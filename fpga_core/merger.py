"""Core diff-and-merge logic — synchronises ``fpga_v`` files with ``rtl_v``.

Uses :class:`FPGABlockExtractor` to isolate FPGA_SYN blocks, diffs the
remaining RTL code against the reference, and applies the changes while
preserving FPGA-specific code.
"""

from __future__ import annotations

import difflib
import logging
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

from .block_extractor import FPGABlock, FPGABlockExtractor
from .config import YELLOW, RED, RESET

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

@dataclass
class MergeResult:
    """Outcome of merging one FPGA file with its RTL reference."""

    fpga_file: Path
    rtl_file: Path
    is_equal: bool
    # Whether any FPGA blocks had their RTL-visible region modified
    fpga_block_warnings: list[int] = field(default_factory=list)
    # The merged content (only set when is_equal is False)
    merged_lines: Optional[list[str]] = None


@dataclass
class SyncContext:
    """Mutable state shared across the sync workflow (replaces old globals)."""

    notequal_fpga: list[str] = field(default_factory=list)
    notequal_rtl: list[str] = field(default_factory=list)
    results: list[MergeResult] = field(default_factory=list)


# ---------------------------------------------------------------------------
# File I/O helpers
# ---------------------------------------------------------------------------

def read_lines(path: Path) -> list[str]:
    """Read file, returning lines with trailing newlines preserved."""
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        return fh.readlines()


def write_lines(path: Path, lines: list[str]) -> None:
    """Write *lines* to *path*, ensuring trailing newlines."""
    with open(path, "w", encoding="utf-8") as fh:
        fh.writelines(lines)


# ---------------------------------------------------------------------------
# Merger
# ---------------------------------------------------------------------------

class FileMerger:
    """Synchronise an FPGA-specific file with its RTL reference.

    Parameters:
        extractor:
            Shared :class:`FPGABlockExtractor` instance (can be reused across
            many files).
    """

    def __init__(self, extractor: Optional[FPGABlockExtractor] = None):
        self.extractor = extractor or FPGABlockExtractor()

    def merge(self, rtl_path: Path, fpga_path: Path) -> MergeResult:
        """Run the full diff-and-merge pipeline for one file pair.

        1. Read both files.
        2. Extract FPGA_SYN blocks from *fpga_path*.
        3. Diff the clean (non-FPGA-only) content against *rtl_path*.
        4. If they differ, apply RTL changes while preserving FPGA blocks.
        5. Write back the merged result.

        Returns a :class:`MergeResult`.
        """
        rtl_lines = read_lines(rtl_path)
        fpga_lines = read_lines(fpga_path)

        # Strip whitespace for comparison (but keep originals for output)
        rtl_stripped = [ln.rstrip() for ln in rtl_lines]

        # Extract FPGA blocks → clean lines (FPGA-only code removed)
        clean_lines, blocks = self.extractor.extract(fpga_lines)
        fpga_stripped = [ln.rstrip() for ln in clean_lines]

        # Diff
        matcher = difflib.SequenceMatcher(None, rtl_stripped, fpga_stripped)
        opcodes = matcher.get_opcodes()

        if len(opcodes) == 1 and opcodes[0][0] == "equal":
            # Files are identical after stripping FPGA blocks
            logger.debug("FPGA file already in sync: %s", fpga_path)
            return MergeResult(fpga_file=fpga_path, rtl_file=rtl_path, is_equal=True)

        # --- Files differ → apply merge ---
        logger.info("Syncing: %s ← %s", fpga_path.name, rtl_path.name)

        # Apply diff opcodes to clean_lines
        merged_clean, block_warnings = self._apply_diff(
            clean_lines, rtl_lines, rtl_stripped, fpga_stripped, opcodes, blocks
        )

        # Reinsert FPGA blocks (using updated RTL content)
        final_lines = self.extractor.reinsert(merged_clean, blocks)

        write_lines(fpga_path, final_lines)

        return MergeResult(
            fpga_file=fpga_path,
            rtl_file=rtl_path,
            is_equal=False,
            fpga_block_warnings=block_warnings,
            merged_lines=final_lines,
        )

    # ------------------------------------------------------------------
    # Internal: diff application
    # ------------------------------------------------------------------

    def _apply_diff(
        self,
        clean_lines: list[str],
        rtl_lines: list[str],
        rtl_stripped: list[str],
        fpga_stripped: list[str],
        opcodes: list[tuple[str, int, int, int, int]],
        blocks: dict[int, FPGABlock],
    ) -> tuple[list[str], list[int]]:
        """Apply diff *opcodes* to produce merged clean lines.

        Returns ``(merged_clean, block_warnings)`` where *block_warnings* lists
        block IDs whose RTL-visible region was affected by the merge.
        """
        merged: list[str] = []
        block_warnings: list[int] = []
        # Track how the block clean_start/clean_end positions shift
        block_positions = {
            bid: [b.clean_start, b.clean_end] for bid, b in blocks.items()
        }

        for tag, a1, a2, b1, b2 in opcodes:
            if tag == "equal":
                # Keep existing FPGA clean lines
                merged.extend(clean_lines[b1:b2])

            elif tag == "replace":
                # Replace FPGA clean segment with RTL lines
                self._check_block_overlap(
                    b1, b2, a2 - a1, tag, blocks, block_positions, block_warnings
                )
                self._shift_block_positions(
                    block_positions, b1, b2, a2 - a1
                )
                merged.extend(rtl_lines[a1:a2])

            elif tag == "delete":
                # difflib 'delete': RTL has lines FPGA doesn't.
                # To apply RTL → FPGA: INSERT RTL[a1:a2] at FPGA position b1.
                new_len = a2 - a1
                self._check_block_overlap(
                    b1, b1, new_len, tag, blocks, block_positions, block_warnings
                )
                self._shift_block_positions(
                    block_positions, b1, b1, new_len
                )
                merged.extend(rtl_lines[a1:a2])

            elif tag == "insert":
                # difflib 'insert': FPGA has lines RTL doesn't.
                # To apply RTL → FPGA: KEEP FPGA[b1:b2].
                self._check_block_overlap(
                    b1, b2, b2 - b1, tag, blocks, block_positions, block_warnings
                )
                merged.extend(clean_lines[b1:b2])

        # Update block positions for reinsertion
        for bid, (new_start, new_end) in block_positions.items():
            if bid in blocks:
                blocks[bid].clean_start = new_start
                blocks[bid].clean_end = new_end

        return merged, block_warnings

    @staticmethod
    def _check_block_overlap(
        b1: int,
        b2: int,
        rtl_len: int,
        tag: str,
        blocks: dict[int, FPGABlock],
        positions: dict[int, list[int]],
        warnings: list[int],
    ) -> None:
        """Check whether the diff region [b1, b2) overlaps any block's RTL area."""
        for bid, block in blocks.items():
            bs, be = positions[bid]
            if block.rtl_visible_count == 0:
                continue
            # Does [b1, b2) intersect [bs, be)?
            if b1 < be and b2 > bs:
                if bid not in warnings:
                    warnings.append(bid)
                    logger.warning(
                        "%sFPGA block %d RTL content modified — may need manual review%s",
                        YELLOW, bid, RESET,
                    )

    @staticmethod
    def _shift_block_positions(
        positions: dict[int, list[int]],
        b1: int,
        b2: int,
        new_len: int,
    ) -> None:
        """Update block clean_start/clean_end after inserting/deleting lines."""
        delta = new_len - (b2 - b1)
        if delta == 0:
            return

        for bid, (bs, be) in positions.items():
            if be <= b1:
                continue  # block entirely before change — no shift
            if bs >= b2:
                # Block entirely after change — shift by delta
                positions[bid] = [bs + delta, be + delta]
            elif bs < b2 and be > b1:
                # Block overlaps the changed region — extend/contract
                positions[bid] = [bs, be + delta]


# ---------------------------------------------------------------------------
# Stub-file port checker
# ---------------------------------------------------------------------------

def check_stub_ports(
    stub_path: Path,
    rtl_path: Path,
    gentb_path: Optional[str] = None,
) -> list[str]:
    """Verify that *stub_path* has matching ports/parameters with *rtl_path*.

    Uses the GenTB parser when available; otherwise falls back to a simple
    regex-based port extraction.

    Returns a list of mismatch descriptions (empty = all good).
    """
    errors: list[str] = []

    # Try GenTB
    gentb = _try_load_gentb(gentb_path)

    if gentb is not None:
        try:
            ref_module = gentb(str(rtl_path), "", "")
            ref_module.parse_top()
            ref_ports = (
                ref_module.para_l + ref_module.in_l
                + ref_module.out_l + ref_module.io_l
            )

            stub_module = gentb(str(stub_path), "", "")
            stub_module.parse_top()
            stub_ports = (
                stub_module.para_l + stub_module.in_l
                + stub_module.out_l + stub_module.io_l
            )

            for p in ref_ports:
                if p not in stub_ports:
                    errors.append(f"Port/param {p} missing in stub")
            for p in stub_ports:
                if p not in ref_ports:
                    errors.append(f"Stub port/param {p} not found in RTL")
            return errors
        except Exception as exc:
            logger.warning("GenTB parse failed for %s: %s", stub_path, exc)
            # Fall through to fallback

    # Pure-Python fallback
    logger.info("Using pure-Python port parser for %s", stub_path)
    ref_ports = _parse_ports_regex(read_lines(rtl_path))
    stub_ports = _parse_ports_regex(read_lines(stub_path))

    for p in ref_ports:
        if p not in stub_ports:
            errors.append(f"Port/param {p} missing in stub")
    for p in stub_ports:
        if p not in ref_ports:
            errors.append(f"Stub port/param {p} not found in RTL")

    return errors


def _try_load_gentb(gentb_path: Optional[str] = None):
    """Best-effort import of the external GenTB module."""
    if gentb_path is None:
        return None
    try:
        import sys
        sys.path.insert(0, gentb_path)
        from gen_tb import GenTB
        return GenTB
    except ImportError:
        logger.debug("GenTB not available at %s", gentb_path)
        return None


def _parse_ports_regex(lines: list[str]) -> set[str]:
    """Extract port and parameter names using regex (pure-Python fallback)."""
    from .config import RE_PORT, RE_MODULE

    text = "".join(lines)

    # Remove comments
    text = re.sub(r"//.*$", "", text, flags=re.MULTILINE)
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)

    ports: set[str] = set()
    for m in RE_PORT.finditer(text):
        name = m.group(5)
        if name:
            ports.add(name)

    return ports


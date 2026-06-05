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
        2. Extract FPGA_SYN blocks from **both** files (stripped RTL → clean
           RTL; stripped FPGA → clean FPGA).
        3. Diff the two clean (ASIC-only) views.
        4. Apply ASIC changes while preserving FPGA blocks.
        5. Merge RTL-originated blocks into the FPGA block set so that
           `` `ifdef FPGA_SYN `` blocks present in the RTL source are not
           duplicated on subsequent syncs.
        6. Write back the merged result.

        Returns a :class:`MergeResult`.
        """
        rtl_lines = read_lines(rtl_path)
        fpga_lines = read_lines(fpga_path)

        # --- 1. Extract FPGA blocks from BOTH files -----------------------
        clean_fpga_lines, fpga_blocks = self.extractor.extract(fpga_lines)
        clean_rtl_lines, rtl_blocks   = self.extractor.extract(rtl_lines)

        # Stripped versions for difflib (compare without trailing whitespace)
        fpga_stripped = [ln.rstrip() for ln in clean_fpga_lines]
        rtl_stripped  = [ln.rstrip() for ln in clean_rtl_lines]

        # --- 2. Diff the two clean (ASIC-only) views ----------------------
        matcher = difflib.SequenceMatcher(None, rtl_stripped, fpga_stripped)
        opcodes = matcher.get_opcodes()

        # Check whether clean content is already identical AND
        # the RTL introduces no new FPGA blocks that the FPGA doesn't have.
        has_new_rtl_blocks = any(
            bid for bid in rtl_blocks
            if bid not in fpga_blocks  # naive check; refined below
        )
        if len(opcodes) == 1 and opcodes[0][0] == "equal" and not has_new_rtl_blocks:
            logger.debug("FPGA file already in sync: %s", fpga_path)
            return MergeResult(fpga_file=fpga_path, rtl_file=rtl_path, is_equal=True)

        # Also run the refined overlap check (uses position mapping)
        rtl_blocks_mapped = self._map_rtl_blocks_to_merged(
            rtl_blocks, clean_rtl_lines, opcodes, fpga_blocks
        )
        new_rtl_blocks = {
            bid: b for bid, b in rtl_blocks_mapped.items()
            if bid not in fpga_blocks
        }
        if len(opcodes) == 1 and opcodes[0][0] == "equal" and not new_rtl_blocks:
            logger.debug("FPGA file already in sync (incl. blocks): %s", fpga_path)
            return MergeResult(fpga_file=fpga_path, rtl_file=rtl_path, is_equal=True)

        # --- 3. Files differ → apply merge --------------------------------
        logger.info("Syncing: %s ← %s", fpga_path.name, rtl_path.name)

        # Map rtl_blocks to clean_fpga space BEFORE merge shifts
        rtl_blocks_in_fpga = self._map_rtl_blocks_to_merged(
            rtl_blocks, clean_rtl_lines, opcodes, fpga_blocks,
        )

        # Apply diff opcodes to clean_fpga_lines, producing merged_clean.
        # fpga_blocks have their positions shifted inside _apply_diff.
        merged_clean, block_warnings = self._apply_diff(
            clean_fpga_lines, clean_rtl_lines, rtl_stripped, fpga_stripped,
            opcodes, fpga_blocks,
        )

        # Also shift rtl_blocks_in_fpga using the same opcodes
        self._apply_position_shifts(rtl_blocks_in_fpga, opcodes)

        # --- 4. Merge RTL blocks into the FPGA block set -------------------
        combined_blocks = dict(fpga_blocks)
        next_id = max(fpga_blocks.keys(), default=-1) + 1
        for bid, rtl_block in rtl_blocks_in_fpga.items():
            # Does this RTL block overlap an existing FPGA block?
            overlaps = self._find_overlapping_block(
                rtl_block, fpga_blocks,
            )
            if overlaps is not None:
                # Already covered — update positions in case lines shifted
                fpga_blocks[overlaps].clean_start = rtl_block.clean_start
                fpga_blocks[overlaps].clean_end   = rtl_block.clean_end
            else:
                # New block from RTL — assign a fresh ID
                rtl_block.block_id = next_id
                combined_blocks[next_id] = rtl_block
                next_id += 1

        # --- 5. Reinsert all blocks ----------------------------------------
        final_lines = self.extractor.reinsert(merged_clean, combined_blocks)

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
        clean_fpga_lines: list[str],
        clean_rtl_lines: list[str],
        rtl_stripped: list[str],
        fpga_stripped: list[str],
        opcodes: list[tuple[str, int, int, int, int]],
        blocks: dict[int, FPGABlock],
    ) -> tuple[list[str], list[int]]:
        """Apply diff *opcodes* to produce merged clean (ASIC-only) lines.

        Both *clean_fpga_lines* and *clean_rtl_lines* are FPGA-block-free
        (their `` `ifdef FPGA_SYN `` blocks have been extracted).  The diff
        therefore only reflects genuine ASIC-level changes.

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
                # Keep existing FPGA clean lines (identical to RTL)
                merged.extend(clean_fpga_lines[b1:b2])

            elif tag == "replace":
                # Replace FPGA clean segment with RTL clean segment
                self._check_block_overlap(
                    b1, b2, a2 - a1, tag, blocks, block_positions, block_warnings
                )
                self._shift_block_positions(
                    block_positions, b1, b2, a2 - a1
                )
                merged.extend(clean_rtl_lines[a1:a2])

            elif tag == "delete":
                # difflib 'delete': RTL has lines FPGA doesn't.
                # To apply RTL → FPGA: INSERT clean_rtl[a1:a2] at FPGA pos b1.
                new_len = a2 - a1
                self._check_block_overlap(
                    b1, b1, new_len, tag, blocks, block_positions, block_warnings
                )
                self._shift_block_positions(
                    block_positions, b1, b1, new_len
                )
                merged.extend(clean_rtl_lines[a1:a2])

            elif tag == "insert":
                # difflib 'insert': FPGA has lines RTL doesn't.
                # To apply RTL → FPGA: KEEP clean_fpga[b1:b2].
                self._check_block_overlap(
                    b1, b2, b2 - b1, tag, blocks, block_positions, block_warnings
                )
                merged.extend(clean_fpga_lines[b1:b2])

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

    # ------------------------------------------------------------------
    # RTL-block merging helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _map_rtl_pos_to_fpga(
        rtl_pos: int,
        opcodes: list[tuple[str, int, int, int, int]],
    ) -> int:
        """Map a single line index from clean-RTL space to clean-FPGA space.

        Uses the difflib opcodes between clean_rtl (A) and clean_fpga (B).
        """
        for tag, a1, a2, b1, b2 in opcodes:
            if a1 <= rtl_pos < a2:
                if tag == "equal":
                    return b1 + (rtl_pos - a1)
                elif tag == "replace":
                    if b1 < b2:
                        return b1 + min(rtl_pos - a1, b2 - b1 - 1)
                    else:
                        return b1
                elif tag == "delete":
                    return b1
        # Fallback: position not covered by any opcode → return as-is
        return rtl_pos

    @staticmethod
    def _map_rtl_blocks_to_merged(
        rtl_blocks: dict[int, FPGABlock],
        clean_rtl_lines: list[str],
        opcodes: list[tuple[str, int, int, int, int]],
        fpga_blocks: dict[int, FPGABlock],
    ) -> dict[int, FPGABlock]:
        """Map *rtl_blocks*' position from clean-RTL space to clean-FPGA space.

        Returns a new dict with updated ``clean_start``/``clean_end`` that are
        directly comparable to the positions in *fpga_blocks* (before any merge
        shifts are applied).

        .. note::

           This produces positions in **clean-FPGA** space — the same space
           occupied by *fpga_blocks* immediately after extraction.  The caller
           must apply any additional shifts that happen during
           :meth:`_apply_diff`.
        """
        mapped: dict[int, FPGABlock] = {}
        for bid, block in rtl_blocks.items():
            if block.rtl_visible_count == 0:
                continue  # pure-FPGA block (no rtl_visible) — can't map
            new_start = FileMerger._map_rtl_pos_to_fpga(
                block.clean_start, opcodes,
            )
            new_end = FileMerger._map_rtl_pos_to_fpga(
                block.clean_end - 1, opcodes,  # last line of rtl_visible
            ) + 1
            import copy
            b2 = copy.copy(block)
            b2.clean_start = new_start
            b2.clean_end = new_end
            mapped[bid] = b2
        return mapped

    @staticmethod
    def _find_overlapping_block(
        rtl_block: FPGABlock,
        fpga_blocks: dict[int, FPGABlock],
    ) -> int | None:
        """Return the block_id of an fpga_block whose rtl_visible region overlaps
        *rtl_block*'s rtl_visible region, or ``None``.

        Two blocks are considered "the same" when their rtl_visible regions
        are at the same position (± 3 lines tolerance for comment shifts).
        """
        TOLERANCE = 3
        rs, re = rtl_block.clean_start, rtl_block.clean_end
        for bid, fb in fpga_blocks.items():
            fs, fe = fb.clean_start, fb.clean_end
            if fb.rtl_visible_count == 0:
                continue
            # Check for position overlap with tolerance
            if rs < fe + TOLERANCE and re > fs - TOLERANCE:
                return bid
        return None

    @staticmethod
    def _apply_position_shifts(
        blocks: dict[int, FPGABlock],
        opcodes: list[tuple[str, int, int, int, int]],
    ) -> None:
        """Shift *blocks*' ``clean_start``/``clean_end`` by the same deltas
        that :meth:`_apply_diff` applies — bringing blocks mapped to
        clean-FPGA space into merged-clean space.

        Only ``replace`` and ``delete`` opcodes cause shifts (``equal`` and
        ``insert`` keep lengths unchanged).
        """
        if not blocks:
            return
        _pos = {bid: [b.clean_start, b.clean_end] for bid, b in blocks.items()}
        for tag, a1, a2, b1, b2 in opcodes:
            if tag == "replace":
                old_len = b2 - b1
                new_len = a2 - a1
            elif tag == "delete":
                old_len = 0
                new_len = a2 - a1
            else:
                continue  # equal / insert — no length change
            FileMerger._shift_block_positions(_pos, b1, b1 + old_len, new_len)
        for bid, b in blocks.items():
            if bid in _pos:
                b.clean_start, b.clean_end = _pos[bid]


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


"""FPGA-block extraction using a state machine with position tracking.

Replaces the fragile manual-index-arithmetic approach in the original
``find_fpga_blocks`` / ``remove_fpga_blocks`` with a deterministic finite
automaton that:

1. Scans once to identify `` `ifdef/`ifndef FPGA_SYN`` blocks.
2. Splits each block into *preamble* / *rtl_visible* / *postamble* parts.
3. Emits clean lines where each block's RTL-visible code is retained
   (so diffing against the reference RTL file works).
4. Tracks block positions in the clean output.
5. Reinserts blocks after merging, using the updated RTL-visible content.

Handles nested `` `ifdef `` directives correctly via a nesting counter.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from enum import Enum, auto
from typing import Optional

from .config import (
    RE_ELSE,
    RE_ENDIF,
    RE_IFDEF_ANY,
    RE_IFDEF_FPGA_SYN,
    RE_IFNDEF_ANY,
    RE_IFNDEF_FPGA_SYN,
)

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

class BlockType(Enum):
    IFDEF  = auto()   # ``ifdef FPGA_SYN``
    IFNDEF = auto()   # ``ifndef FPGA_SYN``


@dataclass
class FPGABlock:
    """A single ``ifdef/ifndef FPGA_SYN ... endif`` block, split into parts.

    Three-part decomposition::

        `ifdef FPGA_SYN      +
         // FPGA-only code    |  preamble  (always includes the opening directive)
        `else                 +
         // RTL code          ->  rtl_visible  (compared against reference RTL)
        `endif                ->  postamble     (always includes the closing endif)

    For blocks without ``else`` the *rtl_visible* part is empty.
    """

    block_id: int
    block_type: BlockType

    # Lines before the RTL-visible section (includes opening directive).
    preamble: list[str] = field(default_factory=list)
    # Lines that are common RTL code -- the part that should be diffed.
    rtl_visible: list[str] = field(default_factory=list)
    # Lines after the RTL-visible section (includes closing endif).
    postamble: list[str] = field(default_factory=list)

    # Position of the rtl_visible lines in the *clean* output:
    #   clean_lines[clean_start:clean_end]  ->  rtl_visible content
    clean_start: int = 0
    clean_end: int = 0

    # Original line range in the source file (1-based for diagnostics).
    src_start: int = 0
    src_end: int = 0

    @property
    def full_lines(self) -> list[str]:
        """Reconstruct the full block."""
        return self.preamble + self.rtl_visible + self.postamble

    @property
    def rtl_visible_count(self) -> int:
        return len(self.rtl_visible)

    def reconstruct(self, updated_rtl: list[str]) -> list[str]:
        """Build the block with updated RTL-visible content."""
        return self.preamble + updated_rtl + self.postamble


# ---------------------------------------------------------------------------
# State machine
# ---------------------------------------------------------------------------

class _State(Enum):
    NORMAL    = auto()
    IN_IFDEF  = auto()
    IN_IFNDEF = auto()


@dataclass
class _RawBlock:
    block_type: BlockType
    lines: list[str]           # accumulated lines from opening directive onward
    src_start: int
    else_idx: int = -1         # index (within lines) of `else, or -1
    nesting: int = 0


class FPGABlockExtractor:
    """State-machine extractor for FPGA_SYN preprocessor blocks.

    Usage::

        extractor = FPGABlockExtractor()
        clean_lines, blocks = extractor.extract(fpga_lines)

        # ... diff & merge clean_lines against reference RTL ...

        merged = extractor.reinsert(merged_clean_lines, blocks)
    """

    def extract(self, lines: list[str]) -> tuple[list[str], dict[int, FPGABlock]]:
        """Scan *lines* and separate FPGA_SYN blocks from clean RTL content.

        Returns:
            *clean_lines* -- lines with FPGA-only code removed, RTL-visible
                             code retained for diffing.
            *blocks*       -- dict mapping block_id -> FPGABlock.
        """
        clean: list[str] = []
        blocks: dict[int, FPGABlock] = {}
        state = _State.NORMAL
        current: Optional[_RawBlock] = None
        block_counter = 0

        for idx, raw_line in enumerate(lines):
            stripped = raw_line.rstrip("\n\r")

            if state is _State.NORMAL:
                result = self._try_start_block(raw_line, stripped, idx, state, current)
                if result is not None:
                    state, current = result
                    continue
                clean.append(raw_line)

            elif state in (_State.IN_IFDEF, _State.IN_IFNDEF):
                assert current is not None
                current.lines.append(raw_line)

                if RE_ENDIF.search(stripped):
                    if current.nesting > 0:
                        current.nesting -= 1
                    else:
                        block = self._build_block(block_counter, current, clean)
                        blocks[block_counter] = block
                        block_counter += 1
                        state = _State.NORMAL
                        current = None
                elif RE_ELSE.search(stripped) and current.else_idx < 0 and current.nesting == 0:
                    current.else_idx = len(current.lines) - 1
                elif RE_IFDEF_ANY.search(stripped) or RE_IFNDEF_ANY.search(stripped):
                    current.nesting += 1

        if state is not _State.NORMAL:
            logger.warning(
                "Unclosed FPGA_SYN block at line %d -- treating rest of file as block",
                current.src_start + 1 if current else 0,
            )
            if current:
                block = self._build_block(block_counter, current, clean)
                blocks[block_counter] = block

        return clean, blocks

    # ------------------------------------------------------------------
    # Reinsertion
    # ------------------------------------------------------------------

    def reinsert(
        self,
        merged_clean: list[str],
        blocks: dict[int, FPGABlock],
        block_positions: Optional[dict[int, tuple[int, int]]] = None,
    ) -> list[str]:
        """Reinsert FPGA blocks into *merged_clean* lines.

        Parameters:
            merged_clean:
                Clean lines after diff/merge (RTL-visible portions may have
                been updated).
            blocks:
                Original extracted blocks (preamble/postamble preserved).
            block_positions:
                Optional dict mapping block_id -> (start, end) in
                *merged_clean*.  If omitted, positions are computed from
                the original ``clean_start``/``clean_end``, which is only
                correct if the merge didn't shift lines.

        Returns:
            Fully merged lines with FPGA blocks restored.
        """
        # Build a map of which merged-clean index ranges belong to each block
        if block_positions is None:
            block_positions = {
                bid: (b.clean_start, b.clean_end)
                for bid, b in blocks.items()
            }

        # Sort blocks by their clean position (descending) so we can safely
        # splice without invalidating earlier positions.
        ordered = sorted(
            block_positions.items(),
            key=lambda kv: kv[1][0],
            reverse=True,
        )

        result = list(merged_clean)

        for bid, (start, end) in ordered:
            block = blocks.get(bid)
            if block is None:
                continue

            # The current RTL-visible content is at merged_clean[start:end]
            # Keep newlines intact -- the merger output lines already have them
            updated_rtl = result[start:end]
            # If the original rtl_visible was empty, there's nothing to update
            reconstructed = block.reconstruct(updated_rtl)
            # Replace the clean segment with the full reconstructed block
            result[start:end] = reconstructed

        return result

    # ------------------------------------------------------------------
    # Change detection
    # ------------------------------------------------------------------

    def detect_changes(
        self,
        old_blocks: dict[int, FPGABlock],
        new_lines: list[str],
    ) -> list[int]:
        """Re-extract and compare blocks -- identify FPGA code that changed.

        Returns block_id values whose inner FPGA-only code (preamble or
        postamble, excluding the directives themselves) was modified.
        """
        _, new_blocks = self.extract(new_lines)
        changed: list[int] = []

        all_ids = sorted(set(old_blocks.keys()) | set(new_blocks.keys()))
        for bid in all_ids:
            old = old_blocks.get(bid)
            new = new_blocks.get(bid)
            if old is None or new is None:
                changed.append(bid)
                logger.warning("FPGA block %d added/removed -- needs manual review", bid)
                continue
            if old.block_type is not new.block_type:
                changed.append(bid)
                continue
            if old.full_lines != new.full_lines:
                changed.append(bid)
                logger.info("FPGA block %d content changed -- needs manual review", bid)

        return changed

    # ------------------------------------------------------------------
    # Internal
    # ------------------------------------------------------------------

    def _try_start_block(
        self,
        raw_line: str,
        stripped: str,
        idx: int,
        state: _State,
        current: Optional[_RawBlock],
    ) -> Optional[tuple[_State, _RawBlock]]:
        """If *stripped* starts a new FPGA_SYN block, return the new state."""
        if RE_IFDEF_FPGA_SYN.search(stripped):
            return (
                _State.IN_IFDEF,
                _RawBlock(
                    block_type=BlockType.IFDEF,
                    lines=[raw_line],
                    src_start=idx,
                ),
            )
        if RE_IFNDEF_FPGA_SYN.search(stripped):
            return (
                _State.IN_IFNDEF,
                _RawBlock(
                    block_type=BlockType.IFNDEF,
                    lines=[raw_line],
                    src_start=idx,
                ),
            )
        return None

    def _build_block(
        self, block_id: int, raw: _RawBlock, clean: list[str]
    ) -> FPGABlock:
        """Partition *raw* into preamble / rtl_visible / postamble."""

        if raw.block_type is BlockType.IFDEF:
            #  `ifdef FPGA_SYN  ...  [`else  ...]  `endif
            if raw.else_idx >= 0:
                preamble  = raw.lines[: raw.else_idx + 1]    # up to and including else
                postamble = raw.lines[-1:]                   # endif
                rtl_vis   = raw.lines[raw.else_idx + 1 : -1] # between else and endif
            else:
                preamble  = raw.lines[:]                     # everything is FPGA-only
                postamble = []
                rtl_vis   = []
        else:  # IFNDEF
            #  `ifndef FPGA_SYN  ...  [`else  ...]  `endif
            if raw.else_idx >= 0:
                preamble  = raw.lines[:1]                    # just the ifndef line
                rtl_vis   = raw.lines[1 : raw.else_idx]      # between ifndef and else
                postamble = raw.lines[raw.else_idx:]         # else  ...  endif
            else:
                preamble  = raw.lines[:1]                    # just the ifndef line
                rtl_vis   = raw.lines[1:]                    # all lines after ifndef
                postamble = []

        block = FPGABlock(
            block_id=block_id,
            block_type=raw.block_type,
            preamble=preamble,
            rtl_visible=rtl_vis,
            postamble=postamble,
            src_start=raw.src_start,
            src_end=raw.src_start + len(raw.lines),
        )

        # Emit RTL-visible content into clean lines
        block.clean_start = len(clean)
        for ln in rtl_vis:
            clean.append(ln)
        block.clean_end = len(clean)

        return block

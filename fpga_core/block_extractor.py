"""FPGA-block extraction with recursive nested-block support.

Splits `` `ifdef/`ifndef FPGA_SYN`` blocks into *preamble* / *rtl_visible* /
*postamble* parts so that the RTL-visible code can be diffed against the
reference RTL while FPGA-only code is preserved and reinserted after merging.

Unlike the previous flat state machine, nested `` `ifdef FPGA_SYN`` blocks
(e.g. an `` `ifdef FPGA_SYN`` inside an instance's port list, itself inside a
strip-ips `` `ifdef FPGA_SYN ... `else ... `endif`` wrapper) are extracted
recursively.  Each nested block becomes a *child* of its enclosing block, so
its FPGA-only branches are excluded from the clean view and survive a merge.
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

    Nested FPGA_SYN blocks are extracted recursively and stored in
    ``children``.  A child's ``clean_start``/``clean_end`` lie strictly within
    its parent's, and the parent's ``rtl_visible`` holds the *recursively
    cleaned* content (child FPGA-only branches removed).
    """

    block_id: int
    block_type: BlockType

    # Lines before the RTL-visible section (includes opening directive).
    preamble: list[str] = field(default_factory=list)
    # Lines that are common RTL code -- the part that should be diffed.
    rtl_visible: list[str] = field(default_factory=list)
    # Lines after the RTL-visible section (includes closing endif).
    postamble: list[str] = field(default_factory=list)

    # Nested FPGA_SYN blocks, ordered by their position within rtl_visible.
    children: list["FPGABlock"] = field(default_factory=list)

    # Position of the rtl_visible lines in the *clean* output:
    #   clean_lines[clean_start:clean_end]  ->  rtl_visible content
    clean_start: int = 0
    clean_end: int = 0

    # Original line range in the source file (0-based for diagnostics).
    src_start: int = 0
    src_end: int = 0

    @property
    def full_lines(self) -> list[str]:
        """Reconstruct the full block (flat view, children not expanded)."""
        return self.preamble + self.rtl_visible + self.postamble

    @property
    def rtl_visible_count(self) -> int:
        return len(self.rtl_visible)

    def reconstruct(self, updated_rtl: list[str]) -> list[str]:
        """Build the block with updated RTL-visible content (flat view)."""
        return self.preamble + updated_rtl + self.postamble


# ---------------------------------------------------------------------------
# Extractor
# ---------------------------------------------------------------------------

class FPGABlockExtractor:
    """Recursive extractor for FPGA_SYN preprocessor blocks.

    Usage::

        extractor = FPGABlockExtractor()
        clean_lines, blocks = extractor.extract(fpga_lines)

        # ... diff & merge clean_lines against reference RTL ...

        merged = extractor.reinsert(merged_clean_lines, blocks)
    """

    def extract(self, lines: list[str]) -> tuple[list[str], dict[int, FPGABlock]]:
        """Scan *lines* and separate FPGA_SYN blocks from clean RTL content.

        Nested ``ifdef/ifndef FPGA_SYN`` blocks are extracted recursively and
        stored as ``children`` of their enclosing block (also present in the
        returned dict keyed by their own block id).

        Returns:
            *clean_lines* -- lines with FPGA-only code removed, RTL-visible
                             code retained for diffing.
            *blocks*       -- dict mapping block_id -> FPGABlock.
        """
        clean, blocks = self._extract_segment(lines, _IdCounter(), offset=0)
        return clean, blocks

    def _extract_segment(
        self, lines: list[str], ids: "_IdCounter", offset: int
    ) -> tuple[list[str], dict[int, FPGABlock]]:
        """Recursively extract top-level FPGA blocks from *lines*.

        *ids* is a shared mutable counter so nested blocks get globally unique
        ids.  *offset* is the global clean-line index at which *lines* begin;
        it lets nested blocks store ``clean_start``/``clean_end`` in the
        global clean coordinate space (not relative to their parent segment).

        Returns ``(clean_lines, blocks)``; nested blocks are attached as
        ``children`` of their parent *and* included in ``blocks``.
        """
        clean: list[str] = []
        blocks: dict[int, FPGABlock] = {}
        i = 0
        n = len(lines)
        while i < n:
            raw_line = lines[i]
            stripped = raw_line.rstrip("\n\r")

            block_type = None
            if RE_IFDEF_FPGA_SYN.search(stripped):
                block_type = BlockType.IFDEF
            elif RE_IFNDEF_FPGA_SYN.search(stripped):
                block_type = BlockType.IFNDEF

            if block_type is None:
                clean.append(raw_line)
                i += 1
                continue

            # Collect the full block (handles nested directives via counting).
            block_lines, end_i = self._collect_block(lines, i)
            preamble, rtl_vis, postamble = self._partition(block_type, block_lines)

            # Recursively extract nested blocks.  Their clean positions must be
            # in the global coordinate space; this block's rtl_visible begins
            # at global line ``offset + len(clean)``.
            rtl_vis_offset = offset + len(clean)
            child_clean, child_blocks = self._extract_segment(rtl_vis, ids, rtl_vis_offset)

            bid = ids.next()
            # `child_blocks` holds *all* blocks inside rtl_vis (direct children
            # plus deeper descendants).  Attach only the direct children --
            # those not nested inside another block of the same segment.
            nested_ids = {c.block_id for b in child_blocks.values() for c in b.children}
            direct_children = sorted(
                (child_blocks[cb] for cb in child_blocks if cb not in nested_ids),
                key=lambda b: b.clean_start,
            )

            block = FPGABlock(
                block_id=bid,
                block_type=block_type,
                preamble=preamble,
                rtl_visible=child_clean,
                postamble=postamble,
                children=direct_children,
                src_start=i,
                src_end=end_i + 1,
            )
            # Emit recursively-cleaned RTL-visible content into clean.
            block.clean_start = rtl_vis_offset
            clean.extend(child_clean)
            block.clean_end = offset + len(clean)

            blocks[bid] = block
            blocks.update(child_blocks)

            i = end_i + 1

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
        """Reinsert FPGA blocks into *merged_clean* lines (recursively).

        Nested blocks are reconstructed innermost-first so that a parent's
        ``rtl_visible`` slice (read from *merged_clean*) already contains the
        fully-reconstructed children when the parent itself is reassembled.

        *block_positions* is retained for backwards compatibility but ignored;
        positions are taken from each block's ``clean_start``/``clean_end``
        (already shifted by the merger).
        """
        result = list(merged_clean)

        # Top-level blocks = those not referenced as any other block's child.
        child_ids = {c.block_id for b in blocks.values() for c in b.children}
        top_blocks = sorted(
            (blocks[bid] for bid in blocks if bid not in child_ids),
            key=lambda b: b.clean_start,
        )

        return self._reinsert_range(result, 0, len(result), top_blocks)

    def _reinsert_range(
        self,
        result: list[str],
        start: int,
        end: int,
        range_blocks: list[FPGABlock],
    ) -> list[str]:
        """Reconstruct *result[start:end]*, splicing in *range_blocks* (which
        must be sorted by ``clean_start`` and lie within ``[start, end)``)."""
        out: list[str] = []
        pos = start
        for block in range_blocks:
            out.extend(result[pos:block.clean_start])
            inner = self._reinsert_range(
                result, block.clean_start, block.clean_end, block.children,
            )
            out.extend(block.preamble)
            out.extend(inner)
            out.extend(block.postamble)
            pos = block.clean_end
        out.extend(result[pos:end])
        return out

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
    # Internal: block collection and partitioning
    # ------------------------------------------------------------------

    def _collect_block(self, lines: list[str], start_i: int) -> tuple[list[str], int]:
        """Collect the block starting at *start_i* (the opening directive).

        Handles nested `` `ifdef/`ifndef/`endif `` directives via a nesting
        counter, returning ``(block_lines, end_i)`` where *end_i* is the index
        of the matching closing `` `endif``.
        """
        block_lines: list[str] = [lines[start_i]]
        nesting = 0
        i = start_i + 1
        n = len(lines)
        while i < n:
            line = lines[i]
            stripped = line.rstrip("\n\r")
            block_lines.append(line)

            if RE_ENDIF.search(stripped):
                if nesting > 0:
                    nesting -= 1
                else:
                    return block_lines, i
            elif RE_ELSE.search(stripped) and nesting == 0:
                pass  # `else at this level -- still inside the block
            elif RE_IFDEF_ANY.search(stripped) or RE_IFNDEF_ANY.search(stripped):
                nesting += 1

            i += 1

        logger.warning(
            "Unclosed FPGA_SYN block at line %d -- treating rest of file as block",
            start_i + 1,
        )
        return block_lines, n - 1

    def _partition(
        self, block_type: BlockType, block_lines: list[str]
    ) -> tuple[list[str], list[str], list[str]]:
        """Split *block_lines* into ``(preamble, rtl_visible, postamble)``."""
        else_idx = self._find_else_idx(block_lines)

        if block_type is BlockType.IFDEF:
            #  `ifdef FPGA_SYN  ...  [`else  ...]  `endif
            if else_idx >= 0:
                preamble = block_lines[: else_idx + 1]     # up to and including else
                postamble = block_lines[-1:]               # endif
                rtl_vis = block_lines[else_idx + 1 : -1]   # between else and endif
            else:
                preamble = block_lines[:]                  # everything is FPGA-only
                postamble = []
                rtl_vis = []
        else:  # IFNDEF
            #  `ifndef FPGA_SYN  ...  [`else  ...]  `endif
            if else_idx >= 0:
                preamble = block_lines[:1]                 # just the ifndef line
                rtl_vis = block_lines[1:else_idx]          # between ifndef and else
                postamble = block_lines[else_idx:]         # else ... endif
            else:
                preamble = block_lines[:1]                 # just the ifndef line
                rtl_vis = block_lines[1:-1]                # between ifndef and endif
                postamble = block_lines[-1:]               # the `endif line

        return preamble, rtl_vis, postamble

    def _find_else_idx(self, block_lines: list[str]) -> int:
        """Return the index of the block's own `` `else`` (nesting 0), or -1.

        ``block_lines[0]`` is the opening directive, so scanning starts at 1.
        Nested `` `ifdef/`ifndef`` directives raise the nesting counter so
        their `` `else`` lines are not mistaken for this block's `` `else``.
        """
        nesting = 0
        for idx in range(1, len(block_lines)):
            stripped = block_lines[idx].rstrip("\n\r")
            if RE_ENDIF.search(stripped):
                if nesting > 0:
                    nesting -= 1
                else:
                    break  # reached the closing endif before any `else
            elif RE_IFDEF_ANY.search(stripped) or RE_IFNDEF_ANY.search(stripped):
                nesting += 1
            elif RE_ELSE.search(stripped) and nesting == 0:
                return idx
        return -1


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

class _IdCounter:
    """Simple mutable integer counter shared across recursive calls."""

    def __init__(self) -> None:
        self._value = 0

    def next(self) -> int:
        value = self._value
        self._value += 1
        return value

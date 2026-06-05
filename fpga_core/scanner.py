"""Directory scanner — unified discovery of RTL / FPGA / stub files.

Replaces the scattered :func:`os.walk` calls and the old ``list_folders``
function with a single, reusable :class:`DesignScanner`.
"""

from __future__ import annotations

import logging
from pathlib import Path
from typing import Iterator, Optional

from .config import RE_STUB_SUFFIX, RE_VERILOG_EXT

logger = logging.getLogger(__name__)


class DesignScanner:
    """Walks design directories to locate RTL / FPGA / stub source files.

    Parameters:
        design_dirs:
            Top-level directories to search recursively.
        reference_subdirs:
            Subdirectory names that contain reference RTL (checked in order).
    """

    # Subdirectories that indicate IP needing FPGA / stub handling
    FPGA_DIR  = "fpga_v"
    STUB_DIR  = "stub_v"

    def __init__(
        self,
        design_dirs: list[Path],
        reference_subdirs: Optional[list[str]] = None,
    ):
        self.design_dirs = design_dirs
        self.ref_subdirs = reference_subdirs or ["rtl_v", "bhv_v", "src"]

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def iter_folders_with_fpga_or_stub(self) -> Iterator[Path]:
        """Yield directories that contain a ``fpga_v`` or ``stub_v`` subdir."""
        for design_dir in self.design_dirs:
            if not design_dir.is_dir():
                continue
            for root, dirs, _files in design_dir.walk():
                if self.FPGA_DIR in dirs or self.STUB_DIR in dirs:
                    yield Path(root)

    def iter_fpga_pairs(self) -> Iterator[tuple[Path, Path]]:
        """Yield ``(rtl_path, fpga_path)`` pairs for every file in ``fpga_v``.

        The RTL reference file is resolved by scanning ``rtl_v``, ``bhv_v``,
        and ``src`` subdirectories (in order) under the same parent.
        """
        for folder in self.iter_folders_with_fpga_or_stub():
            fpga_dir = folder / self.FPGA_DIR
            if not fpga_dir.is_dir():
                continue
            for fpga_file in self._verilog_files(fpga_dir):
                ref = self._find_reference(folder, fpga_file.name)
                if ref is not None:
                    yield (ref, fpga_file)
                else:
                    logger.warning(
                        "Cannot find reference file for %s in %s",
                        fpga_file.name, folder,
                    )

    def iter_stub_files(self) -> Iterator[tuple[Path, Path]]:
        """Yield ``(stub_path, rtl_ref_path)`` pairs for every stub file.

        The stub file name has ``_stub`` stripped to locate the RTL reference.
        """
        for folder in self.iter_folders_with_fpga_or_stub():
            stub_dir = folder / self.STUB_DIR
            if not stub_dir.is_dir():
                continue
            for stub_file in self._verilog_files(stub_dir):
                ref_name = RE_STUB_SUFFIX.sub("", stub_file.name)
                ref = self._find_reference(folder, ref_name)
                if ref is not None:
                    yield (stub_file, ref)
                else:
                    logger.warning(
                        "Cannot find reference for stub %s in %s",
                        stub_file.name, folder,
                    )

    def find_fpga_v_files(self) -> list[Path]:
        """Return the full path of every Verilog file under any ``fpga_v`` dir."""
        result: list[Path] = []
        for design_dir in self.design_dirs:
            if not design_dir.is_dir():
                continue
            for root, dirs, _files in design_dir.walk():
                if self.FPGA_DIR in dirs:
                    fpga_dir = Path(root) / self.FPGA_DIR
                    result.extend(self._verilog_files(fpga_dir))
        return result

    def find_stub_v_files(self) -> list[Path]:
        """Return the full path of every Verilog file under any ``stub_v`` dir."""
        result: list[Path] = []
        for design_dir in self.design_dirs:
            if not design_dir.is_dir():
                continue
            for root, dirs, _files in design_dir.walk():
                if self.STUB_DIR in dirs:
                    stub_dir = Path(root) / self.STUB_DIR
                    result.extend(self._verilog_files(stub_dir))
        return result

    def find_memory_wrappers(self, search_path: Path) -> list[Path]:
        """Find Verilog memory-wrapper files (``*_wrap.v`` / ``*_wrap.sv``)."""
        if not search_path.is_dir():
            logger.debug("Memory wrapper path does not exist: %s", search_path)
            return []
        return [
            p for p in search_path.rglob("*_wrap.v")
        ] + [
            p for p in search_path.rglob("*_wrap.sv")
        ]

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _verilog_files(directory: Path) -> list[Path]:
        """Verilog source files in *directory* (non-recursive)."""
        if not directory.is_dir():
            return []
        return sorted(
            p for p in directory.iterdir()
            if p.is_file() and RE_VERILOG_EXT.search(p.suffix)
        )

    def _find_reference(self, parent: Path, name: str) -> Optional[Path]:
        """Locate the RTL reference file for *name* under *parent*.

        Searches subdirectories in ``ref_subdirs`` order.
        """
        for subdir in self.ref_subdirs:
            candidate = parent / subdir / name
            if candidate.is_file():
                return candidate
        return None

"""FPGA filelist.f generation — replaces all ``os.system('sed …')`` calls
from the original script with Python-native string / file operations.
"""

from __future__ import annotations

import logging
import re
from pathlib import Path
from typing import Optional

from .config import (
    ENV_TO_FILELIST_VAR,
    FPGA_INCLUDE_DIRS,
    FPGA_INCLUDE_DIRS_NOSCE,
    FPGA_SET_PROPERTY,
    FPGA_SET_PROPERTY_SCE,
    FPGA_XDC_PROPERTY,
    RE_VERILOG_EXT,
)
from .scanner import DesignScanner

logger = logging.getLogger(__name__)


def generate_filelist(
    design_dirs: list[Path],
    use_stub_list: list[str],
    tb_fpga_paths: list[Path],
    source_filelist: Path,
    output_path: Path = Path("filelist.f"),
    *,
    use_sce: bool = True,
) -> Path:
    """Generate the FPGA synthesis filelist.

    Parameters:
        design_dirs:
            Root design directories to scan for ``stub_v`` / ``fpga_v``.
        use_stub_list:
            IP names whose RTL files should be replaced by stub versions.
        tb_fpga_paths:
            Paths to FPGA testbench files.
        source_filelist:
            Path to the reference ``top_rtl_filelist`` (RTL filelist).
        output_path:
            Where to write the generated filelist.
        use_sce:
            Whether ``dip_sce`` is in *use_stub_list* (controls Tcl templates).

    Returns:
        The *output_path*.
    """
    scanner = DesignScanner(design_dirs)

    # ---- Collect stub / fpga file info ------------------------------------
    stub_files: dict[str, str] = {}   # basename → full path
    fpga_files: dict[str, str] = {}   # basename → full path

    for design_dir in design_dirs:
        if not design_dir.is_dir():
            continue
        for root, dirs, _files in design_dir.walk():
            root_path = Path(root)

            stub_dir = root_path / "stub_v"
            if stub_dir.is_dir():
                for f in stub_dir.iterdir():
                    if f.is_file() and RE_VERILOG_EXT.search(f.suffix):
                        stub_files[f.name] = str(f)

            fpga_dir = root_path / "fpga_v"
            if fpga_dir.is_dir():
                for f in fpga_dir.iterdir():
                    if f.is_file() and RE_VERILOG_EXT.search(f.suffix):
                        fpga_files[f.name] = str(f)

    # ---- Read source filelist ---------------------------------------------
    if not source_filelist.is_file():
        raise FileNotFoundError(f"Source filelist not found: {source_filelist}")

    lines = _read_source_filelist(source_filelist, use_stub_list, stub_files)

    # ---- Replace RTL entries with FPGA / stub entries ---------------------
    for name, full_path in fpga_files.items():
        lines = _replace_file_entry(lines, name, full_path)

    # ---- Add TB FPGA files ------------------------------------------------
    for tb_path in tb_fpga_paths:
        if tb_path.is_dir():
            for f in sorted(tb_path.iterdir()):
                if f.is_file() and RE_VERILOG_EXT.search(f.suffix):
                    lines = _replace_file_entry(lines, f.name, str(f))

    # ---- Verify fpga_v file count -----------------------------------------
    fpga_v_count = sum(1 for ln in lines if "fpga_v" in ln)
    if fpga_v_count != len(fpga_files):
        logger.error(
            "fpga_v count mismatch: %d in filelist vs %d expected",
            fpga_v_count, len(fpga_files),
        )
        for name in fpga_files:
            if not any(name in ln and "fpga_v" in ln for ln in lines):
                logger.error("  Missing from filelist: %s", name)

    # ---- Build final output -----------------------------------------------
    header = _build_tcl_header(use_sce)
    body = "\n".join(f"read_verilog -sv {ln}" for ln in lines)
    footer = _build_tcl_footer(use_sce)

    output = f"{header}\n{body}\n}}\n{footer}\n"

    # Substitute environment-variable shortcuts back to Tcl variables
    output = _substitute_env_vars(output)

    output_path.write_text(output, encoding="utf-8")
    logger.info("Wrote FPGA filelist: %s (%d entries)", output_path, len(lines))
    return output_path


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _read_source_filelist(
    path: Path,
    use_stub_list: list[str],
    stub_files: dict[str, str],
) -> list[str]:
    """Read and filter the source filelist."""
    lines: list[str] = []

    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            ln = raw.strip()
            if not ln:
                continue
            # Skip library / memory / AIP entries
            if any(kw in ln for kw in ("tsmc_lib", "gf22_lib", "MEMORY_DIR", "/aip_")):
                continue
            # Skip comments
            if ln.startswith("//"):
                continue
            # Skip incdir directives
            if "+incdir+" in ln:
                continue
            lines.append(ln)

    # Replace stub-list IP entries with their stub files
    for stub_ip in use_stub_list:
        lines = [ln for ln in lines if stub_ip not in ln]
        for name, full_path in stub_files.items():
            if stub_ip in name:
                if full_path not in lines:
                    lines.append(full_path)

    return lines


def _replace_file_entry(lines: list[str], basename: str, new_path: str) -> list[str]:
    """Replace any entry ending with *basename* with *new_path*."""
    result: list[str] = []
    found = False
    for ln in lines:
        # Match lines where basename is the file component
        if ln.rstrip().endswith(basename):
            if not found:
                result.append(new_path)
                found = True
            # else: duplicate — skip
        else:
            result.append(ln)
    if not found:
        result.append(new_path)
    return result


def _build_tcl_header(use_sce: bool) -> str:
    """Return the Tcl header block."""
    return FPGA_INCLUDE_DIRS if use_sce else FPGA_INCLUDE_DIRS_NOSCE


def _build_tcl_footer(use_sce: bool) -> str:
    """Return the Tcl footer block."""
    parts = [FPGA_SET_PROPERTY]
    if use_sce:
        parts.append(FPGA_SET_PROPERTY_SCE)
    parts.append(FPGA_XDC_PROPERTY)
    return "\n".join(parts)


def _substitute_env_vars(text: str) -> str:
    """Replace absolute paths with Tcl variable references.

    E.g. ``/proj/common/ip/foo → $COMMON_IP_DIR/foo``.
    """
    import os
    for env_var, tcl_var in ENV_TO_FILELIST_VAR.items():
        env_val = os.getenv(env_var, "")
        if env_val:
            text = text.replace(env_val, tcl_var)
    return text

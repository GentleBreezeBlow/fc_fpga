"""FPGA filelist.f generation -- replaces all ``os.system('sed ...')`` calls
from the original script with Python-native string / file operations.
"""

from __future__ import annotations

import logging
import os
import re
from pathlib import Path
from typing import Optional

from .config import (
    ENV_TO_FILELIST_VAR,
    EXTRA_INCLUDE_DIRS,
    EXTRA_VERILOG_FILES,
    FPGA_SET_PROPERTY,
    FPGA_SET_PROPERTY_SCE,
    FPGA_XDC_PROPERTY,
    RE_VERILOG_EXT,
    SKIP_DIRS,
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
    stub_files: dict[str, str] = {}   # basename -> full path
    fpga_files: dict[str, str] = {}   # basename -> full path

    for design_dir in design_dirs:
        if not design_dir.is_dir():
            continue
        for root, dirs, _files in os.walk(str(design_dir)):
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            root_path = Path(root)

            stub_dir = root_path / "stub_v"
            if stub_dir.is_dir():
                for f in stub_dir.iterdir():
                    if f.is_file() and RE_VERILOG_EXT.search(f.suffix):
                        stub_files[f.name] = str(f).replace("\\", "/")

            fpga_dir = root_path / "fpga_v"
            if fpga_dir.is_dir():
                for f in fpga_dir.iterdir():
                    if f.is_file() and RE_VERILOG_EXT.search(f.suffix):
                        fpga_files[f.name] = str(f).replace("\\", "/")

    # ---- Read source filelist ---------------------------------------------
    if not source_filelist.is_file():
        raise FileNotFoundError(f"Source filelist not found: {source_filelist}")

    lines = _read_source_filelist(source_filelist, use_stub_list, stub_files)

    # ---- Parse +incdir+ / -y from source for include_dirs -----------------
    extra_inc_dirs = _parse_source_include_dirs(source_filelist)

    # ---- Strip all mbist_wrap/rtl_v entries (replaced by fpga_v below) ----
    lines = [ln for ln in lines if "/mbist_wrap/rtl_v/" not in ln.replace("\\", "/")]

    # ---- Replace RTL entries with FPGA / stub entries ---------------------
    # Sort by name length descending so longer names match first; otherwise
    # a shorter name (e.g. "cache_wrap.v") can false-match a longer name
    # (e.g. "cppe_cache_wrap.v") via _replace_file_entry's endswith check.
    for name, full_path in sorted(fpga_files.items(), key=lambda x: len(x[0]), reverse=True):
        lines = _replace_file_entry(lines, name, full_path)

    # ---- Add TB FPGA files ------------------------------------------------
    for tb_path in tb_fpga_paths:
        if tb_path.is_dir():
            for f in sorted(tb_path.iterdir()):
                if f.is_file() and RE_VERILOG_EXT.search(f.suffix):
                    lines = _replace_file_entry(lines, f.name, str(f).replace("\\", "/"))

    # ---- Verify fpga_v file count -----------------------------------------
    # Collect TB fpga_v files (added to filelist in the next step)
    tb_fpga_count = 0
    for tb_path in tb_fpga_paths:
        if tb_path.is_dir():
            for f in tb_path.iterdir():
                if f.is_file() and RE_VERILOG_EXT.search(f.suffix):
                    tb_fpga_count += 1

    fpga_v_count = sum(1 for ln in lines if "fpga_v" in ln)
    expected_count = len(fpga_files) + tb_fpga_count
    if fpga_v_count != expected_count:
        logger.error(
            "fpga_v count mismatch: %d in filelist vs %d expected (design %d + tb %d)",
            fpga_v_count, expected_count, len(fpga_files), tb_fpga_count,
        )
        for name in fpga_files:
            if not any(name in ln and "fpga_v" in ln for ln in lines):
                logger.error("  Missing from filelist: %s", name)

    # ---- Build final output -----------------------------------------------
    header = _build_tcl_header(use_sce, extra_inc_dirs)

    # Append user-defined extra Verilog files
    for extra_path in EXTRA_VERILOG_FILES:
        if extra_path not in lines:
            lines.append(extra_path)

    body = "\n".join(f"read_verilog -sv {ln}" for ln in lines)
    footer = _build_tcl_footer(use_sce)

    output = f"{header}\n{body}\n{footer}\n"

    # Expand Tcl variable references to absolute paths
    output = _expand_tcl_vars(output)

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
            if any(kw in ln for kw in ("tsmc_lib", "gf22_lib", "std_lib", "MEMORY_DIR", "/aip_")):
                continue
            # Skip comments
            if ln.startswith("//"):
                continue
            # Skip incdir / -y directives (handled by _parse_source_include_dirs)
            if "+incdir+" in ln:
                continue
            if ln.startswith("-y "):
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
        stripped = ln.rstrip()
        # Match only when basename is the full file component: must be
        # preceded by "/" or "\" (or be the entire line), otherwise
        # "cache_wrap.v" would falsely match "cppe_cache_wrap.v".
        if stripped.endswith(basename) and (
            stripped == basename or stripped[-(len(basename) + 1)] in ("/", "\\")
        ):
            if not found:
                result.append(new_path)
                found = True
            # else: duplicate -- skip
        else:
            result.append(ln)
    if not found:
        result.append(new_path)
    return result


def _parse_source_include_dirs(path: Path) -> list[str]:
    """Extract ``+incdir+`` and ``-y`` directory paths from source filelist.

    Paths are returned in ``$VAR`` form (expanded later by ``_expand_tcl_vars``).
    ``-y`` paths are resolved to check whether they are directories; files are
    skipped.
    """
    inc_dirs: list[str] = []
    seen: set[str] = set()

    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            ln = raw.strip()
            if not ln or ln.startswith("//"):
                continue
            if "+incdir+" in ln:
                _, _, dir_path = ln.partition("+incdir+")
                dir_path = dir_path.strip()
                if dir_path and dir_path not in seen:
                    seen.add(dir_path)
                    inc_dirs.append(dir_path)
            elif ln.startswith("-y "):
                dir_path = ln[3:].strip()
                if not dir_path:
                    continue
                expanded = _expand_tcl_vars(dir_path)
                if os.path.isdir(expanded) and dir_path not in seen:
                    seen.add(dir_path)
                    inc_dirs.append(dir_path)

    return inc_dirs


def _build_tcl_header(use_sce: bool, extra_include_dirs: list[str] | None = None) -> str:
    """Build the ``set_property include_dirs`` Tcl header.

    Merges static include directories with ``+incdir+`` / ``-y`` paths
    extracted from the source filelist, without duplicates.
    """
    dirs: list[str] = []
    seen: set[str] = set()

    # Extra include directories from config (user-editable)
    for d in EXTRA_INCLUDE_DIRS:
        if d not in seen:
            seen.add(d)
            dirs.append(d)

    if extra_include_dirs:
        for d in extra_include_dirs:
            if d not in seen:
                seen.add(d)
                dirs.append(d)

    lines = ["set_property include_dirs {"]
    for d in dirs:
        lines.append(f"{d} \\")
    lines.append("} [current_fileset]")
    return "\n".join(lines)


def _build_tcl_footer(use_sce: bool) -> str:
    """Return the Tcl footer block."""
    parts = [FPGA_SET_PROPERTY]
    if use_sce:
        parts.append(FPGA_SET_PROPERTY_SCE)
    parts.append(FPGA_XDC_PROPERTY)
    return "\n".join(parts)


def _substitute_env_vars(text: str) -> str:
    """Replace absolute paths with Tcl variable references.

    E.g. ``/proj/common/ip/foo -> $COMMON_IP_DIR/foo``.
    """
    import os
    for env_var, tcl_var in ENV_TO_FILELIST_VAR.items():
        env_val = os.getenv(env_var, "")
        if env_val:
            text = text.replace(env_val, tcl_var)
    return text


def _expand_tcl_vars(text: str) -> str:
    """Replace Tcl-style ``$VAR`` / ``${VAR}`` references with absolute paths.

    E.g. ``${SOC_DESIGN_DIR}/foo -> /proj/soc/design/foo``.

    Paths are normalized to forward slashes for cross-platform consistency.
    """
    import os
    for env_var, _tcl_var in ENV_TO_FILELIST_VAR.items():
        env_val = os.getenv(env_var, "")
        if not env_val:
            continue
        env_val = env_val.replace("\\", "/")
        # Handle ${VAR} form (must precede $VAR to avoid double-match)
        text = text.replace(f"${{{env_var}}}", env_val)
        # Handle $VAR form (no braces)
        text = text.replace(f"${env_var}", env_val)
    return text

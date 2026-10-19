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
    PARAM_PREFIX_DIRS,
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
    # fpga_files: {basename: {parent_dir: full_path}}
    # parent_dir is the absolute normalized directory that CONTAINS fpga_v/.
    # Multiple IP directories may have files with the same basename; the
    # nested dict maps each parent directory to its own fpga_v path so we
    # never cross-replace between different IP trees.
    fpga_files: dict[str, dict[str, str]] = {}

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
                # Absolute, forward-slash parent — the directory containing fpga_v/
                parent = str(root_path.resolve()).replace("\\", "/")
                for f in fpga_dir.iterdir():
                    if f.is_file() and RE_VERILOG_EXT.search(f.suffix):
                        fpga_files.setdefault(f.name, {})[parent] = str(f).replace("\\", "/")

    # ---- Read source filelist ---------------------------------------------
    if not source_filelist.is_file():
        raise FileNotFoundError(f"Source filelist not found: {source_filelist}")

    lines = _read_source_filelist(source_filelist, use_stub_list, stub_files)

    # ---- Parse +incdir+ / -y from source for include_dirs -----------------
    extra_inc_dirs = _parse_source_include_dirs(source_filelist)

    # ---- Collect source parent dirs (before stripping mbist_wrap/rtl_v) ----
    # These are the "grandparent" directories (containing rtl_v/fpga_v/etc.)
    # normalized to absolute paths.  Only fpga_v files whose parent directory
    # appears in this set are eligible for replacement / inclusion.
    source_parents = _extract_source_parents(lines)

    # ---- Strip all mbist_wrap/rtl_v entries (replaced by fpga_v below) ----
    lines = [ln for ln in lines if "/mbist_wrap/rtl_v/" not in ln.replace("\\", "/")]

    # ---- Filter fpga_files to only dirs present in source_parents ---------
    filtered_fpga_files: dict[str, dict[str, str]] = {}
    for name, parent_map in fpga_files.items():
        relevant = {p: fp for p, fp in parent_map.items() if p in source_parents}
        if relevant:
            filtered_fpga_files[name] = relevant

    # ---- Replace RTL entries with FPGA / stub entries ---------------------
    # Sort by name length descending so longer names match first; otherwise
    # a shorter name (e.g. "cache_wrap.v") can false-match a longer name
    # (e.g. "cppe_cache_wrap.v") via _replace_file_entry's endswith check.
    for name, parent_map in sorted(filtered_fpga_files.items(), key=lambda x: len(x[0]), reverse=True):
        lines = _replace_file_entry(lines, name, parent_map, source_parents)

    # ---- Add TB FPGA files ------------------------------------------------
    # TB files use simple basename replacement — they are explicitly
    # provided and always intended to be included regardless of directory.
    for tb_path in tb_fpga_paths:
        if tb_path.is_dir():
            for f in sorted(tb_path.iterdir()):
                if f.is_file() and RE_VERILOG_EXT.search(f.suffix):
                    tb_full = str(f).replace("\\", "/")
                    found = False
                    new_lines: list[str] = []
                    for ln in lines:
                        stripped = ln.rstrip()
                        if stripped.endswith(f.name) and (
                            stripped == f.name or stripped[-(len(f.name) + 1)] in ("/", "\\")
                        ):
                            if not found:
                                new_lines.append(tb_full)
                                found = True
                            # else: duplicate — skip
                        else:
                            new_lines.append(ln)
                    if not found:
                        new_lines.append(tb_full)
                    lines = new_lines

    # ---- Verify fpga_v file count -----------------------------------------
    # Collect TB fpga_v files (added to filelist in the next step)
    tb_fpga_count = 0
    for tb_path in tb_fpga_paths:
        if tb_path.is_dir():
            for f in tb_path.iterdir():
                if f.is_file() and RE_VERILOG_EXT.search(f.suffix):
                    tb_fpga_count += 1

    # Count total fpga_v entries across all filtered parent dirs
    filtered_fpga_total = sum(len(parent_map) for parent_map in filtered_fpga_files.values())
    fpga_v_count = sum(1 for ln in lines if "fpga_v" in ln)
    expected_count = filtered_fpga_total + tb_fpga_count
    if fpga_v_count != expected_count:
        logger.error(
            "fpga_v count mismatch: %d in filelist vs %d expected (design %d + tb %d)",
            fpga_v_count, expected_count, filtered_fpga_total, tb_fpga_count,
        )
        for name, parent_map in filtered_fpga_files.items():
            for full_path in parent_map.values():
                if full_path not in lines:
                    logger.error("  Missing from filelist: %s", full_path)

    # ---- Build final output -----------------------------------------------
    include_dirs = _collect_include_dirs(extra_inc_dirs)
    header = _build_tcl_header(include_dirs)

    # Append user-defined extra Verilog files
    for extra_path in EXTRA_VERILOG_FILES:
        if extra_path not in lines:
            lines.append(extra_path)

    # Comment out -makelib/-endlib directives
    lines = _transform_makelib_directives(lines)

    body = "\n".join(
        ln if ln.startswith("#") else f"read_verilog -sv {ln}"
        for ln in lines
    )
    footer = _build_tcl_footer(use_sce)

    output = f"{header}\n{body}\n{footer}\n"

    # Expand Tcl variable references to absolute paths
    output = _expand_tcl_vars(output)

    output_path.write_text(output, encoding="utf-8")
    logger.info("Wrote FPGA filelist: %s (%d entries)", output_path, len(lines))

    # ---- Generate sim_filelist (覆盖项目根 sim_filelist 模板) -------------
    _generate_sim_filelist(include_dirs, Path("sim_filelist"))

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
            if any(kw in ln for kw in ("tsmc_lib", "gf22_lib", "std_lib", "MEMORY_DIR", "/aip_", "/a_ip_")):
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


def _transform_makelib_directives(lines: list[str]) -> list[str]:
    """Comment out ``-makelib <name>`` / ``-endlib`` directives.

    Directives become ``# ...`` Tcl comments so they are skipped by the FPGA
    tool while the library-bound files between them are still compiled
    normally.
    """
    result: list[str] = []

    for ln in lines:
        if ln.startswith("-makelib "):
            result.append(f"# {ln}")
        elif ln.startswith("-endlib"):
            result.append(f"# {ln}")
        else:
            result.append(ln)

    return result


def _normalize_path(path: str) -> str:
    """Expand Tcl vars and return an absolute, forward-slash path."""
    expanded = _expand_tcl_vars(path)
    return os.path.abspath(expanded).replace("\\", "/")


def _parent_dir_of(path: str) -> str:
    """Return the "grandparent" directory of a file path — the directory
    that *contains* the immediate parent (e.g. ``rtl_v/`` or ``fpga_v/``).

    ``io_lib_c40/rtl_v/xx.v`` → ``<abs>/io_lib_c40``
    ``io_lib_c40/fpga_v/xx.v`` → ``<abs>/io_lib_c40``
    """
    normalized = _normalize_path(path)
    file_dir = os.path.dirname(normalized)
    return os.path.dirname(file_dir)


def _extract_source_parents(lines: list[str]) -> set[str]:
    """Extract unique "grandparent" directories from all filelist paths.

    Only paths whose grandparent is non-empty are kept (bare filenames at
    the filesystem root are skipped).
    """
    parents: set[str] = set()
    for ln in lines:
        path = ln.strip()
        if not path:
            continue
        gp = _parent_dir_of(path)
        if gp:
            parents.add(gp)
    return parents


def _replace_file_entry(
    lines: list[str],
    basename: str,
    parent_map: dict[str, str],
    source_parents: set[str],
) -> list[str]:
    """Replace entries ending with *basename*, but **only within the same
    directory tree**.

    ``parent_map`` maps grandparent-directory → fpga_v full path.
    When a line matches *basename*, its grandparent directory is computed;
    replacement only happens when that grandparent has an entry in
    *parent_map*.  Otherwise the original RTL entry is kept (no cross-IP
    substitution).

    If *basename* doesn't appear in *lines* at all, an fpga_v entry is
    auto-appended **only** when its parent directory appears in
    *source_parents* (i.e. the directory tree is referenced by the source
    filelist).
    """
    result: list[str] = []
    found_any = False

    for ln in lines:
        stripped = ln.rstrip()
        # Match only when basename is the full file component: must be
        # preceded by "/" or "\" (or be the entire line), otherwise
        # "cache_wrap.v" would falsely match "cppe_cache_wrap.v".
        if stripped.endswith(basename) and (
            stripped == basename or stripped[-(len(basename) + 1)] in ("/", "\\")
        ):
            found_any = True
            grandparent = _parent_dir_of(stripped)

            if grandparent in parent_map:
                fpga_path = parent_map[grandparent]
                if fpga_path not in result:
                    result.append(fpga_path)
            else:
                # No fpga_v sibling in this directory tree — keep original
                result.append(ln)
        else:
            result.append(ln)

    if not found_any:
        # Basename not in source filelist at all — auto-append fpga_v only
        # when its directory tree is referenced by the source filelist.
        for parent, full_path in parent_map.items():
            if parent in source_parents and full_path not in result:
                result.append(full_path)

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


def _collect_include_dirs(extra_include_dirs: list[str] | None = None) -> list[str]:
    """合并 EXTRA_INCLUDE_DIRS 与 ``+incdir+``/``-y`` 提取目录，去重后应用 rtl→fpga 替换。"""
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

    # PARAM_PREFIX_DIRS 对应目录的参考目录 → fpga_v（prefix 后 include 改过的 fpga_v/.vh）
    return _rtl_to_fpga_include_dirs(dirs)


def _build_tcl_header(include_dirs: list[str]) -> str:
    """Build the ``set_property include_dirs`` Tcl header."""
    lines = ["set_property include_dirs {"]
    for d in include_dirs:
        lines.append(f"{d} \\")
    lines.append("} [current_fileset]")
    return "\n".join(lines)


# 与 scanner.DesignScanner 的 reference_subdirs 一致：参考 RTL 目录可能叫这些名字
_REF_SUBDIRS = ("rtl_v", "bhv_v", "src")


def _ref_counterparts(fpga_dir: str) -> list[str]:
    """``fpga_v`` 目录 → 同级的参考目录列表（rtl_v / bhv_v / src）。"""
    s = fpga_dir.replace("\\", "/").rstrip("/")
    if not s.endswith("/fpga_v"):
        return []
    parent = s[: -len("/fpga_v")]
    return [f"{parent}/{sub}" for sub in _REF_SUBDIRS]


def _rtl_to_fpga_include_dirs(dirs: list[str]) -> list[str]:
    """把 include_dirs 里 PARAM_PREFIX_DIRS 对应目录的参考目录换成 fpga_v。

    PARAM_PREFIX_DIRS 的 key 是 fpga_v 目录。对每个 key，把 include_dirs 里
    同级的参考目录（rtl_v / bhv_v / src）替换成该 fpga_v 目录——prefix 改过的
    是 fpga_v/.vh，综合时要 include fpga_v 而不是未改的参考目录。
    """
    if not PARAM_PREFIX_DIRS:
        return dirs

    result = list(dirs)
    for fpga_dir in PARAM_PREFIX_DIRS:
        for ref_dir in _ref_counterparts(fpga_dir):
            for i, d in enumerate(result):
                # 归一化到绝对路径比较，兼容 $VAR 与绝对路径混写
                if (
                    _expand_tcl_vars(d).replace("\\", "/").rstrip("/")
                    == _expand_tcl_vars(ref_dir).replace("\\", "/").rstrip("/")
                ):
                    result[i] = fpga_dir
    return result


def _build_tcl_footer(use_sce: bool) -> str:
    """Return the Tcl footer block."""
    parts = [FPGA_SET_PROPERTY]
    if use_sce:
        parts.append(FPGA_SET_PROPERTY_SCE)
    parts.append(FPGA_XDC_PROPERTY)
    return "\n".join(parts)


# sim_filelist 模板里 include_dirs 块： set_property include_dirs { ... } [get_filesets sim_1]
_RE_SIM_INCLUDE_BLOCK = re.compile(
    r"set_property include_dirs \{[\s\S]*?\} \[get_filesets sim_1\]"
)


def _generate_sim_filelist(include_dirs: list[str], path: Path) -> None:
    """生成 sim_filelist：把模板里 include_dirs 块替换为 *include_dirs* 目录。

    模板和输出是同一个文件 *path*（覆盖）。include_dirs 块按正则整体替换，
    不依赖占位符，因此可重复生成（幂等）。目录最后展开成绝对路径，与 filelist.f 一致。
    """
    if not path.is_file():
        logger.warning("sim_filelist template not found: %s -- skipping", path)
        return

    template = path.read_text(encoding="utf-8", errors="replace")
    dir_lines = "\n".join(f"    {d} \\" for d in include_dirs)
    block = "set_property include_dirs {\n" + dir_lines + "\n} [get_filesets sim_1]"

    content = _RE_SIM_INCLUDE_BLOCK.sub(lambda _m: block, template)
    content = _expand_tcl_vars(content)
    path.write_text(content, encoding="utf-8")
    logger.info("Wrote sim_filelist: %s", path)


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

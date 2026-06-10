"""Directory scanner -- unified discovery of RTL / FPGA / stub files.

Replaces the scattered :func:`os.walk` calls and the old ``list_folders``
function with a single, reusable :class:`DesignScanner`.
"""

from __future__ import annotations

import logging
import os
import re
from pathlib import Path
from typing import Iterator, Optional

from .config import RE_STUB_SUFFIX, RE_VERILOG_EXT, SKIP_DIRS

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Verilog instantiation extraction
# ---------------------------------------------------------------------------

# Verilog keywords that are NOT module names (case-insensitive match)
_NON_MODULE_KW: set[str] = {
    "always", "assign", "initial", "if", "else", "for", "while",
    "case", "casex", "casez", "end", "begin", "endcase", "endfunction",
    "endmodule", "endtask", "forever", "fork", "join", "repeat",
    "wait", "wire", "reg", "tri", "logic", "wand", "wor",
    "parameter", "localparam", "input", "output", "inout",
    "genvar", "generate", "endgenerate",
    "specify", "endspecify", "function", "task",
    "buf", "not", "and", "nand", "or", "nor", "xor", "xnor",
    "bufif0", "bufif1", "notif0", "notif1",
    "pullup", "pulldown", "tran", "tranif0", "tranif1",
    "rtran", "rtranif0", "rtranif1", "cmos",
    "pmos", "nmos", "rcmos", "rnmos", "rpmos",
    "supply0", "supply1", "tri0", "tri1", "triand", "trior",
    "trireg", "uwire", "vectored", "scalared",
    "deassign", "defparam", "disable", "event", "force", "release",
    "int", "integer", "real", "realtime", "time", "signed", "unsigned",
    "module", "primitive", "endprimitive", "macromodule",
    "posedge", "negedge", "edge",
    "small", "medium", "large",
    "strong0", "strong1", "pull0", "pull1", "weak0", "weak1",
    "highz0", "highz1",
    "table", "endtable",
    "property", "endproperty", "sequence", "endsequence",
    "assert", "assume", "cover", "restrict",
}

# Regex: module_name #(params) instance_name (  or  module_name instance_name (
# Captures group(1)=module_name, group(2)=instance_name
_INST_RE = re.compile(
    r"^\s*(\w+)\s+"                # module name
    r"(?:"                         # optional parameter override
    r"  \#\s*\([\s\S]*?\)\s*"     # #( ... ) -- lazy, stops at first close-paren
    r")?"
    r"(\w+)\s*\("                   # instance name (then open paren
    r"",
    re.MULTILINE,
)

# Line-comment pattern -- used by backwards-scan fallback
_RE_LINE_COMMENT = re.compile(r"//.*$", re.MULTILINE)
_RE_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.DOTALL)


def _strip_comments(verilog: str) -> str:
    """Remove Verilog ``//`` and ``/* */`` comments, replace with spaces."""
    s = _RE_LINE_COMMENT.sub(lambda m: " " * len(m.group()), verilog)
    s = _RE_BLOCK_COMMENT.sub(lambda m: " " * len(m.group()), s)
    return s


def extract_instances(file_path: Path) -> list[tuple[str, str]]:
    """Parse a Verilog file and return ``(module_name, instance_name)`` pairs
    for every module instantiation found.

    Uses three strategies:
    1.  Regex for simple cases (no nested parens in parameter overrides).
    2.  Backwards-scan for instantiations with ``#( ... ( ... ) ... )``
        parameter blocks (handles nested parentheses).
    3.  Generate-for expansion: instances inside ``generate for`` loops are
        expanded to individual ``block[i].inst`` entries.
    """
    try:
        content = file_path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        logger.warning("Cannot read %s", file_path)
        return []

    result: list[tuple[str, str]] = []
    seen: set[tuple[str, str]] = set()

    # ---- Pass 1: regex (handles ~80% of cases) ------------------------
    for m in _INST_RE.finditer(content):
        mod_name = m.group(1)
        inst_name = m.group(2)
        if mod_name.lower() in _NON_MODULE_KW:
            continue
        if inst_name.lower() in _NON_MODULE_KW:
            continue
        pair = (mod_name, inst_name)
        if pair not in seen:
            seen.add(pair)
            result.append(pair)

    # ---- Pass 2: backwards-scan (handles nested-paren #(...)...)
    cleaned = _strip_comments(content)
    # Negative lookbehind: exclude `.port_name(` named connections
    for m in re.finditer(r"(?<![\.\w])(\w+)\s*\(", cleaned):
        inst_name = m.group(1)
        if inst_name.lower() in _NON_MODULE_KW:
            continue

        # Scan backwards from m.start() to find the module name
        mod_name = _backwards_scan_module(cleaned, m.start())
        if mod_name is None:
            continue
        # Must be a valid Verilog identifier (starts with letter/underscore)
        if not re.match(r"^[a-zA-Z_]\w*$", mod_name):
            continue
        if mod_name.lower() in _NON_MODULE_KW:
            continue
        if mod_name == inst_name:
            continue  # self-reference, not an instantiation

        pair = (mod_name, inst_name)
        if pair not in seen:
            seen.add(pair)
            result.append(pair)

    # ---- Pass 3: expand generate-for loop instances --------------------
    params = _collect_params(cleaned)
    for loop in _find_generate_loops(cleaned, params):
        block = loop["block_name"]
        count = loop["count"]
        body = cleaned[loop["body_start"]:loop["body_end"]]

        for m in re.finditer(r"(?<![\.\w])(\w+)\s*\(", body):
            inst_name = m.group(1)
            if inst_name.lower() in _NON_MODULE_KW:
                continue

            mod_name = _backwards_scan_module(body, m.start())
            if mod_name is None:
                continue
            if not re.match(r"^[a-zA-Z_]\w*$", mod_name):
                continue
            if mod_name.lower() in _NON_MODULE_KW:
                continue
            if mod_name == inst_name:
                continue

            # Remove the flat (non-expanded) entry
            flat_pair = (mod_name, inst_name)
            if flat_pair in seen:
                seen.discard(flat_pair)
                result = [p for p in result if p != flat_pair]

            # Add expanded entries: block[0].inst .. block[N-1].inst
            for i in range(count):
                expanded = f"{block}[{i}].{inst_name}"
                pair = (mod_name, expanded)
                if pair not in seen:
                    seen.add(pair)
                    result.append(pair)

    return result


# ---------------------------------------------------------------------------
# Generate-for loop helpers (used by extract_instances pass 3)
# ---------------------------------------------------------------------------

def _collect_params(content: str) -> dict[str, int]:
    """Parse ``parameter NAME = VALUE`` and ``localparam NAME = VALUE``
    from a Verilog module, returning a name-to-integer map."""
    params: dict[str, int] = {}
    for m in re.finditer(
        r"^\s*(?:parameter|localparam)\s+(\w+)\s*=\s*(\d+)",
        content, re.MULTILINE,
    ):
        params[m.group(1)] = int(m.group(2))
    return params


# Regex to match a generate-for header:   for (VAR = START; VAR <|<= END; ...) begin : BLOCK
_GENFOR_RE = re.compile(
    r"generate\s+"
    r"for\s*\(\s*"
    r"(\w+)\s*=\s*(\d+)\s*;\s*"      # var = start
    r"\1\s*([<>]=?)\s*"              # var op
    r"(\w+)\s*;\s*"                  # bound
    r"\1\s*=\s*\1\s*\+\s*(\d+)\s*"  # var = var + step
    r"\)\s*"
    r"begin\s*:\s*(\w+)"             # begin : block_name
)


def _find_generate_loops(
    content: str, params: dict[str, int],
) -> list[dict]:
    """Find ``generate for`` blocks and return their metadata.

    Returns a list of dicts with keys: ``block_name``, ``count`` (int),
    ``body_start``, ``body_end`` (int offsets into *content*).
    """
    loops: list[dict] = []
    for m in _GENFOR_RE.finditer(content):
        var        = m.group(1)
        start      = int(m.group(2))
        op         = m.group(3)
        end_expr   = m.group(4)
        step       = int(m.group(5))
        block_name = m.group(6)

        # Resolve iteration count
        end_val: int | None = None
        if end_expr.isdigit():
            end_val = int(end_expr)
        elif end_expr in params:
            end_val = params[end_expr]

        if end_val is None:
            continue

        if op == "<":
            count = end_val - start
        elif op == "<=":
            count = end_val - start + 1
        else:  # ">" or ">=" -- unlikely for generate loops
            continue

        if count <= 0:
            continue

        # Locate the body: from just after the header to the matching ``end``
        body_start = m.end()
        body_end = _find_matching_end(content, body_start)
        if body_end is None:
            continue

        loops.append({
            "block_name": block_name,
            "count": count,
            "body_start": body_start,
            "body_end": body_end,
        })

    return loops


def _find_matching_end(text: str, start: int) -> int | None:
    """Find the position of the ``end`` that closes the ``begin`` at *start*.

    Handles nested ``begin`` / ``end`` blocks. Returns the character offset
    of the ``end`` keyword, or ``None`` on failure.
    """
    depth = 1
    pos = start
    while pos < len(text) and depth > 0:
        m = re.search(r"\b(begin|end)\b", text[pos:])
        if not m:
            return None
        kw = m.group(1)
        if kw == "begin":
            depth += 1
        else:
            depth -= 1
            if depth == 0:
                return pos + m.start()
        pos += m.end()
    return None


def _backwards_scan_module(text: str, pos: int) -> str | None:
    """Starting at *pos* (just before ``inst_name (``), scan backwards
    over optional ``#(...)`` parameter block to find the module name.

    Returns the module name string, or ``None`` on failure.
    """
    # Skip whitespace before `(`
    p = pos - 1
    while p >= 0 and text[p] in " \t\r\n":
        p -= 1
    if p < 0:
        return None

    if text[p] == ")":
        # Backtrack over balanced parentheses to find '#('
        depth = 1
        p -= 1
        while p >= 0 and depth > 0:
            if text[p] == ")":
                depth += 1
            elif text[p] == "(":
                depth -= 1
            p -= 1
        if p < 0:
            return None
        # skip whitespace and optional '#'
        while p >= 0 and text[p] in " \t\r\n":
            p -= 1
        if p >= 0 and text[p] == "#":
            p -= 1
        while p >= 0 and text[p] in " \t\r\n":
            p -= 1

    if p < 0:
        return None

    # Read the module name backwards
    end = p
    while p >= 0 and text[p] not in " \t\r\n":
        p -= 1
    start = p + 1
    name = text[start : end + 1]
    return name if name else None


# ---------------------------------------------------------------------------
# Hierarchy module names we look for when listing IPs
# ---------------------------------------------------------------------------

# Explicit hierarchy paths for ``list_hierarchy_ips``.
#
# Each entry is a dotted path using **instance** names (not module names).
# The first token is the top-level module name; every subsequent token is
# an instance name found in the previous level's instantiations.
#
#   "run_top.u_run_int"                 → IPs under run_top → u_run_int
#   "run_top.u_run_int.u_cppe.u_plat"   → IPs under cppe's platform_int
#
# The scanner walks the chain: finds each module's RTL, parses its
# instantiations, locates the next instance, resolves its module to find
# the RTL for the next level, and finally extracts instances from the leaf.
_HIER_MODULES: set[str] = {
    "standby_top",
    "standby_top.u_standby_int",
    "run_top",
    "run_top.u_run_int",
    "run_top.u_run_int.u_cppe",
    "run_top.u_run_int.u_cppe.u_cppe_periph",
    "run_top.u_run_int.u_cppe.u_platform_int",
    "run_top.u_platform_int",
}


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

    @staticmethod
    def _filter_skip_dirs(dirs: list[str]) -> None:
        """Remove *SKIP_DIRS* from *dirs* (in-place) to prevent os.walk descent."""
        to_remove = [d for d in dirs if d in SKIP_DIRS]
        for d in to_remove:
            dirs.remove(d)

    def iter_folders_with_fpga_or_stub(self) -> Iterator[Path]:
        """Yield directories that contain a ``fpga_v`` or ``stub_v`` subdir."""
        for design_dir in self.design_dirs:
            if not design_dir.is_dir():
                continue
            for root, dirs, _files in os.walk(str(design_dir)):
                self._filter_skip_dirs(dirs)
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
            for root, dirs, _files in os.walk(str(design_dir)):
                self._filter_skip_dirs(dirs)
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
            for root, dirs, _files in os.walk(str(design_dir)):
                self._filter_skip_dirs(dirs)
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
    # Hierarchy path resolution (shared by list-ips and strip-ips)
    # ------------------------------------------------------------------

    def _walk_hierarchy_path(self, path: str) -> Path | None:
        """Walk a dotted ``"A.B.C"`` chain and return the RTL path of the leaf.

        The first token is a **module** name (the top).  Every subsequent
        token is an **instance** name found in the previous level's
        instantiations.

        Returns ``None`` if any step in the chain cannot be resolved.
        """
        tokens = path.split(".")
        rtl = self._find_rtl_by_module_name(tokens[0])
        if rtl is None:
            logger.debug("Top module '%s' not found for path '%s'", tokens[0], path)
            return None

        for i, step in enumerate(tokens[1:], start=1):
            instances = self._cached_extract_instances(rtl)
            found_mod = None
            for mod_name, inst_name in instances:
                if inst_name == step:
                    found_mod = mod_name
                    break
            if found_mod is None:
                logger.debug(
                    "Instance '%s' not found in %s (path '%s')",
                    step, tokens[i - 1], path,
                )
                return None
            rtl = self._find_rtl_by_module_name(found_mod)
            if rtl is None:
                logger.debug("No RTL for instance '%s' → module '%s' (path '%s')",
                             step, found_mod, path)
                return None
        return rtl

    def _cached_extract_instances(self, rtl_path: Path) -> list[tuple[str, str]]:
        """Cached wrapper for :func:`extract_instances` — avoids re-parsing
        the same file when walked from multiple hierarchy paths.
        """
        key = str(rtl_path)
        if not hasattr(self, "_inst_cache"):
            self._inst_cache: dict[str, list[tuple[str, str]]] = {}
        if key not in self._inst_cache:
            self._inst_cache[key] = extract_instances(rtl_path)
        return self._inst_cache[key]

    def _find_matching_paths(self, flat_name: str) -> list[str]:
        """Return :data:`_HIER_MODULES` paths whose **leaf module name**
        matches *flat_name* (cached — only walks the hierarchy once).
        """
        if not hasattr(self, "_match_cache"):
            self._match_cache: dict[str, list[str]] = {}
        if flat_name in self._match_cache:
            return self._match_cache[flat_name]

        matches: list[str] = []
        for path in _HIER_MODULES:
            root = path.split(".")[0]
            if self._find_rtl_by_module_name(root) is None:
                logger.debug("  skip '%s': root '%s' not in RTL cache", path, root)
                continue
            logger.debug("  walking: %s", path)
            rtl = self._walk_hierarchy_path(path)
            if rtl is not None and rtl.stem == flat_name:
                matches.append(path)
            else:
                logger.debug("  no match for '%s': leaf=%s", path, rtl.stem if rtl else "(none)")
        self._match_cache[flat_name] = matches
        return matches

    def resolve_fpga_path(self, hier_path: str) -> Path | None:
        """Resolve a hierarchy path to its ``fpga_v`` file.

        **Dotted path** — ``"run_top.u_run_int"`` using instance names
        → ``.../run_int/fpga_v/run_int.sv``.

        **Flat name** — ``"run_int"`` (module name) — is looked up in
        :data:`_HIER_MODULES`.  If *exactly one* entry ends at a module
        with that name, it is used; if zero or more than one, an error
        is logged and the caller must provide an explicit dotted path.
        """
        if "." in hier_path:
            rtl = self._walk_hierarchy_path(hier_path)
            if rtl is None:
                return None
            leaf_stem = rtl.stem
            fpga_dir = rtl.parent.parent / "fpga_v"
            for ext in (".sv", ".v"):
                candidate = fpga_dir / f"{leaf_stem}{ext}"
                if candidate.is_file():
                    return candidate
            logger.debug("No fpga_v file for leaf module '%s'", hier_path)
            return None

        # Flat name — resolve via _HIER_MODULES
        matches = self._find_matching_paths(hier_path)
        if len(matches) == 0:
            logger.error(
                "Module '%s' not found in _HIER_MODULES. "
                "Add it to _HIER_MODULES in scanner.py or use a dotted path.",
                hier_path,
            )
            return None
        if len(matches) > 1:
            logger.error(
                "Ambiguous module name '%s' matches multiple paths: %s. "
                "Use an explicit dotted path (e.g. 'run_top.u_run_int').",
                hier_path, ", ".join(matches),
            )
            return None
        # Single match
        matched = matches[0]
        if "." not in matched:
            # The match IS the flat name itself — look up fpga_v directly
            rtl = self._find_rtl_by_module_name(matched)
            if rtl is None:
                return None
            fpga_dir = rtl.parent.parent / "fpga_v"
            for ext in (".sv", ".v"):
                candidate = fpga_dir / f"{rtl.stem}{ext}"
                if candidate.is_file():
                    return candidate
            return None
        # Dotted match — recurse (won't loop because matched contains ".")
        return self.resolve_fpga_path(matched)

    def list_hierarchy_ips(
        self,
        paths: list[str] | None = None,
    ) -> dict[str, list[tuple[str, str, str]]]:
        """List IPs instantiated under each dotted hierarchy *path*.

        Each path uses **instance** names (e.g. ``run_top.u_run_int``) to
        trace from the top to the leaf module whose instances are extracted.

        Args:
            paths:
                Dotted hierarchy paths (e.g. ``"run_top.run_int"``).
                Defaults to :data:`_HIER_MODULES`.

        Returns:
            Dict keyed by the exact *path* string.  Each value is a list of
            ``(module_name, instance_name, source_path)`` tuples for
            instances found in the leaf module.
        """
        if paths is None:
            paths = sorted(_HIER_MODULES)

        result: dict[str, list[tuple[str, str, str]]] = {}

        for path in paths:
            rtl = self._walk_hierarchy_path(path)
            if rtl is None:
                continue
            instances = extract_instances(rtl)
            result[path] = [(mod, inst, str(rtl)) for mod, inst in instances]

        return result

    # ------------------------------------------------------------------
    # Hierarchy helpers
    # ------------------------------------------------------------------

    def _find_rtl_by_module_name(self, module_name: str) -> Path | None:
        """Locate the RTL source file for *module_name* (cached — only walks
        the design tree once, on the first call).
        """
        if not hasattr(self, "_rtl_name_cache"):
            self._rtl_name_cache: dict[str, Path] = self._build_rtl_cache()
        return self._rtl_name_cache.get(module_name)

    def _build_rtl_cache(self) -> dict[str, Path]:
        """Walk all design dirs once and return ``{module_name: rtl_path}``."""
        logger.info("Building RTL cache — scanning design dirs (this runs once)...")
        cache: dict[str, Path] = {}
        for design_dir in self.design_dirs:
            if not design_dir.is_dir():
                logger.debug("  design dir not found: %s", design_dir)
                continue
            logger.debug("  scanning: %s", design_dir)
            for root, dirs, _files in os.walk(str(design_dir)):
                self._filter_skip_dirs(dirs)
                for rtl_sub in self.ref_subdirs:
                    rtl_dir = Path(root) / rtl_sub
                    if not rtl_dir.is_dir():
                        continue
                    for f in rtl_dir.iterdir():
                        if f.is_file() and f.suffix in (".sv", ".v"):
                            if f.stem not in cache:
                                cache[f.stem] = f
        logger.info("RTL cache built: %d modules", len(cache))
        return cache

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

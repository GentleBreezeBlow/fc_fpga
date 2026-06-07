"""Directory scanner -- unified discovery of RTL / FPGA / stub files.

Replaces the scattered :func:`os.walk` calls and the old ``list_folders``
function with a single, reusable :class:`DesignScanner`.
"""

from __future__ import annotations

import logging
import re
from pathlib import Path
from typing import Iterator, Optional

from .config import RE_STUB_SUFFIX, RE_VERILOG_EXT

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

_HIER_MODULES = {"run_top", "standby_top", "run_int", "standby_int"}


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

    def list_hierarchy_ips(self) -> dict[str, list[tuple[str, str, str]]]:
        """Scan ``run_top``, ``standby_top``, ``run_int``, ``standby_int``
        RTL files and return their instantiated module names.

        Returns:
            A dict keyed by hierarchy module name (e.g. ``"run_top"``).
            Each value is a list of ``(module_name, instance_name, source_path)``
            tuples found in that file.
        """
        result: dict[str, list[tuple[str, str, str]]] = {}

        # Find hierarchy RTL files across all design dirs
        for design_dir in self.design_dirs:
            if not design_dir.is_dir():
                continue
            for root, dirs, _files in design_dir.walk():
                for rtl_sub in self.ref_subdirs:
                    rtl_dir = Path(root) / rtl_sub
                    if not rtl_dir.is_dir():
                        continue
                    for sv_file in sorted(rtl_dir.iterdir()):
                        if not sv_file.is_file():
                            continue
                        if not RE_VERILOG_EXT.search(sv_file.suffix):
                            continue
                        if sv_file.stem in _HIER_MODULES:
                            instances = extract_instances(sv_file)
                            result[sv_file.stem] = [
                                (mod, inst, str(sv_file)) for mod, inst in instances
                            ]

        return result

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

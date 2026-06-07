"""Strip IP instances from fpga_v files -- replace with output tie-offs.

Wraps selected instance blocks with `` `ifdef FPGA_SYN `` (tie outputs to 0)
/ `` `else `` (original instantiation) / `` `endif ``.
"""

from __future__ import annotations

import logging
import re
from pathlib import Path

from .merger import _extract_module_header
from .scanner import DesignScanner

logger = logging.getLogger(__name__)

# ===========================================================================
# Public API
# ===========================================================================

def strip_instances(
    fpga_path: Path,
    inst_names: list[str],
    scanner: DesignScanner,
) -> int:
    """Remove *inst_names* from *fpga_path*, wrapping each with output tie-off.

    For each instance:
    1. Locate its instantiation block in *fpga_path*.
    2. Find the module's RTL source to determine output port directions.
    3. Generate `` `ifdef FPGA_SYN `` assigns (tie outputs to 0) with the
       original instantiation in the `` `else `` branch.
    4. Write back the modified file.

    Returns the number of instances successfully stripped.
    """
    text = fpga_path.read_text(encoding="utf-8", errors="replace")
    fpga_dir = fpga_path.parent

    stripped = 0
    for inst_name in inst_names:
        parsed = _parse_instance_body(text, inst_name)
        if parsed is None:
            logger.warning("Instance '%s' not found in %s", inst_name, fpga_path)
            continue

        text, full_text, start, end, module_name, port_conns = parsed

        # Find module RTL to get output port directions
        rtl_path = _find_module_rtl(module_name, scanner)
        if rtl_path is None:
            logger.warning(
                "Cannot find RTL for module '%s' -- skipping %s",
                module_name, inst_name,
            )
            continue

        outputs = _extract_module_outputs(rtl_path)
        if not outputs:
            logger.warning(
                "No output ports found in %s -- skipping %s",
                rtl_path.name, inst_name,
            )
            continue

        # Build tie-off assigns for output ports
        tie_off_lines: list[str] = []
        for port, signal in port_conns:
            if port in outputs and signal:
                width = _signal_width(signal, text)
                if width is None or width == 1:
                    val = "1'b0"
                else:
                    val = f"{width}'b0"
                tie_off_lines.append(f"assign {signal} = {val};")

        if not tie_off_lines:
            logger.info("No output signals to tie off for %s -- skipping", inst_name)
            continue

        # Generate replacement block — match indentation of the original instance
        # start points to module_name; back up to line start for clean replace
        indent = _indent_of(text, start)
        line_start = text.rfind("\n", 0, start) + 1
        start = line_start
        block_lines = [
            f"{indent}`ifdef FPGA_SYN",
        ]
        for tl in tie_off_lines:
            block_lines.append(f"{indent}{tl}")
        block_lines.append(f"{indent}`else")
        block_lines.append(indent + full_text.lstrip())
        block_lines.append(f"{indent}`endif")

        replacement = "\n".join(block_lines)

        logger.info(
            "Stripping %s (%s) from %s -- %d output(s) tied off",
            inst_name, module_name, fpga_path.name, len(tie_off_lines),
        )

        text = text[:start] + replacement + text[end:]
        stripped += 1

    if stripped > 0:
        fpga_path.write_text(text, encoding="utf-8")

    return stripped


# ===========================================================================
# Instance body parsing
# ===========================================================================

def _parse_instance_body(
    text: str, inst_name: str,
) -> tuple[str, str, int, int, str, list[tuple[str, str]]] | None:
    """Find and parse a Verilog module instantiation.

    Handles both ``module_name inst_name (...);`` and
    ``module_name #(...) inst_name (...);`` (with nested-paren parameter blocks).

    Returns ``(updated_text, full_text, start, end, module_name, port_conns)``
    Returns ``None`` if the instance is not found.
    """
    # 1. Find inst_name followed by (
    pattern = re.compile(
        r"\b" + re.escape(inst_name) + r"\s*\(",
    )
    m = pattern.search(text)
    if not m:
        return None

    # Skip if inside an existing `ifdef FPGA_SYN ... `endif block
    if _inside_fpga_block(text, m.start()):
        return None

    paren_pos = m.end()  # just after the opening (

    # 2. Scan backwards from m.start() to find module_name, skipping #(...)
    module_name, start = _backwards_module_name(text, m.start())
    if module_name is None:
        return None

    # 3. Parse port connections + find closing );
    port_conns, body_end = _parse_port_connections(text, paren_pos)

    full_text = text[start:body_end]

    return (text, full_text, start, body_end, module_name, port_conns)


def _inside_fpga_block(text: str, pos: int) -> bool:
    """Return True if *pos* is inside an `` `ifdef FPGA_SYN `` / `` `endif `` block."""
    before = text[:pos]
    ifdef_count = len(re.findall(r"^\s*`ifdef\s+FPGA_SYN", before, re.MULTILINE))
    endif_count = len(re.findall(r"^\s*`endif\b", before, re.MULTILINE))
    return ifdef_count > endif_count


def _backwards_module_name(text: str, pos: int) -> tuple[str | None, int]:
    """Scan backwards from *pos* to find the module name before an instance.

    Skips over optional ``#(...)`` parameter block with balanced parens.
    Returns ``(module_name, start_offset)`` or ``(None, 0)``.
    """
    p = pos - 1
    # skip whitespace
    while p >= 0 and text[p] in " \t\r\n":
        p -= 1
    if p < 0:
        return None, 0

    # If we hit ')', this is `) inst_name (` — backtrack over #(...)
    if text[p] == ")":
        depth = 0
        while p >= 0:
            if text[p] == ")":
                depth += 1
            elif text[p] == "(":
                depth -= 1
                if depth == 0:
                    p -= 1
                    break
            p -= 1
        if depth != 0:
            return None, 0
        # skip whitespace and optional '#'
        while p >= 0 and text[p] in " \t\r\n":
            p -= 1
        if p >= 0 and text[p] == "#":
            p -= 1
        while p >= 0 and text[p] in " \t\r\n":
            p -= 1

    if p < 0:
        return None, 0

    # Read module name backwards
    end = p
    while p >= 0 and (text[p].isalnum() or text[p] == "_"):
        p -= 1
    start_offset = p + 1
    module_name = text[start_offset:end + 1]
    return (module_name, start_offset)


_PORT_CONN_RE = re.compile(
    r"\.(\w+)\s*\(",
)

def _parse_port_connections(
    text: str, pos: int,
) -> tuple[list[tuple[str, str]], int]:
    """Parse ``.port(signal)`` connections from just inside the ``(``.

    Consumes nested parentheses in signal expressions (e.g. ``.addr(addr[7:0])``).
    Returns ``([(port, signal), ...], end_pos)`` where *end_pos* is after ``);``.
    """
    connections: list[tuple[str, str]] = []
    i = pos

    while i < len(text):
        # Skip whitespace
        while i < len(text) and text[i] in " \t\r\n":
            i += 1

        if i >= len(text):
            break

        ch = text[i]

        if ch == ")":
            # End of port list -- skip to ;
            i += 1
            while i < len(text) and text[i] in " \t\r\n":
                i += 1
            if i < len(text) and text[i] == ";":
                i += 1
            return connections, i

        if ch == ".":
            if i + 1 < len(text) and text[i + 1] == "*":
                # .* -- implicit connection, skip
                i += 2
                while i < len(text) and text[i] in " \t\r\n":
                    i += 1
                if i < len(text) and text[i] == ",":
                    i += 1
                continue

            # .port_name(signal)
            m = _PORT_CONN_RE.match(text, i)
            if m:
                port_name = m.group(1)
                i = m.end()  # just after .port_name(

                # Extract signal expression (balanced parens)
                depth = 1
                sig_start = i
                while i < len(text) and depth > 0:
                    if text[i] == "(":
                        depth += 1
                    elif text[i] == ")":
                        depth -= 1
                    i += 1
                signal = text[sig_start:i - 1].strip()
                connections.append((port_name, signal))

                # Skip optional comma
                while i < len(text) and text[i] in " \t\r\n":
                    i += 1
                if i < len(text) and text[i] == ",":
                    i += 1
                continue

        i += 1

    return connections, i


# ===========================================================================
# Module output-port extraction
# ===========================================================================

_OUTPUT_RE = re.compile(
    r"^\s*output\s+"
    r"(?:reg\s+|wire\s+|logic\s+|tri\s+)?"
    r"(?:signed\s+)?"
    r"(?:\[[^\]]*\]\s+)?"
    r"(\w+)",
    re.MULTILINE,
)


def _extract_module_outputs(rtl_path: Path) -> set[str]:
    """Parse *rtl_path* and return the set of output port names."""
    text = rtl_path.read_text(encoding="utf-8", errors="replace")

    # Strip comments
    text = re.sub(r"//.*$", "", text, flags=re.MULTILINE)
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)

    header = _extract_module_header(text)
    if header is None:
        logger.warning("Cannot parse module header in %s", rtl_path)
        return set()

    header_text = header[0]

    outputs: set[str] = set()
    for m in _OUTPUT_RE.finditer(header_text):
        name = m.group(1)
        if name:
            outputs.add(name)

    return outputs


# ===========================================================================
# RTL file search
# ===========================================================================

def _find_module_rtl(
    module_name: str,
    scanner: DesignScanner,
) -> Path | None:
    """Search for the RTL source of *module_name* across all design dirs."""
    candidates = [f"{module_name}.sv", f"{module_name}.v"]

    for design_dir in scanner.design_dirs:
        if not design_dir.is_dir():
            continue
        for root, dirs, _files in design_dir.walk():
            root_path = Path(root)
            for ref_sub in scanner.ref_subdirs:
                rtl_dir = root_path / ref_sub
                if not rtl_dir.is_dir():
                    continue
                for c in candidates:
                    cpath = rtl_dir / c
                    if cpath.is_file():
                        return cpath

    return None


# ===========================================================================
# Helpers
# ===========================================================================

_SIGNAL_DECL_RE_TEMPLATE = r"(?:input|output|inout|wire|reg|logic|tri)\s+(?:signed\s+)?\[([\w\-\+\*]+)\s*:\s*([\w\-\+\*]+)\]\s*\b{}\b"


def _signal_width(signal: str, text: str) -> int | None:
    """Try to determine the width of *signal* from its declaration.

    Returns the bit-width (e.g. 8), or ``None`` if not determinable.
    """
    base = re.sub(r"\[.*\]", "", signal)  # strip index, e.g. spi_start[2] -> spi_start
    pattern = re.compile(_SIGNAL_DECL_RE_TEMPLATE.format(re.escape(base)))
    m = pattern.search(text)
    if m:
        try:
            msb = int(m.group(1))
            lsb = int(m.group(2))
            if lsb == 0:
                return msb + 1
            return abs(msb - lsb) + 1
        except ValueError:
            return None
    return None  # 1-bit


def _indent_of(text: str, pos: int) -> str:
    """Return the whitespace indentation of the line containing *pos*."""
    line_start = text.rfind("\n", 0, pos)
    if line_start == -1:
        line_start = 0
    else:
        line_start += 1
    # Extract whitespace from line_start to first non-space char
    i = line_start
    while i < len(text) and text[i] in " \t":
        i += 1
    return text[line_start:i]

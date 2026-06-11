"""Strip IP instances from fpga_v files -- replace with output tie-offs.

Wraps selected instance blocks with `` `ifdef FPGA_SYN `` (tie outputs to 0,
or 1 for ``_b``-suffixed active-low ports) / `` `else `` (original
instantiation) / `` `endif ``.
"""

from __future__ import annotations

import fnmatch
import logging
import os
import re
import time
from pathlib import Path

from .config import SKIP_DIRS
from .merger import _extract_module_header
from .scanner import DesignScanner

logger = logging.getLogger(__name__)

# Match "module_name inst_name (" or "module_name #(...) inst_name ("
_RE_INSTANCE = re.compile(
    r"\b(\w+)\s+(?:#\s*\([\s\S]*?\)\s+)?(\w+)\s*\(",
)

# ===========================================================================
# Public API
# ===========================================================================

def _expand_wildcards(text: str, patterns: list[str]) -> list[str]:
    """Expand wildcard patterns (e.g. ``adc*``) against all instance names
    found in *text*.  Non-wildcard entries pass through unchanged.
    """
    # Collect all instance names from the file (skip those inside stripped blocks)
    all_instances: set[str] = set()
    for m in _RE_INSTANCE.finditer(text):
        inst = m.group(2)
        if not _inside_fpga_block(text, m.start()):
            all_instances.add(inst)

    result: list[str] = []
    for pat in patterns:
        if "*" in pat or "?" in pat or "[" in pat:
            expanded = sorted(fnmatch.filter(all_instances, pat))
            if not expanded:
                logger.warning("Wildcard '%s' matched no instances", pat)
            result.extend(expanded)
        else:
            result.append(pat)
    return result


def strip_instances(
    fpga_path: Path,
    inst_names: list[str],
    scanner: DesignScanner,
) -> int:
    """Remove *inst_names* from *fpga_path*, wrapping each with output tie-off.

    *inst_names* may contain shell-style wildcards (``*``, ``?``, ``[...]``).
    Wildcard patterns are expanded against all instance names actually
    present in the file.

    Also **un-strips** any previously stripped instances that are not in
    *inst_names* (removes the ``ifdef FPGA_SYN ... endif`` wrapper and
    restores the original instantiation).

    Returns the number of instances newly stripped.
    """
    text = fpga_path.read_text(encoding="utf-8", errors="replace")
    logger.debug("%s: read %d bytes, %d lines", fpga_path.name, len(text), text.count("\n"))

    # ---- Phase 0: Un-strip ALL previously stripped instances -----------
    # Always un-strip everything so that tie-off format changes, port
    # additions/removals, and _b detection fixes take effect on re-strip.
    t0 = time.time()
    text, unstrip_count = _unstrip_all(text, fpga_path)
    logger.debug("%s: unstrip done in %.2fs, %d un-stripped", fpga_path.name, time.time() - t0, unstrip_count)

    # ---- Phase 1: Expand wildcards --------------------------------------
    expanded_names = _expand_wildcards(text, inst_names)
    logger.debug("%s: wildcard: %d patterns -> %d instances", fpga_path.name, len(inst_names), len(expanded_names))

    # ---- Phase 2: Strip instances ---------------------------------------
    # Pre-warm RTL cache (single walk)
    _build_rtl_cache(scanner)
    stripped = 0
    for inst_name in expanded_names:
        parsed = _parse_instance_body(text, inst_name)
        if parsed is None:
            logger.warning("Instance '%s' not found in %s", inst_name, fpga_path)
            continue

        text, full_text, start, end, module_name, port_conns = parsed

        # Find module RTL to get output port directions (cached)
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
        # Ports ending in _b are active-low — tie to 1 instead of 0
        tie_off_lines: list[str] = []
        for port, signal in port_conns:
            if port in outputs and signal:
                width = _signal_width(signal, text)
                tie_one = port.endswith("_b")
                if width is None or width == 1:
                    val = "1'b1" if tie_one else "'b0"
                else:
                    val = f"{{{width}{{1'b1}}}}" if tie_one else "'b0"
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

    if stripped > 0 or unstrip_count > 0:
        fpga_path.write_text(text, encoding="utf-8")

    return stripped


# ===========================================================================
# Un-strip (restore) instances no longer in the active config
# ===========================================================================

# Matches `` `ifdef FPGA_SYN `` at start of line (with optional whitespace)
_RE_IFDEF_START = re.compile(r"^([ \t]*)`ifdef\s+FPGA_SYN", re.MULTILINE)
_RE_IFDEF_ANY   = re.compile(r"^[ \t]*`ifdef\b", re.MULTILINE)
_RE_ENDIF       = re.compile(r"^[ \t]*`endif\b", re.MULTILINE)

def _extract_instance_from_body(body: str) -> str | None:
    """Extract the instance name from a Verilog instantiation body.

    Handles multi-line ``#(...)`` parameter blocks with nested parentheses.
    Returns the instance name, or ``None`` if parsing fails.
    """
    # Strip comments to avoid false matches
    s = re.sub(r"//.*$", "", body, flags=re.MULTILINE)
    s = re.sub(r"/\*.*?\*/", "", s, flags=re.DOTALL)

    i = 0
    n = len(s)

    # 1. Skip leading whitespace / newlines
    while i < n and s[i] in " \t\r\n":
        i += 1

    # 2. Read module name
    start = i
    while i < n and (s[i].isalnum() or s[i] == "_"):
        i += 1
    if i == start:
        return None
    module_name = s[start:i]

    # 3. Skip whitespace
    while i < n and s[i] in " \t\r\n":
        i += 1

    # 4. Optional #(...) parameter block with balanced parens
    if i < n and s[i] == "#":
        i += 1
        while i < n and s[i] in " \t\r\n":
            i += 1
        if i < n and s[i] == "(":
            depth = 1
            i += 1
            while i < n and depth > 0:
                if s[i] == "(":
                    depth += 1
                elif s[i] == ")":
                    depth -= 1
                i += 1
        # Skip whitespace after #(...)
        while i < n and s[i] in " \t\r\n":
            i += 1

    # 5. Read instance name
    start = i
    while i < n and (s[i].isalnum() or s[i] == "_"):
        i += 1
    if i == start:
        return None
    inst_name = s[start:i]

    # 6. Must be followed by (
    while i < n and s[i] in " \t\r\n":
        i += 1
    if i < n and s[i] == "(":
        return inst_name
    return None


def _find_first_newline(text: str, pos: int) -> int:
    """Return index of the next ``\\n`` after *pos*, or ``len(text)``."""
    nl = text.find("\n", pos)
    return nl if nl != -1 else len(text)


def _strip_block_range(text: str, start: int) -> tuple[int, int, int, str] | None:
    """Find a `` `ifdef FPGA_SYN / `else / `endif `` strip-ips block.

    Uses balanced `` `ifdef `` / `` `endif `` counting to correctly handle
    nested blocks in the body (e.g. RTL-level `` `ifdef FPGA_SYN `` already
    present in the original instantiation).

    Args:
        text: Full file text.
        start: Position of the `` `ifdef FPGA_SYN `` directive.

    Returns:
        ``(wrapper_start, else_pos, endif_pos, indent)`` if a valid
        strip-ips block is found, or ``None``.  Positions are character
        offsets into *text*.
    """
    indent_match = _RE_IFDEF_START.match(text, start)
    if indent_match is None:
        return None
    indent = indent_match.group(1)

    # Walk forward finding `else and matching `endif using balanced counting
    pos = _find_first_newline(text, start) + 1
    depth = 0
    else_pos = -1

    while pos < len(text):
        m_ifdef = _RE_IFDEF_ANY.match(text, pos)
        m_endif = _RE_ENDIF.match(text, pos)

        if m_endif is not None:
            if depth == 0:
                # This endif closes the outer strip block
                if else_pos == -1:
                    return None  # no else found — malformed
                return (start, else_pos, pos, indent)
            depth -= 1
            pos = _find_first_newline(text, pos) + 1
            continue

        if m_ifdef is not None:
            depth += 1
            pos = _find_first_newline(text, pos) + 1
            continue

        # Check for `else at current indent and depth 0
        if depth == 0 and else_pos == -1:
            if text.startswith(f"{indent}`else", pos):
                eol = _find_first_newline(text, pos)
                directive = text[pos:eol].strip()
                if directive == "`else" or directive.startswith("`else "):
                    else_pos = pos
                    pos = eol + 1
                    continue

        pos += 1

    return None  # never found matching endif


def _unstrip_all(text: str, fpga_path: Path) -> tuple[str, int]:
    """Remove ALL ``ifdef FPGA_SYN ... endif`` wrappers, restoring original
    instantiations.  The caller is responsible for re-stripping any
    instances that should remain wrapped.

    Returns ``(modified_text, unstrip_count)``.
    """
    unstrip_count = 0
    changed = True
    loop_count = 0
    while changed:
        loop_count += 1
        if loop_count > 1000:
            logger.error("Unstrip loop exceeded 1000 iterations — possible infinite loop, aborting")
            break
        changed = False
        # Re-scan from start each iteration (text may have been modified)
        block_count = 0
        for m_ifdef in _RE_IFDEF_START.finditer(text):
            block_count += 1
            start = m_ifdef.start()
            block = _strip_block_range(text, start)
            if block is None:
                continue
            wrapper_start, else_pos, endif_pos, indent = block

            # Body: starts right after the `else line, ends before the `endif line
            body_start = _find_first_newline(text, else_pos) + 1
            body = text[body_start:endif_pos].rstrip("\n")
            body_stripped = body.strip()
            if not body_stripped:
                continue

            # Try to find instance name from the body
            inst_name = _extract_instance_from_body(body_stripped)
            if inst_name is None:
                continue

            # Un-strip it — restore original instantiation
            logger.info(
                "Un-stripping %s from %s (will re-strip if still in config)",
                inst_name, fpga_path.name,
            )
            # Replace entire block (ifdef→endif) with just the body
            endif_end = _find_first_newline(text, endif_pos) + 1
            text = text[:wrapper_start] + body_stripped + "\n" + text[endif_end:]
            unstrip_count += 1
            changed = True
            break  # restart iteration after modifying text
        logger.debug("Unstrip loop %d: scanned %d ifdef blocks, unstrip total=%d",
                     loop_count, block_count, unstrip_count)
    return text, unstrip_count


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
    # 1. Find inst_name followed by ( — skip matches inside comments or
    #    existing `ifdef FPGA_SYN blocks (which can appear verbatim in 1000+
    #    line files with many commented-out instances).
    pattern = re.compile(
        r"\b" + re.escape(inst_name) + r"\s*\(",
    )
    search_start = 0
    m = None
    while True:
        m = pattern.search(text, search_start)
        if not m:
            return None
        if _inside_comment(text, m.start()) or _inside_fpga_block(text, m.start()):
            search_start = m.end()
            continue
        break

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


def _inside_comment(text: str, pos: int) -> bool:
    """Return True if *pos* is inside a ``//`` or ``/* */`` comment."""
    # Line comment: find // before pos on the same line
    line_start = text.rfind("\n", 0, pos)
    if line_start == -1:
        line_start = 0
    else:
        line_start += 1
    comment_start = text.find("//", line_start)
    if comment_start != -1 and comment_start < pos:
        return True

    # Block comment: pos is between /* and the next */
    block_start = text.rfind("/*", 0, pos)
    if block_start != -1:
        block_end = text.find("*/", block_start + 2)
        if block_end == -1 or block_end > pos:
            return True

    return False


def _skip_backwards_comments(text: str, p: int) -> int:
    """Skip backwards over ``//`` and ``/**/`` comments starting from *p*.

    If *p* points inside a comment, skip back to before the comment start.
    Returns the new position (may be unchanged if not in a comment).
    """
    # Check for block comment */ — skip back to /*
    if p >= 2 and text[p - 1:p + 1] == "*/":
        # Find matching /*
        while p >= 1:
            if text[p - 1:p + 1] == "/*":
                p -= 2
                while p >= 0 and text[p] in " \t\r\n":
                    p -= 1
                break
            p -= 1
        return p

    # Check for line comment // — skip back to before // on the same line
    # Scan backwards to line start, check if // precedes this position
    line_start = text.rfind("\n", 0, p)
    if line_start == -1:
        line_start = 0
    else:
        line_start += 1
    # Find // between line_start and p
    comment_start = text.find("//", line_start)
    if comment_start != -1 and comment_start < p:
        # p is after // on this line — skip to before //
        p = comment_start - 1
        while p >= 0 and text[p] in " \t\r\n":
            p -= 1
    return p


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

    # Skip backwards past line comments (//...) and block comments (/* */)
    # so they don't inject words like "worse" into the module name.
    p = _skip_backwards_comments(text, p)
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

    def _skip_forward_comments(i: int) -> int:
        """Skip ``//...`` or ``/*...*/`` comment starting at *i*.  Returns new *i*."""
        if text[i:i + 2] == "//":
            nl = text.find("\n", i)
            return nl + 1 if nl != -1 else len(text)
        if text[i:i + 2] == "/*":
            end = text.find("*/", i + 2)
            return end + 2 if end != -1 else len(text)
        return i

    while i < len(text):
        # Skip whitespace
        while i < len(text) and text[i] in " \t\r\n":
            i += 1

        if i >= len(text):
            break

        # Skip comments (may contain parens that would confuse the parser)
        prev = i
        i = _skip_forward_comments(i)
        if i != prev:
            continue

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

                # Extract signal expression (balanced parens, comment-safe)
                depth = 1
                sig_start = i
                while i < len(text) and depth > 0:
                    prev_i = i
                    i = _skip_forward_comments(i)
                    if i != prev_i:
                        continue
                    if text[i] == "(":
                        depth += 1
                    elif text[i] == ")":
                        depth -= 1
                    i += 1
                signal = text[sig_start:i - 1].strip()
                connections.append((port_name, signal))

                # Skip optional comma (and any trailing comment)
                while i < len(text) and text[i] in " \t\r\n":
                    i += 1
                prev_i = i
                i = _skip_forward_comments(i)
                if i != prev_i:
                    while i < len(text) and text[i] in " \t\r\n":
                        i += 1
                if i < len(text) and text[i] == ",":
                    i += 1
                    # Skip whitespace / comments after the comma too
                    while i < len(text) and text[i] in " \t\r\n":
                        i += 1
                    i = _skip_forward_comments(i)
                continue

        i += 1

    return connections, i


# ===========================================================================
# Module output-port extraction
# ===========================================================================

_OUTPUT_RE = re.compile(
    r"\boutput\s+"
    r"(?:reg\s+|wire\s+|logic\s+|tri\s+)?"
    r"(?:signed\s+)?"
    r"(?:\[[^\]]*\]\s+)?"
    r"(\w+)",
)


def _extract_module_outputs(rtl_path: Path) -> set[str]:
    """Parse *rtl_path* and return the set of output port names.

    Handles both ANSI-style ports (``module foo(input a, output b);``) and
    non-ANSI style (``module foo(a,b); output b;``) where port directions
    are declared after the ``);``.
    """
    text = rtl_path.read_text(encoding="utf-8", errors="replace")

    # Strip comments
    text = re.sub(r"//.*$", "", text, flags=re.MULTILINE)
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)

    header = _extract_module_header(text)
    if header is None:
        logger.warning("Cannot parse module header in %s", rtl_path)
        logger.debug("  First 200 chars of %s:\n%s", rtl_path.name, text[:200])
        return set()

    header_text = header[0]

    _KEYWORDS = {"input", "output", "inout", "reg", "wire", "logic", "tri",
                 "signed", "supply", "wand", "wor", "begin", "end"}
    _OUTPUT_BLOCK_RE = re.compile(r"\boutput\b", re.MULTILINE)

    outputs: set[str] = set()
    # Match each output block (from "output" to ";") and extract all
    # identifiers — handles multi-line comma-separated port lists like:
    #   output [7:0] can_byte_7_0,
    #                can_byte_15_8;
    def _extract_names(region: str) -> set[str]:
        """Extract port names from an output-block region.

        Strips bracket expressions ``[...]`` first so that width parameters
        and bit indices (``DATA_WIDTH``, ``0``, ``1``) don't pollute the set.
        """
        # Remove everything inside [...] (handles nested brackets)
        cleaned = re.sub(r"\[[^\[\]]*\]", "", region)
        names: set[str] = set()
        for m_id in re.finditer(r"\b(\w+)\b", cleaned):
            n = m_id.group(1)
            if n not in _KEYWORDS and not n.isdigit():
                names.add(n)
        return names

    _INPUT_RE = re.compile(r"\binput\b", re.MULTILINE)
    _INOUT_RE = re.compile(r"\binout\b", re.MULTILINE)

    for m_out in _OUTPUT_BLOCK_RE.finditer(header_text):
        block_start = m_out.start()
        # Stop at the next direction keyword before stopping at ";"
        block_end = len(header_text)
        for end_re in (_INPUT_RE, _INOUT_RE, re.compile(r";")):
            m_end = end_re.search(header_text, block_start + len("output"))
            if m_end and m_end.start() < block_end:
                block_end = m_end.start()
        block = header_text[block_start:block_end]
        outputs |= _extract_names(block)

    if outputs:
        logger.debug("  %s: ANSI header outputs: %s", rtl_path.name, sorted(outputs))
        return outputs

    # ---- Non-ANSI fallback: port directions declared after ); -----------
    # Scan up to 200 lines after ); — only stop at real body items.
    header_end = header[2]  # offset of ); in the original text
    body_region = ""
    lines = text[header_end:].split("\n")
    _STOP_RE = re.compile(r"\b(assign|always|endmodule|genvar|generate)\b")
    in_port_decl = False
    for ln in lines[:200]:
        stripped = ln.strip()
        if not stripped:
            body_region += ln + "\n"
            continue
        if in_port_decl:
            # Continuation of a multi-line port declaration (e.g. port names
            # on lines after "output [7:0] foo,")
            body_region += ln + "\n"
            if ";" in stripped:
                in_port_decl = False
            continue
        # Skip parameter/localparam/signal decl — they can appear between ); and ports
        if re.match(r"\b(parameter|localparam|wire|reg|logic|tri|signed)\b", stripped):
            continue
        # Stop at real body items
        if _STOP_RE.match(stripped):
            break
        if re.match(r"\b(input|output|inout)\b", stripped):
            body_region += ln + "\n"
            # Handle multi-line port declarations: keep appending until we see ";"
            if ";" not in stripped:
                in_port_decl = True
        else:
            # Non-port, non-decl line that doesn't look like a stop — skip
            continue

    for m_out in _OUTPUT_BLOCK_RE.finditer(body_region):
        block_start = m_out.start()
        semicolon = body_region.find(";", block_start)
        if semicolon == -1:
            semicolon = len(body_region)
        block = body_region[block_start:semicolon]
        outputs |= _extract_names(block)

    if not outputs:
        logger.debug(
            "  %s: no outputs found in header or body!\n"
            "  header (%d chars): %s\n"
            "  body region (%d chars): %s\n"
            "  first 300 chars of file:\n%s",
            rtl_path.name,
            len(header_text), header_text.strip()[:150],
            len(body_region), body_region.strip()[:150],
            rtl_path.read_text(encoding="utf-8", errors="replace")[:300],
        )

    return outputs


# ===========================================================================
# RTL file search
# ===========================================================================

# Module-name → RTL path cache (built once per session)
_rtl_cache: dict[str, Path] | None = None


def _build_rtl_cache(scanner: DesignScanner) -> dict[str, Path]:
    """Walk all design dirs once, return ``{module_name: rtl_path}``."""
    global _rtl_cache
    if _rtl_cache is not None:
        return _rtl_cache
    cache: dict[str, Path] = {}
    for design_dir in scanner.design_dirs:
        if not design_dir.is_dir():
            continue
        for root, dirs, _files in os.walk(str(design_dir)):
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            root_path = Path(root)
            for ref_sub in scanner.ref_subdirs:
                rtl_dir = root_path / ref_sub
                if not rtl_dir.is_dir():
                    continue
                for f in rtl_dir.iterdir():
                    if not f.is_file():
                        continue
                    if f.suffix not in (".sv", ".v"):
                        continue
                    stem = f.stem
                    if stem not in cache:
                        cache[stem] = f
    _rtl_cache = cache
    logger.info("RTL cache built: %d modules", len(cache))
    return cache


def _find_module_rtl(
    module_name: str,
    scanner: DesignScanner,
) -> Path | None:
    """Search for the RTL source of *module_name* across all design dirs (cached)."""
    cache = _build_rtl_cache(scanner)
    return cache.get(module_name)


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

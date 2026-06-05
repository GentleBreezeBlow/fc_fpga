"""Memory-port extraction and FPGA SP-RAM instantiation generation.

Fixes the broken ``gen_mbist_fpgafiles()`` from the original script by:
1. Separating port extraction (pure computation) from code generation.
2. Returning structured data instead of printing + immediately deleting.
3. Producing FPGA single-port RAM instantiations for each memory port found.

Also generates complete FPGA wrapper files (mbist_wrap/fpga_v from rtl_v)
with ``fpga_spram`` instances replacing vendor memory primitives.
"""

from __future__ import annotations

import logging
import re
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

from .config import MEM_PORT_PATTERNS, RE_MODULE, RE_PORT

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

@dataclass
class MemoryPort:
    """A single memory interface extracted from a Verilog wrapper."""

    index: int
    clk: str = ""
    addr: str = ""
    addr_width: int = 1
    me: str = ""
    ram_we: str = ""
    wdata: str = ""
    wdata_width: int = 1
    rdata: str = ""
    rdata_width: int = 1
    mem_depth: int = 2

    def to_spram_instantiation(self) -> str:
        """Generate a Verilog ``fpga_spram`` instantiation for this port."""
        return (
            f"fpga_spram #(\n"
            f"    .MEMDEPTH ({self.mem_depth}),\n"
            f"    .MEMWIDTH ({self.rdata_width}),\n"
            f"    .BYTEWIDTH(8),\n"
            f"    .ADDRWIDTH({self.addr_width}),\n"
            f"    .MEMTYPE (\"block\" )\n"
            f")\n"
            f"mem_{self.index}(\n"
            f"    .ram_clk  ({self.clk}),\n"
            f"    .ram_addr ({self.addr}),\n"
            f"    .ram_me   ({self.me}),\n"
            f"    .ram_we   ({self.ram_we}),\n"
            f"    .ram_wdata({self.wdata}),\n"
            f"    .ram_rdata({self.rdata})\n"
            f");"
        )


@dataclass
class MemoryWrapperResult:
    """Complete parse result for one memory wrapper file."""

    file_path: Path
    module_name: str = ""
    ports: list[MemoryPort] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def extract_memory_ports(file_path: Path) -> MemoryWrapperResult:
    """Parse a memory-wrapper Verilog file and extract memory ports.

    This function returns structured data — unlike the original script it
    does NOT delete the results after computing them.

    Returns:
        :class:`MemoryWrapperResult` with the module name and discovered ports.
    """
    result = MemoryWrapperResult(file_path=file_path)

    try:
        content = file_path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        logger.error("Cannot read %s: %s", file_path, exc)
        return result

    # Extract module name
    mod_match = RE_MODULE.search(content)
    if not mod_match:
        logger.warning("No module declaration found in %s", file_path)
        return result

    result.module_name = mod_match.group(1)
    ports_text = mod_match.group(2)

    # Parse ports
    ports_raw = _parse_port_list(ports_text)
    mem_groups = _classify_memory_ports(ports_raw)

    if not mem_groups:
        logger.warning("No memory ports found in %s", file_path)
        return result

    logger.info("%s: found %d memory port(s)", file_path.name, len(mem_groups))

    is_rom = "rom" in file_path.stem.lower()

    for idx, signals in mem_groups.items():
        port = _build_memory_port(idx, signals, is_rom, file_path)
        if port:
            result.ports.append(port)

    return result


def generate_fpga_memory_file(
    wrapper_path: Path,
    output_dir: Path,
) -> Optional[Path]:
    """Full pipeline: parse wrapper → generate SP-RAM → write output file.

    Returns the path to the generated file, or ``None`` if no ports found.
    """
    result = extract_memory_ports(wrapper_path)
    if not result.ports:
        return None

    output_path = output_dir / f"{result.module_name}_fpga_mem.v"
    lines: list[str] = [
        "// Auto-generated FPGA memory instantiations\n",
        f"// Source: {wrapper_path}\n",
        "// Generator: fpga_core.memory\n",
        "\n",
    ]

    for port in result.ports:
        lines.append(port.to_spram_instantiation())
        lines.append("\n")

    output_path.write_text("".join(lines), encoding="utf-8")
    logger.info("Wrote FPGA memory file: %s", output_path)
    return output_path


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _parse_port_list(text: str) -> list[tuple[str, int, str]]:
    """Extract (name, width, range_str) tuples from a Verilog port list."""
    ports: list[tuple[str, int, str]] = []
    pos = 0
    while pos < len(text):
        m = RE_PORT.search(text, pos)
        if not m:
            break
        name = m.group(5)
        msb_str = m.group(3)
        lsb_str = m.group(4)
        if msb_str is not None and lsb_str is not None:
            width = abs(int(msb_str) - int(lsb_str)) + 1
            range_str = f"[{msb_str}:{lsb_str}]"
        else:
            width = 1
            range_str = ""
        ports.append((name, width, range_str))
        pos = m.end()
        # Skip commas / whitespace
        while pos < len(text) and text[pos] in ",\t\n\r ":
            pos += 1
    return ports


def _classify_memory_ports(
    ports: list[tuple[str, int, str]],
) -> dict[int, dict[str, tuple[str, int, str]]]:
    """Group ports by memory instance index using naming conventions."""
    groups: dict[int, dict[str, tuple[str, int, str]]] = defaultdict(dict)
    for name, width, range_str in ports:
        for sig_type, pat in MEM_PORT_PATTERNS.items():
            if pat.search(name):
                # Extract trailing index number
                num_match = re.search(r"(\d+)$", name)
                idx = int(num_match.group(1)) if num_match else 0
                groups[idx][sig_type] = (name, width, range_str)
                break
    return dict(groups)


def _build_memory_port(
    idx: int,
    signals: dict[str, tuple[str, int, str]],
    is_rom: bool,
    file_path: Path,
) -> Optional[MemoryPort]:
    """Construct a :class:`MemoryPort` from classified signals."""

    # Required signals
    if "addr" not in signals or "clk" not in signals or "q" not in signals:
        logger.debug("Port %d in %s missing required signals (addr/clk/q), skipping", idx, file_path)
        return None

    addr_name, addr_width, addr_range = signals["addr"]
    clk_name, _, _ = signals["clk"]
    q_name, q_width, q_range = signals["q"]

    port = MemoryPort(
        index=idx,
        clk=clk_name,
        addr=addr_name + addr_range,
        addr_width=addr_width,
        mem_depth=1 << addr_width,
        rdata=q_name + q_range,
        rdata_width=q_width,
    )

    # Data
    if "data" in signals:
        d_name, d_width, d_range = signals["data"]
        port.wdata = d_name + d_range
        port.wdata_width = d_width

    # Memory enable
    if "cen" in signals:
        port.me = "~" + signals["cen"][0]
    elif "me" in signals:
        port.me = signals["me"][0]
    else:
        port.me = "1'b1"

    # Write enable
    if "wen" not in signals and "gwen" in signals:
        port.ram_we = "~" + signals["gwen"][0]
    elif "wen" in signals and "gwen" not in signals:
        port.ram_we = "~" + signals["wen"][0]
    elif "wen" in signals and "gwen" in signals:
        # Both bit-write-enable and global-write-enable present —
        # use the global write enable (gwen) as the single-bit ram_we.
        port.ram_we = "~" + signals["gwen"][0]
    else:
        port.ram_we = "1'b0"

    # ROM data
    if is_rom:
        port.wdata = port.wdata or "rom_data"

    return port


# ---------------------------------------------------------------------------
# FPGA wrapper generation (mbist_wrap/rtl_v → mbist_wrap/fpga_v)
# ---------------------------------------------------------------------------

def _find_module_declaration(content: str):
    """Extract module name, full header text, and port-list text.

    Returns ``(module_name, module_header, port_list_text)`` or
    ``(None, None, None)`` on failure.
    """
    m = re.search(r"\bmodule\s+(\w+)", content)
    if not m:
        return None, None, None

    module_name = m.group(1)

    # Find the ); that closes the port list — search from module keyword
    end_match = re.search(r"\)\s*;", content[m.start():])
    if not end_match:
        return None, None, None

    header_end = m.start() + end_match.end()
    module_header = content[m.start():header_end]

    # The port list is the last ( ... ) in the header — work backwards
    close_paren = m.start() + end_match.start()
    depth = 0
    open_paren = -1
    for i in range(close_paren - 1, m.start(), -1):
        if content[i] == ")":
            depth += 1
        elif content[i] == "(":
            if depth == 0:
                open_paren = i
                break
            depth -= 1

    if open_paren == -1:
        return None, None, None

    port_list_text = content[open_paren + 1 : close_paren]
    return module_name, module_header, port_list_text


def _parse_ports_with_direction(
    port_list_text: str,
) -> list[dict]:
    """Parse a Verilog port list, returning each port's direction, name, width.

    Returns a list of dicts with keys: ``direction``, ``name``, ``width``,
    ``range_str``.
    """
    ports: list[dict] = []
    pos = 0
    while pos < len(port_list_text):
        m = RE_PORT.search(port_list_text, pos)
        if not m:
            break
        direction = m.group(1)
        msb_str = m.group(3)
        lsb_str = m.group(4)
        name = m.group(5)

        if msb_str is not None and lsb_str is not None:
            width = abs(int(msb_str) - int(lsb_str)) + 1
            range_str = f"[{msb_str}:{lsb_str}]"
        else:
            width = 1
            range_str = ""

        ports.append({
            "direction": direction,
            "name": name,
            "width": width,
            "range_str": range_str,
        })
        pos = m.end()
        # Skip commas / whitespace
        while pos < len(port_list_text) and port_list_text[pos] in ",\t\n\r ":
            pos += 1
    return ports


def generate_fpga_wrapper(
    wrapper_path: Path,
    output_dir: Path,
) -> Optional[Path]:
    """Generate a complete FPGA wrapper file from a memory-wrapper source.

    Reads the RTL wrapper from *wrapper_path*, extracts the module header and
    memory ports, then writes a same-named file to *output_dir* with:

    - The original module declaration (port list preserved verbatim).
    - ``fpga_spram`` instantiations for every memory port found.
      Memory blocks are identified by counting ``clk_N`` signals — each
      distinct *N* suffix becomes one block, regardless of whether
      ``q_N`` is present in the port list.
    - Dummy wire declarations for any memory block missing its ``q`` output.
    - Default assignments (``'b0``) for non-memory output ports.

    Returns the path to the generated file, or ``None`` if the source could
    not be parsed or no memory ports were found.
    """
    try:
        content = wrapper_path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        logger.error("Cannot read %s: %s", wrapper_path, exc)
        return None

    # 1. Extract module declaration ------------------------------------------
    module_name, module_header, port_list_text = _find_module_declaration(content)
    if module_name is None:
        logger.warning("Cannot parse module declaration in %s", wrapper_path)
        return None

    # 2. Parse all ports with direction --------------------------------------
    all_ports = _parse_ports_with_direction(port_list_text)

    # 3. Classify signals by trailing index, then build ports per clk_N ------
    ports_for_classify = [(p["name"], p["width"], p["range_str"]) for p in all_ports]
    mem_groups = _classify_memory_ports(ports_for_classify)

    # --- Determine block count from clk_N signals ---------------------------
    clk_indices: set[int] = set()
    for idx, signals in mem_groups.items():
        if "clk" in signals:
            clk_indices.add(idx)

    if not clk_indices:
        logger.warning("No clk_* ports found in %s", wrapper_path)
        return None

    logger.info(
        "%s: found %d clk_N signal(s) → %d memory block(s)",
        wrapper_path.name, len(clk_indices), len(clk_indices),
    )

    # 4. Build MemoryPort objects per block ----------------------------------
    is_rom = "rom" in wrapper_path.stem.lower()
    memory_ports: list[MemoryPort] = []
    mem_signal_names: set[str] = set()
    dummy_wires: list[str] = []  # wire declarations for blocks missing q

    for idx in sorted(clk_indices):
        signals = mem_groups.get(idx, {})

        # Must have at least clk + addr
        if "addr" not in signals:
            logger.debug("Block %d missing addr, skipping", idx)
            continue

        addr_name, addr_width, addr_range = signals["addr"]
        clk_name, _, _ = signals["clk"]

        # --- rdata (q) — may be absent; generate dummy wire if needed -------
        if "q" in signals:
            q_name, q_width, q_range = signals["q"]
        else:
            # No q_N port → declare a local wire for ram_rdata
            q_width = signals.get("data", (None, addr_width, ""))[1] if "data" in signals else addr_width
            q_name = f"fpga_q_{idx}"
            q_range = f"[{q_width - 1}:0]" if q_width > 1 else ""
            dummy_wires.append(
                f"wire {q_range} {q_name};" if q_range
                else f"wire {q_name};"
            )

        port = MemoryPort(
            index=idx,
            clk=clk_name,
            addr=addr_name + addr_range,
            addr_width=addr_width,
            mem_depth=1 << addr_width,
            rdata=q_name + q_range,
            rdata_width=q_width,
        )

        # --- wdata (d) ------------------------------------------------------
        if "data" in signals:
            d_name, d_width, d_range = signals["data"]
            port.wdata = d_name + d_range
            port.wdata_width = d_width
        elif not is_rom:
            # No data port (unusual but handle gracefully)
            port.wdata = f"{{{port.rdata_width}{{1'b0}}}}"
            port.wdata_width = port.rdata_width

        # --- Memory enable (cen) --------------------------------------------
        if "cen" in signals:
            port.me = "~" + signals["cen"][0]
        elif "me" in signals:
            port.me = signals["me"][0]
        else:
            port.me = "1'b1"

        # --- Write enable (gwen preferred over wen) -------------------------
        if "gwen" in signals:
            port.ram_we = "~" + signals["gwen"][0]
        elif "wen" in signals:
            port.ram_we = "~" + signals["wen"][0]
        else:
            port.ram_we = "1'b0"

        # --- ROM fix-up -----------------------------------------------------
        if is_rom:
            port.wdata_width = port.rdata_width
            port.wdata = f"{{{port.rdata_width}{{1'b0}}}}"

        memory_ports.append(port)

        # Track port names consumed by spram instances
        for _sig_type, (name, _w, _rng) in signals.items():
            mem_signal_names.add(name)

    if not memory_ports:
        logger.warning("No usable memory blocks in %s", wrapper_path)
        return None

    # 5. Default assignments for non-memory outputs --------------------------
    default_assignments: list[str] = []
    for p in all_ports:
        if p["direction"] not in ("output", "inout"):
            continue
        if p["name"] in mem_signal_names:
            continue
        if p["width"] > 1:
            default_assignments.append(
                f"assign {p['name']} = {{{p['width']}{{1'b0}}}};"
            )
        else:
            default_assignments.append(f"assign {p['name']} = 1'b0;")

    # 6. Build output file ---------------------------------------------------
    lines: list[str] = []
    lines.append(f"// {wrapper_path.name} -- FPGA version (auto-generated)")
    lines.append(f"// Source: {wrapper_path}")
    lines.append(f"// Generator: fpga_core.memory")
    lines.append("")
    lines.append(module_header)

    if dummy_wires:
        lines.append("")
        lines.append("  // Dummy wires for blocks missing q output")
        for dw in dummy_wires:
            lines.append(f"  {dw}")

    if default_assignments:
        lines.append("")
        lines.append("  // Default assignments (non-memory ports)")
        for da in default_assignments:
            lines.append(f"  {da}")

    if memory_ports:
        lines.append("")
        lines.append("  // FPGA memory instantiations")
        for mp in memory_ports:
            lines.append("")
            inst = mp.to_spram_instantiation()
            for inst_line in inst.split("\n"):
                lines.append(f"  {inst_line}")

    lines.append("")
    lines.append("endmodule")
    lines.append("")

    # 7. Write output --------------------------------------------------------
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / wrapper_path.name
    output_path.write_text("\n".join(lines), encoding="utf-8")
    logger.info("Wrote FPGA wrapper: %s", output_path)
    return output_path

"""Memory-port extraction and FPGA SP-RAM instantiation generation.

Fixes the broken ``gen_mbist_fpgafiles()`` from the original script by:
1. Separating port extraction (pure computation) from code generation.
2. Returning structured data instead of printing + immediately deleting.
3. Producing FPGA single-port RAM instantiations for each memory port found.
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
        # Both wen and gwen — special case for FLEXCAN etc.
        if q_width == 104 and "flexcan" in str(file_path).lower():
            port.ram_we = "/* manual — FLEXCAN */"
        else:
            port.ram_we = "/* TODO: wen+gwen */"
    else:
        port.ram_we = "1'b0"

    # ROM data
    if is_rom:
        port.wdata = port.wdata or "rom_data"

    return port

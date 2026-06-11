"""Configuration management for FPGA tools.

Centralizes all path resolution, environment variable reading, regex patterns,
and Tcl template strings that are shared across modules.
"""

import os
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

# =============================================================================
# Stub IP list — add IP names here to replace real RTL with stub_v
# e.g. STUB_IPS = ["dip_sce", "dip_can"]
# =============================================================================
STUB_IPS: list[str] = ["dft_cggroup"]

# =============================================================================
# Extra include directories — appended to set_property include_dirs in filelist.f
# e.g. EXTRA_INCLUDE_DIRS = ["$CPPE_CPUSYSTEM_DIR/CORTEXM4/rtl_v", "$COMMON_IP_DIR/dip_sce/rtl_v"]
# =============================================================================
EXTRA_INCLUDE_DIRS: list[str] = [
    "$CPPE_CPUSYSTEM_DIR/CORTEXM4/rtl_v",
    "$COMMON_IP_DIR/dip_sce/rtl_v",
]

# =============================================================================
# Extra Verilog files — appended as read_verilog -sv entries in filelist.f
# e.g. EXTRA_VERILOG_FILES = ["$COMMON_IP_DIR/dip_hsm/rtl_v/hfam_params.vh"]
# =============================================================================
EXTRA_VERILOG_FILES: list[str] = [
    "$COMMON_IP_DIR/dip_hsm_sys/pulpino/rtl_v/include/config.svh",
    "$COMMON_IP_DIR/dip_hsm_sys/pulpino/rtl_v/include/defines.vh",
    "$COMMON_IP_DIR/dip_hsm_sys/pulpino/rtl_v/include/fcb_bus.svh",
    "$COMMON_IP_DIR/dip_hsm/rtl_v/hfam_params.vh",
    "$COMMON_IP_DIR/dip_hsm/rtl_v/hfam_funcs.vh",
    "$COMMON_IP_DIR/dip_hsm/rtl_v/aesm_funcs.vh",
    "$COMMON_IP_DIR/dip_hsm/rtl_v/aesm_params.vh",
    "$COMMON_IP_DIR/dip_hsm/rtl_v/hfam_const.vh",
    "$COMMON_IP_DIR/dip_hsm/rtl_v/hsm_defines.vh",
    "$COMMON_IP_DIR/dip_hsm/rtl_v/hsm_patronum_defines.vh",
    "$COMMON_IP_DIR/dip_hsm/rtl_v/hsm_patronum_params.vh",
    "$COMMON_IP_DIR/dip_hsm/rtl_v/hsm_wrapper_defines.vh",
    "$COMMON_IP_DIR/dip_hsm/rtl_v/pkam_cmd.vh",
    "$COMMON_IP_DIR/dip_hsm/rtl_v/pkam_params.vh",
    "$COMMON_IP_DIR/dip_hsm/rtl_v/rngm_funcs.vh",
    "$COMMON_IP_DIR/dip_hsm/rtl_v/rngm_params.vh",
]

# ---------------------------------------------------------------------------
# Environment-variable helpers
# ---------------------------------------------------------------------------

def _env(key: str, default: str = "") -> str:
    """Read an environment variable, returning *default* if unset or empty."""
    val = os.getenv(key, default)
    return val if val else default


# ---------------------------------------------------------------------------
# Design directory list
# ---------------------------------------------------------------------------

def get_design_dirs() -> list[str]:
    """Build the list of design directories from environment variables."""
    candidates = [
        _env("SOC_DESIGN_DIR"),
        _env("COMMON_IP_DIR"),
        _env("MEMORY_DIR"),
        _env("LIBRARY_DIR"),
        _env("PLATFORM_DIR"),
        _env("CPPE_DIR"),
    ]
    return [d for d in candidates if d]


# ---------------------------------------------------------------------------
# Regex constants (compiled once at import time)
# ---------------------------------------------------------------------------

# Detect an `ifdef FPGA_SYN or `ifndef FPGA_SYN directive (whole-line match)
RE_IFDEF_FPGA_SYN  = re.compile(r"^\s*`ifdef\s+FPGA_SYN")
RE_IFNDEF_FPGA_SYN = re.compile(r"^\s*`ifndef\s+FPGA_SYN")
RE_IFDEF_ANY       = re.compile(r"^\s*`ifdef\s+")
RE_IFNDEF_ANY      = re.compile(r"^\s*`ifndef\s+")
RE_ELSE            = re.compile(r"^\s*`else\b")
RE_ENDIF           = re.compile(r"^\s*`endif\b")

# File-type filters
RE_VERILOG_EXT = re.compile(r"\.(sv|v|vh)$", re.IGNORECASE)

# Module header extraction
RE_MODULE = re.compile(
    r"\bmodule\s+(\w+)\s*#?\s*\(?(.*?)\)?\s*;", re.DOTALL
)

# Port direction
RE_PORT = re.compile(
    r"\b(input|output|inout)\b\s*"
    r"(?:reg|wire|logic|tri)?\s*"
    r"(signed\s*)?"
    r"(?:\[(\d+)\s*:\s*(\d+)\])?\s*"
    r"([a-zA-Z_]\w*)"
)

# Memory port naming patterns (case-insensitive via match groups)
MEM_PORT_PATTERNS: dict[str, re.Pattern] = {
    "addr": re.compile(r"^(a|A)_"),
    "data": re.compile(r"^(d|D)_"),
    "gwen": re.compile(r"(gwen|GWEN)_"),   # must precede "wen" -- gwen contains "wen"
    "wen":  re.compile(r"(?<!g)(wen|WEN)_"),
    "wem":  re.compile(r"(wem|WEM)_"),
    "me":   re.compile(r"(me|ME)_"),
    "we":   re.compile(r"(we|WE)_"),
    "clk":  re.compile(r"(clk|CLK)_"),
    "q":    re.compile(r"(q|Q)_"),
    "cen":  re.compile(r"(cen|CEN)_"),
}

# Stub-file suffix pattern
RE_STUB_SUFFIX = re.compile(r"_stub\b")

# Directory names to exclude from design traversal (non-project build/tool dirs)
SKIP_DIRS = frozenset({"tool_data"})


# ---------------------------------------------------------------------------
# Tcl property templates (for filelist.f)
# ---------------------------------------------------------------------------

FPGA_SET_PROPERTY_SCE = """\
set_property IS_GLOBAL_INCLUDE 1 [get_files $COMMON_IP_DIR/dip_sce/rtl_v/hsm_patronum_params.v]
set_property FILE_TYPE {Verilog Header} [get_files $COMMON_IP_DIR/dip_sce/rtl_v/hsm_patronum_params.v]"""

FPGA_SET_PROPERTY = """\
set_property IS_GLOBAL_INCLUDE 1 [get_files $SOC_TB_DIR/fpga/fpga_v/FPGA_define.sv]
set_property FILE_TYPE {Verilog Header} [get_files $SOC_TB_DIR/fpga/fpga_v/FPGA_define.sv]
set_property IS_GLOBAL_INCLUDE 1 [get_files $COMMON_IP_DIR/dip_hsm/rtl_v/hsm_defines.vh]
set_property FILE_TYPE {SystemVerilog} [get_files $COMMON_IP_DIR/dip_hsm/rtl_v/hsm_defines.vh]
set_property IS_GLOBAL_INCLUDE 1 [get_files $CPPE_CPUSYSTEM_DIR/CM4_INTEGRATION/rtl_v/__defines_CPPE_CM4.v]
set_property FILE_TYPE {Verilog Header} [get_files $CPPE_CPUSYSTEM_DIR/CM4_INTEGRATION/rtl_v/__defines_CPPE_CM4.v]"""

FPGA_XDC_PROPERTY = """\
set_property top fpga_top [current_fileset]
add_files -fileset constrs_1 -norecurse $SOC_TB_DIR/fpga/constrants/[string tolower ${PROJ_NAME}]_fpga_cons.xdc"""


# ---------------------------------------------------------------------------
# Environment-variable -> filelist variable substitution map
# ---------------------------------------------------------------------------

ENV_TO_FILELIST_VAR: dict[str, str] = {
    "COMMON_IP_DIR":        "${COMMON_IP_DIR}",
    "PLATFORM_DIR":         "${PLATFORM_DIR}",
    "PLATFORM_COM":         "${PLATFORM_COM}",
    "SOC_DESIGN_DIR":       "${SOC_DESIGN_DIR}",
    "SOC_TB_DIR":           "${SOC_TB_DIR}",
    "LIBRARY_DIR":          "${LIBRARY_DIR}",
    "CPPE_DIR":             "${CPPE_DIR}",
    "CPPE_CPUSYSTEM_DIR":   "${CPPE_CPUSYSTEM_DIR}",
    "CPPE_PERIPH_DIR":      "${CPPE_PERIPH_DIR}",
    "CPPE_TOP_DIR":         "${CPPE_TOP_DIR}",
    "PROJ_NAME":            "${PROJ_NAME}",
}


# ---------------------------------------------------------------------------
# FPGAToolConfig dataclass
# ---------------------------------------------------------------------------

@dataclass
class FPGAToolConfig:
    """Runtime configuration for the FPGA tool suite."""

    # Design directories to scan
    design_dirs: list[Path] = field(default_factory=list)

    # IP list that should use stub_v instead of rtl_v
    use_stub_list: list[str] = field(default_factory=list)

    # FPGA testbench paths
    tb_fpga_paths: list[Path] = field(default_factory=list)

    # Path to bcompare executable (None -> auto-detect)
    bcompare_exe: Optional[Path] = None

    # Output directories
    report_dir: Path = Path("reports")
    output_dir: Path = Path(".")

    # Filelist source
    design_config_dir: Optional[Path] = None

    @classmethod
    def from_env(cls) -> "FPGAToolConfig":
        """Build configuration from environment variables."""
        design_dirs = [Path(d) for d in get_design_dirs()]

        tb_fpga_paths: list[Path] = []
        soc_tb = _env("SOC_TB_DIR")
        if soc_tb:
            tb_fpga_paths.append(Path(soc_tb) / "fpga" / "fpga_v")

        design_config = _env("DESIGN")
        design_config_dir = Path(design_config) / "config" if design_config else None

        return cls(
            design_dirs=design_dirs,
            use_stub_list=list(STUB_IPS),
            tb_fpga_paths=tb_fpga_paths,
            design_config_dir=design_config_dir,
        )


# ---------------------------------------------------------------------------
# Sentinels for FPGA-block placeholders
# ---------------------------------------------------------------------------

SENTINEL_PREFIX = "__FPGA_BLOCK_"
SENTINEL_PATTERN = re.compile(r"//\s*__FPGA_BLOCK_(\d+)__")


def make_sentinel(block_id: int) -> str:
    """Create a sentinel comment line for the given block id."""
    return f"// __FPGA_BLOCK_{block_id}__"


# ---------------------------------------------------------------------------
# ANSI colour helpers (kept for backward-compat with existing callers)
# ---------------------------------------------------------------------------

RED    = "\033[1;91m"
YELLOW = "\033[1;93m"
GREEN  = "\033[1;92m"
CYAN   = "\033[1;96m"
BLUE   = "\033[1;94m"
MAGENTA = "\033[1;95m"
DIM    = "\033[2m"
BOLD   = "\033[1m"
RESET  = "\033[0m"


def red(text: str) -> str:
    return f"{RED}{text}{RESET}"


def yellow(text: str) -> str:
    return f"{YELLOW}{text}{RESET}"


def green(text: str) -> str:
    return f"{GREEN}{text}{RESET}"


def cyan(text: str) -> str:
    return f"{CYAN}{text}{RESET}"


def dim(text: str) -> str:
    return f"{DIM}{text}{RESET}"


def bold(text: str) -> str:
    return f"{BOLD}{text}{RESET}"

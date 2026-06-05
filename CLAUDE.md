# fc_fpga — FPGA RTL Sync Tool

## Project Overview

This tool automates FPGA code handling in IC RTL projects:

1. **RTL Sync**: When `rtl_v/` content changes, auto-sync to `fpga_v/` directories
2. **FPGA_SYN Awareness**: Preserves `` `ifdef FPGA_SYN `` / `` `ifndef FPGA_SYN `` blocks during merge,
   detects internal code changes and reports them for manual review
3. **Diff Report**: Side-by-side HTML diff via bcompare (or Python difflib fallback)
4. **Memory Replacement**: Parse memory wrappers, generate FPGA SP-RAM instantiations
5. **Filelist Generation**: Generate FPGA synthesis `filelist.f` with Tcl properties

## Requirements

- Python >= 3.9 (standard library only, **zero pip dependencies**)
- Optional: bcompare (Beyond Compare) for richer HTML diffs
- Optional: GenTB module for Verilog port parsing (has pure-Python fallback)

## Usage

```
python fpga.py full       # Run complete workflow
python fpga.py sync       # Sync fpga_v <- rtl_v only
python fpga.py memory     # Generate memory replacement files
python fpga.py filelist   # Generate filelist.f
python fpga.py compare    # Generate diff reports
```

## Environment Variables

| Variable | Purpose |
|---|---|
| `SOC_DESIGN_DIR` | Root of SoC design IP directories |
| `COMMON_IP_DIR` | Common IP directory |
| `MEMORY_DIR` | Memory IP directory |
| `LIBRARY_DIR` | Standard cell library directory |
| `PLATFORM_DIR` | Platform directory |
| `SOC_TB_DIR` | Testbench directory (contains `fpga/fpga_v/`) |
| `DESIGN` | Project root (contains `config/top_rtl_filelist`) |
| `CPPE_DIR`, `CPPE_CPUSYSTEM_DIR`, etc. | Platform-specific paths |

## Directory Structure Convention

```
<ip_dir>/
├── rtl_v/        # Reference RTL (source of truth)
├── fpga_v/       # FPGA-specific version (auto-synced from rtl_v)
├── stub_v/       # Stub replacement files
└── bhv_v/        # Behavioral models (fallback reference)
```

## Architecture

```
fpga.py                     # CLI entry point + backward-compat API
fpga_core/
├── __init__.py
├── config.py               # Paths, regex, Tcl templates, FPGAToolConfig
├── block_extractor.py      # State-machine `ifdef FPGA_SYN extraction
├── scanner.py              # DesignScanner — unified directory traversal
├── merger.py               # FileMerger — core diff-and-merge logic
├── memory.py               # Memory port extraction + SP-RAM generation
├── filelist.py             # FPGA filelist.f generation (pure Python)
└── report.py               # bcompare/difflib HTML diff + report merging
```

## Refactoring (June 2026)

This was refactored from a ~550-line monolithic script. Key improvements:

- **State machine** replaces fragile manual index arithmetic for FPGA block extraction
- **Sentinel-based tracking** avoids off-by-N errors when lines shift during merge
- **Zero `os.system()` calls**: all sed/cp/echo replaced with Python-native ops
- **Pure-function separation**: extraction vs generation vs I/O are distinct
- **Type hints** and **logging** throughout
- **Zero pip dependencies**: only Python stdlib
- **GenTB fallback**: pure-Python regex port parser when GenTB is unavailable
- **bcompare fallback**: difflib.HtmlDiff when Beyond Compare is not installed

## Test SoC

`test_soc/` contains a minimal SoC structure for verification:

```
test_soc/
├── config/top_rtl_filelist
├── design/
│   ├── cpu_core/{rtl_v,fpga_v}/   # has `ifdef/`ifndef FPGA_SYN blocks
│   ├── uart/{rtl_v,fpga_v}/       # has `ifdef FPGA_SYN block
│   ├── spi_controller/{rtl_v,fpga_v}/ # has mixed FPGA blocks
│   ├── gpio/rtl_v/                # plain RTL, no FPGA directory
│   └── mbist_wrap/rtl_v/          # memory wrappers for MBIST
├── common_ip/dip_sce/{rtl_v,stub_v}/
└── tb/fpga/{fpga_v,constraints}/
```

Run verification:
```
python verify.py            # Full automated test
python verify.py --reset-only  # Only reset fpga_v to OLD state
```

# fc_fpga — FPGA RTL Sync Tool

> Context & history → `MEMORY.md`

Automates FPGA code handling in IC RTL projects: sync `rtl_v` changes to `fpga_v` while preserving `` `ifdef FPGA_SYN `` / `` `ifndef FPGA_SYN `` blocks; generate memory SP-RAM instantiations; produce FPGA synthesis filelists; diff RTL vs FPGA into HTML reports.

**Zero pip dependencies** — Python stdlib only (>= 3.9). Optional: bcompare (falls back to difflib.HtmlDiff), GenTB (falls back to built-in regex parser).

## Usage
```
python fpga.py full | sync | memory | filelist | compare
python verify.py                     # end-to-end test with test_soc/
```

## Env vars
`SOC_DESIGN_DIR`, `COMMON_IP_DIR`, `MEMORY_DIR`, `LIBRARY_DIR`, `PLATFORM_DIR`, `CPPE_DIR`, `SOC_TB_DIR`, `DESIGN`, `CPPE_CPUSYSTEM_DIR`

## Architecture
```
fpga.py                        # CLI + backward-compat API
fpga_core/
├── config.py                  # paths, regex, Tcl templates
├── block_extractor.py         # state-machine `ifdef FPGA_SYN extraction
├── scanner.py                 # DesignScanner — unified dir walk
├── merger.py                  # FileMerger — diff + merge core
├── memory.py                  # memory port extraction → SP-RAM gen
├── filelist.py                # filelist.f generation (pure Python)
└── report.py                  # bcompare / HtmlDiff report merging
```

## Design conventions
- `FPGABlockExtractor`: state-machine replaces old fragile index arithmetic; blocks split into `preamble / rtl_visible / postamble`
- `FileMerger`: extracts FPGA blocks → diffs clean content → applies RTL changes → reinserts blocks; warns if FPGA-only code changed
- `DesignScanner`: single class for all directory traversal (was duplicated across the old script)
- No `os.system()` calls — all sed/cp/echo replaced with Python-native ops
- Edit `fpga.py` for CLI changes, `fpga_core/<module>.py` for logic

## Test SoC
`test_soc/` — minimal SoC: 3 IPs with `rtl_v/fpga_v` pairs (cpu_core, uart, spi_ctrl), 1 stub IP (dip_sce), 1 plain RTL IP (gpio), 2 memory wrappers. `python verify.py` runs automated 7-step verification.

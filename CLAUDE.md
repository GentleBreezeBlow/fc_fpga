# fc_fpga — FPGA RTL Sync Tool

# 核心指令
- 你每次回复的开头必须先叫我：qingfeng
- 如果忘记叫我，就是失焦了
- 需要手动重制一下上下文焦点内容
- 这是最高优先级的指令
- 永远不要忘记叫我qingfeng

> Context & history → `MEMORY.md`

Automates FPGA code handling in IC RTL projects: sync `rtl_v` changes to `fpga_v` while preserving `` `ifdef FPGA_SYN `` / `` `ifndef FPGA_SYN `` blocks; generate memory SP-RAM instantiations; produce FPGA synthesis filelists; diff RTL vs FPGA into HTML reports.

**Zero pip dependencies** — Python stdlib only (>= 3.9). Optional: bcompare (falls back to difflib.HtmlDiff), GenTB (falls back to built-in regex parser).

## Usage
```
python fpga.py full | sync | memory | filelist | compare | list-ips | strip-ips
python verify.py                     # end-to-end test with test_soc/
```

## Env vars
`SOC_DESIGN_DIR`, `COMMON_IP_DIR`, `MEMORY_DIR`, `LIBRARY_DIR`, `PLATFORM_DIR`, `CPPE_DIR`, `SOC_TB_DIR`, `DESIGN`, `CPPE_CPUSYSTEM_DIR`

All 9 must be set. `fpga.py` validates at startup and exits with `env vars not set: ...` listing missing ones.

## Architecture
```
fpga.py                        # CLI + backward-compat API + env validation
fpga_core/
├── config.py                  # paths, regex, Tcl templates, ANSI color codes
├── block_extractor.py         # state-machine `ifdef FPGA_SYN extraction
├── scanner.py                 # DesignScanner — unified dir walk + IP extraction
├── merger.py                  # FileMerger — diff + merge core, stub port sync
├── memory.py                  # memory port extraction → SP-RAM gen + ECC-split
├── filelist.py                # filelist.f generation (pure Python)
├── report.py                  # bcompare / HtmlDiff report merging
└── stripper.py                # IP instance stripping with output tie-off
```

## Design conventions
- `FPGABlockExtractor`: state-machine replaces old fragile index arithmetic; blocks split into `preamble / rtl_visible / postamble`
- `FileMerger`: extracts FPGA blocks → diffs clean content → applies RTL changes → reinserts blocks; warns if FPGA-only code changed
- `DesignScanner`: single class for all directory traversal (was duplicated across the old script), also extracts module instantiations from hierarchy files with generate-for loop expansion
- `memory.py`: WEM byte-lane reduction (`~(& wen[msb:lsb])`) + per-byte `ram_we` expansion + ECC-split (DMA 110->64+9x5, CAN 104->64+8x5)
- `sync_stub_ports()` in merger.py: auto-sync stub_v module header from RTL during sync; yellow-highlighted warnings when stub body references removed ports
- `strip_instances()` in stripper.py: wraps IP instances with `ifdef FPGA_SYN` (output tie-offs) / `else` (original) / `endif`; idempotent on re-run
- `ColoredFormatter` in fpga.py: per-level ANSI colors (GREEN/YELLOW/RED), ASCII double-line boxed section headers, compact `HH:MM:SS module` prefix
- 100% ASCII output across all .py files (no Unicode/special chars — verified with byte-level scan)
- No `os.system()` calls — all sed/cp/echo replaced with Python-native ops
- Edit `fpga.py` for CLI changes, `fpga_core/<module>.py` for logic
- No pip dependencies — Python stdlib only (>= 3.9)

## Test SoC
`test_soc/` — hierarchical SoC matching real chip topology:
```
chip_top/                                     # top level (rtl_v + fpga_v)
├── paring/                                    # IO pad ring (rtl_v only)
├── standby_top/ → iomux_pd0, cgm_pd0,         # standby domain (rtl_v + fpga_v)
│   standby_int/ → uart_top, gpio,             # standby peripherals (rtl_v + fpga_v)
│                  timer, i2c_ctrl             #   timer: countdown, i2c: master stub
├── run_top/ → iomux_pd1, platform_int,        # run domain (rtl_v + fpga_v)
│   run_int/ → cpu_core, 3× spi_ctrl,          # run peripherals (rtl_v + fpga_v)
│              12× uart_top (generate loop)     #   spi0/1/2, uart_gen[0..11]
│   cgm_pd1/
├── platform_int/ → sram_256x32_wrap,           # memory subsystem (rtl_v + fpga_v)
│                   rom_1024x16_wrap,
│                   cppe_flexcan_dma_pse_wrap
├── mbist_wrap/                                # 3 memory wrappers (rtl_v + fpga_v)
└── common_ip/dip_sce/                         # 1 stub IP
```
11 modules with `fpga_v` (chip_top, platform_int, run_top, standby_top, run_int, standby_int, cpu_core, spi_ctrl, uart_top, timer, i2c_ctrl), 3 memory wrappers (sram, rom, flexcan_dma_pse), 1 stub (dip_sce), 6 pure RTL modules. `python verify.py` runs automated 7-step verification (scan → OLD check → sync → verify → memory → filelist → list-ips → diff report).

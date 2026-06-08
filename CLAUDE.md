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
python fpga.py full | sync [--no-compare] | memory | filelist | compare | list-ips | strip-ips
python fpga.py sync --no-compare     # sync only, skip diff report
python fpga.py strip-ips --file strip_ips.conf   # batch strip
```

## Env vars
`SOC_DESIGN_DIR`, `COMMON_IP_DIR`, `MEMORY_DIR`, `LIBRARY_DIR`, `PLATFORM_DIR`, `CPPE_DIR`, `SOC_TB_DIR`, `DESIGN`, `CPPE_CPUSYSTEM_DIR`, `PROJ_NAME`

All must be set. `fpga.py` validates at startup and exits with `env vars not set: ...` listing missing ones.

`PROJ_NAME`: used for xdc constraint file name `${PROJ_NAME}_cons.xdc` in generated filelist.

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
- `FileMerger`: extracts FPGA blocks → diffs clean content → applies RTL changes → reinserts blocks; warns if FPGA-only code changed; **block overlap check uses original positions** (not shifted) to avoid blocks drifting outside `ifndef`
- `DesignScanner`: single class for all directory traversal, skip `tool_data` dirs; extracts module instantiations with generate-for loop expansion
- `memory.py`: WEM byte-lane reduction + per-byte `ram_we` expansion + ECC-split: DMA 110→64+9x5, CAN 104→64+8x5, cppe_cache 36→32+4 (`fpga_mem` style); non-byte-multiple widths auto-pad to 8 boundary (39→40); **fpga_v dir cleared before regen**
- `sync_stub_ports()` in merger.py: auto-sync stub_v module header + reports port diff (green `+N added`, red `-N removed`); yellow warnings when stub body references removed ports
- `strip_instances()` in stripper.py: wraps with `ifdef FPGA_SYN`/`else`/`endif`; **auto un-strips instances removed from config**; idempotent on re-run
- `generate_filelist()` in filelist.py: strips mbist_wrap/rtl_v entries, replaces with fpga_v; `$VAR`/`${VAR}` expanded to absolute paths with `/` normalization; `${PROJ_NAME}_cons.xdc` for constraint file
- `_read_html()` in report.py: auto-detect encoding (UTF-8/GBK/latin-1) when merging HTML reports
- `ColoredFormatter` in fpga.py: per-level ANSI colors, ASCII double-line boxed section headers, compact `HH:MM:SS module` prefix
- Python >= 3.9 compatibility: `os.walk()` not `Path.walk()` (3.12+ only)
- No `os.system()` / pip deps — Python stdlib only
- Edit `fpga.py` for CLI changes, `fpga_core/<module>.py` for logic

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
├── mbist_wrap/                                # 5 memory wrappers (rtl_v + fpga_v)
└── common_ip/dip_sce/                         # 1 stub IP
```
11 modules with `fpga_v`, 5 memory wrappers (sram, rom, flexcan_dma_pse, cppe_ram, cppe_cache), 1 stub (dip_sce). `python verify.py` runs 7-step verification; use `python fpga.py` for daily work (verify.py resets fpga_v to hardcoded OLD state).

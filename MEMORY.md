# Memory — fc_fpga

> Cross-session context. CLAUDE.md links here for project history.

## Current state snapshot (2026-06-06)

- 14 FPGA pairs (11 original + 3 memory wrappers)
- 1 stub pair (dip_sce)
- `verify.py`: 11 OLD states, 47 checks, 7 steps
- `list-ips`: `spi_ctrl` ×3 (spi0/1/2), `uart_top` ×12 (uart_gen[0..11].u_uart), platform_int memory wrappers, standby_int timer + i2c
- `_check_required_env()` validates all 9 env vars before any command

## How we got here

原始 `fpga.py`（~550行单片）于 2025-06-05 重构为模块化 `fpga_core/` 包：

- `find_fpga_blocks()` + `remove_fpga_blocks()` 用脆弱的手动索引运算跟踪行号偏移 — **已替换为** `FPGABlockExtractor` 状态机，将块拆为 `preamble / rtl_visible / postamble`
- 15+ `os.system('sed/cp/echo')` — **已替换为** Python 原生操作
- `gen_mbist_fpgafiles()` 计算端口后立刻 `del` 所有结果（已损坏） — **已修复**
- `bs4` BeautifulSoup — **已移除**，用 `re` 正则解析 HTML body（零依赖）
- difflib `delete` = RTL 有 FPGA 没有 → merger 中作为 insert；`insert` = FPGA 有 RTL 没有 → merger 中保留
- `import re` 原在 `merger.py` 底部 — **已移到顶部**

## Design decisions

1. 模块边界：scanner(发现) → merger(合并) → report(报告)，纯函数 + 最后 I/O
2. CLI 向后兼容：`fpga.py` 保留旧函数签名，内部委托给新模块
3. `block_extractor.reinsert()` 依赖 clean lines 中的 RTL 可见部分重建块
4. Windows 上 `.read_text()` 默认 GBK — `verify.py` 用 `encoding="utf-8"` 解决
5. Zero pip dependencies — Python stdlib only (>= 3.9)，aip_random_noise.sv 外的第三方依赖均为可选

## Test SoC

`test_soc/` 按真实芯片层级组织：

```
chip_top/                                    # 顶层 (rtl_v + fpga_v)
├── paring/                                   # IO pad ring (纯 rtl_v)
├── standby_top/ → iomux_pd0, cgm_pd0,        # standby 域 (rtl_v + fpga_v)
│   standby_int/ → uart_top, gpio,            # standby 外设 (rtl_v + fpga_v)
│                  timer, i2c_ctrl             #   timer: 32-bit countdown
│                                             #   i2c_ctrl: master stub
├── run_top/ → iomux_pd1, platform_int,        # run 域 (rtl_v + fpga_v)
│   run_int/ → cpu_core, 3× spi_ctrl,          # run 外设 (rtl_v + fpga_v)
│              12× uart_top (generate loop)     #   spi0/1/2, uart_gen[0..11]
│   cgm_pd1/
├── platform_int/ → sram_256x32_wrap,           # memory subsystem (rtl_v + fpga_v)
│                   rom_1024x16_wrap,
│                   cppe_flexcan_dma_pse_wrap
├── mbist_wrap/                               # 3 memory wrapper (rtl_v + fpga_v)
└── common_ip/dip_sce/                        # 1 stub IP
```

- 11 个有 `fpga_v` 的模块：chip_top, platform_int, run_top, standby_top, run_int, standby_int, cpu_core, spi_ctrl, uart_top, timer, i2c_ctrl
- 3 个 memory wrapper：sram_256x32, rom_1024x16, cppe_flexcan_dma_pse
- 1 个 stub：dip_sce → dip_sce_top_stub
- 6 个纯 RTL 模块（无 fpga_v）：paring, iomux_pd0, iomux_pd1, cgm_pd0, cgm_pd1, gpio
- `tb/fpga/fpga_v/` 下有 FPGA 基础设施：FPGA_define.sv, cppe_fpga_top.sv, fpga_memory.v, dma_fpgamem.v, can_fpgamem.v

## memory.py — WEM / ECC 完善 (2026-06-06)

### ram_we 位宽修复
`fpga_spram` 的 `ram_we` 端口是 `[MEMWIDTH/BYTEWIDTH-1:0]`（per-byte），非 1-bit：
- 1-bit 源信号 (`WEN_0`, `gwen_0`) → `{N{~sig}}` 复制到正确位宽
- `byte_width` 用 ceil 除法 `(w + 7) // 8`（110-bit → 14 byte lanes）

### WEM 多 bit mask 归约
`wen_*` 信号为 WEM mask（active-low per-bit）时，逐 byte NAND 归约：
- `wen_0[109:0]`（110-bit）→ `{~gwen_0 & ~(&wen_0[109:104]), ~gwen_0 & ~(&wen_0[103:96]), ...}`
- 优先级：WEN（bitmask）> GWEN（global）。GWEN 存在时 gate 每个 byte lane 的 WEN 归约结果

### ECC-split 生成
当 data_width 和 module_name 满足条件时，自动拆分数据 + ECC：

| 条件 | 拆分方案 |
|---|---|
| 110-bit + `dma` in name | 1×64-bit data + 9×5-bit ECC (genvar loop) |
| 104-bit + `can`/`flexcan` in name | 1×64-bit data + 8×5-bit ECC (genvar loop) |

参照 `tb/fpga/fpga_v/dma_fpgamem.v` / `can_fpgamem.v` 模板：先声明 `ram_we` wire（逐 chunk `&WEM[msb:lsb]`），再例化 data fpga_spram + generate-loop ECC fpga_spram。

### 新增函数
`_reduce_wem_mask()`, `_gen_ram_we()`, `_is_ecc_split()`, `_ecc_wem_chunks()`, `_gen_ecc_ram_we_wire()`, `_gen_ecc_split_body()`

## scanner.py — IP extraction (2026-06-06)

### extract_instances() — 三遍扫描

1. **Pass 1 (regex)**: `^\s*(\w+)\s+#?(...)?(\w+)\s*\(` — 处理简单例化
2. **Pass 2 (backwards-scan)**: 处理 `#(.PARAM(val), ...)` 嵌套括号，向前回溯找 module name，过滤 `.port_name(` 和 100+ Verilog 关键字
3. **Pass 3 (generate-for expansion)**: 解析 `generate for (VAR = START; VAR <|<= END; ...) begin : BLOCK`，从 `parameter/localparam` 解析迭代次数，展开为 `BLOCK[0].inst` ~ `BLOCK[N-1].inst`

辅助函数：`_collect_params()`（parameter/localparam 解析），`_find_generate_loops()`（generate-for 匹配 + count 计算），`_find_matching_end()`（嵌套 begin/end 平衡匹配）

### list_hierarchy_ips()

从 `run_top`, `standby_top`, `run_int`, `standby_int` 的 rtl_v 提取例化。CLI：`python fpga.py list-ips`

当前输出：
```
[run_int]  16 IP(s)
  cpu_core              u_cpu
  spi_ctrl              spi0
  spi_ctrl              spi1
  spi_ctrl              spi2
  uart_top              uart_gen[0].u_uart
  ...
  uart_top              uart_gen[11].u_uart
```

## fpga.py — env validation (2026-06-06)

`_check_required_env()` 在 `main()` 入口校验全部 9 个环境变量，缺失时报错 `env vars not set: ...`（列出所有缺失变量名）。

## report.py — 文件名冲突修复 (2026-06-06)

`_extract_module_name()` 原用 `fpga_v` 父目录名 → mbist_wrap 下 3 个文件共用一个目录名，后生成的会覆盖前面的。改为用 `fpga_path.stem`（模块名），保证唯一。

## Stub port auto-sync (2026-06-07)

### sync_stub_ports() in merger.py
- `_extract_module_header(text) -> tuple[str, int, int] | None`: state-machine parsing `module NAME [#(...)]? (...);` with balanced-paren tracking
- `_extract_port_names(header_text) -> set[str]`: extract port signal names from header
- `sync_stub_ports(stub_path, rtl_path) -> bool`: replaces stub module header with RTL header, warns (YELLOW) if stub body references ports no longer in RTL
- Invoked during `sync` step for all stub modules in `use_stub_list`

## Logging beautification (2026-06-07)

### ColoredFormatter in fpga.py
- `_LEVEL_STYLE` dict: DEBUG=DIM, INFO=GREEN, WARNING=YELLOW, ERROR=RED, CRITICAL=RED+BOLD
- `_SECTION_RE`: matches `>>> TITLE <<<` → rendered as ASCII double-line box (`+===...+`)
- Format: `HH:MM:SS > module_name message` — compact, no clutter
- 100% ASCII-only: all .py files verified with byte-level scan (`python -c "open(f,'rb').read().decode('ascii')"`)
- Replaced all Unicode in source: `←→—…×‑│└├` → ASCII equivalents
- ANSI color codes via `config.py`: `GREEN`, `CYAN`, `BLUE`, `MAGENTA`, `DIM`, `BOLD`, `RESET`

## strip-ips command (2026-06-07)

### stripper.py — new module
- `strip_instances(fpga_path, inst_names, scanner) -> int`: main entry, returns count of stripped instances
- `_parse_instance_body(text, inst_name)`: regex-based instance locator with backwards module-name scan (handles `#(...)` parameter blocks with balanced parens)
- `_backwards_module_name(text, pos)`: scan backwards from instance name to find module name, skipping `) inst_name (` → `module_name #(`
- `_inside_fpga_block(text, pos)`: check if position is already inside `ifdef FPGA_SYN` / `endif` (idempotency guard)
- `_parse_port_connections(text, pos)`: balanced-paren scan for `.port(signal)` / `.port()` / `.*` connections
- `_extract_module_outputs(rtl_path) -> set[str]`: parse module RTL header for output port names
- `_find_module_rtl(module_name, scanner) -> Path|None`: search design dirs for module source
- `_signal_width(signal, text) -> int|None`: determine bit-width from signal declaration for correct tie-off value
- `_indent_of(text, pos) -> str`: extract whitespace indentation of the line containing pos

### Key behaviors
- Output ports → `assign <signal> = <N>'b0;` wrapped in `ifdef FPGA_SYN`
- Input/inout ports: skipped (no tie-off needed)
- Idempotent: `_inside_fpga_block()` prevents double-wrapping on re-run
- Indentation preserved from original instance

### CLI + batch mode
```bash
python fpga.py strip-ips run_int spi2 spi3          # CLI: remove specific instances
python fpga.py strip-ips --file strip_ips.conf       # Batch: read from config file
python fpga.py strip-ips run_int spi2 --file ...     # Mixed: both CLI + file
```

### Batch config format (`strip_ips.conf`)
```
# Format: <hier_module> : <inst1> <inst2> ...
run_int: spi2 spi3
standby_int: gpio
```
- `_parse_strip_file(file_path) -> list[tuple[str, list[str]]]`: parse config, ignore `#` comments

## Filelist fpga_v count fix (2026-06-07)

- `filelist.py` `generate_filelist()`: fpga_v file count verification now includes TB fpga_v files (`tb_fpga_paths`) in `expected_count`, fixing false "count mismatch" warnings

## GitHub

- Repo: `github.com/GentleBreezeBlow/fc_fpga`
- Commits: `222b468` (30 files) → `e513f32` (slim CLAUDE.md) → `2c0c6e5` (mbist_wrap fpga_v gen)
- Windows 凭据管理器已存 cred，`git push` 即可

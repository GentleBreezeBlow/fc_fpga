# FPGA RTL Sync Tool (`fpga.py`)

把 IC 设计项目中 RTL 代码（`rtl_v`）的改动同步到 FPGA 版本（`fpga_v`），自动生成 memory SP-RAM 替换和 Vivado 综合 filelist。

## 快速开始

```bash
# 设好项目所需的环境变量，然后运行
python fpga.py full             # 全流程：sync + memory + filelist + diff report
```

## 命令一览

| 命令 | 说明 |
|------|------|
| `full` | 完整流程：sync → memory → filelist → diff report |
| `sync [--no-compare]` | 同步 `fpga_v` ← `rtl_v`，`--no-compare` 跳过生成 diff report |
| `memory` | 生成 `mbist_wrap/fpga_v/` 下的 FPGA SP-RAM 替换文件 |
| `filelist` | 生成 Vivado 综合用的 `filelist.f` |
| `compare` | 生成 RTL vs FPGA 的 HTML diff report |
| `list-ips` | 列出 hierarchy module 中例化的所有 IP |
| `strip-ips` | 用 `ifdef FPGA_SYN` 包裹指定实例，输出端口 tie 到 0 |

### 示例

```bash
python fpga.py sync --no-compare   # 只 sync，不生成 diff report
python fpga.py memory              # 只重新生成 memory wrapper
python fpga.py filelist            # 只重新生成 filelist.f
python fpga.py strip-ips run_int spi2       # 剥离 run_int 中的 spi2 实例
python fpga.py strip-ips --file strip_ips.conf  # 批量剥离（按配置文件）
```

## 工作原理

### 1. sync — `fpga_v` ← `rtl_v`

```
rtl_v/foo.sv                     fpga_v/foo.sv
   (RTL 最新)                      (含 `ifdef FPGA_SYN 块)
       │                                │
       │  ┌──────────────────────────┐  │
       └──│  提取 FPGA block，比较    │──┘
          │  clean RTL 代码           │
          │  差异应用到 fpga_v        │
          │  保留 FPGA block 不变     │
          └──────────────────────────┘
                    │
                    ▼
           fpga_v/foo.sv (更新后)
```

- `ifdef FPGA_SYN` / `ifndef FPGA_SYN` 块自动保留
- 超出 block 范围的 RTL 修改被合并进 fpga_v
- FPGA block 的 `rtl_visible` 部分如果被修改，打印黄色警告 + 完整路径
- stub 端口有增减时自动报告：`+N port(s) added` / `-N port(s) removed`

### 2. memory — 生成 SP-RAM 替换

读取 `mbist_wrap/rtl_v/*_wrap.sv` 的 memory 端口，生成同名的 `mbist_wrap/fpga_v/*_wrap.sv`：

- 普通 memory → `fpga_spram` 实例化
- DMA (110-bit) → 64-bit 数据 SP-RAM + 9×5-bit ECC SP-RAM（generate loop）
- CAN (104-bit) → 64-bit 数据 SP-RAM + 8×5-bit ECC SP-RAM（generate loop）
- CPPE Cache (36-bit) → 32-bit 数据 SP-RAM + `fpga_mem` ECC（原始 WEM）
- 非 8 倍数的数据宽度（如 39-bit → 40-bit）自动补齐
- 每次生成前**清空** `fpga_v/` 目录，避免旧项目残留

### 3. filelist — 生成综合 filelist

- 读取 `top_rtl_filelist`，过滤掉 `tsmc_lib` / `gf22_lib` / `MEMORY_DIR`
- `rtl_v` 路径替换为 `fpga_v` 路径
- `mbist_wrap/rtl_v` 全部剔除，只保留 `mbist_wrap/fpga_v`
- `$VAR` / `${VAR}` 引用展开为绝对路径（`/` 分隔）
- 末尾追加 Tcl property 和 xdc 约束文件

### 4. strip-ips — 剥离例化

```verilog
// 把指定 instance 包裹起来：
`ifdef FPGA_SYN
  assign output_signal = 1'b0;   // FPGA 下输出 tie 0
`else
  module_name inst_name (...);    // ASIC 下保留原例化
`endif
```

配置文件格式（`strip_ips.conf`）：

```ini
# 格式: <父模块名> : <例化名1> <例化名2> ...
run_int: spi2
cppe_periph_top: u_uart u_spi
```

## 配置文件

### `strip_ips.conf`

控制 `strip-ips` 命令需要剥离哪些实例，格式见上方。

### `fpga_core/config.py` 中的可配置项

| 配置 | 说明 |
|------|------|
| `SKIP_DIRS` | 遍历时跳过的目录名（默认 `tool_data`） |
| `ENV_TO_FILELIST_VAR` | 环境变量 → Tcl 变量映射 |
| `MEM_PORT_PATTERNS` | memory 端口命名正则 |
| `FPGA_INCLUDE_DIRS` | filelist Tcl header |

## 依赖

- Python >= 3.9，**零 pip 依赖**（stdlib only）
- 可选：`bcompare`（Beyond Compare，生成 HTML diff；无则自动用 difflib）
- 可选：`GenTB`（Verilog parser，无则用内置正则）

## 脚本结构

```
fpga.py                      # CLI 入口 + 配置加载 + 工作流编排
fpga_core/
├── config.py                # 路径、正则、Tcl 模板、环境变量
├── block_extractor.py       # 状态机提取 ifdef FPGA_SYN 块
├── scanner.py               # 统一目录扫描（fpga_v / stub_v / memory）
├── merger.py                # diff + merge 核心，stub port 同步
├── memory.py                # memory port 提取 → SP-RAM / fpga_mem 生成
├── filelist.py              # filelist.f 生成
├── report.py                # bcompare / difflib HTML diff 报告
└── stripper.py              # IP 例化剥离 + 输出 tie-off
strip_ips.conf               # strip-ips 批量配置文件
```

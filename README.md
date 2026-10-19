# FPGA RTL Sync Tool (`fpga.py`)

把 IC 设计项目中 RTL 代码（`rtl_v`）的改动同步到 FPGA 版本（`fpga_v`），自动生成 memory SP-RAM 替换和 Vivado 综合 filelist。

## 快速开始

```bash
# 设好项目所需的环境变量，然后运行
python fpga.py full             # 全流程：sync + compare + memory + prefix + filelist + strip-ips
```

## 命令一览

| 命令 | 说明 |
|------|------|
| `full` | 完整流程：sync → compare → memory → prefix → filelist → strip-ips（prefix 仅当 `PARAM_PREFIX_DIRS` 非空时执行；strip-ips 自动读 `strip_ips.conf`） |
| `sync [--no-compare]` | 同步 `fpga_v` ← `rtl_v`，`--no-compare` 跳过 diff report |
| `memory` | 生成 `mbist_wrap/fpga_v/` 下的 FPGA SP-RAM 替换文件 |
| `filelist` | 生成 Vivado 综合用的 `filelist.f` |
| `compare` | 生成 RTL vs FPGA 的 HTML diff report |
| `list-ips [-o file]` | 列出 hierarchy module 中例化的 IP，输出到文件（默认 `hierarchy_ips.txt`） |
| `strip-ips` | 用 `ifdef FPGA_SYN` 包裹指定实例，输出端口 tie 0（`_b`/`ready` 结尾或 `tie1` 指定的端口 tie 1） |

### 示例

```bash
python fpga.py sync --no-compare                   # 只 sync，不生成 diff report
python fpga.py memory                              # 只重新生成 memory wrapper
python fpga.py filelist                            # 只重新生成 filelist.f
python fpga.py list-ips                            # 列出 IP → hierarchy_ips.txt
python fpga.py list-ips -o my_ips.txt              # 输出到指定文件
python fpga.py strip-ips run_int spi1              # 扁平名（唯一时可用）
python fpga.py strip-ips run_top.u_run_int spi1       # dotted path 精确指定
python fpga.py strip-ips --file strip_ips.conf      # 批量剥离（按配置文件）
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

- `ifdef FPGA_SYN` / `ifndef FPGA_SYN` 块自动保留，`ifndef` 无 `else` 的 `endif` 正确处理为预处理指令而非 RTL 代码
- 嵌套 `ifdef FPGA_SYN`（例如例化端口列表内的 `` `ifdef FPGA_SYN ``）递归提取，内层 FPGA-only 分支同样保留，不会被 sync 当作多余行删除
- `mbist_wrap/` 下的 memory wrapper 由 `memory` 命令管理，`sync` 自动跳过
- 超出 block 范围的 RTL 修改被合并进 fpga_v
- FPGA block 的 `rtl_visible` 部分如果被修改，打印黄色警告 + 完整路径
- stub 端口有增减时自动报告：`+N port(s) added` / `-N port(s) removed`

### 2. memory — 生成 SP-RAM 替换

读取 `mbist_wrap/rtl_v/*_wrap.sv` 的 memory 端口，生成同名的 `mbist_wrap/fpga_v/*_wrap.sv`：

#### ECC-split 规则

| 条件 | data 位宽 | ECC 位宽 | ECC 数量 | 风格 |
|------|-----------|----------|----------|------|
| DMA (110-bit) | 64 | 5 | 9 | default (genvar loop) |
| CAN/FlexCAN (104-bit) | 64 | 5 | 8 | default (genvar loop) |
| ROM (72-bit) | 64 | 8 | 1 | default (genvar loop) |
| ROM (39-bit) | 32 | 7 | 1 | default (genvar loop) |
| CPPE Cache (36-bit) | 32 | 4 | 1 | cache (fpga_mem) |

#### ROM wrapper 特殊处理

- ROM 的 `fpga_v` 由 `memory` 命令**独家管理**，`sync` 命令跳过 `mbist_wrap/` 路径
- 自动新增输入端口（大小写跟随已有端口惯例 `CLK_0` → `D_0`, `clk_0` → `d_0`）：
  - `D_N` — 写数据端口，位宽 = `Q_N` 位宽
  - `WEN_N` — per-byte WEM mask（低有效），位宽 = `byte_width`（如 16-bit → `[1:0]`，72-bit → `[7:0]`）
  - `GWEN_N` — 全局写使能（低有效），1-bit
- `ram_me = ~CEN`（chip enable），`ram_we = {N{~GWEN}} & ~WEN`（GWEN gate WEN mask）
- ECC spram 的 `ram_we` 只用 `~GWEN`（GWEN 有效即可写 ECC）

#### 通用特性

- 普通 memory → `fpga_spram` 实例化
- WEM bitmask 自动按 byte lane 归约（NAND reduction）
- 非 8 倍数的数据宽度（如 39-bit）mem_width 自动补齐到 8 边界（→ 40-bit pad）
- 每次生成前**清空** `fpga_v/` 目录，避免旧项目残留

### 3. filelist — 生成综合 filelist

- 读取 `top_rtl_filelist`，过滤掉 `tsmc_lib` / `gf22_lib` / `MEMORY_DIR`
- `+incdir+xxx` 和 `-y xxx`（目录）自动提取到 `set_property include_dirs`，与 `EXTRA_INCLUDE_DIRS` 合并去重
- `rtl_v` 路径替换为 `fpga_v` 路径（按文件名长度降序替换，`cppe_cache_wrap` 不会被 `cache_wrap` 误吞）
- `mbist_wrap/rtl_v` 全部剔除，只保留 `mbist_wrap/fpga_v`
- `-makelib xxx` / `-endlib` 指令注释掉（Tcl `#` 注释），并在每个 `-endlib` 后追加一行 `$SOC_TB_DIR/fpga/fpga_v/undef_xxx.v`（`xxx` 为对应 `-makelib` 的名字）
- `$VAR` / `${VAR}` 引用展开为绝对路径（`/` 分隔）
- 末尾追加 Tcl property 和 xdc 约束文件（top 名 `fpga_top`，xdc 文件 `[string tolower ${PROJ_NAME}]_fpga_cons.xdc`）

### 4. strip-ips — 剥离例化

```verilog
// 把指定 instance 包裹起来：
`ifdef FPGA_SYN
  assign output_signal = 'b0;    // tie 0（unsized literal，Verilog 自动扩展位宽）
  assign active_low_b = 1'b1;   // _b / _b_ 端口 tie 1（需位宽）
`else
  module_name inst_name (...);    // ASIC 下保留原例化
`endif
```

支持两种写法定位目标模块：
- **扁平名**（`run_int`）— 直接写模块名，唯一时自动解析；歧义时报错列出所有匹配路径
- **dotted path**（`run_top.u_run_int`）— 全路径精确指定，用 **例化名** 逐级定位

> 扁平名通过 `_HIER_MODULES` 解析为对应的 fpga_v 文件，最终匹配的是 **leaf module name**。

`strip-ips` 配置文件格式（`strip_ips.conf`）：

```ini
# 格式: <模块名|例化名路径> : <例化名1> <例化名2> ...
# 注释行用 #
# 同一个模块可以跨多行写，自动合并
# 支持 shell 风格通配符: * ? [...]

run_int: spi*
# 等价于:
run_int: spi0 spi1 spi2

# 精确名称不需要通配符
run_int: sram_decoder

# tie1 行：剥离 <模块名> 时，把列出的输出端口 tie 1（覆盖默认 _b/ready 启发式）
tie1 mct : ifr_load_done bisr_reset
```

#### tie-off 规则

| 端口特征 | 1-bit | 多-bit |
|----------|-------|--------|
| 普通端口 | `'b0`（unsized，缺省位宽） | `'b0` |
| `_b` / `ready` / `READY` 结尾端口 | `1'b1` | `{N{1'b1}}` |
| `tie1` 指定端口 | `1'b1` | `{N{1'b1}}` |

#### 运行机制

- **unstrip-all 再 re-strip**：每次运行先恢复所有由本工具剥离（`ifdef` 分支仅含 `assign` tie-off）的例化，再根据当前 config 重新剥离。原生 RTL 的 `ifdef FPGA_SYN`（含 wire / 子例化等结构代码）不会被误恢复。这样 tie-off 格式变更、端口增减、`_b` 检测修正全部自动生效
- **嵌套 `ifdef` 安全**：用平衡计数而非正则解析 `ifdef/endif` 边界，正确处理 body 中已有的 RTL 级 `ifdef FPGA_SYN`
- **注释安全**：例化搜索和端口解析全程跳过 `//` 和 `/* */` 注释，同行注释中的 `)` 不会导致端口列表提前截断
- **预处理器安全**：端口列表中 `` `ifdef `` / `` `endif `` 行自动 strip，宏名不会污染端口名集合；`_b` 检测在端口名层面判断，不受预处理器影响
- **输出端口解析**：支持 ANSI（`module foo(input a, output b);`）和非 ANSI（`module foo(a,b); output b;`）风格；端口列表中的字符串字面量（如 `"press (A)"`）不干扰括号匹配；非 ANSI 多行端口声明续行（如 `output [7:0] foo,\n bar;`）正确解析
- **unstrip 双轮机制**：先清理 `` `ifdef FPGA_SYN `` 块（含 `else`），再清理 `` `ifndef FPGA_SYN `` 块（无 `else`），避免无输出模块重复包裹导致 `` `endif `` / `` `ifdef `` 连续出现
- **通配符去重**：`eftu_mce_wrap` 同时被显式列举和 `eftu*` 匹配时自动去重，不会重复剥离
- **filelist 优先的模块查找**：`_find_module_rtl` 三级优先级：① filelist 中文件的实际 `module` 名 → ② 文件名 stem → ③ 全量扫描。确保 `eftu_mce_top.sv`（filelist 列出，内部 `module eftu_top`）优先于目录遍历碰到的 `eftu_top.sv`
- **信号宽度解析防御**：`_signal_width` 在信号名含非法正则字符时安全返回 None，不崩溃
- `full` 命令最后自动调用，无需手动执行

### 5. list-ips — 列出层级 IP

默认输出到 `hierarchy_ips.txt`，不打印到终端。使用 `fpga_core/scanner.py` 中的 `_HIER_MODULES` set 配置要扫描的层级路径：

```python
_HIER_MODULES: set[str] = {
    "standby_top",
    "standby_top.u_standby_int",
    "run_top",
    "run_top.u_run_int",
    "run_top.u_run_int.u_cppe",
    "run_top.u_run_int.u_cppe.u_platform_int",
    "run_top.u_platform_int",
}
```

填什么路径就扫什么路径，不递归、不自动扩展。

### 6. prefix — 宏/参数名前缀

FPGA 综合时不同 IP 目录的 `.vh` 定义同名宏（`` `define``）或 `parameter`/`localparam`，被全局 include 后互相覆盖导致冲突。`prefix` 步骤对 `PARAM_PREFIX_DIRS` 里配置的每个 `fpga_v` 目录，把该目录下 `.vh` 定义的名字，在该目录所有 `.vh`/`.v`/`.sv` 里统一加上目录专属前缀。

在 `fpga_core/config.py` 里配置：

```python
PARAM_PREFIX_DIRS = {
    "$COMMON_IP_DIR/dip_hsm/fpga_v": "HSM_",
    "$COMMON_IP_DIR/dip_sce/fpga_v": "SCE_",
}
```

- 处理对象：`` `define`` 宏（含带参数宏 `` `define F(a,b)``）+ `parameter`/`localparam`
- 作用范围：仅配置目录（`fpga_v`）下的所有 `.vh`/`.v`/`.sv`，不碰 `rtl_v`
- 引用形式全覆盖：`` `NAME`` / `` `NAME(x)`` / `` `ifdef NAME`` / `[NAME-1:0]` / 定义处本身
- 幂等：已带前缀的名字跳过，重复运行不叠加
- `full` 流程在 sync → memory 之后、filelist 之前自动执行（`PARAM_PREFIX_DIRS` 非空时）

## 配置文件

### `strip_ips.conf`

控制 `strip-ips` 命令需要剥离哪些实例，格式见 [strip-ips](#4-strip-ips--剥离例化)。

### `fpga_core/scanner.py` — `_HIER_MODULES`

控制 `list-ips` 和 `strip-ips` 的层级路径解析，格式见 [list-ips](#5-list-ips--列出层级-ip)。

### `fpga_core/config.py` 中的可配置项

| 配置 | 说明 |
|------|------|
| `MANUAL_PAIRS` | 手动指定 RTL ↔ FPGA 配对。FPGA 和 RTL 不在同一父目录时使用，syn c 自动同步（如 `{"HIRZER_0": {"fpga": "$SOC_TB_DIR/fpga/fpga_v/HIRZER_0.sv", "rtl": "$PLATFORM_DIR/ARM/CortexR52plus_0/rtl_v/HIRZER_0.sv"}}`） |
| `STUB_IPS` | stub IP 列表，在列表里的 IP 会用 `stub_v` 替代 `rtl_v`（如 `["dip_sce", "dft_cggroup"]`） |
| `EXTRA_INCLUDE_DIRS` | 追加到 `set_property include_dirs` 的目录（如 `["$CPPE_CPUSYSTEM_DIR/CORTEXM4/rtl_v"]`） |
| `PARAM_PREFIX_DIRS` | 宏/参数名前缀目录映射 `{目录: 前缀}`（如 `{"$COMMON_IP_DIR/dip_hsm/fpga_v": "HSM_"}`），`full` 流程中给该目录下 `.vh` 定义的宏/参数名加前缀 |
| `SKIP_DIRS` | 遍历时跳过的目录名（默认 `tool_data`） |
| `ENV_TO_FILELIST_VAR` | 环境变量 → Tcl 变量映射 |

> `STUB_IPS` 同时控制 `use_sce`：dip_sce 不在列表里时自动加 dip_sce include dir 和 `FPGA_SET_PROPERTY_SCE`。`EXTRA_INCLUDE_DIRS` 里 dip_sce 需用户手动添加。

## 性能

- **RTL 缓存**（三层优先级）：① `top_rtl_filelist` 显式列出的文件 → ② `-y` 库目录递归扫描 → ③ 目录遍历 fallback。filelist 条目永远优先于目录遍历，高优先级文件不会因低优先级同名文件而覆盖
- **例化解析缓存**：同一 RTL 文件被多条 `_HIER_MODULES` 路径引用时只解析一次 `extract_instances`
- **匹配结果缓存**：扁平名解析结果缓存，同一模块名多次查询不重复遍历路径链
- **通配符去重**：strip-ips 通配符（如 `eftu*`）自动展开后去重，同名例化不会重复剥离
- **二级模块名索引**：文件名 != 模块名时（如 `eftu_mce_top.sv` 内部 `module eftu_top`），自动解析文件头 2000 字节建立映射，后续 O(1) 查找

## 依赖

- Python >= 3.9，**零 pip 依赖**（stdlib only）
- 可选：`bcompare`（Beyond Compare，生成 HTML diff；无则自动用 difflib）
- 可选：`GenTB`（Verilog parser，无则用内置正则）

## 脚本结构

```
fpga.py                      # CLI 入口 + 配置加载 + 工作流编排
fpga_core/
├── config.py                # 路径、正则、Tcl 模板、环境变量
├── block_extractor.py       # 递归提取 ifdef FPGA_SYN 块（支持嵌套）
├── scanner.py               # 统一目录扫描（fpga_v / stub_v / memory）
├── merger.py                # diff + merge 核心，stub port 同步
├── memory.py                # memory port 提取 → SP-RAM / fpga_mem 生成
├── filelist.py              # filelist.f 生成
├── prefixer.py              # .vh 宏/参数名前缀（解决跨 IP 同名冲突）
├── report.py                # bcompare / difflib HTML diff 报告
└── stripper.py              # IP 例化剥离 + 输出 tie-off
strip_ips.conf               # strip-ips 批量配置文件
```

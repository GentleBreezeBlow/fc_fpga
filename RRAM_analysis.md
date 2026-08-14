# RRN22ULL256KX144M32I8R32_AD25_SHVT_C240506 分析

## 名称拆解

| 字段 | 含义 |
|------|------|
| `RRN22ULL` | RRAM 22nm ULL 工艺 |
| `256K` | 总容量 256K bits |
| `X144` | X 方向 144 根地址/数据线 |
| `M32` | 32:1 column mux（每行 32 列） |
| `I8R32` | 输入 8bit / 输出 32bit（测试配置） |
| `AD25` | Analog-Digital 25°C 校准 |
| `SHVT` | Super High VT（高阈值管） |

## 容量计算

```
256K bits / 32-bit data = 8192 words
8192 / 32 (M32 column mux) = 256 rows
numXadr = log2(256) = 8  bits
numYadr = log2(32)  = 5  bits
总地址 = 8 + 5 = 13 bits → 8192 深度
```

## IO 端口

### 读端口

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `DOUT` | output | 32 | 读出数据 |
| `RDONE` | output | 1 | 读完成标志 |
| `READ` | input | 1 | 读使能（高有效） |

### 写端口

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `DIN` | input | 32 | 写入数据 |
| `SET` | input | 1 | 写 strobe（写 SET 操作） |
| `RESET` | input | 1 | 写 strobe（写 RESET 操作） |

### 地址

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `XADR` | input | 8 | X 方向行地址 |
| `YADR` | input | 5 | Y 方向列地址 |

### 控制

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `CE` | input | 1 | Chip Enable |
| `NAP` | input | 1 | 休眠（高有效） |
| `RST` | input | 1 | 复位 |
| `XE` | input | 1 | X 方向使能 |
| `YE` | input | 1 | Y 方向使能 |
| `AE` | input | 1 | 地址使能 |
| `IFREN/IFREN1` | input | 1 | 接口使能 |
| `REDEN` | input | 1 | 冗余使能 |
| `POC_IO` | input | 1 | IO 上电控制 |
| `PCH_EXT` | input | 1 | 预充电外部 |
| `CFG_MACRO` | input | 8 | 配置字 |

### 冗余 / 模拟

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `DIN_CR` | input | 8 | 列冗余写数据 |
| `DOUT_CR` | output | 8 | 列冗余读数据 |
| `ANALOG_0` | inout | 1 | 模拟引脚 |

## 读写条件（来自 Liberty Comment）

```
Read   = CE & !NAP &  READ & !RESET & !SET
Write  = CE & !NAP & !READ & (RESET | SET) & !CFG_MACRO[118]
Form   = CE & !NAP & !READ & (RESET | SET) &  CFG_MACRO[118]
Idle   = CE=0 或 NAP=1
```

- **读**：`READ=1`，`SET=RESET=0` → DOUT 有效，RDONE 拉高
- **写**：`READ=0`，`SET=1` 或 `RESET=1` → DIN 写入
- **Form**：同写操作，但 `CFG_MACRO[118]=1`，用于 RRAM forming
- 读写互斥：`READ` 和 `SET/RESET` 不能同时为 1

## 时序（异步）

- 无 CLK 输入（`CK_EXT` 注释掉未用）
- 异步电平触发，非边沿触发
- 读延迟取决于模拟电路（非固定 cycle 数）

## FPGA 替代

用 `fpga_spram`（XPM SPRAM）替代，见 `rram_fpga_wrap.sv`：

| RRAM | fpga_spram |
|------|-----------|
| `{XADR, YADR}` (13bit) | `ram_addr` |
| `CE & !NAP` | `ram_me` |
| `!READ & (SET\|RESET)` | `ram_we` (复制到所有 byte lane) |
| `DIN` (32bit) | `ram_wdata` |
| `DOUT` (32bit) | `ram_rdata` |
| `READ` 延迟 1 拍 | `RDONE` |
| `clk`（新增） | `ram_clk` |

- **clk 必须和 rram_ctrl 用同一时钟**，避免跨时钟域亚稳态
- `DIN_CR`/`DOUT_CR`/`CFG_MACRO`/`IFREN`/`REDEN`/`POC_IO`/`PCH_EXT`/`ANALOG_0` 不在 FPGA 中实现

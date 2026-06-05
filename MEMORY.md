# Memory — fc_fpga

> Cross-session context. CLAUDE.md links here for project history.

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

## Test SoC

`test_soc/` — 6 个 IP：cpu_core(`ifdef+ifndef FPGA_SYN`)、uart(`ifdef FPGA_SYN + else`)、spi_ctrl(`ifndef FPGA_SYN + else`)、gpio(纯RTL)、dip_sce(stub)、mbist_wrap(2 memory wrapper)。`python verify.py` 7 步自动化验证。

## GitHub

- Repo: `github.com/GentleBreezeBlow/fc_fpga`
- Commits: `222b468` (30 files) → `e513f32` (slim CLAUDE.md)
- Windows 凭据管理器已存 cred，`git push` 即可

## Known issues

- stub_v port check 用 regex 回退（GenTB 路径不可用）
- filelist `fpga_v count mismatch` warning 因 TB 目录也含 fpga_v
- FLEXCAN wen+gwen 同时出现的 ram_we 逻辑待完善

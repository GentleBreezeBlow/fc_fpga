"""Prefix `` `define`` macros and ``parameter``/``localparam`` names.

解决不同 IP 目录下 ``.vh`` header 定义同名宏/参数导致的综合冲突：对每个配置
目录，把该目录下 ``.vh`` 里定义的名字，在该目录下所有 Verilog 文件里统一加一个
目录专属前缀（如 ``HSM_``）。
"""

from __future__ import annotations

import logging
import re
from pathlib import Path

from .config import RE_VERILOG_EXT, _expand_path

logger = logging.getLogger(__name__)

# `` `define NAME`` 宏名（带参数宏 `` `define F(a,b)`` 名字仍是 ``F``）
RE_DEFINE = re.compile(r"^\s*`define\s+(\w+)", re.MULTILINE)

# ``parameter [type] [width] NAME = ...`` / ``localparam ... NAME = ...``
# 取 ``=`` 前最后一个标识符作为名字，兼容 ``parameter DATA_WIDTH = 32``、
# ``parameter integer DATA_WIDTH = 32``、``localparam [7:0] ADDR = 0``。
# 已知限制：单行多参数 ``parameter A=1, B=2`` 只收第一个 ``A``。
RE_PARAM = re.compile(
    r"^\s*(?:parameter|localparam)\b[^=;\n]*?\b(\w+)\s*=",
    re.MULTILINE,
)

# 行注释 / 块注释（用于提取定义名时避免注释里的假定义被误收）
_RE_LINE_COMMENT = re.compile(r"//.*$", re.MULTILINE)
_RE_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.DOTALL)


def _strip_comments(text: str) -> str:
    """移除 Verilog ``//`` 和 ``/* */`` 注释。"""
    s = _RE_LINE_COMMENT.sub("", text)
    s = _RE_BLOCK_COMMENT.sub("", s)
    return s


def extract_defined_names(vh_content: str) -> set[str]:
    """从 ``.vh`` 内容里提取 `` `define`` 宏名和 parameter/localparam 名。"""
    cleaned = _strip_comments(vh_content)
    names: set[str] = set()
    names.update(m.group(1) for m in RE_DEFINE.finditer(cleaned))
    names.update(m.group(1) for m in RE_PARAM.finditer(cleaned))
    return names


def rename_names(content: str, names: set[str], prefix: str) -> str:
    """把 *names* 里每个名字在 *content* 里加前缀（幂等：已带前缀则跳过）。

    ``\bNAME\b`` 的单词边界同时覆盖宏引用 `` `NAME`` / `` `NAME(x)``、
    `` `ifdef NAME`` 里的裸形式、parameter 的裸引用，以及定义处本身。
    """
    # 按长度降序，双保险避免短名与长名边界的歧义
    for name in sorted(names, key=len, reverse=True):
        if name.startswith(prefix):
            continue
        content = re.sub(rf"\b{re.escape(name)}\b", prefix + name, content)
    return content


def apply_prefixes(prefix_dirs: dict[str, str]) -> int:
    """对每个 ``(目录, 前缀)`` 配置，把该目录下 ``.vh`` 定义的宏/参数名加前缀。

    返回实际改写的文件数量。
    """
    changed = 0
    for raw_dir, prefix in prefix_dirs.items():
        if not prefix:
            logger.warning("Empty prefix for %s -- skipping", raw_dir)
            continue
        resolved = _expand_path(raw_dir)
        if not resolved:
            logger.warning("Cannot resolve directory: %s -- skipping", raw_dir)
            continue
        d = Path(resolved)
        if not d.is_dir():
            logger.warning("Prefix directory not found: %s -- skipping", d)
            continue

        verilog_files = sorted(
            p for p in d.iterdir()
            if p.is_file() and RE_VERILOG_EXT.search(p.suffix)
        )
        vh_files = [p for p in verilog_files if p.suffix.lower() == ".vh"]
        if not vh_files:
            logger.warning("No .vh files in %s -- nothing to prefix", d)
            continue

        # 收集该目录下所有 .vh 定义的名字
        names: set[str] = set()
        for vh in vh_files:
            try:
                names |= extract_defined_names(
                    vh.read_text(encoding="utf-8", errors="replace")
                )
            except OSError:
                logger.warning("Cannot read %s", vh)
        if not names:
            logger.info("No macros/params defined in %s", d)
            continue

        # 对目录下所有 Verilog 文件（含 .vh 定义处）做前缀重命名
        for f in verilog_files:
            try:
                content = f.read_text(encoding="utf-8", errors="replace")
            except OSError:
                logger.warning("Cannot read %s", f)
                continue
            new_content = rename_names(content, names, prefix)
            if new_content != content:
                f.write_text(new_content, encoding="utf-8")
                changed += 1
                logger.info("Prefixed %s (%d name(s))", f.name, len(names))

    return changed

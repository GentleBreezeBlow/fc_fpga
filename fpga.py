#!/usr/bin/env python3
"""FPGA RTL synchronisation tool.

Synchronises ``fpga_v`` files with their ``rtl_v`` reference,
generates FPGA memory instantiations, and produces synthesis filelists.

Usage::

    python fpga.py full        # Run the complete workflow
    python fpga.py sync        # Sync fpga_v <- rtl_v only
    python fpga.py memory      # Generate memory replacement files only
    python fpga.py filelist    # Generate filelist.f only
    python fpga.py compare     # Run bcompare diff report only
    python fpga.py list-ips    # List IPs instantiated in hierarchy modules
"""

from __future__ import annotations

import os
import re
import shutil

import argparse
import logging
import sys
import time
from pathlib import Path

# ---------------------------------------------------------------------------
# Package imports
# ---------------------------------------------------------------------------
from fpga_core.config import (
    FPGAToolConfig, CYAN, GREEN, YELLOW, RED, BLUE, DIM, BOLD, RESET,
)
from fpga_core.block_extractor import FPGABlockExtractor
from fpga_core.scanner import DesignScanner
from fpga_core.merger import FileMerger, check_stub_ports, sync_stub_ports
from fpga_core.memory import generate_fpga_memory_file, generate_fpga_wrapper
from fpga_core.filelist import generate_filelist
from fpga_core.report import (
    generate_bcompare_script,
    generate_python_diff,
    merge_html_reports,
    run_bcompare,
)
from fpga_core.stripper import strip_instances


# ---------------------------------------------------------------------------
# Logging setup
# ---------------------------------------------------------------------------

class ColoredFormatter(logging.Formatter):
    """Formatter with per-level colour, compact module names, and boxed sections."""

    _LEVEL_STYLE = {
        logging.DEBUG:    (DIM,      " . "),
        logging.INFO:     (GREEN,    " > "),
        logging.WARNING:  (YELLOW,   " ! "),
        logging.ERROR:    (RED,      " X "),
        logging.CRITICAL: (RED+BOLD, " X "),
    }

    # Lines matching  >>> title <<<  are rendered as boxed section headers
    _SECTION_RE = re.compile(r"^>>> (.+) <<<$")

    def _box(self, text: str, width: int = 56) -> str:
        """Wrap *text* in an ASCII double-line box."""
        w = width - 4  # inner width
        pad = (w - len(text)) // 2
        inner = " " * pad + text + " " * (w - pad - len(text))
        top    = f"{CYAN}{BOLD}+{'=' * (width - 2)}+{RESET}"
        middle = f"{CYAN}{BOLD}|{RESET} {BOLD}{inner}{RESET} {CYAN}{BOLD}|{RESET}"
        bottom = f"{CYAN}{BOLD}+{'=' * (width - 2)}+{RESET}"
        return f"\n{top}\n{middle}\n{bottom}"

    def format(self, record: logging.Record) -> str:
        colour, symbol = self._LEVEL_STYLE.get(
            record.levelno, ("", " ")
        )

        short_name = record.name.rsplit(".", 1)[-1]
        ts = time.strftime("%H:%M:%S", time.localtime(record.created))

        line = f"{DIM}{ts}{RESET} {colour}{symbol}{RESET} {DIM}{short_name:>10}{RESET}"

        msg = record.getMessage()
        m = self._SECTION_RE.match(msg)
        if m:
            # Boxed section: no timestamp/module prefix
            return self._box(m.group(1))

        return f"{line} {msg}"


def setup_logging(verbose: bool = False) -> None:
    """Configure logging for the fpga tool."""
    level = logging.DEBUG if verbose else logging.INFO
    handler = logging.StreamHandler(sys.stderr)
    handler.setFormatter(ColoredFormatter())
    logging.basicConfig(
        level=level,
        handlers=[handler],
    )


# ---------------------------------------------------------------------------
# Workflow steps (reusable building blocks)
# ---------------------------------------------------------------------------

def sync_fpga_files(
    config: FPGAToolConfig,
    extractor: FPGABlockExtractor,
) -> tuple[list[str], list[str]]:
    """Synchronise all fpga_v files with their RTL references.

    Returns ``(notequal_fpga, notequal_rtl)`` lists for diff reporting.
    """
    logger = logging.getLogger(__name__)
    scanner = DesignScanner(config.design_dirs)
    merger = FileMerger(extractor)

    notequal_fpga: list[str] = []
    notequal_rtl: list[str] = []

    for rtl_path, fpga_path in scanner.iter_fpga_pairs():
        # mbist_wrap files are managed by memory generation, not by sync
        if "mbist_wrap" in str(fpga_path):
            continue
        try:
            result = merger.merge(rtl_path, fpga_path)
        except Exception as exc:
            logger.error("Merge failed for %s: %s", fpga_path, exc)
            continue

        if not result.is_equal:
            notequal_fpga.append(str(fpga_path))
            notequal_rtl.append(str(rtl_path))
            if result.fpga_block_warnings:
                logger.warning(
                    "FPGA blocks %s modified -- MANUAL REVIEW: %s",
                    result.fpga_block_warnings, fpga_path.resolve(),
                )

    # ---- Sync stub files -----------------------------------------------
    for stub_path, rtl_path in scanner.iter_stub_files():
        stub_name = stub_path.name
        if any(ip in stub_name for ip in config.use_stub_list):
            logger.info("Syncing stub: %s <- %s", stub_name, rtl_path.name)
            try:
                changed = sync_stub_ports(stub_path, rtl_path)
                if changed:
                    logger.info("Stub synced: %s", stub_name)
                    notequal_fpga.append(str(stub_path))
                    notequal_rtl.append(str(rtl_path))
            except Exception as exc:
                logger.error("Stub sync failed for %s: %s", stub_name, exc)

    return notequal_fpga, notequal_rtl


def gen_memory_files(config: FPGAToolConfig) -> list[Path]:
    """Generate FPGA wrapper files (mbist_wrap/fpga_v from rtl_v).

    For each ``*_wrap.v`` / ``*_wrap.sv`` in ``mbist_wrap/rtl_v``, creates a
    same-named FPGA wrapper in ``mbist_wrap/fpga_v`` with memory ports
    connected to ``fpga_spram`` instances.
    """
    logger = logging.getLogger(__name__)
    import os
    soc_dir = os.getenv("SOC_DESIGN_DIR", "")
    if not soc_dir:
        logger.warning("SOC_DESIGN_DIR not set -- skipping memory generation")
        return []

    mbist_rtl = Path(soc_dir) / "mbist_wrap" / "rtl_v"
    scanner = DesignScanner(config.design_dirs)
    wrappers = scanner.find_memory_wrappers(mbist_rtl)

    if not wrappers:
        logger.warning("No memory wrappers found in %s", mbist_rtl)
        return []

    output_dir = Path(soc_dir) / "mbist_wrap" / "fpga_v"
    if output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    generated: list[Path] = []
    for wrapper in wrappers:
        logger.info("Processing memory wrapper: %s", wrapper.name)
        try:
            result = generate_fpga_wrapper(wrapper, output_dir)
            if result:
                generated.append(result)
        except Exception as exc:
            logger.error("Memory generation failed for %s: %s", wrapper, exc)

    return generated


def gen_fpga_filelist(config: FPGAToolConfig) -> Path:
    """Generate the FPGA synthesis filelist."""
    logger = logging.getLogger(__name__)

    if config.design_config_dir is None:
        raise ValueError("DESIGN env var not set -- cannot locate source filelist")

    source = config.design_config_dir / "top_rtl_filelist"
    if not source.is_file():
        raise FileNotFoundError(f"Source filelist not found: {source}")

    return generate_filelist(
        design_dirs=config.design_dirs,
        use_stub_list=config.use_stub_list,
        tb_fpga_paths=config.tb_fpga_paths,
        source_filelist=source,
        output_path=Path("filelist.f"),
        use_sce=("dip_sce" not in config.use_stub_list),
    )


def run_diff_report(
    notequal_fpga: list[str],
    notequal_rtl: list[str],
    report_dir: Path = Path("reports"),
) -> Path:
    """Generate bcompare HTML diffs and merge into a summary report."""
    logger = logging.getLogger(__name__)

    if not notequal_fpga:
        logger.info("All files in sync -- no diff report needed.")
        return report_dir / "all.html"

    pairs = [(Path(rtl), Path(fpga)) for rtl, fpga in zip(notequal_rtl, notequal_fpga)]

    script_path, html_paths = generate_bcompare_script(pairs, report_dir)
    bcompare_ok = run_bcompare(script_path)

    if not bcompare_ok:
        logger.info("Falling back to Python HTML diff for %d pairs", len(pairs))
        html_paths = [
            generate_python_diff(rtl, fpga, report_dir / f"{fpga.stem}.html")
            for rtl, fpga in pairs
        ]

    summary = report_dir / "all.html"
    merge_html_reports(html_paths, summary)
    return summary


def _check_required_env() -> None:
    """Check that required environment variables are set, raise SystemExit if not."""
    required = [
        "SOC_DESIGN_DIR",
        "COMMON_IP_DIR",
        "MEMORY_DIR",
        "LIBRARY_DIR",
        "PLATFORM_DIR",
        "CPPE_DIR",
        "SOC_TB_DIR",
        "DESIGN",
        "CPPE_CPUSYSTEM_DIR",
    ]
    missing = [k for k in required if not os.getenv(k)]
    if missing:
        raise SystemExit("env vars not set: " + ", ".join(missing))


def list_hierarchy_ips(config: FPGAToolConfig, output_path: Path | None = None) -> None:
    """List all IPs instantiated in hierarchy modules and write to *output_path*."""
    logger = logging.getLogger(__name__)
    if output_path is None:
        output_path = Path("hierarchy_ips.txt")
    scanner = DesignScanner(config.design_dirs)
    result = scanner.list_hierarchy_ips()

    if not result:
        print("No hierarchy modules found.")
        return

    lines: list[str] = []
    for mod_path in sorted(result):
        entries = result[mod_path]
        lines.append(f"\n[{mod_path}]")
        for ip_mod, ip_inst, src in entries:
            lines.append(f"  {ip_mod:20s}  {ip_inst}")

    output_path.write_text("\n".join(lines).lstrip() + "\n", encoding="utf-8")
    logger.info("Wrote hierarchy IPs to %s (%d paths)", output_path, len(result))



def _parse_strip_file(file_path: str) -> list[tuple[str, list[str]]]:
    """Parse a strip-ips batch config file.

    Format (one per line)::

        # comments ignored
        <hier_module> : <inst1> <inst2> ...

    ``<hier_module>`` can be a flat module name (``run_int``) or a dotted
    path of instance names (``run_top.u_run_int``) for disambiguation.

    Example::

        run_int: spi1 spi2
        run_top.u_run_int: spi1
        standby_int: gpio
    """
    result: list[tuple[str, list[str]]] = []
    merged: dict[str, list[str]] = {}
    with open(file_path, "r", encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            if ":" not in line:
                continue
            hier_module, rest = line.split(":", 1)
            hier_module = hier_module.strip()
            instances = rest.strip().split()
            if hier_module and instances:
                merged.setdefault(hier_module, []).extend(instances)
    return [(k, v) for k, v in merged.items()]


def _run_strip_from_config(config: FPGAToolConfig, conf_path: str) -> None:
    """Run strip-ips using a batch config file (used by ``full`` workflow)."""
    _log = logging.getLogger(__name__)
    _log.info("Loading strip config: %s", conf_path)
    scanner = DesignScanner(config.design_dirs)
    tasks = _parse_strip_file(conf_path)
    if not tasks:
        _log.info("No valid entries in %s", conf_path)
        return
    _log.info("Strip tasks: %d module(s)", len(tasks))
    for hier_module, instances in tasks:
        _log.info("  [%s] %d instance(s): %s", hier_module, len(instances), ", ".join(instances))
    total = 0
    for hier_module, instances in tasks:
        _log.info("Resolving fpga_v for: %s", hier_module)
        fpga_path = scanner.resolve_fpga_path(hier_module)
        if fpga_path is None:
            _log.error("fpga_v file not found: %s", hier_module)
            continue
        _log.info("  -> %s", fpga_path)
        n = strip_instances(fpga_path, instances, scanner)
        _log.info("Stripped %d instance(s) from %s", n, hier_module)
        total += n
    if total == 0:
        _log.info("No instances were stripped")


def _run_strip(config: FPGAToolConfig, args, conf_path: str) -> None:
    """Run strip-ips in CLI mode (parses args for hier_module + instances)."""
    _log = logging.getLogger(__name__)
    scanner = DesignScanner(config.design_dirs)
    tasks: list[tuple[str, list[str]]] = []

    if args.file:
        tasks = _parse_strip_file(args.file)
        if not tasks:
            _log.error("No valid entries found in %s", args.file)
            return

    if args.hier_module:
        if not args.instances:
            _log.error("No instance names provided for %s", args.hier_module)
            return
        tasks.append((args.hier_module, list(args.instances)))

    if not tasks:
        _log.error("Specify hier_module + instances, or use --file")
        return

    total = 0
    for hier_module, instances in tasks:
        fpga_path = scanner.resolve_fpga_path(hier_module)
        if fpga_path is None:
            _log.error("fpga_v file not found: %s", hier_module)
            continue
        n = strip_instances(fpga_path, instances, scanner)
        _log.info("Stripped %d instance(s) from %s", n, hier_module)
        total += n

    if total == 0:
        _log.info("No instances were stripped")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    """Construct the argument parser."""
    parser = argparse.ArgumentParser(
        description="FPGA RTL synchronisation and filelist generation tool.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python fpga.py full         Run the complete workflow
  python fpga.py sync         Sync fpga_v files only
  python fpga.py memory       Generate memory replacement files
  python fpga.py filelist     Generate filelist.f
  python fpga.py compare      Run diff report on previously-synced files
  python fpga.py list-ips     List IPs instantiated in hierarchy modules
""",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable debug-level logging.",
    )

    sub = parser.add_subparsers(dest="command", help="Workflow step to run")

    sub.add_parser("full",    help="Run the complete FPGA workflow (sync + memory + filelist + compare)")
    sync_p = sub.add_parser("sync",    help="Synchronise fpga_v files with rtl_v references")
    sync_p.add_argument("--no-compare", action="store_true",
                        help="Skip diff report (sync only)")
    sub.add_parser("memory",  help="Generate FPGA SP-RAM memory replacement files")
    sub.add_parser("filelist", help="Generate FPGA synthesis filelist.f")
    sub.add_parser("compare",   help="Generate bcompare HTML diff report")
    list_ips_p = sub.add_parser("list-ips", help="List IPs instantiated in hierarchy modules")
    list_ips_p.add_argument(
        "-o", "--output",
        default="hierarchy_ips.txt",
        help="Output file path (default: hierarchy_ips.txt)",
    )

    strip_parser = sub.add_parser(
        "strip-ips",
        help="Remove IP instances from fpga_v with output tie-off",
        epilog="Examples:\n"
               "  python fpga.py strip-ips run_int spi2\n"
               "  python fpga.py strip-ips run_top.u_run_int spi1\n"
               "  python fpga.py strip-ips --file strip_ips.conf",
    )
    strip_parser.add_argument(
        "hier_module", nargs="?",
        help="Hierarchy module (e.g. run_int) or dotted path (e.g. run_top.u_run_int)",
    )
    strip_parser.add_argument(
        "instances", nargs="*",
        help="Instance names to remove (e.g. spi2 spi3)",
    )
    strip_parser.add_argument(
        "-f", "--file",
        help="Batch file (format: <hier_module> : <inst1> <inst2> ...)",
    )

    return parser


def main(argv: list[str] | None = None) -> int:
    """Entry point -- parse args and run the requested workflow step.

    Returns an exit code (0 = success, non-zero = error).
    """
    parser = build_parser()
    args = parser.parse_args(argv)
    setup_logging(args.verbose)

    logger = logging.getLogger("fpga")
    start_time = time.time()

    if args.command is None:
        parser.print_help()
        return 0

    # ---- Build config ----------------------------------------------------
    _check_required_env()
    try:
        config = FPGAToolConfig.from_env()
    except Exception as exc:
        logger.error("Configuration error: %s", exc)
        return 2

    extractor = FPGABlockExtractor()

    try:
        if args.command in ("full", "sync", "compare"):
            logger.info(">>> SYNCHRONIZING FPGA FILES <<<")
            ne_fpga, ne_rtl = sync_fpga_files(config, extractor)
            logger.info("Sync complete: %d file(s) modified", len(ne_fpga))

            if not getattr(args, "no_compare", False):
                logger.info(">>> GENERATING DIFF REPORT <<<")
                report = run_diff_report(ne_fpga, ne_rtl, config.report_dir)
                logger.info("Report: %s", report)

        if args.command in ("full", "memory"):
            logger.info(">>> GENERATING MEMORY WRAPPERS <<<")
            mem_files = gen_memory_files(config)
            logger.info("Generated %d memory files", len(mem_files))

        if args.command in ("full", "filelist"):
            logger.info(">>> GENERATING FILELIST <<<")
            fl_path = gen_fpga_filelist(config)
            logger.info("Filelist: %s", fl_path)

        if args.command in ("full", "strip-ips"):
            strip_config = getattr(args, "file", None) or "strip_ips.conf"
            if args.command == "full":
                logger.info(">>> STRIPPING IP INSTANCES <<<")
                if not Path(strip_config).is_file():
                    logger.info("No strip_ips.conf found -- skipping strip-ips")
                else:
                    _run_strip_from_config(config, strip_config)
            else:
                _run_strip(config, args, strip_config)

        if args.command == "list-ips":
            list_hierarchy_ips(config, Path(args.output))

    except Exception as exc:
        logger.error("Fatal: %s", exc, exc_info=args.verbose)
        return 1

    elapsed = time.time() - start_time
    logger.info("Done in %.2f s", elapsed)
    return 0


# ---------------------------------------------------------------------------
# Backward-compatible function-level API
# ---------------------------------------------------------------------------
# These wrappers preserve the old function signatures so existing callers
# (e.g. other scripts that ``import fpga``) continue to work.

_read_lines = lambda p: Path(p).read_text(errors="replace").splitlines(True)


def merge_fpga_files(file_a: str, file_b: str) -> None:
    """Backward-compatible wrapper for syncing one file pair."""
    extractor = FPGABlockExtractor()
    merger = FileMerger(extractor)
    merger.merge(Path(file_a), Path(file_b))


def gen_mbist_fpgafiles() -> None:
    """Backward-compatible wrapper for memory generation."""
    config = FPGAToolConfig.from_env()
    gen_memory_files(config)


def _gen_fpga_filelist_compat() -> None:
    """Backward-compatible wrapper for filelist generation (no-args version)."""
    config = FPGAToolConfig.from_env()
    gen_fpga_filelist(config)


# Legacy globals (deprecated -- use SyncContext instead)
notequal_fpga_lists: list[str] = []
notequal_rtl_lists: list[str] = []


# ---------------------------------------------------------------------------
# __main__ hook
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    sys.exit(main())

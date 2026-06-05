#!/usr/bin/env python3
"""FPGA RTL synchronisation tool.

Synchronises ``fpga_v`` files with their ``rtl_v`` reference,
generates FPGA memory instantiations, and produces synthesis filelists.

Usage::

    python fpga.py full        # Run the complete workflow
    python fpga.py sync        # Sync fpga_v ← rtl_v only
    python fpga.py memory      # Generate memory replacement files only
    python fpga.py filelist    # Generate filelist.f only
    python fpga.py compare     # Run bcompare diff report only
"""

from __future__ import annotations

import argparse
import logging
import sys
import time
from pathlib import Path

# ---------------------------------------------------------------------------
# Package imports
# ---------------------------------------------------------------------------
from fpga_core.config import FPGAToolConfig
from fpga_core.block_extractor import FPGABlockExtractor
from fpga_core.scanner import DesignScanner
from fpga_core.merger import FileMerger, check_stub_ports
from fpga_core.memory import generate_fpga_memory_file, generate_fpga_wrapper
from fpga_core.filelist import generate_filelist
from fpga_core.report import (
    generate_bcompare_script,
    generate_python_diff,
    merge_html_reports,
    run_bcompare,
)


# ---------------------------------------------------------------------------
# Logging setup
# ---------------------------------------------------------------------------

def setup_logging(verbose: bool = False) -> None:
    """Configure logging for the fpga tool."""
    level = logging.DEBUG if verbose else logging.INFO
    fmt = "%(asctime)s [%(levelname)-7s] %(name)s: %(message)s"
    logging.basicConfig(
        level=level,
        format=fmt,
        datefmt="%H:%M:%S",
        stream=sys.stderr,
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
        logger.info("Merging: %s ← %s", fpga_path.name, rtl_path.name)
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
                    "FPGA blocks %s in %s may need manual review",
                    result.fpga_block_warnings, fpga_path.name,
                )

    # ---- Check stub files ------------------------------------------------
    for stub_path, rtl_path in scanner.iter_stub_files():
        stub_name = stub_path.name
        if any(ip in stub_name for ip in config.use_stub_list):
            logger.info("Checking stub: %s", stub_name)
            try:
                errors = check_stub_ports(stub_path, rtl_path)
                for err in errors:
                    logger.error("[stub] %s: %s", stub_name, err)
            except Exception as exc:
                logger.error("Stub check failed for %s: %s", stub_name, exc)

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
        logger.warning("SOC_DESIGN_DIR not set — skipping memory generation")
        return []

    mbist_rtl = Path(soc_dir) / "mbist_wrap" / "rtl_v"
    scanner = DesignScanner(config.design_dirs)
    wrappers = scanner.find_memory_wrappers(mbist_rtl)

    if not wrappers:
        logger.warning("No memory wrappers found in %s", mbist_rtl)
        return []

    output_dir = Path(soc_dir) / "mbist_wrap" / "fpga_v"
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
        raise ValueError("DESIGN env var not set — cannot locate source filelist")

    source = config.design_config_dir / "top_rtl_filelist"
    if not source.is_file():
        raise FileNotFoundError(f"Source filelist not found: {source}")

    return generate_filelist(
        design_dirs=config.design_dirs,
        use_stub_list=config.use_stub_list,
        tb_fpga_paths=config.tb_fpga_paths,
        source_filelist=source,
        output_path=Path("filelist.f"),
        use_sce=("dip_sce" in config.use_stub_list),
    )


def run_diff_report(
    notequal_fpga: list[str],
    notequal_rtl: list[str],
    report_dir: Path = Path("reports"),
) -> Path:
    """Generate bcompare HTML diffs and merge into a summary report."""
    logger = logging.getLogger(__name__)

    if not notequal_fpga:
        logger.info("All files in sync — no diff report needed.")
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
""",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable debug-level logging.",
    )

    sub = parser.add_subparsers(dest="command", help="Workflow step to run")

    sub.add_parser("full",    help="Run the complete FPGA workflow (sync + memory + filelist + compare)")
    sub.add_parser("sync",    help="Synchronise fpga_v files with rtl_v references")
    sub.add_parser("memory",  help="Generate FPGA SP-RAM memory replacement files")
    sub.add_parser("filelist", help="Generate FPGA synthesis filelist.f")
    sub.add_parser("compare", help="Generate bcompare HTML diff report")

    return parser


def main(argv: list[str] | None = None) -> int:
    """Entry point — parse args and run the requested workflow step.

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
    try:
        config = FPGAToolConfig.from_env()
    except Exception as exc:
        logger.error("Configuration error: %s", exc)
        return 2

    extractor = FPGABlockExtractor()

    try:
        if args.command in ("full", "sync", "compare"):
            logger.info("=== Step 1: Sync fpga_v files ===")
            ne_fpga, ne_rtl = sync_fpga_files(config, extractor)
            logger.info("Sync complete: %d file(s) modified", len(ne_fpga))

            logger.info("=== Step 2: Diff report ===")
            report = run_diff_report(ne_fpga, ne_rtl, config.report_dir)
            logger.info("Report: %s", report)

        if args.command in ("full", "memory"):
            logger.info("=== Memory replacement ===")
            mem_files = gen_memory_files(config)
            logger.info("Generated %d memory files", len(mem_files))

        if args.command in ("full", "filelist"):
            logger.info("=== Filelist generation ===")
            fl_path = gen_fpga_filelist(config)
            logger.info("Filelist: %s", fl_path)

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


# Legacy globals (deprecated — use SyncContext instead)
notequal_fpga_lists: list[str] = []
notequal_rtl_lists: list[str] = []


# ---------------------------------------------------------------------------
# __main__ hook
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    sys.exit(main())

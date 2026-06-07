"""Diff reporting -- bcompare HTML generation and report merging.

Wraps external ``bcompare`` (Beyond Compare) for side-by-side HTML diffs
and provides a pure-Python ``difflib.HtmlDiff`` fallback.
"""

from __future__ import annotations

import logging
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def generate_bcompare_script(
    pairs: list[tuple[Path, Path]],
    output_dir: Path,
    script_path: Path = Path("bcompare_script.txt"),
) -> tuple[Path, list[Path]]:
    """Create a Beyond Compare script that diffs each (rtl, fpga) pair.

    Parameters:
        pairs:       List of ``(rtl_file, fpga_file)`` paths to compare.
        output_dir:  Directory to write HTML reports into.
        script_path: Where to write the bcompare script.

    Returns:
        ``(script_path, html_paths)`` -- the script file and the list of
        expected HTML report paths.
    """
    output_dir.mkdir(parents=True, exist_ok=True)
    html_paths: list[Path] = []

    lines = ["log verbose \"bcompare_log.txt\"\n"]
    for rtl, fpga in pairs:
        mod_name = _extract_module_name(fpga)
        html_path = output_dir / f"{mod_name}.html"
        html_paths.append(html_path)

        lines.append(
            f"text-report layout:side-by-side "
            f"options:ignore-unimportant,display-context "
            f"output-to:\"{html_path}\" "
            f"output-options:html-color "
            f"\"{rtl}\" \"{fpga}\"\n"
        )

    script_path.write_text("".join(lines), encoding="utf-8")
    logger.info("BCompare script written: %s (%d comparisons)", script_path, len(pairs))
    return script_path, html_paths


def run_bcompare(
    script_path: Path,
    bcompare_exe: Optional[Path] = None,
    timeout: int = 300,
) -> bool:
    """Execute Beyond Compare with *script_path*.

    Returns ``True`` on success.  If bcompare is not available, logs a
    warning and returns ``False``.
    """
    exe = bcompare_exe or _find_bcompare()
    if exe is None:
        logger.warning("bcompare not found -- skipping external diff")
        return False

    try:
        subprocess.run(
            [str(exe), "-silent", f"@{script_path}"],
            check=True,
            timeout=timeout,
            capture_output=True,
            text=True,
        )
        logger.info("bcompare completed successfully")
        return True
    except subprocess.TimeoutExpired:
        logger.error("bcompare timed out after %ds", timeout)
        return False
    except subprocess.CalledProcessError as exc:
        logger.error("bcompare failed: %s", exc.stderr.strip() if exc.stderr else exc)
        return False
    except FileNotFoundError:
        logger.warning("bcompare executable not found")
        return False


def generate_python_diff(
    rtl_path: Path,
    fpga_path: Path,
    output_path: Path,
) -> Path:
    """Generate an HTML side-by-side diff using Python's difflib.

    Pure-Python fallback when bcompare is not available.
    """
    import difflib

    rtl_lines = _read_lines(rtl_path)
    fpga_lines = _read_lines(fpga_path)

    differ = difflib.HtmlDiff(tabsize=4, wrapcolumn=80)
    html = differ.make_file(
        rtl_lines, fpga_lines,
        fromdesc=str(rtl_path),
        todesc=str(fpga_path),
        context=True,
        numlines=3,
    )

    output_path.write_text(html, encoding="utf-8")
    logger.info("Python HTML diff written: %s", output_path)
    return output_path


def merge_html_reports(
    html_paths: list[Path],
    output_path: Path,
) -> Path:
    """Merge multiple HTML diff reports into a single summary file.

    Extracts ``<body>`` content from each report and concatenates.
    """
    import re as _re

    head_content = ""
    body_parts: list[str] = []
    _re_head = _re.compile(r"<head>(.*?)</head>", _re.DOTALL | _re.IGNORECASE)
    _re_body = _re.compile(r"<body>(.*?)</body>", _re.DOTALL | _re.IGNORECASE)

    for i, path in enumerate(html_paths):
        if not path.is_file():
            logger.warning("Report not found, skipping: %s", path)
            continue

        html_text = path.read_text(encoding="utf-8")

        if i == 0:
            m = _re_head.search(html_text)
            if m:
                head_content = f"<head>{m.group(1)}</head>"

        m = _re_body.search(html_text)
        if m:
            body_parts.append(m.group(1))

    full_html = f"""<!DOCTYPE html>
<html>
{head_content}
<body>
{''.join(body_parts)}
</body>
</html>"""

    output_path.write_text(full_html, encoding="utf-8")
    logger.info("Merged %d reports -> %s", len(html_paths), output_path)
    return output_path


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _find_bcompare() -> Optional[Path]:
    """Locate the bcompare executable."""
    # Common install locations
    candidates = [
        "bcompare",
        "bcomp",
        "/usr/bin/bcompare",
        "/usr/local/bin/bcompare",
        "C:/Program Files/Beyond Compare 4/BCompare.exe",
        "C:/Program Files/Beyond Compare 5/BCompare.exe",
    ]
    for c in candidates:
        if shutil.which(c):
            return Path(c)
    return None


def _extract_module_name(fpga_path: Path) -> str:
    """Extract a human-readable module name from an fpga_v file path.

    Uses the file stem (module name) -- always unique, avoids collisions
    when multiple fpga_v files share a parent directory (e.g. mbist_wrap/).
    """
    return fpga_path.stem


def _read_lines(path: Path) -> list[str]:
    """Read file as stripped lines for difflib."""
    try:
        return path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return [f"[Error reading {path}]"]

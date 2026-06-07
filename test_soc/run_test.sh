#!/bin/bash
# ================================================================
# FPGA Tool Test Runner
# Usage: source run_test.sh   (or: . run_test.sh)
# Then run individual tests like:  test_sync, test_memory, etc.
# ================================================================

export SOC_DESIGN_DIR="/d/ai/fpga/test_soc/design"
export COMMON_IP_DIR="/d/ai/fpga/test_soc/common_ip"
export MEMORY_DIR="/d/ai/fpga/test_soc/dummy_mem"
export LIBRARY_DIR="/d/ai/fpga/test_soc/dummy_lib"
export PLATFORM_DIR="/d/ai/fpga/test_soc/dummy_plat"
export CPPE_DIR="/d/ai/fpga/test_soc/dummy_cppe"
export SOC_TB_DIR="/d/ai/fpga/test_soc/tb"
export DESIGN="/d/ai/fpga/test_soc"
export CPPE_CPUSYSTEM_DIR="/d/ai/fpga/test_soc/dummy_cm4"

cd /d/ai/fpga

echo "========================================"
echo "  FPGA Tool Test Environment"
echo "========================================"
echo "SOC_DESIGN_DIR = $SOC_DESIGN_DIR"
echo "COMMON_IP_DIR  = $COMMON_IP_DIR"
echo "DESIGN         = $DESIGN"
echo "SOC_TB_DIR     = $SOC_TB_DIR"
echo ""
echo "Available test commands:"
echo "  test_sync      — Run fpga_v <- rtl_v sync only"
echo "  test_memory    — Generate memory replacement files"
echo "  test_filelist  — Generate filelist.f"
echo "  test_compare   — Run bcompare diff report"
echo "  test_full      — Run complete workflow"
echo "  test_pairs     — List all rtl_v <-> fpga_v pairs"
echo "  test_list_ips  — List IPs in hierarchy modules"
echo "  test_reset     — Reset fpga_v files to original state"
echo ""

test_pairs() {
    echo "=== RTL <-> FPGA file pairs ==="
    python3 -c "
from pathlib import Path
from fpga_core.scanner import DesignScanner
import os
dirs = [Path(os.environ['SOC_DESIGN_DIR']), Path(os.environ['COMMON_IP_DIR'])]
dirs = [d for d in dirs if d.is_dir()]
scanner = DesignScanner(dirs)
for r, f in scanner.iter_fpga_pairs():
    print(f'  {f.parent.parent.name}/{f.parent.name}/{f.name:20s}  <-  {r.parent.name}/{r.name}')
print()
for s, r in scanner.iter_stub_files():
    print(f'  [STUB] {s.parent.parent.name}/{s.parent.name}/{s.name:15s}  <-  {r.name}')
"
}

test_sync() {
    echo "=== Running: fpga_v sync ==="
    python3 fpga.py -v sync
    echo ""
    echo "=== Results ==="
    echo "Check the fpga_v files to see merged changes:"
    find $SOC_DESIGN_DIR -path "*/fpga_v/*.sv" -exec echo "  {}" \;
}

test_memory() {
    echo "=== Running: memory replacement ==="
    python3 fpga.py -v memory
    echo ""
    ls -la fpga_memory_output/ 2>/dev/null || echo "  (no memory output dir)"
}

test_filelist() {
    echo "=== Running: filelist generation ==="
    python3 fpga.py -v filelist
    echo ""
    echo "=== Generated filelist.f (first 40 lines) ==="
    head -40 filelist.f 2>/dev/null || echo "  (filelist.f not found)"
}

test_compare() {
    echo "=== Running: diff report ==="
    python3 fpga.py -v compare
    echo ""
    ls -la reports/ 2>/dev/null || echo "  (no reports dir)"
}

test_full() {
    echo "=== Running: FULL workflow ==="
    python3 fpga.py -v full
    echo ""
    echo "=== Outputs ==="
    ls -la filelist.f fpga_memory_output/ reports/ 2>/dev/null
}

test_list_ips() {
    echo "=== List IPs in hierarchy modules ==="
    python3 fpga.py list-ips
}

test_reset() {
    echo "=== Resetting fpga_v files to original state ==="
    cd /d/ai/fpga
    git checkout test_soc/design/chip_top/fpga_v/chip_top.sv 2>/dev/null || echo "  (not under git — skipping chip_top)"
    git checkout test_soc/design/run_int/cpu_core/fpga_v/cpu_core.sv 2>/dev/null || echo "  (not under git — skipping cpu_core)"
    git checkout test_soc/design/standby_int/uart/fpga_v/uart_top.sv 2>/dev/null || echo "  (not under git — skipping uart)"
    git checkout test_soc/design/run_int/spi_controller/fpga_v/spi_ctrl.sv 2>/dev/null || echo "  (not under git — skipping spi_ctrl)"
    echo "Done."
}

echo "[Test env ready]"

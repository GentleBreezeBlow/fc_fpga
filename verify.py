#!/usr/bin/env python3
"""
FPGA Tool Verification Script
Usage:  python verify.py              (full test)
        python verify.py --reset-only  (only reset fpga_v to OLD state)
"""

import os
import sys
from pathlib import Path

# ---- Encoding helpers (Windows defaults to GBK, we need UTF-8) ----
def _read(path):
    return path.read_text(encoding="utf-8")

def _write(path, text):
    path.write_text(text, encoding="utf-8")

# ---- Setup test environment ----
HERE = Path(__file__).resolve().parent
os.environ["SOC_DESIGN_DIR"]       = str(HERE / "test_soc" / "design")
os.environ["COMMON_IP_DIR"]        = str(HERE / "test_soc" / "common_ip")
os.environ["MEMORY_DIR"]           = str(HERE / "test_soc" / "dummy_mem")
os.environ["LIBRARY_DIR"]          = str(HERE / "test_soc" / "dummy_lib")
os.environ["PLATFORM_DIR"]         = str(HERE / "test_soc" / "dummy_plat")
os.environ["CPPE_DIR"]             = str(HERE / "test_soc" / "dummy_cppe")
os.environ["SOC_TB_DIR"]           = str(HERE / "test_soc" / "tb")
os.environ["DESIGN"]               = str(HERE / "test_soc")
os.environ["CPPE_CPUSYSTEM_DIR"]   = str(HERE / "test_soc" / "dummy_cm4")

sys.path.insert(0, str(HERE))


# ======================================================================
# Test workflow
# ======================================================================

def reset_fpga_v():
    """Restore fpga_v files to their OLD (pre-sync) state."""

    cpu_old = """\
// cpu_core.sv -- FPGA version (OLD)

module cpu_core #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 32
) (
  input  wire                    clk,
  input  wire                    rst_n,
  input  wire                    fetch_en,
  input  wire [ADDR_WIDTH-1:0]   instr_addr,
  output wire [DATA_WIDTH-1:0]   instr_data
);

`ifdef FPGA_SYN
  wire clk_gated;
  BUFGCE fpga_clk_gate (.O(clk_gated), .I(clk), .CE(fetch_en));
`endif

  reg [DATA_WIDTH-1:0]  pc_ff;
  reg [DATA_WIDTH-1:0]  ir_ff;
  reg                   valid_ff;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_ff    <= {DATA_WIDTH{1'b0}};
      ir_ff    <= {DATA_WIDTH{1'b0}};
      valid_ff <= 1'b0;
    end else if (fetch_en) begin
      pc_ff    <= instr_addr;
      ir_ff    <= instr_data;
      valid_ff <= 1'b1;
    end
  end

`ifndef FPGA_SYN
  assign debug_pc = pc_ff;
`else
  wire [DATA_WIDTH-1:0] debug_pc;
  ila_core debug_ila (.clk(clk), .probe0(pc_ff), .probe1(ir_ff));
`endif

endmodule
"""

    uart_old = """\
// uart_top.sv -- FPGA version (OLD)

module uart_top #(
  parameter CLK_FREQ  = 50_000_000,
  parameter BAUD_RATE = 115200
) (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        rx,
  output wire        tx,
  input  wire [7:0]  tx_data,
  input  wire        tx_valid,
  output wire        tx_ready,
  output wire [7:0]  rx_data,
  output wire        rx_valid
);

`ifdef FPGA_SYN
  wire pll_clk;
  PLLE2_BASE #(
    .CLKIN1_PERIOD (20.0), .CLKFBOUT_MULT (10), .DIVCLK_DIVIDE (2)
  ) uart_pll (.CLKIN1(clk), .CLKOUT0(pll_clk), .LOCKED());
`else
  wire pll_clk = clk;
`endif

  localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;
  reg [15:0] baud_cnt;
  wire baud_tick = (baud_cnt == BAUD_DIV - 1);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      baud_cnt <= '0;
    else if (baud_tick)
      baud_cnt <= '0;
    else
      baud_cnt <= baud_cnt + 1;
  end

endmodule
"""

    spi_old = """\
// spi_ctrl.sv -- FPGA version (OLD)

module spi_ctrl #(
  parameter DATA_WIDTH = 8,
  parameter CLK_DIV    = 4
) (
  input  wire                    clk,
  input  wire                    rst_n,
  input  wire                    start,
  input  wire [DATA_WIDTH-1:0]   tx_data,
  output wire [DATA_WIDTH-1:0]   rx_data,
  output wire                    done,
  input  wire                    miso,
  output wire                    mosi,
  output wire                    sclk,
  output wire                    cs_n
);

  reg [7:0] clk_cnt;
  wire clk_en = (clk_cnt == CLK_DIV - 1);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      clk_cnt <= '0;
    else if (clk_en)
      clk_cnt <= '0;
    else
      clk_cnt <= clk_cnt + 1'b1;
  end

  localparam IDLE = 2'b00, SHIFT = 2'b01, DONE = 2'b10;
  reg [1:0] state, next_state;
  reg [7:0] bit_cnt;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  always @(*) begin
    next_state = state;
    case (state)
      IDLE:  if (start) next_state = SHIFT;
      SHIFT: if (bit_cnt == DATA_WIDTH - 1 && clk_en) next_state = DONE;
      DONE:  next_state = IDLE;
    endcase
  end

`ifndef FPGA_SYN
  assign sclk = (state == SHIFT) ? clk : 1'b0;
`else
  ODDR sclk_ddr (.Q(sclk), .C(clk), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));
`endif

  assign done = (state == DONE);
  assign cs_n = (state == IDLE);
endmodule
"""

    files = {
        HERE / "test_soc/design/cpu_core/fpga_v/cpu_core.sv":    cpu_old,
        HERE / "test_soc/design/uart/fpga_v/uart_top.sv":        uart_old,
        HERE / "test_soc/design/spi_controller/fpga_v/spi_ctrl.sv": spi_old,
    }
    for path, content in files.items():
        _write(path, content)
        print(f"  [OK] {path.parent.name}/{path.name}  ->  OLD version")


def banner(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")


def ok(msg):
    print(f"  [PASS] {msg}")

def fail(msg):
    print(f"  [FAIL] {msg}")

def check(condition, msg):
    if condition:
        ok(msg)
    else:
        fail(msg)
    return condition


def run():
    from fpga_core.scanner import DesignScanner

    # ---- Step 1: Scan ----
    banner("STEP 1: Scan file pairs")
    design_dirs = [
        Path(os.environ["SOC_DESIGN_DIR"]),
        Path(os.environ["COMMON_IP_DIR"]),
    ]
    design_dirs = [d for d in design_dirs if d.is_dir()]
    scanner = DesignScanner(design_dirs)

    fpga_pairs = list(scanner.iter_fpga_pairs())
    stub_pairs = list(scanner.iter_stub_files())
    memory_wrappers = scanner.find_memory_wrappers(
        Path(os.environ["SOC_DESIGN_DIR"]) / "mbist_wrap" / "rtl_v"
    )

    print(f"  FPGA pairs: {len(fpga_pairs)}")
    for r, f in fpga_pairs:
        print(f"    {f.parent.name}/{f.name:25s}  <-  {r.name}")
    print(f"  Stub pairs: {len(stub_pairs)}")
    for s, r in stub_pairs:
        print(f"    {s.name:25s}  <-  {r.name}")
    print(f"  Memory wrappers: {len(memory_wrappers)}")
    for w in memory_wrappers:
        print(f"    {w.name}")

    # ---- Step 2: Confirm OLD state ----
    banner("STEP 2: Confirm fpga_v files are OLD (before sync)")

    cpu_fpga = HERE / "test_soc/design/cpu_core/fpga_v/cpu_core.sv"
    uart_fpga = HERE / "test_soc/design/uart/fpga_v/uart_top.sv"
    spi_fpga = HERE / "test_soc/design/spi_controller/fpga_v/spi_ctrl.sv"

    txt = _read(cpu_fpga)
    check("stall_req" not in txt, "cpu_core: no stall_req (OLD)")

    txt = _read(uart_fpga)
    check("cts" not in txt.split(");")[0], "uart:     no cts/rts (OLD)")

    txt = _read(spi_fpga)
    check("cpol" not in txt.split(");")[0], "spi_ctrl: no cpol/cpha (OLD)")

    # ---- Step 3: Run sync ----
    banner("STEP 3: Run fpga_v <- rtl_v sync")
    from fpga_core.block_extractor import FPGABlockExtractor
    from fpga_core.merger import FileMerger

    merger = FileMerger(FPGABlockExtractor())
    results = []
    for rtl, fpga in fpga_pairs:
        r = merger.merge(rtl, fpga)
        results.append(r)
        tag = "SYNCED" if not r.is_equal else "(no change)"
        w = f"  [WARN blocks: {r.fpga_block_warnings}]" if r.fpga_block_warnings else ""
        print(f"  {tag:12s}  {fpga.name}{w}")

    mod_count = sum(1 for r in results if not r.is_equal)
    print(f"\n  Files modified: {mod_count}")

    # ---- Step 4: Verify AFTER sync ----
    banner("STEP 4: Verify AFTER sync")

    txt = _read(cpu_fpga)
    check("stall_req" in txt and "stall_ack" in txt,
          "cpu_core: stall_req + stall_ack added from RTL")
    check("BUFGCE" in txt and "ila_core" in txt,
          "cpu_core: FPGA blocks (BUFGCE, ila_core) preserved")
    check("!stall_req" in txt,
          "cpu_core: always block uses stall condition")

    txt = _read(uart_fpga)
    check("cts" in txt and "rts" in txt,
          "uart:     cts/rts added from RTL")
    check("PLLE2" in txt,
          "uart:     FPGA block (PLLE2) preserved")

    txt = _read(spi_fpga)
    check("cpol" in txt and "cpha" in txt,
          "spi_ctrl: cpol/cpha added from RTL")
    check("ODDR" in txt,
          "spi_ctrl: FPGA block (ODDR) preserved")

    # ---- Step 5: Memory ----
    banner("STEP 5: Run memory replacement")
    from fpga_core.memory import generate_fpga_memory_file

    mem_out = HERE / "fpga_memory_output"
    if mem_out.exists():
        import shutil
        shutil.rmtree(mem_out)
    mem_out.mkdir()

    for w in memory_wrappers:
        out = generate_fpga_memory_file(w, mem_out)
        if out:
            print(f"  [OK] {out.name}")
            c = _read(out)
            check("fpga_spram" in c, f"    {out.name}: contains fpga_spram")
            check("MEMDEPTH" in c and "MEMWIDTH" in c,
                  f"    {out.name}: has MEMDEPTH+MEMWIDTH params")

    # ---- Step 6: Filelist ----
    banner("STEP 6: Run filelist generation")
    from fpga_core.filelist import generate_filelist

    source = HERE / "test_soc/config/top_rtl_filelist"
    tb_paths = [Path(os.environ["SOC_TB_DIR"]) / "fpga" / "fpga_v"]

    fl_path = generate_filelist(
        design_dirs=design_dirs,
        use_stub_list=["dip_sce"],
        tb_fpga_paths=tb_paths,
        source_filelist=source,
        output_path=HERE / "filelist.f",
        use_sce=True,
    )

    c = _read(fl_path)
    check("tsmc_lib" not in c, "filelist: tsmc_lib filtered out")
    check("gf22_lib" not in c,  "filelist: gf22_lib filtered out")
    check("MEMORY_DIR" not in c, "filelist: MEMORY_DIR filtered out")
    check("fpga_v" in c,         "filelist: fpga_v paths present")
    check("set_property" in c,   "filelist: Tcl properties present")

    # ---- Step 7: HTML report ----
    banner("STEP 7: Generate HTML diff report")
    from fpga_core.report import (
        generate_bcompare_script, run_bcompare,
        generate_python_diff, merge_html_reports,
    )

    report_dir = HERE / "reports"
    if report_dir.exists():
        import shutil
        shutil.rmtree(report_dir)
    report_dir.mkdir()

    ne_fpga_p = [r.fpga_file for r in results if not r.is_equal]
    ne_rtl_p  = [r.rtl_file for r in results if not r.is_equal]

    if ne_fpga_p:
        pairs = list(zip(ne_rtl_p, ne_fpga_p))
        script_path, html_paths = generate_bcompare_script(pairs, report_dir)
        ok_bcomp = run_bcompare(script_path)
        if not ok_bcomp:
            print("  bcompare not found, using Python difflib fallback...")
            # regenerate html_paths since bcompare didn't produce them
            html_paths = []
            for rp, fp in pairs:
                hp = report_dir / f"{fp.stem}.html"
                generate_python_diff(rp, fp, hp)
                html_paths.append(hp)

        summary = merge_html_reports(html_paths, report_dir / "all.html")
        print(f"  [OK] Summary report: {summary}")
    else:
        print("  All files in sync, no diff needed")

    # ---- Summary ----
    banner("Done!")
    print(f"""
  Output files:
    {fl_path}
    {mem_out}/
    {report_dir}/all.html

  Open report:  start {report_dir / 'all.html'}
""")
    import webbrowser
    all_html = report_dir / "all.html"
    if all_html.exists():
        webbrowser.open(str(all_html))


if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser(description="FPGA Tool Verification")
    p.add_argument("--reset-only", action="store_true",
                   help="Only reset fpga_v to OLD state")
    args = p.parse_args()

    if args.reset_only:
        print("Resetting fpga_v files to OLD state...")
        reset_fpga_v()
        print("Done. Now run:  python verify.py")
    else:
        print("Resetting fpga_v files to OLD state...")
        reset_fpga_v()
        run()

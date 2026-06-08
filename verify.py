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

    chip_top_old = """\
// chip_top.sv -- FPGA version (OLD)

module chip_top (
  input  wire        sys_clk,
  input  wire        sys_rst_n,
  input  wire        jtag_tck,
  input  wire        jtag_tms,
  input  wire        jtag_tdi,
  output wire        jtag_tdo,
  input  wire        uart_rx,
  output wire        uart_tx
);

`ifdef FPGA_SYN
  wire fpga_clk;
  BUFG bufg_inst (.O(fpga_clk), .I(sys_clk));
`endif

  wire          standby_clk, run_clk;
  wire          standby_rst_n, run_rst_n;
  wire [31:0]   standby_irq, run_irq;
  wire [31:0]   platform_irq;

  paring u_paring (
    .sys_clk   (sys_clk),
    .sys_rst_n (sys_rst_n),
    .*
  );

  standby_top u_standby (
    .clk        (standby_clk),
    .rst_n      (standby_rst_n),
    .irq        (standby_irq),
    .uart_rx    (uart_rx),
    .uart_tx    (uart_tx),
    .*
  );

  run_top u_run (
    .clk          (run_clk),
    .rst_n        (run_rst_n),
    .irq          (run_irq),
    .platform_irq (platform_irq),
    .*
  );

`ifndef FPGA_SYN
  assign debug_mode = 1'b0;
`else
  wire debug_mode;
  ila_top debug_ila (.clk(sys_clk), .probe0(standby_irq));
`endif

endmodule
"""

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

    # ---- NEW: OLD versions for added modules ----

    platform_int_old = """\
// platform_int.sv -- OLD: interrupt controller only, no memory

module platform_int #(
  parameter N_IRQ = 32
) (
  input  wire               clk,
  input  wire               rst_n,
  input  wire [N_IRQ-1:0]   irq_src,
  output wire [N_IRQ-1:0]   irq,
  output wire               irq_pending
);

`ifdef FPGA_SYN
  wire fpga_clk;
  BUFG bufg_mem (.O(fpga_clk), .I(clk));
`endif

  reg [N_IRQ-1:0] irq_reg;
  reg pending_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      irq_reg     <= '0;
      pending_reg <= 1'b0;
    end else begin
      irq_reg     <= irq_src;
      pending_reg <= |irq_src;
    end
  end

  assign irq         = irq_reg;
  assign irq_pending = pending_reg;

`ifndef FPGA_SYN

`else
  wire [31:0] debug_irq;
  ila_platform debug_ila (.clk(clk), .probe0(irq), .probe1(irq_src));
`endif

endmodule
"""

    run_int_old = """\
// run_int.sv -- OLD: cpu + spi only, NO UART array

module run_int (
  input  wire        clk,
  input  wire        rst_n,
  output wire [31:0] irq
);

`ifdef FPGA_SYN
  wire run_clk_buf;
  BUFG bufg_run_int (.O(run_clk_buf), .I(clk));
`endif

  wire [31:0] cpu_instr_addr, cpu_instr_data;
  wire        cpu_fetch_en, cpu_stall_req, cpu_stall_ack;

  wire [7:0]  spi_tx_data, spi_rx_data;
  wire        spi_start, spi_done, spi_miso, spi_mosi, spi_sclk, spi_cs_n;
  wire        spi_cpol, spi_cpha;

  cpu_core #(
    .DATA_WIDTH (32),
    .ADDR_WIDTH (32)
  ) u_cpu (
    .clk        (clk),
    .rst_n      (rst_n),
    .fetch_en   (cpu_fetch_en),
    .instr_addr (cpu_instr_addr),
    .instr_data (cpu_instr_data),
    .stall_req  (cpu_stall_req),
    .stall_ack  (cpu_stall_ack),
    .*
  );

  spi_ctrl #(
    .DATA_WIDTH (8),
    .CLK_DIV    (4)
  ) u_spi (
    .clk      (clk),
    .rst_n    (rst_n),
    .start    (spi_start),
    .tx_data  (spi_tx_data),
    .rx_data  (spi_rx_data),
    .done     (spi_done),
    .miso     (spi_miso),
    .mosi     (spi_mosi),
    .sclk     (spi_sclk),
    .cs_n     (spi_cs_n),
    .cpol     (spi_cpol),
    .cpha     (spi_cpha),
    .*
  );

  assign irq = {30'b0, cpu_stall_ack, spi_done};
  assign cpu_fetch_en = 1'b1;
  assign cpu_instr_addr = 32'h0000_1000;
  assign cpu_stall_req = 1'b0;
  assign spi_start = 1'b0;
  assign spi_tx_data = 8'h00;
  assign spi_miso = 1'b0;
  assign spi_cpol = 1'b0;
  assign spi_cpha = 1'b0;

`ifdef FPGA_SYN
  wire [31:0] debug_run_irq;
  ila_run_int debug_ila (.clk(clk), .probe0(irq));
`endif

endmodule
"""

    standby_int_old = """\
// standby_int.sv -- OLD: uart + gpio only, NO timer/i2c

module standby_int (
  input  wire        clk,
  input  wire        rst_n,
  output wire [31:0] irq,
  input  wire        uart_rx,
  output wire        uart_tx,
  input  wire [15:0] gpio_in,
  output wire [15:0] gpio_out,
  output wire [15:0] gpio_oe
);

`ifdef FPGA_SYN
  wire standby_clk_buf;
  BUFG bufg_standby (.O(standby_clk_buf), .I(clk));
`endif

  wire [7:0]  uart_tx_data, uart_rx_data;
  wire        uart_tx_valid, uart_tx_ready, uart_rx_valid;

  uart_top #(
    .CLK_FREQ  (50_000_000),
    .BAUD_RATE (115200)
  ) u_uart (
    .clk      (clk),
    .rst_n    (rst_n),
    .rx       (uart_rx),
    .tx       (uart_tx),
    .tx_data  (uart_tx_data),
    .tx_valid (uart_tx_valid),
    .tx_ready (uart_tx_ready),
    .rx_data  (uart_rx_data),
    .rx_valid (uart_rx_valid),
    .cts      (1'b0),
    .rts      (),
    .*
  );

  gpio #(.N_PINS(16)) u_gpio (
    .clk      (clk),
    .rst_n    (rst_n),
    .gpio_in  (gpio_in),
    .gpio_out (gpio_out),
    .gpio_oe  (gpio_oe),
    .*
  );

  assign irq = {30'b0, uart_rx_valid, |gpio_in};

`ifdef FPGA_SYN
  wire [31:0] debug_standby_irq;
  ila_standby debug_ila (.clk(clk), .probe0(irq), .probe1(gpio_in));
`endif

endmodule
"""

    timer_old = """\
// timer.sv -- OLD: different default width, no FPGA blocks

module timer #(
  parameter TIMER_WIDTH = 16
) (
  input  wire                     clk,
  input  wire                     rst_n,
  input  wire                     start,
  input  wire [TIMER_WIDTH-1:0]   load_val,
  output wire [TIMER_WIDTH-1:0]   count,
  output wire                     expired
);

  reg [TIMER_WIDTH-1:0] count_reg;
  reg                   running;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count_reg <= '0;
      running   <= 1'b0;
    end else begin
      if (start && !running) begin
        count_reg <= load_val;
        running   <= 1'b1;
      end else if (running) begin
        if (count_reg > 0)
          count_reg <= count_reg - 1'b1;
        else
          running <= 1'b0;
      end
    end
  end

  assign count   = count_reg;
  assign expired = running && (count_reg == 0);

endmodule
"""

    i2c_ctrl_old = """\
// i2c_ctrl.sv -- OLD: different CLK_FREQ default, no FPGA blocks

module i2c_ctrl #(
  parameter CLK_FREQ   = 100_000_000,
  parameter I2C_FREQ   = 100_000
) (
  input  wire         clk,
  input  wire         rst_n,
  input  wire         start,
  input  wire [6:0]   dev_addr,
  input  wire         rw,
  input  wire [7:0]   tx_data,
  output wire [7:0]   rx_data,
  output wire         done,
  output wire         busy,
  output wire         scl,
  inout  wire         sda
);

  localparam DIV = CLK_FREQ / (4 * I2C_FREQ);
  reg [15:0] div_cnt;
  reg        scl_reg;
  reg        sda_out;
  reg        sda_oe;
  reg        busy_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      div_cnt  <= '0;
      scl_reg  <= 1'b1;
      sda_out  <= 1'b1;
      sda_oe   <= 1'b0;
      busy_reg <= 1'b0;
    end else begin
      if (start && !busy_reg) begin
        busy_reg <= 1'b1;
        div_cnt  <= '0;
      end else if (busy_reg) begin
        if (div_cnt == DIV - 1) begin
          div_cnt <= '0;
          scl_reg <= ~scl_reg;
        end else begin
          div_cnt <= div_cnt + 1'b1;
        end
      end
    end
  end

  assign scl     = scl_reg;
  assign sda     = sda_oe ? sda_out : 1'bz;
  assign busy    = busy_reg;
  assign done    = busy_reg && (div_cnt == DIV - 1) && scl_reg;
  assign rx_data = 8'h00;

endmodule
"""

    run_top_old = """\
// run_top.sv -- OLD: no memory/UART ports exposed

module run_top (
  input  wire        clk,
  input  wire        rst_n,
  output wire [31:0] irq,
  output wire [31:0] platform_irq
);

  wire        iomux_clk;
  wire        cgm_clk_out;
  wire [31:0] run_irq_out;
  wire [31:0] platform_irq_src;

`ifdef FPGA_SYN
  wire run_clk_buf;
  BUFG bufg_run (.O(run_clk_buf), .I(clk));
`endif

  iomux_pd1 u_iomux (
    .clk   (clk),
    .rst_n (rst_n),
    .*
  );

  platform_int u_platform_int (
    .clk        (clk),
    .rst_n      (rst_n),
    .irq_src    (platform_irq_src),
    .irq        (platform_irq),
    .*
  );

  run_int u_run_int (
    .clk   (clk),
    .rst_n (rst_n),
    .irq   (run_irq_out),
    .*
  );

  cgm_pd1 u_cgm (
    .clk_in   (clk),
    .clk_out  (cgm_clk_out),
    .rst_n    (rst_n),
    .*
  );

  assign irq = run_irq_out;
  assign platform_irq_src = run_irq_out;

`ifdef FPGA_SYN
  wire [31:0] debug_irq_run;
  ila_run_top debug_ila (.clk(clk), .probe0(run_irq_out), .probe1(platform_irq));
`endif

endmodule
"""

    standby_top_old = """\
// standby_top.sv -- OLD: no timer/i2c ports exposed

module standby_top (
  input  wire        clk,
  input  wire        rst_n,
  output wire [31:0] irq,
  input  wire        uart_rx,
  output wire        uart_tx
);

  wire        iomux_clk;
  wire        cgm_clk_out;
  wire [15:0] gpio_in, gpio_out, gpio_oe;

`ifdef FPGA_SYN
  wire stby_clk_buf;
  BUFG bufg_stby_top (.O(stby_clk_buf), .I(clk));
`endif

  iomux_pd0 u_iomux (
    .clk   (clk),
    .rst_n (rst_n),
    .*
  );

  cgm_pd0 u_cgm (
    .clk_in   (clk),
    .clk_out  (cgm_clk_out),
    .rst_n    (rst_n),
    .*
  );

  standby_int u_standby_int (
    .clk      (cgm_clk_out),
    .rst_n    (rst_n),
    .irq      (irq),
    .uart_rx  (uart_rx),
    .uart_tx  (uart_tx),
    .gpio_in  (gpio_in),
    .gpio_out (gpio_out),
    .gpio_oe  (gpio_oe),
    .*
  );

endmodule
"""

    files = {
        HERE / "test_soc/design/chip_top/fpga_v/chip_top.sv":                    chip_top_old,
        HERE / "test_soc/design/run_int/cpu_core/fpga_v/cpu_core.sv":            cpu_old,
        HERE / "test_soc/design/standby_int/uart/fpga_v/uart_top.sv":            uart_old,
        HERE / "test_soc/design/run_int/spi_controller/fpga_v/spi_ctrl.sv":      spi_old,
        # NEW modules
        HERE / "test_soc/design/platform_int/fpga_v/platform_int.sv":            platform_int_old,
        HERE / "test_soc/design/run_int/fpga_v/run_int.sv":                      run_int_old,
        HERE / "test_soc/design/standby_int/fpga_v/standby_int.sv":              standby_int_old,
        HERE / "test_soc/design/standby_int/timer/fpga_v/timer.sv":              timer_old,
        HERE / "test_soc/design/standby_int/i2c_ctrl/fpga_v/i2c_ctrl.sv":        i2c_ctrl_old,
        HERE / "test_soc/design/run_top/fpga_v/run_top.sv":                      run_top_old,
        HERE / "test_soc/design/standby_top/fpga_v/standby_top.sv":              standby_top_old,
    }
    for path, content in files.items():
        _write(path, content)
        print(f"  [OK] {path.parent.parent.name}/{path.parent.name}/{path.name}  ->  OLD version")


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
        rel = f.relative_to(HERE / "test_soc" / "design")
        print(f"    {rel}")
    print(f"  Stub pairs: {len(stub_pairs)}")
    for s, r in stub_pairs:
        print(f"    {s.name:25s}  <-  {r.name}")
    print(f"  Memory wrappers: {len(memory_wrappers)}")
    for w in memory_wrappers:
        print(f"    {w.name}")

    # ---- Step 2: Confirm OLD state ----
    banner("STEP 2: Confirm fpga_v files are OLD (before sync)")

    chip_top_fpga   = HERE / "test_soc/design/chip_top/fpga_v/chip_top.sv"
    cpu_fpga        = HERE / "test_soc/design/run_int/cpu_core/fpga_v/cpu_core.sv"
    uart_fpga       = HERE / "test_soc/design/standby_int/uart/fpga_v/uart_top.sv"
    spi_fpga        = HERE / "test_soc/design/run_int/spi_controller/fpga_v/spi_ctrl.sv"
    platform_int_fpga = HERE / "test_soc/design/platform_int/fpga_v/platform_int.sv"
    run_int_fpga     = HERE / "test_soc/design/run_int/fpga_v/run_int.sv"
    standby_int_fpga = HERE / "test_soc/design/standby_int/fpga_v/standby_int.sv"
    timer_fpga       = HERE / "test_soc/design/standby_int/timer/fpga_v/timer.sv"
    i2c_fpga         = HERE / "test_soc/design/standby_int/i2c_ctrl/fpga_v/i2c_ctrl.sv"
    run_top_fpga     = HERE / "test_soc/design/run_top/fpga_v/run_top.sv"
    standby_top_fpga = HERE / "test_soc/design/standby_top/fpga_v/standby_top.sv"

    # Original checks
    txt = _read(chip_top_fpga)
    check("ext_wakeup" not in txt, "chip_top: no ext_wakeup port (OLD)")
    check("SOC_ID" not in txt,         "chip_top: no SOC_ID param (OLD)")

    txt = _read(cpu_fpga)
    check("stall_req" not in txt, "cpu_core: no stall_req (OLD)")

    txt = _read(uart_fpga)
    check("cts" not in txt.split(");")[0], "uart:     no cts/rts (OLD)")

    txt = _read(spi_fpga)
    check("cpol" not in txt.split(");")[0], "spi_ctrl: no cpol/cpha (OLD)")

    # NEW: platform_int OLD checks -- no memory wrappers
    txt = _read(platform_int_fpga)
    check("sram_256x32_wrap" not in txt, "platform_int: no sram wrapper (OLD)")
    check("rom_1024x16_wrap" not in txt, "platform_int: no rom wrapper (OLD)")
    check("cppe_flexcan_dma_pse_wrap" not in txt, "platform_int: no dma wrapper (OLD)")
    check("BUFG" in txt and "ila_platform" in txt, "platform_int: FPGA blocks (BUFG, ila_platform) present (OLD)")

    # NEW: run_int OLD checks -- no UART array, single SPI
    txt = _read(run_int_fpga)
    check("N_UART" not in txt,          "run_int: no N_UART param (OLD)")
    check("uart_gen" not in txt,        "run_int: no uart generate loop (OLD)")
    check("uart_rx" not in txt,         "run_int: no uart_rx port (OLD)")
    check("spi0_mosi" not in txt,       "run_int: no spi0_mosi port (OLD)")
    check("spi1_mosi" not in txt,       "run_int: no spi1_mosi port (OLD)")
    check("spi2_mosi" not in txt,       "run_int: no spi2_mosi port (OLD)")
    check("BUFG" in txt and "ila_run_int" in txt, "run_int: FPGA blocks (BUFG, ila_run_int) present (OLD)")

    # NEW: standby_int OLD checks -- no timer/i2c
    txt = _read(standby_int_fpga)
    check("timer_start" not in txt and "timer_expired" not in txt,
          "standby_int: no timer ports (OLD)")
    check("i2c_scl" not in txt,          "standby_int: no i2c ports (OLD)")
    check("BUFG" in txt and "ila_standby" in txt, "standby_int: FPGA blocks (BUFG, ila_standby) present (OLD)")

    # NEW: timer OLD checks -- different default width, no FPGA blocks
    txt = _read(timer_fpga)
    check("TIMER_WIDTH = 16" in txt,    "timer: TIMER_WIDTH=16 default (OLD)")
    check("FPGA_SYN" not in txt,        "timer: no FPGA_SYN block (OLD)")

    # NEW: i2c OLD checks -- different CLK_FREQ, no FPGA blocks
    txt = _read(i2c_fpga)
    check("CLK_FREQ   = 100_000_000" in txt, "i2c_ctrl: CLK_FREQ=100MHz default (OLD)")
    check("FPGA_SYN" not in txt,             "i2c_ctrl: no FPGA_SYN block (OLD)")

    # NEW: run_top OLD checks -- no memory/UART ports
    txt = _read(run_top_fpga)
    check("sram_addr" not in txt,        "run_top: no sram_addr port (OLD)")
    check("uart_rx" not in txt,          "run_top: no uart_rx port (OLD)")
    check("BUFG" in txt and "ila_run_top" in txt, "run_top: FPGA blocks (BUFG, ila_run_top) present (OLD)")

    # NEW: standby_top OLD checks -- no timer/i2c ports
    txt = _read(standby_top_fpga)
    check("timer_start" not in txt,      "standby_top: no timer_start port (OLD)")
    check("i2c_scl" not in txt,          "standby_top: no i2c_scl port (OLD)")
    check("BUFG" in txt,                 "standby_top: FPGA block (BUFG) present (OLD)")

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
        w = ""
        if r.fpga_block_warnings:
            w = f"  [WARN blocks: {r.fpga_block_warnings}]  MANUAL REVIEW: {fpga.resolve()}"
        rel = fpga.relative_to(HERE / "test_soc" / "design")
        print(f"  {tag:12s}  {rel}{w}")

    mod_count = sum(1 for r in results if not r.is_equal)
    print(f"\n  Files modified: {mod_count}")

    # ---- Step 4: Verify AFTER sync ----
    banner("STEP 4: Verify AFTER sync")

    # --- Original checks ---
    txt = _read(chip_top_fpga)
    check("ext_wakeup" in txt and "wakeup_ack" in txt,
          "chip_top: ext_wakeup + wakeup_ack added from RTL")
    check("SOC_ID" in txt,
          "chip_top: SOC_ID parameter added from RTL")
    check("BUFG" in txt and "ila_top" in txt,
          "chip_top: FPGA blocks (BUFG, ila_top) preserved")
    check("wakeup_ack_reg" in txt,
          "chip_top: wakeup logic block added from RTL")

    # cpu_core
    txt = _read(cpu_fpga)
    check("stall_req" in txt and "stall_ack" in txt,
          "cpu_core: stall_req + stall_ack added from RTL")
    check("BUFGCE" in txt and "ila_core" in txt,
          "cpu_core: FPGA blocks (BUFGCE, ila_core) preserved")
    check("!stall_req" in txt,
          "cpu_core: always block uses stall condition")

    # uart
    txt = _read(uart_fpga)
    check("cts" in txt and "rts" in txt,
          "uart:     cts/rts added from RTL")
    check("PLLE2" in txt,
          "uart:     FPGA block (PLLE2) preserved")

    # spi_ctrl
    txt = _read(spi_fpga)
    check("cpol" in txt and "cpha" in txt,
          "spi_ctrl: cpol/cpha added from RTL")
    check("ODDR" in txt,
          "spi_ctrl: FPGA block (ODDR) preserved")

    # --- NEW checks: platform_int ---
    txt = _read(platform_int_fpga)
    check("sram_256x32_wrap" in txt and "u_sram" in txt,
          "platform_int: sram wrapper added from RTL")
    check("rom_1024x16_wrap" in txt and "u_rom" in txt,
          "platform_int: rom wrapper added from RTL")
    check("cppe_flexcan_dma_pse_wrap" in txt and "u_dma_buf" in txt,
          "platform_int: dma buffer wrapper added from RTL")
    check("BUFG" in txt and "ila_platform" in txt,
          "platform_int: FPGA blocks (BUFG, ila_platform) preserved")

    # --- NEW checks: run_int ---
    txt = _read(run_int_fpga)
    check("N_UART" in txt and "uart_gen" in txt,
          "run_int: N_UART param + generate loop added from RTL")
    check("uart_rx" in txt and "uart_tx" in txt,
          "run_int: UART array ports added from RTL")
    check("spi0_mosi" in txt and "spi0_sclk" in txt,
          "run_int: spi0 ports added from RTL")
    check("spi1_mosi" in txt and "spi1_sclk" in txt,
          "run_int: spi1 ports added from RTL")
    check("spi2_mosi" in txt and "spi2_sclk" in txt,
          "run_int: spi2 ports added from RTL")
    check("BUFG" in txt and "ila_run_int" in txt,
          "run_int: FPGA blocks (BUFG, ila_run_int) preserved")

    # --- NEW checks: standby_int ---
    txt = _read(standby_int_fpga)
    check("timer_start" in txt and "timer_load" in txt and "timer_expired" in txt,
          "standby_int: timer ports added from RTL")
    check("i2c_scl" in txt and "i2c_sda" in txt,
          "standby_int: i2c ports added from RTL")
    check("BUFG" in txt and "ila_standby" in txt,
          "standby_int: FPGA blocks (BUFG, ila_standby) preserved")

    # --- NEW checks: timer ---
    txt = _read(timer_fpga)
    check("TIMER_WIDTH = 32" in txt,    "timer: TIMER_WIDTH updated to 32 from RTL")
    # timer RTL has no FPGA_SYN blocks, so fpga_v shouldn't either after sync
    check("ila_timer" not in txt and "PLLE2" not in txt,
          "timer: no spurious FPGA blocks added")

    # --- NEW checks: i2c ---
    txt = _read(i2c_fpga)
    check("CLK_FREQ   = 50_000_000" in txt, "i2c_ctrl: CLK_FREQ updated to 50MHz from RTL")
    # OLD i2c had no FPGA blocks, RTL has none -> after sync no PLLE2 expected
    check("PLLE2" not in txt,               "i2c_ctrl: no spurious PLLE2 (neither OLD nor RTL has it)")
    check("endmodule" in txt,               "i2c_ctrl: complete module")

    # --- NEW checks: run_top ---
    txt = _read(run_top_fpga)
    check("sram_addr" in txt and "sram_dout" in txt,
          "run_top: memory ports added from RTL")
    check("uart_rx" in txt and "uart_tx" in txt and "uart_tx_data" in txt,
          "run_top: UART array ports added from RTL")
    check("BUFG" in txt and "ila_run_top" in txt,
          "run_top: FPGA blocks (BUFG, ila_run_top) preserved")

    # --- NEW checks: standby_top ---
    txt = _read(standby_top_fpga)
    check("timer_start" in txt and "timer_load" in txt and "timer_expired" in txt,
          "standby_top: timer ports added from RTL")
    check("i2c_scl" in txt and "i2c_sda" in txt,
          "standby_top: i2c ports added from RTL")
    check("BUFG" in txt,
          "standby_top: FPGA block (BUFG) preserved")

    # ---- Step 5: Memory ----
    banner("STEP 5: Generate FPGA memory wrappers (mbist_wrap/fpga_v)")
    from fpga_core.memory import generate_fpga_wrapper

    mbist_fpga = HERE / "test_soc/design/mbist_wrap/fpga_v"
    if mbist_fpga.exists():
        import shutil
        shutil.rmtree(mbist_fpga)
    mbist_fpga.mkdir(parents=True)

    for w in memory_wrappers:
        out = generate_fpga_wrapper(w, mbist_fpga)
        if out:
            print(f"  [OK] {out.name}")
            c = _read(out)
            check("fpga_spram" in c, f"    {out.name}: contains fpga_spram")
            check("MEMDEPTH" in c and "MEMWIDTH" in c,
                  f"    {out.name}: has MEMDEPTH+MEMWIDTH params")
            # Verify the wrapper is a complete module
            check("endmodule" in c, f"    {out.name}: is a complete module")

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

    # ---- Step 6.5: List hierarchy IPs ----
    banner("STEP 6.5: List hierarchy IPs")
    ips = scanner.list_hierarchy_ips()
    for mod_name in ["standby_top", "run_top", "standby_int", "run_int"]:
        entries = ips.get(mod_name, [])
        print(f"  [{mod_name}]  {len(entries)} IP(s)")
        for ip_mod, ip_inst, _src in entries:
            print(f"    {ip_mod:20s}  {ip_inst}")

    expected_ips = {
        "standby_top": ["iomux_pd0", "cgm_pd0", "standby_int"],
        "run_top":     ["iomux_pd1", "platform_int", "run_int", "cgm_pd1"],
        "standby_int": ["uart_top", "gpio", "timer", "i2c_ctrl"],
        "run_int":     ["cpu_core", "spi_ctrl", "uart_top"],
    }
    all_ok = True
    for mod_name in expected_ips:
        entries = ips.get(mod_name, [])
        found_mods = {m for m, _, _ in entries}
        expected = set(expected_ips[mod_name])
        if found_mods != expected:
            fail(f"  {mod_name}: expected {expected}, got {found_mods}")
            all_ok = False
    if all_ok:
        ok("list-ips: all hierarchy IPs matched")

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
    {mbist_fpga}/
    {report_dir}/all.html

  Report: {report_dir / 'all.html'}
""")


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

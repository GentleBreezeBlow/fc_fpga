//===========================================================================
// standby_top.sv — Standby Domain Top
//===========================================================================
module standby_top (
  input  wire        clk,
  input  wire        rst_n,
  output wire [31:0] irq,
  input  wire        uart_rx,
  output wire        uart_tx,

  // ---- GPIO ----
  input  wire [15:0] gpio_in,
  output wire [15:0] gpio_out,
  output wire [15:0] gpio_oe,

  // ---- Timer ----
  input  wire        timer_start,
  input  wire [31:0] timer_load,
  output wire [31:0] timer_count,
  output wire        timer_expired,

  // ---- I2C ----
  input  wire         i2c_start,
  input  wire [6:0]   i2c_dev_addr,
  input  wire         i2c_rw,
  input  wire [7:0]   i2c_tx_data,
  output wire [7:0]   i2c_rx_data,
  output wire         i2c_done,
  output wire         i2c_busy,
  output wire         i2c_scl,
  inout  wire         i2c_sda
);

  //===========================================================
  // Internal wires
  //===========================================================
  wire        iomux_clk;
  wire        cgm_clk_out;
  wire [15:0] gpio_in, gpio_out, gpio_oe;

  //===========================================================
  // Sub-module instantiations
  //===========================================================

  // IO Mux for power domain 0
  iomux_pd0 u_iomux (
    .clk   (clk),
    .rst_n (rst_n),
    .*
  );

  // Clock generator for power domain 0
  cgm_pd0 u_cgm (
    .clk_in   (clk),
    .clk_out  (cgm_clk_out),
    .rst_n    (rst_n),
    .*
  );

`ifdef FPGA_SYN
  wire stby_clk_buf;
  BUFG bufg_stby_top (.O(stby_clk_buf), .I(clk));
`endif
  // Standby interrupt controller + peripherals
  standby_int u_standby_int (
    .clk          (cgm_clk_out),
    .rst_n        (rst_n),
    .irq          (irq),
    .uart_rx      (uart_rx),
    .uart_tx      (uart_tx),
    .gpio_in      (gpio_in),
    .gpio_out     (gpio_out),
    .gpio_oe      (gpio_oe),
    .timer_start  (timer_start),
    .timer_load   (timer_load),
    .timer_count  (timer_count),
    .timer_expired(timer_expired),
    .i2c_start    (i2c_start),
    .i2c_dev_addr (i2c_dev_addr),
    .i2c_rw       (i2c_rw),
    .i2c_tx_data  (i2c_tx_data),
    .i2c_rx_data  (i2c_rx_data),
    .i2c_done     (i2c_done),
    .i2c_busy     (i2c_busy),
    .i2c_scl      (i2c_scl),
    .i2c_sda      (i2c_sda),
    .*
  );

endmodule

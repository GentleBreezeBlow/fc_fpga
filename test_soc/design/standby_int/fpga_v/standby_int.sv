//===========================================================================
// standby_int.sv — Standby Interrupt Controller + Multiple Peripherals
//===========================================================================
module standby_int (
  input  wire        clk,
  input  wire        rst_n,
  output wire [31:0] irq,

  // ---- UART ----
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
  // Internal signals
  //===========================================================
  wire [7:0]  uart_tx_data, uart_rx_data;
  wire        uart_tx_valid, uart_tx_ready, uart_rx_valid;

  //===========================================================
  // UART — always-on peripheral in standby domain
`ifdef FPGA_SYN
  wire standby_clk_buf;
  BUFG bufg_standby (.O(standby_clk_buf), .I(clk));
`endif
  //===========================================================
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
    .cts      (1'b0),      // No flow control in standby
    .rts      (),          // Not connected at this level
    .*
  );

  //===========================================================
  // GPIO — wakeup-capable pins
  //===========================================================
  gpio #(.N_PINS(16)) u_gpio (
    .clk      (clk),
    .rst_n    (rst_n),
    .gpio_in  (gpio_in),
    .gpio_out (gpio_out),
    .gpio_oe  (gpio_oe),
    .*
  );

  //===========================================================
  // Timer — general-purpose countdown
  //===========================================================
  timer #(.TIMER_WIDTH(32)) u_timer (
    .clk      (clk),
    .rst_n    (rst_n),
    .start    (timer_start),
    .load_val (timer_load),
    .count    (timer_count),
    .expired  (timer_expired),
    .*
  );

  //===========================================================
  // I2C Controller — low-speed peripheral bus
  //===========================================================
  i2c_ctrl #(
    .CLK_FREQ (50_000_000),
    .I2C_FREQ (100_000)
  ) u_i2c (
    .clk      (clk),
    .rst_n    (rst_n),
    .start    (i2c_start),
    .dev_addr (i2c_dev_addr),
    .rw       (i2c_rw),
    .tx_data  (i2c_tx_data),
    .rx_data  (i2c_rx_data),
    .done     (i2c_done),
    .busy     (i2c_busy),
    .scl      (i2c_scl),
    .sda      (i2c_sda),
    .*
  );

  // Simple IRQ aggregation
  assign irq = {28'b0, timer_expired, i2c_done, uart_rx_valid, |gpio_in};

  // UART tie-offs (controlled externally via pad ring)
  assign uart_tx_data  = 8'h00;
  assign uart_tx_valid = 1'b0;
`ifdef FPGA_SYN
  wire [31:0] debug_standby_irq;
  ila_standby debug_ila (.clk(clk), .probe0(irq), .probe1(gpio_in));
`endif

endmodule

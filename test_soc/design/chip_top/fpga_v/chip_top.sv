//===========================================================================
// chip_top.sv — SoC Top Level (RTL Reference / ground truth)
//===========================================================================
module chip_top #(
  parameter SOC_ID = 32'h0001,      // NEW: SOC ID parameter for version tracking
  parameter N_UART = 12
) (
  input  wire        sys_clk,
  input  wire        sys_rst_n,
  input  wire        jtag_tck,
  input  wire        jtag_tms,
  input  wire        jtag_tdi,
  output wire        jtag_tdo,
  // NEW: external wakeup handshake
  input  wire        ext_wakeup,
  output wire        wakeup_ack,

  // ---- Standby UART (single) ----
  input  wire        uart_rx,
  output wire        uart_tx,

  // ---- Standby GPIO ----
  input  wire [15:0] gpio_in,
  output wire [15:0] gpio_out,
  output wire [15:0] gpio_oe,

  // ---- Standby Timer ----
  input  wire        timer_start,
  input  wire [31:0] timer_load,
  output wire [31:0] timer_count,
  output wire        timer_expired,

  // ---- Standby I2C ----
  input  wire         i2c_start,
  input  wire [6:0]   i2c_dev_addr,
  input  wire         i2c_rw,
  input  wire [7:0]   i2c_tx_data,
  output wire [7:0]   i2c_rx_data,
  output wire         i2c_done,
  output wire         i2c_busy,
  output wire         i2c_scl,
  inout  wire         i2c_sda,

  // ---- Memory interfaces (from platform_int via run_top) ----
  input  wire [7:0]         sram_addr,
  input  wire [31:0]        sram_din,
  output wire [31:0]        sram_dout,
  input  wire               sram_cen,
  input  wire               sram_wen,

  input  wire [9:0]         rom_addr,
  output wire [15:0]        rom_dout,
  input  wire               rom_cen,

  input  wire               dma_clk_0,
  input  wire               dma_cen_0,
  input  wire [6:0]         dma_a_0,
  input  wire [109:0]       dma_d_0,
  input  wire [109:0]       dma_wen_0,
  output wire [109:0]       dma_q_0,
  input  wire               dma_clk_1,
  input  wire               dma_cen_1,
  input  wire [9:0]         dma_a_1,
  input  wire [103:0]       dma_d_1,
  input  wire [103:0]       dma_wen_1,
  output wire [103:0]       dma_q_1,

  // ---- Run-domain UART array ports ----
  input  wire [N_UART-1:0]    run_uart_rx,
  output wire [N_UART-1:0]    run_uart_tx,
  input  wire [N_UART*8-1:0]  run_uart_tx_data,
  input  wire [N_UART-1:0]    run_uart_tx_valid,
  output wire [N_UART-1:0]    run_uart_tx_ready,
  output wire [N_UART*8-1:0]  run_uart_rx_data,
  output wire [N_UART-1:0]    run_uart_rx_valid
);

  //===========================================================
  // Internal connections
  //===========================================================
  wire          standby_clk, run_clk;
  wire          standby_rst_n, run_rst_n;
  wire [31:0]   standby_irq, run_irq;
  wire [31:0]   platform_irq;

  //===========================================================
  // IO Pad
  //===========================================================
  paring u_paring (
    .sys_clk   (sys_clk),
    .sys_rst_n (sys_rst_n),
    .*
  );

  //===========================================================
  // Standby domain
  //===========================================================
  standby_top u_standby (
    .clk          (standby_clk),
    .rst_n        (standby_rst_n),
    .irq          (standby_irq),
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

  //===========================================================
  // Run domain
  //===========================================================
  run_top #(.N_UART(N_UART)) u_run (
    .clk            (run_clk),
    .rst_n          (run_rst_n),
    .irq            (run_irq),
    .platform_irq   (platform_irq),
    // Memory pass-through
    .sram_addr      (sram_addr),
    .sram_din       (sram_din),
    .sram_dout      (sram_dout),
    .sram_cen       (sram_cen),
    .sram_wen       (sram_wen),
    .rom_addr       (rom_addr),
    .rom_dout       (rom_dout),
    .rom_cen        (rom_cen),
    .dma_clk_0      (dma_clk_0),
    .dma_cen_0      (dma_cen_0),
    .dma_a_0        (dma_a_0),
    .dma_d_0        (dma_d_0),
`ifdef FPGA_SYN
  wire fpga_clk;
  BUFG bufg_inst (.O(fpga_clk), .I(sys_clk));
`endif
    .dma_wen_0      (dma_wen_0),
    .dma_q_0        (dma_q_0),
    .dma_clk_1      (dma_clk_1),
    .dma_cen_1      (dma_cen_1),
    .dma_a_1        (dma_a_1),
    .dma_d_1        (dma_d_1),
    .dma_wen_1      (dma_wen_1),
    .dma_q_1        (dma_q_1),
    // UART array pass-through
    .uart_rx        (run_uart_rx),
    .uart_tx        (run_uart_tx),
    .uart_tx_data   (run_uart_tx_data),
    .uart_tx_valid  (run_uart_tx_valid),
    .uart_tx_ready  (run_uart_tx_ready),
    .uart_rx_data   (run_uart_rx_data),
    .uart_rx_valid  (run_uart_rx_valid),
    .*
  );

  //===========================================================
  // Wakeup logic — NEW block
  //===========================================================
  reg wakeup_ack_reg;
  always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
      wakeup_ack_reg <= 1'b0;
    else
      wakeup_ack_reg <= ext_wakeup;      // CHANGED: was 1'b0, now latches ext_wakeup
  end
`ifndef FPGA_SYN
  assign wakeup_ack = wakeup_ack_reg;
`else
  wire debug_mode;
  ila_top debug_ila (.clk(sys_clk), .probe0(standby_irq));
`endif

endmodule

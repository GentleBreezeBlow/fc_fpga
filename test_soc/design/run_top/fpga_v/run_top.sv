//===========================================================================
// run_top.sv — Run Domain Top
//===========================================================================
module run_top #(
  parameter N_UART = 12
) (
  input  wire        clk,
  input  wire        rst_n,
  output wire [31:0] irq,
  output wire [31:0] platform_irq,

  // ---- Memory interfaces (from platform_int) ----
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

  // ---- UART array ports ----
  input  wire [N_UART-1:0]    uart_rx,
  output wire [N_UART-1:0]    uart_tx,
  input  wire [N_UART*8-1:0]  uart_tx_data,
  input  wire [N_UART-1:0]    uart_tx_valid,
  output wire [N_UART-1:0]    uart_tx_ready,
  output wire [N_UART*8-1:0]  uart_rx_data,
  output wire [N_UART-1:0]    uart_rx_valid
);

  //===========================================================
  // Internal wires
  //===========================================================
  wire        iomux_clk;
  wire        cgm_clk_out;
  wire [31:0] run_irq_out;
  wire [31:0] platform_irq_src;

`ifdef FPGA_SYN
  wire run_clk_buf;
  BUFG bufg_run (.O(run_clk_buf), .I(clk));
`endif
  //===========================================================
  // Sub-module instantiations
  //===========================================================

  // IO Mux for power domain 1
  iomux_pd1 u_iomux (
    .clk   (clk),
    .rst_n (rst_n),
    .*
  );

  // Platform interrupt controller + memory subsystem
  platform_int u_platform_int (
    .clk        (clk),
    .rst_n      (rst_n),
    .irq_src    (platform_irq_src),
    .irq        (platform_irq),
    .sram_addr  (sram_addr),
    .sram_din   (sram_din),
    .sram_dout  (sram_dout),
    .sram_cen   (sram_cen),
    .sram_wen   (sram_wen),
    .rom_addr   (rom_addr),
    .rom_dout   (rom_dout),
    .rom_cen    (rom_cen),
    .dma_clk_0  (dma_clk_0),
    .dma_cen_0  (dma_cen_0),
    .dma_a_0    (dma_a_0),
    .dma_d_0    (dma_d_0),
    .dma_wen_0  (dma_wen_0),
    .dma_q_0    (dma_q_0),
    .dma_clk_1  (dma_clk_1),
    .dma_cen_1  (dma_cen_1),
    .dma_a_1    (dma_a_1),
    .dma_d_1    (dma_d_1),
    .dma_wen_1  (dma_wen_1),
    .dma_q_1    (dma_q_1),
    .*
  );

  // Run interrupt controller + peripherals
  run_int #(.N_UART(N_UART)) u_run_int (
    .clk          (clk),
    .rst_n        (rst_n),
    .irq          (run_irq_out),
    .uart_rx      (uart_rx),
    .uart_tx      (uart_tx),
    .uart_tx_data (uart_tx_data),
    .uart_tx_valid(uart_tx_valid),
    .uart_tx_ready(uart_tx_ready),
    .uart_rx_data (uart_rx_data),
    .uart_rx_valid(uart_rx_valid),
    .*
  );

  // Clock generator for power domain 1
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

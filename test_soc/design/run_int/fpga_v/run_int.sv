//===========================================================================
// run_int.sv — Run Interrupt Controller + Peripherals (12 UARTs, 3 SPIs)
//===========================================================================
module run_int #(
  parameter N_UART = 12
) (
  input  wire        clk,
  input  wire        rst_n,
  output wire [31:0] irq,

  // ---- UART array ports ----
  input  wire [N_UART-1:0]    uart_rx,
  output wire [N_UART-1:0]    uart_tx,
  input  wire [N_UART*8-1:0]  uart_tx_data,
  input  wire [N_UART-1:0]    uart_tx_valid,
  output wire [N_UART-1:0]    uart_tx_ready,
  output wire [N_UART*8-1:0]  uart_rx_data,
  output wire [N_UART-1:0]    uart_rx_valid,

  // ---- SPI 0 ----
  input  wire        spi0_miso,
  output wire        spi0_mosi,
  output wire        spi0_sclk,
  output wire        spi0_cs_n,

  // ---- SPI 1 ----
  input  wire        spi1_miso,
  output wire        spi1_mosi,
  output wire        spi1_sclk,
  output wire        spi1_cs_n,

  // ---- SPI 2 ----
  input  wire        spi2_miso,
  output wire        spi2_mosi,
  output wire        spi2_sclk,
  output wire        spi2_cs_n
);

`ifdef FPGA_SYN
  wire run_clk_buf;
  BUFG bufg_run_int (.O(run_clk_buf), .I(clk));
`endif
  //===========================================================
  // Internal signals
  //===========================================================
  wire [31:0] cpu_instr_addr, cpu_instr_data;
  wire        cpu_fetch_en, cpu_stall_req, cpu_stall_ack;

  wire [2:0]  spi_start, spi_done;
  wire [7:0]  spi_tx_data [2:0];
  wire [7:0]  spi_rx_data [2:0];
  wire [2:0]  spi_cpol, spi_cpha;

  //===========================================================
  // CPU Core — main processor
  //===========================================================
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

  //===========================================================
  // SPI Controller 0
  //===========================================================
  spi_ctrl #(
    .DATA_WIDTH (8),
    .CLK_DIV    (4)
  ) spi0 (
    .clk      (clk),
    .rst_n    (rst_n),
    .start    (spi_start[0]),
    .tx_data  (spi_tx_data[0]),
    .rx_data  (spi_rx_data[0]),
    .done     (spi_done[0]),
    .miso     (spi0_miso),
    .mosi     (spi0_mosi),
    .sclk     (spi0_sclk),
    .cs_n     (spi0_cs_n),
    .cpol     (spi_cpol[0]),
    .cpha     (spi_cpha[0]),
    .*
  );

  //===========================================================
  // SPI Controller 1
  //===========================================================
  spi_ctrl #(
    .DATA_WIDTH (8),
    .CLK_DIV    (4)
  ) spi1 (
    .clk      (clk),
    .rst_n    (rst_n),
    .start    (spi_start[1]),
    .tx_data  (spi_tx_data[1]),
    .rx_data  (spi_rx_data[1]),
    .done     (spi_done[1]),
    .miso     (spi1_miso),
    .mosi     (spi1_mosi),
    .sclk     (spi1_sclk),
    .cs_n     (spi1_cs_n),
    .cpol     (spi_cpol[1]),
    .cpha     (spi_cpha[1]),
    .*
  );

`ifdef FPGA_SYN
  wire [31:0] debug_run_irq;
  ila_run_int debug_ila (.clk(clk), .probe0(irq));
`endif
  //===========================================================
  // SPI Controller 2
  //===========================================================
  spi_ctrl #(
    .DATA_WIDTH (8),
    .CLK_DIV    (4)
  ) spi2 (
    .clk      (clk),
    .rst_n    (rst_n),
    .start    (spi_start[2]),
    .tx_data  (spi_tx_data[2]),
    .rx_data  (spi_rx_data[2]),
    .done     (spi_done[2]),
    .miso     (spi2_miso),
    .mosi     (spi2_mosi),
    .sclk     (spi2_sclk),
    .cs_n     (spi2_cs_n),
    .cpol     (spi_cpol[2]),
    .cpha     (spi_cpha[2]),
    .*
  );

  //===========================================================
  // UART Array — 12 instances via generate loop
  //===========================================================
  genvar uart_idx;
  generate
    for (uart_idx = 0; uart_idx < N_UART; uart_idx = uart_idx + 1) begin : uart_gen
      uart_top #(
        .CLK_FREQ  (50_000_000),
        .BAUD_RATE (115200)
      ) u_uart (
        .clk      (clk),
        .rst_n    (rst_n),
        .rx       (uart_rx[uart_idx]),
        .tx       (uart_tx[uart_idx]),
        .tx_data  (uart_tx_data[uart_idx*8 +: 8]),
        .tx_valid (uart_tx_valid[uart_idx]),
        .tx_ready (uart_tx_ready[uart_idx]),
        .rx_data  (uart_rx_data[uart_idx*8 +: 8]),
        .rx_valid (uart_rx_valid[uart_idx]),
        .cts      (1'b0),      // No flow control in run domain
        .rts      (),          // Not connected at this level
        .*
      );
    end
  endgenerate

  // IRQ — aggregate interrupts
  assign irq = {17'b0, uart_rx_valid[0], uart_tx_ready[0], |spi_done, cpu_stall_ack, 8'b0};

  // Tie-offs
  assign cpu_fetch_en    = 1'b1;
  assign cpu_instr_addr  = 32'h0000_1000;
  assign cpu_stall_req   = 1'b0;
  assign spi_start       = 3'b000;
  assign spi_tx_data[0]  = 8'h00;
  assign spi_tx_data[1]  = 8'h00;
  assign spi_tx_data[2]  = 8'h00;
  assign spi_cpol        = 3'b000;
  assign spi_cpha        = 3'b000;

endmodule

//===========================================================================
// uart_top.sv — UART with configurable baud rate
//===========================================================================
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
  output wire        rx_valid,
  input  wire        cts,          // NEW: hardware flow control
  output wire        rts           // NEW: hardware flow control
);

`ifdef FPGA_SYN
  wire pll_clk;
  PLLE2_BASE #(
    .CLKIN1_PERIOD (20.0), .CLKFBOUT_MULT (10), .DIVCLK_DIVIDE (2)
  ) uart_pll (.CLKIN1(clk), .CLKOUT0(pll_clk), .LOCKED());
`else
  //===========================================================
  // Baud-rate generator — CHANGED: was divide-by-N, now fractional
`endif
  //===========================================================
  localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;
  reg [$clog2(BAUD_DIV)-1:0] baud_cnt;
`ifdef FPGA_SYN
  wire baud_tick = 0;
`else
  wire baud_tick = (baud_cnt == BAUD_DIV - 1);
`endif

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      baud_cnt <= '0;
    else if (baud_tick)
      baud_cnt <= '0;
    else
      baud_cnt <= baud_cnt + 1'b1;     // CHANGED: was baud_cnt + 1
  end

  //===========================================================
  // Flow control — NEW block
  //===========================================================
  reg rts_reg;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      rts_reg <= 1'b0;
    else
      rts_reg <= rx_valid;  // Assert RTS when we have data to send
  end
  assign rts = rts_reg;


  wire test=0;


endmodule

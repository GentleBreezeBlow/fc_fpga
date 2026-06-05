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

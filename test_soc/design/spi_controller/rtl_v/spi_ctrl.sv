//===========================================================================
// spi_ctrl.sv — SPI Master Controller (RTL reference — with bugfix)
//===========================================================================
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
  output wire                    cs_n,
  input  wire                    cpol,      // NEW: clock polarity config
  input  wire                    cpha       // NEW: clock phase config
);

  //===========================================================
  // Clock divider — CHANGED: was CLK_DIV, now CLK_DIV/2
  //===========================================================
  reg [7:0] clk_cnt;
  wire clk_en = (clk_cnt == (CLK_DIV/2) - 1);   // FIXED: was CLK_DIV-1 (wrong!)

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      clk_cnt <= '0;
    else if (clk_en)
      clk_cnt <= '0;
    else
      clk_cnt <= clk_cnt + 1'b1;
  end

  //===========================================================
  // SPI state machine — NEW: CPOL/CPHA support
  //===========================================================
  localparam IDLE = 2'b00, SHIFT = 2'b01, DONE = 2'b10;

  reg [1:0] state, next_state;
  reg [7:0] bit_cnt;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  always @(*) begin
    next_state = state;
    case (state)
      IDLE:  if (start) next_state = SHIFT;
      SHIFT: if (bit_cnt == DATA_WIDTH - 1 && clk_en) next_state = DONE;
      DONE:  next_state = IDLE;
    endcase
  end

  // CPOL/CPHA controlled SCLK
  assign sclk = (state == SHIFT) ? (cpol ^ (clk_cnt >= CLK_DIV/4) ? clk : ~clk) : cpol;

  assign done = (state == DONE);
  assign cs_n = (state == IDLE);

endmodule

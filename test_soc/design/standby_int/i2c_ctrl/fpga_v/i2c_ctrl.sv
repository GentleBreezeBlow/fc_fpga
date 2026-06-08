//===========================================================================
// i2c_ctrl.sv — I2C Master Controller Stub
//===========================================================================
module i2c_ctrl #(
  parameter CLK_FREQ   = 50_000_000,
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
  assign rx_data = 8'h00;  // Stub

endmodule

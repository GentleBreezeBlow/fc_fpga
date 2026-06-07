//===========================================================================
// cgm_pd1.sv — Clock Generator for Run Power Domain 1
//===========================================================================
module cgm_pd1 #(
  parameter CLK_DIV = 4
) (
  input  wire        clk_in,
  output wire        clk_out,
  input  wire        rst_n
);

  // Simple clock divider for run domain
  reg [$clog2(CLK_DIV)-1:0] div_cnt;
  reg clk_out_reg;

  always @(posedge clk_in or negedge rst_n) begin
    if (!rst_n) begin
      div_cnt     <= '0;
      clk_out_reg <= 1'b0;
    end else if (div_cnt == CLK_DIV - 1) begin
      div_cnt     <= '0;
      clk_out_reg <= ~clk_out_reg;
    end else begin
      div_cnt <= div_cnt + 1'b1;
    end
  end

  assign clk_out = clk_out_reg;

endmodule

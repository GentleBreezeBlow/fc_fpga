//===========================================================================
// iomux_pd1.sv — IO Mux for Run Power Domain 1
//===========================================================================
module iomux_pd1 #(
  parameter N_IO = 64
) (
  input  wire               clk,
  input  wire               rst_n,
  input  wire [N_IO-1:0]    io_in,
  output wire [N_IO-1:0]    io_out,
  output wire [N_IO-1:0]    io_oe
);

  // Simple pass-through mux for run domain
  reg [N_IO-1:0] out_reg, oe_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      out_reg <= '0;
      oe_reg  <= '0;
    end else begin
      out_reg <= io_in;
      oe_reg  <= {N_IO{1'b1}};
    end
  end

  assign io_out = out_reg;
  assign io_oe  = oe_reg;

endmodule

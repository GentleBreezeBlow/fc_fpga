// gpio.sv — simple GPIO, no FPGA-specific code
module gpio #(parameter N_PINS = 16) (
  input  wire           clk,
  input  wire           rst_n,
  input  wire [N_PINS-1:0]  gpio_in,
  output wire [N_PINS-1:0]  gpio_out,
  output wire [N_PINS-1:0]  gpio_oe
);
  reg [N_PINS-1:0] out_reg, oe_reg;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      out_reg <= '0;
      oe_reg  <= '0;
    end else begin
      out_reg <= gpio_in;
      oe_reg  <= {N_PINS{1'b1}};
    end
  end
  assign gpio_out = out_reg;
  assign gpio_oe  = oe_reg;
endmodule

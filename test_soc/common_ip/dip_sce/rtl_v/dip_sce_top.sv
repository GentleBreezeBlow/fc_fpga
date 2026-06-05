// dip_sce_top.sv — security engine top (will be replaced by stub in FPGA)
module dip_sce_top #(
  parameter KEY_WIDTH = 256
) (
  input  wire                  clk,
  input  wire                  rst_n,
  input  wire [KEY_WIDTH-1:0]  key_in,
  output wire                  session_valid,
  output wire [31:0]           status
);
  // Complex ASIC implementation... (not relevant for FPGA)
  assign session_valid = 1'b1;
  assign status = 32'hDEAD_BEEF;
endmodule

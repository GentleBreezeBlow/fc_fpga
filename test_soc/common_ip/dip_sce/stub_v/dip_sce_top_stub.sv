// dip_sce_stub.sv -- stub replacement for FPGA
module dip_sce_top #(
  parameter KEY_WIDTH = 256
) (
  input  wire                  clk,
  input  wire                  rst_n,
  input  wire [KEY_WIDTH-1:0]  key_in,
  output wire                  session_valid,
  output wire [31:0]           status
);
  // Stub: simple pass-through
  assign valid = 1'b1;
endmodule

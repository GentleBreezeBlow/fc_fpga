// dip_sce_stub.sv — stub replacement for FPGA
module dip_sce #(
  parameter HSM_KEY_WIDTH = 256,
  parameter HSM_SEED_WIDTH = 128
) (
  input  wire                    clk,
  input  wire                    rst_n,
  input  wire [HSM_KEY_WIDTH-1:0] key_in,
  output wire                    valid
);
  // Stub: simple pass-through
  assign valid = 1'b1;
endmodule

//===========================================================================
// paring.sv — IO Pad Ring (structural only, no FPGA blocks)
//===========================================================================
module paring #(
  parameter N_PADS = 64
) (
  input  wire        sys_clk,
  input  wire        sys_rst_n,
  input  wire        jtag_tck,
  input  wire        jtag_tms,
  input  wire        jtag_tdi,
  output wire        jtag_tdo,
  // Pad connections (simplified)
  input  wire [N_PADS-1:0] pad_in,
  output wire [N_PADS-1:0] pad_out,
  output wire [N_PADS-1:0] pad_oe
);

  // Simple pad bypass for FPGA testing
  assign pad_out = pad_in;
  assign pad_oe  = {N_PADS{1'b1}};
  assign jtag_tdo = jtag_tdi;  // loopback for simplicity

endmodule

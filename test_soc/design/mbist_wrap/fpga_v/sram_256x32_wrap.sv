// sram_256x32_wrap.sv — memory wrapper for FPGA memory replacement
module sram_256x32_wrap (
  input  wire         CLK_0,
  input  wire [7:0]   A_0,
  input  wire [31:0]  D_0,
  output wire [31:0]  Q_0,
  input  wire         CEN_0,
  input  wire         WEN_0
);
  // Wrapper around vendor SRAM
  TSMC_SRAM #(.DEPTH(256), .WIDTH(32)) u_sram (
    .CLK  (CLK_0),
    .A    (A_0),
    .D    (D_0),
    .Q    (Q_0),
    .CEN  (CEN_0),
    .WEN  (WEN_0)
  );

endmodule

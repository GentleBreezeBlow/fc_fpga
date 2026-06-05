// rom_1024x16_wrap.sv — ROM wrapper (bootloader)
module rom_1024x16_wrap (
  input  wire         CLK_0,
  input  wire [9:0]   A_0,
  output wire [15:0]  Q_0,
  input  wire         CEN_0
);
  TSMC_ROM #(.DEPTH(1024), .WIDTH(16)) u_rom (
    .CLK  (CLK_0),
    .A    (A_0),
    .Q    (Q_0),
    .CEN  (CEN_0)
  );

endmodule

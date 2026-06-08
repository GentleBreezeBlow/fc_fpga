// rom_1024x16_wrap.sv -- FPGA version (auto-generated)
// Source: C:\ai\fpga\test_soc\design\mbist_wrap\rtl_v\rom_1024x16_wrap.sv
// Generator: fpga_core.memory

module rom_1024x16_wrap (
  input  wire         CLK_0,
  input  wire [9:0]   A_0,
  output wire [15:0]  Q_0,
  input  wire         CEN_0
);

  // FPGA memory instantiations

  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (16),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_0(
      .ram_clk  (CLK_0),
      .ram_addr (A_0[9:0]),
      .ram_me   (~CEN_0),
      .ram_we   ({2{1'b0}}),
      .ram_wdata({16{1'b0}}),
      .ram_rdata(Q_0[15:0])
  );

endmodule

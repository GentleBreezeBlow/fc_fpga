// sram_256x32_wrap.sv -- FPGA version (auto-generated)
// Source: C:\ai\fpga\test_soc\design\mbist_wrap\rtl_v\sram_256x32_wrap.sv
// Generator: fpga_core.memory

module sram_256x32_wrap (
  input  wire         CLK_0,
  input  wire [7:0]   A_0,
  input  wire [31:0]  D_0,
  output wire [31:0]  Q_0,
  input  wire         CEN_0,
  input  wire         WEN_0
);

  // FPGA memory instantiations

  fpga_spram #(
      .MEMDEPTH (256),
      .MEMWIDTH (32),
      .BYTEWIDTH(8),
      .ADDRWIDTH(8),
      .MEMTYPE ("block" )
  )
  mem_0(
      .ram_clk  (CLK_0),
      .ram_addr (A_0[7:0]),
      .ram_me   (~CEN_0),
      .ram_we   ({4{~WEN_0}}),
      .ram_wdata(D_0[31:0]),
      .ram_rdata(Q_0[31:0])
  );

endmodule

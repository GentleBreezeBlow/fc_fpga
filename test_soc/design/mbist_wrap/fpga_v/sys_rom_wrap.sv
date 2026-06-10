// sys_rom_wrap.sv -- FPGA version (auto-generated)
// Source: C:\ai\fpga\test_soc\design\mbist_wrap\rtl_v\sys_rom_wrap.sv
// Generator: fpga_core.memory

module sys_rom_wrap (
    input         sys_clock,
    input         sys_reset,
    input         sys_test_init,
    input         sys_test_start,
    input         sys_ctrl_select,
    input         MISR_CLK,
    input         MISR_SHIFT,
    input         MISR_SI,
    output        MISR_SO,
    output        sys_test_pass,
    output        sys_test_done,

    // Port 0
    input         CLK_0,
    input         CEN_0,
    input  [12:0] A_0,
    input         BEN_0,
    input  [2:0]  EMA_0,
    input         PGEN_0,
    input         KEN_0,
    output [71:0] Q_0,

    // Port 1
    input         CLK_1,
    input         CEN_1,
    input  [12:0] A_1,
    input         BEN_1,
    input  [2:0]  EMA_1,
    input         PGEN_1,
    input         KEN_1,
    output [71:0] Q_1,

    // JTAG and test control signals
    input wire    ijtag_tck,
    input wire    ijtag_reset,
    input wire    ijtag_ce,
    input wire    ijtag_se,
    input wire    ijtag_ue,
    input wire    ijtag_sel,
    input wire    ijtag_si,
    output wire   ijtag_so,
    input wire    ltest_en,
    input wire    memory_bypass_en,
    input wire    mcp_bounding_en,
    input wire    scan_en,

    input  wire  GWEN_0,

    input  wire [7:0]  WEN_0,

    input  wire  GWEN_1,

    input  wire [7:0]  WEN_1,

    input  wire [71:0]  D_0,

    input  wire [71:0]  D_1
);

  wire [7:0] ram_we_0 = {8{~GWEN_0}} & ~WEN_0;
  wire [7:0] ram_we_1 = {8{~GWEN_1}} & ~WEN_1;

  // Default assignments (non-memory ports)
  assign MISR_SO = 1'b0;
  assign sys_test_pass = 1'b0;
  assign sys_test_done = 1'b0;
  assign ijtag_so = 1'b0;

  // FPGA memory instantiations

  fpga_spram #(
      .MEMDEPTH (8192),
      .MEMWIDTH (64),
      .BYTEWIDTH(8),
      .ADDRWIDTH(13),
      .MEMTYPE  ("block")
  )
  mem_64_0(
      .ram_clk  (CLK_0),
      .ram_addr (A_0[12:0]),
      .ram_me   (~CEN_0),
      .ram_we   (ram_we_0[7:0]),
      .ram_wdata(D_0[63:0]),
      .ram_rdata(Q_0[63:0])
  );

  genvar i_0;
  generate
  for(i_0=0;i_0<1;i_0=i_0+1)
  begin:gen_upecc_0
  fpga_spram #(
      .MEMDEPTH (8192),
      .MEMWIDTH (8),
      .BYTEWIDTH(8),
      .ADDRWIDTH(13),
      .MEMTYPE  ("block")
  )
  ecc(
      .ram_clk  (CLK_0),
      .ram_addr (A_0[12:0]),
      .ram_me   (~CEN_0),
      .ram_we   (~GWEN_0),
      .ram_wdata(D_0[64+8*i_0+:8]),
      .ram_rdata(Q_0[64+8*i_0+:8])
  );
  end
  endgenerate

  fpga_spram #(
      .MEMDEPTH (8192),
      .MEMWIDTH (64),
      .BYTEWIDTH(8),
      .ADDRWIDTH(13),
      .MEMTYPE  ("block")
  )
  mem_64_1(
      .ram_clk  (CLK_1),
      .ram_addr (A_1[12:0]),
      .ram_me   (~CEN_1),
      .ram_we   (ram_we_1[7:0]),
      .ram_wdata(D_1[63:0]),
      .ram_rdata(Q_1[63:0])
  );

  genvar i_1;
  generate
  for(i_1=0;i_1<1;i_1=i_1+1)
  begin:gen_upecc_1
  fpga_spram #(
      .MEMDEPTH (8192),
      .MEMWIDTH (8),
      .BYTEWIDTH(8),
      .ADDRWIDTH(13),
      .MEMTYPE  ("block")
  )
  ecc(
      .ram_clk  (CLK_1),
      .ram_addr (A_1[12:0]),
      .ram_me   (~CEN_1),
      .ram_we   (~GWEN_1),
      .ram_wdata(D_1[64+8*i_1+:8]),
      .ram_rdata(Q_1[64+8*i_1+:8])
  );
  end
  endgenerate

endmodule

// cppe_flexcan_dma_pse_wrap.sv -- FPGA version (auto-generated)
// Source: C:\ai\fpga\test_soc\design\mbist_wrap\rtl_v\cppe_flexcan_dma_pse_wrap.sv
// Generator: fpga_core.memory

module cppe_flexcan_dma_pse_wrap (
input  sys_clock,
input  sys_reset,
input  sys_test_init,
input  sys_test_start,
input  sys_ctrl_select,
input  [3:0] sys_algo_select,
input  sys_select_common_algo,
input  [1:0] sys_retention_test_phase,
input  sys_preserve_test_inputs,
output sys_test_pass,
output sys_test_done,
input  clk_0,
input  cen_0,
input  gwen_0,
input  [6:0] a_0,
input  [109:0] d_0,
input  [109:0] wen_0,
input  [2:0] ema_0,
input  [1:0] emaw_0,
input  emas_0,
input  rdt_0,
input  wabl_0,
input  [1:0] wablm_0,
input  rawl_0,
input  [1:0] rawlm_0,
input  se_0,
input  [1:0] si_0,
input  dftrambyp_0,
input  ret1n_0,
output [1:0] so_0,
output [109:0] q_0,
input  clk_1,
input  cen_1,
input  gwen_1,
input  [9:0] a_1,
input  [103:0] d_1,
input  [103:0] wen_1,
input  [2:0] ema_1,
input  [1:0] emaw_1,
input  emas_1,
input  rdt_1,
input  wabl_1,
input  [2:0] wablm_1,
input  rawl_1,
input  [1:0] rawlm_1,
input  stov_1,
output [103:0] q_1);

  wire [8:0] ram_we_0 = {9{~gwen_0}} & {&wen_0[108:104], &wen_0[63:56], &wen_0[55:48], &wen_0[47:40], &wen_0[39:32], &wen_0[31:24], &wen_0[23:16], &wen_0[15:8], &wen_0[7:0]};
  wire [7:0] ram_we_1 = {8{~gwen_1}} & {&wen_1[63:56], &wen_1[55:48], &wen_1[47:40], &wen_1[39:32], &wen_1[31:24], &wen_1[23:16], &wen_1[15:8], &wen_1[7:0]};

  // Default assignments (non-memory ports)
  assign sys_test_pass = 1'b0;
  assign sys_test_done = 1'b0;
  assign so_0 = {2{1'b0}};

  // FPGA memory instantiations

  fpga_spram #(
      .MEMDEPTH (128),
      .MEMWIDTH (64),
      .BYTEWIDTH(8),
      .ADDRWIDTH(7),
      .MEMTYPE  ("block")
  )
  mem_64_0(
      .ram_clk  (clk_0),
      .ram_addr (a_0[6:0]),
      .ram_me   (~cen_0),
      .ram_we   (ram_we_0[7:0]),
      .ram_wdata(d_0[63:0]),
      .ram_rdata(q_0[63:0])
  );

  genvar i_0;
  generate
  for(i_0=0;i_0<9;i_0=i_0+1)
  begin:gen_upecc_0
  fpga_spram #(
      .MEMDEPTH (128),
      .MEMWIDTH (5),
      .BYTEWIDTH(5),
      .ADDRWIDTH(7),
      .MEMTYPE  ("block")
  )
  ecc(
      .ram_clk  (clk_0),
      .ram_addr (a_0[6:0]),
      .ram_me   (~cen_0),
      .ram_we   (ram_we_0[i_0]),
      .ram_wdata(d_0[64+5*i_0+:5]),
      .ram_rdata(q_0[64+5*i_0+:5])
  );
  end
  endgenerate

  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (64),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE  ("block")
  )
  mem_64_1(
      .ram_clk  (clk_1),
      .ram_addr (a_1[9:0]),
      .ram_me   (~cen_1),
      .ram_we   (ram_we_1[7:0]),
      .ram_wdata(d_1[63:0]),
      .ram_rdata(q_1[63:0])
  );

  genvar i_1;
  generate
  for(i_1=0;i_1<8;i_1=i_1+1)
  begin:gen_upecc_1
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (5),
      .BYTEWIDTH(5),
      .ADDRWIDTH(10),
      .MEMTYPE  ("block")
  )
  ecc(
      .ram_clk  (clk_1),
      .ram_addr (a_1[9:0]),
      .ram_me   (~cen_1),
      .ram_we   (ram_we_1[i_1]),
      .ram_wdata(d_1[64+5*i_1+:5]),
      .ram_rdata(q_1[64+5*i_1+:5])
  );
  end
  endgenerate

endmodule

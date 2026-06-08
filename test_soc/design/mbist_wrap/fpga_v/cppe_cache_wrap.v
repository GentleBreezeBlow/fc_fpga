// cppe_cache_wrap.v -- FPGA version (auto-generated)
// Source: C:\ai\fpga\test_soc\design\mbist_wrap\rtl_v\cppe_cache_wrap.v
// Generator: fpga_core.memory

module cppe_cache_wrap (
    input         sys_clock,
    input         sys_reset,
    input         sys_test_init,
    input         sys_test_start,
    input         sys_ctrl_select,
    input  [3:0]  sys_algo_select,
    input         sys_select_common_algo,
    input  [1:0]  sys_retention_test_phase,
    input         sys_preserve_test_inputs,
    output        sys_test_pass,
    output        sys_test_done,

    // Port 0
    input         clk_0,
    input         cen_0,
    input         gwen_0,
    input  [7:0]  a_0,
    input  [21:0] d_0,
    input  [21:0] wen_0,
    input  [2:0]  ema_0,
    input  [1:0]  emaw_0,
    input         emas_0,
    input         rdt_0,
    input         wabl_0,
    input  [1:0]  wablm_0,
    input         rawl_0,
    input  [1:0]  rawlm_0,
    input         se_0,
    input  [1:0]  si_0,
    input         dftrambyp_0,
    input         ret1n_0,
    output [1:0]  so_0,
    output [21:0] q_0,

    // Port 1
    input         clk_1,
    input         cen_1,
    input         gwen_1,
    input  [7:0]  a_1,
    input  [21:0] d_1,
    input  [21:0] wen_1,
    input  [2:0]  ema_1,
    input  [1:0]  emaw_1,
    input         emas_1,
    input         rdt_1,
    input         wabl_1,
    input  [1:0]  wablm_1,
    input         rawl_1,
    input  [1:0]  rawlm_1,
    input         se_1,
    input  [1:0]  si_1,
    input         dftrambyp_1,
    input         ret1n_1,
    output [1:0]  so_1,
    output [21:0] q_1,


input         clk_2,
input         cen_2,
input         gwen_2,
input  [7:0]  a_2,
input  [21:0] d_2,
input  [21:0] wen_2,
input  [2:0]  ema_2,
input  [1:0]  emaw_2,
input         emas_2,
input         rdt_2,
input         wabl_2,
input  [1:0]  wablm_2,
input         rawl_2,
input  [1:0]  rawlm_2,
input         se_2,
input  [1:0]  si_2,
input         dftrambyp_2,
input         ret1n_2,
output [1:0]  so_2,
output [21:0] q_2,

input         clk_3,
input         cen_3,
input         gwen_3,
input  [7:0]  a_3,
input  [21:0] d_3,
input  [21:0] wen_3,
input  [2:0]  ema_3,
input  [1:0]  emaw_3,
input         emas_3,
input         rdt_3,
input         wabl_3,
input  [1:0]  wablm_3,
input         rawl_3,
input  [1:0]  rawlm_3,
input         se_3,
input  [1:0]  si_3,
input         dftrambyp_3,
input         ret1n_3,
output [1:0]  so_3,
output [21:0] q_3,

input         clk_4,
input         cen_4,
input         gwen_4,
input  [9:0]  a_4,
input  [35:0] d_4,
input  [35:0] wen_4,
input  [2:0]  ema_4,
input  [1:0]  emaw_4,
input         emas_4,
input         rdt_4,
input         wabl_4,
input  [2:0]  wablm_4,
input         rawl_4,
input  [1:0]  rawlm_4,
input         stov_4,
input         se_4,
input  [1:0]  si_4,
input         dftrambyp_4,
input         ret1n_4,
output [1:0]  so_4,
output [35:0] q_4

);

  // Default assignments (non-memory ports)
  assign sys_test_pass = 1'b0;
  assign sys_test_done = 1'b0;
  assign so_0 = {2{1'b0}};
  assign so_1 = {2{1'b0}};
  assign so_2 = {2{1'b0}};
  assign so_3 = {2{1'b0}};
  assign so_4 = {2{1'b0}};

  // FPGA memory instantiations

  wire [3:0] ram_we_4 = {4{~gwen_4}} & {&wen_4[31:24], &wen_4[23:16], &wen_4[15:8], &wen_4[7:0]};

  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (32),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE  ("block")
  )
  mem_32_4(
      .ram_clk  (clk_4),
      .ram_addr (a_4[9:0]),
      .ram_me   (~cen_4),
      .ram_we   (ram_we_4[3:0]),
      .ram_wdata(d_4[31:0]),
      .ram_rdata(q_4[31:0])
  );

  fpga_mem #(
      .MEMDEPTH (1024),
      .MEMWIDTH (4),
      .NO_WEM   (0)
  )
  ecc_4(
      .CLK      (clk_4),
      .ADR      (a_4[9:0]),
      .WEM      (wen_4[35:32]),
      .WE       (~gwen_4),
      .ME       (~cen_4),
      .D        (d_4[35:32]),
      .Q        (q_4[35:32])
  );

  fpga_spram #(
      .MEMDEPTH (256),
      .MEMWIDTH (24),
      .BYTEWIDTH(8),
      .ADDRWIDTH(8),
      .MEMTYPE ("block" )
  )
  mem_0(
      .ram_clk  (clk_0),
      .ram_addr (a_0[7:0]),
      .ram_me   (~cen_0),
      .ram_we   ({~gwen_0 & ~(&wen_0[21:16]), ~gwen_0 & ~(&wen_0[15:8]), ~gwen_0 & ~(&wen_0[7:0])}),
      .ram_wdata({2{1'b0}, d_0[21:0]}),
      .ram_rdata({2{1'b0}, q_0[21:0]})
  );

  fpga_spram #(
      .MEMDEPTH (256),
      .MEMWIDTH (24),
      .BYTEWIDTH(8),
      .ADDRWIDTH(8),
      .MEMTYPE ("block" )
  )
  mem_1(
      .ram_clk  (clk_1),
      .ram_addr (a_1[7:0]),
      .ram_me   (~cen_1),
      .ram_we   ({~gwen_1 & ~(&wen_1[21:16]), ~gwen_1 & ~(&wen_1[15:8]), ~gwen_1 & ~(&wen_1[7:0])}),
      .ram_wdata({2{1'b0}, d_1[21:0]}),
      .ram_rdata({2{1'b0}, q_1[21:0]})
  );

  fpga_spram #(
      .MEMDEPTH (256),
      .MEMWIDTH (24),
      .BYTEWIDTH(8),
      .ADDRWIDTH(8),
      .MEMTYPE ("block" )
  )
  mem_2(
      .ram_clk  (clk_2),
      .ram_addr (a_2[7:0]),
      .ram_me   (~cen_2),
      .ram_we   ({~gwen_2 & ~(&wen_2[21:16]), ~gwen_2 & ~(&wen_2[15:8]), ~gwen_2 & ~(&wen_2[7:0])}),
      .ram_wdata({2{1'b0}, d_2[21:0]}),
      .ram_rdata({2{1'b0}, q_2[21:0]})
  );

  fpga_spram #(
      .MEMDEPTH (256),
      .MEMWIDTH (24),
      .BYTEWIDTH(8),
      .ADDRWIDTH(8),
      .MEMTYPE ("block" )
  )
  mem_3(
      .ram_clk  (clk_3),
      .ram_addr (a_3[7:0]),
      .ram_me   (~cen_3),
      .ram_we   ({~gwen_3 & ~(&wen_3[21:16]), ~gwen_3 & ~(&wen_3[15:8]), ~gwen_3 & ~(&wen_3[7:0])}),
      .ram_wdata({2{1'b0}, d_3[21:0]}),
      .ram_rdata({2{1'b0}, q_3[21:0]})
  );

endmodule

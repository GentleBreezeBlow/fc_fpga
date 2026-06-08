// cppe_ram_wrap.v -- FPGA version (auto-generated)
// Source: C:\ai\fpga\test_soc\design\mbist_wrap\rtl_v\cppe_ram_wrap.v
// Generator: fpga_core.memory

module cppe_ram_wrap (
    input         sys_clock,
    input         sys_reset,
    input         sys_test_init,
    input         sys_test_start,
    input         sys_ctrl_select,
    input         sys_bira_en,
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
    input  [12:0] a_0,
    input  [38:0] d_0,
    input  [2:0]  ema_0,
    input  [1:0]  emaw_0,
    input         emas_0,
    input         rdt_0,
    input         wabl_0,
    input  [2:0]  wablm_0,
    input         rawl_0,
    input  [1:0]  rawlm_0,
    input         stov_0,
    input         se_0,
    input  [1:0]  si_0,
    input         dftrambyp_0,
    input         ret1n_0,
    output [1:0]  so_0,
    output [38:0] q_0,

    // Port 1
    input         clk_1,
    input         cen_1,
    input         gwen_1,
    input  [12:0] a_1,
    input  [38:0] d_1,
    input  [2:0]  ema_1,
    input  [1:0]  emaw_1,
    input         emas_1,
    input         rdt_1,
    input         wabl_1,
    input  [2:0]  wablm_1,
    input         rawl_1,
    input  [1:0]  rawlm_1,
    input         stov_1,
    input         se_1,
    input  [1:0]  si_1,
    input         dftrambyp_1,
    input         ret1n_1,
    output [1:0]  so_1,
    output [38:0] q_1
);

  // Default assignments (non-memory ports)
  assign sys_test_pass = 1'b0;
  assign sys_test_done = 1'b0;
  assign so_0 = {2{1'b0}};
  assign so_1 = {2{1'b0}};

  // FPGA memory instantiations

  fpga_spram #(
      .MEMDEPTH (8192),
      .MEMWIDTH (40),
      .BYTEWIDTH(8),
      .ADDRWIDTH(13),
      .MEMTYPE ("block" )
  )
  mem_0(
      .ram_clk  (clk_0),
      .ram_addr (a_0[12:0]),
      .ram_me   (~cen_0),
      .ram_we   ({5{~gwen_0}}),
      .ram_wdata({1{1'b0}, d_0[38:0]}),
      .ram_rdata({1{1'b0}, q_0[38:0]})
  );

  fpga_spram #(
      .MEMDEPTH (8192),
      .MEMWIDTH (40),
      .BYTEWIDTH(8),
      .ADDRWIDTH(13),
      .MEMTYPE ("block" )
  )
  mem_1(
      .ram_clk  (clk_1),
      .ram_addr (a_1[12:0]),
      .ram_me   (~cen_1),
      .ram_we   ({5{~gwen_1}}),
      .ram_wdata({1{1'b0}, d_1[38:0]}),
      .ram_rdata({1{1'b0}, q_1[38:0]})
  );

endmodule

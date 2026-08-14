// eftu_wrap.sv -- FPGA version (auto-generated)
// Source: C:\ai\fpga\test_soc\design\mbist_wrap\rtl_v\eftu_wrap.sv
// Generator: fpga_core.memory

module eftu_wrap (
    input        sysclock,
    input        sys_reset,
    input        sys_test_init,
    input        sys_test_start,
    input        sys_ctrl_select,
    input [3:0]  sys_algo_select,
    input        sys_select_common_algo,
    input [1:0]  sys_retention_test_phase,
    input        sys_preserve_test_inputs,
    output       sys_test_pass,
    output       sys_test_done,

    // Port 0
    input        clk_0,
    input        cen_0,
    input        wen_0,
    input [7:0]  a_0,
    input [31:0] d_0,
    input [2:0]  ema_0,
    input [1:0]  emaw_0,
    input        emas_0,
    input        rdt_0,
    input        wabl_0,
    input [1:0]  wablm_0,
    input        rawl_0,
    input [1:0]  rawlm_0,
    input        se_0,
    input [1:0]  si_0,
    input        dftrambyp_0,
    input        ret1n_0,
    output [1:0] so_0,
    output [31:0] q_0,

    // Port 1
    input        clk_1,
    input        cen_1,
    input        wen_1,
    input [7:0]  a_1,
    input [31:0] d_1,
    input [2:0]  ema_1,
    input [1:0]  emaw_1,
    input        emas_1,
    input        rdt_1,
    input        wabl_1,
    input [1:0]  wablm_1,
    input        rawl_1,
    input [1:0]  rawlm_1,
    input        se_1,
    input [1:0]  si_1,
    input        dftrambyp_1,
    input        ret1n_1,
    output [1:0] so_1,
    output [31:0] q_1,

    // Port 2
    input        clk_2,
    input        cen_2,
    input        gwen_2,
    input [10:0] a_2,
    input [15:0] d_2,
    input [2:0]  ema_2,
    input [1:0]  emaw_2,
    input        emas_2,
    input        rdt_2,
    input        wabl_2,
    input [2:0]  wablm_2,
    input        rawl_2,
    input [1:0]  rawlm_2,
    input        stov_2,
    input        se_2,
    input [1:0]  si_2,
    input        dftrambyp_2,
    input        ret1n_2,
    output [1:0] so_2,
    output [15:0] q_2,

    // Port 3
    input        clk_3,
    input        cen_3,
    input        gwen_3,
    input [10:0] a_3,
    input [15:0] d_3,
    input [2:0]  ema_3,
    input [1:0]  emaw_3,
    input        emas_3,
    input        rdt_3,
    input        wabl_3,
    input [2:0]  wablm_3,
    input        rawl_3,
    input [1:0]  rawlm_3,
    input        stov_3,
    input        se_3,
    input [1:0]  si_3,
    input        dftrambyp_3,
    input        ret1n_3,
    output [1:0] so_3,
    output [15:0] q_3,

    // JTAG & Test Control Signals
    input wire ijtag_tck,
    input wire ijtag_reset,
    input wire ijtag_ce,
    input wire ijtag_se,
    input wire ijtag_ue,
    input wire ijtag_sel,
    input wire ijtag_si,
    output wire ijtag_so,
    input wire ltest_en,
    input wire memory_bypass_en,
    input wire mcp_bounding_en,
    input wire scan_en
);

  // Default assignments (non-memory ports)
  assign sys_test_pass = 1'b0;
  assign sys_test_done = 1'b0;
  assign so_0 = {2{1'b0}};
  assign so_1 = {2{1'b0}};
  assign so_2 = {2{1'b0}};
  assign so_3 = {2{1'b0}};
  assign ijtag_so = 1'b0;

  // FPGA memory instantiations

  fpga_spram #(
      .MEMDEPTH (256),
      .MEMWIDTH (32),
      .BYTEWIDTH(8),
      .ADDRWIDTH(8),
      .MEMTYPE ("block" )
  )
  mem_0(
      .ram_clk  (clk_0),
      .ram_addr (a_0[7:0]),
      .ram_me   (~cen_0),
      .ram_we   ({4{~wen_0}}),
      .ram_wdata(d_0[31:0]),
      .ram_rdata(q_0[31:0])
  );

  fpga_spram #(
      .MEMDEPTH (256),
      .MEMWIDTH (32),
      .BYTEWIDTH(8),
      .ADDRWIDTH(8),
      .MEMTYPE ("block" )
  )
  mem_1(
      .ram_clk  (clk_1),
      .ram_addr (a_1[7:0]),
      .ram_me   (~cen_1),
      .ram_we   ({4{~wen_1}}),
      .ram_wdata(d_1[31:0]),
      .ram_rdata(q_1[31:0])
  );

  fpga_spram #(
      .MEMDEPTH (2048),
      .MEMWIDTH (16),
      .BYTEWIDTH(8),
      .ADDRWIDTH(11),
      .MEMTYPE ("block" )
  )
  mem_2(
      .ram_clk  (clk_2),
      .ram_addr (a_2[10:0]),
      .ram_me   (~cen_2),
      .ram_we   ({2{~gwen_2}}),
      .ram_wdata(d_2[15:0]),
      .ram_rdata(q_2[15:0])
  );

  fpga_spram #(
      .MEMDEPTH (2048),
      .MEMWIDTH (16),
      .BYTEWIDTH(8),
      .ADDRWIDTH(11),
      .MEMTYPE ("block" )
  )
  mem_3(
      .ram_clk  (clk_3),
      .ram_addr (a_3[10:0]),
      .ram_me   (~cen_3),
      .ram_we   ({2{~gwen_3}}),
      .ram_wdata(d_3[15:0]),
      .ram_rdata(q_3[15:0])
  );

endmodule

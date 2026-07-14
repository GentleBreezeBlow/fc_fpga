// u65_wrap.sv -- FPGA version (auto-generated)
// Source: C:\ai\fpga\test_soc\design\mbist_wrap\rtl_v\u65_wrap.sv
// Generator: fpga_core.memory

module u65_wrap (
    input               sys_clock,
    input               sys_reset,
    input               sys_test_init,
    input               sys_test_start,
    input               sys_ctrl_select,
    input [3:0]         sys_algo_select,
    input               sys_select_common_algo,
    input [1:0]         sys_retention_test_phase,
    input               sys_preserve_test_inputs,
    output              sys_test_pass,
    output              sys_test_done,

    input               CLKA_0,
    input               CLKB_0,
    input               CENA_0,
    input               CENB_0,
    input [7:0]         AA_0,
    input [7:0]         AB_0,
    input [63:0]        DB_0,
    input [2:0]         EMAA_0,
    input               EMASA_0,
    input               WABL_0,
    input [1:0]         WABLM_0,
    input               STOV_0,
    input               SEA_0,
    input [1:0]         SIA_0,
    input               DFTRAMBYP_0,
    input [2:0]         EMAB_0,
    input               SEB_0,
    input [1:0]         SIB_0,
    input               RET1N_0,
    output [1:0]        SOA_0,
    output [1:0]        SOB_0,
    output [63:0]       QA_0,

    input               CLKA_1,
    input               CLKB_1,
    input               CENA_1,
    input               CENB_1,
    input [7:0]         AA_1,
    input [7:0]         AB_1,
    input [63:0]        DB_1,
    input [2:0]         EMAA_1,
    input               EMASA_1,
    input               WABL_1,
    input [1:0]         WABLM_1,
    input               STOV_1,
    input               SEA_1,
    input [1:0]         SIA_1,
    input               DFTRAMBYP_1,
    input [2:0]         EMAB_1,
    input               SEB_1,
    input [1:0]         SIB_1,
    input               RET1N_1,
    output [1:0]        SOA_1,
    output [1:0]        SOB_1,
    output [63:0]       QA_1,

    input               CLKA_2,
    input               CLKB_2,
    input               CENA_2,
    input               CENB_2,
    input [7:0]         AA_2,
    input [7:0]         AB_2,
    input [63:0]        DB_2,
    input [2:0]         EMAA_2,
    input               EMASA_2,
    input               WABL_2,
    input [1:0]         WABLM_2,
    input               STOV_2,
    input               SEA_2,
    input [1:0]         SIA_2,
    input               DFTRAMBYP_2,
    input [2:0]         EMAB_2,
    input               SEB_2,
    input [1:0]         SIB_2,
    input               RET1N_2,
    output [1:0]        SOA_2,
    output [1:0]        SOB_2,
    output [63:0]       QA_2,

    input               CLKA_27,
    input               CLKB_27,
    input               CENA_27,
    input               CENB_27,
    input [6:0]         AA_27,
    input [6:0]         AB_27,
    input [127:0]       DB_27,
    input [2:0]         EMAA_27,
    input               EMASA_27,
    input               WABL_27,
    input [1:0]         WABLM_27,
    input               STOV_27,
    input               SEA_27,
    input [1:0]         SIA_27,
    input               DFTRAMBYP_27,
    input [2:0]         EMAB_27,
    input               SEB_27,
    input [1:0]         SIB_27,
    input               RET1N_27,
    output [1:0]        SOA_27,
    output [1:0]        SOB_27,
    output [127:0]      QA_27,

    input               CLKA_28,
    input               CLKB_28,
    input               CENA_28,
    input               CENB_28,
    input [7:0]         AA_28,
    input [7:0]         AB_28,
    input [127:0]       DB_28,
    input [2:0]         EMAA_28,
    input               EMASA_28,
    input               WABL_28,
    input [1:0]         WABLM_28,
    input               STOV_28,
    input               SEA_28,
    input [1:0]         SIA_28,
    input               DFTRAMBYP_28,
    input [2:0]         EMAB_28,
    input               SEB_28,
    input [1:0]         SIB_28,
    input               RET1N_28,
    output [1:0]        SOA_28,
    output [1:0]        SOB_28,
    output [127:0]      QA_28,

    input wire          ijtag_tck,
    input wire          ijtag_reset,
    input wire          ijtag_ce,
    input wire          ijtag_se,
    input wire          ijtag_ue,
    input wire          ijtag_sel,
    input wire          ijtag_si,
    output wire         ijtag_so,
    input wire          ltest_en,
    input wire          memory_bypass_en,
    input wire          mcp_bounding_en,
    input wire          scan_en
);

  // Default assignments (non-memory ports)
  assign sys_test_pass = 1'b0;
  assign sys_test_done = 1'b0;
  assign SOA_0 = {2{1'b0}};
  assign SOB_0 = {2{1'b0}};
  assign SOA_1 = {2{1'b0}};
  assign SOB_1 = {2{1'b0}};
  assign SOA_2 = {2{1'b0}};
  assign SOB_2 = {2{1'b0}};
  assign SOA_27 = {2{1'b0}};
  assign SOB_27 = {2{1'b0}};
  assign SOA_28 = {2{1'b0}};
  assign SOB_28 = {2{1'b0}};
  assign ijtag_so = 1'b0;

  // FPGA memory instantiations
  fpga_sdpram #(
      .MEMDEPTH (256),
      .MEMWIDTH (64),
      .BYTEWIDTH(8),
      .ADDRWIDTH(8),
      .MEMTYPE ("block" )
  )
  mem_0(
      .wr_clk  (CLKB_0),
      .rd_clk  (CLKA_0),
      .wr_addr (AB_0[7:0]),
      .rd_addr (AA_0[7:0]),
      .wr_en   (~CENB_0),
      .wr_we   ({8{1'b1}}),
      .wr_data (DB_0[63:0]),
      .rd_en   (~CENA_0),
      .rd_data (QA_0[63:0])
  );
  fpga_sdpram #(
      .MEMDEPTH (256),
      .MEMWIDTH (64),
      .BYTEWIDTH(8),
      .ADDRWIDTH(8),
      .MEMTYPE ("block" )
  )
  mem_1(
      .wr_clk  (CLKB_1),
      .rd_clk  (CLKA_1),
      .wr_addr (AB_1[7:0]),
      .rd_addr (AA_1[7:0]),
      .wr_en   (~CENB_1),
      .wr_we   ({8{1'b1}}),
      .wr_data (DB_1[63:0]),
      .rd_en   (~CENA_1),
      .rd_data (QA_1[63:0])
  );
  fpga_sdpram #(
      .MEMDEPTH (256),
      .MEMWIDTH (64),
      .BYTEWIDTH(8),
      .ADDRWIDTH(8),
      .MEMTYPE ("block" )
  )
  mem_2(
      .wr_clk  (CLKB_2),
      .rd_clk  (CLKA_2),
      .wr_addr (AB_2[7:0]),
      .rd_addr (AA_2[7:0]),
      .wr_en   (~CENB_2),
      .wr_we   ({8{1'b1}}),
      .wr_data (DB_2[63:0]),
      .rd_en   (~CENA_2),
      .rd_data (QA_2[63:0])
  );
  fpga_sdpram #(
      .MEMDEPTH (128),
      .MEMWIDTH (128),
      .BYTEWIDTH(8),
      .ADDRWIDTH(7),
      .MEMTYPE ("block" )
  )
  mem_27(
      .wr_clk  (CLKB_27),
      .rd_clk  (CLKA_27),
      .wr_addr (AB_27[6:0]),
      .rd_addr (AA_27[6:0]),
      .wr_en   (~CENB_27),
      .wr_we   ({16{1'b1}}),
      .wr_data (DB_27[127:0]),
      .rd_en   (~CENA_27),
      .rd_data (QA_27[127:0])
  );
  fpga_sdpram #(
      .MEMDEPTH (256),
      .MEMWIDTH (128),
      .BYTEWIDTH(8),
      .ADDRWIDTH(8),
      .MEMTYPE ("block" )
  )
  mem_28(
      .wr_clk  (CLKB_28),
      .rd_clk  (CLKA_28),
      .wr_addr (AB_28[7:0]),
      .rd_addr (AA_28[7:0]),
      .wr_en   (~CENB_28),
      .wr_we   ({16{1'b1}}),
      .wr_data (DB_28[127:0]),
      .rd_en   (~CENA_28),
      .rd_data (QA_28[127:0])
  );

endmodule

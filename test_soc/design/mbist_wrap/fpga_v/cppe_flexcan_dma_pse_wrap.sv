// cppe_flexcan_dma_pse_wrap.sv -- FPGA version (auto-generated)
// Source: D:\ai\fpga\test_soc\design\mbist_wrap\rtl_v\cppe_flexcan_dma_pse_wrap.sv
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

.....

endmodule

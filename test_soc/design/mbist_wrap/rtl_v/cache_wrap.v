module cache_wrap (
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
    output [38:0] q_0

);

endmodule
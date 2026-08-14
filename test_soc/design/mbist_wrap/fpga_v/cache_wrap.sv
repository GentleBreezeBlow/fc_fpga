// cache_wrap.sv -- FPGA version (auto-generated)
// Source: C:\ai\fpga\test_soc\design\mbist_wrap\rtl_v\cache_wrap.sv
// Generator: fpga_core.memory

module cache_wrap (
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

    // Port 0
    input        clk_0,
    input        cen_0,
    input        wen_0,
    input [7:0]  a_0,
    input [127:0] d_0,
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
    output [127:0] q_0,

    // Port 1
    input        clk_1,
    input        cen_1,
    input        wen_1,
    input [6:0]  a_1,
    input [25:0] d_1,
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
    output [25:0] q_1,

    // Port 2
    input        clk_2,
    input        cen_2,
    input        wen_2,
    input [6:0]  a_2,
    input [25:0] d_2,
    input [2:0]  ema_2,
    input [1:0]  emaw_2,
    input        emas_2,
    input        rdt_2,
    input        wabl_2,
    input [1:0]  wablm_2,
    input        rawl_2,
    input [1:0]  rawlm_2,
    input        se_2,
    input [1:0]  si_2,
    input        dftrambyp_2,
    input        ret1n_2,
    output [1:0] so_2,
    output [25:0] q_2,

    // Port 3
    input        clk_3,
    input        cen_3,
    input        wen_3,
    input [6:0]  a_3,
    input [25:0] d_3,
    input [2:0]  ema_3,
    input [1:0]  emaw_3,
    input        emas_3,
    input        rdt_3,
    input        wabl_3,
    input [1:0]  wablm_3,
    input        rawl_3,
    input [1:0]  rawlm_3,
    input        se_3,
    input [1:0]  si_3,
    input        dftrambyp_3,
    input        ret1n_3,
    output [1:0] so_3,
    output [25:0] q_3,

    // Port 4
    input        clk_4,
    input        cen_4,
    input        wen_4,
    input [6:0]  a_4,
    input [25:0] d_4,
    input [2:0]  ema_4,
    input [1:0]  emaw_4,
    input        emas_4,
    input        rdt_4,
    input        wabl_4,
    input [1:0]  wablm_4,
    input        rawl_4,
    input [1:0]  rawlm_4,
    input        se_4,
    input [1:0]  si_4,
    input        dftrambyp_4,
    input        ret1n_4,
    output [1:0] so_4,
    output [25:0] q_4,

    // Port 5
    input        clk_5,
    input        cen_5,
    input        wen_5,
    input [6:0]  a_5,
    input [25:0] d_5,
    input [2:0]  ema_5,
    input [1:0]  emaw_5,
    input        emas_5,
    input        rdt_5,
    input        wabl_5,
    input [1:0]  wablm_5,
    input        rawl_5,
    input [1:0]  rawlm_5,
    input        se_5,
    input [1:0]  si_5,
    input        dftrambyp_5,
    input        ret1n_5,
    output [1:0] so_5,
    output [25:0] q_5,

    // Port 6
    input        clk_6,
    input        cen_6,
    input        wen_6,
    input [6:0]  a_6,
    input [25:0] d_6,
    input [2:0]  ema_6,
    input [1:0]  emaw_6,
    input        emas_6,
    input        rdt_6,
    input        wabl_6,
    input [1:0]  wablm_6,
    input        rawl_6,
    input [1:0]  rawlm_6,
    input        se_6,
    input [1:0]  si_6,
    input        dftrambyp_6,
    input        ret1n_6,
    output [1:0] so_6,
    output [25:0] q_6,

    // Port 7
    input        clk_7,
    input        cen_7,
    input        wen_7,
    input [6:0]  a_7,
    input [25:0] d_7,
    input [2:0]  ema_7,
    input [1:0]  emaw_7,
    input        emas_7,
    input        rdt_7,
    input        wabl_7,
    input [1:0]  wablm_7,
    input        rawl_7,
    input [1:0]  rawlm_7,
    input        se_7,
    input [1:0]  si_7,
    input        dftrambyp_7,
    input        ret1n_7,
    output [1:0] so_7,
    output [25:0] q_7,

    // Port 8
    input        clk_8,
    input        cen_8,
    input        wen_8,
    input [6:0]  a_8,
    input [25:0] d_8,
    input [2:0]  ema_8,
    input [1:0]  emaw_8,
    input        emas_8,
    input        rdt_8,
    input        wabl_8,
    input [1:0]  wablm_8,
    input        rawl_8,
    input [1:0]  rawlm_8,
    input        se_8,
    input [1:0]  si_8,
    input        dftrambyp_8,
    input        ret1n_8,
    output [1:0] so_8,
    output [25:0] q_8,

    // Port 9
    input        clk_9,
    input        cen_9,
    input        wen_9,
    input [6:0]  a_9,
    input [25:0] d_9,
    input [2:0]  ema_9,
    input [1:0]  emaw_9,
    input        emas_9,
    input        rdt_9,
    input        wabl_9,
    input [1:0]  wablm_9,
    input        rawl_9,
    input [1:0]  rawlm_9,
    input        se_9,
    input [1:0]  si_9,
    input        dftrambyp_9,
    input        ret1n_9,
    output [1:0] so_9,
    output [25:0] q_9,

    // Port 10
    input        clk_10,
    input        cen_10,
    input        wen_10,
    input [6:0]  a_10,
    input [25:0] d_10,
    input [2:0]  ema_10,
    input [1:0]  emaw_10,
    input        emas_10,
    input        rdt_10,
    input        wabl_10,
    input [1:0]  wablm_10,
    input        rawl_10,
    input [1:0]  rawlm_10,
    input        se_10,
    input [1:0]  si_10,
    input        dftrambyp_10,
    input        ret1n_10,
    output [1:0] so_10,
    output [25:0] q_10,

    // Port 11
    input        clk_11,
    input        cen_11,
    input        wen_11,
    input [6:0]  a_11,
    input [25:0] d_11,
    input [2:0]  ema_11,
    input [1:0]  emaw_11,
    input        emas_11,
    input        rdt_11,
    input        wabl_11,
    input [1:0]  wablm_11,
    input        rawl_11,
    input [1:0]  rawlm_11,
    input        se_11,
    input [1:0]  si_11,
    input        dftrambyp_11,
    input        ret1n_11,
    output [1:0] so_11,
    output [25:0] q_11,

    // Port 12
    input        clk_12,
    input        cen_12,
    input        wen_12,
    input [6:0]  a_12,
    input [25:0] d_12,
    input [2:0]  ema_12,
    input [1:0]  emaw_12,
    input        emas_12,
    input        rdt_12,
    input        wabl_12,
    input [1:0]  wablm_12,
    input        rawl_12,
    input [1:0]  rawlm_12,
    input        se_12,
    input [1:0]  si_12,
    input        dftrambyp_12,
    input        ret1n_12,
    output [1:0] so_12,
    output [25:0] q_12,

    // Port 13
    input        clk_13,
    input        cen_13,
    input        wen_13,
    input [6:0]  a_13,
    input [25:0] d_13,
    input [2:0]  ema_13,
    input [1:0]  emaw_13,
    input        emas_13,
    input        rdt_13,
    input        wabl_13,
    input [1:0]  wablm_13,
    input        rawl_13,
    input [1:0]  rawlm_13,
    input        se_13,
    input [1:0]  si_13,
    input        dftrambyp_13,
    input        ret1n_13,
    output [1:0] so_13,
    output [25:0] q_13,

    // Port 14
    input        clk_14,
    input        cen_14,
    input        wen_14,
    input [6:0]  a_14,
    input [25:0] d_14,
    input [2:0]  ema_14,
    input [1:0]  emaw_14,
    input        emas_14,
    input        rdt_14,
    input        wabl_14,
    input [1:0]  wablm_14,
    input        rawl_14,
    input [1:0]  rawlm_14,
    input        se_14,
    input [1:0]  si_14,
    input        dftrambyp_14,
    input        ret1n_14,
    output [1:0] so_14,
    output [25:0] q_14,

    // Port 15
    input        clk_15,
    input        cen_15,
    input        wen_15,
    input [6:0]  a_15,
    input [25:0] d_15,
    input [2:0]  ema_15,
    input [1:0]  emaw_15,
    input        emas_15,
    input        rdt_15,
    input        wabl_15,
    input [1:0]  wablm_15,
    input        rawl_15,
    input [1:0]  rawlm_15,
    input        se_15,
    input [1:0]  si_15,
    input        dftrambyp_15,
    input        ret1n_15,
    output [1:0] so_15,
    output [25:0] q_15,

    // Port 16
    input        clk_16,
    input        cen_16,
    input        wen_16,
    input [6:0]  a_16,
    input [25:0] d_16,
    input [2:0]  ema_16,
    input [1:0]  emaw_16,
    input        emas_16,
    input        rdt_16,
    input        wabl_16,
    input [1:0]  wablm_16,
    input        rawl_16,
    input [1:0]  rawlm_16,
    input        se_16,
    input [1:0]  si_16,
    input        dftrambyp_16,
    input        ret1n_16,
    output [1:0] so_16,
    output [25:0] q_16,

    // Port 17
    input        clk_17,
    input        cen_17,
    input        gwen_17,
    input [9:0]  a_17,
    input [70:0] d_17,
    input [2:0]  ema_17,
    input [1:0]  emaw_17,
    input        emas_17,
    input        rdt_17,
    input        wabl_17,
    input [1:0]  wablm_17,
    input        rawl_17,
    input [1:0]  rawlm_17,
    input        stov_17,
    input        se_17,
    input [1:0]  si_17,
    input        dftrambyp_17,
    input        ret1n_17,
    output [1:0] so_17,
    output [70:0] q_17,

    // Port 18
    input        clk_18,
    input        cen_18,
    input        gwen_18,
    input [9:0]  a_18,
    input [70:0] d_18,
    input [2:0]  ema_18,
    input [1:0]  emaw_18,
    input        emas_18,
    input        rdt_18,
    input        wabl_18,
    input [1:0]  wablm_18,
    input        rawl_18,
    input [1:0]  rawlm_18,
    input        stov_18,
    input        se_18,
    input [1:0]  si_18,
    input        dftrambyp_18,
    input        ret1n_18,
    output [1:0] so_18,
    output [70:0] q_18,

    // Port 19
    input        clk_19,
    input        cen_19,
    input        gwen_19,
    input [9:0]  a_19,
    input [70:0] d_19,
    input [2:0]  ema_19,
    input [1:0]  emaw_19,
    input        emas_19,
    input        rdt_19,
    input        wabl_19,
    input [1:0]  wablm_19,
    input        rawl_19,
    input [1:0]  rawlm_19,
    input        stov_19,
    input        se_19,
    input [1:0]  si_19,
    input        dftrambyp_19,
    input        ret1n_19,
    output [1:0] so_19,
    output [70:0] q_19,

    // Port 20
    input        clk_20,
    input        cen_20,
    input        gwen_20,
    input [9:0]  a_20,
    input [70:0] d_20,
    input [2:0]  ema_20,
    input [1:0]  emaw_20,
    input        emas_20,
    input        rdt_20,
    input        wabl_20,
    input [1:0]  wablm_20,
    input        rawl_20,
    input [1:0]  rawlm_20,
    input        stov_20,
    input        se_20,
    input [1:0]  si_20,
    input        dftrambyp_20,
    input        ret1n_20,
    output [1:0] so_20,
    output [70:0] q_20,

    // Port 21
    input        clk_21,
    input        cen_21,
    input        gwen_21,
    input [9:0]  a_21,
    input [70:0] d_21,
    input [2:0]  ema_21,
    input [1:0]  emaw_21,
    input        emas_21,
    input        rdt_21,
    input        wabl_21,
    input [1:0]  wablm_21,
    input        rawl_21,
    input [1:0]  rawlm_21,
    input        stov_21,
    input        se_21,
    input [1:0]  si_21,
    input        dftrambyp_21,
    input        ret1n_21,
    output [1:0] so_21,
    output [70:0] q_21,

    // Port 22
    input        clk_22,
    input        cen_22,
    input        gwen_22,
    input [9:0]  a_22,
    input [70:0] d_22,
    input [2:0]  ema_22,
    input [1:0]  emaw_22,
    input        emas_22,
    input        rdt_22,
    input        wabl_22,
    input [1:0]  wablm_22,
    input        rawl_22,
    input [1:0]  rawlm_22,
    input        stov_22,
    input        se_22,
    input [1:0]  si_22,
    input        dftrambyp_22,
    input        ret1n_22,
    output [1:0] so_22,
    output [70:0] q_22,

    // Port 23
    input        clk_23,
    input        cen_23,
    input        gwen_23,
    input [9:0]  a_23,
    input [70:0] d_23,
    input [2:0]  ema_23,
    input [1:0]  emaw_23,
    input        emas_23,
    input        rdt_23,
    input        wabl_23,
    input [1:0]  wablm_23,
    input        rawl_23,
    input [1:0]  rawlm_23,
    input        stov_23,
    input        se_23,
    input [1:0]  si_23,
    input        dftrambyp_23,
    input        ret1n_23,
    output [1:0] so_23,
    output [70:0] q_23,

        // Port 24
    input        clk_24,
    input        cen_24,
    input        gwen_24,
    input [9:0]  a_24,
    input [70:0] d_24,
    input [2:0]  ema_24,
    input [1:0]  emaw_24,
    input        emas_24,
    input        rdt_24,
    input        wabl_24,
    input [1:0]  wablm_24,
    input        rawl_24,
    input [1:0]  rawlm_24,
    input        stov_24,
    input        se_24,
    input [1:0]  si_24,
    input        dftrambyp_24,
    input        ret1n_24,
    output [1:0] so_24,
    output [70:0] q_24,

    // Port 25
    input        clk_25,
    input        cen_25,
    input        gwen_25,
    input [9:0]  a_25,
    input [37:0] d_25,
    input [2:0]  ema_25,
    input [1:0]  emaw_25,
    input        emas_25,
    input        rdt_25,
    input        wabl_25,
    input [1:0]  wablm_25,
    input        rawl_25,
    input [1:0]  rawlm_25,
    input        stov_25,
    input        se_25,
    input [1:0]  si_25,
    input        dftrambyp_25,
    input        ret1n_25,
    output [1:0] so_25,
    output [37:0] q_25,

    // Port 26
    input        clk_26,
    input        cen_26,
    input        gwen_26,
    input [9:0]  a_26,
    input [37:0] d_26,
    input [2:0]  ema_26,
    input [1:0]  emaw_26,
    input        emas_26,
    input        rdt_26,
    input        wabl_26,
    input [1:0]  wablm_26,
    input        rawl_26,
    input [1:0]  rawlm_26,
    input        stov_26,
    input        se_26,
    input [1:0]  si_26,
    input        dftrambyp_26,
    input        ret1n_26,
    output [1:0] so_26,
    output [37:0] q_26,

    // Port 27
    input        clk_27,
    input        cen_27,
    input        gwen_27,
    input [9:0]  a_27,
    input [37:0] d_27,
    input [2:0]  ema_27,
    input [1:0]  emaw_27,
    input        emas_27,
    input        rdt_27,
    input        wabl_27,
    input [1:0]  wablm_27,
    input        rawl_27,
    input [1:0]  rawlm_27,
    input        stov_27,
    input        se_27,
    input [1:0]  si_27,
    input        dftrambyp_27,
    input        ret1n_27,
    output [1:0] so_27,
    output [37:0] q_27,

    // Port 28
    input        clk_28,
    input        cen_28,
    input        gwen_28,
    input [9:0]  a_28,
    input [37:0] d_28,
    input [2:0]  ema_28,
    input [1:0]  emaw_28,
    input        emas_28,
    input        rdt_28,
    input        wabl_28,
    input [1:0]  wablm_28,
    input        rawl_28,
    input [1:0]  rawlm_28,
    input        stov_28,
    input        se_28,
    input [1:0]  si_28,
    input        dftrambyp_28,
    input        ret1n_28,
    output [1:0] so_28,
    output [37:0] q_28,

    // Port 29
    input        clk_29,
    input        cen_29,
    input        gwen_29,
    input [9:0]  a_29,
    input [37:0] d_29,
    input [2:0]  ema_29,
    input [1:0]  emaw_29,
    input        emas_29,
    input        rdt_29,
    input        wabl_29,
    input [1:0]  wablm_29,
    input        rawl_29,
    input [1:0]  rawlm_29,
    input        stov_29,
    input        se_29,
    input [1:0]  si_29,
    input        dftrambyp_29,
    input        ret1n_29,
    output [1:0] so_29,
    output [37:0] q_29,

    // Port 30
    input        clk_30,
    input        cen_30,
    input        gwen_30,
    input [9:0]  a_30,
    input [37:0] d_30,
    input [2:0]  ema_30,
    input [1:0]  emaw_30,
    input        emas_30,
    input        rdt_30,
    input        wabl_30,
    input [1:0]  wablm_30,
    input        rawl_30,
    input [1:0]  rawlm_30,
    input        stov_30,
    input        se_30,
    input [1:0]  si_30,
    input        dftrambyp_30,
    input        ret1n_30,
    output [1:0] so_30,
    output [37:0] q_30,

    // Port 31
    input        clk_31,
    input        cen_31,
    input        gwen_31,
    input [9:0]  a_31,
    input [37:0] d_31,
    input [2:0]  ema_31,
    input [1:0]  emaw_31,
    input        emas_31,
    input        rdt_31,
    input        wabl_31,
    input [1:0]  wablm_31,
    input        rawl_31,
    input [1:0]  rawlm_31,
    input        stov_31,
    input        se_31,
    input [1:0]  si_31,
    input        dftrambyp_31,
    input        ret1n_31,
    output [1:0] so_31,
    output [37:0] q_31,

    // Port 32
    input        clk_32,
    input        cen_32,
    input        gwen_32,
    input [9:0]  a_32,
    input [37:0] d_32,
    input [2:0]  ema_32,
    input [1:0]  emaw_32,
    input        emas_32,
    input        rdt_32,
    input        wabl_32,
    input [1:0]  wablm_32,
    input        rawl_32,
    input [1:0]  rawlm_32,
    input        stov_32,
    input        se_32,
    input [1:0]  si_32,
    input        dftrambyp_32,
    input        ret1n_32,
    output [1:0] so_32,
    output [37:0] q_32,

    // Port 33
    input        clk_33,
    input        cen_33,
    input        gwen_33,
    input [9:0]  a_33,
    input [37:0] d_33,
    input [2:0]  ema_33,
    input [1:0]  emaw_33,
    input        emas_33,
    input        rdt_33,
    input        wabl_33,
    input [1:0]  wablm_33,
    input        rawl_33,
    input [1:0]  rawlm_33,
    input        stov_33,
    input        se_33,
    input [1:0]  si_33,
    input        dftrambyp_33,
    input        ret1n_33,
    output [1:0] so_33,
    output [37:0] q_33,

    // Port 34
    input        clk_34,
    input        cen_34,
    input        gwen_34,
    input [9:0]  a_34,
    input [37:0] d_34,
    input [2:0]  ema_34,
    input [1:0]  emaw_34,
    input        emas_34,
    input        rdt_34,
    input        wabl_34,
    input [1:0]  wablm_34,
    input        rawl_34,
    input [1:0]  rawlm_34,
    input        stov_34,
    input        se_34,
    input [1:0]  si_34,
    input        dftrambyp_34,
    input        ret1n_34,
    output [1:0] so_34,
    output [37:0] q_34,

    // Port 35
    input        clk_35,
    input        cen_35,
    input        gwen_35,
    input [9:0]  a_35,
    input [37:0] d_35,
    input [2:0]  ema_35,
    input [1:0]  emaw_35,
    input        emas_35,
    input        rdt_35,
    input        wabl_35,
    input [1:0]  wablm_35,
    input        rawl_35,
    input [1:0]  rawlm_35,
    input        stov_35,
    input        se_35,
    input [1:0]  si_35,
    input        dftrambyp_35,
    input        ret1n_35,
    output [1:0] so_35,
    output [37:0] q_35,

    // Port 36
    input        clk_36,
    input        cen_36,
    input        gwen_36,
    input [9:0]  a_36,
    input [37:0] d_36,
    input [2:0]  ema_36,
    input [1:0]  emaw_36,
    input        emas_36,
    input        rdt_36,
    input        wabl_36,
    input [1:0]  wablm_36,
    input        rawl_36,
    input [1:0]  rawlm_36,
    input        stov_36,
    input        se_36,
    input [1:0]  si_36,
    input        dftrambyp_36,
    input        ret1n_36,
    output [1:0] so_36,
    output [37:0] q_36,

    // Port 37
    input        clk_37,
    input        cen_37,
    input        gwen_37,
    input [9:0]  a_37,
    input [37:0] d_37,
    input [2:0]  ema_37,
    input [1:0]  emaw_37,
    input        emas_37,
    input        rdt_37,
    input        wabl_37,
    input [1:0]  wablm_37,
    input        rawl_37,
    input [1:0]  rawlm_37,
    input        stov_37,
    input        se_37,
    input [1:0]  si_37,
    input        dftrambyp_37,
    input        ret1n_37,
    output [1:0] so_37,
    output [37:0] q_37,

    // Port 38
    input        clk_38,
    input        cen_38,
    input        gwen_38,
    input [9:0]  a_38,
    input [37:0] d_38,
    input [2:0]  ema_38,
    input [1:0]  emaw_38,
    input        emas_38,
    input        rdt_38,
    input        wabl_38,
    input [1:0]  wablm_38,
    input        rawl_38,
    input [1:0]  rawlm_38,
    input        stov_38,
    input        se_38,
    input [1:0]  si_38,
    input        dftrambyp_38,
    input        ret1n_38,
    output [1:0] so_38,
    output [37:0] q_38,

    // Port 39
    input        clk_39,
    input        cen_39,
    input        gwen_39,
    input [9:0]  a_39,
    input [37:0] d_39,
    input [2:0]  ema_39,
    input [1:0]  emaw_39,
    input        emas_39,
    input        rdt_39,
    input        wabl_39,
    input [1:0]  wablm_39,
    input        rawl_39,
    input [1:0]  rawlm_39,
    input        stov_39,
    input        se_39,
    input [1:0]  si_39,
    input        dftrambyp_39,
    input        ret1n_39,
    output [1:0] so_39,
    output [37:0] q_39,

    // Port 40
    input        clk_40,
    input        cen_40,
    input        gwen_40,
    input [9:0]  a_40,
    input [37:0] d_40,
    input [2:0]  ema_40,
    input [1:0]  emaw_40,
    input        emas_40,
    input        rdt_40,
    input        wabl_40,
    input [1:0]  wablm_40,
    input        rawl_40,
    input [1:0]  rawlm_40,
    input        stov_40,
    input        se_40,
    input [1:0]  si_40,
    input        dftrambyp_40,
    input        ret1n_40,
    output [1:0] so_40,
    output [37:0] q_40
    , input wire ijtag_tck, input wire ijtag_reset, input wire ijtag_ce, input wire ijtag_se,
    input wire ijtag_ue, input wire ijtag_sel, input wire ijtag_si,
    output wire ijtag_so, input wire ltest_en, input wire memory_bypass_en,
    input wire mcp_bounding_en, input wire scan_en);

  // Default assignments (non-memory ports)
  assign sys_test_pass = 1'b0;
  assign sys_test_done = 1'b0;
  assign so_0 = {2{1'b0}};
  assign so_1 = {2{1'b0}};
  assign so_2 = {2{1'b0}};
  assign so_3 = {2{1'b0}};
  assign so_4 = {2{1'b0}};
  assign so_5 = {2{1'b0}};
  assign so_6 = {2{1'b0}};
  assign so_7 = {2{1'b0}};
  assign so_8 = {2{1'b0}};
  assign so_9 = {2{1'b0}};
  assign so_10 = {2{1'b0}};
  assign so_11 = {2{1'b0}};
  assign so_12 = {2{1'b0}};
  assign so_13 = {2{1'b0}};
  assign so_14 = {2{1'b0}};
  assign so_15 = {2{1'b0}};
  assign so_16 = {2{1'b0}};
  assign so_17 = {2{1'b0}};
  assign so_18 = {2{1'b0}};
  assign so_19 = {2{1'b0}};
  assign so_20 = {2{1'b0}};
  assign so_21 = {2{1'b0}};
  assign so_22 = {2{1'b0}};
  assign so_23 = {2{1'b0}};
  assign so_24 = {2{1'b0}};
  assign so_25 = {2{1'b0}};
  assign so_26 = {2{1'b0}};
  assign so_27 = {2{1'b0}};
  assign so_28 = {2{1'b0}};
  assign so_29 = {2{1'b0}};
  assign so_30 = {2{1'b0}};
  assign so_31 = {2{1'b0}};
  assign so_32 = {2{1'b0}};
  assign so_33 = {2{1'b0}};
  assign so_34 = {2{1'b0}};
  assign so_35 = {2{1'b0}};
  assign so_36 = {2{1'b0}};
  assign so_37 = {2{1'b0}};
  assign so_38 = {2{1'b0}};
  assign so_39 = {2{1'b0}};
  assign so_40 = {2{1'b0}};
  assign ijtag_so = 1'b0;

  // FPGA memory instantiations

  fpga_spram #(
      .MEMDEPTH (256),
      .MEMWIDTH (128),
      .BYTEWIDTH(8),
      .ADDRWIDTH(8),
      .MEMTYPE ("block" )
  )
  mem_0(
      .ram_clk  (clk_0),
      .ram_addr (a_0[7:0]),
      .ram_me   (~cen_0),
      .ram_we   ({16{~wen_0}}),
      .ram_wdata(d_0[127:0]),
      .ram_rdata(q_0[127:0])
  );

  wire [31:0] mem_rdata_1;
  fpga_spram #(
      .MEMDEPTH (128),
      .MEMWIDTH (32),
      .BYTEWIDTH(8),
      .ADDRWIDTH(7),
      .MEMTYPE ("block" )
  )
  mem_1(
      .ram_clk  (clk_1),
      .ram_addr (a_1[6:0]),
      .ram_me   (~cen_1),
      .ram_we   ({4{~wen_1}}),
      .ram_wdata({{6{1'b0}}, d_1[25:0]}),
      .ram_rdata(mem_rdata_1)
  );
  assign q_1[25:0] = mem_rdata_1[25:0];

  wire [31:0] mem_rdata_2;
  fpga_spram #(
      .MEMDEPTH (128),
      .MEMWIDTH (32),
      .BYTEWIDTH(8),
      .ADDRWIDTH(7),
      .MEMTYPE ("block" )
  )
  mem_2(
      .ram_clk  (clk_2),
      .ram_addr (a_2[6:0]),
      .ram_me   (~cen_2),
      .ram_we   ({4{~wen_2}}),
      .ram_wdata({{6{1'b0}}, d_2[25:0]}),
      .ram_rdata(mem_rdata_2)
  );
  assign q_2[25:0] = mem_rdata_2[25:0];

  wire [31:0] mem_rdata_3;
  fpga_spram #(
      .MEMDEPTH (128),
      .MEMWIDTH (32),
      .BYTEWIDTH(8),
      .ADDRWIDTH(7),
      .MEMTYPE ("block" )
  )
  mem_3(
      .ram_clk  (clk_3),
      .ram_addr (a_3[6:0]),
      .ram_me   (~cen_3),
      .ram_we   ({4{~wen_3}}),
      .ram_wdata({{6{1'b0}}, d_3[25:0]}),
      .ram_rdata(mem_rdata_3)
  );
  assign q_3[25:0] = mem_rdata_3[25:0];

  wire [31:0] mem_rdata_4;
  fpga_spram #(
      .MEMDEPTH (128),
      .MEMWIDTH (32),
      .BYTEWIDTH(8),
      .ADDRWIDTH(7),
      .MEMTYPE ("block" )
  )
  mem_4(
      .ram_clk  (clk_4),
      .ram_addr (a_4[6:0]),
      .ram_me   (~cen_4),
      .ram_we   ({4{~wen_4}}),
      .ram_wdata({{6{1'b0}}, d_4[25:0]}),
      .ram_rdata(mem_rdata_4)
  );
  assign q_4[25:0] = mem_rdata_4[25:0];

  wire [31:0] mem_rdata_5;
  fpga_spram #(
      .MEMDEPTH (128),
      .MEMWIDTH (32),
      .BYTEWIDTH(8),
      .ADDRWIDTH(7),
      .MEMTYPE ("block" )
  )
  mem_5(
      .ram_clk  (clk_5),
      .ram_addr (a_5[6:0]),
      .ram_me   (~cen_5),
      .ram_we   ({4{~wen_5}}),
      .ram_wdata({{6{1'b0}}, d_5[25:0]}),
      .ram_rdata(mem_rdata_5)
  );
  assign q_5[25:0] = mem_rdata_5[25:0];

  wire [31:0] mem_rdata_6;
  fpga_spram #(
      .MEMDEPTH (128),
      .MEMWIDTH (32),
      .BYTEWIDTH(8),
      .ADDRWIDTH(7),
      .MEMTYPE ("block" )
  )
  mem_6(
      .ram_clk  (clk_6),
      .ram_addr (a_6[6:0]),
      .ram_me   (~cen_6),
      .ram_we   ({4{~wen_6}}),
      .ram_wdata({{6{1'b0}}, d_6[25:0]}),
      .ram_rdata(mem_rdata_6)
  );
  assign q_6[25:0] = mem_rdata_6[25:0];

  wire [31:0] mem_rdata_7;
  fpga_spram #(
      .MEMDEPTH (128),
      .MEMWIDTH (32),
      .BYTEWIDTH(8),
      .ADDRWIDTH(7),
      .MEMTYPE ("block" )
  )
  mem_7(
      .ram_clk  (clk_7),
      .ram_addr (a_7[6:0]),
      .ram_me   (~cen_7),
      .ram_we   ({4{~wen_7}}),
      .ram_wdata({{6{1'b0}}, d_7[25:0]}),
      .ram_rdata(mem_rdata_7)
  );
  assign q_7[25:0] = mem_rdata_7[25:0];

  wire [31:0] mem_rdata_8;
  fpga_spram #(
      .MEMDEPTH (128),
      .MEMWIDTH (32),
      .BYTEWIDTH(8),
      .ADDRWIDTH(7),
      .MEMTYPE ("block" )
  )
  mem_8(
      .ram_clk  (clk_8),
      .ram_addr (a_8[6:0]),
      .ram_me   (~cen_8),
      .ram_we   ({4{~wen_8}}),
      .ram_wdata({{6{1'b0}}, d_8[25:0]}),
      .ram_rdata(mem_rdata_8)
  );
  assign q_8[25:0] = mem_rdata_8[25:0];

  wire [31:0] mem_rdata_9;
  fpga_spram #(
      .MEMDEPTH (128),
      .MEMWIDTH (32),
      .BYTEWIDTH(8),
      .ADDRWIDTH(7),
      .MEMTYPE ("block" )
  )
  mem_9(
      .ram_clk  (clk_9),
      .ram_addr (a_9[6:0]),
      .ram_me   (~cen_9),
      .ram_we   ({4{~wen_9}}),
      .ram_wdata({{6{1'b0}}, d_9[25:0]}),
      .ram_rdata(mem_rdata_9)
  );
  assign q_9[25:0] = mem_rdata_9[25:0];

  wire [31:0] mem_rdata_10;
  fpga_spram #(
      .MEMDEPTH (128),
      .MEMWIDTH (32),
      .BYTEWIDTH(8),
      .ADDRWIDTH(7),
      .MEMTYPE ("block" )
  )
  mem_10(
      .ram_clk  (clk_10),
      .ram_addr (a_10[6:0]),
      .ram_me   (~cen_10),
      .ram_we   ({4{~wen_10}}),
      .ram_wdata({{6{1'b0}}, d_10[25:0]}),
      .ram_rdata(mem_rdata_10)
  );
  assign q_10[25:0] = mem_rdata_10[25:0];

  wire [31:0] mem_rdata_11;
  fpga_spram #(
      .MEMDEPTH (128),
      .MEMWIDTH (32),
      .BYTEWIDTH(8),
      .ADDRWIDTH(7),
      .MEMTYPE ("block" )
  )
  mem_11(
      .ram_clk  (clk_11),
      .ram_addr (a_11[6:0]),
      .ram_me   (~cen_11),
      .ram_we   ({4{~wen_11}}),
      .ram_wdata({{6{1'b0}}, d_11[25:0]}),
      .ram_rdata(mem_rdata_11)
  );
  assign q_11[25:0] = mem_rdata_11[25:0];

  wire [31:0] mem_rdata_12;
  fpga_spram #(
      .MEMDEPTH (128),
      .MEMWIDTH (32),
      .BYTEWIDTH(8),
      .ADDRWIDTH(7),
      .MEMTYPE ("block" )
  )
  mem_12(
      .ram_clk  (clk_12),
      .ram_addr (a_12[6:0]),
      .ram_me   (~cen_12),
      .ram_we   ({4{~wen_12}}),
      .ram_wdata({{6{1'b0}}, d_12[25:0]}),
      .ram_rdata(mem_rdata_12)
  );
  assign q_12[25:0] = mem_rdata_12[25:0];

  wire [31:0] mem_rdata_13;
  fpga_spram #(
      .MEMDEPTH (128),
      .MEMWIDTH (32),
      .BYTEWIDTH(8),
      .ADDRWIDTH(7),
      .MEMTYPE ("block" )
  )
  mem_13(
      .ram_clk  (clk_13),
      .ram_addr (a_13[6:0]),
      .ram_me   (~cen_13),
      .ram_we   ({4{~wen_13}}),
      .ram_wdata({{6{1'b0}}, d_13[25:0]}),
      .ram_rdata(mem_rdata_13)
  );
  assign q_13[25:0] = mem_rdata_13[25:0];

  wire [31:0] mem_rdata_14;
  fpga_spram #(
      .MEMDEPTH (128),
      .MEMWIDTH (32),
      .BYTEWIDTH(8),
      .ADDRWIDTH(7),
      .MEMTYPE ("block" )
  )
  mem_14(
      .ram_clk  (clk_14),
      .ram_addr (a_14[6:0]),
      .ram_me   (~cen_14),
      .ram_we   ({4{~wen_14}}),
      .ram_wdata({{6{1'b0}}, d_14[25:0]}),
      .ram_rdata(mem_rdata_14)
  );
  assign q_14[25:0] = mem_rdata_14[25:0];

  wire [31:0] mem_rdata_15;
  fpga_spram #(
      .MEMDEPTH (128),
      .MEMWIDTH (32),
      .BYTEWIDTH(8),
      .ADDRWIDTH(7),
      .MEMTYPE ("block" )
  )
  mem_15(
      .ram_clk  (clk_15),
      .ram_addr (a_15[6:0]),
      .ram_me   (~cen_15),
      .ram_we   ({4{~wen_15}}),
      .ram_wdata({{6{1'b0}}, d_15[25:0]}),
      .ram_rdata(mem_rdata_15)
  );
  assign q_15[25:0] = mem_rdata_15[25:0];

  wire [31:0] mem_rdata_16;
  fpga_spram #(
      .MEMDEPTH (128),
      .MEMWIDTH (32),
      .BYTEWIDTH(8),
      .ADDRWIDTH(7),
      .MEMTYPE ("block" )
  )
  mem_16(
      .ram_clk  (clk_16),
      .ram_addr (a_16[6:0]),
      .ram_me   (~cen_16),
      .ram_we   ({4{~wen_16}}),
      .ram_wdata({{6{1'b0}}, d_16[25:0]}),
      .ram_rdata(mem_rdata_16)
  );
  assign q_16[25:0] = mem_rdata_16[25:0];

  wire [71:0] mem_rdata_17;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (72),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_17(
      .ram_clk  (clk_17),
      .ram_addr (a_17[9:0]),
      .ram_me   (~cen_17),
      .ram_we   ({9{~gwen_17}}),
      .ram_wdata({{1{1'b0}}, d_17[70:0]}),
      .ram_rdata(mem_rdata_17)
  );
  assign q_17[70:0] = mem_rdata_17[70:0];

  wire [71:0] mem_rdata_18;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (72),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_18(
      .ram_clk  (clk_18),
      .ram_addr (a_18[9:0]),
      .ram_me   (~cen_18),
      .ram_we   ({9{~gwen_18}}),
      .ram_wdata({{1{1'b0}}, d_18[70:0]}),
      .ram_rdata(mem_rdata_18)
  );
  assign q_18[70:0] = mem_rdata_18[70:0];

  wire [71:0] mem_rdata_19;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (72),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_19(
      .ram_clk  (clk_19),
      .ram_addr (a_19[9:0]),
      .ram_me   (~cen_19),
      .ram_we   ({9{~gwen_19}}),
      .ram_wdata({{1{1'b0}}, d_19[70:0]}),
      .ram_rdata(mem_rdata_19)
  );
  assign q_19[70:0] = mem_rdata_19[70:0];

  wire [71:0] mem_rdata_20;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (72),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_20(
      .ram_clk  (clk_20),
      .ram_addr (a_20[9:0]),
      .ram_me   (~cen_20),
      .ram_we   ({9{~gwen_20}}),
      .ram_wdata({{1{1'b0}}, d_20[70:0]}),
      .ram_rdata(mem_rdata_20)
  );
  assign q_20[70:0] = mem_rdata_20[70:0];

  wire [71:0] mem_rdata_21;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (72),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_21(
      .ram_clk  (clk_21),
      .ram_addr (a_21[9:0]),
      .ram_me   (~cen_21),
      .ram_we   ({9{~gwen_21}}),
      .ram_wdata({{1{1'b0}}, d_21[70:0]}),
      .ram_rdata(mem_rdata_21)
  );
  assign q_21[70:0] = mem_rdata_21[70:0];

  wire [71:0] mem_rdata_22;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (72),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_22(
      .ram_clk  (clk_22),
      .ram_addr (a_22[9:0]),
      .ram_me   (~cen_22),
      .ram_we   ({9{~gwen_22}}),
      .ram_wdata({{1{1'b0}}, d_22[70:0]}),
      .ram_rdata(mem_rdata_22)
  );
  assign q_22[70:0] = mem_rdata_22[70:0];

  wire [71:0] mem_rdata_23;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (72),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_23(
      .ram_clk  (clk_23),
      .ram_addr (a_23[9:0]),
      .ram_me   (~cen_23),
      .ram_we   ({9{~gwen_23}}),
      .ram_wdata({{1{1'b0}}, d_23[70:0]}),
      .ram_rdata(mem_rdata_23)
  );
  assign q_23[70:0] = mem_rdata_23[70:0];

  wire [71:0] mem_rdata_24;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (72),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_24(
      .ram_clk  (clk_24),
      .ram_addr (a_24[9:0]),
      .ram_me   (~cen_24),
      .ram_we   ({9{~gwen_24}}),
      .ram_wdata({{1{1'b0}}, d_24[70:0]}),
      .ram_rdata(mem_rdata_24)
  );
  assign q_24[70:0] = mem_rdata_24[70:0];

  wire [39:0] mem_rdata_25;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (40),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_25(
      .ram_clk  (clk_25),
      .ram_addr (a_25[9:0]),
      .ram_me   (~cen_25),
      .ram_we   ({5{~gwen_25}}),
      .ram_wdata({{2{1'b0}}, d_25[37:0]}),
      .ram_rdata(mem_rdata_25)
  );
  assign q_25[37:0] = mem_rdata_25[37:0];

  wire [39:0] mem_rdata_26;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (40),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_26(
      .ram_clk  (clk_26),
      .ram_addr (a_26[9:0]),
      .ram_me   (~cen_26),
      .ram_we   ({5{~gwen_26}}),
      .ram_wdata({{2{1'b0}}, d_26[37:0]}),
      .ram_rdata(mem_rdata_26)
  );
  assign q_26[37:0] = mem_rdata_26[37:0];

  wire [39:0] mem_rdata_27;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (40),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_27(
      .ram_clk  (clk_27),
      .ram_addr (a_27[9:0]),
      .ram_me   (~cen_27),
      .ram_we   ({5{~gwen_27}}),
      .ram_wdata({{2{1'b0}}, d_27[37:0]}),
      .ram_rdata(mem_rdata_27)
  );
  assign q_27[37:0] = mem_rdata_27[37:0];

  wire [39:0] mem_rdata_28;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (40),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_28(
      .ram_clk  (clk_28),
      .ram_addr (a_28[9:0]),
      .ram_me   (~cen_28),
      .ram_we   ({5{~gwen_28}}),
      .ram_wdata({{2{1'b0}}, d_28[37:0]}),
      .ram_rdata(mem_rdata_28)
  );
  assign q_28[37:0] = mem_rdata_28[37:0];

  wire [39:0] mem_rdata_29;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (40),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_29(
      .ram_clk  (clk_29),
      .ram_addr (a_29[9:0]),
      .ram_me   (~cen_29),
      .ram_we   ({5{~gwen_29}}),
      .ram_wdata({{2{1'b0}}, d_29[37:0]}),
      .ram_rdata(mem_rdata_29)
  );
  assign q_29[37:0] = mem_rdata_29[37:0];

  wire [39:0] mem_rdata_30;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (40),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_30(
      .ram_clk  (clk_30),
      .ram_addr (a_30[9:0]),
      .ram_me   (~cen_30),
      .ram_we   ({5{~gwen_30}}),
      .ram_wdata({{2{1'b0}}, d_30[37:0]}),
      .ram_rdata(mem_rdata_30)
  );
  assign q_30[37:0] = mem_rdata_30[37:0];

  wire [39:0] mem_rdata_31;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (40),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_31(
      .ram_clk  (clk_31),
      .ram_addr (a_31[9:0]),
      .ram_me   (~cen_31),
      .ram_we   ({5{~gwen_31}}),
      .ram_wdata({{2{1'b0}}, d_31[37:0]}),
      .ram_rdata(mem_rdata_31)
  );
  assign q_31[37:0] = mem_rdata_31[37:0];

  wire [39:0] mem_rdata_32;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (40),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_32(
      .ram_clk  (clk_32),
      .ram_addr (a_32[9:0]),
      .ram_me   (~cen_32),
      .ram_we   ({5{~gwen_32}}),
      .ram_wdata({{2{1'b0}}, d_32[37:0]}),
      .ram_rdata(mem_rdata_32)
  );
  assign q_32[37:0] = mem_rdata_32[37:0];

  wire [39:0] mem_rdata_33;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (40),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_33(
      .ram_clk  (clk_33),
      .ram_addr (a_33[9:0]),
      .ram_me   (~cen_33),
      .ram_we   ({5{~gwen_33}}),
      .ram_wdata({{2{1'b0}}, d_33[37:0]}),
      .ram_rdata(mem_rdata_33)
  );
  assign q_33[37:0] = mem_rdata_33[37:0];

  wire [39:0] mem_rdata_34;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (40),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_34(
      .ram_clk  (clk_34),
      .ram_addr (a_34[9:0]),
      .ram_me   (~cen_34),
      .ram_we   ({5{~gwen_34}}),
      .ram_wdata({{2{1'b0}}, d_34[37:0]}),
      .ram_rdata(mem_rdata_34)
  );
  assign q_34[37:0] = mem_rdata_34[37:0];

  wire [39:0] mem_rdata_35;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (40),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_35(
      .ram_clk  (clk_35),
      .ram_addr (a_35[9:0]),
      .ram_me   (~cen_35),
      .ram_we   ({5{~gwen_35}}),
      .ram_wdata({{2{1'b0}}, d_35[37:0]}),
      .ram_rdata(mem_rdata_35)
  );
  assign q_35[37:0] = mem_rdata_35[37:0];

  wire [39:0] mem_rdata_36;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (40),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_36(
      .ram_clk  (clk_36),
      .ram_addr (a_36[9:0]),
      .ram_me   (~cen_36),
      .ram_we   ({5{~gwen_36}}),
      .ram_wdata({{2{1'b0}}, d_36[37:0]}),
      .ram_rdata(mem_rdata_36)
  );
  assign q_36[37:0] = mem_rdata_36[37:0];

  wire [39:0] mem_rdata_37;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (40),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_37(
      .ram_clk  (clk_37),
      .ram_addr (a_37[9:0]),
      .ram_me   (~cen_37),
      .ram_we   ({5{~gwen_37}}),
      .ram_wdata({{2{1'b0}}, d_37[37:0]}),
      .ram_rdata(mem_rdata_37)
  );
  assign q_37[37:0] = mem_rdata_37[37:0];

  wire [39:0] mem_rdata_38;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (40),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_38(
      .ram_clk  (clk_38),
      .ram_addr (a_38[9:0]),
      .ram_me   (~cen_38),
      .ram_we   ({5{~gwen_38}}),
      .ram_wdata({{2{1'b0}}, d_38[37:0]}),
      .ram_rdata(mem_rdata_38)
  );
  assign q_38[37:0] = mem_rdata_38[37:0];

  wire [39:0] mem_rdata_39;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (40),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_39(
      .ram_clk  (clk_39),
      .ram_addr (a_39[9:0]),
      .ram_me   (~cen_39),
      .ram_we   ({5{~gwen_39}}),
      .ram_wdata({{2{1'b0}}, d_39[37:0]}),
      .ram_rdata(mem_rdata_39)
  );
  assign q_39[37:0] = mem_rdata_39[37:0];

  wire [39:0] mem_rdata_40;
  fpga_spram #(
      .MEMDEPTH (1024),
      .MEMWIDTH (40),
      .BYTEWIDTH(8),
      .ADDRWIDTH(10),
      .MEMTYPE ("block" )
  )
  mem_40(
      .ram_clk  (clk_40),
      .ram_addr (a_40[9:0]),
      .ram_me   (~cen_40),
      .ram_we   ({5{~gwen_40}}),
      .ram_wdata({{2{1'b0}}, d_40[37:0]}),
      .ram_rdata(mem_rdata_40)
  );
  assign q_40[37:0] = mem_rdata_40[37:0];

endmodule

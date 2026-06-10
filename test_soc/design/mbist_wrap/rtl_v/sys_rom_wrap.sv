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
    input wire    scan_en
);

wire [2:1] BIST_SETUP_ts1;
wire [0:0] toBist, bistEn;
wire [12:0] romullhde_hvt_8192x72c8_h_inst_0_AY,
            romullhde_hvt_8192x72c8_l_inst_0_AY,
            romullhde_hvt_8192x72c8_h_inst_0_interface_inst_TA,
            romullhde_hvt_8192x72c8_l_inst_0_interface_inst_TA;

wire ijtag_to_sel, BIST_HOLD, BIST_SETUP, BIST_SELECT_TEST_DATA,
     to_controllers_tck, to_interfaces_tck, to_controllers_tck_retime,
     mcp_bounding_to_en, scan_to_en, memory_bypass_to_en, ltest_to_en,
     ENABLE_MEM_RESET, REDUCED_ADDRESS_COUNT, BIST_ASYNC_RESET,
     MEM0_BIST_COLLAR_SI, MEM1_BIST_COLLAR_SI, BIST_SO, BIST_SO_ts1,
     MBISTPG_SO, MBISTPG_DONE, BIST_GO, BIST_GO_ts1, MBISTPG_GO,
     MBISTPG_COMPARE_MISR, BIST_SELECT, BIST_CMP, INCLUDE_MEM_RESULTS_REG,
     BIST_COL_ADD, BIST_COL_ADD_ts1, BIST_COL_ADD_ts2, BIST_ROW_ADD,
     BIST_ROW_ADD_ts1, BIST_ROW_ADD_ts2, BIST_ROW_ADD_ts3, BIST_ROW_ADD_ts4;

endmodule
module hsm_rom_wrap (
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
    input  [13:0]  A_0,
    input         BEN_0,
    input  [2:0]  EMA_0,
    input         PGEN_0,
    input         KEN_0,
    output [38:0] Q_0,

    // Port 1
    input         CLK_1,
    input         CEN_1,
    input  [13:0]  A_1,
    input         BEN_1,
    input  [2:0]  EMA_1,
    input         PGEN_1,
    input         KEN_1,
    output [38:0] Q_1,

    // Port 2
    input         CLK_2,
    input         CEN_2,
    input  [13:0]  A_2,
    input         BEN_2,
    input  [2:0]  EMA_2,
    input         PGEN_2,
    input         KEN_2,
    output [38:0] Q_2,

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
wire [13:0] romullhde_hvt_16384x39c16_h_inst_0_AY,
            romullhde_hvt_16384x39c16_inst_0_AY,
            romullhde_hvt_16384x39c16_h_inst_0_AY,
            romullhde_hvt_16384x39c16_inst_0_interface_inst_TA,
            romullhde_hvt_16384x39c16_inst_0_interface_inst_TA;

endmodule
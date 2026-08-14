//`include "eftu_func_defines.vh"
module eftu_top #(
    parameter EFTU_DMA_CHNL = 16,
    parameter EFTU_TRG_CHNL = 16,
    parameter EFTU_GTOM_CHNL = 64,
    parameter EFTU_CLS_NUM   = 3,
    parameter EFTU_SPE_NUM  = 2,
    parameter EFTU_HRPWM_NUMS = 1,
    parameter EFTU_EAC_NUMS = 1,

    parameter SPE_INST = (EFTU_SPE_NUM==0) ? 2 :EFTU_SPE_NUM,  // default dummy
    parameter HRPWM_INST = (EFTU_HRPWM_NUMS==0) ? 8 :8*EFTU_HRPWM_NUMS, // default dummy
    parameter NUM_THREADS     = 4,          // thread count: 1, 2, or 4
    parameter NUM_TRIGGERS    = 96,         // hardware trigger source count
    parameter NUM_SW_TRIGGERS = 32,         // software trigger source count
    parameter IRAM_SIZE       = 16384,      // instruction RAM size (bytes, power-of-2)
    parameter SRAM_SIZE       = 1024,       // scratchpad SRAM size (bytes, power-of-2)
    parameter [NUM_TRIGGERS+NUM_SW_TRIGGERS-1:0] TRIG_ASYNC = {{NUM_SW_TRIGGERS{1'b0}}, {NUM_TRIGGERS{1'b1}}},
    parameter [NUM_TRIGGERS+NUM_SW_TRIGGERS-1:0] TRIG_PULSE = {{NUM_TRIGGERS+NUM_SW_TRIGGERS}{1'b0}},
    parameter HOST_ADDR_W     = 13,
    parameter IRAM_ADDR_W     = $clog2(IRAM_SIZE),
    parameter SRAM_ADDR_W     = $clog2(SRAM_SIZE)
)
(
    input  wire                         fct_clk_se,
    input  wire                         fct_scan_mode,
    input  wire                         fct_clk,
    input  wire                         fct_se_async,
    output wire [2:0]                   cmu0_cmu_eclk_en,
    input  wire [EFTU_CLS_NUM-1: 0]     fcg_clk,
    input  wire [EFTU_CLS_NUM-1: 0]     fcg_hard_async_reset_b,
    input  wire [EFTU_CLS_NUM-1: 0]     fcg_debug,
    output wire [EFTU_CLS_NUM-1:0] [EFTU_DMA_CHNL -1 : 0]  fcd_eftu_req,
    input  wire [EFTU_CLS_NUM-1:0] [EFTU_DMA_CHNL -1 : 0]  fcd_eftu_done,

    input  wire [EFTU_CLS_NUM-1:0] [12:2] eftu_fcb_addr,
    input  wire [EFTU_CLS_NUM-1:0] [31:0] eftu_fcb_wdata,
    output wire [EFTU_CLS_NUM-1:0] [31:0] eftu_fcb_rdata,
    input  wire [EFTU_CLS_NUM-1:0] [3:0]  eftu_fcb_byte_en,
    input  wire [EFTU_CLS_NUM-1:0]        eftu_fcb_rwb,
    input  wire [EFTU_CLS_NUM-1:0]        eftu_fcb_module_en,
    output wire [EFTU_CLS_NUM-1:0]        eftu_fcb_xfr_err,
    output wire [EFTU_CLS_NUM-1:0]        eftu_fcb_xfr_wait,
    output wire [EFTU_CLS_NUM-1:0] [15 : 0] eftu_tom_irq,
    output wire [EFTU_CLS_NUM-1:0] [7 : 0]  eftu_tim_irq,
    output wire [EFTU_CLS_NUM-1:0] [7 : 0]  eftu_tim_err_irq,
    output wire [EFTU_CLS_NUM-1:0]          eftu_err_irq,
    input  wire [EFTU_CLS_NUM-1:0] [1 : 0]  eftu_glb_enable,
    input  wire [7:0]                       eftu_int_tim,
    output wire [EFTU_TRG_CHNL-1:0]         eftu_trg_out,
    input  wire [EFTU_CLS_NUM-1:0] [7 : 0]  eftu_tim_in,
    input  wire [EFTU_CLS_NUM-1:0] [7 : 0]  eftu_dtm_aux_in,
    output wire [EFTU_CLS_NUM-1:0] [15:0]    eftu_out0,
    output wire [EFTU_CLS_NUM-1:0] [15:0]    eftu_out1,
    output wire [EFTU_CLS_NUM-1:0] [23:0]    eftu_cnt_out0,
    output wire [EFTU_CLS_NUM-1:0] [23:0]    eftu_cnt_out1,
    input  wire [SPE_INST-1:0] [2 : 0]       eftu_spe_bldc_hall, //HALL_C, HALL_B, HALL_A
`ifdef EFTU_HSPWM
    output wire [SPE_INST-1:0] [5 : 0]       eftu_spe_bldc_pwm,
    output wire [SPE_INST-1:0] [1 : 0]       eftu_spe_nipd,
    output wire [SPE_INST-1:0] [1 : 0]       eftu_spe_dir,
    output reg  [EFTU_GTOM_CHNL-1:0]         eftu_gtom_out,
    input  wire                              fcf_ind_torclk,
    output wire [HRPWM_INST-1:0] [4:0]       eftu_hrpwm_cnt,    //Only cluster 0 has hrpwm
    output wire [HRPWM_INST-1:0]             eftu_hrpwm_shut_off,//Only cluster 0 has hrpwm
    output wire [HRPWM_INST-1:0]             eftu_out_h,        //Only cluster 0 has hrpwm
`endif
    //---- Trigger source input ----
    input wire [NUM_TRIGGERS-1:0]      trigger_in,
    input wire [NUM_SW_TRIGGERS-1:0]   sw_trigger_flags,

    //---- External status inputs ----
    input wire [8*32-1:0]              status_regs_sync_in,
    input wire [7:0]                   status_regs_sync_valid_in,
    input wire [31:0]                  status_reg_async_in,

    //---- Instruction RAM interface ----
    output wire                        iram_cs_b,
    output wire                        iram_we_b,
    output wire [IRAM_ADDR_W-1:0]       iram_addr,
    output wire [15:0]                 iram_wdata,
    input  wire [15:0]                 iram_rdata,

    //---- Host FCB Slave Interface ----
    input  wire                        host_fcg_clk,
    input  wire                        host_fcg_hard_async_reset_b,
    input  wire                        host_fcb_module_en,
    input  wire                        host_fcb_rwb,
    input  wire [HOST_ADDR_W-1:0]      host_fcb_addr,
    input  wire [31:0]                 host_fcb_wdata,
    output wire [31:0]                 host_fcb_rdata,
    output wire                        host_fcb_xfr_wait,
    output wire                        host_fcb_xfr_error,

    //---- Global status output ----
    output wire [NUM_THREADS-1:0]      thread_status_run,

    //---- Interrupt output ----
    output wire                        mce_irq,

    //---- External Scratchpad SRAM interface ----
    output wire                        sram_cs_b,
    output wire                        sram_we_b,
    output wire [SRAM_ADDR_W-1:0]      sram_addr,
    output wire [31:0]                 sram_wdata,
    input  wire [31:0]                 sram_rdata
);

localparam EFTU_HAS_CLS1 = (EFTU_CLS_NUM > 1) ? 1'b1 : 1'b0;
localparam EFTU_HAS_CLS2 = (EFTU_CLS_NUM > 2) ? 1'b1 : 1'b0;

wire [EFTU_CLS_NUM-1: 0] [12:2]  cluster_fcb_addr;
wire [EFTU_CLS_NUM-1: 0] [31:0]  cluster_fcb_wdata;
wire [EFTU_CLS_NUM-1: 0] [31:0]  cluster_fcb_rdata;
wire [EFTU_CLS_NUM-1: 0]         cluster_fcb_rwb;
wire [EFTU_CLS_NUM-1: 0]         cluster_fcb_module_en;
wire [EFTU_CLS_NUM-1: 0]         cluster_fcb_xfr_err;
wire [EFTU_CLS_NUM-1: 0]         cluster_fcb_xfr_wait;

wire [EFTU_CLS_NUM-1: 0]         eftu_fcb_align_access;
wire [EFTU_CLS_NUM-1: 0]         eftu_fcb_module_en_aligned;
wire [EFTU_CLS_NUM-1: 0]         eftu_fcb_module_en_unaligned;
wire [EFTU_CLS_NUM-1: 0]         eftu_fcb_xfr_error;

wire [EFTU_TRG_CHNL-1:0]         cluster_trig_out[EFTU_CLS_NUM-1: 0];

//------------------- ocm ----------------------//
wire [4:0]        cluster_ocm_hrpwm_out[EFTU_CLS_NUM-1: 0];
wire [4:0]        cluster_ocm0_hrpwm_out;
wire [EFTU_CLS_NUM-1: 0] cluster_ocm_trig_out;
wire                 cluster_ocm0_trig_out;
wire [31:0]          cluster_ocm_trg_out[EFTU_CLS_NUM-1: 0];

//------------------- GDM ----------------------//
wire [7:0]       eftu_gdm_aux_in[EFTU_CLS_NUM-1: 0];
wire [4:0]       gdm_out_hrpwm[7:0];

wire [EFTU_CLS_NUM-1: 0] cluster_eftu_gdm_psu_out;
wire [EFTU_CLS_NUM-1: 0] cluster_gdm_in0_rise;
wire [EFTU_CLS_NUM-1: 0] cluster_gdm_in0_fall;

//------------------- ICM ----------------------//
wire [9:0]        eftu_icm_ext_cap_src_out[EFTU_CLS_NUM-1: 0];
wire [9:0]        cluster_icm_ext_cap_src_out[EFTU_CLS_NUM-1: 0];
wire [7:0]        cluster_icm_trig_out[EFTU_CLS_NUM-1: 0];
reg  [255:0]      cluster_icm_aux_src;

//------------------- SPE ----------------------//
wire [2:0]        spe_bldc_hall[2*EFTU_CLS_NUM-1:0];
wire [5:0]        spe_bldc_pwm[2*EFTU_CLS_NUM-1:0];
wire [2*EFTU_CLS_NUM-1:0] spe_nipd;
wire [2*EFTU_CLS_NUM-1:0] spe_dir;

//------------------- TBU ----------------------//
wire [26:0]       tbu0_tbu_icm0_time_value0;
wire [23:0]       tbu0_tbu_time_value0;
wire [23:0]       tbu0_tbu_time_value1;
wire [23:0]       tbu0_tbu_time_value2;
wire [23:0]       tbu0_tbu_time_value3;
wire [1:0]        tbu0_tbu_up0;
wire              tbu0_tbu_up1;
wire              tbu0_tbu_up2;
wire              tbu0_tbu_up3;
wire              tbu0_tbu_low_res;
wire              tbu0_tbu_ts_clk;

//------------------- CMU ----------------------//
wire [7:0]        cmu0_cmu_clk_en;
wire              cmu0_clk8_en;

//------------------- TRG ----------------------//
wire [127:0]      eftu_trg_src_merge;

//------------------- MCE ----------------------//
wire              iram_cs;
wire              sram_cs;
wire              iram_we;
wire              sram_we;

//------------------- CCM ----------------------//
wire [6:0]        eftu_trg_out_sel[EFTU_TRG_CHNL-1:0];

wire [26:0]       cluster_icm0_time_value0[EFTU_CLS_NUM-1: 0];
wire [23:0]       cluster_time_value0[EFTU_CLS_NUM-1: 0];
wire [23:0]       cluster_time_value1[EFTU_CLS_NUM-1: 0];
wire [23:0]       cluster_time_value2[EFTU_CLS_NUM-1: 0];
wire [23:0]       cluster_time_value3[EFTU_CLS_NUM-1: 0];
wire [1:0]        cluster_up0[EFTU_CLS_NUM-1: 0];
wire [EFTU_CLS_NUM-1: 0] cluster_up1;
wire [EFTU_CLS_NUM-1: 0] cluster_up2;
wire [EFTU_CLS_NUM-1: 0] cluster_up3;

genvar n;
genvar cls_n;
genvar bit_n;
integer cls_i;

//----------------------------------------------------//
// Iteration
//----------------------------------------------------//
assign cluster_eftu_int_icm = eftu_int_tim;

generate for (cls_n=0; cls_n<EFTU_CLS_NUM; cls_n=cls_n+1) begin : GEN_EFTU_CLS_NUM
    for (bit_n=0; bit_n<8; bit_n=bit_n+1) begin
        fc_std_dffn_sync #(.SDEPTH(2), .RST_VAL(0)) eftu_gdm_in_sync (
            .clk(fcg_clk[cls_n]),
            .rst_b(fcg_hard_async_reset_b[cls_n]),
            .async(eftu_dtm_aux_in[cls_n][bit_n]),
            .syncd(eftu_gdm_aux_in[cls_n][bit_n])
        );
    end

    assign eftu_fcb_align_access[cls_n]      = &eftu_fcb_byte_en[cls_n];
    assign eftu_fcb_module_en_aligned[cls_n] =  eftu_fcb_align_access[cls_n] & eftu_fcb_module_en[cls_n];
    assign eftu_fcb_module_en_unaligned[cls_n] = ~eftu_fcb_align_access[cls_n] & eftu_fcb_module_en[cls_n];
    assign eftu_fcb_xfr_err[cls_n]           = eftu_fcb_xfr_error[cls_n] |eftu_fcb_module_en_unaligned[cls_n];
end
endgenerate

endmodule
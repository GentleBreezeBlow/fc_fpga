//`include "eftu_func_defines.vh"
module eftu_top #(
    parameter MASTER_LENGTH =32,
    parameter [31:0] MASTER_ID_ISCORE =32'h0F0F0F0F,
    parameter MASTERID_LENGTH =$clog2(MASTER_LENGTH),
    parameter CORE_NUMS = MASTER_LENGTH/2,
    parameter EFTU_DMA_CHNL =6,
    parameter EFTU_CLS_NUM =3,
    parameter SPE_INST = 2,
    parameter EFTU_HRPWM_NUMS = 1
)
(
input  wire                fct_clk_se,
input  wire                fct_scan_mode,
input  wire                fct_clk,
input  wire                fct_se_async,
input  wire [EFTU_CLS_NUM-1: 0]  fcg_clk,
input  wire [EFTU_CLS_NUM-1: 0]  fcg_hard_async_reset_b,
input  wire [CORE_NUMS-1: 0]     fcg_debug,
output wire [2 :0]               cmu0_cmu_eclk_en,

input  wire [12:2]                eftu0_fcb_addr,
input  wire [31:0]                eftu0_fcb_wdata,
output wire [31:0]                eftu0_fcb_rdata,
input  wire [3 :0]                eftu0_fcb_byte_en,
input  wire [MASTERID_LENGTH-1 :0] eftu0_fcb_mst_id,
input  wire                       eftu0_fcb_rwb,
input  wire                       eftu0_fcb_module_en,
output wire                       eftu0_fcb_xfr_err,
output wire                       eftu0_fcb_xfr_wait,
output wire [EFTU_DMA_CHNL -1 : 0] fcd_eftu0_req,
input  wire [EFTU_DMA_CHNL -1 : 0] fcd_eftu0_done,
output wire [16*CORE_NUMS -1 : 0]  eftu0_tom_irq,
output wire [8*CORE_NUMS  -1 : 0]  eftu0_tim_irq,
output wire [8*CORE_NUMS  -1 : 0]  eftu0_tim_err_irq,
output wire [CORE_NUMS    -1 : 0]  eftu0_err_irq,
input  wire [5 :0]                eftu_glb_enable,
input  wire [7 :0]                eftu_int_tim,
output wire [7 :0]                eftu_trg_out,
input  wire [7 :0]                eftu0_tim_in,
input  wire [7 :0]                eftu0_dtm_aux_in,
output wire [31:0]                eftu0_out_s,     //After Swap
output wire [15:0]                eftu0_out0,
output wire [15:0]                eftu0_out1,
output wire [23:0]                eftu0_cnt_out0,
output wire [23:0]                eftu0_cnt_out1,
input  wire [2 :0]                eftu0_spe0_bldc_hall, //HALL_C, HALL_B, HALL_A
output wire [5 :0]                eftu0_spe0_bldc_pwm,
input  wire [2 :0]                eftu0_spe1_bldc_hall, //HALL_C, HALL_B, HALL_A
output wire [5 :0]                eftu0_spe1_bldc_pwm,
output wire [SPE_INST-1 :0]        eftu0_spe_nipd,
output wire [SPE_INST-1 :0]        eftu0_spe_dir,

`ifdef EFTU_HAS_CLS1
input  wire [12:2]                eftu1_fcb_addr,
input  wire [31:0]                eftu1_fcb_wdata,
output wire [31:0]                eftu1_fcb_rdata,
input  wire [3 :0]                eftu1_fcb_byte_en,
input  wire [MASTERID_LENGTH-1 :0] eftu1_fcb_mst_id,
input  wire                       eftu1_fcb_rwb,
input  wire                       eftu1_fcb_module_en,
output wire                       eftu1_fcb_xfr_err,
output wire                       eftu1_fcb_xfr_wait,
output wire [EFTU_DMA_CHNL -1 : 0] fcd_eftu1_req,
input  wire [EFTU_DMA_CHNL -1 : 0] fcd_eftu1_done,
output wire [16*CORE_NUMS -1 : 0]  eftu1_tom_irq,
output wire [8*CORE_NUMS  -1 : 0]  eftu1_tim_irq,
output wire [8*CORE_NUMS  -1 : 0]  eftu1_tim_err_irq,
output wire [CORE_NUMS    -1 : 0]  eftu1_err_irq,
input  wire [7 :0]                eftu1_tim_in,
input  wire [7 :0]                eftu1_dtm_aux_in,
output wire [31:0]                eftu1_out_s,     //After Swap
output wire [15:0]                eftu1_out0,
output wire [15:0]                eftu1_out1,
output wire [23:0]                eftu1_cnt_out0,
output wire [23:0]                eftu1_cnt_out1,
input  wire [2 :0]                eftu1_spe0_bldc_hall, //HALL_C, HALL_B, HALL_A
output wire [5 :0]                eftu1_spe0_bldc_pwm,
input  wire [2 :0]                eftu1_spe1_bldc_hall, //HALL_C, HALL_B, HALL_A
output wire [5 :0]                eftu1_spe1_bldc_pwm,
output wire [SPE_INST-1 :0]        eftu1_spe_nipd,
output wire [SPE_INST-1 :0]        eftu1_spe_dir,
`endif

`ifdef EFTU_HAS_CLS2
input  wire [12:2]                eftu2_fcb_addr,
input  wire [31:0]                eftu2_fcb_wdata,
output wire [31:0]                eftu2_fcb_rdata,
input  wire [3 :0]                eftu2_fcb_byte_en,
input  wire [MASTERID_LENGTH-1 :0] eftu2_fcb_mst_id,
input  wire                       eftu2_fcb_rwb,
input  wire                       eftu2_fcb_module_en,
output wire                       eftu2_fcb_xfr_err,
output wire                       eftu2_fcb_xfr_wait,
output wire [EFTU_DMA_CHNL -1 : 0] fcd_eftu2_req,
input  wire [EFTU_DMA_CHNL -1 : 0] fcd_eftu2_done,
output wire [16*CORE_NUMS -1 : 0]  eftu2_tom_irq,
output wire [8*CORE_NUMS  -1 : 0]  eftu2_tim_irq,
output wire [8*CORE_NUMS  -1 : 0]  eftu2_tim_err_irq,
output wire [CORE_NUMS    -1 : 0]  eftu2_err_irq,
input  wire [7 :0]                eftu2_tim_in,
input  wire [7 :0]                eftu2_dtm_aux_in,
output wire [31:0]                eftu2_out_s,     //After Swap
output wire [15:0]                eftu2_out0,
output wire [15:0]                eftu2_out1,
output wire [23:0]                eftu2_cnt_out0,
output wire [23:0]                eftu2_cnt_out1,
input  wire [2 :0]                eftu2_spe0_bldc_hall, //HALL_C, HALL_B, HALL_A
output wire [5 :0]                eftu2_spe0_bldc_pwm,
input  wire [2 :0]                eftu2_spe1_bldc_hall, //HALL_C, HALL_B, HALL_A
output wire [5 :0]                eftu2_spe1_bldc_pwm,
output wire [SPE_INST-1 :0]        eftu2_spe_nipd,
output wire [SPE_INST-1 :0]        eftu2_spe_dir,
`endif

`ifdef EFTU_HAS_EAC
input  wire                       fcf_ind_tcrclk,
`endif

`ifdef EFTU_HAS_HRPWM
output wire [39:0]                eftu0_hrpwm_cnt,    //Only cluster 0 has hrpwm
output wire [7 :0]                eftu0_hrpwm_shut_off,//Only cluster 0 has hrpwm
output wire [7 :0]                eftu0_out_h,        //Only cluster 0 has hrpwm
`endif

output reg [15:0]                 eftu_gtom_out
);

wire [12:2] cluster_fcb_addr[EFTU_CLS_NUM-1: 0];
wire [31:0] cluster_fcb_wdata[EFTU_CLS_NUM-1: 0];
wire [31:0] cluster_fcb_rdata[EFTU_CLS_NUM-1: 0];
wire [3 :0] cluster_fcb_byte_en[EFTU_CLS_NUM-1: 0];
wire [MASTERID_LENGTH-1 :0] cluster_fcb_mst_id[EFTU_CLS_NUM-1: 0];
wire [EFTU_CLS_NUM-1: 0]    cluster_fcb_rwb;
wire [EFTU_CLS_NUM-1: 0]    cluster_fcb_module_en;

endmodule
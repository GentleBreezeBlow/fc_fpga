module ETHOSU65_1
import ethosu65_pkg::*;
import ethosu65_cc_reg_pkg::*;
import ethosu65_cc_cmd_parser_pkg::*;
import ethosu65_cc_tsu_pkg::*;
import ethosu65_dma_pkg::*;
import ethosu65_mac_pkg::*;
import ethosu65_wd_pkg::*;
#(
parameter npu_config_t CFG  = BUILD_CFG(1, 256),
parameter NUM_CH            = AXI_NUM_RD_CH(CFG)
)(
input wire                      CLK,
input wire                      nRESET,
input wire                      nMBISTRESET,
input wire                      PORPL,
input wire                      PORSL,
output wire                     IRQ,
output wire                     CLKQACTIVE,
input  wire                     CLKREQn,
output wire                     CLKACCEPTn,
output wire                     CLKDENY,
input  wire                     PWRQACTIVE,
input  wire                     PWRREQn,
output wire                     PWRACCEPTn,
output wire                     PWRDENY,
input  wire                     AWAKEUPM0,
output wire                     ACLKENM0,
output wire [7:0]               AWVALIDM0,
output wire [39:0]              AWADDRM0
);

endmodule
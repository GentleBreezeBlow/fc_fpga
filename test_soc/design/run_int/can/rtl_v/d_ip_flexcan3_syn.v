// +FHDR------------------------------------------------------------------------
// Copyright (c) 2009 Freescale Semiconductor, Inc. All rights reserved
// Freescale Confidential Proprietary
// -----------------------------------------------------------------------------
// FILE NAME        : d_ip_flexcan3_syn.v
// TYPE             : module
// DEPARTMENT       : Brazil Semiconductor Technology Center - BSTC
// AUTHOR           : Gustavo Naspolini, Frank Behrens, Marcelo Marinho
// AUTHOR'S EMAIL   : r58540@freescale.com
//                  : rfb002@freescale.com
//                  : b18958@freescale.com
// -----------------------------------------------------------------------------
// Release history
// VERSION  DATE        AUTHOR      DESCRIPTION
// 1.78     07 Dec 2018 M Marinho    Replaced CDC logic by standard CDC structures
//                                   Removed ipt_test_mode input.
// 1.77     25 Sep 2017 F Orlando    Changed ERX_FIFO_ADDR
// 1.76     23 Sep 2017 F Orlando    Changed SMB0_TIMESTAMP_ADDR
// 1.75     22 Sep 2017 F Orlando    Renamed internal parameter ENHANCE_MB_MEM
// 1.74     12 Sep 2017 F Orlando    Changed ERX_FIFO_DELTA
// 1.72     05 Sep 2017 F Orlando    Changed NUMBER_OF_MB to 64
// 1.69     04 Sep 2017 F Orlando    Renamed outputs
// 1.68     25 Aug 2017 F Orlando    New outputs:
//                                   - ipi_int_erfufw
//                                   - ipi_int_erfovf
//                                   - ipi_int_erfwm
//                                   - ipi_int_erfda
// 1.67     24 Aug 2017 F Orlando    Added signal biu_ctrl2_bte_ff and updated
//                                   TDCCOFF_SZ
// 1.66     22 Aug 2017 M Marinho    Updated interface for new ERX FIFO and bit
//                                   bit timing expansion.
// 181      30 Jun 2017 F Orlando    New parameter ENHANCE_MB_MEM
// 180      30 May 2017 F Orlando    Added localparam TDCCOFF_SZ and 2 new inputs:
//                                   -ipg_hard_async_reset_ts_b
//                                   -ipg_clk_ts
// 179      27 Apr 2017 F Orlando    Included input biu_tdccr_tdmdis_ff to can_pe
// 178      20 Apr 2017 F Orlando    Disabled parameter TIME_STAMP_EN
// 177      20 Apr 2017 F Orlando    Created parameter TIME_STAMP_EN
// -----------------------------------------------------------------------------
// TASD_RST_VALUE          >= 0 <=25  : Tx Arbitration start delay in 5'd16
// LME                     0,1        : Legacy Mode Enable          : 1'b1
// EME                     0,1        : Enhanced Mode Enable        : 1'b0
// MBF_EN                  0,1        : If asserted, the module will
//                                     implement 4 ID filters for
//                                     each MailBox
// MBFM_EN                 0,1        : MailBox Individual Filter
//                                     Masks Enable                : 1'b0
// RXFIFO_EN               0,1        : Rx FIFO enable              : 1'b0
// NUMBER_OF_RXFIFO_FILTERS 0,64,128  : Number of Rx FIFO ID Filters: 8'd0
// TXFIFO_DEPTH            0,4,8,12,16: Tx FIFO dept               : 5'd0
// -----------------------------------------------------------------------------
// REUSE ISSUES :
// Reset Strategy          : Global asynchronous reset
// Clock Domains           : System clock (ipg_clk, ipg_clk_s, ipg_clk_chi)
//                           CAN serial clock (ipg_clk_pe, ipg_clk_pe_nogate)
// Critical Timing         : TBD
// Test Features           : Scan based testing
// Asynchronous I/F        : Async interface between ipg_clk and ipg_clk_pe
// Scan Methodology        : Full scan
// Instantiations          : flexcan3_chi, can_pe
// Synthesizable (y/n)     : Yes
// Other                   :
// -FHDR------------------------------------------------------------------------

module d_ip_flexcan3_syn (
// Outputs
    can_addr,
    can_byte_7_0,
    can_byte_15_8,
    can_byte_23_16,
    can_byte_31_24,
    can_byte_39_32,
    can_byte_47_40,
    can_byte_55_48,
    can_byte_63_56,
    can_cen_b,
    can_clk_src,
    can_lpm_ack,
    can_rwb,
    can_slf_wak,
    can_wak_int,
    can_wak_src,
    can_wdb,
    can_wrb,
    ipd_req,
    ipg_enable_clk_chi,
    ipg_enable_clk_pe,
    ipg_stop_ack,
    ipi_int_error_or_delay,
    ipi_int_or_delay,
    ipi_int_busoff,
    ipi_int_error,
    ipi_int_mb,
    ipi_int_mbor,
    ipi_int_rx_warning,
    ipi_int_tx_warning,
    ipi_int_wakein,
    ipi_int_wake_match,
    ipi_int_wake_to,
    ipi_int_ce,
    ipi_int_nceha,
    ipi_int_ncefa,
    ipi_int_timer_wrap,
    ipp_do_cantx,
    ips_rdata,
    ips_xfr_err,
    ips_xfr_wait,
    ecc_corr_err_det_flag,
    ecc_uncorr_err_det_flag,
    ecc_err_addr,
    ipi_int_busoff_done,
    ipi_int_error_fd,
    ipi_int_erfufw,
    ipi_int_erfovf,
    ipi_int_erfwm,
    ipi_int_erfda,
    //add by jemmy
    can_req,
    can_id,
    can_mb_status,
    ipi_int_efufw,
    ipi_int_efovf,
    ipi_int_efwm,
    ipi_int_efda,
    ipi_int_efrov,
    ipi_int_efwov,
    ipd_req_tx,
    // Inputs
    flxram_rdb,
    gfl_wak_async_req,
    gfl_wak_sync_req_b,
    ipd_done,
    ipg_clk,
    ipg_clk_chi,
    ipg_clk_pe,
    ipg_clk_pe_nogate,
    ipg_clk_s,
    ipg_clk_ts,
    ipg_debug,
    ipg_doze,
    ipg_hard_async_reset_b,
    ipg_hard_async_reset_pe_b,
    ipg_hard_async_reset_ts_b,
    ipg_soft_reset_b,
    ipg_stop,
    ipp_ind_canrx,
    //add by Eric
    can_rx_trgsel,
    ips_addr,
    ips_byte_7_0,
    ips_byte_15_8,
    ips_byte_23_16,
    ips_byte_31_24,
    ips_module_en,
    ips_rwb,
    ips_supervisor_access,
    ips_test_access,
    ips_wdata,
    ipt_se_async,
    tmr_tick_ext,
    timestamp_base,
    dma_fcd_done,
    fd_enable_plug,
    //add by jemmy, come from ifr
    erx_fix_en
);

// -----------------------------------------------------------------------------
// INTEGRATION PARAMETERS
// -----------------------------------------------------------------------------
parameter [7:0] NUMBER_OF_MB      = 8'd64;  // Number of Message Buffers
parameter [0:0] MDIS_RST_VALUE    = 1'b0;   // Reset value of MDIS bit in MCR
parameter [0:0] LOCK_IRMQ         = 1'b0;   // If asserted, locks BCC to reset value
                                            // ('0')
parameter [7:0] ADDR_SIZE         = 8'd14;  // Address bus width (has to be at least 14)
parameter [0:0] IRMQ_EN           = 1'b1;   // If asserted, the module will implement an
                                            // individual Rx Mask for each MailBox
parameter [4:0] TASD_RST_VALUE    = 5'd16;  // Tx Arbitration start delay in CAN bits
parameter [0:0] ECC_EN            = 1'b0;   // ECC feature: To enable make ECC_EN=1
parameter [0:0] DMA_EN            = 1'b0;   // DMA feature: To enable make DMA_EN=1
parameter [0:0] PNET_EN            = 1'b0;  // PNET feature: To enable make PNET_EN=1
parameter [0:0] ENHANCE_MB_MEM     = 1'b0;  // Enhanced MB memory increase
parameter [0:0] ERX_FIFO_EN       = 1'b0;   // Enhanced Rx FIFO enable
parameter [7:0] ERX_FIFO_FLT_ELEM  = 128;   // Number of filters of Enhanced Rx
                                            // FIFO
parameter [5:0] ERX_FIFO_SIZE      = 32;    // Enhanced RX FIFO size
parameter [0:0] CIA_BIT_TIMING     = 1'b0;   // Enable enhanced bit timing
parameter [0:0] TIMER_WRAP_EN     = 1'b0;   // Timer wrap around  GM 7.2.3.B.3, Silvaco #49
parameter [0:0] GATE_FEN           = 1'b1;
parameter [3:0] GATE_BUFFER_SIZE   = 4'h4;
parameter [0:0] EXT_FIFO_EN        = 1'b0;   // Extends FIFO enable

// -----------------------------------------------------------------------------
// INTERNAL PARAMETER
// -----------------------------------------------------------------------------
localparam [6:0] SRAM_DATA_WIDTH = (ECC_EN ? 7'd104 :
                                            7'd64); //RAM read data width
localparam [2:0] TDCCOFF_SZ = CIA_BIT_TIMING ? 3'd7 : 3'd5;      // TDC offset size

//Enhanced mode parameters
localparam [0:0] LME              = 1'b1; // Legacy Mode Enable
localparam [0:0] EN_MB_MEM = FD_EN & (NUMBER_OF_MB == 8'd128 ) & ENHANCE_MB_MEM;
localparam       SDEPTH      = 2;    // CDC Synchronizer depth

// -----------------------------------------------------------------------------
// Port Declarations
// -----------------------------------------------------------------------------
// OUTPUTS
// -----------------------------------------------------------------------------
output reg      ipi_int_or_delay;
output reg      ipi_int_error_or_delay;
output [13:0]   can_addr;               // Address to Message Buffer RAM
output          can_byte_7_0;           // RAM bus byte enable [ 7:0]
output          can_byte_15_8;          // RAM bus byte enable [15:8]
output          can_byte_23_16;         // RAM bus byte enable [23:16]
output          can_byte_31_24;         // RAM bus byte enable [31:24]
output          can_byte_39_32;         // RAM bus byte enable [39:32]
output          can_byte_47_40;         // RAM bus byte enable [47:40]
output          can_byte_55_48;         // RAM bus byte enable [55:48]
output          can_byte_63_56;         // RAM bus byte enable [63:56]
output          can_cen_b;              // RAM chip enable
output          can_clk_src;            // Selects CAN clock source
output          can_lpm_ack;            // Low power mode (stop, doze, sleep)
output          can_rwb;                // RAM rd/wr_b signal
output          can_slf_wak;            // Enable wake-up on CAN bus activity
output          can_wak_int;            // Unmasked wake-up interrupt flag
output          can_wak_src;            // Selects filt/unfilt Rx for wake-up
output [SRAM_DATA_WIDTH-7'd1:0] can_wdb; // RAM write data bus
output          can_wrb;                // RAM wr/rd_b signal
output          ipd_req;                // DMA request signal
output          ipg_enable_clk_chi;     // Request to gate ipg_clk_chi
output          ipg_enable_clk_pe;      // Request to gate ipg_clk_pe
output          ipg_stop_ack;           // Acknowledge to Stop mode
output          ipi_int_busoff;         // Interrupt from busoff
output          ipi_int_error;          // Interrupt from CAN line error
output [NUMBER_OF_MB - 8'd1:0] ipi_int_mb; // Interrupt lines up to 128
output          ipi_int_mbor;           // Ored interrupts from ipi_int_MB
output          ipi_int_rx_warning;     // Rx warning Interrupt
output          ipi_int_tx_warning;     // Tx warning Interrupt
output          ipi_int_wakein;         // Interrupt from wake up
output          ipi_int_wake_match;     // Interrupt from match in PN
output          ipi_int_wake_to;        // Interrupt from timeout in PN
output          ipi_int_ce;             // Correctable error interrupt
output          ipi_int_nceha;          // Non correctable error int host
output          ipi_int_ncefa;          // Non correctable error int internal
output          ipi_int_timer_wrap;     // Timer wraparound int // Silvaco #49
output          ipp_do_cantx;           // CAN transmit pin TX
output [31:0]   ips_rdata;             // IP bus read data bus
output          ips_xfr_err;            // IP bus transfer error
output          ips_xfr_wait;           // IP bus transfer wait
output          ecc_corr_err_det_flag;  // ECC correctable error flag
output          ecc_uncorr_err_det_flag;// ECC uncorrectable error flag
output [31:0]   ecc_err_addr;          // BCC error address for 32-bit accesses
output          ipi_int_busoff_done;    // Busoff done interrupt
output          ipi_int_error_fd;       // FD error interrupt
output          ipi_int_erfufw;         // ERX FIFO Underflow interrupt
output          ipi_int_erfovf;         // ERX FIFO Overflow interrupt
output          ipi_int_erfwm;         // ERX FIFO Water marker interrupt
output          ipi_int_erfda;         // ERX FIFO Data available interrupt
output [31:0]   can_id;
output [NUMBER_OF_MB-1:0] can_mb_status;
output          ipi_int_efufw;         // Extends FIFO Underflow interrupt
output          ipi_int_efovf;         // Extends FIFO Overflow interrupt
output          ipi_int_efwm;          // Extends FIFO water marker overwrap interrupt
output          ipi_int_efda;          // Extends FIFO data available interrupt
output          ipi_int_efrov;
output          ipi_int_efwov;
output          ipd_req_tx;             // last mb dma request

// -----------------------------------------------------------------------------
// INPUTS
// -----------------------------------------------------------------------------
input [SRAM_DATA_WIDTH-7'd1:0] flxram_rdb; // RAM read data bus
input          gfl_wak_async_req;      // Wake-up request via asynchronous path
input          gfl_wak_sync_req_b;     // Wake-up request via synchronous path
input          ipd_done;               // DMA done signal
input          ipg_clk;                // Global clock
input          ipg_clk_chi;
input          ipg_clk_pe;
input          ipg_clk_pe_nogate;
input          ipg_clk_s;
input          ipg_clk_ts;
input          ipg_debug;
input          ipg_doze;
input          ipg_hard_async_reset_b;
input          ipg_hard_async_reset_pe_b;
input          ipg_hard_async_reset_ts_b;
input          ipg_soft_reset_b;
input          ipg_stop;
input          ipp_ind_canrx;
input          can_rx_trgsel;
input [13:0]   ips_addr;
input [7:0]    ips_byte_7_0;
input [7:0]    ips_byte_15_8;
input [7:0]    ips_byte_23_16;
input [7:0]    ips_byte_31_24;
input          ips_module_en;
input          ips_rwb;
input          ips_supervisor_access;
input          ips_test_access;
input [31:0]   ips_wdata;
input          ipt_se_async;
input          tmr_tick_ext;
input [31:0]   timestamp_base;
input          dma_fcd_done;
input          fd_enable_plug;
input          erx_fix_en;

endmodule
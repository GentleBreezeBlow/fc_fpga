//===========================================================================
// run_int.sv — Run Interrupt Controller + Peripherals (12 UARTs, 3 SPIs)
//===========================================================================
module run_int #(
  parameter N_UART = 12
) (
  input  wire        clk,
  input  wire        rst_n,
  output wire [31:0] irq,

  // ---- UART array ports ----
  input  wire [N_UART-1:0]    uart_rx,
  output wire [N_UART-1:0]    uart_tx,
  input  wire [N_UART*8-1:0]  uart_tx_data,
  input  wire [N_UART-1:0]    uart_tx_valid,
  output wire [N_UART-1:0]    uart_tx_ready,
  output wire [N_UART*8-1:0]  uart_rx_data,
  output wire [N_UART-1:0]    uart_rx_valid,

  // ---- SPI 0 ----
  input  wire        spi0_miso,
  output wire        spi0_mosi,
  output wire        spi0_sclk,
  output wire        spi0_cs_n,

  // ---- SPI 1 ----
  input  wire        spi1_miso,
  output wire        spi1_mosi,
  output wire        spi1_sclk,
  output wire        spi1_cs_n,

  // ---- SPI 2 ----
  input  wire        spi2_miso,
  output wire        spi2_mosi,
  output wire        spi2_sclk,
  output wire        spi2_cs_n







//////











);

`ifdef FPGA_SYN
  wire run_clk_buf;
  BUFG bufg_run_int (.O(run_clk_buf), .I(clk));
`endif
  //===========================================================
  // Internal signals
  //===========================================================
  wire [31:0] cpu_instr_addr, cpu_instr_data;
  wire        cpu_fetch_en, cpu_stall_req, cpu_stall_ack;

  wire [2:0]  spi_start, spi_done;
  wire [7:0]  spi_tx_data [2:0];
  wire [7:0]  spi_rx_data [2:0];
  wire [2:0]  spi_cpol, spi_cpha;

  //===========================================================
  // CPU Core — main processor
  //===========================================================
  cpu_core #(
    .DATA_WIDTH (32),
    .ADDR_WIDTH (32)
  ) u_cpu (
    .clk        (clk),
    .rst_n      (rst_n),
    .fetch_en   (cpu_fetch_en),
    .instr_addr (cpu_instr_addr),
    .instr_data (cpu_instr_data),
    .stall_req  (cpu_stall_req),
    .stall_ack  (cpu_stall_ack),
    .*
  );

  //===========================================================
  // SPI Controller 0
  //===========================================================
  spi_ctrl #(
    .DATA_WIDTH (8),
    .CLK_DIV    (4)
  ) spi0 (
    .clk      (clk),
    .rst_n    (rst_n),
    .start    (spi_start[0]),
    .tx_data  (spi_tx_data[0]),
    .rx_data  (spi_rx_data[0]),
    .done     (spi_done[0]),
    .miso     (spi0_miso),
    .mosi     (spi0_mosi),
    .sclk     (spi0_sclk),
    .cs_n     (spi0_cs_n),
    .cpol     (spi_cpol[0]),
    .cpha     (spi_cpha[0]),
    .*
  );

  //===========================================================
  // SPI Controller 1
  //===========================================================
`ifdef FPGA_SYN
assign spi_rx_data[1] = 'b0;
assign spi_done[1] = 'b0;
assign spi1_mosi = 'b0;
assign spi1_sclk = 'b0;
assign spi1_cs_n = 'b0;
`else
spi_ctrl #(
    .DATA_WIDTH (8),
    .CLK_DIV    (4)
  ) spi1 (
    .clk      (clk),
    .rst_n    (rst_n),
    .start    (spi_start[1]),
    .tx_data  (spi_tx_data[1]),
    .rx_data  (spi_rx_data[1]),
    .done     (spi_done[1]),
    .miso     (spi1_miso),
    .mosi     (spi1_mosi),
    .sclk     (spi1_sclk),
    .cs_n     (spi1_cs_n),
    .cpol     (spi_cpol[1]),
    .cpha     (spi_cpha[1]),
    .*
  );
`endif

`ifdef FPGA_SYN
  wire [31:0] debug_run_irq;
  ila_run_int debug_ila (.clk(clk), .probe0(irq));
`endif
  //===========================================================
  // SPI Controller 2
  //===========================================================
`ifdef FPGA_SYN
assign spi_rx_data[2] = 'b0;
assign spi_done[2] = 'b0;
assign spi2_mosi = 'b0;
assign spi2_sclk = 'b0;
assign spi2_cs_n = 'b0;
`else
spi_ctrl #(
    .DATA_WIDTH (8),
    .CLK_DIV    (4)
  ) spi2 (
    .clk      (clk),
    .rst_n    (rst_n),
    .start    (spi_start[2]),
    .tx_data  (spi_tx_data[2]),
    .rx_data  (spi_rx_data[2]),
    .done     (spi_done[2]),
    .miso     (spi2_miso),
    .mosi     (spi2_mosi),
    .sclk     (spi2_sclk),
    .cs_n     (spi2_cs_n),
    .cpol     (spi_cpol[2]),
    .cpha     (spi_cpha[2]),
    .*
  );
`endif

  //===========================================================
  // UART Array — 12 instances via generate loop
  //===========================================================
  genvar uart_idx;
  generate
    for (uart_idx = 0; uart_idx < N_UART; uart_idx = uart_idx + 1) begin : uart_gen
      uart_top #(
        .CLK_FREQ  (50_000_000),
        .BAUD_RATE (115200)
      ) u_uart (
        .clk      (clk),
        .rst_n    (rst_n),
        .rx       (uart_rx[uart_idx]),
        .tx       (uart_tx[uart_idx]),
        .tx_data  (uart_tx_data[uart_idx*8 +: 8]),
        .tx_valid (uart_tx_valid[uart_idx]),
        .tx_ready (uart_tx_ready[uart_idx]),
        .rx_data  (uart_rx_data[uart_idx*8 +: 8]),
        .rx_valid (uart_rx_valid[uart_idx]),
        .cts      (1'b0),      // No flow control in run domain
        .rts      (),          // Not connected at this level
        .*
      );
    end
  endgenerate

  // IRQ — aggregate interrupts
  assign irq = {17'b0, uart_rx_valid[0], uart_tx_ready[0], |spi_done, cpu_stall_ack, 8'b0};

  // Tie-offs
  assign cpu_fetch_en    = 1'b1;
  assign cpu_instr_addr  = 32'h0000_1000;
  assign cpu_stall_req   = 1'b0;
  assign spi_start       = 3'b000;
  assign spi_tx_data[0]  = 8'h00;
  assign spi_tx_data[1]  = 8'h00;
  assign spi_tx_data[2]  = 8'h00;
  assign spi_cpol        = 3'b000;
  assign spi_cpha        = 3'b000;



`ifdef FPGA_SYN
assign ADR_out = 'b0;
assign D_out = 'b0;
assign WEM_out = 'b0;
assign cs_b_out = 'b0;
assign WE_b_out = 'b0;
assign clk_out = 'b0;
assign Q_out = 'b0;
assign mon_err = 'b0;
`else
sram_decoder_mchk #(
  .LP_EN(1))  // default is LP_EN=0, set to 1 for run_int,timing is worse
 sram_decoder
(
  .ADR_out      (ADR_out),
  .D_out        (D_out),
  .WEM_out      (WEM_out),
  .cs_b_out     (cs_b_out),
  .WE_b_out     (WE_b_out), 
  .clk_out       (clk_out),
  .reset_b       (reset_b),
  .clk_in        (clk_in),
  .CS            (CS),
  .WE_in         (WE_in),
  .Q_out         (Q_out),
  .q_in          (q_in),
  .D_in          (D_in),
  .WEM_in        (WEM_in),
  .Addr          (Addr),
  .mon_err_inj   (mon_err_inj),
  .mon_err       (mon_err)
);
`endif

// can0 instance start
`ifdef FPGA_SYN
assign {
                            can0_can_addr_13_nc,                // [13]
                            can0_can_addr[12:3],                // [12:3]
                            can0_can_addr_2_0_nc[2:0]           // [2:0]
                        } = 'b0;
assign can0_can_byte_15_8 = 'b0;
assign can0_can_byte_23_16 = 'b0;
assign can0_can_byte_31_24 = 'b0;
assign can0_can_byte_39_32 = 'b0;
assign can0_can_byte_47_40 = 'b0;
assign can0_can_byte_55_48 = 'b0;
assign can0_can_byte_63_56 = 'b0;
assign can0_can_byte_7_0 = 'b0;
assign can0_can_cen_b = 1'b1;
assign can0_can_clk_src = 'b0;
assign can0_can_id_31_0_nc[31:0] = 'b0;
assign can0_can_lpm_ack_0_nc = 'b0;
assign can0_can_mb_status_127_0_nc[127:0] = 'b0;
assign can0_can_rwb = 'b0;
assign can0_can_slf_wak_0_nc = 'b0;
assign can0_can_wak_int_0_nc = 'b0;
assign can0_can_wak_src_0_nc = 'b0;
assign can0_can_wdb[103:0] = 'b0;
assign can0_can_wrb_0_nc = 'b0;
assign can0_ecc_corr_err_det_flag_0_nc = 'b0;
assign can0_ecc_err_addr_31_0_nc[31:0] = 'b0;
assign can0_ecc_uncorr_err_det_flag_0_nc = 'b0;
assign can0_ipd_req = 'b0;
assign can0_ipd_req_tx_0_nc = 'b0;
assign can0_ipg_enable_clk_chi = 'b0;
assign can0_ipg_enable_clk_pe = 'b0;
assign can0_ipg_stop_ack = 'b0;
assign can0_ipi_int_busoff_0_nc = 'b0;
assign can0_ipi_int_busoff_done_0_nc = 'b0;
assign can0_ipi_int_ce_0_nc = 'b0;
assign can0_ipi_int_efda_0_nc = 'b0;
assign can0_ipi_int_efovf_0_nc = 'b0;
assign can0_ipi_int_efrov_0_nc = 'b0;
assign can0_ipi_int_efufw_0_nc = 'b0;
assign can0_ipi_int_efwm_0_nc = 'b0;
assign can0_ipi_int_efwov_0_nc = 'b0;
assign can0_ipi_int_erfda_0_nc = 'b0;
assign can0_ipi_int_erfovf_0_nc = 'b0;
assign can0_ipi_int_erfufw_0_nc = 'b0;
assign can0_ipi_int_erfwm_0_nc = 'b0;
assign can0_ipi_int_error_0_nc = 'b0;
assign can0_ipi_int_error_fd_0_nc = 'b0;
assign can0_ipi_int_error_or_delay = 'b0;
assign can0_ipi_int_mb_127_0_nc[127:0] = 'b0;
assign can0_ipi_int_mbor_0_nc = 'b0;
assign can0_ipi_int_ncefa_0_nc = 'b0;
assign can0_ipi_int_nceha_0_nc = 'b0;
assign can0_ipi_int_or_delay = 'b0;
assign can0_ipi_int_rx_warning_0_nc = 'b0;
assign can0_ipi_int_timer_wrap_0_nc = 'b0;
assign can0_ipi_int_tx_warning_0_nc = 'b0;
assign can0_ipi_int_wake_match_0_nc = 'b0;
assign can0_ipi_int_wake_to_0_nc = 'b0;
assign can0_ipi_int_wakein_0_nc = 'b0;
assign can0_fcf_do_cantx = 'b0;
assign can0_ips_rdata[31:0] = 'b0;
assign can0_ips_xfr_err = 'b0;
assign can0_ips_xfr_wait = 'b0;
`else
d_ip_flexcan3_syn #(
    .ADDR_SIZE(14),
    .CIA_BIT_TIMING(1'b1),
    .DMA_EN(1'h1),
    .ECC_EN(1'h1),
    .ENHANCE_MB_MEM(1'h0),
    .ERX_FIFO_EN(1'b1),
    .ERX_FIFO_FLT_ELEM(100),
    .ERX_FIFO_SIZE(30),
    .FD_EN(1'h1),
    .GATE_BUFFER_SIZE(4'h4),
    .GATE_FEN(1'b0),
    .IRMQ_EN(1'h1),
    .LOCK_IRMQ(1'h0),
    .MDIS_RST_VALUE(1'h1),
    .NUMBER_OF_MB(128),
    .PNET_EN(1'h1),
    .TASD_RST_VALUE(5'h14),
    .TIMER_WRAP_EN(1'h1),
    .TIME_STAMP_EN(1'h1)
) can0 (
    // Outputs
    .can_addr           ({
                            can0_can_addr_13_nc,                // [13]
                            can0_can_addr[12:3],                // [12:3]
                            can0_can_addr_2_0_nc[2:0]           // [2:0]
                        }),
    .can_byte_15_8      (can0_can_byte_15_8),
    .can_byte_23_16     (can0_can_byte_23_16),
    .can_byte_31_24     (can0_can_byte_31_24),
    .can_byte_39_32     (can0_can_byte_39_32),
    .can_byte_47_40     (can0_can_byte_47_40),
    .can_byte_55_48     (can0_can_byte_55_48),
    .can_byte_63_56     (can0_can_byte_63_56),
    .can_byte_7_0       (can0_can_byte_7_0),
    .can_cen_b          (can0_can_cen_b),
    .can_clk_src        (can0_can_clk_src),
    .can_id             (can0_can_id_31_0_nc[31:0]),
    .can_lpm_ack        (can0_can_lpm_ack_0_nc),
    .can_mb_status      (can0_can_mb_status_127_0_nc[127:0]),
    .can_req            (can0_can_req_0_nc),
    .can_rwb            (can0_can_rwb),
    .can_slf_wak        (can0_can_slf_wak_0_nc),
    .can_wak_int        (can0_can_wak_int_0_nc),
    .can_wak_src        (can0_can_wak_src_0_nc),
    .can_wdb            (can0_can_wdb[103:0]),
    .can_wrb            (can0_can_wrb_0_nc),
    .ecc_corr_err_det_flag  (can0_ecc_corr_err_det_flag_0_nc),
    .ecc_err_addr       (can0_ecc_err_addr_31_0_nc[31:0]),
    .ecc_uncorr_err_det_flag (can0_ecc_uncorr_err_det_flag_0_nc),
    .ipd_req            (can0_ipd_req),
    .ipd_req_tx         (can0_ipd_req_tx_0_nc),
    .ipg_enable_clk_chi (can0_ipg_enable_clk_chi),
    .ipg_enable_clk_pe  (can0_ipg_enable_clk_pe),
    .ipg_stop_ack       (can0_ipg_stop_ack),
    .ipi_int_busoff     (can0_ipi_int_busoff_0_nc),
    .ipi_int_busoff_done (can0_ipi_int_busoff_done_0_nc),
    .ipi_int_ce         (can0_ipi_int_ce_0_nc),
    .ipi_int_efda       (can0_ipi_int_efda_0_nc),
    .ipi_int_efovf      (can0_ipi_int_efovf_0_nc),
    .ipi_int_efrov      (can0_ipi_int_efrov_0_nc),
    .ipi_int_efufw      (can0_ipi_int_efufw_0_nc),
    .ipi_int_efwm       (can0_ipi_int_efwm_0_nc),
    .ipi_int_efwov      (can0_ipi_int_efwov_0_nc),
    .ipi_int_erfda      (can0_ipi_int_erfda_0_nc),
    .ipi_int_erfovf     (can0_ipi_int_erfovf_0_nc),
    .ipi_int_erfufw     (can0_ipi_int_erfufw_0_nc),
    .ipi_int_erfwm      (can0_ipi_int_erfwm_0_nc),
    .ipi_int_error      (can0_ipi_int_error_0_nc),
    .ipi_int_error_fd   (can0_ipi_int_error_fd_0_nc),
    .ipi_int_error_or_delay (can0_ipi_int_error_or_delay),
    .ipi_int_mb         (can0_ipi_int_mb_127_0_nc[127:0]),
    .ipi_int_mbor       (can0_ipi_int_mbor_0_nc),
    .ipi_int_ncefa      (can0_ipi_int_ncefa_0_nc),
    .ipi_int_nceha      (can0_ipi_int_nceha_0_nc),
    .ipi_int_or_delay   (can0_ipi_int_or_delay),
    .ipi_int_rx_warning (can0_ipi_int_rx_warning_0_nc),
    .ipi_int_timer_wrap (can0_ipi_int_timer_wrap_0_nc),
    .ipi_int_tx_warning (can0_ipi_int_tx_warning_0_nc),
    .ipi_int_wake_match (can0_ipi_int_wake_match_0_nc),
    .ipi_int_wake_to    (can0_ipi_int_wake_to_0_nc),
    .ipi_int_wakein     (can0_ipi_int_wakein_0_nc),
    .ipp_do_cantx       (can0_fcf_do_cantx),
    .ips_rdata          (can0_ips_rdata[31:0]),
    .ips_xfr_err        (can0_ips_xfr_err),
    .ips_xfr_wait       (can0_ips_xfr_wait),

    // Inputs
    .can_rx_trgsel      (misc_glue_pd1_can_rx_trgsel),
    .dma_fcd_done       (32'h0000_0000),
    .erx_fix_en         (GPR_CAN_FIX_EN),
    .fd_enable_plug     (GPR_CAN_FD_ENABLE),
    .flxram_rdb         (flexcan_dma_wrap_q_4[103:0]),
    .gfl_wak_async_req  (1'b0),
    .gfl_wak_sync_req_b (1'b1),
    .ipd_done           (dma_mux_fcd_done_can0_fcd),
    .ipg_clk            (pcc_run_int_fcg_clk_pcc_FLEXCAN0),
    .ipg_clk_chi        (clkgen_run_int_clkgated_bus_plat_clk_1_can0_clk_chi),
    .ipg_clk_pe         (flexcan_glue_clkgen_fcg_clk_pe_can0),
    .ipg_clk_pe_nogate  (flexcan_glue_clkgen_fcg_clk_pe_nogate_can0),
    .ipg_clk_s          (pcc_run_int_fcg_clk_s_FLEXCAN0),
    .ipg_clk_ts         (1'b0),
    .ipg_debug          (pcc_run_int_fcg_debug_pcc_periph_FLEXCAN0),
    .ipg_doze           (pcc_run_int_fcg_doze_pcc_periph_FLEXCAN0),
    .ipg_hard_async_reset_b    (pcc_run_int_fcg_reset_b_pcc_periph_FLEXCAN0),
    .ipg_hard_async_reset_pe_b (flexcan_glue_fcg_hard_async_reset_pe_b_can0),
    .ipg_hard_async_reset_ts_b (1'b0),
    .ipg_soft_reset_b   (1'b1),
    .ipg_stop           (pcc_run_int_fcg_stop_pcc_periph_FLEXCAN0),
    .ipp_ind_canrx      (can0_fcf_ind_canrx_out),
    .ips_addr           (platform_int_afcbl_fcb_addr[13:0]),
    .ips_byte_15_8      (platform_int_afcbl_fcb_byte_15_8),
    .ips_byte_23_16     (platform_int_afcbl_fcb_byte_23_16),
    .ips_byte_31_24     (platform_int_afcbl_fcb_byte_31_24),
    .ips_byte_7_0       (platform_int_afcbl_fcb_byte_7_0),
    .ips_module_en      (misc_glue_pd1_can0_fcb_module_en),
    .ips_rwb            (platform_int_afcbl_fcb_rwb),
    .ips_supervisor_access (platform_int_afcbl_fcb_supervisor_access),
    .ips_test_access    (misc_glue_pd1_fcb_test_access_can0),
    .ips_wdata          (platform_int_afcbl_fcb_wdata[31:0]),
    .ipt_se_async       (run_int_tcu_fct_se_async[0]),
    .timestamp_base     (32'h0000_0000),
    .tmr_tick_ext       (eftu_top0_cmu0_eclk_en_1)
);
`endif
// can0 instance end






// can10 instance start
`ifdef FPGA_SYN
assign {
                            can10_can_addr_13_nc,          // [13]
                            can10_can_addr[12],             // [12]
                            can10_can_addr[11],             // [11]
                            can10_can_addr[10],             // [10]
                            can10_can_addr[9],              // [9]
                            can10_can_addr[8],              // [8]
                            can10_can_addr[7],              // [7]
                            can10_can_addr[6],              // [6]
                            can10_can_addr[5],              // [5]
                            can10_can_addr[4],              // [4]
                            can10_can_addr[3],              // [3]
                            can10_can_addr_2_nc,            // [2]
                            can10_can_addr_1_nc,            // [1]
                            can10_can_addr_0_nc             // [0]
                        } = 'b0;
assign can10_can_byte_15_8 = 'b0;
assign can10_can_byte_23_16 = 'b0;
assign can10_can_byte_31_24 = 'b0;
assign can10_can_byte_39_32 = 'b0;
assign can10_can_byte_47_40 = 'b0;
assign can10_can_byte_55_48 = 'b0;
assign can10_can_byte_63_56 = 'b0;
assign can10_can_byte_7_0 = 'b0;
assign can10_can_cen_b = 1'b1;
assign can10_can_clk_src = 'b0;
assign {
                            can10_can_id_31_nc,
                            can10_can_id_30_nc,
                            can10_can_id_29_nc,
                            can10_can_id_28_nc,
                            can10_can_id_27_nc,
                            can10_can_id_26_nc,
                            can10_can_id_25_nc,
                            can10_can_id_24_nc,
                            can10_can_id_23_nc,
                            can10_can_id_22_nc,
                            can10_can_id_21_nc,
                            can10_can_id_20_nc,
                            can10_can_id_19_nc,
                            can10_can_id_18_nc,
                            can10_can_id_17_nc,
                            can10_can_id_16_nc,
                            can10_can_id_15_nc,
                            can10_can_id_14_nc,
                            can10_can_id_13_nc,
                            can10_can_id_12_nc,
                            can10_can_id_11_nc,
                            can10_can_id_10_nc,
                            can10_can_id_9_nc,
                            can10_can_id_8_nc,
                            can10_can_id_7_nc,
                            can10_can_id_6_nc,
                            can10_can_id_5_nc,
                            can10_can_id_4_nc,
                            can10_can_id_3_nc,
                            can10_can_id_2_nc,
                            can10_can_id_1_nc,
                            can10_can_id_0_nc
                        } = 'b0;
assign can10_can_lpm_ack_0_nc = 'b0;
assign {
                            can10_can_mb_status_127_nc,
                            can10_can_mb_status_126_nc,
                            can10_can_mb_status_125_nc,
                            can10_can_mb_status_124_nc,
                            can10_can_mb_status_123_nc,
                            can10_can_mb_status_122_nc,
                            can10_can_mb_status_121_nc,
                            can10_can_mb_status_120_nc,
                            can10_can_mb_status_119_nc,
                            can10_can_mb_status_118_nc,
                            can10_can_mb_status_117_nc,
                            can10_can_mb_status_116_nc,
                            can10_can_mb_status_115_nc,
                            can10_can_mb_status_114_nc,
                            can10_can_mb_status_113_nc,
                            can10_can_mb_status_112_nc,
                            can10_can_mb_status_111_nc,
                            can10_can_mb_status_110_nc,
                            can10_can_mb_status_109_nc,
                            can10_can_mb_status_108_nc,
                            can10_can_mb_status_107_nc,
                            can10_can_mb_status_106_nc,
                            can10_can_mb_status_105_nc,
                            can10_can_mb_status_104_nc,
                            can10_can_mb_status_103_nc,
                            can10_can_mb_status_102_nc,
                            can10_can_mb_status_101_nc,
                            can10_can_mb_status_100_nc,
                            can10_can_mb_status_99_nc,
                            can10_can_mb_status_98_nc,
                            can10_can_mb_status_97_nc,
                            can10_can_mb_status_96_nc,
                            can10_can_mb_status_95_nc,
                            can10_can_mb_status_94_nc,
                            can10_can_mb_status_93_nc,
                            can10_can_mb_status_92_nc,
                            can10_can_mb_status_91_nc,
                            can10_can_mb_status_90_nc,
                            can10_can_mb_status_89_nc,
                            can10_can_mb_status_88_nc,
                            can10_can_mb_status_87_nc,
                            can10_can_mb_status_86_nc,
                            can10_can_mb_status_85_nc,
                            can10_can_mb_status_84_nc,
                            can10_can_mb_status_83_nc,
                            can10_can_mb_status_82_nc,
                            can10_can_mb_status_81_nc,
                            can10_can_mb_status_80_nc,
                            can10_can_mb_status_79_nc,
                            can10_can_mb_status_78_nc,
                            can10_can_mb_status_77_nc,
                            can10_can_mb_status_76_nc,
                            can10_can_mb_status_75_nc,
                            can10_can_mb_status_74_nc,
                            can10_can_mb_status_73_nc,
                            can10_can_mb_status_72_nc,
                            can10_can_mb_status_71_nc,
                            can10_can_mb_status_70_nc,
                            can10_can_mb_status_69_nc,
                            can10_can_mb_status_68_nc,
                            can10_can_mb_status_67_nc,
                            can10_can_mb_status_66_nc,
                            can10_can_mb_status_65_nc,
                            can10_can_mb_status_64_nc,
                            can10_can_mb_status_63_nc,
                            can10_can_mb_status_62_nc,
                            can10_can_mb_status_61_nc,
                            can10_can_mb_status_60_nc,
                            can10_can_mb_status_59_nc,
                            can10_can_mb_status_58_nc,
                            can10_can_mb_status_57_nc,
                            can10_can_mb_status_56_nc,
                            can10_can_mb_status_55_nc,
                            can10_can_mb_status_54_nc,
                            can10_can_mb_status_53_nc,
                            can10_can_mb_status_52_nc,
                            can10_can_mb_status_51_nc,
                            can10_can_mb_status_50_nc,
                            can10_can_mb_status_49_nc,
                            can10_can_mb_status_48_nc,
                            can10_can_mb_status_47_nc,
                            can10_can_mb_status_46_nc,
                            can10_can_mb_status_45_nc,
                            can10_can_mb_status_44_nc,
                            can10_can_mb_status_43_nc,
                            can10_can_mb_status_42_nc,
                            can10_can_mb_status_41_nc,
                            can10_can_mb_status_40_nc,
                            can10_can_mb_status_39_nc,
                            can10_can_mb_status_38_nc,
                            can10_can_mb_status_37_nc,
                            can10_can_mb_status_36_nc,
                            can10_can_mb_status_35_nc,
                            can10_can_mb_status_34_nc,
                            can10_can_mb_status_33_nc,
                            can10_can_mb_status_32_nc,
                            can10_can_mb_status_31_nc,
                            can10_can_mb_status_30_nc,
                            can10_can_mb_status_29_nc,
                            can10_can_mb_status_28_nc,
                            can10_can_mb_status_27_nc,
                            can10_can_mb_status_26_nc,
                            can10_can_mb_status_25_nc,
                            can10_can_mb_status_24_nc,
                            can10_can_mb_status_23_nc,
                            can10_can_mb_status_22_nc,
                            can10_can_mb_status_21_nc,
                            can10_can_mb_status_20_nc,
                            can10_can_mb_status_19_nc,
                            can10_can_mb_status_18_nc,
                            can10_can_mb_status_17_nc,
                            can10_can_mb_status_16_nc,
                            can10_can_mb_status_15_nc,
                            can10_can_mb_status_14_nc,
                            can10_can_mb_status_13_nc,
                            can10_can_mb_status_12_nc,
                            can10_can_mb_status_11_nc,
                            can10_can_mb_status_10_nc,
                            can10_can_mb_status_9_nc,
                            can10_can_mb_status_8_nc,
                            can10_can_mb_status_7_nc,
                            can10_can_mb_status_6_nc,
                            can10_can_mb_status_5_nc,
                            can10_can_mb_status_4_nc,
                            can10_can_mb_status_3_nc,
                            can10_can_mb_status_2_nc,
                            can10_can_mb_status_1_nc,
                            can10_can_mb_status_0_nc
                        } = 'b0;
assign can10_can_rwb = 'b0;
assign can10_can_slf_wak_0_nc = 'b0;
assign can10_can_wak_int_0_nc = 'b0;
assign can10_can_wak_src_0_nc = 'b0;
assign can10_can_wdb[103:0] = 'b0;
assign can10_can_wrb_0_nc = 'b0;
assign can10_ecc_corr_err_det_flag_0_nc = 'b0;
assign {
                            can10_ecc_err_addr_31_nc,
                            can10_ecc_err_addr_30_nc,
                            can10_ecc_err_addr_29_nc,
                            can10_ecc_err_addr_28_nc,
                            can10_ecc_err_addr_27_nc,
                            can10_ecc_err_addr_26_nc,
                            can10_ecc_err_addr_25_nc,
                            can10_ecc_err_addr_24_nc,
                            can10_ecc_err_addr_23_nc,
                            can10_ecc_err_addr_22_nc,
                            can10_ecc_err_addr_21_nc,
                            can10_ecc_err_addr_20_nc,
                            can10_ecc_err_addr_19_nc,
                            can10_ecc_err_addr_18_nc,
                            can10_ecc_err_addr_17_nc,
                            can10_ecc_err_addr_16_nc,
                            can10_ecc_err_addr_15_nc,
                            can10_ecc_err_addr_14_nc,
                            can10_ecc_err_addr_13_nc,
                            can10_ecc_err_addr_12_nc,
                            can10_ecc_err_addr_11_nc,
                            can10_ecc_err_addr_10_nc,
                            can10_ecc_err_addr_9_nc,
                            can10_ecc_err_addr_8_nc,
                            can10_ecc_err_addr_7_nc,
                            can10_ecc_err_addr_6_nc,
                            can10_ecc_err_addr_5_nc,
                            can10_ecc_err_addr_4_nc,
                            can10_ecc_err_addr_3_nc,
                            can10_ecc_err_addr_2_nc,
                            can10_ecc_err_addr_1_nc,
                            can10_ecc_err_addr_0_nc
                        } = 'b0;
assign can10_ecc_uncorr_err_flag_0_nc = 'b0;
assign can10_ipd_req = 'b0;
assign can10_ipd_req_tx_0_nc = 'b0;
assign can10_ipg_enable_clk_chi = 'b0;
assign can10_ipg_enable_clk_pe = 'b0;
assign can10_ipg_stop_ack = 'b0;
assign can10_ipi_int_busoff = 'b0;
assign can10_ipi_int_busoff_done = 'b0;
assign can10_ipi_int_ce = 'b0;
assign can10_ipi_int_efda_0_nc = 'b0;
assign can10_ipi_int_efovf_0_nc = 'b0;
assign can10_ipi_int_efrov_0_nc = 'b0;
assign can10_ipi_int_efufw_0_nc = 'b0;
assign can10_ipi_int_efwm_0_nc = 'b0;
assign can10_ipi_int_efwov_0_nc = 'b0;
assign can10_ipi_int_erfda = 'b0;
assign can10_ipi_int_erfovf = 'b0;
assign can10_ipi_int_erfufw = 'b0;
assign can10_ipi_int_erfwm = 'b0;
assign can10_ipi_int_error = 'b0;
assign can10_ipi_int_error_fd = 'b0;
assign can10_ipi_int_error_or_delay_0_nc = 'b0;
assign {
                            can10_ipi_int_mb_127_nc,
                            can10_ipi_int_mb_126_nc,
                            can10_ipi_int_mb_125_nc,
                            can10_ipi_int_mb_124_nc,
                            can10_ipi_int_mb_123_nc,
                            can10_ipi_int_mb_122_nc,
                            can10_ipi_int_mb_121_nc,
                            can10_ipi_int_mb_120_nc,
                            can10_ipi_int_mb_119_nc,
                            can10_ipi_int_mb_118_nc,
                            can10_ipi_int_mb_117_nc,
                            can10_ipi_int_mb_116_nc,
                            can10_ipi_int_mb_115_nc,
                            can10_ipi_int_mb_114_nc,
                            can10_ipi_int_mb_113_nc,
                            can10_ipi_int_mb_112_nc,
                            can10_ipi_int_mb_111_nc,
                            can10_ipi_int_mb_110_nc,
                            can10_ipi_int_mb_109_nc,
                            can10_ipi_int_mb_108_nc,
                            can10_ipi_int_mb_107_nc,
                            can10_ipi_int_mb_106_nc,
                            can10_ipi_int_mb_105_nc,
                            can10_ipi_int_mb_104_nc,
                            can10_ipi_int_mb_103_nc,
                            can10_ipi_int_mb_102_nc,
                            can10_ipi_int_mb_101_nc,
                            can10_ipi_int_mb_100_nc,
                            can10_ipi_int_mb_99_nc,
                            can10_ipi_int_mb_98_nc,
                            can10_ipi_int_mb_97_nc,
                            can10_ipi_int_mb_96_nc,
                            can10_ipi_int_mb_95_nc,
                            can10_ipi_int_mb_94_nc,
                            can10_ipi_int_mb_93_nc,
                            can10_ipi_int_mb_92_nc,
                            can10_ipi_int_mb_91_nc,
                            can10_ipi_int_mb_90_nc,
                            can10_ipi_int_mb_89_nc,
                            can10_ipi_int_mb_88_nc,
                            can10_ipi_int_mb_87_nc,
                            can10_ipi_int_mb_86_nc,
                            can10_ipi_int_mb_85_nc,
                            can10_ipi_int_mb_84_nc,
                            can10_ipi_int_mb_83_nc,
                            can10_ipi_int_mb_82_nc,
                            can10_ipi_int_mb_81_nc,
                            can10_ipi_int_mb_80_nc,
                            can10_ipi_int_mb_79_nc,
                            can10_ipi_int_mb_78_nc,
                            can10_ipi_int_mb_77_nc,
                            can10_ipi_int_mb_76_nc,
                            can10_ipi_int_mb_75_nc,
                            can10_ipi_int_mb_74_nc,
                            can10_ipi_int_mb_73_nc,
                            can10_ipi_int_mb_72_nc,
                            can10_ipi_int_mb_71_nc,
                            can10_ipi_int_mb_70_nc,
                            can10_ipi_int_mb_69_nc,
                            can10_ipi_int_mb_68_nc,
                            can10_ipi_int_mb_67_nc,
                            can10_ipi_int_mb_66_nc,
                            can10_ipi_int_mb_65_nc,
                            can10_ipi_int_mb_64_nc,
                            can10_ipi_int_mb_63_nc,
                            can10_ipi_int_mb_62_nc,
                            can10_ipi_int_mb_61_nc,
                            can10_ipi_int_mb_60_nc,
                            can10_ipi_int_mb_59_nc,
                            can10_ipi_int_mb_58_nc,
                            can10_ipi_int_mb_57_nc,
                            can10_ipi_int_mb_56_nc,
                            can10_ipi_int_mb_55_nc,
                            can10_ipi_int_mb_54_nc,
                            can10_ipi_int_mb_53_nc,
                            can10_ipi_int_mb_52_nc,
                            can10_ipi_int_mb_51_nc,
                            can10_ipi_int_mb_50_nc,
                            can10_ipi_int_mb_49_nc,
                            can10_ipi_int_mb_48_nc,
                            can10_ipi_int_mb_47_nc,
                            can10_ipi_int_mb_46_nc,
                            can10_ipi_int_mb_45_nc,
                            can10_ipi_int_mb_44_nc,
                            can10_ipi_int_mb_43_nc,
                            can10_ipi_int_mb_42_nc,
                            can10_ipi_int_mb_41_nc,
                            can10_ipi_int_mb_40_nc,
                            can10_ipi_int_mb_39_nc,
                            can10_ipi_int_mb_38_nc,
                            can10_ipi_int_mb_37_nc,
                            can10_ipi_int_mb_36_nc,
                            can10_ipi_int_mb_35_nc,
                            can10_ipi_int_mb_34_nc,
                            can10_ipi_int_mb_33_nc,
                            can10_ipi_int_mb_32_nc,
                            can10_ipi_int_mb_31_nc,
                            can10_ipi_int_mb_30_nc,
                            can10_ipi_int_mb_29_nc,
                            can10_ipi_int_mb_28_nc,
                            can10_ipi_int_mb_27_nc,
                            can10_ipi_int_mb_26_nc,
                            can10_ipi_int_mb_25_nc,
                            can10_ipi_int_mb_24_nc,
                            can10_ipi_int_mb_23_nc,
                            can10_ipi_int_mb_22_nc,
                            can10_ipi_int_mb_21_nc,
                            can10_ipi_int_mb_20_nc,
                            can10_ipi_int_mb_19_nc,
                            can10_ipi_int_mb_18_nc,
                            can10_ipi_int_mb_17_nc,
                            can10_ipi_int_mb_16_nc,
                            can10_ipi_int_mb_15_nc,
                            can10_ipi_int_mb_14_nc,
                            can10_ipi_int_mb_13_nc,
                            can10_ipi_int_mb_12_nc,
                            can10_ipi_int_mb_11_nc,
                            can10_ipi_int_mb_10_nc,
                            can10_ipi_int_mb_9_nc,
                            can10_ipi_int_mb_8_nc,
                            can10_ipi_int_mb_7_nc,
                            can10_ipi_int_mb_6_nc,
                            can10_ipi_int_mb_5_nc,
                            can10_ipi_int_mb_4_nc,
                            can10_ipi_int_mb_3_nc,
                            can10_ipi_int_mb_2_nc,
                            can10_ipi_int_mb_1_nc,
                            can10_ipi_int_mb_0_nc
                        } = 'b0;
assign can10_ipi_int_mbor = 'b0;
assign can10_ipi_int_ncefa = 'b0;
assign can10_ipi_int_nceha = 'b0;
assign can10_ipi_int_or_delay_0_nc = 'b0;
assign can10_ipi_int_rx_warning = 'b0;
assign can10_ipi_int_timer_wrap = 'b0;
assign can10_ipi_int_tx_warning = 'b0;
assign can10_ipi_int_wake_match_0_nc = 'b0;
assign can10_ipi_int_wake_to_0_nc = 'b0;
assign can10_ipi_int_wakein_0_nc = 'b0;
assign can10_ipp_do_cantx = 'b0;
assign can10_ips_rdata[31:0] = 'b0;
assign can10_ips_xfr_err = 'b0;
assign can10_ips_xfr_wait = 'b0;
`else
d_ip_flexcan3_syn #(
    .ADDR_SIZE(14),                 // Address bus width (has to be at least 14)
    .CIA_BIT_TIMING(1'b1),          // Enable enhanced bit timing
    .DMA_EN(1'h1),                  // DMA feature: To enable make DMA_EN=1
    .ECC_EN(1'h1),                  // ECC feature: To enable make ECC_EN=1
    .ENHANCE_MB_MEM(1'h0),          // Enhanced MB memory increase
    .ERX_FIFO_EN(1'b1),             // Enhanced Rx FIFO enable
    .ERX_FIFO_FLT_ELEM(100),        // Number of filters of Enhanced Rx FIFO
    .ERX_FIFO_SIZE(30),             // Enhanced RX FIFO size
    .EXT_FIFO_EN(1'b0),             // Extends FIFO enable
    .FD_EN(1'h1),                   // FD feature: to enable make FD_EN=1
    .GATE_BUFFER_SIZE(4'h4),
    .GATE_FEN(1'b0),
    .IRMQ_EN(1'h1),                 // If asserted, the module will implement an individual Rx Mask for each MailBox
    .LOCK_IRMQ(1'h0),               // If asserted, locks BCC to reset value ('0')
    .MDIS_RST_VALUE(1'h1),          // Reset value of MDIS bit in MCR
    .NUMBER_OF_MB(128),             // Number of Message Buffers
    .PNET_EN(1'h0),                 // PNET feature: To enable make PNET_EN=1
    .TASD_RST_VALUE(5'h14),         // Tx Arbitration start delay in CAN bits
    .TIMER_WRAP_EN(1'h1),           // Timer wrap around GM 7.2.3.B.3, Silvaco #49
    .TIME_STAMP_EN(1'h1)            // Enable external timestamp base
) can10 (
// Outputs
    .can_addr           ({
                            can10_can_addr_13_nc,          // [13]
                            can10_can_addr[12],             // [12]
                            can10_can_addr[11],             // [11]
                            can10_can_addr[10],             // [10]
                            can10_can_addr[9],              // [9]
                            can10_can_addr[8],              // [8]
                            can10_can_addr[7],              // [7]
                            can10_can_addr[6],              // [6]
                            can10_can_addr[5],              // [5]
                            can10_can_addr[4],              // [4]
                            can10_can_addr[3],              // [3]
                            can10_can_addr_2_nc,            // [2]
                            can10_can_addr_1_nc,            // [1]
                            can10_can_addr_0_nc             // [0]
                        }), // can10 // Address to Message Buffer RAM
    .can_byte_15_8      (can10_can_byte_15_8),      // can10 // RAM bus byte enable [15:8]
    .can_byte_23_16     (can10_can_byte_23_16),     // can10 // RAM bus byte enable [23:16]
    .can_byte_31_24     (can10_can_byte_31_24),     // can10 // RAM bus byte enable [31:24]
    .can_byte_39_32     (can10_can_byte_39_32),     // can10 // RAM bus byte enable [39:32]
    .can_byte_47_40     (can10_can_byte_47_40),     // can10 // RAM bus byte enable [47:40]
    .can_byte_55_48     (can10_can_byte_55_48),     // can10 // RAM bus byte enable [55:48]
    .can_byte_63_56     (can10_can_byte_63_56),     // can10 // RAM bus byte enable [63:56]
    .can_byte_7_0       (can10_can_byte_7_0),       // can10 // RAM bus byte enable [ 7:0]
    .can_cen_b          (can10_can_cen_b),          // can10 // RAM chip enable
    .can_clk_src        (can10_can_clk_src),        // can10 // Selects CAN clock source
    .can_id             ({
                            can10_can_id_31_nc,
                            can10_can_id_30_nc,
                            can10_can_id_29_nc,
                            can10_can_id_28_nc,
                            can10_can_id_27_nc,
                            can10_can_id_26_nc,
                            can10_can_id_25_nc,
                            can10_can_id_24_nc,
                            can10_can_id_23_nc,
                            can10_can_id_22_nc,
                            can10_can_id_21_nc,
                            can10_can_id_20_nc,
                            can10_can_id_19_nc,
                            can10_can_id_18_nc,
                            can10_can_id_17_nc,
                            can10_can_id_16_nc,
                            can10_can_id_15_nc,
                            can10_can_id_14_nc,
                            can10_can_id_13_nc,
                            can10_can_id_12_nc,
                            can10_can_id_11_nc,
                            can10_can_id_10_nc,
                            can10_can_id_9_nc,
                            can10_can_id_8_nc,
                            can10_can_id_7_nc,
                            can10_can_id_6_nc,
                            can10_can_id_5_nc,
                            can10_can_id_4_nc,
                            can10_can_id_3_nc,
                            can10_can_id_2_nc,
                            can10_can_id_1_nc,
                            can10_can_id_0_nc
                        }), // can10
    .can_lpm_ack        (can10_can_lpm_ack_0_nc),    // can10 // Low power mode (stop, doze, sleep)
    .can_mb_status      ({
                            can10_can_mb_status_127_nc,
                            can10_can_mb_status_126_nc,
                            can10_can_mb_status_125_nc,
                            can10_can_mb_status_124_nc,
                            can10_can_mb_status_123_nc,
                            can10_can_mb_status_122_nc,
                            can10_can_mb_status_121_nc,
                            can10_can_mb_status_120_nc,
                            can10_can_mb_status_119_nc,
                            can10_can_mb_status_118_nc,
                            can10_can_mb_status_117_nc,
                            can10_can_mb_status_116_nc,
                            can10_can_mb_status_115_nc,
                            can10_can_mb_status_114_nc,
                            can10_can_mb_status_113_nc,
                            can10_can_mb_status_112_nc,
                            can10_can_mb_status_111_nc,
                            can10_can_mb_status_110_nc,
                            can10_can_mb_status_109_nc,
                            can10_can_mb_status_108_nc,
                            can10_can_mb_status_107_nc,
                            can10_can_mb_status_106_nc,
                            can10_can_mb_status_105_nc,
                            can10_can_mb_status_104_nc,
                            can10_can_mb_status_103_nc,
                            can10_can_mb_status_102_nc,
                            can10_can_mb_status_101_nc,
                            can10_can_mb_status_100_nc,
                            can10_can_mb_status_99_nc,
                            can10_can_mb_status_98_nc,
                            can10_can_mb_status_97_nc,
                            can10_can_mb_status_96_nc,
                            can10_can_mb_status_95_nc,
                            can10_can_mb_status_94_nc,
                            can10_can_mb_status_93_nc,
                            can10_can_mb_status_92_nc,
                            can10_can_mb_status_91_nc,
                            can10_can_mb_status_90_nc,
                            can10_can_mb_status_89_nc,
                            can10_can_mb_status_88_nc,
                            can10_can_mb_status_87_nc,
                            can10_can_mb_status_86_nc,
                            can10_can_mb_status_85_nc,
                            can10_can_mb_status_84_nc,
                            can10_can_mb_status_83_nc,
                            can10_can_mb_status_82_nc,
                            can10_can_mb_status_81_nc,
                            can10_can_mb_status_80_nc,
                            can10_can_mb_status_79_nc,
                            can10_can_mb_status_78_nc,
                            can10_can_mb_status_77_nc,
                            can10_can_mb_status_76_nc,
                            can10_can_mb_status_75_nc,
                            can10_can_mb_status_74_nc,
                            can10_can_mb_status_73_nc,
                            can10_can_mb_status_72_nc,
                            can10_can_mb_status_71_nc,
                            can10_can_mb_status_70_nc,
                            can10_can_mb_status_69_nc,
                            can10_can_mb_status_68_nc,
                            can10_can_mb_status_67_nc,
                            can10_can_mb_status_66_nc,
                            can10_can_mb_status_65_nc,
                            can10_can_mb_status_64_nc,
                            can10_can_mb_status_63_nc,
                            can10_can_mb_status_62_nc,
                            can10_can_mb_status_61_nc,
                            can10_can_mb_status_60_nc,
                            can10_can_mb_status_59_nc,
                            can10_can_mb_status_58_nc,
                            can10_can_mb_status_57_nc,
                            can10_can_mb_status_56_nc,
                            can10_can_mb_status_55_nc,
                            can10_can_mb_status_54_nc,
                            can10_can_mb_status_53_nc,
                            can10_can_mb_status_52_nc,
                            can10_can_mb_status_51_nc,
                            can10_can_mb_status_50_nc,
                            can10_can_mb_status_49_nc,
                            can10_can_mb_status_48_nc,
                            can10_can_mb_status_47_nc,
                            can10_can_mb_status_46_nc,
                            can10_can_mb_status_45_nc,
                            can10_can_mb_status_44_nc,
                            can10_can_mb_status_43_nc,
                            can10_can_mb_status_42_nc,
                            can10_can_mb_status_41_nc,
                            can10_can_mb_status_40_nc,
                            can10_can_mb_status_39_nc,
                            can10_can_mb_status_38_nc,
                            can10_can_mb_status_37_nc,
                            can10_can_mb_status_36_nc,
                            can10_can_mb_status_35_nc,
                            can10_can_mb_status_34_nc,
                            can10_can_mb_status_33_nc,
                            can10_can_mb_status_32_nc,
                            can10_can_mb_status_31_nc,
                            can10_can_mb_status_30_nc,
                            can10_can_mb_status_29_nc,
                            can10_can_mb_status_28_nc,
                            can10_can_mb_status_27_nc,
                            can10_can_mb_status_26_nc,
                            can10_can_mb_status_25_nc,
                            can10_can_mb_status_24_nc,
                            can10_can_mb_status_23_nc,
                            can10_can_mb_status_22_nc,
                            can10_can_mb_status_21_nc,
                            can10_can_mb_status_20_nc,
                            can10_can_mb_status_19_nc,
                            can10_can_mb_status_18_nc,
                            can10_can_mb_status_17_nc,
                            can10_can_mb_status_16_nc,
                            can10_can_mb_status_15_nc,
                            can10_can_mb_status_14_nc,
                            can10_can_mb_status_13_nc,
                            can10_can_mb_status_12_nc,
                            can10_can_mb_status_11_nc,
                            can10_can_mb_status_10_nc,
                            can10_can_mb_status_9_nc,
                            can10_can_mb_status_8_nc,
                            can10_can_mb_status_7_nc,
                            can10_can_mb_status_6_nc,
                            can10_can_mb_status_5_nc,
                            can10_can_mb_status_4_nc,
                            can10_can_mb_status_3_nc,
                            can10_can_mb_status_2_nc,
                            can10_can_mb_status_1_nc,
                            can10_can_mb_status_0_nc
                        }), // can10
    .can_req            (can10_can_req_0_nc),        // can10
    .can_rwb            (can10_can_rwb),              // can10 // RAM rd/wr_b signal
    .can_slf_wak        (can10_can_slf_wak_0_nc),    // can10 // Enable wake-up on CAN bus activity
    .can_wak_int        (can10_can_wak_int_0_nc),    // can10 // Unmasked wake-up interrupt flag
    .can_wak_src        (can10_can_wak_src_0_nc),    // can10 // Selects filt/unfilt Rx for wake-up
    .can_wdb            (can10_can_wdb[103:0]),       // can10 // RAM write data bus
    .can_wrb            (can10_can_wrb_0_nc),        // can10 // RAM wr/rd_b signal
    .ecc_corr_err_det_flag  (can10_ecc_corr_err_det_flag_0_nc), // can10 // ECC correctable error flag
    .ecc_err_addr       ({
                            can10_ecc_err_addr_31_nc,
                            can10_ecc_err_addr_30_nc,
                            can10_ecc_err_addr_29_nc,
                            can10_ecc_err_addr_28_nc,
                            can10_ecc_err_addr_27_nc,
                            can10_ecc_err_addr_26_nc,
                            can10_ecc_err_addr_25_nc,
                            can10_ecc_err_addr_24_nc,
                            can10_ecc_err_addr_23_nc,
                            can10_ecc_err_addr_22_nc,
                            can10_ecc_err_addr_21_nc,
                            can10_ecc_err_addr_20_nc,
                            can10_ecc_err_addr_19_nc,
                            can10_ecc_err_addr_18_nc,
                            can10_ecc_err_addr_17_nc,
                            can10_ecc_err_addr_16_nc,
                            can10_ecc_err_addr_15_nc,
                            can10_ecc_err_addr_14_nc,
                            can10_ecc_err_addr_13_nc,
                            can10_ecc_err_addr_12_nc,
                            can10_ecc_err_addr_11_nc,
                            can10_ecc_err_addr_10_nc,
                            can10_ecc_err_addr_9_nc,
                            can10_ecc_err_addr_8_nc,
                            can10_ecc_err_addr_7_nc,
                            can10_ecc_err_addr_6_nc,
                            can10_ecc_err_addr_5_nc,
                            can10_ecc_err_addr_4_nc,
                            can10_ecc_err_addr_3_nc,
                            can10_ecc_err_addr_2_nc,
                            can10_ecc_err_addr_1_nc,
                            can10_ecc_err_addr_0_nc
                        }), // can10 // ECC error address for 32-bit accesses
    .ecc_uncorr_err_det_flag (can10_ecc_uncorr_err_flag_0_nc), // can10 // ECC uncorrectable error flag
    .ipd_req            (can10_ipd_req),              // can10 // DMA request signal
    .ipd_req_tx         (can10_ipd_req_tx_0_nc),      // can10 // last mb dma request
    .ipg_enable_clk_chi (can10_ipg_enable_clk_chi),   // can10 // Request to gate ipg_clk_chi
    .ipg_enable_clk_pe  (can10_ipg_enable_clk_pe),    // can10 // Request to gate ipg_clk_pe
    .ipg_stop_ack       (can10_ipg_stop_ack),         // can10 // Acknowledge to Stop mode
    .ipi_int_busoff     (can10_ipi_int_busoff),       // can10 // Interrupt from busoff
    .ipi_int_busoff_done (can10_ipi_int_busoff_done), // can10 // Busoff done interrupt
    .ipi_int_ce         (can10_ipi_int_ce),           // can10 // Correctable error interrupt
    .ipi_int_efda       (can10_ipi_int_efda_0_nc),   // can10 // Extends FIFO data available interrupt
    .ipi_int_efovf      (can10_ipi_int_efovf_0_nc),  // can10 // Extends FIFO overflow interrupt
    .ipi_int_efrov      (can10_ipi_int_efrov_0_nc),   // can10 // Extends FIFO read pointer overwrap interrupt
    .ipi_int_efufw      (can10_ipi_int_efufw_0_nc),  // can10 // Extends FIFO underflow interrupt
    .ipi_int_efwm       (can10_ipi_int_efwm_0_nc),    // can10 // Extends FIFO watermarker interrupt
    .ipi_int_efwov      (can10_ipi_int_efwov_0_nc),   // can10 // Extends FIFO write pointer overwrap interrupt
    .ipi_int_erfda      (can10_ipi_int_erfda),        // can10 // ERX FIFO Data available interrupt
    .ipi_int_erfovf     (can10_ipi_int_erfovf),       // can10 // ERX FIFO Overflow interrupt
    .ipi_int_erfufw     (can10_ipi_int_erfufw),       // can10 // ERX FIFO Underflow interrupt
    .ipi_int_erfwm      (can10_ipi_int_erfwm),        // can10 // ERX FIFO Water maker interrupt
    .ipi_int_error      (can10_ipi_int_error),        // can10 // Interrupt from CAN line error
    .ipi_int_error_fd   (can10_ipi_int_error_fd),     // can10 // FD error interrupt
    .ipi_int_error_or_delay (can10_ipi_int_error_or_delay_0_nc),
    .ipi_int_mb         ({
                            can10_ipi_int_mb_127_nc,
                            can10_ipi_int_mb_126_nc,
                            can10_ipi_int_mb_125_nc,
                            can10_ipi_int_mb_124_nc,
                            can10_ipi_int_mb_123_nc,
                            can10_ipi_int_mb_122_nc,
                            can10_ipi_int_mb_121_nc,
                            can10_ipi_int_mb_120_nc,
                            can10_ipi_int_mb_119_nc,
                            can10_ipi_int_mb_118_nc,
                            can10_ipi_int_mb_117_nc,
                            can10_ipi_int_mb_116_nc,
                            can10_ipi_int_mb_115_nc,
                            can10_ipi_int_mb_114_nc,
                            can10_ipi_int_mb_113_nc,
                            can10_ipi_int_mb_112_nc,
                            can10_ipi_int_mb_111_nc,
                            can10_ipi_int_mb_110_nc,
                            can10_ipi_int_mb_109_nc,
                            can10_ipi_int_mb_108_nc,
                            can10_ipi_int_mb_107_nc,
                            can10_ipi_int_mb_106_nc,
                            can10_ipi_int_mb_105_nc,
                            can10_ipi_int_mb_104_nc,
                            can10_ipi_int_mb_103_nc,
                            can10_ipi_int_mb_102_nc,
                            can10_ipi_int_mb_101_nc,
                            can10_ipi_int_mb_100_nc,
                            can10_ipi_int_mb_99_nc,
                            can10_ipi_int_mb_98_nc,
                            can10_ipi_int_mb_97_nc,
                            can10_ipi_int_mb_96_nc,
                            can10_ipi_int_mb_95_nc,
                            can10_ipi_int_mb_94_nc,
                            can10_ipi_int_mb_93_nc,
                            can10_ipi_int_mb_92_nc,
                            can10_ipi_int_mb_91_nc,
                            can10_ipi_int_mb_90_nc,
                            can10_ipi_int_mb_89_nc,
                            can10_ipi_int_mb_88_nc,
                            can10_ipi_int_mb_87_nc,
                            can10_ipi_int_mb_86_nc,
                            can10_ipi_int_mb_85_nc,
                            can10_ipi_int_mb_84_nc,
                            can10_ipi_int_mb_83_nc,
                            can10_ipi_int_mb_82_nc,
                            can10_ipi_int_mb_81_nc,
                            can10_ipi_int_mb_80_nc,
                            can10_ipi_int_mb_79_nc,
                            can10_ipi_int_mb_78_nc,
                            can10_ipi_int_mb_77_nc,
                            can10_ipi_int_mb_76_nc,
                            can10_ipi_int_mb_75_nc,
                            can10_ipi_int_mb_74_nc,
                            can10_ipi_int_mb_73_nc,
                            can10_ipi_int_mb_72_nc,
                            can10_ipi_int_mb_71_nc,
                            can10_ipi_int_mb_70_nc,
                            can10_ipi_int_mb_69_nc,
                            can10_ipi_int_mb_68_nc,
                            can10_ipi_int_mb_67_nc,
                            can10_ipi_int_mb_66_nc,
                            can10_ipi_int_mb_65_nc,
                            can10_ipi_int_mb_64_nc,
                            can10_ipi_int_mb_63_nc,
                            can10_ipi_int_mb_62_nc,
                            can10_ipi_int_mb_61_nc,
                            can10_ipi_int_mb_60_nc,
                            can10_ipi_int_mb_59_nc,
                            can10_ipi_int_mb_58_nc,
                            can10_ipi_int_mb_57_nc,
                            can10_ipi_int_mb_56_nc,
                            can10_ipi_int_mb_55_nc,
                            can10_ipi_int_mb_54_nc,
                            can10_ipi_int_mb_53_nc,
                            can10_ipi_int_mb_52_nc,
                            can10_ipi_int_mb_51_nc,
                            can10_ipi_int_mb_50_nc,
                            can10_ipi_int_mb_49_nc,
                            can10_ipi_int_mb_48_nc,
                            can10_ipi_int_mb_47_nc,
                            can10_ipi_int_mb_46_nc,
                            can10_ipi_int_mb_45_nc,
                            can10_ipi_int_mb_44_nc,
                            can10_ipi_int_mb_43_nc,
                            can10_ipi_int_mb_42_nc,
                            can10_ipi_int_mb_41_nc,
                            can10_ipi_int_mb_40_nc,
                            can10_ipi_int_mb_39_nc,
                            can10_ipi_int_mb_38_nc,
                            can10_ipi_int_mb_37_nc,
                            can10_ipi_int_mb_36_nc,
                            can10_ipi_int_mb_35_nc,
                            can10_ipi_int_mb_34_nc,
                            can10_ipi_int_mb_33_nc,
                            can10_ipi_int_mb_32_nc,
                            can10_ipi_int_mb_31_nc,
                            can10_ipi_int_mb_30_nc,
                            can10_ipi_int_mb_29_nc,
                            can10_ipi_int_mb_28_nc,
                            can10_ipi_int_mb_27_nc,
                            can10_ipi_int_mb_26_nc,
                            can10_ipi_int_mb_25_nc,
                            can10_ipi_int_mb_24_nc,
                            can10_ipi_int_mb_23_nc,
                            can10_ipi_int_mb_22_nc,
                            can10_ipi_int_mb_21_nc,
                            can10_ipi_int_mb_20_nc,
                            can10_ipi_int_mb_19_nc,
                            can10_ipi_int_mb_18_nc,
                            can10_ipi_int_mb_17_nc,
                            can10_ipi_int_mb_16_nc,
                            can10_ipi_int_mb_15_nc,
                            can10_ipi_int_mb_14_nc,
                            can10_ipi_int_mb_13_nc,
                            can10_ipi_int_mb_12_nc,
                            can10_ipi_int_mb_11_nc,
                            can10_ipi_int_mb_10_nc,
                            can10_ipi_int_mb_9_nc,
                            can10_ipi_int_mb_8_nc,
                            can10_ipi_int_mb_7_nc,
                            can10_ipi_int_mb_6_nc,
                            can10_ipi_int_mb_5_nc,
                            can10_ipi_int_mb_4_nc,
                            can10_ipi_int_mb_3_nc,
                            can10_ipi_int_mb_2_nc,
                            can10_ipi_int_mb_1_nc,
                            can10_ipi_int_mb_0_nc
                        }), // can10 // Interrupt lines up to 128
    .ipi_int_mbor       (can10_ipi_int_mbor),        // can10 // Ored interrupts from ipi_int_MB
    .ipi_int_ncefa      (can10_ipi_int_ncefa),        // can10 // Non correctable error int internal
    .ipi_int_nceha      (can10_ipi_int_nceha),       // can10 // Non correctable error int host
    .ipi_int_or_delay   (can10_ipi_int_or_delay_0_nc), // can10
    .ipi_int_rx_warning (can10_ipi_int_rx_warning),  // can10 // Rx warning Interrupt
    .ipi_int_timer_wrap (can10_ipi_int_timer_wrap),  // can10 // Timer wraparound int // Silvaco #49
    .ipi_int_tx_warning (can10_ipi_int_tx_warning),  // can10 // Tx warning Interrupt
    .ipi_int_wake_match (can10_ipi_int_wake_match_0_nc), // can10 // Interrupt from match in PN
    .ipi_int_wake_to    (can10_ipi_int_wake_to_0_nc), // can10 // Interrupt from timeout in PN
    .ipi_int_wakein     (can10_ipi_int_wakein_0_nc),  // can10 // Interrupt from wake up
    .ipp_do_cantx       (can10_ipp_do_cantx),         // can10 // CAN transmit pin TX
    .ips_rdata          (can10_ips_rdata[31:0]),     // can10 // IP bus read data bus
    .ips_xfr_err        (can10_ips_xfr_err),          // can10 // IP bus transfer error
    .ips_xfr_wait       (can10_ips_xfr_wait),          // can10 // IP bus transfer wait
    // INTERNAL SIGNALS
    .can_rx_trgsel              (misc_glue_cppe_periph_can10_fob_can_rx_trgsel), // can10 // Trigger select for CAN Rx
    .dma_fcd_done               (32'h0000_0000),                         // can10 // DMA done signal
    .erx_fix_en                 (GPR_CAN_FIX_EN),
    .fd_enable_plug             (GPR_CAN_FD_ENABLE),                     // can10 // Fuse to disable FD
    .flxram_rdb                 (dma_flexcan_pse_ram_wrap_q_11[103:0]),  // can10 // RAM read data bus
    .gfl_wak_async_req          (1'b0),                                  // can10 // Wake-up request via asynchronous path
    .gfl_wak_sync_req_b         (1'b1),                                  // can10 // Wake-up request via synchronous path
    .ipd_done                   (dma_mux_fcd_done_cppe_can10_fcd_req),    // can10 // DMA done signal
    .ipg_clk                    (pcc_cppe_periph_fcg_clk_pcc_FLEXCAN10),  // can10 // Global clock
    .ipg_clk_chi                (clkgen_run_int_clkgated_bus_clk_11_can10_clk_chi), // can10 // Clock gated with ipg_enable_clk_chi
    .ipg_clk_pe                 (flexcan_glue_clkgen_fcg_clk_pe_can10),   // can10 // Clock gated with ipg_enable_clk_pe
    .ipg_clk_pe_nogate          (flexcan_glue_clkgen_fcg_clk_pe_nogate_can10), // can10 // Clock ipg_clk_pe not gated
    .ipg_clk_s                  (pcc_cppe_periph_fcg_clk_s_FLEXCAN10),    // can10 // Clock gated with module_enable_en
    .ipg_clk_ts                 (can_ipg_clk_ts),                         // can10 // Clock for timestamp
    .ipg_debug                  (pcc_cppe_periph_fcg_debug_pcc_periph_FLEXCAN10), // can10 // Freeze/debug mode request
    .ipg_doze                   (pcc_cppe_periph_fcg_doze_pcc_periph_FLEXCAN10),  // can10 // Doze Mode
    .ipg_hard_async_reset_b     (pcc_cppe_periph_fcg_reset_b_pcc_periph_FLEXCAN10), // can10 // Soft reset
    .ipg_hard_async_reset_pe_b  (flexcan_glue_fcg_hard_async_reset_pe_b_can10),    // can10 // Global hard reset to PE blocks
    .ipg_hard_async_reset_ts_b  (can_ipg_hard_async_reset_ts_b),          // can10 // Global hard reset to timestamp
    .ipg_soft_reset_b           (1'b1),                                   // can10 // Soft reset
    .ipg_stop                   (pcc_cppe_periph_fcg_stop_pcc_periph_FLEXCAN10),   // can10 // Stop mode
    .ipp_ind_canrx              (can_hub_can_rx[14]),                     // can10 // CAN receive pin RX
    //add by Eric
    .ips_addr                   (platform_int_afcb2_fcb_addr[13:0]),      // can10 // IP bus address
    .ips_byte_15_8              (platform_int_afcb2_fcb_byte_15_8),       // can10 // IP bus byte enable bits [15:8]
    .ips_byte_23_16             (platform_int_afcb2_fcb_byte_23_16),      // can10 // IP bus byte enable bits [23:16]
    .ips_byte_31_24             (platform_int_afcb2_fcb_byte_31_24),      // can10 // IP bus byte enable bits [31:24]
    .ips_byte_7_0               (platform_int_afcb2_fcb_byte_7_0),        // can10 // IP bus byte enable bits [ 7:0]
    .ips_module_en              (misc_glue_cppe_periph_can10_fob_module_en), // can10 // IP bus module enable
    .ips_rwb                    (platform_int_afcb2_fcb_rwb),             // can10 // IP bus read/write
    .ips_supervisor_access      (platform_int_afcb2_fcb_supervisor_access), // can10 // IP bus supervisor access
    .ips_test_access            (misc_glue_cppe_periph_fcb_test_access_can10), // can10 // IP bus test access
    .ips_wdata                  (platform_int_afcb2_fcb_wdata[31:0]),     // can10 // IP bus write data bus
    .ipt_se_async               (tcu_fct_se_async[0]),                    // can10 // DFT scan enable test mode pin
    .timestamp_base             (can_timestamp_base[31:0]),                // can10 // External timestamp base
    .tmr_tick_ext               (can10_tmr_tick_ext)                      // can10 // External timer tick
);
`endif
// can10 instance end


// cpu1_tcm_wrap instance start
`ifdef FPGA_SYN
assign bisr_so_1 = 'b0;
assign ijtag_so_1 = 'b0;
assign cpu1_tcm_wrap_q_0[38:0] = 'b0;
assign cpu1_tcm_wrap_q_1[38:0] = 'b0;
assign cpu1_tcm_wrap_q_2[38:0] = 'b0;
assign cpu1_tcm_wrap_q_3[38:0] = 'b0;
assign {
                                cpu1_tcm_wrap_so_0_1_nc,            // [1]
                                cpu1_tcm_wrap_so_0_0_nc             // [0]
                            } = 'b0;
assign {
                                cpu1_tcm_wrap_so_1_1_nc,            // [1]
                                cpu1_tcm_wrap_so_1_0_nc             // [0]
                            } = 'b0;
assign {
                                cpu1_tcm_wrap_so_2_1_nc,            // [1]
                                cpu1_tcm_wrap_so_2_0_nc             // [0]
                            } = 'b0;
assign {
                                cpu1_tcm_wrap_so_3_1_nc,            // [1]
                                cpu1_tcm_wrap_so_3_0_nc             // [0]
                            } = 'b0;
assign mct_mbist_done[1] = 'b0;
assign mct_mbist_pass[1] = 'b0;
`else
cppe_ram_wrap cpu1_tcm_wrap(
    // Outputs
    .bisr_so                 (bisr_so_1),                             // cpu1_tcm_wrap
    .ijtag_so                (ijtag_so_1),                            // cpu1_tcm_wrap
    .q_0                     (cpu1_tcm_wrap_q_0[38:0]),               // cpu1_tcm_wrap
    .q_1                     (cpu1_tcm_wrap_q_1[38:0]),               // cpu1_tcm_wrap
    .q_2                     (cpu1_tcm_wrap_q_2[38:0]),               // cpu1_tcm_wrap
    .q_3                     (cpu1_tcm_wrap_q_3[38:0]),               // cpu1_tcm_wrap
    .so_0                    ({
                                cpu1_tcm_wrap_so_0_1_nc,            // [1]
                                cpu1_tcm_wrap_so_0_0_nc             // [0]
                            }), // cpu1_tcm_wrap
    .so_1                    ({
                                cpu1_tcm_wrap_so_1_1_nc,            // [1]
                                cpu1_tcm_wrap_so_1_0_nc             // [0]
                            }), // cpu1_tcm_wrap
    .so_2                    ({
                                cpu1_tcm_wrap_so_2_1_nc,            // [1]
                                cpu1_tcm_wrap_so_2_0_nc             // [0]
                            }), // cpu1_tcm_wrap
    .so_3                    ({
                                cpu1_tcm_wrap_so_3_1_nc,            // [1]
                                cpu1_tcm_wrap_so_3_0_nc             // [0]
                            }), // cpu1_tcm_wrap
    .sys_test_done           (mct_mbist_done[1]),                     // cpu1_tcm_wrap
    .sys_test_pass           (mct_mbist_pass[1]),                     // cpu1_tcm_wrap
    // Inputs
    .a_0                     (cpu1_itcm_decoder_ADR_out[12:0]),       // cpu1_tcm_wrap
    .a_1                     (cpu1_itcm_decoder_ADR_out[25:13]),      // cpu1_tcm_wrap
    .a_2                     (cpu1_dtc_decoder_ADR_out[12:0]),        // cpu1_tcm_wrap
    .a_3                     (cpu1_dtc_decoder_ADR_out[25:13]),       // cpu1_tcm_wrap
    .bisr_clk                (bisr_clk),                              // cpu1_tcm_wrap
    .bisr_reset              (bisr_reset),                           // cpu1_tcm_wrap
    .bisr_shift_en           (bisr_shift_en),                        // cpu1_tcm_wrap
    .bisr_si                 (bisr_so_0),                            // cpu1_tcm_wrap
    .cen_0                   (cpu1_itcm_decoder_cs_b_out[0]),         // cpu1_tcm_wrap
    .cen_1                   (cpu1_itcm_decoder_cs_b_out[1]),         // cpu1_tcm_wrap
    .cen_2                   (cpu1_dtc_decoder_cs_b_out[0]),          // cpu1_tcm_wrap
    .cen_3                   (cpu1_dtc_decoder_cs_b_out[1]),          // cpu1_tcm_wrap
    .clk_0                   (cpu1_itcm_decoder_clk_out[0]),          // cpu1_tcm_wrap
    .clk_1                   (cpu1_itcm_decoder_clk_out[1]),          // cpu1_tcm_wrap
    .clk_2                   (cpu1_dtc_decoder_clk_out[0]),           // cpu1_tcm_wrap
    .clk_3                   (cpu1_dtc_decoder_clk_out[1]),           // cpu1_tcm_wrap
    .d_0                     (cpu1_itcm_decoder_D_out[38:0]),          // cpu1_tcm_wrap
    .d_1                     (cpu1_itcm_decoder_D_out[38:0]),          // cpu1_tcm_wrap
    .d_2                     (cpu1_dtc_decoder_D_out[38:0]),           // cpu1_tcm_wrap
    .d_3                     (cpu1_dtc_decoder_D_out[77:39]),          // cpu1_tcm_wrap
    .dftrambyp_0             (1'b0),                                  // cpu1_tcm_wrap
    .dftrambyp_1             (1'b0),                                  // cpu1_tcm_wrap
    .dftrambyp_2             (1'b0),                                  // cpu1_tcm_wrap
    .dftrambyp_3             (1'b0),                                  // cpu1_tcm_wrap
    .ema_0                   (3'b111),                                // cpu1_tcm_wrap
    .ema_1                   (3'b111),                                // cpu1_tcm_wrap
    .ema_2                   (3'b111),                                // cpu1_tcm_wrap
    .ema_3                   (3'b111),                                // cpu1_tcm_wrap
    .emas_0                  (1'b1),                                  // cpu1_tcm_wrap
    .emas_1                  (1'b1),                                  // cpu1_tcm_wrap
    .emas_2                  (1'b1),                                  // cpu1_tcm_wrap
    .emas_3                  (1'b1),                                  // cpu1_tcm_wrap
    .emaw_0                  (2'b11),                                 // cpu1_tcm_wrap
    .emaw_1                  (2'b11),                                 // cpu1_tcm_wrap
    .emaw_2                  (2'b11),                                 // cpu1_tcm_wrap
    .emaw_3                  (2'b11),                                 // cpu1_tcm_wrap
    .gwen_0                  (cpu1_itcm_decoder_WE_b_out[0]),         // cpu1_tcm_wrap
    .gwen_1                  (cpu1_itcm_decoder_WE_b_out[1]),         // cpu1_tcm_wrap
    .gwen_2                  (cpu1_dtc_decoder_WE_b_out[0]),          // cpu1_tcm_wrap
    .gwen_3                  (cpu1_dtc_decoder_WE_b_out[1]),          // cpu1_tcm_wrap
    .ijtag_ce                (ijtag_ce),                              // cpu1_tcm_wrap
    .ijtag_reset             (ijtag_reset),                           // cpu1_tcm_wrap
    .ijtag_se                (ijtag_se),                              // cpu1_tcm_wrap
    .ijtag_sel               (ijtag_sel),                             // cpu1_tcm_wrap
    .ijtag_si                (ijtag_so_0),                            // cpu1_tcm_wrap
    .ijtag_tck               (ijtag_tck),                             // cpu1_tcm_wrap
    .ijtag_ue                (ijtag_ue),                              // cpu1_tcm_wrap
    .ltest_en                (ltest_en),                              // cpu1_tcm_wrap
    .mcp_bounding_en         (mcp_bounding_en),                       // cpu1_tcm_wrap
    .memory_bypass_en        (memory_bypass_en),                      // cpu1_tcm_wrap
    .rawl_0                  (1'b0),                                  // cpu1_tcm_wrap
    .rawl_1                  (1'b0),                                  // cpu1_tcm_wrap
    .rawl_2                  (1'b0),                                  // cpu1_tcm_wrap
    .rawl_3                  (1'b0),                                  // cpu1_tcm_wrap
    .rawlm_0                 (2'b0),                                  // cpu1_tcm_wrap
    .rawlm_1                 (2'b0),                                  // cpu1_tcm_wrap
    .rawlm_2                 (2'b0),                                  // cpu1_tcm_wrap
    .rawlm_3                 (2'b0),                                  // cpu1_tcm_wrap
    .rdt_0                   (1'b0),                                  // cpu1_tcm_wrap
    .rdt_1                   (1'b0),                                  // cpu1_tcm_wrap
    .rdt_2                   (1'b0),                                  // cpu1_tcm_wrap
    .rdt_3                   (1'b0),                                  // cpu1_tcm_wrap
    .ret1n_0                 (1'b1),                                  // cpu1_tcm_wrap
    .ret1n_1                 (1'b1),                                  // cpu1_tcm_wrap
    .ret1n_2                 (1'b1),                                  // cpu1_tcm_wrap
    .ret1n_3                 (1'b1),                                  // cpu1_tcm_wrap
    .scan_en                 (scan_en),                               // cpu1_tcm_wrap
    .se_0                    (1'b0),                                  // cpu1_tcm_wrap
    .se_1                    (1'b0),                                  // cpu1_tcm_wrap
    .se_2                    (1'b0),                                  // cpu1_tcm_wrap
    .se_3                    (1'b0),                                  // cpu1_tcm_wrap
    .si_0                    (2'b0),                                  // cpu1_tcm_wrap
    .si_1                    (2'b0),                                  // cpu1_tcm_wrap
    .si_2                    (2'b0),                                  // cpu1_tcm_wrap
    .si_3                    (2'b0),                                  // cpu1_tcm_wrap
    .stov_0                  (1'b0),                                  // cpu1_tcm_wrap
    .stov_1                  (1'b0),                                  // cpu1_tcm_wrap
    .stov_2                  (1'b0),                                  // cpu1_tcm_wrap
    .stov_3                  (1'b0),                                  // cpu1_tcm_wrap
    .sys_algo_select         (mct_mbist_alg[3:0]),                    // cpu1_tcm_wrap
    .sys_bira_en             (mct_mbist_bira_en),                     // cpu1_tcm_wrap
    .sys_clock               (clkgen_dft_bus_test_clk),               // cpu1_tcm_wrap
    .sys_ctrl_select         (mct_mbist_sel[1]),                      // cpu1_tcm_wrap
    .sys_preserve_test_inputs(mct_mbist_preserve),                   // cpu1_tcm_wrap
    .sys_reset               (fcg_sync_early_reset_b),                // cpu1_tcm_wrap
    .sys_retention_test_phase(mct_mbist_ret_phase[1:0]),              // cpu1_tcm_wrap
    .sys_select_common_algo  (mct_mbist_alg[4]),                      // cpu1_tcm_wrap
    .sys_test_init           (mct_mbist_init),                        // cpu1_tcm_wrap
    .sys_test_start          (mct_mbist_invoke),                      // cpu1_tcm_wrap
    .wabl_0                  (1'b0),                                  // cpu1_tcm_wrap
    .wabl_1                  (1'b0),                                  // cpu1_tcm_wrap
    .wabl_2                  (1'b0),                                  // cpu1_tcm_wrap
    .wabl_3                  (1'b0),                                  // cpu1_tcm_wrap
    .wablm_0                 (3'b0),                                  // cpu1_tcm_wrap
    .wablm_1                 (3'b0),                                  // cpu1_tcm_wrap
    .wablm_2                 (3'b0),                                  // cpu1_tcm_wrap
    .wablm_3                 (3'b0)                                   // cpu1_tcm_wrap
);
`endif
// cpu1_tcm_wrap instance end



endmodule

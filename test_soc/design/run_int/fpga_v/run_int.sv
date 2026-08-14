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

`ifdef FPGA_SYN
  wire run_clk_buf;
  BUFG bufg_run_int (.O(run_clk_buf), .I(clk));
`endif






//////











);

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
  wire [31:0] debug_run_irq;
  ila_run_int debug_ila (.clk(clk), .probe0(irq));
`endif


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


// eftu_mce_wrap instance start
`ifdef FPGA_SYN
assign eftu_mce_wrap_ijtag_so = 'b0;
assign eftu_mce_wrap_q_0[31:0] = 'b0;
assign eftu_mce_wrap_q_1[31:0] = 'b0;
assign eftu_mce_wrap_q_2[15:0] = 'b0;
assign eftu_mce_wrap_q_3[15:0] = 'b0;
assign eftu_mce_wrap_so_0_1_0_nc[1:0] = 'b0;
assign eftu_mce_wrap_so_1_1_0_nc[1:0] = 'b0;
assign eftu_mce_wrap_so_2_1_0_nc[1:0] = 'b0;
assign eftu_mce_wrap_so_3_1_0_nc[1:0] = 'b0;
assign eftu_mce_wrap_sys_test_done_0_nc = 'b0;
assign eftu_mce_wrap_sys_test_pass_0_nc = 'b0;
`else
eftu_wrap eftu_mce_wrap (
    // Outputs
    .ijtag_so           (eftu_mce_wrap_ijtag_so),
    .q_0                (eftu_mce_wrap_q_0[31:0]),
    .q_1                (eftu_mce_wrap_q_1[31:0]),
    .q_2                (eftu_mce_wrap_q_2[15:0]),
    .q_3                (eftu_mce_wrap_q_3[15:0]),
    .so_0               (eftu_mce_wrap_so_0_1_0_nc[1:0]),
    .so_1               (eftu_mce_wrap_so_1_1_0_nc[1:0]),
    .so_2               (eftu_mce_wrap_so_2_1_0_nc[1:0]),
    .so_3               (eftu_mce_wrap_so_3_1_0_nc[1:0]),
    .sys_test_done      (eftu_mce_wrap_sys_test_done_0_nc),
    .sys_test_pass      (eftu_mce_wrap_sys_test_pass_0_nc),

    // Inputs
    .a_0                (eftu_top0_sram_addr[9:2]),
    .a_1                (eftu_top1_sram_addr[9:2]),
    .a_2                (eftu_top0_iram_addr[11:1]),
    .a_3                (eftu_top1_iram_addr[11:1]),
    .cen_0              (eftu_top0_sram_cs_b),
    .cen_1              (eftu_top1_sram_cs_b),
    .cen_2              (eftu_top0_iram_cs_b),
    .cen_3              (eftu_top1_iram_cs_b),
    .clk_0              (pcc_run_int_fcg_clk_pcc_EFTU_MCE1),
    .clk_1              (pcc_run_int_fcg_clk_pcc_EFTU_MCE1),
    .clk_2              (pcc_run_int_fcg_clk_pcc_EFTU_MCE0),
    .clk_3              (pcc_run_int_fcg_clk_pcc_EFTU_MCE1),
    .d_0                (eftu_top0_sram_wdata[31:0]),
    .d_1                (eftu_top1_sram_wdata[31:0]),
    .d_2                (eftu_top0_iram_wdata[15:0]),
    .d_3                (eftu_top1_iram_wdata[15:0]),
    .dftrambyp_0        (1'b0),
    .dftrambyp_1        (1'b0),
    .dftrambyp_2        (1'b0),
    .dftrambyp_3        (1'b0),
    .ema_0              (misc_glue_pd1_sim_ram_EMA[2:0]),
    .ema_1              (misc_glue_pd1_sim_ram_EMA[2:0]),
    .ema_2              (misc_glue_pd1_sim_ram_EMA[2:0]),
    .ema_3              (misc_glue_pd1_sim_ram_EMA[2:0]),
    .emas_0             (misc_glue_pd1_sim_ram_EMAS),
    .emas_1             (misc_glue_pd1_sim_ram_EMAS),
    .emas_2             (misc_glue_pd1_sim_ram_EMAS),
    .emas_3             (misc_glue_pd1_sim_ram_EMAS),
    .emaw_0             (misc_glue_pd1_sim_ram_EMAW[1:0]),
    .emaw_1             (misc_glue_pd1_sim_ram_EMAW[1:0]),
    .emaw_2             (misc_glue_pd1_sim_ram_EMAW[1:0]),
    .emaw_3             (misc_glue_pd1_sim_ram_EMAW[1:0]),
    .gwen_2             (eftu_top0_sram_we_b),
    .gwen_3             (eftu_top1_sram_we_b),
    .ijtag_ce           (run_int_tcu_mbist_ijtag_to_ce),
    .ijtag_reset        (run_int_tcu_mbist_ijtag_to_reset),
    .ijtag_se           (run_int_tcu_mbist_ijtag_to_se),
    .ijtag_sel          (run_int_tcu_mbist_ijtag_to_sel),
    .ijtag_si           (flexcan_dma_wrap_ijtag_so),
    .ijtag_tck          (run_int_tcu_mbist_ijtag_to_tck),
    .ijtag_ue           (run_int_tcu_mbist_ijtag_to_ue),
    .ltest_en           (run_int_tcu_ltest_to_en),
    .mcp_bounding_en    (run_int_tcu_ltest_to_mcp_bounding_en),
    .memory_bypass_en   (run_int_tcu_ltest_to_mem_bypass_en),
    .rawl_0             (1'b0),
    .rawl_1             (1'b0),
    .rawl_2             (1'b0),
    .rawl_3             (1'b0),
    .rawlm_0            (2'b0),
    .rawlm_1            (2'b0),
    .rawlm_2            (2'b0),
    .rawlm_3            (2'b0),
    .rdt_0              (1'b0),
    .rdt_1              (1'b0),
    .rdt_2              (1'b0),
    .rdt_3              (1'b0),
    .ret1n_0            (BUF1_int_glue_ram_pd_b_wrap_out),
    .ret1n_1            (BUF1_int_glue_ram_pd_b_wrap_out),
    .ret1n_2            (BUF1_int_glue_ram_pd_b_wrap_out),
    .ret1n_3            (BUF1_int_glue_ram_pd_b_wrap_out),
    .scan_en            (run_int_tcu_ltest_to_scan_en),
    .se_0               (1'b0),
    .se_1               (1'b0),
    .se_2               (1'b0),
    .se_3               (1'b0),
    .si_0               (2'b0),
    .si_1               (2'b0),
    .si_2               (2'b0),
    .si_3               (2'b0),
    .stov_2             (1'b0),
    .stov_3             (1'b0),
    .sys_algo_select    (mct_mbist_alg[3:0]),
    .sys_clock          (clkgen_run_bus_test_clk),
    .sys_ctrl_select    (1'b0),
    .sys_preserve_test_inputs (mct_mbist_preserve),
    .sys_reset          (tcu_rgm_fcg_async_early_reset_b),
    .sys_retention_test_phase (mct_mbist_ret_phase[1:0]),
    .sys_select_common_algo (1'b0),
    .sys_test_init      (mct_mbist_init),
    .sys_test_start     (mct_mbist_invoke),
    .wabl_0             (1'b0),
    .wabl_1             (1'b0),
    .wabl_2             (1'b0),
    .wabl_3             (1'b0),
    .wablm_0            (2'b0),
    .wablm_1            (3'b0),
    .wablm_2            (3'b0),
    .wablm_3            (3'b0),
    .wen_0              (eftu_top0_iram_we_b),
    .wen_1              (eftu_top1_iram_we_b)
);
`endif
// eftu_mce_wrap instance end

// eftu_top0 instance start
`ifdef FPGA_SYN
assign {
                                eftu_top0_cmu0_cmu_eclk_en_2_nc,    // [2]
                                eftu_top0_cmu0_cmu_eclk_en_1,       // [1]
                                eftu_top0_cmu0_cmu_eclk_en_0_nc     // [0]
                            } = 'b0;
assign {
                                eftu_top0_eftu_cnt_out0_71_24_nc[47:0], // [2:1]
                                eftu_top0_eftu0_cnt_out0[23:0]          // [0]
                            } = 'b0;
assign {
                                eftu_top0_eftu_cnt_out1_71_24_nc[47:0], // [2:1]
                                eftu_top0_eftu0_cnt_out1[23:0]          // [0]
                            } = 'b0;
assign {
                                eftu_top0_eftu2_err_irq,    // [2]
                                eftu_top0_eftu1_err_irq,    // [1]
                                eftu_top0_eftu0_err_irq     // [0]
                            } = 'b0;
assign {
                                eftu_top0_eftu2_fcb_rdata[31:0], // [2]
                                eftu_top0_eftu1_fcb_rdata[31:0], // [1]
                                eftu_top0_eftu0_fcb_rdata[31:0]  // [0]
                            } = 'b0;
assign {
                                eftu_top0_eftu2_fcb_xfr_err,    // [2]
                                eftu_top0_eftu1_fcb_xfr_err,    // [1]
                                eftu_top0_eftu0_fcb_xfr_err     // [0]
                            } = 'b0;
assign {
                                eftu_top0_eftu2_fcb_xfr_wait,   // [2]
                                eftu_top0_eftu1_fcb_xfr_wait,   // [1]
                                eftu_top0_eftu0_fcb_xfr_wait    // [0]
                            } = 'b0;
assign eftu_top0_eftu_gtom_out[63:0] = 'b0;
assign eftu_top0_eftu_hrpwm_cnt_39_0_nc[39:0] = 'b0;
assign eftu_top0_eftu_hrpwm_shut_off_7_0_nc[7:0] = 'b0;
assign {
                                eftu_top0_eftu2_out0[15:0],  // [2]
                                eftu_top0_eftu1_out0[15:0],  // [1]
                                eftu_top0_eftu0_out0[15:0]   // [0]
                            } = 'b0;
assign eftu_top0_eftu_out1_47_0_nc[47:0] = 'b0;
assign eftu_top0_eftu_out_h_7_0_nc[7:0] = 'b0;
assign {
                                eftu_top0_eftu_spe_bldc_pwm_11_6_nc[5:0], // [1]
                                eftu_top0_eftu0_spe0_bldc_pwm[5:0],       // [0]
                                eftu_top0_eftu0_spe1_bldc_pwm[5:0]        // [0]
                            } = 'b0;
assign {
                                eftu_top0_eftu_spe_dir_3_2_nc[1:0], // [1]
                                eftu_top0_eftu0_spe_dir[1:0]         // [0]
                            } = 'b0;
assign {
                                eftu_top0_eftu_spe_nipd_3_2_nc[1:0], // [1]
                                eftu_top0_eftu0_spe_nipd[1:0]        // [0]
                            } = 'b0;
assign {
                                eftu_top0_eftu2_tim_err_irq[7:0], // [2]
                                eftu_top0_eftu1_tim_err_irq[7:0], // [1]
                                eftu_top0_eftu0_tim_err_irq[7:0]  // [0]
                            } = 'b0;
assign {
                                eftu_top0_eftu2_tim_irq[7:0], // [2]
                                eftu_top0_eftu1_tim_irq[7:0], // [1]
                                eftu_top0_eftu0_tim_irq[7:0]  // [0]
                            } = 'b0;
assign {
                                eftu_top0_eftu2_tom_irq[15:0], // [2]
                                eftu_top0_eftu1_tom_irq[15:0], // [1]
                                eftu_top0_eftu0_tom_irq[15:0]  // [0]
                            } = 'b0;
assign eftu_top0_eftu_trg_out[15:0] = 'b0;
assign {
                                eftu_top0_fcd_eftu2_req[15:0], // [2]
                                eftu_top0_fcd_eftu1_req[15:0], // [1]
                                eftu_top0_fcd_eftu0_req[15:0]  // [0]
                            } = 'b0;
assign eftu_top0_host_fcb_rdata[31:0] = 'b0;
assign eftu_top0_host_fcb_xfr_error = 'b0;
assign eftu_top0_host_fcb_xfr_wait = 'b0;
assign {
                                eftu_top0_iram_addr[11:1], // [11:1]
                                eftu_top0_iram_addr_0_nc   // [0]
                            } = 'b0;
assign eftu_top0_iram_cs_b = 1'b1;
assign eftu_top0_iram_wdata[15:0] = 'b0;
assign eftu_top0_iram_we_b = 1'b1;
assign eftu_top0_mce_irq_0_nc = 'b0;
assign {
                                eftu_top0_sram_addr[9:2],    // [9:2]
                                eftu_top0_sram_addr_1_0_nc[1:0] // [1:0]
                            } = 'b0;
assign eftu_top0_sram_cs_b = 1'b1;
assign eftu_top0_sram_wdata[31:0] = 'b0;
assign eftu_top0_sram_we_b = 1'b1;
assign eftu_top0_thread_status_run_3_0_nc[3:0] = 'b0;
`else
eftu_top #(
    .EFTU_CLS_NUM(3),
    .EFTU_DMA_CHNL(16),
    .EFTU_HRPWM_NUMS(0),
    .IRAM_SIZE(4096),
    .SPE_INST(2),
    .SRAM_SIZE(1024)
) eftu_top0 (
    // Outputs
    .cmu0_cmu_eclk_en       ({
                                eftu_top0_cmu0_cmu_eclk_en_2_nc,    // [2]
                                eftu_top0_cmu0_cmu_eclk_en_1,       // [1]
                                eftu_top0_cmu0_cmu_eclk_en_0_nc     // [0]
                            }),
    .eftu_cnt_out0          ({
                                eftu_top0_eftu_cnt_out0_71_24_nc[47:0], // [2:1]
                                eftu_top0_eftu0_cnt_out0[23:0]          // [0]
                            }),
    .eftu_cnt_out1          ({
                                eftu_top0_eftu_cnt_out1_71_24_nc[47:0], // [2:1]
                                eftu_top0_eftu0_cnt_out1[23:0]          // [0]
                            }),
    .eftu_err_irq           ({
                                eftu_top0_eftu2_err_irq,    // [2]
                                eftu_top0_eftu1_err_irq,    // [1]
                                eftu_top0_eftu0_err_irq     // [0]
                            }),
    .eftu_fcb_rdata         ({
                                eftu_top0_eftu2_fcb_rdata[31:0], // [2]
                                eftu_top0_eftu1_fcb_rdata[31:0], // [1]
                                eftu_top0_eftu0_fcb_rdata[31:0]  // [0]
                            }),
    .eftu_fcb_xfr_err       ({
                                eftu_top0_eftu2_fcb_xfr_err,    // [2]
                                eftu_top0_eftu1_fcb_xfr_err,    // [1]
                                eftu_top0_eftu0_fcb_xfr_err     // [0]
                            }),
    .eftu_fcb_xfr_wait      ({
                                eftu_top0_eftu2_fcb_xfr_wait,   // [2]
                                eftu_top0_eftu1_fcb_xfr_wait,   // [1]
                                eftu_top0_eftu0_fcb_xfr_wait    // [0]
                            }),
    .eftu_gtom_out          (eftu_top0_eftu_gtom_out[63:0]),
    .eftu_hrpwm_cnt         (eftu_top0_eftu_hrpwm_cnt_39_0_nc[39:0]),
    .eftu_hrpwm_shut_off    (eftu_top0_eftu_hrpwm_shut_off_7_0_nc[7:0]),
    .eftu_out0              ({
                                eftu_top0_eftu2_out0[15:0],  // [2]
                                eftu_top0_eftu1_out0[15:0],  // [1]
                                eftu_top0_eftu0_out0[15:0]   // [0]
                            }),
    .eftu_out1              (eftu_top0_eftu_out1_47_0_nc[47:0]),
    .eftu_out_h             (eftu_top0_eftu_out_h_7_0_nc[7:0]),
    .eftu_spe_bldc_pwm      ({
                                eftu_top0_eftu_spe_bldc_pwm_11_6_nc[5:0], // [1]
                                eftu_top0_eftu0_spe0_bldc_pwm[5:0],       // [0]
                                eftu_top0_eftu0_spe1_bldc_pwm[5:0]        // [0]
                            }),
    .eftu_spe_dir           ({
                                eftu_top0_eftu_spe_dir_3_2_nc[1:0], // [1]
                                eftu_top0_eftu0_spe_dir[1:0]         // [0]
                            }),
    .eftu_spe_nipd          ({
                                eftu_top0_eftu_spe_nipd_3_2_nc[1:0], // [1]
                                eftu_top0_eftu0_spe_nipd[1:0]        // [0]
                            }),
    .eftu_tim_err_irq       ({
                                eftu_top0_eftu2_tim_err_irq[7:0], // [2]
                                eftu_top0_eftu1_tim_err_irq[7:0], // [1]
                                eftu_top0_eftu0_tim_err_irq[7:0]  // [0]
                            }),
    .eftu_tim_irq           ({
                                eftu_top0_eftu2_tim_irq[7:0], // [2]
                                eftu_top0_eftu1_tim_irq[7:0], // [1]
                                eftu_top0_eftu0_tim_irq[7:0]  // [0]
                            }),
    .eftu_tom_irq           ({
                                eftu_top0_eftu2_tom_irq[15:0], // [2]
                                eftu_top0_eftu1_tom_irq[15:0], // [1]
                                eftu_top0_eftu0_tom_irq[15:0]  // [0]
                            }),
    .eftu_trg_out           (eftu_top0_eftu_trg_out[15:0]),
    .fcd_eftu_req           ({
                                eftu_top0_fcd_eftu2_req[15:0], // [2]
                                eftu_top0_fcd_eftu1_req[15:0], // [1]
                                eftu_top0_fcd_eftu0_req[15:0]  // [0]
                            }),
    .host_fcb_rdata         (eftu_top0_host_fcb_rdata[31:0]),
    .host_fcb_xfr_error     (eftu_top0_host_fcb_xfr_error),
    .host_fcb_xfr_wait      (eftu_top0_host_fcb_xfr_wait),
    .iram_addr              ({
                                eftu_top0_iram_addr[11:1], // [11:1]
                                eftu_top0_iram_addr_0_nc   // [0]
                            }),
    .iram_cs_b              (eftu_top0_iram_cs_b),
    .iram_wdata             (eftu_top0_iram_wdata[15:0]),
    .iram_we_b              (eftu_top0_iram_we_b),
    .mce_irq                (eftu_top0_mce_irq_0_nc),
    .sram_addr             ({
                                eftu_top0_sram_addr[9:2],    // [9:2]
                                eftu_top0_sram_addr_1_0_nc[1:0] // [1:0]
                            }),
    .sram_cs_b              (eftu_top0_sram_cs_b),
    .sram_wdata             (eftu_top0_sram_wdata[31:0]),
    .sram_we_b              (eftu_top0_sram_we_b),
    .thread_status_run      (eftu_top0_thread_status_run_3_0_nc[3:0]),

    // Inputs
    .eftu_dtm_aux_in        ({
                                trgsel2_mux_out[21],        // [2][7]
                                trgsel2_mux_out[20],        // [2][6]
                                BUF1_adc1_adc_acmp_result,  // [2][5]
                                eftu2_flt1,                 // [2][4]
                                trgsel2_mux_out[18],        // [2][3]
                                trgsel2_mux_out[17],        // [2][2]
                                BUF1_adc0_adc_acmp_result,  // [2][1]
                                eftu2_flt0,                 // [2][0]

                                trgsel2_mux_out[21],        // [1][7]
                                trgsel2_mux_out[20],        // [1][6]
                                BUF1_adc1_adc_acmp_result,  // [1][5]
                                eftu1_flt1,                 // [1][4]
                                trgsel2_mux_out[18],        // [1][3]
                                trgsel2_mux_out[17],        // [1][2]
                                BUF1_adc0_adc_acmp_result,  // [1][1]
                                eftu1_flt0,                 // [1][0]

                                trgsel2_mux_out[21],        // [0][7]
                                trgsel2_mux_out[20],        // [0][6]
                                BUF1_adc1_adc_acmp_result,  // [0][5]
                                eftu0_flt1,                 // [0][4]
                                trgsel2_mux_out[18],        // [0][3]
                                trgsel2_mux_out[17],        // [0][2]
                                BUF1_adc0_adc_acmp_result,  // [0][1]
                                eftu0_flt0                  // [0][0]
                            }),
    .eftu_fcb_addr          ({
                                platform_int_afcb2_fcb_addr[12:2], // [2]
                                platform_int_afcb2_fcb_addr[12:2], // [1]
                                platform_int_afcb2_fcb_addr[12:2]  // [0]
                            }),
    .eftu_fcb_byte_en       ({
                                platform_int_afcb2_fcb_byte_31_24, // [2][3]
                                platform_int_afcb2_fcb_byte_23_16, // [2][2]
                                platform_int_afcb2_fcb_byte_15_8,   // [2][1]
                                platform_int_afcb2_fcb_byte_7_0,    // [2][0]

                                platform_int_afcb2_fcb_byte_31_24, // [1][3]
                                platform_int_afcb2_fcb_byte_23_16, // [1][2]
                                platform_int_afcb2_fcb_byte_15_8,   // [1][1]
                                platform_int_afcb2_fcb_byte_7_0,    // [1][0]

                                platform_int_afcb2_fcb_byte_31_24, // [0][3]
                                platform_int_afcb2_fcb_byte_23_16, // [0][2]
                                platform_int_afcb2_fcb_byte_15_8,   // [0][1]
                                platform_int_afcb2_fcb_byte_7_0     // [0][0]
                            }),
    .eftu_fcb_module_en     ({
                                misc_glue_pdl_eftu2_fcb_module_en, // [2]
                                misc_glue_pdl_eftu1_fcb_module_en, // [1]
                                misc_glue_pdl_eftu0_fcb_module_en  // [0]
                            }),
    .eftu_fcb_rwb           ({
                                platform_int_afcb2_fcb_rwb, // [2]
                                platform_int_afcb2_fcb_rwb, // [1]
                                platform_int_afcb2_fcb_rwb  // [0]
                            }),
    .eftu_fcb_wdata         ({
                                platform_int_afcb2_fcb_wdata[31:0], // [2]
                                platform_int_afcb2_fcb_wdata[31:0], // [1]
                                platform_int_afcb2_fcb_wdata[31:0]  // [0]
                            }),
    .eftu_glb_enable        ({
                                GPR_EFTU2_GLOBAL_TIME_BASE[1:0], // [2]
                                GPR_EFTU1_GLOBAL_TIME_BASE[1:0], // [1]
                                GPR_EFTU0_GLOBAL_TIME_BASE[1:0]  // [0]
                            }),
    .eftu_int_tim           (eftu_int_tim[7:0]),
    .eftu_spe_bldc_hall     ({
                                ftu_glue_eftu0_spe1_mux_in[2:0], // [1]
                                ftu_glue_eftu0_spe0_mux_in[2:0]  // [0]
                            }),
    .eftu_tim_in            ({
                                eftu2_tim_in_7, // [2][7]
                                eftu2_tim_in_6, // [2][6]
                                eftu2_tim_in_5, // [2][5]
                                eftu2_tim_in_4, // [2][4]
                                eftu2_tim_in_3, // [2][3]
                                eftu2_tim_in_2, // [2][2]
                                eftu2_tim_in_1, // [2][1]
                                eftu2_tim_in_0, // [2][0]

                                eftu1_tim_in_7, // [1][7]
                                eftu1_tim_in_6, // [1][6]
                                eftu1_tim_in_5, // [1][5]
                                eftu1_tim_in_4, // [1][4]
                                eftu1_tim_in_3, // [1][3]
                                eftu1_tim_in_2, // [1][2]
                                eftu1_tim_in_1, // [1][1]
                                eftu1_tim_in_0, // [1][0]

                                eftu0_tim_in_7, // [0][7]
                                eftu0_tim_in_6, // [0][6]
                                eftu0_tim_in_5, // [0][5]
                                eftu0_tim_in_4, // [0][4]
                                eftu0_tim_in_3, // [0][3]
                                eftu0_tim_in_2, // [0][2]
                                eftu0_tim_in_1, // [0][1]
                                eftu0_tim_in_0  // [0][0]
                            }),
    .fcd_eftu_done          ({
                                dma_mux_fcd_ack_eftu2_fcd_req_15, // [2][15]
                                dma_mux_fcd_ack_eftu2_fcd_req_14, // [2][14]
                                dma_mux_fcd_ack_eftu2_fcd_req_13, // [2][13]
                                dma_mux_fcd_ack_eftu2_fcd_req_12, // [2][12]
                                dma_mux_fcd_ack_eftu2_fcd_req_11, // [2][11]
                                dma_mux_fcd_ack_eftu2_fcd_req_10, // [2][10]
                                dma_mux_fcd_ack_eftu2_fcd_req_9,  // [2][9]
                                dma_mux_fcd_ack_eftu2_fcd_req_8,  // [2][8]
                                dma_mux_fcd_ack_eftu2_fcd_req_7,  // [2][7]
                                dma_mux_fcd_ack_eftu2_fcd_req_6,  // [2][6]
                                dma_mux_fcd_ack_eftu2_fcd_req_5,  // [2][5]
                                dma_mux_fcd_ack_eftu2_fcd_req_4,  // [2][4]
                                dma_mux_fcd_ack_eftu2_fcd_req_3,  // [2][3]
                                dma_mux_fcd_ack_eftu2_fcd_req_2,  // [2][2]
                                dma_mux_fcd_ack_eftu2_fcd_req_1,  // [2][1]
                                dma_mux_fcd_ack_eftu2_fcd_req_0,  // [2][0]

                                dma_mux_fcd_ack_eftu1_fcd_req_15, // [1][15]
                                dma_mux_fcd_ack_eftu1_fcd_req_14, // [1][14]
                                dma_mux_fcd_ack_eftu1_fcd_req_13, // [1][13]
                                dma_mux_fcd_ack_eftu1_fcd_req_12, // [1][12]
                                dma_mux_fcd_ack_eftu1_fcd_req_11, // [1][11]
                                dma_mux_fcd_ack_eftu1_fcd_req_10, // [1][10]
                                dma_mux_fcd_ack_eftu1_fcd_req_9,  // [1][9]
                                dma_mux_fcd_ack_eftu1_fcd_req_8,  // [1][8]
                                dma_mux_fcd_ack_eftu1_fcd_req_7,  // [1][7]
                                dma_mux_fcd_ack_eftu1_fcd_req_6,  // [1][6]
                                dma_mux_fcd_ack_eftu1_fcd_req_5,  // [1][5]
                                dma_mux_fcd_ack_eftu1_fcd_req_4,  // [1][4]
                                dma_mux_fcd_ack_eftu1_fcd_req_3,  // [1][3]
                                dma_mux_fcd_ack_eftu1_fcd_req_2,  // [1][2]
                                dma_mux_fcd_ack_eftu1_fcd_req_1,  // [1][1]
                                dma_mux_fcd_ack_eftu1_fcd_req_0,  // [1][0]

                                dma_mux_fcd_ack_eftu0_fcd_req_15, // [0][15]
                                dma_mux_fcd_ack_eftu0_fcd_req_14, // [0][14]
                                dma_mux_fcd_ack_eftu0_fcd_req_13, // [0][13]
                                dma_mux_fcd_ack_eftu0_fcd_req_12, // [0][12]
                                dma_mux_fcd_ack_eftu0_fcd_req_11, // [0][11]
                                dma_mux_fcd_ack_eftu0_fcd_req_10, // [0][10]
                                dma_mux_fcd_ack_eftu0_fcd_req_9,  // [0][9]
                                dma_mux_fcd_ack_eftu0_fcd_req_8,  // [0][8]
                                dma_mux_fcd_ack_eftu0_fcd_req_7,  // [0][7]
                                dma_mux_fcd_ack_eftu0_fcd_req_6,  // [0][6]
                                dma_mux_fcd_ack_eftu0_fcd_req_5,  // [0][5]
                                dma_mux_fcd_ack_eftu0_fcd_req_4,  // [0][4]
                                dma_mux_fcd_ack_eftu0_fcd_req_3,  // [0][3]
                                dma_mux_fcd_ack_eftu0_fcd_req_2,  // [0][2]
                                dma_mux_fcd_ack_eftu0_fcd_req_1,  // [0][1]
                                dma_mux_fcd_ack_eftu0_fcd_req_0   // [0][0]
                            }),
    .fcf_ind_tcrclk         (eftu_fcf_ind_tcrclk),
    .fcg_clk                ({
                                pcc_run_int_fcg_clk_pcc_EFTU2, // [2]
                                pcc_run_int_fcg_clk_pcc_EFTU1, // [1]
                                pcc_run_int_fcg_clk_pcc_EFTU0  // [0]
                            }),
    .fcg_debug              ({
                                pcc_run_int_fcg_debug_pcc_periph_EFTU2, // [2]
                                pcc_run_int_fcg_debug_pcc_periph_EFTU1, // [1]
                                pcc_run_int_fcg_debug_pcc_periph_EFTU0  // [0]
                            }),
    .fcg_hard_async_reset_b ({
                                pcc_run_int_fcg_reset_b_pcc_periph_EFTU2, // [2]
                                pcc_run_int_fcg_reset_b_pcc_periph_EFTU1, // [1]
                                pcc_run_int_fcg_reset_b_pcc_periph_EFTU0  // [0]
                            }),
    .fct_clk                (clkgen_dft_fct_test_tck),
    .fct_clk_se             (run_int_tcu_fct_se_gatedclk),
    .fct_scan_mode          (tcu_fct_mode_lbist_or_scan),
    .fct_se_async           (run_int_tcu_fct_se_async[0]),
    .host_fcb_addr          (platform_int_afcb2_fcb_addr[12:0]),
    .host_fcb_module_en     (misc_glue_pdl_eftu_mce0_fcb_module_en),
    .host_fcb_rwb           (platform_int_afcb2_fcb_rwb),
    .host_fcb_wdata         (platform_int_afcb2_fcb_wdata[31:0]),
    .host_fcg_clk           (pcc_run_int_fcg_clk_pcc_EFTU_MCE0),
    .host_fcg_hard_async_reset_b (pcc_run_int_fcg_reset_b_pcc_periph_EFTU_MCE0),
    .iram_rdata             (eftu_mce_wrap_q_2[15:0]),
    .sram_rdata             (eftu_mce_wrap_q_0[31:0]),
    .status_reg_async_in    (32'h0),
    .status_regs_sync_in    (256'h0),
    .status_regs_sync_valid_in (8'h0),
    .sw_trigger_flags       (32'h0),
    .trigger_in             (96'h0)
);
`endif
// eftu_top0 instance end



// rtu1_cache_wrap instance start
`ifdef FPGA_SYN
assign rtu1_cache_wrap_ijtag_so = 'b0;
assign rtu1_cache_wrap_q_0[127:0] = 'b0;
assign rtu1_cache_wrap_q_1[25:0] = 'b0;
assign rtu1_cache_wrap_q_10[25:0] = 'b0;
assign rtu1_cache_wrap_q_11[25:0] = 'b0;
assign rtu1_cache_wrap_q_12[25:0] = 'b0;
assign rtu1_cache_wrap_q_13[25:0] = 'b0;
assign rtu1_cache_wrap_q_14[25:0] = 'b0;
assign rtu1_cache_wrap_q_15[25:0] = 'b0;
assign rtu1_cache_wrap_q_16[25:0] = 'b0;
assign rtu1_cache_wrap_q_17[70:0] = 'b0;
assign rtu1_cache_wrap_q_18[70:0] = 'b0;
assign rtu1_cache_wrap_q_19[70:0] = 'b0;
assign rtu1_cache_wrap_q_2[25:0] = 'b0;
assign rtu1_cache_wrap_q_20[70:0] = 'b0;
assign rtu1_cache_wrap_q_21[70:0] = 'b0;
assign rtu1_cache_wrap_q_22[70:0] = 'b0;
assign rtu1_cache_wrap_q_23[70:0] = 'b0;
assign rtu1_cache_wrap_q_24[70:0] = 'b0;
assign rtu1_cache_wrap_q_25[37:0] = 'b0;
assign rtu1_cache_wrap_q_26[37:0] = 'b0;
assign rtu1_cache_wrap_q_27[37:0] = 'b0;
assign rtu1_cache_wrap_q_28[37:0] = 'b0;
assign rtu1_cache_wrap_q_29[37:0] = 'b0;
assign rtu1_cache_wrap_q_3[25:0] = 'b0;
assign rtu1_cache_wrap_q_30[37:0] = 'b0;
assign rtu1_cache_wrap_q_31[37:0] = 'b0;
assign rtu1_cache_wrap_q_32[37:0] = 'b0;
assign rtu1_cache_wrap_q_33[37:0] = 'b0;
assign rtu1_cache_wrap_q_34[37:0] = 'b0;
assign rtu1_cache_wrap_q_35[37:0] = 'b0;
assign rtu1_cache_wrap_q_36[37:0] = 'b0;
assign rtu1_cache_wrap_q_37[37:0] = 'b0;
assign rtu1_cache_wrap_q_38[37:0] = 'b0;
assign rtu1_cache_wrap_q_39[37:0] = 'b0;
assign rtu1_cache_wrap_q_4[25:0] = 'b0;
assign rtu1_cache_wrap_q_40[37:0] = 'b0;
assign rtu1_cache_wrap_q_5[25:0] = 'b0;
assign rtu1_cache_wrap_q_6[25:0] = 'b0;
assign rtu1_cache_wrap_q_7[25:0] = 'b0;
assign rtu1_cache_wrap_q_8[25:0] = 'b0;
assign rtu1_cache_wrap_q_9[25:0] = 'b0;
assign {
                        rtu1_cache_wrap_so_0_1_nc,
                        rtu1_cache_wrap_so_0_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_1_1_nc,
                        rtu1_cache_wrap_so_1_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_10_1_nc,
                        rtu1_cache_wrap_so_10_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_11_1_nc,
                        rtu1_cache_wrap_so_11_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_12_1_nc,
                        rtu1_cache_wrap_so_12_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_13_1_nc,
                        rtu1_cache_wrap_so_13_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_14_1_nc,
                        rtu1_cache_wrap_so_14_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_15_1_nc,
                        rtu1_cache_wrap_so_15_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_16_1_nc,
                        rtu1_cache_wrap_so_16_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_17_1_nc,
                        rtu1_cache_wrap_so_17_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_18_1_nc,
                        rtu1_cache_wrap_so_18_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_19_1_nc,
                        rtu1_cache_wrap_so_19_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_2_1_nc,
                        rtu1_cache_wrap_so_2_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_20_1_nc,
                        rtu1_cache_wrap_so_20_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_21_1_nc,
                        rtu1_cache_wrap_so_21_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_22_1_nc,
                        rtu1_cache_wrap_so_22_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_23_1_nc,
                        rtu1_cache_wrap_so_23_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_24_1_nc,
                        rtu1_cache_wrap_so_24_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_25_1_nc,
                        rtu1_cache_wrap_so_25_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_26_1_nc,
                        rtu1_cache_wrap_so_26_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_27_1_nc,
                        rtu1_cache_wrap_so_27_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_28_1_nc,
                        rtu1_cache_wrap_so_28_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_29_1_nc,
                        rtu1_cache_wrap_so_29_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_3_1_nc,
                        rtu1_cache_wrap_so_3_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_30_1_nc,
                        rtu1_cache_wrap_so_30_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_31_1_nc,
                        rtu1_cache_wrap_so_31_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_32_1_nc,
                        rtu1_cache_wrap_so_32_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_33_1_nc,
                        rtu1_cache_wrap_so_33_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_34_1_nc,
                        rtu1_cache_wrap_so_34_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_35_1_nc,
                        rtu1_cache_wrap_so_35_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_36_1_nc,
                        rtu1_cache_wrap_so_36_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_37_1_nc,
                        rtu1_cache_wrap_so_37_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_38_1_nc,
                        rtu1_cache_wrap_so_38_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_39_1_nc,
                        rtu1_cache_wrap_so_39_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_4_1_nc,
                        rtu1_cache_wrap_so_4_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_40_1_nc,
                        rtu1_cache_wrap_so_40_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_5_1_nc,
                        rtu1_cache_wrap_so_5_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_6_1_nc,
                        rtu1_cache_wrap_so_6_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_7_1_nc,
                        rtu1_cache_wrap_so_7_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_8_1_nc,
                        rtu1_cache_wrap_so_8_0_nc
                    } = 'b0;
assign {
                        rtu1_cache_wrap_so_9_1_nc,
                        rtu1_cache_wrap_so_9_0_nc
                    } = 'b0;
assign mct_mbist_done_bus[15] = 'b0;
assign mct_mbist_pass_bus[15] = 'b0;
`else
cache_wrap rtu1_cache_wrap(
// Outputs
    .ijtag_so       (rtu1_cache_wrap_ijtag_so),
    .q_0            (rtu1_cache_wrap_q_0[127:0]),
    .q_1            (rtu1_cache_wrap_q_1[25:0]),
    .q_10           (rtu1_cache_wrap_q_10[25:0]),
    .q_11           (rtu1_cache_wrap_q_11[25:0]),
    .q_12           (rtu1_cache_wrap_q_12[25:0]),
    .q_13           (rtu1_cache_wrap_q_13[25:0]),
    .q_14           (rtu1_cache_wrap_q_14[25:0]),
    .q_15           (rtu1_cache_wrap_q_15[25:0]),
    .q_16           (rtu1_cache_wrap_q_16[25:0]),
    .q_17           (rtu1_cache_wrap_q_17[70:0]),
    .q_18           (rtu1_cache_wrap_q_18[70:0]),
    .q_19           (rtu1_cache_wrap_q_19[70:0]),
    .q_2            (rtu1_cache_wrap_q_2[25:0]),
    .q_20           (rtu1_cache_wrap_q_20[70:0]),
    .q_21           (rtu1_cache_wrap_q_21[70:0]),
    .q_22           (rtu1_cache_wrap_q_22[70:0]),
    .q_23           (rtu1_cache_wrap_q_23[70:0]),
    .q_24           (rtu1_cache_wrap_q_24[70:0]),
    .q_25           (rtu1_cache_wrap_q_25[37:0]),
    .q_26           (rtu1_cache_wrap_q_26[37:0]),
    .q_27           (rtu1_cache_wrap_q_27[37:0]),
    .q_28           (rtu1_cache_wrap_q_28[37:0]),
    .q_29           (rtu1_cache_wrap_q_29[37:0]),
    .q_3            (rtu1_cache_wrap_q_3[25:0]),
    .q_30           (rtu1_cache_wrap_q_30[37:0]),
    .q_31           (rtu1_cache_wrap_q_31[37:0]),
    .q_32           (rtu1_cache_wrap_q_32[37:0]),
    .q_33           (rtu1_cache_wrap_q_33[37:0]),
    .q_34           (rtu1_cache_wrap_q_34[37:0]),
    .q_35           (rtu1_cache_wrap_q_35[37:0]),
    .q_36           (rtu1_cache_wrap_q_36[37:0]),
    .q_37           (rtu1_cache_wrap_q_37[37:0]),
    .q_38           (rtu1_cache_wrap_q_38[37:0]),
    .q_39           (rtu1_cache_wrap_q_39[37:0]),
    .q_4            (rtu1_cache_wrap_q_4[25:0]),
    .q_40           (rtu1_cache_wrap_q_40[37:0]),
    .q_5            (rtu1_cache_wrap_q_5[25:0]),
    .q_6            (rtu1_cache_wrap_q_6[25:0]),
    .q_7            (rtu1_cache_wrap_q_7[25:0]),
    .q_8            (rtu1_cache_wrap_q_8[25:0]),
    .q_9            (rtu1_cache_wrap_q_9[25:0]),
    .so_0           ({
                        rtu1_cache_wrap_so_0_1_nc,
                        rtu1_cache_wrap_so_0_0_nc
                    }), // rtu1_cache_wrap
    .so_1           ({
                        rtu1_cache_wrap_so_1_1_nc,
                        rtu1_cache_wrap_so_1_0_nc
                    }), // rtu1_cache_wrap
    .so_10          ({
                        rtu1_cache_wrap_so_10_1_nc,
                        rtu1_cache_wrap_so_10_0_nc
                    }), // rtu1_cache_wrap
    .so_11          ({
                        rtu1_cache_wrap_so_11_1_nc,
                        rtu1_cache_wrap_so_11_0_nc
                    }), // rtu1_cache_wrap
    .so_12          ({
                        rtu1_cache_wrap_so_12_1_nc,
                        rtu1_cache_wrap_so_12_0_nc
                    }), // rtu1_cache_wrap
    .so_13          ({
                        rtu1_cache_wrap_so_13_1_nc,
                        rtu1_cache_wrap_so_13_0_nc
                    }), // rtu1_cache_wrap
    .so_14          ({
                        rtu1_cache_wrap_so_14_1_nc,
                        rtu1_cache_wrap_so_14_0_nc
                    }), // rtu1_cache_wrap
    .so_15          ({
                        rtu1_cache_wrap_so_15_1_nc,
                        rtu1_cache_wrap_so_15_0_nc
                    }), // rtu1_cache_wrap
    .so_16          ({
                        rtu1_cache_wrap_so_16_1_nc,
                        rtu1_cache_wrap_so_16_0_nc
                    }), // rtu1_cache_wrap
    .so_17          ({
                        rtu1_cache_wrap_so_17_1_nc,
                        rtu1_cache_wrap_so_17_0_nc
                    }), // rtu1_cache_wrap
    .so_18          ({
                        rtu1_cache_wrap_so_18_1_nc,
                        rtu1_cache_wrap_so_18_0_nc
                    }), // rtu1_cache_wrap
    .so_19          ({
                        rtu1_cache_wrap_so_19_1_nc,
                        rtu1_cache_wrap_so_19_0_nc
                    }), // rtu1_cache_wrap
    .so_2           ({
                        rtu1_cache_wrap_so_2_1_nc,
                        rtu1_cache_wrap_so_2_0_nc
                    }), // rtu1_cache_wrap
    .so_20          ({
                        rtu1_cache_wrap_so_20_1_nc,
                        rtu1_cache_wrap_so_20_0_nc
                    }), // rtu1_cache_wrap
    .so_21          ({
                        rtu1_cache_wrap_so_21_1_nc,
                        rtu1_cache_wrap_so_21_0_nc
                    }), // rtu1_cache_wrap
    .so_22          ({
                        rtu1_cache_wrap_so_22_1_nc,
                        rtu1_cache_wrap_so_22_0_nc
                    }), // rtu1_cache_wrap
    .so_23          ({
                        rtu1_cache_wrap_so_23_1_nc,
                        rtu1_cache_wrap_so_23_0_nc
                    }), // rtu1_cache_wrap
    .so_24          ({
                        rtu1_cache_wrap_so_24_1_nc,
                        rtu1_cache_wrap_so_24_0_nc
                    }), // rtu1_cache_wrap
    .so_25          ({
                        rtu1_cache_wrap_so_25_1_nc,
                        rtu1_cache_wrap_so_25_0_nc
                    }), // rtu1_cache_wrap
    .so_26          ({
                        rtu1_cache_wrap_so_26_1_nc,
                        rtu1_cache_wrap_so_26_0_nc
                    }), // rtu1_cache_wrap
    .so_27          ({
                        rtu1_cache_wrap_so_27_1_nc,
                        rtu1_cache_wrap_so_27_0_nc
                    }), // rtu1_cache_wrap
    .so_28          ({
                        rtu1_cache_wrap_so_28_1_nc,
                        rtu1_cache_wrap_so_28_0_nc
                    }), // rtu1_cache_wrap
    .so_29          ({
                        rtu1_cache_wrap_so_29_1_nc,
                        rtu1_cache_wrap_so_29_0_nc
                    }), // rtu1_cache_wrap
    .so_3           ({
                        rtu1_cache_wrap_so_3_1_nc,
                        rtu1_cache_wrap_so_3_0_nc
                    }), // rtu1_cache_wrap
    .so_30          ({
                        rtu1_cache_wrap_so_30_1_nc,
                        rtu1_cache_wrap_so_30_0_nc
                    }), // rtu1_cache_wrap
    .so_31          ({
                        rtu1_cache_wrap_so_31_1_nc,
                        rtu1_cache_wrap_so_31_0_nc
                    }), // rtu1_cache_wrap
    .so_32          ({
                        rtu1_cache_wrap_so_32_1_nc,
                        rtu1_cache_wrap_so_32_0_nc
                    }), // rtu1_cache_wrap
    .so_33          ({
                        rtu1_cache_wrap_so_33_1_nc,
                        rtu1_cache_wrap_so_33_0_nc
                    }), // rtu1_cache_wrap
    .so_34          ({
                        rtu1_cache_wrap_so_34_1_nc,
                        rtu1_cache_wrap_so_34_0_nc
                    }), // rtu1_cache_wrap
    .so_35          ({
                        rtu1_cache_wrap_so_35_1_nc,
                        rtu1_cache_wrap_so_35_0_nc
                    }), // rtu1_cache_wrap
    .so_36          ({
                        rtu1_cache_wrap_so_36_1_nc,
                        rtu1_cache_wrap_so_36_0_nc
                    }), // rtu1_cache_wrap
    .so_37          ({
                        rtu1_cache_wrap_so_37_1_nc,
                        rtu1_cache_wrap_so_37_0_nc
                    }), // rtu1_cache_wrap
    .so_38          ({
                        rtu1_cache_wrap_so_38_1_nc,
                        rtu1_cache_wrap_so_38_0_nc
                    }), // rtu1_cache_wrap
    .so_39          ({
                        rtu1_cache_wrap_so_39_1_nc,
                        rtu1_cache_wrap_so_39_0_nc
                    }), // rtu1_cache_wrap
    .so_4           ({
                        rtu1_cache_wrap_so_4_1_nc,
                        rtu1_cache_wrap_so_4_0_nc
                    }), // rtu1_cache_wrap
    .so_40          ({
                        rtu1_cache_wrap_so_40_1_nc,
                        rtu1_cache_wrap_so_40_0_nc
                    }), // rtu1_cache_wrap
    .so_5           ({
                        rtu1_cache_wrap_so_5_1_nc,
                        rtu1_cache_wrap_so_5_0_nc
                    }), // rtu1_cache_wrap
    .so_6           ({
                        rtu1_cache_wrap_so_6_1_nc,
                        rtu1_cache_wrap_so_6_0_nc
                    }), // rtu1_cache_wrap
    .so_7           ({
                        rtu1_cache_wrap_so_7_1_nc,
                        rtu1_cache_wrap_so_7_0_nc
                    }), // rtu1_cache_wrap
    .so_8           ({
                        rtu1_cache_wrap_so_8_1_nc,
                        rtu1_cache_wrap_so_8_0_nc
                    }), // rtu1_cache_wrap
    .so_9           ({
                        rtu1_cache_wrap_so_9_1_nc,
                        rtu1_cache_wrap_so_9_0_nc
                    }), // rtu1_cache_wrap
    .sys_test_done  (mct_mbist_done_bus[15]), // rtu1_cache_wrap
    .sys_test_pass  (mct_mbist_pass_bus[15]), // rtu1_cache_wrap

// Inputs
    .a_0            (DebugTrace_addr_rtu1_erf[7:0]),
    .a_1            (CoreMix_ITAGADDR0_C1[6:0]),
    .a_10           (CoreMix_ITAGADDR1_C1[6:0]),
    .a_11           (CoreMix_ITAGADDR1_C1[6:0]),
    .a_12           (CoreMix_ITAGADDR1_C1[6:0]),
    .a_13           (CoreMix_DTAGADDR1_C1[6:0]),
    .a_14           (CoreMix_DTAGADDR1_C1[6:0]),
    .a_15           (CoreMix_DTAGADDR1_C1[6:0]),
    .a_16           (CoreMix_DTAGADDR1_C1[6:0]),
    .a_17           (CoreMix_IDATA0ADDR0_C1[9:0]),
    .a_18           (CoreMix_IDATA1ADDR0_C1[9:0]),
    .a_19           (CoreMix_IDATA1ADDR1_C1[9:0]),
    .a_2            (CoreMix_IDATA2ADDR0_C1[9:0]),
    .a_20           (CoreMix_IDATA2ADDR1_C1[9:0]),
    .a_21           (CoreMix_IDATA3ADDR0_C1[9:0]),
    .a_22           (CoreMix_IDATA3ADDR1_C1[9:0]),
    .a_23           (CoreMix_IDATA4ADDR0_C1[9:0]),
    .a_24           (CoreMix_IDATA4ADDR1_C1[9:0]),
    .a_25           (CoreMix_DDATA0ADDR1_C1[9:0]),
    .a_26           (CoreMix_DDATA1ADDR0_C1[9:0]),
    .a_27           (CoreMix_DDATA1ADDR1_C1[9:0]),
    .a_28           (CoreMix_DDATA2ADDR0_C1[9:0]),
    .a_29           (CoreMix_DDATA2ADDR1_C1[9:0]),
    .a_3            (CoreMix_ITAGADDR0_C1[6:0]),
    .a_30           (CoreMix_DDATA3ADDR0_C1[9:0]),
    .a_31           (CoreMix_DDATA3ADDR1_C1[9:0]),
    .a_32           (CoreMix_DDATA4ADDR0_C1[9:0]),
    .a_33           (CoreMix_DDATA4ADDR1_C1[9:0]),
    .a_34           (CoreMix_DDATA5ADDR0_C1[9:0]),
    .a_35           (CoreMix_DDATA5ADDR1_C1[9:0]),
    .a_36           (CoreMix_DDATA6ADDR0_C1[9:0]),
    .a_37           (CoreMix_DDATA6ADDR1_C1[9:0]),
    .a_38           (CoreMix_DDATA7ADDR0_C1[9:0]),
    .a_39           (CoreMix_DDATA7ADDR1_C1[9:0]),
    .a_4            (CoreMix_ITAGADDR0_C1[6:0]),
    .a_40           (CoreMix_ITAGADDR1_C1[6:0]),
    .a_5            (CoreMix_DTAGADDR0_C1[6:0]),
    .a_6            (CoreMix_DTAGADDR0_C1[6:0]),
    .a_7            (CoreMix_DTAGADDR0_C1[6:0]),
    .a_8            (CoreMix_DTAGADDR0_C1[6:0]),
    .a_9            (CoreMix_ITAGADDR1_C1[6:0]),
    .cen_0          (DebugTrace_cs_rtu1_et),
    .cen_1          (memory_glue_rtu1_cpu0_icache_tag_CEN[0]),
    .cen_10         (memory_glue_rtu1_cpu1_icache_tag_CEN[1]),
    .cen_11         (memory_glue_rtu1_cpu1_icache_tag_CEN[2]),
    .cen_12         (memory_glue_rtu1_cpu1_icache_tag_CEN[3]),
    .cen_13         (memory_glue_rtu1_cpu1_dcache_tag_CEN[0]),
    .cen_14         (memory_glue_rtu1_cpu1_dcache_tag_CEN[1]),
    .cen_15         (memory_glue_rtu1_cpu1_dcache_tag_CEN[2]),
    .cen_16         (memory_glue_rtu1_cpu1_dcache_tag_CEN[3]),
    .cen_17         (memory_glue_rtu1_cpu0_icache_data_CEN[11]),
    .cen_18         (memory_glue_rtu1_cpu0_icache_data_CEN[12]),
    .cen_19         (memory_glue_rtu1_cpu0_icache_data_CEN[13]),
    .cen_2          (memory_glue_rtu1_cpu0_icache_data_CEN[2]),
    .cen_20         (memory_glue_rtu1_cpu0_icache_data_CEN[3]),
    .cen_21         (memory_glue_rtu1_cpu1_icache_data_CEN[0]),
    .cen_22         (memory_glue_rtu1_cpu1_icache_data_CEN[1]),
    .cen_23         (memory_glue_rtu1_cpu1_icache_data_CEN[2]),
    .cen_24         (memory_glue_rtu1_cpu1_icache_data_CEN[3]),
    .cen_25         (memory_glue_rtu1_cpu0_dcache_data_CEN[0]),
    .cen_26         (memory_glue_rtu1_cpu0_dcache_data_CEN[1]),
    .cen_27         (memory_glue_rtu1_cpu0_dcache_data_CEN[2]),
    .cen_28         (memory_glue_rtu1_cpu0_dcache_data_CEN[3]),
    .cen_29         (memory_glue_rtu1_cpu1_dcache_data_CEN[0]),
    .cen_3          (memory_glue_rtu1_cpu0_icache_data_CEN[5]),
    .cen_30         (memory_glue_rtu1_cpu0_dcache_data_CEN[5]),
    .cen_31         (memory_glue_rtu1_cpu0_dcache_data_CEN[6]),
    .cen_32         (memory_glue_rtu1_cpu0_dcache_data_CEN[7]),
    .cen_33         (memory_glue_rtu1_cpu1_dcache_data_CEN[1]),
    .cen_34         (memory_glue_rtu1_cpu1_dcache_data_CEN[2]),
    .cen_35         (memory_glue_rtu1_cpu1_dcache_data_CEN[3]),
    .cen_36         (memory_glue_rtu1_cpu1_dcache_data_CEN[4]),
    .cen_37         (memory_glue_rtu1_cpu1_dcache_data_CEN[5]),
    .cen_38         (memory_glue_rtu1_cpu1_dcache_data_CEN[6]),
    .cen_39         (memory_glue_rtu1_cpu1_dcache_data_CEN[7]),
    .cen_4          (memory_glue_rtu1_cpu0_icache_tag_CEN[7]),
    .cen_40         (memory_glue_rtu1_cpu1_icache_tag_CEN[0]),
    .cen_5          (memory_glue_rtu1_cpu0_dcache_tag_CEN[0]),
    .cen_6          (memory_glue_rtu1_cpu0_dcache_tag_CEN[1]),
    .cen_7          (memory_glue_rtu1_cpu0_dcache_tag_CEN[2]),
    .cen_8          (memory_glue_rtu1_cpu0_dcache_tag_CEN[3]),
    .cen_9          (memory_glue_rtu1_cpu1_icache_tag_CEN[0]),
    .clk_0          (clkgen_platform_clkgen_gated_plat_clk[6]),
    .clk_1          (rtu1_cpu0_cache_clk),
    .clk_10         (rtu1_cpu1_cache_clk),
    .clk_11         (rtu1_cpu1_cache_clk),
    .clk_12         (rtu1_cpu1_cache_clk),
    .clk_13         (rtu1_cpu1_cache_clk),
    .clk_14         (rtu1_cpu1_cache_clk),
    .clk_15         (rtu1_cpu1_cache_clk),
    .clk_16         (rtu1_cpu1_cache_clk),
    .clk_17         (rtu1_cpu0_cache_clk),
    .clk_18         (rtu1_cpu0_cache_clk),
    .clk_19         (rtu1_cpu0_cache_clk),
    .clk_2          (rtu1_cpu0_cache_clk),
    .clk_20         (rtu1_cpu0_cache_clk),
    .clk_21         (rtu1_cpu1_cache_clk),
    .clk_22         (rtu1_cpu1_cache_clk),
    .clk_23         (rtu1_cpu1_cache_clk),
    .clk_24         (rtu1_cpu1_cache_clk),
    .clk_25         (rtu1_cpu0_cache_clk),
    .clk_26         (rtu1_cpu0_cache_clk),
    .clk_27         (rtu1_cpu0_cache_clk),
    .clk_28         (rtu1_cpu0_cache_clk),
    .clk_29         (rtu1_cpu1_cache_clk),
    .clk_3          (rtu1_cpu0_cache_clk),
    .clk_30         (rtu1_cpu0_cache_clk),
    .clk_31         (rtu1_cpu0_cache_clk),
    .clk_32         (rtu1_cpu0_cache_clk),
    .clk_33         (rtu1_cpu1_cache_clk),
    .clk_34         (rtu1_cpu1_cache_clk),
    .clk_35         (rtu1_cpu1_cache_clk),
    .clk_36         (rtu1_cpu1_cache_clk),
    .clk_37         (rtu1_cpu1_cache_clk),
    .clk_38         (rtu1_cpu1_cache_clk),
    .clk_39         (rtu1_cpu1_cache_clk),
    .clk_4          (rtu1_cpu0_cache_clk),
    .clk_5          (rtu1_cpu0_cache_clk),
    .clk_6          (rtu1_cpu0_cache_clk),
    .clk_7          (rtu1_cpu0_cache_clk),
    .clk_8          (rtu1_cpu0_cache_clk),
    .clk_9          (rtu1_cpu1_cache_clk),
    .d_0            (DebugTrace_wdata_rtu1_erf[127:0]),
    .d_1            (CoreMix_ITAGWDATA_C1[28:3]),
    .d_10           (CoreMix_ITAGWDATA1_C1[28:3]),
    .d_11           (CoreMix_ITAGWDATA1_C1[28:3]),
    .d_12           (CoreMix_ITAGWDATA1_C1[28:3]),
    .d_13           (CoreMix_DTAGWDATA1_C1[28:3]),
    .d_14           (CoreMix_DTAGWDATA1_C1[28:3]),
    .d_15           (CoreMix_DTAGWDATA1_C1[28:3]),
    .d_16           (CoreMix_DTAGWDATA1_C1[28:3]),
    .d_17           (CoreMix_IDATA1WDATA0_C1[70:0]),
    .d_18           (CoreMix_IDATA1WDATA0_C1[70:0]),
    .d_19           (CoreMix_IDATA1WDATA1_C1[70:0]),
    .d_2            (CoreMix_IDATA2WDATA0_C1[70:0]),
    .d_20           (CoreMix_IDATA2WDATA1_C1[70:0]),
    .d_21           (CoreMix_IDATA3WDATA0_C1[70:0]),
    .d_22           (CoreMix_IDATA3WDATA1_C1[70:0]),
    .d_23           (CoreMix_IDATA4WDATA0_C1[70:0]),
    .d_24           (CoreMix_IDATA4WDATA1_C1[70:0]),
    .d_25           (CoreMix_DDATA0WDATA1_C1[37:0]),
    .d_26           (CoreMix_DDATA1WDATA0_C1[37:0]),
    .d_27           (CoreMix_DDATA1WDATA1_C1[37:0]),
    .d_28           (CoreMix_DDATA2WDATA0_C1[37:0]),
    .d_29           (CoreMix_DDATA2WDATA1_C1[37:0]),
    .d_3            (CoreMix_ITAGWDATA0_C1[28:3]),
    .d_30           (CoreMix_DDATA3WDATA0_C1[37:0]),
    .d_31           (CoreMix_DDATA3WDATA1_C1[37:0]),
    .d_32           (CoreMix_DDATA4WDATA0_C1[37:0]),
    .d_33           (CoreMix_DDATA4WDATA1_C1[37:0]),
    .d_34           (CoreMix_DDATA5WDATA0_C1[37:0]),
    .d_35           (CoreMix_DDATA5WDATA1_C1[37:0]),
    .d_36           (CoreMix_DDATA6WDATA0_C1[37:0]),
    .d_37           (CoreMix_DDATA6WDATA1_C1[37:0]),
    .d_38           (CoreMix_DDATA7WDATA0_C1[37:0]),
    .d_39           (CoreMix_DDATA7WDATA1_C1[37:0]),
    .d_4            (CoreMix_ITAGWDATA0_C1[28:3]),
    .d_40           (CoreMix_ITAGWDATA1_C1[28:3]),
    .d_5            (CoreMix_DTAGWDATA0_C1[28:3]),
    .d_6            (CoreMix_DTAGWDATA0_C1[28:3]),
    .d_7            (CoreMix_DTAGWDATA0_C1[28:3]),
    .d_8            (CoreMix_DTAGWDATA0_C1[28:3]),
    .d_9            (CoreMix_ITAGWDATA1_C1[28:3]),
    .dftrambyp_0    (1'b0),
    .dftrambyp_1    (1'b0),
    .dftrambyp_10   (1'b0),
    .dftrambyp_11   (1'b0),
    .dftrambyp_12   (1'b0),
    .dftrambyp_13   (1'b0),
    .dftrambyp_14   (1'b0),
    .dftrambyp_15   (1'b0),
    .dftrambyp_16   (1'b0),
    .dftrambyp_17   (1'b0),
    .dftrambyp_18   (1'b0),
    .dftrambyp_19   (1'b0),
    .dftrambyp_2    (1'b0),
    .dftrambyp_20   (1'b0),
    .dftrambyp_21   (1'b0),
    .dftrambyp_22   (1'b0),
    .dftrambyp_23   (1'b0),
    .dftrambyp_24   (1'b0),
    .dftrambyp_25   (1'b0),
    .dftrambyp_26   (1'b0),
    .dftrambyp_27   (1'b0),
    .dftrambyp_28   (1'b0),
    .dftrambyp_29   (1'b0),
    .dftrambyp_3    (1'b0),
    .dftrambyp_30   (1'b0),
    .dftrambyp_31   (1'b0),
    .dftrambyp_32   (1'b0),
    .dftrambyp_33   (1'b0),
    .dftrambyp_34   (1'b0),
    .dftrambyp_35   (1'b0),
    .dftrambyp_36   (1'b0),
    .dftrambyp_37   (1'b0),
    .dftrambyp_38   (1'b0),
    .dftrambyp_39   (1'b0),
    .dftrambyp_4    (1'b0),
    .dftrambyp_40   (1'b0),
    .dftrambyp_5    (1'b0),
    .dftrambyp_6    (1'b0),
    .dftrambyp_7    (1'b0),
    .dftrambyp_8    (1'b0),
    .dftrambyp_9    (1'b0),
    .ema_0          (MEM_EMA[2:0]),
    .ema_1          (MEM_EMA[2:0]),
    .ema_10         (MEM_EMA[2:0]),
    .ema_11         (MEM_EMA[2:0]),
    .ema_12         (MEM_EMA[2:0]),
    .ema_13         (MEM_EMA[2:0]),
    .ema_14         (MEM_EMA[2:0]),
    .ema_15         (MEM_EMA[2:0]),
    .ema_16         (MEM_EMA[2:0]),
    .ema_17         (MEM_EMA[2:0]),
    .ema_18         (MEM_EMA[2:0]),
    .ema_19         (MEM_EMA[2:0]),
    .ema_2          (MEM_EMA[2:0]),
    .ema_20         (MEM_EMA[2:0]),
    .ema_21         (MEM_EMA[2:0]),
    .ema_22         (MEM_EMA[2:0]),
    .ema_23         (MEM_EMA[2:0]),
    .ema_24         (MEM_EMA[2:0]),
    .ema_25         (MEM_EMA[2:0]),
    .ema_26         (MEM_EMA[2:0]),
    .ema_27         (MEM_EMA[2:0]),
    .ema_28         (MEM_EMA[2:0]),
    .ema_29         (MEM_EMA[2:0]),
    .ema_3          (MEM_EMA[2:0]),
    .ema_30         (MEM_EMA[2:0]),
    .ema_31         (MEM_EMA[2:0]),
    .ema_32         (MEM_EMA[2:0]),
    .ema_33         (MEM_EMA[2:0]),
    .ema_34         (MEM_EMA[2:0]),
    .ema_35         (MEM_EMA[2:0]),
    .ema_36         (MEM_EMA[2:0]),
    .ema_37         (MEM_EMA[2:0]),
    .ema_38         (MEM_EMA[2:0]),
    .ema_39         (MEM_EMA[2:0]),
    .ema_4          (MEM_EMA[2:0]),
    .ema_40         (MEM_EMA[2:0]),
    .ema_5          (MEM_EMA[2:0]),
    .ema_6          (MEM_EMA[2:0]),
    .ema_7          (MEM_EMA[2:0]),
    .ema_8          (MEM_EMA[2:0]),
    .ema_9          (MEM_EMA[2:0]),
    .emas_0         (MEM_EMAS),
    .emas_1         (MEM_EMAS),
    .emas_11        (MEM_EMAS),
    .emas_12        (MEM_EMAS),
    .emas_13        (MEM_EMAS),
    .emas_14        (MEM_EMAS),
    .emas_15        (MEM_EMAS),
    .emas_16        (MEM_EMAS),
    .emas_17        (MEM_EMAS),
    .emas_18        (MEM_EMAS),
    .emas_19        (MEM_EMAS),
    .emas_2         (MEM_EMAS),
    .emas_20        (MEM_EMAS),
    .emas_21        (MEM_EMAS),
    .emas_22        (MEM_EMAS),
    .emas_23        (MEM_EMAS),
    .emas_24        (MEM_EMAS),
    .emas_25        (MEM_EMAS),
    .emas_26        (MEM_EMAS),
    .emas_27        (MEM_EMAS),
    .emas_28        (MEM_EMAS),
    .emas_29        (MEM_EMAS),
    .emas_3         (MEM_EMAS),
    .emas_30        (MEM_EMAS),
    .emas_31        (MEM_EMAS),
    .emas_32        (MEM_EMAS),
    .emas_33        (MEM_EMAS),
    .emas_34        (MEM_EMAS),
    .emas_35        (MEM_EMAS),
    .emas_36        (MEM_EMAS),
    .emas_37        (MEM_EMAS),
    .emas_38        (MEM_EMAS),
    .emas_39        (MEM_EMAS),
    .emas_4         (MEM_EMAS),
    .emas_40        (MEM_EMAS),
    .emas_5         (MEM_EMAS),
    .emas_6         (MEM_EMAS),
    .emas_7         (MEM_EMAS),
    .emas_8         (MEM_EMAS),
    .emas_9         (MEM_EMAS),
    .emaw_0         (MEM_EMAW[1:0]),
    .emaw_1         (MEM_EMAW[1:0]),
    .emaw_10        (MEM_EMAW[1:0]),
    .emaw_11        (MEM_EMAW[1:0]),
    .emaw_12        (MEM_EMAW[1:0]),
    .emaw_13        (MEM_EMAW[1:0]),
    .emaw_14        (MEM_EMAW[1:0]),
    .emaw_15        (MEM_EMAW[1:0]),
    .emaw_16        (MEM_EMAW[1:0]),
    .emaw_17        (MEM_EMAW[1:0]),
    .emaw_18        (MEM_EMAW[1:0]),
    .emaw_19        (MEM_EMAW[1:0]),
    .emaw_2         (MEM_EMAW[1:0]),
    .emaw_20        (MEM_EMAW[1:0]),
    .emaw_21        (MEM_EMAW[1:0]),
    .emaw_22        (MEM_EMAW[1:0]),
    .emaw_23        (MEM_EMAW[1:0]),
    .emaw_24        (MEM_EMAW[1:0]),
    .emaw_25        (MEM_EMAW[1:0]),
    .emaw_26        (MEM_EMAW[1:0]),
    .emaw_27        (MEM_EMAW[1:0]),
    .emaw_28        (MEM_EMAW[1:0]),
    .emaw_29        (MEM_EMAW[1:0]),
    .emaw_3         (MEM_EMAW[1:0]),
    .emaw_30        (MEM_EMAW[1:0]),
    .emaw_31        (MEM_EMAW[1:0]),
    .emaw_32        (MEM_EMAW[1:0]),
    .emaw_33        (MEM_EMAW[1:0]),
    .emaw_34        (MEM_EMAW[1:0]),
    .emaw_35        (MEM_EMAW[1:0]),
    .emaw_36        (MEM_EMAW[1:0]),
    .emaw_37        (MEM_EMAW[1:0]),
    .emaw_38        (MEM_EMAW[1:0]),
    .emaw_39        (MEM_EMAW[1:0]),
    .emaw_4         (MEM_EMAW[1:0]),
    .emaw_40        (MEM_EMAW[1:0]),
    .emaw_5         (MEM_EMAW[1:0]),
    .emaw_6         (MEM_EMAW[1:0]),
    .emaw_7         (MEM_EMAW[1:0]),
    .emaw_8         (MEM_EMAW[1:0]),
    .emaw_9         (MEM_EMAW[1:0]),
    .gwen_17        (memory_glue_rtu1_cpu0_icache_data_GWEN[0]),
    .gwen_18        (memory_glue_rtu1_cpu0_icache_data_GWEN[1]),
    .gwen_19        (memory_glue_rtu1_cpu0_icache_data_GWEN[2]),
    .gwen_2         (memory_glue_rtu1_cpu0_icache_data_GWEN[3]),
    .gwen_20        (memory_glue_rtu1_cpu0_icache_data_GWEN[4]),
    .gwen_21        (memory_glue_rtu1_cpu1_icache_data_GWEN[0]),
    .gwen_22        (memory_glue_rtu1_cpu1_icache_data_GWEN[1]),
    .gwen_23        (memory_glue_rtu1_cpu1_icache_data_GWEN[2]),
    .gwen_24        (memory_glue_rtu1_cpu1_icache_data_GWEN[3]),
    .gwen_25        (memory_glue_rtu1_cpu0_dcache_data_GWEN[0]),
    .gwen_26        (memory_glue_rtu1_cpu0_dcache_data_GWEN[1]),
    .gwen_27        (memory_glue_rtu1_cpu0_dcache_data_GWEN[2]),
    .gwen_28        (memory_glue_rtu1_cpu0_dcache_data_GWEN[3]),
    .gwen_29        (memory_glue_rtu1_cpu0_dcache_data_GWEN[4]),
    .gwen_30        (memory_glue_rtu1_cpu0_dcache_data_GWEN[5]),
    .gwen_31        (memory_glue_rtu1_cpu0_dcache_data_GWEN[6]),
    .gwen_32        (memory_glue_rtu1_cpu0_dcache_data_GWEN[7]),
    .gwen_33        (memory_glue_rtu1_cpu1_dcache_data_GWEN[0]),
    .gwen_34        (memory_glue_rtu1_cpu1_dcache_data_GWEN[1]),
    .gwen_35        (memory_glue_rtu1_cpu1_dcache_data_GWEN[2]),
    .gwen_36        (memory_glue_rtu1_cpu1_dcache_data_GWEN[3]),
    .gwen_37        (memory_glue_rtu1_cpu1_dcache_data_GWEN[4]),
    .gwen_38        (memory_glue_rtu1_cpu1_dcache_data_GWEN[5]),
    .gwen_39        (memory_glue_rtu1_cpu1_dcache_data_GWEN[6]),
    .gwen_40        (memory_glue_rtu1_cpu1_dcache_data_GWEN[7]),
    .ijtag_ce       (platform_int_tcu_mbist_ijtag_to_ce),
    .ijtag_reset    (platform_int_tcu_mbist_ijtag_to_reset),
    .ijtag_se       (platform_int_tcu_mbist_ijtag_to_se),
    .ijtag_sel      (platform_int_tcu_mbist_ijtag_to_sel),
    .ijtag_tck      (rtu0_cache_wrap_ijtag_so),
    .ijtag_ue       (platform_int_tcu_mbist_ijtag_to_ue),
    .ltest_en       (platform_int_tcu_ltest_en),
    .mcp_bounding_en(platform_int_tcu_ltest_to_mcp_bounding_en),
    .memory_bypass_en(platform_int_tcu_ltest_to_mem_bypass_en),
    .rawl_0         (MEM_RAWL),
    .rawl_1         (MEM_RAWL),
    .rawl_10        (MEM_RAWL),
    .rawl_11        (MEM_RAWL),
    .rawl_12        (MEM_RAWL),
    .rawl_13        (MEM_RAWL),
    .rawl_14        (MEM_RAWL),
    .rawl_15        (MEM_RAWL),
    .rawl_16        (MEM_RAWL),
    .rawl_17        (MEM_RAWL),
    .rawl_18        (MEM_RAWL),
    .rawl_19        (MEM_RAWL),
    .rawl_2         (MEM_RAWL),
    .rawl_20        (MEM_RAWL),
    .rawl_21        (MEM_RAWL),
    .rawl_22        (MEM_RAWL),
    .rawl_23        (MEM_RAWL),
    .rawl_24        (MEM_RAWL),
    .rawl_25        (MEM_RAWL),
    .rawl_26        (MEM_RAWL),
    .rawl_27        (MEM_RAWL),
    .rawl_28        (MEM_RAWL),
    .rawl_29        (MEM_RAWL),
    .rawl_3         (MEM_RAWL),
    .rawl_30        (MEM_RAWL),
    .rawl_31        (MEM_RAWL),
    .rawl_32        (MEM_RAWL),
    .rawl_33        (MEM_RAWL),
    .rawl_34        (MEM_RAWL),
    .rawl_35        (MEM_RAWL),
    .rawl_36        (MEM_RAWL),
    .rawl_37        (MEM_RAWL),
    .rawl_38        (MEM_RAWL),
    .rawl_39        (MEM_RAWL),
    .rawl_4         (MEM_RAWL),
    .rawl_40        (MEM_RAWL),
    .rawl_5         (MEM_RAWL),
    .rawl_6         (MEM_RAWL),
    .rawl_7         (MEM_RAWL),
    .rawl_8         (MEM_RAWL),
    .rawl_9         (MEM_RAWL),
    .rawlm_0        (MEM_RAWLM[1:0]),
    .rawlm_1        (MEM_RAWLM[1:0]),
    .rawlm_10       (MEM_RAWLM[1:0]),
    .rawlm_11       (MEM_RAWLM[1:0]),
    .rawlm_12       (MEM_RAWLM[1:0]),
    .rawlm_13       (MEM_RAWLM[1:0]),
    .rawlm_14       (MEM_RAWLM[1:0]),
    .rawlm_15       (MEM_RAWLM[1:0]),
    .rawlm_16       (MEM_RAWLM[1:0]),
    .rawlm_17       (MEM_RAWLM[1:0]),
    .rawlm_18       (MEM_RAWLM[1:0]),
    .rawlm_19       (MEM_RAWLM[1:0]),
    .rawlm_2        (MEM_RAWLM[1:0]),
    .rawlm_20       (MEM_RAWLM[1:0]),
    .rawlm_21       (MEM_RAWLM[1:0]),
    .rawlm_22       (MEM_RAWLM[1:0]),
    .rawlm_23       (MEM_RAWLM[1:0]),
    .rawlm_24       (MEM_RAWLM[1:0]),
    .rawlm_25       (MEM_RAWLM[1:0]),
    .rawlm_26       (MEM_RAWLM[1:0]),
    .rawlm_27       (MEM_RAWLM[1:0]),
    .rawlm_28       (MEM_RAWLM[1:0]),
    .rawlm_29       (MEM_RAWLM[1:0]),
    .rawlm_3        (MEM_RAWLM[1:0]),
    .rawlm_30       (MEM_RAWLM[1:0]),
    .rawlm_31       (MEM_RAWLM[1:0]),
    .rawlm_32       (MEM_RAWLM[1:0]),
    .rawlm_33       (MEM_RAWLM[1:0]),
    .rawlm_34       (MEM_RAWLM[1:0]),
    .rawlm_35       (MEM_RAWLM[1:0]),
    .rawlm_36       (MEM_RAWLM[1:0]),
    .rawlm_37       (MEM_RAWLM[1:0]),
    .rawlm_38       (MEM_RAWLM[1:0]),
    .rawlm_39       (MEM_RAWLM[1:0]),
    .rawlm_4        (MEM_RAWLM[1:0]),
    .rawlm_40       (MEM_RAWLM[1:0]),
    .rawlm_5        (MEM_RAWLM[1:0]),
    .rawlm_6        (MEM_RAWLM[1:0]),
    .rawlm_7        (MEM_RAWLM[1:0]),
    .rawlm_8        (MEM_RAWLM[1:0]),
    .rawlm_9        (MEM_RAWLM[1:0]),
    .rdt_0          (MEM_RDT),
    .rdt_1          (MEM_RDT),
    .rdt_10         (MEM_RDT),
    .rdt_11         (MEM_RDT),
    .rdt_12         (MEM_RDT),
    .rdt_13         (MEM_RDT),
    .rdt_14         (MEM_RDT),
    .rdt_15         (MEM_RDT),
    .rdt_16         (MEM_RDT),
    .rdt_17         (MEM_RDT),
    .rdt_18         (MEM_RDT),
    .rdt_19         (MEM_RDT),
    .rdt_2          (MEM_RDT),
    .rdt_20         (MEM_RDT),
    .rdt_21         (MEM_RDT),
    .rdt_22         (MEM_RDT),
    .rdt_23         (MEM_RDT),
    .rdt_24         (MEM_RDT),
    .rdt_25         (MEM_RDT),
    .rdt_26         (MEM_RDT),
    .rdt_27         (MEM_RDT),
    .rdt_28         (MEM_RDT),
    .rdt_29         (MEM_RDT),
    .rdt_3          (MEM_RDT),
    .rdt_30         (MEM_RDT),
    .rdt_31         (MEM_RDT),
    .rdt_32         (MEM_RDT),
    .rdt_33         (MEM_RDT),
    .rdt_34         (MEM_RDT),
    .rdt_35         (MEM_RDT),
    .rdt_36         (MEM_RDT),
    .rdt_37         (MEM_RDT),
    .rdt_38         (MEM_RDT),
    .rdt_39         (MEM_RDT),
    .rdt_4          (MEM_RDT),
    .rdt_40         (MEM_RDT),
    .rdt_5          (MEM_RDT),
    .rdt_6          (MEM_RDT),
    .rdt_7          (MEM_RDT),
    .rdt_8          (MEM_RDT),
    .rdt_9          (MEM_RDT),
    .ret1n_0        (rtu1_cache_wrap_ret1n_0),
    .ret1n_1        (rtu1_cache_wrap_ret1n_1),
    .ret1n_10       (rtu1_cache_wrap_ret1n_10),
    .ret1n_11       (rtu1_cache_wrap_ret1n_11),
    .ret1n_12       (rtu1_cache_wrap_ret1n_12),
    .ret1n_13       (rtu1_cache_wrap_ret1n_13),
    .ret1n_14       (rtu1_cache_wrap_ret1n_14),
    .ret1n_15       (rtu1_cache_wrap_ret1n_15),
    .ret1n_16       (rtu1_cache_wrap_ret1n_16),
    .ret1n_17       (rtu1_cache_wrap_ret1n_17),
    .ret1n_18       (rtu1_cache_wrap_ret1n_18),
    .ret1n_19       (rtu1_cache_wrap_ret1n_19),
    .ret1n_2        (rtu1_cache_wrap_ret1n_2),
    .ret1n_20       (rtu1_cache_wrap_ret1n_20),
    .ret1n_21       (rtu1_cache_wrap_ret1n_21),
    .ret1n_22       (rtu1_cache_wrap_ret1n_22),
    .ret1n_23       (rtu1_cache_wrap_ret1n_23),
    .ret1n_24       (rtu1_cache_wrap_ret1n_24),
    .ret1n_25       (rtu1_cache_wrap_ret1n_25),
    .ret1n_26       (rtu1_cache_wrap_ret1n_26),
    .ret1n_27       (rtu1_cache_wrap_ret1n_27),
    .ret1n_28       (rtu1_cache_wrap_ret1n_28),
    .ret1n_29       (rtu1_cache_wrap_ret1n_29),
    .ret1n_3        (rtu1_cache_wrap_ret1n_3),
    .ret1n_30       (rtu1_cache_wrap_ret1n_30),
    .ret1n_31       (rtu1_cache_wrap_ret1n_31),
    .ret1n_32       (rtu1_cache_wrap_ret1n_32),
    .ret1n_33       (rtu1_cache_wrap_ret1n_33),
    .ret1n_34       (rtu1_cache_wrap_ret1n_34),
    .ret1n_35       (rtu1_cache_wrap_ret1n_35),
    .ret1n_36       (rtu1_cache_wrap_ret1n_36),
    .ret1n_37       (rtu1_cache_wrap_ret1n_37),
    .ret1n_38       (rtu1_cache_wrap_ret1n_38),
    .ret1n_39       (rtu1_cache_wrap_ret1n_39),
    .ret1n_4        (rtu1_cache_wrap_ret1n_4),
    .ret1n_40       (rtu1_cache_wrap_ret1n_40),
    .ret1n_5        (rtu1_cache_wrap_ret1n_5),
    .ret1n_6        (rtu1_cache_wrap_ret1n_6),
    .ret1n_7        (rtu1_cache_wrap_ret1n_7),
    .ret1n_8        (rtu1_cache_wrap_ret1n_8),
    .ret1n_9        (rtu1_cache_wrap_ret1n_9),
    .scan_en        (platform_int_tcu_ltest_to_scan_en),
    .se_0           (1'b0),
    .se_1           (1'b0),
    .se_10          (1'b0),
    .se_11          (1'b0),
    .se_12          (1'b0),
    .se_13          (1'b0),
    .se_14          (1'b0),
    .se_15          (1'b0),
    .se_16          (1'b0),
    .se_17          (1'b0),
    .se_18          (1'b0),
    .se_19          (1'b0),
    .se_2           (1'b0),
    .se_20          (1'b0),
    .se_21          (1'b0),
    .se_22          (1'b0),
    .se_23          (1'b0),
    .se_24          (1'b0),
    .se_25          (1'b0),
    .se_26          (1'b0),
    .se_27          (1'b0),
    .se_28          (1'b0),
    .se_29          (1'b0),
    .se_3           (1'b0),
    .se_30          (1'b0),
    .se_31          (1'b0),
    .se_32          (1'b0),
    .se_33          (1'b0),
    .se_34          (1'b0),
    .se_35          (1'b0),
    .se_36          (1'b0),
    .se_37          (1'b0),
    .se_38          (1'b0),
    .se_39          (1'b0),
    .se_4           (1'b0),
    .se_40          (1'b0),
    .se_5           (1'b0),
    .se_6           (1'b0),
    .se_7           (1'b0),
    .se_8           (1'b0),
    .se_9           (1'b0),
    .si_0           (2'h0),
    .si_1           (2'h0),
    .si_10          (2'h0),
    .si_11          (2'h0),
    .si_12          (2'h0),
    .si_13          (2'h0),
    .si_14          (2'h0),
    .si_15          (2'h0),
    .si_16          (2'h0),
    .si_17          (2'h0),
    .si_18          (2'h0),
    .si_19          (2'h0),
    .si_2           (2'h0),
    .si_20          (2'h0),
    .si_21          (2'h0),
    .si_22          (2'h0),
    .si_23          (2'h0),
    .si_24          (2'h0),
    .si_25          (2'h0),
    .si_26          (2'h0),
    .si_27          (2'h0),
    .si_28          (2'h0),
    .si_29          (2'h0),
    .si_3           (2'h0),
    .si_30          (2'h0),
    .si_31          (2'h0),
    .si_32          (2'h0),
    .si_33          (2'h0),
    .si_34          (2'h0),
    .si_35          (2'h0),
    .si_36          (2'h0),
    .si_37          (2'h0),
    .si_38          (2'h0),
    .si_39          (2'h0),
    .si_4           (2'h0),
    .si_40          (2'h0),
    .si_5           (2'h0),
    .si_6           (2'h0),
    .si_7           (2'h0),
    .si_8           (2'h0),
    .si_9           (2'h0),
    .stov_17        (MEM_STOV),
    .stov_18        (MEM_STOV),
    .stov_19        (MEM_STOV),
    .stov_2         (MEM_STOV),
    .stov_20        (MEM_STOV),
    .stov_21        (MEM_STOV),
    .stov_22        (MEM_STOV),
    .stov_23        (MEM_STOV),
    .stov_24        (MEM_STOV),
    .stov_25        (MEM_STOV),
    .stov_26        (MEM_STOV),
    .stov_27        (MEM_STOV),
    .stov_28        (MEM_STOV),
    .stov_29        (MEM_STOV),
    .stov_30        (MEM_STOV),
    .stov_31        (MEM_STOV),
    .stov_32        (MEM_STOV),
    .stov_33        (MEM_STOV),
    .stov_34        (MEM_STOV),
    .stov_35        (MEM_STOV),
    .stov_36        (MEM_STOV),
    .stov_37        (MEM_STOV),
    .stov_38        (MEM_STOV),
    .stov_39        (MEM_STOV),
    .stov_4         (MEM_STOV),
    .stov_40        (MEM_STOV),
    .sys_algo_select(mct_mbist_alg[3:0]),
    .sys_clock      (clkgen_platform_clkgen_generic_plat_test_clk),
    .sys_ctrl_select(mct_mbist_sel[15]),
    .sys_preserve_test_inputs(mct_mbist_preserve),
    .sys_reset      (safe_fcg_async_early_reset_b),
    .sys_retention_test_phase(mct_mbist_ret_phase[1:0]),
    .sys_select_common_algo(mct_mbist_algo[4]),
    .sys_test_init  (mct_mbist_init),
    .sys_test_start (mct_mbist_invoke),
    .wabl_0         (MEM_WABL),
    .wabl_1         (MEM_WABL),
    .wabl_10        (MEM_WABL),
    .wabl_11        (MEM_WABL),
    .wabl_12        (MEM_WABL),
    .wabl_13        (MEM_WABL),
    .wabl_14        (MEM_WABL),
    .wabl_15        (MEM_WABL),
    .wabl_16        (MEM_WABL),
    .wabl_17        (MEM_WABL),
    .wabl_18        (MEM_WABL),
    .wabl_19        (MEM_WABL),
    .wabl_2         (MEM_WABL),
    .wabl_20        (MEM_WABL),
    .wabl_21        (MEM_WABL),
    .wabl_22        (MEM_WABL),
    .wabl_23        (MEM_WABL),
    .wabl_24        (MEM_WABL),
    .wabl_25        (MEM_WABL),
    .wabl_26        (MEM_WABL),
    .wabl_27        (MEM_WABL),
    .wabl_28        (MEM_WABL),
    .wabl_29        (MEM_WABL),
    .wabl_3         (MEM_WABL),
    .wabl_30        (MEM_WABL),
    .wabl_31        (MEM_WABL),
    .wabl_32        (MEM_WABL),
    .wabl_33        (MEM_WABL),
    .wabl_34        (MEM_WABL),
    .wabl_35        (MEM_WABL),
    .wabl_36        (MEM_WABL),
    .wabl_37        (MEM_WABL),
    .wabl_38        (MEM_WABL),
    .wabl_39        (MEM_WABL),
    .wabl_4         (MEM_WABL),
    .wabl_40        (MEM_WABL),
    .wabl_5         (MEM_WABL),
    .wabl_6         (MEM_WABL),
    .wabl_7         (MEM_WABL),
    .wabl_8         (MEM_WABL),
    .wabl_9         (MEM_WABL),
    .wen_0          (DebugTrace_we_rtu1_erf),
    .wen_1          (memory_glue_rtu1_cpu0_icache_tag_GWEN),
    .wen_10         (memory_glue_rtu1_cpu1_icache_tag_GWEN),
    .wen_11         (memory_glue_rtu1_cpu1_icache_tag_GWEN),
    .wen_12         (memory_glue_rtu1_cpu1_icache_tag_GWEN),
    .wen_13         (memory_glue_rtu1_cpu1_dcache_tag_GWEN),
    .wen_14         (memory_glue_rtu1_cpu1_dcache_tag_GWEN[0]),
    .wen_15         (memory_glue_rtu1_cpu1_dcache_tag_GWEN[1]),
    .wen_16         (memory_glue_rtu1_cpu1_dcache_tag_GWEN[2]),
    .wen_2          (memory_glue_rtu1_cpu1_dcache_tag_GWEN[3]),
    .wen_3          (memory_glue_rtu1_cpu0_icache_tag_GWEN),
    .wen_4          (memory_glue_rtu1_cpu0_icache_tag_GWEN),
    .wen_5          (memory_glue_rtu1_cpu0_icache_tag_GWEN),
    .wen_6          (memory_glue_rtu1_cpu0_dcache_tag_GWEN),
    .wen_7          (memory_glue_rtu1_cpu0_dcache_tag_GWEN[0]),
    .wen_8          (memory_glue_rtu1_cpu0_dcache_tag_GWEN[1]),
    .wen_9          (memory_glue_rtu1_cpu0_dcache_tag_GWEN[2]),
    .wen_9          (memory_glue_rtu1_cpu1_icache_tag_GWEN)
);
`endif
// rtu1_cache_wrap instance end


// rom_ctrl instance start
`ifdef FPGA_SYN
    wire rom_ctrl_prom_cs;

    wire [7:0] platform_int_CoreMix_HBSTRB_rom;

    fcp_hbstrb8 rom_hbstrb (
        .hbstrb(platform_int_CoreMix_HBSTRB_rom[7:0]),
        .haddr (platform_int_CoreMix_HADDR_rom[2:0]),
        .hsize (platform_int_CoreMix_HSIZE_rom[1:0])
    );

    ahb_sram_ctrl #(.BUSWIDTH(64)) rom_ctrl (
        // Outputs
        .Hrdata         (rom_ctrl_hrdata[63:0]),              // ahb_sram0_ctrl
        .Hready         (rom_ctrl_hready_out),               // ahb_sram0_ctrl
        .RamAddr        ({15'h0, rom_ctrl_prom_addr[16:3]}),
        .RamAddrErr     (),                                   // ahb_sram0_ctrl
        .RamAnyErr      (),                                   // ahb_sram0_ctrl
        .RamCs          (rom_ctrl_prom_cs),                   // ahb_sram0_ctrl
        .RamEdcErr      (),                                   // ahb_sram0_ctrl
        .RamErr         (),                                   // ahb_sram0_ctrl
        .RamErrAddr     (),                                   // ahb_sram0_ctrl
        .RamErrMst      (),                                   // ahb_sram0_ctrl
        .RamMonErr      (),                                   // ahb_sram0_ctrl
        .RamSingleErr   (),                                   // ahb_sram0_ctrl
        .RamSyndrome    (),                                   // ahb_sram0_ctrl
        .RamWChkBit     (rom_ctrl_wdata[71:64]),              // ahb_sram0_ctrl
        .RamWdata       (rom_ctrl_wdata[63:0]),                // ahb_sram0_ctrl
        .RamWe          (rom_ctrl_wen[71:0]),                  // ahb_sram0_ctrl
        .RamWr          (rom_ctrl_we),

        // Inputs
        .Haddr          (platform_int_CoreMix_HADDR_rom[31:3]),   // RAM interface
        .Hbstrb         (platform_int_CoreMix_HBSTRB_rom[7:0]),
        .Hclk           (pcc_run_int_fcg_clk_pcc_ungated_ROM),
        .Hmaster        ('b0),                                 // AHB interface
        .Hresetn        (tcu_rgm_fcg_hard_async_reset_b),
        .Hsize          (platform_int_CoreMix_HSIZE_rom[1:0]),
        .Htrans         (platform_int_CoreMix_HTRANS_rom[1:0]),
        .Hwdata         (platform_int_CoreMix_HWDATA_rom[63:0]),
        .Hwrite         (platform_int_CoreMix_HWRITE_rom),
        .RamAddrInject  ('h0),
        .RamDataInject  ('h0),
        .RamEccEnable   (3'b11),
        .RamEdcEnable   (1'b0),
        .RamInjectMode  (1'b0),                                // Misc
        .RamMonInject   (2'b00),
        .RamRChkBit     (rom_decoder_Q_out[71:64]),            // ECC interface
        .RamRdata       (rom_decoder_Q_out[63:0])
    );

    assign rom_ctrl_hrdata[71:64] = rom_decoder_Q_out[71:64];
    assign rom_ctrl_prom_cs_b = ~rom_ctrl_prom_cs;
    assign rom_ctrl_hresp0 = 0;
`else
    ahb_promc64 #(
        .PROM_ALLOW_USER_READ(1),
        .PROM_DATA_WIDTH(72)
    ) rom_ctrl (
        // Outputs
        .hrdata         (rom_ctrl_hrdata[71:0]),              // rom_ctrl
        .hready_out     (rom_ctrl_hready_out),                 // rom_ctrl
        .hresp0         (rom_ctrl_hresp0),                    // rom_ctrl
        .prom_addr      ({
                            rom_ctrl_prom_addr_19_17_nc[2:0],  // [19:17]
                            rom_ctrl_prom_addr[16:3],           // [16:3]
                            rom_ctrl_prom_addr_2_0_nc[2:0]      // [2:0]
                        }),                                     // rom_ctrl
        .prom_cs_b      (rom_ctrl_prom_cs_b),

        // Inputs
        .async_reset_b  (tcu_rgm_fcg_hard_async_reset_b),     // rom_ctrl
        .clk            (pcc_run_int_fcg_clk_pcc_ungated_ROM),// rom_ctrl
        .haddr          (platform_int_CoreMix_HADDR_rom[31:0]),// rom_ctrl
        .hprot1         (1'b0),                                // rom_ctrl
        .htrans         (platform_int_CoreMix_HTRANS_rom[1:0]),// rom_ctrl
        .hwrite         (platform_int_CoreMix_HWRITE_rom),    // rom_ctrl
        .prom_fast      (1'b0),                               // rom_ctrl
        .prom_hole      (1'b0),                               // rom_ctrl
        .prom_rdata     (rom_decoder_Q_out[71:0]),             // rom_ctrl
        .prom_size      (4'h9)                                // rom_ctrl
    );
`endif
// rom_ctrl instance end

// u65 — Ethos-U65 NPU
wire u65_nmbistreset = 1'b1;
wire u65_porpl       = 1'b1;
wire u65_porsl       = 1'b1;
wire u65_clkreqn     = 1'b0;
wire u65_pwrqactive  = 1'b0;
wire u65_pwrreqn     = 1'b1;
wire u65_awakeupm0   = 1'b0;

`ifdef FPGA_SYN
assign u65_irq = 'b0;
assign u65_clkqactive = 'b0;
assign u65_clkacceptn = 'b0;
assign u65_clkdeny = 'b0;
assign u65_pwracceptn = 'b0;
assign u65_pwrdeny = 'b0;
assign u65_aclkenm0 = 'b0;
assign u65_awvalidm0 = 'b0;
assign u65_awaddrm0 = 'b0;
`else
ETHOSU65_1 #(
  .CFG    (BUILD_CFG(1, 256)),
  .NUM_CH (AXI_NUM_RD_CH(BUILD_CFG(1, 256)))
) u_u65 (
  .CLK          (clk),
  .nRESET       (rst_n),
  .nMBISTRESET  (u65_nmbistreset),
`ifdef FPGA_SYN
  .PORPL        (u65_porpl_fpga),
  .PORSL        (u65_porsl_fpga),
`else
  .PORPL        (u65_porpl),
  .PORSL        (u65_porsl),
`endif
  .IRQ          (u65_irq),
  .CLKQACTIVE   (u65_clkqactive),
  .CLKREQn      (u65_clkreqn),
  .CLKACCEPTn   (u65_clkacceptn),
  .CLKDENY      (u65_clkdeny),
  .PWRQACTIVE   (u65_pwrqactive),
  .PWRREQn      (u65_pwrreqn),
  .PWRACCEPTn   (u65_pwracceptn),
  .PWRDENY      (u65_pwrdeny),
  .AWAKEUPM0    (u65_awakeupm0),
  .ACLKENM0     (u65_aclkenm0),
  .AWVALIDM0    (u65_awvalidm0),
  .AWADDRM0     (u65_awaddrm0)
);
`endif

endmodule

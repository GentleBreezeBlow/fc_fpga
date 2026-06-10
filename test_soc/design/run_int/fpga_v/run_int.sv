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

endmodule

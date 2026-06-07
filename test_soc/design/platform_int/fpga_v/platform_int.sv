//===========================================================================
// platform_int.sv — Platform Interrupt Controller + Memory Subsystem
//===========================================================================
module platform_int #(
  parameter N_IRQ = 32
) (
  input  wire               clk,
  input  wire               rst_n,
  input  wire [N_IRQ-1:0]   irq_src,
  output wire [N_IRQ-1:0]   irq,
  output wire               irq_pending,

  // ---- SRAM 256x32 ----
  input  wire [7:0]         sram_addr,
  input  wire [31:0]        sram_din,
  output wire [31:0]        sram_dout,
  input  wire               sram_cen,
  input  wire               sram_wen,

  // ---- ROM 1024x16 (bootloader) ----
  input  wire [9:0]         rom_addr,
  output wire [15:0]        rom_dout,
  input  wire               rom_cen,

  // ---- DMA Buffer (CPPE FlexCAN DMA PSE) ----
  input  wire               dma_clk_0,
  input  wire               dma_cen_0,
  input  wire [6:0]         dma_a_0,
  input  wire [109:0]       dma_d_0,
  input  wire [109:0]       dma_wen_0,
  output wire [109:0]       dma_q_0,
  input  wire               dma_clk_1,
  input  wire               dma_cen_1,
  input  wire [9:0]         dma_a_1,
  input  wire [103:0]       dma_d_1,
  input  wire [103:0]       dma_wen_1,
  output wire [103:0]       dma_q_1
);

  //===========================================================
  // Interrupt controller
  //===========================================================
  reg [N_IRQ-1:0] irq_reg;
  reg pending_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      irq_reg     <= '0;
      pending_reg <= 1'b0;
    end else begin
      irq_reg     <= irq_src;
      pending_reg <= |irq_src;
    end
  end

  assign irq         = irq_reg;
  assign irq_pending = pending_reg;

  //===========================================================
  // SRAM wrapper — 256×32 general-purpose RAM
  //===========================================================
  sram_256x32_wrap u_sram (
    .CLK_0  (clk),
    .A_0    (sram_addr),
    .D_0    (sram_din),
    .Q_0    (sram_dout),
    .CEN_0  (sram_cen),
    .WEN_0  (sram_wen)
  );

  //===========================================================
  // ROM wrapper — 1024×16 boot ROM
  //===========================================================
  rom_1024x16_wrap u_rom (
    .CLK_0  (clk),
    .A_0    (rom_addr),
    .Q_0    (rom_dout),
    .CEN_0  (rom_cen)
  );

  //===========================================================
  // DMA buffer wrapper — 110b/104b dual-port
  //===========================================================
  cppe_flexcan_dma_pse_wrap u_dma_buf (
    .sys_clock                (clk),
    .sys_reset                (~rst_n),
    .sys_test_init            (1'b0),
    .sys_test_start           (1'b0),
    .sys_ctrl_select          (1'b0),
    .sys_algo_select          (4'h0),
    .sys_select_common_algo   (1'b0),
    .sys_retention_test_phase (2'b00),
    .sys_preserve_test_inputs (1'b0),
    .sys_test_pass            (),
    .sys_test_done            (),
    .clk_0                    (dma_clk_0),
    .cen_0                    (dma_cen_0),
    .gwen_0                   (1'b0),
    .a_0                      (dma_a_0),
    .d_0                      (dma_d_0),
    .wen_0                    (dma_wen_0),
    .ema_0                    (3'h0),
    .emaw_0                   (2'b00),
    .emas_0                   (1'b0),
    .rdt_0                    (1'b0),
    .wabl_0                   (1'b0),
    .wablm_0                  (2'b00),
    .rawl_0                   (1'b0),
    .rawlm_0                  (2'b00),
    .se_0                     (1'b0),
    .si_0                     (2'b00),
    .dftrambyp_0              (1'b0),
    .ret1n_0                  (1'b1),
    .so_0                     (),
`ifdef FPGA_SYN
  wire fpga_clk;
  BUFG bufg_mem (.O(fpga_clk), .I(clk));
`endif
    .q_0                      (dma_q_0),
    .clk_1                    (dma_clk_1),
    .cen_1                    (dma_cen_1),
    .gwen_1                   (1'b0),
    .a_1                      (dma_a_1),
    .d_1                      (dma_d_1),
    .wen_1                    (dma_wen_1),
    .ema_1                    (3'h0),
    .emaw_1                   (2'b00),
    .emas_1                   (1'b0),
    .rdt_1                    (1'b0),
    .wabl_1                   (1'b0),
    .wablm_1                  (3'b000),
    .rawl_1                   (1'b0),
    .rawlm_1                  (2'b00),
    .stov_1                   (1'b0),
    .q_1                      (dma_q_1)
`ifndef FPGA_SYN
  );
`else
  wire [31:0] debug_irq;
  ila_platform debug_ila (.clk(clk), .probe0(irq), .probe1(irq_src));
`endif

endmodule

// cppe_fpga_top.sv — FPGA top-level wrapper
module cppe_fpga_top (
  input  wire  clk_100mhz,
  input  wire  rst_n,
  input  wire  uart_rx,
  output wire  uart_tx
);
  // SoC instantiation — hierarchical chip_top
  chip_top #(.SOC_ID(32'h0001)) u_chip_top (
    .sys_clk    (clk_100mhz),
    .sys_rst_n  (rst_n),
    .jtag_tck   (1'b0),
    .jtag_tms   (1'b0),
    .jtag_tdi   (1'b0),
    .jtag_tdo   (),
    .uart_rx    (uart_rx),
    .uart_tx    (uart_tx),
    .ext_wakeup (1'b0),
    .wakeup_ack ()
  );
endmodule

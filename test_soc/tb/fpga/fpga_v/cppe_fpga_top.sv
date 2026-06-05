// cppe_fpga_top.sv — FPGA top-level wrapper
module cppe_fpga_top (
  input  wire  clk_100mhz,
  input  wire  rst_n,
  input  wire  uart_rx,
  output wire  uart_tx
);
  // SoC instantiation
  cpu_core u_cpu (.clk(clk_100mhz), .rst_n(rst_n), .*);
  uart_top u_uart (.clk(clk_100mhz), .rst_n(rst_n), .rx(uart_rx), .tx(uart_tx), .*);
endmodule

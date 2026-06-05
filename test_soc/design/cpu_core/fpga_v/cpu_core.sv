// cpu_core.sv -- FPGA version (OLD)

module cpu_core #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 32
) (
  input  wire                    clk,
  input  wire                    rst_n,
  input  wire                    fetch_en,
  input  wire [ADDR_WIDTH-1:0]   instr_addr,
  output wire [DATA_WIDTH-1:0]   instr_data
);

`ifdef FPGA_SYN
  wire clk_gated;
  BUFGCE fpga_clk_gate (.O(clk_gated), .I(clk), .CE(fetch_en));
`endif

  reg [DATA_WIDTH-1:0]  pc_ff;
  reg [DATA_WIDTH-1:0]  ir_ff;
  reg                   valid_ff;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_ff    <= {DATA_WIDTH{1'b0}};
      ir_ff    <= {DATA_WIDTH{1'b0}};
      valid_ff <= 1'b0;
    end else if (fetch_en) begin
      pc_ff    <= instr_addr;
      ir_ff    <= instr_data;
      valid_ff <= 1'b1;
    end
  end

`ifndef FPGA_SYN
  assign debug_pc = pc_ff;
`else
  wire [DATA_WIDTH-1:0] debug_pc;
  ila_core debug_ila (.clk(clk), .probe0(pc_ff), .probe1(ir_ff));
`endif

endmodule

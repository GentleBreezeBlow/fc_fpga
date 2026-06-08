//===========================================================================
// cpu_core.sv — RTL Reference (ground truth)
//===========================================================================
module cpu_core #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 32
) (
  input  wire                    clk,
  input  wire                    rst_n,
  input  wire                    fetch_en,
  input  wire [ADDR_WIDTH-1:0]   instr_addr,
  output wire [DATA_WIDTH-1:0]   instr_data,
  // NEW: added pipeline stall control
  input  wire                    stall_req,
  output wire                    stall_ack
);

`ifdef FPGA_SYN
  wire clk_gated;
  BUFGCE fpga_clk_gate (.O(clk_gated), .I(clk), .CE(fetch_en));
`endif
  //===========================================================
  // Pipeline registers
  //===========================================================
  reg [DATA_WIDTH-1:0]  pc_ff;
  reg [DATA_WIDTH-1:0]  ir_ff;
  reg                   valid_ff;

  // Pipeline control — updated: was free-running, now obeys stall
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_ff    <= {DATA_WIDTH{1'b0}};
      ir_ff    <= {DATA_WIDTH{1'b0}};
      valid_ff <= 1'b0;
    end else if (fetch_en && !stall_req) begin   // CHANGED: was just fetch_en
      pc_ff    <= instr_addr;
      ir_ff    <= instr_data;
      valid_ff <= 1'b1;
    end
  end

`ifndef FPGA_SYN
  assign stall_ack = stall_req && valid_ff;       // NEW signal
`else
  wire [DATA_WIDTH-1:0] debug_pc;
  ila_core debug_ila (.clk(clk), .probe0(pc_ff), .probe1(ir_ff));
`endif

endmodule

//===========================================================================
// timer.sv — General-Purpose Countdown Timer
//===========================================================================
module timer #(
  parameter TIMER_WIDTH = 32
) (
  input  wire                     clk,
  input  wire                     rst_n,
  input  wire                     start,
  input  wire [TIMER_WIDTH-1:0]   load_val,
  output wire [TIMER_WIDTH-1:0]   count,
  output wire                     expired
);

  reg [TIMER_WIDTH-1:0] count_reg;
  reg                   running;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count_reg <= '0;
      running   <= 1'b0;
    end else begin
      if (start && !running) begin
        count_reg <= load_val;
        running   <= 1'b1;
      end else if (running) begin
        if (count_reg > 0)
          count_reg <= count_reg - 1'b1;
        else
          running <= 1'b0;
      end
    end
  end

  assign count   = count_reg;
  assign expired = running && (count_reg == 0);

endmodule

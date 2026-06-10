////// : SRAM decoder with memory check logic
////// TYPE:module
/////
////history
// 2024-06-17: Initial version, copied from sram_decoder_mchk


module sram_decoder_mchk #(
    parameter CUT_NUM        = 16,
    parameter ST_NUM         = 0,
    parameter CUT_NUM_BITS   = 4,
    parameter ADDR_WIDTH     = 16,
    parameter ADDR_CUT_WIDTH = ADDR_WIDTH - $clog2(CUT_NUM),
    parameter DATA_WIDTH    = 39,
    parameter LP_EN         = 1'b1  // Default is 1, gate off WEN by CS, timing is WORSE
)
(
     reset_b,
     clk_in,
        clk_out,       // clock to the memory cuts

       CS,
      cs_b_out,      // Chip select of the memory cuts

       WE_in,
       WE_b_out,      // Write enable to memory cuts

       Q_out,
    q_in,  // Read data from memory cuts

       D_in,
     D_out,  // Write data to memory cuts

       WEM_in,
     WEM_out,// Bit enables to memory cuts

        Addr,
     ADR_out,
      // Address out

       mon_err_inj,
       mon_err
);

///////
localparam [0:0] LME = 1'b1;
localparam CUT_NUM_BITS = $clog2(CUT_NUM);

    input                       reset_b;
    input                       clk_in;
    output reg [CUT_NUM-1:0]       clk_out;       // clock to the memory cuts

    input                       CS;
    output [CUT_NUM-1:0]       cs_b_out;      // Chip select of the memory cuts

    input                       WE_in;
    output [CUT_NUM-1:0]        WE_b_out;      // Write enable to memory cuts

    output [DATA_WIDTH-1:0]     Q_out;
    input  [DATA_WIDTH*CUT_NUM-1 : 0] q_in;  // Read data from memory cuts

    input  [DATA_WIDTH-1:0]     D_in;
    output [DATA_WIDTH*CUT_NUM-1 : 0] D_out;  // Write data to memory cuts

    input  [DATA_WIDTH-1:0]     WEM_in;
    output [DATA_WIDTH*CUT_NUM-1 : 0] WEM_out;// Bit enables to memory cuts

    input  [ADDR_WIDTH-1 : 0]    Addr;
    output [ADDR_CUT_WIDTH*CUT_NUM-1 : 0] ADR_out; // Address out

    input  [CUT_NUM-1:0]        mon_err_inj;
    output reg                  mon_err;

sram_decoder #(
    .CUT_NUM      (CUT_NUM      ),
    .ST_NUM       (ST_NUM       ),
    .CUT_NUM_BITS (CUT_NUM_BITS ),
    .ADDR_WIDTH   (ADDR_WIDTH   )
)

endmodule
module ahb_prom64 #(
    parameter PROM_DATA_WIDTH = 64,
    parameter PROM_ALLOW_USER_READ = 1
)
(
    input                       clk,                // Platform system clock
    input                       async_reset_b,      // Async Platform reset
    input [1:0]                 htrans,             // Transfer type: 1X = rom ctl
    input [31:0]                haddr,              // Address bus
    input                       hwrite,             // Write / Read_b
    input                       hprot1,             // supervisor access - hprot[1]
    input [PROM_DATA_WIDTH-1:0] prom_rdata,         // ROM Data OUT
    input [3:0]                 prom_size,
    input                       prom_hole,
    input                       prom_fast,

    // AHB outputs
    output                      hresp0,             // Error response
    output                      hready_out,         // current access termination
    output [PROM_DATA_WIDTH-1:0] hrdata,           // Read data bus
    output [19:0]               prom_addr,          // ROM Address
    output                      prom_cs_b           // ROM chip select
);

wire [19:2] read_addr_zerod;
wire        prom_ap;
wire        prom_valid;
wire        zero_10;
wire        zero_11;
wire        zero_12;
wire        zero_13;
wire        zero_14;
wire        zero_15;
wire        zero_16;
wire        zero_17;
wire        zero_18;
wire        zero_19;
wire        prom_hit_hole;
wire        prom_error_ap;
wire        prom_error_dp;
reg         prom_error_dp2;
wire        htrans_go;                          // htrans and hready

reg [1:0]   prom_state;

// 0x4    4KBytes     3KBytes
// 0x5    8KBytes     6KBytes
// 0x6    16KBytes    12KBytes

endmodule
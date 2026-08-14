// rram_fpga_wrap.sv — FPGA synthesizable wrapper for RRAM
//
// Replaces async RRAM with fpga_spram (XPM SPRAM).
// Name-derived sizing: 256K bits / 32-bit data = 8192 words
//   XADR (row):  8 bits → 256 rows
//   YADR (col):  5 bits → 32:1 column mux
//   Total addr = 13 bits → 8192 words × 32 bits = 256K

module rram_fpga_wrap #(
    parameter NUM_XADR = 8,
    parameter NUM_YADR = 5,
    parameter NUM_OUT  = 32,
    parameter NUM_CFG  = 8,
    parameter NUM_CR   = 8
)(
    // ---- Original RRAM ports ----
    output                        RDONE,
    input                         SET,
    input                         RESET,
    input                         RST,
    input                         NAP,
    input                         IFREN,
    input                         IFREN1,
    input                         REDEN,
    input                         XE,
    input                         YE,
    input                         READ,
    input                         CE,
    input                         POC_IO,
    input                         PCH_EXT,
    input                         AE,
    input  [NUM_XADR-1:0]         XADR,
    input  [NUM_YADR-1:0]         YADR,
    output [NUM_OUT-1:0]          DOUT,
    input  [NUM_OUT-1:0]          DIN,
    input  [NUM_CFG-1:0]          CFG_MACRO,
    input  [NUM_CR-1:0]           DIN_CR,
    output [NUM_CR-1:0]           DOUT_CR,

    // ---- FPGA additions ----
    input                         clk
);

    localparam ADDRWIDTH = NUM_XADR + NUM_YADR;
    localparam MEMDEPTH  = 1 << ADDRWIDTH;
    localparam BYTEWIDTH = 8;

    // ---- Flat address --------------------------------------------------------
    wire [ADDRWIDTH-1:0] ram_addr = {XADR, YADR};

    // ---- Control -------------------------------------------------------------
    wire write_strobe = CE && !NAP && !READ && (SET || RESET);
    wire read_enable  = CE && !NAP && READ;

    // ---- RDONE — asserted 1 cycle after read (fpga_spram read latency = 1) ---
    reg rdone_r;
    always @(posedge clk or posedge RST) begin
        if (RST)
            rdone_r <= 1'b0;
        else
            rdone_r <= read_enable;
    end
    assign RDONE = rdone_r;

    // ---- Write byte-enables — all bytes enabled on write ---------------------
    wire [NUM_OUT/BYTEWIDTH-1:0] ram_we = {NUM_OUT/BYTEWIDTH{write_strobe}};

    // ---- fpga_spram instantiation --------------------------------------------
    fpga_spram #(
        .MEMDEPTH (MEMDEPTH),
        .MEMWIDTH (NUM_OUT),
        .BYTEWIDTH(BYTEWIDTH),
        .ADDRWIDTH(ADDRWIDTH),
        .MEMTYPE  ("block")
    ) u_spram (
        .ram_clk   (clk),
        .ram_addr  (ram_addr),
        .ram_me    (CE && !NAP),
        .ram_we    (ram_we),
        .ram_wdata (DIN),
        .ram_rdata (DOUT)
    );

    // ---- Unused outputs tie-off ----------------------------------------------
    assign DOUT_CR = {NUM_CR{1'b0}};

    // ---- Unused inputs — no-connect (synthesis will optimize away) ------------

endmodule

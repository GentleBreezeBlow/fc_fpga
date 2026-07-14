//---------------------------
// fpga_mem 自定义RAM模型
//---------------------------
module fpga_mem
#(parameter MEMDEPTH  = 8192,
  parameter MEMWIDTH  = 32,
  parameter NO_WE     = 0
)
(
input                  CLK,
input [$clog2(MEMDEPTH)-1:0] ADR,
input [MEMWIDTH-1:0]   WEM,
input                  WE,
input                  ME,
input [MEMWIDTH-1:0]   D,
output reg [MEMWIDTH-1:0] Q
);

reg [MEMWIDTH-1:0] mem [0:MEMDEPTH-1]; /* synthesis RAM_STYLE = "BRAM" */;
wire addr_valid = (ADR < MEMDEPTH) ? 1'b1 : 1'b0;
wire write_en = ME && WE && addr_valid;

always@(posedge CLK) begin
    if(write_en) begin
        if(NO_WE == 1) begin
            mem[ADR] <= D;
        end
        else begin
            for(integer i=0; i<MEMWIDTH; i=i+1) begin
                if(WEM[i])
                    mem[ADR][i] <= D[i];
            end
        end
    end

    if(!ME || !addr_valid) begin
        Q <= {MEMWIDTH{1'b0}};
    end
    else begin
        Q <= mem[ADR];
    end
end

endmodule

//---------------------------
// fpga_spram XPM SPRAM 带字节写
//---------------------------
module fpga_spram
#(parameter MEMDEPTH   = 8192,
  parameter MEMWIDTH   = 32,
  parameter BYTEWIDTH  = 8,
  parameter ADDRWIDTH  = 13,
  parameter INITFILE  = "none",
  parameter MEMTYPE   = "block"
)
(
input wire               ram_clk,
input wire [ADDRWIDTH-1:0] ram_addr,
input wire               ram_me,
input wire [MEMWIDTH/BYTEWIDTH-1:0] ram_we,
input wire [MEMWIDTH-1:0] ram_wdata,
output wire [MEMWIDTH-1:0] ram_rdata
);

xpm_memory_spram #(
    .ADDR_WIDTH_A(ADDRWIDTH),        // DECIMAL
    .AUTO_SLEEP_TIME(0),             // DECIMAL
    .BYTE_WRITE_WIDTH_A(BYTEWIDTH),  // DECIMAL
    .ECC_MODE("no_ecc"),             // String
    .MEMORY_INIT_FILE(INITFILE),     // String
    .MEMORY_INIT_PARAM("0"),         // String
    .MEMORY_OPTIMIZATION("true"),    // String
    .MEMORY_PRIMITIVE(MEMTYPE),      // String
    .MEMORY_SIZE(MEMDEPTH*MEMWIDTH), // DECIMAL
    .MESSAGE_CONTROL(0),             // DECIMAL
    .READ_DATA_WIDTH_A(MEMWIDTH),    // DECIMAL
    .READ_LATENCY_A(1),              // DECIMAL
    .READ_RESET_VALUE_A("0"),         // String
    .RST_MODE_A("SYNC"),             // String
    .USE_MEM_INIT(1),                // DECIMAL
    .WAKEUP_TIME("disable_sleep"),   // String
    .WRITE_DATA_WIDTH_A(MEMWIDTH),   // DECIMAL
    .WRITE_MODE_A("read_first")      // String
)
data_memory_spram_inst (
    .douta(ram_rdata),
    .addra(ram_addr),
    .clka(ram_clk),
    .dina(ram_wdata),
    .ena(ram_me),
    .rsta(1'b0),
    .sleep(1'b0),
    .wea(ram_we)
);

endmodule

//---------------------------
// fpga_sdpram XPM Simple Dual-Port RAM (one read port, one write port)
// Port A = write, Port B = read
//---------------------------
module fpga_sdpram
#(parameter MEMDEPTH   = 8192,
  parameter MEMWIDTH   = 32,
  parameter BYTEWIDTH  = 8,
  parameter ADDRWIDTH  = 13,
  parameter INITFILE  = "none",
  parameter MEMTYPE   = "block"
)
(
input wire                     wr_clk,
input wire                     rd_clk,
input wire [ADDRWIDTH-1:0]    wr_addr,
input wire [ADDRWIDTH-1:0]    rd_addr,
input wire                     wr_en,
input wire [MEMWIDTH/BYTEWIDTH-1:0] wr_we,
input wire [MEMWIDTH-1:0]      wr_data,
input wire                     rd_en,
output wire [MEMWIDTH-1:0]     rd_data
);

xpm_memory_sdpram #(
    .ADDR_WIDTH_A(ADDRWIDTH),           // DECIMAL
    .ADDR_WIDTH_B(ADDRWIDTH),           // DECIMAL
    .AUTO_SLEEP_TIME(0),                // DECIMAL
    .BYTE_WRITE_WIDTH_A(BYTEWIDTH),     // DECIMAL
    .ECC_MODE("no_ecc"),                // String
    .MEMORY_INIT_FILE(INITFILE),        // String
    .MEMORY_INIT_PARAM("0"),            // String
    .MEMORY_OPTIMIZATION("true"),       // String
    .MEMORY_PRIMITIVE(MEMTYPE),         // String
    .MEMORY_SIZE(MEMDEPTH*MEMWIDTH),    // DECIMAL
    .MESSAGE_CONTROL(0),                // DECIMAL
    .READ_DATA_WIDTH_B(MEMWIDTH),       // DECIMAL
    .READ_LATENCY_B(1),                 // DECIMAL
    .READ_RESET_VALUE_B("0"),           // String
    .RST_MODE_A("SYNC"),                // String
    .RST_MODE_B("SYNC"),                // String
    .USE_MEM_INIT(1),                   // DECIMAL
    .WAKEUP_TIME("disable_sleep"),      // String
    .WRITE_DATA_WIDTH_A(MEMWIDTH),      // DECIMAL
    .WRITE_MODE_A("read_first")         // String
)
data_memory_sdpram_inst (
    .doutb(rd_data),                    // read data (port B)
    .addra(wr_addr),                    // write address (port A)
    .addrb(rd_addr),                    // read address (port B)
    .clka(wr_clk),                      // write clock (port A)
    .clkb(rd_clk),                      // read clock (port B)
    .dina(wr_data),                     // write data (port A)
    .ena(wr_en),                        // write enable (port A)
    .enb(rd_en),                        // read enable (port B)
    .rsta(1'b0),                        // reset port A
    .rstb(1'b0),                        // reset port B
    .sleep(1'b0),                       // sleep
    .wea(wr_we)                         // byte-write enable (port A)
);

endmodule

//---------------------------
// fpga_sprom XPM ROM
//---------------------------
module fpga_sprom
#(parameter MEMDEPTH  = 16384,
  parameter MEMWIDTH  = 32,
  parameter ADDRWIDTH = 14,
  parameter INITFILE  = "none"
)
(
input wire [ADDRWIDTH-1:0] ram_addr,
input wire                 ram_me,
input                      ram_clk,
output wire [MEMWIDTH-1:0] ram_rdata
);

xpm_memory_sprom #(
    .ADDR_WIDTH_A(ADDRWIDTH),        // DECIMAL
    .AUTO_SLEEP_TIME(0),             // DECIMAL
    .ECC_MODE("no_ecc"),             // String
    .MEMORY_INIT_FILE(INITFILE),     // String
    .MEMORY_INIT_PARAM("0"),         // String
    .MEMORY_OPTIMIZATION("true"),    // String
    .MEMORY_PRIMITIVE("block"),      // String
    .MEMORY_SIZE(MEMDEPTH*MEMWIDTH), // DECIMAL
    .MESSAGE_CONTROL(0),             // DECIMAL
    .READ_DATA_WIDTH_A(MEMWIDTH),    // DECIMAL
    .READ_LATENCY_A(1),              // DECIMAL
    .READ_RESET_VALUE_A("0"),        // String
    .RST_MODE_A("SYNC"),             // String
    .USE_MEM_INIT(1),                // DECIMAL
    .WAKEUP_TIME("disable_sleep")    // String
)
data_memory_sprom_inst (
    .douta(ram_rdata),
    .addra(ram_addr),
    .clka(ram_clk),
    .ena(ram_me),
    .rsta(1'b0),
    .sleep(1'b0)
);

endmodule
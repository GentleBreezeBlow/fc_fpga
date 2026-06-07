// when xspram depth use 768, vivado will report error.
wire [7:0] ram_we = {8{WE}} & &WEM[63:56], &WEM[55:48], &WEM[47:40], &WEM[39:32], &WEM[31:24], &WEM[23:16], &WEM[15:8], &WEM[7:0];

fpga_spram #(
    .MEMDEPTH (1024 ),
    .MEMWIDTH (64   ),
    .BYTEWIDTH(8    ),
    .ADDRWIDTH(10   ),
    .MEMTYPE  ("block")
)
mem_64(
    .ram_clk  (CLK     ),
    .ram_addr (ADR[9:0]),
    .ram_me   (ME      ),
    .ram_we   (ram_we[7:0]),
    .ram_wdata(D[63:0] ),
    .ram_rdata(Q[63:0] )
);

genvar i;
generate
for(i=0;i<8;i++)
begin:gen_upecc
fpga_spram #(
    .MEMDEPTH (1024 ),
    .MEMWIDTH (5    ),
    .BYTEWIDTH(5    ),
    .ADDRWIDTH(10   ),
    .MEMTYPE  ("block")
)
ecc(
    .ram_clk  (CLK          ),
    .ram_addr (ADR          ),
    .ram_me   (ME           ),
    .ram_we   (ram_we[i]    ),
    .ram_wdata(D[64+5*i+:5] ),
    .ram_rdata(Q[64+5*i+:5] )
);
end
endgenerate

assign QP    = 'b0;
assign S0_L  = 'b0;
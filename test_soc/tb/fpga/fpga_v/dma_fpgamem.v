wire [8:0] ram_we = {9{WE}} & &WEM[108:104] , &WEM[63:56], &WEM[55:48], &WEM[47:40], &WEM[39:32], &WEM[31:24], &WEM[23:16], &WEM[15:8], &WEM[7:0]};

fpga_spram #(
    .MEMDEPTH (128 ),
    .MEMWIDTH (64 ),
    .BYTEWIDTH(8 ),
    .ADDRWIDTH(7 ),
    .MEMTYPE  ("block")
)
mem_64(
    .ram_clk  (CLK      ),
    .ram_addr (ADR[6:0] ),
    .ram_me   (ME       ),
    .ram_we   (ram_we[7:0]),
    .ram_wdata(D[63:0]  ),
    .ram_rdata(Q[63:0]
);

genvar i;
generate
for(i=0;i<9;i++)
begin:gen_upecc
fpga_spram #(
    .MEMDEPTH (128 ),
    .MEMWIDTH (5 ),
    .BYTEWIDTH(5 ),
    .ADDRWIDTH(7),
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

assign QP = 'b0;

endmodule
// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT




module mem_ram #(parameter DW = 8, DEPTH = 16)

   (
     
    input  var logic clk,
    input  var logic wren,
    input  var logic [DW-1:0] wdata,
    input  var logic [$clog2(DEPTH)-1:0] waddr,

    input  var logic rden,
    input  var logic [$clog2(DEPTH)-1:0] raddr,
    
    output var logic [DW-1:0] rdata

     );

    logic [DEPTH-1:0] [DW-1:0] mem;


    always_ff @(posedge clk) begin
	if (wren)
	    mem[waddr] <= wdata;	
    end

    always_ff @(posedge clk) begin
	if (rden)
	    rdata <= mem[raddr];
    end


endmodule

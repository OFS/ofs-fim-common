// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT



// FF fifo 2 deep
//
`default_nettype none
 module fifo_ff_8dp #(parameter DW=8) 
    (
     input var logic                    clk,
     input var logic                    reset,
     input var logic                    push,
     input var logic                    pop,     
     input var logic [DW-1:0]           dIn,

     output var logic [DW-1:0]          dOut,
     output logic                       full,
     output logic                       empty,
     output logic [3:0]                 cnt
     );

    localparam DEPTH = 8;
    
    
    logic [15:0] rst_reg;   
    // Generate arrays of reset to be used in submodule
    always_ff @(posedge clk) begin
	rst_reg <= '{default:reset};
    end

    logic [DW-1:0] prefReg1, prefReg2, prefReg3, prefReg4, 
		   prefReg5, prefReg6, prefReg7, prefReg8,
		   wdata;
    logic [$clog2(DEPTH):0]    prefPtrNxt, prefPtr, prefCnt;

    always_comb begin
	empty   = prefPtr == 'd0;
	full    = prefPtr == 'd7;
	cnt     = prefPtr;

	dOut  = prefReg1;
    end
    
    always_comb begin
	prefPtrNxt = (push & !pop)  ? prefPtr + 1'b1 :
		     (!push & pop)  ? prefPtr - 1'b1 :
                                      prefPtr          ;	
    end

    always_ff @(posedge clk) begin	
	prefPtr <= prefPtrNxt;
	
	if (rst_reg[0])
	    prefPtr <= 2'd0;
    end // always_ff @ (posedge clk)
    
    always_ff @(posedge clk) begin
	
        prefReg1 <= RegUpdate ('d1, prefPtrNxt, dIn, prefReg2, prefReg1, push, pop);
	prefReg2 <= RegUpdate ('d2, prefPtrNxt, dIn, prefReg3, prefReg2, push, pop);
	prefReg3 <= RegUpdate ('d3, prefPtrNxt, dIn, prefReg4, prefReg3, push, pop);
	prefReg4 <= RegUpdate ('d4, prefPtrNxt, dIn, prefReg5, prefReg4, push, pop);
	prefReg5 <= RegUpdate ('d5, prefPtrNxt, dIn, prefReg6, prefReg5, push, pop);
	prefReg6 <= RegUpdate ('d6, prefPtrNxt, dIn, prefReg7, prefReg6, push, pop);
	prefReg7 <= RegUpdate ('d7, prefPtrNxt, dIn, prefReg8, prefReg7, push, pop);
	prefReg8 <= RegUpdate ('d8, prefPtrNxt, dIn, '0,       prefReg8, push, pop);
	  
	if (rst_reg[1])
	    prefReg1 <= '0;

        if (rst_reg[2])
	    prefReg2 <= '0;
	
        if (rst_reg[3])
	    prefReg3 <= '0;

        if (rst_reg[4])
	    prefReg4 <= '0;  

	if (rst_reg[5])
	    prefReg5 <= '0;

        if (rst_reg[6])
	    prefReg6 <= '0;
	
        if (rst_reg[7])
	    prefReg7 <= '0;

        if (rst_reg[8])
	    prefReg8 <= '0;  

    end

    function [DW-1:0] RegUpdate;
	input [$clog2(DEPTH):0]    myAddr;
	input [$clog2(DEPTH):0]    wrAddr;
	
	input [DW-1:0] wrData;
	input [DW-1:0] rdData;
	input [DW-1:0] nxtData;
	
	input          wrEn;
	input          rdEn;
	
	begin
	    if (wrEn & (myAddr == wrAddr))
		RegUpdate = wrData;
	    else if (rdEn)
		RegUpdate = rdData;
	    else
		RegUpdate = nxtData;
	end
    endfunction //

endmodule
     

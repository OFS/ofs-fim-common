// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


//
//
//

`default_nettype none
module fifo_pref#(parameter DW=8) (
  input  var logic clk,
  input  var logic reset,
  input  var logic push,
  input  var logic pop,
  input  var logic [DW-1:0] dIn,
				   
  output var logic [2:0] cnt,
  output var logic [DW-1:0] dOut,
  output var logic full,
  output var logic empty
);
   
   
   

   logic 		     prefWr, prefRd, prefFull;
   logic [2:0] 		     prefPtr, prefPtrNxt;
   logic [2:0] 		     prefCntNxt, prefCnt;
   logic [DW-1:0] 	     prefReg1, prefReg2, prefReg3, prefReg4,
			     prefReg5, prefReg6, prefReg7, prefReg8;

   
   
      
   assign prefWr = push;
   assign prefRd = pop;
   
   assign prefPtrNxt = (prefWr & !prefRd) ? prefPtr + 1'b1 :
		       (!prefWr & prefRd) ? prefPtr - 1'b1 :
		                            prefPtr          ;
   always_ff @(posedge clk)
     if (reset)
       prefPtr <= 3'd0;
     else
       prefPtr <= prefPtrNxt;
   
    always_ff @(posedge clk)  begin
	if (prefWr & (prefPtrNxt == 3'd1))
	    prefReg1 <= dIn;
	else if (prefRd)
	    prefReg1 <= prefReg2;
	
	if (prefWr & (prefPtrNxt == 3'd2))
	    prefReg2 <= dIn;
	else if (prefRd)
	    prefReg2 <= prefReg3;
	
	if (prefWr & (prefPtrNxt == 3'd3))
	    prefReg3 <= dIn;
	else if (prefRd)
	    prefReg3 <= prefReg4;
	
	if (prefWr & (prefPtrNxt == 3'd4))
	    prefReg4 <= dIn;
	else if (prefRd)
	    prefReg4 <= prefReg5;

	if (prefWr & (prefPtrNxt == 3'd5))
	    prefReg5 <= dIn;
	else if (prefRd)
	    prefReg5 <= prefReg6;

	if (prefWr & (prefPtrNxt == 3'd6))
	    prefReg6 <= dIn;
	else if (prefRd)
	    prefReg6 <= prefReg7;
	
	if (prefWr & (prefPtrNxt == 3'd7))
	    prefReg7 <= dIn;
	else if (prefRd)
	    prefReg7 <= 'd0;
    end

   assign full = prefPtr > 3'd2;
   assign empty = prefPtr == 3'd0;

   assign dOut = prefReg1;

   assign cnt = prefPtr;
   
endmodule
`default_nettype wire




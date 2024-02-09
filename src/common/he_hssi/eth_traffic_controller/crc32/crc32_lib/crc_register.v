// Copyright (C) 2001-2018 Intel Corporation
// SPDX-License-Identifier: MIT

// typical CRC register bank
//   the init constant is defaulted to all 1's for CRC-32
// aclr beats ena beats sclr beats init in terms of signal priority.
//
// Revision:
// 04-03-2006 - Initnal version (baeckler)
// 06-09-2012 - Change the default mode to 0 to prevent using the WYSIWYG Version which tide to Device specific
// 07-09-2012 - Fix Quartus Warning Message: Unknow sythesis attribue ( remove "// synthesis XXX" syntax)

module crc_register (d, q, clk, init, sclr, ena, aclr);

parameter WIDTH = 32;
parameter METHOD = 0;
parameter INIT_CONST = 32'hffffffff;

input [WIDTH-1:0] d;
input clk,init,sclr,ena,aclr;
output [WIDTH-1:0] q;
reg [WIDTH-1:0] q;

genvar i;
generate
	if (METHOD == 0) begin
		/////////////////////////////////////
		// Generic style.
		//    Depending on the WIDTH setting and surrounding logic the synthesis 
		//  tool may not use the dedicated hardware.  For 
		//  example at WIDTH=1 the LUT implementation is clearly
		//  better.  To force secondary signals use the WYS version below.	
		/////////////////////////////////////
		always @(posedge clk or posedge aclr) begin
			if (aclr) q <= 0;
			else begin
				if (ena) begin
					if (sclr) q <= 0;
					else if (init) q <= INIT_CONST;
					else q <= d;
				end
			end
		end
	end
	else begin
		///////////////////////
		// WYSIWYG style
		///////////////////////
		wire [WIDTH-1:0] q_internal;

		for (i=0; i<WIDTH; i=i+1)
		begin : regs
			stratixii_lcell_ff r (
				.clk(clk),
				.ena(ena),
				.datain (d[i]),
				.sload (init),
				.adatasdata (INIT_CONST[i]),
				.sclr (sclr),
				.aload(1'b0),
				.aclr(aclr),
		
			// These are simulation-only chipwide
			// reset signals.  Both active low.
						
			// synthesis translate_off
				.devpor(1'b1),
				.devclrn(1'b1),
			// synthesis translate on

				.regout (q_internal[i])	
			);
		end

		always @(q_internal) begin
			q = q_internal;
		end
	end
endgenerate

endmodule

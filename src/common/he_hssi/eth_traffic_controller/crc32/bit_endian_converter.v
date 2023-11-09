// Copyright (C) 2001-2018 Intel Corporation
// SPDX-License-Identifier: MIT

// Bit Endian Converter
//	Convert the input data bit to big or little endian
//	if input is big endian, the output will be little endian
//	if input is little endian, the output will be big endian
//
// Revision:
// 06-09-2012 - intial version
// 07-09-2012 - fix: Assign name to every for loop block in bit_endian_converter.v to prevent Quartus report Error

module bit_endian_converter (
	ENABLE,
	DATA_IN,
	DATA_OUT
);

parameter	DATA_WIDTH = 32;				//8, 16, 32, 64

input						ENABLE;
input	[DATA_WIDTH-1:0]	DATA_IN;
output	[DATA_WIDTH-1:0]	DATA_OUT;

genvar i;
generate
	if (DATA_WIDTH == 8) begin 				
		for (i=0; i<8; i=i+1) begin : bit_endian_conv_loop
			assign	DATA_OUT[i] = ENABLE? DATA_IN[DATA_WIDTH-1-i] : DATA_IN[i];	
		end
	end			
	else if (DATA_WIDTH == 16) begin
		for (i=0; i<8; i=i+1) begin : bit_endian_conv_loop
			assign	DATA_OUT[i] = ENABLE? DATA_IN[DATA_WIDTH-1-8-i] : DATA_IN[i]; 
			assign	DATA_OUT[i+8] = ENABLE? DATA_IN[DATA_WIDTH-1-i] : DATA_IN[i+8]; 
		end	
	end
	else if (DATA_WIDTH == 32) begin
		for (i=0; i<8; i=i+1) begin : bit_endian_conv_loop
			assign	DATA_OUT[i] = ENABLE? DATA_IN[DATA_WIDTH-1-24-i] : DATA_IN[i];
			assign	DATA_OUT[i+8] = ENABLE? DATA_IN[DATA_WIDTH-1-16-i] : DATA_IN[i+8];
			assign	DATA_OUT[i+16] = ENABLE? DATA_IN[DATA_WIDTH-1-8-i] : DATA_IN[i+16];
			assign	DATA_OUT[i+24] = ENABLE? DATA_IN[DATA_WIDTH-1-i] : DATA_IN[i+24];
		end
	end
	else if (DATA_WIDTH == 64) begin
		for (i=0; i<8; i=i+1) begin : bit_endian_conv_loop
			assign	DATA_OUT[i] = ENABLE? DATA_IN[DATA_WIDTH-1-56-i] : DATA_IN[i];
			assign	DATA_OUT[i+8] = ENABLE? DATA_IN[DATA_WIDTH-1-48-i] : DATA_IN[i+8];
			assign	DATA_OUT[i+16] = ENABLE? DATA_IN[DATA_WIDTH-1-40-i] : DATA_IN[i+16];
			assign	DATA_OUT[i+24] = ENABLE? DATA_IN[DATA_WIDTH-1-32-i] : DATA_IN[i+24];
			assign	DATA_OUT[i+32] = ENABLE? DATA_IN[DATA_WIDTH-1-24-i] : DATA_IN[i+32];
			assign	DATA_OUT[i+40] = ENABLE? DATA_IN[DATA_WIDTH-1-16-i] : DATA_IN[i+40];
			assign	DATA_OUT[i+48] = ENABLE? DATA_IN[DATA_WIDTH-1-8-i] : DATA_IN[i+48];
			assign	DATA_OUT[i+56] = ENABLE? DATA_IN[DATA_WIDTH-1-i] : DATA_IN[i+56];
		end
	end
endgenerate

endmodule

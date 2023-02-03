// (C) 2001-2018 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


// Byte Endian Converter
//	Convert the input data byte to big or little endian
//	if input is big endian, the output will be little endian
//	if input is little endian, the output will be big endian
//
// Revision:
// 05-09-2012 - intial version

module byte_endian_converter (
	ENABLE,
	DATA_IN,
	DATA_OUT
);

parameter	DATA_WIDTH = 32;				//8, 16, 32, 64

input						ENABLE;
input	[DATA_WIDTH-1:0]	DATA_IN;
output	[DATA_WIDTH-1:0]	DATA_OUT;

generate
	if (DATA_WIDTH == 8) begin 				//no byte endian is required, passthrough
		assign	DATA_OUT = DATA_IN;	
	end			
	else if (DATA_WIDTH == 16) begin
		assign	DATA_OUT = ENABLE? {DATA_IN[7:0], DATA_IN[15:8]} : DATA_IN; 
	end
	else if (DATA_WIDTH == 32) begin
		assign	DATA_OUT = ENABLE? {DATA_IN[7:0], DATA_IN[15:8], DATA_IN[23:16], DATA_IN[31:24]}: DATA_IN;
	end
	else if (DATA_WIDTH == 64) begin
		assign	DATA_OUT = ENABLE? {DATA_IN[7:0], DATA_IN[15:8], DATA_IN[23:16], DATA_IN[31:24], DATA_IN[39:32], DATA_IN[47:40], DATA_IN[55:48], DATA_IN[63:56]}: DATA_IN;
	end
endgenerate

endmodule
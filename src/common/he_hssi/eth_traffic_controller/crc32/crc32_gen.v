// Copyright (C) 2001-2018 Intel Corporation
// SPDX-License-Identifier: MIT

// CRC32 Generator
//	CRC32 Generator - Interface is compatible with CRC Compiler
//
// Revision:
// 05-09-2012 - intial version
// 14-09-2012 - Enhancement:
//					1. Add Avalon ST Ready Signal as standard Avalon ST Compliance
//					2. crc_checksum_aligner.v move to top as this module is mainly to adjust the latency to compatible with CRC Compiler

module crc32_gen (
	CLK,
	RESET_N,
	
	AVST_READY,
	AVST_VALID,
	AVST_SOP,
	AVST_DATA,
	AVST_EOP,
	AVST_EMPTY,
	
	CRC_VALID,
	CRC_CHECKSUM		
);

parameter	DATA_WIDTH = 32;		//8, 16(optional), 32,64
parameter	EMPTY_WIDTH = 2;		//x, 1 			 , 2 ,3 
parameter	CRC_WIDTH = 32;			//CRC32
parameter	REVERSE_DATA = 1;		//0 - non reverse data, 1 - reverse data
parameter   CRC_PIPELINE_MODE = 1;	//Default set to 0, set to 1 for pipeline mode (init and data input at the same cycle)
parameter	CRC_OUT_LATENCY = 3;	//Add extra latency to match with CRC Compiler Latency

input						CLK;
input						RESET_N;

output						AVST_READY;
input						AVST_VALID;
input						AVST_SOP;
input	[DATA_WIDTH-1:0]	AVST_DATA;
input						AVST_EOP;
input	[EMPTY_WIDTH-1:0]	AVST_EMPTY;

output						CRC_VALID;
output	[CRC_WIDTH-1:0]		CRC_CHECKSUM;

wire						crc_valid_sig;
wire	[CRC_WIDTH-1:0]		crc_checksum_sig;

crc32_calculator #(DATA_WIDTH, EMPTY_WIDTH, CRC_WIDTH, REVERSE_DATA, CRC_PIPELINE_MODE) crc32_calculator_u0 (
	.CLK					(CLK),
	.RESET_N				(RESET_N),
	
	.DATA_INPUT_ENDIAN_SEL	(1'b1),			
	.CRC_OUTPUT_ENDIAN_SEL	(1'b1),
	
	.AVST_READY				(AVST_READY),
	.AVST_VALID				(AVST_VALID),
	.AVST_SOP				(AVST_SOP),
	.AVST_DATA				(AVST_DATA),
	.AVST_EOP				(AVST_EOP),
	.AVST_EMPTY				(AVST_EMPTY),
	                    	
	.CRC_VALID				(crc_valid_sig),
	.CRC_CHECKSUM			(crc_checksum_sig)
);

crc_checksum_aligner #(CRC_WIDTH, CRC_OUT_LATENCY) crc_checksum_aligner_u0 (
	.CLK					(CLK),
	.RESET_N				(RESET_N),
	
	.CRC_CHECKSUM_LATCH_IN	(crc_valid_sig),
	.CRC_CHECKSUM_IN		(crc_checksum_sig),
	
	.CRC_VALID_OUT			(CRC_VALID),
	.CRC_CHECKSUM_OUT		(CRC_CHECKSUM)
);

endmodule

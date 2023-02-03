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


// CRC32 Checker
//	CRC32 Checker - Interface is compatible with CRC Compiler
//
// Revision:
// 05-09-2012 - intial version
// 14-09-2012 - Enhancement:
//					1. Add Avalon ST Ready Signal as standard Avalon ST Compliance
//					2. Add crc_checksum_aligner.v to enable variable latency adjustment - currently set to 0 which is no latency
//					3. Ethernet pkt CRC Extractor and eop aligner is no longer required as CRC checker will compare with fix CRC32_ETHERNET_CHK_VALUE 

module crc32_chk (
	CLK,
	RESET_N,
	
	AVST_READY,
	AVST_VALID,
	AVST_SOP,
	AVST_DATA,
	AVST_EOP,
	AVST_EMPTY,
	
	CRC_VALID,
	CRC_BAD		
);

parameter	DATA_WIDTH = 32;		//8, 16(optional), 32,64
parameter	EMPTY_WIDTH = 2;		//x, 1 			 , 2 ,3 
parameter	CRC_WIDTH = 32;			//CRC32
parameter	REVERSE_DATA = 1;		//0 - non reverse data, 1 - reverse data
parameter   CRC_PIPELINE_MODE = 1;	//Default set to 0, set to 1 for pipeline mode (init and data input at the same cycle)
parameter	CRC_OUT_LATENCY = 0;	//Add extra latency to match with CRC Compiler Latency

parameter	CRC32_ETHERNET_CHK_VALUE = 32'h1CDF4421;		//Ethernet CRC32 Residue 0x2144DF1C

input						CLK;
input						RESET_N;

output						AVST_READY;
input						AVST_VALID;
input						AVST_SOP;
input	[DATA_WIDTH-1:0]	AVST_DATA;
input						AVST_EOP;
input	[EMPTY_WIDTH-1:0]	AVST_EMPTY;

output						CRC_VALID;
output						CRC_BAD;

wire						crc_chk_valid;
wire	[CRC_WIDTH-1:0]		crc_chk_checksum;	
wire						crc_valid_sig;
wire						crc_bad_sig;

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
	                    	
	.CRC_VALID				(crc_chk_valid),
	.CRC_CHECKSUM			(crc_chk_checksum)
);

crc_comparator #(CRC_WIDTH) crc_comparator_u0 (
	.CLK					(CLK),
	.RESET_N				(RESET_N),
	
	.PKT_CRC_VALID_IN		(crc_chk_valid),
	.PKT_CRC_CHECKSUM_IN	(CRC32_ETHERNET_CHK_VALUE),
	
	.CRC_GEN_VALID_IN		(crc_chk_valid),
	.CRC_GEN_CHECKSUM_IN	(crc_chk_checksum),
	
	.CRC_CHK_VALID_OUT		(crc_valid_sig),
	.CRC_CHK_BAD_STATUS_OUT	(crc_bad_sig)
);

//Here CRC Width is define as 1 due to CRC bad is only 1 bit
crc_checksum_aligner #(1, CRC_OUT_LATENCY) crc_aligner_u0 (
	.CLK					(CLK),
	.RESET_N				(RESET_N),
	
	.CRC_CHECKSUM_LATCH_IN	(crc_valid_sig),
	.CRC_CHECKSUM_IN		(crc_bad_sig),
	
	.CRC_VALID_OUT			(CRC_VALID),
	.CRC_CHECKSUM_OUT		(CRC_BAD)
);

endmodule
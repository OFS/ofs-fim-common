// Copyright (C) 2001-2018 Intel Corporation
// SPDX-License-Identifier: MIT

// CRC32 For Ethernet
//	Re-package the CRC32
//
// Revision:
// 05-09-2012 - intial version
// 06-09-2012 - Bug Fix: 
//					1. Add pkt_transfer_status signal to indicate when pkt is transfering
//					2. Fix the unwanted CRC_Valid assertion when a backpressure occured on Avalon ST interface
//					3. Naming change from CRC_ENA_IN to PKT_TRANSFER_STATUS_IN in crc_checksum_aligner.v to avoid confusion
// 13-09-2012 - Enhancement:
//					1. Improve the data input and crc output endian control on the fly
//					2. crc_ethernet is fix to small endian, Avalon ST is big endian, it need to be convert to small endian before passing into CRC_Ethernet.v
// 14-09-2012 - Enhancement:
//					1. Remove crc_checksum_aligner.v to improve latency
//			  - Fix:
//					1. crc32 module name conflict with 10G MAC CRC library name. Change to crc32_calculator.v


module crc32_calculator (
	CLK,
	RESET_N,
	
	DATA_INPUT_ENDIAN_SEL,
	CRC_OUTPUT_ENDIAN_SEL,
	
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
parameter   CRC_PIPELINE_MODE = 0;	//Default set to 0, set to 1 for pipeline mode (init and data input (EOP Only) at the same cycle)

input						CLK;
input						RESET_N;

input						DATA_INPUT_ENDIAN_SEL;		//0 - No Conversion, pass through, 1 - Endian Convertion 
input						CRC_OUTPUT_ENDIAN_SEL;		//0 - No Conversion, pass through, 1 - Endian Conversion

output						AVST_READY;
input						AVST_VALID;
input						AVST_SOP;
input	[DATA_WIDTH-1:0]	AVST_DATA;
input						AVST_EOP;
input	[EMPTY_WIDTH-1:0]	AVST_EMPTY;

output						CRC_VALID;
output	[CRC_WIDTH-1:0]		CRC_CHECKSUM;

wire						crc_enable;
wire						crc_init;
wire	[DATA_WIDTH-1:0]	crc_data;
wire	[EMPTY_WIDTH-1:0]	crc_data_size;
wire	[CRC_WIDTH-1:0]		crc_checksum_out;

wire	[DATA_WIDTH-1:0]	crc_data_small_endian;
wire	[CRC_WIDTH-1:0]		crc_checksum_out_big_endian;

wire						crc_out_latch;

avalon_st_to_crc_if_bridge #(DATA_WIDTH, EMPTY_WIDTH)	crc_bridge_u0 (
	.CLK					(CLK),
	.RESET_N				(RESET_N),
	
	.AVST_READY				(AVST_READY),
	.AVST_VALID				(AVST_VALID),
	.AVST_SOP				(AVST_SOP),
	.AVST_DATA				(AVST_DATA),
	.AVST_EOP				(AVST_EOP),
	.AVST_EMPTY				(AVST_EMPTY),
	
	.CRC_ENA				(crc_enable),
	.CRC_INIT				(crc_init),
	.CRC_DATA				(crc_data),
	.CRC_DATA_SIZE			(crc_data_size),
	
	.CRC_OUT_LATCH			(crc_out_latch)
);

byte_endian_converter #(DATA_WIDTH) byte_endian_converter_u0 (
	.ENABLE					(DATA_INPUT_ENDIAN_SEL),
	.DATA_IN				(crc_data),
	.DATA_OUT				(crc_data_small_endian)
);

crc_ethernet #(DATA_WIDTH, EMPTY_WIDTH, CRC_WIDTH, REVERSE_DATA, CRC_PIPELINE_MODE) crc32_u0 (
	.aclr					(!RESET_N),
	.clk					(CLK),
	.ena					(crc_enable),
	.init					(crc_init),
	.dat_size				(crc_data_size),
	.crc_out				(crc_checksum_out),
	.dat					(crc_data_small_endian)
);

byte_endian_converter #(CRC_WIDTH) byte_endian_converter_u1 (
	.ENABLE					(CRC_OUTPUT_ENDIAN_SEL),
	.DATA_IN				(crc_checksum_out),
	.DATA_OUT				(crc_checksum_out_big_endian)
);


assign	CRC_VALID = crc_out_latch;
assign	CRC_CHECKSUM = crc_checksum_out_big_endian; 	

endmodule

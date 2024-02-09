// Copyright (C) 2001-2018 Intel Corporation
// SPDX-License-Identifier: MIT

// CRC Comparator
//	Compare the two CRC input value
//	- CRC from Ethernet Packet and CRC Generator
//
// Revision:
// 05-09-2012 - intial version

module crc_comparator (
	CLK,
	RESET_N,
	
	PKT_CRC_VALID_IN,
	PKT_CRC_CHECKSUM_IN,
	
	CRC_GEN_VALID_IN,
	CRC_GEN_CHECKSUM_IN,
	
	CRC_CHK_VALID_OUT,
	CRC_CHK_BAD_STATUS_OUT
);

parameter	CRC_WIDTH = 32;			//CRC32

input						CLK;
input						RESET_N;
	
input						PKT_CRC_VALID_IN;
input	[CRC_WIDTH-1:0]		PKT_CRC_CHECKSUM_IN;
	
input						CRC_GEN_VALID_IN;
input	[CRC_WIDTH-1:0]		CRC_GEN_CHECKSUM_IN;
	
output						CRC_CHK_VALID_OUT;
output						CRC_CHK_BAD_STATUS_OUT;

reg		pkt_crc_ready;
reg		crc_gen_ready;
reg		[CRC_WIDTH-1:0]		pkt_crc_checksum;
reg		[CRC_WIDTH-1:0]		crc_gen_checksum;
reg							CRC_CHK_VALID_OUT;
reg							CRC_CHK_BAD_STATUS_OUT;

always @(posedge CLK or negedge RESET_N)
	if (!RESET_N)
		pkt_crc_ready <= 1'b0;
	else if (PKT_CRC_VALID_IN)
		pkt_crc_ready <= 1'b1;
	else if (pkt_crc_ready && crc_gen_ready)
		pkt_crc_ready <= 1'b0;
		
always @(posedge CLK or negedge RESET_N)
	if (!RESET_N)
		crc_gen_ready <= 1'b0;
	else if (CRC_GEN_VALID_IN)
		crc_gen_ready <= 1'b1;
	else if (pkt_crc_ready && crc_gen_ready)
		crc_gen_ready <= 1'b0;		
	
always @(posedge CLK or negedge RESET_N)
	if (!RESET_N)
		pkt_crc_checksum <= {CRC_WIDTH{1'b0}};
	else if (PKT_CRC_VALID_IN)
		pkt_crc_checksum <= PKT_CRC_CHECKSUM_IN;
		
always @(posedge CLK or negedge RESET_N)
	if (!RESET_N)
		crc_gen_checksum <= {CRC_WIDTH{1'b0}};
	else if (CRC_GEN_VALID_IN)
		crc_gen_checksum <= CRC_GEN_CHECKSUM_IN;		 				

always @(posedge CLK or negedge RESET_N)
	if (!RESET_N)
		CRC_CHK_VALID_OUT <= 1'b0;
	else if (pkt_crc_ready && crc_gen_ready)
		CRC_CHK_VALID_OUT <= 1'b1;
	else
		CRC_CHK_VALID_OUT <= 1'b0;	
	   		
always @(posedge CLK or negedge RESET_N)
	if (!RESET_N) begin
		CRC_CHK_BAD_STATUS_OUT <= 1'b0;
	end
	else if (pkt_crc_ready && crc_gen_ready) begin
		if (pkt_crc_checksum !== crc_gen_checksum)
			CRC_CHK_BAD_STATUS_OUT <= 1'b1;
		else
			CRC_CHK_BAD_STATUS_OUT <= 1'b0;   
	end
	else begin
		CRC_CHK_BAD_STATUS_OUT <= 1'b0;
	end

endmodule

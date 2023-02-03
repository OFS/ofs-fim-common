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


// CRC Checksum Aligner
//	Main to match the same latancy performance with CRC Compiler (Generator only)
//
// Revision:
// 05-09-2012 - intial version
// 06-09-2012 - CRC_ENA_IN naming change to PKT_TRANSFER_STATUS_IN to avoid confusion with the CRC_ENA output from CRC_ethernet.v
//					Main reason is that PKT_TRANSFER_STATUS_IN cannot have deassertion during a packet transfer but CRC_ENA from CRC_ethernet.v
//					allow deassertion during pkt transfer. 
// 13-09-2012 - PKT_TRANSFER_STATUS_IN input drop due to the CRC_Ethernet.v now able to perform init and crc calculation (EOP) at the same clock cycle
//			  - PKT_TRANSFER_STATUS_IN change to CRC_CHECKSUM_LATCH_IN which is only valid for 1 clock cycle to latch the CRC output  					
// 14-09-2012 - Enhancement:
//					1. Re-architecture the crc_checksum_aligner where variable latency can define through parameter

module	crc_checksum_aligner (
	CLK,
	RESET_N,
	
	CRC_CHECKSUM_LATCH_IN,
	CRC_CHECKSUM_IN,
	
	CRC_VALID_OUT,
	CRC_CHECKSUM_OUT
);

parameter	CRC_WIDTH = 32;
parameter	LATENCY = 0;

input					CLK;
input					RESET_N;
	
input					CRC_CHECKSUM_LATCH_IN;
input	[CRC_WIDTH-1:0]	CRC_CHECKSUM_IN;
	
output					CRC_VALID_OUT;
output	[CRC_WIDTH-1:0]	CRC_CHECKSUM_OUT;

generate
	if (LATENCY == 0) begin
		assign CRC_VALID_OUT = CRC_CHECKSUM_LATCH_IN;  	
		assign CRC_CHECKSUM_OUT = CRC_CHECKSUM_IN; 	
				
	end
	else begin
		reg						crc_valid_delay	[0:LATENCY-1];
		reg		[CRC_WIDTH-1:0]	crc_checksum_delay [0:LATENCY-1];
		
		integer i;
    	always @(posedge CLK or negedge RESET_N)
    		if (!RESET_N) begin
    			for (i=0; i<LATENCY; i=i+1) begin
    				crc_valid_delay[i] <= 1'b0;
    				crc_checksum_delay[i] <= {CRC_WIDTH{1'b0}};
    			end
    		end
    		else begin
    			crc_valid_delay[0] <= CRC_CHECKSUM_LATCH_IN;
    			crc_checksum_delay[0] <= CRC_CHECKSUM_IN;
    				
    			for (i=0; i<LATENCY-1; i=i+1) begin
    				crc_valid_delay[i+1] <= crc_valid_delay[i];
    				crc_checksum_delay[i+1] <= crc_checksum_delay[i]; 
    			end
    		end	
    		
		assign CRC_VALID_OUT = crc_valid_delay[LATENCY-1]; 	
    	assign CRC_CHECKSUM_OUT = crc_checksum_delay[LATENCY-1]; 			
	end
endgenerate	

endmodule
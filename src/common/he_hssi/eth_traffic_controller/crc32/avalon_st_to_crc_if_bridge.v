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


// Avalon ST to CRC Interface Bridge Converter
//
// Revision:
// 05-09-2012 - Initnal version
// 06-09-2012 - Bug Fix: 
//					1. Add pkt_transfer_status signal to indicate when pkt is transfering
//					2. Fix the CRC_ENA deassertion to pause CRC calculation when backpressure occure on Avalon ST interface/ FSM jump into halt stage
// 13-09-2012 - Enhancement:
//					1. drop previous FSM architecture due the CRC need an extra cycle for init and cause gap is needed between 2 pkts
//					2. enhance the FSM to perfrom init after reset and when eop condition is detected, this required the CRC_Ethernet.v to be enhance as well
//					3. pkt_transfer_status output remove and replace with CRC_OUT_LATCH which only have 1 clock cycle pulse to latch the CRC output indication
// 14-09-2012 - Enhancement:
//					1. Optimize the depandency on the FSM. CRC Interface now can directly use AVST control, FSM only control the initial init and AVST READY signal

module avalon_st_to_crc_if_bridge (
	CLK,
	RESET_N,
	
	AVST_READY,
	AVST_VALID,
	AVST_SOP,
	AVST_DATA,
	AVST_EOP,
	AVST_EMPTY,
	
	CRC_ENA,
	CRC_INIT,
	CRC_DATA,
	CRC_DATA_SIZE,
	
	CRC_OUT_LATCH
);

parameter	DATA_WIDTH = 32;		//8,32,64,16(optional)
parameter	EMPTY_WIDTH = 2;		//x,2 ,3 ,1  	 

//FSM Parameter
localparam	rst  = 2'd0;
localparam	init = 2'd1;			//State init - Init the CRC32 Algorithm with 32'hffffffff
localparam	ready = 2'd2;			//Ready to transfer state

input						CLK;
input						RESET_N;
	
//Avalon ST Interface
output						AVST_READY;
input						AVST_VALID;
input						AVST_SOP;
input	[DATA_WIDTH-1:0]	AVST_DATA;
input						AVST_EOP;
input	[EMPTY_WIDTH-1:0]	AVST_EMPTY;


//CRC Interface
output						CRC_ENA;
output						CRC_INIT;
output	[DATA_WIDTH-1:0]	CRC_DATA;
output	[EMPTY_WIDTH-1:0]	CRC_DATA_SIZE;

//CRC Latch indication
output						CRC_OUT_LATCH;	//0 - CRC not valid, 1 - CRC is valid

reg							CRC_ENA;
reg							CRC_INIT;
reg		[DATA_WIDTH-1:0]	CRC_DATA;
reg		[EMPTY_WIDTH-1:0]	CRC_DATA_SIZE;	

reg		[2:0]	state, next;
reg				CRC_OUT_LATCH;
reg				AVST_READY;

always @(posedge CLK or negedge RESET_N)
	if (!RESET_N)
		AVST_READY <= 1'b0;
	else if (next == ready)
		AVST_READY <= 1'b1;
	else 
		AVST_READY <= 1'b0;

//FSM Init Control	
always @(posedge CLK or negedge RESET_N)
	if (!RESET_N)
		state <= rst;
	else
		state <= next;
		
always @*
	case (state)
		rst	 :
			next = init;
			
		init:
			next = ready;
			 
		ready :
			next = ready;
				
		default:
			next = rst;
			
	endcase					
	
//CRC32 Interface 
always @(posedge CLK or negedge RESET_N)
	if (!RESET_N)
		CRC_ENA <= 1'b0;
	else if (next == init)
		CRC_ENA <= 1'b1;
	else
		CRC_ENA <= AVST_VALID;
		
always @(posedge CLK or negedge RESET_N)
	if (!RESET_N)		
		CRC_INIT <= 1'b0;
	else if ((next == init) || (AVST_VALID && AVST_EOP))
		CRC_INIT <= 1'b1;
	else
		CRC_INIT <= 1'b0;
		
always @(posedge CLK or negedge RESET_N)
	if (!RESET_N)		
		CRC_DATA <= {DATA_WIDTH{1'b0}};
	else
		CRC_DATA <= AVST_DATA;  	
		
generate
	if (DATA_WIDTH == 8) begin
		
		always @(*)
			CRC_DATA_SIZE = {EMPTY_WIDTH{1'b0}}; 
			
	end		
	else if (DATA_WIDTH == 16) begin
		
		always @(posedge CLK or negedge RESET_N)
			if (!RESET_N)		
				CRC_DATA_SIZE <= {EMPTY_WIDTH{1'b0}};
			else
				case (AVST_EMPTY)
					1'b0:
						CRC_DATA_SIZE <= 1'b1;
					1'b1:
						CRC_DATA_SIZE <= 1'b0;
					default:
						CRC_DATA_SIZE <= 1'b1;
				endcase
				
	end
	else if (DATA_WIDTH == 32) begin
	
		always @(posedge CLK or negedge RESET_N)
			if (!RESET_N)		
				CRC_DATA_SIZE <= {EMPTY_WIDTH{1'b0}};
			else
				case (AVST_EMPTY)
					2'b00:
						CRC_DATA_SIZE <= 2'b11;
					2'b01:
						CRC_DATA_SIZE <= 2'b10;
					2'b10:
						CRC_DATA_SIZE <= 2'b01;
					2'b11:
						CRC_DATA_SIZE <= 2'b00;	
					default:
						CRC_DATA_SIZE <= 2'b11;
				endcase
				
	end
	else if (DATA_WIDTH == 64) begin
		
		always @(posedge CLK or negedge RESET_N)
			if (!RESET_N)		
				CRC_DATA_SIZE <= {EMPTY_WIDTH{1'b0}};
			else
				case (AVST_EMPTY)
					3'b000:
						CRC_DATA_SIZE <= 3'b111;
					3'b001:
						CRC_DATA_SIZE <= 3'b110;
					3'b010:
						CRC_DATA_SIZE <= 3'b101;
					3'b011:
						CRC_DATA_SIZE <= 3'b100;	
					3'b100:
						CRC_DATA_SIZE <= 3'b011;
					3'b101:
						CRC_DATA_SIZE <= 3'b010;
					3'b110:
						CRC_DATA_SIZE <= 3'b001;
					3'b111:
						CRC_DATA_SIZE <= 3'b000;		
					default:
						CRC_DATA_SIZE <= 3'b111;
				endcase
				
	end
endgenerate

always @(posedge CLK or negedge RESET_N)
	if (!RESET_N)
		CRC_OUT_LATCH <= 1'b0;
	else if ((state !== init) && CRC_ENA && CRC_INIT)
		CRC_OUT_LATCH <= 1'b1;
	else
		CRC_OUT_LATCH <= 1'b0;
		
endmodule
// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on


module ed_axist_to_avst_tx_mac_seg_if #(
    parameter SIM_EMULATE   	 = 1,
    parameter AVST_MODE			 = "MAC_SEGMENTED",
    parameter AVST_DW      	 = 64,
	 parameter NUM_SEG          = (AVST_MODE == "SOP_ALIGNED")?1:(AVST_DW/64),  //8 bytes per segment
    parameter EMPTY_BITS    	 = 3,
    parameter AVST_ERR      	 = 2*NUM_SEG, 
    parameter FCS_ERR  	 		 = 1*NUM_SEG,
    parameter MAC_STS  	 		 = 3*NUM_SEG,
    parameter AVST_USER  		 = AVST_ERR +90 +328, 
    parameter AXIST_MODE		 = "MULTI_PACKET", 
    parameter AXI_DW      	    = 64,
    parameter NO_OF_BYTES  	 = 8, 
    parameter TUSER  		 	 = AVST_ERR +90 +328, 
    // parameter AXI_ERR      	 = 2*NUM_SEG,
    parameter READY_LATENCY    = 16,  
	 parameter PKT_SEG_PARITY_EN = 0,
	 parameter ENABLE_ECC  		 = 1,
	 parameter USE_M20K			 = "ON",
	 parameter PREAMBLE_PASS_TH_EN			 = 0
) (
    input                           			i_tx_clk, 
    input                           			i_tx_reset_n,
																							
    //AXI Stream Tx, User side interface			   
	 output reg											o_axist_tx_tready,
    input                      					i_axist_tx_tvalid,
    input  [AXI_DW-1:0]      						i_axist_tx_tdata,
    input  						    					i_axist_tx_tlast,
    input  [NO_OF_BYTES-1:0]			    		i_axist_tx_tkeep,
    input  [NUM_SEG-1:0]    		    			i_axist_tx_tlast_segment,
    input  [NUM_SEG*8-1:0]  			i_axist_tx_tkeep_segment,
    input  [TUSER-1:0]  							i_axist_tx_tuser,
    input  [64-1:0]    		    			i_axist_tx_preamble,
    input  [NUM_SEG-1:0]    		    			i_axist_tx_pkt_seg_parity,
	
    //Avalon Stream Tx, MAC side interface	
	 input 												i_avst_tx_ready,
    output   [AVST_DW-1:0]           		o_avst_tx_data,
    output                           		o_avst_tx_valid,
    output                           		o_avst_tx_valid_pkt_client, //only used in ED for PKT client IF
    output   [NUM_SEG-1:0]         			o_avst_tx_inframe,
    output   [NUM_SEG*EMPTY_BITS-1:0]  	o_avst_tx_eop_empty,
    output   				          			o_avst_tx_startofpacket,
    output   				          			o_avst_tx_endofpacket,
    output   [AVST_USER-1:0]      			o_avst_tx_user,
    output   [64-1:0]      			o_avst_tx_preamble,
    output                                o_axist_tx_parity_error, //To CSR status reg
    output   [2-1:0]      					   o_fifo_eccstatus
 
);
 
localparam PRMBLE_WIDTH		 = (PREAMBLE_PASS_TH_EN) ? 64 : 1;
localparam EN_ECC = (ENABLE_ECC) ? "TRUE" : "FALSE" ;
// localparam FIFO_WIDTH = (AVST_MODE == "MAC_SEGMENTED")? (1+(NUM_SEG*EMPTY_BITS)+NUM_SEG+AVST_DW+AVST_USER) : (PRMBLE_WIDTH+3+EMPTY_BITS+AVST_DW+AVST_USER);
localparam FIFO_WIDTH = (AVST_MODE == "MAC_SEGMENTED")? (1+(NUM_SEG*EMPTY_BITS)+NUM_SEG+AVST_DW+AVST_USER) : 
						((PREAMBLE_PASS_TH_EN) ? (PRMBLE_WIDTH+3+EMPTY_BITS+AVST_DW+AVST_USER) : (3+EMPTY_BITS+AVST_DW+AVST_USER));
localparam FIFO_DEPTH = 6;  //minium is 6 
localparam DC_FIFO_LATENCY = 2 + 6 + 6; // 2 cycles for wen delay, 6 cycles for empty delay, 6 cycles of ren delay
localparam FIFO_LEVEL_CHECK = (2**FIFO_DEPTH) - READY_LATENCY - DC_FIFO_LATENCY - 'd4; //1+3 cycles for ready to wen on AXI side
 
//***********************************************************
//***********************************************************
 
reg	[NUM_SEG*8-1:0] 	axist_tx_tkeep_segment_d1;
reg	[NUM_SEG-1:0] 					axist_tx_tlast_segment_d1;
reg										axist_tx_tlast_d1;
	
reg  [AVST_DW-1:0]           		avst_tx_data_d1;
reg  [AVST_DW-1:0]           		avst_tx_data_d2;
reg  [AVST_DW-1:0]           		avst_tx_swiped_data_d2;
reg                          		avst_tx_valid_d1;
reg                          		avst_tx_valid_d2;
reg  [NUM_SEG-1:0]         		avst_tx_inframe_d2;
	
reg  [NUM_SEG*EMPTY_BITS-1:0] 	keep2empty_d1;
 
 
wire [3:0] keep2empty_sop_align_d1 [NO_OF_BYTES/8-1:0]; // = '{default:'0};
 
logic  [NUM_SEG*EMPTY_BITS-1:0] avst_tx_eop_empty_d1;
reg  [NUM_SEG*EMPTY_BITS-1:0]   avst_tx_eop_empty_d2;
 
reg  [NUM_SEG*2-1:0]        avst_tx_user_client;
reg  [NUM_SEG*2-1:0]        avst_tx_user_client_d1;
reg  [TUSER-1:0]         	avst_tx_user_d1;
reg  [TUSER-1:0]         	avst_tx_user_d2;
reg  [63:0]					avst_tx_preamble_d1;
reg  [63:0]					avst_tx_preamble_d2;
 
reg  [NUM_SEG-1:0]				avst_sop_latch;
reg  [NUM_SEG-1:0]				avst_eop_d1;
reg  [NUM_SEG-1:0]				avst_eop_d2;
reg  [NUM_SEG-1:0]				avst_eop_d3;
reg  [NUM_SEG-1:0]				avst_sop_d1;
reg  [NUM_SEG-1:0]				avst_sop_d2;
reg  [NUM_SEG-1:0]				avst_sop_d3;
 
wire	[FIFO_WIDTH-1:0]		fifo_data_in; 
wire	[FIFO_WIDTH-1:0]		fifo_data_out; 
wire	[FIFO_DEPTH-1:0]		avst_tx_fifo_lvl;
wire	[2-1:0]					ecc_status;
wire                      av_st_tx_fifo_empty;
reg								fifo_wrreq_d1;
reg								fifo_wrreq_d2;
wire								axist_tx_tready_delayed;
reg								axist_tx_tready_delayed_d1;
 
reg               axist_tx_parity_error;
logic  [NUM_SEG-1:0]  [63:0]      	axi_st_tx_seg_data;
logic  [AXI_DW-1:0]  			   	axi_st_tx_data;
logic  [NUM_SEG-1:0]  		     	tx_parity_detect;
logic  [NUM_SEG-1:0]  		     	tx_parity_error;
 
 
generate 
if (PKT_SEG_PARITY_EN) 
begin:TX_PARITY_CALC
genvar tx_sp;
	assign avst_tx_user_client = i_axist_tx_tuser[TUSER-1:TUSER-2*NUM_SEG];
	if (AVST_MODE == "MAC_SEGMENTED") begin
		for (tx_sp=0; tx_sp<NUM_SEG; tx_sp=tx_sp+1)begin :TX_SEG_DATA			
			always_comb begin
				axi_st_tx_seg_data[tx_sp] = i_axist_tx_tdata[64*(tx_sp+1)-1:64*tx_sp];
				tx_parity_detect[tx_sp] = ^(axi_st_tx_seg_data[tx_sp]);
			end
			assign tx_parity_error[tx_sp]	= i_axist_tx_tvalid && axist_tx_tready_delayed && (tx_parity_detect[tx_sp] == i_axist_tx_pkt_seg_parity[tx_sp]);
			
			always @(posedge i_tx_clk or negedge i_tx_reset_n) begin
				if (~i_tx_reset_n)
					//avst_tx_user_client_d1[2*(tx_sp+1)-1:2*tx_sp] <= 2'b0;
					avst_tx_user_client_d1[2*(tx_sp+1)-1:2*tx_sp] <= {2*NUM_SEG{1'b0}};
				else begin
					avst_tx_user_client_d1[(2*tx_sp)+1] <= avst_tx_user_client[(2*tx_sp)+1];
					avst_tx_user_client_d1[2*tx_sp] <= avst_tx_user_client[2*tx_sp] | tx_parity_error[tx_sp];
				end
			end			
		end	
		assign axi_st_tx_data = {AXI_DW{1'b0}};
	end
	else begin
		always_comb begin
			axi_st_tx_data = i_axist_tx_tdata;		
			tx_parity_detect = ^(axi_st_tx_data);
		end
		assign tx_parity_error	= i_axist_tx_tvalid && axist_tx_tready_delayed && (tx_parity_detect == i_axist_tx_pkt_seg_parity);
		always @(posedge i_tx_clk or negedge i_tx_reset_n) begin
			if (~i_tx_reset_n)
				//avst_tx_user_client_d1[2*(tx_sp+1)-1:2*tx_sp] <= 2'b0;
				avst_tx_user_client_d1[1:0] <= 2'b0;
			else begin
				avst_tx_user_client_d1[1] <= avst_tx_user_client[1];
				avst_tx_user_client_d1[0] <= avst_tx_user_client[0] | tx_parity_error;
			end
		end		
		assign axi_st_tx_seg_data = 64'b0;
	end
end
else 
begin : TX_NO_PARITY
	always @(posedge i_tx_clk or negedge i_tx_reset_n) begin
		if (~i_tx_reset_n)
			avst_tx_user_client_d1 <= {2*NUM_SEG{1'b0}};
		else 
			avst_tx_user_client_d1 <= i_axist_tx_tuser[TUSER-1:TUSER-2*NUM_SEG];
	end
	assign tx_parity_error	= {NUM_SEG{1'b0}}; 
end
endgenerate		
 
always @(posedge i_tx_clk or negedge i_tx_reset_n)
begin
	if (~i_tx_reset_n) begin
		avst_tx_valid_d1          <= 1'b0;
		avst_tx_valid_d2          <= 1'b0;
		avst_tx_data_d1           <= {AVST_DW{1'b0}};
		avst_tx_data_d2           <= {AVST_DW{1'b0}};
		avst_tx_user_d1           <= {TUSER{1'b0}};
		avst_tx_user_d2           <= {TUSER{1'b0}};
		axist_tx_tkeep_segment_d1 <= {(NUM_SEG*8){1'b0}};		
		axist_tx_tlast_segment_d1 <= {NUM_SEG{1'b0}};		
		axist_tx_tlast_d1         <= 1'b0;	
		axist_tx_parity_error     <= 1'b0;
		avst_tx_preamble_d1		  <= 64'b0;
		avst_tx_preamble_d2		  <= 64'b0;
	end
	else begin
		avst_tx_valid_d1          <= i_axist_tx_tvalid;
		avst_tx_data_d1           <= i_axist_tx_tdata;
		avst_tx_user_d1           <= i_axist_tx_tuser;
		avst_tx_preamble_d1       <= i_axist_tx_preamble;
		avst_tx_valid_d2          <= avst_tx_valid_d1;
		avst_tx_data_d2           <= avst_tx_data_d1;
		avst_tx_user_d2           <= {avst_tx_user_client_d1,avst_tx_user_d1[TUSER-2*NUM_SEG-1:0]};
		avst_tx_preamble_d2       <= avst_tx_preamble_d1;
		axist_tx_tkeep_segment_d1 <= i_axist_tx_tkeep_segment;	
		axist_tx_tlast_segment_d1 <= i_axist_tx_tlast_segment;	
		axist_tx_tlast_d1         <= i_axist_tx_tlast;	
    axist_tx_parity_error     <= |tx_parity_error;
	end
end
assign o_axist_tx_parity_error = axist_tx_parity_error;
 
always @(posedge i_tx_clk or negedge i_tx_reset_n)
begin
	if(~i_tx_reset_n) begin
		o_axist_tx_tready <= 1'b0;
	end
	else if(i_avst_tx_ready) begin
		o_axist_tx_tready <= 1'b1;
	end
	else if(avst_tx_fifo_lvl >= FIFO_LEVEL_CHECK) //Should be based on ready latency and based on tx bridge delay and fifo delays
	//else if(avst_tx_fifo_lvl >= 'd10) //Should be based on ready latency and based on tx bridge delay and fifo delays
		o_axist_tx_tready <= 1'b0;
end
 
 
 
hssi_ss_delay_reg #(
    .CYCLES (READY_LATENCY), 
    .WIDTH  (1)
) i_axi_ready_latency_delay_reg (
    .clk    (i_tx_clk),
    .din    (o_axist_tx_tready),
    .dout   (axist_tx_tready_delayed)
    );
 
generate 
if ((AXIST_MODE == "MULTI_PACKET") || (AVST_MODE == "MAC_SEGMENTED"))
begin:BRIDGE_MP2MS
genvar i;
	for (i=0; i<NUM_SEG; i=i+1) 
	begin : CONVERSION_MP2MS
		always @(posedge i_tx_clk or negedge i_tx_reset_n) 
		begin
			if (~i_tx_reset_n) begin
				avst_eop_d1[i] <= 1'b0;
				avst_sop_latch[i] <= 1'b1;
			end
			else if (axist_tx_tready_delayed && i_axist_tx_tvalid && i_axist_tx_tlast_segment[i]) begin
				avst_eop_d1[i] <= 1'b1 ;
				avst_sop_latch[i] <= 1'b1 ;
			end
			else if (axist_tx_tready_delayed && i_axist_tx_tvalid) begin
				avst_eop_d1[i] <= 1'b0 ;
				avst_sop_latch[i] <= 1'b0 ;
			end			
			else begin
				avst_eop_d1[i] <= 1'b0;
				avst_sop_latch[i] <= avst_sop_latch[i];
			end			
		end
				
		always @(posedge i_tx_clk or negedge i_tx_reset_n) 
		begin
			if (~i_tx_reset_n) 
				avst_sop_d1[i] <= 1'b0;
			else if (axist_tx_tready_delayed && i_axist_tx_tvalid && i_axist_tx_tkeep_segment[8*(i+1)-1:8*i] == 8'hff) begin
				// if ((i==0) && (avst_sop_latch[NUM_SEG-1]) && (axist_tx_tready_delayed_d1 && (axist_tx_tlast_segment_d1[NUM_SEG-1] || (axist_tx_tkeep_segment_d1[(8*NUM_SEG)-1:8*(NUM_SEG-1)] == 8'b0))))
				if ((i==0) && ((avst_sop_latch[NUM_SEG-1] && axist_tx_tready_delayed) || (axist_tx_tready_delayed_d1 && avst_tx_valid_d1 && (axist_tx_tlast_segment_d1[NUM_SEG-1] || (axist_tx_tkeep_segment_d1[(8*NUM_SEG)-1:8*(NUM_SEG-1)] == 8'b0)))))	
					avst_sop_d1[i] <= 1'b1;
				else if ((i!=0) && (i_axist_tx_tlast_segment[i-1] || (i_axist_tx_tkeep_segment[8*i-1:8*(i-1)] == 8'b0)))
					avst_sop_d1[i] <= 1'b1;
				else 
					avst_sop_d1[i] <= 1'b0;	
			end
			else 
				avst_sop_d1[i] <= 1'b0;		
		end
		
		always @(posedge i_tx_clk or negedge i_tx_reset_n) 
		begin
			if (~i_tx_reset_n)
				avst_tx_inframe_d2[i] <= 1'b0;
			else if (avst_sop_d1[i])
				avst_tx_inframe_d2[i] <= 1'b1;
			else if (avst_eop_d1[i])
				avst_tx_inframe_d2[i] <= 1'b0;
			else if (axist_tx_tready_delayed_d1 && avst_tx_valid_d1 && (|axist_tx_tkeep_segment_d1[8*(i+1)-1:8*i]))
				avst_tx_inframe_d2[i] <= 1'b1;
			else 
				avst_tx_inframe_d2[i] <= 1'b0;
		end
		
		keep2empty #(
			.EMPTY_BITS  (3),
		    .NO_OF_BYTES (8)
			)keep2empty_inst(
        .clk(i_tx_clk),
        //.rst_n(i_tx_reset_n),
				//.keep_bits_in(i_axist_tx_tkeep_segment[(i+1)*NO_OF_BYTES-1:NO_OF_BYTES*i]), 
				.keep_bits_in(i_axist_tx_tkeep_segment[(i+1)*8-1:8*i]), 
				.empty_bits_out_d1(keep2empty_d1[(i+1)*EMPTY_BITS-1:EMPTY_BITS*i])			
			);
 
		assign 	avst_tx_eop_empty_d1[(i+1)*EMPTY_BITS-1:EMPTY_BITS*i] = keep2empty_d1[(i+1)*EMPTY_BITS-1:EMPTY_BITS*i];
 
		
		always @(posedge i_tx_clk or negedge i_tx_reset_n) 
		begin
			if (~i_tx_reset_n) 
				avst_tx_eop_empty_d2[(i+1)*EMPTY_BITS-1:EMPTY_BITS*i] <= {EMPTY_BITS{1'b0}};
			else if (avst_tx_valid_d1 && axist_tx_tlast_segment_d1[i]) 
				avst_tx_eop_empty_d2[(i+1)*EMPTY_BITS-1:EMPTY_BITS*i] <= avst_tx_eop_empty_d1[(i+1)*EMPTY_BITS-1:EMPTY_BITS*i];
			else 
				avst_tx_eop_empty_d2[(i+1)*EMPTY_BITS-1:EMPTY_BITS*i] <= {EMPTY_BITS{1'b0}};
		end 
		
	end	
	
	assign fifo_data_in[AVST_USER-1:0]												= avst_tx_user_d2;
	assign fifo_data_in[AVST_DW+AVST_USER-1:AVST_USER]							= avst_tx_data_d2;
	assign fifo_data_in[NUM_SEG+AVST_DW+AVST_USER-1:AVST_DW+AVST_USER]	= avst_tx_inframe_d2;               
	assign fifo_data_in[(NUM_SEG*EMPTY_BITS)+NUM_SEG+AVST_DW+AVST_USER-1:NUM_SEG+AVST_DW+AVST_USER]	= avst_tx_eop_empty_d2;
	assign fifo_data_in[FIFO_WIDTH-1]												= avst_tx_valid_d2; //not used in IP case, used in ED for valid	
 
	assign o_avst_tx_user      	 = fifo_data_out[AVST_USER-1:0];									
	assign o_avst_tx_data      	 = fifo_data_out[AVST_DW+AVST_USER-1:AVST_USER];					
	assign o_avst_tx_inframe   	 = fifo_data_out[NUM_SEG+AVST_DW+AVST_USER-1:AVST_DW+AVST_USER];	
	assign o_avst_tx_eop_empty 	 = fifo_data_out[(NUM_SEG*EMPTY_BITS)+NUM_SEG+AVST_DW+AVST_USER-1:NUM_SEG+AVST_DW+AVST_USER];
	assign o_avst_tx_valid 	       = i_avst_tx_ready;//fifo_data_out[FIFO_WIDTH-1];
	assign o_avst_tx_valid_pkt_client   = fifo_data_out[FIFO_WIDTH-1] && i_avst_tx_ready && ~av_st_tx_fifo_empty;
  assign o_avst_tx_startofpacket = 1'b0;
	assign o_avst_tx_endofpacket 	 = 1'b0;
	assign o_avst_tx_preamble 	 = 64'b0;
	
end //end of BRIDGE_MP2MS
else begin: BRIDGE_SP2SA
genvar j;
genvar k;
 
	for(k=0; k<NO_OF_BYTES;k=k+1)
	begin : BYTE_SWAP
		always @(posedge i_tx_clk)begin
			avst_tx_swiped_data_d2[((k+1)*8)-1 : (k*8)] <= avst_tx_data_d1[(AVST_DW-1-(k*8)) : (AVST_DW-8-(k*8))];
		end
	end
	for (j=0; j<NO_OF_BYTES/8; j=j+1) 
	begin: keep_empty_conversion 
		keep2empty #(
			.EMPTY_BITS  (4),
		    .NO_OF_BYTES (8)
			)keep2empty_inst(
				.clk	(i_tx_clk), 
			  //  .rst_n	(i_tx_reset_n),
				.keep_bits_in  (i_axist_tx_tkeep[(j+1)*8-1:8*j]), 
				.empty_bits_out_d1(keep2empty_sop_align_d1[j])			
			);
	end
 
  always_comb begin
    avst_tx_eop_empty_d1 = 'd0; 
	  for (int p=0; p<NO_OF_BYTES/8; p=p+1) begin 
      avst_tx_eop_empty_d1 = avst_tx_eop_empty_d1 + keep2empty_sop_align_d1[p];
    end
  end
	//assign avst_tx_eop_empty_d1 = keep2empty_sop_align_d1[0]+keep2empty_sop_align_d1[1]+keep2empty_sop_align_d1[2]+keep2empty_sop_align_d1[3]+keep2empty_sop_align_d1[4]+keep2empty_sop_align_d1[5]+keep2empty_sop_align_d1[6]+keep2empty_sop_align_d1[7];
	
	always @(posedge i_tx_clk or negedge i_tx_reset_n) 
	begin
		if (~i_tx_reset_n)
			avst_tx_eop_empty_d2 <= {EMPTY_BITS{1'b0}};
		else 
			avst_tx_eop_empty_d2 <= avst_tx_eop_empty_d1;
	end 
	
	always @(posedge i_tx_clk or negedge i_tx_reset_n) 
	begin
		if (~i_tx_reset_n) begin
			avst_eop_d1    <= 1'b0;
			avst_sop_latch <= 1'b1;
		end
		else if (axist_tx_tready_delayed && i_axist_tx_tvalid && i_axist_tx_tlast) begin
			avst_eop_d1    <= 1'b1 ;
			avst_sop_latch <= 1'b1;
		end
		else if (axist_tx_tready_delayed && i_axist_tx_tvalid)
      begin
			avst_eop_d1    <= 1'b0;
			avst_sop_latch <= 1'b0;
      end
		else begin
			avst_eop_d1    <= 1'b0;
			avst_sop_latch <= avst_sop_latch;
		end			
	end
	always @(posedge i_tx_clk or negedge i_tx_reset_n) 
	begin
		if (~i_tx_reset_n) 
			avst_sop_d1 <= 1'b0;
		else if (avst_sop_latch && axist_tx_tready_delayed && i_axist_tx_tvalid)
			avst_sop_d1 <= 1'b1;
		else 
			avst_sop_d1 <= 1'b0;		
	end
			
	always @(posedge i_tx_clk) 
	begin
		avst_sop_d2 <= avst_sop_d1;
      avst_eop_d2 <= avst_eop_d1;
	end
	
	// assign fifo_data_in[AVST_USER-1:0]												 = avst_tx_user_d2;
	// assign fifo_data_in[AVST_DW+AVST_USER-1:AVST_USER]							 = avst_tx_swiped_data_d2;
	// assign fifo_data_in[EMPTY_BITS+AVST_DW+AVST_USER-1:AVST_DW+AVST_USER] = avst_tx_eop_empty_d2;   
	// assign fifo_data_in[EMPTY_BITS+AVST_DW+AVST_USER:EMPTY_BITS+AVST_DW+AVST_USER] = avst_sop_d2;
	// assign fifo_data_in[EMPTY_BITS+AVST_DW+AVST_USER+1:EMPTY_BITS+AVST_DW+AVST_USER+1] = avst_eop_d2;
	// assign fifo_data_in[FIFO_WIDTH-1] = avst_tx_valid_d2;
	assign fifo_data_in[AVST_USER-1:0]												 = avst_tx_user_d2;
	assign fifo_data_in[AVST_DW+AVST_USER-1:AVST_USER]							 = avst_tx_swiped_data_d2;
	assign fifo_data_in[EMPTY_BITS+AVST_DW+AVST_USER-1:AVST_DW+AVST_USER] = avst_tx_eop_empty_d2;   
	assign fifo_data_in[EMPTY_BITS+AVST_DW+AVST_USER:EMPTY_BITS+AVST_DW+AVST_USER] = avst_sop_d2;
	assign fifo_data_in[EMPTY_BITS+AVST_DW+AVST_USER+1:EMPTY_BITS+AVST_DW+AVST_USER+1] = avst_eop_d2;
	assign fifo_data_in[EMPTY_BITS+AVST_DW+AVST_USER+2:EMPTY_BITS+AVST_DW+AVST_USER+2] = avst_tx_valid_d2;
	assign fifo_data_in[FIFO_WIDTH-1:FIFO_WIDTH-PRMBLE_WIDTH] = (PREAMBLE_PASS_TH_EN) ? avst_tx_preamble_d2 : avst_tx_valid_d2;
	
	
	// assign o_avst_tx_user      	 = fifo_data_out[AVST_USER-1:0];									
	// assign o_avst_tx_data      	 = fifo_data_out[AVST_DW+AVST_USER-1:AVST_USER];					
	// assign o_avst_tx_eop_empty   	 = fifo_data_out[EMPTY_BITS+AVST_DW+AVST_USER-1:AVST_DW+AVST_USER];	
	// assign o_avst_tx_startofpacket = fifo_data_out[EMPTY_BITS+AVST_DW+AVST_USER:EMPTY_BITS+AVST_DW+AVST_USER];
	// assign o_avst_tx_endofpacket 	 = fifo_data_out[EMPTY_BITS+AVST_DW+AVST_USER+1:EMPTY_BITS+AVST_DW+AVST_USER+1];
	// assign o_avst_tx_valid 	       = fifo_data_out[FIFO_WIDTH-1] && i_avst_tx_ready && ~av_st_tx_fifo_empty;
	// assign o_avst_tx_valid_pkt_client   = fifo_data_out[FIFO_WIDTH-1] && i_avst_tx_ready && ~av_st_tx_fifo_empty;
	// assign o_avst_tx_inframe   	 = {NUM_SEG{1'b0}};	
	assign o_avst_tx_user      	 = fifo_data_out[AVST_USER-1:0];									
	assign o_avst_tx_data      	 = fifo_data_out[AVST_DW+AVST_USER-1:AVST_USER];					
	assign o_avst_tx_eop_empty   	 = fifo_data_out[EMPTY_BITS+AVST_DW+AVST_USER-1:AVST_DW+AVST_USER];	
	assign o_avst_tx_startofpacket = fifo_data_out[EMPTY_BITS+AVST_DW+AVST_USER:EMPTY_BITS+AVST_DW+AVST_USER];
	assign o_avst_tx_endofpacket 	 = fifo_data_out[EMPTY_BITS+AVST_DW+AVST_USER+1:EMPTY_BITS+AVST_DW+AVST_USER+1];
	assign o_avst_tx_valid 	       = fifo_data_out[EMPTY_BITS+AVST_DW+AVST_USER+2:EMPTY_BITS+AVST_DW+AVST_USER+2] && i_avst_tx_ready && ~av_st_tx_fifo_empty;
	assign o_avst_tx_valid_pkt_client   = fifo_data_out[EMPTY_BITS+AVST_DW+AVST_USER+2:EMPTY_BITS+AVST_DW+AVST_USER+2] && i_avst_tx_ready && ~av_st_tx_fifo_empty;
	assign o_avst_tx_preamble    = (PREAMBLE_PASS_TH_EN) ? fifo_data_out[FIFO_WIDTH-1:FIFO_WIDTH-PRMBLE_WIDTH] : 64'b0;		
	assign o_avst_tx_inframe   	 = {NUM_SEG{1'b0}};	
	
	
end //end of BRIDGE_SP2SA
endgenerate
 
 
 
//delaying the wrreq of fifo to ready latency value//
always @(posedge i_tx_clk or negedge i_tx_reset_n)
begin 
	if (~i_tx_reset_n)
		fifo_wrreq_d1 <= 1'b0;
	else
		fifo_wrreq_d1 <= axist_tx_tready_delayed;	
end
 
///wrreq delayed by 2 cycles to match conversion delay
always @(posedge i_tx_clk or negedge i_tx_reset_n)
begin 
	if (~i_tx_reset_n)
		fifo_wrreq_d2 <= 1'b0;
  else
		//fifo_wrreq_d2 <= fifo_wrreq_d1 & avst_tx_valid_d1;	
		fifo_wrreq_d2 <= fifo_wrreq_d1;	
end
 
///tready delayed one more cycle to match delay of avst_eop_d1 and avst_sop_d1 to generate avst_tx_inframe_d2 in mac segmented generate block
always @(posedge i_tx_clk)
begin 
	axist_tx_tready_delayed_d1 <= axist_tx_tready_delayed;
end	
/*
scfifo #(
    //.enable_ecc             (ENABLE_ECC),  //available in S10 and A10. Agilex?
    //.intended_device_family ("AGILEX"), //$family for simulation
      //.lpm_hint               ("RAM_BLOCK_TYPE=MLAB,MAXIMUM_DEPTH=32,DISABLE_DCFIFO_EMBEDDED_TIMING_CONSTRAINT=TRUE"),
    .lpm_numwords           (2**FIFO_DEPTH),
    .lpm_showahead          ("OFF"),
    .lpm_type               ("SCFIFO"),
    .lpm_width              (FIFO_WIDTH),
    .lpm_widthu             (FIFO_DEPTH),
    .overflow_checking      ("OFF"),
    .underflow_checking     ("OFF"),
    .use_eab                ("ON")//USE_M20K)  //use block ram or not
) U_av_st_rdy_lat_fifo (
    .sclr       (~i_tx_reset_n),
    .data       (fifo_data_in),
    .clock      (i_tx_clk),
    .rdreq      (i_avst_tx_ready && ~av_st_tx_fifo_empty),
    .wrreq      (fifo_wrreq_d2),
    .q          (fifo_data_out),
    .empty      (av_st_tx_fifo_empty),
    //.full       (av_st_tx_fifo_full) 
    //.eccstatus  (),
    .usedw      (avst_tx_fifo_lvl)
);
 
*/
generate 
if (ENABLE_ECC) 
begin : DCFIFO_WITH_ECC
	dcfifo  # (
		.enable_ecc               (EN_ECC),
		.intended_device_family   ("Agilex"),
		.lpm_hint 				  ("RAM_BLOCK_TYPE=M20K,DISABLE_DCFIFO_EMBEDDED_TIMING_CONSTRAINT=TRUE"),
		.lpm_width                (FIFO_WIDTH),
		.lpm_widthu               (FIFO_DEPTH),
		.lpm_numwords             (2**FIFO_DEPTH),
		.lpm_type                 ("dcfifo"),
		.lpm_showahead            ("OFF"),
		.overflow_checking        ("OFF"),
		.rdsync_delaypipe		  (4),
		.wrsync_delaypipe		  (4),
		.underflow_checking       ("OFF"),
		.use_eab                  ("ON")
	) U_av_st_rdy_lat_fifo (
		.data (fifo_data_in),
		.rdclk (i_tx_clk),
		.rdreq (i_avst_tx_ready && ~av_st_tx_fifo_empty),
		.wrclk (i_tx_clk),
		.wrreq (fifo_wrreq_d2),
		.eccstatus (ecc_status),
		.q (fifo_data_out),
		.rdempty (av_st_tx_fifo_empty),
		.wrfull (),
		.aclr (~i_tx_reset_n),
		.rdfull (),
		.rdusedw (),
		.wrempty (),
		.wrusedw (avst_tx_fifo_lvl)
	);
		assign o_fifo_eccstatus = ecc_status;
end
else begin : DCFIFO_WITHOUT_ECC
	dcfifo  # (
		// .enable_ecc               (EN_ECC),
		.intended_device_family   ("Agilex"),
		.lpm_hint 				  ("RAM_BLOCK_TYPE=M20K,DISABLE_DCFIFO_EMBEDDED_TIMING_CONSTRAINT=TRUE"),
		.lpm_width                (FIFO_WIDTH),
		.lpm_widthu               (FIFO_DEPTH),
		.lpm_numwords             (2**FIFO_DEPTH),
		.lpm_type                 ("dcfifo"),
		.lpm_showahead            ("OFF"),
		.overflow_checking        ("OFF"),
		.rdsync_delaypipe		  (4),
		.wrsync_delaypipe		  (4),
		.underflow_checking       ("OFF"),
		.use_eab                  ("ON")
	) U_av_st_rdy_lat_fifo (
		.data (fifo_data_in),
		.rdclk (i_tx_clk),
		.rdreq (i_avst_tx_ready && ~av_st_tx_fifo_empty),
		.wrclk (i_tx_clk),
		.wrreq (fifo_wrreq_d2),
		// .eccstatus (ecc_status),
		.q (fifo_data_out),
		.rdempty (av_st_tx_fifo_empty),
		.wrfull (),
		.aclr (~i_tx_reset_n),
		.rdfull (),
		.rdusedw (),
		.wrempty (),
		.wrusedw (avst_tx_fifo_lvl)
	);
		assign o_fifo_eccstatus = 2'b0;
end
endgenerate
 
endmodule

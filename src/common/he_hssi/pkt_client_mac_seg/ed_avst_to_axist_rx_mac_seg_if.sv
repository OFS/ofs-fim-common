// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on


module ed_avst_to_axist_rx_mac_seg_if #(
    parameter SIM_EMULATE   	 = 1,
    parameter AVST_MODE			 = "MAC_SEGMENTED",
    parameter AVST_DW      	 = 64,
parameter PORT_PROFILE    = "400GBE",
	 parameter NUM_SEG           = (AVST_MODE == "SOP_ALIGNED")?1:(AVST_DW/64),  //8 bytes per segment
    parameter EMPTY_BITS    	 = (AVST_MODE == "SOP_ALIGNED")? $clog2(AVST_DW/8) : 3,
    parameter AVST_ERR      	 = 2*NUM_SEG,
    parameter FCS_ERR  	 		 = 1*NUM_SEG,
    parameter MAC_STS  	 		 = 3*NUM_SEG,
    parameter AVST_USER  		 = AVST_ERR + FCS_ERR + MAC_STS, 
    parameter AXI_MODE		    = "MULTI_PACKET", 
    parameter AXI_DW      	    = 64,
    parameter NO_OF_BYTES  	 = AXI_DW/8, 
    parameter TUSER  		 	 = AVST_ERR + FCS_ERR + MAC_STS, 
    // parameter AXI_ERR      	 = 2*NUM_SEG,
	parameter PKT_SEG_PARITY_EN = 0  
	
) (
    input                           		i_rx_clk, 
    input                           		i_rx_reset_n,
											
    //Avalon Stream Rx, MAC side interface	
    input                           		i_avst_rx_valid,
    input   [AVST_DW-1:0]           		i_avst_rx_data,
    input   [NUM_SEG-1:0]         			i_avst_rx_inframe,
    input   [NUM_SEG*EMPTY_BITS-1:0]      i_avst_rx_eop_empty,
    input   [AVST_USER-1:0]      			i_avst_rx_user,
    input   				            		i_avst_rx_startofpacket,
    input   				            		i_avst_rx_endofpacket,
    input   [64-1:0]		            		i_avst_rx_preamble,
    // input   [AVST_ERR-1:0]          		i_avst_rx_mac_error,
    // input   [FCS_ERR-1:0]      				i_avst_rx_fcs_error,
    // input   [MAC_STS-1:0]      				i_avst_rx_mac_status,
											
    //AXI Stream Rx, User side interface		   
    output reg                     			o_axist_rx_tvalid,
    output reg [AXI_DW-1:0]      			o_axist_rx_tdata,
    output reg [NUM_SEG-1:0]    		    	o_axist_rx_tlast_segment,
    output reg [NO_OF_BYTES-1:0]  		o_axist_rx_tkeep,
    output reg [NUM_SEG*8-1:0]  		o_axist_rx_tkeep_segment,
    output reg 						    		o_axist_rx_tlast,
    output reg [TUSER-1:0]						o_axist_rx_tuser,
    output reg 					    	o_axist_rx_tuser_valid,
    output reg [64-1:0]			            o_axist_rx_preamble,
    output reg [NUM_SEG-1:0]			    	o_axist_rx_pkt_seg_parity
    // output reg [AXI_ERR-1:0]           		o_axist_rx_tuser_client,
    // output reg [4:0]               		    o_axist_rx_tuser_sts
);
 
//***********************************************************
//***********************************************************
 
reg  [NUM_SEG-1:0]				avst_rx_sop_d1;
reg  [NUM_SEG-1:0]				avst_rx_eop_d1;
reg  [NUM_SEG-1:0]				tlast_segment_d1;
reg  [NO_OF_BYTES-1:0]			tkeep_d1;
 
reg								axist_rx_tlast_d1;
reg								axist_rx_tuser_valid_d1;
 
reg	                         	avst_rx_valid_d1;
reg	                         	avst_rx_ms_valid_d1;
reg	 [AVST_DW-1:0]           	avst_rx_data_d1;
reg	 [AVST_DW-1:0]           	avst_rx_swiped_data_d1;
reg	 [NUM_SEG-1:0]         		avst_rx_inframe_d1;
reg	 [NUM_SEG*EMPTY_BITS-1:0]   avst_rx_eop_empty_d1;
reg	 [AVST_USER-1:0]      		avst_rx_user_d1;
reg	 [64-1:0]      				axist_rx_preamble_d1;
 
logic  [NUM_SEG-1:0]  [63:0]      	axist_rx_seg_data;
logic  [AVST_DW-1:0]  		      	axist_rx_avst_data;
logic  [NUM_SEG-1:0]  		     	rx_parity_detect;
logic  [NUM_SEG-1:0]  		     	avst_tx_parity_error;
wire   [AVST_DW-1:0]           	axist_rx_tdata;
 
 always @(posedge i_rx_clk or negedge i_rx_reset_n)
 begin
	 if (~i_rx_reset_n) begin
		avst_rx_valid_d1	 <= 1'b0;
//		avst_rx_inframe_d1 <= {NUM_SEG{1'b0}};
		avst_rx_eop_empty_d1 <= {NUM_SEG*EMPTY_BITS{1'b0}};
	 end
	 else begin
		avst_rx_valid_d1 	 <=  i_avst_rx_valid ;
//		avst_rx_inframe_d1 <=  i_avst_rx_inframe;	
		avst_rx_eop_empty_d1 <=	 i_avst_rx_eop_empty;
	end
 end
 
 always @(posedge i_rx_clk or negedge i_rx_reset_n)
 begin
	 if (~i_rx_reset_n)
		avst_rx_inframe_d1 <= {NUM_SEG{1'b0}};
	 else if(i_avst_rx_valid)
		avst_rx_inframe_d1 <=  i_avst_rx_inframe;	
 end
 
always @(posedge i_rx_clk or negedge i_rx_reset_n)
begin
	if (~i_rx_reset_n) begin
		avst_rx_data_d1 <= {AXI_DW{1'b0}};
		avst_rx_user_d1 <= {TUSER{1'b0}};	
		axist_rx_preamble_d1 <= 64'b0;	
	end
	else begin
		avst_rx_data_d1 <= i_avst_rx_data;
		avst_rx_user_d1 <= i_avst_rx_user;
		axist_rx_preamble_d1 <= i_avst_rx_preamble;
	end
end
 
generate if (AVST_MODE == "MAC_SEGMENTED")
begin :MAC_SEGMENTED
	genvar i;
		
		for (i=0; i<NUM_SEG; i=i+1) begin :BRIDGE_MS2MP
			
			always @(posedge i_rx_clk or negedge i_rx_reset_n) 
			begin
				if (~i_rx_reset_n)
					avst_rx_eop_d1[i] <= 1'b0;
				else if (i_avst_rx_valid) begin
					if ((i==0) && !i_avst_rx_inframe[i] && avst_rx_inframe_d1[NUM_SEG-1]) 						
						avst_rx_eop_d1[i] <= 1'b1;
					else if ((i!=0) && !i_avst_rx_inframe[i] && i_avst_rx_inframe[i-1]) 									
						avst_rx_eop_d1[i] <= 1'b1;
					else 	
						avst_rx_eop_d1[i] <= '0;					
				end
				else
					avst_rx_eop_d1[i] <= '0;
			end
			
			always @(posedge i_rx_clk or negedge i_rx_reset_n) 
			begin
				if (~i_rx_reset_n)
					avst_rx_sop_d1[i] <= 1'b0;
				else if (i_avst_rx_valid) begin
					if ((i==0) && i_avst_rx_inframe[i] && !avst_rx_inframe_d1[NUM_SEG-1])			
						avst_rx_sop_d1[i] <= 1'b1;	
					else if ((i!=0) && i_avst_rx_inframe[i] && !i_avst_rx_inframe[i-1])				
						avst_rx_sop_d1[i] <= 1'b1;						
					else 
						avst_rx_sop_d1[i] <= 1'b0;
				end
				else
					avst_rx_sop_d1[i] <= 1'b0;
			end
			
			assign tlast_segment_d1[i] = (avst_rx_eop_d1[i]) ? 1'b1 : 1'b0; 
			
			always @(posedge i_rx_clk or negedge i_rx_reset_n) begin
				if (~i_rx_reset_n) 
					o_axist_rx_tlast_segment[i] <= 1'b0;
				else
					o_axist_rx_tlast_segment[i] <= tlast_segment_d1[i];   
			end
			
			always @(posedge i_rx_clk or negedge i_rx_reset_n) 
			begin
				if (~i_rx_reset_n)
					o_axist_rx_tkeep_segment[(i+1)*8-1:8*i] <= {8{1'b0}};				
				else if (avst_rx_ms_valid_d1) begin
					if (tlast_segment_d1[i])
						o_axist_rx_tkeep_segment[(i+1)*8-1:8*i] <= {(8){1'b1}} >> avst_rx_eop_empty_d1[(i+1)*EMPTY_BITS-1:EMPTY_BITS*i];
					else if (avst_rx_inframe_d1[i])
						o_axist_rx_tkeep_segment[(i+1)*8-1:8*i] <= {(8){1'b1}};
					else 
						o_axist_rx_tkeep_segment[(i+1)*8-1:8*i] <= {8{1'b0}};
				end
				else
					o_axist_rx_tkeep_segment[(i+1)*8-1:8*i] <= {8{1'b0}};	
			end
			// always @(posedge i_rx_clk or negedge i_rx_reset_n) 
			// begin
				// if (~i_rx_reset_n)
					// o_axist_rx_tkeep_segment[(i+1)*NO_OF_BYTES-1:NO_OF_BYTES*i] <= {NO_OF_BYTES{1'b0}};				
				// else if (avst_rx_ms_valid_d1) begin
					// if (tlast_segment_d1[i])
					// o_axist_rx_tkeep_segment[(i+1)*NO_OF_BYTES-1:NO_OF_BYTES*i] <= {(NO_OF_BYTES){1'b1}} >> avst_rx_eop_empty_d1[(i+1)*EMPTY_BITS-1:EMPTY_BITS*i];
					// else 
						// o_axist_rx_tkeep_segment[(i+1)*NO_OF_BYTES-1:NO_OF_BYTES*i] <= {(NO_OF_BYTES){1'b1}};
				// end
				// else
					// o_axist_rx_tkeep_segment[(i+1)*NO_OF_BYTES-1:NO_OF_BYTES*i] <= {NO_OF_BYTES{1'b0}};	
			// end
			
		end
		
		always @(posedge i_rx_clk or negedge i_rx_reset_n) 
		begin
			if (~i_rx_reset_n) begin
				o_axist_rx_tuser_valid <= 1'b0;	
				o_axist_rx_tlast <= 1'b0;
				o_axist_rx_tkeep <= {NO_OF_BYTES{1'b0}};
			end
			else begin 
				o_axist_rx_tuser_valid <= (avst_rx_valid_d1 && avst_rx_sop_d1) ? 1'b1 : 1'b0;
			    o_axist_rx_tlast <= |(tlast_segment_d1);
				o_axist_rx_tkeep <= {NO_OF_BYTES{1'b0}};
			end
		end
		//assign 	avst_rx_ms_valid_d1	= ((avst_rx_valid_d1 && (|avst_rx_inframe_d1)) || (|avst_rx_eop_d1));		
		assign 	avst_rx_ms_valid_d1	= avst_rx_valid_d1 && ((|avst_rx_inframe_d1) || (|avst_rx_eop_d1));		
 
end
else begin :SOP_ALIGNED
genvar j;
    for (j=0; j<NO_OF_BYTES; j=j+1)
    begin : BYTE_SWAP
        always @(posedge i_rx_clk)
        begin
           avst_rx_swiped_data_d1[(j*8)+7:(j*8)] <= i_avst_rx_data[AVST_DW-1-(j*8):AVST_DW-8-(j*8)];
        end
    end
	always @(posedge i_rx_clk or negedge i_rx_reset_n)
	begin
		if (~i_rx_reset_n) begin
			axist_rx_tlast_d1 <= 1'b0;
			o_axist_rx_tlast  <= 1'b0;
		end
		else if (i_avst_rx_valid) begin
			axist_rx_tlast_d1 <= i_avst_rx_endofpacket;
			o_axist_rx_tlast  <= axist_rx_tlast_d1;
		end
		else begin
			axist_rx_tlast_d1 <= 1'b0;
			o_axist_rx_tlast  <= axist_rx_tlast_d1;
		end
	end
 
	always @(posedge i_rx_clk or negedge i_rx_reset_n) 
	begin
		if (~i_rx_reset_n)
			tkeep_d1 <= '0;
		else if (i_avst_rx_valid) begin
			if (i_avst_rx_endofpacket)
				tkeep_d1[NO_OF_BYTES-1:0] <= {(NO_OF_BYTES){1'b1}} >> i_avst_rx_eop_empty[EMPTY_BITS-1:0];
			else 
				tkeep_d1[NO_OF_BYTES-1:0] <= {(NO_OF_BYTES){1'b1}};
		end
		else 
			tkeep_d1 <= '0;
	end
	// always @(posedge i_rx_clk or negedge i_rx_reset_n) 
	// begin
		// if (~i_rx_reset_n)
			// tkeep_d1 <= '0;
		// else if (i_avst_rx_valid) begin
			// if (i_avst_rx_endofpacket)
			// tkeep_d1[NO_OF_BYTES-1:0] <= {(NO_OF_BYTES){1'b1}} >> i_avst_rx_eop_empty[EMPTY_BITS-1:0];
			// else 
				// tkeep_d1[NO_OF_BYTES-1:0] <= {(NO_OF_BYTES){1'b1}};
		// end
		// else 
			// tkeep_d1 <= '0;
	// end
	
	always @(posedge i_rx_clk or negedge i_rx_reset_n)
	begin
		if (~i_rx_reset_n) begin
			o_axist_rx_tuser_valid <= 1'b0;
			axist_rx_tuser_valid_d1 <= 1'b0;
			o_axist_rx_tkeep <= {NO_OF_BYTES{1'b0}};
			o_axist_rx_tkeep_segment <= {8*NUM_SEG{1'b0}};
			o_axist_rx_tlast_segment <= {NUM_SEG{1'b0}};
		end
		else begin
			axist_rx_tuser_valid_d1 <= (i_avst_rx_valid & i_avst_rx_startofpacket);
			o_axist_rx_tuser_valid <= axist_rx_tuser_valid_d1;
			o_axist_rx_tkeep <= tkeep_d1;
			o_axist_rx_tkeep_segment <= {8*NUM_SEG{1'b0}};
			o_axist_rx_tlast_segment <= 1'b0;
		end
	end	
	
end
endgenerate
	
always @(posedge i_rx_clk or negedge i_rx_reset_n)
begin
	if (~i_rx_reset_n) begin
		o_axist_rx_tvalid 		  <= 1'b0;
		o_axist_rx_tdata  		  <= {AXI_DW{1'b0}};
		o_axist_rx_tuser  		  <= {TUSER{1'b0}};	
		o_axist_rx_preamble  	  <= 64'b0;	
	end
	else begin
		o_axist_rx_tvalid 		  <= (AVST_MODE == "MAC_SEGMENTED") ? avst_rx_ms_valid_d1 : avst_rx_valid_d1;
		o_axist_rx_tdata  		  <= (AVST_MODE == "MAC_SEGMENTED") ? avst_rx_data_d1 : avst_rx_swiped_data_d1;
		o_axist_rx_tuser  		  <= avst_rx_user_d1;
		o_axist_rx_preamble  	  <= axist_rx_preamble_d1;
	end
end
 
assign axist_rx_tdata = (AVST_MODE == "MAC_SEGMENTED") ? avst_rx_data_d1 : avst_rx_swiped_data_d1;
generate 
if (PKT_SEG_PARITY_EN)
begin:RX_PARITY_CALC
genvar rx_sp;
	if (AVST_MODE == "MAC_SEGMENTED") begin
		for (rx_sp=0; rx_sp<NUM_SEG; rx_sp=rx_sp+1)begin :RX_SEG_DATA
			always_comb begin
				axist_rx_seg_data[rx_sp] = axist_rx_tdata[64*(rx_sp+1)-1:64*rx_sp];
				rx_parity_detect[rx_sp] = ^(axist_rx_seg_data[rx_sp]);
			end	
			
			always @(posedge i_rx_clk or negedge i_rx_reset_n) begin
			if (~i_rx_reset_n)
				o_axist_rx_pkt_seg_parity[rx_sp] <= 1'b0; 
			else
				o_axist_rx_pkt_seg_parity[rx_sp] <= ~rx_parity_detect[rx_sp]; 
			end			
		end
		assign axist_rx_avst_data = {AVST_DW{1'b0}};
	end
	else begin
		always_comb begin
			axist_rx_avst_data = axist_rx_tdata;
			rx_parity_detect = ^(axist_rx_avst_data);
		end	
		
		always @(posedge i_rx_clk or negedge i_rx_reset_n) begin
			if (~i_rx_reset_n)
				o_axist_rx_pkt_seg_parity <= 1'b0; 
			else
				o_axist_rx_pkt_seg_parity <= ~rx_parity_detect; 
		end			
		assign axist_rx_seg_data = 64'b0;	
	end
		
end
else begin : RX_NO_PARITY
		always @(posedge i_rx_clk or negedge i_rx_reset_n) begin
      if (~i_rx_reset_n)
		  	o_axist_rx_pkt_seg_parity <= {NUM_SEG{1'b0}};
      else
		  	o_axist_rx_pkt_seg_parity <= {NUM_SEG{1'b0}};
		end
end
endgenerate		
 
		
endmodule

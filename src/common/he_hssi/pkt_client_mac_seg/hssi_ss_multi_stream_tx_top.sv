// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on


module hssi_ss_multi_stream_tx_top #(
    parameter DATA_WIDTH     	    	= 64,
	 parameter PORT_CLIENT_IF     	= 0,
    parameter TDATA_WIDTH      	   = 64,
    parameter NO_OF_BYTES  			= TDATA_WIDTH/8, 
    parameter TUSER_WIDTH_TX  	 	= 2 +90 +328,
   // parameter TUSER_WIDTH_RX  	 	= 2 +90 +328,
    parameter ST_READY_LATENCY      = 1,  
    parameter TID   				   = 8,  
	 parameter ENABLE_ECC  			= 1,
	 parameter USE_M20K			 	= "ON",
    parameter PORT_PROFILE   	 	= "200G",	
	 parameter NUM_SEG               = (PORT_PROFILE == "200G")? 8 : 16,  
    parameter NUM_OF_STREAM   		= 2  
	
) (
    input   			             		 	 				i_tx_clk, 
    input   			             		 	 				i_tx_reset_n,
   /////////// TX ports ///////////////////		 		 	
    //AXI Stream Tx, from User interface		 
			 //SINGLE PACKET COMPATIBLE SIGNALS		 	         
	 input 															i_av_st_tx_ready,	 
    input  [NUM_OF_STREAM-1:0] 								i_axi_st_tx_tvalid,
    input  [NUM_OF_STREAM-1:0][TDATA_WIDTH-1:0] 		 i_axi_st_tx_tdata,
    input  [NUM_OF_STREAM-1:0]       						i_axi_st_tx_tlast,
    input  [NUM_OF_STREAM-1:0][NO_OF_BYTES-1:0]			i_axi_st_tx_tkeep,
    input  [NUM_OF_STREAM-1:0][TUSER_WIDTH_TX-1:0] 	i_axi_st_tx_tuser,
    input  [NUM_OF_STREAM-1:0][TID-1:0]       			i_axi_st_tx_tid,
			 //MULTI PACKET COMPATIBLE SIGNALS		   	     
	 output reg	[NUM_OF_STREAM-1:0]							o_axi_st_tx_tready,
			
    //Avalon Stream Tx, to MAC interface		   		
    output reg  [TDATA_WIDTH-1:0]           				o_axi_st_tx_tdata,
    output reg                          					o_axi_st_tx_tvalid,
    output reg  [NUM_SEG-1:0][8-1:0]  		            o_axi_st_tx_tkeep_seg,
	 output reg  [NUM_SEG-1:0]									o_axi_st_tx_tlast_seg,	
    output reg  [TUSER_WIDTH_TX-1:0]      				o_axi_st_tx_tuser
													 
	
);

//***********************************************************
//***********************************************************

//--------------------------------------------------------------------------------------------------
//          MULTI STREAM INSTANCES
//--------------------------------------------------------------------------------------------------

generate if ((NUM_OF_STREAM == 2) && (PORT_PROFILE == "200G"))
begin : MULTI_STREAM_200x2
	hssi_ss_ms_200x2_tx #(
		.AXI_DW      	(TDATA_WIDTH),
		.TUSER  		(TUSER_WIDTH_TX),
		.TID 	   	 	(TID),
		.READY_LATENCY  (ST_READY_LATENCY),
		.ENABLE_ECC  	(ENABLE_ECC),
		.USE_M20K		(USE_M20K)
	)hssi_ss_ms_200x2_tx_inst(
		.i_tx_clk				(i_tx_clk),
		.i_tx_reset_n			(i_tx_reset_n),															   
		.o_axi_st_tx_tready		(o_axi_st_tx_tready),		
		.i_axi_st_tx_tvalid      (i_axi_st_tx_tvalid),
		.i_axi_st_tx_tdata       (i_axi_st_tx_tdata),
		.i_axi_st_tx_tkeep       (i_axi_st_tx_tkeep),
		.i_axi_st_tx_tlast       (i_axi_st_tx_tlast),
		.i_axi_st_tx_tuser       (i_axi_st_tx_tuser),
		.i_axi_st_tx_oid         (i_axi_st_tx_tid),
		.i_av_st_tx_ready	    	 (i_av_st_tx_ready),
		.o_axi_st_tx_tdata       (o_axi_st_tx_tdata),
		.o_axi_st_tx_tvalid      (o_axi_st_tx_tvalid),
		.o_axi_st_tx_tkeep_seg   (o_axi_st_tx_tkeep_seg),
		.o_axi_st_tx_tlast_seg   (o_axi_st_tx_tlast_seg),
		.o_axi_st_tx_tuser        (o_axi_st_tx_tuser)
	);
			
end

else if ((NUM_OF_STREAM == 4) && (PORT_PROFILE == "200G"))
begin : MULTI_STREAM_200x4	
	hssi_ss_ms_200x4_tx #(
		.AXI_DW      	(TDATA_WIDTH),
		.TUSER  		(TUSER_WIDTH_TX),
		.TID 	   	 	(TID),
		.READY_LATENCY  (ST_READY_LATENCY),
		.ENABLE_ECC  	(ENABLE_ECC),
		.USE_M20K		(USE_M20K)
	)hssi_ss_ms_200x4_tx_inst(
		.i_tx_clk				(i_tx_clk),
		.i_tx_reset_n			(i_tx_reset_n),															   
		.o_axi_st_tx_tready		(o_axi_st_tx_tready),		
		.i_axi_st_tx_tvalid      (i_axi_st_tx_tvalid),
		.i_axi_st_tx_tdata       (i_axi_st_tx_tdata),
		.i_axi_st_tx_tkeep       (i_axi_st_tx_tkeep),
		.i_axi_st_tx_tlast       (i_axi_st_tx_tlast),
		.i_axi_st_tx_tuser       (i_axi_st_tx_tuser),
		.i_axi_st_tx_oid         (i_axi_st_tx_tid),
		.i_av_st_tx_ready	    (i_av_st_tx_ready),
		.o_axi_st_tx_tdata       (o_axi_st_tx_tdata),
		.o_axi_st_tx_tvalid      (o_axi_st_tx_tvalid),
		.o_axi_st_tx_tkeep_seg   (o_axi_st_tx_tkeep_seg),
		.o_axi_st_tx_tlast_seg   (o_axi_st_tx_tlast_seg),
		.o_axi_st_tx_tuser        (o_axi_st_tx_tuser)
	);
			
end

else if ((NUM_OF_STREAM == 2) && (PORT_PROFILE == "400G"))
begin : MULTI_STREAM_400x2	
	hssi_ss_ms_400x2_tx #(
		.AXI_DW      	(TDATA_WIDTH),
		.TUSER  		(TUSER_WIDTH_TX),
		.TID 	   	 	(TID),
		.READY_LATENCY  (ST_READY_LATENCY),
		.ENABLE_ECC  	(ENABLE_ECC),
		.USE_M20K		(USE_M20K)
	)hssi_ss_ms_400x2_tx_inst(
		.i_tx_clk					 (i_tx_clk),
		.i_tx_reset_n				 (i_tx_reset_n),															   
		.o_axi_st_tx_tready		 (o_axi_st_tx_tready),		
		.i_axi_st_tx_tvalid      (i_axi_st_tx_tvalid),
		.i_axi_st_tx_tdata       (i_axi_st_tx_tdata),
		.i_axi_st_tx_tkeep       (i_axi_st_tx_tkeep),
		.i_axi_st_tx_tlast       (i_axi_st_tx_tlast),
		.i_axi_st_tx_tuser       (i_axi_st_tx_tuser),
		.i_axi_st_tx_oid         (i_axi_st_tx_tid),
		.i_av_st_tx_ready	    	 (i_av_st_tx_ready),
		.o_axi_st_tx_tdata       (o_axi_st_tx_tdata),
		.o_axi_st_tx_tvalid      (o_axi_st_tx_tvalid),
		.o_axi_st_tx_tkeep_seg   (o_axi_st_tx_tkeep_seg),
		.o_axi_st_tx_tlast_seg   (o_axi_st_tx_tlast_seg),
		.o_axi_st_tx_tuser        (o_axi_st_tx_tuser)
	);
			
end

else if ((NUM_OF_STREAM == 4) && (PORT_PROFILE == "400G"))
begin : MULTI_STREAM_400x4	
	hssi_ss_ms_400x4_tx #(
		.AXI_DW      	(TDATA_WIDTH),
		.TUSER  		(TUSER_WIDTH_TX),
		.TID 	   	 	(TID),
		.READY_LATENCY  (ST_READY_LATENCY),
		.ENABLE_ECC  	(ENABLE_ECC),
		.USE_M20K		(USE_M20K)
	)hssi_ss_ms_400x4_tx_inst(
		.i_tx_clk					 (i_tx_clk),
		.i_tx_reset_n				 (i_tx_reset_n),															   
		.o_axi_st_tx_tready		 (o_axi_st_tx_tready),		
		.i_axi_st_tx_tvalid      (i_axi_st_tx_tvalid),
		.i_axi_st_tx_tdata       (i_axi_st_tx_tdata),
		.i_axi_st_tx_tkeep       (i_axi_st_tx_tkeep),
		.i_axi_st_tx_tlast       (i_axi_st_tx_tlast),
		.i_axi_st_tx_tuser       (i_axi_st_tx_tuser),
		.i_axi_st_tx_oid         (i_axi_st_tx_tid),
		.i_av_st_tx_ready	    	 (i_av_st_tx_ready),
		.o_axi_st_tx_tdata       (o_axi_st_tx_tdata),
		.o_axi_st_tx_tvalid      (o_axi_st_tx_tvalid),
		.o_axi_st_tx_tkeep_seg   (o_axi_st_tx_tkeep_seg),
		.o_axi_st_tx_tlast_seg   (o_axi_st_tx_tlast_seg),
		.o_axi_st_tx_tuser        (o_axi_st_tx_tuser)
	);
			
end
				
endgenerate
		
	
endmodule

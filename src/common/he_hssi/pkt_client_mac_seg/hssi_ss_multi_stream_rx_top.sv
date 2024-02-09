// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on


module hssi_ss_multi_stream_rx_top #(
    parameter DATA_WIDTH     	    	= 64,
	 parameter PORT_CLIENT_IF     	= 0,
    parameter TDATA_WIDTH      	   = 64,
    parameter NO_OF_BYTES  			= TDATA_WIDTH/8, 
    //parameter TUSER_WIDTH_TX  	 	= 2 +90 +328,
    parameter TUSER_WIDTH_RX  	 	= 2 +90 +328,
    parameter ST_READY_LATENCY      = 1,  
    parameter TID   				   = 8,  
	 parameter ENABLE_ECC  			= 1,
	 parameter USE_M20K			 	= "ON",
    parameter PORT_PROFILE   	 	= "200G",	
	 parameter NUM_SEG               = (PORT_PROFILE == "200G")? 8 : 16,  
    parameter NUM_OF_STREAM   		= 2  
	
) (
    input   			             		 	 				i_rx_clk, 
    input   			             		 	 				i_rx_reset_n,
													 
/////////// RX ports ////////////////////	     
	//////////////////////////////////////////												 
    //Avalon Stream Rx, from MAC interface		 
	//SOP ALIGNED COMPATIBLE SIGNALS		         
	//MAC_SEGMENTED COMPATIBLE SIGNALS		         
    input                           						i_axi_st_rx_tvalid,
    input   [TDATA_WIDTH-1:0]           					i_axi_st_rx_tdata,
    input   [NUM_SEG-1:0]         							i_axi_st_rx_tlast_seg,
    input   [NUM_SEG-1:0] [8-1:0] 				i_axi_st_rx_tkeep_seg,
    input   [TUSER_WIDTH_RX-1:0]      						i_axi_st_rx_tuser,
													 
    //AXI Stream Rx, to User interface				 
    output reg [NUM_OF_STREAM-1:0]        				o_axi_st_rx_tvalid,
    output reg [NUM_OF_STREAM-1:0] [TDATA_WIDTH-1:0]  o_axi_st_rx_tdata,
    output reg [NUM_OF_STREAM-1:0] [NO_OF_BYTES-1:0]  o_axi_st_rx_tkeep,
    output reg [NUM_OF_STREAM-1:0]    		    			o_axi_st_rx_tlast,
    output reg [NUM_OF_STREAM-1:0][TUSER_WIDTH_RX-1:0]o_axi_st_rx_tuser,
    output reg [NUM_OF_STREAM-1:0][TID-1:0]       		o_axi_st_rx_tid
	
);

//***********************************************************
//***********************************************************

//--------------------------------------------------------------------------------------------------
//          MULTI STREAM INSTANCES
//--------------------------------------------------------------------------------------------------

generate if ((NUM_OF_STREAM == 2) && (PORT_PROFILE == "200G"))
begin : MULTI_STREAM_200x2				
	hssi_ss_ms_200x2_rx #(	
		.AXI_DW      	(TDATA_WIDTH),
		.TUSER  		(TUSER_WIDTH_RX),
		.TID 		 	(TID)
	)hssi_ss_ms_200x2_rx_inst(
		.i_rx_clk				   (i_rx_clk), 
	    .i_rx_reset_n			   (i_rx_reset_n),	    
	    .i_axi_st_rx_tvalid		(i_axi_st_rx_tvalid),
	    .i_axi_st_rx_tdata		(i_axi_st_rx_tdata),
	    .i_axi_st_rx_tlast_seg	(i_axi_st_rx_tlast_seg),
	    .i_axi_st_rx_tkeep_seg	(i_axi_st_rx_tkeep_seg),
	    .i_axi_st_rx_tuser		(i_axi_st_rx_tuser),	    	   
	    .o_axi_st_rx_tvalid		(o_axi_st_rx_tvalid),
	    .o_axi_st_rx_tdata		(o_axi_st_rx_tdata),
	    .o_axi_st_rx_tlast		(o_axi_st_rx_tlast),
	    .o_axi_st_rx_tkeep		(o_axi_st_rx_tkeep),
		 .o_axi_st_rx_tid		   (o_axi_st_rx_tid),
	    .o_axi_st_rx_tuser      (o_axi_st_rx_tuser)
	);
end

else if ((NUM_OF_STREAM == 4) && (PORT_PROFILE == "200G") )
begin : MULTI_STREAM_200x4	
	hssi_ss_ms_200x4_rx #(	
		.AXI_DW      	(TDATA_WIDTH),
		.TUSER  		(TUSER_WIDTH_RX),
		.TID 		 	(TID)
	)hssi_ss_ms_200x4_rx_inst(
		.i_rx_clk					(i_rx_clk), 
	   .i_rx_reset_n				(i_rx_reset_n),	    
	   .i_axi_st_rx_tvalid		(i_axi_st_rx_tvalid),
	   .i_axi_st_rx_tdata		(i_axi_st_rx_tdata),
	   .i_axi_st_rx_tlast_seg	(i_axi_st_rx_tlast_seg),
	   .i_axi_st_rx_tkeep_seg	(i_axi_st_rx_tkeep_seg),
	   .i_axi_st_rx_tuser		(i_axi_st_rx_tuser),	    	   
	   .o_axi_st_rx_tvalid		(o_axi_st_rx_tvalid),
	   .o_axi_st_rx_tdata		(o_axi_st_rx_tdata),
	   .o_axi_st_rx_tlast		(o_axi_st_rx_tlast),
	   .o_axi_st_rx_tkeep		(o_axi_st_rx_tkeep),
	   .o_axi_st_rx_tuser     	(o_axi_st_rx_tuser)
	);
end

else if ((NUM_OF_STREAM == 2) && (PORT_PROFILE == "400G"))
begin : MULTI_STREAM_400x2	
	hssi_ss_ms_400x2_rx #(	
		.AXI_DW      	(TDATA_WIDTH),
		.TUSER  		(TUSER_WIDTH_RX),
		.TID 		 	(TID)
	)hssi_ss_ms_400x2_rx_inst(
		.i_rx_clk				(i_rx_clk), 
	    .i_rx_reset_n			(i_rx_reset_n),	    
	    .i_axi_st_rx_tvalid		(i_axi_st_rx_tvalid),
	    .i_axi_st_rx_tdata		(i_axi_st_rx_tdata),
	    .i_axi_st_rx_tlast_seg	(i_axi_st_rx_tlast_seg),
	    .i_axi_st_rx_tkeep_seg	(i_axi_st_rx_tkeep_seg),
	    .i_axi_st_rx_tuser		(i_axi_st_rx_tuser),	    	   
	    .o_axi_st_rx_tvalid		(o_axi_st_rx_tvalid[1:0]),
	    .o_axi_st_rx_tdata		(o_axi_st_rx_tdata[1:0]),
	    .o_axi_st_rx_tlast		(o_axi_st_rx_tlast[1:0]),
	    .o_axi_st_rx_tkeep		(o_axi_st_rx_tkeep[1:0]),
	    .o_axi_st_rx_tuser       (o_axi_st_rx_tuser)
	);
end

else if ((NUM_OF_STREAM == 4) && (PORT_PROFILE == "400G"))
begin : MULTI_STREAM_400x4	
	hssi_ss_ms_400x4_rx #(	
		.AXI_DW      	(TDATA_WIDTH),
		.TUSER  		(TUSER_WIDTH_RX),
		.TID 		 	(TID)
	)hssi_ss_ms_400x4_rx_inst(
		.i_rx_clk				(i_rx_clk), 
	    .i_rx_reset_n			(i_rx_reset_n),	    
	    .i_axi_st_rx_tvalid		(i_axi_st_rx_tvalid),
	    .i_axi_st_rx_tdata		(i_axi_st_rx_tdata),
	    .i_axi_st_rx_tlast_seg	(i_axi_st_rx_tlast_seg),
	    .i_axi_st_rx_tkeep_seg	(i_axi_st_rx_tkeep_seg),
	    .i_axi_st_rx_tuser		(i_axi_st_rx_tuser),	    	   
	    .o_axi_st_rx_tvalid		(o_axi_st_rx_tvalid),
	    .o_axi_st_rx_tdata		(o_axi_st_rx_tdata),
	    .o_axi_st_rx_tlast		(o_axi_st_rx_tlast),
	    .o_axi_st_rx_tkeep		(o_axi_st_rx_tkeep),
	    .o_axi_st_rx_tuser       (o_axi_st_rx_tuser)
	);
end
				
endgenerate
		
	
endmodule

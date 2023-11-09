// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on


module hssi_ss_f_ed_axis2avst_bridge #(
    parameter TILES   	 			 = "E",
    parameter SIM_EMULATE   	 	 = 0,
    parameter EHIP_RATE         = "10G",
    parameter CLIENT_IF_TYPE	    = 0,//CLIENT_IF_TYPE
    parameter DATA_WIDTH     	    = 64,
	 parameter NUM_SEG            = (CLIENT_IF_TYPE == 1) ? 1 : (DATA_WIDTH/64),  //8 bytes per segment   
    parameter EMPTY_BITS    			= 3,
    parameter AVST_ERR      	 		= 7*NUM_SEG,   
    parameter AVST_FCS_ERR  	 		= 1*NUM_SEG,   
    parameter AVST_MAC_STS  	 		= 3*NUM_SEG,   
    //parameter USER_WIDTH_TX	 		  =  64+96+7+5+32,
     //parameter TX_TUSER_CLIENT_WIDTH = 1,
    parameter RX_TUSER_CLIENT_WIDTH = 1,
    parameter RX_TUSER_STATS_WIDTH  = 1,
    //parameter USER_WIDTH_TX	 		  =  64+96+RX_TUSER_CLIENT_WIDTH+RX_TUSER_STATS_WIDTH+32, commented on oct17
    parameter USER_WIDTH_TX	 		  =  96+96+RX_TUSER_CLIENT_WIDTH+RX_TUSER_STATS_WIDTH+32,
    parameter NO_OF_BYTES  			  = (CLIENT_IF_TYPE == 1) ? (DATA_WIDTH/8) : 8, 
    //parameter TUSER_WIDTH_TX  	 	= 64+96+7+5+32, 
    //parameter TUSER_WIDTH_TX  	 	= 64+96+RX_TUSER_CLIENT_WIDTH+RX_TUSER_STATS_WIDTH+32, coomented on oct17
    parameter TUSER_WIDTH_TX  	 	= 96+96+RX_TUSER_CLIENT_WIDTH+RX_TUSER_STATS_WIDTH+32, 
    parameter AXIST_ERR      	 		= 7*NUM_SEG,
    parameter ENABLE_MULTI_STREAM   = 0,  
    parameter NUM_OF_STREAM   		= 1,  
    parameter PKT_SEG_PARITY_EN  	= 0,
    parameter PREAMBLE_PASS_TH_EN                = 0,//PREAMBLE_PASS_TH_EN
   // parameter DW_AVST             = (PREAMBLE_PASS_TH_EN)? DATA_WIDTH/2: DATA_WIDTH,  
   // parameter DW_AVST_DW            = (PREAMBLE_PASS_TH_EN)? DATA_WIDTH/2: DATA_WIDTH, 
    //parameter BW_AVST_BW            = (PREAMBLE_PASS_TH_EN)? NO_OF_BYTES/2: NO_OF_BYTES,
    parameter DW_AVST_DW            =  DATA_WIDTH, 
    parameter BW_AVST_BW            =  NO_OF_BYTES,  
    parameter ST_READY_LATENCY      = 0,
    parameter TID                   = 8,  
//declare parameter widths
	 	parameter	NUM_MAX_PORTS				= 1,
	 parameter	PKT_SEG_PARITY_WIDTH	= 4,
	 	parameter	DR_ENABLE	 						= 0
) (

    input                		 	 							i_clk_rx, 
    input              		 	   							rx_aresetn,
     	 //CSR
    input      [NUM_MAX_PORTS-1:0]            i_port_active_mask,       //current profile parameters based on profile_sel_reg
    input      [2:0]                          i_active_ports,           //current profile parameters based on profile_sel_reg 
    input      [2:0]                          i_active_segments,        //current profile parameters based on profile_sel_reg - valid for mac seg only
    input      [2:0]                          i_port_data_width,        //current profile parameters based on profile_sel_reg - valid for sopa only
         
		//SINGLE PACKET COMPATIBLE SIGNALS
    //TODO:widths of signals are not matching with packet_client signals		
    input  [NUM_OF_STREAM-1:0]		 	 			    axis_tvalid_i,   
    input  [NUM_OF_STREAM-1:0][DATA_WIDTH-1:0]      axis_tdata_i,
    input  [NUM_OF_STREAM-1:0]      				 	 axis_tlast_i,
    input  [NUM_OF_STREAM-1:0][DATA_WIDTH/8-1:0]	 axis_tkeep_i,
    input  [NUM_OF_STREAM-1:0][TID-1:0]				 axis_rx_tid_i,
	
    input  [NUM_SEG*8-1:0]	 		  			          axis_tkeep_seg_i,
  
	 input  [NUM_OF_STREAM-1:0][RX_TUSER_CLIENT_WIDTH-1:0]	axis_tuser_client_i,  //TODO:check  widht  2bits skip_crc -0 error -1
    input  [NUM_OF_STREAM-1:0][RX_TUSER_STATS_WIDTH-1:0]		axis_tuser_sts ,
    input  [NUM_OF_STREAM-1:0][31:0] 								axis_tuser_sts_ext,
    input  [NUM_OF_STREAM-1:0][95:0] 								axis_rx_ptp_its,
    input  [NUM_OF_STREAM-1:0][95:0]                        axis_rx_ptp_its_p2,
    //input  [63:0]                                           axis_rx_preamble_i,
   // input [NUM_OF_STREAM-1:0][TID-1:0]                      i_axis_rx_tid,//TODO:check
   

	 //MULTI PACKET COMPATIBLE SIGNALS		         
	  input  [NUM_SEG-1:0]    		    			 	axis_tuser_last_seg,
	  output reg										 	axis_tready_o,
	
//added for seg parity 30Sept checkp

   input [NUM_SEG-1:0 ]                     axis_rx_pkt_seg_parity_i, 	   
   input [NUM_SEG-1:0 ]                     axis_tuser_pkt_seg_parity_i, 	   
  
  
  
    //output [95:0] 								   o_rx_ptp_its,
   output [191:0] 								   o_rx_ptp_its,
		//SOP ALIGNED COMPATIBLE SIGNALS	   
	  input 										 		avst_ready_i,
    output reg  [DW_AVST_DW-1:0]  			   avst_data_o,
    output reg          						   avst_valid_o,
    output reg          		  					avst_sop_o,
    output reg           							avst_eop_o,
    output reg  [EMPTY_BITS-1:0] 	 			avst_empty_o,
    output reg  [USER_WIDTH_TX-1:0]      		o_av_st_rx_user, //check {}
   // output reg   [63:0]                      avst_preamble_o, //commented on Feb1
 
                                            		 											 
		//MAC_SEGMENTED COMPATIBLE SIGNALS		   
	 input 											 	i_av_st_rx_ms_ready,
    output reg  [NUM_SEG*64-1:0]       		o_av_st_rx_ms_data,
    output reg  [1-1:0]         				 	o_av_st_rx_ms_valid,
    output reg  [NUM_SEG-1:0]         			o_av_st_rx_ms_inframe,
    output reg  [NUM_SEG*3-1:0]  				o_av_st_rx_ms_eop_empty
   
												 
  		
);

//***********************************************************
//***********************************************************
localparam AVST_MODE  = (CLIENT_IF_TYPE == 0) ? "MAC_SEGMENTED" : "SOP_ALIGNED";
localparam AXIST_MODE = (CLIENT_IF_TYPE == 0) ? "MULTI_PACKET"  : "SINGLE_PACKET";

//wire	[DATA_WIDTH-1:0] 		   avst_rx_data;   
wire	[DW_AVST_DW-1:0] 		      avst_rx_data; //
wire								      avst_rx_valid;
wire								      avst_rx_valid_pkt_client;
wire	[NUM_SEG*EMPTY_BITS-1:0] 	avst_rx_empty;

/* commented on Feb1
logic 							 axi_valid_ppt;
logic                       axis_tlast_ppt; 
logic [DATA_WIDTH/2-1:0]	 axis_tdata_ppt;
logic [NO_OF_BYTES/2-1:0]   axis_tkeep_ppt;
logic [USER_WIDTH_TX-1:0]   axist_rx_tuser_ppt;
logic [63:0]                axis_rx_preamble_ppt;

*/

//-------TODO: MultiStream signalsCheck NOV25-------------------------------
logic	[NUM_OF_STREAM-1:0]				  		axis_rx_tready_mltstrm;
logic [DATA_WIDTH-1:0]				  axis_rx_tdata_mltstrm;
logic                              axis_rx_tvalid_mltstrm;
logic [NUM_SEG-1:0][8-1:0]					axis_rx_tkeep_seg_mltstrm;
logic [NUM_SEG-1:0]					  		axis_rx_tlast_seg_mltstrm;
logic [TUSER_WIDTH_TX-1:0]			  axis_rx_tuser_mltstrm;



//--------------------------------------------------------------------------------------------------
//                   AXI ST to AVST conversion for MAC segmented, SOP aligned
//-------------------------------------------------------------------------------------------------
	generate if ((ENABLE_MULTI_STREAM) && (CLIENT_IF_TYPE == 0))
	begin : MULTI_STREAM
		hssi_ss_multi_stream_tx_top #(
		 .DATA_WIDTH			(DATA_WIDTH),     	    
	    .NUM_SEG            (NUM_SEG),  
	    .TDATA_WIDTH      	(DATA_WIDTH),   
	    .NO_OF_BYTES  		(NO_OF_BYTES),	
	    .TUSER_WIDTH_TX  	(TUSER_WIDTH_TX), 	
	    //.TUSER_WIDTH_RX  	(TUSER_WIDTH_RX), 	
	    .ST_READY_LATENCY   (ST_READY_LATENCY),  
	    .TID   				   (TID), //check TID
	    //.ENABLE_ECC  		   (ENABLE_ECC),	
	    //.USE_M20K			   (USE_M20K), 	
	    .PORT_PROFILE   	 	(EHIP_RATE),
	    .NUM_OF_STREAM   	(NUM_OF_STREAM)
		
		)hssi_ss_multi_stream_rx_top_inst(
		 .i_tx_clk				   (i_clk_rx), 
	    .i_tx_reset_n			   (rx_aresetn),	   
	    .i_av_st_tx_ready		(1'b1),//TODO:CHECK readyaxist_tx_tready	 
	    .i_axi_st_tx_tvalid		(axis_tvalid_i),
	    .i_axi_st_tx_tdata		(axis_tdata_i),
	    .i_axi_st_tx_tlast		(axis_tlast_i),
	    .i_axi_st_tx_tkeep		(axis_tkeep_i),
	    .i_axi_st_tx_tuser		({axis_rx_ptp_its_p2,axis_rx_ptp_its, axis_tuser_client_i, axis_tuser_sts, axis_tuser_sts_ext}),
	    .i_axi_st_tx_tid		   (axis_rx_tid_i), //TODO:check why TID	            
	    .o_axi_st_tx_tready		(axis_rx_tready_mltstrm),	    
	    .o_axi_st_tx_tdata		(axis_rx_tdata_mltstrm),
	    .o_axi_st_tx_tvalid		(axis_rx_tvalid_mltstrm),
	    .o_axi_st_tx_tkeep_seg	(axis_rx_tkeep_seg_mltstrm),
	    .o_axi_st_tx_tlast_seg	(axis_rx_tlast_seg_mltstrm),	
	    .o_axi_st_tx_tuser		(axis_rx_tuser_mltstrm)	     
	   	);

	end
	endgenerate
		

/*
	generate if (PREAMBLE_PASS_TH_EN)
	begin : PREAMBLE_PASS_THROUGH_TX
		preamble_pass_through_tx #(
			.TDATA      	    (DATA_WIDTH),
			.NO_OF_BYTES  	    (NO_OF_BYTES),
			.TUSER  		    (TUSER_WIDTH_TX),
			.READY_LATENCY  (ST_READY_LATENCY),
			.PKT_SEG_PARITY_EN  (PKT_SEG_PARITY_EN)
		)preamble_pass_through_rx_inst(
			.i_tx_clk 					    (i_clk_rx),
			.i_tx_reset_n               (rx_aresetn),
			.i_axist_tx_ready           (1'b1), 
			.i_axist_tx_tvalid          (axis_tvalid_i),      
			.i_axist_tx_tdata           (axis_tdata_i), //preamble of 8B is a part of tdata      
			.i_axist_tx_tlast           (axis_tlast_i),       
			.i_axist_tx_tkeep           (axis_tkeep_i),       
			.i_axist_tx_tuser           ({axis_rx_ptp_its_p2,axis_rx_ptp_its, axis_tuser_client_i, axis_tuser_sts, axis_tuser_sts_ext}),          
			.i_axist_tx_pkt_seg_parity  (axis_rx_pkt_seg_parity_i ),//TODO:i_axi_st_rx_pkt_seg_parity
			.o_axist_tx_tready          (axist_rx_tready_ppt), //TODO check with Dinker
			.o_axist_tx_tvalid          (axi_valid_ppt),
			.o_axist_tx_tdata           (axis_tdata_ppt), //only tdata
			.o_axist_tx_tkeep           (axis_tkeep_ppt),
			.o_axist_tx_tlast           (axis_tlast_ppt),
			.o_axist_tx_tuser           (axist_rx_tuser_ppt),
//			.o_axist_tx_pkt_seg_parity  (axist_tx_pkt_seg_parity_ppt_tx),
			.o_tx_preamble              (axis_rx_preamble_ppt)   //only preamble of 8B
		);
	end
	endgenerate
*/
//-
	ed_axist_to_avst_tx_mac_seg_if #(	
		.SIM_EMULATE   		 (SIM_EMULATE),	
		.AVST_MODE   		   (AVST_MODE),
		.AVST_DW      	      (DW_AVST_DW), 
		.EMPTY_BITS    	   (EMPTY_BITS), //EWIDTH
		.AVST_USER  	 	   (USER_WIDTH_TX),
		.AXIST_MODE				 (AXIST_MODE),
		.AXI_DW      	     (DW_AVST_DW), 
		.NO_OF_BYTES  		 (BW_AVST_BW),
		.TUSER  		       (TUSER_WIDTH_TX),
		.NUM_SEG           (NUM_SEG), 
		.READY_LATENCY     (1),
      .ENABLE_ECC        (0),
		.PKT_SEG_PARITY_EN (PKT_SEG_PARITY_EN)//,
      //.PREAMBLE_PASS_TH_EN    (PREAMBLE_PASS_TH_EN)
//    .NUM_MAX_PORTS  (NUM_MAX_PORTS),
//	.PKT_SEG_PARITY_WIDTH (PKT_SEG_PARITY_WIDTH),
//		.DR_ENABLE						(DR_ENABLE)


			) U_ed_axist_to_avst_rx_mac_seg_if_inst (
		.i_tx_clk 					     (i_clk_rx),
		.i_tx_reset_n                (rx_aresetn),
		.o_axist_tx_tready           (axis_tready_o),
//o_axi_st_rx_tvalid				<= (PREAMBLE_PASS_TH_EN)? axist_rx_tvalid_ppt_rx : ((ENABLE_MULTI_STREAM)? axist_rx_tvalid_mltstrm : axist_rx_tvalid);

		.i_axist_tx_tvalid           ((ENABLE_MULTI_STREAM)? axis_rx_tvalid_mltstrm : axis_tvalid_i[0]),
		.i_axist_tx_tdata            ((ENABLE_MULTI_STREAM)? axis_rx_tdata_mltstrm  : axis_tdata_i[0]),
		.i_axist_tx_tlast            (axis_tlast_i[0]),
		.i_axist_tx_tkeep            (axis_tkeep_i[0]),
		.i_axist_tx_tlast_segment    ((ENABLE_MULTI_STREAM)? axis_rx_tlast_seg_mltstrm  : axis_tuser_last_seg),
		.i_axist_tx_tkeep_segment    ((ENABLE_MULTI_STREAM)? axis_rx_tkeep_seg_mltstrm  : axis_tkeep_seg_i),
		.i_axist_tx_tuser     		  ((ENABLE_MULTI_STREAM)? axis_rx_tuser_mltstrm  :{axis_rx_ptp_its_p2[0],axis_rx_ptp_its[0], axis_tuser_client_i[0], axis_tuser_sts[0], axis_tuser_sts_ext[0]}), //TODO:96+RX_TUSER_CLIENT_WIDTH+32 
  	    //.i_axist_tx_preamble         (64'h0),
	
    //added for seg_parity 30 Sept checkp
    .i_axist_tx_pkt_seg_parity   (axis_rx_pkt_seg_parity_i), 


		.i_avst_tx_ready             (1'b1),           
		//.i_avst_tx_ready             ((AVST_MODE == "MAC_SEGMENTED") ? axis_tvalid_i : 1'b1),           
                                                                  
		.o_avst_tx_data              (avst_rx_data),
	  //.o_avst_tx_valid             (avst_rx_valid),
		.o_avst_tx_valid_pkt_client  (avst_rx_valid_pkt_client),  ///for ed pkt client only
		.o_avst_tx_inframe           (o_av_st_rx_ms_inframe),
		.o_avst_tx_eop_empty         (avst_rx_empty),
		.o_avst_tx_startofpacket	  (avst_sop_o),
		.o_avst_tx_endofpacket	     (avst_eop_o), 		
		.o_avst_tx_user          	  (o_av_st_rx_user),    //TODO:{}
//added on oct17
     //.o_avst_tx_preamble           (avst_preamble_o),
    
    //.i_active_ports                  (i_active_ports),	
    //.i_active_segments               (i_active_segments),	
		//.i_port_active_mask 						(i_port_active_mask), 
		//.i_port_data_width  						(i_port_data_width),

 
 		.o_axist_tx_parity_error(), //To CSR status reg
    .o_fifo_eccstatus()

	);
//o_av_st_tx_ms_eop_empty
assign o_av_st_rx_ms_data      = (AVST_MODE == "MAC_SEGMENTED") ? avst_rx_data  :'d0;
assign o_av_st_rx_ms_valid     = (AVST_MODE == "MAC_SEGMENTED") ? avst_rx_valid_pkt_client :'d0;
assign o_av_st_rx_ms_eop_empty = (AVST_MODE == "MAC_SEGMENTED") ? avst_rx_empty :'d0;
assign avst_data_o         	 = (AVST_MODE == "SOP_ALIGNED")   ? avst_rx_data  :'d0;
assign avst_valid_o        	 = (AVST_MODE == "SOP_ALIGNED")   ? avst_rx_valid_pkt_client :'d0;
assign avst_empty_o         	 = (AVST_MODE == "SOP_ALIGNED")   ? avst_rx_empty :'d0;
assign o_rx_ptp_its            = o_av_st_rx_user[96+96+RX_TUSER_CLIENT_WIDTH+RX_TUSER_STATS_WIDTH+32-1: RX_TUSER_CLIENT_WIDTH+RX_TUSER_STATS_WIDTH+32];
	
endmodule

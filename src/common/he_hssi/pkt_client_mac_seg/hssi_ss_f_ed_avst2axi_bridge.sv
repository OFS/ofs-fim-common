// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on


module hssi_ss_f_ed_avst2axi_bridge #(
   parameter   EHIP_RATE      = "10G",
   parameter   EMPTY_BITS	 	 	  = 3,    //depends datawidth
	parameter   CLIENT_IF_TYPE	  = 0, 
   parameter   DATA_WIDTH     	  = 64, 
	parameter   NO_OF_BYTES 		  = (CLIENT_IF_TYPE == 1)? DATA_WIDTH/8:8,  
   parameter 	PKT_SEG_PARITY_EN = 0,	
   parameter   SIM_EMULATE 		  = 0,
	parameter 	AVST_MODE				  = (CLIENT_IF_TYPE == 0)? "MAC_SEGMENTED" : "SOP_ALIGNED",
	parameter 	AXIST_MODE			  = (CLIENT_IF_TYPE == 0)? "MULTI_PACKET" : "SINGLE_PACKET",
   parameter 	ENABLE_MULTI_STREAM = 0,	
   parameter 	NUM_OF_STREAM       = 1,	
	parameter 	NUM_SEG				  = (CLIENT_IF_TYPE == 1)? 1: (DATA_WIDTH/64),
   parameter   ST_READY_LATENCY  = 0,
   parameter   CLIENT_WIDTH      = 2 ,   

   parameter   PKT_CYL           =  (EHIP_RATE == "400G") ? 2 : 1,
	 parameter PTP_FP_WIDTH       = 8,  
   parameter   PREAMBLE_PASS_TH_EN			 = 0,
   parameter PORT_PROFILE         = "10GbE",
   //parameter   DW_AVST_DW        = (PREAMBLE_PASS_TH_EN)? DATA_WIDTH/2: DATA_WIDTH, //commented on FEb1 
   //parameter   BW_AVST_BW		   = (PREAMBLE_PASS_TH_EN) ? NO_OF_BYTES/2 : NO_OF_BYTES, //commented on Feb1
   parameter   DW_AVST_DW        = DATA_WIDTH, 
   parameter   BW_AVST_BW		   = NO_OF_BYTES,
   parameter TID                 = 8, 
		parameter PKT_SEG_PARITY_WIDTH = 4,
  	//parameter                 TDATA_WIDTH 		    = 64,   //from AXI side
	parameter	NUM_MAX_PORTS				= 1,
	 	parameter	DR_ENABLE	 						= 0
	


) (
  input                       				 i_clk_tx,
  input                       				 i_tx_reset_n,
  input                       				 tx_error_i,
  input                       				 tx_skip_crc_i,
  input    [PKT_CYL*PTP_FP_WIDTH-1:0]      ptp_fp_i,        //TODO:width
  input    [PKT_CYL*1  -1:0]               ptp_ins_ets_i,
  input    [PKT_CYL*1  -1:0]               ptp_ts_req_i,  //TODO:width
  input    [PKT_CYL*96 -1:0]  			 	 ptp_tx_its_i,
  input    [PKT_CYL*1  -1:0]           	 ptp_ins_cf_i,
  input    [PKT_CYL*1  -1:0]           	 ptp_ins_zero_csum_i,
  input    [PKT_CYL*1  -1:0]           	 ptp_ins_update_eb_i,
  input    [PKT_CYL*1  -1:0]           	 ptp_ins_ts_format_i,
  input    [PKT_CYL*16 -1:0]   				 ptp_ins_ts_offset_i, //TODO::change width  
  input    [PKT_CYL*16 -1:0]   				 ptp_ins_cf_offset_i, //TODO::change width 
  input    [PKT_CYL*16 -1:0]   				 ptp_ins_csum_offset_i,//TODO::change width 
  input    [PKT_CYL*16 -1:0]  				 ptp_ins_eb_offset_i,  //TODO::change width 
 //CSR
    input      [NUM_MAX_PORTS-1:0]            i_port_active_mask,       //current profile parameters based on profile_sel_reg
    input      [2:0]                          i_active_ports,           //current profile parameters based on profile_sel_reg 
    input      [2:0]                          i_active_segments,        //current profile parameters based on profile_sel_reg - valid for mac seg only
    input      [2:0]                          i_port_data_width,        //current profile parameters based on profile_sel_reg - valid for sopa only
        
  // axi-s interface
  output [NUM_OF_STREAM-1:0]                     	   axis_tvalid_o,
  output [NUM_OF_STREAM-1:0][DATA_WIDTH-1:0]          axis_tdata_o,
  input  [NUM_OF_STREAM-1:0]                    		axis_tready_i, //TODO:Check Width
  output [NUM_OF_STREAM-1:0][DATA_WIDTH/8-1:0]   		axis_tkeep_o, 
  output [NUM_OF_STREAM-1:0]                    	   axis_tlast_o,
  output [NUM_OF_STREAM-1:0][TID-1:0]                 axis_tid_o,

//TODO:check it's per stream or common for all streams
  output [NUM_OF_STREAM-1:0][CLIENT_WIDTH-1:0]   		axis_tuser_client_o,  
  output [NUM_OF_STREAM-1:0][93:0]  						axis_tuser_ptp_o,
  output [NUM_OF_STREAM-1:0][327:0]  					   axis_tuser_ptp_ext_o,
  //AXI MAC Seg
  output  [NUM_SEG-1:0]			                        axis_tuser_last_seg_o,   
  output  [NUM_SEG-1:0]                               axis_tuser_pkt_seg_parity_o,     
	
 
  // avalon-st interface   outputs from packet_client_top Module
  //input    [63:0]                         avst_preamble_i, //commented on Feb1
  input                       				avst_valid_i,
  input    [DW_AVST_DW-1:0]   				avst_data_i,
  input    [EMPTY_BITS-1:0]  				   avst_empty_i,
  input                       				avst_sop_i,
  input                       				avst_eop_i,
  output   reg                  			   avst_ready_o,
	 
  //---Segmented  IF---  
	output logic                 			 	 o_tx_mac_ready,
  input  logic                 			 	 i_tx_mac_valid,
  input  logic [NUM_SEG-1:0]   			 	 i_tx_mac_inframe,
  input  logic [NUM_SEG*3-1:0] 			 	 i_tx_mac_eop_empty,
  input  logic [NUM_SEG*64-1:0]			 	 i_tx_mac_data,
  input  logic [NUM_SEG-1:0]   			 	 i_tx_mac_error, 
  input  logic [NUM_SEG-1:0]   			 	 i_tx_mac_skip_crc 
);

  localparam AVST_AXI_DLY = 2; 
  localparam FIFO_DEPTH   = 4;
  localparam AVST_USER    = CLIENT_WIDTH + 328 + 94; //preamble 8B  
  //localparam PRMBLE_WIDTH =  (PREAEN) ? 64 : 0; //TODO:check 0 or 1 commented on Feb1
 localparam FIFO_WIDTH   =  (ENABLE_MULTI_STREAM)?(NUM_OF_STREAM*(8+3+NO_OF_BYTES+AVST_USER+DATA_WIDTH)):(2+NUM_SEG+NO_OF_BYTES+NUM_SEG+DATA_WIDTH+AVST_USER);

  wire [CLIENT_WIDTH-1:0]        avst_tuser_client;
  wire [93:0]  						avst_tuser_ptp;
  wire [327:0] 					   avst_tuser_ptp_ext;
  wire [CLIENT_WIDTH-1:0]  	   axis_tuser_client;
  wire [93:0]  					   axis_tuser_ptp;
  wire [327:0]  				      axis_tuser_ptp_ext;
  wire                      		axis_tvalid;
	wire [DW_AVST_DW-1:0]     		axis_tdata;
	wire                      		axis_tlast;  
	wire [NUM_SEG-1:0]	 			axis_tuser_last_seg;   
  wire [BW_AVST_BW-1:0]          axis_tuser_keep;
  wire [NUM_SEG*8-1:0]           axis_tuser_keep_seg;

  logic [NUM_SEG-1:0]            axis_tuser_pkt_seg_parity;

  //wire [63:0]                    axis_preamble; 
  wire	[FIFO_WIDTH-1:0]		 	fifo_data_in; 
  wire	[FIFO_WIDTH-1:0]		 	fifo_data_out; 
  wire	[FIFO_DEPTH-1:0]		 	avst_tx_fifo_lvl;
  wire 		                   	avst_ready_dly;
  wire 		                   	axis_tready_dly;
  wire                           fifo_empty;
  wire                           tx_reset_n_sync;
  reg                            avst_valid_gate_temp;
  wire                           avst_valid_gate;


/* commented onnFeb1
logic 						 axist_tx_tready_ppt; //TODO
logic 						 axist_tx_tvalid_ppt;
logic [DATA_WIDTH-1:0]	 axist_tx_tdata_ppt;
logic [NO_OF_BYTES-1:0]  axist_tx_tkeep_ppt;
logic 						 axist_tx_tlast_ppt;
//logic [AVST_USER-1:0]					 axist_tx_tuser_ppt;//TODO check widths
logic						    axist_tx_tuser_valid_ppt;
logic                    axist_tx_pkt_seg_parity_ppt;

*/

logic	[327:0]             axis_tuser_ptp_ext_ppt;
logic [93:0]          	  axis_tuser_ptp_ppt; 
logic	[CLIENT_WIDTH-1:0]  axis_tuser_client_ppt;

logic [NUM_OF_STREAM-1:0]						   	   axis_tx_tvalid_mltstrm;
logic	[NUM_OF_STREAM-1:0][DATA_WIDTH-1:0]	      axis_tx_tdata_mltstrm; //TODO:check widths
logic	[NUM_OF_STREAM-1:0][DATA_WIDTH/8-1:0]	axis_tx_tkeep_mltstrm;
logic	[NUM_OF_STREAM-1:0]						axis_tx_tlast_mltstrm;
logic	[NUM_OF_STREAM-1:0]						axis_tuser_pkt_seg_parity_mltstrm;
logic	[NUM_OF_STREAM-1:0][8-1:0]					      axis_tx_tid_mltstrm;
logic [NUM_OF_STREAM-1:0][327:0]            			axis_tuser_ptp_ext_mltstrm;
logic [NUM_OF_STREAM-1:0][93:0]          	  			axis_tuser_ptp_mltstrm;
logic [NUM_OF_STREAM-1:0][CLIENT_WIDTH-1:0] 			axis_tuser_client_mltstrm;
//logic	[NUM_OF_STREAM-1:0][AVST_USER-1:0]		      axis_tx_tuser_mltstrm;


//----------------------------------------
// output logic
//----------------------------------------

  assign avst_tuser_client 					= (AVST_MODE == "MAC_SEGMENTED") ? {i_tx_mac_skip_crc, i_tx_mac_error} : {tx_skip_crc_i,tx_error_i};

generate 
if(EHIP_RATE == "400G") begin 
//400G 
     assign avst_tuser_ptp[47:0]    	= {2'b0,24'b0,ptp_fp_i[7:0], 10'b0,ptp_ins_ets_i[0],ptp_ts_req_i[0],1'b0,1'b0};
     assign avst_tuser_ptp[93:48]    	= {2'b0,24'b0,ptp_fp_i[15:8],10'b0,ptp_ins_ets_i[1],ptp_ts_req_i[1]};
	// assign avst_tuser_ptp    		= {46'b0,2'b0,24'b0,ptp_fp_i,10'b0,ptp_ins_ets_i,ptp_ts_req_i,1'b0,1'b0};//CHECK FOR 400G

  	 assign avst_tuser_ptp_ext[163:0]	= {ptp_ins_ts_offset_i[15:0],ptp_ins_cf_offset_i[15:0],ptp_ins_csum_offset_i[15:0],ptp_ins_eb_offset_i[15:0],ptp_ins_zero_csum_i[0],ptp_ins_update_eb_i[0],ptp_ins_ts_format_i[0],ptp_tx_its_i[95:0],ptp_ins_cf_i[0]};
    assign avst_tuser_ptp_ext[327:164]	= {ptp_ins_ts_offset_i[31:16],ptp_ins_cf_offset_i[31:16],ptp_ins_csum_offset_i[31:16],ptp_ins_eb_offset_i[31:16],ptp_ins_zero_csum_i[1],ptp_ins_update_eb_i[1],ptp_ins_ts_format_i[1],ptp_tx_its_i[191:96],ptp_ins_cf_i[1]};

//other than 400G rates
end else 
begin    
  assign avst_tuser_ptp    					= {46'b0,2'b0,24'b0,ptp_fp_i,10'b0,ptp_ins_ets_i,ptp_ts_req_i,1'b0,1'b0};
  assign avst_tuser_ptp_ext[193:0]	= {30'b0,ptp_ins_ts_offset_i,ptp_ins_cf_offset_i,ptp_ins_csum_offset_i,ptp_ins_eb_offset_i,ptp_ins_zero_csum_i,ptp_ins_update_eb_i,ptp_ins_ts_format_i,ptp_tx_its_i,ptp_ins_cf_i};
  assign avst_tuser_ptp_ext[327:194]= '0;
end
endgenerate


always @(posedge i_clk_tx or negedge i_tx_reset_n)
begin
	if(~i_tx_reset_n)
		avst_ready_o <= 1'b0;           
	else if(axis_tready_dly)            
	  avst_ready_o <= 1'b1;
	else if(avst_tx_fifo_lvl >= 'd8)  //Should be based on ready latency and based on tx bridge delay and fifo delays
		avst_ready_o <= 1'b0;
end

assign o_tx_mac_ready = avst_ready_o; 


hssi_ss_delay_reg #(
    .CYCLES (AVST_AXI_DLY),        //AVST_AXI_DLY = 2 , if Latency number increases then add READY_LATENCY+clkcyles   
    .WIDTH  (1)
) i_avst_ready_latency_delay_reg (
    .clk    (i_clk_tx),
    .din    (avst_ready_o),				
    .dout   (avst_ready_dly)      
    );

    wire pkt_64;
    reg pkt_64_avst_valid_gate;
    
	
always @(posedge i_clk_tx or negedge i_tx_reset_n)
begin
  if(~i_tx_reset_n)
    avst_valid_gate_temp <= 1'b0;
  else if(avst_sop_i)
    if (avst_eop_i)
       pkt_64_avst_valid_gate <= 1'b1;
    else begin
       pkt_64_avst_valid_gate <= 1'b0;
    avst_valid_gate_temp <= 1'b1;
    end
  else if(avst_eop_i)
    avst_valid_gate_temp <= 1'b0;
 
end

//assign avst_valid_gate = avst_valid_gate_temp | avst_sop_i;
assign avst_valid_gate = avst_valid_gate_temp | avst_sop_i;
assign pkt_64 = pkt_64_avst_valid_gate | avst_sop_i;


//--------------------------------------------------------------------------------------------------
//  AVST to AXI ST conversion for MAC segmented, SOP aligned
//--------------------------------------------------------------------------------------------------
//---------------------------------------------------------------
	ed_avst_to_axist_rx_mac_seg_if #(
		.SIM_EMULATE   	(SIM_EMULATE),
		.AVST_MODE   		(AVST_MODE),
		.AVST_DW      	   (DW_AVST_DW),
		.EMPTY_BITS    	(EMPTY_BITS),
		.AVST_USER  	 	(AVST_USER),   //328 + 94 + CLIENT_WIDTH
		.AXI_DW      	   (DW_AVST_DW),                
		.NO_OF_BYTES  	   (BW_AVST_BW),                
		.TUSER  				(AVST_USER),   //328 + 94 + CLIENT_WIDTH
		.NUM_SEG          (NUM_SEG),								    
     //AXI_MODE         (),
      .PORT_PROFILE     (PORT_PROFILE),//Ed gives EHIP rates as 400GbE but RTL provide 400GAUI-4?????								    
		.PKT_SEG_PARITY_EN(PKT_SEG_PARITY_EN)//,
    //.NUM_MAX_PORTS  (NUM_MAX_PORTS),
		//.PKT_SEG_PARITY_WIDTH (PKT_SEG_PARITY_WIDTH),
		//.DR_ENABLE						(DR_ENABLE)
	) U_ed_avst_to_axist_tx_mac_seg_if_inst (
		.i_rx_clk 					 	       (i_clk_tx ),			
		.i_rx_reset_n                (i_tx_reset_n),
		.i_avst_rx_valid             ((AVST_MODE == "MAC_SEGMENTED") ? i_tx_mac_valid : ((pkt_64)?avst_sop_i:(avst_valid_i && avst_valid_gate))),
		.i_avst_rx_data              ((AVST_MODE == "MAC_SEGMENTED") ? i_tx_mac_data  : avst_data_i),
		.i_avst_rx_inframe           ((AVST_MODE == "MAC_SEGMENTED") ? i_tx_mac_inframe : 1'b0),
		.i_avst_rx_eop_empty         ((AVST_MODE == "MAC_SEGMENTED") ? i_tx_mac_eop_empty : avst_empty_i),
		.i_avst_rx_user         	  ({avst_tuser_ptp_ext, avst_tuser_ptp, avst_tuser_client}),
		.i_avst_rx_startofpacket     ((AVST_MODE == "MAC_SEGMENTED") ? 1'b0: avst_sop_i),
		.i_avst_rx_endofpacket       ((AVST_MODE == "MAC_SEGMENTED") ? 1'b0: avst_eop_i),
      
      //.i_avst_rx_preamble          (avst_preamble_i),        
		.o_axist_rx_tvalid           (axis_tvalid),
		.o_axist_rx_tdata            (axis_tdata),
		.o_axist_rx_tlast            (axis_tlast), 
		.o_axist_rx_tlast_segment    (axis_tuser_last_seg),
      .o_axist_rx_tkeep            (axis_tuser_keep),
		.o_axist_rx_tkeep_segment    (axis_tuser_keep_seg),
		.o_axist_rx_tuser        	  ({axis_tuser_ptp_ext, axis_tuser_ptp, axis_tuser_client}),
     
      //.o_axist_rx_preamble         (axis_preamble),

      .o_axist_rx_pkt_seg_parity  (axis_tuser_pkt_seg_parity)//,
    //.i_active_ports               (i_active_ports),
    //.i_active_segments               (i_active_segments),
		//.i_port_active_mask 						(i_port_active_mask), 
		//.i_port_data_width  						(i_port_data_width)

	
	);


wire [BW_AVST_BW-1:0]	axis_tkeep_common;
assign axis_tkeep_common = (AVST_MODE == "MAC_SEGMENTED") ? axis_tuser_keep_seg : axis_tuser_keep;

//----------------------------------------------------------------------------

generate if ((ENABLE_MULTI_STREAM) && (CLIENT_IF_TYPE == 0))
begin : MULTI_STREAM
	hssi_ss_multi_stream_rx_top #(
		 .DATA_WIDTH			(DATA_WIDTH),     	    
	    .NUM_SEG            (NUM_SEG),  
	    .TDATA_WIDTH      	(DW_AVST_DW),  //TODO: CHECK WIDTHS 
	    .NO_OF_BYTES  		(NO_OF_BYTES),	
	    //.TUSER_WIDTH_TX  	(TUSER_WIDTH_TX), 	
	    .TUSER_WIDTH_RX  	(AVST_USER), //TODO:check widths	
	    .ST_READY_LATENCY   (ST_READY_LATENCY),  
	    .TID   				   (TID),
	    //.ENABLE_ECC  	  	   (ENABLE_ECC),	
	    //.USE_M20K			   (USE_M20K), 	
	    .PORT_PROFILE   	 	(EHIP_RATE),
	    .NUM_OF_STREAM   	(NUM_OF_STREAM)
		
	)hssi_ss_multi_stream_top_tx_inst(
		 .i_rx_clk				   (i_clk_tx), 
	    .i_rx_reset_n			   (i_tx_reset_n),	   
	        
	    .i_axi_st_rx_tvalid		(axis_tvalid), 
	    .i_axi_st_rx_tdata		(axis_tdata),  
	    .i_axi_st_rx_tlast_seg	(axis_tuser_last_seg),  
	    .i_axi_st_rx_tkeep_seg	(axis_tuser_keep_seg),  
	    .i_axi_st_rx_tuser		({axis_tuser_ptp_ext, axis_tuser_ptp, axis_tuser_client}),       
	    .o_axi_st_rx_tvalid		(axis_tx_tvalid_mltstrm),
	    .o_axi_st_rx_tdata		(axis_tx_tdata_mltstrm),
	    .o_axi_st_rx_tkeep		(axis_tx_tkeep_mltstrm),
	    .o_axi_st_rx_tlast		(axis_tx_tlast_mltstrm),
	    .o_axi_st_rx_tuser     ({axis_tuser_ptp_ext_mltstrm, axis_tuser_ptp_mltstrm, axis_tuser_client_mltstrm}),
	    .o_axi_st_rx_tid       (axis_tx_tid_mltstrm)   //TODO: check why TID
	);

end
endgenerate
		
logic dummy_read;

/*
generate if (PREAMBLE_PASS_TH_EN)
begin : PREAMBLE_PASS_THROUGH_RX
	preamble_pass_through_rx #(
		.TDATA      	     (DATA_WIDTH),
		.NO_OF_BYTES  	     (NO_OF_BYTES),
      .TUSER  		    	  (AVST_USER ), 
		.PKT_SEG_PARITY_EN  (PKT_SEG_PARITY_EN)
	)preamble_pass_through_tx_inst(
		.i_rx_clk 					     (i_clk_tx), 
	    .i_rx_reset_n               (i_tx_reset_n),
	    .i_axist_rx_ready           (1'b1),
	    .i_axist_rx_tvalid          (axis_tvalid),      
	    .i_axist_rx_tdata           (axis_tdata),           //only tdata without preamble  
	    .i_axist_rx_tlast           (axis_tlast),       
	    .i_axist_rx_tkeep           (axis_tuser_keep),       
	    .i_axist_rx_tuser           ({axis_tuser_ptp_ext, axis_tuser_ptp, axis_tuser_client}),
		 .i_axist_rx_tuser_valid     (1'b0), 
	    .i_rx_preamble              (axis_preamble),       //only preamble without tdata

	    .o_axist_rx_tready          (axist_tx_tready_ppt), 
	    .o_axist_rx_tvalid          (axist_tx_tvalid_ppt),
	    .o_axist_rx_tdata           (axist_tx_tdata_ppt),  //preamble is a part of tdata
	    .o_axist_rx_tkeep           (axist_tx_tkeep_ppt),
	    .o_axist_rx_tlast           (axist_tx_tlast_ppt),
	    .o_axist_rx_tuser           ({axis_tuser_ptp_ext_ppt, axis_tuser_ptp_ppt, axis_tuser_client_ppt}),
	    .o_axist_rx_tuser_valid     (axist_tx_tuser_valid_ppt),
	    .o_axist_rx_pkt_seg_parity  (axist_tx_pkt_seg_parity_ppt)
	);
end
endgenerate

*/

//NOV28New MUXING Logic between Bridge and Preamble Module and Multistream top 
generate if(ENABLE_MULTI_STREAM) 
begin
	assign  fifo_data_in[NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94+328+NO_OF_BYTES+3+8)-1:NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94+328+NO_OF_BYTES+3)]  =  axis_tx_tid_mltstrm;
	assign  fifo_data_in[NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94+328+NO_OF_BYTES+3)-1:NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94+328+NO_OF_BYTES+2)]  =  axis_tx_tvalid_mltstrm;
	assign  fifo_data_in[NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94+328+NO_OF_BYTES+2)-1:NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94+328+NO_OF_BYTES+1)]  =  axis_tx_tlast_mltstrm;
	assign  fifo_data_in[NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94+328+NO_OF_BYTES+1)-1:NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94+328+NO_OF_BYTES)]  =  axis_tuser_pkt_seg_parity_mltstrm;
	assign  fifo_data_in[NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94+328+NO_OF_BYTES)-1:NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94+328)] =  axis_tx_tkeep_mltstrm;
	assign  fifo_data_in[NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94+328)-1:NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94)] =  axis_tuser_ptp_ext_mltstrm;
	assign  fifo_data_in[NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94)-1:NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH)]  =  axis_tuser_ptp_mltstrm;
	assign  fifo_data_in[NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH)-1:(NUM_OF_STREAM*DATA_WIDTH)]                   =  axis_tuser_client_mltstrm;
	assign  fifo_data_in[NUM_OF_STREAM*DATA_WIDTH-1:0] =  axis_tx_tdata_mltstrm;

	//o/p's of avst2axi connected to hssi_ss_f_packet_client_top.sv o/p to DUT i/p
	
	assign axis_tid_o  			   	   =   fifo_data_out[NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94+328+NO_OF_BYTES+3+8)-1:NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94+328+NO_OF_BYTES+3)];
	assign axis_tvalid_o  			   =   fifo_data_out[NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94+328+NO_OF_BYTES+3)-1:NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94+328+NO_OF_BYTES+2)];
	assign axis_tlast_o  		  	   =   fifo_data_out[NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94+328+NO_OF_BYTES+2)-1:NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94+328+NO_OF_BYTES+1)];
	
	assign axis_tuser_pkt_seg_parity_o =  fifo_data_out[NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94+328+NO_OF_BYTES+1)-1:NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94+328+NO_OF_BYTES)];
	assign axis_tuser_last_seg_o   =   {NUM_SEG{1'b0}};
	assign axis_tkeep_o            =   fifo_data_out[NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94+328+NO_OF_BYTES)-1:NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94+328)];
	
	//assign axis_preamble_o       =   fifo_data_out[(DATA_WIDTH)+(CLIENT_WIDTH)+94+328-1:(DATA_WIDTH)+(CLIENT_WIDTH)+94+328];
	assign axis_tuser_ptp_ext_o  	 =   fifo_data_out[NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94+328)-1:NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94)];
	assign axis_tuser_ptp_o  		 =   fifo_data_out[NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH+94)-1:NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH)];
	assign axis_tuser_client_o  	 =   fifo_data_out[NUM_OF_STREAM*(DATA_WIDTH+CLIENT_WIDTH)-1:(NUM_OF_STREAM*DATA_WIDTH)];
	assign axis_tdata_o  			 =   fifo_data_out[NUM_OF_STREAM*DATA_WIDTH-1:0];
end

else begin
assign  fifo_data_in[FIFO_WIDTH-1]       =   axis_tvalid;
assign  fifo_data_in[FIFO_WIDTH-2]       =   axis_tlast;

assign  fifo_data_in[(DATA_WIDTH)+(CLIENT_WIDTH)+94+328+(NO_OF_BYTES)+NUM_SEG+NUM_SEG-1:(DATA_WIDTH)+(CLIENT_WIDTH)+94+328+(NO_OF_BYTES)+NUM_SEG]       =  axis_tuser_pkt_seg_parity;
assign  fifo_data_in[(DATA_WIDTH)+(CLIENT_WIDTH)+94+328+(NO_OF_BYTES)+NUM_SEG-1:(DATA_WIDTH)+(CLIENT_WIDTH)+94+328+(NO_OF_BYTES)]   =  axis_tuser_last_seg;
assign  fifo_data_in[(DATA_WIDTH)+(CLIENT_WIDTH)+94+328+(NO_OF_BYTES)-1:(DATA_WIDTH)+(CLIENT_WIDTH)+94+328]         =  axis_tkeep_common;
assign  fifo_data_in[(DATA_WIDTH)+(CLIENT_WIDTH)+94+328-1:(DATA_WIDTH)+(CLIENT_WIDTH)+94]                           =  axis_tuser_ptp_ext;
assign  fifo_data_in[(DATA_WIDTH)+(CLIENT_WIDTH)+94-1:(DATA_WIDTH)+(CLIENT_WIDTH)]                                  =  axis_tuser_ptp;
assign  fifo_data_in[(DATA_WIDTH)+(CLIENT_WIDTH)-1:(DATA_WIDTH)]                                                    =  axis_tuser_client;
assign  fifo_data_in[(DATA_WIDTH)-1:0]                                                                              =  axis_tdata;


//o/p's of avst2axi connected to hssi_ss_f_packet_client_top.sv o/p to DUT i/p

assign axis_tvalid_o  			   =        ( dummy_read==1) ?  fifo_data_out[FIFO_WIDTH-1] : 'h0;
assign axis_tlast_o  		  	   =        ( dummy_read==1) ?  fifo_data_out[FIFO_WIDTH-2] : 'h0;
assign axis_tuser_pkt_seg_parity_o =    ( dummy_read==1) ?  fifo_data_out[(DATA_WIDTH)+(CLIENT_WIDTH)+94+328+(NO_OF_BYTES)+NUM_SEG+NUM_SEG-1:(DATA_WIDTH)+(CLIENT_WIDTH)+94+328+(NO_OF_BYTES)+NUM_SEG]: {NUM_SEG{1'b0}};
assign axis_tuser_last_seg_o   =        ( dummy_read==1) ?  fifo_data_out[(DATA_WIDTH)+(CLIENT_WIDTH)+94+328+(NO_OF_BYTES)+NUM_SEG-1:(DATA_WIDTH)+(CLIENT_WIDTH)+94+328+(NO_OF_BYTES)]: {NUM_SEG{1'b0}};
assign axis_tkeep_o            =        ( dummy_read==1) ?  fifo_data_out[(DATA_WIDTH)+(CLIENT_WIDTH)+94+328+(NO_OF_BYTES)-1:(DATA_WIDTH)+(CLIENT_WIDTH)+94+328]: {(DATA_WIDTH/8){1'h0}};
//assign axis_preamble_o       =   fifo_data_out[(DATA_WIDTH)+(CLIENT_WIDTH)+94+328-1:(DATA_WIDTH)+(CLIENT_WIDTH)+94+328];
assign axis_tuser_ptp_ext_o  	 =        ( dummy_read==1) ?  fifo_data_out[(DATA_WIDTH)+(CLIENT_WIDTH)+94+328-1:(DATA_WIDTH)+(CLIENT_WIDTH)+94]: 'h0;
assign axis_tuser_ptp_o  		 =          ( dummy_read==1) ?  fifo_data_out[(DATA_WIDTH)+(CLIENT_WIDTH)+94-1:(DATA_WIDTH)+(CLIENT_WIDTH)]: {94{1'h0}};
assign axis_tuser_client_o  	 =        ( dummy_read==1) ?  fifo_data_out[(DATA_WIDTH)+(CLIENT_WIDTH)-1:(DATA_WIDTH)]: {CLIENT_WIDTH{1'h0}};
assign axis_tdata_o  			 =            ( dummy_read==1) ?  fifo_data_out[(DATA_WIDTH)-1:0]: {DATA_WIDTH{1'h0}};
end
endgenerate

/* Existing commented on NOV28-------------------------------------------------------------------------- 
//MUXING Logic between Bridge and Preamble Module  //remove and directly assign to Fifo Input

assign  fifo_data_in[FIFO_WIDTH-1]       =  (PREAMBLE_PASS_TH_EN) ? axist_tx_tvalid_ppt : axis_tvalid;
assign  fifo_data_in[FIFO_WIDTH-2]       =  (PREAMBLE_PASS_TH_EN) ? axist_tx_tlast_ppt  : axis_tlast;

assign  fifo_data_in[(DATA_WIDTH)+(CLIENT_WIDTH)+94+328+(NO_OF_BYTES)+NUM_SEG+NUM_SEG-1:(DATA_WIDTH)+(CLIENT_WIDTH)+94+328+(NO_OF_BYTES)+NUM_SEG]       =  axis_tuser_pkt_seg_parity;
assign  fifo_data_in[(DATA_WIDTH)+(CLIENT_WIDTH)+94+328+(NO_OF_BYTES)+NUM_SEG-1:(DATA_WIDTH)+(CLIENT_WIDTH)+94+328+(NO_OF_BYTES)]   =  axis_tuser_last_seg;

assign  fifo_data_in[(DATA_WIDTH)+(CLIENT_WIDTH)+94+328+(NO_OF_BYTES)-1:(DATA_WIDTH)+(CLIENT_WIDTH)+94+328] =  (PREAMBLE_PASS_TH_EN) ? axist_tx_tkeep_ppt : axis_tkeep_common;
//assign  fifo_data_in[(DATA_WIDTH)+(CLIENT_WIDTH)+94+328+PRMBLE_WIDTH-1:(DATA_WIDTH)+(CLIENT_WIDTH)+94+328]                    =  axis_preamble;
assign  fifo_data_in[(DATA_WIDTH)+(CLIENT_WIDTH)+94+328-1:(DATA_WIDTH)+(CLIENT_WIDTH)+94]                           =  (PREAMBLE_PASS_TH_EN) ? axis_tuser_ptp_ext_ppt : axis_tuser_ptp_ext;
assign  fifo_data_in[(DATA_WIDTH)+(CLIENT_WIDTH)+94-1:(DATA_WIDTH)+(CLIENT_WIDTH)]                                  =  (PREAMBLE_PASS_TH_EN) ? axis_tuser_ptp_ppt: axis_tuser_ptp;
assign  fifo_data_in[(DATA_WIDTH)+(CLIENT_WIDTH)-1:(DATA_WIDTH)]                                                    =  (PREAMBLE_PASS_TH_EN) ? axis_tuser_client_ppt : axis_tuser_client;
assign  fifo_data_in[(DATA_WIDTH)-1:0]                                                                              =  (PREAMBLE_PASS_TH_EN) ? axist_tx_tdata_ppt  : axis_tdata;

//o/p's of avst2axi connected to hssi_ss_f_packet_client_top.sv o/p to DUT i/p

assign axis_tvalid_o  			   =   fifo_data_out[FIFO_WIDTH-1];
assign axis_tlast_o  		  	   =   fifo_data_out[FIFO_WIDTH-2];

assign axis_tuser_pkt_seg_parity_o =  fifo_data_out[(DATA_WIDTH)+(CLIENT_WIDTH)+94+328+(NO_OF_BYTES)+NUM_SEG+NUM_SEG-1:(DATA_WIDTH)+(CLIENT_WIDTH)+94+328+(NO_OF_BYTES)+NUM_SEG];
assign axis_tuser_last_seg_o   =   fifo_data_out[(DATA_WIDTH)+(CLIENT_WIDTH)+94+328+(NO_OF_BYTES)+NUM_SEG-1:(DATA_WIDTH)+(CLIENT_WIDTH)+94+328+(NO_OF_BYTES)];
assign axis_tkeep_o            =   fifo_data_out[(DATA_WIDTH)+(CLIENT_WIDTH)+94+328+(NO_OF_BYTES)-1:(DATA_WIDTH)+(CLIENT_WIDTH)+94+328];

//assign axis_preamble_o         =   fifo_data_out[(DATA_WIDTH)+(CLIENT_WIDTH)+94+328-1:(DATA_WIDTH)+(CLIENT_WIDTH)+94+328];
assign axis_tuser_ptp_ext_o  	 =   fifo_data_out[(DATA_WIDTH)+(CLIENT_WIDTH)+94+328-1:(DATA_WIDTH)+(CLIENT_WIDTH)+94];
assign axis_tuser_ptp_o  		 =   fifo_data_out[(DATA_WIDTH)+(CLIENT_WIDTH)+94-1:(DATA_WIDTH)+(CLIENT_WIDTH)];
assign axis_tuser_client_o  	 =   fifo_data_out[(DATA_WIDTH)+(CLIENT_WIDTH)-1:(DATA_WIDTH)];
assign axis_tdata_o  			 =   fifo_data_out[(DATA_WIDTH)-1:0];
*/

eth_f_altera_std_synchronizer_nocut U_sync_tx_reset (
    .clk        (i_clk_tx),
    .reset_n    (1'b1),
    .din        (i_tx_reset_n),  
    .dout       (tx_reset_n_sync)
);
// TODO:Check commented on Dec7 and added below Block
//hssi_ss_delay_reg #(
//    .CYCLES (ST_READY_LATENCY), //hssi ss IP TX ready latency from GUI 
//    .WIDTH  (1)
//) i_axi_st_ready_latency_delay_reg (
//    .clk    (i_clk_tx),
//    .din    (axis_tready_i),				
//    .dout   (axis_tready_dly)      
//    );
//
//generate
//gen_var stream_no;
//  for (stream_no= 0; stream_no < NUM_OF_STREAM;  stream_no =stream_no+1 ) begin
     hssi_ss_delay_reg #(
    .CYCLES (ST_READY_LATENCY), //hssi ss IP TX ready latency from GUI 
    .WIDTH  (1)
) i_axi_st_ready_latency_delay_reg (
    .clk    (i_clk_tx),
    .din    (axis_tready_i[0]),     //stream_no				
    .dout   (axis_tready_dly)     
    );
//end
//always @ (posedge i_clk_tx or negedge i_tx_reset_n) begin
//  if (!i_tx_reset_n) begin
//    dummy_read <= 'h0;
//  end
//  else begin
//    dummy_read <= axis_tready_dly && ~fifo_empty;
//  end
//
//end

assign dummy_read = axis_tready_dly && ~fifo_empty;


scfifo #(
    .enable_ecc             (0),       			  //available in S10 and A10. Agilex?
    .intended_device_family ("AGILEX"), 			//$family for simulation 
    .lpm_numwords           (2**FIFO_DEPTH),
    .lpm_showahead          ("ON"),
    .lpm_type               ("SCFIFO"),
    .lpm_width              (FIFO_WIDTH),    //CLIENT_WIDTH+328+94+DATA_WIDTH+NUM_SEG+1+1+3
    .lpm_widthu             (FIFO_DEPTH),
    .overflow_checking      ("OFF"),
    .underflow_checking     ("OFF"),
    .use_eab                ("OFF")             //use block ram or not
) U_av_st_rdy_lat_fifo (
    .sclr       (~tx_reset_n_sync),
    .data       (fifo_data_in),
    .clock      (i_clk_tx),
    .rdreq      (axis_tready_dly && ~fifo_empty),
    .wrreq      (avst_ready_dly),     
//    .wrreq      (avst_ready_dly && axis_tvalid),     
		.q          (fifo_data_out),      
    .empty      (fifo_empty),
    .usedw      (avst_tx_fifo_lvl)
);

endmodule
//------------------------------------------------------------------------------
//
//
// end avst2axis_bridge.sv
//
//------------------------------------------------------------------------------

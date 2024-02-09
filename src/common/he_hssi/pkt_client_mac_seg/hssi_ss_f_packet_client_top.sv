// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


// ==========================================================================
// Project           : HSSI Subsystem for F-tile 
// Module            : hssi_ss_f_packet_client_top.sv.
// Description       : Wrapper for packet clients, commong for both Simulation and HW design
// Author            : 
// Created           : 
// Description       : This file is the top level wrapper for all the ports with in the subsystem
//                   : this is wrapper of the packet clients
// ==========================================================================

module hssi_ss_f_packet_client_top #(parameter PTP_EN                 = 0,
																		 parameter PTP_ACC_MODE           = 0,
																		 parameter CLIENT_IF_TYPE         = 0, 
																		 parameter EHIP_RATE              = "10G", 
																		 parameter RSFEC_TYPE_GUI         = 0, 
																		 parameter PTP_FP_WIDTH           = 8,  
   																	 parameter EN_10G_ADV_MODE        = 0,
	 																	 parameter EMPTY_WIDTH            = 3, 
	 																	 parameter SIM_MODE               = 0,
	 																	 
																		 parameter DATA_WIDTH      	 	 = 64,
																		 parameter ENABLE_DL_GUI          = 0,
																	    parameter NO_OF_BYTES  			 = ( CLIENT_IF_TYPE == 1) ? DATA_WIDTH/8 : 'd8,  
 																	    parameter NUM_SEG              	 = ( CLIENT_IF_TYPE == 1) ? 'd1 : (DATA_WIDTH/64),  
																		 			parameter	DR_ENABLE	 										= 0,
																		 parameter NUM_MAX_PORTS          				= 1,
 																			parameter PKT_SEG_PARITY_WIDTH					= (CLIENT_IF_TYPE == 1)? NUM_MAX_PORTS: NUM_SEG,	 
 
																		 //TODO
																		 parameter PKT_SEG_PARITY_EN  	 = 0,       
																		 parameter ENABLE_MULTI_STREAM	 = 0,       
																		 parameter NUM_OF_STREAM   		 = 1,
																		 parameter ST_READY_LATENCY       = 0,      
																	    parameter TILES   	 			 	 = "F",    
																		 parameter PKT_ROM_INIT_FILE      = "eth_f_hw_pkt_gen_rom_init.10G_SEG.hex" ,
																		 parameter PKT_ROM_INIT_DATA      = "init_file_data.10G.hex",
																	    parameter PKT_ROM_INIT_CTL       = "init_file_ctrl.10G.hex",
    																 	 parameter TX_TUSER_CLIENT_WIDTH  = 1,
    																	 parameter RX_TUSER_CLIENT_WIDTH  = 1,
    																	 parameter RX_TUSER_STATS_WIDTH   = 1,
                                                       parameter BCM_SIM_ENABLE         = 0,
                                                       parameter PREAMBLE_PASS_TH_EN	 = 0,
                                                       parameter PORT_PROFILE         = "10GbE",
                                                       //parameter DW_AVST_DW             = (PREAMBLE_PASS_TH_EN)? DATA_WIDTH/2: DATA_WIDTH, //commented on Feb1
																		 parameter DW_AVST_DW             = DATA_WIDTH,
                                                       parameter TID                    = 88888888 
 
 
																		 //parameter ENABLE_ECC   		  	  = "TRUE", //comes from tcl ?	
																		// parameter USE_M20K			 		      = "ON"	                      

				

														 )(
	input 											 			i_rst_n,
	input  										   			app_ss_lite_clk,			
	input                        			app_ss_lite_areset_n,
	//input 											 			i_clk_ip_tod,   //TODO:c
  input                        			i_clk_tx,
  input                        			i_clk_rx,
  //input                        			tx_aresetn,
  //input                        			rx_aresetn,
	input                             i_clk_pll,
	input                 			 			i_tx_pll_locked,
	input                 			 			i_cdr_lock,

        //CSR
    		input      [NUM_MAX_PORTS-1:0]            i_port_active_mask,       //current profile parameters based on profile_sel_reg
    		input      [2:0]                          i_active_ports,           //current profile parameters based on profile_sel_reg 
    		input      [2:0]                          i_active_segments,        //current profile parameters based on profile_sel_reg - valid for mac seg only
    		input      [2:0]                          i_port_data_width,        //current profile parameters based on profile_sel_reg - valid for sopa only
       

	//output signals from ex_ss  			
/*	
  input [NUM_OF_STREAM-1:0]          					     			i_txegrts0_tvalid,  // ss_app_st_p${port_no}_txegrts0_tvalid;  outputs from dut(ex_ss)
  input [NUM_OF_STREAM-1:0] [103:0] 						   			i_txegrts0_tdata,   // ss_app_st_p${port_no}_txegrts0_tdata;
  input [NUM_OF_STREAM-1:0]        		 					   			i_rxingrts0_tvalid, // ss_app_st_p${port_no}_rxingrts0_tvalid;
  input [NUM_OF_STREAM-1:0] [95:0]  						   			i_rxingrts0_tdata,  // ss_app_st_p${port_no}_rxingrts0_tdata;
	*/

  input         					     			   i_txegrts0_tvalid,  // ss_app_st_p${port_no}_txegrts0_tvalid;  outputs from dut(ex_ss)
  input [103:0] 						   			i_txegrts0_tdata,   // ss_app_st_p${port_no}_txegrts0_tdata;
  input        		 					   		i_rxingrts0_tvalid, // ss_app_st_p${port_no}_rxingrts0_tvalid;
  input [95:0]  						   			i_rxingrts0_tdata,  // ss_app_st_p${port_no}_rxingrts0_tdata;
  input        		 					         i_txegrts1_tvalid,
  input [103:0] 						   		   i_txegrts1_tdata , 	
  input        		 					   		i_rxingrts1_tvalid,
  input [95:0]  						   			i_rxingrts1_tdata, 


  output [NUM_OF_STREAM-1:0]                       		axis_tx_tvalid_o,
  output [NUM_OF_STREAM-1:0]   [DATA_WIDTH-1:0]    		axis_tx_tdata_o,
  input  [NUM_OF_STREAM-1:0]                      			axis_tx_tready_i, //TODO:check Width
  output [NUM_OF_STREAM-1:0] [DATA_WIDTH/8-1:0]   			axis_tx_tkeep_o,
  output [NUM_OF_STREAM-1:0]                      			axis_tx_tlast_o,
  output [NUM_OF_STREAM-1:0][TX_TUSER_CLIENT_WIDTH-1:0]  axis_tx_tuser_client_o,    //outputs from avst2axis_bridge 
  output [NUM_OF_STREAM-1:0][93:0]   							axis_tx_tuser_ptp_o,
  output [NUM_OF_STREAM-1:0][327:0]   							axis_tx_tuser_ptp_ext_o,
  output  [NUM_SEG-1:0]			   							   axis_tx_tuser_last_seg_o,  //TODO:output signal is  connected as input to ex_ss?
  output  [NUM_SEG-1:0]  	          							axis_tx_tuser_pkt_seg_parity_o,


  input  [NUM_OF_STREAM-1:0]                    			axis_rx_tvalid_i,
  input  [NUM_OF_STREAM-1:0][DATA_WIDTH-1:0]   		  		axis_rx_tdata_i,
  output                    				 			 			axis_rx_tready_o,//TODO:Check width 
  input  [NUM_OF_STREAM-1:0][DATA_WIDTH/8-1:0]   			axis_rx_tkeep_i,
  input  [NUM_OF_STREAM-1:0]                     			axis_rx_tlast_i,
  input  [NUM_OF_STREAM-1:0][RX_TUSER_CLIENT_WIDTH-1:0]  axis_rx_tuser_client_i,  //TODO:warning:  
  input  [NUM_OF_STREAM-1:0][RX_TUSER_STATS_WIDTH-1:0]   axis_rx_tuser_sts_i,     //TODO:warning: 94bits 
  input  [NUM_OF_STREAM-1:0][31:0]  							axis_rx_tuser_sts_ext_i, //TODO:warning:328bits   
  input  [NUM_SEG-1:0]        									axis_rx_tuser_last_seg_i, 
  input  [NUM_SEG-1:0]  											axis_rx_tuser_pkt_seg_parity_i,


	

  input                       			i_clk_status,
  input               [22:0]  			i_status_addr,//TODO:chnaged from 16bits to 23bits to remove warning
  input                       			i_status_read,
  input                       			i_status_write,
  input               [31:0]  			i_status_writedata,
  output              [31:0]  			o_status_readdata,
  output                      			o_status_waitrequest,
  output                      			o_status_readdata_valid,

  input  logic                			i_clk_tx_tod,
  input  logic                			i_clk_rx_tod,
  
 //PTP  signals  connected to ex_ss
  output   logic [95:0]      	        ptp_tx_tod,
  output   logic [95:0]      			  ptp_rx_tod,
  output   logic             			  ptp_tx_tod_valid,
  output   logic             			  ptp_rx_tod_valid,

  input  logic               			  i_tx_tod_rst_n,
  input  logic               			  i_rx_tod_rst_n,
  input  logic               			  i_clk_master_tod,
  input  logic               			  i_clk_todsync_sample,
  input  logic               			  i_clk_todsync_sample_locked,
  input  logic               			  i_ptp_master_tod_rst_n,
  input  logic [95:0]        			  i_ptp_master_tod,
  input  logic               			  i_ptp_master_tod_valid,
  //output logic [63:0]        		 	  o_tx_preamble_pc, //TODO: 
  //input  logic [63:0]        			  i_rx_preamble_pc, //TODO:  
  input	 logic [95:0]        		  i_ptp_ip_tod,      
  input  logic               	   	  i_ptp_ip_tod_valid,

	

  output		              tp 

);

//generate
//if (BCM_SIM_ENABLE == 1)
//begin : BCM_SIM
//  localparam PKT_ROM_INIT_FILE = (CLIENT_IF_TYPE == 0 & PTP_EN == 0) ? "eth_f_hw_pkt_gen_rom_init.{EHIP_RATE}_SEG.hex"      : 
//                                 (CLIENT_IF_TYPE == 1 & PTP_EN == 0) ? "eth_f_hw_pkt_gen_rom_init.{EHIP_RATE}_AVST.hex"     : 
//                                 (CLIENT_IF_TYPE == 0 & PTP_EN == 1) ? "eth_f_hw_pkt_gen_rom_init.{EHIP_RATE}_SEG_PTP.hex"  : 
//                                 (CLIENT_IF_TYPE == 1 & PTP_EN == 1) ? "eth_f_hw_pkt_gen_rom_init.{EHIP_RATE}_AVST_PTP.hex" : 
//                                 "eth_f_hw_pkt_gen_rom_init.hex";
//  localparam PKT_ROM_INIT_DATA = "init_file_data.hex" ;     
//  localparam PKT_ROM_INIT_DATA_B = "init_file_data_b.hex";
//  localparam PKT_ROM_INIT_CTL = "init_file_ctrl.hex";
//end
//else 
//begin : NO_BCM

  localparam PKT_CYL = (EHIP_RATE == "400G") ? 2 : 1;
  //localparam PKT_ROM_INIT_FILE = (CLIENT_IF_TYPE == 0 & PTP_EN == 0) ? "../hardware_test_design/common_f/eth_f_hw_pkt_gen_rom_init.{EHIP_RATE}_SEG.hex"      : 
  //                               (CLIENT_IF_TYPE == 1 & PTP_EN == 0) ? "../hardware_test_design/common_f/eth_f_hw_pkt_gen_rom_init.{EHIP_RATE}_AVST.hex"     : 
  //                               (CLIENT_IF_TYPE == 0 & PTP_EN == 1) ? "../hardware_test_design/common_f/eth_f_hw_pkt_gen_rom_init.{EHIP_RATE}_SEG_PTP.hex"  : 
  //                               (CLIENT_IF_TYPE == 1 & PTP_EN == 1) ? "../hardware_test_design/common_f/eth_f_hw_pkt_gen_rom_init.{EHIP_RATE}_AVST_PTP.hex" : 
  //                               "../hardware_test_design/common_f/eth_f_hw_pkt_gen_rom_init.hex";
  //localparam PKT_ROM_INIT_DATA = "../hardware_test_design/common_f/init_file_data.{EHIP_RATE}.hex" ;
   
  localparam PKT_ROM_INIT_DATA_B = (EHIP_RATE == "400G") ? "../hardware_test_design/common_f/init_file_data_b.400G.hex": "../hardware_test_design/common_f/init_file_data_b.hex" ;
  //localparam PKT_ROM_INIT_CTL = "../hardware_test_design/common_f/init_file_ctrl.{EHIP_RATE}.hex";
//end                               
//endgenerate

//---Less entries for higher speed which has larger data width;
localparam LPBK_FIFO_ADDR_WIDTH = (EHIP_RATE == "10G")  ? 10 :
                                  (EHIP_RATE == "25G")  ? 10 :
                                  (EHIP_RATE == "40G")  ? 10 :
                                  (EHIP_RATE == "50G")  ? 10 :
                                  (EHIP_RATE == "100G") ? 8 :
                                  (EHIP_RATE == "200G") ? 8 :
                                  (EHIP_RATE == "400G") ? 8 : 8;

`ifdef ALTERA_RESERVED_QIS
//synthesis mode
localparam AM_INS_PERIOD        = (EHIP_RATE == "25G")                               ? 81920 :
                                  (EHIP_RATE == "40G")                               ? 32768 :
                                  (EHIP_RATE == "50G" && RSFEC_TYPE_GUI == "0")   ? 32768 :
                                  (EHIP_RATE == "50G")                               ? 40960 :
                                  (EHIP_RATE == "100G" && RSFEC_TYPE_GUI == "0")  ? 81920 :
                                  (EHIP_RATE == "100G")                              ? 81920 :
                                  (EHIP_RATE == "200G" || EHIP_RATE == "400G")    ? 40960 : 40960;
`else
//simulation mode
localparam AM_INS_PERIOD        = (EHIP_RATE == "25G")                               ? 1280 :
                                  (EHIP_RATE == "40G")                               ? 128 :
                                  (EHIP_RATE == "50G" && RSFEC_TYPE_GUI == "0")   ? 512 :
                                  (EHIP_RATE == "50G")                               ? 640 :
//                                  (EHIP_RATE == "100G" && RSFEC_TYPE_GUI == "0")  ? 320 :
                                  (EHIP_RATE == "100G")                              ? 1280 :
                                  (EHIP_RATE == "200G" || EHIP_RATE == "400G")    ? 640 : 1280;

`endif


localparam AM_INS_CYC           = (EHIP_RATE == "25G")                               ? 4 :
                                  (EHIP_RATE == "40G")                               ? 2 :
                                  (EHIP_RATE == "50G" && RSFEC_TYPE_GUI == "0")   ? 2 :
                                  (EHIP_RATE == "50G")                               ? 2 :
                                  (EHIP_RATE == "100G" && RSFEC_TYPE_GUI == "0")  ? 5 :
                                  (EHIP_RATE == "100G")                              ? 5 :
                                  (EHIP_RATE == "200G" || EHIP_RATE == "400G")    ? 2 : 4;

localparam FEC_TYPE	      = RSFEC_TYPE_GUI;
localparam ERATE	         = EHIP_RATE;
localparam READY_LATENCY	= 0;
//localparam EMPTY_WIDTH_INT = PREAMBLE_PASS_TH_EN ? (EMPTY_WIDTH-1) : EMPTY_WIDTH; //commented on Feb1
localparam EMPTY_WIDTH_INT =  EMPTY_WIDTH; 



	defparam    packet_client_top.ENABLE_PTP           = PTP_EN;          		 
	defparam    packet_client_top.PKT_CYL       	      = PKT_CYL;
	defparam    packet_client_top.PTP_FP_WIDTH         = PTP_FP_WIDTH;
	defparam    packet_client_top.CLIENT_IF_TYPE       = CLIENT_IF_TYPE;
	defparam    packet_client_top.READY_LATENCY        = READY_LATENCY;        
   defparam    packet_client_top.WORDS_AVST           = DW_AVST_DW/64;
	defparam    packet_client_top.WORDS_MAC            = NUM_SEG;
//	defparam    packet_client_top.WORDS			         = (CLIENT_IF_TYPE) ? DW_AVST_DW/64 : NUM_SEG;
	defparam    packet_client_top.EMPTY_WIDTH          = EMPTY_WIDTH_INT;          
	defparam    packet_client_top.LPBK_FIFO_ADDR_WIDTH = LPBK_FIFO_ADDR_WIDTH;
	defparam    packet_client_top.PKT_ROM_INIT_FILE    = PKT_ROM_INIT_FILE;

  //--------------------------------------------------------------------------------
  // Signals
  //--------------------------------------------------------------------------------
 
	

 //AVST SOP Aligned interface signals
  wire                    tx_startofpacket;
  wire                    tx_endofpacket;
  wire                    tx_valid;
  wire                    tx_error;
  wire                    tx_ready;
  wire  [EMPTY_WIDTH_INT-1:0] tx_empty;
  wire  [DW_AVST_DW-1:0]  tx_data;
  wire                    tx_skip_crc;
 // wire  [63:0]            tx_preamble;

  wire                    rx_valid;
  wire                    rx_ready=1'b1;
  wire                    rx_startofpacket;
  wire                    rx_endofpacket;
  wire  [DW_AVST_DW-1:0]  rx_data;
  wire  [EMPTY_WIDTH_INT-1:0] rx_empty;
  wire  [5:0]             rx_error;    //TODO:output signals from DUT
  wire  [39:0]            rxstatus_data;
  wire                    rxstatus_valid;
  //wire  [63:0]            rx_preamble;

  //---AVST MAC Segmented TX/RX IF---  
  logic                   tx_mac_ready;
  logic                   tx_mac_valid;
  logic [NUM_SEG-1:0]     tx_mac_inframe;
  logic [NUM_SEG*3-1:0]   tx_mac_eop_empty;
  logic [NUM_SEG*64-1:0]  tx_mac_data;
  logic [NUM_SEG-1:0]     tx_mac_error;
  logic [NUM_SEG-1:0]     tx_mac_skip_crc;

  logic                   rx_mac_valid;
  logic [NUM_SEG-1:0]     rx_mac_inframe;
  logic [NUM_SEG*3-1:0]   rx_mac_eop_empty;
//  logic [NUM_SEG*EMPTY_WIDTH_INT-1:0]   rx_mac_eop_empty;
  logic [NUM_SEG*64-1:0]  rx_mac_data;
  logic [2*NUM_SEG-1:0]   rx_mac_error;
  logic [NUM_SEG-1:0]     rx_mac_fcs_error;
  logic [3*NUM_SEG-1:0]   rx_mac_status;



//-------------------------------------------------------------------------------

 

 
	 // PTP signals
    logic                               clk_tx_tod;
    logic                               clk_rx_tod;
    logic                               tx_tod_rst_n;
    logic                               rx_tod_rst_n;
    logic [PKT_CYL*1  -1:0]             ptp_ins_ets;  //TODO: check widths
    logic [PKT_CYL*1  -1:0]             ptp_ins_cf;
    logic [PKT_CYL*1  -1:0]             ptp_ins_zero_csum;
    logic [PKT_CYL*1  -1:0]             ptp_ins_update_eb;
    logic [PKT_CYL*16 -1:0]             ptp_ins_ts_offset;
    logic [PKT_CYL*16 -1:0]             ptp_ins_cf_offset;
    logic [PKT_CYL*16 -1:0]             ptp_ins_csum_offset;
    logic [PKT_CYL*1  -1:0]             ptp_p2p;
    logic [PKT_CYL*1  -1:0]             ptp_asym;
    logic [PKT_CYL*1  -1:0]             ptp_asym_sign;
    logic [PKT_CYL*7  -1:0]             ptp_asym_p2p_idx;
    logic [PKT_CYL*1  -1:0]             ptp_ts_req;
    logic [PKT_CYL*96 -1:0]             ptp_tx_its;
    logic [PKT_CYL*PTP_FP_WIDTH-1:0]    ptp_fp;
    logic [PKT_CYL*1 -1:0]              ptp_ets_valid;
    logic [PKT_CYL*96-1:0]              ptp_ets;
    logic [PKT_CYL*PTP_FP_WIDTH -1:0]   ptp_ets_fp;
    logic [192-1:0]              ptp_rx_its;

    logic 												      tx_pll_locked_sync;
    logic 											        rx_cdr_lock_sync;
    logic 															tx_todsync_sampling_clk_locked_sync;
    logic 															rx_todsync_sampling_clk_locked_sync;
 	

	 	logic tx_pll_locked_reconfig_sync;
   	logic rst_n_reconfig_sync;
  	logic pkt_client_rst_n;

	  logic [PKT_CYL*1 -1:0]  tx_ptp_ets_valid ;   //({i_txegrts1_tvalid,i_txegrts0_tvalid}),
	  logic [PKT_CYL*96 -1:0] tx_ptp_ets;        //  ({i_txegrts1_tdata[95:0],i_txegrts0_tdata[95:0]}),      //{i_txegrts1_tdata[95:0]i_txegrts0_tdata[95:0]};	    ets
     logic [PKT_CYL*8 -1:0]  tx_ptp_ets_fp;     //  ({i_txegrts1_tdata[103:96],i_txegrts0_tdata[103:96]}),
	  
	  assign tx_ptp_ets_valid  = (PKT_CYL == 2'd2) ? {i_txegrts1_tvalid,i_txegrts0_tvalid} : i_txegrts0_tvalid;
     assign tx_ptp_ets        = (PKT_CYL == 2'd2) ? {i_txegrts1_tdata[95:0],i_txegrts0_tdata[95:0]}  : i_txegrts0_tdata[95:0];
	  assign tx_ptp_ets_fp     = (PKT_CYL == 2'd2) ? {i_txegrts1_tdata[103:96],i_txegrts0_tdata[103:96]} : i_txegrts0_tdata[103:96];
   //logic [TID-1:0] i_axis_rx_tid; //TODO:check input 

//---------------------------------------------------------------	
//---------------------------------------------------------------	

  assign o_tx_pll_locked  = i_tx_pll_locked;
  assign o_cdr_lock		    = i_cdr_lock; 


eth_f_altera_std_synchronizer_nocut tx_pll_locked_reconfig_sync_inst (
    .clk        (app_ss_lite_clk),
    .reset_n    (1'b1),
    .din        (o_tx_pll_locked),  
    .dout       (tx_pll_locked_reconfig_sync)
);

eth_f_altera_std_synchronizer_nocut i_rst_reconfig_sync_inst (
    .clk        (app_ss_lite_clk),
    .reset_n    (1'b1),
    .din        (i_rst_n),
    .dout       (rst_n_reconfig_sync)
);


always @(posedge app_ss_lite_clk) begin
   pkt_client_rst_n <= tx_pll_locked_reconfig_sync & rst_n_reconfig_sync;
end

//eth_f_altera_std_synchronizer_nocut pkt_client_rst_n_sync_inst (
//    .clk        (i_clk_tx),
//    .reset_n    (1'b1),
//    .din        (pkt_client_rst_n),
//    .dout       (pkt_client_rst_n_sync)
//);
hssi_ss_std_synchronizer_nocut pkt_client_rst_n_sync_inst  (.clk (i_clk_tx), .reset_n (1'b1), .din (pkt_client_rst_n), .dout (pkt_client_rst_n_sync));

//wire [NUM_OF_STREAM-1:0] [95:0]	tx_ptp_ets ;  		
//wire [NUM_OF_STREAM-1:0] [7:0]	tx_ptp_ets_fp;		
//
//genvar ns;
//generate
// for (ns=0;ns<NUM_OF_STREAM;ns=ns+1)
// begin: EGRTS_DEMUX
//////	assign tx_ptp_ets[ns]    = i_txegrts0_tdata[96*(ns+1)-1:96*ns];
//////	assign tx_ptp_ets_fp[ns] = i_txegrts0_tdata[(96*(ns+1))+8-1:96*(ns+1)];   //[104*(ns+1)-1:96*(ns+1)]
//	assign tx_ptp_ets[ns] = i_txegrts0_tdata[ns][96-1:0];
//	assign tx_ptp_ets_fp[ns] = i_txegrts0_tdata[ns][103:96];   //[104*(ns+1)-1:96*(ns+1)]
// end
//endgenerate


	eth_f_packet_client_top  packet_client_top (
        .i_arst                       (!pkt_client_rst_n_sync),
        .i_clk_rx                     (i_clk_rx),
        .i_clk_tx                     (i_clk_tx),
        .i_clk_pll		      					(i_clk_pll),
			  .i_clk_status                 (app_ss_lite_clk),
        .i_clk_status_rst             (~app_ss_lite_areset_n), // i_reconfig_reset

        //segemented interface	
        .i_tx_mac_ready               (tx_mac_ready),			
        .o_tx_mac_valid               (tx_mac_valid),			//outputs from Packet_client_top connected to dut/AVST2AXI --?
        .o_tx_mac_inframe             (tx_mac_inframe),   
        .o_tx_mac_eop_empty           (tx_mac_eop_empty), 
        .o_tx_mac_data                (tx_mac_data),			
        .o_tx_mac_error               (tx_mac_error),     
        .o_tx_mac_skip_crc            (tx_mac_skip_crc),  
				
        .i_rx_mac_valid               (rx_mac_valid),	    //outputs of AXI2AVST connected to PC 
        .i_rx_mac_inframe             (rx_mac_inframe),   
        .i_rx_mac_eop_empty           ((CLIENT_IF_TYPE)? {3*NUM_SEG{1'b0}} : rx_mac_eop_empty), 
        .i_rx_mac_data                (rx_mac_data),      
        .i_rx_mac_error               ('h0),         	 //rx_mac_error
        .i_rx_mac_fcs_error           ('h0),             //rx_mac_fcs_error
        .i_rx_mac_status              ('h0),             //rx_mac_status

				//sop_aligned interface
        .i_tx_ready                   (tx_ready),
        .o_tx_valid                   (tx_valid),
        .o_tx_sop                     (tx_startofpacket), 
        .o_tx_eop                     (tx_endofpacket),
        .o_tx_empty                   (tx_empty),
        .o_tx_data                    (tx_data),
        .o_tx_error                   (tx_error),
        .o_tx_skip_crc                (tx_skip_crc),
			
        .i_rx_valid                   (rx_valid),
        .i_rx_sop                     (rx_startofpacket),
        .i_rx_eop                     (rx_endofpacket),
        .i_rx_empty                   (rx_empty),
        .i_rx_data                    (rx_data),
	.i_rx_error                   (6'h0),           //TODO rx_error  --> in E-tile hardcoded to 0
        .i_rxstatus_valid             (1'b1),    //rxstatus_valid), //TODO: check these signals
        .i_rxstatus_data              (40'd0),   //rxstatus_data),  //TODO
   
	//for 40/50G;
        //.i_rx_preamble                (rx_preamble),//TODO://should come as o/p from axis2avst bridge 
        //.o_tx_preamble                (tx_preamble), //should come as o/p from eth_f_packet_client_top 
				
	//ENABLE_PTP signals
        .i_clk_tx_tod                 (i_clk_tx_tod),
        .i_tx_tod_rst_n               (tx_tod_rst_n),
        .o_ptp_ins_ets                (ptp_ins_ets),  	//these outputs are connected to avst2axis_bridge
        .o_ptp_ins_cf                 (ptp_ins_cf),
        .o_ptp_ins_zero_csum          (ptp_ins_zero_csum),
        .o_ptp_ins_update_eb          (ptp_ins_update_eb),
        .o_ptp_ins_ts_offset          (ptp_ins_ts_offset),
        .o_ptp_ins_cf_offset          (ptp_ins_cf_offset),
        .o_ptp_ins_csum_offset        (ptp_ins_csum_offset),
        .o_ptp_p2p                    (ptp_p2p),
        .o_ptp_asym                   (ptp_asym),
        .o_ptp_asym_sign              (ptp_asym_sign),
        .o_ptp_asym_p2p_idx           (ptp_asym_p2p_idx),
        .o_ptp_ts_req                 (ptp_ts_req),
        .o_ptp_fp                     (ptp_fp),
        .o_ptp_tx_its                 (ptp_tx_its), 	// outputs of eth_f_packet_client will be inputs to ex_ss
        
        .i_tx_ptp_ets_valid           (tx_ptp_ets_valid), //ptp_ets_valid // outputs of ex_ss will be inputs to  eth_f_packet_client
        .i_tx_ptp_ets                 (tx_ptp_ets),      //{i_txegrts1_tdata[95:0]i_txegrts0_tdata[95:0]};	    //ptp_ets // tx_ptp_ets
        .i_tx_ptp_ets_fp              (tx_ptp_ets_fp),    //{i_txegrts1_tdata[103:96],i_txegrts0_tdata[103:96]};  //ptp_ets_fp //TODO tx_ptp_ets_fp
        .i_rx_ptp_its                 (ptp_rx_its[PKT_CYL*96-1:0]),			 //ptp_rx_its

        .i_tx_ptp_tod                 (ptp_tx_tod), 		 		     //ptp_rx_tod & //ptp_tx_tod_valid
        .i_tx_ptp_tod_valid           (ptp_tx_tod_valid),

        //Reconfig interface
        .i_status_addr                (i_status_addr),
        .i_status_read                (i_status_read),
        .i_status_write               (i_status_write),
        .i_status_writedata           (i_status_writedata),
        .o_status_readdata            (o_status_readdata),
        .o_status_readdata_valid      (o_status_readdata_valid),
        .o_status_waitrequest         (o_status_waitrequest)
   );
  //--------------------------------------------------------------------------------
  // AVST-AXIS BRidge
  //--------------------------------------------------------------------------------

  hssi_ss_f_ed_avst2axi_bridge #(
 	  .CLIENT_IF_TYPE                  ( CLIENT_IF_TYPE),
		.DATA_WIDTH                  	   ( DATA_WIDTH),	
		.EMPTY_BITS                   	 ( EMPTY_WIDTH_INT),                
    .NUM_SEG                         ( NUM_SEG),
		.PKT_SEG_PARITY_EN             ( PKT_SEG_PARITY_EN),
    .ST_READY_LATENCY                ( ST_READY_LATENCY),
    .ENABLE_MULTI_STREAM             ( ENABLE_MULTI_STREAM),
    .NUM_OF_STREAM                   ( NUM_OF_STREAM),
	 .CLIENT_WIDTH                    (TX_TUSER_CLIENT_WIDTH),
	 //.RX_TUSER_CLIENT_WIDTH           (RX_TUSER_CLIENT_WIDTH),
	 //.RX_TUSER_STATS_WIDTH            (RX_TUSER_STATS_WIDTH),
    //.TILES                           ( TILES),
	 .NO_OF_BYTES                     ( NO_OF_BYTES),
    .SIM_EMULATE                     ( SIM_MODE ),
    //.PREAMBLE_PASS_TH_EN             ( PREAMBLE_PASS_TH_EN ),
    .DW_AVST_DW                      ( DW_AVST_DW),
    .EHIP_RATE                       ( EHIP_RATE),
		.PTP_FP_WIDTH                    (PTP_FP_WIDTH),
    .TID                             ( TID),
	  .NUM_MAX_PORTS										(NUM_MAX_PORTS),
 		.PKT_SEG_PARITY_WIDTH						(PKT_SEG_PARITY_WIDTH),
 		.DR_ENABLE											(DR_ENABLE),
		.PORT_PROFILE										(PORT_PROFILE)
   
    //.DW_AXI                          ((PREAMBLE_PASS_TH_EN)? 256: DATA_WIDTH)
  ) avst2axis_bridge (
    .i_clk_tx                        ( i_clk_tx ),
    .i_tx_reset_n                    ( pkt_client_rst_n_sync ),
    .tx_error_i                      ( tx_error ),
    .tx_skip_crc_i                   ( tx_skip_crc ),
    .ptp_fp_i                        ( ptp_fp ),
    .ptp_ins_ets_i                   ( ptp_ins_ets ),
    .ptp_ts_req_i                    ( ptp_ts_req ),
    .ptp_tx_its_i                    ( ptp_tx_its ),
    .ptp_ins_cf_i                    ( ptp_ins_cf ),
    .ptp_ins_zero_csum_i             ( ptp_ins_zero_csum ), //chnage it to ptp_ins_zero_csum 
    .ptp_ins_update_eb_i             ( ptp_ins_update_eb ),
    .ptp_ins_ts_format_i             ( '0 ),
    .ptp_ins_ts_offset_i             ( ptp_ins_ts_offset ),
    .ptp_ins_cf_offset_i             ( ptp_ins_cf_offset ),
    .ptp_ins_csum_offset_i           ( ptp_ins_csum_offset ),
    .ptp_ins_eb_offset_i             ( '0 ),
    
    .axis_tvalid_o                   ( axis_tx_tvalid_o ),
    .axis_tdata_o                    ( axis_tx_tdata_o  ),
    .axis_tready_i                   ( axis_tx_tready_i ),
    .axis_tkeep_o                    ( axis_tx_tkeep_o ),
    .axis_tlast_o                    ( axis_tx_tlast_o ),
    .axis_tuser_client_o             ( axis_tx_tuser_client_o ),
    .axis_tuser_ptp_o                ( axis_tx_tuser_ptp_o ),
    .axis_tuser_ptp_ext_o            ( axis_tx_tuser_ptp_ext_o ),
    .axis_tuser_last_seg_o	          ( axis_tx_tuser_last_seg_o ),
    //.axis_preamble_o                 ( o_tx_preamble_pc ),
    
    //added for seg_parity 30 Sept
    .axis_tuser_pkt_seg_parity_o     ( axis_tx_tuser_pkt_seg_parity_o ),
    //.avst_preamble_i                 (tx_preamble ),// commented on Feb1 tx_preamble
    .avst_valid_i                    ( tx_valid ),
    .avst_data_i                     ( tx_data ),
    .avst_empty_i                    ( tx_empty ),
    .avst_sop_i                      ( tx_startofpacket ),
    .avst_eop_i                      ( tx_endofpacket ),
    .avst_ready_o                    ( tx_ready ),

		.i_active_ports						(NUM_MAX_PORTS),
		.i_active_segments					((NUM_SEG <= 4)? NUM_SEG: (NUM_SEG == 8)? 3'd5: 3'd6),
		.i_port_active_mask		({NUM_MAX_PORTS{1'b1}}),
		.i_port_data_width				((DW_AVST_DW == 64)? 3'd0 : (DW_AVST_DW == 128)? 3'd1 : 3'd2),
	
    .o_tx_mac_ready		     ( tx_mac_ready),      		
    .i_tx_mac_valid		     ( tx_mac_valid  ),  
    .i_tx_mac_inframe		  ( tx_mac_inframe),  
    .i_tx_mac_eop_empty		  ( tx_mac_eop_empty),
    .i_tx_mac_data		     ( tx_mac_data   ),  
    .i_tx_mac_error		     ( tx_mac_error  ),  
    .i_tx_mac_skip_crc   	  ( tx_mac_skip_crc )   
	 		     		
      )	;


  //--------------------------------------------------------------------------------
  // AXIS-AVST BRidge
  //--------------------------------------------------------------------------------

  hssi_ss_f_ed_axis2avst_bridge #(
    .EHIP_RATE                       (EHIP_RATE),
    .CLIENT_IF_TYPE                	 (CLIENT_IF_TYPE), 
	 .DATA_WIDTH							 (DATA_WIDTH),
	 .EMPTY_BITS							 (EMPTY_WIDTH_INT),  			
    .NUM_SEG                         (NUM_SEG),
	 .PKT_SEG_PARITY_EN            	 (PKT_SEG_PARITY_EN),
	 .ENABLE_MULTI_STREAM				 (ENABLE_MULTI_STREAM), //comes from tcl
	 .NUM_OF_STREAM						 (NUM_OF_STREAM), 		  //comes from tcl
    .TILES                           (TILES),
	 //.TX_TUSER_CLIENT_WIDTH         (TX_TUSER_CLIENT_WIDTH),
	 .RX_TUSER_CLIENT_WIDTH           (RX_TUSER_CLIENT_WIDTH),
	 .RX_TUSER_STATS_WIDTH            (RX_TUSER_STATS_WIDTH),
	 .NO_OF_BYTES                     (NO_OF_BYTES),
    .SIM_EMULATE                     (SIM_MODE),
   // .PREAMBLE_PASS_TH_EN             (PREAMBLE_PASS_TH_EN),
    .DW_AVST_DW                      (DW_AVST_DW),
    .TID                             (TID),
    .ST_READY_LATENCY                (ST_READY_LATENCY),
	  .NUM_MAX_PORTS										(NUM_MAX_PORTS),
 		.PKT_SEG_PARITY_WIDTH						(PKT_SEG_PARITY_WIDTH),
 		.DR_ENABLE											(DR_ENABLE)
    //.DW_AXI                          ((PREAMBLE_PASS_TH_EN)? 256: DATA_WIDTH)                         
  )  axis2avst_bridge (
    .i_clk_rx                        ( i_clk_rx ),
    .rx_aresetn                      ( pkt_client_rst_n_sync ),
    .axis_tvalid_i                   ( axis_rx_tvalid_i ),
    .axis_tdata_i                    ( axis_rx_tdata_i ),
    .axis_tready_o                   ( axis_rx_tready_o ),
    .axis_tkeep_i                    ( axis_rx_tkeep_i ),
    //.axis_tkeep_seg_i                ( (CLIENT_IF_TYPE) ? {NUM_SEG*8{1'b0}} : axis_rx_tkeep_i ),
    .axis_tkeep_seg_i                (axis_rx_tkeep_i[0][(8*NUM_SEG)-1:0]),
    .axis_tlast_i                    ( axis_rx_tlast_i ),
    .axis_tuser_client_i             ( axis_rx_tuser_client_i ),
    .axis_tuser_sts                  ( axis_rx_tuser_sts_i ),
    .axis_tuser_sts_ext              ( axis_rx_tuser_sts_ext_i ),
    .axis_tuser_last_seg			    ( axis_rx_tuser_last_seg_i ),	
    .axis_rx_ptp_its                 ( i_rxingrts0_tdata ),			 //ptp_rx_its
    .axis_rx_ptp_its_p2              ( i_rxingrts1_tdata ), //added on Jan23
    //.i_axis_rx_tid                   (i_axis_rx_tid),
   // .axis_rx_preamble_i              ( i_rx_preamble_pc ),
    .axis_tuser_pkt_seg_parity_i     ( axis_rx_tuser_pkt_seg_parity_i ),   

    .o_rx_ptp_its                    ( ptp_rx_its ),
	 

		.i_active_ports						(NUM_MAX_PORTS),
		.i_active_segments					((NUM_SEG <= 4)? NUM_SEG: (NUM_SEG == 8)? 3'd5: 3'd6),
		.i_port_active_mask		({NUM_MAX_PORTS{1'b1}}),
		.i_port_data_width				((DW_AVST_DW == 64)? 3'd0 : (DW_AVST_DW == 128)? 3'd1 : 3'd2),
	
	
    .avst_valid_o                    ( rx_valid ),
    .avst_data_o                     ( rx_data ),
    .avst_empty_o                    ( rx_empty ),
    .avst_sop_o                      ( rx_startofpacket ),
    .avst_eop_o                      ( rx_endofpacket ),
    .avst_ready_i                    ( 1'b1 ),
    //.avst_preamble_o                 ( rx_preamble ),

		//outputs of axis2avst_bridge connect to pc
    .i_av_st_rx_ms_ready				 ( 1'b1),   
    .o_av_st_rx_ms_data					 ( rx_mac_data),  	  
    .o_av_st_rx_ms_valid				 ( rx_mac_valid),    
    .o_av_st_rx_ms_inframe				 ( rx_mac_inframe),  
    .o_av_st_rx_ms_eop_empty			 ( rx_mac_eop_empty) 
  );

//---------------------------------------------------------------

generate 
if (PTP_EN)
begin:PTP_LOGIC
  
	if (PTP_ACC_MODE == 0) begin //Basic Mode
    // PTP Timestamp Accuracy Mode = "0:Basic"
    assign clk_tx_tod       = i_clk_tx_tod;
    assign clk_rx_tod       = i_clk_rx_tod;
    assign tx_tod_rst_n     = i_tx_tod_rst_n;
    assign rx_tod_rst_n     = i_rx_tod_rst_n;
    assign ptp_tx_tod       = i_ptp_ip_tod; 						//i_ptp_tx_tod,coming from ip_tod
    assign ptp_tx_tod_valid = i_ptp_ip_tod_valid;
    assign ptp_rx_tod       = i_ptp_ip_tod; 						// coming from ip_tod
    assign ptp_rx_tod_valid = i_ptp_ip_tod_valid;
	end else begin
    // PTP Timestamp Accuracy Mode = "1:Advanced"
    logic tx_pll_locked_reg;
    logic cdr_lock_reg;
    logic tx_tod_rst_n_wire;
    logic tx_tod_rst_n_reg;
    logic rx_tod_rst_n_wire;
    logic rx_tod_rst_n_reg;

    always @(posedge app_ss_lite_clk) begin
        tx_pll_locked_reg   <= o_tx_pll_locked;
        cdr_lock_reg        <= o_cdr_lock;
    end

    assign clk_tx_tod        = i_clk_tx_tod;
    assign clk_rx_tod        = i_clk_rx_tod;
    assign tx_tod_rst_n_wire = tx_pll_locked_sync & tx_todsync_sampling_clk_locked_sync;
    assign rx_tod_rst_n_wire = rx_cdr_lock_sync & rx_todsync_sampling_clk_locked_sync;
    
    // flops to fix recovery time violation from tx_tod_rst_n to tod_sync inst
    always @(posedge clk_tx_tod) begin
        tx_tod_rst_n_reg   <= tx_tod_rst_n_wire;
        tx_tod_rst_n       <= tx_tod_rst_n_reg;
    end
    always @(posedge clk_rx_tod) begin
        rx_tod_rst_n_reg   <= rx_tod_rst_n_wire;
        rx_tod_rst_n       <= rx_tod_rst_n_reg;
    end

    eth_f_altera_std_synchronizer_nocut tx_todsync_sampling_locked_sync_inst (
        .clk        (clk_tx_tod),
        .reset_n    (1'b1),
        .din        (i_clk_todsync_sample_locked),
        .dout       (tx_todsync_sampling_clk_locked_sync)
    );
    eth_f_altera_std_synchronizer_nocut rx_todsync_sampling_locked_sync_inst (
        .clk        (clk_rx_tod),
        .reset_n    (1'b1),
        .din        (i_clk_todsync_sample_locked),
        .dout       (rx_todsync_sampling_clk_locked_sync)
    );
    eth_f_altera_std_synchronizer_nocut tx_pll_locked_sync_inst (
        .clk        (clk_tx_tod),
        .reset_n    (1'b1),
        .din        (tx_pll_locked_reg),
        .dout       (tx_pll_locked_sync)
    );
    eth_f_altera_std_synchronizer_nocut rx_cdr_lock_sync_inst (
        .clk        (clk_rx_tod),
        .reset_n    (1'b1),
        .din        (cdr_lock_reg),
        .dout       (rx_cdr_lock_sync)
    );


    eth_f_ptp_stod_top #(
        .EN_10G_ADV_MODE (EN_10G_ADV_MODE)
    ) tx_tod (
        .i_clk_reconfig             (app_ss_lite_clk),
        .i_reconfig_rst_n           (app_ss_lite_areset_n),   
        .i_clk_mtod                 (i_clk_master_tod),        //input signal from top 
        .i_clk_stod                 (clk_tx_tod),
        .i_clk_todsync_sampling     (i_clk_todsync_sample),    //coming from hw_top Module
        .i_mtod_rst_n               (i_ptp_master_tod_rst_n),
        .i_stod_rst_n               (tx_tod_rst_n),
        .i_mtod_data                (i_ptp_master_tod),
        .i_mtod_valid               (i_ptp_master_tod_valid),
        .o_stod_data                (ptp_tx_tod),
        .o_stod_valid               (ptp_tx_tod_valid)
    );
    eth_f_ptp_stod_top #(
        .EN_10G_ADV_MODE (EN_10G_ADV_MODE)                	
    ) rx_tod (
        .i_clk_reconfig             (app_ss_lite_clk),
        .i_reconfig_rst_n           (app_ss_lite_areset_n),
        .i_clk_mtod                 (i_clk_master_tod),
        .i_clk_stod                 (clk_rx_tod),
        .i_clk_todsync_sampling     (i_clk_todsync_sample),
        .i_mtod_rst_n               (i_ptp_master_tod_rst_n),
        .i_stod_rst_n               (rx_tod_rst_n),
        .i_mtod_data                (i_ptp_master_tod),
        .i_mtod_valid               (i_ptp_master_tod_valid),
        .o_stod_data                (ptp_rx_tod),
        .o_stod_valid               (ptp_rx_tod_valid)
    );
	end
//end


end
else
begin : NO_PTP
    assign tx_tod_rst_n     = 1'b1;
end
endgenerate




endmodule

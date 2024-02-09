// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`timescale 1 ps / 1 ps
module hssi_ss_f_packet_client_top_400G_8 #(
        parameter CLIENT_IF_TYPE         				= 0,        // 0:Segmented; 1:AvST;
        parameter LANE_NUM               				= 8,
        parameter WORDS                  				= 8,
        parameter WIDTH                  				= 64,
        parameter EMPTY_WIDTH            				= 6,

        parameter SIM_MODE            					= 0,
				parameter PTP_EN                  			= 0,
				parameter PTP_ACC_MODE            			= 0,
				parameter EHIP_RATE               			= "10G", 
				//parameter PTP_FP_WIDTH            			= 8,  
				parameter EN_10G_ADV_MODE         			= 0,				
				parameter DATA_WIDTH      	 	 					= 64,
				parameter NO_OF_BYTES  			 						= ( CLIENT_IF_TYPE == 1) ? DATA_WIDTH/8 : 'd8,  
				parameter NUM_SEG              	 				= ( CLIENT_IF_TYPE == 1) ? 'd1 : (DATA_WIDTH/64), 
				parameter NUM_PORTS 										= 1,//associated ports 1 or all
			 //TODO

				//parameter ASCT_PORT_NUM									= 0,
				parameter BASE_PORT_NUM									= 0,	
				parameter PKT_SEG_PARITY_EN  	 					= 0,       
				parameter ENABLE_MULTI_STREAM	 					= 0,       
				parameter NUM_OF_STREAM   		 					= 1,
				parameter ST_READY_LATENCY      				= 0,      
				parameter TILES   	 			 	 						= "F",    
		    		parameter NUM_MAX_PORTS          				= 1,
 				parameter PKT_SEG_PARITY_WIDTH					= (CLIENT_IF_TYPE == 1)? NUM_MAX_PORTS: NUM_SEG,	 
				parameter PORT_PROFILE         					= "10GbE",
				parameter	DR_ENABLE	 										= 0,
				//parameter PKT_ROM_INIT_FILE      				= "eth_f_hw_pkt_gen_rom_init.10G_SEG.hex" ,
    		parameter TX_TUSER_CLIENT_WIDTH  				= (2*DATA_WIDTH)/64,
    		parameter RX_TUSER_CLIENT_WIDTH  				= (7*DATA_WIDTH)/64,
    		parameter RX_TUSER_STATS_WIDTH   				= (5*DATA_WIDTH)/64,
        parameter PREAMBLE_PASS_TH_EN	 	 				= 0,
        parameter DW_AVST_DW             				= (PREAMBLE_PASS_TH_EN)? DATA_WIDTH/2: DATA_WIDTH,
        parameter TID                    				= 88888888 


    )(
        input  wire                    												app_ss_lite_clk,//i_reconfig_clk,//app_ss_lite_clk
        input  wire                    												app_ss_lite_areset_n,//i_reconfig_reset,//app_ss_lite_areset_n
						input 	[31:0]																								ASCT_PORT_NUM,
		input wire                        i_rst_n,
	
  			input  logic                	 												i_p0_clk_tx_tod,
  			input  logic                	 												i_p0_clk_rx_tod,			

  			input  logic                	 												i_p1_clk_tx_tod,
  			input  logic                	 												i_p1_clk_rx_tod,			

  			input  logic                	 												i_p2_clk_tx_tod,
  			input  logic                	 												i_p2_clk_rx_tod,			

  			input  logic                	 												i_p3_clk_tx_tod,
  			input  logic                	 												i_p3_clk_rx_tod,			


				
  			  	output logic [95:0]                             p0_ptp_tx_tod,
    output logic [95:0]                             p0_ptp_rx_tod,
    output logic                                    p0_ptp_tx_tod_valid,
    output logic                                    p0_ptp_rx_tod_valid,	

  	output logic [95:0]                             p1_ptp_tx_tod,
    output logic [95:0]                             p1_ptp_rx_tod,
    output logic                                    p1_ptp_tx_tod_valid,
    output logic                                    p1_ptp_rx_tod_valid,	
  		
  	output logic [95:0]                             p2_ptp_tx_tod,
    output logic [95:0]                             p2_ptp_rx_tod,
    output logic                                    p2_ptp_tx_tod_valid,
    output logic                                    p2_ptp_rx_tod_valid,	

  	output logic [95:0]                             p3_ptp_tx_tod,
    output logic [95:0]                             p3_ptp_rx_tod,
    output logic                                    p3_ptp_tx_tod_valid,
    output logic                                    p3_ptp_rx_tod_valid,

  		        input         					     			   	i_p0_txegrts0_tvalid,  // ss_app_st_p${port_no}_txegrts0_tvalid;  outputs from dut(ex_ss)
  			input [104-1:0] 						   				i_p0_txegrts0_tdata,   // ss_app_st_p${port_no}_txegrts0_tdata;

				input         					     			   	i_p1_txegrts0_tvalid,  // ss_app_st_p${port_no}_txegrts0_tvalid;  outputs from dut(ex_ss)
  			input [104-1:0] 						   				i_p1_txegrts0_tdata,   // ss_app_st_p${port_no}_txegrts0_tdata;

        input         					     			   	i_p2_txegrts0_tvalid,  // ss_app_st_p${port_no}_txegrts0_tvalid;  outputs from dut(ex_ss)
  			input [104-1:0] 						   				i_p2_txegrts0_tdata,   // ss_app_st_p${port_no}_txegrts0_tdata;

        input         					     			   	i_p3_txegrts0_tvalid,  // ss_app_st_p${port_no}_txegrts0_tvalid;  outputs from dut(ex_ss)
  			input [104-1:0] 						   				i_p3_txegrts0_tdata,   // ss_app_st_p${port_no}_txegrts0_tdata;


  			input        		 					         		i_p0_txegrts1_tvalid,
  			input [104-1:0] 						   		   	i_p0_txegrts1_tdata , 	

  			input        		 					         		i_p1_txegrts1_tvalid,
  			input [104-1:0] 						   		   	i_p1_txegrts1_tdata , 	

  			input        		 					         		i_p2_txegrts1_tvalid,
  			input [104-1:0] 						   		   	i_p2_txegrts1_tdata , 	

  			input        		 					         		i_p3_txegrts1_tvalid,
  			input [104-1:0] 						   		   	i_p3_txegrts1_tdata , 	

  			input [3:0]       		 					   		i_rxingrts1_tvalid,
  			input [(4*96)-1:0]  						   		i_rxingrts1_tdata, 
  			input [3:0]       		 					   		i_rxingrts0_tvalid,
  			input [(4*96)-1:0]  						   		i_rxingrts0_tdata, 

				//not per port
        input	 logic [95:0]        		 												i_ptp_ip_tod,      
  			input  logic               	   												i_ptp_ip_tod_valid,
				input  logic               		 												i_ptp_master_tod_rst_n,
  			input  logic [95:0]        		 												i_ptp_master_tod,
  			input  logic               		 												i_ptp_master_tod_valid,		
  			input  logic               		 												i_tx_tod_rst_n,
  			input  logic               		 												i_rx_tod_rst_n,
  			input  logic               		 												i_clk_master_tod,
  			input  logic               		 												i_clk_todsync_sample,
  			input  logic               		 												i_clk_todsync_sample_locked,
  		  input  wire                    												i_clk_tx,
        input  wire                    												i_clk_rx,
        input  wire                    												i_clk_pll,
				input  wire               			 											i_tx_pll_locked,
input  wire               			 								i_p0_cdr_lock,
		input  wire               			 								i_p1_cdr_lock,
		input  wire               			 								i_p2_cdr_lock,
		input  wire               			 								i_p3_cdr_lock,
				//output logic [63:0]        		 	  									o_tx_preamble_pc, //TODO: 
  			//input  logic [63:0]        			  									i_rx_preamble_pc, //TODO:


        
	
 

      
 
  			output logic [NUM_OF_STREAM-1:0][3:0]                  			axis_tx_tvalid_o,
  			output logic [NUM_OF_STREAM-1:0][DATA_WIDTH-1:0]      			axis_tx_tdata_o,
  			input  logic [NUM_OF_STREAM-1:0][3:0]                       axis_tx_tready_i, //TODO:check Width
  			output logic [NUM_OF_STREAM-1:0][DATA_WIDTH/8-1:0]    			axis_tx_tkeep_o,
  			output logic [NUM_OF_STREAM-1:0][3:0]                       axis_tx_tlast_o,
  			output logic [NUM_OF_STREAM-1:0][TX_TUSER_CLIENT_WIDTH-1:0] axis_tx_tuser_client_o,    //outputs from avst2axis_bridge 
  			output logic [NUM_OF_STREAM-1:0][(4*94)-1:0]   										axis_tx_tuser_ptp_o,
  			output logic [NUM_OF_STREAM-1:0][(4*328)-1:0]   									axis_tx_tuser_ptp_ext_o,
  			output logic [NUM_SEG-1:0]  							   			axis_tx_tuser_last_seg_o,  //TODO:output signal is  connected as input to ex_ss?
  			output logic [NUM_SEG-1:0]  	         								axis_tx_tuser_pkt_seg_parity_o,


  			input  [NUM_OF_STREAM-1:0][3:0]                				axis_rx_tvalid_i,
  			input  [NUM_OF_STREAM-1:0][DATA_WIDTH-1:0]   		  		axis_rx_tdata_i,
  			output [NUM_OF_STREAM-1:0][3:0]		 			 							axis_rx_tready_o,//TODO:Check width 
  			input  [NUM_OF_STREAM-1:0][DATA_WIDTH/8-1:0]   				axis_rx_tkeep_i,
  			input  [NUM_OF_STREAM-1:0][3:0]                				axis_rx_tlast_i,
  			input  [NUM_OF_STREAM-1:0][RX_TUSER_CLIENT_WIDTH-1:0] axis_rx_tuser_client_i,  //TODO:warning:  
  			input  [NUM_OF_STREAM-1:0][RX_TUSER_STATS_WIDTH-1:0]  axis_rx_tuser_sts_i,     //TODO:warning: 94bits 
  			input  [NUM_OF_STREAM-1:0][31:0]  										axis_rx_tuser_sts_ext_i, //TODO:warning:328bits   
  			input  [NUM_SEG-1:0]      														axis_rx_tuser_last_seg_i, 
  			input  [NUM_SEG-1:0]  																axis_rx_tuser_pkt_seg_parity_i,


 
        
        // Jtag avmm bus
        input   wire    [16-1:0]  								i_jtag_address,
        input   wire                           								i_jtag_read,
        input   wire                           								i_jtag_write,
        input   wire    [31:0]                 								i_jtag_writedata,
        input   wire    [3:0]                  								i_jtag_byteenable,
        output  logic    [31:0]                 								o_jtag_readdata,
        output  logic                           								o_jtag_readdatavalid,
        output  logic                           								o_jtag_waitrequest,

				input logic 	[5:0]																		dr_mode_lite
);
        // DR mode
          wire    [5:0]           											dr_mode; // 6'b00_00_00 - "1x400GE-8"
    
logic [6:0] dr_mode_tod;													
			
hssi_ss_resync_std #(
  .SYNC_CHAIN_LENGTH(3),    .WIDTH(6),  .INIT_VALUE(0)
    ) U_profile_sel_sync_txclk (
      .clk     (i_clk_tx),
      .reset   (1'b0),
      .d       (dr_mode_lite),
      .q       (dr_mode)
    );
															
/*			
hssi_ss_resync_std #(
  .SYNC_CHAIN_LENGTH(3),    .WIDTH(6),  .INIT_VALUE(0)
    ) U_profile_sel_sync_txtodclk (
      .clk     (i_clk_tx_tod),
      .reset   (1'b0),
      .d       (dr_mode_lite),
      .q       (dr_mode_tod)
    );
*/                                            											// 6'b01_00_00 - "2x200GE-4"
                                                											// 6'b10_00_00 - "4x100GE-2"

localparam DR_MODE_1X400GE_8    = 6'b00_00_00; // "1x400GE-8"
localparam DR_MODE_2X200GE_4    = 6'b01_00_00; // "2x200GE-4"
localparam DR_MODE_4X100GE_2    = 6'b10_00_00; // "4x100GE-2"

localparam PKT_ROM_INIT_FILE_400 =(CLIENT_IF_TYPE == 0 & PTP_EN == 0) ? "../hardware_test_design/common_f/eth_f_hw_pkt_gen_rom_init.400G_SEG.hex"      : 
                               		(CLIENT_IF_TYPE == 1 & PTP_EN == 0) ? "../hardware_test_design/common_f/eth_f_hw_pkt_gen_rom_init.400G_AVST.hex"     : 
                               		(CLIENT_IF_TYPE == 0 & PTP_EN == 1) ? "../hardware_test_design/common_f/eth_f_hw_pkt_gen_rom_init.400G_SEG_PTP.hex"  : 
                               		(CLIENT_IF_TYPE == 1 & PTP_EN == 1) ? "../hardware_test_design/common_f/eth_f_hw_pkt_gen_rom_init.400G_AVST_PTP.hex" : 
                               		"../hardware_test_design/common_f/eth_f_hw_pkt_gen_rom_init.hex";
localparam PKT_ROM_INIT_FILE_200 =(CLIENT_IF_TYPE == 0 & PTP_EN == 0) ? "../hardware_test_design/common_f/eth_f_hw_pkt_gen_rom_init.200G_SEG.hex"      : 
                               		(CLIENT_IF_TYPE == 1 & PTP_EN == 0) ? "../hardware_test_design/common_f/eth_f_hw_pkt_gen_rom_init.200G_AVST.hex"     : 
                               		(CLIENT_IF_TYPE == 0 & PTP_EN == 1) ? "../hardware_test_design/common_f/eth_f_hw_pkt_gen_rom_init.200G_SEG_PTP.hex"  : 
                               		(CLIENT_IF_TYPE == 1 & PTP_EN == 1) ? "../hardware_test_design/common_f/eth_f_hw_pkt_gen_rom_init.200G_AVST_PTP.hex" : 
                               		"../hardware_test_design/common_f/eth_f_hw_pkt_gen_rom_init.hex";
localparam PKT_ROM_INIT_FILE_100 =(CLIENT_IF_TYPE == 0 & PTP_EN == 0) ? "../hardware_test_design/common_f/eth_f_hw_pkt_gen_rom_init.100G_SEG.hex"      : 
                               		(CLIENT_IF_TYPE == 1 & PTP_EN == 0) ? "../hardware_test_design/common_f/eth_f_hw_pkt_gen_rom_init.100G_AVST.hex"     : 
                               		(CLIENT_IF_TYPE == 0 & PTP_EN == 1) ? "../hardware_test_design/common_f/eth_f_hw_pkt_gen_rom_init.100G_SEG_PTP.hex"  : 
                               		(CLIENT_IF_TYPE == 1 & PTP_EN == 1) ? "../hardware_test_design/common_f/eth_f_hw_pkt_gen_rom_init.100G_AVST_PTP.hex" : 
                               		"../hardware_test_design/common_f/eth_f_hw_pkt_gen_rom_init.hex";

															 //---Less entries for higher speed which has larger data width;
localparam LPBK_FIFO_ADDR_WIDTH = ("400G" == "10G")  ? 12 :
                                  ("400G" == "25G")  ? 12 :
                                  ("400G" == "40G")  ? 12 :
                                  ("400G" == "50G")  ? 12 :
                                  ("400G" == "100G") ? 8 :
                                  ("400G" == "200G") ? 8 :
                                  ("400G" == "400G") ? 8 : 8;
localparam EMPTY_WIDTH_INT = PREAMBLE_PASS_TH_EN ? (EMPTY_WIDTH-1) : EMPTY_WIDTH;
//---------------------------------------------------------------

    logic     [15:0]               i_status_addr;
    logic                          i_status_read;
    logic                          i_status_write;
    logic     [31:0]               i_status_writedata;
    logic     [3:0]                i_status_byteenable;
    logic     [31:0]               o_status_readdata;
    logic                          o_status_readdata_valid;
    logic                          o_status_waitrequest;

    // 4x100G packet client
    logic     [4*16-1:0]           i_100g_status_addr;
    logic     [3:0]                i_100g_status_read;
    logic     [3:0]                i_100g_status_write;
    logic     [4*32-1:0]           i_100g_status_writedata;
    logic     [4*4-1:0]            i_100g_status_byteenable;
    logic     [4*32-1:0]           o_100g_status_readdata;
    logic     [3:0]                o_100g_status_readdata_valid;
    logic     [3:0]                o_100g_status_waitrequest;
    
    // 2x200G packet client
    logic     [2*16-1:0]           i_200g_status_addr;
    logic     [1:0]                i_200g_status_read;
    logic     [1:0]                i_200g_status_write;
    logic     [2*32-1:0]           i_200g_status_writedata;
    logic     [2*4-1:0]            i_200g_status_byteenable;
    logic     [2*32-1:0]           o_200g_status_readdata;
    logic     [1:0]                o_200g_status_readdata_valid;
    logic     [1:0]                o_200g_status_waitrequest;

//---------------------------------------------------------------
    //TX Segmented Interface
    reg   [64*16-1:0]             i_muxed_tx_mac_data;
    reg   [3:0]                   i_muxed_tx_mac_valid;
    reg   [1*16-1:0]              i_muxed_tx_mac_inframe;
    reg   [48-1:0]                i_muxed_tx_mac_eop_empty;
    wire  [3:0]                   o_muxed_tx_mac_ready;

    reg   [1*16-1:0]              i_muxed_tx_mac_error;
    reg   [16-1:0]                i_muxed_tx_mac_skip_crc;

    //RX Segmented Interface
    wire  [64*16-1:0]             o_muxed_rx_mac_data;
    wire  [3:0]                   o_muxed_rx_mac_valid;
    wire  [1*16-1:0]              o_muxed_rx_mac_inframe;
    wire  [48-1:0]                o_muxed_rx_mac_eop_empty;
    wire  [2*16-1:0]              o_muxed_rx_mac_error;
    wire [1*16-1:0]               o_muxed_rx_mac_fcs_error;
    wire [48-1:0]                 o_muxed_rx_mac_status;

    //TX Segmented Interface
    wire  [64*16-1:0]             i_tx_mac_data;
    wire                          i_tx_mac_valid;
    wire  [1*16-1:0]              i_tx_mac_inframe;
    wire  [48-1:0]                i_tx_mac_eop_empty;
    wire                          o_tx_mac_ready;

    wire  [1*16-1:0]              i_tx_mac_error;
    wire  [16-1:0]                i_tx_mac_skip_crc;

    //RX Segmented Interface
    wire  [64*16-1:0]             o_rx_mac_data;
    wire                          o_rx_mac_valid;
    wire  [1*16-1:0]              o_rx_mac_inframe;
    wire  [48-1:0]                o_rx_mac_eop_empty;
    wire  [2*16-1:0]              o_rx_mac_erro=0;
    wire [1*16-1:0]               o_rx_mac_fcs_error=0;
    wire [48-1:0]                 o_rx_mac_status=0;

    // TX AVST INTERFACE
    wire  [64*16-1:0]             i_tx_data;
    wire                          i_tx_valid;
    wire                          i_tx_startofpacket;
    wire                          i_tx_endofpacket;
    wire                          o_tx_ready;

    wire  [48-1:0]                i_tx_empty;
    wire                          i_tx_error;
    wire                          i_tx_skip_crc;

    // RX AVST INTERFACE
    wire    [64*16-1:0]           o_rx_data;
    wire                          o_rx_valid;
    wire                          o_rx_startofpacket;
    wire                          o_rx_endofpacket;
    wire    [48-1:0]              o_rx_empty;
    wire    [6-1:0]               o_rx_error;
    wire    [39:0]                o_rxstatus_data;
    wire                          o_rxstatus_valid;

    wire    [63:0]                i_tx_preamble; 
    wire    [63:0]                o_rx_preamble;

    // 4x100G
    //TX Segmented Interface
    wire  [4*256-1:0]            i_100g_tx_mac_data;
    wire  [4*1-1:0]              i_100g_tx_mac_valid;
    wire  [4*4-1:0]              i_100g_tx_mac_inframe;
    wire  [4*12-1:0]             i_100g_tx_mac_eop_empty;
    wire  [4*4-1:0]              o_100g_tx_mac_ready;
    wire  [4*4-1:0]              i_100g_tx_mac_error;
    wire  [4*4-1:0]              i_100g_tx_mac_skip_crc;

    //RX Segmented Interface
    wire  [4*256-1:0]            o_100g_rx_mac_data;
    wire  [4*1-1:0]              o_100g_rx_mac_valid;
    wire  [4*4-1:0]              o_100g_rx_mac_inframe;
    wire  [4*12-1:0]             o_100g_rx_mac_eop_empty;
    wire  [4*8-1:0]              o_100g_rx_mac_error=0;
    wire  [4*4-1:0]              o_100g_rx_mac_fcs_error=0;
    wire  [4*12-1:0]             o_100g_rx_mac_status=0;

    // TX AVST INTERFACE
    wire  [4*256-1:0]           i_100g_tx_data;
    wire  [4*1-1:0]             i_100g_tx_valid;
    wire  [4*1-1:0]             i_100g_tx_startofpacket;
    wire  [4*1-1:0]             i_100g_tx_endofpacket;
    wire  [4*1-1:0]             o_100g_tx_ready;
    wire  [4*6-1:0]             i_100g_tx_empty;
    wire  [4*1-1:0]             i_100g_tx_error;
    wire  [4*1-1:0]             i_100g_tx_skip_crc;

    // RX AVST INTERFACE
    wire  [4*256-1:0]           o_100g_rx_data;
    wire  [4*1-1:0]             o_100g_rx_valid;
    wire  [4*1-1:0]             o_100g_rx_startofpacket;
    wire  [4*1-1:0]             o_100g_rx_endofpacket;
    wire  [4*6-1:0]             o_100g_rx_empty;
    wire  [4*6-1:0]             o_100g_rx_error;
    wire  [4*40-1:0]            o_100g_rxstatus_data;
    wire  [4*1-1:0]             o_100g_rxstatus_valid;

    wire  [4*64-1:0]            i_100g_tx_preamble; 
    wire  [4*64-1:0]            o_100g_rx_preamble;

    // 2x200G
    //TX Segmented Interface
    wire  [2*512-1:0]           i_200g_tx_mac_data;
    wire  [2*1:0]               i_200g_tx_mac_valid;
    wire  [2*8-1:0]             i_200g_tx_mac_inframe;
    wire  [2*24-1:0]            i_200g_tx_mac_eop_empty;
    wire  [2*1-1:0]             o_200g_tx_mac_ready;
    wire  [2*8-1:0]             i_200g_tx_mac_error;
    wire  [2*8-1:0]             i_200g_tx_mac_skip_crc;

    //RX Segmented Interface
    wire  [2*512-1:0]           o_200g_rx_mac_data;
    wire  [2*1-1:0]             o_200g_rx_mac_valid;
    wire  [2*8-1:0]             o_200g_rx_mac_inframe;
    wire  [2*24-1:0]            o_200g_rx_mac_eop_empty;
    wire  [2*16-1:0]            o_200g_rx_mac_error=0;
    wire  [2*8-1:0]             o_200g_rx_mac_fcs_error=0;
    wire  [2*24-1:0]            o_200g_rx_mac_status=0;

    // TX AVST INTERFACE
    wire  [2*512-1:0]           i_200g_tx_data;
    wire  [2*1-1:0]             i_200g_tx_valid;
    wire  [2*1-1:0]             i_200g_tx_startofpacket;
    wire  [2*1-1:0]             i_200g_tx_endofpacket;
    wire  [2*1-1:0]             o_200g_tx_ready;
    wire  [2*24-1:0]            i_200g_tx_empty;
    wire  [2*1-1:0]             i_200g_tx_error;
    wire  [2*1-1:0]             i_200g_tx_skip_crc;

    // RX AVST INTERFACE
    wire  [2*512-1:0]           o_200g_rx_data;
    wire  [2*1-1:0]             o_200g_rx_valid;
    wire  [2*1-1:0]             o_200g_rx_startofpacket;
    wire  [2*1-1:0]             o_200g_rx_endofpacket;
    wire  [2*24-1:0]            o_200g_rx_empty;
    wire  [2*6-1:0]             o_200g_rx_error;
    wire  [2*40-1:0]            o_200g_rxstatus_data;
    wire  [2*1-1:0]             o_200g_rxstatus_valid;

    wire  [2*64-1:0]            i_200g_tx_preamble; 
    wire  [2*64-1:0]            o_200g_rx_preamble;

    // ETH 400G
    

    // ETH 100G
    wire [3:0]                  i_100g_clk_tx;
    wire [3:0]                  i_100g_clk_rx;
    wire [3:0]                  i_100g_rst_n;    

    // ETH 200G
    wire [1:0]                  i_200g_clk_tx;
    wire [1:0]                  i_200g_clk_rx;
    wire [1:0]                  i_200g_rst_n;

    



//---------------------------------------------------------------
    localparam PKT_CYL       = 1;
    localparam PKT_CYL_400G  = 2;
    localparam PTP_FP_WIDTH  = 8;




//---------------------------------------------------------------
    //localparam PKT_CYL      = 1;
   // localparam PTP_FP_WIDTH = 8;

    // PTP signals
		
		logic                                    i_400g_clk_tx_tod;
    logic                                    i_400g_tx_tod_rst_n;
    logic [PKT_CYL_400G*1  -1:0]             o_400g_ptp_ins_ets;
    logic [PKT_CYL_400G*1  -1:0]             o_400g_ptp_ins_cf;
    logic [PKT_CYL_400G*1  -1:0]             o_400g_ptp_ins_zero_csum;
    logic [PKT_CYL_400G*1  -1:0]             o_400g_ptp_ins_update_eb;
    logic [PKT_CYL_400G*16 -1:0]             o_400g_ptp_ins_ts_offset;
    logic [PKT_CYL_400G*16 -1:0]             o_400g_ptp_ins_cf_offset;
    logic [PKT_CYL_400G*16 -1:0]             o_400g_ptp_ins_csum_offset;
    logic [PKT_CYL_400G*1  -1:0]             o_400g_ptp_p2p;
    logic [PKT_CYL_400G*1  -1:0]             o_400g_ptp_asym;
    logic [PKT_CYL_400G*1  -1:0]             o_400g_ptp_asym_sign;
    logic [PKT_CYL_400G*7  -1:0]             o_400g_ptp_asym_p2p_idx;
    logic [PKT_CYL_400G*1  -1:0]             o_400g_ptp_ts_req;
    logic [PKT_CYL_400G*96 -1:0]             o_400g_ptp_tx_its;
    logic [PKT_CYL_400G*PTP_FP_WIDTH-1:0]    o_400g_ptp_fp;
    logic [PKT_CYL_400G*1 -1:0]              i_400g_ptp_ets_valid;
    logic [PKT_CYL_400G*96-1:0]              i_400g_ptp_ets;
    logic [PKT_CYL_400G*PTP_FP_WIDTH -1:0]   i_400g_ptp_ets_fp;
    logic [PKT_CYL_400G*96-1:0]              i_400g_ptp_rx_its;
    logic [95:0]                             i_400g_ptp_tx_tod;
    logic                                    i_400g_ptp_tx_tod_valid;
	
 		logic [1:0]                                    i_200g_clk_tx_tod;
    logic [1:0]                                    i_200g_tx_tod_rst_n;
    logic [1:0] [PKT_CYL*1  -1:0]                  o_200g_ptp_ins_ets;
    logic [1:0] [PKT_CYL*1  -1:0]                  o_200g_ptp_ins_cf;
    logic [1:0] [PKT_CYL*1  -1:0]                  o_200g_ptp_ins_zero_csum;
    logic [1:0] [PKT_CYL*1  -1:0]                  o_200g_ptp_ins_update_eb;
    logic [1:0] [PKT_CYL*16 -1:0]                  o_200g_ptp_ins_ts_offset;
    logic [1:0] [PKT_CYL*16 -1:0]                  o_200g_ptp_ins_cf_offset;
    logic [1:0] [PKT_CYL*16 -1:0]                  o_200g_ptp_ins_csum_offset;
    logic [1:0] [PKT_CYL*1  -1:0]                  o_200g_ptp_p2p;
    logic [1:0] [PKT_CYL*1  -1:0]                  o_200g_ptp_asym;
    logic [1:0] [PKT_CYL*1  -1:0]                  o_200g_ptp_asym_sign;
    logic [1:0] [PKT_CYL*7  -1:0]                  o_200g_ptp_asym_p2p_idx;
    logic [1:0] [PKT_CYL*1  -1:0]                  o_200g_ptp_ts_req;
    logic [1:0] [PKT_CYL*96 -1:0]                  o_200g_ptp_tx_its;
    logic [1:0] [PKT_CYL*PTP_FP_WIDTH-1:0]         o_200g_ptp_fp;
    logic [1:0] [PKT_CYL*1 -1:0]                   i_200g_ptp_ets_valid;
    logic [1:0] [PKT_CYL*96-1:0]                   i_200g_ptp_ets;
    logic [1:0] [PKT_CYL*PTP_FP_WIDTH -1:0]        i_200g_ptp_ets_fp;
    logic [1:0] [PKT_CYL*96-1:0]                   i_200g_ptp_rx_its;
    logic [1:0] [95:0]                             i_200g_ptp_tx_tod;
    logic [1:0]                                    i_200g_ptp_tx_tod_valid;


		logic [3:0]                                    i_100g_clk_tx_tod;
    logic [3:0]                                    i_100g_tx_tod_rst_n;
    logic [3:0] [PKT_CYL*1  -1:0]                  o_100g_ptp_ins_ets;
    logic [3:0] [PKT_CYL*1  -1:0]                  o_100g_ptp_ins_cf;
    logic [3:0] [PKT_CYL*1  -1:0]                  o_100g_ptp_ins_zero_csum;
    logic [3:0] [PKT_CYL*1  -1:0]                  o_100g_ptp_ins_update_eb;
    logic [3:0] [PKT_CYL*16 -1:0]                  o_100g_ptp_ins_ts_offset;
    logic [3:0] [PKT_CYL*16 -1:0]                  o_100g_ptp_ins_cf_offset;
    logic [3:0] [PKT_CYL*16 -1:0]                  o_100g_ptp_ins_csum_offset;
    logic [3:0] [PKT_CYL*1  -1:0]                  o_100g_ptp_p2p;
    logic [3:0] [PKT_CYL*1  -1:0]                  o_100g_ptp_asym;
    logic [3:0] [PKT_CYL*1  -1:0]                  o_100g_ptp_asym_sign;
    logic [3:0] [PKT_CYL*7  -1:0]                  o_100g_ptp_asym_p2p_idx;
    logic [3:0] [PKT_CYL*1  -1:0]                  o_100g_ptp_ts_req;
    logic [3:0] [PKT_CYL*96 -1:0]                  o_100g_ptp_tx_its;
    logic [3:0] [PKT_CYL*PTP_FP_WIDTH-1:0]         o_100g_ptp_fp;
    logic [3:0] [PKT_CYL*1 -1:0]                   i_100g_ptp_ets_valid;
    logic [3:0] [PKT_CYL*96-1:0]                   i_100g_ptp_ets;
    logic [3:0] [PKT_CYL*PTP_FP_WIDTH -1:0]        i_100g_ptp_ets_fp;
    logic [3:0] [PKT_CYL*96-1:0]                   i_100g_ptp_rx_its;
    logic [3:0] [95:0]                             i_100g_ptp_tx_tod;
    logic [3:0]                                    i_100g_ptp_tx_tod_valid;
	



  	//logic [95:0]                             p0_ptp_tx_tod;
    //logic [95:0]                             p0_ptp_rx_tod;
    //logic                                    p0_ptp_tx_tod_valid;
    //logic                                    p0_ptp_rx_tod_valid;
    logic [PKT_CYL*1  -1:0]                  p0_ptp_ins_ets;
    logic [PKT_CYL*1  -1:0]                  p0_ptp_ins_cf;
    logic [PKT_CYL*1  -1:0]                  p0_ptp_ins_zero_csum;
    logic [PKT_CYL*1  -1:0]                  p0_ptp_ins_update_eb;
    logic [PKT_CYL*16 -1:0]                  p0_ptp_ins_ts_offset;
    logic [PKT_CYL*16 -1:0]                  p0_ptp_ins_cf_offset;
    logic [PKT_CYL*16 -1:0]                  p0_ptp_ins_csum_offset;
    logic [PKT_CYL*1  -1:0]                  p0_ptp_p2p;
    logic [PKT_CYL*1  -1:0]                  p0_ptp_asym;
    logic [PKT_CYL*1  -1:0]                  p0_ptp_asym_sign;
    logic [PKT_CYL*7  -1:0]                  p0_ptp_asym_p2p_idx;
    logic [PKT_CYL*1  -1:0]                  p0_ptp_ts_req;
    logic [PKT_CYL*96 -1:0]                  p0_ptp_tx_its;
    logic [PKT_CYL*PTP_FP_WIDTH-1:0]         p0_ptp_fp;
    logic [PKT_CYL*1 -1:0]                 p0_ptp_ets_valid;
    logic [PKT_CYL*96-1:0]                 p0_ptp_ets;
    logic [PKT_CYL*PTP_FP_WIDTH -1:0]      p0_ptp_ets_fp;
    logic [PKT_CYL*96-1:0]                 p0_ptp_rx_its;
    logic                                    p0_tx_ptp_offset_data_valid;
    logic                                    p0_rx_ptp_offset_data_valid;
    logic                                    p0_tx_ptp_ready;
    logic                                    p0_rx_ptp_ready;

		

  	//logic [95:0]                             p1_ptp_tx_tod;
    //logic [95:0]                             p1_ptp_rx_tod;
    //logic                                    p1_ptp_tx_tod_valid;
    //logic                                    p1_ptp_rx_tod_valid;
    logic [PKT_CYL*1  -1:0]                  p1_ptp_ins_ets;
    logic [PKT_CYL*1  -1:0]                  p1_ptp_ins_cf;
    logic [PKT_CYL*1  -1:0]                  p1_ptp_ins_zero_csum;
    logic [PKT_CYL*1  -1:0]                  p1_ptp_ins_update_eb;
    logic [PKT_CYL*16 -1:0]                  p1_ptp_ins_ts_offset;
    logic [PKT_CYL*16 -1:0]                  p1_ptp_ins_cf_offset;
    logic [PKT_CYL*16 -1:0]                  p1_ptp_ins_csum_offset;
    logic [PKT_CYL*1  -1:0]                  p1_ptp_p2p;
    logic [PKT_CYL*1  -1:0]                  p1_ptp_asym;
    logic [PKT_CYL*1  -1:0]                  p1_ptp_asym_sign;
    logic [PKT_CYL*7  -1:0]                  p1_ptp_asym_p2p_idx;
    logic [PKT_CYL*1  -1:0]                  p1_ptp_ts_req;
    logic [PKT_CYL*96 -1:0]                  p1_ptp_tx_its;
    logic [PKT_CYL*PTP_FP_WIDTH-1:0]         p1_ptp_fp;
    logic [PKT_CYL*1 -1:0]                 p1_ptp_ets_valid;
    logic [PKT_CYL*96-1:0]                 p1_ptp_ets;
    logic [PKT_CYL*PTP_FP_WIDTH -1:0]      p1_ptp_ets_fp;
    logic [PKT_CYL*96-1:0]                 p1_ptp_rx_its;
    logic                                    p1_tx_ptp_offset_data_valid;
    logic                                    p1_rx_ptp_offset_data_valid;
    logic                                    p1_tx_ptp_ready;
    logic                                    p1_rx_ptp_ready;


  	//logic [95:0]                             p2_ptp_tx_tod;
    //logic [95:0]                             p2_ptp_rx_tod;
    //logic                                    p2_ptp_tx_tod_valid;
    //logic                                    p2_ptp_rx_tod_valid;
    logic [PKT_CYL*1  -1:0]                  p2_ptp_ins_ets;
    logic [PKT_CYL*1  -1:0]                  p2_ptp_ins_cf;
    logic [PKT_CYL*1  -1:0]                  p2_ptp_ins_zero_csum;
    logic [PKT_CYL*1  -1:0]                  p2_ptp_ins_update_eb;
    logic [PKT_CYL*16 -1:0]                  p2_ptp_ins_ts_offset;
    logic [PKT_CYL*16 -1:0]                  p2_ptp_ins_cf_offset;
    logic [PKT_CYL*16 -1:0]                  p2_ptp_ins_csum_offset;
    logic [PKT_CYL*1  -1:0]                  p2_ptp_p2p;
    logic [PKT_CYL*1  -1:0]                  p2_ptp_asym;
    logic [PKT_CYL*1  -1:0]                  p2_ptp_asym_sign;
    logic [PKT_CYL*7  -1:0]                  p2_ptp_asym_p2p_idx;
    logic [PKT_CYL*1  -1:0]                  p2_ptp_ts_req;
    logic [PKT_CYL*96 -1:0]                  p2_ptp_tx_its;
    logic [PKT_CYL*PTP_FP_WIDTH-1:0]         p2_ptp_fp;
    logic [PKT_CYL*1 -1:0]                 p2_ptp_ets_valid;
    logic [PKT_CYL*96-1:0]                 p2_ptp_ets;
    logic [PKT_CYL*PTP_FP_WIDTH -1:0]      p2_ptp_ets_fp;
    logic [PKT_CYL*96-1:0]                 p2_ptp_rx_its;
    logic                                    p2_tx_ptp_offset_data_valid;
    logic                                    p2_rx_ptp_offset_data_valid;
    logic                                    p2_tx_ptp_ready;
    logic                                    p2_rx_ptp_ready;


  	//logic [95:0]                             p3_ptp_tx_tod;
    ///logic [95:0]                             p3_ptp_rx_tod;
   // logic                                    p3_ptp_tx_tod_valid;
    //logic                                    p3_ptp_rx_tod_valid;
    logic [PKT_CYL*1  -1:0]                  p3_ptp_ins_ets;
    logic [PKT_CYL*1  -1:0]                  p3_ptp_ins_cf;
    logic [PKT_CYL*1  -1:0]                  p3_ptp_ins_zero_csum;
    logic [PKT_CYL*1  -1:0]                  p3_ptp_ins_update_eb;
    logic [PKT_CYL*16 -1:0]                  p3_ptp_ins_ts_offset;
    logic [PKT_CYL*16 -1:0]                  p3_ptp_ins_cf_offset;
    logic [PKT_CYL*16 -1:0]                  p3_ptp_ins_csum_offset;
    logic [PKT_CYL*1  -1:0]                  p3_ptp_p2p;
    logic [PKT_CYL*1  -1:0]                  p3_ptp_asym;
    logic [PKT_CYL*1  -1:0]                  p3_ptp_asym_sign;
    logic [PKT_CYL*7  -1:0]                  p3_ptp_asym_p2p_idx;
    logic [PKT_CYL*1  -1:0]                  p3_ptp_ts_req;
    logic [PKT_CYL*96 -1:0]                  p3_ptp_tx_its;
    logic [PKT_CYL*PTP_FP_WIDTH-1:0]         p3_ptp_fp;
    logic [PKT_CYL*1 -1:0]                 p3_ptp_ets_valid;
    logic [PKT_CYL*96-1:0]                 p3_ptp_ets;
    logic [PKT_CYL*PTP_FP_WIDTH -1:0]      p3_ptp_ets_fp;
    logic [PKT_CYL*96-1:0]                 p3_ptp_rx_its;
    logic                                    p3_tx_ptp_offset_data_valid;
    logic                                    p3_rx_ptp_offset_data_valid;
    logic                                    p3_tx_ptp_ready;
    logic                                    p3_rx_ptp_ready;
		
		localparam NUM_SEG_200G = ( CLIENT_IF_TYPE == 1) ? 'd1 : (512/64);
		localparam NUM_SEG_100G = ( CLIENT_IF_TYPE == 1) ? 'd1 : (256/64); 
		localparam NUM_SEG_50G = ( CLIENT_IF_TYPE == 1) ? 'd1 : (128/64); 

//---------------------------------------------------------------

   	logic [NUM_OF_STREAM-1:0]                       		axis_400g_tx_tvalid_o;
   	logic [NUM_OF_STREAM-1:0][DATA_WIDTH-1:0]      			axis_400g_tx_tdata_o;
   	logic [NUM_OF_STREAM-1:0]                      			axis_400g_tx_tready_i;
   	logic [NUM_OF_STREAM-1:0][DATA_WIDTH/8-1:0]    			axis_400g_tx_tkeep_o;
   	logic [NUM_OF_STREAM-1:0]                      			axis_400g_tx_tlast_o;
   	logic [NUM_OF_STREAM-1:0][TX_TUSER_CLIENT_WIDTH-1:0]axis_400g_tx_tuser_client_o;
   	logic [NUM_OF_STREAM-1:0][93:0]   									axis_400g_tx_tuser_ptp_o;
   	logic [NUM_OF_STREAM-1:0][327:0]   									axis_400g_tx_tuser_ptp_ext_o;
   	logic [NUM_SEG-1:0]			   							   					axis_400g_tx_tuser_last_seg_o;
   	logic [NUM_SEG-1:0]  	          										axis_400g_tx_tuser_pkt_seg_parity_o;


   	logic [NUM_OF_STREAM-1:0][1:0]                   		axis_200g_tx_tvalid_o;
   	logic [NUM_OF_STREAM-1:0][DATA_WIDTH-1:0]      			axis_200g_tx_tdata_o;
   	logic [NUM_OF_STREAM-1:0][1:0]                 			axis_200g_tx_tready_i;
   	logic [NUM_OF_STREAM-1:0][DATA_WIDTH/8-1:0]    			axis_200g_tx_tkeep_o;
   	logic [NUM_OF_STREAM-1:0][1:0]                 			axis_200g_tx_tlast_o;
   	logic [NUM_OF_STREAM-1:0][16-1:0]axis_200g_tx_tuser_client_o;
   	logic [NUM_OF_STREAM-1:0][(2*94)-1:0]   									axis_200g_tx_tuser_ptp_o;
   	logic [NUM_OF_STREAM-1:0][(2*328)-1:0]   									axis_200g_tx_tuser_ptp_ext_o;
   	logic [1:0] [NUM_SEG_200G-1:0]			   							   					axis_200g_tx_tuser_last_seg_o;
   	logic [1:0] [NUM_SEG_200G-1:0]  	          										axis_200g_tx_tuser_pkt_seg_parity_o;


   	logic [NUM_OF_STREAM-1:0][3:0]                   		axis_100g_tx_tvalid_o;
   	logic [NUM_OF_STREAM-1:0][DATA_WIDTH-1:0]      			axis_100g_tx_tdata_o;
   	logic [NUM_OF_STREAM-1:0][3:0]                 			axis_100g_tx_tready_i;
   	logic [NUM_OF_STREAM-1:0][DATA_WIDTH/8-1:0]    			axis_100g_tx_tkeep_o;
   	logic [NUM_OF_STREAM-1:0][3:0]                 			axis_100g_tx_tlast_o;
   	logic [NUM_OF_STREAM-1:0][16-1:0]axis_100g_tx_tuser_client_o;
   	logic [NUM_OF_STREAM-1:0][(4*94)-1:0]   									axis_100g_tx_tuser_ptp_o;
   	logic [NUM_OF_STREAM-1:0][(4*328)-1:0]   									axis_100g_tx_tuser_ptp_ext_o;
   	logic [3:0] [NUM_SEG_100G-1:0]			   							   		axis_100g_tx_tuser_last_seg_o;
   	logic [3:0] [NUM_SEG_100G-1:0]  	          								axis_100g_tx_tuser_pkt_seg_parity_o;

		 //--------------------------------------------------------------------------------
  // AVST-AXIS BRidge
  //--------------------------------------------------------------------------------

  hssi_ss_f_ed_avst2axi_bridge #(
 	  .CLIENT_IF_TYPE                  ( CLIENT_IF_TYPE),
		.DATA_WIDTH                  	   (  1024/*DATA_WIDTH*/),	
		.EMPTY_BITS                   	 ( EMPTY_WIDTH_INT),                
    .NUM_SEG                         ( NUM_SEG),
		.PKT_SEG_PARITY_EN               ( PKT_SEG_PARITY_EN),
    .ST_READY_LATENCY                ( ST_READY_LATENCY),
    .ENABLE_MULTI_STREAM             ( ENABLE_MULTI_STREAM),
    .NUM_OF_STREAM                   ( NUM_OF_STREAM),
	  .CLIENT_WIDTH                    ( TX_TUSER_CLIENT_WIDTH),
	  .NO_OF_BYTES                     ( NO_OF_BYTES),
    .SIM_EMULATE                     ( SIM_MODE ),
    .PREAMBLE_PASS_TH_EN             ( PREAMBLE_PASS_TH_EN ),
    .DW_AVST_DW                      ( DW_AVST_DW),
    .EHIP_RATE                       ( EHIP_RATE),
		.PTP_FP_WIDTH                    ( PTP_FP_WIDTH),
    .TID                             ( TID),
	  .NUM_MAX_PORTS										(NUM_MAX_PORTS),
 		.PKT_SEG_PARITY_WIDTH						(PKT_SEG_PARITY_WIDTH)	,
 		.DR_ENABLE											(DR_ENABLE),
		.PORT_PROFILE										(PORT_PROFILE)		
 
    //.DW_AXI                        ((PREAMBLE_PASS_TH_EN)? 256: DATA_WIDTH)
	  //.RX_TUSER_CLIENT_WIDTH         ( RX_TUSER_CLIENT_WIDTH),
	  //.RX_TUSER_STATS_WIDTH          ( RX_TUSER_STATS_WIDTH),
    //.TILES                         ( TILES),
		) avst2axis_bridge (
    .i_clk_tx                        ( i_clk_tx ),
    .i_tx_reset_n                    ( pkt_client_rst_n_sync ),
    .tx_error_i                      ( i_tx_error ),
    .tx_skip_crc_i                   ( i_tx_skip_crc ),
    .ptp_fp_i                        ( o_400g_ptp_fp ),
    .ptp_ins_ets_i                   ( o_400g_ptp_ins_ets ),
    .ptp_ts_req_i                    ( o_400g_ptp_ts_req ),
    .ptp_tx_its_i                    ( o_400g_ptp_tx_its ),
    .ptp_ins_cf_i                    ( o_400g_ptp_ins_cf ),
    .ptp_ins_zero_csum_i             ( o_400g_ptp_ins_zero_csum ), //chnage it to ptp_ins_zero_csum 
    .ptp_ins_update_eb_i             ( o_400g_ptp_ins_update_eb ),
    .ptp_ins_ts_format_i             ( '0 ),
    .ptp_ins_ts_offset_i             ( o_400g_ptp_ins_ts_offset ),
    .ptp_ins_cf_offset_i             ( o_400g_ptp_ins_cf_offset ),
    .ptp_ins_csum_offset_i           ( o_400g_ptp_ins_csum_offset ),
    .ptp_ins_eb_offset_i             ( '0 ),
    
    .axis_tvalid_o                   ( axis_400g_tx_tvalid_o ),
    .axis_tdata_o                    ( axis_400g_tx_tdata_o  ),
    .axis_tready_i                   ( axis_400g_tx_tready_i ),
    .axis_tkeep_o                    ( axis_400g_tx_tkeep_o ),
    .axis_tlast_o                    ( axis_400g_tx_tlast_o ),
    .axis_tuser_client_o             ( axis_400g_tx_tuser_client_o ),
    .axis_tuser_ptp_o                ( axis_400g_tx_tuser_ptp_o ),
    .axis_tuser_ptp_ext_o            ( axis_400g_tx_tuser_ptp_ext_o ),
    .axis_tuser_last_seg_o	         ( axis_400g_tx_tuser_last_seg_o ),
    .axis_tuser_pkt_seg_parity_o     ( axis_400g_tx_tuser_pkt_seg_parity_o ),
    //.axis_preamble_o               ( o_tx_preamble_pc ),

		//.avst_preamble_i                 (i_tx_preamble ),// tx_preamble
    .avst_valid_i                    (i_tx_valid ),
    .avst_data_i                     (i_tx_data ),
    .avst_empty_i                    (i_tx_empty ),
    .avst_sop_i                      (i_tx_startofpacket ),
    .avst_eop_i                      (i_tx_endofpacket ),
    .avst_ready_o                    (o_tx_ready ),
	
    .o_tx_mac_ready		     					 (o_tx_mac_ready),      		
    .i_tx_mac_valid		     					 (i_tx_mac_valid  ),  
    .i_tx_mac_inframe		   					 (i_tx_mac_inframe),  
    .i_tx_mac_eop_empty		 					 (i_tx_mac_eop_empty),
    .i_tx_mac_data		     					 (i_tx_mac_data   ),  
    .i_tx_mac_error		     					 (i_tx_mac_error  ),  
    .i_tx_mac_skip_crc   	 					 (i_tx_mac_skip_crc )   
	 		     		
      )	;


  //--------------------------------------------------------------------------------
  // AXIS-AVST BRidge
  //--------------------------------------------------------------------------------

  hssi_ss_f_ed_axis2avst_bridge #(
   .EHIP_RATE                       (EHIP_RATE),
   .CLIENT_IF_TYPE                	(CLIENT_IF_TYPE), 
	 .DATA_WIDTH							 				( 1024/*DATA_WIDTH*/),
	 .EMPTY_BITS							 				(EMPTY_WIDTH_INT),  			
   .NUM_SEG                         (NUM_SEG),
	 .PKT_SEG_PARITY_EN            	 	(PKT_SEG_PARITY_EN),
	 .ENABLE_MULTI_STREAM				 			(ENABLE_MULTI_STREAM), //comes from tcl
	 .NUM_OF_STREAM						 				(NUM_OF_STREAM), 		  //comes from tcl
   .TILES                           (TILES),	 
	 .RX_TUSER_CLIENT_WIDTH           (RX_TUSER_CLIENT_WIDTH),
	 .RX_TUSER_STATS_WIDTH            (RX_TUSER_STATS_WIDTH),
	 .NO_OF_BYTES                     (NO_OF_BYTES),
   .SIM_EMULATE                     (SIM_MODE),
   .PREAMBLE_PASS_TH_EN             (PREAMBLE_PASS_TH_EN),
   .DW_AVST_DW                      (DW_AVST_DW),
   .TID                             (TID),
   .ST_READY_LATENCY                (ST_READY_LATENCY),
	  .NUM_MAX_PORTS										(NUM_MAX_PORTS),
 		.PKT_SEG_PARITY_WIDTH						(PKT_SEG_PARITY_WIDTH)	,
 		.DR_ENABLE											(DR_ENABLE)
 
   //.DW_AXI                        ((PREAMBLE_PASS_TH_EN)? 256: DATA_WIDTH)                         
   //.TX_TUSER_CLIENT_WIDTH         (TX_TUSER_CLIENT_WIDTH),
	 )  axis2avst_bridge (
    .i_clk_rx                        ( i_clk_rx ),
    .rx_aresetn                      ( pkt_client_rst_n_sync ),
    .axis_tvalid_i                   ( axis_rx_tvalid_i [0][0] && (dr_mode == 6'd0)),
    .axis_tdata_i                    ( axis_rx_tdata_i ),
//    .axis_tready_o                   ( axis_rx_tready_o [0][0]),
    .axis_tkeep_i                    ( axis_rx_tkeep_i ),
    .axis_tkeep_seg_i                ( axis_rx_tkeep_i[0][(8*NUM_SEG)-1:0]),
    .axis_tlast_i                    ( axis_rx_tlast_i [0][0] && (dr_mode == 6'd0)),
    .axis_tuser_client_i             ( axis_rx_tuser_client_i ),
    .axis_tuser_sts                  ( axis_rx_tuser_sts_i ),
    .axis_tuser_sts_ext              ( axis_rx_tuser_sts_ext_i ),
    .axis_tuser_last_seg			       ( axis_rx_tuser_last_seg_i ),	
    .axis_rx_ptp_its                 ( i_rxingrts0_tdata[95:0]),			 //ptp_rx_its
    .axis_tuser_pkt_seg_parity_i     ( axis_rx_tuser_pkt_seg_parity_i ),   
    //.axis_tkeep_seg_i                ( (CLIENT_IF_TYPE) ? {NUM_SEG*8{1'b0}} : axis_rx_tkeep_i ),
		//.i_axis_rx_tid                   (i_axis_rx_tid),
    // .axis_rx_preamble_i              ( i_rx_preamble_pc ),

		.axis_rx_ptp_its_p2              ( i_rxingrts1_tdata[95:0] ), //added on Jan23
    .o_rx_ptp_its                    ( i_400g_ptp_rx_its ),
		
    .avst_valid_o                    ( o_rx_valid ),
    .avst_data_o                     ( o_rx_data ),
    .avst_empty_o                    ( o_rx_empty ),
    .avst_sop_o                      ( o_rx_startofpacket ),
    .avst_eop_o                      ( o_rx_endofpacket ),
    .avst_ready_i                    ( 1'b1 ),
   // .avst_preamble_o                 ( o_rx_preamble ),

		//outputs of axis2avst_bridge connect to pc
    .i_av_st_rx_ms_ready				 		 ( 1'b1),   
    .o_av_st_rx_ms_data					 		 ( o_rx_mac_data),  	  
    .o_av_st_rx_ms_valid				 		 ( o_rx_mac_valid),    
    .o_av_st_rx_ms_inframe				 	 ( o_rx_mac_inframe),  
    .o_av_st_rx_ms_eop_empty			 	 ( o_rx_mac_eop_empty) 
  );



	genvar ex_200g_bridge;
	generate
    for(ex_200g_bridge = 0; ex_200g_bridge < 2; ex_200g_bridge ++) begin : GEN_EX_200G_BRIDGE
        
 //--------------------------------------------------------------------------------
  // AVST-AXIS BRidge
  //--------------------------------------------------------------------------------

  hssi_ss_f_ed_avst2axi_bridge #(
 	  .CLIENT_IF_TYPE                  ( CLIENT_IF_TYPE),
		.DATA_WIDTH                  	   (  512/*DATA_WIDTH*/),	
		.EMPTY_BITS                   	 ( PREAMBLE_PASS_TH_EN ? (6-1) : 6),                
    .NUM_SEG                         ( ( CLIENT_IF_TYPE == 1) ? 'd1 : (512/64) ),
		.PKT_SEG_PARITY_EN               ( PKT_SEG_PARITY_EN),
    .ST_READY_LATENCY                ( ST_READY_LATENCY),
    .ENABLE_MULTI_STREAM             ( ENABLE_MULTI_STREAM),
    .NUM_OF_STREAM                   ( NUM_OF_STREAM),
	  .CLIENT_WIDTH                    ( (2*512)/64),
	  //.NO_OF_BYTES                     ( ( CLIENT_IF_TYPE == 1) ? 512/8 : 'd8),
	  .NO_OF_BYTES                     ( NO_OF_BYTES),
    .SIM_EMULATE                     ( SIM_MODE ),
    .PREAMBLE_PASS_TH_EN             ( PREAMBLE_PASS_TH_EN ),
    .DW_AVST_DW                      ( (PREAMBLE_PASS_TH_EN)? 512/2: 512),
    .EHIP_RATE                       ( "200G"),
		.PTP_FP_WIDTH                    ( PTP_FP_WIDTH),
    .TID                             ( TID),
	  .NUM_MAX_PORTS										(NUM_MAX_PORTS),
 		.PKT_SEG_PARITY_WIDTH						(PKT_SEG_PARITY_WIDTH)	,
 		.DR_ENABLE											(DR_ENABLE),
		.PORT_PROFILE										(PORT_PROFILE)		 

		) avst2axis_bridge_200g (
    .i_clk_tx                        ( i_clk_tx ),
    .i_tx_reset_n                    ( pkt_client_rst_n_sync ),
    .tx_error_i                      ( i_200g_tx_error[ex_200g_bridge] ),
    .tx_skip_crc_i                   ( i_200g_tx_skip_crc [ex_200g_bridge]),
    .ptp_fp_i                        ( o_200g_ptp_fp [ex_200g_bridge]),
    .ptp_ins_ets_i                   ( o_200g_ptp_ins_ets [ex_200g_bridge]),
    .ptp_ts_req_i                    ( o_200g_ptp_ts_req [ex_200g_bridge]),
    .ptp_tx_its_i                    ( o_200g_ptp_tx_its [ex_200g_bridge]),
    .ptp_ins_cf_i                    ( o_200g_ptp_ins_cf [ex_200g_bridge]),
    .ptp_ins_zero_csum_i             ( o_200g_ptp_ins_zero_csum [ex_200g_bridge]), //chnage it to ptp_ins_zero_csum 
    .ptp_ins_update_eb_i             ( o_200g_ptp_ins_update_eb [ex_200g_bridge]),
    .ptp_ins_ts_format_i             ( '0 ),
    .ptp_ins_ts_offset_i             ( o_200g_ptp_ins_ts_offset [ex_200g_bridge]),
    .ptp_ins_cf_offset_i             ( o_200g_ptp_ins_cf_offset [ex_200g_bridge]),
    .ptp_ins_csum_offset_i           ( o_200g_ptp_ins_csum_offset [ex_200g_bridge]),
    .ptp_ins_eb_offset_i             ( '0 ),
    
    .axis_tvalid_o                   ( axis_200g_tx_tvalid_o [0][ex_200g_bridge]),
    .axis_tdata_o                    ( axis_200g_tx_tdata_o [0] [ex_200g_bridge*512+:512]),
    .axis_tready_i                   ( axis_200g_tx_tready_i [0][ex_200g_bridge]),
    .axis_tkeep_o                    ( axis_200g_tx_tkeep_o [0][ex_200g_bridge*64+:64]),
    .axis_tlast_o                    ( axis_200g_tx_tlast_o [0][ex_200g_bridge]),
    .axis_tuser_client_o             ( axis_200g_tx_tuser_client_o[0] [ex_200g_bridge*8+:8]),
    .axis_tuser_ptp_o                ( axis_200g_tx_tuser_ptp_o[0][ex_200g_bridge*94+:94] ),
    .axis_tuser_ptp_ext_o            ( axis_200g_tx_tuser_ptp_ext_o[0] [ex_200g_bridge*328+:328]),
    .axis_tuser_last_seg_o	         ( axis_200g_tx_tuser_last_seg_o [ex_200g_bridge]),
    .axis_tuser_pkt_seg_parity_o     ( axis_200g_tx_tuser_pkt_seg_parity_o [ex_200g_bridge]),
    //.axis_preamble_o               ( o_tx_preamble_pc ),

//		.avst_preamble_i                 (i_200g_tx_preamble [ex_200g_pc*64+:64]),// tx_preamble
    .avst_valid_i                    (i_200g_tx_valid [ex_200g_bridge]),
    .avst_data_i                     (i_200g_tx_data [ex_200g_bridge*512+:512]),
    .avst_empty_i                    (i_200g_tx_empty [ex_200g_bridge*4+:4]),
    .avst_sop_i                      (i_200g_tx_startofpacket [ex_200g_bridge]),
    .avst_eop_i                      (i_200g_tx_endofpacket [ex_200g_bridge]),
    .avst_ready_o                    (o_200g_tx_ready [ex_200g_bridge]),
	
    .o_tx_mac_ready		     					 (o_200g_tx_mac_ready [ex_200g_bridge]),      		
    .i_tx_mac_valid		     					 (i_200g_tx_mac_valid  [ex_200g_bridge]),  
    .i_tx_mac_inframe		   					 (i_200g_tx_mac_inframe[ex_200g_bridge*8+:8]),  
    .i_tx_mac_eop_empty		 					 (i_200g_tx_mac_eop_empty[ex_200g_bridge*24+:24]),
    .i_tx_mac_data		     					 (i_200g_tx_mac_data [ex_200g_bridge*512+:512]  ),  
    .i_tx_mac_error		     					 (i_200g_tx_mac_error [ex_200g_bridge*8+:8] ),  
    .i_tx_mac_skip_crc   	 					 (i_200g_tx_mac_skip_crc [ex_200g_bridge*8+:8])   
	 		     		
      )	;


  //--------------------------------------------------------------------------------
  // AXIS-AVST BRidge
  //--------------------------------------------------------------------------------

  hssi_ss_f_ed_axis2avst_bridge #(
   .EHIP_RATE                       ("200G"),
   .CLIENT_IF_TYPE                	(CLIENT_IF_TYPE), 
	 .DATA_WIDTH							 				( 512/*DATA_WIDTH*/),
	 .EMPTY_BITS							 				(EMPTY_WIDTH_INT),  			
   .NUM_SEG                         (( CLIENT_IF_TYPE == 1) ? 'd1 : (512/64)),
	 .PKT_SEG_PARITY_EN            	 	(PKT_SEG_PARITY_EN),
	 .ENABLE_MULTI_STREAM				 			(ENABLE_MULTI_STREAM), //comes from tcl
	 .NUM_OF_STREAM						 				(NUM_OF_STREAM), 		  //comes from tcl
   .TILES                           (TILES),	 
	 .RX_TUSER_CLIENT_WIDTH           (56),
	 .RX_TUSER_STATS_WIDTH            (40),
	 //.NO_OF_BYTES                     ( ( CLIENT_IF_TYPE == 1) ? 512/8 : 'd8),
	 .NO_OF_BYTES                     ( ( CLIENT_IF_TYPE == 1) ? 256/8 : NO_OF_BYTES),
   .SIM_EMULATE                     (SIM_MODE),
   .PREAMBLE_PASS_TH_EN             (PREAMBLE_PASS_TH_EN),
   .DW_AVST_DW                      ((PREAMBLE_PASS_TH_EN)? 512/2: 512),
   .TID                             (TID),
   .ST_READY_LATENCY                (ST_READY_LATENCY),
	  .NUM_MAX_PORTS										(NUM_MAX_PORTS),
 		.PKT_SEG_PARITY_WIDTH						(PKT_SEG_PARITY_WIDTH)	 ,
 		.DR_ENABLE											(DR_ENABLE)

	 )  axis2avst_bridge_200g (
    .i_clk_rx                        ( i_clk_rx ),
    .rx_aresetn                      ( pkt_client_rst_n_sync ),
    .axis_tvalid_i                   ( axis_rx_tvalid_i[0] [ex_200g_bridge] && ( (dr_mode==6'h10))),
    .axis_tdata_i                    ( axis_rx_tdata_i [0][ex_200g_bridge*512+:512]),
    .axis_tkeep_i                    ( axis_rx_tkeep_i [0][ex_200g_bridge*64+:64]),    
    .axis_tkeep_seg_i                ( axis_rx_tkeep_i[0][ex_200g_bridge*64+:64]),
    .axis_tlast_i                    ( axis_rx_tlast_i [0][ex_200g_bridge] && ( (dr_mode==6'h10))),
    .axis_tuser_client_i             ( axis_rx_tuser_client_i[0][ex_200g_bridge*56+:56] ),
    .axis_tuser_sts                  ( axis_rx_tuser_sts_i[0][ex_200g_bridge*40+:40] ),
    .axis_tuser_sts_ext              ( axis_rx_tuser_sts_ext_i),
    .axis_tuser_last_seg			       (  CLIENT_IF_TYPE ? axis_rx_tuser_last_seg_i : axis_rx_tuser_last_seg_i [ex_200g_bridge*8+:8]),	
    .axis_tuser_pkt_seg_parity_i     (  CLIENT_IF_TYPE ? axis_rx_tuser_pkt_seg_parity_i : axis_rx_tuser_pkt_seg_parity_i [ex_200g_bridge]),   
		.axis_rx_ptp_its                 ( i_rxingrts0_tdata[ex_200g_bridge*96+:96] ),			 //ptp_rx_its

		.axis_rx_ptp_its_p2              ( i_rxingrts1_tdata[ex_200g_bridge*96+:96]  ), //added on Jan23
    .o_rx_ptp_its                    ( i_200g_ptp_rx_its [ex_200g_bridge]),
		
    .avst_valid_o                    ( o_200g_rx_valid[ex_200g_bridge] ),
    .avst_data_o                     ( o_200g_rx_data[ex_200g_bridge*512+:512] ),
    .avst_empty_o                    ( o_200g_rx_empty[ex_200g_bridge*24+:24] ),
    .avst_sop_o                      ( o_200g_rx_startofpacket[ex_200g_bridge] ),
    .avst_eop_o                      ( o_200g_rx_endofpacket[ex_200g_bridge] ),
    .avst_ready_i                    ( 1'b1 ),
//    .avst_preamble_o                 ( o_200g_rx_preamble[ex_200g_bridge*64+:64] ),

		//outputs of axis2avst_bridge connect to pc
    .i_av_st_rx_ms_ready				 		 ( 1'b1),   
    .o_av_st_rx_ms_data					 		 ( o_200g_rx_mac_data[ex_200g_bridge*512+:512]),  	  
    .o_av_st_rx_ms_valid				 		 ( o_200g_rx_mac_valid[ex_200g_bridge]),    
    .o_av_st_rx_ms_inframe				 	 ( o_200g_rx_mac_inframe[ex_200g_bridge*8+:8]),  
    .o_av_st_rx_ms_eop_empty			 	 ( o_200g_rx_mac_eop_empty[ex_200g_bridge*24+:24]) 
  );
end
endgenerate



	genvar ex_100g_bridge;
	generate
    for(ex_100g_bridge = 0; ex_100g_bridge < 4; ex_100g_bridge ++) begin : GEN_EX_100G_BRIDGE
        
 //--------------------------------------------------------------------------------
  // AVST-AXIS BRidge
  //--------------------------------------------------------------------------------

  hssi_ss_f_ed_avst2axi_bridge #(
 	  .CLIENT_IF_TYPE                  ( CLIENT_IF_TYPE),
 
		.DATA_WIDTH                  	   (  256/*DATA_WIDTH*/),	
		.EMPTY_BITS                   	 (  PREAMBLE_PASS_TH_EN ? (5-1) : 5),                
    .NUM_SEG                         ( ( CLIENT_IF_TYPE == 1) ? 'd1 : (256/64) ),
		.PKT_SEG_PARITY_EN               ( PKT_SEG_PARITY_EN),
    .ST_READY_LATENCY                ( ST_READY_LATENCY),
    .ENABLE_MULTI_STREAM             ( ENABLE_MULTI_STREAM),
    .NUM_OF_STREAM                   ( NUM_OF_STREAM),
	  .CLIENT_WIDTH                    ( (2*256)/64),
	  .NO_OF_BYTES                     ( CLIENT_IF_TYPE ? 256/8: NO_OF_BYTES),
    .SIM_EMULATE                     ( SIM_MODE ),
    .PREAMBLE_PASS_TH_EN             ( PREAMBLE_PASS_TH_EN ),
    .DW_AVST_DW                      ( (PREAMBLE_PASS_TH_EN)? 256/2: 256),
    .EHIP_RATE                       ( "100G"),
		.PTP_FP_WIDTH                    ( PTP_FP_WIDTH),
    .TID                             ( TID),
	  .NUM_MAX_PORTS										(NUM_MAX_PORTS),
 		.PKT_SEG_PARITY_WIDTH						(PKT_SEG_PARITY_WIDTH)	 ,
 		.DR_ENABLE											(DR_ENABLE),
		.PORT_PROFILE										(PORT_PROFILE)		

		) avst2axis_bridge_100g (
    .i_clk_tx                        ( i_clk_tx ),
    .i_tx_reset_n                    ( pkt_client_rst_n_sync ),
    .tx_error_i                      ( i_100g_tx_error[ex_100g_bridge] ),
    .tx_skip_crc_i                   ( i_100g_tx_skip_crc [ex_100g_bridge]),
    .ptp_fp_i                        ( o_100g_ptp_fp [ex_100g_bridge]),
    .ptp_ins_ets_i                   ( o_100g_ptp_ins_ets [ex_100g_bridge]),
    .ptp_ts_req_i                    ( o_100g_ptp_ts_req [ex_100g_bridge]),
    .ptp_tx_its_i                    ( o_100g_ptp_tx_its [ex_100g_bridge]),
    .ptp_ins_cf_i                    ( o_100g_ptp_ins_cf [ex_100g_bridge]),
    .ptp_ins_zero_csum_i             ( o_100g_ptp_ins_zero_csum [ex_100g_bridge]), //chnage it to ptp_ins_zero_csum 
    .ptp_ins_update_eb_i             ( o_100g_ptp_ins_update_eb [ex_100g_bridge]),
    .ptp_ins_ts_format_i             ( '0 ),
    .ptp_ins_ts_offset_i             ( o_100g_ptp_ins_ts_offset [ex_100g_bridge]),
    .ptp_ins_cf_offset_i             ( o_100g_ptp_ins_cf_offset [ex_100g_bridge]),
    .ptp_ins_csum_offset_i           ( o_100g_ptp_ins_csum_offset [ex_100g_bridge]),
    .ptp_ins_eb_offset_i             ( '0 ),
    
    .axis_tvalid_o                   ( axis_100g_tx_tvalid_o[0] [ex_100g_bridge]),
    .axis_tdata_o                    ( axis_100g_tx_tdata_o [0] [ex_100g_bridge*256+:256]),
    .axis_tready_i                   ( axis_100g_tx_tready_i[0] [ex_100g_bridge]),
    .axis_tkeep_o                    ( axis_100g_tx_tkeep_o [0][ex_100g_bridge*32+:32]),
    .axis_tlast_o                    ( axis_100g_tx_tlast_o [0][ex_100g_bridge]),
    .axis_tuser_client_o             ( axis_100g_tx_tuser_client_o[0][ex_100g_bridge*4+:4] ),
    .axis_tuser_ptp_o                ( axis_100g_tx_tuser_ptp_o[0][ex_100g_bridge*94+:94] ),
    .axis_tuser_ptp_ext_o            ( axis_100g_tx_tuser_ptp_ext_o[0][ex_100g_bridge*328+:328] ),
    .axis_tuser_last_seg_o	         ( axis_100g_tx_tuser_last_seg_o [ex_100g_bridge]),
    .axis_tuser_pkt_seg_parity_o     ( axis_100g_tx_tuser_pkt_seg_parity_o [ex_100g_bridge]),
    //.axis_preamble_o               ( o_tx_preamble_pc ),

//		.avst_preamble_i                 (i_100g_tx_preamble [ex_100g_pc*64+:64]),// tx_preamble
    .avst_valid_i                    (i_100g_tx_valid [ex_100g_bridge]),
    .avst_data_i                     (i_100g_tx_data [ex_100g_bridge*256+:256]),
    .avst_empty_i                    (i_100g_tx_empty [ex_100g_bridge*3+:3]),
    .avst_sop_i                      (i_100g_tx_startofpacket [ex_100g_bridge]),
    .avst_eop_i                      (i_100g_tx_endofpacket [ex_100g_bridge]),
    .avst_ready_o                    (o_100g_tx_ready [ex_100g_bridge]),
	
    .o_tx_mac_ready		     					 (o_100g_tx_mac_ready [ex_100g_bridge]),      		
    .i_tx_mac_valid		     					 (i_100g_tx_mac_valid  [ex_100g_bridge]),  
    .i_tx_mac_inframe		   					 (i_100g_tx_mac_inframe[ex_100g_bridge*4+:4]),  
    .i_tx_mac_eop_empty		 					 (i_100g_tx_mac_eop_empty[ex_100g_bridge*12+:12]),
    .i_tx_mac_data		     					 (i_100g_tx_mac_data [ex_100g_bridge*256+:256]  ),  
    .i_tx_mac_error		     					 (i_100g_tx_mac_error [ex_100g_bridge*4+:4] ),  
    .i_tx_mac_skip_crc   	 					 (i_100g_tx_mac_skip_crc [ex_100g_bridge*4+:4])   
	 		     		
      )	;


  //--------------------------------------------------------------------------------
  // AXIS-AVST BRidge
  //--------------------------------------------------------------------------------

  hssi_ss_f_ed_axis2avst_bridge #(
   .EHIP_RATE                       (EHIP_RATE),
   .CLIENT_IF_TYPE                	(CLIENT_IF_TYPE), 
	 .DATA_WIDTH							 				( 256/*DATA_WIDTH*/),
	 .EMPTY_BITS							 				(PREAMBLE_PASS_TH_EN ? (4-1) : 4),  			
   .NUM_SEG                         (( CLIENT_IF_TYPE == 1) ? 'd1 : (256/64)),
	 .PKT_SEG_PARITY_EN            	 	(PKT_SEG_PARITY_EN),
	 .ENABLE_MULTI_STREAM				 			(ENABLE_MULTI_STREAM), //comes from tcl
	 .NUM_OF_STREAM						 				(NUM_OF_STREAM), 		  //comes from tcl
   .TILES                           (TILES),	 
	 .RX_TUSER_CLIENT_WIDTH           ((256*7)/64),
	 .RX_TUSER_STATS_WIDTH            ((256*5)/64),
	 //.NO_OF_BYTES                     ( ( CLIENT_IF_TYPE == 1) ? 256/8 : NO_OF_BYTES),
	 .NO_OF_BYTES                     (  (CLIENT_IF_TYPE == 1) ? 256/8 : NO_OF_BYTES),
   .SIM_EMULATE                     (SIM_MODE),
   .PREAMBLE_PASS_TH_EN             (PREAMBLE_PASS_TH_EN),
   .DW_AVST_DW                      ((PREAMBLE_PASS_TH_EN)? 256/2: 256),
   .TID                             (TID),
   .ST_READY_LATENCY                (ST_READY_LATENCY),
	  .NUM_MAX_PORTS										(NUM_MAX_PORTS),
 		.PKT_SEG_PARITY_WIDTH						(PKT_SEG_PARITY_WIDTH)	,
 		.DR_ENABLE											(DR_ENABLE) 

	 )  axis2avst_bridge_100g (
    .i_clk_rx                        ( i_clk_rx ),
    .rx_aresetn                      ( pkt_client_rst_n_sync ),
    .axis_tvalid_i                   ( axis_rx_tvalid_i [0][ex_100g_bridge] && ((dr_mode==6'h20))),
    .axis_tdata_i                    ( axis_rx_tdata_i [0][ex_100g_bridge*256+:256]),
////    .axis_tready_o                   ( axis_rx_tready_o),
    .axis_tkeep_i                    ( axis_rx_tkeep_i [0][ex_100g_bridge*32+:32]),
    //.axis_tkeep_seg_i                ( axis_rx_tkeep_i[0][(8*NUM_SEG)-1:0]),
    .axis_tkeep_seg_i                ( axis_rx_tkeep_i[0][ex_100g_bridge*32+:32]),
    .axis_tlast_i                    ( axis_rx_tlast_i [0][ex_100g_bridge] && ( (dr_mode==6'h20))),
    .axis_tuser_client_i             ( axis_rx_tuser_client_i[0][ex_100g_bridge*28+:28] ),
    .axis_tuser_sts                  ( axis_rx_tuser_sts_i[0][ex_100g_bridge*20+:20] ),
    .axis_tuser_sts_ext              ( axis_rx_tuser_sts_ext_i),
    .axis_tuser_last_seg			       ( CLIENT_IF_TYPE ? axis_rx_tuser_last_seg_i : axis_rx_tuser_last_seg_i [ex_100g_bridge*4+:4]),	
    .axis_tuser_pkt_seg_parity_i     (  CLIENT_IF_TYPE ? axis_rx_tuser_pkt_seg_parity_i : axis_rx_tuser_pkt_seg_parity_i [ex_100g_bridge*4+:4]),   
		.axis_rx_ptp_its                 ( i_rxingrts0_tdata[ex_100g_bridge*96+:96] ),			 //ptp_rx_its

		.axis_rx_ptp_its_p2              ( i_rxingrts1_tdata[ex_50g_bridge*96+:96] ),
    .o_rx_ptp_its                    ( i_100g_ptp_rx_its [ex_100g_bridge]),
		
    .avst_valid_o                    ( o_100g_rx_valid[ex_100g_bridge] ),
    .avst_data_o                     ( o_100g_rx_data[ex_100g_bridge*256+:256] ),
    .avst_empty_o                    ( o_100g_rx_empty[ex_100g_bridge*6+:6] ),
    .avst_sop_o                      ( o_100g_rx_startofpacket[ex_100g_bridge] ),
    .avst_eop_o                      ( o_100g_rx_endofpacket[ex_100g_bridge] ),
    .avst_ready_i                    ( 1'b1 ),
//    .avst_preamble_o                 ( o_100g_rx_preamble[ex_100g_bridge*64+:64] ),

		//outputs of axis2avst_bridge connect to pc
    .i_av_st_rx_ms_ready				 		 ( 1'b1),   
    .o_av_st_rx_ms_data					 		 ( o_100g_rx_mac_data[ex_100g_bridge*256+:256]),  	  
    .o_av_st_rx_ms_valid				 		 ( o_100g_rx_mac_valid[ex_100g_bridge]),    
    .o_av_st_rx_ms_inframe				 	 ( o_100g_rx_mac_inframe[ex_100g_bridge*4+:4]),  
    .o_av_st_rx_ms_eop_empty			 	 ( o_100g_rx_mac_eop_empty[ex_100g_bridge*12+:12]) 
  );
end
endgenerate





//---------------------------------------------------------------
// MUX TX and RX datapath to different packet generator/checkers
//---------------------------------------------------------------
always @(*) begin
     if (dr_mode ==  DR_MODE_1X400GE_8) begin
			axis_tx_tvalid_o 							= axis_400g_tx_tvalid_o;
			axis_tx_tdata_o 							= axis_400g_tx_tdata_o;
			axis_400g_tx_tready_i 					= {3'b0,axis_tx_tready_i[0][0]};
						axis_100g_tx_tready_i 					= 0; 
			axis_200g_tx_tready_i 					= 0;
			axis_tx_tkeep_o 							= axis_400g_tx_tkeep_o;
			axis_tx_tlast_o   						= axis_400g_tx_tlast_o;
			axis_tx_tuser_client_o 				= axis_400g_tx_tuser_client_o;
			axis_tx_tuser_ptp_o    				= axis_400g_tx_tuser_ptp_o;
			axis_tx_tuser_ptp_ext_o       = axis_400g_tx_tuser_ptp_ext_o;
			axis_tx_tuser_last_seg_o			= axis_400g_tx_tuser_last_seg_o;
			axis_tx_tuser_pkt_seg_parity_o= axis_400g_tx_tuser_pkt_seg_parity_o;
    end else if (dr_mode == DR_MODE_2X200GE_4) begin
			axis_tx_tvalid_o 							= axis_200g_tx_tvalid_o;
			axis_tx_tdata_o 							= axis_200g_tx_tdata_o;
			axis_200g_tx_tready_i 				= {axis_tx_tready_i[0][2],axis_tx_tready_i[0][0]};
			axis_400g_tx_tready_i 				= 0; 
			axis_100g_tx_tready_i 				= 0; 
			axis_tx_tkeep_o 							= axis_200g_tx_tkeep_o;
			axis_tx_tlast_o   						= axis_200g_tx_tlast_o;
			axis_tx_tuser_client_o 				= axis_200g_tx_tuser_client_o;
			axis_tx_tuser_ptp_o    				= axis_200g_tx_tuser_ptp_o;
			axis_tx_tuser_ptp_ext_o       = axis_200g_tx_tuser_ptp_ext_o;
			axis_tx_tuser_last_seg_o			= axis_200g_tx_tuser_last_seg_o;
			axis_tx_tuser_pkt_seg_parity_o= axis_200g_tx_tuser_pkt_seg_parity_o;
    end else if (dr_mode == DR_MODE_4X100GE_2) begin
			axis_tx_tvalid_o 							= axis_100g_tx_tvalid_o;
			axis_tx_tdata_o 							= axis_100g_tx_tdata_o;
			axis_100g_tx_tready_i 			  = axis_tx_tready_i;
			
			axis_400g_tx_tready_i 				= 0; 
			axis_200g_tx_tready_i 				= 0;
			axis_tx_tkeep_o 							= axis_100g_tx_tkeep_o;
			axis_tx_tlast_o   						= axis_100g_tx_tlast_o;
			axis_tx_tuser_client_o 				= axis_100g_tx_tuser_client_o;
			axis_tx_tuser_ptp_o    				= axis_100g_tx_tuser_ptp_o;
			axis_tx_tuser_ptp_ext_o       = axis_100g_tx_tuser_ptp_ext_o;
			axis_tx_tuser_last_seg_o			= axis_100g_tx_tuser_last_seg_o;
			axis_tx_tuser_pkt_seg_parity_o= axis_100g_tx_tuser_pkt_seg_parity_o;
		end else begin
			axis_tx_tvalid_o 							= 0; 
			axis_tx_tdata_o 							= 0; 
			axis_100g_tx_tready_i 					= 0; 
			axis_200g_tx_tready_i 					= 0; 
			axis_400g_tx_tready_i 				= 0; 
			axis_tx_tkeep_o 							= 0; 
			axis_tx_tlast_o   						= 0; 
			axis_tx_tuser_client_o 				= 0; 
			axis_tx_tuser_ptp_o    				= 0; 
			axis_tx_tuser_ptp_ext_o       = 0; 
			axis_tx_tuser_last_seg_o			= 0; 
			axis_tx_tuser_pkt_seg_parity_o= 0; 
    end
end

//---------------------------------------------------------------
    //---dummy Avst interface input signals for Segmented mode---

    assign o_rx_error          			= 6'b0;
    assign o_rxstatus_data     			= 40'b0;
    assign o_rxstatus_valid    			= 1'b1;

    assign o_rx_preamble 						= 64'hFB55_5555_5555_55D5;

    //---dummy 4x25G Avst interface input signals for Segmented mode---

    assign o_100g_rx_error          = {4*6{1'b0}};
    assign o_100g_rxstatus_data     = {4*40{1'b0}};
    assign o_100g_rxstatus_valid    = {4{1'b1}};

    assign o_100g_rx_preamble 				= {4{64'hFB55_5555_5555_55D5}};

    //---dummy 2x50G Avst interface input signals for Segmented mode---

    assign o_200g_rx_error          = {2*6{1'b0}};
    assign o_200g_rxstatus_data     = {2*40{1'b0}};
    assign o_200g_rxstatus_valid    = {2{1'b1}};

    assign o_200g_rx_preamble 				= {2{64'hFB55_5555_5555_55D5}};



		
	logic i_p0_rst_n;
logic i_p1_rst_n;
logic i_p2_rst_n;
logic i_p3_rst_n;	


// ETH 100G
assign i_100g_clk_tx     = {4{i_clk_tx}};
assign i_100g_clk_rx     = {4{i_clk_rx}};
assign i_100g_rst_n      = {i_p3_rst_n, i_p2_rst_n, i_p1_rst_n, i_p0_rst_n};    

// ETH 200G
assign i_200g_clk_tx     = {2{i_clk_tx}};
assign i_200g_clk_rx     = {2{i_clk_rx}};
assign i_200g_rst_n      = {i_p2_rst_n, i_p0_rst_n};

//---------------------------------------------------------------
//---------------------------------------------------------------
always @(*) begin
    if (dr_mode == DR_MODE_1X400GE_8) begin
      //-----------------------------------------------
      p0_ptp_ins_ets             = o_400g_ptp_ins_ets[0];
      p0_ptp_ins_cf              = o_400g_ptp_ins_cf[0];
      p0_ptp_ins_zero_csum       = o_400g_ptp_ins_zero_csum[0];
      p0_ptp_ins_update_eb       = o_400g_ptp_ins_update_eb[0];
      p0_ptp_ins_ts_offset       = o_400g_ptp_ins_ts_offset[15:0];
      p0_ptp_ins_cf_offset       = o_400g_ptp_ins_cf_offset[15:0];
      p0_ptp_ins_csum_offset     = o_400g_ptp_ins_csum_offset[15:0];
      p0_ptp_p2p                 = o_400g_ptp_p2p[0];
      p0_ptp_asym                = o_400g_ptp_asym[0];
      p0_ptp_asym_sign           = o_400g_ptp_asym_sign[0];
      p0_ptp_asym_p2p_idx        = o_400g_ptp_asym_p2p_idx[6:0];
      p0_ptp_ts_req              = o_400g_ptp_ts_req[0];
      p0_ptp_tx_its              = o_400g_ptp_tx_its[95:0];
      p0_ptp_fp                  = o_400g_ptp_fp[7:0];
      //----
      i_400g_ptp_ets_valid[0]    = p0_ptp_ets_valid;
      i_400g_ptp_ets[95:0]       = p0_ptp_ets;
      i_400g_ptp_ets_fp[7:0]     = p0_ptp_ets_fp;
//      i_400g_ptp_rx_its[95:0]    = p0_ptp_rx_its;
      i_400g_ptp_tx_tod          = p0_ptp_tx_tod;
      i_400g_ptp_tx_tod_valid    = p0_ptp_tx_tod_valid;
      //----
      i_200g_ptp_ets_valid   [0] = {PKT_CYL{1'b0}};
      i_200g_ptp_ets         [0] = {PKT_CYL*96{1'b0}};
      i_200g_ptp_ets_fp      [0] = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_200g_ptp_rx_its      [0] = {PKT_CYL*96{1'b0}};
      i_200g_ptp_tx_tod      [0] = 96'b0;
      i_200g_ptp_tx_tod_valid[0] = 1'b0;
      //----
      i_100g_ptp_ets_valid   [0] = {PKT_CYL{1'b0}};
      i_100g_ptp_ets         [0] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_ets_fp      [0] = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_100g_ptp_rx_its      [0] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_tx_tod      [0] = 96'b0;
      i_100g_ptp_tx_tod_valid[0] = 1'b0;
      //-----------------------------------------------
      p1_ptp_ins_ets             = {PKT_CYL{1'b0}};
      p1_ptp_ins_cf              = {PKT_CYL{1'b0}};
      p1_ptp_ins_zero_csum       = {PKT_CYL{1'b0}};
      p1_ptp_ins_update_eb       = {PKT_CYL{1'b0}};
      p1_ptp_ins_ts_offset       = {PKT_CYL*96{1'b0}};
      p1_ptp_ins_cf_offset       = {PKT_CYL*96{1'b0}};
      p1_ptp_ins_csum_offset     = {PKT_CYL*96{1'b0}};
      p1_ptp_p2p                 = {PKT_CYL{1'b0}};
      p1_ptp_asym                = {PKT_CYL{1'b0}};
      p1_ptp_asym_sign           = {PKT_CYL{1'b0}};
      p1_ptp_asym_p2p_idx        = {PKT_CYL*7{1'b0}};
      p1_ptp_ts_req              = {PKT_CYL{1'b0}};
      p1_ptp_tx_its              = {PKT_CYL*96{1'b0}};
      p1_ptp_fp                  = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
      //----
      i_100g_ptp_ets_valid   [1] = {PKT_CYL{1'b0}};
      i_100g_ptp_ets         [1] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_ets_fp      [1] = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_100g_ptp_rx_its      [1] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_tx_tod      [1] = 96'b0;
      i_100g_ptp_tx_tod_valid[1] = 1'b0;
      //-----------------------------------------------
      p2_ptp_ins_ets             = o_400g_ptp_ins_ets[1];
      p2_ptp_ins_cf              = o_400g_ptp_ins_cf[1];
      p2_ptp_ins_zero_csum       = o_400g_ptp_ins_zero_csum[1];
      p2_ptp_ins_update_eb       = o_400g_ptp_ins_update_eb[1];
      p2_ptp_ins_ts_offset       = o_400g_ptp_ins_ts_offset[31:16];
      p2_ptp_ins_cf_offset       = o_400g_ptp_ins_cf_offset[31:16];
      p2_ptp_ins_csum_offset     = o_400g_ptp_ins_csum_offset[31:16];
      p2_ptp_p2p                 = o_400g_ptp_p2p[1];
      p2_ptp_asym                = o_400g_ptp_asym[1];
      p2_ptp_asym_sign           = o_400g_ptp_asym_sign[1];
      p2_ptp_asym_p2p_idx        = o_400g_ptp_asym_p2p_idx[13:7];
      p2_ptp_ts_req              = o_400g_ptp_ts_req[0];
      p2_ptp_tx_its              = o_400g_ptp_tx_its[191:96];
      p2_ptp_fp                  = o_400g_ptp_fp[15:8];
      //----
      i_400g_ptp_ets_valid[1]    = p2_ptp_ets_valid;
      i_400g_ptp_ets[191:96]     = p2_ptp_ets;
      i_400g_ptp_ets_fp[15:8]    = p2_ptp_ets_fp;
//      i_400g_ptp_rx_its[191:96]  = p2_ptp_rx_its;
      //----
      i_200g_ptp_ets_valid   [1] = {PKT_CYL{1'b0}};
      i_200g_ptp_ets         [1] = {PKT_CYL*96{1'b0}};
      i_200g_ptp_ets_fp      [1] = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_200g_ptp_rx_its      [1] = {PKT_CYL*96{1'b0}};
      i_200g_ptp_tx_tod      [1] = 96'b0;
      i_200g_ptp_tx_tod_valid[1] = 1'b0;
      //----
      i_100g_ptp_ets_valid   [2] = {PKT_CYL{1'b0}};
      i_100g_ptp_ets         [2] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_ets_fp      [2] = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_100g_ptp_rx_its      [2] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_tx_tod      [2] = 96'b0;
      i_100g_ptp_tx_tod_valid[2] = 1'b0;
      //-----------------------------------------------
      p3_ptp_ins_ets             = {PKT_CYL{1'b0}};
      p3_ptp_ins_cf              = {PKT_CYL{1'b0}};
      p3_ptp_ins_zero_csum       = {PKT_CYL{1'b0}};
      p3_ptp_ins_update_eb       = {PKT_CYL{1'b0}};
      p3_ptp_ins_ts_offset       = {PKT_CYL*96{1'b0}};
      p3_ptp_ins_cf_offset       = {PKT_CYL*96{1'b0}};
      p3_ptp_ins_csum_offset     = {PKT_CYL*96{1'b0}};
      p3_ptp_p2p                 = {PKT_CYL{1'b0}};
      p3_ptp_asym                = {PKT_CYL{1'b0}};
      p3_ptp_asym_sign           = {PKT_CYL{1'b0}};
      p3_ptp_asym_p2p_idx        = {PKT_CYL*7{1'b0}};
      p3_ptp_ts_req              = {PKT_CYL{1'b0}};
      p3_ptp_tx_its              = {PKT_CYL*96{1'b0}};
      p3_ptp_fp                  = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
      //----
      i_100g_ptp_ets_valid   [3] = {PKT_CYL{1'b0}};
      i_100g_ptp_ets         [3] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_ets_fp      [3] = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_100g_ptp_rx_its      [3] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_tx_tod      [3] = 96'b0;
      i_100g_ptp_tx_tod_valid[3] = 1'b0;

    end else if (dr_mode == DR_MODE_2X200GE_4) begin
      //-----------------------------------------------
      p0_ptp_ins_ets             = o_200g_ptp_ins_ets[0];
      p0_ptp_ins_cf              = o_200g_ptp_ins_cf[0];
      p0_ptp_ins_zero_csum       = o_200g_ptp_ins_zero_csum[0];
      p0_ptp_ins_update_eb       = o_200g_ptp_ins_update_eb[0];
      p0_ptp_ins_ts_offset       = o_200g_ptp_ins_ts_offset[0];
      p0_ptp_ins_cf_offset       = o_200g_ptp_ins_cf_offset[0];
      p0_ptp_ins_csum_offset     = o_200g_ptp_ins_csum_offset[0];
      p0_ptp_p2p                 = o_200g_ptp_p2p[0];
      p0_ptp_asym                = o_200g_ptp_asym[0];
      p0_ptp_asym_sign           = o_200g_ptp_asym_sign[0];
      p0_ptp_asym_p2p_idx        = o_200g_ptp_asym_p2p_idx[0];
      p0_ptp_ts_req              = o_200g_ptp_ts_req[0];
      p0_ptp_tx_its              = o_200g_ptp_tx_its[0];
      p0_ptp_fp                  = o_200g_ptp_fp[0];
      //----
      i_400g_ptp_ets_valid[0]    = {PKT_CYL{1'b0}};
      i_400g_ptp_ets[95:0]       = {PKT_CYL*96{1'b0}};
      i_400g_ptp_ets_fp[7:0]     = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_400g_ptp_rx_its[95:0]    = {PKT_CYL*96{1'b0}};
      i_400g_ptp_tx_tod          = 96'b0;
      i_400g_ptp_tx_tod_valid    = 1'b0;
      //----
      i_200g_ptp_ets_valid   [0] = p0_ptp_ets_valid;
      i_200g_ptp_ets         [0] = p0_ptp_ets;
      i_200g_ptp_ets_fp      [0] = p0_ptp_ets_fp;
//      i_200g_ptp_rx_its      [0] = p0_ptp_rx_its;
      i_200g_ptp_tx_tod      [0] = p0_ptp_tx_tod;
      i_200g_ptp_tx_tod_valid[0] = p0_ptp_tx_tod_valid;
      //----
      i_100g_ptp_ets_valid   [0] = {PKT_CYL{1'b0}};
      i_100g_ptp_ets         [0] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_ets_fp      [0] = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_100g_ptp_rx_its      [0] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_tx_tod      [0] = 96'b0;
      i_100g_ptp_tx_tod_valid[0] = 1'b0;
      //-----------------------------------------------
      p1_ptp_ins_ets             = {PKT_CYL{1'b0}};
      p1_ptp_ins_cf              = {PKT_CYL{1'b0}};
      p1_ptp_ins_zero_csum       = {PKT_CYL{1'b0}};
      p1_ptp_ins_update_eb       = {PKT_CYL{1'b0}};
      p1_ptp_ins_ts_offset       = {PKT_CYL*96{1'b0}};
      p1_ptp_ins_cf_offset       = {PKT_CYL*96{1'b0}};
      p1_ptp_ins_csum_offset     = {PKT_CYL*96{1'b0}};
      p1_ptp_p2p                 = {PKT_CYL{1'b0}};
      p1_ptp_asym                = {PKT_CYL{1'b0}};
      p1_ptp_asym_sign           = {PKT_CYL{1'b0}};
      p1_ptp_asym_p2p_idx        = {PKT_CYL*7{1'b0}};
      p1_ptp_ts_req              = {PKT_CYL{1'b0}};
      p1_ptp_tx_its              = {PKT_CYL*96{1'b0}};
      p1_ptp_fp                  = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
      //----
      i_100g_ptp_ets_valid   [1] = {PKT_CYL{1'b0}};
      i_100g_ptp_ets         [1] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_ets_fp      [1] = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_100g_ptp_rx_its      [1] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_tx_tod      [1] = 96'b0;
      i_100g_ptp_tx_tod_valid[1] = 1'b0;
      //-----------------------------------------------
      p2_ptp_ins_ets             = o_200g_ptp_ins_ets[1];
      p2_ptp_ins_cf              = o_200g_ptp_ins_cf[1];
      p2_ptp_ins_zero_csum       = o_200g_ptp_ins_zero_csum[1];
      p2_ptp_ins_update_eb       = o_200g_ptp_ins_update_eb[1];
      p2_ptp_ins_ts_offset       = o_200g_ptp_ins_ts_offset[1];
      p2_ptp_ins_cf_offset       = o_200g_ptp_ins_cf_offset[1];
      p2_ptp_ins_csum_offset     = o_200g_ptp_ins_csum_offset[1];
      p2_ptp_p2p                 = o_200g_ptp_p2p[1];
      p2_ptp_asym                = o_200g_ptp_asym[1];
      p2_ptp_asym_sign           = o_200g_ptp_asym_sign[1];
      p2_ptp_asym_p2p_idx        = o_200g_ptp_asym_p2p_idx[1];
      p2_ptp_ts_req              = o_200g_ptp_ts_req[1];
      p2_ptp_tx_its              = o_200g_ptp_tx_its[1];
      p2_ptp_fp                  = o_200g_ptp_fp[1];
      //----
      i_400g_ptp_ets_valid[1]    = {PKT_CYL{1'b0}};
      i_400g_ptp_ets[191:96]     = {PKT_CYL*96{1'b0}};
      i_400g_ptp_ets_fp[15:8]    = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_400g_ptp_rx_its[191:96]  = {PKT_CYL*96{1'b0}};
      //----
      i_200g_ptp_ets_valid   [1] = p2_ptp_ets_valid;
      i_200g_ptp_ets         [1] = p2_ptp_ets;
      i_200g_ptp_ets_fp      [1] = p2_ptp_ets_fp;
//      i_200g_ptp_rx_its      [1] = p2_ptp_rx_its;
      i_200g_ptp_tx_tod      [1] = p2_ptp_tx_tod;
      i_200g_ptp_tx_tod_valid[1] = p2_ptp_tx_tod_valid;
      //----
      i_100g_ptp_ets_valid   [2] = {PKT_CYL{1'b0}};
      i_100g_ptp_ets         [2] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_ets_fp      [2] = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_100g_ptp_rx_its      [2] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_tx_tod      [2] = 96'b0;
      i_100g_ptp_tx_tod_valid[2] = 1'b0;
      //-----------------------------------------------
      p3_ptp_ins_ets             = {PKT_CYL{1'b0}};
      p3_ptp_ins_cf              = {PKT_CYL{1'b0}};
      p3_ptp_ins_zero_csum       = {PKT_CYL{1'b0}};
      p3_ptp_ins_update_eb       = {PKT_CYL{1'b0}};
      p3_ptp_ins_ts_offset       = {PKT_CYL*96{1'b0}};
      p3_ptp_ins_cf_offset       = {PKT_CYL*96{1'b0}};
      p3_ptp_ins_csum_offset     = {PKT_CYL*96{1'b0}};
      p3_ptp_p2p                 = {PKT_CYL{1'b0}};
      p3_ptp_asym                = {PKT_CYL{1'b0}};
      p3_ptp_asym_sign           = {PKT_CYL{1'b0}};
      p3_ptp_asym_p2p_idx        = {PKT_CYL*7{1'b0}};
      p3_ptp_ts_req              = {PKT_CYL{1'b0}};
      p3_ptp_tx_its              = {PKT_CYL*96{1'b0}};
      p3_ptp_fp                  = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
      //----
      i_100g_ptp_ets_valid   [3] = {PKT_CYL{1'b0}};
      i_100g_ptp_ets         [3] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_ets_fp      [3] = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_100g_ptp_rx_its      [3] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_tx_tod      [3] = 96'b0;
      i_100g_ptp_tx_tod_valid[3] = 1'b0;

    end else if (dr_mode == DR_MODE_4X100GE_2) begin
      //-----------------------------------------------
      p0_ptp_ins_ets            = o_100g_ptp_ins_ets[0];
      p0_ptp_ins_cf             = o_100g_ptp_ins_cf[0];
      p0_ptp_ins_zero_csum      = o_100g_ptp_ins_zero_csum[0];
      p0_ptp_ins_update_eb      = o_100g_ptp_ins_update_eb[0];
      p0_ptp_ins_ts_offset      = o_100g_ptp_ins_ts_offset[0];
      p0_ptp_ins_cf_offset      = o_100g_ptp_ins_cf_offset[0];
      p0_ptp_ins_csum_offset    = o_100g_ptp_ins_csum_offset[0];
      p0_ptp_p2p                = o_100g_ptp_p2p[0];
      p0_ptp_asym               = o_100g_ptp_asym[0];
      p0_ptp_asym_sign          = o_100g_ptp_asym_sign[0];
      p0_ptp_asym_p2p_idx       = o_100g_ptp_asym_p2p_idx[0];
      p0_ptp_ts_req             = o_100g_ptp_ts_req[0];
      p0_ptp_tx_its             = o_100g_ptp_tx_its[0];
      p0_ptp_fp                 = o_100g_ptp_fp[0];
      //----
      i_400g_ptp_ets_valid[0]   = {PKT_CYL{1'b0}};
      i_400g_ptp_ets[95:0]      = {PKT_CYL*96{1'b0}};
      i_400g_ptp_ets_fp[7:0]    = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_400g_ptp_rx_its[95:0]   = {PKT_CYL*96{1'b0}};
      i_400g_ptp_tx_tod         = 96'b0;
      i_400g_ptp_tx_tod_valid   = 1'b0;
      //----
      i_200g_ptp_ets_valid   [0] = {PKT_CYL{1'b0}};
      i_200g_ptp_ets         [0] = {PKT_CYL*96{1'b0}};
      i_200g_ptp_ets_fp      [0] = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_200g_ptp_rx_its      [0] = {PKT_CYL*96{1'b0}};
      i_200g_ptp_tx_tod      [0] = 96'b0;
      i_200g_ptp_tx_tod_valid[0] = 1'b0;
      //----
      i_100g_ptp_ets_valid   [0] = p0_ptp_ets_valid;
      i_100g_ptp_ets         [0] = p0_ptp_ets;
      i_100g_ptp_ets_fp      [0] = p0_ptp_ets_fp;
//      i_100g_ptp_rx_its      [0] = p0_ptp_rx_its;
      i_100g_ptp_tx_tod      [0] = p0_ptp_tx_tod;
      i_100g_ptp_tx_tod_valid[0] = p0_ptp_tx_tod_valid;
      //-----------------------------------------------
      p1_ptp_ins_ets             = o_100g_ptp_ins_ets[1];
      p1_ptp_ins_cf              = o_100g_ptp_ins_cf[1];
      p1_ptp_ins_zero_csum       = o_100g_ptp_ins_zero_csum[1];
      p1_ptp_ins_update_eb       = o_100g_ptp_ins_update_eb[1];
      p1_ptp_ins_ts_offset       = o_100g_ptp_ins_ts_offset[1];
      p1_ptp_ins_cf_offset       = o_100g_ptp_ins_cf_offset[1];
      p1_ptp_ins_csum_offset     = o_100g_ptp_ins_csum_offset[1];
      p1_ptp_p2p                 = o_100g_ptp_p2p[1];
      p1_ptp_asym                = o_100g_ptp_asym[1];
      p1_ptp_asym_sign           = o_100g_ptp_asym_sign[1];
      p1_ptp_asym_p2p_idx        = o_100g_ptp_asym_p2p_idx[1];
      p1_ptp_ts_req              = o_100g_ptp_ts_req[1];
      p1_ptp_tx_its              = o_100g_ptp_tx_its[1];
      p1_ptp_fp                  = o_100g_ptp_fp[1];
      //----
      i_100g_ptp_ets_valid   [1] = p1_ptp_ets_valid;
      i_100g_ptp_ets         [1] = p1_ptp_ets;
      i_100g_ptp_ets_fp      [1] = p1_ptp_ets_fp;
//      i_100g_ptp_rx_its      [1] = p1_ptp_rx_its;
      i_100g_ptp_tx_tod      [1] = p1_ptp_tx_tod;
      i_100g_ptp_tx_tod_valid[1] = p1_ptp_tx_tod_valid;
      //-----------------------------------------------
      p2_ptp_ins_ets             = o_100g_ptp_ins_ets[2];
      p2_ptp_ins_cf              = o_100g_ptp_ins_cf[2];
      p2_ptp_ins_zero_csum       = o_100g_ptp_ins_zero_csum[2];
      p2_ptp_ins_update_eb       = o_100g_ptp_ins_update_eb[2];
      p2_ptp_ins_ts_offset       = o_100g_ptp_ins_ts_offset[2];
      p2_ptp_ins_cf_offset       = o_100g_ptp_ins_cf_offset[2];
      p2_ptp_ins_csum_offset     = o_100g_ptp_ins_csum_offset[2];
      p2_ptp_p2p                 = o_100g_ptp_p2p[2];
      p2_ptp_asym                = o_100g_ptp_asym[2];
      p2_ptp_asym_sign           = o_100g_ptp_asym_sign[2];
      p2_ptp_asym_p2p_idx        = o_100g_ptp_asym_p2p_idx[2];
      p2_ptp_ts_req              = o_100g_ptp_ts_req[2];
      p2_ptp_tx_its              = o_100g_ptp_tx_its[2];
      p2_ptp_fp                  = o_100g_ptp_fp[2];
      //----
      i_400g_ptp_ets_valid[1]    = {PKT_CYL{1'b0}};
      i_400g_ptp_ets[191:96]     = {PKT_CYL*96{1'b0}};
      i_400g_ptp_ets_fp[15:8]    = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_400g_ptp_rx_its[191:96]  = {PKT_CYL*96{1'b0}};
      //----
      i_200g_ptp_ets_valid   [1] = {PKT_CYL{1'b0}};
      i_200g_ptp_ets         [1] = {PKT_CYL*96{1'b0}};
      i_200g_ptp_ets_fp      [1] = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_200g_ptp_rx_its      [1] = {PKT_CYL*96{1'b0}};
      i_200g_ptp_tx_tod      [1] = 96'b0;
      i_200g_ptp_tx_tod_valid[1] = 1'b0;
      //----
      i_100g_ptp_ets_valid   [2] = p2_ptp_ets_valid;
      i_100g_ptp_ets         [2] = p2_ptp_ets;
      i_100g_ptp_ets_fp      [2] = p2_ptp_ets_fp;
////      i_100g_ptp_rx_its      [2] = p2_ptp_rx_its;
      i_100g_ptp_tx_tod      [2] = p2_ptp_tx_tod;
      i_100g_ptp_tx_tod_valid[2] = p2_ptp_tx_tod_valid;
      //-----------------------------------------------
      p3_ptp_ins_ets             = o_100g_ptp_ins_ets[3];
      p3_ptp_ins_cf              = o_100g_ptp_ins_cf[3];
      p3_ptp_ins_zero_csum       = o_100g_ptp_ins_zero_csum[3];
      p3_ptp_ins_update_eb       = o_100g_ptp_ins_update_eb[3];
      p3_ptp_ins_ts_offset       = o_100g_ptp_ins_ts_offset[3];
      p3_ptp_ins_cf_offset       = o_100g_ptp_ins_cf_offset[3];
      p3_ptp_ins_csum_offset     = o_100g_ptp_ins_csum_offset[3];
      p3_ptp_p2p                 = o_100g_ptp_p2p[3];
      p3_ptp_asym                = o_100g_ptp_asym[3];
      p3_ptp_asym_sign           = o_100g_ptp_asym_sign[3];
      p3_ptp_asym_p2p_idx        = o_100g_ptp_asym_p2p_idx[3];
      p3_ptp_ts_req              = o_100g_ptp_ts_req[3];
      p3_ptp_tx_its              = o_100g_ptp_tx_its[3];
      p3_ptp_fp                  = o_100g_ptp_fp[3];
      //----
      i_100g_ptp_ets_valid   [3] = p3_ptp_ets_valid;
      i_100g_ptp_ets         [3] = p3_ptp_ets;
      i_100g_ptp_ets_fp      [3] = p3_ptp_ets_fp;
//      i_100g_ptp_rx_its      [3] = p3_ptp_rx_its;
      i_100g_ptp_tx_tod      [3] = p3_ptp_tx_tod;
      i_100g_ptp_tx_tod_valid[3] = p3_ptp_tx_tod_valid;

    end else begin
      //-----------------------------------------------
      p0_ptp_ins_ets             = {PKT_CYL{1'b0}};
      p0_ptp_ins_cf              = {PKT_CYL{1'b0}};
      p0_ptp_ins_zero_csum       = {PKT_CYL{1'b0}};
      p0_ptp_ins_update_eb       = {PKT_CYL{1'b0}};
      p0_ptp_ins_ts_offset       = {PKT_CYL*96{1'b0}};
      p0_ptp_ins_cf_offset       = {PKT_CYL*96{1'b0}};
      p0_ptp_ins_csum_offset     = {PKT_CYL*96{1'b0}};
      p0_ptp_p2p                 = {PKT_CYL{1'b0}};
      p0_ptp_asym                = {PKT_CYL{1'b0}};
      p0_ptp_asym_sign           = {PKT_CYL{1'b0}};
      p0_ptp_asym_p2p_idx        = {PKT_CYL*7{1'b0}};
      p0_ptp_ts_req              = {PKT_CYL{1'b0}};
      p0_ptp_tx_its              = {PKT_CYL*96{1'b0}};
      p0_ptp_fp                  = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
      //----
      i_400g_ptp_ets_valid[0]    = {PKT_CYL{1'b0}};
      i_400g_ptp_ets[95:0]       = {PKT_CYL*96{1'b0}};
      i_400g_ptp_ets_fp[7:0]     = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_400g_ptp_rx_its[95:0]    = {PKT_CYL*96{1'b0}};
      i_400g_ptp_tx_tod          = 96'b0;
      i_400g_ptp_tx_tod_valid    = 1'b0;
      //----
      i_200g_ptp_ets_valid   [0] = {PKT_CYL{1'b0}};
      i_200g_ptp_ets         [0] = {PKT_CYL*96{1'b0}};
      i_200g_ptp_ets_fp      [0] = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_200g_ptp_rx_its      [0] = {PKT_CYL*96{1'b0}};
      i_200g_ptp_tx_tod      [0] = 96'b0;
      i_200g_ptp_tx_tod_valid[0] = 1'b0;
      //----
      i_100g_ptp_ets_valid   [0] = {PKT_CYL{1'b0}};
      i_100g_ptp_ets         [0] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_ets_fp      [0] = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_100g_ptp_rx_its      [0] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_tx_tod      [0] = 96'b0;
      i_100g_ptp_tx_tod_valid[0] = 1'b0;
      //-----------------------------------------------
      p1_ptp_ins_ets             = {PKT_CYL{1'b0}};
      p1_ptp_ins_cf              = {PKT_CYL{1'b0}};
      p1_ptp_ins_zero_csum       = {PKT_CYL{1'b0}};
      p1_ptp_ins_update_eb       = {PKT_CYL{1'b0}};
      p1_ptp_ins_ts_offset       = {PKT_CYL*96{1'b0}};
      p1_ptp_ins_cf_offset       = {PKT_CYL*96{1'b0}};
      p1_ptp_ins_csum_offset     = {PKT_CYL*96{1'b0}};
      p1_ptp_p2p                 = {PKT_CYL{1'b0}};
      p1_ptp_asym                = {PKT_CYL{1'b0}};
      p1_ptp_asym_sign           = {PKT_CYL{1'b0}};
      p1_ptp_asym_p2p_idx        = {PKT_CYL*7{1'b0}};
      p1_ptp_ts_req              = {PKT_CYL{1'b0}};
      p1_ptp_tx_its              = {PKT_CYL*96{1'b0}};
      p1_ptp_fp                  = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
      //----
      i_100g_ptp_ets_valid   [1] = {PKT_CYL{1'b0}};
      i_100g_ptp_ets         [1] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_ets_fp      [1] = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_100g_ptp_rx_its      [1] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_tx_tod      [1] = 96'b0;
      i_100g_ptp_tx_tod_valid[1] = 1'b0;
      //-----------------------------------------------
      p2_ptp_ins_ets             = {PKT_CYL{1'b0}};
      p2_ptp_ins_cf              = {PKT_CYL{1'b0}};
      p2_ptp_ins_zero_csum       = {PKT_CYL{1'b0}};
      p2_ptp_ins_update_eb       = {PKT_CYL{1'b0}};
      p2_ptp_ins_ts_offset       = {PKT_CYL*96{1'b0}};
      p2_ptp_ins_cf_offset       = {PKT_CYL*96{1'b0}};
      p2_ptp_ins_csum_offset     = {PKT_CYL*96{1'b0}};
      p2_ptp_p2p                 = {PKT_CYL{1'b0}};
      p2_ptp_asym                = {PKT_CYL{1'b0}};
      p2_ptp_asym_sign           = {PKT_CYL{1'b0}};
      p2_ptp_asym_p2p_idx        = {PKT_CYL*7{1'b0}};
      p2_ptp_ts_req              = {PKT_CYL{1'b0}};
      p2_ptp_tx_its              = {PKT_CYL*96{1'b0}};
      p2_ptp_fp                  = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
      //----
      i_400g_ptp_ets_valid[1]    = {PKT_CYL{1'b0}};
      i_400g_ptp_ets[191:96]     = {PKT_CYL*96{1'b0}};
      i_400g_ptp_ets_fp[15:8]    = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_400g_ptp_rx_its[191:96]  = {PKT_CYL*96{1'b0}};
      //----
      i_200g_ptp_ets_valid   [1] = {PKT_CYL{1'b0}};
      i_200g_ptp_ets         [1] = {PKT_CYL*96{1'b0}};
      i_200g_ptp_ets_fp      [1] = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_200g_ptp_rx_its      [1] = {PKT_CYL*96{1'b0}};
      i_200g_ptp_tx_tod      [1] = 96'b0;
      i_200g_ptp_tx_tod_valid[1] = 1'b0;
      //----
      i_100g_ptp_ets_valid   [2] = {PKT_CYL{1'b0}};
      i_100g_ptp_ets         [2] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_ets_fp      [2] = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_100g_ptp_rx_its      [2] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_tx_tod      [2] = 96'b0;
      i_100g_ptp_tx_tod_valid[2] = 1'b0;
      //-----------------------------------------------
      p3_ptp_ins_ets             = {PKT_CYL{1'b0}};
      p3_ptp_ins_cf              = {PKT_CYL{1'b0}};
      p3_ptp_ins_zero_csum       = {PKT_CYL{1'b0}};
      p3_ptp_ins_update_eb       = {PKT_CYL{1'b0}};
      p3_ptp_ins_ts_offset       = {PKT_CYL*96{1'b0}};
      p3_ptp_ins_cf_offset       = {PKT_CYL*96{1'b0}};
      p3_ptp_ins_csum_offset     = {PKT_CYL*96{1'b0}};
      p3_ptp_p2p                 = {PKT_CYL{1'b0}};
      p3_ptp_asym                = {PKT_CYL{1'b0}};
      p3_ptp_asym_sign           = {PKT_CYL{1'b0}};
      p3_ptp_asym_p2p_idx        = {PKT_CYL*7{1'b0}};
      p3_ptp_ts_req              = {PKT_CYL{1'b0}};
      p3_ptp_tx_its              = {PKT_CYL*96{1'b0}};
      p3_ptp_fp                  = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
      //----
      i_100g_ptp_ets_valid   [3] = {PKT_CYL{1'b0}};
      i_100g_ptp_ets         [3] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_ets_fp      [3] = {PKT_CYL*PTP_FP_WIDTH{1'b0}};
//      i_100g_ptp_rx_its      [3] = {PKT_CYL*96{1'b0}};
      i_100g_ptp_tx_tod      [3] = 96'b0;
      i_100g_ptp_tx_tod_valid[3] = 1'b0;

    end
end
//---------------------------------------------------------------

//---------------------------------------------------------------
//---------------------------------------------------------------
logic [31:0] active_port;
assign active_port = (ASCT_PORT_NUM - BASE_PORT_NUM);

always_ff@(posedge app_ss_lite_clk) 
	begin
		if(~app_ss_lite_areset_n) 
		begin
    	i_100g_status_addr					<= 64'h0;
    	i_100g_status_read					<= 4'h0;
    	i_100g_status_write				<= 4'h0;
    	i_100g_status_writedata		<= 1024'h0;
    	i_100g_status_byteenable		<= 16'h0;

			i_200g_status_addr					<= 64'h0;
    	i_200g_status_read					<= 2'h0;
    	i_200g_status_write				<= 2'h0;
    	i_200g_status_writedata		<= 1024'h0;
    	i_200g_status_byteenable		<= 16'h0;

			i_status_addr							<= 16'h0;
    	i_status_read							<= 1'h0;
    	i_status_write						<= 1'h0;
    	i_status_writedata				<= 1024'h0;
    	i_status_byteenable				<= 16'h0;
   	end
    else 
    begin
		if(dr_mode ==  DR_MODE_2X200GE_4)
		begin
				case(active_port[1:0])
				4'd0 :
				begin
					i_200g_status_addr	[0*16+:16]		<= i_jtag_address[15:0];
        	i_200g_status_read[0]						<= i_jtag_read;	
        	i_200g_status_write[0]						<= i_jtag_write;
        	i_200g_status_writedata[0*32+:32]<= i_jtag_writedata;
        	i_200g_status_byteenable[0*4+:4]	<= i_jtag_byteenable;
        	o_jtag_readdata             		<= o_200g_status_readdata[0*32+:32];					
        	o_jtag_readdatavalid        		<= o_200g_status_readdata_valid[0];	
        	o_jtag_waitrequest          		<= o_200g_status_waitrequest[0];		
				end
				4'd2 :
				begin
					i_200g_status_addr	[1*16+:16]		<= i_jtag_address[15:0];
        	i_200g_status_read[1]						<= i_jtag_read;	
        	i_200g_status_write[1]						<= i_jtag_write;
        	i_200g_status_writedata[1*32+:32]<= i_jtag_writedata;
        	i_200g_status_byteenable[1*4+:4]	<= i_jtag_byteenable;
        	o_jtag_readdata             		<= o_200g_status_readdata[1*32+:32];					
        	o_jtag_readdatavalid        		<= o_200g_status_readdata_valid[1];	
        	o_jtag_waitrequest          		<= o_200g_status_waitrequest[1];		
				end
				endcase
		end
		else if (dr_mode == DR_MODE_4X100GE_2)
		begin
				case(active_port[1:0])
				4'd0 :
				begin
					i_100g_status_addr	[0*16+:16]		<= i_jtag_address[15:0];
        	i_100g_status_read[0]						<= i_jtag_read;	
        	i_100g_status_write[0]						<= i_jtag_write;
        	i_100g_status_writedata[0*32+:32]<= i_jtag_writedata;
        	i_100g_status_byteenable[0*4+:4]	<= i_jtag_byteenable;
        	o_jtag_readdata             		<= o_100g_status_readdata[0*32+:32];					
        	o_jtag_readdatavalid        		<= o_100g_status_readdata_valid[0];	
        	o_jtag_waitrequest          		<= o_100g_status_waitrequest[0];	
				end
				4'd1 :
				begin
					i_100g_status_addr	[1*16+:16]		<= i_jtag_address[15:0];
        	i_100g_status_read[1]						<= i_jtag_read;	
        	i_100g_status_write[1]						<= i_jtag_write;
        	i_100g_status_writedata[1*32+:32]<= i_jtag_writedata;
        	i_100g_status_byteenable[1*4+:4]	<= i_jtag_byteenable;
        	o_jtag_readdata             		<= o_100g_status_readdata[1*32+:32];					
        	o_jtag_readdatavalid        		<= o_100g_status_readdata_valid[1];	
        	o_jtag_waitrequest          		<= o_100g_status_waitrequest[1];	
				end
				4'd2 :
				begin
					i_100g_status_addr	[2*16+:16]		<= i_jtag_address[15:0];
        	i_100g_status_read[2]						<= i_jtag_read;	
        	i_100g_status_write[2]						<= i_jtag_write;
        	i_100g_status_writedata[2*32+:32]<= i_jtag_writedata;
        	i_100g_status_byteenable[2*4+:4]	<= i_jtag_byteenable;
        	o_jtag_readdata             		<= o_100g_status_readdata[2*32+:32];					
        	o_jtag_readdatavalid        		<= o_100g_status_readdata_valid[2];	
        	o_jtag_waitrequest          		<= o_100g_status_waitrequest[2];	
				end
				4'd3 :
				begin
					i_100g_status_addr	[3*16+:16]		<= i_jtag_address[15:0];
        	i_100g_status_read[3]						<= i_jtag_read;	
        	i_100g_status_write[3]						<= i_jtag_write;
        	i_100g_status_writedata[3*32+:32]<= i_jtag_writedata;
        	i_100g_status_byteenable[3*4+:4]	<= i_jtag_byteenable;
        	o_jtag_readdata             		<= o_100g_status_readdata[3*32+:32];					
        	o_jtag_readdatavalid        		<= o_100g_status_readdata_valid[3];	
        	o_jtag_waitrequest          		<= o_100g_status_waitrequest[3];	
				end
				endcase
		end			
		else begin
				i_status_addr						<= i_jtag_address[15:0];
        i_status_read						<= i_jtag_read;	
        i_status_write					<= i_jtag_write;
        i_status_writedata			<= i_jtag_writedata;
        i_status_byteenable			<= i_jtag_byteenable;
        o_jtag_readdata         <= o_status_readdata;					
        o_jtag_readdatavalid    <= o_status_readdata_valid;	
        o_jtag_waitrequest      <= o_status_waitrequest;
		end
    end
	end

//---------------------------------------------------------------

//---------------------------------------------------------------


//---------------------------------------------------------------

logic tx_pll_locked_reconfig_sync;
logic rst_n_reconfig_sync;
logic pkt_client_rst_n;
logic o_tx_pll_locked;
logic [3:0] o_cdr_lock;
logic o_rx_mac_error =1'b0;

  assign o_tx_pll_locked  = i_tx_pll_locked;
  assign o_cdr_lock		    = {i_p3_cdr_lock,i_p2_cdr_lock,i_p1_cdr_lock,i_p0_cdr_lock}; 



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

eth_f_altera_std_synchronizer_nocut pkt_client_rst_n_sync_inst (
    .clk        (i_clk_tx),
    .reset_n    (1'b1),
    .din        (pkt_client_rst_n),
    .dout       (pkt_client_rst_n_sync)
);

eth_f_packet_client_top packet_client_top (
        .i_arst                       (!pkt_client_rst_n_sync),
        .i_clk_rx                     (i_clk_rx),
        .i_clk_tx                     (i_clk_tx),
        .i_clk_pll                    (i_clk_pll),
        .i_clk_status                 (app_ss_lite_clk),
        .i_clk_status_rst             (~app_ss_lite_areset_n),

        .i_tx_mac_ready               (o_tx_mac_ready),
        .o_tx_mac_valid               (i_tx_mac_valid),
        .o_tx_mac_inframe             (i_tx_mac_inframe),
        .o_tx_mac_eop_empty           (i_tx_mac_eop_empty),
        .o_tx_mac_data                (i_tx_mac_data),
        .o_tx_mac_error               (i_tx_mac_error),
        .o_tx_mac_skip_crc            (i_tx_mac_skip_crc),

        .i_rx_mac_valid               (o_rx_mac_valid),
        .i_rx_mac_inframe             (o_rx_mac_inframe),
        .i_rx_mac_eop_empty           (o_rx_mac_eop_empty),
        .i_rx_mac_data                (o_rx_mac_data),
        .i_rx_mac_error               (o_rx_mac_error),
        .i_rx_mac_fcs_error           (o_rx_mac_fcs_error),
        .i_rx_mac_status              (o_rx_mac_status),

        .i_tx_ready                   (o_tx_ready),
        .o_tx_valid                   (i_tx_valid),
        .o_tx_sop                     (i_tx_startofpacket), 
        .o_tx_eop                     (i_tx_endofpacket),
        .o_tx_empty                   (i_tx_empty),
        .o_tx_data                    (i_tx_data),
        .o_tx_error                   (i_tx_error),
        .o_tx_skip_crc                (i_tx_skip_crc), 

        .i_rx_valid                   (o_rx_valid),
        .i_rx_sop                     (o_rx_startofpacket),
        .i_rx_eop                     (o_rx_endofpacket),
        .i_rx_empty                   (o_rx_empty),
        .i_rx_data                    (o_rx_data),
        .i_rx_error                   (o_rx_error),
        .i_rxstatus_valid             (o_rxstatus_valid),
        .i_rxstatus_data              (o_rxstatus_data),

        .i_rx_preamble                (o_rx_preamble), 
        .o_tx_preamble                (i_tx_preamble),

        .i_clk_tx_tod                 (i_400g_clk_tx_tod          ),
        .i_tx_tod_rst_n               (i_400g_tx_tod_rst_n        ),
        .o_ptp_ins_ets                (o_400g_ptp_ins_ets         ),
        .o_ptp_ins_cf                 (o_400g_ptp_ins_cf          ),
        .o_ptp_ins_zero_csum          (o_400g_ptp_ins_zero_csum   ),
        .o_ptp_ins_update_eb          (o_400g_ptp_ins_update_eb   ),
        .o_ptp_ins_ts_offset          (o_400g_ptp_ins_ts_offset   ),
        .o_ptp_ins_cf_offset          (o_400g_ptp_ins_cf_offset   ),
        .o_ptp_ins_csum_offset        (o_400g_ptp_ins_csum_offset ),
        .o_ptp_p2p                    (o_400g_ptp_p2p             ),
        .o_ptp_asym                   (o_400g_ptp_asym            ),
        .o_ptp_asym_sign              (o_400g_ptp_asym_sign       ),
        .o_ptp_asym_p2p_idx           (o_400g_ptp_asym_p2p_idx    ),
        .o_ptp_ts_req                 (o_400g_ptp_ts_req          ),
        .o_ptp_fp                     (o_400g_ptp_fp              ),
        .o_ptp_tx_its                 (o_400g_ptp_tx_its          ),
        .i_tx_ptp_ets_valid           (i_400g_ptp_ets_valid       ),
        .i_tx_ptp_ets                 (i_400g_ptp_ets             ),
        .i_tx_ptp_ets_fp              (i_400g_ptp_ets_fp          ),
        .i_rx_ptp_its                 (i_400g_ptp_rx_its          ),
        .i_tx_ptp_tod                 (i_400g_ptp_tx_tod          ),
        .i_tx_ptp_tod_valid           (i_400g_ptp_tx_tod_valid    ),

        .i_status_addr                ({7'h0,i_status_addr}),
        .i_status_read                (i_status_read),
        .i_status_write               (i_status_write),
        .i_status_writedata           (i_status_writedata),
        .o_status_readdata            (o_status_readdata),
        .o_status_readdata_valid      (o_status_readdata_valid),
        .o_status_waitrequest         (o_status_waitrequest)
   );


defparam    packet_client_top.ENABLE_PTP           = PTP_EN;
defparam    packet_client_top.PKT_CYL              = PKT_CYL_400G;
defparam    packet_client_top.PTP_FP_WIDTH         = PTP_FP_WIDTH;
defparam    packet_client_top.CLIENT_IF_TYPE       = CLIENT_IF_TYPE;
defparam    packet_client_top.READY_LATENCY        = 0;
defparam    packet_client_top.WORDS_AVST           = DW_AVST_DW/64;
defparam    packet_client_top.WORDS_MAC            = NUM_SEG;
//defparam    packet_client_top.WORDS                = 16;
defparam    packet_client_top.EMPTY_WIDTH          = 48;
defparam    packet_client_top.LPBK_FIFO_ADDR_WIDTH = LPBK_FIFO_ADDR_WIDTH;
defparam    packet_client_top.PKT_ROM_INIT_FILE    = PKT_ROM_INIT_FILE_400;


// 4x100G packet client
logic [3:0] tx_pll_locked_reconfig_100g_sync;
logic [3:0] rst_n_reconfig_100g_sync;
logic [3:0] pkt_client_100g_rst_n;
logic [3:0] pkt_client_100g_rst_n_sync;
logic [3:0] o_100g_tx_pll_locked; 
assign o_100g_tx_pll_locked = {4{i_tx_pll_locked}};
genvar ex_100g_pc;
generate
    for(ex_100g_pc = 0; ex_100g_pc < 4; ex_100g_pc ++) begin : GEN_EX_100G_PC
        
        eth_f_altera_std_synchronizer_nocut tx_pll_locked_reconfig_sync_100g_inst (
            .clk        (app_ss_lite_clk),
            .reset_n    (1'b1),
            .din        (o_100g_tx_pll_locked[ex_100g_pc]),
            .dout       (tx_pll_locked_reconfig_100g_sync[ex_100g_pc])
        );
        
        eth_f_altera_std_synchronizer_nocut i_rst_reconfig_sync_100g_inst (
            .clk        (app_ss_lite_clk),
            .reset_n    (1'b1),
            .din        (i_100g_rst_n[ex_100g_pc]),
            .dout       (rst_n_reconfig_100g_sync[ex_100g_pc])
        );
        
        always @(posedge app_ss_lite_clk) begin
            pkt_client_100g_rst_n[ex_100g_pc] <= tx_pll_locked_reconfig_100g_sync[ex_100g_pc] & rst_n_reconfig_100g_sync[ex_100g_pc];
        end

		eth_f_altera_std_synchronizer_nocut pkt_client_rst_n_sync_100g_inst (
            .clk        (i_100g_clk_tx[ex_100g_pc]),
            .reset_n    (1'b1),
            .din        (pkt_client_100g_rst_n[ex_100g_pc]),
            .dout       (pkt_client_100g_rst_n_sync[ex_100g_pc])
        );
		
        eth_f_packet_client_top packet_client_100g_top (
            .i_arst                       (!pkt_client_100g_rst_n_sync[ex_100g_pc]),
            .i_clk_rx                     (i_100g_clk_rx[ex_100g_pc]),
            .i_clk_tx                     (i_100g_clk_tx[ex_100g_pc]),
            .i_clk_status_rst             (~app_ss_lite_areset_n),
            .i_clk_status                 (app_ss_lite_clk),
        		.i_clk_pll                    (i_clk_pll), 
            .i_tx_mac_ready               (o_100g_tx_mac_ready[ex_100g_pc]),
            .o_tx_mac_valid               (i_100g_tx_mac_valid[ex_100g_pc]),
            .o_tx_mac_inframe             (i_100g_tx_mac_inframe[ex_100g_pc*4+:4]),
            .o_tx_mac_eop_empty           (i_100g_tx_mac_eop_empty[ex_100g_pc*12+:12]),
            .o_tx_mac_data                (i_100g_tx_mac_data[ex_100g_pc*256+:256]),
            .o_tx_mac_error               (i_100g_tx_mac_error[ex_100g_pc*4+:4]),
            .o_tx_mac_skip_crc            (i_100g_tx_mac_skip_crc[ex_100g_pc*4+:4]),
        
            .i_rx_mac_valid               (o_100g_rx_mac_valid[ex_100g_pc]),
            .i_rx_mac_inframe             (o_100g_rx_mac_inframe[ex_100g_pc*4+:4]),
            .i_rx_mac_eop_empty           (o_100g_rx_mac_eop_empty[ex_100g_pc*12+:12]),
            .i_rx_mac_data                (o_100g_rx_mac_data[ex_100g_pc*256+:256]),
            .i_rx_mac_error               (o_100g_rx_mac_error[ex_100g_pc*8+:8]),
            .i_rx_mac_fcs_error           (o_100g_rx_mac_fcs_error[ex_100g_pc*4+:4]),
            .i_rx_mac_status              (o_100g_rx_mac_status[ex_100g_pc*12+:12]),
        
            .i_tx_ready                   (o_100g_tx_ready[ex_100g_pc]),
            .o_tx_valid                   (i_100g_tx_valid[ex_100g_pc]),
            .o_tx_sop                     (i_100g_tx_startofpacket[ex_100g_pc]), 
            .o_tx_eop                     (i_100g_tx_endofpacket[ex_100g_pc]),
            .o_tx_empty                   (i_100g_tx_empty[ex_100g_pc*6+:6]),
            .o_tx_data                    (i_100g_tx_data[ex_100g_pc*256+:256]),
            .o_tx_error                   (i_100g_tx_error[ex_100g_pc]),
            .o_tx_skip_crc                (i_100g_tx_skip_crc[ex_100g_pc]), 
        
            .i_rx_valid                   (o_100g_rx_valid[ex_100g_pc]),
            .i_rx_sop                     (o_100g_rx_startofpacket[ex_100g_pc]),
            .i_rx_eop                     (o_100g_rx_endofpacket[ex_100g_pc]),
            .i_rx_empty                   (o_100g_rx_empty[ex_100g_pc*6+:6]),
            .i_rx_data                    (o_100g_rx_data[ex_100g_pc*256+:256]),
            .i_rx_error                   (o_100g_rx_error[ex_100g_pc*6+:6]),
            .i_rxstatus_valid             (o_100g_rxstatus_valid[ex_100g_pc]),
            .i_rxstatus_data              (o_100g_rxstatus_data[ex_100g_pc*40+:40]),
        
            .i_rx_preamble                (o_100g_rx_preamble[ex_100g_pc*64+:64]), 
            .o_tx_preamble                (i_100g_tx_preamble[ex_100g_pc*64+:64]),

            .i_clk_tx_tod                 (i_100g_clk_tx_tod          [ex_100g_pc]),
            .i_tx_tod_rst_n               (i_100g_tx_tod_rst_n        [ex_100g_pc]),			
            .o_ptp_ins_ets                (o_100g_ptp_ins_ets         [ex_100g_pc]),
            .o_ptp_ins_cf                 (o_100g_ptp_ins_cf          [ex_100g_pc]),
            .o_ptp_ins_zero_csum          (o_100g_ptp_ins_zero_csum   [ex_100g_pc]),
            .o_ptp_ins_update_eb          (o_100g_ptp_ins_update_eb   [ex_100g_pc]),
            .o_ptp_ins_ts_offset          (o_100g_ptp_ins_ts_offset   [ex_100g_pc]),
            .o_ptp_ins_cf_offset          (o_100g_ptp_ins_cf_offset   [ex_100g_pc]),
            .o_ptp_ins_csum_offset        (o_100g_ptp_ins_csum_offset [ex_100g_pc]),
            .o_ptp_p2p                    (o_100g_ptp_p2p             [ex_100g_pc]),
            .o_ptp_asym                   (o_100g_ptp_asym            [ex_100g_pc]),
            .o_ptp_asym_sign              (o_100g_ptp_asym_sign       [ex_100g_pc]),
            .o_ptp_asym_p2p_idx           (o_100g_ptp_asym_p2p_idx    [ex_100g_pc]),
            .o_ptp_ts_req                 (o_100g_ptp_ts_req          [ex_100g_pc]),
            .o_ptp_fp                     (o_100g_ptp_fp              [ex_100g_pc]),
            .o_ptp_tx_its                 (o_100g_ptp_tx_its          [ex_100g_pc]),
            .i_tx_ptp_ets_valid           (i_100g_ptp_ets_valid       [ex_100g_pc]),
            .i_tx_ptp_ets                 (i_100g_ptp_ets             [ex_100g_pc]),
            .i_tx_ptp_ets_fp              (i_100g_ptp_ets_fp          [ex_100g_pc]),
            .i_rx_ptp_its                 (i_100g_ptp_rx_its          [ex_100g_pc]),
            .i_tx_ptp_tod                 (i_100g_ptp_tx_tod          [ex_100g_pc]),
            .i_tx_ptp_tod_valid           (i_100g_ptp_tx_tod_valid    [ex_100g_pc]),

            .i_status_addr                ({7'h0,i_100g_status_addr[ex_100g_pc*16+:16]}),
            .i_status_read                (i_100g_status_read[ex_100g_pc]),
            .i_status_write               (i_100g_status_write[ex_100g_pc]),
            .i_status_writedata           (i_100g_status_writedata[ex_100g_pc*32+:32]),
            .o_status_readdata            (o_100g_status_readdata[ex_100g_pc*32+:32]),
            .o_status_readdata_valid      (o_100g_status_readdata_valid[ex_100g_pc]),
            .o_status_waitrequest         (o_100g_status_waitrequest[ex_100g_pc])
        );

        defparam packet_client_100g_top.ENABLE_PTP           = PTP_EN;
        defparam packet_client_100g_top.PKT_CYL              = 1;
        defparam packet_client_100g_top.PTP_FP_WIDTH         = 8;
        defparam packet_client_100g_top.CLIENT_IF_TYPE       = CLIENT_IF_TYPE;
        defparam packet_client_100g_top.READY_LATENCY        = 0;
//      defparam packet_client_100g_top.WORDS                = 4;
				defparam packet_client_100g_top.WORDS_AVST           = (PREAMBLE_PASS_TH_EN)? 256/2: 256/64;
				defparam packet_client_100g_top.WORDS_MAC            = 4;
        defparam packet_client_100g_top.EMPTY_WIDTH          = 6;
        defparam packet_client_100g_top.LPBK_FIFO_ADDR_WIDTH = 8;
        defparam packet_client_100g_top.PKT_ROM_INIT_FILE    = PKT_ROM_INIT_FILE_100;
    end
endgenerate

// 2x200G packet client
logic [1:0] tx_pll_locked_reconfig_200g_sync;
logic [1:0] rst_n_reconfig_200g_sync;
logic [1:0] pkt_client_200g_rst_n;
logic [1:0] pkt_client_200g_rst_n_sync;
logic [1:0] o_200g_tx_pll_locked ;
assign o_200g_tx_pll_locked = {2{i_tx_pll_locked}};
genvar ex_200g_pc;
generate
    for(ex_200g_pc = 0; ex_200g_pc < 2; ex_200g_pc ++) begin : GEN_EX_200G_PC
        
        eth_f_altera_std_synchronizer_nocut tx_pll_locked_reconfig_sync_200g_inst (
            .clk        (app_ss_lite_clk),
            .reset_n    (1'b1),
            .din        (o_200g_tx_pll_locked[ex_200g_pc]),
            .dout       (tx_pll_locked_reconfig_200g_sync[ex_200g_pc])
        );
        
        eth_f_altera_std_synchronizer_nocut i_rst_reconfig_sync_200g_inst (
            .clk        (app_ss_lite_clk),
            .reset_n    (1'b1),
            .din        (i_200g_rst_n[ex_200g_pc]),
            .dout       (rst_n_reconfig_200g_sync[ex_200g_pc])
        );
        
        always @(posedge app_ss_lite_clk) begin
            pkt_client_200g_rst_n[ex_200g_pc] <= tx_pll_locked_reconfig_200g_sync[ex_200g_pc] & rst_n_reconfig_200g_sync[ex_200g_pc];
        end

		eth_f_altera_std_synchronizer_nocut pkt_client_rst_n_sync_200g_inst (
            .clk        (i_200g_clk_tx[ex_200g_pc]),
            .reset_n    (1'b1),
            .din        (pkt_client_200g_rst_n[ex_200g_pc]),
            .dout       (pkt_client_200g_rst_n_sync[ex_200g_pc])
        );
        eth_f_packet_client_top packet_client_200g_top (
            .i_arst                       (!pkt_client_200g_rst_n_sync[ex_200g_pc]),
            .i_clk_rx                     (i_200g_clk_rx[ex_200g_pc]),
            .i_clk_tx                     (i_200g_clk_tx[ex_200g_pc]),
            .i_clk_status                 (app_ss_lite_clk),
            .i_clk_status_rst             (~app_ss_lite_areset_n),
            .i_clk_pll                    (i_clk_pll),
            .i_tx_mac_ready               (o_200g_tx_mac_ready[ex_200g_pc]),
            .o_tx_mac_valid               (i_200g_tx_mac_valid[ex_200g_pc]),
            .o_tx_mac_inframe             (i_200g_tx_mac_inframe[ex_200g_pc*8+:8]),
            .o_tx_mac_eop_empty           (i_200g_tx_mac_eop_empty[ex_200g_pc*24+:24]),
            .o_tx_mac_data                (i_200g_tx_mac_data[ex_200g_pc*512+:512]),
            .o_tx_mac_error               (i_200g_tx_mac_error[ex_200g_pc*8+:8]),
            .o_tx_mac_skip_crc            (i_200g_tx_mac_skip_crc[ex_200g_pc*8+:8]),
        
            .i_rx_mac_valid               (o_200g_rx_mac_valid[ex_200g_pc]),
            .i_rx_mac_inframe             (o_200g_rx_mac_inframe[ex_200g_pc*8+:8]),
            .i_rx_mac_eop_empty           (o_200g_rx_mac_eop_empty[ex_200g_pc*24+:24]),
            .i_rx_mac_data                (o_200g_rx_mac_data[ex_200g_pc*512+:512]),
            .i_rx_mac_error               (o_200g_rx_mac_error[ex_200g_pc*16+:16]),
            .i_rx_mac_fcs_error           (o_200g_rx_mac_fcs_error[ex_200g_pc*8+:8]),
            .i_rx_mac_status              (o_200g_rx_mac_status[ex_200g_pc*24+:24]),
        
            .i_tx_ready                   (o_200g_tx_ready[ex_200g_pc]),
            .o_tx_valid                   (i_200g_tx_valid[ex_200g_pc]),
            .o_tx_sop                     (i_200g_tx_startofpacket[ex_200g_pc]), 
            .o_tx_eop                     (i_200g_tx_endofpacket[ex_200g_pc]),
            .o_tx_empty                   (i_200g_tx_empty[ex_200g_pc*24+:24]),
            .o_tx_data                    (i_200g_tx_data[ex_200g_pc*512+:512]),
            .o_tx_error                   (i_200g_tx_error[ex_200g_pc]),
            .o_tx_skip_crc                (i_200g_tx_skip_crc[ex_200g_pc]), 
        
            .i_rx_valid                   (o_200g_rx_valid[ex_200g_pc]),
            .i_rx_sop                     (o_200g_rx_startofpacket[ex_200g_pc]),
            .i_rx_eop                     (o_200g_rx_endofpacket[ex_200g_pc]),
            .i_rx_empty                   (o_200g_rx_empty[ex_200g_pc*24+:24]),
            .i_rx_data                    (o_200g_rx_data[ex_200g_pc*512+:512]),
            .i_rx_error                   (o_200g_rx_error[ex_200g_pc*6+:6]),
            .i_rxstatus_valid             (o_200g_rxstatus_valid[ex_200g_pc]),
            .i_rxstatus_data              (o_200g_rxstatus_data[ex_200g_pc*40+:40]),
        
            .i_rx_preamble                (o_200g_rx_preamble[ex_200g_pc*64+:64]), 
            .o_tx_preamble                (i_200g_tx_preamble[ex_200g_pc*64+:64]),

            .i_clk_tx_tod                 (i_200g_clk_tx_tod          [ex_200g_pc]),
            .i_tx_tod_rst_n               (i_200g_tx_tod_rst_n        [ex_200g_pc]),
            .o_ptp_ins_ets                (o_200g_ptp_ins_ets         [ex_200g_pc]),
            .o_ptp_ins_cf                 (o_200g_ptp_ins_cf          [ex_200g_pc]),
            .o_ptp_ins_zero_csum          (o_200g_ptp_ins_zero_csum   [ex_200g_pc]),
            .o_ptp_ins_update_eb          (o_200g_ptp_ins_update_eb   [ex_200g_pc]),
            .o_ptp_ins_ts_offset          (o_200g_ptp_ins_ts_offset   [ex_200g_pc]),
            .o_ptp_ins_cf_offset          (o_200g_ptp_ins_cf_offset   [ex_200g_pc]),
            .o_ptp_ins_csum_offset        (o_200g_ptp_ins_csum_offset [ex_200g_pc]),
            .o_ptp_p2p                    (o_200g_ptp_p2p             [ex_200g_pc]),
            .o_ptp_asym                   (o_200g_ptp_asym            [ex_200g_pc]),
            .o_ptp_asym_sign              (o_200g_ptp_asym_sign       [ex_200g_pc]),
            .o_ptp_asym_p2p_idx           (o_200g_ptp_asym_p2p_idx    [ex_200g_pc]),
            .o_ptp_ts_req                 (o_200g_ptp_ts_req          [ex_200g_pc]),
            .o_ptp_fp                     (o_200g_ptp_fp              [ex_200g_pc]),
            .o_ptp_tx_its                 (o_200g_ptp_tx_its          [ex_200g_pc]),
            .i_tx_ptp_ets_valid           (i_200g_ptp_ets_valid       [ex_200g_pc]),
            .i_tx_ptp_ets                 (i_200g_ptp_ets             [ex_200g_pc]),
            .i_tx_ptp_ets_fp              (i_200g_ptp_ets_fp          [ex_200g_pc]),
            .i_rx_ptp_its                 (i_200g_ptp_rx_its          [ex_200g_pc]),
            .i_tx_ptp_tod                 (i_200g_ptp_tx_tod          [ex_200g_pc]),
            .i_tx_ptp_tod_valid           (i_200g_ptp_tx_tod_valid    [ex_200g_pc]),
        
            .i_status_addr                ({7'h0,i_200g_status_addr[ex_200g_pc*16+:16]}),
            .i_status_read                (i_200g_status_read[ex_200g_pc]),
            .i_status_write               (i_200g_status_write[ex_200g_pc]),
            .i_status_writedata           (i_200g_status_writedata[ex_200g_pc*32+:32]),
            .o_status_readdata            (o_200g_status_readdata[ex_200g_pc*32+:32]),
            .o_status_readdata_valid      (o_200g_status_readdata_valid[ex_200g_pc]),
            .o_status_waitrequest         (o_200g_status_waitrequest[ex_200g_pc])
        );
        
        defparam packet_client_200g_top.ENABLE_PTP           = PTP_EN;
        defparam packet_client_200g_top.PKT_CYL              = 1;
        defparam packet_client_200g_top.PTP_FP_WIDTH         = 8;
        defparam packet_client_200g_top.CLIENT_IF_TYPE       = CLIENT_IF_TYPE;
        defparam packet_client_200g_top.READY_LATENCY        = 0;
//      defparam packet_client_200g_top.WORDS                = 8;
				defparam packet_client_200g_top.WORDS_AVST           = ((PREAMBLE_PASS_TH_EN)? 512/2: 512)/64;
				defparam packet_client_200g_top.WORDS_MAC            = 8;
        defparam packet_client_200g_top.EMPTY_WIDTH          = 24;
        defparam packet_client_200g_top.LPBK_FIFO_ADDR_WIDTH = 8;
        defparam packet_client_200g_top.PKT_ROM_INIT_FILE    = PKT_ROM_INIT_FILE_200;
    end
endgenerate

//---------------------------------------------------------------
//---------------------------------------------------------------
// PTP Timestamp Accuracy Mode = "1:Advanced"


//---------------------------------------------------------------







//---------------------------------------------------------------

  logic [3:0] i_clk_tx_tod_temp = {i_p3_clk_tx_tod,i_p2_clk_tx_tod,i_p1_clk_tx_tod,i_p0_clk_tx_tod};
	logic [3:0] i_clk_rx_tod_temp = {i_p3_clk_rx_tod,i_p2_clk_rx_tod,i_p1_clk_rx_tod,i_p0_clk_rx_tod};
logic [3:0]  clk_tx_tod;
logic [3:0]  clk_rx_tod;
logic [3:0]  tx_tod_rst_n;
logic [3:0]  rx_tod_rst_n;


  logic [3:0] i_clk_tx_tod = {i_p3_clk_tx_tod,i_p2_clk_tx_tod,i_p1_clk_tx_tod,i_p0_clk_tx_tod};
	logic [3:0] i_clk_rx_tod = {i_p3_clk_rx_tod,i_p2_clk_rx_tod,i_p1_clk_rx_tod,i_p0_clk_rx_tod};
logic [95:0]  ptp_rx_tod[3:0];
logic [95:0]  ptp_tx_tod[3:0];
logic [3:0]  ptp_tx_tod_valid;
logic [3:0]  ptp_rx_tod_valid;



assign i_400g_clk_tx_tod      = i_p0_clk_tx_tod;
assign i_400g_tx_tod_rst_n    = tx_tod_rst_n[0];

assign i_200g_clk_tx_tod[0]   = i_p0_clk_tx_tod;
assign i_200g_tx_tod_rst_n[0] = tx_tod_rst_n[0];
assign i_200g_clk_tx_tod[1]   = i_p2_clk_tx_tod;
assign i_200g_tx_tod_rst_n[1] = tx_tod_rst_n[2];

assign i_100g_clk_tx_tod[0]   = i_p0_clk_tx_tod;
assign i_100g_tx_tod_rst_n[0] = tx_tod_rst_n[0];
assign i_100g_clk_tx_tod[1]   = i_p1_clk_tx_tod;
assign i_100g_tx_tod_rst_n[1] = tx_tod_rst_n[1];
assign i_100g_clk_tx_tod[2]   = i_p2_clk_tx_tod;
assign i_100g_tx_tod_rst_n[2] = tx_tod_rst_n[2];
assign i_100g_clk_tx_tod[3]   = i_p3_clk_tx_tod;
assign i_100g_tx_tod_rst_n[3] = tx_tod_rst_n[3];


	  assign p0_ptp_ets_valid  = i_p0_txegrts0_tvalid;
    assign p0_ptp_ets        = i_p0_txegrts0_tdata[(1*96)-1:0];
	  assign p0_ptp_ets_fp     = i_p0_txegrts0_tdata[(1*104)-1:96];
 


	  assign p1_ptp_ets_valid  = i_p1_txegrts0_tvalid;
    assign p1_ptp_ets        = i_p1_txegrts0_tdata[(1*96)-1:0];
	  assign p1_ptp_ets_fp     = i_p1_txegrts0_tdata[(1*104)-1:96];

//---------------------------------------------------------------




	  assign p2_ptp_ets_valid  = i_p2_txegrts0_tvalid;
    assign p2_ptp_ets        = i_p2_txegrts0_tdata[(1*96)-1:0];
	  assign p2_ptp_ets_fp     = i_p2_txegrts0_tdata[(1*104)-1:96];

 
 
	  assign p3_ptp_ets_valid  = i_p3_txegrts0_tvalid;
    assign p3_ptp_ets        = i_p3_txegrts0_tdata[(1*96)-1:0];
	  assign p3_ptp_ets_fp     = i_p3_txegrts0_tdata[(1*104)-1:96];

 
		assign i_p0_rst_n      = i_rst_n;
		assign i_p1_rst_n      = i_rst_n;
		assign i_p2_rst_n      = i_rst_n;
		assign i_p3_rst_n      = i_rst_n;

		assign p0_ptp_rx_tod = ptp_rx_tod[0];
		assign p1_ptp_rx_tod = ptp_rx_tod[1];
		assign p2_ptp_rx_tod = ptp_rx_tod[2];
		assign p3_ptp_rx_tod = ptp_rx_tod[3];

		assign p0_ptp_rx_tod_valid = ptp_rx_tod_valid[0];
		assign p1_ptp_rx_tod_valid = ptp_rx_tod_valid[1];
		assign p2_ptp_rx_tod_valid = ptp_rx_tod_valid[2];
		assign p3_ptp_rx_tod_valid = ptp_rx_tod_valid[3];

		assign p0_ptp_tx_tod = ptp_tx_tod[0];
		assign p1_ptp_tx_tod = ptp_tx_tod[1];
		assign p2_ptp_tx_tod = ptp_tx_tod[2];
		assign p3_ptp_tx_tod = ptp_tx_tod[3];

		assign p0_ptp_tx_tod_valid = ptp_tx_tod_valid[0];
		assign p1_ptp_tx_tod_valid = ptp_tx_tod_valid[1];
		assign p2_ptp_tx_tod_valid = ptp_tx_tod_valid[2];
		assign p3_ptp_tx_tod_valid = ptp_tx_tod_valid[3];

generate 
if (PTP_EN) begin:PTP_LOGIC
	genvar tod_inst_i;
	for (tod_inst_i = 0; tod_inst_i < 4; tod_inst_i ++) begin : PTP_TOD
		if (PTP_ACC_MODE == 0) begin //Basic Mode
  	  // PTP Timestamp Accuracy Mode = "0:Basic"
  	  assign clk_tx_tod[tod_inst_i]     	= i_clk_tx_tod_temp[tod_inst_i];
  	  assign clk_rx_tod[tod_inst_i]     	= i_clk_rx_tod_temp[tod_inst_i];
  	  assign tx_tod_rst_n[tod_inst_i]   	= i_tx_tod_rst_n;
  	  assign rx_tod_rst_n[tod_inst_i]   	= i_rx_tod_rst_n;
  	  assign ptp_tx_tod[tod_inst_i]       = i_ptp_ip_tod; 						//i_ptp_tx_tod,coming from ip_tod
  	  assign ptp_tx_tod_valid[tod_inst_i] = i_ptp_ip_tod_valid;
  	  assign ptp_rx_tod[tod_inst_i]       = i_ptp_ip_tod; 						// coming from ip_tod
  	  assign ptp_rx_tod_valid[tod_inst_i] = i_ptp_ip_tod_valid;
		end else begin
  	  // PTP Timestamp Accuracy Mode = "1:Advanced"
  	  logic [3:0]	tx_pll_locked_reg;
  	  logic [3:0]	cdr_lock_reg;
  	  logic [3:0]	tx_tod_rst_n_wire;
  	  logic [3:0]	tx_tod_rst_n_reg;
  	  logic [3:0]	rx_tod_rst_n_wire;
  	  logic [3:0]	rx_tod_rst_n_reg;
			logic [3:0] tx_pll_locked_sync;
			logic [3:0] tx_todsync_sampling_clk_locked_sync;
			logic [3:0] rx_todsync_sampling_clk_locked_sync;
			logic [3:0] rx_cdr_lock_sync;



			
  	  always @(posedge app_ss_lite_clk) begin
  	      tx_pll_locked_reg[tod_inst_i]   <= o_tx_pll_locked;
  	      cdr_lock_reg[tod_inst_i]        <= o_cdr_lock[tod_inst_i];
  	  end

  	  assign clk_tx_tod[tod_inst_i]        = i_clk_tx_tod_temp[tod_inst_i];
  	  assign clk_rx_tod[tod_inst_i]        = i_clk_rx_tod_temp[tod_inst_i];
  	  assign tx_tod_rst_n_wire[tod_inst_i] = tx_pll_locked_sync[tod_inst_i] & tx_todsync_sampling_clk_locked_sync[tod_inst_i];
  	  assign rx_tod_rst_n_wire[tod_inst_i] = rx_cdr_lock_sync[tod_inst_i] & rx_todsync_sampling_clk_locked_sync[tod_inst_i];
  	  
  	  // flops to fix recovery time violation from tx_tod_rst_n to tod_sync inst
  	  always @(posedge clk_tx_tod[tod_inst_i]) begin
  	      tx_tod_rst_n_reg[tod_inst_i]   <= tx_tod_rst_n_wire[tod_inst_i];
  	      tx_tod_rst_n[tod_inst_i]       <= tx_tod_rst_n_reg[tod_inst_i];
  	  end
  	  always @(posedge clk_rx_tod[tod_inst_i]) begin
  	      rx_tod_rst_n_reg[tod_inst_i]   <= rx_tod_rst_n_wire[tod_inst_i];
  	      rx_tod_rst_n[tod_inst_i]       <= rx_tod_rst_n_reg[tod_inst_i];
  	  end

  	  eth_f_altera_std_synchronizer_nocut tx_todsync_sampling_locked_sync_inst (
  	      .clk        (clk_tx_tod[tod_inst_i]),
  	      .reset_n    (1'b1),
  	      .din        (i_clk_todsync_sample_locked),
  	      .dout       (tx_todsync_sampling_clk_locked_sync[tod_inst_i])
  	  );
  	  eth_f_altera_std_synchronizer_nocut rx_todsync_sampling_locked_sync_inst (
  	      .clk        (clk_rx_tod[tod_inst_i]),
  	      .reset_n    (1'b1),
  	      .din        (i_clk_todsync_sample_locked),
  	      .dout       (rx_todsync_sampling_clk_locked_sync[tod_inst_i])
  	  );
  	  eth_f_altera_std_synchronizer_nocut tx_pll_locked_sync_inst (
  	      .clk        (clk_tx_tod[tod_inst_i]),
  	      .reset_n    (1'b1),
  	      .din        (tx_pll_locked_reg[tod_inst_i]),
  	      .dout       (tx_pll_locked_sync[tod_inst_i])
  	  );
  	  eth_f_altera_std_synchronizer_nocut rx_cdr_lock_sync_inst (
  	      .clk        (clk_rx_tod[tod_inst_i]),
  	      .reset_n    (1'b1),
  	      .din        (cdr_lock_reg[tod_inst_i]),
  	      .dout       (rx_cdr_lock_sync[tod_inst_i])
  	  );


  	  eth_f_ptp_stod_top #(
  	      .EN_10G_ADV_MODE (EN_10G_ADV_MODE)
  	  ) tx_tod (
  	      .i_clk_reconfig             (app_ss_lite_clk),
  	      .i_reconfig_rst_n           (app_ss_lite_areset_n),   
  	      .i_clk_mtod                 (i_clk_master_tod),        //input signal from top 
  	      .i_clk_stod                 (clk_tx_tod [tod_inst_i]),
  	      .i_clk_todsync_sampling     (i_clk_todsync_sample),    //coming from hw_top Module
  	      .i_mtod_rst_n               (i_ptp_master_tod_rst_n),
  	      .i_stod_rst_n               (tx_tod_rst_n [tod_inst_i]),
  	      .i_mtod_data                (i_ptp_master_tod),
  	      .i_mtod_valid               (i_ptp_master_tod_valid),
  	      .o_stod_data                (ptp_tx_tod [tod_inst_i]),
  	      .o_stod_valid               (ptp_tx_tod_valid [tod_inst_i])
  	  );
  	  eth_f_ptp_stod_top #(
  	      .EN_10G_ADV_MODE (EN_10G_ADV_MODE)                	
  	  ) rx_tod (
  	      .i_clk_reconfig             (app_ss_lite_clk),
  	      .i_reconfig_rst_n           (app_ss_lite_areset_n),
  	      .i_clk_mtod                 (i_clk_master_tod),
  	      .i_clk_stod                 (clk_rx_tod[tod_inst_i]),
  	      .i_clk_todsync_sampling     (i_clk_todsync_sample),
  	      .i_mtod_rst_n               (i_ptp_master_tod_rst_n),
  	      .i_stod_rst_n               (rx_tod_rst_n[tod_inst_i]),
  	      .i_mtod_data                (i_ptp_master_tod),
  	      .i_mtod_valid               (i_ptp_master_tod_valid),
  	      .o_stod_data                (ptp_rx_tod[tod_inst_i]),
  	      .o_stod_valid               (ptp_rx_tod_valid[tod_inst_i])
  	  );
		end
end
end
else
begin : NO_PTP
    assign tx_tod_rst_n     = 1'b1;
end
endgenerate


//---------------------------------------------------------------
endmodule // eth_f_hw_ip_top_400g



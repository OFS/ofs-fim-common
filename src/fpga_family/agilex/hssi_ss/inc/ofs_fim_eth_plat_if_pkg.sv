// Copyright (C) 2020 Intel Corporation.
// SPDX-License-Identifier: MIT

//
// Description
//-----------------------------------------------------------------------------
//
//  This package defines platform-specific parameters and types for
//  AXI-S interfaces to an Ethernet MAC. It is consumed by a platform-
//  independent wrapper, ofs_fim_eth_if_pkg.sv.
//
//----------------------------------------------------------------------------


`include "ofs_ip_cfg_db.vh"
`include "ofs_fim_eth_plat_defines.svh"

package ofs_fim_eth_plat_if_pkg;

`ifdef INCLUDE_CVL
   localparam MAX_NUM_ETH_CHANNELS = 16; // Ethernet Ports
`else
localparam MAX_NUM_ETH_CHANNELS = 16; // Ethernet Ports
`endif
`ifndef MAC_SEGMENTED
localparam NUM_QSFP_PORTS_USED  = 2; // Number of QSFP cages on board used by target hssi configuration
`else
localparam NUM_QSFP_PORTS_USED  = 1; // 1 QSFPDD cage used for 200G and 400G config   
`endif
localparam NUM_ETH_CHANNELS     = `OFS_FIM_IP_CFG_HSSI_SS_NUM_ETH_PORTS; // Number of ethernet ports used by target hssi configuration. For ex for 8x25G, 8 HSSI ports are active on HSSI IP 
localparam NUM_QSFP_LANES       = 4;    // Lanes/QSFP cage
localparam NUM_CVL_LANES        = 0;    // Number for Lanes for CVL
localparam NUM_LANES            = `OFS_FIM_IP_CFG_HSSI_SS_NUM_LANES;        // Number of XCVR Lanes/Port used by the configuration. For ex. for 100GCAUI-4, 4 lanes per HSSI port are used
localparam NUM_ETH_LANES        = NUM_ETH_CHANNELS*NUM_LANES; // Total XCVR lanes active = Number of ethernet ports active * number of lanes per port 
localparam ETH_PACKET_WIDTH     = `OFS_FIM_IP_CFG_HSSI_SS_ETH_PACKET_WIDTH;

localparam ETH_RX_ERROR_WIDTH = 6;
localparam ETH_TX_ERROR_WIDTH = 1;


`ifdef ETH_200G 
localparam ETH_RX_USER_STS_WIDTH       = 20;
`elsif ETH_400G
localparam ETH_RX_USER_STS_WIDTH       = 25;
`else //25G
localparam ETH_RX_USER_STS_WIDTH          = 5;
`endif


`ifdef ETH_200G 
localparam ETH_RX_USER_CLIENT_WIDTH       = 28;
`elsif ETH_400G
localparam ETH_RX_USER_CLIENT_WIDTH       = 35;
`else // 25G
localparam ETH_RX_USER_CLIENT_WIDTH       = 7;
`endif 

`ifdef ETH_200G 
localparam ETH_TX_USER_CLIENT_WIDTH       = 16;
`elsif ETH_400G
localparam ETH_TX_USER_CLIENT_WIDTH       = 32;
`else //25G
localparam ETH_TX_USER_CLIENT_WIDTH       = 2;
`endif

localparam ETH_TX_USER_PTP_WIDTH          = 94;
localparam ETH_TX_USER_PTP_EXTENDED_WIDTH = 328;
 
localparam ETH_TUSER_LAST_SEGMENT_WIDTH	=ETH_PACKET_WIDTH/64;

// Port enums have been moved to $OFS_ROOTDIR/ipss/hssi/inc/ofs_fim_eth_plat_defines.svh
// so that they can be accessed by UVM. The macro is INST_FULL_UVM_PORT_INDEX and is 
// represented by the following expression:
`INST_FULL_ENUM_PORT_INDEX
localparam int ETH_PORT_EN_ARRAY[NUM_ETH_CHANNELS + 1] = { `ENUM_PORT_INDEX 
                                                     PORT_MAX};


//----------------HE-HSSI related---------
typedef struct packed {
   // Error
   logic [ETH_RX_ERROR_WIDTH-1:0] error;
   `ifdef MAC_SEGMENTED // add last_segment interface signals when using MAC segmented mode in HSSI SS
	logic [ETH_TUSER_LAST_SEGMENT_WIDTH-1:0] last_segment;
    `endif
} t_axis_eth_rx_tuser;

typedef struct packed {
   // Error
   logic [ETH_TX_ERROR_WIDTH-1:0] error;
   `ifdef MAC_SEGMENTED // add last_segment interface signals when using MAC segmented mode in HSSI SS
	logic [ETH_TUSER_LAST_SEGMENT_WIDTH-1:0] last_segment;
    `endif	
} t_axis_eth_tx_tuser;

typedef struct packed {
   // Mapped to MAC's avalon_st_pause_data[1]
   logic pause_xoff;
   // Mapped to MAC's avalon_st_pause_data[0]
   logic pause_xon;
   logic [7:0] pfc_xoff;
} t_eth_sideband_to_mac;

// Not currently used
typedef struct packed {
   logic pfc_pause;
} t_eth_sideband_from_mac;



//----------------HSSI SS related---------

// SS user bits
typedef struct packed {
   logic [ETH_RX_USER_STS_WIDTH-1:0]    sts;
   logic [ETH_RX_USER_CLIENT_WIDTH-1:0] client;
`ifdef MAC_SEGMENTED // add last_segmented interface signals when using MAC segmented mode in HSSI SS
   logic [ETH_TUSER_LAST_SEGMENT_WIDTH-1:0] last_segment;
`endif
} t_axis_hssi_ss_rx_tuser;

typedef struct packed {
`ifdef INCLUDE_PTP
   logic [ETH_TX_USER_PTP_EXTENDED_WIDTH-1:0] ptp_extended;
   logic [ETH_TX_USER_PTP_WIDTH-1:0]          ptp;
`endif
   logic [ETH_TX_USER_CLIENT_WIDTH-1:0]       client;
`ifdef MAC_SEGMENTED // add last_segmented interface signals when using MAC segmented mode in HSSI SS
   logic [ETH_TUSER_LAST_SEGMENT_WIDTH-1:0] last_segment;
`endif
} t_axis_hssi_ss_tx_tuser;


// Clocks exported by the MAC for use by the AFU. The primary "clk" is
// guaranteed. Others are platform-specific.
typedef struct packed {
   logic clk;
   logic rst_n;

   logic clkDiv2;
   logic rstDiv2_n;
} t_eth_clocks;

endpackage

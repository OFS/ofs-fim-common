// Copyright (C) 2020 Intel Corporation.
// SPDX-License-Identifier: MIT

//
// Description
//-----------------------------------------------------------------------------
//
//  This package defines parameters for the F-tile AXI MAC-Segmented Traffic
//  generator used for 200G and 400G configurations. 
// 
//----------------------------------------------------------------------------


`include "ofs_ip_cfg_db.vh"

package ofs_fim_eth_f_traffic_controller_pkg;

`ifndef ETH_200G
	localparam EHIP_RATE		= "400G";
	localparam PORT_PROFILE		= "400GAUI-8";	
	localparam PKT_ROM_INIT_FILE	="eth_f_hw_pkt_gen_rom_init.400G_SEG.hex";
	localparam PKT_ROM_INIT_DATA	= "init_file_data.400G.hex" ; 
   	localparam PKT_ROM_INIT_CTL	= "init_file_ctrl.400G.hex";
`else
	localparam EHIP_RATE		= "200G";
	localparam PORT_PROFILE 	= "200GAUI-4";	
	localparam PKT_ROM_INIT_FILE	="eth_f_hw_pkt_gen_rom_init.200G_SEG.hex";
	localparam PKT_ROM_INIT_DATA 	= "init_file_data.200G.hex" ; 
    	localparam PKT_ROM_INIT_CTL	= "init_file_ctrl.200G.hex";
`endif

localparam DATA_WIDTH 			=  ofs_fim_eth_plat_if_pkg::ETH_PACKET_WIDTH;
localparam NO_OF_BYTES			=   (DATA_WIDTH/8);

endpackage 

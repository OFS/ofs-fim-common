// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


// Modified eth_f_hw ip_avmm_decoder.sv to produce an avmm decoder at hw_top level
// This module will decode addresses for the following modules
// PTP AIB6
// PTP AIB7
// hw_ip_top
// MTOD

`timescale 1 ps / 1 ps

module eth_f_hw_top_avmm_decoder #(
        parameter IP_NUM                 = 1,
        parameter AVMM_ADDR_WIDTH        = 32,
        parameter P2P_ADDR_WIDTH         = 12,  // ETH --> PTP P2P
        parameter ASYM_ADDR_WIDTH        = 12,  // + 1 --> PTP ASYM
        parameter HW_IP_ADDR_WIDTH       = 28,  // XCVR --> HW_IP
        parameter KR_IP_ADDR_WIDTH       = 12,  // XCVR --> KR_IP
        parameter TOD_ADDR_WIDTH         = 4,   // STATUS --> TOD
        parameter DATA_WIDTH             = 32,
        parameter BYTE_EN_WIDTH          = 4
  )(
    input  logic                   i_reconfig_clk,
    input  logic                   i_reconfig_reset,

    // Jtag avmm bus
    input   logic   [AVMM_ADDR_WIDTH-1:0]         i_jtag_address,
    input   logic                                 i_jtag_read,
    input   logic                                 i_jtag_write,
    input   logic   [DATA_WIDTH-1:0]              i_jtag_writedata,
    input   logic   [BYTE_EN_WIDTH-1:0]           i_jtag_byteenable,
    output  logic   [DATA_WIDTH-1:0]              o_jtag_readdata,
    output  logic                                 o_jtag_readdatavalid,
    output  logic                                 o_jtag_waitrequest,

    // slave reconfig Interface
    output  logic                                 o_reconfig_p2p_write,
    output  logic                                 o_reconfig_p2p_read,
    output  logic   [P2P_ADDR_WIDTH-1:0]          o_reconfig_p2p_addr,
    output  logic   [DATA_WIDTH-1:0]              o_reconfig_p2p_writedata,
    output  logic   [BYTE_EN_WIDTH-1:0]           o_reconfig_p2p_byteenable,
    input   logic   [DATA_WIDTH-1:0]              i_reconfig_p2p_readdata,
    input   logic                                 i_reconfig_p2p_readdata_valid,
    input   logic                                 i_reconfig_p2p_waitrequest,

    output  logic                                 o_reconfig_asym_write,
    output  logic                                 o_reconfig_asym_read,
    output  logic   [ASYM_ADDR_WIDTH-1:0]         o_reconfig_asym_addr,
    output  logic   [DATA_WIDTH-1:0]              o_reconfig_asym_writedata,
    output  logic   [BYTE_EN_WIDTH-1:0]           o_reconfig_asym_byteenable,
    input   logic   [DATA_WIDTH-1:0]              i_reconfig_asym_readdata,
    input   logic                                 i_reconfig_asym_readdata_valid,
    input   logic                                 i_reconfig_asym_waitrequest,

    output  logic   [IP_NUM-1:0]                  o_reconfig_hw_ip_write,
    output  logic   [IP_NUM-1:0]                  o_reconfig_hw_ip_read,
    output  logic   [IP_NUM*HW_IP_ADDR_WIDTH-1:0] o_reconfig_hw_ip_addr,
    output  logic   [IP_NUM*DATA_WIDTH-1:0]       o_reconfig_hw_ip_writedata,
    output  logic   [IP_NUM*BYTE_EN_WIDTH-1:0]    o_reconfig_hw_ip_byteenable,
    input   logic   [IP_NUM*DATA_WIDTH-1:0]       i_reconfig_hw_ip_readdata,
    input   logic   [IP_NUM-1:0]                  i_reconfig_hw_ip_readdata_valid,
    input   logic   [IP_NUM-1:0]                  i_reconfig_hw_ip_waitrequest,

    output  logic                                 o_reconfig_kr_ip_write,
    output  logic                                 o_reconfig_kr_ip_read,
    output  logic   [KR_IP_ADDR_WIDTH-1:0]        o_reconfig_kr_ip_addr,
    output  logic   [DATA_WIDTH-1:0]              o_reconfig_kr_ip_writedata,
    output  logic   [BYTE_EN_WIDTH-1:0]           o_reconfig_kr_ip_byteenable,
    input   logic   [DATA_WIDTH-1:0]              i_reconfig_kr_ip_readdata,
    input   logic                                 i_reconfig_kr_ip_readdata_valid,
    input   logic                                 i_reconfig_kr_ip_waitrequest,


    output  logic   [TOD_ADDR_WIDTH-1:0]          o_tod_addr,
    output  logic                                 o_tod_read,
    output  logic                                 o_tod_write,
    output  logic   [DATA_WIDTH-1:0]              o_tod_writedata,
    output  logic   [BYTE_EN_WIDTH-1:0]           o_tod_byteenable,
    input   logic   [DATA_WIDTH-1:0]              i_tod_readdata,
    input   logic                                 i_tod_readdata_valid,
    input   logic                                 i_tod_waitrequest,

    input   logic   [AVMM_ADDR_WIDTH-1:0]         i_asym_start_addr,
    input   logic   [AVMM_ADDR_WIDTH-1:0]         i_p2p_start_addr,
    input   logic   [AVMM_ADDR_WIDTH-1:0]         i_hw_ip_start_addr,
    input   logic   [AVMM_ADDR_WIDTH-1:0]         i_kr_ip_start_addr,
    input   logic   [AVMM_ADDR_WIDTH-1:0]         i_tod_start_addr
);

//---------------------------------------------------------------
//---Host Jtag avmm decoder parameter---
localparam  SLAVE_NUM           = 5;

//---hwip top avmm decoder parameter--- 
// just as there can be a number of XCVR's, 
// there can also be a number of hw_ip_top's in the future, 
// reuse this portion but replace XCVR with hw_ip_top
localparam  HWIP_SLAVE_NUM           = IP_NUM;
localparam  HWIP_AVMM_ADDR_WIDTH     = HW_IP_ADDR_WIDTH+4;

//---------------------------------------------------------------
logic [HWIP_AVMM_ADDR_WIDTH-1:0]            hwip_avmm_start_addr [0:IP_NUM-1];
logic [HWIP_AVMM_ADDR_WIDTH-1:0]            hwip_avmm_end_addr [0:IP_NUM-1];
logic [IP_NUM*HWIP_AVMM_ADDR_WIDTH-1:0]   hwip_avmm_start_addr_all, hwip_avmm_end_addr_all;
logic [3:0]  lane_start_addr[0:IP_NUM-1];

genvar i, k;
generate 
    for (i=0; i<IP_NUM; i=i+1) begin:HWIP_addr_init
        assign lane_start_addr[i] = i;
        assign hwip_avmm_start_addr[i] = {lane_start_addr[i], {HW_IP_ADDR_WIDTH{1'b0}}};
        assign hwip_avmm_end_addr[i]   = {lane_start_addr[i], {HW_IP_ADDR_WIDTH{1'b1}}};
    end
    for (i=0; i<IP_NUM; i=i+1) begin:HWIP_2Dto1D
        for (k=0; k<HWIP_AVMM_ADDR_WIDTH; k=k+1) begin:HWIP_addr_assign
            assign hwip_avmm_start_addr_all[i*HWIP_AVMM_ADDR_WIDTH + k] = hwip_avmm_start_addr[i][k];
            assign hwip_avmm_end_addr_all[i*HWIP_AVMM_ADDR_WIDTH + k]   = hwip_avmm_end_addr[i][k];
        end
    end
endgenerate

//---------------------------------------------------------------
//---xcvr avmm master Interface---
logic                                 hwip_master_write;
logic                                 hwip_master_read;
logic    [HWIP_AVMM_ADDR_WIDTH-1:0]   hwip_master_addr;
logic    [DATA_WIDTH-1:0]             hwip_master_writedata;
logic    [BYTE_EN_WIDTH-1:0]          hwip_master_byteenable;
logic    [DATA_WIDTH-1:0]             hwip_master_readdata;
logic                                 hwip_master_readdata_valid;
logic                                 hwip_master_waitrequest;

//---------------------------------------------------------------
logic   [AVMM_ADDR_WIDTH-1:0]                 slave_addr;
logic   [DATA_WIDTH-1:0]                      slave_writedata;
logic   [BYTE_EN_WIDTH-1:0]                   slave_byteenable;
logic   [SLAVE_NUM-1:0]                       slave_read;
logic   [SLAVE_NUM-1:0]                       slave_write;
logic   [SLAVE_NUM*DATA_WIDTH-1:0]            slave_readdata;
logic   [SLAVE_NUM-1:0]                       slave_readdatavalid;
logic   [SLAVE_NUM-1:0]                       slave_waitrequest;
logic   [SLAVE_NUM*AVMM_ADDR_WIDTH-1:0]       slave_start_addr;
logic   [SLAVE_NUM*AVMM_ADDR_WIDTH-1:0]       slave_end_addr;

//---------------------------------------------------------------
assign o_reconfig_kr_ip_addr       = slave_addr[KR_IP_ADDR_WIDTH-1:0];
assign o_reconfig_kr_ip_writedata  = slave_writedata;
assign o_reconfig_kr_ip_byteenable = slave_byteenable;
assign o_reconfig_kr_ip_read       = slave_read[4];
assign o_reconfig_kr_ip_write      = slave_write[4];
assign slave_readdata[32*5-1:32*4] = i_reconfig_kr_ip_readdata;
assign slave_readdatavalid[4]      = i_reconfig_kr_ip_readdata_valid;
assign slave_waitrequest[4]        = i_reconfig_kr_ip_waitrequest;

assign o_reconfig_p2p_addr         = slave_addr[P2P_ADDR_WIDTH-1:0];
assign o_reconfig_p2p_writedata    = slave_writedata;
assign o_reconfig_p2p_byteenable   = slave_byteenable;
assign o_reconfig_p2p_read         = slave_read[3];
assign o_reconfig_p2p_write        = slave_write[3];
assign slave_readdata[32*4-1:32*3] = i_reconfig_p2p_readdata;
assign slave_readdatavalid[3]      = i_reconfig_p2p_readdata_valid;
assign slave_waitrequest[3]        = i_reconfig_p2p_waitrequest;

assign o_reconfig_asym_addr        = slave_addr[ASYM_ADDR_WIDTH-1:0];
assign o_reconfig_asym_writedata   = slave_writedata;
assign o_reconfig_asym_byteenable  = slave_byteenable;
assign o_reconfig_asym_read        = slave_read[2];
assign o_reconfig_asym_write       = slave_write[2];
assign slave_readdata[32*3-1:32*2] = i_reconfig_asym_readdata;
assign slave_readdatavalid[2]      = i_reconfig_asym_readdata_valid;
assign slave_waitrequest[2]        = i_reconfig_asym_waitrequest;

assign o_tod_addr                  = slave_addr[TOD_ADDR_WIDTH-1:0];
assign o_tod_writedata             = slave_writedata;
assign o_tod_byteenable            = slave_byteenable;
assign o_tod_read                  = slave_read[1];
assign o_tod_write                 = slave_write[1];
assign slave_readdata[32*2-1:32*1] = i_tod_readdata;
assign slave_readdatavalid[1]      = i_tod_readdata_valid;
assign slave_waitrequest[1]        = i_tod_waitrequest;

assign hwip_master_addr            = slave_addr[HWIP_AVMM_ADDR_WIDTH-1:0];
assign hwip_master_writedata       = slave_writedata;
assign hwip_master_byteenable      = slave_byteenable;
assign hwip_master_read            = slave_read[0];
assign hwip_master_write           = slave_write[0];
assign slave_readdata[32*1-1:32*0] = hwip_master_readdata;
assign slave_readdatavalid[0]      = hwip_master_readdata_valid;
assign slave_waitrequest[0]        = hwip_master_waitrequest;


//---------------------------------------------------------------
assign slave_end_addr[AVMM_ADDR_WIDTH*1-1:AVMM_ADDR_WIDTH*0]   = i_hw_ip_start_addr + {HWIP_AVMM_ADDR_WIDTH{1'b1}}; // hwip top end address
assign slave_end_addr[AVMM_ADDR_WIDTH*2-1:AVMM_ADDR_WIDTH*1]   = i_tod_start_addr   + {TOD_ADDR_WIDTH{1'b1}};       // tod end address
assign slave_end_addr[AVMM_ADDR_WIDTH*3-1:AVMM_ADDR_WIDTH*2]   = i_asym_start_addr  + {ASYM_ADDR_WIDTH{1'b1}};      // asym end address
assign slave_end_addr[AVMM_ADDR_WIDTH*4-1:AVMM_ADDR_WIDTH*3]   = i_p2p_start_addr   + {P2P_ADDR_WIDTH{1'b1}};       // p2p end address
assign slave_end_addr[AVMM_ADDR_WIDTH*5-1:AVMM_ADDR_WIDTH*4]   = i_kr_ip_start_addr + {KR_IP_ADDR_WIDTH{1'b1}};     // kr ip end address

assign slave_start_addr = {i_kr_ip_start_addr, i_p2p_start_addr, i_asym_start_addr, i_tod_start_addr, i_hw_ip_start_addr};

//---------------------------------------------------------------
eth_f_hw_avmm_decoder host_avmm_decoder (
        .clk (i_reconfig_clk),
        .rst (i_reconfig_reset),

        //---avmm master from Jtag---
        .master_addr             (i_jtag_address),
        .master_read             (i_jtag_read),
        .master_write            (i_jtag_write),
        .master_writedata        (i_jtag_writedata),
        .master_byteenable       (i_jtag_byteenable),
        .master_readdata         (o_jtag_readdata),
        .master_readdatavalid    (o_jtag_readdatavalid),
        .master_waitrequest      (o_jtag_waitrequest),

        //---avmm slave IF to HW IP---
        .slave_addr              (slave_addr          ),
        .slave_read              (slave_read          ),
        .slave_write             (slave_write         ),
        .slave_writedata         (slave_writedata     ),
        .slave_byteenable        (slave_byteenable    ),
        .slave_readdata          (slave_readdata      ),
        .slave_readdatavalid     (slave_readdatavalid),
        .slave_waitrequest       (slave_waitrequest   ),

        //---Ctrl IF---
        .slave_start_addr        (slave_start_addr),
        .slave_end_addr          (slave_end_addr)
);	
defparam    host_avmm_decoder.SLAVE_NUM     = SLAVE_NUM;
defparam    host_avmm_decoder.ADDR_WIDTH    = AVMM_ADDR_WIDTH;

//---------------------------------------------------------------
logic   [HWIP_AVMM_ADDR_WIDTH-1:0]                 hwip_slave_addr;
logic   [DATA_WIDTH-1:0]                           hwip_slave_writedata;
logic   [BYTE_EN_WIDTH-1:0]                        hwip_slave_byteenable;
logic   [HWIP_SLAVE_NUM-1:0]                       hwip_slave_read;
logic   [HWIP_SLAVE_NUM-1:0]                       hwip_slave_write;
logic   [HWIP_SLAVE_NUM*DATA_WIDTH-1:0]            hwip_slave_readdata;
logic   [HWIP_SLAVE_NUM-1:0]                       hwip_slave_readdatavalid;
logic   [HWIP_SLAVE_NUM-1:0]                       hwip_slave_waitrequest;
logic   [HWIP_SLAVE_NUM*HWIP_AVMM_ADDR_WIDTH-1:0]  hwip_slave_start_addr;
logic   [HWIP_SLAVE_NUM*HWIP_AVMM_ADDR_WIDTH-1:0]  hwip_slave_end_addr;

//---------------------------------------------------------------
assign o_reconfig_hw_ip_read     = hwip_slave_read;
assign o_reconfig_hw_ip_write    = hwip_slave_write;
assign hwip_slave_readdata      = i_reconfig_hw_ip_readdata;
assign hwip_slave_readdatavalid = i_reconfig_hw_ip_readdata_valid;
assign hwip_slave_waitrequest   = i_reconfig_hw_ip_waitrequest;

assign o_reconfig_hw_ip_addr       = {HWIP_SLAVE_NUM{hwip_slave_addr[HW_IP_ADDR_WIDTH-1:0]}};
assign o_reconfig_hw_ip_writedata  = {HWIP_SLAVE_NUM{hwip_slave_writedata}};
assign o_reconfig_hw_ip_byteenable = {HWIP_SLAVE_NUM{hwip_slave_byteenable}};

//---------------------------------------------------------------
eth_f_hw_avmm_decoder hwip_avmm_decoder (
        .clk (i_reconfig_clk),
        .rst (i_reconfig_reset),

        //---avmm master from Jtag---
        .master_addr              (hwip_master_addr),
        .master_read              (hwip_master_read),
        .master_write             (hwip_master_write),
        .master_writedata         (hwip_master_writedata),
        .master_byteenable        (hwip_master_byteenable),
        .master_readdata          (hwip_master_readdata),
        .master_readdatavalid     (hwip_master_readdata_valid),
        .master_waitrequest       (hwip_master_waitrequest),

        //---avmm slave IF to HW IP---
        .slave_addr              (hwip_slave_addr          ),
        .slave_read              (hwip_slave_read          ),
        .slave_write             (hwip_slave_write         ),
        .slave_writedata         (hwip_slave_writedata     ),
        .slave_byteenable        (hwip_slave_byteenable    ),
        .slave_readdata          (hwip_slave_readdata      ),
        .slave_readdatavalid     (hwip_slave_readdatavalid),
        .slave_waitrequest       (hwip_slave_waitrequest   ),

        //---Ctrl IF---
        .slave_start_addr        (hwip_avmm_start_addr_all),
        .slave_end_addr          (hwip_avmm_end_addr_all)
);	
defparam    hwip_avmm_decoder.SLAVE_NUM     = HWIP_SLAVE_NUM;
defparam    hwip_avmm_decoder.ADDR_WIDTH    = HWIP_AVMM_ADDR_WIDTH;

//---------------------------------------------------------------
endmodule

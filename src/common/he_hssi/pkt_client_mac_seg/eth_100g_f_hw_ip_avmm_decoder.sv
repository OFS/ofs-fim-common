// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`timescale 1 ps / 1 ps

module eth_100g_f_hw_ip_avmm_decoder #(
        parameter LANE_NUM               = 4,
        parameter AVMM_ADDR_WIDTH        = 32,
        parameter ETH_ADDR_WIDTH         = 17,
        parameter XCVR_ADDR_WIDTH        = 20,
        parameter STATUS_ADDR_WIDTH      = 16,
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
    output  logic                                 o_reconfig_eth_p0_write,
    output  logic                                 o_reconfig_eth_p0_read,
    output  logic   [ETH_ADDR_WIDTH-1:0]          o_reconfig_eth_p0_addr,
    output  logic   [DATA_WIDTH-1:0]              o_reconfig_eth_p0_writedata,
    output  logic   [BYTE_EN_WIDTH-1:0]           o_reconfig_eth_p0_byteenable,
    input   logic   [DATA_WIDTH-1:0]              i_reconfig_eth_p0_readdata,
    input   logic                                 i_reconfig_eth_p0_readdata_valid,
    input   logic                                 i_reconfig_eth_p0_waitrequest,
    
    output  logic                                 o_reconfig_eth_p1_write,
    output  logic                                 o_reconfig_eth_p1_read,
    output  logic   [ETH_ADDR_WIDTH-1:0]          o_reconfig_eth_p1_addr,
    output  logic   [DATA_WIDTH-1:0]              o_reconfig_eth_p1_writedata,
    output  logic   [BYTE_EN_WIDTH-1:0]           o_reconfig_eth_p1_byteenable,
    input   logic   [DATA_WIDTH-1:0]              i_reconfig_eth_p1_readdata,
    input   logic                                 i_reconfig_eth_p1_readdata_valid,
    input   logic                                 i_reconfig_eth_p1_waitrequest,    
    
    output  logic                                 o_reconfig_eth_p2_write,
    output  logic                                 o_reconfig_eth_p2_read,
    output  logic   [ETH_ADDR_WIDTH-1:0]          o_reconfig_eth_p2_addr,
    output  logic   [DATA_WIDTH-1:0]              o_reconfig_eth_p2_writedata,
    output  logic   [BYTE_EN_WIDTH-1:0]           o_reconfig_eth_p2_byteenable,
    input   logic   [DATA_WIDTH-1:0]              i_reconfig_eth_p2_readdata,
    input   logic                                 i_reconfig_eth_p2_readdata_valid,
    input   logic                                 i_reconfig_eth_p2_waitrequest,
    
    output  logic                                 o_reconfig_eth_p3_write,
    output  logic                                 o_reconfig_eth_p3_read,
    output  logic   [ETH_ADDR_WIDTH-1:0]          o_reconfig_eth_p3_addr,
    output  logic   [DATA_WIDTH-1:0]              o_reconfig_eth_p3_writedata,
    output  logic   [BYTE_EN_WIDTH-1:0]           o_reconfig_eth_p3_byteenable,
    input   logic   [DATA_WIDTH-1:0]              i_reconfig_eth_p3_readdata,
    input   logic                                 i_reconfig_eth_p3_readdata_valid,
    input   logic                                 i_reconfig_eth_p3_waitrequest,

    output  logic   [LANE_NUM-1:0]                o_reconfig_xcvr_write,
    output  logic   [LANE_NUM-1:0]                o_reconfig_xcvr_read,
    output  logic   [LANE_NUM*XCVR_ADDR_WIDTH-1:0] o_reconfig_xcvr_addr,
    output  logic   [LANE_NUM*DATA_WIDTH-1:0]     o_reconfig_xcvr_writedata,
    output  logic   [LANE_NUM*BYTE_EN_WIDTH-1:0]  o_reconfig_xcvr_byteenable,
    input   logic   [LANE_NUM*DATA_WIDTH-1:0]     i_reconfig_xcvr_readdata,
    input   logic   [LANE_NUM-1:0]                i_reconfig_xcvr_readdata_valid,
    input   logic   [LANE_NUM-1:0]                i_reconfig_xcvr_waitrequest,

    // 100G packet generator/checker
    output  logic   [STATUS_ADDR_WIDTH-1:0]       o_status_addr,
    output  logic                                 o_status_read,
    output  logic                                 o_status_write,
    output  logic   [DATA_WIDTH-1:0]              o_status_writedata,
    output  logic   [BYTE_EN_WIDTH-1:0]           o_status_byteenable,
    input   logic   [DATA_WIDTH-1:0]              i_status_readdata,
    input   logic                                 i_status_readdata_valid,
    input   logic                                 i_status_waitrequest,

    // 4x25G packet generator/checker
    output  logic   [STATUS_ADDR_WIDTH-1:0]       o_25g_0_status_addr,
    output  logic                                 o_25g_0_status_read,
    output  logic                                 o_25g_0_status_write,
    output  logic   [DATA_WIDTH-1:0]              o_25g_0_status_writedata,
    output  logic   [BYTE_EN_WIDTH-1:0]           o_25g_0_status_byteenable,
    input   logic   [DATA_WIDTH-1:0]              i_25g_0_status_readdata,
    input   logic                                 i_25g_0_status_readdata_valid,
    input   logic                                 i_25g_0_status_waitrequest,

    output  logic   [STATUS_ADDR_WIDTH-1:0]       o_25g_1_status_addr,
    output  logic                                 o_25g_1_status_read,
    output  logic                                 o_25g_1_status_write,
    output  logic   [DATA_WIDTH-1:0]              o_25g_1_status_writedata,
    output  logic   [BYTE_EN_WIDTH-1:0]           o_25g_1_status_byteenable,
    input   logic   [DATA_WIDTH-1:0]              i_25g_1_status_readdata,
    input   logic                                 i_25g_1_status_readdata_valid,
    input   logic                                 i_25g_1_status_waitrequest,
    
    output  logic   [STATUS_ADDR_WIDTH-1:0]       o_25g_2_status_addr,
    output  logic                                 o_25g_2_status_read,
    output  logic                                 o_25g_2_status_write,
    output  logic   [DATA_WIDTH-1:0]              o_25g_2_status_writedata,
    output  logic   [BYTE_EN_WIDTH-1:0]           o_25g_2_status_byteenable,
    input   logic   [DATA_WIDTH-1:0]              i_25g_2_status_readdata,
    input   logic                                 i_25g_2_status_readdata_valid,
    input   logic                                 i_25g_2_status_waitrequest,

    output  logic   [STATUS_ADDR_WIDTH-1:0]       o_25g_3_status_addr,
    output  logic                                 o_25g_3_status_read,
    output  logic                                 o_25g_3_status_write,
    output  logic   [DATA_WIDTH-1:0]              o_25g_3_status_writedata,
    output  logic   [BYTE_EN_WIDTH-1:0]           o_25g_3_status_byteenable,
    input   logic   [DATA_WIDTH-1:0]              i_25g_3_status_readdata,
    input   logic                                 i_25g_3_status_readdata_valid,
    input   logic                                 i_25g_3_status_waitrequest,

    // 2x50G packet generator/checker
    output  logic   [STATUS_ADDR_WIDTH-1:0]       o_50g_0_status_addr,
    output  logic                                 o_50g_0_status_read,
    output  logic                                 o_50g_0_status_write,
    output  logic   [DATA_WIDTH-1:0]              o_50g_0_status_writedata,
    output  logic   [BYTE_EN_WIDTH-1:0]           o_50g_0_status_byteenable,
    input   logic   [DATA_WIDTH-1:0]              i_50g_0_status_readdata,
    input   logic                                 i_50g_0_status_readdata_valid,
    input   logic                                 i_50g_0_status_waitrequest,

    output  logic   [STATUS_ADDR_WIDTH-1:0]       o_50g_1_status_addr,
    output  logic                                 o_50g_1_status_read,
    output  logic                                 o_50g_1_status_write,
    output  logic   [DATA_WIDTH-1:0]              o_50g_1_status_writedata,
    output  logic   [BYTE_EN_WIDTH-1:0]           o_50g_1_status_byteenable,
    input   logic   [DATA_WIDTH-1:0]              i_50g_1_status_readdata,
    input   logic                                 i_50g_1_status_readdata_valid,
    input   logic                                 i_50g_1_status_waitrequest,

    input   logic   [AVMM_ADDR_WIDTH-1:0]         i_eth_p0_start_addr,
    input   logic   [AVMM_ADDR_WIDTH-1:0]         i_eth_p1_start_addr,
    input   logic   [AVMM_ADDR_WIDTH-1:0]         i_eth_p2_start_addr,
    input   logic   [AVMM_ADDR_WIDTH-1:0]         i_eth_p3_start_addr,
    input   logic   [AVMM_ADDR_WIDTH-1:0]         i_xcvr_start_addr,
    input   logic   [AVMM_ADDR_WIDTH-1:0]         i_status_start_addr,
    input   logic   [AVMM_ADDR_WIDTH-1:0]         i_25g_0_status_start_addr,
    input   logic   [AVMM_ADDR_WIDTH-1:0]         i_25g_1_status_start_addr,
    input   logic   [AVMM_ADDR_WIDTH-1:0]         i_25g_2_status_start_addr,
    input   logic   [AVMM_ADDR_WIDTH-1:0]         i_25g_3_status_start_addr,
    input   logic   [AVMM_ADDR_WIDTH-1:0]         i_50g_0_status_start_addr,
    input   logic   [AVMM_ADDR_WIDTH-1:0]         i_50g_1_status_start_addr
);

//---------------------------------------------------------------
//---Host Jtag avmm decoder parameter---
localparam  SLAVE_NUM           = 6 + 4 + 2;

//---xcvr avmm decoder parameter---
localparam  XCVR_SLAVE_NUM           = LANE_NUM;
localparam  XCVR_AVMM_ADDR_WIDTH     = XCVR_ADDR_WIDTH+4;

//---------------------------------------------------------------
logic [XCVR_AVMM_ADDR_WIDTH-1:0]            xcvr_avmm_start_addr [0:LANE_NUM-1];
logic [XCVR_AVMM_ADDR_WIDTH-1:0]            xcvr_avmm_end_addr [0:LANE_NUM-1];
logic [LANE_NUM*XCVR_AVMM_ADDR_WIDTH-1:0]   xcvr_avmm_start_addr_all, xcvr_avmm_end_addr_all;
logic [3:0]  lane_start_addr[0:LANE_NUM-1];

genvar i, k;
generate 
    for (i=0; i<LANE_NUM; i=i+1) begin:XCVR_addr_init
        assign lane_start_addr[i] = i + 8;
        assign xcvr_avmm_start_addr[i] = {lane_start_addr[i], {XCVR_ADDR_WIDTH{1'b0}}};
        assign xcvr_avmm_end_addr[i]   = {lane_start_addr[i], {XCVR_ADDR_WIDTH{1'b1}}};
    end
    for (i=0; i<LANE_NUM; i=i+1) begin:XCVR_2Dto1D
        for (k=0; k<XCVR_AVMM_ADDR_WIDTH; k=k+1) begin:XCVR_addr_assign
            assign xcvr_avmm_start_addr_all[i*XCVR_AVMM_ADDR_WIDTH + k] = xcvr_avmm_start_addr[i][k];
            assign xcvr_avmm_end_addr_all[i*XCVR_AVMM_ADDR_WIDTH + k]   = xcvr_avmm_end_addr[i][k];
        end
    end
endgenerate

//---------------------------------------------------------------
//---xcvr avmm master Interface---
logic                                 xcvr_master_write;
logic                                 xcvr_master_read;
logic    [XCVR_AVMM_ADDR_WIDTH-1:0]   xcvr_master_addr;
logic    [DATA_WIDTH-1:0]             xcvr_master_writedata;
logic    [BYTE_EN_WIDTH-1:0]          xcvr_master_byteenable;
logic    [DATA_WIDTH-1:0]             xcvr_master_readdata;
logic                                 xcvr_master_readdata_valid;
logic                                 xcvr_master_waitrequest;

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
assign o_reconfig_eth_p0_addr         = slave_addr[ETH_ADDR_WIDTH-1:0];
assign o_reconfig_eth_p0_writedata    = slave_writedata;
assign o_reconfig_eth_p0_byteenable   = slave_byteenable;
assign o_reconfig_eth_p0_read         = slave_read[0];
assign o_reconfig_eth_p0_write        = slave_write[0];
assign slave_readdata[32*1-1:32*0] = i_reconfig_eth_p0_readdata;
assign slave_readdatavalid[0]      = i_reconfig_eth_p0_readdata_valid;
assign slave_waitrequest[0]        = i_reconfig_eth_p0_waitrequest;

assign o_reconfig_eth_p1_addr         = slave_addr[ETH_ADDR_WIDTH-1:0];
assign o_reconfig_eth_p1_writedata    = slave_writedata;
assign o_reconfig_eth_p1_byteenable   = slave_byteenable;
assign o_reconfig_eth_p1_read         = slave_read[1];
assign o_reconfig_eth_p1_write        = slave_write[1];
assign slave_readdata[32*2-1:32*1] = i_reconfig_eth_p1_readdata;
assign slave_readdatavalid[1]      = i_reconfig_eth_p1_readdata_valid;
assign slave_waitrequest[1]        = i_reconfig_eth_p1_waitrequest;

assign o_reconfig_eth_p2_addr         = slave_addr[ETH_ADDR_WIDTH-1:0];
assign o_reconfig_eth_p2_writedata    = slave_writedata;
assign o_reconfig_eth_p2_byteenable   = slave_byteenable;
assign o_reconfig_eth_p2_read         = slave_read[2];
assign o_reconfig_eth_p2_write        = slave_write[2];
assign slave_readdata[32*3-1:32*2] = i_reconfig_eth_p2_readdata;
assign slave_readdatavalid[2]      = i_reconfig_eth_p2_readdata_valid;
assign slave_waitrequest[2]        = i_reconfig_eth_p2_waitrequest;

assign o_reconfig_eth_p3_addr         = slave_addr[ETH_ADDR_WIDTH-1:0];
assign o_reconfig_eth_p3_writedata    = slave_writedata;
assign o_reconfig_eth_p3_byteenable   = slave_byteenable;
assign o_reconfig_eth_p3_read         = slave_read[3];
assign o_reconfig_eth_p3_write        = slave_write[3];
assign slave_readdata[32*4-1:32*3] = i_reconfig_eth_p3_readdata;
assign slave_readdatavalid[3]      = i_reconfig_eth_p3_readdata_valid;
assign slave_waitrequest[3]        = i_reconfig_eth_p3_waitrequest;

assign o_status_addr               = slave_addr[STATUS_ADDR_WIDTH-1:0];
assign o_status_writedata          = slave_writedata;
assign o_status_byteenable         = slave_byteenable;
assign o_status_read               = slave_read[4];
assign o_status_write              = slave_write[4];
assign slave_readdata[32*5-1:32*4] = i_status_readdata;
assign slave_readdatavalid[4]      = i_status_readdata_valid;
assign slave_waitrequest[4]        = i_status_waitrequest;

assign xcvr_master_addr            = slave_addr[XCVR_AVMM_ADDR_WIDTH-1:0];
assign xcvr_master_writedata       = slave_writedata;
assign xcvr_master_byteenable      = slave_byteenable;
assign xcvr_master_read            = slave_read[5];
assign xcvr_master_write           = slave_write[5];
assign slave_readdata[32*6-1:32*5] = xcvr_master_readdata;
assign slave_readdatavalid[5]      = xcvr_master_readdata_valid;
assign slave_waitrequest[5]        = xcvr_master_waitrequest;

assign o_25g_0_status_addr         = slave_addr[STATUS_ADDR_WIDTH-1:0];
assign o_25g_0_status_writedata    = slave_writedata;
assign o_25g_0_status_byteenable   = slave_byteenable;
assign o_25g_0_status_read         = slave_read[6];
assign o_25g_0_status_write        = slave_write[6];
assign slave_readdata[32*7-1:32*6] = i_25g_0_status_readdata;
assign slave_readdatavalid[6]      = i_25g_0_status_readdata_valid;
assign slave_waitrequest[6]        = i_25g_0_status_waitrequest;

assign o_25g_1_status_addr         = slave_addr[STATUS_ADDR_WIDTH-1:0];
assign o_25g_1_status_writedata    = slave_writedata;
assign o_25g_1_status_byteenable   = slave_byteenable;
assign o_25g_1_status_read         = slave_read[7];
assign o_25g_1_status_write        = slave_write[7];
assign slave_readdata[32*8-1:32*7] = i_25g_1_status_readdata;
assign slave_readdatavalid[7]      = i_25g_1_status_readdata_valid;
assign slave_waitrequest[7]        = i_25g_1_status_waitrequest;

assign o_25g_2_status_addr         = slave_addr[STATUS_ADDR_WIDTH-1:0];
assign o_25g_2_status_writedata    = slave_writedata;
assign o_25g_2_status_byteenable   = slave_byteenable;
assign o_25g_2_status_read         = slave_read[8];
assign o_25g_2_status_write        = slave_write[8];
assign slave_readdata[32*9-1:32*8] = i_25g_2_status_readdata;
assign slave_readdatavalid[8]      = i_25g_2_status_readdata_valid;
assign slave_waitrequest[8]        = i_25g_2_status_waitrequest;

assign o_25g_3_status_addr         = slave_addr[STATUS_ADDR_WIDTH-1:0];
assign o_25g_3_status_writedata    = slave_writedata;
assign o_25g_3_status_byteenable   = slave_byteenable;
assign o_25g_3_status_read         = slave_read[9];
assign o_25g_3_status_write        = slave_write[9];
assign slave_readdata[32*10-1:32*9] = i_25g_3_status_readdata;
assign slave_readdatavalid[9]      = i_25g_3_status_readdata_valid;
assign slave_waitrequest[9]        = i_25g_3_status_waitrequest;

assign o_50g_0_status_addr         = slave_addr[STATUS_ADDR_WIDTH-1:0];
assign o_50g_0_status_writedata    = slave_writedata;
assign o_50g_0_status_byteenable   = slave_byteenable;
assign o_50g_0_status_read         = slave_read[10];
assign o_50g_0_status_write        = slave_write[10];
assign slave_readdata[32*11-1:32*10] = i_50g_0_status_readdata;
assign slave_readdatavalid[10]      = i_50g_0_status_readdata_valid;
assign slave_waitrequest[10]        = i_50g_0_status_waitrequest;

assign o_50g_1_status_addr         = slave_addr[STATUS_ADDR_WIDTH-1:0];
assign o_50g_1_status_writedata    = slave_writedata;
assign o_50g_1_status_byteenable   = slave_byteenable;
assign o_50g_1_status_read         = slave_read[11];
assign o_50g_1_status_write        = slave_write[11];
assign slave_readdata[32*12-1:32*11] = i_50g_1_status_readdata;
assign slave_readdatavalid[11]      = i_50g_1_status_readdata_valid;
assign slave_waitrequest[11]        = i_50g_1_status_waitrequest;

//---------------------------------------------------------------
assign slave_end_addr[AVMM_ADDR_WIDTH*1-1:AVMM_ADDR_WIDTH*0]   = i_eth_p0_start_addr + {ETH_ADDR_WIDTH{1'b1}};        // eth end address
assign slave_end_addr[AVMM_ADDR_WIDTH*2-1:AVMM_ADDR_WIDTH*1]   = i_eth_p1_start_addr + {ETH_ADDR_WIDTH{1'b1}};        // eth end address
assign slave_end_addr[AVMM_ADDR_WIDTH*3-1:AVMM_ADDR_WIDTH*2]   = i_eth_p2_start_addr + {ETH_ADDR_WIDTH{1'b1}};        // eth end address
assign slave_end_addr[AVMM_ADDR_WIDTH*4-1:AVMM_ADDR_WIDTH*3]   = i_eth_p3_start_addr + {ETH_ADDR_WIDTH{1'b1}};        // eth end address
assign slave_end_addr[AVMM_ADDR_WIDTH*5-1:AVMM_ADDR_WIDTH*4]   = i_status_start_addr + {STATUS_ADDR_WIDTH{1'b1}};     // packet client end address
assign slave_end_addr[AVMM_ADDR_WIDTH*6-1:AVMM_ADDR_WIDTH*5]   = {XCVR_AVMM_ADDR_WIDTH{1'b1}};                        // xcvr end address
assign slave_end_addr[AVMM_ADDR_WIDTH*7-1:AVMM_ADDR_WIDTH*6]   = i_25g_0_status_start_addr + {{STATUS_ADDR_WIDTH}{1'b1}};
assign slave_end_addr[AVMM_ADDR_WIDTH*8-1:AVMM_ADDR_WIDTH*7]   = i_25g_1_status_start_addr + {{STATUS_ADDR_WIDTH}{1'b1}};
assign slave_end_addr[AVMM_ADDR_WIDTH*9-1:AVMM_ADDR_WIDTH*8]   = i_25g_2_status_start_addr + {{STATUS_ADDR_WIDTH}{1'b1}};
assign slave_end_addr[AVMM_ADDR_WIDTH*10-1:AVMM_ADDR_WIDTH*9]  = i_25g_3_status_start_addr + {{STATUS_ADDR_WIDTH}{1'b1}};
assign slave_end_addr[AVMM_ADDR_WIDTH*11-1:AVMM_ADDR_WIDTH*10] = i_50g_0_status_start_addr + {{STATUS_ADDR_WIDTH}{1'b1}};
assign slave_end_addr[AVMM_ADDR_WIDTH*12-1:AVMM_ADDR_WIDTH*11] = i_50g_1_status_start_addr + {{STATUS_ADDR_WIDTH}{1'b1}};

assign slave_start_addr = { i_50g_1_status_start_addr, i_50g_0_status_start_addr,
                            i_25g_3_status_start_addr, i_25g_2_status_start_addr, 
                            i_25g_1_status_start_addr, i_25g_0_status_start_addr,
                            i_xcvr_start_addr, i_status_start_addr,
                            i_eth_p3_start_addr, i_eth_p2_start_addr,
                            i_eth_p1_start_addr, i_eth_p0_start_addr};

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
logic   [XCVR_AVMM_ADDR_WIDTH-1:0]                 xcvr_slave_addr;
logic   [DATA_WIDTH-1:0]                           xcvr_slave_writedata;
logic   [BYTE_EN_WIDTH-1:0]                        xcvr_slave_byteenable;
logic   [XCVR_SLAVE_NUM-1:0]                       xcvr_slave_read;
logic   [XCVR_SLAVE_NUM-1:0]                       xcvr_slave_write;
logic   [XCVR_SLAVE_NUM*DATA_WIDTH-1:0]            xcvr_slave_readdata;
logic   [XCVR_SLAVE_NUM-1:0]                       xcvr_slave_readdatavalid;
logic   [XCVR_SLAVE_NUM-1:0]                       xcvr_slave_waitrequest;
logic   [XCVR_SLAVE_NUM*XCVR_AVMM_ADDR_WIDTH-1:0]  xcvr_slave_start_addr;
logic   [XCVR_SLAVE_NUM*XCVR_AVMM_ADDR_WIDTH-1:0]  xcvr_slave_end_addr;

//---------------------------------------------------------------
assign o_reconfig_xcvr_read     = xcvr_slave_read;
assign o_reconfig_xcvr_write    = xcvr_slave_write;
assign xcvr_slave_readdata      = i_reconfig_xcvr_readdata;
assign xcvr_slave_readdatavalid = i_reconfig_xcvr_readdata_valid;
assign xcvr_slave_waitrequest   = i_reconfig_xcvr_waitrequest;

assign o_reconfig_xcvr_addr       = {XCVR_SLAVE_NUM{xcvr_slave_addr[XCVR_ADDR_WIDTH-1:0]}};
assign o_reconfig_xcvr_writedata  = {XCVR_SLAVE_NUM{xcvr_slave_writedata}};
assign o_reconfig_xcvr_byteenable = {XCVR_SLAVE_NUM{xcvr_slave_byteenable}};

//---------------------------------------------------------------
eth_f_hw_avmm_decoder xcvr_avmm_decoder (
        .clk (i_reconfig_clk),
        .rst (i_reconfig_reset),

        //---avmm master from Jtag---
        .master_addr              (xcvr_master_addr),
        .master_read              (xcvr_master_read),
        .master_write             (xcvr_master_write),
        .master_writedata         (xcvr_master_writedata),
        .master_byteenable        (xcvr_master_byteenable),
        .master_readdata          (xcvr_master_readdata),
        .master_readdatavalid     (xcvr_master_readdata_valid),
        .master_waitrequest       (xcvr_master_waitrequest),

        //---avmm slave IF to HW IP---
        .slave_addr              (xcvr_slave_addr          ),
        .slave_read              (xcvr_slave_read          ),
        .slave_write             (xcvr_slave_write         ),
        .slave_writedata         (xcvr_slave_writedata     ),
        .slave_byteenable        (xcvr_slave_byteenable    ),
        .slave_readdata          (xcvr_slave_readdata      ),
        .slave_readdatavalid     (xcvr_slave_readdatavalid),
        .slave_waitrequest       (xcvr_slave_waitrequest   ),

        //---Ctrl IF---
        .slave_start_addr        (xcvr_avmm_start_addr_all),
        .slave_end_addr          (xcvr_avmm_end_addr_all)
);	
defparam    xcvr_avmm_decoder.SLAVE_NUM     = XCVR_SLAVE_NUM;
defparam    xcvr_avmm_decoder.ADDR_WIDTH    = XCVR_AVMM_ADDR_WIDTH;

//---------------------------------------------------------------
endmodule

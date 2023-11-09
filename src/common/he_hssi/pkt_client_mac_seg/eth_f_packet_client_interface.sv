// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`timescale 1 ps / 1 ps

module eth_f_packet_client_interface #(
        parameter CLIENT_IF_TYPE    = 0,        // 0:Segmented; 1:AvST;
        parameter DATA_BCNT         = 8,
        parameter CTRL_BCNT         = 2,
        parameter WORDS             = 8, 
        parameter AVST_EMPTY_WIDTH  = 6    
    ) (
        input  logic        clk,
        input  logic        rst,
        input  logic        en,

        output logic                             data_req,
        input  logic                             din_vld,
        input  logic [DATA_BCNT*8-1:0]           data_bus,
        input  logic [CTRL_BCNT*8-1:0]           ctrl_bus,
	

        //---packet interface---Segmented Client Interface---
        input  logic                         tx_mac_ready,
        output logic                         tx_mac_valid,
        output logic [WORDS-1:0]             tx_mac_inframe,   
        output logic [WORDS*3-1:0]           tx_mac_eop_empty, 
        output logic [WORDS*64-1:0]          tx_mac_data,    
        output logic [WORDS-1:0]             tx_mac_error,  
        output logic                         tx_mac_skip_crc,

        //---packet interface---Avst Client Interface---MAC SOP-Aligned Client interface---
        input  logic                         tx_ready,
        output logic                         tx_valid,
        output logic                         tx_sop,
        output logic                         tx_eop,
        output logic [AVST_EMPTY_WIDTH-1:0]  tx_empty, 
        output logic [WORDS*64-1:0]          tx_data,  
        output logic                         tx_error, 
        output logic                         tx_skip_crc,

        //---csr interface---
        input  logic          stat_tx_cnt_clr,
        output logic [7:0]    stat_tx_sop_cnt,
        output logic [7:0]    stat_tx_eop_cnt,
        output logic [7:0]    stat_tx_err_cnt
);

//---------------------------------------------
logic data_valid, tx_wr;
logic tx_vld, tx_vld_avst, tx_vld_seg;

assign tx_vld = (CLIENT_IF_TYPE==0) ? tx_vld_seg : tx_vld_avst;

//---------------------------------------------
//assign data_req     = !data_valid | (!din_vld & tx_vld);
assign data_req     = tx_vld | !data_valid;
assign tx_wr        = din_vld & (!data_valid | tx_vld); 
assign tx_valid     = data_valid & tx_ready;
assign tx_mac_valid = data_valid & tx_mac_ready;

always @ (posedge clk) begin
    if (rst)              data_valid <= 1'b0;
    else if (tx_wr)       data_valid <= 1'b1;
    else if (tx_vld)      data_valid <= 1'b0;
end


//---------------------------------------------
///---Segmented IF---
//---------------------------------------------
localparam  SEG_SOP_POS          = 0;
localparam  SEG_EOP_POS          = 1;
localparam  SEG_SKIP_CRC_POS     = 3;
localparam  SEG_INFRAME_POS      = 8;
localparam  SEG_INFRAME_WIDTH    = WORDS*1;
localparam  SEG_EOP_EMPTY_POS    = SEG_INFRAME_POS + SEG_INFRAME_WIDTH;
localparam  SEG_EOP_EMPTY_WIDTH  = WORDS*3;
localparam  SEG_ERR_POS          = SEG_EOP_EMPTY_POS + SEG_EOP_EMPTY_WIDTH;
localparam  SEG_ERR_WIDTH        = WORDS*1;
//---------------------------------------------
logic [WORDS-1:0]             tx_mac_inframe_r;

logic tx_mac_sop, tx_mac_eop;
assign tx_mac_inframe = tx_mac_valid ? tx_mac_inframe_r : {WORDS{1'b0}};
assign tx_vld_seg = tx_mac_ready & tx_mac_valid;
always @ (posedge clk) begin
    if (rst) begin
            tx_mac_sop       <= 0;
            tx_mac_eop       <= 0;
            tx_mac_inframe_r <= 0;
            tx_mac_eop_empty <= 0;
            tx_mac_error     <= 0;
            tx_mac_skip_crc  <= 0;
            tx_mac_data      <= 0;
    end else if (tx_wr) begin
            tx_mac_sop       <= ctrl_bus[SEG_SOP_POS];
            tx_mac_eop       <= ctrl_bus[SEG_EOP_POS];
            tx_mac_skip_crc  <= ctrl_bus[SEG_SKIP_CRC_POS];
            tx_mac_inframe_r <= ctrl_bus[SEG_INFRAME_POS+SEG_INFRAME_WIDTH-1 : SEG_INFRAME_POS];
            tx_mac_eop_empty <= ctrl_bus[SEG_EOP_EMPTY_POS+SEG_EOP_EMPTY_WIDTH-1 : SEG_EOP_EMPTY_POS];
            tx_mac_error     <= ctrl_bus[SEG_ERR_POS+SEG_ERR_WIDTH-1 : SEG_ERR_POS];
            tx_mac_data      <= data_bus;
    end
end

//---------------------------------------------
logic [WORDS-1:0]   tx_mac_inframe_r2, seg_pkt_boundary, seg_pkt_sop, seg_pkt_eop;
logic [WORDS-1:0]   seg_pkt_sop_r, seg_pkt_eop_r;
logic [1:0]         seg_sop_cnt_in_1_cycle_r, seg_eop_cnt_in_1_cycle_r;
logic tx_mac_valid_r;

always @ (posedge clk)   tx_mac_valid_r <= tx_mac_valid;

always @ (posedge clk) begin
    if (rst) begin
            tx_mac_inframe_r2 <= 0;
            seg_pkt_sop_r     <= 0;
            seg_pkt_eop_r     <= 0;
    end else if (tx_mac_valid) begin
            tx_mac_inframe_r2 <= tx_mac_inframe_r;
            seg_pkt_sop_r     <= seg_pkt_sop;
            seg_pkt_eop_r     <= seg_pkt_eop;
    end
end

generate 
    if (WORDS==1) begin: WORDS_1
        assign seg_pkt_boundary = tx_mac_inframe_r2[WORDS-1] ^ tx_mac_inframe_r;
    end else begin: WORDS_more
        assign seg_pkt_boundary = {tx_mac_inframe_r[WORDS-2:0], tx_mac_inframe_r2[WORDS-1]} ^ tx_mac_inframe_r;
    end
endgenerate

assign seg_pkt_sop = seg_pkt_boundary & tx_mac_inframe_r;
assign seg_pkt_eop = seg_pkt_boundary & (~tx_mac_inframe_r);

integer i;
always @* begin
    seg_sop_cnt_in_1_cycle_r = 0;
    seg_eop_cnt_in_1_cycle_r = 0;
    for (i=0; i<WORDS; i=i+1) begin
        seg_sop_cnt_in_1_cycle_r = seg_sop_cnt_in_1_cycle_r + seg_pkt_sop_r[i];
        seg_eop_cnt_in_1_cycle_r = seg_eop_cnt_in_1_cycle_r + seg_pkt_eop_r[i];
    end
end

//---------------------------------------------
///---AvST IF---
//---------------------------------------------
localparam  AVST_SOP_POS      = 0;
localparam  AVST_EOP_POS      = 1;
localparam  AVST_ERR_POS      = 2;
localparam  AVST_CRC_POS      = 3;
localparam  AVST_EMPTY_POS    = 8;
//---------------------------------------------
logic tx_sop_r, tx_eop_r;

assign tx_sop = tx_valid & tx_sop_r;
assign tx_eop = tx_valid & tx_eop_r;
assign tx_vld_avst = tx_ready & tx_valid;
always @ (posedge clk) begin
    if (rst) begin
            tx_sop_r    <= 0;
            tx_eop_r    <= 0;
            tx_empty    <= 0;
            tx_error    <= 0;
            tx_skip_crc <= 0;
    end else if (tx_wr) begin
            tx_sop_r    <= ctrl_bus[AVST_SOP_POS];
            tx_eop_r    <= ctrl_bus[AVST_EOP_POS];
            tx_error    <= ctrl_bus[AVST_ERR_POS];
            tx_skip_crc <= ctrl_bus[AVST_CRC_POS];
            tx_empty    <= ctrl_bus[AVST_EMPTY_POS+AVST_EMPTY_WIDTH-1 : AVST_EMPTY_POS];
            tx_data     <= data_bus;
    end
end

//---------------------------------------------
logic stat_tx_cnt_clr_sync, stat_tx_cnt_clr_mac;
always @ (posedge clk) begin
    stat_tx_cnt_clr_sync <= stat_tx_cnt_clr;
    stat_tx_cnt_clr_mac  <= stat_tx_cnt_clr_sync;
end

always @ (posedge clk) begin
    if (rst | stat_tx_cnt_clr_mac) begin
        stat_tx_sop_cnt <= 0;
        stat_tx_eop_cnt <= 0;
    end else begin
        if (tx_sop)               stat_tx_sop_cnt <= stat_tx_sop_cnt + 1;
        else if (tx_mac_valid_r)  stat_tx_sop_cnt <= stat_tx_sop_cnt + seg_sop_cnt_in_1_cycle_r;
        if (tx_eop)               stat_tx_eop_cnt <= stat_tx_eop_cnt + 1;
        else if (tx_mac_valid_r)  stat_tx_eop_cnt <= stat_tx_eop_cnt + seg_eop_cnt_in_1_cycle_r;
    end
end

//---------------------------------------------------------------
logic [7:0]    stat_tx_sop_cnt_t;
logic [7:0]    stat_tx_eop_cnt_t;
logic [7:0]    stat_tx_err_cnt_t;
eth_f_pkt_stat_counter stat_counter (
       .i_clk            (clk),
       .i_rst            (rst),

        //---MAC AVST---
       .i_valid          (tx_vld_avst),
       .i_sop            (tx_sop),
       .i_eop            (tx_eop),
       .i_error          (tx_error),

        //---MAC segmented---
       .i_mac_valid      (tx_vld_seg),
       .i_mac_inframe    (tx_mac_inframe),
       .i_mac_error      (tx_mac_error),

        //---csr interface---
       .stat_cnt_clr        (stat_tx_cnt_clr_mac),
       .stat_sop_cnt        (stat_tx_sop_cnt_t),
       .stat_eop_cnt        (stat_tx_eop_cnt_t),
       .stat_err_cnt        (stat_tx_err_cnt_t)
);
defparam    stat_counter.WORDS              = WORDS;
defparam    stat_counter.CLIENT_IF_TYPE     = CLIENT_IF_TYPE;

//---------------------------------------------
endmodule



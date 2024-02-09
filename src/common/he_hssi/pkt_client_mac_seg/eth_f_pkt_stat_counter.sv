// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


module eth_f_pkt_stat_counter #(
        parameter CLIENT_IF_TYPE    = 1,
        parameter WORDS             = 8,
        parameter AVST_ERR_WIDTH    = 6,
        parameter SEG_ERR_WIDTH     = 16
    ) (
        input logic                   i_clk,
        input logic                   i_rst,
    
        //---MAC AVST---
        input logic                   i_valid,
        input logic                   i_sop,
        input logic                   i_eop,
        input logic [AVST_ERR_WIDTH-1:0]    i_error,

        //---MAC segmented---
        input logic                         i_mac_valid,
        input logic [WORDS-1:0]             i_mac_inframe,
        input logic [SEG_ERR_WIDTH-1:0]     i_mac_error,
        //input logic [WORDS-1:0]     i_mac_fcs_error,

        //---csr interface---
		  input  logic                   stat_cnt_clr,
        output  logic                  stat_lat_sop,
        output logic                   stat_cnt_vld,
        output logic [7:0]             stat_sop_cnt,
        output logic [7:0]             stat_eop_cnt,
        output logic [7:0]             stat_err_cnt
);

logic rst;
assign rst = i_rst | stat_cnt_clr;

//---------------------------------------------
logic avst_valid, avst_sop, avst_eop, avst_err;
logic seg_valid, seg_err;
logic [WORDS-1:0]  seg_inframe;
logic [WORDS-1:0] i_mac_err_2to1;
//---------------------------------------------
logic [WORDS-1:0]   seg_inframe_r, seg_pkt_boundary;
logic [WORDS-1:0]   seg_pkt_sop, seg_pkt_eop;
logic [WORDS-1:0]   seg_pkt_sop_r, seg_pkt_eop_r;
logic [1:0]         seg_sop_cnt_cyc_r, seg_eop_cnt_cyc_r;
logic seg_valid_r;

always @ (posedge i_clk) begin
    if (rst) begin
            avst_valid        <= 0;
            avst_sop          <= 0;
            avst_eop          <= 0;
            avst_err          <= 0;
            seg_valid         <= 0;
            seg_inframe       <= 0;
            seg_err           <= 0;
    end else begin
            avst_valid        <= i_valid;
            avst_sop          <= i_sop;
            avst_eop          <= i_eop;
            avst_err          <= |i_error;
            seg_valid         <= i_mac_valid;
            seg_inframe       <= i_mac_inframe & {WORDS{i_mac_valid}};
            seg_err           <= | (i_mac_err_2to1 & seg_pkt_eop );
    end
end

genvar k;
generate
    for (k=0; k<WORDS; k=k+1) begin:ERR_2_TO_1
       assign i_mac_err_2to1[k] = i_mac_error[k*2] | i_mac_error[k*2+1];
    end // ERR_2_TO_1
endgenerate

//---------------------------------------------
always @ (posedge i_clk)   seg_valid_r <= seg_valid;

always @ (posedge i_clk) begin
    if (rst) begin
            seg_inframe_r     <= 0;
            seg_pkt_sop_r     <= 0;
            seg_pkt_eop_r     <= 0;
    end else if (seg_valid) begin
            seg_inframe_r     <= seg_inframe;
            seg_pkt_sop_r     <= seg_pkt_sop;
            seg_pkt_eop_r     <= seg_pkt_eop;
    end
end

generate 
    if (WORDS==1) begin: WORDS_1
        assign seg_pkt_boundary = seg_inframe_r[WORDS-1] ^ seg_inframe;
    end else begin: WORDS_more
        assign seg_pkt_boundary = {seg_inframe[WORDS-2:0], seg_inframe_r[WORDS-1]} ^ seg_inframe;
    end
endgenerate

assign seg_pkt_sop = seg_pkt_boundary & seg_inframe;
assign seg_pkt_eop = seg_pkt_boundary & (~seg_inframe);

integer i;
always @* begin
    seg_sop_cnt_cyc_r = 0;
    seg_eop_cnt_cyc_r = 0;
    for (i=0; i<WORDS; i=i+1) begin
        seg_sop_cnt_cyc_r = seg_sop_cnt_cyc_r + seg_pkt_sop_r[i];
        seg_eop_cnt_cyc_r = seg_eop_cnt_cyc_r + seg_pkt_eop_r[i];
    end
end

//---------------------------------------------
logic stat_cnt_clr_sync, stat_cnt_clr_mac;
always @ (posedge i_clk) begin
    stat_cnt_clr_sync <= stat_cnt_clr;
    stat_cnt_clr_mac  <= stat_cnt_clr_sync;
end

logic [7:0]             stat_sop_cnt_t;
logic [7:0]             stat_eop_cnt_t;
logic [7:0]             stat_err_cnt_t;
generate
    if (CLIENT_IF_TYPE==0) begin: SEG_IF
        always @ (posedge i_clk) begin
            if (rst) begin
                stat_sop_cnt_t <= 0;
                stat_eop_cnt_t <= 0;
                stat_err_cnt_t <= 0;
					 stat_lat_sop   <= 0;
            end else begin
                if (seg_valid_r)       stat_sop_cnt_t <= stat_sop_cnt_t + seg_sop_cnt_cyc_r;
                if (seg_valid_r)       stat_eop_cnt_t <= stat_eop_cnt_t + seg_eop_cnt_cyc_r;
                if (seg_valid)         stat_err_cnt_t <= stat_err_cnt_t + seg_err;
					 if (seg_valid)         stat_lat_sop <= |seg_pkt_sop;
            end 
        end
    end else begin: AVST_IF
        always @ (posedge i_clk) begin
            if (rst) begin
                stat_sop_cnt_t <= 0;
                stat_eop_cnt_t <= 0;
                stat_err_cnt_t <= 0;
					 stat_lat_sop   <= 0;
            end else begin
                if (avst_valid)             stat_sop_cnt_t <= stat_sop_cnt_t + avst_sop;
                if (avst_valid)             stat_eop_cnt_t <= stat_eop_cnt_t + avst_eop;
                if (avst_valid)             stat_err_cnt_t <= stat_err_cnt_t + avst_err;
					 if (avst_valid)             stat_lat_sop <= avst_sop;
            end 
        end
    end
endgenerate

//---------------------------------------------
logic [3:0]     clk_cnt;
always @ (posedge i_clk) begin
    if (rst)    clk_cnt <= 4'b0;
    else        clk_cnt <= clk_cnt + 4'b1;
    if (rst)                       stat_cnt_vld <= 1'b0;
    else if (clk_cnt==4'h8)        stat_cnt_vld <= 1'b0;
    else if (clk_cnt==4'hF)        stat_cnt_vld <= 1'b1;
end

always @ (posedge i_clk) begin
    if (rst) begin
        stat_sop_cnt <= 0;
        stat_eop_cnt <= 0;
        stat_err_cnt <= 0;
    end else if (&clk_cnt) begin
        stat_sop_cnt <= stat_sop_cnt_t;
        stat_eop_cnt <= stat_eop_cnt_t;
        stat_err_cnt <= stat_err_cnt_t;
        
    end
end
 
//---------------------------------------------
endmodule

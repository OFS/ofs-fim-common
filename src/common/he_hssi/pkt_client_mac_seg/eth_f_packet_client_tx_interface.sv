// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`timescale 1 ps / 1 ps

module eth_f_packet_client_tx_interface #(
        parameter ENABLE_PTP        = 0,
        parameter PKT_CYL           = 0,
        parameter PTP_FP_WIDTH      = 0,
        parameter CLIENT_IF_TYPE    = 0,        // 0:Segmented; 1:AvST;
        parameter DATA_BCNT         = 8,
        parameter CTRL_BCNT         = 2,
        parameter PTP_BCNT          = 2,
        //parameter WORDS             = 8,
        parameter WORDS_AVST             = 8,
        parameter WORDS_MAC             = 8,
        parameter AVST_EMPTY_WIDTH  = 6
    ) (
        input  logic        clk,
        input  logic        rst,
        input  logic        tx_en,

        output logic                         data_req,
        input  logic                         din_vld,
        input  logic [DATA_BCNT*8-1:0]       data_bus,
        input  logic [CTRL_BCNT*8-1:0]       ctrl_bus,
        input  logic [PTP_BCNT*8-1:0]        ptp_bus,

        //---packet interface---Segmented Client Interface---
        input  logic                         tx_mac_ready,
        output logic                         tx_mac_valid,
        output logic [WORDS_MAC-1:0]             tx_mac_inframe,
        output logic [WORDS_MAC*3-1:0]           tx_mac_eop_empty,
        output logic [WORDS_MAC*64-1:0]          tx_mac_data,
        output logic [WORDS_MAC-1:0]             tx_mac_error,
        output logic [WORDS_MAC-1:0]             tx_mac_skip_crc,

        //---packet interface---Avst Client Interface---MAC SOP-Aligned Client interface---
        input  logic                         tx_ready,
        output logic                         tx_valid,
        output logic                         tx_sop,
        output logic                         tx_eop,
        output logic [AVST_EMPTY_WIDTH-1:0]  tx_empty,
        output logic [WORDS_AVST*64-1:0]          tx_data,
        output logic                         tx_error,
        output logic                         tx_skip_crc,

        // PTP Command Interface, driving to DUT
        output logic [PKT_CYL*1-1:0]         ptp_ins_ets,
        output logic [PKT_CYL*1-1:0]         ptp_ins_cf,
        output logic [PKT_CYL*1-1:0]         ptp_ins_zero_csum,
        output logic [PKT_CYL*1-1:0]         ptp_ins_update_eb,
        output logic [PKT_CYL*16-1:0]        ptp_ins_ts_offset,
        output logic [PKT_CYL*16-1:0]        ptp_ins_cf_offset,
        output logic [PKT_CYL*16-1:0]        ptp_ins_csum_offset,
        output logic [PKT_CYL*1-1:0]         ptp_p2p,
        output logic [PKT_CYL*1-1:0]         ptp_asym,
        output logic [PKT_CYL*1-1:0]         ptp_asym_sign,
        output logic [PKT_CYL*7-1:0]         ptp_asym_p2p_idx,
        output logic [PKT_CYL*1-1:0]         ptp_ts_req,
        output logic [PKT_CYL*PTP_FP_WIDTH-1:0]  ptp_fp,

        //---csr interface---
        input  logic          stat_tx_cnt_clr,
		  output logic          stat_tx_lat_sop,
        output logic          stat_tx_cnt_vld,
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
assign data_req     = (tx_vld | !data_valid) & tx_en;
assign tx_wr        = din_vld & (!data_valid | tx_vld) & tx_en; 
assign tx_valid     = data_valid & tx_ready;
assign tx_mac_valid = data_valid & tx_mac_ready;

always @ (posedge clk) begin
    if (rst)              data_valid <= 1'b0;
    else if (tx_wr)       data_valid <= 1'b1;
    else if (tx_vld)      data_valid <= 1'b0;
end


generate 
  if (CLIENT_IF_TYPE == 0) begin:SEG 
    //---------------------------------------------
    ///---Segmented IF---
    //---------------------------------------------
    localparam  SEG_SOP_POS          = 0;
    localparam  SEG_EOP_POS          = 1;
    localparam  SEG_SKIP_CRC_POS     = 3;
    localparam  SEG_INFRAME_POS      = 8;
    localparam  SEG_INFRAME_WIDTH    = WORDS_MAC*1;
    localparam  SEG_EOP_EMPTY_POS    = SEG_INFRAME_POS + SEG_INFRAME_WIDTH;
    localparam  SEG_EOP_EMPTY_WIDTH  = WORDS_MAC*3;
    localparam  SEG_ERR_POS          = SEG_EOP_EMPTY_POS + SEG_EOP_EMPTY_WIDTH;
    localparam  SEG_ERR_WIDTH        = WORDS_MAC*1;
    //---------------------------------------------
    logic [WORDS_MAC-1:0]             tx_mac_inframe_r;

    logic tx_mac_sop, tx_mac_eop;
    assign tx_mac_inframe = tx_mac_valid ? tx_mac_inframe_r : {WORDS_MAC{1'b0}};
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
                tx_mac_skip_crc  <= {WORDS_MAC{ctrl_bus[SEG_SKIP_CRC_POS]}};
                tx_mac_inframe_r <= ctrl_bus[SEG_INFRAME_POS+SEG_INFRAME_WIDTH-1 : SEG_INFRAME_POS];
                tx_mac_eop_empty <= ctrl_bus[SEG_EOP_EMPTY_POS+SEG_EOP_EMPTY_WIDTH-1 : SEG_EOP_EMPTY_POS];
                tx_mac_error     <= ctrl_bus[SEG_ERR_POS+SEG_ERR_WIDTH-1 : SEG_ERR_POS];
                tx_mac_data      <= data_bus;
        end
    end
    assign tx_sop      = 0;
    assign tx_eop      = 0;
    assign tx_vld_avst = 0;
    assign tx_empty    = 0;
    assign tx_error    = 0;
    assign tx_skip_crc = 0;
    assign tx_data     ='0;

    if (ENABLE_PTP == 1 & PKT_CYL == 2) begin : SEG_PTP_400G
    always @ (posedge clk) begin
        if (rst) begin
                ptp_ins_ets         <= 0;
                ptp_ins_cf          <= 0;
                ptp_ins_zero_csum   <= 0;
                ptp_ins_update_eb   <= 0;
                ptp_ins_ts_offset   <= 0;
                ptp_ins_cf_offset   <= 0;
                ptp_ins_csum_offset <= 0;
                ptp_p2p             <= 0;
                ptp_asym            <= 0;
                ptp_asym_sign       <= 0;
                ptp_asym_p2p_idx    <= 0;
                ptp_ts_req          <= 0;
                ptp_fp              <= 0;
        end else if (tx_wr) begin
                ptp_ins_ets         <= {ptp_bus[97]       , ptp_bus[1]    };
                ptp_ins_cf          <= {ptp_bus[98]       , ptp_bus[2]    };
                ptp_ins_zero_csum   <= {ptp_bus[99]       , ptp_bus[3]    };
                ptp_ins_update_eb   <= {ptp_bus[100]      , ptp_bus[4]    };
                ptp_ins_ts_offset   <= {ptp_bus[119:104]  , ptp_bus[23:8] };
                ptp_ins_cf_offset   <= {ptp_bus[135:120]  , ptp_bus[39:24]};
                ptp_ins_csum_offset <= {ptp_bus[151:136]  , ptp_bus[55:40]};
                ptp_p2p             <= {ptp_bus[101]      , ptp_bus[5]    };
                ptp_asym            <= {ptp_bus[102]      , ptp_bus[6]    };
                ptp_asym_sign       <= {ptp_bus[103]      , ptp_bus[7]    };
                ptp_asym_p2p_idx    <= {ptp_bus[190:184]  , ptp_bus[94:88]};
                ptp_ts_req          <= {ptp_bus[96]       , ptp_bus[0]    };
                ptp_fp              <= {ptp_bus[(152+PTP_FP_WIDTH-1):152]  , ptp_bus[(56+PTP_FP_WIDTH-1):56]};
        end
    end

    end else if (ENABLE_PTP == 1 & PKT_CYL == 1) begin : SEG_PTP
    always @ (posedge clk) begin
        if (rst) begin
                ptp_ins_ets         <= 0;
                ptp_ins_cf          <= 0;
                ptp_ins_zero_csum   <= 0;
                ptp_ins_update_eb   <= 0;
                ptp_ins_ts_offset   <= 0;
                ptp_ins_cf_offset   <= 0;
                ptp_ins_csum_offset <= 0;
                ptp_p2p             <= 0;
                ptp_asym            <= 0;
                ptp_asym_sign       <= 0;
                ptp_asym_p2p_idx    <= 0;
                ptp_ts_req          <= 0;
                ptp_fp              <= 0;
        end else if (tx_wr) begin
                ptp_ins_ets         <= ptp_bus[1];
                ptp_ins_cf          <= ptp_bus[2];
                ptp_ins_zero_csum   <= ptp_bus[3];
                ptp_ins_update_eb   <= ptp_bus[4];
                ptp_ins_ts_offset   <= ptp_bus[23:8];
                ptp_ins_cf_offset   <= ptp_bus[39:24];
                ptp_ins_csum_offset <= ptp_bus[55:40];
                ptp_p2p             <= ptp_bus[5];
                ptp_asym            <= ptp_bus[6];
                ptp_asym_sign       <= ptp_bus[7];
                ptp_asym_p2p_idx    <= ptp_bus[94:88];
                ptp_ts_req          <= ptp_bus[0];
                ptp_fp              <= ptp_bus[(56+PTP_FP_WIDTH-1):56];
        end
    end
    end else begin : SEG_NO_PTP
        assign ptp_ins_ets          = 0;
        assign ptp_ins_cf           = 0;
        assign ptp_ins_zero_csum    = 0;
        assign ptp_ins_update_eb    = 0;
        assign ptp_ins_ts_offset    = 0;
        assign ptp_ins_cf_offset    = 0;
        assign ptp_ins_csum_offset  = 0;
        assign ptp_p2p              = 0;
        assign ptp_asym             = 0;
        assign ptp_asym_sign        = 0;
        assign ptp_asym_p2p_idx     = 0;
        assign ptp_ts_req           = 0;
        assign ptp_fp               = 0;
    end
end else if (CLIENT_IF_TYPE == 1) begin:AVST
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
                tx_data     <= 0;
        end else if (tx_wr) begin
                tx_sop_r    <= ctrl_bus[AVST_SOP_POS];
                tx_eop_r    <= ctrl_bus[AVST_EOP_POS];
                tx_error    <= ctrl_bus[AVST_ERR_POS];
                tx_skip_crc <= ctrl_bus[AVST_CRC_POS];
                tx_empty    <= ctrl_bus[AVST_EMPTY_POS+AVST_EMPTY_WIDTH-1 : AVST_EMPTY_POS];
                tx_data     <= data_bus;
        end
    end
    assign tx_mac_eop_empty = 0;
    assign tx_mac_error     = 0;
    assign tx_mac_skip_crc  = 0;
    assign tx_mac_data      = 0;
    assign tx_mac_inframe   = 0;
    assign tx_vld_seg       = 0;

    if (ENABLE_PTP == 1) begin : AVST_PTP
    always @ (posedge clk) begin
        if (rst) begin
                ptp_ins_ets         <= 0;
                ptp_ins_cf          <= 0;
                ptp_ins_zero_csum   <= 0;
                ptp_ins_update_eb   <= 0;
                ptp_ins_ts_offset   <= 0;
                ptp_ins_cf_offset   <= 0;
                ptp_ins_csum_offset <= 0;
                ptp_p2p             <= 0;
                ptp_asym            <= 0;
                ptp_asym_sign       <= 0;
                ptp_asym_p2p_idx    <= 0;
                ptp_ts_req          <= 0;
                ptp_fp              <= 0;
        end else if (tx_wr) begin
                ptp_ins_ets         <= ptp_bus[1];
                ptp_ins_cf          <= ptp_bus[2];
                ptp_ins_zero_csum   <= ptp_bus[3];
                ptp_ins_update_eb   <= ptp_bus[4];
                ptp_ins_ts_offset   <= ptp_bus[23:8];
                ptp_ins_cf_offset   <= ptp_bus[39:24];
                ptp_ins_csum_offset <= ptp_bus[55:40];
                ptp_p2p             <= ptp_bus[5];
                ptp_asym            <= ptp_bus[6];
                ptp_asym_sign       <= ptp_bus[7];
                ptp_asym_p2p_idx    <= ptp_bus[94:88];
                ptp_ts_req          <= ptp_bus[0];
                ptp_fp              <= ptp_bus[(56+PTP_FP_WIDTH-1):56];
        end
    end
    end else begin : AVST_NO_PTP
        assign ptp_ins_ets          = 0;
        assign ptp_ins_cf           = 0;
        assign ptp_ins_zero_csum    = 0;
        assign ptp_ins_update_eb    = 0;
        assign ptp_ins_ts_offset    = 0;
        assign ptp_ins_cf_offset    = 0;
        assign ptp_ins_csum_offset  = 0;
        assign ptp_p2p              = 0;
        assign ptp_asym             = 0;
        assign ptp_asym_sign        = 0;
        assign ptp_asym_p2p_idx     = 0;
        assign ptp_ts_req           = 0;
        assign ptp_fp               = 0;
    end
end 
endgenerate

//---------------------------------------------------------------
logic stat_tx_cnt_clr_sync, stat_tx_cnt_clr_mac;
always @ (posedge clk) begin
    stat_tx_cnt_clr_sync <= stat_tx_cnt_clr;
    stat_tx_cnt_clr_mac  <= stat_tx_cnt_clr_sync;
end

wire [2*WORDS_MAC-1:0] tx_mac_error_exp; //tx_mac_error expand double to match rx_mac_error

genvar i;
generate
    for (i=0;i<WORDS_MAC;i=i+1) begin: mac_error_expand
        assign tx_mac_error_exp[i*2] = tx_mac_error[i] ;
        assign tx_mac_error_exp[i*2+1] = 1'b0 ;
    end
endgenerate

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
       .i_mac_error      (tx_mac_error_exp),

        //---csr interface---
       .stat_cnt_clr        (stat_tx_cnt_clr_mac),
		 .stat_lat_sop        (stat_tx_lat_sop),
       .stat_cnt_vld        (stat_tx_cnt_vld),
       .stat_sop_cnt        (stat_tx_sop_cnt),
       .stat_eop_cnt        (stat_tx_eop_cnt),
       .stat_err_cnt        (stat_tx_err_cnt)
);
defparam    stat_counter.CLIENT_IF_TYPE     = CLIENT_IF_TYPE;
defparam    stat_counter.WORDS              = WORDS_MAC; ///check AVST required???
defparam    stat_counter.AVST_ERR_WIDTH     = 1;
defparam    stat_counter.SEG_ERR_WIDTH      = 2*WORDS_MAC;

//---------------------------------------------
endmodule

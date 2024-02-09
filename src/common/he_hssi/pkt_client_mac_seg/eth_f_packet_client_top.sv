// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`timescale 1 ps / 1 ps

module eth_f_packet_client_top #(
        parameter ENABLE_PTP             = 0,
        parameter PKT_CYL                = 0,
        parameter PTP_FP_WIDTH           = 0,
        parameter CLIENT_IF_TYPE         = 0,   // 0:Segmented; 1:AvST;
        parameter READY_LATENCY          = 1,
        parameter WORDS_MAC              = 8,
		  parameter WORDS_AVST             = 8,
		  
        parameter EMPTY_WIDTH            = 6,
        parameter LPBK_FIFO_ADDR_WIDTH   = 6,
        parameter PKT_ROM_INIT_FILE      = "eth_f_hw_pkt_gen_rom_init.hex"
    )(
        input   logic                 i_arst,
        input   logic                 i_clk_tx,
        input   logic                 i_clk_rx,
		  input   logic                 i_clk_pll,
        input   logic                 i_clk_tx_tod,
        input   logic                 i_tx_tod_rst_n,
        input   logic                 i_clk_status,
        input   logic                 i_clk_status_rst,

        //---Segmented TX/RX IF---
        input   logic                 i_tx_mac_ready,
        output  logic                 o_tx_mac_valid,
        output  logic [WORDS_MAC-1:0]     o_tx_mac_inframe,
        output  logic [WORDS_MAC*3-1:0]   o_tx_mac_eop_empty,
        output  logic [WORDS_MAC*64-1:0]  o_tx_mac_data,
        output  logic [WORDS_MAC-1:0]     o_tx_mac_error,
        output  logic [WORDS_MAC-1:0]     o_tx_mac_skip_crc,

        input   logic                 i_rx_mac_valid,
        input   logic [WORDS_MAC-1:0]     i_rx_mac_inframe,
        input   logic [WORDS_MAC*3-1:0]   i_rx_mac_eop_empty,
        input   logic [WORDS_MAC*64-1:0]  i_rx_mac_data,
        input   logic [2*WORDS_MAC-1:0]   i_rx_mac_error,
        input   logic [WORDS_MAC-1:0]     i_rx_mac_fcs_error,
        input   logic [3*WORDS_MAC-1:0]   i_rx_mac_status,

        //---Avst TX/RX IF---
        input   logic                       i_tx_ready,
        output  logic                       o_tx_valid,
        output  logic                       o_tx_sop,
        output  logic                       o_tx_eop,
        output  logic   [EMPTY_WIDTH-1:0]   o_tx_empty,
        output  logic   [WORDS_AVST*64-1:0] 	  o_tx_data,
        output  logic                       o_tx_error,
        output  logic                       o_tx_skip_crc,
        output  logic   [64-1:0]            o_tx_preamble,   // for 40/50G;

        input   logic                       i_rx_valid,
        input   logic                       i_rx_sop,
        input   logic                       i_rx_eop,
        input   logic   [EMPTY_WIDTH-1:0]   i_rx_empty,
        input   logic   [WORDS_AVST*64-1:0] 	  i_rx_data,
        input   logic   [64-1:0]            i_rx_preamble,   // for 40/50G;
        input   logic   [6-1:0]             i_rx_error,
        input   logic                       i_rxstatus_valid,
        input   logic   [40-1:0]            i_rxstatus_data,

        // PTP Command Interface, driving to DUT
        output logic [PKT_CYL*1-1:0]	    o_ptp_ins_ets,
        output logic [PKT_CYL*1-1:0]	    o_ptp_ins_cf,
        output logic [PKT_CYL*1-1:0]	    o_ptp_ins_zero_csum,
        output logic [PKT_CYL*1-1:0]	    o_ptp_ins_update_eb,
        output logic [PKT_CYL*16-1:0]	    o_ptp_ins_ts_offset,
        output logic [PKT_CYL*16-1:0]	    o_ptp_ins_cf_offset,
        output logic [PKT_CYL*16-1:0]	    o_ptp_ins_csum_offset,
        output logic [PKT_CYL*1-1:0]	    o_ptp_p2p,
        output logic [PKT_CYL*1-1:0]	    o_ptp_asym,
        output logic [PKT_CYL*1-1:0]	    o_ptp_asym_sign,
        output logic [PKT_CYL*7-1:0]	    o_ptp_asym_p2p_idx,
        output logic [PKT_CYL*1-1:0]	    o_ptp_ts_req,
        output logic [PKT_CYL*PTP_FP_WIDTH-1:0] o_ptp_fp,
        output logic [PKT_CYL*96 -1:0]      o_ptp_tx_its,

        input logic [PKT_CYL-1:0]           i_tx_ptp_ets_valid,
        input logic [PKT_CYL*96 -1:0]       i_tx_ptp_ets,
        input logic [PKT_CYL*PTP_FP_WIDTH -1:0] i_tx_ptp_ets_fp,
        input logic [PKT_CYL*96 -1:0]       i_rx_ptp_its,

        input logic [95:0]                  i_tx_ptp_tod,
        input logic                         i_tx_ptp_tod_valid,

        // status register bus
        input   logic   [22:0]              i_status_addr,
        input   logic                       i_status_read,
        input   logic                       i_status_write,
        input   logic   [31:0]              i_status_writedata,
        output  logic   [31:0]              o_status_readdata,
        output  logic                       o_status_readdata_valid,
        output  logic                       o_status_waitrequest
);

//localparam DATA_BCNT = WORDS*8;
localparam DATA_BCNT = (CLIENT_IF_TYPE==0) ? (WORDS_MAC*8): (WORDS_AVST*8) ;       //check again for AVST
localparam CTRL_BCNT = (CLIENT_IF_TYPE==0) ? (WORDS_MAC+1) : 2;
localparam PTP_BCNT  = (ENABLE_PTP== 1 & PKT_CYL==2) ? 24 :
                       (ENABLE_PTP== 1 & PKT_CYL==1) ? 12 :
                                                        0;
localparam ROM_ADDR_WIDTH = 10;
localparam ROM_LOOPCOUNT_WIDTH = 32;

logic [PKT_CYL*1-1:0]	ptp_ins_ets_int;
logic [PKT_CYL*1-1:0]	ptp_ins_cf_int;
logic [PKT_CYL*1-1:0]	ptp_ins_zero_csum_int;
logic [PKT_CYL*1-1:0]	ptp_ins_update_eb_int;
logic [PKT_CYL*16-1:0]	ptp_ins_ts_offset_int;
logic [PKT_CYL*16-1:0]	ptp_ins_cf_offset_int;
logic [PKT_CYL*16-1:0]	ptp_ins_csum_offset_int;
logic [PKT_CYL*1-1:0]	ptp_p2p_int;
logic [PKT_CYL*1-1:0]	ptp_asym_int;
logic [PKT_CYL*1-1:0]	ptp_asym_sign_int;
logic [PKT_CYL*7-1:0]	ptp_asym_p2p_idx_int;
logic [PKT_CYL*1-1:0]	ptp_ts_req_int;
logic [PKT_CYL*PTP_FP_WIDTH-1:0]	ptp_fp_int;
logic [PKT_CYL*96 -1:0] ptp_tx_its_int;

logic [31:0]            o_pkt_mon_readdata;
logic                   o_pkt_mon_readdata_valid;
logic                   o_pkt_mon_waitrequest;

logic [31:0]            o_pkt_cli_readdata;
logic                   o_pkt_cli_readdata_valid;
logic                   o_pkt_cli_waitrequest;
//---------------------------------------------------------------
logic                      cfg_tx_select_pkt_gen;
logic                      cfg_pkt_gen_tx_en;
logic                      cfg_pkt_gen_cont_mode;

logic                      tx_reset;

//---------------------------------------------------------------
//---packet generator signals---
logic                      pkt_gen_req;
logic                      pkt_gen_rdata_vld;
logic [DATA_BCNT*8-1:0]    pkt_gen_rdata;
logic [CTRL_BCNT*8-1:0]    pkt_gen_rdata_ctrl;
logic [PTP_BCNT*8-1:0]     pkt_gen_ptp_ctrl;

//---loopback client signals---
logic                      loopback_req;
logic                      loopback_rdata_vld;
logic [DATA_BCNT*8-1:0]    loopback_rdata;
logic [CTRL_BCNT*8-1:0]    loopback_rdata_ctrl;

//---TX MUX signals---
logic                      tx_mux_data_vld;
logic [DATA_BCNT*8-1:0]    tx_mux_data;
logic [CTRL_BCNT*8-1:0]    tx_mux_ctrl;

//---------------------------------------------------------------
logic [15:0]           cfg_pkt_client_ctrl, cfg_pkt_client_ctrl_sync;
logic [ROM_ADDR_WIDTH-1:0] cfg_rom_start_addr;
logic [ROM_ADDR_WIDTH-1:0] cfg_rom_end_addr;
logic [ROM_LOOPCOUNT_WIDTH-1:0] cfg_test_loop_cnt;
logic [7:0]            stat_tx_sop_cnt, stat_tx_eop_cnt, stat_tx_err_cnt;
logic [7:0]            stat_tx_sop_cnt_sync, stat_tx_eop_cnt_sync, stat_tx_err_cnt_sync;
logic [7:0]            stat_rx_sop_cnt, stat_rx_eop_cnt, stat_rx_err_cnt;
logic [7:0]            stat_rx_sop_cnt_sync, stat_rx_eop_cnt_sync, stat_rx_err_cnt_sync;
logic                  stat_tx_cnt_clr, stat_rx_cnt_clr;
logic [1:0]            stat_rx_cnt_clr_sync, stat_tx_cnt_clr_sync;
logic                  loopback_fifo_wr_full_err, loopback_fifo_rd_empty_err;
logic                  loopback_fifo_wr_full_err_sync, loopback_fifo_rd_empty_err_sync;
logic                  stat_tx_lat_sop,stat_rx_lat_sop,stat_lat_cnt_done;
logic						  stat_lat_cnt_done_sync;
logic [7:0]				  stat_lat_cnt;
logic [7:0]				  stat_lat_cnt_sync;
logic 						stat_lat_en;

logic [ROM_ADDR_WIDTH-1:0] cfg_rom_start_addr_sync;
logic [ROM_ADDR_WIDTH-1:0] cfg_rom_end_addr_sync;
logic [ROM_LOOPCOUNT_WIDTH-1:0] cfg_test_loop_cnt_sync;

//---------------------------------------------------------------
assign      o_tx_preamble = 64'hFB55_5555_5555_55D5;

assign o_status_waitrequest = i_status_addr[10] ? o_pkt_mon_waitrequest : o_pkt_cli_waitrequest;
assign o_status_readdata_valid = o_pkt_cli_readdata_valid || o_pkt_mon_readdata_valid;

always @(*) begin
    case (1'b1)
        o_pkt_cli_readdata_valid    : o_status_readdata = o_pkt_cli_readdata;
        o_pkt_mon_readdata_valid    : o_status_readdata = o_pkt_mon_readdata;
        default                     : o_status_readdata = 32'hdeadc0de;
    endcase
end

//---------------------------------------------------------------
//---------------------------------------------------------------
//-----------------TX MAC Ready Latency -----------------
logic [10:0]   tx_rdy_latency;
logic [11:0]  tx_rdy_latency_all;
logic         tx_rdy;
logic         tx_ready_seg, tx_ready_avst;
logic         tx_ready_latency, tx_valid_latency;
logic         tx_valid, tx_mac_valid;

assign tx_rdy = (CLIENT_IF_TYPE==0) ? i_tx_mac_ready : i_tx_ready;
always @(posedge i_clk_tx) tx_rdy_latency <= {tx_rdy_latency[8:0], tx_rdy};
assign tx_rdy_latency_all = {tx_rdy_latency, tx_rdy};
assign tx_ready_latency = (cfg_tx_select_pkt_gen==1 || CLIENT_IF_TYPE==1)? tx_rdy_latency_all[READY_LATENCY] : tx_rdy_latency_all[2];
assign tx_valid_latency = (cfg_tx_select_pkt_gen==1 || CLIENT_IF_TYPE==1)? tx_rdy_latency_all[READY_LATENCY] : tx_rdy_latency_all[2];

assign tx_ready_seg   = (CLIENT_IF_TYPE==0) & tx_ready_latency;
assign o_tx_mac_valid = (CLIENT_IF_TYPE==0) & tx_valid_latency;
assign tx_ready_avst = (CLIENT_IF_TYPE==1) & tx_ready_latency;
assign o_tx_valid    = (CLIENT_IF_TYPE==1) & tx_valid_latency;

//---------------------------------------------------------------
//---------------------------------------------------------------

eth_f_pkt_gen_top pkt_gen_top (
        .clk               (i_clk_tx),
        .rst               (tx_reset),
        .clken             (1'b1),

        //---packet data interface---
        .tx_pkt_req            (pkt_gen_req),
        .tx_pkt_rdata_vld      (pkt_gen_rdata_vld),
        .tx_pkt_rdata          (pkt_gen_rdata),
        .tx_pkt_rdata_ctrl     (pkt_gen_rdata_ctrl),
        .tx_pkt_ptp_ctrl       (pkt_gen_ptp_ctrl),

        //---csr ctrl---
        .cfg_pkt_gen_tx_en     (cfg_pkt_gen_tx_en),
        .cfg_rom_start_addr    (cfg_rom_start_addr_sync),
        .cfg_rom_end_addr      (cfg_rom_end_addr_sync),
        .cfg_test_loop_cnt     (cfg_test_loop_cnt_sync),
	.cfg_pkt_gen_cont_mode     (cfg_pkt_gen_cont_mode)



);
defparam pkt_gen_top.ENABLE_PTP             = ENABLE_PTP;
defparam pkt_gen_top.CLIENT_IF_TYPE         = CLIENT_IF_TYPE;   // 0: Segmented; 1: AVST;
defparam pkt_gen_top.DATA_BCNT              = DATA_BCNT;
defparam pkt_gen_top.CTRL_BCNT              = CTRL_BCNT;
defparam pkt_gen_top.PTP_BCNT               = PTP_BCNT;
//defparam pkt_gen_top.WORDS                  = WORDS;
defparam pkt_gen_top.WORDS_MAC              = WORDS_MAC;
defparam pkt_gen_top.WORDS_AVST             = WORDS_AVST;
defparam pkt_gen_top.ROM_ADDR_WIDTH         = ROM_ADDR_WIDTH;
defparam pkt_gen_top.ROM_LOOPCOUNT_WIDTH    = ROM_LOOPCOUNT_WIDTH;
defparam pkt_gen_top.PKT_ROM_INIT_FILE      = PKT_ROM_INIT_FILE;

//---------------------------------------------------------------
eth_f_loopback_client #(
        .CLIENT_IF_TYPE  (CLIENT_IF_TYPE),
        .EMPTY_WIDTH     (EMPTY_WIDTH),
        //.WORDS           (WORDS),
		  //.WORDS           ((CLIENT_IF_TYPE == 1)? WORDS_MAC : WORDS_AVST),
		  .WORDS_AVST      (WORDS_AVST),
		  .WORDS_MAC        (WORDS_MAC),
        .DATA_BCNT       (DATA_BCNT),
        .CTRL_BCNT       (CTRL_BCNT),
        .FIFO_ADDR_WIDTH (LPBK_FIFO_ADDR_WIDTH),
        .SIM_EMULATE     (0)
    ) loopback_client (
        .i_arst           (i_arst),
        .i_clk_w          (i_clk_rx),
        .i_clk_r          (i_clk_tx),
        //AVST interface
        .i_sop            (i_rx_sop),
        .i_eop            (i_rx_eop),
        .i_valid          (i_rx_valid),
        .i_empty          (i_rx_empty),
        .i_data           (i_rx_data),
        .i_error          (i_rx_error),
        //   .i_preamble       (),
        // MAC segmented interface
        .i_mac_data       (i_rx_mac_data),
        .i_mac_valid      (i_rx_mac_valid),
        .i_mac_inframe    (i_rx_mac_inframe),
        .i_mac_eop_empty  (i_rx_mac_eop_empty),
        .i_mac_error      (i_rx_mac_error),
        //   .i_mac_fcs_error  (i_rx_mac_fcs_error),
        //Packet client tx mux interface
        .i_tx_req         ((CLIENT_IF_TYPE==1)? loopback_req : tx_rdy),
        .o_tx_data_vld    (loopback_rdata_vld),
        .o_tx_data        (loopback_rdata),
        .o_tx_ctrl        (loopback_rdata_ctrl),

        //---csr interface---
        .stat_rx_cnt_clr        (stat_rx_cnt_clr_sync[1]),
		  .stat_rx_lat_sop        (stat_rx_lat_sop),
        .stat_rx_cnt_vld        (stat_rx_cnt_vld),
        .stat_rx_sop_cnt        (stat_rx_sop_cnt),
        .stat_rx_eop_cnt        (stat_rx_eop_cnt),
        .stat_rx_err_cnt        (stat_rx_err_cnt),
        .o_wr_full_err          (loopback_fifo_wr_full_err),
        .o_rd_empty_err         (loopback_fifo_rd_empty_err)
);
defparam loopback_client.INIT_FILE_DATA  = PKT_ROM_INIT_FILE;

//---------------------------------------------------------------
eth_f_packet_client_tx_mux packet_client_tx_mux (
        .i_clk_tx             (i_clk_tx),
        .i_rst                (tx_reset),
        .cfg_m0_select        (cfg_tx_select_pkt_gen),

        //---TX master 0---
        .m0_tx_req            (pkt_gen_req),
        .m0_tx_data_vld       (pkt_gen_rdata_vld),
        .m0_tx_data           (pkt_gen_rdata),
        .m0_tx_ctrl           (pkt_gen_rdata_ctrl),

        //---TX master 1---
        .m1_tx_req            (loopback_req),
        .m1_tx_data_vld       (loopback_rdata_vld),
        .m1_tx_data           (loopback_rdata),
        .m1_tx_ctrl           (loopback_rdata_ctrl),

        //---Ouput bus signals---
        .i_tx_req             (tx_mux_req),
        .o_tx_data_vld        (tx_mux_data_vld),
        .o_tx_data            (tx_mux_data),
        .o_tx_ctrl            (tx_mux_ctrl)
);
defparam packet_client_tx_mux.DATA_BCNT = DATA_BCNT;
defparam packet_client_tx_mux.CTRL_BCNT = CTRL_BCNT;


eth_f_packet_client_tx_interface packet_client_tx_if (
        .clk               (i_clk_tx),
        .rst               (tx_reset),
        .tx_en             ((cfg_tx_select_pkt_gen==1)? cfg_pkt_gen_tx_en : 1'b1),

        .data_req          (tx_mux_req),
        .din_vld           (tx_mux_data_vld),
        .data_bus          (tx_mux_data),
        .ctrl_bus          (tx_mux_ctrl),
        .ptp_bus           (pkt_gen_ptp_ctrl),

        //---Segmented Client Interface---
        .tx_mac_ready      (tx_ready_seg),
        .tx_mac_valid      (tx_mac_valid),
        .tx_mac_inframe    (o_tx_mac_inframe),
        .tx_mac_eop_empty  (o_tx_mac_eop_empty),
        .tx_mac_data       (o_tx_mac_data),
        .tx_mac_error      (o_tx_mac_error),
        .tx_mac_skip_crc   (o_tx_mac_skip_crc),

        //---Avst Client Interface---MAC SOP-Aligned Client interface---
        .tx_ready          (tx_ready_avst),
        .tx_valid          (tx_valid),
        .tx_sop            (o_tx_sop),
        .tx_eop            (o_tx_eop),
        .tx_empty          (o_tx_empty),
        .tx_data           (o_tx_data),
        .tx_error          (o_tx_error),
        .tx_skip_crc       (o_tx_skip_crc),

        .ptp_ins_ets             (ptp_ins_ets_int),
        .ptp_ins_cf              (ptp_ins_cf_int),
        .ptp_ins_zero_csum       (ptp_ins_zero_csum_int),
        .ptp_ins_update_eb       (ptp_ins_update_eb_int),
        .ptp_ins_ts_offset       (ptp_ins_ts_offset_int),
        .ptp_ins_cf_offset       (ptp_ins_cf_offset_int),
        .ptp_ins_csum_offset     (ptp_ins_csum_offset_int),
        .ptp_p2p                 (ptp_p2p_int),
        .ptp_asym                (ptp_asym_int),
        .ptp_asym_sign           (ptp_asym_sign_int),
        .ptp_asym_p2p_idx        (ptp_asym_p2p_idx_int),
        .ptp_ts_req              (ptp_ts_req_int),
        .ptp_fp                  (ptp_fp_int),

        //---csr interface---
        .stat_tx_cnt_clr         (stat_tx_cnt_clr_sync[1]),
		  .stat_tx_lat_sop         (stat_tx_lat_sop),
        .stat_tx_cnt_vld         (stat_tx_cnt_vld),
        .stat_tx_sop_cnt         (stat_tx_sop_cnt),
        .stat_tx_eop_cnt         (stat_tx_eop_cnt),
        .stat_tx_err_cnt         (stat_tx_err_cnt)
);
defparam packet_client_tx_if.ENABLE_PTP        = ENABLE_PTP;
defparam packet_client_tx_if.PKT_CYL           = PKT_CYL;
defparam packet_client_tx_if.PTP_FP_WIDTH      = PTP_FP_WIDTH;
defparam packet_client_tx_if.CLIENT_IF_TYPE    = CLIENT_IF_TYPE;
defparam packet_client_tx_if.DATA_BCNT         = DATA_BCNT;
defparam packet_client_tx_if.CTRL_BCNT         = CTRL_BCNT;
defparam packet_client_tx_if.PTP_BCNT          = PTP_BCNT;
//defparam packet_client_tx_if.WORDS             = WORDS;
defparam packet_client_tx_if.WORDS_MAC             = WORDS_MAC;
defparam packet_client_tx_if.WORDS_AVST             = WORDS_AVST;
defparam packet_client_tx_if.AVST_EMPTY_WIDTH  = EMPTY_WIDTH;

generate if (ENABLE_PTP == 1) begin: PTP_TX_ITS_GEN
logic [47:0] tx_clk_tod_sync;

eth_f_ptp_clock_crosser #(
    .SYMBOLS_PER_BEAT       (1),
    .BITS_PER_SYMBOL        (48),
    .FORWARD_SYNC_DEPTH     (3),
    .BACKWARD_SYNC_DEPTH    (3)
    
) tx_tod_to_tx_clk_crosser (
    .in_clk                 (i_clk_tx_tod),
    .in_reset               (~i_tx_tod_rst_n),
    .in_ready               (/*not-used*/),
    .in_valid               (i_tx_ptp_tod_valid),
    .in_data                (i_tx_ptp_tod[95:48]),  // only sync the seconds field
    .out_clk                (i_clk_tx),
    .out_reset              (tx_reset),
    .out_ready              (1'b1),
    .out_valid              (tx_clk_tod_valid_sync),
    .out_data               (tx_clk_tod_sync)
);

always @(posedge i_clk_tx) begin
    if (tx_reset) begin
        ptp_tx_its_int <= {PKT_CYL{96'h0}};
    end else if (tx_clk_tod_valid_sync) begin
        ptp_tx_its_int <= {PKT_CYL{tx_clk_tod_sync, 48'h0}};
    end
end

end else begin : NO_PTP_TX_ITS_GEN
    assign ptp_tx_its_int = 0;
end
endgenerate

//---------------------------------------------------------------
//latency measurement logic
eth_f_multibit_sync #(
    .WIDTH(9)
) pkt_cli_lat_stat_sync_inst (
    .clk (i_clk_status),
    .reset_n (1'b1),
    .din ({ stat_lat_cnt_done, stat_lat_cnt}),
    .dout ({stat_lat_cnt_done_sync, stat_lat_cnt_sync})
);

 eth_f_latency_measure latency_cnt(

        .i_clk_pll 			(i_clk_pll),
        .i_rst 				(i_arst),
		  .stat_lat_en			(stat_lat_en),//syncronized inside latency_measure module
        .stat_tx_lat_sop	(stat_tx_lat_sop),
        .stat_rx_lat_sop	(stat_rx_lat_sop),
		  .stat_cnt_clr		(stat_tx_cnt_clr),
		  .stat_lat_cnt_done (stat_lat_cnt_done),
        . stat_lat_cnt		(stat_lat_cnt)
);

//---------------------------------------------------------------
// Fix DA CDC 50001
eth_f_multibit_sync #(
    .WIDTH(27)
) lpbk_cli_stat_sync_inst (
    .clk (i_clk_status),
    .reset_n (1'b1),
    .din ({loopback_fifo_rd_empty_err, loopback_fifo_wr_full_err, stat_rx_cnt_vld, stat_rx_sop_cnt, stat_rx_eop_cnt, stat_rx_err_cnt}),
    .dout ({loopback_fifo_rd_empty_err_sync, loopback_fifo_wr_full_err_sync, stat_rx_cnt_vld_sync, stat_rx_sop_cnt_sync, stat_rx_eop_cnt_sync, stat_rx_err_cnt_sync})
);

eth_f_multibit_sync #(
    .WIDTH(25)
) pkt_cli_txif_stat_sync_inst (
    .clk (i_clk_status),
    .reset_n (1'b1),
    .din ({ stat_tx_cnt_vld, stat_tx_sop_cnt, stat_tx_eop_cnt, stat_tx_err_cnt}),
    .dout ({stat_tx_cnt_vld_sync, stat_tx_sop_cnt_sync, stat_tx_eop_cnt_sync, stat_tx_err_cnt_sync})
);


eth_f_packet_client_csr packet_client_csr (
        .i_clk_status            (i_clk_status),
        .i_clk_status_rst        (i_clk_status_rst),

        // status register bus
        .i_status_addr           (i_status_addr),
        .i_status_read           (i_status_read),
        .i_status_write          (i_status_write),
        .i_status_writedata      (i_status_writedata),
        .o_status_readdata       (o_pkt_cli_readdata),
        .o_status_readdata_valid (o_pkt_cli_readdata_valid),
        .o_status_waitrequest    (o_pkt_cli_waitrequest),

        //---csr ctrl---
        .cfg_pkt_client_ctrl     (cfg_pkt_client_ctrl),
        .cfg_rom_start_addr      (cfg_rom_start_addr),
        .cfg_rom_end_addr        (cfg_rom_end_addr),
        .cfg_test_loop_cnt       (cfg_test_loop_cnt),

        //---stat interface---
        .stat_tx_cnt_clr         (stat_tx_cnt_clr),
        .stat_tx_cnt_vld         (stat_tx_cnt_vld_sync),
        .stat_tx_sop_cnt         (stat_tx_sop_cnt_sync),
        .stat_tx_eop_cnt         (stat_tx_eop_cnt_sync),
        .stat_tx_err_cnt         (stat_tx_err_cnt_sync),

        .stat_rx_cnt_clr         (stat_rx_cnt_clr),
        .stat_rx_cnt_vld         (stat_rx_cnt_vld_sync),
        .stat_rx_sop_cnt         (stat_rx_sop_cnt_sync),
        .stat_rx_eop_cnt         (stat_rx_eop_cnt_sync),
        .stat_rx_err_cnt         (stat_rx_err_cnt_sync),
		  
		  .stat_lat_cnt_done			(stat_lat_cnt_done_sync),
		  .stat_lat_cnt            (stat_lat_cnt_sync),
		  .stat_lat_en             (stat_lat_en),
		  
        .i_loopback_fifo_wr_full_err           (loopback_fifo_wr_full_err_sync),
        .i_loopback_fifo_rd_empty_err          (loopback_fifo_rd_empty_err_sync),
		  .stat_cntr_snapshot 	(stat_cntr_snapshot),
		   .stat_cntr_clear 	(stat_cntr_clear)
		  
);
defparam packet_client_csr.CLIENT_IF_TYPE       = CLIENT_IF_TYPE;
defparam packet_client_csr.STATUS_BASE_ADDR     = 16'h0;
defparam packet_client_csr.SIM_EMULATE          = 0;
defparam packet_client_csr.ROM_ADDR_WIDTH       = ROM_ADDR_WIDTH;
defparam packet_client_csr.ROM_LOOPCOUNT_WIDTH  = ROM_LOOPCOUNT_WIDTH;

// sync to TX clock

eth_f_multibit_sync #(
    .WIDTH(ROM_ADDR_WIDTH*2)
) cfg_rom_data_sync_inst (
    .clk (i_clk_tx),
    .reset_n (1'b1),
    .din ({cfg_rom_start_addr, cfg_rom_end_addr}),
    .dout ({cfg_rom_start_addr_sync, cfg_rom_end_addr_sync})
);

eth_f_multibit_sync #(
    .WIDTH(ROM_LOOPCOUNT_WIDTH)
) cfg_rom_loopcount_sync_inst (
    .clk (i_clk_tx),
    .reset_n (1'b1),
    .din (cfg_test_loop_cnt),
    .dout (cfg_test_loop_cnt_sync)
);

//---------------------------------------------------------------
eth_f_multibit_sync #(
    .WIDTH(16)
) cfg_pkt_client_ctrl_sync_inst (
    .clk (i_clk_tx),
    .reset_n (1'b1),
    .din (cfg_pkt_client_ctrl),
    .dout (cfg_pkt_client_ctrl_sync)
);

assign cfg_pkt_gen_tx_en        = cfg_pkt_client_ctrl_sync[0];
assign cfg_pkt_gen_cont_mode =  cfg_pkt_client_ctrl_sync[2];
assign cfg_tx_select_pkt_gen    = !cfg_pkt_client_ctrl_sync[4]; //Loopback Enable bit 
assign stat_cntr_snapshot = cfg_pkt_client_ctrl_sync[6];
assign stat_cntr_clear = cfg_pkt_client_ctrl_sync[7];


//---------------------------------------------------------------
always @ (posedge i_clk_rx) begin
    stat_rx_cnt_clr_sync <= {stat_rx_cnt_clr_sync[0], stat_rx_cnt_clr};
end
always @ (posedge i_clk_tx) begin
    stat_tx_cnt_clr_sync <= {stat_tx_cnt_clr_sync[0], stat_tx_cnt_clr};
end

//---------------------------------------------------------------
eth_f_reset_synchronizer rstx (
        .aclr       (i_arst),
        .clk        (i_clk_tx),
        .aclr_sync  (tx_reset)
);

eth_f_reset_synchronizer rsrx (
        .aclr       (i_arst),
        .clk        (i_clk_rx),
        .aclr_sync  (rx_reset)
);

//---------------------------------------------------------------
generate if (ENABLE_PTP == 1) begin: PTP_MON
eth_f_packet_client_ptp_monitor ptp_monitor (
    .i_arst                 (i_arst),
    .i_clk_tx               (i_clk_tx),
    .i_rst_tx               (tx_reset),
    .i_clk_rx               (i_clk_rx),
    .i_rst_rx               (rx_reset),
    .i_clk_status           (i_clk_status),
    .i_clk_status_rst	    (i_clk_status_rst),

    .i_tx_ready             (tx_ready_avst),
    .i_tx_valid             (tx_valid),
    .i_tx_startofpacket     (o_tx_sop),
    .i_tx_endofpacket       (o_tx_eop),
    .i_tx_data	            (o_tx_data),
    .i_tx_empty	            (o_tx_empty),
    .i_tx_error             (o_tx_error),
    .i_tx_skip_crc          (o_tx_skip_crc),

    .i_rx_valid             (i_rx_valid),
    .i_rx_startofpacket     (i_rx_sop),
    .i_rx_endofpacket       (i_rx_eop),
    .i_rx_data	            (i_rx_data),
    .i_rx_empty             (i_rx_empty),
    .i_rx_error             (i_rx_error),

    .i_tx_mac_ready         (tx_ready_seg),
    .i_tx_mac_valid         (tx_mac_valid),
    .i_tx_mac_inframe       (o_tx_mac_inframe),
    .i_tx_mac_eop_empty     (o_tx_mac_eop_empty),
    .i_tx_mac_data          (o_tx_mac_data),
    .i_tx_mac_error         (o_tx_mac_error),
    .i_tx_mac_skip_crc      (o_tx_mac_skip_crc),

    .i_rx_mac_valid         (i_rx_mac_valid),
    .i_rx_mac_inframe       (i_rx_mac_inframe),
    .i_rx_mac_eop_empty     (i_rx_mac_eop_empty),
    .i_rx_mac_data          (i_rx_mac_data),
    .i_rx_mac_fcs_error     (i_rx_mac_fcs_error),
    .i_rx_mac_error         (i_rx_mac_error),

    .i_ptp_ins_ets          (ptp_ins_ets_int),
    .i_ptp_ins_cf           (ptp_ins_cf_int),
    .i_ptp_ins_zero_csum    (ptp_ins_zero_csum_int),
    .i_ptp_ins_update_eb    (ptp_ins_update_eb_int),
    .i_ptp_ins_ts_offset    (ptp_ins_ts_offset_int),
    .i_ptp_ins_cf_offset    (ptp_ins_cf_offset_int),
    .i_ptp_ins_csum_offset  (ptp_ins_csum_offset_int),
    .i_ptp_p2p              (ptp_p2p_int),
    .i_ptp_asym             (ptp_asym_int),
    .i_ptp_asym_sign        (ptp_asym_sign_int),
    .i_ptp_asym_p2p_idx     (ptp_asym_p2p_idx_int),
    .i_ptp_ts_req           (ptp_ts_req_int),
    .i_ptp_fp	            (ptp_fp_int),
    .i_tx_ptp_rt_its        (ptp_tx_its_int),
    .i_tx_ptp_ets_valid     (i_tx_ptp_ets_valid),
    .i_tx_ptp_ets           (i_tx_ptp_ets),
    .i_tx_ptp_ets_fp        (i_tx_ptp_ets_fp),
    .i_rx_ptp_its           (i_rx_ptp_its),

    .i_status_addr           (i_status_addr),
    .i_status_read           (i_status_read),
    .i_status_write          (i_status_write),
    .i_status_writedata      (i_status_writedata),
    .o_status_readdata       (o_pkt_mon_readdata),
    .o_status_readdata_valid (o_pkt_mon_readdata_valid),
    .o_status_waitrequest    (o_pkt_mon_waitrequest)
);


defparam PTP_MON.ptp_monitor.PKT_CYL         = PKT_CYL;
defparam PTP_MON.ptp_monitor.CLIENT_IF_TYPE  = CLIENT_IF_TYPE;
//defparam PTP_MON.ptp_monitor.WORDS           = WORDS;
defparam PTP_MON.ptp_monitor.WORDS_MAC           = WORDS_MAC;
defparam PTP_MON.ptp_monitor.WORDS_AVST           = WORDS_AVST;
defparam PTP_MON.ptp_monitor.EMPTY_WIDTH     = EMPTY_WIDTH;
defparam PTP_MON.ptp_monitor.BURST_SIZE      = 32;
defparam PTP_MON.ptp_monitor.STATUS_BASE_ADDR   = 16'h0400;
defparam PTP_MON.ptp_monitor.READY_LATENCY      = READY_LATENCY;
defparam PTP_MON.ptp_monitor.PTP_FP_WIDTH       = PTP_FP_WIDTH;
end else begin: PTP_MON_DISABLE
    assign o_pkt_mon_readdata           = 32'h0;
    assign o_pkt_mon_readdata_valid     = 1'b0;
    assign o_pkt_mon_waitrequest        = 1'b0;
end
endgenerate

assign o_ptp_ins_ets          = ptp_ins_ets_int;
assign o_ptp_ins_cf           = ptp_ins_cf_int;
assign o_ptp_ins_zero_csum    = ptp_ins_zero_csum_int;
assign o_ptp_ins_update_eb    = ptp_ins_update_eb_int;
assign o_ptp_ins_ts_offset    = ptp_ins_ts_offset_int;
assign o_ptp_ins_cf_offset    = ptp_ins_cf_offset_int;
assign o_ptp_ins_csum_offset  = ptp_ins_csum_offset_int;
assign o_ptp_p2p              = ptp_p2p_int;
assign o_ptp_asym             = ptp_asym_int;
assign o_ptp_asym_sign        = ptp_asym_sign_int;
assign o_ptp_asym_p2p_idx     = ptp_asym_p2p_idx_int;
assign o_ptp_ts_req           = ptp_ts_req_int;
assign o_ptp_fp               = ptp_fp_int;
assign o_ptp_tx_its           = ptp_tx_its_int;

endmodule


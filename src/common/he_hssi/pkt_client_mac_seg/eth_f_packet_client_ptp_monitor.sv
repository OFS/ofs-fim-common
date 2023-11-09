// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`timescale 1 ps / 1 ps
module eth_f_packet_client_ptp_monitor #(
    parameter PKT_CYL                = 0,
    parameter CLIENT_IF_TYPE         = 0,   // 0:Segmented; 1:AvST;
   // parameter WORDS                  = 8,
	  parameter WORDS_MAC              = 8,
    parameter WORDS_AVST             = 8,
    parameter EMPTY_WIDTH            = 6,
    parameter STATUS_BASE_ADDR       = 16'h0100,
    parameter PTP_FP_WIDTH           = 8,
    parameter BURST_SIZE             = 32,
    parameter PKT_SIZE               = 128,
    parameter READY_LATENCY          = 0
)(
    input logic                         i_arst,
    input logic                         i_clk_tx,
    input logic                         i_rst_tx,
    input logic                         i_clk_rx,
    input logic                         i_rst_rx,
    input logic                         i_clk_status,
    input logic                         i_clk_status_rst,

    //---Avst TX/RX IF---
    input logic                         i_tx_ready,
    input logic                         i_tx_valid,
    input logic                         i_tx_startofpacket,
    input logic                         i_tx_endofpacket,
    input logic [WORDS_AVST*64-1:0]          i_tx_data,
    input logic [EMPTY_WIDTH-1:0]       i_tx_empty,
    input logic                         i_tx_error,
    input logic                         i_tx_skip_crc,

    input logic                         i_rx_valid,
    input logic                         i_rx_startofpacket,
    input logic                         i_rx_endofpacket,
    input logic [WORDS_AVST*64-1:0]          i_rx_data,
    input logic [EMPTY_WIDTH-1:0]       i_rx_empty,
    input logic [5:0]                   i_rx_error,

    //---Segmented TX/RX IF---
    input logic                         i_tx_mac_ready,
    input logic                         i_tx_mac_valid,
    input logic [WORDS_MAC-1:0]             i_tx_mac_inframe,
    input logic [WORDS_MAC*3-1:0]           i_tx_mac_eop_empty,
    input logic [WORDS_MAC*64-1:0]          i_tx_mac_data,
    input logic [WORDS_MAC-1:0]             i_tx_mac_error,
    input logic [WORDS_MAC-1:0]             i_tx_mac_skip_crc,

    input logic                         i_rx_mac_valid,
    input logic [WORDS_MAC-1:0]             i_rx_mac_inframe,
    input logic [WORDS_MAC*3-1:0]           i_rx_mac_eop_empty,
    input logic [WORDS_MAC*64-1:0]          i_rx_mac_data,
    input logic [WORDS_MAC-1:0]             i_rx_mac_fcs_error,
    input logic [2*WORDS_MAC-1:0]           i_rx_mac_error,

    input logic [PKT_CYL*1-1:0]         i_ptp_ins_ets,
    input logic [PKT_CYL*1-1:0]         i_ptp_ins_cf,
    input logic [PKT_CYL*1-1:0]         i_ptp_ins_zero_csum,
    input logic [PKT_CYL*1-1:0]         i_ptp_ins_update_eb,
    input logic [PKT_CYL*16-1:0]        i_ptp_ins_ts_offset,
    input logic [PKT_CYL*16-1:0]        i_ptp_ins_cf_offset,
    input logic [PKT_CYL*16-1:0]        i_ptp_ins_csum_offset,
    input logic [PKT_CYL*1-1:0]         i_ptp_p2p,
    input logic [PKT_CYL*1-1:0]         i_ptp_asym,
    input logic [PKT_CYL*1-1:0]         i_ptp_asym_sign,
    input logic [PKT_CYL*7-1:0]         i_ptp_asym_p2p_idx,
    input logic [PKT_CYL*1-1:0]         i_ptp_ts_req,
    input logic [PKT_CYL*PTP_FP_WIDTH-1:0] i_ptp_fp,

    input logic [PKT_CYL*96 -1:0]       i_tx_ptp_rt_its,
    input logic [PKT_CYL-1:0]           i_tx_ptp_ets_valid,
    input logic [PKT_CYL*96 -1:0]       i_tx_ptp_ets,
    input logic [PKT_CYL*PTP_FP_WIDTH -1:0] i_tx_ptp_ets_fp,
    input logic [PKT_CYL*96 -1:0]       i_rx_ptp_its,

    // status register bus
    input  logic   [22:0]         i_status_addr,
    input  logic                  i_status_read,
    input  logic                  i_status_write,
    input  logic   [31:0]         i_status_writedata,
    output logic   [31:0]         o_status_readdata,
    output logic                  o_status_readdata_valid,
    output logic                  o_status_waitrequest
);

    localparam FIFO_TX_PKT_WIDTH = (CLIENT_IF_TYPE == 0) ? 1+1+1+3+1+1+64 : // segmented, inframe, sop, eop, empty, error, skip crc, data
                                   (CLIENT_IF_TYPE == 1) ? 1+1+EMPTY_WIDTH+1+1+64 : 0;  // AVST, sop, eop, empty, error, skip crc, data

    localparam FIFO_RX_PKT_WIDTH = (CLIENT_IF_TYPE == 0) ? 1+1+1+3+2+1+64 : // segmented, inframe, sop, eop, empty, error, fcs_error, data
                                   (CLIENT_IF_TYPE == 1) ? 1+1+EMPTY_WIDTH+6+64 : 0;  // AVST, sop, eop, empty, error, data

    localparam FIFO_PKT_DEPTH   = (PKT_SIZE*BURST_SIZE)/8;
    localparam FIFO_CMD_DEPTH   = BURST_SIZE;
    localparam FIFO_TS_DEPTH    = BURST_SIZE;

    localparam EMPTY_OUT_WIDTH = (CLIENT_IF_TYPE == 0) ? 3 : EMPTY_WIDTH;

    // deduct inframe, sop, eop, error, skip_crc and empty
    localparam READDATA_TX_PAD = 32 - 5 - EMPTY_OUT_WIDTH;
    // deduct inframe, sop, eop, empty, error, fcs_error
    localparam READDATA_RX_PAD = 32 - 10 - EMPTY_OUT_WIDTH;
    localparam READDATA_FP_PAD = 32 - PTP_FP_WIDTH;
		localparam WORDS = (CLIENT_IF_TYPE  == 0) ? WORDS_MAC :WORDS_AVST;

    localparam CNTR_WIDTH = (WORDS == 16) ? 5 :
                            (WORDS == 8)  ? 4 :     // 0000 --> 0111 --> 1000 --> 0000
                            (WORDS == 4)  ? 3 :     // 000  --> 011  --> 100  --> 000
                            (WORDS == 2)  ? 2 : 1;  // 00   --> 01   --> 10   --> 00

    localparam VALID_BITS = (WORDS == 16) ? 4 :
                            (WORDS == 8)  ? 3 :
                            (WORDS == 4)  ? 2 :
                            (WORDS == 2)  ? 1 : 1;

    logic [WORDS-1:0]                       fifo_full_tx_pkt, fifo_empty_tx_pkt, fifo_rd_tx_pkt;
    logic [WORDS-1:0] [FIFO_TX_PKT_WIDTH-1:0] fifo_rdata_tx_pkt;

    // **** Read data wires start
    // TX PKT FIFO
    logic [WORDS-1:0]                   rd_tx_sop;
    logic [WORDS-1:0]                   rd_tx_eop;
    logic [WORDS-1:0] [EMPTY_OUT_WIDTH-1:0] rd_tx_empty;
    logic [WORDS-1:0] [31:0]            rd_tx_data_63_32;
    logic [WORDS-1:0] [31:0]            rd_tx_data_31_0;
    logic [WORDS-1:0]                   rd_tx_mac_inframe;
    logic [WORDS-1:0]                   rd_tx_error;
    logic [WORDS-1:0]                   rd_tx_skip_crc;

    // RX PKT FIFO
    logic [WORDS-1:0]                   rd_rx_sop;
    logic [WORDS-1:0]                   rd_rx_eop;
    logic [WORDS-1:0] [EMPTY_OUT_WIDTH-1:0] rd_rx_empty;
    logic [WORDS-1:0] [31:0]            rd_rx_data_63_32;
    logic [WORDS-1:0] [31:0]            rd_rx_data_31_0;
    logic [WORDS-1:0]                   rd_rx_mac_inframe;
    logic [WORDS-1:0]                   rd_rx_fcs_err;
    logic [WORDS-1:0] [5:0]             rd_rx_err;

    // PTP CMD FIFO
    logic [95:0]                rd_tx_ptp_rt_its;
    logic                       rd_ptp_ts_req;
    logic                       rd_ptp_ins_ets;
    logic                       rd_ptp_ins_cf;
    logic                       rd_ptp_ins_zero_csum;
    logic                       rd_ptp_ins_update_eb;
    logic                       rd_ptp_p2p;
    logic                       rd_ptp_asym;
    logic                       rd_ptp_asym_sign;
    logic [6:0]                 rd_ptp_asym_p2p_idx;
    logic [15:0]                rd_ptp_ins_ts_offset;
    logic [15:0]                rd_ptp_ins_cf_offset;
    logic [15:0]                rd_ptp_ins_csum_offset;
    logic [PTP_FP_WIDTH-1:0]    rd_ptp_fp;

    // TX TS FIFO
    logic [95:0]                rd_tx_ptp_ets;
    logic [PTP_FP_WIDTH-1:0]    rd_tx_ptp_ets_fp;

    // RX TS FIFO
    logic [95:0]    rd_rx_ptp_its;
    // **** Read data wires end

    logic [WORDS-1:0]                       fifo_full_rx_pkt, fifo_empty_rx_pkt, fifo_rd_rx_pkt;
    logic [WORDS-1:0] [FIFO_RX_PKT_WIDTH-1:0] fifo_rdata_rx_pkt;

    logic                       tx_valid_reg;
    logic                       tx_startofpacket_reg;
    logic                       tx_endofpacket_reg;
    logic [WORDS_AVST*64-1:0]   tx_data_reg;
    logic [EMPTY_WIDTH-1:0]     tx_empty_reg;
    logic                       tx_error_reg;
    logic                       tx_skip_crc_reg;

    logic [WORDS_AVST-1:0]           tx_sop_fifo;
    logic [WORDS_AVST-1:0]           tx_eop_fifo;
    logic [WORDS_AVST-1:0][EMPTY_WIDTH-1:0] tx_empty_fifo;
    logic [WORDS_AVST-1:0]           tx_err_fifo;
    logic [WORDS_AVST-1:0]           rx_sop_fifo;
    logic [WORDS_AVST-1:0]           rx_eop_fifo;
    logic [WORDS_AVST-1:0][EMPTY_WIDTH-1:0] rx_empty_fifo;
    logic [WORDS_AVST-1:0][5:0]      rx_err_fifo;

    logic                       rx_valid_reg;
    logic                       rx_startofpacket_reg;
    logic                       rx_endofpacket_reg;
    logic [WORDS_AVST*64-1:0]   rx_data_reg;
    logic [EMPTY_WIDTH-1:0]     rx_empty_reg;
    logic [5:0]                 rx_error_reg;

    logic                         tx_mac_valid_reg;
    logic [WORDS_MAC-1:0]         tx_mac_inframe_reg;
    logic [WORDS_MAC*3-1:0]       tx_mac_eop_empty_reg;
    logic [WORDS_MAC*64-1:0]      tx_mac_data_reg;
    logic [WORDS_MAC-1:0]         tx_mac_error_reg;
    logic [WORDS_MAC-1:0]         tx_mac_skip_crc_reg;

    logic [WORDS_MAC-1:0]         rx_mac_valid_reg;
    logic [WORDS_MAC-1:0]         rx_mac_inframe_reg;
    logic [WORDS_MAC*3-1:0]       rx_mac_eop_empty_reg;
    logic [WORDS_MAC*64-1:0]      rx_mac_data_reg;
    logic [WORDS_MAC-1:0]         rx_mac_fcs_error_reg;
    logic [WORDS_MAC*2-1:0]       rx_mac_error_reg;

    logic                     tx_inframe_prev;
    logic [WORDS_MAC-1:0]         tx_inframe_sop;
    logic [PKT_CYL*1-1:0]     tx_found_sop;
    logic [WORDS_MAC-1:0]         tx_inframe_eop;
    logic [PKT_CYL*1-1:0]     tx_found_eop;

    logic                     rx_inframe_prev;
    logic [WORDS_MAC-1:0]         rx_inframe_sop;
    logic [PKT_CYL*1-1:0]     rx_found_sop;
    logic [WORDS_MAC-1:0]         rx_inframe_eop;
    logic [PKT_CYL*1-1:0]     rx_found_eop;

    logic [PKT_CYL*1-1:0]     rx_found_sop_r;

    logic                     tx_pkt_fifo_write;
    logic [WORDS_MAC-1:0][FIFO_TX_PKT_WIDTH-1:0] tx_pkt_fifo_write_data;

    logic [WORDS_MAC-1:0]         rx_pkt_fifo_write;
    logic [WORDS_MAC-1:0][FIFO_RX_PKT_WIDTH-1:0] rx_pkt_fifo_write_data;

    // CSR signals
    logic [7:0]   status_addr_r;
    logic [31:0]  status_writedata_r;
    logic         status_addr_sel, status_read, status_write;
    logic         status_addr_sel_r, status_read_r, status_write_r;
    logic         status_read_r2, status_write_r2;
    logic         status_read_p, status_write_p;
    logic         status_waitrequest, status_waitrequest_r;
    logic         soft_rst;

    genvar i, j;
    localparam WORDS_2 = WORDS_MAC/PKT_CYL;    // 1/1=1 2/1=2, 4/1=4, 8/1=8, 16/2=8

    // Segmented data is little endian, declare wires for big endian conversion
    logic [WORDS_MAC-1:0]       tx_mac_inframe_w;
    logic [WORDS_MAC-1:0]       tx_inframe_sop_w;
    logic [WORDS_MAC-1:0]       tx_inframe_eop_w;
    logic [WORDS_MAC-1:0][2:0]  tx_mac_eop_empty_w;
    logic [WORDS_MAC-1:0]       tx_mac_error_w;
    logic [WORDS_MAC-1:0]       tx_mac_skip_crc_w;
    logic [WORDS_MAC-1:0][63:0] tx_mac_data_w;

    logic [WORDS_MAC-1:0]       rx_mac_inframe_w;
    logic [WORDS_MAC-1:0]       rx_inframe_sop_w;
    logic [WORDS_MAC-1:0]       rx_inframe_eop_w;
    logic [WORDS_MAC-1:0][2:0]  rx_mac_eop_empty_w;
    logic [WORDS_MAC-1:0][1:0]  rx_mac_err_w;
    logic [WORDS_MAC-1:0][63:0] rx_mac_data_w;
    logic [WORDS_MAC-1:0]       rx_mac_fcs_error_w;

    //----------------------------------------------------------
    //----------------------------------------------------------
    generate
    if (CLIENT_IF_TYPE == 0) begin: SEG_PKT
        // TX SEGMENTED
        always @ (posedge i_clk_tx) begin
            if (i_rst_tx) begin
                tx_mac_inframe_reg   <= {WORDS_MAC{1'b0}};
                tx_mac_eop_empty_reg <= {WORDS_MAC*3{1'b0}};
                // tx_mac_data_reg      <= {WORDS*64{1'b0}}; // Not resetting data flop to relieve setup timing
                tx_mac_error_reg     <= {WORDS_MAC{1'b0}};
                tx_mac_skip_crc_reg  <= {WORDS_MAC{1'b0}};
            end if (i_tx_mac_valid && i_tx_mac_ready) begin
                tx_mac_inframe_reg   <= i_tx_mac_inframe;
                tx_mac_eop_empty_reg <= i_tx_mac_eop_empty;
                tx_mac_data_reg      <= i_tx_mac_data;
                tx_mac_error_reg     <= i_tx_mac_error;
                tx_mac_skip_crc_reg  <= i_tx_mac_skip_crc;
            end
        end

        always @(posedge i_clk_tx) begin
            if (i_rst_tx) begin
                tx_mac_valid_reg     <= 1'b0;
            end else begin
                tx_mac_valid_reg     <= i_tx_mac_valid & i_tx_mac_ready;
            end
        end

        //----------------------------------------------------------
        // Little Endian to Big Endian Conversion
        for (i=0; i<WORDS_MAC; i++) begin: SEG_TX_INFRAME_CONV_WD
            assign tx_mac_inframe_w[i] = tx_mac_inframe_reg[WORDS_MAC-1-i];
        end

        for (i=0; i<WORDS_MAC; i++) begin: SEG_TX_INFRAME_SOP_CONV_WD
            assign tx_inframe_sop_w[i] = tx_inframe_sop[WORDS_MAC-1-i];
        end

        for (i=0; i<WORDS_MAC; i++) begin: SEG_TX_INFRAME_EOP_CONV_WD
            assign tx_inframe_eop_w[i] = tx_inframe_eop[WORDS_MAC-1-i];
        end

        for (i=0; i<WORDS_MAC; i++) begin: SEG_TX_EMPTY_CONV_WD
            for (j=0; j<3; j++) begin: SEG_TX_EMPTY_CONV_BIT
                assign tx_mac_eop_empty_w[i][j] = tx_mac_eop_empty_reg[(2-j)+(i*3)];
            end
        end

        for (i=0; i<WORDS_MAC; i++) begin: SEG_TX_ERR_CONV_WD
            assign tx_mac_error_w[i] = tx_mac_error_reg[WORDS_MAC-1-i];
        end

        for (i=0; i<WORDS_MAC; i++) begin: SEG_TX_SKIP_CRC_CONV_WD
            assign tx_mac_skip_crc_w[i] = tx_mac_skip_crc_reg[WORDS_MAC-1-i];
        end

        for (i=0; i<WORDS_MAC; i++) begin: SEG_TX_DATA_CONV_WD
            for (j=0; j<8; j++) begin: SEG_TX_DATA_CONV_BYTE
                assign tx_mac_data_w[i][((7-j)+1)*8-1:(7-j)*8] = tx_mac_data_reg[(( (j+1)*8-1)+((WORDS_MAC-1-i)*64)):((j*8)+((WORDS_MAC-1-i)*64))];
            end
        end
        //----------------------------------------------------------

        always @ (posedge i_clk_tx) begin
            if (i_rst_tx) begin
                tx_inframe_prev <= 1'b0;
            end else begin
                tx_inframe_prev <= tx_mac_inframe_reg[WORDS_MAC-1];
            end
        end

        assign tx_inframe_sop[0] = (tx_mac_inframe_reg[0] && !tx_inframe_prev && tx_mac_valid_reg);
        for (i=1; i<WORDS_MAC; i++) begin: SEG_DET_TX_SOP
            assign tx_inframe_sop[i] = (tx_mac_inframe_reg[i] && !tx_mac_inframe_reg[i-1] && tx_mac_valid_reg);
        end

        assign tx_inframe_eop[0] = (!tx_mac_inframe_reg[0] && tx_inframe_prev && tx_mac_valid_reg);
        for (i=1; i<WORDS_MAC; i++) begin: SEG_DET_TX_EOP
            assign tx_inframe_eop[i] = (!tx_mac_inframe_reg[i] && tx_mac_inframe_reg[i-1] && tx_mac_valid_reg);
        end

        //RX SEGMENTED
        always @ (posedge i_clk_rx) begin
            if (i_rst_rx) begin
                rx_mac_inframe_reg   <= {WORDS_MAC{1'b0}};
                rx_mac_eop_empty_reg <= {WORDS_MAC*3{1'b0}};
                // rx_mac_data_reg      <= {WORDS_MAC*64{1'b0}}; // Not resetting data flop to relieve setup timing
                rx_mac_fcs_error_reg <= {WORDS_MAC{1'b0}};
                rx_mac_error_reg     <= {WORDS_MAC*2{1'b0}};
                rx_mac_valid_reg    <= {WORDS_MAC{1'b0}};
            // end else if (i_rx_mac_valid) begin
            end
            else begin
                rx_mac_inframe_reg   <= i_rx_mac_inframe;
                rx_mac_eop_empty_reg <= i_rx_mac_eop_empty;
                rx_mac_data_reg      <= i_rx_mac_data;
                rx_mac_fcs_error_reg <= i_rx_mac_fcs_error;
                rx_mac_error_reg     <= i_rx_mac_error;
                rx_mac_valid_reg    <= {WORDS_MAC{i_rx_mac_valid}};
            end
        end

        //----------------------------------------------------------
        // Little Endian to Big Endian Conversion

        for (i=0; i<WORDS_MAC; i++) begin: SEG_RX_INFRAME_CONV_WD
            assign rx_mac_inframe_w[i] = rx_mac_inframe_reg[WORDS_MAC-1-i];
        end

        for (i=0; i<WORDS_MAC; i++) begin: SEG_RX_INFRAME_SOP_CONV_WD
            assign rx_inframe_sop_w[i] = rx_inframe_sop[WORDS_MAC-1-i];
        end

        for (i=0; i<WORDS_MAC; i++) begin: SEG_RX_INFRAME_EOP_CONV_WD
            assign rx_inframe_eop_w[i] = rx_inframe_eop[WORDS_MAC-1-i];
        end

        for (i=0; i<WORDS_MAC; i++) begin: SEG_RX_EMPTY_CONV_WD
            for (j=0; j<3; j++) begin: SEG_RX_EMPTY_CONV_BIT
                assign rx_mac_eop_empty_w[i][j] = rx_mac_eop_empty_reg[(2-j)+(i*3)];
            end
        end

        for (i=0; i<WORDS_MAC; i++) begin: SEG_RX_ERR_CONV_WD
            for (j=0; j<2; j++) begin: SEG_RX_ERR_CONV_BIT
                assign rx_mac_err_w[i][j] = rx_mac_error_reg[(1-j)+(i*2)];
            end
        end

        for (i=0; i<WORDS_MAC; i++) begin: SEG_RX_FCS_ERR_CONV_WD
            assign rx_mac_fcs_error_w[i] = rx_mac_fcs_error_reg[WORDS_MAC-1-i];
        end

        for (i=0; i<WORDS_MAC; i++) begin: SEG_RX_DATA_CONV_WD
            for (j=0; j<8; j++) begin: SEG_RX_DATA_CONV_BYTE
                assign rx_mac_data_w[i][((7-j)+1)*8-1:(7-j)*8] = rx_mac_data_reg[(( (j+1)*8-1)+((WORDS_MAC-1-i)*64)):((j*8)+((WORDS_MAC-1-i)*64))];
            end
        end

        //----------------------------------------------------------

        always @ (posedge i_clk_rx) begin
            if (i_rst_rx) begin
                rx_inframe_prev <= 1'b0;
            end else if (rx_mac_valid_reg[0]) begin
                rx_inframe_prev <= rx_mac_inframe_reg[WORDS_MAC-1];
            end
        end

        assign rx_inframe_sop[0] = (rx_mac_inframe_reg[0] && !rx_inframe_prev && rx_mac_valid_reg[0]);
        for (i=1; i<WORDS_MAC; i++) begin: SEG_DET_RX_SOP
            assign rx_inframe_sop[i] = (rx_mac_inframe_reg[i] && !rx_mac_inframe_reg[i-1] && rx_mac_valid_reg[i]);
        end

        assign rx_inframe_eop[0] = (!rx_mac_inframe_reg[0] && rx_inframe_prev && rx_mac_valid_reg[0]);
        for (i=1; i<WORDS_MAC; i++) begin: SEG_DET_RX_EOP
            assign rx_inframe_eop[i] = (!rx_mac_inframe_reg[i] && rx_mac_inframe_reg[i-1] && rx_mac_valid_reg[i]);
        end

        for (i=0; i<WORDS_MAC; i++) begin: SEG_PKT_FIFO
            // TX
            always @ (posedge i_clk_tx) begin
                tx_pkt_fifo_write         <= tx_mac_valid_reg && (|tx_mac_inframe_reg || |tx_inframe_eop);
                tx_pkt_fifo_write_data[i] <= {tx_mac_inframe_w[i], tx_inframe_sop_w[i], tx_inframe_eop_w[i], tx_mac_eop_empty_w[i], tx_mac_error_w[i], tx_mac_skip_crc_w[i], tx_mac_data_w[i]};
            end

            eth_f_hw_dual_clock_fifo #(
                .WIDTH  (FIFO_TX_PKT_WIDTH),
                .DEPTH  (FIFO_PKT_DEPTH)
            ) tx_pkt_fifo (
                .areset        (i_rst_tx),
                .write_clk     (i_clk_tx),
                .write         (tx_pkt_fifo_write),
                .write_data    (tx_pkt_fifo_write_data[i]),

                .read_clk      (i_clk_status),
                .read          (fifo_rd_tx_pkt[i]),
                .read_data     (fifo_rdata_tx_pkt[i]),

                .full          (fifo_full_tx_pkt[i]),
                .empty         (fifo_empty_tx_pkt[i])
            );

            assign rd_tx_mac_inframe[i] = fifo_rdata_tx_pkt[i][FIFO_TX_PKT_WIDTH-1];
            assign rd_tx_sop[i]         = fifo_rdata_tx_pkt[i][FIFO_TX_PKT_WIDTH-2];
            assign rd_tx_eop[i]         = fifo_rdata_tx_pkt[i][FIFO_TX_PKT_WIDTH-3];
            assign rd_tx_empty[i]       = fifo_rdata_tx_pkt[i][68:66];  // empty of 3 bits per lane
            assign rd_tx_error[i]       = fifo_rdata_tx_pkt[i][65];
            assign rd_tx_skip_crc[i]    = fifo_rdata_tx_pkt[i][64];
            assign rd_tx_data_63_32[i]  = fifo_rdata_tx_pkt[i][63:32];
            assign rd_tx_data_31_0[i]   = fifo_rdata_tx_pkt[i][31:0];

            // RX
            always @ (posedge i_clk_rx) begin
                rx_pkt_fifo_write[i]      <= rx_mac_valid_reg[i] && (|rx_mac_inframe_reg || |rx_inframe_eop);
                rx_pkt_fifo_write_data[i] <= {rx_mac_inframe_w[i], rx_inframe_sop_w[i], rx_inframe_eop_w[i], rx_mac_eop_empty_w[i], rx_mac_err_w[i], rx_mac_fcs_error_w[i], rx_mac_data_w[i]};
            end

            eth_f_hw_dual_clock_fifo #(
                .WIDTH  (FIFO_RX_PKT_WIDTH),
                .DEPTH  (FIFO_PKT_DEPTH)
            ) rx_pkt_fifo (
                .areset        (i_rst_rx),
                .write_clk     (i_clk_rx),
                .write         (rx_pkt_fifo_write[i]),
                .write_data    (rx_pkt_fifo_write_data[i]),

                .read_clk      (i_clk_status),
                .read          (fifo_rd_rx_pkt[i]),
                .read_data     (fifo_rdata_rx_pkt[i]),

                .full          (fifo_full_rx_pkt[i]),
                .empty         (fifo_empty_rx_pkt[i])
            );

            // Split the readdata into its components
            assign rd_rx_mac_inframe[i] = fifo_rdata_rx_pkt[i][FIFO_RX_PKT_WIDTH-1];
            assign rd_rx_sop[i]         = fifo_rdata_rx_pkt[i][FIFO_RX_PKT_WIDTH-2];
            assign rd_rx_eop[i]         = fifo_rdata_rx_pkt[i][FIFO_RX_PKT_WIDTH-3];
            assign rd_rx_empty[i]       = fifo_rdata_rx_pkt[i][68:66];  // segmented empty is 3 bits wide
            assign rd_rx_err[i]         = {4'h0, fifo_rdata_rx_pkt[i][66:65]};  // segmented error is 2 bits wide
            assign rd_rx_fcs_err[i]     = fifo_rdata_rx_pkt[i][64];
            assign rd_rx_data_63_32[i]  = fifo_rdata_rx_pkt[i][63:32];
            assign rd_rx_data_31_0[i]   = fifo_rdata_rx_pkt[i][31:0];
        end
    end
    //----------------------------------------------------------
    else if (CLIENT_IF_TYPE == 1) begin: AVST_PKT
        // TX
        always @ (posedge i_clk_tx) begin
            if (i_rst_tx) begin
                tx_valid_reg          <= 1'b0;
                tx_startofpacket_reg  <= 1'b0;
                tx_endofpacket_reg    <= 1'b0;
                tx_data_reg           <= {WORDS_AVST*64{1'b0}};
                tx_empty_reg          <= {EMPTY_WIDTH{1'b0}};
                tx_error_reg          <= 1'b0;
                tx_skip_crc_reg       <= 1'b0;
            end else begin
                tx_valid_reg          <= (READY_LATENCY == 0) ? i_tx_valid & i_tx_ready : i_tx_valid;
                tx_startofpacket_reg  <= i_tx_startofpacket;
                tx_endofpacket_reg    <= i_tx_endofpacket;
                tx_data_reg           <= i_tx_data;
                tx_empty_reg          <= i_tx_empty;
                tx_error_reg          <= i_tx_error;
                tx_skip_crc_reg       <= i_tx_skip_crc;
            end
        end

        // RX
        always @ (posedge i_clk_rx) begin
            if (i_rst_rx) begin
                rx_valid_reg          <= 1'b0;
                rx_startofpacket_reg  <= 1'b0;
                rx_endofpacket_reg    <= 1'b0;
                rx_data_reg           <= {WORDS_AVST*64{1'b0}};
                rx_empty_reg          <= {EMPTY_WIDTH{1'b0}};
                rx_error_reg          <= 6'h0;
            end else begin
                rx_valid_reg          <= i_rx_valid;
                rx_startofpacket_reg  <= i_rx_startofpacket;
                rx_endofpacket_reg    <= i_rx_endofpacket;
                rx_data_reg           <= i_rx_data;
                rx_empty_reg          <= i_rx_empty;
                rx_error_reg          <= i_rx_error;
            end
        end

        for (i=0; i<WORDS_AVST; i++) begin: AVST_PKT_FIFO
            // TX AVST
            assign tx_sop_fifo[i]   = (i == WORDS_AVST-1) ? tx_startofpacket_reg : 1'b0;
            assign tx_eop_fifo[i]   = (i == 0) ? tx_endofpacket_reg : 1'b0;
            assign tx_empty_fifo[i] = (i == 0) ? tx_empty_reg : {EMPTY_WIDTH{1'b0}};
            assign tx_err_fifo[i]   = (i == 0) ? tx_error_reg : 1'b0;
            eth_f_hw_dual_clock_fifo #(
                .WIDTH  (FIFO_TX_PKT_WIDTH),
                .DEPTH  (FIFO_PKT_DEPTH)
            ) tx_pkt_fifo (
                .areset        (i_rst_tx),
                .write_clk     (i_clk_tx),
                .write         (tx_valid_reg),
                .write_data    ({tx_sop_fifo[i], tx_eop_fifo[i], tx_empty_fifo[i], tx_err_fifo[i], tx_skip_crc_reg, tx_data_reg[(i*64)+:64]}),

                .read_clk      (i_clk_status),
                .read          (fifo_rd_tx_pkt[i]),
                .read_data     (fifo_rdata_tx_pkt[i]),

                .full          (fifo_full_tx_pkt[i]),
                .empty         (fifo_empty_tx_pkt[i])
            );

            // Split the readdata into its components - data is big endian
            assign rd_tx_sop[i]         = fifo_rdata_tx_pkt[i][FIFO_TX_PKT_WIDTH-1];
            assign rd_tx_eop[i]         = fifo_rdata_tx_pkt[i][FIFO_TX_PKT_WIDTH-2];
            assign rd_tx_empty[i]       = fifo_rdata_tx_pkt[i][66+:EMPTY_OUT_WIDTH];
            assign rd_tx_error[i]       = fifo_rdata_tx_pkt[i][65];
            assign rd_tx_skip_crc[i]    = fifo_rdata_tx_pkt[i][64];
            assign rd_tx_data_63_32[i]  = fifo_rdata_tx_pkt[i][63:32];
            assign rd_tx_data_31_0[i]   = fifo_rdata_tx_pkt[i][31:0];
            // segmented inframe signal not used
            assign rd_tx_mac_inframe[i] = 1'b0;

            // RX AVST
            assign rx_sop_fifo[i]   = (i == WORDS_AVST-1) ? rx_startofpacket_reg : 1'b0;
            assign rx_eop_fifo[i]   = (i == 0) ? rx_endofpacket_reg : 1'b0;
            assign rx_empty_fifo[i] = (i == 0) ? rx_empty_reg : {EMPTY_WIDTH{1'b0}};
            assign rx_err_fifo[i]   = (i == 0) ? rx_error_reg : 6'h0;
            eth_f_hw_dual_clock_fifo #(
                .WIDTH  (FIFO_RX_PKT_WIDTH),
                .DEPTH  (FIFO_PKT_DEPTH)
            ) rx_pkt_fifo (
                .areset        (i_rst_rx),
                .write_clk     (i_clk_rx),
                .write         (rx_valid_reg),
                .write_data    ({rx_sop_fifo[i], rx_eop_fifo[i], rx_empty_fifo[i], rx_err_fifo[i], rx_data_reg[(i*64)+:64]}),

                .read_clk      (i_clk_status),
                .read          (fifo_rd_rx_pkt[i]),
                .read_data     (fifo_rdata_rx_pkt[i]),

                .full          (fifo_full_rx_pkt[i]),
                .empty         (fifo_empty_rx_pkt[i])
            );

            // Split the readdata into its components
            assign rd_rx_sop[i]         = fifo_rdata_rx_pkt[i][FIFO_RX_PKT_WIDTH-1];
            assign rd_rx_eop[i]         = fifo_rdata_rx_pkt[i][FIFO_RX_PKT_WIDTH-2];
            assign rd_rx_empty[i]       = fifo_rdata_rx_pkt[i][70+:EMPTY_OUT_WIDTH];
            assign rd_rx_err[i]         = fifo_rdata_rx_pkt[i][69:64];
            assign rd_rx_data_63_32[i]  = fifo_rdata_rx_pkt[i][63:32];
            assign rd_rx_data_31_0[i]   = fifo_rdata_rx_pkt[i][31:0];
            // segmented signals not used
            assign rd_rx_mac_inframe[i] = 1'b0;
            assign rd_rx_fcs_err[i]     = 1'b0;
        end


    end
    endgenerate

    //----------------------------------------------------------
    //----------------------------------------------------------
    localparam PTP_CMD_WIDTH = 159 + PTP_FP_WIDTH;

    logic [1:0]                tx_found_sop_reg2;

    logic [PKT_CYL*1-1:0]       ptp_ins_ets_reg;
    logic [PKT_CYL*1-1:0]       ptp_ins_cf_reg;
    logic [PKT_CYL*1-1:0]       ptp_ins_zero_csum_reg;
    logic [PKT_CYL*1-1:0]       ptp_ins_update_eb_reg;
    logic [PKT_CYL*16-1:0]      ptp_ins_ts_offset_reg;
    logic [PKT_CYL*16-1:0]      ptp_ins_cf_offset_reg;
    logic [PKT_CYL*16-1:0]      ptp_ins_csum_offset_reg;
    logic [PKT_CYL*1-1:0]       ptp_p2p_reg;
    logic [PKT_CYL*1-1:0]       ptp_asym_reg;
    logic [PKT_CYL*1-1:0]       ptp_asym_sign_reg;
    logic [PKT_CYL*7-1:0]       ptp_asym_p2p_idx_reg;
    logic [PKT_CYL*1-1:0]       ptp_ts_req_reg;
    logic [PKT_CYL*PTP_FP_WIDTH-1:0]      ptp_fp_reg;
    logic [PKT_CYL*96 -1:0]    tx_ptp_rt_its_reg;

    logic fifo_full_tx_ptp_cmd, fifo_empty_tx_ptp_cmd;
    logic fifo_wr_tx_ptp_cmd, fifo_rd_tx_ptp_cmd;

    logic [PTP_CMD_WIDTH-1:0] fifo_rdata_tx_ptp_cmd;
    logic [PTP_CMD_WIDTH-1:0] fifo_wdata_tx_ptp_cmd_l;
    logic [PTP_CMD_WIDTH-1:0] fifo_wdata_tx_ptp_cmd_h;
    logic [PTP_CMD_WIDTH-1:0] fifo_wdata_tx_ptp_cmd;

    always @ (posedge i_clk_tx) begin
        ptp_ins_ets_reg          <= i_ptp_ins_ets;
        ptp_ins_cf_reg           <= i_ptp_ins_cf;
        ptp_ins_zero_csum_reg    <= i_ptp_ins_zero_csum;
        ptp_ins_update_eb_reg    <= i_ptp_ins_update_eb;
        ptp_ins_ts_offset_reg    <= i_ptp_ins_ts_offset;
        ptp_ins_cf_offset_reg    <= i_ptp_ins_cf_offset;
        ptp_ins_csum_offset_reg  <= i_ptp_ins_csum_offset;
        ptp_p2p_reg              <= i_ptp_p2p;
        ptp_asym_reg             <= i_ptp_asym;
        ptp_asym_sign_reg        <= i_ptp_asym_sign;
        ptp_asym_p2p_idx_reg     <= i_ptp_asym_p2p_idx;
        ptp_ts_req_reg           <= i_ptp_ts_req;
        ptp_fp_reg               <= i_ptp_fp;
        tx_ptp_rt_its_reg        <= i_tx_ptp_rt_its;
    end

    generate
    if (CLIENT_IF_TYPE == 0 && PKT_CYL == 2) begin: DET_SOP_SEG_2CYL
        for (j=0; j<PKT_CYL; j++) begin: CYL2_FOUND_SOP
            always @ (posedge i_clk_tx) begin
                tx_found_sop[j] <= |tx_inframe_sop[(j+1)*WORDS_2-1 -:WORDS_2];
            end
        end

        always @ (posedge i_clk_tx) begin
            tx_found_sop_reg2 <= tx_found_sop;

            fifo_wdata_tx_ptp_cmd_l <= {
                tx_ptp_rt_its_reg[95:0],
                ptp_ins_update_eb_reg[0],
                ptp_ins_ts_offset_reg[15:0],
                ptp_ins_cf_offset_reg[15:0],
                ptp_ins_csum_offset_reg[15:0],
                ptp_p2p_reg[0],
                ptp_asym_reg[0],
                ptp_asym_sign_reg[0],
                ptp_asym_p2p_idx_reg[6:0],
                ptp_fp_reg[0+:PTP_FP_WIDTH],
                ptp_ins_ets_reg[0],
                ptp_ins_cf_reg[0],
                ptp_ins_zero_csum_reg[0],
                ptp_ts_req_reg[0]
            };

            fifo_wdata_tx_ptp_cmd_h <= {
                tx_ptp_rt_its_reg[191:96],
                ptp_ins_update_eb_reg[1],
                ptp_ins_ts_offset_reg[31:16],
                ptp_ins_cf_offset_reg[31:16],
                ptp_ins_csum_offset_reg[31:16],
                ptp_p2p_reg[1],
                ptp_asym_reg[1],
                ptp_asym_sign_reg[1],
                ptp_asym_p2p_idx_reg[13:7],
                ptp_fp_reg[PTP_FP_WIDTH+:PTP_FP_WIDTH],
                ptp_ins_ets_reg[1],
                ptp_ins_cf_reg[1],
                ptp_ins_zero_csum_reg[1],
                ptp_ts_req_reg[1]
            };

            if (tx_found_sop == 2'b10) begin
                fifo_wdata_tx_ptp_cmd <= fifo_wdata_tx_ptp_cmd_h;
            end
            else if (tx_found_sop == 2'b01) begin
                fifo_wdata_tx_ptp_cmd <= fifo_wdata_tx_ptp_cmd_l;
            end
        end

        assign fifo_wr_tx_ptp_cmd = |tx_found_sop_reg2;

    end
    //----------------------------------------------------------
    else if (CLIENT_IF_TYPE == 0 && PKT_CYL == 1) begin: DET_SOP_SEG
        for (j=0; j<PKT_CYL; j++) begin:  CYL1_FOUND_SOP
            assign tx_found_sop[j] = |tx_inframe_sop[(j+1)*WORDS_2-1 -:WORDS_2];
        end

        assign fifo_wdata_tx_ptp_cmd = {
            tx_ptp_rt_its_reg,
            ptp_ins_update_eb_reg,
            ptp_ins_ts_offset_reg,
            ptp_ins_cf_offset_reg,
            ptp_ins_csum_offset_reg,
            ptp_p2p_reg,
            ptp_asym_reg,
            ptp_asym_sign_reg,
            ptp_asym_p2p_idx_reg,
            ptp_fp_reg,
            ptp_ins_ets_reg,
            ptp_ins_cf_reg,
            ptp_ins_zero_csum_reg,
            ptp_ts_req_reg
        };

        assign fifo_wr_tx_ptp_cmd = tx_found_sop;

    end
    //----------------------------------------------------------
    else if (CLIENT_IF_TYPE == 1 && PKT_CYL == 1) begin: DET_SOP_AVST
        for (j=0; j<PKT_CYL; j++) begin: AVST_FOUND_SOP
            assign tx_found_sop[j] = tx_startofpacket_reg && tx_valid_reg;
        end

            assign fifo_wdata_tx_ptp_cmd = {
                tx_ptp_rt_its_reg,
                ptp_ins_update_eb_reg,
                ptp_ins_ts_offset_reg,
                ptp_ins_cf_offset_reg,
                ptp_ins_csum_offset_reg,
                ptp_p2p_reg,
                ptp_asym_reg,
                ptp_asym_sign_reg,
                ptp_asym_p2p_idx_reg,
                ptp_fp_reg,
                ptp_ins_ets_reg,
                ptp_ins_cf_reg,
                ptp_ins_zero_csum_reg,
                ptp_ts_req_reg
            };

        assign fifo_wr_tx_ptp_cmd = tx_found_sop;

    end
    endgenerate

    eth_f_hw_dual_clock_fifo #(
        .WIDTH  (PTP_CMD_WIDTH),
        .DEPTH  (FIFO_CMD_DEPTH)
    ) tx_ptp_cmd_fifo (
        .areset        (i_rst_tx),
        .write_clk     (i_clk_tx),
        .write         (fifo_wr_tx_ptp_cmd),
        .write_data    (fifo_wdata_tx_ptp_cmd),

        .read_clk      (i_clk_status),
        .read          (fifo_rd_tx_ptp_cmd),
        .read_data     (fifo_rdata_tx_ptp_cmd),

        .full          (fifo_full_tx_ptp_cmd),
        .empty         (fifo_empty_tx_ptp_cmd)
    );

    // split the readdata into its components
    assign {rd_tx_ptp_rt_its,
            rd_ptp_ins_update_eb,
            rd_ptp_ins_ts_offset,
            rd_ptp_ins_cf_offset,
            rd_ptp_ins_csum_offset,
            rd_ptp_p2p,
            rd_ptp_asym,
            rd_ptp_asym_sign,
            rd_ptp_asym_p2p_idx,
            rd_ptp_fp,
            rd_ptp_ins_ets,
            rd_ptp_ins_cf,
            rd_ptp_ins_zero_csum,
            rd_ptp_ts_req} = fifo_rdata_tx_ptp_cmd;
    //----------------------------------------------------------
    //----------------------------------------------------------
    localparam                          PTP_TX_ETS_TS_WIDTH = 96 + PTP_FP_WIDTH;

    logic [PKT_CYL-1:0]                 tx_ptp_ets_valid_reg;
    logic [PKT_CYL*96 -1:0]             tx_ptp_ets_reg;
    logic [PKT_CYL*PTP_FP_WIDTH -1:0]   tx_ptp_ets_fp_reg;

    logic [1:0]                         tx_ptp_ets_valid_reg2;

    logic                               fifo_full_tx_ts, fifo_empty_tx_ts;
    logic                               fifo_wr_tx_ts, fifo_rd_tx_ts;

    logic [PTP_TX_ETS_TS_WIDTH-1:0]     fifo_rdata_tx_ts;
    logic [PTP_TX_ETS_TS_WIDTH-1:0]     fifo_wdata_tx_ts;

    always @ (posedge i_clk_tx) begin
        if (i_rst_tx) begin
            tx_ptp_ets_valid_reg  <= {PKT_CYL{1'b0}};
            tx_ptp_ets_reg        <= {PKT_CYL*96{1'b0}};
            tx_ptp_ets_fp_reg     <= {PKT_CYL*PTP_FP_WIDTH{1'b0}};
        end else begin
            tx_ptp_ets_valid_reg  <= i_tx_ptp_ets_valid;
            tx_ptp_ets_reg        <= i_tx_ptp_ets;
            tx_ptp_ets_fp_reg     <= i_tx_ptp_ets_fp;
        end
    end

    generate
    //----------------------------------------------------------
    if (CLIENT_IF_TYPE == 0 && PKT_CYL == 2) begin: TX_TS_SEG_2CYL
        always @ (posedge i_clk_tx) begin
            if (i_rst_tx) begin
                tx_ptp_ets_valid_reg2   <= 2'b0;
                fifo_wdata_tx_ts        <= {PTP_TX_ETS_TS_WIDTH{1'b0}};
            end else begin
                tx_ptp_ets_valid_reg2 <= tx_ptp_ets_valid_reg;

                if (tx_ptp_ets_valid_reg == 2'b10)
                    fifo_wdata_tx_ts <= {tx_ptp_ets_fp_reg[15:8], tx_ptp_ets_reg[191:96]};
                else if (tx_ptp_ets_valid_reg == 2'b01)
                    fifo_wdata_tx_ts <= {tx_ptp_ets_fp_reg[7:0], tx_ptp_ets_reg[95:0]};
            end
        end

        assign fifo_wr_tx_ts = |tx_ptp_ets_valid_reg2;

    //----------------------------------------------------------
    end else begin: TX_TS

        assign fifo_wr_tx_ts    = tx_ptp_ets_valid_reg;
        assign fifo_wdata_tx_ts = {tx_ptp_ets_fp_reg, tx_ptp_ets_reg};

    end
    endgenerate

    eth_f_hw_dual_clock_fifo #(
        .WIDTH  (PTP_TX_ETS_TS_WIDTH),
        .DEPTH  (FIFO_TS_DEPTH)
    ) tx_ts_fifo (
        .areset        (i_rst_tx),
        .write_clk     (i_clk_tx),
        .write         (fifo_wr_tx_ts),
        .write_data    (fifo_wdata_tx_ts),

        .read_clk      (i_clk_status),
        .read          (fifo_rd_tx_ts),
        .read_data     (fifo_rdata_tx_ts),

        .full          (fifo_full_tx_ts),
        .empty         (fifo_empty_tx_ts)
    );

    // split the readdata into its components
    assign rd_tx_ptp_ets_fp = fifo_rdata_tx_ts[96+:PTP_FP_WIDTH];
    assign rd_tx_ptp_ets    = fifo_rdata_tx_ts[95:0];

    //----------------------------------------------------------
    //----------------------------------------------------------
    // RX TS
    localparam                          PTP_RX_ITS_TS_WIDTH = 96;
    logic [PKT_CYL*96 -1:0]             rx_ptp_its_reg;

    logic                               fifo_full_rx_ts, fifo_empty_rx_ts;
    logic                               fifo_wr_rx_ts, fifo_rd_rx_ts;

    logic [PTP_RX_ITS_TS_WIDTH-1:0]     fifo_rdata_rx_ts;
    logic [PTP_RX_ITS_TS_WIDTH-1:0]     fifo_wdata_rx_ts_l;
    logic [PTP_RX_ITS_TS_WIDTH-1:0]     fifo_wdata_rx_ts_h;
    logic [PTP_RX_ITS_TS_WIDTH-1:0]     fifo_wdata_rx_ts;

    always @(posedge i_clk_rx) begin
        if (i_rst_rx) begin
            rx_ptp_its_reg <= {PKT_CYL*96{1'b0}};
        end else begin
            rx_ptp_its_reg <= i_rx_ptp_its;
        end
    end
    generate
    //----------------------------------------------------------
    if (CLIENT_IF_TYPE == 0 && PKT_CYL == 2) begin: RX_TS_SEG_2CYL
        for (j=0; j<PKT_CYL; j++) begin: RX_TS_FIND_RX_SOP
            always @ (posedge i_clk_tx) begin
                rx_found_sop[j] <= |rx_inframe_sop[(j+1)*WORDS_2-1 -:WORDS_2];
            end
        end

        always @ (posedge i_clk_tx) begin
            if (i_rst_tx) begin
                rx_found_sop_r      <= {PKT_CYL{1'b0}};
                fifo_wdata_rx_ts    <= {PTP_RX_ITS_TS_WIDTH{1'b0}};
            end else begin
                rx_found_sop_r      <= rx_found_sop;
                fifo_wdata_rx_ts_l  <= rx_ptp_its_reg[95:0];
                fifo_wdata_rx_ts_h  <= rx_ptp_its_reg[191:96];

                if ( rx_found_sop == 2'b10)
                    fifo_wdata_rx_ts <= fifo_wdata_rx_ts_h;
                else if ( rx_found_sop == 2'b01)
                    fifo_wdata_rx_ts <= fifo_wdata_rx_ts_l;
            end
        end

        assign fifo_wr_rx_ts = |rx_found_sop_r;

    //----------------------------------------------------------
    end else if (CLIENT_IF_TYPE == 0 && PKT_CYL == 1) begin: RX_TS_SEG
        for (j=0; j<PKT_CYL; j++) begin: RX_TS_FIND_RX_SOP
            assign rx_found_sop[j] = |rx_inframe_sop[(j+1)*WORDS_2-1 -:WORDS_2];
        end
            assign fifo_wr_rx_ts     = rx_found_sop;
            assign fifo_wdata_rx_ts  = rx_ptp_its_reg;
    end else begin: RX_TS_AVST
        for (j=0; j<PKT_CYL; j++) begin: RX_TS_FIND_RX_SOP
            assign rx_found_sop[j] = rx_startofpacket_reg && rx_valid_reg;
        end
            assign fifo_wr_rx_ts     = rx_found_sop;
            assign fifo_wdata_rx_ts  = rx_ptp_its_reg;
    end
    endgenerate

    eth_f_hw_dual_clock_fifo #(
        .WIDTH  (PTP_RX_ITS_TS_WIDTH),
        .DEPTH  (FIFO_TS_DEPTH)
    ) rx_ts_fifo (
        .areset        (i_rst_rx),
        .write_clk     (i_clk_rx),
        .write         (fifo_wr_rx_ts),
        .write_data    (fifo_wdata_rx_ts),

        .read_clk      (i_clk_status),
        .read          (fifo_rd_rx_ts),
        .read_data     (fifo_rdata_rx_ts),

        .full          (fifo_full_rx_ts),
        .empty         (fifo_empty_rx_ts)
    );

    assign rd_rx_ptp_its = fifo_rdata_rx_ts;

    //---------------------------------------------
    // PTP Monitor CSR
    //---------------------------------------------

    //---------------------------------------------
    assign status_addr_sel = ({i_status_addr[15:8], 8'b0} == STATUS_BASE_ADDR);
    assign status_read  = i_status_read & status_addr_sel;
    assign status_write = i_status_write & status_addr_sel;

    assign status_read_p = status_read_r & !status_read_r2;
    assign status_write_p = status_write_r & !status_write_r2;

    always @(posedge i_clk_status) begin
        if (i_clk_status_rst) begin
            status_addr_r           <= 8'h0;
            status_addr_sel_r       <= 1'b0;
            status_read_r           <= 1'b0;
            status_write_r          <= 1'b0;
            status_writedata_r      <= 32'h0;
            status_read_r2          <= 1'b0;
            status_write_r2         <= 1'b0;
        end else begin
            status_addr_r           <= i_status_addr[9:2];
            status_addr_sel_r       <= status_addr_sel;
            status_read_r           <= status_read;
            status_write_r          <= status_write;
            status_writedata_r      <= i_status_writedata;
            status_read_r2          <= status_read_r;
            status_write_r2         <= status_write_r;
        end
    end

    always @(posedge i_clk_status) begin
        status_waitrequest_r <= status_waitrequest;
        if (i_clk_status_rst)     status_waitrequest <= 1'b1;
        else         status_waitrequest <= !(status_read_p | status_write_p);
    end
    assign o_status_waitrequest = status_waitrequest & status_waitrequest_r;

    //---------------------------------------------
    always @(posedge i_clk_status) begin
        if (i_clk_status_rst) begin
            soft_rst <= 1'b0;
        end else if (status_write_r & status_addr_sel_r) begin
            case (status_addr_r)
                8'h00:  soft_rst <= status_writedata_r[0];
                default : soft_rst <= soft_rst;
            endcase
        end
    end

    //---------------------------------------------
    // control read signal of fifos
    logic fifo_empty_tx_pkt_s, fifo_empty_tx_pkt_r, fifo_empty_tx_pkt_r2, fifo_empty_tx_pkt_p;
    logic fifo_empty_rx_pkt_s, fifo_empty_rx_pkt_r, fifo_empty_rx_pkt_r2, fifo_empty_rx_pkt_p;
    logic fifo_empty_tx_ptp_cmd_s, fifo_empty_tx_ptp_cmd_r, fifo_empty_tx_ptp_cmd_r2, fifo_empty_tx_ptp_cmd_p;
    logic fifo_empty_tx_ts_s, fifo_empty_tx_ts_r, fifo_empty_tx_ts_r2, fifo_empty_tx_ts_p;
    logic fifo_empty_rx_ts_s, fifo_empty_rx_ts_r, fifo_empty_rx_ts_r2, fifo_empty_rx_ts_p;

    // PKT FIFO: and the empty signals and invert. All fifo's should be filled at the same time
    assign fifo_empty_tx_pkt_s = !(&fifo_empty_tx_pkt);
    assign fifo_empty_rx_pkt_s = !(&fifo_empty_rx_pkt);

    assign fifo_empty_tx_ptp_cmd_s = !fifo_empty_tx_ptp_cmd;
    assign fifo_empty_tx_ts_s = !fifo_empty_tx_ts;
    assign fifo_empty_rx_ts_s = !fifo_empty_rx_ts;

    always @(posedge i_clk_status) begin
        if (i_clk_status_rst) begin
            fifo_empty_tx_pkt_r         <= 1'b0;
            fifo_empty_rx_pkt_r         <= 1'b0;
            fifo_empty_tx_ptp_cmd_r     <= 1'b0;
            fifo_empty_tx_ts_r          <= 1'b0;
            fifo_empty_rx_ts_r          <= 1'b0;

            fifo_empty_tx_pkt_r2        <= 1'b0;
            fifo_empty_rx_pkt_r2        <= 1'b0;
            fifo_empty_tx_ptp_cmd_r2    <= 1'b0;
            fifo_empty_tx_ts_r2         <= 1'b0;
            fifo_empty_rx_ts_r2         <= 1'b0;
        end else begin
            fifo_empty_tx_pkt_r         <= fifo_empty_tx_pkt_s;
            fifo_empty_rx_pkt_r         <= fifo_empty_rx_pkt_s;
            fifo_empty_tx_ptp_cmd_r     <= fifo_empty_tx_ptp_cmd_s;
            fifo_empty_tx_ts_r          <= fifo_empty_tx_ts_s;
            fifo_empty_rx_ts_r          <= fifo_empty_rx_ts_s;

            fifo_empty_tx_pkt_r2        <= fifo_empty_tx_pkt_r;
            fifo_empty_rx_pkt_r2        <= fifo_empty_rx_pkt_r;
            fifo_empty_tx_ptp_cmd_r2    <= fifo_empty_tx_ptp_cmd_r;
            fifo_empty_tx_ts_r2         <= fifo_empty_tx_ts_r;
            fifo_empty_rx_ts_r2         <= fifo_empty_rx_ts_r;
        end
    end

    // handle read for ptpcmd, tx/rx_ts fifo's. These fifo will assert empty if read immediately
    // unlike tx/rx pkt fifo's where multiple write's happen
    logic ptp_cmd_first_read, tx_ts_first_read, rx_ts_first_read;
    always @(posedge i_clk_status) begin
        if (i_clk_status_rst) begin
            ptp_cmd_first_read  <= 1'b0;
        end else if (soft_rst) begin
            ptp_cmd_first_read  <= 1'b0;
        // detect the first pulse from empty. After this, read will only be asserted after reading address 0x0A/0x0F/0x16
        // de-assert first reads when user reads last addr and fifo is empty
        end else if (fifo_empty_tx_ptp_cmd_p) begin
            ptp_cmd_first_read  <= 1'b1;
        end else if ((status_addr_r == 8'h0A) && status_read_r) begin
            ptp_cmd_first_read  <= !fifo_empty_tx_ptp_cmd;
        end
    end

    always @(posedge i_clk_status) begin
        if (i_clk_status_rst) begin
            tx_ts_first_read    <= 1'b0;
        end else if (soft_rst) begin
            tx_ts_first_read    <= 1'b0;
        end else if (fifo_empty_tx_ts_p) begin
            tx_ts_first_read    <= 1'b1;
        end else if ((status_addr_r == 8'h0F) && status_read_r) begin
            tx_ts_first_read    <= !fifo_empty_tx_ts;
        end
    end

    always @(posedge i_clk_status) begin
        if (i_clk_status_rst) begin
            rx_ts_first_read    <= 1'b0;
        end else if (soft_rst) begin
            rx_ts_first_read    <= 1'b0;
        end else if (fifo_empty_rx_ts_p) begin
            rx_ts_first_read    <= 1'b1;
        end else if ((status_addr_r == 8'h16) && status_read_r) begin
            rx_ts_first_read    <= !fifo_empty_rx_ts;
        end
    end

    // detect the edge of empty de-asserting
    assign fifo_empty_tx_pkt_p      = fifo_empty_tx_pkt_r       & !fifo_empty_tx_pkt_r2;
    assign fifo_empty_rx_pkt_p      = fifo_empty_rx_pkt_r       & !fifo_empty_rx_pkt_r2;
    assign fifo_empty_tx_ptp_cmd_p  = fifo_empty_tx_ptp_cmd_r   & !fifo_empty_tx_ptp_cmd_r2;
    assign fifo_empty_tx_ts_p       = fifo_empty_tx_ts_r        & !fifo_empty_tx_ts_r2;
    assign fifo_empty_rx_ts_p       = fifo_empty_rx_ts_r        & !fifo_empty_rx_ts_r2;

    // for TX/RX pkt data, users need to cycle through the addresses <WORDS> times
    // counter has an additional bit width to allow the last word to be read
    logic [CNTR_WIDTH-1:0] word_cnt_tx;
    logic dummy_tx_cnt_reg;
    always @(posedge i_clk_status) begin
        if (i_clk_status_rst) begin
            word_cnt_tx <= {CNTR_WIDTH{1'b0}};
        end else if (soft_rst) begin
            word_cnt_tx <= {CNTR_WIDTH{1'b0}};
        end else if (word_cnt_tx == WORDS)begin
            word_cnt_tx <= {CNTR_WIDTH{1'b0}};
        end else begin
            if (status_read_p & status_addr_r == 8'h04)
                {dummy_tx_cnt_reg, word_cnt_tx} <= word_cnt_tx + 'h1;
        end
    end

    logic [CNTR_WIDTH-1:0] word_cnt_rx;
    logic dummy_rx_cnt_reg;
    always @(posedge i_clk_status) begin
        if (i_clk_status_rst) begin
            word_cnt_rx <= {CNTR_WIDTH{1'b0}};
        end else if (soft_rst) begin
            word_cnt_rx <= {CNTR_WIDTH{1'b0}};
        end else if (word_cnt_rx == WORDS)begin
            word_cnt_rx <= {CNTR_WIDTH{1'b0}};
        end else begin
            if (status_read_p & status_addr_r == 8'h12)
                {dummy_rx_cnt_reg, word_cnt_rx} <= word_cnt_rx + 'h1;
        end
    end

    // Update valid with empty signal from fifo after we finish reading all data from the TX TS fifo (read address = 8'h0F)
    logic tx_ts_valid;
    always @(posedge i_clk_status) begin
        if (i_clk_status_rst) begin
            tx_ts_valid <= 1'b0;
        end else if (soft_rst) begin
            tx_ts_valid <= 1'b0;
        end else if (fifo_empty_tx_ts_p) begin
            tx_ts_valid <= 1'b1;
        end else if (status_read_p & status_addr_r == 8'h0F) begin
            tx_ts_valid <= !fifo_empty_tx_ts;
        end
    end

    for (i=0; i<WORDS; i++) begin: RD_FIFO_PKT_COND
        always @(posedge i_clk_status) begin
            if (i_clk_status_rst) begin
                fifo_rd_tx_pkt[i]    <= 1'b0;
                fifo_rd_rx_pkt[i]    <= 1'b0;
            end else if (soft_rst) begin
                fifo_rd_tx_pkt[i]    <= 1'b0;
                fifo_rd_rx_pkt[i]    <= 1'b0;
            end else begin
                fifo_rd_tx_pkt[i]    <= fifo_empty_tx_pkt_p | ((status_read_p & (status_addr_r == 8'h04) & fifo_empty_tx_pkt_s) & (word_cnt_tx == WORDS - 1));
                fifo_rd_rx_pkt[i]    <= fifo_empty_rx_pkt_p | ((status_read_p & (status_addr_r == 8'h12) & fifo_empty_rx_pkt_s) & (word_cnt_rx == WORDS - 1));
            end
        end
    end

    // assert read to FIFO's during first read and after all data are read out to the user
    always @(posedge i_clk_status) begin
        if (i_clk_status_rst) begin
            fifo_rd_tx_ptp_cmd   <= 1'b0;
            fifo_rd_tx_ts        <= 1'b0;
            fifo_rd_rx_ts        <= 1'b0;
        end else if (soft_rst) begin
            fifo_rd_tx_ptp_cmd   <= 1'b0;
            fifo_rd_tx_ts        <= 1'b0;
            fifo_rd_rx_ts        <= 1'b0;
        end else begin
            fifo_rd_tx_ptp_cmd   <= (!ptp_cmd_first_read & fifo_empty_tx_ptp_cmd_p) | (status_read_p & (status_addr_r == 8'h0A) & !fifo_empty_tx_ptp_cmd);
            fifo_rd_tx_ts        <= (!tx_ts_first_read & fifo_empty_tx_ts_p) | (status_read_p & (status_addr_r == 8'h0F) & !fifo_empty_tx_ts);
            fifo_rd_rx_ts        <= (!rx_ts_first_read & fifo_empty_rx_ts_p) | (status_read_p & (status_addr_r == 8'h16) & !fifo_empty_rx_ts);
        end
    end

    //---------------------------------------------
    always @(posedge i_clk_status) begin
        o_status_readdata_valid <= status_read_r2 & !status_waitrequest_r;
        if (status_read_p) begin
            if (status_addr_sel_r) begin
                case (status_addr_r)
                    8'h00:     o_status_readdata <= {31'h0, soft_rst};
                    8'h01:     o_status_readdata <= {29'h0, fifo_empty_rx_pkt_s, tx_ts_valid, fifo_empty_tx_pkt_s};
                    8'h02:     o_status_readdata <= rd_tx_data_63_32[(WORDS-1-word_cnt_tx[VALID_BITS-1:0])];
                    8'h03:     o_status_readdata <= rd_tx_data_31_0[(WORDS-1-word_cnt_tx[VALID_BITS-1:0])];
                    8'h04:     o_status_readdata <= {{READDATA_TX_PAD{1'b0}},
                                                    rd_tx_skip_crc[(WORDS-1-word_cnt_tx[VALID_BITS-1:0])],
                                                    rd_tx_error[(WORDS-1-word_cnt_tx[VALID_BITS-1:0])],
                                                    rd_tx_empty[(WORDS-1-word_cnt_tx[VALID_BITS-1:0])],
                                                    rd_tx_eop[(WORDS-1-word_cnt_tx[VALID_BITS-1:0])],
                                                    rd_tx_sop[(WORDS-1-word_cnt_tx[VALID_BITS-1:0])],
                                                    rd_tx_mac_inframe[(WORDS-1-word_cnt_tx[VALID_BITS-1:0])] };
                    8'h05:     o_status_readdata <= {rd_ptp_ins_ts_offset, rd_ptp_asym_p2p_idx, rd_ptp_asym_sign, 1'b0, rd_ptp_asym, rd_ptp_p2p, rd_ptp_ins_update_eb, rd_ptp_ins_zero_csum, rd_ptp_ins_cf, rd_ptp_ins_ets, rd_ptp_ts_req};
                    8'h06:     o_status_readdata <= {rd_ptp_ins_csum_offset, rd_ptp_ins_cf_offset};
                    8'h07:     o_status_readdata <= {{READDATA_FP_PAD{1'b0}}, rd_ptp_fp};
                    8'h08:     o_status_readdata <= rd_tx_ptp_rt_its[95:64];
                    8'h09:     o_status_readdata <= rd_tx_ptp_rt_its[63:32];
                    8'h0a:     o_status_readdata <= rd_tx_ptp_rt_its[31:0];
                    8'h0b:     o_status_readdata <= {27'h0, 5'h0};   // Reserved
                    8'h0c:     o_status_readdata <= {{READDATA_FP_PAD{1'b0}}, rd_tx_ptp_ets_fp};
                    8'h0d:     o_status_readdata <= {rd_tx_ptp_ets[95:64]};
                    8'h0e:     o_status_readdata <= {rd_tx_ptp_ets[63:32]};
                    8'h0f:     o_status_readdata <= {rd_tx_ptp_ets[31:0]};
                    8'h10:     o_status_readdata <= {{READDATA_RX_PAD{1'b0}},
                                                    rd_rx_fcs_err[(WORDS-1-word_cnt_rx[VALID_BITS-1:0])],
                                                    rd_rx_err[(WORDS-1-word_cnt_rx[VALID_BITS-1:0])],
                                                    rd_rx_empty[(WORDS-1-word_cnt_rx[VALID_BITS-1:0])],
                                                    rd_rx_eop[(WORDS-1-word_cnt_rx[VALID_BITS-1:0])],
                                                    rd_rx_sop[(WORDS-1-word_cnt_rx[VALID_BITS-1:0])],
                                                    rd_rx_mac_inframe[(WORDS-1-word_cnt_rx[VALID_BITS-1:0])] };
                    8'h11:     o_status_readdata <= rd_rx_data_63_32[(WORDS-1-word_cnt_rx[VALID_BITS-1:0])];
                    8'h12:     o_status_readdata <= rd_rx_data_31_0[(WORDS-1-word_cnt_rx[VALID_BITS-1:0])];
                    8'h13:     o_status_readdata <= {27'h0, 5'h0};   // Reserved
                    8'h14:     o_status_readdata <= rd_rx_ptp_its[95:64];
                    8'h15:     o_status_readdata <= rd_rx_ptp_its[63:32];
                    8'h16:     o_status_readdata <= rd_rx_ptp_its[31:0];

                    default:  o_status_readdata <= 32'hdeadc0de;
                endcase
            end else begin
                o_status_readdata <= 32'hdeadc0de;
            end
        end
    end

endmodule


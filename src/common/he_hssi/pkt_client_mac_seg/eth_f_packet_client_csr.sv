// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`timescale 1 ps / 1 ps

module eth_f_packet_client_csr #(
        parameter CLIENT_IF_TYPE        = 0,
        parameter STATUS_BASE_ADDR      = 16'b0,
        parameter SIM_EMULATE           = 0,
        parameter ROM_ADDR_WIDTH        = 8,
        parameter ROM_LOOPCOUNT_WIDTH   = 16
    )(
        input  logic                  i_clk_status,
        input  logic                  i_clk_status_rst,

        // status register bus
        input  logic   [22:0]         i_status_addr,
        input  logic                  i_status_read,
        input  logic                  i_status_write,
        input  logic   [31:0]         i_status_writedata,
        output logic   [31:0]         o_status_readdata,
        output logic                  o_status_readdata_valid,
        output logic                  o_status_waitrequest,

        //---csr ctrl
        output logic [15:0]                     cfg_pkt_client_ctrl,   // [0]: start/stop sending pkt; 0: stop sending pkt;
        output logic [ROM_ADDR_WIDTH-1:0]       cfg_rom_start_addr,    // Rom start addr for packet data;
        output logic [ROM_ADDR_WIDTH-1:0]       cfg_rom_end_addr,      // define how many rows in Rom for packet data;
        output logic [ROM_LOOPCOUNT_WIDTH-1:0]  cfg_test_loop_cnt,     // define how many loops in total to read from Rom;
        output logic stat_cntr_snapshot,
        output logic stat_cntr_clear,
        output logic stat_lat_en,
        //---stat interface---
        output logic                  stat_tx_cnt_clr,
        input  logic                  stat_tx_cnt_vld,
        input  logic [7:0]            stat_tx_sop_cnt,
        input  logic [7:0]            stat_tx_eop_cnt,
        input  logic [7:0]            stat_tx_err_cnt,

        output logic                  stat_rx_cnt_clr,
        input  logic                  stat_rx_cnt_vld,
        input  logic [7:0]            stat_rx_sop_cnt,
        input  logic [7:0]            stat_rx_eop_cnt,
        input  logic [7:0]            stat_rx_err_cnt,
          
        input  logic                  stat_lat_cnt_done,
        input  logic [7:0]            stat_lat_cnt,

        input  logic                  i_loopback_fifo_wr_full_err,
        input  logic                  i_loopback_fifo_rd_empty_err
);

//---------------------------------------------
logic [63:0]  stat_tx_sop_cnt_all, stat_tx_eop_cnt_all, stat_tx_err_cnt_all;
logic [63:0]  stat_rx_sop_cnt_all, stat_rx_eop_cnt_all, stat_rx_err_cnt_all;
logic [63:0]  stat_tx_sop_cnt_all_shadow, stat_tx_eop_cnt_all_shadow, stat_tx_err_cnt_all_shadow;
logic [63:0]  stat_rx_sop_cnt_all_shadow, stat_rx_eop_cnt_all_shadow, stat_rx_err_cnt_all_shadow;
logic [63:0]  timestamp_counter, stat_timestamp_tg_start_shadow, stat_timestamp_tg_end_shadow;
logic         clear_timestamp;

logic         loopback_fifo_wr_full_err, loopback_fifo_rd_empty_err;

logic [7:0]   status_addr_r;
logic [31:0]  status_writedata_r;
logic         status_addr_sel, status_read, status_write;
logic         status_addr_sel_r, status_read_r, status_write_r;
logic         status_read_r2, status_write_r2;
logic         status_read_p, status_write_p;
logic         cfg_cnt_clr_clr; 
logic         status_waitrequest, status_waitrequest_r;

logic         tg_start_stopn, tg_start_stopn_r;

//---------------------------------------------
//---cfg_pkt_client_ctrl (reg_00)---
//---[0]: 1: start pkt generator; 0: stop pkt gen;
//---[4]: 0: send pkt generator data to MAC; 1: send loopback client data to MAC;
//---[8]: 1: clear pkt tx/rx counters; self-clean;

//---------------------------------------------
logic [31:0]  reg_00;   //---cfg_pkt_client_ctrl
logic [31:0]  reg_01;   //---cfg_test_loop_cnt
logic [31:0]  reg_02;   //---Rom start/end address;
logic [31:0]  reg_03;   //---some status signals;
logic [31:0]  reg_04;   //latency measure register, bit 31 is used as enable

//---------------------------------------------
assign cfg_pkt_client_ctrl  = reg_00[15:0];
assign tg_start_stopn       = reg_00[0];
assign cfg_test_loop_cnt    = reg_01[0+:ROM_LOOPCOUNT_WIDTH];
assign cfg_rom_start_addr   = reg_02[0+:ROM_ADDR_WIDTH];
assign cfg_rom_end_addr     = reg_02[16+:ROM_ADDR_WIDTH];
assign stat_lat_en           = reg_04[31];

//---------------------------------------------
assign status_addr_sel = ({i_status_addr[15:8], 8'b0} == STATUS_BASE_ADDR);
assign status_read  = i_status_read & status_addr_sel;
assign status_write = i_status_write & status_addr_sel;

assign status_read_p = status_read_r & !status_read_r2;
assign status_write_p = status_write_r & !status_write_r2;

//---------------------------------------------
always @(posedge i_clk_status) begin
        status_addr_r           <= i_status_addr[9:2];
        status_addr_sel_r       <= status_addr_sel;
        status_read_r           <= status_read;
        status_write_r          <= status_write;
        status_writedata_r      <= i_status_writedata;
        status_read_r2          <= status_read_r;
        status_write_r2         <= status_write_r;
        tg_start_stopn_r        <= tg_start_stopn;
end

always @(posedge i_clk_status) begin
    status_waitrequest_r <= status_waitrequest;
    if (i_clk_status_rst)     status_waitrequest <= 1'b1;
    else         status_waitrequest <= !(status_read_p | status_write_p);
end
assign o_status_waitrequest = status_waitrequest & status_waitrequest_r;

//---------------------------------------------
logic  stat_tx_sop_cnt_sel, stat_tx_eop_cnt_sel;
assign stat_tx_sop_cnt_sel = status_addr_sel_r & (status_addr_r == 8'h8);
assign stat_tx_eop_cnt_sel = status_addr_sel_r & (status_addr_r == 8'h9);

//---------------------------------------------
always @(posedge i_clk_status) begin
    if (i_clk_status_rst) begin
                   reg_00 <= 32'h0000_0000;
                   reg_01 <= 32'h0000_0001;
                   reg_02 <= 32'h007F_0000;
                   reg_03 <= 32'h0000_0000;
                         reg_04[31] <= 1'b0;
    end else if (status_write_r & status_addr_sel_r) begin
        case (status_addr_r)
            8'h00:  reg_00 <= status_writedata_r;
            8'h01:  reg_01 <= status_writedata_r;
            8'h02:  reg_02 <= status_writedata_r;
            8'h03:  reg_03 <= status_writedata_r;
                8'h04:  reg_04[31] <= status_writedata_r[31];
        endcase
    end else begin
        if (cfg_cnt_clr_clr)  reg_00[8] <= 1'b0;
          if (stat_lat_cnt_done) reg_04[31] <= 1'b0;
        reg_03[0] <= loopback_fifo_wr_full_err;
        reg_03[1] <= loopback_fifo_rd_empty_err;
    end
end

//---------------------------------------------
always @(posedge i_clk_status) begin
        o_status_readdata_valid <= status_read_r2 & !status_waitrequest_r;
    if (status_read_p) begin
        if (status_addr_sel_r) begin
            case (status_addr_r)
                8'h00:     o_status_readdata <= reg_00;
                8'h01:     o_status_readdata <= reg_01;
                8'h02:     o_status_readdata <= reg_02;
                8'h03:     o_status_readdata <= reg_03;
                     8'h04:     o_status_readdata <= {24'b0,stat_lat_cnt};

                8'h8:     o_status_readdata <= stat_tx_sop_cnt_all_shadow[31:0];
        8'h9:     o_status_readdata <= stat_tx_sop_cnt_all_shadow[63:32];

                8'ha:     o_status_readdata <= stat_tx_eop_cnt_all_shadow[31:0];
        8'hb:    o_status_readdata <= stat_tx_eop_cnt_all_shadow[63:32];

                8'hc:     o_status_readdata <= stat_tx_err_cnt_all_shadow[31:0];
        8'hd:    o_status_readdata <= stat_tx_err_cnt_all_shadow[63:32];

                8'he:     o_status_readdata <= stat_rx_sop_cnt_all_shadow[31:0];
        8'hf:    o_status_readdata <= stat_rx_sop_cnt_all_shadow[63:32];

                8'h10:     o_status_readdata <= stat_rx_eop_cnt_all_shadow[31:0];
        8'h11:    o_status_readdata <= stat_rx_eop_cnt_all_shadow[63:32];

                8'h12:     o_status_readdata <= stat_rx_err_cnt_all_shadow[31:0];
        8'h13:    o_status_readdata <= stat_rx_err_cnt_all_shadow[63:32];

                8'h14:     o_status_readdata <= stat_timestamp_tg_start_shadow[31:0];
        8'h15:    o_status_readdata <= stat_timestamp_tg_start_shadow[63:32];

                8'h16:     o_status_readdata <= stat_timestamp_tg_end_shadow[31:0];
        8'h17:    o_status_readdata <= stat_timestamp_tg_end_shadow[63:32];

                default:  o_status_readdata <= 32'hdeadc0de;
            endcase
        end else begin
            o_status_readdata <= 32'hdeadc0de;
        end
    end
end

//---------------------------------------------
always @(posedge i_clk_status) begin
    loopback_fifo_wr_full_err  <= i_loopback_fifo_wr_full_err;
    loopback_fifo_rd_empty_err <= i_loopback_fifo_rd_empty_err;
end

//---------------------------------------------
logic [7:0] cfg_cnt_clr;
always @(posedge i_clk_status) begin
    cfg_cnt_clr <= {cfg_cnt_clr[6:0], reg_00[8]};
end

assign stat_rx_cnt_clr = reg_00[8];
assign stat_tx_cnt_clr = reg_00[8];
assign clear_timestamp = reg_00[8];
assign cfg_cnt_clr_clr = cfg_cnt_clr[7];   // for self-clear;
assign stat_cntr_snapshot = reg_00[6]; //for snapshot
assign stat_cntr_clear = reg_00[7]; //for clear


always_ff @(posedge i_clk_status) begin
  if (stat_cntr_clear) begin
   stat_tx_sop_cnt_all_shadow <= 0;
   stat_tx_eop_cnt_all_shadow <= 0;
   stat_tx_err_cnt_all_shadow <= 0;
   stat_rx_sop_cnt_all_shadow <= 0;
   stat_rx_eop_cnt_all_shadow <= 0;
   stat_rx_err_cnt_all_shadow <= 0;
  end else begin
    if (stat_cntr_snapshot) begin 
        stat_tx_sop_cnt_all_shadow  <= stat_tx_sop_cnt_all_shadow;
        stat_tx_eop_cnt_all_shadow  <= stat_tx_eop_cnt_all_shadow;
        stat_tx_err_cnt_all_shadow  <= stat_tx_err_cnt_all_shadow;
        stat_rx_sop_cnt_all_shadow  <= stat_rx_sop_cnt_all_shadow;
        stat_rx_eop_cnt_all_shadow  <= stat_rx_eop_cnt_all_shadow;
        stat_rx_err_cnt_all_shadow  <= stat_rx_err_cnt_all_shadow;
    end else begin
        stat_tx_sop_cnt_all_shadow  <= stat_tx_sop_cnt_all;
        stat_tx_eop_cnt_all_shadow  <= stat_tx_eop_cnt_all;
        stat_tx_err_cnt_all_shadow  <= stat_tx_err_cnt_all;
        stat_rx_sop_cnt_all_shadow  <= stat_rx_sop_cnt_all;
        stat_rx_eop_cnt_all_shadow  <= stat_rx_eop_cnt_all;
        stat_rx_err_cnt_all_shadow  <= stat_rx_err_cnt_all;
    end
  end

  if (clear_timestamp) begin
    timestamp_counter <= 0;
  end else begin
    timestamp_counter <= timestamp_counter + 1;
  end

  if (stat_cntr_clear) begin
    stat_timestamp_tg_start_shadow <= 0;
    stat_timestamp_tg_end_shadow <= 0;
  end else begin
    if (tg_start_stopn && !tg_start_stopn_r) begin // Rising-edge on Start
      stat_timestamp_tg_start_shadow <= timestamp_counter;
    end else if (!tg_start_stopn && tg_start_stopn_r) begin // Falling-edge on Start (i.e. Stop)
      stat_timestamp_tg_end_shadow  <= timestamp_counter;
    end
  end
end


//---------------------------------------------
eth_f_packet_client_csr_pkt_cnt  u_tx_sop_cnt (
        .clk        (i_clk_status),
        .rst        (i_clk_status_rst),
        .cnt_clr    (stat_tx_cnt_clr),
        .cnt_in_vld (stat_tx_cnt_vld),
        .cnt_in     (stat_tx_sop_cnt),
        .cnt_out    (stat_tx_sop_cnt_all)
);


eth_f_packet_client_csr_pkt_cnt  u_tx_eop_cnt (
        .clk        (i_clk_status),
        .rst        (i_clk_status_rst),
        .cnt_clr    (stat_tx_cnt_clr),
        .cnt_in_vld (stat_tx_cnt_vld),
        .cnt_in     (stat_tx_eop_cnt),
        .cnt_out    (stat_tx_eop_cnt_all)
);



eth_f_packet_client_csr_pkt_cnt  u_tx_err_cnt (
        .clk        (i_clk_status),
        .rst        (i_clk_status_rst),
        .cnt_clr    (stat_tx_cnt_clr),
        .cnt_in_vld (stat_tx_cnt_vld),
        .cnt_in     (stat_tx_err_cnt),
        .cnt_out    (stat_tx_err_cnt_all)
);


//---------------------------------------------
eth_f_packet_client_csr_pkt_cnt  u_rx_sop_cnt (
        .clk        (i_clk_status),
        .rst        (i_clk_status_rst),
        .cnt_clr    (stat_rx_cnt_clr),
        .cnt_in_vld (stat_rx_cnt_vld),
        .cnt_in     (stat_rx_sop_cnt),
        .cnt_out    (stat_rx_sop_cnt_all)
);


eth_f_packet_client_csr_pkt_cnt  u_rx_eop_cnt (
        .clk        (i_clk_status),
        .rst        (i_clk_status_rst),
        .cnt_clr    (stat_rx_cnt_clr),
        .cnt_in_vld (stat_rx_cnt_vld),
        .cnt_in     (stat_rx_eop_cnt),
        .cnt_out    (stat_rx_eop_cnt_all)
);

eth_f_packet_client_csr_pkt_cnt  u_rx_err_cnt (
        .clk        (i_clk_status),
        .rst        (i_clk_status_rst),
        .cnt_clr    (stat_rx_cnt_clr),
        .cnt_in_vld (stat_rx_cnt_vld),
        .cnt_in     (stat_rx_err_cnt),
        .cnt_out    (stat_rx_err_cnt_all)
);

//---------------------------------------------
endmodule


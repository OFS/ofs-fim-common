// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// AXIS pipeline generator
//
//-----------------------------------------------------------------------------

`timescale 1 ps / 1 ps

import ofs_fim_eth_if_pkg::*;

module axis_hssi_pr_freeze_bridge #( 
    parameter TDATA_WIDTH          = 512,
    parameter TUSER_WIDTH          = 10,
    // 0 - Uses pr_freeze signal
    // 1 - Doesn't use pr_freeze signal
    parameter PR_FREEZE_DIS        = 0,
    parameter TX_REG_MODE          = 0,
    parameter RX_REG_MODE          = 1 //Only Simple, Bypass needed for RX since there is no backpressure
)(
    input logic                  pr_freeze,
    input logic                  afu_reset,
    ofs_fim_hssi_ss_tx_axis_if.client hssi_ss_st_tx,
    ofs_fim_hssi_ss_rx_axis_if.client hssi_ss_st_rx,
    ofs_fim_hssi_fc_if.client         hssi_fc,
    input logic                       i_hssi_clk_pll,


    ofs_fim_hssi_ss_tx_axis_if.mac    hssi_afu_st_tx,
    ofs_fim_hssi_ss_rx_axis_if.mac    hssi_afu_st_rx,
    ofs_fim_hssi_fc_if.mac            hssi_afu_fc

);

   logic                          hssi_tx_rst_n;
   logic                          hssi_rx_rst_n;
   logic                          hssi_rx_rst_n_d;
   ofs_fim_hssi_ss_tx_axis_if     hssi_frz2port_ss_st_tx  ();
   ofs_fim_hssi_fc_if             hssi_frz2port_fc ();
   logic                          pr_freeze_wire;

   generate 
   if (PR_FREEZE_DIS == 1) begin
       assign pr_freeze_wire = 0;
   end else begin
       assign pr_freeze_wire = pr_freeze;
   end
   endgenerate

   axis_tx_hssi_pipeline #(
      .TDATA_WIDTH (TDATA_WIDTH),
      .TUSER_WIDTH (TUSER_WIDTH),
      .MODE (TX_REG_MODE)
   ) pr_frz_mx2fn_hssi_port (
      .axis_m (hssi_frz2port_ss_st_tx),
      .axis_s (hssi_afu_st_tx)
   );

   always_comb begin
      hssi_afu_st_rx.clk = hssi_ss_st_rx.clk;
      hssi_afu_st_rx.rst_n = hssi_rx_rst_n;

      hssi_frz2port_ss_st_tx.clk    = hssi_ss_st_tx.clk;
      hssi_frz2port_ss_st_tx.rst_n  = hssi_tx_rst_n;
      hssi_frz2port_ss_st_tx.tready = hssi_ss_st_tx.tready;
      hssi_ss_st_tx.tx.tlast = hssi_frz2port_ss_st_tx.tx.tlast;
      hssi_ss_st_tx.tx.tdata = hssi_frz2port_ss_st_tx.tx.tdata;
      hssi_ss_st_tx.tx.tkeep = hssi_frz2port_ss_st_tx.tx.tkeep;
     `ifndef INCLUDE_PTP
         hssi_ss_st_tx.tx.tuser = hssi_frz2port_ss_st_tx.tx.tuser;
     `endif
      if (pr_freeze_wire) begin
         hssi_ss_st_tx.tx.tvalid = '0;
      end else begin
         hssi_ss_st_tx.tx.tvalid = hssi_frz2port_ss_st_tx.tx.tvalid;
      end
   end

   generate
   if (RX_REG_MODE == 2)
      always_ff @(posedge hssi_ss_st_rx.clk) begin
          hssi_afu_st_rx.rx <= hssi_ss_st_rx.rx;
      end
   else  //Bypass
        assign hssi_afu_st_rx.rx = hssi_ss_st_rx.rx;
   endgenerate

   always_ff @(posedge i_hssi_clk_pll) begin
      hssi_frz2port_fc.tx_pause <= hssi_afu_fc.tx_pause;
      hssi_frz2port_fc.tx_pfc   <= hssi_afu_fc.tx_pfc;
   end

   always_ff @(posedge hssi_ss_st_rx.clk) begin
      hssi_afu_fc.rx_pause  <= hssi_frz2port_fc.rx_pause;
      hssi_afu_fc.rx_pfc    <= hssi_frz2port_fc.rx_pfc;
   end

   always_comb begin 
      hssi_frz2port_fc.rx_pause = hssi_fc.rx_pause;
      hssi_frz2port_fc.rx_pfc   = hssi_fc.rx_pfc;
      if (pr_freeze_wire) begin
         hssi_fc.tx_pause = '0;
         hssi_fc.tx_pfc   = '0; 
      end else begin
         hssi_fc.tx_pause = hssi_frz2port_fc.tx_pause;
         hssi_fc.tx_pfc   = hssi_frz2port_fc.tx_pfc;
      end
   end

   // Add softreset to ch resets in PR domain
   always_ff @(posedge hssi_ss_st_rx.clk) begin
      hssi_rx_rst_n_d <= hssi_ss_st_rx.rst_n & ~afu_reset;
      hssi_rx_rst_n   <= hssi_rx_rst_n_d;
   end

   always @(posedge hssi_ss_st_tx.clk) hssi_tx_rst_n <= hssi_ss_st_tx.rst_n & ~afu_reset;
endmodule // axis_hssi_pr_freeze_bridge


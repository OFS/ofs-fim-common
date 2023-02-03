// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
// Description
//-----------------------------------------------------------------------------
//
// CDC FIFO to cross clock domain between Ethernet AXI-S interface 
//
//-----------------------------------------------------------------------------

`timescale 1ps / 1ps

import ofs_fim_eth_if_pkg::*;

module eth_rx_axis_cdc_fifo #(
   parameter DEPTH_LOG2         = 6,
   parameter ALMFULL_THRESHOLD  = 2
)(
   input wire                       src_clk,
   input wire                       src_rst_n,
   ofs_fim_eth_rx_axis_if.slave     snk_if,
   ofs_fim_eth_rx_axis_if.master    src_if
);

ofs_fim_eth_if_pkg::t_axis_eth_rx  fifo_din, fifo_dout;
logic                          fifo_wreq;
logic                          fifo_rdack;
logic                          fifo_almfull;
logic                          fifo_valid;
logic                          snk_tready;
logic                          snk_clk;
logic                          snk_rst_n;
logic                          src_tready_reg;

assign snk_if.tready = snk_tready;
assign snk_clk         = snk_if.clk; 
assign snk_rst_n       = snk_if.rst_n;
assign src_if.clk      = src_clk;
assign src_if.rst_n    = src_rst_n;

fim_rdack_dcfifo #(
   .DATA_WIDTH            (AXIS_ETH_RX_WIDTH),
   .DEPTH_LOG2            (DEPTH_LOG2),          // depth 64 
   .ALMOST_FULL_THRESHOLD (ALMFULL_THRESHOLD+2), // allow 4 pipelines
   .READ_ACLR_SYNC        ("ON")                 // add aclr synchronizer on read side
) fifo (
   .wclk      (snk_clk),
   .rclk      (src_clk),
   .aclr      (~snk_rst_n),
   .wdata     (fifo_din), 
   .wreq      (fifo_wreq),
   .rdack     (fifo_rdack),
   .rdata     (fifo_dout),
   .wfull     (),
   .almfull   (fifo_almfull),
   .rvalid    (fifo_valid)
);

 axis_register #( 
         .MODE           ( 0 ),
         .TREADY_RST_VAL ( 0 ),
         .ENABLE_TKEEP   ( 1 ),
         .ENABLE_TLAST   ( 1 ),
         .ENABLE_TID     ( 0 ),
         .ENABLE_TDEST   ( 0 ),
         .ENABLE_TUSER   ( 1 ),
         .TDATA_WIDTH    ( ETH_PACKET_WIDTH ),
         .TUSER_WIDTH    ( ETH_RX_ERROR_WIDTH )
      
      ) axis_reg_inst (
        .clk       (src_clk),
        .rst_n     (src_rst_n),

        .s_tready  (src_tready_reg),
        .s_tvalid  (fifo_valid),
        .s_tdata   (fifo_dout.tdata),
        .s_tkeep   (fifo_dout.tkeep),
        .s_tlast   (fifo_valid && fifo_dout.tlast),
        .s_tid     (),
        .s_tdest   (),
        .s_tuser   (fifo_dout.tuser),
                   
        .m_tready  (src_if.tready),
        .m_tvalid  (src_if.rx.tvalid),
        .m_tdata   (src_if.rx.tdata),
        .m_tkeep   (src_if.rx.tkeep),
        .m_tlast   (src_if.rx.tlast),
        .m_tid     (),
        .m_tdest   (), 
        .m_tuser   (src_if.rx.tuser)
      );

assign fifo_wreq  = fifo_din.tvalid && snk_tready;
assign fifo_rdack = (~src_if.rx.tvalid || src_tready_reg);

// Input Register
always_ff @(posedge snk_clk) begin 
   if (~fifo_almfull) begin
      fifo_din           <= snk_if.rx;
   end
end

always_ff @(posedge snk_clk) begin
   snk_tready <= ~fifo_almfull;
   if (~snk_rst_n) begin
      snk_tready <= 1'b0;
   end
end

endmodule : eth_rx_axis_cdc_fifo

// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
// Description
//-----------------------------------------------------------------------------
//
// CDC FIFO to cross clock domain between two AXI-S interface 
//
//-----------------------------------------------------------------------------

`timescale 1ps / 1ps

import pcie_ss_axis_pkg::*;

module pcie_axis_cdc_fifo #(
   parameter DEPTH_LOG2         = 6,
   parameter ALMFULL_THRESHOLD  = 2
)(
    input wire                  snk_clk,
    input wire                  snk_rst_n,

    input wire                  src_clk,
    input wire                  src_rst_n,
    
    pcie_ss_axis_if.sink        snk_if,
    pcie_ss_axis_if.source      src_if
);

pcie_ss_axis_pkg::t_axis_pcie  fifo_din, fifo_dout;
logic                          fifo_wreq;
logic                          fifo_rdack;
logic                          fifo_almfull;
logic                          fifo_valid;
logic                          snk_tready;

assign snk_if.tready = snk_tready;

fim_rdack_dcfifo #(
   .DATA_WIDTH            (T_AXIS_PCIE_WIDTH),
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

assign fifo_wreq  = fifo_din.tvalid && snk_tready;
assign fifo_rdack = (~src_if.tvalid || src_if.tready);

// Input Register
always_ff @(posedge snk_clk) begin 
   if (snk_tready) begin
      fifo_din.tvalid <= snk_if.tvalid;
      fifo_din.tdata  <= snk_if.tdata;
      fifo_din.tkeep  <= snk_if.tkeep;
      fifo_din.tuser  <= snk_if.tuser_vendor;
      fifo_din.tlast  <= snk_if.tlast;
   end
end

// Output Register
always_ff @(posedge src_clk) begin
   if (fifo_rdack) begin
      src_if.tdata        <= fifo_dout.tdata;
      src_if.tkeep        <= fifo_dout.tkeep;
      src_if.tuser_vendor <= fifo_dout.tuser;
      src_if.tvalid       <= fifo_valid;
      src_if.tlast        <= fifo_valid && fifo_dout.tlast;
   end

   if (~src_rst_n) 
      src_if.tvalid <= 1'b0;
end

always_ff @(posedge snk_clk) begin
   snk_tready <= ~fifo_almfull;
   if (~snk_rst_n) begin
      snk_tready <= 1'b0;
   end
end

endmodule : pcie_axis_cdc_fifo

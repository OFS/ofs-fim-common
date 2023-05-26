// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// This is a register based handshake circuit for moving data across unrelated domains. 
// The bandwidth is relatively low due to the 2 way negotiation.
//
//-----------------------------------------------------------------------------

`timescale 1ps/1ps

module fim_cross_handshake #(
      parameter WIDTH = 32
)(
      input  logic             din_clk,
      input  logic             din_srst,
      input  logic [WIDTH-1:0] din,
      input  logic             din_valid,
      output logic             din_ack,

      input  logic             dout_clk,
      input  logic             dout_srst,
      output logic [WIDTH-1:0] dout,
      output logic             dout_valid,
      input  logic             dout_ack
);

// Registers holding sampled din signals to be passed to dout_clk domain
logic [WIDTH-1:0] launch /* synthesis preserve dont_replicate */;

// Transfer in progress
logic launch_valid /* synthesis preserve dont_replicate */;

// Single-cycle pulse indicating start of new transfer
logic launch_fresh /* synthesis preserve dont_replicate */;

always_ff @(posedge din_clk) begin
   if (din_srst) begin
      launch_valid <= 1'b0;
      launch_fresh <= 1'b0;
   end else begin
      launch_fresh <= 1'b0; // De-assert lauch_fresh in the next cycle following its assertion
      
      // Sample din_valid when there is no active transfer (launch_valid=0)
      if (~launch_valid && din_valid) begin
         // When din_valid=1 is sampled, assert launch_valid (transfer in progress)
         launch_valid <= 1'b1;
         launch_fresh <= 1'b1;
      end

      // De-assert launch_valid when current transfer is acknowledged
      if (din_ack) 
         launch_valid <= 1'b0;
   end
end

// Sample din signals
always_ff @(posedge din_clk) begin
   if (~launch_valid && din_valid)
      launch <= din;
end

// Move capturing pulse to dout_clk domain
logic capture_ena;

fim_cross_strobe ena_strb (
   .din_clk    (din_clk),
   .din_srst   (din_srst),
   .din_pulse  (launch_fresh),

   .dout_clk   (dout_clk),
   .dout_srst  (dout_srst),
   .dout_pulse (capture_ena)
);

// Capture the input
logic [WIDTH-1:0] capture;
logic capture_ack;
logic capture_valid;

always_ff @(posedge dout_clk) begin
   if (dout_srst) begin
      capture_valid <= 1'b0;
   end else begin
      if (capture_ena) capture_valid <= 1'b1;
      if (capture_ack) capture_valid <= 1'b0;
   end
end

// Capture stable signals from the source clock domain
always_ff @(posedge dout_clk) begin
   if (capture_ena)
      capture <= launch;
end

// Return the ack
fim_cross_strobe ack_strb (
   .din_clk    (dout_clk),
   .din_srst   (dout_srst),
   .din_pulse  (capture_ack),

   .dout_clk   (din_clk),
   .dout_srst  (din_srst),
   .dout_pulse (din_ack)   
);

assign dout        = capture;
assign dout_valid  = capture_valid;
assign capture_ack = dout_ack;

endmodule


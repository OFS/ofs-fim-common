// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// Low resolution frequency counter based off inaccurate (SSC) 100 MHz time base.
//
// Time base approximate accuracy:
//   SSC off:  +/-100 ppm or +/-150 ppm
//
//   SSC  on: (+/-100 ppm or +/-150 ppm) - 2500 ppm (slow); -2350/-2650 ppm
//            Typically, will read frequency as approximately 0.25% high
//
// Resolution is 10 kHz.
//
// Count is +/- 1 count.
//
// Update rate is approximately 2.6 ms (16x prescaler, and 18-bit wrap counter).
// This is much faster than maximum PR load time, about 0.9 s.
//
// To operate:
//   1) Mode should be set (measure uclk or uclk_div2).
//   2) Wait > 5.3 ms; recommend wait time is 10 ms
//   3) Read frequency
//   4) Should match +/- 1 count plus accuracy limits (timebase + oscillator source)
// 
//
// Command:
//   [   32]: measure fast clock:
//            1: measure  uclk
//            0: measure  uclk_div2
//
// Status:
//   [63:60]: version
//   [   32]: clock measured
//            1: measured uclk
//            0: measured uclk_div2
//   [16:00]: frequency in 10 kHz units
//
//-----------------------------------------------------------------------------

import qph_user_clk_pkg::*;

module qph_user_clk_freq
#(
   // Actual frequency of clk. Expected to be about 100MHz, though
   // the actual frequency may be off by up to 1%.
   parameter real CLK_MHZ = 100.0
)
(
   // Clocks and Reset
   input  logic              clk,                          // 100 MHz 0deg SSC 
   input  logic              rst_n,

   // User clocks
   input  logic              uclk,                         // User clock
   input  logic              uclk_div2,                    // User clock divided by 2

   // Command and status (synchronous to clk)
   input  logic              i_sel_uclk,
   output logic              o_freq_valid,
   output logic [16:0]       o_freq
);

//-----------------------------------------------------------------------------------------------------

// Free running 2^18 time base with the goal of counting
// cycles for 100us. The prescaler slows counting by a
// factor of 16 so user clock cycles are counted for 1.6ms.
localparam ETIME_CYCLES = 18'(int'(CLK_MHZ * 1600.0) + 1);

logic [17:0] timebase;       // Free-running time base
logic        reset_counter;  // Pulse to reset freq counter
logic        latch_output;   // Pulse to transfer count to output latch

initial begin
   timebase  = 18'b0;
end

always @(posedge clk) begin
   timebase      <= timebase + 18'b1;
   reset_counter <= ~|timebase;
   latch_output  <= &(timebase ~^ ETIME_CYCLES);
end

// 16x prescaler
logic [3:0] prescaler;
logic [3:0] prescaler_div2;

initial begin
   prescaler      = 4'b0;
   prescaler_div2 = 4'b0;
end

always @(posedge uclk) begin
   prescaler <= prescaler + 4'b1;
end

always @(posedge uclk_div2) begin
   prescaler_div2 <= prescaler_div2 + 4'b1;
end

// Sampler
logic smpclk;       // Sample clock
logic smpclk_edge;  // Edge, pulse
logic smpclk_meta, smpclk_meta_div2;
logic smpclk_dly;

always_ff @(posedge clk) begin
   smpclk_meta      <= prescaler[3];
   smpclk_meta_div2 <= prescaler_div2[3];

   smpclk           <= i_sel_uclk ? smpclk_meta : smpclk_meta_div2;
end

always_ff @(posedge clk) begin
   smpclk_dly  <= smpclk;
   smpclk_edge <= smpclk & ~smpclk_dly;
end

// Frequency counter
// Only 16 bits required, but adding 17th bit for overrange
logic [16:0] frequency;  // Frequency in 10 kHz units

always_ff @(posedge clk)begin
   if (reset_counter) begin
      frequency <= 17'b0;
   end else if (smpclk_edge) begin
      frequency <= frequency + 17'b1;
   end
end

// Output latch
logic        latched_freq_valid;
logic [16:0] latched_freq;           // Latched frequency

always_ff @(posedge clk) begin
   if (latch_output) begin
      latched_freq <= frequency;
   end
end

always_ff @(posedge clk) begin
   latched_freq_valid <= latch_output;
end

assign o_freq = latched_freq;
assign o_freq_valid = latched_freq_valid;

endmodule

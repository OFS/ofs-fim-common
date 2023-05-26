// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// Synchronizer for pulse crossing from fast to slow clock. Input pulse is
// longer than 1-clk in source clock domain
//
//-----------------------------------------------------------------------------

module pulse_sync  (
   input  logic       fast_clk,
   input  logic       fast_rst,
   input  logic       fast_pulse,
   input  logic       slow_clk,
   input  logic       slow_rst,
   output logic       slow_pulse
);

logic       rise_detect;
logic       fast_pulse_d;
logic       pulse_stretch;
logic [3:0] sync_bit; 


// ------------------------Events in Fast clock------------------------


always_ff @ (posedge fast_clk) begin
   fast_pulse_d <= fast_pulse;
end

// stretch till next pulse
assign rise_detect   = ~fast_pulse_d & fast_pulse;
assign pulse_stretch = rise_detect ^ sync_bit[0];

//first reg in fast clock
// sync[0] changes with change in pulse
always_ff @ (posedge fast_clk) begin
   if (fast_rst) begin
      sync_bit[0] <= 1'b0;
   end else begin
      sync_bit[0] <= pulse_stretch;
   end
end


// ------------------------Events in Slow clock------------------------

// Synchronize in slow clock
// sync[2] for meta, sync[3] for pulse gen
always_ff @ (posedge slow_clk) begin
   if (slow_rst) begin
      sync_bit[3:1] <= 3'b000;
   end else begin
      sync_bit[3:1] <= {sync_bit[2:1],sync_bit[0]};
   end
end

// Detect pulse
assign slow_pulse = sync_bit[3] ^ sync_bit[2];

endmodule

// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Generated by one of Gregg's toys.   Share And Enjoy.
// Executable compiled Sep 14 2017 14:08:19
// This file was generated 08/04/2020 17:24:39

// Compose a 12 way from two 6 ways

//   output is offset +48
module prio_enc_w12_t2_b48 #(
    parameter SIM_EMULATE = 1'b0
) (
    input clk,
    input [11:0] din,
    output [5:0] dout
);

wire [5:0] dout_w;
////////////////////////////////
// lower deck 0..5

wire [2:0] p0_dout;
prio_enc_w6_t1 #(
    .SIM_EMULATE(SIM_EMULATE)
) p0 (
    .clk(clk),
    .din(din[5:0]),
    .dout(p0_dout)
);


reg p0_empty;
always @(posedge clk) p0_empty <= ~|din[5:0];

////////////////////////////////
// upper deck 6..11

wire [3:0] p1_dout;
prio_enc_w6_t1_b6 #(
    .SIM_EMULATE(SIM_EMULATE)
) p1 (
    .clk(clk),
    .din(din[11:6]),
    .dout(p1_dout)
);

////////////////////////////////
// combine

assign dout_w = p0_empty ? p1_dout : {1'b0,p0_dout};

////////////////////////////////
// output latency from here is 1

reg [5:0] dout_r;
always @(posedge clk) dout_r <= dout_w[3:0] + 48;
assign dout = dout_r;

endmodule


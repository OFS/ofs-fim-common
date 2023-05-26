// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// n.b. Modified Gregg's 12:4 to 8:3

// Compose a 8 way from two 4 ways

//include "prio_enc_w4_t1.v"
//include "prio_enc_w4_t1_b4.v"

module prio_enc_w8_t2 #(
    parameter SIM_EMULATE = 1'b0
) (
    input  clk,
    input  [7:0] din,
    output [3:0] dout
);

wire [3:0] dout_w;
////////////////////////////////
// lower deck 0..4

wire [2:0] p0_dout;
prio_enc_w4_t1 #(
    .SIM_EMULATE(SIM_EMULATE)
) p0 (
    .clk(clk),
    .din(din[3:0]),
    .dout(p0_dout)
);


reg p0_empty;
always @(posedge clk) p0_empty <= ~|din[3:0];

////////////////////////////////
// upper deck 4..7

wire [3:0] p1_dout;
prio_enc_w4_t1_b4 #(
    .SIM_EMULATE(SIM_EMULATE)
) p1 (
    .clk(clk),
    .din(din[7:4]),
    .dout(p1_dout)
);

////////////////////////////////
// combine

assign dout_w = p0_empty ? p1_dout : {1'b0, p0_dout};

////////////////////////////////
// output latency from here is 1

reg [3:0] dout_r;
always @(posedge clk) dout_r <= dout_w;
assign dout = dout_r;

endmodule


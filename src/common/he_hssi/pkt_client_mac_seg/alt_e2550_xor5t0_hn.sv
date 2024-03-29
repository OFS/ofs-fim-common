// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT




`timescale 1ps/1ps

// DESCRIPTION
// 5 input XOR gate.  Latency 0.
// Generated by one of Gregg's toys.   Share And Enjoy.

module alt_e2550_xor5t0_hn #(
    //parameter SIM_EMULATE = 1'b0
) (
    input [4:0] din,
    output dout
);

alt_e2550_lut6_hn #(.MASK (64'h6996966996696996)) t0 (.din({1'b0,din}),.dout(dout));
//defparam t0 .SIM_EMULATE = SIM_EMULATE;
//defparam t0 .MASK = 64'h6996966996696996;

endmodule


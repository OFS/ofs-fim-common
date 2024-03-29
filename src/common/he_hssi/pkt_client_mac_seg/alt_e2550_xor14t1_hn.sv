// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


// Copyright 2014 Altera Corporation. All rights reserved.
// Altera products are protected under numerous U.S. and foreign patents, 
// maskwork rights, copyrights and other intellectual property laws.  
//
// This reference design file, and your use thereof, is subject to and governed
// by the terms and conditions of the applicable Altera Reference Design 
// License Agreement (either as signed by you or found at www.altera.com).  By
// using this reference design file, you indicate your acceptance of such terms
// and conditions between you and Altera Corporation.  In the event that you do
// not agree with such terms and conditions, you may not use the reference 
// design file and please promptly destroy any copies you have made.
//
// This reference design file is being provided on an "as-is" basis and as an 
// accommodation and therefore all warranties, representations or guarantees of 
// any kind (whether express, implied or statutory) including, without 
// limitation, warranties of merchantability, non-infringement, or fitness for
// a particular purpose, are specifically disclaimed.  By making this reference
// design file available, Altera expressly does not recommend, suggest or 
// require that this reference design file be used in combination with any 
// other product not provided by Altera.
/////////////////////////////////////////////////////////////////////////////


`timescale 1ps/1ps

// DESCRIPTION
// 14 input XOR gate.  Latency 1.
// Generated by one of Gregg's toys.   Share And Enjoy.

module alt_e2550_xor14t1_hn #(
//    parameter SIM_EMULATE = 1'b0
) (
    input clk,
    input [13:0] din,
    output dout
);

wire [2:0] leaf;

alt_e2550_xor5t1_hn c0 (
    .clk(clk),
    .din(din[4:0]),
    .dout(leaf[0])
);
//defparam c0 .SIM_EMULATE = SIM_EMULATE;

alt_e2550_xor5t1_hn c1 (
    .clk(clk),
    .din(din[9:5]),
    .dout(leaf[1])
);
//defparam c1 .SIM_EMULATE = SIM_EMULATE;

alt_e2550_xor4t1_hn c2 (
    .clk(clk),
    .din(din[13:10]),
    .dout(leaf[2])
);
//defparam c2 .SIM_EMULATE = SIM_EMULATE;

alt_e2550_xor3t0_hn c3 (
    .din(leaf),
    .dout(dout)
);
//defparam c3 .SIM_EMULATE = SIM_EMULATE;

endmodule


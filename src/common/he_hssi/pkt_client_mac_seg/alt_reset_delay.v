// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`timescale 1 ps / 1 ps
// baeckler - 12-17-2009

// when not ready_in - immediately not ready_out
// when ready_in - wait for counter, then ready out synchronously

// DESCRIPTION
// 
// This is a more elaborate version of aclr_filter, typically used for bringing up SERDES pins or PLLs. When
// the input ready condition is not met the output is immediately driven to not ready. When the input
// ready becomes true the output will become ready after a programmable delay.
// 



// CONFIDENCE
// This is used very liberally in Altera test and demo designs
// 

module alt_reset_delay #(
    parameter CNTR_BITS = 16
)
(
    input clk,
    input ready_in,
    output ready_out
);

reg [2:0] rs_meta /* synthesis preserve dont_replicate */
/* synthesis ALTERA_ATTRIBUTE = "-name SDC_STATEMENT \"set_false_path -from [get_fanins -async *reset_delay*rs_meta\[*\]] -to [get_keepers *reset_delay*rs_meta\[*\]]\" " */;

always @(posedge clk or negedge ready_in) begin
    if (!ready_in) rs_meta <= 3'b000;
    else rs_meta <= {rs_meta[1:0],1'b1};
end
wire ready_sync = rs_meta[2];

reg [CNTR_BITS-1:0] cntr /* synthesis preserve */;
assign ready_out = cntr[CNTR_BITS-1];
always @(posedge clk or negedge ready_sync) begin
    if (!ready_sync) cntr <= {CNTR_BITS{1'b0}};
    else if (!ready_out) cntr <= cntr + 1'b1;
end

endmodule

// BENCHMARK INFO :  10AX115U2F45I2SGE2
// BENCHMARK INFO :  Quartus Prime Version 15.1.0 Internal Build 99 06/10/2015 TO Standard Edition
// BENCHMARK INFO :  Uses helper file :  alt_reset_delay.v
// BENCHMARK INFO :  Max depth :  3.4 LUTs
// BENCHMARK INFO :  Total registers : 19
// BENCHMARK INFO :  Total pins : 3
// BENCHMARK INFO :  Total virtual pins : 0
// BENCHMARK INFO :  Total block memory bits : 0
// BENCHMARK INFO :  Comb ALUTs :  17                 
// BENCHMARK INFO :  ALMs : 9 / 427,200 ( < 1 % )
// BENCHMARK INFO :  Worst setup path @ 468.75MHz : 0.796 ns, From cntr[15], To ready_out}

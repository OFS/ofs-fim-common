// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`timescale 1 ps / 1 ps

module alt_aeuex_user_mode_det (
    input ref_clk,
    output user_mode_sync);

    reg user_mode = 1'b0 /* synthesis preserve_syn_only */;

    always @(posedge ref_clk)
    begin
        user_mode <= 1'b1;
    end

    reg [7:0] user_mode_counter = 8'h00 /* synthesis preserve_syn_only */;
	 always @(posedge ref_clk)
    begin
        if (user_mode && ! user_mode_counter[7]) 
            user_mode_counter <= user_mode_counter + 1'b1;
    end
    assign user_mode_sync = user_mode_counter[7];

endmodule

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

reg [2:0] rs_meta = 3'b0 /* synthesis preserve dont_replicate */
/* synthesis ALTERA_ATTRIBUTE = "-name SDC_STATEMENT \"set_false_path -from [get_fanins -async *reset_delay*rs_meta\[*\]] -to [get_keepers *reset_delay*rs_meta\[*\]]\" " */;

always @(posedge clk or negedge ready_in) begin
	if (!ready_in) rs_meta <= 3'b000;
	else rs_meta <= {rs_meta[1:0],1'b1};
end
wire ready_sync = rs_meta[2];

reg [CNTR_BITS-1:0] cntr = {CNTR_BITS{1'b0}} /* synthesis preserve */;
assign ready_out = cntr[CNTR_BITS-1];
always @(posedge clk or negedge ready_sync) begin
	if (!ready_sync) cntr <= {CNTR_BITS{1'b0}};
	else if (!ready_out) cntr <= cntr + 1'b1;
end

endmodule

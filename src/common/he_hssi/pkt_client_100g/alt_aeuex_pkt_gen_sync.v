// Copyright (C) 2001-2021 Intel Corporation
// SPDX-License-Identifier: MIT

//-------------------------------------------------
module alt_aeuex_pkt_gen_sync #(
        parameter WIDTH = 32
)(
        input clk,
        input [WIDTH-1:0] din,
        output [WIDTH-1:0] dout
);

reg [WIDTH-1:0] sync_0 = 0 /* synthesis preserve_syn_only */;
reg [WIDTH-1:0] sync_1 = 0 /* synthesis preserve_syn_only */;

always @(posedge clk) begin
        sync_0 <= din;
        sync_1 <= sync_0;
end
assign dout = sync_1;

endmodule

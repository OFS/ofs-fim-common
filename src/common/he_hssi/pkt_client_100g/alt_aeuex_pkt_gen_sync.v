// (C) 2001-2021 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


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

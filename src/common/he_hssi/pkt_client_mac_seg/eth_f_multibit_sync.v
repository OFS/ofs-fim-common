// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`timescale 1 ps / 1 ps
// baeckler - 01-20-2010
// weak meta hardening intended for low toggle rate / low priority status signals

module eth_f_multibit_sync #(
	parameter WIDTH = 32
)(
	input clk,
	input reset_n,
	input [WIDTH-1:0] din,
	output [WIDTH-1:0] dout
);

generate
genvar i;
for (i=0; i<WIDTH; i=i+1)
begin : sync
           eth_f_altera_std_synchronizer_nocut #(
                .depth(3),
                .rst_value({WIDTH{1'b0}})
            )  synchronizer_nocut_inst  (
                .clk(clk),
                .reset_n(reset_n),
                .din(din[i]),
                .dout(dout[i])
            );
end
endgenerate

endmodule

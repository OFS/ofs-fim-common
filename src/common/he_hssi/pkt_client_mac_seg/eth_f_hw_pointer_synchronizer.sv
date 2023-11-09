// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


module eth_f_hw_pointer_synchronizer #(
    parameter WIDTH = 8
) (
    input              input_clk,
    input  [WIDTH-1:0] input_ptr,

    input              output_clk,
    output [WIDTH-1:0] output_ptr
);
    wire [WIDTH-1:0] input_ptr_gray;
    eth_f_hw_bin_to_gray_reg #(
        .WIDTH      (WIDTH)
    ) b2g_input_ptr (
        .clk        (input_clk),
        .bin_value  (input_ptr),
        .gray_value (input_ptr_gray)
    );

    wire [WIDTH-1:0] input_ptr_gray_sync;
    eth_f_hw_delay_reg #(
        .CYCLES (3),
        .WIDTH  (WIDTH)
    ) ptr_sync (
        .clk    (output_clk),
        .din    (input_ptr_gray),
        .dout   (input_ptr_gray_sync)
    );

    eth_f_hw_gray_to_bin_reg #(
        .WIDTH  (WIDTH)
    ) g2b_output_ptr (
        .clk        (output_clk),
        .gray_value (input_ptr_gray_sync),
        .bin_value  (output_ptr)
    );
endmodule

module eth_f_hw_bin_to_gray_reg #(
    parameter WIDTH = 8
) (
    input                   clk,
    input      [WIDTH-1:0]  bin_value,
    output reg [WIDTH-1:0]  gray_value
);
    genvar i;
    generate
        for (i = 0; i < (WIDTH-1); i=i+1) begin : bit_loop
            always @(posedge clk) gray_value[i] <= bin_value[i] ^ bin_value[i+1];
        end
        always @(posedge clk) gray_value[WIDTH-1] <= bin_value[WIDTH-1];
    endgenerate
endmodule

module eth_f_hw_gray_to_bin_reg #(
    parameter WIDTH = 8
) (
    input                   clk,
    input      [WIDTH-1:0]  gray_value,
    output reg [WIDTH-1:0]  bin_value
);
    genvar i;
    generate
        for (i = 0; i < WIDTH; i=i+1) begin : bit_loop
            always @(posedge clk) bin_value[i] <= ^gray_value[(WIDTH-1):i];
        end
    endgenerate
endmodule

module eth_f_hw_delay_reg #(
    parameter CYCLES = 3,
    parameter WIDTH = 1
) (
    input              clk,
    input  [WIDTH-1:0] din,
    output [WIDTH-1:0] dout
);

    genvar i;
    generate
        for (i = 0; i < WIDTH; i=i+1) begin : bit_loop
            eth_f_hw_delay_reg_1b #(
                .DEPTH  (CYCLES)
            ) sync (
                .clk    (clk),
                .din    (din[i]),
                .dout   (dout[i])
            );
        end
    endgenerate
endmodule

module eth_f_hw_delay_reg_1b #(
    parameter DEPTH = 3
) (
    input  clk,
    input  din,
    output dout
);

    reg [DEPTH-1:0] mem;
    always @(posedge clk) begin
        mem <= {mem[DEPTH-2:0], din};
    end

    assign dout = mem[DEPTH-1];
endmodule


// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


module eth_f_pointer_synchronizer #(
    parameter WIDTH = 16
) (
    input   logic               clk_in,
    input   logic   [WIDTH-1:0] ptr_in,
    input   logic               clk_out,
    output  logic   [WIDTH-1:0] ptr_out
);

    logic [WIDTH-1:0] ptr_gray;
    logic [WIDTH-1:0] ptr_gray_reg;

    logic [WIDTH-1:0] ptr_gray_s1;
    logic [WIDTH-1:0] ptr_gray_s2;
    logic [WIDTH-1:0] ptr_gray_sync;

    logic [WIDTH-1:0] ptr_out_wire;

    eth_f_bin_to_gray #(
        .WIDTH      (WIDTH)
    ) b2g (
        .bin_value  (ptr_in),
        .gray_value (ptr_gray)
    );

    always_ff @(posedge clk_in) begin
        ptr_gray_reg    <= ptr_gray;
    end

    always_ff @(posedge clk_out) begin
        ptr_gray_s1   <= ptr_gray_reg;
        ptr_gray_s2   <= ptr_gray_s1;
        ptr_gray_sync <= ptr_gray_s2;
    end

    eth_f_gray_to_bin #(
        .WIDTH      (WIDTH)
    ) g2b_read (
        .gray_value (ptr_gray_sync),
        .bin_value  (ptr_out_wire)
    );

    always_ff @(posedge clk_out) begin
        ptr_out <= ptr_out_wire;
    end
endmodule

module eth_f_gray_to_bin #(
    parameter WIDTH = 8
) (
    input  logic    [WIDTH-1:0] gray_value,
    output logic    [WIDTH-1:0] bin_value
);

    genvar i;
    generate
        for (i = 0; i < WIDTH; i++) begin : bit_loop
            assign bin_value[i] = ^gray_value[(WIDTH-1):i];
        end
    endgenerate
endmodule

module eth_f_bin_to_gray #(
    parameter WIDTH = 8
) (
    input  logic [WIDTH-1:0] bin_value,
    output logic [WIDTH-1:0] gray_value
);

    genvar i;
    generate
        for (i = 0; i < (WIDTH-1); i++) begin : bit_loop
            assign gray_value[i] = bin_value[i] ^ bin_value[i+1];
        end
        assign gray_value[WIDTH-1] = bin_value[WIDTH-1];
    endgenerate
endmodule


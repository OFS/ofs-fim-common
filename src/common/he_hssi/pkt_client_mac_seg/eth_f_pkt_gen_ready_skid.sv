// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


module eth_f_pkt_gen_ready_skid #(
    parameter WIDTH = 8
) (
    input   logic               i_clk,
    input   logic               i_ready,
    input   logic   [WIDTH-1:0] i_data,
    output  logic               o_ready,
    output  logic   [WIDTH-1:0] o_data
);
    logic   [WIDTH-1:0] temp;

    always_ff @(posedge i_clk) begin
        o_ready     <= i_ready;

        if (o_ready) begin
            temp        <= i_data;
        end else begin
            temp        <= temp;
        end

        if (i_ready) begin
            if (o_ready) begin
                o_data      <= i_data;
            end else begin
                o_data      <= temp;
            end
        end else begin
            o_data      <= o_data;
        end
    end
endmodule


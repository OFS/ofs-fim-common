// Copyright (C) 2001-2021 Intel Corporation
// SPDX-License-Identifier: MIT

module alt_e100s10_ready_skid #(
    parameter WIDTH = 8
) (
    input   logic               i_clk,
    input   logic               i_rst,
    input   logic               i_ready,
    input   logic   [WIDTH-1:0] i_data,
    output  logic               o_ready,
    output  logic   [WIDTH-1:0] o_data
);
    logic   [WIDTH-1:0] temp;

    always_ff @(posedge i_clk) begin
      o_ready     <= i_ready;
      
      if (i_rst) begin
         temp      <= 'b0;
      end
      else begin
         if (o_ready) begin
            temp        <= i_data;
         end else begin
            temp        <= temp;
         end
      end
      if (i_rst) begin
         o_data      <= 'b0;
      end
      else begin
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
    end
endmodule


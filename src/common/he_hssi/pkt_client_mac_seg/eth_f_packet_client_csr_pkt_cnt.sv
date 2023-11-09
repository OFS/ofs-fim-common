// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`timescale 1 ps / 1 ps

module eth_f_packet_client_csr_pkt_cnt(
        input  logic                  clk,
        input  logic                  rst,

        //---stat interface---
        input  logic                  cnt_clr,
        input  logic                  cnt_in_vld,
        input  logic [7:0]            cnt_in,
        output logic [63:0]           cnt_out
);

logic [7:0]       cnt_sync;
logic [55:0]      cnt_high;
logic             cnt_b7_r, cnt_b7_r2, cnt_in_overflow;
logic             cnt_clr_r;

//---------------------------------------------
logic    cnt_vld_sync, cnt_vld_r, cnt_vld_r2, cnt_vld;
always @(posedge clk) begin
    if (rst) begin
        cnt_vld_sync <= 1'b0;
        cnt_vld_r    <= 1'b0;
        cnt_vld_r2   <= 1'b0;
    end else begin
        cnt_vld_sync <= cnt_in_vld;
        cnt_vld_r    <= cnt_vld_sync;
        cnt_vld_r2   <= cnt_vld_r;
    end
end
assign cnt_vld = cnt_vld_r & !cnt_vld_r2;

//---------------------------------------------
always @(posedge clk)     cnt_clr_r <= cnt_clr;
always @(posedge clk) begin
    if (rst | cnt_clr | cnt_clr_r) begin
        cnt_sync   <= 8'b0;
    end else if (cnt_vld) begin
        cnt_sync   <= cnt_in;
    end
end

assign cnt_in_overflow = cnt_sync[7] & !cnt_in[7];
assign cnt_out = {cnt_high, cnt_sync};

always @ (posedge clk) begin
    if (rst | cnt_clr | cnt_clr_r) begin
        cnt_high <= 0;
    end else if (cnt_vld & cnt_in_overflow) begin
        cnt_high <= cnt_high + 1'b1;
    end
end

//---------------------------------------------
endmodule

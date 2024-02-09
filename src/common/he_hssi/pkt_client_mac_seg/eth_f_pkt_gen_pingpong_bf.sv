// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`timescale 1 ps / 1 ps

module eth_f_pkt_gen_pingpong_bf #(
        parameter WIDTH = 32   
    )(
        input  logic        clk,
        input  logic        rst,

        input  logic                 wr,
        input  logic [WIDTH-1:0]     wdata,
        input  logic                 rd,
        output logic [WIDTH-1:0]     rdata,
        output logic                 full,
        output logic                 empty
);

logic [1:0] bf_cnt;
always @ (posedge clk) begin
    if (rst) begin
            bf_cnt <= 2'b0;
            full   <= 1'b0;
            empty  <= 1'b1;
    end else if (wr & !rd) begin
            bf_cnt <= bf_cnt + 1'b1;
            full   <= (bf_cnt >= 1);
            empty  <= 1'b0;
    end else if (!wr & rd) begin
            bf_cnt <= bf_cnt - 1'b1;
            full   <= 1'b0;
            empty  <= (bf_cnt <= 1);
    end
end
//assign full  = (bf_cnt==2'h2);
//assign empty = (bf_cnt==2'h0);

logic bf_wptr, bf_rptr;
always @ (posedge clk) begin
    if (rst) begin
            bf_wptr <= 0;
    end else if (wr) begin
            bf_wptr <= !bf_wptr;
    end
end
always @ (posedge clk) begin
    if (rst) begin
            bf_rptr <= 0;
    end else if (rd) begin
            bf_rptr <= !bf_rptr;
    end
end

logic [WIDTH-1:0]    bf0, bf1;
always @ (posedge clk) begin
    if (rst) begin
        bf0 <= 0;
        bf1 <= 0;
    end else if (wr) begin
        if (bf_wptr==0) bf0 <= wdata;
        if (bf_wptr==1) bf1 <= wdata;
    end
end 

assign rdata = (bf_rptr==0) ? bf0 : bf1;
//always @ (posedge clk) begin
//    if (rd)    rdata <= (bf_rptr==0) ? bf0 : bf1;
//end

endmodule

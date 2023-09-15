// Copyright (C) 2001-2021 Intel Corporation
// SPDX-License-Identifier: MIT

`include "fpga_defines.vh"

module alt_e100s10_data_block_buffer #(
    parameter WIDTH         = 8,
    parameter SIM_EMULATE   = 0
) (
    input   logic               i_reset,
    input   logic               i_clk,

    input   logic               i_eop,
    input   logic               i_valid,
    input   logic   [WIDTH-1:0] i_data,

    output  logic   [WIDTH-1:0] o_data,
    output  logic               o_valid,
    input   logic               i_ready
);

    enum logic {STOPPED, SENDING} mode;

    logic   [4:0]   wptr;
    logic   [4:0]   rptr;
    logic   [4:0]   eptr;
    logic           e_stored;

    logic   [4:0]   used;
    logic           partial_full;
    logic           eop_out;

    logic   [WIDTH-1:0] read_data;

    assign used         = wptr - rptr;
    assign partial_full = (used >= 5'd16);
    assign eop_out      = (eptr == rptr);

    always_ff @(posedge i_clk) begin
        if (i_reset) begin
            eptr    <= 5'd0;
        end else begin
            if (i_valid && i_eop) begin
                eptr <= wptr;
            end else begin
                eptr <= eptr;
            end
        end
    end

    always_ff @(posedge i_clk) begin
        if (i_reset) begin
            rptr    <= 5'd0;
            o_valid <= 1'b0;
        end else begin
            if ((mode == SENDING) && i_ready) begin
                rptr    <= rptr + 1'b1;
                o_valid <= 1'b1;
            end else begin
                rptr    <= rptr;
                o_valid <= 1'b0;
            end
        end
    end

    always_ff @(posedge i_clk) begin
        if (i_reset) begin
            mode    <= STOPPED;
        end else begin
            if (partial_full || (i_eop && i_valid)) begin
                mode    <= SENDING;
            end else if (eop_out && e_stored && i_ready && !partial_full) begin
                mode    <= STOPPED;
            end else begin
                mode    <= mode;
            end
        end
    end

    always_ff @(posedge i_clk) begin
        if (i_reset) begin
            e_stored <= 1'b0;
        end else begin
            if (i_eop && i_valid) begin
                e_stored <= 1'b1;
            end else if (i_ready && eop_out && (mode == SENDING)) begin
                e_stored <= 1'b0;
            end else begin
                e_stored <= e_stored;
            end
        end
    end

    always_ff @(posedge i_clk) begin
        if (i_reset) begin
            wptr    <= 5'd0;
        end else begin
            wptr    <= i_valid ? wptr + 1'b1 : wptr;
        end
    end

generate
if(`FAMILY == "Stratix 10") begin 
    alt_e100s10_mlab  #(
        .WIDTH      (WIDTH),
        .ADDR_WIDTH (5),
        .SIM_EMULATE(SIM_EMULATE)
    ) mem0 (
        .wclk       (i_clk),
        .wdata_reg  (i_data),
        .wena       (i_valid),
        .waddr_reg  (wptr),
        .raddr      (rptr),
        .rdata      (read_data)
    );
end
else begin 
    alt_ehipc3_fm_mlab #(
        .WIDTH      (WIDTH),
        .ADDR_WIDTH (5),
        .SIM_EMULATE(SIM_EMULATE)
    ) mem0 (
        .wclk       (i_clk),
        .wdata_reg  (i_data),
        .wena       (i_valid),
        .waddr_reg  (wptr),
        .raddr      (rptr),
        .rdata      (read_data)
    );
end 
endgenerate 

    always_ff @(posedge i_clk) begin
        o_data  <= read_data;
    end
endmodule

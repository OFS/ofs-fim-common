// Copyright (C) 2001-2021 Intel Corporation
// SPDX-License-Identifier: MIT

`include "fpga_defines.vh"

module alt_e100s10_loopback_client #(
    parameter SIM_EMULATE   = 0
) (
    input   logic                       i_arst,

    input   logic                       i_clk_w,
    input   logic                       i_sop,
    input   logic                       i_eop,
    input   logic                       i_valid,
    input   logic   [6-1:0]             i_empty,
    input   logic   [512-1:0]           i_data,

    input   logic                       i_clk_r,
    output  logic                       o_sop,
    output  logic                       o_eop,
    output  logic                       o_valid,
    output  logic   [6-1:0]             o_empty,
    output  logic   [512-1:0]           o_data,
    input   logic                       i_ready
);
    localparam MEM_WIDTH    = 512 + 6 + 1 + 1;

    logic                       r_reset;

    logic   [MEM_WIDTH-1:0]     dcfifo_write_data;
    logic   [MEM_WIDTH-1:0]     dcfifo_read_data;
    logic   [0:7]               dcfifo_valid;

    logic   [512-1:0]           int_data;
    logic   [6-1:0]             int_empty;
    logic                       int_sop;
    logic                       int_eop;
    logic                       int_valid;

    assign dcfifo_write_data    = {i_sop, i_eop, i_empty, i_data};

    always_ff @(posedge i_clk_r) begin
    end

    generate
    if(`FAMILY == "Stratix 10" ) begin 
        alt_e100s10_reset_synchronizer  reset_sync_read (
           .clk   (i_clk_r),
           .aclr      (i_arst),
           .aclr_sync (r_reset)
        );
    end
    else begin
        fim_resync #( 
            .INIT_VALUE            (1),
            .SYNC_CHAIN_LENGTH     (3),
            .TURN_OFF_ADD_PIPELINE (0)
        ) reset_sync_read (
            .clk   (i_clk_r),
            .reset (i_arst),
            .d     (1'b0),
            .q     (r_reset)
        );
    end
   endgenerate

    alt_e100s10_data_synchronizer #(
        .SIM_EMULATE    (SIM_EMULATE)
    ) ds (
        .i_arst     (i_arst),
        .i_clk_w    (i_clk_w),
        .i_data     (dcfifo_write_data),
        .i_valid    (i_valid),
        .i_clk_r    (i_clk_r),
        .o_data     (dcfifo_read_data),
        .o_valid    (dcfifo_valid)
    );
    assign int_valid = dcfifo_valid[0];

    assign {int_sop, int_eop, int_empty, int_data} = dcfifo_read_data;

    alt_e100s10_frame_buffer #(
        .DATA_WIDTH     (512),
        .EMPTY_WIDTH    (6),
        .SIM_EMULATE    (SIM_EMULATE)
    ) sync_buffer (
        .i_clk          (i_clk_r),
        .i_reset        (r_reset),
        .i_sop          (int_sop),
        .i_eop          (int_eop),
        .i_valid        (int_valid),
        .i_empty        (int_empty),
        .i_data         (int_data),
        .o_sop          (o_sop),
        .o_eop          (o_eop),
        .o_valid        (o_valid),
        .o_empty        (o_empty),
        .o_data         (o_data),
        .i_ready        (i_ready)
    );
endmodule

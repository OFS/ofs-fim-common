// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


module eth_f_data_synchronizer #(
    parameter DATA_BCNT   = 0,
    parameter CTRL_BCNT   = 0,
    parameter FIFO_ADDR_WIDTH  = 6,
    parameter SIM_EMULATE = 0
) (
    input   logic                   i_arst,

    input   logic                   i_clk_w,
    input   logic [0:CTRL_BCNT*8-1] i_ctrl,
    input   logic [0:DATA_BCNT*8-1] i_data,
    input   logic                   i_valid,

    input   logic                   i_clk_r,
    input   logic                   i_read_req,
    output  logic [0:DATA_BCNT*8-1] o_data,
    output  logic [0:CTRL_BCNT*8-1] o_ctrl,
    output  logic [0:7]             o_valid
);

    logic           w_reset;
    logic           r_reset;
    logic   [0:8]   w_reset_reg;    /* synthesis dont_merge */

    eth_f_reset_synchronizer rsw (
        .clk        (i_clk_w),
        .aclr       (i_arst),
        .aclr_sync  (w_reset)
    );

    eth_f_reset_synchronizer rsr (
        .clk        (i_clk_r),
        .aclr       (i_arst),
        .aclr_sync  (r_reset)
    );

    logic   [0:DATA_BCNT*8-1] i_data_reg;
    logic   [0:CTRL_BCNT*8-1] i_ctrl_reg;
    logic   [0:8]             i_valid_reg;    /* synthesis dont_merge */
    logic   [0:7]             i_read_req_reg;    /* synthesis dont_merge */

    logic   [0:DATA_BCNT*8-1] read_data;
    logic   [0:CTRL_BCNT*8-1] read_ctrl;
    



    always_ff @(posedge i_clk_w) begin
        i_data_reg  <= i_data;
        i_ctrl_reg  <= i_ctrl;
    end


    logic   [FIFO_ADDR_WIDTH-1:0]   wptr            [0:8];  /* synthesis dont_merge */
    logic   [FIFO_ADDR_WIDTH-1:0]   wptr_sync_reg   [0:7];  /* synthesis dont_merge */
    logic   [FIFO_ADDR_WIDTH-1:0]   wptr_sync;
    logic   [FIFO_ADDR_WIDTH-1:0]   rptr            [0:7];  /* synthesis dont_merge */

    eth_f_pointer_synchronizer #(
        .WIDTH  (FIFO_ADDR_WIDTH)
    ) ps (
        .clk_in     (i_clk_w),
        .ptr_in     (wptr[8]),
        .clk_out    (i_clk_r),
        .ptr_out    (wptr_sync)
    );

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin : rptr_loop

            always_ff @(posedge i_clk_r) begin
                wptr_sync_reg[i]    <= wptr_sync;
                i_read_req_reg[i]   <= i_read_req;

                if (r_reset) begin
                    rptr[i] <= {FIFO_ADDR_WIDTH{1'b0}};
                    o_valid[i]  <= 1'b0;
                end else begin
                    if ((rptr[i] === wptr_sync_reg[i]) || (i_read_req_reg[i] === 1'b0)) begin
                        rptr[i] <= rptr[i];
                        o_valid[i]  <= 1'b0;
                    end else begin
                        rptr[i] <= rptr[i] + 1'd1;
                        o_valid[i]  <= 1'b1;
                    end
                end
            end

            eth_f_mlab #(
                .WIDTH      (DATA_BCNT),
                .ADDR_WIDTH (FIFO_ADDR_WIDTH),
                .SIM_EMULATE(SIM_EMULATE)
            ) mem_data (
                .wclk       (i_clk_w),
                .wdata_reg  (i_data_reg[DATA_BCNT*i+:DATA_BCNT]),
                .wena       (1'b1),
                .waddr_reg  (wptr[i]),
                .raddr      (rptr[i]),
                .rdata      (read_data[DATA_BCNT*i+:DATA_BCNT])
            );

            eth_f_mlab #(
                .WIDTH      (CTRL_BCNT),
                .ADDR_WIDTH (FIFO_ADDR_WIDTH),
                .SIM_EMULATE(SIM_EMULATE)
            ) mem_ctrl (
                .wclk       (i_clk_w),
                .wdata_reg  (i_ctrl_reg[CTRL_BCNT*i+:CTRL_BCNT]),
                .wena       (1'b1),
                .waddr_reg  (wptr[i]),
                .raddr      (rptr[i]),
                .rdata      (read_ctrl[CTRL_BCNT*i+:CTRL_BCNT])
            );
        end

        always_ff @(posedge i_clk_r) begin
            o_data <= read_data;
            o_ctrl <= read_ctrl;
        end

        for (i = 0; i < 9; i++) begin : wptr_loop
            always_ff @(posedge i_clk_w) begin
                w_reset_reg[i]  <= w_reset;
                i_valid_reg[i]  <= i_valid;

                if (w_reset_reg[i]) begin
                    wptr[i] <= {FIFO_ADDR_WIDTH{1'b0}};
                end else begin
                    if (i_valid_reg[i]) begin
                        wptr[i] <= wptr[i] + 1'd1;
                    end else begin
                        wptr[i] <= wptr[i];
                    end
                end
            end
        end
    endgenerate

endmodule

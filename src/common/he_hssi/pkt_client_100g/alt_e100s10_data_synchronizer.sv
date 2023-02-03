// (C) 2001-2021 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.
`include "fpga_defines.vh"

module alt_e100s10_data_synchronizer #(
    parameter SIM_EMULATE = 0
) (
    input   logic           i_arst,

    input   logic           i_clk_w,
    input   logic   [0:519] i_data,
    input   logic           i_valid,

    input   logic           i_clk_r,
    output  logic   [0:519] o_data,
    output  logic   [0:7]   o_valid
);

    logic           w_reset;
    logic           r_reset;
    logic   [0:8]   w_reset_reg;    /* synthesis dont_merge */

generate 
if(`FAMILY == "Stratix 10") begin 
    alt_e100s10_reset_synchronizer rsw (
        .clk        (i_clk_w),
        .aclr       (i_arst),
        .aclr_sync  (w_reset)
    );
end
else   begin    
    alt_ehipc3_fm_reset_synchronizer rsw (
        .clk        (i_clk_w),
        .aclr       (i_arst),
        .aclr_sync  (w_reset)
    );
end
endgenerate

generate
if(`FAMILY == "Stratix 10") begin 
    alt_e100s10_reset_synchronizer  rsr (
        .clk        (i_clk_r),
        .aclr       (i_arst),
        .aclr_sync  (r_reset)
    );
end
else begin 
    alt_ehipc3_fm_reset_synchronizer rsr (
        .clk        (i_clk_r),
        .aclr       (i_arst),
        .aclr_sync  (r_reset)
    );
end
endgenerate

    logic   [0:519] i_data_reg;
    logic   [0:8]   i_valid_reg;    /* synthesis dont_merge */

    always_ff @(posedge i_clk_w) begin
        i_data_reg  <= i_data;
    end

    logic   [4:0]   wptr            [0:8];  /* synthesis dont_merge */
    logic   [4:0]   wptr_sync_reg   [0:7];  /* synthesis dont_merge */
    logic   [4:0]   wptr_sync;
    logic   [4:0]   rptr            [0:7];  /* synthesis dont_merge */

    logic   [0:519] read_data;

    alt_e100s10_pointer_synchronizer #(
        .WIDTH  (5)
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

                if (r_reset) begin
                    rptr[i] <= 5'd0;
                    o_valid[i]  <= 1'b0;
                end else begin
                    if (rptr[i] === wptr_sync_reg[i]) begin
                        rptr[i] <= rptr[i];
                        o_valid[i]  <= 1'b0;
                    end else begin
                        rptr[i] <= rptr[i] + 1'd1;
                        o_valid[i]  <= 1'b1;
                    end
                end
            end

if(`FAMILY == "Stratix 10") begin
            alt_e100s10_mlab  #(
                .WIDTH      (65),
                .ADDR_WIDTH (5),
                .SIM_EMULATE(SIM_EMULATE)
            ) mem (
                .wclk       (i_clk_w),
                .wdata_reg  (i_data_reg[65*i+:65]),
                .wena       (1'b1),
                .waddr_reg  (wptr[i]),
                .raddr      (rptr[i]),
                .rdata      (read_data[65*i+:65])
            );
end
else begin
            alt_ehipc3_fm_mlab  #(
                .WIDTH      (65),
                .ADDR_WIDTH (5),
                .SIM_EMULATE(SIM_EMULATE)
            ) mem (
                .wclk       (i_clk_w),
                .wdata_reg  (i_data_reg[65*i+:65]),
                .wena       (1'b1),
                .waddr_reg  (wptr[i]),
                .raddr      (rptr[i]),
                .rdata      (read_data[65*i+:65])
            );
end
end

        always_ff @(posedge i_clk_r) begin
            o_data <= read_data;
        end

        for (i = 0; i < 9; i++) begin : wptr_loop
            always_ff @(posedge i_clk_w) begin
                w_reset_reg[i]  <= w_reset;
                i_valid_reg[i]  <= i_valid;

                if (w_reset_reg[i]) begin
                    wptr[i] <= 5'd0;
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

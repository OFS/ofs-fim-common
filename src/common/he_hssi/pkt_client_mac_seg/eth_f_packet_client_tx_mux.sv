// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`timescale 1 ps / 1 ps

module eth_f_packet_client_tx_mux #(
        parameter DATA_BCNT     = 8,
        parameter CTRL_BCNT     = 2
    )(
        input   logic                       i_clk_tx,
        input   logic                       i_rst,
        input   logic                       cfg_m0_select,

        //---Master 0 interface---
        output logic                        m0_tx_req,
        input  logic                        m0_tx_data_vld,
        input  logic [DATA_BCNT*8-1:0]      m0_tx_data,
        input  logic [CTRL_BCNT*8-1:0]      m0_tx_ctrl,

        //---Master 1 interface---
        output logic                        m1_tx_req,
        input  logic                        m1_tx_data_vld,
        input  logic [DATA_BCNT*8-1:0]      m1_tx_data,
        input  logic [CTRL_BCNT*8-1:0]      m1_tx_ctrl,

        //---Output interface---
        input  logic                        i_tx_req,
        output logic                        o_tx_data_vld,
        output logic [DATA_BCNT*8-1:0]      o_tx_data,
        output logic [CTRL_BCNT*8-1:0]      o_tx_ctrl
);

assign m0_tx_req =  cfg_m0_select & i_tx_req;
assign m1_tx_req = !cfg_m0_select & i_tx_req;

//---------------------------------------------------------------
always @* begin
    if (cfg_m0_select) begin
            o_tx_data_vld    = m0_tx_data_vld;
            o_tx_data        = m0_tx_data;
            o_tx_ctrl        = m0_tx_ctrl;
    end else begin
            o_tx_data_vld    = m1_tx_data_vld;
            o_tx_data        = m1_tx_data;
            o_tx_ctrl        = m1_tx_ctrl;
    end
end

endmodule

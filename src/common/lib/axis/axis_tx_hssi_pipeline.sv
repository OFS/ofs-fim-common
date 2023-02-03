// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// AXIS pipeline generator
//
//-----------------------------------------------------------------------------

`timescale 1 ps / 1 ps

import ofs_fim_eth_if_pkg::*;

module axis_tx_hssi_pipeline #( 
    parameter MODE                 = 0, // 0: skid buffer 1: simple buffer 2: simple buffer (bubble) 3: bypass
    parameter TREADY_RST_VAL       = 0, // 0: tready deasserted during reset 
                                        // 1: tready asserted during reset
    parameter ENABLE_TKEEP         = 1,
    parameter ENABLE_TLAST         = 1,
    parameter ENABLE_TID           = 0,
    parameter ENABLE_TDEST         = 0,
    parameter ENABLE_TUSER         = 1,
   
    parameter TDATA_WIDTH          = 512,
    parameter TID_WIDTH            = 8,
    parameter TDEST_WIDTH          = 8,
    parameter TUSER_WIDTH          = 10,

    parameter PL_DEPTH = 1
)(
    ofs_fim_hssi_ss_tx_axis_if.mac    axis_s,
    ofs_fim_hssi_ss_tx_axis_if.client axis_m
);

ofs_fim_hssi_ss_tx_axis_if axis_pl [PL_DEPTH:0] ();

always_comb begin
   axis_s.clk              = axis_m.clk;
   axis_s.rst_n            = axis_m.rst_n;
   axis_s.tready           = axis_pl[0].tready;

   axis_pl[0].tx.tvalid       = axis_s.tx.tvalid;
   axis_pl[0].tx.tlast        = axis_s.tx.tlast;
   axis_pl[0].tx.tuser        = axis_s.tx.tuser;
   axis_pl[0].tx.tdata        = axis_s.tx.tdata;
   axis_pl[0].tx.tkeep        = axis_s.tx.tkeep;

   axis_m.tx.tvalid       = axis_pl[PL_DEPTH].tx.tvalid;
   axis_m.tx.tlast        = axis_pl[PL_DEPTH].tx.tlast;
   axis_m.tx.tuser        = axis_pl[PL_DEPTH].tx.tuser;
   axis_m.tx.tdata        = axis_pl[PL_DEPTH].tx.tdata;
   axis_m.tx.tkeep        = axis_pl[PL_DEPTH].tx.tkeep;

   axis_pl[PL_DEPTH].tready = axis_m.tready;
end
   
genvar n;
generate
   for(n=0; n<PL_DEPTH; n=n+1) begin : axis_pl_stage
      axis_register #( 
         .MODE           ( MODE           ),
         .TREADY_RST_VAL ( TREADY_RST_VAL ),
         .ENABLE_TKEEP   ( ENABLE_TKEEP   ),
         .ENABLE_TLAST   ( ENABLE_TLAST   ),
         .ENABLE_TID     ( ENABLE_TID     ),
         .ENABLE_TDEST   ( ENABLE_TDEST   ),
         .ENABLE_TUSER   ( ENABLE_TUSER   ),
         .TDATA_WIDTH    ( TDATA_WIDTH    ),
         .TID_WIDTH      ( TID_WIDTH      ),
         .TDEST_WIDTH    ( TDEST_WIDTH    ),
         .TUSER_WIDTH    ( TUSER_WIDTH    )
      
      ) axis_reg_inst (
        .clk       (axis_m.clk),
        .rst_n     (axis_m.rst_n),

        .s_tready  (axis_pl[n].tready),
        .s_tvalid  (axis_pl[n].tx.tvalid),
        .s_tdata   (axis_pl[n].tx.tdata),
        .s_tkeep   (axis_pl[n].tx.tkeep),
        .s_tlast   (axis_pl[n].tx.tlast),
        .s_tid     (),
        .s_tdest   (),
        .s_tuser   (axis_pl[n].tx.tuser),
                   
        .m_tready  (axis_pl[n+1].tready),
        .m_tvalid  (axis_pl[n+1].tx.tvalid),
        .m_tdata   (axis_pl[n+1].tx.tdata),
        .m_tkeep   (axis_pl[n+1].tx.tkeep),
        .m_tlast   (axis_pl[n+1].tx.tlast),
        .m_tid     (),
        .m_tdest   (), 
        .m_tuser   (axis_pl[n+1].tx.tuser)
      );
   end // for (n=0; n<PL_DEPTH; n=n+1)
endgenerate
endmodule // axis_pipeline


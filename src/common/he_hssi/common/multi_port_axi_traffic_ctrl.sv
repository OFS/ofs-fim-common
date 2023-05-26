// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
// Description
//-----------------------------------------------------------------------------
//
// AXI-S Version of Multi-Port Traffic Controller
// 
// The traffic controller's native interface is Avalon. This module transforms
// the AXI-S interfaces to Avalon and then instantiates the Avalon version
// of the same wrapper.
//
//-----------------------------------------------------------------------------

module multi_port_axi_traffic_ctrl #(
   parameter NUM_ETH            = 1,  // Number of Ethernet lanes
   parameter AVMM_DATA_W        = 32, // Data width
   parameter AVMM_ADDR_W        = 16  // AVMM address width
)( // Clock and reset
   input                             clk,
   input                             reset,

   // AFU/MAC traffic
   ofs_fim_eth_tx_axis_if.master     eth_tx_st[NUM_ETH-1:0],
   ofs_fim_eth_rx_axis_if.slave      eth_rx_st[NUM_ETH-1:0],

   // AFU/MAC sideband
   ofs_fim_eth_sideband_tx_axis_if.master eth_sideband_tx [NUM_ETH-1:0],
   ofs_fim_eth_sideband_rx_axis_if.slave  eth_sideband_rx [NUM_ETH-1:0],

   // Avalon-MM Interface
   input  logic [AVMM_ADDR_W-1:0]    i_avmm_addr,        // AVMM address
   input  logic                      i_avmm_read,        // AVMM read request
   input  logic                      i_avmm_write,       // AVMM write request
   input  logic [AVMM_DATA_W-1:0]    i_avmm_writedata,   // AVMM write data
   output logic [AVMM_DATA_W-1:0]    o_avmm_readdata,    // AVMM read data
   output logic                      o_avmm_waitrequest, // AVMM wait request
   input  logic [3:0]                i_csr_port_sel      // Lane select for CSR
);

   ofs_fim_eth_tx_avst_if s_eth_tx_avst [NUM_ETH-1:0]();
   ofs_fim_eth_rx_avst_if s_eth_rx_avst [NUM_ETH-1:0]();

   ofs_fim_eth_sideband_tx_avst_if s_eth_sb_tx_avst [NUM_ETH-1:0]();
   ofs_fim_eth_sideband_rx_avst_if s_eth_sb_rx_avst [NUM_ETH-1:0]();

   // AVST TX/RX interface mapping
   generate
      for (genvar nume=0; nume<NUM_ETH; nume++) begin : GenBrdg
         `ifdef INCLUDE_HSSI
            ofs_fim_eth_afu_avst_to_fim_axis_bridge axis_to_avst_bridge_inst (
               .avst_tx_st (s_eth_tx_avst[nume]),
               .avst_rx_st (s_eth_rx_avst[nume]),
               .axi_tx_st  (eth_tx_st[nume]),
               .axi_rx_st  (eth_rx_st[nume])
            );

            // sideband mapping
            ofs_fim_eth_sb_afu_avst_to_fim_axis_bridge sb_axis_to_avst_bridge_inst (
               .avst_tx_st (s_eth_sb_tx_avst[nume]),
               .avst_rx_st (s_eth_sb_rx_avst[nume]),
               .axi_tx_st  (eth_sideband_tx[nume]),
               .axi_rx_st  (eth_sideband_rx[nume])
            );
         `else // Loopback for standalone unit test with no MAC-PHY
            always_comb begin
               s_eth_rx_avst[nume].rx.data   = s_eth_tx_avst[nume].tx.data;
               s_eth_rx_avst[nume].rx.valid  = s_eth_tx_avst[nume].tx.valid;
               s_eth_rx_avst[nume].rx.sop    = s_eth_tx_avst[nume].tx.sop;
               s_eth_rx_avst[nume].rx.eop    = s_eth_tx_avst[nume].tx.eop;
               s_eth_rx_avst[nume].rx.empty  = s_eth_tx_avst[nume].tx.empty;
               s_eth_rx_avst[nume].rx.user.error = {5'b0,s_eth_tx_avst[nume].tx.user.error};
               s_eth_tx_avst[nume].ready     = s_eth_rx_avst[nume].ready;
            end
         `endif
      end //GenBrdg
   endgenerate

   // Controller with AVST interface
   multi_port_traffic_ctrl #( 
      .NUM_ETH       (NUM_ETH),
      .AVMM_DATA_W   (AVMM_DATA_W),
      .AVMM_ADDR_W   (AVMM_ADDR_W)
   ) multi_port_traffic_ctrl_inst (
      .clk,
      .reset,

      // AFU <-> MAC data streams
      .eth_tx_st       (s_eth_tx_avst),
      .eth_rx_st       (s_eth_rx_avst),

      // AFU <-> MAC sideband signals
      .eth_sideband_tx (s_eth_sb_tx_avst),
      .eth_sideband_rx (s_eth_sb_rx_avst),

      .i_avmm_addr,
      .i_avmm_read,
      .i_avmm_write,
      .i_avmm_writedata,
      .o_avmm_readdata,
      .o_avmm_waitrequest,
      .i_csr_port_sel
   );

endmodule // multi_port_axi_traffic_ctrl

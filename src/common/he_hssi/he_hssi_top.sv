// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

//---
//
// Description: 
// The Host Exerciser  HSSI (he_hssi  is responsible for generating eth traffic with 
// the intention of exercising the path from the AFU to the Host at full bandwidth.
// Per the IOFS specification, It has a  PCIE AVL-ST interface  whcih is user for CSR access 
//  HSSI subssytem interface provides connects to HSSI subsystem
`include "vendor_defines.vh"
import ofs_fim_eth_if_pkg::*;

module he_hssi_top #(
   parameter PF_NUM=0,
   parameter VF_NUM=0,
   parameter VF_ACTIVE=0
)(
   input  logic                            clk,
   input  logic                            softreset,
   // AVST Rx                              
   pcie_ss_axis_if.sink                    axis_rx_if,
   // AVST Tx                              
   pcie_ss_axis_if.source                  axis_tx_if,
   ofs_fim_hssi_ss_tx_axis_if.client       hssi_ss_st_tx [MAX_NUM_ETH_CHANNELS-1:0],
   ofs_fim_hssi_ss_rx_axis_if.client       hssi_ss_st_rx [MAX_NUM_ETH_CHANNELS-1:0],
   ofs_fim_hssi_fc_if.client               hssi_fc [MAX_NUM_ETH_CHANNELS-1:0],

 //`ifdef INCLUDE_PTP
 //   ofs_fim_hssi_ptp_tx_tod_if.client    hssi_ptp_tx_tod [MAX_NUM_ETH_CHANNELS-1:0],
 //   ofs_fim_hssi_ptp_rx_tod_if.client    hssi_ptp_rx_tod [MAX_NUM_ETH_CHANNELS-1:0],
 //   ofs_fim_hssi_ptp_tx_egrts_if.client  hssi_ptp_tx_egrts [MAX_NUM_ETH_CHANNELS-1:0],
 //   ofs_fim_hssi_ptp_rx_ingrts_if.client hssi_ptp_rx_ingrts [MAX_NUM_ETH_CHANNELS-1:0],
 //`endif

   input logic [MAX_NUM_ETH_CHANNELS-1:0]  i_hssi_clk_pll
);

// ----------- Parameters -------------
   localparam ETH_DW           = ofs_fim_eth_if_pkg::ETH_PACKET_WIDTH;
   localparam RX_ERROR_WIDTH   = ofs_fim_eth_if_pkg::ETH_RX_ERROR_WIDTH;
   localparam TX_ERROR_WIDTH   = ofs_fim_eth_if_pkg::ETH_TX_ERROR_WIDTH;
   localparam AVMM_DATA_W      = 32;
   localparam AVMM_ADDR_W      = 16;
   localparam NUM_ETH_BY_2     = NUM_ETH_CHANNELS/2;

   // ---- Logic / Struct Declarations ---
   logic [AVMM_ADDR_W-1:0]          s_avmm_addr;
   logic                            s_avmm_read;
   logic                            s_avmm_write;
   logic [AVMM_DATA_W-1:0]          s_avmm_writedata;
   logic [AVMM_DATA_W-1:0]          s_avmm_readdata;
   logic                            s_avmm_waitrequest, s_avmm_waitrequest_q1;
   logic                            s_avmm_waitrequest_q2, s_avmm_waitrequest_q3;
   logic [3:0]                      s_csr_port_sel;
   logic                            s_port_swap_en;
   logic [MAX_NUM_ETH_CHANNELS-1:0] s_tx_bus_clk;
   logic [MAX_NUM_ETH_CHANNELS-1:0] s_rx_bus_clk;
   ofs_fim_eth_tx_axis_if           afu_eth_tx_st [MAX_NUM_ETH_CHANNELS-1:0] ();
   ofs_fim_eth_rx_axis_if           afu_eth_rx_st [MAX_NUM_ETH_CHANNELS-1:0] ();
   ofs_fim_eth_sideband_tx_axis_if  afu_eth_sideband_tx [MAX_NUM_ETH_CHANNELS-1:0] ();
   ofs_fim_eth_sideband_rx_axis_if  afu_eth_sideband_rx [MAX_NUM_ETH_CHANNELS-1:0] ();

`ifdef INCLUDE_CVL
   // AXIS data interface
   ofs_fim_eth_tx_axis_if           cpr_eth_tx_st [MAX_NUM_ETH_CHANNELS-1:0] ();
   ofs_fim_eth_rx_axis_if           cpr_eth_rx_st [MAX_NUM_ETH_CHANNELS-1:0] ();
   // AXI sideband interface
   ofs_fim_eth_sideband_tx_axis_if  cpr_eth_sideband_tx [MAX_NUM_ETH_CHANNELS-1:0] ();
`endif

//----------------------------Tx/Rx Streaming Datapath------------------//
   generate
      for (genvar ch=0; ch<MAX_NUM_ETH_CHANNELS; ch++) begin
         always_comb begin
            //Clock for easier assignment and synchronizer implementation
            s_tx_bus_clk[ch] = i_hssi_clk_pll[ch];
            s_rx_bus_clk[ch] = hssi_ss_st_rx[ch].clk;

            afu_eth_tx_st[ch].tready             = hssi_ss_st_tx[ch].tready;
            hssi_ss_st_tx[ch].tx.tvalid          = afu_eth_tx_st[ch].tx.tvalid;
            hssi_ss_st_tx[ch].tx.tlast           = afu_eth_tx_st[ch].tx.tlast;
            hssi_ss_st_tx[ch].tx.tdata           = afu_eth_tx_st[ch].tx.tdata;
            hssi_ss_st_tx[ch].tx.tkeep           = afu_eth_tx_st[ch].tx.tkeep;
            hssi_ss_st_tx[ch].tx.tuser.client[1] = afu_eth_tx_st[ch].tx.tuser;
            hssi_ss_st_tx[ch].tx.tuser.client[0] = afu_eth_tx_st[ch].tx.tuser;

            afu_eth_rx_st[ch].rx.tvalid   = hssi_ss_st_rx[ch].rx.tvalid;
            afu_eth_rx_st[ch].rx.tlast    = hssi_ss_st_rx[ch].rx.tlast;
            afu_eth_rx_st[ch].rx.tdata    = hssi_ss_st_rx[ch].rx.tdata;
            afu_eth_rx_st[ch].rx.tkeep    = hssi_ss_st_rx[ch].rx.tkeep;
            afu_eth_rx_st[ch].rx.tuser[0] = hssi_ss_st_rx[ch].rx.tuser.client[6];
            afu_eth_rx_st[ch].rx.tuser[1] = hssi_ss_st_rx[ch].rx.tuser.client[5];
            afu_eth_rx_st[ch].rx.tuser[2] = hssi_ss_st_rx[ch].rx.tuser.client[2];
            afu_eth_rx_st[ch].rx.tuser[3] = hssi_ss_st_rx[ch].rx.tuser.client[3];
            afu_eth_rx_st[ch].rx.tuser[4] = hssi_ss_st_rx[ch].rx.tuser.client[4];
            afu_eth_rx_st[ch].rx.tuser[5] = 1'b0;
            afu_eth_rx_st[ch].rx.tuser[5] = 1'b0;

            //----------------Tx/Rx Sideband Interface--------------------//
            afu_eth_sideband_rx[ch].sb    = 'b0;
            hssi_fc[ch].tx_pause = afu_eth_sideband_tx[ch].sb.tvalid  & afu_eth_sideband_tx[ch].sb.tdata.pause_xoff ;
            hssi_fc[ch].tx_pfc   = afu_eth_sideband_tx[ch].sb.tvalid  & (|afu_eth_sideband_tx[ch].sb.tdata.pfc_xoff );
         end
      end
   endgenerate 

     always_ff @(posedge clk) begin
      if(softreset) begin
         s_avmm_waitrequest_q1 <= '0;
         s_avmm_waitrequest_q2 <= '0;
         s_avmm_waitrequest_q3 <= '0;
      end else begin
         s_avmm_waitrequest_q1 <= s_avmm_waitrequest;
         s_avmm_waitrequest_q2 <= s_avmm_waitrequest_q1;
         s_avmm_waitrequest_q3 <= s_avmm_waitrequest_q2;
      end
   end

   // Clock and reset mapping for HSSI datapath
   generate
      for (genvar ch=0; ch<NUM_ETH_CHANNELS; ch++) begin : GenRstSync
         logic tx_sync_rst_n;
         fim_resync # (
               .SYNC_CHAIN_LENGTH(3),
               .WIDTH(1),
               .INIT_VALUE(0),
               .NO_CUT(0)
            ) tx_reset_synchronizer(
               .clk   (s_tx_bus_clk[ch]),
               .reset (softreset),
               .d     (1'b1),
               .q     (tx_sync_rst_n)
            );

         logic rx_sync_rst_n;
         fim_resync # (
               .SYNC_CHAIN_LENGTH(3),
               .WIDTH(1),
               .INIT_VALUE(0),
               .NO_CUT(0)
            ) rx_reset_synchronizer(
               .clk   (s_rx_bus_clk[ch]),
               .reset (softreset),
               .d     (1'b1),
               .q     (rx_sync_rst_n)
            );

         always_comb begin // sideband mapping
            afu_eth_tx_st[ch].clk         = s_tx_bus_clk[ch];
            afu_eth_tx_st[ch].rst_n       = tx_sync_rst_n;
            afu_eth_rx_st[ch].clk         = s_rx_bus_clk[ch];
            afu_eth_rx_st[ch].rst_n       = rx_sync_rst_n;
            afu_eth_sideband_tx[ch].clk   = s_tx_bus_clk[ch];
            afu_eth_sideband_tx[ch].rst_n = tx_sync_rst_n;
            afu_eth_sideband_rx[ch].clk   = s_rx_bus_clk[ch];
            afu_eth_sideband_rx[ch].rst_n = rx_sync_rst_n;
         end
      end
   endgenerate

   // cross port routing logic
   // cpr_eth* connected to traffic controller
   // afu_eth* connected to HSSI SS interfaces
   `ifdef INCLUDE_CVL
      generate
         for (genvar ch=0; ch<NUM_ETH_CHANNELS; ch++) begin : GenCPR
            
            `ifndef CPR_DISABLE
               eth_rx_axis_cdc_fifo  #(
                  .DEPTH_LOG2        (6),
                  .ALMFULL_THRESHOLD (4)
               ) cvl_data_sync (
                  .src_clk    (cpr_eth_tx_st[ch].clk),
                  .src_rst_n  (cpr_eth_tx_st[ch].rst_n),
                  .snk_if     (afu_eth_rx_st[ch]),
                  .src_if     (cpr_eth_rx_st[ch])
               );
               always_comb begin
                  cpr_eth_tx_st[ch].clk         = afu_eth_tx_st[(ch+(NUM_ETH_BY_2))%NUM_ETH_CHANNELS].clk;
                  cpr_eth_tx_st[ch].rst_n       = afu_eth_tx_st[(ch+(NUM_ETH_BY_2))%NUM_ETH_CHANNELS].rst_n;
                  afu_eth_tx_st[ch].tx          = cpr_eth_tx_st[(ch+(NUM_ETH_BY_2))%NUM_ETH_CHANNELS].tx;
                  cpr_eth_tx_st[ch].tready      = afu_eth_tx_st[(ch+(NUM_ETH_BY_2))%NUM_ETH_CHANNELS].tready;
                  
                  cpr_eth_sideband_tx[ch].clk   = afu_eth_sideband_tx[(ch+(NUM_ETH_BY_2))%NUM_ETH_CHANNELS].clk;
                  cpr_eth_sideband_tx[ch].rst_n = afu_eth_sideband_tx[(ch+(NUM_ETH_BY_2))%NUM_ETH_CHANNELS].rst_n;
                  afu_eth_sideband_tx[ch].sb    = cpr_eth_sideband_tx[(ch+(NUM_ETH_BY_2))%NUM_ETH_CHANNELS].sb;
               end
            `else
               always_comb begin
                  cpr_eth_tx_st[ch].clk      = afu_eth_tx_st[ch].clk;
                  cpr_eth_tx_st[ch].rst_n    = afu_eth_tx_st[ch].rst_n;
                  afu_eth_tx_st[ch].tx       = cpr_eth_tx_st[ch].tx;
                  cpr_eth_tx_st[ch].tready   = afu_eth_tx_st[ch].tready;

                  cpr_eth_rx_st[ch].clk      = afu_eth_rx_st[ch].clk;
                  cpr_eth_rx_st[ch].rst_n    = afu_eth_rx_st[ch].rst_n;
                  cpr_eth_rx_st[ch].rx       = afu_eth_rx_st[ch].rx;
                  afu_eth_rx_st[ch].tready   = cpr_eth_rx_st[ch].tready;
                  
                  cpr_eth_sideband_tx[ch].clk   = afu_eth_sideband_tx[ch].clk;
                  cpr_eth_sideband_tx[ch].rst_n = afu_eth_sideband_tx[ch].rst_n;
                  afu_eth_sideband_tx[ch].sb    = cpr_eth_sideband_tx[ch].sb;
               
               end
            `endif
         end
      endgenerate
   `endif

   // CSR for module for ethernet traffic AFU
   eth_traffic_pcie_tlp_to_csr  #(
      .PF_NUM        (PF_NUM),
      .VF_NUM        (VF_NUM),
      .VF_ACTIVE     (VF_ACTIVE),
      .AVMM_DATA_W   (AVMM_DATA_W),
      .AVMM_ADDR_W   (AVMM_ADDR_W)
   ) eth_traffic_pcie_tlp_to_csr_inst (
      .clk                (clk),
      .softreset          (softreset),
      .axis_rx_if         (axis_rx_if),
      .axis_tx_if         (axis_tx_if),
      .o_avmm_addr        (s_avmm_addr),
      .o_avmm_read        (s_avmm_read),
      .o_avmm_write       (s_avmm_write),
      .o_avmm_writedata   (s_avmm_writedata),
      .i_avmm_readdata    (s_avmm_readdata),
      .i_avmm_waitrequest (s_avmm_waitrequest_q3),
      .o_csr_port_sel     (s_csr_port_sel),
      .o_port_swap_en     (s_port_swap_en)
   );

// Multi-channel 10G ethernet traffic controller top
   multi_port_axi_traffic_ctrl #( 
      .NUM_ETH       (NUM_ETH_CHANNELS),
      .AVMM_DATA_W   (AVMM_DATA_W),
      .AVMM_ADDR_W   (AVMM_ADDR_W)
   ) multi_port_axi_traffic_ctrl_inst (
      .clk                (clk),
      .reset              (softreset),

      // AFU <-> MAC data streams
      `ifdef INCLUDE_CVL
         .eth_tx_st       (cpr_eth_tx_st[NUM_ETH_CHANNELS-1:0]),
         .eth_rx_st       (cpr_eth_rx_st[NUM_ETH_CHANNELS-1:0]),
      `else
         .eth_tx_st       (afu_eth_tx_st[NUM_ETH_CHANNELS-1:0]),
         .eth_rx_st       (afu_eth_rx_st[NUM_ETH_CHANNELS-1:0]),
      `endif

      // AFU <-> MAC sideband signals
      `ifdef INCLUDE_CVL
         .eth_sideband_tx (cpr_eth_sideband_tx[NUM_ETH_CHANNELS-1:0]),
      `else
         .eth_sideband_tx (afu_eth_sideband_tx[NUM_ETH_CHANNELS-1:0]),
      `endif
      .eth_sideband_rx    (afu_eth_sideband_rx[NUM_ETH_CHANNELS-1:0]),

      .i_avmm_addr        (s_avmm_addr),
      .i_avmm_read        (s_avmm_read),
      .i_avmm_write       (s_avmm_write),
      .i_avmm_writedata   (s_avmm_writedata),
      .o_avmm_readdata    (s_avmm_readdata),
      .o_avmm_waitrequest (s_avmm_waitrequest),
      .i_csr_port_sel     (s_csr_port_sel)
   );

endmodule // eth_traffic_afu

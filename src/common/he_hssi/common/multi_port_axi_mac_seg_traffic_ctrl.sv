// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
// Description
//-----------------------------------------------------------------------------
//
// Multi-Port MAC Segmented Traffic Controller
// 
// Instantiates traffic controller based on number of Ethernet
// channels
//-----------------------------------------------------------------------------
import ofs_fim_eth_if_pkg::*;
import ofs_fim_eth_f_traffic_controller_pkg::*;

module multi_port_axi_mac_seg_traffic_ctrl #(
   parameter NUM_ETH            = 1,  // Number of Ethernet lanes
   parameter AVMM_DATA_W        = 32, // Data width
   parameter AVMM_ADDR_W        = 16  // AVMM address width
)( // Clock and reset
   input                             clk,
   input                             reset,
   
   // AFU/MAC traffic
   ofs_fim_hssi_ss_tx_axis_if.client       hssi_pc_st_tx [NUM_ETH-1:0],
   ofs_fim_hssi_ss_rx_axis_if.client       hssi_pc_st_rx [NUM_ETH-1:0],
   ofs_fim_hssi_fc_if.client               hssi_pc_fc [NUM_ETH-1:0],
   input logic [MAX_NUM_ETH_CHANNELS-1:0]  i_hssi_clk_pll,
   input logic [MAX_NUM_ETH_CHANNELS-1:0]  i_tx_pll_locked,
   input logic [NUM_ETH_CHANNELS-1:0]      i_cdr_lock,
   
   // Avalon-MM Interface
   input  logic [AVMM_ADDR_W-1:0]    i_avmm_addr,        // AVMM address
   input  logic                      i_avmm_read,        // AVMM read request
   input  logic                      i_avmm_write,       // AVMM write request
   input  logic [AVMM_DATA_W-1:0]    i_avmm_writedata,   // AVMM write data
   output logic [AVMM_DATA_W-1:0]    o_avmm_readdata,    // AVMM read data
   output logic                      o_avmm_readdata_valid, // AVMM read data valid
   output logic                      o_avmm_waitrequest, // AVMM wait request
   input  logic [3:0]                i_csr_port_sel      // Lane select for CSR
);

////////////////////////////////////////////////////////////////////////////////
// MAC signals
////////////////////////////////////////////////////////////////////////////////

logic [NUM_ETH-1:0][AVMM_DATA_W-1:0] csr_readdata;
logic [NUM_ETH-1:0]                  csr_waitrequest;
logic [NUM_ETH-1:0]                  csr_readdatavalid;


generate
   for (genvar nume=0; nume<NUM_ETH; nume++) begin : GenTrafWrap
      logic                   csr_read;
      logic                   csr_write;
      logic [AVMM_DATA_W-1:0] csr_writedata /* synthesis preserve */;
      logic [AVMM_ADDR_W-1:0] csr_address   /* synthesis preserve */;
            
      hssi_ss_f_packet_client_top #(
        .PTP_EN                     (0),
        .PTP_ACC_MODE               (1),
        .CLIENT_IF_TYPE             (0),    // 0 = MAC segmented (default in this TG), 1 = AVST mode
        .EHIP_RATE                  (EHIP_RATE),
        .RSFEC_TYPE_GUI             (3),    //  same for 200G,400G
        .PTP_FP_WIDTH               (8),    //  same for 200G,400G
        .EN_10G_ADV_MODE            (0),
        .EMPTY_WIDTH                (3),
        .NO_OF_BYTES                (NO_OF_BYTES),
        .DATA_WIDTH                 (ETH_PACKET_WIDTH),
        .ENABLE_DL_GUI              (0),
        .TX_TUSER_CLIENT_WIDTH      (2*ETH_PACKET_WIDTH/64),
        .RX_TUSER_CLIENT_WIDTH      (7*ETH_PACKET_WIDTH/64),
        .RX_TUSER_STATS_WIDTH       (5*ETH_PACKET_WIDTH/64),
        .PREAMBLE_PASS_TH_EN        (0),
        .PORT_PROFILE               (PORT_PROFILE),
        .DR_ENABLE                  (0),
        .NUM_MAX_PORTS              (1),

        .ST_READY_LATENCY           (0),
        .PKT_SEG_PARITY_EN          (0),
        .ENABLE_MULTI_STREAM        (0),
        .NUM_OF_STREAM              (1),

        .PKT_ROM_INIT_FILE          (PKT_ROM_INIT_FILE),
        .PKT_ROM_INIT_DATA          (PKT_ROM_INIT_DATA),
        .PKT_ROM_INIT_CTL           (PKT_ROM_INIT_CTL),
        .TILES                      ("F"),
        .TID                        (8),
        .BCM_SIM_ENABLE             (0)
      ) mac_seg_packet_client_top (
         .i_rst_n                (!reset), 
         .app_ss_lite_clk        (clk),
         .app_ss_lite_areset_n   (!reset),

         .i_clk_tx               (hssi_pc_st_tx[nume].clk),
         .i_clk_rx               (hssi_pc_st_rx[nume].clk),
         .i_clk_pll              (i_hssi_clk_pll[nume] ),
         .i_tx_pll_locked        (i_tx_pll_locked),     
         .i_cdr_lock             (i_cdr_lock),

         .axis_tx_tready_i       (hssi_pc_st_tx[nume].tready),
         .axis_tx_tvalid_o       (hssi_pc_st_tx[nume].tx.tvalid),
         .axis_tx_tdata_o        (hssi_pc_st_tx[nume].tx.tdata),
         .axis_tx_tkeep_o        (hssi_pc_st_tx[nume].tx.tkeep),
         .axis_tx_tlast_o        (hssi_pc_st_tx[nume].tx.tlast),
         .axis_tx_tuser_client_o (hssi_pc_st_tx[nume].tx.tuser.client),
         .axis_tx_tuser_last_seg_o (hssi_pc_st_tx[nume].tx.tuser.last_segment),

         .axis_rx_tuser_last_seg_i (hssi_pc_st_rx[nume].rx.tuser.last_segment), 
         .axis_rx_tvalid_i       (hssi_pc_st_rx[nume].rx.tvalid),
         .axis_rx_tdata_i        (hssi_pc_st_rx[nume].rx.tdata),
         .axis_rx_tkeep_i        (hssi_pc_st_rx[nume].rx.tkeep),
         .axis_rx_tlast_i        (hssi_pc_st_rx[nume].rx.tlast),
         .axis_rx_tuser_client_i (hssi_pc_st_rx[nume].rx.tuser.client),
         .axis_rx_tuser_sts_i    (hssi_pc_st_rx[nume].rx.tuser.sts),
         .axis_rx_tuser_sts_ext_i('h0),
              
         .i_clk_status             (clk),
         .i_status_addr            (csr_address),
         .i_status_read            (csr_read),
         .i_status_write           (csr_write),
         .i_status_writedata       (csr_writedata),
         .o_status_readdata        (csr_readdata[nume]),
         .o_status_readdata_valid  (csr_readdatavalid[nume]),
         .o_status_waitrequest     (csr_waitrequest[nume])
      );
      
      always_comb begin // sideband mapping //not driven in ED  
         hssi_pc_fc[nume].tx_pause = 1'b0; 
         hssi_pc_fc[nume].tx_pfc   = 8'b0; 
      end

      always_comb begin
         if (i_csr_port_sel == nume) begin
            csr_read           = i_avmm_read;
            csr_write          = i_avmm_write;
         end   
         else begin
            csr_read           = 1'b0;
            csr_write          = 1'b0;
         end
      end
      
      always_comb begin
         csr_writedata      = i_avmm_writedata;
         csr_address        = i_avmm_addr;
      end
   end
endgenerate

// Output selection based on port_sel   
always_comb begin
   o_avmm_waitrequest       = csr_waitrequest[i_csr_port_sel];
   o_avmm_readdata          = csr_readdata[i_csr_port_sel];
   o_avmm_readdata_valid    = csr_readdatavalid[i_csr_port_sel];
end


endmodule //multi_port_axi_mac_traffic_ctrl


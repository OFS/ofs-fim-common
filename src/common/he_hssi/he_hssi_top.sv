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
`include "fpga_defines.vh"

`ifdef DEVICE_FAMILY_IS_AGILEX
   `include  "ofs_ip_cfg_hssi_ss.vh"
`endif

module he_hssi_top #(
   parameter PF_NUM=0,
   parameter VF_NUM=0,
   parameter VF_ACTIVE=0,
   parameter AXI4_LITE_CSR = 0
)(
   input  logic                            clk,
   input  logic                            softreset,
`ifdef HE_HSSI_ENABLE_AXI_CSR
   ofs_fim_axi_lite_if.sink                csr_lite_if,
`endif
   pcie_ss_axis_if.sink                    axis_rx_if,
   // AVST Tx                              
   pcie_ss_axis_if.source                  axis_tx_if,
   ofs_fim_hssi_ss_tx_axis_if.client       hssi_ss_st_tx [MAX_NUM_ETH_CHANNELS-1:0],
   ofs_fim_hssi_ss_rx_axis_if.client       hssi_ss_st_rx [MAX_NUM_ETH_CHANNELS-1:0],
   ofs_fim_hssi_fc_if.client               hssi_fc [MAX_NUM_ETH_CHANNELS-1:0],
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
   logic                            clk_sys;
   logic                            rst_sys;

   logic [AVMM_ADDR_W-1:0]          s_avmm_addr;
   logic                            s_avmm_read;
   logic                            s_avmm_write;
   logic [AVMM_DATA_W-1:0]          s_avmm_writedata;
   logic [AVMM_DATA_W-1:0]          s_avmm_readdata;
   logic                            s_avmm_readdata_valid;
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
   ofs_fim_hssi_ss_tx_axis_if       afu_pc_st_tx [MAX_NUM_ETH_CHANNELS-1:0] ();
   ofs_fim_hssi_ss_rx_axis_if       afu_pc_st_rx [MAX_NUM_ETH_CHANNELS-1:0] ();
   ofs_fim_hssi_fc_if               afu_pc_fc [MAX_NUM_ETH_CHANNELS-1:0] ();


   always_ff @(posedge clk_sys) begin
      if(rst_sys) begin
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
            `ifndef INCLUDE_CPR
	       afu_eth_rx_st[ch].clk         = s_rx_bus_clk[ch];
               afu_eth_rx_st[ch].rst_n       = rx_sync_rst_n;
            `endif
            afu_eth_sideband_tx[ch].clk   = s_tx_bus_clk[ch];
            afu_eth_sideband_tx[ch].rst_n = tx_sync_rst_n;
            afu_eth_sideband_rx[ch].clk   = s_rx_bus_clk[ch];
            afu_eth_sideband_rx[ch].rst_n = rx_sync_rst_n;
         end
      end
   endgenerate

   
generate

// If AXI4_LITE interface is enabled, CSR access takes place only through
// the AXI4_LITE interface. When disabled, CSR access takes place through
// the steaming interface.
if(AXI4_LITE_CSR == 1)
begin
`ifdef HE_HSSI_ENABLE_AXI_CSR
   // CSR for module for ethernet traffic AFU
   eth_traffic_pcie_axil_csr  #(
      .AVMM_DATA_W   (AVMM_DATA_W),
      .AVMM_ADDR_W   (AVMM_ADDR_W)
   ) eth_traffic_pcie_axil_csr_inst (
      .clk                (csr_lite_if.clk),
      .rst_n              (csr_lite_if.rst_n),
      .csr_lite_if        (csr_lite_if),
      .o_avmm_addr        (s_avmm_addr),
      .o_avmm_read        (s_avmm_read),
      .o_avmm_write       (s_avmm_write),
      .o_avmm_writedata   (s_avmm_writedata),
      .i_avmm_readdata    (s_avmm_readdata),
      .i_avmm_waitrequest (s_avmm_waitrequest_q3),
      .o_csr_port_sel     (s_csr_port_sel),
      .o_port_swap_en     (s_port_swap_en)
   );

   // Tieoff the PCIe SS ST interfaces
   assign axis_rx_if.tready = 1'b1;
   assign axis_tx_if.tvalid = 1'b0;

   assign clk_sys = csr_lite_if.clk;
   assign rst_sys = ~csr_lite_if.rst_n;
`endif
end
else
begin
    `ifdef MAC_SEGMENTED
        // multi_port_axi_mac_seg_traffic_ctrl has a readdata_valid that we must use.
        localparam ETH_TRAFFIC_PCIE_TLP_TO_CSR_USE_AVMM_READDATA_VALID = 1;
    `else
        localparam ETH_TRAFFIC_PCIE_TLP_TO_CSR_USE_AVMM_READDATA_VALID = 0;
    `endif

   // CSR for module for ethernet traffic AFU
   eth_traffic_pcie_tlp_to_csr  #(
      .PF_NUM        (PF_NUM),
      .VF_NUM        (VF_NUM),
      .VF_ACTIVE     (VF_ACTIVE),
      .AVMM_DATA_W   (AVMM_DATA_W),
      .AVMM_ADDR_W   (AVMM_ADDR_W),
      .USE_AVMM_READDATA_VALID (ETH_TRAFFIC_PCIE_TLP_TO_CSR_USE_AVMM_READDATA_VALID)
   ) eth_traffic_pcie_tlp_to_csr_inst (
      .clk                      (clk),
      .softreset                (softreset),
      .axis_rx_if               (axis_rx_if),
      .axis_tx_if               (axis_tx_if),
      // *_avmm* goes to the traffic controller
      .o_avmm_addr              (s_avmm_addr),
      .o_avmm_read              (s_avmm_read),
      .o_avmm_write             (s_avmm_write),
      .o_avmm_writedata         (s_avmm_writedata),
      .i_avmm_readdata          (s_avmm_readdata),
      .i_avmm_readdata_valid    (s_avmm_readdata_valid),
      .i_avmm_waitrequest       (s_avmm_waitrequest_q3),
      .o_csr_port_sel           (s_csr_port_sel),
      .o_port_swap_en           (s_port_swap_en)
   );

   assign clk_sys = clk;
   assign rst_sys = softreset;
end
endgenerate

    
localparam AVST_DATA_WIDTH       = ofs_fim_eth_avst_if_pkg::AVST_ETH_PACKET_WIDTH;
ofs_fim_eth_rx_axis_if           cpr_eth_rx_st [MAX_NUM_ETH_CHANNELS-1:0] ();
ofs_fim_eth_tx_axis_if           cpr_eth_tx_st_frame_buff [MAX_NUM_ETH_CHANNELS-1:0] ();
ofs_fim_eth_tx_avst_if           cpr_eth_tx_avst_frame_buff [MAX_NUM_ETH_CHANNELS-1:0] ();
ofs_fim_eth_rx_avst_if           cpr_eth_rx_avst [MAX_NUM_ETH_CHANNELS-1:0] ();
logic [MAX_NUM_ETH_CHANNELS-1:0] cpr_eth_rx_st_frame_buff_tvalid;

// Cross Port Routing logic
        
`ifdef INCLUDE_CPR
       for (genvar ch=0; ch<NUM_ETH_CHANNELS; ch++) begin : GenCPR
    
          eth_rx_axis_cdc_fifo  #(
             .DEPTH_LOG2        (6),
             .ALMFULL_THRESHOLD (4)
          ) hssi_data_sync (
             .src_clk    (hssi_ss_st_tx[(ch+(NUM_ETH_BY_2))%NUM_ETH_CHANNELS].clk),
             .src_rst_n  (hssi_ss_st_tx[(ch+(NUM_ETH_BY_2))%NUM_ETH_CHANNELS].rst_n),
             .snk_if     (afu_eth_rx_st[ch]),
             .src_if     (cpr_eth_rx_st[ch])
          );
    
          ofs_fim_eth_afu_avst_to_fim_axis_bridge axis_to_avst_bridge_inst (
             .avst_tx_st (cpr_eth_tx_avst_frame_buff[ch]),
             .avst_rx_st (cpr_eth_rx_avst[ch]),
             .axi_tx_st  (cpr_eth_tx_st_frame_buff[ch]),
             .axi_rx_st  (cpr_eth_rx_st[ch])
          );
    
         // sc_fifo_tx_sc_fifo_altera_avalon_sc_fifo_1931_45k5dnq #(
	 sc_fifo_tx_sc_fifo #(
             .SYMBOLS_PER_BEAT    (AVST_DATA_WIDTH/8),
             .BITS_PER_SYMBOL     (8),
             .FIFO_DEPTH          (16384/AVST_DATA_WIDTH),  // set to 16K that can support maximum Ethernet frame length 9600 bytes 
             .CHANNEL_WIDTH       (0),
             .ERROR_WIDTH         (1),
             .USE_PACKETS         (1),
             .USE_FILL_LEVEL      (1),
             .EMPTY_LATENCY       (3),
             .USE_MEMORY_BLOCKS   (1),
             .USE_STORE_FORWARD   (1),
             .USE_ALMOST_FULL_IF  (1),
             .USE_ALMOST_EMPTY_IF (1)
          ) tx_sc_fifo (
             .clk                 (cpr_eth_tx_avst_frame_buff[ch].clk),
             .reset               (~cpr_eth_tx_avst_frame_buff[ch].rst_n),
             .csr_address         (3'b0),
             .csr_read            (1'b0),
             .csr_write           (1'b0),
             .csr_readdata        (),
             .csr_writedata       (32'b0),
             .in_data             (cpr_eth_rx_avst[ch].rx.data),
             .in_valid            (cpr_eth_rx_avst[ch].rx.valid),
             .in_ready            (cpr_eth_rx_avst[ch].ready),
             .in_startofpacket    (cpr_eth_rx_avst[ch].rx.sop),
             .in_endofpacket      (cpr_eth_rx_avst[ch].rx.eop),
             .in_empty            (cpr_eth_rx_avst[ch].rx.empty),
             .in_error            (|cpr_eth_rx_avst[ch].rx.user.error),
             .out_data            (cpr_eth_tx_avst_frame_buff[ch].tx.data),
             .out_valid           (cpr_eth_tx_avst_frame_buff[ch].tx.valid),
             .out_ready           (cpr_eth_tx_avst_frame_buff[ch].ready),
             .out_startofpacket   (cpr_eth_tx_avst_frame_buff[ch].tx.sop),
             .out_endofpacket     (cpr_eth_tx_avst_frame_buff[ch].tx.eop),
             .out_empty           (cpr_eth_tx_avst_frame_buff[ch].tx.empty),
             .out_error           (cpr_eth_tx_avst_frame_buff[ch].tx.user.error),
             .almost_full_data    (),
             .almost_empty_data   ()
	      );
    
          always_comb begin
             cpr_eth_tx_st_frame_buff[ch].tready  = hssi_ss_st_tx[(ch+(NUM_ETH_BY_2))%NUM_ETH_CHANNELS].tready;
             cpr_eth_tx_st_frame_buff[ch].clk     = hssi_ss_st_tx[(ch+(NUM_ETH_BY_2))%NUM_ETH_CHANNELS].clk;
             cpr_eth_tx_st_frame_buff[ch].rst_n   = hssi_ss_st_tx[(ch+(NUM_ETH_BY_2))%NUM_ETH_CHANNELS].rst_n;
             hssi_ss_st_tx[ch].tx.tvalid          = cpr_eth_tx_st_frame_buff[(ch+(NUM_ETH_BY_2))%NUM_ETH_CHANNELS].tx.tvalid ;
             hssi_ss_st_tx[ch].tx.tlast           = cpr_eth_tx_st_frame_buff[(ch+(NUM_ETH_BY_2))%NUM_ETH_CHANNELS].tx.tlast;
             hssi_ss_st_tx[ch].tx.tdata           = cpr_eth_tx_st_frame_buff[(ch+(NUM_ETH_BY_2))%NUM_ETH_CHANNELS].tx.tdata;
             hssi_ss_st_tx[ch].tx.tkeep           = cpr_eth_tx_st_frame_buff[(ch+(NUM_ETH_BY_2))%NUM_ETH_CHANNELS].tx.tkeep;
             hssi_ss_st_tx[ch].tx.tuser.client[1] = 0;
             hssi_ss_st_tx[ch].tx.tuser.client[0] = |(cpr_eth_tx_st_frame_buff[(ch+(NUM_ETH_BY_2))%NUM_ETH_CHANNELS].tx.tuser);
    
             afu_eth_rx_st[ch].clk         = hssi_ss_st_rx[ch].clk;
             afu_eth_rx_st[ch].rst_n       = hssi_ss_st_rx[ch].rst_n;
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
    
             hssi_fc[ch].tx_pause = 'h0;
             hssi_fc[ch].tx_pfc   = 'h0;
          end
       end
    
`else // if no cross-port routing (INCLUDE_CPR), check which traffic generator is required, if MAC_SEGMENTED then instantiate multi_port_axi_mac_seg_traffic_ctrl  or else instantiate multi_port_axi_sop_traffic_ctrl 

    `ifdef MAC_SEGMENTED
         generate
          for (genvar ch=0; ch<MAX_NUM_ETH_CHANNELS; ch++) begin
             always_comb begin
                //Clock for easier assignment and synchronizer implementation
                s_tx_bus_clk[ch] = i_hssi_clk_pll[ch];
                s_rx_bus_clk[ch] = hssi_ss_st_rx[ch].clk;
    
                afu_pc_st_tx[ch].tready              = hssi_ss_st_tx[ch].tready;
                hssi_ss_st_tx[ch].tx.tvalid          = afu_pc_st_tx[ch].tx.tvalid;
                hssi_ss_st_tx[ch].tx.tlast           = afu_pc_st_tx[ch].tx.tlast;
                hssi_ss_st_tx[ch].tx.tdata           = afu_pc_st_tx[ch].tx.tdata;
                hssi_ss_st_tx[ch].tx.tkeep           = afu_pc_st_tx[ch].tx.tkeep;
                hssi_ss_st_tx[ch].tx.tuser.client    = afu_pc_st_tx[ch].tx.tuser.client;
                hssi_ss_st_tx[ch].tx.tuser.last_segment = afu_pc_st_tx[ch].tx.tuser.last_segment;
             
    
                afu_pc_st_rx[ch].rx.tvalid   = hssi_ss_st_rx[ch].rx.tvalid;
                afu_pc_st_rx[ch].rx.tlast    = hssi_ss_st_rx[ch].rx.tlast;
                afu_pc_st_rx[ch].rx.tdata    = hssi_ss_st_rx[ch].rx.tdata;
                afu_pc_st_rx[ch].rx.tkeep    = hssi_ss_st_rx[ch].rx.tkeep;
                afu_pc_st_rx[ch].rx.tuser.client = hssi_ss_st_rx[ch].rx.tuser.client;
                afu_pc_st_rx[ch].rx.tuser.sts = hssi_ss_st_rx[ch].rx.tuser.sts;
                afu_pc_st_rx[ch].rx.tuser.last_segment = hssi_ss_st_rx[ch].rx.tuser.last_segment; 
    
                //----------------Tx/Rx Sideband Interface--------------------//
                afu_pc_fc[ch].rx_pause    = hssi_fc[ch].rx_pause;
                afu_pc_fc[ch].rx_pfc      = hssi_fc[ch].rx_pfc;
                hssi_fc[ch].tx_pause = afu_pc_fc[ch].tx_pause;
                hssi_fc[ch].tx_pfc   = afu_pc_fc[ch].tx_pfc; 

		// setting up initial values for unused interfaces for simluation
		afu_eth_tx_st[ch].tx.tvalid = 1'b0;
		afu_eth_tx_st[ch].tx.tlast  = 'b0;
		afu_eth_tx_st[ch].tx.tdata  = 'b0;
		afu_eth_tx_st[ch].tx.tkeep  = 'b0;
		afu_eth_tx_st[ch].tx.tuser  = 'b0;
		afu_eth_tx_st[ch].tready    = 1'b0;
	        afu_eth_rx_st[ch].rx.tvalid = 1'b0; 
            	afu_eth_rx_st[ch].rx.tlast  = 'b0; 
             	afu_eth_rx_st[ch].rx.tdata  = 'b0; 
		afu_eth_rx_st[ch].rx.tkeep  = 'b0;
             	afu_eth_rx_st[ch].rx.tuser  = 'b0;
		afu_eth_rx_st[ch].tready    = 1'b0;
		afu_eth_sideband_rx[ch].sb  = 'b0;
                afu_eth_sideband_tx[ch].sb  = 'b0;
	     end
          end
       endgenerate 
      // Clock and reset mapping for HSSI datapath
       generate
          for (genvar ch=0; ch<NUM_ETH_CHANNELS; ch++) begin : GenRstSyncMacSeg
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
                afu_pc_st_tx[ch].clk         = s_tx_bus_clk[ch];
                afu_pc_st_tx[ch].rst_n       = tx_sync_rst_n;
                afu_pc_st_rx[ch].clk         = s_rx_bus_clk[ch];
                afu_pc_st_rx[ch].rst_n       = rx_sync_rst_n;
                end
          end
       endgenerate
    
        multi_port_axi_mac_seg_traffic_ctrl #(
          .NUM_ETH       (NUM_ETH_CHANNELS),
          .AVMM_DATA_W   (AVMM_DATA_W),
          .AVMM_ADDR_W   (AVMM_ADDR_W)
       ) multi_port_axi_mac_seg_traffic_ctrl_inst (
          .clk                      (clk_sys),
          .reset                    (rst_sys),
    
          // AFU <-> MAC data streams
          .hssi_pc_st_tx            (afu_pc_st_tx[NUM_ETH_CHANNELS-1:0]),
          .hssi_pc_st_rx            (afu_pc_st_rx[NUM_ETH_CHANNELS-1:0]),
    
          // AFU <-> MAC sideband signals
          .hssi_pc_fc               (afu_pc_fc[NUM_ETH_CHANNELS-1:0]),
          .i_hssi_clk_pll           (i_hssi_clk_pll),
          .i_tx_pll_locked          (1'b1),
          .i_cdr_lock               (1'b1),
          
          .i_avmm_addr              (s_avmm_addr),
          .i_avmm_read              (s_avmm_read),
          .i_avmm_write             (s_avmm_write),
          .i_avmm_writedata         (s_avmm_writedata),
          .o_avmm_readdata          (s_avmm_readdata),
          .o_avmm_readdata_valid    (s_avmm_readdata_valid),
          .o_avmm_waitrequest       (s_avmm_waitrequest),
          .i_csr_port_sel           (s_csr_port_sel)
       );
     
    `else // not defined MAC_SEGMENTED, Instantiate Multi-channel SOP ethernet traffic controller top
    
    
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
		    
		    // setting up initial values for unused interfaces for simluation
		    afu_pc_st_tx[ch].tready			= 1'b0;  
		    afu_pc_st_tx[ch].tx.tvalid 			= 1'b0;
		    afu_pc_st_tx[ch].tx.tlast  			= 'b0;
		    afu_pc_st_tx[ch].tx.tdata  			= 'b0;
		    afu_pc_st_tx[ch].tx.tkeep  			= 'b0;
		    afu_pc_st_tx[ch].tx.tuser			= 'b0;
		    afu_pc_st_rx[ch].rx.tvalid 			= 1'b0;
		    afu_pc_st_rx[ch].rx.tlast			= 'b0;
		    afu_pc_st_rx[ch].rx.tdata 			= 'b0;
		    afu_pc_st_rx[ch].rx.tkeep			= 'b0;
		    afu_pc_st_rx[ch].rx.tuser.client		= 'b0;
		    afu_pc_fc[ch].tx_pause			= 'b0; 
		    afu_pc_fc[ch].tx_pfc			= 'b0;
		    afu_pc_fc[ch].rx_pause			= 'b0;
		    afu_pc_fc[ch].tx_pfc			= 'b0;
                 end
              end
           endgenerate 
                
           multi_port_axi_sop_traffic_ctrl #( 
              .NUM_ETH       (NUM_ETH_CHANNELS),
              .AVMM_DATA_W   (AVMM_DATA_W),
              .AVMM_ADDR_W   (AVMM_ADDR_W)
           ) multi_port_axi_sop_traffic_ctrl_inst (
              .clk                (clk_sys),
              .reset              (rst_sys),
        
              // AFU <-> MAC data streams
              .eth_tx_st          (afu_eth_tx_st[NUM_ETH_CHANNELS-1:0]),
              .eth_rx_st          (afu_eth_rx_st[NUM_ETH_CHANNELS-1:0]),
        
              // AFU <-> MAC sideband signals
              .eth_sideband_tx    (afu_eth_sideband_tx[NUM_ETH_CHANNELS-1:0]),
              .eth_sideband_rx    (afu_eth_sideband_rx[NUM_ETH_CHANNELS-1:0]),
        
              .i_avmm_addr        (s_avmm_addr),
              .i_avmm_read        (s_avmm_read),
              .i_avmm_write       (s_avmm_write),
              .i_avmm_writedata   (s_avmm_writedata),
              .o_avmm_readdata    (s_avmm_readdata),
              .o_avmm_waitrequest (s_avmm_waitrequest),
              .i_csr_port_sel     (s_csr_port_sel)
           );
    
    `endif // MAC_SEGMENTED

`endif //INCLUDE_CPR


endmodule // he_hssi_top


// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
// Description
//-----------------------------------------------------------------------------
//
// Ethernet Traffic AFU
//
// Generates and Checks 10G Ethernet traffic 
//-----------------------------------------------------------------------------
import ofs_fim_if_pkg::*;
import ofs_fim_pcie_hdr_def::*;
import ofs_fim_eth_if_pkg::*;

`ifdef INCLUDE_DDR4
   import ofs_fim_emif_cfg_pkg::*;
`endif

module eth_traffic_afu (
   input  logic                      clk_2x,
   input  logic                      clk_1x,
   input  logic                      clk_div4,
   input  logic                      uclk_usr,
   input  logic                      uclk_usr_div2,
   input  logic                      softreset,
   ofs_fim_pcie_rxs_axis_if.slave    afu_rx_st,
   ofs_fim_pcie_txs_axis_if.master   afu_tx_st,

`ifdef INCLUDE_DDR4
   `ifdef INCLUDE_DDR4_AXI_BRIDGE
      ofs_fim_emif_afu_axi_if.master  afu_mem_if [NUM_LOCAL_MEM_BANKS-1:0],
   `else
      ofs_fim_emif_afu_avmm_if.master afu_mem_if [NUM_LOCAL_MEM_BANKS-1:0],
   `endif
`endif

`ifdef INCLUDE_HSSI
   // AXIS data interface
   ofs_fim_eth_tx_axis_if.master          afu_eth_tx_st [NUM_ETH_CHANNELS-1:0],
   ofs_fim_eth_rx_axis_if.slave           afu_eth_rx_st [NUM_ETH_CHANNELS-1:0],
   // AXI sideband interface
   ofs_fim_eth_sideband_tx_axis_if.master afu_eth_sideband_tx [NUM_ETH_CHANNELS-1:0],
   ofs_fim_eth_sideband_rx_axis_if.slave  afu_eth_sideband_rx [NUM_ETH_CHANNELS-1:0],
   // Ethernet clocks
   t_axis_eth_clocks                      eth_clocks,
`endif

   ofs_fim_afu_irq_rsp_axis_if.slave afu_irq_rsp_if
);

// ----------- Parameters -------------
   localparam ETH_DW          = ofs_fim_eth_if_pkg::ETH_PACKET_WIDTH;
   localparam RX_ERROR_WIDTH  = ofs_fim_eth_if_pkg::ETH_RX_ERROR_WIDTH;
   localparam TX_ERROR_WIDTH  = ofs_fim_eth_if_pkg::ETH_TX_ERROR_WIDTH;
   localparam AVMM_DATA_W     = ETH_DW;
   localparam AVMM_ADDR_W     = 16;

   // ---- Logic / Struct Declarations ---
   logic [AVMM_ADDR_W-1:0]         s_avmm_addr;
   logic                           s_avmm_read;
   logic                           s_avmm_write;
   logic [AVMM_DATA_W-1:0]         s_avmm_writedata;
   logic [AVMM_DATA_W-1:0]         s_avmm_readdata;
   logic                           s_avmm_waitrequest;
   logic [2:0]                     s_csr_port_sel;
   logic            tx_clk_fim;
   logic            tx_rst_n_fim;
   logic            tx_clk_div2_fim;
   logic            tx_rst_n_div2_fim;

// Tie-off unused interface
assign afu_irq_rsp_if.tready = 1'b1;

// Clock and reset mapping
always_comb begin
   `ifdef INCLUDE_HSSI
      tx_clk_fim         = afu_eth_rx_st[0].clk;
      tx_rst_n_fim       = afu_eth_rx_st[0].rst_n;
      tx_clk_div2_fim    = eth_clocks.clkDiv2;
      tx_rst_n_div2_fim  = eth_clocks.rstDiv2_n;
   `else // standalone unit test with no MAC-PHY
      tx_clk_fim      = clk_2x;
      tx_rst_n_fim    = softreset;
      tx_clk_div2_fim = clk_1x;
   `endif
end

// Reset generation with by-2 clock for standalone unit test with no MAC-PHY
`ifndef INCLUDE_HSSI 
   altera_reset_synchronizer # (
      .ASYNC_RESET(1),
      .DEPTH      (4)  
   ) tx_half_clk_reset_synchronizer_inst(
      .clk(tx_clk_div2_fim),
      .reset_in(tx_rst_n_fim),
      .reset_out(tx_rst_n_div2_fim)
   ); 
`endif

// CSR for module for ethernet traffic AFU
   eth_traffic_pcie_tlp_to_csr  #(
      .AVMM_DATA_W   (AVMM_DATA_W),
      .AVMM_ADDR_W   (AVMM_ADDR_W)
   ) eth_traffic_pcie_tlp_to_csr_inst (
      .clk                (clk_2x),
      .rst                (softreset),
      .i_csr_axi_rx_st    (afu_rx_st),
      .o_csr_axi_tx_st    (afu_tx_st),
      .o_avmm_addr        (s_avmm_addr),
      .o_avmm_read        (s_avmm_read),
      .o_avmm_write       (s_avmm_write),
      .o_avmm_writedata   (s_avmm_writedata),
      .i_avmm_readdata    (s_avmm_readdata),
      .i_avmm_waitrequest (s_avmm_waitrequest),
      .o_csr_port_sel     (s_csr_port_sel)
   );

// Multi-channel 10G ethernet traffic controller top
   multi_port_axi_sop_traffic_ctrl #( 
      .NUM_ETH       (NUM_ETH_CHANNELS),
      .AVMM_DATA_W   (AVMM_DATA_W),
      .AVMM_ADDR_W   (AVMM_ADDR_W)
   ) multi_port_axi_traffic_ctrl_inst (
      .clk                        (clk_2x),
      .reset                      (softreset),
      .tx_clk_312                 (tx_clk_fim),
      .rx_clk_312                 (tx_clk_fim),
      .tx_clk_156                 (tx_clk_div2_fim),
      .rx_clk_156                 (tx_clk_div2_fim),
      .tx_rst_n                   (tx_rst_n_fim),
      .rx_rst_n                   (tx_rst_n_fim),
      .tx_rst_n_div2              (tx_rst_n_div2_fim),
      .rx_rst_n_div2              (tx_rst_n_div2_fim),

      // AFU <-> MAC data streams
      .eth_tx_st                  (afu_eth_tx_st),
      .eth_rx_st                  (afu_eth_rx_st),

      // AFU <-> MAC sideband signals
      .eth_sideband_tx            (afu_eth_sideband_tx),
      .eth_sideband_rx            (afu_eth_sideband_rx),

      .i_avmm_addr                (s_avmm_addr),
      .i_avmm_read                (s_avmm_read),
      .i_avmm_write               (s_avmm_write),
      .i_avmm_writedata           (s_avmm_writedata),
      .o_avmm_readdata            (s_avmm_readdata),
      .o_avmm_waitrequest         (s_avmm_waitrequest),
      .i_csr_port_sel             (s_csr_port_sel)
   );

endmodule // eth_traffic_afu

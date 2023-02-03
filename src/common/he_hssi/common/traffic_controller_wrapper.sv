// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
// Description
//-----------------------------------------------------------------------------
//
// Traffic Controller wrapper
//
// Instantiates traffic controller, address decoder, sc_fifo and avst adapter
//
//-----------------------------------------------------------------------------
import ofs_fim_eth_avst_if_pkg::*;

module traffic_controller_wrapper (
   input logic      csr_clk,
   input logic      csr_rst_n,
   input logic      tx_rst_n,
   input logic      rx_rst_n,

   input tx_clk_156,
   input rx_clk_156,
   // Client traffic TX
   input   logic                                 i_tx_traffic_ready,
   output  logic  [AVST_ETH_PACKET_WIDTH-1:0]    o_tx_traffic_data,
   output  logic                                 o_tx_traffic_valid,
   output  logic                                 o_tx_traffic_startofpacket,
   output  logic                                 o_tx_traffic_endofpacket,
   output  logic  [AVST_ETH_EMPTY_WIDTH-1:0]     o_tx_traffic_empty,
   output  logic                                 o_tx_traffic_error,
   // Client traffic RX
   output logic                                  o_rx_traffic_ready,
   input  logic  [AVST_ETH_PACKET_WIDTH-1:0]     i_rx_traffic_data,
   input  logic                                  i_rx_traffic_valid,
   input  logic                                  i_rx_traffic_startofpacket,
   input  logic                                  i_rx_traffic_endofpacket,
   input  logic  [AVST_ETH_EMPTY_WIDTH-1:0]      i_rx_traffic_empty,
   input  logic  [5:0]                           i_rx_traffic_error,
   // MAC sideband signal
   output logic  [1:0]   o_avalon_st_pause_data,
   output logic  [7:0]   o_avalon_st_pfc_pause_data,
   // csr interface
   input logic          csr_read,
   input logic          csr_write,
   input logic  [31:0]  csr_writedata,
   output logic [31:0]  csr_readdata,
   input logic  [15:0]  csr_address,
   output logic         csr_waitrequest
);

parameter   DEVICE_FAMILY           = "Stratix 10";
logic  [31:0]  avalon_st_pause_data, avalon_st_pfc_pause_data;
logic          csr_read_q, csr_read_extend, csr_read_extend_q , sync_csr_read;
logic          csr_write_q, csr_write_extend, csr_write_extend_q,  sync_csr_write;
logic  [31:0]  sync_csr_writedata;
logic  [31:0]  sync_csr_readdata;
logic  [31:0]  sync_csr_readdata_q;
logic  [15:0]  sync_csr_address;
logic          sync_csr_waitrequest;
logic          sync_csr_waitrequest_q;

always_ff @ (posedge tx_clk_156) begin
   if (~tx_rst_n) begin
      avalon_st_pause_data <= 'h0;
   end else if (sync_csr_write && (sync_csr_address == 'h380E)) begin
      avalon_st_pause_data <= sync_csr_writedata;
   end
end

always_ff @ (posedge tx_clk_156) begin
   if (~tx_rst_n) begin
      avalon_st_pfc_pause_data <= 'h0;
   end else if (sync_csr_write && (sync_csr_address == 'h380F)) begin
      avalon_st_pfc_pause_data <= sync_csr_writedata;
   end
end

assign o_avalon_st_pause_data = avalon_st_pause_data[1:0];
assign o_avalon_st_pfc_pause_data = avalon_st_pfc_pause_data[7:0];

// Pulse sync for signals crossing faster clock to slower clock
always_ff @ (posedge csr_clk) begin
   csr_read_q  <= csr_read;
   csr_write_q <= csr_write;
end

always_ff @ (posedge tx_clk_156) begin
   sync_csr_waitrequest_q  <= sync_csr_waitrequest;
   sync_csr_readdata_q     <= sync_csr_readdata;
end

fim_cross_strobe  #(
   .SYNC_NO_CUT (0)
) read_sync (
   .din_clk    (csr_clk),
   .din_srst   (~csr_rst_n),
   .din_pulse  (~csr_read_q & csr_read),

   .dout_clk   (tx_clk_156),
   .dout_srst  (~tx_rst_n),
   .dout_pulse (sync_csr_read)   
);

fim_cross_strobe #(
   .SYNC_NO_CUT (0)
) write_sync (
   .din_clk    (csr_clk),
   .din_srst   (~csr_rst_n),
   .din_pulse  (~csr_write_q & csr_write),

   .dout_clk   (tx_clk_156),
   .dout_srst  (~tx_rst_n),
   .dout_pulse (sync_csr_write)   
);

fim_cross_strobe #(
   .SYNC_NO_CUT (0)
) csr_waitrequest_sync (
   .din_clk    (tx_clk_156),
   .din_srst   (~tx_rst_n),
   .din_pulse  (sync_csr_waitrequest_q),   

   .dout_clk   (csr_clk),
   .dout_srst  (~csr_rst_n),
   .dout_pulse (csr_waitrequest)
);

fim_resync #(
   . SYNC_CHAIN_LENGTH (2),   // Number of flip-flops for retiming. Must be >1
   . WIDTH             (16),  // Number of bits to resync
   . INIT_VALUE        (0),
   . NO_CUT	           (0)	  // See description above
)csr_address_sync(
   . clk  (tx_clk_156),
   . reset(1'b0),
   . d(csr_address[15:0]),
   . q(sync_csr_address )
);

fim_resync #(
   . SYNC_CHAIN_LENGTH (2),   // Number of flip-flops for retiming. Must be >1
   . WIDTH             (32),  // Number of bits to resync
   . INIT_VALUE        (0),
   . NO_CUT	           (0)	  // See description above
)csr_writedata_sync(
   . clk  (tx_clk_156),
   . reset(1'b0),
   . d(csr_writedata),
   . q(sync_csr_writedata )
);

fim_resync #(
   . SYNC_CHAIN_LENGTH (2),  // Number of flip-flops for retiming. Must be >1
   . WIDTH             (32),  // Number of bits to resync
   . INIT_VALUE        (0),
   . NO_CUT	           (0)	  // See description above
)csr_readdata_sync(
   . clk  (csr_clk),
   . reset(1'b0),
   . d(sync_csr_readdata_q),
   . q(csr_readdata)
);


// generator and checker and also loopback
`ifndef ETH_100G
eth_std_traffic_controller_top #(
`ifdef DISABLE_HE_HSSI_CRC
   .CRC_EN        (0),
`endif
   .DEVICE_FAMILY (DEVICE_FAMILY)
) gen_mon_inst (
   .clk                 (tx_clk_156),
   .reset_n             (tx_rst_n),

   .avl_mm_read         (sync_csr_read),
   .avl_mm_write        (sync_csr_write),
   .avl_mm_waitrequest  (sync_csr_waitrequest),
   .avl_mm_baddress     (sync_csr_address[11:0]),
   .avl_mm_readdata     (sync_csr_readdata),
   .avl_mm_writedata    (sync_csr_writedata),

   .mac_rx_status_data  (40'b0),
   .mac_rx_status_valid (1'b0),
   .mac_rx_status_error (1'b0),
   .stop_mon            (1'b0),
   .mon_active          (),
   .mon_done            (),
   .mon_error           (),

   .avl_st_tx_data      (o_tx_traffic_data),
   .avl_st_tx_empty     (o_tx_traffic_empty),
   .avl_st_tx_eop       (o_tx_traffic_endofpacket),
   .avl_st_tx_error     (o_tx_traffic_error),
   .avl_st_tx_ready     (i_tx_traffic_ready),
   .avl_st_tx_sop       (o_tx_traffic_startofpacket),
   .avl_st_tx_val       (o_tx_traffic_valid),

   .avl_st_rx_data      (i_rx_traffic_data),
   .avl_st_rx_empty     (i_rx_traffic_empty),
   .avl_st_rx_eop       (i_rx_traffic_endofpacket),
   .avl_st_rx_error     (i_rx_traffic_error),
   .avl_st_rx_ready     (o_rx_traffic_ready),
   .avl_st_rx_sop       (i_rx_traffic_startofpacket),
   .avl_st_rx_val       (i_rx_traffic_valid)
);
`else
alt_e100s10_packet_client #(
   .WORDS                    (8),
   .WIDTH                    (64),
   .EMPTY_WIDTH              (6)
) gen_inst (
   .i_arst                   (~(tx_rst_n & rx_rst_n)),
   .i_clk_tx                 (tx_clk_156),
   .o_tx_valid               (o_tx_traffic_valid),
   .i_tx_ready               (i_tx_traffic_ready),
   .o_tx_data                (o_tx_traffic_data),
   .o_tx_sop                 (o_tx_traffic_startofpacket),
   .o_tx_eop                 (o_tx_traffic_endofpacket),
   .o_tx_empty               (o_tx_traffic_empty),
   .i_clk_rx                 (rx_clk_156),
   .i_rx_valid               (i_rx_traffic_valid),
   .i_rx_data                (i_rx_traffic_data),
   .i_rx_sop                 (i_rx_traffic_startofpacket),
   .i_rx_eop                 (i_rx_traffic_endofpacket),
   .i_rx_empty               (i_rx_traffic_empty),
   .i_rx_error               (i_rx_traffic_error),
   .i_clk_status             (tx_clk_156),
   .i_status_addr            (sync_csr_address[15:0]),
   .i_status_read            (sync_csr_read),
   .i_status_write           (sync_csr_write),
   .i_status_writedata       (sync_csr_writedata),
   .o_status_readdata        (sync_csr_readdata),
   .o_status_readdata_valid  ()
);

assign o_rx_traffic_ready   = 1'b1;
assign o_tx_traffic_error   = 1'b0;

always_ff @ (posedge tx_clk_156) begin
   if (~tx_rst_n) begin
      sync_csr_waitrequest <= 'h0;
   end else if (sync_csr_waitrequest) begin
      sync_csr_waitrequest <= 'h0;
   end else if (sync_csr_write || sync_csr_read) begin
      sync_csr_waitrequest <= 'h1;
   end
end
`endif

endmodule  //traffic_controller_wrapper

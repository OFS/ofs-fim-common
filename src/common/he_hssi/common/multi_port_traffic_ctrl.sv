// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
// Description
//-----------------------------------------------------------------------------
//
// Multi-Port Traffic Controller
// 
// Instantiates traffic controller based on number of Ethernet
// channels
//-----------------------------------------------------------------------------

module multi_port_traffic_ctrl #(
   parameter NUM_ETH            = 1,  // Number of Ethernet lanes
   parameter AVMM_DATA_W        = 32, // Data width
   parameter AVMM_ADDR_W        = 16  // AVMM address width
)( // Clock and reset
   input                             clk,
   input                             reset,

   // AFU/MAC traffic
   ofs_fim_eth_tx_avst_if.master     eth_tx_st[NUM_ETH-1:0],
   ofs_fim_eth_rx_avst_if.slave      eth_rx_st[NUM_ETH-1:0],

   // AFU/MAC sideband
   ofs_fim_eth_sideband_tx_avst_if.master eth_sideband_tx [NUM_ETH-1:0],
   ofs_fim_eth_sideband_rx_avst_if.slave  eth_sideband_rx [NUM_ETH-1:0],

   // Avalon-MM Interface
   input  logic [AVMM_ADDR_W-1:0]    i_avmm_addr,        // AVMM address
   input  logic                      i_avmm_read,        // AVMM read request
   input  logic                      i_avmm_write,       // AVMM write request
   input  logic [AVMM_DATA_W-1:0]    i_avmm_writedata,   // AVMM write data
   output logic [AVMM_DATA_W-1:0]    o_avmm_readdata,    // AVMM read data
   output logic                      o_avmm_waitrequest, // AVMM wait request
   input  logic [3:0]                i_csr_port_sel      // Lane select for CSR
);

////////////////////////////////////////////////////////////////////////////////
// MAC signals
////////////////////////////////////////////////////////////////////////////////

logic [NUM_ETH-1:0][AVMM_DATA_W-1:0] csr_readdata;
logic [NUM_ETH-1:0]                  csr_waitrequest;

generate
   for (genvar nume=0; nume<NUM_ETH; nume++) begin : GenTrafWrap
      logic                   csr_read;
      logic                   csr_write;
      logic [AVMM_DATA_W-1:0] csr_writedata /* synthesis preserve */;
      logic [AVMM_ADDR_W-1:0] csr_address   /* synthesis preserve */;
            
      logic [1:0] o_avalon_st_pause_data;
      logic [7:0] o_avalon_st_pfc_pause_data;

      traffic_controller_wrapper traffic_controller_wrapper (
         //clock
         .csr_clk                    (clk),
         .tx_clk_156                 (eth_tx_st[nume].clk),
         .rx_clk_156                 (eth_rx_st[nume].clk),
         //reset
         .csr_rst_n                  (!reset),
         .tx_rst_n                   (eth_tx_st[nume].rst_n),
         .rx_rst_n                   (eth_rx_st[nume].rst_n),
         //data
         // Client traffic TX
         .i_tx_traffic_ready         (eth_tx_st[nume].ready),
         .o_tx_traffic_data          (eth_tx_st[nume].tx.data),
         .o_tx_traffic_valid         (eth_tx_st[nume].tx.valid),
         .o_tx_traffic_startofpacket (eth_tx_st[nume].tx.sop),
         .o_tx_traffic_endofpacket   (eth_tx_st[nume].tx.eop),
         .o_tx_traffic_empty         (eth_tx_st[nume].tx.empty),
         .o_tx_traffic_error         (eth_tx_st[nume].tx.user.error),
         // Client traffic RX
         .o_rx_traffic_ready         (eth_rx_st[nume].ready),
         .i_rx_traffic_data          (eth_rx_st[nume].rx.data),
         .i_rx_traffic_valid         (eth_rx_st[nume].rx.valid),
         .i_rx_traffic_startofpacket (eth_rx_st[nume].rx.sop),
         .i_rx_traffic_endofpacket   (eth_rx_st[nume].rx.eop),
         .i_rx_traffic_empty         (eth_rx_st[nume].rx.empty),
         .i_rx_traffic_error         (eth_rx_st[nume].rx.user.error),
         // AFU to MAC sideband signal
         .o_avalon_st_pause_data     (o_avalon_st_pause_data),
         .o_avalon_st_pfc_pause_data (o_avalon_st_pfc_pause_data),
         // csr interface
         .csr_read                   (csr_read),
         .csr_write                  (csr_write),
         .csr_writedata              (csr_writedata),
         .csr_readdata               (csr_readdata[nume]),
         .csr_address                (csr_address),
         .csr_waitrequest            (csr_waitrequest[nume])
      );
      
      always_comb begin // sideband mapping
         eth_sideband_tx[nume].sb.data.pause_xoff = o_avalon_st_pause_data[1];
         eth_sideband_tx[nume].sb.data.pause_xon  = o_avalon_st_pause_data[0];
         eth_sideband_tx[nume].sb.data.pfc_xoff   = o_avalon_st_pfc_pause_data;
         eth_sideband_tx[nume].sb.valid = 1'b1;
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
   o_avmm_waitrequest = csr_waitrequest[i_csr_port_sel];
   o_avmm_readdata    = csr_readdata[i_csr_port_sel];
end


endmodule //multi_port_traffic_ctrl

// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
// Description
//-----------------------------------------------------------------------------
//
// PCIe TLP <-> AXI-lite Bridge 
//
//-----------------------------------------------------------------------------

`timescale 1ps / 1ps
import ofs_csr_pkg::*;

module st2mm #(
   parameter PF_NUM            = 0,
   parameter VF_NUM            = 0,
   parameter VF_ACTIVE         = 0,
   parameter MM_ADDR_WIDTH     = 19, 
   parameter MM_DATA_WIDTH     = 64,
   parameter READ_ALLOWANCE    = 1,
   parameter WRITE_ALLOWANCE   = 64,
   parameter TX_VDM_OFFSET     = 16'h2000,
   parameter RX_VDM_OFFSET     = 16'h2000,
   parameter PMCI_BASEADDR     = 18'h20000,
   parameter FEAT_ID           = 12'h0,
   parameter FEAT_VER          = 4'h0,
   parameter END_OF_LIST       = 1'b0,
   parameter NEXT_DFH_OFFSET   = 24'h1000
)(
    input wire                  clk,
    input wire                  rst_n,

    input wire                  clk_csr,
    input wire                  rst_n_csr,

    input logic                 flr_rst_n,
    output logic                flr_ack,
    
    pcie_ss_axis_if.sink        axis_rx_if,
    pcie_ss_axis_if.source      axis_tx_if,

    ofs_fim_axi_lite_if         axi_m_pmci_vdm_if,
    ofs_fim_axi_lite_if         axi_m_if,
    ofs_fim_axi_lite_if.slave   axi_s_if
    // ofs_fim_axi_lite_if.slave   axi_s_pmci_vdm_if
);

import pcie_ss_hdr_pkg::*;

pcie_ss_axis_if st2mm_rx_if(.clk (clk_csr), .rst_n(rst_n_csr));
pcie_ss_axis_if st2mm_tx_if(.clk (clk_csr), .rst_n(rst_n_csr));
pcie_ss_axis_if st2mm_tx_p_if[1:0](.clk(clk_csr), .rst_n(rst_n_csr));

pcie_ss_axis_if    st2mm_tx_st[1:0](.clk(clk_csr), .rst_n(rst_n_csr));

logic                         csr_sop;
logic                         csr_eop;
logic                         csr_val;
logic [MM_DATA_WIDTH-1:0]     csr_pld;
csr_access_type_t             csr_type;
logic                         csr_rdy;

logic                           msix_strb;
logic   [15:0]                  msix_num;
logic                           msix_ready;


// Tx MuX
always_comb begin
   st2mm_tx_st[0].tready        = 1'b0;
   st2mm_tx_st[1].tready        = 1'b0; 
   st2mm_tx_if.tvalid           = 1'b0;
   
   case ( { st2mm_tx_st[0].tvalid } )
      // PRIORITY #1 = MMIO
      1'b1: begin
         st2mm_tx_st[0].tready        = st2mm_tx_if.tready;
         st2mm_tx_if.tvalid           = st2mm_tx_st[0].tvalid;
         st2mm_tx_if.tlast            = st2mm_tx_st[0].tlast;
         st2mm_tx_if.tuser_vendor     = st2mm_tx_st[0].tuser_vendor;
         st2mm_tx_if.tdata            = st2mm_tx_st[0].tdata;
         st2mm_tx_if.tkeep            = st2mm_tx_st[0].tkeep;
      end
      
      // PRIORITY #2 = MSIX
      default: begin
         st2mm_tx_st[1].tready        = st2mm_tx_if.tready;       
         st2mm_tx_if.tvalid           = st2mm_tx_st[1].tvalid;
         st2mm_tx_if.tlast            = st2mm_tx_st[1].tlast;
         st2mm_tx_if.tuser_vendor     = st2mm_tx_st[1].tuser_vendor;
         st2mm_tx_if.tdata            = st2mm_tx_st[1].tdata;
         st2mm_tx_if.tkeep            = st2mm_tx_st[1].tkeep;
      end  
   endcase
end


//---------------------------------
// ST2MM FLR reset 
//---------------------------------
logic flr_rst_n_q;

always_ff @(posedge clk) begin
   flr_rst_n_q <= flr_rst_n;
end

always_ff @(posedge clk) begin
   flr_ack <= 1'b0;
   if (flr_rst_n_q && ~flr_rst_n) begin
      flr_ack <= 1'b1;
   end

   if (~rst_n) begin
      flr_ack <= 1'b0;
   end
end

//---------------------------------
// Clock crossing to CSR clock domain 
//---------------------------------
pcie_axis_cdc_fifo #(
   .DEPTH_LOG2        (6),
   .ALMFULL_THRESHOLD (4)
) rx_cdc_fifo (
   .snk_clk     (clk),
   .snk_rst_n   (rst_n),
   .src_clk     (clk_csr),
   .src_rst_n   (rst_n_csr),
   .snk_if      (axis_rx_if),
   .src_if      (st2mm_rx_if)
);

pcie_axis_cdc_fifo #(
   .DEPTH_LOG2        (6),
   .ALMFULL_THRESHOLD (4)
) tx_cdc_fifo (
   .snk_clk     (clk_csr       ),
   .snk_rst_n   (rst_n_csr     ),
   .src_clk     (clk           ),
   .src_rst_n   (rst_n         ),
   .snk_if      (st2mm_tx_if   ),
   .src_if      (axis_tx_if    )
);

//---------------------------------
// ST2MM RX bridge 
//---------------------------------
logic                                           tlp_rd;
logic [pcie_ss_hdr_pkg::PCIE_TAG_WIDTH-1:0]     tlp_rd_tag;
logic [1:0]                                     tlp_rd_length;
logic [15:0]                                    tlp_rd_req_id;
logic [pcie_ss_hdr_pkg::LOWER_ADDR_WIDTH-1:0]   tlp_rd_lower_addr;
logic [2:0]                                     tlp_attr;
logic [2:0]                                     tlp_tc;


st2mm_rx_bridge #(
    .MM_ADDR_WIDTH    (MM_ADDR_WIDTH),
    .MM_DATA_WIDTH    (MM_DATA_WIDTH),
    .PMCI_BASEADDR    (PMCI_BASEADDR),
    .VDM_OFFSET       (RX_VDM_OFFSET),   
    .READ_ALLOWANCE   (READ_ALLOWANCE),
    .WRITE_ALLOWANCE  (WRITE_ALLOWANCE)
)
st2mm_rx_bridge (
   .clk                  (clk_csr),
   .rst_n                (rst_n_csr),
  
   .rx_st_if             (st2mm_rx_if),
   .axi_m_if             (axi_m_if),
   .axi_m_pmci_vdm_if    (axi_m_pmci_vdm_if),

   .o_tlp_rd             (tlp_rd),
   .o_tlp_rd_tag         (tlp_rd_tag),
   .o_tlp_rd_length      (tlp_rd_length),
   .o_tlp_rd_req_id      (tlp_rd_req_id),
   .o_tlp_rd_lower_addr  (tlp_rd_lower_addr),
   .o_tlp_attr           (tlp_attr),
   .o_tlp_tc             (tlp_tc)
);

//---------------------------------
// ST2MM RX bridge 
//---------------------------------
st2mm_tx_bridge #(
    .PF_NUM           (PF_NUM),
    .VF_NUM           (VF_NUM),
    .VF_ACTIVE        (VF_ACTIVE),
    .MM_ADDR_WIDTH    (MM_ADDR_WIDTH),
    .MM_DATA_WIDTH    (MM_DATA_WIDTH),
    .READ_ALLOWANCE   (READ_ALLOWANCE)
)
st2mm_tx_bridge (
   .clk                  (clk_csr),
   .rst_n                (rst_n_csr),
  
   .tx_st_if             (st2mm_tx_p_if[0]),
   .axi_m_if             (axi_m_if),

   .i_tlp_rd             (tlp_rd),
   .i_tlp_rd_tag         (tlp_rd_tag),
   .i_tlp_rd_length      (tlp_rd_length),
   .i_tlp_rd_req_id      (tlp_rd_req_id),
   .i_tlp_rd_lower_addr  (tlp_rd_lower_addr),
   .i_tlp_attr           (tlp_attr),
   .i_tlp_tc             (tlp_tc)
);

//--------------------------------------------
// MSIX Bridge
//---------------------------------------------
axis_tx_msix_bridge #(
    .PF_NUM             (PF_NUM),
    .VF_NUM             (VF_NUM),
    .VF_ACTIVE          (VF_ACTIVE)
)
axis_tx_msix_bridge (
    .clk                            (clk_csr),
    .rst_n                          (rst_n_csr),
    
    .axis_tx_if                     (st2mm_tx_st[1]),
    .axis_tx_error                  ( ),
    
    .msix_strb                      (msix_strb),
    .msix_num                       (msix_num),
    .msix_ready                     (msix_ready)
);

//---------------------------------
// ST2MM CSR 
//---------------------------------
st2mm_csr #(
    .ADDR_WIDTH       (MM_ADDR_WIDTH),
    .DATA_WIDTH       (MM_DATA_WIDTH),
    .TX_VDM_OFFSET    (TX_VDM_OFFSET),
    .FEAT_ID          (FEAT_ID),
    .FEAT_VER         (FEAT_VER),
    .NEXT_DFH_OFFSET  (NEXT_DFH_OFFSET),
    .END_OF_LIST      (END_OF_LIST)
) st2mm_csr (
    .clk          (clk_csr),
    .rst_n        (rst_n_csr),
    .msix_strb    (msix_strb),
    .msix_num     (msix_num),
    .msix_ready   (msix_ready),
    
    .csr_lite_if  (axi_s_if),
	//.vdm_csr_lite_if  (axi_s_pmci_vdm_if),
    .o_csr_sop    (csr_sop),
    .o_csr_eop    (csr_eop),
    .o_csr_val    (csr_val),
    .o_csr_pld    (csr_pld),
    .o_csr_type   (csr_type),
    .i_csr_rdy    (csr_rdy)
);

//---------------------------------
// MCTP TX Bridge
//---------------------------------

mctp_tx_bridge #(
    .PF_NUM        (PF_NUM),
    .VF_NUM        (VF_NUM),
    .VF_ACTIVE     (VF_ACTIVE),
    .TDATA_W       (axis_rx_if.DATA_W),
    .TUSER_W       (axis_rx_if.USER_W)
) mctp_tx_bridge (
   .clk             (clk_csr),
   .rst             (~rst_n_csr),
   .o_tx_st         (st2mm_tx_p_if[1]),
   .i_csr_sop       (csr_sop),
   .i_csr_eop       (csr_eop),
   .i_csr_val       (csr_val),
   .i_csr_pld       (csr_pld),
   .i_csr_type      (csr_type),
   .o_csr_rdy       (csr_rdy)
);

//---------------------------------
// umsg & mmio arb
//---------------------------------

pcie_axis_mux #(
   .NUM_CH          (2),
   .TDATA_WIDTH     (axis_rx_if.DATA_W),
   .TUSER_WIDTH     (axis_rx_if.USER_W)
) axis_mux (
   .clk             (clk_csr),
   .rst_n           (rst_n_csr),
   .sink            (st2mm_tx_p_if),
   .source          (st2mm_tx_st[0])
);

endmodule : st2mm

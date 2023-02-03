// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
// Description
//-----------------------------------------------------------------------------
//
// Generic PCIe TLP to simple CSR read/write interface. AFU-generated PCIe
// DMA is not supported.
//
//-----------------------------------------------------------------------------
import ofs_csr_pkg::*;

module pcie_tlp_to_csr_no_dma #(
   parameter PF_NUM            = 0,
   parameter VF_NUM            = 0,
   parameter VF_ACTIVE         = 0,
   parameter MM_ADDR_WIDTH     = 18, 
   parameter MM_DATA_WIDTH     = 64
)(
   input                                   clk,
   input                                   rst_n,

   pcie_ss_axis_if.sink                    axis_rx_if,
   pcie_ss_axis_if.source                  axis_tx_if,
   
   input  logic                            avmm_s2m_readdatavalid,
   input  logic   [MM_DATA_WIDTH-1:0]      avmm_s2m_readdata,
   input  logic                            avmm_s2m_waitrequest,
   input  logic                            avmm_s2m_writeresponsevalid, 
   
   output logic                            avmm_m2s_write,
   output logic                            avmm_m2s_read,
   output logic   [MM_ADDR_WIDTH-1:0]      avmm_m2s_address,
   output logic   [MM_DATA_WIDTH-1:0]      avmm_m2s_writedata,
   output logic   [(MM_DATA_WIDTH>>3)-1:0] avmm_m2s_byteenable, 
   output logic   [7:0]                    axis_rx_fmttype,
   output  logic  [13:0]                   axis_rx_length,
   output logic   [63:0]                   axis_rx_addr
);


logic                               tlp_rd_strb;
logic   [9:0]                       tlp_rd_tag;
logic   [13:0]                      tlp_rd_length;
logic   [15:0]                      tlp_rd_req_id;
logic   [23:0]                      tlp_rd_low_addr;

axis_rx_mmio_bridge #(
   .AVMM_ADDR_WIDTH    (MM_ADDR_WIDTH), 
   .AVMM_DATA_WIDTH    (MM_DATA_WIDTH)
)
axis_rx_mmio_bridge (
   .clk                            (clk),
   .rst_n                          (rst_n),
   
   .axis_rx_if                     (axis_rx_if),
   
   .avmm_s2m_waitrequest           (avmm_s2m_waitrequest),
   .avmm_s2m_writeresponsevalid    (avmm_s2m_writeresponsevalid),
   .avmm_s2m_readdatavalid         (avmm_s2m_readdatavalid),
   
   .avmm_m2s_write                 (avmm_m2s_write),
   .avmm_m2s_read                  (avmm_m2s_read),
   .avmm_m2s_address               (avmm_m2s_address),
   .avmm_m2s_writedata             (avmm_m2s_writedata),
   .avmm_m2s_byteenable            (avmm_m2s_byteenable),
   
   .tlp_rd_strb                    (tlp_rd_strb),
   .tlp_rd_tag                     (tlp_rd_tag),
   .tlp_rd_length                  (tlp_rd_length),
   .tlp_rd_req_id                  (tlp_rd_req_id),
   .tlp_rd_low_addr                (tlp_rd_low_addr),

   .axis_rx_fmttype                (axis_rx_fmttype),
   .axis_rx_length                 (axis_rx_length),
   .axis_rx_addr                   (axis_rx_addr)
);

axis_tx_mmio_bridge #(
   .PF_NUM             (PF_NUM),
   .VF_NUM             (VF_NUM),
   .VF_ACTIVE          (VF_ACTIVE),
   .AVMM_DATA_WIDTH    (MM_DATA_WIDTH)
)
axis_tx_mmio_bridge (
   .clk                            (clk),
   .rst_n                          (rst_n),
   
   .axis_tx_if                     (axis_tx_if),

   .avmm_s2m_readdatavalid         (avmm_s2m_readdatavalid),
   .avmm_s2m_readdata              (avmm_s2m_readdata),

   .tlp_rd_strb                    (tlp_rd_strb),
   .tlp_rd_tag                     (tlp_rd_tag),
   .tlp_rd_length                  (tlp_rd_length),
   .tlp_rd_req_id                  (tlp_rd_req_id),
   .tlp_rd_low_addr                (tlp_rd_low_addr)
);

endmodule

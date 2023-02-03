// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
// Description
//-----------------------------------------------------------------------------
//
// Generic PCIe TLP to simple CSR AVMM read/write interface.
//
//-----------------------------------------------------------------------------
import ofs_csr_pkg::*;

module csr_bridge #(
   parameter PF_NUM            =  0,
   parameter VF_NUM            =  0,
   parameter VF_ACTIVE         =  0,
   parameter MM_ADDR_WIDTH     = 18, 
   parameter MM_DATA_WIDTH     = 64
)(
   input                   clk,
   input                   rst_n,
   
   pcie_ss_axis_if.sink    axis_rx_if,
   pcie_ss_axis_if.source  axis_tx_if,
   
   ofs_avmm_if.source      csr_if
);

logic                               tlp_rd_strb;
logic   [9:0]                       tlp_rd_tag;
logic   [13:0]                      tlp_rd_length;
logic   [15:0]                      tlp_rd_req_id;
logic   [23:0]                      tlp_rd_low_addr;

assign csr_if.clk   = clk;
assign csr_if.rst_n = rst_n;
assign csr_if.burstcount = 0;

axis_rx_mmio_bridge #(
   .AVMM_ADDR_WIDTH    (csr_if.ADDR_W), 
   .AVMM_DATA_WIDTH    (csr_if.DATA_W)
) axis_rx_bridge (
   .clk                            (clk),
   .rst_n                          (rst_n),
   
   .axis_rx_if                     (axis_rx_if),
   
   .avmm_s2m_waitrequest           (csr_if.waitrequest),
   .avmm_s2m_writeresponsevalid    (csr_if.writeresponsevalid),
   
   .avmm_s2m_readdatavalid         (csr_if.readdatavalid),
   
   .avmm_m2s_write                 (csr_if.write),
   .avmm_m2s_read                  (csr_if.read),
   .avmm_m2s_address               (csr_if.address),
   .avmm_m2s_writedata             (csr_if.writedata),
   .avmm_m2s_byteenable            (csr_if.byteenable),
   
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
axis_tx_bridge (
   .clk                            (clk),
   .rst_n                          (rst_n),
   
   .axis_tx_if                     (axis_tx_if),
   
   .avmm_s2m_readdatavalid         (csr_if.readdatavalid),
   .avmm_s2m_readdata              (csr_if.readdata),
   
   .tlp_rd_strb                    (tlp_rd_strb),
   .tlp_rd_tag                     (tlp_rd_tag),
   .tlp_rd_length                  (tlp_rd_length),
   .tlp_rd_req_id                  (tlp_rd_req_id),
   .tlp_rd_low_addr                (tlp_rd_low_addr)
);

endmodule

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

import pcie_ss_hdr_pkg::*;

module st2mm_tx_bridge #(
   parameter PF_NUM            = 0,
   parameter VF_NUM            = 0,
   parameter VF_ACTIVE         = 0,
   parameter MM_ADDR_WIDTH     = 19, 
   parameter MM_DATA_WIDTH     = 64,
   parameter READ_ALLOWANCE    = 1
)(
    input wire clk,
    input wire rst_n,

    pcie_ss_axis_if.source     tx_st_if,

    ofs_fim_axi_lite_if.rsp    axi_m_if,
    ofs_fim_axi_lite_if.rsp    fake_rsp_csr_if,

    input logic                                           i_tlp_rd,
    input logic [pcie_ss_hdr_pkg::PCIE_TAG_WIDTH-1:0]     i_tlp_rd_tag,
    input logic [1:0]                                     i_tlp_rd_length,
    input logic [15:0]                                    i_tlp_rd_req_id,
    input logic [pcie_ss_hdr_pkg::LOWER_ADDR_WIDTH-1:0]   i_tlp_rd_lower_addr,
    input logic [2:0]                                     i_tlp_attr,
    input logic [2:0]                                     i_tlp_tc


);

mmio_rsp_bridge #(
   .MM_DATA_WIDTH  (MM_DATA_WIDTH),
   .PF_NUM         (PF_NUM),
   .VF_NUM         (VF_NUM),
   .VF_ACTIVE      (VF_ACTIVE),
   .READ_ALLOWANCE (READ_ALLOWANCE),
   .TAG_WIDTH      (PCIE_TAG_WIDTH)
) 
mmio_rsp_bridge (
   .clk     (clk),
   .rst_n   (rst_n),

   .o_tx_st (tx_st_if),

   .i_tlp_rd              (i_tlp_rd),
   .i_tlp_rd_tag          (i_tlp_rd_tag),
   .i_tlp_rd_length       (i_tlp_rd_length),
   .i_tlp_rd_req_id       (i_tlp_rd_req_id),
   .i_tlp_rd_lower_addr   (i_tlp_rd_lower_addr),

   .i_tlp_attr            (i_tlp_attr),
   .i_tlp_tc              (i_tlp_tc),

   .axi_m_if              (axi_m_if),
   .fake_rsp_csr_if       (fake_rsp_csr_if)
);

endmodule : st2mm_tx_bridge

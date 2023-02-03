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

module st2mm_rx_bridge #(
   parameter MM_ADDR_WIDTH     = 19, 
   parameter MM_DATA_WIDTH     = 64,
   parameter PMCI_BASEADDR     = 18'h20000,
   parameter VDM_OFFSET        = 16'h2000,
   parameter READ_ALLOWANCE    = 1,
   parameter WRITE_ALLOWANCE   = 6
)(
    input wire clk,
    input wire rst_n,

    pcie_ss_axis_if.sink       rx_st_if,

    ofs_fim_axi_lite_if.req    axi_m_if,
    ofs_fim_axi_lite_if.req    axi_m_pmci_vdm_if,
    ofs_fim_axi_lite_if.req    fake_rsp_csr_if,

    output logic                                         o_tlp_rd,
    output logic [pcie_ss_hdr_pkg::PCIE_TAG_WIDTH-1:0]   o_tlp_rd_tag,
    output logic [1:0]                                   o_tlp_rd_length,
    output logic [15:0]                                  o_tlp_rd_req_id,
    output logic [pcie_ss_hdr_pkg::LOWER_ADDR_WIDTH-1:0] o_tlp_rd_lower_addr,
    output logic [2:0]                                   o_tlp_attr,
    output logic [2:0]                                   o_tlp_tc

);

pcie_ss_axis_if mmio_rx_if (.clk (clk), .rst_n(rst_n));
pcie_ss_axis_if umsg_rx_if (.clk (clk), .rst_n(rst_n));

//---------------------------------
// Packet filter
//---------------------------------
st2mm_packet_filter st2mm_pkt_filter (
   .clk          (clk),
   .rst_n        (rst_n),

   .rx_st_if     (rx_st_if),

   .mmio_st_if   (mmio_rx_if),
   .umsg_st_if   (umsg_rx_if)
);

//---------------------------------
// PCIe VDM handler 
//---------------------------------
//always_comb begin
//   umsg_rx_if.tready = 1'b1;
//end

//---------------------------------
// PMCI VDM request bridge
//---------------------------------
// Sends VDM TLP to AXI memory write/read request
mctp_rx_bridge #(
  .MAX_BUF_DEPTH      (32),
  .MM_DATA_WIDTH     (MM_DATA_WIDTH),
  .PMCI_BASEADDR     (PMCI_BASEADDR),
  .VDM_OFFSET        (VDM_OFFSET),
  .MM_ADDR_WIDTH     (MM_ADDR_WIDTH), 
  .READ_ALLOWANCE    (READ_ALLOWANCE),
  .WRITE_ALLOWANCE   (WRITE_ALLOWANCE)
) mctp_rx_bridge (
   .clk           (clk),
   .rst_n         (rst_n),
   .i_vdm_req_st  (umsg_rx_if),
   .axi_m_if      (axi_m_pmci_vdm_if)
);

//---------------------------------
// MMIO request bridge
//---------------------------------
// Converts MWr/MRd TLP to AXI memory write/read request
mmio_req_bridge #(
   .MM_ADDR_WIDTH   (MM_ADDR_WIDTH),
   .MM_DATA_WIDTH   (MM_DATA_WIDTH),
   .READ_ALLOWANCE  (READ_ALLOWANCE),
   .WRITE_ALLOWANCE (WRITE_ALLOWANCE)

) mmio_req_bridge (
   .clk                  (clk),
   .rst_n                (rst_n),

   .i_mmio_req_st        (mmio_rx_if),

   .axi_m_if             (axi_m_if),
   .fake_rsp_csr_if      (fake_rsp_csr_if),

   .o_tlp_rd             (o_tlp_rd),
   .o_tlp_rd_tag         (o_tlp_rd_tag),
   .o_tlp_rd_length      (o_tlp_rd_length),
   .o_tlp_rd_req_id      (o_tlp_rd_req_id),
   .o_tlp_rd_lower_addr  (o_tlp_rd_lower_addr),
   .o_tlp_attr           (o_tlp_attr),
   .o_tlp_tc             (o_tlp_tc)
);

endmodule : st2mm_rx_bridge

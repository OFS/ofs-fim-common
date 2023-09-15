// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// This module places the MMIO requests from the master onto the AW, W, 
// and AR channels in the m_csr_if AXI-M interface which is connected to a
// slave CSR module. 
//
// It also connects the ready signals from AW, W, and AR channels to the respective
// o_*ready signals back to the master.
//
//-----------------------------------------------------------------------------

module axi_lite_if_conn #(
   parameter MM_ADDR_WIDTH = 19,
   parameter MM_DATA_WIDTH = 64
)(
   input  logic                           clk,
   input  logic                           rst_n,

   // Drivers
   input  logic                           i_awvalid,
   input  logic                           i_wvalid,
   input  logic                           i_arvalid,
   input  logic [MM_ADDR_WIDTH-1:0]       i_addr,
   input  logic                           i_length,   // 0:8B, 1:4B
   input  logic [MM_DATA_WIDTH-1:0]       i_wdata,

   // Sinks
   output logic                           o_awready,
   output logic                           o_wready,
   output logic                           o_arready,

   output logic                           o_bvalid,
   output logic                           o_bready,
   output logic                           o_rvalid,
   output logic                           o_rready,

   // Master CSR interface
   ofs_fim_axi_lite_if.req                m_csr_if
);

always_comb begin
   // Write address channel
   o_awready         = m_csr_if.awready;
   m_csr_if.awvalid  = i_awvalid;
   m_csr_if.awaddr   = i_addr;
   m_csr_if.awprot   = 3'b001;              // Priviledged, secure and data access

   // write data channel
   o_wready         = m_csr_if.wready;
   m_csr_if.wvalid  = i_wvalid;
   
   if (i_length) begin
      // 32-bit write
      m_csr_if.wdata = {2{i_wdata[31:0]}};
      m_csr_if.wstrb = i_addr[2] ? 8'hf0 : 8'h0f;      
   end else begin
      // 64-bit write
      m_csr_if.wdata = i_wdata;
      m_csr_if.wstrb = 8'hff;
   end

   // Read channel
   o_arready         = m_csr_if.arready;   
   m_csr_if.arvalid  = i_arvalid;
   m_csr_if.araddr   = i_addr;
   m_csr_if.arprot   = 3'b001;              // Priviledged, secure and data access

   // Write response channel
   o_bvalid = m_csr_if.bvalid;
   o_bready = m_csr_if.bready;

   // Read response channel
   o_rvalid = m_csr_if.rvalid;
   o_rready = m_csr_if.rready;
end

endmodule : axi_lite_if_conn


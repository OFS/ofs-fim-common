// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//   Functions:
//      1. Convert MMIO request TLPs to AXI-M read/write request
//      2. Convert AXI-M read responses into MMIO response TLPs
//
//-----------------------------------------------------------------------------

`include "vendor_defines.vh"
import pcie_ss_hdr_pkg::*;

module mmio_rsp_bridge #(
   parameter MM_DATA_WIDTH    = 64,
   parameter PF_NUM           = 0,
   parameter VF_NUM           = 0,
   parameter VF_ACTIVE        = 0,
   parameter READ_ALLOWANCE   = 1,
   parameter TAG_WIDTH        = 6
)(
   input  logic clk,
   input  logic rst_n,
   
   // PCIe Tx interface
   pcie_ss_axis_if.source o_tx_st,

   // MMIO request fields for CPL/CPLd
   input logic                                         i_tlp_rd,
   input logic [TAG_WIDTH-1:0]                         i_tlp_rd_tag,
   input logic [1:0]                                   i_tlp_rd_length,
   input logic [15:0]                                  i_tlp_rd_req_id,
   input logic [pcie_ss_hdr_pkg::LOWER_ADDR_WIDTH-1:0] i_tlp_rd_lower_addr,
   input logic [2:0]                                   i_tlp_attr,
   input logic [2:0]                                   i_tlp_tc,

   // CSR slave master interfaces
   ofs_fim_axi_lite_if.rsp axi_m_if
);

import pcie_ss_axis_pkg::*;
import st2mm_pkg::*;

localparam HDR_BYTE_CNT = (HDR_WIDTH/8);

// MMIO response 
typedef struct packed {
   logic [pcie_ss_hdr_pkg::PCIE_TAG_WIDTH-1:0] tid;
   logic [1:0]               rresp;
   logic [MM_DATA_WIDTH-1:0] rdata;
} t_rsp_fifo_data;
localparam RSP_FIFO_WIDTH = $bits(t_rsp_fifo_data);

//----------------------
// Register and wires
//----------------------
logic                                        load_rsp;
logic                                        send_packet;

pcie_ss_axis_pkg::t_axis_pcie                tx_q;
logic                                        tx_tready;

st2mm_pkg::t_cpl_hdr_info                    ctt_din;
st2mm_pkg::t_cpl_hdr_info                    ctt_dout;
logic [pcie_ss_hdr_pkg::PCIE_TAG_WIDTH-1:0]  ctt_raddr;
logic                                        ctt_we;
logic                                        ctt_re;
logic                                        ctt_dout_valid;

logic                                        rsp_fifo_rdvalid;
logic                                        rsp_fifo_wr;
logic                                        rsp_fifo_rd;
logic                                        rsp_fifo_full;
logic                                        rsp_fifo_empty;

t_rsp_fifo_data                              rsp_fifo_din;
t_rsp_fifo_data                              fifo_mmio_rsp;
t_rsp_fifo_data                              fifo_mmio_rsp_t1;

//`ifdef PU_MMIO
   pcie_ss_hdr_pkg::PCIe_PUCplHdr_t          cpl_hdr;
//`else
//   pcie_ss_hdr_pkg::PCIe_CplHdr_t            cpl_hdr;
//`endif

st2mm_pkg::t_axi_mmio_r      csr_rsp;
logic                        csr_rsp_ready;

//-----------------------------------------------------------------------------------------

assign load_rsp = (~tx_q.tvalid || tx_tready);

// Interface assignment
always_comb begin
   o_tx_st.tvalid       = tx_q.tvalid;
   o_tx_st.tdata        = tx_q.tdata;
   o_tx_st.tkeep        = tx_q.tkeep;
   o_tx_st.tuser_vendor = tx_q.tuser;
   o_tx_st.tlast        = tx_q.tlast;
   tx_tready            = o_tx_st.tready;
end

//-------------------------------------------------------------------------------------
// MMIO responses from CSR slaves
//-------------------------------------------------------------------------------------
//  The MMIO response FIFO in this module stores the reponses from CSR slaves
//
//  Since the FIFO can only accept 1 response at a time, 
//  the arbiter arbitrates the access to the FIFO for all the responses
//  from the CSR slaves
//
//-------------------------------------------------------------------------------------

// Assign MMIO responses from each CSR slave to a designated index in the csr_rsp array 
// Similarly, acknowledgement for each CSR slave is assigned to the same index in the csr_rsp_ready array

// FME CSR
always_comb begin
   csr_rsp.rvalid = axi_m_if.rvalid;
   csr_rsp.rid    = '0; // Set to 0 until TID is supported
   csr_rsp.rresp  = e_resp'(axi_m_if.rresp);
   csr_rsp.rdata  = axi_m_if.rdata;
   
   axi_m_if.rready = csr_rsp_ready;
   axi_m_if.bready = 1'b1;
end

assign csr_rsp_ready = ~rsp_fifo_full;

// Write MMIO response to the FIFO 
always @(posedge clk) begin
   rsp_fifo_wr  <= (~rsp_fifo_full && csr_rsp.rvalid);
   if (csr_rsp.rvalid) begin
      rsp_fifo_din.tid   = csr_rsp.rid;
      rsp_fifo_din.rresp = csr_rsp.rresp;
      rsp_fifo_din.rdata = csr_rsp.rdata;
   end
end

//-----------------------------
// FIFO to store MMIO responses
//-----------------------------
logic rsp_fifo_rdack;

localparam RSP_FIFO_DEPTH_LOG2 = (READ_ALLOWANCE<32) ? 5 : $clog2(READ_ALLOWANCE);
// Allow 4 pipelines
localparam RSP_FIFO_ALMFULL_TH = 2**RSP_FIFO_DEPTH_LOG2 - 5;

fim_rdack_scfifo #(
   .DATA_WIDTH            (RSP_FIFO_WIDTH),
   .DEPTH_LOG2            (RSP_FIFO_DEPTH_LOG2), // allow minimum 32 threads 
   .USE_EAB               ("ON"),
   .ALMOST_FULL_THRESHOLD (2**RSP_FIFO_DEPTH_LOG2 - 8)  
                                                       // 
) mmio_rsp_fifo (
   .clk     (clk),
   .sclr    (~rst_n),
   .wdata   (rsp_fifo_din),
   .wreq    (rsp_fifo_wr),
   .rdack   (rsp_fifo_rdack),
   .rdata   (fifo_mmio_rsp),
   .wfull   (),
   .wusedw  (),
   .rusedw  (),
   .almfull (rsp_fifo_full), 
   .rempty  (rsp_fifo_empty),
   .rvalid  (rsp_fifo_rdvalid)
);

assign rsp_fifo_rdack = ctt_re;

always_ff @(posedge clk) begin
   ctt_re <= 1'b0;

   if (~send_packet) begin
      ctt_re           <= rsp_fifo_rdvalid;
      fifo_mmio_rsp_t1  <= fifo_mmio_rsp;
   end

   if (~rst_n) begin
      ctt_re         <= 1'b0;
   end
end

//-------------------------------------------------------------------------------------
//
// mmio_rsp_tracker stores the information retrieved from MMIO request
// The information is used to construct CPL/CPLD TLP, e.g. requester ID, tag etc.
//
// USE_AXI_LITE_TID = 0
//       Only 1 read request is allowed at a time on the AXI4-lite fabric (APF/BPF)
//       In future, when AXI5-lite is supported, it needs to be updated to support 
//       multi-threading (i.e. multiple read in flight) by leveraging  
//       the TID field on AXI5-lite interface
//
//-------------------------------------------------------------------------------------
localparam USE_AXI_LITE_TID    = 0;
localparam CTT_FIFO_DEPTH_LOG2 = RSP_FIFO_DEPTH_LOG2;

// CTT FIFO requires +1 extra buffer to allow subsequent MRd request following a read response
localparam CTT_FIFO_ALMFULL_TH = RSP_FIFO_ALMFULL_TH + 1; 

always_comb begin
   ctt_we               = i_tlp_rd;
   ctt_din.tag          = i_tlp_rd_tag;
   ctt_din.lower_addr   = i_tlp_rd_lower_addr;
   ctt_din.requester_id = i_tlp_rd_req_id;
   ctt_din.length       = i_tlp_rd_length;
   ctt_din.attr         = i_tlp_attr;
   ctt_din.tc           = i_tlp_tc;
   ctt_raddr            = fifo_mmio_rsp_t1.tid; 
end

mmio_rsp_tag_tracker #(
   .USE_AXI_LITE_TID           (USE_AXI_LITE_TID),
   .CTT_FIFO_DEPTH_LOG2        (CTT_FIFO_DEPTH_LOG2),
   .CTT_FIFO_ALMFULL_THRESHOLD (CTT_FIFO_ALMFULL_TH)
) ctt_tag_tracker (
   .clk              (clk),
   .rst_n            (rst_n),
   
   .i_ctt_we         (ctt_we),
   .i_ctt_din        (ctt_din),

   .i_ctt_re         (ctt_re),
   .i_ctt_raddr      (ctt_raddr),
   .o_ctt_dout_valid (ctt_dout_valid),
   .o_ctt_dout       (ctt_dout)
);

//-------------------------------------------------------------------------------------
// Send MMIO CPL/CPLD response TLP 
//-------------------------------------------------------------------------------------
//
//  * Read MMIO response from MMIO response FIFO
//
//  * Retrieve the information of the original MMIO request
//    that is needed to fill in the CPL/CPLD header fields
//
//  * Convert the MMIO response into PCIe CPL/CPLD TLP and 
//    send the CPL/CPLD TLP upstream on AXI-S channel
//
//-------------------------------------------------------------------------------------

always_ff @(posedge clk) begin
   if (~send_packet && rsp_fifo_rdvalid) begin
      send_packet <= 1'b1;
   end else begin
      if (tx_q.tvalid && tx_tready) begin
         send_packet <= 1'b0;
      end
   end

   if (~rst_n) begin
      send_packet <= 1'b0;
   end
end

// Convert MMIO response retrieved from MMIO response FIFO
// into CPL/CPLD TLP header 
always_comb begin
   cpl_hdr = '0;
   
   cpl_hdr.pf_num    = PF_NUM[pcie_ss_hdr_pkg::PF_WIDTH-1:0];
   cpl_hdr.vf_num    = VF_NUM[pcie_ss_hdr_pkg::VF_WIDTH-1:0];
   cpl_hdr.vf_active = VF_ACTIVE;
   cpl_hdr.fmt_type  = DM_CPL; 
   {cpl_hdr.attr[8],cpl_hdr.attr[3:2]} = ctt_dout.attr;
   cpl_hdr.TC        = ctt_dout.tc;
   case (fifo_mmio_rsp_t1.rresp)
      st2mm_pkg::RESP_SLVERR,
      st2mm_pkg::RESP_DECERR : 
      begin
         cpl_hdr.cpl_status = 3'b001;
      end

      default : 
      begin
         cpl_hdr.cpl_status = 3'b000;
      end
   endcase

//`ifdef PU_MMIO
   cpl_hdr.req_id        = ctt_dout.requester_id; 
   
   cpl_hdr.comp_id[2:0]  = PF_NUM[0+:2];
   cpl_hdr.comp_id[3]    = VF_ACTIVE[0];
   cpl_hdr.comp_id[15:4] = VF_NUM[0+:10];

   cpl_hdr.tag_h         = ctt_dout.tag[9];
   cpl_hdr.tag_m         = ctt_dout.tag[8];
   cpl_hdr.tag_l         = ctt_dout.tag[7:0];

   cpl_hdr.low_addr      = ctt_dout.lower_addr[6:0];

   cpl_hdr.length        = {'0, ctt_dout.length}; // length in DW unit
   cpl_hdr.byte_count    = {ctt_dout.length, 2'h0};
//`else
//   cpl_hdr.tag           = ctt_dout.tag;
//   
//   cpl_hdr.low_addr_h    = ctt_dout.lower_addr[23:8];
//   cpl_hdr.low_addr_l    = ctt_dout.lower_addr[7:0];
//   
//   // Length in byte unit
//   cpl_hdr.length_h      = 2'h0;
//   cpl_hdr.length_m      = {'0, ctt_dout.length};
//   cpl_hdr.length_l      = 2'h0;
//`endif
end

// Send completion TLP upstream (Power user header format)
always_ff @(posedge clk) begin
   if (load_rsp) begin
      tx_q                                <= '0;
      tx_q.tvalid                         <= ctt_dout_valid;
      tx_q.tlast                          <= ctt_dout_valid;

      tx_q.tdata[HDR_WIDTH-1:0]           <= cpl_hdr;           
      tx_q.tdata[TDATA_WIDTH-1:HDR_WIDTH] <= ctt_dout.lower_addr[2] ? {'0, fifo_mmio_rsp_t1.rdata[63:32]} : fifo_mmio_rsp_t1.rdata;

      tx_q.tkeep                          <= {'0, {HDR_BYTE_CNT{1'b1}}}; // 32B header
      tx_q.tkeep[HDR_BYTE_CNT+:8]         <= ctt_dout.length[0] ? 8'h0F : 8'hFF;

//      `ifndef PU_MMIO
 //        tx_q.tuser[0]                    <= 1'b1; // Data Mover Header
//      `endif
   end

   if (~rst_n) begin
      tx_q.tvalid <= 1'b0;
   end
end

endmodule : mmio_rsp_bridge

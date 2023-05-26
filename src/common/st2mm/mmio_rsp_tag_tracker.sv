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
import st2mm_pkg::*;

module mmio_rsp_tag_tracker #(
   parameter USE_AXI_LITE_TID           = 0, // 0,1
   parameter CTT_FIFO_DEPTH_LOG2        = 5,
   parameter CTT_FIFO_ALMFULL_THRESHOLD = 1
)(
   input  logic clk,
   input  logic rst_n,
   
   input logic                          i_ctt_we,
   input st2mm_pkg::t_cpl_hdr_info      i_ctt_din,

   input logic                          i_ctt_re,
   input logic [pcie_ss_hdr_pkg::PCIE_TAG_WIDTH-1:0] i_ctt_raddr,
   output logic                         o_ctt_dout_valid,
   output st2mm_pkg::t_cpl_hdr_info     o_ctt_dout
);

st2mm_pkg::t_cpl_hdr_info ctt_din;
st2mm_pkg::t_cpl_hdr_info ctt_dout;
logic                     ctt_dout_valid;
logic                     ctt_we;
logic                     ctt_re;

//----------------------------------------------------------
// Assignments
//----------------------------------------------------------
assign ctt_we           = i_ctt_we;
assign ctt_re           = i_ctt_re;
assign ctt_din          = i_ctt_din;
assign o_ctt_dout       = ctt_dout;
assign o_ctt_dout_valid = ctt_dout_valid;

generate
   if (USE_AXI_LITE_TID) begin : ctt_ram
         localparam RAM_ADDR_WIDTH = pcie_ss_hdr_pkg::PCIE_TAG_WIDTH;
   
         logic [RAM_ADDR_WIDTH-1:0] ctt_waddr;
         logic [RAM_ADDR_WIDTH-1:0] ctt_raddr;

         assign ctt_waddr = i_ctt_din.tag;
         assign ctt_raddr = i_ctt_raddr; 

         // RAM to store the information retrieved from MRd request
         ram_1r1w #(
            .DEPTH          (pcie_ss_hdr_pkg::PCIE_TAG_WIDTH),
            .WIDTH          (st2mm_pkg::CPL_HDR_INFO_WIDTH), 
            .GRAM_MODE      (2'd1),
            .GRAM_STYLE     (`GRAM_AUTO),
            .INCLUDE_PARITY (0)
         ) csr_trk_tag (
            .clk   (clk),
            .din   (ctt_din),
            .waddr (ctt_waddr),
            .we    (ctt_we),
            .raddr (ctt_raddr),
            .re    (ctt_re),
            .dout  (ctt_dout),
            .perr  ()
         );

         always_ff @(posedge clk) begin
            if (~rst_n) begin
               ctt_dout_valid <= 1'b0;
            end else begin
               ctt_dout_valid <= ctt_re;
            end
         end
   end : ctt_ram
   else begin : ctt_fifo
         // FIFO to store the information retrieved from MRd request
         fim_scfifo #(
            .DATA_WIDTH            (st2mm_pkg::CPL_HDR_INFO_WIDTH),
            .DEPTH_LOG2            (CTT_FIFO_DEPTH_LOG2), 
            .USE_EAB               ("ON"),
            .ALMOST_FULL_THRESHOLD (CTT_FIFO_ALMFULL_THRESHOLD)
         ) csr_trk_tag (
            .clk     (clk),
            .sclr    (~rst_n),
            .w_data  (ctt_din),
            .w_req   (ctt_we),
            .r_req   (ctt_re),
            .r_data  (ctt_dout),
            .w_usedw (),
            .r_usedw (),
            .w_full  (),
            .w_ready (), 
            .r_empty (),
            .r_valid (ctt_dout_valid)
         );
   end : ctt_fifo
endgenerate

endmodule : mmio_rsp_tag_tracker


// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// ST2MM Packet Filter
//
//    * Filter for MMIO and UMSG packet
//
//-----------------------------------------------------------------------------

`timescale 1ps / 1ps


module st2mm_packet_filter #(
   parameter TDATA_WIDTH = 512,
   parameter TUSER_WIDTH = 10
)(
   input wire               clk,
   input wire               rst_n,

   pcie_ss_axis_if.sink     rx_st_if,

   pcie_ss_axis_if.source   mmio_st_if,
   pcie_ss_axis_if.source   umsg_st_if
);

import pcie_ss_axis_pkg::*;
import pcie_ss_hdr_pkg::*;

localparam NUM_IFS   = 3;
localparam SEL_WIDTH = $clog2(NUM_IFS);

ofs_axis_if #(
   .TDATA_WIDTH (TDATA_WIDTH),
   .TUSER_WIDTH (TUSER_WIDTH)
) dmx_in(), dmx_out[NUM_IFS-1:0] (); 


pcie_ss_hdr_pkg::PCIe_PUHdr_t          ss_pu_hdr;
pcie_ss_hdr_pkg::t_pu_tlp_req_hdr      hdr;
pcie_ss_hdr_pkg::t_pu_vdm_tlp_req_hdr  vdm_hdr;
pcie_ss_axis_pkg::t_axis_pcie          rx_st_q;
logic                                  rx_st_tready;
logic                                  mem_req;
logic                                  sop;
logic                                  vdm_req;
logic                                  vdm_req_latch;
logic                                  vdm_mctp_req;

//-------------------
// Decode header
//-------------------
assign ss_pu_hdr = rx_st_if.tdata[HDR_WIDTH-1:0];
assign hdr       = func_get_pu_tlp_hdr(ss_pu_hdr);
assign vdm_hdr   = func_get_pu_tlp_hdr(ss_pu_hdr);

//-------------------
// Pipeline
//-------------------

assign rx_st_if.tready = ~rx_st_q.tvalid | rx_st_tready;

always_ff @(posedge clk) begin
   if (rx_st_if.tready) begin
      rx_st_q.tvalid <= rx_st_if.tvalid;
      rx_st_q.tdata  <= rx_st_if.tdata;
      rx_st_q.tkeep  <= rx_st_if.tkeep;
      rx_st_q.tlast  <= rx_st_if.tlast;
      rx_st_q.tuser  <= rx_st_if.tuser_vendor;
      
      mem_req        <= pcie_ss_hdr_pkg::func_is_mem_req(ReqHdr_FmtType_e'(hdr.dw0.fmttype));
      //vdm_req        <= func_is_vdm_req(ReqHdr_FmtType_e'(hdr.dw0.fmttype)) && func_is_vdm_vendor_id(vdm_hdr.vendor_id) && func_is_msg_code(vdm_hdr.msg_code);
      vdm_req        <= func_is_vdm_req(ReqHdr_FmtType_e'(hdr.dw0.fmttype));
      vdm_mctp_req   <= func_is_vdm_req(ReqHdr_FmtType_e'(hdr.dw0.fmttype)) && func_is_vdm_vendor_id(vdm_hdr.vendor_id) && func_is_msg_code(vdm_hdr.msg_code);
      sop            <= rx_st_if.tlast;
   end
   if (rx_st_q.tvalid && vdm_mctp_req && ~rx_st_q.tlast ) begin
     vdm_req_latch <= 1'b1;
   end else if (rx_st_q.tvalid && sop) begin
     vdm_req_latch <= 1'b0;
   end
   if (~rst_n) begin
      rx_st_q.tvalid <= 1'b0;
      sop            <= 1'b1;
      vdm_req_latch  <= 1'b0;
	  vdm_req        <= 1'b0;
	  mem_req        <= 1'b0;
	  vdm_mctp_req   <= 1'b0;
   end
end

//-------------------
// Demux
//-------------------
logic [SEL_WIDTH-1:0] sel, sel_q;

always_ff @(posedge clk) begin
   sel_q <= sel;
end

//assign sel = sop ? mem_req : sel_q;
//assign sel = (sop & mem_req) ? 1'b1 : (sop & vdm_req) ? 1'b0 : sel_q;
assign sel = (sop & mem_req & (!vdm_mctp_req) & (!vdm_req) & (!vdm_req_latch)) ? 2'b01 : ((rx_st_q.tvalid & vdm_mctp_req) | vdm_req_latch) ? 2'b00 : (rx_st_q.tvalid & vdm_req & (!vdm_mctp_req) & (!vdm_req_latch)) ? 2'b10 : sel_q;

always_comb begin
   rx_st_tready   = dmx_in.tready;
   dmx_in.clk     = clk;
   dmx_in.rst_n   = rst_n;
   dmx_in.tvalid  = rx_st_q.tvalid;
   dmx_in.tlast   = rx_st_q.tlast;
   dmx_in.tdata   = rx_st_q.tdata;
   dmx_in.tkeep   = rx_st_q.tkeep;
   dmx_in.tuser   = rx_st_q.tuser;
end

axis_demux #(
   .NUM_CH      (NUM_IFS),
   .TDATA_WIDTH (TDATA_WIDTH),
   .TUSER_WIDTH (TUSER_WIDTH) 
) demux (
   .sel     (sel),
   .sink    (dmx_in),
   .source  (dmx_out)
);

//-------------------
// Output assignment 
//-------------------
// MMIO
assign dmx_out[2'b01].tready   = mmio_st_if.tready;
assign mmio_st_if.tvalid       = dmx_out[2'b01].tvalid;
assign mmio_st_if.tlast        = dmx_out[2'b01].tlast;
assign mmio_st_if.tdata        = dmx_out[2'b01].tdata;
assign mmio_st_if.tkeep        = dmx_out[2'b01].tkeep;
assign mmio_st_if.tuser_vendor = dmx_out[2'b01].tuser;

// UMSG - MCTP VDM message
assign dmx_out[2'b0].tready    = umsg_st_if.tready;
assign umsg_st_if.tvalid       = dmx_out[2'b0].tvalid;
assign umsg_st_if.tlast        = dmx_out[2'b0].tlast;
assign umsg_st_if.tdata        = dmx_out[2'b0].tdata;
assign umsg_st_if.tkeep        = dmx_out[2'b0].tkeep;
assign umsg_st_if.tuser_vendor = dmx_out[2'b0].tuser;

// UMSG - non MCTP type
assign dmx_out[2'b10].tready    = 1'b1;

endmodule : st2mm_packet_filter 


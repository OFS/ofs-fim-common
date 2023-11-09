// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//  Definition of AXI-4 Memory Mapped Interfaces used in CoreFIM
//  This interface is parameterized with FIM-specific bus widths.
//
//-----------------------------------------------------------------------------
interface ofs_axi_mm_if 
   import ofs_axi_mm_pkg::*;
#(
   parameter AWID_WIDTH   = ofs_axi_mm_pkg::AXI_ID_WIDTH,
   parameter AWADDR_WIDTH = ofs_axi_mm_pkg::AXI_ADDR_WIDTH,
   parameter AWUSER_WIDTH = ofs_axi_mm_pkg::AXI_USER_WIDTH,
   parameter AWLEN_WIDTH  = ofs_axi_mm_pkg::AXI_BURST_LEN_WIDTH,
   parameter WDATA_WIDTH  = ofs_axi_mm_pkg::AXI_DATA_WIDTH,
   parameter WUSER_WIDTH  = ofs_axi_mm_pkg::AXI_USER_WIDTH,
   parameter BUSER_WIDTH  = ofs_axi_mm_pkg::AXI_USER_WIDTH,
   parameter ARID_WIDTH   = ofs_axi_mm_pkg::AXI_ID_WIDTH,
   parameter ARADDR_WIDTH = ofs_axi_mm_pkg::AXI_ADDR_WIDTH,
   parameter ARUSER_WIDTH = ofs_axi_mm_pkg::AXI_USER_WIDTH,
   parameter ARLEN_WIDTH  = ofs_axi_mm_pkg::AXI_BURST_LEN_WIDTH,
   parameter RDATA_WIDTH  = ofs_axi_mm_pkg::AXI_DATA_WIDTH,
   parameter RUSER_WIDTH  = ofs_axi_mm_pkg::AXI_USER_WIDTH 
);
   
   logic                       clk;
   logic                       rst_n;

   // Write address channel
   logic                       awready;
   logic                       awvalid;
   logic [AWID_WIDTH-1:0]      awid;
   logic [AWADDR_WIDTH-1:0]    awaddr;
   logic [AWLEN_WIDTH-1:0]     awlen;
   logic [2:0]                 awsize;
   axi_burst_t                 awburst;
   logic                       awlock;
   logic [3:0]                 awcache;
   logic [2:0]                 awprot;
   logic [3:0]                 awqos;
   logic [AWUSER_WIDTH-1:0]    awuser;

   // Write data channel
   logic                       wready;
   logic                       wvalid;
   logic [WDATA_WIDTH-1:0]     wdata;
   logic [(WDATA_WIDTH/8-1):0] wstrb;
   logic                       wlast;
   logic [WUSER_WIDTH-1:0]     wuser;

   // Write response channel
   logic                       bready;
   logic                       bvalid;
   logic [AWID_WIDTH-1:0]      bid;
   axi_resp_t                  bresp;
   logic [BUSER_WIDTH-1:0]     buser;

   // Read address channel
   logic                       arready;
   logic                       arvalid;
   logic [ARID_WIDTH-1:0]      arid;
   logic [ARADDR_WIDTH-1:0]    araddr;
   logic [ARLEN_WIDTH-1:0]     arlen;
   logic [2:0]                 arsize;
   axi_burst_t                 arburst;
   logic                       arlock;
   logic [3:0]                 arcache;
   logic [2:0]                 arprot;
   logic [3:0]                 arqos;
   logic [ARUSER_WIDTH-1:0]    aruser;

   // Read response channel
   logic                       rready;
   logic                       rvalid;
   logic [ARID_WIDTH-1:0]      rid;
   logic [RDATA_WIDTH-1:0]     rdata;
   axi_resp_t                  rresp;
   logic                       rlast;
   logic [RUSER_WIDTH-1:0]     ruser;

   modport manager (
      output clk, rst_n,
      // Write address channel
      input  awready,
      output awvalid, awid, awaddr, awlen, awsize, awburst, awuser,

      // Write data channel
      input  wready,
      output wvalid, wdata, wstrb, wlast, wuser,

      // Read address channel
      input  arready,
      output arvalid, arid, araddr, arlen, arsize, arburst, aruser,

      // Write response channel
      output bready,
      input  bvalid, bid, bresp, buser,

      // Read response channel
      output rready,
      input  rvalid, rid, rdata, rresp, rlast, ruser
   );
   
   modport subordinate (
      input  clk, rst_n,
      // Write address channel
      output awready,
      input  awvalid, awid, awaddr, awlen, awsize, awburst, awuser,

      // Write data channel
      output wready,
      input  wvalid, wdata, wstrb, wlast, wuser,

      // Read address channel
      output arready,
      input  arvalid, arid, araddr, arlen, arsize, arburst, aruser,

      // Write response channel
      input  bready,
      output bvalid, bid, bresp, buser,

      // Read response channel
      input  rready,
      output rvalid, rid, rdata, rresp, rlast, ruser
   );

   // User managed if w/ EMIF native clock & reset
   modport user (
      input clk, rst_n,
      // Write address channel
      input  awready,
      output awvalid, awid, awaddr, awlen, awsize, awburst, awuser,

      // Write data channel
      input  wready,
      output wvalid, wdata, wstrb, wlast, wuser,

      // Read address channel
      input  arready,
      output arvalid, arid, araddr, arlen, arsize, arburst, aruser,

      // Write response channel
      output bready,
      input  bvalid, bid, bresp, buser,

      // Read response channel
      output rready,
      input  rvalid, rid, rdata, rresp, rlast, ruser
   );

   // EMIF subordinate if
   modport emif (
      output  clk, rst_n,
      // Write address channel
      output awready,
      input  awvalid, awid, awaddr, awlen, awsize, awburst, awuser,

      // Write data channel
      output wready,
      input  wvalid, wdata, wstrb, wlast, wuser,

      // Read address channel
      output arready,
      input  arvalid, arid, araddr, arlen, arsize, arburst, aruser,

      // Write response channel
      input  bready,
      output bvalid, bid, bresp, buser,

      // Read response channel
      input  rready,
      output rvalid, rid, rdata, rresp, rlast, ruser
   );
endinterface : ofs_axi_mm_if

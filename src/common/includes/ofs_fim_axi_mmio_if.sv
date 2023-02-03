// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//  Definition of AXI-4 Memory Mapped Interfaces used in CoreFIM
//
//-----------------------------------------------------------------------------

`ifndef __OFS_FIM_AXI_MMIO_IF_SV__
`define __OFS_FIM_AXI_MMIO_IF_SV__

interface ofs_fim_axi_mmio_if #(
   parameter AWID_WIDTH = 10,
   parameter AWADDR_WIDTH = 21,
   parameter AWUSER_WIDTH = 1,
   parameter WDATA_WIDTH = 64,
   parameter WUSER_WIDTH = 1,
   parameter BUSER_WIDTH = 1,
   parameter ARID_WIDTH = 10,
   parameter ARADDR_WIDTH = 21,
   parameter ARUSER_WIDTH = 1,
   parameter RDATA_WIDTH = 64,
   parameter RUSER_WIDTH = 1
);
   logic                       clk;
   logic                       rst_n;

   // Write address channel
   logic                       awready;
   logic                       awvalid;
   logic [AWID_WIDTH-1:0]      awid;
   logic [AWADDR_WIDTH-1:0]    awaddr;
   logic [7:0]                 awlen;
   logic [2:0]                 awsize;
   logic [1:0]                 awburst;
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
   logic [1:0]                 bresp;
   logic [BUSER_WIDTH-1:0]     buser;

   // Read address channel
   logic                       arready;
   logic                       arvalid;
   logic [ARID_WIDTH-1:0]      arid;
   logic [ARADDR_WIDTH-1:0]    araddr;
   logic [7:0]                 arlen;
   logic [2:0]                 arsize;
   logic [1:0]                 arburst;
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
   logic [1:0]                 rresp;
   logic                       rlast;
   logic [RUSER_WIDTH-1:0]     ruser;
	
   modport master (
        input  awready, wready, 
               bvalid, bid, bresp, 
               arready, 
               rvalid, rid, rdata, rresp, rlast,
        output clk, rst_n, 
               awvalid, awid, awaddr, awlen, awsize, awburst, 
               awcache, awprot, awqos,
               wvalid, wdata, wstrb, wlast,
               bready, 
               arvalid, arid, araddr, arlen, arsize, arburst, 
               arcache, arprot, arqos,
               rready
   );
   
   modport req (
        input  awready, wready, 
               arready, 
        output clk, rst_n, 
               awvalid, awid, awaddr, awlen, awsize, awburst, 
               awcache, awprot, awqos,
               wvalid, wdata, wstrb, wlast,
               arvalid, arid, araddr, arlen, arsize, arburst,
               arcache, arprot, arqos
   );
  
   modport rsp (
        input  bvalid, bid, bresp, 
               rvalid, rid, rdata, rresp, rlast,
        output bready, 
               rready
   );

   modport slave (
        output awready, wready, 
               bvalid, bid, bresp, 
               arready, 
               rvalid, rid, rdata, rresp, rlast,
        input  clk, rst_n, 
               awvalid, awid, awaddr, awlen, awsize, awburst,awlock,
               awcache, awprot, awqos,
               wvalid, wdata, wstrb, wlast,
               bready, 
               arvalid, arid, araddr, arlen, arsize, arburst,arlock,
               arcache, arprot, arqos,
               rready
   );
  
   modport user (
        input  awready, wready, 
               bvalid, bid, bresp, buser,
               arready,
               rvalid, rid, rdata, rresp, rlast, ruser,
        output clk, rst_n, 
               awvalid, awid, awaddr, awlen, awsize, awburst, awlock,
               awcache, awprot, awuser,
               wvalid, wdata, wstrb, wlast,
               bready, 
               arvalid, arid, araddr, arlen, arsize, arburst, 
               arcache, arprot, aruser, arlock,
               rready
   );

   modport emif (
        output awready, wready, 
               bvalid, bid, bresp, buser,
               arready, 
               rvalid, rid, rdata, rresp, rlast, ruser,
        input  clk, rst_n, 
               awvalid, awid, awaddr, awlen, awsize, awburst, awlock,
               awcache, awprot, awuser,
               wvalid, wdata, wstrb, wlast,
               bready, 
               arvalid, arid, araddr, arlen, arsize, arburst,
               arcache, arprot, aruser, arlock,
               rready
   );

   modport user_n (
        input  clk, rst_n, 
               awready, wready, 
               bvalid, bid, bresp, buser,
               arready,
               rvalid, rid, rdata, rresp, rlast, ruser,
        output awvalid, awid, awaddr, awlen, awsize, awburst, awlock,
               awcache, awprot, awuser,
               wvalid, wdata, wstrb, wlast,
               bready, 
               arvalid, arid, araddr, arlen, arsize, arburst, 
               arcache, arprot, aruser, arlock,
               rready
   );

   modport emif_n (
        output clk, rst_n, 
               awready, wready, 
               bvalid, bid, bresp, buser,
               arready, 
               rvalid, rid, rdata, rresp, rlast, ruser,
        input  awvalid, awid, awaddr, awlen, awsize, awburst, awlock,
               awcache, awprot, awuser,
               wvalid, wdata, wstrb, wlast,
               bready, 
               arvalid, arid, araddr, arlen, arsize, arburst,
               arcache, arprot, aruser, arlock,
               rready
   );

endinterface : ofs_fim_axi_mmio_if 
`endif // __OFS_FIM_AXI_MMIO_IF_SV__

// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//  Definition of AXI-4 lite interface
//
//-----------------------------------------------------------------------------

`ifndef __OFS_FIM_AXI_LITE_IF_SV__
`define __OFS_FIM_AXI_LITE_IF_SV__

interface ofs_fim_axi_lite_if #(
   parameter AWADDR_WIDTH = 21,
   parameter WDATA_WIDTH = 64,
   parameter ARADDR_WIDTH = 21,
   parameter RDATA_WIDTH = 64
)(
   input wire clk,
   input wire rst_n
);
   // Write address channel
   logic                       awready;
   logic                       awvalid;
   logic [AWADDR_WIDTH-1:0]    awaddr;
   logic [2:0]                 awprot;

   // Write data channel
   logic                       wready;
   logic                       wvalid;
   logic [WDATA_WIDTH-1:0]     wdata;
   logic [(WDATA_WIDTH/8-1):0] wstrb;

   // Write response channel
   logic                       bready;
   logic                       bvalid;
   logic [1:0]                 bresp;

   // Read address channel
   logic                       arready;
   logic                       arvalid;
   logic [ARADDR_WIDTH-1:0]    araddr;
   logic [2:0]                 arprot;

   // Read response channel
   logic                       rready;
   logic                       rvalid;
   logic [RDATA_WIDTH-1:0]     rdata;
   logic [1:0]                 rresp;
	
   modport master (
        input  awready,
               wready, 
               bvalid, bresp, 
               arready, 
               rvalid, rdata, rresp,
        output awvalid, awaddr, awprot,
               wvalid, wdata, wstrb,
               bready, 
               arvalid, araddr, arprot,
               rready
   );
   
   modport req (
        input  awready, 
               wready, 
               arready, 
               bvalid, bready,
               rvalid, rready,
        output awvalid, awaddr, awprot,
               wvalid, wdata, wstrb,
               arvalid, araddr, arprot
   );
  
   modport rsp (
        input  bvalid, bresp, 
               rvalid, rdata, rresp,
        output bready, 
               rready
   );

   modport slave (
        output awready, 
               wready, 
               bvalid, bresp, 
               arready, 
               rvalid, rdata, rresp,
        input  awvalid, awaddr, awprot,
               wvalid, wdata, wstrb,
               bready, 
               arvalid, araddr, arprot,
               rready
   );

   modport source (
        input  clk, rst_n,
               awready,
               wready, 
               bvalid, bresp, 
               arready, 
               rvalid, rdata, rresp,
        output awvalid, awaddr, awprot,
               wvalid, wdata, wstrb,
               bready, 
               arvalid, araddr, arprot,
               rready
   );
   
   modport sink (
        output awready, 
               wready, 
               bvalid, bresp, 
               arready, 
               rvalid, rdata, rresp,
        input  clk, rst_n,
               awvalid, awaddr, awprot,
               wvalid, wdata, wstrb,
               bready, 
               arvalid, araddr, arprot,
               rready
  );

endinterface : ofs_fim_axi_lite_if 
`endif // __OFS_FIM_AXI_LITE_IF_SV__

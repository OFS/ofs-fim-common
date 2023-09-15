// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// This module converts AXI4-lite requests targeting a CSR, to AXI4 protocol.
// For the mapping to AXI4 signals, it considers the AXI4-lite requirements:
// - all transactions are of burst length 1
// - all data accesses use the full width of the data bus
// - data bus width of 64-bit
// - all accesses are Non-modifiable, Non-bufferable
// - exclusive accesses are not supported
//-----------------------------------------------------------------------------

module axi_lite2mmio
(
    input clk,
    input rst_n,
    ofs_fim_axi_lite_if.slave    lite_if,
    ofs_fim_axi_mmio_if.master   mmio_if
);

//-------------------------------------
// Signals mapping
//-------------------------------------

// Global signals
assign mmio_if.clk      = clk;
assign mmio_if.rst_n    = rst_n;

// Write address channel
assign lite_if.awready  = mmio_if.awready;

assign mmio_if.awvalid  = lite_if.awvalid;
assign mmio_if.awid     = 'b0; 
assign mmio_if.awaddr   = lite_if.awaddr;
assign mmio_if.awlen    = 8'b0; 
assign mmio_if.awsize   = ( &lite_if.wstrb )        ?   3'b011 :    // 8-byte
                                                        3'b010;     // 4-byte
assign mmio_if.awburst  = 2'b00;
//assign mmio_if.awlock   = 1'b0;
assign mmio_if.awcache  = 4'b0000;
assign mmio_if.awprot   = lite_if.awprot;
assign mmio_if.awqos    = 4'b0000;
//assign mmio_if.awuser   = 'b0; 

// Write data channel
assign lite_if.wready   = mmio_if.wready;

assign mmio_if.wvalid   = lite_if.wvalid;
assign mmio_if.wdata    = lite_if.wdata;
assign mmio_if.wstrb    = lite_if.wstrb;
assign mmio_if.wlast    = 1'b1; 
//assign mmio_if.wuser    = 'b0;

// Write response channel
assign lite_if.bvalid   = mmio_if.bvalid;
assign lite_if.bresp    = mmio_if.bresp;

assign mmio_if.bready   = lite_if.bready;

// Read address channel
assign lite_if.arready  = mmio_if.arready;

assign mmio_if.arvalid  = lite_if.arvalid;
assign mmio_if.arid     = 'b0; 
assign mmio_if.araddr   = lite_if.araddr;
assign mmio_if.arlen    = 8'b0;
assign mmio_if.arsize   = ( lite_if.araddr[2] )     ?   3'b010 :    // 4-byte
                                                        3'b011;     // 8-byte
assign mmio_if.arburst  = 2'b00;
//assign mmio_if.arlock   = 1'b0;
assign mmio_if.arcache  = 4'b0000;
assign mmio_if.arprot   = lite_if.arprot;
assign mmio_if.arqos    = 4'b0000;
//assign mmio_if.aruser   = 'b0;

// Read response channel
assign lite_if.rvalid   = mmio_if.rvalid;
assign lite_if.rdata    = mmio_if.rdata;
assign lite_if.rresp    = mmio_if.rresp;

assign mmio_if.rready   = lite_if.rready;

endmodule

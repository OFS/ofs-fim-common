// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// This is a pass-thru module to enable exporting the AXI4-lite interface
//-----------------------------------------------------------------------------

module axi4lite_shim
#(
parameter AW =18,
parameter DW =64,

// Derived parameter
parameter WSTRB_W = (DW/8)
) 
(
// Global signals
input           clk,   
input           rst_n,

// Slave WR ADDR Channel
input [AW-1:0]  s_awaddr,
input [2:0]     s_awprot,
input           s_awvalid,
output          s_awready,
// Slave WR DATA Channel
input [DW-1:0]  s_wdata, 
input [WSTRB_W-1:0] s_wstrb, 
input           s_wvalid,
output          s_wready,
// Slave WR RESP Channel
output  [1:0]   s_bresp, 
output          s_bvalid,
input           s_bready,
// Slave RD ADDR Channel
input [AW-1:0]  s_araddr,
input [2:0]     s_arprot,
input           s_arvalid,
output          s_arready,
// Slave RD DATA Channel
output [DW-1:0] s_rdata, 
output [1:0]    s_rresp, 
output          s_rvalid,
input           s_rready,

// Master WR ADDR Channel
output [AW-1:0] m_awaddr,
output [2:0]    m_awprot,
output          m_awvalid,
input           m_awready,
// Master WR DATA Channel
output [DW-1:0] m_wdata, 
output [WSTRB_W-1:0]    m_wstrb, 
output          m_wvalid,
input           m_wready,
// Master WR RESP Channel
input  [1:0]    m_bresp, 
input           m_bvalid,
output          m_bready,
// Master RD ADDR Channel
output [AW-1:0] m_araddr,
output [2:0]    m_arprot,
output          m_arvalid,
input           m_arready,
// Master RD DATA Channel
input  [DW-1:0] m_rdata, 
input  [1:0]    m_rresp, 
input           m_rvalid,
output          m_rready
);

//-------------------------------------
// Signals mapping
//-------------------------------------

// Write address channel
assign s_awready= m_awready ;
assign m_awvalid= s_awvalid ;
assign m_awaddr = s_awaddr  ;
assign m_awprot = s_awprot  ;

// Write data channel
assign s_wready = m_wready  ;
assign m_wvalid = s_wvalid  ;
assign m_wdata  = s_wdata   ;
assign m_wstrb  = s_wstrb   ;

// Write response channel
assign m_bready = s_bready  ;
assign s_bvalid = m_bvalid  ;
assign s_bresp  = m_bresp   ;

// Read address channel
assign s_arready= m_arready ;
assign m_arvalid= s_arvalid ;
assign m_araddr = s_araddr  ;
assign m_arprot = s_arprot  ;

// Read response channel
assign m_rready = s_rready  ;
assign s_rvalid = m_rvalid  ;
assign s_rdata  = m_rdata   ;
assign s_rresp  = m_rresp   ;

endmodule

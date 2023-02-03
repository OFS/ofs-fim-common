// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// AXI pipeline register
// 
//-----------------------------------------------------------------------------

`timescale 1 ps / 1 ps
module axi_register 
#( 
    // Register mode for write address channel
    parameter AW_REG_MODE          = 0, // 0: skid buffer 1: simple buffer 2: bypass
    // Register mode for write data channel
    parameter W_REG_MODE           = 0, // 0: skid buffer 1: simple buffer 2: bypass
    // Regiter mode for write response channel
    parameter B_REG_MODE           = 0, // 0: skid buffer 1: simple buffer 2: bypass
    // Register mode for read address channel
    parameter AR_REG_MODE          = 0, // 0: skid buffer 1: simple buffer 2: bypass
    // Register mode for read data channel
    parameter R_REG_MODE           = 0, // 0: skid buffer 1: simple buffer 2: bypass
    
    // Enable awuser signal on register output
    parameter ENABLE_AWUSER        = 0,
    // Enable wuser signal on register output
    parameter ENABLE_WUSER         = 0,
    // Enable buser signal on register output
    parameter ENABLE_BUSER         = 0,
    // Enable aruser signal on register output
    parameter ENABLE_ARUSER        = 0,
    // Enable ruser signal on register output
    parameter ENABLE_RUSER         = 0,
  
    // Width of ID signal on write address channel
    parameter AWID_WIDTH = 10,
    // Width of address signal on write address channel
    parameter AWADDR_WIDTH = 20,
    // Width of awuser signal on write address channel
    parameter AWUSER_WIDTH = 1,
    
    // Width of data signal on write data channel
    parameter WDATA_WIDTH = 256,
    // Width of wuser signal on write data channel
    parameter WUSER_WIDTH = 1,
    
    // Width of buser signal on write response channel
    parameter BUSER_WIDTH = 1,
    
    // Width of ID signal on read address channel
    parameter ARID_WIDTH = 10,
    // Width of address signal on read address channel
    parameter ARADDR_WIDTH = 20,
    // Width of aruser signal on read address channel
    parameter ARUSER_WIDTH = 1,
    
    // Width of data signal on read data channel
    parameter RDATA_WIDTH = 256,
    // Width of ruser signal on read data channel
    parameter RUSER_WIDTH = 1,

    // --------------------------------------
    // Derived parameters
    // --------------------------------------
    // Width of wstrb signal on write data channel
    parameter WSTRB_WIDTH = (WDATA_WIDTH/8-1)
)(
    input                         clk,
    input                         rst_n,

    // Slave interface
       /*Write address channel*/
    output logic                       s_awready,
    input  logic                       s_awvalid,
    input  logic [AWID_WIDTH-1:0]      s_awid,
    input  logic [AWADDR_WIDTH-1:0]    s_awaddr,
    input  logic [7:0]                 s_awlen,
    input  logic [2:0]                 s_awsize,
    input  logic [1:0]                 s_awburst,
    input  logic                       s_awlock,
    input  logic [3:0]                 s_awcache,
    input  logic [2:0]                 s_awprot,
    input  logic [3:0]                 s_awqos,
    input  logic [3:0]                 s_awregion,
    input  logic [AWUSER_WIDTH-1:0]    s_awuser,

       /*Write data channel*/
    output logic                       s_wready,
    input  logic                       s_wvalid,
    input  logic [WDATA_WIDTH-1:0]     s_wdata,
    input  logic [(WDATA_WIDTH/8-1):0] s_wstrb,
    input  logic [2:0]                 s_wlast,
    input  logic [WUSER_WIDTH-1:0]     s_wuser,

       /*Write response channel*/
    input  logic                       s_bready,
    output logic                       s_bvalid,
    output logic [AWID_WIDTH-1:0]      s_bid,
    output logic [1:0]                 s_bresp,
    output logic [BUSER_WIDTH-1:0]     s_buser,

       /*Read address channel*/
    output logic                       s_arready,
    input  logic                       s_arvalid,
    input  logic [ARID_WIDTH-1:0]      s_arid,
    input  logic [ARADDR_WIDTH-1:0]    s_araddr,
    input  logic [7:0]                 s_arlen,
    input  logic [2:0]                 s_arsize,
    input  logic [1:0]                 s_arburst,
    input  logic                       s_arlock,
    input  logic [3:0]                 s_arcache,
    input  logic [2:0]                 s_arprot,
    input  logic [3:0]                 s_arqos,
    input  logic [3:0]                 s_arregion,
    input  logic [ARUSER_WIDTH-1:0]    s_aruser,

       /*Read response channel*/
    input  logic                       s_rready,
    output logic                       s_rvalid,
    output logic [ARID_WIDTH-1:0]      s_rid,
    output logic [RDATA_WIDTH-1:0]     s_rdata,
    output logic [1:0]                 s_rresp,
    output logic                       s_rlast,
    output logic [RUSER_WIDTH-1:0]     s_ruser,

    // Master interface
       /*Write address channel*/
    input  logic                       m_awready,
    output logic                       m_awvalid,
    output logic [AWID_WIDTH-1:0]      m_awid,
    output logic [AWADDR_WIDTH-1:0]    m_awaddr,
    output logic [7:0]                 m_awlen,
    output logic [2:0]                 m_awsize,
    output logic [1:0]                 m_awburst,
    output logic                       m_awlock,
    output logic [3:0]                 m_awcache,
    output logic [2:0]                 m_awprot,
    output logic [3:0]                 m_awqos,
    output logic [3:0]                 m_awregion,
    output logic [AWUSER_WIDTH-1:0]    m_awuser,

       /*Write data channel*/
    input  logic                       m_wready,
    output logic                       m_wvalid,
    output logic [WDATA_WIDTH-1:0]     m_wdata,
    output logic [(WDATA_WIDTH/8-1):0] m_wstrb,
    output logic [2:0]                 m_wlast,
    output logic [WUSER_WIDTH-1:0]     m_wuser,

       /*Write response channel*/
    output logic                       m_bready,
    input  logic                       m_bvalid,
    input  logic [AWID_WIDTH-1:0]      m_bid,
    input  logic [1:0]                 m_bresp,
    input  logic [BUSER_WIDTH-1:0]     m_buser,

       /*Read address channel*/
    input  logic                       m_arready,
    output logic                       m_arvalid,
    output logic [ARID_WIDTH-1:0]      m_arid,
    output logic [ARADDR_WIDTH-1:0]    m_araddr,
    output logic [7:0]                 m_arlen,
    output logic [2:0]                 m_arsize,
    output logic [1:0]                 m_arburst,
    output logic                       m_arlock,
    output logic [3:0]                 m_arcache,
    output logic [2:0]                 m_arprot,
    output logic [3:0]                 m_arqos,
    output logic [3:0]                 m_arregion,
    output logic [ARUSER_WIDTH-1:0]    m_aruser,

       /*Read response channel*/
    output logic                       m_rready,
    input  logic                       m_rvalid,
    input  logic [ARID_WIDTH-1:0]      m_rid,
    input  logic [RDATA_WIDTH-1:0]     m_rdata,
    input  logic [1:0]                 m_rresp,
    input  logic                       m_rlast,
    input  logic [RUSER_WIDTH-1:0]     m_ruser
);

axi_write_register #(
   .AW_REG_MODE    (AW_REG_MODE),
   .W_REG_MODE     (W_REG_MODE),
   .B_REG_MODE     (B_REG_MODE),
   .ENABLE_AWUSER  (ENABLE_AWUSER),
   .ENABLE_WUSER   (ENABLE_WUSER),
   .ENABLE_BUSER   (ENABLE_BUSER),
   .AWID_WIDTH     (AWID_WIDTH),
   .AWADDR_WIDTH   (AWADDR_WIDTH),
   .AWUSER_WIDTH   (AWUSER_WIDTH),
   .WDATA_WIDTH    (WDATA_WIDTH),
   .WSTRB_WIDTH    (WSTRB_WIDTH),  
   .WUSER_WIDTH    (WUSER_WIDTH),
   .BUSER_WIDTH    (BUSER_WIDTH)
) axi_write_reg (
   .*
);

axi_read_register #(
   .AR_REG_MODE    (AR_REG_MODE),
   .R_REG_MODE     (R_REG_MODE),
   .ENABLE_ARUSER  (ENABLE_ARUSER),
   .ENABLE_RUSER   (ENABLE_RUSER),
   .ARID_WIDTH     (ARID_WIDTH),
   .ARADDR_WIDTH   (ARADDR_WIDTH),
   .ARUSER_WIDTH   (ARUSER_WIDTH),
   .RDATA_WIDTH    (RDATA_WIDTH),
   .RUSER_WIDTH    (RUSER_WIDTH)
) axi_read_reg (
   .*
);

endmodule

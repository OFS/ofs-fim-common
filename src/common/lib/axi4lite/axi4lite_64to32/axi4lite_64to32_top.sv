// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Author: Ranajoy Nandi (ranajoy.s.nandi@intel.com)
// Date: WW20, 2022
// Project: Originally designed for OSC. 
// Description: Bridge for converting between 64-bit data domain (master) and 
//              32-bit data domain (slave). All write and read requests
//              are initiated by master and responded to by slave.
//              This bridge does not support requests initiated by slave.
// Application Example: In OSC shell this bridge is used to convert between
// 64-bit domain of SoC BPF (master) and 32-bit CSR domain of BNIC IP (slave).
//-----------------------------------------------------------------------------

module axi4lite_64to32_top 
#( 
   parameter M_AWADDR_WIDTH = 32,
   parameter M_ARADDR_WIDTH = 32,
   parameter S_AWADDR_WIDTH = 32,
   parameter S_ARADDR_WIDTH = 32
)
(
   input logic rst_n,
   input logic clk,
   //Master Interface
   input  logic [M_AWADDR_WIDTH-1:0] m_awaddr,
   input  logic                      m_awvalid,
   output logic                      m_awready,
   input  logic [63:0]               m_wdata,
   input  logic [7:0]                m_wstrb,
   input  logic                      m_wvalid,
   output logic                      m_wready,
   output logic [1:0]                m_bresp,
   output logic                      m_bvalid,
   input  logic                      m_bready,
   input  logic [M_ARADDR_WIDTH-1:0] m_araddr,
   input  logic                      m_arvalid,
   output logic                      m_arready,
   output logic [1:0]                m_rresp,
   output logic [63:0]               m_rdata,
   output logic                      m_rvalid,
   input  logic                      m_rready,
   //Slave Interface
   output logic [S_AWADDR_WIDTH-1:0] s_awaddr,
   output logic                      s_awvalid,
   input  logic                      s_awready,
   output logic [31:0]               s_wdata,
   output logic [3:0]                s_wstrb,
   output logic                      s_wvalid,
   input  logic                      s_wready,
   input  logic [1:0]                s_bresp,
   input  logic                      s_bvalid,
   output logic                      s_bready,
   output logic [S_ARADDR_WIDTH-1:0] s_araddr,
   output logic                      s_arvalid,
   input  logic                      s_arready,
   input  logic [1:0]                s_rresp,
   input  logic [31:0]               s_rdata,
   input  logic                      s_rvalid,
   output logic                      s_rready
);

//-------------------------------------------------------
//Internal Signals
//-------------------------------------------------------

//-------------------------------------------------------

//-------------------------------------------------------
//Write Handler
//-------------------------------------------------------
whandler #(
           .M_AWADDR_WIDTH (M_AWADDR_WIDTH),
           .S_AWADDR_WIDTH (S_AWADDR_WIDTH)
          ) u0_whandler (
                          .clk,
                          .rst_n,
                          .m_awaddr,
                          .m_awvalid,
                          .m_awready,
                          .m_wdata,
                          .m_wstrb,
                          .m_wvalid,
                          .m_wready,
                          .m_bresp,
                          .m_bvalid,
                          .m_bready,
                          .s_awaddr,
                          .s_awvalid,
                          .s_awready,
                          .s_wdata,
                          .s_wstrb,
                          .s_wvalid,
                          .s_wready,
                          .s_bresp,
                          .s_bvalid,
                          .s_bready
                         );


//-----------------------------------------------------------
//Read Handler
//-----------------------------------------------------------
rhandler #(
               .M_ARADDR_WIDTH (M_ARADDR_WIDTH),
               .S_ARADDR_WIDTH (S_ARADDR_WIDTH)
              ) u0_rhandler (
                             .clk,
                             .rst_n,
                             .m_araddr,
                             .m_arvalid,
                             .m_arready,
                             .m_rresp,
                             .m_rdata,
                             .m_rvalid,
                             .m_rready,
                             .s_araddr,
                             .s_arvalid,
                             .s_arready,
                             .s_rresp,
                             .s_rdata,
                             .s_rvalid,
                             .s_rready
                            );
                            
endmodule


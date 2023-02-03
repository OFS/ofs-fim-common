// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Author: Ranajoy Nandi (ranajoy.s.nandi@intel.com)
// Date: WW20, 2022
// Project: Originally designed for OSC. 
// Description: Read Handler
//-----------------------------------------------------------------------------
module rhandler
#(
  parameter M_ARADDR_WIDTH = 32,
  parameter S_ARADDR_WIDTH = 32
)
(
  input  logic                      clk,
  input  logic                      rst_n,
  input  logic [M_ARADDR_WIDTH-1:0] m_araddr,
  input  logic                      m_arvalid,
  output logic                      m_arready,
  output logic [1:0]                m_rresp,
  output logic [63:0]               m_rdata,
  output logic                      m_rvalid,
  input  logic                      m_rready,
  output logic [S_ARADDR_WIDTH-1:0] s_araddr,
  output logic                      s_arvalid,
  input  logic                      s_arready,
  input  logic [1:0]                s_rresp,
  input  logic [31:0]               s_rdata,
  input  logic                      s_rvalid,
  output logic                      s_rready

);

//---------------------------------------------------------------
//Internal Wires
//---------------------------------------------------------------
logic i_select_upper;
logic i_start;
logic i_done;
logic i_latch_addr;
logic i_latch_lower_rdata;
logic i_latch_upper_rdata;
logic [M_ARADDR_WIDTH-1:0] i_m_araddr;
//---------------------------------------------------------------

//---------------------------------------------------------------
//Register for capturing m_araddr
//---------------------------------------------------------------
always_ff @(posedge clk or negedge rst_n) begin
  if (~rst_n)
    i_m_araddr <= 0;
  else if (i_latch_addr)
    i_m_araddr <= m_araddr;
  else
    i_m_araddr <= i_m_araddr;
end

//---------------------------------------------------------------
//Mux for selecting address to drive to the slave side
//---------------------------------------------------------------
always_comb begin
  if (i_select_upper && (!i_m_araddr[2])) 
      s_araddr = i_m_araddr + 4; //When reading from upper dword address, add 4 to outgoing 32-bit aligned s_araddr
                                 //only if the incoming m_araddr was 64-bit aligned.
  else
      s_araddr = i_m_araddr;
end

//---------------------------------------------------------------
//Master Controller FSM
//---------------------------------------------------------------
rhandler_ctrl u0_rhandler_ctrl (
                                .clk,
                                .rst_n,
                                .m_arvalid,
                                .m_arready,
                                .m_rvalid,
                                .m_rready,
                                .select_upper      (i_select_upper),
                                .start             (i_start),
                                .done              (i_done),
                                .addrbit2          (i_m_araddr[2]),
                                .latch_addr        (i_latch_addr),
                                .latch_lower_rdata (i_latch_lower_rdata),
                                .latch_upper_rdata (i_latch_upper_rdata)
                               );

//------------------------------------------------------------------
//Slave Driver FSM
//------------------------------------------------------------------
rhandler_slave_driver u0_rhandler_slave_driver (
                                                 .clk,
                                                 .rst_n,
                                                 .start (i_start),
                                                 .done (i_done),
                                                 .s_arvalid,
                                                 .s_arready,
                                                 .s_rvalid,
                                                 .s_rready
                                               );

//------------------------------------------------------------------
//Master Response and Rdata generator data path
//------------------------------------------------------------------
rhandler_rresp_gen u0_rhandler_rresp_gen (
                                           .clk,
                                           .rst_n,
                                           .addrbit2          (i_m_araddr[2]),
                                           .s_rresp,
                                           .s_rdata,
                                           .latch_upper_rdata (i_latch_upper_rdata),
                                           .latch_lower_rdata (i_latch_lower_rdata),
                                           .m_rresp,
                                           .m_rdata
                                         );

endmodule

// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Author: Ranajoy Nandi (ranajoy.s.nandi@intel.com)
// Date: WW20, 2022
// Project: Originally designed for OSC. 
// Description: Master FSM controller for Read Handler
//-----------------------------------------------------------------------------

module rhandler_rresp_gen (
  input  logic clk,
  input  logic rst_n,
  input  logic addrbit2,
  input  logic [1:0] s_rresp,
  input  logic [31:0] s_rdata,
  input  logic latch_upper_rdata,
  input  logic latch_lower_rdata,
  output logic [1:0] m_rresp,
  output logic [63:0] m_rdata
);

//----------------------------------------------------
//Internal Signals
//----------------------------------------------------
logic [1:0] i_rresp_lower;
logic [31:0] i_rdata_lower;
logic [1:0] i_rresp_upper;
logic [31:0] i_rdata_upper;
//----------------------------------------------------
//Registers for capturing rresp and rdata from slave
//----------------------------------------------------
//Lower Data
always_ff @(posedge clk or negedge rst_n) begin
  if (~rst_n) begin
    i_rresp_lower <= 2'h0;
    i_rdata_lower <= 32'h0;
  end
  else if (latch_lower_rdata) begin
    i_rresp_lower <= s_rresp;
    i_rdata_lower <= s_rdata;
  end  
end

//Upper Data
always_ff @(posedge clk or negedge rst_n) begin
  if (~rst_n) begin
    i_rresp_upper <= 2'h0;
    i_rdata_upper <= 32'h0;
  end
  else if (latch_upper_rdata) begin
    i_rresp_upper <= s_rresp;
    i_rdata_upper <= s_rdata;
  end  

end

//-----------------------------------------------------
//Mux logic for m_rdata and m_rresp
//------------------------------------------------------
//m_rdata
always_comb begin
  if (addrbit2)
    m_rdata = {i_rdata_upper,i_rdata_upper}; //Replicate upper data
                                             //on both outgoing dwords
  else
    m_rdata = {i_rdata_upper,i_rdata_lower};
end  

//m_rresp
always_comb begin
  if (addrbit2)
    m_rresp = i_rresp_upper;
  else begin
    if ((i_rresp_upper == 2'b00) && (i_rresp_lower == 2'b00))
      m_rresp = 2'b00;
    else
      m_rresp = 2'b01; //SLVERR by default
  end  

end  

endmodule

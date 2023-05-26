// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Author: Ranajoy Nandi (ranajoy.s.nandi@intel.com)
// Date: WW20, 2022
// Project: Originally designed for OSC. 
// Description: BRESP generator for Master
//-----------------------------------------------------------------------------

module whandler_bresp_gen (
  input  logic clk,
  input  logic rst_n,
  input  logic addrbit2,
  input  logic [1:0] s_bresp,
  input  logic latch_upper_bresp,
  input  logic latch_lower_bresp,
  output logic [1:0] m_bresp
);

//----------------------------------------------------
//Internal Signals
//----------------------------------------------------
logic [1:0] i_bresp_lower;
logic [1:0] i_bresp_upper;
//----------------------------------------------------
//Registers for capturing bresp from slave
//----------------------------------------------------
//Lower bresp
always_ff @(posedge clk or negedge rst_n) begin
  if (~rst_n)
    i_bresp_lower <= 2'h0;
  else if (latch_lower_bresp) 
    i_bresp_lower <= s_bresp;
  else
    i_bresp_lower <= i_bresp_lower;
end

//Upper bresp
always_ff @(posedge clk or negedge rst_n) begin
  if (~rst_n)
    i_bresp_upper <= 2'h0;
  else if (latch_upper_bresp) 
    i_bresp_upper <= s_bresp;
  else
    i_bresp_upper <= i_bresp_upper;
end

//-----------------------------------------------------
//Mux logic for m_bresp
//------------------------------------------------------
always_comb begin
  if (addrbit2)
    m_bresp = i_bresp_upper;
  else begin
    if ((i_bresp_upper == 2'b00) && (i_bresp_lower == 2'b00))
      m_bresp = 2'b00;
    else
      m_bresp = 2'b01; //SLVERR by default
  end  

end  

endmodule

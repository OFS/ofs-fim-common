// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Author: Ranajoy Nandi (ranajoy.s.nandi@intel.com)
// Date: WW20, 2022
// Project: Originally designed for OSC. 
// Description: Master FSM controller for Read Handler
//-----------------------------------------------------------------------------

module rhandler_ctrl (
  input  logic clk,
  input  logic rst_n,
  input  logic m_arvalid,
  output logic m_arready,
  output logic m_rvalid,
  input  logic m_rready,
  output logic select_upper,
  output logic start,
  input  logic done,
  input  logic addrbit2,
  output logic latch_addr,
  output logic latch_lower_rdata,
  output logic latch_upper_rdata
);  

//-------------------------------------------
//Internal Signals
//-------------------------------------------
enum logic [2:0] {
  IDLE             = 0,
  WAIT_FOR_REQUEST = 1,
  EVALUATE_REQUEST = 2,
  READ_LOWER       = 3,
  READ_UPPER       = 4,
  ISSUE_RRESP      = 5
} i_fsm_ps, i_fsm_ns;

//-----------------------------------------------
//FSM State Register
//-----------------------------------------------
always_ff @(posedge clk or negedge rst_n) begin
  if (~rst_n)
    i_fsm_ps <= IDLE;
  else
    i_fsm_ps <= i_fsm_ns;
end

//----------------------------------------------------------------
//Next State & Output Decoder. Coding this as a Mealy machine
//with unregistered outputs. Don't anticipate timing problems 
//at 100 Mhz.
//----------------------------------------------------------------
always_comb begin
  m_arready          = 1'b0;
  m_rvalid           = 1'b0;
  select_upper       = 1'b0;
  start              = 1'b0;
  latch_addr         = 1'b0;
  latch_lower_rdata  = 1'b0;
  latch_upper_rdata  = 1'b0;

  case (i_fsm_ps)
    IDLE             : i_fsm_ns = WAIT_FOR_REQUEST;
    WAIT_FOR_REQUEST : begin
                         m_arready = 1'b1;
                         if (m_arvalid) begin
                           latch_addr = 1'b1;
                           i_fsm_ns   = EVALUATE_REQUEST;  
                         end  
                         else
                           i_fsm_ns = WAIT_FOR_REQUEST;
                       end
    EVALUATE_REQUEST : begin
                         start = 1'b1;
                         if (addrbit2)
                           i_fsm_ns = READ_UPPER;
                         else
                           i_fsm_ns = READ_LOWER;
                       end
    READ_LOWER       : begin
                         if (done) begin
                           latch_lower_rdata = 1'b1;
                           start       = 1'b1;  //start upper read
                           i_fsm_ns    = READ_UPPER;
                         end  
                         else
                           i_fsm_ns    = READ_LOWER;
                       end
    READ_UPPER       : begin
                         select_upper = 1'b1;
                         if (done) begin
                           latch_upper_rdata = 1'b1;
                           i_fsm_ns = ISSUE_RRESP;
                         end  
                         else
                           i_fsm_ns = READ_UPPER;
                       end
    ISSUE_RRESP      : begin
                         m_rvalid = 1;
                         if (m_rready)
                           i_fsm_ns = WAIT_FOR_REQUEST;
                         else
                           i_fsm_ns = ISSUE_RRESP;
                       end
     default         : i_fsm_ns = IDLE;                  
  endcase  
end

endmodule


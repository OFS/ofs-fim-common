// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Author: Ranajoy Nandi (ranajoy.s.nandi@intel.com)
// Date: WW20, 2022
// Project: Originally designed for OSC. 
// Description: FSM for driving read control signals to slave side
//-----------------------------------------------------------------------------
module rhandler_slave_driver (
  input  logic rst_n,
  input  logic clk,
  input  logic start,
  output logic done,
  output logic s_arvalid,
  input  logic s_arready,
  input  logic s_rvalid,
  output logic s_rready
);

//--------------------------------------------------------
//Internal Signals
//--------------------------------------------------------
enum logic [1:0] {
  IDLE           = 0,
  WAIT_FOR_START = 1,
  ISSUE_READ     = 2,
  WAIT_FOR_RRESP = 3
} i_fsm_ps, i_fsm_ns;

logic i_start_flag;
logic i_clr_start_flag;

//--------------------------------------------------------------
//Start Flag. Required so that we don't miss the start signal
//from the master FSM.
//--------------------------------------------------------------
always_ff @(posedge clk or negedge rst_n) begin
  if (~rst_n)
    i_start_flag <= 1'b0;
  else if (start)
    i_start_flag <= 1'b1;
  else if (i_clr_start_flag)
    i_start_flag <= 1'b0;
  else
    i_start_flag <= i_start_flag;
end

//--------------------------------------------------------------
//FSM State Register
//--------------------------------------------------------------
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
  done             = 1'b0;
  i_clr_start_flag = 1'b0;
  s_arvalid        = 1'b0;
  s_rready         = 1'b0;

  case (i_fsm_ps)
    IDLE           : i_fsm_ns = WAIT_FOR_START;
    WAIT_FOR_START : begin
                       if (i_start_flag) begin
                         i_clr_start_flag = 1'b1;
                         i_fsm_ns         = ISSUE_READ;
                       end  
                       else
                         i_fsm_ns = WAIT_FOR_START;
                     end

    ISSUE_READ     : begin
                       s_arvalid = 1'b1;
                       if (s_arready)
                         i_fsm_ns = WAIT_FOR_RRESP;
                       else
                         i_fsm_ns = ISSUE_READ;
                     end

    WAIT_FOR_RRESP : begin
                       s_rready = 1'b1;
                       if (s_rvalid) begin
                         i_fsm_ns = WAIT_FOR_START;
                         done = 1'b1;
                       end  
                       else
                         i_fsm_ns = WAIT_FOR_RRESP;
                     end
    default        : i_fsm_ns = IDLE;
  endcase  
end

endmodule

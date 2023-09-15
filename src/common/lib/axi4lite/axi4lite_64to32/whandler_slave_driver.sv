// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Author: Ranajoy Nandi (ranajoy.s.nandi@intel.com)
// Date: WW20, 2022
// Project: Originally designed for OSC. 
// Description: FSM for driving AXI4 Lite control signals to slave IP
//-----------------------------------------------------------------------------

module whandler_slave_driver 
(
  input  logic rst_n,
  input  logic clk,
  output logic s_awvalid,
  input  logic s_awready,
  output logic s_wvalid,
  input  logic s_wready,
  output logic s_bready,
  input  logic s_bvalid,
  input  logic start,
  output logic done
);

//----------------------------------------------
//Internal Signals
//----------------------------------------------
enum logic [2:0] {
  IDLE             = 0,
  WAIT_FOR_START   = 1,
  ISSUE_WRITE      = 2,
  WAIT_FOR_AWREADY = 3,
  WAIT_FOR_WREADY  = 4,
  WAIT_FOR_BRESP   = 5
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
  s_awvalid        = 1'b0;
  s_wvalid         = 1'b0;
  s_bready         = 1'b0;
  done             = 1'b0;
  i_clr_start_flag = 1'b0;

  case (i_fsm_ps)
    IDLE           : i_fsm_ns = WAIT_FOR_START;

    WAIT_FOR_START : begin
                       if (i_start_flag) begin
                         i_clr_start_flag = 1;
                         i_fsm_ns         = ISSUE_WRITE;
                       end  
                       else
                         i_fsm_ns = WAIT_FOR_START;
                     end

    ISSUE_WRITE    : begin
                       s_awvalid = 1'b1;
                       s_wvalid  = 1'b1;
                       case ({s_awready, s_wready})
                         2'b00 : i_fsm_ns = ISSUE_WRITE;
                         2'b01 : i_fsm_ns = WAIT_FOR_AWREADY;
                         2'b10 : i_fsm_ns = WAIT_FOR_WREADY;
                         2'b11 : i_fsm_ns = WAIT_FOR_BRESP;
                       endcase  
                     end

    WAIT_FOR_AWREADY : begin
                         s_awvalid = 1'b1;
                         if (s_awready)
                           i_fsm_ns = WAIT_FOR_BRESP;
                         else
                           i_fsm_ns = WAIT_FOR_AWREADY;
                       end

    WAIT_FOR_WREADY : begin
                         s_wvalid = 1'b1;
                         if (s_wready)
                           i_fsm_ns = WAIT_FOR_BRESP;
                         else
                           i_fsm_ns = WAIT_FOR_WREADY;
                       end

    WAIT_FOR_BRESP : begin
                       s_bready = 1'b1;
                       if (s_bvalid) begin
                         i_fsm_ns = WAIT_FOR_START;
                         done     = 1'b1;
                       end  
                       else
                         i_fsm_ns = WAIT_FOR_BRESP;
                     end
    default        : i_fsm_ns = IDLE;                 
  endcase  
end

endmodule

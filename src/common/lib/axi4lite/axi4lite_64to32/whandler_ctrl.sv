// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Author: Ranajoy Nandi (ranajoy.s.nandi@intel.com)
// Date: WW20, 2022
// Project: Originally designed for OSC. 
// Description: Master FSM controller for Write Handler
//-----------------------------------------------------------------------------

module whandler_ctrl (
  input  logic rst_n,
  input  logic clk,
  input  logic m_awvalid,
  output logic m_awready,
  input  logic m_wvalid,
  output logic m_wready,
  input  logic m_bready,
  output logic m_bvalid,
  output logic latch_addr,
  output logic latch_data,
  output logic select_upper,
  output logic latch_upper_bresp,
  output logic latch_lower_bresp,
  //output logic copy_bresp,
  //output logic rst_bresp_gen,
  output logic slv_driver_start,
  input  logic slv_driver_done,
  input  logic upper_strb_set,
  input  logic lower_strb_set,
  input  logic addrbit2
);

//------------------------------------------------------------
//Internal Signals
//------------------------------------------------------------
enum logic [2:0] {
  IDLE             = 0,
  WAIT_FOR_REQUEST = 1,
  WAIT_FOR_ADDR    = 2,
  WAIT_FOR_DATA    = 3,
  EVALUATE_REQUEST = 4,
  WRITE_LOWER      = 5,
  WRITE_UPPER      = 6,
  ISSUE_BRESP      = 7
} i_fsm_ps, i_fsm_ns;

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
  //Assign defaults to all outputs
  m_awready          = 0;
  m_wready           = 0;
  m_bvalid           = 0;
  latch_addr         = 0;
  latch_data         = 0;
  select_upper       = 0;
  latch_upper_bresp  = 0;
  latch_lower_bresp  = 0;
  //rst_bresp_gen      = 0;
  slv_driver_start   = 0;
  //copy_bresp         = 0;

  case (i_fsm_ps)
    IDLE             : i_fsm_ns = WAIT_FOR_REQUEST;  //This state is necessary to make sure that
                                                     //the ready outputs are held at 0 while in reset.

    WAIT_FOR_REQUEST : begin               //Possible that master may issue address and data at different times
                         m_awready = 1;
                         m_wready  = 1;
                         if (m_awvalid && m_wvalid) begin
                           latch_addr    = 1;
                           latch_data    = 1;
                           //rst_bresp_gen = 1;
                           i_fsm_ns      = EVALUATE_REQUEST;
                         end 
                         else if (m_awvalid && (!m_wvalid)) begin
                           latch_addr    = 1;
                           //rst_bresp_gen = 1;
                           i_fsm_ns      = WAIT_FOR_DATA;
                         end  
                         else if (!m_awvalid && m_wvalid) begin
                           latch_data    = 1;
                           //rst_bresp_gen = 1;
                           i_fsm_ns      = WAIT_FOR_ADDR;
                         end
                         else
                           i_fsm_ns = WAIT_FOR_REQUEST;
                       end

    WAIT_FOR_ADDR    : begin
                         m_awready = 1;
                         if (m_awvalid) begin
                           latch_addr = 1;
                           i_fsm_ns   = EVALUATE_REQUEST;
                         end  
                         else
                           i_fsm_ns = WAIT_FOR_ADDR;
                       end
    
    WAIT_FOR_DATA    : begin
                         m_wready = 1;
                         if (m_wvalid) begin
                           latch_data = 1;
                           i_fsm_ns   = EVALUATE_REQUEST;
                         end  
                         else
                           i_fsm_ns = WAIT_FOR_DATA;
                       end

    EVALUATE_REQUEST : begin                       
                         casez ({addrbit2, upper_strb_set, lower_strb_set})
                           3'b11?  : begin                                               
                                       slv_driver_start = 1;
                                       i_fsm_ns         = WRITE_UPPER;
                                     end
                           3'b0?1  : begin
                                       slv_driver_start = 1;
                                       i_fsm_ns         = WRITE_LOWER;
                                     end
                           3'b010  : begin
                                       slv_driver_start = 1;
                                       i_fsm_ns = WRITE_UPPER;
                                     end
                           default : i_fsm_ns = ISSUE_BRESP;
                         endcase  
                       end
                                                                       

    WRITE_LOWER      : begin
                         if (slv_driver_done) begin
                           latch_lower_bresp = 1;
                           if (upper_strb_set) begin  //Must check for upper dword strobe as well.
                             i_fsm_ns         = WRITE_UPPER;
                             slv_driver_start = 1;
                             //copy_bresp       = 1;
                           end  
                           else
                             i_fsm_ns = ISSUE_BRESP;
                         end
                         else
                           i_fsm_ns = WRITE_LOWER;
                       end

    WRITE_UPPER      : begin
                         select_upper = 1;
                         if (slv_driver_done) begin
                           latch_upper_bresp = 1;
                           i_fsm_ns = ISSUE_BRESP;
                         end  
                         else
                           i_fsm_ns = WRITE_UPPER;
                       end

    ISSUE_BRESP      : begin
                         m_bvalid = 1;
                         if (m_bready)
                           i_fsm_ns = WAIT_FOR_REQUEST;
                         else
                           i_fsm_ns = ISSUE_BRESP;
                       end

    default          : i_fsm_ns = IDLE;
    
  endcase  

end

endmodule

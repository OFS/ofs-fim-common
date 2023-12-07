// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// Port Reset FSM 
// Features:
// 1. Port Reset FSM based on input from PORT_CONTROL, PR_RESET, and VF_FLR Resets
//-----------------------------------------------------------------------------

//`include "fpga_defines.vh"
import ofs_fim_if_pkg::*;

module port_reset_fsm #(
   parameter  SYNC_RESET_MIN_WIDTH = 256
)(
   input  logic                        clk_2x,
   input  logic                        rst_n_2x,

   // PR reset
   input  logic                        i_pr_reset,
   
   // Port CSR
   input  logic [63:0]                 i_port_ctrl, 
   input logic                         i_afu_access_ctrl, 
   output logic [63:0]                 o_port_ctrl,
   output logic                        o_vf_flr_access_err,

   // FLR signals
   input  t_sideband_from_pcie         i_pcie_p2c_sideband,
   output t_sideband_to_pcie           o_pcie_c2p_sideband,

   // Port TX traffic control
   input  logic                        i_sel_mmio_rsp,
   input  logic                        i_read_flush_done,

   // Reset outputs
   output logic                        o_port_softreset_n,
   output logic                        o_afu_softreset
);

   typedef enum {
      RESET_HOLD_BIT,
      RESET_SET_BIT,
      RESET_DEACT_BIT,
      RESET_CLEAR_BIT, 
      RESET_STATE_MAX
   } reset_control_idx;		
   
   typedef enum logic [RESET_STATE_MAX-1:0] {
      RESET_HOLD  = (1 << RESET_HOLD_BIT),
      RESET_SET   = (1 << RESET_SET_BIT),
      RESET_DEACT = (1 << RESET_DEACT_BIT),
      RESET_CLEAR = (1 << RESET_CLEAR_BIT)
   } t_fsm_reset;
   
   t_fsm_reset fsm_reset = RESET_HOLD;
   t_fsm_reset fsm_reset_next;

   logic [$clog2(SYNC_RESET_MIN_WIDTH):0] reset_pulse_width = '0;
   logic [$clog2(SYNC_RESET_MIN_WIDTH):0] reset_pulse_width_next;
   logic port_softreset_n = 1'b0;
   logic port_softreset_n_next;
   logic port_softreset_n_q = 1'b0;
   logic afu_softreset = 1'b1;
   logic afu_softreset_next;
   logic afu_softreset_q = 1'b1;

   logic port_reset; 
   logic reset_flush_done;
   logic port_deact; 

   logic reset_done_state;
   reg    vf_flr_access_error, vf_flr_access_error_d;
   logic  flr_rcvd_vf_flag;

   //AFU Reset
   assign port_reset = (  i_port_ctrl[0]  // SW initiates reset through PORT_CONTROL[0]
                        | i_pr_reset);    // PR RESET

   assign o_afu_softreset    = afu_softreset_q;
   assign o_port_softreset_n = port_softreset_n_q;


   // Reset state machine
   //-----------------------------------------------------
   // Either:
   // 1. Software writes 1 to Port Reset CSR
   // 2. System Reset
   // 3. PR state machine
   // 4. PCIe Function Level Reset (FLR)
   //
   // Conditions for deactivation.
   // The following 3 conditions should be true
   // 1. Source of the Reset should be de-asserted
   // 2. Reset pulse width is met
   // 3. All requests in fabric are drained

   always @(posedge clk_2x) begin
   
      afu_softreset_q        <= afu_softreset;
      port_softreset_n_q     <= port_softreset_n;
      
      if(!rst_n_2x) begin
         fsm_reset           <= RESET_DEACT;
         reset_pulse_width   <= '0;
         afu_softreset       <= 1'b1;
         port_softreset_n    <= 1'b0;
      end 
      else begin 
         fsm_reset           <= fsm_reset_next;
         reset_pulse_width   <= reset_pulse_width_next;
         afu_softreset       <= afu_softreset_next;
         port_softreset_n    <= port_softreset_n_next;
      end 
   end 
   
   always_comb  begin
      fsm_reset_next          = fsm_reset;
      afu_softreset_next      = afu_softreset;
      port_softreset_n_next   = port_softreset_n;
      reset_pulse_width_next  = reset_pulse_width;
      
      unique case(1'b1)
         // Assert the external & internal reset
         // Wait for Reset timer to expires
         // Wait for drain acknowledgement from write fence logic
         fsm_reset[RESET_HOLD_BIT] : begin
            afu_softreset_next    = 1'b1; 
            port_softreset_n_next = 1'b0; 

            if(reset_pulse_width[$clog2(SYNC_RESET_MIN_WIDTH)]) begin 
               fsm_reset_next = RESET_DEACT;
            end else begin // saturating timer
               reset_pulse_width_next = reset_pulse_width + 1'b1;
            end
         end

         fsm_reset[RESET_DEACT_BIT] : begin
            if(~port_reset) begin
               fsm_reset_next = RESET_CLEAR;
            end
         end

         fsm_reset[RESET_CLEAR_BIT] : begin
            afu_softreset_next    = 1'b0; // external reset, going from FIM -> AFU
            port_softreset_n_next = 1'b1;
            
            if (port_reset)
               fsm_reset_next = RESET_SET;
         end

         fsm_reset[RESET_SET_BIT]: begin
            afu_softreset_next     = 1'b1;
            reset_pulse_width_next = '0;
            
            if (i_sel_mmio_rsp) // synchronize such that you don't terminate multi-CL Wr, drain Wr channel
               fsm_reset_next  = RESET_HOLD;
         end
      endcase
   end
   
   always_ff @(posedge clk_2x or negedge rst_n_2x) begin
      if(!rst_n_2x) begin
         port_deact <= 1'b0;
         reset_flush_done <= 1'b0;
      end else begin
         port_deact <= fsm_reset[RESET_DEACT_BIT];
         reset_flush_done <= i_read_flush_done && port_deact;
      end
   end 

   always_comb begin
      o_port_ctrl = '0;
      o_port_ctrl[3] = flr_rcvd_vf_flag | i_pcie_p2c_sideband.flr_active_pf;
      o_port_ctrl[4] = reset_flush_done;

      o_pcie_c2p_sideband.flr_completed_vf_num <= i_pcie_p2c_sideband.flr_rcvd_vf_num;
      o_pcie_c2p_sideband.flr_completed_pf_num <= i_pcie_p2c_sideband.flr_rcvd_pf_num;
      o_pcie_c2p_sideband.flr_completed_vf <= reset_done_state & flr_rcvd_vf_flag;
      o_pcie_c2p_sideband.flr_completed_pf <= reset_done_state & i_pcie_p2c_sideband.flr_active_pf;
   end

   //Functional Level Reset for VF
   always_ff @(posedge clk_2x)begin 
      reset_done_state <= fsm_reset[RESET_DEACT_BIT];
   end 

   // Set Port Error register bit to indicate a VF FLR was
   // issued while the port/AFU is in PF mode as deteremined
   // by the AFU access control bit.
   // Note - The VF FLR will reset the AFU regardless of the
   //        AFU Access Control setting.
   assign o_vf_flr_access_err = vf_flr_access_error & ~vf_flr_access_error_d;  // Edge detect to set Port Error register bit.

   always_ff @(posedge clk_2x) begin
      if (~rst_n_2x | o_pcie_c2p_sideband.flr_completed_vf) begin
         vf_flr_access_error   <= 1'b0;
         vf_flr_access_error_d <= 1'b0;
      end else if (flr_rcvd_vf_flag & ~i_afu_access_ctrl) begin
         vf_flr_access_error   <= 1'b1;
         vf_flr_access_error_d <= vf_flr_access_error;
      end
   end 

   // Set flag to indicate VF FLR was issued.
   // Clear flag when VF FLR has been completed.
   always_ff @(posedge clk_2x) begin
      if (~rst_n_2x)
         flr_rcvd_vf_flag <= 1'b0;
      else if (i_pcie_p2c_sideband.flr_rcvd_vf)         // Set the flag
         flr_rcvd_vf_flag <= 1'b1;
      else if (o_pcie_c2p_sideband.flr_completed_vf)    // Clear the flag
         flr_rcvd_vf_flag <= 1'b0;
   end

   
endmodule

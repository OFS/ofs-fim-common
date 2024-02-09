// Copyright (C) 2001-2021 Intel Corporation
// SPDX-License-Identifier: MIT


//////////////////////////////////////////////////////////////////////////////
// The sim master module sends user configured address/data/instruction 
// commands to TG and the last command needs to be a write to TG_START. 
// ///////////////////////////////////////////////////////////////////////////

module altera_emif_avl_tg_2_sim_master #(
      parameter PORT_TG_CFG_ADDRESS_WIDTH     = "",
      parameter PORT_TG_CFG_WDATA_WIDTH       = "",
      parameter PORT_TG_CFG_RDATA_WIDTH       = ""
   )(
      input                                       clk,
      input                                       reset,
      output reg                                  master_write,
      output reg                                  master_read,
      output reg [PORT_TG_CFG_ADDRESS_WIDTH-1:0]  master_address,
      output reg [PORT_TG_CFG_WDATA_WIDTH-1:0]    master_writedata,
      input                                       master_waitrequest,
      input  [PORT_TG_CFG_RDATA_WIDTH-1:0]        master_readdata,
      input                                       master_readdatavalid,
      input                                       at_wait_user_stage
   );
   
   timeunit 1ns;
   timeprecision 1ps;
   import avl_tg_sim_master_defs::*;

   // Test stages definition
   typedef enum int unsigned {
      INIT,
      WRITE_USER_TRAFFIC,
      DONE
   } tst_stage_t;
   
   tst_stage_t state /* synthesis ignore_power_up */;
   tst_stage_t next_state;
   
   logic [31:0] param_row;
   
   always_ff @(posedge clk) begin
      if(reset) 
         state <= INIT;
      else
         state <= next_state;
   end

   always_comb begin
      next_state = state;
      case(state)
         INIT: begin
            if(at_wait_user_stage)
               next_state = WRITE_USER_TRAFFIC;
            else
               next_state = INIT;
         end
         WRITE_USER_TRAFFIC: begin
            if(param_row == TG_DEF_SIM_MASTER_PARAM_N_ROW - 1)
               next_state = DONE;
            else
               next_state = WRITE_USER_TRAFFIC;
         end
         DONE: next_state = DONE;
         default: next_state = state;
      endcase
   end
   
   always_ff @ (posedge clk) begin
      if(reset) 
         param_row <= '0;
      else 
         param_row <= (state == WRITE_USER_TRAFFIC)? param_row + 1'b1: '0;
   end
   
   always_ff @ (posedge clk) begin
      if(reset) begin
         master_address   <= '0;
         master_writedata <= '0;
         master_write     <= '0;
         master_read      <= '0;
      end
      else if (state == WRITE_USER_TRAFFIC) begin
         master_address   <= tg_def_sim_master_user_param[param_row][0][PORT_TG_CFG_ADDRESS_WIDTH-1:0];
         master_writedata <= tg_def_sim_master_user_param[param_row][1][PORT_TG_CFG_WDATA_WIDTH-1:0];
         master_write     <= 1'b1;
         master_read      <= 1'b0;
      end
      else begin
         master_address   <= '0;
         master_writedata <= '0;
         master_write     <= '0;
         master_read      <= '0;
      end
   end

endmodule


// Copyright (C) 2001-2021 Intel Corporation
// SPDX-License-Identifier: MIT


//This is a special test stage designed to test that data masking works correctly
//This test is reliant on a special configuration in the status checker, so the status checker
//must know this test is being run
//This is a 2 step test which first performs a set of writes, with byte enables fully unmasked,
//writing the same known data to each address. The status checker must be aware of this data.
//Following this, the byte enable generators as well as the data generators are configured to random
//and a set of writes is performed, followed by a set of reads to the same addresses
//The status checker is then responsible for verifying that the originally written data did not get
//overwritten according to the data masking, and that the remainder of the data did, and was then read
//correctly



module altera_emif_avl_tg_2_byteenable_test_stage #(
   parameter PORT_TG_CFG_ADDRESS_WIDTH    = 1,
   parameter PORT_TG_CFG_RDATA_WIDTH      = 1,
   parameter PORT_TG_CFG_WDATA_WIDTH      = 1
)(
   input                                           clk,
   input                                           rst,
   input                                           enable,
   input                                           amm_cfg_waitrequest,
   input                                           amm_cfg_readdatavalid,
   output logic [PORT_TG_CFG_ADDRESS_WIDTH-1:0]    amm_cfg_address,
   input logic  [PORT_TG_CFG_RDATA_WIDTH-1:0]      amm_cfg_readdata,
   output logic [PORT_TG_CFG_WDATA_WIDTH-1:0]      amm_cfg_writedata,
   output logic                                    amm_cfg_write,
   output logic                                    amm_cfg_read,
   output                                          stage_complete,
   input                                           emergency_brake_active
   );
   timeunit 1ns;
   timeprecision 1ps;

   import avl_tg_defs::*;

   // Counter defintions for traversing default params' associative arrays.
   // These arrays are defined in the avl_tg_defs package
   int     unsigned param_row_common;
   int     unsigned param_row_single_wr;
   int     unsigned param_row_invert_be_single_wr;
   int     unsigned param_row_single_rd;

   typedef enum int unsigned {
      INIT,
      WRITE_CFG_COMMON,
      SINGLE_WRITE,
      WAIT_START_SINGLE_WRITE,
      WAIT_FINISH_SINGLE_WRITE,
      INVERT_BE_SINGLE_WRITE,
      WAIT_START_INVERT_BE_SINGLE_WRITE,
      WAIT_FINISH_INVERT_BE_SINGLE_WRITE,
      SINGLE_READ,
      WAIT_START_SINGLE_READ,
      WAIT_FINISH_SINGLE_READ,
      DONE
   } cfg_state_t;

   // State definitions
   cfg_state_t state /* synthesis ignore_power_up */;
   cfg_state_t next_state;

   always_ff @ (posedge clk) begin : next_state_propagate
      if (rst|emergency_brake_active)
         state <= INIT;
      else
         state <= next_state;
   end // next_state_propagate

   always_comb begin : next_state_logic
      case (state)
         INIT: begin
            if (enable & ~amm_cfg_waitrequest)
               next_state = WRITE_CFG_COMMON;
            else
               next_state = INIT;
         end
         WRITE_CFG_COMMON: begin
            if (param_row_common == TG_DEF_PARAMS_BE_COMMON_N_ROWS-1 )
               next_state = SINGLE_WRITE;
            else
               next_state = WRITE_CFG_COMMON;
         end
         SINGLE_WRITE: begin
            if (param_row_single_wr == TG_DEF_PARAMS_BE_SINGLE_WR_N_ROWS-1 )
               next_state = WAIT_START_SINGLE_WRITE;
            else
               next_state = SINGLE_WRITE;
         end
         WAIT_START_SINGLE_WRITE: begin
            if (amm_cfg_waitrequest)
               next_state = WAIT_FINISH_SINGLE_WRITE;
            else
               next_state = WAIT_START_SINGLE_WRITE;
         end
         WAIT_FINISH_SINGLE_WRITE: begin
            if (~amm_cfg_waitrequest)
               next_state = INVERT_BE_SINGLE_WRITE;
            else
               next_state = WAIT_FINISH_SINGLE_WRITE;
         end
         INVERT_BE_SINGLE_WRITE: begin
            if (param_row_invert_be_single_wr == TG_DEF_PARAMS_BE_INVERT_BE_SINGLE_WR_N_ROWS-1 )
               next_state = WAIT_START_INVERT_BE_SINGLE_WRITE;
            else
               next_state = INVERT_BE_SINGLE_WRITE;
         end
         WAIT_START_INVERT_BE_SINGLE_WRITE: begin
            if (amm_cfg_waitrequest)
               next_state = WAIT_FINISH_INVERT_BE_SINGLE_WRITE;
            else
               next_state = WAIT_START_INVERT_BE_SINGLE_WRITE;
         end
         WAIT_FINISH_INVERT_BE_SINGLE_WRITE: begin
            if (~amm_cfg_waitrequest)
               next_state = SINGLE_READ;
            else
               next_state = WAIT_FINISH_INVERT_BE_SINGLE_WRITE;
         end
         SINGLE_READ: begin
            if (param_row_single_rd == TG_DEF_PARAMS_BE_SINGLE_RD_N_ROWS-1 )
               next_state = WAIT_START_SINGLE_READ;
            else
               next_state = SINGLE_READ;
         end
         WAIT_START_SINGLE_READ: begin
            if (amm_cfg_waitrequest)
               next_state = WAIT_FINISH_SINGLE_READ;
            else
               next_state = WAIT_START_SINGLE_READ;
         end
         WAIT_FINISH_SINGLE_READ: begin
             if (~amm_cfg_waitrequest)
               next_state = DONE;
             else
               next_state = WAIT_FINISH_SINGLE_READ;
         end
         DONE: begin
            next_state = INIT;
         end

         default: begin
            next_state = INIT;
         end
      endcase
   end // next_state_logic

   assign amm_cfg_read     = '0; // never need to read on this interface during this stage
   assign stage_complete   = (state == DONE);
   always_ff @ (posedge clk) begin : output_logic_param_indexes
      if (rst) begin
         param_row_common              <= '0;
         param_row_single_wr           <= '0;
         param_row_invert_be_single_wr <= '0;
         param_row_single_rd           <= '0;
      end else begin
         param_row_common              <= (state == WRITE_CFG_COMMON)               ? param_row_common              + 1'b1 : '0;
         param_row_single_wr           <= (state == SINGLE_WRITE)                   ? param_row_single_wr           + 1'b1 : '0;
         param_row_invert_be_single_wr <= (state == INVERT_BE_SINGLE_WRITE)         ? param_row_invert_be_single_wr + 1'b1 : '0;
         param_row_single_rd           <= (state == SINGLE_READ)                    ? param_row_single_rd           + 1'b1 : '0;
      end
   end // output_logic_param_indexes

   always_ff @ (posedge clk) begin : output_logic_amm_cfgs
      if (rst) begin
         amm_cfg_address      <= '0;
         amm_cfg_writedata    <= '0;
         amm_cfg_write        <= '0;
      end else begin
         if ( ~amm_cfg_waitrequest & (state == WRITE_CFG_COMMON) ) begin
            amm_cfg_address   <= def_params_be_common[param_row_common][0][PORT_TG_CFG_ADDRESS_WIDTH-1:0];
            amm_cfg_writedata <= def_params_be_common[param_row_common][1][PORT_TG_CFG_WDATA_WIDTH-1:0];
            amm_cfg_write     <= 1'b1;
         end else if ( ~amm_cfg_waitrequest & (state == SINGLE_WRITE) ) begin
               amm_cfg_address   <= def_params_be_single_wr[param_row_single_wr][0][PORT_TG_CFG_ADDRESS_WIDTH-1:0];
               amm_cfg_writedata <= def_params_be_single_wr[param_row_single_wr][1][PORT_TG_CFG_WDATA_WIDTH-1:0];
               amm_cfg_write     <= 1'b1;
         end else if ( ~amm_cfg_waitrequest & (state == INVERT_BE_SINGLE_WRITE) ) begin
            amm_cfg_address   <= def_params_be_invert_be_single_wr[param_row_invert_be_single_wr][0][PORT_TG_CFG_ADDRESS_WIDTH-1:0];
            amm_cfg_writedata <= def_params_be_invert_be_single_wr[param_row_invert_be_single_wr][1][PORT_TG_CFG_WDATA_WIDTH-1:0];
            amm_cfg_write     <= 1'b1;
         end else if ( ~amm_cfg_waitrequest & (state == SINGLE_READ) ) begin
            amm_cfg_address   <= def_params_be_single_rd[param_row_single_rd][0][PORT_TG_CFG_ADDRESS_WIDTH-1:0];
            amm_cfg_writedata <= def_params_be_single_rd[param_row_single_rd][1][PORT_TG_CFG_WDATA_WIDTH-1:0];
            amm_cfg_write     <= 1'b1;
         end else begin
            amm_cfg_address   <= '0;
            amm_cfg_writedata <= '0;
            amm_cfg_write     <= '0;
         end
      end
   end // output_logic_amm_cfgs

   // Status outputs
   assign stage_complete = (state == DONE);


endmodule




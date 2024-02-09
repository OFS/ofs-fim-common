// Copyright (C) 2001-2021 Intel Corporation
// SPDX-License-Identifier: MIT


//////////////////////////////////////////////////////////////////////////////
// This test is used for both single write/read test stage and the block write/read
// test stage. The single write read stage performs a parametrizable number of
// interleaving write and read operation.  The number of write/read cycles
// that various address generators are used are parametrizable.
// The block write/read test stage performs a parametrizable number of write
// operations, followed by the same number of read operations to the same
// addresses.  The write/read cycle repeats for a parametrizable number of
// times.  The number of write/read cycles that various address generators
// are used are also parametrizable.
//////////////////////////////////////////////////////////////////////////////

module altera_emif_avl_tg_2_rw_stage # (

   // The number of write/read cycles that each address generator is used
   parameter BLOCK_RW_MODE                  = "",
   parameter TG_TEST_DURATION               = "",
   parameter PORT_TG_CFG_ADDRESS_WIDTH      = "",
   parameter PORT_TG_CFG_RDATA_WIDTH        = "",
   parameter PORT_TG_CFG_WDATA_WIDTH        = ""
) (
   // Clock and reset
   input                                          clk,
   input                                          rst,
   input                                          enable,
   output                                         stage_complete,
   input                                          amm_cfg_waitrequest,
   input                                          amm_cfg_readdatavalid,
   output logic [PORT_TG_CFG_ADDRESS_WIDTH-1:0]   amm_cfg_address,
   output logic [PORT_TG_CFG_WDATA_WIDTH-1:0]     amm_cfg_writedata,
   input  logic [PORT_TG_CFG_RDATA_WIDTH-1:0]     amm_cfg_readdata,
   output logic                                   amm_cfg_write,
   output logic                                   amm_cfg_read,
   input                                          emergency_brake_active
);

   timeunit 1ns;
   timeprecision 1ps;

   import avl_tg_defs::*;

   // Counter defintions for traversing default params' associative arrays.
   // These arrays are defined in the avl_tg_defs package
   int     unsigned param_row_common;
   int     unsigned param_row_block_size;
   int     unsigned param_row_seq;
   int     unsigned param_row_rand;
   int     unsigned param_row_rand_seq;

   typedef enum int unsigned {
      INIT,
      WRITE_CFG_COMMON,
      WRITE_CFG_BLOCK_SIZE,
      WRITE_CFG_AND_START_SEQ,
      WAIT_START_SEQ,
      WAIT_FINISH_SEQ,
      WRITE_CFG_AND_START_RAND,
      WAIT_START_RAND,
      WAIT_FINISH_RAND,
      WRITE_CFG_AND_START_RAND_SEQ,
      WAIT_START_RAND_SEQ,
      WAIT_FINISH_RAND_SEQ,
      DONE
   } cfg_state_t;

   // State definitions
   cfg_state_t state /* synthesis ignore_power_up */;
   cfg_state_t next_state;

   always_ff @ (posedge clk) begin : next_state_propagate
      if (rst | emergency_brake_active)
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
            if (param_row_common == TG_DEF_PARAMS_RW_COMMON_N_ROWS-1 )
               next_state = WRITE_CFG_BLOCK_SIZE;
            else
               next_state = WRITE_CFG_COMMON;
         end
         WRITE_CFG_BLOCK_SIZE: begin
            if (param_row_block_size == TG_DEF_PARAMS_RW_BLOCK_SIZE_N_ROWS-1 )
               next_state = WRITE_CFG_AND_START_SEQ;
            else
               next_state = WRITE_CFG_BLOCK_SIZE;
         end
         WRITE_CFG_AND_START_SEQ: begin
            if (param_row_seq == TG_DEF_PARAMS_RW_SEQ_N_ROWS-1 )
               next_state = WAIT_START_SEQ;
            else
               next_state = WRITE_CFG_AND_START_SEQ;
         end
         WAIT_START_SEQ: begin
            if (amm_cfg_waitrequest)
               next_state = WAIT_FINISH_SEQ;
            else
               next_state = WAIT_START_SEQ;
         end
         WAIT_FINISH_SEQ: begin
            if (~amm_cfg_waitrequest)
               next_state = WRITE_CFG_AND_START_RAND;
            else
               next_state = WAIT_FINISH_SEQ;
         end
         WRITE_CFG_AND_START_RAND: begin
            if (param_row_rand == TG_DEF_PARAMS_RW_RAND_N_ROWS-1 )
               next_state = WAIT_START_RAND;
            else
               next_state = WRITE_CFG_AND_START_RAND;
         end
         WAIT_START_RAND: begin
            if (amm_cfg_waitrequest)
               next_state = WAIT_FINISH_RAND;
            else
               next_state = WAIT_START_RAND;
         end
         WAIT_FINISH_RAND: begin
            if (~amm_cfg_waitrequest)
               next_state = WRITE_CFG_AND_START_RAND_SEQ;
            else
               next_state = WAIT_FINISH_RAND;
         end
         WRITE_CFG_AND_START_RAND_SEQ: begin
            if (param_row_rand_seq == TG_DEF_PARAMS_RW_RAND_SEQ_N_ROWS-1 )
               next_state = WAIT_START_RAND_SEQ;
            else
               next_state = WRITE_CFG_AND_START_RAND_SEQ;
         end
         WAIT_START_RAND_SEQ: begin
            if (amm_cfg_waitrequest)
               next_state = WAIT_FINISH_RAND_SEQ;
            else
               next_state = WAIT_START_RAND_SEQ;
         end
         WAIT_FINISH_RAND_SEQ: begin
            if (~amm_cfg_waitrequest)
               next_state = DONE;
            else
               next_state = WAIT_FINISH_RAND_SEQ;
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
         param_row_common   <= '0;
         param_row_block_size   <= '0;
         param_row_seq      <= '0;
         param_row_rand     <= '0;
         param_row_rand_seq <= '0;
      end else begin
         param_row_common     <= (state == WRITE_CFG_COMMON)             ? param_row_common     + 1'b1 : '0;
         param_row_block_size <= (state == WRITE_CFG_BLOCK_SIZE)         ? param_row_block_size + 1'b1 : '0;
         param_row_seq        <= (state == WRITE_CFG_AND_START_SEQ)      ? param_row_seq        + 1'b1 : '0;
         param_row_rand       <= (state == WRITE_CFG_AND_START_RAND)     ? param_row_rand       + 1'b1 : '0;
         param_row_rand_seq   <= (state == WRITE_CFG_AND_START_RAND_SEQ) ? param_row_rand_seq   + 1'b1 : '0;
      end
   end // output_logic_param_indexes

   always_ff @ (posedge clk) begin : output_logic_amm_cfgs
      if (rst) begin
         amm_cfg_address      <= '0;
         amm_cfg_writedata    <= '0;
         amm_cfg_write        <= '0;
      end else begin
         if ( ~amm_cfg_waitrequest & (state == WRITE_CFG_COMMON) ) begin
            amm_cfg_address   <= def_params_rw_common[param_row_common][0][PORT_TG_CFG_ADDRESS_WIDTH-1:0];
            amm_cfg_writedata <= def_params_rw_common[param_row_common][1][PORT_TG_CFG_WDATA_WIDTH-1:0];
            amm_cfg_write     <= 1'b1;
         end else if ( ~amm_cfg_waitrequest & (state == WRITE_CFG_BLOCK_SIZE) ) begin
            if (BLOCK_RW_MODE == 0) begin
               amm_cfg_address   <= def_params_rw_block_size_single[param_row_block_size][0][PORT_TG_CFG_ADDRESS_WIDTH-1:0];
               amm_cfg_writedata <= def_params_rw_block_size_single[param_row_block_size][1][PORT_TG_CFG_WDATA_WIDTH-1:0];
               amm_cfg_write     <= 1'b1;
            end else if (TG_TEST_DURATION == "SHORT") begin
               amm_cfg_address   <= def_params_rw_block_size_short[param_row_block_size][0][PORT_TG_CFG_ADDRESS_WIDTH-1:0];
               amm_cfg_writedata <= def_params_rw_block_size_short[param_row_block_size][1][PORT_TG_CFG_WDATA_WIDTH-1:0];
               amm_cfg_write     <= 1'b1;
            end else begin
               amm_cfg_address   <= def_params_rw_block_size_long[param_row_block_size][0][PORT_TG_CFG_ADDRESS_WIDTH-1:0];
               amm_cfg_writedata <= def_params_rw_block_size_long[param_row_block_size][1][PORT_TG_CFG_WDATA_WIDTH-1:0];
               amm_cfg_write     <= 1'b1;
            end
         end else if ( ~amm_cfg_waitrequest & (state == WRITE_CFG_AND_START_SEQ) ) begin
            amm_cfg_address   <= def_params_rw_seq[param_row_seq][0][PORT_TG_CFG_ADDRESS_WIDTH-1:0];
            amm_cfg_writedata <= def_params_rw_seq[param_row_seq][1][PORT_TG_CFG_WDATA_WIDTH-1:0];
            amm_cfg_write     <= 1'b1;
         end else if ( ~amm_cfg_waitrequest & (state == WRITE_CFG_AND_START_RAND) ) begin
            amm_cfg_address   <= def_params_rw_rand[param_row_rand][0][PORT_TG_CFG_ADDRESS_WIDTH-1:0];
            amm_cfg_writedata <= def_params_rw_rand[param_row_rand][1][PORT_TG_CFG_WDATA_WIDTH-1:0];
            amm_cfg_write     <= 1'b1;
         end else if ( ~amm_cfg_waitrequest & (state == WRITE_CFG_AND_START_RAND_SEQ) ) begin
            amm_cfg_address   <= def_params_rw_rand_seq[param_row_rand_seq][0][PORT_TG_CFG_ADDRESS_WIDTH-1:0];
            amm_cfg_writedata <= def_params_rw_rand_seq[param_row_rand_seq][1][PORT_TG_CFG_WDATA_WIDTH-1:0];
            amm_cfg_write     <= 1'b1;
         end else begin
            amm_cfg_address   <= '0;
            amm_cfg_writedata <= '0;
            amm_cfg_write     <= '0;
         end
      end
   end // output_logic_amm_cfgs

endmodule


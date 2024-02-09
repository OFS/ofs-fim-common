// Copyright (C) 2001-2021 Intel Corporation
// SPDX-License-Identifier: MIT


//////////////////////////////////////////////////////////////////////////////
// This module is a wrapper for the address generators.  The generators'
// outputs are multiplexed in this module using the select signals.
// The address generation modes are sequential (from a given start address),
// random, random sequential which produces sequential addresses from a
// random start address, and one-hot
//////////////////////////////////////////////////////////////////////////////
module altera_emif_avl_tg_2_addr_gen # (
   parameter AMM_WORD_ADDRESS_WIDTH                = "",
   parameter SEQ_CNT_WIDTH                         = "",
   parameter RAND_SEQ_CNT_WIDTH                    = "",
   parameter SEQ_ADDR_INCR_WIDTH                   = "",
   parameter AMM_BURST_COUNT_DIVISIBLE_BY    = "",
   parameter AMM_WORD_ADDRESS_DIVISIBLE_BY   = "",

   // If set to true, the unix_id will be used as the MSBs of the generated address.
   // This is used to ensure:
   //
   // 1. no address overlapping when more than 1 TG is connected to the same responder.
   // 2. no nonexistent responders being targeted when NUM_TGS > NUM_RESPONDERS
   // and NUM_RESPONDER is not a power of 2.
   //
   // Note: if addr MSBs select the responder, we cannot just use the TG_ID as the MSB.
   // If the NUM_RESPONDERS is not a power of 2, then for TG_IDs where TG_ID > NUM_RESPONDER,
   // the TG_ID used as the MSB will correspond to a nonexistent responder.
   //
   // To fulfill #1 and #2, the unix_id is internally set to
   // modified_unix_id = {unix_id % NUM_RESPONDERS, unix_id / NUM_RESPONDERS}
   parameter ENABLE_UNIX_ID                        = 0,
   parameter USE_UNIX_ID                           = 0,
   parameter AMM_BURSTCOUNT_WIDTH                  = "",
   parameter NUM_RESPONDERS                        = 8
) (
   // Clock and reset
   input                                           clk,
   input                                           rst,

   // Control and status
   input                                           enable,

   input                                           start,
   input [AMM_WORD_ADDRESS_WIDTH-1:0]              start_addr,
   input [1:0]                                     addr_gen_mode,

   //for sequential mode
   input                                           seq_return_to_start_addr,
   input [SEQ_CNT_WIDTH-1:0]                       seq_addr_num,

   //for random sequential mode
   input [RAND_SEQ_CNT_WIDTH-1:0]                  rand_seq_num_seq_addr,
   input                                           rand_seq_restart_pattern,

   //increment size for sequential and random sequential addressing
   //increments avalon address
   input [SEQ_ADDR_INCR_WIDTH-1:0]                 seq_addr_increment,

   // Address generator outputs
   output   [AMM_WORD_ADDRESS_WIDTH-1:0]           addr_out,
   input    [AMM_BURSTCOUNT_WIDTH-1:0]             burstlength
);
   timeunit 1ns;
   timeprecision 1ps;

   import avl_tg_defs::*;

   localparam MAX_NUM_TG                            = 8;
   localparam UNIX_ID_REMAINDER                     = USE_UNIX_ID % NUM_RESPONDERS;
   localparam UNIX_ID_REMAINDER_WIDTH               = $clog2(NUM_RESPONDERS);
   localparam UNIX_ID_QUOTIENT                      = USE_UNIX_ID / NUM_RESPONDERS;

   // set quotient width to 1 if (MAX_NUM_TG / NUM_RESPONDERS) < 1.5 because clog2(1.49) will round down to 0.
   localparam UNIX_ID_QUOTIENT_WIDTH                = ((MAX_NUM_TG / NUM_RESPONDERS) < 1.5) ? 1 : $clog2(MAX_NUM_TG / NUM_RESPONDERS);

   localparam UNIX_ID_WIDTH                         = UNIX_ID_REMAINDER_WIDTH + UNIX_ID_QUOTIENT_WIDTH;
   localparam TRUNCATED_AMM_WORD_ADDRESS_WIDTH = (ENABLE_UNIX_ID && (NUM_RESPONDERS > 1)) ? AMM_WORD_ADDRESS_WIDTH-UNIX_ID_WIDTH : AMM_WORD_ADDRESS_WIDTH;
   logic [TRUNCATED_AMM_WORD_ADDRESS_WIDTH-1:0]      addr;

   // Sequential address generator signals
   logic                                             seq_addr_gen_enable;
   logic [TRUNCATED_AMM_WORD_ADDRESS_WIDTH-1:0]      seq_addr_gen_addr;
   logic [TRUNCATED_AMM_WORD_ADDRESS_WIDTH-1:0]      seq_start_addr;

   // Random address generator signals
   logic                                             rand_addr_gen_enable;
   logic [TRUNCATED_AMM_WORD_ADDRESS_WIDTH-1:0]      rand_addr_gen_addr;

   //one-hot address generator signals
   logic                                             one_hot_addr_gen_enable;
   logic [TRUNCATED_AMM_WORD_ADDRESS_WIDTH-1:0]      one_hot_addr_gen_addr;

   reg [RAND_SEQ_CNT_WIDTH-1:0] num_rand_seq_addr;
   always @ (posedge clk)
   begin
      if (addr_gen_mode==TG_ADDR_RAND_SEQ) begin
         num_rand_seq_addr <= rand_seq_num_seq_addr;
      end else begin
         num_rand_seq_addr <= 1'b1;
      end
   end

   generate
      if (NUM_RESPONDERS == 1)
         // When only 1 responder is used, we don't need harcoding so we just use the addr as is.
         assign addr_out = addr;
      else begin
         // For >1 responders, we need a dummy reg to output unix_id instead of just concatenating
         // the unix_id as a parameter. Otherwise, quartus will realize that some responders are
         // not being targeted and it will optimize away needed logic (case:14015302558).
         logic [UNIX_ID_WIDTH-1:0] unix_id /* synthesis dont_merge syn_preserve = 1*/;
         always @ (posedge clk) begin
            unix_id <= {UNIX_ID_REMAINDER[UNIX_ID_REMAINDER_WIDTH-1:0], UNIX_ID_QUOTIENT[UNIX_ID_QUOTIENT_WIDTH-1:0]};
         end
         // When UNIX_IDs are used, addr must be concatenated to the hardcoded MODIFIED_UNIX_ID
         // to avoid overwriting the pseudorandom bits and affecting the generated patterns.
         assign addr_out = (ENABLE_UNIX_ID == 1) ? {unix_id, addr} : addr;
      end
   endgenerate

   always_comb
   begin
      case (addr_gen_mode)
         TG_ADDR_SEQ:
         begin
            addr  = seq_addr_gen_addr;
         end
         TG_ADDR_RAND:
         begin
            addr  = rand_addr_gen_addr;
         end
         TG_ADDR_ONE_HOT:
         begin
            addr = one_hot_addr_gen_addr;
         end
         TG_ADDR_RAND_SEQ:
         begin
            addr  = rand_addr_gen_addr;
         end
         default: addr = 'x;
      endcase
   end

   // Address generator inputs
   assign seq_addr_gen_enable      = enable & (addr_gen_mode == TG_ADDR_SEQ);
   assign rand_addr_gen_enable     = enable & (addr_gen_mode == TG_ADDR_RAND || addr_gen_mode == TG_ADDR_RAND_SEQ);
   assign one_hot_addr_gen_enable  = enable & (addr_gen_mode == TG_ADDR_ONE_HOT);

   // The sequential start address should be the input start address for sequential mode.
   assign seq_start_addr = start_addr[TRUNCATED_AMM_WORD_ADDRESS_WIDTH-1:0];

   // Sequential address generator
   altera_emif_avl_tg_2_seq_addr_gen # (
      .AMM_WORD_ADDRESS_WIDTH          (TRUNCATED_AMM_WORD_ADDRESS_WIDTH),
      .SEQ_ADDR_INCR_WIDTH             (SEQ_ADDR_INCR_WIDTH),
      .SEQ_CNT_WIDTH                   (SEQ_CNT_WIDTH),
      .AMM_WORD_ADDRESS_DIVISIBLE_BY   (AMM_WORD_ADDRESS_DIVISIBLE_BY),
      .AMM_BURST_COUNT_DIVISIBLE_BY    (AMM_BURST_COUNT_DIVISIBLE_BY)
   ) seq_addr_gen_inst (
      .clk                          (clk),
      .rst                          (rst),
      .enable                       (seq_addr_gen_enable),
      .seq_addr                     (seq_addr_gen_addr),
      .start_addr                   (seq_start_addr),
      .start                        (start),
      .return_to_start_addr         (seq_return_to_start_addr),
      .seq_addr_increment           (seq_addr_increment),
      .num_seq_addr                 (seq_addr_num)
   );

   // Random address generator
   altera_emif_avl_tg_2_rand_seq_addr_gen # (
      .AMM_WORD_ADDRESS_WIDTH          (TRUNCATED_AMM_WORD_ADDRESS_WIDTH),
      .SEQ_ADDR_INCR_WIDTH             (SEQ_ADDR_INCR_WIDTH),
      .RAND_SEQ_CNT_WIDTH              (RAND_SEQ_CNT_WIDTH),
      .AMM_WORD_ADDRESS_DIVISIBLE_BY   (AMM_WORD_ADDRESS_DIVISIBLE_BY),
      .AMM_BURSTCOUNT_WIDTH            (AMM_BURSTCOUNT_WIDTH)
   ) rand_seq_addr_gen_inst (
      .clk                          (clk),
      .rst                          (rst),
      .enable                       (rand_addr_gen_enable),
      .restart_pattern              (rand_seq_restart_pattern),
      .addr_out                     (rand_addr_gen_addr),
      //number of sequential addresses between each random address
      //for full random mode, set to 1
      .num_rand_seq_addr            (num_rand_seq_addr),
      //increment size for sequential addresses
      .rand_seq_addr_increment      (seq_addr_increment),
      .seed                         (seq_start_addr),
      .burstlength                  (burstlength)
   );

   altera_emif_avl_tg_2_one_hot_addr_gen # (
      .ADDR_WIDTH                      (TRUNCATED_AMM_WORD_ADDRESS_WIDTH),
      .AMM_WORD_ADDRESS_DIVISIBLE_BY   (AMM_WORD_ADDRESS_DIVISIBLE_BY),
      .AMM_BURST_COUNT_DIVISIBLE_BY    (AMM_BURST_COUNT_DIVISIBLE_BY)
   ) one_hot_addr_gen_inst (
      .clk                          (clk),
      .rst                          (rst),
      .enable                       (one_hot_addr_gen_enable),
      .one_hot_addr                 (one_hot_addr_gen_addr),
      .start                        (start)
   );

endmodule


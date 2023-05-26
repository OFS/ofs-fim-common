// Copyright (C) 2001-2021 Intel Corporation
// SPDX-License-Identifier: MIT


//////////////////////////////////////////////////////////////////////////////
// The random sequential address generator generates sequential addresses from
// a random start address. The number of sequential addresses between each random
// address is configurable. This is set to 1 for full random mode.
// For simplicity in avoiding overlaps between sequential blocks, generate
// a random address for the upper part and zero the lower part.
//////////////////////////////////////////////////////////////////////////////
module altera_emif_avl_tg_2_rand_seq_addr_gen # (
   //total width of generated address
   parameter AMM_WORD_ADDRESS_WIDTH               = "",
   parameter SEQ_ADDR_INCR_WIDTH                  = "",
   parameter RAND_SEQ_CNT_WIDTH                   = "", // Width for number of sequential addresses between each random address
   parameter AMM_WORD_ADDRESS_DIVISIBLE_BY        = "",
   parameter AMM_BURSTCOUNT_WIDTH                 = ""
) (
   input                                         clk,
   input                                         rst,
   input                                         enable,
   input                                         restart_pattern, // signal to indicate that the pattern should restart (from seed) on the next clk cycle 

   // Number of sequential addresses between each random address
   // For full random mode, set to 1
   input [RAND_SEQ_CNT_WIDTH-1:0]                num_rand_seq_addr,       

   // Increment size for sequential addresses
   input [SEQ_ADDR_INCR_WIDTH-1:0]               rand_seq_addr_increment, 
   input [AMM_WORD_ADDRESS_WIDTH-1:0]            seed,

   output logic [AMM_WORD_ADDRESS_WIDTH-1:0]     addr_out,
   input [AMM_BURSTCOUNT_WIDTH-1:0]              burstlength                       
);
   timeunit 1ns;
   timeprecision 1ps;

   import avl_tg_defs::*;       // Required for the log2 function definition 
   
   // LFSR module controls 
   logic [31:0]                             effective_width;
   logic [31:0]                             rand_effective_width;
   logic [31:0]                             rand_seq_effective_width;
   logic                                    gen_rand_addr;
   logic [AMM_WORD_ADDRESS_WIDTH-1:0]       lfsr_output;
   logic                                    is_full_rand;

   // RAND_SEQ_ADDR controls to account for SEQ addressing 
   logic [AMM_WORD_ADDRESS_WIDTH-1:0]       rand_seq_addr_incrementer;
   logic [RAND_SEQ_CNT_WIDTH-1:0]           rand_seq_addr_cnt;

   always_ff @ (posedge clk) begin
      if (rst | restart_pattern) begin
         rand_seq_addr_cnt          <= num_rand_seq_addr;
         rand_seq_addr_incrementer  <= 0;
      end else if (enable) begin
         if (rand_seq_addr_cnt > 1) begin
            rand_seq_addr_cnt         <= rand_seq_addr_cnt - 1'b1;
            rand_seq_addr_incrementer <= rand_seq_addr_incrementer + rand_seq_addr_increment;
         end else begin
            rand_seq_addr_cnt         <= num_rand_seq_addr;
            rand_seq_addr_incrementer <= 0;
         end
      end
   end

   always_ff @(posedge clk) begin
      is_full_rand <= num_rand_seq_addr == 1'b1;
      rand_effective_width <= (AMM_WORD_ADDRESS_WIDTH-log2(AMM_WORD_ADDRESS_DIVISIBLE_BY)-ceil_log2(burstlength));
      rand_seq_effective_width <= (AMM_WORD_ADDRESS_WIDTH-log2(AMM_WORD_ADDRESS_DIVISIBLE_BY)-ceil_log2(rand_seq_addr_increment)-ceil_log2(num_rand_seq_addr));
      effective_width <= is_full_rand ? rand_effective_width : rand_seq_effective_width;
   end
   
   assign addr_out      = is_full_rand ? lfsr_output : lfsr_output + rand_seq_addr_incrementer;

   assign gen_rand_addr = enable & rand_seq_addr_cnt <= 1;

   // LFSRs for random addresses
   altera_emif_avl_tg_2_lfsr # (
      .WIDTH                      (AMM_WORD_ADDRESS_WIDTH),
      .EFFECTIVE_WIDTH_NUM_BITS   (32)
   ) rand_addr_high (
      .clk               (clk),
      .rst               (rst | restart_pattern),
      .enable            (gen_rand_addr),
      .data_out          (lfsr_output),
      .seed              (seed),
      .effective_width   (effective_width) 
   );

endmodule

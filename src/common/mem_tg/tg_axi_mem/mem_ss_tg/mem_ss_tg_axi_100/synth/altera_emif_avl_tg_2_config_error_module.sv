// (C) 2001-2021 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


module altera_emif_avl_tg_2_config_error_module # (
   parameter AMM_WORD_ADDRESS_DIVISIBLE_BY   = "",
   parameter AMM_BURST_COUNT_DIVISIBLE_BY    = "",
   parameter PORT_CTRL_AMM_WDATA_WIDTH       = "",
   parameter MEM_BE_WIDTH                    = "",
   parameter USE_AVL_BYTEEN                  = "",
   parameter NUMBER_OF_DATA_GENERATORS       = "",
   parameter NUMBER_OF_BYTE_EN_GENERATORS    = "",
   parameter DATA_RATE_WIDTH_RATIO           = "",
   parameter RAND_SEQ_CNT_WIDTH              = "",
   parameter AMM_WORD_ADDRESS_WIDTH          = "",
   parameter AMM_BURSTCOUNT_WIDTH            = "",
   parameter RW_OPERATION_COUNT_WIDTH        = "",
   parameter RW_RPT_COUNT_WIDTH              = "",
   parameter SEQ_ADDR_INCR_WIDTH             = ""
) (
   input clk,
   input reset,
   input tg_restart,

   //config registers of interest
   input [RW_OPERATION_COUNT_WIDTH-1:0]   num_reads,
   input [RW_OPERATION_COUNT_WIDTH-1:0]   num_writes,
   input [AMM_BURSTCOUNT_WIDTH-1:0]       burstlength,
   input [RW_RPT_COUNT_WIDTH-1:0]         num_read_repeats,
   input [RW_RPT_COUNT_WIDTH-1:0]         num_write_repeats,
   input [AMM_WORD_ADDRESS_WIDTH-1:0]     addr_write,
   input [1:0]                            addr_mode_write,
   input [RAND_SEQ_CNT_WIDTH-1:0]         rand_seq_addrs_write,
   input [AMM_WORD_ADDRESS_WIDTH-1:0]     addr_read,
   input [1:0]                            addr_mode_read,
   input [RAND_SEQ_CNT_WIDTH-1:0]         rand_seq_addrs_read,
   input [SEQ_ADDR_INCR_WIDTH-1:0]        seq_addr_incr,

   //error report out
   output logic [31:0]  config_error_report

);

   timeunit 1ns;
   timeprecision 1ps;

   import avl_tg_defs::*;

   wire sequential_addr_mode;
   assign sequential_addr_mode = addr_mode_write == TG_ADDR_SEQ | addr_mode_read == TG_ADDR_SEQ | addr_mode_write == TG_ADDR_RAND_SEQ | addr_mode_read == TG_ADDR_RAND_SEQ;

   int j;
   generate
   always @ (posedge clk)
   begin
      if (reset) begin
         config_error_report        <= 32'h0;
      end else begin
         config_error_report[ERR_MORE_READS_THAN_WRITES]             <= num_reads > num_writes;
         config_error_report[ERR_BURSTLENGTH_GT_SEQ_ADDR_INCR]       <= sequential_addr_mode & (burstlength > seq_addr_incr);
         config_error_report[ERR_ADDR_DIVISIBLE_BY_GT_SEQ_ADDR_INCR] <= sequential_addr_mode & (seq_addr_incr < AMM_WORD_ADDRESS_DIVISIBLE_BY[SEQ_ADDR_INCR_WIDTH-1:0]);
         config_error_report[ERR_SEQ_ADDR_INCR_NOT_DIVISIBLE]        <= sequential_addr_mode & (config_error_report[ERR_ADDR_DIVISIBLE_BY_GT_SEQ_ADDR_INCR] | (seq_addr_incr != (seq_addr_incr & ~(AMM_WORD_ADDRESS_DIVISIBLE_BY[SEQ_ADDR_INCR_WIDTH-1:0] - 1'b1))));
         config_error_report[ERR_READ_AND_WRITE_START_ADDRS_DIFFER]  <= (addr_write != addr_read);
         config_error_report[ERR_ADDR_MODES_DIFFERENT]               <= (addr_mode_write != addr_mode_read);
         config_error_report[ERR_NUMBER_OF_RAND_SEQ_ADDRS_DIFFERENT] <= (rand_seq_addrs_write != rand_seq_addrs_read) & (addr_mode_write == TG_ADDR_RAND_SEQ | addr_mode_read == TG_ADDR_RAND_SEQ);
         config_error_report[ERR_REPEATS_SET_TO_ZERO]                <= ~(|num_read_repeats[RW_RPT_COUNT_WIDTH-1:0]) | ~(|num_write_repeats[RW_RPT_COUNT_WIDTH-1:0]);
         config_error_report[ERR_BOTH_BURST_AND_REPEAT_MODE_ACTIVE]  <= (burstlength > 1) & ((|num_read_repeats[RW_RPT_COUNT_WIDTH-1:1]) | (|num_write_repeats[RW_RPT_COUNT_WIDTH-1:1]));
         config_error_report[31:ERR_BOTH_BURST_AND_REPEAT_MODE_ACTIVE+1] <= '0;
      end
   end
   endgenerate

endmodule


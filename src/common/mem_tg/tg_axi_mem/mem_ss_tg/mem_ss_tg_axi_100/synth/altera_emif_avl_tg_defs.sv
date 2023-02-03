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


//////////////////////////////////////////////////////////////////////////////
// This package contains common typedefs and function definitions for the
// example driver.
//////////////////////////////////////////////////////////////////////////////

package avl_tg_defs;

   timeunit 1ps;
   timeprecision 1ps;

   // Address generators definition
   typedef enum int unsigned {
      SEQ,
      RAND,
      RAND_SEQ,
      TEMPLATE_ADDR_GEN
   } addr_gen_select_t;


   // Returns the maximum of two numbers
   function automatic integer max;
      input integer a;
      input integer b;
      begin
         max = (a > b) ? a : b;
      end
   endfunction


   // Calculate the log_2 of the input value
   function automatic integer log2;
      input integer value;
      begin
         value = value >> 1;
         for (log2 = 0; value > 0; log2 = log2 + 1)
            value = value >> 1;
      end
   endfunction


   // Calculate the ceiling of log_2 of the input value
   function automatic integer ceil_log2;
      input integer value;
      begin
         value = value - 1;
         for (ceil_log2 = 0; value > 0; ceil_log2 = ceil_log2 + 1)
            value = value >> 1;
      end
   endfunction

   localparam RW_IDLE_COUNT_WIDTH   = 16;
   localparam LOOP_IDLE_COUNT_WIDTH = 16;

   localparam TG_CLEAR_WIDTH       = 3;
   localparam TG_CLEAR__PNF        = 0;
   localparam TG_CLEAR__READ_COUNT = 1;
   localparam TG_CLEAR__FAIL_INFO  = 2;

   localparam TG_PATTERN_PRBS           = 2'b00;
   localparam TG_PATTERN_FIXED          = 2'b01;
   localparam TG_PATTERN_PRBS_INVERTED  = 2'b10;
   localparam TG_PATTERN_FIXED_INVERTED = 2'b11;

   localparam TG_DATA_FIXED    = 6'h0;
   localparam TG_DATA_PRBS7    = 6'h1;
   localparam TG_DATA_PRBS15   = 6'h2;
   localparam TG_DATA_PRBS31   = 6'h3;
   localparam TG_DATA_ROTATING = 6'h4;

   localparam TG_ADDR_RAND     = 2'd0;
   localparam TG_ADDR_SEQ      = 2'd1;
   localparam TG_ADDR_RAND_SEQ = 2'd2;
   localparam TG_ADDR_ONE_HOT  = 2'd3;

   localparam TG_MASK_DISABLED        = 2'b00;
   localparam TG_MASK_FIXED           = 2'b01;
   localparam TG_MASK_FULL_CYCLING    = 2'b10;
   localparam TG_MASK_PARTIAL_CYCLING = 2'b11;

   // --- Address Map ---
   // Traffic generator version
   localparam TG_VERSION = 10'h0;
   // Start
   localparam TG_START = 10'h1;
   // Loop count
   localparam TG_LOOP_COUNT = 10'h2;
   // Write count
   localparam TG_WRITE_COUNT = 10'h3;
   // Read count
   localparam TG_READ_COUNT = 10'h4;
   // Write repeat count
   localparam TG_WRITE_REPEAT_COUNT = 10'h5;
   // Read repeat count
   localparam TG_READ_REPEAT_COUNT = 10'h6;
   // Burst length
   localparam TG_BURST_LENGTH = 10'h7;
   // Group-wise Selective Clear
   localparam TG_CLEAR = 10'h8;
   // Idle count within a loop
   localparam TG_RW_GEN_IDLE_COUNT = 10'hE;
   // Idle count between consecutive loops
   localparam TG_RW_GEN_LOOP_IDLE_COUNT = 10'hF;
   // Sequential start address (Write) (Lower 32 bits)
   localparam TG_SEQ_START_ADDR_WR_L = 10'h10;
   // Sequential start address (Write) (Upper 32 bits)
   localparam TG_SEQ_START_ADDR_WR_H = 10'h11;
   // Address mode
   localparam TG_ADDR_MODE_WR = 10'h12;
   // Random sequential number of addresses (Write)
   localparam TG_RAND_SEQ_ADDRS_WR = 10'h13;
   // Return to start address
   localparam TG_RETURN_TO_START_ADDR = 10'h14;
   // Sequential address increment
   localparam TG_SEQ_ADDR_INCR = 10'h1D;
   // Sequential start address (Read) (Lower 32 bits)
   localparam TG_SEQ_START_ADDR_RD_L = 10'h1E;
   // Sequential start address (Read) (Upper 32 bits)
   localparam TG_SEQ_START_ADDR_RD_H = 10'h1F;
   // Address mode (Read)
   localparam TG_ADDR_MODE_RD = 10'h20;
   // Random sequential number of addresses (Read)
   localparam TG_RAND_SEQ_ADDRS_RD = 10'h21;
   // Pass
   localparam TG_PASS = 10'h22;
   // Fail
   localparam TG_FAIL = 10'h23;
   // Failure count (lower 32 bits)
   localparam TG_FAIL_COUNT_L = 10'h24;
   // Failure count (upper 32 bits)
   localparam TG_FAIL_COUNT_H = 10'h25;
   // First failure address (lower 32 bits)
   localparam TG_FIRST_FAIL_ADDR_L = 10'h26;
   // First failure address (upper 32 bits)
   localparam TG_FIRST_FAIL_ADDR_H = 10'h27;
   // Total read count (lower 32 bits)
   localparam TG_TOTAL_READ_COUNT_L = 10'h28;
   // Total read count (upper 32 bits)
   localparam TG_TOTAL_READ_COUNT_H = 10'h29;
   // Test complete status register
   localparam TG_TEST_COMPLETE = 10'h2A;
   // Invert Byte Enable Write
   localparam TG_INVERT_BYTEEN = 10'h2B;
   // Restart Default Traffic
   localparam TG_RESTART_DEFAULT_TRAFFIC = 10'h2C;
   // Worm Enable User Mode
   localparam TG_USER_WORM_EN = 10'h2D;
   // Test byte-enable
   localparam TG_TEST_BYTEEN = 10'h2E;
   // Timeout
   localparam TG_TIMEOUT = 10'h2F;
   // Number of data generators
   localparam TG_NUM_DATA_GEN = 10'h31;
   // Number of byte enable generators
   localparam TG_NUM_BYTEEN_GEN = 10'h32;
   // Width of read data and PNF signals
   localparam TG_RDATA_WIDTH = 10'h37;
   // Error reporting register for illegal configurations of the traffic generator
   localparam TG_ERROR_REPORT = 10'h3B;
   // Data rate width ratio
   localparam TG_DATA_RATE_WIDTH_RATIO = 10'h3C;
   // Persistent PNF per bit (144*8 / 32 addresses needed)
   localparam TG_PNF = 10'h40;
   // First failure expected data (144*8 / 32 addresses needed)
   localparam TG_FAIL_EXPECTED_DATA = 10'h80;
   // First failure read data (144*8 / 32 addresses needed)
   localparam TG_FAIL_READ_DATA = 10'hC0;
   // Data generator seed
   localparam TG_DATA_SEED = 10'h100;
   // Byte enable generator seed
   localparam TG_BYTEEN_SEED = 10'h200;
   // Data per-pin pattern type selection
   localparam TG_PPPG_SEL = 10'h300;
   // Byte-Enable pattern type selection
   localparam TG_BYTEEN_SEL = 10'h3A0;

   // --- Defaults ---
   localparam TG_START_DEFAULT = '0;
   localparam TG_LOOP_COUNT_DEFAULT = 1'b1;
   localparam TG_WRITE_COUNT_DEFAULT = 1'b1;
   localparam TG_READ_COUNT_DEFAULT = 1'b1;
   localparam TG_WRITE_REPEAT_COUNT_DEFAULT = 1'b1;
   localparam TG_READ_REPEAT_COUNT_DEFAULT = 1'b1;
   localparam TG_BURST_LENGTH_DEFAULT = 1'b1;
   localparam TG_CLEAR_DEFAULT = '0;
   localparam TG_RW_GEN_IDLE_COUNT_DEFAULT = '0;
   localparam TG_RW_GEN_LOOP_IDLE_COUNT_DEFAULT = '0;
   localparam TG_SEQ_START_ADDR_WR_L_DEFAULT = '0;
   localparam TG_ADDR_MODE_WR_DEFAULT = 2'h2;
   localparam TG_RAND_SEQ_ADDRS_WR_DEFAULT = 1'b1;
   localparam TG_RETURN_TO_START_ADDR_DEFAULT = '0;
   localparam TG_SEQ_ADDR_INCR_DEFAULT = 1'b1;
   localparam TG_SEQ_START_ADDR_RD_L_DEFAULT = '0;
   localparam TG_ADDR_MODE_RD_DEFAULT = 2'h2;
   localparam TG_RAND_SEQ_ADDRS_RD_DEFAULT = 1'b1;
   localparam TG_INVERT_BYTEEN_DEFAULT = '0;
   localparam TG_RESTART_DEFAULT_TRAFFIC_DEFAULT = '0;
   localparam TG_USER_WORM_EN_DEFAULT = 1'b0;
   localparam TG_TEST_BYTEEN_DEFAULT = 1'b0;
   localparam TG_DATA_SEED_DEFAULT = 32'h5a5a5a5a;
   localparam TG_BYTEEN_SEED_DEFAULT = 32'hFFFFFFFF;
   localparam TG_PPPG_SEL_DEFAULT = '0;
   localparam TG_BYTEEN_SEL_DEFAULT = '0;

   // --- Constants ---
   // More read operations will be scheduled than write operations. Data mismatches may occur.
   localparam ERR_MORE_READS_THAN_WRITES = 32'h0;
   // The Avalon burst length exceeds the sequential address increment.  Data mismatches may occur.
   localparam ERR_BURSTLENGTH_GT_SEQ_ADDR_INCR = 32'h1;
   // The sequential address increment is smaller than the minimum required.  Data mismatches may occur.
   localparam ERR_ADDR_DIVISIBLE_BY_GT_SEQ_ADDR_INCR = 32'h2;
   // The sequential address increment is not divisible by the necessary step.  Data mismatches may occur.
   localparam ERR_SEQ_ADDR_INCR_NOT_DIVISIBLE = 32'h3;
   // The read and write start address are different.  Data mismatches may occur.
   localparam ERR_READ_AND_WRITE_START_ADDRS_DIFFER = 32'h4;
   // Read and write settings for address generation mode are different.  Data mismatches may occur.
   localparam ERR_ADDR_MODES_DIFFERENT = 32'h5;
   // Read and write settings for number of random sequential address operations are unequal.  Data mismatches may occur.
   localparam ERR_NUMBER_OF_RAND_SEQ_ADDRS_DIFFERENT = 32'h6;
   // Invalid read or write repeat count. The number of read or write repeats can not be set to 0. Data mismatches may occur.
   localparam ERR_REPEATS_SET_TO_ZERO = 32'h7;
   // Avalon burst length can not be greater than 1 when read/write repeats is greater than 1. Data mismatches may occur.
   localparam ERR_BOTH_BURST_AND_REPEAT_MODE_ACTIVE = 32'h8;

   // --- Default Flow Settings ---
   localparam TG_DEF_PARAMS_N_COLS                 = 2;
   localparam TG_DEF_PARAMS_RW_COMMON_N_ROWS  = 29;
   localparam TG_DEF_PARAMS_RW_BLOCK_SIZE_N_ROWS  = 3;
   localparam TG_DEF_PARAMS_RW_SEQ_N_ROWS  = 5;
   localparam TG_DEF_PARAMS_RW_RAND_N_ROWS  = 4;
   localparam TG_DEF_PARAMS_RW_RAND_SEQ_N_ROWS  = 7;
   localparam TG_DEF_PARAMS_BE_COMMON_N_ROWS  = 31;
   localparam TG_DEF_PARAMS_BE_SINGLE_WR_N_ROWS  = 4;
   localparam TG_DEF_PARAMS_BE_INVERT_BE_SINGLE_WR_N_ROWS  = 2;
   localparam TG_DEF_PARAMS_BE_SINGLE_RD_N_ROWS  = 5;
   localparam TG_DEF_PARAMS_TARGET_COMMON_N_ROWS  = 9;

   localparam [31:0] def_params_rw_common [TG_DEF_PARAMS_RW_COMMON_N_ROWS][TG_DEF_PARAMS_N_COLS] = '{
      '{ TG_SEQ_START_ADDR_WR_L   ,   32'd0 }, 
      '{ TG_SEQ_START_ADDR_RD_L   ,   32'd0 }, 
      '{ TG_SEQ_START_ADDR_WR_H   ,   32'd0 }, 
      '{ TG_SEQ_START_ADDR_RD_H   ,   32'd0 }, 
      '{ TG_RW_GEN_IDLE_COUNT   ,   32'd0 }, 
      '{ TG_RW_GEN_LOOP_IDLE_COUNT   ,   32'd0 }, 
      '{ TG_DATA_SEED   ,   32'h5a5a5a5a }, 
      '{ TG_DATA_SEED+1   ,   32'h5a5a5a5a }, 
      '{ TG_DATA_SEED+2   ,   32'h5a5a5a5a }, 
      '{ TG_DATA_SEED+3   ,   32'h5a5a5a5a }, 
      '{ TG_DATA_SEED+4   ,   32'h5a5a5a5a }, 
      '{ TG_DATA_SEED+5   ,   32'h5a5a5a5a }, 
      '{ TG_DATA_SEED+6   ,   32'h5a5a5a5a }, 
      '{ TG_DATA_SEED+7   ,   32'h5a5a5a5a }, 
      '{ TG_BYTEEN_SEED   ,   32'hFFFFFFFF }, 
      '{ TG_BYTEEN_SEED+1   ,   32'hFFFFFFFF }, 
      '{ TG_BYTEEN_SEED+2   ,   32'hFFFFFFFF }, 
      '{ TG_BYTEEN_SEED+3   ,   32'hFFFFFFFF }, 
      '{ TG_BYTEEN_SEED+4   ,   32'hFFFFFFFF }, 
      '{ TG_BYTEEN_SEED+5   ,   32'hFFFFFFFF }, 
      '{ TG_BYTEEN_SEED+6   ,   32'hFFFFFFFF }, 
      '{ TG_BYTEEN_SEED+7   ,   32'hFFFFFFFF }, 
      '{ TG_PPPG_SEL   ,   TG_DATA_PRBS31 }, 
      '{ TG_BYTEEN_SEL   ,   TG_DATA_FIXED }, 
      '{ TG_READ_REPEAT_COUNT   ,   32'd1 }, 
      '{ TG_WRITE_REPEAT_COUNT   ,   32'd1 }, 
      '{ TG_BURST_LENGTH   ,   32'd1 }, 
      '{ TG_INVERT_BYTEEN   ,   32'd0 }, 
      '{ TG_TEST_BYTEEN   ,   32'd0 }  
   };

   localparam [31:0] def_params_rw_block_size_single [TG_DEF_PARAMS_RW_BLOCK_SIZE_N_ROWS][TG_DEF_PARAMS_N_COLS] = '{
      '{ TG_LOOP_COUNT   ,   32'd1 }, 
      '{ TG_READ_COUNT   ,   32'd1 }, 
      '{ TG_WRITE_COUNT  ,   32'd1 }  
   };

   localparam [31:0] def_params_rw_block_size_short [TG_DEF_PARAMS_RW_BLOCK_SIZE_N_ROWS][TG_DEF_PARAMS_N_COLS] = '{
      '{ TG_LOOP_COUNT   ,   32'd8 }, 
      '{ TG_READ_COUNT   ,   32'd16 }, 
      '{ TG_WRITE_COUNT  ,   32'd16 }  
   };

   localparam [31:0] def_params_rw_block_size_long [TG_DEF_PARAMS_RW_BLOCK_SIZE_N_ROWS][TG_DEF_PARAMS_N_COLS] = '{
      '{ TG_LOOP_COUNT   ,   32'd64 }, 
      '{ TG_READ_COUNT   ,   32'd64 }, 
      '{ TG_WRITE_COUNT   ,   32'd64 }  
   };

   localparam [31:0] def_params_rw_seq [TG_DEF_PARAMS_RW_SEQ_N_ROWS][TG_DEF_PARAMS_N_COLS] = '{
      '{ TG_ADDR_MODE_WR   ,   TG_ADDR_SEQ }, 
      '{ TG_ADDR_MODE_RD   ,   TG_ADDR_SEQ }, 
      '{ TG_SEQ_ADDR_INCR   ,   32'd32 }, 
      '{ TG_BURST_LENGTH   ,   32'd3 }, 
      '{ TG_START   ,   32'd1 }  
   };

   localparam [31:0] def_params_rw_rand [TG_DEF_PARAMS_RW_RAND_N_ROWS][TG_DEF_PARAMS_N_COLS] = '{
      '{ TG_ADDR_MODE_WR   ,   TG_ADDR_RAND }, 
      '{ TG_ADDR_MODE_RD   ,   TG_ADDR_RAND }, 
      '{ TG_BURST_LENGTH   ,   32'd1 }, 
      '{ TG_START   ,   32'd1 }  
   };

   localparam [31:0] def_params_rw_rand_seq [TG_DEF_PARAMS_RW_RAND_SEQ_N_ROWS][TG_DEF_PARAMS_N_COLS] = '{
      '{ TG_ADDR_MODE_WR   ,   TG_ADDR_RAND_SEQ }, 
      '{ TG_ADDR_MODE_RD   ,   TG_ADDR_RAND_SEQ }, 
      '{ TG_RAND_SEQ_ADDRS_WR   ,   32'd32 }, 
      '{ TG_RAND_SEQ_ADDRS_RD   ,   32'd32 }, 
      '{ TG_SEQ_ADDR_INCR   ,   32'd32 }, 
      '{ TG_BURST_LENGTH   ,   32'd3 }, 
      '{ TG_START   ,   32'd1 }  
   };

   localparam [31:0] def_params_be_common [TG_DEF_PARAMS_BE_COMMON_N_ROWS][TG_DEF_PARAMS_N_COLS] = '{
      '{ TG_SEQ_START_ADDR_WR_L   ,   32'd0 }, 
      '{ TG_SEQ_START_ADDR_RD_L   ,   32'd0 }, 
      '{ TG_SEQ_START_ADDR_WR_H   ,   32'd0 }, 
      '{ TG_SEQ_START_ADDR_RD_H   ,   32'd0 }, 
      '{ TG_RW_GEN_IDLE_COUNT   ,   32'd0 }, 
      '{ TG_RW_GEN_LOOP_IDLE_COUNT   ,   32'd0 }, 
      '{ TG_DATA_SEED   ,   32'h0000000a }, 
      '{ TG_DATA_SEED+1   ,   32'h0000005a }, 
      '{ TG_DATA_SEED+2   ,   32'h00000a5a }, 
      '{ TG_DATA_SEED+3   ,   32'h00005a5a }, 
      '{ TG_DATA_SEED+4   ,   32'h000a5a5a }, 
      '{ TG_DATA_SEED+5   ,   32'h005a5a5a }, 
      '{ TG_DATA_SEED+6   ,   32'h0a5a5a5a }, 
      '{ TG_DATA_SEED+7   ,   32'h5a5a5a5a }, 
      '{ TG_BYTEEN_SEED   ,   32'h0000000a }, 
      '{ TG_BYTEEN_SEED+1   ,   32'h0000005a }, 
      '{ TG_BYTEEN_SEED+2   ,   32'h00000a5a }, 
      '{ TG_BYTEEN_SEED+3   ,   32'h00005a5a }, 
      '{ TG_BYTEEN_SEED+4   ,   32'h000a5a5a }, 
      '{ TG_BYTEEN_SEED+5   ,   32'h005a5a5a }, 
      '{ TG_BYTEEN_SEED+6   ,   32'h0a5a5a5a }, 
      '{ TG_BYTEEN_SEED+7   ,   32'h5a5a5a5a }, 
      '{ TG_PPPG_SEL   ,   TG_DATA_PRBS7 }, 
      '{ TG_BYTEEN_SEL   ,   TG_DATA_PRBS7 }, 
      '{ TG_READ_REPEAT_COUNT   ,   32'd1 }, 
      '{ TG_WRITE_REPEAT_COUNT   ,   32'd1 }, 
      '{ TG_BURST_LENGTH   ,   32'd1 }, 
      '{ TG_SEQ_ADDR_INCR   ,   32'd32 }, 
      '{ TG_LOOP_COUNT   ,   32'd1 }, 
      '{ TG_ADDR_MODE_WR   ,   TG_ADDR_SEQ }, 
      '{ TG_ADDR_MODE_RD   ,   TG_ADDR_SEQ }  
   };

   localparam [31:0] def_params_be_single_wr [TG_DEF_PARAMS_BE_SINGLE_WR_N_ROWS][TG_DEF_PARAMS_N_COLS] = '{
      '{ TG_READ_COUNT   ,   32'd0 }, 
      '{ TG_WRITE_COUNT   ,   32'd3 }, 
      '{ TG_INVERT_BYTEEN   ,   32'd0 }, 
      '{ TG_START   ,   32'd1 }  
   };

   localparam [31:0] def_params_be_invert_be_single_wr [TG_DEF_PARAMS_BE_INVERT_BE_SINGLE_WR_N_ROWS][TG_DEF_PARAMS_N_COLS] = '{
      '{ TG_INVERT_BYTEEN   ,   32'd1 }, 
      '{ TG_START   ,   32'd1 }  
   };

   localparam [31:0] def_params_be_single_rd [TG_DEF_PARAMS_BE_SINGLE_RD_N_ROWS][TG_DEF_PARAMS_N_COLS] = '{
      '{ TG_READ_COUNT   ,   32'd3 }, 
      '{ TG_WRITE_COUNT   ,   32'd0 }, 
      '{ TG_INVERT_BYTEEN   ,   32'd0 }, 
      '{ TG_TEST_BYTEEN   ,   32'd1 }, 
      '{ TG_START   ,   32'd1 }  
   };

   localparam [31:0] def_params_target_common [TG_DEF_PARAMS_TARGET_COMMON_N_ROWS][TG_DEF_PARAMS_N_COLS] = '{
      '{ TG_ADDR_MODE_RD         ,    TG_ADDR_SEQ }, 
      '{ TG_SEQ_ADDR_INCR        ,    32'd0 }, 
      '{ TG_LOOP_COUNT           ,    32'd1 }, 
      '{ TG_WRITE_COUNT          ,    32'd0 }, 
      '{ TG_READ_COUNT           ,    32'd1 }, 
      '{ TG_BURST_LENGTH         ,    32'd1 }, 
      '{ TG_WRITE_REPEAT_COUNT   ,    32'd1 }, 
      '{ TG_READ_REPEAT_COUNT    ,    32'd1 }, 
      '{ TG_START                ,    32'd1 }  
   };



endpackage




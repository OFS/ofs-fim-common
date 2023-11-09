// Copyright (C) 2001-2021 Intel Corporation
// SPDX-License-Identifier: MIT


// This is an example testbench for demonstrating the
// configuration interface of the Avalon Traffic Generator 2.0.

module altera_emif_avl_tg_2_tb();

   timeunit 1ps;
   timeprecision 1ps;

   import avl_tg_defs::*;
   import avalon_mm_pkg::*;

   // Example testbench for simulating the configuration of the traffic generator
   // using an Avalon-MM BFM.

   // Usage:
   // 1. Define TG_BFM(INDEX) as the hierarchy path of the BFM.
   // 2. Define the MACRO_TG_SEND_CFG_WRITE_TO_INDEX and MACRO_TG_SEND_CFG_READ_TO_INDEX
   // macros for each traffic generator in the design.  For example:
   // `MACRO_TG_SEND_CFG_WRITE_TO_INDEX(0)
   // `MACRO_TG_SEND_CFG_READ_TO_INDEX(0)
   // `MACRO_TG_SEND_CFG_WRITE_TO_INDEX(1)
   // `MACRO_TG_SEND_CFG_READ_TO_INDEX(1)
   // 3. Ensure that the altera_emif_avl_tg_2_top module is instantiated with the
   // BYPASS_USER_STAGE parameter set to 0.  Optionally, also set the BYPASS_DEFAULT_PATTERN
   // parameter to 1 to skip running the default traffic pattern first.
   // 4. In your testbench, use the tasks below to configure and run the traffic generator.

   //  Define the hierarchy path of the traffic generator's configuration BFM
   `define TG_BFM(INDEX) altera_emif_avl_tg_2_tb.ed_sim_inst.tg_cfg_bfm``INDEX.tg_cfg_bfm``INDEX

   `define MACRO_TG_SEND_CFG_WRITE_TO_INDEX(INDEX) \
   task automatic tg_send_cfg_write_``INDEX;\
      input [9:0]    addr;\
      input [31:0]   data;\
\
      `TG_BFM(INDEX).set_command_address(addr << 2);\
      `TG_BFM(INDEX).set_command_burst_count(1);\
      `TG_BFM(INDEX).set_command_burst_size(1);\
      `TG_BFM(INDEX).set_command_init_latency(0);\
      `TG_BFM(INDEX).set_command_request(REQ_WRITE);\
      `TG_BFM(INDEX).set_command_data(data, 0);\
      `TG_BFM(INDEX).set_command_byte_enable(4'hf, 0);\
      `TG_BFM(INDEX).set_command_idle(0, 0);\
      `TG_BFM(INDEX).set_command_timeout(0);\
      `TG_BFM(INDEX).push_command();\
      @(`TG_BFM(INDEX).signal_write_response_complete) begin\
         `TG_BFM(INDEX).pop_response();\
      end\
      $display("Traffic Generator ID %d configuration WRITE: Addr: 0x%h Data 0x%h", INDEX, addr, data);\
   endtask

   `define MACRO_TG_SEND_CFG_READ_TO_INDEX(INDEX) \
   task automatic tg_send_cfg_read_``INDEX;\
      input  [9:0]    addr;\
      output [31:0]   data;\
\
      `TG_BFM(INDEX).set_command_address(addr << 2);\
      `TG_BFM(INDEX).set_command_burst_count(1);\
      `TG_BFM(INDEX).set_command_burst_size(1);\
      `TG_BFM(INDEX).set_command_init_latency(0);\
      `TG_BFM(INDEX).set_command_request(REQ_READ);\
      `TG_BFM(INDEX).set_command_byte_enable(4'hf, 0);\
      `TG_BFM(INDEX).set_command_idle(0, 0);\
      `TG_BFM(INDEX).set_command_timeout(0);\
      `TG_BFM(INDEX).push_command();\
      @(`TG_BFM(INDEX).signal_read_response_complete) begin\
         `TG_BFM(INDEX).pop_response();\
      end\
      data = `TG_BFM(INDEX).get_response_data(0);\
      $display("Traffic Generator ID %d configuration READ: Addr: 0x%h Data: 0x%h", INDEX, addr, data);\
   endtask

   //  Define macros for tasks used to write/read the
   //  traffic generator configuration.  If more than one
   //  configuration interface index exists, define these
   //  macros for each index.
   `MACRO_TG_SEND_CFG_WRITE_TO_INDEX(0)
   `MACRO_TG_SEND_CFG_READ_TO_INDEX(0)

   initial begin
      //  Example test procedure

      integer num_data_generators;
      integer i;

      //  Wait for the interface to be ready
      wait(`TG_BFM(0).avm_waitrequest==0);

      //  Set the number of loops, block reads/writes,
      //  repeats, and burst length
      tg_send_cfg_write_0(TG_LOOP_COUNT, 2);             // The number of r/w loops to be completed before completion of the test stage. A loop is a single iteration of writes and reads. Upon completion the base address is either incremented (SEQ or RAND_SEQ) or it is replaced by a newly generated random address (RAND or RAND_SEQ).
      tg_send_cfg_write_0(TG_READ_COUNT, 15);             // The number of burst reads to be performed per traffic generator loop (this must be assigned a value equal to that assigned to the TG_WRITE_COUNT register).
      tg_send_cfg_write_0(TG_WRITE_COUNT, 15);            // The number of burst writes to be performed per traffic generator loop.
      tg_send_cfg_write_0(TG_READ_REPEAT_COUNT, 5);             // The number of read repeats to be performed per read transaction.
      tg_send_cfg_write_0(TG_WRITE_REPEAT_COUNT, 5);            // The number of write repeats to be performed per write transaction.
      tg_send_cfg_write_0(TG_BURST_LENGTH, 1);           // The size of each burst written by the traffic generator on every write, and read back on every read.
      tg_send_cfg_write_0(TG_ADDR_MODE_WR, TG_ADDR_RAND);
      tg_send_cfg_write_0(TG_ADDR_MODE_RD, TG_ADDR_RAND);

      // Set the fixed pattern for the data generators
      // and the mode to fixed pattern
      tg_send_cfg_read_0(TG_NUM_DATA_GEN, num_data_generators);
      for (i = 0; i < num_data_generators; i = i + 1) begin
         tg_send_cfg_write_0(TG_DATA_SEED + i, 32'h5A);  // Assign a seed/initial value to each of the data generators of the traffic generator
      end

      //  Begin the test
      tg_send_cfg_write_0(TG_START, 1);                  // Write any value to TG_START to initiate the traffic generator's test stage.
   end

   //  Instantiate the DUT
   ed_sim ed_sim_inst();

endmodule


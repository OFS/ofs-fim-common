// Copyright (C) 2001-2021 Intel Corporation
// SPDX-License-Identifier: MIT


`timescale 1 ps / 1 ps
//-------------------------------------------------------------------------------
// Filename    : rw_gen.v
// Description : Read-Write Enable Generator. Issues a block of "num_writes"
//                writes to different addresses (which can be random, sequential,
//                etc), performing each write "num_write_repeats" times. Then,
//                issues a block of "num_reads" reads to the read addresses,
//                performing each read "num_read_repeats" times. This sequence
//                repeats "num_loops" times, with addresses and data different on
//                every iteration of the loop.
//                The operation_handler module manages the operation counters,
//                while the rw_gen module manages the FSM and the outer loop counter.
//                Repeats are managed in the higher level traffic generator module.
//-----------------------------------------------------------------------------

module altera_emif_avl_tg_2_rw_gen #(
   //counter widths
   parameter OPERATION_COUNT_WIDTH   = "",
   parameter LOOP_COUNT_WIDTH        = "",
   parameter RW_IDLE_COUNT_WIDTH     = "",
   parameter LOOP_IDLE_COUNT_WIDTH   = "",
   parameter AMM_BURSTCOUNT_WIDTH    = ""
)(
   input        clk,
   input        rst,
   output       valid,
   output       read_enable,
   output logic write_enable,

   //Signals to address generators to generate next read or write address
   //Asserted on last write of write_rpt_cntr, last read of read_rpt_cntr
   output       next_addr_read,
   output       next_addr_write,
   output       next_data_read,
   output       next_data_write,

   //backpressure to the configuration unit
   //reconfiguration cannot be performed during operations outside IDLE state
   output       waitrequest,

   //in the interest of generating new data signals, combines cases of repeat count
   //being met and the AMM interface being ready for another operation.
   input        read_ready,
   input        write_ready,

   input        emergency_brake_asserted,

   //configuration signals
   //Perform reconfiguration, restart operations with new inputs
   input                              start,

   //input configuration counter values
   //these get registered upon input to the higher level traffic generator module
   //and will remain stable outside of IDLE state, allowing them to be used for comparisons
   //number of times to duplicate each read or write operation - inner loop
   input [OPERATION_COUNT_WIDTH-1:0]  num_writes,
   input [OPERATION_COUNT_WIDTH-1:0]  num_reads,

   //number of loops over the total write-read block of operations - outer loop
   input [LOOP_COUNT_WIDTH-1:0]       num_loops,
   input                              inf_user_mode,
   input [AMM_BURSTCOUNT_WIDTH-1:0]   burstlength,
   input [RW_IDLE_COUNT_WIDTH-1:0]    rw_gen_idle_count,
   input [LOOP_IDLE_COUNT_WIDTH-1:0]  rw_gen_loop_idle_count,

   //number of operations left in the current loop
   output [OPERATION_COUNT_WIDTH-1:0] write_cntr,
   output [AMM_BURSTCOUNT_WIDTH-1:0]  write_burst_cntr,
   output [OPERATION_COUNT_WIDTH-1:0] read_cntr
);

   timeunit 1ns;
   timeprecision 1ps;

   // counters
   reg  [LOOP_COUNT_WIDTH-1:0]      loop_cntr;
   reg  [RW_IDLE_COUNT_WIDTH-1:0]   rw_idle_cntr;
   reg  [LOOP_IDLE_COUNT_WIDTH-1:0] loop_idle_cntr;

   // indicate wether the block settings inclue this
   //operation at all (i.e. num_reads/num_writes > 0)
   wire have_reads;
   wire have_writes;
   wire write_reload;
   wire have_writes_or_reads;
   assign have_writes_or_reads = have_reads | have_writes;

   // states
   typedef enum int unsigned {
      IDLE,
      WRITE,
      WAIT_FOR_WRITES,
      READ,
      WAIT_READ,
      WAIT_LOOP
   } state_t;

   state_t state /* synthesis ignore_power_up */;

   //read and write handlers
   //handle write_cntr, read_cntr, write_rpt_cntr, read_rpt_cntr
   altera_emif_avl_tg_2_operation_handler #(OPERATION_COUNT_WIDTH, AMM_BURSTCOUNT_WIDTH)
   read_handler(
      .clk                 (clk),
      .ready               (read_ready),
      .enable              (read_enable),
      .load                (start),
      .load_operation_cntr (num_reads),
      .operation_cntr      (read_cntr),
      .operation_reload    (),
      .have_operations     (have_reads),
      .next_addr_enable    (next_addr_read),
      .next_data_enable    (next_data_read),
      //reads are not concerned with burst length, status checker will handle addressing issues
      //since read must only be asserted for one cycle
      .burstlength         ({ {(AMM_BURSTCOUNT_WIDTH-1){1'b0}}, 1'b1 }),
      .burst_counter       ()
   );
   altera_emif_avl_tg_2_operation_handler #(OPERATION_COUNT_WIDTH, AMM_BURSTCOUNT_WIDTH)
   write_handler(
      .clk                 (clk),
      .ready               (write_ready),
      .enable              (write_enable),
      .load                (start),
      .load_operation_cntr (num_writes),
      .operation_cntr      (write_cntr),
      .operation_reload    (write_reload),
      .have_operations     (have_writes),
      .next_addr_enable    (next_addr_write),
      .next_data_enable    (next_data_write),
      //writes need to be aware of burstlength for when to update the address generator
      //write must remain asserted for entirety of burst
      .burstlength         (burstlength),
      .burst_counter       (write_burst_cntr)
   );


   //State machine handling write and read enable states and looping of
   //consecutive read and write blocks
   state_t next_state;
   always @(*) begin : primary_fsm_state_logic
      case (state)
         IDLE:  begin
            if (start & have_writes_or_reads & ~emergency_brake_asserted) begin
               if (have_writes) begin
                  next_state = WRITE;
               end else begin
                  next_state = READ;
               end
            end else begin
               next_state = IDLE;
            end
         end

         WRITE: begin
            if (write_cntr==1 & write_burst_cntr==1 & write_ready & ~emergency_brake_asserted) begin               //last write of last set

               if (have_reads & rw_idle_cntr == 0) begin   //reads pending, no idle time
                  next_state    = READ;
               end else if (have_reads) begin                    //reads pending, idle time
                  next_state    = WAIT_READ;
               end else if (loop_cntr == 1) begin
                  next_state    = IDLE;
               end else begin
                  next_state    = WRITE;
               end

            end else if (emergency_brake_asserted) begin
               next_state    = IDLE;
            end else begin
               next_state    = WRITE;
            end
         end

         WAIT_READ: begin
               if (emergency_brake_asserted) begin
                  next_state    = IDLE;
               end else if (rw_idle_cntr <= 1) begin
                  next_state    = READ;
               end else begin
                  next_state    = WAIT_READ;
               end
         end

         READ:  begin
               if (read_cntr == 1 & read_ready & ~emergency_brake_asserted) begin//last read
                  if (loop_cntr > 1) begin
                     if (have_writes & (loop_idle_cntr == 0)) begin
                        next_state = WRITE;
                     end else begin
                        next_state = WAIT_LOOP;
                     end
                  end else begin //done all loops, done all operations
                     next_state    = IDLE;
                  end
               end else if (emergency_brake_asserted) begin
                  next_state    = IDLE;
               end else begin
                  next_state    = READ;
               end
         end

         WAIT_LOOP:  begin
               if (emergency_brake_asserted) begin
                  next_state    = IDLE;
               end else if (loop_idle_cntr <= 1) begin
                  next_state    = have_writes? WRITE : READ;
               end else begin
                  next_state    = WAIT_LOOP;
               end
         end
      endcase
   end

   always @(posedge clk) begin : primary_fsm_loop_counter
      if (rst) begin
         state <= IDLE;
         loop_cntr <= 1'b1;
      end else begin
         state <= next_state;

         case(state)
            IDLE:    begin
               if (start) begin
                  loop_cntr <= (inf_user_mode ? 12'd2:num_loops);
               end else begin
                  loop_cntr <= loop_cntr;
               end
            end

            WRITE:   begin
               if ( write_cntr==1 & write_burst_cntr==1 & write_ready & ~have_reads & ~inf_user_mode) begin 
                   loop_cntr <= loop_cntr - 1'b1;
               end else begin
                   loop_cntr <= loop_cntr;
               end
            end

            READ:    begin
               if (read_cntr == 1 & read_ready & ~inf_user_mode) begin
                   loop_cntr <= loop_cntr - 1'b1;
               end else begin
                   loop_cntr <= loop_cntr;
               end
            end

            default: begin                   // for idle states
               loop_cntr <= loop_cntr;
            end
         endcase

      end
   end

   always @(posedge clk) begin : primary_fsm_idle_counters
      if (rst) begin
         rw_idle_cntr   <= '0;
         loop_idle_cntr <= '0;
      end else begin

         case(state)
            IDLE:    begin
               rw_idle_cntr   <= rw_gen_idle_count;
               loop_idle_cntr <= rw_gen_loop_idle_count;
            end

            WRITE:   begin
               rw_idle_cntr   <= rw_gen_idle_count;
               loop_idle_cntr <= loop_idle_cntr;
            end

            WAIT_READ: begin
               if (rw_idle_cntr == 0) begin
                  rw_idle_cntr <= rw_gen_idle_count;
               end else begin
                  rw_idle_cntr <= rw_idle_cntr - 1'b1;
               end

               loop_idle_cntr <= loop_idle_cntr;
            end

            READ:    begin
               rw_idle_cntr   <= rw_idle_cntr;
               loop_idle_cntr <= rw_gen_loop_idle_count;
            end

            WAIT_LOOP:  begin
               rw_idle_cntr <= rw_idle_cntr;

               if (loop_idle_cntr == 0) begin
                  loop_idle_cntr <= rw_gen_loop_idle_count;   
               end else begin
                  loop_idle_cntr <= loop_idle_cntr - 1'b1;
               end
            end
         endcase

      end
   end

   // syncronized version of rst
   reg    rst_loc;

   always@ (posedge clk) begin
       if (rst)  rst_loc <= 1'b1;
       else      rst_loc <= 1'b0;
   end

   // Output Logic
   assign read_enable   = (state == READ);
   assign write_enable  = (state == WRITE);

   assign valid         = read_enable | write_enable;

   assign waitrequest   = valid | rst_loc | start;

endmodule

module altera_emif_avl_tg_2_operation_handler #(
      parameter OPERATION_COUNT_WIDTH = "",
      parameter AMM_BURSTCOUNT_WIDTH  = ""
   )(
      input                                   clk,
      input                                   ready,                 // Signal from external FSM
      input                                   enable,                // Signal from rw_gen FSM

      input        [AMM_BURSTCOUNT_WIDTH-1:0] burstlength,

      // New configurations available on inputs
      input                                   load,

      // Input operation count values
      input       [OPERATION_COUNT_WIDTH-1:0] load_operation_cntr,

      // Current counter values
      output reg  [OPERATION_COUNT_WIDTH-1:0] operation_cntr,
      output reg   [AMM_BURSTCOUNT_WIDTH-1:0] burst_counter,

      output reg                              operation_reload,
      output                                  have_operations,

      // Indicate repeat block of operations complete, update address
      output                                  next_addr_enable,
      output                                  next_data_enable

   );

   assign have_operations = load_operation_cntr > 0;

   always @ (posedge clk) begin : update_burst_counter
      if (load) begin
         burst_counter    <= burstlength;
      end else if (enable & ready) begin
         if (burst_counter > 1'b1) begin
            burst_counter   <= burst_counter - 1'b1;
         end else begin                                     // when done burst, reset counter and decrement repeats
            burst_counter   <= burstlength;
         end
      end else begin
         burst_counter      <= burst_counter;
      end
   end

   always @ (posedge clk) begin : update_operation_cntr
      if (load) begin
         operation_cntr   <= load_operation_cntr;

      end else if (enable & ready & burst_counter <= 1'b1) begin
         if (operation_cntr > 1) begin                      // when done operation, reset counter for the next loop
            operation_cntr  <= operation_cntr - 1'b1;
         end else begin
            operation_cntr  <= load_operation_cntr;
         end
      end else begin
         operation_cntr     <= operation_cntr;
      end
   end

   always @ (posedge clk) begin : update_operation_reload
      if (load) begin
         operation_reload <= 'b0;
      end else if (enable & ready & burst_counter <= 2 & operation_cntr <= 1) begin
         operation_reload <= 'b1;
      end else begin
         operation_reload <= 'b0;
      end
   end



   // assert on last burst of any operation to signal for a new address
   // only issue on last cycle of burst
   assign next_addr_enable  = enable & ready & (burst_counter == 1'b1);
   assign next_data_enable  = enable & ready;

endmodule



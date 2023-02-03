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



///////////////////////////////////////////////////////////////////////////////
// Top-level of the Avalon-MM 1x bridge.
//
// The purpose is to decouple an Avalon-MM master and an Avalon-MM slave in the
// same clock domain using a shallow FIFO. The requirements are:
//
// 1) No effiency loss (i.e. at steady state, the only reason the bridge
//    needs to stall the external Avalon-MM master is backpressure from
//    the external Avalon-MM slave)
// 2) Minimal latency penalty through the bridge.
// 3) No direct path between external slave and external master
// 4) Avalon-MM compliant.
//
// The 1x bridge is implemented as a 2-deep FIFO, the input of which is
// connected to an external AMM master. An Avalon command (read or write)
// results in one item in the FIFO. When the external AMM slave is ready to
// accept command, one item is read out of the FIFO. The output of the FIFO
// goes to a pipeline register stage before reaching the external AMM slave.
// The pipeline register stage is what decouples master and slave.
//
// A 2-deep FIFO is the minimum FIFO depth to ensure no efficiency loss
// without needing to send backpressure signal from the slave into
// the master.
//
///////////////////////////////////////////////////////////////////////////////

// Use FFs to implement FIFO. Turn off RAM inference.
(* altera_attribute = "-name AUTO_RAM_RECOGNITION OFF" *)

module altera_emif_avl_tg_amm_1x_bridge # (

   parameter AMM_WDATA_WIDTH                   = 1,
   parameter AMM_SYMBOL_ADDRESS_WIDTH          = 1,
   parameter AMM_BCOUNT_WIDTH                  = 1,
   parameter AMM_BYTEEN_WIDTH                  = 1,
   parameter CTRL_BRIDGE_EN                    = 1

) (
   // User reset
   input  logic                                               reset,

   // User clock
   input  logic                                               clk,

   // Ports for slave Avalon port
   output logic                                               amm_slave_write,
   output logic                                               amm_slave_read,
   input  logic                                               amm_slave_ready,
   output logic [AMM_SYMBOL_ADDRESS_WIDTH-1:0]                amm_slave_address,
   output logic [AMM_WDATA_WIDTH-1:0]                         amm_slave_writedata,
   output logic [AMM_BCOUNT_WIDTH-1:0]                        amm_slave_burstcount,
   output logic [AMM_BYTEEN_WIDTH-1:0]                        amm_slave_byteenable,

   // Ports for master Avalon port
   input  logic                                               amm_master_write,
   input  logic                                               amm_master_read,
   output logic                                               amm_master_ready,
   input  logic [AMM_SYMBOL_ADDRESS_WIDTH-1:0]                amm_master_address,
   input  logic [AMM_WDATA_WIDTH-1:0]                         amm_master_writedata,
   input  logic [AMM_BCOUNT_WIDTH-1:0]                        amm_master_burstcount,
   input  logic [AMM_BYTEEN_WIDTH-1:0]                        amm_master_byteenable
);
   timeunit 1ns;
   timeprecision 1ps;

   generate 
   if ( CTRL_BRIDGE_EN == 1 ) begin: bridge_en
   typedef enum {
      FIFO_EMPTY,
      FIFO_1,
      FIFO_FULL
   } fifo_state_t;

   localparam FIFO_DEPTH = 2;

   (* altera_attribute = {"-name MAX_FANOUT 5"}*) logic fifo_wptr;
   (* altera_attribute = {"-name MAX_FANOUT 5"}*) logic fifo_rptr;

   logic                      fifo_empty;
   logic                      fifo_full;
   logic                      incr_fifo_wptr;
   logic                      incr_fifo_rptr;

   // Pipeline the reset_n signal for amm_master_ready generation.
   // Don't use reset_n directly because if reset_n is promoted to global,
   // the insertion delay is big enough to cause downstream logic to fail setup timing.
   // Also duplicate the reset signal aggressively to achieve best locality for optimal timing.
   (* altera_attribute = {"-name MAX_FANOUT 5"}*) logic local_reset;
   always_ff @(posedge clk)
   begin
      if(reset)
         local_reset <= 1'b1;
      else
         local_reset <= 1'b0;
   end

   // Bridge is ready to accept new item from the AMM master whenever FIFO
   // isn't full and we're not under reset
   assign amm_master_ready = !fifo_full && !local_reset;

   // The following signals whether or not on the upcoming rising clock edge,
   // we're accepting an incoming Avalon command from the AMM master
   assign incr_fifo_wptr = (amm_master_read || amm_master_write) && !fifo_full;

   // Advance FIFO write pointer whenever we're accepting an Avalon command from master
   always_ff @(posedge clk)
   begin
      if (local_reset) begin
         fifo_wptr <= 1'b0;
      end else begin
         if (incr_fifo_wptr)
            fifo_wptr <= ~fifo_wptr;
      end
   end

   // 2-deep FIFO
   //
   // An Avalon command results in one item in the FIFO.
   //
   // We overwrite the FIFO whenever it is ready to accept data.
   // There's no need to check whether the written data is garbage
   // or not since FIFO's readiness guarantees that what we're
   // overwriting must not be valulable. Also, as long as we don't
   // change fifo_wptr we're not really writing anyway. This approach
   // avoids unnecessarily coupling amm_master_write and amm_master_read
   // to every data bit of the FIFO.
   // Also note that we don't need to store amm_master_read, since an
   // entry in the FIFO is either a read or a write.
   // Another optimization is that there's no need to reset FIFO contents.
   logic                                 fifo_write      [0:FIFO_DEPTH-1];
   logic [AMM_SYMBOL_ADDRESS_WIDTH-1:0]  fifo_address    [0:FIFO_DEPTH-1];
   logic [AMM_WDATA_WIDTH-1:0]           fifo_writedata  [0:FIFO_DEPTH-1];
   logic [AMM_BCOUNT_WIDTH-1:0]          fifo_burstcount [0:FIFO_DEPTH-1];
   logic [AMM_BYTEEN_WIDTH-1:0]          fifo_byteenable [0:FIFO_DEPTH-1];

   always_ff @(posedge clk)
   begin
      if (!fifo_full) begin
         fifo_write      [fifo_wptr] <= amm_master_write;
         fifo_address    [fifo_wptr] <= amm_master_address;
         fifo_writedata  [fifo_wptr] <= amm_master_writedata;
         fifo_burstcount [fifo_wptr] <= amm_master_burstcount;
         fifo_byteenable [fifo_wptr] <= amm_master_byteenable;
      end
   end

   // Send FIFO output into register stage
   // whenever the external AMM slave is ready to accept new command.
   // For best latency, it is possible to pop the FIFO into the
   // register stage whenever it is not occupied, even if the AMM
   // slave isn't ready, but doing so makes timing closure difficult
   // since the "occupied" signal is tightly coupled to FIFO state signals
   // which can't be easily duplicated.
   (* altera_attribute = {"-name MAX_FANOUT 1"}*) logic amm_slave_ready_int;
   assign amm_slave_ready_int = amm_slave_ready;

   // The following are control signals. When the FIFO is empty we must
   // ensure that we don't output garbage to cause a bogus read/write
   // command.
   always_ff @(posedge clk)
   begin
      if (local_reset) begin
         amm_slave_write <= 1'b0;
         amm_slave_read  <= 1'b0;
      end else begin
         if (amm_slave_ready_int) begin
            if (fifo_empty) begin
               // No command to push out.
               amm_slave_write      <= 1'b0;
               amm_slave_read       <= 1'b0;
            end else begin
               // Push out next command
               amm_slave_write      <= fifo_write[fifo_rptr];
               amm_slave_read       <= ~fifo_write[fifo_rptr];
            end
         end
      end
   end

   // The following are not control signals, so even garbage is ok.
   // The only requirement is that they must be kept unchanged when
   // the register stage isn't writable.
   always_ff @(posedge clk)
   begin
      if (amm_slave_ready_int) begin
         amm_slave_address    <= fifo_address    [fifo_rptr];
         amm_slave_burstcount <= fifo_burstcount [fifo_rptr];
         amm_slave_writedata  <= fifo_writedata  [fifo_rptr];
         amm_slave_byteenable <= fifo_byteenable [fifo_rptr];
      end
   end

   // Advance FIFO read pointer whenever FIFO isn't empty and
   // an item has been read into the register stage
   assign incr_fifo_rptr = !fifo_empty && amm_slave_ready_int;
   always_ff @(posedge clk)
   begin
      if (local_reset) begin
         fifo_rptr <= 1'b0;
      end else begin
         if (incr_fifo_rptr)
            fifo_rptr <= ~fifo_rptr;
      end
   end

   // State machine to generate fifo_empty and fifo_full.
   // An alternative approach is to append another bit to fifo_wptr and fifo_rptr
   // and use them to detect empty/full condition, but that'd be slower because
   // fifo_empty and fifo_full are combinational outputs instead of FF outputs,
   // and incrementing the fifo pointers involve 2-bit adders instead of inverters.
   // Assumption: FIFO_DEPTH == 2
   fifo_state_t fifo_state /* synthesis ignore_power_up */;

   always_ff @(posedge clk)
   begin
      if (local_reset) begin
         fifo_state <= FIFO_EMPTY;
      end else begin
         if (fifo_state == FIFO_EMPTY) begin
            if (incr_fifo_wptr) begin
               fifo_state <= FIFO_1;
            end
         end else if (fifo_state == FIFO_1) begin
            if (incr_fifo_wptr && !incr_fifo_rptr) begin
               fifo_state <= FIFO_FULL;
            end else if (!incr_fifo_wptr && incr_fifo_rptr) begin
               fifo_state <= FIFO_EMPTY;
            end
         end else begin
            if (incr_fifo_rptr) begin
               fifo_state <= FIFO_1;
            end
         end
      end
   end

   assign fifo_empty = (fifo_state == FIFO_EMPTY);
   assign fifo_full  = (fifo_state == FIFO_FULL);
   end
   else begin: bridge_disabled

   assign amm_slave_write      = amm_master_write;
   assign amm_slave_read       = amm_master_read;
   assign amm_master_ready     = amm_slave_ready;
   assign amm_slave_address    = amm_master_address;
   assign amm_slave_writedata  = amm_master_writedata;
   assign amm_slave_burstcount = amm_master_burstcount;
   assign amm_slave_byteenable = amm_master_byteenable;
   end
   endgenerate 
endmodule


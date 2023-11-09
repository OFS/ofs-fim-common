// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// FSM controller to interface with PLL reconfiguration slave AVMM interface.
// Assumes AVMM read latency 1.
//
//-----------------------------------------------------------------------------

import qph_user_clk_pkg::*;

module qph_user_clk_rcfg_fsm (
   // Clock and reset
   input  logic       clk,                  // 125 MHz 0deg SSC 
   input  logic       rst_n,                // 125 MHz Reset_n

   // 125 MHz CSR related
   input  logic [1:0] rcfg_seq,             // Sequence change starts machine
   input  logic       rcfg_write,           // 0:read;  1:write

   // Read latch control. Read latch should be reset with mmmachRst_n.
   output logic       enable_read_latch,    // Enable AMM read latch

   // MM agent
   input  logic       amm_waitrequest,      // AMM waitrequest
   output logic       amm_read,             // Reg to form ffs read  to MM
   output logic       amm_write,            // Reg to form ffs write to MM

   // Errors
   output logic       error                 // MM Machine error, fatal
);  

logic       amm_write_next;
logic       amm_read_next;

// MmMach local outputs
logic       enable_read_latch_next;   // MmMach read enable strobe, to be latched
logic       error_next;               // MmMach error, to be latched

// Machine inputs and related
logic [1:0] rcfg_seq_dly;            // Sequence change starts machine
logic       start_cmd;               // Start, seq changed
logic       write_cmd;               // 0:read;  1:write

// Reset fanout
logic       rst_n_dly;               // 125 MHz reset_n

//----------------------------------------------------------------------------

always @(posedge clk) begin
   rst_n_dly <= rst_n;
end

always @(posedge clk) begin
   if (~rst_n_dly) begin
      write_cmd    <= 1'b0;
      rcfg_seq_dly <= 2'b0;
      start_cmd    <= 1'b0;
   end else begin
      write_cmd    <= rcfg_write;
      rcfg_seq_dly <= rcfg_seq;
      start_cmd    <= |(rcfg_seq_dly ^ rcfg_seq);
   end
end

// State machine
typedef enum {
   RESET_BIT,   // Power on default
   IDLE_BIT,
   WRITE_BIT,
   READ_BIT,
   EPILOGUE_BIT,
   ERROR_START_BIT,
   MAX_STATE_BIT
} e_state_idx;

typedef enum logic [MAX_STATE_BIT-1:0] {
   RESET       =  (1 << RESET_BIT),   // Power on default
   IDLE        =  (1 << IDLE_BIT),
   WRITE       =  (1 << WRITE_BIT),
   READ        =  (1 << READ_BIT),
   EPILOGUE    =  (1 << EPILOGUE_BIT),
   ERROR_START =  (1 << ERROR_START_BIT)
} e_state;

e_state state, next_state;

always_ff @(posedge clk) begin
   if (~rst_n_dly) begin
      state <= RESET;
   end else begin
      state <= next_state;
   end
end

// FSM inputs: start_cmd, write_cmd, amm_waitrequest
always_comb begin
   // Defaults
   amm_read_next          = 1'b0;
   amm_write_next         = 1'b0;
   enable_read_latch_next = 1'b0;
   error_next             = 1'b0;

   unique case (1'b1)
      state[RESET_BIT] : begin
         // This is also power-on state
         // Held here with state variable reset
         if (start_cmd) begin
            // Start command active error
            next_state = ERROR_START;
         end else begin
            // Off to IDLE
            next_state = IDLE;
         end
      end

      state[IDLE_BIT] : begin
         // Waits for start command
         if (start_cmd) begin
            // Start requested
            if (write_cmd) begin
               // Write command requested
               // Activate write next cycle
               // Off to write
               amm_write_next = 1'b1;
               next_state     = WRITE;
            end else begin
               // Read  command requested
               // Activate read  next cycle
               amm_read_next = 1'b1; 
               next_state    = READ; // Off to read
            end
         end else begin
            // Wait again
            next_state = IDLE;
         end
      end

      state[WRITE_BIT] : begin
         // Write is high this cycle
         if (start_cmd) begin
            // Error, start requested!
            next_state = ERROR_START;
         end else if (~amm_waitrequest) begin
            // Write accepted, activate readback latch to xfer seq
            enable_read_latch_next = 1'b1;
            next_state = EPILOGUE; // Off to epilogue
         end else begin
            // Wait again and with write
            amm_write_next = 1'b1;
            next_state     = WRITE;
         end
      end

      state[READ_BIT] : begin
         // Read is high this cycle
         if (start_cmd) begin
            // Error, start requested!
            next_state = ERROR_START;
         end else if (~amm_waitrequest) begin
            // Read accepted, activate readback latch to xfer seq
            enable_read_latch_next = 1'b1;
            next_state = EPILOGUE; // Off to epilogue
         end else begin
            // Wait again and with read
            amm_read_next = 1'b1;
            next_state    = READ;
         end
      end

      state[EPILOGUE_BIT] : begin
         // Readback latch enable high this state
         if (start_cmd) begin
            next_state = ERROR_START; // Error, start requested!
         end else begin 
            next_state = IDLE; // All okay, off to idle
         end
      end

      state[ERROR_START_BIT] : begin
         // Fatal error, restart during operation
         error_next  = 1'b1;
         next_state  = ERROR_START;
      end
   endcase
end

// Register read/write commands
always_ff @(posedge clk) begin
   amm_read  <= amm_read_next;
   amm_write <= amm_write_next;
end

always_ff @(posedge clk) begin
   if (~rst_n_dly) begin
      enable_read_latch <= 1'b0;
      error     <= 1'b0;
   end else begin
      enable_read_latch <= enable_read_latch_next;
      error             <= (error | error_next);
   end
end

endmodule

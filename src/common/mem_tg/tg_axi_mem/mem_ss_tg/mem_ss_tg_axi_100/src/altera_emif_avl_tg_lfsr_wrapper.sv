// Copyright (C) 2001-2021 Intel Corporation
// SPDX-License-Identifier: MIT


//////////////////////////////////////////////////////////////////////////////
// This module is a wrapper for the Linear feedback shift registers (LFSR)
// module.  Since the LFSR module has a maximum width (32), this wrapper is
// used to instantiates multiple LFSR modules for an arbitrary width.
//////////////////////////////////////////////////////////////////////////////
module altera_emif_avl_tg_lfsr_wrapper # (
   parameter DATA_WIDTH   = "",
   parameter SEED         = 36'b000000111110000011110000111000110010
) (
   // Clock and reset
   input  logic                      clk,
   input  logic                      reset_n,

   // Control and output
   input  logic                      enable,
   output logic [DATA_WIDTH-1:0]     data
);
   timeunit 1ns;
   timeprecision 1ps;
   
   import avl_tg_defs::*;

   // The maximum width of a single LFSR
   localparam MAX_LFSR_WIDTH = 36;

   // Number of LFSR modules required
   localparam NUM_LFSR = num_lfsr(DATA_WIDTH);

   // The width of each LFSR
   localparam LFSR_WIDTH = max(4, (DATA_WIDTH + NUM_LFSR - 1) / NUM_LFSR);

   // LFSR outputs
   logic [NUM_LFSR*LFSR_WIDTH-1:0] lfsr_data;

   // Connect output data
   assign data = lfsr_data[DATA_WIDTH-1:0];

   // Instantiate LFSR modules
   generate
      genvar i;
      for (i = 0; i < NUM_LFSR; i++)
      begin : lfsr_gen
         altera_emif_avl_tg_lfsr # (
            .WIDTH     (LFSR_WIDTH),
            .SEED      (SEED * (i + 1) + i)
         ) lfsr_inst (
            .clk       (clk),
            .reset_n   (reset_n),
            .enable    (enable),
            .data      (lfsr_data[((i+1)*LFSR_WIDTH-1):(i*LFSR_WIDTH)])
         );
      end
   endgenerate

   // Calculate the number of LFSR modules needed for the specified width
   function integer num_lfsr;
      input integer data_width;
      begin
         num_lfsr = 1;
         while ((data_width + num_lfsr - 1) / num_lfsr > MAX_LFSR_WIDTH)
            num_lfsr = num_lfsr * 2;
      end
   endfunction

   // Simulation assertions
   // synthesis translate_off
   initial
   begin
      assert (NUM_LFSR * LFSR_WIDTH >= DATA_WIDTH) else $error ("Invalid LSFR width");
   end
   // synthesis translate_on
endmodule


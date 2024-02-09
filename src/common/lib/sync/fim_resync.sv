// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//   A general purpose resynchronization module that uses the recommended altera_std_synchronizer 
//   and altera_std_synchronizer_nocut synchronizer
//  
//   Parameters:
//         SYNC_CHAIN_LENGTH
//               Length of the synchronizer chain for metastability retiming.
//         WIDTH
//               Number of bits to synchronize. Controls the width of the d and q ports.
//         INIT_VALUE
//               Initial values of the synchronization registers.
//         NO_CUT
//               0 : Enable embedded set_false path SDC
//               1 : DIsable embedded set_false_path SDC
//        
//-----------------------------------------------------------------------------

`timescale 1ps / 1ps 

module fim_resync #(
   parameter SYNC_CHAIN_LENGTH = 2,  // Number of flip-flops for retiming. Must be >1
   parameter WIDTH             = 1,  // Number of bits to resync
   parameter INIT_VALUE        = 0,
   parameter NO_CUT		= 1	  // See description above
)(
   input  logic              clk,
   input  logic              reset,
   input  logic  [WIDTH-1:0] d,
   output logic  [WIDTH-1:0] q
);

localparam  INT_LEN       = (SYNC_CHAIN_LENGTH > 1) ? SYNC_CHAIN_LENGTH : 2;
localparam  L_INIT_VALUE  = (INIT_VALUE == 1) ? 1'b1 : 1'b0;

genvar ig;

// Generate a synchronizer chain for each bit
generate
   for(ig=0;ig<WIDTH;ig=ig+1) begin : resync_chains
      wire d_in;   // Input to sychronization chain.
      wire sync_d_in;
      wire sync_q_out;
      
      assign d_in = d[ig];
      
      // Adding inverter to the input of first sync register and output of the last sync register to implement power-up high for INIT_VALUE=1
      assign sync_d_in = (INIT_VALUE == 1) ? ~d_in : d_in;
      assign q[ig] = (INIT_VALUE == 1)  ? ~sync_q_out : sync_q_out;
      
      if (NO_CUT == 0) begin
         // Synchronizer with embedded set_false_path SDC
         altera_std_synchronizer #(
            .depth(INT_LEN)				
         ) synchronizer (
            .clk      (clk),
            .reset_n  (~reset),
            .din      (sync_d_in),
            .dout     (sync_q_out)
         );
         
         //synthesis translate_off			
         initial begin
            synchronizer.dreg = {(INT_LEN-1){1'b0}};
            synchronizer.din_s1 = 1'b0;
         end
         //synthesis translate_on

      end else begin
         // Synchronizer WITHOUT embedded set_false_path SDC
         altera_std_synchronizer_nocut #(
            .depth(INT_LEN)
         ) synchronizer_nocut (
            .clk      (clk),
            .reset_n  (~reset),
            .din      (sync_d_in),
            .dout     (sync_q_out)
         );

         //synthesis translate_off
         initial begin
            synchronizer_nocut.dreg = {(INT_LEN-1){1'b0}};
            synchronizer_nocut.din_s1 = 1'b0;
         end
         //synthesis translate_on	
      end
   end // for loop
endgenerate
endmodule

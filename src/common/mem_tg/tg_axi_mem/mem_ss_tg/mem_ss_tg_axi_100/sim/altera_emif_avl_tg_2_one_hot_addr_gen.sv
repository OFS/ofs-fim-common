// Copyright (C) 2001-2021 Intel Corporation
// SPDX-License-Identifier: MIT


//////////////////////////////////////////////////////////////////////////////
// The one hot address generator rotates the one hot address across the address pins
//////////////////////////////////////////////////////////////////////////////
module altera_emif_avl_tg_2_one_hot_addr_gen # (
   parameter ADDR_WIDTH                      = "",
   parameter AMM_BURST_COUNT_DIVISIBLE_BY    = "",
   parameter AMM_WORD_ADDRESS_DIVISIBLE_BY   = ""
) (
   // Clock and reset
   input                         clk,
   input                         rst,

   // Control and status
   input                         enable,

   input                         start,

   // Address generator outputs
   output logic [ADDR_WIDTH-1:0] one_hot_addr
);

   timeunit 1ns;
   timeprecision 1ps;
   localparam MAX_PARAM_WIDTH = (ADDR_WIDTH > 32)? 32 : ADDR_WIDTH;

   // Sequential address generation
   always_ff @(posedge clk)
   begin
      //go back to start address when starting a new series of reads or writes
      if (rst) begin
         one_hot_addr <= (ADDR_WIDTH > 32) ? {(ADDR_WIDTH){1'b0}} | AMM_WORD_ADDRESS_DIVISIBLE_BY[MAX_PARAM_WIDTH-1:0] : AMM_WORD_ADDRESS_DIVISIBLE_BY[ADDR_WIDTH-1:0];
      end else begin
         if (start)
            one_hot_addr <= (ADDR_WIDTH > 32) ? {(ADDR_WIDTH){1'b0}} | AMM_WORD_ADDRESS_DIVISIBLE_BY[MAX_PARAM_WIDTH-1:0] : AMM_WORD_ADDRESS_DIVISIBLE_BY[ADDR_WIDTH-1:0];
         else if (enable) begin
            if (one_hot_addr[ADDR_WIDTH-1]) begin
               one_hot_addr <= (ADDR_WIDTH > 32) ? {(ADDR_WIDTH){1'b0}} | AMM_WORD_ADDRESS_DIVISIBLE_BY[MAX_PARAM_WIDTH-1:0] : AMM_WORD_ADDRESS_DIVISIBLE_BY[ADDR_WIDTH-1:0];
            end else begin
               one_hot_addr <= one_hot_addr << 1;
            end
         end
      end
   end

endmodule


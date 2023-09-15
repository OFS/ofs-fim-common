// Copyright (C) 2001-2021 Intel Corporation
// SPDX-License-Identifier: MIT


//-----------------------------------------------------------------------------
// Filename    : pppg.v
// Description : Pattern Generators for PRBS polynominals and deterministic
//                sequences. In deterministic mode, the per-bit
//                pattern generator produces a repeating bit pattern of length
//                corresponding to PATTERN_LENGTH parameter using series of
//                circular shift registers
//                The PRBS data is panellized such that in order to reproduce
//                the PRBS it must be serialized from MSB to LSB.
//                Deterministic data is stored and shifted to match.
//
//Illegal PRBS State: 1 in MSB, others => 0
//This additional illegal PRBS input is due to the fact that PRBS uses only n-1
//registers, while the deterministic patterns use n.
//
// Supported Patterns - PRBS-7, PRBS-15, PRBS-31, Deterministic
// Supported Output Data widths = 4, 8
//
// Copyright (c) Altera Corporation 1997-2014
// All rights reserved
//
//-----------------------------------------------------------------------------

//Each module synthesizes with a FF usage equal to the PATTERN_LENGTH + 2
//and a max LUT depth of 2

import avl_tg_defs::*;


//Generates X bit parallel output using PRBS or deterministic sequence
module altera_emif_avl_tg_2_per_pin_pattern_gen#(
   parameter DATA_WIDTH         = 8,
   parameter MAX_PATTERN_LENGTH = 32,                 
   parameter AMM_CFG_DATA_WIDTH = "",
   parameter PPPG_SEL_WIDTH = "",
   parameter PATTERN_SEL_DEFAULT = "",
   parameter SEED_DEFAULT = ""
)(
   input                            clk,
   input                            rst,
   
   //load enable signal to update load_data
   input                            data_gen_load,
   input                            pattern_gen_load,
   input                            tg_start_detected,
   
   //Data mode: 0 for prbs output, 1 for deterministic sequence based on load_data
   input                               enable,
   input      [AMM_CFG_DATA_WIDTH-1:0] reg_gen_data,
   output reg [AMM_CFG_DATA_WIDTH-1:0]                   seed_data,  
   output reg [PPPG_SEL_WIDTH-1:0]                    pattern_sel,  
   output     [DATA_WIDTH-1:0]         dout
);
   timeunit 1ns;
   timeprecision 1ps;

   reg [AMM_CFG_DATA_WIDTH-1:0]   x, d, rotating_fixed_data, fixed_data, prbs_data_7, prbs_data_15, prbs_data_31;

   assign dout = x[DATA_WIDTH-1:0];

   always_comb begin
      //  FIXED  pattern
      d = x;
      d = (d[DATA_WIDTH-1:0]);               
      fixed_data = d;
   
      //  ROTATING  pattern
      d = x;
      repeat (DATA_WIDTH) d = {d[0],d[MAX_PATTERN_LENGTH-1:1]};         
      rotating_fixed_data = d;
      
      //  PRBS7  pattern
      d = x;
      repeat (DATA_WIDTH) d = {d[6:0] ,d[6]^d[5]};        
      prbs_data_7 = d;

      // PRBS15  pattern
      d = x;
      repeat (DATA_WIDTH) d = {d[14:0],d[14]^d[13]};
      prbs_data_15 = d;

      // PRBS31  pattern
      d = x;
      repeat (DATA_WIDTH) d = {d[30:0],d[30]^d[27]};
      prbs_data_31 = d;
   end

   always @ (posedge clk) begin
      if(rst) begin
          x                    <= '0;
          pattern_sel          <= PATTERN_SEL_DEFAULT;
          seed_data            <= SEED_DEFAULT;
      end else begin
          if (data_gen_load) begin
            x           <= reg_gen_data[AMM_CFG_DATA_WIDTH-1:0];
            seed_data   <= reg_gen_data[AMM_CFG_DATA_WIDTH-1:0];
          
          end if (pattern_gen_load) begin
            pattern_sel <= reg_gen_data[5:0];
          
          end if (tg_start_detected) begin
            x           <= seed_data;

          end if (enable) begin
            case(pattern_sel)      
               TG_DATA_FIXED:      x <= fixed_data;
               TG_DATA_ROTATING:   x <= rotating_fixed_data;
               TG_DATA_PRBS7:      x <= prbs_data_7;
               TG_DATA_PRBS15:     x <= prbs_data_15;
               TG_DATA_PRBS31:     x <= prbs_data_31;
               default:            x <= fixed_data;
            endcase
         end
      end
   end
endmodule

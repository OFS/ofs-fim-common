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
// The Pseudo-Random Shift Registers (LFSR) generates 2^n-1 pseudo random
// numbers where n is the width of the LFSR.
//////////////////////////////////////////////////////////////////////////////
module altera_emif_avl_tg_2_lfsr # (
   parameter WIDTH   = 40,
   parameter EFFECTIVE_WIDTH_NUM_BITS = 32,
   parameter MAX_WIDTH = 40
) (
   // Clock and reset
   input  logic               clk,
   input  logic               rst,

   // Control
   input  logic               enable,

   // LFSR output
   output logic [WIDTH-1:0]   data_out,

   input logic [WIDTH-1:0]    seed,
   
   input  logic [EFFECTIVE_WIDTH_NUM_BITS - 1:0]        effective_width

);
   timeunit 1ns;
   timeprecision 1ps;

   logic [WIDTH-1:0] data;
   
   localparam [MAX_WIDTH - 1:0] taps [MAX_WIDTH+1] = '{
      40'b0,                                                       //   0:   unused
      40'b0,                                                       //   1:   unused
      40'b11,                                                      //   2:   taps:   2,   1 
      40'b011,                                                     //   3:   taps:   3,   2
      40'b0011,                                                    //   4:   taps:   4,   3
      40'b00101,                                                   //   5:   taps:   5,   3 
      40'b000011,                                                  //   6:   taps:   6,   5
      40'b0000011,                                                 //   7:   taps:   7,   6
      40'b00011101,                                                //   8:   taps:   8,   6,   5,   4  
      40'b000010001,                                               //   9:   taps:   9,   5
      40'b0000001001,                                              //   10:  taps:   10,   7
      40'b00000000101,                                             //   11:  taps:   11,   9
      40'b000001010011,                                            //   12:  taps:   12,   11,   8,   6
      40'b0000000011011,                                           //   13:  taps:   13,   12,   10,  9
      40'b00000000101011,                                          //   14:  taps:   14,   13,   11,  9
      40'b000000000000011,                                         //   15:  taps:   15,   14
      40'b0000000000101101,                                        //   16:  taps:   16,   14,   13,  11
      40'b00000000000001001,                                       //   17:  taps:   17,   14
      40'b000000000010000001,                                      //   18:  taps:   18,   11
      40'b0000000000000100111,                                     //   19:  taps:   19,   18,   17,  14
      40'b00000000000000001001,                                    //   20:  taps:   20,   17
      40'b000000000000000000101,                                   //   21:  taps:   21,   19
      40'b0000000000000000000011,                                  //   22:  taps:   22,   21
      40'b00000000000000000100001,                                 //   23:  taps:   23,   18
      40'b000000000000000000011011,                                //   24:  taps:   24,   23,   21,   20
      40'b0000000000000000000001001,                               //   25:  taps:   25,   22
      40'b00000000000000000001000111,                              //   26:  taps:   26,   25,   24,   20
      40'b000000000000000000000100111,                             //   27:  taps:   27,   26,   25,   22
      40'b0000000000000000000000001001,                            //   28:  taps:   28,   25
      40'b00000000000000000000000000101,                           //   29:  taps:   29,   27
      40'b000000000000000000000001010011,                          //   30:  taps:   30,   29,   26,   24
      40'b0000000000000000000000000001001,                         //   31:  taps:   31,   28
      40'b00000000000000000000000011000101,                        //   32:  taps:   32,   30,   26,   25
      40'b000000000000000000010000000000001,                       //   33:  taps:   33,   20
      40'b0000000000000000000000000100011001,                      //   34:  taps:   34,   31,   30,   26
      40'b00000000000000000000000000000000101,                     //   35:  taps:   35,   33
      40'b000000000000000000000000100000000001,                    //   36:  taps:   36,   25   
      40'b0000000000000000000000000000001010011,                   //   37:  taps:   37,   36,   33,   31
      40'b00000000000000000000000000000001100011,                  //   38:  taps:   38,   37,   33,   32
      40'b000000000000000000000000000000000010001,                 //   39:  taps:   39,   35
      40'b0000000000000000000000000000000000111001                 //   40:  taps:   40,   37,   36,   35
   };

   // masking bits based on effective width 
   integer j;
   always_comb begin
      data_out = {WIDTH{1'b0}};
      for (j = 1; j < WIDTH+1; j++) begin
         if(effective_width == j) data_out = data << WIDTH - j;
      end
   end

   integer i;
   always_ff @(posedge clk) begin
      if (rst) begin
         data <= seed;
      end else if (enable) begin
         for (i = 0; i < WIDTH - 1; i++) begin
             data[i] <= (effective_width == i + 1) ? (~^(data[WIDTH-1:0] & taps[i + 1][WIDTH-1:0])) : (data[i+1]);
         end
         data[WIDTH-1] <= ~^(data[WIDTH-1:0] & taps[WIDTH][WIDTH-1:0]);
      end
   end
   
   // Simulation assertions
   // synthesis translate_off
   initial begin
      assert (WIDTH >= 2 && WIDTH <= 40) else $error ("Invalid LSFR width");
   end
   // synthesis translate_on

endmodule

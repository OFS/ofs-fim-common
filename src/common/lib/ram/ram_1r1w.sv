// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// ram_1r1w.sv: Generic simple dual port RAM with one write port and one read port
// Copyright Intel 2008
// edited by pratik marolia on 3/15/2010
// Created 2008Oct16
// referenced Arthur's VHDL version
//
// Generic dual port RAM. This module helps to keep your HDL code architecture
// independent. 
//
// Four modes are supported. All of them use synchronous write and differ only
// in read. 
// Mode  Read Latency   write-to-read latency   Read behavior
// 0     0              1                       asynchronous read
// 1     1              1                       Unknown data on simultaneous access
// 2     1              2                       Old data on simultaneous access
// 3     2              2                       Unknown data on simultaneous access
//
// This module makes use of synthesis tool's automatic RAM recognition feature.
// It can infer distributed as well as block RAM. The type of inferred RAM
// depends on GRAM_STYLE and mode. Mode 0 can only be mapped to
// distributed RAM. Mode 1/2/3 can be mapped to either distributed or block
// RAM. There are three supported values for GRAM_STYLE.
// GRAM_AUTO : Let the tool to decide 
// GRAM_BLCK : Use block RAM
// GRAM_DIST : Use distributed RAM
// 
// Diagram of GRAM:
//
//           +---+      +------------+     +------+
//   raddr --|1/3|______|            |     | 2/3  |
//           |>  |      |            |-----|      |-- dout
//           +---+      |            |     |>     |
//        din __________|   RAM      |     +------+
//      waddr __________|            |
//        we  __________|            |
//        clk __________|\           |
//                      |/           |
//                      +------------+
//
// You can override parameters to customize RAM.
//
`include "vendor_defines.vh"

module ram_1r1w #(
   parameter   DEPTH           =   4,         // number of bits of address bus
   parameter   WIDTH           =   32,        // number of bits of data bus
   parameter   GRAM_MODE       =   2'd3,      // GRAM read mode
   parameter   GRAM_STYLE      =  `GRAM_AUTO, // GRAM_AUTO, GRAM_BLCK, GRAM_DIST
   parameter   INCLUDE_PARITY  =   0,         // 0: Disable parity 1: Enable parity
   parameter   BITS_PER_PARITY =   32,        // number of data BITS PER parity bit
   parameter   PIPELINE_PERR   =   0          // Adds one pipeline register stage in parity error detection logic.
)(
   input  logic              clk,             // clock
   input  logic              we,              // write enable
   input  logic  [DEPTH-1:0] waddr,           // write address with configurable width
   input  logic  [WIDTH-1:0] din,             // write data with configurable width
   input  logic  [DEPTH-1:0] raddr,           // read address with configurable width
   input  logic              re,              // read enable
   
   output logic  [WIDTH-1:0] dout,            // perr_or error
   output logic              perr             // write data with configurable width
);              

//-----------------------------------------------------------------

localparam PARITY_WIDTH = (WIDTH%BITS_PER_PARITY == 0) ? (WIDTH/BITS_PER_PARITY) :( WIDTH/BITS_PER_PARITY+1);

logic [WIDTH-1:0]           ram_dout; // registered ram output
logic [PARITY_WIDTH-1:0]    perr_in;  // input parity
logic                       perr_or;  // or of all parity error check
logic                       re_q;     // read enable 1 clk delayed
logic                       re_qq;    // read enable 2 clk delayed

assign dout  = ram_dout[WIDTH-1:0]        ;// output  parity error

always_ff @(posedge clk)
begin
    re_q    <= re                                                  ;
    re_qq   <= re_q                                                ;
end

generate
  case (GRAM_MODE)
    0: begin : GEN_ASYN_READ                    // asynchronous read
    //----------------------------------------------------------------------- 
        always @(*) perr = perr_or & re;
       end
    1: begin : GEN_SYN_READ                     // synchronous read
    //-----------------------------------------------------------------------
         always @(*)
                perr = perr_or & re_q;
       end
    2: begin : GEN_FALSE_SYN_READ               // False synchronous read, buffer output
    //-----------------------------------------------------------------------
         always @(*)
                perr = perr_or & re_q;
       end
    3: begin : GEN_SYN_READ_BUF_OUTPUT          // synchronous read, buffer output
    //-----------------------------------------------------------------------
         always @(*)
                perr = perr_or & re_qq;
       end
  endcase
endgenerate
//------------------------------------------------------------------------------------------------------------------------------------------------------------//

generate 
if (INCLUDE_PARITY) begin
    logic     [PARITY_WIDTH-1:0]    perr_out, perr_out_int; // output parity computed
    logic     [PARITY_WIDTH-1:0]    perr_expected;          // output parity from RAM
    logic     [PARITY_WIDTH-1:0]    perr_expected_int;      // output parity from RAM

    calc_parity #( .WIDTH (WIDTH), .BITS_PER_PARITY(BITS_PER_PARITY) )
    inst_calc_parity_before
    (
        .clk    (clk),
        .din    (din),
        .parity (perr_in)
    );

    calc_parity #( .WIDTH (WIDTH), .BITS_PER_PARITY(BITS_PER_PARITY) )
    inst_calc_parity_after
    (
        .clk    (clk),
        .din    (ram_dout[WIDTH-1:0]),
        .parity (perr_out)
    );

    if (PIPELINE_PERR) begin
       always_ff @(posedge clk)
       begin
          perr_out_int      <= perr_out;
          perr_expected_int <= perr_expected;
       end
    end else begin
       always @(*) 
       begin
          perr_out_int      = perr_out;
          perr_expected_int = perr_expected;
       end
    end

    always @(*) perr_or = |(perr_out_int ^ perr_expected_int);

    gram_sdp #( 
       .BUS_SIZE_ADDR ( DEPTH),
       .BUS_SIZE_DATA ( PARITY_WIDTH+WIDTH),
       .GRAM_MODE     ( GRAM_MODE),
       .GRAM_STYLE    ( GRAM_STYLE)
    ) 
    inst_gram_sdp 
    (
      .clk   ( clk                       ) ,
      .we    ( we                        ) ,
      .waddr ( waddr                     ) ,
      .din   ( {perr_in, din}            ) ,
      .raddr ( raddr                     ) ,
      .dout  ( {perr_expected, ram_dout} ) 
    );
end else begin
   always @(*) perr_or = 0;
   
   gram_sdp #( 
     .BUS_SIZE_ADDR ( DEPTH),
     .BUS_SIZE_DATA ( WIDTH),
     .GRAM_MODE     ( GRAM_MODE),
     .GRAM_STYLE    ( GRAM_STYLE)
   ) 
   inst_gram_sdp 
   (
     .clk   ( clk                       ) ,
     .we    ( we                        ) ,
     .waddr ( waddr                     ) ,
     .din   ( din                       ) ,
     .raddr ( raddr                     ) ,
     .dout  ( ram_dout                  ) 
   );
end
endgenerate

endmodule

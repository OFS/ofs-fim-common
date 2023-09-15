// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// gram_sdp.v: Generic simple dual port RAM with one write port and one read port
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
// It can infer LAB as well as Block RAM. The type of inferred RAM
// depends on GRAM_STYLE and mode. Mode 0 can only be mapped to
// LAB RAM. Mode 1/2/3 can be mapped to either LAB or Block 
// RAM. There are three supported values for GRAM_STYLE.
// GRAM_AUTO : Let the tool to decide 
// GRAM_BLCK : Use Block RAM
// GRAM_LAB : Use LAB RAM
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

module gram_sdp (clk,      // input   clock
                we,        // input   write enable
                waddr,     // input   write address with configurable width
                din,       // input   write data with configurable width
                raddr,     // input   read address with configurable width
                dout);     // output  write data with configurable width

parameter BUS_SIZE_ADDR =4;          // number of bits of address bus
parameter BUS_SIZE_DATA =32;         // number of bits of data bus
parameter GRAM_MODE      =2'd3;       // GRAM read mode
parameter GRAM_STYLE     =`GRAM_AUTO; // GRAM_AUTO, GRAM_BLCK, GRAM_DIST
localparam RAM_BLOCK_TYPE = GRAM_STYLE ==`GRAM_BLCK ? "M20K"
			      : GRAM_STYLE ==`GRAM_DIST ? "MLAB"
   		   	      :"AUTO";

input                           clk;
input                           we;
input   [BUS_SIZE_ADDR-1:0]     waddr;
input   [BUS_SIZE_DATA-1:0]     din;
input   [BUS_SIZE_ADDR-1:0]     raddr;
output  [BUS_SIZE_DATA-1:0]     dout;

(* `GRAM_STYLE = GRAM_STYLE *)
logic [BUS_SIZE_DATA-1:0] ram [(2**BUS_SIZE_ADDR)-1:0];

logic [BUS_SIZE_ADDR-1:0] raddr_q;
logic [BUS_SIZE_DATA-1:0] dout;
logic [BUS_SIZE_DATA-1:0] ram_dout;
/*synthesis translate_off */
logic                     driveX;         // simultaneous access detected. Drive X on output
/*synthesis translate_on */

generate
  case (GRAM_MODE)
    0: begin : GEN_ASYN_READ                    // asynchronous read
    //-----------------------------------------------------------------------
        always @(posedge clk)
        begin
          if (we)
            ram[waddr]<=din; // synchronous write the RAM
        end

         always @(*) dout = ram[raddr];
       end
    1: begin : GEN_SYN_READ                     // synchronous read
    //-----------------------------------------------------------------------
        always @(posedge clk)
         begin  
                if (we)
                  ram[waddr]<=din; // synchronous write the RAM

                                                /* synthesis translate_off */
                if(driveX)
                        dout <= 'hx;
                else                            /* synthesis translate_on */
                        dout <= ram[raddr];
         end
                                                /*synthesis translate_off */
         always @(*)
         begin
                driveX = 0;
                                                
                if(raddr==waddr && we)
                        driveX  = 1;
                else    driveX  = 0;            
   
         end                                    /*synthesis translate_on */
         
       end
    2: begin : GEN_FALSE_SYN_READ               // False synchronous read, buffer output
    //-----------------------------------------------------------------------
       always @(*)
         begin
                ram_dout = ram[raddr];
                                                /*synthesis translate_off */
                if(raddr==waddr && we)
                ram_dout = 'hx;                 /*synthesis translate_on */
         end
         always @(posedge clk)
         begin
                if (we)
                  ram[waddr]<=din; // synchronous write the RAM

                dout <= ram_dout;
         end
       end
    3: begin : GEN_SYN_READ_BUF_OUTPUT          // synchronous read, buffer output
    //-----------------------------------------------------------------------
        `ifdef SIM_MODE
           always @(posedge clk)
            begin
                  if (we)
                    ram[waddr]<=din; // synchronous write the RAM

                   ram_dout<= ram[raddr];
                   dout    <= ram_dout;
                                                   /*synthesis translate_off */
                   if(driveX)
                   dout    <= 'hx;
                   if(raddr==waddr && we)
                           driveX <= 1;
                   else    driveX <= 0;            /*synthesis translate_on */
            end
        `else   // Compilation 
            ram_sdp_wysiwyg #(
                .BUS_SIZE_ADDR  (BUS_SIZE_ADDR),
                .BUS_SIZE_DATA  (BUS_SIZE_DATA),
                .RAM_BLOCK_TYPE (RAM_BLOCK_TYPE)
            )
            inst_ram_sdp_wysiwyg
            (
                .clock     ( clk),
                .data      ( din),
                .rdaddress ( raddr),
                .wraddress ( waddr),
                .wren      ( we),
                .q         ( dout)
            );

        `endif
       end
  endcase
endgenerate

endmodule

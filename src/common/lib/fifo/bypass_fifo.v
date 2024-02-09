// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

//synopsys translate_off
//`time_scale
//synopsys translate_on

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//  MODULE NAME:  bypass_fifo.v
//
//  This module contains the generic logic for a dual port FIFO which can be
//  read one cycle after writing.
//
//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

module bypass_fifo (
                    //inputs
                    clk
                    ,reset_n
                    //Inputs
                    ,write
                    ,write_data
                    ,read

                    //Outputs
                    ,read_data
                    ,fifo_empty
                    ,nafull
                    ,fifo_count
                    ,write_pointer
                    ,read_pointer
                    );

   parameter DATA_WIDTH   = 256;
   parameter ADDR_WIDTH   = 10;
   parameter AFULL_COUNT  = (2**ADDR_WIDTH)-8;
   parameter [0:0] BYPASS = 1;

   input                   clk;
   input                   reset_n;
   input                   write;
   input [DATA_WIDTH-1:0]  write_data;
   input                   read;

   output [DATA_WIDTH-1:0] read_data;
   output                  fifo_empty;
   output                  nafull;
   output [ADDR_WIDTH-1:0] fifo_count;
   output [ADDR_WIDTH-1:0] write_pointer;
   output [ADDR_WIDTH-1:0] read_pointer;

   wire                    clk;
   wire                    reset_n;
   wire                    write;
   wire [DATA_WIDTH-1:0]   write_data;
   wire                    read;

   //outputs
   wire [DATA_WIDTH-1:0]   read_data;      // Data used as output for read commands
   wire                    fifo_empty;
   reg                     nafull;
   reg [ADDR_WIDTH-1:0]    fifo_count;
   wire [ADDR_WIDTH-1:0]   write_pointer;
   wire [ADDR_WIDTH-1:0]   read_pointer;

   wire [ADDR_WIDTH-1:0]   write_pointer_value = 0;
   wire [ADDR_WIDTH-1:0]   read_pointer_value = 0;

   wire [ADDR_WIDTH-1:1]   leading_zeros_wire = 0;

   always @(posedge clk) begin
      if (~reset_n) begin
         fifo_count <= 0;
      end else begin
         if (write & ~read) begin
            fifo_count <= fifo_count + {leading_zeros_wire, 1'b1};
         end else if (~write & read) begin
            fifo_count <= fifo_count - {leading_zeros_wire, 1'b1};
         end
      end
      nafull <= ~(fifo_count >= AFULL_COUNT);
   end // always @ (posedge clk)

   fifo_w_rewind #(.ADDR_WIDTH(ADDR_WIDTH),
                          .DATA_WIDTH(DATA_WIDTH),
                          .BYPASS(BYPASS))
   fifo_w_rewind (
                         //Inputs
                         .clk                   (clk)
                         ,.reset_n              (reset_n)
                         ,.write                (write)
                         ,.write_data           (write_data)
                         ,.read                 (read)
                         ,.load_write_pointer   (1'b0)
                         ,.write_pointer_value  (write_pointer_value)
                         ,.load_read_pointer    (1'b0)
                         ,.read_pointer_value   (read_pointer_value)

                         //Outputs
                         ,.read_data            (read_data)
                         ,.fifo_empty           (fifo_empty)
                         ,.nafull               ()
                         ,.write_pointer        (write_pointer)
                         ,.read_pointer         (read_pointer)
                         );



   //synopsys translate_off

   always @(posedge clk) begin
      if ((&fifo_count) & write) begin
         $display("T:%8d ERROR: %m Wrote to the FIFO when FIFO count was %4X", $time, fifo_count);
         #1;
         $finish;
      end
   end

   //synopsys translate_on

endmodule

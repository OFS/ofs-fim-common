//------------Endianess Adapter--------------------------------------------//
//This adapter is inserted when there is a mismatch in the endianess between source and sink //
// src_ denotes coming / going to sink
// snk_ denotes coming / going to source

`timescale 1 ns / 1 ns

module intel_st_dbg_endianness_adp 
 # (
 parameter SYM_SIZE = 8 ,// fixed
 parameter NUM_SYM  = 16 ,// set from hw_tcl
 parameter SRC_ENDIANNESS = 0,
 parameter SNK_ENDIANNESS = 1,
 parameter CHANNEL_W  = 11,

 //Internal Parameters 
 parameter DATA_W = 128, // set from hw_tcl
 parameter EMPTY_W = 4 //set from hw_tcl

 ) (

 input logic clk,
 input logic rst,

 // Sink Interface wrt DUT
  output logic                      snk_ready,
  input  logic [DATA_W-1:0]         snk_data,
  input  logic                      snk_valid,
  input  logic                      snk_sop,
  input  logic                      snk_eop,
  input  logic [EMPTY_W-1:0]        snk_empty,
  input  logic [CHANNEL_W-1: 0]     snk_channel,


 // Source Interface wrt DUT
  input logic                        src_ready,
  output  logic [DATA_W-1:0]         src_data,
  output  logic                      src_valid,
  output  logic                      src_sop,
  output  logic                      src_eop,
  output  logic [EMPTY_W-1:0]        src_empty,
  output  logic [CHANNEL_W-1: 0]     src_channel

 );


 // wiring for passthrough
 assign snk_ready = src_ready;
 assign src_valid = snk_valid;
 assign src_sop   = snk_sop;
 assign src_eop   = snk_eop;
 assign src_empty = snk_empty;
 assign src_channel = snk_channel;

 genvar i;
 generate if ( SRC_ENDIANNESS == SNK_ENDIANNESS ) begin
          assign src_data = snk_data;
            end 
          else begin
            for (i = 0; i < NUM_SYM; i=i+1) begin
              assign  src_data[((((i+NUM_SYM)-2*i)*8)-1) -: 8] = snk_data[i*8 +: 8];
            end
          end
 endgenerate

endmodule

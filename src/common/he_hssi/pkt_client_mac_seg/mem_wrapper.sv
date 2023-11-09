// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


//
//
//
`default_nettype none
module mem_wrapper #(
    parameter DEVICE_FAMILY  = "Arria 10",
    parameter DW             = 8,
    parameter DEPTH          = 8, 
    parameter RAM_TYPE       = "AUTO",
    parameter OUTREG         = "ON",
     parameter SKIP_RDEN   	  = 0,
    parameter INIT_FILE_DATA = "init_file_data.hex"
)(
    input var  logic                     clk,
    input var  logic                     wren,
    input var  logic [DW-1:0]            wdata,
    input var  logic [$clog2(DEPTH)-1:0] waddr,

    input var  logic                     rden,
    input var  logic [$clog2(DEPTH)-1:0] raddr,
    output     logic [DW-1:0]            rdata,
    output     logic                     rdata_vld
);

nbq_scsdpram #(
    .DEVICE_FAMILY  (DEVICE_FAMILY),
    .SKIP_RDEN      (SKIP_RDEN),
    .LOG2_DEPTH     ($clog2(DEPTH)), 
    .WIDTH          (DW),
    .RAM_TYPE       (RAM_TYPE),
    .OUTREG         (OUTREG),
    .INIT_FILE      (INIT_FILE_DATA)
) mem (
  .clock        ( clk ),

  .data         ( wdata ),           // Write Data
  .wraddress    ( waddr ),
  .wren         ( wren ),

  .rdaddress    ( raddr ),
  .rden         ( rden ),
  .q            ( rdata )            // Read Data
);

always_ff @(posedge clk)   
     rdata_vld <= rden;
   
endmodule
`default_nettype wire

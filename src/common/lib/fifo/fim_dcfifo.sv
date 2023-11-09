// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT


//
// Taken from a Qsys-generated instance of a DCFIFO.
//


// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on

module fim_dcfifo
  #(
    parameter DATA_WIDTH               = 32,
    parameter DEPTH_RADIX              = 9,
    
    parameter ALMOST_FULL_THRESHOLD    = 16, // Minimum number of free slots before almost full is asserted
    parameter WRITE_ACLR_SYNC          = "OFF", // ON/OFF
    parameter READ_ACLR_SYNC           = "OFF",   // ON/OFF

    parameter OVERFLOW_CHECKING_PARAM  = "ON",    
    parameter UNDERFLOW_CHECKING_PARAM = "ON",
    parameter LPM_SHOWAHEAD_PARAM      = "OFF",

    parameter ADD_USEDW_MSB_BIT_PARAM  = "ON",
    parameter RDSYNC_DELAYPIPE_PARAM   = 5,
    parameter WRSYNC_DELAYPIPE_PARAM   = 5
    )
   (
    aclr,
    data,
    rdclk,
    rdreq,
    wrclk,
    wrreq,
    q,
    rdempty,
    rdfull,
    rdusedw,
    wrempty,
    wrfull,
    wralmfull,
    wrusedw);

   input                  aclr;
   input [DATA_WIDTH-1:0] data;
   input 		  rdclk;
   input 		  rdreq;
   input 		  wrclk;
   input 		  wrreq;
   output [DATA_WIDTH-1:0] q;
   output 		   rdempty;
   output 		   rdfull;
   output [DEPTH_RADIX-1:0] rdusedw;
   output 		    wrempty;
   output 		    wrfull;
   output 		    wralmfull;
   output [DEPTH_RADIX-1:0] wrusedw;
`ifndef ALTERA_RESERVED_QIS
   // synopsys translate_off
`endif
   tri0 		    aclr;
`ifndef ALTERA_RESERVED_QIS
   // synopsys translate_on
`endif
   
   wire [DATA_WIDTH-1:0]    sub_wire0;
   wire 		    sub_wire1;
   wire 		    sub_wire2;
   wire [DEPTH_RADIX-1:0]   sub_wire3;
   wire 		    sub_wire4;
   wire 		    sub_wire5;
   wire [DEPTH_RADIX-1:0]   sub_wire6;
   wire [DATA_WIDTH-1:0]    q = sub_wire0[DATA_WIDTH-1:0];
   wire 		    rdempty = sub_wire1;
   wire 		    rdfull = sub_wire2;
   wire [DEPTH_RADIX-1:0]   rdusedw = sub_wire3[DEPTH_RADIX-1:0];
   wire 		    wrempty = sub_wire4;
   wire 		    wrfull = sub_wire5;
   wire [DEPTH_RADIX-1:0]   wrusedw = sub_wire6[DEPTH_RADIX-1:0];

   dcfifo  dcfifo_component (
			     .aclr (aclr),
			     .data (data),
			     .rdclk (rdclk),
			     .rdreq (rdreq),
			     .wrclk (wrclk),
			     .wrreq (wrreq),
			     .q (sub_wire0),
			     .rdempty (sub_wire1),
			     .rdfull (sub_wire2),
			     .rdusedw (sub_wire3),
			     .wrempty (sub_wire4),
			     .wrfull (sub_wire5),
			     .wrusedw (sub_wire6),
			     .eccstatus ());

   defparam
     dcfifo_component.add_usedw_msb_bit  = ADD_USEDW_MSB_BIT_PARAM,
     dcfifo_component.enable_ecc         = "FALSE",
     dcfifo_component.lpm_hint           = "DISABLE_DCFIFO_EMBEDDED_TIMING_CONSTRAINT=TRUE",
     dcfifo_component.lpm_numwords       = 2**DEPTH_RADIX,  //debth of the FIFO always 2**lpm_widthu
     dcfifo_component.lpm_showahead      = LPM_SHOWAHEAD_PARAM,
     dcfifo_component.lpm_type           = "dcfifo",
     dcfifo_component.lpm_width          = DATA_WIDTH,      // width of the data port
     dcfifo_component.lpm_widthu         = DEPTH_RADIX,     // width of the wrusedw port
     dcfifo_component.overflow_checking  = OVERFLOW_CHECKING_PARAM,
     dcfifo_component.rdsync_delaypipe   = RDSYNC_DELAYPIPE_PARAM,
     dcfifo_component.read_aclr_synch    = READ_ACLR_SYNC,  // include the aclr port
     dcfifo_component.underflow_checking = UNDERFLOW_CHECKING_PARAM,
     dcfifo_component.use_eab            = "ON",            // use ram (not logic elements)
     dcfifo_component.write_aclr_synch   = WRITE_ACLR_SYNC, // include the aclr port
     dcfifo_component.wrsync_delaypipe   = WRSYNC_DELAYPIPE_PARAM;

   // The count of entries at which almost full is asserted.  Two extra free slots
   // are added to account for wrreq to wrusedw latency.
   localparam ALMOST_FULL_CNT = (2**DEPTH_RADIX) -
                                ALMOST_FULL_THRESHOLD - 2;

   logic sub_wralmfull;
   assign wralmfull = sub_wralmfull;

   always_ff @(posedge wrclk)
   begin
      sub_wralmfull <= (wrusedw >= DEPTH_RADIX'(ALMOST_FULL_CNT));
   end

endmodule

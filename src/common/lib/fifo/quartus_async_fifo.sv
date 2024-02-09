// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
//
// This is a parameterized version of the DCFIFO from Quartus. 
// RAM_STYLE = "AUTO"|"M20K"|"MLAB"


// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on

module  quartus_async_fifo #(parameter WIDTH=32, DEPTH=8, REG_OUT=1, RAM_STYLE="AUTO", ECC_EN=0)  
(
  aclr,
  fifo_din,
  rdclk,
  fifo_ren,
  wrclk,
  fifo_wen,
  fifo_dout,
  fifo_empty,
  fifo_full,
  fifo_eccstatus                     // FIFO EC Status 00: No error 
                                     //                01: Illegal
                                     //                10: A correctable error occurred and the error has been corrected at the outputs; however, the memory array has not been updated.
                                     //                11: An uncorrectable error occurred and uncorrectable data appears at the output
);

  input               aclr;
  input  [WIDTH-1:0]  fifo_din;
  input               rdclk;
  input               fifo_ren;
  input               wrclk;
  input               fifo_wen;
  output [WIDTH-1:0]  fifo_dout;
  output              fifo_empty;
  output              fifo_full;
  output [1:0]        fifo_eccstatus  ;// FIFO ECC Status


  `ifndef ALTERA_RESERVED_QIS
  // synopsys translate_off
  `endif
      tri0     aclr;
  `ifndef ALTERA_RESERVED_QIS
  // synopsys translate_on
  `endif

  localparam RAM_TYPE = (RAM_STYLE=="M20K") ? "RAM_BLOCK_TYPE=M20K" : 
                        (RAM_STYLE=="MLAB") ? "RAM_BLOCK_TYPE=MLAB" :
                                              "RAM_BLOCK_TYPE=AUTO" ;  

  wire [WIDTH-1:0] sub_wire0;
  wire             sub_wire1;
  wire             sub_wire2;
  wire [WIDTH-1:0] fifo_dout = sub_wire0[WIDTH-1:0];
  wire             fifo_empty = sub_wire1;
  wire             fifo_full = sub_wire2;

generate
  if(ECC_EN)
  begin
    dcfifo  dcfifo_component (
      .aclr (aclr),
      .data (fifo_din),
      .rdclk (rdclk),
      .rdreq (fifo_ren),
      .wrclk (wrclk),
      .wrreq (fifo_wen),
      .q (sub_wire0),
      .rdempty (sub_wire1),
      .wrfull (sub_wire2),
      .eccstatus (fifo_eccstatus),
      .rdfull (),
      .rdusedw (),
      .wrempty (),
      .wrusedw ());
    defparam
      dcfifo_component.add_ram_output_register  = (REG_OUT == 1) ? "ON" : "OFF",
      dcfifo_component.enable_ecc  = (ECC_EN==1) ? "TRUE" : "FALSE",
`ifdef DEVICE_FAMILY
      dcfifo_component.intended_device_family  = `DEVICE_FAMILY,
`else
      dcfifo_component.intended_device_family  = "Stratix 10",
`endif
      dcfifo_component.lpm_hint  = "DISABLE_DCFIFO_EMBEDDED_TIMING_CONSTRAINT=TRUE, RAM_TYPE",
      dcfifo_component.lpm_numwords  = 2**DEPTH,
      dcfifo_component.lpm_showahead  = "ON",
      dcfifo_component.lpm_type  = "dcfifo",
      dcfifo_component.lpm_width  = WIDTH,
      dcfifo_component.lpm_widthu  = DEPTH,
      dcfifo_component.overflow_checking  = "ON",
      dcfifo_component.rdsync_delaypipe  = 5,
      dcfifo_component.read_aclr_synch  = "ON",
      dcfifo_component.underflow_checking  = "ON",
      dcfifo_component.use_eab  = "ON",
      dcfifo_component.write_aclr_synch  = "ON",
      dcfifo_component.wrsync_delaypipe  = 5;
  end
  else
  begin
    dcfifo  dcfifo_component (
      .aclr (aclr),
      .data (fifo_din),
      .rdclk (rdclk),
      .rdreq (fifo_ren),
      .wrclk (wrclk),
      .wrreq (fifo_wen),
      .q (sub_wire0),
      .rdempty (sub_wire1),
      .wrfull (sub_wire2),
      .eccstatus (),
      .rdfull (),
      .rdusedw (),
      .wrempty (),
      .wrusedw ());
    defparam
      dcfifo_component.add_ram_output_register  = (REG_OUT == 1) ? "ON" : "OFF",
      dcfifo_component.enable_ecc  = (ECC_EN==1) ? "TRUE" : "FALSE",
      dcfifo_component.intended_device_family  = "Stratix 10",
      dcfifo_component.lpm_hint  = "DISABLE_DCFIFO_EMBEDDED_TIMING_CONSTRAINT=TRUE, RAM_TYPE",
      dcfifo_component.lpm_numwords  = 2**DEPTH,
      dcfifo_component.lpm_showahead  = "ON",
      dcfifo_component.lpm_type  = "dcfifo",
      dcfifo_component.lpm_width  = WIDTH,
      dcfifo_component.lpm_widthu  = DEPTH,
      dcfifo_component.overflow_checking  = "ON",
      dcfifo_component.rdsync_delaypipe  = 5,
      dcfifo_component.read_aclr_synch  = "ON",
      dcfifo_component.underflow_checking  = "ON",
      dcfifo_component.use_eab  = "ON",
      dcfifo_component.write_aclr_synch  = "ON",
      dcfifo_component.wrsync_delaypipe  = 5;
  end //if (ENN_EN)
endgenerate

endmodule


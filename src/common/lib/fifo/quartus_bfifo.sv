// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
//
// This is a parameterized version of the SCFIFO from Quartus. 
// RAM_STYLE = "AUTO"|"M20K"|"MLAB"

module quartus_bfifo  #(parameter WIDTH=80, DEPTH=6, FULL_THRESHOLD=56, EMPTY_THRESHOLD=0, REG_OUT=1, RAM_STYLE="AUTO", ECC_EN=0)   // synchronous bypass FIFO
(
  fifo_din                            ,// FIFO write data in
  fifo_wen                            ,// FIFO write enable
  fifo_ren                            ,// FIFO read enable
  clk                                 ,// clock
  Resetb                              ,// Reset active low
  fifo_dout                           ,// FIFO read data out (registered)
  fifo_count                          ,// FIFO number of valid entries
  full                                ,// 
  almost_full                         ,// FIFO count > FULL_THRESHOLD 
  not_empty                           ,// FIFO is not empty (registered)
  almost_empty                        ,// FIFO count < EMPTY_THRESHOLD
  fifo_err                            ,// FIFO overflow/underflow error
  fifo_eccstatus                       // FIFO EC Status 00: No error 
                                       //                01: Illegal
                                       //                10: A correctable error occurred and the error has been corrected at the outputs; however, the memory array has not been updated.
                                       //                11: An uncorrectable error occurred and uncorrectable data appears at the output.
);                                                                  
                                                                                        
  input  [WIDTH-1:0]  fifo_din        ;// FIFO write data in
  input               fifo_wen        ;// FIFO write enable
  input               fifo_ren        ;// FIFO read enable
  input               clk             ;// clock
  input               Resetb          ;// Reset active low
  output [WIDTH-1:0]  fifo_dout       ;// FIFO read data 
  output [DEPTH-1:0]  fifo_count      ;// FIFO count 
  output              full            ;// FIFO is almost full -- need to stall fifo_wen
  output              almost_full     ;// FIFO is almost full -- need to stall fifo_wen
  output              not_empty       ;// FIFO is not empty 
  output              almost_empty    ;// FIFO hit EMPTY THRESHOLD 
  output logic        fifo_err        ;// FIFO overflow/underflow error
  output [1:0]        fifo_eccstatus  ;// FIFO ECC Status
                                                                     
  logic               empty;

  localparam RAM_TYPE = (RAM_STYLE=="M20K") ? "RAM_BLOCK_TYPE=M20K" : 
                        (RAM_STYLE=="MLAB") ? "RAM_BLOCK_TYPE=MLAB" :
                                              "RAM_BLOCK_TYPE=AUTO" ;             

  assign not_empty = (EMPTY_THRESHOLD == 0) ? !empty : !almost_empty;


  always @ (posedge clk)
  begin
    if(!Resetb)
    begin
      fifo_err <= 0;
    end
    else
    begin
      unique case(1)
          ( fifo_ren & fifo_count==0                             )   : fifo_err <= 1'b1                      ;//
          ( fifo_wen & (!fifo_ren) & full                        )   : fifo_err <= 1'b1                      ;//
          default                                                    : fifo_err <= 0                         ;//
      endcase
    end
  end

  generate
    if(ECC_EN)
    begin
      scfifo  scfifo_component (
        .clock (clk),
        .data (fifo_din),
        .rdreq (fifo_ren),
        .wrreq (fifo_wen),
        .almost_empty (almost_empty),
        .almost_full (almost_full),
        .empty (empty),
        .full (full),
        .q (fifo_dout),
        .usedw (fifo_count),
        .aclr (1'b0),
        .eccstatus (fifo_eccstatus),
  		.sclr (!Resetb));
      defparam
          scfifo_component.add_ram_output_register  = (REG_OUT == 1) ? "ON" : "OFF",
          scfifo_component.almost_empty_value  = EMPTY_THRESHOLD,
          scfifo_component.almost_full_value  = FULL_THRESHOLD,
          scfifo_component.enable_ecc  = "TRUE",
`ifdef DEVICE_FAMILY
          scfifo_component.intended_device_family  = `DEVICE_FAMILY,
`else
          scfifo_component.intended_device_family  = "Stratix 10",
`endif
          scfifo_component.lpm_hint  = RAM_TYPE,
          scfifo_component.lpm_numwords  = 2**DEPTH,
          scfifo_component.lpm_showahead  = "ON",
          scfifo_component.lpm_type  = "scfifo",
          scfifo_component.lpm_width  = WIDTH,
          scfifo_component.lpm_widthu  = DEPTH,
          scfifo_component.overflow_checking  = "ON",
          scfifo_component.underflow_checking  = "ON",
          scfifo_component.use_eab  = "ON";
  
    end
    else //(ECC_EN == 0)
    begin
        scfifo  scfifo_component (
          .clock (clk),
          .data (fifo_din),
          .rdreq (fifo_ren),
          .wrreq (fifo_wen),
          .almost_empty (almost_empty),
          .almost_full (almost_full),
          .empty (empty),
          .full (full),
          .q (fifo_dout),
          .usedw (fifo_count),
          .aclr (1'b0),
          .eccstatus (),
  		  .sclr (!Resetb));
        defparam
          scfifo_component.add_ram_output_register  = (REG_OUT == 1) ? "ON" : "OFF",
          scfifo_component.almost_empty_value  = EMPTY_THRESHOLD,
          scfifo_component.almost_full_value  = FULL_THRESHOLD,
          scfifo_component.enable_ecc  = "FALSE",
`ifdef DEVICE_FAMILY
          scfifo_component.intended_device_family  = `DEVICE_FAMILY,
`else
          scfifo_component.intended_device_family  = "Stratix 10",
`endif
          scfifo_component.lpm_hint  = RAM_TYPE,
          scfifo_component.lpm_numwords  = 2**DEPTH,
          scfifo_component.lpm_showahead  = "ON",
          scfifo_component.lpm_type  = "scfifo",
          scfifo_component.lpm_width  = WIDTH,
          scfifo_component.lpm_widthu  = DEPTH,
          scfifo_component.overflow_checking  = "ON",
          scfifo_component.underflow_checking  = "ON",
          scfifo_component.use_eab  = "ON";
    end //if(ECC_EN)
  endgenerate
					 
endmodule 

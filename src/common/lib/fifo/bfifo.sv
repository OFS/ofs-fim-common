// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
//
// Module Name: bfifo
// Project:     QPI, UPI
// Description: see below
//
// ***************************************************************************
//                  Synchronous Bypss FIFO
//****************************************************************************
//
// This FIFO is designed to have synchrounous/registered outputs (fifo_dout, not_empty)
// and to have quick data output.  The fifo_dout becomes valid one clock after fifo_wen.
// 
// 1.  bypass path is used to bypass fifo_ram which takes 2 clocks to read out data
// 2.  bypass has two entries acting as fast 2-entry fifo: fifo_dout and fifo_din_q
// 3.  fifo_cntr tracks # of unread fifo entries.  Based on fifo_cntr, the logic determines if bypss path is taken
// 4.  fifo_r_ptr reads 1 entry ahead, this is needed since inc fifo_r_ptr on fifo_ren is too slow.
// 5.  fifo_ram output for fifo_r_ptr+1 asserted two clocks earlier becomes available when fifo_cntr > 2
// 6.  logic descriptions:
//
// To address large RAM Tco in M20K, REG_OUT=0 provides the option of registering at the ram output,
// M20K ram supports only unconditonal registering of ram outputs; therefore bfifo conditional select 
// is done combinationally after the ram out registers; this will incur timing penalty to the 
// subsequent data path.  User should evaluate timing implications and decide the option for REG_OUT:
// 
// REG_OUT = 0 : Use M20K embedded output registers, then combinational select for fifo data out.
// REG_OUT = 1 : Use registers outside of M20K with conditional select before fifo data out registers.
// 
//--------------------------------------------------------------------------------------------------------------------------------------------
//                      fifo_wen        fifo_ren        comment
//--------------------------------------------------------------------------------------------------------------------------------------------
//  fifo_cntr == 0          0           0               no change
//                          0           1               illegal.  read empty fifo
//                          1           0               forward din to dout.                        next fifo_cntr <= 1;
//                          1           1               forward din to dout.                        next fifo_cntr <= 0;
//--------------------------------------------------------------------------------------------------------------------------------------------
//  fifo_cntr == 1          0           0               hold fifo_dout                              next fifo_cntr <= 1;
//                          0           1               fifo_dout is read.                          next fifo_cntr <= 0;
//                          1           0               hold fifo_dout                              next fifo_cntr <= 2;
//                          1           1               forward din to dout.                        next fifo_cntr <= 1;
//--------------------------------------------------------------------------------------------------------------------------------------------
//  fifo_cntr == 2          0           0               hold fifo_dout, fifo_din_q                  next fifo_cntr <= 2;
//                          0           1               fifo_dout <= fifo_din_q                     next fifo_cntr <= 1;
//                          1           0               forward din to dout.                        next fifo_cntr <= 3;
//                          1           1        fifo_dout <= fifo_din_q; fifo_din_q <= fifo_din    next fifo_cntr <= 2;
//--------------------------------------------------------------------------------------------------------------------------------------------
//  fifo_cntr  > 2          0           0               hold fifo_dout, fifo_din_q                  next fifo_cntr <= no change;                                   
//                          0           1               fifo_dout <= fifo_ram_out                   next_fifo_cntr <= fifo_cntr - 1;
//                          1           0        fifo_dout <= no change; fifo_din_q <= fifo_din     next fifo_cntr <= fifo_cntr + 1;
//                          1           1     fifo_dout <= fifo_ram_out; fifo_din_q <= fifo_din     next fifo_cntr <= on change;
//--------------------------------------------------------------------------------------------------------------------------------------------
//   EXAMPLE
//
//
// () - value used for fifo_dout (registered)
//
//------------------------------------------------------------------------------------------------------------------------------------------
//             clk0    clk1    clk2    clk3    clk4    clk5    clk6    clk7    clk8    clk9    clk10   clk11   clk12   clk13   clk14   clk15
//-------------------------------------------------------------------------------------------------------------------------------------------
// fifo_din    (D0)     X      (D1)     D2      X       D3      D4      X       D5      X       D6      X       X       X       X       X       
// fifo_wen     1       0       1       1       0       1       1       0       1       0       1       0       0       0       0       0
// fifo_din_q   X       D0      D0      D1     (D2)     D2      D3      D4      D4      D5      D5      D6      D6    (D6)     D6      D6
// fifo_w_ptr   0       1       1       2       3       3       4       5       5       6       6       7       7       7       7       7
// fifo_r_ptr   1       2       2       2       3       3       3       4       4       4       4       5       6       7       8       8      
// ram_out      X       X       X       X       D2      X       D3     (D3)     D4      D4      D4     (D4)    (D5)    D6       X      D8
// fifo_cntr    0       1       0       1       2       1       2       3       2       3       3       4       3       2       1       0
// fifo_ren     0       1       0       0       1       0       0       1       0       0       0       1       1       1       1       0        
// fifo_dout    X      (D0)     D0     (D1)     D1     (D2)    (D2)     D2     (D3)    (D3)    (D3)     D3      D4      D5     (D6)   (D6)
//------------------------------------------------------------------------------------------------------------------------------------------
// select      din     hold    din     hold    din_q   hold    hold     out    hold    hold    hold    out     out     din_q   hold    hold
//
// 
`include "fpga_defines.vh"
`include "vendor_defines.vh"
//import kti_pkg::*;

module  bfifo  #(parameter 
                     WIDTH=80                                                  ,// FIFO Width
                     DEPTH=6                                                   ,// FIFO Deptn = 2**DEPTH
                     FULL_THRESHOLD=56                                         ,// FIFO full threshold/watermark value
                     REG_IN=0                                                  ,// Add FIFO input registers for timing
                     REG_OUT=1                                                 ,// 1- register at the FIFO outputs. 0- register at ram outputs
                     GRAM_STYLE=`GRAM_AUTO                                     ,// Use M20K block ram or Logic for fifo ram
                     BITS_PER_PARITY =32                                        // parity bit per number of data bits
                     )                                                          //
                    (                                                           //
                    fifo_din                                                   ,// FIFO write data in
                    fifo_wen                                                   ,// FIFO write enable
                    fifo_ren                                                   ,// FIFO read enable
                    clk                                                        ,// clock
                    Resetb                                                     ,// Reset active low
                                                                                //
                    fifo_out                                                   ,// FIFO read data out (unregistered)
                    fifo_dout                                                  ,// FIFO read data out (registered)
                    fifo_count                                                 ,// FIFO number of valid entries
                    full                                                       ,// FIFO count > FULL_THRESHOLD
                    not_empty_out                                              ,// FIFO is not empty (unregistered)
                    not_empty                                                  ,// FIFO is not empty (registered)
                    not_empty_dup                                              ,// FIFO is not empty (registered)
                    fifo_err                                                   ,// FIFO overflow/underflow error
                    fifo_perr                                                   // FIFO pairity error
                    );                                                          //
                                                                                //
input  [WIDTH-1:0]  fifo_din                                                   ;// FIFO write data in
input               fifo_wen                                                   ;// FIFO write enable
input               fifo_ren                                                   ;// FIFO read enable
input               clk                                                        ;// clock
input               Resetb                                                     ;// Reset active low
                                                                                //
output [WIDTH-1:0]  fifo_out                                                   ;
output [WIDTH-1:0]  fifo_dout                                                  ;
output [DEPTH  :0]  fifo_count                                                 ; 
output              full                                                       ;// FIFO is almost full -- need to stall fifo_wen
output              not_empty_out                                              ;// FIFO is not empty (unregistered)
output              not_empty                                                  ;// FIFO is not empty (registered)
output [1:0]        not_empty_dup                                              ;// FIFO is not empty (registered)
output              fifo_err                                                   ;// FIFO overflow/underflow error
output              fifo_perr                                                  ;//
                                                                                //
reg  [WIDTH-1:0]    fifo_out                                                   ;//
reg  [WIDTH-1:0]    out_q                                                      ;//
reg  [WIDTH-1:0]    ram_out_q                                                  ;//
reg  [WIDTH-1:0]    fifo_dout                                                  ;//
reg  [WIDTH-1:0]    fifo_out_q                                                 ;//
reg  [WIDTH-1:0]    fifo_din_q                                                 ;//
reg  [WIDTH-1:0]    fifo_in_q                                                  ;//
reg  [WIDTH-1:0]    fifo_in                                                    ;//
reg  [DEPTH-1:0]    fifo_r_ptr = 'd1 /* synthesis preserve  */                 ;//
reg  [DEPTH-1:0]    fifo_w_ptr = 'd0 /* synthesis preserve  */                 ;//
reg  [DEPTH  :0]    fifo_cntr  = 'b0 /* synthesis preserve  */                 ;//
reg  [DEPTH  :0]    fifo_cntr_d                                                ;//
reg                 fifo_lt_4                                                  ;//
reg                 fifo_gt_2                                                  ;//
reg                 fifo_lt_2                                                  ;//
reg                 fifo_w                                                     ;//
reg                 fifo_w_q  = 'b0  /* synthesis preserve */                  ;//
reg                 fifo_dout_sel                                              ;//
reg                 not_empty_out                                              ;//
reg                 full                                                       ;//
reg                 fifo_err                                                   ;//
reg                 perr_en                                                    ;//
reg                 perr_en_q                                                  ;// Delayed version of perr_en
(* dont_merge *) reg [5:0] valid                                               ;//
                                                                                //
assign              not_empty = valid[0]                                       ;//
assign              not_empty_dup = valid[5:4]                                 ;//
wire                perr                                                       ;//
wire                fifo_perr = perr & perr_en_q & DEPTH>1                     ;//
wire [WIDTH-1:0]    ram_out                                                    ;//
reg  [DEPTH-1:0]    next_r_ptr                                                 ;//
                                                                                //
assign fifo_count = fifo_cntr                                                  ;// for debug/simulation
                                                                                //
always @(*)                                                                     //
    begin                                                                       //
       if (REG_IN)                                                              //
           begin                                                                //
               fifo_in = fifo_din_q                                            ;//
               fifo_w  = fifo_w_q                                              ;//
           end                                                                  //
       else                                                                     //
           begin                                                                //
               fifo_in = fifo_din                                              ;//
               fifo_w  = fifo_wen                                              ;//
           end                                                                  //
                                                                                //
        if (REG_OUT)                                                            // registered fifo_dout
           begin                                                                //
                                            fifo_dout = fifo_out_q             ;//
           end                                                                  //
        else                                                                    //
           begin                                                                // 2:1 muxed fifo_dout
               if (fifo_dout_sel)           fifo_dout = ram_out_q              ;// registered ram dout
               else                         fifo_dout = out_q                  ;// registered bypass out
           end                                                                  //
                                                                                //
       if  (fifo_ren) next_r_ptr = fifo_r_ptr + 1'b1                           ;//
       else           next_r_ptr = fifo_r_ptr                                  ;//
                                                                                //
       unique case(1)                                                           //
           ( fifo_ren &  fifo_gt_2 &  DEPTH>1   ): fifo_out = ram_out          ;// fifo_cntr > 2:  fifo_out = ram[next_r_ptr]
           ( fifo_ren & !fifo_gt_2 & !fifo_lt_2 ): fifo_out = fifo_in_q        ;// fifo_cntr ==2:  fifo_out = fifo_in_q
           ( fifo_ren &  fifo_lt_2 | !valid[1]  ): fifo_out = fifo_in          ;// fifo_cntr < 2:  if (fifo_w) fifo_dout <= fifo_in
             default                             : fifo_out = fifo_dout        ;// 
       endcase                                                                  //
                                                                                //
       unique case(1)                                                           //
           (fifo_lt_2 & !fifo_w & fifo_ren      ): not_empty_out = 0           ;//
           (!valid[3] &  fifo_w                 ): not_empty_out = 1'b1        ;// 
             default                             : not_empty_out = valid[3]    ;//
       endcase                                                                  //
                                                                                //
       unique case(1)                                                           //
           ( fifo_w & !fifo_ren): fifo_cntr_d = fifo_cntr + 1'b1               ;//
           (!fifo_w &  fifo_ren): fifo_cntr_d = fifo_cntr - 1'b1               ;//
            default             : fifo_cntr_d = fifo_cntr                      ;//
       endcase                                                                  //
    end                                                                         //
                                                                                //
always @(posedge clk)                                                           //
    begin                                                                       //
        fifo_din_q    <= fifo_din                                              ;//
        fifo_w_q      <= fifo_wen                                              ;//
        perr_en_q     <= perr_en                                               ;// delayed version of perr_en to align to perr output from ram_1r1w
        perr_en       <= fifo_gt_2  & fifo_ren                                 ;//
        fifo_dout_sel <= fifo_gt_2  & fifo_ren                                 ;//
        fifo_out_q    <= fifo_out                                              ;// for REG_OUT1=:  register at FIFO outputs
                                                                                //
        if ( DEPTH>1  )  ram_out_q  <= ram_out                                 ;//
        if ( fifo_w   )  fifo_in_q  <= fifo_in                                 ;// store valid fifo_din  
                                                                                //
        unique case(1)                                                          // for REG_OUT=0:  register at ram outputs then select
           ( fifo_ren &  fifo_lt_2 | !valid[1]  ): out_q <= fifo_in            ;// fifo_cntr < 2:  if (fifo_w) fifo_dout <= fifo_in
           ( fifo_ren & !fifo_gt_2 & !fifo_lt_2 ): out_q <= fifo_in_q          ;// fifo_cntr ==2:  fifo_out = fifo_in_q
             default                             : out_q <= fifo_dout          ;// 
        endcase                                                                 //
    end                                                                         //
                                                                                //
always @(posedge clk)                                                           //
if (!Resetb)                                                                    //
begin                                                                           //
    fifo_err    <= 0;                                                           //
    fifo_cntr   <= 0;                                                           //
    fifo_r_ptr  <= 1;                                                           //
    fifo_w_ptr  <= 0;                                                           //
    valid       <= 0;                                                           //
    fifo_lt_4   <= 1;                                                           //
    fifo_lt_2   <= 1;                                                           //
    fifo_gt_2   <= 0;                                                           //
    full        <= 0;                                                           //
end                                                                             //
else                                                                            //
begin                                                                           //
    unique case(1)                                                              //
        ( fifo_ren & !valid[3]          )   : fifo_err <= 1'b1                 ;//
        ( fifo_w   & fifo_cntr==2**DEPTH)   : fifo_err <= 1'b1                 ;//
        default                             : fifo_err <= 0                    ;//
    endcase                                                                     //
                                                                                //
    unique case(1)                                                              //
        ( fifo_w & !fifo_ren)   : fifo_cntr <= fifo_cntr + 1'b1                ;//
        (!fifo_w &  fifo_ren)   : fifo_cntr <= fifo_cntr - 1'b1                ;//
          default                            :                                 ;//
    endcase                                                                     //
                                                                                //
    if ( fifo_ren )  fifo_r_ptr <= fifo_r_ptr + 1'b1                           ;// inc fifo read pointer read if read and fifo is not empty
    if ( fifo_w   )  fifo_w_ptr <= fifo_w_ptr + 1'b1                           ;// inc fifo write ponter if write and fifo is not empty
                                                                                //
    unique case(1)                                                              //
        (!fifo_w   & fifo_ren    & fifo_lt_2 ): valid <= 6'b0                  ;//
        ( fifo_w   & !valid[0]               ): valid <= 6'b111111             ;//
        default                             :                                  ;//
    endcase                                                                     //
                                                                                //
    if (fifo_lt_4)                                                              // replaces fifo_lt_2 and fifo_gt_2 for timing
    unique case (fifo_cntr[1:0])                                                //
        2'b00   :                                                              ;//
        2'b01   : if ( fifo_w & !fifo_ren) fifo_lt_2 <= 0                      ;//
        2'b10   : begin                                                         //
                      if (!fifo_w &  fifo_ren) fifo_lt_2 <= 1'b1               ;//
                      if ( fifo_w & !fifo_ren) fifo_gt_2 <= 1'b1               ;//
                  end                                                           // 
        2'b11   : if (!fifo_w &  fifo_ren) fifo_gt_2 <= 0                      ;//
        default :                                                              ;//
    endcase                                                                     //
                                                                                //
    fifo_lt_4 <= fifo_cntr_d< 4                                                ;//
    full      <= fifo_cntr_d>=FULL_THRESHOLD                                   ;// fifo count reached full threshold
end

ram_1r1w  #(.DEPTH(DEPTH),.WIDTH(WIDTH),.GRAM_MODE(1),.GRAM_STYLE(GRAM_STYLE), .BITS_PER_PARITY(BITS_PER_PARITY)) fifo_ram 
               (
                .din        (fifo_in    ) ,// input   write data with configurable width
                .waddr      (fifo_w_ptr ) ,// input   write address with configurable width
                .we         (fifo_w     ) ,// input   write enable
                .raddr      (next_r_ptr ) ,// input   read address with configurable width
                .re         (fifo_ren   ) ,// input   read enable
                .clk        (clk        ) ,// input   clock

                .dout       (ram_out    ) ,// output  parity error
                .perr       (perr       )  // output  write data with configurable width
                );           
endmodule 

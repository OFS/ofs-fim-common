// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
//
// Module Name: bfifo
// Project:     QPI, UPI
// Description: see below
//
// ***************************************************************************//
// qfifo functions as a 2-read 2-write port FIFO, capable of writing and reading two entries in one clock.
// It is implemenmted using two quad_fifo.v (see descriptions in quad_fifo.v) -- one for even etnry and the 
// other for odd.  The even and odd allows look ahead of two addresses (one each for even and odd), 
// therefore allows read out of two entries in consective clocks. (unlike quad_fifo, which can only read 
// out one entry in consective clocks).
//
//  even/odd write logic
//
//  ----------------------------------------------------------------------------------------
//     w_odd_even    wen0      wen1            even_wen    even_din     odd_wen     odd_din
//  ----------------------------------------------------------------------------------------
//         0          0         0                 x          x            0           x
//         0          0         1                 1         din1          0           x       
//         0          1         0                 1         din0          0           x
//         0          1         1                 1         din0          1         din1
//         1          0         0                 0         x             0           x
//         1          0         1                 0         x             1         din1
//         1          1         0                 0         x             1         din0
//         1          1         1                 1         din1          1         din0
//
//
//
//      r_ptr[0]    ren0        ren1        raddr[0]    odd_ren     even_ren
//         0          0           0               0           0           0 
//         0          0           1               1           1           0
//         0          1           0               1           0           1
//         0          1           1               0           1           1
//         1          0           0               1           0           0
//         1          0           1               0           0           1
//         1          1           0               0           1           0
//         1          1           1               1           1           1
//                        
//      odd_ren  =    r_ptr[0] & ren0 | !r_ptr[0] & ren1  = r_ptr[0]? ren0 : ren1
//      even_ren =   !r_ptr[0] & ren0 |  r_ptr[0] & ren1  = r_ptr[0]? ren1 : ren0
//                        
`include "fpga_defines.vh"
`include "vendor_defines.vh"
//import kti_pkg::*;

module qfifo #(parameter WIDTH=50, DEPTH=6, FULL_THRESHOLD=56, REG_IN=0, REG_OUT=1, GRAM_STYLE=`GRAM_AUTO, BITS_PER_PARITY=32)
                        (
                        din0           ,// [WIDTH-1:0] data in port 0
                        wen0           ,//             write enable port 0
                        ren0           ,//             read enable port 0
                        din1           ,// [WIDTH-1:0] data in port 1
                        wen1           ,//             write enable port 1
                        ren1           ,//             read enable port 1
                        resetb         ,//             resetb (active low)
                        clk            ,//             1x clock
                         
                        out0           ,// [WIDTH-1:0] read data output prot0 (comb out)
                        out1           ,// [WIDTH-1:0] read data output port1 (comb out)
                        dout0          ,// [WIDTH-1:0] read data output prot0 (reg out)
                        dout1          ,// [WIDTH-1:0] read data output port 1 (reg out)
                        fifo_count     ,// [DEPTH-1:0] number of valid fifo entries
                        not_empty0     ,//             even fifo not empty         
                        not_empty0_dup ,//             even fifo not empty         
                        not_empty1     ,//             odd fifo not empty
                        not_empty1_dup ,//             odd fifo not empty
                        full           ,//             fifo_cntr > FULL_THRESHOLD
                        fifo_err       ,//             fifo overflow/underflow error
                        fifo_perr       //             fifo pairity error
                        );

input   [WIDTH-1:0]     din0           ;// [WIDTH-1:0] data in port 0
input                   wen0           ;//             write enable port 0
input                   ren0           ;//             read enable port 0
input   [WIDTH-1:0]     din1           ;// [WIDTH-1:0] data in port 1
input                   wen1           ;//             write enable port 1
input                   ren1           ;//             read enable port 1
input                   resetb         ;//             resetb (active low)
input                   clk            ;//             1x clock
                         
output  [WIDTH-1:0]     out0           ;// [WIDTH-1:0] read data output prot0 (comb out)
output  [WIDTH-1:0]     out1           ;// [WIDTH-1:0] read data output port1 (comb out)
output  [WIDTH-1:0]     dout0          ;// [WIDTH-1:0] read data output prot0 (reg out)
output  [WIDTH-1:0]     dout1          ;// [WIDTH-1:0] read data output port1 (reg out)
output  [DEPTH  :0]     fifo_count     ;// [DEPTH-1:0] number of valid fifo entries
output                  not_empty0     ;//             even fifo not empty
output  [1:0]           not_empty0_dup ;//             even fifo not empty
output                  not_empty1     ;//             odd fifo not empty
output  [1:0]           not_empty1_dup ;//             odd fifo not empty
output                  full           ;//             fifo_cntr > FULL_THRESHOLD
output                  fifo_err       ;//             fifo overflow/underflow error
output                  fifo_perr      ;//             fifo pairity error
   
reg     [1:0]           wen_q      = '0 /* synthesis preserve dont_replicate dont_retime */ ;// write enable port 0
reg     [1:0]           ren_q      = '0 /* synthesis preserve dont_replicate dont_retime */ ;// read enable port 0
reg     [1:0]           w_odd_even = '0 /* synthesis preserve dont_replicate dont_retime */ ;// replicate w_odd_even for fanout
reg     [DEPTH-1:0]     fifo_w_ptr = '0 /* synthesis preserve dont_replicate dont_retime */ ;
reg     [DEPTH-1:0]     fifo_r_ptr = '0 /* synthesis preserve dont_replicate dont_retime */ ;
reg     [DEPTH  :0]     fifo_cntr  = '0 /* synthesis preserve dont_replicate dont_retime */ ;
reg                     full           ;// fifo entries > threshold 
reg                     valid0         ;// entry0 is valid
reg                     valid1         ;// entry 1 is valid
reg                     fifo_err       ;// fifo access error
reg     [3:0]           raddr0_q       ;// read address bit 0
reg                     not_empty0     ;// entry0 is valid
reg     [1:0]           not_empty0_dup ;// entry0 is valid
reg                     not_empty1     ;// entry1 is valid
reg     [1:0]           not_empty1_dup ;// entry1 is valid
reg     [WIDTH-1:0]     out0_q         ;//
reg     [WIDTH-1:0]     out1_q         ;//
reg     [WIDTH-1:0]     out0           ;//
reg     [WIDTH-1:0]     out1           ;//
reg     [WIDTH-1:0]     dout0          ;//
reg     [WIDTH-1:0]     dout1          ;//
reg     [WIDTH-1:0]     even_din       ;// 
reg                     even_wen       ;// 
reg     [WIDTH-1:0]     odd_din        ;// 
reg                     odd_wen        ;// 
reg     [WIDTH-1:0]     even_in_q      ;// 
reg                     even_w_q       ;// 
reg     [WIDTH-1:0]     odd_in_q       ;// 
reg                     odd_w_q        ;// 

wire    [WIDTH-1:0]     odd_out        ;//  odd fifo data comb out
wire    [WIDTH-1:0]     odd_dout       ;//  odd fifo data reg out
wire    [WIDTH-1:0]     even_out       ;// even fifo data comb out
wire    [WIDTH-1:0]     even_dout      ;// even fifo data reg out
wire                    even_full      ;// even entries > threshold  
wire                    odd_full       ;//  odd entries > threshold   
wire                    even_not_empty ;// even fifo is not empty  
wire                    odd_not_empty  ;// odd fifo is not empty  
wire                    odd_valid      ;// odd fifo has valid entries
wire                    even_valid     ;// even fifl has valid entries 
wire                    even_fifo_err  ;// even fifo access error
wire                    odd_fifo_err   ;// odd fifo access error
wire                    even_fifo_perr ;// even fifo parity error
wire                    odd_fifo_perr  ;// odd fifo parity error

wire    [DEPTH-1:0]     waddr      = fifo_w_ptr                                 ;// next write address
wire          [3:0]     raddr0     ={4{fifo_r_ptr[0]  ^ ren0  ^ ren1}}          ;// next read address bit0                                                                                         //
wire                    even_ren   = fifo_r_ptr[0]  ? ren1  : ren0              ;// even fifo data read enable
wire                    odd_ren    = fifo_r_ptr[0]  ? ren0  : ren1              ;//  odd fifo data read eanble
wire                    fifo_perr  = even_fifo_perr | odd_fifo_perr             ;// fifo ram parity error

assign fifo_count = fifo_cntr;

always @(*)
begin
    if (REG_OUT)                                                                 // registered outputs
        begin                                                                    //
            out0       = raddr0[0] ?  odd_out     : even_out                    ;// entry0 data out
            out1       = raddr0[1] ? even_out     :  odd_out                    ;// entry1 data out
            dout0      = out0_q                                                 ;// entry0 data out
            dout1      = out1_q                                                 ;// entry1 data out
            not_empty0 = valid0                                                 ;// entry0 is valid
            not_empty0_dup = {2{valid0}}                                        ;// entry0 is valid
            not_empty1 = valid1                                                 ;// entry1 is valid
            not_empty1_dup = {2{valid1}}                                        ;// entry1 is valid
        end                                                                      //
    else                                                                         // unregistered outputs
        begin                                                                    //
            out1       = raddr0_q[0] ?       even_out:        odd_out           ;// entry1 data out
            out0       = raddr0_q[1] ?        odd_out:       even_out           ;// entry0 data out
            dout0      = raddr0_q[2] ?       odd_dout:      even_dout           ;// entry0 data out
            dout1      = raddr0_q[3] ?      even_dout:       odd_dout           ;// entry1 data out
            not_empty0 = raddr0_q[0] ?  odd_not_empty: even_not_empty           ;// entry0 is valid
            not_empty0_dup = raddr0_q[0] ? {2{odd_not_empty}}: {2{even_not_empty}};// entry0 is valid
            not_empty1 = raddr0_q[1] ? even_not_empty:  odd_not_empty           ;// entry1 is valid
            not_empty1_dup = raddr0_q[1] ? {2{even_not_empty}}: {2{odd_not_empty}};// entry1 is valid
        end                                                                      //
        
    if (REG_IN)
        begin
            even_din   = even_in_q                                              ;// even fifo data in       
            even_wen   = even_w_q                                               ;// even fifo data write enable
            odd_din    = odd_in_q                                               ;//  odd fifo data in        
            odd_wen    = odd_w_q                                                ;//  odd fifo data write enable
        end                                                                     
    else                                                                        
        begin                                                                   
            even_din   =(!w_odd_even[0] & wen0) ? din0        : din1            ;// even fifo data in       
            even_wen   =  w_odd_even[0]         ? wen0 & wen1 : wen0 | wen1     ;// even fifo data write enable
            odd_din    = (w_odd_even[1] & wen0) ? din0        : din1            ;//  odd fifo data in        
            odd_wen    =  w_odd_even[1]         ? wen0 | wen1 : wen0 & wen1     ;//  odd fifo data write enable
        end
end

always @(posedge clk)

begin
            even_in_q  <=(!w_odd_even[0] & wen0) ? din0        : din1            ;// even fifo data in       
            even_w_q   <=  w_odd_even[0]         ? wen0 & wen1 : wen0 | wen1     ;// even fifo data write enable
            odd_in_q   <= (w_odd_even[1] & wen0) ? din0        : din1            ;//  odd fifo data in        
            odd_w_q    <=  w_odd_even[1]         ? wen0 | wen1 : wen0 & wen1     ;//  odd fifo data write enable

            wen_q     <= wen0 + wen1   ;
            ren_q     <= ren0 + ren1   ;
            
            raddr0_q   <={4{raddr0[0]}}   ;                        

            valid0     <=     raddr0[2] ? odd_valid    : even_valid     ;
            valid1     <=     raddr0[3] ? even_valid   :  odd_valid     ;
            out0_q     <=     raddr0[2] ?  odd_out     : even_out       ;
            out1_q     <=     raddr0[3] ? even_out     :  odd_out       ;
            
            if (!resetb)
            begin
                w_odd_even <= 0;
                fifo_r_ptr <= 0;
                fifo_w_ptr <= 0;
                fifo_cntr  <= 0;
                full       <= 0; 
                fifo_err   <= 0;
            end
            else
            begin
                if (wen0 | wen1) w_odd_even <= {2{(wen0 ^ wen1) & !waddr[0]
                                                 |(wen0 & wen1) &  waddr[0] }};
                unique case(1)                                                             
                    (ren0 & ren1): fifo_r_ptr[DEPTH-1:1] <= fifo_r_ptr[DEPTH-1:1] + 1'b1;
                    (ren0 ^ ren1): fifo_r_ptr[DEPTH-1:0] <= fifo_r_ptr[DEPTH-1:0] + 1'b1;
                     default     :                                                      ;
                endcase

                unique case(1)                                                             
                    (wen0 & wen1): fifo_w_ptr[DEPTH-1:1] <= fifo_w_ptr[DEPTH-1:1] + 1'b1;
                    (wen0 ^ wen1): fifo_w_ptr[DEPTH-1:0] <= fifo_w_ptr[DEPTH-1:0] + 1'b1;
                     default     :                                                      ;
                endcase

                fifo_cntr  <=  fifo_cntr   + wen_q        - ren_q          ;
                full       <=  fifo_cntr  >= FULL_THRESHOLD                ;
                fifo_err   <=  fifo_cntr  >= 2**DEPTH
                            |  fifo_cntr  <  0 ;
            end
end

`ifdef INCLUDE_UPI_HA
always @(posedge clk) 
begin  

  /*synthesis translate_off */
  if (resetb)
  begin

    if ( (ren0) && (^dout0)  === 1'bx )
    begin $display("*** WARNING: FIFO returned Xs on output port0 *** \n Module Name: %m"); #10000; $finish (); end

    if ( (ren1) && (^dout1)  === 1'bx )
    begin $display("*** WARNING: FIFO returned Xs on output port1 *** \n Module Name: %m"); #10000; $finish (); end

  end
  /*synthesis translate_on */
  
end
`endif // INCLUDE_UPI_HA
       
// `ifdef  S10_SYNTHESIS // use qaud port fifo
// 
//    
//         eofifo #(.WIDTH          (    WIDTH        )  , 
//                  .DEPTH          (    DEPTH        )  , 
//                  .FULL_THRESHOLD ( FULL_THRESHOLD  )  , 
//                  .REG_OUT        (   REG_OUT       )  , 
//                  .GRAM_STYLE     (  GRAM_STYLE     )  , 
//                  .BITS_PER_PARITY( BITS_PER_PARITY )  )
//         eofifo (                                       
//                  .e_fifo_din     (  even_din       )  ,// even FIFO write data in
//                  .e_fifo_wen     (  even_wen       )  ,// even FIFO write enable
//                  .e_fifo_ren     (  even_ren       )  ,// even FIFO read enable
//                  .o_fifo_din     (   odd_din       )  ,// odd  FIFO write data in
//                  .o_fifo_wen     (   odd_wen       )  ,// odd  FIFO write enable
//                  .o_fifo_ren     (   odd_ren       )  ,// odd  FIFO read enable
//                  .clk            (   clk           )  ,// clock
//                  .resetb         (   resetb        )  ,// Reset active low
//                                                       
//                  .e_fifo_out     (  even_out       )  ,// even FIFO read data out (unregistered)
//                  .e_fifo_dout    (  even_dout      )  ,// even FIFO read data out (registered)
//                  .e_full         (  even_full      )  ,// even FIFO is almost e_full -- need to stall e_fifo_wen
//                  .e_valid_out    (  even_valid     )  ,// even FIFO is not empty (unregistered)
//                  .e_valid        (  even_not_empty )  ,// even FIFO is not empty (registered)
//                  .e_fifo_err     (  even_fifo_err  )  ,// even FIFO overflow/underflow error
//                  .e_fifo_perr    (  even_fifo_perr )  ,// even FIFO parity
//                  .o_fifo_out     (   odd_out       )  ,// odd  FIFO read data out (unregistered)
//                  .o_fifo_dout    (   odd_dout      )  ,// odd  FIFO read data out (registered)
//                  .o_full         (   odd_full      )  ,// odd  FIFO is almost e_full -- need to stall e_fifo_wen
//                  .o_valid_out    (   odd_valid     )  ,// odd  FIFO is not empty (unregistered)
//                  .o_valid        (   odd_not_empty )  ,// odd  FIFO is not empty (registered)
//                  .o_fifo_err     (   odd_fifo_err  )  ,// odd  FIFO overflow/underflow error
//                  .o_fifo_perr    (   odd_fifo_perr )   // odd  FIFO parity
//                ); 
//                
//`else // Use 2 bfifo
//
            bfifo #(
                   .WIDTH          (WIDTH           )  ,
                   .DEPTH          (DEPTH-1         )  ,
                   .FULL_THRESHOLD (FULL_THRESHOLD/2)  , 
                   .GRAM_STYLE     (GRAM_STYLE      )  , 
                   .REG_OUT        (REG_OUT         )  ,
                   .BITS_PER_PARITY(BITS_PER_PARITY )  )  
           even_que
                  (
                   .fifo_din       (even_din        )  ,// FIFO write data in
                   .fifo_wen       (even_wen        )  ,// FIFO write enable
                   .fifo_ren       (even_ren        )  ,// FIFO read enable
                   .clk            (clk             )  ,// clock
                   .Resetb         (resetb          )  ,// Reset active low
                                                        //--------------------- Output  ------------------
                   .fifo_out       (even_out        )  ,// FIFO read data out
                   .fifo_dout      (even_dout       )  ,// FIFO read data out
                   .fifo_count     (                )  ,// FIFO read data out
                   .full           (even_full       )  ,// FIFO count > FULL_THRESHOLD
                   .not_empty_out  (even_valid      )  ,// FIFO is not empty
                   .not_empty      (even_not_empty  )  ,// FIFO is not empty
                   .not_empty_dup  (                )  ,// FIFO is not empty
                   .fifo_err       (even_fifo_err   )  ,//
                   .fifo_perr      (even_fifo_perr  )   //
                   )                                   ;//
           bfifo #(
                   .WIDTH          (WIDTH           )  ,
                   .DEPTH          (DEPTH-1         )  ,
                   .FULL_THRESHOLD (FULL_THRESHOLD/2)  , 
                   .GRAM_STYLE     (GRAM_STYLE      )  , 
                   .REG_OUT        (REG_OUT         )  ,
                   .BITS_PER_PARITY(BITS_PER_PARITY ))  
           odd_que
                  (
                   .fifo_din       ( odd_din        )  ,// FIFO write data in
                   .fifo_wen       ( odd_wen        )  ,// FIFO write enable
                   .fifo_ren       ( odd_ren        )  ,// FIFO read enable
                   .clk            ( clk            )  ,// clock
                   .Resetb         ( resetb         )  ,// Reset active low
                                                        //--------------------- Output  ------------------
                   .fifo_out       ( odd_out        )  ,// FIFO read data out
                   .fifo_dout      ( odd_dout       )  ,// FIFO read data out
                   .fifo_count     (                )  ,// FIFO read data out
                   .full           ( odd_full       )  ,// FIFO count > FULL_THRESHOLD
                   .not_empty_out  ( odd_valid      )  ,// FIFO is not empty
                   .not_empty      ( odd_not_empty  )  ,// FIFO is not empty
                   .not_empty_dup  (                )  ,// FIFO is not empty
                   .fifo_err       ( odd_fifo_err   )  ,//
                   .fifo_perr      ( odd_fifo_perr  )   //
                   )                                   ;// 

//`endif

endmodule



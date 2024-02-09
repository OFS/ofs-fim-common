// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// Ready/valid pipeline register
//-----------------------------------------------------------------------------

`timescale 1 ps / 1 ps
module chan_reg
#( 
    parameter MODE   = 0, // 0 = skid buffer, 1 = bubble, 2 = bypass
    
    // Width of datapath
    parameter DATA_W = 8
)(
    input  logic              clk,
    input  logic              rst_n,

    output logic              tx_ready,
    input  logic              tx_valid,
    input  logic [DATA_W-1:0] tx_data,

    input  logic              rx_ready,
    output logic              rx_valid,
    output logic [DATA_W-1:0] rx_data
);
generate
if (MODE == 0) begin 
   // Skid buffer
   logic                      buf_valid;
   logic [DATA_W-1:0] 	      buf_data;
   logic                      rx_idle;
   logic 		      use_buf;

   assign rx_idle  = (rx_ready  || ~rx_valid);
   
   always_ff @(posedge clk) begin
      if (~rst_n) begin
         tx_ready  <=  1'b0;
      end else begin
         tx_ready  <=  rx_idle;
      end
   end

   always_ff @(posedge clk) begin
      if (~rst_n) begin
         use_buf <= 1'b1;
      end else if (rx_idle) begin
         use_buf <= 1'b0;
      end else if (~rx_idle && tx_ready) begin
         use_buf <= 1'b1;
      end
   end
    
   // Buffer registers    
   always_ff @(posedge clk) begin
      if (~rst_n) begin
         buf_valid  <= 1'b0;
      end else begin
         if (tx_ready) 
            buf_valid <= tx_valid;            
      end
   end

   always @(posedge clk) begin
      if (tx_ready) begin
         buf_data <= tx_data;
      end
   end
   
   // Generate ready and valid signals
   always @(posedge clk) begin
      if (~rst_n) begin
         rx_valid <= 1'b0;
      end else if (rx_idle) begin
         rx_valid <= (use_buf) ? buf_valid : tx_valid;
      end
   end
   
   always @(posedge clk) begin
      if (rx_idle) begin
         rx_data <= (use_buf) ? buf_data : tx_data;
      end
   end
end else if (MODE == 1) begin 
   // bubble pipeline
   always @(posedge clk) begin
      if (~rst_n) begin
         tx_ready <= 1'b0;
         rx_valid <= 1'b0;
      end else begin
        if (tx_ready && tx_valid) begin
           tx_ready <= 1'b0;
           rx_valid <= 1'b1;
        end else if (~tx_ready && (rx_ready || ~rx_valid)) begin
           tx_ready <= 1'b1;
           rx_valid <= 1'b0;
        end
      end
   end

   always @(posedge clk) begin
      if (tx_ready) begin
         rx_data <= tx_data;
      end
   end
end else begin 
    // Bypass
    assign tx_ready   =  rx_ready;
    assign rx_valid   =  tx_valid;
    assign rx_data    =  tx_data;
end
endgenerate



endmodule

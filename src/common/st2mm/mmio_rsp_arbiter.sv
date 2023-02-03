// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//    *  Arbitrates multiple incoming responses on i_rsp port to single
//       response output o_rsp using stages of fair arbiters. 
//
//       Incoming responses are divided into groups of 4, each group 
//       of 4 responses drive a 4-way fair arbiter in first stage of the arbiter
//       pipeline (stage 0). The output of the arbiter is registered.
//       The arbiters on stage 0 are further divided into groups of 4, and the 
//       output of the arbiters in each group drives a 4-way fair arbiter in 
//       the next stage of the arbiter pipeline. 
//
//       The division continues until there is only one 4-way fair arbiter 
//       in a stage, i.e. final stage of the pipeline.
//
//       The depth of the pipeline stage is determined by the number of 
//       incoming responses. 
//        e.g. 12 responses results in 2 stage pipelines, with 3 arbiters
//             in stage 0 (first stage) and 1 arbiter in stage 2 (final stage),
//             as shown below.
//       
//
//                    (STAGE 0)                                   (STAGE 1)
//
//                    arb[0][0]   
//                    ---------   
//                   |         | 
//      i_rsp[3:0]-->| Arbiter |<-- *[0] 
//    o_ready[3:0]<--|         |  
//                    ---------   
//
//                    arb[0][1]                                    arb[1][0]
//                    ---------                                    ---------          
//                   |         |                                  |         |
//      i_rsp[7:4]-->| Arbiter |<-- *[1]           arb[0][2:0] -->| Arbiter |--> o_rsp
//    o_ready[7:4]<--|         |            *arb_ready[1][2:0] <--|         |<-- i_ready
//                    ---------                                    ---------
//
//                    arb[0][2]
//                    ---------
//                   |         |
//     i_rsp[11:8]-->| Arbiter |<-- *[2] 
//   o_ready[11:8]<--|         |
//                    ---------
//
//
//   *  Each arbiter has 1 ready input and 1-4 ready outputs (1 for each of
//      the response inputs). The ready input is the backpressure signal from
//      the arbiter in the next pipeline or the i_ready input signal if the 
//      arbiter is in the final pipeline stage.
//
//      The ready outputs are used to backpressure the arbiters in previous pipeline
//      stage or the source of the incoming responses if the arbiter is in the first
//      pipeline stage (o_ready).
//
//      Each ready output is registered to facilitate timing.
//      Since the source will only see the ready 1 cycle later, the source's input to 
//      the arbiter is ignored when the ready output is high, introducing 1 bubble cycle
//      between two consecutive responses from the same source.
//
//-----------------------------------------------------------------------------

import st2mm_pkg::*;

module mmio_rsp_arbiter #(   
   parameter NUM_RSP = 4 // Maximum 32 responses are supported
)(
   input  logic clk,
   input  logic rst_n,

   input  st2mm_pkg::t_axi_mmio_r [NUM_RSP-1:0] i_rsp,
   output logic [NUM_RSP-1:0]                   o_ready,

   output st2mm_pkg::t_axi_mmio_r               o_rsp,
   input  logic                                 i_ready
);

localparam NUM_RSP_GROUP = (NUM_RSP/4)*4 < NUM_RSP ? (NUM_RSP/4)+1 : (NUM_RSP/4);
localparam MAX_RSP = NUM_RSP_GROUP*4;
localparam LOG2_MAX_RSP = $clog2(MAX_RSP);

// Calculate total number of arbiter pipeline stage based on input response count
function automatic integer calc_arb_stage (
  input integer rsp_count
);
   integer stage = 1;
   integer cnt = (rsp_count/4)*4 < rsp_count ? (rsp_count/4)+1 : (rsp_count/4);

   while (cnt > 1) begin
      stage = stage + 1;
      cnt = (cnt/4)*4 < cnt ? (cnt/4)+1 : (cnt/4);
   end  
   return stage;
endfunction
localparam integer ARB_STAGE = calc_arb_stage(MAX_RSP);

// Calculate the total number of 4-way fair arbiters in each arbiter stage
function automatic bit [ARB_STAGE-1:0][LOG2_MAX_RSP-1:0] calc_arb_count (
  input integer rsp_count
);
   integer cnt = rsp_count;

   for (int i=0; i<ARB_STAGE; i=i+1) begin
      cnt = ( (cnt/4)*4 < cnt) ? (cnt/4)+1 : (cnt/4);
      calc_arb_count[i]  = cnt;
   end
endfunction
localparam bit [ARB_STAGE-1:0][LOG2_MAX_RSP-1:0] NUM_ARB = calc_arb_count(MAX_RSP);

// arbiter input 
typedef logic [MAX_RSP-1:0][3:0] t_arb_in_vec;
// arbiter output select 
typedef logic [MAX_RSP-1:0][1:0] t_arb_sel_vec;
// response vector
typedef st2mm_pkg::t_axi_mmio_r [MAX_RSP-1:0] t_mmio_rsp_vec;

// Allocate maximum registers per stage, unused registers will be synthesized away
t_mmio_rsp_vec [ARB_STAGE-1:0] arb_rsp_in; // arbiter response inputs
t_mmio_rsp_vec [ARB_STAGE-1:0] arb_rsp_comb; // arbiter response outputs (comb)
t_mmio_rsp_vec [ARB_STAGE-1:0] arb_rsp_out; // arbiter response outputs (registered)
logic [ARB_STAGE-1:0][MAX_RSP-1:0] arb_ready_out    ; // arbiter ready output (registered)

t_arb_in_vec  [ARB_STAGE-1:0]              int_rsp_valid    ; // response valid inputs to arbiter 
logic         [ARB_STAGE-1:0][MAX_RSP-1:0] int_arb_ready; // arbiter backpressure input
logic         [ARB_STAGE-1:0][MAX_RSP-1:0] int_hold_arb; // arbiter hold signal
t_arb_in_vec  [ARB_STAGE-1:0]              int_arb_sel_1hot; // arbiter 1-hot input select output
t_arb_sel_vec [ARB_STAGE-1:0]              int_arb_sel; // arbiter input select output
logic         [ARB_STAGE-1:0][MAX_RSP-1:0] int_arb_valid; // arbiter selection valid output 

//--------------------
// Output assignments
//--------------------
// backpressure signals from the first stage arbiters back to the source
assign o_ready = arb_ready_out[0][NUM_RSP-1:0];
// Response output from last stage arbiter 
assign o_rsp   = arb_rsp_out[ARB_STAGE-1][0];

//--------------------
// Arbiter inputs
//--------------------
// Input responses to arbiters 
always_comb begin
   for (int i=0; i<ARB_STAGE; i=i+1) begin
      if (i == 0) begin
         arb_rsp_in[i] = '0;
         arb_rsp_in[i] = i_rsp;
      end else begin
         arb_rsp_in[i] = '0;
         for (int j=0; j<NUM_ARB[i-1]; j=j+1) begin
            arb_rsp_in[i][j] = arb_rsp_out[i-1][j];
         end
      end
   end
end

// Response valid inputs to arbiters 
always_comb begin
   for (int i=0; i<ARB_STAGE; i=i+1) begin
      for (int j=0; j<NUM_ARB[i]; j=j+1) begin
         for (int k=0; k<4; k=k+1) begin
            int_rsp_valid[i][j][k] = arb_rsp_in[i][j*4+k].rvalid && ~arb_ready_out[i][j*4+k];
         end
      end
   end
end

//------------------------------
// Arbiter backpressure signals
//------------------------------
// Connect arbiter ready input to the driver in next arbiter stage
// The ready input of last stage arbiter is connected directly to the i_ready input
always_comb begin
   for (int i=0; i<ARB_STAGE; i=i+1) begin 
      if (i == ARB_STAGE-1) begin
         int_arb_ready[i][0] = i_ready;
      end else begin
         for (int j=0; j<NUM_ARB[i]; j=j+1) begin
            int_arb_ready[i][j] = arb_ready_out[i+1][j];
         end
      end
   end
end

// Assert int_hold_arb (hold arbiter response) when the next stage logic is not ready to 
// consume the response from the arbiter 
// i.e. there is a pending response in the arbiter output register 
//      and the arbiter ready input is de-asserted (backpressure from next stage logic)
always_comb begin
   for (int i=0; i<ARB_STAGE; i=i+1) begin
      for (int j=0; j<NUM_ARB[i]; j=j+1) begin
         int_hold_arb[i][j] = (arb_rsp_out[i][j].rvalid && ~int_arb_ready[i][j]);
      end
   end
end

// Arbiter ready output
always_ff @(posedge clk) begin
   for (int i=0; i<ARB_STAGE; i=i+1) begin
      for (int j=0; j<NUM_ARB[i]; j=j+1) begin
         for (int k=0; k<4; k=k+1) begin
            if (~rst_n) begin
               arb_ready_out[i][j*4+k] <= 1'b0;
            end else begin
               // k-th ready output of the arbiter
               arb_ready_out[i][j*4+k] <= (int_arb_valid[i][j] // arbiter output is valid 
                                             && int_arb_sel_1hot[i][j][k] // k-th response input is selected
                                             && ~int_hold_arb[i][j]); // arbiter is not backpressured
            end
         end
      end
   end
end

//------------------------------
// Arbiter response output 
//------------------------------
// Assign the selected input response to the arbiter output 
always_comb begin
   for (int i=0; i<ARB_STAGE; i=i+1) begin
      for (int j=0; j<NUM_ARB[i]; j=j+1) begin
         case (int_arb_sel[i][j]) 
            2'd0 : begin 
               arb_rsp_comb[i][j] = arb_rsp_in[i][j*4];
               arb_rsp_comb[i][j].rvalid = arb_rsp_in[i][j*4].rvalid && int_arb_valid[i][j];
            end
            2'd1 : begin 
               arb_rsp_comb[i][j] = arb_rsp_in[i][j*4+1];
               arb_rsp_comb[i][j].rvalid = arb_rsp_in[i][j*4+1].rvalid && int_arb_valid[i][j];
            end
            2'd2 : begin 
               arb_rsp_comb[i][j] = arb_rsp_in[i][j*4+2];
               arb_rsp_comb[i][j].rvalid = arb_rsp_in[i][j*4+2].rvalid && int_arb_valid[i][j];
            end
            2'd3 : begin 
               arb_rsp_comb[i][j] = arb_rsp_in[i][j*4+3];
               arb_rsp_comb[i][j].rvalid = arb_rsp_in[i][j*4+3].rvalid && int_arb_valid[i][j];
            end
         endcase
      end
   end
end

// Register arbiter response output
always_ff @(posedge clk) begin
   for (int i=0; i<ARB_STAGE; i=i+1) begin
      for (int j=0; j<NUM_ARB[i]; j=j+1) begin
         // Register new response from the arbiter when the arbiter is not being backpressured
         // or when there is no pending response in the output register
         if (~int_hold_arb[i][j]) begin
            arb_rsp_out[i][j] <= arb_rsp_comb[i][j];
         end

         if (~rst_n) begin
            arb_rsp_out[i][j].rvalid <= 1'b0;
         end
      end
   end
end

//-------------------------------
// 4-way fair arbiter instances
//-------------------------------
generate 
genvar i, j;
  for (i=0; i<ARB_STAGE; i=i+1) begin : arb_stage
     for (j=0; j<NUM_ARB[i]; j=j+1) begin : arb
        fair_arbiter #(
           .NUM_INPUTS  (4),
           .LNUM_INPUTS (2)
        )
        fair_arbiter
        (
           .clk             (clk),
           .reset_n         (rst_n),
           .in_valid        (int_rsp_valid[i][j]),
           .hold_priority   ({4{~int_hold_arb[i][j]}}),
           .out_select      (int_arb_sel[i][j]),
           .out_select_1hot (int_arb_sel_1hot[i][j]),
           .out_valid       (int_arb_valid[i][j])
        );
     end
  end
endgenerate

endmodule
	


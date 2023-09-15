// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description 
//----------------------------------------------------------------------------
//
// Module name : fim_rdack_scfifo
//
//
//   If the FIFO is not empty, data is automatically read from the FIFO 
//   when there is no valid data on the output ports or when a rdack is received
//   for the valid data currently presented on the output ports.
//  
//   rvalid is asserted one cycle after a read from the FIFO, indicating valid
//   data is available at the output ports.
//   Data read from the FIFO is hold valid until a rdack is received.
//   rdack should be asserted on the same clock cycle when data is consumed.
//   This is different from a typical FIFO where the FIFO pops out a new data
//   in response to rdreq input in the previous clock cycle.
//  
//   The FIFO can not overflow, write is inhibited internally when the FIFO is full.
//   Similary, the FIFO can not underflow, read is inhibited internally when the FIFO 
//   is empty.
//
//----------------------------------------------------------------------------

module fim_rdack_scfifo #(
   parameter DATA_WIDTH = 32,

   // DEPTH_LOG2 sets the number of entries in the FIFO (2 ** DEPTH_LOG2)
   // as well as the width of usedw counters.
   parameter DEPTH_LOG2 = 5,
   
   // Type of storage. "OFF" uses LUTs. "ON" uses RAM blocks (embedded
   // array blocks).
   parameter USE_EAB = "OFF",

   // Number of busy entries at which w_ready will go low.
   // Defaults to half full.
   parameter ALMOST_FULL_THRESHOLD = 2 ** (DEPTH_LOG2 - 1)
)(
   input  logic clk,
   input  logic sclr,
   
   input  logic [DATA_WIDTH-1:0] wdata,
   input  logic wreq,
   input  logic rdack,
   
   output logic [DATA_WIDTH-1:0] rdata,
   output logic [DEPTH_LOG2-1:0] wusedw,
   output logic [DEPTH_LOG2-1:0] rusedw,
   output logic wfull,
   output logic almfull,
   output logic rempty,
   // rvalid is set when rdata is valid. See discussion above the module.
   output logic rvalid
);

logic fifo_rvalid;
logic fifo_empty;
logic fifo_full;

logic fifo_wreq;
logic fifo_rdreq;
logic wready;
logic [DATA_WIDTH-1:0] fifo_dout, fifo_dout_q;

/////////////////////////////////////////////////////////////////////////////////////

// FIFO almost full
assign almfull = ~wready;
// FIFO empty
assign rempty  = fifo_empty;
// FIFO full
assign wfull   = fifo_full;

// Select final data to be assigned to rdata output based on ADD_OUTPUT_REGISTER setting
assign rdata = fifo_rvalid ? fifo_dout : fifo_dout_q;

// FIFO write request
assign fifo_wreq = wreq & ~fifo_full;

// FIFO read request
assign fifo_rdreq = (~rvalid | rdack) && ~fifo_empty;

// Valid signal assignment 
always_ff @(posedge clk) begin
   if (sclr) begin
      rvalid <= 1'b0;
   end else begin
      if (fifo_rdreq) begin
         rvalid <= 1'b1;
      end else if (~rvalid || rdack) begin
         rvalid <= 1'b0;
      end
   end
end

// Register FIFO output
always_ff @(posedge clk) begin
   fifo_dout_q <= fifo_dout;
end

// SCFIFO
fim_scfifo #(
   .DATA_WIDTH(DATA_WIDTH),
   .DEPTH_LOG2(DEPTH_LOG2),
   .USE_EAB(USE_EAB),
   .ALMOST_FULL_THRESHOLD(ALMOST_FULL_THRESHOLD),
   .ADD_RAM_OUTPUT_REGISTER("OFF")
) sfifo (
   .clk     (clk),
   .sclr    (sclr),
   .w_data  (wdata),
   .w_req   (fifo_wreq),
   .r_req   (fifo_rdreq),
   .r_data  (fifo_dout),
   .w_full  (fifo_full),
   .w_usedw (wusedw),
   .r_usedw (rusedw),
   .w_ready (wready), 
   .r_empty (fifo_empty),
   .r_valid (fifo_rvalid)
);

endmodule // fim_rdack_scfifo

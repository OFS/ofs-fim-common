// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description 
//----------------------------------------------------------------------------
//
// Module name : fim_rdack_dcfifo
//
// If the FIFO is not empty, data is automatically read from the FIFO 
// when there is no valid data on the output ports or when a rdack is received
// for the valid data currently presented on the output ports.
//
// rvalid is asserted one cycle after a read from the FIFO, indicating valid
// data is available at the output ports.
// Data read from the FIFO is hold valid until a rdack is received.
// rdack should be asserted on the same clock cycle when data is consumed.
// This is different from a typical FIFO where the FIFO pops out a new data
// in response to rdreq input in the previous clock cycle.
//
// The FIFO can not overflow, write is inhibited internally when the FIFO is full.
// Similary, the FIFO can not underflow, read is inhibited internally when the FIFO 
// is empty.
//
//----------------------------------------------------------------------------

module fim_rdack_dcfifo #(
   parameter DATA_WIDTH = 32,
   
   // DEPTH_LOG2 sets the number of entries in the FIFO (2 ** DEPTH_LOG2)
   // as well as the width of usedw counters.
   parameter DEPTH_LOG2 = 5,

   // Number of busy entries at which w_ready will go low.
   // Defaults to half full.
   parameter ALMOST_FULL_THRESHOLD = 2 ** (DEPTH_LOG2 - 1),
   parameter WRITE_ACLR_SYNC = "OFF", // ON/OFF
   parameter READ_ACLR_SYNC = "OFF"   // ON/OFF
)(
   input  logic wclk,
   input  logic rclk,
   input  logic aclr,
   
   input  logic [DATA_WIDTH-1:0] wdata,
   input  logic wreq,
   input  logic rdack,
   
   output logic [DATA_WIDTH-1:0] rdata,
   output logic [DEPTH_LOG2-1:0] wusedw,
   output logic [DEPTH_LOG2-1:0] rusedw,
   output logic wfull,
   output logic wempty,
   output logic almfull,
   output logic rempty,
   output logic rfull,
   // rvalid is set when rdata is valid. See discussion above the module.
   output logic rvalid
);

logic rclk_rst_n;

logic fifo_rvalid;
logic fifo_empty;
logic fifo_full;

logic fifo_wreq;
logic fifo_rdreq;
logic [DATA_WIDTH-1:0] fifo_dout, fifo_dout_q;

/////////////////////////////////////////////////////////////////////////////////////

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

// Valid signal assignment based on LOW_LATENCY mode
always_ff @(posedge rclk) begin
   if (~rclk_rst_n) begin
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
always_ff @(posedge rclk) begin
   fifo_dout_q <= fifo_dout;
end

// DC FIFO
fim_dcfifo #(
   .DATA_WIDTH            (DATA_WIDTH),
   .DEPTH_RADIX           (DEPTH_LOG2),
   .ALMOST_FULL_THRESHOLD (ALMOST_FULL_THRESHOLD),
   .WRITE_ACLR_SYNC       (WRITE_ACLR_SYNC),
   .READ_ACLR_SYNC        (READ_ACLR_SYNC)
) dcfifo (
   .aclr      (aclr),
   .data      (wdata), 
   .rdclk     (rclk),
   .rdreq     (fifo_rdreq),
   .wrclk     (wclk),
   .wrreq     (fifo_wreq),
   .q         (fifo_dout),
   .rdempty   (fifo_empty),
   .rdfull    (rfull),
   .rdusedw   (rusedw),
   .wrempty   (wempty),
   .wrfull    (fifo_full),
   .wralmfull (almfull),
   .wrusedw   (wusedw)
);

always_ff @(posedge rclk) begin
   if (~rclk_rst_n)
      fifo_rvalid <= 1'b0;
   else
      fifo_rvalid <= fifo_rdreq;
end

// Reset synchronizer (read clock domain)
fim_resync #(
   .SYNC_CHAIN_LENGTH(3),
   .WIDTH(1),
   .INIT_VALUE(0),
   .NO_CUT(1)
) rst_rclk_resync (
   .clk   (rclk),
   .reset (aclr),
   .d     (1'b1),
   .q     (rclk_rst_n)
);

endmodule // fim_rdack_dcfifo

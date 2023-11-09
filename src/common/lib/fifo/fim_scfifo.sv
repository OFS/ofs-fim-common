// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// fim_scfifo implements the same interface as a Platform Designer
// fifo2 but exports the depth, width and memory type as parameters.
//
// Unlike the Platform Designer version, the FIFO here guarantees that
// r_data is available and r_valid is set the cycle immediately following
// r_req.
//
// The FIFO can not underflow. r_req is inhibited internally when r_empty
// is true. In theory, you could tie r_req high and just monitor the
// r_valid output. r_valid is true whenever r_data has valid data leaving
// the FIFO.
//
//-----------------------------------------------------------------------------

module fim_scfifo #(
  parameter DATA_WIDTH = 32,

  // DEPTH_LOG2 sets the number of entries in the FIFO (2 ** DEPTH_LOG2)
  // as well as the width of usedw counters.
  parameter DEPTH_LOG2 = 5,

  // Type of storage. "OFF" uses LUTs. "ON" uses RAM blocks (embedded
  // array blocks).
  parameter USE_EAB = "OFF",

  // Type of storage. "OFF" uses LUTs. "ON" uses RAM blocks (embedded
  // array blocks).
  parameter SHOWAHEAD = "OFF",

  // Number of busy entries at which w_ready will go low.
  // Defaults to half full.
  parameter ALMOST_FULL_THRESHOLD = 2 ** (DEPTH_LOG2 - 1),

  // Register the output (ON or OFF)?
  parameter ADD_RAM_OUTPUT_REGISTER = "OFF"
)
(
  input  logic clk,
  input  logic sclr,

  input  logic [DATA_WIDTH-1:0] w_data,
  input  logic w_req,
  input  logic r_req,

  // Data is valid the cycle following a r_req
  output logic [DATA_WIDTH-1:0] r_data,
  output logic [DEPTH_LOG2-1:0] w_usedw,
  output logic [DEPTH_LOG2-1:0] r_usedw,
  output logic w_full,
  output logic w_ready,
  output logic r_empty,
  // r_valid is set when r_data is valid. See discussion above the module.
  output logic r_valid
);

  localparam N_ENTRIES = 2 ** DEPTH_LOG2;

  logic almost_full;
  assign w_ready = ~almost_full;

  assign r_usedw = w_usedw;

  // Only enable r_req when the FIFO isn't empty.
  logic r_req_en;
  assign r_req_en = r_req & ~r_empty;

  always_ff @(posedge clk) begin
    if (sclr) begin
       r_valid <= 1'b0;
    end
    else begin
       r_valid <= r_req_en;
    end
  end

  scfifo #(
`ifdef FAMILY
    .intended_device_family(`FAMILY),
`endif
    .lpm_numwords(N_ENTRIES),
    .lpm_showahead(SHOWAHEAD),
    .lpm_type("scfifo"),
    .lpm_width(DATA_WIDTH),
    .lpm_widthu(DEPTH_LOG2),
    .almost_full_value(ALMOST_FULL_THRESHOLD),
    .overflow_checking("OFF"),
    .underflow_checking("OFF"),
    .use_eab(USE_EAB),
    .add_ram_output_register(ADD_RAM_OUTPUT_REGISTER)
  )
  scfifo_inst (
    .clock(clk),
    .sclr(sclr),

    .data(w_data),
    .wrreq(w_req),
    .full(w_full),
    .almost_full(almost_full),
    .usedw(w_usedw),

    .rdreq(r_req_en),
    .q(r_data),
    .empty(r_empty),
    .almost_empty(),

    .aclr(),
    .eccstatus()
  );

endmodule // fim_scfifo

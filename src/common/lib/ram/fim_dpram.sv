// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// fim_dpram implements a simple dual port RAM using the altera_syncram megafunction
//
// This module also handles read-during-write behavior with a bypass register with
// approprate read latency
//
//-----------------------------------------------------------------------------

module fim_dpram #(
  parameter DATA_WIDTH = 32,

  // DEPTH_LOG2 sets the number of entries in the RAM (2 ** DEPTH_LOG2)
  parameter DEPTH_LOG2 = 5,

  // Specifies RAM block type. Values are family dependent. Besides "AUTO" supported values are:
  // "LUTRAM", "MLAB", "M10K", "M20K"
  parameter RAM_STYLE = "AUTO",

  // Register the output (ON or OFF)?
  parameter ADD_RAM_OUTPUT_REGISTER = "OFF"
)
(
  input  logic clk,

  input  logic w_req,
  input  logic [DEPTH_LOG2-1:0] w_address,
  input  logic [DATA_WIDTH-1:0] w_data,

  input  logic r_req,
  // always read since reads are non-destructive
  input  logic [DEPTH_LOG2-1:0] r_address,
  // Data is valid the cycle following a r_req w/o output register
  output logic [DATA_WIDTH-1:0] r_data,
  output logic                  r_valid
);

   localparam N_ENTRIES = 2 ** DEPTH_LOG2;
   localparam BYTEEN_WIDTH = DATA_WIDTH/8;
   localparam OUTPUT_REGISTER = (ADD_RAM_OUTPUT_REGISTER == "OFF") ? "UNREGISTERED" : "CLOCK0";

   logic r_req_q;
   
   logic byp, byp_q;
   logic [DATA_WIDTH-1:0] byp_data, byp_data_q;
   
   logic [DATA_WIDTH-1:0] ram_r_data;
   
   always_ff @ (posedge clk) begin
      // byp <= (w_req) & (w_address == r_address);
      byp <= (w_req & r_req) & (w_address == r_address);
      byp_data <= w_data;
   end

   always_ff @ (posedge clk) begin
      r_req_q <= r_req;
   end
   
   
   generate 
   if(ADD_RAM_OUTPUT_REGISTER == "OFF") begin
      assign byp_q      = byp;
      assign byp_data_q = byp_data;
      assign r_valid    = r_req_q;
   end else begin
      always_ff @ (posedge clk) begin
	 byp_q      <= byp;
	 byp_data_q <= byp_data;
	 r_valid    <= r_req_q;
      end
   end
   endgenerate
   
   assign r_data = (byp_q) ? byp_data_q : ram_r_data;

   altera_syncram #(
`ifdef DEVICE_FAMILY
      .intended_device_family(`FAMILY),
`endif
      .lpm_type       ("altera_syncram"),
      .operation_mode ("DUAL_PORT"),
      .ram_block_type (RAM_STYLE),

      .byte_size  (8),
      .numwords_a (N_ENTRIES),
      .numwords_b (N_ENTRIES),
      .width_a    (DATA_WIDTH),
      .width_b    (DATA_WIDTH),
      .widthad_a  (DEPTH_LOG2),
      .widthad_b  (DEPTH_LOG2),
      .width_byteena_a (DATA_WIDTH/8),

      .address_reg_b ("CLOCK0"),
      .rdcontrol_reg_b ("CLOCK0"),
      .outdata_reg_b (OUTPUT_REGISTER),

      .clock_enable_input_a  ("BYPASS"),
      .clock_enable_output_a ("BYPASS"),
      .clock_enable_input_b  ("BYPASS"),
      .clock_enable_output_b ("BYPASS"),
      // read during write behavior is handled by a bypass register
      .read_during_write_mode_mixed_ports ("DONT_CARE")
   )
   syncram_inst (
      .address_a (w_address),
      .address_b (r_address),
      .clock0    (clk),
      .data_a    (w_data),
      .wren_a    (w_req),
      .q_b       (ram_r_data),
      .aclr0 (1'b0),
      .aclr1 (1'b0),
      .address2_a (1'b1),
      .address2_b (1'b1),
      .addressstall_a (1'b0),
      .addressstall_b (1'b0),
      .byteena_a ({BYTEEN_WIDTH{1'b1}}),
      .byteena_b ({BYTEEN_WIDTH{1'b1}}),
      .clock1 (1'b1),
      .clocken0 (1'b1),
      .clocken1 (1'b1),
      .clocken2 (1'b1),
      .clocken3 (1'b1),
      .data_b ({2{1'b1}}),
      .eccencbypass (1'b0),
      .eccencparity (8'b0),
      .eccstatus (),
      .q_a (),
      .rden_a (1'b1),
      // .rden_b (1'b1),
      .rden_b (r_req),
      .sclr (1'b0),
      .wren_b (1'b0)
   );
endmodule // fim_dpram

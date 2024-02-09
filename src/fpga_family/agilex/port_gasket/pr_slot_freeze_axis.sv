// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT


import pcie_ss_axis_pkg::*;

module  pr_slot_freeze_axis #(
   parameter DIR = ""
)(
   input                       clk,
   input                       rst_n,
   input                       pr_freeze,

   pcie_ss_axis_if.source      axis_src_if,
   pcie_ss_axis_if.sink        axis_snk_if,

   output                      port_rst_n
);

//pipeline reset input
logic rst_n_local;
localparam RESET_PIPE_DEPTH = 2;
logic [RESET_PIPE_DEPTH-1:0] rst_n_pipe;
always_ff @(posedge clk) begin
   {rst_n_local,rst_n_pipe}  <= {rst_n_pipe[RESET_PIPE_DEPTH-1:0], '1};
   if (!rst_n) begin
      rst_n_local <= '0;
      rst_n_pipe  <= '0;
   end
end

logic pr_freeze_local;
localparam FREEZE_PIPE_DEPTH = 1;
logic [FREEZE_PIPE_DEPTH-1:0] pr_freeze_pipe;
always_ff @(posedge clk) begin
   {pr_freeze_local,pr_freeze_pipe}  <= {pr_freeze_pipe[FREEZE_PIPE_DEPTH-1:0], '0};
   if (pr_freeze) begin
      pr_freeze_local <= '1;
      pr_freeze_pipe  <= '1;
   end
end

pcie_ss_axis_if axis_reg ();

//AXI-S register/pipeline
st_if_reg #(
   .PCK_WIDTH  ($bits({axis_src_if.tlast,
                        axis_src_if.tuser_vendor,
                        axis_src_if.tdata,
                        axis_src_if.tkeep}))
) st_if_reg_inst (
   .clk,
   .i_reset_n      (rst_n_local),
   .o_reset_n      (port_rst_n),
   .i_m0_valid     (axis_snk_if.tvalid),
   .i_m0_pck       ({axis_snk_if.tlast,
                     axis_snk_if.tuser_vendor,
                     axis_snk_if.tdata,
                     axis_snk_if.tkeep}),
   .o_m0_ready     (axis_snk_if.tready),
   .i_s0_ready     (axis_reg.tready),
   .o_s0_valid     (axis_reg.tvalid),
   .o_s0_pck       ({axis_reg.tlast,
                     axis_reg.tuser_vendor,
                     axis_reg.tdata,
                     axis_reg.tkeep})
);

// freeze the ready & valid signals
always_comb begin
   axis_src_if.tvalid       = axis_reg.tvalid;
   axis_src_if.tlast        = axis_reg.tlast;
   axis_src_if.tuser_vendor = axis_reg.tuser_vendor;
   axis_src_if.tdata        = axis_reg.tdata;
   axis_src_if.tkeep        = axis_reg.tkeep;
   axis_reg.tready          = axis_src_if.tready;

   if (pr_freeze_local) begin
      axis_src_if.tvalid    = 0;
      axis_reg.tready       = 0;
   end
end

endmodule : pr_slot_freeze_axis

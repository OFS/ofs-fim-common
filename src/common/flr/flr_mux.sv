// Copyright 2023 Intel Corporation
// SPDX-License-Identifier: MIT

//
// Description: 
//-----------------------------------------------------------------------------
//
// A simple mux that connects host FLR to agent ports. 
//
//-----------------------------------------------------------------------------

module flr_mux
   import pcie_ss_axis_pkg::*;
   import pf_vf_mux_pkg::*;
#(
   parameter NUM_PORT = 1,
   // Routing table params
   parameter int NUM_RTABLE_ENTRIES = 1,
   parameter pf_vf_mux_pkg::t_pfvf_rtable_entry [NUM_RTABLE_ENTRIES-1:0] 
             PFVF_ROUTING_TABLE = {NUM_RTABLE_ENTRIES{pf_vf_mux_pkg::t_pfvf_rtable_entry'(0)}}

) (
   input  logic                             clk,
   input  logic                             rst_n,

   input  pcie_ss_axis_pkg::t_axis_pcie_flr h_flr_req,
   output pcie_ss_axis_pkg::t_axis_pcie_flr h_flr_rsp,

   output pcie_ss_axis_pkg::t_axis_pcie_flr a_flr_req [NUM_PORT-1:0],
   input  pcie_ss_axis_pkg::t_axis_pcie_flr a_flr_rsp [NUM_PORT-1:0]
);
   localparam NID_WIDTH = $clog2(NUM_PORT);
   localparam FIFO_SHOWAHEAD = "OFF";
   
   function logic [NID_WIDTH:0] flr_to_port(
      input pcie_ss_axis_pkg::t_flr_func flr
   );
      // Search the routing table, stopping at the first match. The table
      // must be constructed such that there is always a match.
      for (int i = 0; i < NUM_RTABLE_ENTRIES; i = i + 1) begin
         if (pf_vf_mux_pkg::pfvf_tbl_matches(flr.pf, flr.vf, flr.vf_active, PFVF_ROUTING_TABLE[i]))
            return PFVF_ROUTING_TABLE[i].pfvf_port;
      end

      // Error!
      return -1;
   endfunction : flr_to_port
   
   // Map FLR requests host->agent
   always_ff @(posedge clk) begin : map_flr_req
      for(int p = 0; p < NUM_PORT; p++) begin
	 a_flr_req[p].tdata  <= h_flr_req.tdata;
	 a_flr_req[p].tvalid <= h_flr_req.tvalid & (flr_to_port(h_flr_req.tdata) == p);
      end
   end : map_flr_req

   // Facilitate FLR response agent->host:
   // Buffer FLR responses and pass them through round-robin
   t_axis_pcie_flr [NUM_PORT-1:0] port_flr_rsp;

   logic                 flr_arb_valid;
   logic [NUM_PORT-1:0]  flr_arb_req_n, flr_arb_gnt;
   logic [NID_WIDTH-1:0] flr_arb_sel_d, flr_arb_sel;

   always_ff @(posedge clk) begin
      h_flr_rsp.tvalid <= port_flr_rsp[flr_arb_sel].tvalid;
      h_flr_rsp.tdata  <= port_flr_rsp[flr_arb_sel].tdata;
   end
   
   // FLR bus does not have flow control, this block needs to be
   // sized to support buffering FLR from a port in the worst case:
   // (NUM_PORT-1) requests need to be serviced ahead of this port
   generate for(genvar p=0; p < NUM_PORT; p++) begin : flr_port
      fim_scfifo #(
         .DATA_WIDTH($bits(pcie_ss_axis_pkg::t_flr_func)),
         .DEPTH_LOG2(NID_WIDTH),
         .SHOWAHEAD(FIFO_SHOWAHEAD)
      ) flr_rsp_buf (
         .clk (clk),
         .sclr(!rst_n),

         .w_data (a_flr_rsp[p].tdata),
         .w_req  (a_flr_rsp[p].tvalid),

         .w_usedw(),
         .r_usedw(),
         .w_full (),
         .w_ready(),

         // request to arb
         .r_req  (flr_arb_gnt[p] & flr_arb_valid),
         .r_empty(flr_arb_req_n[p]),
         .r_valid(port_flr_rsp[p].tvalid),
         .r_data (port_flr_rsp[p].tdata)
      );
   end : flr_port
   endgenerate
   
   fair_arbiter #(
      .NUM_INPUTS(NUM_PORT)
   ) flr_rsp_arb (
      .clk             (clk),
      .reset_n         (rst_n),
      .hold_priority   ('0),
      .in_valid        (~flr_arb_req_n),
      .out_select_1hot (flr_arb_gnt),
      .out_select      (flr_arb_sel_d),
      .out_valid       (flr_arb_valid)
   );
   
   // FIFO has either latency 1 or 0 (show-ahead)
   generate
      if(FIFO_SHOWAHEAD == "ON") begin
	 always_comb flr_arb_sel = flr_arb_sel_d;
      end else begin
	 always_ff @(posedge clk) flr_arb_sel <= flr_arb_sel_d;
      end
   endgenerate

endmodule

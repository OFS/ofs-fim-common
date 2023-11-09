// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// Top level module for Remote SignalTap feature
//
//-----------------------------------------------------------------------------

`include "fpga_defines.vh"

module remote_stp_top #(
   // Set up remote STP? If 0, tie off the interfaces.
   parameter ENABLE = 1
 ) (
   // Clocks
   input   logic                 clk_100,

   // AXI-M interface
   ofs_fim_axi_mmio_if.slave     csr_if,

   // JTAG interface for PR region debug
   output  logic                 o_sr2pr_tms,
   output  logic                 o_sr2pr_tdi,
   input   logic                 i_pr2sr_tdo,
   output  logic                 o_sr2pr_tck,
   output  logic                 o_sr2pr_tckena,

   // JTAG interface for PR region debug
   output  logic [63:0]          remotestp_status,
   output  logic                 remotestp_parity_err
);

`ifdef INCLUDE_REMOTE_STP
   // Build remote STP as long as ENABLE is true
   localparam BUILD_REMOTE_STP = ENABLE;
`else
   localparam BUILD_REMOTE_STP = 0;
`endif

assign remotestp_status     = 64'd0;
assign remotestp_parity_err = 1'b0;

generate
 if (BUILD_REMOTE_STP) begin : do_stp
   // <implement Remote STP feature>

   remote_debug_jtag_only remote_debug_jtag_only(
      .jtag_clk_clk(clk_100),
      .host_if_slave_awid(csr_if.awid),
      .host_if_slave_awaddr(csr_if.awaddr),
      .host_if_slave_awlen(csr_if.awlen),
      .host_if_slave_awsize(csr_if.awsize),
      .host_if_slave_awburst(csr_if.awburst),
      .host_if_slave_awcache(csr_if.awcache),
      .host_if_slave_awprot(csr_if.awprot),
      .host_if_slave_awvalid(csr_if.awvalid),
      .host_if_slave_awready(csr_if.awready),
      .host_if_slave_wdata(csr_if.wdata),
      .host_if_slave_wstrb(csr_if.wstrb),
      .host_if_slave_wlast(csr_if.wlast),
      .host_if_slave_wvalid(csr_if.wvalid),
      .host_if_slave_wready(csr_if.wready),
      .host_if_slave_bid(csr_if.bid),
      .host_if_slave_bresp(csr_if.bresp),
      .host_if_slave_bvalid(csr_if.bvalid),
      .host_if_slave_bready(csr_if.bready),
      .host_if_slave_arid(csr_if.arid),
      .host_if_slave_araddr(csr_if.araddr),
      .host_if_slave_arlen(csr_if.arlen),
      .host_if_slave_arsize(csr_if.arsize),
      .host_if_slave_arburst(csr_if.arburst),
      .host_if_slave_arcache(csr_if.arcache),
      .host_if_slave_arprot(csr_if.arprot),
      .host_if_slave_arvalid(csr_if.arvalid),
      .host_if_slave_arready(csr_if.arready),
      .host_if_slave_rid(csr_if.rid),
      .host_if_slave_rdata(csr_if.rdata),
      .host_if_slave_rresp(csr_if.rresp),
      .host_if_slave_rlast(csr_if.rlast),
      .host_if_slave_rvalid(csr_if.rvalid),
      .host_if_slave_rready(csr_if.rready),
      .jtag_tck_clk(o_sr2pr_tck),
      .jtag_tck_ena(o_sr2pr_tckena),
      .jtag_tms(o_sr2pr_tms),
      .jtag_tdi(o_sr2pr_tdi),
      .jtag_tdo(i_pr2sr_tdo),
      .axi_reset_n_reset_n(csr_if.rst_n),
      .axi_clk_clk(csr_if.clk)
   );

 end // block: do_stp
 else begin : tie_off
   logic rvalid, bvalid;

   always_ff @ (posedge csr_if.clk) begin
      rvalid    <= csr_if.arvalid;
      bvalid    <= csr_if.awvalid;
   end

   // Tie-off
   assign csr_if.arready       = 1'b1;
   assign csr_if.rvalid        = rvalid;    // WAS 1'b0;
   assign csr_if.rresp         = 2'b00;
   assign csr_if.rdata         = '0;
   assign csr_if.rid           = '0;
   assign csr_if.rlast         = 1'b0;

   assign csr_if.awready       = 1'b1;
   assign csr_if.wready        = 1'b1;
   assign csr_if.bvalid        = bvalid;    // WAS 1'b0;
   assign csr_if.bresp         = 2'b00;
   assign csr_if.bid           = '0;

   assign o_sr2pr_tms          = 1'b0;
   assign o_sr2pr_tdi          = 1'b0;
   assign o_sr2pr_tck          = 1'b0;
   assign o_sr2pr_tckena       = 1'b0;
 end
endgenerate

endmodule




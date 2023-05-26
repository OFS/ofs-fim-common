// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// Top level module for Remote SignalTap feature
// 
//-----------------------------------------------------------------------------

`include "fpga_defines.vh"

module remote_stp_top (
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

   // <implement Remote STP feature>
   assign remotestp_status     = 64'h0;
   assign remotestp_parity_err = 1'b0;

remote_debug_jtag_only remote_debug_jtag_only(
   .jtag_clk_clk(clk_100),                                  //           clk.clk
   .host_if_slave_awid(csr_if.awid),    // host_if_slave.awid
   .host_if_slave_awaddr(csr_if.awaddr),  //              .awaddr
   .host_if_slave_awlen(csr_if.awlen),   //              .awlen
   .host_if_slave_awsize(csr_if.awsize),  //              .awsize
   .host_if_slave_awburst(csr_if.awburst), //              .awburst
   .host_if_slave_awcache(csr_if.awcache), //              .awcache
   .host_if_slave_awprot(csr_if.awprot),  //              .awprot
   .host_if_slave_awvalid(csr_if.awvalid), //              .awvalid
   .host_if_slave_awready(csr_if.awready), //              .awready
   .host_if_slave_wdata(csr_if.wdata),   //              .wdata
   .host_if_slave_wstrb(csr_if.wstrb),   //              .wstrb
   .host_if_slave_wlast(csr_if.wlast),   //              .wlast
   .host_if_slave_wvalid(csr_if.wvalid),  //              .wvalid
   .host_if_slave_wready(csr_if.wready),  //              .wready
   .host_if_slave_bid(csr_if.bid),     //              .bid
   .host_if_slave_bresp(csr_if.bresp),   //              .bresp
   .host_if_slave_bvalid(csr_if.bvalid),  //              .bvalid
   .host_if_slave_bready(csr_if.bready),  //              .bready
   .host_if_slave_arid(csr_if.arid),    //              .arid
   .host_if_slave_araddr(csr_if.araddr),  //              .araddr
   .host_if_slave_arlen(csr_if.arlen),   //              .arlen
   .host_if_slave_arsize(csr_if.arsize),  //              .arsize
   .host_if_slave_arburst(csr_if.arburst), //              .arburst
   .host_if_slave_arcache(csr_if.arcache), //              .arcache
   .host_if_slave_arprot(csr_if.arprot),  //              .arprot
   .host_if_slave_arvalid(csr_if.arvalid), //              .arvalid
   .host_if_slave_arready(csr_if.arready), //              .arready
   .host_if_slave_rid(csr_if.rid),     //              .rid
   .host_if_slave_rdata(csr_if.rdata),   //              .rdata
   .host_if_slave_rresp(csr_if.rresp),   //              .rresp
   .host_if_slave_rlast(csr_if.rlast),   //              .rlast
   .host_if_slave_rvalid(csr_if.rvalid),  //              .rvalid
   .host_if_slave_rready(csr_if.rready),  //              .rready
   .jtag_tck_clk(o_sr2pr_tck),              //          jtag.tck
   .jtag_tck_ena(o_sr2pr_tckena),           //              .tckena
   .jtag_tms(o_sr2pr_tms),              //              .tms
   .jtag_tdi(o_sr2pr_tdi),              //              .tdi
   .jtag_tdo(i_pr2sr_tdo),              //              .tdo
   .axi_reset_n_reset_n(csr_if.rst_n),            //         reset.reset
   .axi_clk_clk(csr_if.clk)
);

`else
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

   assign csr_if.awready       = 1'b1;
   assign csr_if.wready        = 1'b1;
   assign csr_if.bvalid        = bvalid;    // WAS 1'b0;
   assign csr_if.bresp         = 2'b00;

   assign o_sr2pr_tms          = 1'b0;
   assign o_sr2pr_tdi          = 1'b0;
   assign o_sr2pr_tck          = 1'b0;
   assign o_sr2pr_tckena       = 1'b0;
   
   assign remotestp_status     = 64'd0;
   assign remotestp_parity_err = 1'b0;
`endif

endmodule




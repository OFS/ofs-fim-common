// Copyright (C) 2020 Intel Corporation.
// SPDX-License-Identifier: MIT

//
// Description
//-----------------------------------------------------------------------------
//
// Debug logging
//
//-----------------------------------------------------------------------------

module ofs_fim_pcie_ss_debug_log (
   input logic  fim_clk,
   input logic  fim_rst_n,

    // AXI-S data interfaces
   pcie_ss_axis_if.source           axi_st_rxreq_if,   // MMIO (when PCIe SS completions are sorted)
   pcie_ss_axis_if.source           axi_st_rx_if,      // Host memory read completions
   pcie_ss_axis_if.sink             axi_st_tx_if,      // Any FPGA to host command or completion
   pcie_ss_axis_if.sink             axi_st_txreq_if    // DM-encoded reads or interrupts
);


// synthesis translate_off
// Log TLP AXI-S traffic at the PCIe SS edge
logic axi_st_rx_if_sop, axi_st_rxreq_if_sop, axi_st_tx_if_sop;

initial
begin : log
   static int log_fd = $fopen("log_pcie_ss_edge.tsv", "w");

   // Write module hierarchy to the top of the log
   $fwrite(log_fd, "pcie_wrapper.sv: %m\n\n");

   forever @(posedge fim_clk) begin
      if (fim_rst_n && axi_st_rx_if.tvalid && axi_st_rx_if.tready) begin
         $fwrite(log_fd, "RX:    %s\n",
         pcie_ss_pkg::func_pcie_ss_flit_to_string(
         axi_st_rx_if_sop, axi_st_rx_if.tlast,
         pcie_ss_hdr_pkg::func_hdr_is_pu_mode(axi_st_rx_if.tuser_vendor),
         axi_st_rx_if.tdata, axi_st_rx_if.tkeep));
         $fflush(log_fd);
      end

      if (fim_rst_n && axi_st_rxreq_if.tvalid && axi_st_rxreq_if.tready) begin
         $fwrite(log_fd, "RXREQ: %s\n",
         pcie_ss_pkg::func_pcie_ss_flit_to_string(
         axi_st_rxreq_if_sop, axi_st_rxreq_if.tlast,
         pcie_ss_hdr_pkg::func_hdr_is_pu_mode(axi_st_rxreq_if.tuser_vendor),
         axi_st_rxreq_if.tdata, axi_st_rxreq_if.tkeep));
         $fflush(log_fd);
      end

      if (fim_rst_n && axi_st_tx_if.tvalid && axi_st_tx_if.tready) begin
         $fwrite(log_fd, "TX:    %s\n",
         pcie_ss_pkg::func_pcie_ss_flit_to_string(
         axi_st_tx_if_sop, axi_st_tx_if.tlast,
         pcie_ss_hdr_pkg::func_hdr_is_pu_mode(axi_st_tx_if.tuser_vendor),
         axi_st_tx_if.tdata, axi_st_tx_if.tkeep));
         $fflush(log_fd);
      end
      if (fim_rst_n && axi_st_txreq_if.tvalid && axi_st_txreq_if.tready) begin
         $fwrite(log_fd, "TXREQ: %s\n",
         pcie_ss_pkg::func_pcie_ss_flit_to_string(
         1'b1, axi_st_txreq_if.tlast,
         1'b0,
         { '0, axi_st_txreq_if.tdata}, { '0, 32'hffffffff }));
         $fflush(log_fd);
      end
   end
end

always_ff @(posedge fim_clk) begin
   if (axi_st_rx_if.tvalid && axi_st_rx_if.tready)
      axi_st_rx_if_sop <= axi_st_rx_if.tlast;
   if (axi_st_rxreq_if.tvalid && axi_st_rxreq_if.tready)
      axi_st_rxreq_if_sop <= axi_st_rxreq_if.tlast;

   if (axi_st_tx_if.tvalid && axi_st_tx_if.tready)
      axi_st_tx_if_sop <= axi_st_tx_if.tlast;

   if (!fim_rst_n) begin
      axi_st_rx_if_sop <= 1'b1;
      axi_st_rxreq_if_sop <= 1'b1;

      axi_st_tx_if_sop <= 1'b1;
   end
end

pcie_ss_hdr_pkg::PCIe_ReqHdr_t txreq_hdr;
assign txreq_hdr = pcie_ss_hdr_pkg::PCIe_ReqHdr_t'(axi_st_txreq_if.tdata[$bits(txreq_hdr)-1 : 0]);

always_ff @(posedge fim_clk) begin
  if (fim_rst_n && axi_st_txreq_if.tvalid) begin
    assert(pcie_ss_hdr_pkg::func_hdr_is_dm_mode(axi_st_txreq_if.tuser_vendor)) else
      $fatal(2, " ** ERROR ** %m: txreq must be DM-encoded!");
    assert(axi_st_txreq_if.tlast) else
      $fatal(2, " ** ERROR ** %m: txreq must be only headers!");
    assert(pcie_ss_hdr_pkg::func_is_mrd_req(txreq_hdr.fmt_type) || pcie_ss_hdr_pkg::func_is_interrupt_req(txreq_hdr.fmt_type)) else
      $fatal(2, " ** ERROR ** %m: txreq may only be MRd or Intr!");
  end
end
// synthesis translate_on

endmodule



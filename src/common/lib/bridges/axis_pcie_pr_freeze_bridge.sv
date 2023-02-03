// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// AXIS pipeline generator
//
//-----------------------------------------------------------------------------

`timescale 1 ps / 1 ps
module axis_pcie_pr_freeze_bridge 
#( 
    parameter TDATA_WIDTH          = 512,
    parameter TUSER_WIDTH          = 10,
    parameter PL_DEPTH = 1,
    // 0 - Uses pr_freeze signal
    // 1 - Doesn't use pr_freeze signal
    parameter PR_FREEZE_DIS = 0,
    parameter RX_REG_MODE = 0,
    parameter TX_REG_MODE = 0
)(
    input logic            port_rst_n,
    input logic            pr_freeze,
    pcie_ss_axis_if.sink   axi_rx_if_s,
    pcie_ss_axis_if.source axi_rx_if_m,
    pcie_ss_axis_if.sink   axi_tx_if_s,
    pcie_ss_axis_if.source axi_tx_if_m

);

pcie_ss_axis_if     axi_tx_if_t0();
//pcie_ss_axis_if     axi_tx_if_t1();

pcie_ss_axis_if     axi_rx_if_t0();
//pcie_ss_axis_if     axi_rx_if_t1();

logic pr_freeze_wire;
generate 
if (PR_FREEZE_DIS == 1) begin
    assign pr_freeze_wire = 0;
end else begin
    assign pr_freeze_wire = pr_freeze;
end
endgenerate

axis_pipeline #(
   .TDATA_WIDTH (TDATA_WIDTH),
   .TUSER_WIDTH (TUSER_WIDTH),
   .PL_DEPTH    (PL_DEPTH),
   .MODE        (TX_REG_MODE) 
) pr_frz_fn2mx_port (
   .clk         (axi_tx_if_m.clk),
   .rst_n       (port_rst_n),
   .axis_s      (axi_tx_if_s),
   .axis_m      (axi_tx_if_t0)
);

// freeze ready & valid
always_comb begin
   axi_tx_if_m.tvalid         = axi_tx_if_t0.tvalid;
   axi_tx_if_m.tlast          = axi_tx_if_t0.tlast;
   axi_tx_if_m.tuser_vendor   = axi_tx_if_t0.tuser_vendor;
   axi_tx_if_m.tdata          = axi_tx_if_t0.tdata;
   axi_tx_if_m.tkeep          = axi_tx_if_t0.tkeep;
   axi_tx_if_t0.tready      = axi_tx_if_m.tready;

   if (pr_freeze_wire) begin
      axi_tx_if_m.tvalid     = 0;
      axi_tx_if_t0.tready  = 0;
   end
end

// Register rx-a signals for freeze logic
axis_pipeline #(
   .TDATA_WIDTH (TDATA_WIDTH),
   .TUSER_WIDTH (TUSER_WIDTH),
   .PL_DEPTH    (PL_DEPTH),
   .MODE        (RX_REG_MODE) 
) pr_frz_mx2fn_port (
   .clk    (axi_rx_if_s.clk),
   .rst_n  (port_rst_n),
   .axis_s (axi_rx_if_t0),
   .axis_m (axi_rx_if_m)
);

// freeze ready & valid
always_comb begin
   axi_rx_if_t0.tvalid       = axi_rx_if_s.tvalid;
   axi_rx_if_t0.tlast        = axi_rx_if_s.tlast;
   axi_rx_if_t0.tuser_vendor = axi_rx_if_s.tuser_vendor;
   axi_rx_if_t0.tdata        = axi_rx_if_s.tdata;
   axi_rx_if_t0.tkeep        = axi_rx_if_s.tkeep;
   axi_rx_if_s.tready          = axi_rx_if_t0.tready;

   if (pr_freeze_wire) begin
      axi_rx_if_t0.tvalid  = 0;
      axi_rx_if_s.tready     = 0;
   end
end

endmodule // axis_pcie_pr_freeze_bridge


// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
// PIM SHIM for the MEM_TG2 AFU persona
//

`include "ofs_plat_if.vh"

module ofs_plat_afu
  (
   ofs_plat_if plat_ifc
   );

localparam NUM_MEM_CH = mem_ss_pkg::MC_CHANNEL;

// Index of each feature in the AXIS bus
localparam AXIS_HEM_TG2_PID = 2;

// PCIe clock domain
wire clk = plat_ifc.clocks.pClk.clk;
wire rst_n = plat_ifc.clocks.pClk.reset_n;

// Standard FIM PCIe TLP AXI-S interfaces
pcie_ss_axis_if pcie_ss_tx_a_st(clk, rst_n);
pcie_ss_axis_if pcie_ss_rx_a_st(clk, rst_n);

ofs_fim_emif_axi_mm_if ext_mem_if[NUM_MEM_CH-1:0]();


mem_tg2_top
  #(
    .PF_ID(0),
    .VF_ID(3),
    .VF_ACTIVE(1),
    .NUM_TG(NUM_MEM_CH))
mem_tg2_inst
  (
   .clk           (clk),
   .rst_n         (rst_n),
   .axis_rx_if    (pcie_ss_rx_a_st),
   .axis_tx_if    (pcie_ss_tx_a_st),
   .mem_tg_active (),
   .ext_mem_if    (ext_mem_if)
   );

//
// The plat_ifc wrapper has a slightly different representation of the TLP
// stream because it uses a generic AXI-S that is also used by the PIM.
// Translating between the plat_ifc version and the version expected
// by HE LB is a simple wire mapping.
//

logic tx_a_st_sop;

assign pcie_ss_tx_a_st.tready = plat_ifc.host_chan.ports[AXIS_HEM_TG2_PID].afu_tx_a_st.tready;
assign plat_ifc.host_chan.ports[AXIS_HEM_TG2_PID].afu_tx_a_st.tvalid = pcie_ss_tx_a_st.tvalid;

always_comb
  begin
     plat_ifc.host_chan.ports[AXIS_HEM_TG2_PID].afu_tx_a_st.t.last = pcie_ss_tx_a_st.tlast;
     plat_ifc.host_chan.ports[AXIS_HEM_TG2_PID].afu_tx_a_st.t.data = pcie_ss_tx_a_st.tdata;
     plat_ifc.host_chan.ports[AXIS_HEM_TG2_PID].afu_tx_a_st.t.keep = pcie_ss_tx_a_st.tkeep;
     // plat_ifc breaks user bits into a struct. It also supports multiple
     // SOP/EOP bits within a single message. HE LB does not, so just set
     // the user bit group 0. The SOP/EOP bits are required by ASE and debug
     // loggers.
     plat_ifc.host_chan.ports[AXIS_HEM_TG2_PID].afu_tx_a_st.t.user = '0;
     plat_ifc.host_chan.ports[AXIS_HEM_TG2_PID].afu_tx_a_st.t.user[0].dm_mode = pcie_ss_tx_a_st.tuser_vendor[0];
     plat_ifc.host_chan.ports[AXIS_HEM_TG2_PID].afu_tx_a_st.t.user[0].sop = tx_a_st_sop;
     plat_ifc.host_chan.ports[AXIS_HEM_TG2_PID].afu_tx_a_st.t.user[0].eop = pcie_ss_tx_a_st.tlast;
  end

// Compute SOP
always_ff @(posedge clk)
  begin
     if (!rst_n)
       tx_a_st_sop <= 1'b1;
     else if (pcie_ss_tx_a_st.tready && pcie_ss_tx_a_st.tvalid)
       tx_a_st_sop <= pcie_ss_tx_a_st.tlast;
  end

assign plat_ifc.host_chan.ports[AXIS_HEM_TG2_PID].afu_rx_a_st.tready = pcie_ss_rx_a_st.tready;
assign pcie_ss_rx_a_st.tvalid = plat_ifc.host_chan.ports[AXIS_HEM_TG2_PID].afu_rx_a_st.tvalid;

always_comb
  begin
     pcie_ss_rx_a_st.tlast = plat_ifc.host_chan.ports[AXIS_HEM_TG2_PID].afu_rx_a_st.t.last;
     pcie_ss_rx_a_st.tdata = plat_ifc.host_chan.ports[AXIS_HEM_TG2_PID].afu_rx_a_st.t.data;
     pcie_ss_rx_a_st.tkeep = plat_ifc.host_chan.ports[AXIS_HEM_TG2_PID].afu_rx_a_st.t.keep;
     // plat_ifc breaks user bits into a struct. Just pass the DM/PU encoding bit.
     pcie_ss_rx_a_st.tuser_vendor = '0;
     pcie_ss_rx_a_st.tuser_vendor[0] = plat_ifc.host_chan.ports[AXIS_HEM_TG2_PID].afu_rx_a_st.t.user[0].dm_mode;
  end

// HE LB does not use the B ports. All traffic is sent on A.
assign plat_ifc.host_chan.ports[AXIS_HEM_TG2_PID].afu_tx_b_st.tvalid = 1'b0;
assign plat_ifc.host_chan.ports[AXIS_HEM_TG2_PID].afu_rx_b_st.tready = 1'b1;

generate
  for (genvar b = 0; b < NUM_MEM_CH; b = b + 1)
    begin : lm

    assign ext_mem_if[b].clk = plat_ifc.local_mem.banks[b].clk;
    assign ext_mem_if[b].awready = plat_ifc.local_mem.banks[b].awready;

    assign plat_ifc.local_mem.banks[b].awvalid = ext_mem_if[b].awvalid;
    assign plat_ifc.local_mem.banks[b].aw.id = ext_mem_if[b].awid;
    assign plat_ifc.local_mem.banks[b].aw.addr = ext_mem_if[b].awaddr;
    assign plat_ifc.local_mem.banks[b].aw.len = ext_mem_if[b].awlen;
    assign plat_ifc.local_mem.banks[b].aw.size = ext_mem_if[b].awsize;
    assign plat_ifc.local_mem.banks[b].aw.burst = ext_mem_if[b].awburst;
    assign plat_ifc.local_mem.banks[b].aw.lock = ext_mem_if[b].awlock;
    assign plat_ifc.local_mem.banks[b].aw.cache = ext_mem_if[b].awcache;
    assign plat_ifc.local_mem.banks[b].aw.prot = ext_mem_if[b].awprot;
    assign plat_ifc.local_mem.banks[b].aw.user = ext_mem_if[b].awuser;

    assign ext_mem_if[b].wready = plat_ifc.local_mem.banks[b].wready;

    assign plat_ifc.local_mem.banks[b].wvalid = ext_mem_if[b].wvalid;
    assign plat_ifc.local_mem.banks[b].w.data = ext_mem_if[b].wdata;
    assign plat_ifc.local_mem.banks[b].w.strb = ext_mem_if[b].wstrb;
    assign plat_ifc.local_mem.banks[b].w.last = ext_mem_if[b].wlast;
    assign plat_ifc.local_mem.banks[b].bready = ext_mem_if[b].bready;

    assign ext_mem_if[b].bvalid = plat_ifc.local_mem.banks[b].bvalid;
    assign ext_mem_if[b].bid = plat_ifc.local_mem.banks[b].b.id;
    assign ext_mem_if[b].bresp = plat_ifc.local_mem.banks[b].b.resp;
    assign ext_mem_if[b].buser = plat_ifc.local_mem.banks[b].b.user;

    assign ext_mem_if[b].arready = plat_ifc.local_mem.banks[b].arready;

    assign plat_ifc.local_mem.banks[b].arvalid = ext_mem_if[b].arvalid;
    assign plat_ifc.local_mem.banks[b].ar.id = ext_mem_if[b].arid;
    assign plat_ifc.local_mem.banks[b].ar.addr = ext_mem_if[b].araddr;
    assign plat_ifc.local_mem.banks[b].ar.len = ext_mem_if[b].arlen;
    assign plat_ifc.local_mem.banks[b].ar.size = ext_mem_if[b].arsize;
    assign plat_ifc.local_mem.banks[b].ar.burst = ext_mem_if[b].arburst;
    assign plat_ifc.local_mem.banks[b].ar.lock = ext_mem_if[b].arlock;
    assign plat_ifc.local_mem.banks[b].ar.cache = ext_mem_if[b].arcache;
    assign plat_ifc.local_mem.banks[b].ar.prot = ext_mem_if[b].arprot;
    assign plat_ifc.local_mem.banks[b].ar.user = ext_mem_if[b].aruser;
    assign plat_ifc.local_mem.banks[b].rready = ext_mem_if[b].rready;

    assign ext_mem_if[b].rvalid = plat_ifc.local_mem.banks[b].rvalid;
    assign ext_mem_if[b].rid = plat_ifc.local_mem.banks[b].r.id;
    assign ext_mem_if[b].rdata = plat_ifc.local_mem.banks[b].r.data;
    assign ext_mem_if[b].rresp = plat_ifc.local_mem.banks[b].r.resp;
    assign ext_mem_if[b].rlast = plat_ifc.local_mem.banks[b].r.last;
    assign ext_mem_if[b].ruser = plat_ifc.local_mem.banks[b].r.user;
    end // block: lm
endgenerate

// ====================================================================
//
//  Tie off unused ports.
//
// ====================================================================

ofs_plat_if_tie_off_unused
  #(
    // Masks are bit masks, with bit 0 corresponding to port/bank zero.
    // Set a bit in the mask when a port is IN USE by the design.
    // This way, the AFU does not need to know about every available
    // device. By default, devices are tied off.

    // All available banks beyond NUM_LOCAL_MEM_BANKS will be tied off
    .LOCAL_MEM_IN_USE_MASK((1 << NUM_MEM_CH) - 1),

    // All available VFs beyond NUM_AFU_PORTS will be tied off and
    // respond with a dummy AFU ID.
    .HOST_CHAN_IN_USE_MASK(1 << AXIS_HEM_TG2_PID)
    )
tie_off(plat_ifc);

endmodule // ofs_plat_afu

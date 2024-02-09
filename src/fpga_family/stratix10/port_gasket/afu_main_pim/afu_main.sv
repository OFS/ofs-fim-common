// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
// -----------------------------------------------------------------------------
//  PIM version of afu_main
// -----------------------------------------------------------------------------

//
// Map the FIM's device interfaces to Platform Interface Manager (PIM)
// interfaces and instantiate a PIM-based AFU.
//

// OPAE_PLATFORM_GEN is set when a script is generating the PR build environment
// used with OPAE SDK tools. When set, afu_main acts as a simple template that
// defines the module but doesn't include an actual AFU.
`ifndef OPAE_PLATFORM_GEN
`include "ofs_plat_if.vh"
`endif

`ifndef SIM_MODE
   `define INCLUDE_REMOTE_STP
`endif

import top_cfg_pkg::*;
import ofs_fim_eth_if_pkg::*;

module afu_main # (
   parameter PG_NUM_PORTS    = 1,
   // PF/VF to which each port is mapped
   parameter pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t[PG_NUM_PORTS-1:0] PORT_PF_VF_INFO =
                {PG_NUM_PORTS{pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t'(0)}},

   parameter NUM_MEM_CH      = NUM_MEM_CH
)(
   input  logic                  clk,
   input  logic                  clk_div2,
   input  logic                  clk_div4,
   input  logic                  uclk_usr,
   input  logic                  uclk_usr_div2,
   input  logic                  rst_n_100M,
   input  logic                  rst_n,
   input  logic                  port_rst_n          [PG_NUM_PORTS-1:0],

   // PCIe A ports are the standard TLP channels. All host responses
   // arrive on the RX A port.
   pcie_ss_axis_if.source        afu_axi_tx_a_if     [PG_NUM_PORTS-1:0],
   pcie_ss_axis_if.sink          afu_axi_rx_a_if     [PG_NUM_PORTS-1:0],
   // PCIe B ports are a second channel on which reads and interrupts
   // may be sent from the AFU. To improve throughput, reads on B may flow
   // around writes on A through PF/VF MUX trees until writes are committed
   // to the PCIe subsystem. AFUs may tie off the B port and send all
   // messages to A.
   pcie_ss_axis_if.source        afu_axi_tx_b_if     [PG_NUM_PORTS-1:0],
   // Write commits are signaled here on the RX B port, indicating the
   // point at which the A and B channels become ordered within the FIM.
   // Commits are signaled after tlast of a write on TX A, after arbitration
   // with TX B within the FIM. The commit is a Cpl (without data),
   // returning the tag value from the write request. AFUs that do not
   // need local write commits may ignore this port, but must set
   // tready to 1.
   pcie_ss_axis_if.sink          afu_axi_rx_b_if     [PG_NUM_PORTS-1:0],

   ofs_fim_emif_avmm_if.user     ext_mem_if          [NUM_MEM_CH],

`ifdef INCLUDE_HE_HSSI  
   ofs_fim_hssi_ss_tx_axis_if.client       hssi_ss_st_tx [MAX_NUM_ETH_CHANNELS-1:0],
   ofs_fim_hssi_ss_rx_axis_if.client       hssi_ss_st_rx [MAX_NUM_ETH_CHANNELS-1:0],
   ofs_fim_hssi_fc_if.client               hssi_fc [MAX_NUM_ETH_CHANNELS-1:0],
   `ifdef INCLUDE_PTP
      ofs_fim_hssi_ptp_tx_tod_if.client       hssi_ptp_tx_tod [MAX_NUM_ETH_CHANNELS-1:0],
      ofs_fim_hssi_ptp_rx_tod_if.client       hssi_ptp_rx_tod [MAX_NUM_ETH_CHANNELS-1:0],
      ofs_fim_hssi_ptp_tx_egrts_if.client     hssi_ptp_tx_egrts [MAX_NUM_ETH_CHANNELS-1:0],
      ofs_fim_hssi_ptp_rx_ingrts_if.client    hssi_ptp_rx_ingrts [MAX_NUM_ETH_CHANNELS-1:0],
   `endif
   input logic [MAX_NUM_ETH_CHANNELS-1:0]  i_hssi_clk_pll,
`endif

// JTAG interface for PR region debug
   input  logic                  sr2pr_tms,
   input  logic                  sr2pr_tdi,
   output logic                  pr2sr_tdo,
   input  logic                  sr2pr_tck,
   input  logic                  sr2pr_tckena
);

`ifndef OPAE_PLATFORM_GEN

//----------------------------------------------
// Top-level AFU platform interface
//----------------------------------------------

// OFS platform interface constructs a single interface object that
// wraps all ports to the AFU.
ofs_plat_if#(.ENABLE_LOG(1)) plat_ifc();

logic [PG_NUM_PORTS-1:0] port_softreset_n = {PG_NUM_PORTS{1'b0}};

// Clocks
ofs_plat_std_clocks_gen_port_resets clocks (
   .pClk(clk),
   .pClk_reset_n(port_softreset_n),
   .pClkDiv2(clk_div2),
   .pClkDiv4(clk_div4),
   .uClk_usr(uclk_usr),
   .uClk_usrDiv2(uclk_usr_div2),
   .clocks(plat_ifc.clocks)
);

// Reset, etc. With multiple ports, a global soft reset doesn't make much
// sense. The softReset_n signal and reset associated with pClk remain
// for compatibility. AFUs with multiple PCIe ports should use the reset
// signal bound to each of the PIM's host channel interfaces as soft
// reset from the channel.
assign plat_ifc.softReset_n = plat_ifc.clocks.pClk.reset_n;
assign plat_ifc.pwrState = 1'b0;


//----------------------------------------------
// AXI-S PCIe channels
//----------------------------------------------

generate
   for (genvar p = 0; p < PG_NUM_PORTS; p = p + 1)
   begin : hc
      assign plat_ifc.host_chan.ports[p].clk = plat_ifc.clocks.pClk.clk;
      assign plat_ifc.host_chan.ports[p].reset_n = port_softreset_n[p];
      assign plat_ifc.host_chan.ports[p].instance_number = p;

      always @(posedge plat_ifc.host_chan.ports[p].clk)
      begin
         port_softreset_n[p] <= rst_n && port_rst_n[p];
      end

      assign plat_ifc.host_chan.ports[p].pf_num = PORT_PF_VF_INFO[p].pf_num;
      assign plat_ifc.host_chan.ports[p].vf_num = PORT_PF_VF_INFO[p].vf_num;
      assign plat_ifc.host_chan.ports[p].vf_active = PORT_PF_VF_INFO[p].vf_active;
      assign plat_ifc.host_chan.ports[p].link_num = PORT_PF_VF_INFO[p].link_num;

      map_fim_pcie_ss_to_host_chan map_host_chan (
         .pcie_ss_tx_a_st(afu_axi_tx_a_if[p]),
         .pcie_ss_tx_b_st(afu_axi_tx_b_if[p]),
         .pcie_ss_rx_a_st(afu_axi_rx_a_if[p]),
         .pcie_ss_rx_b_st(afu_axi_rx_b_if[p]),

         .pim_tx_a_st(plat_ifc.host_chan.ports[p].afu_tx_a_st),
         .pim_tx_b_st(plat_ifc.host_chan.ports[p].afu_tx_b_st),
         .pim_rx_a_st(plat_ifc.host_chan.ports[p].afu_rx_a_st),
         .pim_rx_b_st(plat_ifc.host_chan.ports[p].afu_rx_b_st)
      );
   end
endgenerate


//----------------------------------------------
// Local memory
//----------------------------------------------

generate
   for (genvar b = 0; b < NUM_MEM_CH; b = b + 1)
   begin : lm
      // Map the PIM's local_mem interface to the FIM's AVMM interface.
      map_fim_emif_avmm_to_local_mem
        #(
          .INSTANCE_NUMBER(b)
          )
       map_local_mem
         (
          .fim_mem_bank(ext_mem_if[b]),
          .afu_mem_bank(plat_ifc.local_mem.banks[b])
          );
   end
endgenerate


//----------------------------------------------
// Ethernet
//----------------------------------------------
`ifdef INCLUDE_HE_HSSI  
generate
   for (genvar ch = 0; ch < MAX_NUM_ETH_CHANNELS; ch = ch + 1) begin
      assign hssi_ss_st_tx[ch].tx.tvalid       = 1'b0;
      assign hssi_ss_st_tx[ch].tx.tdata        = '0;
      assign hssi_ss_st_tx[ch].tx.tkeep        = '0;
      assign hssi_ss_st_tx[ch].tx.tlast        = '0;
      assign hssi_ss_st_tx[ch].tx.tuser.client = '0;
      assign hssi_fc[ch].tx_pause = 1'b0;
      assign hssi_fc[ch].tx_pfc   = '0;
   end
endgenerate
`endif


//----------------------------------------------
// Other (PIM extension interface)
//----------------------------------------------

// The extension interface here is a stub that could be used to pass
// extended state through plat_ifc without modifying the PIM.
// The "sample_state" is used in examples. We suggest keeping it, even
// if you update the interface.
assign plat_ifc.other.ports[0].sample_state = 32'hcafef00d;


//----------------------------------------------
// Instantiate the AFU
//----------------------------------------------

`PLATFORM_SHIM_MODULE_NAME `PLATFORM_SHIM_MODULE_NAME (
   .plat_ifc
);

`endif //  `ifndef OPAE_PLATFORM_GEN


//----------------------------
// Remote Debug JTAG IP instantiation
//----------------------------

wire remote_stp_conf_reset = ~rst_n_100M;
`include "ofs_fim_remote_stp_node.vh"

endmodule // afu_main

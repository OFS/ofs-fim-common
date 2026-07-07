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

import top_cfg_pkg::*;

// Is the PR build using the PIM? If so, this port_afu_instances() module
// will be used. If the AFU provides its own port_afu_instances, typically by
// setting the afu-top-interface class to "afu_main" in the AFU's JSON file,
// then the code here is disabled. The macro is set by the
// afu_synth_setup/afu_sim_setup scripts.
`ifndef AFU_TOP_REQUIRES_AFU_MAIN_IF

module port_afu_instances # (
   parameter PG_NUM_LINKS    = 1,
   parameter PG_NUM_PORTS    = 1,
   // PF/VF to which each port is mapped
   parameter pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t[PG_NUM_PORTS-1:0] PORT_PF_VF_INFO =
                {PG_NUM_PORTS{pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t'(0)}},

   parameter NUM_MEM_CH      = 0,
`ifdef INCLUDE_HSSI
   parameter MAX_ETH_CH      = ofs_fim_eth_plat_if_pkg::MAX_NUM_ETH_CHANNELS,
`else
   parameter MAX_ETH_CH      = 0,
`endif

   // Used in simulation by ASE to emulate multiple links. ASE PCIe emulation
   // supports only one link. The multi-link ASE environment adds an extra PF/VF
   // MUX before afu_main() and requires unique VFs across all links.
   // The parameter is relevant only in multiplexed channel mode, since PF/VF
   // MUXing is complete already in normal mode before reaching
   // port_afu_instances.
   parameter LINK_NUM_FROM_PORT_INFO = 0,

`ifdef OFS_PLAT_HOST_CHAN_MULTIPLEXED
   // When PCIe is multiplexed here, the incoming channels are
   // grouped by PCIe links. PF/VF tagged streams remain multiplexed
   // within each link.
   parameter NUM_PCIE_STREAMS = PG_NUM_LINKS
`else
   // PF/VF MUX in afu_main() splits all links/PFs/VFs into
   // individual streams and maps them to a linear collection of ports.
   parameter NUM_PCIE_STREAMS = PG_NUM_PORTS
`endif
)(
   input  logic clk,
   input  logic clk_div2,
   input  logic clk_div4,
   input  logic uclk_usr,
   input  logic uclk_usr_div2,
   input  logic pr_freeze_to_afu,  // optional for pr_freeze usage in afu
   input  logic rst_n,
   // Both soft reset and global rst_n trigger port_rst_n
`ifdef OFS_PLAT_HOST_CHAN_MULTIPLEXED
   // PCIe streams remain mulitplexed -- resets are grouped by PCIe links
   input  logic [PG_NUM_PORTS-1:0] port_rst_n[PG_NUM_LINKS-1:0],
`else
   // Demultiplexed array across link/PF/VF
   input  logic [PG_NUM_PORTS-1:0] port_rst_n,
`endif

   // PCIe A ports are the standard TLP channels. All host responses
   // arrive on the RX A port.
   pcie_ss_axis_if.source        afu_axi_tx_a_if [NUM_PCIE_STREAMS-1:0],
   pcie_ss_axis_if.sink          afu_axi_rx_a_if [NUM_PCIE_STREAMS-1:0],
   // PCIe B ports are a second channel on which reads and interrupts
   // may be sent from the AFU. To improve throughput, reads on B may flow
   // around writes on A through PF/VF MUX trees until writes are committed
   // to the PCIe subsystem. AFUs may tie off the B port and send all
   // messages to A.
   pcie_ss_axis_if.source        afu_axi_tx_b_if [NUM_PCIE_STREAMS-1:0],
   // Write commits are signaled here on the RX B port, indicating the
   // point at which the A and B channels become ordered within the FIM.
   // Commits are signaled after tlast of a write on TX A, after arbitration
   // with TX B within the FIM. The commit is a Cpl (without data),
   // returning the tag value from the write request. AFUs that do not
   // need local write commits may ignore this port, but must set
   // tready to 1.
   pcie_ss_axis_if.sink          afu_axi_rx_b_if [NUM_PCIE_STREAMS-1:0]

   `ifdef INCLUDE_LOCAL_MEM
      // Local memory
     ,ofs_fim_emif_axi_mm_if.user     ext_mem_if [NUM_MEM_CH-1:0]
   `endif

   `ifdef INCLUDE_HSSI
     ,ofs_fim_hssi_ss_tx_axis_if.client hssi_ss_st_tx [MAX_ETH_CH-1:0],
      ofs_fim_hssi_ss_rx_axis_if.client hssi_ss_st_rx [MAX_ETH_CH-1:0],
      ofs_fim_hssi_fc_if.client         hssi_fc [MAX_ETH_CH-1:0],
      input logic [MAX_ETH_CH-1:0]      i_hssi_clk_pll
   `endif
);


`ifndef OPAE_PLATFORM_GEN

//----------------------------------------------
// Top-level AFU platform interface
//----------------------------------------------

// OFS platform interface constructs a single interface object that
// wraps all ports to the AFU.
ofs_plat_if#(.ENABLE_LOG(1)) plat_ifc();

// Vector of PCIe port resets. When ports are multiplexed, these
// will be cold and PR reset. When ports are already demultiplexed,
// these will include function level reset.
logic [NUM_PCIE_STREAMS-1:0] pcie_stream_rst_n;
`ifdef OFS_PLAT_HOST_CHAN_MULTIPLEXED
    for (genvar p = 0; p < NUM_PCIE_STREAMS; p = p + 1) begin : r
        assign pcie_stream_rst_n[p] = afu_axi_tx_a_if[p].rst_n;
    end
`else
    assign pcie_stream_rst_n = port_rst_n;
`endif

// Clocks
ofs_plat_std_clocks_gen_port_resets clocks (
   .pClk(clk),
   .pClk_reset_n(pcie_stream_rst_n),
`ifdef OFS_PLAT_HOST_CHAN_MULTIPLEXED
   // Pass resets with and without function level reset
   .pClk_demux_reset_n(port_rst_n),
`endif
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

assign plat_ifc.pr_freeze_to_afu_in = pr_freeze_to_afu;
//----------------------------------------------
// AXI-S PCIe channels
//----------------------------------------------

function automatic pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t[PG_NUM_PORTS-1:0] gen_link_pf_vf_info(int stream_num);
    pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t[PG_NUM_PORTS-1:0] pfvf = PORT_PF_VF_INFO;

    if (LINK_NUM_FROM_PORT_INFO) begin
        for (int p = 0; p < PG_NUM_PORTS; p = p + 1)
            pfvf[p].vf_num = pfvf[p].vf_num + (stream_num * PG_NUM_PORTS);
    end

    return pfvf;
endfunction // gen_link_pf_vf_info

generate
   for (genvar s = 0; s < NUM_PCIE_STREAMS; s = s + 1)
   begin : hc
       localparam pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t[PG_NUM_PORTS-1:0] LINK_PORT_PF_VF_INFO =
           gen_link_pf_vf_info(s);

      // Map the PIM's host_chan interface to the FIM's PCIe SS interface.
      map_fim_pcie_ss_to_pim_host_chan
        #(
          .INSTANCE_NUMBER(s),
`ifdef OFS_PLAT_HOST_CHAN_MULTIPLEXED
          .PORT_PF_VF_INFO(LINK_PORT_PF_VF_INFO)
`else
          .PF_NUM(PORT_PF_VF_INFO[s].pf_num),
          .VF_NUM(PORT_PF_VF_INFO[s].vf_num),
          .VF_ACTIVE(PORT_PF_VF_INFO[s].vf_active)
`endif
          )
       map_host_chan
         (
          .clk(plat_ifc.clocks.pClk.clk),
          .reset_n(pcie_stream_rst_n[s]),

          .pcie_ss_tx_a_st(afu_axi_tx_a_if[s]),
          .pcie_ss_tx_b_st(afu_axi_tx_b_if[s]),
          .pcie_ss_rx_a_st(afu_axi_rx_a_if[s]),
          .pcie_ss_rx_b_st(afu_axi_rx_b_if[s]),

          .port(plat_ifc.host_chan.ports[s])
          );
   end
endgenerate


//----------------------------------------------
// Local memory
//----------------------------------------------

`ifdef INCLUDE_LOCAL_MEM

generate
   for (genvar b = 0; b < NUM_MEM_CH; b = b + 1)
   begin : lm
      // Map the PIM's local_mem interface to the FIM's AXI-MM interface.
      map_fim_emif_axi_mm_to_local_mem
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

`endif


//----------------------------------------------
// Ethernet
//----------------------------------------------

`ifdef INCLUDE_HSSI

generate
   for (genvar c = 0; c < MAX_ETH_CH; c = c + 1)
   begin : hssi
      assign plat_ifc.hssi.channels[c].clk = i_hssi_clk_pll[c];
      assign plat_ifc.hssi.channels[c].reset_n = hssi_ss_st_rx[c].rst_n;

      ofs_fim_hssi_axis_connect_rx connect_rx (
         .to_client(plat_ifc.hssi.channels[c].data_rx),
         .to_mac(hssi_ss_st_rx[c])
      );

      ofs_fim_hssi_axis_connect_tx connect_tx (
         .to_client(plat_ifc.hssi.channels[c].data_tx),
         .to_mac(hssi_ss_st_tx[c])
      );

      ofs_fim_hssi_connect_fc connect_fc (
         .to_client(plat_ifc.hssi.channels[c].fc),
         .to_mac(hssi_fc[c])
      );
   end
endgenerate

`endif // `ifdef INCLUDE_HSSI


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

endmodule // port_afu_instances

`endif //  `ifndef AFU_TOP_REQUIRES_AFU_MAIN_IF

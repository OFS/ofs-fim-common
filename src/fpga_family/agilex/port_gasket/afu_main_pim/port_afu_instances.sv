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
   parameter PG_NUM_PORTS    = 1,
   // PF/VF to which each port is mapped
   parameter pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t[PG_NUM_PORTS-1:0] PORT_PF_VF_INFO =
                {PG_NUM_PORTS{pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t'(0)}},

   parameter NUM_MEM_CH      = 0,
   parameter MAX_ETH_CH      = ofs_fim_eth_plat_if_pkg::MAX_NUM_ETH_CHANNELS
)(
   input  logic clk,
   input  logic clk_div2,
   input  logic clk_div4,
   input  logic uclk_usr,
   input  logic uclk_usr_div2,

   input  logic rst_n,
   input  logic [PG_NUM_PORTS-1:0] port_rst_n,

   // PCIe A ports are the standard TLP channels. All host responses
   // arrive on the RX A port.
   pcie_ss_axis_if.source        afu_axi_tx_a_if [PG_NUM_PORTS-1:0],
   pcie_ss_axis_if.sink          afu_axi_rx_a_if [PG_NUM_PORTS-1:0],
   // PCIe B ports are a second channel on which reads and interrupts
   // may be sent from the AFU. To improve throughput, reads on B may flow
   // around writes on A through PF/VF MUX trees until writes are committed
   // to the PCIe subsystem. AFUs may tie off the B port and send all
   // messages to A.
   pcie_ss_axis_if.source        afu_axi_tx_b_if [PG_NUM_PORTS-1:0],
   // Write commits are signaled here on the RX B port, indicating the
   // point at which the A and B channels become ordered within the FIM.
   // Commits are signaled after tlast of a write on TX A, after arbitration
   // with TX B within the FIM. The commit is a Cpl (without data),
   // returning the tag value from the write request. AFUs that do not
   // need local write commits may ignore this port, but must set
   // tready to 1.
   pcie_ss_axis_if.sink          afu_axi_rx_b_if [PG_NUM_PORTS-1:0]

   `ifdef INCLUDE_DDR4
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

logic [PG_NUM_PORTS-1:0] port_softreset_n = {PG_NUM_PORTS{1'b0}};
logic [PG_NUM_PORTS-1:0] port_rst_n_q1 = {PG_NUM_PORTS{1'b0}};
logic rst_n_q1 = 1'b0;

always @(posedge clk) rst_n_q1 <= rst_n;


`ifndef OPAE_PLATFORM_GEN

//----------------------------------------------
// Top-level AFU platform interface
//----------------------------------------------

// OFS platform interface constructs a single interface object that
// wraps all ports to the AFU.
ofs_plat_if#(.ENABLE_LOG(1)) plat_ifc();

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
      // Map the PIM's host_chan interface to the FIM's PCIe SS interface.
      map_fim_pcie_ss_to_pim_host_chan
        #(
          .INSTANCE_NUMBER(p),

          .PF_NUM(PORT_PF_VF_INFO[p].pf_num),
          .VF_NUM(PORT_PF_VF_INFO[p].vf_num),
          .VF_ACTIVE(PORT_PF_VF_INFO[p].vf_active)
          )
       map_host_chan
         (
          .clk(plat_ifc.clocks.pClk.clk),
          .reset_n(port_softreset_n[p]),

          .pcie_ss_tx_a_st(afu_axi_tx_a_if[p]),
          .pcie_ss_tx_b_st(afu_axi_tx_b_if[p]),
          .pcie_ss_rx_a_st(afu_axi_rx_a_if[p]),
          .pcie_ss_rx_b_st(afu_axi_rx_b_if[p]),

          .port(plat_ifc.host_chan.ports[p])
          );

      always @(posedge plat_ifc.host_chan.ports[p].clk)
      begin
         port_rst_n_q1[p]     <= port_rst_n[p];
         port_softreset_n[p]  <= rst_n_q1 && port_rst_n_q1[p];
      end
   end
endgenerate


//----------------------------------------------
// Local memory
//----------------------------------------------

`ifdef INCLUDE_DDR4

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

`endif //  `ifdef INCLUDE_DDR4


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

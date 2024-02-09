// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT


// The PIM's top-level wrapper is included only because it defines the
// platform macros used below to make the afu_main() port list slightly
// more portable. Except for those macros it is not needed for the non-PIM
// AFUs.
`include "ofs_plat_if.vh"

// Merge HSSI macros from various platforms into a single AFU_MAIN_HAS_HSSI
`ifdef INCLUDE_HSSI
  `define AFU_MAIN_HAS_HSSI 1
`endif
`ifdef PLATFORM_FPGA_FAMILY_S10
  `ifdef INCLUDE_HE_HSSI
    `define AFU_MAIN_HAS_HSSI 1
  `endif
`endif

// ========================================================================
//
//  The ports in this implementation of afu_main() are complicated because
//  the code is expected to compile on multiple platforms, each with
//  subtle variations.
//
//  An implementation for a single platform should be simplified by
//  reducing the ports to only those of the target.
//
//  This example currently compiles on OFS for d5005 and n6000.
//
// ========================================================================

module port_afu_instances
#(
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
   // port_rst_n at this point also includes rst_n. The two are combined
   // in afu_main().
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
     ,ofs_fim_emif_axi_mm_if.user ext_mem_if [NUM_MEM_CH-1:0]
   `endif
   `ifdef PLATFORM_FPGA_FAMILY_S10
      // S10 uses AVMM for DDR
     ,ofs_fim_emif_avmm_if.user   ext_mem_if [NUM_MEM_CH-1:0]
   `endif

   `ifdef AFU_MAIN_HAS_HSSI
     ,ofs_fim_hssi_ss_tx_axis_if.client hssi_ss_st_tx [MAX_ETH_CH-1:0],
      ofs_fim_hssi_ss_rx_axis_if.client hssi_ss_st_rx [MAX_ETH_CH-1:0],
      ofs_fim_hssi_fc_if.client         hssi_fc [MAX_ETH_CH-1:0],
      input logic [MAX_ETH_CH-1:0]      i_hssi_clk_pll
   `endif

    // S10 HSSI PTP interface
   `ifdef INCLUDE_PTP
     ,ofs_fim_hssi_ptp_tx_tod_if.client       hssi_ptp_tx_tod [MAX_ETH_CH-1:0],
      ofs_fim_hssi_ptp_rx_tod_if.client       hssi_ptp_rx_tod [MAX_ETH_CH-1:0],
      ofs_fim_hssi_ptp_tx_egrts_if.client     hssi_ptp_tx_egrts [MAX_ETH_CH-1:0],
      ofs_fim_hssi_ptp_rx_ingrts_if.client    hssi_ptp_rx_ingrts [MAX_ETH_CH-1:0]
   `endif
   );

    localparam HE_MEM_IDX = `HE_MEM_IDX;

    for (genvar j = 0; j < PG_NUM_PORTS; j++) begin : he
        if (j != HE_MEM_IDX) begin : lb
            he_lb_top
              #(
                .PF_ID(PORT_PF_VF_INFO[j].pf_num),
                .VF_ID(PORT_PF_VF_INFO[j].vf_num),
                .VF_ACTIVE(PORT_PF_VF_INFO[j].vf_active),
                .CLK_MHZ(`OFS_PLAT_PARAM_CLOCKS_PCLK_FREQ)
                )
              top
                (
                 .clk,
                 .rst_n(port_rst_n[j]),
                 .axi_rx_a_if(afu_axi_rx_a_if[j]),
                 .axi_rx_b_if(afu_axi_rx_b_if[j]),
                 .axi_tx_a_if(afu_axi_tx_a_if[j]),
                 .axi_tx_b_if(afu_axi_tx_b_if[j])
                 );
        end
        else begin : mem
            he_mem_top
              #(
                .PF_ID(PORT_PF_VF_INFO[j].pf_num),
                .VF_ID(PORT_PF_VF_INFO[j].vf_num),
                .VF_ACTIVE(PORT_PF_VF_INFO[j].vf_active),
                .CLK_MHZ(`OFS_PLAT_PARAM_CLOCKS_PCLK_FREQ),
                .EMIF(1),
                .NUM_MEM_BANKS(NUM_MEM_CH)
                )
              top
                (
                 .clk,
                 .rst_n(port_rst_n[j]),
                 .axi_rx_a_if(afu_axi_rx_a_if[j]),
                 .axi_rx_b_if(afu_axi_rx_b_if[j]),
                 .axi_tx_a_if(afu_axi_tx_a_if[j]),
                 .axi_tx_b_if(afu_axi_tx_b_if[j]),
                 .ext_mem_if (ext_mem_if)
                 );
        end
    end


    // ======================================================
    // Tie off unused HSSI
    // ======================================================

  `ifdef AFU_MAIN_HAS_HSSI
    for (genvar c=0; c<MAX_ETH_CH; c++) begin : hssi
        assign hssi_ss_st_tx[c].tx = '0;
        assign hssi_fc[c].tx_pause = 0;
        assign hssi_fc[c].tx_pfc = 0;
    end
  `endif

endmodule : port_afu_instances

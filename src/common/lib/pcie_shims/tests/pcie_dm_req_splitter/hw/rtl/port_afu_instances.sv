// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT


// The PIM's top-level wrapper is included only because it defines the
// platform macros used below to make the afu_main() port list slightly
// more portable. Except for those macros it is not needed for the non-PIM
// AFUs.
`include "ofs_plat_if.vh"

// Merge HSSI macros from various platforms into a single AFU_MAIN_HAS_HSSI
`ifdef PLATFORM_FPGA_FAMILY_S10
  `ifdef INCLUDE_HSSI
    `define AFU_MAIN_HAS_HSSI 1
  `endif
`endif
`define AFU_MAIN_HAS_HSSI 1

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

// Clock crossing macro for a PCIe AXI-S. This will be applied to each stream.
`define PCIE_AXIS_CLK_CROSSING(to_fim, instance_name, width, src_if, dst_if) \
    ofs_plat_prim_ready_enable_async \
      #( \
        .DATA_WIDTH(width) \
        ) \
      instance_name \
       ( \
        .clk_in(to_fim ? uclk_usr : clk), \
        .reset_n_in(to_fim ? uclk_rst_n : port_rst_n[j]), \
        .ready_in(src_if.tready), \
        .valid_in(src_if.tvalid), \
        .data_in({ src_if.tlast, src_if.tuser_vendor, src_if.tdata, src_if.tkeep }), \
        .clk_out(to_fim ? clk : uclk_usr), \
        .reset_n_out(to_fim ? port_rst_n[j] : uclk_rst_n), \
        .ready_out(dst_if.tready), \
        .valid_out(dst_if.tvalid), \
        .data_out({ dst_if.tlast, dst_if.tuser_vendor, dst_if.tdata, dst_if.tkeep }) \
        )

    for (genvar j = 0; j < PG_NUM_PORTS; j++) begin : afu
        //
        // Move the PCIe TLP streams to uclk in order to test the
        // AFU at higher frequency. Use some PIM clock crossing
        // modules since they are already part of the environment.
        //
        logic uclk_rst_n;
        ofs_plat_prim_clock_crossing_reset p_to_u
           (
            .clk_src(clk),
            .clk_dst(uclk_usr),
            .reset_in(port_rst_n[j]),
            .reset_out(uclk_rst_n)
            );

        pcie_ss_axis_if rx_a_uclk_if(uclk_usr, uclk_rst_n);
        pcie_ss_axis_if rx_b_uclk_if(uclk_usr, uclk_rst_n);
        pcie_ss_axis_if tx_uclk_if[2](uclk_usr, uclk_rst_n);

        localparam AXIS_WIDTH = 1 + $bits(rx_a_if.tuser_vendor) +
                                $bits(rx_a_if.tdata) + $bits(rx_a_if.tkeep);

        `PCIE_AXIS_CLK_CROSSING(0, rx_a, AXIS_WIDTH, afu_axi_rx_a_if[j], rx_a_uclk_if);
        `PCIE_AXIS_CLK_CROSSING(0, rx_b, AXIS_WIDTH, afu_axi_rx_b_if[j], rx_b_uclk_if);
        `PCIE_AXIS_CLK_CROSSING(1, tx_a, AXIS_WIDTH, tx_uclk_if[0], afu_axi_tx_a_if[j]);
        `PCIE_AXIS_CLK_CROSSING(1, tx_b, AXIS_WIDTH, tx_uclk_if[1], afu_axi_tx_b_if[j]);

        //
        // Tag mapper is enabled only in simulation. The TX read request splitter generates
        // requests with the same tag for each packet in a split request. In a normal FIM
        // there is a shared tag mapper instantiated that generates unique tags before
        // requests reach the PCIe SS. In ASE there is none -- hence the use here only
        // in simulation. The tag mapper does not require unique tags on the AFU side.
        //
        // Using the same tag for split requests makes it easy to reassociate split
        // completions with the original large AFU read request.
        //
        pcie_ss_axis_if tx_map_if[2](uclk_usr, uclk_rst_n);
        pcie_ss_axis_if rx_a_if(uclk_usr, uclk_rst_n);
        pcie_ss_axis_if rx_b_if(uclk_usr, uclk_rst_n);
        pcie_ss_axis_if tx_a_if(uclk_usr, uclk_rst_n);
        pcie_ss_axis_if tx_b_if(uclk_usr, uclk_rst_n);

        pcie_ss_axis_pkg::t_pcie_tag_mode tag_mode;
        always_comb begin
            tag_mode = '0;
            tag_mode.tag_8bit = 1'b1;
        end

        tag_remap_multi_tx
          #(
`ifdef SIM_MODE
            .REMAP(1),
`else
            .REMAP(0),
`endif
            .N_TX_PORTS(2)
            )
          tag_mapper
           (
            .clk(uclk_usr),
            .rst_n(uclk_rst_n),
            .ho2mx_rx_port(rx_a_uclk_if),
            .mx2ho_tx_port(tx_uclk_if),
            .ho2mx_rx_remap(rx_a_if),
            .mx2ho_tx_remap(tx_map_if),
            .tag_mode
            );

        // Connect mapper ports to AFU interfaces
        axis_pipeline #(.PL_DEPTH(0)) conn_rx_b (.clk(uclk_usr), .rst_n(uclk_rst_n), .axis_s(rx_b_uclk_if), .axis_m(rx_b_if));
        axis_pipeline #(.PL_DEPTH(0)) conn_tx_a (.clk(uclk_usr), .rst_n(uclk_rst_n), .axis_s(tx_a_if), .axis_m(tx_map_if[0]));
        axis_pipeline #(.PL_DEPTH(0)) conn_tx_b (.clk(uclk_usr), .rst_n(uclk_rst_n), .axis_s(tx_b_if), .axis_m(tx_map_if[1]));


        //
        // Split RX completions into a separate stream, leaving only incoming
        // requests on rx_a.
        //
        logic rx_a_sop;
        logic rx_a_is_cpl, rx_a_is_cpl_q;
        pcie_ss_axis_if rx_cpl_if(uclk_usr, uclk_rst_n);
        pcie_ss_axis_if rx_a_other_if(uclk_usr, uclk_rst_n);

        // fmt_type is in the same position for both PU and DM encoded completions
        pcie_ss_hdr_pkg::PCIe_CplHdr_t rx_a_dm_hdr;
        assign rx_a_dm_hdr = pcie_ss_hdr_pkg::PCIe_CplHdr_t'(rx_a_if.tdata);
        assign rx_a_is_cpl = rx_a_sop ? pcie_ss_hdr_pkg::func_is_completion(rx_a_dm_hdr.fmt_type) :
                                        rx_a_is_cpl_q;

        always_ff @(posedge uclk_usr) begin
            if (rx_a_if.tvalid && rx_a_if.tready) begin
                rx_a_sop <= rx_a_if.tlast;
                rx_a_is_cpl_q <= rx_a_is_cpl;
            end

            if (!uclk_rst_n) begin
                rx_a_sop <= 1'b1;
                rx_a_is_cpl_q <= 1'b0;
            end
        end

        logic rx_cpl_tready, rx_a_other_tready;
        assign rx_a_if.tready = rx_a_is_cpl ? rx_cpl_tready : rx_a_other_tready;

        // Filter out completions into rx_cpl_if
        ofs_plat_prim_ready_enable_skid
          #(
            .N_DATA_BITS(AXIS_WIDTH)
            )
          cpl_skid
           (
            .clk(uclk_usr),
            .reset_n(uclk_rst_n),

            .enable_from_src(rx_a_if.tvalid && rx_a_is_cpl),
            .data_from_src({ rx_a_if.tlast, rx_a_if.tuser_vendor, rx_a_if.tdata, rx_a_if.tkeep }),
            .ready_to_src(rx_cpl_tready),

            .enable_to_dst(rx_cpl_if.tvalid),
            .data_to_dst({ rx_cpl_if.tlast, rx_cpl_if.tuser_vendor, rx_cpl_if.tdata, rx_cpl_if.tkeep }),
            .ready_from_dst(rx_cpl_if.tready)
            );

        // Everything else to rx_a_other_if
        ofs_plat_prim_ready_enable_skid
          #(
            .N_DATA_BITS(AXIS_WIDTH)
            )
          other_skid
           (
            .clk(uclk_usr),
            .reset_n(uclk_rst_n),

            .enable_from_src(rx_a_if.tvalid && !rx_a_is_cpl),
            .data_from_src({ rx_a_if.tlast, rx_a_if.tuser_vendor, rx_a_if.tdata, rx_a_if.tkeep }),
            .ready_to_src(rx_a_other_tready),

            .enable_to_dst(rx_a_other_if.tvalid),
            .data_to_dst({ rx_a_other_if.tlast, rx_a_other_if.tuser_vendor, rx_a_other_if.tdata, rx_a_other_if.tkeep }),
            .ready_from_dst(rx_a_other_if.tready)
            );

        dm_large_req_afu
          #(
            .INSTANCE_ID(j),
            .PF_ID(PORT_PF_VF_INFO[j].pf_num),
            .VF_ID(PORT_PF_VF_INFO[j].vf_num),
            .VF_ACTIVE(PORT_PF_VF_INFO[j].vf_active)
            )
          top
            (
             .clk(uclk_usr),
             .rst_n(uclk_rst_n),
             .rx_a_if(rx_a_other_if),
             .rx_b_if,
             .i_rx_cpl_if(rx_cpl_if),
             .o_tx_a_if(tx_a_if),
             .o_tx_b_if(tx_b_if)
             );
    end


    // ======================================================
    // Tie off unused local memory
    // ======================================================

    for (genvar c = 0; c < NUM_MEM_CH; c++) begin : mb
      `ifdef INCLUDE_DDR4
        assign ext_mem_if[c].awvalid = 1'b0;
        assign ext_mem_if[c].wvalid = 1'b0;
        assign ext_mem_if[c].arvalid = 1'b0;
        assign ext_mem_if[c].bready = 1'b1;
        assign ext_mem_if[c].rready = 1'b1;
      `endif

      `ifdef PLATFORM_FPGA_FAMILY_S10
        assign ext_mem_if[c].write = 1'b0;
        assign ext_mem_if[c].read = 1'b0;
      `endif
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
  `ifdef INCLUDE_PTP
    for (genvar c=0; c<MAX_ETH_CH; c++) begin : hssi
        assign hssi_ptp_tx_egrts[c].tvalid = 1'b0;
        assign hssi_ptp_rx_ingrts[c].tvalid = 1'b0;
    end
  `endif

endmodule : port_afu_instances

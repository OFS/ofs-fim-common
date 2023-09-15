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
  `ifdef INCLUDE_HSSI
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

    // Load CPL_CHAN and WR_COMMIT_CHAN
    import ofs_pcie_ss_cfg_pkg::*;

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

    //
    // Instantiate separate copies of the engine on each AFU port.
    //
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

        pcie_ss_axis_if rx_a_if(uclk_usr, uclk_rst_n);
        pcie_ss_axis_if rx_b_if(uclk_usr, uclk_rst_n);
        pcie_ss_axis_if tx_a_if(uclk_usr, uclk_rst_n);
        pcie_ss_axis_if tx_b_if(uclk_usr, uclk_rst_n);

        localparam AXIS_WIDTH = 1 + $bits(rx_a_if.tuser_vendor) +
                                $bits(rx_a_if.tdata) + $bits(rx_a_if.tkeep);

        `PCIE_AXIS_CLK_CROSSING(0, rx_a, AXIS_WIDTH, afu_axi_rx_a_if[j], rx_a_if);
        `PCIE_AXIS_CLK_CROSSING(0, rx_b, AXIS_WIDTH, afu_axi_rx_b_if[j], rx_b_if);
        `PCIE_AXIS_CLK_CROSSING(1, tx_a, AXIS_WIDTH, tx_a_if, afu_axi_tx_a_if[j]);
        `PCIE_AXIS_CLK_CROSSING(1, tx_b, AXIS_WIDTH, tx_b_if, afu_axi_tx_b_if[j]);


        // ================================================================
        //
        //  Depending on the FIM configuration, read completions and write
        //  commit messages may be found on either RX-A or RX-B. The
        //  location is static -- either RX-A or RX-B, but not both.
        //  Furthermore, only one of the classes may be on RX-B in a given
        //  FIM.
        //
        //  The code below maps RX traffic to the proper place given the
        //  compile-time FIM parameters.
        //
        // ================================================================

        //
        // Split RX completions into separate streams for MMIO, read
        // completions and write commits.
        //
        pcie_ss_axis_if rx_mmio_if(uclk_usr, uclk_rst_n);
        pcie_ss_axis_if rx_cpl_if(uclk_usr, uclk_rst_n);
        pcie_ss_axis_if rx_commit_if(uclk_usr, uclk_rst_n);

        logic rx_a_sop;
        bit rx_a_is_cpl, rx_a_is_cpl_q;
        bit rx_a_cpl_is_commit;

        // fmt_type is in the same position for both PU and DM encoded completions
        pcie_ss_hdr_pkg::PCIe_CplHdr_t rx_a_dm_hdr;
        assign rx_a_dm_hdr = pcie_ss_hdr_pkg::PCIe_CplHdr_t'(rx_a_if.tdata);
        assign rx_a_is_cpl = rx_a_sop ? pcie_ss_hdr_pkg::func_is_completion(rx_a_dm_hdr.fmt_type) :
                                        rx_a_is_cpl_q;
        // Read completions have data. Write commits do not and have only an SOP beat.
        assign rx_a_cpl_is_commit = rx_a_sop && !pcie_ss_hdr_pkg::func_has_data(rx_a_dm_hdr.fmt_type);

        always_ff @(posedge uclk_usr) begin
            if (rx_a_if.tvalid && rx_a_if.tready) begin
                rx_a_sop <= rx_a_if.tlast;
                rx_a_is_cpl_q <= rx_a_is_cpl && !rx_a_if.tlast;
            end

            if (!uclk_rst_n) begin
                rx_a_sop <= 1'b1;
                rx_a_is_cpl_q <= 1'b0;
            end
        end

        // RX-A may be forwarded to one of three places: read completions, write
        // commits (completions without data) and MMIO requests. Whether read
        // completions and write commits are on RX-A or RX-B depends on the FIM
        // configuration.
        logic rx_mmio_tready, rx_cpl_tready, rx_commit_tready;
        assign rx_a_if.tready =
                 rx_mmio_tready &&
                 ((CPL_CHAN == PCIE_CHAN_A) ? (rx_cpl_tready || !rx_a_is_cpl || rx_a_cpl_is_commit) : 1'b1) &&
                 ((WR_COMMIT_CHAN == PCIE_CHAN_A) ? (rx_commit_tready || !rx_a_is_cpl || !rx_a_cpl_is_commit) : 1'b1);

        // synthesis translate_off
        always_ff @(posedge uclk_usr)
        begin
            if (uclk_rst_n && rx_a_if.tvalid && rx_a_if.tready && rx_a_sop) begin
                // Trigger errors if a read completion or write commit is seen on
                // RX-A but is expected on RX-B.
                if (rx_a_is_cpl) begin
                    if (!rx_a_cpl_is_commit) begin
                        assert(CPL_CHAN == PCIE_CHAN_A) else
                          $fatal(2, "** ERROR ** %m: Unexpected read completion on RX-A!");
                    end
                    else begin
                        assert(WR_COMMIT_CHAN == PCIE_CHAN_A) else
                          $fatal(2, "** ERROR ** %m: Unexpected write commit on RX-A!");
                    end
                end
            end
        end
        // synthesis translate_on

        // Move read completions to rx_cpl_if
        if (CPL_CHAN == PCIE_CHAN_A)
        begin : cpl_a
            // The FIM is configured with completions on RX-A
            ofs_plat_prim_ready_enable_skid
              #(
                .N_DATA_BITS(AXIS_WIDTH)
                )
              cpl_skid
               (
                .clk(uclk_usr),
                .reset_n(uclk_rst_n),

                .enable_from_src(rx_a_if.tvalid && rx_a_is_cpl && !rx_a_cpl_is_commit),
                .data_from_src({ rx_a_if.tlast, rx_a_if.tuser_vendor, rx_a_if.tdata, rx_a_if.tkeep }),
                .ready_to_src(rx_cpl_tready),

                .enable_to_dst(rx_cpl_if.tvalid),
                .data_to_dst({ rx_cpl_if.tlast, rx_cpl_if.tuser_vendor, rx_cpl_if.tdata, rx_cpl_if.tkeep }),
                .ready_from_dst(rx_cpl_if.tready)
                );
        end
        else
        begin : cpl_b
            // The FIM is configured with completions on RX-B.
            // Only completions will be on this stream.
            ofs_plat_prim_ready_enable_skid
              #(
                .N_DATA_BITS(AXIS_WIDTH)
                )
              cpl_skid
               (
                .clk(uclk_usr),
                .reset_n(uclk_rst_n),

                .enable_from_src(rx_b_if.tvalid),
                .data_from_src({ rx_b_if.tlast, rx_b_if.tuser_vendor, rx_b_if.tdata, rx_b_if.tkeep }),
                .ready_to_src(rx_b_if.tready),

                .enable_to_dst(rx_cpl_if.tvalid),
                .data_to_dst({ rx_cpl_if.tlast, rx_cpl_if.tuser_vendor, rx_cpl_if.tdata, rx_cpl_if.tkeep }),
                .ready_from_dst(rx_cpl_if.tready)
                );

            assign rx_cpl_tready = 1'b1;
        end

        if (WR_COMMIT_CHAN == PCIE_CHAN_A)
        begin : wr_commit_a
            // The FIM is configured with completions on RX-A
            ofs_plat_prim_ready_enable_skid
              #(
                .N_DATA_BITS(AXIS_WIDTH)
                )
              wr_commit_skid
               (
                .clk(uclk_usr),
                .reset_n(uclk_rst_n),

                .enable_from_src(rx_a_if.tvalid && rx_a_is_cpl && rx_a_cpl_is_commit),
                .data_from_src({ rx_a_if.tlast, rx_a_if.tuser_vendor, rx_a_if.tdata, rx_a_if.tkeep }),
                .ready_to_src(rx_commit_tready),

                .enable_to_dst(rx_commit_if.tvalid),
                .data_to_dst({ rx_commit_if.tlast, rx_commit_if.tuser_vendor, rx_commit_if.tdata, rx_commit_if.tkeep }),
                .ready_from_dst(rx_commit_if.tready)
                );
        end
        else
        begin : wr_commit_b
            // The FIM is configured with completions on RX-B.
            // Only completions will be on this stream.
            ofs_plat_prim_ready_enable_skid
              #(
                .N_DATA_BITS(AXIS_WIDTH)
                )
              wr_commit_skid
               (
                .clk(uclk_usr),
                .reset_n(uclk_rst_n),

                .enable_from_src(rx_b_if.tvalid),
                .data_from_src({ rx_b_if.tlast, rx_b_if.tuser_vendor, rx_b_if.tdata, rx_b_if.tkeep }),
                .ready_to_src(rx_b_if.tready),

                .enable_to_dst(rx_commit_if.tvalid),
                .data_to_dst({ rx_commit_if.tlast, rx_commit_if.tuser_vendor, rx_commit_if.tdata, rx_commit_if.tkeep }),
                .ready_from_dst(rx_commit_if.tready)
                );

            assign rx_commit_tready = 1'b1;
        end

        // Everything else to rx_mmio_if
        ofs_plat_prim_ready_enable_skid
          #(
            .N_DATA_BITS(AXIS_WIDTH)
            )
          mmio_skid
           (
            .clk(uclk_usr),
            .reset_n(uclk_rst_n),

            .enable_from_src(rx_a_if.tvalid && !rx_a_is_cpl),
            .data_from_src({ rx_a_if.tlast, rx_a_if.tuser_vendor, rx_a_if.tdata, rx_a_if.tkeep }),
            .ready_to_src(rx_mmio_tready),

            .enable_to_dst(rx_mmio_if.tvalid),
            .data_to_dst({ rx_mmio_if.tlast, rx_mmio_if.tuser_vendor, rx_mmio_if.tdata, rx_mmio_if.tkeep }),
            .ready_from_dst(rx_mmio_if.tready)
            );


        if ((CPL_CHAN == PCIE_CHAN_A) && (WR_COMMIT_CHAN == PCIE_CHAN_A))
        begin : tie_b
            // Nothing on RX-B in this FIM
            assign rx_b_if.tready = 1'b1;
        end


        //
        // Finally -- instantiate the AFU.
        //
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
             .rx_mmio_if(rx_mmio_if),
             .o_tx_a_if(tx_a_if),
             .o_tx_b_if(tx_b_if),
             .i_rx_cpl_if(rx_cpl_if),
             .i_rx_wr_commit_if(rx_commit_if)
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

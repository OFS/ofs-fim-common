// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
// -----------------------------------------------------------------------------
//
// The PIM version of the standard exercisers. It instantiates exercisers,
// similar to the non-PIM afu_main(), but uses the PIM interface.
//
// Unlike most PIM-based AFUs, the code here uses the platform-specific
// FIM interfaces. The code is mostly useful as a test that the basic
// transformations to PIM data-structures are working. The code here isn't
// particularly useful as an example of a valuable use of the PIM.
//
// -----------------------------------------------------------------------------

`include "ofs_plat_if.vh"

module ofs_plat_afu (
   // All platform wires, wrapped in one interface.
   ofs_plat_if plat_ifc
);

   // How many PCIe ports will the AFU use? (Any extras will be tied off by
   // the PIM.)
   localparam NUM_PCIE_PORTS = 1;

   localparam FIM_PCIE_SEG_WIDTH =  ofs_pcie_ss_cfg_pkg::TDATA_WIDTH /
                                    ofs_pcie_ss_cfg_pkg::NUM_OF_SEG;
   // Segment width in bytes (useful for indexing tkeep as valid bits)
   localparam FIM_PCIE_SEG_BYTES = FIM_PCIE_SEG_WIDTH / 8;

   // Construct vectors of PCIe port clocks and resets, required when
   // constructing the AXI interfaces.
   logic host_chan_clk [NUM_PCIE_PORTS];
   logic host_chan_reset_n [NUM_PCIE_PORTS];

   generate
      for (genvar p = 0; p < NUM_PCIE_PORTS; p = p + 1)
      begin : pc
         assign host_chan_clk[p] = plat_ifc.host_chan.ports[p].clk;
         assign host_chan_reset_n[p] = plat_ifc.host_chan.ports[p].reset_n;
      end
   endgenerate

   pcie_ss_axis_if afu_axi_rx_if[NUM_PCIE_PORTS](host_chan_clk, host_chan_reset_n);
   pcie_ss_axis_if afu_axi_tx_if[NUM_PCIE_PORTS](host_chan_clk, host_chan_reset_n);
   logic afu_axi_tx_is_sop [NUM_PCIE_PORTS];

   //
   // Map PIM ports to pcie_ss_axis_if.
   //
   generate
      for (genvar p = 0; p < NUM_PCIE_PORTS; p = p + 1)
      begin : pm
         //
         // RX (host->AFU)
         //
         assign plat_ifc.host_chan.ports[p].afu_rx_st.tready = afu_axi_rx_if[p].tready;
         assign afu_axi_rx_if[p].tvalid = plat_ifc.host_chan.ports[p].afu_rx_st.tvalid;

         always_comb
         begin
            afu_axi_rx_if[p].tlast = plat_ifc.host_chan.ports[p].afu_rx_st.t.last;
            afu_axi_rx_if[p].tdata = plat_ifc.host_chan.ports[p].afu_rx_st.t.data;
            afu_axi_rx_if[p].tkeep = plat_ifc.host_chan.ports[p].afu_rx_st.t.keep;

            // The PIM interface describes tuser_vendor bits explicitly. Only bit
            // 0 (DM vs. PU mode) is currently passed through.
            afu_axi_rx_if[p].tuser_vendor = '0;
            afu_axi_rx_if[p].tuser_vendor[0] = plat_ifc.host_chan.ports[p].afu_rx_st.t.user[0].dm_mode;
         end


         //
         // TX (AFU->host)
         //
         assign afu_axi_tx_if[p].tready = plat_ifc.host_chan.ports[p].afu_tx_st.tready;
         assign plat_ifc.host_chan.ports[p].afu_tx_st.tvalid = afu_axi_tx_if[p].tvalid;

         always_comb
         begin
            plat_ifc.host_chan.ports[p].afu_tx_st.t.last = afu_axi_tx_if[p].tlast;
            plat_ifc.host_chan.ports[p].afu_tx_st.t.data = afu_axi_tx_if[p].tdata;
            plat_ifc.host_chan.ports[p].afu_tx_st.t.keep = afu_axi_tx_if[p].tkeep;

            plat_ifc.host_chan.ports[p].afu_tx_st.t.user = '0;
            plat_ifc.host_chan.ports[p].afu_tx_st.t.user[0].dm_mode = afu_axi_tx_if[p].tuser_vendor[0];

            // The PIM adds explicit SOP/EOP encoding
            plat_ifc.host_chan.ports[p].afu_tx_st.t.user[0].sop = afu_axi_tx_is_sop[p];

            // Mark at most one EOP. Find the highest segment with a payload and
            // set its EOP bit, using tlast. tlast is currently the only header
            // indicator in the FIM's PCIe SS configuration.
            for (int s = ofs_pcie_ss_cfg_pkg::NUM_OF_SEG - 1; s >= 0; s = s - 1)
            begin
               if (afu_axi_tx_if[p].tkeep[s * FIM_PCIE_SEG_BYTES])
               begin
                  plat_ifc.host_chan.ports[p].afu_tx_st.t.user[0].eop = afu_axi_tx_if[p].tlast;
                  break;
               end
            end
         end

         // Track TX SOP
         always_ff @(posedge plat_ifc.host_chan.ports[p].clk)
         begin
            if (afu_axi_tx_if[p].tready && afu_axi_tx_if[p].tvalid)
            begin
               afu_axi_tx_is_sop[p] <= afu_axi_tx_if[p].tlast;
            end

            if (!plat_ifc.host_chan.ports[p].reset_n)
            begin
               afu_axi_tx_is_sop[p] <= 1'b1;
            end
         end
      end
   endgenerate

   // Dummy memory interface (not connected)
   ofs_axi_mm_if he_lb_ext_mem_dummy();

   // Dummy HE-LB CSR interface (not connected)
   ofs_fim_axi_lite_if #(.AWADDR_WIDTH(he_lb_pkg::CSR_AW),
                         .ARADDR_WIDTH(he_lb_pkg::CSR_AW)) he_lb_csr_if_dummy ();       

   //
   // Intantiate simple loopback interface to PCIe port 0
   //
   he_lb_top #(
      .PF_ID(top_cfg_pkg::PG_AFU_PORTS_PF_NUM[0]),
      .VF_ID(top_cfg_pkg::PG_AFU_PORTS_VF_NUM[0]),
      .VF_ACTIVE(top_cfg_pkg::PG_AFU_PORTS_VF_ACTIVE[0]),
      .SPLIT_RSP(1),
      .EMIF(0),
      // Use power user encoding in this instance
      .PU_MEM_REQ(1)
   ) he_lb_inst (
      .clk(afu_axi_tx_if[0].clk),
      // The PIM's port reset_n already includes soft reset
      .SoftReset(!afu_axi_tx_if[0].rst_n),
      .axi_rx_if(afu_axi_rx_if[0]),
      .axi_tx_if(afu_axi_tx_if[0]),
      .ext_mem_if(he_lb_ext_mem_dummy),
      .csr_if(he_lb_csr_if_dummy)
   );


   // ====================================================================
   //
   //  Tie off unused ports.
   //
   // ====================================================================

   ofs_plat_if_tie_off_unused #(
      // Masks are bit masks, with bit 0 corresponding to port/bank zero.
      // Set a bit in the mask when a port is IN USE by the design.
      // This way, the AFU does not need to know about every available
      // device. By default, devices are tied off.

      // Used 1 AFU port
      .HOST_CHAN_IN_USE_MASK(1)
   ) tie_off (plat_ifc);

endmodule // ofs_plat_afu


// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT

//
// Ensure that only one completion for a split completion has the FC bit
// set. When completions are split, the same tag is used throughput. The
// FIM's tag mapper ensures that unique tags reach the PCIe SS.
//

module ofs_fim_pcie_dm_rx_rd_splitter
  #(
    // One DM metadata bit is used to mark split requests. Pick any bit
    // from 0 to 64.
    parameter DM_METADATA_BIT = 63
    )
   (
    // FIM-side connection
    pcie_ss_axis_if.sink   i_rx_cpl_if,
    // Original value of the metadata bit
    input  logic i_rx_meta_orig,

    // AFU-side connection
    pcie_ss_axis_if.source o_rx_cpl_if
    );

    // All interfaces are in the same clock domain
    wire clk = i_rx_cpl_if.clk;
    wire rst_n = i_rx_cpl_if.rst_n;

    localparam DM_METADATA_SAFE_BIT = DM_METADATA_BIT & 31;

    logic rx_sop;
    pcie_ss_hdr_pkg::PCIe_CplHdr_t i_rx_hdr;
    assign i_rx_hdr = pcie_ss_hdr_pkg::PCIe_CplHdr_t'(i_rx_cpl_if.tdata);
    pcie_ss_hdr_pkg::PCIe_CplHdr_t o_rx_hdr;

    always_comb begin
        i_rx_cpl_if.tready = o_rx_cpl_if.tready;
        o_rx_cpl_if.tvalid = i_rx_cpl_if.tvalid;
        o_rx_cpl_if.tlast = i_rx_cpl_if.tlast;
        o_rx_cpl_if.tuser_vendor = i_rx_cpl_if.tuser_vendor;
        o_rx_cpl_if.tkeep = i_rx_cpl_if.tkeep;
        o_rx_cpl_if.tdata = i_rx_cpl_if.tdata;

        o_rx_hdr = i_rx_hdr;
        if (rx_sop && pcie_ss_hdr_pkg::func_hdr_is_dm_mode(i_rx_cpl_if.tuser_vendor) &&
            pcie_ss_hdr_pkg::func_is_completion(i_rx_hdr.fmt_type))
        begin
            o_rx_hdr.FC = i_rx_hdr.FC &
                ((DM_METADATA_BIT >= 32) ? i_rx_hdr.metadata_h[DM_METADATA_SAFE_BIT] :
                                           i_rx_hdr.metadata_l[DM_METADATA_SAFE_BIT]);

            // Restore the metadata bit
            if (DM_METADATA_BIT >= 3)
                o_rx_hdr.metadata_h[DM_METADATA_SAFE_BIT] = i_rx_meta_orig;
            else
                o_rx_hdr.metadata_l[DM_METADATA_SAFE_BIT] = i_rx_meta_orig;
        end

        o_rx_cpl_if.tdata[$bits(o_rx_hdr)-1 : 0] = o_rx_hdr;
    end

    always_ff @(posedge clk)
    begin
        if (i_rx_cpl_if.tvalid && i_rx_cpl_if.tready) begin
            rx_sop <= i_rx_cpl_if.tlast;
        end

        if (!rst_n) begin
            rx_sop <= 1'b1;
        end
    end

endmodule // ofs_fim_pcie_dm_rx_rd_splitter

// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// -----------------------------------------------------------------------------

//
// Configuration of the PCIe subsystem.
//
// This is the common PCIe configuration package, available on all platforms.
// It imports values from platform-specific configuration packages.
//
// The majority of code should import this package and not the platform-
// specific versions. Using this common package enforces consistency across
// platform-specific configuration.
//

`include "ofs_pcie_ss_cfg.vh"

package ofs_pcie_ss_cfg_pkg;

    // OFS has two PCIe TX and two RX streams, named "A" and "B". This enumeration
    // may be used to specify an A or B channel, with TX vs. RX implied by context.
    typedef enum bit[0:0] {
        PCIE_CHAN_A,
        PCIE_CHAN_B
    } e_pcie_chan;

    // Payload width
    localparam TDATA_WIDTH = ofs_pcie_ss_plat_cfg_pkg::TDATA_WIDTH;

    // Width of the PCIe SS's tuser_vendor field
    localparam TUSER_VENDOR_WIDTH = ofs_pcie_ss_plat_cfg_pkg::TUSER_VENDOR_WIDTH;
    // Width of the FIM's tuser field, when encoded with OFS-specific
    // state. If present, tuser_vendor bits are placed in the low bits
    // of tuser.
    localparam TUSER_WIDTH = TUSER_VENDOR_WIDTH;

    // TUSER flags
    //   PCIe data mover encoded when 1
    localparam TUSER_DM_ENCODING_BIT = 0;
    //   When this tuser bit is set, the FIM generates store and
    //   interrupt commit messages at the point that the request
    //   is ordered entering the PCIe SS. Before the commit point,
    //   the relative order of requests on TX-A and TX-B is not fixed.
    //   Commits are encoded as completions without data and are
    //   delivered on the channel indicated by WR_COMMIT_CHAN below.
    //   Any read request following a commit is guaranteed to enter
    //   the PCIe SS after the original write.
    //
    //   Before WR_COMMIT_CHAN was added below, the bit here was called
    //   TUSER_NO_STORE_COMMIT_MSG_BIT and the sense was inverted.
    //   Local commits were always generated and returned on RX-B
    //   unless the bit was set. With the addition of WR_COMMIT_CHAN
    //   and ordered read completions, local commits were moved to RX-A.
    //   The default (0) here was changed NOT to generate commits. AFUs
    //   that do not expect commits can no longer simply ignore RX-B
    //   and have to filter out dataless completions on RX-A. By
    //   switching the bit, only AFUs actually expecting commits had to
    //   change. These AFUs had to be updated anyway, since the commits
    //   may now be on RX-A. (The change happened in Feb. 2023.)
    localparam TUSER_STORE_COMMIT_REQ_BIT = TUSER_WIDTH - 1;

    // Maximum read request size (AFU reading host memory)
    localparam MAX_RD_REQ_BYTES = ofs_pcie_ss_plat_cfg_pkg::MAX_RD_REQ_BYTES;
    // Maximum write payload size (AFU writing host memory)
    localparam MAX_WR_PAYLOAD_BYTES = ofs_pcie_ss_plat_cfg_pkg::MAX_WR_PAYLOAD_BYTES;

    // Maximum number of SOP (TLP header starts) in tdata. Even when
    // NUM_OF_SOP is 1, the single header may start at a tdata bit other
    // than bit 0 if NUM_OF_SEG is greater than 1.
    localparam NUM_OF_SOP = ofs_pcie_ss_plat_cfg_pkg::NUM_OF_SOP;

    // Number of segments in tdata, divided into equal size ranges.
    // An SOP (TLP header) may be placed at any segment boundary.
    localparam NUM_OF_SEG = ofs_pcie_ss_plat_cfg_pkg::NUM_OF_SEG;

    // Maximum number of FPGA->host AFU tags. AFU tags must must be less than
    // this. This tag space is managed by the FIM, using the tag remapper.
    // Consequently, tags do not have to conform the the PCIe standard and
    // do not have to conform to the dynamic state of the PCIe HIP. Even
    // in 10 bit mode, tag values in the range 0-255 remain legal. The FIM's
    // tag remapper will guarantee that actual tags reaching the PCIe SS are
    // valid.
    localparam PCIE_EP_MAX_TAGS = ofs_pcie_ss_plat_cfg_pkg::PCIE_EP_MAX_TAGS;
    // Maximum number of host->FPGA tags. (Tag values will be less than this.)
    localparam PCIE_RP_MAX_TAGS = ofs_pcie_ss_plat_cfg_pkg::PCIE_RP_MAX_TAGS;

    // Used only by the FIM's tag remapper, this is the maximum number of
    // tags accepted by the physical PCIe tile. It is the count of legal tags,
    // not the maximum value. E.g., a HIP that limits 10 bit tags to 256-767
    // would have a value of 512.
    localparam PCIE_TILE_MAX_TAGS = ofs_pcie_ss_plat_cfg_pkg::PCIE_TILE_MAX_TAGS;

    // Are completions reordered by the PCIe SS? Set to either 0 (disabled)
    // or 1 (enabled).
    localparam CPL_REORDER_EN = `OFS_PCIE_SS_CFG_FLAG_CPL_REORDER;

    // RX channel used for read completions
    localparam e_pcie_chan CPL_CHAN = `OFS_PCIE_SS_CFG_FLAG_CPL_CHAN;

    // RX channel used for FIM-generated write commits
    localparam e_pcie_chan WR_COMMIT_CHAN = `OFS_PCIE_SS_CFG_FLAG_WR_COMMIT_CHAN;

    // Number of independent AXI streams exposed by the PCIe controller and
    // FIM. Parallel streams are logically independent, each configured
    // separately with the WIDTH, SOP and SEG parameters above. The PCIe
    // subsystem merges the streams before passing requests to the HIP.
    localparam NUM_OF_STREAMS = ofs_pcie_ss_plat_cfg_pkg::NUM_OF_STREAMS;

endpackage // ofs_pcie_ss_cfg_pkg

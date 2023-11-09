// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Configuration of the PCIe subsystem.
//
// This .vh file, associated with the ofs_pcie_ss_cfg_pkg::, may be used
// for managing updates to parameters imported from platform-specific versions
// of the configuration package. Macros may indicate the version number
// of a platform-specific implementation, which can then be used to
// set suitable defaults in ofs_pcie_ss_cfg_pkg:: without having to
// update old platforms.
//

`ifndef __OFS_PCIE_SS_CFG_VH__
`define __OFS_PCIE_SS_CFG_VH__ 1

// Include the platform-specific version of this file.
`include "ofs_pcie_ss_plat_cfg.vh"

//
// Map some well-known names from platform-specific to global. This syntactic
// sugar enforced a common namespace across platforms.
//

// Defined when ofs_pcie_ss_cfg_pkg::TUSER_STORE_COMMIT_REQ_BIT is available.
`define OFS_PCIE_SS_CFG_FLAG_TUSER_STORE_COMMIT_REQ 1

// Primarily, this flag indicates that ofs_pcie_ss_cfg_pkg::CPL_REORDER_EN
// is defined. The macro also indicates whether completion reordering is
// enabled in the PCIe SS, set to either 0 (disabled) or 1 (enabled).
`ifdef OFS_PCIE_SS_PLAT_CFG_FLAG_CPL_REORDER
  `define OFS_PCIE_SS_CFG_FLAG_CPL_REORDER `OFS_PCIE_SS_PLAT_CFG_FLAG_CPL_REORDER
`else
  // Default
  `define OFS_PCIE_SS_CFG_FLAG_CPL_REORDER 0
`endif

// Which RX channel is used for read completions?
`ifdef OFS_PCIE_SS_PLAT_CFG_FLAG_CPL_CHAN
  `define OFS_PCIE_SS_CFG_FLAG_CPL_CHAN `OFS_PCIE_SS_PLAT_CFG_FLAG_CPL_CHAN
`else
  // Default
  `define OFS_PCIE_SS_CFG_FLAG_CPL_CHAN ofs_pcie_ss_cfg_pkg::PCIE_CHAN_A
`endif

// Which RX channel is used for FIM-generated write commits?
`ifdef OFS_PCIE_SS_PLAT_CFG_FLAG_WR_COMMIT_CHAN
  `define OFS_PCIE_SS_CFG_FLAG_WR_COMMIT_CHAN `OFS_PCIE_SS_PLAT_CFG_FLAG_WR_COMMIT_CHAN
`else
  // Default
  `define OFS_PCIE_SS_CFG_FLAG_WR_COMMIT_CHAN ofs_pcie_ss_cfg_pkg::PCIE_CHAN_B
`endif

`endif // __OFS_PCIE_SS_CFG_VH__

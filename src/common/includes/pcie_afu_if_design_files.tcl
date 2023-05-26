## Copyright 2020 Intel Corporation
## SPDX-License-Identifier: MIT

#
# PCIe interfaces passed to AFUs. These files are used by both FIM and PR builds.
#

#--------------------
# Common packages
#--------------------
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/includes/ofs_pcie_ss_cfg_pkg.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/includes/pcie_ss_hdr_pkg.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/includes/pcie_ss_pkg.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/includes/pcie_ss_axis_pkg.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/includes/pcie_ss_axis_if.sv

## Copyright (C) 2023 Intel Corporation
## SPDX-License-Identifier: MIT

##
## Load the subset of interfaces and modules required for AFUs inside the port
## gasket. This is the minimal set of sources loaded when generating the
## out-of-tree PR build environment.
##

set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/sys_pll/sys_pll_pkg.sv

if { [::config_env::verilog_macro_defined INCLUDE_REMOTE_STP] } {
    set_global_assignment -name IP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/remote_stp/AFU_debug/config_reset_release.ip
    set_global_assignment -name IP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/remote_stp/AFU_debug/scjio_agilex.ip
}

if { [::config_env::verilog_macro_defined INCLUDE_JTAG_PR_STP] } {
    set_global_assignment -name IP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/jtag_pr_stp/AFU_debug/jtag_pr_sld_host.ip
    set_global_assignment -name IP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/jtag_pr_stp/AFU_debug/jtag_pr_reset_release_endpoint.ip
}

#--------------------
# Memory Application user interface files
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/mem_ss/mem_afu_if_design_files.tcl

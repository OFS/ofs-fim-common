## Copyright (C) 2023 Intel Corporation
## SPDX-License-Identifier: MIT

#--------------------
# JTAG PR STP
#--------------------
if { [::config_env::verilog_macro_defined INCLUDE_JTAG_PR_STP] } {
    set_global_assignment -name IP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/jtag_pr_stp/ip/jtag_pr_sld_agent.ip
    set_global_assignment -name IP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/jtag_pr_stp/ip/jtag_pr_reset_release.ip
    set_global_assignment -name IP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/jtag_pr_stp/AFU_debug/jtag_pr_sld_host.ip
    set_global_assignment -name IP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/jtag_pr_stp/AFU_debug/jtag_pr_reset_release_endpoint.ip
}

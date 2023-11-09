## Copyright (C) 2023 Intel Corporation
## SPDX-License-Identifier: MIT

#--------------------
# JTAG PR STP
#--------------------
set_global_assignment -name IP_FILE   $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/jtag_pr_stp/ip/jtag_pr_sld_agent.ip
set_global_assignment -name IP_FILE   $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/jtag_pr_stp/ip/jtag_pr_reset_release.ip
set_global_assignment -name IP_FILE   $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/jtag_pr_stp/AFU_debug/jtag_pr_sld_host.ip
set_global_assignment -name IP_FILE   $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/jtag_pr_stp/AFU_debug/jtag_pr_reset_release_endpoint.ip

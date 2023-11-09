## Copyright (C) 2023 Intel Corporation
## SPDX-License-Identifier: MIT
#--------------------
# Remote STP
#--------------------
set_global_assignment -name IP_FILE   $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/remote_stp/ip/remote_debug_jtag_only/remote_debug_jtag_only_clock_in.ip
set_global_assignment -name IP_FILE   $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/remote_stp/ip/remote_debug_jtag_only/host_if.ip
set_global_assignment -name IP_FILE   $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/remote_stp/ip/remote_debug_jtag_only/jop_blaster.ip
set_global_assignment -name IP_FILE   $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/remote_stp/ip/remote_debug_jtag_only/remote_debug_jtag_only_reset_in.ip
set_global_assignment -name IP_FILE   $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/remote_stp/ip/remote_debug_jtag_only/sys_clk.ip
set_global_assignment -name QSYS_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/remote_stp/remote_debug_jtag_only.qsys
set_global_assignment -name IP_FILE   $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/remote_stp/AFU_debug/config_reset_release.ip
set_global_assignment -name IP_FILE   $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/remote_stp/AFU_debug/scjio_agilex.ip

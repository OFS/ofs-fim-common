# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

#--------------------
# Port Gasket modules
#--------------------
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/stratix10/port_gasket/pr_slot.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/stratix10/port_gasket/port_gasket.sv

set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/stratix10/user_clock/user_clk/qph_user_clk.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/stratix10/user_clock/user_clk/user_clock.sv

set_global_assignment -name IP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/stratix10/pr/PR_IP.ip
set_global_assignment -name IP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/stratix10/user_clock/qph_user_clk_iopll_s10_RF100M.ip
set_global_assignment -name IP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/stratix10/user_clock/qph_user_clk_iopll_reconfig.ip
set_global_assignment -name IP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/stratix10/remote_stp/ip/remote_debug_jtag_only/remote_debug_jtag_only_clock_in.ip
set_global_assignment -name IP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/stratix10/remote_stp/ip/remote_debug_jtag_only/host_if.ip
set_global_assignment -name IP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/stratix10/remote_stp/ip/remote_debug_jtag_only/jop_blaster.ip
set_global_assignment -name IP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/stratix10/remote_stp/ip/remote_debug_jtag_only/remote_debug_jtag_only_reset_in.ip
set_global_assignment -name IP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/stratix10/remote_stp/ip/remote_debug_jtag_only/sys_clk.ip
set_global_assignment -name QSYS_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/stratix10/remote_stp/remote_debug_jtag_only.qsys
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/stratix10/port_gasket/pr_slot.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/stratix10/port_gasket/port_gasket.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/stratix10/user_clock/user_clk/qph_user_clk.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/stratix10/user_clock/user_clk/user_clock.sv

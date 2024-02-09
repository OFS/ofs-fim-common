# Copyright (C) 2020 Intel Corporation.
# SPDX-License-Identifier: MIT

#
# Ethernet
#--------------------

set_global_assignment -name SEARCH_PATH $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/hssi_ss/inc/

#-----------------
# HSSI Common Files
#-----------------
set_global_assignment -name SYSTEMVERILOG_FILE    $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/hssi_ss/inc/ofs_fim_eth_plat_defines.svh 
set_global_assignment -name SYSTEMVERILOG_FILE    $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/hssi_ss/inc/ofs_fim_eth_plat_if_pkg.sv 
set_global_assignment -name SYSTEMVERILOG_FILE    $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/hssi_ss/inc/ofs_fim_eth_if_pkg.sv 
set_global_assignment -name SYSTEMVERILOG_FILE    $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/hssi_ss/inc/ofs_fim_eth_if.sv 
set_global_assignment -name SYSTEMVERILOG_FILE    $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/hssi_ss/inc/ofs_fim_eth_avst_if_pkg.sv 
set_global_assignment -name SYSTEMVERILOG_FILE    $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/hssi_ss/inc/ofs_fim_eth_avst_if.sv
set_global_assignment -name SYSTEMVERILOG_FILE    $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/hssi_ss/lib/ofs_fim_eth_afu_avst_to_fim_axis_bridge.sv 
set_global_assignment -name SYSTEMVERILOG_FILE    $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/hssi_ss/lib/ofs_fim_eth_sb_afu_avst_to_fim_axis_bridge.sv
set_global_assignment -name SYSTEMVERILOG_FILE    $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/hssi_ss/lib/mm_ctrl_xcvr.sv
set_global_assignment -name SYSTEMVERILOG_FILE    $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/hssi_ss/lib/rst_ack.sv

#-----------------
# HSSI SS top
#-----------------
set_global_assignment -name SYSTEMVERILOG_FILE    $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/hssi_ss/hssi_wrapper_csr.sv
set_global_assignment -name SYSTEMVERILOG_FILE    $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/hssi_ss/hssi_wrapper.sv



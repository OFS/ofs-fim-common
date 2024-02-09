## Copyright (C) 2023 Intel Corporation
## SPDX-License-Identifier: MIT

# This filelist contains the sources used on Agilex platforms
#--------------------
# AVST Pipeline modules
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/avst_pipeline/avst_pipeline_design_files.tcl

#--------------------
# cfg_mon module
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/cfg_mon/cfg_mon_design_files.tcl

#--------------------
# hps module
#--------------------
#set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/hps/hps_design_files.tcl

#--------------------
# Port Gasket module
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/port_gasket/port_gasket_design_files.tcl

#--------------------
# PR module
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/pr/pr_design_files.tcl

#--------------------
#Priority Encoder (pri_enc) modules
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/pri_enc/pri_enc_design_files.tcl

#--------------------
#Remote and JTAG STP modules
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/remote_stp/remote_stp_design_files.tcl
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/jtag_pr_stp/jtag_pr_stp_design_files.tcl

#--------------------
#Sys PLL module
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/sys_pll/sys_pll_design_files.tcl

#--------------------
#UART module
#--------------------
# Uart design files are added into the platform specific design list since not all platforms have uart

#--------------------
#User Clock module
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/user_clock/user_clock_design_files.tcl

#--------------------
# Memory Subsystem top module
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/mem_ss/mem_top_design_files.tcl

#--------------------
# PCIe Subsystem top module
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/pcie_ss/pcie_ss_top_design_files.tcl

#--------------------
# HSSI Subsystem top module
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/hssi_ss/hssi_wrapper_design_files.tcl

## Copyright (C) 2023 Intel Corporation
## SPDX-License-Identifier: MIT

#--------------------
# Sys PLL filelist
#--------------------
set_global_assignment -name IP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/sys_pll/sys_pll.ip

# Add the PLL to the dictionary of IP files that will be parsed by OFS
# into the project's ofs_ip_cfg_db directory. Parameters from the configured
# IP will be turned into Verilog macros.
dict set ::ofs_ip_cfg_db::ip_db $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/sys_pll/sys_pll.ip [list sys_clk iopll_get_cfg.tcl]

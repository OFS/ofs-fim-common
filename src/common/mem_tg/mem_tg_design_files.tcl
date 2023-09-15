## Copyright (C) 2023 Intel Corporation
## SPDX-License-Identifier: MIT

#--------------------
# HE MEM traffic generator modules
#--------------------
set_global_assignment -name QIP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg.qip
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/mem_ss_tg2.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg2_axi_mem.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg2_csr_pkg.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/csr_bridge.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/mem_tg2_csr.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/mem_tg2_top.sv

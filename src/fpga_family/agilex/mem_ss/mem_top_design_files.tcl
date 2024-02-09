# Copyright (C) 2020 Intel Corporation.
# SPDX-License-Identifier: MIT

# Include path
set_global_assignment -name SEARCH_PATH $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/mem_ss/includes

# Interfaces
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/mem_ss/ofs_fim_emif_ddr4_if.sv

# FIM logic
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/mem_ss/rst_hs.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/mem_ss/mem_ss_csr.sv

# MemSS CSR fabric (For DFHv0)
set_global_assignment -name IP_FILE   $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/mem_ss/qip/axilite_ic/ip/emif_csr_ic/emif_csr_ic_clock_in.ip
set_global_assignment -name IP_FILE   $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/mem_ss/qip/axilite_ic/ip/emif_csr_ic/emif_csr_ic_reset_in.ip
set_global_assignment -name IP_FILE   $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/mem_ss/qip/axilite_ic/ip/emif_csr_ic/emif_csr_slv.ip
set_global_assignment -name IP_FILE   $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/mem_ss/qip/axilite_ic/ip/emif_csr_ic/mem_ss_csr_mst.ip
set_global_assignment -name IP_FILE   $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/mem_ss/qip/axilite_ic/ip/emif_csr_ic/emif_dfh_mst.ip
set_global_assignment -name QSYS_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/mem_ss/qip/axilite_ic/emif_csr_ic.qsys

# Subsystem wrapper file
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/mem_ss/mem_ss_top.sv

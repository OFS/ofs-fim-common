# Copyright (C) 2020 Intel Corporation.
# SPDX-License-Identifier: MIT

# Include path
set_global_assignment -name SEARCH_PATH $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/mem_ss/includes

#
# EMIF application interfaces are passed to AFUs. These files are used by both FIM and PR builds.
#
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/mem_ss/includes/ofs_fim_mem_if_pkg.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/mem_ss/ofs_fim_emif_axi_mm_if.sv

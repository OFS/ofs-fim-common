## Copyright (C) 2023 Intel Corporation
## SPDX-License-Identifier: MIT
#--------------------
# Tag remap Filelist
#--------------------
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/tag_remap/pcie_arb_local_commit.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/tag_remap/ofs_fim_tag_pool.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/tag_remap/tag_remap.sv


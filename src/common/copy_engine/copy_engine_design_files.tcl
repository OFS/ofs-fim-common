## Copyright (C) 2023 Intel Corporation
## SPDX-License-Identifier: MIT
#--------------------
#--------------------------
# HPS Copy Engine Filelist
#--------------------------
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/includes/ofs_fim_ace_lite_if.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/copy_engine/rtl/ce_top.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/copy_engine/rtl/ce_axist_tx.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/copy_engine/rtl/ce_axist_rx.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/copy_engine/rtl/ce_axist_rx_req.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/copy_engine/rtl/ce_acelite_tx.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/copy_engine/rtl/ce_csr.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/copy_engine/rtl/ce_axi4mm_rx.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/lib/fifo/quartus_bfifo.sv


## Copyright (C) 2023 Intel Corporation
## SPDX-License-Identifier: MIT
#--------------------
#--------------------
# ST2MM Filelist
#--------------------
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/st2mm/st2mm_pkg.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/st2mm/axi_lite_if_conn.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/st2mm/fake_responder.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/st2mm/mmio_req_bridge.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/st2mm/mmio_rsp_arbiter.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/st2mm/mmio_rsp_tag_tracker.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/st2mm/mmio_rsp_bridge.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/st2mm/pcie_axis_cdc_fifo.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/st2mm/st2mm_csr.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/st2mm/st2mm_packet_filter.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/st2mm/pcie_axis_mux.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/st2mm/mctp_tx_bridge.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/st2mm/mctp_rx_bridge.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/st2mm/st2mm_rx_bridge.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/st2mm/st2mm_tx_bridge.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/st2mm/st2mm.sv

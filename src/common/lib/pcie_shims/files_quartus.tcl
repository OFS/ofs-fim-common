# Copyright (C) 2022 Intel Corporation
# SPDX-License-Identifier: MIT

##
## Import all pcie_shims sources into Quartus.
##

# Directory of script
set PCIE_SHIMS_DIR [file dirname [info script]]

set_global_assignment -name SYSTEMVERILOG_FILE "${PCIE_SHIMS_DIR}/pcie_dm_req_splitter/ofs_fim_pcie_dm_cpl_merge.sv"
set_global_assignment -name SYSTEMVERILOG_FILE "${PCIE_SHIMS_DIR}/pcie_dm_req_splitter/ofs_fim_pcie_dm_req_splitter.sv"
set_global_assignment -name SYSTEMVERILOG_FILE "${PCIE_SHIMS_DIR}/pcie_dm_req_splitter/ofs_fim_pcie_dm_rx_rd_splitter.sv"
set_global_assignment -name SYSTEMVERILOG_FILE "${PCIE_SHIMS_DIR}/pcie_dm_req_splitter/ofs_fim_pcie_dm_tx_req_splitter.sv"
set_global_assignment -name SYSTEMVERILOG_FILE "${PCIE_SHIMS_DIR}/pcie_dm_req_splitter/ofs_fim_pcie_dm_tx_rdwr_req_splitter.sv"
set_global_assignment -name SYSTEMVERILOG_FILE "${PCIE_SHIMS_DIR}/pcie_dm_req_splitter/ofs_fim_rotate_words_comb.sv"

set_global_assignment -name SYSTEMVERILOG_FILE "${PCIE_SHIMS_DIR}/pcie_hdr_out_of_band/ofs_fim_pcie_hdr_extract.sv"
set_global_assignment -name SYSTEMVERILOG_FILE "${PCIE_SHIMS_DIR}/pcie_hdr_out_of_band/ofs_fim_pcie_hdr_merge.sv"

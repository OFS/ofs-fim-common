# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: MIT

#--------------------
#HE_HSSI Filelist
#--------------------
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/lib/bridges/axis_rx_mmio_bridge.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/lib/bridges/axis_tx_mmio_bridge.sv

set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/he_hssi_top.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/common/eth_rx_axis_cdc_fifo.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/common/eth_traffic_csr_pkg.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/top_direct_green_bs/eth_traffic_pcie_tlp_to_csr.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/top_direct_green_bs/pcie_tlp_to_csr_no_dma.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/common/eth_traffic_csr.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/common/multi_port_axi_traffic_ctrl.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/common/multi_port_traffic_ctrl.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/common/pulse_sync.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/common/traffic_controller_wrapper.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/avalon_st_loopback.sv
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/avalon_st_loopback_csr.v
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/avalon_st_gen.v 
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/avalon_st_loopback.sv 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/avalon_st_loopback_csr.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/avalon_st_mon.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/avalon_st_prtmux.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/eth_std_traffic_controller_top.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/shiftreg_ctrl.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/shiftreg_data.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/crc32/avalon_st_to_crc_if_bridge.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/crc32/bit_endian_converter.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/crc32/byte_endian_converter.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/crc32/crc_checksum_aligner.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/crc32/crc_comparator.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/crc32/crc32_calculator.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/crc32/crc32_chk.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/crc32/crc32_gen.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/crc32/crc32_lib/crc_ethernet.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/crc32/crc32_lib/crc_register.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/crc32/crc32_lib/crc32_dat8.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/crc32/crc32_lib/crc32_dat16.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/crc32/crc32_lib/crc32_dat24.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/crc32/crc32_lib/crc32_dat32.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/crc32/crc32_lib/crc32_dat32_any_byte.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/crc32/crc32_lib/crc32_dat40.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/crc32/crc32_lib/crc32_dat48.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/crc32/crc32_lib/crc32_dat56.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/crc32/crc32_lib/crc32_dat64.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/crc32/crc32_lib/crc32_dat64_any_byte.v 
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/eth_traffic_controller/crc32/crc32_lib/xor6.v

set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/pkt_client_100g/alt_aeuex_pkt_gen_sync.v
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/pkt_client_100g/alt_e100s10_data_block_buffer.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/pkt_client_100g/alt_e100s10_data_synchronizer.sv 
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/pkt_client_100g/alt_e100s10_frame_buffer.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/pkt_client_100g/alt_e100s10_loopback_client.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/pkt_client_100g/alt_e100s10_pointer_synchronizer.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/pkt_client_100g/alt_e100s10_ready_skid.sv
set_global_assignment -name VERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/pkt_client_100g/alt_aeuex_packet_client_tx.v 
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/pkt_client_100g/alt_e100s10_packet_client.sv
set_global_assignment -name IP_FILE ../ip_lib/ofs-common/src/common/lib/fifo/sc_fifo_tx_sc_fifo.ip

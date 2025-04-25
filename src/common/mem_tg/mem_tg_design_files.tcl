## Copyright (C) 2023 Intel Corporation
## SPDX-License-Identifier: MIT

#--------------------
# HE MEM traffic generator modules
#--------------------
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/mem_ss_tg2.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg2_axi_mem.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg2_csr_pkg.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/csr_bridge.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/mem_tg2_csr.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/mem_tg2_top.sv

set_global_assignment -name VERILOG_FILE       $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_std_synchronizer_nocut.v
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_defs.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_2_sim_master_defs.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_2_top.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_2_rw_gen.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_2_addr_gen.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_2_lfsr.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_2_bringup_dcb.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_2_byteenable_test_stage.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_2_avl_interface.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_2_one_hot_addr_gen.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_2_per_pin_pattern_gen.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_2_rand_seq_addr_gen.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_2_seq_addr_gen.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_2_traffic_gen.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_2_rw_stage.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_2_compare_addr_gen.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_2_status_checker.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_2_config_error_module.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_lfsr_wrapper.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_lfsr.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_amm_1x_bridge.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_2_sim_master.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_2_targetted_reads_test_stage.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_2_axi_interface.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/altera_emif_avl_tg_2_csr_driver.sv
set_global_assignment -name SDC_FILE           $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/mem_ss_tg_axi_100/src/mem_ss_tg_axi.sdc
set_global_assignment -name VERILOG_FILE       $::env(BUILD_ROOT_REL)/ofs-common/src/common/mem_tg/tg_axi_mem/mem_ss_tg/src/mem_ss_tg.v

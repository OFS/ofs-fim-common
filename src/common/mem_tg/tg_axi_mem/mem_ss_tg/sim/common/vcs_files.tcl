# Copyright (C) 2021 Intel Corporation
# SPDX-License-Identifier: MIT

namespace eval mem_ss_tg {
  proc get_memory_files {QSYS_SIMDIR} {
    set memory_files [list]
    return $memory_files
  }
  
  proc get_common_design_files {QSYS_SIMDIR} {
    set design_files [dict create]
    dict set design_files "altera_common_sv_packages::avalon_vip_verbosity_pkg" "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/verbosity_pkg.sv"
    dict set design_files "altera_common_sv_packages::avalon_vip_avalon_mm_pkg" "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/avalon_mm_pkg.sv"
    return $design_files
  }
  
  proc get_design_files {QSYS_SIMDIR} {
    set design_files [dict create]
    dict set design_files "altera_std_synchronizer_nocut.v"                    "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_std_synchronizer_nocut.v"                   
    dict set design_files "altera_emif_avl_tg_defs.sv"                         "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_defs.sv"                        
    dict set design_files "altera_emif_avl_tg_2_sim_master_defs.sv"            "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_sim_master_defs.sv"           
    dict set design_files "altera_emif_avl_tg_2_top.sv"                        "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_top.sv"                       
    dict set design_files "altera_emif_avl_tg_2_rw_gen.sv"                     "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_rw_gen.sv"                    
    dict set design_files "altera_emif_avl_tg_2_addr_gen.sv"                   "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_addr_gen.sv"                  
    dict set design_files "altera_emif_avl_tg_2_lfsr.sv"                       "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_lfsr.sv"                      
    dict set design_files "altera_emif_avl_tg_2_bringup_dcb.sv"                "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_bringup_dcb.sv"               
    dict set design_files "altera_emif_avl_tg_2_byteenable_test_stage.sv"      "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_byteenable_test_stage.sv"     
    dict set design_files "altera_emif_avl_tg_2_avl_interface.sv"              "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_avl_interface.sv"             
    dict set design_files "altera_emif_avl_tg_2_one_hot_addr_gen.sv"           "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_one_hot_addr_gen.sv"          
    dict set design_files "altera_emif_avl_tg_2_per_pin_pattern_gen.sv"        "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_per_pin_pattern_gen.sv"       
    dict set design_files "altera_emif_avl_tg_2_rand_seq_addr_gen.sv"          "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_rand_seq_addr_gen.sv"         
    dict set design_files "altera_emif_avl_tg_2_seq_addr_gen.sv"               "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_seq_addr_gen.sv"              
    dict set design_files "altera_emif_avl_tg_2_traffic_gen.sv"                "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_traffic_gen.sv"               
    dict set design_files "altera_emif_avl_tg_2_rw_stage.sv"                   "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_rw_stage.sv"                  
    dict set design_files "altera_emif_avl_tg_2_compare_addr_gen.sv"           "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_compare_addr_gen.sv"          
    dict set design_files "altera_emif_avl_tg_2_status_checker.sv"             "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_status_checker.sv"            
    dict set design_files "altera_emif_avl_tg_2_config_error_module.sv"        "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_config_error_module.sv"       
    dict set design_files "altera_emif_avl_tg_lfsr_wrapper.sv"                 "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_lfsr_wrapper.sv"                
    dict set design_files "altera_emif_avl_tg_lfsr.sv"                         "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_lfsr.sv"                        
    dict set design_files "altera_emif_avl_tg_amm_1x_bridge.sv"                "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_amm_1x_bridge.sv"               
    dict set design_files "altera_emif_avl_tg_2_sim_master.sv"                 "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_sim_master.sv"                
    dict set design_files "altera_emif_avl_tg_2_targetted_reads_test_stage.sv" "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_targetted_reads_test_stage.sv"
    dict set design_files "altera_emif_avl_tg_2_axi_interface.sv"              "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_axi_interface.sv"             
    dict set design_files "altera_emif_avl_tg_2_csr_driver.sv"                 "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_csr_driver.sv"                
    dict set design_files "altera_emif_avl_tg_2_tb.sv"                         "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_tb.sv"                        
    dict set design_files "mem_ss_tg.v"                                        "$QSYS_SIMDIR/mem_ss_tg.v"                                                                
    return $design_files
  }
  
  proc get_elab_options {SIMULATOR_TOOL_BITNESS} {
    set ELAB_OPTIONS ""
    if ![ string match "bit_64" $SIMULATOR_TOOL_BITNESS ] {
    } else {
    }
    return $ELAB_OPTIONS
  }
  
  
  proc get_sim_options {SIMULATOR_TOOL_BITNESS} {
    set SIM_OPTIONS ""
    if ![ string match "bit_64" $SIMULATOR_TOOL_BITNESS ] {
    } else {
    }
    return $SIM_OPTIONS
  }
  
  
  proc get_env_variables {SIMULATOR_TOOL_BITNESS} {
    set ENV_VARIABLES [dict create]
    set LD_LIBRARY_PATH [dict create]
    dict set ENV_VARIABLES "LD_LIBRARY_PATH" $LD_LIBRARY_PATH
    if ![ string match "bit_64" $SIMULATOR_TOOL_BITNESS ] {
    } else {
    }
    return $ENV_VARIABLES
  }
  
  
}

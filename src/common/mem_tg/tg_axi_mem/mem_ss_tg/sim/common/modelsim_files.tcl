
namespace eval mem_ss_tg {
  proc get_design_libraries {} {
    set libraries [dict create]
    dict set libraries altera_common_sv_packages 1
    dict set libraries mem_ss_tg_axi_100         1
    dict set libraries mem_ss_tg                 1
    return $libraries
  }
  
  proc get_memory_files {QSYS_SIMDIR} {
    set memory_files [list]
    return $memory_files
  }
  
  proc get_common_design_files {USER_DEFINED_COMPILE_OPTIONS USER_DEFINED_VERILOG_COMPILE_OPTIONS USER_DEFINED_VHDL_COMPILE_OPTIONS QSYS_SIMDIR} {
    set design_files [dict create]
    dict set design_files "altera_common_sv_packages::avalon_vip_verbosity_pkg" "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/verbosity_pkg.sv"]\"  -work altera_common_sv_packages"
    dict set design_files "altera_common_sv_packages::avalon_vip_avalon_mm_pkg" "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/avalon_mm_pkg.sv"]\"  -work altera_common_sv_packages"
    return $design_files
  }
  
  proc get_design_files {USER_DEFINED_COMPILE_OPTIONS USER_DEFINED_VERILOG_COMPILE_OPTIONS USER_DEFINED_VHDL_COMPILE_OPTIONS QSYS_SIMDIR} {
    set design_files [list]
    lappend design_files "vlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_std_synchronizer_nocut.v"]\"  -work mem_ss_tg_axi_100"                                                   
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_defs.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"                        
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_sim_master_defs.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"           
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_top.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"                       
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_rw_gen.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"                    
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_addr_gen.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"                  
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_lfsr.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"                      
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_bringup_dcb.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"               
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_byteenable_test_stage.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"     
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_avl_interface.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"             
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_one_hot_addr_gen.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"          
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_per_pin_pattern_gen.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"       
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_rand_seq_addr_gen.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"         
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_seq_addr_gen.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"              
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_traffic_gen.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"               
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_rw_stage.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"                  
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_compare_addr_gen.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"          
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_status_checker.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"            
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_config_error_module.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"       
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_lfsr_wrapper.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"                
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_lfsr.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"                        
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_amm_1x_bridge.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"               
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_sim_master.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"                
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_targetted_reads_test_stage.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_axi_interface.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"             
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_csr_driver.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"                
    lappend design_files "vlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/../mem_ss_tg_axi_100/sim/altera_emif_avl_tg_2_tb.sv"]\" -L altera_common_sv_packages -work mem_ss_tg_axi_100"                        
    lappend design_files "vlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS  \"[normalize_path "$QSYS_SIMDIR/mem_ss_tg.v"]\"  -work mem_ss_tg"                                                                                                        
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
  
  
  proc normalize_path {FILEPATH} {
      if {[catch { package require fileutil } err]} { 
          return $FILEPATH 
      } 
      set path [fileutil::lexnormalize [file join [pwd] $FILEPATH]]  
      if {[file pathtype $FILEPATH] eq "relative"} { 
          set path [fileutil::relative [pwd] $path] 
      } 
      return $path 
  } 
}

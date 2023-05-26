# Copyright (C) 2020 Intel Corporation
# SPDX-License-Identifier: MIT

namespace eval avst_pipeline_st_pipeline_stage_0 {
  proc get_memory_files {QSYS_SIMDIR} {
    set memory_files [list]
    return $memory_files
  }
  
  proc get_common_design_files {QSYS_SIMDIR} {
    set design_files [dict create]
    return $design_files
  }
  
  proc get_design_files {QSYS_SIMDIR} {
    set design_files [dict create]
    dict set design_files "avst_pipeline_st_pipeline_stage_0_altera_avalon_st_pipeline_stage_1920_zterisq.sv" "$QSYS_SIMDIR/../altera_avalon_st_pipeline_stage_1920/sim/avst_pipeline_st_pipeline_stage_0_altera_avalon_st_pipeline_stage_1920_zterisq.sv"
    dict set design_files "altera_avalon_st_pipeline_base.v"                                                  "$QSYS_SIMDIR/../altera_avalon_st_pipeline_stage_1920/sim/altera_avalon_st_pipeline_base.v"                                                 
    dict set design_files "avst_pipeline_st_pipeline_stage_0.v"                                               "$QSYS_SIMDIR/avst_pipeline_st_pipeline_stage_0.v"                                                                                          
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

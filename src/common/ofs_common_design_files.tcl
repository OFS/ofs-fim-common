## Copyright (C) 2023 Intel Corporation
## SPDX-License-Identifier: MIT

#The list below is the filelist for the ofs-common repository. It can be inherited into 
#any FIM repo as is or by creating antoher filelist with only the modules that are required

#--------------------
# Include files
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/includes/include_design_files.tcl

#--------------------
# FME Files
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/fme/fme_design_files.tcl

#--------------------
# FME ID ROM Files
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/fme_id_rom/fme_id_rom_design_files.tcl

#--------------------
# FLR Logic
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/flr/flr_design_files.tcl

#--------------------
# HE NULL module
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_null/he_null_design_files.tcl

#--------------------
# Protocol Checker module
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/protocol_checker/protocol_checker_design_files.tcl

#--------------------
# Tag remap logic
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/tag_remap/tag_remap_design_files.tcl

#--------------------------
# HPS Copy Engine modules
#--------------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/copy_engine/copy_engine_design_files.tcl

#--------------------
# ST2MM modules
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/st2mm/st2mm_design_files.tcl

#--------------------
# PR Gasket modules
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/port_gasket/port_gasket_design_files.tcl


#--------------------
#HE_HSSI modules
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_hssi/he_hssi_design_files.tcl


#--------------------
#Common Library modules
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/lib/lib_design_files.tcl



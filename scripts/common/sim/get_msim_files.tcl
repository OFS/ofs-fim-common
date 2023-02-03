# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

# Description
#-----------------------------------------------------------------------------
#
# This script takes in two arguments:
#    0 : IP instance name
#    1 : Path to the Modelsim simulation script of the IP instance
#
# It sources the IP Modelsim simulation script to collect the IP simulation
# filelist, which includes:
#    * IP and common library files
#    * Memory initialization files
#
# The filelist is written into design_files.txt and memory_files.txt
#
#-----------------------------------------------------------------------------

# Source the IP Modelsim simulation script
set ip [lindex $argv 0]
set msim_file [lindex $argv 1]
source $msim_file

set mem_fh [open "memory_files.txt" w]
set fh [open "design_files.txt" w]

# Using the TCL procedures from the IP VCS simulation script
# to collect the IP filelist 
set memory_files [${ip}::get_memory_files "\$QSYS_SIMDIR"]
set common_design_files [dict values [${ip}::get_common_design_files "\$USER_DEFINED_COMPILE_OPTIONS" "\$USER_DEFINED_VERILOG_COMPILE_OPTIONS" "\$USER_DEFINED_VHDL_COMPILE_OPTIONS" "\$QSYS_SIMDIR"]]
set design_files [${ip}::get_design_files "\$USER_DEFINED_COMPILE_OPTIONS" "\$USER_DEFINED_VERILOG_COMPILE_OPTIONS" "\$USER_DEFINED_VHDL_COMPILE_OPTIONS" "\$QSYS_SIMDIR"]

# Write memory initialization files to memory_files.txt
foreach file $memory_files { 
   puts $mem_fh "$file"
}
close $mem_fh

# Write IP filelist to design_files.txt
foreach file $common_design_files { 
   puts $fh "$file"
}

foreach file $design_files { 
   puts $fh "$file"
}

close $fh

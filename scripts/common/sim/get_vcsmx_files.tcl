# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

# Description
#-----------------------------------------------------------------------------
#
# For now, this script mirrors the behavior of get_vcs_files.tcl and writes
# a list of IP simulation files to memory_files.txt and design_files.txt.
# It strips the vlogan VCS-MX commands, extracting just the files.
#
# In the future we could execute the enumerated vlogan commands.
#
#-----------------------------------------------------------------------------

# Source the IP VCS simulation script
set ip [lindex $argv 0]
set vcs_file [lindex $argv 1]
source $vcs_file

set mem_fh [open "memory_files.txt" w]
set fh [open "design_files.txt" w]

# Using the TCL procedures from the IP VCS simulation script
# to collect the IP filelist 
set memory_files [${ip}::get_memory_files "\$QSYS_SIMDIR" "\$QUARTUS_ROOTDIR"]
set common_design_files [${ip}::get_common_design_files "XXXREMOVEXXX" "" "" "\$QSYS_SIMDIR"]
set design_files [${ip}::get_design_files "XXXREMOVEXXX" "" "" "\$QSYS_SIMDIR" "\$QUARTUS_ROOTDIR"]

# Write memory initialization files to memory_files.txt
foreach file $memory_files {
   puts $mem_fh "$file"
}
close $mem_fh

proc extract_filename_from_cmd {cmd} {
   set f [regsub {^.*XXXREMOVEXXX *} $cmd {}]
   set f [regsub { *-work .*$} $f {}]
   set f [regsub -all {\\"} $f {}]
   return $f
}

# Write IP filelist to design_files.txt
foreach file $common_design_files { 
   puts $fh [extract_filename_from_cmd $file]
}

foreach file $design_files { 
   puts $fh [extract_filename_from_cmd $file]
}

close $fh

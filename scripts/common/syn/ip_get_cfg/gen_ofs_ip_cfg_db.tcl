# Copyright 2023 Intel Corporation
# SPDX-License-Identifier: MIT

##
## Invoke from quartus_sh -t.
##
## Helper script for generating the OFS configuration database header
## files. The script simply loads the project and invokes the project's
## Tcl procedure that emits the header files.
##

# Add tcl_lib subdirectory of this script to package search path
lappend auto_path [file join [pwd] [file dirname [info script]] .. tcl_lib]
# OFS script for parsing command line options
package require options


proc PrintHelp {} {
   puts "This script invokes the Tcl procedure that generates the OFS."
   puts "IP configuration header files in ofs_ip_cfg_db."
   puts ""    
   puts "Usage: gen_ofs_ip_cfg_db.tcl --project=<proj> --revision=<rev>"
   puts ""
   puts "Supported options:"
   puts "    --project=<project>"
   puts "    --revision=<revision>"
   puts ""
}


proc main {} {
  if { [::options::ParseCMDArguments {--project --revision} {--help}] == -1 } {
    PrintHelp
    exit 1
  }

  if [info exists ::options::optionMap(--help)] {
    PrintHelp
    return 0
  }

  set project $::options::optionMap(--project)
  set revision $::options::optionMap(--revision)

  project_open -revision $revision $project

  if { ! [llength [info procs ::ofs_ip_cfg_db::generate]] } {
    post_message -type Warning "ofs_ip_cfg_db.tcl is not loaded in this project"
  } else {
    post_message "Generating OFS IP configuration database in ofs_ip_cfg_db/"
    ::ofs_ip_cfg_db::generate
  }

  project_close
}

main

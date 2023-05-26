# Copyright 2022 Intel Corporation
# SPDX-License-Identifier: MIT

##
## Invoke from quartus_sh -t.
##
## Emit all macros defined in a Quartus project.
##

# Add tcl_lib subdirectory of this script to package search path
lappend auto_path [file join [pwd] [file dirname [info script]] tcl_lib]
# OFS script for parsing command line options
package require options


#************************************************
# Description: Print the HELP info
#************************************************
proc PrintHelp {} {
   puts "This script emits all the macros defined in a project."
   puts "Usage: emit_project_macros.tcl --project=<proj> --revision=<rev> --output=<fname>"
   puts "Supported options:"
   puts "    --project <project>"
   puts "    --revision <revision>"
   puts "    --output <output file>"
}


proc emitMacros {} {
  set project $::options::optionMap(--project)
  set revision $::options::optionMap(--revision)
  set output_fname $::options::optionMap(--output)

  project_open -revision $revision $project

  set ofile [open $output_fname w]

  puts $ofile "##"
  puts $ofile "## Verilog macros read from ${project} ${revision}"
  puts $ofile "##"
  puts $ofile "## Generated by emit_project_macros.tcl"
  puts $ofile "##\n"

  set macro_col [get_all_global_assignments -name VERILOG_MACRO]
  foreach_in_collection m $macro_col {
    set t [lindex $m 2]
    # Emit everything but OPAE_PLATFORM_GEN, which is a tag used during
    # out-of-tree PR release creation.
    if { $t != "OPAE_PLATFORM_GEN" } {
      puts $ofile $t
    }
  }

  close $ofile
  project_close
}

#************************************************
# Description: Entry point of TCL post processing
#************************************************
proc main {} {
  if { [::options::ParseCMDArguments {--project --revision --output}] == -1 } {
    PrintHelp
    return -1
  }

  emitMacros
}

main

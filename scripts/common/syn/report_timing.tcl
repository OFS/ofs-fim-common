# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

##
## Invoke from quartus_sta -t or as a hook at the end of quartus_sta.
##
## Generate a timing report in output_files/timing_report. When
## output_files/timing_report/clocks.sta.fail.summary is empty there are
## no timing violations.
##
## This script may either be sourced with a timing netlist already
## created or run stand-alone with quartus_sta. Logic at the bottom
## detects the mode.
##

# Add tcl_lib subdirectory of this script to package search path
lappend auto_path [file join [pwd] [file dirname [info script]] tcl_lib]
# OFS script for parsing command line options
package require options


#************************************************
# Description: Print the HELP info
#************************************************
proc PrintHelp {} {
   puts "This script generates detailed timing report for the given project in output_files/timing_report"
   puts "Usage: report_timing.tcl <option>.."
   puts "Supported options:"
   puts "    --project <project>         "
   puts "    --revision <revision>       "
}


# Write clock summary to open file handle $ofile
proc emitClockSummaryInfo {ofile corner domain type} {
  set name [lindex $domain 0]
  set slack [lindex $domain 1]
  set keeper_tns [lindex $domain 2]

  puts $ofile "Type  : ${corner} ${type} '${name}'"
  puts $ofile "Slack : ${slack}"
  puts $ofile "TNS   : ${keeper_tns}"
  puts $ofile ""
}


proc subReportTiming {project revision} {
  if [file exists output_files/timing_report] {
    file delete -force -- output_files/timing_report
  }

  report_clocks -file "output_files/timing_report/clocks.rpt"

  set pass_file [open "output_files/timing_report/clocks.sta.pass.summary" w]
  set fail_file [open "output_files/timing_report/clocks.sta.fail.summary" w]

  set operating_conditions [get_available_operating_conditions]
  foreach corner $operating_conditions {
    set_operating_conditions $corner
    # User clock frequency changes may update the timing. Apply the time
    # borrowing computed for the target frequency by setting dynamic_borrow.
    update_timing_netlist -dynamic_borrow

    set report_type_list {setup hold recovery removal mpw}
    foreach type $report_type_list {
      set report_name "output_files/timing_report/${revision}_${corner}_${type}.rpt"
      set domain_list [get_clock_domain_info -${type}]
      foreach domain $domain_list {
        set name [lindex $domain 0]
        set slack [lindex $domain 1]

        if {$slack >= 0} {
          emitClockSummaryInfo $pass_file $corner $domain $type
        } else {
          emitClockSummaryInfo $fail_file $corner $domain $type

          if {$type != "mpw"} {
            report_timing -to_clock $name -${type} -show_routing -npaths 20 -file $report_name -append
          } else {
            report_min_pulse_width -nworst 20 -file $report_name -append
          }
        }
      }
    }
  }

  close $pass_file
  close $fail_file
}

#************************************************
# Description: Entry point of TCL post processing
#************************************************
proc main {} {
  # Run as the top level script. Open a project.
  if { [::options::ParseCMDArguments {--project --revision}] == -1 } {
    PrintHelp
    return -1
  }

  set project $::options::optionMap(--project)
  set revision $::options::optionMap(--revision)

  project_open -revision $revision $project
  create_timing_netlist
  read_sdc

  subReportTiming $project $revision

  delete_timing_netlist
  project_close
}

proc from_sta {} {
  # Run from another script with a project open
  set project [get_current_project]
  set revision [get_current_revision]

  post_message "Running OFS report_timing.tcl" \
    -submsgs [list "Project: ${project}" "Revision: ${revision}"]

  subReportTiming $project $revision
}

if { [info script] eq $::argv0 } {
  main
} else {
  from_sta
}

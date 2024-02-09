# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

##
## Invoke from quartus_sh -t or as a hook at the end of quartus_sta.
##
## When the user clock is in "auto" mode, compute the achieved Fmax.
## The chosen user clock frequency is written to
## output_files/user_clock_freq.txt.
##
## This script may either be sourced with a timing netlist already
## created or run stand-alone with quartus_sta. Logic at the bottom
## detects the mode.
##

# Required packages
package require ::quartus::project
package require ::quartus::report
package require ::quartus::flow

# Add tcl_lib subdirectory of this script to package search path
lappend auto_path [file join [pwd] [file dirname [info script]] tcl_lib]
# OFS script for parsing command line options
package require options


# Load state into userClocks namespace
source ofs_partial_reconfig/user_clock_defs.tcl


proc compute_uclk {project_name revision_name} {
    set jitter_compensation 0.01

    load_report $revision_name

    delete_computed_user_clocks_file

    # get device speedgrade
    set part_name [get_global_assignment -name DEVICE]
    post_message "Device part name is $part_name"
    set report [report_part_info $part_name]
    regexp {Speed Grade.*$} $report speedgradeline
    regexp {(\d+)} $speedgradeline speedgrade
    if { $speedgrade < 1 || $speedgrade > 8 } {
        post_message "Speedgrade is $speedgrade and not in the range of 1 to 8"
        post_message "Terminating post-flow script"
        return TCL_ERROR
    }
    post_message "Speedgrade is $speedgrade"

    set need_timing_update 0
    set json_uclk_freqs [get_afu_json_user_clock_freqs]

    if {[uclk_freq_is_auto $json_uclk_freqs]} {
        post_message "User clocks auto mode: computing FMax"

        if {[llength $json_uclk_freqs] == 2 &&
            0 == [string compare -nocase -length 4 "auto" [lindex $json_uclk_freqs 0]] &&
            0 == [string compare -nocase -length 4 "auto" [lindex $json_uclk_freqs 1]]} {
            # Both high and low clocks are in auto mode
            if {! [uclk_used_in_afu $::userClocks::u_clk_name]} {
                set json_uclk_freqs [lreplace $json_uclk_freqs 1 1 0]
                post_message "User clock high is not used by the AFU. Allowing full range of the low frequency clock."
            }
        }

        # Get the achieved frequencies for each clock
        set x [get_user_clks_and_fmax $::userClocks::u_clkdiv2_name $::userClocks::u_clk_name $jitter_compensation]
        # Construct a list of just frequencies (low then high)
        set uclk_freqs_actual [list [lindex $x 0] [lindex $x 2]]

        # Choose uclk frequencies, based on the original JSON constraints and
        # the achieved frequencies.
        set uclk_freqs [uclk_pick_aligned_freqs $json_uclk_freqs $uclk_freqs_actual $::userClocks::u_clk_fmax]

        # Write chosen frequencies to a file, which will be used both by the
        # next timing analysis phase and by the packager.
        save_computed_user_clocks $uclk_freqs
        set need_timing_update 1
    } else {
        post_message "User clocks not in auto mode"

        # Canonicalize clocks in case only one was specified
        if {[llength $json_uclk_freqs] == 2} {
            if {[lindex $json_uclk_freqs 0] == 0} {
                lset json_uclk_freqs 0 [expr {[lindex $json_uclk_freqs 1] / 2.0}]
            }
            if {[lindex $json_uclk_freqs 1] == 0} {
                lset json_uclk_freqs 1 [expr {[lindex $json_uclk_freqs 0] * 2}]
            }

            save_computed_user_clocks $json_uclk_freqs
        }
    }

    return $need_timing_update
}


#
# Check whether a user clock is used by the AFU region in the design.
#
proc uclk_used_in_afu {uclk_name} {
    set uclk [get_clocks -include_generated_clocks $uclk_name]

    # We expect a single afu_main(), but we may as well check the
    # returned list of instances.
    foreach afu_main [get_entity_instances -nowarn afu_main] {
        # Is there any register inside afu_main() clocked by uclk?
        set paths [get_timing_paths -to_clock $uclk -to [get_registers "{$afu_main|*}"] -npaths 1 -setup]
        if { [get_collection_size $paths] > 0 } {
            return 1
        }
    }

    # Clock not used
    return 0
}


# Return values: [retval panel_id row_index]
#   panel_id and row_index are only valid if the query is successful
# retval:
#    0: success
#   -1: not found
#   -2: panel not found (could be report not loaded)
#   -3: no rows found in panel
#   -4: multiple matches found
proc find_report_panel_row { panel_name col_index string_op string_pattern } {
    if {[catch {get_report_panel_id $panel_name} panel_id] || $panel_id == -1} {
        return -2;
    }

    if {[catch {get_number_of_rows -id $panel_id} num_rows] || $num_rows == -1} {
        return -3;
    }

    # Search for row match.
    set found 0
    set row_index -1;

    for {set r 1} {$r < $num_rows} {incr r} {
        if {[catch {get_report_panel_data -id $panel_id -row $r -col $col_index} value] == 0} {


            if {[string $string_op $string_pattern $value]} {
                if {$found == 0} {

                    # If multiple rows match, return the first
                    set row_index $r

                }
                incr found
            }

        }
    }

    if {$found > 1} {return [list -4 $panel_id $row_index]}
    if {$row_index == -1} {return -1}

    return [list 0 $panel_id $row_index]
}


# get_fmax_from_report: Determines the fmax for the given clock. The fmax value returned
# will meet all timing requirements (setup, hold, recovery, removal, minimum pulse width)
# across all corners.  The return value is a 2-element list consisting of the
# fmax and clk name
proc get_fmax_from_report { clkname required jitter_compensation} {
    # Find the clock period.
    set result [find_report_panel_row "Timing Analyzer||Clocks" 0 match $clkname]
    set retval [lindex $result 0]

    if {$retval == -1} {
        if {$required == 1} {
           error "Error: Could not find clock: $clkname"
        } else {
           post_message -type warning "Could not find clock: $clkname.  Clock is not required assuming 10 GHz and proceeding."
           return [list 10000 $clkname]
        }
    } elseif {$retval < 0} {
        error "Error: Failed search for clock $clkname (error $retval)"
    }

    # Update clock name to full clock name ($clkname as passed in may contain wildcards).
    set panel_id [lindex $result 1]
    set row_index [lindex $result 2]
    set clkname [get_report_panel_data -id $panel_id -row $row_index -col 0]
    set clk_period [get_report_panel_data -id $panel_id -row $row_index -col 2]

    post_message "Clock $clkname"
    post_message "  Period: $clk_period"

    # Determine the most negative slack across all relevant timing metrics (setup, recovery, minimum pulse width)
    # and across all timing corners. Hold and removal metrics are not taken into account
    # because their slack values are independent on the clock period (for kernel clocks at least).
    #
    # Paths that involve both a posedge and negedge of the kernel clocks are not handled properly (slack
    # adjustment needs to be doubled).
    set timing_metrics [list "Setup" "Recovery" "Minimum Pulse Width"]
    set timing_metric_colindex [list 1 3 5 ]
    set timing_metric_required [list 1 0 0]
    set wc_slack $clk_period
    set has_slack 0
    set fmax_from_summary 5000.0

    # Find the "Fmax Summary" numbers reported in Quartus.  This may not
    # account for clock transfers but it does account for pos-to-neg edge same
    # clock transfers.  Whatever we calculate should be less than this.
    set fmax_panel_name "Timing Analyzer||* Model||* Model Fmax Summary"
    foreach panel_name [get_report_panel_names] {
      if {[string match $fmax_panel_name $panel_name] == 1} {
        set result [find_report_panel_row $panel_name 2 equal $clkname]
        set retval [lindex $result 0]
        if {$retval == 0} {
          set restricted_fmax_field [get_report_panel_data -id [lindex $result 1] -row [lindex $result 2] -col 1]
          regexp {([0-9\.]+)} $restricted_fmax_field restricted_fmax
          if {$restricted_fmax < $fmax_from_summary} {
            set fmax_from_summary $restricted_fmax
          }
        }
      }
    }
    post_message "  Restricted Fmax from STA: $fmax_from_summary"

    # Find the worst case slack across all corners and metrics
    foreach metric $timing_metrics metric_required $timing_metric_required col_ndx $timing_metric_colindex {
      set panel_name "Timing Analyzer||Multicorner Timing Analysis Summary"
      set panel_id [get_report_panel_id $panel_name]
      set result [find_report_panel_row $panel_name 0 equal " $clkname"]
      set retval [lindex $result 0]

      if {$retval == -1} {
        if {$required == 1 && $metric_required == 1} {
          error "Error: Could not find clock: $clkname"
        }
      } elseif {$retval < 0 && $retval != -4 } {
        error "Error: Failed search for clock $clkname (error $retval)"
      }

      if {$retval == 0 || $retval == -4} {
        set slack [get_report_panel_data -id [lindex $result 1] -row [lindex $result 2] -col $col_ndx ]
        post_message "    $metric slack: $slack"
        if {$slack != "N/A"} {
          if {$metric == "Setup" || $metric == "Recovery"} {
            set has_slack 1
            if {$metric == "Recovery"} {
              set normalized_slack [ expr $slack / 4.0 ]
              post_message "    normalized $metric slack: $normalized_slack"
              set slack $normalized_slack
            }
          }
        }
        # Keep track of the most negative slack.
        if {$slack < $wc_slack} {
          set wc_slack $slack
          set wc_metric $metric
        }
      }
    }

    if {$has_slack == 1} {
        # Adjust the clock period to meet the worst-case slack requirement.
        set clk_period [expr $clk_period - $wc_slack + $jitter_compensation]
        post_message "  Adjusted period: $clk_period ([format %+0.3f [expr -$wc_slack]], $wc_metric)"

        # Compute fmax from clock period. Clock period is in nanoseconds and the
        # fmax number should be in MHz.
        set fmax [expr 1000 / $clk_period]

        if {$fmax_from_summary < $fmax} {
            post_message "  Restricted Fmax from STA is lower than $fmax, using it instead."
            set fmax $fmax_from_summary
        }

        # Truncate to two decimal places. Truncate (not round to nearest) to avoid the
        # very small chance of going over the clock period when doing the computation.
        set fmax [expr floor($fmax * 100) / 100]
        post_message "  Fmax: $fmax"
    } else {
        post_message -type warning "No slack found for clock $clkname - assuming 10 GHz."
        set fmax 10000
    }

    return [list $fmax $clkname]
}

# Returns [fmax1 u_clkdiv2_name fmax2 u_clk_name]
proc get_user_clks_and_fmax {u_clkdiv2_name u_clk_name jitter_compensation} {
    set result [list]

    # Read in the achieved fmax for each clock
    set x [get_fmax_from_report $u_clk_name 0 $jitter_compensation]
    set fmax2 [lindex $x 0]
    set u_clk_name [lindex $x 1]

    # Is the slow clock configurable separately?
    if {$u_clkdiv2_name != ""} {
        # Yes.  What frequency did it achieve?
        set x [get_fmax_from_report $u_clkdiv2_name 1 $jitter_compensation]
        set fmax1 [lindex $x 0]
        set u_clkdiv2_name [lindex $x 1]
    } else {
        # No.  Set the request based on the primary clock.
        set fmax1 [expr $fmax2 / 2.0]
        if {$fmax1 > $::userClocks::u_clkdiv2_fmax} {
            set fmax1 $::userClocks::u_clkdiv2_fmax
        }
    }

    return [list $fmax1 $u_clkdiv2_name $fmax2 $u_clk_name]
}


#************************************************
# Description: Print the HELP info
#************************************************
proc PrintHelp {} {
    puts "Compute user clock frequencies based on the AFU JSON requests and actual frequencies"
    puts "achieved following place and route."
    puts ""
    puts "Usage: compute_user_clock_freqs.tcl --project=<project> --revision=<revision>"
}

# Entry point when run as the primary script
proc main {} {
    # Run as the top level script. Open a project.
    if { [::options::ParseCMDArguments {--project --revision}] == -1 } {
        PrintHelp
        return -1
    }

    set project $::options::optionMap(--project)
    set revision $::options::optionMap(--revision)

    project_open -revision $revision $project
    load_package design
    design::load_design -snapshot final

    if { [compute_uclk $project $revision] } {
        # Force sta timing netlist to be rebuilt
        file delete [glob -nocomplain db/$revision_name.sta_cmp.*.tdb]
        file delete -force -- [glob -nocomplain qdb/_compiler/$revision_name/*/*/final/1/.cache*]
        file delete [glob -nocomplain qdb/_compiler/$revision_name/*/*/final/1/*cache*]
        file delete [glob -nocomplain qdb/_compiler/$revision_name/*/*/final/1/timing_netlist*]
    }

    design::unload_design
    project_close
}

# Entry point when invoked from another script with a project open
proc from_sta {} {
    set project [get_current_project]
    set revision [get_current_revision]

    post_message "Running OFS user_clock_freqs_compute.tcl" \
        -submsgs [list "Project: ${project}" "Revision: ${revision}"]

    if { [compute_uclk $project $revision] } {
        post_message "Updating timing netlist with new user clock frequency."
        read_sdc
        update_timing_netlist
    }
}

if { [info script] eq $::argv0 } {
    main
} else {
    from_sta
}

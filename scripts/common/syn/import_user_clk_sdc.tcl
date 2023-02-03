# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

## This script is run at the end of the fim build.  The top-level
## procedure (setup_user_clk_sdc) is called with a regular expression matching the
## user clocks.  (E.g. "vl_qph_user_clk_clkpsc_clk*".)  The code here discovers the
## primary user clocks that are derived from a base clock.  A Tcl script to be used
## during PR builds for constraining user clocks to target frequencies is emitted
## to user_clock_defs.tcl in the compile output files directory.
##

proc setup_user_clk_sdc { user_clks_regexp uclk_max_freq ofile_name } {
  # Two user clocks should be found
  set user_clk_coll [get_clocks $user_clks_regexp]
  set n_user_clks [get_collection_size $user_clk_coll]
  if {${n_user_clks} != 2} {
    post_message -type error "Expected 2 user clocks, found ${n_user_clks}"
    qexit -error
  }

  # Convert the 2 entry clocks collection to a list
  set user_clks [list]
  set user_clk_periods [list]
  foreach_in_collection clk $user_clk_coll {
    lappend user_clks $clk
    lappend user_clk_periods [get_clock_info $clk -period]
  }

  # Sort by period, with slow clock first
  if {[get_clock_info [lindex $user_clks 0] -period] < [get_clock_info [lindex $user_clks 1] -period]} {
    set user_clks [lreverse $user_clks]
  }

  set base_user_clks [list]
  set base_ratios [list]
  set user_clk_names [list]
  set user_clk_master_names [list]

  # Find the configurable user clocks by walking up the generated hierarchy
  foreach clk $user_clks {
    set c_name [get_clock_info $clk -name]

    set b_info [get_base_user_clk $clk]
    set b_clk [lindex $b_info 0]
    set b_ratio [lindex $b_info 1]
    set b_name [get_clock_info $b_clk -name]

    post_message -type info "Base of {${c_name}} is {${b_name}} (ratio ${b_ratio})"
    lappend base_user_clks $b_clk
    lappend base_ratios $b_ratio
    lappend user_clk_names $c_name
    lappend user_clk_master_names [get_clock_info $clk -master_clock]
  }

  if {[llength $base_user_clks] != 2} {
    post_message -type error "Expected 2 clocks"
    qexit -error
  }

  #
  # At this point we have a pair of 2 entry lists.  One is the set of base user clocks
  # on which the constraints will be applied.  The other list holds the ratios applied
  # to these base clocks before they are passed to the AFU.
  #

  # Are the base user clocks the same for low and high?
  if {[lindex $base_user_clks 0] == [lindex $base_user_clks 1]} {
    # Pass a single entry list to the emitter, indicating a shared clock
    emit_user_clk_cfg [list [lindex $base_user_clks 0]] $user_clk_names $uclk_max_freq $ofile_name
  } else {
    emit_user_clk_cfg $base_user_clks $user_clk_names $uclk_max_freq $ofile_name
  }
}


##
## Find the base of a user clock.  Namely, the parent upon which the timing constraint
## should be applied.  We assume this is the first clock in the chain that is
## either not generated or has a ratio other than 1.
##
## Returns a tuple: the base clock and the ratio applied to that clock before it
## reaches the AFU.
##
proc get_base_user_clk { user_clk } {
  set clk $user_clk
  set ratio 1.0

  while {[get_parent_clk_type $clk] == "generated"} {
    set c_name [get_clock_info $clk -name]
    set ratio [expr $ratio * [get_clock_info $clk -multiply_by] / [get_clock_info $clk -divide_by]]
    if {$ratio != 1.0} {
      post_message -type info "Found generated user clock {${c_name}} with ratio ${ratio}"
      break
    }

    set p_clk [get_parent_clk $clk]
    set p_name [get_clock_info $p_clk -name]

    post_message -type info "Parent of user clock {${c_name}} is {${p_name}}"
    set clk $p_clk
  }

  return [list $clk $ratio]
}


##
## Return the immediate parent (master) of clk
##
proc get_parent_clk { clk } {
  set m_name [get_clock_info $clk -master_clock]
  set m_clks [get_clocks $m_name]

  if {[get_collection_size $m_clks] == 1} {
    foreach_in_collection clk $m_clks {
      return $clk
    }
  }

  set c_name [get_clock_info $clk -name]
  post_message -type error "Failed to find parent of clock ${c_name}"
  qexit -error
}


##
## Return the type of the immediate parent (master) of clk
##
proc get_parent_clk_type { clk } {
  set p_clk [get_parent_clk $clk]
  return [get_clock_info $p_clk -type]
}


##
## Emit the configuration file
##
proc emit_user_clk_cfg { user_clks user_clk_names uclk_max_freq ofile_name } {
  # What is the frequency of the primary clock?  We assume that all user clocks share
  # the same primary.
  set p_clk [get_parent_clk [lindex $user_clks 0]]
  set p_clk_mhz [expr 1000.0 / [get_clock_info $p_clk -period]]

  # Map from p_clk MHz to target MHz.  The divide_by will be set to 1000 since Quartus
  # doesn't allow floating point arguments.
  set p_clk_mult [expr 1000.0 / $p_clk_mhz]

  set uclkdiv2_name [lindex $user_clk_names 0]
  set uclk_name [lindex $user_clk_names 1]

  # Ensure the target directory is present
  file mkdir [file dirname $ofile_name]
  file delete $ofile_name

  set of [open $ofile_name w]
  puts $of "## Generated by import_user_clk_sdc.tcl during FIM build\n"

  puts $of "##"
  puts $of "## Global namespace for defining some static properties of user clocks,"
  puts $of "## used by other user clock management scripts."
  puts $of "##"
  puts $of "namespace eval userClocks \{"
  puts $of "    variable u_clkdiv2_name \{${uclkdiv2_name}\}"
  puts $of "    variable u_clk_name \{${uclk_name}\}"
  if {[llength $user_clks] == 2} {
    set uclkdiv2 [lindex $user_clks 0]
    set uclk [lindex $user_clks 1]
    puts $of "    variable u_clkdiv2_fmax ${uclk_max_freq}"
    puts $of "    variable u_clk_fmax ${uclk_max_freq}"
  } else {
    set uclk [lindex $user_clks 0]
    set uclk_name [get_clock_info $uclk -name]
    set uclk_max_freq_div2 [expr $uclk_max_freq / 2]
    puts $of "    variable u_clkdiv2_fmax ${uclk_max_freq_div2}"
    puts $of "    variable u_clk_fmax ${uclk_max_freq}"
  }
  puts $of "\}\n"

  puts $of "##"
  puts $of "## Constrain the user clocks given a list of targets, ordered low to high."
  if {[llength $user_clks] == 2} {
    puts $of "##   (The code assumes that the relative values of the low and high clocks"
    puts $of "##   are legal and treats them independently.)"
  } else {
    puts $of "##   (On this system, \$u_clk_low_mhz is ignored.  The low clock is set to"
    puts $of "##   half the frequency of \$u_clk_high_mhz.)"
  }
  puts $of "##"
  puts $of "proc constrain_user_clks \{ u_clks \} \{"
  puts $of "    global ::userClocks"
  puts $of ""
  puts $of "    set u_clk_low_mhz \[lindex \$u_clks 0\]"
  puts $of "    set u_clk_high_mhz \[lindex \$u_clks 1\]"
  puts $of ""
  puts $of "    if \{\$u_clk_high_mhz > \$::userClocks::u_clk_fmax\} \{"
  puts $of "        set u_clk_high_mhz \$::userClocks::u_clk_fmax"
  puts $of "    \}"
  puts $of "    set mult_high \[expr \{int(ceil($p_clk_mult * \$u_clk_high_mhz))\}\]"
  set gen_high [user_clock_gen_str $uclk "high"]
  puts $of "    ${gen_high}"

  if {[llength $user_clks] == 2} {
    puts $of ""
    puts $of "    if \{\$u_clk_low_mhz > \$::userClocks::u_clkdiv2_fmax\} \{"
    puts $of "        set u_clk_low_mhz \$::userClocks::u_clkdiv2_fmax"
    puts $of "    \}"
    puts $of "    set mult_low \[expr \{int(ceil($p_clk_mult * \$u_clk_low_mhz))\}\]"
    set gen_low [user_clock_gen_str $uclkdiv2 "low"]
    puts $of "    ${gen_low}"
  }

  puts $of "\}"

  close $of

  post_message -type info "Emitted ${ofile_name}"
}


##
## Generate the create_generated_clock string for clk and a multiply by variable name.
##
proc user_clock_gen_str { clk mult_name } {
  set c_name [get_clock_info $clk -name]
  set c_master_name [get_clock_info $clk -master_clock]
  set c_master_pin [get_clock_info $clk -master_clock_pin]
  set c_master_type [get_obj_ref_type $c_master_pin]

  set c_targets [get_clock_info $clk -targets]
  if {[get_collection_size $c_targets] != 1} {
    post_message -type error "Unexpected number of targets for ${c_name}"
    qexit -error
  }

  foreach_in_collection tgt $c_targets { }
  set c_target_pin [get_node_info $tgt -name]
  set c_type [get_obj_ref_type $tgt]

  return "create_generated_clock -name \{$c_name\} -source \[get_${c_master_type} \{$c_master_pin\}\] -multiply_by \$\{mult_${mult_name}\} -divide_by 1000 -master_clock \{$c_master_name\} \[get_${c_type} \{$c_target_pin\}\]"
}


##
## How is the target referenced?
##
proc get_obj_ref_type { obj } {
  set obj_name [get_node_info $obj -name]
  set obj_type [get_node_info $obj -type]

  if {$obj_type == "reg"} {
    return "registers"
  } elseif {$obj_type == "pin"} {
    return "pins"
  } elseif {$obj_type == "port"} {
    return "ports"
  } else {
    post_message -type error "Unknown target type for ${obj_name}: ${obj_type}"
    qexit -error
  }

  return ""
}

# Copyright 2023 Intel Corporation
# SPDX-License-Identifier: MIT

##
## Dump a project's timing constraints to a single SDC file. This
## script is used to pass all timing constraints from a FIM base build
## to a PR project.
##

## Usage: crate_sdc_for_pr_compile.tcl <project> <revision> <target sdc file>
set project [lindex $::quartus(args) 0]
set revision [lindex $::quartus(args) 1]
set tgt_sdc [lindex $::quartus(args) 2]

project_open -force "${project}.qpf" -revision ${revision}

# Set a flag to avoid overconstraining the user clocks in the base SDC.
# Constraints may be added during the PR build flow.
namespace eval userClocks {
  variable no_added_constraints 1
}

create_timing_netlist -model slow
read_sdc
write_sdc -expand "${tgt_sdc}"

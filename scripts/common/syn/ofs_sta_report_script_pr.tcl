# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

##
## This script is attached to projects as TIMING_ANALYZER_REPORT_SCRIPT.
## quartus_sta will invoke it as the --report_script.
##
##  *** This script is the default for PR builds. ***
##

# Compute the achieved Fmax of user clock when it is set to "auto"
source ofs_partial_reconfig/user_clock_freqs_compute.tcl
# Generate a timing report summarizing clocks and any failed paths
source ofs_partial_reconfig/report_timing.tcl

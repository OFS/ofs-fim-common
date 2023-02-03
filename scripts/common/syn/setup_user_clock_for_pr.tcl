#####################
####  This script searches for the USER clocks and emits a
####  Tcl file that will be used during PR builds to discover
####  achieved user clock frequencies.
###
project_open -force "$::env(Q_PROJECT).qpf" -revision $::env(Q_REVISION)
create_timing_netlist -model slow
read_sdc

source $::env(IMPORT_USER_CLK_SDC_TCL_FILE)
# Make sure the target directory exists
file mkdir [file dirname $::env(WORK_USER_CLOCK_DEFS_TCL_FILE)]
# Emit user clock details
setup_user_clk_sdc $::env(USER_CLOCK_PATTERN) 600 $::env(WORK_USER_CLOCK_DEFS_TCL_FILE)

project_open -force "$::env(Q_PROJECT).qpf" -revision $::env(Q_REVISION)

# Set a flag to avoid overconstraining the user clocks in the base SDC.
# Constraints may be added during the PR build flow.
namespace eval userClocks {
  variable no_added_constraints 1
}

create_timing_netlist -model slow
read_sdc
write_sdc -expand $::env(WORK_SDC_FOR_PR_COMPILE_SDC_FILE)

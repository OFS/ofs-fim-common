##
## Import all HE LB sources into Quartus.
##

# Directory of script
set HE_LB_DIR [file dirname [info script]]

set_global_assignment -name SYSTEMVERILOG_FILE "${HE_LB_DIR}/he_lb_pkg.sv"

set_global_assignment -name SYSTEMVERILOG_FILE "${HE_LB_DIR}/he_lb_top.sv"
set_global_assignment -name SYSTEMVERILOG_FILE "${HE_LB_DIR}/he_mem_top.sv"
set_global_assignment -name SYSTEMVERILOG_FILE "${HE_LB_DIR}/he_mem_merge_banks.sv"
set_global_assignment -name SYSTEMVERILOG_FILE "${HE_LB_DIR}/he_lb_main.sv"
set_global_assignment -name SYSTEMVERILOG_FILE "${HE_LB_DIR}/he_lb_csr.sv"
set_global_assignment -name SYSTEMVERILOG_FILE "${HE_LB_DIR}/he_lb_engines.sv"
set_global_assignment -name SYSTEMVERILOG_FILE "${HE_LB_DIR}/he_lb_mux_fixed.sv"
set_global_assignment -name SYSTEMVERILOG_FILE "${HE_LB_DIR}/mode_lpbk.sv"
set_global_assignment -name SYSTEMVERILOG_FILE "${HE_LB_DIR}/mode_atomic.sv"
set_global_assignment -name SYSTEMVERILOG_FILE "${HE_LB_DIR}/mode_rdwr.sv"

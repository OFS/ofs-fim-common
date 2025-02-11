## Copyright (C) 2023 Intel Corporation
## SPDX-License-Identifier: MIT

#--------------------
# Option to disable user clock
#--------------------
if { [::config_env::verilog_macro_defined INCLUDE_USER_CLK] } {
    #--------------------
    # User Clock Filelist 
    #--------------------
    set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/user_clock/user_clock.sv
    set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/user_clock/qph_user_clk.sv

    if { [::config_env::verilog_macro_defined CONFIG_AGILEX5] } {
       set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/user_clock/ag5_user_clk_rcfg_fsm.sv
       set_global_assignment -name IP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/user_clock/ag5_user_clk_iopll_reconfig.ip
    } else {
       set_global_assignment -name IP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/user_clock/qph_user_clk_iopll_RF100M.ip
       set_global_assignment -name IP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/user_clock/qph_user_clk_iopll_reconfig.ip
    }
}

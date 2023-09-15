## Copyright (C) 2023 Intel Corporation
## SPDX-License-Identifier: MIT
#--------------------
# User Clock Filelist 
#--------------------
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/user_clock/user_clock.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/user_clock/qph_user_clk.sv
set_global_assignment -name IP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/user_clock/qph_user_clk_iopll_RF100M.ip
set_global_assignment -name IP_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/user_clock/qph_user_clk_iopll_reconfig.ip
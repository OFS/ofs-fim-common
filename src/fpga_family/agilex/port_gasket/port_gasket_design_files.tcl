## Copyright (C) 2023 Intel Corporation
## SPDX-License-Identifier: MIT
#--------------------
# PR Gasket Filelist
#--------------------
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/port_gasket/pr_slot.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/port_gasket/port_gasket.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/port_gasket/pr_slot_freeze_axis.sv

set_global_assignment -name IP_FILE ../ip_lib/ofs-common/src/fpga_family/agilex/pr/PR_IP.ip

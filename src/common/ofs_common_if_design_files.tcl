## Copyright (C) 2023 Intel Corporation
## SPDX-License-Identifier: MIT

##
## Load the subset of interfaces and modules required for AFUs inside the port
## gasket. This is the minimal set of sources loaded when generating the
## out-of-tree PR build environment.
##

# Include files
set_global_assignment -name SEARCH_PATH $::env(BUILD_ROOT_REL)/ofs-common/src/common/includes

set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/includes/ofs_fim_if_pkg.sv

set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/includes/ofs_fim_axi_mmio_if.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/includes/ofs_fim_axi_lite_if.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/includes/ofs_csr_pkg.sv

# Signal tap, available in the PR region
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/includes/ofs_jtag_if.sv

##
## Modules used in the standard afu_main(). These manage a variety of common
## features, such as:
##  - PF/VF MUX to map a single multiplexed TLP stream into per-VF streams.
##  - PR freeze logic.
##
## *** This should be the minimum collection of modules required to support ***
## *** the common afu_main(). Every file listed here is exported to the     ***
## *** out-of-tree PR build environment and every file is imported into     ***
## *** all projects.                                                        ***
##
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/lib/axi/axi_register.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/lib/axis/axis_pipeline.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/lib/axis/axis_register.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/lib/fifo/bfifo.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/lib/ram/ram_1r1w.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/lib/ram/gram_sdp.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/lib/mux/pf_vf_mux_pkg.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/lib/mux/Nmux.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/lib/mux/switch.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/lib/mux/pf_vf_mux_w_params.sv

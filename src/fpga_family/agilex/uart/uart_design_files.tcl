## Copyright (C) 2023 Intel Corporation
## SPDX-License-Identifier: MIT
#Features such as the UART are platform specific. This filelist is included in the platform filelist instead of the common filelist for this reason

set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/uart/rtl/ofs_fim_uart_if.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/uart/rtl/vuart_top.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/uart/rtl/vuart_csr_decode.sv
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/uart/rtl/csrs/vuart_csr.sv

# IP file
set_global_assignment -name IP_FILE    $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/uart/ip/uart.ip

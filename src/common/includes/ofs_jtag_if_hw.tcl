# Copyright 2023 Intel Corporation
# SPDX-License-Identifier: MIT

# 
# ofs_jtag_if "ofs_jtag_if" v1.0
#  2022.03.25.09:14:52
# 
# 

# 
# request TCL package from ACDS 22.1
# 
package require -exact qsys 22.1


# 
# module ofs_jtag_if
# 
set_module_property DESCRIPTION ""
set_module_property NAME ofs_jtag_if
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property AUTHOR ""
set_module_property GROUP "ofs sv interfaces"
set_module_property DISPLAY_NAME ofs_jtag_if
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL ofs_jtag_if
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file ofs_jtag_if.sv SYSTEM_VERILOG PATH ofs_jtag_if.sv SYSTEMVERILOG_INTERFACE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL ofs_jtag_if
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file ofs_jtag_if.sv SYSTEM_VERILOG PATH ofs_jtag_if.sv SYSTEMVERILOG_INTERFACE



# 
# parameters
# 

# 
# connection point o_virtio_tx_if
# 
add_interface svInterface svinterface start
set_interface_property svInterface ENABLED true
set_interface_property svInterface EXPORT_OF ""
set_interface_property svInterface PORT_NAME_MAP ""
set_interface_property svInterface CMSIS_SVD_VARIABLES ""
set_interface_property svInterface SVD_ADDRESS_GROUP ""
set_interface_property svInterface IPXACT_REGISTER_MAP_VARIABLES ""
set_interface_property svInterface SV_INTERFACE_TYPE "ofs_jtag_if"
set_interface_property svInterface SV_INTERFACE_MODPORT_TYPE ""

add_interface_port svInterface svInterface_tms tms bidir 1
add_interface_port svInterface svInterface_tdi tdi bidir 1
add_interface_port svInterface svInterface_tdo tdo bidir 1
add_interface_port svInterface svInterface_tck tck bidir 1
add_interface_port svInterface svInterface_tckena tckena bidir 1


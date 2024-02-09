# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

# AXI-Lite responder

package require -exact qsys 22.3

# 
# module axi4lite_rsp
# 
set_module_property DESCRIPTION "AXI-Lite responder, responds to all requests with RSP_VALUE"
set_module_property NAME axi4lite_rsp
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME axi4lite_rsp
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false
set_module_property LOAD_ELABORATION_LIMIT 0
# callbacks
# 
set_module_property ELABORATION_CALLBACK elaborate

# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL axi4lite_rsp
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file axi4lite_rsp.sv SYSTEM_VERILOG PATH axi4lite_rsp.sv TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL axi4lite_rsp
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file axi4lite_rsp.sv SYSTEM_VERILOG PATH axi4lite_rsp.sv TOP_LEVEL_FILE


# 
# parameters
# 
add_parameter AW INTEGER 18
set_parameter_property AW DEFAULT_VALUE 18
set_parameter_property AW DISPLAY_NAME AW
set_parameter_property AW UNITS None
set_parameter_property AW HDL_PARAMETER true
add_parameter DW INTEGER 64
set_parameter_property DW DEFAULT_VALUE 64
set_parameter_property DW DISPLAY_NAME DW
set_parameter_property DW UNITS None
set_parameter_property DW HDL_PARAMETER true
set_parameter_property DW AFFECTS_ELABORATION true

add_parameter WSTRB_W  INTEGER 8
set_parameter_property WSTRB_W  DEFAULT_VALUE 8
set_parameter_property WSTRB_W  DISPLAY_NAME "WSTRB_W"
set_parameter_property WSTRB_W  UNITS None
set_parameter_property WSTRB_W  DERIVED true
set_parameter_property WSTRB_W  HDL_PARAMETER true


add_parameter RSP_VALUE STD_LOGIC_VECTOR 0xFFFFFFFFFFFFFFFF
set_parameter_property RSP_VALUE DEFAULT_VALUE 0xFFFFFFFFFFFFFFFF
set_parameter_property RSP_VALUE DISPLAY_NAME RSP_VALUE
set_parameter_property RSP_VALUE UNITS None
set_parameter_property RSP_VALUE HDL_PARAMETER true
set_parameter_property RSP_VALUE WIDTH DW

add_parameter RSP_STATUS STD_LOGIC_VECTOR 0
set_parameter_property RSP_STATUS DEFAULT_VALUE 0
set_parameter_property RSP_STATUS DISPLAY_NAME RSP_STATUS
set_parameter_property RSP_STATUS UNITS None
set_parameter_property RSP_STATUS HDL_PARAMETER true
set_parameter_property RSP_STATUS WIDTH 2

# 
# display items
# 

proc add_ports {} {
   # 
   # connection point clock
   # 
   add_interface clock clock end
   set_interface_property clock ENABLED true
   set_interface_property clock EXPORT_OF ""
   set_interface_property clock PORT_NAME_MAP ""
   set_interface_property clock CMSIS_SVD_VARIABLES ""
   set_interface_property clock SVD_ADDRESS_GROUP ""
   set_interface_property clock IPXACT_REGISTER_MAP_VARIABLES ""
   
   add_interface_port clock clk clk Input 1
   
   
   # 
   # connection point reset
   # 
   add_interface reset reset end
   set_interface_property reset associatedClock clock
   set_interface_property reset synchronousEdges DEASSERT
   set_interface_property reset ENABLED true
   set_interface_property reset EXPORT_OF ""
   set_interface_property reset PORT_NAME_MAP ""
   set_interface_property reset CMSIS_SVD_VARIABLES ""
   set_interface_property reset SVD_ADDRESS_GROUP ""
   set_interface_property reset IPXACT_REGISTER_MAP_VARIABLES ""
   
   add_interface_port reset rst_n reset_n Input 1
   
   
   # 
   # connection point altera_axi4lite_slave
   # 
   add_interface altera_axi4lite_slave axi4lite end
   set_interface_property altera_axi4lite_slave associatedClock clock
   set_interface_property altera_axi4lite_slave associatedReset reset
   set_interface_property altera_axi4lite_slave readAcceptanceCapability 1
   set_interface_property altera_axi4lite_slave writeAcceptanceCapability 1
   set_interface_property altera_axi4lite_slave combinedAcceptanceCapability 1
   set_interface_property altera_axi4lite_slave bridgesToMaster ""
   set_interface_property altera_axi4lite_slave ENABLED true
   set_interface_property altera_axi4lite_slave EXPORT_OF ""
   set_interface_property altera_axi4lite_slave PORT_NAME_MAP ""
   set_interface_property altera_axi4lite_slave CMSIS_SVD_VARIABLES ""
   set_interface_property altera_axi4lite_slave SVD_ADDRESS_GROUP ""
   set_interface_property altera_axi4lite_slave IPXACT_REGISTER_MAP_VARIABLES ""
   
   add_interface_port altera_axi4lite_slave s_awaddr awaddr Input "((AW - 1)) - (0) + 1"
   add_interface_port altera_axi4lite_slave s_awprot awprot Input 3
   add_interface_port altera_axi4lite_slave s_awvalid awvalid Input 1
   add_interface_port altera_axi4lite_slave s_awready awready Output 1
   add_interface_port altera_axi4lite_slave s_wdata wdata Input "((DW - 1)) - (0) + 1"
   add_interface_port altera_axi4lite_slave s_wstrb wstrb Input "((WSTRB_W - 1)) - (0) + 1"
   add_interface_port altera_axi4lite_slave s_wvalid wvalid Input 1
   add_interface_port altera_axi4lite_slave s_wready wready Output 1
   add_interface_port altera_axi4lite_slave s_bresp bresp Output 2
   add_interface_port altera_axi4lite_slave s_bvalid bvalid Output 1
   add_interface_port altera_axi4lite_slave s_bready bready Input 1
   add_interface_port altera_axi4lite_slave s_araddr araddr Input "((AW - 1)) - (0) + 1"
   add_interface_port altera_axi4lite_slave s_arprot arprot Input 3
   add_interface_port altera_axi4lite_slave s_arvalid arvalid Input 1
   add_interface_port altera_axi4lite_slave s_arready arready Output 1
   add_interface_port altera_axi4lite_slave s_rdata rdata Output "((DW - 1)) - (0) + 1"
   add_interface_port altera_axi4lite_slave s_rresp rresp Output 2
   add_interface_port altera_axi4lite_slave s_rvalid rvalid Output 1
   add_interface_port altera_axi4lite_slave s_rready rready Input 1
   
}

proc elaborate {} {
    set_parameter_value WSTRB_W  [expr [get_parameter_value DW] /8]
    add_ports
}

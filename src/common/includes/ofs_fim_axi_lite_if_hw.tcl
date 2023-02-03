# 
# ofs_fim_axi_lite_if "ofs_fim_axi_lite_if" v1.0
#  2022.03.25.09:14:52
# 
# 

# 
# request TCL package from ACDS 22.1
# 
package require -exact qsys 22.1


# 
# module pcie_ss_axis_if
# 
set_module_property DESCRIPTION ""
set_module_property NAME ofs_fim_axi_lite_if
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property GROUP "ofs sv interfaces"
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME ofs_fim_axi_lite_if
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL ofs_fim_axi_lite_if
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file ofs_fim_axi_lite_if.sv SYSTEM_VERILOG PATH ofs_fim_axi_lite_if.sv SYSTEMVERILOG_INTERFACE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL ofs_fim_axi_lite_if
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file ofs_fim_axi_lite_if.sv SYSTEM_VERILOG PATH ofs_fim_axi_lite_if.sv SYSTEMVERILOG_INTERFACE


# 
# parameters
# 
add_parameter AWADDR_WIDTH INTEGER 21 ""
set_parameter_property AWADDR_WIDTH DEFAULT_VALUE 21
set_parameter_property AWADDR_WIDTH DISPLAY_NAME AWADDR_WIDTH
set_parameter_property AWADDR_WIDTH UNITS None
set_parameter_property AWADDR_WIDTH ALLOWED_RANGES -2147483648:2147483647
set_parameter_property AWADDR_WIDTH DESCRIPTION ""
set_parameter_property AWADDR_WIDTH AFFECTS_GENERATION false
set_parameter_property AWADDR_WIDTH HDL_PARAMETER true
set_parameter_property AWADDR_WIDTH EXPORT true

add_parameter WDATA_WIDTH INTEGER 64 ""
set_parameter_property WDATA_WIDTH DEFAULT_VALUE 64
set_parameter_property WDATA_WIDTH DISPLAY_NAME WDATA_WIDTH
set_parameter_property WDATA_WIDTH UNITS None
set_parameter_property WDATA_WIDTH ALLOWED_RANGES -2147483648:2147483647
set_parameter_property WDATA_WIDTH DESCRIPTION ""
set_parameter_property WDATA_WIDTH AFFECTS_GENERATION false
set_parameter_property WDATA_WIDTH HDL_PARAMETER true
set_parameter_property WDATA_WIDTH EXPORT true

add_parameter ARADDR_WIDTH INTEGER 21 ""
set_parameter_property ARADDR_WIDTH DEFAULT_VALUE 21
set_parameter_property ARADDR_WIDTH DISPLAY_NAME ARADDR_WIDTH
set_parameter_property ARADDR_WIDTH UNITS None
set_parameter_property ARADDR_WIDTH ALLOWED_RANGES -2147483648:2147483647
set_parameter_property ARADDR_WIDTH DESCRIPTION ""
set_parameter_property ARADDR_WIDTH AFFECTS_GENERATION false
set_parameter_property ARADDR_WIDTH HDL_PARAMETER true
set_parameter_property ARADDR_WIDTH EXPORT true

add_parameter RDATA_WIDTH INTEGER 64 ""
set_parameter_property RDATA_WIDTH DEFAULT_VALUE 64
set_parameter_property RDATA_WIDTH DISPLAY_NAME RDATA_WIDTH
set_parameter_property RDATA_WIDTH UNITS None
set_parameter_property RDATA_WIDTH ALLOWED_RANGES -2147483648:2147483647
set_parameter_property RDATA_WIDTH DESCRIPTION ""
set_parameter_property RDATA_WIDTH AFFECTS_GENERATION false
set_parameter_property RDATA_WIDTH HDL_PARAMETER true
set_parameter_property RDATA_WIDTH EXPORT true

# 
# connection point svInterface
# 
add_interface svInterface svinterface start
set_interface_property svInterface ENABLED true
set_interface_property svInterface EXPORT_OF ""
set_interface_property svInterface PORT_NAME_MAP ""
set_interface_property svInterface CMSIS_SVD_VARIABLES ""
set_interface_property svInterface SVD_ADDRESS_GROUP ""
set_interface_property svInterface IPXACT_REGISTER_MAP_VARIABLES ""
set_interface_property svInterface SV_INTERFACE_TYPE "ofs_fim_axi_lite_if"
set_interface_property svInterface SV_INTERFACE_MODPORT_TYPE ""

# Write address channel
add_interface_port svInterface svInterface_awready awready bidir 1
add_interface_port svInterface svInterface_awvalid awvalid bidir 1
add_interface_port svInterface svInterface_awaddr awaddr bidir AWADDR_WIDTH
add_interface_port svInterface svInterface_awprot awprot bidir 512

# Write data channel
add_interface_port svInterface svInterfacef_wready wready bidir 1
add_interface_port svInterface svInterface_wvalid wvalid bidir 1
add_interface_port svInterface svInterface_wdata wdata bidir WDATA_WIDTH
add_interface_port svInterface svInterface_wstrb wstrb bidir WDATA_WIDTH/8

# Write response channel
add_interface_port svInterface svInterface_bready bready bidir 1
add_interface_port svInterface svInterface_bvalid bvalid bidir 1
add_interface_port svInterface svInterface_bresp bresp bidir 1

# Read address channel
add_interface_port svInterface svInterface_arready arready bidir 1
add_interface_port svInterface svInterface_arvalid arvalid bidir 1
add_interface_port svInterface svInterface_araddr araddr bidir ARADDR_WIDTH
add_interface_port svInterface svInterface_arprot arprot bidir 2

# Read response channel
add_interface_port svInterface svInterface_rready rready bidir 1
add_interface_port svInterface svInterface_rvalid rvalid bidir 1
add_interface_port svInterface svInterface_rdata rdata bidir RDATA_WIDTH
add_interface_port svInterface svInterface_rresp rresp bidir 1

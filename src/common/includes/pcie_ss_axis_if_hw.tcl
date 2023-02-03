# 
# pcie_ss_axis_if "pcie_ss_axis_if" v1.0
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
set_module_property NAME pcie_ss_axis_if
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property AUTHOR ""
set_module_property GROUP "ofs sv interfaces"
set_module_property DISPLAY_NAME pcie_ss_axis_if
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL pcie_ss_axis_if
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file pcie_ss_axis_if.sv SYSTEM_VERILOG PATH pcie_ss_axis_if.sv SYSTEMVERILOG_INTERFACE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL pcie_ss_axis_if
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file pcie_ss_axis_if.sv SYSTEM_VERILOG PATH pcie_ss_axis_if.sv SYSTEMVERILOG_INTERFACE



# 
# parameters
# 
add_parameter USER_W INTEGER 10 ""
set_parameter_property USER_W DEFAULT_VALUE 10
set_parameter_property USER_W DISPLAY_NAME USER_W
set_parameter_property USER_W UNITS None
set_parameter_property USER_W ALLOWED_RANGES -2147483648:2147483647
set_parameter_property USER_W DESCRIPTION ""
set_parameter_property USER_W AFFECTS_GENERATION false
set_parameter_property USER_W HDL_PARAMETER true
set_parameter_property USER_W EXPORT true

add_parameter DATA_W INTEGER 512 ""
set_parameter_property DATA_W DEFAULT_VALUE 512
set_parameter_property DATA_W DISPLAY_NAME DATA_W
set_parameter_property DATA_W UNITS None
set_parameter_property DATA_W ALLOWED_RANGES -2147483648:2147483647
set_parameter_property DATA_W DESCRIPTION ""
set_parameter_property DATA_W AFFECTS_GENERATION false
set_parameter_property DATA_W HDL_PARAMETER true
set_parameter_property DATA_W EXPORT true

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
set_interface_property svInterface SV_INTERFACE_TYPE "pcie_ss_axis_if"
set_interface_property svInterface SV_INTERFACE_MODPORT_TYPE ""

add_interface_port svInterface svInterface_tvalid tvalid bidir 1
add_interface_port svInterface svInterface_tlast tlast bidir 1
add_interface_port svInterface svInterface_tuser_vendor tuser bidir USER_W
add_interface_port svInterface svInterface_tdata tdata bidir DATA_W
add_interface_port svInterface svInterfacef_tkeep tkeep bidir DATA_W/8
add_interface_port svInterface svInterface_tready tready bidir 1

# 
# connection point clk
# 
add_interface clk clock end
set_interface_property clk ENABLED true
set_interface_property clk EXPORT_OF ""
set_interface_property clk PORT_NAME_MAP ""
set_interface_property clk CMSIS_SVD_VARIABLES ""
set_interface_property clk SVD_ADDRESS_GROUP ""
set_interface_property clk IPXACT_REGISTER_MAP_VARIABLES ""

add_interface_port clk clk clk Input 1


# 
# connection point rst_n
# 
add_interface rst_n reset end
set_interface_property rst_n associatedClock clk
set_interface_property rst_n synchronousEdges DEASSERT
set_interface_property rst_n ENABLED true
set_interface_property rst_n EXPORT_OF ""
set_interface_property rst_n PORT_NAME_MAP ""
set_interface_property rst_n CMSIS_SVD_VARIABLES ""
set_interface_property rst_n SVD_ADDRESS_GROUP ""
set_interface_property rst_n IPXACT_REGISTER_MAP_VARIABLES ""

add_interface_port rst_n rst_n reset_n Input 1

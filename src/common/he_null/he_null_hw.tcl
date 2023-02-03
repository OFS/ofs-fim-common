# TCL File Generated by Component Editor 22.2
# Wed Mar 09 16:14:35 PST 2022
# DO NOT MODIFY


# 
# he_null "he_null" v1.0
#  2022.03.09.16:14:35
# 
# 

# 
# request TCL package from ACDS 22.1
# 
package require -exact qsys 22.1


# 
# module he_null
# 
set_module_property DESCRIPTION ""
set_module_property NAME he_null
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property GROUP "ofs exercisers"
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME he_null
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false
set_module_property LOAD_ELABORATION_LIMIT 0


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL he_null
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
#add_fileset_file ofs_fim_cfg_pkg.sv SYSTEM_VERILOG PATH ../../../fims/n6000/includes/ofs_fim_cfg_pkg.sv
add_fileset_file ofs_pcie_ss_cfg.vh OTHER PATH ../includes/ofs_pcie_ss_cfg.vh
#add_fileset_file ofs_pcie_ss_cfg_pkg.sv SYSTEM_VERILOG PATH ../../../includes/ofs_pcie_ss_cfg_pkg.sv
add_fileset_file ofs_pcie_ss_plat_cfg.vh OTHER PATH ../fims/n6000/includes/ofs_pcie_ss_plat_cfg.vh
#add_fileset_file ofs_pcie_ss_plat_cfg_pkg.sv SYSTEM_VERILOG PATH ../../../fims/n6000/includes/ofs_pcie_ss_plat_cfg_pkg.sv
#add_fileset_file pcie_ss_axis_if.sv SYSTEM_VERILOG PATH ../../../includes/pcie_ss_axis_if.sv SYSTEMVERILOG_INTERFACE
#add_fileset_file pcie_ss_hdr_pkg.sv SYSTEM_VERILOG PATH ../../../includes/pcie_ss_hdr_pkg.sv
#add_fileset_file pcie_ss_pkg.sv SYSTEM_VERILOG PATH ../../../includes/pcie_ss_pkg.sv
add_fileset_file he_null.sv SYSTEM_VERILOG PATH he_null.sv TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL he_null
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
#add_fileset_file ofs_fim_cfg_pkg.sv SYSTEM_VERILOG PATH ../../../fims/n6000/includes/ofs_fim_cfg_pkg.sv
add_fileset_file ofs_pcie_ss_cfg.vh OTHER PATH ../includes/ofs_pcie_ss_cfg.vh
#add_fileset_file ofs_pcie_ss_cfg_pkg.sv SYSTEM_VERILOG PATH ../../../includes/ofs_pcie_ss_cfg_pkg.sv
add_fileset_file ofs_pcie_ss_plat_cfg.vh OTHER PATH ../fims/n6000/includes/ofs_pcie_ss_plat_cfg.vh
#add_fileset_file ofs_pcie_ss_plat_cfg_pkg.sv SYSTEM_VERILOG PATH ../../../fims/n6000/includes/ofs_pcie_ss_plat_cfg_pkg.sv
#add_fileset_file pcie_ss_axis_if.sv SYSTEM_VERILOG PATH ../../../includes/pcie_ss_axis_if.sv SYSTEMVERILOG_INTERFACE
#add_fileset_file pcie_ss_hdr_pkg.sv SYSTEM_VERILOG PATH ../../../includes/pcie_ss_hdr_pkg.sv
#add_fileset_file pcie_ss_pkg.sv SYSTEM_VERILOG PATH ../../../includes/pcie_ss_pkg.sv
add_fileset_file he_null.sv SYSTEM_VERILOG PATH he_null.sv TOP_LEVEL_FILE



# 
# parameters
# 
add_parameter CSR_DATA_WIDTH INTEGER 64
set_parameter_property CSR_DATA_WIDTH DEFAULT_VALUE 64
set_parameter_property CSR_DATA_WIDTH DISPLAY_NAME CSR_DATA_WIDTH
set_parameter_property CSR_DATA_WIDTH UNITS None
set_parameter_property CSR_DATA_WIDTH ALLOWED_RANGES -2147483648:2147483647
set_parameter_property CSR_DATA_WIDTH AFFECTS_GENERATION false
set_parameter_property CSR_DATA_WIDTH HDL_PARAMETER true
set_parameter_property CSR_DATA_WIDTH EXPORT true
add_parameter CSR_ADDR_WIDTH INTEGER 16
set_parameter_property CSR_ADDR_WIDTH DEFAULT_VALUE 16
set_parameter_property CSR_ADDR_WIDTH DISPLAY_NAME CSR_ADDR_WIDTH
set_parameter_property CSR_ADDR_WIDTH UNITS None
set_parameter_property CSR_ADDR_WIDTH ALLOWED_RANGES -2147483648:2147483647
set_parameter_property CSR_ADDR_WIDTH AFFECTS_GENERATION false
set_parameter_property CSR_ADDR_WIDTH HDL_PARAMETER true
set_parameter_property CSR_ADDR_WIDTH EXPORT true
add_parameter CSR_DEPTH INTEGER 4
set_parameter_property CSR_DEPTH DEFAULT_VALUE 4
set_parameter_property CSR_DEPTH DISPLAY_NAME CSR_DEPTH
set_parameter_property CSR_DEPTH UNITS None
set_parameter_property CSR_DEPTH ALLOWED_RANGES -2147483648:2147483647
set_parameter_property CSR_DEPTH AFFECTS_GENERATION false
set_parameter_property CSR_DEPTH HDL_PARAMETER true
set_parameter_property CSR_DEPTH EXPORT true
add_parameter PF_ID INTEGER 3
set_parameter_property PF_ID DEFAULT_VALUE 3
set_parameter_property PF_ID DISPLAY_NAME PF_ID
set_parameter_property PF_ID UNITS None
set_parameter_property PF_ID ALLOWED_RANGES -2147483648:2147483647
set_parameter_property PF_ID AFFECTS_GENERATION false
set_parameter_property PF_ID HDL_PARAMETER true
set_parameter_property PF_ID EXPORT true
add_parameter VF_ID INTEGER 0
set_parameter_property VF_ID DEFAULT_VALUE 0
set_parameter_property VF_ID DISPLAY_NAME VF_ID
set_parameter_property VF_ID UNITS None
set_parameter_property VF_ID ALLOWED_RANGES -2147483648:2147483647
set_parameter_property VF_ID AFFECTS_GENERATION false
set_parameter_property VF_ID HDL_PARAMETER true
set_parameter_property VF_ID EXPORT true
add_parameter VF_ACTIVE INTEGER 0
set_parameter_property VF_ACTIVE DEFAULT_VALUE 0
set_parameter_property VF_ACTIVE DISPLAY_NAME VF_ACTIVE
set_parameter_property VF_ACTIVE UNITS None
set_parameter_property VF_ACTIVE ALLOWED_RANGES -2147483648:2147483647
set_parameter_property VF_ACTIVE AFFECTS_GENERATION false
set_parameter_property VF_ACTIVE HDL_PARAMETER true
set_parameter_property VF_ACTIVE EXPORT true
add_parameter DATA_W INTEGER 512
set_parameter_property DATA_W DEFAULT_VALUE 512
set_parameter_property DATA_W DISPLAY_NAME DATA_W
set_parameter_property DATA_W UNITS None
set_parameter_property DATA_W ALLOWED_RANGES -2147483648:2147483647
set_parameter_property DATA_W AFFECTS_GENERATION false
#set_parameter_property DATA_W HDL_PARAMETER true
set_parameter_property DATA_W EXPORT true
add_parameter USER_W INTEGER 10
set_parameter_property USER_W DEFAULT_VALUE 10
set_parameter_property USER_W DISPLAY_NAME USER_W
set_parameter_property USER_W UNITS None
set_parameter_property USER_W ALLOWED_RANGES -2147483648:2147483647
set_parameter_property USER_W AFFECTS_GENERATION false
#set_parameter_property USER_W HDL_PARAMETER true
set_parameter_property USER_W EXPORT true

# 
# display items
# 


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
# connection point reset_sink
# 
add_interface reset_sink reset end
set_interface_property reset_sink associatedClock clock
set_interface_property reset_sink synchronousEdges DEASSERT
set_interface_property reset_sink ENABLED true
set_interface_property reset_sink EXPORT_OF ""
set_interface_property reset_sink PORT_NAME_MAP ""
set_interface_property reset_sink CMSIS_SVD_VARIABLES ""
set_interface_property reset_sink SVD_ADDRESS_GROUP ""
set_interface_property reset_sink IPXACT_REGISTER_MAP_VARIABLES ""

add_interface_port reset_sink rst_n reset_n Input 1

# 
# connection point o_tx_if
# 
add_interface o_tx_if axi4stream start
set_interface_property o_tx_if associatedClock clock
set_interface_property o_tx_if associatedReset reset_sink
set_interface_property o_tx_if ENABLED true
set_interface_property o_tx_if EXPORT_OF ""
set_interface_property o_tx_if PORT_NAME_MAP ""
set_interface_property o_tx_if CMSIS_SVD_VARIABLES ""
set_interface_property o_tx_if SVD_ADDRESS_GROUP ""
set_interface_property o_tx_if IPXACT_REGISTER_MAP_VARIABLES ""
set_interface_property o_tx_if SV_INTERFACE_TYPE pcie_ss_axis_if
set_interface_property o_tx_if SV_INTERFACE_MODPORT_TYPE source

add_interface_port o_tx_if o_tx_if_tvalid tvalid Output 1
add_interface_port o_tx_if o_tx_if_tlast tlast Output 1
add_interface_port o_tx_if o_tx_if_tuser_vendor tuser Output USER_W
add_interface_port o_tx_if o_tx_if_tdata tdata Output DATA_W
add_interface_port o_tx_if o_tx_if_tkeep tkeep Output DATA_W/8
add_interface_port o_tx_if o_tx_if_tready tready Input 1


# 
# connection point i_rx_if
# 
add_interface i_rx_if axi4stream end
set_interface_property i_rx_if associatedClock clock
set_interface_property i_rx_if associatedReset reset_sink
set_interface_property i_rx_if ENABLED true
set_interface_property i_rx_if EXPORT_OF ""
set_interface_property i_rx_if PORT_NAME_MAP ""
set_interface_property i_rx_if CMSIS_SVD_VARIABLES ""
set_interface_property i_rx_if SVD_ADDRESS_GROUP ""
set_interface_property i_rx_if IPXACT_REGISTER_MAP_VARIABLES ""
set_interface_property i_rx_if SV_INTERFACE_TYPE pcie_ss_axis_if
set_interface_property i_rx_if SV_INTERFACE_MODPORT_TYPE sink

add_interface_port i_rx_if i_rx_if_tvalid tvalid Input 1
add_interface_port i_rx_if i_rx_if_tlast tlast Input 1
add_interface_port i_rx_if i_rx_if_tuser_vendor tuser Input USER_W
add_interface_port i_rx_if i_rx_if_tdata tdata Input DATA_W
add_interface_port i_rx_if i_rx_if_tkeep tkeep Input DATA_W/8
add_interface_port i_rx_if i_rx_if_tready tready Output 1


# 
# connection point flr_rst_n
# 
add_interface flr_rst_n conduit end
set_interface_property flr_rst_n associatedClock clock
set_interface_property flr_rst_n ENABLED true

add_interface_port flr_rst_n i_flr_rst_n flr_rst_n Input 1


# 
# connection point flr_ack
# 
add_interface flr_ack conduit end
set_interface_property flr_ack associatedClock clock
set_interface_property flr_ack ENABLED true
add_interface_port flr_ack o_flr_ack flr_ack Output 1

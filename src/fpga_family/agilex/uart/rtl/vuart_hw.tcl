# Copyright (C) 2022 Intel Corporation
# SPDX-License-Identifier: MIT

# TCL File Generated by Component Editor 22.2
# Thu Mar 17 15:20:27 PDT 2022
# DO NOT MODIFY


# 
# vuart "vuart" v1.0
#  2022.03.17.15:20:27
# 
# 

# 
# request TCL package from ACDS 22.1
# 
package require -exact qsys 22.1


# 
# module vuart
# 
set_module_property DESCRIPTION ""
set_module_property NAME vuart
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property GROUP "ofs infra"
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME vuart
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
set_fileset_property QUARTUS_SYNTH TOP_LEVEL vuart_top_pd
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
#add_fileset_file axi_lite_if_conn.sv SYSTEM_VERILOG PATH axi_lite_if_conn.sv
add_fileset_file vuart_csr_decode.sv SYSTEM_VERILOG PATH vuart_csr_decode.sv
add_fileset_file vuart_csr.sv SYSTEM_VERILOG PATH csrs/vuart_csr.sv
#add_fileset_file vuart_csr_template.sv SYSTEM_VERILOG PATH csrs/vuart_csr_template.sv
#add_fileset_file uart.v SYSTEM_VERILOG PATH ip/uart/synth/uart.v
add_fileset_file fim_resync.sv SYSTEM_VERILOG PATH ../../../../common/lib/sync/fim_resync.sv
add_fileset_file pfa_master.sv SYSTEM_VERILOG PATH ../../../../common/lib/pfa/pfa_master.sv
add_fileset_file ofs_fim_uart_if.sv SYSTEM_VERILOG PATH ofs_fim_uart_if.sv SYSTEMVERILOG_INTERFACE
add_fileset_file vuart_top_pd.sv SYSTEM_VERILOG PATH vuart_top_pd.sv TOP_LEVEL_FILE



add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL vuart_top_pd
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
#add_fileset_file axi_lite_if_conn.sv SYSTEM_VERILOG PATH axi_lite_if_conn.sv
add_fileset_file vuart_csr_decode.sv SYSTEM_VERILOG PATH vuart_csr_decode.sv
add_fileset_file vuart_csr.sv SYSTEM_VERILOG PATH csrs/vuart_csr.sv
#add_fileset_file vuart_csr_template.sv SYSTEM_VERILOG PATH csrs/vuart_csr_template.sv
#add_fileset_file uart.v SYSTEM_VERILOG PATH ip/uart/synth/uart.v
add_fileset_file fim_resync.sv SYSTEM_VERILOG PATH ../../../../common/lib/sync/fim_resync.sv
add_fileset_file pfa_master.sv SYSTEM_VERILOG PATH ../../../../common/lib/pfa/pfa_master.sv
add_fileset_file ofs_fim_uart_if.sv SYSTEM_VERILOG PATH ofs_fim_uart_if.sv SYSTEMVERILOG_INTERFACE
add_fileset_file vuart_top_pd.sv SYSTEM_VERILOG PATH vuart_top_pd.sv TOP_LEVEL_FILE

# 
# parameters
# 
add_parameter DATA_WIDTH INTEGER 0
set_parameter_property DATA_WIDTH DEFAULT_VALUE 64
set_parameter_property DATA_WIDTH DISPLAY_NAME DATA_WIDTH
set_parameter_property DATA_WIDTH UNITS None
set_parameter_property DATA_WIDTH ALLOWED_RANGES -2147483648:2147483647
set_parameter_property DATA_WIDTH AFFECTS_GENERATION false
set_parameter_property DATA_WIDTH HDL_PARAMETER true
set_parameter_property DATA_WIDTH EXPORT true
add_parameter ADDR_WIDTH INTEGER 0
set_parameter_property ADDR_WIDTH DEFAULT_VALUE 20
set_parameter_property ADDR_WIDTH DISPLAY_NAME ADDR_WIDTH
set_parameter_property ADDR_WIDTH UNITS None
set_parameter_property ADDR_WIDTH ALLOWED_RANGES -2147483648:2147483647
set_parameter_property ADDR_WIDTH AFFECTS_GENERATION false
set_parameter_property ADDR_WIDTH HDL_PARAMETER true
set_parameter_property ADDR_WIDTH EXPORT true
add_parameter ST2MM_DFH_MSIX_ADDR INTEGER 0
set_parameter_property ST2MM_DFH_MSIX_ADDR DEFAULT_VALUE 40000 
set_parameter_property ST2MM_DFH_MSIX_ADDR DISPLAY_NAME ST2MM_DFH_MSIX_ADDR 
set_parameter_property ST2MM_DFH_MSIX_ADDR UNITS None
set_parameter_property ST2MM_DFH_MSIX_ADDR ALLOWED_RANGES -2147483648:2147483647
set_parameter_property ST2MM_DFH_MSIX_ADDR AFFECTS_GENERATION false
set_parameter_property ST2MM_DFH_MSIX_ADDR HDL_PARAMETER true
set_parameter_property ST2MM_DFH_MSIX_ADDR EXPORT true

# ofs_fim_axi_lite_if parameters
add_parameter AWADDR_WIDTH INTEGER 21 ""
set_parameter_property AWADDR_WIDTH DEFAULT_VALUE 21
set_parameter_property AWADDR_WIDTH DISPLAY_NAME AWADDR_WIDTH
set_parameter_property AWADDR_WIDTH UNITS None
set_parameter_property AWADDR_WIDTH ALLOWED_RANGES -2147483648:2147483647
set_parameter_property AWADDR_WIDTH DESCRIPTION ""
set_parameter_property AWADDR_WIDTH AFFECTS_GENERATION false
#set_parameter_property AWADDR_WIDTH HDL_PARAMETER true
set_parameter_property AWADDR_WIDTH EXPORT true

add_parameter WDATA_WIDTH INTEGER 64 ""
set_parameter_property WDATA_WIDTH DEFAULT_VALUE 64
set_parameter_property WDATA_WIDTH DISPLAY_NAME WDATA_WIDTH
set_parameter_property WDATA_WIDTH UNITS None
set_parameter_property WDATA_WIDTH ALLOWED_RANGES -2147483648:2147483647
set_parameter_property WDATA_WIDTH DESCRIPTION ""
set_parameter_property WDATA_WIDTH AFFECTS_GENERATION false
#set_parameter_property WDATA_WIDTH HDL_PARAMETER true
set_parameter_property WDATA_WIDTH EXPORT true

add_parameter ARADDR_WIDTH INTEGER 21 ""
set_parameter_property ARADDR_WIDTH DEFAULT_VALUE 21
set_parameter_property ARADDR_WIDTH DISPLAY_NAME ARADDR_WIDTH
set_parameter_property ARADDR_WIDTH UNITS None
set_parameter_property ARADDR_WIDTH ALLOWED_RANGES -2147483648:2147483647
set_parameter_property ARADDR_WIDTH DESCRIPTION ""
set_parameter_property ARADDR_WIDTH AFFECTS_GENERATION false
#set_parameter_property ARADDR_WIDTH HDL_PARAMETER true
set_parameter_property ARADDR_WIDTH EXPORT true

add_parameter RDATA_WIDTH INTEGER 64 ""
set_parameter_property RDATA_WIDTH DEFAULT_VALUE 64
set_parameter_property RDATA_WIDTH DISPLAY_NAME RDATA_WIDTH
set_parameter_property RDATA_WIDTH UNITS None
set_parameter_property RDATA_WIDTH ALLOWED_RANGES -2147483648:2147483647
set_parameter_property RDATA_WIDTH DESCRIPTION ""
set_parameter_property RDATA_WIDTH AFFECTS_GENERATION false
#set_parameter_property RDATA_WIDTH HDL_PARAMETER true
set_parameter_property RDATA_WIDTH EXPORT true

# 
# display items
# 

# 
# connection point clk
# 
add_interface clk_csr clock end
set_interface_property clk_csr ENABLED true
set_interface_property clk_csr EXPORT_OF ""
set_interface_property clk_csr PORT_NAME_MAP ""
set_interface_property clk_csr CMSIS_SVD_VARIABLES ""
set_interface_property clk_csr SVD_ADDRESS_GROUP ""
set_interface_property clk_csr IPXACT_REGISTER_MAP_VARIABLES ""

add_interface_port clk_csr clk_csr clk Input 1

# 
# connection point rst_n_csr
# 
add_interface rst_n_csr reset end
set_interface_property rst_n_csr associatedClock clk_csr
set_interface_property rst_n_csr synchronousEdges DEASSERT
set_interface_property rst_n_csr ENABLED true
set_interface_property rst_n_csr EXPORT_OF ""
set_interface_property rst_n_csr PORT_NAME_MAP ""
set_interface_property rst_n_csr CMSIS_SVD_VARIABLES ""
set_interface_property rst_n_csr SVD_ADDRESS_GROUP ""
set_interface_property rst_n_csr IPXACT_REGISTER_MAP_VARIABLES ""

add_interface_port rst_n_csr rst_n_csr reset_n Input 1

# 
# connection point clk_50m 
 
add_interface clk_50m clock end
set_interface_property clk_50m ENABLED true
set_interface_property clk_50m EXPORT_OF ""
set_interface_property clk_50m PORT_NAME_MAP ""
set_interface_property clk_50m CMSIS_SVD_VARIABLES ""
set_interface_property clk_50m SVD_ADDRESS_GROUP ""
set_interface_property clk_50m IPXACT_REGISTER_MAP_VARIABLES ""

add_interface_port clk_50m clk_50m clk Input 1

 
# connection point rst_n_50m 
# 
add_interface rst_n_50m reset end
set_interface_property rst_n_50m associatedClock clk_50m
set_interface_property rst_n_50m synchronousEdges DEASSERT
set_interface_property rst_n_50m ENABLED true
set_interface_property rst_n_50m EXPORT_OF ""
set_interface_property rst_n_50m PORT_NAME_MAP ""
set_interface_property rst_n_50m CMSIS_SVD_VARIABLES ""
set_interface_property rst_n_50m SVD_ADDRESS_GROUP ""
set_interface_property rst_n_50m IPXACT_REGISTER_MAP_VARIABLES ""

add_interface_port rst_n_50m rst_n_50m reset_n Input 1

# connection point clk_50m 
 
add_interface pwr_good_csr_clk_n clock end
set_interface_property pwr_good_csr_clk_n ENABLED true
set_interface_property pwr_good_csr_clk_n EXPORT_OF ""
set_interface_property pwr_good_csr_clk_n PORT_NAME_MAP ""
set_interface_property pwr_good_csr_clk_n CMSIS_SVD_VARIABLES ""
set_interface_property pwr_good_csr_clk_n SVD_ADDRESS_GROUP ""
set_interface_property pwr_good_csr_clk_n IPXACT_REGISTER_MAP_VARIABLES ""

add_interface_port pwr_good_csr_clk_n pwr_good_csr_clk_n clk Input 1 
# 
# connection point csr_lite_m_if
# 
add_interface csr_lite_m_if axi4lite start
set_interface_property csr_lite_m_if associatedClock clk_csr
set_interface_property csr_lite_m_if associatedReset rst_n_csr
set_interface_property csr_lite_m_if ENABLED true
set_interface_property csr_lite_m_if EXPORT_OF ""
set_interface_property csr_lite_m_if PORT_NAME_MAP ""
set_interface_property csr_lite_m_if CMSIS_SVD_VARIABLES ""
set_interface_property csr_lite_m_if SVD_ADDRESS_GROUP ""
set_interface_property csr_lite_m_if IPXACT_REGISTER_MAP_VARIABLES ""
set_interface_property csr_lite_m_if SV_INTERFACE_TYPE ofs_fim_axi_lite_if
#set_interface_property csr_lite_m_if SV_INTERFACE_MODPORT_TYPE "master"

# Write address channel
add_interface_port csr_lite_m_if csr_lite_m_if_awready awready input 1
add_interface_port csr_lite_m_if csr_lite_m_if_awvalid awvalid output 1
add_interface_port csr_lite_m_if csr_lite_m_if_awaddr awaddr output AWADDR_WIDTH
add_interface_port csr_lite_m_if csr_lite_m_if_awprot awprot output 3
# Write data channel
add_interface_port csr_lite_m_if csr_lite_m_if_if_wready wready input 1
add_interface_port csr_lite_m_if csr_lite_m_if_wvalid wvalid output 1
add_interface_port csr_lite_m_if csr_lite_m_if_wdata wdata output WDATA_WIDTH
add_interface_port csr_lite_m_if csr_lite_m_if_wstrb wstrb output WDATA_WIDTH/8
# Write response channel
add_interface_port csr_lite_m_if csr_lite_m_if_bready bready output 1
add_interface_port csr_lite_m_if csr_lite_m_if_bvalid bvalid input 1
add_interface_port csr_lite_m_if csr_lite_m_if_bresp bresp input 2
# Read address channel
add_interface_port csr_lite_m_if csr_lite_m_if_arready arready input 1
add_interface_port csr_lite_m_if csr_lite_m_if_arvalid arvalid output 1
add_interface_port csr_lite_m_if csr_lite_m_if_araddr araddr output ARADDR_WIDTH
add_interface_port csr_lite_m_if csr_lite_m_if_arprot arprot output 3
# Read response channel
add_interface_port csr_lite_m_if csr_lite_m_if_rready rready output 1
add_interface_port csr_lite_m_if csr_lite_m_if_rvalid rvalid input 1
add_interface_port csr_lite_m_if csr_lite_m_if_rdata rdata input RDATA_WIDTH
add_interface_port csr_lite_m_if csr_lite_m_if_rresp rresp input 2



# 
# connection point csr_lite_if
# 
add_interface csr_lite_if axi4lite end
set_interface_property csr_lite_if associatedClock clk_csr
set_interface_property csr_lite_if associatedReset rst_n_csr
set_interface_property csr_lite_if ENABLED true
set_interface_property csr_lite_if EXPORT_OF ""
set_interface_property csr_lite_if PORT_NAME_MAP ""
set_interface_property csr_lite_if CMSIS_SVD_VARIABLES ""
set_interface_property csr_lite_if SVD_ADDRESS_GROUP ""
set_interface_property csr_lite_if IPXACT_REGISTER_MAP_VARIABLES ""
set_interface_property csr_lite_if SV_INTERFACE_TYPE ofs_fim_axi_lite_if
#set_interface_property csr_lite_if SV_INTERFACE_MODPORT_TYPE "slave"

# Write address channel
add_interface_port csr_lite_if csr_lite_if_awready awready output 1
add_interface_port csr_lite_if csr_lite_if_awvalid awvalid input 1
add_interface_port csr_lite_if csr_lite_if_awaddr awaddr input AWADDR_WIDTH
add_interface_port csr_lite_if csr_lite_if_awprot awprot input 3
# Write data channel
add_interface_port csr_lite_if csr_lite_if_wready wready output 1
add_interface_port csr_lite_if csr_lite_if_wvalid wvalid input 1
add_interface_port csr_lite_if csr_lite_if_wdata wdata input WDATA_WIDTH
add_interface_port csr_lite_if csr_lite_if_wstrb wstrb input WDATA_WIDTH/8
# Write response channel
add_interface_port csr_lite_if csr_lite_if_bready bready input 1
add_interface_port csr_lite_if csr_lite_if_bvalid bvalid output 1
add_interface_port csr_lite_if csr_lite_if_bresp bresp output 2
# Read address channel
add_interface_port csr_lite_if csr_lite_if_arready arready output 1
add_interface_port csr_lite_if csr_lite_if_arvalid arvalid input 1
add_interface_port csr_lite_if csr_lite_if_araddr araddr input ARADDR_WIDTH
add_interface_port csr_lite_if csr_lite_if_arprot arprot input 3
# Read response channel
add_interface_port csr_lite_if csr_lite_if_rready rready input 1
add_interface_port csr_lite_if csr_lite_if_rvalid rvalid output 1
add_interface_port csr_lite_if csr_lite_if_rdata rdata output RDATA_WIDTH
add_interface_port csr_lite_if csr_lite_if_rresp rresp output 2


#
#uart signals output 
add_interface host_uart_if_dtr_n conduit start
set_interface_property host_uart_if_dtr_n  associatedClock clk_50m
set_interface_property host_uart_if_dtr_n  associatedReset rst_n_50m
set_interface_property host_uart_if_dtr_n ENABLED true
add_interface_port host_uart_if_dtr_n host_uart_if_dtr_n dtr_n output 1

add_interface host_uart_if_rts_n conduit start
set_interface_property host_uart_if_rts_n  associatedClock clk_50m
set_interface_property host_uart_if_rts_n  associatedReset rst_n_50m
set_interface_property host_uart_if_rts_n ENABLED true
add_interface_port host_uart_if_rts_n host_uart_if_rts_n rts_n output 1


add_interface host_uart_if_out1_n conduit start
set_interface_property host_uart_if_out1_n  associatedClock clk_50m
set_interface_property host_uart_if_out1_n  associatedReset rst_n_50m
set_interface_property host_uart_if_out1_n ENABLED true
add_interface_port host_uart_if_out1_n host_uart_if_out1_n out1_n output 1


add_interface host_uart_if_out2_n conduit start
set_interface_property host_uart_if_out2_n  associatedClock clk_50m
set_interface_property host_uart_if_out2_n  associatedReset rst_n_50m
set_interface_property host_uart_if_out2_n ENABLED true
add_interface_port host_uart_if_out2_n host_uart_if_out2_n out2_n output 1

add_interface host_uart_if_tx conduit start
set_interface_property host_uart_if_tx  associatedClock clk_50m
set_interface_property host_uart_if_tx  associatedReset rst_n_50m
set_interface_property host_uart_if_tx ENABLED true
add_interface_port host_uart_if_tx host_uart_if_tx tx output 1


#uart input 
#

add_interface host_uart_if_cts_n conduit end
set_interface_property host_uart_if_cts_n  associatedClock clk_50m
set_interface_property host_uart_if_cts_n  associatedReset rst_n_50m
set_interface_property host_uart_if_cts_n ENABLED true
add_interface_port host_uart_if_cts_n host_uart_if_cts_n cts_n input 1

add_interface host_uart_if_dsr_n conduit end
set_interface_property host_uart_if_dsr_n  associatedClock clk_50m
set_interface_property host_uart_if_dsr_n  associatedReset rst_n_50m
set_interface_property host_uart_if_dsr_n ENABLED true
add_interface_port host_uart_if_dsr_n host_uart_if_dsr_n dsr_n input 1

add_interface host_uart_if_dcd_n conduit end
set_interface_property host_uart_if_dcd_n  associatedClock clk_50m
set_interface_property host_uart_if_dcd_n  associatedReset rst_n_50m
set_interface_property host_uart_if_dcd_n ENABLED true
add_interface_port host_uart_if_dcd_n host_uart_if_dcd_n dcd_n input 1

add_interface host_uart_if_ri_n conduit end
set_interface_property host_uart_if_ri_n  associatedClock clk_50m
set_interface_property host_uart_if_ri_n  associatedReset rst_n_50m
set_interface_property host_uart_if_ri_n ENABLED true
add_interface_port host_uart_if_ri_n host_uart_if_ri_n ri_n input 1

add_interface host_uart_if_rx  conduit end
set_interface_property host_uart_if_rx   associatedClock clk_50m
set_interface_property host_uart_if_rx   associatedReset rst_n_50m
set_interface_property host_uart_if_rx  ENABLED true
add_interface_port host_uart_if_rx host_uart_if_rx rx input 1


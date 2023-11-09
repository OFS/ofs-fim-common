# Copyright (C) 2021 Intel Corporation
# SPDX-License-Identifier: MIT

# Intel Streaming Debug Endianness Adapter 

# 
# request TCL package from ACDS 20.1
# 
package require -exact qsys 20.1

# 
# module st_dbg_if
# 
set_module_property DESCRIPTION "Intel Streaming Debug Endianness Adapter"
set_module_property NAME intel_st_dbg_endianness_adp
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property DISPLAY_NAME "Intel Streaming Debug Endianness Adapter IP"
set_module_property GROUP "Basic Functions/Simulation; Debug and Verification/Debug and Performance"
set_module_property AUTHOR "Intel Corporation"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false
set_module_property LOAD_ELABORATION_LIMIT 0

# callbacks
# 
set_module_property ELABORATION_CALLBACK elaborate


proc add_rtl_files {} {
    add_fileset_file intel_st_dbg_endianness_adp.sv SYSTEM_VERILOG PATH intel_st_dbg_endianness_adp.sv
}

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL intel_st_dbg_endianness_adp
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_rtl_files 

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL intel_st_dbg_endianness_adp
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_rtl_files


#
# parameters
#
proc add_params {} {

    add_display_item "" "Source Interface" GROUP
    add_display_item "" "Sink Interface" GROUP

    add_parameter SRC_ENDIANNESS INTEGER 0
    set_parameter_property SRC_ENDIANNESS DISPLAY_NAME {First Symbol in High-Order Bits}
    set_parameter_property SRC_ENDIANNESS DISPLAY_HINT boolean
    set_parameter_property SRC_ENDIANNESS HDL_PARAMETER true
    set_parameter_property SRC_ENDIANNESS GROUP "Source Interface"

    add_parameter SNK_ENDIANNESS INTEGER 1
    set_parameter_property SNK_ENDIANNESS DISPLAY_NAME {First Symbol in High-Order Bits}
    set_parameter_property SNK_ENDIANNESS DISPLAY_HINT boolean
    set_parameter_property SNK_ENDIANNESS HDL_PARAMETER true
    set_parameter_property SNK_ENDIANNESS GROUP "Sink Interface"

    add_parameter SYM_SIZE INTEGER 8
    set_parameter_property SYM_SIZE DISPLAY_NAME "Symbol Size"
    set_parameter_property SYM_SIZE ENABLED false
    set_parameter_property SYM_SIZE UNITS None
    set_parameter_property SYM_SIZE ALLOWED_RANGES 8:8
    set_parameter_property SYM_SIZE HDL_PARAMETER true

    add_parameter NUM_SYM INTEGER 4
    set_parameter_property NUM_SYM DISPLAY_NAME "Number of Symbols"
    set_parameter_property NUM_SYM ALLOWED_RANGES {4 8 16 32 64 128}
    set_parameter_property NUM_SYM HDL_PARAMETER true

    add_parameter DATA_W INTEGER 32
    set_parameter_property DATA_W ENABLED false
    set_parameter_property DATA_W DERIVED true
    set_parameter_property DATA_W HDL_PARAMETER true

    add_parameter CHANNEL_W INTEGER 11 ""
    set_parameter_property CHANNEL_W DISPLAY_NAME "Channel Width"
    set_parameter_property CHANNEL_W ENABLED false
    set_parameter_property CHANNEL_W VISIBLE false
    set_parameter_property CHANNEL_W UNITS None
    set_parameter_property CHANNEL_W ALLOWED_RANGES 11:11
    set_parameter_property CHANNEL_W DESCRIPTION ""
    set_parameter_property CHANNEL_W HDL_PARAMETER true

    add_parameter EMPTY_W INTEGER 2 ""
    set_parameter_property EMPTY_W DISPLAY_NAME "Empty Width"
    set_parameter_property EMPTY_W ENABLED false
    set_parameter_property EMPTY_W VISIBLE false
    set_parameter_property EMPTY_W DERIVED true
    set_parameter_property EMPTY_W UNITS None
    set_parameter_property EMPTY_W DESCRIPTION ""
    set_parameter_property EMPTY_W HDL_PARAMETER true

}

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
    # connection point reset_sink
    # 
    add_interface reset_sink reset end
    set_interface_property reset_sink associatedClock clock
    set_interface_property reset_sink synchronousEdges BOTH
    set_interface_property reset_sink ENABLED true
    set_interface_property reset_sink EXPORT_OF ""
    set_interface_property reset_sink PORT_NAME_MAP ""
    set_interface_property reset_sink CMSIS_SVD_VARIABLES ""
    set_interface_property reset_sink SVD_ADDRESS_GROUP ""
    set_interface_property reset_sink IPXACT_REGISTER_MAP_VARIABLES ""
    
    add_interface_port reset_sink rst reset Input 1
    # 
    # connection point src interface connecting to SINK
    #
    set src_endianness [ get_parameter_value SRC_ENDIANNESS ]
    add_interface src avalon_streaming start
    set_interface_property src associatedClock clock
    set_interface_property src associatedReset reset_sink
    set_interface_property src dataBitsPerSymbol 8
    set_interface_property src errorDescriptor ""
    if { $src_endianness == 0 } {
    set_interface_property src firstSymbolInHighOrderBits false
    } else {
    set_interface_property src firstSymbolInHighOrderBits true
    }
    set channel_w [ get_parameter_value CHANNEL_W ]
    set_interface_property src maxChannel [expr {2 ** $channel_w} - 1]
    set_interface_property src readyAllowance 0
    set_interface_property src readyLatency 0
    set_interface_property src ENABLED true
    set_interface_property src EXPORT_OF ""
    set_interface_property src PORT_NAME_MAP ""
    set_interface_property src CMSIS_SVD_VARIABLES ""
    set_interface_property src SVD_ADDRESS_GROUP ""
    set_interface_property src IPXACT_REGISTER_MAP_VARIABLES ""
    
    add_interface_port src src_data data Output "((DATA_W - 1)) - (0) + 1"
    add_interface_port src src_valid valid Output 1
    add_interface_port src src_sop startofpacket Output 1
    add_interface_port src src_eop endofpacket Output 1
    add_interface_port src src_empty empty Output "((EMPTY_W - 1)) - (0) + 1"
    add_interface_port src src_ready ready Input 1
    add_interface_port src src_channel channel Output "((CHANNEL_W - 1)) - (0) + 1"

 
    # connection point snk interface connects to source
    #
    set snk_endianness [ get_parameter_value SNK_ENDIANNESS ]
    add_interface snk avalon_streaming end
    set_interface_property snk associatedClock clock
    set_interface_property snk associatedReset reset_sink
    set_interface_property snk dataBitsPerSymbol 8
    set_interface_property snk errorDescriptor ""
    if { $snk_endianness == 0 } {
    set_interface_property snk firstSymbolInHighOrderBits false
    } else {
    set_interface_property snk firstSymbolInHighOrderBits true
    }
    set_interface_property snk maxChannel [expr {2 ** $channel_w} - 1]
    set_interface_property snk readyAllowance 0
    set_interface_property snk readyLatency 0
    set_interface_property snk ENABLED true
    set_interface_property snk EXPORT_OF ""
    set_interface_property snk PORT_NAME_MAP ""
    set_interface_property snk CMSIS_SVD_VARIABLES ""
    set_interface_property snk SVD_ADDRESS_GROUP ""
    set_interface_property snk IPXACT_REGISTER_MAP_VARIABLES ""
    
    add_interface_port snk snk_ready ready Output 1
    add_interface_port snk snk_data data Input "((DATA_W - 1)) - (0) + 1"
    add_interface_port snk snk_valid valid Input 1
    add_interface_port snk snk_sop startofpacket Input 1
    add_interface_port snk snk_eop endofpacket Input 1
    add_interface_port snk snk_empty empty Input "((EMPTY_W - 1)) - (0) + 1"
    add_interface_port snk snk_channel channel Input "((CHANNEL_W - 1)) - (0) + 1"


}

proc set_derived_params {} {
    set_parameter_value DATA_W  [expr [get_parameter_value SYM_SIZE] *[get_parameter_value NUM_SYM] ]
    set_parameter_value EMPTY_W [clog2 [get_parameter_value NUM_SYM]]
}

proc clog2 { x } {
    set i 1
    set log2ceil 0
    # convert to base10 - nop if already base10
    set decimal_x [expr $x]
    while {$i < $decimal_x} {
        incr log2ceil
        set i [expr $i*2]
    }
    return $log2ceil
 }

add_params

proc elaborate {} {
    set_derived_params
    add_ports
}

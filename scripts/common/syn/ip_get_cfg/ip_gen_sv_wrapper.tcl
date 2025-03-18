## Copyright (C) 2025 Intel Corporation
## SPDX-License-Identifier: MIT

##
## Generate a SystemVerilog wrapper around an original Verilog IP module.
## Ports are grouped into vectors of interfaces and wires. Interfaces
## defined in the IP HWTCL are mapped to SystemVerilog interfaces.
##
## The script can either be invoked directly as a qsys-script command or as
## part invoked as part of a longer command. To support both modes, the entry
## point to the script is the emit_ip_cfg procedure. The procedure takes the
## name of the output file and the name of the IP subsystem as arguments.
##
## To use with qsys-script, do not use the --script argument. Instead, invoke
## qsys-script with a project and system-file, adding:
##
##     --cmd="source <path to this script>; gen_sv_wrapper <target dir> <subsystem name>"
## e.g.:
##     qsys-script --cmd="source $OFS_ROOTDIR/ofs-common/scripts/common/syn/ip_get_cfg/ip_gen_sv_wrapper.tcl; gen_sv_wrapper <path to>/pcie_ss/synth pcie_ss" --quartus-project=ofs_top --rev=ofs_top --system-file=<path to>/pcie_ss.ip
##
## Three files are written, using the target SystemVerilog file name as the base:
##   - <target>.sv: The SystemVerilog wrapper around the original Verilog IP module.
##   - <target>_param_pkg.sv: A package with parameters for the SystemVerilog module.
##   - <target>_params.vh: A header file with macros describing the SystemVerilog interfaces.
##

package require qsys

set info_script [info script]

# ip_ifcs will hold data to construct SystemVerilog interfaces for the raw interfaces
# described in the IP HWTCL. Entries are indexed by the SystemVerilog interface name
# Groups of identical raw interfaces may be merged into a shared SV entry. This
# happens with memory banks, PCIe links, etc.
#
# See gen_interface() for the format of the entries.
array set ip_ifcs {}

# Map from HWTCL interface name to SystemVerilog interface name
array set ifc_name_map {}

# Map from HWTCL interface name to vector length of ports coalesced into
# a group. If an entry is present, the interface is either the primary
# interface for a vector or a subordinate member of a primary entry.
# Primary entries are either a string (the name of a parameter) or a positive
# integer. Subordinate entries are an empty string.
array set ifc_vec_len {}

# Map from parameter name to the number of ports in the vector. These will be added to
# a SystemVerilog interface.
array set ifc_vec_params {}

# Log transformations for debugging
set log_file 0

# Map HWTCL interface descriptor to SystemVerilog details, producing an
# entry to be stored in ip_ifcs.
#
# Returns a list with the following entries:
#  0: list of ports, formatted as SystemVerilog port declarations. This entry is a
#     list of lists, each with the following entries:
#       0: port name
#       1: list with three entries: port direction, port type, port width if not 1
#       2: number of ports in a merged group, if the port is part of a group
#  1: two entry list of modport names, the first for the IP side and the second for the
#     application side.
proc gen_interface {inst ifc port_list} {
    set port_decl [list]

    # Is an associated clock or reset present? If yes, add them to the SV interface.
    set clk [get_instance_interface_parameter_value $inst $ifc associatedClock]
    set rst [get_instance_interface_parameter_value $inst $ifc associatedReset]
    if {$clk != ""} {
        lappend port_decl [list "clk" [list "output" "wire " ""] 0]
        lappend port_outputs "clk"
    }
    if {$rst != ""} {
        # Find the reset polarity from the port
        set rst_roll [get_first_port_role $inst $rst]
        if {[string tolower [string index $rst_roll end]] == "n"} {
            lappend port_decl [list "rst_n" [list "output" "wire " ""] 0]
            lappend port_outputs "rst_n"
        } else {
            lappend port_decl [list "rst" [list "output" "wire " ""] 0]
            lappend port_outputs "rst"
        }
    }

    foreach port $port_list {
        # Short port name inside the interface scope       
        set pname [get_instance_interface_port_property $inst $ifc $port ROLE]
        if {$pname == ""} {
            set pname $port
        }
        set ptype "logic"

        set dir [string tolower [get_instance_interface_port_property $inst $ifc $port DIRECTION]]
        if {$dir != "input" && $dir != "output"} {
            set dir "inout"
            set ptype "wire "
        }

        set w [get_instance_interface_port_property $inst $ifc $port WIDTH]
        if {$w == 1} {
            lappend port_decl [list $pname [list $dir $ptype ""]]
        } else {
            lappend port_decl [list $pname [list $dir $ptype "\[[expr $w-1]:0\] "]]
        }
    }

    set class_name [string tolower [get_instance_interface_property $inst $ifc CLASS_NAME]]
    if {[string first "axi" $class_name] != -1} {
        if {[string first "slave" $class_name] != -1 || [string first "subord" $class_name] != -1} {
            set mport [list "subordinate" "manager"]
        } else {
            set mport [list "manager" "subordinate"]
        }
    } else {
        set mport [list "ip" "app"]
    }

    # Combine ports into vectors (fix HWTCL missing vector support)
    set port_decl [merge_interface_ports $inst $ifc $port_decl]
    # Rename some interface ports (fix HWTCL poor name choices)
    set port_decl [rename_interface_ports $inst $ifc $port_decl]

    return [list $port_decl $mport]
}

proc get_first_port {inst ifc} {
    return [lindex [get_instance_interface_ports $inst $ifc] 0]
}

proc get_first_port_role {inst ifc} {
    set port [get_first_port $inst $ifc]
    set role [get_instance_interface_port_property $inst $ifc $port ROLE]
    if {$role != ""} {
        return $role
    }
    # No roll. Return the port.
    return $port
}

# Rename interface ports that have instance numbers matching the interface's
# instance number. Eliminate the number in the port. This allows some poorly
# constructed interfaces to be collapsed into vectors. The real solution is
# fixing the HWTCL to use consistent port names across interfaces.
proc rename_interface_ports {inst ifc port_list} {
    global log_file

    # Extract the instance number from the interface name
    if {[regexp {[^0-9]([0-9]+)_} $ifc dummy id] == 0} {
        return $port_list
    }

    # Generate a list of updated port names with the instance number removed
    set found_rename 0
    set renamed_ports [list]
    array set port_set {}
    foreach port $port_list {
        set port_name [lindex $port 0]
        if {[regexp {[^0-9]([0-9]+)_} $port_name dummy port_id]} {
            # Found a similar pattern with an unexpected number. Give up and use
            # the original port names.
            if {$port_id != $id} {
                return $port_list
            }
            set new_port_name [name_to_group $port_name]
            set found_rename 1
        } else {
            set new_port_name $port_name
        }

        lappend renamed_ports $new_port_name

        if {[info exists port_set($new_port_name)]} {
            # Renaming led to a duplicate port name. Give up and use the original.
            return $port_list
        }
        set port_set($new_port_name) 1
    }

    if {$found_rename == 0} {
        # Nothing to do. Return the original list.
        return $port_list
    }

    # Renaming was successful. Update the port list.
    set new_port_list [list]
    foreach port $port_list new_name $renamed_ports {
        set old_name [lindex $port 0]
        lappend new_port_list [concat $new_name [lrange $port 1 end]]
        puts $log_file "${inst} ${ifc} renaming port ${old_name} to ${new_name}"
    }

    return $new_port_list
}

# Merge interface ports with sequential numbering into a single vector.
# Future HWTCL should describe vectors explicitly.
proc merge_interface_ports {inst ifc port_list} {
    global log_file

    set merged_ports [list]
    set cur_merge_orig ""
    set cur_merge_base ""
    set cur_merge_pattern ""
    set next_id 0

    foreach port $port_list {
        set port_name [lindex $port 0]
        if {$next_id != 0} {
            # Does the current port match the previous one?

            # Extract the index for the candidate. It must be monotonically
            # increasing.
            set is_match [regexp $cur_merge_pattern $port_name dummy id]

            if {$is_match && $id == $next_id && [lindex $cur_merge_orig 1] == [lindex $port 1]} {
                # Match. Extend the current group.
                incr next_id
                continue
            } else {
                # No match. Finish the current group.
                if {$next_id > 1} {
                    lappend merged_ports [list $cur_merge_base [lindex $cur_merge_orig 1] $next_id]
                    puts $log_file "${inst} ${ifc} merging ports matching ${cur_merge_pattern}: ${cur_merge_base}\[$next_id\]"
                } else {
                    lappend merged_ports $cur_merge_orig
                }

                set cur_merge_base ""
                set next_id 0
            }
        }

        if {[regexp "\[^0-9\]0\$" $port_name]} {
            # Start a new group from the pattern "name0"
            set cur_merge_orig $port
            set cur_merge_base [string range $port_name 0 end-1]
            set cur_merge_pattern "${cur_merge_base}(\[0-9\]+)$"
            set next_id 1
        } elseif {[is_interface_id0 $port_name]} {
            # Start a new group from the pattern "name0_*"
            set cur_merge_orig $port
            regsub \[0-9\]+_ $port_name _ cur_merge_base
            regsub 0_ $port_name (\[0-9\]+)_ cur_merge_pattern
            set next_id 1
        } else {
            # No group. Add the port as is.
            lappend merged_ports $port
        }
    }

    # Finish the last group
    if {$next_id > 1} {
        lappend merged_ports [list $cur_merge_base [lindex $cur_merge_orig 1] $next_id]
        puts $log_file "${inst} ${ifc} merging ports matching ${cur_merge_pattern}: ${cur_merge_base}\[$next_id\]"
    } elseif {$next_id == 1} {
        lappend merged_ports $cur_merge_orig
    }

    return $merged_ports
}

# Map HWTCL interface descriptor with only one port to the same representation
# as gen_interface above. The modport name list is empty.
proc gen_simple_port {inst ifc port} {
    # Short port name inside the interface scope       
    set pname [get_instance_interface_port_property $inst $ifc $port ROLE]
    if {$pname == ""} {
        set pname $port
    }

    set w [get_instance_interface_port_property $inst $ifc $port WIDTH]
    if {$w == 1} {
        set width ""
    } else {
        set width "\[[expr $w-1]:0\] "
    }

    set dir [string tolower [get_instance_interface_port_property $inst $ifc $port DIRECTION]]
    if {$dir == "input"} {
        set dir "input "
    } elseif {$dir != "output"} {
        set dir "inout "
    }

    return [list [list ${dir} "wire" ${width}] {}]
}

# Read the IP HWTCL and map raw interfaces to ip_ifcs and ifc_name_map,
# which will be used to generate SystemVerilog interfaces.
proc decode_sv_interfaces {} {
    global ip_ifcs
    global ifc_name_map

    foreach inst [get_instances] {
        # All interfaces for the instance
        set ifc_list [lsort_dict [get_instance_interfaces $inst]]

        foreach ifc $ifc_list {
            set port_list [lsort_dict [get_instance_interface_ports $inst $ifc]]

            # Map to a SystemVerilog interface or simple port
            if {[llength $port_list] > 1} {
                set sv_ifc [gen_interface $inst $ifc $port_list]
            } else {
                set sv_ifc [gen_simple_port $inst $ifc [lindex $port_list 0]]
            }

            # Check if the interface is a candidate for coalescing by dropping
            # a numeric index.
            regsub \[0-9\]+_ $ifc _ merge_ifc_name
            set merge_ifc_name "${inst}_[string trimright $merge_ifc_name _]_if"

            set map_key ${inst}_${ifc}

            if {[is_interface_id0 $ifc]} {
                # 0 index entry. Always drop the number, even if no "1" entry is
                # found later. That way the interface is consistent with other
                # configurations that have coalesced interfaces. This might happen
                # with PCIe interfaces, for example, when multiple links are present.
                set ifc_name $merge_ifc_name
            } elseif {[info exists ip_ifcs($merge_ifc_name)] && $ip_ifcs($merge_ifc_name) == $sv_ifc} {
                # Merge with the 0 index entry
                set ifc_name_map($map_key) $merge_ifc_name
                continue
            } else {
                set ifc_name "${inst}_[string trimright $ifc _]_if"
            }

            set ip_ifcs($ifc_name) $sv_ifc
            set ifc_name_map($map_key) $ifc_name
        }
    }
}

# Generate a mapping from Verilog ports to SystemVerilog ports. The returned
# array will be used to populate the port list for the original Verilog module.
proc gen_verilog_port_map {inst port_map_name} {
    global ip_ifcs
    global ifc_name_map
    global ifc_vec_len
    global ifc_vec_params

    upvar 1 $port_map_name port_map
    if {[info exists port_map]} { array unset port_map }

    foreach ifc [lsort_dict [get_instance_interfaces $inst]] {
        set map_key ${inst}_${ifc}
        set ifc_name $ifc_name_map($map_key)
        set sv_ifc $ip_ifcs($ifc_name)

        # Mapped to a vector in SV?
        set vec_idx ""
        if {[info exists ifc_vec_len($ifc)]} {
            set vec_idx "\[[name_to_group_id $ifc]\]"
        }

        if {[llength [lindex $sv_ifc 1]]} {
            # modports present. Use a SV interface.
            if {$vec_idx != ""} {
                set wrapper_port_name "[string trimright [name_to_group $ifc] _]${vec_idx}"
            } else {
                set wrapper_port_name [string trimright $ifc _]
            }

            # Ports from the SV interface
            set wrapper_port_list [lindex $sv_ifc 0]
            set widx 0

            # Skip clk and rst ports. They are initialized with assignment later.
            while {[lindex [lindex $wrapper_port_list $widx] 2] == 0} {
                incr widx
            }

            # Walk the original Verilog port list. The Verilog ports and the SV interface
            # ports are in the same order. The SV interface may have merged ports, so
            # the mapping must assign each merged index to the correct Verilog port.
            set vec_idx 0
            foreach port [lsort_dict [get_instance_interface_ports $inst $ifc]] {
                set ifc_port_info [lindex $wrapper_port_list $widx]
                set ifc_port_name [lindex $ifc_port_info 0]
                set ifc_port_vec_len [lindex $ifc_port_info 2]

                if {$ifc_port_vec_len != ""} {
                    set port_map($port) "${wrapper_port_name}.${ifc_port_name}\[${vec_idx}\]"
                    incr vec_idx
                    if {$vec_idx == $ifc_port_vec_len} {
                        incr widx
                        set vec_idx 0
                    }
                } else {
                    set port_map($port) "${wrapper_port_name}.${ifc_port_name}"
                    incr widx
                }
            }
        } else {
            # No SystemVerilog interface. Use a simple port.
            set ip_port_name [lindex [get_instance_interface_ports $inst $ifc] 0]
            set wrapper_port_name $ip_port_name
            if {$vec_idx != ""} {
                set wrapper_port_name [name_to_group $wrapper_port_name]
            }
            set wrapper_port_name "[string trimright $wrapper_port_name _]${vec_idx}"
            set port_map($ip_port_name) $wrapper_port_name
        }
    }
}

# Generate a mapping from Verilog clocks and resets to the clk and rst ports
# in the SystemVerilog interfaces.
proc gen_sv_clk_map {inst clk_map_name} {
    global ip_ifcs
    global ifc_name_map
    global ifc_vec_len
    global ifc_vec_params

    upvar 1 $clk_map_name clk_map
    if {[info exists clk_map]} { array unset clk_map }

    foreach ifc [lsort_dict [get_instance_interfaces $inst]] {
        set map_key ${inst}_${ifc}
        set ifc_name $ifc_name_map($map_key)
        set sv_ifc $ip_ifcs($ifc_name)

        # Mapped to a vector in SV?
        set vec_idx ""
        if {[info exists ifc_vec_len($ifc)]} {
            set vec_idx "\[[name_to_group_id $ifc]\]"
        }

        if {[llength [lindex $sv_ifc 1]]} {
            # modports present. Use a SV interface.
            if {$vec_idx != ""} {
                set wrapper_port_name "[string trimright [name_to_group $ifc] _]${vec_idx}"
            } else {
                set wrapper_port_name [string trimright $ifc _]
            }

            # Ports from the SV interface
            set wrapper_port_list [lindex $sv_ifc 0]
            set widx 0

            # clk and rst ports are first. They are tagged with a replication count of 0
            # and the Verilog port is stored in index 3 of the port metadata.
            while {[lindex [lindex $wrapper_port_list $widx] 2] == 0} {
                set ifc_port_info [lindex $wrapper_port_list $widx]
                set ifc_port_name [lindex $ifc_port_info 0]

                if {$ifc_port_name == "clk"} {
                    set clk [get_instance_interface_parameter_value $inst $ifc associatedClock]
                    set verilog_port_name [get_first_port $inst $clk]
                } else {
                    set rst [get_instance_interface_parameter_value $inst $ifc associatedReset]
                    set verilog_port_name [get_first_port $inst $rst]
                }

                set clk_map(${wrapper_port_name}.${ifc_port_name}) $verilog_port_name
                incr widx
            }
        }
    }
}

proc emit_modports {of name ins outs inouts} {
    set ports [list]
    if {[llength $ins]}    { lappend ports "    input  [join $ins ", "]" }
    if {[llength $outs]}   { lappend ports "    output [join $outs ", "]" }
    if {[llength $inouts]} { lappend ports "    inout  [join $inouts ", "]" }

    puts $of "  modport $name ("
    puts $of [join $ports ",\n"]
    puts $of "  );"
}

# Write out a collection of IP parameters to a VH file.
proc emit_ip_params {hdr_params_file inst param_list msg} {
    puts $hdr_params_file ""
    puts $hdr_params_file "//"
    puts $hdr_params_file "// ${msg}"
    puts $hdr_params_file "//"
    puts $hdr_params_file ""
    foreach p [lsort_dict $param_list] {
        set p_type [string toupper [get_instance_parameter_property $inst $p TYPE]]
        set p_value [get_instance_parameter_value $inst $p]
        if {![string match "*_LIST" $p_type]} {
            if {$p_type == "STRING"} {
                # Ideally we would just trust the STRING property, but too many parameters are
                # tagged string that are actually numbers. Add quotation marks if the string
                # is non-numeric.
                if {![regexp {^[0-9\.]+$} $p_value]} {
                    set p_value "\"${p_value}\""
                }
            }
            puts $hdr_params_file "`define [string toupper $inst]_PARAM_[string toupper $p]    $p_value"
        }
    }

}

proc emit_file_header {f} {
    global info_script

    puts $f "//"
    puts $f "// Generated by [file tail $info_script]"
    puts $f "//"
    puts $f ""
}

proc gen_pretty_ifc_name {ifc_name} {
    regsub {_if_if$} $ifc_name "_if" ifc_name
    regsub {_interface_if$} $ifc_name "_interface" ifc_name
    return $ifc_name
}

proc gen_sv_wrapper {tgt_dir ip_name} {
    global ip_ifcs
    global ifc_name_map
    global ifc_vec_len
    global ifc_vec_params
    global log_file

    set of [open "${tgt_dir}/${ip_name}_sv.sv" w]
    emit_file_header $of
    set log_file [open "${tgt_dir}/${ip_name}_sv.log" w]
    emit_file_header $log_file
    set pkg_file [open "${tgt_dir}/${ip_name}_param_pkg.sv" w]
    emit_file_header $pkg_file
    set hdr_if_file [open "${tgt_dir}/${ip_name}_if_info.vh" w]
    emit_file_header $hdr_if_file
    set hdr_params_file [open "${tgt_dir}/${ip_name}_ip_params.vh" w]
    emit_file_header $hdr_params_file

    set ip_name [string toupper $ip_name]
    set hdr_if_macro "__${ip_name}_IF_INFO_H__"
    puts $hdr_if_file "`ifndef $hdr_if_macro"
    puts $hdr_if_file "`define $hdr_if_macro"
    puts $hdr_if_file ""
    set hdr_params_macro "__${ip_name}_IP_PARAMS_H__"
    puts $hdr_params_file "`ifndef $hdr_params_macro"
    puts $hdr_params_file "`define $hdr_params_macro"
    puts $hdr_params_file ""

    decode_sv_interfaces

    # Write out the SV interfaces
    puts $hdr_if_file "//"
    puts $hdr_if_file "// Macros describing SystemVerilog interfaces"
    puts $hdr_if_file "//"
    puts $hdr_if_file ""
    foreach ifc_name [lsort_dict [array names ip_ifcs]] {
        set sv_ifc $ip_ifcs($ifc_name)
        set pretty_ifc_name [gen_pretty_ifc_name $ifc_name]

        # Skip interfaces with no ports
        if {[llength [lindex $sv_ifc 1]] == 0} { continue }

        puts $hdr_if_file "`define HAS_IFC_[string toupper ${pretty_ifc_name}] 1"
        puts $of "interface ${pretty_ifc_name};"
        set input_ports [list]
        set output_ports [list]
        set inout_ports [list]

        # See gen_interface() above for the format of the port list
        foreach port [lindex $sv_ifc 0] {
            set port_name [lindex $port 0]
            set port_direction [lindex [lindex $port 1] 0]
            set port_type [lindex [lindex $port 1] 1]
            set port_width [lindex [lindex $port 1] 2]

            puts $hdr_if_file "`define IFC_[string toupper ${pretty_ifc_name}]_HAS_PORT_[string toupper ${port_name}] 1"

            if {[llength $port] > 2 && [lindex $port 2] > 0} {
                # Merged port (vector of base ports detected from sequentially numbered naming)
                set n_entries [expr [lindex $port 2] - 1]
                puts $of "  ${port_type} \[${n_entries}:0\] ${port_width}${port_name};"
                puts $hdr_if_file "`define IFC_[string toupper ${pretty_ifc_name}]_PORT_[string toupper ${port_name}]_IS_VEC [expr $n_entries+1]"
            } else {
                puts $of "  ${port_type} ${port_width}${port_name};"
            }

            if {$port_direction == "input"} {
                lappend input_ports ${port_name}
            } elseif {$port_direction == "output"} {
                lappend output_ports ${port_name}
            } else {
                lappend inout_ports ${port_name}
            }
        }

        puts $of ""
        emit_modports $of [lindex [lindex $sv_ifc 1] 0] $input_ports $output_ports $inout_ports
        emit_modports $of [lindex [lindex $sv_ifc 1] 1] $output_ports $input_ports $inout_ports

        puts $of "endinterface"
        puts $of ""

        puts $hdr_if_file ""
    }

    foreach inst [get_instances] {
        # Reduce individual interfaces into vectors of interfaces
        coalesce_vec_ifs $inst

        puts $pkg_file "package ${inst}_param_pkg;"
        puts $pkg_file "    localparam NUM_PORTS = $ifc_vec_params(NUM_PORTS);"
        foreach param [lsort_dict [array names ifc_vec_params]] {
            if {$param != "NUM_PORTS"} {
                puts $pkg_file "    localparam $param = $ifc_vec_params($param);"
            }
        }
        puts $pkg_file "endpackage"
        puts $pkg_file ""

        puts $hdr_if_file ""
        puts $hdr_if_file "//"
        puts $hdr_if_file "// Macros describing ${inst}_sv module ports"
        puts $hdr_if_file "//"
        puts $hdr_if_file ""

        puts $of "module ${inst}_sv"
        puts $of "  import ${inst}_param_pkg::*;"
        puts $of "("

        # All interfaces for the instance
        set all_ports [list]
        foreach ifc [get_instance_interfaces $inst] {
            set map_key ${inst}_${ifc}
            set ifc_name $ifc_name_map($map_key)
            set sv_ifc $ip_ifcs($ifc_name)
            set pretty_ifc_name [gen_pretty_ifc_name $ifc_name]

            if {[info exists ifc_vec_len($ifc)] && $ifc_vec_len($ifc) == ""} {
                # This interface is already part of a vector. Skip it.
                continue
            }

            # Primary entry of a vector? Add the vector size to the port.
            set vec_len ""
            if {[info exists ifc_vec_len($ifc)] && $ifc_vec_len($ifc) != ""} {
                set vec_len $ifc_vec_len($ifc)
            }

            if {[llength [lindex $sv_ifc 1]]} {
                # modports present. Use a SV interface.
                set port "  ${pretty_ifc_name}.[lindex [lindex $sv_ifc 1] 0] "
                if {$vec_len != ""} {
                    append port "[string trimright [name_to_group $ifc] _]\[${vec_len}\]"
                    puts $hdr_if_file "`define ${ip_name}_PORT_[string toupper [string trimright [name_to_group $ifc] _]]_IS_VEC ${inst}_param_pkg::${vec_len}"
                    puts $hdr_if_file "`define ${ip_name}_HAS_PORT_[string toupper [string trimright [name_to_group $ifc] _]] 1"
                } else {
                    append port [string trimright $ifc _]
                    puts $hdr_if_file "`define ${ip_name}_HAS_PORT_[string toupper [string trimright $ifc _]] 1"
                }
                puts $hdr_if_file "`define ${ip_name}_PORT_[string toupper [string trimright $ifc _]]_IS_SV_IFC ${pretty_ifc_name}"
            } else {
                # No SystemVerilog interface. Use a simple port.
                set port_name [lindex [get_instance_interface_ports $inst $ifc] 0]
                set simple_port [lindex $sv_ifc 0]
                set port "  [join [lrange $simple_port 0 1]]"
                if {$vec_len != ""} {
                    append port " \[${vec_len}-1:0\]"
                    set port_name [name_to_group $port_name]
                    puts $hdr_if_file "`define ${ip_name}_PORT_[string toupper [string trimright $port_name _]]_IS_VEC ${inst}_param_pkg::${vec_len}"
                }
                append port " [lindex $simple_port 2][string trimright $port_name _]"
                puts $hdr_if_file "`define ${ip_name}_HAS_PORT_[string toupper [string trimright $port_name _]] 1"
            }

            lappend all_ports $port
            puts $hdr_if_file ""
        }

        puts $of [join $all_ports ",\n"]
        puts $of ");"

        # Instantiate the original IP Verilog wrapper module
        array set verilog_port_map {}
        gen_verilog_port_map $inst verilog_port_map
        puts $of ""
        puts $of "  ${inst} ${inst} ("
        set verilog_ports [lsort_dict [array names verilog_port_map]]
        foreach port [lrange $verilog_ports 0 end-1] {
            puts $of "    .${port}($verilog_port_map($port)),"
        }
        set port [lindex $verilog_ports end]
        puts $of "    .${port}($verilog_port_map($port))"
        puts $of "  );"

        # Assign the clock and reset ports in SV interfaces
        array set sv_clk_map {}
        gen_sv_clk_map $inst sv_clk_map
        puts $of ""
        foreach clk [lsort_dict [array names sv_clk_map]] {
            puts $of "  assign ${clk} = $verilog_port_map($sv_clk_map($clk));"
        }
        puts $of ""
        puts $of "endmodule"

        # Generate sets of IP parameters to write to hdr_params_file. The first group
        # is the set of parameters declared by the top-level internal IP module.
        # The second group is visible parameters that affect generation.
        set hdr_top_params [list]
        set hdr_gen_params [list]
        foreach p [get_instance_parameters $inst] {
            if {[get_instance_parameter_property $inst $p HDL_PARAMETER]} {
                lappend hdr_top_params $p
            } elseif {[get_instance_parameter_property $inst $p AFFECTS_GENERATION] && [get_instance_parameter_property $inst $p VISIBLE]} {
                lappend hdr_gen_params $p
            }
        }

        if {[llength $hdr_top_params]} {
            emit_ip_params $hdr_params_file $inst $hdr_top_params "${inst} primary IP configuration parameters"
        }
        if {[llength $hdr_gen_params]} {
            emit_ip_params $hdr_params_file $inst $hdr_gen_params "${inst} other IP configuration parameters affecting generation"
        }
    }

    close $of
    close $log_file
    close $pkg_file

    puts $hdr_if_file ""
    puts $hdr_if_file "`endif  // $hdr_if_macro"
    close $hdr_if_file
    puts $hdr_params_file ""
    puts $hdr_params_file "`endif  // $hdr_params_macro"
    close $hdr_params_file
}


##########################################################################
##########################################################################
##
## The old tcl library used by PD returns the wrong order for
## lsort -dictionary in some cases. Implement an equivalent with a
## custom comparison function.
##
##########################################################################
##########################################################################

proc lsort_dict {in_list} {
    return [lsort -command dict_compare $in_list]
}

# Equivalent of lsort -dictionary
proc dict_compare {a b} {
    # Split the input strings into lists of integers and strings
    regsub -all (\[0-9\]+) $a "^\\1^" a_exp
    set a_list [split $a_exp "^"]
    regsub -all (\[0-9\]+) $b "^\\1^" b_exp
    set b_list [split $b_exp "^"]

    # Compare the lists element by element
    foreach a_elem $a_list b_elem $b_list {
        if {$a_elem != $b_elem} {
            # If both elements are integers, compare them as integers, independent
            # of length.
            if {[string is integer -strict $a_elem] && [string is integer -strict $b_elem]} {
                return [expr {$a_elem - $b_elem}]
            }
            return [string compare $a_elem $b_elem]
        }
    }
    return 0
}


##########################################################################
##########################################################################
##
## The remainder of the script has procedures for coalescing independent
## but identical interfaces into vectors of interfaces. It should be
## replaced by data structures in the HWTCL and IP that describe the
## actual vectors instead of having to infer them.
##
##########################################################################
##########################################################################

# Return true if the interface name is of the form: *<name>0_*.
# When true, the interface name is likely to be repeated with increasing
# index values. The id0 instance is used to drive coalescing.
proc is_interface_id0 {ifc} {
    set idx [string first 0_ $ifc]
    if {$idx <= 0} { return 0 }
    set prev_char [string index $ifc [expr $idx-1]]
    return [expr ![string is digit $prev_char]]
}

# Map a numbered interface name to a group name.
proc name_to_group {ifc} {
    regsub {([^0-9])[0-9]+_} $ifc "\\1_" ifc_base
    return $ifc_base
}

# Map an interface to the group index.
proc name_to_group_id {ifc} {
    regexp {[^0-9]([0-9]+)_} $ifc dummy id
    return $id
}

# Algorithmically coalesce interfaces that are likely to be part of a vector by
# looking for a common IP naming pattern. Look for interface names matching
# *<name>0_* and then searches for other interfaces with the same *<name>* but
# with different indices. If the indices are contiguous and all interfaces share
# a common port list, the interfaces are coalesced into a single vector.
#
# Returns a list of groups to coalesce. Each group is a list of interface names.
proc find_coalesce_groups {inst} {
    global log_file
    global ifc_name_map
    set coalesce_groups [list]

    # All interfaces for the instance
    set ifc_list [lsort_dict [get_instance_interfaces $inst]]

    foreach ifc $ifc_list {
        # Turn id0 variant of the interface into a pattern
        # that detects other interfaces matching the same pattern
        # but with different indices.
        if {[is_interface_id0 $ifc]} {
            # Generate a new regex in the variable "pattern" that matches
            # the numeric index in the interface name to find candidates
            # for coalescing. Zero in the original interface name is replaced
            # with a wildcard to match any number.
            regsub 0_ $ifc (\[0-9\]+)_ pattern
            set pattern "^${pattern}$"

            # Filter the interfaces that match. The ifc_group list will hold
            # matching interface names and ifc_group_ids will hold just the port 
            # index numbers from the names.
            set ifc_group [list]
            set ifc_group_ids [list]
            foreach i $ifc_list {
                if {[regexp $pattern $i dummy id]} {
                    lappend ifc_group $i
                    lappend ifc_group_ids $id
                }
            }

            # Sort the group id list in order to figure out whether port indices
            # are contiguous. If the array is contiguous, it can be coalesced into
            # a single vector of interfaces.
            set ifc_group_ids [lsort -int $ifc_group_ids]
            set num_ports [llength $ifc_group_ids]
            if {[lindex $ifc_group_ids end] != $num_ports - 1} {
                # Not contiguous. Skip coalescing.
                continue
            }

            # Final check before coalescing: all interfaces in the group must
            # have the same port list.
            set mapped_name $ifc_name_map(${inst}_${ifc})
            set matched 1
            foreach i $ifc_group {
                if {$mapped_name != $ifc_name_map(${inst}_${i})} {
                    # Different port list. Skip coalescing.
                    set matched 0
                    break
                }
            }
            if {!$matched} {
                continue
            }

            puts $log_file "${inst}: coalescing groups matching ${pattern} into $ifc_group"
            lappend coalesce_groups $ifc_group
        }
    }

    return $coalesce_groups
}

# Algorithmically pick a group size and declare it to be the primary number of
# ports -- the main vector size for grouped interfaces. The algorithm is simple:
# pick the most common group size. This may well be wrong for some IP.
#
# The algorithm should be replaced with explicit information in the IP.
proc coalesce_get_num_ports {groups} {
    # Generate a histogram of group sizes
    array set group_size_hist {}
    foreach group $groups {
        set size [llength $group]
        if {[info exists group_size_hist($size)]} {
            incr group_size_hist($size)
        } else {
            set group_size_hist($size) 1
        }
    }

    # Find the most common group size
    set num_ports 0
    set max_group_size 0
    foreach size [array names group_size_hist] {
        if {$group_size_hist($size) > $max_group_size} {
            set max_group_size $group_size_hist($size)
            set num_ports $size
        }
    }

    return $num_ports
}

# foo_bar0_baz -> bar
proc map_func_near_prefix {name} {
    regexp {([a-zA-Z]+)[0-9]+_} $name dummy g
    return $g
}

# foo_txbar0_baz -> bar (same as map_func_near prefix but remove TX and RX,
# trying to merge pairs of interfaces)
proc map_func_near_prefix_drop_txrx {name} {
    set g [map_func_near_prefix $name]
    regsub -nocase {^(tx|rx)} $g "" g
    return $g
}

# foo_bar0_baz -> foo_bar
proc map_func_full_prefix {name} {
    regexp {(^.*[^0-9])[0-9]+_} $name dummy g
    return $g
}

# foo_bar0_baz -> foo_bar_baz
proc map_func_full_name {name} {
    regsub \[0-9\]+_ $name _ g
    return [string trimright $g _]
}

# Check whether the provided mapping function (one of map_func_* above) can
# be used to generate names for the provided list of groups. A mapping function
# can be used if each generated name corresponds to a single vector size.
proc coalesce_try_map_func {groups map_func} {
    global ifc_vec_len
    global ifc_vec_params

    array set name_to_size {}
    foreach group $groups {
        set mapped_name [$map_func [lindex $group 0]]
        if {[info exists name_to_size($mapped_name)]} {
            if {$name_to_size($mapped_name) != [llength $group]} {
                # Name would correspond to multiple vector lengths
                return 0
            }
        } else {
            set name_to_size($mapped_name) [llength $group]
        }
    }

    # Mapping works. Update ifc_vec_len with chosen naming.
    foreach group $groups {
        set mapped_name [string toupper [$map_func [lindex $group 0]]]

        if {$mapped_name != "PORTS"} {
           set param_name "NUM_${mapped_name}"
        } else {
           set param_name "GRP_PORTS"
        }
        set ifc_vec_params($param_name) [llength $group]
        set ifc_vec_len([lindex $group 0]) $param_name
        foreach ifc [lrange $group 1 end] {
            set ifc_vec_len($ifc) ""
        }
    }

    return 1
}

proc coalesce_vec_ifs {inst} {
    global log_file
    global ifc_vec_len
    global ifc_vec_params

    if {[info exists ifc_vec_len]} { array unset ifc_vec_len }
    if {[info exists ifc_vec_params]} { array unset ifc_vec_params }

    set coalesce_groups [find_coalesce_groups $inst]
    if {[llength $coalesce_groups] == 0} {
        # Nothing to combine. Add a dummy NUM_PORTS for consistency.
        set ifc_vec_params(NUM_PORTS) 1
        return
    }

    set num_ports [coalesce_get_num_ports $coalesce_groups]
    puts $log_file "${inst}: coalescing interfaces into vectors of $num_ports ports"

    # Assign NUM_PORTS to the group with that size. Keep the remaing
    # groups in a list to be processed later.
    set ifc_vec_params(NUM_PORTS) $num_ports
    set remaining_groups [list]
    foreach group $coalesce_groups {
        if {[llength $group] == $num_ports} {
            set ifc_vec_len([lindex $group 0]) "NUM_PORTS"
            foreach ifc [lrange $group 1 end] {
                set ifc_vec_len($ifc) ""
            }
        } else {
            lappend remaining_groups $group
        }
    }

    if {[llength $remaining_groups] == 0} {
        return
    }

    # Try different mapping functions to generate names for the remaining,
    # starting with short names and growing longer.
    if {[coalesce_try_map_func $remaining_groups map_func_near_prefix_drop_txrx]} { return }
    if {[coalesce_try_map_func $remaining_groups map_func_near_prefix]} { return }
    if {[coalesce_try_map_func $remaining_groups map_func_full_prefix]} { return }
    if {[coalesce_try_map_func $remaining_groups map_func_full_name]} { return }

    # This point should not be reached. At least map_func_full_name should have
    # generated unique names for each group.
    puts "ERROR: Failed to coalesce interfaces into vectors"
    exit 1
}

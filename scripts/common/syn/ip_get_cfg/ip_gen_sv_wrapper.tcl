## Copyright (C) 2025 Altera Corporation
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
##     --cmd="source <path to this script>; gen_sv_wrapper <target dir>"
## e.g.:
##     qsys-script --cmd="source $OFS_ROOTDIR/ofs-common/scripts/common/syn/ip_get_cfg/ip_gen_sv_wrapper.tcl; gen_sv_wrapper ../../../../ipss/pcie/qip/sv_wrapper" --quartus-project=ofs_top --rev=ofs_top --system-file=../../../../ipss/pcie/qip/pcie_ss.ip
##
## Five files are written, using the target SystemVerilog file name as the base:
##   - <target>.sv: The SystemVerilog wrapper around the original Verilog IP module.
##   - <target>_param_pkg.sv: A package with parameters for the SystemVerilog module.
##   - <target>_if_info.vh: A header file with macros describing the SystemVerilog interfaces.
##   - <target>_ip_params.vh: A header file with macros describing the IP parameters.
##   - <target>.log: A log file with debugging information.
##

package require qsys

namespace eval ip_gen_sv {
    variable info_script [info script]

    # Cache the set of all instances
    variable all_instances [list]

    # ip_ifcs will hold data to construct SystemVerilog interfaces for the raw interfaces
    # described in the IP HWTCL. Entries are indexed by the SystemVerilog interface name
    # Groups of identical raw interfaces may be merged into a shared SV entry. This
    # happens with memory banks, PCIe links, etc.
    #
    # See gen_interface() for the format of the entries.
    variable ip_ifcs
    array set ip_ifcs {}

    # Map from HWTCL interface name to SystemVerilog interface name
    variable ifc_name_map
    array set ifc_name_map {}
    # Map from HWTCL interface name to the key used to index the ip_ifcs array.
    # For most interfaces this is just a pointer to itself. For coalesced interfaces
    # this is a pointer to the id0 interface's key.
    variable ifc_name_map_key
    array set ifc_name_map_key {}
    # Regular expression for matching the id0 (index 0) interface name, used to find
    # other interfaces matching the same pattern. Uses the same keys as ifc_name_map.
    variable ifc_name_map_pattern
    array set ifc_name_map_pattern {}

    # Group candidates detected during the interface detection phase. These
    # will turn into real groups as long as the indices are dense.
    variable ifc_groups
    array set ifc_groups {}

    # Interface group number. Each entry is a list with two entries:
    #   0: group number - the id0 entry is always group 0
    #   1: group index offset - mapping from the original port name to vector offset
    # Group number is used to handle a collection of similarly named ports that have
    # multiple interfaces. For example, a board with 4 sets of EMIF -- two with ECC
    # and two without. If all 4 EMIF ports have consistent names, such as mem0_ddr,
    # mem1_ddr, mem2_ddr, and mem3_ddr, the group number will be 0 for the first
    # two and 1 for the last two. The index offset will be 0 for the first two and
    # 2 for the last two.
    variable ifc_group_num
    array set ifc_group_num {}

    # Map from HWTCL interface name to vector length of ports coalesced into
    # a group. If an entry is present, the interface is either the primary
    # interface for a vector or a subordinate member of a primary entry.
    # Primary entries are either a string (the name of a parameter) or a positive
    # integer. Subordinate entries are an empty string.
    variable ifc_vec_len
    array set ifc_vec_len {}

    # Map from parameter name to the number of ports in the vector. These will be added to
    # a SystemVerilog interface.
    variable ifc_vec_params
    array set ifc_vec_params {}

    # Log transformations for debugging
    variable log_file 0
}

# Does the instance name exist?
proc test_instance_exists {inst} {
    if {[lsearch $::ip_gen_sv::all_instances $inst] == -1} {
        return 0
    }
    return 1
}

# Given a top-level interface, find the internal interface that it exports.
# Return the value of the parameter from the exported interface.
proc get_exported_interface_parameter_value {ifc param} {
    set export_of [get_interface_property $ifc "EXPORT_OF"]
    if {$export_of == ""} {
        return ""
    }

    set s [split $export_of "."]
    if {[llength $s] != 2} {
        return ""
    }

    return [get_instance_interface_parameter_value [lindex $s 0] [lindex $s 1] $param]
}

# Similar to get_exported_interface_parameter_value, but for properties.
proc get_exported_interface_property {ifc prop} {
    set export_of [get_interface_property $ifc "EXPORT_OF"]
    if {$export_of == ""} {
        return ""
    }

    set s [split $export_of "."]
    if {[llength $s] != 2} {
        return ""
    }

    return [get_instance_interface_property [lindex $s 0] [lindex $s 1] $prop]
}

# Map HWTCL interface descriptor to SystemVerilog details, producing an
# entry to be stored in ::ip_gen_sv::ip_ifcs.
#
# Returns a list with the following entries:
#  0: list of ports, formatted as SystemVerilog port declarations. This entry is a
#     list of lists, each with the following entries:
#       0: port name
#       1: list with three entries: port direction, port type, port width if not 1
#       2: number of ports in a merged group, if the port is part of a group
#  1: two entry list of modport names, the first for the IP side and the second for the
#     application side.
proc gen_interface {name ifc port_list} {
    set port_decl [list]

    # Instance from which this public interface is exported
    set export_of_inst [lindex [split [get_interface_property $ifc "EXPORT_OF"] "."] 0]

    # Generate a list of signals in the interface.
    set port_name_list [list]
    foreach port $port_list {
        # Short port name inside the interface scope       
        set pname [get_interface_port_property $ifc $port ROLE]
        if {$pname == ""} {
            set pname $port
        }
        lappend port_name_list $pname
    }

    # Look for a common prefix on each signal in the interface. Prefixes are strings, separated
    # by underscores.
    set common_prefix [split [string trimright [lindex $port_name_list 0] _] _]
    # Can't delete the whole string
    set common_prefix [lrange $common_prefix 0 end-1]
    foreach pname $port_name_list {
        if {[llength $common_prefix] == 0} { break }
        set new_common_prefix [list]
        foreach c $common_prefix p [split $pname "_"] {
            if {$c != $p} { break }
            lappend new_common_prefix $c
        }
        set common_prefix $new_common_prefix
    }
    set common_prefix_len 0
    if {[llength $common_prefix] > 0} {
        set common_prefix_len [string length [join $common_prefix _]_]
        puts $::ip_gen_sv::log_file "${name} ${ifc} removing common prefix: [join $common_prefix _]_"
    }

    # Add signals to the Tcl interface data structure.
    set pname_list [list]
    foreach port $port_list port_name $port_name_list {
        # Short port name inside the interface scope, dropping common prefix if one was found.
        set pname [string range $port_name $common_prefix_len end]
        set ptype "logic"

        set dir [string tolower [get_interface_port_property $ifc $port DIRECTION]]
        if {$dir != "input" && $dir != "output"} {
            set dir "inout"
            set ptype "wire "
        }

        set width [get_interface_port_property $ifc $port WIDTH]
        lappend port_decl [list $pname [list $dir $ptype $width]]
        lappend pname_list $pname
    }

    # Is an associated clock or reset present? If yes, add them to the SV interface.
    # Do not add them if there is already a clock or reset port with the same name.
    set rst [get_exported_interface_parameter_value $ifc associatedReset]
    if {$rst != "" && $export_of_inst == $name} {
        # Find the reset polarity from the port
        set rst_roll [get_first_port_role $name $rst]
        if {[string tolower [string index $rst_roll end]] == "n"} {
            if {[lsearch $pname_list "rst_n"] == -1} {
                set port_decl [lreplace $port_decl 0 -1 [list "rst_n" [list "output" "wire " ""] 0]]
            }
        } else {
            if {[lsearch $pname_list "rst"] == -1} {
                set port_decl [lreplace $port_decl 0 -1 [list "rst" [list "output" "wire " ""] 0]]
            }
        }
    }
    set clk [get_exported_interface_parameter_value $ifc associatedClock]
    if {$clk != "" && $export_of_inst == $name} {
        if {[lsearch $pname_list "clk"] == -1} {
            set port_decl [lreplace $port_decl 0 -1 [list "clk" [list "output" "wire " ""] 0]]
        }
    }

    # Pick modport names
    set class_name [string tolower [get_exported_interface_property $ifc CLASS_NAME]]
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
    set port_decl [merge_interface_ports $name $ifc $port_decl]
    # Rename some interface ports (fix HWTCL poor name choices)
    set port_decl [rename_interface_ports $name $ifc $port_decl]

    return [list $port_decl $mport]
}

proc get_first_port {name ifc} {
    return [lindex [get_interface_ports $ifc] 0]
}

proc get_first_port_role {name ifc} {
    set port [get_first_port $name $ifc]
    set role [get_interface_port_property $ifc $port ROLE]
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
proc rename_interface_ports {name ifc port_list} {
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
            set new_port_name [port_name_to_group $port_name]
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
        puts $::ip_gen_sv::log_file "${name} ${ifc} renaming port ${old_name} to ${new_name}"
    }

    return $new_port_list
}

# Merge interface ports with sequential numbering into a single vector.
# Future HWTCL should describe vectors explicitly.
proc merge_interface_ports {name ifc port_list} {
    set merged_ports [list]
    set cur_merge_orig ""
    set cur_merge_base ""
    set cur_merge_pattern ""
    set cur_merge_set [list]
    set next_id 0

    # List of all port names will be used by the algorithm looking for
    # opportunities to merge ports into vectors.
    set all_port_names [list]
    foreach port $port_list {
        lappend all_port_names [lindex $port 0]
    }

    foreach port $port_list {
        set port_name [lindex $port 0]
        if {$next_id != 0} {
            # Does the current port match the previous one?

            # Extract the index for the candidate, testing whether the pattern matches a group.
            set is_match [regexp $cur_merge_pattern $port_name dummy prefix id]

            if {$is_match} {
                # Pattern matches. Does the type match and is the index monotonically increasing?
                lappend cur_merge_set $port
                if {$id != $next_id || [lindex $cur_merge_orig 1] != [lindex $port 1]} {
                    # Not a group. Enumerate the ports individually
                    # and give up on the current pattern.
                    set merged_ports [concat $merged_ports $cur_merge_set]
                    set cur_merge_base ""
                    set next_id 0
                } else {
                    # Match. Extend the current group.
                    incr next_id
                }
                continue
            } else {
                # No match. Finish the current group.
                if {$next_id > 1} {
                    lappend merged_ports [list $cur_merge_base [lindex $cur_merge_orig 1] $next_id]
                    puts $::ip_gen_sv::log_file "${name} ${ifc} merging ports matching ${cur_merge_pattern}: ${cur_merge_base}\[$next_id\]"
                } else {
                    lappend merged_ports $cur_merge_orig
                }

                set cur_merge_base ""
                set next_id 0
            }
        }

        set is_id0 [is_interface_id0 $port_name $all_port_names]
        if {$is_id0 != ""} {
            # Start a new group from the pattern
            set cur_merge_orig $port
            set cur_merge_pattern $is_id0
            regsub $cur_merge_pattern $port_name "\\1\\3" cur_merge_base
            set cur_merge_set [list $port]
            set next_id 1
        } else {
            # No group. Add the port as is.
            lappend merged_ports $port
        }
    }

    # Finish the last group
    if {$next_id > 1} {
        lappend merged_ports [list $cur_merge_base [lindex $cur_merge_orig 1] $next_id]
        puts $::ip_gen_sv::log_file "${name} ${ifc} merging ports matching ${cur_merge_pattern}: ${cur_merge_base}\[$next_id\]"
    } elseif {$next_id == 1} {
        lappend merged_ports $cur_merge_orig
    }

    return $merged_ports
}

# Map HWTCL interface descriptor with only one port to the same representation
# as gen_interface above. The modport name list is empty.
proc gen_simple_port {name ifc port} {
    # Short port name inside the interface scope       
    set pname [get_interface_port_property $ifc $port ROLE]
    if {$pname == ""} {
        set pname $port
    }

    set width [get_interface_port_property $ifc $port WIDTH]
    if {$width == ""} {
        set width 1
    }

    set dir [string tolower [get_interface_port_property $ifc $port DIRECTION]]
    if {$dir == "input"} {
        set dir "input "
    } elseif {$dir != "output"} {
        set dir "inout "
    }

    return [list [list ${dir} "wire" ${width}] {}]
}

# Read the IP HWTCL and map raw interfaces to ::ip_gen_sv::ip_ifcs and ::ip_gen_sv::ifc_name_map,
# which will be used to generate SystemVerilog interfaces.
proc decode_sv_interfaces {} {
    set name [get_module_property "NAME"]

    if {[info exists ::ip_gen_sv::ifc_name_map]} { array unset ::ip_gen_sv::ifc_name_map }
    if {[info exists ::ip_gen_sv::ifc_name_map_key]} { array unset ::ip_gen_sv::ifc_name_map_key }
    if {[info exists ::ip_gen_sv::ifc_name_map_pattern]} { array unset ::ip_gen_sv::ifc_name_map_pattern }
    if {[info exists ::ip_gen_sv::ifc_groups]} { array unset ::ip_gen_sv::ifc_groups }

    # All exported interfaces
    set ifc_list [lsort_dict [get_interfaces]]

    foreach ifc $ifc_list {
        set port_list [lsort_dict [get_interface_ports $ifc]]

        # Map to a SystemVerilog interface or simple port
        if {[llength $port_list] > 1} {
            set sv_ifc [gen_interface $name $ifc $port_list]
            set pub_ifc $ifc
        } else {
            set pub_ifc [lindex $port_list 0]
            set sv_ifc [gen_simple_port $name $ifc $pub_ifc]
        }

        set map_key ${name}_${ifc}

        # Check if the interface is a candidate for coalescing by dropping
        # a numeric index.
        set is_id0 [is_interface_id0 $pub_ifc [list]]
        if {$is_id0 != ""} {
            set merge_pattern $is_id0
            # Drop the zero index from the name
            regsub $merge_pattern $pub_ifc "\\1\\3" merge_ifc_name
            set ifc_name "${name}_[string trimright $merge_ifc_name _]_if"

            # Save the pattern used to map this id0 interface to the generic form.
            # It will be used when attempting to merge with other interfaces.
            # The pattern has three match groups: prefix, index, and suffix.
            set ::ip_gen_sv::ifc_name_map_pattern($map_key) $merge_pattern

            set ::ip_gen_sv::ip_ifcs($ifc_name) $sv_ifc
            set ::ip_gen_sv::ifc_name_map($map_key) $ifc_name
            set ::ip_gen_sv::ifc_name_map_key($map_key) $map_key
            set ::ip_gen_sv::ifc_groups($map_key) $pub_ifc
            set ::ip_gen_sv::ifc_group_num($map_key) [list 0 0]

            puts $::ip_gen_sv::log_file "${pub_ifc} is id0 of a potential group. Using ${ifc_name}."
            puts $::ip_gen_sv::log_file "  Map key: ${map_key}"
            puts $::ip_gen_sv::log_file "  Pattern: $::ip_gen_sv::ifc_name_map_pattern($map_key)"
        } else {
            # Check existing id0 interfaces for coalescing matches. This is O(n^2) but n is small.
            set found_match 0
            set merge_pattern ""
            set merge_next_group_num 1
            foreach key [array names ::ip_gen_sv::ifc_name_map_pattern] {
                if {[regexp $::ip_gen_sv::ifc_name_map_pattern($key) $pub_ifc dummy prefix idx suffix]} {
                    # Found a name match. Does the interface match?
                    set test_ifc_name $::ip_gen_sv::ifc_name_map($key)

                    # Found a pattern match. Record details of the pattern and port name group IDs in case
                    # the interface does not match.
                    set merge_pattern $::ip_gen_sv::ifc_name_map_pattern($key)
                    if {[lindex $::ip_gen_sv::ifc_group_num($key) 0] >= $merge_next_group_num} {
                        set merge_next_group_num [expr [lindex $::ip_gen_sv::ifc_group_num($key) 0] + 1]
                    }

                    if {[info exists ::ip_gen_sv::ip_ifcs($test_ifc_name)] && $::ip_gen_sv::ip_ifcs($test_ifc_name) == $sv_ifc} {
                        # Merge with the 0 index entry
                        set ::ip_gen_sv::ifc_name_map($map_key) $test_ifc_name
                        set ::ip_gen_sv::ifc_name_map_key($map_key) $key
                        # Add the new interface to the group
                        lappend ::ip_gen_sv::ifc_groups($key) $pub_ifc
                        set found_match 1

                        puts $::ip_gen_sv::log_file "${pub_ifc} matches ${test_ifc_name}."
                        puts $::ip_gen_sv::log_file "  Map key: ${map_key}"
                        puts $::ip_gen_sv::log_file "  Base key: ${key}"
                        puts $::ip_gen_sv::log_file "  Pattern: $::ip_gen_sv::ifc_name_map_pattern($key)"
                        break
                    }
                }
            }

            if {$found_match == 0} {
                if {$merge_pattern != ""} {
                    # Found a pattern match but the interface does not match. Use the
                    # pattern to generate a new name.
                    regexp $merge_pattern $pub_ifc dummy prefix idx suffix
                    set ifc_name "${name}_[string trimright ${prefix}_g${merge_next_group_num}${suffix} _]_if"

                    set ::ip_gen_sv::ifc_name_map_pattern($map_key) $merge_pattern

                    set ::ip_gen_sv::ip_ifcs($ifc_name) $sv_ifc
                    set ::ip_gen_sv::ifc_name_map($map_key) $ifc_name
                    set ::ip_gen_sv::ifc_name_map_key($map_key) $map_key
                    set ::ip_gen_sv::ifc_groups($map_key) $pub_ifc
                    set ::ip_gen_sv::ifc_group_num($map_key) [list $merge_next_group_num $idx]

                    puts $::ip_gen_sv::log_file "${pub_ifc} starts a new group with interface ${ifc_name}."
                    puts $::ip_gen_sv::log_file "  Map key: ${map_key}"
                    puts $::ip_gen_sv::log_file "  Pattern: $::ip_gen_sv::ifc_name_map_pattern($map_key)"
                    puts $::ip_gen_sv::log_file "  Group number / Start index: $::ip_gen_sv::ifc_group_num($map_key)"
                } else {
                    # No match. Use the original name.
                    set ifc_name "${name}_[string trimright $pub_ifc _]_if"
                    set ::ip_gen_sv::ip_ifcs($ifc_name) $sv_ifc
                    set ::ip_gen_sv::ifc_name_map($map_key) $ifc_name
                    set ::ip_gen_sv::ifc_name_map_key($map_key) $map_key
                    puts $::ip_gen_sv::log_file "${ifc} is not part of a group. Using ${ifc_name}."
                }
            }
        }
    }
}

# Generate a mapping from Verilog ports to SystemVerilog ports. The returned
# array will be used to populate the port list for the original Verilog module.
proc gen_verilog_port_map {name port_map_name} {
    upvar 1 $port_map_name port_map
    if {[info exists port_map]} { array unset port_map }

    foreach ifc [lsort_dict [get_interfaces]] {
        set map_key ${name}_${ifc}
        set ifc_name $::ip_gen_sv::ifc_name_map($map_key)
        set sv_ifc $::ip_gen_sv::ip_ifcs($ifc_name)

        if {[llength [lindex $sv_ifc 1]]} {
            set pub_ifc $ifc
        } else {
            set pub_ifc [lindex [get_interface_ports $ifc] 0]
        }

        # Mapped to a vector in SV?
        set vec_idx ""
        if {[info exists ::ip_gen_sv::ifc_vec_len($pub_ifc)]} {
            set vec_idx "\[[ifc_to_group_id $name $ifc $pub_ifc]\]"
        }

        if {[llength [lindex $sv_ifc 1]]} {
            # modports present. Use a SV interface.
            if {$vec_idx != ""} {
                set wrapper_port_name "[string trimright [ifc_to_group $name $ifc] _]${vec_idx}"
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
            foreach port [lsort_dict [get_interface_ports $ifc]] {
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
            set ip_port_name [lindex [get_interface_ports $ifc] 0]
            set wrapper_port_name $ip_port_name
            if {$vec_idx != ""} {
                set wrapper_port_name [ifc_to_group $name $ifc $pub_ifc]
            }
            set wrapper_port_name "[string trimright $wrapper_port_name _]${vec_idx}"
            set port_map($ip_port_name) $wrapper_port_name
        }
    }
}

# Generate a mapping from Verilog clocks and resets to the clk and rst ports
# in the SystemVerilog interfaces.
proc gen_sv_clk_map {name clk_map_name} {
    upvar 1 $clk_map_name clk_map
    if {[info exists clk_map]} { array unset clk_map }

    foreach ifc [lsort_dict [get_interfaces]] {
        set map_key ${name}_${ifc}
        set ifc_name $::ip_gen_sv::ifc_name_map($map_key)
        set sv_ifc $::ip_gen_sv::ip_ifcs($ifc_name)

        # Mapped to a vector in SV?
        set vec_idx ""
        if {[info exists ::ip_gen_sv::ifc_vec_len($ifc)]} {
            set vec_idx "\[[ifc_to_group_id $name $ifc]\]"
        }

        if {[llength [lindex $sv_ifc 1]]} {
            # modports present. Use a SV interface.
            if {$vec_idx != ""} {
                set wrapper_port_name "[string trimright [ifc_to_group $name $ifc] _]${vec_idx}"
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
                    set clk [get_exported_interface_parameter_value $ifc associatedClock]
                    set verilog_port_name [get_first_port $name $clk]
                } else {
                    set rst [get_exported_interface_parameter_value $ifc associatedReset]
                    set verilog_port_name [get_first_port $name $rst]
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
    puts $f "//"
    puts $f "// Generated by [file tail $::ip_gen_sv::info_script]"
    puts $f "//"
    puts $f ""
}

proc gen_pretty_ifc_name {ifc_name} {
    regsub {_if_if$} $ifc_name "_if" ifc_name
    regsub {_interface_if$} $ifc_name "_interface" ifc_name
    regsub -all {_+} $ifc_name "_" ifc_name
    return $ifc_name
}

# Confirm that all the subordinate IP and QSYS projects can be found. If
# they aren't, QSYS will treat them as empty and will miss adding
# top-level ports. Instead of allowing this to happen, abort.
proc check_component_paths {} {
    set err 0
    foreach msg [validate_system] {
        puts "  validate_system: $msg"
        if {[regexp {Error:.*Component .*not found} $msg]} {
            set err 1
        }
    }
    if {$err} {
        puts "Aborting: component not found. Fix search path."
        puts "  The Quartus project's IP_SEARCH_PATHS must be passed as --search-path."
        exit 1
    }
}

proc gen_sv_wrapper {tgt_dir} {
    check_component_paths

    set ::ip_gen_sv::all_instances [lsort_dict [get_instances]]
    set name [get_module_property "NAME"]
    set ip_name $name

    set of [open "${tgt_dir}/${ip_name}_sv.sv" w]
    emit_file_header $of
    set ::ip_gen_sv::log_file [open "${tgt_dir}/${ip_name}_sv.log" w]
    fconfigure $::ip_gen_sv::log_file -buffering line
    emit_file_header $::ip_gen_sv::log_file
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
    puts $hdr_if_file "// Macros describing SystemVerilog interfaces. Interface macros indicate"
    puts $hdr_if_file "// both the presence of a signal and its width."
    puts $hdr_if_file "//"
    puts $hdr_if_file ""
    foreach ifc_name [lsort_dict [array names ::ip_gen_sv::ip_ifcs]] {
        set sv_ifc $::ip_gen_sv::ip_ifcs($ifc_name)
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
            if {$port_width == ""} {
                set port_width 1
            }

            set port_range ""
            if {$port_width != 1} {
                set port_range "\[[expr ${port_width}-1]:0\] "
            }

            puts $hdr_if_file "`define IFC_[string toupper ${pretty_ifc_name}]_WIDTH_[string toupper ${port_name}] ${port_width}"

            if {[llength $port] > 2 && [lindex $port 2] > 0} {
                # Merged port (vector of base ports detected from sequentially numbered naming)
                set n_entries [expr [lindex $port 2] - 1]
                puts $of "  ${port_type} \[${n_entries}:0\] ${port_range}${port_name};"
                puts $hdr_if_file "`define IFC_[string toupper ${pretty_ifc_name}]_PORT_[string toupper ${port_name}]_IS_VEC [expr $n_entries+1]"
            } else {
                puts $of "  ${port_type} ${port_range}${port_name};"
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

    # Reduce individual interfaces into vectors of interfaces
    coalesce_vec_ifs $name

    puts $pkg_file "package ${name}_param_pkg;"
    puts $pkg_file "    localparam NUM_PORTS = $::ip_gen_sv::ifc_vec_params(NUM_PORTS);"
    foreach param [lsort_dict [array names ::ip_gen_sv::ifc_vec_params]] {
        if {$param != "NUM_PORTS"} {
            puts $pkg_file "    localparam $param = $::ip_gen_sv::ifc_vec_params($param);"
        }
    }
    puts $pkg_file "endpackage"
    puts $pkg_file ""

    puts $hdr_if_file ""
    puts $hdr_if_file "//"
    puts $hdr_if_file "// Macros describing ${name}_sv module ports"
    puts $hdr_if_file "//"
    puts $hdr_if_file ""

    puts $of "module ${name}_sv"
    puts $of "  import ${name}_param_pkg::*;"
    puts $of "("

    # All exported interfaces
    set all_ports [list]
    foreach ifc [get_interfaces] {
        set map_key ${name}_${ifc}
        set ifc_name $::ip_gen_sv::ifc_name_map($map_key)
        set sv_ifc $::ip_gen_sv::ip_ifcs($ifc_name)
        set pretty_ifc_name [gen_pretty_ifc_name $ifc_name]

        if {[llength [lindex $sv_ifc 1]]} {
            set pub_ifc $ifc
        } else {
            set pub_ifc [lindex [get_interface_ports $ifc] 0]
        }

        if {[info exists ::ip_gen_sv::ifc_vec_len($pub_ifc)] && $::ip_gen_sv::ifc_vec_len($pub_ifc) == ""} {
            # This interface is already part of a vector. Skip it.
            continue
        }

        # Primary entry of a vector? Add the vector size to the port.
        set vec_len ""
        if {[info exists ::ip_gen_sv::ifc_vec_len($pub_ifc)] && $::ip_gen_sv::ifc_vec_len($pub_ifc) != ""} {
            set vec_len $::ip_gen_sv::ifc_vec_len($pub_ifc)
        }

        if {[llength [lindex $sv_ifc 1]]} {
            # modports present. Use a SV interface.
            set port "  ${pretty_ifc_name}.[lindex [lindex $sv_ifc 1] 0] "
            if {$vec_len != ""} {
                append port "[string trimright [ifc_to_group $name $ifc] _]\[${vec_len}-1:0\]"
                set def_name [string toupper [string trimright [ifc_to_group $name $ifc] _]]
                puts $hdr_if_file "`define ${ip_name}_PORT_${def_name}_IS_VEC ${name}_param_pkg::${vec_len}"
                puts $hdr_if_file "`define ${ip_name}_HAS_PORT_${def_name} 1"
                puts $hdr_if_file "`define ${ip_name}_PORT_${def_name}_IS_SV_IFC ${pretty_ifc_name}"
            } else {
                append port [string trimright $ifc _]
                set def_name [string toupper [string trimright $ifc _]]
                puts $hdr_if_file "`define ${ip_name}_HAS_PORT_${def_name} 1"
                puts $hdr_if_file "`define ${ip_name}_PORT_${def_name}_IS_SV_IFC ${pretty_ifc_name}"
            }
        } else {
            # No SystemVerilog interface. Use a simple port.
            set port_name $pub_ifc
            set simple_port [lindex $sv_ifc 0]
            set port "  [join [lrange $simple_port 0 1]]"

            set port_range ""
            set port_width [lindex $simple_port 2]
            if {$port_width != 1} {
                set port_range "\[[expr ${port_width}-1]:0\] "
            }

            if {$vec_len != ""} {
                append port " \[${vec_len}-1:0\]"
                set port_name [ifc_to_group $name $ifc $pub_ifc]
                puts $hdr_if_file "`define ${ip_name}_PORT_[string toupper [string trimright $port_name _]]_IS_VEC ${name}_param_pkg::${vec_len}"
            }
            append port " ${port_range}[string trimright $port_name _]"
            puts $hdr_if_file "`define ${ip_name}_HAS_PORT_[string toupper [string trimright $port_name _]] 1"
            puts $hdr_if_file "`define ${ip_name}_PORT_WIDTH_[string toupper [string trimright $port_name _]] ${port_width}"
        }

        lappend all_ports $port
        puts $hdr_if_file ""
    }

    puts $of [join $all_ports ",\n"]
    puts $of ");"

    # Instantiate the original IP Verilog wrapper module
    array set verilog_port_map {}
    gen_verilog_port_map $name verilog_port_map
    puts $of ""
    puts $of "  ${name} ${name} ("
    set verilog_ports [lsort_dict [array names verilog_port_map]]
    foreach port [lrange $verilog_ports 0 end-1] {
        puts $of "    .${port}($verilog_port_map($port)),"
    }
    set port [lindex $verilog_ports end]
    puts $of "    .${port}($verilog_port_map($port))"
    puts $of "  );"

    # Assign the clock and reset ports in SV interfaces
    array set sv_clk_map {}
    gen_sv_clk_map $name sv_clk_map
    puts $of ""
    foreach clk [lsort_dict [array names sv_clk_map]] {
        set p $sv_clk_map($clk)
        if {[info exists verilog_port_map($p)]} {
            puts $of "  assign ${clk} = $verilog_port_map($p);"
        }
    }
    puts $of ""
    puts $of "endmodule"

    # Generate sets of IP parameters to write to hdr_params_file. The first group
    # is the set of parameters declared by the top-level internal IP module.
    # The second group is visible parameters that affect generation.
    foreach inst $::ip_gen_sv::all_instances {
        set hdr_top_params [list]
        set hdr_gen_params [list]
        foreach p [lsort_dict [get_instance_parameters $inst]] {
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
    close $::ip_gen_sv::log_file
    close $pkg_file

    puts $hdr_if_file ""
    puts $hdr_if_file "`endif  // $hdr_if_macro"
    close $hdr_if_file
    puts $hdr_params_file ""
    puts $hdr_params_file "`endif  // $hdr_params_macro"
    close $hdr_params_file

    return 0
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

# Map interface names that are index 0 candidates for coalescing to a
# regular expression. The regular expression is used to map any name
# in the candidate group to the base name.
proc is_interface_id0 {ifc all_ifc_names} {
    set p ""
    set found_id1 -1

    # Number at the end of the name
    if {[regexp {[^0-9]0+$} $ifc]} {
        regsub 0+$ $ifc ")(\[0-9\]+)(" p

        # Check whether the matching candidate exists with id 1. If yes,
        # pattern with the index at the end will be favored.
        set id1 [string range $ifc 0 end-1]1
        set found_id1 [lsearch -exact $all_ifc_names $id1]
    }

    if {$found_id1 == -1 && [regexp {[^0-9]0+_} $ifc]} {
        # Number followed by underscore in the middle of the name. This pattern
        # is favored unless an id0/id1 pair with the index at the end has been
        # found already.
        regsub 0+_ $ifc ")(\[0-9\]+)(_" p
    }

    if {$p != ""} {
        return "^($p)$"
    }

    return ""
}

# Map a numbered interface name to a group name.
proc port_name_to_group {ifc} {
    regsub {([^0-9])[0-9]+_} $ifc "\\1_" ifc_base
    return $ifc_base
}

proc ifc_to_group {name ifc {pub_ifc ""}} {
    set map_key $::ip_gen_sv::ifc_name_map_key(${name}_${ifc})
    set pattern $::ip_gen_sv::ifc_name_map_pattern($map_key)

    if {$pub_ifc == ""} {
        set pub_ifc $ifc
    }

    # Does the group have a non-zero group ID? If so, add it to the name.
    set grp_num [lindex $::ip_gen_sv::ifc_group_num($map_key) 0]
    set grp_num_str ""
    if {$grp_num > 0} {
        set grp_num_str "_g${grp_num}"
    }

    regexp $pattern $pub_ifc dummy prefix id suffix
    return "[string trimright $prefix _]${grp_num_str}${suffix}"
}

proc drop_leading_zeros {str} {
    if {$str != ""} {
        set str [string trimleft $str 0]
        if {$str == ""} {
            set str 0
        }
    }
    return $str
}

# Map an interface to the group index.
proc ifc_to_group_id {name ifc {pub_ifc ""}} {
    set map_key $::ip_gen_sv::ifc_name_map_key(${name}_${ifc})
    set pattern $::ip_gen_sv::ifc_name_map_pattern($map_key)

    if {$pub_ifc == ""} {
        set pub_ifc $ifc
    }

    # Mapping from the index from the interface name to the index of the
    # group's vector. Most will both be 0. Ports with matching names but
    # different interfaces are broken into groups and require index mapping.
    set start_id [lindex $::ip_gen_sv::ifc_group_num($map_key) 1]
    set start_id [drop_leading_zeros $start_id]

    regexp $pattern $pub_ifc dummy prefix id suffix
    set id [drop_leading_zeros $id]
    return [expr $id - $start_id]
}

# Potential port coalescing was already discovered during decode_sv_interfaces.
# Check the candidate groups and decide whether they should be combined into
# vectors.
#
# Returns a list of groups to coalesce. Each group is a list of interface names.
proc find_coalesce_groups {name} {
    set coalesce_groups [list]

    # Consider all groups with matching names (different indices)
    foreach map_key [lsort_dict [array names ::ip_gen_sv::ifc_groups]] {
        # Regular expression that formed the group, used to find the indices
        set pattern $::ip_gen_sv::ifc_name_map_pattern($map_key)

        set has_suffix 0
        set expect_idx [lindex $::ip_gen_sv::ifc_group_num($map_key) 1]
        set idx_is_dense 1

        # Each interface in the group
        foreach ifc $::ip_gen_sv::ifc_groups($map_key) {
            regexp $pattern $ifc dummy prefix id suffix
            set id [drop_leading_zeros $id]
            if {$id != $expect_idx} {
                # Not contiguous. Skip coalescing.
                set idx_is_dense 0
                break
            }
            if {$suffix != ""} {
                set has_suffix 1
            }
            set expect_idx [expr $expect_idx + 1]
        }

        if {$idx_is_dense && ($has_suffix || $expect_idx > 1)} {
            # All interfaces in the group are contiguous and have the same suffix.
            # Coalesce them into a single vector.
            lappend coalesce_groups $::ip_gen_sv::ifc_groups($map_key)
            puts $::ip_gen_sv::log_file "${name}: coalescing group $::ip_gen_sv::ifc_groups($map_key)"
        } else {
            puts $::ip_gen_sv::log_file "${name}: $::ip_gen_sv::ifc_groups($map_key) is not a group"
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

# Standard interface to group name mapping
proc map_func_near_prefix {name ifc} {
    if {[regexp {([a-zA-Z]+)[0-9]+(_|$)} $ifc dummy g] == 0} {
        return ""
    }
    set g [string trimright $g _]

    # Don't accept single character results
    if {[string length $g] < 2} {
        return ""
    }

    return $g
}

# foo_txbar0_baz -> bar (same as map_func_near prefix but remove TX and RX,
# trying to merge pairs of interfaces)
proc map_func_near_prefix_drop_txrx {name ifc} {
    set g [map_func_near_prefix $name $ifc]
    regsub -nocase {^(tx|rx)} $g "" g
    return $g
}

# foo_bar0_baz -> foo_bar
proc map_func_full_prefix {name ifc} {
    if {[regexp {([a-zA-Z_]+)[0-9]+(_|$)} $ifc dummy g] == 0} {
        return ""
    }

    # Don't accept single character results
    if {[string length $g] < 2} {
        return ""
    }

    return $g
}

# foo_bar0_baz -> foo_bar_baz
proc map_func_full_name {name ifc} {
    # Try to use the stored pattern match
    set map_ifc $ifc
    if {![info exists ::ip_gen_sv::ifc_groups(${name}_${ifc})]} {
        foreach key [array names ::ip_gen_sv::ifc_groups] {
            if {$::ip_gen_sv::ifc_groups($key) == $ifc} {
                regsub "^${name}_" $key "" map_ifc
                break
            }
        }
    }

    if {[info exists ::ip_gen_sv::ifc_groups(${name}_${map_ifc})]} {
        set g [ifc_to_group $name $map_ifc [lindex $::ip_gen_sv::ifc_groups(${name}_${map_ifc}) 0]]
        regsub "_if$" $g "" g
        return $g
    }

    # Give up and just use the interface name
    regsub {[0-9]+(_|$)} $ifc _ g
    return [string trimright $g _]
}

# Check whether the provided mapping function (one of map_func_* above) can
# be used to generate names for the provided list of groups. A mapping function
# can be used if each generated name corresponds to a single vector size.
proc coalesce_try_map_func {name groups map_func} {
    array set name_to_size {}
    foreach group $groups {
        set mapped_name [$map_func $name [lindex $group 0]]
        if {$mapped_name == ""} {
            # Mapping function failed. Try the next one.
            return 0
        }

        if {[info exists name_to_size($mapped_name)]} {
            if {$name_to_size($mapped_name) != [llength $group]} {
                # Name would correspond to multiple vector lengths
                return 0
            }
        } else {
            set name_to_size($mapped_name) [llength $group]
        }
    }

    # Mapping works. Update ::ip_gen_sv::ifc_vec_len with chosen naming.
    foreach group $groups {
        set mapped_name [string toupper [$map_func $name [lindex $group 0]]]

        if {$mapped_name != "PORTS"} {
           set param_name "NUM_${mapped_name}"
        } else {
           set param_name "GRP_PORTS"
        }
        set ::ip_gen_sv::ifc_vec_params($param_name) [llength $group]
        set ::ip_gen_sv::ifc_vec_len([lindex $group 0]) $param_name
        foreach ifc [lrange $group 1 end] {
            set ::ip_gen_sv::ifc_vec_len($ifc) ""
        }
    }

    return 1
}

proc coalesce_vec_ifs {name} {
    if {[info exists ::ip_gen_sv::ifc_vec_len]} { array unset ::ip_gen_sv::ifc_vec_len }
    if {[info exists ::ip_gen_sv::ifc_vec_params]} { array unset ::ip_gen_sv::ifc_vec_params }

    set coalesce_groups [find_coalesce_groups $name]
    if {[llength $coalesce_groups] == 0} {
        # Nothing to combine. Add a dummy NUM_PORTS for consistency.
        set ::ip_gen_sv::ifc_vec_params(NUM_PORTS) 1
        return
    }

    set num_ports [coalesce_get_num_ports $coalesce_groups]
    puts $::ip_gen_sv::log_file "${name}: coalescing interfaces into vectors of $num_ports ports"

    # Assign NUM_PORTS to the group with that size. Keep the remaing
    # groups in a list to be processed later.
    set ::ip_gen_sv::ifc_vec_params(NUM_PORTS) $num_ports
    set remaining_groups [list]
    foreach group $coalesce_groups {
        if {[llength $group] == $num_ports} {
            set ::ip_gen_sv::ifc_vec_len([lindex $group 0]) "NUM_PORTS"
            foreach ifc [lrange $group 1 end] {
                set ::ip_gen_sv::ifc_vec_len($ifc) ""
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
    if {[coalesce_try_map_func $name $remaining_groups map_func_near_prefix_drop_txrx]} { return }
    if {[coalesce_try_map_func $name $remaining_groups map_func_near_prefix]} { return }
    if {[coalesce_try_map_func $name $remaining_groups map_func_full_prefix]} { return }
    if {[coalesce_try_map_func $name $remaining_groups map_func_full_name]} { return }

    # This point should not be reached. At least map_func_full_name should have
    # generated unique names for each group.
    puts "ERROR: Failed to coalesce interfaces into vectors"
    exit 1
}

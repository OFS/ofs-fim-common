# Copyright 2023 Intel Corporation
# SPDX-License-Identifier: MIT

##
## This is the post-module script that should be invoked as a
## POST_MODULE_SCRIPT_FILE for most platform's base FIM builds.
##
## Quartus invokes only one POST_MODULE_SCRIPT_FILE. Boards that
## need platform-specific scripts should set a board-specific script
## as the primary POST_MODULE_SCRIPT_FILE and then invoke this
## common script from it.
##

# Execute command (a list with command and arguments), print output
# detect errors.
proc ofs_post_module_exec {msg cmd_list} {
    set cmd_str [join $cmd_list]
    if {[string match "quartus*" $cmd_str]} {
        # Quartus commands already print their arguments with "Command:"
        post_message $msg -submsgs [list "${cmd_str}"]
    } else {
        # Prefix non-quartus with "Command:" so they are easily found in a log
        post_message $msg -submsgs [list "Command: ${cmd_str}"]
    }

    if {[catch {exec {*}${cmd_list}} output]} {
        post_message $output
        post_message -type error "Error executing: ${cmd_str}"
    } else {
        post_message $output
    }
}

proc ofs_post_module_script_fim {} {
    set module [lindex $::quartus(args) 0]
    set project [lindex $::quartus(args) 1]
    set revision [lindex $::quartus(args) 2]

    set THIS_DIR [file dirname [info script]]

    if {$module == "quartus_ipgenerate"} {
        # Extract configuration parameters from IP into header files in the
        # project's ofs_ip_cfg_db subdirectory.

        # The project isn't open yet
        project_open ${project} -revision ${revision}

        # Is the configuration database Tcl loaded in this project?
        if { ! [llength [info procs ::ofs_ip_cfg_db::generate]] } {
            post_message -type Warning "ofs_ip_cfg_db.tcl is not loaded in this project"
        } else {
            post_message "Generating OFS IP configuration database in ofs_ip_cfg_db/"
            ::ofs_ip_cfg_db::generate
        }

        project_close
    }

    if {$module == "quartus_syn"} {
        # Generate a Tcl script with project macros for use in PR builds
        post_message -type info "Running ofs_post_module_script_fim.tcl for ${module}"

        # Summary SDC file with all FIM constraints
        ofs_post_module_exec "Emitting FIM project macros for use in PR..." \
            [list quartus_sh -t "${THIS_DIR}/emit_project_macros.tcl" \
                 --project=${project} --revision=${revision} \
                 --output=fim_project_macros.tcl --mode=tcl]
    }

    if {$module == "quartus_fit"} {
        # Generate a memory file with an FME interface ID
        post_message -type info "Running ofs_post_module_script_fim.tcl for ${module}"

        # Generate the UID and container
        ofs_post_module_exec "Generating FME ID..." \
            [list python3 "${THIS_DIR}/update_fme_ifc_id.py" "." ${revision}]

        # Remove stale FPGA images
        file delete {*}[glob -nocomplain output_files/*.sof output_files/*.rbf \
                                         output_files/*.bin output_files/*.green_region.*]

        ofs_post_module_exec "Updating database..." \
            [list quartus_cdb ${project} -c ${revision} --update_mif]
    }

    if {$module == "quartus_asm"} {
        # Export base partition for use in PR projects. This could be replaced
        # with an EXPORT_PARTITION_SNAPSHOT_FINAL instance assignment.
        post_message -type info "Running ofs_post_module_script_fim.tcl for ${module}"

        ofs_post_module_exec "Exporting root_partition..." \
            [list quartus_cdb ${project} -c ${revision} \
                 --export_partition root_partition --snapshot final \
                 --file "${revision}.qdb" --include_sdc_entity_in_partition]
    }

    if {$module == "quartus_sta"} {
        # Emit state needed for PR builds after timing analysis
        post_message -type info "Running ofs_post_module_script_fim.tcl for ${module}"

        # Summary SDC file with all FIM constraints
        ofs_post_module_exec "Emitting FIM timing constraints..." \
            [list quartus_sta -t "${THIS_DIR}/create_sdc_for_pr_compile.tcl" \
                 ${project} ${revision} "${project}.out.sdc"]

        # Summary TCL file with all IP loaded in the FIM build
        ofs_post_module_exec "Emitting FIM IP list..." \
            [list quartus_ipgenerate -t "${THIS_DIR}/emit_project_ip.tcl" \
                 --project=${project} --revision=${revision} \
                 --output=fim_base_ip.tcl]
    }
}

ofs_post_module_script_fim

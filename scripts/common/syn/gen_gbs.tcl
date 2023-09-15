# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

##
## Generate a GBS file from the RBF file assembled by a PR Quartus build.
##
## The script can be invoked automatically as a POST_FLOW_SCRIPT_FILE or
## explicitly. It expects the standard post flow script arguments:
##
##    quartus_sh -t gen_gbs.tcl compile <project> <revision>
##

proc find_json_file {} {
    # Look for the AFU JSON file
    set afu_json_file ""

    # Is it defined in the project?
    catch {set afu_json_file [get_afu_json_file]}

    # Try the environment variable OFS uses during in-tree PR builds
    if {$afu_json_file == "" && [info exists ::env(WORK_PR_JSON_FILE)]} {
        set afu_json_file $::env(WORK_PR_JSON_FILE)
    }

    if {$afu_json_file == ""} {
        # Last try: look for JSON files in the current directory
        foreach j [glob -nocomplain *.json] {
            # Does the JSON file look like an AFU descriptor?
            set file [open $j r]
            while {[gets $file line] != -1} {
                if {[string match "*accelerator-clusters*" $line]} {
                    set afu_json_file $j
                    break
                }
            }
            # Found one?
            if {$afu_json_file != ""} break
        }
    }

    # Might return empty string if no JSON file found
    return $afu_json_file
}

# Get any environment variable and abort if not defined
proc get_env_variable {v} {
    if {! [info exists ::env($v)]} {
        post_message -type error "$v environment variable not defined!"
        project_close
        exit 1
    }

    return $::env($v)
}

# Return user clock settings from $uclk_fname as a list. Returns an empty
# list if the file doesn't exist.
proc get_uclk_cfg {uclk_fname} {
    if {! [file exists $uclk_fname]} {
        return {}
    }

    set uclks {}
    set file [open $uclk_fname r]
    while {[gets $file line] != -1} {
        # Ignore comments
        if {! [string match "#*" $line]} {
            set uclks [concat $uclks $line]
        }
    }

    return $uclks
}

proc main {} {
    set project [lindex $::quartus(args) 1]
    set revision [lindex $::quartus(args) 2]

    project_open -revision $revision $project

    set afu_json_file [find_json_file]
    if {$afu_json_file == ""} {
        post_message -type error "Cannot find AFU JSON file!"
        project_close
        exit 1
    }
    post_message "AFU JSON file: ${afu_json_file}"

    # These environment variables are defined in the FIM build. They
    # are expected to be carried over to PR builds by storing them in
    # build_env_db.txt.
    set partition [get_env_variable Q_PR_PARTITION_NAME]
    post_message "Partition: ${partition}"
    set fme_ifc_id [get_env_variable FME_IFC_ID]
    post_message "FME interface ID: ${fme_ifc_id}"

    # Input RBF file 
    set rbf_fname "output_files/${revision}.${partition}.rbf"
    if {! [file exists $rbf_fname]} {
        post_message -type error "${rbf_fname} not found!"
        project_close
        exit 1
    }

    # Target GBS file name
    set gbs_fname "output_files/${revision}.${partition}.gbs"

    # Construct the packager command. The command name might be overridden
    # by the PACKAGER environment variable.
    if {[info exists ::env(PACKAGER)]} {
        set cmd $::env(PACKAGER)
    } else {
        set cmd {packager}
    }
    set cmd [concat $cmd create-gbs]
    set cmd [concat $cmd "--gbs=${gbs_fname}"]
    set cmd [concat $cmd "--afu-json=${afu_json_file}"]
    set cmd [concat $cmd "--rbf=${rbf_fname}"]
    set cmd [concat $cmd "--set-value interface-uuid:${fme_ifc_id}"]
    set cmd [concat $cmd [get_uclk_cfg "output_files/user_clock_freq.txt"]]

    post_message "Executing: $cmd"
    post_message [exec {*}$cmd 2>@1]

    project_close
}

main

##
## FIM sources are specified using relative paths, relying on the BUILD_ROOT_REL
## environment variable to point to the root of a source tree. The variable must
## be set the first time Quartus loads a FIM project. When loading a synthesized
## project, users may see errors about BUILD_ROOT_REL missing if they haven't
## set the variable explicitly.
##
## This code reads key/value pairs from a database created during FIM setup
## (build_env_db.txt in the project directory) and stores them as environment
## variables.
##
## For reasons that should be obvious, the project must be able to find this
## config_env.tcl script without BUILD_ROOT_REL. This script is copied during
## FIM build setup from a common location to a well-known location in the
## build tree.
##

set build_env_db_name "build_env_db.txt"

# Load saved environment if it exists
if {[file exists $build_env_db_name]} {
    set fp [open $build_env_db_name]

    # Contents of the file
    set v [read $fp]
    # Drop comments
    set v [string trim [regsub -all -line {(^#.*$)} $v ""]]
    # Look for lines of the form: NAME = value
    foreach line [split $v "\n"] {
        # Drop whitespace around the equal sign
        set line [regsub -all -line {\s*=\s*} $line "="]
        set e [split $line "="]
        if {[llength $e] == 2} {
            # Found <key>=<value>
            set key [lindex $e 0]
            set val [lindex $e 1]

            if { [info exists ::env($key)] } {
                if {$val != $::env($key)} {
                    post_message -type warning "::env($key) (\"$::env($key)\") does not match previous value (\"$val\")"
                }
            } else {
                set ::env($key) $val
                post_message -type info "Setting ::env($key)=$val"
            }
        }
    }
}

if { ![info exists ::env(BUILD_ROOT_REL)] } {
    post_message -type error "BUILD_ROOT_REL environment variable is undefined!"
} else {
    post_message -type info "BUILD_ROOT_REL is $::env(BUILD_ROOT_REL)"
}

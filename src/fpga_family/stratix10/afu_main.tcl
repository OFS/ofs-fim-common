# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

#--------------------
# AFU modules
#--------------------

# REVISION_TYPE is PR_IMPL in PR partitions. Set a macro for use in RTL
# sources -- used to guide the default AFU example instantiation.
set part_revision_type PR_BASE
catch { set part_revision_type [get_global_assignment -name REVISION_TYPE] }
if { $part_revision_type == "PR_IMPL" } {
    set_global_assignment -name VERILOG_MACRO "PR_COMPILE"
}


# What type of AFU is being instantiated?

if { [info exist env(OPAE_PLATFORM_GEN) ] } {

    # In OPAE_PLATFORM_GEN mode, used only when generating the out-of-tree PR build
    # environment. Only the PIM's afu_main.sv is loaded as a template. It does not
    # instantiate any other sources.
    set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/stratix10/port_gasket/afu_main_pim/afu_main.sv

    # Request the simulation-time module for ASE that instantiates an afu_main
    # emulator. The emulator will construct a platform-specific emulation of
    # the interface to afu_main.
    set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/stratix10/port_gasket/afu_main_pim/sim/ase_afu_main_emul.sv

} else {

    # This is the normal flow. Start by importing Platform Interface Manager
    # RTL. Just because the PIM is loaded doesn't mean it is used by the AFU.
    # The PIM may be used in two modes. One, when afu.tcl is present, wraps the
    # AFU in a standard PIM module wrapper (ofs_plat_afu). The other mode
    # does not impose a module hierarchy, but PIM modules are available for
    # use by any AFU to transform individual PCIe or local memory ports.

    # Load the PIM
    if { [file exists afu_with_pim/pim.tcl] } {
        set_global_assignment -name SOURCE_TCL_SCRIPT_FILE afu_with_pim/pim.tcl
    }

    if { [file exists afu_with_pim/afu.tcl] } {

        # afu_with_pim/afu.tcl exists. An AFU based on the Platform Interface
        # Manager has been configured.
        post_message "Loading PIM-based AFU..."

        # Load the connector from the FIM to the PIM
        set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/stratix10/port_gasket/afu_main_pim/afu_main.sv
        # Load the AFU
        set_global_assignment -name SOURCE_TCL_SCRIPT_FILE afu_with_pim/afu.tcl

    } else {

        post_message "Loading device exerciser AFU..."

        # Standard exerciser sources, used for testing
        set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/afu_main_std_exerciser_design_files.tcl

        # No AFU or PIM specific. Instantiate the default exercisers.
        if { $part_revision_type == "PR_IMPL" } {
            post_message "Instantiating pr-compile based afu_main.sv..."
            set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/stratix10/port_gasket/afu_main_std_exerciser/pr_compile/afu_main.sv
        } else {
            post_message "Instantiating fim-compile based afu_main.sv..."
            set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/stratix10/port_gasket/afu_main_std_exerciser/fim_compile/afu_main.sv
        }
    }
}

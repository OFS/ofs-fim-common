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

# The default afu_main() is now a generic wrapper that sets up the AFU
# environment. It converts multiplexed AXI-S PCIe TLP interfaces into
# separate VF-specific interfaces, which are then passed to
# port_afu_instances(). The PIM-based flow and out-of-tree build
# configuration also use the default afu_main().
set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/port_gasket/afu_main_std_exerciser/fim_compile/afu_main.sv

# Set a macro to indicate that afu_main() instantiates port_afu_instances().
# AFUs may test this to conditionally use the shared afu_main() instead of
# defining their own.
set_global_assignment -name VERILOG_MACRO "SHARED_AFU_MAIN_TO_PORT_AFU_INSTANCES"

# Set another macro indicating that afu_main() contains a PF/VF MUX and
# that only a single, multiplexed, TLP stream enters afu_main().
set_global_assignment -name VERILOG_MACRO "AFU_MAIN_HAS_PF_VF_MUX"

# What type of AFU is being instantiated?

if { [info exist env(OPAE_PLATFORM_GEN) ] } {

    # In OPAE_PLATFORM_GEN mode, used only when generating the out-of-tree PR build
    # environment. Only the PIM's afu_main.sv is loaded as a template. It does not
    # instantiate any other sources.
    set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/port_gasket/afu_main_pim/port_afu_instances.sv

    # Request the simulation-time module for ASE that instantiates an afu_main
    # emulator. The emulator will construct a platform-specific emulation of
    # the interface to afu_main.
    set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/port_gasket/afu_main_pim/sim/ase_afu_main_emul.sv

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
        set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/port_gasket/afu_main_pim/port_afu_instances.sv
        # Load the AFU
        set_global_assignment -name SOURCE_TCL_SCRIPT_FILE afu_with_pim/afu.tcl

        if { $part_revision_type != "PR_IMPL" } {
            # Building the FIM, but the PIM's wrapper around ofs_plat_afu() was
            # requested. Probably by setting the AFU_WITH_PIM environment variable
            # when running the build_top.sh setup script.
            #
            # The FIM still needs the standard exercisers for the static region.
            set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/afu_main_std_exerciser_design_files.tcl
        }

    } else {

        post_message "Loading device exerciser AFU..."

        # Standard exerciser sources, used for testing
        set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/afu_main_std_exerciser_design_files.tcl
        set_global_assignment -name SYSTEMVERILOG_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/port_gasket/afu_main_std_exerciser/fim_compile/port_afu_instances.sv

    }
}

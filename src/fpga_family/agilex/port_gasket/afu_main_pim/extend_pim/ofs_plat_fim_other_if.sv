// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
// -----------------------------------------------------------------------------
//  Platform-specific interface passed through the PIM's "other" class.
//  This is a sideband interface not managed by the PIM and have any value.
// -----------------------------------------------------------------------------

//
// When the [other] group is added to the PIM's .ini file, the PIM
// adds a generic wrapper interface to its top-level plat_ifc as
// plat_ifc.other.ports[]. Each port is of type ofs_plat_fim_other_if,
// defined here. The PIM has no knowledge of the contents of this type.
// It is available to individual platforms for passing state that is
// otherwise difficult to manage in the PIM.
//
// The "other" interface is mapped to a vector of ports as a standard
// PIM abstraction. All PIM top-level objects are vectors. Many systems
// will use only a single port. A single port is the default.
//
// NOTE: there is a corresponding ofs_plat_other_fiu_if_tie_off() module
// that must match the definition here. The PIM will instantiate the module
// on each port when required.
//

`include "ofs_plat_if.vh"

interface ofs_plat_fim_other_if
  #(
    parameter ofs_plat_log_pkg::t_log_class LOG_CLASS = ofs_plat_log_pkg::NONE
    );

    // *** Add platform-specific state here ***


    // Sample container. We suggest that you keep this in your implementation.
    // It is used in tutorials as a demonstration of this interface. As long
    // as it is unconsumed in your design no area will be wasted.
    logic [31:0] sample_state;

    //
    // Connection from a module toward the platform (FPGA Interface Manager)
    //
    modport to_fiu
       (
        input  sample_state
        );

    //
    // Connection from a module toward the AFU
    //
    modport to_afu
       (
        output sample_state
        );

endinterface // ofs_plat_fim_other_if

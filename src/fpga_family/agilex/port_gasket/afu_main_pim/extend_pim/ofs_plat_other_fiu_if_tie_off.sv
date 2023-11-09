// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
// -----------------------------------------------------------------------------
//  Tie off a platform-specific interface passed through the PIM's "other"
//  class.
// -----------------------------------------------------------------------------

//
// Tie off a single platform-specific "other" interface port. Add code
// here to match ofs_plat_fim_other_if.
//
// Just like all other host channel and local memory ports, this module is
// connected to each "other" port only when the PIM is responsible for tying
// them off.
//

module ofs_plat_other_fiu_if_tie_off
   (
    ofs_plat_fim_other_if.to_fiu port
    );

    // *** Add platform-specific state here ***

endmodule // ofs_plat_other_fiu_if_tie_off

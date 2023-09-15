// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// Global data types and configuration for the PF/VF MUX.
//

package pf_vf_mux_pkg;

    //
    // The PF/VF routing table is an array of t_pfvf_rtable_entry structs.
    // The routing function returns the pfvf_port of the first matching
    // array entry.
    //

    typedef struct packed {
        int pfvf_port;		// MUX port index (the routing decision)
        int pf;			// PF (-1 matches any PF)
        int vf;			// VF (-1 matches any VF)
        bit vf_active;          // Is VF active? There is no wildcard here.
                                // To test both VF active and inactive for
                                // the same PF, use two table entries.
    } t_pfvf_rtable_entry;

    // Return 1 if the table entry matches PF/VF.
    function bit pfvf_tbl_matches(
        input int pf,
        input int vf,
        input bit vf_active,
        input t_pfvf_rtable_entry tbl_entry
        );

        // VF active must match exactly. PF and VF must either match or
        // have -1 in the table entry to match any function.
        if ((vf_active == tbl_entry.vf_active) &&
            ((pf == tbl_entry.pf) || (tbl_entry.pf == -1)) &&
            ((vf == tbl_entry.vf) || (tbl_entry.vf == -1)))
        begin
            return 1;
        end

        return 0;
    endfunction // pfvf_tbl_matches

endpackage // pf_vf_mux_pkg

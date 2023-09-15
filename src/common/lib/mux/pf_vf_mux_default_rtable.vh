// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: MIT

//
// This is the default PF/VF MUX routing table constructor for the FIM's
// static region. Include it in the middle of a top_cfg_pkg after the
// required localparams have been set.
//
// The default table assigns a single function to each MUX port. All PFs
// are mapped first. VFs are added to the table after all PFs. When the
// input parameter ENABLE_PG_SHARED_VF is non-zero, PF0's VFs are all
// routed to the last port (PG_SHARED_VF_PID), which is connected to
// the port gasket and afu_main().
//
// Input localparams (define before including this file):
//
//   NUM_SR_PORTS -
//     Number of ports to the static region. This must be the sum of all
//     functions, both PF and VF, excluding PF0's VFs. Each function will
//     map to a unique port. The table constructor will append one
//     additional slot for PF0 VFs.
//
//   ENABLE_PG_SHARED_VF -
//     When non-zero, append a router port in the last slot to which all
//     PF0 VFs are routed.
//
//   MAX_PF_NUM -
//     Number of the largest enabled PF. PF numbering does not have to be
//     dense. MAX_PF_NUM defines the range of input vectors describing
//     enabled PFs and VFs.
//
//   PF_ENABLED_VEC[MAX_PF_NUM+1] -
//     Vector index by PF number indicating whether a PF is enabled (0 or 1).
//
//   PF_NUM_VFS_VEC[MAX_PF_NUM+1] -
//     Vector of int, indexed by PF number, with the number of VFs bound
//     to each PF.
//
//
// Outputs:
//
//   PG_SHARED_VF_PID -
//     Index in the routing table of the appended port for all PF0 VFs.
//     This will always be the last port. When ENABLE_PG_SHARED_VF is 0,
//     the PID will be -1.
//
//   t_pf_vf_entry_info -
//     The generated routing table's type, a vector of table entries:
//       pf_vf_mux_pkg::t_pfvf_rtable_entry [NUM_RTABLE_ENTRIES-1:0]
//
//   SR_PF_VF_RTABLE -
//     The generated routing table, a localparam of type t_pf_vf_entry_info.
//


// DO NOT PREVENT LOADING THIS MULTIPLE TIMES! It may be included in more
// than one package when there are multiple PCIe interfaces.

// Static region routing table data structure
localparam NUM_RTABLE_ENTRIES = NUM_SR_PORTS + (ENABLE_PG_SHARED_VF ? 1 : 0);
typedef pf_vf_mux_pkg::t_pfvf_rtable_entry [NUM_RTABLE_ENTRIES-1:0] t_pf_vf_entry_info;
localparam t_pf_vf_entry_info SR_PF_VF_RTABLE = get_pf_vf_entry_info();

// Port index in the static region MUX that should be routed to the
// port gasket. (These are the PF0 VFs.) This port is expected to be
// last.
localparam PG_SHARED_VF_PID = (ENABLE_PG_SHARED_VF ? NUM_SR_PORTS : -1);

//
// Generate the default table, mapping each function to a unique port.
//
// NOTE: If you are replacing this table for a specific design, probably
//       in order to map multiple functions to a single port, you could
//       choose to define t_pf_vf_entry_info statically instead of using
//       a function. The function here adapts to changes in PF/VF
//       topology in order to handle multiple reference designs. It may
//       be unnecessarily complex for a single, fixed topology.
//
function automatic t_pf_vf_entry_info get_pf_vf_entry_info();
    int cur_pf;
    int cur_vf;
    bit mapping_vfs;
    t_pf_vf_entry_info map;

    cur_pf = 0;
    cur_vf = 0;
    mapping_vfs = 0;

    for (int p = 0; p < NUM_RTABLE_ENTRIES; p = p + 1) begin
        if (p == PG_SHARED_VF_PID) begin
            // The last port in the vector routes any PF0 VF to the
            // port gasket.
            map[p].pf        = 0;
	    map[p].vf        = -1;  // Match any VF
	    map[p].vf_active = 1;
            map[p].pfvf_port = PG_SHARED_VF_PID;
        end else begin
            // SR ports passed to fim_afu_instances()
            map[p].pf        = cur_pf;
            map[p].vf        = cur_vf;
            map[p].vf_active = mapping_vfs;
            map[p].pfvf_port = p;

            // Pick the next port to map. All PFs are mapped first, then
            // VFs associated with the PFs are mapped.
            if (mapping_vfs && (cur_vf != PF_NUM_VFS_VEC[cur_pf]-1)) begin
                // VFs are being mapped and the current PF isn't done yet
                cur_vf = cur_vf + 1;
            end else begin
                // Move to the next PF. If we are now mapping VFs, then look
                // for a PF with enabled VFs.
                cur_vf = 0;
                cur_pf = get_next_enabled_pf(cur_pf, mapping_vfs);
                if (cur_pf == -1) begin
                    // Reached the end of the PFs. Start at the beginning and
                    // switch to mapping VFs. PF0's VFs are not part of the
                    // mapping here, so get the next PF after PF0.
                    cur_pf = get_next_enabled_pf(0, 1);
                    mapping_vfs = 1;
                end
            end
        end
    end

    return map;
endfunction 

// Find the next enabled PF after cur_pf. If with_vfs is set then only return
// PFs that have associated VFs. This function is used in combination with
// the routing table generator above when mapping PF/VF pairs to ports.
function automatic int get_next_enabled_pf(int cur_pf, bit with_vfs);
    int pf_num = cur_pf;
    while (pf_num < MAX_PF_NUM) begin
        pf_num = pf_num + 1;
        if (PF_ENABLED_VEC[pf_num] && (!with_vfs || (PF_NUM_VFS_VEC[pf_num] > 0))) begin
            // This PF is enabled and either has VFs or we are just looking for PFs.
            return pf_num;
        end
    end

    // No more enabled PFs
    return -1;
endfunction

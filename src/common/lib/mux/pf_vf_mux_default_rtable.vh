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
//   NUM_TOP_PORTS -
//     Number of ports on the top level mux. This is PF0, plus one 
//     additional port for the port gasket which routes PF0 VFs when VFs are enabled on PF0 or
//     routes PF1 when VFs are disabled on PF0, and all non-PF0/non-PF0+non-PF1 functions.
//
//   NUM_SR_PORTS -
//     Number of ports to 2nd level static region. This must be the sum of all
//     functions, both PF and VF, excluding PF0 & Port Gasket entries. Each function will
//     map to a unique port.
//
//   ENABLE_PG_SHARED_VF -
//     When non-zero, append a router port in the last slot to which all
//     PF0 VFs are routed when VFs are enabled on PF0 or PF1 is routed when
//     VFs on PF0 are disabled.
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
//     Index in the routing table of the appended port for all PF0 VFs or PF1.
//     This will always be the last port. 
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

// PF0 entry, static-region entries (2 entries to toggle VF active), port gasket entry (PF0 VF or PF1)
localparam NUM_TOP_RTABLE_ENTRIES = 1 + 
				    ((NUM_SR_PORTS > 0)  ? 2 : 0) + 1;

// Static region routing table data structure
localparam NUM_SR_RTABLE_ENTRIES = (NUM_SR_PORTS > 0) ? NUM_SR_PORTS : 1;
typedef pf_vf_mux_pkg::t_pfvf_rtable_entry [NUM_TOP_RTABLE_ENTRIES-1:0] t_top_pf_vf_entry_info;
localparam t_top_pf_vf_entry_info TOP_PF_VF_RTABLE = get_top_pf_vf_entry_info();

typedef pf_vf_mux_pkg::t_pfvf_rtable_entry [NUM_SR_RTABLE_ENTRIES-1:0] t_sr_pf_vf_entry_info;
localparam t_sr_pf_vf_entry_info SR_PF_VF_RTABLE = get_sr_pf_vf_entry_info();

// Port index in the static region MUX that should be routed to the
// port gasket. (These are the PF0 VFs when VFs are enabled on PF0 or PF1 when VFs on PF0 are disabled.) 
//This port is expected to be last.
localparam PF0_MGMT_PID       = 0;
localparam PG_SHARED_VF_PID   = 1;
localparam SR_SHARED_PFVF_PID = ((NUM_SR_PORTS > 0)  ? NUM_TOP_PORTS-1 : -1);

// 
// Generate the default top AFU table
//
function automatic t_top_pf_vf_entry_info get_top_pf_vf_entry_info();
    t_top_pf_vf_entry_info map;
    for (int p = 0; p < NUM_TOP_RTABLE_ENTRIES; p = p + 1) begin
        if (p == PF0_MGMT_PID) begin
            // Map the management port
            map[p].pf        = 0;
            map[p].vf        = 0;
            map[p].vf_active = 0;
            map[p].pfvf_port = PF0_MGMT_PID;
        end else if (p == PG_SHARED_VF_PID) begin
            // Map the port gasket port
            map[p].pf        =  ENABLE_PG_SHARED_VF ? 0 : 1;  //pf0vfs or pf1
            map[p].vf        =  ENABLE_PG_SHARED_VF ? -1: 0;  // Match any VF
            map[p].vf_active =  ENABLE_PG_SHARED_VF ? 1 : 0;  //pf0vfs or pf1
            map[p].pfvf_port = PG_SHARED_VF_PID;
        end else begin
            // Map the static AFU port to everything else
            map[p].pf        = -1;
            map[p].vf        = -1;
            // p>0 in this branch and will execute 2x if reachable
            // So we take the compliment of the prev entry to get full 
            // vf_active coverage
            map[p].vf_active =  ~map[p-1].vf_active;
            map[p].pfvf_port = SR_SHARED_PFVF_PID;
        end
    end
    return map;
endfunction 

//
// Generate the default static-region AFU table, mapping each function to a unique port.
//
// NOTE: If you are replacing this table for a specific design, probably
//       in order to map multiple functions to a single port, you could
//       choose to define t_pf_vf_entry_info statically instead of using
//       a function. The function here adapts to changes in PF/VF
//       topology in order to handle multiple reference designs. It may
//       be unnecessarily complex for a single, fixed topology.
//
function automatic t_sr_pf_vf_entry_info get_sr_pf_vf_entry_info();
    int cur_pf;
    int cur_vf;
    bit mapping_vfs;
    t_sr_pf_vf_entry_info map;

    // Start from PF1 when VFs are enabled on PF0, else start
    // from PF2, PF0 is a device management port, PF0VF/PF1 is reserved for port gasket
    cur_pf = (ENABLE_PG_SHARED_VF || PG_NUM_PORT == 0) ? 1 : 2;
    cur_vf = 0;
    mapping_vfs = 0;

    for (int p = 0; p < NUM_SR_RTABLE_ENTRIES; p = p + 1) begin
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

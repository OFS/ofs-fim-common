// Copyright (C) 2023 Intel Corporation.
// SPDX-License-Identifier: MIT
//
`ifndef __HOST_BFM_TYPES_PKG__
`define __HOST_BFM_TYPES_PKG__

`include "ofs_ip_cfg_db.vh"

package host_bfm_types_pkg; 

//----------------------------------------------------------------------------------------------------
// Parameter and Enum Definitions for Host BFM.
//----------------------------------------------------------------------------------------------------

typedef bit   [9:0] packet_tag_t;
typedef logic [7:0] byte_t;
typedef bit  [23:0] dm_length_t;
typedef bit  [63:0] addr_t;
typedef bit [127:0] uint128_t;
typedef longint unsigned uint64_t;
typedef int unsigned uint32_t;
typedef byte_t byte_array_t [];
typedef bit pf_array_t [];
typedef int vf_array_t [];
typedef bit default_pfs[1];
typedef int default_vfs[1];
typedef struct packed {
   bit  [2:0] pfn;
   bit [10:0] vfn;
   bit        vfa;
} pfvf_struct;
typedef enum {
   START,
   START_ACK,
   STOP,
   STOP_ACK,
   READY,
   READY_ACK,
   GO,
   GO_ACK,
   WAIT,
   WAIT_ACK,
   RUNNING,
   ERROR,
   PASS,
   FAIL,
   HALT,
   HALT_ACK,
   DONE,
   DONE_ACK
} mbx_message_t;

localparam TUSER_WIDTH = 10;
localparam HDR_WIDTH = 256;
// The BFM minimum PCIe bus data width is HDR_WIDTH
localparam TDATA_WIDTH = (`OFS_FIM_IP_CFG_PCIE_SS_DWIDTH_BYTE * 8) > HDR_WIDTH ?
                            (`OFS_FIM_IP_CFG_PCIE_SS_DWIDTH_BYTE * 8) : HDR_WIDTH;
localparam TXREQ_DATA_WIDTH = HDR_WIDTH;

// Debug Functions
function automatic void dump_pfvf_params(
   bit pf_list[],
   int vf_list[]
);
   int size_pf, size_vf;
   size_pf = pf_list.size();
   size_vf = vf_list.size();
   $display(">>> PFVF PF List Size: %0d", size_pf);
   $display("         VF List Size: %0d", size_vf);
   $display("         PF Members:");
   foreach (pf_list[i])
   begin
      $display("                   : %B", pf_list[i]);
   end
   $display("         VF Members:");
   foreach (vf_list[i])
   begin
      $display("                   : %0d", vf_list[i]);
   end
   $display(">>> Done.");
   $display("");
endfunction

endpackage: host_bfm_types_pkg

`endif // __HOST_BFM_TYPES_PKG__

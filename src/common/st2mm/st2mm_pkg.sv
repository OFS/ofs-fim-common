// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// This package defines the global parameters of FIM
//
//----------------------------------------------------------------------------

`ifndef __ST2MM_PKG_SV__
`define __ST2MM_PKG_SV__

package st2mm_pkg;
   import pcie_ss_hdr_pkg::*;

localparam MMIO_DATA_WIDTH = 64;

// AXI write/read response status 
typedef enum logic [1:0] {
   RESP_OKAY   = 2'b00,
   RESP_EXOKAY = 2'b01,
   RESP_SLVERR = 2'b10,
   RESP_DECERR = 2'b11
} e_resp;

// Read response 
typedef struct packed {
   logic [PCIE_TAG_WIDTH-1:0]  rid;
   logic                       rvalid;
   e_resp                      rresp;
   logic [MMIO_DATA_WIDTH-1:0] rdata;
} t_axi_mmio_r;

typedef struct packed {
  logic [PCIE_TAG_WIDTH-1:0]   tag;
  logic [LOWER_ADDR_WIDTH-1:0] lower_addr;
  logic [15:0]                 requester_id;
  logic [1:0]                  length;
  logic [2:0]                  attr;
  logic [2:0]                  tc;
} t_cpl_hdr_info;
localparam CPL_HDR_INFO_WIDTH = $bits(t_cpl_hdr_info);

endpackage : st2mm_pkg

`endif // __ST2MM_PKG_SV__

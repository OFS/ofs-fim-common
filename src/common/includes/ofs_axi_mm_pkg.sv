// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//  Package describing AXI-4 Memory Mapped Interfaces widths used primarily in
//  the port gasket
//
//-----------------------------------------------------------------------------


`ifndef __OFS_AXI_MM_PKG_SV__
`define __OFS_AXI_MM_PKG_SV__

package ofs_axi_mm_pkg;

   typedef enum logic [1:0] {
      FIXED = 2'b00,
      INCR  = 2'b01,
      WRAP  = 2'b10
   } axi_burst_t;
   
   typedef enum logic [1:0] {
      OKAY   = 2'b00,
      EXOKAY = 2'b01,
      SLVERR = 2'b10,
      DECERR = 2'b11
   } axi_resp_t;

   localparam AXI_DATA_WIDTH      = 512;
   localparam AXI_ADDR_WIDTH      = 32;
   localparam AXI_ID_WIDTH        = 9;
   localparam AXI_USER_WIDTH      = 1;
   localparam AXI_BURST_LEN_WIDTH = 8;

endpackage : ofs_axi_mm_pkg
`endif //__OFS_AXI_MM_PKG_SV__
 

// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//  This file contains SystemVerilog package definitions for User Clock related 
//  parameters and types
//
//----------------------------------------------------------------------------

`ifndef __QPH_USER_CLK_PKG_SV__
`define __QPH_USER_CLK_PKG_SV__

package qph_user_clk_pkg;

   typedef struct packed {
      logic [1:0]  seq;    //  2-bit: Seq
      logic        write;  //  1-bit: Write
      logic [9:0]  addr;   // 10-bit: Address
      logic [31:0] data;   // 32-bit: Data
   } t_rcfg_ctrl;

endpackage : qph_user_clk_pkg

`endif // __QPH_USER_CLK_PKG_SV__

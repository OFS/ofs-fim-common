// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//   TOOL and VENDOR Specific configurations
//   ------------------------------------------------------------------------
//   The TOOL and VENDOR definition necessary to correctly configure project
//   package currently supports
//   Vendors : Intel
//   Tools   : Quartus II
//
//-----------------------------------------------------------------------------

`ifndef VENDOR_DEFINES_VH
   `define VENDOR_DEFINES_VH

   `ifndef VENDOR_INTEL
      `define VENDOR_INTEL
   `endif

    `ifndef TOOL_QUARTUS
      `define TOOL_QUARTUS
   `endif

   `ifdef VENDOR_INTEL
       `define GRAM_AUTO "no_rw_check"                         // defaults to auto
       `define GRAM_BLCK "no_rw_check, M20K"
       `define GRAM_DIST "no_rw_check, MLAB"
   `endif
   
   //-------------------------------------------   
   `ifdef TOOL_QUARTUS
       `define GRAM_STYLE   ramstyle
       `define NO_RETIMING  dont_retime
       `define NO_MERGE     dont_merge
       `define KEEP_WIRE    syn_keep = 1
   `endif
`endif

// Copyright (C) 2023 Intel Corporation.
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
// Description
//
// Macros for connecting IP memory channels to OFS Interfaces. Use for collapsing
// long port lists of an IP. Mem SS port list is large because each possible 
// memory port is wrapped in a preprocessor switch.
//
//-----------------------------------------------------------------------------

`include "ofs_ip_cfg_db.vh"

`define CONNECT_DDR4_MODEL_TB(IPORT, OPORT, IFC, GROUP) \
   // DDR4 Interface \
   .``OPORT``_ck           (``IFC``.ck), \
   .``OPORT``_ck_n         (``IFC``.ck_n), \
   .``OPORT``_a            (``IFC``.a), \
   .``OPORT``_act_n        (``IFC``.act_n), \
   .``OPORT``_ba           (``IFC``.ba), \
   .``OPORT``_bg           (``IFC``.bg), \
   .``OPORT``_cke          (``IFC``.cke), \
   .``OPORT``_cs_n         (``IFC``.cs_n), \
   .``OPORT``_odt          (``IFC``.odt), \
   .``OPORT``_reset_n      (``IFC``.reset_n), \
   .``OPORT``_par          (``IFC``.par), \
   .``OPORT``_alert_n      (``IFC``.alert_n), \
   .``OPORT``_dqs          (``IFC``.dqs), \
   .``OPORT``_dqs_n        (``IFC``.dqs_n), \
  `ifdef IFC_MEM_SS_MEM``GROUP``DDR4_IF_WIDTH_DBI_N \
   .``OPORT``_dbi_n        (``IFC``.dbi_n), \
  `endif                                    \
   .``OPORT``_dq           (``IFC``.dq)

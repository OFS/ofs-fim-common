// Copyright (C) 2023 Intel Corporation.
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
// Description
//
// Macros for connecting IP memory channels to OFS Interfaces. Use for collapsing
// long port lists of an IP.
//
//-----------------------------------------------------------------------------

`include "ofs_ip_cfg_db.vh"

// Mapping from top-level DDR4 pin interface to the testbench EMIF emulator.
`define CONNECT_DDR4_MODEL_TB(IPORT, OPORT, IFC, GROUP, MEM_REF_CLK_IF) \
 `ifdef CONFIG_AGILEX5 \
   // Agilex 5 memory model (no memory subsystem) \
   .``OPORT``_ck_t_0       (``MEM_REF_CLK_IF``.ck_t), \
   .``OPORT``_ck_c_0       (``MEM_REF_CLK_IF``.ck_c), \
   .``OPORT``_reset_n_0    (``MEM_REF_CLK_IF``.reset_n), \
   .``OPORT``_a_0          (``IFC``.a), \
   .``OPORT``_act_n_0      (``IFC``.act_n), \
   .``OPORT``_ba_0         (``IFC``.ba), \
   .``OPORT``_bg_0         (``IFC``.bg), \
   .``OPORT``_cke_0        (``IFC``.cke), \
   .``OPORT``_cs_n_0       (``IFC``.cs_n), \
   .``OPORT``_odt_0        (``IFC``.odt), \
   .``OPORT``_par_0        (``IFC``.par), \
   .``OPORT``_alert_n_0    (``IFC``.alert_n), \
   .``OPORT``_dqs_c_0      (``IFC``.dqs_c), \
   .``OPORT``_dqs_t_0      (``IFC``.dqs_t), \
   .``OPORT``_dbi_n_0      (``IFC``.dbi_n), \
   .``OPORT``_dq_0         (``IFC``.dq) \
 `else \
   // Memory subsystem (Agilex 7) \
   .``OPORT``_ck           (``IFC``.ck), \
   .``OPORT``_ck_n         (``IFC``.ck_n), \
   .``OPORT``_reset_n      (``IFC``.reset_n), \
   .``OPORT``_a            (``IFC``.a), \
   .``OPORT``_act_n        (``IFC``.act_n), \
   .``OPORT``_ba           (``IFC``.ba), \
   .``OPORT``_bg           (``IFC``.bg), \
   .``OPORT``_cke          (``IFC``.cke), \
   .``OPORT``_cs_n         (``IFC``.cs_n), \
   .``OPORT``_odt          (``IFC``.odt), \
   .``OPORT``_par          (``IFC``.par), \
   .``OPORT``_alert_n      (``IFC``.alert_n), \
   .``OPORT``_dqs          (``IFC``.dqs), \
   .``OPORT``_dqs_n        (``IFC``.dqs_n), \
  `ifdef IFC_MEM_SS_MEM``GROUP``DDR4_IF_WIDTH_DBI_N \
   .``OPORT``_dbi_n        (``IFC``.dbi_n), \
  `endif                                    \
   .``OPORT``_dq           (``IFC``.dq) \
 `endif

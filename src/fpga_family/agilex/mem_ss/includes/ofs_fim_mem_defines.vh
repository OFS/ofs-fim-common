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

// A Macro to connect an OFS AXI-MM interface to a PD interconnect port mapping
`define CONNECT_OFS_FIM_AXI_MM_PORT(IPORT, OPORT, IFC) \
// Write address channel \
.``OPORT``_awready (``IFC``.awready), \
   .``IPORT``_awvalid (``IFC``.awvalid), \
   .``IPORT``_awid    (``IFC``.awid), \
   .``IPORT``_awaddr  (``IFC``.awaddr), \
   .``IPORT``_awlen   (``IFC``.awlen), \
   .``IPORT``_awsize  (``IFC``.awsize), \
   .``IPORT``_awburst (``IFC``.awburst), \
   .``IPORT``_awlock  (``IFC``.awlock), \
   .``IPORT``_awcache (``IFC``.awcache), \
   .``IPORT``_awprot  (``IFC``.awprot), \
   .``IPORT``_awuser  (``IFC``.awuser), \
   // Write data channel \
   .``OPORT``_wready  (``IFC``.wready), \
   .``IPORT``_wvalid  (``IFC``.wvalid), \
   .``IPORT``_wdata   (``IFC``.wdata), \
   .``IPORT``_wstrb   (``IFC``.wstrb), \
   .``IPORT``_wlast   (``IFC``.wlast), \
   // Write response channel \
   .``IPORT``_bready  (``IFC``.bready), \
   .``OPORT``_bvalid  (``IFC``.bvalid), \
   .``OPORT``_bid     (``IFC``.bid), \
   .``OPORT``_bresp   (``IFC``.bresp), \
   .``OPORT``_buser   (``IFC``.buser), \
   // Read address channel \
   .``OPORT``_arready (``IFC``.arready), \
   .``IPORT``_arvalid (``IFC``.arvalid), \
   .``IPORT``_arid    (``IFC``.arid), \
   .``IPORT``_araddr  (``IFC``.araddr), \
   .``IPORT``_arlen   (``IFC``.arlen), \
   .``IPORT``_arsize  (``IFC``.arsize), \
   .``IPORT``_arburst (``IFC``.arburst), \
   .``IPORT``_arlock  (``IFC``.arlock), \
   .``IPORT``_arcache (``IFC``.arcache), \
   .``IPORT``_arprot  (``IFC``.arprot), \
   .``IPORT``_aruser  (``IFC``.aruser), \
   //Read response channel \
   .``IPORT``_rready  (``IFC``.rready), \
   .``OPORT``_rvalid  (``IFC``.rvalid), \
   .``OPORT``_rid     (``IFC``.rid), \
   .``OPORT``_rdata   (``IFC``.rdata), \
   .``OPORT``_rresp   (``IFC``.rresp), \
   .``OPORT``_rlast   (``IFC``.rlast)

`define CONNECT_OFS_FIM_DDR4_PORT(IPORT, OPORT, IFC) \
// DDR4 Interface \
.``IPORT``_pll_ref_clk  (``IFC``.ref_clk), \
   .``IPORT``_oct_rzqin    (``IFC``.oct_rzqin), \
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
   .``OPORT``_dq           (``IFC``.dq), \
   .``OPORT``_dbi_n        (``IFC``.dbi_n)

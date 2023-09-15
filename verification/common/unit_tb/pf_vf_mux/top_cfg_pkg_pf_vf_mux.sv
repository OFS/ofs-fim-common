// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// This package defines the parameters used in PF/VF Mux module
//
//-----------------------------------------------------------------------------
package top_cfg_pkg_pf_vf_mux;

   import ofs_fim_cfg_pkg::*;
   parameter NUM_HOST     = 1;
   parameter NUM_PORT     = `NUM_PORT; //Added for UNIT LEVEL VERIFICATION BY ASHISH
   parameter DATA_WIDTH   = 512;
   parameter NID_WIDTH    = $clog2(NUM_PORT);// ID field width for targeting mux ports
   parameter MID_WIDTH    = $clog2(NUM_HOST);// ID field width for targeting host ports

 endpackage : top_cfg_pkg_pf_vf_mux

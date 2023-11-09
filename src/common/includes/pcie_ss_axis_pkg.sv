// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//  This package defines the following interfaces/channels for PCIe SS 
//     1. PCIe SS AXI4-S channels
//     2. Sideband signals from PCIe SS Interface (PCIe configurations, FLR and etc.)
//
//----------------------------------------------------------------------------

package pcie_ss_axis_pkg;
   import pcie_ss_hdr_pkg::*;

localparam TDATA_WIDTH = pcie_ss_pkg::TDATA_WIDTH;
localparam TKEEP_WIDTH = TDATA_WIDTH/8;
localparam TUSER_WIDTH = pcie_ss_pkg::TUSER_WIDTH;

typedef struct packed {
  logic                    tvalid;
  logic [TDATA_WIDTH-1:0]  tdata; 
  logic [TKEEP_WIDTH-1:0]  tkeep; 
  logic [TUSER_WIDTH-1:0]  tuser; 
  logic                    tlast;
} t_axis_pcie;
localparam T_AXIS_PCIE_WIDTH = $bits(t_axis_pcie);

typedef struct packed {
   logic [4:0]          slot;
   logic                vf_active;
   logic [VF_WIDTH-1:0] vf;
   logic [PF_WIDTH-1:0] pf;
} t_flr_func;

typedef struct packed {
   logic        tvalid;
   t_flr_func   tdata;
} t_axis_pcie_flr;
localparam T_AXIS_PCIE_FLR_WIDTH = $bits(t_axis_pcie_flr);

typedef struct packed {
   logic [4:0]                  slot;
   logic                        vf_active;
   logic [VF_WIDTH-1:0]         vf;
   logic [PF_WIDTH-1:0]         pf;
   logic [PCIE_TAG_WIDTH-1:0]   tag;
} t_cplto_info;

typedef struct packed {
   logic          tvalid;
   t_cplto_info   tdata;
} t_axis_pcie_cplto; 
localparam T_AXIS_PCIE_CPLTO_WIDTH = $bits(t_axis_pcie_cplto);


//Ctrl Shadow Registers
typedef struct packed {
   logic        tag_enable_10bit; 
   logic        extended_tag;
   logic        vf_active;
   logic [10:0] vf_num;
   logic [2:0]  pf_num;
} t_pcie_ctrl_shdw_func;

typedef struct packed {
   logic                 tvalid;
   t_pcie_ctrl_shdw_func tdata;
} t_pcie_ctrl_shdw;
localparam T_PCIE_CTRL_SHDW_WIDTH = $bits(t_pcie_ctrl_shdw);

//Tag Mode
typedef struct packed {
   logic        tag_10bit; 
   logic        tag_8bit;
   logic        tag_5bit;
} t_pcie_tag_mode;
localparam T_PCIE_TAG_WIDTH = $bits(t_pcie_tag_mode);


endpackage: pcie_ss_axis_pkg

// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//   AXI-Mem traffic generator CSR package 
//
//-----------------------------------------------------------------------------

`ifndef __TG2_CSR_PKG_SV__
`define __TG2_CSR_PKG_SV__

package tg2_csr_pkg;

import ofs_csr_pkg::*;
// FUTURE_IMPROVEMENT_kroberso: some strange behavior can happen if M_CHANNEL is not = to the
// correct # of channels
`ifndef __MEM_SS_PKG_SV__
localparam M_CHANNEL = 4;
`else
import mem_ss_pkg::*;
localparam M_CHANNEL = mem_ss_pkg::MC_CHANNEL;
`endif
   
// AFU ID
// From https://www.uuidgenerator.net/version1:
// Note that this same number is used in PythonSV:
//   fpga_common/adp/arrowcreek/pysv_files/pysv_arrow.py
//   fpga_common/adp/arrowcreek/xml_files/mem_tg2.py
// Re-use from tg_csr_pkg to replace he_mem_tg
localparam MEM_TG2_ID_L = 64'hA3DC5B831F5CECBB;
localparam MEM_TG2_ID_H = 64'h4DADEA342C7848CB;

//-------------------
// CSR address
//-------------------
localparam CSR_ADDR_W      = 15;
localparam CSR_ADDR_SHIFT  = 3;

//-------------------
// DFH
//
localparam MEM_TG2_NUM_REGS = 16;

localparam AFU_DFH_CSR     = 16'h0000; //00
localparam AFU_ID_L_CSR    = 16'h0008; //01
localparam AFU_ID_H_CSR    = 16'h0010; //02
localparam AFU_NEXT        = 16'h0018; //03
localparam AFU_RSVD        = 16'h0020; //04
localparam SCRATCHPAD      = 16'h0028; //05
localparam MEM_TG_CTRL     = 16'h0030; //06
localparam MEM_TG_STAT     = 16'h0038; //07
localparam MEM_TG_CLOCKS   = 16'h0050; //10
// The TG2 registers are accessed starting at 16'h1000 for ch0, 16'h2000 for ch1, etc.
localparam TG2_CH_BASE     = 16'h1000;
localparam TG2_CH_NEXT     = 16'h1000;
localparam TG_START_ADDR   = 10'h001;

localparam AFU_DFH_CSR_IDX     = AFU_DFH_CSR>>CSR_ADDR_SHIFT;
localparam AFU_ID_L_CSR_IDX    = AFU_ID_L_CSR>>CSR_ADDR_SHIFT;
localparam AFU_ID_H_CSR_IDX    = AFU_ID_H_CSR>>CSR_ADDR_SHIFT;
localparam AFU_NEXT_IDX        = AFU_NEXT>>CSR_ADDR_SHIFT;
localparam AFU_RSVD_IDX        = AFU_RSVD>>CSR_ADDR_SHIFT;
localparam SCRATCHPAD_IDX      = SCRATCHPAD>>CSR_ADDR_SHIFT;
localparam MEM_TG_CTRL_IDX     = MEM_TG_CTRL>>CSR_ADDR_SHIFT;
localparam MEM_TG_STAT_IDX     = MEM_TG_STAT>>CSR_ADDR_SHIFT;
localparam MEM_TG_CLOCKS_IDX   = MEM_TG_CLOCKS>>CSR_ADDR_SHIFT;

// Register types
//---------------------------------------------------------
// CSR_AFU_DFH Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [3:0]  feature_type; //......[63:60]
   logic [7:0]  reserved1; //.........[59:52]
   logic [3:0]  afu_min_version; //...[51:48]
   logic [6:0]  reserved0; //.........[47:41]
   logic        end_of_list; //.......[40]
   logic [23:0] next_dfh_offset; //...[39:16]
   logic [3:0]  afu_maj_version; //...[15:12]
   logic [11:0] feature_id; //........[11:0]
} afu_csr_dfh_fields_t;

typedef union packed {
   afu_csr_dfh_fields_t afu_dfh;
   logic [63:0]         data;
   ofs_csr_reg_2x32_t   word;
} afu_csr_dfh_t;

//---------------------------------------------------------
// CSR_AFU_ID Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [63:0]  afu_id_l; //......[63:0]
} afu_csr_afu_id_l_fields_t;

typedef union packed {
   afu_csr_afu_id_l_fields_t csr_afu_id_l;
   logic [63:0]       data;
   ofs_csr_reg_2x32_t word;
} afu_csr_afu_id_l_t;

typedef struct packed {
   logic [63:0]  afu_id_h; //......[63:0]
} afu_csr_afu_id_h_fields_t;

typedef union packed {
   afu_csr_afu_id_h_fields_t  csr_afu_id_h;
   logic [63:0]               data;
   ofs_csr_reg_2x32_t         word;
} afu_csr_afu_id_h_t;

//---------------------------------------------------------
// Memory traffic gen control register
//---------------------------------------------------------
typedef struct packed {
   logic  tg_init_n;
} t_tg_ctrl;

typedef struct packed {
   t_tg_ctrl [M_CHANNEL-1:0] tg_ctrl;
} t_csr_tg_ctrl;
   
localparam CSR_TG_CTRL_WIDTH = $bits(t_csr_tg_ctrl);
typedef struct packed {
   logic [63:CSR_TG_CTRL_WIDTH] reserved1;
   t_csr_tg_ctrl tg_ctrl;
} csr_tg_ctrl_fields_t;

typedef union packed {
   csr_tg_ctrl_fields_t  csr_tg_ctrl;
   logic [63:0]          data;
   ofs_csr_reg_2x32_t    word;
} csr_tg_ctrl_t;

//---------------------------------------------------------
// Memory traffic gen status register
//---------------------------------------------------------
typedef struct packed {
   logic tg_pass;
   logic tg_fail;
   logic tg_timeout;
   logic tg_active;
} t_tg_stat;

typedef struct packed {
   t_tg_stat [M_CHANNEL-1:0] tg_stat;
} t_csr_tg_stat;

localparam CSR_TG_STAT_WIDTH = $bits(t_csr_tg_stat);
typedef struct packed {
   logic [63:CSR_TG_STAT_WIDTH] reserved1;
   t_csr_tg_stat tg_stat;
} csr_tg_stat_fields_t;

typedef union packed {
   csr_tg_stat_fields_t  csr_tg_stat;
   logic [63:0]          data;
   ofs_csr_reg_2x32_t    word;
} csr_tg_stat_t;

endpackage : tg2_csr_pkg
`endif //  `ifndef __TG2_CSR_PKG_SV__

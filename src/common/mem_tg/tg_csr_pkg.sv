// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//   AXI-Mem traffic generator CSR package 
//
//-----------------------------------------------------------------------------

`ifndef __TG_CSR_PKG_SV__
`define __TG_CSR_PKG_SV__

package tg_csr_pkg;

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
localparam MEM_TG_ID_L = 64'hA3DC5B831F5CECBB;
localparam MEM_TG_ID_H = 64'h4DADEA342C7848CB;
   
//-------------------
// CSR address
//-------------------
localparam CSR_ADDR_W      = 13;
localparam CSR_ADDR_SHIFT  = 3;

//-------------------
// DFH
//
localparam MEM_TG_NUM_REGS = 8;

localparam AFU_DFH_CSR     = 16'h0000;
localparam AFU_ID_L_CSR    = 16'h0008;
localparam AFU_ID_H_CSR    = 16'h0010;
localparam AFU_NEXT        = 16'h0018;
localparam AFU_RSVD        = 16'h0020;
localparam SCRATCHPAD      = 16'h0028;
localparam MEM_TG_CTRL     = 16'h0030;
localparam MEM_TG_STAT     = 16'h0038;
// FUTURE_IMPROVEMENT: TG atuo gen perf registers...

// CSR I/O traffic gen control/status type
typedef struct packed {
   logic  tg_init_n;
} t_tg_ctrl;

typedef struct packed {
   logic tg_pass;
   logic tg_fail;
   logic tg_timeout;
   logic tg_active;
} t_tg_stat;

// add tg perf def..
   
typedef struct packed {
   t_tg_ctrl [M_CHANNEL-1:0] tg_ctrl;
} t_csr_tg_ctrl;
   
typedef struct packed {
   t_tg_stat [M_CHANNEL-1:0] tg_stat;
} t_csr_tg_stat;

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

endpackage : tg_csr_pkg
`endif //  `ifndef __TG_CSR_PKG_SV__

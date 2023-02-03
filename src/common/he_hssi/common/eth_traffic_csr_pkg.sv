// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
// Description
//-----------------------------------------------------------------------------
//
// Ethernet traffic CSR Package.
//
// Definition of Ethernet traffic AFU CSR register block structures/overlays and
// supporting parameters/types.
//
//-----------------------------------------------------------------------------

`ifndef __ETH_TRAFFIC_CSR_PKG__
`define __ETH_TRAFFIC_CSR_PKG__

package eth_traffic_csr_pkg; 

import ofs_csr_pkg::*;

//---------------------------------------------------------
// CSR ADDRESS MAP 
//---------------------------------------------------------
// Ethernet traffic AFU Register Addresses
//---------------------------------------------------------
localparam CSR_AFU_DFH              = 16'h0000;
localparam CSR_AFU_ID_L             = 16'h0008;
localparam CSR_AFU_ID_H             = 16'h0010;
localparam CSR_AFU_INIT             = 16'h0028;
localparam CSR_TRAFFIC_CTRL_CMD     = 16'h0030;
localparam CSR_TRAFFIC_CTRL_DATA    = 16'h0038;
localparam CSR_TRAFFIC_CTRL_PORT    = 16'h0040;
localparam CSR_AFU_SCRATCH          = 16'h0048;
localparam CSR_PORT_SWAP_EN         = 16'h0050;

// DEPTH of CSR Mem
// Ceiling log2 of last address then subtract 3 for 64-bit address.
localparam ETH_AFU_CSR_REG_ADDR_WIDTH  = $clog2(CSR_AFU_SCRATCH)-3;

//---------------------------------------------------------
// Ethernet traffic AFU CSR Overlay Structures.
//    The following packed structures and unions create 
//    useful overlays for the inputs and outputs of the 
//    Ethernet traffic AFU CSR registers.
//---------------------------------------------------------

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
// CSR_AFU_ID_L Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [63:0]  afu_id_l; //......[63:0]
} afu_csr_afu_id_l_fields_t;

typedef union packed {
   afu_csr_afu_id_l_fields_t csr_afu_id_l;
   logic [63:0]       data;
   ofs_csr_reg_2x32_t word;
} afu_csr_afu_id_l_t;


//---------------------------------------------------------
// CSR_AFU_ID_H Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [63:0]  afu_id_h; //......[63:0]
} afu_csr_afu_id_h_fields_t;

typedef union packed {
   afu_csr_afu_id_h_fields_t  csr_afu_id_h;
   logic [63:0]               data;
   ofs_csr_reg_2x32_t         word;
} afu_csr_afu_id_h_t;


//---------------------------------------------------------
// CSR_AFU_INIT Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [61:0] reserved; //............[63:2]
   logic        init_done; //...........[1]
   logic        init_start; //..........[0]
} afu_csr_afu_init_fields_t;

typedef union packed {
   afu_csr_afu_init_fields_t  afu_init;
   logic [63:0]               data;
   ofs_csr_reg_2x32_t         word;
} afu_csr_afu_init_t;


//---------------------------------------------------------
// CSR_TRAFFIC_CTRL_CMD Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [15:0] reserved1; //............[63:48]
   logic [15:0] addr; //.................[47:32]
   logic [28:0] reserved0; //............[31:3]
   logic        ack_trans; //............[2]
   logic        wr_cmd; //...............[1]
   logic        rd_cmd; //...............[0]
} afu_csr_afu_traffic_ctrl_cmd_fields_t;

typedef union packed {
   afu_csr_afu_traffic_ctrl_cmd_fields_t afu_traffic_ctrl_cmd;
   logic [63:0]                          data;
   ofs_csr_reg_2x32_t                    word;
} afu_csr_afu_traffic_ctrl_cmd_t;


//---------------------------------------------------------
// CSR_TRAFFIC_CTRL_DATA Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [31:0] wr_data; //............[63:32]
   logic [31:0] rd_data; //............[31:0]
} afu_csr_afu_traffic_ctrl_data_fields_t;

typedef union packed {
   afu_csr_afu_traffic_ctrl_data_fields_t afu_traffic_ctrl_data;
   logic [63:0]                           data;
   ofs_csr_reg_2x32_t                     word;
} afu_csr_afu_traffic_ctrl_data_t;


//---------------------------------------------------------
// CSR_TRAFFIC_CTRL_PORT Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [59:0] reserved; //............[63:3]
   logic [3:0]  port_sel; //............[2:0]
} afu_csr_afu_traffic_ctrl_port_fields_t;

typedef union packed {
   afu_csr_afu_traffic_ctrl_port_fields_t afu_traffic_ctrl_port;
   logic [63:0]                           data;
   ofs_csr_reg_2x32_t                     word;
} afu_csr_afu_traffic_ctrl_port_t;


//---------------------------------------------------------
// CSR_PORT_SWAP_EN Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [62:0] reserved; //............[63:1]
   logic        swap_en; // ............[0]
} afu_csr_port_swap_en_fields_t;

typedef union packed {
   afu_csr_port_swap_en_fields_t          port_swap_en;
   logic [63:0]                           data;
   ofs_csr_reg_2x32_t                     word;
} afu_csr_port_swap_en_t;


endpackage: eth_traffic_csr_pkg

`endif // __ETH_TRAFFIC_CSR_PKG__

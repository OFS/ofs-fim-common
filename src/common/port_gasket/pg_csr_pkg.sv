// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// PR CSR Package:
// Definition of PR CSR register block structures/overlays and supporting 
// parameters/types.
//-----------------------------------------------------------------------------

`ifndef __PG_CSR_PKG__
`define __PG_CSR_PKG__

package pg_csr_pkg; 

import ofs_csr_pkg::*;

//----------------------------------------------------------------------------
// Here we define each registers address...
//----------------------------------------------------------------------------
localparam PG_CSR_FEATURE_NUM     = 8;
localparam PG_CSR_FEATURE_REG_NUM = 24;

localparam  PG_PR_DFH             = 20'h0_0000;
localparam  PG_PR_CTRL            = 20'h0_0008;
localparam  PG_PR_STATUS          = 20'h0_0010;
localparam  PG_PR_DATA            = 20'h0_0018;
localparam  PG_PR_ERROR           = 20'h0_0020;
localparam  PG_DUMMY_5028         = 20'h0_0028;
localparam  PG_DUMMY_5030         = 20'h0_0030;
localparam  PG_DUMMY_5038         = 20'h0_0038;
localparam  PG_DUMMY_5040         = 20'h0_0040;
localparam  PG_DUMMY_5048         = 20'h0_0048;
localparam  PG_DUMMY_5050         = 20'h0_0050;
localparam  PG_DUMMY_5058         = 20'h0_0058;
localparam  PG_DUMMY_5060         = 20'h0_0060;
localparam  PG_DUMMY_5068         = 20'h0_0068;
localparam  PG_DUMMY_5070         = 20'h0_0070;
localparam  PG_DUMMY_5078         = 20'h0_0078;
localparam  PG_DUMMY_5080         = 20'h0_0080;
localparam  PG_DUMMY_5088         = 20'h0_0088;
localparam  PG_DUMMY_5090         = 20'h0_0090;
localparam  PG_DUMMY_5098         = 20'h0_0098;
localparam  PG_DUMMY_50A0         = 20'h0_00A0;
localparam  PG_PR_INTFC_ID_L      = 20'h0_00A8;
localparam  PG_PR_INTFC_ID_H      = 20'h0_00B0;
localparam  PG_SCRATCHPAD         = 20'h0_00B8;

localparam  PORT_DFH              = 20'h0_1000;
localparam  PORT_AFU_ID_L         = 20'h0_1008;
localparam  PORT_AFU_ID_H         = 20'h0_1010;
localparam  FIRST_AFU_OFFSET      = 20'h0_1018;
localparam  PORT_MAILBOX          = 20'h0_1020;
localparam  PORT_SCRATCHPAD0      = 20'h0_1028;
localparam  PORT_CAPABILITY       = 20'h0_1030;
localparam  PORT_CONTROL          = 20'h0_1038;
localparam  PORT_STATUS           = 20'h0_1040;

localparam  PG_USER_CLK_DFH       = 20'h0_2000;
localparam  PG_USER_CLK_FREQ_CMD0 = 20'h0_2008;
localparam  PG_USER_CLK_FREQ_CMD1 = 20'h0_2010;
localparam  PG_USER_CLK_FREQ_STS0 = 20'h0_2018;
localparam  PG_USER_CLK_FREQ_STS1 = 20'h0_2020;

localparam  PORT_STP_DFH          = 20'h0_3000;
localparam  PORT_STP_STATUS       = 20'h0_3008;

//---------------------------------------------------------------------------------
// Define the register bit attributes for each of the CSRs
//---------------------------------------------------------------------------------
//csr_bit_attr_t [63:0] PG_DFH_ATTR               = {64{RO}};
//csr_bit_attr_t [63:0] PG_PR_DFH_ATTR            = {64{RO}};
//csr_bit_attr_t [63:0] PG_PR_CTRL_ATTR           = {64{RW}};
//csr_bit_attr_t [63:0] PG_PR_STATUS_ATTR         = {64{RO}};
//csr_bit_attr_t [63:0] PG_PR_DATA_ATTR           = {64{RW}};
//csr_bit_attr_t [63:0] PG_PR_ERROR_ATTR          = {64{RW1C}};
//csr_bit_attr_t [63:0] PG_DUMMY_5028_ATTR           = {64{RO}};
//csr_bit_attr_t [63:0] PG_DUMMY_5030_ATTR           = {64{RO}};
//csr_bit_attr_t [63:0] PG_DUMMY_5038_ATTR           = {64{RO}};
//csr_bit_attr_t [63:0] PG_DUMMY_5040_ATTR           = {64{RO}};
//csr_bit_attr_t [63:0] PG_DUMMY_5048_ATTR           = {64{RO}};
//csr_bit_attr_t [63:0] PG_DUMMY_5050_ATTR           = {64{RO}};
//csr_bit_attr_t [63:0] PG_DUMMY_5058_ATTR           = {64{RO}};
//csr_bit_attr_t [63:0] PG_DUMMY_5060_ATTR           = {64{RO}};
//csr_bit_attr_t [63:0] PG_DUMMY_5068_ATTR           = {64{RO}};
//csr_bit_attr_t [63:0] PG_DUMMY_5070_ATTR           = {64{RO}};
//csr_bit_attr_t [63:0] PG_DUMMY_5078_ATTR           = {64{RO}};
//csr_bit_attr_t [63:0] PG_DUMMY_5080_ATTR           = {64{RO}};
//csr_bit_attr_t [63:0] PG_DUMMY_5088_ATTR           = {64{RO}};
//csr_bit_attr_t [63:0] PG_DUMMY_5090_ATTR           = {64{RO}};
//csr_bit_attr_t [63:0] PG_DUMMY_5098_ATTR           = {64{RO}};
//csr_bit_attr_t [63:0] PG_DUMMY_50A0_ATTR           = {64{RO}};
//csr_bit_attr_t [63:0] PG_PR_INTFC_ID_L_ATTR     = {64{RO}};
//csr_bit_attr_t [63:0] PG_PR_INTFC_ID_H_ATTR     = {64{RO}};
csr_bit_attr_t [63:0] PG_SCRATCHPAD_ATTR        = {64{RW}};
csr_bit_attr_t [63:0] PG_USER_CLK_DFH_ATTR          = {64{RO}};
csr_bit_attr_t [63:0] PG_USER_CLK_FREQ_CMD0_ATTR    = {64{RW}};
csr_bit_attr_t [63:0] PG_USER_CLK_FREQ_CMD1_ATTR    = {64{RW}};
csr_bit_attr_t [63:0] PG_USER_CLK_FREQ_STS0_ATTR    = {64{RO}};
csr_bit_attr_t [63:0] PG_USER_CLK_FREQ_STS1_ATTR    = {64{RO}};

//---------------------------------------------------------------------------------
//  PG PR IDs
//---------------------------------------------------------------------------------
// FUTURE_IMPROVEMENT: Add ID assignments, current
localparam PG_ID_NUM_REGS = 2;
localparam PG_ID_IDX_WIDTH = $clog2(PG_ID_NUM_REGS);
typedef enum bit [PG_ID_IDX_WIDTH-1:0]  {
   PG_PR_IF_ID_L_IDX,
   PG_PR_IF_ID_H_IDX
} pg_id_idx_t;

logic [63:0] pg_id_regs[PG_ID_NUM_REGS-1:0];

//---------------------------------------------------------------------------------
// PR CSR Overlay Structures.
//    The following packed structures and unions create 
//    useful overlays for the inputs and outputs of the 
//    PR CSR registers.
//---------------------------------------------------------------------------------

//---------------------------------------------------------
// Port_DFH Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [3:0]  feature_type; //......[63:60]
   logic [18:0] reserved; //..........[59:41]
   logic        end_of_list; //.......[40]
   logic [23:0] next_dfh_offset; //...[39:16]
   logic [3:0]  afu_maj_version; //...[15:12]
   logic [11:0] corefim_version; //...[11:0]
} port_csr_port_dfh_fields_t;

typedef union packed {
   port_csr_port_dfh_fields_t port_dfh;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} port_csr_port_dfh_t;

typedef struct packed {
   csr_bit_attr_t [3:0]  feature_type; //......[63:60]
   csr_bit_attr_t [18:0] reserved; //..........[59:41]
   csr_bit_attr_t        end_of_list; //.......[40]
   csr_bit_attr_t [23:0] next_dfh_offset; //...[39:16]
   csr_bit_attr_t [3:0]  afu_maj_version; //...[15:12]
   csr_bit_attr_t [11:0] corefim_version; //...[11:0]
} port_csr_port_dfh_fields_attr_t;

typedef union packed {
   port_csr_port_dfh_fields_attr_t port_dfh;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} port_csr_port_dfh_attr_t;


//---------------------------------------------------------
// Port_AFU_ID_L Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [63:0]  afu_id_l; //......[63:0]
} port_csr_port_afu_id_l_fields_t;

typedef union packed {
   port_csr_port_afu_id_l_fields_t port_afu_id_l;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} port_csr_port_afu_id_l_t;

typedef struct packed {
   csr_bit_attr_t [63:0]  afu_id_l; //......[63:0]
} port_csr_port_afu_id_l_fields_attr_t;

typedef union packed {
   port_csr_port_afu_id_l_fields_attr_t port_afu_id_l;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} port_csr_port_afu_id_l_attr_t;


//---------------------------------------------------------
// Port_AFU_ID_H Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [63:0]  afu_id_h; //......[63:0]
} port_csr_port_afu_id_h_fields_t;

typedef union packed {
   port_csr_port_afu_id_h_fields_t port_afu_id_h;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} port_csr_port_afu_id_h_t;

typedef struct packed {
   csr_bit_attr_t [63:0]  afu_id_h; //......[63:0]
} port_csr_port_afu_id_h_fields_attr_t;

typedef union packed {
   port_csr_port_afu_id_h_fields_attr_t port_afu_id_h;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} port_csr_port_afu_id_h_attr_t;


//---------------------------------------------------------
// Port_FIRST_AFU_OFFSET Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [39:0] reserved; //............[63:24]
   logic [23:0] first_afu_offset; //....[23:0]
} port_csr_first_afu_offset_fields_t;

typedef union packed {
   port_csr_first_afu_offset_fields_t first_afu_offset;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} port_csr_first_afu_offset_t;

typedef struct packed {
   csr_bit_attr_t [39:0] reserved; //............[63:24]
   csr_bit_attr_t [23:0] first_afu_offset; //....[23:0]
} port_csr_first_afu_offset_fields_attr_t;

typedef union packed {
   port_csr_first_afu_offset_fields_attr_t first_afu_offset;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} port_csr_first_afu_offset_attr_t;


//---------------------------------------------------------
// Port_CAPABILITY Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [27:0] reserved36; //......[63:36]
   logic [3:0]  num_supp_int; //....[35:32]
   logic [7:0]  reserved24; //......[31:24]
   logic [15:0] mmio_size; //.......[23:8]
   logic [7:0]  reserved0; //.......[7:0]
} port_csr_port_capability_fields_t;

typedef union packed {
   port_csr_port_capability_fields_t port_capability;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} port_csr_port_capability_t;

typedef struct packed {
   csr_bit_attr_t [27:0] reserved36; //......[63:36]
   csr_bit_attr_t [3:0]  num_supp_int; //....[35:32]
   csr_bit_attr_t [7:0]  reserved24; //......[31:24]
   csr_bit_attr_t [15:0] mmio_size; //.......[23:8]
   csr_bit_attr_t [7:0]  reserved0; //.......[7:0]
} port_csr_port_capability_fields_attr_t;

typedef union packed {
   port_csr_port_capability_fields_attr_t port_capability;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} port_csr_port_capability_attr_t;


//---------------------------------------------------------
// Port_CONTROL Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [58:0] reserved5; //.............[63:5]
   logic        port_soft_reset_ack; //...[4]
   logic        flr_port_reset; //........[3]
   logic        latency_tolerance; //.....[2]
   logic        reserved1; //.............[1]
   logic        port_soft_reset; //.......[0]
} port_csr_port_control_fields_t;

typedef union packed {
   port_csr_port_control_fields_t port_control;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} port_csr_port_control_t;

typedef struct packed {
   csr_bit_attr_t [58:0] reserved5; //.............[63:5]
   csr_bit_attr_t        port_soft_reset_ack; //...[4]
   csr_bit_attr_t        flr_port_reset; //........[3]
   csr_bit_attr_t        latency_tolerance; //.....[2]
   csr_bit_attr_t        reserved1; //.............[1]
   csr_bit_attr_t        port_soft_reset; //.......[0]
} port_csr_port_control_fields_attr_t;

typedef union packed {
   port_csr_port_control_fields_attr_t port_control;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} port_csr_port_control_attr_t;


//---------------------------------------------------------
// Port_STATUS Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [62:0] reserved1; //.....[63:1]
   logic        port_freeze; //...[   0]
} port_csr_port_status_fields_t;

typedef union packed {
   port_csr_port_status_fields_t port_status;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} port_csr_port_status_t;

typedef struct packed {
   csr_bit_attr_t [62:0] reserved1; //.....[63:1]
   csr_bit_attr_t        port_freeze; //...[   0]
} port_csr_port_status_fields_attr_t;

typedef union packed {
   port_csr_port_status_fields_attr_t port_status;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} port_csr_port_status_attr_t;

//---------------------------------------------------------------------------------
// PR_DFH Register Overlay.
//---------------------------------------------------------------------------------
typedef struct packed {
// [63:60]: Feature Type
// [59:52]: Reserved
// [51:48]: If AFU - AFU Minor Revision Number (else, reserved)
// [47:41]: Reserved
// [   40]: EOL (End of DFH list)
// [39:16]: Next DFH Byte Offset
// [15:12]: If AfU, AFU Major version number (else feature #)
// [11: 0]: Feature ID
   logic [3:0]  feature_type;              //......[63:60]
   logic [7:0]  reserved59;                //......[59:52]
   logic [3:0]  afu_minor_rev_num;         //......[51:48]
   logic [6:0]  reserved47;                //......[47:41]
   logic        end_of_list;               //......[40]
   logic [23:0] next_dfh_offset;           //......[39:16]
   logic [3:0]  feature_rev;               //......[15:12]
   logic [11:0] feature_id;                //......[11:0]
} pg_csr_pr_dfh_fields_t;

typedef union packed {
   pg_csr_pr_dfh_fields_t     pr_dfh;
   logic [63:0]                 data;
} pg_csr_pr_dfh_t;


//---------------------------------------------------------------------------------
// PR_CTRL Register Overlay.
//---------------------------------------------------------------------------------
typedef struct packed {
// [63:32]: TBD/Config Data
// [31:15]: Reserved
// [   14]: PRKind. 0: Load customer GBS, 1: Load Intel GBS
// [   13]: PRDataPushComplete
// [   12]: PRStartRequest 
// [11:10]: Reserved
// [ 9: 8]: PRRegionId
// [ 7: 5]: Reserved
// [    4]: PRResetAck
// [ 3: 1]: Reserved
// [    0]: PRReset
   logic [31:0] config_data;               //......[63:32]
   logic [16:0] reserved15;                //......[31:15]
   logic        pr_kind;                   //......[14]
   logic        pr_data_push_complete;     //......[13]
   logic        pr_start_request;          //......[12]
   logic [1:0]  reserved10;                //......[11:10]
   logic [1:0]  pr_region_id;              //......[ 9:8]
   logic [2:0]  reserved5;                 //......[ 7:5]
   logic        pr_reset_ack;              //......[ 4]
   logic [2:0]  reserved1;                 //......[ 3:1]
   logic        pr_reset;                  //......[ 0]
} pg_csr_pr_ctrl_fields_t;

typedef union packed {
   pg_csr_pr_ctrl_fields_t      pr_ctrl;
   logic [63:0]                 data;
} pg_csr_pr_ctrl_t;

//---------------------------------------------------------------------------------
// PR_STATUS Register Overlay.
//---------------------------------------------------------------------------------
typedef struct packed {
// [63:32]: SecurityBlockStatus (TBD)
// [31:28]: Reserved
// [27:24]: PRHostStatus
// [   23]: Reserved
// [22:20]: AlteraPRCrtlrStatus
// [   17]: Reserved
// [   16]: PRStatus
// [15: 9]: Reserved
// [ 8: 0]: NumbCredits
   logic [31:0] security_block_status;     //......[63:32]
   logic [3:0]  reserved28;                //......[31:28]
   logic [3:0]  pr_host_status;            //......[27:24]
   logic        reserved23;                //......[23]
   logic [2:0]  altera_pr_ctrl_status;     //......[22:20]
   logic [2:0]  reserved17;                //......[19:17]
   logic        pr_status;                 //......[16]
   logic [6:0]  reserved9;                 //......[15:9]
   logic [8:0]  numb_credits;              //......[ 8:0]
} pg_csr_pr_status_fields_t;

typedef union packed {
   pg_csr_pr_status_fields_t    pr_status;
   logic [63:0]                 data;
} pg_csr_pr_status_t;

//---------------------------------------------------------------------------------
// PR_ERROR Register Overlay.
//---------------------------------------------------------------------------------
typedef struct packed {
// [63: 7]: Reserved
// [    6]: Secure Load Failed
// [    5]: Host Init TImeout
// [    4]: Host Init Fifo Overflow
// [    3]: IP Init Protocol Error
// [    2]: IP Init Incompatible Bitstream
// [    1]: IP Init CRC Error
// [    0]: Host Init Operation Error 
   logic [56:0] reserved7;                     //......[63:7]
   logic        secure_load_failed;            //......[ 6]
   logic        host_init_timeout;             //......[ 5]
   logic        host_init_fifo_overflow;       //......[ 4]
   logic        ip_init_protocol_error;        //......[ 3]
   logic        ip_init_incompatible_bitstream;//......[ 2]
   logic        ip_init_crc_error;             //......[ 1]
   logic        host_init_operation_error;     //......[ 0]
} pg_csr_pr_error_fields_t;

typedef union packed {
   pg_csr_pr_error_fields_t     pr_error;
   logic [63:0]                 data;
} pg_csr_pr_error_t;

//---------------------------------------------------------------------------------
// USER_CLK_DFH Register Overlay.
//---------------------------------------------------------------------------------
typedef struct packed {
// [63:60]: Feature Type = Private
// [59:41]: Reserved41
// [   40]: EOL - End of DFH List
// [39:16]: Next DFH Byte Offset
// [15:12]: CCI-P Minor Revision
// [11: 0]: CCI-P Version #
   logic [3:0]     FeatureType;                //......[63:60]
   logic [18:0]    Reserved41;                 //......[59:41]
   logic           EOL;                        //......[40]
   logic [23:0]    NextDfhOffset;              //......[39:16]
   logic [3:0]     CciMinorRev;                //......[15:12]
   logic [11:0]    CciVersion;                 //......[11:0]
} pg_csr_user_clk_dfh_fields_t;

typedef union packed {
   pg_csr_user_clk_dfh_fields_t    user_clk_dfh;
   logic [63:0]                    data;
} pg_csr_user_clk_dfh_t;

//---------------------------------------------------------------------------------
// USER_CLK_FREQ_CMD0 Register Overlay.
//---------------------------------------------------------------------------------
typedef struct packed {
// [63:58]: Reserved
// [   57]: IOPLL Reset
// [   56]: IOPLL Management Reset
// [55:53]: Reserved
// [   52]: AVMM Bridge State Machine Reset Machine (active low)
// [51:50]: Reserved
// [49:48]: IOPLL Reconfig Command Sequence Number
// [47:45]: Reserved
// [   44]: IOPLL Reconfig Command Write
// [43:42]: Reserved
// [41:32]: IOPLL Reconfig Command Address
// [31: 0]: IOPLL Reconfig Command Data
   logic [5:0]     Reserved4;                  //......[63:58]
   logic           UsrClkCmdPllRst;            //......[57]
   logic           UsrClkCmdPllMgmtRst;        //......[56]
   logic [2:0]     Reserved3;                  //......[55:53]
   logic           UsrClkCmdMmRst;             //......[52]
   logic [1:0]     Reserved2;                  //......[51:50]
   logic [1:0]     UsrClkCmdSeq;               //......[49:48]
   logic [2:0]     Reserved1;                  //......[47:45]
   logic           UsrClkCmdWr;                //......[44]
   logic [1:0]     Reserved0;                  //......[43:42]
   logic [9:0]     UsrClkCmdAdr;               //......[41:32]
   logic [31:0]    UsrClkCmdDat;               //......[31:0]
} pg_csr_user_clk_freq_cmd0_fields_t;

typedef union packed {
   pg_csr_user_clk_freq_cmd0_fields_t      user_clk_freq_cmd0;
   logic [63:0]                            data;
} pg_csr_user_clk_freq_cmd0_t;

//---------------------------------------------------------------------------------
// USER_CLK_FREQ_CMD1 Register Overlay.
//---------------------------------------------------------------------------------
typedef struct packed {
// [63:33]:    Reserved
// [   32]:    Clock to measure (0 - uClk_usr_Div2, 1 - uClk_usr)
// [31: 0]:    Reserved
   logic [30:0]     Reserved1;                  //......[63:33]
   logic            FreqCntrClkSel;             //......[32]
   logic [31:0]     Reserved0;                  //......[31:0]
} pg_csr_user_clk_freq_cmd1_fields_t;

typedef union packed {
   pg_csr_user_clk_freq_cmd1_fields_t      user_clk_freq_cmd1;
   logic [63:0]                            data;
} pg_csr_user_clk_freq_cmd1_t;

//---------------------------------------------------------------------------------
// USER_CLK_FREQ_STS0 Register Overlay.
//---------------------------------------------------------------------------------
typedef struct packed {
// [   63]:    Avalon-mm bridge state machine error
// [62:61]:    Reserved
// [   60]:    IOPLL Locked
// [59:58]:    Reserved
// [   57]:    IOPLL reset
// [   56]:    IOPLL Management reset
// [55:53]:    Reserved
// [   52]:    Avalon-mm bridge state machine reset
// [51:50]:    Reserved
// [49:48]:    IOPLL reconfig command sequence number
// [47:45]:    Reserved
// [   44]:    IOPLL reconfig command write
// [43:42]:    Reserved
// [41:32]:    IOPLL reconfig command address
// [31: 0]:    IOPLL reconfig command read back data
   logic           UsrClkStMmError;            //......[63]
   logic [1:0]     UsrClkStPllActClk;          //......[62:61]
   logic           UsrClkStPllLocked;          //......[60]
   logic [1:0]     Reserved4;                  //......[59:58]
   logic           UsrClkStPllRst;             //......[57]
   logic           UsrClkStPllMgmtRst;         //......[56]
   logic [2:0]     Reserved3;                  //......[55:53]
   logic           UsrClkStMmRst;              //......[52]
   logic [1:0]     Reserved2;                  //......[51:50]
   logic [1:0]     UsrClkStSeq;                //......[49:48]
   logic [2:0]     Reserved1;                  //......[47:45]
   logic           UsrClkStWr;                 //......[44]
   logic [1:0]     Reserved0;                  //......[43:42]
   logic [9:0]     UsrClkStAdr;                //......[41:32]
   logic [31:0]    UsrClkStDat;                //......[31:0]
} pg_csr_user_clk_freq_sts0_fields_t;

typedef union packed {
   pg_csr_user_clk_freq_sts0_fields_t      user_clk_freq_sts0;
   logic [63:0]                            data;
} pg_csr_user_clk_freq_sts0_t;

//---------------------------------------------------------------------------------
// USER_CLK_FREQ_STS1 Register Overlay.
//---------------------------------------------------------------------------------
typedef struct packed {
// [63:60]:    Frequency counter version number
// [59:51]:    Reserved
// [50:33]:    PLL Reference Clock Frequency in 10kHz units.  For example, 100MHz = 10000 x 10 kHz >>> 10000 = 0x2710
// [   32]:    Clock that was measured (0 - uClk_usr_Div2, 1 - uClk_Usr)
// [31:17]:    Reserved
// [16: 0]:    Frequency in 10kHz units
   logic [3:0]     FreqCntrVersion;            //......[63:60]
   logic [8:0]     Reserved51;                 //......[59:51]
   logic [17:0]    FreqPLLRef;                 //......[50:33]
   logic           FreqCntrClkMeasured;        //......[32]
   logic [14:0]    Reserved41;                 //......[31:17]
   logic [16:0]    FreqCntrMeasuredFreq;       //......[16:0]
} pg_csr_user_clk_freq_sts1_fields_t;

typedef union packed {
   pg_csr_user_clk_freq_sts1_fields_t      user_clk_freq_sts1;
   logic [63:0]                            data;
} pg_csr_user_clk_freq_sts1_t;

//---------------------------------------------------------
// Standard Feature DFH Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [3:0]  feature_type; //.......[63:60]
   logic [18:0] reserved; //...........[59:41]
   logic        end_of_list; //........[40]
   logic [23:0] next_dfh_offset; //....[39:16]
   logic [3:0]  feature_rev; //........[15:12]
   logic [11:0] feature_id; //.........[11:0] 
} port_csr_dfh_fields_t;

typedef union packed {
   port_csr_dfh_fields_t dfh;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} port_csr_dfh_t;

typedef struct packed {
   csr_bit_attr_t [3:0]  feature_type; //.......[63:60]
   csr_bit_attr_t [18:0] reserved; //...........[59:41]
   csr_bit_attr_t        end_of_list; //........[40]
   csr_bit_attr_t [23:0] next_dfh_offset; //....[39:16]
   csr_bit_attr_t [3:0]  feature_rev; //........[15:12]
   csr_bit_attr_t [11:0] feature_id; //.........[11:0] 
} port_csr_dfh_fields_attr_t;

typedef union packed {
   port_csr_dfh_fields_attr_t dfh;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} port_csr_dfh_attr_t;

//---------------------------------------------------------
// Port_STP_STATUS Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [15:0] num_mmio_resp; //......[63:48]
   logic [15:0] num_mmio_req; //.......[47:32]
   logic [15:0] num_mmio_wr; //........[31:16]
   logic        rx_fifo_underflow; //..[15]
   logic        rx_fifo_overflow; //...[14]
   logic        tx_fifo_underflow; //..[13]
   logic        tx_fifo_overflow; //...[12]
   logic [3:0]  rx_fifo_count; //......[11:8]
   logic [3:0]  tx_fifo_count; //......[7:4]
   logic        mmio_time_out; //......[3]
   logic        unsupported_rd; //.....[2]
   logic        stp_in_reset; //.......[1]
   logic        rw_time_out; //........[0]
} port_csr_port_stp_status_fields_t;

typedef union packed {
   port_csr_port_stp_status_fields_t port_stp_status;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} port_csr_port_stp_status_t;

typedef struct packed {
   csr_bit_attr_t [15:0] num_mmio_resp; //......[63:48]
   csr_bit_attr_t [15:0] num_mmio_req; //.......[47:32]
   csr_bit_attr_t [15:0] num_mmio_wr; //........[31:16]
   csr_bit_attr_t        rx_fifo_underflow; //..[15]
   csr_bit_attr_t        rx_fifo_overflow; //...[14]
   csr_bit_attr_t        tx_fifo_underflow; //..[13]
   csr_bit_attr_t        tx_fifo_overflow; //...[12]
   csr_bit_attr_t [3:0]  rx_fifo_count; //......[11:8]
   csr_bit_attr_t [3:0]  tx_fifo_count; //......[7:4]
   csr_bit_attr_t        mmio_time_out; //......[3]
   csr_bit_attr_t        unsupported_rd; //.....[2]
   csr_bit_attr_t        stp_in_reset; //.......[1]
   csr_bit_attr_t        rw_time_out; //........[0]
} port_csr_port_stp_status_fields_attr_t;

typedef union packed {
   port_csr_port_stp_status_fields_attr_t port_stp_status;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} port_csr_port_stp_status_attr_t;

endpackage: pg_csr_pkg

`endif // __PG_CSR_PKG__

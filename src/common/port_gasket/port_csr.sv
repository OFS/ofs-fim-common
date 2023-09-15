// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// Port Control CSR
//-----------------------------------------------------------------------------

`include "fpga_defines.vh"

import ofs_csr_pkg::*;
import fme_csr_pkg::*;

module port_csr #(
   parameter END_OF_LIST     = 1'b0,
   parameter NEXT_DFH_OFFSET = 24'h01_0000,
   parameter ADDR_WIDTH      = 20, 
   parameter DATA_WIDTH      = 64,
   parameter AGILEX          = 0
)(
   input                                       clk,
   input                                       rst_n,

   ofs_fim_axi_lite_if.slave                   axi_s_if,

   // PR Freeze Monitor
   input  logic                                i_pr_freeze,

   // PORT CTRL Interface
   input  logic     [63:0]                     i_port_ctrl,
   output logic     [63:0]                     o_port_ctrl

`ifdef INCLUDE_USER_CLK
   ,
   // User clock interface
   output logic     [63:0]                     user_clk_freq_cmd_0,
   output logic     [63:0]                     user_clk_freq_cmd_1,
   input  logic     [63:0]                     user_clk_freq_sts_0,
   input  logic     [63:0]                     user_clk_freq_sts_1
`endif
`ifdef INCLUDE_REMOTE_STP
   ,
   // Remote STP
   input  logic     [63:0]                     i_remotestp_status,
   ofs_fim_axi_lite_if.master                  m_remotestp_if  
`endif
);

`ifndef INCLUDE_USER_CLK
logic     [63:0]                     user_clk_freq_cmd_0;
logic     [63:0]                     user_clk_freq_cmd_1;
logic     [63:0]                     user_clk_freq_sts_0;
logic     [63:0]                     user_clk_freq_sts_1;
`endif
`ifndef INCLUDE_REMOTE_STP
logic     [63:0]                     i_remotestp_status;
ofs_fim_axi_lite_if                  m_remotestp_if();  
`endif
//----------------------------------------------------------------------------
// PORT Register Definitions
//----------------------------------------------------------------------------
localparam CSR_FEATURE_NUM     = 4;
localparam CSR_FEATURE_REG_NUM = 9;

localparam  PORT_DFH              = 20'h0_0000;
localparam  PORT_AFU_ID_L         = 20'h0_0008;
localparam  PORT_AFU_ID_H         = 20'h0_0010;
localparam  FIRST_AFU_OFFSET      = 20'h0_0018;
localparam  PORT_MAILBOX          = 20'h0_0020;
localparam  PORT_SCRATCHPAD0      = 20'h0_0028;
localparam  PORT_CAPABILITY       = 20'h0_0030;
localparam  PORT_CONTROL          = 20'h0_0038;
localparam  PORT_STATUS           = 20'h0_0040;

localparam  USER_CLK_DFH          = 20'h0_2000;
localparam  USER_CLK_FREQ_CMD0    = 20'h0_2008;
localparam  USER_CLK_FREQ_CMD1    = 20'h0_2010;
localparam  USER_CLK_FREQ_STS0    = 20'h0_2018;
localparam  USER_CLK_FREQ_STS1    = 20'h0_2020;

localparam  REMOTE_STP_DFH        = 20'h0_3000;
localparam  REMOTE_STP_STATUS     = 20'h0_3008;

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
} port_csr_user_clk_dfh_fields_t;

typedef union packed {
   port_csr_user_clk_dfh_fields_t  user_clk_dfh;
   logic [63:0]                    data;
} port_csr_user_clk_dfh_t;

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
} port_csr_user_clk_freq_cmd0_fields_t;

typedef union packed {
   port_csr_user_clk_freq_cmd0_fields_t    user_clk_freq_cmd0;
   logic [63:0]                            data;
} port_csr_user_clk_freq_cmd0_t;

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
} port_csr_user_clk_freq_cmd1_fields_t;

typedef union packed {
   port_csr_user_clk_freq_cmd1_fields_t    user_clk_freq_cmd1;
   logic [63:0]                            data;
} port_csr_user_clk_freq_cmd1_t;

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
} port_csr_user_clk_freq_sts0_fields_t;

typedef union packed {
   port_csr_user_clk_freq_sts0_fields_t    user_clk_freq_sts0;
   logic [63:0]                            data;
} port_csr_user_clk_freq_sts0_t;

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
} port_csr_user_clk_freq_sts1_fields_t;

typedef union packed {
   port_csr_user_clk_freq_sts1_fields_t    user_clk_freq_sts1;
   logic [63:0]                            data;
} port_csr_user_clk_freq_sts1_t;

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
} port_csr_remote_stp_status_fields_t;

typedef union packed {
   port_csr_remote_stp_status_fields_t remote_stp_status;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} port_csr_remote_stp_status_t;

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
} port_csr_remote_stp_status_fields_attr_t;

typedef union packed {
   port_csr_remote_stp_status_fields_attr_t remote_stp_status;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} port_csr_remote_stp_status_attr_t;

//----------------------------------------------------------------------------
// SIGNAL DEFINITIONS
//----------------------------------------------------------------------------
//----------------------------------------------------------------------------
// CSR registers are implemented in a two dimensional array according to the
// features and the number of registers per feature.  This allows the most
// flexibility addressing the registers as well as using the least resources.
//----------------------------------------------------------------------------
//....[63:0 packed width].....reg[0:0 - #Features   ][8:0 - #Regs in Feature]  <<= Unpacked dimensions.

localparam USER_CLK_MINOR_REV = (AGILEX == 1) ? 4'h1 : 4'h0; 
logic [CSR_REG_WIDTH-1:0]   csr_reg     [CSR_FEATURE_NUM-1:0][CSR_FEATURE_REG_NUM-1:0];   // CSR Registers
logic                       csr_write   [CSR_FEATURE_NUM-1:0][CSR_FEATURE_REG_NUM-1:0];   // Arrayed like the CSR registers

ofs_csr_hw_state_t          hw_state;           // Hardware state during CSR updates.  This simplifies the CSR Register Update function call.

logic                       aw_ready_valid, w_ready_valid, b_ready_valid, ar_ready_valid, r_ready_valid;

logic [ADDR_WIDTH-1:0]      waddr_reg;
logic [CSR_REG_WIDTH-1:0]   wdata_reg;

csr_access_type_t           write_type, write_type_reg;

logic [ADDR_WIDTH-1:0]      raddr_reg;

port_csr_port_dfh_t         port_csr_port_dfh_reset, port_csr_port_dfh_update;
port_csr_port_afu_id_l_t    port_csr_port_afu_id_l_reset, port_csr_port_afu_id_l_update;
port_csr_port_afu_id_h_t    port_csr_port_afu_id_h_reset, port_csr_port_afu_id_h_update;
port_csr_first_afu_offset_t port_csr_first_afu_offset_reset, port_csr_first_afu_offset_update;
ofs_csr_reg_generic_t       port_csr_port_mailbox_reset, port_csr_port_mailbox_update;
ofs_csr_reg_generic_t       port_csr_port_scratchpad0_reset, port_csr_port_scratchpad0_update;
port_csr_port_capability_t  port_csr_port_capability_reset, port_csr_port_capability_update;
port_csr_port_control_t     port_csr_port_control_reset, port_csr_port_control_update;
port_csr_port_control_t     port_csr_port_control;
port_csr_port_status_t      port_csr_port_status_reset, port_csr_port_status_update;

port_csr_user_clk_dfh_t       port_csr_user_clk_dfh_reset, port_csr_user_clk_dfh_update;
port_csr_user_clk_freq_cmd0_t port_csr_user_clk_freq_cmd0_reset, port_csr_user_clk_freq_cmd0_update;
port_csr_user_clk_freq_cmd1_t port_csr_user_clk_freq_cmd1_reset, port_csr_user_clk_freq_cmd1_update;
port_csr_user_clk_freq_sts0_t port_csr_user_clk_freq_sts0_reset, port_csr_user_clk_freq_sts0_update;
port_csr_user_clk_freq_sts1_t port_csr_user_clk_freq_sts1_reset, port_csr_user_clk_freq_sts1_update;

port_csr_dfh_t                     port_csr_remote_stp_dfh_reset, port_csr_remote_stp_dfh_update;
port_csr_remote_stp_status_t         port_csr_remote_stp_status_reset, port_csr_remote_stp_status_update;

// Port DFH Register Bit Attributes -----------------------------------------------
port_csr_port_dfh_attr_t port_dfh_attr;
assign port_dfh_attr.port_dfh.feature_type    = {4{RO}};
assign port_dfh_attr.port_dfh.reserved        = {19{RsvdZ}};
assign port_dfh_attr.port_dfh.end_of_list     = RO;
assign port_dfh_attr.port_dfh.next_dfh_offset = {24{RO}};
assign port_dfh_attr.port_dfh.afu_maj_version = {4{RO}};
assign port_dfh_attr.port_dfh.corefim_version = {12{RO}};
// Port AFU ID Low Register Bit Attributes ----------------------------------------
port_csr_port_afu_id_l_attr_t port_afu_id_l_attr;
assign port_afu_id_l_attr.port_afu_id_l.afu_id_l = {64{RO}};
// Port AFU ID High Register Bit Attributes ---------------------------------------
port_csr_port_afu_id_h_attr_t port_afu_id_h_attr;
assign port_afu_id_h_attr.port_afu_id_h.afu_id_h = {64{RO}};
// Port First AFU Offset Register Bit Attributes ----------------------------------
port_csr_first_afu_offset_attr_t first_afu_offset_attr;
assign first_afu_offset_attr.first_afu_offset.reserved         = {40{RsvdZ}};
assign first_afu_offset_attr.first_afu_offset.first_afu_offset = {24{RO}};
// Port Main Utility, Control, and Status Register Bit Attributes -----------------
ofs_csr_reg_generic_attr_t port_mailbox_attr;
assign port_mailbox_attr = {64{RW}};
ofs_csr_reg_generic_attr_t port_scratchpad0_attr;
assign port_scratchpad0_attr = {64{RW}};
port_csr_port_capability_attr_t port_capability_attr;
assign port_capability_attr.port_capability.reserved36   = {28{RsvdZ}};
assign port_capability_attr.port_capability.num_supp_int = {4{RO}};
assign port_capability_attr.port_capability.reserved24   = {8{RsvdZ}};
assign port_capability_attr.port_capability.mmio_size    = {16{RO}};
assign port_capability_attr.port_capability.reserved0    = {8{RsvdZ}};
port_csr_port_control_attr_t port_control_attr;
assign port_control_attr.port_control.reserved5           = {59{RsvdZ}};
assign port_control_attr.port_control.port_soft_reset_ack = RO;
assign port_control_attr.port_control.flr_port_reset      = RO;
assign port_control_attr.port_control.latency_tolerance   = RW;
assign port_control_attr.port_control.reserved1           = RsvdZ;
assign port_control_attr.port_control.port_soft_reset     = RW;
port_csr_port_status_attr_t port_status_attr;
assign port_status_attr.port_status.reserved1   = {63{RsvdZ}};
assign port_status_attr.port_status.port_freeze = RO;

// Port User Clock Register Bit Attributes -----------------------------------------
csr_bit_attr_t [63:0] USER_CLK_DFH_ATTR          = {64{RO}};
csr_bit_attr_t [63:0] USER_CLK_FREQ_CMD0_ATTR    = {64{RW}};
csr_bit_attr_t [63:0] USER_CLK_FREQ_CMD1_ATTR    = {64{RW}};
csr_bit_attr_t [63:0] USER_CLK_FREQ_STS0_ATTR    = {64{RO}};
csr_bit_attr_t [63:0] USER_CLK_FREQ_STS1_ATTR    = {64{RO}};

// Port SignalTap Register Bit Attributes -----------------------------------------
port_csr_dfh_attr_t remote_stp_dfh_attr;
assign remote_stp_dfh_attr.dfh.feature_type    = {4{RO}};
assign remote_stp_dfh_attr.dfh.reserved        = {19{RsvdZ}};
assign remote_stp_dfh_attr.dfh.end_of_list     = RO;
assign remote_stp_dfh_attr.dfh.next_dfh_offset = {24{RO}};
assign remote_stp_dfh_attr.dfh.feature_rev     = {4{RO}};
assign remote_stp_dfh_attr.dfh.feature_id      = {12{RO}};
port_csr_remote_stp_status_attr_t remote_stp_status_attr;
assign remote_stp_status_attr.remote_stp_status.num_mmio_resp     = {16{RO}};
assign remote_stp_status_attr.remote_stp_status.num_mmio_req      = {16{RO}};
assign remote_stp_status_attr.remote_stp_status.num_mmio_wr       = {16{RO}};
assign remote_stp_status_attr.remote_stp_status.rx_fifo_underflow = RO;
assign remote_stp_status_attr.remote_stp_status.rx_fifo_overflow  = RO;
assign remote_stp_status_attr.remote_stp_status.tx_fifo_underflow = RO;
assign remote_stp_status_attr.remote_stp_status.tx_fifo_overflow  = RO;
assign remote_stp_status_attr.remote_stp_status.rx_fifo_count     = {4{RO}};
assign remote_stp_status_attr.remote_stp_status.tx_fifo_count     = {4{RO}};
assign remote_stp_status_attr.remote_stp_status.mmio_time_out     = RO;
assign remote_stp_status_attr.remote_stp_status.unsupported_rd    = RO;
assign remote_stp_status_attr.remote_stp_status.stp_in_reset      = RO;
assign remote_stp_status_attr.remote_stp_status.rw_time_out       = RO;

//----------------------------------------------------------------------------
// HW State is a data struct used to pass the resets, write data, and write
// type to the CSR "update_reg" function.
//----------------------------------------------------------------------------
assign hw_state.reset_n      = rst_n;
assign hw_state.pwr_good_n   = 1'b0;
assign hw_state.wr_data.data = wdata_reg;
assign hw_state.write_type   = write_type_reg;

//----------------------------------------------------------------------------
// Combinatorial logic to define what type of write is occurring:
//     1.) UPPER32 = Upper 32 bits of register from lower 32 bits of the write
//         data bus.
//     2.) LOWER32 = Lower 32 bits of register from lower 32 bits of the write
//         data bus.
//     3.) FULL64 = All 64 bits of the register from all 64 bits of the write
//         data bus.
//     4.) NONE = No write will be performed on register.
// Logic must be careful to detect simultaneous awvalid and wvalid OR awvalid
// leading wvalid.  A write address with bit #2 set decides whether 32-bit
// write is to upper or lower word.
//----------------------------------------------------------------------------
always_comb
begin
   write_type = ( !axi_s_if.wvalid )      ?  NONE    :
                  ( &axi_s_if.wstrb )     ?  FULL64  : 
                  ( !axi_s_if.awvalid )   ?
                  ( !waddr_reg[2] )       ?  LOWER32 :
                                             UPPER32 :
                  ( !axi_s_if.awaddr[2] ) ?  LOWER32 :
                                             UPPER32 ;                                                                    
end

//----------------------------------------------------------------------------
// Remote STP IP intercept
//----------------------------------------------------------------------------
logic   remotestp_awaddr_hit;
logic   remotestp_araddr_hit;

logic   remotestp_awaddr_hit_reg;
logic   remotestp_araddr_hit_reg;

`ifndef INCLUDE_REMOTE_STP
assign  remotestp_awaddr_hit        = 1'b0;
assign  remotestp_araddr_hit        = 1'b0;

assign  remotestp_awaddr_hit_reg    = 1'b0;
assign  remotestp_araddr_hit_reg    = 1'b0;
`else
always_ff @ ( posedge clk ) begin
   if ( !rst_n )
      begin
         remotestp_awaddr_hit_reg    <= 1'b0;
         remotestp_araddr_hit_reg    <= 1'b0;
      end else begin
         if ( aw_ready_valid )
            remotestp_awaddr_hit_reg <= remotestp_awaddr_hit;
      
         if ( ar_ready_valid )
            remotestp_araddr_hit_reg <= remotestp_araddr_hit;
      end
end

// Remote STP IP address hit
always_comb
begin
   if ( aw_ready_valid )
      remotestp_awaddr_hit = ( axi_s_if.awaddr[15:4] > REMOTE_STP_DFH[15:4] );
   else
      remotestp_awaddr_hit = remotestp_awaddr_hit_reg;

   if ( ar_ready_valid )
      remotestp_araddr_hit = ( axi_s_if.araddr[15:4] > REMOTE_STP_DFH[15:4] );
   else
      remotestp_araddr_hit = remotestp_araddr_hit_reg;
end
`endif

// Tx ports m_remotestp_if
always_comb
begin
   m_remotestp_if.awvalid = remotestp_awaddr_hit  ? axi_s_if.awvalid  : 1'b0;
   m_remotestp_if.awaddr  = axi_s_if.awaddr;
   m_remotestp_if.awprot  = axi_s_if.awprot;

   m_remotestp_if.wvalid  = remotestp_awaddr_hit  ? axi_s_if.wvalid   : 1'b0;
   m_remotestp_if.wdata   = axi_s_if.wdata;
   m_remotestp_if.wstrb   = axi_s_if.wstrb;

   m_remotestp_if.bready  = axi_s_if.bready;

   m_remotestp_if.arvalid = remotestp_araddr_hit  ? axi_s_if.arvalid  : 1'b0;
   m_remotestp_if.araddr  = axi_s_if.araddr;
   m_remotestp_if.arprot  = axi_s_if.arprot;

   m_remotestp_if.rready  = axi_s_if.rready;
end

//----------------------------------------------------------------------------
// AXI-LITE READY + VALID
//----------------------------------------------------------------------------
always_comb
begin
   aw_ready_valid = ( axi_s_if.awready && axi_s_if.awvalid );
   w_ready_valid  = ( axi_s_if.wready && axi_s_if.wvalid );
   b_ready_valid  = ( axi_s_if.bready && axi_s_if.bvalid );
   ar_ready_valid = ( axi_s_if.arready && axi_s_if.arvalid );
   r_ready_valid  = ( axi_s_if.rready && axi_s_if.rvalid );
end

//----------------------------------------------------------------------------
// AXI-LITE WRITE INTERFACE
//----------------------------------------------------------------------------
typedef enum bit [1:0] {
   ST_WADDR,
   ST_WDATA,
   ST_BWAIT,
   ST_BRESP
} WriteState_t;

WriteState_t     WriteState, WriteNextState;

always_ff @ (posedge clk) begin
   if ( !rst_n ) begin
      WriteState <= ST_WADDR;
   end else begin
      WriteState <= WriteNextState;
   end
end    

always_comb begin
   WriteNextState = WriteState;

   case (WriteState)
      ST_WADDR: begin
         if (aw_ready_valid && w_ready_valid) WriteNextState = ST_BWAIT;
         else if (aw_ready_valid) WriteNextState = ST_WDATA; 
      end

      ST_WDATA: begin
            if (w_ready_valid) WriteNextState = ST_BWAIT;
      end

      ST_BWAIT: begin
         WriteNextState = ST_BRESP;
      end

      ST_BRESP: begin
         if (b_ready_valid) WriteNextState = ST_WADDR;
      end
   endcase

end

always_comb
begin
   axi_s_if.awready                = 1'b0;
   axi_s_if.wready                 = 1'b0;
   axi_s_if.bvalid                 = 1'b0;
   axi_s_if.bresp                  = 2'b00;

   csr_write                       = '{default:0};

   case ( WriteState )
      ST_WADDR: begin
         axi_s_if.awready = 1'b1;
         axi_s_if.wready  = 1'b1;                    
      end

      ST_WDATA: begin
         axi_s_if.wready = 1'b1;                         
      end

      ST_BWAIT: begin
         csr_write[waddr_reg[14:12]][waddr_reg[7:3]] = 1'b1;    
            if (remotestp_awaddr_hit) begin
               csr_write = '{default:0};
            end                      
      end

      ST_BRESP: begin
         csr_write[waddr_reg[14:12]][waddr_reg[7:3]]     = 1'b1; 
         axi_s_if.bvalid = 1'b1;

         if (remotestp_awaddr_hit) begin
            csr_write       = '{default:0};
            axi_s_if.bvalid = m_remotestp_if.bvalid;
            axi_s_if.bresp  = m_remotestp_if.bresp;
         end                
      end

   endcase
end

always_ff @ (posedge clk) begin
   if (!rst_n) begin        
      write_type_reg <= NONE;
      waddr_reg      <= {ADDR_WIDTH{1'b0}};
      wdata_reg      <= {CSR_REG_WIDTH{1'b0}};
   end else begin
      write_type_reg <= write_type;

      if (w_ready_valid) begin
         wdata_reg <= axi_s_if.wdata;
      end

      if (aw_ready_valid) begin
         waddr_reg <= axi_s_if.awaddr;
      end

   end
end

//----------------------------------------------------------------------------
// AXI-LITE READ INTERFACE
//----------------------------------------------------------------------------
typedef enum {
   ST_RADDR,
   ST_RDATA
} ReadState_t;

ReadState_t      ReadState, ReadNextState;

always_ff @ (posedge clk) begin
   if (!rst_n) begin
      ReadState           <= ST_RADDR;
   end else begin
      ReadState           <= ReadNextState;
   end
end

always_comb begin
   ReadNextState           = ReadState;

   case ( ReadState )
      ST_RADDR: begin
         if (ar_ready_valid) begin
            ReadNextState = ST_RDATA;
         end
      end

      ST_RDATA: begin
         if (r_ready_valid) begin
            ReadNextState           = ST_RADDR;        
         end
      end
   endcase
end

always_comb begin
   axi_s_if.arready = 1'b0;
   axi_s_if.rvalid  = 1'b0;
   axi_s_if.rresp   = 2'b00;
   axi_s_if.rdata   = csr_reg[raddr_reg[14:12]][raddr_reg[7:3]];

   if (remotestp_araddr_hit) begin
      axi_s_if.rdata = m_remotestp_if.rdata;
   end

   case (ReadState)
      ST_RADDR: begin
         axi_s_if.arready = 1'b1;               
      end

      ST_RDATA: begin
         axi_s_if.rvalid = 1'b1; 

         if (remotestp_araddr_hit) begin
            axi_s_if.rvalid = m_remotestp_if.rvalid;
            axi_s_if.rresp  = m_remotestp_if.rresp;
         end                
      end
   endcase

end

always_ff @ (posedge clk)
begin
   if (!rst_n) begin
      raddr_reg <= {ADDR_WIDTH{1'b0}};
   end else begin
      if (ar_ready_valid) begin
         raddr_reg <= axi_s_if.araddr;
      end
   end
end

//----------------------------------------------------------------------------
// User Clk CMD Assignments
//----------------------------------------------------------------------------
assign user_clk_freq_cmd_0 = csr_reg[USER_CLK_FREQ_CMD0[14:12]][USER_CLK_FREQ_CMD0[7:3]];
assign user_clk_freq_cmd_1 = csr_reg[USER_CLK_FREQ_CMD1[14:12]][USER_CLK_FREQ_CMD1[7:3]];

//------------------------------------------------------------------------------------------------------------------
// Port DFH Register------------------------------------------------------------------------------------------------
assign port_csr_port_dfh_reset.data = port_csr_port_dfh_update.data; 
assign port_csr_port_dfh_update.port_dfh.feature_type    = 4'h4; 
assign port_csr_port_dfh_update.port_dfh.reserved        = {19{1'b0}}; 
`ifdef INCLUDE_USER_CLK
assign port_csr_port_dfh_update.port_dfh.end_of_list     = 1'b0;
assign port_csr_port_dfh_update.port_dfh.next_dfh_offset = USER_CLK_DFH - PORT_DFH;
`elsif INCLUDE_REMOTE_STP
assign port_csr_port_dfh_update.port_dfh.end_of_list     = 1'b0;
assign port_csr_port_dfh_update.port_dfh.next_dfh_offset = REMOTE_STP_DFH - PORT_DFH;
`else
assign port_csr_port_dfh_update.port_dfh.end_of_list     = END_OF_LIST;
assign port_csr_port_dfh_update.port_dfh.next_dfh_offset = NEXT_DFH_OFFSET - PORT_DFH;
`endif
assign port_csr_port_dfh_update.port_dfh.afu_maj_version = 4'h1; 
assign port_csr_port_dfh_update.port_dfh.corefim_version = 12'h001;
assign port_csr_port_afu_id_l_reset.data  = 64'h9642_B06C_6B35_5B87;
assign port_csr_port_afu_id_l_update.data = 64'h9642_B06C_6B35_5B87;
assign port_csr_port_afu_id_h_reset.data  = 64'h3AB4_9893_138D_42EB;
assign port_csr_port_afu_id_h_update.data = 64'h3AB4_9893_138D_42EB;
assign port_csr_first_afu_offset_reset.data = port_csr_first_afu_offset_update.data;
assign port_csr_first_afu_offset_update.first_afu_offset.reserved         = {40{1'b0}};
assign port_csr_first_afu_offset_update.first_afu_offset.first_afu_offset = 24'h0;      // WAS 24'h040000;
assign port_csr_port_mailbox_reset.data  = 64'h0000_0000_0000_0000;
assign port_csr_port_mailbox_update.data = 64'h0000_0000_0000_0000;
assign port_csr_port_scratchpad0_reset.data  = 64'h0000_0000_0000_0000;
assign port_csr_port_scratchpad0_update.data = 64'h0000_0000_0000_0000;

// Port Capability -----------------------------------------------------------
assign port_csr_port_capability_reset.data = port_csr_port_capability_update.data;
assign port_csr_port_capability_update.port_capability.reserved36   = {28{1'b0}};
assign port_csr_port_capability_update.port_capability.num_supp_int = 4'd4;
assign port_csr_port_capability_update.port_capability.reserved24   = {8{1'b0}};
assign port_csr_port_capability_update.port_capability.mmio_size    = 16'h0100;
assign port_csr_port_capability_update.port_capability.reserved0    = {8{1'b0}};

// Port Control --------------------------------------------------------------
assign port_csr_port_control_reset.data = port_csr_port_control_update.data;
assign port_csr_port_control_update.port_control.reserved5           = {59{1'b0}};
assign port_csr_port_control_update.port_control.port_soft_reset_ack = i_port_ctrl[4];  // WAS port_io.inp2cr_port_control[4];
assign port_csr_port_control_update.port_control.flr_port_reset      = i_port_ctrl[3];  // WAS port_io.inp2cr_port_control[3];
assign port_csr_port_control_update.port_control.latency_tolerance   = 1'b1;
assign port_csr_port_control_update.port_control.reserved1           = 1'b0;
assign port_csr_port_control_update.port_control.port_soft_reset     = 1'b1;

// Port Status ---------------------------------------------------------------
assign port_csr_port_status_reset.data = port_csr_port_status_update.data;
assign port_csr_port_status_update.port_status.reserved1   = {63{1'b0}};
assign port_csr_port_status_update.port_status.port_freeze = i_pr_freeze;         // WAS port_io.inp2cr_port_status[0];

// User Clock DFH Register-------------------------------------------------------------------------------------------------
assign port_csr_user_clk_dfh_reset.data                           = port_csr_user_clk_dfh_update.data;
assign port_csr_user_clk_dfh_update.user_clk_dfh.FeatureType      = 4'h3;
assign port_csr_user_clk_dfh_update.user_clk_dfh.Reserved41       = {18{1'b0}};
`ifdef INCLUDE_REMOTE_STP
assign port_csr_user_clk_dfh_update.user_clk_dfh.EOL              = 1'b0;
assign port_csr_user_clk_dfh_update.user_clk_dfh.NextDfhOffset    = REMOTE_STP_DFH - USER_CLK_DFH;
`else
assign port_csr_user_clk_dfh_update.user_clk_dfh.EOL              = END_OF_LIST;
assign port_csr_user_clk_dfh_update.user_clk_dfh.NextDfhOffset    = NEXT_DFH_OFFSET - USER_CLK_DFH;
`endif
assign port_csr_user_clk_dfh_update.user_clk_dfh.CciMinorRev      = USER_CLK_MINOR_REV;
assign port_csr_user_clk_dfh_update.user_clk_dfh.CciVersion       = 12'h14;

// User Clock Freq CMD0 Register-------------------------------------------------------------------------------------------------
assign port_csr_user_clk_freq_cmd0_reset.data                                     = 64'h0;
assign port_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.Reserved4            = 6'h0; 
assign port_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.UsrClkCmdPllRst      = 1'h0;
assign port_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.UsrClkCmdPllMgmtRst  = 1'h0;
assign port_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.Reserved3            = 3'h0;
assign port_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.UsrClkCmdMmRst       = 1'h0;  
assign port_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.Reserved2            = 2'h0;
assign port_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.UsrClkCmdSeq         = 2'h0;
assign port_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.Reserved1            = 3'h0;
assign port_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.UsrClkCmdWr          = 1'h0;
assign port_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.Reserved0            = 2'h0;
assign port_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.UsrClkCmdAdr         = 10'h0;
assign port_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.UsrClkCmdDat         = 32'h0;

// User Clock Freq CMD1 Register-------------------------------------------------------------------------------------------------
assign port_csr_user_clk_freq_cmd1_reset.data                                 = 64'h0;
assign port_csr_user_clk_freq_cmd1_update.user_clk_freq_cmd1.Reserved1        = 31'h0; 
assign port_csr_user_clk_freq_cmd1_update.user_clk_freq_cmd1.FreqCntrClkSel   = 1'h0; 
assign port_csr_user_clk_freq_cmd1_update.user_clk_freq_cmd1.Reserved0        = 32'h0; 

// User Clock Freq STS0 Register-------------------------------------------------------------------------------------------------
assign port_csr_user_clk_freq_sts0_reset.data     = 64'h0;
assign port_csr_user_clk_freq_sts0_update.data    = user_clk_freq_sts_0;

// User Clock Freq STS1 Register-------------------------------------------------------------------------------------------------
assign port_csr_user_clk_freq_sts1_reset.data     = 64'h0;
assign port_csr_user_clk_freq_sts1_update.data    = user_clk_freq_sts_1;

// Port STP DFH --------------------------------------------------------------
assign port_csr_remote_stp_dfh_reset.data = port_csr_remote_stp_dfh_update.data; 
assign port_csr_remote_stp_dfh_update.dfh.feature_type    = 4'h3; 
assign port_csr_remote_stp_dfh_update.dfh.reserved        = {19{1'b0}}; 
assign port_csr_remote_stp_dfh_update.dfh.end_of_list     = END_OF_LIST;
assign port_csr_remote_stp_dfh_update.dfh.next_dfh_offset = NEXT_DFH_OFFSET - REMOTE_STP_DFH;
assign port_csr_remote_stp_dfh_update.dfh.feature_rev     = 4'h2; 
assign port_csr_remote_stp_dfh_update.dfh.feature_id      = 12'h013; 

// Port STP Status -----------------------------------------------------------
assign port_csr_remote_stp_status_reset.data  = port_csr_remote_stp_status_update.data;
assign port_csr_remote_stp_status_update.data = i_remotestp_status;                           // WAS port_io.inp2cr_remote_stp_status;

//----------------------------------------------------------------------------
// Outputs into the CSR Interface for distribution.
//----------------------------------------------------------------------------
assign o_port_ctrl  = csr_reg[PORT_CONTROL[14:12]][PORT_CONTROL[7:3]];

//----------------------------------------------------------------------------
// Register Update Logic using "update_reg" function in "ofs_csr_pkg.sv"
// SystemVerilog package.  Function inputs are "named" for ease of
// understanding the use.
//     - Register bit attributes are set in array input above.  Attribute
//       functions are defined in SAS.
//     - Reset Value is appied at reset except for RO, *D, and Rsvd{Z}.
//     - Update Value is used as status bit updates for RO, RW1C*, and RW1S*.
//     - Current Value is used to determine next register value.  This must be
//       done due to scoping rules using SystemVerilog package.
//     - "Write" is the decoded write signal for that particular register.
//     - State is a hardware state structure to pass input signals to
//       "update_reg" function.  See just above.
//----------------------------------------------------------------------------
always_ff @ ( posedge clk )
begin
   csr_reg[PORT_DFH[14:12]][PORT_DFH[7:3]] <= update_reg(
                                                   // [63:60]: Feature Type
                                                   // [59:52]: Reserved
                                                   // [51:48]: If AFU - AFU Minor Revision Number (else, reserved)
                                                   // [47:41]: Reserved
                                                   // [   40]: EOL (End of DFH list)
                                                   // [39:16]: Next DFH Byte Offset
                                                   // [15:12]: If AfU, AFU Major version number (else feature #)
                                                   // [11: 0]: Feature ID
                                                         .attr            (port_dfh_attr.data),
                                                         .reg_reset_val   (port_csr_port_dfh_reset.data),
                                                         .reg_update_val  (port_csr_port_dfh_update.data),
                                                         .reg_current_val (csr_reg[PORT_DFH[14:12]][PORT_DFH[7:3]]),
                                                         .write           (csr_write[PORT_DFH[14:12]][PORT_DFH[7:3]]),
                                                         .state           (hw_state)
                                                      );

   csr_reg[PORT_AFU_ID_L[14:12]][PORT_AFU_ID_L[7:3]] <=   update_reg (
                                                                        .attr(port_afu_id_l_attr.data),
                                                                        .reg_reset_val   (port_csr_port_afu_id_l_reset.data),
                                                                        .reg_update_val  (port_csr_port_afu_id_l_update.data),
                                                                        .reg_current_val (csr_reg[PORT_AFU_ID_L[14:12]][PORT_AFU_ID_L[7:3]]),
                                                                        .write           (csr_write[PORT_AFU_ID_L[14:12]][PORT_AFU_ID_L[7:3]]),
                                                                        .state           (hw_state)
                                                                  );

   csr_reg[PORT_AFU_ID_H[14:12]][PORT_AFU_ID_H[7:3]] <=   update_reg (
                                                                     .attr            (port_afu_id_h_attr.data),
                                                                     .reg_reset_val   (port_csr_port_afu_id_h_reset.data),
                                                                     .reg_update_val  (port_csr_port_afu_id_h_update.data),
                                                                     .reg_current_val (csr_reg[PORT_AFU_ID_H[14:12]][PORT_AFU_ID_H[7:3]]),
                                                                     .write           (csr_write[PORT_AFU_ID_H[14:12]][PORT_AFU_ID_H[7:3]]),
                                                                     .state           (hw_state)
                                                                  );

   csr_reg[FIRST_AFU_OFFSET[14:12]][FIRST_AFU_OFFSET[7:3]] <=   update_reg (
                                                                           .attr            (first_afu_offset_attr.data),
                                                                           .reg_reset_val   (port_csr_first_afu_offset_reset.data),
                                                                           .reg_update_val  (port_csr_first_afu_offset_update.data),
                                                                           .reg_current_val (csr_reg[FIRST_AFU_OFFSET[14:12]][FIRST_AFU_OFFSET[7:3]]),
                                                                           .write           (csr_write[FIRST_AFU_OFFSET[14:12]][FIRST_AFU_OFFSET[7:3]]),
                                                                           .state           (hw_state)
                                                                        );

   csr_reg[PORT_MAILBOX[14:12]][PORT_MAILBOX[7:3]] <=  update_reg (
                                                                  .attr            (port_mailbox_attr.data),
                                                                  .reg_reset_val   (port_csr_port_mailbox_reset.data),
                                                                  .reg_update_val  (port_csr_port_mailbox_update.data),
                                                                  .reg_current_val (csr_reg[PORT_MAILBOX[14:12]][PORT_MAILBOX[7:3]]),
                                                                  .write           (csr_write[PORT_MAILBOX[14:12]][PORT_MAILBOX[7:3]]),
                                                                  .state           (hw_state)
                                                               );

   csr_reg[PORT_SCRATCHPAD0[14:12]][PORT_SCRATCHPAD0[7:3]] <=   update_reg (
                                                                           .attr            (port_scratchpad0_attr.data),
                                                                           .reg_reset_val   (port_csr_port_scratchpad0_reset.data),
                                                                           .reg_update_val  (port_csr_port_scratchpad0_update.data),
                                                                           .reg_current_val (csr_reg[PORT_SCRATCHPAD0[14:12]][PORT_SCRATCHPAD0[7:3]]),
                                                                           .write           (csr_write[PORT_SCRATCHPAD0[14:12]][PORT_SCRATCHPAD0[7:3]]),
                                                                           .state           (hw_state)
                                                                        );

   csr_reg[PORT_CAPABILITY[14:12]][PORT_CAPABILITY[7:3]] <=  update_reg (
                                                                        .attr            (port_capability_attr.data),
                                                                        .reg_reset_val   (port_csr_port_capability_reset.data),
                                                                        .reg_update_val  (port_csr_port_capability_update.data),
                                                                        .reg_current_val (csr_reg[PORT_CAPABILITY[14:12]][PORT_CAPABILITY[7:3]]),
                                                                        .write           (csr_write[PORT_CAPABILITY[14:12]][PORT_CAPABILITY[7:3]]),
                                                                        .state           (hw_state)
                                                                     );

   csr_reg[PORT_CONTROL[14:12]][PORT_CONTROL[7:3]] <=  update_reg (
                                                                  .attr            (port_control_attr.data),
                                                                  .reg_reset_val   (port_csr_port_control_reset.data),
                                                                  .reg_update_val  (port_csr_port_control_update.data),
                                                                  .reg_current_val (csr_reg[PORT_CONTROL[14:12]][PORT_CONTROL[7:3]]),
                                                                  .write           (csr_write[PORT_CONTROL[14:12]][PORT_CONTROL[7:3]]),
                                                                  .state           (hw_state)
                                                               );

   csr_reg[PORT_STATUS[14:12]][PORT_STATUS[7:3]] <= update_reg(
                                                               .attr            (port_status_attr.data),
                                                               .reg_reset_val   (port_csr_port_status_reset.data),
                                                               .reg_update_val  (port_csr_port_status_update.data),
                                                               .reg_current_val (csr_reg[PORT_STATUS[14:12]][PORT_STATUS[7:3]]),
                                                               .write           (csr_write[PORT_STATUS[14:12]][PORT_STATUS[7:3]]),
                                                               .state           (hw_state)
                                                            );
                                                            
   csr_reg[USER_CLK_DFH[14:12]][USER_CLK_DFH[7:3]]   <= update_reg (
                                                      // [63:60]: Feature Type = Private
                                                      // [59:41]: Reserved41
                                                      // [   40]: EOL - End of DFH List
                                                      // [39:16]: Next DFH Byte Offset
                                                      // [15:12]: CCI-P Minor Revision
                                                      // [11: 0]: CCI-P Version #
                                                         .attr            (USER_CLK_DFH_ATTR),
                                                         .reg_reset_val   (port_csr_user_clk_dfh_reset.data),
                                                         .reg_update_val  (port_csr_user_clk_dfh_update.data),
                                                         .reg_current_val (csr_reg[USER_CLK_DFH[14:12]][USER_CLK_DFH[7:3]]),
                                                         .write           (csr_write[USER_CLK_DFH[14:12]][USER_CLK_DFH[7:3]]),
                                                         .state           (hw_state)
                                                      ); 

   csr_reg[USER_CLK_FREQ_CMD0[14:12]][USER_CLK_FREQ_CMD0[7:3]]   <= update_reg(
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
                                                         .attr            (USER_CLK_FREQ_CMD0_ATTR),
                                                         .reg_reset_val   (port_csr_user_clk_freq_cmd0_reset.data),
                                                         .reg_update_val  (port_csr_user_clk_freq_cmd0_update.data),
                                                         .reg_current_val (csr_reg[USER_CLK_FREQ_CMD0[14:12]][USER_CLK_FREQ_CMD0[7:3]]),
                                                         .write           (csr_write[USER_CLK_FREQ_CMD0[14:12]][USER_CLK_FREQ_CMD0[7:3]]),
                                                         .state           (hw_state)
                                                      ); 

   csr_reg[USER_CLK_FREQ_CMD1[14:12]][USER_CLK_FREQ_CMD1[7:3]]   <= update_reg(
                                                      // [63:33]:    Reserved
                                                      // [   32]:    Clock to measure (0 - uClk_usr_Div2, 1 - uClk_usr)
                                                      // [31: 0]:    Reserved
                                                         .attr            (USER_CLK_FREQ_CMD1_ATTR),
                                                         .reg_reset_val   (port_csr_user_clk_freq_cmd1_reset.data),
                                                         .reg_update_val  (port_csr_user_clk_freq_cmd1_update.data),
                                                         .reg_current_val (csr_reg[USER_CLK_FREQ_CMD1[14:12]][USER_CLK_FREQ_CMD1[7:3]]),
                                                         .write           (csr_write[USER_CLK_FREQ_CMD1[14:12]][USER_CLK_FREQ_CMD1[7:3]]),
                                                         .state           (hw_state)
                                                      ); 

   csr_reg[USER_CLK_FREQ_STS0[14:12]][USER_CLK_FREQ_STS0[7:3]]   <= update_reg(
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
                                                         .attr               (USER_CLK_FREQ_STS0_ATTR),
                                                         .reg_reset_val      (port_csr_user_clk_freq_sts0_reset.data),
                                                         .reg_update_val     (port_csr_user_clk_freq_sts0_update.data),
                                                         .reg_current_val    (csr_reg[USER_CLK_FREQ_STS0[14:12]][USER_CLK_FREQ_STS0[7:3]]),
                                                         .write              (csr_write[USER_CLK_FREQ_STS0[14:12]][USER_CLK_FREQ_STS0[7:3]]),
                                                         .state              (hw_state)
                                                      ); 

   csr_reg[USER_CLK_FREQ_STS1[14:12]][USER_CLK_FREQ_STS1[7:3]]   <= update_reg(
                                                      // [63:60]:    Frequency counter version number
                                                      // [59:51]:    Reserved
                                                      // [50:33]:    PLL Reference Clock Frequency in 10kHz units.  For example, 100MHz = 10000 x 10 kHz >>> 10000 = 0x2710
                                                      // [   32]:    Clock that was measured (0 - uClk_usr_Div2, 1 - uClk_Usr)
                                                      // [31:17]:    Reserved
                                                      // [16: 0]:    Frequency in 10kHz units
                                                         .attr               (USER_CLK_FREQ_STS1_ATTR),
                                                         .reg_reset_val      (port_csr_user_clk_freq_sts1_reset.data),
                                                         .reg_update_val     (port_csr_user_clk_freq_sts1_update.data),
                                                         .reg_current_val    (csr_reg[USER_CLK_FREQ_STS1[14:12]][USER_CLK_FREQ_STS1[7:3]]),
                                                         .write              (csr_write[USER_CLK_FREQ_STS1[14:12]][USER_CLK_FREQ_STS1[7:3]]),
                                                         .state              (hw_state)
                                                      ); 

   csr_reg[REMOTE_STP_DFH[14:12]][REMOTE_STP_DFH[7:3]] <=  update_reg (
                                                                  .attr            (remote_stp_dfh_attr.data),
                                                                  .reg_reset_val   (port_csr_remote_stp_dfh_reset.data),
                                                                  .reg_update_val  (port_csr_remote_stp_dfh_update.data),
                                                                  .reg_current_val (csr_reg[REMOTE_STP_DFH[14:12]][REMOTE_STP_DFH[7:3]]),
                                                                  .write           (csr_write[REMOTE_STP_DFH[14:12]][REMOTE_STP_DFH[7:3]]),
                                                                  .state           (hw_state)
                                                               );

   csr_reg[REMOTE_STP_STATUS[14:12]][REMOTE_STP_STATUS[7:3]] <=  update_reg (
                                                                        .attr(remote_stp_status_attr.data),
                                                                        .reg_reset_val   (port_csr_remote_stp_status_reset.data),
                                                                        .reg_update_val  (port_csr_remote_stp_status_update.data),
                                                                        .reg_current_val (csr_reg[REMOTE_STP_STATUS[14:12]][REMOTE_STP_STATUS[7:3]]),
                                                                        .write           (csr_write[REMOTE_STP_STATUS[14:12]][REMOTE_STP_STATUS[7:3]]),
                                                                        .state           (hw_state)
                                                                     ); 
end

endmodule 

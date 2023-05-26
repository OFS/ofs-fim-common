// Copyright (C) 2001-2021 Intel Corporation
// SPDX-License-Identifier: MIT


`timescale 1 ps / 1 ps
///////////////////////////////////////////////////////////////////////////////
// Top-level wrapper of EMIF Configurable Avalon Traffic Generator.
//
///////////////////////////////////////////////////////////////////////////////

// Give unique names to each of the PNF ISSPs for later sorting
`define _get_pnf_id(_prefix, _i)  (  (((_i)==0) ? `"_prefix``0`" : \
                                     (((_i)==1) ? `"_prefix``1`" : \
                                     (((_i)==2) ? `"_prefix``2`" : \
                                     (((_i)==3) ? `"_prefix``3`" : \
                                     (((_i)==4) ? `"_prefix``4`" : \
                                     (((_i)==5) ? `"_prefix``5`" : \
                                     (((_i)==6) ? `"_prefix``6`" : \
                                     (((_i)==7) ? `"_prefix``7`" : `"_prefix``8`")))))))))

import avl_tg_defs::*;

module altera_emif_avl_tg_2_top # (
   parameter PROTOCOL_ENUM                           = "",
   parameter MEGAFUNC_DEVICE_FAMILY                  = "",

   // Exercise the CSR interface
   parameter TEST_CSR                                = 0,

   // SHORT -> Suitable for simulation only.
   // MEDIUM -> Generates more traffic for simple hardware testing in seconds.
   // INFINITE -> Generates traffic continuously and indefinitely.
   parameter TEST_DURATION                           = "SHORT",

   // Bypass the default traffic pattern
   parameter BYPASS_DEFAULT_PATTERN                  = 0,

   // Bypass the user test stage after a reset
   parameter BYPASS_USER_STAGE                       = 1,

   // Disables the status checker from performing a comparison between written/read data, forcing it to never fail. 
   // Useful for read-only performance tests.
   parameter DISABLE_STATUS_CHECKER                  = 0,

   // Number of controller ports
   parameter NUM_OF_CTRL_PORTS                       = 1,

   // Avalon protocol used by the controller
   parameter CTRL_AVL_PROTOCOL_ENUM                  = "",

   // Indicates whether Avalon byte-enable signal is used
   parameter USE_AVL_BYTEEN                          = 1,

   // FIFO width for compare_addr_generator
   parameter COMPARE_ADDR_GEN_FIFO_WIDTH             = 64,

   // Specifies alignment criteria for Avalon-MM word addresses and burst count
   parameter AMM_WORD_ADDRESS_DIVISIBLE_BY           = 1,
   parameter AMM_BURST_COUNT_DIVISIBLE_BY            = 1,

   // The traffic generator is an Avalon master, and therefore generates symbol-
   // addresses that are word-aligned when the protocol specified is Avalon-MM.
   // To generate word-aligned addresses it must know the word address width.
   parameter AMM_WORD_ADDRESS_WIDTH                  = 1,

   // Definition of port widths for "ctrl_amm" interface (auto-generated)
   parameter PORT_CTRL_AMM_RDATA_WIDTH               = 1,
   parameter PORT_CTRL_AMM_ADDRESS_WIDTH             = 1,
   parameter PORT_CTRL_AMM_WDATA_WIDTH               = 1,
   parameter PORT_CTRL_AMM_BCOUNT_WIDTH              = 1,
   parameter PORT_CTRL_AMM_BYTEEN_WIDTH              = 1,

   // Definition of port widths for "ctrl_user_refresh" interface
   parameter PORT_CTRL_USER_REFRESH_REQ_WIDTH        = 1,
   parameter PORT_CTRL_USER_REFRESH_BANK_WIDTH       = 1,

   // Definition of port widths for "ctrl_self_refresh" interface
   parameter PORT_CTRL_SELF_REFRESH_REQ_WIDTH        = 1,

   // Definition of port widths for "ctrl_mmr" interface
   parameter PORT_CTRL_MMR_MASTER_ADDRESS_WIDTH      = 1,
   parameter PORT_CTRL_MMR_MASTER_RDATA_WIDTH        = 1,
   parameter PORT_CTRL_MMR_MASTER_WDATA_WIDTH        = 1,
   parameter PORT_CTRL_MMR_MASTER_BCOUNT_WIDTH       = 1,

   // Definition of port widths for "tg_cfg" interface
   parameter PORT_TG_CFG_ADDRESS_WIDTH      = 1,
   parameter PORT_TG_CFG_RDATA_WIDTH        = 1,
   parameter PORT_TG_CFG_WDATA_WIDTH        = 1,

   // Definition of port widths for "tg_cfg" interface
   //valid values for this parameter are defined in the TG_CFG_AMM_EXPORT_MODE enum
   parameter DIAG_EXPORT_TG_CFG_AVALON_SLAVE         = "TG_CFG_AMM_EXPORT_MODE_EXPORT",
   parameter CORE_CLK_FREQ_HZ                        = 0,

   // definition of port width for TG_TIMEOUT signal
   // it is reduced in simulation test for quicker results
   parameter TG_TIMEOUT_WIDTH = 32,
   parameter MEM_TTL_DATA_WIDTH = 1,
   parameter MEM_TTL_NUM_OF_WRITE_GROUPS = 1,
   parameter AVL_TO_DQ_WIDTH_RATIO = 1,

   parameter INFI_TG2_ERR_TEST = 0,
   parameter CTRL_INTERFACE_TYPE             = "AVL",
   parameter CTRL_BRIDGE_EN                  = 1,
   parameter PORT_CTRL_AXI4_AWID_WIDTH          = 1,
   parameter PORT_CTRL_AXI4_AWADDR_WIDTH        = 31,
   parameter PORT_CTRL_AXI4_AWUSER_WIDTH        = 8,
   parameter PORT_CTRL_AXI4_AWLEN_WIDTH         = 8,
   parameter PORT_CTRL_AXI4_AWSIZE_WIDTH        = 3,
   parameter PORT_CTRL_AXI4_AWBURST_WIDTH       = 2,
   parameter PORT_CTRL_AXI4_AWLOCK_WIDTH        = 1,
   parameter PORT_CTRL_AXI4_AWCACHE_WIDTH       = 4,
   parameter PORT_CTRL_AXI4_AWPROT_WIDTH        = 3,
   parameter PORT_CTRL_AXI4_ARID_WIDTH          = 1,
   parameter PORT_CTRL_AXI4_ARADDR_WIDTH        = 31,
   parameter PORT_CTRL_AXI4_ARUSER_WIDTH        = 8,
   parameter PORT_CTRL_AXI4_ARLEN_WIDTH         = 8,
   parameter PORT_CTRL_AXI4_ARSIZE_WIDTH        = 3,
   parameter PORT_CTRL_AXI4_ARBURST_WIDTH       = 2,
   parameter PORT_CTRL_AXI4_ARLOCK_WIDTH        = 1,
   parameter PORT_CTRL_AXI4_ARCACHE_WIDTH       = 4,
   parameter PORT_CTRL_AXI4_ARPROT_WIDTH        = 3,
   parameter PORT_CTRL_AXI4_WDATA_WIDTH         = 512,
   parameter PORT_CTRL_AXI4_WSTRB_WIDTH         = 64,
   parameter PORT_CTRL_AXI4_BID_WIDTH           = 1,
   parameter PORT_CTRL_AXI4_BRESP_WIDTH         = 2,
   parameter PORT_CTRL_AXI4_BUSER_WIDTH         = 8,
   parameter PORT_CTRL_AXI4_RID_WIDTH           = 1,
   parameter PORT_CTRL_AXI4_RDATA_WIDTH         = 512,
   parameter PORT_CTRL_AXI4_RRESP_WIDTH         = 2,
   parameter PORT_CTRL_AXI4_RUSER_WIDTH         = 8,

   // Definition of port widths for CSR AXI4-Lite interface
   parameter PORT_SUBSYSTEM_CSR_AXI4L_AWADDR_WIDTH     = 1,
   parameter PORT_SUBSYSTEM_CSR_AXI4L_AWPROT_WIDTH     = 1,
   parameter PORT_SUBSYSTEM_CSR_AXI4L_ARADDR_WIDTH     = 1,
   parameter PORT_SUBSYSTEM_CSR_AXI4L_ARPROT_WIDTH     = 1,
   parameter PORT_SUBSYSTEM_CSR_AXI4L_WDATA_WIDTH      = 1,
   parameter PORT_SUBSYSTEM_CSR_AXI4L_WSTRB_WIDTH      = 1,
   parameter PORT_SUBSYSTEM_CSR_AXI4L_BRESP_WIDTH      = 1,
   parameter PORT_SUBSYSTEM_CSR_AXI4L_RDATA_WIDTH      = 1,
   parameter PORT_SUBSYSTEM_CSR_AXI4L_RRESP_WIDTH      = 1,

   // Register width definitions
   parameter AMM_CFG_ADDR_WIDTH                 = 10,
   parameter RW_RPT_COUNT_WIDTH                 = 16,
   parameter RW_OPERATION_COUNT_WIDTH           = 12,
   parameter RW_LOOP_COUNT_WIDTH                = 32,

   // Ensures unique addresses are generated for different
   // TGs when multiple TG instances are used. The
   // TG_INST_UNIQUE_ID is used to hardcode the MSBs of each
   // generated address. Supports up to 8 TGs.
   // NUM_OF_AXI_SWITCH_RESPONDERS ensures that only valid
   // responders are accessed (if addr MSBs select the responder)
   parameter TG_INST_UNIQUE_ID                  = 0,
   parameter USE_UNIQUE_ADDR_PER_TG_INST        = 0,
   parameter NUM_OF_AXI_SWITCH_RESPONDERS       = 0
) (
   // User reset
   input  logic                                               emif_usr_reset_n,

   // User clock
   input  logic                                               emif_usr_clk,

   // Chip Initialization done
   input  logic                                               ninit_done,

   // Ports for CSR AXI4-Lite interface
   output logic   [PORT_SUBSYSTEM_CSR_AXI4L_AWADDR_WIDTH-1:0] ss_base_csr_axi4l_awaddr,
   output logic                                               ss_base_csr_axi4l_awvalid,
   input  logic                                               ss_base_csr_axi4l_awready,
   output logic   [PORT_SUBSYSTEM_CSR_AXI4L_AWPROT_WIDTH-1:0] ss_base_csr_axi4l_awprot,   
   output logic   [PORT_SUBSYSTEM_CSR_AXI4L_ARADDR_WIDTH-1:0] ss_base_csr_axi4l_araddr,
   output logic                                               ss_base_csr_axi4l_arvalid,
   input  logic                                               ss_base_csr_axi4l_arready,
   output logic   [PORT_SUBSYSTEM_CSR_AXI4L_ARPROT_WIDTH-1:0] ss_base_csr_axi4l_arprot,   
   output logic   [PORT_SUBSYSTEM_CSR_AXI4L_WDATA_WIDTH-1:0]  ss_base_csr_axi4l_wdata,
   output logic                                               ss_base_csr_axi4l_wvalid,
   input  logic                                               ss_base_csr_axi4l_wready,
   output logic   [PORT_SUBSYSTEM_CSR_AXI4L_WSTRB_WIDTH-1:0]  ss_base_csr_axi4l_wstrb,    
   input  logic   [PORT_SUBSYSTEM_CSR_AXI4L_BRESP_WIDTH-1:0]  ss_base_csr_axi4l_bresp,
   input  logic                                               ss_base_csr_axi4l_bvalid,
   output logic                                               ss_base_csr_axi4l_bready,
   input  logic   [PORT_SUBSYSTEM_CSR_AXI4L_RDATA_WIDTH-1:0]  ss_base_csr_axi4l_rdata,
   input  logic   [PORT_SUBSYSTEM_CSR_AXI4L_RRESP_WIDTH-1:0]  ss_base_csr_axi4l_rresp,
   input  logic                                               ss_base_csr_axi4l_rvalid,
   output logic                                               ss_base_csr_axi4l_rready,

   // Ports for "ctrl_axi" interfaces
   output logic [PORT_CTRL_AXI4_AWID_WIDTH-1:0]               axi_awid,
   output logic [PORT_CTRL_AXI4_AWADDR_WIDTH-1:0]             axi_awaddr,
   output logic                                               axi_awvalid,
   output logic [PORT_CTRL_AXI4_AWUSER_WIDTH-1:0]             axi_awuser,
   output logic [PORT_CTRL_AXI4_AWLEN_WIDTH-1:0]              axi_awlen,
   output logic [PORT_CTRL_AXI4_AWSIZE_WIDTH-1:0]             axi_awsize,
   output logic [PORT_CTRL_AXI4_AWBURST_WIDTH-1:0]            axi_awburst,
   input  logic                                               axi_awready,
   output logic [PORT_CTRL_AXI4_AWPROT_WIDTH-1:0]             axi_awprot,
   output logic [PORT_CTRL_AXI4_AWCACHE_WIDTH-1:0]            axi_awcache,
   output logic [PORT_CTRL_AXI4_AWLOCK_WIDTH-1:0]             axi_awlock,
   output logic [PORT_CTRL_AXI4_ARID_WIDTH-1:0]               axi_arid,
   output logic [PORT_CTRL_AXI4_ARADDR_WIDTH-1:0]             axi_araddr,
   output logic                                               axi_arvalid,
   output logic [PORT_CTRL_AXI4_ARUSER_WIDTH-1:0]             axi_aruser,
   output logic [PORT_CTRL_AXI4_ARLEN_WIDTH-1:0]              axi_arlen,
   output logic [PORT_CTRL_AXI4_ARSIZE_WIDTH-1:0]             axi_arsize,
   output logic [PORT_CTRL_AXI4_ARBURST_WIDTH-1:0]            axi_arburst,
   input  logic                                               axi_arready,
   output logic [PORT_CTRL_AXI4_ARPROT_WIDTH-1:0]             axi_arprot,
   output logic [PORT_CTRL_AXI4_ARCACHE_WIDTH-1:0]            axi_arcache,
   output logic [PORT_CTRL_AXI4_ARLOCK_WIDTH-1:0]             axi_arlock,
   output logic [PORT_CTRL_AXI4_WDATA_WIDTH-1:0]              axi_wdata,
   output logic [PORT_CTRL_AXI4_WSTRB_WIDTH-1:0]              axi_wstrb,
   output logic                                               axi_wlast,
   output logic                                               axi_wvalid,
   input  logic                                               axi_wready,
   input  logic [PORT_CTRL_AXI4_BID_WIDTH-1:0]                axi_bid,
   input  logic [PORT_CTRL_AXI4_BRESP_WIDTH-1:0]              axi_bresp,
   input  logic [PORT_CTRL_AXI4_BUSER_WIDTH-1:0]              axi_buser,
   input  logic                                               axi_bvalid,
   output logic                                               axi_bready,
   input  logic [PORT_CTRL_AXI4_RID_WIDTH-1:0]                axi_rid,
   input  logic [PORT_CTRL_AXI4_RDATA_WIDTH-1:0]              axi_rdata,
   input  logic [PORT_CTRL_AXI4_RRESP_WIDTH-1:0]              axi_rresp,
   input  logic [PORT_CTRL_AXI4_RUSER_WIDTH-1:0]              axi_ruser,
   input  logic                                               axi_rlast,
   input  logic                                               axi_rvalid,
   output logic                                               axi_rready,

   //Ports for "ctrl_user_priority" interface
   output logic                                               ctrl_user_priority_hi_0,

   //Ports for "ctrl_auto_precharge" interface
   output logic                                               ctrl_auto_precharge_req_0,

   //Ports for "ctrl_ecc_interrupt" interface
   input  logic                                               ctrl_ecc_user_interrupt_0,

   // Ports for "ctrl_ecc_readdataerror" interface
   input  logic                                               ctrl_ecc_readdataerror_0,

   //Ports for "ctrl_mmr" interface
   input  logic                                               mmr_master_waitrequest_0,
   output logic                                               mmr_master_read_0,
   output logic                                               mmr_master_write_0,
   output logic [PORT_CTRL_MMR_MASTER_ADDRESS_WIDTH-1:0]      mmr_master_address_0,
   input  logic [PORT_CTRL_MMR_MASTER_RDATA_WIDTH-1:0]        mmr_master_readdata_0,
   output logic [PORT_CTRL_MMR_MASTER_WDATA_WIDTH-1:0]        mmr_master_writedata_0,
   output logic [PORT_CTRL_MMR_MASTER_BCOUNT_WIDTH-1:0]       mmr_master_burstcount_0,
   output logic                                               mmr_master_beginbursttransfer_0,
   input  logic                                               mmr_master_readdatavalid_0,

   //Ports for "tg_cfg" interface
   output logic                                               tg_cfg_waitrequest,
   input  logic                                               tg_cfg_read,
   input  logic                                               tg_cfg_write,
   input  logic [PORT_TG_CFG_ADDRESS_WIDTH-1:0]               tg_cfg_address,
   output logic [PORT_TG_CFG_RDATA_WIDTH-1:0]                 tg_cfg_readdata,
   input  logic [PORT_TG_CFG_WDATA_WIDTH-1:0]                 tg_cfg_writedata,
   output logic                                               tg_cfg_readdatavalid,

   //Ports for "tg_status" interfaces
   output logic                                               traffic_gen_pass,
   output logic                                               traffic_gen_fail,
   output logic                                               traffic_gen_timeout

);
   timeunit 1ns;
   timeprecision 1ps;

   localparam MAX_CTRL_PORTS = 1;

   logic [MAX_CTRL_PORTS-1:0]                                   amm_ready_all;
   logic [MAX_CTRL_PORTS-1:0]                                   amm_readdatavalid_all;

   logic [MAX_CTRL_PORTS-1:0][PORT_TG_CFG_ADDRESS_WIDTH-1:0]    tg_cfg_address_all;
   logic [MAX_CTRL_PORTS-1:0][PORT_TG_CFG_WDATA_WIDTH-1:0]      tg_cfg_writedata_all;
   logic [MAX_CTRL_PORTS-1:0][PORT_TG_CFG_RDATA_WIDTH-1:0]      tg_cfg_readdata_all;
   logic [MAX_CTRL_PORTS-1:0]                                   tg_cfg_readdatavalid_all;
   logic [MAX_CTRL_PORTS-1:0]                                   tg_cfg_write_all;
   logic [MAX_CTRL_PORTS-1:0]                                   tg_cfg_read_all;
   logic [MAX_CTRL_PORTS-1:0]                                   tg_cfg_waitrequest_all;

   logic                                                        csr_test_pass;
   logic                                                        csr_test_fail;
   logic                                                        csr_test_timeout;
   logic [MAX_CTRL_PORTS-1:0]                                   traffic_gen_pass_all;
   logic [MAX_CTRL_PORTS-1:0]                                   traffic_gen_fail_all;
   logic [MAX_CTRL_PORTS-1:0]                                   traffic_gen_timeout_all;
   logic [MAX_CTRL_PORTS-1:0]                                   incr_timeout_all;

   logic [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_WDATA_WIDTH-1:0]    pnf_per_bit_persist;

   logic                                                        issp_worm_en;
   logic [2:0]                                                  worm_en;

   logic reset_n_int;
   (* altera_attribute = {"-name MAX_FANOUT 100; -name ADV_NETLIST_OPT_ALLOWED ALWAYS_ALLOW"}*) logic reset;

   assign amm_ready_all         = '1;
   assign amm_readdatavalid_all = '0;

   assign  traffic_gen_pass    = &(traffic_gen_pass_all)    & csr_test_pass;
   assign  traffic_gen_fail    = |(traffic_gen_fail_all)    | csr_test_fail;
   assign  traffic_gen_timeout = |(traffic_gen_timeout_all) | csr_test_timeout;


   localparam NUMBER_OF_DATA_GENERATORS    = MEM_TTL_DATA_WIDTH / MEM_TTL_NUM_OF_WRITE_GROUPS;   // = (num DQ pins) / (DQS group)
   localparam NUMBER_OF_BYTE_EN_GENERATORS = (USE_AVL_BYTEEN == 0)?          1 :
                                             (CTRL_INTERFACE_TYPE == "AVL")? PORT_CTRL_AMM_BYTEEN_WIDTH / AVL_TO_DQ_WIDTH_RATIO :
                                                                             PORT_CTRL_AXI4_WSTRB_WIDTH / AVL_TO_DQ_WIDTH_RATIO;

   localparam TOTAL_OP_COUNT_WIDTH     = RW_LOOP_COUNT_WIDTH + RW_OPERATION_COUNT_WIDTH + RW_RPT_COUNT_WIDTH;

   localparam GENERIC_RDATA_WIDTH         =  (CTRL_INTERFACE_TYPE == "AVL")? PORT_CTRL_AMM_RDATA_WIDTH :   PORT_CTRL_AXI4_RDATA_WIDTH;
   localparam GENERIC_ADDRESS_WIDTH       =  (CTRL_INTERFACE_TYPE == "AVL")? PORT_CTRL_AMM_ADDRESS_WIDTH : PORT_CTRL_AXI4_ARADDR_WIDTH;
   localparam GENERIC_WDATA_WIDTH         =  (CTRL_INTERFACE_TYPE == "AVL")? PORT_CTRL_AMM_WDATA_WIDTH :   PORT_CTRL_AXI4_WDATA_WIDTH;
   localparam GENERIC_BCOUNT_WIDTH        =  (CTRL_INTERFACE_TYPE == "AVL")? PORT_CTRL_AMM_BCOUNT_WIDTH :  PORT_CTRL_AXI4_ARLEN_WIDTH;
   localparam GENERIC_BYTEEN_WIDTH        =  (CTRL_INTERFACE_TYPE == "AVL")? PORT_CTRL_AMM_BYTEEN_WIDTH :  PORT_CTRL_AXI4_WSTRB_WIDTH;

   localparam IS_AXI                      =  (CTRL_INTERFACE_TYPE == "AVL")? 0                          :  1;
   wire [MAX_CTRL_PORTS-1:0][PORT_TG_CFG_ADDRESS_WIDTH-1:0]  amm_cfg_address;
   wire [MAX_CTRL_PORTS-1:0][PORT_TG_CFG_WDATA_WIDTH-1:0]    amm_cfg_writedata;
   wire [MAX_CTRL_PORTS-1:0][PORT_TG_CFG_RDATA_WIDTH-1:0]    amm_cfg_readdata;
   wire [MAX_CTRL_PORTS-1:0]                                 amm_cfg_readdatavalid;
   wire [MAX_CTRL_PORTS-1:0]                                 amm_cfg_write;
   wire [MAX_CTRL_PORTS-1:0]                                 amm_cfg_read;
   wire [MAX_CTRL_PORTS-1:0]                                 amm_cfg_wait_req;

   wire [MAX_CTRL_PORTS-1:0][AMM_WORD_ADDRESS_WIDTH-1:0]     ast_exp_data_readaddr;
   wire [MAX_CTRL_PORTS-1:0][GENERIC_WDATA_WIDTH-1:0]        ast_exp_data_writedata;
   wire [MAX_CTRL_PORTS-1:0][GENERIC_BYTEEN_WIDTH-1:0]       ast_exp_data_byteenable;

   wire [MAX_CTRL_PORTS-1:0]                                 ast_act_data_readdatavalid;
   wire [MAX_CTRL_PORTS-1:0][GENERIC_WDATA_WIDTH-1:0]        ast_act_data_readdata;

   wire [MAX_CTRL_PORTS-1:0][TG_CLEAR_WIDTH-1:0]             tg_clear;
   wire [MAX_CTRL_PORTS-1:0]                                 at_byteenable_stage;

   wire [MAX_CTRL_PORTS-1:0][GENERIC_RDATA_WIDTH-1:0]        before_ff_expected_data;
   wire [MAX_CTRL_PORTS-1:0][GENERIC_RDATA_WIDTH-1:0]        before_ff_read_data;
   wire [MAX_CTRL_PORTS-1:0]                                 before_ff_rdata_valid;
   wire [MAX_CTRL_PORTS-1:0][GENERIC_RDATA_WIDTH-1:0]        after_ff_expected_data;
   wire [MAX_CTRL_PORTS-1:0][GENERIC_RDATA_WIDTH-1:0]        after_ff_read_data;
   wire [MAX_CTRL_PORTS-1:0]                                 after_ff_rdata_valid;
   wire [MAX_CTRL_PORTS-1:0][TOTAL_OP_COUNT_WIDTH-1:0]       failure_count;
   wire [MAX_CTRL_PORTS-1:0][GENERIC_RDATA_WIDTH-1:0]        first_fail_expected_data;
   wire [MAX_CTRL_PORTS-1:0][GENERIC_RDATA_WIDTH-1:0]        first_fail_read_data;
   wire [MAX_CTRL_PORTS-1:0][GENERIC_RDATA_WIDTH-1:0]        first_fail_pnf;
   wire [MAX_CTRL_PORTS-1:0]                                 first_failure_occured;
   wire [MAX_CTRL_PORTS-1:0][GENERIC_RDATA_WIDTH-1:0]        last_read_data;
   wire [MAX_CTRL_PORTS-1:0][TOTAL_OP_COUNT_WIDTH-1:0]       total_read_count;

   //asserted when driver control block writes start to r/w gen
   wire [MAX_CTRL_PORTS-1:0]                                user_cfg_start;
   wire [MAX_CTRL_PORTS-1:0]                                at_wait_user_stage;
   wire [MAX_CTRL_PORTS-1:0]                                at_done_stage;
   wire [MAX_CTRL_PORTS-1:0]                                at_default_stage;
   wire [MAX_CTRL_PORTS-1:0]                                test_in_prog;
   wire [MAX_CTRL_PORTS-1:0]                                restart_default_traffic;
   wire [MAX_CTRL_PORTS-1:0]                                rst_config;
   wire [MAX_CTRL_PORTS-1:0]                                inf_user_mode;
   wire [MAX_CTRL_PORTS-1:0]                                inf_user_mode_status_en;
   wire [MAX_CTRL_PORTS-1:0]                                tg_test_complete;
   wire [MAX_CTRL_PORTS-1:0][AMM_WORD_ADDRESS_WIDTH-1:0]    first_fail_addr;
   wire [MAX_CTRL_PORTS-1:0]                                at_target_stage;
   wire [MAX_CTRL_PORTS-1:0]                                target_first_failing_addr;

   if (DIAG_EXPORT_TG_CFG_AVALON_SLAVE == "TG_CFG_AMM_EXPORT_MODE_EXPORT") begin
      // TG_CFG_AMM_EXPORT_MODE_EXPORT --> Connect signals to tg_cfg port
      assign tg_cfg_write_all      =         tg_cfg_write;
      assign tg_cfg_read_all       =  tg_cfg_read;
      assign tg_cfg_address_all    =   tg_cfg_address;
      assign tg_cfg_writedata_all  =  tg_cfg_writedata;
      assign tg_cfg_readdatavalid = tg_cfg_readdatavalid_all;
      assign tg_cfg_readdata = tg_cfg_readdata_all;
      assign tg_cfg_waitrequest = tg_cfg_waitrequest_all;
   end
   else begin
      assign tg_cfg_waitrequest = '0;
      assign tg_cfg_readdata = '0;
      assign tg_cfg_readdatavalid = '0;
   end

   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_AWID_WIDTH-1:0]     axi_awid_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_AWADDR_WIDTH-1:0]   axi_awaddr_w;
   wire [MAX_CTRL_PORTS-1:0]                                    axi_awvalid_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_AWUSER_WIDTH-1:0]   axi_awuser_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_AWLEN_WIDTH-1:0]    axi_awlen_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_AWSIZE_WIDTH-1:0]   axi_awsize_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_AWBURST_WIDTH-1:0]  axi_awburst_w;
   wire [MAX_CTRL_PORTS-1:0]                                    axi_awready_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_AWPROT_WIDTH-1:0]   axi_awprot_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_AWCACHE_WIDTH-1:0]  axi_awcache_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_AWLOCK_WIDTH-1:0]   axi_awlock_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_ARID_WIDTH-1:0]     axi_arid_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_ARADDR_WIDTH-1:0]   axi_araddr_w;
   wire [MAX_CTRL_PORTS-1:0]                                    axi_arvalid_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_ARUSER_WIDTH-1:0]   axi_aruser_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_ARLEN_WIDTH-1:0]    axi_arlen_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_ARSIZE_WIDTH-1:0]   axi_arsize_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_ARBURST_WIDTH-1:0]  axi_arburst_w;
   wire [MAX_CTRL_PORTS-1:0]                                    axi_arready_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_ARPROT_WIDTH-1:0]   axi_arprot_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_ARCACHE_WIDTH-1:0]  axi_arcache_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_ARLOCK_WIDTH-1:0]   axi_arlock_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_WDATA_WIDTH-1:0]    axi_wdata_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_WSTRB_WIDTH-1:0]    axi_wstrb_w;
   wire [MAX_CTRL_PORTS-1:0]                                    axi_wlast_w;
   wire [MAX_CTRL_PORTS-1:0]                                    axi_wvalid_w;
   wire [MAX_CTRL_PORTS-1:0]                                    axi_wready_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_BID_WIDTH-1:0]      axi_bid_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_BRESP_WIDTH-1:0]    axi_bresp_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_BUSER_WIDTH-1:0]    axi_buser_w;
   wire [MAX_CTRL_PORTS-1:0]                                    axi_bvalid_w;
   wire [MAX_CTRL_PORTS-1:0]                                    axi_bready_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_RID_WIDTH-1:0]      axi_rid_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_RDATA_WIDTH-1:0]    axi_rdata_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_RRESP_WIDTH-1:0]    axi_rresp_w;
   wire [MAX_CTRL_PORTS-1:0][PORT_CTRL_AXI4_RUSER_WIDTH-1:0]    axi_ruser_w;
   wire [MAX_CTRL_PORTS-1:0]                                    axi_rlast_w;
   wire [MAX_CTRL_PORTS-1:0]                                    axi_rvalid_w;
   wire [MAX_CTRL_PORTS-1:0]                                    axi_rready_w;

   generate
   if (NUM_OF_CTRL_PORTS == 1) begin : gen_axi_ctrl1
      assign axi_awid = axi_awid_w[0];
      assign axi_awaddr = axi_awaddr_w[0];
      assign axi_awvalid = axi_awvalid_w[0];
      assign axi_awuser = axi_awuser_w[0];
      assign axi_awlen = axi_awlen_w[0];
      assign axi_awsize = axi_awsize_w[0];
      assign axi_awburst = axi_awburst_w[0];
      assign axi_awready_w[0] = axi_awready;
      assign axi_awprot = axi_awprot_w[0];
      assign axi_awcache = axi_awcache_w[0];
      assign axi_awlock = axi_awlock_w[0];
      assign axi_arid = axi_arid_w[0];
      assign axi_araddr = axi_araddr_w[0];
      assign axi_arvalid = axi_arvalid_w[0];
      assign axi_aruser = axi_aruser_w[0];
      assign axi_arlen = axi_arlen_w[0];
      assign axi_arsize = axi_arsize_w[0];
      assign axi_arburst = axi_arburst_w[0];
      assign axi_arready_w[0] = axi_arready;
      assign axi_arprot = axi_arprot_w[0];
      assign axi_arcache = axi_arcache_w[0];
      assign axi_arlock = axi_arlock_w[0];
      assign axi_wdata = axi_wdata_w[0];
      assign axi_wstrb = axi_wstrb_w[0];
      assign axi_wlast = axi_wlast_w[0];
      assign axi_wvalid = axi_wvalid_w[0];
      assign axi_wready_w[0] = axi_wready;
      assign axi_bvalid_w[0] = axi_bvalid;
      assign axi_bready = axi_bready_w[0];
      assign axi_rvalid_w[0] = axi_rvalid;
      assign axi_rready = axi_rready_w[0];
   end 
   else if (NUM_OF_CTRL_PORTS > 1) begin : gen_axi_ctrl_gt1
      reg active_mstr_write; 
      reg active_mstr_read;
      wire active_aw;

      reg [3:0] delayed_wdata;  
      reg [3:0] starve_count;
      wire incr_delayed_data;
      wire decr_delayed_data;
      assign incr_delayed_data = (axi_awvalid_w [active_mstr_write] && axi_awready_w[active_mstr_write]);
      assign decr_delayed_data = (axi_wvalid_w [active_mstr_write] && axi_wready_w[active_mstr_write]);
      assign active_aw = starve_count != 4'b0100;  


      always_ff @(posedge emif_usr_clk)
      begin
      if (reset) begin
            active_mstr_write <= '0;
            starve_count <= '0;
      end else if ((delayed_wdata == 4'b0000 && ~incr_delayed_data) || (delayed_wdata == 4'b0001 && decr_delayed_data && ~incr_delayed_data)) begin
            active_mstr_write <= ~active_mstr_write;
            starve_count <= '0;
      end else if (starve_count != 4'b0100) begin
            starve_count <= starve_count + 1;
      end
      end
      always_ff @(posedge emif_usr_clk)
      begin
      if (reset) begin
              delayed_wdata <= '0;
      end else if (incr_delayed_data && decr_delayed_data) begin
              delayed_wdata <= delayed_wdata;
      end else if (incr_delayed_data) begin
              delayed_wdata <= delayed_wdata+1;
      end else if (decr_delayed_data) begin
              delayed_wdata <= delayed_wdata-1;
      end
      end

      always_ff @(posedge emif_usr_clk)
      begin
         if (reset) begin
            active_mstr_read <= '0;
         end else begin
            active_mstr_read <= ~active_mstr_read;
         end
      end

      assign axi_awid = {PORT_CTRL_AXI4_AWID_WIDTH{1'b0}} | active_mstr_write;

      assign axi_awaddr =
                 {axi_awaddr_w[active_mstr_write][PORT_CTRL_AXI4_AWADDR_WIDTH-1:AMM_WORD_ADDRESS_WIDTH+1],
                   active_mstr_write,
                   axi_awaddr_w[active_mstr_write][AMM_WORD_ADDRESS_WIDTH-1:0]};

      assign axi_awvalid = active_aw && axi_awvalid_w[active_mstr_write];
      assign axi_awuser = axi_awuser_w[active_mstr_write];
      assign axi_awlen = axi_awlen_w[active_mstr_write];
      assign axi_awsize = axi_awsize_w[active_mstr_write];
      assign axi_awburst = axi_awburst_w[active_mstr_write];

      assign axi_awready_w[0] = (active_mstr_write == 1'b0 && active_aw)? axi_awready:1'b0;
      assign axi_awready_w[1] = (active_mstr_write == 1'b1 && active_aw)? axi_awready:1'b0;

      assign axi_awprot = axi_awprot_w[active_mstr_write];
      assign axi_awcache = axi_awcache_w[active_mstr_write];
      assign axi_awlock = axi_awlock_w[active_mstr_write];
      assign axi_arid = {PORT_CTRL_AXI4_AWID_WIDTH{1'b0}} | active_mstr_read;

      assign axi_araddr =
                 {axi_araddr_w[active_mstr_read][PORT_CTRL_AXI4_ARADDR_WIDTH-1:AMM_WORD_ADDRESS_WIDTH+1],
                   active_mstr_read,
                   axi_araddr_w[active_mstr_read][AMM_WORD_ADDRESS_WIDTH-1:0]};

      assign axi_arvalid = axi_arvalid_w[active_mstr_read];
      assign axi_aruser = axi_aruser_w[active_mstr_read];
      assign axi_arlen = axi_arlen_w[active_mstr_read];
      assign axi_arsize = axi_arsize_w[active_mstr_read];
      assign axi_arburst = axi_arburst_w[active_mstr_read];

      assign axi_arready_w[0] = (active_mstr_read == 1'b0)? axi_arready:1'b0;
      assign axi_arready_w[1] = (active_mstr_read == 1'b1)? axi_arready:1'b0;

      assign axi_arprot = axi_arprot_w[active_mstr_read];
      assign axi_arcache = axi_arcache_w[active_mstr_read];
      assign axi_arlock = axi_arlock_w[active_mstr_read];
      assign axi_wdata = axi_wdata_w[active_mstr_write];
      assign axi_wstrb = axi_wstrb_w[active_mstr_write];
      assign axi_wlast = axi_wlast_w[active_mstr_write];
      assign axi_wvalid = axi_wvalid_w[active_mstr_write];

      assign axi_wready_w[0] = (active_mstr_write == 1'b0)? axi_wready:1'b0;
      assign axi_wready_w[1] = (active_mstr_write == 1'b1)? axi_wready:1'b0;

      assign axi_bvalid_w[0] = (axi_bid == 1'b0)? axi_bvalid:1'b0;
      assign axi_bvalid_w[1] = (axi_bid == 1'b1)? axi_bvalid:1'b0;

      assign axi_bready = axi_bready_w[axi_bid];

      assign axi_rvalid_w[0] = (axi_rid == 1'b0)? axi_rvalid:1'b0;
      assign axi_rvalid_w[1] = (axi_rid == 1'b1)? axi_rvalid:1'b0;

      assign axi_rready = axi_rready_w[axi_rid];

   end 
   endgenerate

   assign axi_awprot_w[0] = '0;
   assign axi_arprot_w[0] = '0;
   assign axi_arcache_w[0][0] = '0;
   assign axi_awcache_w[0][0] = '0;
   assign axi_arcache_w[0][1] = '0;
   assign axi_awcache_w[0][1] = '0;
   assign axi_arcache_w[0][2] = '0;
   assign axi_awcache_w[0][2] = '0;
   assign axi_arcache_w[0][3] = '0;
   assign axi_awcache_w[0][3] = '0;
   assign axi_awlock_w[0] = '0;
   assign axi_arlock_w[0] = '0;

   genvar i;
   generate
   for (i = 0; i < MAX_CTRL_PORTS; ++i)
   begin: gen_avl_mm_driver
      if (i < NUM_OF_CTRL_PORTS) begin
            altera_emif_avl_tg_2_bringup_dcb #(
               .NUMBER_OF_DATA_GENERATORS    (NUMBER_OF_DATA_GENERATORS),
               .USE_AVL_BYTEEN               (USE_AVL_BYTEEN),
               .NUMBER_OF_BYTE_EN_GENERATORS (NUMBER_OF_BYTE_EN_GENERATORS),
               .MEM_ADDR_WIDTH               (GENERIC_ADDRESS_WIDTH),
               .BURSTCOUNT_WIDTH             (GENERIC_BCOUNT_WIDTH),
               .TG_TEST_DURATION             (TEST_DURATION),
               .PORT_TG_CFG_ADDRESS_WIDTH    (PORT_TG_CFG_ADDRESS_WIDTH),
               .PORT_TG_CFG_RDATA_WIDTH      (PORT_TG_CFG_RDATA_WIDTH),
               .PORT_TG_CFG_WDATA_WIDTH      (PORT_TG_CFG_WDATA_WIDTH),
               .WRITE_GROUP_WIDTH            (MEM_TTL_DATA_WIDTH / MEM_TTL_NUM_OF_WRITE_GROUPS),
               .BYPASS_DEFAULT_PATTERN       (BYPASS_DEFAULT_PATTERN),
               .BYPASS_USER_STAGE            (BYPASS_USER_STAGE),
               .AMM_WORD_ADDRESS_WIDTH       (AMM_WORD_ADDRESS_WIDTH),
               .AMM_BURST_COUNT_DIVISIBLE_BY (AMM_BURST_COUNT_DIVISIBLE_BY),
               .IS_AXI                       (IS_AXI)
            ) bu_dcb_inst (
               .clk                             (emif_usr_clk),
               .rst                             (reset),
               //trigger the driver control block when calibration has passed and ready is high
               .amm_ctrl_ready                  (amm_ready_all[i]),
               .amm_cfg_slave_waitrequest       (tg_cfg_waitrequest_all[i]),
               .amm_cfg_slave_address           (tg_cfg_address_all[i]),
               .amm_cfg_slave_writedata         (tg_cfg_writedata_all[i]),
               .amm_cfg_slave_write             (tg_cfg_write_all[i]),
               .amm_cfg_slave_read              (tg_cfg_read_all[i]),
               .amm_cfg_slave_readdata          (tg_cfg_readdata_all[i]),
               .amm_cfg_slave_readdatavalid     (tg_cfg_readdatavalid_all[i]),

               //configuration interface to/from traffic generator
               .amm_cfg_master_waitrequest      (amm_cfg_wait_req[i]),
               .amm_cfg_master_address          (amm_cfg_address[i]),
               .amm_cfg_master_writedata        (amm_cfg_writedata[i]),
               .amm_cfg_master_write            (amm_cfg_write[i]),
               .amm_cfg_master_read             (amm_cfg_read[i]),
               .amm_cfg_master_readdata         (amm_cfg_readdata[i]),
               .amm_cfg_master_readdatavalid    (amm_cfg_readdatavalid[i]),
               .tg_test_complete                (tg_test_complete[i]),
               .restart_default_traffic         (restart_default_traffic[i]),
               .rst_config                      (rst_config[i]),
               .inf_user_mode                   (inf_user_mode[i]),
               //status checker related signals for special tests
               .at_done_stage                   (at_done_stage[i]),
               .at_wait_user_stage              (at_wait_user_stage[i]),
               .at_default_stage                (at_default_stage[i]),
               .first_fail_addr                 (first_fail_addr[i]),
               .failure_occured                 (first_failure_occured[i]),
               .target_first_failing_addr       (target_first_failing_addr[i]),
               .at_target_stage                 (at_target_stage[i]),
               .user_cfg_start                  (user_cfg_start[i])
            );

            if (DIAG_EXPORT_TG_CFG_AVALON_SLAVE == "TG_CFG_AMM_EXPORT_MODE_JTAG") begin
               // synthesis read_comments_as_HDL on
               // `define ENABLE_ADME_FOR_SYNTH
               // synthesis read_comments_as_HDL off
               `ifdef ENABLE_ADME_FOR_SYNTH
                  localparam DIAG_USE_ADME_FOR_SYNTH = 1;
               `else
                  localparam DIAG_USE_ADME_FOR_SYNTH = 0;
               `endif
               if (DIAG_USE_ADME_FOR_SYNTH == 1) begin
                  // TG_CFG_AMM_EXPORT_MODE_JTAG --> Instantiate ADME for configuration through system-console
                  localparam PADDING_BITS = 2;
                  logic [PORT_TG_CFG_ADDRESS_WIDTH+PADDING_BITS-1:0] adme_master_address;
                  assign tg_cfg_address_all[i] = adme_master_address[PORT_TG_CFG_ADDRESS_WIDTH-1:0];
                  altera_debug_master_endpoint #(
                      .ADDR_WIDTH     (PORT_TG_CFG_ADDRESS_WIDTH+PADDING_BITS),                                      
                      .DATA_WIDTH     (PORT_TG_CFG_WDATA_WIDTH),                                                     
                      .HAS_RDV        (1),                                                                           
                      .SLAVE_MAP      ("{typeName emif_avl_tg_2 address 0 span 4096 hpath {adme} assignments {}}"),
                      .PREFER_HOST    (""),                                                                          
                      .CLOCK_RATE_CLK (CORE_CLK_FREQ_HZ)                                                             
                  ) adme (
                      .clk                  (emif_usr_clk),                                    
                      .reset                (reset),                                           
                      .master_write         (tg_cfg_write_all[i]),                             
                      .master_read          (tg_cfg_read_all[i]),                              
                      .master_address       (adme_master_address),                             
                      .master_writedata     (tg_cfg_writedata_all[i]),                         
                      .master_waitrequest   (tg_cfg_waitrequest_all[i]),                       
                      .master_readdata      (tg_cfg_readdata_all[i]),                          
                      .master_readdatavalid (tg_cfg_readdatavalid_all[i])                      
                  );
               end

               else begin
                  // TG_CFG_AMM_EXPORT_MODE_JTAG --> Instantiate simultion module for user configured pattern
                  altera_emif_avl_tg_2_sim_master #(
                     .PORT_TG_CFG_ADDRESS_WIDTH(PORT_TG_CFG_ADDRESS_WIDTH),
                     .PORT_TG_CFG_WDATA_WIDTH(PORT_TG_CFG_WDATA_WIDTH),
                     .PORT_TG_CFG_RDATA_WIDTH(PORT_TG_CFG_RDATA_WIDTH)
                  ) tg2_sim_master (
                     .clk(emif_usr_clk),                                
                     .reset(reset),                                     
                     .master_write(tg_cfg_write_all[i]),                
                     .master_read(tg_cfg_read_all[i]),                  
                     .master_address(tg_cfg_address_all[i]),            
                     .master_writedata(tg_cfg_writedata_all[i]),        
                     .master_waitrequest(tg_cfg_waitrequest_all[i]),    
                     .master_readdata(tg_cfg_readdata_all[i]),          
                     .master_readdatavalid(tg_cfg_readdatavalid_all[i]),
                     .at_wait_user_stage(at_wait_user_stage[i])         
                  );
               end
            end

               altera_emif_avl_tg_2_traffic_gen #(
                  .NUMBER_OF_DATA_GENERATORS      (NUMBER_OF_DATA_GENERATORS),
                  .NUMBER_OF_BYTE_EN_GENERATORS   (NUMBER_OF_BYTE_EN_GENERATORS),
                  .AMM_CFG_ADDR_WIDTH             (PORT_TG_CFG_ADDRESS_WIDTH),
                  .AMM_CFG_DATA_WIDTH             (PORT_TG_CFG_WDATA_WIDTH),
                  .DATA_RATE_WIDTH_RATIO          (AVL_TO_DQ_WIDTH_RATIO),
                  .OP_COUNT_WIDTH                 (TOTAL_OP_COUNT_WIDTH),
                  .RW_RPT_COUNT_WIDTH             (RW_RPT_COUNT_WIDTH),
                  .RW_OPERATION_COUNT_WIDTH       (RW_OPERATION_COUNT_WIDTH),
                  .RW_LOOP_COUNT_WIDTH            (RW_LOOP_COUNT_WIDTH),
                  .MEM_ADDR_WIDTH                 (GENERIC_ADDRESS_WIDTH), //memory address width
                  .AMM_BURSTCOUNT_WIDTH           (GENERIC_BCOUNT_WIDTH),
                  .PORT_CTRL_AMM_WDATA_WIDTH      (GENERIC_WDATA_WIDTH),
                  .PORT_CTRL_AMM_RDATA_WIDTH      (GENERIC_RDATA_WIDTH),
                  .MEM_TTL_DATA_WIDTH             (MEM_TTL_DATA_WIDTH),
                  .MEM_TTL_NUM_OF_WRITE_GROUPS    (MEM_TTL_NUM_OF_WRITE_GROUPS),
                  .MEM_BE_WIDTH                   (GENERIC_BYTEEN_WIDTH),
                  .AMM_WORD_ADDRESS_WIDTH         (AMM_WORD_ADDRESS_WIDTH),
                  .USE_AVL_BYTEEN                 (USE_AVL_BYTEEN),
                  .AMM_WORD_ADDRESS_DIVISIBLE_BY  (AMM_WORD_ADDRESS_DIVISIBLE_BY),
                  .AMM_BURST_COUNT_DIVISIBLE_BY   (AMM_BURST_COUNT_DIVISIBLE_BY),
                  .TG_CLEAR_WIDTH                 (TG_CLEAR_WIDTH),
                  .COMPARE_ADDR_GEN_FIFO_WIDTH    (COMPARE_ADDR_GEN_FIFO_WIDTH),
                  .TG_ENABLE_UNIX_ID              (PROTOCOL_ENUM == "PROTOCOL_QDR4" || USE_UNIQUE_ADDR_PER_TG_INST),
                  .TG_USE_UNIX_ID                 (USE_UNIQUE_ADDR_PER_TG_INST ? TG_INST_UNIQUE_ID : i),
                  .NUM_RESPONDERS                 (NUM_OF_AXI_SWITCH_RESPONDERS),
                  .CTRL_BRIDGE_EN                 (CTRL_BRIDGE_EN),
                  .CTRL_INTERFACE_TYPE            (CTRL_INTERFACE_TYPE),
                  .PORT_CTRL_AXI4_AWID_WIDTH      (PORT_CTRL_AXI4_AWID_WIDTH),
                  .PORT_CTRL_AXI4_AWADDR_WIDTH    (PORT_CTRL_AXI4_AWADDR_WIDTH),
                  .PORT_CTRL_AXI4_AWUSER_WIDTH    (PORT_CTRL_AXI4_AWUSER_WIDTH),
                  .PORT_CTRL_AXI4_AWLEN_WIDTH     (PORT_CTRL_AXI4_AWLEN_WIDTH),
                  .PORT_CTRL_AXI4_AWSIZE_WIDTH    (PORT_CTRL_AXI4_AWSIZE_WIDTH),
                  .PORT_CTRL_AXI4_AWBURST_WIDTH   (PORT_CTRL_AXI4_AWBURST_WIDTH),
                  .PORT_CTRL_AXI4_AWLOCK_WIDTH    (PORT_CTRL_AXI4_AWLOCK_WIDTH),
                  .PORT_CTRL_AXI4_AWCACHE_WIDTH   (PORT_CTRL_AXI4_AWCACHE_WIDTH),
                  .PORT_CTRL_AXI4_AWPROT_WIDTH    (PORT_CTRL_AXI4_AWPROT_WIDTH),
                  .PORT_CTRL_AXI4_ARID_WIDTH      (PORT_CTRL_AXI4_ARID_WIDTH),
                  .PORT_CTRL_AXI4_ARADDR_WIDTH    (PORT_CTRL_AXI4_ARADDR_WIDTH),
                  .PORT_CTRL_AXI4_ARUSER_WIDTH    (PORT_CTRL_AXI4_ARUSER_WIDTH),
                  .PORT_CTRL_AXI4_ARLEN_WIDTH     (PORT_CTRL_AXI4_ARLEN_WIDTH),
                  .PORT_CTRL_AXI4_ARSIZE_WIDTH    (PORT_CTRL_AXI4_ARSIZE_WIDTH),
                  .PORT_CTRL_AXI4_ARBURST_WIDTH   (PORT_CTRL_AXI4_ARBURST_WIDTH),
                  .PORT_CTRL_AXI4_ARLOCK_WIDTH    (PORT_CTRL_AXI4_ARLOCK_WIDTH),
                  .PORT_CTRL_AXI4_ARCACHE_WIDTH   (PORT_CTRL_AXI4_ARCACHE_WIDTH),
                  .PORT_CTRL_AXI4_ARPROT_WIDTH    (PORT_CTRL_AXI4_ARPROT_WIDTH),
                  .PORT_CTRL_AXI4_WDATA_WIDTH     (PORT_CTRL_AXI4_WDATA_WIDTH),
                  .PORT_CTRL_AXI4_WSTRB_WIDTH     (PORT_CTRL_AXI4_WSTRB_WIDTH),
                  .PORT_CTRL_AXI4_BID_WIDTH       (PORT_CTRL_AXI4_BID_WIDTH),
                  .PORT_CTRL_AXI4_BRESP_WIDTH     (PORT_CTRL_AXI4_BRESP_WIDTH),
                  .PORT_CTRL_AXI4_BUSER_WIDTH     (PORT_CTRL_AXI4_BUSER_WIDTH),
                  .PORT_CTRL_AXI4_RID_WIDTH       (PORT_CTRL_AXI4_RID_WIDTH),
                  .PORT_CTRL_AXI4_RDATA_WIDTH     (PORT_CTRL_AXI4_RDATA_WIDTH),
                  .PORT_CTRL_AXI4_RRESP_WIDTH     (PORT_CTRL_AXI4_RRESP_WIDTH),
                  .PORT_CTRL_AXI4_RUSER_WIDTH     (PORT_CTRL_AXI4_RUSER_WIDTH)
               ) traffic_gen_inst (
                  .clk                          (emif_usr_clk),
                  .rst                          (reset),
                  .rst_config                   (rst_config[i]),
                  .tg_test_complete             (tg_test_complete[i]),
                  .inf_user_mode                (inf_user_mode[i]),
                  .inf_user_mode_status_en      (inf_user_mode_status_en[i]),
                  .at_target_stage              (at_target_stage[i]),

                  //to avalon memory controller
                  .amm_ctrl_write               (),
                  .amm_ctrl_read                (),
                  .amm_ctrl_address             (),
                  .amm_ctrl_writedata           (),
                  .amm_ctrl_byteenable          (),
                  .amm_ctrl_ready               (amm_ready_all[i]),
                  .amm_ctrl_burstcount          (),
                  .amm_ctrl_readdatavalid       (amm_readdatavalid_all[i]),
                  .amm_ctrl_readdata            ('0),

                  //Expected data for comparison in status checker
                  .ast_exp_data_byteenable      (ast_exp_data_byteenable[i]),
                  .ast_exp_data_writedata       (ast_exp_data_writedata[i]),
                  .ast_exp_data_readaddr        (ast_exp_data_readaddr[i]),

                  //Actual data for comparison in status checker
                  .ast_act_data_readdatavalid   (ast_act_data_readdatavalid[i]),
                  .ast_act_data_readdata        (ast_act_data_readdata[i]),

                  //configuration interface to/from driver config block
                  .amm_cfg_address              (amm_cfg_address[i]),
                  .amm_cfg_writedata            (amm_cfg_writedata[i]),
                  .amm_cfg_readdata             (amm_cfg_readdata[i]),
                  .amm_cfg_readdatavalid        (amm_cfg_readdatavalid[i]),
                  .amm_cfg_write                (amm_cfg_write[i]),
                  .amm_cfg_read                 (amm_cfg_read[i]),
                  .amm_cfg_waitrequest          (amm_cfg_wait_req[i]),
                  .axi_awid                     (axi_awid_w[i]),
                  .axi_awaddr                   (axi_awaddr_w[i]),
                  .axi_awvalid                  (axi_awvalid_w[i]),
                  .axi_awuser                   (axi_awuser_w[i]),
                  .axi_awlen                    (axi_awlen_w[i]),
                  .axi_awsize                   (axi_awsize_w[i]),
                  .axi_awburst                  (axi_awburst_w[i]),
                  .axi_awready                  (axi_awready_w[i]),
                  .axi_wdata                    (axi_wdata_w[i]),
                  .axi_wstrb                    (axi_wstrb_w[i]),   
                  .axi_wlast                    (axi_wlast_w[i]),   
                  .axi_wvalid                   (axi_wvalid_w[i]),
                  .axi_wready                   (axi_wready_w[i]),
                  .axi_bid                      (axi_bid),
                  .axi_bresp                    (axi_bresp),
                  .axi_buser                    (axi_buser),
                  .axi_bvalid                   (axi_bvalid_w[i]),
                  .axi_bready                   (axi_bready_w[i]),
                  .axi_arid                     (axi_arid_w[i]),
                  .axi_araddr                   (axi_araddr_w[i]),
                  .axi_arvalid                  (axi_arvalid_w[i]),
                  .axi_aruser                   (axi_aruser_w[i]),
                  .axi_arlen                    (axi_arlen_w[i]),
                  .axi_arsize                   (axi_arsize_w[i]),
                  .axi_arburst                  (axi_arburst_w[i]),
                  .axi_arready                  (axi_arready_w[i]),
                  .axi_rid                      (axi_rid),
                  .axi_rdata                    (axi_rdata),
                  .axi_rresp                    (axi_rresp),
                  .axi_ruser                    (axi_ruser),
                  .axi_rlast                    (axi_rlast),
                  .axi_rvalid                   (axi_rvalid_w[i]),
                  .axi_rready                   (axi_rready_w[i]),

                  //status report
                  .tg_clear                     (tg_clear[i]),
                  .pnf_per_bit_persist          (pnf_per_bit_persist[i]),
                  .fail                         (traffic_gen_fail_all[i]),
                  .pass                         (traffic_gen_pass_all[i]),
                  .timeout                      (traffic_gen_timeout_all[i]),
                  .first_fail_addr              ({{(64-AMM_WORD_ADDRESS_WIDTH){1'b0}}, first_fail_addr[i]}),
                  .failure_count                ({{(64-TOTAL_OP_COUNT_WIDTH){1'b0}}, failure_count[i]}),
                  .total_read_count             ({{(64-TOTAL_OP_COUNT_WIDTH){1'b0}}, total_read_count[i]}),
                  .first_fail_expected_data     (first_fail_expected_data[i]),
                  .first_fail_read_data         (first_fail_read_data[i]),
                  .first_failure_occured        (first_failure_occured[i]),
                  //extra signals used by the status checker
                  .test_in_prog                (test_in_prog[i]),
                  .target_first_failing_addr    (target_first_failing_addr[i]),
                  .restart_default_traffic      (restart_default_traffic[i]),
                  .worm_en                      (worm_en[2]),
                  .tg_test_byteen               (at_byteenable_stage[i]),
                  .incr_timeout                 (incr_timeout_all[i])
               );

            altera_emif_avl_tg_2_status_checker # (
               .DATA_WIDTH                 (GENERIC_RDATA_WIDTH),
               .BE_WIDTH                   (GENERIC_BYTEEN_WIDTH),
               .ADDR_WIDTH                 (AMM_WORD_ADDRESS_WIDTH),
               .OP_COUNT_WIDTH             (TOTAL_OP_COUNT_WIDTH),
               .TEST_DURATION              (TEST_DURATION),
               .TG_CLEAR_WIDTH             (TG_CLEAR_WIDTH),
               .TG_TIMEOUT_WIDTH           (TG_TIMEOUT_WIDTH),
               .DISABLE_STATUS_CHECKER     (DISABLE_STATUS_CHECKER)
            ) status_checker_inst (
               .clk                        (emif_usr_clk),
               .rst                        (reset),
               .tg_restart                 (restart_default_traffic[i]|(~at_default_stage[i] & user_cfg_start[i])), 
               .enable                     (1'b1),

               .ast_exp_data_writedata     (ast_exp_data_writedata[i]),
               .ast_exp_data_byteenable    (ast_exp_data_byteenable[i]),
               .ast_exp_data_readaddr      (ast_exp_data_readaddr[i]),

               .ast_act_data_readdatavalid (ast_act_data_readdatavalid[i]),
               .ast_act_data_readdata      (ast_act_data_readdata[i]),

               .tg_clear                  (tg_clear[i]),
               .pnf_per_bit_persist       (pnf_per_bit_persist[i]),
               .fail                      (traffic_gen_fail_all[i]),
               .pass                      (traffic_gen_pass_all[i]),
               .first_fail_addr           (first_fail_addr[i]),
               .failure_count             (failure_count[i]),
               .first_fail_expected_data  (first_fail_expected_data[i]),
               .first_fail_read_data      (first_fail_read_data[i]),
               .first_fail_pnf            (first_fail_pnf[i]),
               .first_failure_occured     (first_failure_occured[i]),
               .before_ff_expected_data   (before_ff_expected_data[i]),
               .before_ff_read_data       (before_ff_read_data[i]),
               .after_ff_expected_data    (after_ff_expected_data[i]),
               .after_ff_read_data        (after_ff_read_data[i]),

               .before_ff_rdata_valid     (before_ff_rdata_valid[i]),
               .after_ff_rdata_valid      (after_ff_rdata_valid[i]),

               .last_read_data            (last_read_data[i]),
               .total_read_count          (total_read_count[i]),

               .all_tests_issued          ((at_wait_user_stage[i]&&!BYPASS_DEFAULT_PATTERN)|(at_done_stage[i])),
               .at_byteenable_stage       (at_byteenable_stage[i]),
               .inf_user_mode_status_en   (inf_user_mode_status_en[i]),
               .test_in_prog             (test_in_prog[i]),
               .timeout                   (traffic_gen_timeout_all[i]),
               .incr_timeout              (incr_timeout_all[i])
            );

      end else begin

         assign tg_cfg_waitrequest_all[i]       = '0;
         assign tg_cfg_readdata_all[i]          = '0;
         assign tg_cfg_readdatavalid_all[i]     = '0;

         // unused status signals
         assign traffic_gen_fail_all[i]         = '0;
         assign traffic_gen_pass_all[i]         = '1;
         assign traffic_gen_timeout_all[i]      = '0;
         assign pnf_per_bit_persist[i]          = '0;
         assign before_ff_expected_data[i]      = '0;
         assign before_ff_read_data[i]          = '0;
         assign before_ff_rdata_valid[i]        = '0;
         assign after_ff_expected_data[i]       = '0;
         assign after_ff_read_data[i]           = '0;
         assign after_ff_rdata_valid[i]         = '0;
         assign failure_count[i]                = '0;
         assign first_fail_expected_data[i]     = '0;
         assign first_fail_read_data[i]         = '0;
         assign first_fail_pnf[i]               = '0;
         assign first_failure_occured[i]        = '0;
         assign last_read_data[i]               = '0;
         assign total_read_count[i]             = '0;
         assign first_fail_addr[i]              = '0;
     end
   end
   endgenerate

   // Instantiate AXI-Lite driver irrespective of whether AXI drivers
   // exist. HWTCL can choose whether AXI drivers and AXI-Lite drivers
   // are allowed to co-exist.
   generate
      if (TEST_CSR) begin: gen_axilite_driver
         altera_emif_avl_tg_2_csr_driver # (
            .PORT_AWADDR_WIDTH   (PORT_SUBSYSTEM_CSR_AXI4L_AWADDR_WIDTH),
            .PORT_AWPROT_WIDTH   (PORT_SUBSYSTEM_CSR_AXI4L_AWPROT_WIDTH),
            .PORT_ARADDR_WIDTH   (PORT_SUBSYSTEM_CSR_AXI4L_ARADDR_WIDTH),
            .PORT_ARPROT_WIDTH   (PORT_SUBSYSTEM_CSR_AXI4L_ARPROT_WIDTH),
            .PORT_WDATA_WIDTH    (PORT_SUBSYSTEM_CSR_AXI4L_WDATA_WIDTH),
            .PORT_WSTRB_WIDTH    (PORT_SUBSYSTEM_CSR_AXI4L_WSTRB_WIDTH),
            .PORT_BRESP_WIDTH    (PORT_SUBSYSTEM_CSR_AXI4L_BRESP_WIDTH),
            .PORT_RDATA_WIDTH    (PORT_SUBSYSTEM_CSR_AXI4L_RDATA_WIDTH),
            .PORT_RRESP_WIDTH    (PORT_SUBSYSTEM_CSR_AXI4L_RRESP_WIDTH)
         ) csr_driver_inst (
            .clk        (emif_usr_clk),
            .rst        (reset),

            .pass       (csr_test_pass),
            .fail       (csr_test_fail),
            .timeout    (csr_test_timeout),

            .awaddr     (ss_base_csr_axi4l_awaddr),
            .awvalid    (ss_base_csr_axi4l_awvalid),
            .awready    (ss_base_csr_axi4l_awready),
            .awprot     (ss_base_csr_axi4l_awprot),
            .araddr     (ss_base_csr_axi4l_araddr),
            .arvalid    (ss_base_csr_axi4l_arvalid),
            .arready    (ss_base_csr_axi4l_arready),
            .arprot     (ss_base_csr_axi4l_arprot),
            .wdata      (ss_base_csr_axi4l_wdata),
            .wvalid     (ss_base_csr_axi4l_wvalid),
            .wready     (ss_base_csr_axi4l_wready),
            .wstrb      (ss_base_csr_axi4l_wstrb),
            .bresp      (ss_base_csr_axi4l_bresp),
            .bvalid     (ss_base_csr_axi4l_bvalid),
            .bready     (ss_base_csr_axi4l_bready),
            .rdata      (ss_base_csr_axi4l_rdata),
            .rresp      (ss_base_csr_axi4l_rresp),
            .rvalid     (ss_base_csr_axi4l_rvalid),
            .rready     (ss_base_csr_axi4l_rready)
         );
      end else begin
         assign csr_test_pass    = '1;
         assign csr_test_fail    = '0;
         assign csr_test_timeout = '0;
         assign ss_base_csr_axi4l_awaddr  = '0;
         assign ss_base_csr_axi4l_awvalid = '0;
         assign ss_base_csr_axi4l_awprot  = '0;
         assign ss_base_csr_axi4l_araddr  = '0;
         assign ss_base_csr_axi4l_arvalid = '0;
         assign ss_base_csr_axi4l_arprot  = '0;
         assign ss_base_csr_axi4l_wdata   = '0;
         assign ss_base_csr_axi4l_wvalid  = '0;
         assign ss_base_csr_axi4l_wstrb   = '0;
         assign ss_base_csr_axi4l_bready  = '0;
         assign ss_base_csr_axi4l_rready  = '0;
      end
   endgenerate

   `ifdef ALTERA_EMIF_ENABLE_ISSP
      // acds/quartus/libraries/megafunctions/altsource_probe_body.vhd
      localparam MAX_PROBE_WIDTH = 511;
      localparam TTL_PNF_WIDTH = NUM_OF_CTRL_PORTS * GENERIC_WDATA_WIDTH;

      altsource_probe #(
         .sld_auto_instance_index ("YES"),
         .sld_instance_index      (0),
         .instance_id             ("WORM"),
         .probe_width             (0),
         .source_width            (1),
         .source_initial_value    ("0"),
         .enable_metastability    ("NO")
      ) tg_worm_en_issp (
         .source (issp_worm_en)
      );

      altsource_probe #(
         .sld_auto_instance_index ("YES"),
         .sld_instance_index      (0),
         .instance_id             ("TGP"),
         .probe_width             (1),
         .source_width            (0),
         .source_initial_value    ("0"),
         .enable_metastability    ("NO")
      ) tg_pass (
         .probe  (traffic_gen_pass)
      );

      altsource_probe #(
         .sld_auto_instance_index ("YES"),
         .sld_instance_index      (0),
         .instance_id             ("TGF"),
         .probe_width             (1),
         .source_width            (0),
         .source_initial_value    ("0"),
         .enable_metastability    ("NO")
      ) tg_fail (
         .probe  (traffic_gen_fail)
      );

      altsource_probe #(
         .sld_auto_instance_index ("YES"),
         .sld_instance_index      (0),
         .instance_id             ("TGT"),
         .probe_width             (1),
         .source_width            (0),
         .source_initial_value    ("0"),
         .enable_metastability    ("NO")
      ) tg_timeout (
         .probe  (traffic_gen_timeout)
      );

      altsource_probe #(
         .sld_auto_instance_index ("YES"),
         .sld_instance_index      (0),
         .instance_id             ("RCNT"),
         .probe_width             (TOTAL_OP_COUNT_WIDTH),
         .source_width            (0),
         .source_initial_value    ("0"),
         .enable_metastability    ("NO")
      ) issp_pnf_count (
         .probe  (total_read_count[0][TOTAL_OP_COUNT_WIDTH-1:0])
      );

      altsource_probe #(
         .sld_auto_instance_index ("YES"),
         .sld_instance_index      (0),
         .instance_id             ("FCNT"),
         .probe_width             (TOTAL_OP_COUNT_WIDTH),
         .source_width            (0),
         .source_initial_value    ("0"),
         .enable_metastability    ("NO")
      ) issp_ttl_fail_pnf (
         .probe  (failure_count[0][TOTAL_OP_COUNT_WIDTH-1:0])
      );

      altsource_probe #(
         .sld_auto_instance_index ("YES"),
         .sld_instance_index      (0),
         .instance_id             ("FADR"),
         .probe_width             (AMM_WORD_ADDRESS_WIDTH),
         .source_width            (0),
         .source_initial_value    ("0"),
         .enable_metastability    ("NO")
      ) issp_first_fail_exact_addr (
         .probe  (first_fail_addr[0])
      );

      altsource_probe #(
         .sld_auto_instance_index ("YES"),
         .sld_instance_index      (0),
         .instance_id             ("RAVP"),
         .probe_width             (MAX_CTRL_PORTS),
         .source_width            (0),
         .source_initial_value    ("0"),
         .enable_metastability    ("NO")
      ) issp_bff_rdata_valid      (
         .probe  (before_ff_rdata_valid[MAX_CTRL_PORTS-1:0])
      );

      altsource_probe #(
         .sld_auto_instance_index ("YES"),
         .sld_instance_index      (0),
         .instance_id             ("RAVN"),
         .probe_width             (MAX_CTRL_PORTS),
         .source_width            (0),
         .source_initial_value    ("0"),
         .enable_metastability    ("NO")
      ) issp_aff_rdata_valid      (
         .probe  (after_ff_rdata_valid[MAX_CTRL_PORTS-1:0])
      );



   generate
      if (NUM_OF_CTRL_PORTS > 0) begin
         // Pack PNF from all traffic generators into one long bit array to ease processing
         wire [TTL_PNF_WIDTH-1:0] pnf_per_bit_persist_packed   = pnf_per_bit_persist[NUM_OF_CTRL_PORTS-1:0];
         wire [TTL_PNF_WIDTH-1:0] first_fail_pnf_packed        = first_fail_pnf[NUM_OF_CTRL_PORTS-1:0];
         wire [TTL_PNF_WIDTH-1:0] first_fail_exp_data_packed   = first_fail_expected_data[NUM_OF_CTRL_PORTS-1:0];
         wire [TTL_PNF_WIDTH-1:0] first_fail_read_data_packed  = first_fail_read_data[NUM_OF_CTRL_PORTS-1:0];
         wire [TTL_PNF_WIDTH-1:0] last_read_data_packed        = last_read_data[NUM_OF_CTRL_PORTS-1:0];
         wire [TTL_PNF_WIDTH-1:0] after_ff_exp_data_packed     = after_ff_expected_data[NUM_OF_CTRL_PORTS-1:0];
         wire [TTL_PNF_WIDTH-1:0] after_ff_read_data_packed    = after_ff_read_data[NUM_OF_CTRL_PORTS-1:0];
         wire [TTL_PNF_WIDTH-1:0] before_ff_exp_data_packed    = before_ff_expected_data[NUM_OF_CTRL_PORTS-1:0];
         wire [TTL_PNF_WIDTH-1:0] before_ff_read_data_packed   = before_ff_read_data[NUM_OF_CTRL_PORTS-1:0];

         for (i = 0; i < (TTL_PNF_WIDTH + MAX_PROBE_WIDTH - 1) / MAX_PROBE_WIDTH; i = i + 1)
         begin : gen_pnf
            altsource_probe #(
               .sld_auto_instance_index ("YES"),
               .sld_instance_index      (0),
               .instance_id             (`_get_pnf_id(PNF, i)),
               .probe_width             ((MAX_PROBE_WIDTH * (i+1)) > TTL_PNF_WIDTH ? TTL_PNF_WIDTH - (MAX_PROBE_WIDTH * i) : MAX_PROBE_WIDTH),
               .source_width            (0),
               .source_initial_value    ("0"),
               .enable_metastability    ("NO")
            ) tg_pnf_persist (
               .probe  (pnf_per_bit_persist_packed[((MAX_PROBE_WIDTH * (i+1) - 1) < TTL_PNF_WIDTH-1 ? (MAX_PROBE_WIDTH * (i+1) - 1) : TTL_PNF_WIDTH-1) : (MAX_PROBE_WIDTH * i)])
            );

            altsource_probe #(
               .sld_auto_instance_index ("YES"),
               .sld_instance_index      (0),
               .instance_id             (`_get_pnf_id(FPN, i)),
               .probe_width             ((MAX_PROBE_WIDTH * (i+1)) > TTL_PNF_WIDTH ? TTL_PNF_WIDTH - (MAX_PROBE_WIDTH * i) : MAX_PROBE_WIDTH),
               .source_width            (0),
               .source_initial_value    ("0"),
               .enable_metastability    ("NO")
            ) tg_first_fail_pnf (
               .probe  (first_fail_pnf_packed[((MAX_PROBE_WIDTH * (i+1) - 1) < TTL_PNF_WIDTH-1 ? (MAX_PROBE_WIDTH * (i+1) - 1) : TTL_PNF_WIDTH-1) : (MAX_PROBE_WIDTH * i)])
            );

            altsource_probe #(
               .sld_auto_instance_index ("YES"),
               .sld_instance_index      (0),
               .instance_id             (`_get_pnf_id(FEX, i)),
               .probe_width             ((MAX_PROBE_WIDTH * (i+1)) > TTL_PNF_WIDTH ? TTL_PNF_WIDTH - (MAX_PROBE_WIDTH * i) : MAX_PROBE_WIDTH),
               .source_width            (0),
               .source_initial_value    ("0"),
               .enable_metastability    ("NO")
            ) tg_wd1 (
               .probe  (first_fail_exp_data_packed[((MAX_PROBE_WIDTH * (i+1) - 1) < TTL_PNF_WIDTH-1 ? (MAX_PROBE_WIDTH * (i+1) - 1) : TTL_PNF_WIDTH-1) : (MAX_PROBE_WIDTH * i)])
            );

            altsource_probe #(
               .sld_auto_instance_index ("YES"),
               .sld_instance_index      (0),
               .instance_id             (`_get_pnf_id(FEP, i)),
               .probe_width             ((MAX_PROBE_WIDTH * (i+1)) > TTL_PNF_WIDTH ? TTL_PNF_WIDTH - (MAX_PROBE_WIDTH * i) : MAX_PROBE_WIDTH),
               .source_width            (0),
               .source_initial_value    ("0"),
               .enable_metastability    ("NO")
            ) tg_wd2 (
               .probe  (before_ff_exp_data_packed[((MAX_PROBE_WIDTH * (i+1) - 1) < TTL_PNF_WIDTH-1 ? (MAX_PROBE_WIDTH * (i+1) - 1) : TTL_PNF_WIDTH-1) : (MAX_PROBE_WIDTH * i)])
            );

            altsource_probe #(
               .sld_auto_instance_index ("YES"),
               .sld_instance_index      (0),
               .instance_id             (`_get_pnf_id(FEN, i)),
               .probe_width             ((MAX_PROBE_WIDTH * (i+1)) > TTL_PNF_WIDTH ? TTL_PNF_WIDTH - (MAX_PROBE_WIDTH * i) : MAX_PROBE_WIDTH),
               .source_width            (0),
               .source_initial_value    ("0"),
               .enable_metastability    ("NO")
            ) tg_wd3 (
               .probe  (after_ff_exp_data_packed[((MAX_PROBE_WIDTH * (i+1) - 1) < TTL_PNF_WIDTH-1 ? (MAX_PROBE_WIDTH * (i+1) - 1) : TTL_PNF_WIDTH-1) : (MAX_PROBE_WIDTH * i)])
            );

            altsource_probe #(
               .sld_auto_instance_index ("YES"),
               .sld_instance_index      (0),
               .instance_id             (`_get_pnf_id(ACT, i)),
               .probe_width             ((MAX_PROBE_WIDTH * (i+1)) > TTL_PNF_WIDTH ? TTL_PNF_WIDTH - (MAX_PROBE_WIDTH * i) : MAX_PROBE_WIDTH),
               .source_width            (0),
               .source_initial_value    ("0"),
               .enable_metastability    ("NO")
            ) tg_rd1 (
               .probe  (first_fail_read_data_packed[((MAX_PROBE_WIDTH * (i+1) - 1) < TTL_PNF_WIDTH-1 ? (MAX_PROBE_WIDTH * (i+1) - 1) : TTL_PNF_WIDTH-1) : (MAX_PROBE_WIDTH * i)])
            );

            altsource_probe #(
               .sld_auto_instance_index ("YES"),
               .sld_instance_index      (0),
               .instance_id             (`_get_pnf_id(ACP, i)),
               .probe_width             ((MAX_PROBE_WIDTH * (i+1)) > TTL_PNF_WIDTH ? TTL_PNF_WIDTH - (MAX_PROBE_WIDTH * i) : MAX_PROBE_WIDTH),
               .source_width            (0),
               .source_initial_value    ("0"),
               .enable_metastability    ("NO")
            ) tg_rd2 (
               .probe  (before_ff_read_data_packed[((MAX_PROBE_WIDTH * (i+1) - 1) < TTL_PNF_WIDTH-1 ? (MAX_PROBE_WIDTH * (i+1) - 1) : TTL_PNF_WIDTH-1) : (MAX_PROBE_WIDTH * i)])
            );

            altsource_probe #(
               .sld_auto_instance_index ("YES"),
               .sld_instance_index      (0),
               .instance_id             (`_get_pnf_id(ACN, i)),
               .probe_width             ((MAX_PROBE_WIDTH * (i+1)) > TTL_PNF_WIDTH ? TTL_PNF_WIDTH - (MAX_PROBE_WIDTH * i) : MAX_PROBE_WIDTH),
               .source_width            (0),
               .source_initial_value    ("0"),
               .enable_metastability    ("NO")
            ) tg_rd3 (
               .probe  (after_ff_read_data_packed[((MAX_PROBE_WIDTH * (i+1) - 1) < TTL_PNF_WIDTH-1 ? (MAX_PROBE_WIDTH * (i+1) - 1) : TTL_PNF_WIDTH-1) : (MAX_PROBE_WIDTH * i)])
            );

            altsource_probe #(
               .sld_auto_instance_index ("YES"),
               .sld_instance_index      (0),
               .instance_id             (`_get_pnf_id(LRD, i)),
               .probe_width             ((MAX_PROBE_WIDTH * (i+1)) > TTL_PNF_WIDTH ? TTL_PNF_WIDTH - (MAX_PROBE_WIDTH * i) : MAX_PROBE_WIDTH),
               .source_width            (0),
               .source_initial_value    ("0"),
               .enable_metastability    ("NO")
            ) tg_last_rdata (
               .probe  (last_read_data_packed[((MAX_PROBE_WIDTH * (i+1) - 1) < TTL_PNF_WIDTH-1 ? (MAX_PROBE_WIDTH * (i+1) - 1) : TTL_PNF_WIDTH-1) : (MAX_PROBE_WIDTH * i)])
            );

         end
      end
   endgenerate
   `else
      assign issp_worm_en = 1'b0;
   `endif

   always_ff @(posedge emif_usr_clk)
   begin
      worm_en[2:0] <= {worm_en[1:0], issp_worm_en};
   end

   localparam DATA_SYNC_LENGTH = 3;

   wire ninit_done_int;
   assign ninit_done_int = ( MEGAFUNC_DEVICE_FAMILY == "ARRIA 10" ) ?  1'b1 : ~ninit_done;

   // Pipeline, synchronize and duplicate the emif_usr_reset_n signal for timing
   altera_std_synchronizer_nocut # (
      .depth     (DATA_SYNC_LENGTH),
      .rst_value (0)
   ) reset_n_int_sync_inst (
      .clk     (emif_usr_clk),
      .reset_n (emif_usr_reset_n),
      .din     (ninit_done_int),
      .dout    (reset_n_int)
   );

   always_ff @(posedge emif_usr_clk)begin
      reset <= ~reset_n_int;
   end

   //Tie off unused signals

   // not supported
   assign amm_beginbursttransfer_all = '0;

   //Tie off side-band signals
   //The example traffic generator doesn't exercise the side-band signals,
   //but we tie them off via core registers to ensure we get somewhat
   //realistic timing for these paths.
   (* altera_attribute = {"-name MAX_FANOUT 1; -name ADV_NETLIST_OPT_ALLOWED ALWAYS_ALLOW"}*) logic core_zero_tieoff_r /* synthesis dont_merge syn_preserve = 1*/;
   always_ff @(posedge emif_usr_clk)
   begin
      if (reset) begin
         core_zero_tieoff_r <= 1'b0;
      end else begin
         core_zero_tieoff_r <= 1'b0;
      end
   end

   assign ctrl_user_priority_hi_0         = core_zero_tieoff_r;
   assign ctrl_auto_precharge_req_0       = core_zero_tieoff_r;
   assign mmr_master_read_0               = core_zero_tieoff_r;
   assign mmr_master_write_0              = core_zero_tieoff_r;
   assign mmr_master_address_0            = {PORT_CTRL_MMR_MASTER_ADDRESS_WIDTH{core_zero_tieoff_r}};
   assign mmr_master_writedata_0          = {PORT_CTRL_MMR_MASTER_WDATA_WIDTH{core_zero_tieoff_r}};
   assign mmr_master_burstcount_0         = {PORT_CTRL_MMR_MASTER_BCOUNT_WIDTH{core_zero_tieoff_r}};
   assign mmr_master_beginbursttransfer_0 = core_zero_tieoff_r;

endmodule

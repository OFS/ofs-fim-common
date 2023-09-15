// Copyright (C) 2001-2021 Intel Corporation
// SPDX-License-Identifier: MIT


module altera_emif_avl_tg_2_traffic_gen #(
   parameter NUMBER_OF_DATA_GENERATORS       = "",
   parameter NUMBER_OF_BYTE_EN_GENERATORS    = "",
   parameter AMM_CFG_ADDR_WIDTH              = "", //avalon cfg address width from driver control block
   parameter AMM_CFG_DATA_WIDTH              = "", //avalon cfg data width from driver control block
   //Corresponds to memory data rate, 8 for quarter-rate, 4 for half-rate
   parameter DATA_RATE_WIDTH_RATIO           = "",
   //A total count of reads for the driver
   parameter OP_COUNT_WIDTH                  = "",
   //rw generator counter widths - will dictate maxima for configurable values
   parameter RW_RPT_COUNT_WIDTH              = "",
   parameter RW_OPERATION_COUNT_WIDTH        = "",
   parameter RW_LOOP_COUNT_WIDTH             = "",
   parameter RAND_SEQ_CNT_WIDTH              = 8,
   parameter SEQ_ADDR_INCR_WIDTH             = 16,
   //address generator params
   parameter MEM_ADDR_WIDTH                  = "", //memory address width
   parameter AMM_BURSTCOUNT_WIDTH            = "",
   parameter PORT_CTRL_AMM_WDATA_WIDTH       = "",
   parameter PORT_CTRL_AMM_RDATA_WIDTH       = "",
   parameter MEM_TTL_DATA_WIDTH              = "",
   parameter MEM_TTL_NUM_OF_WRITE_GROUPS     = "",
   parameter MEM_BE_WIDTH                    = "",
   parameter AMM_WORD_ADDRESS_WIDTH          = "",
   parameter USE_AVL_BYTEEN                  = "",
   parameter NUM_OF_CTRL_PORTS               = "",
   parameter AMM_BURST_COUNT_DIVISIBLE_BY    = "",
   parameter AMM_WORD_ADDRESS_DIVISIBLE_BY   = "",
   parameter TG_CLEAR_WIDTH                  = "",
   parameter COMPARE_ADDR_GEN_FIFO_WIDTH     = "",
   // Random seed for data generator
   parameter TG_LFSR_SEED                    = 36'b000000111110000011110000111000110010,

   // If set to true, the unix_id will be added to the MSB bit of
   // the generated address. This is useful to avoid address
   // overlapping when more than one traffic generator being
   // connected to the same slave.
   parameter TG_ENABLE_UNIX_ID               = 0,
   parameter TG_USE_UNIX_ID                  = 3'b000,
   parameter NUM_RESPONDERS                  = "",
   parameter CTRL_INTERFACE_TYPE             = "",
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
   parameter PORT_CTRL_AXI4_RUSER_WIDTH         = 8

   )(
   input      clk,
   input      rst,
   input      rst_config,
   output     tg_test_complete,
   output reg inf_user_mode,

   //Driver control block AMM interface signals
   input        [AMM_CFG_ADDR_WIDTH-1:0]  amm_cfg_address,
   input        [AMM_CFG_DATA_WIDTH-1:0]  amm_cfg_writedata,
   output reg   [AMM_CFG_DATA_WIDTH-1:0]  amm_cfg_readdata,
   input                                  amm_cfg_write,
   input                                  amm_cfg_read,
   output reg                             amm_cfg_waitrequest,
   output reg                             amm_cfg_readdatavalid,

   //Memory controller AMM interface signals
   output                              amm_ctrl_write,
   output                              amm_ctrl_read,
   output [MEM_ADDR_WIDTH-1:0]         amm_ctrl_address,
   output [PORT_CTRL_AMM_WDATA_WIDTH-1:0]         amm_ctrl_writedata,
   output [MEM_BE_WIDTH-1:0]           amm_ctrl_byteenable,
   input                               amm_ctrl_ready,
   input                               amm_ctrl_readdatavalid,
   input  [PORT_CTRL_AMM_WDATA_WIDTH-1:0]         amm_ctrl_readdata,
   output [AMM_BURSTCOUNT_WIDTH-1:0]   amm_ctrl_burstcount,
   // Ports for "ctrl_axi" interfaces
   output logic   [PORT_CTRL_AXI4_AWID_WIDTH-1:0]     axi_awid,
   output logic   [PORT_CTRL_AXI4_AWADDR_WIDTH-1:0]   axi_awaddr,
   output logic                                       axi_awvalid,
   output logic   [PORT_CTRL_AXI4_AWUSER_WIDTH-1:0]   axi_awuser,
   output logic   [PORT_CTRL_AXI4_AWLEN_WIDTH-1:0]    axi_awlen,
   output logic   [PORT_CTRL_AXI4_AWSIZE_WIDTH-1:0]   axi_awsize,
   output logic   [PORT_CTRL_AXI4_AWBURST_WIDTH-1:0]  axi_awburst,
   input  logic                                       axi_awready,
   output logic   [PORT_CTRL_AXI4_AWPROT_WIDTH-1:0]   axi_awprot,
   output logic   [PORT_CTRL_AXI4_AWCACHE_WIDTH-1:0]  axi_awcache,
   output logic   [PORT_CTRL_AXI4_AWLOCK_WIDTH-1:0]   axi_awlock,
   output logic   [PORT_CTRL_AXI4_ARID_WIDTH-1:0]     axi_arid,
   output logic   [PORT_CTRL_AXI4_ARADDR_WIDTH-1:0]   axi_araddr,
   output logic                                       axi_arvalid,
   output logic   [PORT_CTRL_AXI4_ARUSER_WIDTH-1:0]   axi_aruser,
   output logic   [PORT_CTRL_AXI4_ARLEN_WIDTH-1:0]    axi_arlen,
   output logic   [PORT_CTRL_AXI4_ARSIZE_WIDTH-1:0]   axi_arsize,
   output logic   [PORT_CTRL_AXI4_ARBURST_WIDTH-1:0]  axi_arburst,
   input  logic                                       axi_arready,
   output logic   [PORT_CTRL_AXI4_ARPROT_WIDTH-1:0]   axi_arprot,
   output logic   [PORT_CTRL_AXI4_ARCACHE_WIDTH-1:0]  axi_arcache,
   output logic   [PORT_CTRL_AXI4_ARLOCK_WIDTH-1:0]   axi_arlock,
   output logic   [PORT_CTRL_AXI4_WDATA_WIDTH-1:0]    axi_wdata,
   output logic   [PORT_CTRL_AXI4_WSTRB_WIDTH-1:0]    axi_wstrb,
   output logic                                       axi_wlast,
   output logic                                       axi_wvalid,
   input  logic                                       axi_wready,
   input  logic   [PORT_CTRL_AXI4_BID_WIDTH-1:0]      axi_bid,
   input  logic   [PORT_CTRL_AXI4_BRESP_WIDTH-1:0]    axi_bresp,
   input  logic   [PORT_CTRL_AXI4_BUSER_WIDTH-1:0]    axi_buser,
   input  logic                                       axi_bvalid,
   output logic                                       axi_bready,
   input  logic   [PORT_CTRL_AXI4_RID_WIDTH-1:0]      axi_rid,
   input  logic   [PORT_CTRL_AXI4_RDATA_WIDTH-1:0]    axi_rdata,
   input  logic   [PORT_CTRL_AXI4_RRESP_WIDTH-1:0]    axi_rresp,
   input  logic   [PORT_CTRL_AXI4_RUSER_WIDTH-1:0]    axi_ruser,
   input  logic                                       axi_rlast,
   input  logic                                       axi_rvalid,
   output logic                                       axi_rready,

   //Expected data for comparison in status checker
   output [MEM_BE_WIDTH-1:0]           ast_exp_data_byteenable,
   output [PORT_CTRL_AMM_WDATA_WIDTH-1:0]         ast_exp_data_writedata,
   output [AMM_WORD_ADDRESS_WIDTH-1:0] ast_exp_data_readaddr,

   //Actual data for comparison in status checker
   output                        ast_act_data_readdatavalid,
   output [PORT_CTRL_AMM_WDATA_WIDTH-1:0]   ast_act_data_readdata,

   //Status information from the status checker
   output reg [TG_CLEAR_WIDTH-1:0]  tg_clear,
   input    [PORT_CTRL_AXI4_WDATA_WIDTH-1:0]   pnf_per_bit_persist,
   input                            fail,
   input                            pass,
   input                            timeout,
   input    [AMM_CFG_DATA_WIDTH*2-1:0]                  first_fail_addr,
   input    [AMM_CFG_DATA_WIDTH*2-1:0]                  failure_count,
   input    [PORT_CTRL_AXI4_WDATA_WIDTH-1:0]   first_fail_expected_data,
   input    [PORT_CTRL_AXI4_WDATA_WIDTH-1:0]   first_fail_read_data,
   input                            first_failure_occured,

   input    [AMM_CFG_DATA_WIDTH*2-1:0]                  total_read_count,

   input                            at_target_stage,
   output                           target_first_failing_addr,

   output                           test_in_prog,
   output logic                     restart_default_traffic,
   input                            worm_en,
   output reg                       tg_test_byteen,
   output                           incr_timeout,
   output reg                       inf_user_mode_status_en
);
   timeunit 1ns;
   timeprecision 1ps;

   import avl_tg_defs::*;

   localparam DATA_TO_CFG_WIDTH_RATIO = PORT_CTRL_AMM_RDATA_WIDTH / AMM_CFG_DATA_WIDTH;
   localparam MAX_DATA_TO_CFG_MUX_SIZE = 36;
   localparam MAX_GEN_MODE_WIDTH = 2;
   localparam ADDR_GEN_MODE_WIDTH = 2;
   localparam PPPG_SEL_WIDTH = 6;

   localparam WORD_ADDR_SHIFT = ceil_log2(DATA_RATE_WIDTH_RATIO);

   wire [AMM_WORD_ADDRESS_WIDTH-1:0]  write_addr;
   wire [AMM_WORD_ADDRESS_WIDTH-1:0]  read_addr;

   wire reads_in_prog;
   wire writes_in_prog;
   wire status_check_in_prog;
   wire rw_gen_waitrequest;
   wire controller_wr_ready;
   wire controller_rd_ready;
   wire controller_ready;
   wire write_req;
   wire read_req;

   wire [PORT_CTRL_AMM_WDATA_WIDTH-1:0]     mem_write_data;
   wire [MEM_BE_WIDTH-1:0]       mem_write_be;

   //randomly generated write data
   reg [PORT_CTRL_AMM_WDATA_WIDTH-1:0]     lfsr_write_data;
   reg [MEM_BE_WIDTH-1:0]       lfsr_write_be;

   //expected read data
   reg [PORT_CTRL_AMM_WDATA_WIDTH-1:0]     lfsr_exp_write_data;
   reg [MEM_BE_WIDTH-1:0]       lfsr_exp_write_be;


   wire [PORT_CTRL_AMM_WDATA_WIDTH-1:0]     written_data;
   wire [MEM_BE_WIDTH-1:0]       written_be;

   //user-defined write data
   wire [PORT_CTRL_AMM_WDATA_WIDTH-1:0]     fixed_wdata;
   wire [MEM_BE_WIDTH-1:0]       fixed_wbe;

   wire [PORT_CTRL_AMM_WDATA_WIDTH-1:0]     fixed_exp_wdata;
   wire [MEM_BE_WIDTH-1:0]       fixed_exp_wbe;

   wire [DATA_RATE_WIDTH_RATIO-1:0] fixed_write_data   [0:NUMBER_OF_DATA_GENERATORS-1];
   wire [DATA_RATE_WIDTH_RATIO-1:0] fixed_write_be     [0:NUMBER_OF_BYTE_EN_GENERATORS-1];

   wire [DATA_RATE_WIDTH_RATIO-1:0] fixed_exp_write_data   [0:NUMBER_OF_DATA_GENERATORS-1];
   wire [DATA_RATE_WIDTH_RATIO-1:0] fixed_exp_write_be     [0:NUMBER_OF_BYTE_EN_GENERATORS-1];

   (* altera_attribute = {"-name MAX_FANOUT 100"}*) reg [MAX_GEN_MODE_WIDTH-1:0] data_gen_mode;
   reg [MAX_GEN_MODE_WIDTH-1:0] byte_en_gen_mode;

   //load for data generators
   reg [NUMBER_OF_DATA_GENERATORS-1:0] data_gen_load;
   reg [NUMBER_OF_DATA_GENERATORS-1:0] data_pattern_gen_load;

   //load for byte enable generators
   reg [NUMBER_OF_BYTE_EN_GENERATORS-1:0] byte_en_load;
   reg [NUMBER_OF_BYTE_EN_GENERATORS-1:0] byte_en_pattern_load;

   //enables from r/w generator to address generators
   wire next_addr_read;
   wire next_addr_write;
   wire next_data_read;
   wire next_data_write;

   wire [AMM_CFG_DATA_WIDTH-1:0] pnf_to_cfg_mux_signal [0:MAX_DATA_TO_CFG_MUX_SIZE-1];
   wire [AMM_CFG_DATA_WIDTH-1:0] exp_data_to_cfg_mux_signal [0:MAX_DATA_TO_CFG_MUX_SIZE-1];
   wire [AMM_CFG_DATA_WIDTH-1:0] read_data_to_cfg_mux_signal [0:MAX_DATA_TO_CFG_MUX_SIZE-1];

   //memory mapped registers
   reg [RW_LOOP_COUNT_WIDTH-1:0]      rw_gen_loop_cnt;
   reg [RW_OPERATION_COUNT_WIDTH-1:0] rw_gen_write_cnt;
   reg [RW_OPERATION_COUNT_WIDTH-1:0] rw_gen_read_cnt;
   reg [RW_RPT_COUNT_WIDTH-1:0]       rw_gen_write_rpt_cnt;
   reg [RW_RPT_COUNT_WIDTH-1:0]       rw_gen_read_rpt_cnt;
   reg [RW_IDLE_COUNT_WIDTH-1:0]      rw_gen_idle_count;
   reg [LOOP_IDLE_COUNT_WIDTH-1:0]    rw_gen_loop_idle_count;
   reg                                rw_gen_start;
   reg [AMM_BURSTCOUNT_WIDTH-1:0]     burstlength;
   reg [AMM_CFG_DATA_WIDTH-1:0]       data_seed       [0:NUMBER_OF_DATA_GENERATORS-1];
   reg [PPPG_SEL_WIDTH-1:0]           pppg_sel        [0:NUMBER_OF_DATA_GENERATORS-1];
   reg [AMM_CFG_DATA_WIDTH-1:0]       byteen_seed     [0:NUMBER_OF_BYTE_EN_GENERATORS-1];
   reg [PPPG_SEL_WIDTH-1:0]           byteen_sel      [0:NUMBER_OF_BYTE_EN_GENERATORS-1];

   //single bit signal indicate burstlength is 1
   reg                                single_burst;

   //single bit signal indicate if repeat read wirte is enabled
   reg                                rw_not_rpt_read;
   reg                                rw_not_rpt_write;

   reg   [AMM_CFG_DATA_WIDTH*2-1:0]   addr_gen_write_start_addr;
   reg   [ADDR_GEN_MODE_WIDTH-1:0]    addr_gen_mode_writes;

   reg   [AMM_CFG_DATA_WIDTH*2-1:0]   addr_gen_read_start_addr;
   reg   [ADDR_GEN_MODE_WIDTH-1:0]    addr_gen_mode_reads;

   //2nd layer decoder enables


   //generate data for amm_cfg_readdata 1 clock cycle before
   //retiming for time closure
   reg [AMM_CFG_DATA_WIDTH-1:0]       amm_cfg_readdata_status;
   reg [AMM_CFG_DATA_WIDTH-1:0]       amm_cfg_readdata_info;
   //error flag if amm_cfg_address is out of range
   //retiming for time closure
   reg                                amm_cfg_readdata_status_error;
   reg                                amm_cfg_readdata_info_error;

   //timing pipeline
   reg                                amm_cfg_read_r;
   reg                                amm_cfg_write_r;
   reg [AMM_CFG_ADDR_WIDTH-1:0]       amm_cfg_address_r;
   reg [AMM_CFG_DATA_WIDTH-1:0]       amm_cfg_writedata_r;

   //return to start address between write/read blocks for sequential addressing
   reg                                addr_gen_seq_return_to_start_addr;
   //number of sequential addresses to produce between random addresses for random sequential addressing
   reg [RAND_SEQ_CNT_WIDTH-1:0]       addr_gen_rseq_num_seq_addr_write;
   reg [RAND_SEQ_CNT_WIDTH-1:0]       addr_gen_rseq_num_seq_addr_read;
   //increment size for sequential or random sequential addressing. This is the increment to the avalon address
   reg [SEQ_ADDR_INCR_WIDTH-1:0]      addr_gen_seq_addr_incr;

   reg                                emergency_brake_asserted;
   reg [AMM_CFG_DATA_WIDTH-1:0]       config_error_report_reg;
   reg                                tg_start_detected;
   reg                                tg_invert_byteen;
   reg                                tg_user_worm_en;

   logic tg_restart;
   assign target_first_failing_addr =  worm_en | tg_user_worm_en;

   // used for infinite user mode
   logic timeout_rst;

   // used to reset all the FSMs once TG timeout
   // timeout_rst is high at the posedge of timeout
   logic timeout_r;
   always_ff @(posedge clk) begin
      if(rst) begin
         timeout_r   <= '0;
         timeout_rst <= '0;
      end
      else begin
         timeout_r <= timeout;
         if(timeout && !timeout_r) timeout_rst <= 1'b1;
         else                      timeout_rst <= 1'b0;
      end
   end

   always @ (posedge clk)
   begin
      //Pipelined configuration interface, in implementation of two-stage decoder
      amm_cfg_address_r       <= amm_cfg_address;
      amm_cfg_writedata_r     <= amm_cfg_writedata;
   end


   // infinite user mode control signal
   assign inf_user_mode = (rw_gen_loop_cnt == '0);
   always_ff @ (posedge clk) begin
      if(rst) begin
         inf_user_mode_status_en <= '0;
      end
      else begin
         if      (amm_cfg_write && !amm_cfg_waitrequest && (amm_cfg_address == TG_START) && (rw_gen_loop_cnt == '0)) inf_user_mode_status_en <= 1'b1;
         else if (amm_cfg_write && !amm_cfg_waitrequest && (amm_cfg_address == TG_START) && ~at_target_stage)  inf_user_mode_status_en <= 1'b0;
      end
   end


   int j;
   // Inital values / write
   always_ff @ (posedge clk) begin
      if (rst || rst_config) begin
         addr_gen_seq_return_to_start_addr   <= TG_RETURN_TO_START_ADDR_DEFAULT;
         rw_gen_loop_cnt                     <= TG_LOOP_COUNT_DEFAULT;
         rw_gen_write_cnt                    <= TG_WRITE_COUNT_DEFAULT;
         rw_gen_read_cnt                     <= TG_READ_COUNT_DEFAULT;
         rw_gen_write_rpt_cnt                <= TG_WRITE_REPEAT_COUNT_DEFAULT;
         rw_gen_read_rpt_cnt                 <= TG_READ_REPEAT_COUNT_DEFAULT;
         rw_gen_idle_count                   <= TG_RW_GEN_IDLE_COUNT_DEFAULT;
         rw_gen_loop_idle_count              <= TG_RW_GEN_LOOP_IDLE_COUNT_DEFAULT;
         rw_not_rpt_read                     <= 1'b1;
         rw_not_rpt_write                    <= 1'b1;
         addr_gen_rseq_num_seq_addr_write    <= TG_RAND_SEQ_ADDRS_WR_DEFAULT;
         addr_gen_rseq_num_seq_addr_read     <= TG_RAND_SEQ_ADDRS_RD_DEFAULT;
         burstlength                         <= TG_BURST_LENGTH_DEFAULT;
         single_burst                        <= 1'b1;
         addr_gen_seq_addr_incr              <= TG_SEQ_ADDR_INCR_DEFAULT;
         addr_gen_mode_writes                <= TG_ADDR_MODE_WR_DEFAULT;
         addr_gen_mode_reads                 <= TG_ADDR_MODE_RD_DEFAULT;
         amm_cfg_readdatavalid               <= '0;
         tg_clear                            <= TG_CLEAR_DEFAULT;
         rw_gen_start                        <= TG_START_DEFAULT;
         restart_default_traffic             <= TG_RESTART_DEFAULT_TRAFFIC_DEFAULT;
         amm_cfg_read_r                      <= '0;
         amm_cfg_write_r                     <= '0;
         data_gen_mode                       <= 1'b1;
         byte_en_gen_mode                    <= 1'b1;
         data_pattern_gen_load               <= '0;
         data_gen_load                       <= '0;
         byte_en_load                        <= '0;
         byte_en_pattern_load                <= '0;
         amm_cfg_waitrequest                 <= '0;
         emergency_brake_asserted            <= '0;
         tg_start_detected                   <= '0;
         addr_gen_write_start_addr           <= TG_SEQ_START_ADDR_WR_L_DEFAULT;
         addr_gen_read_start_addr            <= TG_SEQ_START_ADDR_RD_L_DEFAULT;
         tg_invert_byteen                    <= TG_INVERT_BYTEEN_DEFAULT;
         tg_test_byteen                      <= TG_TEST_BYTEEN_DEFAULT;
         tg_user_worm_en                     <= TG_USER_WORM_EN_DEFAULT;
      end else begin
         if (amm_cfg_write && !amm_cfg_waitrequest) begin
            for (j = 0; j < NUMBER_OF_DATA_GENERATORS; j++) begin: write_pattern
               if(amm_cfg_address == TG_PPPG_SEL+j)
                  data_pattern_gen_load[j]           <= 1'b1;
               else
                  data_pattern_gen_load[j]           <= 1'b0;
            end

            //Configuration of the data generator (seed)
            //The seed for data generator N can be found at address 100+N
            for (j = 0; j < NUMBER_OF_DATA_GENERATORS; j++) begin: write_seed
               if(amm_cfg_address == TG_DATA_SEED+j)
                  data_gen_load[j]           <= 1'b1;
               else
                  data_gen_load[j]           <= 1'b0;
            end

            for (j = 0; j < NUMBER_OF_BYTE_EN_GENERATORS; j++) begin: byte_en_pattern
               if(amm_cfg_address == TG_BYTEEN_SEL+j)
                  byte_en_pattern_load[j]            <= 1'b1;
               else
                  byte_en_pattern_load[j]            <= 1'b0;
            end

            //Configuration of the byte enable generator (seed)
            //The seed for byte enable generator N can be found at address 1A0+N
            for (j = 0; j < NUMBER_OF_BYTE_EN_GENERATORS; j++) begin: byte_en_seed
               if(amm_cfg_address == TG_BYTEEN_SEED+j)
                  byte_en_load[j]            <= 1'b1;
               else
                  byte_en_load[j]            <= 1'b0;
            end

         end else begin
            data_pattern_gen_load      <= 'b0;
            data_gen_load              <= 'b0;
            byte_en_pattern_load       <= 'b0;
            byte_en_load               <= 'b0;
         end

         if (amm_cfg_write_r) begin
            case(amm_cfg_address_r)
               TG_START:                    rw_gen_start                      <=  1'b1;
               TG_LOOP_COUNT:               rw_gen_loop_cnt                   <=  amm_cfg_writedata_r    [RW_LOOP_COUNT_WIDTH-1:0];
               TG_WRITE_COUNT:              rw_gen_write_cnt                  <=  amm_cfg_writedata_r    [RW_OPERATION_COUNT_WIDTH-1:0];
               TG_READ_COUNT:               rw_gen_read_cnt                   <=  amm_cfg_writedata_r    [RW_OPERATION_COUNT_WIDTH-1:0];
               TG_WRITE_REPEAT_COUNT:       begin
                                              rw_gen_write_rpt_cnt            <=  amm_cfg_writedata_r    [RW_RPT_COUNT_WIDTH-1:0];
                                              rw_not_rpt_write                <=  (amm_cfg_writedata_r   [RW_RPT_COUNT_WIDTH-1:0]   == 1'b1);
                                            end
               TG_READ_REPEAT_COUNT:        begin
                                              rw_gen_read_rpt_cnt             <=  amm_cfg_writedata_r    [RW_RPT_COUNT_WIDTH-1:0];
                                              rw_not_rpt_read                 <=  (amm_cfg_writedata_r   [RW_RPT_COUNT_WIDTH-1:0]   == 1'b1);
                                            end
               TG_BURST_LENGTH:             begin
                                              burstlength                     <=  amm_cfg_writedata_r    [AMM_BURSTCOUNT_WIDTH-1:0];
                                              single_burst                    <=  (amm_cfg_writedata_r   [AMM_BURSTCOUNT_WIDTH-1:0] == 1'b1);
                                            end
               TG_RW_GEN_IDLE_COUNT:        rw_gen_idle_count                 <= amm_cfg_writedata_r     [RW_IDLE_COUNT_WIDTH-1:0];
               TG_RW_GEN_LOOP_IDLE_COUNT:   rw_gen_loop_idle_count            <= amm_cfg_writedata_r     [LOOP_IDLE_COUNT_WIDTH-1:0];
               TG_CLEAR:                    tg_clear                          <=  amm_cfg_writedata_r    [TG_CLEAR_WIDTH-1:0];
               TG_SEQ_START_ADDR_WR_L:      addr_gen_write_start_addr[AMM_CFG_DATA_WIDTH-1:0]   <=  amm_cfg_writedata_r;
               TG_SEQ_START_ADDR_WR_H:      addr_gen_write_start_addr[AMM_CFG_DATA_WIDTH*2-1:AMM_CFG_DATA_WIDTH]  <=  amm_cfg_writedata_r;
               TG_ADDR_MODE_WR:             addr_gen_mode_writes              <=  amm_cfg_writedata_r    [ADDR_GEN_MODE_WIDTH-1:0];
               TG_RAND_SEQ_ADDRS_WR:        addr_gen_rseq_num_seq_addr_write  <=  amm_cfg_writedata_r    [RAND_SEQ_CNT_WIDTH-1:0];
               TG_RETURN_TO_START_ADDR:     addr_gen_seq_return_to_start_addr <=  amm_cfg_writedata_r    [0];
               TG_SEQ_ADDR_INCR:            addr_gen_seq_addr_incr            <=  amm_cfg_writedata_r    [SEQ_ADDR_INCR_WIDTH-1:0];
               TG_SEQ_START_ADDR_RD_L:      addr_gen_read_start_addr[AMM_CFG_DATA_WIDTH-1:0]    <=  amm_cfg_writedata_r;
               TG_SEQ_START_ADDR_RD_H:      addr_gen_read_start_addr[AMM_CFG_DATA_WIDTH*2-1:AMM_CFG_DATA_WIDTH]   <=  amm_cfg_writedata_r;
               TG_ADDR_MODE_RD:             addr_gen_mode_reads               <=  amm_cfg_writedata_r    [ADDR_GEN_MODE_WIDTH-1:0];
               TG_RAND_SEQ_ADDRS_RD:        addr_gen_rseq_num_seq_addr_read   <=  amm_cfg_writedata_r    [RAND_SEQ_CNT_WIDTH-1:0];
               TG_INVERT_BYTEEN:            tg_invert_byteen                  <=  amm_cfg_writedata_r    [0];
               TG_TEST_BYTEEN:              tg_test_byteen                    <=  amm_cfg_writedata_r    [0];
               TG_RESTART_DEFAULT_TRAFFIC:  restart_default_traffic           <=  1'b1;
               TG_USER_WORM_EN:             tg_user_worm_en                   <=  amm_cfg_writedata_r    [0];
            endcase
         end

         // These signals should only be asserted for one cycle
         if (rw_gen_start            != 1'b0)   rw_gen_start             <= 1'b0;
         if (restart_default_traffic != 1'b0)   restart_default_traffic  <= 1'b0;
         if (tg_clear                !=   '0)   tg_clear                 <= '0;

         // Set control signals
         //amm_cfg_waitrequest  <= amm_cfg_read ? 1'b0 : rw_gen_waitrequest | status_check_in_prog; //TIMING?? //can we assign it to zero?? what about default seq?
         amm_cfg_waitrequest  <= '0;
         tg_start_detected    <= amm_cfg_write && !amm_cfg_waitrequest && (amm_cfg_address == TG_START);

         amm_cfg_read_r       <= amm_cfg_read  && !amm_cfg_waitrequest;
         amm_cfg_write_r      <= amm_cfg_write && !amm_cfg_waitrequest;

         amm_cfg_readdatavalid      <= amm_cfg_read_r;
         emergency_brake_asserted   <= (first_failure_occured & ~at_target_stage & target_first_failing_addr);

      end  
   end

   localparam NUM_DATA_GEN_LOG = (NUMBER_OF_DATA_GENERATORS == 1)? 1:ceil_log2(NUMBER_OF_DATA_GENERATORS);
   localparam NUM_BYTEEN_GEN_LOG = (NUMBER_OF_BYTE_EN_GENERATORS == 1)? 1:ceil_log2(NUMBER_OF_BYTE_EN_GENERATORS);
   localparam NUM_TG_PNF_LOG = ceil_log2(MAX_DATA_TO_CFG_MUX_SIZE);
   bit amm_cfg_address_pnf, amm_cfg_address_act_data, amm_cfg_address_exp_data;
   bit amm_cfg_address_data_seed, amm_cfg_address_byteen_seed, amm_cfg_address_pppg_sel,amm_cfg_address_byteen_sel;
   always @ (posedge clk)
   begin
      amm_cfg_address_pnf         <= (amm_cfg_address[AMM_CFG_ADDR_WIDTH-1:NUM_TG_PNF_LOG]     == TG_PNF               [AMM_CFG_ADDR_WIDTH-1:NUM_TG_PNF_LOG]);
      amm_cfg_address_exp_data    <= (amm_cfg_address[AMM_CFG_ADDR_WIDTH-1:NUM_TG_PNF_LOG]     == TG_FAIL_EXPECTED_DATA[AMM_CFG_ADDR_WIDTH-1:NUM_TG_PNF_LOG]);
      amm_cfg_address_act_data    <= (amm_cfg_address[AMM_CFG_ADDR_WIDTH-1:NUM_TG_PNF_LOG]     == TG_FAIL_READ_DATA    [AMM_CFG_ADDR_WIDTH-1:NUM_TG_PNF_LOG]);
      amm_cfg_address_data_seed   <= (amm_cfg_address[AMM_CFG_ADDR_WIDTH-1:NUM_DATA_GEN_LOG]   == TG_DATA_SEED    [AMM_CFG_ADDR_WIDTH-1:NUM_DATA_GEN_LOG]);
      amm_cfg_address_byteen_seed <= (amm_cfg_address[AMM_CFG_ADDR_WIDTH-1:NUM_BYTEEN_GEN_LOG] == TG_BYTEEN_SEED  [AMM_CFG_ADDR_WIDTH-1:NUM_BYTEEN_GEN_LOG]);
      amm_cfg_address_pppg_sel    <= (amm_cfg_address[AMM_CFG_ADDR_WIDTH-1:NUM_DATA_GEN_LOG]   == TG_PPPG_SEL     [AMM_CFG_ADDR_WIDTH-1:NUM_DATA_GEN_LOG]);
      amm_cfg_address_byteen_sel  <= (amm_cfg_address[AMM_CFG_ADDR_WIDTH-1:NUM_BYTEEN_GEN_LOG] == TG_BYTEEN_SEL   [AMM_CFG_ADDR_WIDTH-1:NUM_BYTEEN_GEN_LOG]);
   end

   // Read from registers
   always @ (posedge clk) begin
    if (amm_cfg_read_r) begin
            if (amm_cfg_address_pnf        ) amm_cfg_readdata <= pnf_to_cfg_mux_signal      [amm_cfg_address_r[NUM_TG_PNF_LOG-1:0]];
       else if (amm_cfg_address_act_data   ) amm_cfg_readdata <= read_data_to_cfg_mux_signal[amm_cfg_address_r[NUM_TG_PNF_LOG-1:0]];
       else if (amm_cfg_address_exp_data   ) amm_cfg_readdata <= exp_data_to_cfg_mux_signal [amm_cfg_address_r[NUM_TG_PNF_LOG-1:0]];
       else if (amm_cfg_address_data_seed  ) amm_cfg_readdata <= data_seed  [amm_cfg_address_r[NUM_DATA_GEN_LOG-1:0]];
       else if (amm_cfg_address_byteen_seed) amm_cfg_readdata <= byteen_seed[amm_cfg_address_r[NUM_BYTEEN_GEN_LOG-1:0]];
       else if (amm_cfg_address_pppg_sel   ) amm_cfg_readdata <= pppg_sel   [amm_cfg_address_r[NUM_DATA_GEN_LOG-1:0]];
       else if (amm_cfg_address_byteen_sel ) amm_cfg_readdata <= byteen_sel [amm_cfg_address_r[NUM_BYTEEN_GEN_LOG-1:0]];
       else
         case (amm_cfg_address_r)
           TG_START:                         amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-1}{1'b0}}, rw_gen_start};
           TG_LOOP_COUNT:                    amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-RW_LOOP_COUNT_WIDTH}{1'b0}}, rw_gen_loop_cnt};
           TG_WRITE_COUNT:                   amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-RW_OPERATION_COUNT_WIDTH}{1'b0}}, rw_gen_write_cnt};
           TG_READ_COUNT:                    amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-RW_OPERATION_COUNT_WIDTH}{1'b0}}, rw_gen_read_cnt};
           TG_WRITE_REPEAT_COUNT:            amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-RW_RPT_COUNT_WIDTH}{1'b0}}, rw_gen_write_rpt_cnt};
           TG_READ_REPEAT_COUNT:             amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-RW_RPT_COUNT_WIDTH}{1'b0}}, rw_gen_read_rpt_cnt};
           TG_BURST_LENGTH:                  amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-AMM_BURSTCOUNT_WIDTH}{1'b0}}, burstlength};
           TG_CLEAR:                         amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-TG_CLEAR_WIDTH}{1'b0}},tg_clear};
           TG_SEQ_START_ADDR_WR_L:           amm_cfg_readdata <= addr_gen_write_start_addr [AMM_CFG_DATA_WIDTH-1:0];
           TG_SEQ_START_ADDR_WR_H:           amm_cfg_readdata <= addr_gen_write_start_addr [AMM_CFG_DATA_WIDTH*2-1:AMM_CFG_DATA_WIDTH];
           TG_ADDR_MODE_WR:                  amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-ADDR_GEN_MODE_WIDTH}{1'b0}}, addr_gen_mode_writes};
           TG_RAND_SEQ_ADDRS_WR:             amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-RAND_SEQ_CNT_WIDTH}{1'b0}}, addr_gen_rseq_num_seq_addr_write};
           TG_RETURN_TO_START_ADDR:          amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-1}{1'b0}}, addr_gen_seq_return_to_start_addr};
           TG_SEQ_ADDR_INCR:                 amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-SEQ_ADDR_INCR_WIDTH}{1'b0}}, addr_gen_seq_addr_incr};
           TG_SEQ_START_ADDR_RD_L:           amm_cfg_readdata <= addr_gen_read_start_addr [AMM_CFG_DATA_WIDTH-1:0];
           TG_SEQ_START_ADDR_RD_H:           amm_cfg_readdata <= addr_gen_read_start_addr [AMM_CFG_DATA_WIDTH*2-1:AMM_CFG_DATA_WIDTH];
           TG_ADDR_MODE_RD:                  amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-ADDR_GEN_MODE_WIDTH}{1'b0}}, addr_gen_mode_reads};
           TG_RAND_SEQ_ADDRS_RD:             amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-RAND_SEQ_CNT_WIDTH}{1'b0}}, addr_gen_rseq_num_seq_addr_read};
           TG_PASS:                          amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-1}{1'b0}}, pass};
           TG_FAIL:                          amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-1}{1'b0}}, fail};
           TG_TIMEOUT:                       amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-1}{1'b0}}, timeout};
           TG_FAIL_COUNT_L:                  amm_cfg_readdata <= failure_count[AMM_CFG_DATA_WIDTH-1:0];
           TG_FAIL_COUNT_H:                  amm_cfg_readdata <= failure_count[AMM_CFG_DATA_WIDTH*2-1:AMM_CFG_DATA_WIDTH];
           TG_FIRST_FAIL_ADDR_L:             amm_cfg_readdata <= first_fail_addr[AMM_CFG_DATA_WIDTH-1:0];
           TG_FIRST_FAIL_ADDR_H:             amm_cfg_readdata <= first_fail_addr[AMM_CFG_DATA_WIDTH*2-1:AMM_CFG_DATA_WIDTH];
           TG_TOTAL_READ_COUNT_L:            amm_cfg_readdata <= total_read_count[AMM_CFG_DATA_WIDTH-1:0];
           TG_TOTAL_READ_COUNT_H:            amm_cfg_readdata <= total_read_count[AMM_CFG_DATA_WIDTH*2-1:AMM_CFG_DATA_WIDTH];
           TG_TEST_COMPLETE:                 amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-1}{1'b0}}, tg_test_complete};
           TG_VERSION:                       amm_cfg_readdata <= 32'd169;
           TG_NUM_DATA_GEN:                  amm_cfg_readdata <= NUMBER_OF_DATA_GENERATORS;
           TG_NUM_BYTEEN_GEN:                amm_cfg_readdata <= NUMBER_OF_BYTE_EN_GENERATORS;
           TG_RDATA_WIDTH:                   amm_cfg_readdata <= PORT_CTRL_AMM_RDATA_WIDTH;
           TG_ERROR_REPORT:                  amm_cfg_readdata <= config_error_report_reg;
           TG_DATA_RATE_WIDTH_RATIO:         amm_cfg_readdata <= DATA_RATE_WIDTH_RATIO;
           TG_RW_GEN_IDLE_COUNT:             amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-RW_IDLE_COUNT_WIDTH}{1'b0}}, rw_gen_idle_count};
           TG_RW_GEN_LOOP_IDLE_COUNT:        amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-LOOP_IDLE_COUNT_WIDTH}{1'b0}}, rw_gen_loop_idle_count};
           TG_INVERT_BYTEEN:                 amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-1}{1'b0}}, tg_invert_byteen};
           TG_TEST_BYTEEN:                   amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-1}{1'b0}}, tg_test_byteen};
           TG_USER_WORM_EN:                  amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-1}{1'b0}}, tg_user_worm_en};
           TG_RESTART_DEFAULT_TRAFFIC:       amm_cfg_readdata <= {{{AMM_CFG_DATA_WIDTH-1}{1'b0}}, restart_default_traffic};
           default:                          amm_cfg_readdata <= 32'hbadf00d;
         endcase
    end
   end

   assign writes_in_prog = (writes_in_prog | write_req) & ~controller_rd_ready & ~rst;
   assign reads_in_prog = status_check_in_prog | tg_start_detected;
   assign test_in_prog = writes_in_prog | reads_in_prog;
   assign tg_restart = rw_gen_start;
   assign tg_test_complete = !(rw_gen_waitrequest | test_in_prog);

   genvar dupl_cntr;
   genvar k;
   genvar l;
   generate

      for ( k = 0; k <MAX_DATA_TO_CFG_MUX_SIZE*AMM_CFG_DATA_WIDTH ; k++ ) begin: multiplex_pnf_to_cfg
         if ( k < PORT_CTRL_AMM_RDATA_WIDTH) begin
            assign pnf_to_cfg_mux_signal      [k/AMM_CFG_DATA_WIDTH][k%AMM_CFG_DATA_WIDTH]     = pnf_per_bit_persist     [k];
            assign exp_data_to_cfg_mux_signal [k/AMM_CFG_DATA_WIDTH][k%AMM_CFG_DATA_WIDTH]     = first_fail_expected_data[k];
            assign read_data_to_cfg_mux_signal[k/AMM_CFG_DATA_WIDTH][k%AMM_CFG_DATA_WIDTH]     = first_fail_read_data    [k];
         end else begin
            assign pnf_to_cfg_mux_signal      [k/AMM_CFG_DATA_WIDTH][k%AMM_CFG_DATA_WIDTH]     = 1'b1;
            assign exp_data_to_cfg_mux_signal [k/AMM_CFG_DATA_WIDTH][k%AMM_CFG_DATA_WIDTH]     = 1'b0;
            assign read_data_to_cfg_mux_signal[k/AMM_CFG_DATA_WIDTH][k%AMM_CFG_DATA_WIDTH]     = 1'b0;
         end
      end

      localparam NUM_DUPLICATE_PATTERNS = PORT_CTRL_AMM_WDATA_WIDTH / (DATA_RATE_WIDTH_RATIO * NUMBER_OF_DATA_GENERATORS);

      for (dupl_cntr = 0; dupl_cntr < NUM_DUPLICATE_PATTERNS; dupl_cntr++) begin: fixed_wdata_mux_duplicates   // duplicate pattern over DQS groups
         for (l = 0; l < DATA_RATE_WIDTH_RATIO; l++) begin: fixed_wdata_mux_outer           // unwrap pattern
            for ( k = 0; k < NUMBER_OF_DATA_GENERATORS; k++) begin: fixed_wdata_mux_inner
               assign fixed_wdata     [l*NUM_DUPLICATE_PATTERNS*NUMBER_OF_DATA_GENERATORS + dupl_cntr*NUMBER_OF_DATA_GENERATORS + k]  = fixed_write_data     [k][l];
               assign fixed_exp_wdata [l*NUM_DUPLICATE_PATTERNS*NUMBER_OF_DATA_GENERATORS + dupl_cntr*NUMBER_OF_DATA_GENERATORS + k]  = fixed_exp_write_data [k][l];
            end
         end
      end

      if (USE_AVL_BYTEEN) begin
         for (l = 0; l < DATA_RATE_WIDTH_RATIO; l++) begin: fixed_wbe_mux_outer
            for ( k = 0; k < NUMBER_OF_BYTE_EN_GENERATORS; k++) begin: fixed_wbe_mux_inner
               assign fixed_wbe     [l*NUMBER_OF_BYTE_EN_GENERATORS+k] = fixed_write_be     [k][l];
               assign fixed_exp_wbe [l*NUMBER_OF_BYTE_EN_GENERATORS+k] = fixed_exp_write_be [k][l];
            end
         end
      end else begin
         assign fixed_wbe     = {(MEM_BE_WIDTH){1'b1}};
         assign fixed_exp_wbe = {(MEM_BE_WIDTH){1'b1}};
      end
   endgenerate

   //Traffic generation modules

   wire compare_addr_gen_fifo_full;

   reg [31:0]  rw_read_rpt_cnt;
   reg [31:0]  rw_write_rpt_cnt;

   //Indicate the last read/write of repeated R/W
   reg rpt_read_last;
   reg rpt_write_last;

   always @ (posedge clk) begin
      if (rw_gen_start) begin
         rpt_read_last <= rw_not_rpt_read;
         rpt_write_last <= rw_not_rpt_write;
      end else begin
         //Always high if read and write is not repeated
         if (rw_not_rpt_read) begin
            rpt_read_last <= 1'b1;
         end else if (read_req & controller_ready) begin
            rpt_read_last <= (rw_read_rpt_cnt == 32'h2);
         end

         //Always high if read and write is not repeated
         if (rw_not_rpt_write) begin
            rpt_write_last <= 1'b1;
         end else if (write_req & controller_ready) begin
            rpt_write_last <= (rw_write_rpt_cnt == 32'h2);
         end
      end
   end

   always @ (posedge clk) begin
      if (rw_gen_start) begin 
         rw_read_rpt_cnt   <= rw_gen_read_rpt_cnt;
         rw_write_rpt_cnt  <= rw_gen_write_rpt_cnt;
      end else begin
         if (read_req & controller_rd_ready) begin
            if (rpt_read_last)  rw_read_rpt_cnt   <= rw_gen_read_rpt_cnt;
            else                rw_read_rpt_cnt   <= rw_read_rpt_cnt - 32'h1;
         end

         if (write_req & controller_wr_ready) begin
            if (rpt_write_last) rw_write_rpt_cnt  <= rw_gen_write_rpt_cnt;
            else                rw_write_rpt_cnt  <= rw_write_rpt_cnt - 32'h1;
         end
      end
   end

   //number of operations left in the current loop
   wire [AMM_BURSTCOUNT_WIDTH-1:0]     write_burst_cntr;
   wire [RW_OPERATION_COUNT_WIDTH-1:0] write_cntr;
   wire [RW_OPERATION_COUNT_WIDTH-1:0] read_cntr;

   //read/write generator
   altera_emif_avl_tg_2_rw_gen #(
      .OPERATION_COUNT_WIDTH   (RW_OPERATION_COUNT_WIDTH),
      .LOOP_COUNT_WIDTH        (RW_LOOP_COUNT_WIDTH),
      .RW_IDLE_COUNT_WIDTH     (RW_IDLE_COUNT_WIDTH),
      .LOOP_IDLE_COUNT_WIDTH   (LOOP_IDLE_COUNT_WIDTH),
      .AMM_BURSTCOUNT_WIDTH    (AMM_BURSTCOUNT_WIDTH)
   ) rw_gen_u0 (
      .clk                       (clk),
      .rst                       (rst|timeout_rst),
      .valid                     (),
      .read_enable               (read_req),
      .write_enable              (write_req),
      .next_addr_read            (next_addr_read),
      .next_addr_write           (next_addr_write),
      .next_data_read            (next_data_read),
      .next_data_write           (next_data_write),
      .waitrequest               (rw_gen_waitrequest),
      .read_ready                (controller_rd_ready & rpt_read_last),
      .write_ready               (controller_wr_ready & rpt_write_last),
      .start                     (rw_gen_start),
      .num_reads                 (rw_gen_read_cnt),
      //writes are concerned with burst length, as write enable must be held high
      //for entire duration of burst
      .num_writes                (rw_gen_write_cnt),
      .num_loops                 (rw_gen_loop_cnt),
      .inf_user_mode             (inf_user_mode),
      .rw_gen_idle_count         (rw_gen_idle_count),
      .rw_gen_loop_idle_count    (rw_gen_loop_idle_count),
      .emergency_brake_asserted  (emergency_brake_asserted),
      .burstlength               (burstlength),
      .write_cntr                (write_cntr),
      .write_burst_cntr          (write_burst_cntr),
      .read_cntr                 (read_cntr)
   );

   //address generators
   altera_emif_avl_tg_2_addr_gen #(
      .AMM_WORD_ADDRESS_WIDTH          (AMM_WORD_ADDRESS_WIDTH),
      .SEQ_CNT_WIDTH                   (RW_OPERATION_COUNT_WIDTH),
      .RAND_SEQ_CNT_WIDTH              (RAND_SEQ_CNT_WIDTH),
      .SEQ_ADDR_INCR_WIDTH             (SEQ_ADDR_INCR_WIDTH),
      .AMM_WORD_ADDRESS_DIVISIBLE_BY   (AMM_WORD_ADDRESS_DIVISIBLE_BY),
      .AMM_BURST_COUNT_DIVISIBLE_BY    (AMM_BURST_COUNT_DIVISIBLE_BY),
      .ENABLE_UNIX_ID                  (TG_ENABLE_UNIX_ID),
      .USE_UNIX_ID                     (TG_USE_UNIX_ID),
      .NUM_RESPONDERS                  (NUM_RESPONDERS),
      .AMM_BURSTCOUNT_WIDTH            (AMM_BURSTCOUNT_WIDTH)
   ) write_address_gen (
      .clk                       (clk),
      .rst                       (rst|timeout_rst),
      .enable                    (next_addr_write),
      .addr_out                  (write_addr),
      .start                     (rw_gen_start),
      .start_addr                (addr_gen_write_start_addr[AMM_WORD_ADDRESS_WIDTH-1:0]),
      .addr_gen_mode             (addr_gen_mode_writes),
      //for sequential mode
      .seq_return_to_start_addr  (addr_gen_seq_return_to_start_addr),   // signals whether or not to return to seed when loop is done
      .seq_addr_num              (rw_gen_write_cnt),
      .seq_addr_increment        (addr_gen_seq_addr_incr),

      //for random sequential mode
      .rand_seq_num_seq_addr     (addr_gen_rseq_num_seq_addr_write),
      .rand_seq_restart_pattern  (rw_gen_start | (addr_gen_seq_return_to_start_addr & (write_cntr <= 1) & (write_burst_cntr <= 1))),   // signals that should return to seed on next clock cycle
      .burstlength               (burstlength)
   );

   altera_emif_avl_tg_2_addr_gen #(
      .AMM_WORD_ADDRESS_WIDTH          (AMM_WORD_ADDRESS_WIDTH),
      .SEQ_CNT_WIDTH                   (RW_OPERATION_COUNT_WIDTH),
      .RAND_SEQ_CNT_WIDTH              (RAND_SEQ_CNT_WIDTH),
      .SEQ_ADDR_INCR_WIDTH             (SEQ_ADDR_INCR_WIDTH),
      .AMM_WORD_ADDRESS_DIVISIBLE_BY   (AMM_WORD_ADDRESS_DIVISIBLE_BY),
      .AMM_BURST_COUNT_DIVISIBLE_BY    (AMM_BURST_COUNT_DIVISIBLE_BY),
      .ENABLE_UNIX_ID                  (TG_ENABLE_UNIX_ID),
      .USE_UNIX_ID                     (TG_USE_UNIX_ID),
      .NUM_RESPONDERS                  (NUM_RESPONDERS),
      .AMM_BURSTCOUNT_WIDTH            (AMM_BURSTCOUNT_WIDTH)
   ) read_address_gen (
      .clk                       (clk),
      .rst                       (rst|timeout_rst),
      //enable on start in order to generate the first address
      .enable                    (next_addr_read|rw_gen_start),
      .addr_out                  (read_addr),
      .start                     (rw_gen_start),
      .start_addr                (addr_gen_read_start_addr[AMM_WORD_ADDRESS_WIDTH-1:0]),
      .addr_gen_mode             (addr_gen_mode_reads),
      //for sequential mode
      .seq_return_to_start_addr  (addr_gen_seq_return_to_start_addr),
      .seq_addr_num              (rw_gen_read_cnt),
      .seq_addr_increment        (addr_gen_seq_addr_incr),
      //for random sequential
      .rand_seq_num_seq_addr     (addr_gen_rseq_num_seq_addr_read),
      .rand_seq_restart_pattern  (rw_gen_start | (addr_gen_seq_return_to_start_addr & (read_cntr <= 1))),   // signals that should return to seed on next clock cycle
      .burstlength               (burstlength)
   );
   wire next_read_data_en;

   genvar i;
   generate
      //The instantiation and linkage ordering is such that the first input configuration data will go to
      //instance 0, and the last input will go to instance number NUMBER_OF_DATA_GENERATORS-1
      for (i = 0; i < NUMBER_OF_DATA_GENERATORS; i = i + 1) begin: wr_data_pppg
         altera_emif_avl_tg_2_per_pin_pattern_gen #(
            .DATA_WIDTH         (DATA_RATE_WIDTH_RATIO),
            .AMM_CFG_DATA_WIDTH (AMM_CFG_DATA_WIDTH),
            .PPPG_SEL_WIDTH(PPPG_SEL_WIDTH),
            .PATTERN_SEL_DEFAULT(TG_PPPG_SEL_DEFAULT),
            .SEED_DEFAULT(TG_DATA_SEED_DEFAULT)
         ) per_pin_pattern_gen_data_wr (
            .clk                (clk),
            .rst                (rst),
            .data_gen_load      (data_gen_load[i]),
            .pattern_gen_load   (data_pattern_gen_load[i]),
            .tg_start_detected  (tg_start_detected),
            .reg_gen_data       (amm_cfg_writedata_r[AMM_CFG_DATA_WIDTH-1:0]),
            .enable             (next_data_write),
            .seed_data          (data_seed[i]),
            .pattern_sel        (pppg_sel[i]),
            .dout               (fixed_write_data[i])
         );
      end
   endgenerate

   generate
      for (i = 0; i < NUMBER_OF_BYTE_EN_GENERATORS; i = i + 1) begin: wr_byte_en_pppg
         altera_emif_avl_tg_2_per_pin_pattern_gen #(
            .DATA_WIDTH         (DATA_RATE_WIDTH_RATIO),
            .AMM_CFG_DATA_WIDTH (AMM_CFG_DATA_WIDTH),
            .PPPG_SEL_WIDTH(PPPG_SEL_WIDTH),
            .PATTERN_SEL_DEFAULT(TG_BYTEEN_SEL_DEFAULT),
            .SEED_DEFAULT(TG_BYTEEN_SEED_DEFAULT)
         ) per_pin_pattern_gen_be_wr (
            .clk                (clk),
            .rst                (rst),
            .data_gen_load      (byte_en_load[i]),
            .pattern_gen_load   (byte_en_pattern_load[i]),
            .tg_start_detected  (tg_start_detected),
            .reg_gen_data       (amm_cfg_writedata_r[AMM_CFG_DATA_WIDTH-1:0]),
            .enable             (next_data_write),
            .seed_data          (byteen_seed[i]),
            .pattern_sel        (byteen_sel[i]),
            .dout               (fixed_write_be[i])
         );
      end
   endgenerate

   generate
      //data for comparison to read data
      for (i = 0; i < NUMBER_OF_DATA_GENERATORS; i = i + 1) begin: exp_data_pppg
         altera_emif_avl_tg_2_per_pin_pattern_gen #(
            .DATA_WIDTH         (DATA_RATE_WIDTH_RATIO),
            .AMM_CFG_DATA_WIDTH (AMM_CFG_DATA_WIDTH),
            .PPPG_SEL_WIDTH(PPPG_SEL_WIDTH),
            .PATTERN_SEL_DEFAULT(TG_PPPG_SEL_DEFAULT),
            .SEED_DEFAULT(TG_DATA_SEED_DEFAULT)
         ) per_pin_pattern_gen_data_exp (
            .clk                (clk),
            .rst                (rst),
            .data_gen_load      (data_gen_load[i]),
            .pattern_gen_load   (data_pattern_gen_load[i]),
            .tg_start_detected  (tg_start_detected),
            .reg_gen_data       (amm_cfg_writedata_r[AMM_CFG_DATA_WIDTH-1:0]),
            .enable             (next_read_data_en),
            .seed_data          (),
            .pattern_sel        (),
            .dout               (fixed_exp_write_data[i])
         );
      end
   endgenerate


   generate
      //be for comparison to read data
      for (i = 0; i < NUMBER_OF_BYTE_EN_GENERATORS; i = i + 1) begin: exp_byte_en_pppg
         altera_emif_avl_tg_2_per_pin_pattern_gen #(
            .DATA_WIDTH         (DATA_RATE_WIDTH_RATIO),
            .AMM_CFG_DATA_WIDTH (AMM_CFG_DATA_WIDTH),
            .PPPG_SEL_WIDTH(PPPG_SEL_WIDTH),
            .PATTERN_SEL_DEFAULT(TG_BYTEEN_SEL_DEFAULT),
            .SEED_DEFAULT(TG_BYTEEN_SEED_DEFAULT)
         ) per_pin_pattern_gen_be_exp (
            .clk               (clk),
            .rst               (rst),
            .data_gen_load     (byte_en_load[i]),
            .pattern_gen_load  (byte_en_pattern_load[i]),
            .tg_start_detected (tg_start_detected),
            .reg_gen_data      (amm_cfg_writedata_r[AMM_CFG_DATA_WIDTH-1:0]),
            .enable            (next_read_data_en),
            .seed_data         (),
            .pattern_sel       (),
            .dout              (fixed_exp_write_be[i])
         );
      end
   endgenerate

   // LFSR data generators
   // 2 sets needed - 1 for writes, 1 for verification of read data
   // A separate data generator is used to re-generate the written data/mask for read comparison.
   // This saves us from the need of instantiating a FIFO to record the write data

      //Actual write data generator
   altera_emif_avl_tg_lfsr_wrapper # (
      .DATA_WIDTH (PORT_CTRL_AMM_WDATA_WIDTH),
      .SEED       (TG_LFSR_SEED)
   ) act_data_gen_inst (
      .clk        (clk),
      .reset_n    (~rst),
      .enable     (next_data_write & (data_gen_mode[0] == 0)),
      .data       (lfsr_write_data)
   );

   //Actual byte enable generator
   generate
      if (USE_AVL_BYTEEN) begin : act_be_gen
         altera_emif_avl_tg_lfsr_wrapper # (
            .DATA_WIDTH (MEM_BE_WIDTH)
         ) act_be_gen_inst (
            .clk        (clk),
            .reset_n    (~rst),
            .enable     (next_data_write & (data_gen_mode[0] == 0)),
            .data       (lfsr_write_be)
         );
      end else begin
         assign lfsr_write_be = {(MEM_BE_WIDTH){1'b1}};
      end
   endgenerate

   // Expected write data generator
   altera_emif_avl_tg_lfsr_wrapper # (
      .DATA_WIDTH (PORT_CTRL_AMM_WDATA_WIDTH),
      .SEED       (TG_LFSR_SEED)
   ) exp_data_gen_inst (
      .clk        (clk),
      .reset_n    (~rst),
      .enable     (next_read_data_en & (data_gen_mode[0] == 0)),
      .data       (lfsr_exp_write_data)
   );

   // Expected byte enable generator
   generate
      if (USE_AVL_BYTEEN) begin : exp_be_gen
         altera_emif_avl_tg_lfsr_wrapper # (
            .DATA_WIDTH (MEM_BE_WIDTH)
         ) exp_be_gen_inst (
            .clk        (clk),
            .reset_n    (~rst),
            .enable     (next_read_data_en & (data_gen_mode[0] == 0)),
            .data       (lfsr_exp_write_be)
         );
      end else begin
         assign lfsr_exp_write_be = {(MEM_BE_WIDTH){1'b1}};
      end
   endgenerate

   assign mem_write_data = data_gen_mode[0] ? (tg_invert_byteen ? ~fixed_wdata : fixed_wdata) : lfsr_write_data;
   assign mem_write_be   = byte_en_gen_mode[0] ? (tg_invert_byteen ? ~fixed_wbe : fixed_wbe) : lfsr_write_be;

   assign written_data = data_gen_mode[0] ? (tg_invert_byteen ? ~fixed_exp_wdata : fixed_exp_wdata) : lfsr_exp_write_data;
   assign written_be   = byte_en_gen_mode[0] ? (tg_invert_byteen ? ~fixed_exp_wbe : fixed_exp_wbe) : lfsr_exp_write_be;

   wire [MEM_BE_WIDTH-1:0]    ast_exp_data_byteenable_pre;

   generate
      //Logic to connect the avl interface to the 1x bridge

      logic                                    avl_read_req;
      logic                                    avl_write_req;
      logic                                    avl_ready;
      logic [MEM_ADDR_WIDTH-1:0]               avl_mem_addr;
      logic [AMM_BURSTCOUNT_WIDTH-1:0]         avl_burstlength;
      logic [MEM_BE_WIDTH-1:0]                 avl_mem_write_be;
      logic [PORT_CTRL_AMM_WDATA_WIDTH-1:0]    avl_mem_write_data;
      logic [AMM_WORD_ADDRESS_WIDTH-1:0]       mem_addr;

      assign mem_addr = write_req ? write_addr : read_addr;

      // For timing closure we instantiate a bridge to decouple
      // master and slave. The bridge is essentially a 2-deep FIFO.

      altera_emif_avl_tg_amm_1x_bridge # (
         .AMM_WDATA_WIDTH          (PORT_CTRL_AMM_WDATA_WIDTH),
         .AMM_SYMBOL_ADDRESS_WIDTH (MEM_ADDR_WIDTH),
         .AMM_BCOUNT_WIDTH         (AMM_BURSTCOUNT_WIDTH),
         .AMM_BYTEEN_WIDTH         (MEM_BE_WIDTH)
      ) amm_1x_bridge (
         .reset                      (rst|timeout_rst),
         .clk                        (clk),

         // memory interface side
         .amm_slave_write            (amm_ctrl_write),
         .amm_slave_read             (amm_ctrl_read),
         .amm_slave_ready            (amm_ctrl_ready), 
         .amm_slave_address          (amm_ctrl_address),
         .amm_slave_writedata        (amm_ctrl_writedata),
         .amm_slave_burstcount       (amm_ctrl_burstcount),
         .amm_slave_byteenable       (amm_ctrl_byteenable),

         // avl interface side
         .amm_master_write           (avl_write_req),
         .amm_master_read            (avl_read_req),
         .amm_master_ready           (avl_ready), 
         .amm_master_address         (avl_mem_addr),
         .amm_master_writedata       (avl_mem_write_data),
         .amm_master_burstcount      (avl_burstlength),
         .amm_master_byteenable      (avl_mem_write_be)
      );

      if ( CTRL_INTERFACE_TYPE == "AXI" ) begin: axi_interface
         altera_emif_avl_tg_2_axi_if # (
            .BYTE_ADDR_WIDTH              (MEM_ADDR_WIDTH),
            .DATA_WIDTH                   (PORT_CTRL_AMM_WDATA_WIDTH),
            .BE_WIDTH                     (MEM_BE_WIDTH),
            .AMM_WORD_ADDRESS_WIDTH       (AMM_WORD_ADDRESS_WIDTH),
            .AMM_BURSTCOUNT_WIDTH         (AMM_BURSTCOUNT_WIDTH),
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
         ) axi_tg_if_inst (
            .clk                        (clk),
            .rst                        (rst|timeout_rst),
            .write_req                  (write_req),
            .read_req                   (read_req),
            .mem_addr                   (mem_addr),
            .controller_wr_ready        (controller_wr_ready),
            .controller_rd_ready        (controller_rd_ready),
            .mem_write_data             (mem_write_data),
            .mem_write_be               (mem_write_be),
            .burstlength                (burstlength),
            .axi_awid                   (axi_awid),
            .axi_awaddr                 (axi_awaddr),
            .axi_awvalid                (axi_awvalid),
            .axi_awuser                 (axi_awuser),
            .axi_awlen                  (axi_awlen),
            .axi_awsize                 (axi_awsize),
            .axi_awburst                (axi_awburst),
            .axi_awready                (axi_awready),
            .axi_wdata                  (axi_wdata),
            .axi_wstrb                  (axi_wstrb),   
            .axi_wlast                  (axi_wlast),   
            .axi_wvalid                 (axi_wvalid),
            .axi_wready                 (axi_wready),
            .axi_bid                    (axi_bid),
            .axi_bresp                  (axi_bresp),
            .axi_buser                  (axi_buser),
            .axi_bvalid                 (axi_bvalid),
            .axi_bready                 (axi_bready),
            .axi_arid                   (axi_arid),
            .axi_araddr                 (axi_araddr),
            .axi_arvalid                (axi_arvalid),
            .axi_aruser                 (axi_aruser),
            .axi_arlen                  (axi_arlen),
            .axi_arsize                 (axi_arsize),
            .axi_arburst                (axi_arburst),
            .axi_arready                (axi_arready),
            .axi_rid                    (axi_rid),
            .axi_rdata                  (axi_rdata),
            .axi_rresp                  (axi_rresp),
            .axi_ruser                  (axi_ruser),
            .axi_rlast                  (axi_rlast),
            .axi_rvalid                 (axi_rvalid),
            .axi_rready                 (axi_rready),
            .written_data               (written_data),
            .written_be                 (written_be),
            .ast_exp_data_byteenable    (ast_exp_data_byteenable_pre),
            .ast_exp_data_writedata     (ast_exp_data_writedata),
            .ast_act_data_readdatavalid (ast_act_data_readdatavalid),
            .ast_act_data_readdata      (ast_act_data_readdata),
            .read_addr_fifo_full        (compare_addr_gen_fifo_full),
            .start                      (rw_gen_start)
         );


         assign axi_awprot  = '0;
         assign axi_awcache = '0;
         assign axi_awlock  = '0;
         assign axi_arprot  = '0;
         assign axi_arcache = '0;
         assign axi_arlock  = '0;

         assign avl_read_req = '0;
         assign avl_write_req = '0;
         assign avl_mem_addr = '0;
         assign avl_burstlength = '0;
         assign avl_mem_write_data = '0;
         assign avl_mem_write_be = '0;

         assign controller_ready = '0;
      end
      else begin: avl_interface
         assign controller_wr_ready = controller_ready;
         assign controller_rd_ready = controller_ready;
         //translates the commands issued by the traffic_gen into Avalon signals
         altera_emif_avl_tg_2_avl_if # (
            .BYTE_ADDR_WIDTH              (MEM_ADDR_WIDTH),
            .DATA_WIDTH                   (PORT_CTRL_AMM_WDATA_WIDTH),
            .BE_WIDTH                     (MEM_BE_WIDTH),
            .AMM_WORD_ADDRESS_WIDTH       (AMM_WORD_ADDRESS_WIDTH),
            .AMM_BURSTCOUNT_WIDTH         (AMM_BURSTCOUNT_WIDTH)
         ) avl_tg_if_inst (

            .clk                          (clk),

            // traffic generator side
            .write_req                    (write_req),
            .read_req                     (read_req),
            .mem_addr                     (mem_addr),
            .mem_write_data               (mem_write_data),
            .mem_write_be                 (mem_write_be),
            .controller_ready             (controller_ready),
            .burstlength                  (burstlength),

            // 1x bridge side
            .amm_ctrl_write              (avl_write_req),
            .amm_ctrl_read               (avl_read_req),
            .amm_ctrl_address            (avl_mem_addr),
            .amm_ctrl_writedata          (avl_mem_write_data),
            .amm_ctrl_byteenable         (avl_mem_write_be),
            .amm_ctrl_ready              (avl_ready),
            .amm_ctrl_burstcount         (avl_burstlength),

            // from memory interface
            .amm_ctrl_readdatavalid      (amm_ctrl_readdatavalid),
            .amm_ctrl_readdata           (amm_ctrl_readdata),

            //data for comparison
            .written_be                  (written_be),
            .written_data                (written_data),

            // outputs
            .ast_exp_data_byteenable     (ast_exp_data_byteenable_pre),
            .ast_exp_data_writedata      (ast_exp_data_writedata),

            .ast_act_data_readdatavalid  (ast_act_data_readdatavalid),
            .ast_act_data_readdata       (ast_act_data_readdata),

            .read_addr_fifo_full         (compare_addr_gen_fifo_full)

         );

         assign axi_awid    = '0;
         assign axi_awaddr  = '0;
         assign axi_awvalid = '0;
         assign axi_awuser  = '0;
         assign axi_awlen   = '0;
         assign axi_awsize  = '0;
         assign axi_awburst = '0;
         assign axi_awprot  = '0;
         assign axi_awcache = '0;
         assign axi_awlock  = '0;
         assign axi_arid    = '0;
         assign axi_araddr  = '0;
         assign axi_arvalid = '0;
         assign axi_aruser  = '0;
         assign axi_arlen   = '0;
         assign axi_arsize  = '0;
         assign axi_arburst = '0;
         assign axi_arprot  = '0;
         assign axi_arcache = '0;
         assign axi_arlock  = '0;
         assign axi_wdata   = '0;
         assign axi_wstrb   = '0;
         assign axi_wlast   = '0;
         assign axi_wvalid  = '0;
         assign axi_bready  = '0;
         assign axi_rready  = '0;
      end

   `ifdef ALTERA_EMIF_ENABLE_ISSP
      logic [31:0] avl_cycle_cnt;
      logic [31:0] avl_byte_cnt;
      logic [31:0] clock_cnt;
      logic        first_req_received;

      always_ff @(posedge clk)
      begin
         if (rst) begin
             first_req_received <= 0;
         end else if ((avl_read_req | avl_write_req) & avl_ready) begin
             first_req_received <= 1'b1;
         end
     end

      always_ff @(posedge clk)
      begin
         if (rst) begin
             avl_cycle_cnt <= '0;
             avl_byte_cnt <= '0;
             clock_cnt <= '0;
         end else if (first_req_received) begin
             if (avl_read_req & avl_ready)begin
                avl_byte_cnt <= avl_byte_cnt + avl_burstlength;
             end else if(avl_write_req & avl_ready) begin
                avl_byte_cnt <= avl_byte_cnt + 1;
             end

             if(avl_read_req & avl_ready)
               avl_cycle_cnt <= avl_cycle_cnt + 1;

             clock_cnt <= clock_cnt + 1;
         end
      end

      altsource_probe #(
         .sld_auto_instance_index ("YES"),
         .sld_instance_index      (0),
         .instance_id             ("AVSC"),
         .probe_width             (96),
         .source_width            (0),
         .source_initial_value    ("0"),
         .enable_metastability    ("NO")
      ) issp_avl_req_count (
         .probe  ({avl_byte_cnt, avl_cycle_cnt, clock_cnt})
      );
   `endif
   endgenerate

   assign ast_exp_data_byteenable = NUMBER_OF_BYTE_EN_GENERATORS == 0 ? {MEM_BE_WIDTH{1'b1}} : ast_exp_data_byteenable_pre;

   //Generates the addresses of the read data needed by status checker
   altera_emif_avl_tg_2_compare_addr_gen # (
      .AMM_WORD_ADDRESS_WIDTH    (AMM_WORD_ADDRESS_WIDTH),
      .ADDR_FIFO_DEPTH           (COMPARE_ADDR_GEN_FIFO_WIDTH),
      .AMM_BURSTCOUNT_WIDTH      (AMM_BURSTCOUNT_WIDTH),
      .READ_RPT_COUNT_WIDTH      (RW_RPT_COUNT_WIDTH),
      .READ_COUNT_WIDTH          (RW_OPERATION_COUNT_WIDTH),
      .READ_LOOP_COUNT_WIDTH     (RW_LOOP_COUNT_WIDTH)
   ) compare_addr_gen_inst(
      .clk                       (clk),
      .rst                       (rst|timeout_rst),
      .tg_restart                (tg_restart),

      //read counters needed by status checker
      .num_read_bursts           (rw_gen_read_cnt),
      .num_read_loops            (rw_gen_loop_cnt),
      .inf_user_mode             (inf_user_mode),
      .not_repeat_test           (rw_not_rpt_read),
      .rw_gen_read_rpt_cnt       (rw_gen_read_rpt_cnt),
      .rdata_valid               (ast_act_data_readdatavalid),
      .emergency_brake_asserted  (emergency_brake_asserted),

      .read_addr                 (read_addr),
      .read_addr_valid           (controller_ready & read_req),

      .burst_length              (burstlength),
      .single_burst              (single_burst),
      .current_written_addr      (ast_exp_data_readaddr),
      .check_in_prog             (status_check_in_prog),
      .fifo_almost_full          (compare_addr_gen_fifo_full),
      .next_read_data_en         (next_read_data_en),
      .read_addr_fifo_out        (),
      .incr_timeout              (incr_timeout)
   );

   altera_emif_avl_tg_2_config_error_module # (
      .AMM_WORD_ADDRESS_DIVISIBLE_BY   (AMM_WORD_ADDRESS_DIVISIBLE_BY),
      .AMM_BURST_COUNT_DIVISIBLE_BY    (AMM_BURST_COUNT_DIVISIBLE_BY),
      .PORT_CTRL_AMM_WDATA_WIDTH       (PORT_CTRL_AMM_WDATA_WIDTH),
      .MEM_BE_WIDTH                    (MEM_BE_WIDTH),
      .USE_AVL_BYTEEN                  (USE_AVL_BYTEEN),
      .NUMBER_OF_DATA_GENERATORS       (NUMBER_OF_DATA_GENERATORS),
      .NUMBER_OF_BYTE_EN_GENERATORS    (NUMBER_OF_BYTE_EN_GENERATORS),
      .DATA_RATE_WIDTH_RATIO           (DATA_RATE_WIDTH_RATIO),
      .RAND_SEQ_CNT_WIDTH              (RAND_SEQ_CNT_WIDTH),
      .AMM_WORD_ADDRESS_WIDTH          (AMM_WORD_ADDRESS_WIDTH),
      .AMM_BURSTCOUNT_WIDTH            (AMM_BURSTCOUNT_WIDTH),
      .RW_OPERATION_COUNT_WIDTH        (RW_OPERATION_COUNT_WIDTH),
      .RW_RPT_COUNT_WIDTH              (RW_RPT_COUNT_WIDTH),
      .SEQ_ADDR_INCR_WIDTH             (SEQ_ADDR_INCR_WIDTH)
   ) config_error_module_inst (
      .clk                             (clk),
      .reset                           (rst),
      .tg_restart                      (tg_restart),

      //config registers of interest
      .num_reads                       (rw_gen_read_cnt),
      .num_writes                      (rw_gen_write_cnt),
      .seq_addr_incr                   (addr_gen_seq_addr_incr),
      .burstlength                     (burstlength),
      .addr_write                      (addr_gen_write_start_addr[AMM_WORD_ADDRESS_WIDTH-1:0]),
      .addr_read                       (addr_gen_read_start_addr[AMM_WORD_ADDRESS_WIDTH-1:0]),
      .addr_mode_write                 (addr_gen_mode_writes),
      .addr_mode_read                  (addr_gen_mode_reads),
      .rand_seq_addrs_write            (addr_gen_rseq_num_seq_addr_write),
      .rand_seq_addrs_read             (addr_gen_rseq_num_seq_addr_read),
      .num_read_repeats                (rw_gen_read_rpt_cnt),
      .num_write_repeats               (rw_gen_write_rpt_cnt),

      //error report out
      .config_error_report             (config_error_report_reg)
   );







endmodule








// Copyright (C) 2001-2021 Intel Corporation
// SPDX-License-Identifier: MIT


//////////////////////////////////////////////////////////////////////////////
//This is a sample driver control block for the traffic generator
//It coordinates the issuing of individual test stages, each of which will perform
//their own configuration of the traffic generator specific to a certain test case
//New test stages can easily be added
//////////////////////////////////////////////////////////////////////////////

module altera_emif_avl_tg_2_bringup_dcb #(
      parameter NUMBER_OF_DATA_GENERATORS    = "",
      parameter NUMBER_OF_BYTE_EN_GENERATORS = "",
      parameter USE_AVL_BYTEEN               = "",
      parameter MEM_ADDR_WIDTH               = "",
      parameter BURSTCOUNT_WIDTH             = "",
      parameter TG_TEST_DURATION             = "",
      parameter PORT_TG_CFG_ADDRESS_WIDTH    = "",
      parameter PORT_TG_CFG_RDATA_WIDTH      = "",
      parameter PORT_TG_CFG_WDATA_WIDTH      = "",
      parameter WRITE_GROUP_WIDTH            = "",
      parameter BYPASS_DEFAULT_PATTERN       = "",
      parameter BYPASS_USER_STAGE            = "",
      parameter AMM_BURST_COUNT_DIVISIBLE_BY = "",
      parameter AMM_WORD_ADDRESS_WIDTH       = "",

      parameter IS_AXI                       = 0
   )(
      input                                       clk,
      input                                       rst,
      input                                       amm_ctrl_ready,

      output reg                                  amm_cfg_slave_waitrequest,
      input      [PORT_TG_CFG_ADDRESS_WIDTH-1:0]  amm_cfg_slave_address,
      input        [PORT_TG_CFG_WDATA_WIDTH-1:0]  amm_cfg_slave_writedata,
      input                                       amm_cfg_slave_write,
      input                                       amm_cfg_slave_read,
      output reg   [PORT_TG_CFG_RDATA_WIDTH-1:0]  amm_cfg_slave_readdata,
      output reg                                  amm_cfg_slave_readdatavalid,

      input                                       amm_cfg_master_waitrequest,
      output reg [PORT_TG_CFG_ADDRESS_WIDTH-1:0]  amm_cfg_master_address,
      output reg   [PORT_TG_CFG_WDATA_WIDTH-1:0]  amm_cfg_master_writedata,
      output reg                                  amm_cfg_master_write,
      output reg                                  amm_cfg_master_read,
      input        [PORT_TG_CFG_RDATA_WIDTH-1:0]  amm_cfg_master_readdata,
      input                                       amm_cfg_master_readdatavalid,

      input                                       restart_default_traffic,
      input                                       tg_test_complete,
      output                                      at_done_stage,
      output                                      at_wait_user_stage,
      output                                      at_default_stage,
      output reg                                  rst_config,

      input         [AMM_WORD_ADDRESS_WIDTH-1:0]  first_fail_addr,
      input                                       failure_occured,
      input                                       inf_user_mode,

      output logic                                at_target_stage,

      input                                       target_first_failing_addr,
      input                                       timeout,
      output                                      user_cfg_start
   );

   timeunit 1ns;
   timeprecision 1ps;

   import avl_tg_defs::*;

   localparam NUM_DRIVER_LOOP      = (TG_TEST_DURATION == "INFINITE") ? 0    :
                                     (TG_TEST_DURATION == "MEDIUM")   ? 1000 :
                                     (TG_TEST_DURATION == "SHORT")    ? 1    : 1;

   localparam NUM_DRIVER_LOOP_LOC  = (NUM_DRIVER_LOOP == '0) ? 0 : NUM_DRIVER_LOOP - 1;

   // Test stages definition
   typedef enum int unsigned {
      INIT,
      DONE_DEFAULT_PATTERN,
      DONE,
      BYTEENABLE_STAGE,
      SINGLE_RW,
      BLOCK_RW,
      TARGET_STAGE,
      STOP_INF_MODE,
      IN_INF_MODE,
      RESET_CONFIG,
      WAIT_USER_STAGE,
      INIT_USER_STAGE,
      WAIT_FOR_DONE_USER_LOOP
   } tst_stage_t;

   tst_stage_t state /* synthesis ignore_power_up */;
   tst_stage_t next_state;

   logic [31:0] loop_counter;

   // Indicates that instruction pattern is not complete (i.e. reads and writes are required)
   reg more_default_pattern;

   // Byteenable stage signals
   wire [PORT_TG_CFG_ADDRESS_WIDTH-1:0]   byteenable_test_stage_address;
   wire [PORT_TG_CFG_WDATA_WIDTH-1:0]     byteenable_test_stage_writedata;
   wire                                   byteenable_test_stage_write;
   wire                                   byteenable_test_stage_read;
   wire                                   byteenable_test_stage_complete;

   // Single write/read stage signals
   wire [PORT_TG_CFG_ADDRESS_WIDTH-1:0]   single_rw_stage_address;
   wire [PORT_TG_CFG_WDATA_WIDTH-1:0]     single_rw_stage_writedata;
   wire                                   single_rw_stage_write;
   wire                                   single_rw_stage_read;
   wire                                   single_rw_stage_complete;


   // Block write/read stage signals
   wire [PORT_TG_CFG_ADDRESS_WIDTH-1:0]   block_rw_stage_address;
   wire [PORT_TG_CFG_WDATA_WIDTH-1:0]     block_rw_stage_writedata;
   wire                                   block_rw_stage_write;
   wire                                   block_rw_stage_read;
   wire                                   block_rw_stage_complete;

   // Target state signals
   wire [PORT_TG_CFG_ADDRESS_WIDTH-1:0]   target_stage_address;
   wire [PORT_TG_CFG_WDATA_WIDTH-1:0]     target_stage_writedata;
   wire                                   target_stage_write;
   wire                                   target_stage_read;
   wire                                   target_stage_complete;

   // Emergency Brake
   //TODO: explain this signal in user comments
   wire                                   emergency_brake_active;

   logic [PORT_TG_CFG_ADDRESS_WIDTH-1:0]  w_amm_cfg_address;
   logic [PORT_TG_CFG_WDATA_WIDTH-1:0]    w_amm_cfg_writedata;
   logic                                  w_amm_cfg_write;
   logic                                  w_amm_cfg_read;

   // Signals that a user-requested TG_START has been accepted
   assign   user_cfg_start = ~amm_cfg_slave_waitrequest && amm_cfg_slave_write && amm_cfg_slave_address == TG_START;

   // Indicates that the amm_cfg_* interface is controlled by the amm_cfg_slave_* interface (user control)
   logic use_amm_cfg_in;

   // The amm_cfg_in interface should be gated until the default pattern stages are complete
   always_comb begin
      amm_cfg_slave_waitrequest   = !(state == WAIT_USER_STAGE || state == DONE || (state == WAIT_FOR_DONE_USER_LOOP && !amm_cfg_slave_write) || (state == INIT_USER_STAGE         && !amm_cfg_slave_write) || state == IN_INF_MODE);
      use_amm_cfg_in              =  (state == WAIT_USER_STAGE || state == DONE ||  state == WAIT_FOR_DONE_USER_LOOP                          ||  state == INIT_USER_STAGE                                  || state == IN_INF_MODE);
      amm_cfg_master_address      = use_amm_cfg_in ? amm_cfg_slave_address        : w_amm_cfg_address;
      amm_cfg_master_writedata    = use_amm_cfg_in ? amm_cfg_slave_writedata      : w_amm_cfg_writedata;
      amm_cfg_master_write        = use_amm_cfg_in ? amm_cfg_slave_write          : w_amm_cfg_write;
      amm_cfg_master_read         = use_amm_cfg_in ? amm_cfg_slave_read           : w_amm_cfg_read;
      amm_cfg_slave_readdata      = use_amm_cfg_in ? amm_cfg_master_readdata      : '0;
      amm_cfg_slave_readdatavalid = use_amm_cfg_in ? amm_cfg_master_readdatavalid : '0;
   end

   assign emergency_brake_active = failure_occured & target_first_failing_addr;

   // Test stages signals mux
   always_comb begin
      case (state)
         BYTEENABLE_STAGE:
         begin
            w_amm_cfg_address   = byteenable_test_stage_address;
            w_amm_cfg_writedata = byteenable_test_stage_writedata;
            w_amm_cfg_write     = byteenable_test_stage_write;
            w_amm_cfg_read      = byteenable_test_stage_read;
            rst_config          = 1'b0;
         end
         SINGLE_RW:
         begin
            w_amm_cfg_address   = single_rw_stage_address;
            w_amm_cfg_writedata = single_rw_stage_writedata;
            w_amm_cfg_write     = single_rw_stage_write;
            w_amm_cfg_read      = single_rw_stage_read;
            rst_config          = 1'b0;
         end
         BLOCK_RW:
         begin
            w_amm_cfg_address   = block_rw_stage_address;
            w_amm_cfg_writedata = block_rw_stage_writedata;
            w_amm_cfg_write     = block_rw_stage_write;
            w_amm_cfg_read      = block_rw_stage_read;
            rst_config          = 1'b0;
         end
         TARGET_STAGE:
         begin
            w_amm_cfg_address   = target_stage_address;
            w_amm_cfg_writedata = target_stage_writedata;
            w_amm_cfg_write     = target_stage_write;
            w_amm_cfg_read      = target_stage_read;
            rst_config          = 1'b0;
         end
         RESET_CONFIG:
         begin
            w_amm_cfg_address   = '0;
            w_amm_cfg_writedata = '0;
            w_amm_cfg_write     = 1'b0;
            w_amm_cfg_read      = 1'b0;
            rst_config          = 1'b1;
         end
         STOP_INF_MODE:
         begin
            w_amm_cfg_address   = TG_LOOP_COUNT;
            w_amm_cfg_writedata = 1'b1;
            w_amm_cfg_write     = 1'b1;
            w_amm_cfg_read      = 1'b0;
            rst_config          = 1'b0;
         end
         default:
         begin
            w_amm_cfg_address   = '0;
            w_amm_cfg_writedata = '0;
            w_amm_cfg_write     = 1'b0;
            w_amm_cfg_read      = 1'b0;
            rst_config          = 1'b0;
         end
      endcase
   end

   // Test stages state machine
   // next state logic
   always_ff @(posedge clk) begin
      if(rst)
         state <= INIT;
      else
         state <= next_state;
   end

   always_comb begin
      next_state = state;
      case(state)
         INIT: begin
            if(amm_ctrl_ready) begin
               if (BYPASS_DEFAULT_PATTERN) begin
                  next_state = WAIT_USER_STAGE;
               end else begin
                  if (IS_AXI) begin
                     next_state = BLOCK_RW;
                  end else begin
                     next_state = SINGLE_RW;
                  end
               end
            end else begin
               next_state = INIT;
            end
         end
         SINGLE_RW:  begin
            if (timeout) begin
               next_state = RESET_CONFIG;
            end
            else begin
               if (emergency_brake_active)
                   next_state = TARGET_STAGE;
               else begin
                   if (single_rw_stage_complete) begin
                       next_state = BLOCK_RW;
                   end
                   else
                       next_state = SINGLE_RW;
               end
            end
         end
         BLOCK_RW: begin
            if (timeout) begin
               next_state = RESET_CONFIG;
            end
            else begin
               if (emergency_brake_active)
                   next_state = TARGET_STAGE;
               else begin
                   if (block_rw_stage_complete) begin
                       if (USE_AVL_BYTEEN)
                          next_state = BYTEENABLE_STAGE;
                       else
                          next_state = DONE_DEFAULT_PATTERN;
                   end
                   else
                       next_state = BLOCK_RW;
               end
            end
         end
         BYTEENABLE_STAGE: begin
            if (timeout) begin
               next_state = RESET_CONFIG;
            end
            else begin
               if (emergency_brake_active)
                   next_state = TARGET_STAGE;
               else begin
                   if (byteenable_test_stage_complete)
                       next_state = DONE_DEFAULT_PATTERN;
                   else
                       next_state = BYTEENABLE_STAGE;
               end
            end
         end
         TARGET_STAGE: begin
            if (timeout) begin
               next_state = RESET_CONFIG;
            end
            else begin
               if (target_stage_complete)
                  next_state = WAIT_USER_STAGE;
               else
                  next_state = TARGET_STAGE;
            end
         end
         STOP_INF_MODE: begin
            if (tg_test_complete)
               next_state = TARGET_STAGE;
            else
               next_state = STOP_INF_MODE;
         end
         DONE_DEFAULT_PATTERN:  begin
            if (more_default_pattern)
               next_state = INIT;
            else
               next_state = RESET_CONFIG;
         end
         RESET_CONFIG: begin
            next_state = WAIT_USER_STAGE;
         end
         WAIT_USER_STAGE: begin
            if (restart_default_traffic)
                next_state = INIT;
            else if (BYPASS_USER_STAGE)
               next_state = WAIT_USER_STAGE;
            else begin
               if (user_cfg_start)
                  next_state = INIT_USER_STAGE;
               else
                  next_state = WAIT_USER_STAGE;
            end
         end
         INIT_USER_STAGE: begin
            if(inf_user_mode)
               next_state = IN_INF_MODE;
            else
               next_state = WAIT_FOR_DONE_USER_LOOP;
         end
         IN_INF_MODE: begin
            if(emergency_brake_active) begin
               next_state = STOP_INF_MODE;
            end
            else begin
               if (tg_test_complete|timeout)
                  next_state = DONE;
               else
                  next_state = IN_INF_MODE;
            end
         end
         WAIT_FOR_DONE_USER_LOOP: begin
            if(emergency_brake_active) begin
               next_state = TARGET_STAGE;
            end
            else begin
               if (tg_test_complete|timeout)
                  next_state = DONE;
               else
                  next_state = WAIT_FOR_DONE_USER_LOOP;
            end
         end
         DONE: begin
            if (restart_default_traffic)
               next_state = INIT;
            else if (user_cfg_start)
               next_state = INIT_USER_STAGE;
            else
               next_state = DONE;
         end
         default:  begin
            next_state = INIT;
         end
      endcase
   end

   // status outputs
   //define all_tests_issued in user mode
   assign at_done_stage = (state == DONE) && !user_cfg_start;
   assign at_wait_user_stage = (state == WAIT_USER_STAGE) && !user_cfg_start;
   assign at_default_stage = (state == INIT || state == SINGLE_RW || state == BLOCK_RW || state == BYTEENABLE_STAGE || state == TARGET_STAGE || state == DONE_DEFAULT_PATTERN || state == WAIT_USER_STAGE);

   // Loop Control for Default Pattern
   always_ff @(posedge clk) begin
      if (rst || restart_default_traffic ||state == DONE)
        loop_counter <= '0;
      else if (state == DONE_DEFAULT_PATTERN)
        loop_counter <= loop_counter + 1'b1;
   end
   assign more_default_pattern = (NUM_DRIVER_LOOP == 0) || (!(loop_counter == NUM_DRIVER_LOOP_LOC));


   // TEST STAGE MODULE INSTANTIATIONS
   // These modules should comply with the following protocol:
   // - when 'rst' is deasserted, it should idle and listen to 'stage_enable'
   // - it should proceed with the test operations when 'stage_enable' is asserted
   // - when the test completes, it should assert 'stage_complete' and properly
   //drive the state failure output signal (usually just plugging back in the input state failure
   //which comes from the status checker, unless it is a multi run test) -this could be done above

   altera_emif_avl_tg_2_byteenable_test_stage #(
      .PORT_TG_CFG_ADDRESS_WIDTH    (PORT_TG_CFG_ADDRESS_WIDTH),
      .PORT_TG_CFG_RDATA_WIDTH      (PORT_TG_CFG_RDATA_WIDTH),
      .PORT_TG_CFG_WDATA_WIDTH      (PORT_TG_CFG_WDATA_WIDTH)
   ) byteenable_test_stage_inst(
      .clk                          (clk),
      .rst                          (rst),
      .enable                       (state == BYTEENABLE_STAGE),
      .amm_cfg_waitrequest          (~tg_test_complete),
      .amm_cfg_readdatavalid        (amm_cfg_master_readdatavalid),
      .amm_cfg_address              (byteenable_test_stage_address),
      .amm_cfg_writedata            (byteenable_test_stage_writedata),
      .amm_cfg_readdata             (amm_cfg_master_readdata),
      .amm_cfg_write                (byteenable_test_stage_write),
      .amm_cfg_read                 (byteenable_test_stage_read),
      .stage_complete               (byteenable_test_stage_complete),
      .emergency_brake_active       (emergency_brake_active)
   );

   //read/write test stages
   altera_emif_avl_tg_2_rw_stage # (
      .BLOCK_RW_MODE                (0),
      .TG_TEST_DURATION             (TG_TEST_DURATION),
      .PORT_TG_CFG_ADDRESS_WIDTH    (PORT_TG_CFG_ADDRESS_WIDTH),
      .PORT_TG_CFG_RDATA_WIDTH      (PORT_TG_CFG_RDATA_WIDTH),
      .PORT_TG_CFG_WDATA_WIDTH      (PORT_TG_CFG_WDATA_WIDTH)
   ) single_rw_stage (
      .clk                          (clk),
      .rst                          (rst),
      .enable                       (state == SINGLE_RW),
      .amm_cfg_waitrequest          (~tg_test_complete),
      .amm_cfg_readdatavalid        (amm_cfg_master_readdatavalid),
      .amm_cfg_address              (single_rw_stage_address),
      .amm_cfg_writedata            (single_rw_stage_writedata),
      .amm_cfg_readdata             (amm_cfg_master_readdata),
      .amm_cfg_write                (single_rw_stage_write),
      .amm_cfg_read                 (single_rw_stage_read),
      .stage_complete               (single_rw_stage_complete),
      .emergency_brake_active       (emergency_brake_active)
   );
   altera_emif_avl_tg_2_rw_stage # (
      .BLOCK_RW_MODE                (1),
      .TG_TEST_DURATION             (TG_TEST_DURATION),
      .PORT_TG_CFG_ADDRESS_WIDTH    (PORT_TG_CFG_ADDRESS_WIDTH),
      .PORT_TG_CFG_RDATA_WIDTH      (PORT_TG_CFG_RDATA_WIDTH),
      .PORT_TG_CFG_WDATA_WIDTH      (PORT_TG_CFG_WDATA_WIDTH)
   ) block_rw_stage (
      .clk                          (clk),
      .rst                          (rst),
      .enable                       (state == BLOCK_RW),
      .amm_cfg_waitrequest          (~tg_test_complete),
      .amm_cfg_readdatavalid        (amm_cfg_master_readdatavalid),
      .amm_cfg_address              (block_rw_stage_address),
      .amm_cfg_writedata            (block_rw_stage_writedata),
      .amm_cfg_readdata             (amm_cfg_master_readdata),
      .amm_cfg_write                (block_rw_stage_write),
      .amm_cfg_read                 (block_rw_stage_read),
      .stage_complete               (block_rw_stage_complete),
      .emergency_brake_active       (emergency_brake_active)
   );

   assign at_target_stage = (state == TARGET_STAGE);

   // targetted reads test state
   altera_emif_avl_tg_2_targetted_reads_test_stage # (
      .MEM_ADDR_WIDTH               (AMM_WORD_ADDRESS_WIDTH),
      .PORT_TG_CFG_ADDRESS_WIDTH    (PORT_TG_CFG_ADDRESS_WIDTH),
      .PORT_TG_CFG_RDATA_WIDTH      (PORT_TG_CFG_RDATA_WIDTH),
      .PORT_TG_CFG_WDATA_WIDTH      (PORT_TG_CFG_WDATA_WIDTH)
   ) target_reads (
      .clk                          (clk),
      .rst                          (rst),
      .enable                       (at_target_stage),
      .amm_cfg_waitrequest          (~tg_test_complete),
      .amm_cfg_readdatavalid        (amm_cfg_master_readdatavalid),
      .amm_cfg_address              (target_stage_address),
      .amm_cfg_writedata            (target_stage_writedata),
      .amm_cfg_readdata             (amm_cfg_master_readdata),
      .amm_cfg_write                (target_stage_write),
      .amm_cfg_read                 (target_stage_read),
      .stage_complete               (target_stage_complete),
      .target_address               (first_fail_addr)
   );

endmodule



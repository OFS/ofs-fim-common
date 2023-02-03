// (C) 2001-2021 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


//////////////////////////////////////////////////////////////////////////////
// This test is used for both single write/read test stage and the block write/read
// test stage. The single write read stage performs a parametrizable number of
// interleaving write and read operation.  The number of write/read cycles
// that various address generators are used are parametrizable.
// The block write/read test stage performs a parametrizable number of write
// operations, followed by the same number of read operations to the same
// addresses.  The write/read cycle repeats for a parametrizable number of
// times.  The number of write/read cycles that various address generators
// are used are also parametrizable.
// If stress_mode is enabled, this stage issues data patterns designed to stress
// the signal integrity of the interface.
//////////////////////////////////////////////////////////////////////////////


module altera_emif_avl_tg_2_targetted_reads_test_stage # (

   // The number of write/read cycles that each address generator is used
   parameter MEM_ADDR_WIDTH                 = "",
   parameter PORT_TG_CFG_ADDRESS_WIDTH      = 1,
   parameter PORT_TG_CFG_RDATA_WIDTH        = 1,
   parameter PORT_TG_CFG_WDATA_WIDTH        = 1
) (
   // Clock and reset
   input                                          clk,
   input                                          rst,

   input [MEM_ADDR_WIDTH-1:0]                     target_address,

   input                                          enable,
   output                                         stage_complete,
   input                                          amm_cfg_waitrequest,
   output logic [PORT_TG_CFG_ADDRESS_WIDTH-1:0]   amm_cfg_address,
   output logic [PORT_TG_CFG_WDATA_WIDTH-1:0]     amm_cfg_writedata,
   input logic  [PORT_TG_CFG_RDATA_WIDTH-1:0]     amm_cfg_readdata,
   input logic                                    amm_cfg_readdatavalid,
   output logic                                   amm_cfg_write,
   output logic                                   amm_cfg_read

);

   timeunit 1ns;
   timeprecision 1ps;

   import avl_tg_defs::*;

   int unsigned param_row_common;
   int unsigned addr_row_common_save;
   int unsigned addr_row_common_save_delayed; // Delayed counter to account for access time
   int unsigned addr_row_common_load;
   localparam ADDR_L_TOP  = (MEM_ADDR_WIDTH > 'd32)? 31 : MEM_ADDR_WIDTH-1;
   localparam ADDR_H_BASE = (MEM_ADDR_WIDTH > 'd32)? 32 : 0;

   typedef enum int unsigned {
      INIT,
      SAVE_USER_CONFIG,
      WRITE_CFG_ADDR_RD_L,
      WRITE_CFG_ADDR_RD_H,
      WRITE_CFG_COMMON,
      WAIT_FOR_WAIT_REQUEST,
      LOAD_USER_CONFIG,
      WAIT_START,
      WAIT_FINISH,
      DONE
   } cfg_state_t;

   // State definitions
   cfg_state_t state /* synthesis ignore_power_up */;
   cfg_state_t next_state;

   // User CSR values pre targetted reads stage
   // Width is one shorter than params_target_common to exclude TG_START
   logic [TG_DEF_PARAMS_TARGET_COMMON_N_ROWS-2:0][PORT_TG_CFG_RDATA_WIDTH-1:0] user_csr_configs;
   logic prev_waitrequest;
   
   always_ff @(posedge clk) begin: check_waitrequest_falling_edge
      if(rst)
         prev_waitrequest <= '0;
      else
         prev_waitrequest <= amm_cfg_waitrequest;
   end

   always_ff @(posedge clk) begin: next_state_propagate
      if(rst)
         state <= INIT;
     else
         state <= next_state;
   end // next_state_propagate

   always_comb begin: next_state_logic
      case (state)
         INIT: begin
            if (enable & ~amm_cfg_waitrequest)
               next_state = SAVE_USER_CONFIG;
            else
               next_state = INIT;
         end
         SAVE_USER_CONFIG: begin
            if (addr_row_common_save_delayed == TG_DEF_PARAMS_TARGET_COMMON_N_ROWS-2) begin
               next_state = WRITE_CFG_ADDR_RD_L;
            end else begin
               next_state = SAVE_USER_CONFIG;
            end
         end
         WRITE_CFG_ADDR_RD_L: begin
            if(MEM_ADDR_WIDTH > 'd32)
               next_state = WRITE_CFG_ADDR_RD_H;
            else
               next_state = WRITE_CFG_COMMON;
         end
         WRITE_CFG_ADDR_RD_H: begin
            next_state = WRITE_CFG_COMMON;
         end
         WRITE_CFG_COMMON: begin
            if(param_row_common == TG_DEF_PARAMS_TARGET_COMMON_N_ROWS-1)
               next_state = WAIT_FOR_WAIT_REQUEST;
            else
               next_state = WRITE_CFG_COMMON;
         end
         WAIT_FOR_WAIT_REQUEST: begin
             // Catch falling edge of waitrequest so LOAD_USER_CONFIG can have control of the interface to write to CSRs
             if(prev_waitrequest & ~amm_cfg_waitrequest)
                next_state = LOAD_USER_CONFIG;
             else
                next_state = WAIT_FOR_WAIT_REQUEST;
         end
         LOAD_USER_CONFIG: begin
            if(addr_row_common_load == TG_DEF_PARAMS_TARGET_COMMON_N_ROWS-2)
               next_state = DONE;
            else
               next_state = LOAD_USER_CONFIG;
         end
         DONE:
            next_state = INIT;
         default:
            next_state = INIT;
      endcase
   end

   // Status outputs
   //assign amm_cfg_read   = '0; // never need to read on this interface during this stage
   assign stage_complete = (state == DONE);
   always_ff @(posedge clk) begin: output_logic_param_indices
      if(rst)
         param_row_common <= '0;
      else
         param_row_common <= (state == WRITE_CFG_COMMON)? param_row_common + 1'b1: '0;
   end

   always_ff @(posedge clk) begin: output_logic_addr_indices
      if(rst) begin
         addr_row_common_save         <= '0;
         addr_row_common_save_delayed <= '0;
         addr_row_common_load         <= '0;
      end else begin
         addr_row_common_save         <= (state == SAVE_USER_CONFIG)? addr_row_common_save + 1'b1: '0;
         addr_row_common_save_delayed <= (state == SAVE_USER_CONFIG && amm_cfg_readdatavalid)? addr_row_common_save_delayed + 1'b1: '0;
         addr_row_common_load <= (state == LOAD_USER_CONFIG)? addr_row_common_load + 1'b1: '0;
      end
   end

   always_ff @(posedge clk) begin: output_logic_amm_cfgs
      if(rst) begin
         user_csr_configs  <= '0;
         amm_cfg_address   <= '0;
         amm_cfg_writedata <= '0;
         amm_cfg_write     <= '0;
      end else begin
         if(~amm_cfg_waitrequest & (state == WRITE_CFG_COMMON)) begin
            amm_cfg_address   <= def_params_target_common[param_row_common][0][PORT_TG_CFG_ADDRESS_WIDTH-1:0];
            amm_cfg_writedata <= def_params_target_common[param_row_common][1][PORT_TG_CFG_WDATA_WIDTH-1:0];
            amm_cfg_write     <= 1'b1;
         end else if (~amm_cfg_waitrequest & (state == WRITE_CFG_ADDR_RD_L)) begin
            amm_cfg_address   <= TG_SEQ_START_ADDR_RD_L;
            amm_cfg_writedata <= target_address[ADDR_L_TOP:0];
            amm_cfg_write     <= 1'b1;
         end else if(~amm_cfg_waitrequest & (state == WRITE_CFG_ADDR_RD_H)) begin
            amm_cfg_address   <= TG_SEQ_START_ADDR_RD_H;
            amm_cfg_writedata <= target_address[MEM_ADDR_WIDTH-1:ADDR_H_BASE];
            amm_cfg_write     <= 1'b1;
         end else if(~amm_cfg_waitrequest & (state == SAVE_USER_CONFIG)) begin 
            amm_cfg_address   <= def_params_target_common[addr_row_common_save][0][PORT_TG_CFG_ADDRESS_WIDTH-1:0];
            amm_cfg_write     <= 1'b0;
            amm_cfg_read      <= 1'b1;
            if (amm_cfg_readdatavalid) begin
               for (integer i = 0; i < TG_DEF_PARAMS_TARGET_COMMON_N_ROWS-1; i++) begin
                  if(def_params_target_common[i][0] == def_params_target_common[addr_row_common_save_delayed][0]) begin
                     user_csr_configs[i] <= amm_cfg_readdata;
                  end
               end
            end
         end else if(~amm_cfg_waitrequest & (state == LOAD_USER_CONFIG)) begin 
            amm_cfg_address   <= def_params_target_common[addr_row_common_load][0][PORT_TG_CFG_ADDRESS_WIDTH-1:0];
            for (integer i = 0; i < TG_DEF_PARAMS_TARGET_COMMON_N_ROWS-1; i++) begin
               if(def_params_target_common[i][0] == def_params_target_common[addr_row_common_load][0]) begin
                  amm_cfg_writedata <= user_csr_configs[i];
               end
            end
            amm_cfg_write     <= 1'b1;
         end else begin
            amm_cfg_address   <= '0;
            amm_cfg_writedata <= '0;
            amm_cfg_write     <= '0;
         end
      end
   end
endmodule

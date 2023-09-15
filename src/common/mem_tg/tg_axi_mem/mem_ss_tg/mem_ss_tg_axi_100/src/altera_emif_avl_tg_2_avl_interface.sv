// Copyright (C) 2001-2021 Intel Corporation
// SPDX-License-Identifier: MIT


//////////////////////////////////////////////////////////////////////////////
// This module translates the commands issued by the state machines into
// Avalon-MM or Avalon-ST signals.
//////////////////////////////////////////////////////////////////////////////

module altera_emif_avl_tg_2_avl_if # (
   parameter BYTE_ADDR_WIDTH              = "",
   parameter DATA_WIDTH                   = "",
   parameter BE_WIDTH                     = "",
   parameter AMM_WORD_ADDRESS_WIDTH       = "",
   parameter AMM_BURSTCOUNT_WIDTH         = ""
) (
   // Clock
   input clk,

   //from traffic generator
   input write_req,
   input read_req,
   input [AMM_WORD_ADDRESS_WIDTH-1:0] mem_addr,
   output controller_ready,

   input [DATA_WIDTH-1:0] mem_write_data,
   input [BE_WIDTH-1:0] mem_write_be,
   input [AMM_BURSTCOUNT_WIDTH-1:0] burstlength,

   //to avalon memory controller
   output amm_ctrl_write,
   output amm_ctrl_read,
   input amm_ctrl_ready,
   output [BYTE_ADDR_WIDTH-1:0] amm_ctrl_address,
   output [DATA_WIDTH-1:0] amm_ctrl_writedata,
   output [BE_WIDTH-1:0]  amm_ctrl_byteenable,
   output [AMM_BURSTCOUNT_WIDTH-1:0] amm_ctrl_burstcount,

   input [DATA_WIDTH-1:0] written_data,
   input [BE_WIDTH-1:0] written_be,
   output [BE_WIDTH-1:0] ast_exp_data_byteenable,
   output [DATA_WIDTH-1:0] ast_exp_data_writedata,

   input                        amm_ctrl_readdatavalid,
   input [DATA_WIDTH-1:0]       amm_ctrl_readdata,

   //Actual data for comparison in status checker
   output                       ast_act_data_readdatavalid,
   output [DATA_WIDTH-1:0]      ast_act_data_readdata,

   input read_addr_fifo_full

);
   timeunit 1ns;
   timeprecision 1ps;

   //assign the write data such that data generated from each per pin pattern generator
   //will be written to corresponding dq pin

   assign amm_ctrl_writedata        =  mem_write_data;
   assign amm_ctrl_byteenable       =  mem_write_be;
   assign ast_exp_data_writedata    =  written_data;
   assign ast_exp_data_byteenable   =  written_be;

   //when the address fifo is full, the ready signal to the traffic generator is deasserted
   //this potentially leaves the read or write signals to the memory controller asserted for its duration
   //when we actually do not want to be issuing operations, only holding current state
   assign amm_ctrl_write             = write_req & ~read_addr_fifo_full;
   assign amm_ctrl_read              = read_req & ~read_addr_fifo_full;
   assign controller_ready           = amm_ctrl_ready & ~read_addr_fifo_full;

   assign ast_act_data_readdata      = amm_ctrl_readdata;
   assign ast_act_data_readdatavalid = amm_ctrl_readdatavalid;

   assign amm_ctrl_burstcount        = burstlength;

   //generate correctly aligned address
   assign amm_ctrl_address           = {mem_addr, {(BYTE_ADDR_WIDTH - AMM_WORD_ADDRESS_WIDTH){1'b0}}};
endmodule


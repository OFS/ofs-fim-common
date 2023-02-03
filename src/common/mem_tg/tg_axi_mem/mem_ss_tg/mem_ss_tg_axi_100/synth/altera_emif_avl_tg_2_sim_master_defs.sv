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
// This package contains user configurations for the
// sim master module.
//////////////////////////////////////////////////////////////////////////////

package avl_tg_sim_master_defs;
   import avl_tg_defs::*;
   localparam TG_DEF_SIM_MASTER_PARAM_N_ROW = 55;
   localparam [31:0] tg_def_sim_master_user_param [TG_DEF_SIM_MASTER_PARAM_N_ROW][2] = '{
      '{ TG_LOOP_COUNT   ,   32'd1 }, 
      '{ TG_READ_COUNT   ,   32'd1 }, 
      '{ TG_WRITE_COUNT   ,   32'd1 }, 
      '{ TG_READ_REPEAT_COUNT   ,   32'd1 }, 
      '{ TG_WRITE_REPEAT_COUNT   ,   32'd1 }, 
      '{ TG_BURST_LENGTH   ,   32'd1 }, 
      '{ TG_RW_GEN_IDLE_COUNT   ,   32'd0 }, 
      '{ TG_RW_GEN_LOOP_IDLE_COUNT   ,   32'd0 }, 
      '{ TG_SEQ_START_ADDR_WR_L   ,   32'd0 }, 
      '{ TG_SEQ_START_ADDR_RD_L   ,   32'd0 }, 
      '{ TG_SEQ_START_ADDR_WR_H   ,   32'd0 }, 
      '{ TG_SEQ_START_ADDR_RD_H   ,   32'd0 }, 
      '{ TG_RETURN_TO_START_ADDR   , 32'd0 }, 
      '{ TG_ADDR_MODE_RD   ,   TG_ADDR_SEQ }, 
      '{ TG_ADDR_MODE_WR   ,   TG_ADDR_SEQ }, 
      '{ TG_RAND_SEQ_ADDRS_RD   ,   32'd1 }, 
      '{ TG_RAND_SEQ_ADDRS_WR   ,   32'd1 }, 
      '{ TG_SEQ_ADDR_INCR   ,   32'd32 }, 
      '{ TG_INVERT_BYTEEN   ,   32'd0 }, 
      '{ TG_USER_WORM_EN   ,   32'd0 }, 
      '{ TG_DATA_SEED   ,   32'h0000000a }, 
      '{ TG_DATA_SEED+1   ,   32'h0000005a }, 
      '{ TG_DATA_SEED+2   ,   32'h00000a5a }, 
      '{ TG_DATA_SEED+3   ,   32'h00005a5a }, 
      '{ TG_DATA_SEED+4   ,   32'h000a5a5a }, 
      '{ TG_DATA_SEED+5   ,   32'h005a5a5a }, 
      '{ TG_DATA_SEED+6   ,   32'h0a5a5a5a }, 
      '{ TG_DATA_SEED+7   ,   32'h5a5a5a5a }, 
      '{ TG_BYTEEN_SEED   ,   32'hffffffff }, 
      '{ TG_BYTEEN_SEED+1   ,   32'hffffffff }, 
      '{ TG_BYTEEN_SEED+2   ,   32'hffffffff }, 
      '{ TG_BYTEEN_SEED+3   ,   32'hffffffff }, 
      '{ TG_BYTEEN_SEED+4   ,   32'hffffffff }, 
      '{ TG_BYTEEN_SEED+5   ,   32'hffffffff }, 
      '{ TG_BYTEEN_SEED+6   ,   32'hffffffff }, 
      '{ TG_BYTEEN_SEED+7   ,   32'hffffffff }, 
      '{ TG_BYTEEN_SEED+8   ,   32'hffffffff }, 
      '{ TG_PPPG_SEL   ,   TG_DATA_PRBS7 }, 
      '{ TG_PPPG_SEL+1 ,   TG_DATA_PRBS7 }, 
      '{ TG_PPPG_SEL+2 ,   TG_DATA_PRBS7 }, 
      '{ TG_PPPG_SEL+3 ,   TG_DATA_PRBS7 }, 
      '{ TG_PPPG_SEL+4 ,   TG_DATA_PRBS7 }, 
      '{ TG_PPPG_SEL+5 ,   TG_DATA_PRBS7 }, 
      '{ TG_PPPG_SEL+6 ,   TG_DATA_PRBS7 }, 
      '{ TG_PPPG_SEL+7 ,   TG_DATA_PRBS7 }, 
      '{ TG_BYTEEN_SEL   ,   TG_DATA_PRBS7 }, 
      '{ TG_BYTEEN_SEL+1 ,   TG_DATA_PRBS7 }, 
      '{ TG_BYTEEN_SEL+2 ,   TG_DATA_PRBS7 }, 
      '{ TG_BYTEEN_SEL+3 ,   TG_DATA_PRBS7 }, 
      '{ TG_BYTEEN_SEL+4 ,   TG_DATA_PRBS7 }, 
      '{ TG_BYTEEN_SEL+5 ,   TG_DATA_PRBS7 }, 
      '{ TG_BYTEEN_SEL+6 ,   TG_DATA_PRBS7 }, 
      '{ TG_BYTEEN_SEL+7 ,   TG_DATA_PRBS7 }, 
      '{ TG_BYTEEN_SEL+8 ,   TG_DATA_PRBS7 }, 
      '{ TG_START   ,   32'd1 }  
   };
endpackage

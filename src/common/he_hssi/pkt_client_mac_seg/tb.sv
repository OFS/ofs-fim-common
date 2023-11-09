// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`timescale 1ps/1ps

module tb;
   import gdr_pkt_pkg::*;
   
      
   logic clk, clkf, rst, clk_avmm;
      
   always @(*) begin
      clkf <= #1000 !clkf;
   end

   always @(*) begin
      clk <= #2000 !clk;
   end
   
   always @(*) begin
      clk_avmm <= #4500 !clk_avmm;
   end

   localparam CSR_RD = 1;
   localparam CSR_WR = 1;
   
    //----------------------------------------------------------------------------------------
    // csr interface
   logic [9:0] address;
   logic [31:0] writedata;
   logic 	read;
   logic 	write;
   
   logic [31:0] readdata;
   logic 	readdatavalid;
   logic 	waitrequest;
   
   //----------------------------------------------------------------------------------------
   // tmii
   logic 	tx_mii_ready;
   
   PCS_D_16_WRD_s tx_mii_d;
   PCS_C_16_WRD_s tx_mii_c;
   PCS_SYNC_16_WRD_s tx_mii_sync;
   logic 	tx_mii_vld;
   logic 	tx_mii_am;
   
   //----------------------------------------------------------------------------------------
   // rmii 
   PCS_D_16_WRD_s rx_mii_d;
   PCS_SYNC_16_WRD_s rx_mii_sync;
   PCS_C_16_WRD_s rx_mii_c;
   logic 	rx_mii_vld;
   logic 	rx_mii_am;
   
   CFG_MODE_0_s cfg_mode_reg_0;
   CFG_MODE_1_s cfg_mode_reg_1;
   CFG_MODE_2_s cfg_mode_reg_2;
   CFG_MODE_3_s cfg_mode_reg_3;
   CFG_START_PKT_GEN_s cfg_start_pkt_gen_reg;
   CFG_START_XFER_PKT_s cfg_xfer_pkt_reg;
   CFG_CNT_STATS_s cnt_reg;
   logic 	test_fail, test_fail_stats;
   CFG_DREG_s readdata_reg;

   always_ff @(posedge clk_avmm) begin
     if (test_fail)
       test_fail_stats <= '1;
   
      if (rst)
	test_fail_stats <= '0;
   end
   
   initial begin
      $vcdpluson;
      $display("Starting \n");    
      
      $display("DONE Init sequence\n");    
      Init;

      
      $display("*****************************************************");
      $display("**** Test 1.1: MODE_PCS; MODE_400G; FIX_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_PCS), 
	     MODE_e'(MODE_400G), 
	     PKT_LEN_MODE_e'(FIX_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd256,   // fix_pkt_len
	     13'd16,    // no_of_pkt_gen	     
	     16'd500    // no_of_xfer_pkt
	     );
             
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 1.2: MODE_PCS; MODE_400G; INC_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_PCS), 
	     MODE_e'(MODE_400G), 
	     PKT_LEN_MODE_e'(INC_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd64,    // fix_pkt_len
	     13'd512,   // no_of_pkt_gen	     
	     16'd1024    // no_of_xfer_pkt
	     );
       
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 1.3: MODE_PCS; MODE_400G; RND_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_PCS), 
	     MODE_e'(MODE_400G), 
	     PKT_LEN_MODE_e'(RND_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd64,    // fix_pkt_len
	     13'd1024,  // no_of_pkt_gen max no of pkt = 1024  @2K 	     
	     16'd2048   // no_of_xfer_pkt
	     );      
       
      $display("*******************************************************");
      $display("**** Test 1.4: MODE_FLEXE; MODE_400G; FIX_PKT_LEN; ****");
      $display("*******************************************************");
      test_1(MODE_OP_e'(MODE_FLEXE), 
	     MODE_e'(MODE_400G), 
	     PKT_LEN_MODE_e'(FIX_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd256,   // fix_pkt_len
	     13'd16,    // no_of_pkt_gen	     
	     16'd500    // no_of_xfer_pkt
	     );  
      
      repeat (200) @(posedge clk_avmm);
      $display("*******************************************************");
      $display("**** Test 1.5: MODE_FLEXE; MODE_400G; INC_PKT_LEN; ****");
      $display("*******************************************************");
      test_1(MODE_OP_e'(MODE_FLEXE), 
	     MODE_e'(MODE_400G), 
	     PKT_LEN_MODE_e'(INC_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd64,    // fix_pkt_len
	     13'd512,     // no_of_pkt_gen	     
	     16'd1024    // no_of_xfer_pkt
	     );
       
      repeat (200) @(posedge clk_avmm);
      $display("*******************************************************");
      $display("**** Test 1.6: MODE_FLEXE; MODE_400G; RND_PKT_LEN; ****");
      $display("*******************************************************");
      test_1(MODE_OP_e'(MODE_FLEXE), 
	     MODE_e'(MODE_400G), 
	     PKT_LEN_MODE_e'(RND_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd64,    // fix_pkt_len
	     13'd1024,  // no_of_pkt_gen max no of pkt = 1024  @2K 	     
	     16'd2048   // no_of_xfer_pkt
	     ); 
       
      $display("*****************************************************");
      $display("**** Test 1.7: MODE_OTN; MODE_400G; FIX_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_OTN), 
	     MODE_e'(MODE_400G), 
	     PKT_LEN_MODE_e'(FIX_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd256,   // fix_pkt_len
	     13'd16,    // no_of_pkt_gen	     
	     16'd500      // no_of_xfer_pkt
	     );
       
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 1.8: MODE_OTN; MODE_400G; INC_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_OTN), 
	     MODE_e'(MODE_400G), 
	     PKT_LEN_MODE_e'(INC_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd64,    // fix_pkt_len
	     13'd512,   // no_of_pkt_gen	     
	     16'd1024    // no_of_xfer_pkt
	     );
       
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 1.9: MODE_OTN; MODE_400G; RND_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_OTN), 
	     MODE_e'(MODE_400G), 
	     PKT_LEN_MODE_e'(RND_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd64,    // fix_pkt_len
	     13'd1024,  // no_of_pkt_gen max no of pkt = 1024  @2K 	     
	     16'd2048   // no_of_xfer_pkt
	     );  
  
  
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 2.1: MODE_PCS; MODE_200G; FIX_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_PCS), 
	     MODE_e'(MODE_200G),
	     PKT_LEN_MODE_e'(FIX_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd256,   // fix_pkt_len
	     13'd16,    // no_of_pkt_gen	     
	     16'd500    // no_of_xfer_pkt	     	     
	     );
      
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 2.2: MODE_PCS; MODE_200G; INC_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_PCS), 
	     MODE_e'(MODE_200G),
	     PKT_LEN_MODE_e'(INC_PKT_LEN),
	     8'd1,       // no_of_inc_bytes
	     11'd64,     // fix_pkt_len
	     13'd512,    // no_of_pkt_gen	     
	     16'd1024    // no_of_xfer_pkt	     	     
	     );

      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 2.3: MODE_PCS; MODE_200G; RND_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_PCS), 
	     MODE_e'(MODE_200G),
	     PKT_LEN_MODE_e'(RND_PKT_LEN),
	     8'd1,       // no_of_inc_bytes
	     11'd64,     // fix_pkt_len
	     13'd512,   // no_of_pkt_gen max no of pkt = 512  @2K 	     
	     16'd2048    // no_of_xfer_pkt	     	     
	     );
      
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 2.4: MODE_FLEXE; MODE_200G; FIX_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_PCS), 
	     MODE_e'(MODE_200G),
	     PKT_LEN_MODE_e'(FIX_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd256,   // fix_pkt_len
	     13'd16,    // no_of_pkt_gen	     
	     16'd500    // no_of_xfer_pkt	     	     
	     );
      
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 2.5: MODE_FLEXE; MODE_200G; INC_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_FLEXE), 
	     MODE_e'(MODE_200G),
	     PKT_LEN_MODE_e'(INC_PKT_LEN),
	     8'd1,       // no_of_inc_bytes
	     11'd64,     // fix_pkt_len
	     13'd512,    // no_of_pkt_gen	     
	     16'd1024    // no_of_xfer_pkt	     	     
	     );

      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 2.6: MODE_FLEXE; MODE_200G; RND_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_FLEXE), 
	     MODE_e'(MODE_200G),
	     PKT_LEN_MODE_e'(RND_PKT_LEN),
	     8'd1,       // no_of_inc_bytes
	     11'd64,     // fix_pkt_len
	     13'd512,   // no_of_pkt_gen max no of pkt = 512  @2K 	     
	     16'd2048    // no_of_xfer_pkt	     	     
	     );

      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 2.7: MODE_OTN; MODE_200G; FIX_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_OTN), 
	     MODE_e'(MODE_200G),
	     PKT_LEN_MODE_e'(FIX_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd256,   // fix_pkt_len
	     13'd16,    // no_of_pkt_gen	     
	     16'd500    // no_of_xfer_pkt	     	     
	     );
      
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 2.8: MODE_OTN; MODE_200G; INC_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_OTN), 
	     MODE_e'(MODE_200G),
	     PKT_LEN_MODE_e'(INC_PKT_LEN),
	     8'd1,       // no_of_inc_bytes
	     11'd64,     // fix_pkt_len
	     13'd512,    // no_of_pkt_gen	     
	     16'd1024    // no_of_xfer_pkt	     	     
	     );

      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 2.9: MODE_OTN; MODE_200G; RND_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_OTN), 
	     MODE_e'(MODE_200G),
	     PKT_LEN_MODE_e'(RND_PKT_LEN),
	     8'd1,       // no_of_inc_bytes
	     11'd64,     // fix_pkt_len
	     13'd512,   // no_of_pkt_gen max no of pkt = 512  @2K 	     
	     16'd2048    // no_of_xfer_pkt	     	     
	     );
  
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 3.1: MODE_PCS; MODE_100G; FIX_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_PCS), 
	     MODE_e'(MODE_100G),
	     PKT_LEN_MODE_e'(FIX_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd256,   // fix_pkt_len
	     13'd16,    // no_of_pkt_gen	     
	     16'd500    // no_of_xfer_pkt	     
	     );

      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 3.2: MODE_PCS; MODE_100G; INC_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_PCS), 
	     MODE_e'(MODE_100G),
	     PKT_LEN_MODE_e'(INC_PKT_LEN),
	     8'd1,       // no_of_inc_bytes
	     11'd64,     // fix_pkt_len
	     13'd512,    // no_of_pkt_gen	     
	     16'd1024    // no_of_xfer_pkt	     	     
	     );
       
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 3.3: MODE_PCS; MODE_100G; RND_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_PCS), 
	     MODE_e'(MODE_100G),
	     PKT_LEN_MODE_e'(RND_PKT_LEN),
	     8'd1,       // no_of_inc_bytes
	     11'd64,     // fix_pkt_len
	     13'd256,    // no_of_pkt_gen, max no of pkt = 256  @2K  
	     16'd2048    // no_of_xfer_pkt	     	     
	     );
      
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 3.4: MODE_FLEXE; MODE_100G; FIX_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_FLEXE), 
	     MODE_e'(MODE_100G),
	     PKT_LEN_MODE_e'(FIX_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd256,   // fix_pkt_len
	     13'd16,    // no_of_pkt_gen	     
	     16'd500    // no_of_xfer_pkt	     
	     );

      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 3.5: MODE_FLEXE; MODE_100G; INC_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_FLEXE), 
	     MODE_e'(MODE_100G),
	     PKT_LEN_MODE_e'(INC_PKT_LEN),
	     8'd1,       // no_of_inc_bytes
	     11'd64,     // fix_pkt_len
	     13'd512,    // no_of_pkt_gen	     
	     16'd1024    // no_of_xfer_pkt	     	     
	     );
       
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 3.6: MODE_FLEXE; MODE_100G; RND_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_PCS), 
	     MODE_e'(MODE_100G),
	     PKT_LEN_MODE_e'(RND_PKT_LEN),
	     8'd1,       // no_of_inc_bytes
	     11'd64,     // fix_pkt_len
	     13'd256,    // no_of_pkt_gen, max no of pkt = 256  @2K  
	     16'd2048    // no_of_xfer_pkt	     	     
	     );

      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 3.7: MODE_OTN; MODE_100G; FIX_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_OTN), 
	     MODE_e'(MODE_100G),
	     PKT_LEN_MODE_e'(FIX_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd256,   // fix_pkt_len
	     13'd16,    // no_of_pkt_gen	     
	     16'd500    // no_of_xfer_pkt	     
	     );

      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 3.8: MODE_OTN; MODE_100G; INC_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_OTN), 
	     MODE_e'(MODE_100G),
	     PKT_LEN_MODE_e'(INC_PKT_LEN),
	     8'd1,       // no_of_inc_bytes
	     11'd64,     // fix_pkt_len
	     13'd512,    // no_of_pkt_gen	     
	     16'd1024    // no_of_xfer_pkt	     	     
	     );
       
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 3.9: MODE_OTN; MODE_100G; RND_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_OTN), 
	     MODE_e'(MODE_100G),
	     PKT_LEN_MODE_e'(RND_PKT_LEN),
	     8'd1,       // no_of_inc_bytes
	     11'd64,     // fix_pkt_len
	     13'd256,    // no_of_pkt_gen, max no of pkt = 256  @2K  
	     16'd2048    // no_of_xfer_pkt	     	     
	     );
  
      repeat (200) @(posedge clk_avmm);
      $display("*******************************************************");
      $display("**** Test 4.1: MODE_PCS; MODE_40/50G; FIX_PKT_LEN; ****");
      $display("*******************************************************");
      test_1(MODE_OP_e'(MODE_PCS), 
	     MODE_e'(MODE_40_50G),
	     PKT_LEN_MODE_e'(FIX_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd256,   // fix_pkt_len
	     13'd16,    // no_of_pkt_gen	     
	     16'd500    // no_of_xfer_pkt
	     
	     );

      repeat (200) @(posedge clk_avmm);
      $display("*******************************************************");
      $display("**** Test 4.2: MODE_PCS; MODE_40/50G; INC_PKT_LEN; ****");
      $display("*******************************************************");
      test_1(MODE_OP_e'(MODE_PCS), 
	     MODE_e'(MODE_40_50G),
	     PKT_LEN_MODE_e'(INC_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd64,    // fix_pkt_len
	     13'd128,    // no_of_pkt_gen	     
	     16'd1024    // no_of_xfer_pkt	     
	     );

      repeat (200) @(posedge clk_avmm);
      $display("*******************************************************");
      $display("**** Test 4.3: MODE_PCS; MODE_40/50G; RND_PKT_LEN; ****");
      $display("*******************************************************");
      test_1(MODE_OP_e'(MODE_PCS), 
	     MODE_e'(MODE_40_50G),
	     PKT_LEN_MODE_e'(RND_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd64,    // fix_pkt_len
	     13'd128,    // no_of_pkt_gen	     
	     16'd2048    // no_of_xfer_pkt	     
	     );
       
      repeat (200) @(posedge clk_avmm);
      $display("*******************************************************");
      $display("**** Test 4.4: MODE_FLEXE; MODE_40/50G; FIX_PKT_LEN; ****");
      $display("*******************************************************");
      test_1(MODE_OP_e'(MODE_FLEXE), 
	     MODE_e'(MODE_40_50G),
	     PKT_LEN_MODE_e'(FIX_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd256,   // fix_pkt_len
	     13'd16,    // no_of_pkt_gen	     
	     16'd500    // no_of_xfer_pkt
	     
	     );

      repeat (200) @(posedge clk_avmm);
      $display("*******************************************************");
      $display("**** Test 4.5: MODE_FLEXE; MODE_40/50G; INC_PKT_LEN; ****");
      $display("*******************************************************");
      test_1(MODE_OP_e'(MODE_FLEXE), 
	     MODE_e'(MODE_40_50G),
	     PKT_LEN_MODE_e'(INC_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd64,    // fix_pkt_len
	     13'd128,    // no_of_pkt_gen	     
	     16'd1024    // no_of_xfer_pkt	     
	     );

      repeat (200) @(posedge clk_avmm);
      $display("*******************************************************");
      $display("**** Test 4.6: MODE_FLEXE; MODE_40/50G; RND_PKT_LEN; ****");
      $display("*******************************************************");
      test_1(MODE_OP_e'(MODE_FLEXE), 
	     MODE_e'(MODE_40_50G),
	     PKT_LEN_MODE_e'(RND_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd64,    // fix_pkt_len
	     13'd128,    // no_of_pkt_gen	     
	     16'd2048    // no_of_xfer_pkt	     
	     );
      
      repeat (200) @(posedge clk_avmm);
      $display("*******************************************************");
      $display("**** Test 4.7: MODE_OTN; MODE_40/50G; FIX_PKT_LEN; ****");
      $display("*******************************************************");
      test_1(MODE_OP_e'(MODE_OTN), 
	     MODE_e'(MODE_40_50G),
	     PKT_LEN_MODE_e'(FIX_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd256,   // fix_pkt_len
	     13'd16,    // no_of_pkt_gen	     
	     16'd500    // no_of_xfer_pkt
	     
	     );

      repeat (200) @(posedge clk_avmm);
      $display("*******************************************************");
      $display("**** Test 4.8: MODE_OTN; MODE_40/50G; INC_PKT_LEN; ****");
      $display("*******************************************************");
      test_1(MODE_OP_e'(MODE_OTN), 
	     MODE_e'(MODE_40_50G),
	     PKT_LEN_MODE_e'(INC_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd64,    // fix_pkt_len
	     13'd128,    // no_of_pkt_gen	     
	     16'd1024    // no_of_xfer_pkt	     
	     );

      repeat (200) @(posedge clk_avmm);
      $display("*******************************************************");
      $display("**** Test 4.9: MODE_OTN; MODE_40/50G; RND_PKT_LEN; ****");
      $display("*******************************************************");
      test_1(MODE_OP_e'(MODE_OTN), 
	     MODE_e'(MODE_40_50G),
	     PKT_LEN_MODE_e'(RND_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd64,    // fix_pkt_len
	     13'd128,    // no_of_pkt_gen	     
	     16'd2048    // no_of_xfer_pkt	     
	     );
  
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 5.1: MODE_PCS; MODE_10/25G; FIX_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_PCS), 
	     MODE_e'(MODE_10_25G),
	     PKT_LEN_MODE_e'(FIX_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd256,   // fix_pkt_len
	     13'd16,    // no_of_pkt_gen	     
	     16'd500    // no_of_xfer_pkt
	     );
      
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 5.2: MODE_PCS; MODE_10/25G; INC_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_PCS), 
	     MODE_e'(MODE_10_25G),
	     PKT_LEN_MODE_e'(INC_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd64,    // fix_pkt_len
	     13'd128,   // no_of_pkt_gen	     
	     16'd1024   // no_of_xfer_pkt
	     );
      
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 5.3: MODE_PCS; MODE_10/25G; RND_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_PCS), 
	     MODE_e'(MODE_10_25G),
	     PKT_LEN_MODE_e'(RND_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd64,    // fix_pkt_len
	     13'd64,   // no_of_pkt_gen	     
	     16'd1024   // no_of_xfer_pkt
	     );
       
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 5.4: MODE_FLEXE; MODE_10/25G; FIX_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_FLEXE), 
	     MODE_e'(MODE_10_25G),
	     PKT_LEN_MODE_e'(FIX_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd256,   // fix_pkt_len
	     13'd16,    // no_of_pkt_gen	     
	     16'd500    // no_of_xfer_pkt
	     );
      
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 5.5: MODE_FLEXE; MODE_10/25G; INC_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_FLEXE), 
	     MODE_e'(MODE_10_25G),
	     PKT_LEN_MODE_e'(INC_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd64,    // fix_pkt_len
	     13'd128,   // no_of_pkt_gen	     
	     16'd1024   // no_of_xfer_pkt
	     );
      
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 5.6: MODE_FLEXE; MODE_10/25G; RND_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_FLEXE), 
	     MODE_e'(MODE_10_25G),
	     PKT_LEN_MODE_e'(RND_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd64,    // fix_pkt_len
	     13'd64,   // no_of_pkt_gen	     
	     16'd1024   // no_of_xfer_pkt
	     );
  
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 5.7: MODE_OTN; MODE_10/25G; FIX_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_OTN), 
	     MODE_e'(MODE_10_25G),
	     PKT_LEN_MODE_e'(FIX_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd256,   // fix_pkt_len
	     13'd16,    // no_of_pkt_gen	     
	     16'd500    // no_of_xfer_pkt
	     );
      
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 5.8: MODE_OTN; MODE_10/25G; INC_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_OTN), 
	     MODE_e'(MODE_10_25G),
	     PKT_LEN_MODE_e'(INC_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd64,    // fix_pkt_len
	     13'd128,   // no_of_pkt_gen	     
	     16'd1024   // no_of_xfer_pkt
	     );
      
      repeat (200) @(posedge clk_avmm);
      $display("*****************************************************");
      $display("**** Test 5.9: MODE_OTN; MODE_10/25G; RND_PKT_LEN; ****");
      $display("*****************************************************");
      test_1(MODE_OP_e'(MODE_OTN), 
	     MODE_e'(MODE_10_25G),
	     PKT_LEN_MODE_e'(RND_PKT_LEN),
	     8'd1,      // no_of_inc_bytes
	     11'd64,    // fix_pkt_len
	     13'd64,   // no_of_pkt_gen	     
	     16'd1024   // no_of_xfer_pkt
	     );
      
      repeat (10) @(posedge clk);
          
      $finish;
   end

   task test_1;
      input MODE_OP_e      mode_op;
      input MODE_e         mode;
      input PKT_LEN_MODE_e pkt_len_mode;
      input [7:0] 	   no_of_inc_bytes;
      input [10:0]         fix_pkt_len;
      input [12:0] 	   no_of_pkt_gen;      
      input [15:0]         no_of_xfer_pkt;

      
      CFG_MODE_0_s t1_cfg_mode_0;
      CFG_MODE_1_s t1_cfg_mode_1;
      CFG_MODE_2_s t1_cfg_mode_2;
      
      begin
	 
	 sys_reset;

	 $display("**** Read Config Registers Default Settings **** ");
	 csr_rd_access({ADDR_CFG_MODE_2, 2'd0});
	 repeat (2) @(posedge clk_avmm);
	 t1_cfg_mode_2 = readdata_reg;
	 t1_cfg_mode_2.no_of_pkt_gen  = no_of_pkt_gen;
	 t1_cfg_mode_2.no_of_xfer_pkt = no_of_xfer_pkt;
	 // set number of pkt to transmit
	 csr_wr_access ({ADDR_CFG_MODE_2, 2'd0}, t1_cfg_mode_2);
	 repeat (2) @(posedge clk_avmm);
	 
	 csr_rd_access({ADDR_CFG_MODE_1, 2'd0});
	 repeat (2) @(posedge clk_avmm);
	 t1_cfg_mode_1 = readdata_reg;
	 t1_cfg_mode_1.fix_pkt_len = fix_pkt_len;
	 t1_cfg_mode_1.no_of_inc_bytes = no_of_inc_bytes;	 
	 // set fix_pkt_len and no_of_inc_bytes
	 csr_wr_access ({ADDR_CFG_MODE_1, 2'd0}, t1_cfg_mode_1);
	 repeat (2) @(posedge clk_avmm);
	 
	 csr_rd_access({ADDR_CFG_MODE_0, 2'd0});
	 repeat (2) @(posedge clk_avmm);
	 t1_cfg_mode_0 = readdata_reg;
	 t1_cfg_mode_0.mode         = mode;
	 t1_cfg_mode_0.mode_op      = mode_op;
	 t1_cfg_mode_0.pkt_len_mode = pkt_len_mode;
	 // set mode of operation
	 csr_wr_access ({ADDR_CFG_MODE_0, 2'd0}, t1_cfg_mode_0);
	 repeat (10) @(posedge clk_avmm);

	 // generate pkts "write pkt data to buffer memory"
	 gen_pkt;
	 
	 // read counters before xfer pkts
	 csr_rd_cnt;
	 repeat (20) @(posedge clk_avmm);
	 // read cfg registers
	 csr_rd_cfg_reg;
	 repeat (20) @(posedge clk_avmm);
	 
	 // transfer pkt
	 xfer_pkt (no_of_xfer_pkt, 32'd0);
      end
   endtask // test_1
   
   task sys_reset;
      begin
	 rst = '1;	 
	 
	 repeat (100) @(posedge clk_avmm);
	 rst = '0;
	 
	 repeat (100) @(posedge clk_avmm);
      end
   endtask
   
   task Init;
      begin
	 clk  = '0;
	 clkf = '1;
	 clk_avmm = '0;
	 test_fail = '0;
	 
	 address = '0;
	 writedata = '0;
	 read = '0;
	 write = '0;
	 
	 rst = '1;	 
	 
	 repeat (100) @(posedge clk);
	 rst = '0;
	 
	 repeat (100) @(posedge clk);

	 	 
	 
	 
	 /*
	 wait (tb.exd.cfg_pkt_gen_done)	   
	   repeat (100) @(posedge clk);
	 $display("*** Packet generation is done. **** \n");

	 wait (tb.exd.cfg_start_xfer_pkt)
	   repeat (100) @(posedge clk);
	 $display("*** Packet Transmission is starting. **** \n");
	 */
	 /*
	 @(posedge clk)
	   cfg_start_xfer_pkt <= '1;
	  */

	 repeat (1000) @(posedge clk);
      end
   endtask // Init

   logic [15:0] tx_mii_rdy_cnt;
   
   always_ff @(posedge clkf) begin
      tx_mii_rdy_cnt <= tx_mii_rdy_cnt + 1'b1;
      
      if (rst)
	tx_mii_rdy_cnt <= '0;
   end

   always_ff @(posedge clkf) begin
      if (tx_mii_rdy_cnt[7:2] == 6'h20)
	tx_mii_ready <= '0;
      else
	tx_mii_ready <= '1;
   end

   // xfer packets
   task xfer_pkt;
      input [31:0] cnt_exp;
      input [31:0] err_cnt_exp;
      
      begin
	 CFG_START_XFER_PKT_s xfer_pkt_gen_reg;
	 CFG_MODE_2_s mode_2_reg;
	 
	 //csr_rd_cfg_reg;
	 repeat (100) @(posedge clk_avmm);
	 	 
	 xfer_pkt_gen_reg = '0;
	 xfer_pkt_gen_reg.start_xfer_pkt = '1;

	 $display("**** Start Xfer Packet **** ");
	 
	 // initiate pkt transmission
	 csr_wr_access ({ADDR_CFG_START_XFER_PKT, 2'd0}, xfer_pkt_gen_reg);
	 
	 repeat (100) @(posedge clk_avmm);
	 csr_rd_access( {ADDR_CFG_START_XFER_PKT, 2'd0});

	 while (!cfg_xfer_pkt_reg.pkt_xfer_done_stat) begin
	    csr_rd_access( {ADDR_CFG_START_XFER_PKT, 2'd0} );
	    repeat (5000) @(posedge clk_avmm);
	 end

	 repeat (500) @(posedge clk_avmm);
	 $display("**** Xfer Packet Finish **** \n");
	 
	 repeat (1000) @(posedge clk_avmm);

	 $display("**** Read Counters Stats **** ");
	 csr_rd_access_exp( {ADDR_TX_SOP_CNT, 2'd0}, cnt_exp);
         csr_rd_access_exp( {ADDR_TX_EOP_CNT, 2'd0}, cnt_exp);
         csr_rd_access_exp( {ADDR_TX_PKT_CNT, 2'd0}, cnt_exp);
	 csr_rd_access_exp( {ADDR_RX_CRC_OK_CNT, 2'd0}, cnt_exp);
         csr_rd_access_exp( {ADDR_RX_CRC_ERR_CNT, 2'd0}, err_cnt_exp);
         csr_rd_access_exp( {ADDR_RX_SOP_CNT, 2'd0}, cnt_exp);
         csr_rd_access_exp( {ADDR_RX_EOP_CNT, 2'd0}, cnt_exp);
         csr_rd_access_exp( {ADDR_RX_PKT_CNT, 2'd0}, cnt_exp);
         
	 //csr_rd_cnt;
	 repeat (200) @(posedge clk_avmm);

	 if (test_fail_stats) begin
	    $display("**** Test FAILED **** \n");
	    repeat (200) @(posedge clk_avmm);
	    $finish;
	 end
	 else
	   $display("**** Test PASSED **** \n");
      end
   endtask


   
   // packet generation
   task gen_pkt;

      begin
	 CFG_START_PKT_GEN_s start_pkt_gen_reg;
	 start_pkt_gen_reg = '0;
	 start_pkt_gen_reg.start_pkt_gen = '1;
	 
	 $display("**** Start Packet Generation **** ");
	 csr_wr_access ({ADDR_CFG_START_PKT_GEN, 2'd0}, start_pkt_gen_reg);
	 repeat (100) @(posedge clk_avmm);
	 csr_rd_access( {ADDR_CFG_START_PKT_GEN, 2'd0} );
	 
	 while (!cfg_start_pkt_gen_reg.pkt_gen_done_stat) begin
	    csr_rd_access( {ADDR_CFG_START_PKT_GEN, 2'd0} );
	    repeat (10000) @(posedge clk_avmm);
	 end

	 $display("**** Packet Generation Finish **** \n");
      end
   endtask

   task csr_rd_cfg_reg;
      begin
	 $display("**** Read Config Registers **** ");
	 csr_rd_access( {ADDR_CFG_MODE_0, 2'd0});
	 csr_rd_access( {ADDR_CFG_MODE_1, 2'd0});
	 csr_rd_access( {ADDR_CFG_MODE_2, 2'd0});
	 csr_rd_access( {ADDR_CFG_MODE_3, 2'd0});
      end
   endtask // csr_rd_cfg_reg
   
   task csr_rd_cnt;
      begin
	 $display("**** Read Counter Registers **** ");
	 csr_rd_access( {ADDR_TX_SOP_CNT, 2'd0});
         csr_rd_access( {ADDR_TX_EOP_CNT, 2'd0});
         csr_rd_access( {ADDR_TX_PKT_CNT, 2'd0});
	 csr_rd_access( {ADDR_RX_CRC_OK_CNT, 2'd0});
         csr_rd_access( {ADDR_RX_CRC_ERR_CNT, 2'd0});
         csr_rd_access( {ADDR_RX_SOP_CNT, 2'd0});
         csr_rd_access( {ADDR_RX_EOP_CNT, 2'd0});
         csr_rd_access( {ADDR_RX_PKT_CNT, 2'd0});
         
      end
   endtask // csr_rd_cnt
   

   task csr_access;
      input rd;
      input wr;
      input [9:0] addr;
      input [31:0] wdata;

      begin
	 wait (tb.exd.waitrequest === 0)

	   @(posedge clk_avmm) begin
	      read      <= rd;
	      write     <= wr;
	      address   <= addr;
	      writedata <= writedata;
	   end
	 
	 repeat (1) @(posedge clk_avmm);
	 #10;
	 
	 wait (tb.exd.waitrequest === 1)
	   @(posedge clk_avmm) begin
	      read      <= '0;
	      write     <= '0;
	   end	 
      end
      
   endtask // csr_access

   task csr_rd_access;
      input [9:0] addr;      

      begin
	 wait (tb.exd.waitrequest === 0)

	   @(posedge clk_avmm) begin
	      read      <= '1;
	      address   <= addr;
	      write     <= '0;
	      writedata <= '0;
	   end
	 
	 repeat (1) @(posedge clk_avmm);
	 #10;
	 
	 wait (tb.exd.waitrequest === 1)
	   @(posedge clk_avmm) begin
	      read      <= '0;
	      write     <= '0;
	   end
	 repeat (4) @(posedge clk_avmm);
      end
   endtask

   task csr_rd_access_exp;
      input [9:0] addr;   
      input [31:0] exp_rdata;
   
      begin
	 test_fail = '0;
	 
	 wait (tb.exd.waitrequest === 0)

	   @(posedge clk_avmm) begin
	      read      <= '1;
	      address   <= addr;
	      write     <= '0;
	      writedata <= '0;
	   end
	 
	 repeat (1) @(posedge clk_avmm);
	 #10;
	 
	 wait (tb.exd.waitrequest === 1)	 
	   @(posedge clk_avmm) begin
	      read      <= '0;
	      write     <= '0;
	   end

	 #10;
	 wait (tb.exd.readdatavalid === 1)
	   if (readdata !== exp_rdata) begin
	     $display("RD ERROR: Expected data = %0d; Actual data = %0d;", exp_rdata, readdata);
	      test_fail = '1;
	   end

	 repeat (4) @(posedge clk_avmm);
      end
      
   endtask // csr_rd_acces

   task csr_wr_access;
      input [9:0] addr;
      input [31:0] wdata;

      begin
	 wait (tb.exd.waitrequest === 0)

	   @(posedge clk_avmm) begin
	      write      <= '1;
	      read       <= '0;
	      address    <= addr;
	      writedata  <= wdata;
	   end
	 
	 repeat (1) @(posedge clk_avmm);
	 #10;
	 
	 wait (tb.exd.waitrequest === 1)
	   @(posedge clk_avmm) begin
	      read      <= '0;
	      write     <= '0;
	   end

	 repeat (4) @(posedge clk_avmm);
      end
      
   endtask

   // example design
   exd exd
     (// inputs
      .tclk (clkf), 
      .clk (clk),
      .clk_avmm (clk_avmm),
      .rst (rst),

      //------------------------------------------------------------------------------------
      // csr interface
      // inputs
      .address (address),
      .writedata (writedata),
      .read (read),
      .write (write),
      
      // outputs
      .readdata (readdata),
      .readdatavalid (readdatavalid),
      .waitrequest (waitrequest),

      //--------------------------------------------------------------------------------------
      // tmii
      // inputs
      .tx_mii_ready ('1),

      // outputs
      .tx_mii_d (tx_mii_d),
      .tx_mii_c (tx_mii_c),
      .tx_mii_sync (tx_mii_sync),
      .tx_mii_vld (tx_mii_vld),
      .tx_mii_am (tx_mii_am),
      //--------------------------------------------------------------------------------------

      //--------------------------------------------------------------------------------------
      // rmii
      .rx_mii_d (tx_mii_d),
      .rx_mii_c (tx_mii_c),
      .rx_mii_sync (tx_mii_sync),
      .rx_mii_vld (tx_mii_vld),
      .rx_mii_am (tx_mii_am)

      );

  
   
   always_comb begin
      cfg_mode_reg_0        = readdata;
      cfg_mode_reg_1        = readdata;
      cfg_mode_reg_2        = readdata;
      cfg_mode_reg_3        = readdata;
      cfg_start_pkt_gen_reg = readdata;
      cfg_xfer_pkt_reg      = readdata;
      cnt_reg               = readdata;
   end
   
   always_ff @(posedge clk_avmm) begin
      if (readdatavalid) begin
	 readdata_reg <= readdata;
	 
	 case (address[9:2])
	   ADDR_CFG_MODE_0: begin
	      case (cfg_mode_reg_0.mode_op)
		MODE_OP_e'(MODE_PCS): $display("RD_REG: cfg_mode_reg_0: mode_op=MODE_PCS;");
                MODE_OP_e'(MODE_FLEXE): $display("RD_REG: cfg_mode_reg_0: mode_op=MODE_FLEXE; ");
                MODE_OP_e'(MODE_OTN): $display("RD_REG: cfg_mode_reg_0: mode_op=MODE_OTN;");
	      endcase
              case (cfg_mode_reg_0.mode)
		MODE_e'(MODE_10_25G) : $display("RD_REG: cfg_mode_reg_0: mode=MODE_10_25G;");
		MODE_e'(MODE_40_50G) : $display("RD_REG: cfg_mode_reg_0: mode=MODE_40_50G;");
		MODE_e'(MODE_100G) : $display("RD_REG: cfg_mode_reg_0: mode=MODE_100G;");
		MODE_e'(MODE_200G) : $display("RD_REG: cfg_mode_reg_0: mode=MODE_200G;");
		MODE_e'(MODE_400G) : $display("RD_REG: cfg_mode_reg_0: mode=MODE_400G;");
	      endcase
	      case (cfg_mode_reg_0.pkt_len_mode)
	        PKT_LEN_MODE_e'(FIX_PKT_LEN) : $display("RD_REG: cfg_mode_reg_0: pkt_len_mode=FIX_PKT_LEN;");
		PKT_LEN_MODE_e'(INC_PKT_LEN) : $display("RD_REG: cfg_mode_reg_0: pkt_len_mode=INC_PKT_LEN;");
		PKT_LEN_MODE_e'(RND_PKT_LEN) : $display("RD_REG: cfg_mode_reg_0: pkt_len_mode=RND_PKT_LEN;");
	      endcase
	      case (cfg_mode_reg_0.pat_mode)
		DAT_PAT_MODE_e'(FIX_DAT_PAT): $display("RD_REG: cfg_mode_reg_0: pat_mode=FIX_DAT_PAT;");
		DAT_PAT_MODE_e'(INC_DAT_PAT): $display("RD_REG: cfg_mode_reg_0: pat_mode=INC_DAT_PAT;");
		DAT_PAT_MODE_e'(RND_DAT_PAT): $display("RD_REG: cfg_mode_reg_0: pat_mode=RND_DAT_PAT;");
	      endcase
		
	          
	      $display("RD_REG: cfg_mode_reg_0: cont_xfer_mode=%0d; disable_am_ins=%0d; rx2tx_lb=%0d; ipg_dly=%0d; tmii_rdy_fix_dly=%0d;"
                 ,cfg_mode_reg_0.cont_xfer_mode
		 ,cfg_mode_reg_0.disable_am_ins
	         ,cfg_mode_reg_0.rx2tx_lb
		 ,cfg_mode_reg_0.ipg_dly
                 ,cfg_mode_reg_0.tmii_rdy_fix_dly);
	   end // case: ADDR_CFG_MODE_0
	   ADDR_CFG_MODE_1: begin
	      $display("RD_REG: cfg_mode_reg_1: no_of_inc_bytes=%0d; fix_pattern=0x%0h; fix_pkt_len=%0d;",cfg_mode_reg_1.no_of_inc_bytes,
		                                                                                       cfg_mode_reg_1.fix_pattern,
		                                                                                       cfg_mode_reg_1.fix_pkt_len);
	   end
	   ADDR_CFG_MODE_2: begin
	      $display("RD_REG: cfg_mode_reg_2: no_of_pkt_gen=%0d; no_of_xfer_pkt=%0d;",cfg_mode_reg_2.no_of_pkt_gen,
		                                                                        cfg_mode_reg_2.no_of_xfer_pkt);
	   end
	   ADDR_CFG_MODE_3: begin
	      $display("RD_REG: cfg_mode_reg_3: am_ins_period=%0d; am_ins_cyc=%0d;",cfg_mode_reg_3.am_ins_period,
		                                                                    cfg_mode_reg_3.am_ins_cyc);
	   end
	   ADDR_CFG_START_PKT_GEN: begin
	      $display("RD_REG: cfg_start_pkt_gen_reg : start_pkt_gen=%0d; pkt_gen_done_stat=%0d;",cfg_start_pkt_gen_reg.start_pkt_gen,
		                                                                                   cfg_start_pkt_gen_reg.pkt_gen_done_stat);
	   end
	   ADDR_CFG_START_XFER_PKT: begin
	      $display("RD_REG:  cfg_xfer_pkt_reg: start_xfer_pkt=%0d; pkt_xfer_done_stat=%0d;",cfg_xfer_pkt_reg.start_xfer_pkt,
		                                                                                cfg_xfer_pkt_reg.pkt_xfer_done_stat);
	   end
	   ADDR_TX_SOP_CNT: $display("RD_REG:  tx_sop_cnt=%0d; ",cnt_reg );
	   ADDR_TX_EOP_CNT: $display("RD_REG:  tx_eop_cnt=%0d; ",cnt_reg );
           ADDR_TX_PKT_CNT: $display("RD_REG:  tx_pkt_cnt=%0d; ",cnt_reg );
	   ADDR_RX_SOP_CNT: $display("RD_REG:  rx_sop_cnt=%0d; ",cnt_reg );
	   ADDR_RX_EOP_CNT: $display("RD_REG:  rx_eop_cnt=%0d; ",cnt_reg );
           ADDR_RX_PKT_CNT: $display("RD_REG:  rx_pkt_cnt=%0d; ",cnt_reg );
	   ADDR_RX_CRC_OK_CNT: $display("RD_REG:  rx_crc_ok_cnt=%0d; ",cnt_reg );
	   ADDR_RX_CRC_ERR_CNT: $display("RD_REG:  rx_crc_err_cnt=%0d; ",cnt_reg );
	   
	 endcase 

      end // if (readdatavalid)
   end
   
endmodule // tb

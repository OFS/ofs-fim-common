// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT



`default_nettype none
module tx_packet_client #(parameter   PARAM_RATE_OP  = 4 
                                    , INIT_FILE_DATA = "init_file_data.hex"
			            , INIT_FILE_DATA_B = "init_file_data_b.hex" 
                                    , INIT_FILE_CTL  = "init_file_crtl.hex" 
                                    , INTF_DATA_WD = 1 << (PARAM_RATE_OP + 6)
			            , INTF_CTL_WD = 1 << (PARAM_RATE_OP + 3)
			            , INTF_SYNC_WD = 1 << (PARAM_RATE_OP + 1))
   (
    input  var logic tclk,
    input  var logic clk,
    input  var logic rst,
    input  var logic rst_tclk,

    //----------------------------------------------------------------------------------------
    // config
    input  var gdr_pkt_pkg::MODE_e cfg_mode, // 0: 10/25G (8B)
                                // 1: 40/50G (16B)
                                // 2: 100G   (32B)
                                // 3: 200G   (64B)
                                // 4: 400G   (128B)
    input  var gdr_pkt_pkg::MODE_OP_e cfg_mode_op,
    input  var gdr_pkt_pkg::PKT_LEN_MODE_e cfg_pkt_len_mode, // 0: fix pkt_len, 
                                                // 1: inc pkt len start from 64B
                                                // 2: random pkt len start from 64B
    input  var gdr_pkt_pkg::DAT_PAT_MODE_e cfg_pkt_pattern_mod, // 0: fix pattern data base on 
                                                   //      cfg_fix_pattern
                                                   // 1: inc patten
                                                   // 2: random pattern
    input  var logic [10:0] cfg_fix_pkt_len, // this define as pkt_len - 4.
    input  var logic [7:0] cfg_fix_pattern,
    input  var logic [12:0] cfg_no_of_pkt_gen, // maximum number of generated pkt. care must
                                               //  be taken when cfg_pkt_len_mode = 1 or 2.
                                               //  Maximum setting is 8191 for 64B pkt
    input  var logic [7:0] cfg_no_of_inc_bytes, // Number of incremental bytes to be used in
                                                //  used when cfg_pkt_len_mode=1
    input  var logic [3:0] cfg_tx_mii_rdy_2_vld, // number of fix delay from tx_mii_ready
                                                 //  to tx_mii_valid. Note minimum setting
                                                 //  is 3.

    input  var logic [16:0] cfg_am_ins_period, // am insertion "period - 1"
    
    input  var logic [3:0] cfg_am_ins_cyc, // am insertion "cyc - 1"
    
    input  var logic cfg_disable_am_ins, // 1: disable am insertion function
                                         // 0: enable am insertion function
    input  var logic cfg_start_pkt_gen,
    input  var logic cfg_sw_gen_pkt,
    input  var logic cfg_dyn_pkt_gen, // 1: enable dynamic packet generation
                                      //    if (cfg_cont_xfer_mode==1)
                                      //       tx pkt until cfg_start_pkt_gen is deasserted
                                      //    if (cfg_cont_xfer_mode==0)
                                      //       tx pkt until (tx_pkt_cnt == cfg_no_of_xfer_pkt) 
                                      // 0: disable dynamic packet generation
    input  var logic [gdr_pkt_pkg::GEN_MEM_ADDR-1:0] cfg_last_mem_addr,
    input  var logic [15:0] cfg_no_of_xfer_pkt, // number of pkt to be tx

    input  var logic cfg_cont_xfer_mode, // 1: enable continuous xfer mode. keep replay
                                         //     the xfer buffer until cfg_start_xfer_pkt
                                         //     deasserted.
                                         // 0: enable number pkt xfer mode. stop xfer pkt
                                         //     when number of tx pkt reaches 
                                         //     cfg_no_of_xfer_pkt

    input  var logic [7:0] cfg_ipg_dly, // indicates number ipg delay cycles
    
    input  var logic cfg_start_xfer_pkt, // 1: start tx pkt
                                         // 0: stop tx pkt
    
        
    input  var logic cfg_rx_2_tx_loopbk, // 1: enable rx_2_tx loopback
                                         // 0: normal operation

    output var logic inc_tx_sop,
    output var logic inc_tx_eop,
    output var logic inc_tx_pkt,
    
    input  var gdr_pkt_pkg::CFG_GEN_MEM_REQ_s cfg_mem_req,
    
    output var gdr_pkt_pkg::GEN_MEM_RD_RSP_s cfg_mem_rd_rsp,
    output var logic cfg_mem_rd_done,
    output var logic cfg_mem_wr_done,
    
    //----------------------------------------------------------------------------------------
    // tcsr interface
    output var logic cfg_pkt_gen_done,
    output var logic cfg_pkt_xfer_done,
    output var logic init_done,
    
    //----------------------------------------------------------------------------------------
    // tmii
    input  var logic tx_mii_ready,
    
    //output var gdr_pkt_pkg::PCS_D_16_WRD_s tx_mii_d,
    //output var gdr_pkt_pkg::PCS_SYNC_16_WRD_s tx_mii_sync,
    //output var gdr_pkt_pkg::PCS_C_16_WRD_s tx_mii_c,
    output var logic [INTF_DATA_WD-1:0] tx_mii_d,
    output var logic [INTF_CTL_WD-1:0] tx_mii_c,
    output var logic [INTF_SYNC_WD-1:0] tx_mii_sync ,
    
    output var logic tx_mii_vld,
    output var logic tx_mii_am,
    
    //----------------------------------------------------------------------------------------
    // rpcs interface use for loopback
    input  var gdr_pkt_pkg::PCS_D_32_WRD_s rpcs_tpcs_d,
    input  var gdr_pkt_pkg::PCS_C_32_WRD_s rpcs_tpcs_c,
    input  var logic rpcs_tpcs_vld
    );
    import gdr_pkt_pkg::*;
    
    //----------------------------------------------------------------------------------------
    // op from tpgn
    logic [12:0] last_mem_addr;
    GEN_MEM_WR_s gen_pkt_mem;

    //----------------------------------------------------------------------------------------
    // op from tmem
    GEN_MEM_RD_RSP_s gen_pkt_mem_rdata;

    //----------------------------------------------------------------------------------------
    // op from tpcs
    logic gen_pkt_mem_rd;
    logic [12:0] gen_pkt_mem_raddr;
    logic xfer_pkt_done;
    logic inc_sop_cnt;
    logic inc_term_cnt ;
    PCS_D_32_WRD_s tpcs_tscr_d;    
    PCS_C_32_WRD_s tpcs_tscr_c;    
    logic tpcs_tscr_vld, tpcs_tscr_pref_push;

    //----------------------------------------------------------------------------------------
    // op from tscr
    logic tscr_rdy;
    PCS_D_16_WRD_s [1:0] tscr_tmii_d;    
    PCS_SYNC_16_WRD_s [1:0] tscr_tmii_sync;  
    PCS_C_16_WRD_s [1:0]  tscr_tmii_c;
    
    logic tscr_tmii_vld;
    
    //----------------------------------------------------------------------------------------
    // op from tmii
    logic tmii_rdy;
    
    logic [1023:0] tx_mii_d_o;    
    logic [127:0]  tx_mii_c_o;    
    logic [31:0] tx_mii_sync_o;

    generate 
	//------------------------------------------------------------------------------------
	// Generate 400G generated pkt mem
	if (PARAM_RATE_OP == 4) begin: tx_intf_gen_400G
	    always_comb begin
		tx_mii_d    = tx_mii_d_o;
		tx_mii_c    = tx_mii_c_o;
		tx_mii_sync = tx_mii_sync_o;		
	    end
	end // block: rx_intf_gen_400G
	//------------------------------------------------------------------------------------
	// Generate 200G generated pkt mem
	else if (PARAM_RATE_OP == 3) begin: tx_intf_gen_200G
	    always_comb begin
		tx_mii_d    = tx_mii_d_o[511:0];
		tx_mii_c    = tx_mii_c_o[63:0];
		tx_mii_sync = tx_mii_sync_o[15:0];		
	    end
	end // block: tx_intf_gen_200G
	//------------------------------------------------------------------------------------
	// Generate 100G generated pkt mem
	else if (PARAM_RATE_OP == 2) begin: tx_intf_gen_100G
	    always_comb begin
		tx_mii_d    = tx_mii_d_o[255:0];
		tx_mii_c    = tx_mii_c_o[31:0];
		tx_mii_sync = tx_mii_sync_o[7:0];		
	    end
	end // block: tx_intf_gen_100G
	//------------------------------------------------------------------------------------
	// Generate 50G generated pkt mem
	else if (PARAM_RATE_OP == 1) begin: tx_intf_gen_50G
	    always_comb begin
		tx_mii_d    = tx_mii_d_o[127:0];
		tx_mii_c    = tx_mii_c_o[15:0];
		tx_mii_sync = tx_mii_sync_o[3:0];		
	    end
	end // block: tx_intf_gen_50G
	//------------------------------------------------------------------------------------
	// Generate 10G generated pkt mem
	else  begin: tx_intf_gen_10G
	    always_comb begin
		tx_mii_d    = tx_mii_d_o[63:0];
		tx_mii_c    = tx_mii_c_o[7:0];
		tx_mii_sync = tx_mii_sync_o[1:0];		
	    end
	end
    endgenerate
    
    //----------------------------------------------------------------------------------------
    // pkt generation
    tpgn  tpgn
     (// inputs
      .clk (clk),
      .rst (rst),
      
      //--------------------------------------------------------------------------------------
      // configinterface
      // inputs 
      .cfg_mode (cfg_mode),
      .cfg_pkt_len_mode (cfg_pkt_len_mode),
      .cfg_pkt_pattern_mod (cfg_pkt_pattern_mod),
      .cfg_fix_pattern (cfg_fix_pattern),
      .cfg_fix_pkt_len (cfg_fix_pkt_len),
      .cfg_no_of_inc_bytes (cfg_no_of_inc_bytes),
      .cfg_no_of_pkt_gen (cfg_no_of_pkt_gen ),
      .cfg_start_pkt_gen (cfg_start_pkt_gen),
      .cfg_sw_gen_pkt (cfg_sw_gen_pkt),
      .cfg_last_mem_addr (cfg_last_mem_addr),
      .cfg_dyn_pkt_gen (cfg_dyn_pkt_gen),
      .cfg_cont_xfer_mode (cfg_cont_xfer_mode),
      //--------------------------------------------------------------------------------------

      //--------------------------------------------------------------------------------------
      // tcsr interface
      // outputs
      .cfg_pkt_gen_done (cfg_pkt_gen_done),
      //--------------------------------------------------------------------------------------
      
      //--------------------------------------------------------------------------------------
      // tpcs interface
      // outputs
      .last_mem_addr (last_mem_addr),
      //--------------------------------------------------------------------------------------
      
      //--------------------------------------------------------------------------------------
      // tmem interface
      // outputs
      .gen_pkt_mem (gen_pkt_mem)
      //--------------------------------------------------------------------------------------

      );
    
    //----------------------------------------------------------------------------------------
    // pkt mem
    tmem #(  .PARAM_RATE_OP(PARAM_RATE_OP)
            ,.INIT_FILE_DATA (INIT_FILE_DATA)
	    ,.INIT_FILE_DATA_B (INIT_FILE_DATA_B)
            ,.INIT_FILE_CTL (INIT_FILE_CTL)   ) tmem
       (// inputs
	.clk (clk),
	.rst (rst),

	//--------------------------------------------------------------------------------------
	// csr interface
	// inputs
	.cfg_mem_req (cfg_mem_req),

	// outputs
	.cfg_mem_rd_rsp (cfg_mem_rd_rsp),
	.cfg_mem_rd_done (cfg_mem_rd_done),
	.cfg_mem_wr_done (cfg_mem_wr_done),

	.init_done (init_done),
	
	//--------------------------------------------------------------------------------------
	// tpgn interface
	// inputs
	.gen_pkt_mem (gen_pkt_mem),

	//--------------------------------------------------------------------------------------
	// tpcs interface
	// inputs
	.gen_pkt_mem_rd (gen_pkt_mem_rd),
	.gen_pkt_mem_raddr (gen_pkt_mem_raddr),
	
	// outputs
	.gen_pkt_mem_rdata (gen_pkt_mem_rdata)
	);
    
    tpcs tpcs
       (
	// inputs
	.clk (clk),
	.rst (rst),
	.cfg_mode (cfg_mode),
	.cfg_no_of_xfer_pkt (cfg_no_of_xfer_pkt - 1'b1),
	.cfg_cont_xfer_mode (cfg_cont_xfer_mode),
	.cfg_rx_2_tx_loopbk (cfg_rx_2_tx_loopbk),
	.cfg_start_xfer_pkt (cfg_start_xfer_pkt),
	.cfg_ipg_dly (cfg_ipg_dly),
	.cfg_dyn_pkt_gen (cfg_dyn_pkt_gen),
	.cfg_start_pkt_gen (cfg_start_pkt_gen),
	//-----------------------------------------------------
	// tpgn
	// inputs
	.last_mem_addr (last_mem_addr),
	.cfg_pkt_gen_done (cfg_pkt_gen_done),
	.cfg_pkt_xfer_done (cfg_pkt_xfer_done),
	
	//-----------------------------------------------------
	// tmem
	// outputs
	.gen_pkt_mem_rd (gen_pkt_mem_rd),
	.gen_pkt_mem_raddr (gen_pkt_mem_raddr),
	
	// inputs
	.gen_pkt_mem_rdata (gen_pkt_mem_rdata),
	
	//-----------------------------------------------------
	// csr if
	// outputs
	.xfer_pkt_done (xfer_pkt_done),
	.inc_sop_cnt (inc_tx_sop),
	.inc_term_cnt (inc_tx_eop),
	.inc_pkt_cnt (inc_tx_pkt),
	
	//-----------------------------------------------------
	// tscr interface
	// inputs
	.tscr_rdy  (tscr_rdy),
	
	// outputs
	.tpcs_tscr_pref_push (tpcs_tscr_pref_push),
	.tpcs_tscr_d (tpcs_tscr_d),
	.tpcs_tscr_c (tpcs_tscr_c),
	.tpcs_tscr_vld (tpcs_tscr_vld),
		
	//-----------------------------------------------------
	// rpcs interface use for loopback
	// inputs
	.rpcs_tpcs_d (rpcs_tpcs_d),
	.rpcs_tpcs_c (rpcs_tpcs_c),
	.rpcs_tpcs_vld (rpcs_tpcs_vld)
	
	);

    tscr tscr (
	    // inputs
	    .clk (clk),
	    .rst (rst),
	    //-----------------------------------------------------
	    // configinterface
	    // inputs
	    .cfg_mode (cfg_mode),
	    .cfg_mode_op (cfg_mode_op),
	    
	    //-----------------------------------------------------
	    // tpcs interface
	    // inputs
	    .tpcs_tscr_pref_push (tpcs_tscr_pref_push),
	    .tpcs_tscr_d (tpcs_tscr_d),
	    .tpcs_tscr_c (tpcs_tscr_c),
	    .tpcs_tscr_vld (tpcs_tscr_vld),

	    // outputs
	    .tscr_rdy (tscr_rdy),
	    
	    //-----------------------------------------------------
	    // tmii interface
	    // inputs
	    .tmii_rdy (tmii_rdy),

	    // outputs
	    .tscr_tmii_d (tscr_tmii_d),
	    .tscr_tmii_c (tscr_tmii_c),
	    .tscr_tmii_sync (tscr_tmii_sync),
	    .tscr_tmii_vld (tscr_tmii_vld)
	);

    tmii tmii
       (// inputs
	.tclk (tclk),
	.rst (rst),
	//-----------------------------------------------------
	// configinterface
	// inputs
	.cfg_mode (cfg_mode),
	.cfg_tx_mii_rdy_2_vld (cfg_tx_mii_rdy_2_vld),
	.cfg_am_ins_period (cfg_am_ins_period),
	.cfg_am_ins_cyc (cfg_am_ins_cyc),
	.cfg_disable_am_ins (cfg_disable_am_ins),

	//-----------------------------------------------------
	// tscr interface
	// inputs
	.tscr_tmii_d (tscr_tmii_d),
	.tscr_tmii_c (tscr_tmii_c),
	.tscr_tmii_sync (tscr_tmii_sync),
	.tscr_tmii_vld (tscr_tmii_vld),

	// outputs
	.tmii_rdy (tmii_rdy),

	//-----------------------------------------------------
	// tmii interface
	// inputs
	.tx_mii_ready (tx_mii_ready),

	// outputs
	.tx_mii_d (tx_mii_d_o),
	.tx_mii_c (tx_mii_c_o),
	.tx_mii_sync (tx_mii_sync_o),
	.tx_mii_vld (tx_mii_vld),
	.tx_mii_am (tx_mii_am)
	);
    
endmodule // exd_tx

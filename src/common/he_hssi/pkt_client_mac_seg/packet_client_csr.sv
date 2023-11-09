// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`default_nettype none

///////////////////////////////////////////////////////////////////////////////////////////////
/*
PARAM_RATE_OP:
  typedef enum logic [2:0] 
       {
        MODE_10_25G = 3'd0,
	MODE_40_50G = 3'd1,
	MODE_100G   = 3'd2,
	MODE_200G   = 3'd3,
	MODE_400G   = 3'd4
	}MODE_e;
 
PARAM_MODE_OP:
  typedef enum logic [1:0]
       {
	MODE_PCS   = 2'd0,
	MODE_FLEXE = 2'd1,
	MODE_OTN   = 2'd2
	} MODE_OP_e;
 
PARAM_PKT_LEN_MODE:
  typedef enum logic [1:0] 
       {
        FIX_PKT_LEN = 2'd0,
	INC_PKT_LEN = 2'd1,
	RND_PKT_LEN = 2'd2
	}PKT_LEN_MODE_e;
 
PARAM_DAT_PAT_MODE:
  typedef enum logic [1:0] 
       {
        FIX_DAT_PAT = 2'd0,
	INC_DAT_PAT = 2'd1,
	RND_DAT_PAT = 2'd2
	}DAT_PAT_MODE_e;
 */


module packet_client_csr #( parameter  PARAM_AUTO_XFER_PKT     = 1
                           , PARAM_RATE_OP           = 4
                           , PARAM_MODE_OP           = 0
                           , PARAM_PKT_LEN_MODE      = 0 
                           , PARAM_DAT_PAT_MODE      = 0
                           , PARAM_TX_IPG_DLY        = 32 
                           , PARAM_CONT_XFER_PKT     = 0
		           , PARAM_DISABLE_AM_INS    = 1
                           , PARAM_RX2TX_LB          = 0
		           , PARAM_TMII_RDY_FIX_DLY  = 3
		           , PARAM_FIX_PKT_LEN       = 256
		           , PARAM_FIX_DAT_PAT       = 'ha6
		           , PARAM_NO_OF_INC_BYTES   = 1
		           , PARAM_NO_OF_PKT_GEN     = 10
		           , PARAM_NO_OF_XFER_PKT    = 1000
		           , PARAM_AM_INS_PERIOD     = 40960
		           , PARAM_AM_INS_CYC        = 2
		           , PARAM_DYN_PKT_GEN       = 0
                           ) 
        
   (
        
    input  var logic clk_avmm,
    input  var logic clk,
    input  var logic tclk,
    input  var logic rst,

    output var logic rst_tclk,
    output var logic rst_clk,
    output var logic rst_avmm_clk,
    
    //----------------------------------------------------------------------------------------
    //----------------------------------------------------------------------------------------
    // csr interface
    input  var logic [9:0] address,
    input  var logic [31:0] writedata,
    input  var logic read,
    input  var logic write,
        
    output var logic [31:0] readdata,
    output var logic readdatavalid,
    output var logic waitrequest,
    //----------------------------------------------------------------------------------------
    //----------------------------------------------------------------------------------------

    
    //----------------------------------------------------------------------------------------
    // config interface
    output var gdr_pkt_pkg::MODE_e cfg_mode, // 0: 10/25G (8B)
                                // 1: 40/50G (16B)
                                // 2: 100G   (32B)
                                // 3: 200G   (64B)
                                // 4: 400G   (128B)
    output var gdr_pkt_pkg::MODE_OP_e cfg_mode_op,
    output var gdr_pkt_pkg::PKT_LEN_MODE_e cfg_pkt_len_mode, // 0: fix pkt_len, 
                                                // 1: inc pkt len start from 64B
                                                // 2: random pkt len start from 64B
    output var gdr_pkt_pkg::DAT_PAT_MODE_e cfg_pkt_pattern_mod, // 0: fix pattern data base on 
                                                   //      cfg_fix_pattern
                                                   // 1: inc patten
                                                   // 2: random pattern
    output var logic [10:0] cfg_fix_pkt_len, // this define as pkt_len - 4.
    output var logic [7:0] cfg_fix_pattern,
    output var logic [12:0] cfg_no_of_pkt_gen, // maximum number of generated pkt. care must
                                               //  be taken when cfg_pkt_len_mode = 1 or 2.
                                               //  Maximum setting is 8191 for 64B pkt
    output var logic [7:0] cfg_no_of_inc_bytes, // Number of incremental bytes to be used in
                                                //  used when cfg_pkt_len_mode=1
    output var logic [3:0] cfg_tx_mii_rdy_2_vld, // number of fix delay from tx_mii_ready
                                                 //  to tx_mii_valid. Note minimum setting
                                                 //  is 3.

    output var logic [16:0] cfg_am_ins_period, // am insertion "period - 1"
    
    output var logic [3:0] cfg_am_ins_cyc, // am insertion "cyc - 1"
    
    output var logic cfg_disable_am_ins, // 1: disable am insertion function
                                         // 0: enable am insertion function
    output var logic cfg_start_pkt_gen,
    output var logic [15:0] cfg_no_of_xfer_pkt, // number of pkt to be tx
    output var logic cfg_sw_gen_pkt, // indicates sw generated pkt
    output var logic [12:0] cfg_last_mem_addr, // indicats last mem address. valid when
                                               //   cfg_sw_gen_pkt is set
    output var logic cfg_cont_xfer_mode, // 1: enable continuous xfer mode. keep replay
                                         //     the xfer buffer until cfg_start_xfer_pkt
                                         //     deasserted.
                                         // 0: enable number pkt xfer mode. stop xfer pkt
                                         //     when number of tx pkt reaches 
                                         //     cfg_no_of_xfer_pkt

    output var logic [7:0] cfg_ipg_dly, // indicates number ipg delay cycles
    
    output var logic cfg_start_xfer_pkt, // 1: start tx pkt
                                         // 0: stop tx pkt
    
        
    output var logic cfg_rx_2_tx_loopbk, // 1: enable rx_2_tx loopback
                                         // 0: normal operation
        
    output var logic cfg_dyn_pkt_gen, // 1: enable dynamic packet generation
                                      //    if (cfg_cont_xfer_mode==1)
                                      //       tx pkt until cfg_start_pkt_gen is deasserted
                                      //    if (cfg_cont_xfer_mode==0)
                                      //       tx pkt until (tx_pkt_cnt == cfg_no_of_xfer_pkt) 
                                      // 0: disable dynamic packet generation
    //----------------------------------------------------------------------------------------
    // exd_rx interface
    input  var logic [gdr_pkt_pkg::NO_OF_RCHK-1:0] inc_rx_crc_ok,
    input  var logic [gdr_pkt_pkg::NO_OF_RCHK-1:0] inc_rx_crc_err,
    input  var logic [gdr_pkt_pkg::NO_OF_RCHK-1:0] inc_rx_sop,
    input  var logic [gdr_pkt_pkg::NO_OF_RCHK-1:0] inc_rx_eop,
    input  var logic [gdr_pkt_pkg::NO_OF_RCHK-1:0] inc_rx_pkt,
    
    //----------------------------------------------------------------------------------------
    // exd_tx interface
    input  var logic cfg_pkt_gen_done,
    input  var logic cfg_pkt_xfer_done,
    input  var logic init_done,
    
    input  var logic inc_tx_sop,
    input  var logic inc_tx_eop,
    input  var logic inc_tx_pkt,
	 
	 input  var logic stat_lat_cnt_done,
	 input  var logic [7:0] stat_lat_cnt,
	 output var logic stat_lat_cnt_en,
    
    output var gdr_pkt_pkg::CFG_GEN_MEM_REQ_s cfg_mem_req,
    input  var gdr_pkt_pkg::GEN_MEM_RD_RSP_s cfg_mem_rd_rsp,
    input  var logic cfg_mem_rd_done,
    input  var logic cfg_mem_wr_done
    
    );
    import gdr_pkt_pkg::*;
    
    //parameter  AUTO_XFER_PKT = 1;
    
    //----------------------------------------------------------------------------------------
    // Reset avmm_clk
    logic [15:0] rst_reg_avmm;
    logic rst_avmm_c2, rst_avmm_c1, rst_comb;
    CFG_SW_RST_s cfg_sw_rst_reg;
    logic exd_sw_rst, sw_rst, exd_sw_rst_c2, exd_sw_rst_c3, sw_rst_pos_pls, sw_rst_pos_pls_c1,
	  sw_rst_neg_pls, sw_rst_avmm;
    logic exd_stscnt_rst,exd_stscnt_rst_clk_sync;	  
	  //latency count
	  CFG_LAT_CNT_s cfg_lat_cnt_reg;
	  //latency adjustment count
	  CFG_LAT_ADJ_CNT_s cfg_lat_adj_cnt_reg; 
    

    always_comb begin
	exd_sw_rst = cfg_sw_rst_reg.exd_sw_rst;
        exd_stscnt_rst = cfg_sw_rst_reg.exd_stscnt_rst;	
    end
	 
	 always_ff @(posedge clk_avmm or posedge rst_avmm_clk) begin
	 if (rst_avmm_clk)
	    stat_lat_cnt_en <= '0;
	 else
		 stat_lat_cnt_en = cfg_lat_cnt_reg.lat_cnt_en;
	 end
	 
    
    exd_std_synchronizer #(.DW(1)) rst_clk_avmm_sync
       (// inputs
	.clk (clk_avmm),
	.din({  '0
               }),
		
	// outputs
	.dout ({  rst_avmm_c2
                 })
	);
    
    always_comb begin
	rst_comb = rst | exd_sw_rst;	
    end

    always_ff @(posedge clk_avmm or posedge rst) begin
	if (rst)
	    sw_rst_avmm <= '1;
	else
	    sw_rst_avmm <= rst_avmm_c2;
    end
    
    //Vivek:
    always_ff @(posedge clk_avmm or posedge rst_comb) begin
	//rst_avmm_clk <= rst_avmm_c2
	rst_avmm_clk <= rst_comb ? '1 : rst_avmm_c2;
    end // always_ff @ (posedge clk_avmm or posedge rst_avmm_c2)
    
    // Generate arrays of reset to be used in submodule
    always_ff @(posedge clk_avmm) begin
	rst_reg_avmm <= '{default:rst_avmm_clk};
    end
    //----------------------------------------------------------------------------------------
    
    //----------------------------------------------------------------------------------------
    // Reset clk
    logic [15:0] rst_reg;
    logic 	 rst_clk_c1, rst_clk_c2;
        
    exd_std_synchronizer #(.DW(1)) rst_clk_sync
       (// inputs
	.clk (clk),
	.din('0),
		
	// outputs
	.dout (rst_clk_c2)
	);
    //Vivek:
    	 reg rst_clk_reg;
    always_ff @(posedge clk or posedge rst_comb) begin	
	if (rst_comb) begin
	    rst_clk <= '1;	
		 rst_clk_reg <= '1;
	end else begin
	    rst_clk_reg <= rst_clk_c2;
		 rst_clk <= rst_clk_reg;
	end	 
  end // always_ff @ (posedge clk or posedge rst)

    // Generate arrays of reset to be used in submodule
    always_ff @(posedge clk) begin
	rst_reg <= '{default:rst_clk};
    end
    //----------------------------------------------------------------------------------------

    //----------------------------------------------------------------------------------------
    // Reset tclk
    logic [15:0] rst_tclk_reg;
    logic 	 rst_tclk_c1, rst_tclk_c2, rst_comb_avmm, rst_comb_tclk;
   
    exd_std_synchronizer #(.DW(1)) rst_tclk_sync
       (// inputs
	.clk (tclk),
	.din('0),
		
	// outputs
	.dout (rst_tclk_c2)
	);

    // RES-50002
    eth_f_multibit_sync #(
    .WIDTH(1)
    ) rst_comb_tclk_inst (
    .clk (tclk),
    .reset_n (1'b1),
    .din (rst_comb_avmm),
    .dout (rst_comb_tclk)
    ); 
	
    always_ff @(posedge clk_avmm) begin
	rst_comb_avmm <= rst_comb;
    end
    
    //Vivek:
    always_ff @(posedge tclk) begin
	
	if (rst_comb_tclk)
	    rst_tclk <= '1;	
	else 
	    rst_tclk <= rst_tclk_c2;
    end // always_ff @ (posedge clk or posedge rst)
    
    // Generate arrays of reset to be used in submodule
    always_ff @(posedge clk) begin
	rst_tclk_reg <= '{default:rst_tclk};
    end

    eth_f_xcvr_resync_std #(
        .SYNC_CHAIN_LENGTH  (3),
        .WIDTH              (1),
        .INIT_VALUE         (0)
    ) exd_stscnt_rst_sync (
        .clk                (clk),
        .reset              (1'b0),
        .d                  (exd_stscnt_rst),
        .q                  (exd_stscnt_rst_clk_sync)
    );
    //----------------------------------------------------------------------------------------

    CFG_MODE_0_s cfg_mode_reg_0,cfg_mode_reg_0_sync, cfg_mode_reg_0_c1;
    CFG_MODE_1_s cfg_mode_reg_1,cfg_mode_reg_1_sync, cfg_mode_reg_1_c1;
    CFG_MODE_2_s cfg_mode_reg_2,cfg_mode_reg_2_sync, cfg_mode_reg_2_c1;
    CFG_MODE_3_s cfg_mode_reg_3,cfg_mode_reg_3_sync, cfg_mode_reg_3_c1;
   
    
    CFG_START_PKT_GEN_s cfg_start_pkt_gen_reg, cfg_start_pkt_gen_reg_sync, cfg_start_pkt_gen_reg_c1;
    CFG_START_XFER_PKT_s cfg_xfer_pkt_reg;
    CFG_CNT_STATS_s tx_sop_cnt_reg, tx_eop_cnt_reg, tx_pkt_cnt_reg,
	            rx_sop_cnt_reg, rx_eop_cnt_reg, rx_pkt_cnt_reg,  rx_crc_ok_cnt_reg, 
                    rx_crc_err_cnt_reg,
	            tx_sop_cnt_hi_reg, tx_eop_cnt_hi_reg, tx_pkt_cnt_hi_reg,
	            rx_sop_cnt_hi_reg, rx_eop_cnt_hi_reg, rx_pkt_cnt_hi_reg, rx_crc_ok_cnt_hi_reg, 
                    rx_crc_err_cnt_hi_reg,
	            tx_sop_cnt_clk, tx_eop_cnt_clk, tx_pkt_cnt_clk,
	            tx_sop_cnt_clk_sync, tx_eop_cnt_clk_sync, tx_pkt_cnt_clk_sync,
	            rx_sop_cnt_clk, rx_eop_cnt_clk, rx_pkt_cnt_clk, rx_crc_ok_cnt_clk, 
	            rx_sop_cnt_clk_sync, rx_eop_cnt_clk_sync, rx_pkt_cnt_clk_sync, rx_crc_ok_cnt_clk_sync, 
                    rx_crc_err_cnt_clk,
                    rx_crc_err_cnt_clk_sync,
	            tx_sop_cnt_hi_clk, tx_eop_cnt_hi_clk, tx_pkt_cnt_hi_clk,
	            tx_sop_cnt_hi_clk_sync, tx_eop_cnt_hi_clk_sync, tx_pkt_cnt_hi_clk_sync,
	            rx_sop_cnt_hi_clk, rx_eop_cnt_hi_clk, rx_pkt_cnt_hi_clk, rx_crc_ok_cnt_hi_clk, 
	            rx_sop_cnt_hi_clk_sync, rx_eop_cnt_hi_clk_sync, rx_pkt_cnt_hi_clk_sync, rx_crc_ok_cnt_hi_clk_sync, 
                    rx_crc_err_cnt_hi_clk,
                    rx_crc_err_cnt_hi_clk_sync ;
 
    CFG_DREG_s [63:0] mem_reg_data,rd_rsp_mem_data,rd_rsp_mem_data_sync ;
    CFG_DREG_s [7:0] mem_reg_ctl, rd_rsp_mem_ctl;
    CFG_MEM_MISC_s mem_reg_misc, rd_rsp_mem_misc;
    CFG_MEM_ACCESS_CTL_s mem_reg_acc_ctl;
    CFG_DREG_s mem_reg_rdata, mem_reg_rctl, mem_reg_data_rdata, mem_reg_ctl_rdata,
	       rdata_c2;
    
    GEN_MEM_RD_RSP_s mem_rd_rsp_reg;
    DWORD_128_s  mem_wr_data;
    
    logic read_c1, csr_rd,
	  rd_c1, rd_c2, wr_c1, wr_c1_sync, ld_rd_rsp, clr_wr_req, clr_rd_req, mem_rd_req_c1, mem_rd_req_c2,
	  mem_wr_req_c1, mem_wr_req_c2, rd_req, wr_req, rd_req_c1, rd_req_c2, rd_req_c3,
	  wr_req_c1, wr_req_c2, wr_req_c3,
	  mem_reg_data_wren_c1, mem_reg_ctl_wren_c1, mem_reg_misc_wren_c1, 
	  mem_reg_acc_ctl_wren_c1,
	  mem_reg_data_rden_c1, mem_reg_ctl_rden_c1, mem_reg_misc_rden_c1, mem_reg_acc_rden_c1,
	  cfg_pkt_gen_done_c1, cfg_pkt_gen_done_c2, cfg_pkt_xfer_done_c1, cfg_pkt_xfer_done_c2,
	  ld_cnt_stat,ld_cnt_stat_sync, ld_cnt_stat_c1, ld_cnt_stat_c2, ld_cnt, cnt_wren_c1, cnt_wren_c2, 
	  cnt_wren,
	  cfg_mem_rd_done_c1, cfg_mem_rd_done_c2, cfg_mem_wr_done_c1, cfg_mem_wr_done_c2,
	  init_done_c1, init_done_c2, xfer_pkt_dly_done, 
	  stop_xfer_pkt_det, start_xfer_pkt_det, stop_xfer_pkt_det_c1, start_xfer_pkt_det_c1,
	  stop_xfer_pkt_csr_pls, start_xfer_pkt_csr_pls, start_xfer_pkt, start_xfer_pkt_sync;

    logic [2:0] cyc_cnt;

    logic [3:0] xfer_pkt_dly_cnt;
    
    logic [9:0] address_c1;
    logic [7:0] decode_addr, decode_addr_c1, decode_addr_c1_sync, cnt_wren_decode_addr;
    
    logic [31:0] writedata_c1,writedata_c1_sync, cnt_wr_data;
    logic [255:0] wr_array_c1, wren_array_c1;


    //----------------------------------------------------------------------------------------
    // sync inputs from clk to clk_avmm
    exd_std_synchronizer #(.DW(5)) cfg_enable_sync
       (// inputs
	.clk (clk_avmm),
	.din({init_done,
	      cfg_pkt_gen_done,
	      cfg_pkt_xfer_done,
	      cfg_mem_rd_done,
	      cfg_mem_wr_done}

	      ),
		
	// outputs
	.dout ({init_done_c1,
		cfg_pkt_gen_done_c1,
		cfg_pkt_xfer_done_c1,
		cfg_mem_rd_done_c1,
		cfg_mem_wr_done_c1})
	);
    
    always_ff @(posedge clk_avmm) begin
	cfg_mem_rd_done_c2   <= cfg_mem_rd_done_c1;
	cfg_mem_wr_done_c2   <= cfg_mem_wr_done_c1;
    end // always_ff @ (posedge clk_avmm)
    //----------------------------------------------------------------------------------------

    //----------------------------------------------------------------------------------------
    // generate loading counter stats
    always_ff @(posedge clk_avmm) begin
	cyc_cnt <= cyc_cnt + 1'b1;
	
	if (rst_reg_avmm[0])
	    cyc_cnt <= '0;

	ld_cnt_stat <= (cyc_cnt == '1);
    end // always_ff @ (posedge clk_avmm)
    //----------------------------------------------------------------------------------------

    //----------------------------------------------------------------------------------------
    // delay counter when pkt_gen is done
    always_ff @(posedge clk_avmm) begin
	if (cfg_pkt_gen_done & (xfer_pkt_dly_cnt != 4'hf))
	    xfer_pkt_dly_cnt <= xfer_pkt_dly_cnt + 1'b1;

	if (  !cfg_xfer_pkt_reg.xfer_pkt_after_pkt_gen 
	    | !cfg_pkt_gen_done                        )
	    xfer_pkt_dly_cnt <= '0;
	
	if (rst_reg_avmm[0])
	    xfer_pkt_dly_cnt <= '0;

	xfer_pkt_dly_done <= (xfer_pkt_dly_cnt == '1);
	
    end // always_ff @ (posedge clk_avmm)
    //----------------------------------------------------------------------------------------

    always_comb begin
	// stop xfering pkt detection from csr
	stop_xfer_pkt_det =   wr_c1
			   //& (decode_addr_c1 == ADDR_CFG_START_XFER_PKT)
			   & (decode_addr_c1 == ADDR_CFG_START_PKT_GEN)
			   & !writedata_c1[0]                            ;

	// start xfering pkt detection from csr
	start_xfer_pkt_det =   wr_c1
			    //& (decode_addr_c1 == ADDR_CFG_START_XFER_PKT)
			    & (decode_addr_c1 == ADDR_CFG_START_PKT_GEN)
			    & writedata_c1[0]                            ;
    end // always_comb

    always_ff @(posedge clk_avmm) begin
	stop_xfer_pkt_det_c1  <= stop_xfer_pkt_det;
	start_xfer_pkt_det_c1 <= start_xfer_pkt_det;
    end

    always_comb begin
	// edge detect for stop xfer pkt
	stop_xfer_pkt_csr_pls = stop_xfer_pkt_det & !stop_xfer_pkt_det_c1;

	// edge detect for start xfer pkt
	start_xfer_pkt_csr_pls = start_xfer_pkt_det & !start_xfer_pkt_det_c1;	
    end

    always_ff @(posedge clk_avmm) begin
	if (cfg_start_pkt_gen_reg.dyn_pkt_gen) begin
	    start_xfer_pkt <= cfg_start_pkt_gen_reg.start_pkt_gen;
	end
	else begin
	    // xfer pkt after pkt_gen
	    if (cfg_xfer_pkt_reg.xfer_pkt_after_pkt_gen) begin
		if (stop_xfer_pkt_det_c1 | !xfer_pkt_dly_done)
		    start_xfer_pkt <= '0;
		else if ( xfer_pkt_dly_done | start_xfer_pkt_det)
		    start_xfer_pkt <= '1;
	    end
	    else begin
		start_xfer_pkt <= cfg_xfer_pkt_reg.start_xfer_pkt;
	    end // else: !if(cfg_xfer_pkt_reg.xfer_pkt_after_pkt_gen)
	end
	    
	if (rst_reg_avmm[0])
	    start_xfer_pkt <= '0;	
    end
    
    always_comb begin
	// decode address
	decode_addr = address[9:2];	
    end
    
    always_ff @(posedge clk_avmm) begin
	// load decode address
	if (write | read)
	    decode_addr_c1 <= decode_addr;

	// load wr data
	if (write)
	    writedata_c1   <= writedata;
	
	read_c1 <= read ;

	rd_c1 <= csr_rd;
       
	rd_c2          <= rd_c1;
	
	wr_c1          <= write;

	
	// mem_reg data array write enable
	mem_reg_data_wren_c1 <= write & (decode_addr[7:6] == 2'b10);

	// mem_reg ctl array write enable
	mem_reg_ctl_wren_c1  <= write & (decode_addr[7:3] == 5'b11_000);

	// mem_reg misc reg write enable
	mem_reg_misc_wren_c1 <= write & (decode_addr == ADDR_MEM_MISC);

	// mem_reg access ctl reg write enable
	mem_reg_acc_ctl_wren_c1  <= write & (decode_addr == ADDR_MEM_ACCESS);
	
	// mem_reg data array rd enable
	mem_reg_data_rden_c1 <= read & (decode_addr[7:6] == 2'b10);

	// mem_reg ctl array rd enable
	mem_reg_ctl_rden_c1  <= read & (decode_addr[7:3] == 5'b11_000);

	// mem_reg misc reg rd enable
	mem_reg_misc_rden_c1 <= read & (decode_addr == ADDR_MEM_MISC);

	// mem_reg access ctl reg rd enable
	mem_reg_acc_rden_c1  <= read & (decode_addr == ADDR_MEM_ACCESS);
     	
    end // always_ff @ (posedge clk_avmm)

    
    always_ff @(posedge clk_avmm) begin
	// pre-select mem_reg data array rdata base on decode_addr
	mem_reg_data_rdata <= mem_reg_data[decode_addr[5:0]];

	// pre-select mem_reg clt array rdata base on decode_addr
	mem_reg_ctl_rdata  <= mem_reg_ctl[decode_addr[2:0]];  
    end

    always_comb begin
	csr_rd = !read_c1 & read;
    end
    
    // read data interface
    always_ff @(posedge clk_avmm) begin
	readdatavalid <= rd_c2;
	
	if (rd_c2)
	    readdata <= rdata_c2;

	if (rst_reg_avmm[15])
	    readdata <= '0;	
    end // always_ff @ (posedge clk)

    always_comb begin
	waitrequest = wr_c1 | rd_c1 | rd_c2 ? '1 :
		                              '0  ; 
    end

    // Read cycle
    always_ff @(posedge clk_avmm) begin
	case (decode_addr_c1)
	    ADDR_CFG_MODE_0        : rdata_c2  <= cfg_mode_reg_0;
	    ADDR_CFG_MODE_1        : rdata_c2  <= cfg_mode_reg_1;
	    ADDR_CFG_MODE_2        : rdata_c2  <= cfg_mode_reg_2;
	    ADDR_CFG_MODE_3        : rdata_c2  <= cfg_mode_reg_3;
	    ADDR_CFG_START_PKT_GEN : rdata_c2  <= cfg_start_pkt_gen_reg;
	    ADDR_CFG_START_XFER_PKT: rdata_c2  <= cfg_xfer_pkt_reg;
	    ADDR_TX_SOP_CNT        : rdata_c2  <= tx_sop_cnt_reg;
	    ADDR_TX_EOP_CNT        : rdata_c2  <= tx_eop_cnt_reg;
	    ADDR_TX_PKT_CNT        : rdata_c2  <= tx_pkt_cnt_reg;
	    ADDR_RX_SOP_CNT        : rdata_c2  <= rx_sop_cnt_reg;
	    ADDR_RX_EOP_CNT        : rdata_c2  <= rx_eop_cnt_reg;
	    ADDR_RX_PKT_CNT        : rdata_c2  <= rx_pkt_cnt_reg;
	    ADDR_RX_CRC_OK_CNT     : rdata_c2  <= rx_crc_ok_cnt_reg;
	    ADDR_RX_CRC_ERR_CNT    : rdata_c2  <= rx_crc_err_cnt_reg;

	    ADDR_TX_SOP_CNT_HI     : rdata_c2  <= tx_sop_cnt_hi_reg;
	    ADDR_TX_EOP_CNT_HI     : rdata_c2  <= tx_eop_cnt_hi_reg;
	    ADDR_TX_PKT_CNT_HI     : rdata_c2  <= tx_pkt_cnt_hi_reg;
	    ADDR_RX_SOP_CNT_HI     : rdata_c2  <= rx_sop_cnt_hi_reg;
	    ADDR_RX_EOP_CNT_HI     : rdata_c2  <= rx_eop_cnt_hi_reg;
	    ADDR_RX_PKT_CNT_HI     : rdata_c2  <= rx_pkt_cnt_hi_reg;
	    ADDR_RX_CRC_OK_CNT_HI  : rdata_c2  <= rx_crc_ok_cnt_hi_reg;
	    ADDR_RX_CRC_ERR_CNT_HI : rdata_c2  <= rx_crc_err_cnt_hi_reg;
	    
	    ADDR_SW_RST            : rdata_c2  <= cfg_sw_rst_reg;
            ADDR_LAT_CNT	   : rdata_c2  <= cfg_lat_cnt_reg;
            LAT_ADJ_CNT            : rdata_c2  <= cfg_lat_adj_cnt_reg;
	    ADDR_MEM_MISC          : rdata_c2  <= mem_reg_misc;
	    ADDR_MEM_ACCESS        : rdata_c2  <= mem_reg_acc_ctl;
	    default                : begin
		if (mem_reg_data_rden_c1)
		    rdata_c2  <= mem_reg_data_rdata;

		if (mem_reg_ctl_rden_c1)
		    rdata_c2  <= mem_reg_ctl_rdata;
	    end
	    
	endcase

	if (rst_reg_avmm[14])
	    rdata_c2  <= '0;
    end

    // Write cyle:
    always_ff @(posedge clk_avmm) begin
	if (wr_c1) begin
	    case (decode_addr_c1)
		ADDR_CFG_MODE_0        : begin
		    cfg_mode_reg_0 <= writedata_c1;
		    cfg_mode_reg_0.mode_op <= cfg_mode_reg_0.mode_op;
		    cfg_mode_reg_0.mode    <= cfg_mode_reg_0.mode;
		end
		ADDR_CFG_MODE_1        : cfg_mode_reg_1           <= writedata_c1;
		ADDR_CFG_MODE_2        : cfg_mode_reg_2           <= writedata_c1;
		ADDR_CFG_MODE_3        : cfg_mode_reg_3           <= writedata_c1;
		ADDR_SW_RST            : cfg_sw_rst_reg[1:0]        <= writedata_c1[1:0];
		ADDR_LAT_CNT	       : cfg_lat_cnt_reg.lat_cnt_en      <= writedata_c1[31];
		LAT_ADJ_CNT  	       : cfg_lat_adj_cnt_reg  		<= writedata_c1;
		ADDR_CFG_START_PKT_GEN : begin
		    cfg_start_pkt_gen_reg[0]     <= writedata_c1[0];
		    cfg_start_pkt_gen_reg[29:16] <= writedata_c1[29:16];
		end
		ADDR_CFG_START_XFER_PKT: cfg_xfer_pkt_reg[0]      <= writedata_c1[0];
		default: begin
		    // write cycle: data wrd registers
		    if (mem_reg_data_wren_c1)
			mem_reg_data[decode_addr_c1[5:0]] <= writedata_c1;

		    // write cycle: ctl wrd registers
		    if (mem_reg_ctl_wren_c1)
			mem_reg_ctl[decode_addr_c1[2:0]] <= writedata_c1;

		    // write cycle: misc register
		    if (mem_reg_misc_wren_c1)
			mem_reg_misc <= writedata_c1;

		    // load control access register
		    if (mem_reg_acc_ctl_wren_c1) begin
			mem_reg_acc_ctl.addr_req <= writedata_c1[31:16];
			mem_reg_acc_ctl.rd_req   <= writedata_c1[1];
			mem_reg_acc_ctl.wr_req   <= writedata_c1[0];
		    end
		end
	    endcase // case (decode_addr_c1)
	end // if (wr_c1)
	
	cfg_mode_reg_0.init_done <= init_done_c1;
	
	
	cfg_start_pkt_gen_reg[31] <= cfg_pkt_gen_done_c1;
	
	cfg_xfer_pkt_reg[31] <= cfg_pkt_xfer_done_c1;

	// load counter stats from clk domain
	if (ld_cnt_stat) begin
	    tx_sop_cnt_reg           <= tx_sop_cnt_clk_sync;
	    tx_eop_cnt_reg           <= tx_eop_cnt_clk_sync;
	    tx_pkt_cnt_reg           <= tx_pkt_cnt_clk_sync;

	    tx_sop_cnt_hi_reg        <= tx_sop_cnt_hi_clk_sync;
	    tx_eop_cnt_hi_reg        <= tx_eop_cnt_hi_clk_sync;
	    tx_pkt_cnt_hi_reg        <= tx_pkt_cnt_hi_clk_sync;
	    
	    rx_sop_cnt_reg           <= rx_sop_cnt_clk_sync;
	    rx_eop_cnt_reg           <= rx_eop_cnt_clk_sync;
	    rx_pkt_cnt_reg           <= rx_pkt_cnt_clk_sync;
	    rx_crc_ok_cnt_reg        <= rx_crc_ok_cnt_clk_sync;
	    rx_crc_err_cnt_reg       <= rx_crc_err_cnt_clk_sync;

	    rx_sop_cnt_hi_reg        <= rx_sop_cnt_hi_clk_sync;
	    rx_eop_cnt_hi_reg        <= rx_eop_cnt_hi_clk_sync;
	    rx_pkt_cnt_hi_reg        <= rx_pkt_cnt_hi_clk_sync;
	    rx_crc_ok_cnt_hi_reg     <= rx_crc_ok_cnt_hi_clk_sync;
	    rx_crc_err_cnt_hi_reg    <= rx_crc_err_cnt_hi_clk_sync;
	end

	// load rd_rsp: data wrd registers
	if (ld_rd_rsp)
	    mem_reg_data <= rd_rsp_mem_data_sync;
	
	// load rd_rsp: ctl wrd registers
	if (ld_rd_rsp)
	    mem_reg_ctl <= rd_rsp_mem_ctl;

	// load rd_rsp: misc register
	if (ld_rd_rsp)
	    mem_reg_misc <= rd_rsp_mem_misc;
	
	// clr wr_req
	if (clr_wr_req)
	    mem_reg_acc_ctl.wr_req <= '0;

	// clr rd_req
	if (clr_rd_req)
	    mem_reg_acc_ctl.rd_req <= '0;
	
	// clr rd_req
	if (rst_reg_avmm[0]) begin
	cfg_lat_cnt_reg  <= '0;
	end
	else if (stat_lat_cnt_done) begin
	    cfg_lat_cnt_reg.lat_cnt_en  <= '0;
		 cfg_lat_cnt_reg.lat_cnt <= stat_lat_cnt - cfg_lat_adj_cnt_reg[7:0];
   end
	
	if (rst_reg_avmm[0]) begin
		if (cfg_mode_op==2'd0 ) begin //PCS
              case (cfg_mode)
	           3'd0 : cfg_lat_adj_cnt_reg <= 32'd60;
                   3'd1 : cfg_lat_adj_cnt_reg <= 32'd60;
                   3'd2 : cfg_lat_adj_cnt_reg <= 32'd95;
                   3'd3 : cfg_lat_adj_cnt_reg <= 32'd65;
		   3'd4 : cfg_lat_adj_cnt_reg <= 32'd90;
		   default : cfg_lat_adj_cnt_reg <= 32'd60;
		   endcase
		end 
		else if (cfg_mode_op==2'd2 )   begin //OTN
 		  case (cfg_mode)
	                3'd0 : cfg_lat_adj_cnt_reg <= 32'd70;
                   3'd1 : cfg_lat_adj_cnt_reg <= 32'd75;
                   3'd2 : cfg_lat_adj_cnt_reg <= 32'd90;
                   3'd3 : cfg_lat_adj_cnt_reg <= 32'd95;
		             3'd4 : cfg_lat_adj_cnt_reg <= 32'd70;
		         default : cfg_lat_adj_cnt_reg <= 32'd65;
		   endcase
		end
		else if (cfg_mode_op==2'd1 )   begin //FLEXE
 		  case (cfg_mode)
	                3'd0 : cfg_lat_adj_cnt_reg <= 32'd65;
                   3'd1 : cfg_lat_adj_cnt_reg <= 32'd65;
                   3'd2 : cfg_lat_adj_cnt_reg <= 32'd75;
                   3'd3 : cfg_lat_adj_cnt_reg <= 32'd95;
		             3'd4 : cfg_lat_adj_cnt_reg <= 32'd70;
		         default : cfg_lat_adj_cnt_reg <= 32'd65;
		   endcase
		end
		else begin
 		  cfg_lat_adj_cnt_reg <= 32'd60;
		end

	end
		 
	
	if (rst_reg_avmm[0]) begin
	    cfg_mode_reg_0  <= '0;
	    cfg_mode_reg_0.ipg_dly          <= PARAM_TX_IPG_DLY;
	    cfg_mode_reg_0.rx2tx_lb         <= PARAM_RX2TX_LB;
	    cfg_mode_reg_0.disable_am_ins   <= PARAM_DISABLE_AM_INS;
	    cfg_mode_reg_0.cont_xfer_mode   <= PARAM_CONT_XFER_PKT;
	    cfg_mode_reg_0.tmii_rdy_fix_dly <= PARAM_TMII_RDY_FIX_DLY;
	    cfg_mode_reg_0.pat_mode         <= dat_pat_mode_enum(PARAM_DAT_PAT_MODE);
	    cfg_mode_reg_0.pkt_len_mode     <= pkt_len_mode_enum(PARAM_PKT_LEN_MODE);
	    cfg_mode_reg_0.mode             <= mode_enum(PARAM_RATE_OP);
	    cfg_mode_reg_0.mode_op          <= mode_op_enum(PARAM_MODE_OP);	    
	end
	    
	if (rst_reg_avmm[1]) begin
	    cfg_mode_reg_1                 <= '0;
	    cfg_mode_reg_1.no_of_inc_bytes <= PARAM_NO_OF_INC_BYTES;
	    cfg_mode_reg_1.fix_pattern     <= PARAM_FIX_DAT_PAT;
	    cfg_mode_reg_1.fix_pkt_len     <= PARAM_FIX_PKT_LEN;
	end

	if (rst_reg_avmm[2]) begin
	    cfg_mode_reg_2                <= '0;
	    cfg_mode_reg_2.no_of_xfer_pkt <= PARAM_NO_OF_XFER_PKT;
	    cfg_mode_reg_2.no_of_pkt_gen  <= PARAM_NO_OF_PKT_GEN;
	end

	if (rst_reg_avmm[3]) begin
	    cfg_mode_reg_3               <= '0;
	    cfg_mode_reg_3.am_ins_cyc    <= PARAM_AM_INS_CYC;
	    cfg_mode_reg_3.am_ins_period <= PARAM_AM_INS_PERIOD;	    
	end // if (rst_reg_avmm[3])

	if (sw_rst_avmm) 
	    cfg_sw_rst_reg <= '0;
		
	if (rst_reg_avmm[4]) begin
	    cfg_start_pkt_gen_reg <= '0;
	    cfg_start_pkt_gen_reg.dyn_pkt_gen <= PARAM_DYN_PKT_GEN;
	end
	
	if (rst_reg_avmm[5]) begin
	    cfg_xfer_pkt_reg <= '0;
	    cfg_xfer_pkt_reg.xfer_pkt_after_pkt_gen <= PARAM_AUTO_XFER_PKT;
	end

	if (rst_reg_avmm[6] | exd_stscnt_rst) 
	    tx_sop_cnt_reg <= '0;

	if (rst_reg_avmm[7] | exd_stscnt_rst) 
	    tx_eop_cnt_reg <= '0;

	if (rst_reg_avmm[8] | exd_stscnt_rst) 
	    tx_pkt_cnt_reg <= '0;
	
	if (rst_reg_avmm[9] | exd_stscnt_rst) 
	    rx_sop_cnt_reg <= '0;
	
	if (rst_reg_avmm[10] | exd_stscnt_rst) 
	    rx_eop_cnt_reg <= '0;

	if (rst_reg_avmm[11] | exd_stscnt_rst) 
	    rx_pkt_cnt_reg <= '0;

	if (rst_reg_avmm[12] | exd_stscnt_rst) 
	    rx_crc_ok_cnt_reg <= '0;
	
	if (rst_reg_avmm[13] | exd_stscnt_rst) 
	    rx_crc_err_cnt_reg <= '0;

	if (rst_reg_avmm[14])
	    mem_reg_acc_ctl <= '0;	
	
    end
   
    always_ff @(posedge clk_avmm) begin
	// clear rd_req
	clr_rd_req <= !cfg_mem_rd_done_c2 & cfg_mem_rd_done_c1;

	// clear wr req 
	clr_wr_req <= !cfg_mem_wr_done_c2 & cfg_mem_wr_done_c1 ;

	// load rd_rsp data
	ld_rd_rsp  <= !cfg_mem_rd_done_c2 & cfg_mem_rd_done_c1;	
    end

    always_comb begin
	for (int i = 0; i < 64; i++) begin
	    rd_rsp_mem_data[i] =  cfg_mem_rd_rsp.mem_data.data[i].data;
	    //rd_rsp_mem_ctl[i]  =  cfg_mem_rd_rsp.mem_data.data[i].ctl;
	end

	for (int i = 0; i < 8; i ++) begin
	    rd_rsp_mem_ctl[i][3:0]   = cfg_mem_rd_rsp.mem_data.data[(8*i)].ctl;
	    rd_rsp_mem_ctl[i][7:4]   = cfg_mem_rd_rsp.mem_data.data[(8*i)+1].ctl;
	    rd_rsp_mem_ctl[i][11:8]  = cfg_mem_rd_rsp.mem_data.data[(8*i)+2].ctl;
	    rd_rsp_mem_ctl[i][15:12] = cfg_mem_rd_rsp.mem_data.data[(8*i)+3].ctl;
	    rd_rsp_mem_ctl[i][19:16] = cfg_mem_rd_rsp.mem_data.data[(8*i)+4].ctl;
	    rd_rsp_mem_ctl[i][23:20] = cfg_mem_rd_rsp.mem_data.data[(8*i)+5].ctl;
	    rd_rsp_mem_ctl[i][27:24] = cfg_mem_rd_rsp.mem_data.data[(8*i)+6].ctl;
	    rd_rsp_mem_ctl[i][31:28] = cfg_mem_rd_rsp.mem_data.data[(8*i)+7].ctl;
	end

	rd_rsp_mem_misc           = '0;
	rd_rsp_mem_misc.sop       =  cfg_mem_rd_rsp.sop;
	rd_rsp_mem_misc.terminate =  cfg_mem_rd_rsp.terminate;	
    end // always_comb
    //----------------------------------------------------------------------------------------
    
    logic [63:0] [3:0] mem_reg_ctl_array;
        
    always_comb begin
	for (int a = 0; a < 8; a ++) begin
	    mem_reg_ctl_array[(8*a)]   = mem_reg_ctl[a][3:0];
	    mem_reg_ctl_array[(8*a)+1] = mem_reg_ctl[a][7:4];
	    mem_reg_ctl_array[(8*a)+2] = mem_reg_ctl[a][11:8];
	    mem_reg_ctl_array[(8*a)+3] = mem_reg_ctl[a][15:12];
	    mem_reg_ctl_array[(8*a)+4] = mem_reg_ctl[a][19:16];
	    mem_reg_ctl_array[(8*a)+5] = mem_reg_ctl[a][23:20];
	    mem_reg_ctl_array[(8*a)+6] = mem_reg_ctl[a][27:24];
	    mem_reg_ctl_array[(8*a)+7] = mem_reg_ctl[a][31:28];	    
	end
    end
	    
    // mem access interface
    always_comb begin
	for (int i = 0; i < 64; i ++) begin
	    mem_wr_data.data[i].data = mem_reg_data[i];
	    mem_wr_data.data[i].ctl  = mem_reg_ctl_array[i];
	end

	cfg_mem_req.mem_data   = mem_wr_data;
	cfg_mem_req.mem_addr   = mem_reg_acc_ctl.addr_req[12:0];
	cfg_mem_req.mem_wr     = mem_reg_acc_ctl.wr_req;
	cfg_mem_req.mem_rd     = mem_reg_acc_ctl.rd_req;
	cfg_mem_req.sop        = mem_reg_misc.sop;
	cfg_mem_req.terminate  = mem_reg_misc.terminate;	
    end

eth_f_multibit_sync #(
    .WIDTH(161)
) cfg_mode_reg_sync_inst (
    .clk (clk),
    .reset_n (1'b1),
    .din ({cfg_mode_reg_0,cfg_mode_reg_1,cfg_mode_reg_2,cfg_mode_reg_3,cfg_start_pkt_gen_reg,start_xfer_pkt}),
   .dout ({cfg_mode_reg_0_c1,cfg_mode_reg_1_c1,cfg_mode_reg_2_c1,cfg_mode_reg_3_c1,cfg_start_pkt_gen_reg_c1,cfg_start_xfer_pkt })

);	

/*
    exd_std_synchronizer #(.DW((32*5) + 
                                   1    )) cfg_sync_clk
       (// inputs
	.clk (clk),
	.din({cfg_mode_reg_0_sync,
	      cfg_mode_reg_1_sync,
	      cfg_mode_reg_2_sync,
	      cfg_mode_reg_3_sync,
	      cfg_start_pkt_gen_reg_sync,
	      start_xfer_pkt_sync }
	      //cfg_xfer_pkt_reg.start_xfer_pkt}

	      ),
		
	// outputs
	.dout ({cfg_mode_reg_0_c1,
		cfg_mode_reg_1_c1,
		cfg_mode_reg_2_c1,
		cfg_mode_reg_3_c1,
		cfg_start_pkt_gen_reg_c1,
		cfg_start_xfer_pkt })
	);
*/

    always_comb begin
	cfg_mode_op          = cfg_mode_reg_0_c1.mode_op;
	cfg_mode             = cfg_mode_reg_0_c1.mode;	
	cfg_pkt_len_mode     = cfg_mode_reg_0_c1.pkt_len_mode;	
	cfg_pkt_pattern_mod  = cfg_mode_reg_0_c1.pat_mode;
	cfg_tx_mii_rdy_2_vld = cfg_mode_reg_0_c1.tmii_rdy_fix_dly;
	cfg_cont_xfer_mode   = cfg_mode_reg_0_c1.cont_xfer_mode;
	cfg_disable_am_ins   = cfg_mode_reg_0_c1.disable_am_ins;
	cfg_rx_2_tx_loopbk   = cfg_mode_reg_0_c1.rx2tx_lb;
	cfg_ipg_dly          = cfg_mode_reg_0_c1.ipg_dly;

	cfg_fix_pkt_len      = cfg_mode_reg_1_c1.fix_pkt_len;
	cfg_fix_pattern      = cfg_mode_reg_1_c1.fix_pattern;
	cfg_no_of_inc_bytes  = cfg_mode_reg_1_c1.no_of_inc_bytes;
		
		
	
	cfg_am_ins_period    = cfg_mode_reg_3_c1.am_ins_period - 2'd1;
	cfg_am_ins_cyc       = cfg_mode_reg_3_c1.am_ins_cyc - 2'd1;

	cfg_start_pkt_gen    = cfg_start_pkt_gen_reg_c1.start_pkt_gen;
	cfg_sw_gen_pkt       = cfg_start_pkt_gen_reg_c1.sw_gen_pkt;
	cfg_last_mem_addr    = cfg_start_pkt_gen_reg_c1.last_mem_addr;
	cfg_dyn_pkt_gen      = cfg_start_pkt_gen_reg_c1.dyn_pkt_gen;

	cfg_no_of_pkt_gen    = cfg_mode_reg_2_c1.no_of_pkt_gen;     
	cfg_no_of_xfer_pkt   = 
          cfg_dyn_pkt_gen ? cfg_mode_reg_2_c1.no_of_pkt_gen :
                            cfg_mode_reg_2_c1.no_of_xfer_pkt;
	
        //cfg_start_xfer_pkt   = cfg_xfer_pkt_reg.start_xfer_pkt;
    end

// Fix CDC-50001
eth_f_multibit_sync #(
   .WIDTH(42)
) counter_sync_inst (
    .clk (clk),
    .reset_n (1'b1),
    .din ({decode_addr_c1,writedata_c1,ld_cnt_stat,wr_c1}),
    .dout ({decode_addr_c1_sync,writedata_c1_sync,ld_cnt_stat_sync,wr_c1_sync})
);

    counters counters
       (// input
	.clk (clk),
	.rst (rst_reg[0]|exd_stscnt_rst_clk_sync),
	.ld_cnt_stat (ld_cnt_stat_sync),
	.wr_c1 (wr_c1_sync),
	.decode_addr_c1 (decode_addr_c1_sync),
	.writedata_c1 (writedata_c1_sync),

	.inc_rx_crc_ok (inc_rx_crc_ok),
	.inc_rx_crc_err (inc_rx_crc_err),
	.inc_rx_sop (inc_rx_sop),
	.inc_rx_eop (inc_rx_eop),
	.inc_rx_pkt (inc_rx_pkt),
	.inc_tx_sop (inc_tx_sop),
	.inc_tx_eop (inc_tx_eop),
	.inc_tx_pkt (inc_tx_pkt),

	// outputs
	.tx_sop_cnt_clk (tx_sop_cnt_clk),
	.tx_eop_cnt_clk (tx_eop_cnt_clk), 
	.tx_pkt_cnt_clk (tx_pkt_cnt_clk),
	.tx_sop_cnt_hi_clk (tx_sop_cnt_hi_clk),
	.tx_eop_cnt_hi_clk (tx_eop_cnt_hi_clk), 
	.tx_pkt_cnt_hi_clk (tx_pkt_cnt_hi_clk),
	
	.rx_sop_cnt_clk (rx_sop_cnt_clk), 
	.rx_eop_cnt_clk (rx_eop_cnt_clk), 
	.rx_pkt_cnt_clk (rx_pkt_cnt_clk), 
	.rx_crc_ok_cnt_clk (rx_crc_ok_cnt_clk), 
	.rx_crc_err_cnt_clk (rx_crc_err_cnt_clk),

	.rx_sop_cnt_hi_clk (rx_sop_cnt_hi_clk), 
	.rx_eop_cnt_hi_clk (rx_eop_cnt_hi_clk), 
	.rx_pkt_cnt_hi_clk (rx_pkt_cnt_hi_clk), 
	.rx_crc_ok_cnt_hi_clk (rx_crc_ok_cnt_hi_clk), 
	.rx_crc_err_cnt_hi_clk (rx_crc_err_cnt_hi_clk)


	 );


// Fix CDC-50001
eth_f_multibit_sync #(
    .WIDTH(192)
) tx_cnt_stat_sync_inst (
    .clk (clk_avmm),
    .reset_n (1'b1),
    .din ({tx_sop_cnt_clk,tx_eop_cnt_clk,tx_pkt_cnt_clk,tx_sop_cnt_hi_clk,tx_eop_cnt_hi_clk,tx_pkt_cnt_hi_clk}),
    .dout ({tx_sop_cnt_clk_sync,tx_eop_cnt_clk_sync,tx_pkt_cnt_clk_sync,tx_sop_cnt_hi_clk_sync,tx_eop_cnt_hi_clk_sync,tx_pkt_cnt_hi_clk_sync})
);
	 
eth_f_multibit_sync #(
    .WIDTH(160)
) rx_cnt_stat_sync_inst (
    .clk (clk_avmm),
    .reset_n (1'b1),
    .din ({rx_sop_cnt_clk,rx_eop_cnt_clk,rx_pkt_cnt_clk,rx_crc_ok_cnt_clk,rx_crc_err_cnt_clk }),
    .dout ({rx_sop_cnt_clk_sync,rx_eop_cnt_clk_sync,rx_pkt_cnt_clk_sync,rx_crc_ok_cnt_clk_sync,rx_crc_err_cnt_clk_sync})
);

eth_f_multibit_sync #(
    .WIDTH(160)
) rx_hi_cnt_stat_sync_inst (
    .clk (clk_avmm),
    .reset_n (1'b1),
    .din ({rx_sop_cnt_hi_clk,rx_eop_cnt_hi_clk,rx_pkt_cnt_hi_clk,rx_crc_ok_cnt_hi_clk,rx_crc_err_cnt_hi_clk }),
    .dout ({rx_sop_cnt_hi_clk_sync,rx_eop_cnt_hi_clk_sync,rx_pkt_cnt_hi_clk_sync,rx_crc_ok_cnt_hi_clk_sync,rx_crc_err_cnt_hi_clk_sync })
);

eth_f_multibit_sync #(
    .WIDTH(2048)
) rd_rsp_data_sync_inst (
    .clk (clk_avmm),
    .reset_n (1'b1),
    .din ({rd_rsp_mem_data}),
    .dout ({rd_rsp_mem_data_sync})
);



endmodule // packet_client_csr

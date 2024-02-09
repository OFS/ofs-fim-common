// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`default_nettype none

///////////////////////////////////////////////////////////////////////////////////////////////
/*
PARAM_RATE_OP:  Define rate of operation as shown below
  typedef enum logic [2:0] 
       {
        MODE_10_25G = 3'd0,
	MODE_40_50G = 3'd1,
	MODE_100G   = 3'd2,
	MODE_200G   = 3'd3,
	MODE_400G   = 3'd4
	}MODE_e;
 
PARAM_MODE_OP: Defines mode of operation as shown below
  typedef enum logic [1:0]
       {
	MODE_PCS   = 2'd0,
	MODE_FLEXE = 2'd2,
	MODE_OTN   = 2'd1
	} MODE_OP_e; 

PARAM_PKT_LEN_MODE: Defines packet generation mode as shown below
  typedef enum logic [1:0] 
       {
        FIX_PKT_LEN = 2'd0,
	INC_PKT_LEN = 2'd1,
	RND_PKT_LEN = 2'd2
	}PKT_LEN_MODE_e;
 
PARAM_DAT_PAT_MODE: Defines data pattern mode as shown below
  typedef enum logic [1:0] 
       {
        FIX_DAT_PAT = 2'd0,
	INC_DAT_PAT = 2'd1,
	RND_DAT_PAT = 2'd2
	}DAT_PAT_MODE_e; 

PARAM_AUTO_XFER_PKT: 1: Automatic transmit packet after packet generation
                     0: Packet transmission require to activate  
 */
module pcs_packet_client  #( parameter  PARAM_AUTO_XFER_PKT     = 0
                        , PARAM_RATE_OP           = 0 
                        , PARAM_MODE_OP           = 0 
                        , PARAM_FEC_TYPE          = 0 
                        , PARAM_EHIP_RATE         = 0 
                        , PARAM_PKT_LEN_MODE      = 0 
                        , PARAM_DAT_PAT_MODE      = 1
                        , PARAM_TX_IPG_DLY        = 32
                        , PARAM_CONT_XFER_PKT     = 0
		                , PARAM_DISABLE_AM_INS    = 1
		                , PARAM_RX2TX_LB          = 0
		                , PARAM_TMII_RDY_FIX_DLY  = 3
		                , PARAM_FIX_PKT_LEN       = 64 
		                , PARAM_FIX_DAT_PAT       = 'ha6
		                , PARAM_NO_OF_INC_BYTES   = 1
		                , PARAM_NO_OF_PKT_GEN     = 16
		                , PARAM_NO_OF_XFER_PKT    = 10
		                , PARAM_AM_INS_PERIOD     = 40960
		                , PARAM_AM_INS_CYC        = 2
			            , PARAM_DYN_PKT_GEN       = 1
			            , INIT_FILE_DATA = "init_file_data.hex"
			            , INIT_FILE_DATA_B = "init_file_data_b.hex" 
                        , INIT_FILE_CTL  = "init_file_ctrl.hex"
                        , INTF_DATA66_WD = 1 << (PARAM_RATE_OP)
                        , INTF_DATA_WD = 1 << (PARAM_RATE_OP + 6)
			            , INTF_CTL_WD = 1 << (PARAM_RATE_OP + 3)
			            , INTF_SYNC_WD = 1 << (PARAM_RATE_OP + 1)
                        )
   (
    
    input  var logic tclk,
    input  var logic clk,
    input  var logic clk_avmm,
    input  var logic rst,

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
    // tmii
    input  var logic tx_mii_ready,
	   	   
    //output var gdr_pkt_pkg::PCS_D_16_WRD_s tx_mii_d,
    //output var gdr_pkt_pkg::PCS_C_16_WRD_s tx_mii_c,
    //output var gdr_pkt_pkg::PCS_SYNC_16_WRD_s tx_mii_sync
    output var logic [INTF_DATA_WD-1:0] tx_mii_d,
    output var logic [INTF_CTL_WD-1:0] tx_mii_c,
               
    output var logic [INTF_DATA66_WD*66-1:0] tx_pcs66_d,
    
    output var logic tx_mii_vld,
    output var logic tx_mii_am,

    //----------------------------------------------------------------------------------------
    // rmii 
    //input  var gdr_pkt_pkg::PCS_D_16_WRD_s rx_mii_d,
    //input  var gdr_pkt_pkg::PCS_SYNC_16_WRD_s rx_mii_sync,
    //input  var gdr_pkt_pkg::PCS_C_16_WRD_s rx_mii_c,
    input  var logic [INTF_DATA66_WD*66-1:0] rx_pcs66_d,

    input  var logic [INTF_DATA_WD-1:0] rx_mii_d,
    input  var logic [INTF_CTL_WD-1:0] rx_mii_c,
    input  var logic rx_mii_vld,
    input  var logic rx_mii_am

    );
    import gdr_pkt_pkg::*;
    //parameter  AUTO_XFER_PKT = 1;
    

    
    MODE_e cfg_mode;
    MODE_OP_e cfg_mode_op;   
    DAT_PAT_MODE_e cfg_pkt_pattern_mod;
    PKT_LEN_MODE_e cfg_pkt_len_mode;
    logic  rst_tclk, rst_clk, rst_avmm_clk;
    
    logic [INTF_DATA66_WD*66-1:0] rx_pcs66_d_rev;
    logic [INTF_DATA66_WD*66-1:0] tx_pcs66_d_rev;
    logic [INTF_DATA_WD-1:0] rx_mii_d_rev;
    logic [INTF_DATA_WD-1:0] rx_mii_d_scr;
    logic [INTF_DATA_WD-1:0] rx_mii_d_scr1;
    logic [INTF_CTL_WD-1:0]  rx_mii_c_rev;
    logic [INTF_SYNC_WD-1:0] rx_mii_sync_rev;
    logic [INTF_SYNC_WD-1:0] rx_mii_sync_scr;
    logic rx_mii_vld_rev;
    logic rx_mii_am_rev;

    logic [INTF_DATA_WD-1:0] tx_mii_d_rev;
    logic [INTF_DATA_WD-1:0] tx_mii_d_scr;
    logic [INTF_CTL_WD-1:0]  tx_mii_c_rev;
    logic [INTF_SYNC_WD-1:0] tx_mii_sync_rev;
    logic [INTF_SYNC_WD-1:0] tx_mii_sync_scr;
    logic tx_mii_vld_rev;
    logic tx_mii_am_rev, tx_mii_am_scr; 
    logic tx_mii_am_scr1;

    logic [15:0] cfg_no_of_xfer_pkt;
    logic 	 cfg_cont_xfer_mode;    
    logic [3:0]  cfg_tx_mii_rdy_2_vld;     
    logic [16:0] cfg_am_ins_period;     
    logic [3:0]  cfg_am_ins_cyc;     
    logic 	 cfg_disable_am_ins;     
    logic 	 cfg_rx_2_tx_loopbk;    
    logic [12:0] cfg_no_of_pkt_gen;
    logic [10:0] cfg_fix_pkt_len;
    logic [7:0]  cfg_no_of_inc_bytes;   
    logic [7:0]  cfg_fix_pattern;
    logic [7:0]  cfg_ipg_dly;    
    logic 	 cfg_start_pkt_gen;
    logic 	 cfg_start_xfer_pkt;
    logic 	 cfg_sw_gen_pkt;
    logic 	 cfg_dyn_pkt_gen;

 
    logic [12:0] cfg_last_mem_addr;
    
    logic 	 cfg_pkt_gen_done, cfg_pkt_xfer_done;
    logic [NO_OF_RCHK-1:0] inc_rx_crc_ok, inc_rx_crc_err, inc_rx_sop, inc_rx_eop, inc_rx_pkt,
			   inc_rx_miss_sop, inc_rx_miss_eop;
    
    logic 	 inc_tx_sop, inc_tx_eop, inc_tx_pkt, init_done;
    
    CFG_GEN_MEM_REQ_s cfg_mem_req,cfg_mem_req_sync;    
    GEN_MEM_RD_RSP_s cfg_mem_rd_rsp, cfg_mem_rd_rsp_sync;
    
    logic  cfg_mem_rd_done, cfg_mem_wr_done;
    
    PCS_D_32_WRD_s rpcs_tpcs_d;
    
    PCS_C_32_WRD_s rpcs_tpcs_c;
    
    logic rpcs_tpcs_vld;
	 
	 logic stat_lat_cnt_done_sync, stat_lat_cnt_done,stat_lat_cnt_en;
	 logic [7:0] stat_lat_cnt_sync, stat_lat_cnt;
  
//adding am markers 
logic [INTF_DATA_WD-1:0] tx_mii_am_d1;
logic [INTF_DATA_WD-1:0] tx_mii_am_d2;
logic [255:0] tx_mii_am_d3;
logic [255:0] tx_mii_am_d4;
logic [255:0] tx_mii_am_d5;
logic [INTF_SYNC_WD-1:0] tx_mii_am_sync1;
logic [INTF_SYNC_WD-1:0] tx_mii_am_sync2;
logic [7:0] tx_mii_am_sync3;
logic [7:0] tx_mii_am_sync4;
logic [7:0] tx_mii_am_sync5;
logic [16:0] am_cnt;
logic am_ins_pulse;
generate
if (PARAM_MODE_OP == 1 && PARAM_FEC_TYPE == 0 && (PARAM_RATE_OP == 1	|| PARAM_RATE_OP == 2)) begin:OTN_NOFEC_40G_50G_100G



// assign am_dx = rate ? 100G : 40_50G;
assign tx_mii_am_d5 = {8'h00,8'h1a,8'h0f,8'h3f,8'h00,8'he5,8'hf0,8'hc0, 8'h00,8'hd5,8'h99,8'ha0,8'h00,8'h2a,8'h66,8'h5f, 8'h00,8'h48,8'h29,8'h52,8'h00,8'hb7,8'hd6,8'had, 8'h00,8'hb3,8'hce,8'h3b,8'h00,8'h4c,8'h31,8'hc4};
assign tx_mii_am_d4 = {8'h00,8'h32,8'hc9,8'hca,8'h00,8'hcd,8'h36,8'h35, 8'h00,8'h35,8'h38,8'h7c,8'h00,8'hca,8'hc7,8'h83, 8'h00,8'h42,8'h07,8'he5,8'h00,8'hbd,8'hf8,8'h1a, 8'h00,8'h4d,8'h46,8'ha3,8'h00,8'hb2,8'hb9,8'h5c};
assign tx_mii_am_d3 = {8'h00,8'haa,8'h6e,8'h46,8'h00,8'h55,8'h91,8'hb9, 8'h00,8'h66,8'h93,8'h02,8'h00,8'h99,8'h6c,8'hfd, 8'h00,8'h04,8'h36,8'h97,8'h00,8'hfb,8'hc9,8'h68, 8'h00,8'h89,8'hdb,8'h5f,8'h00,8'h76,8'h24,8'ha0};
assign tx_mii_am_d2 = (PARAM_RATE_OP == 2) ? {8'h00,8'h99,8'hba,8'h84,8'h00,8'h66,8'h45,8'h7b, 8'h00,8'hd9,8'hb5,8'h65,8'h00,8'h26,8'h4a,8'h9a, 8'h00,8'h3d,8'heb,8'h22,8'h00,8'hc2,8'h14,8'hdd, 8'h00,8'hf6,8'hf8,8'h0a,8'h00,8'h09,8'h07,8'hf5}
					   : {8'h00,8'hC2,8'h86,8'h5D,8'h00,8'h3D,8'h79,8'hA2, 8'h00,8'h64,8'h9A,8'h3A,8'h00,8'h9B,8'h65,8'hC5};
assign tx_mii_am_d1 = (PARAM_RATE_OP == 2) ? {8'h00,8'h84,8'h6a,8'hb2,8'h00,8'h7b,8'h95,8'h4d, 8'h00,8'h17,8'hb4,8'ha6,8'h00,8'he8,8'h4b,8'h59, 8'h00,8'h71,8'h8e,8'h62,8'h00,8'h8e,8'h71,8'h9d, 8'h00,8'hde,8'h97,8'h3e,8'h00,8'h21,8'h68,8'hc1}
					   : {8'h00,8'h19,8'h3B,8'h0F,8'h00,8'hE6,8'hC4,8'hF0, 8'h00,8'hb8,8'h89,8'h6F,8'h00,8'h47,8'h76,8'h90};

assign tx_mii_am_sync1 = (PARAM_RATE_OP == 2) ? {2'b10, 2'b10, 2'b10, 2'b10} : {2'b10, 2'b10};
assign tx_mii_am_sync2 = (PARAM_RATE_OP == 2) ? {2'b10, 2'b10, 2'b10, 2'b10} : {2'b10, 2'b10};
assign tx_mii_am_sync3 = {2'b10, 2'b10, 2'b10, 2'b10};
assign tx_mii_am_sync4 = {2'b10, 2'b10, 2'b10, 2'b10};
assign tx_mii_am_sync5 = {2'b10, 2'b10, 2'b10, 2'b10};



always_ff @(posedge tclk) begin
	if(rst_tclk)
	  am_cnt <= 0;
	else if (tx_mii_vld) begin
		if(am_cnt == cfg_am_ins_period)
			am_cnt <= 'd0;
		else
			am_cnt <= am_cnt + 1'b1;

		am_ins_pulse <= (am_cnt >= 0 && am_cnt <= cfg_am_ins_cyc);

	end

end
end
endgenerate

//CDC FIX DA-50001
eth_f_multibit_sync #(
    .WIDTH(2306)
) mem_rd_rsp_sync_inst (
    .clk (clk_avmm),
    .reset_n (1'b1),
    .din ({cfg_mem_rd_rsp}),
    .dout ({cfg_mem_rd_rsp_sync})
);	

    packet_client_csr #(  .PARAM_AUTO_XFER_PKT (PARAM_AUTO_XFER_PKT) 
	      , .PARAM_RATE_OP (PARAM_RATE_OP)
              , .PARAM_MODE_OP (PARAM_MODE_OP)
              , .PARAM_PKT_LEN_MODE (PARAM_PKT_LEN_MODE)
              , .PARAM_DAT_PAT_MODE (PARAM_DAT_PAT_MODE)
              , .PARAM_TX_IPG_DLY (PARAM_TX_IPG_DLY)
              , .PARAM_CONT_XFER_PKT (PARAM_CONT_XFER_PKT)
              , .PARAM_DISABLE_AM_INS (PARAM_DISABLE_AM_INS)
              , .PARAM_RX2TX_LB (PARAM_RX2TX_LB)
              , .PARAM_TMII_RDY_FIX_DLY (PARAM_TMII_RDY_FIX_DLY)
              , .PARAM_FIX_PKT_LEN (PARAM_FIX_PKT_LEN)
              , .PARAM_FIX_DAT_PAT (PARAM_FIX_DAT_PAT)
              , .PARAM_NO_OF_INC_BYTES (PARAM_NO_OF_INC_BYTES)
              , .PARAM_NO_OF_PKT_GEN (PARAM_NO_OF_PKT_GEN)
              , .PARAM_NO_OF_XFER_PKT (PARAM_NO_OF_XFER_PKT) 
              , .PARAM_AM_INS_PERIOD (PARAM_AM_INS_PERIOD)
              , .PARAM_AM_INS_CYC (PARAM_AM_INS_CYC)
              , .PARAM_DYN_PKT_GEN (PARAM_DYN_PKT_GEN) ) packet_client_csr
       (// inputs
	.clk (clk),
	.clk_avmm (clk_avmm),
	.tclk (tclk),
	.rst (rst),

	// outputs
	.rst_tclk (rst_tclk),
	.rst_clk (rst_clk),
	.rst_avmm_clk (rst_avmm_clk),

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

	//------------------------------------------------------------------------------------
	// config interface
	// outputs
	.cfg_mode (cfg_mode), 
	.cfg_mode_op (cfg_mode_op),
	.cfg_pkt_len_mode (cfg_pkt_len_mode), 
	.cfg_pkt_pattern_mod (cfg_pkt_pattern_mod), 
	.cfg_fix_pkt_len (cfg_fix_pkt_len), 
	.cfg_fix_pattern (cfg_fix_pattern),
	.cfg_no_of_pkt_gen (cfg_no_of_pkt_gen), 
	.cfg_no_of_inc_bytes (cfg_no_of_inc_bytes), 
	.cfg_tx_mii_rdy_2_vld (cfg_tx_mii_rdy_2_vld),       
	.cfg_am_ins_period (cfg_am_ins_period),      
	.cfg_am_ins_cyc (cfg_am_ins_cyc),       
	.cfg_disable_am_ins (cfg_disable_am_ins), 
	.cfg_start_pkt_gen (cfg_start_pkt_gen),
	.cfg_sw_gen_pkt (cfg_sw_gen_pkt),
	.cfg_last_mem_addr (cfg_last_mem_addr),
	.cfg_no_of_xfer_pkt (cfg_no_of_xfer_pkt),      
	.cfg_cont_xfer_mode (cfg_cont_xfer_mode),       
	.cfg_ipg_dly (cfg_ipg_dly),       
	.cfg_start_xfer_pkt (cfg_start_xfer_pkt),               
	.cfg_rx_2_tx_loopbk (cfg_rx_2_tx_loopbk),
	.cfg_mem_req (cfg_mem_req),
	.cfg_dyn_pkt_gen (cfg_dyn_pkt_gen),
	
	// inputs
	.cfg_mem_rd_rsp (cfg_mem_rd_rsp_sync),
	.cfg_mem_rd_done (cfg_mem_rd_done),
	.cfg_mem_wr_done (cfg_mem_wr_done),
	
    .stat_lat_cnt_done(stat_lat_cnt_done_sync),
	 .stat_lat_cnt(stat_lat_cnt_sync),
	 .stat_lat_cnt_en(stat_lat_cnt_en),
	 
	//------------------------------------------------------------------------------------
	// tcsr interface
	// inputs
	.cfg_pkt_gen_done (cfg_pkt_gen_done),
	.cfg_pkt_xfer_done (cfg_pkt_xfer_done),
	.init_done (init_done),
	.inc_tx_sop (inc_tx_sop),
	.inc_tx_eop (inc_tx_eop),
	.inc_tx_pkt (inc_tx_pkt),
	
	//------------------------------------------------------------------------------------
	// rx_packet
	.inc_rx_crc_ok (inc_rx_crc_ok),
	.inc_rx_crc_err (inc_rx_crc_err),
	.inc_rx_sop (inc_rx_sop),
	.inc_rx_eop (inc_rx_eop),
	.inc_rx_pkt (inc_rx_pkt)
	 );

//CDC FIX DA-50001
eth_f_multibit_sync #(
    .WIDTH(2321)
) rd_rsp_data_sync_inst (
    .clk (clk),
    .reset_n (1'b1),
    .din ({cfg_mem_req}),
    .dout ({cfg_mem_req_sync})
);	 
    
    tx_packet_client #(  .PARAM_RATE_OP (PARAM_RATE_OP) 
                        ,.INIT_FILE_DATA (INIT_FILE_DATA)
			,.INIT_FILE_DATA_B (INIT_FILE_DATA_B) 
                        ,.INIT_FILE_CTL (INIT_FILE_CTL)
                        ,.INTF_DATA_WD (INTF_DATA_WD)
                        ,.INTF_CTL_WD (INTF_CTL_WD)
                        ,.INTF_SYNC_WD (INTF_SYNC_WD)   ) tx_packet_client
     (// inputs
      .tclk (tclk), 
      .clk (clk), 
      .rst (rst_clk),
      .rst_tclk (rst_tclk),
      
      //--------------------------------------------------------------------------------------
      // config interface
      // inputs
      .cfg_mode (cfg_mode), 
      .cfg_mode_op (cfg_mode_op),
      .cfg_pkt_len_mode (cfg_pkt_len_mode), 
      .cfg_pkt_pattern_mod (cfg_pkt_pattern_mod), 
      .cfg_fix_pkt_len (cfg_fix_pkt_len), 
      .cfg_fix_pattern (cfg_fix_pattern),
      .cfg_no_of_pkt_gen (cfg_no_of_pkt_gen), 
      .cfg_no_of_inc_bytes (cfg_no_of_inc_bytes), 
      .cfg_tx_mii_rdy_2_vld (cfg_tx_mii_rdy_2_vld),       
      .cfg_am_ins_period (cfg_am_ins_period),      
      .cfg_am_ins_cyc (cfg_am_ins_cyc),       
      .cfg_disable_am_ins (cfg_disable_am_ins), 
      .cfg_start_pkt_gen (cfg_start_pkt_gen),
      .cfg_sw_gen_pkt (cfg_sw_gen_pkt),
      .cfg_last_mem_addr (cfg_last_mem_addr),
      .cfg_no_of_xfer_pkt (cfg_no_of_xfer_pkt),      
      .cfg_cont_xfer_mode (cfg_cont_xfer_mode),       
      .cfg_ipg_dly (cfg_ipg_dly),       
      .cfg_start_xfer_pkt (cfg_start_xfer_pkt),               
      .cfg_rx_2_tx_loopbk (cfg_rx_2_tx_loopbk),    
      .cfg_mem_req (cfg_mem_req_sync),
      .cfg_dyn_pkt_gen (cfg_dyn_pkt_gen),
      
      // outputs
      .inc_tx_sop (inc_tx_sop),
      .inc_tx_eop (inc_tx_eop),
      .inc_tx_pkt (inc_tx_pkt),
      .cfg_mem_rd_rsp (cfg_mem_rd_rsp),
      .cfg_mem_rd_done (cfg_mem_rd_done),
      .cfg_mem_wr_done (cfg_mem_wr_done),
      //--------------------------------------------------------------------------------------

      // outputs
      .cfg_pkt_gen_done (cfg_pkt_gen_done),
      .cfg_pkt_xfer_done (cfg_pkt_xfer_done),
      .init_done (init_done),
      
      //--------------------------------------------------------------------------------------
      // tmii
      // inputs
      .tx_mii_ready (tx_mii_ready),

      // outputs
      .tx_mii_d (tx_mii_d_rev),
      .tx_mii_c (tx_mii_c_rev),
      .tx_mii_sync (tx_mii_sync_rev),
      .tx_mii_vld (tx_mii_vld_rev),
      .tx_mii_am (tx_mii_am_rev),
      //--------------------------------------------------------------------------------------

      //--------------------------------------------------------------------------------------
      // rpcs interface use for loopback
      // inputs
      .rpcs_tpcs_d (rpcs_tpcs_d),
      .rpcs_tpcs_c (rpcs_tpcs_c),
      .rpcs_tpcs_vld (rpcs_tpcs_vld)
      );
   
   rx_packet_client #(  .PARAM_RATE_OP (PARAM_RATE_OP) 
                       ,.INTF_DATA_WD (INTF_DATA_WD)
                       ,.INTF_CTL_WD (INTF_CTL_WD)
							  ,.INIT_FILE_DATA(INIT_FILE_DATA)
                       ,.INTF_SYNC_WD (INTF_SYNC_WD) ) rx_packet_client
     (// inputs
      .tclk (tclk), 
      .clk (clk), 
      .rst (rst_clk),
      .rst_tclk (rst_tclk),
      //--------------------------------------------------------------------------------------
      // config interface
      // inputs
      .cfg_mode (cfg_mode),
      .cfg_mode_op (cfg_mode_op),

      // outputs
      .inc_rx_crc_ok (inc_rx_crc_ok),
      .inc_rx_crc_err (inc_rx_crc_err),
      .inc_rx_sop (inc_rx_sop),
      .inc_rx_eop (inc_rx_eop),
      .inc_rx_pkt (inc_rx_pkt),
      .inc_rx_miss_sop (inc_rx_miss_sop),
      .inc_rx_miss_eop (inc_rx_miss_eop),
      
      //--------------------------------------------------------------------------------------
      // tpcs interface use for loopback
      // outputs
      .rpcs_tpcs_d (rpcs_tpcs_d),
      .rpcs_tpcs_c (rpcs_tpcs_c),
      .rpcs_tpcs_vld (rpcs_tpcs_vld),
      
      //--------------------------------------------------------------------------------------
      // rmii
      // inputs
      .rx_mii_d (rx_mii_d_rev),
      .rx_mii_c (rx_mii_c_rev),
      .rx_mii_sync (rx_mii_sync_rev),
      .rx_mii_vld (rx_mii_vld_rev),
      .rx_mii_am (rx_mii_am_rev)
      );


//byte reversal required

generate
genvar i,j;
if(PARAM_MODE_OP == 0) begin: BYTE_REV_PCS
    for(i=0;i<INTF_CTL_WD/8;i=i+1) //loop for every 64bits, INTF_CTL_WD=8 for 10G/25G
    begin: PCS_BYTE_REV_64BITS
        for(j=0;j<8;j=j+1)
        begin: PCS_BYTE_REV_8BITS
            assign tx_mii_d[8*(8*i+j)+7 : 8*(8*i+j)]     = tx_mii_d_rev[8*(8*i+7-j)+7 : 8*(8*i+7-j)];
            assign tx_mii_c[8*i+j]                       = tx_mii_c_rev[8*i+7-j];
            assign rx_mii_d_rev[8*(8*i+j)+7 : 8*(8*i+j)] = rx_mii_d[8*(8*i+7-j)+7 : 8*(8*i+7-j)];
            assign rx_mii_c_rev[8*i+j]                   = rx_mii_c[8*i+7-j];
        end
    end
    assign tx_pcs66_d = 'd0;
    assign tx_mii_vld = tx_mii_vld_rev;
    assign tx_mii_am = tx_mii_am_rev;
    assign rx_mii_sync_rev = {INTF_SYNC_WD{1'b0}};
    assign rx_mii_vld_rev = rx_mii_vld; 
    assign rx_mii_am_rev = rx_mii_am; 
end
else begin: BYTE_REV_OTN_FLEXE
    for(i=0;i<INTF_CTL_WD/8;i=i+1) //loop for every 64bits, INTF_CTL_WD=8 for 10G/25G
    begin: OTN_FLEXE_BYTE_REV_64BITS

        for(j=0;j<8;j=j+1)
        begin: OTN_FLEXE_BYTE_REV_8BITS
          assign tx_mii_d[8*(8*i+j)+7 : 8*(8*i+j)]     = tx_mii_d_rev[8*(8*i+7-j)+7 : 8*(8*i+7-j)];
          assign rx_mii_d_rev[8*(8*i+j)+7 : 8*(8*i+j)] = rx_mii_d_scr[8*(8*i+7-j)+7 : 8*(8*i+7-j)];
        end

        //CORRECT FORMAT FOR FLEXE IS : { B8,B7,B6,B5,B4,B3,B2,B1,REVERSED SYNC BITS }
        //E.G. {D5,55,55,55,55,55,55,78,0,1} - SOP
        //{00,00,00,00,00,00,00,1E,0,1}=0x79 - IDLE
        //{03,00,02,00,01,00,00,00,1,0} - DATA
	
	if(PARAM_MODE_OP == 1 && PARAM_FEC_TYPE == 0 && PARAM_RATE_OP == 1) begin:AM_MARKER_40G_50G_NO_FEC
		assign tx_pcs66_d[66*i+65 : 66*i]    = tx_mii_vld ? (tx_mii_am ? (am_cnt == 1 ? {tx_mii_am_d1[64*i+63 : 64*i], tx_mii_am_sync1[2*i], tx_mii_am_sync1[2*i+1]} 
											      : {tx_mii_am_d2[64*i+63 : 64*i], tx_mii_am_sync2[2*i], tx_mii_am_sync2[2*i+1]})
											      : {tx_mii_d_scr[64*i+63 : 64*i], tx_mii_sync_scr[2*i], tx_mii_sync_scr[2*i+1]})
											      : {tx_mii_d_scr[64*i+63 : 64*i], tx_mii_sync_scr[2*i], tx_mii_sync_scr[2*i+1]} ;
	end else if(PARAM_MODE_OP == 1 && PARAM_FEC_TYPE == 0 && PARAM_RATE_OP == 2) begin:AM_MARKER_100G_NO_FEC
		assign tx_pcs66_d[66*i+65 : 66*i]    = tx_mii_vld ? (tx_mii_am ? am_cnt == 1 ? {tx_mii_am_d1[64*i+63 : 64*i], tx_mii_am_sync1[2*i], tx_mii_am_sync1[2*i+1]} 
											     : am_cnt == 2 ? {tx_mii_am_d2[64*i+63 : 64*i], tx_mii_am_sync2[2*i], tx_mii_am_sync2[2*i+1]} 
									 		     : am_cnt == 3 ? {tx_mii_am_d3[64*i+63 : 64*i], tx_mii_am_sync3[2*i], tx_mii_am_sync3[2*i+1]} 
											     : am_cnt == 4 ? {tx_mii_am_d4[64*i+63 : 64*i], tx_mii_am_sync4[2*i], tx_mii_am_sync4[2*i+1]} 
											     : {tx_mii_am_d5[64*i+63 : 64*i], tx_mii_am_sync5[2*i], tx_mii_am_sync5[2*i+1]} 
											     : {tx_mii_d_scr[64*i+63 : 64*i], tx_mii_sync_scr[2*i], tx_mii_sync_scr[2*i+1]})
											     : {tx_mii_d_scr[64*i+63 : 64*i], tx_mii_sync_scr[2*i], tx_mii_sync_scr[2*i+1]} ;
	end else begin:OTHER_MODES	
        	assign tx_pcs66_d[66*i+65 : 66*i]    = {tx_mii_d_scr[64*i+63 : 64*i], tx_mii_sync_scr[2*i], tx_mii_sync_scr[2*i+1] };
	end	

        assign rx_mii_sync_scr[2*i+1:2*i]    = {rx_pcs66_d[66*i],rx_pcs66_d[66*i+1]};
        assign rx_mii_d_scr1[64*i+63 : 64*i] = rx_pcs66_d[66*i+65 : 66*i+2];
        
    end

    assign tx_mii_c = 'd0;
    assign rx_mii_c_rev = 'd0;

    scramble_new #(
        .INTF_DATA_WD(INTF_DATA_WD),
        .INTF_SYNC_WD(INTF_SYNC_WD),
        .PARAM_RATE_OP(PARAM_RATE_OP),
        .PARAM_EHIP_RATE(PARAM_EHIP_RATE),
        .PARAM_MODE_OP(PARAM_MODE_OP)
    ) scramble_new (
        //input
        .tclk(tclk),
        .rst_tclk(rst_tclk),
        .tx_mii_d(tx_mii_d),
        .tx_mii_sync_rev(tx_mii_sync_rev),
        .tx_mii_vld_rev(tx_mii_vld_rev),
        .tx_mii_am_rev(tx_mii_am_rev),
        //output
        .tx_mii_d_scr(tx_mii_d_scr),
        .tx_mii_sync_scr(tx_mii_sync_scr),
        .tx_mii_vld(tx_mii_vld),
        .tx_mii_am(tx_mii_am)
    );

    descramble_new #(
        .INTF_DATA_WD(INTF_DATA_WD),
        .INTF_SYNC_WD(INTF_SYNC_WD),
        .PARAM_RATE_OP(PARAM_RATE_OP),
        .PARAM_MODE_OP(PARAM_MODE_OP)
    ) descramble_new (
        //input
        .tclk(tclk),
        .rst_tclk(rst_tclk),
        .rx_mii_d_scr1(rx_mii_d_scr1),
        .rx_mii_sync_scr(rx_mii_sync_scr),
        .rx_mii_vld(rx_mii_vld),
        .rx_mii_am(rx_mii_am),
        //output
        .rx_mii_d_scr(rx_mii_d_scr),
        .rx_mii_sync_rev(rx_mii_sync_rev),
        .rx_mii_vld_rev(rx_mii_vld_rev),
        .rx_mii_am_rev(rx_mii_am_rev)
    );

end
endgenerate

//---------------------------------------------------------------
//latency measurement logic
eth_f_xcvr_resync_std #(
      .SYNC_CHAIN_LENGTH  (3),
      .WIDTH              (9),
      .INIT_VALUE         (0)
  ) kr_ctrl_sync (
      .clk                (clk_avmm),
      .reset              (1'b0),
      .d                  ({ stat_lat_cnt_done, stat_lat_cnt}),
      .q                  ({stat_lat_cnt_done_sync, stat_lat_cnt_sync})
  );

 eth_f_latency_measure latency_cnt(

        .i_clk_pll 			(tclk),
        .i_rst 				(rst),
		  .stat_lat_en			(stat_lat_cnt_en),
        .stat_tx_lat_sop	(inc_tx_sop),
        .stat_rx_lat_sop	(|inc_rx_sop),
		  .stat_cnt_clr		(rst_avmm_clk),
		  .stat_lat_cnt_done (stat_lat_cnt_done),
        . stat_lat_cnt		(stat_lat_cnt)
);

endmodule

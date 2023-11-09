// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`default_nettype none
module rx_packet_client #( parameter PARAM_RATE_OP           = 4
                                   , INTF_DATA_WD = 1 << (PARAM_RATE_OP + 6)
											  ,parameter INIT_FILE_DATA = "init_file_data.hex"
			           , INTF_CTL_WD = 1 << (PARAM_RATE_OP + 3)
			           , INTF_SYNC_WD = 1 << (PARAM_RATE_OP + 1) )

    
    
   (
    input  var logic tclk,
    input  var logic clk,
    input  var logic rst,
    input  var logic rst_tclk,

    //----------------------------------------------------------------------------------------
    // config
    input  var gdr_pkt_pkg::MODE_e cfg_mode,
    input  var gdr_pkt_pkg::MODE_OP_e cfg_mode_op,
    
    //----------------------------------------------------------------------------------------
    // rmii 
    //input  var PCS_D_16_WRD_s rx_mii_d,
    //input  var PCS_C_16_WRD_s rx_mii_c,
    //input  var PCS_SYNC_16_WRD_s rx_mii_sync,
    input  var logic [INTF_DATA_WD-1:0] rx_mii_d,
    input  var logic [INTF_CTL_WD-1:0] rx_mii_c,
    input  var logic [INTF_SYNC_WD-1:0] rx_mii_sync ,
    input  var logic rx_mii_vld,
    input  var logic rx_mii_am,

    output var logic [gdr_pkt_pkg::NO_OF_RCHK-1:0] inc_rx_crc_ok,
    output var logic [gdr_pkt_pkg::NO_OF_RCHK-1:0] inc_rx_crc_err,
    output var logic [gdr_pkt_pkg::NO_OF_RCHK-1:0] inc_rx_sop,
    output var logic [gdr_pkt_pkg::NO_OF_RCHK-1:0] inc_rx_eop,
    output var logic [gdr_pkt_pkg::NO_OF_RCHK-1:0] inc_rx_pkt,
    output var logic [gdr_pkt_pkg::NO_OF_RCHK-1:0] inc_rx_miss_sop,
    output var logic [gdr_pkt_pkg::NO_OF_RCHK-1:0] inc_rx_miss_eop,
    
    output var gdr_pkt_pkg::PCS_D_32_WRD_s rpcs_tpcs_d,
    output var gdr_pkt_pkg::PCS_C_32_WRD_s rpcs_tpcs_c,
    output var logic rpcs_tpcs_vld
    );
    import gdr_pkt_pkg::*;
    
    PCS_D_16_WRD_s [1:0] rmii_dscr_d;
    
    PCS_SYNC_16_WRD_s [1:0] rmii_dscr_sync;
    PCS_C_16_WRD_s [1:0] rmii_dscr_c;
    
    logic rmii_dscr_vld;

    logic rx_pcs_sop_det;
    logic rx_pcs_term_det;
    logic [NO_OF_RCHK-1:0] rx_pcs_pkt_vld;
    logic [NO_OF_RCHK_ADDR-1:0] rx_pcs_pkt_ln_id;
    PCS_D_WRD_s [31:0] rx_pcs_d;
    PCS_C_WRD_s [31:0] rx_pcs_c;
    MODE_e [31:0] cfg_mode_array;

    logic [1023:0] rx_mii_d_i;
    
    logic [127:0] rx_mii_c_i;
    
    logic [31:0]  rx_mii_sync_i;
    
    logic [47:0] rst_reg;
    // Generate arrays of reset to be used in submodule
    always_ff @(posedge clk) begin
	rst_reg <= '{default:rst};
    end

    always_ff @(posedge clk) begin
       for (int i = 0; i < 32; i++) begin
	  cfg_mode_array[i] <= cfg_mode;	  
       end

    end

    generate 
	//------------------------------------------------------------------------------------
	// Generate 400G generated pkt mem
	if (PARAM_RATE_OP == 4) begin: rx_intf_gen_400G
	    always_comb begin
		rx_mii_d_i = rx_mii_d;
		rx_mii_c_i = rx_mii_c;
		rx_mii_sync_i = rx_mii_sync;		
	    end
	end
	//------------------------------------------------------------------------------------
	// Generate 200G generated pkt mem
	else if (PARAM_RATE_OP == 3) begin: rx_intf_gen_200G
	    always_comb begin
		rx_mii_d_i = {512'd0, rx_mii_d};
		rx_mii_c_i = {64'd0, rx_mii_c};
		rx_mii_sync_i = {16'd0, rx_mii_sync};		
	    end
	end // block: rx_intf_gen_200G
	//------------------------------------------------------------------------------------
	// Generate 100G generated pkt mem
	else if (PARAM_RATE_OP == 1) begin: rx_intf_gen_100G
	    always_comb begin
		rx_mii_d_i    = {512'd0, 256'd0, rx_mii_d};
		rx_mii_c_i    = {64'd0,   32'd0, rx_mii_c};
		rx_mii_sync_i = {16'd0,    8'd0, rx_mii_sync};		
	    end
	end // block: rx_intf_gen_100G
	//------------------------------------------------------------------------------------
	// Generate 50G generated pkt mem
	else if (PARAM_RATE_OP == 1) begin: rx_intf_gen_50G
	    always_comb begin
		rx_mii_d_i    = {512'd0, 256'd0, 128'd0, rx_mii_d};
		rx_mii_c_i    = {64'd0,   32'd0,  16'd0, rx_mii_c};
		rx_mii_sync_i = {16'd0,    8'd0,   4'd0, rx_mii_sync};		
	    end
	end // block: rx_intf_gen_50G
	//------------------------------------------------------------------------------------
	// Generate 10G generated pkt mem
	else   begin: rx_intf_gen_10G
	    always_comb begin
		rx_mii_d_i    = {512'd0, 256'd0, 128'd0, 64'd0, rx_mii_d};
		rx_mii_c_i    = {64'd0,   32'd0,  16'd0,  8'd0, rx_mii_c};
		rx_mii_sync_i = {16'd0,    8'd0,   4'd0,  2'd0, rx_mii_sync};		
	    end
	end 
    endgenerate
    
    
    rmii rmii
       (// inputs
	.tclk (tclk),
	.rst (rst_reg[32]),
	.rx_mii_d (rx_mii_d_i),
	.rx_mii_c (rx_mii_c_i),
	.rx_mii_sync (rx_mii_sync_i),
	.rx_mii_vld (rx_mii_vld),
	.rx_mii_am (rx_mii_am),

	// outputs
	.rmii_dscr_d (rmii_dscr_d),
	.rmii_dscr_c (rmii_dscr_c),
	.rmii_dscr_sync (rmii_dscr_sync),
	.rmii_dscr_vld (rmii_dscr_vld)
	);

    rscr rscr (// inputs
	    .clk (clk),
	    .rst (rst_reg[33]),
	    .cfg_mode (cfg_mode),
	    .cfg_mode_op (cfg_mode_op),
	    .rmii_dscr_d (rmii_dscr_d),
	    .rmii_dscr_c (rmii_dscr_c),
	    .rmii_dscr_sync (rmii_dscr_sync),
	    .rmii_dscr_vld (rmii_dscr_vld),

	    // outputs
	    .rx_pcs_sop_det (rx_pcs_sop_det),
	    .rx_pcs_term_det (rx_pcs_term_det),
	    .rx_pcs_pkt_vld (rx_pcs_pkt_vld),
	    .rx_pcs_pkt_ln_id (rx_pcs_pkt_ln_id),
	    .rx_pcs_d (rx_pcs_d),
	    .rx_pcs_c (rx_pcs_c)
	);
    
    always_ff @(posedge clk)  begin
	rpcs_tpcs_d   <= rx_pcs_d;
	rpcs_tpcs_c   <= rx_pcs_c;
	rpcs_tpcs_vld <= |rx_pcs_pkt_vld;	
    end
    
    genvar l;
	generate
	    for (l = 0; l < NO_OF_RCHK; l++) begin: RX_PACKET_CHCK
		rchk #(.PARAM_RATE_OP(PARAM_RATE_OP),.INIT_FILE_DATA(INIT_FILE_DATA))  rchk
		    (// inputs
		     .clk (clk),
		     .rst (rst_reg[0]),
		     //.my_id ('0),
		     .cfg_mode (cfg_mode_array[l]),
		     .rx_pcs_sop_det (rx_pcs_sop_det & rx_pcs_pkt_vld[l]),
		     .rx_pcs_term_det (rx_pcs_term_det & rx_pcs_pkt_vld[l]),
		     .rx_pcs_pkt_vld (rx_pcs_pkt_vld[l]),
		     //.rx_pcs_pkt_ln_id (rx_pcs_pkt_ln_id),
		     .rx_pcs_d (rx_pcs_d),
		     .rx_pcs_c (rx_pcs_c),

		     // outputs
		     .crc32_ok (inc_rx_crc_ok[l]),
		     .crc32_err (inc_rx_crc_err[l]),
		     .inc_rx_sop (inc_rx_sop[l]),
		     .inc_rx_eop (inc_rx_eop[l]),
		     .inc_rx_pkt (inc_rx_pkt[l]),
		     .inc_rx_miss_sop (inc_rx_miss_sop[l]),
		     .inc_rx_miss_eop (inc_rx_miss_eop[l])
		     );
	    end // for (l = 0; l < 32; l++)
	endgenerate
     
    
endmodule

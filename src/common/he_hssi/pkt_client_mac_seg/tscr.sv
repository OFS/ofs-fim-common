// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`default_nettype none
module tscr
    import gdr_pkt_pkg::*;
   (
    input  var logic clk,
    input  var logic rst,
    input  var MODE_e cfg_mode,
    input  var MODE_OP_e cfg_mode_op, 
    
    input  var PCS_D_32_WRD_s tpcs_tscr_d,
    input  var PCS_C_32_WRD_s tpcs_tscr_c,
    input  var logic tpcs_tscr_vld,
    input  var logic tpcs_tscr_pref_push,
    output var logic tscr_rdy,

    output var PCS_D_16_WRD_s [1:0] tscr_tmii_d,
    output var PCS_C_16_WRD_s [1:0]  tscr_tmii_c,
    output var PCS_SYNC_16_WRD_s [1:0] tscr_tmii_sync,
    output var logic tscr_tmii_vld,
    input  var logic tmii_rdy
    );

    logic [15:0] rst_reg;

    // Generate arrays of reset to be used in submodule
    always_ff @(posedge clk) begin
	rst_reg <= '{default:rst};
    end
    
    PCS_D_32_WRD_s tmii_d;
    PCS_SYNC_WRD_s [31:0] tmii_c;
    PCS_D_WRD_s [31:0] enc_data, tdata;
    PCS_SYNC_WRD_s [31:0] enc_sync, tsync;
    logic [31:0] enc_vld;

    PCS_D_WRD_s [31:0] pcs_data;
    PCS_SYNC_WRD_s [31:0] pcs_sync;
    PCS_C_WRD_s [31:0] pcs_ctl;
    
    logic [31:0] scr_vld;
    logic 	 pcs_vld;
    
    PCS_D_16_WRD_s [1:0] tscr_data;
    PCS_C_16_WRD_s [1:0]  tscr_ctl;
    PCS_SYNC_16_WRD_s [1:0] tscr_sync;
    
    logic tscr_data_vld, tscr_fifo_full, tscr_fifo_empty, tscr_data_pop,tmii_rdy_c1;
    logic [4:0] tscr_fifo_cnt, occ_cnt;
    
    // encoding data
    genvar 	 k;
	generate
	    for (k = 0; k < 32; k ++) begin: ENCODER_BLOCK		
        encoder encode (
          // inputs
		      .clk (clk),
		      .rst (rst),
		      .i_data (tpcs_tscr_d.data[k]),
		      .i_ctl (tpcs_tscr_c.ctl[k]),
		      .i_vld (tpcs_tscr_vld),
		      // outputs
		      .enc_data (enc_data[k]),
		      .enc_sync (enc_sync[k]),
		      .enc_vld (enc_vld[k])
		      );
	    end // for (k = 0; k < 32; k ++)
	endgenerate

    always_ff @(posedge clk) begin
	case (cfg_mode_op)
	    MODE_OP_e'(MODE_PCS): begin
		pcs_data <= tpcs_tscr_d;
		pcs_sync <= '0;
		for (int i = 0; i < 32; i++) begin
		    pcs_ctl[i] <= tpcs_tscr_c.ctl[i];
		end
		pcs_vld           <= tpcs_tscr_vld;
	    end // case: MODE_OP_e'(MODE_PCS)
	    MODE_OP_e'(MODE_FLEXE): begin
		pcs_data <= enc_data;
		pcs_ctl <= '0;
		pcs_sync <= enc_sync;
		pcs_vld  <= |enc_vld;
	    end // case: MODE_OP_e'(MODE_FLEXE)
	    MODE_OP_e'(MODE_OTN): begin
 		    pcs_data <= enc_data;
		    pcs_ctl <= '0;
		    pcs_sync <= enc_sync;
		    pcs_vld  <= |enc_vld;
	    end // case: MODE_OP_e'(MODE_OTN)
	    default: begin
		pcs_data <= '0;
		pcs_ctl <= '0;
		pcs_sync <= '0;
		pcs_vld  <= '0;
	    end // case: default
	endcase
    end

    always_ff @(posedge clk) begin
	tmii_rdy_c1 <= tmii_rdy;
    end
	
    always_ff @(posedge clk) begin
	tscr_data_vld <= pcs_vld;
	
	case (cfg_mode)
	    MODE_e'(MODE_10_25G): begin
		for (int i = 0 ; i < 1; i++) begin
		    tscr_data[0].data[i] <= pcs_data[i];
		    tscr_data[1].data[i] <= pcs_data[1+i];
		    tscr_ctl[0].ctl[i] <= pcs_ctl[i];
		    tscr_ctl[1].ctl[i] <= pcs_ctl[1+i];
		    tscr_sync[0].sync[i] <= pcs_sync[i];
		    tscr_sync[1].sync[i] <= pcs_sync[1+i];
		end // for (int i = 0 ; i < 2; i++)
	    end
	    MODE_e'(MODE_40_50G ): begin
		for (int i = 0 ; i < 2; i++) begin
		    tscr_data[0].data[i] <= pcs_data[i];
		    tscr_data[1].data[i] <= pcs_data[2+i];
		    tscr_ctl[0].ctl[i] <= pcs_ctl[i];
		    tscr_ctl[1].ctl[i] <= pcs_ctl[2+i];
		    tscr_sync[0].sync[i] <= pcs_sync[i];
		    tscr_sync[1].sync[i] <= pcs_sync[2+i];
		end // for (int i = 0 ; i < 2; i++)
	    end // case: MODE_e'(MODE_40_50G )
	    MODE_e'(MODE_100G): begin
		for (int i = 0 ; i < 4; i++) begin
		    tscr_data[0].data[i] <= pcs_data[i];
		    tscr_data[1].data[i] <= pcs_data[4+i];
		    tscr_ctl[0].ctl[i] <= pcs_ctl[i];
		    tscr_ctl[1].ctl[i] <= pcs_ctl[4+i];
		    tscr_sync[0].sync[i] <= pcs_sync[i];
		    tscr_sync[1].sync[i] <= pcs_sync[4+i];
		end // for (int i = 0 ; i < 8; i++)
	    end // case: MODE_e'(MODE_100G)
	    MODE_e'(MODE_200G): begin
		for (int i = 0 ; i < 8; i++) begin
		    tscr_data[0].data[i] <= pcs_data[i];
		    tscr_data[1].data[i] <= pcs_data[8+i];
		    tscr_ctl[0].ctl[i] <= pcs_ctl[i];
		    tscr_ctl[1].ctl[i] <= pcs_ctl[8+i];
		    tscr_sync[0].sync[i] <= pcs_sync[i];
		    tscr_sync[1].sync[i] <= pcs_sync[8+i];
		end // for (int i = 0 ; i < 16; i++)
	    end // case: MODE_e'(MODE_200G)
	    MODE_e'(MODE_400G): begin
		for (int i = 0 ; i < 16; i++) begin
		    tscr_data[0].data[i] <= pcs_data[i];
		    tscr_data[1].data[i] <= pcs_data[16+i];
		    tscr_ctl[0].ctl[i] <= pcs_ctl[i];
		    tscr_ctl[1].ctl[i] <= pcs_ctl[16+i];
		    tscr_sync[0].sync[i] <= pcs_sync[i];
		    tscr_sync[1].sync[i] <= pcs_sync[16+i];
		end
	    end // case: MODE_e'(MODE_400G)
	    default: begin
		tscr_data <= '0;
		tscr_ctl <= '0;
		tscr_sync <= '0;
	    end
	endcase
    end // always_ff @ (posedge clk)

    always_ff @(posedge clk) begin
	if (tpcs_tscr_vld & !tscr_data_pop)
	    occ_cnt <= occ_cnt + 1'b1;
	else if (!tpcs_tscr_vld & tscr_data_pop)
	     occ_cnt <= occ_cnt - 1'b1;
	if (rst_reg[15])
	    occ_cnt <= '0;	
    end
    
   eth_f_scfifo_mlab #(
       .WIDTH ((PCS_D_16_WRD_WD*2) +
		      (PCS_C_16_WRD_WD*2) +
		      (PCS_SYNC_16_WRD_WD*2)) 
   ) tscr_fifo (
       .sclr  (rst_reg[1]),
       .clk   (clk),
       .wreq  (tscr_data_vld),
       .wdata ({tscr_sync,tscr_ctl,tscr_data}),
       .full  (tscr_fifo_full),
       .rreq  (tscr_data_pop),
       .rdata ({tscr_tmii_sync,tscr_tmii_c,tscr_tmii_d}),
	    .empty(tscr_fifo_empty),
	    .cnt  (tscr_fifo_cnt)
   );

    always_comb begin
	tscr_data_pop = tmii_rdy_c1 & !tscr_fifo_empty;
	tscr_tmii_vld = tscr_data_pop;
    end
    always_comb begin
	tscr_rdy = occ_cnt < 5'd9;	
    end
endmodule

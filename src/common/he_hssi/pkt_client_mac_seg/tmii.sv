// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`default_nettype none
module tmii
    import gdr_pkt_pkg::*;
    
   (
    input  var logic tclk,
    input  var logic rst,
    input  var MODE_e cfg_mode, // 0: 10/25G (8B)
                                // 1: 40/50G (16B)
                                // 2: 100G   (32B)
                                // 3: 200G   (64B)
                                // 4: 400G   (128B)
    
    input  var logic [3:0] cfg_tx_mii_rdy_2_vld, // number of fix delay from tx_mii_ready
                                                 //  to tx_mii_valid. Note minimum setting
                                                 //  is 3.

    input  var logic [16:0] cfg_am_ins_period, // am insertion "period - 1"
    
    input  var logic [3:0] cfg_am_ins_cyc, // am insertion "cyc - 1"
    
    input  var logic cfg_disable_am_ins, // 1: disable am insertion function
                                         // 0: enable am insertion function
    

    //----------------------------------------------------------------------------------------
    // tscr interface
    input  var PCS_D_16_WRD_s [1:0] tscr_tmii_d,
    input var PCS_C_16_WRD_s [1:0] tscr_tmii_c,
    input  var PCS_SYNC_16_WRD_s [1:0] tscr_tmii_sync,
    input  var logic tscr_tmii_vld,
    
    output var logic tmii_rdy,
    
    //----------------------------------------------------------------------------------------
    // tx_mii interface
    input  var logic tx_mii_ready,
    
    output var PCS_D_16_WRD_s tx_mii_d,
    output var PCS_C_16_WRD_s tx_mii_c,
    output var PCS_SYNC_16_WRD_s tx_mii_sync,
    output var logic tx_mii_vld,
    output var logic tx_mii_am
    );

    
    logic [15:0] rst_reg;
    logic 	 rst_c1_tclk, rst_c2_tclk;
    
    always_ff @(posedge tclk) begin
	rst_c1_tclk <= rst;
	rst_c2_tclk <= rst_c1_tclk ;	
    end
    
    // Generate arrays of reset to be used in submodule
    always_ff @(posedge tclk) begin
	rst_reg <= '{default:rst_c2_tclk};
    end

    MODE_e cfg_mode_c1;
    
    PCS_D_16_WRD_s [1:0] tscr_tmii_d_c1, tscr_tmii_d_c2;  
    
    PCS_SYNC_16_WRD_s [1:0] tscr_tmii_sync_c1, tscr_tmii_sync_c2;
    PCS_C_16_WRD_s [1:0] tscr_tmii_c_c1, tscr_tmii_c_c2;

    PCS_D_16_WRD_s tmii_d,tmii_d_reg, o_tmii_d;
    PCS_SYNC_16_WRD_s tmii_sync,tmii_sync_reg, o_tmii_sync;
    PCS_C_16_WRD_s tmii_c,tmii_c_reg, o_tmii_c;
    
    logic tscr_tmii_vld_c1, tscr_tmii_vld_c2, cfg_disable_am_ins_tclk, 
	  tmii_vld,tmii_vld_reg, full, empty, pop,
	  tx_mii_rdy_c1, tx_mii_rdy_c2, tx_mii_rdy_c3, tx_mii_rdy_c4, tx_mii_rdy_c5,
	  tx_mii_rdy_c6, tx_mii_rdy_c7, tx_mii_rdy_c8, tx_mii_rdy_c9, tx_mii_rdy_c10,
	  tx_mii_rdy_dly, am_ins_cyc_done, am_ins_cyc, clr_am_ins_cnt ;

    logic [4:0] cnt;

    logic [3:0] cfg_tx_mii_rdy_2_vld_tclk, am_ins_cyc_cnt, cfg_am_ins_cyc_tclk;

    logic [9:0] tx_mii_rdy_dly_array;
    
    logic [15:0] toggle;

    logic [16:0] cfg_am_ins_period_tclk, am_ins_cnt;
    
    always_ff @(posedge tclk) begin
	tscr_tmii_d_c1 <= tscr_tmii_d;
	tscr_tmii_sync_c1 <= tscr_tmii_sync;
	tscr_tmii_c_c1 <= tscr_tmii_c;
	tscr_tmii_vld_c1 <= tscr_tmii_vld;

	cfg_tx_mii_rdy_2_vld_tclk <= cfg_tx_mii_rdy_2_vld;
	
	cfg_mode_c1      <= cfg_mode;
	cfg_am_ins_cyc_tclk <= cfg_am_ins_cyc;
	cfg_am_ins_period_tclk <= cfg_am_ins_period;
	cfg_disable_am_ins_tclk <= cfg_disable_am_ins;
	
    end
		
    always_ff @(posedge tclk) begin
	toggle <= ~toggle;
	
	if (rst_reg[0])
	    toggle <= '0;
    end // always_ff @ (posedge tclk)

    always_ff @(posedge tclk) begin
	if (toggle[0])
	    tscr_tmii_vld_c2 <= tscr_tmii_vld_c1;
	
	for (int i = 0; i < 16; i++) begin
	    if (toggle[i]) begin
		tscr_tmii_d_c2[0].data[i] <=  tscr_tmii_d_c1[0].data[i];
		tscr_tmii_d_c2[1].data[i] <=  tscr_tmii_d_c1[1].data[i];
		
		tscr_tmii_sync_c2[0].sync[i] <= tscr_tmii_sync_c1[0].sync[i];
		tscr_tmii_sync_c2[1].sync[i] <= tscr_tmii_sync_c1[1].sync[i];

		tscr_tmii_c_c2[0].ctl[i] <= tscr_tmii_c_c1[0].ctl[i];
		tscr_tmii_c_c2[1].ctl[i] <= tscr_tmii_c_c1[1].ctl[i];
	    end // if (toggle[i])
	end // for (int i = 0; i < 16; i++)

	if (rst_reg[0])
	    tscr_tmii_vld_c2 <= '0;
	
    end // always_ff @ (posedge tclk)
    
    always_ff @(posedge tclk) begin
	for (int i = 0; i < 16; i++) begin
	    if (toggle[i]) begin
		tmii_d.data[i] <= tscr_tmii_d_c2[1].data[i];
		tmii_sync.sync[i] <= tscr_tmii_sync_c2[1].sync[i];
		
		tmii_c.ctl[i] <= tscr_tmii_c_c2[1].ctl[i];
		
	    end
	    else begin
		tmii_d.data[i] <= tscr_tmii_d_c2[0].data[i];
		tmii_sync.sync[i] <= tscr_tmii_sync_c2[0].sync[i];
		tmii_c.ctl[i] <= tscr_tmii_c_c2[0].ctl[i];
	    end		
	end

	tmii_vld <= tscr_tmii_vld_c2;

	if (rst_reg[0]) 
	    tmii_vld <= '0;	
    end

    // Generate tx_mii_ready pipe delay
    always_ff @(posedge tclk) begin
	tx_mii_rdy_c1 <= tx_mii_ready;
	tx_mii_rdy_c2 <= tx_mii_rdy_c1;
	tx_mii_rdy_c3 <= tx_mii_rdy_c2;
	tx_mii_rdy_c4 <= tx_mii_rdy_c3;
	tx_mii_rdy_c5 <= tx_mii_rdy_c4;
	tx_mii_rdy_c6 <= tx_mii_rdy_c5;
	tx_mii_rdy_c7 <= tx_mii_rdy_c6;
	tx_mii_rdy_c8 <= tx_mii_rdy_c7;
	tx_mii_rdy_c9 <= tx_mii_rdy_c8;
	tx_mii_rdy_c10 <= tx_mii_rdy_c9;	
    end // always_ff @ (posedge clkf)

    always_comb begin
	tx_mii_rdy_dly_array[0] = tx_mii_ready;
	tx_mii_rdy_dly_array[1] = tx_mii_rdy_c1;
	tx_mii_rdy_dly_array[2] = tx_mii_rdy_c2;
	tx_mii_rdy_dly_array[3] = tx_mii_rdy_c3;
	tx_mii_rdy_dly_array[4] = tx_mii_rdy_c4;
	tx_mii_rdy_dly_array[5] = tx_mii_rdy_c5;
	tx_mii_rdy_dly_array[6] = tx_mii_rdy_c6;
	tx_mii_rdy_dly_array[7] = tx_mii_rdy_c7;
	tx_mii_rdy_dly_array[8] = tx_mii_rdy_c8;
	tx_mii_rdy_dly_array[9] = tx_mii_rdy_c9;

	tx_mii_rdy_dly = tx_mii_rdy_dly_array[cfg_tx_mii_rdy_2_vld_tclk];	
    end // always_comb

    always_ff @(posedge tclk) begin
	if (toggle[0])
	    tmii_rdy <= cnt < 5'd10;
    end


    always_comb begin
	pop = tx_mii_rdy_dly & !empty & !am_ins_cyc;	
    end


// am insertion cyc counts
    always_ff @(posedge tclk) begin
	if (tx_mii_rdy_dly) begin
        if(am_ins_cnt == cfg_am_ins_period_tclk)
	        am_ins_cnt <= 'd0;
        else
	        am_ins_cnt <= am_ins_cnt + 1'b1;
        am_ins_cyc <= (cfg_disable_am_ins_tclk)? 1'b0 : (am_ins_cnt >= 0 && am_ins_cnt <= cfg_am_ins_cyc_tclk); 
    end 
	
	if (rst_reg[2])
        begin
	    am_ins_cnt <= '0;	
	    am_ins_cyc <= '0;	
        end
    end // always_ff @ (posedge clkf)
    always_ff @(posedge tclk) begin
	tx_mii_vld   <= tx_mii_rdy_dly;//| am_ins_cyc;
	tx_mii_d     <= (am_ins_cyc)? 'd0 : o_tmii_d;
	tx_mii_c     <= (am_ins_cyc)? 'd0 : o_tmii_c;
	tx_mii_sync  <= o_tmii_sync;
	tx_mii_am    <= am_ins_cyc;
    end

    always_ff @(posedge tclk) begin
	    tmii_vld_reg  <= tmii_vld;
	    tmii_sync_reg <= tmii_sync;
	    tmii_c_reg    <= tmii_c;
	    tmii_d_reg    <= tmii_d;
    end

   eth_f_scfifo_mlab #(
       .WIDTH (PCS_D_16_WRD_WD +
		      PCS_C_16_WRD_WD +
		      PCS_SYNC_16_WRD_WD) 
   ) tmii_pref_fifo (
       .sclr   (rst),
       .clk   (tclk),
       .wreq  (tmii_vld_reg),
       .wdata  ({tmii_sync_reg,
	            tmii_c_reg,
	            tmii_d_reg }), 
       .full   (full),
       .rreq   (pop),
       .rdata  ({o_tmii_sync,
		        o_tmii_c,
	            o_tmii_d }),
	    .empty (empty),
	    .cnt (cnt)
   );

endmodule

// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT



`default_nettype none
module rmii

    import gdr_pkt_pkg::*;
    
   (
    input  var logic tclk,
    input  var logic rst,

    input  var PCS_D_16_WRD_s rx_mii_d,
    input  var PCS_SYNC_16_WRD_s rx_mii_sync,
    input  var PCS_C_16_WRD_s rx_mii_c,
    input  var logic rx_mii_vld,
    input  var logic rx_mii_am,

    output var PCS_D_16_WRD_s [1:0] rmii_dscr_d,
    output var PCS_C_16_WRD_s [1:0] rmii_dscr_c,
    output var PCS_SYNC_16_WRD_s [1:0] rmii_dscr_sync,
    output var logic rmii_dscr_vld
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
    //----------------------------------------------------------------------------------------

    PCS_D_16_WRD_s rx_mii_d_c1, rx_mii_d_c2;
    
    PCS_C_16_WRD_s rx_mii_c_c1, rx_mii_c_c2;

    PCS_SYNC_16_WRD_s rx_mii_sync_c1, rx_mii_sync_c2;

    logic rvld, rvld_c1, rvld_c2, rtoggle, rtoggle_c1, rtoggle_c2, dscr_vld_c1,
	  dscr_vld_c2, dscr_vld_c3;
    
    logic [15:0] rtoggle_array, rtoggle_array_c1, rtoggle_array_c2, rvld_array,
		 rx_mii_vld_array_c1, rx_mii_vld_array_c2, rx_mii_am_c1, rx_mii_vld_c2,
		 rmii_vld, rmii_am;

    PCS_D_16_WRD_s [1:0] rmii_dscr_d_ld;
   
    PCS_C_16_WRD_s [1:0] rmii_dscr_c_ld;
   
    PCS_SYNC_16_WRD_s [1:0] rmii_dscr_sync_ld;
   
    logic 	 rmii_dscr_vld_ld;
   
      
    always_comb begin
	rvld = rx_mii_vld & !rx_mii_am;
	rvld_array = {16{rvld}};	
    end

    

    always_comb begin
	dscr_vld_c1 = rtoggle_c1 & rvld_c1;
    end
    
    always_ff @(posedge tclk) begin
		
	rtoggle_c1 <= rtoggle;	
	rtoggle_array_c1 <= rtoggle_array;
	
	

	
	dscr_vld_c2 <= dscr_vld_c1;
	
	rtoggle_c2 <= rtoggle_c1;
	rtoggle_array_c2 <= rtoggle_array_c1;
	


	dscr_vld_c3 <= dscr_vld_c2;	
    end // always_ff @ (posedge tclk)

    // pipe1 rx data
    always_ff @(posedge tclk) begin
	rx_mii_vld_array_c1 <= rvld_array;
	rvld_c1             <= rvld;
	
	for (int i = 0; i < 16; i++) begin
	    if (rvld_array[i]) begin
		rx_mii_d_c1.data[i]      <= rx_mii_d.data[i];
		rx_mii_c_c1.ctl[i]       <= rx_mii_c.ctl[i];
		rx_mii_sync_c1.sync[i]   <= rx_mii_sync.sync[i];
	    end
	end // for (int i = 0; i < 16; i++)
    end

    // pipe1 rx data
    always_ff @(posedge tclk) begin
	rx_mii_vld_array_c2 <= rx_mii_vld_array_c1;
	rvld_c2             <= rvld_c1;
	
	for (int i = 0; i < 16; i++) begin
	    if (rx_mii_vld_array_c1[i]) begin
		rx_mii_d_c2.data[i]      <= rx_mii_d_c1.data[i];
		rx_mii_c_c2.ctl[i]       <= rx_mii_c_c1.ctl[i];
		rx_mii_sync_c2.sync[i]   <= rx_mii_sync_c1.sync[i];	
	    end
	end
    end
    
    always_ff @(posedge tclk) begin
	if (rvld_c1) begin
	    rtoggle       <= !rtoggle;
	    rtoggle_array <= ~rtoggle_array;
	end
	
	if (rst_reg[0]) begin
	    rtoggle       <= '0;
	    rtoggle_array <= '0;
	end
    end // always_ff @ (posedge tclk)

    logic ld_data, ld_data_c1, ld_data_c2, ld_data_extend;
    
    always_comb begin
	// ld data
	//ld_data = rtoggle & rvld_c1 & rvld_c2;
	ld_data = rtoggle & rvld_c1 ;
    end

    always_ff @(posedge tclk) begin
	ld_data_c1 <= ld_data;
	ld_data_c2 <= ld_data_c1;
    end

    always_comb begin
	ld_data_extend = ld_data_c1 | ld_data_c2;
	rmii_dscr_vld_ld  = ld_data_extend;
    end
    
    always_ff @(posedge tclk) begin	
	for (int i = 0; i < 16; i++) begin
	    /*
	    if (rtoggle_array[i]       & 
		rx_mii_vld_array_c1[i] & 
		rx_mii_vld_array_c2[i]   ) begin*/
	    if (rtoggle_array[i]       & 
		rx_mii_vld_array_c1[i]   ) begin
		rmii_dscr_d_ld[0].data[i] <= rx_mii_d_c2.data[i];
		rmii_dscr_d_ld[1].data[i] <= rx_mii_d_c1.data[i];

		rmii_dscr_c_ld[0].ctl[i] <= rx_mii_c_c2.ctl[i];
		rmii_dscr_c_ld[1].ctl[i] <= rx_mii_c_c1.ctl[i];
		
		rmii_dscr_sync_ld[0].sync[i] <= rx_mii_sync_c2.sync[i];
		rmii_dscr_sync_ld[1].sync[i] <= rx_mii_sync_c1.sync[i];
	    end
	end
    end

    always_ff @(posedge tclk) begin
       rmii_dscr_d <= rmii_dscr_d_ld;
       rmii_dscr_c <= rmii_dscr_c_ld;
       rmii_dscr_sync <= rmii_dscr_sync_ld;
       rmii_dscr_vld  <= rmii_dscr_vld_ld;
    end
   
endmodule // rmii

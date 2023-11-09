// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`default_nettype none
module counters
    import gdr_pkt_pkg::*;
   (
    input  var logic clk,
    input  var logic rst,

    input  var logic ld_cnt_stat,
    input  var logic wr_c1,
    input  var logic [7:0] decode_addr_c1,
    input  var logic [31:0] writedata_c1, 
    
    //----------------------------------------------------------------------------------------
    // exd_rx interface
    input  var logic [NO_OF_RCHK-1:0] inc_rx_crc_ok,
    input  var logic [NO_OF_RCHK-1:0] inc_rx_crc_err,
    input  var logic [NO_OF_RCHK-1:0] inc_rx_sop,
    input  var logic [NO_OF_RCHK-1:0] inc_rx_eop,
    input  var logic [NO_OF_RCHK-1:0] inc_rx_pkt,
    
    //----------------------------------------------------------------------------------------
    // exd_tx interface
    
    input  var logic inc_tx_sop,
    input  var logic inc_tx_eop,
    input  var logic inc_tx_pkt,

    output var logic [31:0] tx_sop_cnt_clk, 
    output var logic [31:0] tx_eop_cnt_clk, 
    output var logic [31:0] tx_pkt_cnt_clk,
    output var logic [31:0] tx_sop_cnt_hi_clk, 
    output var logic [31:0] tx_eop_cnt_hi_clk, 
    output var logic [31:0] tx_pkt_cnt_hi_clk,
    
    output var logic [31:0] rx_sop_cnt_clk, 
    output var logic [31:0] rx_eop_cnt_clk, 
    output var logic [31:0] rx_pkt_cnt_clk, 
    output var logic [31:0] rx_crc_ok_cnt_clk, 
    output var logic [31:0] rx_crc_err_cnt_clk,

    output var logic [31:0] rx_sop_cnt_hi_clk, 
    output var logic [31:0] rx_eop_cnt_hi_clk, 
    output var logic [31:0] rx_pkt_cnt_hi_clk, 
    output var logic [31:0] rx_crc_ok_cnt_hi_clk, 
    output var logic [31:0] rx_crc_err_cnt_hi_clk

    );

    logic [15:0] rst_reg;
    // Generate arrays of reset to be used in submodule
    always_ff @(posedge clk) begin
	rst_reg <= '{default:rst};
    end

    
    logic cnt_wren, cnt_wren_c1, cnt_wren_c2, cnt_wren_pls,
	  ld_cnt_stat_c1, ld_cnt_stat_c2, ld_cnt_stat_pls,
	  inc_rx_crc_ok_cnt, inc_rx_crc_err_cnt, 
	  inc_rx_sop_cnt, inc_rx_eop_cnt, inc_rx_pkt_cnt,
	  inc_tx_sop_cnt, inc_tx_eop_cnt, inc_tx_pkt_cnt,
	  rx_sop_cnt_wen, rx_eop_cnt_wen, rx_pkt_cnt_wen, 
	  rx_crc_ok_cnt_wen, rx_crc_err_cnt_wen,
	  tx_sop_cnt_wen, tx_eop_cnt_wen, tx_pkt_cnt_wen,
	  inc_rx_sop_cnt_c1, inc_rx_eop_cnt_c1, inc_rx_pkt_cnt_c1,
	  inc_rx_crc_ok_cnt_c1, inc_rx_crc_err_cnt_c1,
	  inc_tx_sop_cnt_c1, inc_tx_eop_cnt_c1, inc_tx_pkt_cnt_c1,
	  rx_sop_cnt_hi_wen, rx_eop_cnt_hi_wen, rx_pkt_cnt_hi_wen, 
	  rx_crc_ok_cnt_hi_wen, rx_crc_err_cnt_hi_wen,
	  tx_sop_cnt_hi_wen, tx_eop_cnt_hi_wen, tx_pkt_cnt_hi_wen;

    logic [5:0] rx_sop_cnt_value, rx_eop_cnt_value, rx_pkt_cnt_value, rx_crc_ok_cnt_value,
		rx_crc_err_cnt_value;

    logic [7:0] cnt_wren_decode_addr;

    logic [31:0] cnt_wr_data;
    

    logic [32:0] tx_sop_cnt, tx_eop_cnt, tx_pkt_cnt,
	         rx_sop_cnt, rx_eop_cnt, rx_pkt_cnt,  rx_crc_ok_cnt, rx_crc_err_cnt;
    logic [31:0] tx_sop_cnt_hi, tx_eop_cnt_hi, tx_pkt_cnt_hi,
	         rx_sop_cnt_hi, rx_eop_cnt_hi, rx_pkt_cnt_hi, 
		 rx_crc_ok_cnt_hi, rx_crc_err_cnt_hi;

    //----------------------------------------------------------------------------------------
    /*// sync data from clk_avmm to clk
    eth_f_multibit_sync #(
    .WIDTH(2)
    ) cnt_sync_inst (
    .clk (clk),
    .reset_n (1'b1),
    .din ({wr_c1,ld_cnt_stat}),
    .dout ({cnt_wren_c1,ld_cnt_stat_c1})


);*/
    assign  ld_cnt_stat_c1 = ld_cnt_stat;
    assign cnt_wren_c1 = wr_c1;
      
    
    always_ff @(posedge clk) begin	
	cnt_wren_c2 <= cnt_wren_c1;	
	ld_cnt_stat_c2 <= ld_cnt_stat_c1;
    end // always_ff @ (posedge clk)
    
    always_ff @(posedge clk) begin
	cnt_wren_pls <= !cnt_wren_c2 & cnt_wren_c1;
	
	ld_cnt_stat_pls <= !ld_cnt_stat_c2 & ld_cnt_stat_c1;	
    end

    always_ff @(posedge clk) begin
	// ld write address and data from avmm_clk
	if (cnt_wren_pls) begin
	    cnt_wren_decode_addr <= decode_addr_c1;
	    cnt_wr_data          <= writedata_c1;
	end

	// update counter from csr interface
	cnt_wren <= cnt_wren_pls;			   
    end // always_ff @ (posedge clk)
    
    always_comb begin
	rx_sop_cnt_wen     = cnt_wren & (cnt_wren_decode_addr == ADDR_RX_SOP_CNT);
	rx_eop_cnt_wen     = cnt_wren & (cnt_wren_decode_addr == ADDR_RX_EOP_CNT);
	rx_pkt_cnt_wen     = cnt_wren & (cnt_wren_decode_addr == ADDR_RX_PKT_CNT);
	rx_crc_ok_cnt_wen  = cnt_wren & (cnt_wren_decode_addr == ADDR_RX_CRC_OK_CNT);
	rx_crc_err_cnt_wen = cnt_wren & (cnt_wren_decode_addr == ADDR_RX_CRC_ERR_CNT);
	rx_sop_cnt_hi_wen     = cnt_wren & (cnt_wren_decode_addr == ADDR_RX_SOP_CNT_HI);
	rx_eop_cnt_hi_wen     = cnt_wren & (cnt_wren_decode_addr == ADDR_RX_EOP_CNT_HI);
	rx_pkt_cnt_hi_wen     = cnt_wren & (cnt_wren_decode_addr == ADDR_RX_PKT_CNT_HI);
	rx_crc_ok_cnt_hi_wen  = cnt_wren & (cnt_wren_decode_addr == ADDR_RX_CRC_OK_CNT_HI);
	rx_crc_err_cnt_hi_wen = cnt_wren & (cnt_wren_decode_addr == ADDR_RX_CRC_ERR_CNT_HI);

	tx_sop_cnt_wen     = cnt_wren & (cnt_wren_decode_addr == ADDR_TX_SOP_CNT);
	tx_eop_cnt_wen     = cnt_wren & (cnt_wren_decode_addr == ADDR_TX_EOP_CNT);
	tx_pkt_cnt_wen     = cnt_wren & (cnt_wren_decode_addr == ADDR_TX_PKT_CNT);
	tx_sop_cnt_hi_wen     = cnt_wren & (cnt_wren_decode_addr == ADDR_TX_SOP_CNT_HI);
	tx_eop_cnt_hi_wen     = cnt_wren & (cnt_wren_decode_addr == ADDR_TX_EOP_CNT_HI);
	tx_pkt_cnt_hi_wen     = cnt_wren & (cnt_wren_decode_addr == ADDR_TX_PKT_CNT_HI);
    end // always_comb
    
    always_ff @(posedge clk) begin	
	rx_sop_cnt_value <= Add_Array(inc_rx_sop);
	rx_eop_cnt_value <= Add_Array(inc_rx_eop);
	rx_pkt_cnt_value <= Add_Array(inc_rx_pkt);
	rx_crc_ok_cnt_value  <= Add_Array(inc_rx_crc_ok);
	rx_crc_err_cnt_value <= Add_Array(inc_rx_crc_err);
	inc_rx_sop_cnt      <= |inc_rx_sop;	
	inc_rx_eop_cnt      <= |inc_rx_eop;	
	inc_rx_pkt_cnt      <= |inc_rx_pkt;	
	inc_rx_crc_ok_cnt   <= |inc_rx_crc_ok;	
	inc_rx_crc_err_cnt  <= |inc_rx_crc_err;

	inc_rx_sop_cnt_c1      <= inc_rx_sop_cnt;	
	inc_rx_eop_cnt_c1      <= inc_rx_eop_cnt;	
	inc_rx_pkt_cnt_c1      <= inc_rx_pkt_cnt;	
	inc_rx_crc_ok_cnt_c1   <= inc_rx_crc_ok_cnt;	
	inc_rx_crc_err_cnt_c1  <= inc_rx_crc_err_cnt;

	inc_tx_sop_cnt_c1 <= inc_tx_sop;
	inc_tx_eop_cnt_c1 <= inc_tx_eop;
	inc_tx_pkt_cnt_c1 <= inc_tx_pkt;
	
    end

    always_ff @(posedge clk) begin
	// add lower 32 bits counter
	rx_sop_cnt <= Cnt_Stat(inc_rx_sop_cnt, rx_sop_cnt_value, rx_sop_cnt[31:0], 
                               rx_sop_cnt_wen, cnt_wr_data);

	// add upper 32 bits with a carry from lower 32 bits counter
	rx_sop_cnt_hi <= Cnt_Stat_Hi(inc_rx_sop_cnt_c1, rx_sop_cnt[32], rx_sop_cnt_hi[31:0], 
                                     rx_sop_cnt_hi_wen, cnt_wr_data);

	// add lower 32 bits counter
	rx_eop_cnt <= Cnt_Stat(inc_rx_eop_cnt, rx_eop_cnt_value, rx_eop_cnt[31:0], 
                               rx_eop_cnt_wen, cnt_wr_data);

	// add upper 32 bits with a carry from lower 32 bits counter
	rx_eop_cnt_hi <= Cnt_Stat_Hi(inc_rx_eop_cnt_c1, rx_eop_cnt[32], rx_eop_cnt_hi[31:0], 
                                     rx_eop_cnt_hi_wen, cnt_wr_data);

	// add lower 32 bits counter
	rx_pkt_cnt <= Cnt_Stat(inc_rx_pkt_cnt, rx_pkt_cnt_value, rx_pkt_cnt[31:0], 
                               rx_pkt_cnt_wen, cnt_wr_data);

	// add upper 32 bits with a carry from lower 32 bits counter
	rx_pkt_cnt_hi <= Cnt_Stat_Hi(inc_rx_pkt_cnt_c1, rx_pkt_cnt[32], rx_pkt_cnt_hi[31:0], 
                                     rx_pkt_cnt_hi_wen, cnt_wr_data);

	// add lower 32 bits counter
	rx_crc_ok_cnt <= Cnt_Stat(inc_rx_crc_ok_cnt, rx_crc_ok_cnt_value, rx_crc_ok_cnt[31:0], 
                                  rx_crc_ok_cnt_wen, cnt_wr_data);

	// add upper 32 bits with a carry from lower 32 bits counter
	rx_crc_ok_cnt_hi <= 
          Cnt_Stat_Hi(inc_rx_crc_ok_cnt_c1, rx_crc_ok_cnt[32], rx_crc_ok_cnt_hi[31:0], 
                      rx_crc_ok_cnt_hi_wen, cnt_wr_data);
	
	// add lower 32 bits counter
	rx_crc_err_cnt <= Cnt_Stat(inc_rx_crc_err_cnt, rx_crc_err_cnt_value, rx_crc_err_cnt[31:0], 
                                   rx_crc_err_cnt_wen, cnt_wr_data);

	// add upper 32 bits with a carry from lower 32 bits counter
	rx_crc_err_cnt_hi <= 
          Cnt_Stat_Hi(inc_rx_crc_err_cnt_c1, rx_crc_err_cnt[32], rx_crc_err_cnt_hi[31:0], 
                      rx_crc_err_cnt_hi_wen, cnt_wr_data);
	
	// add lower 32 bits counter
	tx_sop_cnt <= Cnt_Stat(inc_tx_sop, 6'd1, tx_sop_cnt[31:0], 
                               tx_sop_cnt_wen, cnt_wr_data);

	// add upper 32 bits with a carry from lower 32 bits counter
	tx_sop_cnt_hi <= Cnt_Stat_Hi(inc_tx_sop_cnt_c1, tx_sop_cnt[32], tx_sop_cnt_hi[31:0], 
                                     tx_sop_cnt_hi_wen, cnt_wr_data);
	
	// add lower 32 bits counter
	tx_eop_cnt <= Cnt_Stat(inc_tx_eop, 6'd1, tx_eop_cnt[31:0], 
                               tx_eop_cnt_wen, cnt_wr_data);

	// add upper 32 bits with a carry from lower 32 bits counter
	tx_eop_cnt_hi <= Cnt_Stat_Hi(inc_tx_eop_cnt_c1, tx_eop_cnt[32], tx_eop_cnt_hi[31:0], 
                                     tx_eop_cnt_hi_wen, cnt_wr_data);
	
	// add lower 32 bits counter
	tx_pkt_cnt <= Cnt_Stat(inc_tx_pkt, 6'd1, tx_pkt_cnt[31:0], 
                               tx_pkt_cnt_wen, cnt_wr_data);

	// add upper 32 bits with a carry from lower 32 bits counter
	tx_pkt_cnt_hi <= Cnt_Stat_Hi(inc_tx_pkt_cnt_c1, tx_pkt_cnt[32], tx_pkt_cnt_hi[31:0], 
                                     tx_pkt_cnt_hi_wen, cnt_wr_data);
	
	if (rst_reg[0])
	    rx_sop_cnt <= '0;

	if (rst_reg[1])
	    rx_eop_cnt <= '0;

	if (rst_reg[2])
	    rx_pkt_cnt <= '0;

	if (rst_reg[3])
	    rx_crc_ok_cnt <= '0;

	if (rst_reg[4])
	    rx_crc_err_cnt <= '0;

	if (rst_reg[5])
	    tx_sop_cnt <= '0;

	if (rst_reg[6])
	    tx_eop_cnt <= '0;

	if (rst_reg[7])
	    tx_pkt_cnt <= '0;

	if (rst_reg[8])
	    rx_sop_cnt_hi <= '0;

	if (rst_reg[9])
	    rx_eop_cnt_hi <= '0;

	if (rst_reg[10])
	    rx_pkt_cnt_hi <= '0;

	if (rst_reg[11])
	    rx_crc_ok_cnt_hi <= '0;

	if (rst_reg[12])
	    rx_crc_err_cnt_hi <= '0;

	if (rst_reg[13])
	    tx_sop_cnt_hi <= '0;

	if (rst_reg[14])
	    tx_eop_cnt_hi <= '0;

	if (rst_reg[15])
	    tx_pkt_cnt_hi <= '0;
    end // always_ff @ (posedge clk)

    always_ff @(posedge clk) begin
	if (ld_cnt_stat_pls) begin
	    rx_sop_cnt_clk <= rx_sop_cnt[31:0];
	    rx_eop_cnt_clk <= rx_eop_cnt[31:0];
	    rx_pkt_cnt_clk <= rx_pkt_cnt[31:0];
	    rx_crc_ok_cnt_clk <= rx_crc_ok_cnt[31:0];
	    rx_crc_err_cnt_clk <= rx_crc_err_cnt[31:0];

	    rx_sop_cnt_hi_clk <= rx_sop_cnt_hi[31:0];
	    rx_eop_cnt_hi_clk <= rx_eop_cnt_hi[31:0];
	    rx_pkt_cnt_hi_clk <= rx_pkt_cnt_hi[31:0];
	    rx_crc_ok_cnt_hi_clk <= rx_crc_ok_cnt_hi[31:0];
	    rx_crc_err_cnt_hi_clk <= rx_crc_err_cnt_hi[31:0];
	    
	    tx_sop_cnt_clk <= tx_sop_cnt[31:0];
	    tx_eop_cnt_clk <= tx_eop_cnt[31:0];
	    tx_pkt_cnt_clk <= tx_pkt_cnt[31:0];

	    tx_sop_cnt_hi_clk <= tx_sop_cnt_hi[31:0];
	    tx_eop_cnt_hi_clk <= tx_eop_cnt_hi[31:0];
	    tx_pkt_cnt_hi_clk <= tx_pkt_cnt_hi[31:0];
	end	
    end
    
    function [32:0] Cnt_Stat;
	input logic inc;
	input logic [5:0] inc_value;
	input logic [31:0] cnt_reg;
	input logic 	   wren;
	input logic [31:0] wdata;
	
		    

	begin
	    logic [16:0] cnt_lsb;
	    logic [16:0] cnt_msb;
	    logic [31:0] cnt;
	    
	    cnt_lsb = inc ? cnt_reg[15:0] + inc_value :
                            {1'b0, cnt_reg[15:0]};
	    cnt_msb = inc ? cnt_lsb[16] + cnt_reg[31:16] :
                            {1'b0, cnt_reg[31:16]} ;
	    
	    cnt = cnt_msb[16] ? '1 :
		                 {cnt_msb[15:0], cnt_lsb[15:0]};
	    
	    Cnt_Stat = wren ? wdata : cnt ;	    
	end
    endfunction // Cnt_Stat

     function [31:0] Cnt_Stat_Hi;
	input logic inc;
	input logic inc_value;
	input logic [31:0] cnt_reg;
	input logic 	   wren;
	input logic [31:0] wdata;
	
		    

	begin
	    logic [16:0] cnt_lsb;
	    logic [16:0] cnt_msb;
	    logic [31:0] cnt;
	    
	    cnt_lsb = inc ? cnt_reg[15:0] + inc_value :
                            {1'b0, cnt_reg[15:0]};
	    cnt_msb = inc ? cnt_lsb[16] + cnt_reg[31:16] :
                            {1'b0, cnt_reg[31:16]} ;
	    
	    cnt = cnt_msb[16] ? '1 :
		                 {cnt_msb[15:0], cnt_lsb[15:0]};
	    
	    Cnt_Stat_Hi = wren ? wdata : cnt ;	    
	end
    endfunction 

    function [NO_OF_RCHK_ADDR:0] Add_Array;
	input logic [NO_OF_RCHK-1:0] din;

	begin
	    logic [NO_OF_RCHK_ADDR:0] tmp_cnt, tmp_sum;
	    
	    tmp_cnt = '0;
	    
	    for (int i = 0; i < NO_OF_RCHK; i++) begin
		
		tmp_sum = tmp_cnt + din[i];
		tmp_cnt = tmp_sum;		
	    end // for (int i = 0; i < NO_OF_RCHK; i++)
	    Add_Array = tmp_sum;
	    /*
	    Add_Array = din[0] + din[1] + din[2] + din[3] +
			din[4] + din[5] + din[6] + din[7] +
			din[8] + din[9] +
			din[10] + din[11] + din[12] + din[13] +
			din[14] + din[15] + din[16] + din[17] +
			din[18] + din[19] +
			din[20] + din[21] + din[22] + din[23] +
			din[24] + din[25] + din[26] + din[27] +
			din[28] + din[29] +
			din[30] + din[31] ;	    
	     */
	end
    endfunction

endmodule // counters



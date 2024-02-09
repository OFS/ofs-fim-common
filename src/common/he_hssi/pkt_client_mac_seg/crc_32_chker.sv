// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT




//--------------------------------------------------------------------------------------------
`default_nettype none
module crc_32_chker
  (
   input  var logic clk,
   input  var logic rst,
   input  var logic [3:0] [7:0] i_data,
   input  var logic [1:0] i_bytes_vld,
   input  var logic i_sop,
   input  var logic i_eop,
   input  var logic i_vld,

   
   output var logic crc32_ok,
   output var logic crc32_err
   );

    logic vld_dly, sop_dly, eop_dly, 
	  i_sop_c1, i_eop_c1, i_vld_c1, i_sop_c2, i_eop_c2, i_vld_c2,
	  i_rx_sop, i_rx_eop, i_rx_vld, i_rx_fcs, crc32_chk_cyc;
    
    logic [1:0] i_bytes_vld_c1, i_bytes_vld_c2, i_rx_bytes_vld;
    
    logic [31:0] crc_reg, crc_out;
    
    logic [3:0] [7:0] i_data_c1, i_data_c2, i_rx_data, i_rx_crc_data,
                      bit_reverse_data, i_data_tmp, bit_reverse_data_crc,
		      reflect_crc_reg, crc_reg_tmp;

    logic [31:0] [31:0] cal_crc32_poly;
    logic [31:0] crc32_poly_reg, crc32_data, cal_crc32_poly_reg;
    
    always_ff @(posedge clk) begin
	i_data_c1 <= i_data;
	i_bytes_vld_c1 <= i_bytes_vld;
	i_sop_c1 <= i_sop;
	i_eop_c1 <= i_eop;
	i_vld_c1 <= i_vld;
	
	i_data_c2 <= i_data_c1;
	i_bytes_vld_c2 <= i_bytes_vld_c1;
	i_sop_c2 <= i_sop_c1;
	i_eop_c2 <= i_eop_c1;
	i_vld_c2 <= i_vld_c1;
    end // always_ff @ (posedge clk)

    // extract the last 4 bytes of fcs
    always_ff @(posedge clk) begin
	if (i_eop) begin
	    case (i_bytes_vld)
		2'd1: begin
		    i_rx_data      <= 
                      {i_data_c1[3], 8'd0, 8'd0, 8'd0};
		    i_rx_bytes_vld <= i_bytes_vld;
		    i_rx_sop       <= '0;
		    i_rx_eop       <= '1;		    		    
		    i_rx_vld       <= '1;
		    i_rx_crc_data  <= 
                      {i_data_c1[2], i_data_c1[1], i_data_c1[0], i_data[3]};
		    
		end // case: 2'd1
		2'd2: begin
		    i_rx_data      <= 
                      {i_data_c1[3], i_data_c1[2], 8'd0, 8'd0};
		    i_rx_bytes_vld <= i_bytes_vld;
		    i_rx_sop       <= '0;
		    i_rx_eop       <= '1;		    		    
		    i_rx_vld       <= '1;
		    i_rx_crc_data  <= 
                      {i_data_c1[1], i_data_c1[0], i_data[3], i_data[2]};
		end // case: 2'd2
		2'd3: begin
		    i_rx_data      <= 
                      {i_data_c1[3], i_data_c1[2], i_data_c1[1], 8'd0};
		    i_rx_bytes_vld <= i_bytes_vld;
		    i_rx_sop       <= '0;
		    i_rx_eop       <= '1;		    		    
		    i_rx_vld       <= '1;
		    i_rx_crc_data  <= 
                      {i_data_c1[0], i_data[3], i_data[2], i_data[1]};
		end // case: 2'd3
		default: begin
		    i_rx_data      <= 
                      {i_data_c1[3], i_data_c1[2], i_data_c1[1], i_data_c1[0]};
		    i_rx_bytes_vld <= i_bytes_vld;
		    i_rx_sop       <= '0;
		    i_rx_eop       <= '1;		    
		    
		    i_rx_vld       <= '1;
		    i_rx_crc_data  <= 
                      {i_data[3], i_data[2], i_data[1], i_data[0]};
		end // case: default
	    endcase // case (i_bytes_vld)
	end // if (i_eop)
	else begin
	    i_rx_data      <= 
	       {i_data_c1[3], i_data_c1[2], i_data_c1[1], i_data_c1[0]};
	    i_rx_bytes_vld <= '0;
	    i_rx_sop       <= i_sop_c1;
	    i_rx_eop       <= '0;		    
	    
	    i_rx_vld       <= i_vld_c1;
	    //i_rx_crc_data  <= '0;
	end // else: !if(i_eop)
    end

    always_ff @(posedge clk) begin
	i_rx_fcs <= i_rx_eop;

	crc32_chk_cyc <= i_rx_fcs;	
    end   
    
    always_ff @(posedge clk) begin
	crc32_ok  <= crc32_chk_cyc & (crc32_poly_reg  == 32'hc704_dd7b);
	crc32_err <= crc32_chk_cyc & (crc32_poly_reg  != 32'hc704_dd7b);
    end
    
    always_comb begin
	if (i_rx_eop) begin
	    case (i_rx_bytes_vld)
		2'd1: crc32_data = {24'd0, i_rx_data[3]} ;
		2'd2: crc32_data = {16'd0, i_rx_data[2], i_rx_data[3]} ;
		2'd3: crc32_data = {8'd0, i_rx_data[1], i_rx_data[2], i_rx_data[3]} ;
		default: crc32_data = {i_rx_data[0], i_rx_data[1], i_rx_data[2], i_rx_data[3]} ;
	    endcase // case (i_rx_bytes_vld)
	end
	else if (i_rx_fcs)
	    crc32_data =  {i_rx_crc_data[3], i_rx_crc_data[2], 
                           i_rx_crc_data[1], i_rx_crc_data[0]}  ;
	else 
	    crc32_data =  {i_rx_data[0], i_rx_data[1],  i_rx_data[2],  i_rx_data[3]}  ;
		    		
	
	cal_crc32_poly_reg  = i_rx_sop ? '1 : crc32_poly_reg;
	
	
	for (int p = 0; p < 32; p++) begin
	    if (p == '0)
		cal_crc32_poly[p] = next_crc32_d1(crc32_data[p], cal_crc32_poly_reg);
	    else
		cal_crc32_poly[p] = next_crc32_d1(crc32_data[p], cal_crc32_poly[p-1]);
	end
	
    end

    always_ff @(posedge clk) begin
	if (i_rx_vld)
	    crc32_poly_reg <= cal_crc32_poly[31];

	if (i_rx_eop) begin
	    case (i_rx_bytes_vld)
		2'd1:    crc32_poly_reg <= cal_crc32_poly[7];
		2'd2:    crc32_poly_reg <= cal_crc32_poly[15];
		2'd3:    crc32_poly_reg <= cal_crc32_poly[23];
		default: crc32_poly_reg <= cal_crc32_poly[31];
	    endcase
	end
	
	if (i_rx_fcs)
	    crc32_poly_reg <= cal_crc32_poly[31];
	
	if (rst)
	    crc32_poly_reg <= '1;
    end
    
    
    function [3:0] [7:0] Reflect_Data;
	input [3:0] [7:0] data;

	begin
	    for (int i = 0; i < 8; i++) begin
		for (int k = 0; k < 8; k ++) begin
		    Reflect_Data[i][k] = data[i][7-k];
		end
	    end
	end
    endfunction

    //----------------------------------------------------------------------------------------
    // polynomial: 
    // x^32 +x^26 +x^23 +x^22 +x^16  x^12 +x^11 +x^10 +x^8 +x^7 +x^5 +x^4 +x^2 +x^1 +1
    function [31:0] next_crc32_d1;
    
	input         dIn;
	input [31:0]  crcData;
	begin
            next_crc32_d1[0]  = dIn ^ crcData[31]             ;  // +1
            next_crc32_d1[1]  = dIn ^ crcData[31] ^ crcData[0];  // x^1
            next_crc32_d1[2]  = dIn ^ crcData[31] ^ crcData[1];  // x^2
            next_crc32_d1[3]  =                     crcData[2];
            next_crc32_d1[4]  = dIn ^ crcData[31] ^ crcData[3];  // x^4
            next_crc32_d1[5]  = dIn ^ crcData[31] ^ crcData[4];  // x^5
            next_crc32_d1[6]  =                     crcData[5];
            next_crc32_d1[7]  = dIn ^ crcData[31] ^ crcData[6];  // x^7
            next_crc32_d1[8]  = dIn ^ crcData[31] ^ crcData[7];  // x^8
            next_crc32_d1[9]  =                     crcData[8];
            next_crc32_d1[10] = dIn ^ crcData[31] ^ crcData[9];  // x^10
            next_crc32_d1[11] = dIn ^ crcData[31] ^ crcData[10]; // x^11
            next_crc32_d1[12] = dIn ^ crcData[31] ^ crcData[11]; // x^12
            next_crc32_d1[13] =                     crcData[12];
            next_crc32_d1[14] =                     crcData[13];
            next_crc32_d1[15] =                     crcData[14];
            next_crc32_d1[16] = dIn ^ crcData[31] ^ crcData[15]; // x^16
            next_crc32_d1[17] =                     crcData[16];
            next_crc32_d1[18] =                     crcData[17];
            next_crc32_d1[19] =                     crcData[18];
            next_crc32_d1[20] =                     crcData[19];
            next_crc32_d1[21] =                     crcData[20];
            next_crc32_d1[22] = dIn ^ crcData[31] ^ crcData[21]; // x^22
            next_crc32_d1[23] = dIn ^ crcData[31] ^ crcData[22]; // x^23
            next_crc32_d1[24] =                     crcData[23];
            next_crc32_d1[25] =                     crcData[24];
            next_crc32_d1[26] = dIn ^ crcData[31] ^ crcData[25]; // x^26
            next_crc32_d1[27] =                     crcData[26];
            next_crc32_d1[28] =                     crcData[27];
            next_crc32_d1[29] =                     crcData[28];
            next_crc32_d1[30] =                     crcData[29];
            next_crc32_d1[31] =                     crcData[30];
	end
    endfunction

   
    


endmodule

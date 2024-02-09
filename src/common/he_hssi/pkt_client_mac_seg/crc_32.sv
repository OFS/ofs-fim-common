// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT



`default_nettype none

//--------------------------------------------------------------------------------------------
module crc_32
  (
   input  var logic clk,
   input  var logic rst,
   input  var logic [3:0] [7:0] i_data,
   input  var logic [1:0] i_bytes_vld,
   input  var logic i_sop,
   input  var logic i_eop,
   input  var logic i_vld,

   output var logic [31:0] o_crc32,
   output var logic o_crc32_vld

   );

    logic vld_dly, sop_dly, eop_dly;
    
    logic [31:0] 	   crc_reg, crc_out;   
    logic [3:0] [7:0] 	   bit_reverse_data, i_data_tmp, bit_reverse_data_crc;

    logic [3:0] [7:0] reflect_crc_reg, crc_reg_tmp;
    logic [31:0] [31:0] cal_crc32_poly;
    logic [31:0] crc32_poly_reg, crc32_data, cal_crc32_poly_reg;
    logic [31:0] o_crc32_hn;
    
    always_ff @(posedge clk) begin
	vld_dly <= i_vld;
	sop_dly <= i_sop;
	eop_dly <= i_eop;
	
	o_crc32_vld <= i_vld & i_eop;    		
   end
        
    always_comb begin	 
	o_crc32 = gen_crc_wrd(crc32_poly_reg);	
    end // always_comb
    
    always_comb begin
	if (i_eop) begin
	    case (i_bytes_vld)
		2'd1: crc32_data = {24'd0, i_data[3]} ;
		2'd2: crc32_data = {16'd0, i_data[2], i_data[3]} ;
		2'd3: crc32_data = {8'd0, i_data[1], i_data[2], i_data[3]} ;
		default: crc32_data = {i_data[0], i_data[1], i_data[2], i_data[3]} ;
	    endcase // case (i_rx_bytes_vld)
	end
	
	else 
	    crc32_data =  {i_data[0], i_data[1],  i_data[2],  i_data[3]}  ;
		    		
	
	cal_crc32_poly_reg  = i_sop ? '1 : crc32_poly_reg;
    end // always_comb
    
    always_ff @(posedge clk) begin
	if (i_vld )
	    crc32_poly_reg <= cal_crc32_poly[31];

	if (i_eop) begin
	    case (i_bytes_vld)
		2'd1:    crc32_poly_reg <= cal_crc32_poly[7];
		2'd2:    crc32_poly_reg <= cal_crc32_poly[15];
		2'd3:    crc32_poly_reg <= cal_crc32_poly[23];
		default: crc32_poly_reg <= cal_crc32_poly[31];
	    endcase
	end
		
	if (rst)
	    crc32_poly_reg <= '1;
    end
    
    always_comb begin
	for (int p = 0; p < 32; p++) begin
	    if (p == '0)
		cal_crc32_poly[p] = next_crc32_d1(crc32_data[p], cal_crc32_poly_reg);
	    else
		cal_crc32_poly[p] = next_crc32_d1(crc32_data[p], cal_crc32_poly[p-1]);
	end

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
    
    function [31:0] gen_crc_wrd;
	input [31:0] dIn;

	begin
            gen_crc_wrd[7:0]   = ~{dIn[24],dIn[25],dIn[26],dIn[27], 
				   dIn[28],dIn[29],dIn[30],dIn[31]};
	    
            gen_crc_wrd[15:8]  = ~{dIn[16],dIn[17],dIn[18],dIn[19], 
				   dIn[20],dIn[21],dIn[22],dIn[23]};
	    
            gen_crc_wrd[23:16] = ~{dIn[8],dIn[9],dIn[10],dIn[11], 
				   dIn[12],dIn[13],dIn[14],dIn[15]};
	    
            gen_crc_wrd[31:24] = ~{dIn[0],dIn[1],dIn[2],dIn[3], 
				   dIn[4],dIn[5],dIn[6],dIn[7]};
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
    endfunction // next_crc32_d1
    
   
    



endmodule

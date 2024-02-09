// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT



//-----------------------------------------------------------------------------
// Copyright (C) 2009 OutputLogic.com
// This source file may be used and distributed without restriction
// provided that this copyright statement is not removed from the file
// and that any derivative work contains the original copyright notice
// and the associated disclaimer.
//
// THIS SOURCE FILE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS
// OR IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
// WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
//-----------------------------------------------------------------------------
// scrambler module for data[63:0],   lfsr[57:0]=1+x^39+x^58;
//-----------------------------------------------------------------------------

module scramble_c49
    (
     input  var logic [63:0] data_in,
     input  var logic scram_en,
     
     output var logic [63:0] data_out,
     output var logic data_out_vld,
		 
     input  var logic rst,
     input  var logic clk
     );

    reg [57:0] lfsr_q,lfsr_c;
    reg [63:0] data_c;
    
    always @(*) begin
	lfsr_c[0] = lfsr_q[13] ^ lfsr_q[32] ^ lfsr_q[51] ^ lfsr_q[52];
	lfsr_c[1] = lfsr_q[14] ^ lfsr_q[33] ^ lfsr_q[52] ^ lfsr_q[53];
	lfsr_c[2] = lfsr_q[15] ^ lfsr_q[34] ^ lfsr_q[53] ^ lfsr_q[54];
	lfsr_c[3] = lfsr_q[16] ^ lfsr_q[35] ^ lfsr_q[54] ^ lfsr_q[55];
	lfsr_c[4] = lfsr_q[17] ^ lfsr_q[36] ^ lfsr_q[55] ^ lfsr_q[56];
	lfsr_c[5] = lfsr_q[18] ^ lfsr_q[37] ^ lfsr_q[56] ^ lfsr_q[57];
	lfsr_c[6] = lfsr_q[0] ^ lfsr_q[19] ^ lfsr_q[38] ^ lfsr_q[57];
	lfsr_c[7] = lfsr_q[1] ^ lfsr_q[20] ^ lfsr_q[39];
	lfsr_c[8] = lfsr_q[2] ^ lfsr_q[21] ^ lfsr_q[40];
	lfsr_c[9] = lfsr_q[3] ^ lfsr_q[22] ^ lfsr_q[41];
	lfsr_c[10] = lfsr_q[4] ^ lfsr_q[23] ^ lfsr_q[42];
	lfsr_c[11] = lfsr_q[5] ^ lfsr_q[24] ^ lfsr_q[43];
	lfsr_c[12] = lfsr_q[6] ^ lfsr_q[25] ^ lfsr_q[44];
	lfsr_c[13] = lfsr_q[7] ^ lfsr_q[26] ^ lfsr_q[45];
	lfsr_c[14] = lfsr_q[8] ^ lfsr_q[27] ^ lfsr_q[46];
	lfsr_c[15] = lfsr_q[9] ^ lfsr_q[28] ^ lfsr_q[47];
	lfsr_c[16] = lfsr_q[10] ^ lfsr_q[29] ^ lfsr_q[48];
	lfsr_c[17] = lfsr_q[11] ^ lfsr_q[30] ^ lfsr_q[49];
	lfsr_c[18] = lfsr_q[12] ^ lfsr_q[31] ^ lfsr_q[50];
	lfsr_c[19] = lfsr_q[13] ^ lfsr_q[32] ^ lfsr_q[51];
	lfsr_c[20] = lfsr_q[14] ^ lfsr_q[33] ^ lfsr_q[52];
	lfsr_c[21] = lfsr_q[15] ^ lfsr_q[34] ^ lfsr_q[53];
	lfsr_c[22] = lfsr_q[16] ^ lfsr_q[35] ^ lfsr_q[54];
	lfsr_c[23] = lfsr_q[17] ^ lfsr_q[36] ^ lfsr_q[55];
	lfsr_c[24] = lfsr_q[18] ^ lfsr_q[37] ^ lfsr_q[56];
	lfsr_c[25] = lfsr_q[19] ^ lfsr_q[38] ^ lfsr_q[57];
	lfsr_c[26] = lfsr_q[20] ^ lfsr_q[39];
	lfsr_c[27] = lfsr_q[21] ^ lfsr_q[40];
	lfsr_c[28] = lfsr_q[22] ^ lfsr_q[41];
	lfsr_c[29] = lfsr_q[23] ^ lfsr_q[42];
	lfsr_c[30] = lfsr_q[24] ^ lfsr_q[43];
	lfsr_c[31] = lfsr_q[25] ^ lfsr_q[44];
	lfsr_c[32] = lfsr_q[26] ^ lfsr_q[45];
	lfsr_c[33] = lfsr_q[27] ^ lfsr_q[46];
	lfsr_c[34] = lfsr_q[28] ^ lfsr_q[47];
	lfsr_c[35] = lfsr_q[29] ^ lfsr_q[48];
	lfsr_c[36] = lfsr_q[30] ^ lfsr_q[49];
	lfsr_c[37] = lfsr_q[31] ^ lfsr_q[50];
	lfsr_c[38] = lfsr_q[32] ^ lfsr_q[51];
	lfsr_c[39] = lfsr_q[13] ^ lfsr_q[32] ^ lfsr_q[33] ^ lfsr_q[51];
	lfsr_c[40] = lfsr_q[14] ^ lfsr_q[33] ^ lfsr_q[34] ^ lfsr_q[52];
	lfsr_c[41] = lfsr_q[15] ^ lfsr_q[34] ^ lfsr_q[35] ^ lfsr_q[53];
	lfsr_c[42] = lfsr_q[16] ^ lfsr_q[35] ^ lfsr_q[36] ^ lfsr_q[54];
	lfsr_c[43] = lfsr_q[17] ^ lfsr_q[36] ^ lfsr_q[37] ^ lfsr_q[55];
	lfsr_c[44] = lfsr_q[18] ^ lfsr_q[37] ^ lfsr_q[38] ^ lfsr_q[56];
	lfsr_c[45] = lfsr_q[0] ^ lfsr_q[19] ^ lfsr_q[38] ^ lfsr_q[39] ^ lfsr_q[57];
	lfsr_c[46] = lfsr_q[1] ^ lfsr_q[20] ^ lfsr_q[39] ^ lfsr_q[40];
	lfsr_c[47] = lfsr_q[2] ^ lfsr_q[21] ^ lfsr_q[40] ^ lfsr_q[41];
	lfsr_c[48] = lfsr_q[3] ^ lfsr_q[22] ^ lfsr_q[41] ^ lfsr_q[42];
	lfsr_c[49] = lfsr_q[4] ^ lfsr_q[23] ^ lfsr_q[42] ^ lfsr_q[43];
	lfsr_c[50] = lfsr_q[5] ^ lfsr_q[24] ^ lfsr_q[43] ^ lfsr_q[44];
	lfsr_c[51] = lfsr_q[6] ^ lfsr_q[25] ^ lfsr_q[44] ^ lfsr_q[45];
	lfsr_c[52] = lfsr_q[7] ^ lfsr_q[26] ^ lfsr_q[45] ^ lfsr_q[46];
	lfsr_c[53] = lfsr_q[8] ^ lfsr_q[27] ^ lfsr_q[46] ^ lfsr_q[47];
	lfsr_c[54] = lfsr_q[9] ^ lfsr_q[28] ^ lfsr_q[47] ^ lfsr_q[48];
	lfsr_c[55] = lfsr_q[10] ^ lfsr_q[29] ^ lfsr_q[48] ^ lfsr_q[49];
	lfsr_c[56] = lfsr_q[11] ^ lfsr_q[30] ^ lfsr_q[49] ^ lfsr_q[50];
	lfsr_c[57] = lfsr_q[12] ^ lfsr_q[31] ^ lfsr_q[50] ^ lfsr_q[51];
	
	data_c[0] = data_in[0] ^ lfsr_q[57];
	data_c[1] = data_in[1] ^ lfsr_q[56];
	data_c[2] = data_in[2] ^ lfsr_q[55];
	data_c[3] = data_in[3] ^ lfsr_q[54];
	data_c[4] = data_in[4] ^ lfsr_q[53];
	data_c[5] = data_in[5] ^ lfsr_q[52];
	data_c[6] = data_in[6] ^ lfsr_q[51];
	data_c[7] = data_in[7] ^ lfsr_q[50];
	data_c[8] = data_in[8] ^ lfsr_q[49];
	data_c[9] = data_in[9] ^ lfsr_q[48];
	data_c[10] = data_in[10] ^ lfsr_q[47];
	data_c[11] = data_in[11] ^ lfsr_q[46];
	data_c[12] = data_in[12] ^ lfsr_q[45];
	data_c[13] = data_in[13] ^ lfsr_q[44];
	data_c[14] = data_in[14] ^ lfsr_q[43];
	data_c[15] = data_in[15] ^ lfsr_q[42];
	data_c[16] = data_in[16] ^ lfsr_q[41];
	data_c[17] = data_in[17] ^ lfsr_q[40];
	data_c[18] = data_in[18] ^ lfsr_q[39];
	data_c[19] = data_in[19] ^ lfsr_q[38] ^ lfsr_q[57];
	data_c[20] = data_in[20] ^ lfsr_q[37] ^ lfsr_q[56];
	data_c[21] = data_in[21] ^ lfsr_q[36] ^ lfsr_q[55];
	data_c[22] = data_in[22] ^ lfsr_q[35] ^ lfsr_q[54];
	data_c[23] = data_in[23] ^ lfsr_q[34] ^ lfsr_q[53];
	data_c[24] = data_in[24] ^ lfsr_q[33] ^ lfsr_q[52];
	data_c[25] = data_in[25] ^ lfsr_q[32] ^ lfsr_q[51];
	data_c[26] = data_in[26] ^ lfsr_q[31] ^ lfsr_q[50];
	data_c[27] = data_in[27] ^ lfsr_q[30] ^ lfsr_q[49];
	data_c[28] = data_in[28] ^ lfsr_q[29] ^ lfsr_q[48];
	data_c[29] = data_in[29] ^ lfsr_q[28] ^ lfsr_q[47];
	data_c[30] = data_in[30] ^ lfsr_q[27] ^ lfsr_q[46];
	data_c[31] = data_in[31] ^ lfsr_q[26] ^ lfsr_q[45];
	data_c[32] = data_in[32] ^ lfsr_q[25] ^ lfsr_q[44];
	data_c[33] = data_in[33] ^ lfsr_q[24] ^ lfsr_q[43];
	data_c[34] = data_in[34] ^ lfsr_q[23] ^ lfsr_q[42];
	data_c[35] = data_in[35] ^ lfsr_q[22] ^ lfsr_q[41];
	data_c[36] = data_in[36] ^ lfsr_q[21] ^ lfsr_q[40];
	data_c[37] = data_in[37] ^ lfsr_q[20] ^ lfsr_q[39];
	data_c[38] = data_in[38] ^ lfsr_q[19] ^ lfsr_q[38] ^ lfsr_q[57];
	data_c[39] = data_in[39] ^ lfsr_q[18] ^ lfsr_q[37] ^ lfsr_q[56];
	data_c[40] = data_in[40] ^ lfsr_q[17] ^ lfsr_q[36] ^ lfsr_q[55];
	data_c[41] = data_in[41] ^ lfsr_q[16] ^ lfsr_q[35] ^ lfsr_q[54];
	data_c[42] = data_in[42] ^ lfsr_q[15] ^ lfsr_q[34] ^ lfsr_q[53];
	data_c[43] = data_in[43] ^ lfsr_q[14] ^ lfsr_q[33] ^ lfsr_q[52];
	data_c[44] = data_in[44] ^ lfsr_q[13] ^ lfsr_q[32] ^ lfsr_q[51];
	data_c[45] = data_in[45] ^ lfsr_q[12] ^ lfsr_q[31] ^ lfsr_q[50];
	data_c[46] = data_in[46] ^ lfsr_q[11] ^ lfsr_q[30] ^ lfsr_q[49];
	data_c[47] = data_in[47] ^ lfsr_q[10] ^ lfsr_q[29] ^ lfsr_q[48];
	data_c[48] = data_in[48] ^ lfsr_q[9] ^ lfsr_q[28] ^ lfsr_q[47];
	data_c[49] = data_in[49] ^ lfsr_q[8] ^ lfsr_q[27] ^ lfsr_q[46];
	data_c[50] = data_in[50] ^ lfsr_q[7] ^ lfsr_q[26] ^ lfsr_q[45];
	data_c[51] = data_in[51] ^ lfsr_q[6] ^ lfsr_q[25] ^ lfsr_q[44];
	data_c[52] = data_in[52] ^ lfsr_q[5] ^ lfsr_q[24] ^ lfsr_q[43];
	data_c[53] = data_in[53] ^ lfsr_q[4] ^ lfsr_q[23] ^ lfsr_q[42];
	data_c[54] = data_in[54] ^ lfsr_q[3] ^ lfsr_q[22] ^ lfsr_q[41];
	data_c[55] = data_in[55] ^ lfsr_q[2] ^ lfsr_q[21] ^ lfsr_q[40];
	data_c[56] = data_in[56] ^ lfsr_q[1] ^ lfsr_q[20] ^ lfsr_q[39];
	data_c[57] = data_in[57] ^ lfsr_q[0] ^ lfsr_q[19] ^ lfsr_q[38] ^ lfsr_q[57];
	data_c[58] = data_in[58] ^ lfsr_q[18] ^ lfsr_q[37] ^ lfsr_q[56] ^ lfsr_q[57];
	data_c[59] = data_in[59] ^ lfsr_q[17] ^ lfsr_q[36] ^ lfsr_q[55] ^ lfsr_q[56];
	data_c[60] = data_in[60] ^ lfsr_q[16] ^ lfsr_q[35] ^ lfsr_q[54] ^ lfsr_q[55];
	data_c[61] = data_in[61] ^ lfsr_q[15] ^ lfsr_q[34] ^ lfsr_q[53] ^ lfsr_q[54];
	data_c[62] = data_in[62] ^ lfsr_q[14] ^ lfsr_q[33] ^ lfsr_q[52] ^ lfsr_q[53];
	data_c[63] = data_in[63] ^ lfsr_q[13] ^ lfsr_q[32] ^ lfsr_q[51] ^ lfsr_q[52];
    end // always

    always_ff @(posedge clk) begin
	if(rst) begin
	    //lfsr_q <= {58{1'b1}};
	    lfsr_q   <= {1'b1, {57{1'b0}}};
	    data_out <= {64{1'b0}};
	end
	else begin
	    lfsr_q <=  scram_en ? lfsr_c : lfsr_q;
	    data_out <= scram_en ? data_c : data_out;
	end

       
    end // always

    always_ff @(posedge clk) begin
	data_out_vld <= scram_en;
    end
endmodule // scrambler

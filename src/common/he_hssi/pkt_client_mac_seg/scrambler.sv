// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


module scrambler 
   (
    input logic clk,
    input logic rst,    
    input logic scram_en,
    input logic [63:0] data_in,
    
    output logic [63:0] data_out,
    output logic data_out_vld
    );

    
    reg [57:0] 	  Poly;
    wire [63:0]   next;
    assign next[63] = Poly[57] ^ Poly[38];
    assign next[62] = Poly[56] ^ Poly[37];
    assign next[61] = Poly[55] ^ Poly[36];
    assign next[60] = Poly[54] ^ Poly[35];
    assign next[59] = Poly[53] ^ Poly[34];
    assign next[58] = Poly[52] ^ Poly[33];
    assign next[57] = Poly[51] ^ Poly[32];
    assign next[56] = Poly[50] ^ Poly[31];
    assign next[55] = Poly[49] ^ Poly[30];
    assign next[54] = Poly[48] ^ Poly[29];
    assign next[53] = Poly[47] ^ Poly[28];
    assign next[52] = Poly[46] ^ Poly[27];
    assign next[51] = Poly[45] ^ Poly[26];
    assign next[50] = Poly[44] ^ Poly[25];
    assign next[49] = Poly[43] ^ Poly[24];
    assign next[48] = Poly[42] ^ Poly[23];
    assign next[47] = Poly[41] ^ Poly[22];
    assign next[46] = Poly[40] ^ Poly[21];
    assign next[45] = Poly[39] ^ Poly[20];
    assign next[44] = Poly[38] ^ Poly[19];
    assign next[43] = Poly[37] ^ Poly[18];
    assign next[42] = Poly[36] ^ Poly[17];
    assign next[41] = Poly[35] ^ Poly[16];
    assign next[40] = Poly[34] ^ Poly[15];
    assign next[39] = Poly[33] ^ Poly[14];
    assign next[38] = Poly[32] ^ Poly[13];
    assign next[37] = Poly[31] ^ Poly[12];
    assign next[36] = Poly[30] ^ Poly[11];
    assign next[35] = Poly[29] ^ Poly[10];
    assign next[34] = Poly[28] ^ Poly[9];
    assign next[33] = Poly[27] ^ Poly[8];
    assign next[32] = Poly[26] ^ Poly[7];
    assign next[31] = Poly[25] ^ Poly[6];
    assign next[30] = Poly[24] ^ Poly[5];
    assign next[29] = Poly[23] ^ Poly[4];
    assign next[28] = Poly[22] ^ Poly[3];
    assign next[27] = Poly[21] ^ Poly[2];
    assign next[26] = Poly[20] ^ Poly[1];
    assign next[25] = Poly[19] ^ Poly[0];
    assign next[24] = Poly[57] ^ Poly[38] ^ Poly[18];
    assign next[23] = Poly[56] ^ Poly[37] ^ Poly[17];
    assign next[22] = Poly[55] ^ Poly[36] ^ Poly[16];
    assign next[21] = Poly[54] ^ Poly[35] ^ Poly[15];
    assign next[20] = Poly[53] ^ Poly[34] ^ Poly[14];
    assign next[19] = Poly[52] ^ Poly[33] ^ Poly[13];
    assign next[18] = Poly[51] ^ Poly[32] ^ Poly[12];
    assign next[17] = Poly[50] ^ Poly[31] ^ Poly[11];
    assign next[16] = Poly[49] ^ Poly[30] ^ Poly[10];
    assign next[15] = Poly[48] ^ Poly[29] ^ Poly[9];
    assign next[14] = Poly[47] ^ Poly[28] ^ Poly[8];
    assign next[13] = Poly[46] ^ Poly[27] ^ Poly[7];
    assign next[12] = Poly[45] ^ Poly[26] ^ Poly[6];
    assign next[11] = Poly[44] ^ Poly[25] ^ Poly[5];
    assign next[10] = Poly[43] ^ Poly[24] ^ Poly[4];
    assign next[9] = Poly[42] ^ Poly[23] ^ Poly[3];
    assign next[8] = Poly[41] ^ Poly[22] ^ Poly[2];
    assign next[7] = Poly[40] ^ Poly[21] ^ Poly[1];
    assign next[6] = Poly[39] ^ Poly[20] ^ Poly[0];
    assign next[5] = Poly[57] ^ Poly[19];
    assign next[4] = Poly[56] ^ Poly[18];
    assign next[3] = Poly[55] ^ Poly[17];
    assign next[2] = Poly[54] ^ Poly[16];
    assign next[1] = Poly[53] ^ Poly[15];
    assign next[0] = Poly[52] ^ Poly[14];

    logic [57:0]  nxt_poly;
    logic [63:0]  scr_data_comb;
    
    
    
    always @(posedge clk) begin
	if(rst) begin
	    Poly <= '1;//rst each lane differently
	    data_out <= 64'b0;
	end 
	else if(scram_en) begin
	    Poly <= next[57:0];
	    	    
	    data_out <= data_in[63:0] ^ {Poly[57:0], next[63:58]};
	end // if (scram_en)

	data_out_vld <= scram_en;	
    end

   
endmodule

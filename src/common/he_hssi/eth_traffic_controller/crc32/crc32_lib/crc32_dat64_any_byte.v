// (C) 2001-2018 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


// CRC32 of data with any size from 1 to 8 bytes (e.g. residues)
// the input data ports typically come from the same 64 bit 
// register, but this is not a requirement.

module crc32_dat64_any_byte (
	dat_size,
	crc_in,
	crc_out,
	dat8,dat16,dat24,dat32,
	dat40,dat48,dat56,dat64
);

input [2:0] dat_size;
input [31:0] crc_in;

output [31:0] crc_out;
wire [31:0] crc_out;

input [7:0] dat8;
input [15:0] dat16;
input [23:0] dat24;
input [31:0] dat32;
input [39:0] dat40;
input [47:0] dat48;
input [55:0] dat56;
input [63:0] dat64;

parameter METHOD = 1; // depth optimal factored
parameter REVERSE_DATA = 0; // Use LSB first

// internal data signals
wire [7:0] dat8_w;
wire [15:0] dat16_w;
wire [23:0] dat24_w;
wire [31:0] dat32_w;
wire [39:0] dat40_w;
wire [47:0] dat48_w;
wire [55:0] dat56_w;
wire [63:0] dat64_w;

//////////////////////////////////////////////////////
// Optional reversal of the data bits to do LSB
//   of data 1st.  No area cost
//////////////////////////////////////////////////////
genvar i;
generate
if (REVERSE_DATA)
begin
		for (i=0; i<64; i=i+1)
		begin : rev_64
			assign dat64_w[i] = dat64[63-i];		
		end
		for (i=0; i<56; i=i+1)
		begin : rev_56
			assign dat56_w[i] = dat56[55-i];		
		end
		for (i=0; i<48; i=i+1)
		begin : rev_48
			assign dat48_w[i] = dat48[47-i];		
		end
		for (i=0; i<40; i=i+1)
		begin : rev_40
			assign dat40_w[i] = dat40[39-i];		
		end
		for (i=0; i<32; i=i+1)
		begin : rev_32
			assign dat32_w[i] = dat32[31-i];		
		end
		for (i=0; i<24; i=i+1)
		begin : rev_24
			assign dat24_w[i] = dat24[23-i];		
		end
		for (i=0; i<16; i=i+1)
		begin : rev_16
			assign dat16_w[i] = dat16[15-i];		
		end
		for (i=0; i<8; i=i+1)
		begin : rev_8
			assign dat8_w[i] = dat8[7-i];		
		end
end
else
begin
	// no reversal - pass along
	assign dat64_w = dat64;
	assign dat56_w = dat56;
	assign dat48_w = dat48;
	assign dat40_w = dat40;
	assign dat32_w = dat32;
	assign dat24_w = dat24;
	assign dat16_w = dat16;
	assign dat8_w = dat8;
end
endgenerate

//////////////////////////////////////////////////////
// define a parallel array of CRC units for one to 
//	eight bytes of data.
//////////////////////////////////////////////////////
	wire [31:0] co_a,co_b,co_c,co_d,co_e,co_f,co_g,co_h;
	crc32_dat8  a (.crc_in (crc_in),.crc_out (co_a),.dat_in(dat8_w));
	crc32_dat16 b (.crc_in (crc_in),.crc_out (co_b),.dat_in(dat16_w));
	crc32_dat24 c (.crc_in (crc_in),.crc_out (co_c),.dat_in(dat24_w));
	crc32_dat32 d (.crc_in (crc_in),.crc_out (co_d),.dat_in(dat32_w));
	crc32_dat40 e (.crc_in (crc_in),.crc_out (co_e),.dat_in(dat40_w));
	crc32_dat48 f (.crc_in (crc_in),.crc_out (co_f),.dat_in(dat48_w));
	crc32_dat56 g (.crc_in (crc_in),.crc_out (co_g),.dat_in(dat56_w));
	crc32_dat64 h (.crc_in (crc_in),.crc_out (co_h),.dat_in(dat64_w));

	defparam a .METHOD = METHOD;
	defparam b .METHOD = METHOD;
	defparam c .METHOD = METHOD;
	defparam d .METHOD = METHOD;
	defparam e .METHOD = METHOD;
	defparam f .METHOD = METHOD;
	defparam g .METHOD = METHOD;
	defparam h .METHOD = METHOD;

//////////////////////////////////////////////////////
// select the CRC output according to data width
//////////////////////////////////////////////////////
generate
	for (i=0; i<32;i=i+1)
	begin : parmux
		wire [7:0] tmp_m;
		assign tmp_m[0] = co_a[i];
		assign tmp_m[1] = co_b[i];
		assign tmp_m[2] = co_c[i];
		assign tmp_m[3] = co_d[i];
		assign tmp_m[4] = co_e[i];
		assign tmp_m[5] = co_f[i];
		assign tmp_m[6] = co_g[i];
		assign tmp_m[7] = co_h[i];
		assign crc_out[i] = tmp_m[dat_size];
	end	
endgenerate

endmodule
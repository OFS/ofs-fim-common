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


// typical Ethernet FCS style CRC-32
//   variable data width, 1..4 bytes
//
// Revision:
// 04-03-2006 - Original Code for Intel Cookbook
// 05-09-2012 - Add variable data path size for CRC32 - Data Width = 8,16,32,64
//				Remove the dependency on Stratix II WYSIWYG Style and replace with Generic fucntion
// 13-09-2012 - remove data endian conversion to crc_ethernet input, endian conversion perfrom outside of this module
//			  - crc_ethernet data input and calculated CRC32 output is small endian
//			  - Improve the crc_ethernet.v to capable to perform init and crc calculation (EOP only) at the same cycle

module crc_ethernet (
	aclr,
	clk,
	ena,
	init,
	dat_size,
	crc_out,
	dat
);

parameter	DATA_WIDTH = 32;
parameter	DATA_SIZE_WIDTH = 2;
parameter	CRC_WIDTH = 32;
parameter	REVERSE_DATA = 1;
parameter	CRC_PIPELINE_MODE = 0;							//jier - Default set to 0, set to 1 for pipeline mode (init and data input at the same cycle)

input 	[DATA_SIZE_WIDTH-1:0] 		dat_size; 			// 2'b00=1 byte .. 2'b11=4 bytes .. 3'b111=8 bytes
input 	[DATA_WIDTH-1:0] 			dat;
input 								clk;
input 								ena;				// deactivate me for power savings
input 								aclr;				// async rst to 0
input 								init;				// sync load 111...
output 	[CRC_WIDTH-1:0] 			crc_out;  			// reversed and inverted
                            		
reg 	[CRC_WIDTH-1:0] 			crc_out;  

wire 	[CRC_WIDTH-1:0] 			crc_rin_wire;
wire 	[CRC_WIDTH-1:0] 			crc_rout_wire;

// 32 bit register bank, initializes to 111.. on the init signal.
crc_register #(CRC_WIDTH, 0, 32'hffffffff) rg (
	.d(crc_rin_wire),
	.q(crc_rout_wire),
	.clk(clk),
	.init(init),
	.sclr(1'b0),
	.ena(ena),
	.aclr(aclr));

// parallel array of CRC XORs
generate
	if (DATA_WIDTH == 8) begin
		crc32_dat32_any_byte #(1, REVERSE_DATA) cr (				//Jier need to varify this or reuse the crc32_dat32_any_byte for data width = 8
			.dat_size	(2'b00),
			.crc_in		(crc_rout_wire),
			.crc_out	(crc_rin_wire),
			.dat8 		(dat[7:0]),
			.dat16 		(16'h0000),				//unused
			.dat24 		(24'h000000),			//unused
			.dat32 		(32'h00000000)			//unused
		);
	end
	if (DATA_WIDTH == 16) begin
		crc32_dat32_any_byte #(1, REVERSE_DATA) cr (				//Jier need to varify this or reuse the crc32_dat32_any_byte for data width = 16 
			.dat_size	({1'b0, dat_size[0]}),
			.crc_in		(crc_rout_wire),
			.crc_out	(crc_rin_wire),
			.dat8 		(dat[7:0]),
			.dat16 		(dat[15:0]),	
			.dat24 		(24'h000000),			//unused
			.dat32 		(32'h00000000)			//unused
		);
	end
	else if (DATA_WIDTH == 32) begin
		crc32_dat32_any_byte #(1, REVERSE_DATA) cr (
			.dat_size	(dat_size[1:0]),
			.crc_in		(crc_rout_wire),
			.crc_out	(crc_rin_wire),
			.dat8 		(dat[7:0]),
			.dat16 		(dat[15:0]),
			.dat24 		(dat[23:0]),
			.dat32 		(dat[31:0])
		);
		
	end	
	else if (DATA_WIDTH == 64) begin
		crc32_dat64_any_byte #(1, REVERSE_DATA) cr (
			.dat_size	(dat_size[2:0]),
			.crc_in		(crc_rout_wire),
			.crc_out	(crc_rin_wire),
			.dat8		(dat[7:0]),
			.dat16		(dat[15:0]),
			.dat24		(dat[23:0]),
			.dat32		(dat[31:0]),
			.dat40		(dat[39:0]),
			.dat48		(dat[47:0]),
			.dat56		(dat[55:0]),
			.dat64		(dat[63:0])
		);
	end
endgenerate


generate
	if (CRC_PIPELINE_MODE == 1) begin 

		//jier mod
		// reverse and invert the CRC output lines (when use crc32.v, use this mode)
		// enhacent the CRC that able to perfrom init and crc calculation on EOP condition, no extra init cycle required
		reg 	[CRC_WIDTH-1:0] 			crc_out_inv;
		
		integer i;
		always @(crc_rin_wire) begin
		  for (i=0;i<CRC_WIDTH;i=i+1) 
		  begin
		    crc_out_inv[i] = !crc_rin_wire[(CRC_WIDTH-1)-i];
		  end
		end
		
		always @(posedge clk or posedge aclr)
			if (aclr)
				crc_out <= {CRC_WIDTH{1'b0}};
			else 				
				crc_out <= crc_out_inv; 	
	
		
	end
	else begin //(CRC_PIPELINE_MODE == 0)         
		
		// reverse and invert the CRC output lines (Default use this mode, same as CRC32 in Intel cookbook)
		integer i;
		always @(crc_rout_wire) begin
		  for (i=0;i<CRC_WIDTH;i=i+1) 
		  begin
		    crc_out[i] = !crc_rout_wire[(CRC_WIDTH-1)-i];
		  end
		end		
	end
endgenerate 
		
endmodule

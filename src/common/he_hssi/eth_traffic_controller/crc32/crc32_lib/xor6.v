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


// 6 input XOR Function
//
// Revision:
// 04-03-2006 - Original Code for Intel Cookbook
// 05-09-2012 - Remove the dependency of the WYSIWYG Startix II lcell
//				Replace with the general equation function

module xor6 (out,a,b,c,d,e,f);
input a,b,c,d,e,f;
output out;
wire out;

// Equivalent function : out = a ^ b ^ c ^ d ^ e ^ f;
assign out = a ^ b ^ c ^ d ^ e ^ f;


//stratixii_lcell_comb s2lc (
//  .dataa (a),.datab (b),.datac (c),.datad (d),.datae (e),.dataf (f),.datag(1'b1),
//  .cin(1'b1),.sharein(1'b0),.sumout(),.cout(),.shareout(),
//  .combout(out));
//
//defparam s2lc .lut_mask = 64'h6996966996696996;
//defparam s2lc .shared_arith = "off";
//defparam s2lc .extended_lut = "off";

endmodule

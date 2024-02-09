// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


//-----------------------------------------------------------------------------
// (C) 2015 Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License Subscription 
// Agreement, Altera MegaCore Function License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the applicable 
// agreement for further details.
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Revision history:-
//
// 18/May/2015  | Creation.
//              | 
//              | Single clock simple-dual-port mode RAM. This is a 
//              | parameterised version of a Megawizard generated wrapper.
//-----------------------------------------------------------------------------

module nbq_scsdpram # (
   parameter INIT_FILE       = "packet_client.hex",
   parameter SKIP_RDEN   	  = 0,
   parameter DEVICE_FAMILY   = "Arria 10",
   parameter LOG2_DEPTH      = 8, // Number of locations = 2^LOG2_DEPTH.
   parameter WIDTH           = 32, // Width in bits of each location.
   parameter RAM_TYPE        = (LOG2_DEPTH>5 ? "AUTO" : "MLAB"), // AUTO
   parameter OUTREG          = "ON", // "ON" = extra output stage; "OFF" = no extra output stage.
   parameter UNINITIALIZED   = "FALSE") // "FALSE" = simulation model is initialised; "TRUE" = model is uninitialised.
(
    clock,
    data,
    rdaddress,
    rden,
    wraddress,
    wren,
    q);

    input var logic  clock;
    input var logic  [WIDTH - 1:0]  data;
    input var logic  [LOG2_DEPTH - 1:0]  rdaddress;
    input var logic  rden;
    input var logic  [LOG2_DEPTH - 1:0]  wraddress;
    input var logic  wren;
    output    logic  [WIDTH - 1:0]  q;

// Check and correct RAM type based on best util of resources
localparam RAM_BLOCK_TYPE = (LOG2_DEPTH<=5 ? "MLAB" : RAM_TYPE);

generate if (RAM_BLOCK_TYPE == "MLAB") begin: MLAB
if (SKIP_RDEN == 1) begin
    altsyncram # (
            .address_aclr_b ("NONE"),
            .address_reg_b ("CLOCK0"),
            .clock_enable_input_a ("BYPASS"),
            .clock_enable_input_b ("BYPASS"),
            .clock_enable_output_b ("BYPASS"),
            .intended_device_family (DEVICE_FAMILY),
            .lpm_type ("altsyncram"),
            .numwords_a (2**LOG2_DEPTH),
            .numwords_b (2**LOG2_DEPTH),
            .operation_mode ("DUAL_PORT"),
            .outdata_aclr_b ("NONE"),
            .outdata_reg_b ((OUTREG == "ON") ? "CLOCK0" : "UNREGISTERED"),
            .power_up_uninitialized (UNINITIALIZED),
	    //.power_up_uninitialized ("TRUE"),
            .ram_block_type (RAM_BLOCK_TYPE),            
            .rdcontrol_reg_b ("CLOCK0"),
            .read_during_write_mode_mixed_ports ("DONT_CARE"),
            .widthad_a (LOG2_DEPTH),
            .widthad_b (LOG2_DEPTH),
            .width_a (WIDTH),
            .width_b (WIDTH),
            .width_byteena_a (1),
	    .init_file (INIT_FILE)
        )    OVS_MLAB (
                               .address_a (wraddress),
                               .clock0 (clock),
                               .data_a (data),
		              // .rden_b (rden),
                               .wren_a (wren),
                               .address_b (rdaddress),
                               .q_b (q),
                               .aclr0 (1'b0),
                               .aclr1 (1'b0),
                               .addressstall_a (1'b0),
                               .addressstall_b (1'b0),
                               .byteena_a (1'b1),
                               .byteena_b (1'b1),
                               .clock1 (1'b1),
                               .clocken0 (1'b1),
                               .clocken1 (1'b1),
                               .clocken2 (1'b1),
                               .clocken3 (1'b1),
                               .data_b ({WIDTH{1'b1}}),
                               .eccstatus (),
                               .q_a (),
                               .rden_a (1'b1),
                               .wren_b (1'b0)
                           );
       end
       else
	altsyncram # (
            .address_aclr_b ("NONE"),
            .address_reg_b ("CLOCK0"),
            .clock_enable_input_a ("BYPASS"),
            .clock_enable_input_b ("BYPASS"),
            .clock_enable_output_b ("BYPASS"),
            .intended_device_family (DEVICE_FAMILY),
            .lpm_type ("altsyncram"),
            .numwords_a (2**LOG2_DEPTH),
            .numwords_b (2**LOG2_DEPTH),
            .operation_mode ("DUAL_PORT"),
            .outdata_aclr_b ("NONE"),
            .outdata_reg_b ((OUTREG == "ON") ? "CLOCK0" : "UNREGISTERED"),
            .power_up_uninitialized (UNINITIALIZED),
	    //.power_up_uninitialized ("TRUE"),
            .ram_block_type (RAM_BLOCK_TYPE),            
            .rdcontrol_reg_b ("CLOCK0"),
            .read_during_write_mode_mixed_ports ("DONT_CARE"),
            .widthad_a (LOG2_DEPTH),
            .widthad_b (LOG2_DEPTH),
            .width_a (WIDTH),
            .width_b (WIDTH),
            .width_byteena_a (1),
	    .init_file (INIT_FILE)
        )    OVS_MLAB (
                               .address_a (wraddress),
                               .clock0 (clock),
                               .data_a (data),
		                         .rden_b (rden),
                               .wren_a (wren),
                               .address_b (rdaddress),
                               .q_b (q),
                               .aclr0 (1'b0),
                               .aclr1 (1'b0),
                               .addressstall_a (1'b0),
                               .addressstall_b (1'b0),
                               .byteena_a (1'b1),
                               .byteena_b (1'b1),
                               .clock1 (1'b1),
                               .clocken0 (1'b1),
                               .clocken1 (1'b1),
                               .clocken2 (1'b1),
                               .clocken3 (1'b1),
                               .data_b ({WIDTH{1'b1}}),
                               .eccstatus (),
                               .q_a (),
                               .rden_a (1'b1),
                               .wren_b (1'b0)
                           );		 
	end
 else   begin: M20K

    altsyncram # (
            .address_aclr_b ("NONE"),
            .address_reg_b ("CLOCK0"),
            .clock_enable_input_a ("BYPASS"),
            .clock_enable_input_b ("BYPASS"),
            .clock_enable_output_b ("BYPASS"),
            .intended_device_family (DEVICE_FAMILY),
            .lpm_type ("altsyncram"),
            .numwords_a (2**LOG2_DEPTH),
            .numwords_b (2**LOG2_DEPTH),
            .operation_mode ("DUAL_PORT"),
            .outdata_aclr_b ("NONE"),
            .outdata_reg_b ((OUTREG == "ON") ? "CLOCK0" : "UNREGISTERED"),
            .power_up_uninitialized (UNINITIALIZED),
            .ram_block_type (RAM_BLOCK_TYPE),            
            .rdcontrol_reg_b ("CLOCK0"),
            .read_during_write_mode_mixed_ports ("DONT_CARE"),
            .widthad_a (LOG2_DEPTH),
            .widthad_b (LOG2_DEPTH),
            .width_a (WIDTH),
            .width_b (WIDTH),
            .width_byteena_a (1),
	    .init_file (INIT_FILE)
        )    OVS_M20K (
                               .address_a (wraddress),
                               .clock0 (clock),
                               .data_a (data),
                               .rden_b (rden),
                               .wren_a (wren),
                               .address_b (rdaddress),
                               .q_b (q),
                               .aclr0 (1'b0),
                               .aclr1 (1'b0),
                               .addressstall_a (1'b0),
                               .addressstall_b (1'b0),
                               .byteena_a (1'b1),
                               .byteena_b (1'b1),
                               .clock1 (1'b1),
                               .clocken0 (1'b1),
                               .clocken1 (1'b1),
                               .clocken2 (1'b1),
                               .clocken3 (1'b1),
                               .data_b ({WIDTH{1'b1}}),
                               .eccstatus (),
                               .q_a (),
                               .rden_a (1'b1),
                               .wren_b (1'b0)
                           );
        end
 endgenerate                               
    






endmodule

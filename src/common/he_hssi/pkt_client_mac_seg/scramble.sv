// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT



`default_nettype none

module scramble
    
    import gdr_pkt_pkg::*;
    #(
        parameter PARAM_RATE_OP = 1
    )
    (
        input var logic clk,
        input var logic rst,

        //input var PCS_D_WRD_s enc_data,
        //input var logic [1:0] enc_sync,
        //input var logic enc_vld,

        //output var PCS_D_WRD_s scr_data,
        //output var logic [1:0] scr_sync,
        //output var logic scr_vld

        input var PCS_D_WRD_s [31:0] enc_data,
        input var PCS_SYNC_WRD_s [31:0] enc_sync,
        input var logic [31:0] enc_vld,

        output var PCS_D_WRD_s [31:0] scr_data,
        output var PCS_SYNC_WRD_s [31:0] scr_sync,
        output var logic [31:0] scr_vld
    );

    //logic [1:0] enc_syn_c1;
    PCS_SYNC_WRD_s [31:0] enc_syn_c1;
    // 50G -> 128bits
    //100G -> 256bits
    logic [15:0] scr128_vld;
    logic [7:0] scr256_vld;

    //alt_e2550_scram64_hn  scram64_hn  
    //   (// inputs
	//.clk (clk), 
	//.din (enc_data), 
	//.din_valid (enc_vld), 

	//// outputs
	//.dout (scr_data), 
	//.dout_valid (scr_vld)
	//);
    genvar i;
    generate
    //----------------------------------
    //Generate 128bits scrambler for 50G
    //if (PARAM_RATE_OP == 1) begin
    //    for (i = 0; i < 16; i = i+1) begin:SCRAMBLE_128
    //    alt_e2550_scram128_hn  scram128( //SIM.EMULATE
    //        .clk (clk),
    //        .din ( {enc_data[2*i+1],enc_data[2*i]} ),//Need confirm the word order
    //        .din_valid ( {enc_vld[2*i+1] & enc_vld[2*i]} ), //Need confirm AND vld 
    //
    //        // outputs
    //        .dout ( {scr_data[2*i+1],scr_data[2*i]} ),
    //        .dout_valid (scr128_vld[i])
    //    );

    //    assign {scr_vld[2*i+1],scr_vld[2*i]} = {scr128_vld[i],scr128_vld[i]};
    //    end //for (i = 0;i < 16;i = i+1)
    //    
    //end 
    //----------------------------------
    //Generate 256bits scrambler for 100G
    if (PARAM_RATE_OP == 1 || PARAM_RATE_OP == 2) begin
        for (i = 0; i < 8; i = i+1) begin:SCRAMBLE_256
        alt_e2550_scram256_hn  scram256( //SIM.EMULATE
                .clk (clk),
                .reset (rst),
                .din ( {enc_data[4*i+3],enc_data[4*i+2],enc_data[4*i+1],enc_data[4*i]} ),//Need confirm the word order
                .din_valid ( {enc_vld[4*i+3] & enc_vld[4*i+2] & enc_vld[4*i+1] & enc_vld[4*i]} ), //Need confirm AND vld 
        
                // outputs
                .dout ( {scr_data[4*i+3],scr_data[4*i+2],scr_data[4*i+1],scr_data[4*i]} ),
                .dout_valid (scr256_vld[i])
            );

            assign {scr_vld[4*i+3],scr_vld[4*i+2],scr_vld[4*i+1],scr_vld[4*i]} = {scr128_vld[i],scr128_vld[i],scr128_vld[i],scr128_vld[i]};
        end //for (i = 0;i < 8;i = i+1)

    end 
    //----------------------------------
    //Generate 64bits scrambler for single lane and 200G&400G(no OTN support)
    else begin
        for (i = 0; i < 32; i = i+1) begin:SCRAMBLE_64
            alt_e2550_scram64_hn  scram64_hn  (// inputs
            .clk (clk), 
            .din (enc_data[i]), 
            .din_valid (enc_vld[i]), 
                                               
            // outputs
            .dout (scr_data[i]), 
            .dout_valid (scr_vld[i])
            );
        end
    end
    endgenerate

    always_ff @(posedge clk) begin
	    enc_syn_c1 <= enc_sync ;
	    scr_sync <= enc_syn_c1 ;
    end

    //---------------------------------
    //Below codes are not used
    // synopsys translate_off
    logic descr_rst, descr_vld_hn;
    logic [7:0] cnt;
    PCS_D_WRD_s descr_data_hn;
    
    always_ff @(posedge clk) begin
	if (cnt != '1)
	    cnt <= cnt + 1'b1;
	
	if (rst) begin
	    cnt <= '0;
	    descr_rst <= 1'b1;
	end

	if (cnt == 8'd8)
	    descr_rst <= 1'b0;
    end // always_ff @ (posedge clk)
    
    alt_e2550_descram64_hn  dscram64_hn  
    
       (// inputs
	.clk (clk), 
	.din (descr_rst? '0 : scr_data), 
	.din_valid (descr_rst? '0 : scr_vld), 

	// outputs
	.dout (descr_data_hn), 
	.dout_valid (descr_vld_hn)
	);

    // synopsys translate_on

    
    
    
    
endmodule // scramble

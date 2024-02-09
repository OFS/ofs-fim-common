// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT



`default_nettype none

module descramble
    
    import gdr_pkt_pkg::*;
    #(
        parameter PARAM_RATE_OP = 1
    )
    (
        input var logic clk,
        input var logic rst,

        input var PCS_D_WRD_s [31:0] enc_data,
        input var PCS_SYNC_WRD_s [31:0] enc_sync,
        input var logic [31:0] enc_vld,

        output var PCS_D_WRD_s [31:0] descr_data,
        output var PCS_SYNC_WRD_s [31:0] descr_sync,
        output var logic [31:0] descr_vld
    );

    logic [15:0] descr128_vld;
    logic [7:0] descr256_vld;

    //alt_e2550_descram64_hn  dscram64_hn  
    //
    //   (// inputs
	//.clk (clk), 
	//.din (enc_data  ), 
	//.din_valid (enc_vld  ), 

	//// outputs
	//.dout (descr_data), 
	//.dout_valid (descr_vld)
	//);

    genvar i;
    generate
    //----------------------------------
    //Generate 128bits descrambler for 50G
    //if (PARAM_RATE_OP == 1) begin
    //    for (i = 0; i < 16; i = i+1) begin:DESCRAMBLE_128
    //    alt_e2550_descram128_hn  descram128( //SIM.EMULATE
    //        .clk (clk),
    //        .din ( {enc_data[2*i+1],enc_data[2*i]} ),//Need confirm the word order
    //        .din_valid ( {enc_vld[2*i+1] & enc_vld[2*i]} ), //Need confirm AND vld 
    //
    //        // outputs
    //        .dout ( {descr_data[2*i+1],descr_data[2*i]} ),
    //        .dout_valid (descr128_vld[i])
    //    );

    //    assign {descr_vld[2*i+1],descr_vld[2*i]} = {descr128_vld[i],descr128_vld[i]};
    //    end //for (i = 0;i < 16;i = i+1)
    //    
    //end 
    //----------------------------------
    //Generate 256bits scrambler for 100G
    if (PARAM_RATE_OP == 1 || PARAM_RATE_OP == 2) begin
        for (i = 0; i < 8; i = i+1) begin:DESCRAMBLE_256
            alt_e2550_descram256_hn  descram256( //SIM.EMULATE
                .clk (clk),
                .din ( {enc_data[4*i+3],enc_data[4*i+2],enc_data[4*i+1],enc_data[4*i]} ),//Need confirm the word order
                .din_valid ( {enc_vld[4*i+3] & enc_vld[4*i+2] & enc_vld[4*i+1] & enc_vld[4*i]} ), //Need confirm AND vld 
    
                // outputs
                .dout ( {descr_data[4*i+3],descr_data[4*i+2],descr_data[4*i+1],descr_data[4*i]} ),
                .dout_valid (descr128_vld[i])
        );
        assign {descr_vld[4*i+3],descr_vld[4*i+2],descr_vld[4*i+1],descr_vld[4*i]} = {descr128_vld[i],descr128_vld[i],descr128_vld[i],descr128_vld[i]};
        end //for (i = 0;i < 8;i = i+1)
    end 
    //----------------------------------
    //Generate 64bits scrambler for single lane and 200G&400G(no OTN support)
    else begin
        for (i = 0; i < 32; i = i+1) begin:DESCRAMBLE_64
            alt_e2550_descram64_hn  dscram64_hn  
            (// inputs
            .clk (clk),
            .din (enc_data[i]),
            .din_valid (enc_vld[i]),
            // outputs
            .dout (descr_data[i]),
            .dout_valid (descr_vld[i])
            );
        end
    end
    endgenerate

    //Why there is no additional register like scramble
    always_ff @(posedge clk) begin
	descr_sync <= enc_sync;	
    end

endmodule // scramble

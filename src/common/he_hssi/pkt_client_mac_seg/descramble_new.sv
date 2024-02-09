// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


module descramble_new #(
    parameter PARAM_RATE_OP = 0,
              PARAM_MODE_OP = 1,
              INTF_DATA_WD = 1 << (PARAM_RATE_OP + 6),
              INTF_SYNC_WD = 1 << (PARAM_RATE_OP + 1)
              ) (
    // input
    input var logic tclk,
    input var logic rst_tclk,

    input var logic [INTF_DATA_WD-1:0] rx_mii_d_scr1,
    input var logic [INTF_SYNC_WD-1:0] rx_mii_sync_scr,
    input var logic rx_mii_vld,
    input var logic rx_mii_am,
    //output
    output var logic [INTF_DATA_WD-1:0] rx_mii_d_scr,
    output var logic [INTF_SYNC_WD-1:0] rx_mii_sync_rev,
    output var logic rx_mii_vld_rev,
    output var logic rx_mii_am_rev
 ); 

    //========rx
    generate
    if (PARAM_MODE_OP == 2 || PARAM_RATE_OP == 3 || PARAM_RATE_OP == 4 ) begin:FLEXE //FLEX or OTN_200G OTN_400G
	assign  rx_mii_d_scr = rx_mii_d_scr1;
        assign  rx_mii_sync_rev = rx_mii_sync_scr;
        assign  rx_mii_am_rev = rx_mii_am;
	assign  rx_mii_vld_rev = rx_mii_vld;

    end
    else begin: OTN
        case (PARAM_RATE_OP)
        0: begin: descrambler_64 //25G
            alt_e2550_descram64_hn  descram64( //SIM.EMULATE
                .clk (tclk),
                .din (rst_tclk ? '0 : rx_mii_d_scr1),
                .din_valid (rst_tclk ? '0 : rx_mii_am ? '0 : rx_mii_vld),
            
                // outputs
                .dout (rx_mii_d_scr),
                .dout_valid (rx_mii_vld_rev)
            );
        end
        1: begin: descrambler_128 //50G
            alt_e2550_descram128_hn  descram128( //SIM.EMULATE
                .clk (tclk),
                .din (rst_tclk ? '0 : rx_mii_d_scr1),
                .din_valid (rst_tclk ? '0 : rx_mii_am ? '0 : rx_mii_vld),
            
                // outputs
                .dout (rx_mii_d_scr),
                .dout_valid (rx_mii_vld_rev)
            );
        end
        2: begin: descrambler_256 //100G
            alt_e2550_descram256_hn  descram256( //SIM.EMULATE
                .clk (tclk),
                .reset(rst_tclk),
                .din (rst_tclk ? '0 : rx_mii_d_scr1),
                .din_valid (rst_tclk ? '0 : rx_mii_am ? '0 : rx_mii_vld),
            
                // outputs
                .dout (rx_mii_d_scr),
                .dout_valid (rx_mii_vld_rev)
            );
        end
        endcase

        always @ (posedge tclk)
        begin
            rx_mii_sync_rev <= rx_mii_sync_scr;
            rx_mii_am_rev <= rx_mii_am;
        end

    end
    endgenerate
endmodule

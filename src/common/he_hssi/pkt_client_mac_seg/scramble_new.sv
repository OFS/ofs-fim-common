// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


module scramble_new #(
    parameter PARAM_RATE_OP = 0,
              PARAM_MODE_OP = 1,
              PARAM_EHIP_RATE = 1,
              INTF_DATA_WD = 1 << (PARAM_RATE_OP + 6),
              INTF_SYNC_WD = 1 << (PARAM_RATE_OP + 1)
) (
    // input
    input var logic tclk,
    input var logic rst_tclk,

    input var logic [INTF_DATA_WD-1:0] tx_mii_d,
    input var logic [INTF_SYNC_WD-1:0] tx_mii_sync_rev,
    input var logic tx_mii_vld_rev,
    input var logic tx_mii_am_rev,

    // output
    output var logic [INTF_DATA_WD-1:0] tx_mii_d_scr,
    output var logic [INTF_SYNC_WD-1:0] tx_mii_sync_scr,
    output var logic tx_mii_vld,
    output var logic tx_mii_am
 ); 

    logic [INTF_SYNC_WD-1:0] tx_mii_sync_scr1;
    logic tx_mii_vld_scr;
    logic tx_mii_am_scr;
    logic tx_mii_vld_reg;
    logic tx_mii_vld_reg2;

    //========tx
    generate
    if (PARAM_MODE_OP == 2 || PARAM_RATE_OP == 3 || PARAM_RATE_OP == 4 ) begin:FLEXE //FLEX or OTN_200G or OTN_400G
       always @ (posedge tclk) begin
         if (rst_tclk) begin
             tx_mii_d_scr     <= '0;
             tx_mii_sync_scr  <= '0;
             tx_mii_vld       <= '0;
             tx_mii_am        <= '0;
         end
         else begin
             tx_mii_d_scr     <= tx_mii_d;
             tx_mii_sync_scr  <= tx_mii_sync_rev;
             tx_mii_vld       <= tx_mii_vld_rev;
             tx_mii_am        <= tx_mii_am_rev;
         end
       end
    end
    else begin: OTN
      case (PARAM_RATE_OP)
      0 : begin: scrambler_64 //10G & 25G
          alt_e2550_scram64_hn  scram64( //SIM.EMULATE
              .clk (tclk),
              .din (rst_tclk ? '0 : tx_mii_d),
              .din_valid (rst_tclk ? '0 : tx_mii_am_rev ? '0 : tx_mii_vld_rev),

              // outputs
              .dout (tx_mii_d_scr),
              .dout_valid (tx_mii_vld_scr)
          );
      end
      1 : begin: scrambler_128 //50G
          alt_e2550_scram128_hn  scram128( //SIM.EMULATE
              .clk (tclk),
              .din (rst_tclk ? '0 : tx_mii_d),
              .din_valid (rst_tclk ? '0 : tx_mii_am_rev ? '0 : tx_mii_vld_rev),

              // outputs
              .dout (tx_mii_d_scr),
              .dout_valid (tx_mii_vld_scr)
          );
      end
      2 : begin: scrambler_256 //100G
          alt_e2550_scram256_hn  scram256( //SIM.EMULATE
              .clk (tclk),
              .reset(rst_tclk),
              .din (rst_tclk ? '0 : tx_mii_d),
              .din_valid (rst_tclk ? '0 : tx_mii_am_rev ? '0 : tx_mii_vld_rev),

              // outputs
              .dout (tx_mii_d_scr),
              .dout_valid (tx_mii_vld_scr)
          );
      end
      endcase

      always @ (posedge tclk)
      begin
	  tx_mii_vld_reg <= tx_mii_vld_rev;
	  tx_mii_vld_reg2 <= tx_mii_vld_reg;
          tx_mii_sync_scr1 <= tx_mii_sync_rev;
          tx_mii_sync_scr <= tx_mii_sync_scr1;
          tx_mii_am_scr <= tx_mii_am_rev;
          tx_mii_am     <= tx_mii_am_scr;
      end

    	if (PARAM_EHIP_RATE == "40G")	
	      assign tx_mii_vld = tx_mii_vld_reg2;
        else 
	      assign tx_mii_vld = tx_mii_vld_scr | tx_mii_am;

    end

    endgenerate
endmodule

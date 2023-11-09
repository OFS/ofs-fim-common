// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT



`default_nettype none
module rscr

    import gdr_pkt_pkg::*;
    (
        input  var logic clk,
        input  var logic rst,

        input  var MODE_e cfg_mode, 
        input  var MODE_OP_e cfg_mode_op,
        input  var PCS_D_16_WRD_s [1:0] rmii_dscr_d,
        input  var PCS_SYNC_16_WRD_s [1:0] rmii_dscr_sync,
        input  var PCS_C_16_WRD_s [1:0] rmii_dscr_c,
        input  var logic rmii_dscr_vld,

        output var logic rx_pcs_sop_det,
        output var logic rx_pcs_term_det,
        output var logic [NO_OF_RCHK-1:0] rx_pcs_pkt_vld,
        output var logic [NO_OF_RCHK_ADDR-1:0] rx_pcs_pkt_ln_id,
        output var PCS_D_WRD_s [31:0] rx_pcs_d,
        output var PCS_C_WRD_s [31:0] rx_pcs_c
    );

    logic [15:0] rst_reg;
    // Generate arrays of reset to be used in submodule
    always_ff @(posedge clk) begin
        rst_reg <= '{default:rst};
    end

    MODE_e cfg_mode_c1;
    MODE_OP_e cfg_mode_op_c1;

    PCS_D_16_WRD_s [1:0] rmii_dscr_d_c1;
    PCS_C_16_WRD_s [1:0] rmii_dscr_c_c1;
    PCS_SYNC_16_WRD_s [1:0] rmii_dscr_sync_c1;

    PCS_D_WRD_s [31:0] rmii_pcs_d;
    PCS_SYNC_WRD_s [31:0] rmii_pcs_sync;
    PCS_C_WRD_s [31:0]  rmii_pcs_c;

    PCS_D_WRD_s [31:0] i_dec_data;
    PCS_SYNC_WRD_s [31:0] i_dec_sync;

    PCS_C_WRD_s [31:0] dec_ctl;
    PCS_D_WRD_s [31:0] dec_data;

    logic rmii_dscr_vld_c1, mode_25G, sop_det, term_det, pkt_vld_cyc, pkt_vld;
    logic [31:0] rmii_pcs_vld_array, rmii_dscr_vld_array_c1, i_dec_vld_array,
                 rx_pcs_vld_array, dec_vld_array, sop_det_array, term_det_array;
    logic [31:0] dscr_vld;
    logic [31:0] dec_vld;

    always_ff @(posedge clk) begin
        cfg_mode_c1 <= cfg_mode;
        cfg_mode_op_c1 <= cfg_mode_op;

        mode_25G <= cfg_mode_c1 == MODE_e'(MODE_10_25G);

        rmii_dscr_d_c1    <= rmii_dscr_d;
        rmii_dscr_c_c1    <= rmii_dscr_c;
        rmii_dscr_sync_c1 <= rmii_dscr_sync;

        rmii_dscr_vld_c1       <= rmii_dscr_vld;
        rmii_dscr_vld_array_c1 <= {32{rmii_dscr_vld}};
    end

    // align rmii data
    always_ff @(posedge clk) begin
        rmii_pcs_vld_array <= rmii_dscr_vld_array_c1;
    if (rst_reg[0])
        rmii_pcs_vld_array <= '0;
    end // always_ff @ (posedge clk)

    always_ff @(posedge clk) begin
    case (cfg_mode)
    MODE_e'(MODE_10_25G): begin
        for (int i = 0; i < 1; i++) begin
            rmii_pcs_d[i]   <= rmii_dscr_d_c1[0].data[i];
            rmii_pcs_sync[i]   <= rmii_dscr_sync_c1[0].sync[i];
            rmii_pcs_c[i]   <= rmii_dscr_c_c1[0].ctl[i];
        end
        for (int i = 0; i < 1; i++) begin
            rmii_pcs_d[1+i] <= rmii_dscr_d_c1[1].data[i];
            rmii_pcs_sync[1+i] <= rmii_dscr_sync_c1[1].sync[i];
            rmii_pcs_c[1+i] <= rmii_dscr_c_c1[1].ctl[i];
        end
    end // case: MODE_e'(MODE_10_25G)
    MODE_e'(MODE_40_50G): begin
        for (int i = 0; i < 2; i++) begin
            rmii_pcs_d[i]   <= rmii_dscr_d_c1[0].data[i];
            rmii_pcs_sync[i]   <= rmii_dscr_sync_c1[0].sync[i];
            rmii_pcs_c[i]   <= rmii_dscr_c_c1[0].ctl[i];
        end
        for (int i = 0; i < 2; i++) begin
            rmii_pcs_d[2+i] <= rmii_dscr_d_c1[1].data[i];
            rmii_pcs_sync[2+i] <= rmii_dscr_sync_c1[1].sync[i];
            rmii_pcs_c[2+i] <= rmii_dscr_c_c1[1].ctl[i];
        end
    end // case: MODE_e'(MODE_40_50G)
    MODE_e'(MODE_100G): begin
        for (int i = 0; i < 4; i++) begin
            rmii_pcs_d[i]   <= rmii_dscr_d_c1[0].data[i];
            rmii_pcs_sync[i]   <= rmii_dscr_sync_c1[0].sync[i];
            rmii_pcs_c[i]   <= rmii_dscr_c_c1[0].ctl[i];
        end

        for (int i = 0; i < 4; i++) begin
            rmii_pcs_d[4+i] <= rmii_dscr_d_c1[1].data[i];
            rmii_pcs_sync[4+i] <= rmii_dscr_sync_c1[1].sync[i];
            rmii_pcs_c[4+i] <= rmii_dscr_c_c1[1].ctl[i];
        end // for (int i = 0; i < 2; i++)
    end // case: MODE_e'(MODE_100G)
    MODE_e'(MODE_200G): begin
        for (int i = 0; i < 8; i++) begin
            rmii_pcs_d[i]   <= rmii_dscr_d_c1[0].data[i];
            rmii_pcs_sync[i]   <= rmii_dscr_sync_c1[0].sync[i];
            rmii_pcs_c[i]   <= rmii_dscr_c_c1[0].ctl[i];
        end

        for (int i = 0; i < 8; i++) begin
            rmii_pcs_d[8+i] <= rmii_dscr_d_c1[1].data[i];
            rmii_pcs_sync[8+i] <= rmii_dscr_sync_c1[1].sync[i];
            rmii_pcs_c[8+i] <= rmii_dscr_c_c1[1].ctl[i];
        end // for (int i = 0; i < 4; i++)
    end // case: MODE_e'(MODE_200G)
    MODE_e'(MODE_400G): begin
        for (int i = 0; i < 16; i++) begin
            rmii_pcs_d[i]   <= rmii_dscr_d_c1[0].data[i];
            rmii_pcs_sync[i]   <= rmii_dscr_sync_c1[0].sync[i];
            rmii_pcs_c[i]   <= rmii_dscr_c_c1[0].ctl[i];
        end
        for (int i = 0; i < 16; i++) begin
            rmii_pcs_d[16+i] <= rmii_dscr_d_c1[1].data[i];
            rmii_pcs_sync[16+i] <= rmii_dscr_sync_c1[1].sync[i];
            rmii_pcs_c[16+i] <= rmii_dscr_c_c1[1].ctl[i];
        end // for (int i = 0; i < 8; i++)
    end
    default: begin
        rmii_pcs_d <= '0;
        rmii_pcs_sync <= '0;
        rmii_pcs_c <= '0;
        end
    endcase // case (cfg_mode)
    end

    always_ff @(posedge clk) begin
        i_dec_data      <= rmii_pcs_d;
        i_dec_sync      <= rmii_pcs_sync;
        i_dec_vld_array <= rmii_pcs_vld_array;
    end

    // decoding data
    genvar 	 k;
    generate
        for (k = 0; k < 32; k ++) begin: DECODER_BLOCK
        decoder decoder
            (// inputs
             .clk (clk),
             .rst (rst),
             .i_data (i_dec_data[k]),
             .i_sync (i_dec_sync[k]),
             .i_vld  (i_dec_vld_array[k]),

             // outputs
             .dec_data (dec_data[k]),
             .dec_ctl (dec_ctl[k]),
             .dec_vld (dec_vld_array[k])
             );
        end // for (k = 0; k < 32; k ++)
    endgenerate

    always_ff @(posedge clk) begin
        if ((cfg_mode_op_c1 == MODE_OP_e'(MODE_OTN)) | (cfg_mode_op_c1 == MODE_OP_e'(MODE_FLEXE))  ) begin
            rx_pcs_d          <= dec_data;
            rx_pcs_c          <= dec_ctl;
            rx_pcs_vld_array  <= dec_vld_array;
            for (int i = 0; i < 32; i ++) begin
                sop_det_array[i]  <= Sop_Det(mode_25G, dec_data[i], dec_ctl[i], dec_vld_array[i]);
                term_det_array[i] <= Term_Det(dec_data[i], dec_ctl[i], dec_vld_array[i]);
            end
        end 
        else begin
            rx_pcs_d         <= rmii_pcs_d;
            rx_pcs_c         <= rmii_pcs_c;
            rx_pcs_vld_array <= rmii_pcs_vld_array;
            for (int i = 0; i < 32; i ++) begin
                sop_det_array[i]  <=
                      Sop_Det(mode_25G, rmii_pcs_d[i], rmii_pcs_c[i], rmii_pcs_vld_array[i]) ;
                term_det_array[i] <=
                      Term_Det(rmii_pcs_d[i], rmii_pcs_c[i], rmii_pcs_vld_array[i]);
            end
        end
    end
    
    always_comb begin
    rx_pcs_sop_det = |sop_det_array;
    rx_pcs_term_det = |term_det_array;	
    end
    
    always_ff @(posedge clk) begin
    if (rx_pcs_term_det)
        pkt_vld_cyc <= '0;
    else if (rx_pcs_sop_det)
        pkt_vld_cyc <= '1;
    
    if (rst_reg[0])
        pkt_vld_cyc <= '0;	
    end
    
    always_comb begin
        for (int i = 0; i < NO_OF_RCHK; i++) begin
            rx_pcs_pkt_vld[i] = 
                  ((rx_pcs_pkt_ln_id == i) & rx_pcs_sop_det) |
              ((rx_pcs_pkt_ln_id == i) & rx_pcs_vld_array[i] & pkt_vld_cyc) ;
        end
    end
    
    always_ff @(posedge clk) begin
        if (rx_pcs_term_det)
            rx_pcs_pkt_ln_id <= rx_pcs_pkt_ln_id + 1'b1;
        
        if (rst_reg[0])
            rx_pcs_pkt_ln_id <= '0;	
    end
    
    function Sop_Det;
    input mode_25G;
    
    input PCS_D_WRD_s data;
    input PCS_C_WRD_s ctl;
    input vld;
    
    
    begin
        if (mode_25G)
    	Sop_Det = ((data.data[7] == PCS_C_START) & ctl.ctl[7] & vld) |
    		  ((data.data[3] == PCS_C_START) & ctl.ctl[3] & vld)   ;
        else
    	Sop_Det = ((data.data[7] == PCS_C_START) & ctl.ctl[7] & vld);
        
    end
    endfunction // sop_det
    
    function Term_Det;	
    input PCS_D_WRD_s data;
    input PCS_C_WRD_s ctl;
    input vld;
    
    begin
        
        Term_Det = ((data.data[7] == PCS_C_END) & ctl.ctl[7] & vld) |
    	       ((data.data[6] == PCS_C_END) & ctl.ctl[6] & vld) |
    	       ((data.data[5] == PCS_C_END) & ctl.ctl[5] & vld) |
    	       ((data.data[4] == PCS_C_END) & ctl.ctl[4] & vld) |
    	       ((data.data[3] == PCS_C_END) & ctl.ctl[3] & vld) |
    	       ((data.data[2] == PCS_C_END) & ctl.ctl[2] & vld) |
    	       ((data.data[1] == PCS_C_END) & ctl.ctl[1] & vld) |
    	       ((data.data[0] == PCS_C_END) & ctl.ctl[0] & vld)   ;	    
    end
    endfunction
    
endmodule // rscr

    

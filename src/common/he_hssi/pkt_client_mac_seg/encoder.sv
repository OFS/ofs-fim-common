// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT



`default_nettype none
module encoder

    import gdr_pkt_pkg::*;
    
   (
    input  var logic clk,
    input  var logic rst,
    input  var PCS_D_WRD_s i_data,
    input  var PCS_C_WRD_s i_ctl,
    input  var logic i_vld,
    
    output var PCS_D_WRD_s enc_data,
    output var logic [1:0] enc_sync,
    output var logic enc_vld

    );
    
    logic [15:0] rst_reg;
     // Generate arrays of reset to be used in submodule
    always_ff @(posedge clk) begin
	rst_reg <= '{default:rst};
    end


    logic start_det, term_det, term_det_prev, idle_det;
    
    logic [7:0] term_det_array, term_det_array_prev, idle_det_array;
	   
    always_comb begin
	for (int i = 0; i < 8; i ++) begin	    
	    term_det_array[i] = (i_data.data[i] == PCS_C_END) &
		                (i_ctl.ctl[i] & i_vld);

	    idle_det_array[i] = (i_data.data[i] == PCS_C_IDLE) &
		               (i_ctl.ctl[i] & i_vld);
	end
	
	start_det = 
          (i_data.data[7] == PCS_C_START) & i_ctl.ctl[7] & i_vld;
	
	term_det  = |term_det_array;
	
	idle_det  = (idle_det_array == 8'hff);
    end

    always_ff @(posedge clk) begin
	if (start_det) begin
	    enc_data <= 
              {CODE_GRP_CTL_e'(CG_S_D), i_data.data[6], i_data.data[5], i_data.data[4],
	       i_data.data[3], i_data.data[2], i_data.data[1], i_data.data[0]};
	    
	    enc_sync <= 2'b10;

	    enc_vld <= '1;
	end // if (start_det)
	else if (term_det) begin
	    enc_sync <= 2'b10;
	    enc_vld  <= '1;
	    case (1'b1)
		term_det_array[7]: begin
		    enc_data <= 
		      {CODE_GRP_CTL_e'(CG_T_C), 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0};
		end // case: term_det_array[7]
		term_det_array[6]: begin
		    enc_data <= 
		      {CODE_GRP_CTL_e'(CG_1D_T_C), i_data.data[7], 8'd0, 8'd0, 
                       8'd0, 8'd0, 8'd0, 8'd0};
		end // case: term_det_array[6]
		term_det_array[5]: begin
		    enc_data <= 
		      {CODE_GRP_CTL_e'(CG_2D_T_C), i_data.data[7], i_data.data[6], 8'd0, 
                       8'd0, 8'd0, 8'd0, 8'd0};
		end // case: term_det_array[6]
		term_det_array[4]: begin
		    enc_data <= 
		      {CODE_GRP_CTL_e'(CG_3D_T_C), 
		       i_data.data[7], i_data.data[6], i_data.data[5], 
                       8'd0, 8'd0, 8'd0, 8'd0};
		end // case: term_det_array[5]
		term_det_array[3]: begin
		    enc_data <= 
		      {CODE_GRP_CTL_e'(CG_4D_T_C), 
		       i_data.data[7], i_data.data[6], i_data.data[5], 
                       i_data.data[4], 8'd0, 8'd0, 8'd0};
		end // case: term_det_array[4]
		term_det_array[2]: begin
		    enc_data <= 
		      {CODE_GRP_CTL_e'(CG_5D_T_C), 
		       i_data.data[7], i_data.data[6], i_data.data[5], 
                       i_data.data[4], i_data.data[3], 8'd0, 8'd0};
		end // case: term_det_array[3]
		term_det_array[1]: begin
		    enc_data <= 
		      {CODE_GRP_CTL_e'(CG_6D_T_C), 
		       i_data.data[7], i_data.data[6], i_data.data[5], 
                       i_data.data[4], i_data.data[3], i_data.data[2], 8'd0};
		end // case: term_det_array[2]
		term_det_array[0]: begin
		    enc_data <= 
		      {CODE_GRP_CTL_e'(CG_7D_T_C), 
		       i_data.data[7], i_data.data[6], i_data.data[5], 
                       i_data.data[4], i_data.data[3], i_data.data[2], i_data.data[1]};
		end // case: term_det_array[1]
		default: begin
		    enc_data <= 
		      {CODE_GRP_CTL_e'(CG_8CTL), 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0};
		end
	    endcase // case (1'b1)
	end // if (term_det)
	else if (idle_det) begin
	    enc_sync <= 2'b10;
	    enc_vld  <= '1;
	    enc_data <= 
	      {CODE_GRP_CTL_e'(CG_8CTL), 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0};
	end
	else begin
	    enc_sync <= 2'b01;
	    enc_vld  <= i_vld;
	    enc_data <= 
	      {i_data.data[7], i_data.data[6], i_data.data[5], i_data.data[4],
               i_data.data[3], i_data.data[2], i_data.data[1], i_data.data[0]};
	end // case: term_det_array[2]
    end

   

    
endmodule // encoder

    

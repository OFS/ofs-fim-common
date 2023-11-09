// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT



`default_nettype none
module decoder

    import gdr_pkt_pkg::*;
    
   (
    input  var logic clk,
    input  var logic rst,

    input var PCS_D_WRD_s  i_data,
    input var logic [1:0] i_sync,
    input var logic i_vld,

    output  var PCS_D_WRD_s dec_data,
    output  var PCS_C_WRD_s dec_ctl,
    output  var logic dec_vld
    );

    logic [15:0] rst_reg;
     // Generate arrays of reset to be used in submodule
    always_ff @(posedge clk) begin
	rst_reg <= '{default:rst};
    end

    //CODE_GRP_CTL_e code_grp;
    logic [7:0] code_grp_data, code_grp;
    

    always_comb begin
	code_grp_data  = i_data.data[7];
	code_grp = code_grp_data;
	
    end

    always_ff @(posedge clk) begin
	dec_vld <= i_vld;
	
	if (i_sync == 2'b10) begin
	    case (code_grp)
		CODE_GRP_CTL_e'(CG_8CTL): begin
		    dec_data <= PCS_8_IDLE_DATA;
		    dec_ctl  <= '1;
		end
		CODE_GRP_CTL_e'(CG_4CTL_S): begin
		    dec_data <= 
                      {PCS_C_IDLE, PCS_C_IDLE, PCS_C_IDLE, PCS_C_IDLE,
		       PCS_C_START, i_data.data[2], i_data.data[1], i_data.data[0]};
		    dec_ctl <= 
		      {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0 };		    
		end // case: CODE_GRP_CTL_e'(CG_4CTL_S)
		CODE_GRP_CTL_e'(CG_S_D): begin
		    dec_data <=
		      {PCS_C_START, i_data.data[6], i_data.data[5], i_data.data[4],
		       i_data.data[3], i_data.data[2], i_data.data[1], i_data.data[0]};
		    dec_ctl <= 
		      {1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 };
		end // case: CODE_GRP_CTL_e'(CG_S_D)
		CODE_GRP_CTL_e'(CG_T_C): begin
		    dec_data <=
		      {PCS_C_END, PCS_C_IDLE, PCS_C_IDLE, PCS_C_IDLE,
		       PCS_C_IDLE, PCS_C_IDLE, PCS_C_IDLE,PCS_C_IDLE };
		    dec_ctl <= 
		      {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1 };
		end // case: CODE_GRP_CTL_e'(CG_T_C)
		CODE_GRP_CTL_e'(CG_1D_T_C): begin
		    dec_data <=
		      {i_data.data[6], PCS_C_END, PCS_C_IDLE, PCS_C_IDLE, 
		       PCS_C_IDLE, PCS_C_IDLE, PCS_C_IDLE, PCS_C_IDLE };
		    dec_ctl <= 
		      {1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1 };
		end // case: CODE_GRP_CTL_e'(CG_1D_T_C)
		CODE_GRP_CTL_e'(CG_2D_T_C): begin
		    dec_data <=
		      {i_data.data[6], i_data.data[5], PCS_C_END, PCS_C_IDLE,  
		       PCS_C_IDLE, PCS_C_IDLE, PCS_C_IDLE, PCS_C_IDLE };
		    dec_ctl <= 
		      {1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1 };
		end // case: CODE_GRP_CTL_e'(CG_2D_T_C)
		CODE_GRP_CTL_e'(CG_3D_T_C): begin
		    dec_data <=
		      {i_data.data[6], i_data.data[5], i_data.data[4], PCS_C_END,  
		       PCS_C_IDLE, PCS_C_IDLE, PCS_C_IDLE, PCS_C_IDLE };
		    dec_ctl <= 
		      {1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1 };
		end // case: CODE_GRP_CTL_e'(CG_3D_T_C)
		CODE_GRP_CTL_e'(CG_4D_T_C): begin
		    dec_data <=
		      {i_data.data[6], i_data.data[5], i_data.data[4], i_data.data[3],   
		       PCS_C_END, PCS_C_IDLE, PCS_C_IDLE, PCS_C_IDLE};
		    dec_ctl <= 
		      {1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1 };
		end // case: CODE_GRP_CTL_e'(CG_4D_T_C)
		CODE_GRP_CTL_e'(CG_5D_T_C): begin
		    dec_data <=
		      {i_data.data[6], i_data.data[5], i_data.data[4], i_data.data[3],   
		       i_data.data[2], PCS_C_END, PCS_C_IDLE, PCS_C_IDLE};
		    dec_ctl <= 
		      {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1 };
		end // case: CODE_GRP_CTL_e'(CG_5D_T_C)
		CODE_GRP_CTL_e'(CG_6D_T_C): begin
		    dec_data <=
		      {i_data.data[6], i_data.data[5], i_data.data[4], i_data.data[3],   
		       i_data.data[2], i_data.data[1], PCS_C_END, PCS_C_IDLE};
		    dec_ctl <= 
		      {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1 };
		end // case: CODE_GRP_CTL_e'(CG_6D_T_C)
		CODE_GRP_CTL_e'(CG_7D_T_C): begin
		    dec_data <=
		      {i_data.data[6], i_data.data[5], i_data.data[4], i_data.data[3],   
		       i_data.data[2], i_data.data[1], i_data.data[0], PCS_C_END};
		    dec_ctl <= 
		      {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1 };
		end // case: CODE_GRP_CTL_e'(CG_7D_T_C)
		CODE_GRP_CTL_e'(CG_O_C): begin
		    dec_data <=
		      {PCS_C_ORD, i_data.data[6], i_data.data[5], i_data.data[4],   
		       PCS_C_IDLE, PCS_C_IDLE, PCS_C_IDLE, PCS_C_IDLE};
		    dec_ctl <= 
		      {1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1 };
		end // case: CODE_GRP_CTL_e'(CG_O_C)
		CODE_GRP_CTL_e'(CG_4CTL_O): begin
		    dec_data <=
		      {PCS_C_IDLE, PCS_C_IDLE, PCS_C_IDLE, PCS_C_IDLE,
                       PCS_C_ORD, i_data.data[2], i_data.data[1], i_data.data[0]};
		    dec_ctl <= 
		      {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0 };
		end // case: CODE_GRP_CTL_e'(CG_4CTL_O)
		CODE_GRP_CTL_e'(CG_O_S): begin
		    dec_data <=
		      {PCS_C_ORD, i_data.data[6], i_data.data[5], i_data.data[4],
		       PCS_C_START, i_data.data[2], i_data.data[1], i_data.data[0]};
		    dec_ctl <= 
		      {1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0 };
		end // case: CODE_GRP_CTL_e'(CG_O_S)
		CODE_GRP_CTL_e'(CG_O_O): begin
		    dec_data <=
		      {PCS_C_ORD, i_data.data[6], i_data.data[5], i_data.data[4],
		       PCS_C_ORD, i_data.data[2], i_data.data[1], i_data.data[0]};
		    dec_ctl <= 
		      {1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0 };
		end // case: CODE_GRP_CTL_e'(CG_O_O)
		default: begin
		    dec_data <= '0;
		    dec_ctl  <= '0;
		    
		end // case: default
	    endcase // case (code_grp)
	    
	end // if (i_sync == 2'b10)
	else begin
	    dec_data <= i_data;
	    dec_ctl  <= '0;
	end

    end
    
endmodule // dencoder


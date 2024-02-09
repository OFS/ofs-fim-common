// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`default_nettype none
module rchk #(parameter   PARAM_RATE_OP  = 4,parameter INIT_FILE_DATA = "init_file_data.hex" )

    
    
   (
    input var logic clk,
    input var logic rst,
    //input var logic [4:0] my_id,
    input var gdr_pkt_pkg::MODE_e cfg_mode,

    input var logic rx_pcs_sop_det,
    input var logic rx_pcs_term_det,
    input var logic rx_pcs_pkt_vld,
    //input var logic [5:0] rx_pcs_pkt_ln_id,
    input var gdr_pkt_pkg::PCS_D_WRD_s [31:0] rx_pcs_d,
    input var gdr_pkt_pkg::PCS_C_WRD_s [31:0] rx_pcs_c,


    output var logic crc32_ok,
    output var logic crc32_err,
    output var logic inc_rx_sop,
    output var logic inc_rx_eop,
    output var logic inc_rx_pkt,
    output var logic inc_rx_miss_sop,
    output var logic inc_rx_miss_eop
    );
    import gdr_pkt_pkg::*;
    logic [15:0] rst_reg;
    // Generate arrays of reset to be used in submodule
    always_ff @(posedge clk) begin
	rst_reg <= '{default:rst};
    end

    logic rchk_fifo_push, rchk_fifo_pop, pcs_sop_det, pcs_term_det, 
	  pcs_empty, pcs_full, pcs_mux_vld,  pcs_mux_sop_det, pcs_mux_term_det,
	  pcs_mux_vld_c1, pcs_mux_sop_det_c1, pcs_mux_sfd_det_c1, pcs_mux_term_det_c1,
	  crc_chk_vld, crc_chk_sop, crc_chk_eop,  rx_sop_state, pcs_mux_sop_state;   

    logic [1:0] pcs_mux_eop_bytes_vld, pcs_mux_eop_bytes_vld_c1, crc_chk_eop_bytes_vld;
    
    logic [3:0] pcs_mux_term_det_array, pcs_mux_term_det_array_c1;
    
    
    logic [5:0] dmux_cnt;
    
    PCS_D_WRD_s [31:0] pcs_data;  
  
    PCS_C_WRD_s [31:0] pcs_ctl;

    DATA_WRD_s [63:0] data_wrd;
    CTL_WRD_s [63:0] ctl_wrd;
    DATA_WRD_s pcs_mux_data, pcs_mux_data_c1, crc_chk_data;
    CTL_WRD_s  pcs_mux_ctl, pcs_mux_ctl_c1;
    
   
   logic rx_pcs_pkt_vld_c1, rx_pcs_sop_det_c1, rx_pcs_term_det_c1;

    generate 
	//------------------------------------------------------------------------------------
	// Generate 400G
	if (PARAM_RATE_OP == 4) begin: rchk_buffer_400G
	    PCS_D_WRD_s [31:0] rx_pcs_d_c1;
	    PCS_C_WRD_s [31:0] rx_pcs_c_c1;
	    PCS_D_WRD_s [31:0] pcs_data_o;    
	    PCS_C_WRD_s [31:0] pcs_ctl_o;
	    logic [6:0] pcs_cnt;
	    
	    pipe #(.W (1                 +
		       (PCS_D_WRD_WD*32) +
		       (PCS_C_WRD_WD*32) +
		       2  ),
		   .N (1) ) rx_pcs_pipe
		(.clk (clk),
		 .dIn({  rx_pcs_pkt_vld 
			 , rx_pcs_d
			 , rx_pcs_c
			 , rx_pcs_sop_det
			 , rx_pcs_term_det
			 
			 }),
		 
		 .dOut ({  rchk_fifo_push
			   , rx_pcs_d_c1
			   , rx_pcs_c_c1
			   , rx_pcs_sop_det_c1
			   , rx_pcs_term_det_c1
			   
			   })
		 );
	    
	    fifo_lat_0 #(.DEPTH (64),
				   .INIT_FILE_DATA (INIT_FILE_DATA),
		         .DW (2                 +
			      (PCS_D_WRD_WD*32) +
			      (PCS_C_WRD_WD*32)   )   ) rchk_fifo
		(// inputs
		 .clk (clk),
		 .reset (rst_reg[0]),
		 .push (rchk_fifo_push),
		 .pop (rchk_fifo_pop),
		 .dIn ({rx_pcs_sop_det_c1,
			rx_pcs_term_det_c1,
			rx_pcs_c_c1,
			rx_pcs_d_c1}),
		 
		 // outputs
		 .dOut ({pcs_sop_det,
			 pcs_term_det,
			 pcs_ctl_o,
			 pcs_data_o}),
		 .cnt (pcs_cnt),
		 .full (pcs_full),
		 .empty (pcs_empty),
		 .dOutVld ()
		 
		 );

	    always_comb begin
		pcs_data = pcs_data_o;
		pcs_ctl  = pcs_ctl_o;
		
	    end
	end // block: rchk_buffer_400G

	//------------------------------------------------------------------------------------
	// Generate 200G 
	else if (PARAM_RATE_OP == 3) begin: rchk_buffer_200G
	    PCS_D_WRD_s [15:0] rx_pcs_d_c1;
	    PCS_C_WRD_s [15:0] rx_pcs_c_c1;
	    PCS_D_WRD_s [15:0] pcs_data_o;    
	    PCS_C_WRD_s [15:0] pcs_ctl_o;
	    logic [7:0] pcs_cnt;
	    
	    pipe #(.W (1                 +
		       (PCS_D_WRD_WD*16) +
		       (PCS_C_WRD_WD*16) +
		       2  ),
		   .N (1) ) rx_pcs_pipe
		(.clk (clk),
		 .dIn({  rx_pcs_pkt_vld 
			 , rx_pcs_d[15:0]
			 , rx_pcs_c[15:0]
			 , rx_pcs_sop_det
			 , rx_pcs_term_det
			 
			 }),
		 
		 .dOut ({  rchk_fifo_push
			   , rx_pcs_d_c1
			   , rx_pcs_c_c1
			   , rx_pcs_sop_det_c1
			   , rx_pcs_term_det_c1
			   
			   })
		 );
	    
	    fifo_lat_0 #(.DEPTH (128),
					.INIT_FILE_DATA(INIT_FILE_DATA),
		         .DW (2                 +
			      (PCS_D_WRD_WD*16) +
			      (PCS_C_WRD_WD*16)   )   ) rchk_fifo
		(// inputs
		 .clk (clk),
		 .reset (rst_reg[0]),
		 .push (rchk_fifo_push),
		 .pop (rchk_fifo_pop),
		 .dIn ({rx_pcs_sop_det_c1,
			rx_pcs_term_det_c1,
			rx_pcs_c_c1,
			rx_pcs_d_c1}),
		 
		 // outputs
		 .dOut ({pcs_sop_det,
			 pcs_term_det,
			 pcs_ctl_o,
			 pcs_data_o}),
		 .cnt (pcs_cnt),
		 .full (pcs_full),
		 .empty (pcs_empty),
		 .dOutVld ()
		 
		 );

	    always_comb begin
		pcs_data[15:0] = pcs_data_o;
		pcs_data[31:16] = '0;
		
		pcs_ctl[15:0]  = pcs_ctl_o;
		pcs_ctl[31:16] = '0;
	    end
	end // block: rchk_buffer_200G

	//------------------------------------------------------------------------------------
	// Generate 100G 
	else if (PARAM_RATE_OP == 2) begin: rchk_buffer_100G
	    PCS_D_WRD_s [7:0] rx_pcs_d_c1;
	    PCS_C_WRD_s [7:0] rx_pcs_c_c1;
	    PCS_D_WRD_s [7:0] pcs_data_o;    
	    PCS_C_WRD_s [7:0] pcs_ctl_o;
	    logic [8:0] pcs_cnt;
	    
	    pipe #(.W (1                 +
		       (PCS_D_WRD_WD*8) +
		       (PCS_C_WRD_WD*8) +
		       2  ),
		   .N (1) ) rx_pcs_pipe
		(.clk (clk),
		 .dIn({  rx_pcs_pkt_vld 
			 , rx_pcs_d[7:0]
			 , rx_pcs_c[7:0]
			 , rx_pcs_sop_det
			 , rx_pcs_term_det
			 
			 }),
		 
		 .dOut ({  rchk_fifo_push
			   , rx_pcs_d_c1
			   , rx_pcs_c_c1
			   , rx_pcs_sop_det_c1
			   , rx_pcs_term_det_c1
			   
			   })
		 );
	    
	    fifo_lat_0 #(.DEPTH (256),
					.INIT_FILE_DATA(INIT_FILE_DATA),
		         .DW (2                 +
			      (PCS_D_WRD_WD*8) +
			      (PCS_C_WRD_WD*8)   )   ) rchk_fifo
		(// inputs
		 .clk (clk),
		 .reset (rst_reg[0]),
		 .push (rchk_fifo_push),
		 .pop (rchk_fifo_pop),
		 .dIn ({rx_pcs_sop_det_c1,
			rx_pcs_term_det_c1,
			rx_pcs_c_c1,
			rx_pcs_d_c1}),
		 
		 // outputs
		 .dOut ({pcs_sop_det,
			 pcs_term_det,
			 pcs_ctl_o,
			 pcs_data_o}),
		 .cnt (pcs_cnt),
		 .full (pcs_full),
		 .empty (pcs_empty),
		 .dOutVld ()
		 
		 );

	    always_comb begin
		pcs_data[7:0] = pcs_data_o;
		pcs_data[31:8] = '0;
		
		pcs_ctl[7:0]  = pcs_ctl_o;
		pcs_ctl[31:8] = '0;
	    end
	end // block: rchk_buffer_100G
	
	//------------------------------------------------------------------------------------
	// Generate 50G 
	else if (PARAM_RATE_OP == 1) begin: rchk_buffer_50G
	    PCS_D_WRD_s [3:0] rx_pcs_d_c1;
	    PCS_C_WRD_s [3:0] rx_pcs_c_c1;
	    PCS_D_WRD_s [3:0] pcs_data_o;    
	    PCS_C_WRD_s [3:0] pcs_ctl_o;
	    logic [9:0] pcs_cnt;
	    
	    pipe #(.W (1                 +
		       (PCS_D_WRD_WD*4) +
		       (PCS_C_WRD_WD*4) +
		       2  ),
		   .N (1) ) rx_pcs_pipe
		(.clk (clk),
		 .dIn({  rx_pcs_pkt_vld 
			 , rx_pcs_d[3:0]
			 , rx_pcs_c[3:0]
			 , rx_pcs_sop_det
			 , rx_pcs_term_det
			 
			 }),
		 
		 .dOut ({  rchk_fifo_push
			   , rx_pcs_d_c1
			   , rx_pcs_c_c1
			   , rx_pcs_sop_det_c1
			   , rx_pcs_term_det_c1
			   
			   })
		 );
	    
	    fifo_lat_0 #(.DEPTH (512),
					.INIT_FILE_DATA(INIT_FILE_DATA),
		         .DW (2                 +
			      (PCS_D_WRD_WD*4) +
			      (PCS_C_WRD_WD*4)   )   ) rchk_fifo
		(// inputs
		 .clk (clk),
		 .reset (rst_reg[0]),
		 .push (rchk_fifo_push),
		 .pop (rchk_fifo_pop),
		 .dIn ({rx_pcs_sop_det_c1,
			rx_pcs_term_det_c1,
			rx_pcs_c_c1,
			rx_pcs_d_c1}),
		 
		 // outputs
		 .dOut ({pcs_sop_det,
			 pcs_term_det,
			 pcs_ctl_o,
			 pcs_data_o}),
		 .cnt (pcs_cnt),
		 .full (pcs_full),
		 .empty (pcs_empty),
		 .dOutVld ()
		 
		 );

	    always_comb begin
		pcs_data[3:0] = pcs_data_o;
		pcs_data[31:4] = '0;
		
		pcs_ctl[3:0]  = pcs_ctl_o;
		pcs_ctl[31:4] = '0;
	    end
	end // block: rchk_buffer_50G
	
	//------------------------------------------------------------------------------------
	// Generate 10G 
	else  begin: rchk_buffer_10G
	    PCS_D_WRD_s [1:0] rx_pcs_d_c1;
	    PCS_C_WRD_s [1:0] rx_pcs_c_c1;
	    PCS_D_WRD_s [1:0] pcs_data_o;    
	    PCS_C_WRD_s [1:0] pcs_ctl_o;
	    logic [10:0] pcs_cnt;
	    
	    pipe #(.W (1                 +
		       (PCS_D_WRD_WD*2) +
		       (PCS_C_WRD_WD*2) +
		       2  ),
		   .N (1) ) rx_pcs_pipe_10G
		(.clk (clk),
		 .dIn({  rx_pcs_pkt_vld 
			 , rx_pcs_d[1:0]
			 , rx_pcs_c[1:0]
			 , rx_pcs_sop_det
			 , rx_pcs_term_det
			 
			 }),
		 
		 .dOut ({  rchk_fifo_push
			   , rx_pcs_d_c1
			   , rx_pcs_c_c1
			   , rx_pcs_sop_det_c1
			   , rx_pcs_term_det_c1
			   
			   })
		 );
	    
	    fifo_lat_0 #(.DEPTH (1024),
					.INIT_FILE_DATA(INIT_FILE_DATA),
		         .DW (2                 +
			      (PCS_D_WRD_WD*2) +
			      (PCS_C_WRD_WD*2)   )   ) rchk_fifo_10G
		(// inputs
		 .clk (clk),
		 .reset (rst_reg[0]),
		 .push (rchk_fifo_push),
		 .pop (rchk_fifo_pop),
		 .dIn ({rx_pcs_sop_det_c1,
			rx_pcs_term_det_c1,
			rx_pcs_c_c1,
			rx_pcs_d_c1}),
		 
		 // outputs
		 .dOut ({pcs_sop_det,
			 pcs_term_det,
			 pcs_ctl_o,
			 pcs_data_o}),
		 .cnt (pcs_cnt),
		 .full (pcs_full),
		 .empty (pcs_empty),
		 .dOutVld ()
		 
		 );

	    always_comb begin
		pcs_data[1:0] = pcs_data_o;
		pcs_data[31:2] = '0;
		
		pcs_ctl[1:0]  = pcs_ctl_o;
		pcs_ctl[31:2] = '0;
	    end
	end // block: rchk_buffer_10G	
    endgenerate
    /*
   pipe #(.W (1                 +
	      (PCS_D_WRD_WD*32) +
	      (PCS_C_WRD_WD*32) +
              2  ),
	  .N (1) ) rx_pcs_pipe
     (.clk (clk),
      .dIn({  rx_pcs_pkt_vld 
	    , rx_pcs_d
	    , rx_pcs_c
	    , rx_pcs_sop_det
	    , rx_pcs_term_det

	    }),

      .dOut ({  rchk_fifo_push
	      , rx_pcs_d_c1
	      , rx_pcs_c_c1
	      , rx_pcs_sop_det_c1
	      , rx_pcs_term_det_c1

	      })
      );*/

   /*
    always_ff @(posedge clk) begin
	
	rchk_fifo_push <= rx_pcs_pkt_vld;
        rx_pcs_d_c1  <= rx_pcs_d;       
        rx_pcs_c_c1 <= rx_pcs_c;
        rx_pcs_sop_det_c1 <= rx_pcs_sop_det;
        rx_pcs_term_det_c1 <= rx_pcs_term_det;
    end
    */
      
    always_comb begin
	for (int i = 0; i < 32; i++) begin
	    data_wrd[(2*i)  ] = pcs_data[i].data[7:4];
	    data_wrd[(2*i)+1] = pcs_data[i].data[3:0];

	    ctl_wrd[(2*i)  ] = pcs_ctl[i].ctl[7:4];
	    ctl_wrd[(2*i)+1] = pcs_ctl[i].ctl[3:0];
	    
	end // for (int i = 0; i < 32; i++)		
    end

    always_ff @(posedge clk) begin
	if (!pcs_empty) begin
	    case (cfg_mode)
		MODE_e'(MODE_10_25G): begin
		    dmux_cnt[1:0] <=
		       (rchk_fifo_pop & !pcs_term_det) |
                       pcs_mux_term_det_c1               ? '0            :
		       (rchk_fifo_pop & pcs_term_det) |
                        pcs_mux_term_det                 ? dmux_cnt[1:0] :    
                                                           dmux_cnt[1:0] + 1'b1;
                       
		    rchk_fifo_pop <=
		      (!rchk_fifo_pop & (dmux_cnt[1:0] == 2'd2))  |
		      (!rchk_fifo_pop & pcs_mux_term_det &  (dmux_cnt[1:0] < 2'd2)) ;
		    
		    		    
		end // case: MODE_e'(MODE_10_25G)
		
		MODE_e'(MODE_40_50G): begin
		    dmux_cnt[2:0] <=
		       (rchk_fifo_pop & !pcs_term_det) |
                       pcs_mux_term_det_c1               ? '0            :
		       (rchk_fifo_pop & pcs_term_det) |
                        pcs_mux_term_det                 ? dmux_cnt[2:0] :    
                                                           dmux_cnt[2:0] + 1'b1;

		     rchk_fifo_pop <=
		      (!rchk_fifo_pop & (dmux_cnt[2:0] == 3'd6))  |
		      (!rchk_fifo_pop & pcs_mux_term_det &  (dmux_cnt[2:0] < 4'd6)) ;
		    		    
		end // case: MODE_e'(MODE_40_50G)
		
		MODE_e'(MODE_100G): begin
		    dmux_cnt[3:0] <=
		       (rchk_fifo_pop & !pcs_term_det) |
                       pcs_mux_term_det_c1               ? '0            :
		       (rchk_fifo_pop & pcs_term_det) |
                        pcs_mux_term_det                 ? dmux_cnt[3:0] :    
                                                           dmux_cnt[3:0] + 1'b1;

		    rchk_fifo_pop <=
		      (!rchk_fifo_pop & (dmux_cnt[3:0] == 4'd14))  |
		      (!rchk_fifo_pop & pcs_mux_term_det &  (dmux_cnt[3:0] < 4'd14)) ;
		    		    
		end // case: MODE_e'(MODE_100G)
		
		MODE_e'(MODE_200G): begin
		    dmux_cnt[4:0] <=
		       (rchk_fifo_pop & !pcs_term_det) |
                       pcs_mux_term_det_c1               ? '0            :
		       (rchk_fifo_pop & pcs_term_det) |
                        pcs_mux_term_det                 ? dmux_cnt[4:0] :    
                                                           dmux_cnt[4:0] + 1'b1;
                       
		     rchk_fifo_pop <=
		      (!rchk_fifo_pop & (dmux_cnt[4:0] == 5'd30))  |
		      (!rchk_fifo_pop & pcs_mux_term_det &  (dmux_cnt[4:0] < 5'd30)) ;
		   	    
		end // case: MODE_e'(MODE_200G)
		
		MODE_e'(MODE_400G): begin
		    dmux_cnt[5:0] <= 
                       (rchk_fifo_pop & !pcs_term_det) |
                       pcs_mux_term_det_c1               ? '0            :
		       (rchk_fifo_pop & pcs_term_det) |
                        pcs_mux_term_det                 ? dmux_cnt[5:0] :    
                                                           dmux_cnt[5:0] + 1'b1;

		    rchk_fifo_pop <=
		      (!rchk_fifo_pop & (dmux_cnt[5:0] == 6'd62))  |
		      (!rchk_fifo_pop & pcs_mux_term_det & (dmux_cnt[5:0] < 6'd62)) ;
		end // case: MODE_e'(MODE_400G)
		
		default: begin
		    dmux_cnt <= '0;
		    rchk_fifo_pop <= '0;
		end
	    endcase
	end
	
	else begin
	    dmux_cnt <= '0;
	    rchk_fifo_pop <= '0;
	end // else: !if(!pcs_empty)
	
	if (rst_reg[0]) begin
	    dmux_cnt <= '0;
	    rchk_fifo_pop <= '0;
	end
    end // always_ff @ (posedge clk)

    always_ff @(posedge clk) begin
	/*
	pcs_mux_data <= 
          (rchk_fifo_pop & (dmux_cnt == '0)) ? '0 : // note: this condition is only detected 
			                            // at eop
                                                data_wrd[dmux_cnt];
	pcs_mux_ctl  <= 
          (rchk_fifo_pop & (dmux_cnt == '0)) ? '0 : 
                                                ctl_wrd[dmux_cnt];
	 */
	pcs_mux_data <= data_wrd[dmux_cnt];
          
	pcs_mux_ctl  <= ctl_wrd[dmux_cnt];
          
	pcs_mux_vld  <= !pcs_empty;
    end

    always_ff @(posedge clk) begin
	if (pcs_mux_sop_det)
	    pcs_mux_sop_state <= '1;
	
	if (pcs_mux_term_det)
	    pcs_mux_sop_state <= '0;
	
	if (rst_reg[0])
	    pcs_mux_sop_state <= '0;
	
    end
    always_comb begin
	pcs_mux_sop_det = (pcs_mux_data[31:24] == PCS_C_START) &
			   pcs_mux_ctl[3] & pcs_mux_vld ;

	pcs_mux_term_det_array[3] = (pcs_mux_data[31:24] == PCS_C_END) &
			             pcs_mux_ctl[3] & pcs_mux_vld;

	pcs_mux_term_det_array[2] = (pcs_mux_data[23:16] == PCS_C_END) &
			            pcs_mux_ctl[2] & pcs_mux_vld;

	pcs_mux_term_det_array[1] = (pcs_mux_data[15:8] == PCS_C_END) &
			            pcs_mux_ctl[1] & pcs_mux_vld;

	pcs_mux_term_det_array[0] = (pcs_mux_data[7:0] == PCS_C_END) &
			            pcs_mux_ctl[0] & pcs_mux_vld;

	pcs_mux_term_det = |pcs_mux_term_det_array;

	case (1'b1)
	    pcs_mux_term_det_array[3]: pcs_mux_eop_bytes_vld = '0;
	    pcs_mux_term_det_array[2]: pcs_mux_eop_bytes_vld = 2'd1;
	    pcs_mux_term_det_array[1]: pcs_mux_eop_bytes_vld = 2'd2;
	    pcs_mux_term_det_array[0]: pcs_mux_eop_bytes_vld = 2'd3;
	    default                  : pcs_mux_eop_bytes_vld = '0;
	endcase
	    
    end // always_comb

    always_ff @(posedge clk) begin
	pcs_mux_data_c1 <= pcs_mux_data;
	pcs_mux_ctl_c1 <= pcs_mux_ctl;
	pcs_mux_vld_c1 <= pcs_mux_vld;
	pcs_mux_sop_det_c1 <= pcs_mux_sop_det;
	pcs_mux_sfd_det_c1 <= pcs_mux_sop_det_c1;
	pcs_mux_term_det_array_c1 <= pcs_mux_term_det_array;
	pcs_mux_term_det_c1 <= pcs_mux_term_det;
	pcs_mux_eop_bytes_vld_c1 <= pcs_mux_eop_bytes_vld;
    end // always_ff @ (posedge clk)

    always_ff @(posedge clk) begin
	crc_chk_sop <= pcs_mux_sfd_det_c1;
	
	if (pcs_mux_term_det_c1 | pcs_mux_term_det_array[3])
	    crc_chk_vld <= '0;
	else if (pcs_mux_sfd_det_c1)
	    crc_chk_vld <= '1;
	
	if (rst_reg[1])
	    crc_chk_vld <= '0;	
    end // always_ff @ (posedge clk)

    //Vivek:
    always_comb begin
	//crc_chk_eop = ((pcs_mux_term_det_array[3]) |
	//	      |(pcs_mux_term_det_array_c1[2:0]));
	crc_chk_eop = pcs_mux_term_det_array[3] | ( |pcs_mux_term_det_array_c1[2:0]);

	crc_chk_eop_bytes_vld = 
	  |pcs_mux_term_det_array_c1[2:0] ? pcs_mux_eop_bytes_vld_c1 : '0;
	
	crc_chk_data = pcs_mux_data_c1;	
    end
    
    


    crc_32_chker crc_32_chker
       (// inputs
	.clk (clk),
	.rst (rst_reg[1]),
	.i_data (crc_chk_data),
	.i_bytes_vld (crc_chk_eop_bytes_vld),
	.i_sop (crc_chk_sop),
	.i_eop (crc_chk_eop),
	.i_vld (crc_chk_vld),

	// outputs
	.crc32_ok (crc32_ok),
	.crc32_err (crc32_err)

	 );

    always_ff @(posedge clk) begin
	if (crc_chk_eop)
	    rx_sop_state <= '0;
	else if (crc_chk_sop)
	    rx_sop_state <= '1;;
	
	if (rst_reg[0])
	    rx_sop_state <= '0;	
    end // always_ff @ (posedge clk)
    
    always_ff @(posedge clk) begin
	inc_rx_sop <= crc_chk_sop;
	inc_rx_eop <= crc_chk_eop;
	inc_rx_pkt <= (crc_chk_sop & crc_chk_eop) |
		      (rx_sop_state & crc_chk_eop) ;
	
	inc_rx_miss_sop <= (crc_chk_vld & !rx_sop_state & !crc_chk_sop);
	
	inc_rx_miss_eop <= (crc_chk_vld & rx_sop_state & crc_chk_sop);
    end

    
    
endmodule // rchk


    

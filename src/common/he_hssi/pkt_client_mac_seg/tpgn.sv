// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT



`default_nettype none
module tpgn
    import gdr_pkt_pkg::*;
    
   (
    input  var logic clk,
    input  var logic rst,
    //----------------------------------------------------------------------------------------
    // config interfae
    input  var MODE_e cfg_mode, // 0: 10/25G (8B)
                                // 1: 40/50G (16B)
                                // 2: 100G   (32B)
                                // 3: 200G   (64B)
                                // 4: 400G   (128B)
    input  var PKT_LEN_MODE_e cfg_pkt_len_mode, // 0: fix pkt_len, 
                                                // 1: inc pkt len start from 64B
                                                // 2: random pkt len start from 64B
    input  var DAT_PAT_MODE_e cfg_pkt_pattern_mod, // 0: fix pattern data base on 
                                                   //      cfg_fix_pattern
                                                   // 1: inc patten
                                                   // 2: random pattern
    input  var logic [10:0] cfg_fix_pkt_len, // this define as pkt_len - 4.
    input  var logic [7:0] cfg_fix_pattern,
    input  var logic [12:0] cfg_no_of_pkt_gen, // maximum number of generated pkt. care must
                                          //  be taken when cfg_pkt_len_mode = 1 or 2.
                                          //  Maximum setting is 8191 for 64B pkt
    input  var logic [7:0] cfg_no_of_inc_bytes, // Number of incremental bytes to be used in
                                            //  used when cfg_pkt_len_mode=1
    input  var logic cfg_start_pkt_gen,
    input  var logic cfg_cont_xfer_mode, // 1: enable continuous xfer mode. keep replay
                                         //     the xfer buffer until cfg_start_xfer_pkt
                                         //     deasserted.
                                         // 0: enable number pkt xfer mode. stop xfer pkt
                                         //     when number of tx pkt reaches 
                                         //     cfg_no_of_xfer_pkt
    input  var logic cfg_dyn_pkt_gen, // 1: enable dynamic packet generation
                                      //    if (cfg_cont_xfer_mode==1)
                                      //       tx pkt until cfg_start_pkt_gen is deasserted
                                      //    if (cfg_cont_xfer_mode==0)
                                      //       tx pkt until (tx_pkt_cnt == cfg_no_of_xfer_pkt) 
                                      // 0: disable dynamic packet generation
    input  var logic cfg_sw_gen_pkt, // indicates sw generated pkt
    input  var logic [GEN_MEM_ADDR-1:0] cfg_last_mem_addr,
    //----------------------------------------------------------------------------------------

    //----------------------------------------------------------------------------------------
    // tcsr interface
    output var logic cfg_pkt_gen_done,
    //----------------------------------------------------------------------------------------
    
    //----------------------------------------------------------------------------------------
    // tpcs interface
    output var logic [GEN_MEM_ADDR-1:0] last_mem_addr,
    //----------------------------------------------------------------------------------------

    //----------------------------------------------------------------------------------------
    // tmem interface
    output var GEN_MEM_WR_s gen_pkt_mem
    //----------------------------------------------------------------------------------------
    
    );
    
    logic [15:0] rst_reg;
    // Generate arrays of reset to be used in submodule
    always_ff @(posedge clk) begin
	rst_reg <= '{default:rst};
    end
    
    logic sop, preamble, eop, fcs_cyc, gen_pkt_cyc, crc_en, fcs_sop, gen_fcs_cyc,
	  i_sop, i_eop, i_vld, o_crc32_vld, gen_sop, gen_eop, gen_vld, gen_terminate,
	  gen_sop_c1, gen_eop_c1, gen_fcs_cyc_c1, gen_terminate_c1, gen_vld_c1,
	  gen_vld_c2, gen_terminate_c2, gen_sop_c2, cfg_start_pkt_gen_c1, start_pkt_gen_pls,
	  gen_addr_cnt_en_c2, cyc_stall_en, cyc_stall_done, gen_pkt_data_sop,
	  gen_pkt_data_terminate, inc_sop_cnt, inc_term_cnt;

    logic [1:0] eop_bytes_vld, i_bytes_vld, gen_bytes_vld, gen_bytes_vld_c1;

    logic [3:0] gen_ctl_c2;

    logic [4:0] cyc_stall_cnt;
    
    logic [10:0] rnd_pkt_len, gen_pkt_len, gen_inc_pkt_len, gen_tot_pkt_len,
		 tot_pkt_len_fix, gen_pkt_len_c2, fix_pkt_len, fix_pkt_len_nofcs_pre,
		 tot_pkt_len_inc, tot_pkt_len_rnd;
    
    logic [11:0] gen_inc_pkt_len_sum;
    
    logic [8:0]  no_of_xfer, no_of_xfer_at_eop; // base on 32b granularity
    
    logic [8:0]  cyc_cnt, byte_id_cnt, gen_cyc_cnt_c2;
    
    logic [12:0] gen_pkt_cnt, gen_pkt_cnt_c2, gen_addr_cnt_c2;

    logic [15:0] gen_wr_en;
    
    logic [31:0] o_crc32;
    
    logic [63:0] gen_pkt_data_mem_wr;
    
    logic [3:0] [7:0] data_pattern, inc_data_pattern, fix_data_pattern, rnd_pattern,
		      gen_data, gen_data_c1, gen_data_c2 ;


    GEN_PKT_DATA_s gen_pkt_data;
    GEN_PKT_DATA_s [63:0] gen_pkt_data_c;
    DWORD_128_s   mem_data;

    logic [3:0] gen_pkt_ctl;
    logic [3:0] [7:0] gen_pkt_data_wrd;    
    logic gen_pkt_sop;
    logic gen_pkt_eop;
    logic gen_pkt_vld;
    logic [8:0] gen_pkt_cyc_cnt;
    logic gen_pkt_mem_adddr_en;
    logic [12:0] gen_pkt_mem_adddr;
    DWORD_128_s  gen_pkt_mem_wdata;
    logic 	 gen_pkt_mem_sop, gen_pkt_mem_term;
    logic [12:0] gen_pkt_no_of_pkt;
    

   

    
    always_ff @(posedge clk) begin
	if (fcs_cyc) begin
	    case (cfg_pkt_len_mode)
		// fix pkt len
		PKT_LEN_MODE_e'(FIX_PKT_LEN): begin
		    // pkt_len without fcs
		    gen_pkt_len <= cfg_fix_pkt_len;

		    // eop bytes_vld
		    eop_bytes_vld <= cfg_fix_pkt_len[1:0];
		    
		    no_of_xfer        <= tot_pkt_len_fix[10:2] + |tot_pkt_len_fix[1:0];
		    no_of_xfer_at_eop <= (tot_pkt_len_fix[10:2] + |tot_pkt_len_fix[1:0]) - 1'b1;
		end
		// increment pkt_len
		PKT_LEN_MODE_e'(INC_PKT_LEN): begin
		    // pkt_len without fcs
		    gen_pkt_len <= gen_inc_pkt_len;

		    // eop bytes_vld
		    eop_bytes_vld <= gen_inc_pkt_len[1:0];
		    
		    no_of_xfer        <= tot_pkt_len_inc[10:2] + |tot_pkt_len_inc[1:0];
		    no_of_xfer_at_eop <= (tot_pkt_len_inc[10:2] + |tot_pkt_len_inc[1:0]) - 1'b1;
		end
		// random pkt_len
		PKT_LEN_MODE_e'(RND_PKT_LEN): begin
		    // pkt_len without fcs
		    gen_pkt_len <= rnd_pkt_len ;

		    // eop bytes_vld
		    eop_bytes_vld <= rnd_pkt_len[1:0];
		    
		    no_of_xfer        <= tot_pkt_len_rnd[10:2] + |tot_pkt_len_rnd[1:0];
		    no_of_xfer_at_eop <= (tot_pkt_len_rnd[10:2] + |tot_pkt_len_rnd[1:0]) - 1'b1;
		    
		end // case: 2'd2

		default: begin
		    // pkt_len without fcs
		    gen_pkt_len <= cfg_fix_pkt_len;

		    // eop bytes_vld
		    eop_bytes_vld <= '0;

		    no_of_xfer        <= tot_pkt_len_fix[10:2] + |tot_pkt_len_fix[1:0];
		    no_of_xfer_at_eop <= (tot_pkt_len_fix[10:2] + |tot_pkt_len_fix[1:0]) - 1'b1;
		end

	    endcase // case (cfg_pkt_len_mode)
	end

	// load first pkt gen
	if (start_pkt_gen_pls) begin
	    gen_pkt_len     <= cfg_fix_pkt_len;
	    eop_bytes_vld   <= cfg_fix_pkt_len[1:0];

	    no_of_xfer        <= tot_pkt_len_fix[10:2] + |tot_pkt_len_fix[1:0];
	    no_of_xfer_at_eop <= (tot_pkt_len_fix[10:2] + |tot_pkt_len_fix[1:0]) - 1'b1;
	end
	    
	if (rst_reg[3]) 
	    gen_pkt_len <= 'd60;

	if (rst_reg[5])
	    eop_bytes_vld <= '0;

	if (rst_reg[6]) begin
	    no_of_xfer        <= 'd0;
	    no_of_xfer_at_eop <= 'd0;
	end
	
    end

    always_comb begin
	// pkt_len with no fcs + preamble
	tot_pkt_len_fix = cfg_fix_pkt_len + PREAMBLE_LEN - 3'd4;

	// total increment pkt len
	tot_pkt_len_inc = gen_inc_pkt_len + PREAMBLE_LEN - 3'd4;

	// total random pkt len
	tot_pkt_len_rnd = rnd_pkt_len + PREAMBLE_LEN - 3'd4;
	
    end

    /*
    always_ff @(posedge clk) begin
	if (fcs_cyc) begin
	    no_of_xfer        <= gen_tot_pkt_len[10:2] + |gen_tot_pkt_len[1:0];
	    no_of_xfer_at_eop <= (gen_tot_pkt_len[10:2] + |gen_tot_pkt_len[1:0]) - 1'b1;
	end

	if (start_pkt_gen_pls) begin
	    no_of_xfer        <= tot_pkt_len_fix[10:2] + |tot_pkt_len_fix[1:0];
	    no_of_xfer_at_eop <= tot_pkt_len_fix[10:2] + |tot_pkt_len_fix[1:0] - 1'b1;	    
	end
	
	if (rst_reg[4]) begin
	    no_of_xfer        <= 'd0;
	    no_of_xfer_at_eop <= 'd0;
	end
	
    end // always_ff @ (posedge clk)
    */
    
    always_ff @(posedge clk) begin
	cfg_start_pkt_gen_c1 <= cfg_start_pkt_gen;	
    end

    always_comb begin
	// start pkt generation
	start_pkt_gen_pls = cfg_start_pkt_gen & !cfg_start_pkt_gen_c1;
    end

    // Generate pkt cycle enable
    always_ff @(posedge clk) begin
	// clear gen_pkt_cyc when done generating pkt
	if (cfg_pkt_gen_done |
	    eop              |
	    cyc_stall_en        )
	    gen_pkt_cyc <= '0;
	// Generate pkt cycle enable if not done packet generation
	else if (!cfg_sw_gen_pkt & cfg_start_pkt_gen & !cfg_pkt_gen_done)
	    gen_pkt_cyc <= '1;
	
	//else if (eop | gen_eop | gen_fcs_cyc | gen_terminate | cyc_stall_en)
	//    gen_pkt_cyc <= '0;
       		
	if (rst_reg[0])
	    gen_pkt_cyc <= '0;	
    end // always_ff @ (posedge clk)
    
    // pkt generation cyc_cnt
    always_ff @(posedge clk) begin
	if (gen_pkt_cyc & (cyc_cnt == no_of_xfer))
	    cyc_cnt <= '0;
	else if (gen_pkt_cyc)
	    cyc_cnt <= cyc_cnt + 1'b1;
	
	if (rst_reg[1])
	    cyc_cnt <= '0;
    end

    // stall cycles between each packet generation
    always_ff @(posedge clk) begin
	if (cyc_stall_done)
	    cyc_stall_en <= '0;
	else if (eop)
	    cyc_stall_en <= '1;

	if (rst_reg[2])
	    cyc_stall_en <= '0;	
    end // always_ff @ (posedge clk)

    // in between packet generation cycle count
    always_ff @(posedge clk) begin
	if (cyc_stall_en & (cyc_stall_cnt != 5'h1f) )
	    cyc_stall_cnt <= cyc_stall_cnt + 1'b1;
	else 
	    cyc_stall_cnt <= '0;
	
	if (rst_reg[3])
	    cyc_stall_cnt <= '0;

	// in between packet generation cycle done
	cyc_stall_done <= cyc_stall_en & (cyc_stall_cnt == 5'd16);
    end // always_ff @ (posedge clk)

        
    // Packet generation is done
    always_ff @(posedge clk) begin
	if (cfg_cont_xfer_mode) begin
	    if (gen_pkt_mem_term & !cfg_start_pkt_gen)
		cfg_pkt_gen_done <= '1;
	    else if (cfg_start_pkt_gen)
		cfg_pkt_gen_done <= '0;
	end

	else begin
	    if (!cfg_start_pkt_gen)
		cfg_pkt_gen_done <= '0;
	    else if ( (gen_pkt_mem_term & (gen_pkt_no_of_pkt  == cfg_no_of_pkt_gen))
		     |(cfg_start_pkt_gen & cfg_sw_gen_pkt) )
		cfg_pkt_gen_done <= '1;
	end


	if (rst_reg[4])
	    cfg_pkt_gen_done <= '0;
    end // always_ff @ (posedge clk)

    // capture last generated mem address
    always_ff @(posedge clk) begin
	if (cfg_dyn_pkt_gen) begin
	    if (gen_pkt_mem_term)
		last_mem_addr <= gen_pkt_mem_adddr + 1'b1;
	end
	else begin
	    if (gen_pkt_mem_term)
		last_mem_addr <= gen_pkt_mem_adddr;
	    
	    if (cfg_sw_gen_pkt)
		last_mem_addr <= cfg_last_mem_addr;
	end // else: !if(cfg_dyn_pkt_gen)
	
	if (rst_reg[0])
	    last_mem_addr <= '0;
    end

    always_ff @(posedge clk) begin
	// sop cycle
	sop <= (cyc_cnt == '0) & gen_pkt_cyc;

	// preamble cycle
	preamble <= sop;

	// sop for crc gen
	fcs_sop <= preamble;
	
	// eop without fcs
	eop <= (cyc_cnt == no_of_xfer_at_eop) & gen_pkt_cyc;

	// fcs cycle
	fcs_cyc <= eop;               

        // crc generation cycle count
	byte_id_cnt <= cyc_cnt[8:0] - 2'd1;	    
    end // always_ff @ (posedge clk)

    // FCS cyc_en
    always_ff @(posedge clk) begin
	// start fcs calculation
	if (preamble)
	    crc_en <= '1;
	// stop fcs calculation when eop is detected
	else if (eop)
	    crc_en <= '0;

	if (rst_reg[5])
	    crc_en <= '0;
    end // always_ff @ (posedge clk)

    always_comb begin
	// increment data pattern
	
	
	inc_data_pattern[3] = {6'd0, byte_id_cnt[8:7]};
	inc_data_pattern[2] = {byte_id_cnt[6:0], 1'b0};
	inc_data_pattern[1] = {6'd0, byte_id_cnt[8:7]};
	inc_data_pattern[0] = {byte_id_cnt[6:0], 1'b1};

	// fix data pattern
	fix_data_pattern = {cfg_fix_pattern,
		            cfg_fix_pattern,
		            cfg_fix_pattern,
                            cfg_fix_pattern };

	// random data patter
	rnd_pattern = o_crc32;
    end // always_comb
    
    // generate pkt pattern
    always_ff @(posedge clk) begin
	case (cfg_pkt_pattern_mod)
	    // inc pattern
	    DAT_PAT_MODE_e'(INC_DAT_PAT): data_pattern    <= inc_data_pattern;
	    // random patter
	    DAT_PAT_MODE_e'(RND_DAT_PAT): data_pattern    <= rnd_pattern;
	    // fix pattern
	    default: data_pattern <= fix_data_pattern;
	endcase // case (cfg_pkt_pattern_mod)
    end

    // Generate rdn pkt len    
    always_ff @(posedge clk) begin
	rnd_pkt_len <= 
          (o_crc32[10:0] > 11'd2000) ? 11'd2000 :
	  (o_crc32[10:0] <= 11'd64) ?  11'd64   :		       	       
                                       {o_crc32[10:0]} ;

	if (rst_reg[1])
	    rnd_pkt_len <= 11'h5a5;	
    end // always_ff @ (posedge clk)

    // generate incremental pkt len
    always_comb begin
	gen_inc_pkt_len_sum = gen_inc_pkt_len + cfg_no_of_inc_bytes;
    end
    
    always_ff @(posedge clk) begin
	if (eop)
	    gen_inc_pkt_len <= 
               gen_inc_pkt_len_sum[11] ? 11'd2000 :
                                         gen_inc_pkt_len + cfg_no_of_inc_bytes;   

	if (start_pkt_gen_pls)
	    gen_inc_pkt_len <= cfg_fix_pkt_len;
	
	if (rst_reg[2])
	    gen_inc_pkt_len <= 'd60;	
    end // always_ff @ (posedge clk)
    
    // writes the constructed pkt data to memory
    always_comb begin
	gen_pkt_mem.sop       = gen_pkt_mem_sop;
	gen_pkt_mem.terminate = gen_pkt_mem_term;
	gen_pkt_mem.mem_addr  = gen_pkt_mem_adddr;
	gen_pkt_mem.mem_wr    = gen_pkt_mem_adddr_en;
	gen_pkt_mem.mem_data  = gen_pkt_mem_wdata;
	
    end // always_comb
    
    fcs_pkt fcs_pkt
       (.clk  (clk),
	.rst  (rst_reg[6]),
	.cfg_mode (cfg_mode),
	.start_pkt_gen_pls (start_pkt_gen_pls),
	.preamble_vld (sop),
	.sfd_vld (preamble),
	.i_data (data_pattern),
	.i_bytes_vld (eop_bytes_vld),
	.i_sop (fcs_sop),
	.i_eop (eop),
	.i_vld (crc_en),

	.o_data (gen_pkt_data_wrd),
	.o_ctl (gen_pkt_ctl),
	.o_sop (gen_pkt_sop),
	.o_eop (gen_pkt_eop),
	.o_vld (gen_pkt_vld),
	.o_cyc_cnt (gen_pkt_cyc_cnt),
	.o_mem_addr_en (gen_pkt_mem_adddr_en),
	.o_mem_addr (gen_pkt_mem_adddr),
	.o_mem_wdata (gen_pkt_mem_wdata),
	.o_mem_sop (gen_pkt_mem_sop),
	.o_mem_term (gen_pkt_mem_term),
	.o_gen_pkt_cnt (gen_pkt_no_of_pkt),
	.o_crc32 (o_crc32)
	 );
    
    
endmodule

// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`default_nettype none
module tpcs
    import gdr_pkt_pkg::*;
    
   (
    input  var logic clk,
    input  var logic rst,

    input  var MODE_e cfg_mode, // 0: 10/25G (8B)
                                // 1: 40/50G (16B)
                                // 2: 100G   (32B)
                                // 3: 200G   (64B)
                                // 4: 400G   (128B)
    input  var logic [15:0] cfg_no_of_xfer_pkt, // number of pkt to be tx

    input  var logic cfg_cont_xfer_mode, // 1: enable continuous xfer mode. keep replay
                                         //     the xfer buffer until cfg_start_xfer_pkt
                                         //     deasserted.
                                         // 0: enable number pkt xfer mode. stop xfer pkt
                                         //     when number of tx pkt reaches 
                                         //     cfg_no_of_xfer_pkt
    input  var logic cfg_start_pkt_gen,
    input  var logic cfg_dyn_pkt_gen, // 1: enable dynamic packet generation
                                      //    if (cfg_cont_xfer_mode==1)
                                      //       tx pkt until cfg_start_pkt_gen is deasserted
                                      //    if (cfg_cont_xfer_mode==0)
                                      //       tx pkt until (tx_pkt_cnt == cfg_no_of_xfer_pkt) 
                                      // 0: disable dynamic packet generation
    input  var logic [7:0] cfg_ipg_dly, // indicates number ipg delay cycles
    
    input  var logic cfg_start_xfer_pkt, // 1: start tx pkt
                                         // 0: stop tx pkt
    
        
    input  var logic cfg_rx_2_tx_loopbk, // 1: enable rx_2_tx loopback
                                         // 0: normal operation
    
    input  var logic cfg_pkt_gen_done,
    input  var logic [gdr_pkt_pkg::GEN_MEM_ADDR-1:0] last_mem_addr, // This has dual function:
                                           //   if (cfg_dyn_pkt_gen == 1)
                                           //      last_mem_addr indicates as wr_ptr. tpgn
                                           //      updates everytime terminate wr cycle
                                           //   if (cfg_dyn_pkt_gen == 0)
                                           //      last_mem_addr indicates as the last wr_ptr
                                           //      of the pkt_gen memory
    
    output var logic gen_pkt_mem_rd,
    output var logic [gdr_pkt_pkg::GEN_MEM_ADDR-1:0] gen_pkt_mem_raddr,

    input  var GEN_MEM_RD_RSP_s gen_pkt_mem_rdata,
    
    output var logic xfer_pkt_done,
    output var logic cfg_pkt_xfer_done,
    
    output var logic inc_sop_cnt,
    output var logic inc_term_cnt, 
    output var logic inc_pkt_cnt,
    
    //input  var logic tx_mii_ready,
    input  var logic tscr_rdy,
    output var logic tpcs_tscr_pref_push,

    output var PCS_D_32_WRD_s tpcs_tscr_d,
    output var PCS_C_32_WRD_s tpcs_tscr_c,
    output var logic tpcs_tscr_vld,

    input  var PCS_D_32_WRD_s rpcs_tpcs_d,
    input  var PCS_C_32_WRD_s rpcs_tpcs_c,
    input  var logic rpcs_tpcs_vld
   
    );

    logic [15:0] rst_reg;
    
    // Generate arrays of reset to be used in submodule
    always_ff @(posedge clk) begin
	rst_reg <= '{default:rst };
    end
    
    logic  cfg_pkt_gen_done_clkf, start_xfer_c1, start_xfer_c2, 
	   start_xfer_c3_clkf, start_xfer_pls, ftch_cyc,
	   last_mem_det, gen_pkt_mem_rdata_vld, o_full, o_empty, gen_pkt_mem_pop,
	   tx_mii_rdy_c1, tx_mii_rdy_c2, tx_mii_rdy_c3, tx_mii_rdy_c4, tx_mii_rdy_c5,
	   tx_mii_rdy_c6, tx_mii_rdy_c7, tx_mii_rdy_c8, tx_mii_rdy_c9, tx_mii_rdy_c10,
	   am_ins_cyc, am_ins_cyc_done, clr_am_ins_cnt, cfg_rx_2_tx_loopbk_clkf,
	   sop, terminate, tx_rdy,  ipg_cyc_done, ipg_cyc_en,
	   rdy_2_pop, tx_mii_data_vld, inc_pref_cnt, dec_pref_cnt, pref_full,
	   tx_mii_rdy_dly, gen_pkt_mem_push, rx_mii_data_vld_lb, cfg_cont_xfer_mode_clkf,
	   inc_sop_cnt_c1, inc_term_cnt_c1, sop_state, rx_mii_sop_lb, rx_mii_term_lb,
	   pkt_state;
    
    logic [3:0]  o_cnt, pref_cnt;
    
    logic [3:0]  mii_rdy_2_vld_clkf, cfg_am_ins_cyc_clkf, am_ins_cyc_cnt;

    logic [7:0]  ipg_cyc_cnt, cfg_ipg_dly_clkf;

    logic [9:0] tx_mii_rdy_dly_array;
    
    logic [15:0] cfg_no_of_xfer_pkt_clkf, tx_pkt_cnt;
    
    logic [16:0] am_ins_cnt, cfg_am_ins_period_clkf;
    
    logic [12:0]  mem_raddr;

    logic [63:0] ipg_cyc_en_array, rdy_2_pop_array, sop_det_array, term_det_array;
    
    GEN_MEM_RD_RSP_s o_mem_rdata, gen_pkt_mem_wdata;
    logic [GEN_MEM_ADDR-1:0] last_mem_addr_c1;
    
    DWORD_128_s tx_mii_data, rx_mii_data_lb, rpcs_tpcs_lb;
    		 
    always_ff @(posedge clk) begin
	last_mem_addr_c1 <= last_mem_addr;
	
	start_xfer_c1 <= cfg_start_xfer_pkt;
	start_xfer_c2 <= start_xfer_c1;

	// start to pkt xfer
	start_xfer_pls <= !start_xfer_c2 & start_xfer_c1;	
    end

    always_ff @(posedge clk) begin
	// fetching cycle from pkt_mem is done
	if (xfer_pkt_done | !start_xfer_c2)
	    ftch_cyc <= '0;
	// fetching cycle from pkt_mem
	else if (start_xfer_pls)
	    ftch_cyc <= '1;
	
	if (rst_reg[0])
	    ftch_cyc <= '0;
    end // always_ff @ (posedge clkf)

    always_comb begin
	// last fetch memory address is detected
	last_mem_det = (mem_raddr == last_mem_addr_c1) & ftch_cyc & !pref_full;	
    end
    
    always_ff @(posedge clk) begin
	if (cfg_dyn_pkt_gen) begin
	    if (  (mem_raddr != last_mem_addr_c1) 
                & cfg_start_pkt_gen
                & !pref_full                       )
		mem_raddr <= mem_raddr + 1'b1;
	end
	else begin
	    // reset mem_address when last mem address is detected
	    if (last_mem_det) 
		mem_raddr <= '0;
	    // fetch mem_addr
	    else if (ftch_cyc & !pref_full)
		mem_raddr <= mem_raddr + 1'b1;
	    
	    // reset mem_address when detects start_xfer_pls
	    if (start_xfer_pls)
		mem_raddr <= '0;
	end // else: !if(cfg_dyn_pkt_gen)
	
	if (rst_reg[1])
	    mem_raddr <= '0;	
    end

    always_comb begin
	pref_full = pref_cnt > 4'd5;
	
	// fetch interface to pkt_memory
	gen_pkt_mem_rd    = 
           cfg_dyn_pkt_gen   ?   (mem_raddr != last_mem_addr_c1) 
                                & cfg_start_pkt_gen 
                                & !pref_full                    :
                                  ftch_cyc & !pref_full             ;
	gen_pkt_mem_raddr = mem_raddr;

	//inc_pref_cnt = ftch_cyc & !pref_full;
        inc_pref_cnt = gen_pkt_mem_rd;
	dec_pref_cnt = gen_pkt_mem_pop;
    end

    // keep tracks of pref fifo occupancy
    always_ff @(posedge clk) begin
	if (inc_pref_cnt & !dec_pref_cnt)
	    pref_cnt <= pref_cnt + 1'b1;
	else if (!inc_pref_cnt & dec_pref_cnt)
	    pref_cnt <= pref_cnt - 1'b1;
	
	if (rst_reg[0])
	    pref_cnt <= '0;	
    end
         
    pipe #(.W(1), .N(3) ) rd_pipe_dly
	(.clk (clk),
	 .dIn (gen_pkt_mem_rd),

	 .dOut (gen_pkt_mem_rdata_vld)
	 );

    // Generate wr interface to pref fifo
    always_ff @(posedge clk) begin
	if (cfg_rx_2_tx_loopbk) begin
	    gen_pkt_mem_wdata.mem_data  <= rx_mii_data_lb;
	    gen_pkt_mem_wdata.sop       <= rx_mii_sop_lb;
	    gen_pkt_mem_wdata.terminate <= rx_mii_term_lb;
	    gen_pkt_mem_push            <= rx_mii_data_vld_lb;
	    
	end
	else begin
	    gen_pkt_mem_push <= gen_pkt_mem_rdata_vld;
	    gen_pkt_mem_wdata <= gen_pkt_mem_rdata;
	end
    end
    
    // Prefetch buffer for tx_mii interface
    fifo_ff_8dp #(.DW(GEN_MEM_RD_RSP_WD) ) tpc_pref_fifo
       (// inputs
	.clk (clk),
	.reset (rst_reg[1]),
	.push (gen_pkt_mem_push ),
	.pop (gen_pkt_mem_pop),
	.dIn (gen_pkt_mem_wdata),

	// outputs
	.dOut (o_mem_rdata),
	.full (o_full),
	.empty (o_empty),
	.cnt (o_cnt)
	);

    always_comb begin
	// sop detection
	sop = o_mem_rdata.sop & gen_pkt_mem_pop;
	// terminate detection
	terminate = o_mem_rdata.terminate & gen_pkt_mem_pop;

	tpcs_tscr_pref_push = gen_pkt_mem_pop;
    end

    always_ff @(posedge clk) begin
	// increment sop counter
	inc_sop_cnt  <= sop;
	// increment eop counter
	inc_term_cnt <= terminate;

	inc_pkt_cnt <= (sop & terminate) |
		       (sop_state & terminate);
	
    end // always_ff @ (posedge clk)

    always_ff @(posedge clk) begin
	if (terminate)
	    sop_state <= '0;
	else if (sop)
	    sop_state <= '1;
	
	if (rst_reg[0])
	    sop_state <= '0;	
    end

    
    // count number of tx pkt
    always_ff @(posedge clk) begin
	if (terminate)
	    tx_pkt_cnt <= tx_pkt_cnt + 1'b1;

	if (!cfg_start_xfer_pkt)
	    tx_pkt_cnt <= '0;
	
	if (rst_reg[0])
	    tx_pkt_cnt <= '0;
    end // always_ff @ (posedge clk)

    always_ff @(posedge clk) begin
	// tx pkt is done
	if ( (tx_pkt_cnt == cfg_no_of_xfer_pkt) & terminate)
	    xfer_pkt_done <= '1;

	if (!cfg_start_xfer_pkt | cfg_cont_xfer_mode)
	    xfer_pkt_done <= '0;
	
	if (rst_reg[0])
	    xfer_pkt_done <= '0;	
    end // always_ff @ (posedge clk)

    always_comb begin
	cfg_pkt_xfer_done = xfer_pkt_done;
    end
    
    always_ff @(posedge clk) begin
	// start ipg cycle
	if (terminate) begin
	    ipg_cyc_en <= '1;
	    ipg_cyc_en_array <= '1;
	end
	
	// ipg cyc is done
	if (ipg_cyc_done) begin
	    ipg_cyc_en <= '0;
	    ipg_cyc_en_array <= '0;
	end
	
	if (rst_reg[0]) begin
	    ipg_cyc_en <= '0;
	    ipg_cyc_en_array <= '0;
	end
    end // always_ff @ (posedge clk)

    always_ff @(posedge clk) begin
	// ipg cycle
	if (ipg_cyc_en)
	    ipg_cyc_cnt <= ipg_cyc_cnt + 1'b1;

	// clr ipg_cyc_cnt when ipg cycle is done
	if (ipg_cyc_done)
	    ipg_cyc_cnt <= '0;
	
	if (rst_reg[0])
	    ipg_cyc_cnt <= '0;
    end // always_ff @ (posedge clk)

    always_ff @(posedge clk) begin
	// ipg cycle is done
	ipg_cyc_done <= ipg_cyc_cnt == cfg_ipg_dly ;
    end

    /*
    always_ff @(posedge clk) begin
	// ready to pop pref fifo
	rdy_2_pop        <=  tscr_rdy & !xfer_pkt_done & !o_empty;
	rdy_2_pop_array  <= {64{tscr_rdy & !xfer_pkt_done & !o_empty}};
    end */ 
    
    always_comb begin
	// ready to pop pref fifo
	rdy_2_pop        =  tscr_rdy & !xfer_pkt_done & !o_empty;
	rdy_2_pop_array  = {64{tscr_rdy & !xfer_pkt_done & !o_empty}};
    end // always_ff @ (posedge clk)
    
    always_comb begin
	// pop pref fio
	gen_pkt_mem_pop = rdy_2_pop & !ipg_cyc_en;	
    end

    always_ff @(posedge clk) begin
	if (gen_pkt_mem_pop & o_mem_rdata.terminate)
	    pkt_state <= '0;
	else if (gen_pkt_mem_pop & o_mem_rdata.sop)
	    pkt_state <= '1;
	if (rst_reg[0])
	    pkt_state <= '0;	
    end
    
    // interface to tscr module
    always_ff @(posedge clk) begin
	for (int i = 0; i < 64; i ++) begin
	    if (ipg_cyc_en_array[i]) begin
		tx_mii_data.data[i].data <= PCS_IDLE_DATA;
		tx_mii_data.data[i].ctl  <= '1;
		
	    end
	    else if (rdy_2_pop_array[i]) begin
		tx_mii_data.data[i].data <= o_mem_rdata.mem_data.data[i].data;
		tx_mii_data.data[i].ctl  <= o_mem_rdata.mem_data.data[i].ctl;		
	    end
	    else begin
		tx_mii_data.data[i].data <= PCS_IDLE_DATA;
		tx_mii_data.data[i].ctl  <= '1;
	    end
	    
	end // for (int i = 0; i < 64; i ++)
	tx_mii_data_vld <= !tscr_rdy                ? 1'b0 :
                           (rdy_2_pop | ipg_cyc_en) ? 1'b1 :
                                                      tscr_rdy & !pkt_state  ;

	if (rst_reg[0])
	    tx_mii_data_vld <= '0;
    end

    always_comb begin
	for (int i = 0; i < 32; i ++) begin
	    tpcs_tscr_d.data[i] = {tx_mii_data.data[(i*2)  ].data,
			           tx_mii_data.data[(i*2)+1].data };
	    
	    tpcs_tscr_c.ctl[i] = {tx_mii_data.data[(i*2)  ].ctl,
			          tx_mii_data.data[(i*2)+1].ctl  };
	end
	tpcs_tscr_vld  = tx_mii_data_vld;		
    end 
   
    // loop back interface
    always_comb begin
	for (int i = 0; i < 32; i++) begin
	    rpcs_tpcs_lb.data[(i*2)  ].data  = {rpcs_tpcs_d.data[i].data[7],
						   rpcs_tpcs_d.data[i].data[6],
						   rpcs_tpcs_d.data[i].data[5],
						   rpcs_tpcs_d.data[i].data[4] };
	    rpcs_tpcs_lb.data[(i*2)+1].data  = {rpcs_tpcs_d.data[i].data[3],
						   rpcs_tpcs_d.data[i].data[2],
						   rpcs_tpcs_d.data[i].data[1],
						   rpcs_tpcs_d.data[i].data[0] };
	    
	    rpcs_tpcs_lb.data[(i*2)    ].ctl  = rpcs_tpcs_c.ctl[i].ctl[7:4];
	    rpcs_tpcs_lb.data[(i*2) + 1].ctl  = rpcs_tpcs_c.ctl[i].ctl[3:0];	    
	end

	for (int p = 0; p < 64; p++) begin
	    sop_det_array[p] = (rpcs_tpcs_lb.data[p].data[31:24] == PCS_C_START) &
		               rpcs_tpcs_lb.data[p].ctl[3]          ;

	    term_det_array[p] = ((rpcs_tpcs_lb.data[p].data[31:24] == PCS_C_END) &
		                  rpcs_tpcs_lb.data[p].ctl[3]                     ) |
                                ((rpcs_tpcs_lb.data[p].data[23:16] == PCS_C_END) &
		                  rpcs_tpcs_lb.data[p].ctl[2]                     ) | 
                                ((rpcs_tpcs_lb.data[p].data[15:8] == PCS_C_END) &
		                  rpcs_tpcs_lb.data[p].ctl[1]                     ) |
                                ((rpcs_tpcs_lb.data[p].data[7:0] == PCS_C_END) &
		                  rpcs_tpcs_lb.data[p].ctl[0]                     )  ;
	end
    end
    
    always_ff @(posedge clk) begin
	
	rx_mii_data_lb     <= rpcs_tpcs_lb;
	rx_mii_sop_lb      <= |sop_det_array & rpcs_tpcs_vld;
	rx_mii_term_lb     <= |term_det_array & rpcs_tpcs_vld;
	rx_mii_data_vld_lb <= rpcs_tpcs_vld ;	
    end // always_ff @ (posedge clk)
    
endmodule // ftch_pkt_gen_clkf


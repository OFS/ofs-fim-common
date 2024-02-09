// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT



`default_nettype none
module tmem #(parameter   PARAM_RATE_OP  = 4 
                        , INIT_FILE_DATA = "init_file_data.hex"
	                , INIT_FILE_DATA_B = "init_file_data_b.hex" 
                        , INIT_FILE_CTL  = "init_file_ctrl.hex"  )
    
    
   (
    input  var logic clk,
    input  var logic rst,
    input  var gdr_pkt_pkg::GEN_MEM_WR_s gen_pkt_mem, // sync to clk

    input  var logic gen_pkt_mem_rd,
    input  var logic [gdr_pkt_pkg::GEN_MEM_ADDR-1:0] gen_pkt_mem_raddr,

    output var gdr_pkt_pkg::GEN_MEM_RD_RSP_s gen_pkt_mem_rdata,

    //----------------------------------------------------------------------------------------
    // csr interface
    input  var gdr_pkt_pkg::CFG_GEN_MEM_REQ_s cfg_mem_req,
    
    output var gdr_pkt_pkg::GEN_MEM_RD_RSP_s cfg_mem_rd_rsp,
    output var logic cfg_mem_rd_done,
    output var logic cfg_mem_wr_done,

    output var logic init_done
    );
    
    import gdr_pkt_pkg::*;
    
    GEN_MEM_WR_s pkt_mem;
    DWORD_128_s init_mem_wr_data;
    
    logic  pkt_mem_rd, cfg_rd_req_c1, cfg_rd_req_c2, cfg_rd, cfg_rd_c1, 
	   cfg_rd_pls, cfg_rd_pls_c1, cfg_rd_vld, cfg_rd_vld_c1, cfg_rd_vld_c2,
	   cfg_rd_vld_c3, cfg_rd_vld_c4, cfg_rd_pls_c2,
	   cfg_wr_req_c1, cfg_wr_req_c2, cfg_wr, cfg_wr_c1, 
	   cfg_wr_pls, cfg_wr_pls_c1, cfg_wr_pls_c2, cfg_wr_pls_c3, cfg_wr_pls_c4,
	   init_en;
    logic [12:0] pkt_mem_raddr, init_cnt;

    always_comb begin
	for (int i = 0; i < 64; i ++) begin
	    init_mem_wr_data.data[i].data = PCS_IDLE_DATA;
	    init_mem_wr_data.data[i].ctl  = '1;
	end

    end
    
    always_ff @(posedge clk) begin
	/*
	if (init_done)
	    init_en <= '0;
	
	else if (init_cnt != '1)
	    init_en <= '1;
	*/
	
	if (rst)
	    init_en <= '0;
    end

    always_ff @(posedge clk) begin
	if (init_en & (init_cnt != '1) )
	    init_cnt <= init_cnt + 1'b1;
	
	if (rst)
	    init_cnt <= '0;


	//init_done <= (init_cnt == '1);
	init_done <= '1;
	
    end
    
    //----------------------------------------------------------------------------------------
    // sync control sigs from clk_avmm
    exd_std_synchronizer #(.DW(2)) cfg_mem_sync
       (// inputs
	.clk (clk),
	.din({cfg_mem_req.mem_rd,
	      cfg_mem_req.mem_wr
	      }),
		
	// outputs
	.dout ({cfg_rd_req_c1,
		cfg_wr_req_c1
		})
	);
    
    always_ff @(posedge clk) begin
	
	cfg_rd_req_c2 <= cfg_rd_req_c1;	
       	cfg_rd_c1     <= cfg_rd_req_c2;
	
	
	cfg_wr_req_c2 <= cfg_wr_req_c1;	
	cfg_wr_c1     <= cfg_wr;
    end

    always_comb begin
	cfg_rd     = cfg_rd_req_c2 & !gen_pkt_mem_rd;
	cfg_rd_pls = !cfg_rd_c1 & cfg_rd;

	cfg_wr     = cfg_wr_req_c1 & !gen_pkt_mem.mem_wr;
	cfg_wr_pls = !cfg_wr_c1 & cfg_wr;
    end

    always_ff @(posedge clk) begin
	pkt_mem.mem_wr <= cfg_wr_pls | gen_pkt_mem.mem_wr | init_en;
	
	pkt_mem.mem_data <=
	  init_en    ?  init_mem_wr_data    :
          cfg_wr_pls ? cfg_mem_req.mem_data :
		       gen_pkt_mem.mem_data   ;
	
	pkt_mem.sop <=
	  init_en    ? '0              :
          cfg_wr_pls ? cfg_mem_req.sop :
		       gen_pkt_mem.sop   ;
	
	pkt_mem.terminate <= cfg_wr_pls ? cfg_mem_req.terminate :
				          gen_pkt_mem.terminate   ;
	
	pkt_mem.mem_addr <=
	  init_en    ? init_cnt	            :
          cfg_wr_pls ? cfg_mem_req.mem_addr :
		       gen_pkt_mem.mem_addr   ;	
    end

    always_comb begin
	pkt_mem_rd = cfg_rd_pls |gen_pkt_mem_rd;
	
	pkt_mem_raddr = cfg_rd_pls ? cfg_mem_req.mem_addr :
			             gen_pkt_mem_raddr ;
    end
    
    always_ff @(posedge clk) begin
	cfg_wr_pls_c1 <= cfg_wr_pls;
	cfg_wr_pls_c2 <= cfg_wr_pls_c1;
	cfg_wr_pls_c3 <= cfg_wr_pls_c2;
	cfg_wr_pls_c4 <= cfg_wr_pls_c3;
	cfg_mem_wr_done <= cfg_wr_pls | cfg_wr_pls_c1 | cfg_wr_pls_c2 |
			   cfg_wr_pls_c3 | cfg_wr_pls_c4;
	
	cfg_rd_pls_c1 <= cfg_rd_pls;
	cfg_rd_pls_c2 <= cfg_rd_pls_c1;
	
	cfg_rd_vld    <= cfg_rd_pls_c2;
	cfg_rd_vld_c1 <= cfg_rd_vld;
	cfg_rd_vld_c2 <= cfg_rd_vld_c1;
	cfg_rd_vld_c3 <= cfg_rd_vld_c2;
	cfg_rd_vld_c4 <= cfg_rd_vld_c3;
	 
	cfg_mem_rd_done <= cfg_rd_vld | cfg_rd_vld_c1 | cfg_rd_vld_c2 | 
                           cfg_rd_vld_c3 | cfg_rd_vld_c4;

	if (cfg_rd_vld)
	    cfg_mem_rd_rsp <= gen_pkt_mem_rdata;
    end
    
    // 8K x 256B
    gen_pkt_mem_wrap #( .PARAM_RATE_OP (PARAM_RATE_OP) 
                       ,.INIT_FILE_DATA (INIT_FILE_DATA)
		       ,.INIT_FILE_DATA_B (INIT_FILE_DATA_B)
                       ,.INIT_FILE_CTL (INIT_FILE_CTL)  ) gen_pkt_mem_wrap_0
       (
	// inputs
	.clk (clk),
	.rst (rst),
	.gen_pkt_mem (pkt_mem),
	
	.gen_pkt_mem_rd (pkt_mem_rd),
	.gen_pkt_mem_raddr (pkt_mem_raddr ),
	
	// outputs
	.gen_pkt_mem_rdata (gen_pkt_mem_rdata)

	 );
    
   //// synopsys translate_off
    /*
    always_ff @(posedge clk) begin
	if (pkt_mem.mem_wr & !init_en) begin
	    $display("Write Mem: wr_addr=0x%0h  wr_data=0x%0h", pkt_mem.mem_addr
                                                          , {pkt_mem.sop,
							     pkt_mem.terminate,
							     pkt_mem.mem_data   });

	end
    end
    // synopsys translate_on
    */



endmodule

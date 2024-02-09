// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT



`default_nettype none
module gen_pkt_mem_wrap #(parameter   PARAM_RATE_OP  = 4 
                                    , INIT_FILE_DATA   = "init_file_data.hex"
			            , INIT_FILE_DATA_B = "init_file_data_b.hex" 
                                    , INIT_FILE_CTL  = "init_file_ctrl.hex")
    
    
   (
    input  var logic clk,
    input  var logic rst,
    input  var gdr_pkt_pkg::GEN_MEM_WR_s gen_pkt_mem, 

    input  var logic gen_pkt_mem_rd,
    input  var logic [12:0] gen_pkt_mem_raddr,

    output var gdr_pkt_pkg::GEN_MEM_RD_RSP_s gen_pkt_mem_rdata
    );
    import gdr_pkt_pkg::*;
    
    typedef struct packed {
	DATA_WRD_s [63:0] data;	
    } MEM_DATA_WRD_64_s;
    localparam MEM_DATA_WRD_64_WD = $bits(MEM_DATA_WRD_64_s);
    
    typedef struct packed {
	DATA_WRD_s [31:0] data;	
    } MEM_DATA_WRD_32_s;
    localparam MEM_DATA_WRD_32_WD = $bits(MEM_DATA_WRD_32_s);
    
    typedef struct packed {
	DATA_WRD_s [15:0] data;	
    } MEM_DATA_WRD_16_s;
    localparam MEM_DATA_WRD_16_WD = $bits(MEM_DATA_WRD_16_s);
    
    typedef struct packed {
	DATA_WRD_s [7:0] data;	
    } MEM_DATA_WRD_8_s;
    localparam MEM_DATA_WRD_8_WD = $bits(MEM_DATA_WRD_8_s);

    typedef struct packed {
	DATA_WRD_s [3:0] data;	
    } MEM_DATA_WRD_4_s;
    localparam MEM_DATA_WRD_4_WD = $bits(MEM_DATA_WRD_4_s);

    typedef struct packed {
	CTL_WRD_s [63:0] ctl;	
    } MEM_CTL_WRD_64_s;
    localparam MEM_CTL_WRD_64_WD = $bits(MEM_CTL_WRD_64_s);
    
    typedef struct packed {
	CTL_WRD_s [31:0] ctl;	
    } MEM_CTL_WRD_32_s;
    localparam MEM_CTL_WRD_32_WD = $bits(MEM_CTL_WRD_32_s);
    
    typedef struct packed {
	CTL_WRD_s [15:0] ctl;	
    } MEM_CTL_WRD_16_s;
    localparam MEM_CTL_WRD_16_WD = $bits(MEM_CTL_WRD_16_s);
    
    typedef struct packed {
	CTL_WRD_s [7:0] ctl;	
    } MEM_CTL_WRD_8_s;
    localparam MEM_CTL_WRD_8_WD = $bits(MEM_CTL_WRD_8_s);

     typedef struct packed {
	CTL_WRD_s [3:0] ctl;	
    } MEM_CTL_WRD_4_s;
    localparam MEM_CTL_WRD_4_WD = $bits(MEM_CTL_WRD_4_s);
    

    MEM_DATA_WRD_64_s mem_data_64, mem_rd_data_64;
    MEM_CTL_WRD_64_s mem_ctl_64, mem_rd_ctl_64;
    logic mem_rd_terminate, mem_rd_sop;

    logic [5:0] rd_tmp;
    
    

    
    always_comb begin
	for (int i = 0; i < 64; i++) begin
	    mem_data_64.data[i].data = gen_pkt_mem.mem_data.data[i].data;
	    mem_ctl_64.ctl[i].ctl    = gen_pkt_mem.mem_data.data[i].ctl;	    
	end
    end

    always_ff @(posedge clk) begin
	for (int i = 0; i < 64; i++) begin
	    gen_pkt_mem_rdata.mem_data.data[i].data <= mem_rd_data_64.data[i].data;
	    gen_pkt_mem_rdata.mem_data.data[i].ctl  <= mem_rd_ctl_64.ctl[i].ctl;
	    gen_pkt_mem_rdata.sop                   <= mem_rd_sop;
	    gen_pkt_mem_rdata.terminate             <= mem_rd_terminate;
	end
    end


        
    generate 
	//------------------------------------------------------------------------------------
	// Generate 400G generated pkt mem
	if (PARAM_RATE_OP == 4) begin: pkt_gen_mem_400G
	    MEM_DATA_WRD_32_s gen_mem_wr_data_32_a, gen_mem_wr_data_32_b,
			      gen_mem_rd_data_32_a, gen_mem_rd_data_32_b;
	    
	    MEM_DATA_WRD_64_s gen_mem_wr_data_64, gen_mem_rd_data_64;
	    MEM_CTL_WRD_64_s gen_mem_wr_ctl_64, gen_mem_rd_ctl_64;

	    always_comb begin
		 
		for (int i = 0; i < 32; i++) begin
		    gen_mem_wr_data_32_a.data[i].data = gen_pkt_mem.mem_data.data[i].data;
		    gen_mem_wr_data_32_b.data[i].data = gen_pkt_mem.mem_data.data[32+i].data;
		end
		gen_mem_wr_data_64 = mem_data_64;
		gen_mem_wr_ctl_64  = mem_ctl_64;

		//mem_rd_data_64 = gen_mem_rd_data_64;
		mem_rd_data_64 = {gen_mem_rd_data_32_b, gen_mem_rd_data_32_a};
		
		mem_rd_ctl_64 = gen_mem_rd_ctl_64;
	    end
	    
            mem_wrapper  #(  .DW (MEM_DATA_WRD_32_WD ) 
		           , .DEPTH (GEN_MEM_DEPTH) 
                           , .INIT_FILE_DATA (INIT_FILE_DATA) ) gen_pkt_mem_data_a
		(// inputs
		 .clk (clk),
		 .wren (gen_pkt_mem.mem_wr),
		 .wdata (gen_mem_wr_data_32_a),
		 .waddr (gen_pkt_mem.mem_addr),
		 .rden (gen_pkt_mem_rd ),
		 .raddr (gen_pkt_mem_raddr),
		 
		 // outputs
		 .rdata (gen_mem_rd_data_32_a),
		 .rdata_vld ()
		 );

	    mem_wrapper  #(  .DW (MEM_DATA_WRD_32_WD ) 
		           , .DEPTH (GEN_MEM_DEPTH) 
                           , .INIT_FILE_DATA (INIT_FILE_DATA_B) ) gen_pkt_mem_data_b
		(// inputs
		 .clk (clk),
		 .wren (gen_pkt_mem.mem_wr),
		 .wdata (gen_mem_wr_data_32_b),
		 .waddr (gen_pkt_mem.mem_addr),
		 .rden (gen_pkt_mem_rd ),
		 .raddr (gen_pkt_mem_raddr),
		 
		 // outputs
		 .rdata (gen_mem_rd_data_32_b),
		 .rdata_vld ()
		 );

	    mem_wrapper  #(  .DW (  8 
                                  + MEM_CTL_WRD_64_WD) 
		           , .DEPTH (GEN_MEM_DEPTH) 
                           , .INIT_FILE_DATA (INIT_FILE_CTL)) gen_pkt_mem_ctl
		(// inputs
		 .clk (clk),
		 .wren (gen_pkt_mem.mem_wr),
		 .wdata ({  6'd0
                          , gen_pkt_mem.sop
			  , gen_pkt_mem.terminate
			  , gen_mem_wr_ctl_64
			  }),
		 .waddr (gen_pkt_mem.mem_addr),
		 .rden (gen_pkt_mem_rd ),
		 .raddr (gen_pkt_mem_raddr),
		 
		 // outputs
		 .rdata ({  rd_tmp
                          , mem_rd_sop
			  , mem_rd_terminate
			  , gen_mem_rd_ctl_64
			  }),
		 .rdata_vld ()
		 );	

	    
	    // synopsys translate_off
	    /*
	    always_ff @(posedge clk) begin
		if (gen_pkt_mem.mem_wr) begin
		    		    
		    $display("wr_addr=0x%0h ", gen_pkt_mem.mem_addr);
		    $display("wr_data_0=0x%0h ", gen_mem_wr_data_64);
		    $display("wr_data_1=0x%0h ", {    gen_pkt_mem.sop
						    , gen_pkt_mem.terminate
						    , gen_mem_wr_ctl_64
			                         });
		    
		end
	    end	  
	     */ 
	    // synopsys translate_on
	end

	//------------------------------------------------------------------------------------
	// Generate 200G generated pkt mem
	else if (PARAM_RATE_OP == 3) begin: pkt_gen_mem_200G
	    MEM_DATA_WRD_32_s gen_mem_wr_data_32, gen_mem_rd_data_32, gen_mem_data_idle_32;	    
	    MEM_CTL_WRD_32_s gen_mem_wr_ctl_32, gen_mem_rd_ctl_32, gem_mem_ctl_idle_32;
	        
	    always_comb begin
		for (int i = 0; i < 32; i++) begin
		    gen_mem_wr_data_32.data[i].data = gen_pkt_mem.mem_data.data[i].data;
		    gen_mem_wr_ctl_32.ctl[i].ctl    = gen_pkt_mem.mem_data.data[i].ctl;	    
		end	

		gen_mem_data_idle_32 = {32{PCS_IDLE_DATA}};
		gem_mem_ctl_idle_32 = '1;
	       
		mem_rd_data_64 = {gen_mem_data_idle_32, gen_mem_rd_data_32};
		mem_rd_ctl_64  = {gem_mem_ctl_idle_32, gen_mem_rd_ctl_32};
	    end
	    
            mem_wrapper  #(  .DW (   MEM_DATA_WRD_32_WD ) 
		           , .DEPTH (GEN_MEM_DEPTH) 
                           , .INIT_FILE_DATA (INIT_FILE_DATA) ) gen_pkt_mem_data_200G
		(// inputs
		 .clk (clk),
		 .wren (gen_pkt_mem.mem_wr),
		 .wdata (gen_mem_wr_data_32),
		 .waddr (gen_pkt_mem.mem_addr),
		 .rden (gen_pkt_mem_rd ),
		 .raddr (gen_pkt_mem_raddr),
		 
		 // outputs
		 .rdata (gen_mem_rd_data_32),
		 .rdata_vld ()
		 );

	    mem_wrapper  #(  .DW (  2 
                                  + MEM_CTL_WRD_32_WD) 
		           , .DEPTH (GEN_MEM_DEPTH) 
                           , .INIT_FILE_DATA (INIT_FILE_CTL) ) gen_pkt_mem_ctl_200G
		(// inputs
		 .clk (clk),
		 .wren (gen_pkt_mem.mem_wr),
		 .wdata ({  gen_pkt_mem.sop
			  , gen_pkt_mem.terminate
			  , gen_mem_wr_ctl_32
			  }),
		 .waddr (gen_pkt_mem.mem_addr),
		 .rden (gen_pkt_mem_rd ),
		 .raddr (gen_pkt_mem_raddr),
		 
		 // outputs
		 .rdata ({  mem_rd_sop
			  , mem_rd_terminate
			  , gen_mem_rd_ctl_32
			  }),
		 .rdata_vld ()
		 );
	    /*
	    // synopsys translate_off
	    always_ff @(posedge clk) begin
		if (gen_pkt_mem.mem_wr) begin		    
		    $display("wr_addr = 0x%0h ", gen_pkt_mem.mem_addr);
		    $display("wr_data_0 = 0x%0h ", gen_mem_wr_data_32);
		    $display("wr_data_1 = 0x%0h \n", {  gen_pkt_mem.sop
						    , gen_pkt_mem.terminate
						    , gen_mem_wr_ctl_32
			                         });
		    
		end
	    end	   
	    // synopsys translate_on
	     */
	end // block: pkt_gen_mem_200G
	
	//------------------------------------------------------------------------------------
	// Generate 100G generated pkt mem	
	else if (PARAM_RATE_OP == 2) begin: pkt_gen_mem_100G
	    MEM_DATA_WRD_16_s gen_mem_wr_data_16, gen_mem_rd_data_16, gen_mem_data_idle;
	    
	    MEM_CTL_WRD_16_s gen_mem_wr_ctl_16, gen_mem_rd_ctl_16, gem_mem_ctl_idle;

	    always_comb begin
		for (int i = 0; i < 16; i++) begin
		    gen_mem_wr_data_16.data[i].data = gen_pkt_mem.mem_data.data[i].data;
		    gen_mem_wr_ctl_16.ctl[i].ctl    = gen_pkt_mem.mem_data.data[i].ctl;	    
		end
		
		//gen_mem_wr_data_16 = mem_data_64[15:0];
		//gen_mem_wr_ctl_16  = mem_ctl_64[15:0];

		gen_mem_data_idle = {16{PCS_IDLE_DATA}};
		gem_mem_ctl_idle = '1;
		
		mem_rd_data_64 = {  gen_mem_data_idle
				  , gen_mem_data_idle
				  , gen_mem_data_idle  
				  , gen_mem_rd_data_16};
		
		mem_rd_ctl_64  = {  gem_mem_ctl_idle
				  , gem_mem_ctl_idle
				  , gem_mem_ctl_idle
				  , gen_mem_rd_ctl_16};
	    end
	    
            mem_wrapper  #(  .DW (MEM_DATA_WRD_16_WD ) 
		           , .DEPTH (GEN_MEM_DEPTH) 
                           , .INIT_FILE_DATA (INIT_FILE_DATA) ) gen_pkt_mem_data
		(// inputs
		 .clk (clk),
		 .wren (gen_pkt_mem.mem_wr),
		 .wdata (gen_mem_wr_data_16),
		 .waddr (gen_pkt_mem.mem_addr),
		 .rden (gen_pkt_mem_rd ),
		 .raddr (gen_pkt_mem_raddr),
		 
		 // outputs
		 .rdata (gen_mem_rd_data_16),
		 .rdata_vld ()
		 );

	    mem_wrapper  #(  .DW ( 8 
                                  + MEM_CTL_WRD_16_WD) 
		           , .DEPTH (GEN_MEM_DEPTH) 
                           , .INIT_FILE_DATA (INIT_FILE_CTL) ) gen_pkt_mem_ctl
		(// inputs
		 .clk (clk),
		 .wren (gen_pkt_mem.mem_wr),
		 .wdata ({  6'd0
                          , gen_pkt_mem.sop
			  , gen_pkt_mem.terminate
			  , gen_mem_wr_ctl_16
			  }),
		 .waddr (gen_pkt_mem.mem_addr),
		 .rden (gen_pkt_mem_rd ),
		 .raddr (gen_pkt_mem_raddr),
		 
		 // outputs
		 .rdata ({  rd_tmp
                          , mem_rd_sop
			  , mem_rd_terminate
			  , gen_mem_rd_ctl_16
			  }),
		 .rdata_vld ()
		 );
	    /*
	    // synopsys translate_off    
	    always_ff @(posedge clk) begin
		if (gen_pkt_mem.mem_wr) begin
		    $display("Write Mem:");
		    
		    $display("wr_addr=0x%0h ", gen_pkt_mem.mem_addr);
		    $display("wr_data_0=0x%0h ", gen_mem_wr_data_16);
		    $display("wr_data_1=0x%0h ", {    gen_pkt_mem.sop
						    , gen_pkt_mem.terminate
						    , gen_mem_wr_ctl_16
			                         });
		    
		end
	    end
	    // synopsys translate_on
	    */
	end // block: pkt_gen_mem_100G
	
	//------------------------------------------------------------------------------------
	// Generate 100G generated pkt mem
	else if (PARAM_RATE_OP == 1) begin: pkt_gen_mem_50G
	    MEM_DATA_WRD_8_s gen_mem_wr_data_8, gen_mem_rd_data_8, gen_mem_data_idle;
	    
	    MEM_CTL_WRD_8_s gen_mem_wr_ctl_8, gen_mem_rd_ctl_8, gem_mem_ctl_idle;

	    always_comb begin
		for (int i = 0; i < 8; i++) begin
		    gen_mem_wr_data_8.data[i].data = gen_pkt_mem.mem_data.data[i].data;
		    gen_mem_wr_ctl_8.ctl[i].ctl    = gen_pkt_mem.mem_data.data[i].ctl;	    
		end
		
		gen_mem_data_idle = {8{PCS_IDLE_DATA}};
		gem_mem_ctl_idle = '1;
		
		mem_rd_data_64 = {  gen_mem_data_idle
				  , gen_mem_data_idle
				  , gen_mem_data_idle 
                                  , gen_mem_data_idle
				  , gen_mem_data_idle
                                  , gen_mem_data_idle
				  , gen_mem_data_idle
				  , gen_mem_rd_data_8};
		
		mem_rd_ctl_64  = {  gem_mem_ctl_idle
				  , gem_mem_ctl_idle
				  , gem_mem_ctl_idle
				  , gem_mem_ctl_idle
				  , gem_mem_ctl_idle
				  , gem_mem_ctl_idle
				  , gem_mem_ctl_idle
				  , gen_mem_rd_ctl_8};
	    end
	    
            mem_wrapper  #(  .DW (MEM_DATA_WRD_8_WD ) 
		           , .DEPTH (GEN_MEM_DEPTH) 
                           , .INIT_FILE_DATA (INIT_FILE_DATA)) gen_pkt_mem_data
		(// inputs
		 .clk (clk),
		 .wren (gen_pkt_mem.mem_wr),
		 .wdata (gen_mem_wr_data_8),
		 .waddr (gen_pkt_mem.mem_addr),
		 .rden (gen_pkt_mem_rd ),
		 .raddr (gen_pkt_mem_raddr),
		 
		 // outputs
		 .rdata (gen_mem_rd_data_8),
		 .rdata_vld ()
		 );

	    mem_wrapper  #(  .DW (  2 
                                  + MEM_CTL_WRD_8_WD) 
		           , .DEPTH (GEN_MEM_DEPTH) 
                           , .INIT_FILE_DATA (INIT_FILE_CTL) ) gen_pkt_mem_ctl
		(// inputs
		 .clk (clk),
		 .wren (gen_pkt_mem.mem_wr),
		 .wdata ({  gen_pkt_mem.sop
			  , gen_pkt_mem.terminate
			  , gen_mem_wr_ctl_8
			  }),
		 .waddr (gen_pkt_mem.mem_addr),
		 .rden (gen_pkt_mem_rd ),
		 .raddr (gen_pkt_mem_raddr),
		 
		 // outputs
		 .rdata ({  mem_rd_sop
			  , mem_rd_terminate
			  , gen_mem_rd_ctl_8
			  }),
		 .rdata_vld ()
		 );
	end

	else begin: pkt_gen_mem_25G
	    MEM_DATA_WRD_4_s gen_mem_wr_data_4, gen_mem_rd_data_4, gen_mem_data_idle;
	    
	    MEM_CTL_WRD_4_s gen_mem_wr_ctl_4, gen_mem_rd_ctl_4, gem_mem_ctl_idle;

	    always_comb begin
		for (int i = 0; i < 4; i++) begin
		    gen_mem_wr_data_4.data[i].data = gen_pkt_mem.mem_data.data[i].data;
		    gen_mem_wr_ctl_4.ctl[i].ctl    = gen_pkt_mem.mem_data.data[i].ctl;	    
		end
		
		gen_mem_data_idle = {4{PCS_IDLE_DATA}};
		gem_mem_ctl_idle = '1;
		
		mem_rd_data_64 = {  gen_mem_data_idle
				  , gen_mem_data_idle
				  , gen_mem_data_idle 
                                  , gen_mem_data_idle
				  , gen_mem_data_idle
                                  , gen_mem_data_idle
				  , gen_mem_data_idle
				  , gen_mem_data_idle
				  , gen_mem_data_idle 
                                  , gen_mem_data_idle
				  , gen_mem_data_idle
                                  , gen_mem_data_idle
				  , gen_mem_data_idle
				  , gen_mem_data_idle
				  , gen_mem_data_idle 
				  , gen_mem_rd_data_4};
		
		mem_rd_ctl_64  = {  gem_mem_ctl_idle
				  , gem_mem_ctl_idle
				  , gem_mem_ctl_idle
				  , gem_mem_ctl_idle
				  , gem_mem_ctl_idle
				  , gem_mem_ctl_idle
				  , gem_mem_ctl_idle
				  , gem_mem_ctl_idle
				  , gem_mem_ctl_idle
				  , gem_mem_ctl_idle
				  , gem_mem_ctl_idle
				  , gem_mem_ctl_idle
				  , gem_mem_ctl_idle
                                  , gem_mem_ctl_idle
				  , gem_mem_ctl_idle  
				  , gen_mem_rd_ctl_4};
	    end
	    
            mem_wrapper  #(  .DW (MEM_DATA_WRD_4_WD ) 
		           , .DEPTH (GEN_MEM_DEPTH) 
                           , .INIT_FILE_DATA (INIT_FILE_DATA) ) gen_pkt_mem_data
		(// inputs
		 .clk (clk),
		 .wren (gen_pkt_mem.mem_wr),
		 .wdata (gen_mem_wr_data_4),
		 .waddr (gen_pkt_mem.mem_addr),
		 .rden (gen_pkt_mem_rd ),
		 .raddr (gen_pkt_mem_raddr),
		 
		 // outputs
		 .rdata (gen_mem_rd_data_4),
		 .rdata_vld ()
		 );

	    mem_wrapper  #(  .DW ( 2 
                                  + MEM_CTL_WRD_4_WD) 
		           , .DEPTH (GEN_MEM_DEPTH) 
                           , .INIT_FILE_DATA (INIT_FILE_CTL) ) gen_pkt_mem_ctl
		(// inputs
		 .clk (clk),
		 .wren (gen_pkt_mem.mem_wr),
		 .wdata ({  gen_pkt_mem.sop
			  , gen_pkt_mem.terminate
			  , gen_mem_wr_ctl_4
			  }),
		 .waddr (gen_pkt_mem.mem_addr),
		 .rden (gen_pkt_mem_rd ),
		 .raddr (gen_pkt_mem_raddr),
		 
		 // outputs
		 .rdata ({  mem_rd_sop
			  , mem_rd_terminate
			  , gen_mem_rd_ctl_4
			  }),
		 .rdata_vld ()
		 );
	end
    endgenerate
    

    
    /*
    mem_wrapper #(.DW (DW), .DEPTH (DEPTH)) mem_ram
	(// inputs
	 .clk  (clk),
	 .wren  (wren),
	 .wdata  (wdata[DW-1:0]),
	 .waddr  (waddr),
	 .rden  (rden),
	 .raddr  (raddr),
	 
	 // output
	 .rdata  (o_rdata[DW-1:0]),
	 .rdata_vld ()

	 );

    always_ff @(posedge clk) begin
	rdata <= o_rdata;
    end
     */


endmodule

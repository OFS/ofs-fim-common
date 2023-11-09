// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT



`default_nettype none
module fcs_pkt
   
    import gdr_pkt_pkg::*;
   (
    input  var logic clk,
    input  var logic rst,
    input  var MODE_e cfg_mode,
    input  var logic start_pkt_gen_pls,
    input  var logic preamble_vld,
    input  var logic sfd_vld,
    input  var logic [3:0] [7:0] i_data,
    input  var logic [1:0] i_bytes_vld,
    input  var logic i_sop,
    input  var logic i_eop,
    input  var logic i_vld,

    output var logic [3:0] o_ctl,
    output var logic [3:0] [7:0] o_data, 
    output var logic o_sop,
    output var logic o_eop,
    output var logic o_vld,
    output var logic [8:0] o_cyc_cnt,
    output var logic o_mem_addr_en,
    output var logic [12:0] o_mem_addr,
    output var DWORD_128_s o_mem_wdata,
    output var logic o_mem_sop,
    output var logic o_mem_term,
    output var logic [12:0] o_gen_pkt_cnt,
    output var logic [31:0] o_crc32
    );


    logic [15:0] rst_reg;
    // Generate arrays of reset to be used in submodule
    always_ff @(posedge clk) begin
	rst_reg <= '{default:rst};
    end

    logic crc32_vld_c1, crc32_vld_c2, crc32_vld_c3, 
	  preamble_vld_c1, preamble_vld_c2, sfd_vld_c1, sfd_vld_c2,
	  i_sop_c1, i_eop_c1, i_vld_c1, i_sop_c2, i_eop_c2, i_vld_c2,
	  fcs_cyc, sop_state;

    logic [1:0] i_bytes_vld_c1, i_bytes_vld_c2, i_bytes_vld_c3;
    
    logic [3:0] [7:0] crc32_c1, crc32_c2, i_data_c1, i_data_c2;

    always_ff @(posedge clk) begin
	preamble_vld_c1 <= preamble_vld;
	sfd_vld_c1 <= sfd_vld;
	
	i_data_c1 <= i_data;
	i_bytes_vld_c1 <= i_eop ? i_bytes_vld : '0 ;
	i_sop_c1 <= i_sop;
	i_eop_c1 <= i_eop;
	i_vld_c1 <= i_vld;

	preamble_vld_c2 <= preamble_vld_c1;
	sfd_vld_c2 <= sfd_vld_c1;
	
	i_data_c2 <= i_data_c1;
	i_bytes_vld_c2 <= i_bytes_vld_c1;
	i_sop_c2 <= i_sop_c1;
	i_eop_c2 <= i_eop_c1;
	i_vld_c2 <= i_vld_c1;

	i_bytes_vld_c3 <= i_bytes_vld_c2;
	crc32_vld_c2  <= crc32_vld_c1;
	crc32_vld_c3  <= crc32_vld_c2;
	crc32_c2 <= crc32_c1;
	
    end // always_ff @ (posedge clk)

    always_ff @(posedge clk) begin
	if (preamble_vld_c1) begin
	    o_data  <= PCS_SOP_DATA;
	    o_ctl   <= 4'b1000;	    
	    
	    o_sop       <= '1;
	    o_eop       <= '0;		    		    
	    o_vld       <= '1;
	end // if (preamble_vld_c1)
	else if (sfd_vld_c1) begin
	    o_data      <= PCS_PRE_DATA;
	    o_ctl       <= 4'b0000;	    
	    
	    o_sop       <= '0;
	    o_eop       <= '0;		    		    
	    o_vld       <= '1;
	end
	
	else if (i_eop_c1) begin
	    o_ctl       <= 4'b0000;
	    
	    o_sop       <= '0;
	    o_eop       <= '0;		    		    
	    o_vld       <= '1;
	    case (i_bytes_vld_c1)
		2'd1: begin
		    o_data      <= 
                      {i_data_c1[3], crc32_c1[3], crc32_c1[2], crc32_c1[1]};   
		end // case: 2'd1
		2'd2: begin
		    o_data      <= 
                      {i_data_c1[3], i_data_c1[2], crc32_c1[3], crc32_c1[2]};
		    end // case: 2'd2
		2'd3: begin
		    o_data      <= 
                      {i_data_c1[3], i_data_c1[2], i_data_c1[1], crc32_c1[3]};
		end // case: 2'd3
		default: begin
		    o_data      <= 
                      {i_data_c1[3], i_data_c1[2], i_data_c1[1], i_data_c1[0]};
		    end // case: default
	    endcase // case (i_bytes_vld_c1)
	end // if (i_eop_c1)
	else if (crc32_vld_c2) begin
	    o_sop       <= '0;
	    o_vld       <= '1;
	    case (i_bytes_vld_c2)
		2'd1: begin
		    o_data      <= 
                      {crc32_c2[0], PCS_C_END, PCS_C_IDLE, PCS_C_IDLE};
		    o_ctl       <= 4'b0111;		    
		    o_eop       <= '1;		 
		end // case: 2'd1
		2'd2: begin
		    o_data      <= 
                      {crc32_c2[1], crc32_c2[0], PCS_C_END, PCS_C_IDLE};
		    o_ctl       <= 4'b0011;
		    o_eop       <= '1;	    
		end // case: 2'd2
		2'd3: begin
		    o_data      <= 
                      {crc32_c2[2], crc32_c2[1], crc32_c2[0], PCS_C_END};
		    o_ctl       <= 4'b0001;
		    o_eop       <= '1;		    
		end // case: 2'd3
		default: begin
		    o_data      <= 
                      {crc32_c2[3], crc32_c2[2], crc32_c2[1], crc32_c2[0]};
		    o_eop       <= '0;		    		    	
		end // case: default
	    endcase
	end // if (crc32_vld_c2)
	else if (crc32_vld_c3) begin
	    if (i_bytes_vld_c3 == '0) begin
		o_data      <= PCS_TERMINATE_DATA;
		o_ctl       <= '1;
		o_sop       <= '0;
		o_eop       <= '1;
		o_vld       <= '1;
	    end // if (i_bytes_vld_c3 == '0)
	    else begin
		o_data      <= PCS_IDLE_DATA;
		o_ctl       <= '1;
		o_sop       <= '0;
		o_eop       <= '0;
		o_vld       <= '0;
	    end
	end
	else if (i_vld_c1) begin
	    o_data      <= i_data_c1;
	    o_ctl       <= '0;
	    o_sop       <= '0;
	    o_eop       <= '0;		    		    
	    o_vld       <= i_vld_c1;
	end // if (i_vld_c1)
	else begin
	    o_data      <= PCS_IDLE_DATA;
	    o_ctl       <= '1;
	    o_sop       <= '0;
	    o_eop       <= '0;
	    o_vld       <= '0;
	end
    end

    always_ff @(posedge clk) begin
	if (o_eop)
	    o_cyc_cnt <= '0;
	
	else if (o_vld)
	    o_cyc_cnt <= o_cyc_cnt + 1'b1;
		
	if (rst_reg[1])
	    o_cyc_cnt <= '0;
	
    end

     // mem write enable for generated packet
    always_ff @(posedge clk) begin
	o_mem_addr_en <= '0;
	o_mem_term <= o_eop;
	
	case (cfg_mode)
	    // 1: 40/50G (16B)
	    MODE_e'(MODE_40_50G):  begin		
		o_mem_addr_en <= ((o_cyc_cnt[2:0] == '1) & o_vld) |
				 o_eop;	

		if (o_cyc_cnt[2:0] == '0) begin
		    for (int i = 1; i < 64; i++) begin
			o_mem_wdata.data[i].data <= PCS_IDLE_DATA;
			o_mem_wdata.data[i].ctl  <= '1;
		    end
		end
		o_mem_wdata.data[o_cyc_cnt[2:0]].data <= o_data;
		o_mem_wdata.data[o_cyc_cnt[2:0]].ctl  <= o_ctl;
	    end // case: 3'd1
	    
	    // 2: 100G (32B)
	    MODE_e'(MODE_100G):  begin
		 o_mem_addr_en <= ((o_cyc_cnt[3:0] == '1) & o_vld) |
				o_eop;

		 if (o_cyc_cnt[3:0] == '0) begin
		    for (int i = 1; i < 64; i++) begin
			o_mem_wdata.data[i].data <= PCS_IDLE_DATA;
			o_mem_wdata.data[i].ctl  <= '1;
		    end
		 end // if (o_cyc_cnt[3:0] == '0)
		 o_mem_wdata.data[o_cyc_cnt[3:0]].data <= o_data;
		 o_mem_wdata.data[o_cyc_cnt[3:0]].ctl  <= o_ctl;
		 
	    end // case: 3'd1
	    
	    // 3: 200G (64B)
	    MODE_e'(MODE_200G):  begin
		 o_mem_addr_en <= ((o_cyc_cnt[4:0] == '1) & o_vld) |
		          	  o_eop;

		 if (o_cyc_cnt[4:0] == '0) begin
		    for (int i = 1; i < 64; i++) begin
			o_mem_wdata.data[i].data <= PCS_IDLE_DATA;
			o_mem_wdata.data[i].ctl  <= '1;
		    end
		 end // if (o_cyc_cnt[3:0] == '0)
		 o_mem_wdata.data[o_cyc_cnt[4:0]].data <= o_data;
		 o_mem_wdata.data[o_cyc_cnt[4:0]].ctl  <= o_ctl;
	    end // case: 3'd3
	    
	    // 4: 400G (128B)
	    MODE_e'(MODE_400G):  begin
		o_mem_addr_en <= ((o_cyc_cnt[5:0] == '1) & o_vld) |
				  o_eop;

		if (o_cyc_cnt[5:0] == '0) begin
		    for (int i = 1; i < 64; i++) begin
			o_mem_wdata.data[i].data <= PCS_IDLE_DATA;
			o_mem_wdata.data[i].ctl  <= '1;
		    end
		 end // if (o_cyc_cnt[3:0] == '0)
		 o_mem_wdata.data[o_cyc_cnt[5:0]].data <= o_data;
		 o_mem_wdata.data[o_cyc_cnt[5:0]].ctl  <= o_ctl;
	    end // case: 3'd3
	    
	    // 0: 10/25G (8B)
	    default: begin
		o_mem_addr_en <= ((o_cyc_cnt[1:0] == '1) & o_vld) |
				 o_eop;

		if (o_cyc_cnt[1:0] == '0) begin
		    for (int i = 1; i < 64; i++) begin
			o_mem_wdata.data[i].data <= PCS_IDLE_DATA;
			o_mem_wdata.data[i].ctl  <= '1;
		    end
		 end // if (o_cyc_cnt[3:0] == '0)
		 o_mem_wdata.data[o_cyc_cnt[1:0]].data <= o_data;
		 o_mem_wdata.data[o_cyc_cnt[1:0]].ctl  <= o_ctl;
	    end // case: default
	endcase // case (cfg_mode)
    end // always_comb

    always_ff @(posedge clk) begin
	if (o_mem_addr_en)
	    o_mem_addr <= o_mem_addr + 1'b1;
	
	if (rst_reg[2])
	    o_mem_addr <= '0;	
    end // always_ff @ (posedge clk)

    always_comb begin
	o_mem_sop = sop_state & o_mem_addr_en;
	
    end

    always_ff @(posedge clk) begin
	if (sop_state & o_mem_addr_en)
	    sop_state <= '0;
	else if (o_sop)
	    sop_state <= '1;
	
	if (rst_reg[3])
	    sop_state <= '0;	
    end

    always_ff @(posedge clk) begin
	if (o_sop)
	    o_gen_pkt_cnt <= o_gen_pkt_cnt + 1'b1;
	
	if (start_pkt_gen_pls)
	    o_gen_pkt_cnt <= '0;
	
	if (rst_reg[4])
	    o_gen_pkt_cnt <= '0;	
    end

    always_comb begin
	o_crc32 = crc32_c1;	
    end
    
    crc_32 crc_32
	(// inputs
	 .clk  (clk),
	 .rst  (rst_reg[0]),
	 .i_data  (i_data ),
	 .i_bytes_vld  (i_bytes_vld),
	 .i_sop  (i_sop),
	 .i_eop  (i_eop),
	 .i_vld  (i_vld),

	 // outputs
	 .o_crc32  (crc32_c1),
	 .o_crc32_vld  (crc32_vld_c1)
	 );

    
	


endmodule

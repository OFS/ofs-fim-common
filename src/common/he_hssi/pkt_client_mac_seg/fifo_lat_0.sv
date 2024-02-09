// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


//
// Prefetch 0 latency fifo
//
`default_nettype none
 module fifo_lat_0 #(parameter DEPTH=4,  parameter SKIP_RDEN   	  = 0,parameter INIT_FILE_DATA = "init_file_data.hex",DW=8) 
    (
     input var logic                    clk,
     input var logic                    reset,
     input var logic                    push,
     input var logic                    pop,
     
     input var logic [DW-1:0]           dIn,
     output logic [$clog2(DEPTH):0]     cnt,
     output logic [DW-1:0]              dOut,
     output logic                       dOutVld,
     output logic                       full,
     output logic                       empty
);

    logic [DW-1:0] rdata, rdata_pre;
    
    logic [$clog2(DEPTH)-1:0] wrPtr, rdPtr, nxtRdPtr;
    logic [$clog2(DEPTH):0]   bufCnt;
    
    logic fifoRdEn, fifoEmpty, prefFifoFull;
       
    logic prefPush , rdata_vld, wren, rden, rden_1P, rdata_vld_pre;
    
    logic [2:0]  prefPtrNxt, prefPtr, prefCnt;
    
    logic [DW-1:0] prefReg1, prefReg2, prefReg3, prefReg4, wdata;
    
    logic [$clog2(DEPTH)-1:0] waddr, raddr;

    logic [15:0] rst_reg;   
    // Generate arrays of reset to be used in submodule
    always_ff @(posedge clk) begin
	rst_reg <= '{default:reset};
    end
    
    always_comb begin
	full = (bufCnt == DEPTH);
	fifoEmpty = (bufCnt == '0);
    end
   
    always_ff @(posedge clk) begin	
	if (push)
	    wrPtr <= wrPtr + 1'b1;
	
	if (rst_reg[0])
	    wrPtr <= '0;
    end

    always_comb begin
	fifoRdEn = (!prefFifoFull & !fifoEmpty) |
                   (pop & !fifoEmpty)             ;
    end
    
    always_comb begin
	nxtRdPtr = fifoRdEn ? rdPtr + 1'b1 :
		              rdPtr          ;	
    end

    always_ff @(posedge clk) begin
	rdPtr <= nxtRdPtr;
	
	if (rst_reg[1])
	    rdPtr <= '0;	
    end
 
    always_ff @(posedge clk) begin
	if (push & !fifoRdEn)
	    bufCnt <= bufCnt + 1'b1;
	else if (!push & fifoRdEn)
	    bufCnt <= bufCnt - 1'b1;
	
	if (rst_reg[2])
	    bufCnt <= '0;
    end

    always_ff @(posedge clk) begin
	cnt <= bufCnt + prefCnt ;	
    end
     
    always_comb begin
	prefFifoFull = prefCnt >= 'd3;
	
	prefPush = rdata_vld;	
    end
    
    always_comb begin
	prefPtrNxt = (prefPush & !pop)  ? prefPtr + 1'b1 :
		     (!prefPush & pop)  ? prefPtr - 1'b1 :
                                          prefPtr          ;	
    end

    always_ff @(posedge clk) begin	
	prefPtr <= prefPtrNxt;
	
	if (rst_reg[3])
	    prefPtr <= 3'd0;
    end

    always_ff @(posedge clk) begin
	
        prefReg1 <= RegUpdate ('d1, prefPtrNxt, rdata, prefReg2, prefReg1, prefPush, pop);
	prefReg2 <= RegUpdate ('d2, prefPtrNxt, rdata, prefReg3, prefReg2, prefPush, pop);
	prefReg3 <= RegUpdate ('d3, prefPtrNxt, rdata, prefReg4, prefReg3, prefPush, pop);
	prefReg4 <= RegUpdate ('d4, prefPtrNxt, rdata, '0,       prefReg4, prefPush, pop);
	  
	if (rst_reg[4])
	    prefReg1 <= '0;

        if (rst_reg[5])
	    prefReg2 <= '0;

        if (rst_reg[6])
	    prefReg3 <= '0;

        if (rst_reg[7])
	    prefReg4 <= '0;	
    end

    always_ff @(posedge clk) begin
	if (rden & !pop)
	    prefCnt <= prefCnt + 1'b1;
	else if (!rden & pop)
	    prefCnt <= prefCnt - 1'b1;
	
	if (rst_reg[8])
	    prefCnt <= '0;	
    end
    
    always_comb begin
	wdata = dIn;
	waddr = wrPtr;
	wren  = push;

	raddr = rdPtr;
	rden  = fifoRdEn;
	
	dOut  = prefReg1;
	
	dOutVld = prefPtr != 3'd0;
	empty   = prefPtr == 3'd0;
	
    end

    always_ff @(posedge clk) begin
	//rdata     <= rdata_pre;
	
	rden_1P   <= rden;	
	rdata_vld <= rden_1P ;	
    end

    mem_wrapper #(.DW    (DW),
                  .DEPTH (DEPTH),
		  .SKIP_RDEN (SKIP_RDEN),
		  .INIT_FILE_DATA (INIT_FILE_DATA),
		  .OUTREG ("ON")) mem_wrapper
	(

	 // Clk
        .clk             (clk),
        
        //------------------------------------------------------------------------------------
        // Normal data path
        // Inputs
        .wren            (wren),
        .wdata           (wdata),
        .waddr           (waddr),  
        .rden            (rden),
        .raddr           (raddr),
	
	// Outputs
        .rdata           (rdata),
        .rdata_vld       ()        
	 );

    function [DW-1:0] RegUpdate;
	input [1:0]    myAddr;
	input [1:0]    wrAddr;
	
	input [DW-1:0] wrData;
	input [DW-1:0] rdData;
	input [DW-1:0] nxtData;
	
	input          wrEn;
	input          rdEn;
	
	begin
	    if (wrEn & (myAddr == wrAddr))
		RegUpdate = wrData;
	    else if (rdEn)
		RegUpdate = rdData;
	    else
		RegUpdate = nxtData;
	end
    endfunction // 

	
endmodule




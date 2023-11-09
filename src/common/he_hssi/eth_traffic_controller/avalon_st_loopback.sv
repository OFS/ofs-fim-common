// Copyright (C) 2001-2018 Intel Corporation
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
// Functional Description:
// This module is the top level of the Avalon ST Loopback Mux
//-------------------------------------------------------------------------------

module avalon_st_loopback #(
   parameter	amm_addr_width = 8,
   parameter	amm_data_width = 32,	
   parameter	ast_data_width = 64,	
   parameter	ast_empty_width = 3,	
   parameter	ast_rx_error_width = 6,	
   parameter	sc_fifo_depth = 2048
)(
   input              		        clk,             // TX FIFO Interface clock
   input              			reset,           // Reset signal
   input       [amm_addr_width-1:0]  	address,         // Register Address
   input              			write,           // Register Write Strobe
   input              			read,            // Register Read Strobe
   output wire        			waitrequest,  
   input       [amm_data_width-1:0] 	writedata,       // Register Write Data
   output wire [amm_data_width-1:0] 	readdata,        // Register Read Data

   //To 10G MAC Avalon ST                  	
   input                 		from_mac_tx_ready,  // Avalon-ST Ready Input
   output reg  [ast_data_width-1:0] 	to_mac_tx_data,     // Avalon-ST TX Data
   output reg         	        	to_mac_tx_valid,    // Avalon-ST TX Valid
   output reg         	        	to_mac_tx_sop,      // Avalon-ST TX StartOfPacket
   output reg         	        	to_mac_tx_eop,      // Avalon-ST TX EndOfPacket
   output reg  [ast_empty_width-1:0]    to_mac_tx_empty,    // Avalon-ST TX Empty
   output reg           		to_mac_tx_error,    // Avalon-ST TX Error
   
   //From 10G MAC Avalon ST                	
   input       [ast_data_width-1:0]	from_mac_rx_data,           
   input       				from_mac_rx_valid,          
   input       				from_mac_rx_sop,            
   input       				from_mac_rx_eop,            
   input       [ast_empty_width-1:0]	from_mac_rx_empty,          
   input       [ast_rx_error_width-1:0]	from_mac_rx_error,          
   output reg  				to_mac_rx_ready,          
   
   //From Gen Avalon ST
   output reg				to_gen_tx_ready,
   input       [ast_data_width-1:0]	from_gen_tx_data,
   input				from_gen_tx_valid,
   input				from_gen_tx_sop,
   input				from_gen_tx_eop,
   input       [ast_empty_width-1:0]	from_gen_tx_empty,
   input				from_gen_tx_error,

   //To Mon Avalon ST                      	
   output reg  [ast_data_width-1:0]	to_mon_rx_data,
   output reg  				to_mon_rx_valid,
   output reg  				to_mon_rx_sop,
   output reg  				to_mon_rx_eop,
   output reg  [ast_empty_width-1:0]	to_mon_rx_empty,
   output reg  [ast_rx_error_width-1:0]	to_mon_rx_error,
   input				from_mon_rx_ready
);

wire				avalon_st_loopback_ena;
wire	[ast_data_width-1:0]	sc_fifo_out_data;
wire				sc_fifo_out_valid;
wire				sc_fifo_in_ready;
wire				sc_fifo_out_sop;
wire				sc_fifo_out_eop;
wire	[ast_empty_width-1:0]	sc_fifo_out_empty;
wire				sc_fifo_out_error;	

wire				waitrequest_loopback_ena,waitrequest_sc_fifo;
wire	[amm_data_width-1:0]	readdata_loopback_ena, readdata_sc_fifo;

wire				sc_fifo_almost_full;
wire				sc_fifo_almost_empty;

wire  blk_sel_loopback_ena 	= (address[amm_addr_width-1] == 1'b0);
wire  blk_sel_sc_fifo 		= (address[amm_addr_width-1] == 1'b1);

assign waitrequest = blk_sel_loopback_ena? waitrequest_loopback_ena : waitrequest_sc_fifo;
assign readdata = blk_sel_loopback_ena? readdata_loopback_ena : readdata_sc_fifo;

// ____________________________________________________________________________    	
// Avalon ST Loopback CSR Register Map
// ____________________________________________________________________________
avalon_st_loopback_csr #(
   .amm_addr_width (4),
   .amm_data_width (32)
) avalon_st_loopback_ena_csr_inst
(
   .clk		           (clk),            
   .reset	           (reset),           
   .address	           (address[3:0]),	         
   .write	           (write & blk_sel_loopback_ena),          
   .read	           (read & blk_sel_loopback_ena),            
   .waitrequest            (waitrequest_loopback_ena),  
   .writedata	           (writedata),       
   .readdata	           (readdata_loopback_ena),	        
   .avalon_st_loopback_ena (avalon_st_loopback_ena),
   .sc_fifo_aempty	   (sc_fifo_almost_empty),
   .sc_fifo_afull	   (sc_fifo_almost_full)	          
);   	


// ____________________________________________________________________________
// Register Mux 
// ____________________________________________________________________________
always @(*) begin
   if (avalon_st_loopback_ena) begin
      to_mac_tx_data	  = sc_fifo_out_data;
      to_mac_tx_valid   = sc_fifo_out_valid; 
      to_mac_tx_sop     = sc_fifo_out_sop;
      to_mac_tx_eop     = sc_fifo_out_eop;
      to_mac_tx_empty   = sc_fifo_out_empty;
      to_mac_tx_error   = sc_fifo_out_error;
      to_gen_tx_ready	  = 1'b0;
   end else begin
      to_mac_tx_data	  = from_gen_tx_data;
      to_mac_tx_valid   = from_gen_tx_valid; 
      to_mac_tx_sop     = from_gen_tx_sop;
      to_mac_tx_eop     = from_gen_tx_eop;
      to_mac_tx_empty   = from_gen_tx_empty;
      to_mac_tx_error   = from_gen_tx_error;
      to_gen_tx_ready	  = from_mac_tx_ready;
   end
end 	

always @(*) begin
   if (avalon_st_loopback_ena) begin
      to_mon_rx_data	  = {ast_data_width{1'b0}};
      to_mon_rx_valid   = 1'b0; 
      to_mon_rx_sop     = 1'b0;
      to_mon_rx_eop     = 1'b0;
      to_mon_rx_empty   = {ast_empty_width{1'b0}};
      to_mon_rx_error   = {ast_rx_error_width{1'b0}};
      to_mac_rx_ready	  = sc_fifo_in_ready;
   end else begin
      to_mon_rx_data	  = from_mac_rx_data;
      to_mon_rx_valid   = from_mac_rx_valid; 
      to_mon_rx_sop     = from_mac_rx_sop;
      to_mon_rx_eop     = from_mac_rx_eop;
      to_mon_rx_empty   = from_mac_rx_empty;
      to_mon_rx_error   = from_mac_rx_error;
      to_mac_rx_ready	  = from_mon_rx_ready;
   end
end  	

//jier
sc_fifo_tx_sc_fifo #(
   .SYMBOLS_PER_BEAT    (ast_data_width/8),
   .BITS_PER_SYMBOL     (8),
   .FIFO_DEPTH          (sc_fifo_depth),	//jier set to 2048 x 8 = 16K that can support maximum Ethernet frame length 9600 bytes	
   .CHANNEL_WIDTH       (0),
   .ERROR_WIDTH         (1),
   .USE_PACKETS         (1),
   .USE_FILL_LEVEL      (1),
   .EMPTY_LATENCY       (3),
   .USE_MEMORY_BLOCKS   (1),
   .USE_STORE_FORWARD   (1),
   .USE_ALMOST_FULL_IF  (1),
   .USE_ALMOST_EMPTY_IF (1)
) tx_sc_fifo (
   .clk               		(clk),                                              
   .reset             		(reset),                      
   .csr_address       		(address[2:0]),   
   .csr_read          		(read & blk_sel_sc_fifo),      
   .csr_write         		(write & blk_sel_sc_fifo),     	
   .csr_readdata      		(readdata_sc_fifo),  
   .csr_writedata     		(writedata),
   .in_data           		(from_mac_rx_data),                                      
   .in_valid          		(from_mac_rx_valid & avalon_st_loopback_ena),                                     
   .in_ready          		(sc_fifo_in_ready),                                     
   .in_startofpacket  		(from_mac_rx_sop),                             
   .in_endofpacket    		(from_mac_rx_eop),                               
   .in_empty          		(from_mac_rx_empty),                                     
   .in_error          		(|from_mac_rx_error),                                     
   .out_data          		(sc_fifo_out_data),                                     
   .out_valid         		(sc_fifo_out_valid),                                    
   .out_ready         		(from_mac_tx_ready),                                    
   .out_startofpacket 		(sc_fifo_out_sop),                            
   .out_endofpacket   		(sc_fifo_out_eop),                              
   .out_empty         		(sc_fifo_out_empty),                                    
   .out_error         		(sc_fifo_out_error),                                    
   .almost_full_data  		(sc_fifo_almost_full),                                                        
   .almost_empty_data 		(sc_fifo_almost_empty)                                                        
);

// ____________________________________________________________________________
// Waitrequest for SCFIFO CSR interface
// ____________________________________________________________________________
   reg rddly, wrdly;
   always@(posedge clk or posedge reset)
   begin
      if(reset) 
      begin 
         wrdly <= 1'b0; 
         rddly <= 1'b0; 
      end 
      else 
      begin 
         wrdly <= write & blk_sel_sc_fifo; 
         rddly <= read & blk_sel_sc_fifo; 
      end 
   end
  
   wire wredge = write& ~wrdly;
   wire rdedge = read & ~rddly;

   assign waitrequest_sc_fifo = (wredge|rdedge); // your design is done with transaction when this goes down


endmodule	

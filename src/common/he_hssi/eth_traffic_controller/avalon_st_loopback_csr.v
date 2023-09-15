// Copyright (C) 2001-2018 Intel Corporation
// SPDX-License-Identifier: MIT

module avalon_st_loopback_csr
	#(
	parameter	amm_addr_width = 4,
	parameter	amm_data_width = 32	
	)
	(
	input                 						clk,             // TX FIFO Interface clock
	input                 						reset,           // Reset signal
	input          [amm_addr_width-1:0]  		address,         // Register Address
	input                 						write,           // Register Write Strobe
	input                 						read,            // Register Read Strobe
	output wire           						waitrequest,  
	input          [amm_data_width-1:0] 		writedata,       // Register Write Data
	output reg     [amm_data_width-1:0] 		readdata,        // Register Read Data    
	
	output reg									avalon_st_loopback_ena,	//avst loopback enable signal  
	input										sc_fifo_aempty,         
	input										sc_fifo_afull 
);

localparam	AVALON_ST_LB_ENA = 4'h0;
localparam	SC_FIFO_STATUS = 4'h1;

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
	      wrdly <= write; 
	      rddly <= read; 
	 end 
end

wire wredge = write& ~wrdly;
wire rdedge = read & ~rddly;

assign waitrequest = (wredge|rdedge); // your design is done with transaction when this goes down

// ____________________________________________________________________________
// Avalon ST Loopback Enable Register
// ____________________________________________________________________________
always @ (posedge reset or posedge clk)
	if (reset) 
      avalon_st_loopback_ena <= 1'b0;
    else if (write & address == AVALON_ST_LB_ENA) 
    	avalon_st_loopback_ena <= writedata[0];
    	
// ____________________________________________________________________________    	
// Output MUX of registers into readdata bus
// ____________________________________________________________________________
always@(posedge clk or posedge reset)
begin
	if(reset) begin 
		readdata <= 32'h0;
	end
   	else if (read) begin
    	case (address)
         	AVALON_ST_LB_ENA: readdata <= {31'd0, avalon_st_loopback_ena};
         	SC_FIFO_STATUS: readdata <= {{amm_data_width-2{1'b0}} ,sc_fifo_aempty, sc_fifo_afull};
         	default: readdata <=32'h0;
      	endcase
   	end
end    	

endmodule

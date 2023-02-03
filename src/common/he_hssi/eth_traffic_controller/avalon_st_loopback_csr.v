// (C) 2001-2018 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


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
      `ifdef INCLUDE_CVL
    	avalon_st_loopback_ena <= 1'b1;
      `else
    	avalon_st_loopback_ena <= 1'b0;
      `endif
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
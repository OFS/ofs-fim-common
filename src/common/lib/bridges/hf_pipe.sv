// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// HyperFlex-compatible Pipeline
//-----------------------------------------------------------------------------

module	hf_pipe
	# (
		parameter	WIDTH =		1,
		parameter	DEPTH =		1
	)
(
	input	wire				clk,
	
	input	wire	[WIDTH-1:0]	Din,
	output	logic	[WIDTH-1:0]	Qout
);
	
		logic	[WIDTH-1:0]	Q [0:DEPTH-1];	
// If 0 DEPTH, generate a passthrough
generate
if ( DEPTH == 0 )
begin
	// Output assignment
	always_comb
	begin
		Qout = Din;
	end
end

// Else, generate an array WIDTH x DEPTH
else
begin	
	// Declarations
		//logic	[WIDTH-1:0]	Q [0:DEPTH-1];	
	integer	i, j;
	
	// Output assignment
	always_comb
	begin
		for ( i = 0 ; i < WIDTH ; i = i + 1 )
			Qout[i]			<= Q[0][i];
	end

	// HyperFlex does not support asynchronous clear
	always_ff @ ( posedge clk )
	begin
		for ( j = 0 ; j < DEPTH ; j = j + 1 )
		begin
			// If last 'j', shift in Din
			if ( j + 1 >= DEPTH )
				Q[j]			<= Din;
				
			// Else, left-shift Q
			else
				Q[j]			<= Q[j+1];
		end
	end
end
endgenerate

endmodule

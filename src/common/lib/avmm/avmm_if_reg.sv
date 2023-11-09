// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// Register AVMM SR <--> PR interface signals
//-----------------------------------------------------------------------------

module avmm_if_reg
#(
	parameter	TX_WIDTH	= 512,		// Tx: Master -> Slave
	parameter	RX_WIDTH	= 512		// Rx: Slave -> Master
)
(
	input	logic					clk,
	
	input	logic					i_reset_n,
	output	logic					o_reset_n,
	
	input	logic					i_s0_waitrequest,
	input	logic [RX_WIDTH-1:0]	i_s0_pck_Rx,
	output	logic [TX_WIDTH-1:0]	o_s0_pck_Tx,
	
	output	logic					o_m0_waitrequest,
	output	logic [RX_WIDTH-1:0]	o_m0_pck_Rx,
	input	logic [TX_WIDTH-1:0]	i_m0_pck_Tx
);

	// Register Declarations
	(* preserve *)
		logic					i_reset_n_q = 1'b0;
	(* preserve *)
		logic					i_s0_waitrequest_q;
	(* preserve *)
		logic	[RX_WIDTH-1:0]	i_s0_pck_Rx_q;
	(* preserve *)
		logic	[TX_WIDTH-1:0]	i_m0_pck_Tx_q;
	(* preserve *)
		logic	[TX_WIDTH-1:0]	o_s0_pck_Tx_q;

	// Reset +1 -> Q
	always @ ( posedge clk )
	begin
		i_reset_n_q			<= i_reset_n;
	end

	// Reset Output
	assign o_reset_n		= i_reset_n_q;

//////////////////////////////////////////////////////////////////////////////////
	// Slave -> Master +1 -> Q
	always_ff @ ( posedge clk )
	begin
		if ( !i_reset_n )
		begin
			i_s0_waitrequest_q	<= 1'b1;
			i_s0_pck_Rx_q		<= 0;
		end
		else
		begin
			i_s0_waitrequest_q	<= i_s0_waitrequest;
			i_s0_pck_Rx_q		<= i_s0_pck_Rx;
		end
	end

	// Slave -> Master Output
	assign o_m0_waitrequest		= i_s0_waitrequest_q;
	assign o_m0_pck_Rx			= i_s0_pck_Rx_q;

//////////////////////////////////////////////////////////////////////////////////
//	clk				|	|	|	|	|	|	|	|	|	|	|	|
//						 _______	 ___	 ___
//	i_s0_waitrequest ___| 		|___| 	|___| 	|________________
//							 _______	 ___	 ___
//	o_m0_waitrequest _______|		|___|	|___| 	|____________
//
//	i_m0_pck_Tx		  A	| B	| C			| D		| E		| F	|
//
//	i_m0_pck_Tx_q		| A | B			| C		| D		| E	| F
//
//	o_s0_pck_Tx			| A 		| B		| C		| D	| E	| F
//

	// Master -> Slave +1 -> Q	
	always_ff @ ( posedge clk )
	begin
		if ( !i_reset_n )
		begin
			i_m0_pck_Tx_q			<= 0;
		end
		else
		begin
			// If waitrequest +1 == 1
				// --> Hold current i_m0_pck_Tx_q; m0 will hold i_m0_pck_Tx this clk
			if ( o_m0_waitrequest )
				i_m0_pck_Tx_q			<= i_m0_pck_Tx_q;
			
			// Else
			else
				i_m0_pck_Tx_q			<= i_m0_pck_Tx;
		end
	end

	// Master -> Slave Registered MuX
	always_ff @ ( posedge clk )
	begin
		if ( !i_reset_n )
		begin
			o_s0_pck_Tx_q			<= 0;
		end
		else
		begin
			// If waitrequest +0 == 1
				// --> Immediately hold current o_s0_pck_Tx_q; above will hold i_m0_pck_Tx_q
			if ( i_s0_waitrequest )
				o_s0_pck_Tx_q			<= o_s0_pck_Tx_q;
			
			// If waitrequest +1 == 1
				// --> Load held i_m0_pck_Tx_q to o_s0_pck_Tx_q; i_m0_pck_Tx_q may update this clk
			else
			if ( o_m0_waitrequest )
				o_s0_pck_Tx_q			<= i_m0_pck_Tx_q;
			
			// Else
			else
				o_s0_pck_Tx_q			<= i_m0_pck_Tx;
		end
	end

	// Registered MuX -> Slave Output
	assign o_s0_pck_Tx					= o_s0_pck_Tx_q;

endmodule

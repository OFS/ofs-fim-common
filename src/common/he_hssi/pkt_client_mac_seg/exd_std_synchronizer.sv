// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT




module exd_std_synchronizer #(parameter DW=8) 
    (

     input  clk,
     
     input  logic [DW-1:0] din,
     output logic [DW-1:0] dout


     );

    logic [DW-1:0] 	   din_c1, din_c2;

    always_ff @(posedge clk) begin
	din_c1 <= din;
	din_c2 <= din_c1;

	dout <= din_c2;

    end

endmodule 



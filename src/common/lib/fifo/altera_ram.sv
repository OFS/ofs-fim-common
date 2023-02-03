// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

module altera_ram  #(parameter ADDR_WIDTH = 10, DATA_WIDTH = 256)
   (
    input  wire [(ADDR_WIDTH-1):0] rdaddress,
    input  wire                    wrclock,
    input  wire [(ADDR_WIDTH-1):0] wraddress,
    input  wire                    wren,
    input  wire [(DATA_WIDTH-1):0] data,
    output wire [(DATA_WIDTH-1):0] q,
    output wire                    ram_data_invalid
    );
   
   
   reg [(DATA_WIDTH-1):0]    ram[(2**ADDR_WIDTH)-1:0];
   reg [(ADDR_WIDTH-1):0]    wraddress_r1;
   reg 			     wren_r1;
   
   always @(posedge wrclock)
     begin
        if (wren)
          begin
             ram[wraddress] <= data;
          end
	wraddress_r1 <= wraddress;
	wren_r1 <= wren;
     end
	
   assign ram_data_invalid = wren_r1 & (wraddress_r1 == rdaddress) |
			     (wren   & (wraddress    == rdaddress));

   // Note, both equations below should synthisize the same.
`ifdef X_R_W_SAME_LOC
   assign q     = ram_data_invalid ? {DATA_WIDTH{1'bx}} : ram[rdaddress];
`else
   assign q     = ram[rdaddress];
`endif

endmodule

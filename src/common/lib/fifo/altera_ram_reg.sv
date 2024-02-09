// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

module altera_ram_reg #(ADDR_WIDTH = 3, DATA_WIDTH = 1)
   (
    input  wire                    rdclock,
    input  wire [ADDR_WIDTH-1:0]   rdaddress,
    input  wire                    wrclock,
    input  wire [ADDR_WIDTH-1:0]   wraddress,
    input  wire                    wren,
    input  wire [DATA_WIDTH-1:0]   data,
    output reg [DATA_WIDTH-1:0]    q,
    output reg                     ram_data_invalid_stg1,
    output wire                    ram_data_invalid
    );
   
   wire [DATA_WIDTH-1:0]           nxt_q;
   
   altera_ram #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH))
   altera_ram (
               .rdaddress        (rdaddress),
               .wrclock          (wrclock),
               .wraddress        (wraddress),
               .wren             (wren),
               .data             (data),
               .q                (nxt_q),
               .ram_data_invalid (ram_data_invalid)
               );
   
   
   always @(posedge rdclock) begin
      q                     <= nxt_q;
      ram_data_invalid_stg1 <= ram_data_invalid;
   end
   
endmodule

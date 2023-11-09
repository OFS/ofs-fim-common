// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: MIT

module  axi4lite_mst_dummy 
        (
        input                          clk          ,
        ofs_fim_emif_axi_mm_if.master  dummy_mst_if
        );               
        reg                       bready;    /* synthesis noprune */
        reg                       bvalid;    /* synthesis noprune */
        reg [7:0]                 bid;       /* synthesis noprune */
        reg [1:0]                 bresp;     /* synthesis noprune */
        reg                       rready;    /* synthesis noprune */
        reg                       rvalid;    /* synthesis noprune */
        reg [7:0]                 rid;       /* synthesis noprune */
        reg [63:0]                rdata;     /* synthesis noprune */
        reg [1:0]                 rresp;     /* synthesis noprune */
        reg                       rlast;     /* synthesis noprune */

               
        always_comb
            begin
                dummy_mst_if.awaddr   = '0  ;
                dummy_mst_if.awprot   = '0  ;
                dummy_mst_if.awvalid  = '0  ;
                dummy_mst_if.wdata    = '0  ;
                dummy_mst_if.wstrb    = '0  ;
                dummy_mst_if.wvalid   = '0  ;
                dummy_mst_if.bready   = '0  ;
                dummy_mst_if.araddr   = '0  ;
                dummy_mst_if.arprot   = '0  ;
                dummy_mst_if.arvalid  = '0  ;
                dummy_mst_if.rready   = '0  ;
            end 
            
        always_ff @(posedge clk)
            begin
                bready   <= dummy_mst_if.bready  ;
                bvalid   <= dummy_mst_if.bvalid  ;
                bid      <= dummy_mst_if.bid     ;
                bresp    <= dummy_mst_if.bresp   ;
                rready   <= dummy_mst_if.rready  ;
                rvalid   <= dummy_mst_if.rvalid  ;
                rid      <= dummy_mst_if.rid     ;
                rdata    <= dummy_mst_if.rdata   ;
                rresp    <= dummy_mst_if.rresp   ;
                rlast    <= dummy_mst_if.rlast   ;
            end
endmodule


// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: MIT

module  axi4lite_slv_dummy 
        (
        input                       clk          ,
        input                       rst_n        ,
        ofs_fim_axi_lite_if.slave   dummy_slv_if
        );
        always_comb
            begin
                dummy_slv_if.awready         = 1; 
                dummy_slv_if.wready          = 1;
                dummy_slv_if.bresp           = 0;
                dummy_slv_if.arready         = 1;
                dummy_slv_if.rdata           = 0; 
                dummy_slv_if.rresp           = 0;
            end  
        
        always_ff @ ( posedge clk )         // DUMMY address response
            begin            
                if (dummy_slv_if.bvalid) dummy_slv_if.bvalid <= ~dummy_slv_if.bready;
                else                     dummy_slv_if.bvalid <=  dummy_slv_if.awvalid; 
                if (dummy_slv_if.rvalid) dummy_slv_if.rvalid <= ~dummy_slv_if.rready;
                else                     dummy_slv_if.rvalid <=  dummy_slv_if.arvalid; 
                
                if (!rst_n) dummy_slv_if.bvalid <= 0 ;
                if (!rst_n) dummy_slv_if.rvalid <= 0 ;
            end   
endmodule
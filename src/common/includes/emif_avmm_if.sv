// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: MIT

// External Memory AVMM Interface 

interface emif_avmm_if #(
    parameter ADDR_W  = 46,
    parameter DATA_W  = 512,
    parameter MDATA_W = 18
)
(
);
    localparam BE_W = DATA_W/8;

    logic               waitrequest;          
    logic               read;         
    logic               write;        
    logic               write_poison; 
    logic [ADDR_W-1:0]  address;         
    logic [MDATA_W-1:0] req_mdata;    
    logic [DATA_W-1:0]  readdata;       
    logic [MDATA_W-1:0] rsp_mdata;    
    logic [DATA_W-1:0]  writedata;       
    logic [BE_W-1:0]    byteenable;           
    logic               readdatavalid;
    logic               readdata_error;

    modport source (   //Entity making requests
        output read,
        output write,
        output write_poison,
        output address,
        output req_mdata,
        output writedata,
        output byteenable,
        input  waitrequest,
        input  rsp_mdata,
        input  readdata,
        input  readdatavalid,
        input  readdata_error
    );

    modport sink (    //Entity accepting requests and providing responses
        input  read,
        input  write,
        input  write_poison,
        input  address,
        input  req_mdata,
        input  writedata,
        input  byteenable,
        output waitrequest,
        output rsp_mdata,
        output readdata,
        output readdatavalid,
        output readdata_error
    );

endinterface : emif_avmm_if

// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// Definition of Avalon Streaming (AVST) interface
//
//-----------------------------------------------------------------------------

`ifndef __OFS_AVST_IF_SV__
`define __OFS_AVST_IF_SV__

interface ofs_avst_if #(
parameter DW = 512,
parameter EW = $clog2(DW/8)
);
    logic [DW-1:0]  data;
    logic           valid;
    logic           error;
    logic           sop;
    logic           eop;
    logic [EW-1:0]  empty;
    logic           ready;
   
    modport source (
        output  data,
        output  valid,
        output  error,
        output  sop,
        output  eop,
        output  empty,
        input   ready
    );

    modport sink (
        input   data,
        input   valid,
        input   error,
        input   sop,
        input   eop,
        input   empty,
        output  ready
   );

endinterface : ofs_avst_if 

`endif // __OFS_AVST_IF_SV__

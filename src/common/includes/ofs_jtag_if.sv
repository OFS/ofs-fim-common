// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// Definition of JTAG interface
//
//-----------------------------------------------------------------------------

`ifndef __OFS_JTAG_IF_SV__
`define __OFS_JTAG_IF_SV__

interface ofs_jtag_if;
    logic tms;
    logic tdi;
    logic tdo;
    logic tck;
    logic tckena;
    logic vir_tdi;
    logic reset;
    
    modport source (
        output  tms, tdi, tck, tckena, vir_tdi, reset,
        input   tdo
    );
   
   modport sink (
        output  tdo,
        input   tms, tdi, tck, tckena, vir_tdi, reset
   );

endinterface : ofs_jtag_if 

`endif // __OFS_JTAG_IF_SV__

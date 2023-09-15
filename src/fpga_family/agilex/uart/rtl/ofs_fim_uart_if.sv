// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//  Definition of UART interfaces
//
//----------------------------------------------------------------------------

`ifndef __OFS_FIM_UART_IF_SV__
`define __OFS_FIM_UART_IF_SV__

interface ofs_uart_if;
    logic cts_n;
    logic dsr_n;
    logic dcd_n;
    logic ri_n;
    logic rx;
    logic dtr_n;
    logic rts_n;
    logic out1_n;
    logic out2_n;
    logic tx;
    
    modport source (
        output dtr_n, rts_n, out1_n, out2_n, tx,
        input cts_n, dsr_n, dcd_n, ri_n, rx
    );
   
    modport sink (
        output cts_n, dsr_n, dcd_n, ri_n, rx,
        input dtr_n, rts_n, out1_n, out2_n, tx
   );
endinterface : ofs_uart_if

`endif // __OFS_FIM_UART_IF_SV__

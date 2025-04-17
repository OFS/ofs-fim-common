// Copyright (C) 2020 Intel Corporation.
// SPDX-License-Identifier: MIT

//
// Description
//-----------------------------------------------------------------------------
//
//  This file contains SystemVerilog interface definitions defining
//  EMIF/DDR4 related interfaces
//
//----------------------------------------------------------------------------

// Wires that aren't declared as part of the DDR4 interface by the memory subsystem IP.
interface ofs_fim_mem_ddr4_ref_clk_if;
    logic clk;
    logic oct_rzqin;

    modport ip (
        input clk, oct_rzqin
    );
    modport app (
        output clk, oct_rzqin
    );
endinterface

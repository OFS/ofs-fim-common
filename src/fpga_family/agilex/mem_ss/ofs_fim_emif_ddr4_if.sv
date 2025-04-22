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

// When DDR4 clock and reset are in separate interfaces from other signals they
// may be passed through this one. The Agilex 7 memory subsystem does not need
// these pins -- they are passed in the main DDR4 pins interface.

`ifdef CONFIG_AGILEX5
    // Agilex 5 DDR4 to AXI-MM IP bridge has a separate DDR4 clock interface.
    `define OFS_DDR4_PIN_IF_WITH_CLK
`endif

// Wires that aren't declared as part of the DDR4 interface by the memory subsystem IP.
interface ofs_fim_mem_ddr4_ref_clk_if;
    logic clk;
    logic oct_rzqin;

 `ifdef OFS_DDR4_PIN_IF_WITH_CLK
    logic ck_t;
    logic ck_c;
    logic reset_n;
 `endif

    modport ip (
 `ifdef OFS_DDR4_PIN_IF_WITH_CLK
        output ck_t, ck_c, reset_n,
 `endif
        input  clk, oct_rzqin
    );
    modport app (
 `ifdef OFS_DDR4_PIN_IF_WITH_CLK
        input  ck_t, ck_c, reset_n,
 `endif
        output clk, oct_rzqin
    );
endinterface

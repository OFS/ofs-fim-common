// Copyright (C) 2025 Altera Corporation.
// SPDX-License-Identifier: MIT

//
// Manage details of the system clock, mostly mapping configuration parameters
// from exported Verilog macros to local parameters.
//

`include "ofs_ip_cfg_db.vh"

package sys_pll_pkg;
    localparam NUM_CLOCKS = `IOPLL_0_PARAM_GUI_NUMBER_OF_CLOCKS;

    // Use a fixed number to avoid messy macro ifdef tests
    localparam NUM_STATIC_CLOCKS = 10;
    localparam string CLOCK_NAMES[NUM_STATIC_CLOCKS]  = {
        `IOPLL_0_PARAM_GUI_CLOCK_NAME_STRING0,
        `IOPLL_0_PARAM_GUI_CLOCK_NAME_STRING1,
        `IOPLL_0_PARAM_GUI_CLOCK_NAME_STRING2,
        `IOPLL_0_PARAM_GUI_CLOCK_NAME_STRING3,
        `IOPLL_0_PARAM_GUI_CLOCK_NAME_STRING4,
        `IOPLL_0_PARAM_GUI_CLOCK_NAME_STRING5,
        `IOPLL_0_PARAM_GUI_CLOCK_NAME_STRING6,
        `IOPLL_0_PARAM_GUI_CLOCK_NAME_STRING7,
        `IOPLL_0_PARAM_GUI_CLOCK_NAME_STRING8,
        `IOPLL_0_PARAM_GUI_CLOCK_NAME_STRING9
        };

    localparam real TGT_CLK_MHZ[NUM_STATIC_CLOCKS] = {
        `IOPLL_0_PARAM_GUI_OUTPUT_CLOCK_FREQUENCY0,
        `IOPLL_0_PARAM_GUI_OUTPUT_CLOCK_FREQUENCY1,
        `IOPLL_0_PARAM_GUI_OUTPUT_CLOCK_FREQUENCY2,
        `IOPLL_0_PARAM_GUI_OUTPUT_CLOCK_FREQUENCY3,
        `IOPLL_0_PARAM_GUI_OUTPUT_CLOCK_FREQUENCY4,
        `IOPLL_0_PARAM_GUI_OUTPUT_CLOCK_FREQUENCY5,
        `IOPLL_0_PARAM_GUI_OUTPUT_CLOCK_FREQUENCY6,
        `IOPLL_0_PARAM_GUI_OUTPUT_CLOCK_FREQUENCY7,
        `IOPLL_0_PARAM_GUI_OUTPUT_CLOCK_FREQUENCY8,
        `IOPLL_0_PARAM_GUI_OUTPUT_CLOCK_FREQUENCY9
        };

    localparam real ACTUAL_CLK_MHZ[NUM_STATIC_CLOCKS] = {
        `IOPLL_0_PARAM_GUI_ACTUAL_OUTPUT_CLOCK_FREQUENCY0,
        `IOPLL_0_PARAM_GUI_ACTUAL_OUTPUT_CLOCK_FREQUENCY1,
        `IOPLL_0_PARAM_GUI_ACTUAL_OUTPUT_CLOCK_FREQUENCY2,
        `IOPLL_0_PARAM_GUI_ACTUAL_OUTPUT_CLOCK_FREQUENCY3,
        `IOPLL_0_PARAM_GUI_ACTUAL_OUTPUT_CLOCK_FREQUENCY4,
        `IOPLL_0_PARAM_GUI_ACTUAL_OUTPUT_CLOCK_FREQUENCY5,
        `IOPLL_0_PARAM_GUI_ACTUAL_OUTPUT_CLOCK_FREQUENCY6,
        `IOPLL_0_PARAM_GUI_ACTUAL_OUTPUT_CLOCK_FREQUENCY7,
        `IOPLL_0_PARAM_GUI_ACTUAL_OUTPUT_CLOCK_FREQUENCY8,
        `IOPLL_0_PARAM_GUI_ACTUAL_OUTPUT_CLOCK_FREQUENCY9
        };

    function automatic int clock_name_to_idx(string clock_name);
        if (NUM_CLOCKS > NUM_STATIC_CLOCKS) begin
            // synthesis translate_off
            $fatal(2, " ** ERROR ** %m: NUM_CLOCKS %0d exceeds NUM_STATIC_CLOCKS %0d", NUM_CLOCKS, NUM_STATIC_CLOCKS);
            // synthesis translate_on
            return -2;
        end

        for (int i = 0; i < NUM_STATIC_CLOCKS; i++) begin
            if (CLOCK_NAMES[i] == clock_name)
                return i;
        end

        return -1;
    endfunction

    function automatic real clock_name_to_tgt_mhz(string clock_name);
        int idx = clock_name_to_idx(clock_name);
        // A compilation error with an invalid index is a sign either that the
        // clock_name is not in the list, or that NUM_CLOCKS is too large.
        // The function is called during elaboration, so it's impossible to generate
        // a meaningful error message at runtime.
        return TGT_CLK_MHZ[idx];
    endfunction

    function automatic real clock_name_to_actual_mhz(string clock_name);
        int idx = clock_name_to_idx(clock_name);
        // For errors, see comment above in clock_name_to_tgt_mhz.
        return ACTUAL_CLK_MHZ[idx];
    endfunction

endpackage

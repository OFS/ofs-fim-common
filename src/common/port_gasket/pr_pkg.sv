// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// This file contains SystemVerilog package definitions for S10 boards.
//-----------------------------------------------------------------------------

package pr_pkg;
   // Partial Reconfiguration Controller status output bus values
   parameter SW_POWERUP_NRESET_ASSERTED = 3'b000;
   parameter SW_PR_ERROR_IS_TRIGGERED = 3'b001;
   parameter SW_CRC_ERROR_IS_TRIGGERED = 3'b010;
   parameter SW_INCOMPATIBLE_BITSTREAM_ERROR_DETECTED = 3'b011;
   parameter SW_PR_OPERATION_IN_PROGRESS = 3'b100;
   parameter SW_PR_OPERATION_SUCCESSFUL = 3'b101;
   parameter SW_CONFIGURATION_SYSTEM_IS_BUSY = 3'b110;

   parameter POWERUP_NRESET_ASSERTED       = 3'b000;
   parameter CONFIGURATION_SYSTEM_IS_BUSY  = 3'b001;
   parameter PR_OPERATION_IN_PROGRESS      = 3'b010;
   parameter PR_OPERATION_SUCCESSFUL       = 3'b011;
   parameter PR_ERROR_IS_TRIGGERED         = 3'b100;
endpackage : pr_pkg




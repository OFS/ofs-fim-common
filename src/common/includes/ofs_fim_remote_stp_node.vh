// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT

//
// Instantiate a remote SignalTap, presumably in afu_main(), picking the
// appropriate idiom for the device. We assume that there will be a common
// setup for all flavors of a device.
//
// Include this file in the middle of the afu_main() module. Having a standard
// include file makes afu_main() slightly more portable, hiding differences
// in the JTAG interface.
//

// *** THIS LOGIC ASSUMES THAT remote_stp_conf_reset IS DEFINED AND SET ***
// *** BEFORE THE FILE IS INCLUDED.                                     ***

`ifndef __OFS_FIM_REMOTE_PR_STP_NODE__
`define __OFS_FIM_REMOTE_PR_STP_NODE__

// Platform-specific info, including DEVICE_FAMILY_IS_* macros.
`include "fpga_defines.vh"

`ifdef DEVICE_FAMILY_IS_S10

   `ifdef INCLUDE_REMOTE_STP
      `ifdef SIM_MODE
         assign pr2sr_tdo = 0;
      `else
         wire stp_loopback;

         sld_virtual_jtag inst_sld_virtual_jtag (
            .tdi (stp_loopback),
            .tdo (stp_loopback)
         );

         altera_sld_host_endpoint #(
            .NEGEDGE_TDO_LATCH(0),
            .USE_TCK_ENA(1)
         ) scjio (
            .tck         (sr2pr_tck),
            .tck_ena     (sr2pr_tckena),
            .tms         (sr2pr_tms),
            .tdi         (sr2pr_tdi),
            .tdo         (pr2sr_tdo),
            .vir_tdi     (sr2pr_tdi),
            .select_this (1'b1)
         );

         intel_configuration_reset_release_to_debug_logic
         intel_configuration_reset_release_to_debug_logic_inst (
            .conf_reset (remote_stp_conf_reset)
         );
      `endif // SIM_MODE
   `else
      always_ff@(posedge sr2pr_tck) begin
         pr2sr_tdo <= sr2pr_tdi;
      end
   `endif // INCLUDE_REMOTE_STP

`elsif DEVICE_FAMILY_IS_AGILEX

   `ifdef INCLUDE_REMOTE_STP
      `ifdef SIM_MODE
         assign remote_stp_jtag_if.tdo = 0;
      `else
         wire stp_loopback;

         sld_virtual_jtag inst_sld_virtual_jtag (
            .tdi (stp_loopback),
            .tdo (stp_loopback)
         );

         // Soft Core JTAG I/O IP instantiation to tap SLD nodes in the PR region
         scjio_agilex scjio_a (
            .jtag_clock_clk        (remote_stp_jtag_if.tck),
            .jtag_signals_tms      (remote_stp_jtag_if.tms),
            .jtag_signals_tdi      (remote_stp_jtag_if.tdi),
            .jtag_signals_tdo      (remote_stp_jtag_if.tdo),
            .jtag_signals_tck_ena  (remote_stp_jtag_if.tckena)
         );

         intel_configuration_reset_release_to_debug_logic
         intel_configuration_reset_release_to_debug_logic (
            .conf_reset (remote_stp_conf_reset)
         );
      `endif // SIM_MODE
   `else
      always_ff@(posedge remote_stp_jtag_if.tck) begin
         remote_stp_jtag_if.tdo <= remote_stp_jtag_if.tdi;
      end
   `endif // INCLUDE_REMOTE_STP

`else

   *** Unsupported DEVICE_FAMILY ***

`endif

`endif // __OFS_FIM_REMOTE_PR_STP_NODE__

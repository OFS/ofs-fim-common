// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: MIT

//======================
// UVM and SVT packages
//======================
`include "uvm_pkg.sv"
`include "svt_axi.uvm.pkg"
import uvm_pkg::*;
import svt_axi_uvm_pkg::*;

//==============
//   Testcases
//==============
`include "pf_vf_mux_request_sequence.sv"
`include "pf_vf_mux_master_traffic_sequence.sv"
`include "pf_vf_mux_master_traffic_wr_rd_combo_sequence.sv"
`include "pf_vf_mux_master_invalid_traffic_sequence.sv"
`include "pf_vf_mux_master_bp_sequence.sv"
`include "pf_vf_mux_master_fifo_error_sequence.sv"
`include "pf_vf_mux_master_reset_in_middle_sequence.sv"
`include "pf_vf_mux_slave_traffic_sequence.sv"
`include "pf_vf_mux_slave_traffic_wr_rd_combo_sequence.sv"
`include "pf_vf_mux_slave_simultaneous_traffic_sequence.sv"
`include "pf_vf_mux_slave_simultaneous_wr_rd_combo_sequence.sv"
`include "pf_vf_mux_slave_simultaneous_backpressure_sequence.sv"
`include "pf_vf_mux_slave_reset_in_middle_sequence.sv"
`include "pf_vf_mux_slave_fifo_error_sequence.sv"
`include "pf_vf_mux_slave_sequential_backpressure_sequence.sv"
`include "pf_vf_mux_stress_sequence.sv"
`include "pf_vf_mux_tuser_vendor_toggle_sequence.sv"

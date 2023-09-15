// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// Port CSR I/O Interface.
//
// Definition of Port CSR register block interface and modports.
//
//-----------------------------------------------------------------------------

`ifndef __PORT_CSR_IO_IF_SV__
`define __PORT_CSR_IO_IF_SV__

interface port_csr_io_if #(
   parameter CSR_REG_WIDTH = 64
);
// Register Value Inputs ------------------------------------
   logic [CSR_REG_WIDTH-1:0] inp2cr_port_control;
   logic [CSR_REG_WIDTH-1:0] inp2cr_port_status;
   logic [CSR_REG_WIDTH-1:0] inp2cr_port_error;
   logic [CSR_REG_WIDTH-1:0] inp2cr_port_malformed_req_0;
   logic [CSR_REG_WIDTH-1:0] inp2cr_port_malformed_req_1;
   logic [CSR_REG_WIDTH-1:0] inp2cr_port_debug0;
   logic [CSR_REG_WIDTH-1:0] inp2cr_port_stp_status;
   logic [CSR_REG_WIDTH-1:0] inp2cr_port_afu_status[ofs_fim_if_pkg::NUM_PORT_AFU_STATUS_CSRS];
   // Register Value Outputs -----------------------------------
   logic [CSR_REG_WIDTH-1:0] cr2out_port_control;
   logic [CSR_REG_WIDTH-1:0] cr2out_port_error;
   logic [CSR_REG_WIDTH-1:0] cr2out_port_error_mask;
   logic                     cr2out_port_error_clear;
   logic [CSR_REG_WIDTH-1:0] cr2out_port_first_error;

 
   modport port (
      input inp2cr_port_control, inp2cr_port_status, inp2cr_port_error, inp2cr_port_malformed_req_0,
            inp2cr_port_malformed_req_1, inp2cr_port_debug0, inp2cr_port_stp_status,
            inp2cr_port_afu_status,
      output cr2out_port_control, cr2out_port_error, cr2out_port_error_mask, cr2out_port_error_clear,
            cr2out_port_first_error 
   );

   
   modport tb (
      output inp2cr_port_control, inp2cr_port_status, inp2cr_port_error, inp2cr_port_malformed_req_0,
            inp2cr_port_malformed_req_1, inp2cr_port_debug0, inp2cr_port_stp_status,
            inp2cr_port_afu_status,
      input cr2out_port_control, cr2out_port_error, cr2out_port_error_mask, cr2out_port_error_clear,
            cr2out_port_first_error 
   );


endinterface : port_csr_io_if

`endif // __PORT_CSR_IO_IF_SV__

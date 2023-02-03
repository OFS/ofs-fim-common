// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// FME CSR I/O Interface.
//
// Definition of FME CSR register block interface and modports.
//
//-----------------------------------------------------------------------------

`ifndef __FME_CSR_IO_IF_SV__
`define __FME_CSR_IO_IF_SV__

interface fme_csr_io_if #(
   parameter CSR_REG_WIDTH = 64
);
// Register Value Inputs ------------------------------------
   logic [CSR_REG_WIDTH-1:0] inp2cr_fme_error;
   logic [CSR_REG_WIDTH-1:0] inp2cr_ras_grnerr;
   logic [CSR_REG_WIDTH-1:0] inp2cr_ras_bluerr;
// Register Value Outputs -----------------------------------
   logic [CSR_REG_WIDTH-1:0] cr2out_port0_offset;
   logic [CSR_REG_WIDTH-1:0] cr2out_port1_offset;
   logic [CSR_REG_WIDTH-1:0] cr2out_port2_offset;
   logic [CSR_REG_WIDTH-1:0] cr2out_port3_offset;
   logic [CSR_REG_WIDTH-1:0] cr2out_gbsErrMask;
   logic [CSR_REG_WIDTH-1:0] cr2out_ras_grnerr;
   logic [CSR_REG_WIDTH-1:0] cr2out_ras_bluerr;
   logic                     cr2out_CfgRdHit;
   logic                     cr2out_catErrInj;
   logic                     cr2out_fatErrInj;
   logic                     cr2out_warnErrInj;
   logic                     cr2out_fme_fab_err;
   logic [19:0]              cr2out_fme_sclr;
   logic [12:0]              cr2out_pcie0_sclr;
   logic                     cr2out_fat_sclr;
   logic                     cr2out_nonfat_sclr;


   modport fme (
      input inp2cr_fme_error, inp2cr_ras_grnerr, inp2cr_ras_bluerr,
      output cr2out_port0_offset, cr2out_port1_offset, cr2out_port2_offset, cr2out_port3_offset,
            cr2out_gbsErrMask,
            cr2out_ras_grnerr, cr2out_ras_bluerr,
            cr2out_CfgRdHit, 
            cr2out_catErrInj, cr2out_fatErrInj, cr2out_warnErrInj, 
            cr2out_fme_fab_err,
            cr2out_fme_sclr, cr2out_pcie0_sclr,
            cr2out_fat_sclr, cr2out_nonfat_sclr
   );

   
   modport tb (
      output inp2cr_fme_error, inp2cr_ras_grnerr, inp2cr_ras_bluerr,
      input cr2out_port0_offset, cr2out_port1_offset, cr2out_port2_offset, cr2out_port3_offset,
            cr2out_gbsErrMask,
            cr2out_ras_grnerr, cr2out_ras_bluerr,
            cr2out_CfgRdHit, 
            cr2out_catErrInj, cr2out_fatErrInj, cr2out_warnErrInj, 
            cr2out_fme_fab_err,
            cr2out_fme_sclr, cr2out_pcie0_sclr,
            cr2out_fat_sclr, cr2out_nonfat_sclr
   );

   modport ras (
      output inp2cr_ras_grnerr, inp2cr_ras_bluerr,
      input cr2out_catErrInj, cr2out_fatErrInj, cr2out_warnErrInj,
            cr2out_ras_grnerr, cr2out_ras_bluerr
   );


endinterface : fme_csr_io_if
`endif // __FME_CSR_IO_IF_SV__

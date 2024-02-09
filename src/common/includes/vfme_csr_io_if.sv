// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// vFME CSR I/O Interface.
//
// Definition of vFME CSR register block interface and modports.
//
//-----------------------------------------------------------------------------

`ifndef __VFME_CSR_IO_IF_SV__
`define __VFME_CSR_IO_IF_SV__

interface vfme_csr_io_if #(
   parameter CSR_REG_WIDTH = 64
);
// Register Value Inputs ------------------------------------
	logic [CSR_REG_WIDTH-1:0] inp2cr_msix_vpba;
// Register Value Outputs -----------------------------------
	logic [CSR_REG_WIDTH-1:0] cr2out_msix_vaddr0;
	logic [CSR_REG_WIDTH-1:0] cr2out_msix_vctldat0;
	logic [CSR_REG_WIDTH-1:0] cr2out_msix_vaddr1;
	logic [CSR_REG_WIDTH-1:0] cr2out_msix_vctldat1;
	logic [CSR_REG_WIDTH-1:0] cr2out_msix_vaddr2;
	logic [CSR_REG_WIDTH-1:0] cr2out_msix_vctldat2;
	logic [CSR_REG_WIDTH-1:0] cr2out_msix_vaddr3;
	logic [CSR_REG_WIDTH-1:0] cr2out_msix_vctldat3;
	logic [CSR_REG_WIDTH-1:0] cr2out_msix_vaddr4;
	logic [CSR_REG_WIDTH-1:0] cr2out_msix_vctldat4;
	logic [CSR_REG_WIDTH-1:0] cr2out_msix_vpba;


   modport vfme (
      input inp2cr_msix_vpba,
      output   cr2out_msix_vaddr0, cr2out_msix_vctldat0, cr2out_msix_vaddr1,
               cr2out_msix_vctldat1, cr2out_msix_vaddr2, cr2out_msix_vctldat2,
               cr2out_msix_vaddr3, cr2out_msix_vctldat3, cr2out_msix_vaddr4,
               cr2out_msix_vctldat4, cr2out_msix_vpba
   );

   
   modport tb (
      output inp2cr_msix_vpba,
      input cr2out_msix_vaddr0, cr2out_msix_vctldat0, cr2out_msix_vaddr1,
            cr2out_msix_vctldat1, cr2out_msix_vaddr2, cr2out_msix_vctldat2,
            cr2out_msix_vaddr3, cr2out_msix_vctldat3, cr2out_msix_vaddr4,
            cr2out_msix_vctldat4, cr2out_msix_vpba
   );


   modport interrupt (
      output inp2cr_msix_vpba,
      input cr2out_msix_vaddr0, cr2out_msix_vctldat0, cr2out_msix_vaddr1,
            cr2out_msix_vctldat1, cr2out_msix_vaddr2, cr2out_msix_vctldat2,
            cr2out_msix_vaddr3, cr2out_msix_vctldat3, cr2out_msix_vaddr4,
            cr2out_msix_vctldat4, cr2out_msix_vpba
   );


endinterface : vfme_csr_io_if
`endif // __VFME_CSR_IO_IF_SV__

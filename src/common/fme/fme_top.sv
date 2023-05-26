// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// Top level module of FME. All core FME features are implemented inside this module.
//
//-----------------------------------------------------------------------------

import ofs_fim_cfg_pkg::*;
import ofs_fim_if_pkg::*;
import ofs_csr_pkg::*;
import fme_csr_pkg::*;

module fme_top #(
   parameter EXT_FME_IRQ_IFS = 1,
   parameter ST2MM_MSIX_ADDR = 20'h80010,
   parameter NEXT_DFH_OFFSET = 24'h10000
)
(
   input clk,
   input rst_n,
   input pwr_good_n,
   input pr_parity_error, // Parity Error signal from Partial Reconfiguration Block

   ofs_fim_axi_lite_if.master axi_lite_m_if,
   ofs_fim_axi_lite_if.slave  axi_lite_s_if
);

ofs_fim_pwrgoodn_if pgn();
assign pgn.pwr_good_n = pwr_good_n;

//-------------------------------------
// AXI4 lite to MMIO adapter
//-------------------------------------

ofs_fim_axi_mmio_if axi_mmio_if();

axi_lite2mmio axi_lite2mmio (
.clk    (clk),
.rst_n  (rst_n),
.lite_if(axi_lite_s_if),
.mmio_if(axi_mmio_if)
);

//--------------------------------------------------------------------------------
// Drive Standard FME Inputs with reset values if not implemented in OFS version.
// For other inputs, format input with appropriate bits cleared.
//--------------------------------------------------------------------------------

fme_csr_io_if #( .CSR_REG_WIDTH(64) ) fme_io();

assign fme_io.inp2cr_fme_error[63:1]     = 'b0; // Bit0 used in PR Controller
assign fme_io.inp2cr_fme_error[0]        = pr_parity_error; // Parity Error signal from Partial Reconfiguration Block
assign fme_io.inp2cr_ras_grnerr =   {
                                       {57{1'b0}}, //.........................Bits [63:7] - Reserved
                                       fme_io.cr2out_warnErrInj, //...........Bit  [6]
                                       1'b0, //...............................Bit  [5]    - Reserved
                                       1'b0, //...............................Bit  [4]    - Reserved
                                       1'b0, //...............................Bit  [3]    - Reserved
                                       1'b0, //...............................Bit  [2]    - Reserved
                                       {2{1'b0}}  //..........................Bits [1:0]  - Reserved
                                    };
assign fme_io.inp2cr_ras_bluerr =   {
                                       // Catastrophic Errors
                                       {52{1'b0}}, //......................Bits [63:12] - Reserved
                                       fme_io.cr2out_catErrInj, //.........Bit  [11]
                                       {2{1'b0}}, //.......................Bit  [10:9]  - Reserved
                                       // Fatal Errors
                                       fme_io.cr2out_fatErrInj, //.........Bit  [8]
                                       1'b0, //............................Bit  [7]     - Reserved
                                       1'b0, //............................Bit  [6]     - Reserved
                                       {6{1'b0}}  //.......................Bits [5:0]   - Reserved
                                    };


//----------------------------
// Connect FME I/O output signals
//----------------------------
fme_csr_port_offset_t [3:0] cr2out_port_offset;

assign cr2out_port_offset[0] = fme_io.cr2out_port0_offset;
assign cr2out_port_offset[1] = fme_io.cr2out_port1_offset;
assign cr2out_port_offset[2] = fme_io.cr2out_port2_offset;
assign cr2out_port_offset[3] = fme_io.cr2out_port3_offset;

//------------------------------------------------------
// SCLR for FME RW1C and negedge detection & FME RO regs
//------------------------------------------------------
logic [19:0] cr2out_fme_sclr;
logic [12:0] cr2out_pcie0_sclr;
logic        cr2out_nonfat_sclr;
logic        cr2out_fat_sclr; 

logic        cr2out_fme_fab_err;

logic [63:0] ras2csr_grnerr;
logic [63:0] ras2csr_bluerr;
logic [63:0] c32ui_port0_offset;

logic        cr2out_caterr_inj;
logic        cr2out_faterr_inj;
logic        cr2out_warnerr_inj;
   
assign cr2out_fme_sclr     = fme_io.cr2out_fme_sclr;
assign cr2out_pcie0_sclr   = fme_io.cr2out_pcie0_sclr;
assign cr2out_nonfat_sclr  = fme_io.cr2out_nonfat_sclr;
assign cr2out_fat_sclr     = fme_io.cr2out_fat_sclr;

assign cr2out_fme_fab_err  = fme_io.cr2out_fme_fab_err;

assign ras2csr_grnerr      = fme_io.cr2out_ras_grnerr;
assign ras2csr_bluerr      = fme_io.cr2out_ras_bluerr;
assign c32ui_port0_offset  = fme_io.cr2out_port0_offset;

assign cr2out_caterr_inj   = fme_io.cr2out_catErrInj;
assign cr2out_faterr_inj   = fme_io.cr2out_fatErrInj;
assign cr2out_warnerr_inj  = fme_io.cr2out_warnErrInj;

// FME Interrupt generation logic.
logic       fme_irq;
logic       fme_sclr;

logic       fme_error_irq;
logic       fme_irq_edge;

logic [1:0] fme_irq_sync, fme_irq_pulse;

logic [6:0] fme_err_regs;  // err event registers in FME 
logic [3:0] fme_sclr_regs; 

always @(posedge clk) begin 
   if (!rst_n) begin
      fme_error_irq <= 0;
      fme_sclr      <= 0;
   end else begin
      fme_error_irq <= (|fme_err_regs) & (~|fme_sclr_regs);
      fme_sclr      <=  |fme_sclr_regs;
   end 
end

always@(posedge clk) begin
   if (!rst_n) begin
      fme_irq_sync  <= 0;
      fme_irq_pulse <= 0;
   end else begin
      fme_irq_sync  <= {fme_irq_sync[0],  fme_error_irq};
      fme_irq_pulse <= {fme_irq_pulse[0], fme_irq_edge};
   end
end 

assign fme_irq_edge = ~fme_irq_sync[1] & fme_irq_sync[0];
assign fme_irq = fme_irq_pulse[1] ^ fme_irq_pulse[0];

assign fme_sclr_regs = {|cr2out_fme_sclr, |cr2out_pcie0_sclr, cr2out_nonfat_sclr, cr2out_fat_sclr};
assign fme_err_regs  = {cr2out_fme_fab_err, //FME_ERROR0  - FME Error source
                        |1'b0,              //Unused
                        |ras2csr_bluerr,    //FAT_CAT_ERR - Fatal/Catastrophic Error (Blue Error)
                        |ras2csr_grnerr,    //NONFAT_CAT  - Non-Fatal Error (Green Error)
                        cr2out_caterr_inj,  //CATERR_INJ  - Catastrophic Error Injected
                        cr2out_faterr_inj,  //FATERR_INJ  - Fatal Error Injected
                        cr2out_warnerr_inj  //WARNERR_INJ - Warning Injected
                     };

//----------------------------
// FME IRQ sideband -> inband
//----------------------------
logic   avmm_s2m_waitrequest;

pfa_master #(
   .AVMM_ADDR_WIDTH        (21),
   .AVMM_RDATA_WIDTH       (64),
   .AVMM_WDATA_WIDTH       (64),
   .AXI4LITE_ADDR_WIDTH    (21),
   .AXI4LITE_RDATA_WIDTH   (64),
   .AXI4LITE_WDATA_WIDTH   (64)
)
pfa_master (
   .ACLK                           (clk),
   .ARESETn                        (rst_n),

   .avmm_m2s_write                 (fme_irq_edge),
   .avmm_m2s_read                  (1'b0),
   .avmm_m2s_address               (ST2MM_MSIX_ADDR),
   .avmm_m2s_writedata             (64'd6),
   .avmm_m2s_byteenable            (8'hff),

   .avmm_s2m_waitrequest           (avmm_s2m_waitrequest),
   .avmm_s2m_writeresponsevalid    (),
   .avmm_s2m_readdatavalid         (),
   .avmm_s2m_readdata              (),

   .axi4lite_s2m_AWREADY           (axi_lite_m_if.awready),
   .axi4lite_m2s_AWVALID           (axi_lite_m_if.awvalid),
   .axi4lite_m2s_AWADDR            (axi_lite_m_if.awaddr),
   .axi4lite_m2s_AWPROT            (axi_lite_m_if.awprot),

   .axi4lite_s2m_WREADY            (axi_lite_m_if.wready),
   .axi4lite_m2s_WVALID            (axi_lite_m_if.wvalid),
   .axi4lite_m2s_WDATA             (axi_lite_m_if.wdata),
   .axi4lite_m2s_WSTRB             (axi_lite_m_if.wstrb),

   .axi4lite_s2m_BVALID            (axi_lite_m_if.bvalid),
   .axi4lite_s2m_BRESP             (axi_lite_m_if.bresp),
   .axi4lite_m2s_BREADY            (axi_lite_m_if.bready),

   .axi4lite_s2m_ARREADY           (axi_lite_m_if.arready),
   .axi4lite_m2s_ARVALID           (axi_lite_m_if.arvalid),
   .axi4lite_m2s_ARADDR            (axi_lite_m_if.araddr),
   .axi4lite_m2s_ARPROT            (axi_lite_m_if.arprot),

   .axi4lite_s2m_RVALID            (axi_lite_m_if.rvalid),
   .axi4lite_s2m_RDATA             (axi_lite_m_if.rdata),
   .axi4lite_s2m_RRESP             (axi_lite_m_if.rresp),
   .axi4lite_m2s_RREADY            (axi_lite_m_if.rready)
);

//----------------------------
// FME CSR module
//----------------------------
fme_csr #(  .NEXT_DFH_OFFSET   (NEXT_DFH_OFFSET) )
fme_csr (
   .pgn  		(pgn),
   .axi        (axi_mmio_if),
   .fme_io     (fme_io)
);

endmodule

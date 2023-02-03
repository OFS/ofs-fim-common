// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// AXI-S Tx MSI-X Bridge
//-----------------------------------------------------------------------------

`include "fpga_defines.vh"

import pcie_ss_hdr_pkg::*;

module  axis_tx_msix_bridge #(
    parameter PF_NUM            = 0,
    parameter VF_NUM            = 0,
    parameter VF_ACTIVE         = 0  
)(
    input                   clk,
    input                   rst_n,
    
    pcie_ss_axis_if.source  axis_tx_if,    
    output  logic           axis_tx_error,
    
    input   logic           msix_strb,
    input   logic   [15:0]  msix_num,
    output  logic           msix_ready
);

pcie_ss_hdr_pkg::PCIe_IntrHdr_t     intr_hdr;

logic           msix_fifo_wrreq;
logic   [15:0]  msix_fifo_din;

logic           msix_fifo_rdack;
logic   [15:0]  msix_fifo_dout;

logic           msix_fifo_valid;
logic           msix_fifo_valid_next;

logic           msix_fifo_empty;
logic           msix_fifo_almostempty;
logic           msix_fifo_almostfull;

logic   [11:0]  msix_fifo_usedw;
logic   [1:0]   msix_fifo_eccstatus;

//--------------------------------------------------------
// AXIS Tx Source Interface
//--------------------------------------------------------
always_comb
begin
    axis_tx_if.tlast        = msix_fifo_valid;
    axis_tx_if.tvalid       = msix_fifo_valid;
    
    axis_tx_if.tdata        = {$bits(axis_tx_if.tdata){1'b0}};
    axis_tx_if.tdata        = intr_hdr;
    
    axis_tx_if.tkeep        = {$bits(axis_tx_if.tkeep){1'b1}};
    axis_tx_if.tuser_vendor = msix_fifo_valid ? 10'h1 : 10'h0;
    
    axis_tx_error           = msix_fifo_eccstatus[0];
end

//--------------------------------------------------------
// Construct DM_INTR Header
//--------------------------------------------------------
always_comb
begin
    intr_hdr                 = {$bits(intr_hdr){1'b0}};

    intr_hdr.pf_num          = PF_NUM;
    intr_hdr.vf_num          = VF_NUM;
    intr_hdr.vf_active       = VF_ACTIVE;

    intr_hdr.fmt_type        = DM_INTR;
    
    intr_hdr.vector_num      = msix_fifo_dout;
end

//--------------------------------------------------------
// MSIX Vector Number FIFO
//--------------------------------------------------------
always_ff @ ( posedge clk )
begin
    if ( !rst_n )
    begin
        msix_fifo_wrreq     <= 1'b0;
        msix_ready          <= 1'b0;
    end
    else
    begin
        // Construct TLP -> DIN
        msix_fifo_din       <= msix_num;
        msix_fifo_wrreq     <= msix_strb;
        msix_ready          <= ~msix_fifo_almostfull; 
    end
end

// Hold DOUT until sink capture on AVST 'ready' and 'valid'
always_comb
begin
    msix_fifo_rdack      = axis_tx_if.tready
                            && axis_tx_if.tvalid;
end

// If almost empty, deassert next valid on 'rdack', to allow empty status flag to update
always_comb
begin   
    msix_fifo_valid_next = msix_fifo_rdack      ?   !msix_fifo_almostempty :
                                                    !msix_fifo_empty;
end

// +1 delay to 'valid' to allow for 'rdack' -> DOUT latency
always_ff @ ( posedge clk )
begin
    if ( !rst_n )
    begin
        msix_fifo_valid         <= 1'b0;
    end
    else
    begin
        msix_fifo_valid         <= msix_fifo_valid_next;
    end
end

// MSIX FIFO
scfifo
msix_fifo (
    .clock          (clk),
    .sclr           (!rst_n),
    .aclr           (1'b0),
    
    .wrreq          (msix_fifo_wrreq),
    .data           (msix_fifo_din),
    
    .rdreq          (msix_fifo_rdack),
    .q              (msix_fifo_dout),
    
    .empty          (msix_fifo_empty),
    .almost_empty   (msix_fifo_almostempty),

    .full           ( ),
    .almost_full    (msix_fifo_almostfull),      // Need to add overflow backpressure logic...
    .usedw          (msix_fifo_usedw),
    
    .eccstatus      (msix_fifo_eccstatus)
);
defparam
    msix_fifo.add_ram_output_register  = "ON",
    msix_fifo.almost_empty_value  = 3,
    msix_fifo.almost_full_value  = 4080,
    msix_fifo.enable_ecc  = "TRUE",
`ifdef DEVICE_FAMILY
    msix_fifo.intended_device_family  = `DEVICE_FAMILY,
`else
    msix_fifo.intended_device_family  = "Stratix 10",
`endif
    msix_fifo.lpm_hint  = "RAM_BLOCK_TYPE=M20K",
    msix_fifo.lpm_numwords  = 4096,
    msix_fifo.lpm_showahead  = "ON",
    msix_fifo.lpm_type  = "scfifo",
    msix_fifo.lpm_width  = 16,
    msix_fifo.lpm_widthu  = 12,
    msix_fifo.overflow_checking  = "ON",
    msix_fifo.underflow_checking  = "ON",
    msix_fifo.use_eab  = "ON";

endmodule


// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// AXI-S Tx MMIO Bridge
//-----------------------------------------------------------------------------

`include "fpga_defines.vh"


module  axis_tx_mmio_bridge #(
    parameter PF_NUM            = 0,
    parameter VF_NUM            = 0,
    parameter VF_ACTIVE         = 0,
    parameter AVMM_DATA_WIDTH   = 64
)(
    input                   clk,
    input                   rst_n,
    
    pcie_ss_axis_if.source  axis_tx_if,    
    output  logic           axis_tx_error,
    
    input   logic                               avmm_s2m_readdatavalid,
    input   logic   [AVMM_DATA_WIDTH-1:0]       avmm_s2m_readdata,

    input   logic                               tlp_rd_strb,
    input   logic   [9:0]                       tlp_rd_tag,
    input   logic   [13:0]                      tlp_rd_length,
    input   logic   [15:0]                      tlp_rd_req_id,
    input   logic   [23:0]                      tlp_rd_low_addr
);

import pcie_ss_hdr_pkg::*;

pcie_ss_hdr_pkg::PCIe_PUCplHdr_t    cpl_hdr;

logic   [AVMM_DATA_WIDTH-1:0]   avmm_s2m_readdata_1;
logic                           avmm_s2m_readdatavalid_1;

logic   [AVMM_DATA_WIDTH-1:0]   avmm_s2m_readdata_2;
logic                           avmm_s2m_readdatavalid_2;

logic           rsp_fifo_wrreq;
logic   [511:0] rsp_fifo_din;

logic           rsp_fifo_rdack;
logic   [511:0] rsp_fifo_dout;

logic           rsp_fifo_valid;
logic           rsp_fifo_valid_next;

logic           rsp_fifo_empty;
logic           rsp_fifo_almostempty;
logic           rsp_fifo_almostfull;

logic   [1:0]   rsp_fifo_eccstatus;

typedef struct packed {
    logic   [9:0]   tag;
    logic   [13:0]  length;
    logic   [15:0]  req_id;
    logic   [23:0]  low_addr;
} ctt_t;

ctt_t   ctt_fifo_din;
ctt_t   ctt_fifo_dout;

logic           ctt_fifo_wrreq;
logic           ctt_fifo_rdack;

logic   [1:0]   ctt_fifo_eccstatus;

logic   [2:0]   ctt_fifo_error_pipe;

//--------------------------------------------------------
// AXIS Tx Source Interface
//--------------------------------------------------------
always_comb
begin
    axis_tx_if.tlast        = rsp_fifo_valid;
    axis_tx_if.tvalid       = rsp_fifo_valid;
    
    axis_tx_if.tdata        = rsp_fifo_dout;
    axis_tx_if.tkeep        = {$bits(axis_tx_if.tkeep){1'b1}};
    axis_tx_if.tuser_vendor = {$bits(axis_tx_if.tuser_vendor){1'b0}};
    
    axis_tx_error           = ctt_fifo_error_pipe[2] || rsp_fifo_eccstatus[0];
end

//--------------------------------------------------------
// AVMM Slave to Master Interface + FIFO
//--------------------------------------------------------
// Construct TLP -> Response FIFO DIN
always_comb
begin    
    // Right-shift empty readdata due to unaligned address
    rsp_fifo_din        <= { { ( 256 - $bits(avmm_s2m_readdata_2) ) {1'b0} }, 
                                avmm_s2m_readdata_2 >> ( 8 * cpl_hdr.low_addr[2:0] ), 
                                                                            cpl_hdr };
    rsp_fifo_wrreq      <= avmm_s2m_readdatavalid_2;
end

// +2 pipeline to ensure CTT FIFO wrreq -> Q latency
always_ff @ ( posedge clk )
begin
    if ( !rst_n )
    begin
        avmm_s2m_readdatavalid_2    <= 1'b0;
        avmm_s2m_readdatavalid_1    <= 1'b0;
        avmm_s2m_readdata_2         <= 0;
        avmm_s2m_readdata_1         <= 0;
    end
    else
    begin
        avmm_s2m_readdata_2         <= avmm_s2m_readdata_1;
        avmm_s2m_readdatavalid_2    <= avmm_s2m_readdatavalid_1;

        avmm_s2m_readdata_1         <= avmm_s2m_readdata;
        avmm_s2m_readdatavalid_1    <= avmm_s2m_readdatavalid;
    end
end

// Hold DOUT until sink capture on AVST 'ready' and 'valid'
always_comb
begin
    rsp_fifo_rdack      = axis_tx_if.tready
                            && axis_tx_if.tvalid;
end

// If almost empty, deassert next valid on 'rdack', to allow empty status flag to update
always_comb
begin   
    rsp_fifo_valid_next = rsp_fifo_rdack        ?   !rsp_fifo_almostempty :
                                                    !rsp_fifo_empty;
end

// +1 delay to 'valid' to allow for 'rdack' -> DOUT latency
always_ff @ ( posedge clk )
begin
    if ( !rst_n )
    begin
        rsp_fifo_valid          <= 1'b0;
    end
    else
    begin
        rsp_fifo_valid          <= rsp_fifo_valid_next;
    end
end

// RSP FIFO
scfifo
rsp_fifo (
    .clock          (clk),
    .sclr           (!rst_n),
    .aclr           (1'b0),
    
    .wrreq          (rsp_fifo_wrreq),
    .data           (rsp_fifo_din),
    
    .rdreq          (rsp_fifo_rdack),
    .q              (rsp_fifo_dout),
    
    .empty          (rsp_fifo_empty),
    .almost_empty   (rsp_fifo_almostempty),

    .full           ( ),
    .almost_full    (rsp_fifo_almostfull),      // No overflow backpressure
    .usedw          ( ),
    
    .eccstatus      (rsp_fifo_eccstatus)
);
defparam
    rsp_fifo.add_ram_output_register  = "ON",
    rsp_fifo.almost_empty_value  = 3,
    rsp_fifo.almost_full_value  = 240,
    rsp_fifo.enable_ecc  = "TRUE",
`ifdef DEVICE_FAMILY
    rsp_fifo.intended_device_family  = `DEVICE_FAMILY,
`else
    rsp_fifo.intended_device_family  = "Stratix 10",
`endif
    rsp_fifo.lpm_hint  = "RAM_BLOCK_TYPE=M20K",
    rsp_fifo.lpm_numwords  = 256,
    rsp_fifo.lpm_showahead  = "ON",
    rsp_fifo.lpm_type  = "scfifo",
    rsp_fifo.lpm_width  = 512,
    rsp_fifo.lpm_widthu  = 8,
    rsp_fifo.overflow_checking  = "ON",
    rsp_fifo.underflow_checking  = "ON",
    rsp_fifo.use_eab  = "ON";

//--------------------------------------------------------
// Cache Tag Tracker FIFO
// TLP Read Request Sideband from Rx Bridge
//--------------------------------------------------------
always_comb
begin
    ctt_fifo_din.tag        = tlp_rd_tag;
    ctt_fifo_din.length     = tlp_rd_length;
    ctt_fifo_din.req_id     = tlp_rd_req_id;
    ctt_fifo_din.low_addr   = tlp_rd_low_addr;
    
    ctt_fifo_wrreq          = tlp_rd_strb;
    ctt_fifo_rdack          = avmm_s2m_readdatavalid_2;
end

always_ff @ ( posedge clk )
begin
    ctt_fifo_error_pipe[2]  <= ctt_fifo_error_pipe[1];
    ctt_fifo_error_pipe[1]  <= ctt_fifo_error_pipe[0];
    ctt_fifo_error_pipe[0]  <= ctt_fifo_rdack && ctt_fifo_eccstatus[0];
end

// CTT FIFO
scfifo
ctt_fifo (
    .clock          (clk),
    .sclr           (!rst_n),
    .aclr           (1'b0),
    
    .wrreq          (ctt_fifo_wrreq),
    .data           (ctt_fifo_din),
    
    .rdreq          (ctt_fifo_rdack),
    .q              (ctt_fifo_dout),
    
    .empty          ( ),
    .almost_empty   ( ),

    .full           ( ),
    .almost_full    ( ),
    .usedw          ( ),
    
    .eccstatus      (ctt_fifo_eccstatus)
);
defparam
    ctt_fifo.add_ram_output_register  = "ON",
    ctt_fifo.almost_empty_value  = 2,
    ctt_fifo.almost_full_value  = 1023,
    ctt_fifo.enable_ecc  = "TRUE",
`ifdef DEVICE_FAMILY
    ctt_fifo.intended_device_family  = `DEVICE_FAMILY,
`else
    ctt_fifo.intended_device_family  = "Stratix 10",
`endif
    ctt_fifo.lpm_hint  = "RAM_BLOCK_TYPE=M20K",
    ctt_fifo.lpm_numwords  = 1024,
    ctt_fifo.lpm_showahead  = "ON",
    ctt_fifo.lpm_type  = "scfifo",
    ctt_fifo.lpm_width  = 64,
    ctt_fifo.lpm_widthu  = 10,
    ctt_fifo.overflow_checking  = "ON",
    ctt_fifo.underflow_checking  = "ON",
    ctt_fifo.use_eab  = "ON";

//--------------------------------------------------------
// Construct Completion Header
//--------------------------------------------------------
always_comb
begin
    cpl_hdr                 = {$bits(cpl_hdr){1'b0}};

    cpl_hdr.pf_num          = PF_NUM;
    cpl_hdr.vf_num          = VF_NUM;
    cpl_hdr.vf_active       = VF_ACTIVE;

    cpl_hdr.fmt_type        = DM_CPL;

    {cpl_hdr.tag_h,
     cpl_hdr.tag_m,
     cpl_hdr.tag_l}         = ctt_fifo_dout.tag[9:0];
    
    cpl_hdr.length          = ctt_fifo_dout.length[11:2];    
    cpl_hdr.low_addr        = ctt_fifo_dout.low_addr[6:0];
    cpl_hdr.req_id          = ctt_fifo_dout.req_id[15:0];
    cpl_hdr.byte_count      = ctt_fifo_dout.length[11:0];

    cpl_hdr.comp_id[2:0]    = PF_NUM;
    cpl_hdr.comp_id[3]      = VF_ACTIVE;
    cpl_hdr.comp_id[15:4]   = VF_NUM;
    cpl_hdr.cpl_status      = 3'b000;                           // SUCCESS
end

endmodule


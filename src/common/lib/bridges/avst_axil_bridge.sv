// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// AVST to AXI-Lite Bridge
//-----------------------------------------------------------------------------

module  avst_axil_bridge #(
    parameter END_OF_LIST       = 1'b0,
    parameter NEXT_DFH_OFFSET   = 24'h01_0000,
    
    parameter PF_NUM            = 0,
    parameter VF_NUM            = 0,
    parameter VF_ACTIVE         = 0,
    
    parameter MM_ADDR_WIDTH     = 20, 
    parameter MM_DATA_WIDTH     = 64
)(
    input                       clk,
    input                       rst_n,
    input                       flrst_n,
    
    ofs_avst_if.sink            avst_rx_if,
    ofs_avst_if.source          avst_tx_if,

    ofs_fim_axi_lite_if.master  axi_m_if,
    ofs_fim_axi_lite_if.slave   axi_s_if
);

logic                               avmm_m2s_write;
logic                               avmm_m2s_read;
logic   [MM_ADDR_WIDTH-1:0]         avmm_m2s_address;
logic   [MM_DATA_WIDTH-1:0]         avmm_m2s_writedata;
logic   [(MM_DATA_WIDTH>>3)-1:0]    avmm_m2s_byteenable;

logic                               avmm_s2m_waitrequest;
logic                               avmm_s2m_writeresponsevalid;
logic                               avmm_s2m_readdatavalid;
logic   [MM_DATA_WIDTH-1:0]         avmm_s2m_readdata;

logic                               tlp_rd_strb;
logic   [9:0]                       tlp_rd_tag;
logic   [13:0]                      tlp_rd_length;
logic   [15:0]                      tlp_rd_req_id;
logic   [23:0]                      tlp_rd_low_addr;

logic   reset_n;

always_comb
begin
    reset_n =       !rst_n      ?   1'b0 :
                    !flrst_n    ?   1'b0 :
                                    1'b1;
end

avst_rx_mmio_bridge #(
    .AVMM_ADDR_WIDTH    (MM_ADDR_WIDTH), 
    .AVMM_DATA_WIDTH    (MM_DATA_WIDTH)
)
avst_rx_mmio_bridge (
    .clk                            (clk),
    .rst_n                          (reset_n),
    
    .avst_rx_if                     (avst_rx_if),
    
    .avmm_s2m_waitrequest           (avmm_s2m_waitrequest),
    .avmm_s2m_writeresponsevalid    (avmm_s2m_writeresponsevalid),
    .avmm_s2m_readdatavalid         (avmm_s2m_readdatavalid),
    
    .avmm_m2s_write                 (avmm_m2s_write),
    .avmm_m2s_read                  (avmm_m2s_read),
    .avmm_m2s_address               (avmm_m2s_address),
    .avmm_m2s_writedata             (avmm_m2s_writedata),
    .avmm_m2s_byteenable            (avmm_m2s_byteenable),
    
    .tlp_rd_strb                    (tlp_rd_strb),
    .tlp_rd_tag                     (tlp_rd_tag),
    .tlp_rd_length                  (tlp_rd_length),
    .tlp_rd_req_id                  (tlp_rd_req_id),
    .tlp_rd_low_addr                (tlp_rd_low_addr)
);

avst_tx_mmio_bridge #(
    .PF_NUM             (PF_NUM),
    .VF_NUM             (VF_NUM),
    .VF_ACTIVE          (VF_ACTIVE),
    .AVMM_DATA_WIDTH    (MM_DATA_WIDTH)
)
avst_tx_mmio_bridge (
    .clk                            (clk),
    .rst_n                          (reset_n),
    
    .avst_tx_if                     (avst_tx_if),

    .avmm_s2m_readdatavalid         (avmm_s2m_readdatavalid),
    .avmm_s2m_readdata              (avmm_s2m_readdata),

    .tlp_rd_strb                    (tlp_rd_strb),
    .tlp_rd_tag                     (tlp_rd_tag),
    .tlp_rd_length                  (tlp_rd_length),
    .tlp_rd_req_id                  (tlp_rd_req_id),
    .tlp_rd_low_addr                (tlp_rd_low_addr)
);

axil_bridge_csr #(
    .END_OF_LIST            (END_OF_LIST),
    .NEXT_DFH_OFFSET        (NEXT_DFH_OFFSET),
    .ADDR_WIDTH             (MM_ADDR_WIDTH),
    .DATA_WIDTH             (MM_DATA_WIDTH)
)
axil_bridge_csr_inst (
    .clk                            (clk),
    .rst_n                          (reset_n),
    
    .axi_s_if                       (axi_s_if),
    
    .msix_strb                      (msix_strb),
    .msix_num                       (msix_num),
    
    .flg_rd_req                     (avmm_m2s_read),
    .flg_rd_cpl                     (avmm_s2m_readdatavalid),
    .flg_wr_req                     (avmm_m2s_write),
    .flg_wr_cpl                     (avmm_s2m_writeresponsevalid)
);

pfa_master #(
    .AVMM_ADDR_WIDTH        (MM_ADDR_WIDTH),
    .AVMM_RDATA_WIDTH       (MM_DATA_WIDTH),
    .AVMM_WDATA_WIDTH       (MM_DATA_WIDTH),
    .AXI4LITE_ADDR_WIDTH    (MM_ADDR_WIDTH),
    .AXI4LITE_RDATA_WIDTH   (MM_DATA_WIDTH),
    .AXI4LITE_WDATA_WIDTH   (MM_DATA_WIDTH)
)
pfa_master (
    .ACLK                           (clk),
    .ARESETn                        (reset_n),
    
    .avmm_m2s_write                 (avmm_m2s_write),
    .avmm_m2s_read                  (avmm_m2s_read),
    .avmm_m2s_address               (avmm_m2s_address),
    .avmm_m2s_writedata             (avmm_m2s_writedata),
    .avmm_m2s_byteenable            (avmm_m2s_byteenable),
    
    .avmm_s2m_waitrequest           (avmm_s2m_waitrequest),
    .avmm_s2m_writeresponsevalid    (avmm_s2m_writeresponsevalid),
    .avmm_s2m_readdatavalid         (avmm_s2m_readdatavalid),
    .avmm_s2m_readdata              (avmm_s2m_readdata),
    
    .axi4lite_s2m_AWREADY           (axi_m_if.awready),
    .axi4lite_m2s_AWVALID           (axi_m_if.awvalid),
    .axi4lite_m2s_AWADDR            (axi_m_if.awaddr),
    .axi4lite_m2s_AWPROT            (axi_m_if.awprot),
    
    .axi4lite_s2m_WREADY            (axi_m_if.wready),
    .axi4lite_m2s_WVALID            (axi_m_if.wvalid),
    .axi4lite_m2s_WDATA             (axi_m_if.wdata),
    .axi4lite_m2s_WSTRB             (axi_m_if.wstrb),
    
    .axi4lite_s2m_BVALID            (axi_m_if.bvalid),
    .axi4lite_s2m_BRESP             (axi_m_if.bresp),
    .axi4lite_m2s_BREADY            (axi_m_if.bready),
    
    .axi4lite_s2m_ARREADY           (axi_m_if.arready),
    .axi4lite_m2s_ARVALID           (axi_m_if.arvalid),
    .axi4lite_m2s_ARADDR            (axi_m_if.araddr),
    .axi4lite_m2s_ARPROT            (axi_m_if.arprot),
    
    .axi4lite_s2m_RVALID            (axi_m_if.rvalid),
    .axi4lite_s2m_RDATA             (axi_m_if.rdata),
    .axi4lite_s2m_RRESP             (axi_m_if.rresp),
    .axi4lite_m2s_RREADY            (axi_m_if.rready)
);

endmodule

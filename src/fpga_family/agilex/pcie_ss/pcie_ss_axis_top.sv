// Copyright (C) 2024 Intel Corporation.
// SPDX-License-Identifier: MIT

//
// Description
//-----------------------------------------------------------------------------
//
// Top level module of PCIe subsystem.
//
//-----------------------------------------------------------------------------

`include "ofs_ip_cfg_db.vh"

module pcie_ss_axis_top # (
   parameter PCIE_LANES = 16,
   parameter PCIE_NUM_LINKS = 1,
   parameter SOC_ATTACH = 0
)(

   input  logic                     fim_clk,
   input  logic                     csr_clk,
   input  logic                     ninit_done,
   output logic [PCIE_NUM_LINKS-1:0] reset_status,

   input  logic [PCIE_NUM_LINKS-1:0] fim_rst_n,
   input  logic [PCIE_NUM_LINKS-1:0] csr_rst_n,
   input  logic [PCIE_NUM_LINKS-1:0] subsystem_cold_rst_n,
   input  logic [PCIE_NUM_LINKS-1:0] subsystem_warm_rst_n,
   output logic [PCIE_NUM_LINKS-1:0] subsystem_cold_rst_ack_n,
   output logic [PCIE_NUM_LINKS-1:0] subsystem_warm_rst_ack_n,

   // PCIe pins
   ofs_fim_pcie_ss_pins_if.pcie_ss  pin_pcie,

   //TXREQ ports
   pcie_ss_axis_if.sink             axi_st_txreq_if[PCIE_NUM_LINKS-1:0],

   //Ctrl Shadow ports
   output logic [PCIE_NUM_LINKS-1:0]         ss_app_st_ctrlshadow_tvalid,
   output logic [PCIE_NUM_LINKS-1:0][39:0]   ss_app_st_ctrlshadow_tdata,

   // Application to FPGA request port (MMIO/VDM)
   pcie_ss_axis_if.source           axi_st_rxreq_if[PCIE_NUM_LINKS-1:0],

   // FPGA to application request/response ports (DM req/rsp, MMIO rsp)
   pcie_ss_axis_if.source           axi_st_rx_if[PCIE_NUM_LINKS-1:0],
   pcie_ss_axis_if.sink             axi_st_tx_if[PCIE_NUM_LINKS-1:0],

   ofs_fim_axi_lite_if.slave        ss_csr_lite_if[PCIE_NUM_LINKS-1:0],

   // FLR interface
   output pcie_ss_axis_pkg::t_axis_pcie_flr     flr_req_if[PCIE_NUM_LINKS-1:0],
   input  pcie_ss_axis_pkg::t_axis_pcie_flr     flr_rsp_if[PCIE_NUM_LINKS-1:0],

   // Completion Timeout interface
   output pcie_ss_axis_pkg::t_axis_pcie_cplto   cpl_timeout_if[PCIE_NUM_LINKS-1:0],

   output ofs_fim_if_pkg::t_sideband_from_pcie  pcie_p2c_sideband[PCIE_NUM_LINKS-1:0]
);

import ofs_fim_pcie_pkg::*;

// ========================================================================
//
//   Configuration macros (from PCIe SS IP) to localparams
//
// ========================================================================

// Map macro names from ofs_ip_cfg_db headers to localparams. Both possible
// variants are mapped: PCIE_SS and SOC_PCIE_SS. Macros that are undefined
// map to 0.
`define MACRO_TO_PARAM(NAME) \
  `ifdef OFS_FIM_IP_CFG_PCIE_SS_``NAME \
    localparam CFG_PCIE_SS_``NAME = `OFS_FIM_IP_CFG_PCIE_SS_``NAME; \
  `else \
    localparam CFG_PCIE_SS_``NAME = 0; \
  `endif \
  `ifdef OFS_FIM_IP_CFG_SOC_PCIE_SS_``NAME \
    localparam CFG_SOC_PCIE_SS_``NAME = `OFS_FIM_IP_CFG_SOC_PCIE_SS_``NAME \
  `else \
    localparam CFG_SOC_PCIE_SS_``NAME = 0 \
  `endif

// Vector macro with N_ELEM entries
`define MACRO_TO_PARAM_VEC(NAME, V_TYPE, N_ELEM) \
  `ifdef OFS_FIM_IP_CFG_PCIE_SS_``NAME \
    localparam V_TYPE CFG_PCIE_SS_``NAME``[N_ELEM] = { `OFS_FIM_IP_CFG_PCIE_SS_``NAME }; \
  `else \
    localparam V_TYPE CFG_PCIE_SS_``NAME``[N_ELEM] = '{N_ELEM{0}}; \
  `endif \
  `ifdef OFS_FIM_IP_CFG_SOC_PCIE_SS_``NAME \
    localparam V_TYPE CFG_SOC_PCIE_SS_``NAME``[N_ELEM] = { `OFS_FIM_IP_CFG_SOC_PCIE_SS_``NAME } \
  `else \
    localparam V_TYPE CFG_SOC_PCIE_SS_``NAME``[N_ELEM] = '{N_ELEM{0}} \
  `endif

// Map macro names from ofs_ip_cfg_db headers and then pick the active
// instance (either from PCIE_SS or SOC_PCIE_SS), generating a single
// localparam CFG_<NAME>.
`define SET_CFG_PARAM(NAME) \
  `MACRO_TO_PARAM(NAME); \
  localparam CFG_``NAME = SOC_ATTACH ? CFG_SOC_PCIE_SS_``NAME : CFG_PCIE_SS_``NAME

// Vector macro with N_ELEM entries
`define SET_CFG_PARAM_VEC(NAME, V_TYPE, N_ELEM) \
  `MACRO_TO_PARAM_VEC(NAME, V_TYPE, N_ELEM); \
  localparam V_TYPE CFG_``NAME``[N_ELEM] = SOC_ATTACH ? CFG_SOC_PCIE_SS_``NAME : CFG_PCIE_SS_``NAME

// Generate localparams from relevant ofs_ip_cfg_db macros using the macros
// above. Each results in a localparam named CFG_<argument>. The value is either
// the value of the cfg db macro or 0 if undefined.
`SET_CFG_PARAM(TILE_NAME);
`SET_CFG_PARAM(DWIDTH_BYTE);
`SET_CFG_PARAM(NUM_LINKS);
`SET_CFG_PARAM(NUM_SEG);
`SET_CFG_PARAM(HDR_SCHEME_IS_SIDE_BAND);
`SET_CFG_PARAM(HAS_RX_TUSER_HDR);
`SET_CFG_PARAM(HAS_TX_TUSER_HDR);
`SET_CFG_PARAM(HAS_RX_TUSER_VENDOR);
`SET_CFG_PARAM(HAS_RX_TUSER_HVALID);
`SET_CFG_PARAM(HAS_TX_TUSER_HVALID);
`SET_CFG_PARAM(HAS_RX_TUSER_LAST_SEGMENT);
`SET_CFG_PARAM(HAS_TX_TUSER_LAST_SEGMENT);
`SET_CFG_PARAM(ST_RX_HAS_TREADY);
`SET_CFG_PARAM(HAS_RXCRDT);
`SET_CFG_PARAM(HAS_P0_I_SYSPLL_C0_CLK);

`SET_CFG_PARAM(NUM_PFS);
`SET_CFG_PARAM(TOTAL_NUM_VFS);
`SET_CFG_PARAM_VEC(NUM_VFS_VEC, int, CFG_NUM_PFS);
`SET_CFG_PARAM_VEC(MSIX_PF_TABLE_SIZE_VEC, int, 8);
`SET_CFG_PARAM_VEC(MSIX_PF_TABLE_OFFSET_VEC, int, 8);
`SET_CFG_PARAM_VEC(MSIX_PF_TABLE_BAR_VEC, int, 8);
`SET_CFG_PARAM_VEC(MSIX_PF_TABLE_BAR_LOG2_SIZE_VEC, int, 8);
`SET_CFG_PARAM_VEC(MSIX_PF_PBA_OFFSET_VEC, int, 8);
`SET_CFG_PARAM_VEC(MSIX_PF_PBA_BAR_VEC, int, 8);
`SET_CFG_PARAM_VEC(MSIX_VF_TABLE_SIZE_VEC, int, 8);
`SET_CFG_PARAM_VEC(MSIX_VF_TABLE_OFFSET_VEC, int, 8);
`SET_CFG_PARAM_VEC(MSIX_VF_TABLE_BAR_VEC, int, 8);
`SET_CFG_PARAM_VEC(MSIX_VF_TABLE_BAR_LOG2_SIZE_VEC, int, 8);
`SET_CFG_PARAM_VEC(MSIX_VF_PBA_OFFSET_VEC, int, 8);
`SET_CFG_PARAM_VEC(MSIX_VF_PBA_BAR_VEC, int, 8);

`SET_CFG_PARAM(ATS_CAP);
`SET_CFG_PARAM(PASID_CAP);
`SET_CFG_PARAM(PRS_CAP);
`SET_CFG_PARAM_VEC(PASID_CAP_VEC, bit, CFG_NUM_PFS);

`SET_CFG_PARAM(HAS_CEB);
`SET_CFG_PARAM(CEB_PF_EXT_NEXT_DW);
`SET_CFG_PARAM(CEB_VF_EXT_NEXT_DW);

`undef MACRO_TO_PARAM
`undef SET_CFG_PARAM

// synopsys translate_off
initial begin
    //
    // A bunch of tests that the PCIe SS interface is in a state covered by
    // pcie_ss_axis_top.
    //

    // Requested PCIe links must be <= HIP number of links
    if (PCIE_NUM_LINKS > CFG_NUM_LINKS)
       $fatal(1, " ** ERROR ** %m: PCIE_NUM_LINKS (%0d) > CFG_NUM_LINKS (%0d)",
              PCIE_NUM_LINKS, CFG_NUM_LINKS);

    // Side-band expects to send/receive headers in tuser_hdr
    if (CFG_HDR_SCHEME_IS_SIDE_BAND != CFG_HAS_RX_TUSER_HDR)
       $fatal(1, " ** ERROR ** %m: CFG_HDR_SCHEME_IS_SIDE_BAND (%0d) != CFG_HAS_RX_TUSER_HDR (%0d)",
              CFG_HDR_SCHEME_IS_SIDE_BAND, CFG_HAS_RX_TUSER_HDR);

    if (CFG_HAS_TX_TUSER_HDR != CFG_HAS_RX_TUSER_HDR)
       $fatal(1, " ** ERROR ** %m: CFG_HAS_TX_TUSER_HDR (%0d) != CFG_HAS_RX_TUSER_HDR (%0d)",
              CFG_HAS_TX_TUSER_HDR, CFG_HAS_RX_TUSER_HDR);

    // Bus width must be defined
    if (CFG_DWIDTH_BYTE == 0)
        $fatal(1, " ** ERROR ** %m: CFG_DWIDTH_BYTE undefined!");

    // CFG_NUM_SEG must be defined
    if (CFG_NUM_SEG == 0)
        $fatal(1, " ** ERROR ** %m: CFG_NUM_SEG undefined!");

    // If the number of segments is > 1 then expect tuser_hvalid.
    // Exception: Agilex 5 GTS ("SM") tile in-band-header streams legitimately
    // run with NUM_OF_SEG=2 but do not expose tuser_hvalid through the IP
    // config DB. Tile-gating this check keeps elaboration honest for every
    // other tile while letting the SM tile build cleanly.
    if ((CFG_NUM_SEG > 1) && !CFG_HAS_RX_TUSER_HVALID && (CFG_TILE_NAME != "SM"))
        $fatal(1, " ** ERROR ** %m: CFG_NUM_SEG (%0d) > 1 but no tuser_hvalid", CFG_NUM_SEG);

    // RX/TX tuser_hvalid and tuser_last_segment should match. The two fields should
    // both be present or not present.
    if (CFG_HAS_TX_TUSER_HVALID != CFG_HAS_RX_TUSER_HVALID)
       $fatal(1, " ** ERROR ** %m: CFG_HAS_TX_TUSER_HVALID (%0d) != CFG_HAS_RX_TUSER_HVALID (%0d)",
              CFG_HAS_TX_TUSER_HVALID, CFG_HAS_RX_TUSER_HVALID);
    if (CFG_HAS_TX_TUSER_HVALID != CFG_HAS_TX_TUSER_LAST_SEGMENT)
       $fatal(1, " ** ERROR ** %m: CFG_HAS_TX_TUSER_HVALID (%0d) != CFG_HAS_TX_TUSER_LAST_SEGMENT (%0d)",
              CFG_HAS_TX_TUSER_HVALID, CFG_HAS_TX_TUSER_LAST_SEGMENT);
    if (CFG_HAS_RX_TUSER_HVALID != CFG_HAS_RX_TUSER_LAST_SEGMENT)
       $fatal(1, " ** ERROR ** %m: CFG_HAS_RX_TUSER_HVALID (%0d) != CFG_HAS_RX_TUSER_LAST_SEGMENT (%0d)",
              CFG_HAS_RX_TUSER_HVALID, CFG_HAS_RX_TUSER_LAST_SEGMENT);

    // Expect either RX tready or RX credit and not both
    if (CFG_ST_RX_HAS_TREADY == CFG_HAS_RXCRDT)
        $fatal(1, " ** ERROR ** %m: CFG_ST_RX_HAS_TREADY (%0d) == CFG_HAS_RXCRDT (%0d)",
               CFG_ST_RX_HAS_TREADY, CFG_HAS_RXCRDT);
end
// synopsys translate_on


// ========================================================================
//
//   OFS to PCIe SS
//
// ========================================================================

localparam TDATA_WIDTH = CFG_DWIDTH_BYTE * 8;
localparam TKEEP_WIDTH = CFG_DWIDTH_BYTE;

localparam CSR_STAT_SYNC_WIDTH = 33;

// Clock & Reset
logic                             coreclkout_hip;
logic [PCIE_NUM_LINKS-1:0]        reset_status_n;

assign reset_status = ~reset_status_n;

// PCIE SS signals
logic [PCIE_NUM_LINKS-1:0]                   ss_app_st_rx_tvalid;
logic [PCIE_NUM_LINKS-1:0]                   app_ss_st_rx_tready;
logic [PCIE_NUM_LINKS-1:0] [TDATA_WIDTH-1:0] ss_app_st_rx_tdata;
logic [PCIE_NUM_LINKS-1:0] [TKEEP_WIDTH-1:0] ss_app_st_rx_tkeep;
logic [PCIE_NUM_LINKS-1:0]                   ss_app_st_rx_tlast;
logic [PCIE_NUM_LINKS-1:0] [CFG_NUM_SEG-1:0] ss_app_st_rx_tuser_vendor;
logic [PCIE_NUM_LINKS-1:0] [CFG_NUM_SEG-1:0] ss_app_st_rx_tuser_last_segment;
logic [PCIE_NUM_LINKS-1:0] [CFG_NUM_SEG-1:0] ss_app_st_rx_tuser_hvalid;
logic [PCIE_NUM_LINKS-1:0] [256*CFG_NUM_SEG-1:0] ss_app_st_rx_tuser_hdr;

logic [PCIE_NUM_LINKS-1:0]                   app_ss_st_tx_tvalid;
logic [PCIE_NUM_LINKS-1:0]                   ss_app_st_tx_tready;
logic [PCIE_NUM_LINKS-1:0] [TDATA_WIDTH-1:0] app_ss_st_tx_tdata;
logic [PCIE_NUM_LINKS-1:0] [TKEEP_WIDTH-1:0] app_ss_st_tx_tkeep;
logic [PCIE_NUM_LINKS-1:0]                   app_ss_st_tx_tlast;
logic [PCIE_NUM_LINKS-1:0] [CFG_NUM_SEG-1:0] app_ss_st_tx_tuser_vendor;
logic [PCIE_NUM_LINKS-1:0] [CFG_NUM_SEG-1:0] app_ss_st_tx_tuser_last_segment;
logic [PCIE_NUM_LINKS-1:0] [CFG_NUM_SEG-1:0] app_ss_st_tx_tuser_hvalid;
logic [PCIE_NUM_LINKS-1:0] [256*CFG_NUM_SEG-1:0] app_ss_st_tx_tuser_hdr;

logic [PCIE_NUM_LINKS-1:0]               ss_app_st_rxcrdt_tvalid;
logic [PCIE_NUM_LINKS-1:0] [18:0]        ss_app_st_rxcrdt_tdata;

// FLR Signals
logic [PCIE_NUM_LINKS-1:0]               ss_app_st_flrrcvd_tvalid;
logic [PCIE_NUM_LINKS-1:0] [19:0]        ss_app_st_flrrcvd_tdata;
logic [PCIE_NUM_LINKS-1:0]               app_ss_st_flrcmpl_tvalid;
logic [PCIE_NUM_LINKS-1:0]               ss_app_st_flrcmpl_tready;
logic [PCIE_NUM_LINKS-1:0] [19:0]        app_ss_st_flrcmpl_tdata;

// Completion Timeout
logic [PCIE_NUM_LINKS-1:0]               ss_app_st_cplto_tvalid;
logic [PCIE_NUM_LINKS-1:0] [29:0]        ss_app_st_cplto_tdata;

logic [PCIE_NUM_LINKS-1:0]               ctrlshadow_tvalid;
logic [PCIE_NUM_LINKS-1:0][39:0]         ctrlshadow_tdata;

logic [PCIE_NUM_LINKS-1:0]               ss_app_lite_csr_awready;
logic [PCIE_NUM_LINKS-1:0]               ss_app_lite_csr_wready;
logic [PCIE_NUM_LINKS-1:0]               ss_app_lite_csr_arready;
logic [PCIE_NUM_LINKS-1:0]               ss_app_lite_csr_bvalid;
logic [PCIE_NUM_LINKS-1:0]               ss_app_lite_csr_rvalid;
logic [PCIE_NUM_LINKS-1:0]               app_ss_lite_csr_awvalid;
logic [PCIE_NUM_LINKS-1:0] [ofs_fim_cfg_pkg::PCIE_LITE_CSR_WIDTH-1:0] app_ss_lite_csr_awaddr;
logic [PCIE_NUM_LINKS-1:0]               app_ss_lite_csr_wvalid;
logic [PCIE_NUM_LINKS-1:0] [31:0]        app_ss_lite_csr_wdata;
logic [PCIE_NUM_LINKS-1:0] [3:0]         app_ss_lite_csr_wstrb;
logic [PCIE_NUM_LINKS-1:0]               app_ss_lite_csr_bready;
logic [PCIE_NUM_LINKS-1:0] [1:0]         ss_app_lite_csr_bresp;
logic [PCIE_NUM_LINKS-1:0]               app_ss_lite_csr_arvalid;
logic [PCIE_NUM_LINKS-1:0] [ofs_fim_cfg_pkg::PCIE_LITE_CSR_WIDTH-1:0] app_ss_lite_csr_araddr;
logic [PCIE_NUM_LINKS-1:0]               app_ss_lite_csr_rready;
logic [PCIE_NUM_LINKS-1:0] [31:0]        ss_app_lite_csr_rdata;
logic [PCIE_NUM_LINKS-1:0] [1:0]         ss_app_lite_csr_rresp;

logic [PCIE_NUM_LINKS-1:0]               ss_app_st_cebreq_tvalid;
logic [PCIE_NUM_LINKS-1:0]               app_ss_st_cebreq_tready;
logic [PCIE_NUM_LINKS-1:0] [67:0]        ss_app_st_cebreq_tdata;
logic [PCIE_NUM_LINKS-1:0]               app_ss_st_cebresp_tvalid;
logic [PCIE_NUM_LINKS-1:0] [31:0]        app_ss_st_cebresp_tdata;

logic [PCIE_NUM_LINKS-1:0]               initiate_warmrst_req;
logic [PCIE_NUM_LINKS-1:0]               ss_app_dlup;
logic [PCIE_NUM_LINKS-1:0]               ss_app_serr;

// Find a representative PF that is configured with an MSI-X table.
// The table implementation requires that all functions with MSI-X
// enabled must have identical configurations.
function automatic int find_msix_enabled_pf();
`ifdef MINIMAL_BUILD
  return -1;
`else
    for (int f = 0; f < 8; f += 1) begin
        if (CFG_MSIX_PF_TABLE_SIZE_VEC[f] != 0) return f;
    end

    return -1;
`endif
endfunction // find_msix_enabled_pf

for (genvar j=0; j<PCIE_NUM_LINKS; j++) begin : PCIE_LINK_CONN
    // MSI-X table, including mapping interrupt requests to writes
    pcie_ss_axis_if#(.DATA_W(axi_st_rxreq_if[j].DATA_W), .USER_W(axi_st_rxreq_if[j].USER_W))
        rxreq_to_msix(fim_clk, fim_rst_n[j]);
    pcie_ss_axis_if#(.DATA_W(axi_st_tx_if[j].DATA_W), .USER_W(axi_st_tx_if[j].USER_W))
        tx_from_msix(fim_clk, fim_rst_n[j]);
    pcie_ss_axis_pkg::t_axis_pcie_flr msix_flr_rsp_if;

    if (find_msix_enabled_pf() != -1) begin : msix
        // MSI-X manager. Handle MMIO requests to the tables and transform AFU
        // interrupt requests to host writes. All other traffic passes through.
        ofs_fim_pcie_ss_msix
          #(
            .NUM_PFS(CFG_NUM_PFS),
            .TOTAL_NUM_VFS(CFG_TOTAL_NUM_VFS),
            .VFS_COUNT_PER_PF(CFG_NUM_VFS_VEC),

            .MSIX_PF_TABLE_SIZE(CFG_MSIX_PF_TABLE_SIZE_VEC),
            .MSIX_PF_TABLE_OFFSET(CFG_MSIX_PF_TABLE_OFFSET_VEC),
            .MSIX_PF_TABLE_BAR(CFG_MSIX_PF_TABLE_BAR_VEC),
            .MSIX_PF_TABLE_BAR_LOG2_SIZE(CFG_MSIX_PF_TABLE_BAR_LOG2_SIZE_VEC),
            .MSIX_PF_PBA_OFFSET(CFG_MSIX_PF_PBA_OFFSET_VEC),
            .MSIX_PF_PBA_BAR(CFG_MSIX_PF_PBA_BAR_VEC),

            .MSIX_VF_TABLE_SIZE(CFG_MSIX_VF_TABLE_SIZE_VEC),
            .MSIX_VF_TABLE_OFFSET(CFG_MSIX_VF_TABLE_OFFSET_VEC),
            .MSIX_VF_TABLE_BAR(CFG_MSIX_VF_TABLE_BAR_VEC),
            .MSIX_VF_TABLE_BAR_LOG2_SIZE(CFG_MSIX_VF_TABLE_BAR_LOG2_SIZE_VEC),
            .MSIX_VF_PBA_OFFSET(CFG_MSIX_VF_PBA_OFFSET_VEC),
            .MSIX_VF_PBA_BAR(CFG_MSIX_VF_PBA_BAR_VEC)
            )
          msix
           (
            .axi_st_rxreq_in(rxreq_to_msix),
            .axi_st_rxreq_out(axi_st_rxreq_if[j]),

            .axi_st_tx_in(axi_st_tx_if[j]),
            .axi_st_tx_out(tx_from_msix),

            .csr_clk,
            .csr_rst_n(csr_rst_n[j]),
            .ctrlshadow_tvalid(ctrlshadow_tvalid[j]),
            .ctrlshadow_tdata(ctrlshadow_tdata[j]),

            .flr_req_if(flr_rsp_if[j]),
            .flr_rsp_if(msix_flr_rsp_if),
            .flr_rsp_tready(ss_app_st_flrcmpl_tready[j])
            );
    end else begin : no_msix
        // MSI-X is not enabled
        ofs_fim_axis_pipeline #(.PL_DEPTH(0))
            pipe_rxreq(.clk(fim_clk), .rst_n(fim_rst_n[j]), .axis_s(rxreq_to_msix), .axis_m(axi_st_rxreq_if[j]));

        ofs_fim_axis_pipeline #(.PL_DEPTH(0))
            pipe_tx(.clk(fim_clk), .rst_n(fim_rst_n[j]), .axis_s(axi_st_tx_if[j]), .axis_m(tx_from_msix));

        assign msix_flr_rsp_if = flr_rsp_if[j];
    end

    // Connecting the RX ST Interface
    if (CFG_HDR_SCHEME_IS_SIDE_BAND) begin : rx_sb
        ofs_fim_pcie_ss_pipe_rx_sb
          #(
            .TDATA_WIDTH(TDATA_WIDTH),
            .NUM_OF_SEG(CFG_NUM_SEG),
            .CFG_HAS_RXCRDT(CFG_HAS_RXCRDT)
            )
          pipe_rx
           (
            .hip_clk(coreclkout_hip),
            .hip_rst_n(reset_status_n),

            .ss_app_st_rx_tvalid(ss_app_st_rx_tvalid[j]),
            .ss_app_st_rx_tdata(ss_app_st_rx_tdata[j]),
            .ss_app_st_rx_tkeep(ss_app_st_rx_tkeep[j]),
            .ss_app_st_rx_tlast(ss_app_st_rx_tlast[j]),
            .ss_app_st_rx_tuser_vendor(ss_app_st_rx_tuser_vendor[j]),
            .ss_app_st_rx_tuser_last_segment(ss_app_st_rx_tuser_last_segment[j]),
            .ss_app_st_rx_tuser_hvalid(ss_app_st_rx_tuser_hvalid[j]),
            .ss_app_st_rx_tuser_hdr(ss_app_st_rx_tuser_hdr[j]),
            .app_ss_st_rx_tready(app_ss_st_rx_tready[j]),
            .ss_app_st_rxcrdt_tvalid(ss_app_st_rxcrdt_tvalid[j]),
            .ss_app_st_rxcrdt_tdata(ss_app_st_rxcrdt_tdata[j]),

            .axi_st_rxreq_if(rxreq_to_msix),
            .axi_st_rx_if(axi_st_rx_if[j])
            );
    end else begin : rx_ib
        ofs_fim_pcie_ss_pipe_rx_ib
          #(
            .TDATA_WIDTH(TDATA_WIDTH),
            .NUM_OF_SEG(CFG_NUM_SEG),
            .CFG_HAS_RXCRDT(CFG_HAS_RXCRDT)
            )
          pipe_rx
           (
            .hip_clk(coreclkout_hip),
            .hip_rst_n(reset_status_n),

            .ss_app_st_rx_tvalid(ss_app_st_rx_tvalid[j]),
            .ss_app_st_rx_tdata(ss_app_st_rx_tdata[j]),
            .ss_app_st_rx_tkeep(ss_app_st_rx_tkeep[j]),
            .ss_app_st_rx_tlast(ss_app_st_rx_tlast[j]),
            .ss_app_st_rx_tuser_vendor(ss_app_st_rx_tuser_vendor[j]),
            .ss_app_st_rx_tuser_last_segment(ss_app_st_rx_tuser_last_segment[j]),
            .ss_app_st_rx_tuser_hvalid(ss_app_st_rx_tuser_hvalid[j]),
            .app_ss_st_rx_tready(app_ss_st_rx_tready[j]),
            .ss_app_st_rxcrdt_tvalid(ss_app_st_rxcrdt_tvalid[j]),
            .ss_app_st_rxcrdt_tdata(ss_app_st_rxcrdt_tdata[j]),

            .axi_st_rxreq_if(rxreq_to_msix),
            .axi_st_rx_if(axi_st_rx_if[j])
            );
    end

    if (CFG_HAS_RX_TUSER_VENDOR == 0) begin
        // Only PU encoding from PCIe
        assign ss_app_st_rx_tuser_vendor[j] = 1'b0;
    end
    if (CFG_HAS_RX_TUSER_HVALID == 0) begin
        // tuser_hvalid and tuser_last_segment may be undefined only when
        // the number of segments is 1. Define them here so the pipeline can
        // use consistent signals.
        assign ss_app_st_rx_tuser_last_segment[j] = ss_app_st_rx_tlast[j];
        always_ff @(posedge coreclkout_hip) begin
        if (ss_app_st_rx_tvalid[j] && app_ss_st_rx_tready[j])
                ss_app_st_rx_tuser_hvalid[j] <= ss_app_st_rx_tlast[j];
        if (!reset_status_n[j])
                ss_app_st_rx_tuser_hvalid[j] <= 1'b1;
        end
    end


    logic axi_st_rx_if_sop;
    pcie_ss_hdr_pkg::PCIe_PUReqHdr_t cpl_hdr;
    pcie_ss_hdr_pkg::PCIe_PUReqHdr_t cpl_hdr_d;
    logic cpl_hdr_d_valid;

    assign cpl_hdr = axi_st_rx_if[j].tdata[$bits(cpl_hdr)-1:0];

    always_ff @(posedge fim_clk) begin
        cpl_hdr_d <= cpl_hdr;
        cpl_hdr_d_valid <= axi_st_rx_if[j].tvalid && axi_st_rx_if[j].tready &&
                           axi_st_rx_if_sop &&
                           pcie_ss_hdr_pkg::func_is_completion(cpl_hdr.fmt_type);

        if (axi_st_rx_if[j].tvalid && axi_st_rx_if[j].tready) begin
            axi_st_rx_if_sop <= axi_st_rx_if[j].tlast;
        end

        if (!fim_rst_n[j]) begin
            cpl_hdr_d_valid <= 1'b0;
            axi_st_rx_if_sop <= 1'b1;
        end
    end


    // Connecting the TX ST Interface
    if (CFG_HDR_SCHEME_IS_SIDE_BAND) begin : tx_sb
        ofs_fim_pcie_ss_pipe_tx_sb
          #(
            .TILE(CFG_TILE_NAME),
            .PORT_ID(j),
            .TDATA_WIDTH(TDATA_WIDTH),
            .NUM_OF_SEG(CFG_NUM_SEG),
            .NUM_OF_LINKS(PCIE_NUM_LINKS)
            )
          pipe_tx
           (
            .axi_st_txreq_if(axi_st_txreq_if[j]),
            .axi_st_tx_if(tx_from_msix),

            .hip_clk(coreclkout_hip),
            .hip_rst_n(reset_status_n),
            .csr_clk,
            .csr_rst_n(csr_rst_n[j]),

            .app_ss_st_tx_tvalid(app_ss_st_tx_tvalid[j]),
            .app_ss_st_tx_tdata(app_ss_st_tx_tdata[j]),
            .app_ss_st_tx_tkeep(app_ss_st_tx_tkeep[j]),
            .app_ss_st_tx_tlast(app_ss_st_tx_tlast[j]),
            .app_ss_st_tx_tuser_vendor(app_ss_st_tx_tuser_vendor[j]),
            .app_ss_st_tx_tuser_last_segment(app_ss_st_tx_tuser_last_segment[j]),
            .app_ss_st_tx_tuser_hvalid(app_ss_st_tx_tuser_hvalid[j]),
            .app_ss_st_tx_tuser_hdr(app_ss_st_tx_tuser_hdr[j]),
            .ss_app_st_tx_tready(ss_app_st_tx_tready[j]),

            .cpl_hdr_valid(cpl_hdr_d_valid),
            .cpl_hdr(cpl_hdr_d),
            .cpl_timeout(cpl_timeout_if[j])
            );
    end else begin : tx_ib
        ofs_fim_pcie_ss_pipe_tx_ib
          #(
            .TILE(CFG_TILE_NAME),
            .PORT_ID(j),
            .TDATA_WIDTH(TDATA_WIDTH),
            .NUM_OF_SEG(CFG_NUM_SEG),
            .NUM_OF_LINKS(PCIE_NUM_LINKS)
            )
          pipe_tx
           (
            .axi_st_txreq_if(axi_st_txreq_if[j]),
            .axi_st_tx_if(tx_from_msix),

            .hip_clk(coreclkout_hip),
            .hip_rst_n(reset_status_n),
            .csr_clk,
            .csr_rst_n(csr_rst_n[j]),

            .app_ss_st_tx_tvalid(app_ss_st_tx_tvalid[j]),
            .app_ss_st_tx_tdata(app_ss_st_tx_tdata[j]),
            .app_ss_st_tx_tkeep(app_ss_st_tx_tkeep[j]),
            .app_ss_st_tx_tlast(app_ss_st_tx_tlast[j]),
            .app_ss_st_tx_tuser_vendor(app_ss_st_tx_tuser_vendor[j]),
            .app_ss_st_tx_tuser_last_segment(app_ss_st_tx_tuser_last_segment[j]),
            .app_ss_st_tx_tuser_hvalid(app_ss_st_tx_tuser_hvalid[j]),
            .ss_app_st_tx_tready(ss_app_st_tx_tready[j]),

            .cpl_hdr_valid(cpl_hdr_d_valid),
            .cpl_hdr(cpl_hdr_d),
            .cpl_timeout(cpl_timeout_if[j])
            );

        assign app_ss_st_tx_tuser_hdr[j] = '0;
    end

    // Connecting the FLR Interface
    assign flr_req_if[j].tvalid = ss_app_st_flrrcvd_tvalid[j];
    assign flr_req_if[j].tdata  = ss_app_st_flrrcvd_tdata[j];

    // FLR response from FIM flows through the MSI-X handler above
    assign app_ss_st_flrcmpl_tvalid[j] = msix_flr_rsp_if.tvalid;
    assign app_ss_st_flrcmpl_tdata[j]  = msix_flr_rsp_if.tdata;


    // Connecting the csr interface
    assign ss_csr_lite_if[j].awready     = ss_app_lite_csr_awready[j];
    assign ss_csr_lite_if[j].wready      = ss_app_lite_csr_wready[j];
    assign ss_csr_lite_if[j].arready     = ss_app_lite_csr_arready[j];
    assign ss_csr_lite_if[j].bvalid      = ss_app_lite_csr_bvalid[j];
    assign ss_csr_lite_if[j].rvalid      = ss_app_lite_csr_rvalid[j];
    assign app_ss_lite_csr_awvalid[j]    = ss_csr_lite_if[j].awvalid;
    assign app_ss_lite_csr_awaddr[j]     = ss_csr_lite_if[j].awaddr;
    assign app_ss_lite_csr_wvalid[j]     = ss_csr_lite_if[j].wvalid;
    assign app_ss_lite_csr_wdata[j]      = ss_csr_lite_if[j].wdata;
    assign app_ss_lite_csr_wstrb[j]      = ss_csr_lite_if[j].wstrb;
    assign app_ss_lite_csr_bready[j]     = ss_csr_lite_if[j].bready;
    assign ss_csr_lite_if[j].bresp       = ss_app_lite_csr_bresp[j];
    assign app_ss_lite_csr_arvalid[j]    = ss_csr_lite_if[j].arvalid;
    assign app_ss_lite_csr_araddr[j]     = ss_csr_lite_if[j].araddr;
    assign app_ss_lite_csr_rready[j]     = ss_csr_lite_if[j].rready;
    assign ss_csr_lite_if[j].rdata       = ss_app_lite_csr_rdata[j];
    assign ss_csr_lite_if[j].rresp       = ss_app_lite_csr_rresp[j];


    // Configuration extension bus
    pcie_ss_axis_pkg::t_pcie_ceb_req ceb_req;
    always_comb begin
        ceb_req.dw_addr   = ss_app_st_cebreq_tdata[j][9:0];
        ceb_req.slot_num  = ss_app_st_cebreq_tdata[j][14:10];
        ceb_req.pf_num    = ss_app_st_cebreq_tdata[j][17:15];
        ceb_req.vf_num    = ss_app_st_cebreq_tdata[j][28:18];
        ceb_req.vf_active = ss_app_st_cebreq_tdata[j][29];
        ceb_req.wr_data   = ss_app_st_cebreq_tdata[j][61:30];
        ceb_req.wr_tkeep  = ss_app_st_cebreq_tdata[j][65:62];
    end

    pcie_ss_axis_pkg::t_pcie_ceb_rsp ceb_rsp;
    assign app_ss_st_cebresp_tdata[j] = ceb_rsp.rd_data;

    if (CFG_HAS_CEB && CFG_ATS_CAP && CFG_PASID_CAP && !CFG_PRS_CAP) begin : ceb
        // Configuration extension bus enabled, ATS capability is enabled,
        // and PRS capability is not enabled. Assume this is because the HIP's
        // implementation of PRS is flawed: the PASID required bit isn't
        // set and outstanding request capacity is zero. Use a FIM-provided
        // version of the page request capabililty.
        ofs_fim_pcie_ss_ceb_pri
          #(
            .PRI_CAP_DW_ADDR(CFG_CEB_PF_EXT_NEXT_DW),
            .NUM_PFS(CFG_NUM_PFS),
            // Add a PRI capability to every PF that supports PASID. The PRI
            // capability is never added to VFs. A PF's PRI capability applies
            // to its VFs.
            .PF_ENABLE_PRI(CFG_PASID_CAP_VEC)
            )
          ceb_pri
           (
            .csr_clk,
            .csr_rst_n(csr_rst_n[j]),
            .ceb_req_tvalid(ss_app_st_cebreq_tvalid[j]),
            .ceb_req_tready(app_ss_st_cebreq_tready[j]),
            .ceb_req(ceb_req),
            .ceb_rsp_tvalid(app_ss_st_cebresp_tvalid[j]),
            .ceb_rsp(ceb_rsp),

            .ctrlshadow_tvalid_in(ctrlshadow_tvalid[j]),
            .ctrlshadow_tdata_in(ctrlshadow_tdata[j]),
            .ctrlshadow_tvalid_out(ss_app_st_ctrlshadow_tvalid[j]),
            .ctrlshadow_tdata_out(ss_app_st_ctrlshadow_tdata[j])
            );
    end
    else begin : no_ceb
        // CEB may be enabled, but is not exposed to the FIM. Tie it off,
        // always returning 0.
        assign app_ss_st_cebreq_tready[j] = 1'b1;
        assign ceb_rsp = '0;

        assign ss_app_st_ctrlshadow_tvalid[j] = ctrlshadow_tvalid[j];
        assign ss_app_st_ctrlshadow_tdata[j] = ctrlshadow_tdata[j];

        always_ff @(posedge csr_clk) begin
            app_ss_st_cebresp_tvalid[j] <= ss_app_st_cebreq_tvalid[j] && ~|ceb_req.wr_tkeep;

            if (~csr_rst_n[j])
                app_ss_st_cebresp_tvalid[j] <= 1'b0;
        end
    end


    //-------------------------------------
    // Completion timeout interface
    //-------------------------------------
    always_comb begin
        cpl_timeout_if[j].tvalid = ss_app_st_cplto_tvalid[j];
        cpl_timeout_if[j].tdata  = ss_app_st_cplto_tdata[j];
    end

    // PCIE stat signals clock crossing (fim_clk -> csr_clk)
    fim_resync #(
        .SYNC_CHAIN_LENGTH(3),
        .WIDTH(CSR_STAT_SYNC_WIDTH),
        .INIT_VALUE(0),
        .NO_CUT(1)
      ) csr_resync (
        .clk   (csr_clk),
        .reset (~csr_rst_n[j]),
        .d     ({ss_app_dlup[j],32'b0}),
        .q     ({pcie_p2c_sideband[j].pcie_linkup, pcie_p2c_sideband[j].pcie_chk_rx_err_code})
        );

end //for (genvar j=0; j<PCIE_NUM_LINKS;..

// GTS clock -- IP generated to match the PCIe configuration by OFSS
logic systemclk_pll_lock;
logic systemclk_c0;
if (CFG_HAS_P0_I_SYSPLL_C0_CLK) begin : syspll
    pcie_ss_systemclk_gts systemclk_gts (
        .o_pll_lock(systemclk_pll_lock),
        .o_syspll_c0(systemclk_c0),
        .i_refclk(pin_pcie.refclk0_p)
        );
end

//-------------------------------------
// PCIe SS
//-------------------------------------

`ifdef OFS_FIM_IP_CFG_PCIE_SS_TOTAL_NUM_LANES_IS_8
   `define PCIE_SS_NUM_LANES_GT_4 1
`endif
`ifdef OFS_FIM_IP_CFG_PCIE_SS_TOTAL_NUM_LANES_IS_16
   `define PCIE_SS_NUM_LANES_GT_4 1
   `define PCIE_SS_NUM_LANES_GT_8 1
`endif

`ifdef OFS_FIM_IP_CFG_SOC_PCIE_SS_TOTAL_NUM_LANES_IS_8
   `define SOC_PCIE_SS_NUM_LANES_GT_4 1
`endif
`ifdef OFS_FIM_IP_CFG_SOC_PCIE_SS_TOTAL_NUM_LANES_IS_16
   `define SOC_PCIE_SS_NUM_LANES_GT_4 1
   `define SOC_PCIE_SS_NUM_LANES_GT_8 1
`endif

// Expand common arguments to the host and SoC instances from a macro.
// They are the same. The argument to the macro is expanded recursively
// by the preprocessor for either host or SoC configurations. (See
// the ifdefs below that embed SS_NAME.)
`define PCIE_SS_AXIS_PORTS(SS_NAME) \
    .refclk0                        (pin_pcie.refclk0_p             ), \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_REFCLK1                       \
    .refclk1                        (pin_pcie.refclk1_p             ), \
   `endif                                                              \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_I_FLUX_CLK                    \
    .i_flux_clk                     (pin_pcie.in_flux_clk[0]        ), \
   `endif                                                              \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_CORECLKOUT_HIP_TOAPP          \
    .coreclkout_hip_toapp           (coreclkout_hip                 ), \
   `endif                                                              \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_P0_CORECLKOUT_HIP_TOAPP       \
    .p0_coreclkout_hip_toapp        (coreclkout_hip                 ), \
   `endif                                                              \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_PIN_PERST_N                   \
    .pin_perst_n                    (pin_pcie.in_perst_n            ), \
   `endif                                                              \
    .p0_pin_perst_n                 (                               ), \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_P0_PIN_PERST_N_I              \
    .p0_pin_perst_n_i               (pin_pcie.in_perst_n            ), \
   `endif                                                              \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_P0_PIN_PERST_N_1_I            \
    .p0_pin_perst_n_1_i             (pin_pcie.in_perst_n            ), \
   `endif                                                              \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_I_GPIO_PERST0_N               \
    .i_gpio_perst0_n                (1'b1                           ), \
   `endif                                                              \
    .p0_reset_status_n              (reset_status_n[0]              ), \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_P0_I_SYSPLL_C0_CLK            \
    .p0_i_syspll_c0_clk             (systemclk_c0                   ), \
    .p0_i_ss_vccl_syspll_locked     (systemclk_pll_lock             ), \
   `endif                                                              \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_DUMMY_USER_AVMM_RST           \
    .dummy_user_avmm_rst            (                               ), \
   `endif                                                              \
    .p0_axi_st_clk                  (coreclkout_hip                 ), \
    .p0_axi_lite_clk                (csr_clk                        ), \
    .p0_axi_st_areset_n             (fim_rst_n[0]                   ), \
    .p0_axi_lite_areset_n           (csr_rst_n[0]                   ), \
    .p0_subsystem_cold_rst_n        (subsystem_cold_rst_n[0]        ), \
    .p0_subsystem_warm_rst_n        (subsystem_warm_rst_n[0]        ), \
    .p0_subsystem_cold_rst_ack_n    (subsystem_cold_rst_ack_n[0]    ), \
    .p0_subsystem_warm_rst_ack_n    (subsystem_warm_rst_ack_n[0]    ), \
    .p0_subsystem_rst_req           ('0                             ), \
    .p0_subsystem_rst_rdy           (                               ), \
    .p0_initiate_warmrst_req        (initiate_warmrst_req[0]        ), \
    .p0_initiate_rst_req_rdy        (initiate_warmrst_req[0]        ), \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_P0_APP_SS_ST_RX_TUSER_HALT    \
    .p0_app_ss_st_rx_tuser_halt     ('0                             ), \
   `endif                                                              \
    .p0_ss_app_st_rx_tvalid         (ss_app_st_rx_tvalid[0]         ), \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_ST_RX_HAS_TREADY                  \
    .p0_app_ss_st_rx_tready         (app_ss_st_rx_tready[0]         ), \
   `endif                                                              \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_RXCRDT                        \
    .p0_ss_app_st_rxcrdt_tvalid     (ss_app_st_rxcrdt_tvalid[0]     ), \
    .p0_ss_app_st_rxcrdt_tdata      (ss_app_st_rxcrdt_tdata[0]      ), \
   `endif                                                              \
    .p0_ss_app_st_rx_tdata          (ss_app_st_rx_tdata[0]          ), \
    .p0_ss_app_st_rx_tkeep          (ss_app_st_rx_tkeep[0]          ), \
    .p0_ss_app_st_rx_tlast          (ss_app_st_rx_tlast[0]          ), \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_RX_TUSER_VENDOR               \
    .p0_ss_app_st_rx_tuser_vendor   (ss_app_st_rx_tuser_vendor[0]   ), \
   `endif                                                              \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_RX_TUSER_HDR                  \
    .p0_ss_app_st_rx_tuser_hdr      (ss_app_st_rx_tuser_hdr[0]      ), \
   `endif                                                              \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_RX_TUSER_HVALID               \
    .p0_ss_app_st_rx_tuser_hvalid   (ss_app_st_rx_tuser_hvalid[0]   ), \
    .p0_ss_app_st_rx_tuser_last_segment(ss_app_st_rx_tuser_last_segment[0]), \
   `endif                                                              \
    .p0_app_ss_st_tx_tvalid         (app_ss_st_tx_tvalid[0]         ), \
    .p0_ss_app_st_tx_tready         (ss_app_st_tx_tready[0]         ), \
    .p0_app_ss_st_tx_tdata          (app_ss_st_tx_tdata[0]          ), \
    .p0_app_ss_st_tx_tkeep          (app_ss_st_tx_tkeep[0]          ), \
    .p0_app_ss_st_tx_tlast          (app_ss_st_tx_tlast[0]          ), \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_TX_TUSER_VENDOR               \
    .p0_app_ss_st_tx_tuser_vendor   (app_ss_st_tx_tuser_vendor[0]   ), \
   `endif                                                              \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_TX_TUSER_HDR                  \
    .p0_app_ss_st_tx_tuser_hdr      (app_ss_st_tx_tuser_hdr[0]      ), \
   `endif                                                              \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_TX_TUSER_HVALID               \
    .p0_app_ss_st_tx_tuser_hvalid   (app_ss_st_tx_tuser_hvalid[0]   ), \
    .p0_app_ss_st_tx_tuser_last_segment(app_ss_st_tx_tuser_last_segment[0]), \
   `endif                                                              \
    .p0_ss_app_st_flrrcvd_tvalid    (ss_app_st_flrrcvd_tvalid[0]    ), \
    .p0_ss_app_st_flrrcvd_tdata     (ss_app_st_flrrcvd_tdata[0]     ), \
    .p0_app_ss_st_flrcmpl_tvalid    (app_ss_st_flrcmpl_tvalid[0]    ), \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_FLRCMPL_HAS_TREADY                \
    .p0_ss_app_st_flrcmpl_tready    (ss_app_st_flrcmpl_tready[0]    ), \
   `endif                                                              \
    .p0_app_ss_st_flrcmpl_tdata     (app_ss_st_flrcmpl_tdata[0]     ), \
    .p0_ss_app_st_ctrlshadow_tvalid (ctrlshadow_tvalid[0]           ), \
    .p0_ss_app_st_ctrlshadow_tdata  (ctrlshadow_tdata[0]            ), \
    .p0_ss_app_st_txcrdt_tvalid     (                               ), \
    .p0_ss_app_st_txcrdt_tdata      (                               ), \
    .p0_ss_app_st_cplto_tvalid      (ss_app_st_cplto_tvalid[0]      ), \
    .p0_ss_app_st_cplto_tdata       (ss_app_st_cplto_tdata[0]       ), \
    .p0_app_ss_lite_csr_awvalid     (app_ss_lite_csr_awvalid[0]     ), \
    .p0_ss_app_lite_csr_awready     (ss_app_lite_csr_awready[0]     ), \
    .p0_app_ss_lite_csr_awaddr      (app_ss_lite_csr_awaddr[0]      ), \
    .p0_app_ss_lite_csr_wvalid      (app_ss_lite_csr_wvalid[0]      ), \
    .p0_ss_app_lite_csr_wready      (ss_app_lite_csr_wready[0]      ), \
    .p0_app_ss_lite_csr_wdata       (app_ss_lite_csr_wdata[0]       ), \
    .p0_app_ss_lite_csr_wstrb       (app_ss_lite_csr_wstrb[0]       ), \
    .p0_ss_app_lite_csr_bvalid      (ss_app_lite_csr_bvalid[0]      ), \
    .p0_app_ss_lite_csr_bready      (app_ss_lite_csr_bready[0]      ), \
    .p0_ss_app_lite_csr_bresp       (ss_app_lite_csr_bresp[0]       ), \
    .p0_app_ss_lite_csr_arvalid     (app_ss_lite_csr_arvalid[0]     ), \
    .p0_ss_app_lite_csr_arready     (ss_app_lite_csr_arready[0]     ), \
    .p0_app_ss_lite_csr_araddr      (app_ss_lite_csr_araddr[0]      ), \
    .p0_ss_app_lite_csr_rvalid      (ss_app_lite_csr_rvalid[0]      ), \
    .p0_app_ss_lite_csr_rready      (app_ss_lite_csr_rready[0]      ), \
    .p0_ss_app_lite_csr_rdata       (ss_app_lite_csr_rdata[0]       ), \
    .p0_ss_app_lite_csr_rresp       (ss_app_lite_csr_rresp[0]       ), \
    .p0_ss_app_dlup                 (ss_app_dlup[0]                 ), \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_CEB                           \
    .p0_ss_app_st_cebreq_tvalid     (ss_app_st_cebreq_tvalid[0]     ), \
    .p0_app_ss_st_cebreq_tready     (app_ss_st_cebreq_tready[0]     ), \
    .p0_ss_app_st_cebreq_tdata      (ss_app_st_cebreq_tdata[0]      ), \
    .p0_app_ss_st_cebresp_tvalid    (app_ss_st_cebresp_tvalid[0]    ), \
    .p0_app_ss_st_cebresp_tdata     (app_ss_st_cebresp_tdata[0]     ), \
   `endif                                                              \
                                                                       \
 `ifdef OFS_FIM_IP_CFG_``SS_NAME``_NUM_PHYS_LINKS_IS_2                 \
  `ifdef OFS_FIM_IP_CFG_``SS_NAME``_EN_LINK_1                          \
    /* Two ports used in OFS reference design */                       \
    .p1_reset_status_n              (reset_status_n[1]              ), \
    .p1_axi_st_clk                  (coreclkout_hip                 ), \
    .p1_axi_lite_clk                (csr_clk                        ), \
    .p1_axi_st_areset_n             (fim_rst_n[1]                   ), \
    .p1_axi_lite_areset_n           (csr_rst_n[1]                   ), \
    .p1_subsystem_cold_rst_n        (subsystem_cold_rst_n[1]        ), \
    .p1_subsystem_warm_rst_n        (subsystem_warm_rst_n[1]        ), \
    .p1_subsystem_cold_rst_ack_n    (subsystem_cold_rst_ack_n[1]    ), \
    .p1_subsystem_warm_rst_ack_n    (subsystem_warm_rst_ack_n[1]    ), \
    .p1_subsystem_rst_req           ('0                             ), \
    .p1_subsystem_rst_rdy           (                               ), \
    .p1_initiate_warmrst_req        (initiate_warmrst_req[1]        ), \
    .p1_initiate_rst_req_rdy        (initiate_warmrst_req[1]        ), \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_P1_APP_SS_ST_RX_TUSER_HALT    \
    .p1_app_ss_st_rx_tuser_halt     ('0                             ), \
   `endif                                                              \
    .p1_ss_app_st_rx_tvalid         (ss_app_st_rx_tvalid[1]         ), \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_ST_RX_HAS_TREADY                  \
    .p1_app_ss_st_rx_tready         (app_ss_st_rx_tready[1]         ), \
   `endif                                                              \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_RXCRDT                        \
    .p1_ss_app_st_rxcrdt_tvalid     (ss_app_st_rxcrdt_tvalid[1]     ), \
    .p1_ss_app_st_rxcrdt_tdata      (ss_app_st_rxcrdt_tdata[1]      ), \
   `endif                                                              \
    .p1_ss_app_st_rx_tdata          (ss_app_st_rx_tdata[1]          ), \
    .p1_ss_app_st_rx_tkeep          (ss_app_st_rx_tkeep[1]          ), \
    .p1_ss_app_st_rx_tlast          (ss_app_st_rx_tlast[1]          ), \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_RX_TUSER_VENDOR               \
    .p1_ss_app_st_rx_tuser_vendor   (ss_app_st_rx_tuser_vendor[1]   ), \
   `endif                                                              \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_RX_TUSER_HDR                  \
    .p1_ss_app_st_rx_tuser_hdr      (ss_app_st_rx_tuser_hdr[1]      ), \
   `endif                                                              \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_RX_TUSER_HVALID               \
    .p1_ss_app_st_rx_tuser_hvalid   (ss_app_st_rx_tuser_hvalid[1]   ), \
    .p1_ss_app_st_rx_tuser_last_segment(ss_app_st_rx_tuser_last_segment[1]), \
   `endif                                                              \
    .p1_app_ss_st_tx_tvalid         (app_ss_st_tx_tvalid[1]         ), \
    .p1_ss_app_st_tx_tready         (ss_app_st_tx_tready[1]         ), \
    .p1_app_ss_st_tx_tdata          (app_ss_st_tx_tdata[1]          ), \
    .p1_app_ss_st_tx_tkeep          (app_ss_st_tx_tkeep[1]          ), \
    .p1_app_ss_st_tx_tlast          (app_ss_st_tx_tlast[1]          ), \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_TX_TUSER_VENDOR               \
    .p1_app_ss_st_tx_tuser_vendor   (app_ss_st_tx_tuser_vendor[1]   ), \
   `endif                                                              \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_TX_TUSER_HDR                  \
    .p1_app_ss_st_tx_tuser_hdr      (app_ss_st_tx_tuser_hdr[1]      ), \
   `endif                                                              \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_TX_TUSER_HVALID               \
    .p1_app_ss_st_tx_tuser_hvalid   (app_ss_st_tx_tuser_hvalid[1]   ), \
    .p1_app_ss_st_tx_tuser_last_segment(app_ss_st_tx_tuser_last_segment[1]), \
   `endif                                                              \
    .p1_ss_app_st_flrrcvd_tvalid    (ss_app_st_flrrcvd_tvalid[1]    ), \
    .p1_ss_app_st_flrrcvd_tdata     (ss_app_st_flrrcvd_tdata[1]     ), \
    .p1_app_ss_st_flrcmpl_tvalid    (app_ss_st_flrcmpl_tvalid[1]    ), \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_FLRCMPL_HAS_TREADY                \
    .p1_ss_app_st_flrcmpl_tready    (ss_app_st_flrcmpl_tready[1]    ), \
   `endif                                                              \
    .p1_app_ss_st_flrcmpl_tdata     (app_ss_st_flrcmpl_tdata[1]     ), \
    .p1_ss_app_st_ctrlshadow_tvalid (ctrlshadow_tvalid[1]           ), \
    .p1_ss_app_st_ctrlshadow_tdata  (ctrlshadow_tdata[1]            ), \
    .p1_ss_app_st_txcrdt_tvalid     (                               ), \
    .p1_ss_app_st_txcrdt_tdata      (                               ), \
    .p1_ss_app_st_cplto_tvalid      (ss_app_st_cplto_tvalid[1]      ), \
    .p1_ss_app_st_cplto_tdata       (ss_app_st_cplto_tdata[1]       ), \
    .p1_app_ss_lite_csr_awvalid     (app_ss_lite_csr_awvalid[1]     ), \
    .p1_ss_app_lite_csr_awready     (ss_app_lite_csr_awready[1]     ), \
    .p1_app_ss_lite_csr_awaddr      (app_ss_lite_csr_awaddr[1]      ), \
    .p1_app_ss_lite_csr_wvalid      (app_ss_lite_csr_wvalid[1]      ), \
    .p1_ss_app_lite_csr_wready      (ss_app_lite_csr_wready[1]      ), \
    .p1_app_ss_lite_csr_wdata       (app_ss_lite_csr_wdata[1]       ), \
    .p1_app_ss_lite_csr_wstrb       (app_ss_lite_csr_wstrb[1]       ), \
    .p1_ss_app_lite_csr_bvalid      (ss_app_lite_csr_bvalid[1]      ), \
    .p1_app_ss_lite_csr_bready      (app_ss_lite_csr_bready[1]      ), \
    .p1_ss_app_lite_csr_bresp       (ss_app_lite_csr_bresp[1]       ), \
    .p1_app_ss_lite_csr_arvalid     (app_ss_lite_csr_arvalid[1]     ), \
    .p1_ss_app_lite_csr_arready     (ss_app_lite_csr_arready[1]     ), \
    .p1_app_ss_lite_csr_araddr      (app_ss_lite_csr_araddr[1]      ), \
    .p1_ss_app_lite_csr_rvalid      (ss_app_lite_csr_rvalid[1]      ), \
    .p1_app_ss_lite_csr_rready      (app_ss_lite_csr_rready[1]      ), \
    .p1_ss_app_lite_csr_rdata       (ss_app_lite_csr_rdata[1]       ), \
    .p1_ss_app_lite_csr_rresp       (ss_app_lite_csr_rresp[1]       ), \
    .p1_ss_app_dlup                 (ss_app_dlup[1]                 ), \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_CEB                           \
    .p1_ss_app_st_cebreq_tvalid     (ss_app_st_cebreq_tvalid[1]     ), \
    .p1_app_ss_st_cebreq_tready     (app_ss_st_cebreq_tready[1]     ), \
    .p1_ss_app_st_cebreq_tdata      (ss_app_st_cebreq_tdata[1]      ), \
    .p1_app_ss_st_cebresp_tvalid    (app_ss_st_cebresp_tvalid[1]    ), \
    .p1_app_ss_st_cebresp_tdata     (app_ss_st_cebresp_tdata[1]     ), \
   `endif                                                              \
                                                                       \
  `else /* !`ifdef OFS_FIM_IP_CFG_``SS_NAME``_EN_LINK_1 */             \
                                                                       \
    /* Second port is tied off and not used in OFS example */          \
    .p1_axi_st_clk                  (coreclkout_hip                 ), \
    .p1_axi_lite_clk                (csr_clk                        ), \
    .p1_axi_st_areset_n             (fim_rst_n[0]                   ), \
    .p1_axi_lite_areset_n           (csr_rst_n[0]                   ), \
    .p1_subsystem_cold_rst_n        (subsystem_cold_rst_n[0]        ), \
    .p1_subsystem_warm_rst_n        (subsystem_warm_rst_n[0]        ), \
    .p1_subsystem_cold_rst_ack_n    (                               ), \
    .p1_subsystem_warm_rst_ack_n    (                               ), \
    .p1_subsystem_rst_req           ('0                             ), \
    .p1_subsystem_rst_rdy           (                               ), \
    .p1_initiate_warmrst_req        (initiate_warmrst_req[1]        ), \
    .p1_initiate_rst_req_rdy        (initiate_warmrst_req[1]        ), \
    .p1_ss_app_st_rx_tvalid         (                               ), \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_ST_RX_HAS_TREADY                  \
    .p1_app_ss_st_rx_tready         (1'b1                           ), \
   `endif                                                              \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_RXCRDT                        \
    .p1_ss_app_st_rxcrdt_tvalid     (1'b0                           ), \
    .p1_ss_app_st_rxcrdt_tdata      ('0                             ), \
   `endif                                                              \
    .p1_ss_app_st_rx_tdata          (                               ), \
    .p1_ss_app_st_rx_tkeep          (                               ), \
    .p1_ss_app_st_rx_tlast          (                               ), \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_RX_TUSER_VENDOR               \
    .p1_ss_app_st_rx_tuser_vendor   (                               ), \
   `endif                                                              \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_RX_TUSER_HDR                  \
    .p1_ss_app_st_rx_tuser_hdr      (                               ), \
   `endif                                                              \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_RX_TUSER_HVALID               \
    .p1_ss_app_st_rx_tuser_hvalid   (                               ), \
    .p1_ss_app_st_rx_tuser_last_segment(                            ), \
   `endif                                                              \
    .p1_app_ss_st_tx_tvalid         ('0                             ), \
    .p1_ss_app_st_tx_tready         (                               ), \
    .p1_app_ss_st_tx_tdata          ('0                             ), \
    .p1_app_ss_st_tx_tkeep          ('0                             ), \
    .p1_app_ss_st_tx_tlast          ('0                             ), \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_TX_TUSER_VENDOR               \
    .p1_app_ss_st_tx_tuser_vendor   ('0                             ), \
   `endif                                                              \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_TX_TUSER_HDR                  \
    .p1_app_ss_st_tx_tuser_hdr      ('0                             ), \
   `endif                                                              \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_TX_TUSER_HVALID               \
    .p1_app_ss_st_tx_tuser_hvalid   ('0                             ), \
    .p1_app_ss_st_tx_tuser_last_segment('0                          ), \
   `endif                                                              \
    .p1_ss_app_st_flrrcvd_tvalid    (                               ), \
    .p1_ss_app_st_flrrcvd_tdata     (                               ), \
    .p1_app_ss_st_flrcmpl_tvalid    ('0                             ), \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_FLRCMPL_HAS_TREADY                \
    .p1_ss_app_st_flrcmpl_tready    (                               ), \
   `endif                                                              \
    .p1_app_ss_st_flrcmpl_tdata     ('0                             ), \
    .p1_ss_app_st_txcrdt_tvalid     (                               ), \
    .p1_ss_app_st_txcrdt_tdata      (                               ), \
    .p1_app_ss_lite_csr_awvalid     ('0                             ), \
    .p1_ss_app_lite_csr_awready     (                               ), \
    .p1_app_ss_lite_csr_awaddr      ('0                             ), \
    .p1_app_ss_lite_csr_wvalid      ('0                             ), \
    .p1_ss_app_lite_csr_wready      (                               ), \
    .p1_app_ss_lite_csr_wdata       ('0                             ), \
    .p1_app_ss_lite_csr_wstrb       ('0                             ), \
    .p1_ss_app_lite_csr_bvalid      (                               ), \
    .p1_app_ss_lite_csr_bready      ('0                             ), \
    .p1_ss_app_lite_csr_bresp       (                               ), \
    .p1_app_ss_lite_csr_arvalid     ('0                             ), \
    .p1_ss_app_lite_csr_arready     (                               ), \
    .p1_app_ss_lite_csr_araddr      ('0                             ), \
    .p1_ss_app_lite_csr_rvalid      (                               ), \
    .p1_app_ss_lite_csr_rready      ('0                             ), \
    .p1_ss_app_lite_csr_rdata       (                               ), \
    .p1_ss_app_lite_csr_rresp       (                               ), \
    .p1_ss_app_dlup                 (                               ), \
   `ifdef OFS_FIM_IP_CFG_``SS_NAME``_HAS_CEB                           \
    .p1_ss_app_st_cebreq_tvalid     (ss_app_st_cebreq_tvalid[1]     ), \
    .p1_app_ss_st_cebreq_tready     (app_ss_st_cebreq_tready[1]     ), \
    .p1_ss_app_st_cebreq_tdata      (ss_app_st_cebreq_tdata[1]      ), \
    .p1_app_ss_st_cebresp_tvalid    (app_ss_st_cebresp_tvalid[1]    ), \
    .p1_app_ss_st_cebresp_tdata     (app_ss_st_cebresp_tdata[1]     ), \
   `endif                                                              \
                                                                       \
  `endif /* !`ifdef OFS_FIM_IP_CFG_``SS_NAME``_EN_LINK_1 */            \
 `endif /* `ifdef OFS_FIM_IP_CFG_``SS_NAME``_NUM_PHYS_LINKS_IS_2 */    \
                                                                       \
    .tx_n_out0                      (pin_pcie.tx_n[0]               ), \
    .tx_n_out1                      (pin_pcie.tx_n[1]               ), \
    .tx_n_out2                      (pin_pcie.tx_n[2]               ), \
    .tx_n_out3                      (pin_pcie.tx_n[3]               ), \
   `ifdef ``SS_NAME``_NUM_LANES_GT_4                                  \
    .tx_n_out4                      (pin_pcie.tx_n[4]               ), \
    .tx_n_out5                      (pin_pcie.tx_n[5]               ), \
    .tx_n_out6                      (pin_pcie.tx_n[6]               ), \
    .tx_n_out7                      (pin_pcie.tx_n[7]               ), \
   `endif                                                              \
   `ifdef ``SS_NAME``_NUM_LANES_GT_8                                  \
    .tx_n_out8                      (pin_pcie.tx_n[8]               ), \
    .tx_n_out9                      (pin_pcie.tx_n[9]               ), \
    .tx_n_out10                     (pin_pcie.tx_n[10]              ), \
    .tx_n_out11                     (pin_pcie.tx_n[11]              ), \
    .tx_n_out12                     (pin_pcie.tx_n[12]              ), \
    .tx_n_out13                     (pin_pcie.tx_n[13]              ), \
    .tx_n_out14                     (pin_pcie.tx_n[14]              ), \
    .tx_n_out15                     (pin_pcie.tx_n[15]              ), \
   `endif                                                              \
    .tx_p_out0                      (pin_pcie.tx_p[0]               ), \
    .tx_p_out1                      (pin_pcie.tx_p[1]               ), \
    .tx_p_out2                      (pin_pcie.tx_p[2]               ), \
    .tx_p_out3                      (pin_pcie.tx_p[3]               ), \
   `ifdef ``SS_NAME``_NUM_LANES_GT_4                                  \
    .tx_p_out4                      (pin_pcie.tx_p[4]               ), \
    .tx_p_out5                      (pin_pcie.tx_p[5]               ), \
    .tx_p_out6                      (pin_pcie.tx_p[6]               ), \
    .tx_p_out7                      (pin_pcie.tx_p[7]               ), \
   `endif                                                              \
   `ifdef ``SS_NAME``_NUM_LANES_GT_8                                  \
    .tx_p_out8                      (pin_pcie.tx_p[8]               ), \
    .tx_p_out9                      (pin_pcie.tx_p[9]               ), \
    .tx_p_out10                     (pin_pcie.tx_p[10]              ), \
    .tx_p_out11                     (pin_pcie.tx_p[11]              ), \
    .tx_p_out12                     (pin_pcie.tx_p[12]              ), \
    .tx_p_out13                     (pin_pcie.tx_p[13]              ), \
    .tx_p_out14                     (pin_pcie.tx_p[14]              ), \
    .tx_p_out15                     (pin_pcie.tx_p[15]              ), \
   `endif                                                              \
    .rx_n_in0                       (pin_pcie.rx_n[0]               ), \
    .rx_n_in1                       (pin_pcie.rx_n[1]               ), \
    .rx_n_in2                       (pin_pcie.rx_n[2]               ), \
    .rx_n_in3                       (pin_pcie.rx_n[3]               ), \
   `ifdef ``SS_NAME``_NUM_LANES_GT_4                                  \
    .rx_n_in4                       (pin_pcie.rx_n[4]               ), \
    .rx_n_in5                       (pin_pcie.rx_n[5]               ), \
    .rx_n_in6                       (pin_pcie.rx_n[6]               ), \
    .rx_n_in7                       (pin_pcie.rx_n[7]               ), \
   `endif                                                              \
   `ifdef ``SS_NAME``_NUM_LANES_GT_8                                  \
    .rx_n_in8                       (pin_pcie.rx_n[8]               ), \
    .rx_n_in9                       (pin_pcie.rx_n[9]               ), \
    .rx_n_in10                      (pin_pcie.rx_n[10]              ), \
    .rx_n_in11                      (pin_pcie.rx_n[11]              ), \
    .rx_n_in12                      (pin_pcie.rx_n[12]              ), \
    .rx_n_in13                      (pin_pcie.rx_n[13]              ), \
    .rx_n_in14                      (pin_pcie.rx_n[14]              ), \
    .rx_n_in15                      (pin_pcie.rx_n[15]              ), \
   `endif                                                              \
    .rx_p_in0                       (pin_pcie.rx_p[0]               ), \
    .rx_p_in1                       (pin_pcie.rx_p[1]               ), \
    .rx_p_in2                       (pin_pcie.rx_p[2]               ), \
    .rx_p_in3                       (pin_pcie.rx_p[3]               ), \
   `ifdef ``SS_NAME``_NUM_LANES_GT_4                                  \
    .rx_p_in4                       (pin_pcie.rx_p[4]               ), \
    .rx_p_in5                       (pin_pcie.rx_p[5]               ), \
    .rx_p_in6                       (pin_pcie.rx_p[6]               ), \
    .rx_p_in7                       (pin_pcie.rx_p[7]               ), \
   `endif                                                              \
   `ifdef ``SS_NAME``_NUM_LANES_GT_8                                  \
    .rx_p_in8                       (pin_pcie.rx_p[8]               ), \
    .rx_p_in9                       (pin_pcie.rx_p[9]               ), \
    .rx_p_in10                      (pin_pcie.rx_p[10]              ), \
    .rx_p_in11                      (pin_pcie.rx_p[11]              ), \
    .rx_p_in12                      (pin_pcie.rx_p[12]              ), \
    .rx_p_in13                      (pin_pcie.rx_p[13]              ), \
    .rx_p_in14                      (pin_pcie.rx_p[14]              ), \
    .rx_p_in15                      (pin_pcie.rx_p[15]              ), \
   `endif                                                              \
    .ninit_done                     (ninit_done                     )  \


generate if (SOC_ATTACH == 0) begin : host_pcie
    pcie_ss pcie_ss(
        `PCIE_SS_AXIS_PORTS(PCIE_SS)
    );

  `ifndef OFS_FIM_IP_CFG_PCIE_SS_FLRCMPL_HAS_TREADY
    assign ss_app_st_flrcmpl_tready = {PCIE_NUM_LINKS{1'b1}};
  `endif

  `ifndef OFS_FIM_IP_CFG_PCIE_SS_HAS_CEB
    assign ss_app_st_cebreq_tvalid = {PCIE_NUM_LINKS{1'b0}};
  `endif
end
else begin : soc_pcie
    soc_pcie_ss pcie_ss(
        `PCIE_SS_AXIS_PORTS(SOC_PCIE_SS)
    );

  `ifndef OFS_FIM_IP_CFG_SOC_PCIE_SS_FLRCMPL_HAS_TREADY
    assign ss_app_st_flrcmpl_tready = {PCIE_NUM_LINKS{1'b1}};
  `endif

  `ifndef OFS_FIM_IP_CFG_SOC_PCIE_SS_HAS_CEB
    assign ss_app_st_cebreq_tvalid = {PCIE_NUM_LINKS{1'b0}};
  `endif
end
endgenerate
endmodule // pcie_ss_axis_top

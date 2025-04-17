// Copyright (C) 2020 Intel Corporation.
// SPDX-License-Identifier: MIT

//
// Description
//-----------------------------------------------------------------------------
//
// Memory Subsystem FIM wrapper
//
//-----------------------------------------------------------------------------

`include "ofs_fim_mem_defines.vh"
`include "ofs_ip_cfg_db.vh"

module mem_ss_top
   import ofs_fim_mem_if_pkg::*;
#(
   parameter bit [11:0] FEAT_ID         = 12'h00f,
   parameter bit [3:0]  FEAT_VER        = 4'h1,
   parameter bit [23:0] NEXT_DFH_OFFSET = 24'h1000,
   parameter bit        END_OF_LIST     = 1'b0
)(
   input  wire                  clk,
   input  wire                  reset,

   ofs_fim_emif_axi_mm_if.emif  afu_mem_if  [NUM_MEM_CHANNELS-1:0],

   ofs_fim_mem_ddr4_ref_clk_if.ip ddr4_mem_if_ref_clk [NUM_DDR4_CHANNELS-1:0],
`ifdef HAS_IFC_MEM_SS_MEM_DDR4_IF
   mem_ss_mem_ddr4_if.ip        ddr4_mem_if         [NUM_GROUP_0_DDR4_CHANNELS-1:0],
`endif
`ifdef HAS_IFC_MEM_SS_MEM_G1_DDR4_IF
   mem_ss_mem_g1_ddr4_if.ip     ddr4_mem_if_group_1 [NUM_GROUP_1_DDR4_CHANNELS-1:0],
`endif

`ifdef INCLUDE_HPS
   // HPS interfaces
   input  logic [4095:0]        hps2emif,
   input  logic [1:0]           hps2emif_gp,
   output logic [4095:0]        emif2hps,
   output logic                 emif2hps_gp,
`endif

   // CSR interfaces
   input                        clk_csr,
   input                        rst_n_csr,
   ofs_fim_axi_lite_if.slave    csr_lite_if
);

`ifndef __OFS_FIM_IP_CFG_LOCAL_MEM__
   $error("OFS Memory Subsystem configuration is undefined, but the subsystem has been instantiated in the design!");
`endif

   // Map memory subsystem channel index to interface index.
   // ip_cfg_db flags when to enable the fabric or HPS interface 
   // and which user interfaces are enabled in the memory crossbar.
   // (OFS defaults to 1-to-1 AXI-MEM interface mapping)

   // AXI-MM interface defined by mem_ss SystemVerilog wrapper module.
   mem_ss_i_axi_mm_if           ss_axi_mm[NUM_MEM_CHANNELS-1:0]();
   wire  [NUM_MEM_CHANNELS-1:0] mem_ss_app_usr_clk;
   wire  [NUM_MEM_CHANNELS-1:0] mem_ss_app_usr_reset_n;
 
   mem_ss_subsystem_reset_if    ss_reset_if();
   logic                        mem_ss_rst_init;

   mem_ss_mem_status_if         mem_ss_cal_status[NUM_MEM_CHANNELS-1:0]();
   logic [NUM_MEM_CHANNELS-1:0] mem_ss_cal_fail;
   logic [NUM_MEM_CHANNELS-1:0] mem_ss_cal_success;

   logic [NUM_MEM_CHANNELS-1:0] csr_cal_fail;
   logic [NUM_MEM_CHANNELS-1:0] csr_cal_success;

`ifdef HAS_IFC_MEM_SS_CSR_AXI_LITE_IF
   ofs_fim_axi_lite_if #(.AWADDR_WIDTH(11), .ARADDR_WIDTH(11), .WDATA_WIDTH(64)) emif_dfh_if();
`endif

   wire [NUM_DDR4_CHANNELS-1:0] mem_pll_ref_clk;
   wire [NUM_DDR4_CHANNELS-1:0] mem_oct_rzqin;
   for (genvar c = 0; c < NUM_DDR4_CHANNELS; c++) begin : ref_clk_map
      assign mem_pll_ref_clk[c] = ddr4_mem_if_ref_clk[c].clk;
      assign mem_oct_rzqin[c] = ddr4_mem_if_ref_clk[c].oct_rzqin;
   end


// The mem_ss IP doesn't have a clean way for naming the HPS interface port.
// For now, we extract the name using the OFS mem_ss_get_cfg.tcl script and
// save the HPS port's index in the macro OFS_FIM_IP_CFG_LOCAL_MEM_HPS_CHANNEL.
// These macros expand the channel number into the interface and port names.
`define HPS_IFC_NAME(NUM) mem_ss_mem``NUM``_hps_emif_if
`define HPS_PORT_NAME(NUM) mem``NUM``_hps_emif

   // Macro maps to the HPS interface name in the mem_ss IP SV wrapper.
`ifdef OFS_FIM_IP_CFG_LOCAL_MEM_HPS_CHANNEL
   `HPS_IFC_NAME(`OFS_FIM_IP_CFG_LOCAL_MEM_HPS_CHANNEL) hps_emif_if();
`endif

`ifdef INCLUDE_HPS
   assign hps_emif_if.hps_to_emif = hps2emif;
   assign hps_emif_if.gp_to_emif  = hps2emif_gp;
   assign emif2hps = hps_emif_if.emif_to_hps;
   assign emif2hps_gp = hps_emif_if.emif_to_gp;
`elsif OFS_FIM_IP_CFG_LOCAL_MEM_HPS_CHANNEL
   assign hps_emif_if.hps_to_emif = '0;
   assign hps_emif_if.gp_to_emif  = '0;
`endif

fim_resync #(
   .SYNC_CHAIN_LENGTH(3),
   .WIDTH(1),
   .INIT_VALUE(0),
   .NO_CUT(0)
) rst_hs_resync (
   .clk   (mem_pll_ref_clk[0]),
   .reset (1'b0),
   .d     (reset),
   .q     (mem_ss_rst_init)
);

for (genvar c = 0; c < NUM_MEM_CHANNELS; c++) begin : mem_ss_cal_map
   assign mem_ss_cal_success[c] = mem_ss_cal_status[c].success;
   assign mem_ss_cal_fail[c] = mem_ss_cal_status[c].fail;
end

fim_resync #(
   .SYNC_CHAIN_LENGTH(3),
   .WIDTH(NUM_MEM_CHANNELS),
   .INIT_VALUE(0),
   .NO_CUT(0)
) mem_ss_cal_success_resync (
   .clk   (clk_csr),
   .reset (!rst_n_csr),
   .d     (mem_ss_cal_success),
   .q     (csr_cal_success)
);

fim_resync #(
   .SYNC_CHAIN_LENGTH(3),
   .WIDTH(NUM_MEM_CHANNELS),
   .INIT_VALUE(0),
   .NO_CUT(0)
) mem_ss_cal_fail_resync (
   .clk   (clk_csr),
   .reset (!rst_n_csr),
   .d     (mem_ss_cal_fail),
   .q     (csr_cal_fail)
);

rst_hs rst_hs_inst (
   .clk      (mem_pll_ref_clk[0]),
   .rst_init (mem_ss_rst_init),
 `ifdef SIM_MODE_NO_MSS_RST
   .rst_req  (),
   .rst_n    (),
 `else
   .rst_req  (ss_reset_if.app_ss_rst_req),
   .rst_n    (ss_reset_if.app_ss_cold_rst_n),
 `endif
   .rst_rdy  (ss_reset_if.ss_app_rst_rdy),
   .rst_ack_n(ss_reset_if.ss_app_cold_rst_ack_n)
);

`ifdef SIM_MODE_NO_MSS_RST
   assign ss_reset_if.app_ss_rst_req    = 1'b0;
   assign ss_reset_if.app_ss_cold_rst_n = 1'b1;
`endif

mem_ss_csr #(
   .FEAT_ID          (FEAT_ID),
   .FEAT_VER         (FEAT_VER),
   .NEXT_DFH_OFFSET  (NEXT_DFH_OFFSET),
   .END_OF_LIST      (END_OF_LIST),
   .NUM_MEM_DEVICES  (NUM_MEM_CHANNELS)
) mem_ss_csr_inst (
   .clk              (clk_csr),
   .rst_n            (rst_n_csr),
`ifdef HAS_IFC_MEM_SS_CSR_AXI_LITE_IF
   .csr_lite_if      (emif_dfh_if),
`else
   .csr_lite_if      (csr_lite_if),
`endif
   .cal_fail         (csr_cal_fail),
   .cal_success      (csr_cal_success)
);


`ifdef HAS_IFC_MEM_SS_CSR_AXI_LITE_IF
   mem_ss_csr_axi_lite_if ss_csr_axi_lite_if();

   assign ss_csr_axi_lite_if.awaddr[22:11] = '0;
   assign ss_csr_axi_lite_if.araddr[22:11] = '0;

emif_csr_ic emif_csr_interconnect (
   .clk_clk     (clk_csr),
   .reset_reset (!rst_n_csr),

   // APF MemSS CSR interface (64b)
   .emif_csr_slv_awaddr    (csr_lite_if.awaddr),
   .emif_csr_slv_awprot    (csr_lite_if.awprot),
   .emif_csr_slv_awvalid   (csr_lite_if.awvalid),
   .emif_csr_slv_awready   (csr_lite_if.awready),
   .emif_csr_slv_wdata     (csr_lite_if.wdata),
   .emif_csr_slv_wstrb     (csr_lite_if.wstrb),
   .emif_csr_slv_wvalid    (csr_lite_if.wvalid),
   .emif_csr_slv_wready    (csr_lite_if.wready),
   .emif_csr_slv_bresp     (csr_lite_if.bresp),
   .emif_csr_slv_bvalid    (csr_lite_if.bvalid),
   .emif_csr_slv_bready    (csr_lite_if.bready),
   .emif_csr_slv_araddr    (csr_lite_if.araddr),
   .emif_csr_slv_arprot    (csr_lite_if.arprot),
   .emif_csr_slv_arvalid   (csr_lite_if.arvalid),
   .emif_csr_slv_arready   (csr_lite_if.arready),
   .emif_csr_slv_rdata     (csr_lite_if.rdata),
   .emif_csr_slv_rresp     (csr_lite_if.rresp),
   .emif_csr_slv_rvalid    (csr_lite_if.rvalid),
   .emif_csr_slv_rready    (csr_lite_if.rready),

   // Local DFH interface (32b)			  
   .emif_dfh_mst_awaddr    (emif_dfh_if.awaddr),
   .emif_dfh_mst_awprot    (emif_dfh_if.awprot),
   .emif_dfh_mst_awvalid   (emif_dfh_if.awvalid),
   .emif_dfh_mst_awready   (emif_dfh_if.awready),
   .emif_dfh_mst_wdata     (emif_dfh_if.wdata),
   .emif_dfh_mst_wstrb     (emif_dfh_if.wstrb),
   .emif_dfh_mst_wvalid    (emif_dfh_if.wvalid),
   .emif_dfh_mst_wready    (emif_dfh_if.wready),
   .emif_dfh_mst_bresp     (emif_dfh_if.bresp),
   .emif_dfh_mst_bvalid    (emif_dfh_if.bvalid),
   .emif_dfh_mst_bready    (emif_dfh_if.bready),
   .emif_dfh_mst_araddr    (emif_dfh_if.araddr),
   .emif_dfh_mst_arprot    (emif_dfh_if.arprot),
   .emif_dfh_mst_arvalid   (emif_dfh_if.arvalid),
   .emif_dfh_mst_arready   (emif_dfh_if.arready),
   .emif_dfh_mst_rdata     (emif_dfh_if.rdata),
   .emif_dfh_mst_rresp     (emif_dfh_if.rresp),
   .emif_dfh_mst_rvalid    (emif_dfh_if.rvalid),
   .emif_dfh_mst_rready    (emif_dfh_if.rready),

   // MemSS CSR interface (32b)			  
   .mem_ss_csr_mst_awaddr  (ss_csr_axi_lite_if.awaddr[10:0]),
   .mem_ss_csr_mst_awprot  (ss_csr_axi_lite_if.awprot),
   .mem_ss_csr_mst_awvalid (ss_csr_axi_lite_if.awvalid),
   .mem_ss_csr_mst_awready (ss_csr_axi_lite_if.awready),
   .mem_ss_csr_mst_wdata   (ss_csr_axi_lite_if.wdata),
   .mem_ss_csr_mst_wstrb   (ss_csr_axi_lite_if.wstrb),
   .mem_ss_csr_mst_wvalid  (ss_csr_axi_lite_if.wvalid),
   .mem_ss_csr_mst_wready  (ss_csr_axi_lite_if.wready),
   .mem_ss_csr_mst_bresp   (ss_csr_axi_lite_if.bresp),
   .mem_ss_csr_mst_bvalid  (ss_csr_axi_lite_if.bvalid),
   .mem_ss_csr_mst_bready  (ss_csr_axi_lite_if.bready),
   .mem_ss_csr_mst_araddr  (ss_csr_axi_lite_if.araddr[10:0]),
   .mem_ss_csr_mst_arprot  (ss_csr_axi_lite_if.arprot),
   .mem_ss_csr_mst_arvalid (ss_csr_axi_lite_if.arvalid),
   .mem_ss_csr_mst_arready (ss_csr_axi_lite_if.arready),
   .mem_ss_csr_mst_rdata   (ss_csr_axi_lite_if.rdata),
   .mem_ss_csr_mst_rresp   (ss_csr_axi_lite_if.rresp),
   .mem_ss_csr_mst_rvalid  (ss_csr_axi_lite_if.rvalid),
   .mem_ss_csr_mst_rready  (ss_csr_axi_lite_if.rready)
);
`endif

mem_ss_sv mem_ss_sv (
 `ifdef HAS_IFC_MEM_SS_CSR_AXI_LITE_IF
   .csr_app_ss_lite_aclk(),
   .csr_app_ss_lite_areset_n(),
   .csr_axi_lite(ss_csr_axi_lite_if),
 `endif

   .i_axi_mm(ss_axi_mm),

   .mem_ss_app_usr_clk,
   .mem_ss_app_usr_reset_n,

 `ifdef HAS_IFC_MEM_SS_MEM_DDR4_IF
   .mem_ddr4(ddr4_mem_if),
 `endif
 `ifdef HAS_IFC_MEM_SS_MEM_G1_DDR4_IF
   .mem_g1_ddr4(ddr4_mem_if_group_1),
 `endif

   .mem_pll_ref_clk,
   .mem_oct_rzqin,
   .mem_status(mem_ss_cal_status),

 `ifdef OFS_FIM_IP_CFG_LOCAL_MEM_HPS_CHANNEL
   .`HPS_PORT_NAME(`OFS_FIM_IP_CFG_LOCAL_MEM_HPS_CHANNEL) (hps_emif_if),
 `endif

   // MemSS Reset request
   .subsystem_reset(ss_reset_if)
);

// Map the OFS AXI-MM interface to the memory subsystem interface
for (genvar c = 0; c < NUM_MEM_CHANNELS; c++) begin : axi_mm_map
   assign afu_mem_if[c].clk     = mem_ss_app_usr_clk[c];
   assign afu_mem_if[c].rst_n   = mem_ss_app_usr_reset_n[c];

   // Write address channel
   assign afu_mem_if[c].awready = ss_axi_mm[c].awready;
   assign ss_axi_mm[c].awvalid  = afu_mem_if[c].awvalid;
   assign ss_axi_mm[c].awid     = afu_mem_if[c].awid;
   assign ss_axi_mm[c].awaddr   = afu_mem_if[c].awaddr;
   assign ss_axi_mm[c].awlen    = afu_mem_if[c].awlen;
   assign ss_axi_mm[c].awsize   = afu_mem_if[c].awsize;
   assign ss_axi_mm[c].awburst  = afu_mem_if[c].awburst;
   assign ss_axi_mm[c].awlock   = afu_mem_if[c].awlock;
   assign ss_axi_mm[c].awcache  = afu_mem_if[c].awcache;
   assign ss_axi_mm[c].awprot   = afu_mem_if[c].awprot;
   assign ss_axi_mm[c].awuser   = afu_mem_if[c].awuser;
   // Write data channel
   assign afu_mem_if[c].wready  = ss_axi_mm[c].wready;
   assign ss_axi_mm[c].wvalid   = afu_mem_if[c].wvalid;
   assign ss_axi_mm[c].wdata    = afu_mem_if[c].wdata;
   assign ss_axi_mm[c].wstrb    = afu_mem_if[c].wstrb;
   assign ss_axi_mm[c].wlast    = afu_mem_if[c].wlast;
   // Write response channel
   assign ss_axi_mm[c].bready   = afu_mem_if[c].bready;
   assign afu_mem_if[c].bvalid  = ss_axi_mm[c].bvalid;
   assign afu_mem_if[c].bid     = ss_axi_mm[c].bid;
   assign afu_mem_if[c].bresp   = ss_axi_mm[c].bresp;
   assign afu_mem_if[c].buser   = ss_axi_mm[c].buser;
   // Read address channel
   assign afu_mem_if[c].arready = ss_axi_mm[c].arready;
   assign ss_axi_mm[c].arvalid  = afu_mem_if[c].arvalid;
   assign ss_axi_mm[c].arid     = afu_mem_if[c].arid;
   assign ss_axi_mm[c].araddr   = afu_mem_if[c].araddr;
   assign ss_axi_mm[c].arlen    = afu_mem_if[c].arlen;
   assign ss_axi_mm[c].arsize   = afu_mem_if[c].arsize;
   assign ss_axi_mm[c].arburst  = afu_mem_if[c].arburst;
   assign ss_axi_mm[c].arlock   = afu_mem_if[c].arlock;
   assign ss_axi_mm[c].arcache  = afu_mem_if[c].arcache;
   assign ss_axi_mm[c].arprot   = afu_mem_if[c].arprot;
   assign ss_axi_mm[c].aruser   = afu_mem_if[c].aruser;
   // Read response channel
   assign ss_axi_mm[c].rready   = afu_mem_if[c].rready;
   assign afu_mem_if[c].rvalid  = ss_axi_mm[c].rvalid;
   assign afu_mem_if[c].rid     = ss_axi_mm[c].rid;
   assign afu_mem_if[c].rdata   = ss_axi_mm[c].rdata;
   assign afu_mem_if[c].rresp   = ss_axi_mm[c].rresp;
   assign afu_mem_if[c].rlast   = ss_axi_mm[c].rlast;
   assign afu_mem_if[c].ruser   = 'h0;
end

endmodule // mem_ss_top


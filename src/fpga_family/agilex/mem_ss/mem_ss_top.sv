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
   input                        clk,
   input                        reset,

   ofs_fim_emif_axi_mm_if.emif  afu_mem_if  [NUM_MEM_CHANNELS-1:0],

   ofs_fim_emif_ddr4_if.emif    ddr4_mem_if [NUM_MEM_CHANNELS-1:0],

`ifdef INCLUDE_HPS
   // HPS interfaces
   input  logic [4095:0]        hps2emif,
   input  logic [1:0]           hps2emif_gp,
   output logic [4095:0]        emif2hps,
   output logic                 emif2hps_gp,

   ofs_fim_hps_ddr4_if.emif     ddr4_hps_if,
`endif

   // CSR interfaces
   input                        clk_csr,
   input                        rst_n_csr,
   ofs_fim_axi_lite_if.slave    csr_lite_if
);

`ifndef __OFS_FIM_IP_CFG_MEM_SS__
   $error("OFS Memory Subsystem configuration is undefined, but the subsystem has been instantiated in the design!");
`endif

   // Map memory subsys channel index to interface index.
   // ip_cfg_db flags when to enable the fabric or HPS interface.
   enum {
`ifdef OFS_FIM_IP_CFG_MEM_SS_EN_MEM_0
      MEM_0,
`endif
`ifdef OFS_FIM_IP_CFG_MEM_SS_EN_MEM_1
      MEM_1,
`endif
`ifdef OFS_FIM_IP_CFG_MEM_SS_EN_MEM_2
      MEM_2,
`endif
`ifdef OFS_FIM_IP_CFG_MEM_SS_EN_MEM_3
      MEM_3,
`endif
`ifdef OFS_FIM_IP_CFG_MEM_SS_EN_MEM_4
      MEM_4,
`endif
`ifdef OFS_FIM_IP_CFG_MEM_SS_EN_MEM_5
      MEM_5,
`endif
`ifdef OFS_FIM_IP_CFG_MEM_SS_EN_MEM_6
      MEM_6,
`endif
`ifdef OFS_FIM_IP_CFG_MEM_SS_EN_MEM_7
      MEM_7,
`endif
`ifdef OFS_FIM_IP_CFG_MEM_SS_EN_MEM_8
      MEM_8,
`endif
      MEM_XXX
   } mem_idx;
   
   logic 			mem_ss_rst_n;
   logic 			mem_ss_rst_req;
   logic 			mem_ss_rst_rdy;
   logic 			mem_ss_rst_ack_n;
   logic 			mem_ss_rst_init;

   logic [NUM_MEM_CHANNELS-1:0] mem_ss_cal_fail;
   logic [NUM_MEM_CHANNELS-1:0] mem_ss_cal_success;

   logic [NUM_MEM_CHANNELS-1:0] csr_cal_fail;
   logic [NUM_MEM_CHANNELS-1:0] csr_cal_success;
   
   ofs_fim_axi_lite_if #(.AWADDR_WIDTH(11), .ARADDR_WIDTH(11), .WDATA_WIDTH(32)) ss_csr_lite_32b_if();
   ofs_fim_axi_lite_if #(.AWADDR_WIDTH(11), .ARADDR_WIDTH(11), .WDATA_WIDTH(64)) emif_dfh_if();

fim_resync #(
   .SYNC_CHAIN_LENGTH(3),
   .WIDTH(1),
   .INIT_VALUE(0),
   .NO_CUT(0)
) rst_hs_resync (
   .clk   (ddr4_mem_if[0].ref_clk),
   .reset (1'b0),
   .d     (reset),
   .q     (mem_ss_rst_init)
);

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
   .clk      (ddr4_mem_if[0].ref_clk),
   .rst_init (mem_ss_rst_init),
   .rst_req  (mem_ss_rst_req),
   .rst_rdy  (mem_ss_rst_rdy),
   .rst_n    (mem_ss_rst_n),
   .rst_ack_n(mem_ss_rst_ack_n)
);

mem_ss_csr #(
   .FEAT_ID          (FEAT_ID),
   .FEAT_VER         (FEAT_VER),
   .NEXT_DFH_OFFSET  (NEXT_DFH_OFFSET),
   .END_OF_LIST      (END_OF_LIST)
) mem_ss_csr_inst (
   .clk              (clk_csr),
   .rst_n            (rst_n_csr),
`ifdef OFS_FIM_IP_CFG_MEM_SS_EN_CSR
   .csr_lite_if      (emif_dfh_if),
`else
   .csr_lite_if      (csr_lite_if),
`endif
   .cal_fail         (csr_cal_fail),
   .cal_success      (csr_cal_success)
);

`ifdef OFS_FIM_IP_CFG_MEM_SS_EN_CSR
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
   .mem_ss_csr_mst_awaddr  (ss_csr_lite_32b_if.awaddr),
   .mem_ss_csr_mst_awprot  (ss_csr_lite_32b_if.awprot),
   .mem_ss_csr_mst_awvalid (ss_csr_lite_32b_if.awvalid),
   .mem_ss_csr_mst_awready (ss_csr_lite_32b_if.awready),
   .mem_ss_csr_mst_wdata   (ss_csr_lite_32b_if.wdata),
   .mem_ss_csr_mst_wstrb   (ss_csr_lite_32b_if.wstrb),
   .mem_ss_csr_mst_wvalid  (ss_csr_lite_32b_if.wvalid),
   .mem_ss_csr_mst_wready  (ss_csr_lite_32b_if.wready),
   .mem_ss_csr_mst_bresp   (ss_csr_lite_32b_if.bresp),
   .mem_ss_csr_mst_bvalid  (ss_csr_lite_32b_if.bvalid),
   .mem_ss_csr_mst_bready  (ss_csr_lite_32b_if.bready),
   .mem_ss_csr_mst_araddr  (ss_csr_lite_32b_if.araddr),
   .mem_ss_csr_mst_arprot  (ss_csr_lite_32b_if.arprot),
   .mem_ss_csr_mst_arvalid (ss_csr_lite_32b_if.arvalid),
   .mem_ss_csr_mst_arready (ss_csr_lite_32b_if.arready),
   .mem_ss_csr_mst_rdata   (ss_csr_lite_32b_if.rdata),
   .mem_ss_csr_mst_rresp   (ss_csr_lite_32b_if.rresp),
   .mem_ss_csr_mst_rvalid  (ss_csr_lite_32b_if.rvalid),
   .mem_ss_csr_mst_rready  (ss_csr_lite_32b_if.rready)
);
`endif   

mem_ss_fm mem_ss_fm_inst (
`ifdef OFS_FIM_IP_CFG_MEM_SS_EN_CSR
   // Subsystem CSR AXI4-lite interface
   .csr_app_ss_lite_aclk     (clk_csr),
   .csr_app_ss_lite_areset_n (rst_n_csr),
   .csr_app_ss_lite_awvalid  (    ss_csr_lite_32b_if.awvalid),
   .csr_app_ss_lite_awaddr   ({'b0,ss_csr_lite_32b_if.awaddr}),
   .csr_app_ss_lite_awprot   (    ss_csr_lite_32b_if.awprot),
   .csr_ss_app_lite_awready  (    ss_csr_lite_32b_if.awready),
   .csr_app_ss_lite_arvalid  (    ss_csr_lite_32b_if.arvalid),
   .csr_app_ss_lite_araddr   ({'b0,ss_csr_lite_32b_if.araddr}),
   .csr_app_ss_lite_arprot   (    ss_csr_lite_32b_if.arprot),
   .csr_ss_app_lite_arready  (    ss_csr_lite_32b_if.arready),
   .csr_app_ss_lite_wvalid   (    ss_csr_lite_32b_if.wvalid),
   .csr_app_ss_lite_wdata    (    ss_csr_lite_32b_if.wdata),
   .csr_app_ss_lite_wstrb    (    ss_csr_lite_32b_if.wstrb),
   .csr_ss_app_lite_wready   (    ss_csr_lite_32b_if.wready),
   .csr_ss_app_lite_bvalid   (    ss_csr_lite_32b_if.bvalid),
   .csr_ss_app_lite_bresp    (    ss_csr_lite_32b_if.bresp),
   .csr_app_ss_lite_bready   (    ss_csr_lite_32b_if.bready),
   .csr_ss_app_lite_rvalid   (    ss_csr_lite_32b_if.rvalid),
   .csr_ss_app_lite_rdata    (    ss_csr_lite_32b_if.rdata),
   .csr_ss_app_lite_rresp    (    ss_csr_lite_32b_if.rresp),
   .csr_app_ss_lite_rready   (    ss_csr_lite_32b_if.rready),
`endif

`ifdef OFS_FIM_IP_CFG_MEM_SS_EN_MEM_0
   // EMIF Calibration status
   .mem0_local_cal_success (mem_ss_cal_success[MEM_0]),
   .mem0_local_cal_fail    (mem_ss_cal_fail[MEM_0]),

   // AXI-MM clk/rst from EMIF
   .mem0_ss_app_usr_reset_n(afu_mem_if[MEM_0].rst_n),
   .mem0_ss_app_usr_clk    (afu_mem_if[MEM_0].clk),

   // Connect PD port to interface class with macro from ofs_fim_mem_plat_defines.svh
   // Macro args: input (to IP) port ID, output port ID, interface ID
   `CONNECT_OFS_FIM_AXI_MM_PORT(i0_app_ss_mm, i0_ss_app_mm, afu_mem_if[MEM_0]),
   `CONNECT_OFS_FIM_DDR4_PORT(mem0, mem0_ddr4, ddr4_mem_if[MEM_0]),
`endif

`ifdef OFS_FIM_IP_CFG_MEM_SS_EN_MEM_1
   .mem1_local_cal_success (mem_ss_cal_success [MEM_1]),
   .mem1_local_cal_fail    (mem_ss_cal_fail    [MEM_1]),

   .mem1_ss_app_usr_reset_n(afu_mem_if[MEM_1].rst_n),
   .mem1_ss_app_usr_clk    (afu_mem_if[MEM_1].clk),

   // Macro args: input (to IP) port ID, output port ID, interface ID
   `CONNECT_OFS_FIM_AXI_MM_PORT(i1_app_ss_mm, i1_ss_app_mm, afu_mem_if[MEM_1]),
   `CONNECT_OFS_FIM_DDR4_PORT(mem1, mem1_ddr4, ddr4_mem_if[MEM_1]),
`endif

`ifdef OFS_FIM_IP_CFG_MEM_SS_EN_MEM_2
   .mem2_local_cal_success (mem_ss_cal_success [MEM_2]),
   .mem2_local_cal_fail    (mem_ss_cal_fail    [MEM_2]),

   .mem2_ss_app_usr_reset_n(afu_mem_if[MEM_2].rst_n),
   .mem2_ss_app_usr_clk    (afu_mem_if[MEM_2].clk),

   // Macro args: input (to IP) port ID, output port ID, interface ID
   `CONNECT_OFS_FIM_AXI_MM_PORT(i2_app_ss_mm, i2_ss_app_mm, afu_mem_if[MEM_2]),
   `CONNECT_OFS_FIM_DDR4_PORT(mem2, mem2_ddr4, ddr4_mem_if[MEM_2]),
`endif

`ifdef OFS_FIM_IP_CFG_MEM_SS_EN_MEM_3
   .mem3_local_cal_success (mem_ss_cal_success [MEM_3]),
   .mem3_local_cal_fail    (mem_ss_cal_fail    [MEM_3]),

   .mem3_ss_app_usr_reset_n(afu_mem_if[MEM_3].rst_n),
   .mem3_ss_app_usr_clk    (afu_mem_if[MEM_3].clk),

   // Macro args: input (to IP) port ID, output port ID, interface ID
   `CONNECT_OFS_FIM_AXI_MM_PORT(i3_app_ss_mm, i3_ss_app_mm, afu_mem_if[MEM_3]),
   `CONNECT_OFS_FIM_DDR4_PORT(mem3, mem3_ddr4, ddr4_mem_if[MEM_3]),
`endif

`ifdef OFS_FIM_IP_CFG_MEM_SS_EN_MEM_4
   .mem4_local_cal_success (mem_ss_cal_success [MEM_4]),
   .mem4_local_cal_fail    (mem_ss_cal_fail    [MEM_4]),

   .mem4_ss_app_usr_reset_n(afu_mem_if[MEM_4].rst_n),
   .mem4_ss_app_usr_clk    (afu_mem_if[MEM_4].clk),

   // Macro args: input (to IP) port ID, output port ID, interface ID
   `CONNECT_OFS_FIM_AXI_MM_PORT(i4_app_ss_mm, i4_ss_app_mm, afu_mem_if[MEM_4]),
   `CONNECT_OFS_FIM_DDR4_PORT(mem4, mem4_ddr4, ddr4_mem_if[MEM_4]),
`endif

`ifdef OFS_FIM_IP_CFG_MEM_SS_EN_MEM_5
   .mem5_local_cal_success (mem_ss_cal_success [MEM_5]),
   .mem5_local_cal_fail    (mem_ss_cal_fail    [MEM_5]),

   .mem5_ss_app_usr_reset_n(afu_mem_if[MEM_5].rst_n),
   .mem5_ss_app_usr_clk    (afu_mem_if[MEM_5].clk),

   // Macro args: input (to IP) port ID, output port ID, interface ID
   `CONNECT_OFS_FIM_AXI_MM_PORT(i5_app_ss_mm, i5_ss_app_mm, afu_mem_if[MEM_5]),
   `CONNECT_OFS_FIM_DDR4_PORT(mem5, mem5_ddr4, ddr4_mem_if[MEM_5]),
`endif

`ifdef OFS_FIM_IP_CFG_MEM_SS_EN_MEM_6
   .mem6_local_cal_success (mem_ss_cal_success [MEM_6]),
   .mem6_local_cal_fail    (mem_ss_cal_fail    [MEM_6]),

   .mem6_ss_app_usr_reset_n(afu_mem_if[MEM_6].rst_n),
   .mem6_ss_app_usr_clk    (afu_mem_if[MEM_6].clk),

   // Macro args: input (to IP) port ID, output port ID, interface ID
   `CONNECT_OFS_FIM_AXI_MM_PORT(i6_app_ss_mm, i6_ss_app_mm, afu_mem_if[MEM_6]),
   `CONNECT_OFS_FIM_DDR4_PORT(mem6, mem6_ddr4, ddr4_mem_if[MEM_6]),
`endif

`ifdef OFS_FIM_IP_CFG_MEM_SS_EN_MEM_7
   .mem7_local_cal_success (mem_ss_cal_success [MEM_7]),
   .mem7_local_cal_fail    (mem_ss_cal_fail    [MEM_7]),

   .mem7_ss_app_usr_reset_n(afu_mem_if[MEM_7].rst_n),
   .mem7_ss_app_usr_clk    (afu_mem_if[MEM_7].clk),

   // Macro args: input (to IP) port ID, output port ID, interface ID
   `CONNECT_OFS_FIM_AXI_MM_PORT(i7_app_ss_mm, i7_ss_app_mm, afu_mem_if[MEM_7]),
   `CONNECT_OFS_FIM_DDR4_PORT(mem7, mem7_ddr4, ddr4_mem_if[MEM_7]),
`endif

`ifdef OFS_FIM_IP_CFG_MEM_SS_EN_MEM_8
   .mem8_local_cal_success (mem_ss_cal_success [MEM_8]),
   .mem8_local_cal_fail    (mem_ss_cal_fail    [MEM_8]),

   .mem8_ss_app_usr_reset_n(afu_mem_if[MEM_8].rst_n),
   .mem8_ss_app_usr_clk    (afu_mem_if[MEM_8].clk),

   // Macro args: input (to IP) port ID, output port ID, interface ID
   `CONNECT_OFS_FIM_AXI_MM_PORT(i8_app_ss_mm, i8_ss_app_mm, afu_mem_if[MEM_8]),
   `CONNECT_OFS_FIM_DDR4_PORT(mem8, mem8_ddr4, ddr4_mem_if[MEM_8]),
`endif

`ifdef INCLUDE_HPS
`ifdef OFS_FIM_IP_CFG_MEM_SS_HPS_EMIF_IS_MEM_0
   // CH0 EMIF HPS conduit
   .mem0_hps_to_emif     (hps2emif),
   .mem0_emif_to_hps     (emif2hps),
   .mem0_hps_to_emif_gp  (hps2emif_gp),
   .mem0_emif_to_hps_gp  (emif2hps_gp),

   // Macro args: input (to IP) port ID, output port ID, interface ID
   `CONNECT_OFS_FIM_DDR4_PORT(mem0, mem0_ddr4, ddr4_hps_if),
`endif

`ifdef OFS_FIM_IP_CFG_MEM_SS_HPS_EMIF_IS_MEM_1
   // CH0 EMIF HPS conduit
   .mem1_hps_to_emif     (hps2emif),
   .mem1_emif_to_hps     (emif2hps),
   .mem1_hps_to_emif_gp  (hps2emif_gp),
   .mem1_emif_to_hps_gp  (emif2hps_gp),

   // Macro args: input (to IP) port ID, output port ID, interface ID
   `CONNECT_OFS_FIM_DDR4_PORT(mem1, mem1_ddr4, ddr4_hps_if),
`endif

`ifdef OFS_FIM_IP_CFG_MEM_SS_HPS_EMIF_IS_MEM_2
   // CH2 EMIF HPS conduit
   .mem2_hps_to_emif     (hps2emif),
   .mem2_emif_to_hps     (emif2hps),
   .mem2_hps_to_emif_gp  (hps2emif_gp),
   .mem2_emif_to_hps_gp  (emif2hps_gp),

   // Macro args: input (to IP) port ID, output port ID, interface ID
   `CONNECT_OFS_FIM_DDR4_PORT(mem2, mem2_ddr4, ddr4_hps_if),
`endif

`ifdef OFS_FIM_IP_CFG_MEM_SS_HPS_EMIF_IS_MEM_3
   // CH3 EMIF HPS conduit
   .mem3_hps_to_emif     (hps2emif),
   .mem3_emif_to_hps     (emif2hps),
   .mem3_hps_to_emif_gp  (hps2emif_gp),
   .mem3_emif_to_hps_gp  (emif2hps_gp),

   // Macro args: input (to IP) port ID, output port ID, interface ID
   `CONNECT_OFS_FIM_DDR4_PORT(mem3, mem3_ddr4, ddr4_hps_if),
`endif

`ifdef OFS_FIM_IP_CFG_MEM_SS_HPS_EMIF_IS_MEM_4
   // CH4 EMIF HPS conduit
   .mem4_hps_to_emif     (hps2emif),
   .mem4_emif_to_hps     (emif2hps),
   .mem4_hps_to_emif_gp  (hps2emif_gp),
   .mem4_emif_to_hps_gp  (emif2hps_gp),

   // Macro args: input (to IP) port ID, output port ID, interface ID
   `CONNECT_OFS_FIM_DDR4_PORT(mem4, mem4_ddr4, ddr4_hps_if),
`endif

`ifdef OFS_FIM_IP_CFG_MEM_SS_HPS_EMIF_IS_MEM_5
   // CH5 EMIF HPS conduit
   .mem5_hps_to_emif     (hps2emif),
   .mem5_emif_to_hps     (emif2hps),
   .mem5_hps_to_emif_gp  (hps2emif_gp),
   .mem5_emif_to_hps_gp  (emif2hps_gp),

   // Macro args: input (to IP) port ID, output port ID, interface ID
   `CONNECT_OFS_FIM_DDR4_PORT(mem5, mem5_ddr4, ddr4_hps_if),
`endif

`ifdef OFS_FIM_IP_CFG_MEM_SS_HPS_EMIF_IS_MEM_6
   // CH6 EMIF HPS conduit
   .mem6_hps_to_emif     (hps2emif),
   .mem6_emif_to_hps     (emif2hps),
   .mem6_hps_to_emif_gp  (hps2emif_gp),
   .mem6_emif_to_hps_gp  (emif2hps_gp),

   // Macro args: input (to IP) port ID, output port ID, interface ID
   `CONNECT_OFS_FIM_DDR4_PORT(mem6, mem6_ddr4, ddr4_hps_if),
`endif

`ifdef OFS_FIM_IP_CFG_MEM_SS_HPS_EMIF_IS_MEM_7
   // CH7 EMIF HPS conduit
   .mem7_hps_to_emif     (hps2emif),
   .mem7_emif_to_hps     (emif2hps),
   .mem7_hps_to_emif_gp  (hps2emif_gp),
   .mem7_emif_to_hps_gp  (emif2hps_gp),

   // Macro args: input (to IP) port ID, output port ID, interface ID
   `CONNECT_OFS_FIM_DDR4_PORT(mem7, mem7_ddr4, ddr4_hps_if),
`endif

`ifdef OFS_FIM_IP_CFG_MEM_SS_HPS_EMIF_IS_MEM_8
   // CH8 EMIF HPS conduit
   .mem8_hps_to_emif     (hps2emif),
   .mem8_emif_to_hps     (emif2hps),
   .mem8_hps_to_emif_gp  (hps2emif_gp),
   .mem8_emif_to_hps_gp  (emif2hps_gp),

   // Macro args: input (to IP) port ID, output port ID, interface ID
   `CONNECT_OFS_FIM_DDR4_PORT(mem8, mem8_ddr4, ddr4_hps_if),
`endif

`endif //  `ifdef INCLUDE_HPS
			  
   // MemSS Reset request
`ifdef SIM_MODE_NO_MSS_RST
   .app_ss_rst_req        (1'b0),
   .app_ss_cold_rst_n     (1'b1),
`else
   .app_ss_rst_req        (mem_ss_rst_req),
   .app_ss_cold_rst_n     (mem_ss_rst_n),
`endif
   .ss_app_rst_rdy        (mem_ss_rst_rdy),
   .ss_app_cold_rst_ack_n (mem_ss_rst_ack_n)
);
   
endmodule // mem_ss_top


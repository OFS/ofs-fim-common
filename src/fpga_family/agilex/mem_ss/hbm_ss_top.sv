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

module hbm_ss_top
   import ofs_fim_mem_if_pkg::*;
#(
   parameter bit [11:0] FEAT_ID         = 12'h00f,
   parameter bit [3:0]  FEAT_VER        = 4'h1,
   parameter bit [23:0] NEXT_DFH_OFFSET = 24'h1000,
   parameter bit        END_OF_LIST     = 1'b0
)(
   input       reset,

   input       uib_refclk      [NUM_HBM_DEVICES-1:0],
   input       fab_clk         [NUM_HBM_DEVICES-1:0],
   input       fab_clk_wr      [NUM_HBM_DEVICES-1:0],
   input       noc_ctrl_refclk [NUM_HBM_DEVICES-1:0],

   input       hbm_cattrip [NUM_HBM_DEVICES-1:0],
   input [2:0] hbm_temp    [NUM_HBM_DEVICES-1:0],

   ofs_fim_emif_axi_mm_if.emif afu_mem_if [NUM_MEM_CHANNELS-1:0],

   input       clk_csr,
   input       rst_n_csr,
   ofs_fim_axi_lite_if.slave    csr_lite_if

);

`ifndef __OFS_FIM_IP_CFG_LOCAL_MEM__
   $error("OFS HBM Subsystem configuration is undefined, but the subsystem has been instantiated in the design!");
`endif

   // AXI-MM interface defined by the NoC SystemVerilog wrapper module.
   hbm_ss_i_app_if ss_axi_mm[NUM_MEM_CHANNELS-1:0]();

   logic [NUM_HBM_DEVICES-1:0] hbm_cal_fail;
   logic [NUM_HBM_DEVICES-1:0] hbm_cal_success;

   logic [NUM_HBM_DEVICES-1:0] csr_cal_fail;
   logic [NUM_HBM_DEVICES-1:0] csr_cal_success;

fim_resync #(
   .SYNC_CHAIN_LENGTH(3),
   .WIDTH(NUM_MEM_CHANNELS),
   .INIT_VALUE(0),
   .NO_CUT(0)
) mem_ss_cal_success_resync (
   .clk   (clk_csr),
   .reset (!rst_n_csr),
   .d     (hbm_cal_success),
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
   .d     (hbm_cal_fail),
   .q     (csr_cal_fail)
);

mem_ss_csr #(
   .FEAT_ID          (FEAT_ID),
   .FEAT_VER         (FEAT_VER),
   .NEXT_DFH_OFFSET  (NEXT_DFH_OFFSET),
   .END_OF_LIST      (END_OF_LIST),
   .NUM_MEM_DEVICES  (NUM_HBM_DEVICES)
) mem_ss_csr_inst (
   .clk              (clk_csr),
   .rst_n            (rst_n_csr),
   .csr_lite_if      (csr_lite_if),
   .cal_fail         (csr_cal_fail),
   .cal_success      (csr_cal_success)
);

// AXI-MM application channel connections
// Macros are used to declare and connect the OFS interface types
// to wires which are implicitly connected to the PD component ports

// Connect clock/reset
wire [NUM_MEM_CHANNELS-1:0] i_app_clk_clk;
wire [NUM_MEM_CHANNELS-1:0] i_app_rst_n_reset_n;

generate for(genvar ch = 0; ch < NUM_MEM_CHANNELS; ch++) begin : mem_clk_rst
   assign afu_mem_if[ch].clk = fab_clk[0];
   fim_dup_tree dup_rst ( .clk( afu_mem_if[ch].clk ), .din( ~reset ), .dout( afu_mem_if[ch].rst_n ));

   assign i_app_clk_clk[ch] = afu_mem_if[ch].clk;
   assign i_app_rst_n_reset_n[ch] = afu_mem_if[ch].rst_n;
end
endgenerate


   // HBM/NoC signals
   logic [NUM_HBM_DEVICES-1:0] hbm_fab_clk_clk;
   logic [NUM_HBM_DEVICES-1:0] hbm_rst_n_reset_n;
   logic [NUM_HBM_DEVICES-1:0] hbm_cattrip_conduit;
   logic [NUM_HBM_DEVICES-1:0] [2:0] hbm_temp_conduit;
   logic [NUM_HBM_DEVICES-1:0] hbm_uib_clk_clk;
   logic [NUM_HBM_DEVICES-1:0] noc_ctrl_clk;
   logic [NUM_HBM_DEVICES-1:0] noc_noc_bridge_fabric_clk_clk;

generate for(genvar d = 0; d < NUM_HBM_DEVICES; d++) begin : hbm_clk_rst
   assign hbm_fab_clk_clk[d] = fab_clk[d];
   assign hbm_rst_n_reset_n[d] = ~reset;
   assign hbm_cattrip_conduit[d] = hbm_cattrip[d];
   assign hbm_temp_conduit[d] = hbm_temp[d];
   assign hbm_uib_clk_clk[d] = uib_refclk[d];
   assign noc_ctrl_clk[d] = noc_ctrl_refclk[d];
   assign noc_noc_bridge_fabric_clk_clk[d] = fab_clk_wr[d];
end
endgenerate

hbm_ss_sv hbm_ss_sv (
   .hbm_fab_clk_clk,
   .hbm_rst_n_reset_n,
   .hbm_cattrip_conduit,
   .hbm_temp_conduit,
   .hbm_uib_clk_clk,
   .noc_ctrl_clk,
   .noc_noc_bridge_fabric_clk_clk,

   .hbm_local_cal_success_local_cal_success(hbm_cal_success),
   .hbm_local_cal_fail_local_cal_fail(hbm_cal_fail),

   .i_app(ss_axi_mm),
   .i_app_clk_clk,
   .i_app_rst_n_reset_n
 );

// Map the OFS AXI-MM interface to the memory subsystem interface.
// Clock and reset are connected in a generate block above.
for (genvar c = 0; c < NUM_MEM_CHANNELS; c++) begin : axi_mm_map
   // Write address channel
   assign afu_mem_if[c].awready = ss_axi_mm[c].awready;
   assign ss_axi_mm[c].awvalid  = afu_mem_if[c].awvalid;
   assign ss_axi_mm[c].awid     = afu_mem_if[c].awid;
   assign ss_axi_mm[c].awaddr   = afu_mem_if[c].awaddr;
   assign ss_axi_mm[c].awlen    = { '0, afu_mem_if[c].awlen }; // OFS may use a narrower burst width
   assign ss_axi_mm[c].awsize   = afu_mem_if[c].awsize;
   assign ss_axi_mm[c].awburst  = afu_mem_if[c].awburst;
   assign ss_axi_mm[c].awlock   = afu_mem_if[c].awlock;
   assign ss_axi_mm[c].awprot   = afu_mem_if[c].awprot;
   assign ss_axi_mm[c].awuser   = afu_mem_if[c].awuser;
   // Write data channel
   assign afu_mem_if[c].wready  = ss_axi_mm[c].wready;
   assign ss_axi_mm[c].wvalid   = afu_mem_if[c].wvalid;
   assign ss_axi_mm[c].wdata    = afu_mem_if[c].wdata;
   assign ss_axi_mm[c].wstrb    = afu_mem_if[c].wstrb;
   assign ss_axi_mm[c].wlast    = afu_mem_if[c].wlast;
   assign ss_axi_mm[c].wuser    = '0;
   // Write response channel
   assign ss_axi_mm[c].bready   = afu_mem_if[c].bready;
   assign afu_mem_if[c].bvalid  = ss_axi_mm[c].bvalid;
   assign afu_mem_if[c].bid     = ss_axi_mm[c].bid;
   assign afu_mem_if[c].bresp   = ss_axi_mm[c].bresp;
 `ifdef IFC_MEM_SS_I_AXI_MM_IF_WIDTH_RUSER
   assign afu_mem_if[c].buser   = ss_axi_mm[c].buser;
 `else
   assign afu_mem_if[c].buser   = '0;
 `endif
   // Read address channel
   assign afu_mem_if[c].arready = ss_axi_mm[c].arready;
   assign ss_axi_mm[c].arvalid  = afu_mem_if[c].arvalid;
   assign ss_axi_mm[c].arid     = afu_mem_if[c].arid;
   assign ss_axi_mm[c].araddr   = afu_mem_if[c].araddr;
   assign ss_axi_mm[c].arlen    = { '0, afu_mem_if[c].arlen }; // OFS may use a narrower burst width
   assign ss_axi_mm[c].arsize   = afu_mem_if[c].arsize;
   assign ss_axi_mm[c].arburst  = afu_mem_if[c].arburst;
   assign ss_axi_mm[c].arlock   = afu_mem_if[c].arlock;
   assign ss_axi_mm[c].arprot   = afu_mem_if[c].arprot;
   assign ss_axi_mm[c].aruser   = afu_mem_if[c].aruser;
   assign ss_axi_mm[c].arqos   = '0;
   // Read response channel
   assign ss_axi_mm[c].rready   = afu_mem_if[c].rready;
   assign afu_mem_if[c].rvalid  = ss_axi_mm[c].rvalid;
   assign afu_mem_if[c].rid     = ss_axi_mm[c].rid;
   assign afu_mem_if[c].rdata   = ss_axi_mm[c].rdata;
   assign afu_mem_if[c].rresp   = ss_axi_mm[c].rresp;
   assign afu_mem_if[c].rlast   = ss_axi_mm[c].rlast;
   assign afu_mem_if[c].ruser   = ss_axi_mm[c].ruser;
end
      
endmodule // mem_ss_top

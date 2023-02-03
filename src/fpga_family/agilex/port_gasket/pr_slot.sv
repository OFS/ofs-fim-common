// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// Partial Reconfiguration Slot
//-----------------------------------------------------------------------------

import pcie_ss_axis_pkg::*;
import ofs_fim_eth_if_pkg::*;

module  pr_slot #(
   parameter PG_NUM_PORTS      = 1,  // Number of PCIe VF ports to PR region
   // PF/VF to which each port is mapped
   parameter pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t[PG_NUM_PORTS-1:0] PORT_PF_VF_INFO =
                {PG_NUM_PORTS{pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t'(0)}},

   parameter EMIF              = 0,  // Emif enable
   parameter NUM_MEM_CH        = 2,  // Number of memory channel
   parameter PL_DEPTH          = 1,  // PCIe Port pipeline depth before PR region crossing
   parameter TDATA_WIDTH       = pcie_ss_axis_pkg::TDATA_WIDTH,
   parameter TUSER_WIDTH       = pcie_ss_axis_pkg::TUSER_WIDTH
)(
   // Clocks and Resets
   input                       clk,
   input                       clk_div2,
   input                       clk_div4,
   input                       uclk_usr,
   input                       uclk_usr_div2,
   input                       rst_n,
   input                       softreset,
   input  logic [PG_NUM_PORTS-1:0] port_rst_n,

   // PR region freeze signal for isolation
   input                       pr_freeze,
   
   // Memory
`ifdef INCLUDE_DDR4
   ofs_fim_emif_axi_mm_if.user afu_mem_if  [NUM_MEM_CH-1:0],
`endif

   // PCIe 
   pcie_ss_axis_if.source      axi_tx_a_if [PG_NUM_PORTS-1:0],
   pcie_ss_axis_if.sink        axi_rx_a_if [PG_NUM_PORTS-1:0],
   pcie_ss_axis_if.source      axi_tx_b_if [PG_NUM_PORTS-1:0],
   pcie_ss_axis_if.sink        axi_rx_b_if [PG_NUM_PORTS-1:0],
 
   // HSSI
`ifdef INCLUDE_HSSI
    ofs_fim_hssi_ss_tx_axis_if.client     hssi_ss_st_tx [MAX_NUM_ETH_CHANNELS-1:0],
    ofs_fim_hssi_ss_rx_axis_if.client     hssi_ss_st_rx [MAX_NUM_ETH_CHANNELS-1:0],
    ofs_fim_hssi_fc_if.client             hssi_fc [MAX_NUM_ETH_CHANNELS-1:0],
    input logic [MAX_NUM_ETH_CHANNELS-1:0] i_hssi_clk_pll,
`endif

   // JTAG interface for PR region remote STP support
   ofs_jtag_if.sink            remote_stp_jtag_if

);

   // MM Bridge configurations
   localparam MM_BYPASS        = 2;
   localparam MM_SIMPLE_BUFFER = 1;
   localparam MM_SKID_BUFFER   = 0;

   // ST Bridge configurations
   localparam ST_BYPASS        = 3;
   localparam ST_SIMPLE_BUFFER_1 = 2;
   localparam ST_SIMPLE_BUFFER_0 = 1;
   localparam ST_SKID_BUFFER   = 0;

   `ifdef INCLUDE_PR
        parameter PR_FREEZE_DIS = 0;
   `else 
        parameter PR_FREEZE_DIS = 1;
    `endif

   logic pr_freeze_emif_q0, pr_freeze_emif_q1;
   logic [MAX_NUM_ETH_CHANNELS-1:0] pr_freeze_hssi;
   logic [MAX_NUM_ETH_CHANNELS-1:0] softreset_hssi;
   logic pr_freeze_emif[NUM_MEM_CH-1: 0];
   logic softreset_emif[NUM_MEM_CH-1: 0];

// ----------------------------------------------------------------------------------------------------
//  PR Freeze Logic
//  - Implemented only in Tx direction.
// ----------------------------------------------------------------------------------------------------


// ----------------------------------------------------------------------------------------------------
// 1. PR Freeze: PCIe ports to PFVF-Mux
// ----------------------------------------------------------------------------------------------------
`ifdef INCLUDE_PR 
    parameter PCIE_RX_REG_MODE    =ST_SKID_BUFFER; 
    parameter PCIE_TX_REG_MODE    =ST_SKID_BUFFER; 
`else // INCLUDE_PR
    parameter PCIE_RX_REG_MODE    =ST_BYPASS; 
    parameter PCIE_TX_REG_MODE    =ST_BYPASS; 
`endif //INCLUDE_PR

logic               pr_freeze_fnmx_q0, pr_freeze_fnmx_q1;
pcie_ss_axis_if     axi_tx_a_if_t1            [PG_NUM_PORTS-1:0]();
pcie_ss_axis_if     axi_rx_a_if_t1            [PG_NUM_PORTS-1:0]();
pcie_ss_axis_if     axi_tx_b_if_t1            [PG_NUM_PORTS-1:0]();
pcie_ss_axis_if     axi_rx_b_if_t1            [PG_NUM_PORTS-1:0]();

logic [PG_NUM_PORTS-1:0] port_rst_n_t1;

// Flop freeze signal
always_ff @ (posedge clk) begin
   pr_freeze_fnmx_q1   <= pr_freeze_fnmx_q0;
   pr_freeze_fnmx_q0   <= pr_freeze;
end

for (genvar j=0; j<PG_NUM_PORTS; j++) begin

   // Port A
   axis_pcie_pr_freeze_bridge #(
      .TDATA_WIDTH (TDATA_WIDTH),
      .TUSER_WIDTH (TUSER_WIDTH),
      .PL_DEPTH    (PL_DEPTH),
      .PR_FREEZE_DIS (PR_FREEZE_DIS),
      .RX_REG_MODE (PCIE_RX_REG_MODE),
      .TX_REG_MODE (PCIE_TX_REG_MODE)
   ) pr_frz_afu_pcie_a_port (
      .port_rst_n  (port_rst_n[j]),
      .pr_freeze   (pr_freeze_fnmx_q1),
      .axi_rx_if_s (axi_rx_a_if[j]),    // <--- PCIe SS
      .axi_tx_if_m (axi_tx_a_if[j]),    // ---> PCIe SS
      .axi_rx_if_m (axi_rx_a_if_t1[j]), // ---> PR slot AFU 
      .axi_tx_if_s (axi_tx_a_if_t1[j])  // <--- PR slot AFU
   );

   // Port B
   axis_pcie_pr_freeze_bridge #(
      .TDATA_WIDTH (TDATA_WIDTH),
      .TUSER_WIDTH (TUSER_WIDTH),
      .PL_DEPTH    (PL_DEPTH),
      .PR_FREEZE_DIS (PR_FREEZE_DIS),
      .RX_REG_MODE (PCIE_RX_REG_MODE),
      .TX_REG_MODE (PCIE_TX_REG_MODE)
   ) pr_frz_afu_pcie_b_port (
      .port_rst_n  (port_rst_n[j]),
      .pr_freeze   (pr_freeze_fnmx_q1),
      .axi_rx_if_s (axi_rx_b_if[j]),    // <--- PCIe SS
      .axi_tx_if_m (axi_tx_b_if[j]),    // ---> PCIe SS
      .axi_rx_if_m (axi_rx_b_if_t1[j]), // ---> PR slot AFU 
      .axi_tx_if_s (axi_tx_b_if_t1[j])  // <--- PR slot AFU
   );

   // Assign clk & resets to interface package
   // rst_n from PCIe SS needs to be replaced with port_rst_n
   assign axi_rx_a_if_t1[j].clk     = axi_rx_a_if[j].clk;
   assign axi_rx_a_if_t1[j].rst_n   = port_rst_n_t1[j];
   assign axi_tx_a_if_t1[j].clk     = axi_tx_a_if[j].clk;
   assign axi_tx_a_if_t1[j].rst_n   = port_rst_n_t1[j];

   assign axi_rx_b_if_t1[j].clk     = axi_rx_b_if[j].clk;
   assign axi_rx_b_if_t1[j].rst_n   = port_rst_n_t1[j];
   assign axi_tx_b_if_t1[j].clk     = axi_tx_b_if[j].clk;
   assign axi_tx_b_if_t1[j].rst_n   = port_rst_n_t1[j];
   
   always @(posedge clk) begin
      port_rst_n_t1[j] <= port_rst_n[j];
   end
end


// ----------------------------------------------------------------------------------------------------
// 2. PR Freeze: AFU-MEM_IF to MEM SS
// ----------------------------------------------------------------------------------------------------
`ifdef INCLUDE_DDR4
    
    `ifdef INCLUDE_PR 
        parameter W_REG_MODE     =MM_SKID_BUFFER; 
        parameter R_REG_MODE     =MM_SKID_BUFFER; 
        parameter AW_REG_MODE    =MM_SKID_BUFFER; 
        parameter B_REG_MODE     =MM_SKID_BUFFER; 
        parameter AR_REG_MODE    =MM_SKID_BUFFER; 
    `else // INCLUDE_PR
        parameter W_REG_MODE     =MM_BYPASS; 
        parameter R_REG_MODE     =MM_BYPASS; 
        parameter AW_REG_MODE    =MM_BYPASS; 
        parameter B_REG_MODE     =MM_BYPASS; 
        parameter AR_REG_MODE    =MM_BYPASS; 
    `endif //INCLUDE_PR

   ofs_fim_emif_axi_mm_if #(
      .AWID_WIDTH   ($bits(afu_mem_if[0].awid)),
      .AWADDR_WIDTH ($bits(afu_mem_if[0].awaddr)),
      .AWUSER_WIDTH ($bits(afu_mem_if[0].awuser)),
      .WDATA_WIDTH  ($bits(afu_mem_if[0].wdata)),
      .BUSER_WIDTH  ($bits(afu_mem_if[0].buser)),
      .ARID_WIDTH   ($bits(afu_mem_if[0].arid)),
      .ARADDR_WIDTH ($bits(afu_mem_if[0].araddr)),
      .ARUSER_WIDTH ($bits(afu_mem_if[0].aruser)),
      .RDATA_WIDTH  ($bits(afu_mem_if[0].rdata)),
      .RUSER_WIDTH  ($bits(afu_mem_if[0].ruser)) 
   ) afu_main_emif [NUM_MEM_CH-1:0]();

   // Flop freeze signal
   always_ff @ (posedge clk) begin
      pr_freeze_emif_q1   <= pr_freeze_emif_q0;
      pr_freeze_emif_q0   <= pr_freeze;
   end

   for (genvar j=0; j<NUM_MEM_CH; j++) begin : afu_mem
      fim_resync #(
         .SYNC_CHAIN_LENGTH (2),
         .WIDTH             (1),
         .INIT_VALUE        (0),
         .NO_CUT            (0)
      ) ddr4_pr_freeze_sync (
         .clk   (afu_mem_if[j].clk),
         .reset (1'b0),
         .d     (pr_freeze_emif_q1),
         .q     (pr_freeze_emif[j])
      );

      fim_resync #(
         .SYNC_CHAIN_LENGTH (2),
         .WIDTH             (1),
         .INIT_VALUE        (1),
         .NO_CUT            (0)
      ) ddr4_softreset_sync (
         .clk   (afu_mem_if[j].clk),
         .reset (1'b0),
         .d     (softreset),
         .q     (softreset_emif[j])
      );

      axi_mm_pr_freeze_bridge #(
         // Register tx signals for freeze logic
         // Number of pipeline stage
         .AW_REG_MODE (AW_REG_MODE),
         .W_REG_MODE  (W_REG_MODE),
         .B_REG_MODE  (B_REG_MODE),
         .AR_REG_MODE (AR_REG_MODE),
         .R_REG_MODE  (R_REG_MODE),
         .PR_FREEZE_DIS (PR_FREEZE_DIS),
         .ID_WIDTH    ($bits(afu_mem_if[j].arid)),
         .ADDR_WIDTH  ($bits(afu_mem_if[j].araddr)),
         .DATA_WIDTH  ($bits(afu_mem_if[j].rdata))
      ) pr_frz_afu_avmm_if (
	 .afu_reset (softreset_emif[j]),
         .pr_freeze (pr_freeze_emif[j]),
         .m_if      (afu_mem_if[j]),   /* user = master */
         .s_if      (afu_main_emif[j]) /* emif = slave */
      );
   end //for
`endif

// ----------------------------------------------------------------------------------------------------
// 3. PR Freeze: HE-HSSI to HSSI-SS Ports (Tx Direction)
// ----------------------------------------------------------------------------------------------------
`ifdef INCLUDE_HSSI
  
   `ifdef INCLUDE_PR 
       parameter HSSI_RX_REG_MODE    =ST_SIMPLE_BUFFER_0; 
       parameter HSSI_TX_REG_MODE    =ST_SKID_BUFFER; 
   `else // INCLUDE_PR
       parameter HSSI_RX_REG_MODE    =ST_BYPASS; 
       parameter HSSI_TX_REG_MODE    =ST_BYPASS; 
   `endif //INCLUDE_PR
 
   ofs_fim_hssi_ss_tx_axis_if     hssi_afu_st_tx  [MAX_NUM_ETH_CHANNELS-1:0] ();
   ofs_fim_hssi_ss_rx_axis_if     hssi_afu_st_rx [MAX_NUM_ETH_CHANNELS-1:0] ();
   ofs_fim_hssi_fc_if             hssi_afu_fc [MAX_NUM_ETH_CHANNELS-1:0] ();

   for (genvar j=0; j<MAX_NUM_ETH_CHANNELS; j++) begin
      fim_resync #(
         .INIT_VALUE (0),
         .NO_CUT     (0)
      ) hssi_pr_freeze_rst_n (
         .clk      (i_hssi_clk_pll[j]),
         .reset    (0),
         .d        (softreset),
         .q        (softreset_hssi[j])
      );

      fim_resync #(
         .NO_CUT (0)
      ) hssi_pr_freeze_resync_inst (
         .clk      (i_hssi_clk_pll[j]),
         .reset    (1'b0),
         .d        (pr_freeze),
         .q        (pr_freeze_hssi[j])
      );

      axis_hssi_pr_freeze_bridge #(
         .TDATA_WIDTH ($bits(hssi_ss_st_tx[j].tx.tdata)),
         .TUSER_WIDTH ($bits(hssi_ss_st_tx[j].tx.tuser)),
         .PR_FREEZE_DIS (PR_FREEZE_DIS),
         .TX_REG_MODE (HSSI_RX_REG_MODE),
         .RX_REG_MODE (HSSI_TX_REG_MODE)
        
      ) pr_frz_hssi_ss_port (
         .pr_freeze        (pr_freeze_hssi[j]),
         .afu_reset        (softreset_hssi[j]),
         .hssi_ss_st_tx    (hssi_ss_st_tx[j]),
         .hssi_ss_st_rx    (hssi_ss_st_rx[j]),
         .hssi_fc          (hssi_fc[j]),
         .i_hssi_clk_pll   (i_hssi_clk_pll[j]),
         .hssi_afu_st_tx   (hssi_afu_st_tx[j]),
         .hssi_afu_st_rx   (hssi_afu_st_rx[j]),
         .hssi_afu_fc      (hssi_afu_fc[j])
      );
      
   end
`endif

// ----------------------------------------------------------------------------------------------------
// AFU Instance
// ----------------------------------------------------------------------------------------------------

//
// afu_main() is the standard point of AFU-specific logic. The FIM passes all
// available device interfaces to the AFU, which must either drive or tie them
// off. AFU's may either connect directly to the devices or use the provided
// Platform Interface Manager (PIM) abstraction layer, which implements a
// PIM connector in afu_main(). The PIM's afu_main() then instantiates any
// PIM-based AFU.
//
afu_main #(
   .PG_NUM_PORTS     (PG_NUM_PORTS),
   .PORT_PF_VF_INFO  (PORT_PF_VF_INFO),
   .NUM_MEM_CH       (NUM_MEM_CH)
) afu_main (
   .clk,
   .clk_div2,
   .clk_div4,
   .uclk_usr           (uclk_usr),
   .uclk_usr_div2      (uclk_usr_div2),

   .rst_n              (!softreset),
   .port_rst_n         (port_rst_n_t1),

   `ifdef INCLUDE_DDR4
      .ext_mem_if        (afu_main_emif),
   `endif
   
   .afu_axi_rx_a_if    (axi_rx_a_if_t1),
   .afu_axi_tx_a_if    (axi_tx_a_if_t1),
   .afu_axi_rx_b_if    (axi_rx_b_if_t1),
   .afu_axi_tx_b_if    (axi_tx_b_if_t1),

   `ifdef INCLUDE_HSSI
      .hssi_ss_st_tx    (hssi_afu_st_tx),
      .hssi_ss_st_rx    (hssi_afu_st_rx),
      .hssi_fc          (hssi_afu_fc),
      .i_hssi_clk_pll   (i_hssi_clk_pll),
   `endif 

   //JTAG signal connection to AFU region for remote SignalTap
   .remote_stp_jtag_if
);

endmodule : pr_slot

// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//  Instantiates HE-MEM, HE-HSSI and HE-MEM-TG in FIM base compile
//               HE-LPBK, HE-HSSI and HE-MEM-TG in-tree PR compile
// -----------------------------------------------------------------------------
// Created for use of the PF/VF Configuration tool, where only AFU endpoints are
// connected. The user is instructed to utilize the PORT_PF_VF_INFO parameter
// to access all information regarding a specific endpoint with a PID.
// 
// The default PID mapping is as follows:
//    PID 0 - PF0/VF0 HE-MEM
//    PID 1 - PF0/VF1 HE-HSSI
//    PID 2 - PF0/VF2 HE-MEM-TG
//    PID 3+ - NULL AFUs
//


`include "fpga_defines.vh"

module port_afu_instances
   import pcie_ss_axis_pkg::*;
   import he_lb_pkg::*;
# (
   parameter PG_NUM_PORTS    = 1,
   parameter pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t[PG_NUM_PORTS-1:0] PORT_PF_VF_INFO =
                {PG_NUM_PORTS{pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t'(0)}},

   parameter NUM_MEM_CH      = 0,
   parameter MAX_ETH_CH      = ofs_fim_eth_plat_if_pkg::MAX_NUM_ETH_CHANNELS
)(
   input  logic clk,
   input  logic clk_div2,
   input  logic clk_div4,
   input  logic uclk_usr,
   input  logic uclk_usr_div2,

   input  logic rst_n,
   input  logic [PG_NUM_PORTS-1:0] port_rst_n,
   
   // PCIe A ports are the standard TLP channels. All host responses
   // arrive on the RX A port.
   pcie_ss_axis_if.source        afu_axi_tx_a_if [PG_NUM_PORTS-1:0],
   pcie_ss_axis_if.sink          afu_axi_rx_a_if [PG_NUM_PORTS-1:0],
   // PCIe B ports are a second channel on which reads and interrupts
   // may be sent from the AFU. To improve throughput, reads on B may flow
   // around writes on A through PF/VF MUX trees until writes are committed
   // to the PCIe subsystem. AFUs may tie off the B port and send all
   // messages to A.
   pcie_ss_axis_if.source        afu_axi_tx_b_if [PG_NUM_PORTS-1:0],
   // Write commits are signaled here on the RX B port, indicating the
   // point at which the A and B channels become ordered within the FIM.
   // Commits are signaled after tlast of a write on TX A, after arbitration
   // with TX B within the FIM. The commit is a Cpl (without data),
   // returning the tag value from the write request. AFUs that do not
   // need local write commits may ignore this port, but must set
   // tready to 1.
   pcie_ss_axis_if.sink          afu_axi_rx_b_if [PG_NUM_PORTS-1:0]

   `ifdef INCLUDE_DDR4
      // Local memory
     ,ofs_fim_emif_axi_mm_if.user     ext_mem_if [NUM_MEM_CH-1:0]
   `endif

   `ifdef INCLUDE_HSSI
     ,ofs_fim_hssi_ss_tx_axis_if.client hssi_ss_st_tx [MAX_ETH_CH-1:0],
      ofs_fim_hssi_ss_rx_axis_if.client hssi_ss_st_rx [MAX_ETH_CH-1:0],
      ofs_fim_hssi_fc_if.client         hssi_fc [MAX_ETH_CH-1:0],
      input logic [MAX_ETH_CH-1:0]      i_hssi_clk_pll
   `endif
);

localparam SKID_BUFFER   = 0;
localparam W_REG_MODE    = SKID_BUFFER; 
localparam R_REG_MODE    = SKID_BUFFER; 
localparam AW_REG_MODE   = SKID_BUFFER; 
localparam B_REG_MODE    = SKID_BUFFER; 
localparam AR_REG_MODE   = SKID_BUFFER; 

   //--------------------------------------------------------------------------------
   // Process feature control flags:
   // *   Set the index of each feature on the AXIS bus
   // *   A -1 PID means the associated feature will not be instantiated
   // *   An unimplemented PID in PG_NUM_PORTS will default to A NULL AFU
   // *   If an external interface is disconnected because a feature is turned off
   //     it needs to be tied off here
   //--------------------------------------------------------------------------------

   // HE-MEM port feature configuration
 `ifdef USE_NULL_HE_MEM
   localparam AXIS_HEM_PID = -1;
   localparam AXIS_HLB_PID = -1;
   localparam HE_MEM_CH = 0;
 `else
  `ifdef PR_COMPILE
   //--------------------------------------------------------------------------------
   // PR_COMPILE is set during in-tree ofs-dev PR compile. This replaces HE-MEM
   // from FIM base compile to HE-LPBK. After loading the in-tree.gbs, the
   // LPBK GUID should reflect a successful PR
   //--------------------------------------------------------------------------------
   localparam AXIS_HEM_PID = -1;
   localparam AXIS_HLB_PID = 0;
   localparam HE_MEM_CH = 0;
  `else
   `ifdef INCLUDE_DDR4
   localparam AXIS_HEM_PID = 0;
   localparam AXIS_HLB_PID = -1;
   localparam HE_MEM_CH = 1;
   `else
   localparam AXIS_HEM_PID = -1;
   localparam AXIS_HLB_PID = 0;
   localparam HE_MEM_CH = 0;
   `endif
  `endif
 `endif

   // MEM-TG port feature configuration
 `ifdef USE_NULL_HE_MEM_TG
   localparam AXIS_MEM_TG_PID = -1;
   localparam MEM_TG_CH = 0;
 `else
  `ifdef INCLUDE_DDR4
   localparam MEM_TG_CH = (NUM_MEM_CH > HE_MEM_CH) ? NUM_MEM_CH - HE_MEM_CH : 0;
   // stub out the feature if there are no memory channels to connect to
   localparam AXIS_MEM_TG_PID = (MEM_TG_CH > 0) ? 2 : -1;
  `else
   localparam AXIS_MEM_TG_PID = -1;
   localparam MEM_TG_CH = 0;
  `endif
 `endif

   // HE-HSSI port feature configuration
 `ifdef USE_NULL_HE_HSSI
   localparam AXIS_HEH_PID = -1;
   localparam HE_HSSI_CH   = 0;
 `else
   `ifdef INCLUDE_HSSI
   localparam AXIS_HEH_PID = 1;
   localparam HE_HSSI_CH   = MAX_ETH_CH;
   `else
   localparam AXIS_HEH_PID = -1;
   localparam HE_HSSI_CH   = 0;
   `endif
  `endif
   
   // The number of connected external channels, used to tie off any excess
   localparam CON_MEM_CH = MEM_TG_CH + HE_MEM_CH;
   localparam CON_ETH_CH = HE_HSSI_CH;

//--------------------------------------------------------------------------------
// Manage External Interfaces:
// *   Pipelining
// *   Interface tie-offs
//--------------------------------------------------------------------------------
`ifdef INCLUDE_DDR4
(* noprune *) ofs_fim_emif_axi_mm_if #(
      .AWID_WIDTH   ($bits(ext_mem_if[0].awid)),
      .AWADDR_WIDTH ($bits(ext_mem_if[0].awaddr)),
      .AWUSER_WIDTH ($bits(ext_mem_if[0].awuser)),
      .WDATA_WIDTH  ($bits(ext_mem_if[0].wdata)),
      .BUSER_WIDTH  ($bits(ext_mem_if[0].buser)),
      .ARID_WIDTH   ($bits(ext_mem_if[0].arid)),
      .ARADDR_WIDTH ($bits(ext_mem_if[0].araddr)),
      .ARUSER_WIDTH ($bits(ext_mem_if[0].aruser)),
      .RDATA_WIDTH  ($bits(ext_mem_if[0].rdata)),
      .RUSER_WIDTH  ($bits(ext_mem_if[0].ruser)) 
   ) afu_ext_mem_if [NUM_MEM_CH-1:0] ();

   genvar ch;
   generate 
      for (ch=0; ch<NUM_MEM_CH; ch++) begin : axi_mm_reg
         // ======================================================
         // Pipeline Memory ports in PR region before consuming
         // ======================================================
         axi_mm_emif_bridge #(
            .AW_REG_MODE (AW_REG_MODE),
            .W_REG_MODE  (W_REG_MODE),
            .B_REG_MODE  (B_REG_MODE),
            .AR_REG_MODE (AR_REG_MODE),
            .R_REG_MODE  (R_REG_MODE),
            .ID_WIDTH    (ext_mem_if[ch].ARID_WIDTH),
            .ADDR_WIDTH  (ext_mem_if[ch].ARADDR_WIDTH),
            .DATA_WIDTH  (ext_mem_if[ch].RDATA_WIDTH)
         ) afu_axi_mm_bridge (
            .m_if      (ext_mem_if[ch]), /* user = master */
            .s_if      (afu_ext_mem_if[ch]) /* emif = slave  */
         );     
      end

      for (ch=CON_MEM_CH; ch<NUM_MEM_CH; ch++) begin : axi_mm_tie_off
	 always_comb begin
            afu_ext_mem_if[ch].awvalid = 1'b0;
            afu_ext_mem_if[ch].wvalid = 1'b0;
            afu_ext_mem_if[ch].arvalid = 1'b0;
            afu_ext_mem_if[ch].rready = 1'b1;
            afu_ext_mem_if[ch].bready = 1'b1;
	 end
      end
   endgenerate
`endif

`ifdef INCLUDE_HSSI
(* noprune *) ofs_fim_hssi_ss_tx_axis_if hssi_ss_st_tx_t1 [MAX_ETH_CH-1:0] ();
(* noprune *) ofs_fim_hssi_ss_rx_axis_if hssi_ss_st_rx_t1 [MAX_ETH_CH-1:0] ();
generate 
   for (genvar j=0; j<MAX_ETH_CH; j++) begin : hssi_st_pipe_gen
      assign hssi_ss_st_rx_t1[j].clk = hssi_ss_st_rx[j].clk;

      always_ff @(posedge hssi_ss_st_rx[j].clk) begin
         hssi_ss_st_rx_t1[j].rx    <= hssi_ss_st_rx[j].rx;
         hssi_ss_st_rx_t1[j].rst_n <= hssi_ss_st_rx[j].rst_n;
      end
      axis_tx_hssi_pipeline #(
         .TDATA_WIDTH ($bits(hssi_ss_st_tx[j].tx.tdata)),
         .TUSER_WIDTH ($bits(hssi_ss_st_tx[j].tx.tuser)),
	 .PRESERVE_REG (1) // adds syn_keep on all registers when set        
      ) axis_tx_hssi_pipeline_inst (
         .axis_m (hssi_ss_st_tx[j]),   //client
         .axis_s (hssi_ss_st_tx_t1[j]) //mac
      );
   end

   // Tie off Tx
   for (genvar j=CON_ETH_CH; j<MAX_ETH_CH; j++) begin : heh_tx_tie_off
      assign hssi_ss_st_tx_t1[j].tx.tvalid = 1'b0;
   end
endgenerate
`endif
   
//--------------------------------------------------------------------------------
// Instantiate features
// 
// A loop is used for the standard OFS AFU to scale port connections to varying
// port configurations without having to modify RTL.
//
// A user AFU may use this as a template to connect unused ports to a null-afu
// instance by setting 'i' to the end of the enumerated port list.
//--------------------------------------------------------------------------------
genvar i;
generate
   for(i=0; i<PG_NUM_PORTS; i=i+1) begin : afu_gen
      if (i == AXIS_HLB_PID) begin : hlb_gen
         he_lb_top #(
            .PF_ID     (PORT_PF_VF_INFO[i].pf_num),
            .VF_ID     (PORT_PF_VF_INFO[i].vf_num),
            .VF_ACTIVE (PORT_PF_VF_INFO[i].vf_active)
         ) he_lb_inst (
            .clk         (clk),
            .rst_n       (port_rst_n      [i]),
            .axi_rx_a_if (afu_axi_rx_a_if [i]),
            .axi_rx_b_if (afu_axi_rx_b_if [i]),
            .axi_tx_a_if (afu_axi_tx_a_if [i]),
            .axi_tx_b_if (afu_axi_tx_b_if [i])
         );
      end : hlb_gen
`ifdef INCLUDE_DDR4
      else if(i == AXIS_HEM_PID) begin : hem_gen
         he_mem_top #(
            .PF_ID     (PORT_PF_VF_INFO[i].pf_num),
            .VF_ID     (PORT_PF_VF_INFO[i].vf_num),
            .VF_ACTIVE (PORT_PF_VF_INFO[i].vf_active),
            .EMIF(1),
            .NUM_MEM_BANKS(HE_MEM_CH)
         ) he_mem_inst (
            .clk         (clk),
            .rst_n       (port_rst_n[i]),
            .axi_rx_a_if (afu_axi_rx_a_if[i]),
            .axi_rx_b_if (afu_axi_rx_b_if[i]),
            .axi_tx_a_if (afu_axi_tx_a_if[i]),
            .axi_tx_b_if (afu_axi_tx_b_if[i]),
            .ext_mem_if  (afu_ext_mem_if[HE_MEM_CH-1:0])
         );
      end : hem_gen
      else if (i == AXIS_MEM_TG_PID) begin : tg_gen
         mem_tg2_top #(
            .PF_ID     (PORT_PF_VF_INFO[i].pf_num),
            .VF_ID     (PORT_PF_VF_INFO[i].vf_num),
            .VF_ACTIVE (PORT_PF_VF_INFO[i].vf_active),
            .NUM_TG    (MEM_TG_CH)
         ) mem_tg_inst (
            .clk        (clk),
            .rst_n      (port_rst_n      [i]),
            .axis_rx_if (afu_axi_rx_a_if [i]),
            .axis_tx_if (afu_axi_tx_a_if [i]),
            .ext_mem_if (afu_ext_mem_if[NUM_MEM_CH-1:HE_MEM_CH])
         );
	 // AFU does not have TX/RX B port
	 assign afu_axi_tx_b_if[i].tvalid = 1'b0;
	 assign afu_axi_rx_b_if[i].tready = 1'b1;
      end : tg_gen
`endif
`ifdef INCLUDE_HSSI
      else if (i == AXIS_HEH_PID) begin : heh_gen
         he_hssi_top #(
            .PF_NUM    (PORT_PF_VF_INFO[i].pf_num),
            .VF_NUM    (PORT_PF_VF_INFO[i].vf_num),
            .VF_ACTIVE (PORT_PF_VF_INFO[i].vf_active)
         ) he_hssi_inst (
            .clk            (clk),
            .softreset      (~port_rst_n     [i]),
            .axis_rx_if     (afu_axi_rx_a_if [i]),
            .axis_tx_if     (afu_axi_tx_a_if [i]),
            .hssi_ss_st_tx  (hssi_ss_st_tx_t1), //client
            .hssi_ss_st_rx  (hssi_ss_st_rx_t1), //client
            .hssi_fc        (hssi_fc),
            .i_hssi_clk_pll (i_hssi_clk_pll)
         );
	 // AFU does not have TX/RX B port
	 assign afu_axi_tx_b_if[i].tvalid = 1'b0;
	 assign afu_axi_rx_b_if[i].tready = 1'b1;
      end : heh_gen
`endif
      else begin : null_gen
         he_null #(
            .PF_ID     (PORT_PF_VF_INFO[i].pf_num),
            .VF_ID     (PORT_PF_VF_INFO[i].vf_num),
            .VF_ACTIVE (PORT_PF_VF_INFO[i].vf_active)
         ) he_null_prr (
            .clk     (clk),
            .rst_n   (port_rst_n[i]),
            .i_rx_if (afu_axi_rx_a_if[i]),
            .o_tx_if (afu_axi_tx_a_if[i])
         );
	 // AFU does not have TX/RX B port
	 assign afu_axi_tx_b_if[i].tvalid = 1'b0;
	 assign afu_axi_rx_b_if[i].tready = 1'b1;
      end : null_gen
   end
endgenerate

endmodule

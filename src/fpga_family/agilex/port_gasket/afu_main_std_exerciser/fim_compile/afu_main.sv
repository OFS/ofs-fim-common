// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//  Instantiates HE-MEM, HE-HSSI and HE-MEM-TG in FIM base compile
//               HE-LPBK, HE-HSSI and HE-MEM-TG in-tree PR compile
// -----------------------------------------------------------------------------
//
// This simple AFU example connects test exercisers directly to the PCIe VF
// ports available in PR slot. This file is used in both Base/PR compile and can be 
// used as en example to bring up PR flow in a new platform. One of 
// exerciser is replaced using 'PR_COMPILE' during in-tree gbs compilation. This gbs
// can be used to bring up PR in a new platform. 
// A new AFU could be constructed by starting with this afu_main()
// and replacing the body with RTL that instantiates the desired accelerator.
//


`include "fpga_defines.vh"


module afu_main 
   import top_cfg_pkg::*;
   import pcie_ss_axis_pkg::*;
   import ofs_axi_mm_pkg::*;
#(
   parameter PG_NUM_PORTS    = 1,
   // PF/VF to which each port is mapped
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
   pcie_ss_axis_if.sink          afu_axi_rx_b_if [PG_NUM_PORTS-1:0],

   `ifdef INCLUDE_DDR4
      // Local memory
      ofs_fim_emif_axi_mm_if.user ext_mem_if [NUM_MEM_CH-1:0],
   `endif

   `ifdef INCLUDE_HSSI
      ofs_fim_hssi_ss_tx_axis_if.client hssi_ss_st_tx [MAX_ETH_CH-1:0],
      ofs_fim_hssi_ss_rx_axis_if.client hssi_ss_st_rx [MAX_ETH_CH-1:0],
      ofs_fim_hssi_fc_if.client         hssi_fc [MAX_ETH_CH-1:0],
      input logic [MAX_ETH_CH-1:0]      i_hssi_clk_pll,
   `endif

   // JTAG interface for PR region debug
   ofs_jtag_if.sink              remote_stp_jtag_if
);

// Index of each feature in the AXIS bus
localparam AXIS_HEM_TG_PID = 2;
localparam AXIS_HEH_PID    = 1;
localparam AXIS_HEM_PID    = 0;
localparam BYPASS        = 2;
localparam SIMPLE_BUFFER = 1;
localparam SKID_BUFFER   = 0;
parameter W_REG_MODE     = SKID_BUFFER; 
parameter R_REG_MODE     = SKID_BUFFER; 
parameter AW_REG_MODE    = SKID_BUFFER; 
parameter B_REG_MODE     = SKID_BUFFER; 
parameter AR_REG_MODE    = SKID_BUFFER; 

localparam NUM_TAGS       = ofs_pcie_ss_cfg_pkg::PCIE_EP_MAX_TAGS;

//PCIe port pipelines
localparam PL_DEPTH       = 1;
localparam TDATA_WIDTH    = pcie_ss_axis_pkg::TDATA_WIDTH;
localparam TUSER_WIDTH    = pcie_ss_axis_pkg::TUSER_WIDTH;

logic [PG_NUM_PORTS-1:0] port_rst_n_q1 = {PG_NUM_PORTS{1'b0}};
logic [PG_NUM_PORTS-1:0] port_rst_n_q2 = {PG_NUM_PORTS{1'b0}};

(* noprune *) pcie_ss_axis_if     afu_axi_tx_a_if_t1            [PG_NUM_PORTS-1:0]();
(* noprune *) pcie_ss_axis_if     afu_axi_rx_a_if_t1            [PG_NUM_PORTS-1:0]();
(* noprune *) pcie_ss_axis_if     afu_axi_tx_b_if_t1            [PG_NUM_PORTS-1:0]();
(* noprune *) pcie_ss_axis_if     afu_axi_rx_b_if_t1            [PG_NUM_PORTS-1:0]();
(* noprune *) logic rx_a_rst_n[PG_NUM_PORTS-1:0];
(* noprune *) logic rx_b_rst_n[PG_NUM_PORTS-1:0];
(* noprune *) logic tx_a_rst_n[PG_NUM_PORTS-1:0];
(* noprune *) logic tx_b_rst_n[PG_NUM_PORTS-1:0];


// ======================================================
// Pipeline PCIe ports in PR region before consuming
// ======================================================

for (genvar j=0; j<PG_NUM_PORTS; j++) begin : axis_reg

   // All ports need to flopped and preserved
   // Port A - Primary Port for all Traffic
   axis_pipeline #(
      .TDATA_WIDTH (TDATA_WIDTH),
      .TUSER_WIDTH (TUSER_WIDTH),
      .PRESERVE_REG(1),
      .PL_DEPTH    (PL_DEPTH)
   ) pcie_pipeline_rx_a (
      .clk     (afu_axi_rx_a_if[j].clk),
      .rst_n   (afu_axi_rx_a_if[j].rst_n),
      .axis_s  (afu_axi_rx_a_if[j]),         // <--- PCIe SS
      .axis_m  (afu_axi_rx_a_if_t1[j])      // ---> AFU workload
   );

   axis_pipeline #(
      .TDATA_WIDTH (TDATA_WIDTH),
      .TUSER_WIDTH (TUSER_WIDTH),
      .PRESERVE_REG(1),
      .PL_DEPTH    (PL_DEPTH)
   ) pcie_pipeline_tx_a (
      .clk     (afu_axi_tx_a_if[j].clk),
      .rst_n   (afu_axi_tx_a_if[j].rst_n),
      .axis_s  (afu_axi_tx_a_if_t1[j]),      // <--- AFU workload
      .axis_m  (afu_axi_tx_a_if[j])         // ---> PCIe SS
   );
 
   // Port B - Secondary Port
   axis_pipeline #(
      .TDATA_WIDTH (TDATA_WIDTH),
      .TUSER_WIDTH (TUSER_WIDTH),
      .PRESERVE_REG(1),
      .PL_DEPTH    (PL_DEPTH)
   ) pcie_pipeline_rx_b (
      .clk     (afu_axi_rx_b_if[j].clk),
      .rst_n   (afu_axi_rx_b_if[j].rst_n),
      .axis_s  (afu_axi_rx_b_if[j]),         // <--- PCIe SS
      .axis_m  (afu_axi_rx_b_if_t1[j])      // ---> AFU workload
   );

   axis_pipeline #(
      .TDATA_WIDTH (TDATA_WIDTH),
      .TUSER_WIDTH (TUSER_WIDTH),
      .PRESERVE_REG(1),
      .PL_DEPTH    (PL_DEPTH)
   ) pcie_pipeline_tx_b (
      .clk     (afu_axi_tx_b_if[j].clk),
      .rst_n   (afu_axi_tx_b_if[j].rst_n),
      .axis_s  (afu_axi_tx_b_if_t1[j]),      // <--- AFU workload
      .axis_m  (afu_axi_tx_b_if[j])         // ---> PCIe SS
   );

   // Assign clk & resets to interface package
   assign afu_axi_rx_a_if_t1[j].clk     = afu_axi_rx_a_if[j].clk;
   assign afu_axi_rx_a_if_t1[j].rst_n   = rx_a_rst_n[j];
   assign afu_axi_tx_a_if_t1[j].clk     = afu_axi_tx_a_if[j].clk;
   assign afu_axi_tx_a_if_t1[j].rst_n   = tx_a_rst_n[j];

   assign afu_axi_rx_b_if_t1[j].clk     = afu_axi_rx_b_if[j].clk;
   assign afu_axi_rx_b_if_t1[j].rst_n   = rx_b_rst_n[j];
   assign afu_axi_tx_b_if_t1[j].clk     = afu_axi_tx_b_if[j].clk;
   assign afu_axi_tx_b_if_t1[j].rst_n   = tx_b_rst_n[j];
end


// ======================================================
// Pipeline Memory ports in PR region before consuming
// ======================================================

`ifdef INCLUDE_DDR4// Number of memory channels accessible to HE-MEM block
   ofs_fim_emif_axi_mm_if #(
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

   for (genvar j=0; j<NUM_MEM_CH; j++) begin : axi_mm_reg
      axi_mm_emif_bridge #(
         .AW_REG_MODE (AW_REG_MODE),
         .W_REG_MODE  (W_REG_MODE),
         .B_REG_MODE  (B_REG_MODE),
         .AR_REG_MODE (AR_REG_MODE),
         .R_REG_MODE  (R_REG_MODE),
         .ID_WIDTH    (ext_mem_if[j].ARID_WIDTH),
         .ADDR_WIDTH  (ext_mem_if[j].ARADDR_WIDTH),
         .DATA_WIDTH  (ext_mem_if[j].RDATA_WIDTH)
      ) afu_axi_mm_bridge (
         .m_if      (ext_mem_if[j]), /* user = master */
         .s_if      (afu_ext_mem_if[j]) /* emif = slave  */
      );     
   end : axi_mm_reg
`endif


// ======================================================
// Instantiate AFUs
// ======================================================

port_afu_instances #(
   .PG_NUM_PORTS    (PG_NUM_PORTS),
   .PORT_PF_VF_INFO (PORT_PF_VF_INFO),
   .NUM_MEM_CH      (NUM_MEM_CH),
   .MAX_ETH_CH      (MAX_ETH_CH),
   .NUM_TAGS        (NUM_TAGS),
   .AW_REG_MODE     (AW_REG_MODE),
   .W_REG_MODE      (W_REG_MODE),
   .B_REG_MODE      (B_REG_MODE),
   .AR_REG_MODE     (AR_REG_MODE),
   .R_REG_MODE      (R_REG_MODE)
) port_afu_instances (
   .clk           (clk),
   .clk_div2      (clk_div2),
   .clk_div4      (clk_div4),
   .uclk_usr      (uclk_usr),
   .uclk_usr_div2 (uclk_usr_div2),
   .rst_n         (rst_n),
   .port_rst_n    (port_rst_n_q2),

`ifdef INCLUDE_HSSI
   .hssi_ss_st_tx  (hssi_ss_st_tx),
   .hssi_ss_st_rx  (hssi_ss_st_rx),
   .hssi_fc        (hssi_fc),
   .i_hssi_clk_pll (i_hssi_clk_pll),
`endif

`ifdef INCLUDE_DDR4
   .ext_mem_if (afu_ext_mem_if),
`endif

   .afu_axi_rx_a_if (afu_axi_rx_a_if_t1),
   .afu_axi_tx_a_if (afu_axi_tx_a_if_t1),
   .afu_axi_rx_b_if (afu_axi_rx_b_if_t1),
   .afu_axi_tx_b_if (afu_axi_tx_b_if_t1)
);


// ======================================================
// Preserve clock and reset routing to PR region
// ======================================================

//
// These signals are preserved in the default FIM build's afu_main()
// in order to ensure they are available for subsequent PR builds.
// This preservation is only required during the initial FIM build.
// It is not required in afu_main() instances used during a PR build.
//

(* noprune *) logic rst_n_q1;
(* noprune *) logic uclk_usr_q1, uclk_usr_q2;
(* noprune *) logic uclk_usrDiv2_q1, uclk_usrDiv2_q2;
(* noprune *) logic pclkDiv4_q1, pclkDiv4_q2;
(* noprune *) logic pclkDiv2_q1, pclkDiv2_q2;

`ifdef INCLUDE_HSSI
   (* noprune *) logic       rx_pause_q1 [MAX_ETH_CH-1:0];
   (* noprune *) logic [7:0] rx_pfc_q1   [MAX_ETH_CH-1:0];

   (* noprune *) logic       rx_rst_n_q1   [MAX_ETH_CH-1:0];
   (* noprune *) logic [3:0] rx_tuser_sts_q1[MAX_ETH_CH-1:0];
   (* noprune *) logic [1:0] rx_tuser_client_q1[MAX_ETH_CH-1:0];


   genvar a;
   generate
      for (a = 0; a < MAX_ETH_CH; a = a + 1) begin: preserve_hssi_fc
         always @(posedge clk) rx_pause_q1[a] <= hssi_fc[a].rx_pause;
         always @(posedge clk) rx_pfc_q1[a]   <= hssi_fc[a].rx_pfc;
         always @(posedge clk) rx_rst_n_q1[a] <= hssi_ss_st_rx[a].rst_n;
         always @(posedge clk) rx_tuser_sts_q1[a] <= hssi_ss_st_rx[a].rx.tuser.sts;
         always @(posedge clk) rx_tuser_client_q1[a] <= hssi_ss_st_rx[a].rx.tuser.client;
      end 
   endgenerate
`endif

always_ff @(posedge clk) begin
   rst_n_q1        <= rst_n;
end

always_ff @(posedge uclk_usr) begin
   uclk_usr_q1     <= uclk_usr_q2;
   uclk_usr_q2     <= !uclk_usr_q1;
end

always_ff @(posedge uclk_usr_div2) begin
   uclk_usrDiv2_q1 <= uclk_usrDiv2_q2;
   uclk_usrDiv2_q2 <= !uclk_usrDiv2_q1;
end

always_ff @(posedge clk_div4) begin
   pclkDiv4_q1     <= pclkDiv4_q2;
   pclkDiv4_q2     <= !pclkDiv4_q1;
end

always_ff @(posedge clk_div2) begin
   pclkDiv2_q1     <= pclkDiv2_q2;
   pclkDiv2_q2     <= !pclkDiv2_q1;
end

genvar c;
generate
   for (c = 0; c < PG_NUM_PORTS; c = c + 1) begin: pcie_port_rst
      always @(posedge clk) port_rst_n_q1[c] <= port_rst_n[c];
      always @(posedge clk) port_rst_n_q2[c] <= port_rst_n_q1[c] && rst_n_q1;
   end 
   
   for (c = 0; c < PG_NUM_PORTS; c = c + 1) begin: preserve_rst
      //rx_a
      always_ff @(posedge afu_axi_rx_a_if[c].clk) begin
         rx_a_rst_n[c] <= afu_axi_rx_a_if[c].rst_n; 
      end
      
      //tx_a
      always_ff @(posedge afu_axi_tx_a_if[c].clk) begin
         tx_a_rst_n[c] <= afu_axi_tx_a_if[c].rst_n; 
      end

      //rx_b
      always_ff @(posedge afu_axi_rx_b_if[c].clk) begin
         rx_b_rst_n[c] <= afu_axi_rx_b_if[c].rst_n; 
      end
      
      //tx_b
      always_ff @(posedge afu_axi_tx_b_if[c].clk) begin
         tx_b_rst_n[c] <= afu_axi_tx_b_if[c].rst_n; 
      end
   end 
endgenerate


//----------------------------------------------
// Remote Debug JTAG IP instantiation
//----------------------------------------------

wire remote_stp_conf_reset = ~rst_n_q1;
`include "ofs_fim_remote_stp_node.vh"

endmodule : afu_main

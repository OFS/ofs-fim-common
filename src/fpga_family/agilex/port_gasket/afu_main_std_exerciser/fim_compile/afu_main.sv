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

// Set this macro to disable this shared afu_main() and provide an AFU-specific
// version.
`ifndef DISABLE_DEFAULT_FIM_AFU_MAIN

`include "fpga_defines.vh"

module afu_main 
#(
   parameter PG_NUM_PORTS    = 1,
   // PF/VF to which each port is mapped
   parameter pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t[PG_NUM_PORTS-1:0] PORT_PF_VF_INFO =
                {PG_NUM_PORTS{pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t'(0)}},

   parameter NUM_MEM_CH      = 0,
   parameter MAX_ETH_CH      = ofs_fim_eth_plat_if_pkg::MAX_NUM_ETH_CHANNELS,

   parameter int PG_NUM_RTABLE_ENTRIES = 3,

   parameter pf_vf_mux_pkg::t_pfvf_rtable_entry[PG_NUM_RTABLE_ENTRIES-1:0] PG_PFVF_ROUTING_TABLE = {PG_NUM_RTABLE_ENTRIES{pf_vf_mux_pkg::t_pfvf_rtable_entry'(0)}}

)(
   input  logic clk,
   input  logic clk_div2,
   input  logic clk_div4,
   input  logic uclk_usr,
   input  logic uclk_usr_div2,

   input  logic rst_n,
   input  logic [PG_NUM_PORTS-1:0] port_rst_n,

   // M20k protection control signal propagated to PR boundary. There is 
   // a qsf assignment to identify this signal. Quartus compiler will use 
   // this control signal and automatically insert soft clock gating logic 
   // around M20k
   input  logic pr_m20k_ce_ctl_req, 

   // PCIe A ports are the standard TLP channels. All host responses
   // arrive on the RX A port.
   pcie_ss_axis_if.source        afu_axi_tx_a_if,
   pcie_ss_axis_if.sink          afu_axi_rx_a_if,
   // PCIe B ports are a second channel on which reads and interrupts
   // may be sent from the AFU. To improve throughput, reads on B may flow
   // around writes on A through PF/VF MUX trees until writes are committed
   // to the PCIe subsystem. AFUs may tie off the B port and send all
   // messages to A.
   pcie_ss_axis_if.source        afu_axi_tx_b_if,
   // Write commits are signaled here on the RX B port, indicating the
   // point at which the A and B channels become ordered within the FIM.
   // Commits are signaled after tlast of a write on TX A, after arbitration
   // with TX B within the FIM. The commit is a Cpl (without data),
   // returning the tag value from the write request. AFUs that do not
   // need local write commits may ignore this port, but must set
   // tready to 1.
   pcie_ss_axis_if.sink          afu_axi_rx_b_if,

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

//PCIe port pipelines
localparam PL_DEPTH       = 1;
localparam TDATA_WIDTH    = pcie_ss_axis_pkg::TDATA_WIDTH;
localparam TUSER_WIDTH    = pcie_ss_axis_pkg::TUSER_WIDTH;

logic [PG_NUM_PORTS-1:0] port_rst_n_q1 = {PG_NUM_PORTS{1'b0}};
logic [PG_NUM_PORTS-1:0] port_rst_n_q2 = {PG_NUM_PORTS{1'b0}};

// 1 PCIe-ST Physical port containing all VF transactions to PR region
(* noprune *) pcie_ss_axis_if #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) afu_axi_tx_a_if_t1 (.clk(clk), .rst_n(rst_n));
(* noprune *) pcie_ss_axis_if #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) afu_axi_rx_a_if_t1 (.clk(clk), .rst_n(rst_n));
(* noprune *) pcie_ss_axis_if #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) afu_axi_tx_b_if_t1 (.clk(clk), .rst_n(rst_n));
(* noprune *) pcie_ss_axis_if #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) afu_axi_rx_b_if_t1 (.clk(clk), .rst_n(rst_n));
// Array of PCIe-ST ports with VF(n) from PG_MUX to AFU
pcie_ss_axis_if  #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) mux_afu_axi_rx_a_if [PG_NUM_PORTS-1:0](clk, port_rst_n_q2);
pcie_ss_axis_if  #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) mux_afu_axi_tx_a_if [PG_NUM_PORTS-1:0](clk, port_rst_n_q2);
pcie_ss_axis_if  #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) mux_afu_axi_rx_b_if [PG_NUM_PORTS-1:0](clk, port_rst_n_q2);
pcie_ss_axis_if  #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) mux_afu_axi_tx_b_if [PG_NUM_PORTS-1:0](clk, port_rst_n_q2);

// ======================================================
// Pipeline PCIe ports in PR region before consuming
// ======================================================

   // All ports need to flopped and preserved
   // Port A - Primary Port for all Traffic
   axis_pipeline #(
      .TDATA_WIDTH (TDATA_WIDTH),
      .TUSER_WIDTH (TUSER_WIDTH),
      .PRESERVE_REG(1),
      .PL_DEPTH    (PL_DEPTH)
   ) pcie_pipeline_rx_a (
      .clk     (afu_axi_rx_a_if.clk),
      .rst_n   (afu_axi_rx_a_if.rst_n),
      .axis_s  (afu_axi_rx_a_if),         // <--- PCIe SS
      .axis_m  (afu_axi_rx_a_if_t1)      // ---> AFU workload
   );

   axis_pipeline #(
      .TDATA_WIDTH (TDATA_WIDTH),
      .TUSER_WIDTH (TUSER_WIDTH),
      .PRESERVE_REG(1),
      .PL_DEPTH    (PL_DEPTH)
   ) pcie_pipeline_tx_a (
      .clk     (afu_axi_tx_a_if.clk),
      .rst_n   (afu_axi_tx_a_if.rst_n),
      .axis_s  (afu_axi_tx_a_if_t1),      // <--- AFU workload
      .axis_m  (afu_axi_tx_a_if)         // ---> PCIe SS
   );
 
   // Port B - Secondary Port
   axis_pipeline #(
      .TDATA_WIDTH (TDATA_WIDTH),
      .TUSER_WIDTH (TUSER_WIDTH),
      .PRESERVE_REG(1),
      .PL_DEPTH    (PL_DEPTH)
   ) pcie_pipeline_rx_b (
      .clk     (afu_axi_rx_b_if.clk),
      .rst_n   (afu_axi_rx_b_if.rst_n),
      .axis_s  (afu_axi_rx_b_if),         // <--- PCIe SS
      .axis_m  (afu_axi_rx_b_if_t1)      // ---> AFU workload
   );

   axis_pipeline #(
      .TDATA_WIDTH (TDATA_WIDTH),
      .TUSER_WIDTH (TUSER_WIDTH),
      .PRESERVE_REG(1),
      .PL_DEPTH    (PL_DEPTH)
   ) pcie_pipeline_tx_b (
      .clk     (afu_axi_tx_b_if.clk),
      .rst_n   (afu_axi_tx_b_if.rst_n),
      .axis_s  (afu_axi_tx_b_if_t1),      // <--- AFU workload
      .axis_m  (afu_axi_tx_b_if)         // ---> PCIe SS
   );


   // Primary PF/VF MUX ("A" ports). Map individual TX A ports from
   // AFUs down to a single, merged A channel. The RX port from host
   // to FPGA is demultiplexed and individual connections are forwarded
   // to AFUs.
   pf_vf_mux_w_params #(
      .MUX_NAME("PG_A"),
      .NUM_PORT(PG_NUM_PORTS),
      .NUM_RTABLE_ENTRIES(PG_NUM_RTABLE_ENTRIES),
      .PFVF_ROUTING_TABLE(PG_PFVF_ROUTING_TABLE)
   ) pg_pf_vf_mux_a (
      .clk             (clk               ),
      .rst_n           (rst_n             ),
      .ho2mx_rx_port   (afu_axi_rx_a_if_t1),
      .mx2ho_tx_port   (afu_axi_tx_a_if_t1),
      .mx2fn_rx_port   (mux_afu_axi_rx_a_if),
      .fn2mx_tx_port   (mux_afu_axi_tx_a_if),
      .out_fifo_err    (),
      .out_fifo_perr   ()
   );

   // Secondary PF/VF MUX ("B" ports). Only TX is implemented, since a
   // single RX stream is sufficient. The RX input to the MUX is tied off.
   // AFU B TX ports are multiplexed into a single TX B channel that is
   // passed to the A/B MUX above.
   pf_vf_mux_w_params  #(
      .MUX_NAME ("PG_B"),
      .NUM_PORT(PG_NUM_PORTS),
      .NUM_RTABLE_ENTRIES(PG_NUM_RTABLE_ENTRIES),
      .PFVF_ROUTING_TABLE(PG_PFVF_ROUTING_TABLE)
   ) pg_pf_vf_mux_b (
      .clk             (clk               ),
      .rst_n           (rst_n             ),
      .ho2mx_rx_port   (afu_axi_rx_b_if_t1),
      .mx2ho_tx_port   (afu_axi_tx_b_if_t1),
      .mx2fn_rx_port   (mux_afu_axi_rx_b_if),
      .fn2mx_tx_port   (mux_afu_axi_tx_b_if),
      .out_fifo_err    (),
      .out_fifo_perr   ()
   );


// ======================================================
// Instantiate AFUs
// ======================================================

port_afu_instances #(
   .PG_NUM_PORTS    (PG_NUM_PORTS),
   .PORT_PF_VF_INFO (PORT_PF_VF_INFO),
   .NUM_MEM_CH      (NUM_MEM_CH),
   .MAX_ETH_CH      (MAX_ETH_CH)
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
   .ext_mem_if    (ext_mem_if),
`endif

   .afu_axi_rx_a_if (mux_afu_axi_rx_a_if),
   .afu_axi_tx_a_if (mux_afu_axi_tx_a_if),
   .afu_axi_rx_b_if (mux_afu_axi_rx_b_if),
   .afu_axi_tx_b_if (mux_afu_axi_tx_b_if)
);

logic rst_n_q1;
always_ff @(posedge clk) begin
   rst_n_q1        <= rst_n;
end

genvar c;
generate
   for (c = 0; c < PG_NUM_PORTS; c = c + 1) begin: pcie_port_rst
      always @(posedge clk) port_rst_n_q1[c] <= port_rst_n[c];
      always @(posedge clk) port_rst_n_q2[c] <= port_rst_n_q1[c] && rst_n_q1;
   end 
endgenerate


// ======================================================
// Preserve clock and reset routing to PR region
// ======================================================

`ifndef PR_COMPILE

//
// These signals are preserved in the default FIM build's afu_main()
// in order to ensure they are available for subsequent PR builds.
// This preservation is only required during the initial FIM build.
// It is not required in afu_main() instances used during a PR build.
//

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

`endif //  `ifndef PR_COMPILE


//----------------------------------------------
// Remote Debug JTAG IP instantiation
//----------------------------------------------

wire remote_stp_conf_reset = ~rst_n_q1;
`include "ofs_fim_remote_stp_node.vh"

endmodule : afu_main

`endif //  `ifndef DISABLE_DEFAULT_FIM_AFU_MAIN

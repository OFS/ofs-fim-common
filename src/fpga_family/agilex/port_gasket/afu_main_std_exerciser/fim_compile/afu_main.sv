// Copyright 2020-2024 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
// Map the multiplexed ports coming from the FIM into demultiplexed PF/VF
// ports. Then pass an array of independent ports to port_afu_instances().


// Set this macro to disable this shared afu_main() and provide an AFU-specific
// version.
`ifndef DISABLE_DEFAULT_FIM_AFU_MAIN

`include "fpga_defines.vh"

`ifndef OPAE_PLATFORM_GEN
`include "ofs_plat_if.vh"
`endif

module afu_main 
#(
   parameter PG_NUM_LINKS    = 1,
   parameter PG_NUM_PORTS    = 1,
   // PF/VF to which each port is mapped
   parameter pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t[PG_NUM_PORTS-1:0] PORT_PF_VF_INFO =
                {PG_NUM_PORTS{pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t'(0)}},

   parameter NUM_MEM_CH      = 0,
`ifdef INCLUDE_HSSI
   parameter MAX_ETH_CH      = ofs_fim_eth_plat_if_pkg::MAX_NUM_ETH_CHANNELS,
`else
   parameter MAX_ETH_CH      = 0,
`endif

   parameter int PG_NUM_RTABLE_ENTRIES = 3,

   parameter pf_vf_mux_pkg::t_pfvf_rtable_entry[PG_NUM_RTABLE_ENTRIES-1:0] PG_PFVF_ROUTING_TABLE = {PG_NUM_RTABLE_ENTRIES{pf_vf_mux_pkg::t_pfvf_rtable_entry'(0)}},

   // Used in simulation by ASE to emulate multiple links. ASE PCIe emulation
   // supports only one link. The multi-link ASE environment adds an extra PF/VF
   // MUX before afu_main() and requires unique VFs across all links.
   parameter LINK_NUM_FROM_PORT_INFO = 0
)(
   input  logic clk,
   input  logic clk_div2,
   input  logic clk_div4,
   input  logic uclk_usr,
   input  logic uclk_usr_div2,

   input  logic rst_n,
   input  logic [PG_NUM_PORTS-1:0] port_rst_n[PG_NUM_LINKS-1:0],
   
   // PCIe A ports are the standard TLP channels. All host responses
   // arrive on the RX A port.
   pcie_ss_axis_if.source        afu_axi_tx_a_if[PG_NUM_LINKS-1:0],
   pcie_ss_axis_if.sink          afu_axi_rx_a_if[PG_NUM_LINKS-1:0],
   // PCIe B ports are a second channel on which reads and interrupts
   // may be sent from the AFU. To improve throughput, reads on B may flow
   // around writes on A through PF/VF MUX trees until writes are committed
   // to the PCIe subsystem. AFUs may tie off the B port and send all
   // messages to A.
   pcie_ss_axis_if.source        afu_axi_tx_b_if[PG_NUM_LINKS-1:0],
   // Write commits are signaled here on the RX B port, indicating the
   // point at which the A and B channels become ordered within the FIM.
   // Commits are signaled after tlast of a write on TX A, after arbitration
   // with TX B within the FIM. The commit is a Cpl (without data),
   // returning the tag value from the write request. AFUs that do not
   // need local write commits may ignore this port, but must set
   // tready to 1.
   pcie_ss_axis_if.sink          afu_axi_rx_b_if[PG_NUM_LINKS-1:0],

   `ifdef INCLUDE_LOCAL_MEM
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
   ofs_jtag_if.sink              remote_stp_jtag_if,
   input pr_freeze_to_afu        // optional for pr_freeze usage in afu
);

`ifdef OFS_PLAT_HOST_CHAN_MULTIPLEXED
   localparam IS_MULTIPLEXED = 1;
`else
   localparam IS_MULTIPLEXED = 0;
`endif

//PCIe port pipelines
localparam PL_DEPTH       = 1;
localparam TDATA_WIDTH    = pcie_ss_axis_pkg::TDATA_WIDTH;
localparam TUSER_WIDTH    = pcie_ss_axis_pkg::TUSER_WIDTH;
localparam TOTAL_PORTS    = PG_NUM_LINKS * PG_NUM_PORTS;

(* altera_attribute = {"-name PRESERVE_REGISTER_SYN_ONLY ON"} *)
reg [PG_NUM_LINKS-1:0][PG_NUM_PORTS-1:0] port_rst_n_q1 = {TOTAL_PORTS{1'b0}};

wire[PG_NUM_LINKS-1:0][PG_NUM_PORTS-1:0] port_rst_n_din;

reg rst_n_tree;
fim_dup_tree dup_rst(.clk, .din(rst_n), .dout(rst_n_tree));

// Registered streams, still on the FIM side of the PF/VF MUX.
pcie_ss_axis_if #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) afu_axi_tx_a_if_t1 [PG_NUM_LINKS-1:0](.clk(clk), .rst_n(rst_n_tree));
pcie_ss_axis_if #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) afu_axi_rx_a_if_t1 [PG_NUM_LINKS-1:0](.clk(clk), .rst_n(rst_n_tree));
pcie_ss_axis_if #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) afu_axi_tx_b_if_t1 [PG_NUM_LINKS-1:0](.clk(clk), .rst_n(rst_n_tree));
pcie_ss_axis_if #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) afu_axi_rx_b_if_t1 [PG_NUM_LINKS-1:0](.clk(clk), .rst_n(rst_n_tree));

`ifdef OFS_PLAT_HOST_CHAN_MULTIPLEXED
   // No PF/VF MUX. Pass the PF/VF tagged (multiplexed) TLP streams
   // directly to the AFU.
   pcie_ss_axis_if #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) port_rx_a_if [PG_NUM_LINKS-1:0](.clk(clk),.rst_n(rst_n_tree));
   pcie_ss_axis_if #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) port_tx_a_if [PG_NUM_LINKS-1:0](.clk(clk),.rst_n(rst_n_tree));
   pcie_ss_axis_if #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) port_rx_b_if [PG_NUM_LINKS-1:0](.clk(clk),.rst_n(rst_n_tree));
   pcie_ss_axis_if #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) port_tx_b_if [PG_NUM_LINKS-1:0](.clk(clk),.rst_n(rst_n_tree));

   // Port-level resets are still demultiplexed since they enter
   // afu_main that way. Retain the doubly indexed arrays and pass
   // it directly to port_afu_instances().
   reg [PG_NUM_PORTS-1:0] port_rst_n_tree[PG_NUM_LINKS-1:0];
`else
   // Normal case:
   //  Demultiplexed streams on the AFU side of the PF/VF MUX.
   //  The port_afu_instances() module receives a flattened array
   //  of ports, merging links and ports into a single dimension.

   // Per-port resets
   reg [TOTAL_PORTS-1:0] port_rst_n_tree;
   pcie_ss_axis_if #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) port_rx_a_if [TOTAL_PORTS-1:0](.clk(clk),.rst_n(port_rst_n_tree));
   pcie_ss_axis_if #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) port_tx_a_if [TOTAL_PORTS-1:0](.clk(clk),.rst_n(port_rst_n_tree));
   pcie_ss_axis_if #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) port_rx_b_if [TOTAL_PORTS-1:0](.clk(clk),.rst_n(port_rst_n_tree));
   pcie_ss_axis_if #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) port_tx_b_if [TOTAL_PORTS-1:0](.clk(clk),.rst_n(port_rst_n_tree));
`endif

// Linear mapping function from link/port to the array that
// will reach port_afu_instances().
function automatic int linearLinkPort(int link, int port);
   // The linearization function interleaves ports from all
   // links. OFS requires that each incoming link have the same
   // PF/VF settings so that there is an equal number of ports
   // on each link.
   //
   // Concatenate ports, starting with link 0, then link 1...
   return port + PG_NUM_PORTS * link;
endfunction


// Generate the full linearized vector describing the ports that will
// be passed to port_afu_instances(). Ports from each link are concatenated.
typedef pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t[TOTAL_PORTS-1:0] t_afu_prr_pf_vf_map;
function automatic t_afu_prr_pf_vf_map gen_prr_pf_vf_map();
   t_afu_prr_pf_vf_map map;
   for (int link = 0; link < PG_NUM_LINKS; link = link + 1) begin
      for (int p = 0; p < PG_NUM_PORTS; p = p + 1) begin
         map[link * PG_NUM_PORTS + p].link_num = link;
         map[link * PG_NUM_PORTS + p].pf_num = PORT_PF_VF_INFO[p].pf_num;
         map[link * PG_NUM_PORTS + p].vf_active = PORT_PF_VF_INFO[p].vf_active;
         if (LINK_NUM_FROM_PORT_INFO)
            // ASE - unique VF numbers across all links
            map[link * PG_NUM_PORTS + p].vf_num = PORT_PF_VF_INFO[p].vf_num + (link * PG_NUM_PORTS);
         else
            map[link * PG_NUM_PORTS + p].vf_num = PORT_PF_VF_INFO[p].vf_num;
      end
   end
   return map;
endfunction // gen_prr_pf_vf_map

localparam pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t[TOTAL_PORTS-1:0] TOTAL_PORT_PF_VF_INFO =
   gen_prr_pf_vf_map();


// ======================================================
// Pipeline PCIe ports in PR region before consuming
// ======================================================

for (genvar j=0; j<PG_NUM_LINKS; j++) begin : PCIE_FREEZE_BRIDGE
   // All ports need to flopped and preserved
   // Port A - Primary Port for all Traffic
   ofs_fim_axis_long_skid #(
      .PRESERVE_REG("RX")
   ) pcie_pipeline_rx_a (
      .clk     (afu_axi_rx_a_if[j].clk),
      .rst_n   (afu_axi_rx_a_if[j].rst_n),
      .axis_s  (afu_axi_rx_a_if[j]),        // <--- PCIe SS
      .axis_m  (afu_axi_rx_a_if_t1[j])      // ---> AFU workload
   );

   ofs_fim_axis_pipeline #(
      .PRESERVE_REG("TX"),
      .PL_DEPTH    (PL_DEPTH)
   ) pcie_pipeline_tx_a (
      .clk     (afu_axi_tx_a_if[j].clk),
      .rst_n   (afu_axi_tx_a_if[j].rst_n),
      .axis_s  (afu_axi_tx_a_if_t1[j]),     // <--- AFU workload
      .axis_m  (afu_axi_tx_a_if[j])         // ---> PCIe SS
   );
 
   // Port B - Secondary Port
   ofs_fim_axis_long_skid #(
      .PRESERVE_REG("RX")
   ) pcie_pipeline_rx_b (
      .clk     (afu_axi_rx_b_if[j].clk),
      .rst_n   (afu_axi_rx_b_if[j].rst_n),
      .axis_s  (afu_axi_rx_b_if[j]),        // <--- PCIe SS
      .axis_m  (afu_axi_rx_b_if_t1[j])      // ---> AFU workload
   );

   ofs_fim_axis_pipeline #(
      .PRESERVE_REG("TX"),
      .PL_DEPTH    (PL_DEPTH)
   ) pcie_pipeline_tx_b (
      .clk     (afu_axi_tx_b_if[j].clk),
      .rst_n   (afu_axi_tx_b_if[j].rst_n),
      .axis_s  (afu_axi_tx_b_if_t1[j]),     // <--- AFU workload
      .axis_m  (afu_axi_tx_b_if[j])         // ---> PCIe SS
   );
end // for: PCIE_FREEZE_BRIDGE


`ifdef OFS_PLAT_HOST_CHAN_MULTIPLEXED

// No PF/VF MUX. Pass the multiplexed link streams directly to the AFU.
generate
   for (genvar link = 0; link < PG_NUM_LINKS; link = link + 1) begin: no_mux
      ofs_fim_axis_pipeline #(.PL_DEPTH(0)) conn_tx_a (.clk, .rst_n(rst_n_tree), .axis_s(port_tx_a_if[link]), .axis_m(afu_axi_tx_a_if_t1[link]));
      ofs_fim_axis_pipeline #(.PL_DEPTH(0)) conn_rx_a (.clk, .rst_n(rst_n_tree), .axis_s(afu_axi_rx_a_if_t1[link]), .axis_m(port_rx_a_if[link]));
      ofs_fim_axis_pipeline #(.PL_DEPTH(0)) conn_tx_b (.clk, .rst_n(rst_n_tree), .axis_s(port_tx_b_if[link]), .axis_m(afu_axi_tx_b_if_t1[link]));
      ofs_fim_axis_pipeline #(.PL_DEPTH(0)) conn_rx_b (.clk, .rst_n(rst_n_tree), .axis_s(afu_axi_rx_b_if_t1[link]), .axis_m(port_rx_b_if[link]));
   end
endgenerate

`else

// Normal AFU -- add PF/VF MUX to map links to individual ports
generate
   for (genvar link = 0; link < PG_NUM_LINKS; link = link + 1) begin: mux
      // Build a separate PF/VF MUX for each PCIe link.
      pcie_ss_axis_if #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) rx_a_if [PG_NUM_PORTS-1:0](.clk(clk),.rst_n(port_rst_n[link]));
      pcie_ss_axis_if #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) tx_a_if [PG_NUM_PORTS-1:0](.clk(clk),.rst_n(port_rst_n[link]));
      pcie_ss_axis_if #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) rx_b_if [PG_NUM_PORTS-1:0](.clk(clk),.rst_n(port_rst_n[link]));
      pcie_ss_axis_if #(.DATA_W (TDATA_WIDTH), .USER_W (TUSER_WIDTH)) tx_b_if [PG_NUM_PORTS-1:0](.clk(clk),.rst_n(port_rst_n[link]));

      localparam MUX_NAME = PG_NUM_LINKS == 1 ? "PG" : $sformatf("PG%0d", link);

      // Primary PF/VF MUX ("A" ports). Map individual TX A ports from
      // AFUs down to a single, merged A channel. The RX port from host
      // to FPGA is demultiplexed and individual connections are forwarded
      // to AFUs.
      pf_vf_mux_tree #(
         .MUX_NAME({ MUX_NAME, "_A" }),
         .NUM_PORT(PG_NUM_PORTS),
         .NUM_RTABLE_ENTRIES(PG_NUM_RTABLE_ENTRIES),
         .PFVF_ROUTING_TABLE(PG_PFVF_ROUTING_TABLE)
      ) pg_pf_vf_mux_a (
         .clk             (clk),
         .rst_n           (rst_n_tree),
         .ho2mx_rx_port   (afu_axi_rx_a_if_t1[link]),
         .mx2ho_tx_port   (afu_axi_tx_a_if_t1[link]),
         .mx2fn_rx_port   (rx_a_if),
         .fn2mx_tx_port   (tx_a_if),
         .out_fifo_err    (),
         .out_fifo_perr   ()
         );

      // Secondary PF/VF MUX ("B" ports). Only TX is implemented, since a
      // single RX stream is sufficient. The RX input to the MUX is tied off.
      // AFU B TX ports are multiplexed into a single TX B channel that is
      // passed to the A/B MUX above.
      pf_vf_mux_tree #(
         .MUX_NAME({ MUX_NAME, "_B" }),
         .NUM_PORT(PG_NUM_PORTS),
         .NUM_RTABLE_ENTRIES(PG_NUM_RTABLE_ENTRIES),
         .PFVF_ROUTING_TABLE(PG_PFVF_ROUTING_TABLE)
      ) pg_pf_vf_mux_b (
         .clk             (clk),
         .rst_n           (rst_n_tree),
         .ho2mx_rx_port   (afu_axi_rx_b_if_t1[link]),
         .mx2ho_tx_port   (afu_axi_tx_b_if_t1[link]),
         .mx2fn_rx_port   (rx_b_if),
         .fn2mx_tx_port   (tx_b_if),
         .out_fifo_err    (),
         .out_fifo_perr   ()
         );

      // Map the AFU side of the current link's PF/VF MUX into the linearized
      // port vector that will connect to port_afu_instances().
      for (genvar p = 0; p < PG_NUM_PORTS; p = p + 1) begin: conn
         localparam c = linearLinkPort(link, p);

         ofs_fim_axis_pipeline #(.PL_DEPTH(0)) conn_tx_a (.clk, .rst_n(port_rst_n_tree[c]), .axis_s(port_tx_a_if[c]), .axis_m(tx_a_if[p]));
         ofs_fim_axis_pipeline #(.PL_DEPTH(0)) conn_rx_a (.clk, .rst_n(port_rst_n_tree[c]), .axis_s(rx_a_if[p]), .axis_m(port_rx_a_if[c]));
         ofs_fim_axis_pipeline #(.PL_DEPTH(0)) conn_tx_b (.clk, .rst_n(port_rst_n_tree[c]), .axis_s(port_tx_b_if[c]), .axis_m(tx_b_if[p]));
         ofs_fim_axis_pipeline #(.PL_DEPTH(0)) conn_rx_b (.clk, .rst_n(port_rst_n_tree[c]), .axis_s(rx_b_if[p]), .axis_m(port_rx_b_if[c]));
      end
   end // block: mux
endgenerate

`endif


// ======================================================
// Instantiate AFUs
// ======================================================

port_afu_instances #(
   .PG_NUM_LINKS    (PG_NUM_LINKS),
   .PG_NUM_PORTS    (IS_MULTIPLEXED ? PG_NUM_PORTS : TOTAL_PORTS),
   .PORT_PF_VF_INFO (IS_MULTIPLEXED ? PORT_PF_VF_INFO : TOTAL_PORT_PF_VF_INFO),
`ifdef OFS_PLAT_HOST_CHAN_MULTIPLEXED
   .LINK_NUM_FROM_PORT_INFO(LINK_NUM_FROM_PORT_INFO),
`endif
   .NUM_MEM_CH      (NUM_MEM_CH),
   .MAX_ETH_CH      (MAX_ETH_CH)
) port_afu_instances (
   .clk           	(clk),
   .clk_div2      	(clk_div2),
   .clk_div4      	(clk_div4),
   .uclk_usr      	(uclk_usr),
   .uclk_usr_div2 	(uclk_usr_div2),
   .rst_n         	(rst_n_tree),
   .port_rst_n    	(port_rst_n_tree),
   .pr_freeze_to_afu	(pr_freeze_to_afu), 
`ifdef INCLUDE_HSSI
   .hssi_ss_st_tx  	(hssi_ss_st_tx),
   .hssi_ss_st_rx  	(hssi_ss_st_rx),
   .hssi_fc        	(hssi_fc),
   .i_hssi_clk_pll 	(i_hssi_clk_pll),
`endif

`ifdef INCLUDE_LOCAL_MEM
   .ext_mem_if    	(ext_mem_if),
`endif

   .afu_axi_rx_a_if 	(port_rx_a_if),
   .afu_axi_tx_a_if 	(port_tx_a_if),
   .afu_axi_rx_b_if 	(port_rx_b_if),
   .afu_axi_tx_b_if 	(port_tx_b_if)
);


(* altera_attribute = {"-name PRESERVE_REGISTER_SYN_ONLY ON"} *) reg rst_n_q1;
always_ff @(posedge clk) begin
   rst_n_q1        <= rst_n;
end

// Add fanout to port-level resets
generate
   for (genvar link = 0; link < PG_NUM_LINKS; link = link + 1) begin: rst_link
      for (genvar p = 0; p < PG_NUM_PORTS; p = p + 1) begin: rst_p
         always @(posedge clk) port_rst_n_q1[link][p] <= port_rst_n[link][p];
         assign port_rst_n_din[link][p] = port_rst_n_q1[link][p] && rst_n_q1;

         // Multi-cycle duplication tree
`ifdef OFS_PLAT_HOST_CHAN_MULTIPLEXED
         // No PF/VF MUX - resets remain indexed by link then port
         fim_dup_tree dup_port_rst(.clk, .din(port_rst_n_din[link][p]), .dout(port_rst_n_tree[link][p]));
`else
         // With PF/VF MUX - lap incoming port-level resets to the
         // same order as the flattend port vectors port_rx_a_if, etc.
         localparam c = linearLinkPort(link, p);

         fim_dup_tree dup_port_rst(.clk, .din(port_rst_n_din[link][p]), .dout(port_rst_n_tree[c]));
`endif
      end
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

wire remote_stp_conf_reset = ~rst_n_tree;
`include "ofs_fim_remote_stp_node.vh"

endmodule : afu_main

`endif //  `ifndef DISABLE_DEFAULT_FIM_AFU_MAIN

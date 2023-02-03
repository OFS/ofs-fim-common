// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//  Instantiates HE-LPBK, HE-HSSI and MEM_INTF
// -----------------------------------------------------------------------------
//
// This simple AFU example connects test exercisers directly to the device
// interfaces. A new AFU could be constructed by starting with this afu_main()
// and replacing the body with RTL that instantiates the desired accelerator.
//

`include "fpga_defines.vh"

import top_cfg_pkg::*;
import ofs_fim_eth_if_pkg::*;

module afu_main # (
   parameter PG_NUM_PORTS    = 1,
   // PF/VF to which each port is mapped
   parameter pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t[PG_NUM_PORTS-1:0] PORT_PF_VF_INFO =
                {PG_NUM_PORTS{pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t'(0)}},

   parameter NUM_MEM_CH      = NUM_MEM_CH
)(
   input  logic                  clk,
   input  logic                  clk_div2,
   input  logic                  clk_div4,
   input  logic                  uclk_usr,
   input  logic                  uclk_usr_div2,
   input  logic                  rst_n_100M,   
   input  logic                  rst_n,
   input  logic                  port_rst_n          [PG_NUM_PORTS-1:0],
   
   // PCIe A ports are the standard TLP channels. All host responses
   // arrive on the RX A port.
   pcie_ss_axis_if.source        afu_axi_tx_a_if     [PG_NUM_PORTS-1:0],
   pcie_ss_axis_if.sink          afu_axi_rx_a_if     [PG_NUM_PORTS-1:0],
   // PCIe B ports are a second channel on which reads and interrupts
   // may be sent from the AFU. To improve throughput, reads on B may flow
   // around writes on A through PF/VF MUX trees until writes are committed
   // to the PCIe subsystem. AFUs may tie off the B port and send all
   // messages to A.
   pcie_ss_axis_if.source        afu_axi_tx_b_if     [PG_NUM_PORTS-1:0],
   // Write commits are signaled here on the RX B port, indicating the
   // point at which the A and B channels become ordered within the FIM.
   // Commits are signaled after tlast of a write on TX A, after arbitration
   // with TX B within the FIM. The commit is a Cpl (without data),
   // returning the tag value from the write request. AFUs that do not
   // need local write commits may ignore this port, but must set
   // tready to 1.
   pcie_ss_axis_if.sink          afu_axi_rx_b_if     [PG_NUM_PORTS-1:0],
   
   ofs_fim_emif_avmm_if.user     ext_mem_if          [NUM_MEM_CH],
   
`ifdef INCLUDE_HE_HSSI  
   ofs_fim_hssi_ss_tx_axis_if.client       hssi_ss_st_tx [MAX_NUM_ETH_CHANNELS-1:0],
   ofs_fim_hssi_ss_rx_axis_if.client       hssi_ss_st_rx [MAX_NUM_ETH_CHANNELS-1:0],
   ofs_fim_hssi_fc_if.client               hssi_fc [MAX_NUM_ETH_CHANNELS-1:0],
   `ifdef INCLUDE_PTP
      ofs_fim_hssi_ptp_tx_tod_if.client    hssi_ptp_tx_tod [MAX_NUM_ETH_CHANNELS-1:0],
      ofs_fim_hssi_ptp_rx_tod_if.client    hssi_ptp_rx_tod [MAX_NUM_ETH_CHANNELS-1:0],
      ofs_fim_hssi_ptp_tx_egrts_if.client  hssi_ptp_tx_egrts [MAX_NUM_ETH_CHANNELS-1:0],
      ofs_fim_hssi_ptp_rx_ingrts_if.client hssi_ptp_rx_ingrts [MAX_NUM_ETH_CHANNELS-1:0],
   `endif
   input logic [MAX_NUM_ETH_CHANNELS-1:0] i_hssi_clk_pll,
`endif

   // JTAG interface for PR region debug
   input  logic                  sr2pr_tms,
   input  logic                  sr2pr_tdi,
   output logic                  pr2sr_tdo,
   input  logic                  sr2pr_tck,
   input  logic                  sr2pr_tckena
);

//-----------------------------------------------------------------------------
// Resets - Split for timing
// synthesis preserve_syn_only - Prevents removal of registers during synthesis. 
// This settings does not affect retiming or other optimizations in the Fitter.
//-----------------------------------------------------------------------------
logic rst_n_a = 1'b0 /* synthesis preserve_syn_only */ ;
logic rst_n_b = 1'b0 /* synthesis preserve_syn_only */ ;
logic rst_n_c = 1'b0 /* synthesis preserve_syn_only */ ;
logic rst_n_d = 1'b0 /* synthesis preserve_syn_only */ ;

always @ (posedge clk) begin
   rst_n_a  <= rst_n;
   rst_n_b  <= rst_n;
   rst_n_c  <= rst_n;
   rst_n_d  <= rst_n;
end

//---------------------------------------------------------------------------------------------------
//AXI_PORT[0]: HE-MEM
//---------------------------------------------------------------------------------------------------

he_mem_top #(
   .PF_ID     (PORT_PF_VF_INFO[0].pf_num),
   .VF_ID     (PORT_PF_VF_INFO[0].vf_num),
   .VF_ACTIVE (PORT_PF_VF_INFO[0].vf_active),
   .EMIF      (1),
   .NUM_MEM_BANKS(NUM_MEM_CH)
) he_lb_inst (
   .clk        (clk),
   .rst_n      (rst_n_a & port_rst_n[0]),
   .axi_rx_a_if(afu_axi_rx_a_if[0]),
   .axi_rx_b_if(afu_axi_rx_b_if[0]),
   .axi_tx_a_if(afu_axi_tx_a_if[0]),
   .axi_tx_b_if(afu_axi_tx_b_if[0]),
   // Pass bank 0 to HE MEM. The other banks are tied off in this example.
   .ext_mem_if (ext_mem_if)
);


`ifdef INCLUDE_HE_HSSI  
//---------------------------------------------------------------------------------------------------
//AXI_PORT[1]: HE-HSSI
//---------------------------------------------------------------------------------------------------

he_hssi_top #(
   .PF_NUM    (PORT_PF_VF_INFO[1].pf_num),
   .VF_NUM    (PORT_PF_VF_INFO[1].vf_num),
   .VF_ACTIVE (PORT_PF_VF_INFO[1].vf_active)
) he_hssi_top_inst (
   .clk                    (clk),
   .softreset              (!rst_n_c | !port_rst_n[1]),
   .axis_rx_if             (afu_axi_rx_a_if[1]),  
   .axis_tx_if             (afu_axi_tx_a_if[1]),  
   .hssi_ss_st_tx          (hssi_ss_st_tx),
   .hssi_ss_st_rx          (hssi_ss_st_rx),
   .hssi_fc                (hssi_fc),

   `ifdef INCLUDE_PTP
      .hssi_ptp_tx_tod     (hssi_ptp_tx_tod),
      .hssi_ptp_rx_tod     (hssi_ptp_rx_tod),
      .hssi_ptp_tx_egrts   (hssi_ptp_tx_egrts),
      .hssi_ptp_rx_ingrts  (hssi_ptp_rx_ingrts),
   `endif

   .i_hssi_clk_pll         (i_hssi_clk_pll)
);
`endif

// HE HSSI does not use the TX B port
assign afu_axi_tx_b_if[1].tvalid = 1'b0;
assign afu_axi_rx_b_if[1].tready = 1'b1;

//----------------------------
// Preserve unused clocks for use by other AFUs that use this instance
// as the base FIM compilation.
//----------------------------
(* noprune *) logic uclk_usr_q1, uclk_usr_q2;
(* noprune *) logic uclk_usr_div2_q1, uclk_usr_div2_q2;
(* noprune *) logic clk_div2_q1, clk_div2_q2;
(* noprune *) logic clk_div4_q1, clk_div4_q2;

always_ff @(posedge uclk_usr) begin
   uclk_usr_q1 <= uclk_usr_q2;
   uclk_usr_q2 <= ~uclk_usr_q1;
end

always_ff @(posedge uclk_usr_div2) begin
   uclk_usr_div2_q1 <= uclk_usr_div2_q2;
   uclk_usr_div2_q2 <= ~uclk_usr_div2_q1;
end

always_ff @(posedge clk_div2) begin
   clk_div2_q1 <= clk_div2_q2;
   clk_div2_q2 <= ~clk_div2_q1;
end

always_ff @(posedge clk_div4) begin
   clk_div4_q1 <= clk_div4_q2;
   clk_div4_q2 <= ~clk_div4_q1;
end

//----------------------------
// Remote Debug JTAG IP instantiation
//----------------------------

wire remote_stp_conf_reset = ~rst_n_100M;
`include "ofs_fim_remote_stp_node.vh"

endmodule

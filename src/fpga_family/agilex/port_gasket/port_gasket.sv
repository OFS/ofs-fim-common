// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// PORT Gasket
//-----------------------------------------------------------------------------

import pcie_ss_axis_pkg::*;
import ofs_fim_if_pkg::*;
import ofs_fim_eth_if_pkg::*;

module  port_gasket #(
   parameter PG_NUM_PORTS      = 1,
   // PF/VF to which each port is mapped
   parameter pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t[PG_NUM_PORTS-1:0] PORT_PF_VF_INFO =
                {PG_NUM_PORTS{pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t'(0)}},

   parameter END_OF_LIST       = 1'b0,
   parameter NEXT_DFH_OFFSET   = 24'h01_0000,

   parameter MM_ADDR_WIDTH     = 18,
   parameter MM_DATA_WIDTH     = 64,

   parameter EMIF              = 0,
   parameter NUM_MEM_CH        = 0,

   parameter int PG_NUM_RTABLE_ENTRIES = 3,
   parameter pf_vf_mux_pkg::t_pfvf_rtable_entry[PG_NUM_RTABLE_ENTRIES-1:0] PG_PFVF_ROUTING_TABLE = {PG_NUM_RTABLE_ENTRIES{pf_vf_mux_pkg::t_pfvf_rtable_entry'(0)}}
)(
   input                       refclk,
   input                       clk,
   input                       clk_div2,
   input                       clk_div4,
   input                       clk_100,
   input                       clk_csr,

   input                       rst_n,
   input                       rst_n_100,
   input                       rst_n_csr,
   input  logic  [PG_NUM_PORTS-1:0]  func_pf_rst_n,
   input  logic  [PG_NUM_PORTS-1:0]  func_vf_rst_n,

   input  logic                i_sel_mmio_rsp,
   input  logic                i_read_flush_done,
   output logic                o_port_softreset_n,
   output logic                o_afu_softreset,
   output logic                o_pr_parity_error,
   
   pcie_ss_axis_if.source      axi_tx_a_if,
   pcie_ss_axis_if.sink        axi_rx_a_if,
   pcie_ss_axis_if.source      axi_tx_b_if,
   pcie_ss_axis_if.sink        axi_rx_b_if,

`ifdef INCLUDE_DDR4
   ofs_fim_emif_axi_mm_if.user afu_mem_if  [NUM_MEM_CH-1:0],
`endif

`ifdef INCLUDE_HSSI
   ofs_fim_hssi_ss_tx_axis_if.client     hssi_ss_st_tx [MAX_NUM_ETH_CHANNELS-1:0],
   ofs_fim_hssi_ss_rx_axis_if.client     hssi_ss_st_rx [MAX_NUM_ETH_CHANNELS-1:0],
   ofs_fim_hssi_fc_if.client             hssi_fc [MAX_NUM_ETH_CHANNELS-1:0],
   input logic [MAX_NUM_ETH_CHANNELS-1:0] i_hssi_clk_pll,
`endif

   ofs_fim_axi_lite_if.slave   axi_s_if
);

pr_ctrl_if #( .CSR_REG_WIDTH(64))   pr_ctrl_io();

logic                               pr_freeze;
logic                               pr_reset;
logic                               pr_m20k_ce_ctl_req;

logic                               port_softreset_n;
logic                               afu_softreset;
   
// user_clock <--> pg_csr if
logic   [63:0]                      user_clk_freq_cmd_0;
logic   [63:0]                      user_clk_freq_cmd_1;
logic   [63:0]                      user_clk_freq_sts_0;
logic   [63:0]                      user_clk_freq_sts_1;

logic                               uclk;
logic                               uclk_div2;
logic   [63:0]                      rst2csr_port_ctrl;
logic   [63:0]                      csr2rst_port_ctrl;

t_sideband_from_pcie                pcie_p2c_sideband;

logic [63:0]                        remotestp_status;

ofs_fim_axi_mmio_if                 s_remote_stp_csr_if();
ofs_fim_axi_lite_if                 m_remote_stp_csr_if();


ofs_jtag_if                        remote_stp_jtag_if();
    


logic [PG_NUM_PORTS-1:0] func_vf_rst_n_d;
logic [PG_NUM_PORTS-1:0] port_rst_n = {PG_NUM_PORTS{1'b0}};
// ----------------------------------------------------------------------------------------------------
//  PCIe port_rst_n generation
// ----------------------------------------------------------------------------------------------------

genvar c;
generate
   for (c = 0; c < PG_NUM_PORTS; c = c + 1) begin: pcie_port
      // Reset generation for each PCIe VF port in PR slot
      // Reset sources
      // - afu_softreset
      // --- PCIe hip
      // --- Reset from PR FSM
      // --- softreset from Port CSR
      // - PF Flr containing the VFs in PR slot
      // - VF Flr
      // - PCIe system reset
      always @(posedge clk) port_rst_n[c] <= ~o_afu_softreset && func_pf_rst_n[c] && func_vf_rst_n[c] && rst_n;
   end //for
endgenerate


// ----------------------------------------------------------------------------------------------------
//  PR Slot Inst
// ----------------------------------------------------------------------------------------------------
pr_slot #(
   .PG_NUM_PORTS          (PG_NUM_PORTS),
   .PORT_PF_VF_INFO       (PORT_PF_VF_INFO),
   .EMIF                  (EMIF),
   .NUM_MEM_CH            (NUM_MEM_CH),
   .PG_NUM_RTABLE_ENTRIES (PG_NUM_RTABLE_ENTRIES),
   .PG_PFVF_ROUTING_TABLE (PG_PFVF_ROUTING_TABLE)
) pr_slot (
   .clk,
   .clk_div2,
   .clk_div4,
   .uclk_usr       (uclk),
   .uclk_usr_div2  (uclk_div2),
   .rst_n,

   // Memory interface   
`ifdef INCLUDE_DDR4
   .afu_mem_if    (afu_mem_if),
`endif

   // Rst for all logic in PR slot
   // Generated from the following sources
   // - PCIe Hip
   // - PR process
   // - Port CSR softreset
   .softreset     (o_afu_softreset),

   // Rst to PCIe ports in PG
   // - afu_softreset
   // - PF Flr
   // - VF flr
   .port_rst_n,
   
   .pr_freeze,
   .pr_m20k_ce_ctl_req,
   
   // PCIe interfaces
   .axi_tx_a_if,
   .axi_rx_a_if,
   .axi_tx_b_if,
   .axi_rx_b_if,

   // HSSI interface
`ifdef INCLUDE_HSSI
   .hssi_ss_st_tx    (hssi_ss_st_tx),
   .hssi_ss_st_rx    (hssi_ss_st_rx),
   .hssi_fc          (hssi_fc),
   .i_hssi_clk_pll   (i_hssi_clk_pll),
`endif //INCLUDE_HSSI

   // Remote STP
   .remote_stp_jtag_if
);

// ----------------------------------------------------------------------------------------------------
//  User Clock Inst
// ----------------------------------------------------------------------------------------------------
user_clock user_clock (
   .refclk              (refclk),
   .clk_csr,  //source-clk of user_clk_freq_cmd_? data; dest-clk of user_clk_freq_sts_? data.
   .clk_100             (clk_100),

   .rst_n_csr,  //source-rst of user_clk_freq_cmd_? data; dest-rst of user_clk_freq_sts_? data.
   .rst_n_clk100        (rst_n_100),

   .user_clk_freq_cmd_0 (user_clk_freq_cmd_0),
   .user_clk_freq_cmd_1 (user_clk_freq_cmd_1),
   .user_clk_freq_sts_0 (user_clk_freq_sts_0),
   .user_clk_freq_sts_1 (user_clk_freq_sts_1),

   .uclk                (uclk),
   .uclk_div2           (uclk_div2)
);


// ----------------------------------------------------------------------------------------------------
//  PG CSR Inst
// ----------------------------------------------------------------------------------------------------
pg_csr #(
   .END_OF_LIST     (END_OF_LIST),
   .NEXT_DFH_OFFSET (NEXT_DFH_OFFSET),
   .ADDR_WIDTH      (MM_ADDR_WIDTH),
   .DATA_WIDTH      (MM_DATA_WIDTH),
   .AGILEX          (1)
) pg_csr (
   .clk                 (clk_csr),
   .rst_n               (rst_n_csr),

   .axi_s_if            (axi_s_if),

   .pr_ctrl_io          (pr_ctrl_io),
   .i_pr_freeze         (pr_freeze),

   .i_port_ctrl         (rst2csr_port_ctrl),
   .o_port_ctrl         (csr2rst_port_ctrl),

   .user_clk_freq_cmd_0 (user_clk_freq_cmd_0),
   .user_clk_freq_cmd_1 (user_clk_freq_cmd_1),
   .user_clk_freq_sts_0 (user_clk_freq_sts_0),
   .user_clk_freq_sts_1 (user_clk_freq_sts_1),

   .i_remotestp_status  (remotestp_status),
   .m_remotestp_if      (m_remote_stp_csr_if)
);

//-------------------
// Port reset FSM
//-------------------
port_reset_fsm port_reset_fsm_inst (
   .clk_2x              (clk_csr),
   .rst_n_2x            (rst_n_csr),
   
   // PR reset
   .i_pr_reset          (pr_reset),
   
   // Port CSR
   .i_port_ctrl         (csr2rst_port_ctrl),     // SW port reset
   .i_afu_access_ctrl   (1'b1),                  // 1 = VF mode
   .o_port_ctrl         (rst2csr_port_ctrl),
   .o_vf_flr_access_err (),
   
   // FLR signals
   .i_pcie_p2c_sideband (pcie_p2c_sideband),
   .o_pcie_c2p_sideband (),
  
   // Port traffic controller signals
   .i_sel_mmio_rsp    (1'b1),      // Tx FIFO Empty
   .i_read_flush_done  (1'b1),      // Pending Read = 0
   
   //.i_sel_mmio_rsp    (i_sel_mmio_rsp),      // Tx FIFO Empty
   //.i_read_flush_done  (i_read_flush_done),      // Pending Read = 0
   
   // Reset output
   .o_afu_softreset    (afu_softreset),
   .o_port_softreset_n (port_softreset_n)
);

fim_resync #(
   .SYNC_CHAIN_LENGTH (2),
   .WIDTH             (1),
   .INIT_VALUE        (1),
   .NO_CUT            (0)
) afu_softreset_sync (
   .clk   (clk),
   .reset (1'b0),
   .d     (afu_softreset),
   .q     (o_afu_softreset)
);

fim_resync #(
   .SYNC_CHAIN_LENGTH (2),
   .WIDTH             (1),
   .INIT_VALUE        (0),
   .NO_CUT            (0)
) port_softreset_sync (
   .clk   (clk),
   .reset (1'b0),
   .d     (port_softreset_n),
   .q     (o_port_softreset_n)
);

integer i;
always_comb begin
   pcie_p2c_sideband                   = '0;
   for ( i = 0 ; i < PG_NUM_PORTS ; i = i + 1'b1 )
      if ( !func_vf_rst_n[i] ) begin
         pcie_p2c_sideband.flr_rcvd_vf_num   = i + 1'b1;    // [0] = VF1, [1] = VF2, ...
         pcie_p2c_sideband.flr_rcvd_vf       = 1'b1;
      end
end

// ----------------------------------------------------------------------------------------------------
//  Remote STP
// ----------------------------------------------------------------------------------------------------
// AXI-lite adapter
axi_lite2mmio axi_lite2mmio (
   .clk     (clk_csr),
   .rst_n   (rst_n_csr),
   .lite_if (m_remote_stp_csr_if),
   .mmio_if (s_remote_stp_csr_if)
);

// Remote SignalTap module 
remote_stp_top remote_stp_top (
   .clk_100                (clk_100             ),
   .csr_if                 (s_remote_stp_csr_if ),
   .o_sr2pr_tms            (remote_stp_jtag_if.tms),
   .o_sr2pr_tdi            (remote_stp_jtag_if.tdi ),
   .i_pr2sr_tdo            (remote_stp_jtag_if.tdo),
   .o_sr2pr_tck            (remote_stp_jtag_if.tck ),
   .o_sr2pr_tckena         (remote_stp_jtag_if.tckena),
   .remotestp_status       (remotestp_status),
   .remotestp_parity_err   ()

);

// ----------------------------------------------------------------------------------------------------
//  PR Controller Inst
// ----------------------------------------------------------------------------------------------------
`ifdef INCLUDE_PR

`define INCLUDE_PR_M20K_PROTECTION
pr_ctrl pr_ctrl (
   // Clks and Reset
   .clk_1x              (clk_csr), // 100MHz clock for PR IP
   .clk_2x              (clk_csr), // 100Mhz clock CSR intf
   .rst_n_1x            (rst_n_csr),
   .rst_n_2x            (rst_n_csr),
   .o_pr_fifo_parity_err(o_pr_parity_error),
   .o_pr_m20k_ce_ctl_req(pr_m20k_ce_ctl_req),

   // PR CTRL Interface
   .pr_ctrl_io          (pr_ctrl_io),

   // PR to port signals
   .o_pr_reset          (pr_reset),
   .o_pr_freeze         (pr_freeze)  // will be connected to freeze logic,  1=holds
);
`else
   always_comb begin
      pr_ctrl_io.inp2prc_pg_pr_ctrl   = '0;
      pr_ctrl_io.inp2prc_pg_pr_status = '0;
      pr_ctrl_io.inp2prc_pg_pr_error  = '0;
      pr_ctrl_io.inp2prc_pg_error     = '0;
      pr_reset                        = '0;
      pr_m20k_ce_ctl_req              = '0;
      pr_freeze                       = '0;
   end
`endif

//-----------------------------------------------------------------
// Send PR FIFO Parity Error to FME for backward compatibility
//-----------------------------------------------------------------
//assign o_pr_parity_error = pr_ctrl_io.inp2prc_pg_error[0];

endmodule

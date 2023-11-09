// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// PORT Gasket
//-----------------------------------------------------------------------------

import pcie_ss_pkg::*;
import top_cfg_pkg::*;
import ofs_fim_if_pkg::*;
import ofs_fim_eth_plat_if_pkg::*;

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
   parameter NUM_MEM_CH        = NUM_MEM_CH
)(
   input                       refclk,
   input                       clk_100,
   input                       clk_2x,
   input                       clk_1x,
   input                       clk_div4,

   input                       rst_n_2x,
   input                       rst_n_1x,
   input                       rst_n_100,
   input  logic                port_rst_n  [PG_NUM_PORTS-1:0],
   
   input  logic                i_sel_mmio_rsp,
   input  logic                i_read_flush_done,
   output logic                o_port_softreset_n,
   output logic                o_afu_softreset,
   output logic                o_pr_parity_error,
   
   pcie_ss_axis_if.source      axi_tx_a_if [PG_NUM_PORTS-1:0],
   pcie_ss_axis_if.sink        axi_rx_a_if [PG_NUM_PORTS-1:0],
   pcie_ss_axis_if.source      axi_tx_b_if [PG_NUM_PORTS-1:0],
   pcie_ss_axis_if.sink        axi_rx_b_if [PG_NUM_PORTS-1:0],

   `ifdef INCLUDE_HE_HSSI  
      ofs_fim_hssi_ss_tx_axis_if.client      hssi_ss_st_tx [MAX_NUM_ETH_CHANNELS-1:0],
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

   ofs_fim_axi_lite_if.slave   axi_s_if,
   ofs_fim_emif_avmm_if.user   afu_mem_if  [NUM_MEM_CH-1:0]
);

pr_ctrl_if #( .CSR_REG_WIDTH(64))   pr_ctrl_io();

logic                       pr_freeze;
logic                       pr_reset;

// user_clock <--> pg_csr if
logic   [63:0]              user_clk_freq_cmd_0;
logic   [63:0]              user_clk_freq_cmd_1;
logic   [63:0]              user_clk_freq_sts_0;
logic   [63:0]              user_clk_freq_sts_1;

logic                       uclk;
logic                       uclk_div2;

logic   [63:0]              rst2csr_port_ctrl;
logic   [63:0]              csr2rst_port_ctrl;

t_sideband_from_pcie        pcie_p2c_sideband;

logic [63:0]                remotestp_status_100;
logic [63:0]                remotestp_status_2x;

ofs_fim_axi_mmio_if         s_remote_stp_csr_if();
ofs_fim_axi_lite_if         m_remote_stp_csr_if();

logic                       o_sr2pr_tms;
logic                       o_sr2pr_tdi;             
logic                       i_pr2sr_tdo;             
logic                       o_sr2pr_tck;
logic                       o_sr2pr_tckena; 

// ----------------------------------------------------------------------------------------------------
//  PR Slot Inst 
// ----------------------------------------------------------------------------------------------------
pr_slot #(
   .PG_NUM_PORTS     (PG_NUM_PORTS),
   .PORT_PF_VF_INFO  (PORT_PF_VF_INFO),
   .EMIF             (EMIF),
   .NUM_MEM_CH       (NUM_MEM_CH)
) pr_slot (
   .clk_2x        (clk_2x),
   .clk_1x        (clk_1x),
   .clk_100       (clk_100),
   .clk_div4      (clk_div4),
   .uclk_usr      (uclk),
   .uclk_usr_div2 (uclk_div2),

   .rst_n_2x      (rst_n_2x),
   .rst_n_1x      (rst_n_1x),
   .rst_n_100M    (rst_n_100),
   .softreset     (o_afu_softreset),
   .port_rst_n    (port_rst_n),
   
   .pr_freeze     (pr_freeze),
   
   .axi_tx_a_if   (axi_tx_a_if),
   .axi_rx_a_if   (axi_rx_a_if),
   .axi_tx_b_if   (axi_tx_b_if),
   .axi_rx_b_if   (axi_rx_b_if),
   
   .afu_mem_if    (afu_mem_if),

   `ifdef INCLUDE_HE_HSSI  
      .hssi_ss_st_tx         (hssi_ss_st_tx),
      .hssi_ss_st_rx         (hssi_ss_st_rx),
      .hssi_fc               (hssi_fc),
      `ifdef INCLUDE_PTP
         .hssi_ptp_tx_tod    (hssi_ptp_tx_tod),
         .hssi_ptp_rx_tod    (hssi_ptp_rx_tod),
         .hssi_ptp_tx_egrts  (hssi_ptp_tx_egrts),
         .hssi_ptp_rx_ingrts (hssi_ptp_rx_ingrts),
      `endif
      .i_hssi_clk_pll (i_hssi_clk_pll),
   `endif

   .sr2pr_tms    (o_sr2pr_tms),
   .sr2pr_tdi    (o_sr2pr_tdi),
   .pr2sr_tdo    (i_pr2sr_tdo),
   .sr2pr_tck    (o_sr2pr_tck),
   .sr2pr_tckena (o_sr2pr_tckena)
);

// ----------------------------------------------------------------------------------------------------
//  Port reset FSM
// ----------------------------------------------------------------------------------------------------
port_reset_fsm port_reset_fsm_inst (
   .clk_2x              (clk_2x),
   .rst_n_2x            (rst_n_2x),

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
   .i_sel_mmio_rsp     (1'b1),       // Tx FIFO Empty
   .i_read_flush_done   (1'b1),       // Pending Read = 0

   // Reset output
   .o_port_softreset_n  (o_port_softreset_n),
   .o_afu_softreset     (o_afu_softreset)
);

integer i;
always_comb begin
   pcie_p2c_sideband                   = '0;
   for ( i = 0 ; i < PG_NUM_PORTS ; i = i + 1'b1 )
      if ( !port_rst_n[i] ) begin
         pcie_p2c_sideband.flr_rcvd_vf_num   = i + 1'b1;    // [0] = VF1, [1] = VF2, ...
         pcie_p2c_sideband.flr_rcvd_vf       = 1'b1;
      end
end
   
// ----------------------------------------------------------------------------------------------------
//  PG CSR Inst 
// ----------------------------------------------------------------------------------------------------
pg_csr #(
   .END_OF_LIST     (END_OF_LIST),
   .NEXT_DFH_OFFSET (NEXT_DFH_OFFSET),
   .ADDR_WIDTH      (MM_ADDR_WIDTH),
   .DATA_WIDTH      (MM_DATA_WIDTH)
) pg_csr_inst (
   .clk                 (clk_2x),
   .rst_n               (rst_n_2x),
   
   .axi_s_if            (axi_s_if),

   .pr_ctrl_io          (pr_ctrl_io),
   .i_pr_freeze         (pr_freeze),
   
   .i_port_ctrl         (rst2csr_port_ctrl),
   .o_port_ctrl         (csr2rst_port_ctrl),

   .user_clk_freq_cmd_0 (user_clk_freq_cmd_0),
   .user_clk_freq_cmd_1 (user_clk_freq_cmd_1),
   .user_clk_freq_sts_0 (user_clk_freq_sts_0),
   .user_clk_freq_sts_1 (user_clk_freq_sts_1),
   
   .i_remotestp_status  (remotestp_status_2x),
   .m_remotestp_if      (m_remote_stp_csr_if)
);

// ----------------------------------------------------------------------------------------------------
//  Remote STP
// ----------------------------------------------------------------------------------------------------
// AXI-lite adapter
axi_lite2mmio axi_lite2mmio_inst (
   .clk     (clk_2x),
   .rst_n   (rst_n_2x),
   .lite_if (m_remote_stp_csr_if),
   .mmio_if (s_remote_stp_csr_if)
);

// Remote SignalTap IP
remote_stp_top remote_stp_top_inst (
   .clk_100              (clk_100),
   .csr_if               (s_remote_stp_csr_if),
   .o_sr2pr_tms          (o_sr2pr_tms),
   .o_sr2pr_tdi          (o_sr2pr_tdi),
   .i_pr2sr_tdo          (i_pr2sr_tdo),
   .o_sr2pr_tck          (o_sr2pr_tck),
   .o_sr2pr_tckena       (o_sr2pr_tckena),
   .remotestp_status     (remotestp_status_100),
   .remotestp_parity_err ()
);

// 100 -> 2x
fim_resync #(
   .SYNC_CHAIN_LENGTH (2),
   .WIDTH             (64),
   .INIT_VALUE        (0),
   .NO_CUT            (1)
) 
remotestp_status_sync (
   .clk   (clk_2x),
   .reset (rst_n_2x),
   .d     (remotestp_status_100),
   .q     (remotestp_status_2x)
);

// ----------------------------------------------------------------------------------------------------
//  User Clock Inst 
// ----------------------------------------------------------------------------------------------------
user_clock user_clock (
   .refclk       (refclk),
   .clk_2x       (clk_2x),
   .clk_100      (clk_100),

   .rst_n_2x     (rst_n_2x),
   .rst_n_clk100 (rst_n_100),

   .user_clk_freq_cmd_0 (user_clk_freq_cmd_0),
   .user_clk_freq_cmd_1 (user_clk_freq_cmd_1),
   .user_clk_freq_sts_0 (user_clk_freq_sts_0),
   .user_clk_freq_sts_1 (user_clk_freq_sts_1),

   .uclk      (uclk),
   .uclk_div2 (uclk_div2)
);

// ----------------------------------------------------------------------------------------------------
//  PR Controller Inst 
// ----------------------------------------------------------------------------------------------------
pr_ctrl pr_ctrl (
   // Clks and Reset
   .clk_1x              (clk_1x),
   .clk_2x              (clk_2x),
   .rst_n_1x            (rst_n_1x),
   .rst_n_2x            (rst_n_2x),
   .o_pr_fifo_parity_err(o_pr_parity_error),

   // PR CTRL Interface
   .pr_ctrl_io          (pr_ctrl_io),

   // PR to port signals
   .o_pr_reset          (pr_reset),
   .o_pr_freeze         (pr_freeze)  // will be connected to freeze logic,  1=holds
);

// Notes:
// 1 pr contrl
// 1-4 userclk, rstp

// soft_reset - inp to pr_slots and comes from port_csr/pr_csr  
// rst_1x - input to Pr_ctrl
// rst_2x - OR with flr_rst, input pr_ctrl, 
//-----------------------------------------------------------------
// Send PR FIFO Parity Error to FME for backward compatibility
//-----------------------------------------------------------------
//assign o_pr_parity_error = pr_ctrl_io.inp2prc_pg_error[0];


endmodule

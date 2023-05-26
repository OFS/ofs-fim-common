// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// Partial Reconfiguration Slot
//-----------------------------------------------------------------------------

import pcie_ss_pkg::*;
import top_cfg_pkg::*;
import ofs_fim_eth_if_pkg::*;

module  pr_slot #(
   parameter PG_NUM_PORTS      = 1,
   // PF/VF to which each port is mapped
   parameter pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t[PG_NUM_PORTS-1:0] PORT_PF_VF_INFO =
                {PG_NUM_PORTS{pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t'(0)}},

   parameter EMIF              = 0,
   parameter NUM_MEM_CH        = 2,
   parameter TDATA_WIDTH       = ofs_pcie_ss_cfg_pkg::TDATA_WIDTH,
   parameter TUSER_WIDTH       = ofs_pcie_ss_cfg_pkg::TUSER_WIDTH
)(
   input                       clk_2x,
   input                       clk_1x,
   input                       clk_div4,
   input                       clk_100,
   input                       uclk_usr,
   input                       uclk_usr_div2,

   input                       rst_n_2x,
   input                       rst_n_1x,
   input                       rst_n_100M,
   input                       softreset,
   input  logic                port_rst_n  [PG_NUM_PORTS-1:0],

   input                       pr_freeze,

   pcie_ss_axis_if.source      axi_tx_a_if [PG_NUM_PORTS-1:0],
   pcie_ss_axis_if.sink        axi_rx_a_if [PG_NUM_PORTS-1:0],
   pcie_ss_axis_if.source      axi_tx_b_if [PG_NUM_PORTS-1:0],
   pcie_ss_axis_if.sink        axi_rx_b_if [PG_NUM_PORTS-1:0],

   ofs_fim_emif_avmm_if.user   afu_mem_if[NUM_MEM_CH],

   `ifdef INCLUDE_HE_HSSI  
      ofs_fim_hssi_ss_tx_axis_if.client       hssi_ss_st_tx [MAX_NUM_ETH_CHANNELS-1:0],
      ofs_fim_hssi_ss_rx_axis_if.client       hssi_ss_st_rx [MAX_NUM_ETH_CHANNELS-1:0],
      ofs_fim_hssi_fc_if.client               hssi_fc [MAX_NUM_ETH_CHANNELS-1:0],
      `ifdef INCLUDE_PTP
         ofs_fim_hssi_ptp_tx_tod_if.client     hssi_ptp_tx_tod [MAX_NUM_ETH_CHANNELS-1:0],
         ofs_fim_hssi_ptp_rx_tod_if.client     hssi_ptp_rx_tod [MAX_NUM_ETH_CHANNELS-1:0],
         ofs_fim_hssi_ptp_tx_egrts_if.client   hssi_ptp_tx_egrts [MAX_NUM_ETH_CHANNELS-1:0],
         ofs_fim_hssi_ptp_rx_ingrts_if.client  hssi_ptp_rx_ingrts [MAX_NUM_ETH_CHANNELS-1:0],
         input logic                           i_ehip_clk_806,
         input logic                           i_ehip_clk_403,
         input logic                           i_ehip_pll_locked,
      `endif
      input logic [MAX_NUM_ETH_CHANNELS-1:0] i_hssi_clk_pll,
   `endif

   // JTAG interface for PR region debug
   input  logic  sr2pr_tms,
   input  logic  sr2pr_tdi,             
   output logic  pr2sr_tdo,             
   input  logic  sr2pr_tck,
   input  logic  sr2pr_tckena
);

logic                        port_rst_n_t0[PG_NUM_PORTS-1:0];
logic                        port_rst_n_t1[PG_NUM_PORTS-1:0];
logic                        rst_n_100M_d;
always_ff @ (posedge clk_100) begin
       rst_n_100M_d        <= rst_n_100M; 
end

// ----------------------------------------------------------------------------------------------------
//  PR Freeze Logic 
//  - Implemented only in Tx direction. 
// ----------------------------------------------------------------------------------------------------


// ----------------------------------------------------------------------------------------------------
// 1. PR Freeze: PG Ports to PFVF-Mux
// ----------------------------------------------------------------------------------------------------
logic               pr_freeze_fnmx_q0, pr_freeze_fnmx_q1;
pcie_ss_axis_if     axi_tx_a_if_t0          [PG_NUM_PORTS-1:0]();
pcie_ss_axis_if     axi_tx_a_if_t1          [PG_NUM_PORTS-1:0]();
pcie_ss_axis_if     axi_tx_b_if_t0          [PG_NUM_PORTS-1:0]();
pcie_ss_axis_if     axi_tx_b_if_t1          [PG_NUM_PORTS-1:0]();

pcie_ss_axis_if     axi_rx_a_if_t0          [PG_NUM_PORTS-1:0]();
pcie_ss_axis_if     axi_rx_a_if_t1          [PG_NUM_PORTS-1:0]();
pcie_ss_axis_if     axi_rx_b_if_t0          [PG_NUM_PORTS-1:0]();
pcie_ss_axis_if     axi_rx_b_if_t1          [PG_NUM_PORTS-1:0]();

// Flop freeze signal
always_ff @ (posedge clk_2x) begin
   pr_freeze_fnmx_q1   <= pr_freeze_fnmx_q0;
   pr_freeze_fnmx_q0   <= pr_freeze;
end

generate
for (genvar j=0; j<PG_NUM_PORTS; j++) begin : p

   // Reset register
   always_ff @ (posedge clk_2x) begin
      port_rst_n_t0[j]        <= rst_n_2x && port_rst_n[j];
      port_rst_n_t1[j]        <= port_rst_n_t0[j];
   end

   // Register tx signals for freeze logic
   axis_pipeline #(
      .TDATA_WIDTH(TDATA_WIDTH),
      .TUSER_WIDTH(TUSER_WIDTH),
      .PL_DEPTH(1) )
   pr_frz_fn2mx_a_port (
      .clk            ( clk_2x                            ),
      .rst_n          ( !softreset && rst_n_2x && port_rst_n[j] ),
      .axis_s         ( axi_tx_a_if_t1[j]                 ),
      .axis_m         ( axi_tx_a_if_t0[j]                 )
   );

   // freeze ready & valid
   always_comb begin
      axi_tx_a_if[j].tvalid       = axi_tx_a_if_t0[j].tvalid;
      axi_tx_a_if[j].tlast        = axi_tx_a_if_t0[j].tlast;
      axi_tx_a_if[j].tuser_vendor = axi_tx_a_if_t0[j].tuser_vendor;
      axi_tx_a_if[j].tdata        = axi_tx_a_if_t0[j].tdata;
      axi_tx_a_if[j].tkeep        = axi_tx_a_if_t0[j].tkeep;
      axi_tx_a_if_t0[j].tready    = axi_tx_a_if[j].tready;

      if (pr_freeze_fnmx_q1) begin
         axi_tx_a_if[j].tvalid    = 0;
         axi_tx_a_if_t0[j].tready = 0;
      end
   end

   // Register tx B port signals for freeze logic
   axis_pipeline #(
      .TDATA_WIDTH(TDATA_WIDTH),
      .TUSER_WIDTH(TUSER_WIDTH),
      .PL_DEPTH(1) )
   pr_frz_fn2mx_b_port (
      .clk            ( clk_2x                            ),
      .rst_n          ( !softreset && rst_n_2x && port_rst_n[j] ),
      .axis_s         ( axi_tx_b_if_t1[j]                 ),
      .axis_m         ( axi_tx_b_if_t0[j]                 )
   );

   // freeze ready & valid
   always_comb begin
      axi_tx_b_if[j].tvalid       = axi_tx_b_if_t0[j].tvalid;
      axi_tx_b_if[j].tlast        = axi_tx_b_if_t0[j].tlast;
      axi_tx_b_if[j].tuser_vendor = axi_tx_b_if_t0[j].tuser_vendor;
      axi_tx_b_if[j].tdata        = axi_tx_b_if_t0[j].tdata;
      axi_tx_b_if[j].tkeep        = axi_tx_b_if_t0[j].tkeep;
      axi_tx_b_if_t0[j].tready    = axi_tx_b_if[j].tready;

      if (pr_freeze_fnmx_q1) begin
         axi_tx_b_if[j].tvalid    = 0;
         axi_tx_b_if_t0[j].tready = 0;
      end
   end

   // Register rx signals for freeze logic
   axis_pipeline #(
      .TDATA_WIDTH (TDATA_WIDTH),
      .TUSER_WIDTH (TUSER_WIDTH),
      .PL_DEPTH    (1)
   ) pr_frz_mx2fn_a_port (
      .clk    (clk_2x),
      .rst_n  (!softreset && rst_n_2x && port_rst_n[j]),
      .axis_s (axi_rx_a_if_t0[j]),
      .axis_m (axi_rx_a_if_t1[j])
   );

   // freeze ready & valid
   always_comb begin
      axi_rx_a_if_t0[j].tvalid       = axi_rx_a_if[j].tvalid;
      axi_rx_a_if_t0[j].tlast        = axi_rx_a_if[j].tlast;
      axi_rx_a_if_t0[j].tuser_vendor = axi_rx_a_if[j].tuser_vendor;
      axi_rx_a_if_t0[j].tdata        = axi_rx_a_if[j].tdata;
      axi_rx_a_if_t0[j].tkeep        = axi_rx_a_if[j].tkeep;
      axi_rx_a_if[j].tready          = axi_rx_a_if_t0[j].tready;

      if (pr_freeze_fnmx_q1) begin
         axi_rx_a_if_t0[j].tvalid  = 0;
         axi_rx_a_if[j].tready     = 0;
      end
   end

   // Register rx B signals for freeze logic
   axis_pipeline #(
      .TDATA_WIDTH (TDATA_WIDTH),
      .TUSER_WIDTH (TUSER_WIDTH),
      .PL_DEPTH    (1)
   ) pr_frz_mx2fn_b_port (
      .clk    (clk_2x),
      .rst_n  (!softreset && rst_n_2x && port_rst_n[j]),
      .axis_s (axi_rx_b_if_t0[j]),
      .axis_m (axi_rx_b_if_t1[j])
   );

   // freeze ready & valid
   always_comb begin
      axi_rx_b_if_t0[j].tvalid       = axi_rx_b_if[j].tvalid;
      axi_rx_b_if_t0[j].tlast        = axi_rx_b_if[j].tlast;
      axi_rx_b_if_t0[j].tuser_vendor = axi_rx_b_if[j].tuser_vendor;
      axi_rx_b_if_t0[j].tdata        = axi_rx_b_if[j].tdata;
      axi_rx_b_if_t0[j].tkeep        = axi_rx_b_if[j].tkeep;
      axi_rx_b_if[j].tready          = axi_rx_b_if_t0[j].tready;

      if (pr_freeze_fnmx_q1) begin
         axi_rx_b_if_t0[j].tvalid  = 0;
         axi_rx_b_if[j].tready     = 0;
      end
   end
end
endgenerate


// ----------------------------------------------------------------------------------------------------
// 2. PR Freeze: AFU-MEM_IF to MEM SS
// ----------------------------------------------------------------------------------------------------
logic                   pr_freeze_emif[NUM_MEM_CH];
logic                   softreset_emif[NUM_MEM_CH];
logic                   afu_mem_if_read_t0[NUM_MEM_CH];
logic                   afu_mem_if_write_t0[NUM_MEM_CH];
logic                   afu_mem_if_waitrequest_t0[NUM_MEM_CH];
ofs_fim_emif_avmm_if    afu_main_emif[NUM_MEM_CH]();

for (genvar j=0; j<NUM_MEM_CH; j++) begin : emif
   fim_resync #(
      .SYNC_CHAIN_LENGTH (2),
      .WIDTH             (1),
      .INIT_VALUE        (0),
      .NO_CUT            (1)
   ) ddr4_pr_freeze_sync (
      .clk   (afu_mem_if[j].clk),
      .reset (1'b0),
      .d     (pr_freeze),
      .q     (pr_freeze_emif[j])
   );

   fim_resync #(
      .SYNC_CHAIN_LENGTH(2),
      .WIDTH(1),
      .INIT_VALUE(1),
      .NO_CUT(1)
   ) ddr4_softreset_sync (
      .clk(afu_mem_if[j].clk),
      .reset(1'b0),
      .d(softreset),
      .q(softreset_emif[j])
   );

   // Register tx signals for freeze logic
   avmm_if_reg #(
      .TX_WIDTH($bits({afu_mem_if[j].read,
                        afu_mem_if[j].write,
                        afu_mem_if[j].address,
                        afu_mem_if[j].writedata,
                        afu_mem_if[j].byteenable,
                        afu_mem_if[j].burstcount})),
      .RX_WIDTH($bits({afu_mem_if[j].readdata,
                        afu_mem_if[j].readdatavalid}))
   ) pr_frz_afu_avmm_if (
      .clk               (afu_mem_if[j].clk),
      .i_reset_n         (afu_mem_if[j].rst_n && ~softreset_emif[j]),
      .o_reset_n         (afu_main_emif[j].rst_n),

      .o_m0_waitrequest  (afu_main_emif[j].waitrequest),

      .o_m0_pck_Rx       ({afu_main_emif[j].readdata,
                           afu_main_emif[j].readdatavalid}),

      .i_m0_pck_Tx       ({afu_main_emif[j].read,
                           afu_main_emif[j].write,
                           afu_main_emif[j].address,
                           afu_main_emif[j].writedata,
                           afu_main_emif[j].byteenable,
                           afu_main_emif[j].burstcount}),

      .i_s0_waitrequest  (afu_mem_if_waitrequest_t0[j] ),

      .i_s0_pck_Rx       ({afu_mem_if[j].readdata,
                           afu_mem_if[j].readdatavalid}),

      .o_s0_pck_Tx       ({afu_mem_if_read_t0[j],
                           afu_mem_if_write_t0[j],
                           afu_mem_if[j].address,
                           afu_mem_if[j].writedata,
                           afu_mem_if[j].byteenable,
                           afu_mem_if[j].burstcount})      
   );

   assign afu_main_emif[j].clk   = afu_mem_if[j].clk;

   // freeze read & write valids
   always_comb begin
      afu_mem_if[j].read           = afu_mem_if_read_t0[j];
      afu_mem_if[j].write          = afu_mem_if_write_t0[j];
      afu_mem_if_waitrequest_t0[j] = afu_mem_if[j].waitrequest;

      if (pr_freeze_emif[j]) begin
         afu_mem_if[j].read           = 0;
         afu_mem_if[j].write          = 0;
         afu_mem_if_waitrequest_t0[j] = 1'b1;
      end
   end
end //for


`ifdef INCLUDE_HE_HSSI  
// ----------------------------------------------------------------------------------------------------
// 3. PR Freeze: HE-HSSI to HSSI-SS Ports (Tx Direction)
// ----------------------------------------------------------------------------------------------------
   ofs_fim_hssi_ss_tx_axis_if       hssi_afu_st_tx  [MAX_NUM_ETH_CHANNELS-1:0] ();
   ofs_fim_hssi_ss_rx_axis_if       hssi_afu_st_rx [MAX_NUM_ETH_CHANNELS-1:0] ();
   ofs_fim_hssi_fc_if               hssi_afu_fc [MAX_NUM_ETH_CHANNELS-1:0] ();
   logic [MAX_NUM_ETH_CHANNELS-1:0] softreset_hssi;
   logic [MAX_NUM_ETH_CHANNELS-1:0] pr_freeze_hssi;

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
         .TUSER_WIDTH ($bits(hssi_ss_st_tx[j].tx.tuser))
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
   .clk             (clk_2x),
   .clk_div2        (clk_1x),
   .clk_div4        (clk_div4),
   .uclk_usr        (uclk_usr),
   .uclk_usr_div2   (uclk_usr_div2),
   .rst_n_100M      (rst_n_100M_d),
   .rst_n           (!softreset),
   .port_rst_n      (port_rst_n_t1),

   .afu_axi_tx_a_if (axi_tx_a_if_t1),
   .afu_axi_rx_a_if (axi_rx_a_if_t1),
   .afu_axi_tx_b_if (axi_tx_b_if_t1),
   .afu_axi_rx_b_if (axi_rx_b_if_t1),

   .ext_mem_if      (afu_main_emif),

   `ifdef INCLUDE_HE_HSSI  
      .hssi_ss_st_tx         (hssi_afu_st_tx),
      .hssi_ss_st_rx         (hssi_afu_st_rx),
      .hssi_fc               (hssi_afu_fc),
      `ifdef INCLUDE_PTP
         .hssi_ptp_tx_tod    (hssi_ptp_tx_tod),
         .hssi_ptp_rx_tod    (hssi_ptp_rx_tod),
         .hssi_ptp_tx_egrts  (hssi_ptp_tx_egrts),
         .hssi_ptp_rx_ingrts (hssi_ptp_rx_ingrts),
      `endif
      .i_hssi_clk_pll        (i_hssi_clk_pll),
  `endif

   .sr2pr_tms                (sr2pr_tms),
   .sr2pr_tdi                (sr2pr_tdi),
   .pr2sr_tdo                (pr2sr_tdo),
   .sr2pr_tck                (sr2pr_tck),
   .sr2pr_tckena             (sr2pr_tckena)
);

endmodule

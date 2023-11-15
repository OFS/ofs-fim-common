// Copyright (C) 2020 Intel Corporation.
// SPDX-License-Identifier: MIT

//
// Description
//-----------------------------------------------------------------------------
//
// Top level module of HSSI subsystem.
// Port and signals use continuous index irrespective IP configuration.
// For example is HSSI SS IP enables port-0 and port-4, then all port/signal in
// shell have index-0 mapped to port 0 and index-1 mapped to port 4
//-----------------------------------------------------------------------------

`include "fpga_defines.vh"
`include "ofs_fim_eth_plat_defines.svh"
`include "ofs_ip_cfg_db.vh"
import ofs_fim_eth_if_pkg::*;

module hssi_wrapper #(
   parameter bit [23:0] NEXT_DFH_OFFSET = 24'h1000,
   parameter bit        END_OF_LIST     = 1'b0
) (
   // CSR interfaces
   input  logic                               clk_csr,
   input  logic                               rst_n_csr,
   ofs_fim_axi_lite_if.slave                  csr_lite_if,
   // Streaming data interfaces
   ofs_fim_hssi_ss_tx_axis_if.mac             hssi_ss_st_tx [MAX_NUM_ETH_CHANNELS-1:0],
   ofs_fim_hssi_ss_rx_axis_if.mac             hssi_ss_st_rx [MAX_NUM_ETH_CHANNELS-1:0],
   // Streaming PTP interfaces
   `ifdef INCLUDE_PTP
      input  logic                               sys_pll_locked,
      ofs_fim_hssi_ptp_tx_tod_if.mac             hssi_ptp_tx_tod [MAX_NUM_ETH_CHANNELS-1:0],
      ofs_fim_hssi_ptp_rx_tod_if.mac             hssi_ptp_rx_tod [MAX_NUM_ETH_CHANNELS-1:0],
      ofs_fim_hssi_ptp_tx_egrts_if.mac           hssi_ptp_tx_egrts [MAX_NUM_ETH_CHANNELS-1:0],
      ofs_fim_hssi_ptp_rx_ingrts_if.mac          hssi_ptp_rx_ingrts [MAX_NUM_ETH_CHANNELS-1:0],
      output logic                               o_ehip_clk_806,
      output logic                               o_ehip_clk_403,
      output logic                               o_ehip_pll_locked,
   `endif
   // Flow control interfaces
   ofs_fim_hssi_fc_if.mac                     hssi_fc [MAX_NUM_ETH_CHANNELS-1:0],
   // Serial Pins
   ofs_fim_hssi_serial_if.hssi                hssi_if [NUM_ETH_LANES-1:0],
   // Clock interfaces
   input  logic [2:0]                         i_hssi_clk_ref,
   output logic [2:0]                         o_hssi_rec_clk,
   output logic [MAX_NUM_ETH_CHANNELS-1:0]    o_hssi_clk_pll,
   // Speed and activity LEDS
   output logic [1:0]                         o_qsfp_speed_green,       // Link up in Nx25G or 2x56G or 1x100G speed
   output logic [1:0]                         o_qsfp_speed_yellow,      // Link up in Nx10G speed
   output logic [1:0]                         o_qsfp_activity_green,    // Link up and activity seen
   output logic [1:0]                         o_qsfp_activity_red       // LOS, TX Fault etc
);

localparam NUM_PORT    = NUM_ETH_CHANNELS;                        // Number of Ethernet ports
localparam UNUSED_PORT = MAX_NUM_ETH_CHANNELS - NUM_ETH_CHANNELS; // Number of Ethernet ports not unused

logic [NUM_ETH_CHANNELS-1:0][NUM_LANES-1:0] serial_tx_p,serial_tx_n;
logic [NUM_ETH_CHANNELS-1:0][NUM_LANES-1:0] serial_rx_p,serial_rx_n;

logic [MAX_NUM_ETH_CHANNELS-1:0]        axis_tx_areset,csr_axis_tx_areset;
logic [MAX_NUM_ETH_CHANNELS-1:0]        axis_rx_areset,csr_axis_rx_areset;
logic [MAX_NUM_ETH_CHANNELS-1:0]        tx_rst;
logic [MAX_NUM_ETH_CHANNELS-1:0]        rx_rst;
logic [MAX_NUM_ETH_CHANNELS-1:0]        tx_rst_ack_n,sync_tx_rst_ack_n;
logic [MAX_NUM_ETH_CHANNELS-1:0]        rx_rst_ack_n,sync_rx_rst_ack_n;
logic                                   cold_rst;
logic                                   cold_rst_ack_n,sync_cold_rst_ack_n;
logic [MAX_NUM_ETH_CHANNELS-1:0]        tx_pll_locked,sync_tx_pll_locked;
logic [MAX_NUM_ETH_CHANNELS-1:0]        tx_lanes_stable,sync_tx_lanes_stable;
logic [MAX_NUM_ETH_CHANNELS-1:0]        rx_pcs_ready,sync_rx_pcs_ready;
logic [MAX_NUM_ETH_CHANNELS-1:0]        handshaked_tx_rst;
logic [MAX_NUM_ETH_CHANNELS-1:0]        handshaked_rx_rst;
logic                                   handshaked_cold_rst;
logic [MAX_NUM_ETH_CHANNELS-1:0][2:0]   led_speed, led_status;

logic [NUM_ETH_CHANNELS-1:0]            clk_pll;
logic                                   ehip0_ptp_clk_pll,ehip1_ptp_clk_pll;
logic                                   ehip0_ptp_clk_tx_div,ehip1_ptp_clk_tx_div;
logic                                   ehip0_ptp_clk_rec_div,ehip1_ptp_clk_rec_div;
logic                                   ehip0_ptp_clk_rec_div64,ehip1_ptp_clk_rec_div64;
logic                                   ehip2_ptp_clk_pll,ehip3_ptp_clk_pll;
logic                                   ehip2_ptp_clk_tx_div,ehip3_ptp_clk_tx_div;
logic                                   ehip2_ptp_clk_rec_div,ehip3_ptp_clk_rec_div;
logic                                   ehip2_ptp_clk_rec_div64,ehip3_ptp_clk_rec_div64;

logic  [NUM_ETH_CHANNELS-1:0]           tx_ptp_ready,sync_tx_ptp_ready;
logic  [NUM_ETH_CHANNELS-1:0]           rx_ptp_ready,sync_rx_ptp_ready;
logic  [MAX_NUM_ETH_CHANNELS-1:0]       sync_tx_ptp_ready_csr;
logic  [MAX_NUM_ETH_CHANNELS-1:0]       sync_rx_ptp_ready_csr;

logic                                   clk_ptp_sample;
logic                                   p0_clk_ptp_sample;
logic                                   p4_clk_ptp_sample;
logic                                   p8_clk_ptp_sample;
logic                                   p10_clk_ptp_sample;
logic                                   p12_clk_ptp_sample;

logic  [NUM_ETH_CHANNELS-1:0]           st_tx_clk;
logic  [NUM_ETH_CHANNELS-1:0]           st_rx_clk;
logic  [NUM_ETH_CHANNELS-1:0]           clk_tx_div,clk_rec_div64,clk_rec_div;
logic  [NUM_ETH_CHANNELS-1:0]           clk_tx_tod=clk_tx_div;
logic  [NUM_ETH_CHANNELS-1:0]           clk_rx_tod=clk_rec_div;

ofs_fim_axi_lite_if #(.AWADDR_WIDTH(11), .WDATA_WIDTH(32), .ARADDR_WIDTH(11), .RDATA_WIDTH(32)) ss_ip_csr_if();
ofs_fim_axi_lite_if #(.AWADDR_WIDTH(11), .ARADDR_WIDTH(11)) wrapper_csr_if();

// Port enums have been moved to $OFS_ROOTDIR/ipss/hssi/inc/ofs_fim_eth_plat_defines.svh
// so that they can be accessed by UVM. The macro is INST_FULL_UVM_PORT_INDEX and is 
// represented by the following expression:
//     enum { 
//        `ENUM_PORT_INDEX   
//         PORT_MAX
//     } port_index;
// 
// This allows interfaces, ports, parameters, etc, to be indexed with PORT_<n>.
// For example the ETH_PORT_EN_ARRAY localparam will allow us to index the 
// port_index enum, where:
// 8x25/10g:
//    ETH_PORT_EN_ARRAY[PORT_0] = 0
//    ETH_PORT_EN_ARRAY[PORT_1] = 1
//    ETH_PORT_EN_ARRAY[PORT_2] = 2
//    ETH_PORT_EN_ARRAY[PORT_3] = 3
//    ETH_PORT_EN_ARRAY[PORT_4] = 4
//    ETH_PORT_EN_ARRAY[PORT_5] = 5
//    ETH_PORT_EN_ARRAY[PORT_6] = 6
//    ETH_PORT_EN_ARRAY[PORT_7] = 7
// 2x100g: 
//    ETH_PORT_EN_ARRAY[PORT_0] = 0
//    ETH_PORT_EN_ARRAY[PORT_4] = 1
// 2x200g: 
//    ETH_PORT_EN_ARRAY[PORT_8]  = 0
//    ETH_PORT_EN_ARRAY[PORT_12] = 1
`INST_FULL_ENUM_PORT_INDEX


assign o_hssi_clk_pll = st_tx_clk;
assign st_tx_clk = clk_pll;
assign st_rx_clk = clk_pll;


for (genvar nump=0; nump < NUM_ETH_CHANNELS; nump++) begin : GenClkRst
   
   fim_resync #(
    .SYNC_CHAIN_LENGTH  (2),
    .WIDTH              (1),
    .INIT_VALUE         (1),
    .NO_CUT             (0)
   ) st_tx_rst_sync(
    .clk                (st_tx_clk[nump]),
    .reset              (~rst_n_csr || csr_axis_tx_areset[nump]),
    .d                  (1'b0),
    .q                  (axis_tx_areset[nump])
);

 fim_resync #(
    .SYNC_CHAIN_LENGTH  (2),
    .WIDTH              (1),
    .INIT_VALUE         (1),
    .NO_CUT             (0)
   ) st_rx_rst_sync(
    .clk                (st_tx_clk[nump]),
    .reset              (~rst_n_csr || csr_axis_rx_areset[nump]),
    .d                  (1'b0),
    .q                  (axis_rx_areset[nump])
);

   assign hssi_ss_st_tx[nump].clk   = st_tx_clk[nump];
   assign hssi_ss_st_tx[nump].rst_n = ~axis_tx_areset[nump];
   
   assign hssi_ss_st_rx[nump].clk   = st_rx_clk[nump];
   assign hssi_ss_st_rx[nump].rst_n = ~axis_rx_areset[nump];
   
end

// AXI4Lite interconnect to split CSR space between HSSI SS IP and shell CSR
   hssi_ss_csr_ic hssi_ss_csr_ic (
      .clk_clk                     (clk_csr),                     //   input,   width = 1,                 clk.clk
      .hssi_ss_csr_mst_awaddr      (csr_lite_if.awaddr[11:0]),    //   input,  width = 12,     hssi_ss_csr_mst.awaddr
      .hssi_ss_csr_mst_awprot      (csr_lite_if.awprot),          //   input,   width = 3,                    .awprot
      .hssi_ss_csr_mst_awvalid     (csr_lite_if.awvalid),         //   input,   width = 1,                    .awvalid
      .hssi_ss_csr_mst_awready     (csr_lite_if.awready),         //  output,   width = 1,                    .awready
      .hssi_ss_csr_mst_wdata       (csr_lite_if.wdata),           //   input,  width = 64,                    .wdata
      .hssi_ss_csr_mst_wstrb       (csr_lite_if.wstrb),           //   input,   width = 8,                    .wstrb
      .hssi_ss_csr_mst_wvalid      (csr_lite_if.wvalid),          //   input,   width = 1,                    .wvalid
      .hssi_ss_csr_mst_wready      (csr_lite_if.wready),          //  output,   width = 1,                    .wready
      .hssi_ss_csr_mst_bresp       (csr_lite_if.bresp),           //  output,   width = 2,                    .bresp
      .hssi_ss_csr_mst_bvalid      (csr_lite_if.bvalid),          //  output,   width = 1,                    .bvalid
      .hssi_ss_csr_mst_bready      (csr_lite_if.bready),          //   input,   width = 1,                    .bready
      .hssi_ss_csr_mst_araddr      (csr_lite_if.araddr[11:0]),    //   input,  width = 12,                    .araddr
      .hssi_ss_csr_mst_arprot      (csr_lite_if.arprot),          //   input,   width = 3,                    .arprot
      .hssi_ss_csr_mst_arvalid     (csr_lite_if.arvalid),         //   input,   width = 1,                    .arvalid
      .hssi_ss_csr_mst_arready     (csr_lite_if.arready),         //  output,   width = 1,                    .arready
      .hssi_ss_csr_mst_rdata       (csr_lite_if.rdata),           //  output,  width = 64,                    .rdata
      .hssi_ss_csr_mst_rresp       (csr_lite_if.rresp),           //  output,   width = 2,                    .rresp
      .hssi_ss_csr_mst_rvalid      (csr_lite_if.rvalid),          //  output,   width = 1,                    .rvalid
      .hssi_ss_csr_mst_rready      (csr_lite_if.rready),          //   input,   width = 1,                    .rready
      .hssi_ss_ip_slv_awaddr       (ss_ip_csr_if.awaddr[10:0]),   //  output,  width = 11,      hssi_ss_ip_slv.awaddr
      .hssi_ss_ip_slv_awprot       (ss_ip_csr_if.awprot),         //  output,   width = 3,                    .awprot
      .hssi_ss_ip_slv_awvalid      (ss_ip_csr_if.awvalid),        //  output,   width = 1,                    .awvalid
      .hssi_ss_ip_slv_awready      (ss_ip_csr_if.awready),        //   input,   width = 1,                    .awready
      .hssi_ss_ip_slv_wdata        (ss_ip_csr_if.wdata),          //  output,  width = 64,                    .wdata
      .hssi_ss_ip_slv_wstrb        (ss_ip_csr_if.wstrb),          //  output,   width = 8,                    .wstrb
      .hssi_ss_ip_slv_wvalid       (ss_ip_csr_if.wvalid),         //  output,   width = 1,                    .wvalid
      .hssi_ss_ip_slv_wready       (ss_ip_csr_if.wready),         //   input,   width = 1,                    .wready
      .hssi_ss_ip_slv_bresp        (ss_ip_csr_if.bresp),          //   input,   width = 2,                    .bresp
      .hssi_ss_ip_slv_bvalid       (ss_ip_csr_if.bvalid),         //   input,   width = 1,                    .bvalid
      .hssi_ss_ip_slv_bready       (ss_ip_csr_if.bready),         //  output,   width = 1,                    .bready
      .hssi_ss_ip_slv_araddr       (ss_ip_csr_if.araddr[10:0]),   //  output,  width = 11,                    .araddr
      .hssi_ss_ip_slv_arprot       (ss_ip_csr_if.arprot),         //  output,   width = 3,                    .arprot
      .hssi_ss_ip_slv_arvalid      (ss_ip_csr_if.arvalid),        //  output,   width = 1,                    .arvalid
      .hssi_ss_ip_slv_arready      (ss_ip_csr_if.arready),        //   input,   width = 1,                    .arready
      .hssi_ss_ip_slv_rdata        (ss_ip_csr_if.rdata),          //   input,  width = 64,                    .rdata
      .hssi_ss_ip_slv_rresp        (ss_ip_csr_if.rresp),          //   input,   width = 2,                    .rresp
      .hssi_ss_ip_slv_rvalid       (ss_ip_csr_if.rvalid),         //   input,   width = 1,                    .rvalid
      .hssi_ss_ip_slv_rready       (ss_ip_csr_if.rready),         //  output,   width = 1,                    .rready
      .hssi_ss_wrapper_slv_awaddr  (wrapper_csr_if.awaddr[10:0]), //  output,  width = 11, hssi_ss_wrapper_slv.awaddr
      .hssi_ss_wrapper_slv_awprot  (wrapper_csr_if.awprot),       //  output,   width = 3,                    .awprot
      .hssi_ss_wrapper_slv_awvalid (wrapper_csr_if.awvalid),      //  output,   width = 1,                    .awvalid
      .hssi_ss_wrapper_slv_awready (wrapper_csr_if.awready),      //   input,   width = 1,                    .awready
      .hssi_ss_wrapper_slv_wdata   (wrapper_csr_if.wdata),        //  output,  width = 64,                    .wdata
      .hssi_ss_wrapper_slv_wstrb   (wrapper_csr_if.wstrb),        //  output,   width = 8,                    .wstrb
      .hssi_ss_wrapper_slv_wvalid  (wrapper_csr_if.wvalid),       //  output,   width = 1,                    .wvalid
      .hssi_ss_wrapper_slv_wready  (wrapper_csr_if.wready),       //   input,   width = 1,                    .wready
      .hssi_ss_wrapper_slv_bresp   (wrapper_csr_if.bresp),        //   input,   width = 2,                    .bresp
      .hssi_ss_wrapper_slv_bvalid  (wrapper_csr_if.bvalid),       //   input,   width = 1,                    .bvalid
      .hssi_ss_wrapper_slv_bready  (wrapper_csr_if.bready),       //  output,   width = 1,                    .bready
      .hssi_ss_wrapper_slv_araddr  (wrapper_csr_if.araddr[10:0]), //  output,  width = 11,                    .araddr
      .hssi_ss_wrapper_slv_arprot  (wrapper_csr_if.arprot),       //  output,   width = 3,                    .arprot
      .hssi_ss_wrapper_slv_arvalid (wrapper_csr_if.arvalid),      //  output,   width = 1,                    .arvalid
      .hssi_ss_wrapper_slv_arready (wrapper_csr_if.arready),      //   input,   width = 1,                    .arready
      .hssi_ss_wrapper_slv_rdata   (wrapper_csr_if.rdata),        //   input,  width = 64,                    .rdata
      .hssi_ss_wrapper_slv_rresp   (wrapper_csr_if.rresp),        //   input,   width = 2,                    .rresp
      .hssi_ss_wrapper_slv_rvalid  (wrapper_csr_if.rvalid),       //   input,   width = 1,                    .rvalid
      .hssi_ss_wrapper_slv_rready  (wrapper_csr_if.rready),       //  output,   width = 1,                    .rready
      .reset_reset_n               (rst_n_csr)                    //   input,   width = 1,               reset.reset_n
   );

//----------------------------
// HSSI Wrapper CSR instantiation
//----------------------------

hssi_wrapper_csr hssi_wrapper_csr (
   .clk                 (clk_csr),
   .rst_n               (rst_n_csr),
   .csr_lite_if         (wrapper_csr_if),
   .o_axis_tx_areset    (csr_axis_tx_areset),
   .o_axis_rx_areset    (csr_axis_rx_areset),
   .o_tx_rst            (tx_rst),
   .o_rx_rst            (rx_rst),
   .i_tx_rst_ack        (~sync_tx_rst_ack_n),
   .i_rx_rst_ack        (~sync_rx_rst_ack_n),
   .o_cold_rst          (cold_rst),
   .i_cold_rst_ack      (~sync_cold_rst_ack_n),
   .i_tx_pll_locked     (sync_tx_pll_locked),
   .i_tx_lanes_stable   (sync_tx_lanes_stable),
   .i_rx_pcs_ready      (sync_rx_pcs_ready),
   .i_tx_ptp_ready      (sync_tx_ptp_ready_csr), 
   .i_rx_ptp_ready      (sync_rx_ptp_ready_csr)
);

//------------------------------------------------------------------------------------
// Assign zero to unused port status signal to avoid 'x' propagation in sim 
//------------------------------------------------------------------------------------
generate
   if (UNUSED_PORT != 0) begin : GenUnusedPort
      always_comb begin
         tx_pll_locked[MAX_NUM_ETH_CHANNELS-1:NUM_PORT]   = {UNUSED_PORT{1'b0}};
         tx_lanes_stable[MAX_NUM_ETH_CHANNELS-1:NUM_PORT] = {UNUSED_PORT{1'b0}};
         rx_pcs_ready[MAX_NUM_ETH_CHANNELS-1:NUM_PORT]    = {UNUSED_PORT{1'b0}};
         tx_rst_ack_n[MAX_NUM_ETH_CHANNELS-1:NUM_PORT]    = {UNUSED_PORT{1'b0}};
         rx_rst_ack_n[MAX_NUM_ETH_CHANNELS-1:NUM_PORT]    = {UNUSED_PORT{1'b0}};
         sync_tx_ptp_ready_csr                            = {{UNUSED_PORT{1'b0}},sync_tx_ptp_ready};
         sync_rx_ptp_ready_csr                            = {{UNUSED_PORT{1'b0}},sync_rx_ptp_ready};
      end
   end
endgenerate

//----------------------------
// Reset-Ack handshake 
//----------------------------
generate

   for (genvar nump=0; nump<NUM_PORT; nump++) begin : GenRst
      rst_ack tx_rst_ack(
         .i_clk(clk_csr),
         .i_rst(~rst_n_csr | tx_rst[nump]),
      `ifdef INCLUDE_FTILE
         .i_ack(~sync_tx_rst_ack_n[nump]),
      `else
         .i_ack(sync_tx_pll_locked[nump] & ~sync_tx_rst_ack_n[nump]),
      `endif
         .o_rst(handshaked_tx_rst[nump])
      );

      rst_ack rx_rst_ack(
         .i_clk(clk_csr),
         .i_rst(~rst_n_csr | rx_rst[nump]),
      `ifdef INCLUDE_FTILE
         .i_ack(~sync_rx_rst_ack_n[nump]),
      `else
         .i_ack(sync_tx_pll_locked[nump] & ~sync_rx_rst_ack_n[nump]),
      `endif
         .o_rst(handshaked_rx_rst[nump])
      );
   end
endgenerate

rst_ack cold_rst_ack(
   .i_clk(clk_csr),
   .i_rst(~rst_n_csr | cold_rst),
   .i_ack(~sync_cold_rst_ack_n),
   .o_rst(handshaked_cold_rst)
);

//--------------------------------
// Synchronizers for CSR module
//--------------------------------
fim_resync #(
    .SYNC_CHAIN_LENGTH  (2),
    .WIDTH              ($bits({cold_rst_ack_n,rx_rst_ack_n,tx_rst_ack_n})),
    .INIT_VALUE         (0),
    .NO_CUT             (0)
   ) inst_sync_ack (
    .clk                (clk_csr),
    .reset              (~rst_n_csr),
    .d                  ({cold_rst_ack_n,rx_rst_ack_n,tx_rst_ack_n}),
    .q                  ({sync_cold_rst_ack_n,sync_rx_rst_ack_n,sync_tx_rst_ack_n})
);

fim_resync #(
    .SYNC_CHAIN_LENGTH  (2),
    .WIDTH              ($bits({rx_pcs_ready,tx_lanes_stable,tx_pll_locked})),
    .INIT_VALUE         (0),
    .NO_CUT             (0)
   ) inst_sync_stats (
    .clk                (clk_csr),
    .reset              (~rst_n_csr),
    .d                  ({rx_pcs_ready,tx_lanes_stable,tx_pll_locked}),
    .q                  ({sync_rx_pcs_ready,sync_tx_lanes_stable,sync_tx_pll_locked})
);

//--------------------------------
// PTP-CSR interface logic
//--------------------------------
`ifdef INCLUDE_PTP
   fim_resync #(
       .SYNC_CHAIN_LENGTH  (2),
       .WIDTH              ($bits({rx_ptp_ready,tx_ptp_ready})),
       .INIT_VALUE         (0),
       .NO_CUT             (0)
      ) inst_sync_ptp_ready (
       .clk                (clk_csr),
       .reset              (~rst_n_csr),
       .d                  ({rx_ptp_ready,tx_ptp_ready}),
       .q                  ({sync_rx_ptp_ready,sync_tx_ptp_ready})
   );

   //generate 114.285714MHz
   `ifndef ETH_100G
   ptp_sample_clk_pll  ptp_sample_clk_pll (
      .rst        (~rst_n_csr),
      .refclk     (clk_csr),
      .locked     (),
      .permit_cal (sys_pll_locked),
      .outclk_0  (clk_ptp_sample)
   );

   assign p0_clk_ptp_sample  = clk_ptp_sample;
   assign p3_clk_ptp_sample  = clk_ptp_sample;
   assign p4_clk_ptp_sample  = clk_ptp_sample;
   assign p8_clk_ptp_sample  = clk_ptp_sample;
   assign p10_clk_ptp_sample = clk_ptp_sample;
   assign p11_clk_ptp_sample = clk_ptp_sample;
   assign p12_clk_ptp_sample = clk_ptp_sample;
   `endif
`else
   assign sync_tx_ptp_ready      = 'h0;
   assign sync_rx_ptp_ready      = 'h0;
`endif

//----------------------------
// HSSI SS instantiation
//----------------------------
hssi_ss #( 
   `ifdef SIM_MODE
      .SIM_MODE                      (1'b1),
      `else
      .SIM_MODE                      (1'b0),
      `endif
      .SET_AXI_LITE_RESPONSE_TO_ZERO (1'b1),
      .DFHv0_FEA_EOL                 (END_OF_LIST),
      .DFHv0_FEA_NXT                 (NEXT_DFH_OFFSET)
) hssi_ss (
   .app_ss_lite_clk                    (clk_csr),
   .app_ss_lite_areset_n               (rst_n_csr),
   .app_ss_lite_awaddr                 ({15'h0,ss_ip_csr_if.awaddr[10:0]}),
   .app_ss_lite_awprot                 (ss_ip_csr_if.awprot),
   .app_ss_lite_awvalid                (ss_ip_csr_if.awvalid),
   .ss_app_lite_awready                (ss_ip_csr_if.awready),
   .app_ss_lite_wdata                  (ss_ip_csr_if.wdata),
   .app_ss_lite_wstrb                  (ss_ip_csr_if.wstrb),
   .app_ss_lite_wvalid                 (ss_ip_csr_if.wvalid),
   .ss_app_lite_wready                 (ss_ip_csr_if.wready),
   .ss_app_lite_bresp                  (ss_ip_csr_if.bresp),
   .ss_app_lite_bvalid                 (ss_ip_csr_if.bvalid),
   .app_ss_lite_bready                 (ss_ip_csr_if.bready),
   .app_ss_lite_araddr                 ({15'h0,ss_ip_csr_if.araddr[10:0]}),
   .app_ss_lite_arprot                 (ss_ip_csr_if.arprot),
   .app_ss_lite_arvalid                (ss_ip_csr_if.arvalid),
   .ss_app_lite_arready                (ss_ip_csr_if.arready),
   .ss_app_lite_rdata                  (ss_ip_csr_if.rdata),
   .ss_app_lite_rvalid                 (ss_ip_csr_if.rvalid),
   .app_ss_lite_rready                 (ss_ip_csr_if.rready),
   .ss_app_lite_rresp                  (ss_ip_csr_if.rresp),

   // The `INST_ALL_PORTS macro is defined in 
   // $OFS_ROOTDIR/sim/scripts/qip_gen_<platform>/syn/syn_top/ofs_ip_cfg_db/ofs_ip_cfg_hssi_ss.vh
   // This macro instantiates N instances of `HSSI_PORT_INST foudn in 
   // $OFS_ROOTDIR/ipss/hssi/rtl/inc/of_fim_eth_plat_defines.svh
   // An example of a single port bank (Bank 0) is as follows:
   //  .p0_app_ss_st_tx_clk           (hssi_ss_st_tx[PORT_0].clk), \
   //  .p0_app_ss_st_tx_areset_n      (hssi_ss_st_tx[PORT_0].rst_n), \
   //  .p0_app_ss_st_tx_tvalid        (hssi_ss_st_tx[PORT_0].tx.tvalid), \
   //  .p0_ss_app_st_tx_tready        (hssi_ss_st_tx[PORT_0].tready), \
   //  .p0_app_ss_st_tx_tdata         (hssi_ss_st_tx[PORT_0].tx.tdata), \
   //  .p0_app_ss_st_tx_tkeep         (hssi_ss_st_tx[PORT_0].tx.tkeep), \
   //  .p0_app_ss_st_tx_tlast         (hssi_ss_st_tx[PORT_0].tx.tlast), \
   //  .p0_app_ss_st_tx_tuser_client  (hssi_ss_st_tx[PORT_0].tx.tuser.client), \
   //  .p0_app_ss_st_rx_clk           (hssi_ss_st_rx[PORT_0].clk), \
   //  .p0_app_ss_st_rx_areset_n      (hssi_ss_st_rx[PORT_0].rst_n), \
   //  .p0_ss_app_st_rx_tvalid        (hssi_ss_st_rx[PORT_0].rx.tvalid), \
   //  .p0_ss_app_st_rx_tdata         (hssi_ss_st_rx[PORT_0].rx.tdata), \
   //  .p0_ss_app_st_rx_tkeep         (hssi_ss_st_rx[PORT_0].rx.tkeep), \
   //  .p0_ss_app_st_rx_tlast         (hssi_ss_st_rx[PORT_0].rx.tlast), \
   //  .p0_ss_app_st_rx_tuser_client  (hssi_ss_st_rx[PORT_0].rx.tuser.client), \
   //  .p0_ss_app_st_rx_tuser_sts     (hssi_ss_st_rx[PORT_0].rx.tuser.sts), \
   //  .p0_tx_serial                  (serial_tx_p[PORT_0]), \
   //  .p0_tx_serial_n                (serial_tx_n[PORT_0]), \
   //  .p0_rx_serial                  (serial_rx_p[PORT_0]), \
   //  .p0_rx_serial_n                (serial_rx_n[PORT_0]), \
   //  .p0_tx_lanes_stable            (tx_lanes_stable[PORT_0]), \
   //  .p0_rx_pcs_ready               (rx_pcs_ready[PORT_0]), \
   //  .i_p0_tx_pause                 (hssi_fc[PORT_0].tx_pause), \
   //  .i_p0_tx_pfc                   (hssi_fc[PORT_0].tx_pfc), \
   //  .i_p0_tx_rst_n                 (~handshaked_tx_rst[PORT_0]), \
   //  .i_p0_rx_rst_n                 (~handshaked_rx_rst[PORT_0]), \
   //  .o_p0_rx_pause                 (hssi_fc[PORT_0].rx_pause), \
   //  .o_p0_rx_pfc                   (hssi_fc[PORT_0].rx_pfc), \
   //  .o_p0_tx_pll_locked            (tx_pll_locked[PORT_0]), \
   //  .o_p0_rx_rst_ack_n             (rx_rst_ack_n[PORT_0]), \
   //  .o_p0_tx_rst_ack_n             (tx_rst_ack_n[PORT_0]), \
   //  .o_p0_ereset_n                 (), \
   //  .o_p0_clk_pll                  (clk_pll[PORT_0]), \
   //  .o_p0_clk_tx_div               (clk_tx_div[PORT_0]), \
   //  .o_p0_clk_rec_div64            (clk_rec_div64[PORT_0]), \
   //  .o_p0_clk_rec_div              (clk_rec_div[PORT_0]), \
   //  .port0_led_speed               (led_speed[PORT_0]), \
   //  .port0_led_status              (led_status[PORT_0]),
   // 
   // The `INST_ALL_PORTS macro is generated by
   // $OFS_ROOTDIR/ofs-common/scripts/common/syn/ip_get_cfg/hssi_s_get_cfg.tcl 
   
   `INST_ALL_PORTS 
  
`ifdef MAC_SEGMENTED
//Connecting the last_segment signals for the hssi_ss ip for ETH_200G (Ports 8,12) and ETH_400G (Port 8) configurations. 
//The macros used below are defined in the ofs_ip_cfg_db.vh
  `ifdef INCLUDE_HSSI_PORT_12
   .p12_app_ss_st_tx_tuser_last_segment (hssi_ss_st_tx[PORT_12].tx.tuser.last_segment),
   .p12_ss_app_st_rx_tuser_last_segment (hssi_ss_st_rx[PORT_12].rx.tuser.last_segment),
   `endif
   `ifdef INCLUDE_HSSI_PORT_8
   .p8_app_ss_st_tx_tuser_last_segment (hssi_ss_st_tx[PORT_8].tx.tuser.last_segment),
   .p8_ss_app_st_rx_tuser_last_segment (hssi_ss_st_rx[PORT_8].rx.tuser.last_segment), 
   `endif
`endif
   .subsystem_cold_rst_n               (~handshaked_cold_rst),
   .subsystem_cold_rst_ack_n           (cold_rst_ack_n),
   .i_clk_ref                          (i_hssi_clk_ref)
);




genvar lane;
generate
   for (lane = 0; lane < NUM_ETH_LANES; lane = lane + 1) begin : GENLANES
      always_comb begin
         localparam integer PORT_IDX = lane/NUM_LANES;
         localparam integer LANE_IDX = lane%NUM_LANES;
         serial_rx_p[ETH_PORT_EN_ARRAY[PORT_IDX]][LANE_IDX] = hssi_if[lane].rx_p;
         serial_rx_n[ETH_PORT_EN_ARRAY[PORT_IDX]][LANE_IDX] = hssi_if[lane].rx_n;
         hssi_if[lane].tx_p = serial_tx_p[ETH_PORT_EN_ARRAY[PORT_IDX]][LANE_IDX];
         hssi_if[lane].tx_n = serial_tx_n[ETH_PORT_EN_ARRAY[PORT_IDX]][LANE_IDX];
      end
     end
endgenerate

localparam LED_WIDTH = 3;
logic [LED_WIDTH-1:0][MAX_NUM_ETH_CHANNELS-1:0] inv_led_speed; 
logic [LED_WIDTH-1:0][MAX_NUM_ETH_CHANNELS-1:0] inv_led_status;

// We need to transpose the led_speed/led_status arrays so that we
// can perform bitwise operators the rows
genvar row,col;
generate
   for (row = 0; row < MAX_NUM_ETH_CHANNELS; row = row + 1) begin : GENLEDSTATUSROW
      for (col = 0; col < LED_WIDTH; col = col + 1) begin : GENLEDSTATUSCOL
         always_comb begin
            inv_led_speed[col][row] = led_speed[row][col];
            inv_led_status[col][row] = led_status[row][col];
         end
      end
   end
endgenerate

localparam integer PORTS_PER_QSFP = NUM_ETH_CHANNELS/NUM_QSFP_PORTS_USED; 

genvar qsfp_idx;
generate
   for (qsfp_idx = 0; qsfp_idx < NUM_QSFP_PORTS_USED; qsfp_idx = qsfp_idx + 1) begin : GENACTIVITYLED
      always_comb begin
         localparam integer QSFP_IDX_H = (qsfp_idx*PORTS_PER_QSFP)+(PORTS_PER_QSFP-1);
         localparam integer QSFP_IDX_L = (qsfp_idx*PORTS_PER_QSFP);
         o_qsfp_speed_green[qsfp_idx]    = &inv_led_speed[2][QSFP_IDX_H:QSFP_IDX_L];
         o_qsfp_speed_yellow[qsfp_idx]   = &inv_led_speed[1][QSFP_IDX_H:QSFP_IDX_L];
         o_qsfp_activity_green[qsfp_idx] = &inv_led_status[2][QSFP_IDX_H:QSFP_IDX_L];
         o_qsfp_activity_red[qsfp_idx]   = |inv_led_status[1][QSFP_IDX_H:QSFP_IDX_L];
      end
   end
endgenerate

//----------------------------------------
// Recover clock mapping for SYNCE
//----------------------------------------
if (NUM_ETH_CHANNELS < 3) begin
   assign o_hssi_rec_clk[NUM_ETH_CHANNELS-1:0] = clk_rec_div64[NUM_ETH_CHANNELS-1:0];
   assign o_hssi_rec_clk[2:NUM_ETH_CHANNELS]   = {(3-NUM_ETH_CHANNELS){clk_rec_div64[NUM_ETH_CHANNELS-1:0]}};
end
else begin
   assign o_hssi_rec_clk = clk_rec_div64[2:0];
end

//----------------------------------------
// EHIP PLL clock and lock mapping for CPRI
//----------------------------------------
assign o_ehip_clk_806    = ehip0_ptp_clk_pll;
assign o_ehip_clk_403    = ehip0_ptp_clk_tx_div;
assign o_ehip_pll_locked = tx_pll_locked[0];

endmodule

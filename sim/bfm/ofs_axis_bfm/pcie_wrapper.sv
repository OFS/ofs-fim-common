// Copyright (C) 2020 Intel Corporation.
// SPDX-License-Identifier: MIT

//
// Description
//-----------------------------------------------------------------------------
//
// Top level module of PCIe subsystem.
//
//-----------------------------------------------------------------------------

`include "fpga_defines.vh"
`include "ofs_ip_cfg_db.vh"


module pcie_wrapper 
import ofs_fim_cfg_pkg::*;
import pcie_ss_axis_pkg::*;
import ofs_fim_pcie_hdr_def::*;
#(
   parameter            PCIE_LANES      = 16,
   parameter            PCIE_NUM_LINKS  = 1,
   parameter            MM_ADDR_WIDTH   = 19,
   parameter            MM_DATA_WIDTH   = 64,
   parameter bit [11:0] FEAT_ID         = 12'h0,
   parameter bit [3:0]  FEAT_VER        = 4'h0,
   parameter bit [23:0] NEXT_DFH_OFFSET = 24'h1000,
   parameter bit        END_OF_LIST     = 1'b0,
   parameter            SOC_ATTACH      = 0
)(
   input  logic                      fim_clk,
   input  logic [PCIE_NUM_LINKS-1:0] fim_rst_n,

   input  logic                      csr_clk,
   input  logic [PCIE_NUM_LINKS-1:0] csr_rst_n,

   input  logic                      ninit_done,
   output logic [PCIE_NUM_LINKS-1:0] reset_status,

   input  logic [PCIE_NUM_LINKS-1:0] subsystem_cold_rst_n,    
   input  logic [PCIE_NUM_LINKS-1:0] subsystem_warm_rst_n,    
   output logic [PCIE_NUM_LINKS-1:0] subsystem_cold_rst_ack_n,
   output logic [PCIE_NUM_LINKS-1:0] subsystem_warm_rst_ack_n,
   
   // PCIe pins
   ofs_fim_pcie_ss_pins_if.pcie_ss   pin_pcie,

   //Ctrl Shadow ports
   output logic [PCIE_NUM_LINKS-1:0]        ss_app_st_ctrlshadow_tvalid,
   output logic [PCIE_NUM_LINKS-1:0] [39:0] ss_app_st_ctrlshadow_tdata,

   // AXI-S data interfaces
   pcie_ss_axis_if.source            axi_st_rxreq_if[PCIE_NUM_LINKS-1:0],   // MMIO (when PCIe SS completions are sorted)
   pcie_ss_axis_if.source            axi_st_rx_if[PCIE_NUM_LINKS-1:0],      // Host memory read completions
   pcie_ss_axis_if.sink              axi_st_tx_if[PCIE_NUM_LINKS-1:0],      // Any FPGA to host command or completion
   pcie_ss_axis_if.sink              axi_st_txreq_if[PCIE_NUM_LINKS-1:0],   // DM-encoded reads or interrupts

   // AXI4-lite CSR interface
   ofs_fim_axi_lite_if.slave        csr_lite_if[PCIE_NUM_LINKS-1:0],
  
   //Completion Timeout Interface
   output pcie_ss_axis_pkg::t_axis_pcie_cplto axis_cpl_timeout[PCIE_NUM_LINKS-1:0],
 
   output pcie_ss_axis_pkg::t_pcie_tag_mode tag_mode[PCIE_NUM_LINKS-1:0],

   // FLR 
   output pcie_ss_axis_pkg::t_axis_pcie_flr    axi_st_flr_req[PCIE_NUM_LINKS-1:0],
   input  pcie_ss_axis_pkg::t_axis_pcie_flr    axi_st_flr_rsp[PCIE_NUM_LINKS-1:0]

);  

localparam NATIVE_TXREQ_WIDTH = host_bfm_types_pkg::TXREQ_DATA_WIDTH;
localparam NATIVE_TDATA_WIDTH = host_bfm_types_pkg::TDATA_WIDTH;
localparam TUSER_WIDTH = host_bfm_types_pkg::TUSER_WIDTH;

pcie_ss_axis_if #(.DATA_W(NATIVE_TXREQ_WIDTH), .USER_W(TUSER_WIDTH)) axi_st_txreq_if_native[PCIE_NUM_LINKS-1:0] (.clk(fim_clk), .rst_n(fim_rst_n));
pcie_ss_axis_if #(.DATA_W(NATIVE_TDATA_WIDTH), .USER_W(TUSER_WIDTH)) axi_st_rxreq_if_native[PCIE_NUM_LINKS-1:0] (.clk(fim_clk), .rst_n(fim_rst_n));
pcie_ss_axis_if #(.DATA_W(NATIVE_TDATA_WIDTH), .USER_W(TUSER_WIDTH)) axi_st_rx_if_native[PCIE_NUM_LINKS-1:0] (.clk(fim_clk), .rst_n(fim_rst_n));
pcie_ss_axis_if #(.DATA_W(NATIVE_TDATA_WIDTH), .USER_W(TUSER_WIDTH)) axi_st_tx_if_native[PCIE_NUM_LINKS-1:0] (.clk(fim_clk), .rst_n(fim_rst_n));

// Hold dummy links in reset
pcie_ss_axis_if #(.DATA_W(NATIVE_TXREQ_WIDTH), .USER_W(TUSER_WIDTH)) axi_st_txreq_if_dummy[PCIE_NUM_LINKS-1:0] (.clk(fim_clk), .rst_n(1'b0));
pcie_ss_axis_if #(.DATA_W(NATIVE_TDATA_WIDTH), .USER_W(TUSER_WIDTH)) axi_st_rxreq_if_dummy[PCIE_NUM_LINKS-1:0] (.clk(fim_clk), .rst_n(1'b0));
pcie_ss_axis_if #(.DATA_W(NATIVE_TDATA_WIDTH), .USER_W(TUSER_WIDTH)) axi_st_rx_if_dummy[PCIE_NUM_LINKS-1:0] (.clk(fim_clk), .rst_n(1'b0));
pcie_ss_axis_if #(.DATA_W(NATIVE_TDATA_WIDTH), .USER_W(TUSER_WIDTH)) axi_st_tx_if_dummy[PCIE_NUM_LINKS-1:0] (.clk(fim_clk), .rst_n(1'b0));
pcie_ss_axis_pkg::t_axis_pcie_flr    axi_st_flr_rsp_dummy[PCIE_NUM_LINKS-1:0];

t_axis_pcie         axis_tx[PCIE_NUM_LINKS-1:0];
logic [PCIE_NUM_LINKS-1:0]   axis_tx_tready;

logic [PCIE_NUM_LINKS-1:0]   pcie_linkup;
logic [31:0]        pcie_rx_err_code[PCIE_NUM_LINKS-1:0];

pcie_ss_axis_if #(.DATA_W(NATIVE_TDATA_WIDTH), .USER_W(TUSER_WIDTH)) rxreq_in[PCIE_NUM_LINKS-1:0](.clk(fim_clk), .rst_n(fim_rst_n));
pcie_ss_axis_if #(.DATA_W(NATIVE_TDATA_WIDTH), .USER_W(TUSER_WIDTH)) axi_st_tx_committed[PCIE_NUM_LINKS-1:0](.clk(fim_clk), .rst_n(fim_rst_n));


ofs_fim_axi_lite_if #(.AWADDR_WIDTH(20), .ARADDR_WIDTH(20), .WDATA_WIDTH(32), .RDATA_WIDTH(32)) ss_csr_lite_if[PCIE_NUM_LINKS-1:0]();
ofs_fim_axi_lite_if #(.AWADDR_WIDTH(20), .ARADDR_WIDTH(20), .WDATA_WIDTH(32), .RDATA_WIDTH(32)) ss_csr_lite_if_dummy[PCIE_NUM_LINKS-1:0]();
ofs_fim_axi_lite_if #(.AWADDR_WIDTH(20), .ARADDR_WIDTH(20), .WDATA_WIDTH(32), .RDATA_WIDTH(32)) ss_csr_lite_if_bfm_dummy();

import ofs_fim_if_pkg::*;
t_sideband_from_pcie   pcie_p2c_sideband[PCIE_NUM_LINKS-1:0];

generate
    for (genvar j=0; j<PCIE_NUM_LINKS; j++) begin : PCIE_LINKS
 
        // Adjust bus width between FIM and PCIe IP, done mainly when the native
        // bus is very narrow and the FIM requires something wider. When the
        // FIM and native sizes are the same the connections will just be wired
        // together.
        ofs_fim_pcie_bus_width rx_if_width (.i_if(axi_st_rx_if_native[j]), .o_if(axi_st_rx_if[j]));
        ofs_fim_pcie_bus_width rxreq_if_width (.i_if(axi_st_rxreq_if_native[j]), .o_if(axi_st_rxreq_if[j]));
        ofs_fim_pcie_bus_width tx_if_width (.i_if(axi_st_tx_if[j]), .o_if(axi_st_tx_if_native[j]));
        ofs_fim_pcie_bus_width txreq_if_width (.i_if(axi_st_txreq_if[j]), .o_if(axi_st_txreq_if_native[j]));

        pcie_ss_axis_if #(
            .DATA_W(NATIVE_TDATA_WIDTH),
            .USER_W(TUSER_WIDTH)
            ) rxreq_arb_in[2](.clk(fim_clk), .rst_n(fim_rst_n[j]));

       
        always_comb 
        begin
            // axis tx intf
            axis_tx[j].tvalid = axi_st_tx_if_native[j].tvalid;
            axis_tx[j].tdata  = axi_st_tx_if_native[j].tdata;
            axis_tx[j].tkeep  = axi_st_tx_if_native[j].tkeep;
            axis_tx[j].tlast  = axi_st_tx_if_native[j].tlast;
            axis_tx[j].tuser  = axi_st_tx_if_native[j].tuser_vendor;

            axis_tx_tready[j] = axi_st_tx_if_native[j].tready;

            // rx to arb
            rxreq_arb_in[0].tvalid             = rxreq_in[j].tvalid;  
            rxreq_arb_in[0].tdata              = rxreq_in[j].tdata;  
            rxreq_arb_in[0].tkeep              = rxreq_in[j].tkeep;  
            rxreq_arb_in[0].tlast              = rxreq_in[j].tlast;  
            rxreq_arb_in[0].tuser_vendor       = rxreq_in[j].tuser_vendor;  

            rxreq_in[j].tready                 = rxreq_arb_in[0].tready;

        end

        pcie_ss_if #(
            .MM_ADDR_WIDTH   (MM_ADDR_WIDTH), 
            .MM_DATA_WIDTH   (MM_DATA_WIDTH),
            .FEAT_ID         (FEAT_ID),
            .FEAT_VER        (FEAT_VER),
            .NEXT_DFH_OFFSET (NEXT_DFH_OFFSET),
            .END_OF_LIST     (END_OF_LIST)   
        ) pcie_ss_if (
            .fim_clk            (fim_clk),
            .fim_rst_n          (fim_rst_n[j]),
            
            .csr_clk            (csr_clk),
            .csr_rst_n          (csr_rst_n[j]),
            
            .i_axis_tx          (axis_tx[j]),
            .i_axis_tx_tready   (axis_tx_tready[j]),
            
            .i_axis_cpl_timeout (axis_cpl_timeout[j]),
            
            .i_pcie_linkup      (pcie_linkup[j]),
            .i_rx_err_code      (pcie_rx_err_code[j]),
            
            .csr_lite_if        (csr_lite_if[j]),
            .ss_csr_lite_if     (ss_csr_lite_if[j])
        );


        // OFS does not guarantee the relative order of write requests on TX and read requests
        // on TXREQ until this point, where requests enter the PCIe SS. Here, a completion
        // without data is returned to the AFU as a write request commits, indicating that
        // the future reads will see the committed write data.
        //

        // Generate write commits on the commit port. The TX stream toward the PCIe SS
        // is on the source port.
        pcie_arb_local_commit local_commit
        (
            .clk    ( fim_clk       ),
            .rst_n  ( fim_rst_n     ),
            .sink   ( axi_st_tx_if_native[j] ),
            .source ( axi_st_tx_committed[j] ),
            .commit ( rxreq_arb_in[1] )
        );

        // Combine the write commit stream and RXREQ toward the AFU.
        pcie_ss_axis_mux #(
            .NUM_CH ( 2 ),
            .TDATA_WIDTH ( NATIVE_TDATA_WIDTH ),
            .TUSER_WIDTH ( TUSER_WIDTH )
        ) ho2mx_rxreq_mux (
            .clk    ( fim_clk       ),
            .rst_n  ( fim_rst_n[j]  ),
            .sink   ( rxreq_arb_in  ),
            .source ( axi_st_rxreq_if_native[j] )
        );

        ofs_fim_pcie_ss_tag_mode ofs_fim_pcie_ss_tag_mode (
           .fim_clk                        (fim_clk),
           .fim_rst_n                      (fim_rst_n[j]),
           .csr_clk                        (csr_clk),
           .csr_rst_n                      (csr_rst_n[j]),
           .p0_ss_app_st_ctrlshadow_tvalid (ss_app_st_ctrlshadow_tvalid[j] ),
           .p0_ss_app_st_ctrlshadow_tdata  (ss_app_st_ctrlshadow_tdata[j]  ),
           .tag_mode                       (tag_mode[j])
        );
        
        ofs_fim_pcie_ss_debug_log ofs_fim_pcie_ss_debug_log (
           .fim_clk                    (fim_clk),
           .fim_rst_n                  (fim_rst_n[j]),
           .axi_st_rxreq_if            (axi_st_rxreq_if[j]), 
           .axi_st_rx_if               (axi_st_rx_if[j]),    
           .axi_st_tx_if               (axi_st_tx_if[j]),    
           .axi_st_txreq_if            (axi_st_txreq_if[j]) 
        
        );

        assign pcie_linkup[j] = pcie_p2c_sideband[j].pcie_linkup;
        assign pcie_rx_err_code[j] = pcie_p2c_sideband[j].pcie_chk_rx_err_code;
    end // PCIE_LINKS
endgenerate

   // Include the subsystem in simulation design, but tie off all the I/O since the functionality is served by the BFM
   // This is required to compile F-Tile designs which includes tile support logic containing cross hierarchical references to the PCIe HIP

`ifdef FTILE_SIM
// Is the host PCIe interface data mover?
`ifdef OFS_FIM_IP_CFG_PCIE_SS_FUNC_MODE_IS_DM
    localparam PCIE_MODE_IS_DM = 1;
`else
    localparam PCIE_MODE_IS_DM = 0;
`endif

// Is the SoC PCIe interface data mover (if present)?
`ifdef OFS_FIM_IP_CFG_SOC_PCIE_SS_FUNC_MODE_IS_DM
    localparam SOC_PCIE_MODE_IS_DM = 1;
`else
    localparam SOC_PCIE_MODE_IS_DM = 0;
`endif

// Is the target PCIe interface DM?
localparam MODE_IS_DM = SOC_ATTACH ? SOC_PCIE_MODE_IS_DM : PCIE_MODE_IS_DM;

ofs_fim_pcie_ss_pins_if #(.PCIE_LANES(ofs_fim_cfg_pkg::PCIE_LANES)) pin_pcie_dummy();
assign pin_pcie_dummy.refclk0_p = 1'b0;
assign pin_pcie_dummy.refclk1_p = 1'b0;
assign pin_pcie_dummy.in_perst_n = 1'b0;

`define PCIE_SS_TOP_PORTS \
    .fim_clk                        ('0), \
    .fim_rst_n                      ('1), \
    .csr_clk                        ('0), \
    .csr_rst_n                      ('1), \
    .ninit_done                     ('0), \
    .subsystem_cold_rst_n           ('1), \
    .subsystem_warm_rst_n           ('1), \
    .subsystem_cold_rst_ack_n       (), \
    .subsystem_warm_rst_ack_n       (), \
    .pin_pcie                       (pin_pcie_dummy), \
    .axi_st_txreq_if                (axi_st_txreq_if_dummy       ), \
    .axi_st_rxreq_if                (axi_st_rxreq_if_dummy       ), \
    .ss_app_st_ctrlshadow_tvalid    (), \ 
    .ss_app_st_ctrlshadow_tdata     (), \
    .axi_st_rx_if                   (axi_st_rx_if_dummy          ), \
    .axi_st_tx_if                   (axi_st_tx_if_dummy          ), \
    .ss_csr_lite_if                 (ss_csr_lite_if_dummy        ), \
    .flr_req_if                     (), \
    .flr_rsp_if                     (axi_st_flr_rsp              ), \
    .reset_status                   (), \
    .cpl_timeout_if                 (), \
    .pcie_p2c_sideband              () \

    if (MODE_IS_DM) begin : pcie_ss
        pcie_ss_dm_top #(
           .PCIE_LANES       (ofs_fim_cfg_pkg::PCIE_LANES),
           .PCIE_NUM_LINKS   (PCIE_NUM_LINKS),
           .SOC_ATTACH       (SOC_ATTACH)
        ) top (
           `PCIE_SS_TOP_PORTS
        );
    end
    else begin : pcie_ss
    pcie_ss_axis_top #(
        .PCIE_LANES       (ofs_fim_cfg_pkg::PCIE_LANES),
        .PCIE_NUM_LINKS   (PCIE_NUM_LINKS),
        .SOC_ATTACH       (SOC_ATTACH)
        ) top (
        `PCIE_SS_TOP_PORTS
       );
end

   assign axi_st_rxreq_if_dummy[0].tready = 1'b1;
   assign axi_st_rx_if_dummy[0].tready    = 1'b1;
   assign axi_st_tx_if_dummy[0].tvalid    = 1'b0;
   assign axi_st_flr_rsp_dummy[0].tvalid  = 1'b0;
   if (PCIE_NUM_LINKS > 1)
   begin
      assign axi_st_rxreq_if_dummy[1].tready = 1'b1;
      assign axi_st_rx_if_dummy[1].tready    = 1'b1;
      assign axi_st_tx_if_dummy[1].tvalid    = 1'b0;
      assign axi_st_flr_rsp_dummy[1].tvalid  = 1'b0;
   end

`endif

//-------------------------------------------------------------------------------
// Used only for Unit sim testing.  For f2000x designs, code generates
// a 'pcie_top' using the scope for the package import that will be unique for
// that block, whether it is a host- or soc-oriented block.
//-------------------------------------------------------------------------------
generate
   if (SOC_ATTACH)
   begin : soc_gen_block
      import ofs_fim_if_pkg::*;

      pcie_top #(
         .PCIE_LANES       (16),
         .NUM_PF           (ofs_fim_pcie_pkg::NUM_PF),
         .NUM_VF           (ofs_fim_pcie_pkg::NUM_VF),
         .MAX_NUM_VF       (ofs_fim_pcie_pkg::MAX_NUM_VF),
         .SOC_ATTACH       (SOC_ATTACH),
         .LINK_NUMBER      (0),
         .PF_ENABLED_VEC_T (pfvf_def_pkg_soc::PF_ENABLED_SOC_VEC_T),
         .PF_ENABLED_VEC   (pfvf_def_pkg_soc::PF_ENABLED_SOC_VEC),
         .PF_NUM_VFS_VEC_T (pfvf_def_pkg_soc::PF_NUM_VFS_SOC_VEC_T),
         .PF_NUM_VFS_VEC   (pfvf_def_pkg_soc::PF_NUM_VFS_SOC_VEC),
         .MM_ADDR_WIDTH    (MM_ADDR_WIDTH),
         .MM_DATA_WIDTH    (MM_DATA_WIDTH),
         .FEAT_ID          (12'h020),
         .FEAT_VER         (4'h0),
         .NEXT_DFH_OFFSET  (24'h1000),
         .END_OF_LIST      (1'b0)  
      ) pcie_top_soc (
         .fim_clk               (fim_clk                    ),
         .fim_rst_n             (fim_rst_n[0]               ),
         .csr_clk               (csr_clk                    ),
         .csr_rst_n             (csr_rst_n[0]               ),
         .ninit_done            (ninit_done                 ),
         .reset_status          (reset_status[0]            ),                 
         .pin_pcie_refclk0_p    (pin_pcie.refclk0_p         ),
         .pin_pcie_refclk1_p    (pin_pcie.refclk1_p         ),
         .pin_pcie_in_perst_n   (pin_pcie.in_perst_n        ),
         .pin_pcie_rx_p         (pin_pcie.rx_p[0]           ),
         .pin_pcie_rx_n         (pin_pcie.rx_n[0]           ),
         .pin_pcie_tx_p         (pin_pcie.tx_p[0]           ),                
         .pin_pcie_tx_n         (pin_pcie.tx_n[0]           ),                
         .axi_st_rx_if          (axi_st_rx_if_native[0]     ),
         .axi_st_tx_if          (axi_st_tx_committed[0]     ),
         .axi_st_txreq_if       (axi_st_txreq_if_native[0]  ),
         .axi_st_rxreq_if       (rxreq_in[0]                ),
         .csr_lite_if           (ss_csr_lite_if[0]          ),
         .flr_req_if            (axi_st_flr_req[0]          ),
         .flr_rsp_if            (axi_st_flr_rsp[0]          ),
         .cpl_timeout_if        (axis_cpl_timeout[0]        ),
         .pcie_p2c_sideband     (pcie_p2c_sideband[0]       )
      );
   end
   else
   begin : host_gen_block0
      import ofs_fim_if_pkg::*;

      pcie_top #(
         .PCIE_LANES       (16),
         .NUM_PF           (ofs_fim_pcie_pkg::NUM_PF),
         .NUM_VF           (ofs_fim_pcie_pkg::NUM_VF),
         .MAX_NUM_VF       (ofs_fim_pcie_pkg::MAX_NUM_VF),
         .SOC_ATTACH       (SOC_ATTACH),
         .LINK_NUMBER      (0),
         .PF_ENABLED_VEC_T (pfvf_def_pkg_host::PF_ENABLED_HOST_VEC_T),
         .PF_ENABLED_VEC   (pfvf_def_pkg_host::PF_ENABLED_HOST_VEC),
         .PF_NUM_VFS_VEC_T (pfvf_def_pkg_host::PF_NUM_VFS_HOST_VEC_T),
         .PF_NUM_VFS_VEC   (pfvf_def_pkg_host::PF_NUM_VFS_HOST_VEC),
         .MM_ADDR_WIDTH    (MM_ADDR_WIDTH),
         .MM_DATA_WIDTH    (MM_DATA_WIDTH),
         .FEAT_ID          (12'h020),
         .FEAT_VER         (4'h0),
         .NEXT_DFH_OFFSET  (24'h1000),
         .END_OF_LIST      (1'b0)  
      ) pcie_top_host0 (
         .fim_clk               (fim_clk                    ),
         .fim_rst_n             (fim_rst_n[0]               ),
         .csr_clk               (csr_clk                    ),
         .csr_rst_n             (csr_rst_n[0]               ),
         .ninit_done            (ninit_done                 ),
         .reset_status          (reset_status[0]            ),                 
         .pin_pcie_refclk0_p    (pin_pcie.refclk0_p         ),
         .pin_pcie_refclk1_p    (pin_pcie.refclk1_p         ),
         .pin_pcie_in_perst_n   (pin_pcie.in_perst_n        ),
         .pin_pcie_rx_p         (pin_pcie.rx_p[0]           ),
         .pin_pcie_rx_n         (pin_pcie.rx_n[0]           ),
         .pin_pcie_tx_p         (pin_pcie.tx_p[0]           ),                
         .pin_pcie_tx_n         (pin_pcie.tx_n[0]           ),                
         .axi_st_rx_if          (axi_st_rx_if_native[0]     ),
         .axi_st_tx_if          (axi_st_tx_committed[0]     ),
         .axi_st_txreq_if       (axi_st_txreq_if_native[0]  ),
         .axi_st_rxreq_if       (rxreq_in[0]                ),
         .csr_lite_if           (ss_csr_lite_if[0]          ),
         .flr_req_if            (axi_st_flr_req[0]          ),
         .flr_rsp_if            (axi_st_flr_rsp[0]          ),
         .cpl_timeout_if        (axis_cpl_timeout[0]        ),
         .pcie_p2c_sideband     (pcie_p2c_sideband[0]       )
      );
      if (PCIE_NUM_LINKS > 1)
      begin : host_gen_block1

         pcie_top #(
            .PCIE_LANES       (16),
            .NUM_PF           (ofs_fim_pcie_pkg::NUM_PF),
            .NUM_VF           (ofs_fim_pcie_pkg::NUM_VF),
            .MAX_NUM_VF       (ofs_fim_pcie_pkg::MAX_NUM_VF),
            .SOC_ATTACH       (SOC_ATTACH),
            .LINK_NUMBER      (1),
            .PF_ENABLED_VEC_T (pfvf_def_pkg_host::PF_ENABLED_HOST_VEC_T),
            .PF_ENABLED_VEC   (pfvf_def_pkg_host::PF_ENABLED_HOST_VEC),
            .PF_NUM_VFS_VEC_T (pfvf_def_pkg_host::PF_NUM_VFS_HOST_VEC_T),
            .PF_NUM_VFS_VEC   (pfvf_def_pkg_host::PF_NUM_VFS_HOST_VEC),
            .MM_ADDR_WIDTH    (MM_ADDR_WIDTH),
            .MM_DATA_WIDTH    (MM_DATA_WIDTH),
            .FEAT_ID          (12'h020),
            .FEAT_VER         (4'h0),
            .NEXT_DFH_OFFSET  (24'h1000),
            .END_OF_LIST      (1'b0)  
         ) pcie_top_host1 (
            .fim_clk               (fim_clk                    ),
            .fim_rst_n             (fim_rst_n[1]               ),
            .csr_clk               (csr_clk                    ),
            .csr_rst_n             (csr_rst_n[1]               ),
            .ninit_done            (ninit_done                 ),
            .reset_status          (reset_status[1]            ),                 
            .pin_pcie_refclk0_p    (pin_pcie.refclk0_p         ),
            .pin_pcie_refclk1_p    (pin_pcie.refclk1_p         ),
            .pin_pcie_in_perst_n   (pin_pcie.in_perst_n        ),
            .pin_pcie_rx_p         (pin_pcie.rx_p[1]           ),
            .pin_pcie_rx_n         (pin_pcie.rx_n[1]           ),
            .pin_pcie_tx_p         (pin_pcie.tx_p[1]           ),   // Leave dummy outputs unconnected for unit simulation
            .pin_pcie_tx_n         (pin_pcie.tx_n[1]           ),   // Leave dummy outputs unconnected for unit simulation
            .axi_st_rx_if          (axi_st_rx_if_native[1]     ),
            .axi_st_tx_if          (axi_st_tx_committed[1]     ),
            .axi_st_txreq_if       (axi_st_txreq_if_native[1]  ),
            .axi_st_rxreq_if       (rxreq_in[1]                ),
            .csr_lite_if           (ss_csr_lite_if_bfm_dummy   ),  // CSR Interface is inactive.  RXREQ Interface is main CSR access method.
            .flr_req_if            (axi_st_flr_req[1]          ),
            .flr_rsp_if            (axi_st_flr_rsp[1]          ),
            .cpl_timeout_if        (axis_cpl_timeout[1]        ),
            .pcie_p2c_sideband     (pcie_p2c_sideband[1]       )
         );
      end
   end
endgenerate

endmodule : pcie_wrapper

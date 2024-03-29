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

import ofs_fim_cfg_pkg::*;
import ofs_fim_if_pkg::*;
import pcie_ss_axis_pkg::*;

module pcie_ss_top # (
   parameter PCIE_LANES = 16,
   parameter SOC_ATTACH = 0
)(

   input  logic                     fim_clk,
   input  logic                     fim_rst_n,
   input  logic                     csr_clk,
   input  logic                     csr_rst_n,
   input  logic                     ninit_done,
   output logic                     reset_status,

   input  logic                     p0_subsystem_cold_rst_n,  
   input  logic                     p0_subsystem_warm_rst_n,    
   output logic                     p0_subsystem_cold_rst_ack_n,
   output logic                     p0_subsystem_warm_rst_ack_n,

   // PCIe pins
   input  logic                     pin_pcie_refclk0_p,
   input  logic                     pin_pcie_refclk1_p,
   input  logic                     pin_pcie_in_perst_n,   // connected to HIP
   input  logic [PCIE_LANES-1:0]    pin_pcie_rx_p,
   input  logic [PCIE_LANES-1:0]    pin_pcie_rx_n,
   output logic [PCIE_LANES-1:0]    pin_pcie_tx_p,
   output logic [PCIE_LANES-1:0]    pin_pcie_tx_n,

   //TXREQ ports
   output logic                     p0_ss_app_st_txreq_tready,
   input  logic                     p0_app_ss_st_txreq_tvalid,
   input  logic [255:0]             p0_app_ss_st_txreq_tdata,
   input  logic                     p0_app_ss_st_txreq_tlast,

   //Ctrl Shadow ports
   output logic                     p0_ss_app_st_ctrlshadow_tvalid,
   output logic [39:0]              p0_ss_app_st_ctrlshadow_tdata,

   // Application to FPGA request port (MMIO/VDM)
   pcie_ss_axis_if.source           axi_st_rxreq_if,

   // FPGA to application request/response ports (DM req/rsp, MMIO rsp)
   pcie_ss_axis_if.source           axi_st_rx_if,
   pcie_ss_axis_if.sink             axi_st_tx_if,
   
   ofs_fim_axi_lite_if.slave        ss_csr_lite_if,
 
   // FLR interface
   output t_axis_pcie_flr           flr_req_if,
   input  t_axis_pcie_flr           flr_rsp_if,

   // Completion Timeout interface
   output t_axis_pcie_cplto         cpl_timeout_if,

   output t_sideband_from_pcie      pcie_p2c_sideband
);

import ofs_fim_pcie_pkg::*;

// Clock & Reset
logic                             coreclkout_hip;
logic                             reset_status_n;

assign reset_status = ~reset_status_n;

// PCIe bridge AXIS interface
ofs_fim_pcie_rxs_axis_if          axis_rx_st();
ofs_fim_pcie_txs_axis_if          axis_tx_st();


//PCIE SS signals
logic                             p0_ss_app_st_rx_tvalid;      
logic                             p0_app_ss_st_rx_tready;      
logic [511:0]                     p0_ss_app_st_rx_tdata;       
logic [63:0]                      p0_ss_app_st_rx_tkeep;      
logic                             p0_ss_app_st_rx_tlast;      
logic [2:0]                       p0_ss_app_st_rx_tuser_vendor;
logic [7:0]                       p0_ss_app_st_rx_tuser; 

logic                             p0_ss_app_st_rxreq_tvalid;      
logic                             p0_app_ss_st_rxreq_tready;       
logic  [511:0]                    p0_ss_app_st_rxreq_tdata;         
logic  [63:0]                     p0_ss_app_st_rxreq_tkeep;        
logic                             p0_ss_app_st_rxreq_tlast;        
logic  [2:0]                      p0_ss_app_st_rxreq_tuser_vendor;  

logic                             p0_app_ss_st_tx_tvalid;
logic                             p0_ss_app_st_tx_tready;     
logic [511:0]                     p0_app_ss_st_tx_tdata;     
logic [63:0]                      p0_app_ss_st_tx_tkeep;      
logic                             p0_app_ss_st_tx_tlast;      
logic [1:0]                       p0_app_ss_st_tx_tuser_vendor;
logic [7:0]                       p0_app_ss_st_tx_tuser;

//FLR Signals
logic                             p0_ss_app_st_flrrcvd_tvalid;
logic [19:0]                      p0_ss_app_st_flrrcvd_tdata;
logic                             p0_app_ss_st_flrcmpl_tvalid;
logic [19:0]                      p0_app_ss_st_flrcmpl_tdata;

//Completion Timeout
logic                             p0_ss_app_st_cplto_tvalid;
logic [29:0]                      p0_ss_app_st_cplto_tdata;

logic                             p0_ss_app_lite_csr_awready;
logic                             p0_ss_app_lite_csr_wready;
logic                             p0_ss_app_lite_csr_arready;
logic                             p0_ss_app_lite_csr_bvalid;
logic                             p0_ss_app_lite_csr_rvalid; 
logic                             p0_app_ss_lite_csr_awvalid;
logic [ofs_fim_cfg_pkg::PCIE_LITE_CSR_WIDTH-1:0] p0_app_ss_lite_csr_awaddr;
logic                             p0_app_ss_lite_csr_wvalid;
logic [31:0]                      p0_app_ss_lite_csr_wdata;
logic [3:0]                       p0_app_ss_lite_csr_wstrb;  
logic                             p0_app_ss_lite_csr_bready; 
logic [1:0]                       p0_ss_app_lite_csr_bresp;
logic                             p0_app_ss_lite_csr_arvalid;
logic [ofs_fim_cfg_pkg::PCIE_LITE_CSR_WIDTH-1:0] p0_app_ss_lite_csr_araddr; 
logic                             p0_app_ss_lite_csr_rready; 
logic [31:0]                      p0_ss_app_lite_csr_rdata;  
logic [1:0]                       p0_ss_app_lite_csr_rresp;  

logic                             p0_initiate_warmrst_req;
logic                             p1_initiate_warmrst_req;
logic                             p0_ss_app_dlup;
logic                             p0_ss_app_serr;


//---------------------------------------------------------------
//Connecting the RX ST Interface
assign axi_st_rx_if.tvalid            = p0_ss_app_st_rx_tvalid ;     
assign p0_app_ss_st_rx_tready         = axi_st_rx_if.tready    ;
assign axi_st_rx_if.tdata             = p0_ss_app_st_rx_tdata  ;     
assign axi_st_rx_if.tkeep             = p0_ss_app_st_rx_tkeep  ;     
assign axi_st_rx_if.tlast             = p0_ss_app_st_rx_tlast  ;     
assign axi_st_rx_if.tuser_vendor[2:0] = p0_ss_app_st_rx_tuser_vendor[2:0];
assign axi_st_rx_if.tuser_vendor[9:3] = p0_ss_app_st_rx_tuser; 

//Connecting the RX-REQ ST Interface
assign axi_st_rxreq_if.tvalid            = p0_ss_app_st_rxreq_tvalid ;     
assign p0_app_ss_st_rxreq_tready         = axi_st_rxreq_if.tready    ;
assign axi_st_rxreq_if.tdata             = p0_ss_app_st_rxreq_tdata  ;     
assign axi_st_rxreq_if.tkeep             = p0_ss_app_st_rxreq_tkeep  ;     
assign axi_st_rxreq_if.tlast             = p0_ss_app_st_rxreq_tlast  ;     
assign axi_st_rxreq_if.tuser_vendor[2:0] = p0_ss_app_st_rxreq_tuser_vendor;
assign axi_st_rxreq_if.tuser_vendor[9:3] = 7'h0;

//Connecting the TX ST Interface
assign p0_app_ss_st_tx_tvalid         = axi_st_tx_if.tvalid; 
assign axi_st_tx_if.tready            = p0_ss_app_st_tx_tready;
assign p0_app_ss_st_tx_tdata          = axi_st_tx_if.tdata;
assign p0_app_ss_st_tx_tkeep          = axi_st_tx_if.tkeep;
assign p0_app_ss_st_tx_tlast          = axi_st_tx_if.tlast;
assign p0_app_ss_st_tx_tuser_vendor   = axi_st_tx_if.tuser_vendor[1:0];
assign p0_app_ss_st_tx_tuser          = axi_st_tx_if.tuser_vendor[9:2];

//Connecting the FLR Interface
assign flr_req_if.tvalid = p0_ss_app_st_flrrcvd_tvalid;
assign flr_req_if.tdata  = p0_ss_app_st_flrrcvd_tdata;

assign p0_app_ss_st_flrcmpl_tvalid = flr_rsp_if.tvalid;
assign p0_app_ss_st_flrcmpl_tdata  = flr_rsp_if.tdata;


//Connecting the csr interface
assign ss_csr_lite_if.awready        = p0_ss_app_lite_csr_awready;
assign ss_csr_lite_if.wready         = p0_ss_app_lite_csr_wready;
assign ss_csr_lite_if.arready        = p0_ss_app_lite_csr_arready;
assign ss_csr_lite_if.bvalid         = p0_ss_app_lite_csr_bvalid;
assign ss_csr_lite_if.rvalid         = p0_ss_app_lite_csr_rvalid;
assign p0_app_ss_lite_csr_awvalid    = ss_csr_lite_if.awvalid; 
assign p0_app_ss_lite_csr_awaddr     = ss_csr_lite_if.awaddr;
assign p0_app_ss_lite_csr_wvalid     = ss_csr_lite_if.wvalid;
assign p0_app_ss_lite_csr_wdata      = ss_csr_lite_if.wdata;
assign p0_app_ss_lite_csr_wstrb      = ss_csr_lite_if.wstrb;
assign p0_app_ss_lite_csr_bready     = ss_csr_lite_if.bready;
assign ss_csr_lite_if.bresp          = p0_ss_app_lite_csr_bresp;
assign p0_app_ss_lite_csr_arvalid    = ss_csr_lite_if.arvalid;
assign p0_app_ss_lite_csr_araddr     = ss_csr_lite_if.araddr;
assign p0_app_ss_lite_csr_rready     = ss_csr_lite_if.rready;
assign ss_csr_lite_if.rdata          = p0_ss_app_lite_csr_rdata;
assign ss_csr_lite_if.rresp          = p0_ss_app_lite_csr_rresp;

//-------------------------------------
// Completion timeout interface 
//-------------------------------------
always_comb begin
   cpl_timeout_if.tvalid = p0_ss_app_st_cplto_tvalid;
   cpl_timeout_if.tdata  = p0_ss_app_st_cplto_tdata;
end


// PCIE stat signals clock crossing (fim_clk -> csr_clk)
localparam CSR_STAT_SYNC_WIDTH = 33;
fim_resync #(
   .SYNC_CHAIN_LENGTH(3),
   .WIDTH(CSR_STAT_SYNC_WIDTH),
   .INIT_VALUE(0),
   .NO_CUT(1)
) csr_resync (
   .clk   (csr_clk),
   .reset (~csr_rst_n),
   .d     ({p0_ss_app_dlup,32'b0}),
   .q     ({pcie_p2c_sideband.pcie_linkup, pcie_p2c_sideband.pcie_chk_rx_err_code})
);

//-------------------------------------
// PCIe SS
//-------------------------------------
generate if (SOC_ATTACH == 1) begin : soc_pcie
soc_pcie_ss pcie_ss(
.refclk0                        (pin_pcie_refclk0_p             ),               
.refclk1                        (pin_pcie_refclk1_p             ),
.pin_perst_n                    (pin_pcie_in_perst_n            ),
.coreclkout_hip_toapp           (coreclkout_hip                 ),
.p0_pin_perst_n                 (                               ), 
.p0_reset_status_n              (reset_status_n                 ),
.ninit_done                     (ninit_done                     ), 
.dummy_user_avmm_rst            (                               ), 
.p0_axi_st_clk                  (fim_clk                        ),
.p0_axi_lite_clk                (csr_clk                        ),  
.p0_axi_st_areset_n             (fim_rst_n                      ),       
.p0_axi_lite_areset_n           (csr_rst_n                      ),        
.p0_subsystem_cold_rst_n        (p0_subsystem_cold_rst_n        ),
.p0_subsystem_warm_rst_n        (p0_subsystem_warm_rst_n        ),
.p0_subsystem_cold_rst_ack_n    (p0_subsystem_cold_rst_ack_n    ),
.p0_subsystem_warm_rst_ack_n    (p0_subsystem_warm_rst_ack_n    ),
.p0_subsystem_rst_req           ('0                             ),
.p0_subsystem_rst_rdy           (                               ),      
.p0_initiate_warmrst_req        (p0_initiate_warmrst_req        ),
.p0_initiate_rst_req_rdy        (p0_initiate_warmrst_req        ),          
.p0_ss_app_st_rx_tvalid         (p0_ss_app_st_rx_tvalid         ),   
.p0_app_ss_st_rx_tready         (p0_app_ss_st_rx_tready         ),   
.p0_ss_app_st_rx_tdata          (p0_ss_app_st_rx_tdata          ), 
.p0_ss_app_st_rx_tkeep          (p0_ss_app_st_rx_tkeep          ),
.p0_ss_app_st_rx_tlast          (p0_ss_app_st_rx_tlast          ),
.p0_ss_app_st_rx_tuser          (p0_ss_app_st_rx_tuser          ),
.p0_ss_app_st_rx_tuser_vendor   (p0_ss_app_st_rx_tuser_vendor   ),
.p0_app_ss_st_tx_tvalid         (p0_app_ss_st_tx_tvalid         ),
.p0_ss_app_st_tx_tready         (p0_ss_app_st_tx_tready         ),
.p0_app_ss_st_tx_tdata          (p0_app_ss_st_tx_tdata          ),
.p0_app_ss_st_tx_tkeep          (p0_app_ss_st_tx_tkeep          ),
.p0_app_ss_st_tx_tlast          (p0_app_ss_st_tx_tlast          ),
.p0_app_ss_st_tx_tuser          (p0_app_ss_st_tx_tuser          ),
.p0_app_ss_st_tx_tuser_vendor   (p0_app_ss_st_tx_tuser_vendor   ),
.p0_ss_app_st_rxreq_tvalid      (p0_ss_app_st_rxreq_tvalid      ),  
.p0_app_ss_st_rxreq_tready      (p0_app_ss_st_rxreq_tready      ),  
.p0_ss_app_st_rxreq_tdata       (p0_ss_app_st_rxreq_tdata       ),  
.p0_ss_app_st_rxreq_tkeep       (p0_ss_app_st_rxreq_tkeep       ),  
.p0_ss_app_st_rxreq_tlast       (p0_ss_app_st_rxreq_tlast       ),  
.p0_ss_app_st_rxreq_tuser_vendor(p0_ss_app_st_rxreq_tuser_vendor),  
.p0_app_ss_st_txreq_tvalid      (p0_app_ss_st_txreq_tvalid      ),  
.p0_ss_app_st_txreq_tready      (p0_ss_app_st_txreq_tready      ),    
.p0_app_ss_st_txreq_tdata       (p0_app_ss_st_txreq_tdata       ), 
.p0_app_ss_st_txreq_tlast       (p0_app_ss_st_txreq_tlast       ),      
.p0_ss_app_st_flrrcvd_tvalid    (p0_ss_app_st_flrrcvd_tvalid    ),
.p0_ss_app_st_flrrcvd_tdata     (p0_ss_app_st_flrrcvd_tdata     ),
.p0_app_ss_st_flrcmpl_tvalid    (p0_app_ss_st_flrcmpl_tvalid    ),
.p0_app_ss_st_flrcmpl_tdata     (p0_app_ss_st_flrcmpl_tdata     ),
.p0_ss_app_st_ctrlshadow_tvalid (p0_ss_app_st_ctrlshadow_tvalid ),
.p0_ss_app_st_ctrlshadow_tdata  (p0_ss_app_st_ctrlshadow_tdata  ),
.p0_ss_app_st_txcrdt_tvalid     (                               ),
.p0_ss_app_st_txcrdt_tdata      (                               ),
.p0_ss_app_st_cplto_tvalid      (p0_ss_app_st_cplto_tvalid      ),    
.p0_ss_app_st_cplto_tdata       (p0_ss_app_st_cplto_tdata       ),
.p0_app_ss_lite_csr_awvalid     (p0_app_ss_lite_csr_awvalid     ),
.p0_ss_app_lite_csr_awready     (p0_ss_app_lite_csr_awready     ),
.p0_app_ss_lite_csr_awaddr      (p0_app_ss_lite_csr_awaddr      ),
.p0_app_ss_lite_csr_wvalid      (p0_app_ss_lite_csr_wvalid      ),
.p0_ss_app_lite_csr_wready      (p0_ss_app_lite_csr_wready      ),
.p0_app_ss_lite_csr_wdata       (p0_app_ss_lite_csr_wdata       ),
.p0_app_ss_lite_csr_wstrb       (p0_app_ss_lite_csr_wstrb       ),
.p0_ss_app_lite_csr_bvalid      (p0_ss_app_lite_csr_bvalid      ),
.p0_app_ss_lite_csr_bready      (p0_app_ss_lite_csr_bready      ),
.p0_ss_app_lite_csr_bresp       (p0_ss_app_lite_csr_bresp       ),
.p0_app_ss_lite_csr_arvalid     (p0_app_ss_lite_csr_arvalid     ),
.p0_ss_app_lite_csr_arready     (p0_ss_app_lite_csr_arready     ),
.p0_app_ss_lite_csr_araddr      (p0_app_ss_lite_csr_araddr      ),
.p0_ss_app_lite_csr_rvalid      (p0_ss_app_lite_csr_rvalid      ),
.p0_app_ss_lite_csr_rready      (p0_app_ss_lite_csr_rready      ),
.p0_ss_app_lite_csr_rdata       (p0_ss_app_lite_csr_rdata       ),
.p0_ss_app_lite_csr_rresp       (p0_ss_app_lite_csr_rresp       ),
.p0_ss_app_dlup                 (p0_ss_app_dlup                 ),
.tx_n_out0                      (pin_pcie_tx_n[0]               ),      
.tx_n_out1                      (pin_pcie_tx_n[1]               ),      
.tx_n_out2                      (pin_pcie_tx_n[2]               ),      
.tx_n_out3                      (pin_pcie_tx_n[3]               ),      
.tx_n_out4                      (pin_pcie_tx_n[4]               ),      
.tx_n_out5                      (pin_pcie_tx_n[5]               ),      
.tx_n_out6                      (pin_pcie_tx_n[6]               ),      
.tx_n_out7                      (pin_pcie_tx_n[7]               ),      
.tx_n_out8                      (pin_pcie_tx_n[8]               ),      
.tx_n_out9                      (pin_pcie_tx_n[9]               ),      
.tx_n_out10                     (pin_pcie_tx_n[10]              ),       
.tx_n_out11                     (pin_pcie_tx_n[11]              ),       
.tx_n_out12                     (pin_pcie_tx_n[12]              ),       
.tx_n_out13                     (pin_pcie_tx_n[13]              ),       
.tx_n_out14                     (pin_pcie_tx_n[14]              ),       
.tx_n_out15                     (pin_pcie_tx_n[15]              ),       
.tx_p_out0                      (pin_pcie_tx_p[0]               ),
.tx_p_out1                      (pin_pcie_tx_p[1]               ),
.tx_p_out2                      (pin_pcie_tx_p[2]               ),
.tx_p_out3                      (pin_pcie_tx_p[3]               ),
.tx_p_out4                      (pin_pcie_tx_p[4]               ),
.tx_p_out5                      (pin_pcie_tx_p[5]               ),
.tx_p_out6                      (pin_pcie_tx_p[6]               ),
.tx_p_out7                      (pin_pcie_tx_p[7]               ),
.tx_p_out8                      (pin_pcie_tx_p[8]               ),
.tx_p_out9                      (pin_pcie_tx_p[9]               ),
.tx_p_out10                     (pin_pcie_tx_p[10]              ), 
.tx_p_out11                     (pin_pcie_tx_p[11]              ), 
.tx_p_out12                     (pin_pcie_tx_p[12]              ), 
.tx_p_out13                     (pin_pcie_tx_p[13]              ), 
.tx_p_out14                     (pin_pcie_tx_p[14]              ), 
.tx_p_out15                     (pin_pcie_tx_p[15]              ), 
.rx_n_in0                       (pin_pcie_rx_n[0]               ),    
.rx_n_in1                       (pin_pcie_rx_n[1]               ),    
.rx_n_in2                       (pin_pcie_rx_n[2]               ),    
.rx_n_in3                       (pin_pcie_rx_n[3]               ),    
.rx_n_in4                       (pin_pcie_rx_n[4]               ),    
.rx_n_in5                       (pin_pcie_rx_n[5]               ),    
.rx_n_in6                       (pin_pcie_rx_n[6]               ),    
.rx_n_in7                       (pin_pcie_rx_n[7]               ),    
.rx_n_in8                       (pin_pcie_rx_n[8]               ),    
.rx_n_in9                       (pin_pcie_rx_n[9]               ),    
.rx_n_in10                      (pin_pcie_rx_n[10]              ),    
.rx_n_in11                      (pin_pcie_rx_n[11]              ),    
.rx_n_in12                      (pin_pcie_rx_n[12]              ),    
.rx_n_in13                      (pin_pcie_rx_n[13]              ),    
.rx_n_in14                      (pin_pcie_rx_n[14]              ),    
.rx_n_in15                      (pin_pcie_rx_n[15]              ),    
.rx_p_in0                       (pin_pcie_rx_p[0]               ),    
.rx_p_in1                       (pin_pcie_rx_p[1]               ),    
.rx_p_in2                       (pin_pcie_rx_p[2]               ),    
.rx_p_in3                       (pin_pcie_rx_p[3]               ),    
.rx_p_in4                       (pin_pcie_rx_p[4]               ),    
.rx_p_in5                       (pin_pcie_rx_p[5]               ),    
.rx_p_in6                       (pin_pcie_rx_p[6]               ),    
.rx_p_in7                       (pin_pcie_rx_p[7]               ),    
.rx_p_in8                       (pin_pcie_rx_p[8]               ),    
.rx_p_in9                       (pin_pcie_rx_p[9]               ),    
.rx_p_in10                      (pin_pcie_rx_p[10]              ),    
.rx_p_in11                      (pin_pcie_rx_p[11]              ),    
.rx_p_in12                      (pin_pcie_rx_p[12]              ),    
.rx_p_in13                      (pin_pcie_rx_p[13]              ),    
.rx_p_in14                      (pin_pcie_rx_p[14]              ),    
.rx_p_in15                      (pin_pcie_rx_p[15]              )
);
end : soc_pcie
else begin : host_pcie
pcie_ss pcie_ss(
.refclk0                        (pin_pcie_refclk0_p             ),               
.refclk1                        (pin_pcie_refclk1_p             ),
.pin_perst_n                    (pin_pcie_in_perst_n            ),
.coreclkout_hip_toapp           (coreclkout_hip                 ),
.p0_pin_perst_n                 (                               ), 
.p0_reset_status_n              (reset_status_n                 ),
.ninit_done                     (ninit_done                     ), 
.dummy_user_avmm_rst            (                               ), 
.p0_axi_st_clk                  (fim_clk                        ),
.p0_axi_lite_clk                (csr_clk                        ),  
.p0_axi_st_areset_n             (fim_rst_n                      ),       
.p0_axi_lite_areset_n           (csr_rst_n                      ),        
.p0_subsystem_cold_rst_n        (p0_subsystem_cold_rst_n        ),
.p0_subsystem_warm_rst_n        (p0_subsystem_warm_rst_n        ),
.p0_subsystem_cold_rst_ack_n    (p0_subsystem_cold_rst_ack_n    ),
.p0_subsystem_warm_rst_ack_n    (p0_subsystem_warm_rst_ack_n    ),
.p0_subsystem_rst_req           ('0                             ),
.p0_subsystem_rst_rdy           (                               ),      
.p0_initiate_warmrst_req        (p0_initiate_warmrst_req        ),
.p0_initiate_rst_req_rdy        (p0_initiate_warmrst_req        ),          
.p0_ss_app_st_rx_tvalid         (p0_ss_app_st_rx_tvalid         ),   
.p0_app_ss_st_rx_tready         (p0_app_ss_st_rx_tready         ),   
.p0_ss_app_st_rx_tdata          (p0_ss_app_st_rx_tdata          ), 
.p0_ss_app_st_rx_tkeep          (p0_ss_app_st_rx_tkeep          ),
.p0_ss_app_st_rx_tlast          (p0_ss_app_st_rx_tlast          ),
.p0_ss_app_st_rx_tuser          (p0_ss_app_st_rx_tuser          ),
.p0_ss_app_st_rx_tuser_vendor   (p0_ss_app_st_rx_tuser_vendor   ),
.p0_app_ss_st_tx_tvalid         (p0_app_ss_st_tx_tvalid         ),
.p0_ss_app_st_tx_tready         (p0_ss_app_st_tx_tready         ),
.p0_app_ss_st_tx_tdata          (p0_app_ss_st_tx_tdata          ),
.p0_app_ss_st_tx_tkeep          (p0_app_ss_st_tx_tkeep          ),
.p0_app_ss_st_tx_tlast          (p0_app_ss_st_tx_tlast          ),
.p0_app_ss_st_tx_tuser          (p0_app_ss_st_tx_tuser          ),
.p0_app_ss_st_tx_tuser_vendor   (p0_app_ss_st_tx_tuser_vendor   ),
.p0_ss_app_st_rxreq_tvalid      (p0_ss_app_st_rxreq_tvalid      ),   
.p0_app_ss_st_rxreq_tready      (p0_app_ss_st_rxreq_tready      ),   
.p0_ss_app_st_rxreq_tdata       (p0_ss_app_st_rxreq_tdata       ),   
.p0_ss_app_st_rxreq_tkeep       (p0_ss_app_st_rxreq_tkeep       ),   
.p0_ss_app_st_rxreq_tlast       (p0_ss_app_st_rxreq_tlast       ),   
.p0_ss_app_st_rxreq_tuser_vendor(p0_ss_app_st_rxreq_tuser_vendor),   
.p0_app_ss_st_txreq_tvalid      (p0_app_ss_st_txreq_tvalid      ),  
.p0_ss_app_st_txreq_tready      (p0_ss_app_st_txreq_tready      ),    
.p0_app_ss_st_txreq_tdata       (p0_app_ss_st_txreq_tdata       ), 
.p0_app_ss_st_txreq_tlast       (p0_app_ss_st_txreq_tlast       ),      
.p0_ss_app_st_flrrcvd_tvalid    (p0_ss_app_st_flrrcvd_tvalid    ),
.p0_ss_app_st_flrrcvd_tdata     (p0_ss_app_st_flrrcvd_tdata     ),
.p0_app_ss_st_flrcmpl_tvalid    (p0_app_ss_st_flrcmpl_tvalid    ),
.p0_app_ss_st_flrcmpl_tdata     (p0_app_ss_st_flrcmpl_tdata     ),
.p0_ss_app_st_ctrlshadow_tvalid (p0_ss_app_st_ctrlshadow_tvalid ),
.p0_ss_app_st_ctrlshadow_tdata  (p0_ss_app_st_ctrlshadow_tdata  ),
.p0_ss_app_st_txcrdt_tvalid     (                               ),
.p0_ss_app_st_txcrdt_tdata      (                               ),
.p0_ss_app_st_cplto_tvalid      (p0_ss_app_st_cplto_tvalid      ),    
.p0_ss_app_st_cplto_tdata       (p0_ss_app_st_cplto_tdata       ),
.p0_app_ss_lite_csr_awvalid     (p0_app_ss_lite_csr_awvalid     ),
.p0_ss_app_lite_csr_awready     (p0_ss_app_lite_csr_awready     ),
.p0_app_ss_lite_csr_awaddr      (p0_app_ss_lite_csr_awaddr      ),
.p0_app_ss_lite_csr_wvalid      (p0_app_ss_lite_csr_wvalid      ),
.p0_ss_app_lite_csr_wready      (p0_ss_app_lite_csr_wready      ),
.p0_app_ss_lite_csr_wdata       (p0_app_ss_lite_csr_wdata       ),
.p0_app_ss_lite_csr_wstrb       (p0_app_ss_lite_csr_wstrb       ),
.p0_ss_app_lite_csr_bvalid      (p0_ss_app_lite_csr_bvalid      ),
.p0_app_ss_lite_csr_bready      (p0_app_ss_lite_csr_bready      ),
.p0_ss_app_lite_csr_bresp       (p0_ss_app_lite_csr_bresp       ),
.p0_app_ss_lite_csr_arvalid     (p0_app_ss_lite_csr_arvalid     ),
.p0_ss_app_lite_csr_arready     (p0_ss_app_lite_csr_arready     ),
.p0_app_ss_lite_csr_araddr      (p0_app_ss_lite_csr_araddr      ),
.p0_ss_app_lite_csr_rvalid      (p0_ss_app_lite_csr_rvalid      ),
.p0_app_ss_lite_csr_rready      (p0_app_ss_lite_csr_rready      ),
.p0_ss_app_lite_csr_rdata       (p0_ss_app_lite_csr_rdata       ),
.p0_ss_app_lite_csr_rresp       (p0_ss_app_lite_csr_rresp       ),
.p0_ss_app_dlup                 (p0_ss_app_dlup                 ),

`ifdef OFS_FIM_IP_CFG_PCIE_SS_GEN5_2X8
// Hip doesn't support Gen5x8 config, hence Gen5_2x8 is used.
// Second PCIe port is tied off and not used in OFS example
.p1_axi_st_clk                  (fim_clk                        ),
.p1_axi_lite_clk                (csr_clk                        ),  
.p1_axi_st_areset_n             (fim_rst_n                      ),       
.p1_axi_lite_areset_n           (csr_rst_n                      ),        
.p1_subsystem_cold_rst_n        (p0_subsystem_cold_rst_n        ),
.p1_subsystem_warm_rst_n        (p0_subsystem_warm_rst_n        ),
.p1_subsystem_cold_rst_ack_n    (                               ),
.p1_subsystem_warm_rst_ack_n    (                               ),
.p1_subsystem_rst_req           ('0                             ),
.p1_subsystem_rst_rdy           (                               ),      
.p1_initiate_warmrst_req        (p1_initiate_warmrst_req        ),
.p1_initiate_rst_req_rdy        (p1_initiate_warmrst_req        ),          
.p1_ss_app_st_rx_tvalid         (                               ),   
.p1_app_ss_st_rx_tready         (1'b1                           ),   
.p1_ss_app_st_rx_tdata          (                               ), 
.p1_ss_app_st_rx_tkeep          (                               ),
.p1_ss_app_st_rx_tlast          (                               ),
.p1_ss_app_st_rx_tuser          (                               ),
.p1_ss_app_st_rx_tuser_vendor   (                               ),
.p1_app_ss_st_tx_tvalid         ('0                             ),
.p1_ss_app_st_tx_tready         (                               ),
.p1_app_ss_st_tx_tdata          ('0                             ),
.p1_app_ss_st_tx_tkeep          ('0                             ),
.p1_app_ss_st_tx_tlast          ('0                             ),
.p1_app_ss_st_tx_tuser          ('0                             ),
.p1_app_ss_st_tx_tuser_vendor   ('0                             ),
.p1_ss_app_st_rxreq_tvalid      (                               ),
.p1_app_ss_st_rxreq_tready      (1'b1                           ),
.p1_ss_app_st_rxreq_tdata       (                               ),
.p1_ss_app_st_rxreq_tkeep       (                               ),
.p1_ss_app_st_rxreq_tlast       (                               ),
.p1_ss_app_st_rxreq_tuser_vendor(                               ),
.p1_app_ss_st_txreq_tvalid      ('0                             ),  
.p1_ss_app_st_txreq_tready      (                               ),    
.p1_app_ss_st_txreq_tdata       ('0                             ), 
.p1_app_ss_st_txreq_tlast       ('0                             ),      
.p1_ss_app_st_flrrcvd_tvalid    (                               ),
.p1_ss_app_st_flrrcvd_tdata     (                               ),
.p1_app_ss_st_flrcmpl_tvalid    ('0                             ),
.p1_app_ss_st_flrcmpl_tdata     ('0                             ),
.p1_ss_app_st_txcrdt_tvalid     (                               ),
.p1_ss_app_st_txcrdt_tdata      (                               ),
//1p0_ss_app_st_cplto_tvalid      (p0_ss_app_st_cplto_tvalid      ),    
//1p0_ss_app_st_cplto_tdata       (p0_ss_app_st_cplto_tdata       ),
.p1_app_ss_lite_csr_awvalid     ('0                             ),
.p1_ss_app_lite_csr_awready     (                               ),
.p1_app_ss_lite_csr_awaddr      ('0                             ),
.p1_app_ss_lite_csr_wvalid      ('0                             ),
.p1_ss_app_lite_csr_wready      (                               ),
.p1_app_ss_lite_csr_wdata       ('0                             ),
.p1_app_ss_lite_csr_wstrb       ('0                             ),
.p1_ss_app_lite_csr_bvalid      (                               ),
.p1_app_ss_lite_csr_bready      ('0                             ),
.p1_ss_app_lite_csr_bresp       (                               ),
.p1_app_ss_lite_csr_arvalid     ('0                             ),
.p1_ss_app_lite_csr_arready     (                               ),
.p1_app_ss_lite_csr_araddr      ('0                             ),
.p1_ss_app_lite_csr_rvalid      (                               ),
.p1_app_ss_lite_csr_rready      ('0                             ),
.p1_ss_app_lite_csr_rdata       (                               ),
.p1_ss_app_lite_csr_rresp       (                               ),
.p1_ss_app_dlup                 (                               ),
`endif

.tx_n_out0                      (pin_pcie_tx_n[0]               ),      
.tx_n_out1                      (pin_pcie_tx_n[1]               ),      
.tx_n_out2                      (pin_pcie_tx_n[2]               ),      
.tx_n_out3                      (pin_pcie_tx_n[3]               ),      
.tx_n_out4                      (pin_pcie_tx_n[4]               ),      
.tx_n_out5                      (pin_pcie_tx_n[5]               ),      
.tx_n_out6                      (pin_pcie_tx_n[6]               ),      
.tx_n_out7                      (pin_pcie_tx_n[7]               ),      
.tx_n_out8                      (pin_pcie_tx_n[8]               ),      
.tx_n_out9                      (pin_pcie_tx_n[9]               ),      
.tx_n_out10                     (pin_pcie_tx_n[10]              ),       
.tx_n_out11                     (pin_pcie_tx_n[11]              ),       
.tx_n_out12                     (pin_pcie_tx_n[12]              ),       
.tx_n_out13                     (pin_pcie_tx_n[13]              ),       
.tx_n_out14                     (pin_pcie_tx_n[14]              ),       
.tx_n_out15                     (pin_pcie_tx_n[15]              ),       
.tx_p_out0                      (pin_pcie_tx_p[0]               ),
.tx_p_out1                      (pin_pcie_tx_p[1]               ),
.tx_p_out2                      (pin_pcie_tx_p[2]               ),
.tx_p_out3                      (pin_pcie_tx_p[3]               ),
.tx_p_out4                      (pin_pcie_tx_p[4]               ),
.tx_p_out5                      (pin_pcie_tx_p[5]               ),
.tx_p_out6                      (pin_pcie_tx_p[6]               ),
.tx_p_out7                      (pin_pcie_tx_p[7]               ),
.tx_p_out8                      (pin_pcie_tx_p[8]               ),
.tx_p_out9                      (pin_pcie_tx_p[9]               ),
.tx_p_out10                     (pin_pcie_tx_p[10]              ), 
.tx_p_out11                     (pin_pcie_tx_p[11]              ), 
.tx_p_out12                     (pin_pcie_tx_p[12]              ), 
.tx_p_out13                     (pin_pcie_tx_p[13]              ), 
.tx_p_out14                     (pin_pcie_tx_p[14]              ), 
.tx_p_out15                     (pin_pcie_tx_p[15]              ), 
.rx_n_in0                       (pin_pcie_rx_n[0]               ),    
.rx_n_in1                       (pin_pcie_rx_n[1]               ),    
.rx_n_in2                       (pin_pcie_rx_n[2]               ),    
.rx_n_in3                       (pin_pcie_rx_n[3]               ),    
.rx_n_in4                       (pin_pcie_rx_n[4]               ),    
.rx_n_in5                       (pin_pcie_rx_n[5]               ),    
.rx_n_in6                       (pin_pcie_rx_n[6]               ),    
.rx_n_in7                       (pin_pcie_rx_n[7]               ),    
.rx_n_in8                       (pin_pcie_rx_n[8]               ),    
.rx_n_in9                       (pin_pcie_rx_n[9]               ),    
.rx_n_in10                      (pin_pcie_rx_n[10]              ),    
.rx_n_in11                      (pin_pcie_rx_n[11]              ),    
.rx_n_in12                      (pin_pcie_rx_n[12]              ),    
.rx_n_in13                      (pin_pcie_rx_n[13]              ),    
.rx_n_in14                      (pin_pcie_rx_n[14]              ),    
.rx_n_in15                      (pin_pcie_rx_n[15]              ),    
.rx_p_in0                       (pin_pcie_rx_p[0]               ),    
.rx_p_in1                       (pin_pcie_rx_p[1]               ),    
.rx_p_in2                       (pin_pcie_rx_p[2]               ),    
.rx_p_in3                       (pin_pcie_rx_p[3]               ),    
.rx_p_in4                       (pin_pcie_rx_p[4]               ),    
.rx_p_in5                       (pin_pcie_rx_p[5]               ),    
.rx_p_in6                       (pin_pcie_rx_p[6]               ),    
.rx_p_in7                       (pin_pcie_rx_p[7]               ),    
.rx_p_in8                       (pin_pcie_rx_p[8]               ),    
.rx_p_in9                       (pin_pcie_rx_p[9]               ),    
.rx_p_in10                      (pin_pcie_rx_p[10]              ),    
.rx_p_in11                      (pin_pcie_rx_p[11]              ),    
.rx_p_in12                      (pin_pcie_rx_p[12]              ),    
.rx_p_in13                      (pin_pcie_rx_p[13]              ),    
.rx_p_in14                      (pin_pcie_rx_p[14]              ),    
.rx_p_in15                      (pin_pcie_rx_p[15]              )
);
end : host_pcie
endgenerate
endmodule

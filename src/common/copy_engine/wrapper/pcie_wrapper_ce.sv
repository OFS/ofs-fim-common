// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//   Platform top level module
//
//-----------------------------------------------------------------------------

`include "fpga_defines.vh"
import ofs_fim_if_pkg::*;
import ofs_fim_pcie_pkg::*;
import ofs_csr_pkg::*;
import ofs_fim_cfg_pkg::*;
import pcie_ss_axis_pkg::*;
//-----------------------------------------------------------------------------
// Module ports
//-----------------------------------------------------------------------------

module pcie_wrapper_ce#(
    parameter bit [11:0] CE_FEAT_ID                     = 12'h1               , //DFH Feature ID
    parameter bit [3:0]  CE_FEAT_VER                    = 4'h1                , //DFH Feature Version
    parameter bit [23:0] CE_NEXT_DFH_OFFSET             = 24'h1000            , //DFH Next DFH Offset
    parameter bit        CE_END_OF_LIST                 = 1'b1                , //DFH End of list
    parameter            CE_BUS_ADDR_WIDTH              = 32                  , //Axi Stream & Ace lite addr width 
    parameter            CE_AXI4MM_ADDR_WIDTH           = 21                  , //Axi4MM Addrwidth 
    parameter            CE_BUS_DATA_WIDTH              = 512                 , //Axi Stream & Ace Lite data width
    parameter            CE_BUS_USER_WIDTH              = 10                  , //Axi Stream tuser width
    parameter            CE_AXI4MM_DATA_WIDTH           = 32                  , //AXI4MM Data width
    parameter            CE_BUS_STRB_WIDTH              = CE_BUS_DATA_WIDTH>>3, //Axi Stream tkeep width & Ace Lite wstrb width
    parameter            CE_MMIO_RSP_FIFO_DEPTH         = 4                   , //MMIO Response FIFO depth
    parameter            CE_HST2HPS_FIFO_DEPTH          = 5                   , //Completion FIFO depth(Axi Stream to Ace Lite conversion FIFO)
    parameter            CE_PF_ID                       = 4                   , //PF ID of Cpld Packet to host
    parameter            CE_VF_ID                       = 0                   , //VF ID of Cpld Packet to host
    parameter            CE_VF_ACTIVE                   = 0                   , //VF_ACTIVE of Cpld Packet to host
    parameter            PCIE_LANES                     = 16                  ,
    parameter            MM_ADDR_WIDTH                  = 19                  ,
    parameter            MM_DATA_WIDTH                  = 64                  ,
    parameter bit [11:0] FEAT_ID                        = 12'h0               ,
    parameter bit [3:0]  FEAT_VER                       = 4'h0                ,
    parameter bit [23:0] NEXT_DFH_OFFSET                = 24'h1000            ,
    parameter bit        END_OF_LIST                    = 1'b0)
   (



                          //input                                     SYS_RefClk                        ,// System Reference Clock (100MHz)
                          //input                                     PCIE_RefClk                       ,// PCIe clock
                          //input                                     PCIE_Rst_n                        ,// PCIe reset
                          //input  [PCIE_LANES-1:0] PCIE_Rx                           ,// PCIe RX interface
                          //output [PCIE_LANES-1:0] PCIE_Tx                           ,// PCIe TX interface 
                          //
                          //input                                     ninit_done                        , //input to pcie wrapper
                          //input                                     npor                              , //input to pcie wrapper
                          //input                                     pcie_reset_status                 , //input to pcie wrapper
                          //ofs_fim_axi_lite_if.slave                 csr_lite_if                       , //axi lite slave interface
                          //ofs_fim_irq_axis_if.master                irq_if                            , //axi-st master interface
                          //input                                     c2p_sideband                      , //input to pcie wrapper

                          //output                                    hps2host_hps_rdy_gpio             , 
                          //output [1:0]                              hps2host_ssbl_vfy_gpio            ,
                          //output [1:0]                              hps2host_kernel_vfy_gpio          ,
                          //input                                     host2hps_gpio                     , 

                          //ofs_fim_ace_lite_if.master                ace_lite_tx_if
                        input  logic                              fim_clk                           ,
                        input  logic                              fim_rst_n                         ,

                        input  logic                              csr_clk                           ,
                        input  logic                              csr_rst_n                         ,

                        input  logic                              ninit_done                        ,
                        output logic                              reset_status                      ,

                        input  logic                              p0_subsystem_cold_rst_n           ,    
                        input  logic                              p0_subsystem_warm_rst_n           ,    
                        output logic                              p0_subsystem_cold_rst_ack_n       ,
                        output logic                              p0_subsystem_warm_rst_ack_n       ,
                        
                        // PCIe pins
                        input  logic                              pin_pcie_refclk0_p                ,
                        input  logic                              pin_pcie_refclk1_p                ,
                        input  logic                              pin_pcie_in_perst_n               ,   // connected to HIP
                        input  logic [PCIE_LANES-1:0]             pin_pcie_rx_p                     ,
                        input  logic [PCIE_LANES-1:0]             pin_pcie_rx_n                     ,
                        output logic [PCIE_LANES-1:0]             pin_pcie_tx_p                     ,
                        output logic [PCIE_LANES-1:0]             pin_pcie_tx_n                     ,

                        // AXI-S data interfaces
                        //pcie_ss_axis_if.source                    axi_st_rx_if                      ,
                        //pcie_ss_axis_if.sink                      axi_st_tx_if                      ,

                        // AXI4-lite CSR interface
                        ofs_fim_axi_lite_if.slave                 csr_lite_if                       ,

                        // FLR 
                        output t_axis_pcie_flr                    axi_st_flr_req                    ,
                        input  t_axis_pcie_flr                    axi_st_flr_rsp                    ,
                        //output                                    hps2host_hps_rdy_gpio             , 
                        //output [1:0]                              hps2host_ssbl_vfy_gpio            ,
                        //output [1:0]                              hps2host_kernel_vfy_gpio          ,
                        //input                                     host2hps_gpio                     , 
                        //hps_ce_gpio_if.sink                           gpio_if                           ,
                        ofs_fim_ace_lite_if.master                ace_lite_tx_if,
                       // ofs_fim_axi_lite_if.slave              axi_lite_rx_if
                        ofs_fim_axi_mmio_if.slave                       axi4mm_rx_if
);

//-----------------------------------------------------------------------------
// Internal signals
//-----------------------------------------------------------------------------

//logic pcie_reset_status;
//	 ofs_fim_axi_lite_if.slave                 csr_lite_if , //axi lite slave interface
//	 ofs_fim_irq_axis_if.master                irq_if  , //axi-st master interface

// AXIS PCIe Subsystem Interface
pcie_ss_axis_if pcie_ss_axis_rx_if(.clk (fim_clk), .rst_n(fim_rst_n));
pcie_ss_axis_if pcie_ss_axis_tx_if(.clk (fim_clk), .rst_n(fim_rst_n));

//pcie_ss_axis_if.source pcie_tx_if;
//pcie_ss_axis_if.sink   pcie_rx_if;

pcie_ss_axis_if  axis_tx_if(.clk (fim_clk), .rst_n(fim_rst_n));
pcie_ss_axis_if  axis_rx_if(.clk (fim_clk), .rst_n(fim_rst_n));
ofs_fim_axi_lite_if ss_init_lite_if();

assign ss_init_lite_if.wready=1'b0;
assign ss_init_lite_if.awready=1'b0;
assign ss_init_lite_if.arready=1'b0;


assign ss_init_lite_if.bvalid=1'b0;
assign ss_init_lite_if.rvalid=1'b0;

assign ss_init_lite_if.rresp='h0;
assign ss_init_lite_if.rdata='h0;
assign ss_init_lite_if.bresp='h0;

//pcie_ss_axis_if.source pcie_tx_if;
//pcie_ss_axis_if.sink   pcie_rx_if;


//assign axis_tx_if.clk         =pcie_ss_axis_rx_if.sink.clk;
//assign axis_tx_if.rst_n       =pcie_ss_axis_rx_if.sink.rst_n;
assign pcie_ss_axis_tx_if.tdata		=axis_tx_if.tdata  ;
assign pcie_ss_axis_tx_if.tvalid	=axis_tx_if.tvalid ;
assign pcie_ss_axis_tx_if.tkeep		=axis_tx_if.tkeep  ;       
assign pcie_ss_axis_tx_if.tuser_vendor	=axis_tx_if.tuser_vendor ;      
assign pcie_ss_axis_tx_if.tlast		=axis_tx_if.tlast;
assign axis_tx_if.tready                =pcie_ss_axis_tx_if.tready;
//
//
//assign axis_rx_if.clk         =pcie_ss_axis_tx_if.source.clk;
//assign axis_rx_if.rst_n       =pcie_ss_axis_tx_if.source.rst_n;
assign axis_rx_if.tdata       =pcie_ss_axis_rx_if.tdata;
assign axis_rx_if.tvalid      =pcie_ss_axis_rx_if.tvalid;
assign axis_rx_if.tkeep       =pcie_ss_axis_rx_if.tkeep;
assign axis_rx_if.tuser_vendor       =pcie_ss_axis_rx_if.tuser_vendor;
assign axis_rx_if.tlast       =pcie_ss_axis_rx_if.tlast;
assign pcie_ss_axis_rx_if.tready =axis_rx_if.tready;
//-----------------------------------------------------------------------------
// Modules instances
//-----------------------------------------------------------------------------


//*******************************
// PCIe Subsystem
//*******************************

 pcie_wrapper #(  
     .PCIE_LANES       (PCIE_LANES      ),
     .MM_ADDR_WIDTH    (MM_ADDR_WIDTH   ),
     .MM_DATA_WIDTH    (MM_DATA_WIDTH   ),
     .FEAT_ID          (FEAT_ID         ),
     .FEAT_VER         (FEAT_VER        ),
     .NEXT_DFH_OFFSET  (NEXT_DFH_OFFSET ),
     .END_OF_LIST      (END_OF_LIST     )  
) pcie_wrapper (
   .fim_clk                      (fim_clk                       ),
   .fim_rst_n                    (fim_rst_n                     ),
   .csr_clk                      (csr_clk                       ),
   .csr_rst_n                    (csr_rst_n                     ),
   .ninit_done                   (ninit_done                    ),
   .p0_subsystem_cold_rst_n      (p0_subsystem_cold_rst_n       ),     
   .p0_subsystem_warm_rst_n      (p0_subsystem_warm_rst_n       ),
   .p0_subsystem_cold_rst_ack_n  (p0_subsystem_cold_rst_ack_n   ),
   .p0_subsystem_warm_rst_ack_n  (p0_subsystem_warm_rst_ack_n   ),
   .reset_status                 (reset_status                  ),   
   .pin_pcie_refclk0_p           (pin_pcie_refclk0_p            ),
   .pin_pcie_refclk1_p           (pin_pcie_refclk1_p            ),
   .pin_pcie_in_perst_n          (pin_pcie_in_perst_n           ),   // connected to HIP
   .pin_pcie_rx_p                (pin_pcie_rx_p                 ),
   .pin_pcie_rx_n                (pin_pcie_rx_n                 ),
   .pin_pcie_tx_p                (pin_pcie_tx_p                 ),                
   .pin_pcie_tx_n                (pin_pcie_tx_n                 ),                
   .axi_st_rx_if                 (pcie_ss_axis_rx_if.source     ),
   .axi_st_tx_if                 (pcie_ss_axis_tx_if.sink       ), 
   .csr_lite_if                  (csr_lite_if                   ),
   .ss_init_lite_if              (ss_init_lite_if               ),
   .axi_st_flr_req               (axi_st_flr_req                ),
   .axi_st_flr_rsp               (axi_st_flr_rsp                )
);
 // pcie_wrapper 
 // pcie_wrapper(
 //       .fim_clk            (SYS_RefClk                 ),
 //       .fim_rst_n          (PCIE_Rst_n                 ),
 //       .ninit_done         (ninit_done                 ),
 //       .npor               (npor                       ),
 //       .reset_status       (pcie_reset_status          ),                 
 //       .pin_pcie_ref_clk_p (PCIE_RefClk                ),
 //       .pin_pcie_in_perst_n(PCIE_Rst_n                 ),   // connected to HIP
 //       .pin_pcie_rx_p      (PCIE_Rx                    ),
 //       .pin_pcie_tx_p      (PCIE_Tx                    ),                
 //       .axi_st_rx_if       (pcie_ss_axis_rx_if.source         ),
 //       .axi_st_tx_if       (pcie_ss_axis_tx_if.sink         ),

 //       //.axi_st_rx_if       (pcie_rx_if         ),
 //       //.axi_st_tx_if       (pcie_tx_if         ),

 //       .csr_lite_if        (csr_lite_if                ), 
 //       .irq_if             (irq_if                     ), 
 //       .pcie_p2c_sideband  (                           ), 
 //       .pcie_c2p_sideband  (c2p_sideband               )
 //       );

//*******************************
// Copy Engine
//*******************************

/*ce_top #(
               .CE_FEAT_ID               (CE_FEAT_ID             ),   
               .CE_FEAT_VER              (CE_FEAT_VER            ),
               .CE_NEXT_DFH_OFFSET       (CE_NEXT_DFH_OFFSET     ),
               .CE_END_OF_LIST           (CE_END_OF_LIST         ),
               .CE_BUS_ADDR_WIDTH        (CE_BUS_ADDR_WIDTH      ),
               .CE_BUS_DATA_WIDTH        (CE_BUS_DATA_WIDTH      ),
               .CE_BUS_USER_WIDTH        (CE_BUS_USER_WIDTH      ),
               .CE_MMIO_RSP_FIFO_DEPTH   (CE_MMIO_RSP_FIFO_DEPTH ),
               .CE_HST2HPS_FIFO_DEPTH    (CE_HST2HPS_FIFO_DEPTH  ),
               .CE_RDY_LOW_THRESHOLD     (CE_RDY_LOW_THRESHOLD   ),
               .CE_PF_ID                 (CE_PF_ID               ),
               .CE_VF_ID                 (CE_VF_ID               ),
               .CE_VF_ACTIVE             (CE_VF_ACTIVE           ))
//ce_inst(
//      .clk                       (SYS_RefClk                 ),
//      .SoftReset                 (~PCIE_Rst_n                 ),
//      .axis_tx_if                (axis_tx_if.source          ),
//      .axis_rx_if                (axis_rx_if.sink            ),
//      .ace_lite_tx_if            (ace_lite_tx_if             ),
//      .hps2host_hps_rdy_gpio     (hps2host_hps_rdy_gpio      ),
//      .hps2host_ssbl_vfy_gpio    (hps2host_ssbl_vfy_gpio     ),
//      .hps2host_kernel_vfy_gpio  (hps2host_kernel_vfy_gpio   ),
//      .host2hps_gpio             (host2hps_gpio              )
//
//     );
ce_inst(
      .clk                       (fim_clk                    ),
      .SoftReset                 (~fim_rst_n                 ),
      .axis_tx_if                (axis_tx_if.source          ),
      .axis_rx_if                (axis_rx_if.sink            ),
      .ace_lite_tx_if            (ace_lite_tx_if             )
      //.hps_gpio_if                (gpio_if                    )
     );*/

ce_top #(
    .CE_PF_ID               (CE_PF_ID    ),
    .CE_VF_ID               (CE_VF_ID    ),
    .CE_VF_ACTIVE           (CE_VF_ACTIVE),
    .CE_FEAT_ID             (12'h1    ),    
    .CE_FEAT_VER            (4'h1     ),                
    .CE_NEXT_DFH_OFFSET     (24'h1000 ),
    .CE_END_OF_LIST         (1'b1     ),
    .CE_BUS_ADDR_WIDTH      (32       ),
    .CE_AXI4MM_ADDR_WIDTH   (21       ),
    .CE_AXI4MM_DATA_WIDTH   (32       ),
    .CE_BUS_DATA_WIDTH      (512      ),
    .CE_BUS_USER_WIDTH      (10       ),
    .CE_MMIO_RSP_FIFO_DEPTH (4        ),//
    .CE_HST2HPS_FIFO_DEPTH  (8        )      
 
) ce_top_inst (
  .clk                      (fim_clk             ),
  .rst                      (~fim_rst_n          ),
  .axis_rx_if               (axis_rx_if.sink     ),    // Mux to AFU   PF4
  .axis_tx_if               (axis_tx_if.source   ),    // AFU to MUX   PF4
  .ace_lite_tx_if           (ace_lite_tx_if      ),
  .axi4mm_rx_if             (axi4mm_rx_if      ) 

);


endmodule


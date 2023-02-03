// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Engineer     : Liaqat                      
// Create Date  : Nov 2020
// Module Name  : ce_top.sv
// Project      : IOFS
// -----------------------------------------------------------------------------
//
// Description: 
// The Copy Engine is responsible for copying the firmware image from Host DDR to HPS-DDR once
// the descriptors within the copy engine are programmed by the host.
// Copy Engine is a part of AFU block.
// ***************************************************************************
module ce_top #(
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
   parameter            CE_HST2HPS_FIFO_DEPTH          = 5                   , //Completion FIFO depth; Axi Stream to Ace Lite conversion FIFO
   parameter            CE_PF_ID                       = 4                   , //PF ID of Cpld Packet to host                                                       
   parameter            CE_VF_ID                       = 0                   , //VF ID of Cpld Packet to host
   parameter            CE_VF_ACTIVE                   = 0                    //VF_ACTIVE of Cpld Packet to host
                                                                                                                  
)( 
   // global signals
   input   logic                           clk                      ,
   input   logic                           rst                      ,
   input   logic                           h2f_reset                ,
   
   // AXI-ST Tx interface signals
   pcie_ss_axis_if.source                axis_tx_if                ,
                                                                                                
   // AXI-ST Rx interface signals

   pcie_ss_axis_if.sink                   axis_rx_if                ,

   // ACE Lite Tx interface signals
   ofs_fim_ace_lite_if.master             ace_lite_tx_if            ,

   // AXI4-MM Rx interface signals
   ofs_fim_axi_mmio_if.slave              axi4mm_rx_if            


);
//--------------------------------------------------------
// Local Parameters
//--------------------------------------------------------
//localparam FIFO_CNT_WIDTH = CE_HST2HPS_FIFO_DEPTH; 
localparam TAG_WIDTH              = 10                              ;                    // Tag width 
localparam REQ_ID_WIDTH           = 16                              ;                    // Requester ID width PU mode
localparam CSR_ADDR_WIDTH         = 16                              ;                    // CSR Addr Width
localparam CSR_DATA_WIDTH         = 64                              ;                    // CSR Data Width
localparam CE_MMIO_RSP_FIFO_THRHLD = (2**CE_MMIO_RSP_FIFO_DEPTH) - 4;
localparam CE_HST2HPS_FIFO_THRSHLD = (2**CE_HST2HPS_FIFO_DEPTH) - 4 ;

//--------------------------------------------------------
// Declare Variables 
//--------------------------------------------------------
wire                              csr_mrdstart                  ;
wire                              axisttx_csr_dmaerr            ;
wire                              csr_axisttx_rspvalid          ;
wire                              csr_hpsrdy                    ;
wire                              axistrx_csr_wen               ;
wire                              axistrx_csr_ren               ;
wire                              axistrx_cpldfifo_wen          ;
wire                              axistrx_fc                    ;
wire                              cpldfifo_axistrx_full         ;
wire                              cpldfifo_axistrx_almostfull   ;
wire                              acelitetx_cpldfifo_ren        ;
wire                              cpldfifo_acelitetx_empty      ;
wire                              cpldfifo_notempty             ;
wire                              cpldfifo_csr_fifoerr          ;
wire                              cpldfifo_csr_overflow         ;
wire                              cpldfifo_csr_underflow        ;
wire                              axisttx_csr_mmiofifooverflow  ;    
wire                              axisttx_csr_mmiofifounderflow ;    
wire                              mmiorspfifo_axistrx_almostfull;                   
wire                              fifo_err_flag                 ;                   

wire  [576:0]                     cpldfifo_acelitetx_rddata     ;
wire  [CE_HST2HPS_FIFO_DEPTH-1:0] cpldfifo_occupancy            ;
wire  [2:0  ]                     axistrx_csr_cplstatus         ;
wire  [8:0  ]                     csr_axisttx_rspattr           ;
wire  [2:0  ]                     csr_axisttx_tc                ;
wire  [10:0 ]                     csr_axisttx_datareqlimit      ;
wire  [3:0 ]                      csr_axisttx_datareqlimit_log2 ;
wire  [8:0  ]                     axistrx_csr_rspatrr           ;
wire  [2:0  ]                     axistrx_csr_tc                ;
wire  [576:0]                     axistrx_cpldfifo_wrdata       ;
wire  [1:0  ]                     acelitetx_bresp               ;
wire                              acelitetx_bresperrpulse       ;
wire                              acelitetx_csr_dmadone         ;
wire                              axistrx_cplerr                ;
wire                              acelitetx_axisttx_req_en      ;


wire                                    ce_softreset            ;
wire                                    ce_corereset            ;
wire                                    axi4mmrx_csr_ren        ; 
wire                                    axi4mmrx_csr_wen        ;
wire  [(CE_AXI4MM_DATA_WIDTH>>3)-1:0]   axi4mmrx_csr_wstrb      ; 
wire  [CSR_ADDR_WIDTH-1:0           ]   csr_axisttx_rspaddr     ;
wire  [CSR_DATA_WIDTH-1:0           ]   csr_axisttx_hostaddr    ;
wire  [CSR_DATA_WIDTH-1:0           ]   csr_imgxfrsize          ;
wire  [TAG_WIDTH-1:0                ]   csr_axisttx_rsptag      ;
wire  [REQ_ID_WIDTH-1:0             ]   axistrx_csr_reqid       ;
wire  [REQ_ID_WIDTH-1:0             ]   csr_axisttx_reqid       ;
wire  [CSR_DATA_WIDTH-1:0           ]   csr_axisttx_rspdata     ;
wire  [(CSR_DATA_WIDTH>>3)-1:0      ]   csr_axisttx_tkeep       ;
wire  [CE_AXI4MM_DATA_WIDTH-1:0     ]   csr_axi4mmrx_rdata      ;
wire  [CSR_DATA_WIDTH-1:0           ]   csr_acelitetx_hpsaddr   ;
wire  [CSR_ADDR_WIDTH-1:0           ]   axistrx_csr_alignaddr   ;
wire  [CSR_ADDR_WIDTH-1:0           ]   axistrx_csr_unalignaddr ;
wire  [TAG_WIDTH-1:0                ]   axistrx_csr_rsptag      ;
wire  [CSR_DATA_WIDTH-1:0           ]   axistrx_csr_wrdata      ;

wire  [CE_AXI4MM_DATA_WIDTH-1:0     ]   axi4mmrx_csr_wdata      ; 
wire  [CSR_ADDR_WIDTH-1:0           ]   axi4mmrx_csr_raddr      ; 
wire  [CSR_ADDR_WIDTH-1:0           ]   axi4mmrx_csr_waddr      ; 


//wire                              MmioRspFiFo_AxistRx_full      ;                   

assign cpldfifo_acelitetx_empty =!cpldfifo_notempty ;
assign ce_corereset             =rst| ce_softreset  ;

assign cpldfifo_csr_overflow    = cpldfifo_csr_fifoerr& cpldfifo_axistrx_full;
assign cpldfifo_csr_underflow   = cpldfifo_csr_fifoerr& !cpldfifo_notempty   ; 
                                                                                 
ce_csr #(  
         .CE_FEAT_ID            (CE_FEAT_ID             ), 
         .CE_FEAT_VER           (CE_FEAT_VER            ), 
         .CE_NEXT_DFH_OFFSET    (CE_NEXT_DFH_OFFSET     ), 
         .CE_END_OF_LIST        (CE_END_OF_LIST         ), 
         .CE_AXI4MM_DATA_WIDTH  (CE_AXI4MM_DATA_WIDTH   ),
         .CE_BUS_STRB_WIDTH     (CE_AXI4MM_DATA_WIDTH>>3), 
         .CSR_ADDR_WIDTH        (CSR_ADDR_WIDTH         ),
         .CSR_DATA_WIDTH        (CSR_DATA_WIDTH         ),
         .TAG_WIDTH             (TAG_WIDTH              ),
         .REQ_ID_WIDTH          (REQ_ID_WIDTH           ))

ce_csr_inst(

   .clk                          (clk                          ),     
   .rst                          (rst                          ), 
   .ce_corereset                 (ce_corereset                 ), 
   .csr_axisttx_hostaddr         (csr_axisttx_hostaddr         ), 
   .csr_imgxfrsize               (csr_imgxfrsize               ), 
   .ce_softreset                 (ce_softreset                 ), 
   .csr_mrdstart                 (csr_mrdstart                 ), 
   .csr_axisttx_rspaddr          (csr_axisttx_rspaddr          ), 
   .csr_axisttx_rsptag           (csr_axisttx_rsptag           ), 
   .csr_axisttx_tkeep            (csr_axisttx_tkeep            ), 
   .csr_axisttx_length           (csr_axisttx_length           ),  
   .csr_axisttx_rspattr          (csr_axisttx_rspattr          ),            
   .csr_axisttx_tc               (csr_axisttx_tc               ),            
   .csr_axisttx_datareqlimit     (csr_axisttx_datareqlimit     ),            
   .csr_axisttx_datareqlimit_log2(csr_axisttx_datareqlimit_log2),            
   .fifo_err_flag                (fifo_err_flag                ),            
   .csr_axisttx_rspdata          (csr_axisttx_rspdata          ), 
   .csr_axisttx_rspvalid         (csr_axisttx_rspvalid         ),  
   .axisttx_csr_dmaerr           (axisttx_csr_dmaerr           ), 
   .acelitetx_bresp              (acelitetx_bresp              ),
   .cpldfifo_csr_overflow        (cpldfifo_csr_overflow        ),
   .cpldfifo_csr_underflow       (cpldfifo_csr_underflow       ),
   .axisttx_csr_mmiofifooverflow (axisttx_csr_mmiofifooverflow ),    
   .axisttx_csr_mmiofifounderflow(axisttx_csr_mmiofifounderflow),    
   .csr_axisttx_reqid            (csr_axisttx_reqid            ),
   .acelitetx_csr_dmadone        (acelitetx_csr_dmadone        ),
   .axistrx_csr_wrdata           (axistrx_csr_wrdata           ), 
   .axistrx_csr_wen              (axistrx_csr_wen              ), 
   .axistrx_csr_ren              (axistrx_csr_ren              ), 
   .axistrx_csr_length           (axistrx_csr_length           ),          
   .axistrx_csr_reqid            (axistrx_csr_reqid            ),
   .axistrx_csr_cplstatus        (axistrx_csr_cplstatus        ), 
   .axistrx_csr_alignaddr        (axistrx_csr_alignaddr        ), 
   .axistrx_csr_unalignaddr      (axistrx_csr_unalignaddr      ), 
   .axistrx_csr_rsptag           (axistrx_csr_rsptag           ),
   .axistrx_csr_rspatrr          (axistrx_csr_rspatrr          ),
   .axistrx_csr_tc               (axistrx_csr_tc               ),
   .csr_hpsrdy                   (csr_hpsrdy                   ),
   .csr_acelitetx_hpsaddr        (csr_acelitetx_hpsaddr        ),
   .axi4mmrx_csr_wdata           (axi4mmrx_csr_wdata           ),
   .axi4mmrx_csr_wen             (axi4mmrx_csr_wen             ),
   .axi4mmrx_csr_wstrb           (axi4mmrx_csr_wstrb           ),            
   .axi4mmrx_csr_ren             (axi4mmrx_csr_ren             ),
   .csr_axi4mmrx_rdata           (csr_axi4mmrx_rdata           ),
   .axi4mmrx_csr_raddr           (axi4mmrx_csr_raddr           ), 
   .axi4mmrx_csr_waddr           (axi4mmrx_csr_waddr           ) 
);


ce_axist_tx    
   #(.CE_BUS_DATA_WIDTH           (CE_BUS_DATA_WIDTH      ),
   .CE_BUS_STRB_WIDTH           (CE_BUS_STRB_WIDTH      ),
   .CE_MMIO_RSP_FIFO_DEPTH      (CE_MMIO_RSP_FIFO_DEPTH ),
   .CE_MMIO_RSP_FIFO_THRHLD     (CE_MMIO_RSP_FIFO_THRHLD),  
   .CE_HST2HPS_FIFO_DEPTH       (CE_HST2HPS_FIFO_DEPTH  ),  
   .CE_PF_ID                    (CE_PF_ID               ),
   .CE_VF_ID                    (CE_VF_ID               ),
   .CE_VF_ACTIVE                (CE_VF_ACTIVE           ),
   .CSR_ADDR_WIDTH              (CSR_ADDR_WIDTH         ),
   .CSR_DATA_WIDTH              (CSR_DATA_WIDTH         ),
   .TAG_WIDTH                   (TAG_WIDTH              ),
   .REQ_ID_WIDTH                (REQ_ID_WIDTH           ))

   ce_axist_tx_inst(

   .clk                              (clk                           ),
   .ce_corereset                     (ce_corereset                  ), 
   .csr_axisttx_hostaddr             (csr_axisttx_hostaddr          ),        
   .csr_axisttx_imgxfrsize           (csr_imgxfrsize                ),        
   .csr_axisttx_mrdstart             (csr_mrdstart                  ),        
   .csr_axisttx_rspaddr              (csr_axisttx_rspaddr           ),        
   .csr_axisttx_rspdata              (csr_axisttx_rspdata           ),        
   .csr_axisttx_rsptag               (csr_axisttx_rsptag            ),            
   .csr_axisttx_fifoerr              (fifo_err_flag                 ),            
   .csr_axisttx_length               (csr_axisttx_length            ),  
   .csr_axisttx_rspattr              (csr_axisttx_rspattr           ),            
   .csr_axisttx_tc                   (csr_axisttx_tc                ),            
   .csr_axisttx_datareqlimit         (csr_axisttx_datareqlimit      ),            
   .csr_axisttx_datareqlimit_log2    (csr_axisttx_datareqlimit_log2 ),            
   .axisttx_csr_mmiofifooverflow     (axisttx_csr_mmiofifooverflow  ),    
   .axisttx_csr_mmiofifounderflow    (axisttx_csr_mmiofifounderflow ),    
   .csr_axisttx_rspvalid             (csr_axisttx_rspvalid          ),       
   .csr_axisttx_reqid                (csr_axisttx_reqid             ),
   .csr_axisttx_tkeep                (csr_axisttx_tkeep             ), 
   .mmiorspfifo_axistrx_almostfull   (mmiorspfifo_axistrx_almostfull),
   .acelitetx_axisttx_bresp          (acelitetx_bresp               ),
   .axistrx_csr_ren                  (axistrx_csr_ren               ), 
   .axistrx_axisttx_cplerr           (axistrx_cplerr                ),     
   .acelitetx_axisttx_req_en         (acelitetx_axisttx_req_en      ),
   .csr_axisttx_hpsrdy               (csr_hpsrdy                    ),    
   .axistrx_axisttx_fc               (axistrx_fc                    ), 
   .axisttx_csr_dmaerr               (axisttx_csr_dmaerr            ), 
   .ce2mux_tx_tvalid                 (axis_tx_if.tvalid             ),         
   .mux2ce_tx_tready                 (axis_tx_if.tready             ),         
   .ce2mux_tx_tdata                  (axis_tx_if.tdata              ),         
   .ce2mux_tx_tkeep                  (axis_tx_if.tkeep              ),         
   .ce2mux_tx_tuser                  (axis_tx_if.tuser_vendor       ),               
   .ce2mux_tx_tlast                  (axis_tx_if.tlast              ) 
);


ce_axist_rx     
   #(.CE_BUS_DATA_WIDTH        (CE_BUS_DATA_WIDTH ),
   .CE_BUS_STRB_WIDTH        (CE_BUS_STRB_WIDTH ),
   .CSR_ADDR_WIDTH           (CSR_ADDR_WIDTH    ),
   .CSR_DATA_WIDTH           (CSR_DATA_WIDTH    ),
   .TAG_WIDTH                (TAG_WIDTH         ),
   .REQ_ID_WIDTH             (REQ_ID_WIDTH      ))

   ce_axist_rx_inst(

   .clk                                (clk                           ),
   .ce_corereset                       (ce_corereset                  ), 
   .mux2ce_rx_tvalid                   (axis_rx_if.tvalid             ),             
   .ce2mux_rx_tready                   (axis_rx_if.tready             ),             
   .mux2ce_rx_tdata                    (axis_rx_if.tdata              ),             
   .mux2ce_rx_tkeep                    (axis_rx_if.tkeep              ),             
   .mux2ce_rx_tuser                    (axis_rx_if.tuser_vendor       ),                   
   .mux2ce_rx_tlast                    (axis_rx_if.tlast              ), 	
   .axistrx_cpldfifo_wrdata            (axistrx_cpldfifo_wrdata       ),
   .csr_axistrx_fifoerr                (fifo_err_flag                 ),            
   .axistrx_cpldfifo_wen               (axistrx_cpldfifo_wen          ),            
   .cpldfifo_axistrx_full              (cpldfifo_axistrx_full         ),  
   .cpldfifo_axistrx_almostfull        (cpldfifo_axistrx_almostfull   ),  
   .axistrx_csr_wen                    (axistrx_csr_wen               ),          
   .axistrx_csr_ren                    (axistrx_csr_ren               ),          
   .axistrx_csr_length                 (axistrx_csr_length            ),          
   .axistrx_csr_alignaddr              (axistrx_csr_alignaddr         ),         
   .axistrx_csr_unalignaddr            (axistrx_csr_unalignaddr       ), 
   .axistrx_csr_wrdata                 (axistrx_csr_wrdata            ),        
   .axistrx_csr_rsptag                 (axistrx_csr_rsptag            ),
   .axistrx_csr_reqid                  (axistrx_csr_reqid             ),
   .axistrx_csr_rspatrr                (axistrx_csr_rspatrr           ),
   .axistrx_csr_tc                     (axistrx_csr_tc                ),
   .csr_axistrx_mrdstart               (csr_mrdstart                  ),
   .mmiorspfifo_axistrx_almostfull     (mmiorspfifo_axistrx_almostfull),
   .axistrx_csr_cplstatus              (axistrx_csr_cplstatus         ), 
   .axistrx_fc                         (axistrx_fc                    ),
   .acelitetx_axistrx_bresp            (acelitetx_bresp               ),     
   .axistrx_axisttx_cplerr             (axistrx_cplerr                ),     
   .acelitetx_axistrx_bresperrpulse    (acelitetx_bresperrpulse       )     
);


ce_acelite_tx      
   #(.CE_BUS_DATA_WIDTH         (CE_BUS_DATA_WIDTH    ),
   .CE_BUS_ADDR_WIDTH         (CE_BUS_ADDR_WIDTH    ),
   .CSR_DATA_WIDTH            (CSR_DATA_WIDTH       ),
   .CE_HST2HPS_FIFO_DEPTH     (CE_HST2HPS_FIFO_DEPTH),
   .CE_BUS_STRB_WIDTH         (CE_BUS_STRB_WIDTH    )) 

   ce_acelite_tx_inst(

   .clk                             (clk                             ),
   .ce_corereset                    (ce_corereset                    ), 
   .hps2ce_tx_awready               (ace_lite_tx_if.awready          ),
   .ce2hps_tx_awvalid               (ace_lite_tx_if.awvalid          ),
   .ce2hps_tx_awaddr                (ace_lite_tx_if.awaddr           ),
   .ce2hps_tx_awprot                (ace_lite_tx_if.awprot           ),
   .ce2hps_tx_awlen                 (ace_lite_tx_if.awlen            ),
   .ce2hps_tx_awsize                (ace_lite_tx_if.awsize           ),
   .ce2hps_tx_awburst               (ace_lite_tx_if.awburst          ),
   .ce2hps_tx_awsnoop               (ace_lite_tx_if.awsnoop          ),  
   .ce2hps_tx_awdomain              (ace_lite_tx_if.awdomain         ), 
   .ce2hps_tx_awbar                 (ace_lite_tx_if.awbar            ), 
   .hps2ce_tx_wready                (ace_lite_tx_if.wready           ),
   .ce2hps_tx_wvalid                (ace_lite_tx_if.wvalid           ),
   .ce2hps_tx_wlast                 (ace_lite_tx_if.wlast            ),
   .ce2hps_tx_wdata                 (ace_lite_tx_if.wdata            ),
   .ce2hps_tx_wstrb                 (ace_lite_tx_if.wstrb            ),
   .hps2ce_tx_bvalid                (ace_lite_tx_if.bvalid           ),
   .hps2ce_tx_bresp                 (ace_lite_tx_if.bresp            ),            
   .ce2hps_tx_bready                (ace_lite_tx_if.bready           ), 
   .cpldfifo_acelitetx_rddata       (cpldfifo_acelitetx_rddata       ),
   .acelitetx_cpldfifo_ren          (acelitetx_cpldfifo_ren          ),            
   .cpldfifo_acelitetx_cnt          (cpldfifo_occupancy              ),
   .csr_acelitetx_fifoerr           (fifo_err_flag                   ),            
   .cpldfifo_acelitetx_empty        (cpldfifo_acelitetx_empty        ),  
   .axistrx_acelitetx_fc            (axistrx_fc                      ),
   .csr_acelitetx_hpsaddr           (csr_acelitetx_hpsaddr           ),    
   .csr_acelitetx_mrdstart          (csr_mrdstart                    ),
   .axistrx_acelitetx_cplerr        (axistrx_cplerr                  ),     
   .acelitetx_bresp                 (acelitetx_bresp                 ),
   .acelitetx_axisttx_req_en        (acelitetx_axisttx_req_en        ),
   .acelitetx_bresperrpulse         (acelitetx_bresperrpulse         ),     
   .acelitetx_csr_dmadone           (acelitetx_csr_dmadone           ),
   .csr_acelitetx_imgxfrsize        (csr_imgxfrsize                  ),    
   .csr_acelitetx_datareqlimit_log2 (csr_axisttx_datareqlimit_log2   ),            
   .csr_acelitetx_datareqlimit      (csr_axisttx_datareqlimit        )

);
//bfifo
//  #(.WIDTH             ( 576                    ),
//    .DEPTH             ( CE_HST2HPS_FIFO_DEPTH  ),
//    .FULL_THRESHOLD    ( CE_HST2HPS_FIFO_THRSHLD),       
//    .REG_OUT           ( 1                      ), 
//    .GRAM_STYLE        ( 0                      ), //TBD
//    .BITS_PER_PARITY   ( 32                     )
//  )
//
//hst2hps_cpld_fifo(
//     
//    .fifo_din          (AxistRx_CpldFiFo_WrData   ),
//    .fifo_wen          (AxistRx_CpldFiFo_wen      ),
//    .fifo_ren          (AceliteTx_CpldFiFo_ren    ),
//    .clk               (clk                       ),
//    .Resetb            (!ce_CoreReset             ),
//    .fifo_out          (                          ),
//    .fifo_dout         (CpldFiFo_AceliteTx_RdData ),       
//    .fifo_count        (CpldFiFo_AxistRx_cnt      ),
//    .full              (CpldFiFo_AxistRx_full     ),
//    .not_empty         (CpldFiFo_NotEmpty         ),
//    .not_empty_out     (                          ),
//    .not_empty_dup     (                          ),
//    .fifo_err          (                          ),
//    .fifo_perr         (                          )
//  );

quartus_bfifo
   #(.WIDTH             ( 577                    ),
   .DEPTH             ( CE_HST2HPS_FIFO_DEPTH  ), 
   .FULL_THRESHOLD    ( CE_HST2HPS_FIFO_THRSHLD),
   .REG_OUT           ( 1                      ), 
   .RAM_STYLE         ( "AUTO"                 ),  
   .ECC_EN            ( 0                      ))

hst2hps_cpld_fifo(

      .fifo_din        (axistrx_cpldfifo_wrdata         ),
      .fifo_wen        (axistrx_cpldfifo_wen            ),
      .fifo_ren        (acelitetx_cpldfifo_ren          ),
      .clk             (clk                             ),
      .Resetb          (!ce_corereset                   ),
      .fifo_dout       (cpldfifo_acelitetx_rddata       ),       
      .fifo_count      (cpldfifo_occupancy              ), 
      .full            (cpldfifo_axistrx_full           ),
      .almost_full     (cpldfifo_axistrx_almostfull     ),
      .not_empty       (cpldfifo_notempty               ),
      .almost_empty    (                                ),
      .fifo_eccstatus  (                                ),
      .fifo_err        (cpldfifo_csr_fifoerr            )
);

ce_axi4mm_rx      
   #(.CE_AXI4MM_DATA_WIDTH     (CE_AXI4MM_DATA_WIDTH   ),
   .CE_AXI4MM_ADDR_WIDTH     (CE_AXI4MM_ADDR_WIDTH   ),
   .CSR_ADDR_WIDTH           (CSR_ADDR_WIDTH         ),
   .CE_BUS_STRB_WIDTH        (CE_AXI4MM_DATA_WIDTH>>3)) 

   ce_axi4mm_rx_inst(

   .clk                          (clk                        ),
   .h2f_reset                    (h2f_reset                  ),
   .ce2hps_rx_awready            (axi4mm_rx_if.awready       ),
   .hps2ce_rx_awvalid            (axi4mm_rx_if.awvalid       ),
   .hps2ce_rx_awaddr             (axi4mm_rx_if.awaddr        ),
   .hps2ce_rx_awprot             (axi4mm_rx_if.awprot        ),
   .hps2ce_rx_awlen              (axi4mm_rx_if.awlen         ),
   .hps2ce_rx_awid               (axi4mm_rx_if.awid          ),
   .hps2ce_rx_awsize             (axi4mm_rx_if.awsize        ),
   .hps2ce_rx_awburst            (axi4mm_rx_if.awburst       ),
   .hps2ce_rx_awlock             (axi4mm_rx_if.awlock        ),
   .hps2ce_rx_awcache            (axi4mm_rx_if.awcache       ),
   .hps2ce_rx_awqos              (axi4mm_rx_if.awqos         ), //
   .ce2hps_rx_wready             (axi4mm_rx_if.wready        ),
   .hps2ce_rx_wvalid             (axi4mm_rx_if.wvalid        ),
   .hps2ce_rx_wdata              (axi4mm_rx_if.wdata         ),
   .hps2ce_rx_wstrb              (axi4mm_rx_if.wstrb         ),
   .hps2ce_rx_wlast              (axi4mm_rx_if.wlast         ),
   .ce2hps_rx_bvalid             (axi4mm_rx_if.bvalid        ),
   .ce2hps_rx_bresp              (axi4mm_rx_if.bresp         ),            
   .ce2hps_rx_bid                (axi4mm_rx_if.bid           ),            
   .hps2ce_rx_bready             (axi4mm_rx_if.bready        ),
   .ce2hps_rx_arready            (axi4mm_rx_if.arready       ),
   .hps2ce_rx_arvalid            (axi4mm_rx_if.arvalid       ),
   .hps2ce_rx_araddr             (axi4mm_rx_if.araddr        ),
   .hps2ce_rx_arprot             (axi4mm_rx_if.arprot        ),
   .hps2ce_rx_arid               (axi4mm_rx_if.arid          ),
   .hps2ce_rx_arlen              (axi4mm_rx_if.arlen         ),
   .hps2ce_rx_arsize             (axi4mm_rx_if.arsize        ),
   .hps2ce_rx_arburst            (axi4mm_rx_if.arburst       ),
   .hps2ce_rx_arlock             (axi4mm_rx_if.arlock        ),
   .hps2ce_rx_arcache            (axi4mm_rx_if.arcache       ),
   .hps2ce_rx_arqos              (axi4mm_rx_if.arqos         ), //
   .hps2ce_rx_rready             (axi4mm_rx_if.rready        ),
   .ce2hps_rx_rvalid             (axi4mm_rx_if.rvalid        ),
   .ce2hps_rx_rdata              (axi4mm_rx_if.rdata         ),
   .ce2hps_rx_rlast              (axi4mm_rx_if.rlast         ),
   .ce2hps_rx_rid                (axi4mm_rx_if.rid           ),
   .ce2hps_rx_rresp              (axi4mm_rx_if.rresp         ),
   .acelitetx_axi4mmrx_bresp     (acelitetx_bresp            ),     
   .axistrx_axi4mmrx_cplerr      (axistrx_cplerr             ),     
   .axi4mmrx_csr_wdata           (axi4mmrx_csr_wdata         ), 
   .axi4mmrx_csr_wen             (axi4mmrx_csr_wen           ),            
   .axi4mmrx_csr_wstrb           (axi4mmrx_csr_wstrb         ),            
   .axi4mmrx_csr_ren             (axi4mmrx_csr_ren           ),  
   .axi4mmrx_csr_raddr           (axi4mmrx_csr_raddr         ),    
   .csr_axi4mmrx_fifoerr         (fifo_err_flag              ),            
   .axi4mmrx_csr_waddr           (axi4mmrx_csr_waddr         ),
   .csr_axi4mmrx_rdata           (csr_axi4mmrx_rdata         )

);

//tie off for unused outputs

assign  ace_lite_tx_if.awid       = 5'd0                     ;
assign  ace_lite_tx_if.awlock     = 1'd0                     ;
assign  ace_lite_tx_if.awcache    = 4'b0010                  ;
assign  ace_lite_tx_if.awqos      = 4'd0                     ;
assign  ace_lite_tx_if.awuser     = 23'b11100000             ;
assign  ace_lite_tx_if.arid       = 5'd0                     ;
assign  ace_lite_tx_if.arlock     = 1'd0                     ;
assign  ace_lite_tx_if.arcache    = 4'b0010                  ;
assign  ace_lite_tx_if.arqos      = 4'd0                     ;
assign  ace_lite_tx_if.aruser     = 23'b11100000             ;
assign  ace_lite_tx_if.arvalid    = 1'd0                     ;
assign  ace_lite_tx_if.araddr     = {CE_BUS_ADDR_WIDTH{1'h0}};
assign  ace_lite_tx_if.arprot     = 3'd0                     ;
assign  ace_lite_tx_if.arlen      = 8'd0                     ;
assign  ace_lite_tx_if.arsize     = 3'd0                     ;
assign  ace_lite_tx_if.arburst    = 2'd0                     ;
assign  ace_lite_tx_if.arsnoop    = 4'd0                     ;
assign  ace_lite_tx_if.ardomain   = 2'd3                     ;
assign  ace_lite_tx_if.arbar      = 2'd0                     ;
assign  ace_lite_tx_if.rready     = 1'd0                     ;

endmodule

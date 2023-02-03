// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Engineer     : Parakundil, Liaqat                
// Create Date  : Nov 2020
// Module Name  : ce_csr.sv
// Project      : IOFS
// -----------------------------------------------------------------------------
//
// Description: 
//Implementation of a 64-bits/32bits read/write CSR block
//host sw and hps sw can access copy engine registers
// ***************************************************************************

//`include "vendor_defines.vh"
module ce_csr #(
   parameter bit [11:0] CE_FEAT_ID             = 12'h1                    , //DFH Feature ID
   parameter bit [3:0 ] CE_FEAT_VER            = 4'h1                     , //DFH Feature Version
   parameter bit [23:0] CE_NEXT_DFH_OFFSET     = 24'h1000                 , //DFH Next DFH Offset
   parameter bit        CE_END_OF_LIST         = 1'b1                     , //DFH End of list
   parameter            CSR_ADDR_WIDTH         = 16                       , 
   parameter            CSR_DATA_WIDTH         = 64                       , 
   parameter            CE_AXI4MM_DATA_WIDTH   = 32                       , 
   parameter            CE_BUS_STRB_WIDTH      = CE_AXI4MM_DATA_WIDTH >>3 ,
   parameter            REQ_ID_WIDTH           = 16                       , 
   parameter            TAG_WIDTH              = 10
   )(

//connections from top block
input wire                                  clk                               ,   //350MHz clock
input wire                                  ce_corereset                      ,   //Active high reset-hard reset + soft reset
input wire                                  rst                               ,   //System reset-Hard reset                   
input wire                                  cpldfifo_csr_overflow             ,   //FIFO2 overflow err flag
input wire                                  cpldfifo_csr_underflow            ,   //FIFO2 underflow err flag
output wire                                 fifo_err_flag                     ,   //FIFO1 & FIFO2 status

// connections to/from tx block                                
input wire                                  axisttx_csr_mmiofifooverflow      ,   //MMIO FIFO overflow flag                                   
input wire                                  axisttx_csr_mmiofifounderflow     ,   //MMIO FIFO Underflow flag                                  
output wire                                 csr_mrdstart                      ,   //MRD Start bit; to Tx & Rx block
output wire                                 csr_axisttx_rspvalid              ,   //CSR to Tx block flag to write to FIFO1
output logic                                ce_softreset                     ,   //Copy Engine Soft Reset  
output wire                                 csr_axisttx_length                ,   //CSR Length Field 
output logic   [CSR_DATA_WIDTH/8 -1:0  ]    csr_axisttx_tkeep                 ,   //tkeep signal      
output wire    [8:0                    ]    csr_axisttx_rspattr               ,   //Attribute field             
output wire    [2:0                    ]    csr_axisttx_tc                    ,   //Traffic class               
output logic   [10:0                   ]    csr_axisttx_datareqlimit          ,   //Data Req Limit              
output logic   [3:0                    ]    csr_axisttx_datareqlimit_log2     ,   //Data Req Limit log2         
output wire    [CSR_DATA_WIDTH-1:0     ]    csr_axisttx_hostaddr              ,   //Host DDR Start address
output wire    [CSR_DATA_WIDTH-1:0     ]    csr_imgxfrsize                    ,   //Image size                    
output wire    [CSR_ADDR_WIDTH-1:0     ]    csr_axisttx_rspaddr               ,   //CSR Response addr
output wire    [CSR_DATA_WIDTH-1:0     ]    csr_axisttx_rspdata               ,   //CSR read data[63:0] for AXI ST Interface
output wire    [TAG_WIDTH-1:0          ]    csr_axisttx_rsptag                ,   //Tag field                   
output wire    [REQ_ID_WIDTH-1:0       ]    csr_axisttx_reqid                 ,   //requester ID            

// connections from rx                                
input  logic                                axistrx_csr_wen                   ,   //CSR write enable
input  logic                                axistrx_csr_ren                   ,   //CSR read enable
input  logic                                axistrx_csr_length                ,   //Header Length Field 
input  logic                                axisttx_csr_dmaerr                ,   //Error status signal              
output wire                                 csr_hpsrdy                        ,   //HPS ready bit]
input  logic  [8:0               ]          axistrx_csr_rspatrr               ,   //Attribute field
input  logic  [2:0               ]          axistrx_csr_tc                    ,   //Traffic class field
input  logic  [2:0               ]          axistrx_csr_cplstatus             ,   //Completion status in the completer header format
input  logic  [CSR_DATA_WIDTH-1:0]          axistrx_csr_wrdata                ,   //CSR write data
input  logic  [CSR_ADDR_WIDTH-1:0]          axistrx_csr_alignaddr             ,   //8B Aligned address
input  logic  [CSR_ADDR_WIDTH-1:0]          axistrx_csr_unalignaddr           ,   //Unaligned address-4B aligned & not 8B aligned
input  logic  [TAG_WIDTH-1:0     ]          axistrx_csr_rsptag                ,   //Tag field
input  logic  [REQ_ID_WIDTH-1:0  ]          axistrx_csr_reqid                 ,   //Requester ID


//connections from/to Axi4mm interface from HPS to Copy Engine

input  logic                                axi4mmrx_csr_wen                  ,   // Write Enable
input  logic                                axi4mmrx_csr_ren                  ,   // Read Enable
input  logic  [CE_BUS_STRB_WIDTH-1:0    ]   axi4mmrx_csr_wstrb                ,    //Write strobes 
input  logic  [CE_AXI4MM_DATA_WIDTH-1:0 ]   axi4mmrx_csr_wdata                ,   // Write Data from AXI Lite interface
input  logic  [CSR_ADDR_WIDTH-1:0       ]   axi4mmrx_csr_waddr                ,   // write Address
input  logic  [CSR_ADDR_WIDTH-1:0       ]   axi4mmrx_csr_raddr                ,   // Read Address
output logic  [CE_AXI4MM_DATA_WIDTH-1:0 ]   csr_axi4mmrx_rdata                ,   // Read Data


//connections to/from Acelite Tx block
input  logic                                acelitetx_csr_dmadone             ,  //Ace Lite Write Response
input  logic   [1:0               ]         acelitetx_bresp                   ,  //Ace Lite Write Response
output wire    [CSR_DATA_WIDTH-1:0]         csr_acelitetx_hpsaddr                 //HPS DDR destination address
);



//---------------------------------------------------------
// CSR Address Map ***** DO NOT MODIFY *****
//---------------------------------------------------------


//Accessible to host only
localparam      CE_FEATURE_DFH       	       = 16'h000     ; // RO - DFH info for the Copy Engine
localparam      CE_FEATURE_GUID_L    	       = 16'h008     ; // RO - Lower 64 bits of the GUID
localparam      CE_FEATURE_GUID_H    	       = 16'h010     ; // RO - Upper 64 bits of the GUID
localparam      CE_FEATURE_CSR_ADDR  	       = 16'h018     ; // RO - Address of CSR block 
localparam      CE_FEATURE_CSR_SIZE_GROUP      = 16'h020     ; // RO - Size of CSR block and Grouping ID


localparam      CSR_HOST_SCRATCHPAD 	       = 16'h100     ; // RW   SCRATCHPAD REGISTER for Host
localparam      CSR_CE2HOST_DATA_REQ_LIMIT     = 16'h108     ; // RW   DATA Request limit                 

localparam      CSR_IMG_SRC_ADDR               = 16'h110     ; // RW   HOST DDR Read address 
localparam      CSR_IMG_DST_ADDR               = 16'h118     ; // RW   HPS DDR offset
localparam      CSR_IMG_SIZE        	       = 16'h120     ; // RW   Data Size in Bytes
localparam      CSR_HOST2CE_MRD_START  	       = 16'h128     ; // RW   Memory Read Start
localparam      CSR_CE2HOST_STATUS             = 16'h130     ; // RO   copy engine to host dma status
localparam      CSR_HOST2HPS_IMG_XFR	       = 16'h0138    ; // RW   once complete image is transferred (DMA done), host write to this csr         
localparam      CSR_HPS2HOST_RSP_SHDW          = 16'h140     ; // RO   HPS to host status   
localparam      CSR_CE_SFTRST                  = 16'h148     ; // RW   Copy engine soft reset csr


///DFH CSRs Default values
localparam       DEF_CE_FEATURE_DFH            = {4'h1,19'h0,CE_END_OF_LIST,CE_NEXT_DFH_OFFSET,CE_FEAT_VER,CE_FEAT_ID};
localparam       DEF_CE_FEATURE_GUID_L         = 64'hBD42_57DC_93EA_7F91;
localparam       DEF_CE_FEATURE_GUID_H         = 64'h44BF_C10D_B42A_44E5;
localparam       DEF_CE_FEATURE_CSR_ADDR       = 64'h0000_0000_0000_0100;
localparam       DEF_CE_FEATURE_CSR_SIZE_GROUP = 64'h0000_0050_0000_0000; 

//Accessible to HPS only
localparam      CSR_HPS_SCRATCHPAD             = 16'h150    ; // RW   SCRATCHPAD REGISTER for HPS
localparam      CSR_HOST2HPS_IMG_XFR_SHDW      = 16'h154    ; // RO   once complete image is transferred (DMA done), host write to this csr         
localparam      CSR_HPS2HOST_RSP               = 16'h158    ; // RW   HPS to host status   


//-------------------------------------------------------------
//TAG,ADDR given by host during CSR Read
//are registered here and stored in FIFO1                
//in Tx block
//-------------------------------------------------------------
reg                        csr_rd_data_valid_t1 ;
reg                        csr_length_t1        ; 
reg [CSR_ADDR_WIDTH-1:0]   csr_addr_t1          ;
reg [TAG_WIDTH-1:0     ]   csr_tag_t1           ;
reg [REQ_ID_WIDTH-1:0  ]   csr_req_id_t1        ;
reg [8:0               ]   csr_attr_t1          ;
reg [2:0               ]   csr_tc_t1            ;


always @(posedge clk)
begin
   if(ce_corereset==1) begin
      csr_rd_data_valid_t1 <= 1'b0                  ;
      csr_length_t1        <= 1'b0                  ;
      csr_tag_t1           <= {TAG_WIDTH{1'b0}}     ;
      csr_req_id_t1        <= {REQ_ID_WIDTH{1'b0}}  ;
      csr_addr_t1          <= {CSR_ADDR_WIDTH{1'b0}};
      csr_attr_t1          <= 9'h0                  ;
   end

   else begin
      csr_rd_data_valid_t1 <= axistrx_csr_ren          ;
      csr_length_t1        <= axistrx_csr_length       ; 
      csr_tag_t1           <= axistrx_csr_rsptag       ;
      csr_req_id_t1        <= axistrx_csr_reqid        ;
      csr_attr_t1          <= axistrx_csr_rspatrr      ;
      csr_tc_t1            <= axistrx_csr_tc           ;
      csr_addr_t1          <= axistrx_csr_unalignaddr  ;
   end
end
//-------------------------------------------------------------

//----------------------------------------------------------------
//-----------------Host CSR Writes(RW)&& CE CSR updates-------
//----------------------------------------------------------------

reg [CSR_DATA_WIDTH-1:0      ]  csr_host_scratchpad    ;
reg [CSR_DATA_WIDTH-1:0      ]  csr_data_req_limit     ;
reg [CE_AXI4MM_DATA_WIDTH-1:0]  csr_hps_scratchpad     ;
reg [CSR_DATA_WIDTH-1:0      ]  csr_desc_imgsrc_addr   ;
reg [CSR_DATA_WIDTH-1:0      ]  csr_desc_imgdst_addr   ;
reg [CSR_DATA_WIDTH-1:0      ]  csr_desc_img_size      ;
reg [CSR_DATA_WIDTH-1:0      ]  csr_ce_softreset       ;
reg [CSR_DATA_WIDTH-1:0      ]  csr_desc_mrd_start     ;
reg [CSR_DATA_WIDTH-1:0      ]  csr_host2hps_img_xfr_st;
reg [CE_AXI4MM_DATA_WIDTH-1:0]  csr_hps2host_rsp       ;
reg [CSR_DATA_WIDTH-1:0      ]  csr_dma_st             ;

//0x130 CSR_CE2HOST_STATUS
always@(posedge clk)
begin
   if(ce_corereset==1'b1) begin
      csr_dma_st         <= {CSR_DATA_WIDTH{1'h0}};
   end

   else begin
         csr_dma_st[10:9]    <= {cpldfifo_csr_overflow,cpldfifo_csr_underflow               };//capturing FIFO2 health condition
         csr_dma_st[8:7 ]    <= {axisttx_csr_mmiofifooverflow, axisttx_csr_mmiofifounderflow};//capturing FIFO1 health condition
         csr_dma_st[6:4 ]    <= axistrx_csr_cplstatus                                        ;//capturing completion status from host-AXIST Rx
         csr_dma_st[3:2 ]    <= acelitetx_bresp                                              ;//capturing Acelite interface write response


         if (csr_desc_mrd_start[0]==1'b1)begin
            csr_dma_st[1:0  ]    <= 2'd1                                                                                            ;  //DMA in progress
            csr_dma_st[12:11]    <= ( (|csr_desc_imgdst_addr[63:30] == 1'b1) ) ? 2'b10:2'b01; //checking if host programmed
                                                                                                                                       //valid host DDR & HPS DDR addr
                                                                                                                                       //HPS  DDR= 1GB          
         end

         else if(csr_dma_st[12:11] == 2'b10) begin //host programmed illegal values in the descriptors
                                                   //MRD start will be de-asserted. Host to program legal values
            csr_dma_st[1:0    ]    <= 2'd0               ;//DMA status is IDLE
            csr_dma_st[12:11  ]    <= csr_dma_st[12:11]  ; 
         end

         else if(axisttx_csr_dmaerr == 1'b1) begin//Error in transfer
            csr_dma_st[1:0    ]    <= 2'b11              ;//DMA status is Error
            csr_dma_st[12:11  ]    <= csr_dma_st[12:11]  ;
         end

         else if(acelitetx_csr_dmadone == 1'b1) begin //data moved successfully from host DDR to HPS DDR as per csr_img_size programmed  
            csr_dma_st[1:0   ]    <= 2'b10              ;//DMA status is success
            csr_dma_st[12:11 ]    <= csr_dma_st[12:11]  ;
         end

   end
end
//----------------------------------------------------------------



//----------------------------------------------------------------
//--------HOST CSR Write------------------------------------------
//----------------------------------------------------------------

//MRD start CSR                                   
//Assertion is always by SW
//Deassertion is always by HW
always@(posedge clk)
begin
   if(ce_corereset==1'b1) begin
      csr_desc_mrd_start <= {CSR_DATA_WIDTH{1'h0}};
   end


   else if( (acelitetx_csr_dmadone == 1'b1)  || //data moved successfully from host DDR to HPS DDR as per csr_img_size programmed
            (axisttx_csr_dmaerr    == 1'b1 ) || //Error in transfer     
            ((csr_dma_st[12:11]    == 2'b10) && (csr_desc_mrd_start[0]==1'b1) )) begin  //host programmed illegal values in the descriptors 
            csr_desc_mrd_start[0] <= 1'h0;
   end

   else if  ( (axistrx_csr_alignaddr == CSR_HOST2CE_MRD_START ) && (axistrx_csr_wen == 1'b1)) begin//Host updating MRD start CSR
      if    ( (axistrx_csr_wrdata[0] == 1'b1) && (axistrx_csr_unalignaddr[2]== 1'b0) ) begin //ensuring value programmed by host is 1'b1-64bits 8B aligned access
                                                                                             //host is not expected to program 1'b0 to this field
                                                                                             //this bit de-assertion is by CE                           
            csr_desc_mrd_start[0] <= 1'b1;
      end

      if(   (axistrx_csr_length == 1'b0) && (axistrx_csr_unalignaddr[2]== 1'b0) ) begin //32bits-4B aligned
            csr_desc_mrd_start[31:1]      <= axistrx_csr_wrdata[31:1]; 
      end

      else if( (axistrx_csr_length == 1'b0) && (axistrx_csr_unalignaddr[2]== 1'b1) ) begin //32bits- 4B un-aligned
            csr_desc_mrd_start[63:32]      <= axistrx_csr_wrdata[31:0]; 
      end

      else if( (axistrx_csr_length == 1'b1) && (axistrx_csr_unalignaddr[2]== 1'b0) )begin //64bits-8B aligned 
            csr_desc_mrd_start[63:1]      <= axistrx_csr_wrdata[63:1]; 
      end
   end
end

always@(posedge clk)
begin
   if(ce_corereset==1'b1)begin
      csr_host_scratchpad     <= {CSR_DATA_WIDTH{1'h0}};
      csr_data_req_limit      <= 64'd3                 ; //default data request limit is 1KB
      csr_desc_imgsrc_addr    <= {CSR_DATA_WIDTH{1'h0}};
      csr_desc_imgdst_addr    <= {CSR_DATA_WIDTH{1'h0}};
      csr_desc_img_size       <= {CSR_DATA_WIDTH{1'h0}};
      csr_host2hps_img_xfr_st <= {CSR_DATA_WIDTH{1'h0}};
   end

   else begin  

      if( (axistrx_csr_length == 1'b0) && (axistrx_csr_unalignaddr[2]== 1'b0) )  begin //4B aligned access
            case({axistrx_csr_wen,axistrx_csr_alignaddr}) 
               {1'b1,CSR_HOST_SCRATCHPAD       }: csr_host_scratchpad    [31:0] <= axistrx_csr_wrdata[31:0] ; 
               {1'b1,CSR_CE2HOST_DATA_REQ_LIMIT}: csr_data_req_limit     [31:0] <= axistrx_csr_wrdata[31:0] ; 
               {1'b1,CSR_IMG_SRC_ADDR          }: csr_desc_imgsrc_addr   [31:0] <= axistrx_csr_wrdata[31:0] ; 
               {1'b1,CSR_IMG_DST_ADDR          }: csr_desc_imgdst_addr   [31:0] <= axistrx_csr_wrdata[31:0] ; 
               {1'b1,CSR_IMG_SIZE        	 }: csr_desc_img_size      [31:0] <= axistrx_csr_wrdata[31:0] ; 
               {1'b1,CSR_HOST2HPS_IMG_XFR	 }: csr_host2hps_img_xfr_st[31:0] <= axistrx_csr_wrdata[31:0] ; 

               default:                           begin
                                                      csr_host_scratchpad       <= csr_host_scratchpad       ; 
                                                      csr_data_req_limit        <= csr_data_req_limit        ; 
                                                      csr_desc_imgsrc_addr      <= csr_desc_imgsrc_addr      ; 
                                                      csr_desc_imgdst_addr      <= csr_desc_imgdst_addr      ; 
                                                      csr_desc_img_size         <= csr_desc_img_size         ; 
                                                      csr_host2hps_img_xfr_st   <= csr_host2hps_img_xfr_st   ; 
                                                end
            endcase
      end

      else if( (axistrx_csr_length == 1'b0) && (axistrx_csr_unalignaddr[2]==1'b1) )  begin //4B unaligned access
         case({axistrx_csr_wen,axistrx_csr_alignaddr}) 
               {1'b1,CSR_HOST_SCRATCHPAD       }: csr_host_scratchpad    [63:32] <= axistrx_csr_wrdata[31:0] ; 
               {1'b1,CSR_CE2HOST_DATA_REQ_LIMIT}: csr_data_req_limit     [63:32] <= axistrx_csr_wrdata[31:0] ; 
               {1'b1,CSR_IMG_SRC_ADDR          }: csr_desc_imgsrc_addr   [63:32] <= axistrx_csr_wrdata[31:0] ; 
               {1'b1,CSR_IMG_DST_ADDR          }: csr_desc_imgdst_addr   [63:32] <= axistrx_csr_wrdata[31:0] ; 
               {1'b1,CSR_IMG_SIZE        	 }: csr_desc_img_size      [63:32] <= axistrx_csr_wrdata[31:0] ; 
               {1'b1,CSR_HOST2HPS_IMG_XFR	 }: csr_host2hps_img_xfr_st[63:32] <= axistrx_csr_wrdata[31:0] ; 

               default:                           begin
                                                      csr_host_scratchpad       <= csr_host_scratchpad    ; 
                                                      csr_data_req_limit        <= csr_data_req_limit     ; 
                                                      csr_desc_imgsrc_addr      <= csr_desc_imgsrc_addr   ; 
                                                      csr_desc_imgdst_addr      <= csr_desc_imgdst_addr   ; 
                                                      csr_desc_img_size         <= csr_desc_img_size      ; 
                                                      csr_host2hps_img_xfr_st   <= csr_host2hps_img_xfr_st; 
                                                end
            endcase
      end

      else if ( (axistrx_csr_length == 1'b1) && (axistrx_csr_unalignaddr[2]==1'b0) ) begin //8B access
         case({axistrx_csr_wen,axistrx_csr_alignaddr}) 
               {1'b1,CSR_HOST_SCRATCHPAD    	 }: csr_host_scratchpad     <= axistrx_csr_wrdata ; 
               {1'b1,CSR_CE2HOST_DATA_REQ_LIMIT}: csr_data_req_limit      <= axistrx_csr_wrdata ; 
               {1'b1,CSR_IMG_SRC_ADDR          }: csr_desc_imgsrc_addr    <= axistrx_csr_wrdata ; 
               {1'b1,CSR_IMG_DST_ADDR          }: csr_desc_imgdst_addr    <= axistrx_csr_wrdata ; 
               {1'b1,CSR_IMG_SIZE        	 }: csr_desc_img_size       <= axistrx_csr_wrdata ; 
               {1'b1,CSR_HOST2HPS_IMG_XFR	 }: csr_host2hps_img_xfr_st <= axistrx_csr_wrdata ; 

               default:                           begin
                                                      csr_host_scratchpad     <= csr_host_scratchpad    ; 
                                                      csr_data_req_limit      <= csr_data_req_limit     ; 
                                                      csr_desc_imgsrc_addr    <= csr_desc_imgsrc_addr   ; 
                                                      csr_desc_imgdst_addr    <= csr_desc_imgdst_addr   ; 
                                                      csr_desc_img_size       <= csr_desc_img_size      ; 
                                                      csr_host2hps_img_xfr_st <= csr_host2hps_img_xfr_st; 
                                                end
         endcase
      end
   end
end

//HPS CSR Write
reg wr_rcvd;
always@(posedge clk)
begin
   if(ce_corereset==1'b1) begin
      csr_hps_scratchpad <= {CE_AXI4MM_DATA_WIDTH{1'h0}};
      csr_hps2host_rsp   <= {CE_AXI4MM_DATA_WIDTH{1'h0}};
      wr_rcvd            <= 1'b0                        ;
   end

   else begin                                                                   
      case({axi4mmrx_csr_wen,axi4mmrx_csr_waddr}) 

         {1'b1,CSR_HPS_SCRATCHPAD}: begin
                                       csr_hps_scratchpad[7:0  ] <= axi4mmrx_csr_wstrb[0] ? axi4mmrx_csr_wdata[7:0  ]:csr_hps_scratchpad[7:0  ] ; 
                                       csr_hps_scratchpad[15:8 ] <= axi4mmrx_csr_wstrb[1] ? axi4mmrx_csr_wdata[15:8 ]:csr_hps_scratchpad[15:8 ] ; 
                                       csr_hps_scratchpad[23:16] <= axi4mmrx_csr_wstrb[2] ? axi4mmrx_csr_wdata[23:16]:csr_hps_scratchpad[23:16] ; 
                                       csr_hps_scratchpad[31:24] <= axi4mmrx_csr_wstrb[3] ? axi4mmrx_csr_wdata[31:24]:csr_hps_scratchpad[31:24] ; 
                                    end

         {1'b1,CSR_HPS2HOST_RSP  }: begin
                                             //csr_hps2host_rsp[31:5]  <= axi4mmrx_csr_wdata[31:5]; 

                                             csr_hps2host_rsp[31:24]   <= axi4mmrx_csr_wstrb[3] ? axi4mmrx_csr_wdata[31:24]:csr_hps2host_rsp[31:24] ; 
                                             csr_hps2host_rsp[23:16]   <= axi4mmrx_csr_wstrb[2] ? axi4mmrx_csr_wdata[23:16]:csr_hps2host_rsp[23:16] ; 
                                             csr_hps2host_rsp[15:8 ]   <= axi4mmrx_csr_wstrb[1] ? axi4mmrx_csr_wdata[15:8 ]:csr_hps2host_rsp[15:8 ] ; 
                                             csr_hps2host_rsp[7:5  ]   <= axi4mmrx_csr_wstrb[0] ? axi4mmrx_csr_wdata[7:5  ]:csr_hps2host_rsp[7:5  ] ; 
                                             csr_hps2host_rsp[3:0  ]   <= axi4mmrx_csr_wstrb[0] ? axi4mmrx_csr_wdata[3:0  ]:csr_hps2host_rsp[3:0  ] ; 

                                                if((wr_rcvd               == 1'b0 ) &&
                                                   (axi4mmrx_csr_wdata[4] == 1'b1 ) &&
                                                   (axi4mmrx_csr_wstrb[0] == 1'b1 )) begin

                                                   csr_hps2host_rsp[4]   <= 1'b1 ;
                                                   wr_rcvd               <= 1'b1 ;
                                                end
                                             end


         default:                           begin
                                                csr_hps2host_rsp   <= csr_hps2host_rsp  ;
                                                csr_hps_scratchpad <= csr_hps_scratchpad;
                                             end
      endcase
   end
end
//----------------------------------------------------------------

//----------------------------------------------------------------
//--------HOST CSR Reads------------------------------------------
//----------------------------------------------------------------
reg [CSR_DATA_WIDTH-1:0       ] host_csr_rd_data;
reg [CE_AXI4MM_DATA_WIDTH-1:0] hps_csr_rd_data ;


always@(posedge clk)
begin
   if(ce_corereset==1'b1)begin
      csr_axisttx_tkeep  <= {CSR_DATA_WIDTH>>3{1'h0}}  ;
   end

   else if (axistrx_csr_ren==1'b1) begin

      if(axistrx_csr_length == 1'b1) begin
         csr_axisttx_tkeep  <= 8'hFF;
      end
      else if(axistrx_csr_length == 1'b0) begin
         csr_axisttx_tkeep  <= 8'h0F;
      end
   end
end

always@(posedge clk)
begin
   if(ce_corereset==1'b1)begin
      host_csr_rd_data   <= {CSR_DATA_WIDTH{1'h0}}  ;
   end

   else if((axistrx_csr_unalignaddr <=  16'h14C) && (!((axistrx_csr_alignaddr >= 16'h28) && (axistrx_csr_alignaddr <=  16'hF8)))) begin  

      if(axistrx_csr_unalignaddr[2]==1'b0) begin
         case({axistrx_csr_ren,axistrx_csr_alignaddr}) 

            {1'b1,CE_FEATURE_DFH            }: host_csr_rd_data <= DEF_CE_FEATURE_DFH           ;
            {1'b1,CE_FEATURE_GUID_L    	}: host_csr_rd_data <= DEF_CE_FEATURE_GUID_L        ;
            {1'b1,CE_FEATURE_GUID_H    	}: host_csr_rd_data <= DEF_CE_FEATURE_GUID_H        ;
            {1'b1,CE_FEATURE_CSR_ADDR  	}: host_csr_rd_data <= DEF_CE_FEATURE_CSR_ADDR      ;  
            {1'b1,CE_FEATURE_CSR_SIZE_GROUP }: host_csr_rd_data <= DEF_CE_FEATURE_CSR_SIZE_GROUP; 
            {1'b1,CSR_HOST_SCRATCHPAD       }: host_csr_rd_data <= csr_host_scratchpad          ; 
            {1'b1,CSR_CE2HOST_DATA_REQ_LIMIT}: host_csr_rd_data <= csr_data_req_limit           ; 
            {1'b1,CSR_IMG_SRC_ADDR         	}: host_csr_rd_data <= csr_desc_imgsrc_addr         ; 
            {1'b1,CSR_IMG_DST_ADDR         	}: host_csr_rd_data <= csr_desc_imgdst_addr         ; 
            {1'b1,CSR_IMG_SIZE        	}: host_csr_rd_data <= csr_desc_img_size            ; 
            {1'b1,CSR_HOST2CE_MRD_START     }: host_csr_rd_data <= csr_desc_mrd_start           ; 
            {1'b1,CSR_CE2HOST_STATUS        }: host_csr_rd_data <= csr_dma_st                   ; 
            {1'b1,CSR_HOST2HPS_IMG_XFR	}: host_csr_rd_data <= csr_host2hps_img_xfr_st      ; 
            {1'b1,CSR_HPS2HOST_RSP_SHDW     }: host_csr_rd_data <= {32'h0,csr_hps2host_rsp}     ; 
            {1'b1,CSR_CE_SFTRST             }: host_csr_rd_data <= csr_ce_softreset             ; 
            default:                           host_csr_rd_data <= host_csr_rd_data             ;
         endcase
      end

      else if(axistrx_csr_unalignaddr[2] == 1'b1) begin//4B

         case({axistrx_csr_ren,axistrx_csr_alignaddr}) 

            {1'b1,CE_FEATURE_DFH            }: host_csr_rd_data[31:0] <= DEF_CE_FEATURE_DFH           [63:32] ;
            {1'b1,CE_FEATURE_GUID_L    	}: host_csr_rd_data[31:0] <= DEF_CE_FEATURE_GUID_L        [63:32] ;
            {1'b1,CE_FEATURE_GUID_H    	}: host_csr_rd_data[31:0] <= DEF_CE_FEATURE_GUID_H        [63:32] ;
            {1'b1,CE_FEATURE_CSR_ADDR  	}: host_csr_rd_data[31:0] <= DEF_CE_FEATURE_CSR_ADDR      [63:32] ;  
            {1'b1,CE_FEATURE_CSR_SIZE_GROUP }: host_csr_rd_data[31:0] <= DEF_CE_FEATURE_CSR_SIZE_GROUP[63:32] ;
            {1'b1,CSR_HOST_SCRATCHPAD       }: host_csr_rd_data[31:0] <= csr_host_scratchpad          [63:32] ; 
            {1'b1,CSR_CE2HOST_DATA_REQ_LIMIT}: host_csr_rd_data[31:0] <= csr_data_req_limit           [63:32] ; 
            {1'b1,CSR_IMG_SRC_ADDR         	}: host_csr_rd_data[31:0] <= csr_desc_imgsrc_addr         [63:32] ; 
            {1'b1,CSR_IMG_DST_ADDR         	}: host_csr_rd_data[31:0] <= csr_desc_imgdst_addr         [63:32] ; 
            {1'b1,CSR_IMG_SIZE        	}: host_csr_rd_data[31:0] <= csr_desc_img_size            [63:32] ; 
            {1'b1,CSR_HOST2CE_MRD_START     }: host_csr_rd_data[31:0] <= csr_desc_mrd_start           [63:32] ; 
            {1'b1,CSR_CE_SFTRST             }: host_csr_rd_data[31:0] <= csr_ce_softreset             [63:32] ; 
            {1'b1,CSR_CE2HOST_STATUS        }: host_csr_rd_data[31:0] <= csr_dma_st                   [63:32] ; 
            {1'b1,CSR_HOST2HPS_IMG_XFR	}: host_csr_rd_data[31:0] <= csr_host2hps_img_xfr_st      [63:32] ; 
            {1'b1,CSR_HPS2HOST_RSP_SHDW     }: host_csr_rd_data[31:0] <= csr_hps2host_rsp             [31:0 ] ; 
            default:                           host_csr_rd_data[31:0] <= host_csr_rd_data             [31:0 ] ;
         endcase
      end

   end

   else if (axistrx_csr_unalignaddr <= 16'h0158)begin
      host_csr_rd_data    <= {CSR_DATA_WIDTH{1'h0}} ; // if host sw issues a read to non-allocated csr but within the range, data is all 0 s
   end

   else begin
      host_csr_rd_data    <= {CSR_DATA_WIDTH{1'h1}} ; // if host sw issues a read to non-allocated csr and outside the range, data is all F s
   end
end


//HPS CSR Reads
always@(posedge clk)
begin
   if(ce_corereset==1'b1)begin
      hps_csr_rd_data   <= {CE_AXI4MM_DATA_WIDTH{1'h0}};
   end

   else begin
      case({axi4mmrx_csr_ren, axi4mmrx_csr_raddr}) 

            {1'b1,CSR_HOST2HPS_IMG_XFR_SHDW }: hps_csr_rd_data <= csr_host2hps_img_xfr_st[31:0] ; 
            {1'b1,CSR_HPS2HOST_RSP          }: hps_csr_rd_data <= csr_hps2host_rsp              ; 
            {1'b1,CSR_HPS_SCRATCHPAD        }: hps_csr_rd_data <= csr_hps_scratchpad            ; 
            default:                           hps_csr_rd_data <= hps_csr_rd_data               ;
      endcase
   end
end
//----------------------------------------------------------------





//----------------------------------------------------------------
//---Copy Engine Soft Reset Logic---------------------------------
//----------------------------------------------------------------
reg [7:0] ce_softreset_cntr;

always@(posedge clk)
begin
   if(rst==1'b1) begin
      csr_ce_softreset   <= {CSR_DATA_WIDTH{1'h0}};
   end


   else if( (ce_softreset_cntr== 'd220) &&
            (csr_ce_softreset[0]== 1'b1)) begin   
      csr_ce_softreset[0] <= 1'h0;
   end

   else if  ( (axistrx_csr_alignaddr == CSR_CE_SFTRST) && (axistrx_csr_wen == 1'b1)) begin
      if   ( (axistrx_csr_wrdata[0] == 1'b1) && (axistrx_csr_unalignaddr[2]== 1'b0) ) begin
            csr_ce_softreset[0] <= 1'b1;
      end

      if( (axistrx_csr_length == 1'b0) && (axistrx_csr_unalignaddr[2]== 1'b0) ) begin //4B aligned
            csr_ce_softreset[31:1]      <= axistrx_csr_wrdata[31:1]; 
      end

      else if( (axistrx_csr_length == 1'b0) && (axistrx_csr_unalignaddr[2]== 1'b1) ) begin //4B unalgined
            csr_ce_softreset[63:32]      <= axistrx_csr_wrdata[31:0]; 
      end

      else if( (axistrx_csr_length == 1'b1) && (axistrx_csr_unalignaddr[2]== 1'b0) )begin //8B
            csr_ce_softreset[63:1]      <= axistrx_csr_wrdata[63:1]; 
      end
   end
end


always@(posedge clk)
begin
   if(rst==1'b1) begin
      ce_softreset_cntr <= 8'd0;
   end

   else if (ce_softreset_cntr == 8'd220) begin
      ce_softreset_cntr <= 8'd0;
   end

   else if (csr_ce_softreset[0] == 1'b1) begin
      ce_softreset_cntr <= ce_softreset_cntr + 8'd1;
   end
end


always@(posedge clk)
begin
   if(rst==1'b1) begin
      ce_softreset <= 1'd0;
   end

   else if ( (ce_softreset_cntr   == 8'd200) &&
   //if all fsm are in idle state                       
      (csr_ce_softreset[0] == 1'b1 )) begin
      ce_softreset <= 1'd1;
   end

   else if (ce_softreset_cntr == 8'd220) begin
      ce_softreset <= 1'd0;
   end
end
//----------------------------------------------------------------

always@(posedge clk)
begin
   if(ce_corereset==1'b1) begin
      csr_axisttx_datareqlimit      <= 11'd0;
      csr_axisttx_datareqlimit_log2 <= 4'd0;
   end

   else begin
      case(csr_data_req_limit[1:0])
         2'b00:  begin
   	   	           csr_axisttx_datareqlimit      <= 11'd64 ;
   	   	       csr_axisttx_datareqlimit_log2 <= 4'd6   ;
   	   	   	  end
         2'b01: begin
   	   	          csr_axisttx_datareqlimit      <= 11'd128 ;
   	   	          csr_axisttx_datareqlimit_log2 <= 4'd7    ; 
   	   	       end
         2'b10: begin
   	   	          csr_axisttx_datareqlimit      <= 11'd512 ;
   	   	          csr_axisttx_datareqlimit_log2 <= 4'd9    ;
   	   	   	 end
         2'b11: begin
   	   	          csr_axisttx_datareqlimit      <= 11'd1024 ;
   	   	          csr_axisttx_datareqlimit_log2 <= 4'd10    ;
   	   			 end
      endcase
   end
end



assign csr_axisttx_hostaddr    = csr_desc_imgsrc_addr                                   ;  
assign csr_acelitetx_hpsaddr   = csr_desc_imgdst_addr                                   ; 
assign csr_imgxfrsize          = csr_desc_img_size                                      ; 
assign csr_mrdstart            = (csr_dma_st[12:11]!= 2'b10)? csr_desc_mrd_start[0]: 1'b0;  
assign csr_axisttx_rspvalid    = csr_rd_data_valid_t1                                   ;
assign csr_axisttx_rspdata     = host_csr_rd_data                                       ;
assign csr_axi4mmrx_rdata      = hps_csr_rd_data                                        ;
assign csr_axisttx_rspaddr     = csr_addr_t1                                            ;
assign csr_axisttx_rsptag      = csr_tag_t1                                             ;
assign csr_axisttx_length      = csr_length_t1                                          ; 
assign csr_axisttx_reqid       = csr_req_id_t1                                          ;
assign csr_axisttx_rspattr     = csr_attr_t1                                            ;
assign csr_axisttx_tc          = csr_tc_t1                                              ;
assign csr_hpsrdy              = csr_hps2host_rsp[4]                                    ;
assign fifo_err_flag           = ((csr_dma_st[10:9]!= 2'b00) || 
                                 (csr_dma_st[8:7] != 2'b00)) ? 1'b1: 1'b0             ;

endmodule

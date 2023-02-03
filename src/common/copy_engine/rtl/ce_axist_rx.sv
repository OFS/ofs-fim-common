// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Engineer     : Sindhura Medam                       
// Create Date  : Dec 2020
// Module Name  : ce_axist_rx.sv
// Project      : IOFS
// -----------------------------------------------------------------------------
//
// Description: 
//	This block handles host polling/configure of CSR and receive firmware image from host.
//	During a CSR access, this block decodes the address and redirects to the appropriate CSR.
//	Firmware image is send to the FIFO2

// ***************************************************************************

import pcie_ss_hdr_pkg::*;

module ce_axist_rx #( 

   parameter CE_BUS_DATA_WIDTH          = 512,
   parameter CSR_ADDR_WIDTH             = 16, 
   parameter CSR_DATA_WIDTH             = 64, 
   parameter CE_BUS_USER_WIDTH          = 10, 
   parameter TAG_WIDTH                  = 10, 
   parameter REQ_ID_WIDTH               = 16, 
   parameter CE_BUS_STRB_WIDTH          = CE_BUS_DATA_WIDTH>>3
   )(  

   // global signals
   input   logic                               clk                            ,    //Clock Signal
   input   logic                               ce_corereset                   ,    //Combination of hard reset and soft reset
   
   // AXI-ST Rx interface signals
   input   logic                               mux2ce_rx_tvalid               ,    //AXI-ST Valid Signal         
   input   logic                               mux2ce_rx_tlast                ,    //AXI-ST Last signal
   output  logic                               ce2mux_rx_tready               ,    //AXI-ST Ready Signal         
   input   logic  [CE_BUS_DATA_WIDTH-1:0]      mux2ce_rx_tdata                ,    //AXI-ST Data Signal
   input   logic  [CE_BUS_STRB_WIDTH-1:0]      mux2ce_rx_tkeep                ,    //AXI-ST Keep Signal         
   input   logic  [CE_BUS_USER_WIDTH-1:0]      mux2ce_rx_tuser                ,    //AXI-ST User Signal               

   //FIFO2 signals
   output  logic                               axistrx_cpldfifo_wen           ,    //FIFO2 Write enable       
   input   logic                               cpldfifo_axistrx_full          ,    //FIFO2 Full Signal
   input   logic                               cpldfifo_axistrx_almostfull    ,    //FIFO2 almost Full Signal
   output  logic  [576:0]                      axistrx_cpldfifo_wrdata        ,    //FIFO2 Write data
   
   //CSR signals
   input   logic                               csr_axistrx_mrdstart           ,    //Memory Read Start bit
   output  logic                               axistrx_fc                     ,    //Final Completion bit of Completion Header
   output  logic                               axistrx_csr_wen                ,    //CSR write enable
   output  logic                               axistrx_csr_ren                ,    //CSR read enable
   output  logic                               axistrx_csr_length             ,    //PU Mode Request Header- Length Field 
   output  logic  [CSR_ADDR_WIDTH-1:0]         axistrx_csr_alignaddr          ,    //8B Aligned CSR address
   output  logic  [CSR_ADDR_WIDTH-1:0]         axistrx_csr_unalignaddr        ,    //UnAligned CSR address 4Bytes aligned
   output  logic  [CSR_DATA_WIDTH-1:0]         axistrx_csr_wrdata             ,    //CSR Write Data    
   output  logic  [TAG_WIDTH-1:0]              axistrx_csr_rsptag             ,    //PU Mode Request Header- TAG field
   output  logic  [REQ_ID_WIDTH-1:0]           axistrx_csr_reqid              ,    //PU Mode Request Header -Requester ID 
   output  logic  [2:0]                        axistrx_csr_cplstatus          ,    //DM Mode Completion Header - Completion Status
   output  logic  [8:0]                        axistrx_csr_rspatrr            ,    //PU Mode Request Header -Attribute field 
   output  logic  [2:0]                        axistrx_csr_tc                 ,    //PU Mode Request Header- Traffic Class field 

   //AXI-ST Tx signals               
   input   logic                               mmiorspfifo_axistrx_almostfull ,    //FIFO1 almost full   
   output  logic                               axistrx_axisttx_cplerr         ,    //DM Mode Completion Header Error Flag

   //ACE-Lite Tx Signals      
   input   logic                               acelitetx_axistrx_bresperrpulse,    //Ace Lite Write Response Err pulse     
   input   logic                               csr_axistrx_fifoerr            ,    //Fifo overflow and underflow error      
   input   logic  [1:0]                        acelitetx_axistrx_bresp             //Ace Lite Write Response      
);

// ---------------------------------------------------------------------------
// Internal Signal Declaration
// ---------------------------------------------------------------------------

logic                                mux2ce_rx_tlast_q     ;   //Registered(1FF) AXI-ST Last signal
logic                                tlast_q1              ;   //Registered(2FF) AXI-ST valid Last Signal
logic                                mux2ce_rx_tvalid_q    ;   //Registered(1FF) AXI-ST Valid Signal
logic    [CE_BUS_DATA_WIDTH-1:0]     mux2ce_rx_tdata_q     ;   //Registered(1FF) AXI-ST Data Signal
logic    [CE_BUS_STRB_WIDTH-1:0]     mux2ce_rx_tkeep_q     ;   //Registered(1FF) AXI-ST Keep Signal 
logic    [CE_BUS_USER_WIDTH-1:0]     mux2ce_rx_tuser_q     ;   //Registered(1FF) AXI-ST User Signal 

//Header Package Signals
PCIe_PUReqHdr_t                      csrhdr, csrhdr_q      ;   //Power user mode Request header Format
PCIe_CplHdr_t                        cplhdr                ;   //Completion header Format

//Internal signals
logic                                data_byte_q           ;   //Used for Header Detection
logic                                detect_hdr            ;   //Used for Header Detection
logic                                cpl_err_hdr           ;   //Used for Extraction of err
logic    [CSR_DATA_WIDTH-1:0]        csrwrdata, csrwrdata_q;   //CSR Write data
                                                               //status from cpl header
// --------------------------------------------------------------------------

//fsm state declaration
//
typedef enum logic [1:0] {

   AXIST_RX_IDLE         = 2'b00,   //IDLE State
   
   AXIST_RX_CSR_RD       = 2'b01,   //CSR Read Request State

   AXIST_RX_CSR_WR       = 2'b10,   //CSR Write Request State

   AXIST_RX_CPLD_FIFO_WR = 2'b11    //FIFO2 Write State  

} fsm_states;

fsm_states      pstate,nstate;

// ---------------------------------------------------------------------------
// Rx Path
// ---------------------------------------------------------------------------

//Sampling AXI-ST Rx interface Signals
//
always_ff @(posedge clk) 
begin
   if (ce_corereset)
   begin
      mux2ce_rx_tvalid_q   <= 1'd0                     ; 
      mux2ce_rx_tdata_q    <= {CE_BUS_DATA_WIDTH{1'd0}};
      mux2ce_rx_tkeep_q    <= {CE_BUS_STRB_WIDTH{1'd0}};
      mux2ce_rx_tuser_q    <= {CE_BUS_USER_WIDTH{1'd0}}; 
      mux2ce_rx_tlast_q    <= 1'd0                     ;
   end
   else
   begin
      mux2ce_rx_tvalid_q   <=  mux2ce_rx_tvalid & ce2mux_rx_tready; 
      mux2ce_rx_tdata_q    <=  mux2ce_rx_tdata                    ; 
      mux2ce_rx_tkeep_q    <=  mux2ce_rx_tkeep                    ;
      mux2ce_rx_tuser_q    <=  mux2ce_rx_tuser                    ;  
      mux2ce_rx_tlast_q    <=  mux2ce_rx_tlast                    ; 
   end 
end

//assign ce2mux_rx_tready = ((CpldFiFo_AxistRx_cnt >= CE_HST2HPS_FIFO_DEPTH -2'd3) || (MmioRspFiFo_AxistRx_full)) ? 1'b0 :1'b1;

//Axist-Rx ready signal towards Merlin mux
//Copy Engine gives ready on RX interface if and only if both the FIFO1 and FIFO2 are NOT almost full
assign ce2mux_rx_tready = ((cpldfifo_axistrx_almostfull) || (mmiorspfifo_axistrx_almostfull)) ? 1'b0 :1'b1;


// ---------------------------------------------------------------------------
// Header Detection logic
// ---------------------------------------------------------------------------

always_ff @(posedge clk)
begin
   if(ce_corereset)
   begin
      data_byte_q <= 1'b0;
   end
   else if(mux2ce_rx_tvalid_q & mux2ce_rx_tlast_q)
   begin
      data_byte_q <= 1'b0;
   end
   else if(mux2ce_rx_tvalid_q)
   begin
      data_byte_q <= 1'b1;
   end
end

assign detect_hdr = (mux2ce_rx_tvalid_q &  (!data_byte_q)) ? 1'b1 : 1'b0;

//----------------------------------------------------------------------------
// -----Rx FSM Start
// Present State
//----------------------------------------------------------------------------

always_ff@(posedge clk)
begin
   if(ce_corereset)
   begin
      pstate <= AXIST_RX_IDLE;
   end
   else
   begin
      pstate <= nstate;
   end
end

//---------------------------------------------------------------------------
// Next State
//---------------------------------------------------------------------------

always_comb
begin
   if (acelitetx_axistrx_bresperrpulse || cpl_err_hdr ) // state transition to IDLE if any error condition occurs  
   begin
      nstate = AXIST_RX_IDLE;
   end
   else
   begin
      case(pstate)
   
         AXIST_RX_IDLE             :   if(detect_hdr && ((csrhdr.fmt_type == M_RD) || (csrhdr.fmt_type == DM_RD)))  
                              begin
                                 nstate = AXIST_RX_CSR_RD;
                              end
                              else if(detect_hdr && ((csrhdr.fmt_type == M_WR) || (csrhdr.fmt_type == DM_WR))) 
                              begin 
                                 nstate = AXIST_RX_CSR_WR;
                              end
                              else if(detect_hdr && (cplhdr.fmt_type == DM_CPL) && csr_axistrx_mrdstart && (acelitetx_axistrx_bresp == 2'b00) && (!axistrx_axisttx_cplerr) && (!csr_axistrx_fifoerr)) 
                              begin
                                 nstate = AXIST_RX_CPLD_FIFO_WR;
                              end
                              else  
                              begin 
                                 nstate = AXIST_RX_IDLE;
                              end
         
         AXIST_RX_CSR_RD           :   if(detect_hdr && ((csrhdr.fmt_type == M_WR) || (csrhdr.fmt_type == DM_WR))) 
                              begin 
                                 nstate = AXIST_RX_CSR_WR;
                              end
                              else if  (detect_hdr && (cplhdr.fmt_type == DM_CPL) && csr_axistrx_mrdstart && 
                                       (acelitetx_axistrx_bresp == 2'b00) && (!axistrx_axisttx_cplerr) && (!csr_axistrx_fifoerr)) 
                              begin 
                                 nstate = AXIST_RX_CPLD_FIFO_WR;
                              end
                              else if(detect_hdr && ((csrhdr.fmt_type == M_RD) || (csrhdr.fmt_type == DM_RD))) //outstanding CSR Reads
                              begin
                                 nstate = AXIST_RX_CSR_RD;
                              end
                              else 
                              begin 
                                 nstate = AXIST_RX_IDLE;
                              end
                                    
         AXIST_RX_CSR_WR           :   if(detect_hdr && ((csrhdr.fmt_type == M_RD) || (csrhdr.fmt_type == DM_RD)))
                              begin
                                 nstate = AXIST_RX_CSR_RD;
                              end
                              else if  (detect_hdr && (cplhdr.fmt_type == DM_CPL) && csr_axistrx_mrdstart && 
                                       (acelitetx_axistrx_bresp == 2'b00) && (!axistrx_axisttx_cplerr) && (!csr_axistrx_fifoerr))
                              begin 
                                 nstate = AXIST_RX_CPLD_FIFO_WR;
                              end
                              else if(detect_hdr && ((csrhdr.fmt_type == M_WR) || (csrhdr.fmt_type == DM_WR))) //Outstanding CSR Writes
                              begin 
                                 nstate = AXIST_RX_CSR_WR;
                              end
                              else 
                              begin 
                                 nstate = AXIST_RX_IDLE;
                              end

         AXIST_RX_CPLD_FIFO_WR     :   if(detect_hdr && ((csrhdr.fmt_type == M_RD) || (csrhdr.fmt_type == DM_RD)))  
                              begin 
                                 nstate = AXIST_RX_CSR_RD;
                              end
                              else if(detect_hdr && ((csrhdr.fmt_type == M_WR) || (csrhdr.fmt_type == DM_WR)))
                              begin 
                                 nstate = AXIST_RX_CSR_WR;
                              end
                              else if((tlast_q1) && (!(detect_hdr && (cplhdr.fmt_type == DM_CPL)))) 
                              begin 
                                 nstate = AXIST_RX_IDLE;
                              end
                              else //Outstanding DMA Completions 
                              begin
                                 nstate = AXIST_RX_CPLD_FIFO_WR;
                              end

         default          :   nstate = AXIST_RX_IDLE;

      endcase
   end
end

// ---------------------------------------------------------------------------
// CSR Path
// ---------------------------------------------------------------------------

//Capturing CSR header(256bits) and CSR data(64-bits)
// 
always_comb
begin
   csrhdr     = (detect_hdr) ? mux2ce_rx_tdata_q [255:0] : 256'd0                              ;  
   csrwrdata  = (detect_hdr) ? mux2ce_rx_tdata_q [256+:CSR_DATA_WIDTH] : {CSR_DATA_WIDTH{1'd0}};
end

//Sampling the CSR Header and CSR data
//
always_ff @(posedge clk) 
begin
   if (ce_corereset)
   begin
      csrhdr_q       <= 256'd0                ;
      csrwrdata_q    <= {CSR_DATA_WIDTH{1'd0}};
   end
   else
   begin
      csrhdr_q       <=  csrhdr   ;
      csrwrdata_q    <=  csrwrdata;
   end 
end

// ---------------------------------------------------------------------------
//CSR Access parameters
// ---------------------------------------------------------------------------
assign  axistrx_csr_wen      = (pstate == AXIST_RX_CSR_WR) ? 1'b1 :1'b0                                                            ;
assign  axistrx_csr_ren      = (pstate == AXIST_RX_CSR_RD) ? 1'b1 :1'b0                                                            ;
assign  axistrx_csr_wrdata   = (pstate == AXIST_RX_CSR_WR) ? csrwrdata_q :{CSR_DATA_WIDTH{1'd0}}                                   ;
assign  axistrx_csr_rsptag   = (pstate == AXIST_RX_CSR_RD) ? {csrhdr_q.tag_h, csrhdr_q.tag_m, csrhdr_q.tag_l} : {TAG_WIDTH{1'd0}}  ;
assign  axistrx_csr_reqid    = (pstate == AXIST_RX_CSR_RD) ? {csrhdr_q.req_id} : {REQ_ID_WIDTH{1'd0}}                              ;
assign  axistrx_csr_length   = ((pstate == AXIST_RX_CSR_RD) || (pstate == AXIST_RX_CSR_WR))  ? ((csrhdr_q.length > 1) ?  1'b1 : 1'b0) : 1'b0; //Length in DWs : 1=> 2DWs and 0=> 1DW in this case 
assign  axistrx_csr_rspatrr  = (pstate == AXIST_RX_CSR_RD) ? (csrhdr_q.attr) : 9'd0                                                ; 
assign  axistrx_csr_tc       = (pstate == AXIST_RX_CSR_RD) ? (csrhdr_q.TC)   : 3'd0                                                ; 

always_comb
begin
   if(((pstate == AXIST_RX_CSR_RD) && (csrhdr_q.fmt_type == M_RD)) || ((pstate == AXIST_RX_CSR_WR) && (csrhdr_q.fmt_type == M_WR))) //3DW -Power User Mode
   begin
      axistrx_csr_alignaddr   = {4'd0,csrhdr_q.host_addr_h[11:3], 3'b000}; //8B aligned
      axistrx_csr_unalignaddr = {4'd0,csrhdr_q.host_addr_h[11:0]}        ;
   end
   else if(((pstate == AXIST_RX_CSR_RD) && (csrhdr_q.fmt_type == DM_RD)) || ((pstate == AXIST_RX_CSR_WR) && (csrhdr_q.fmt_type == DM_WR))) //4DW -Power User Mode
   begin
      axistrx_csr_alignaddr   = {4'd0,csrhdr_q.host_addr_l[9:1], 3'b000}; 
      //axistrx_csr_unalignaddr = {4'd0, csrhdr_q.host_addr_l[11:0]}      ; 
      axistrx_csr_unalignaddr = {4'd0, csrhdr_q.host_addr_l[9:0],2'b00}   ; 
   end
   else 
   begin
      axistrx_csr_alignaddr  = {CSR_ADDR_WIDTH{1'd0}};
      axistrx_csr_unalignaddr= {CSR_ADDR_WIDTH{1'd0}};
   end
end
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// Receiving Firmware image (CPLD from Host) 
// ---------------------------------------------------------------------------

//header capture
assign cplhdr = mux2ce_rx_tvalid_q ? mux2ce_rx_tdata_q [255:0] : 256'd0;

// tdata concatenation logic for Writing into FIFO2 
logic [CE_BUS_DATA_WIDTH-1:0] tdata_q1                   ;
logic [CE_BUS_DATA_WIDTH-1:0] tdata_concat_q,tdata_concat;

//Sampling the valid mux2ce_rx_tdata_q
//
always_ff @(posedge clk) 
begin
   if (ce_corereset)
   begin
      tdata_q1   <= {CE_BUS_DATA_WIDTH{1'd0}};
   end
   else if(mux2ce_rx_tvalid_q)
   begin
      tdata_q1   <= mux2ce_rx_tdata_q        ;
   end
end

//tdata concatenation
//example shown with 64bits for simplicity
//---------------------AABB_CCDD -  data0+header
//---------------------1122_3344 -  data1       
//---------------------5566_7788 -  data2       
//---------------------99AA_BBDD -  data3       
//---------------------00FF_FF00 -  data4 - last data
//
//----------------------data concatenation is {dataN[255:0],dataN-1[511:256]} 
//----------------------{3344,AABB}  {7788,1122}  {BBDD,5566}  {FF00, 99AA}  {0000,00FF}
//tkeep concatenation is also in the similar fashion

assign tdata_concat =   ((pstate == AXIST_RX_CPLD_FIFO_WR) && tlast_q1)           ? {256'd0,tdata_q1[511:256]}                    :                //for the last tdata received,zero padding is done to upper 256bits  
                        ((pstate == AXIST_RX_CPLD_FIFO_WR) && mux2ce_rx_tvalid_q) ? {mux2ce_rx_tdata_q[255:0], tdata_q1[511:256]} : tdata_concat_q;//Concatenating lower 256 bits of current tdata and upper 256 bits of previous tdata


//Sampling the Concatenated tdata
//
always_ff @(posedge clk) 
begin
   if (ce_corereset)
   begin
      tdata_concat_q   <= {CE_BUS_DATA_WIDTH{1'd0}};
   end
   else 
   begin
      tdata_concat_q   <= tdata_concat;
   end
end

//Sampling the Valid mux2ce_rx_tlast_q
//
always_ff @(posedge clk) 
begin
   if (ce_corereset)
   begin
      tlast_q1   <= 1'd0; 
   end
   else 
   begin
      tlast_q1   <= mux2ce_rx_tvalid_q & mux2ce_rx_tlast_q;
   end
end

// ---------------------------------------------------------------------------
// tkeep concatenation logic for Writing into FIFO2 
// ---------------------------------------------------------------------------

logic [CE_BUS_STRB_WIDTH-1:0] tkeep_q1                   ;
logic [CE_BUS_STRB_WIDTH-1:0] tkeep_concat_q,tkeep_concat;

//Sampling the valid mux2ce_rx_tkeep_q
//
always_ff @(posedge clk) 
begin
   if (ce_corereset)
   begin
      tkeep_q1   <= {CE_BUS_STRB_WIDTH{1'd0}};
   end
   else if(mux2ce_rx_tvalid_q)
   begin
      tkeep_q1   <= mux2ce_rx_tkeep_q        ;
   end
end

//Please check tdata concatenation example shown above. tkeep concatenation follows the same fashion
//
assign tkeep_concat =   ((pstate == AXIST_RX_CPLD_FIFO_WR) && tlast_q1) ? {32'd0,tkeep_q1[63:32]} :                                             //for the last tkeep received,zero padding is done to upper 32bits  
                        ((pstate == AXIST_RX_CPLD_FIFO_WR) && mux2ce_rx_tvalid_q) ? {mux2ce_rx_tkeep_q[31:0], tkeep_q1[63:32]} : tkeep_concat_q;//Concatenating lower 32 bits of current tkeep and upper 32bits of previous tkeep

//Sampling the Concatenated tkeep 
//
always_ff @(posedge clk) 
begin
   if (ce_corereset)
   begin
      tkeep_concat_q   <= {CE_BUS_STRB_WIDTH{1'd0}};
   end
   else 
   begin
      tkeep_concat_q   <= tkeep_concat             ;
   end
end

//------------------------------------------------------------------------
// CE FIFO2 Write Enable & Write data logic
//when FIFO2 is almost full, we no longer give tready to Rx interface.
//check ce2mux_rx_tready generation
//------------------------------------------------------------------------

logic mask_wren;

assign mask_wren = tlast_q1 && (tkeep_q1[63:32] == 32'd0) ;

assign axistrx_cpldfifo_wen    =  ((pstate == AXIST_RX_CPLD_FIFO_WR) && (mux2ce_rx_tvalid_q || tlast_q1 ) && (!cpldfifo_axistrx_full) && (!mask_wren)) ? 1'b1 : 1'b0; 
assign axistrx_cpldfifo_wrdata =  ((pstate == AXIST_RX_CPLD_FIFO_WR) && (mux2ce_rx_tvalid_q || tlast_q1 ) && (!cpldfifo_axistrx_full)) ? {axistrx_fc,tdata_concat,tkeep_concat} : 577'd0;

//-----------------------------------------------------------
// Bytecount logic for counting the number of bytes received
//-----------------------------------------------------------
//logic    [31:0]               byte_count_q          ;
//
//always_ff @(posedge clk) 
//begin
//    if (ce_corereset) 
//    begin
//        byte_count_q    <= 32'd0;   
//    end
//    else if(byte_count_q >=csr_ImgXfrSize[31:0])
//    begin
//        byte_count_q    <= 32'd0;   
//    end
//    else if((pstate == AXIST_RX_CPLD_FIFO_WR) && mux2ce_rx_tvalid_q && mux2ce_rx_tlast_q && (!(detect_hdr && (csrhdr.fmt_type == M_WR))))
//    begin
//        byte_count_q    <= byte_count_q+32'd32;	
//    end
//    begin
//        byte_count_q    <= byte_count_q+32'd64;	
//    end
//end

//---------------------------------------------------------------------------------------
// Extraction of Final completion(FC) information from DM_CPL Header
// Copy Engine doesn't send outstanding read request to host         
// Once complete data of current request is received succesfully (Final completion bit 
// is HIGH and completion status is 3'b000) and
// once FIFO2 has sufficient space, the next read request is initiated to host
// Host might send multiple completions to copy engine (with multiple completion headers for a given read request)
// For each header packet received, FC bit is checked
// detect_hdr signal in this block detects the header packet in tdata
//---------------------------------------------------------------------------------------

logic fc_st;
logic fc_q ;
logic fc_q1;

assign fc_st = (detect_hdr && (cplhdr.fmt_type == DM_CPL) && (cplhdr.cpl_status == 3'b000) && csr_axistrx_mrdstart && (cplhdr.FC));

always_ff @(posedge clk) 
begin
   if (ce_corereset)
   begin
      fc_q    <= 1'd0 ;   
   end
   else if(mux2ce_rx_tvalid_q & mux2ce_rx_tlast_q)
   //else if(tlast_q1 ) //temp
   begin
      fc_q    <= 1'd0 ;   
   end
   else if(fc_st == 1'b1)
   begin
      fc_q    <= 1'd1 ;   
   end
end

always_ff @(posedge clk) 
begin
   if (ce_corereset)
   begin
      fc_q1   <= 1'd0; 
   end
   else 
   begin
      fc_q1   <= mux2ce_rx_tvalid_q & mux2ce_rx_tlast_q & fc_q;
   end
end


//assign axistrx_fc = (csr_axistrx_mrdstart & mux2ce_rx_tvalid_q & mux2ce_rx_tlast_q & fc_q) ? 1'b1 : 1'b0; 
//assign axistrx_fc = (csr_axistrx_mrdstart && tlast_q1 && fc_q) ? 1'b1 : 1'b0;  

assign axistrx_fc =  (mux2ce_rx_tvalid_q && mux2ce_rx_tlast_q && (mux2ce_rx_tkeep_q[63:32] == 32'd0)) ? fc_q :
                     (tlast_q1  && !mask_wren) ? fc_q1 : 1'b0;

//--------------------------------------------------------------------------
// For each completion header packet received, completion status is checked
// If status is not successful, this is captured in a CSR
// No further transactions are done by copy engine
// host sw should soft reset the copy engine
//--------------------------------------------------------------------------

assign cpl_err_hdr = (detect_hdr && (cplhdr.fmt_type == DM_CPL) && (cplhdr.cpl_status != 3'b000) && csr_axistrx_mrdstart) ? 1'b1 : 1'b0;

always_ff @(posedge clk) 
begin
   if (ce_corereset) 
   begin
      axistrx_axisttx_cplerr    <= 1'b0;   
   end
   else if(cpl_err_hdr) 
   begin
      axistrx_axisttx_cplerr    <= 1'b1;
   end
end

always_ff @(posedge clk)
begin
   if (ce_corereset) 
   begin
      axistrx_csr_cplstatus    <= 3'b000            ;   
   end
   else if(csr_axistrx_mrdstart && detect_hdr && (cplhdr.fmt_type == DM_CPL))
   begin
      axistrx_csr_cplstatus    <=  cplhdr.cpl_status;
   end
end

endmodule

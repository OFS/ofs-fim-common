// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Engineer     : Liaqat Parakundil	               
// Create Date  : Dec 2020
// Module Name  : ce_axist_tx.sv
// Project      : IOFS AC
// -----------------------------------------------------------------------------
//
// Description: 
//Does the following job
//       1. Creates transmitter packets for host DDR read access and CSR read data(MMIO Read request completion)
//       2. Calculates addresses for subsequent read request to host
// ***************************************************************************
import pcie_ss_hdr_pkg::*;

module ce_axist_tx #(      
   parameter CE_BUS_DATA_WIDTH       = 512                  ,
   parameter CE_BUS_STRB_WIDTH       = CE_BUS_DATA_WIDTH >>3,
   parameter CE_MMIO_RSP_FIFO_DEPTH  = 5                    ,
   parameter CE_HST2HPS_FIFO_DEPTH   = 8                    ,
   parameter CSR_ADDR_WIDTH          = 16                   , 
   parameter CSR_DATA_WIDTH          = 64                   , 
   parameter CE_BUS_USER_WIDTH       = 10                   , 
   parameter TAG_WIDTH               = 10                   , 
   parameter REQ_ID_WIDTH            = 16                   , 
   parameter CE_MMIO_RSP_FIFO_THRHLD = 4                    ,
   parameter CE_PF_ID                = 4                    ,
   parameter CE_VF_ID                = 0                    ,
   parameter CE_VF_ACTIVE            = 0   
)(
   // global signals/from top block
   input   logic                              clk                               ,   //system clock 350MHz
   input   logic                              ce_corereset                      ,   //Active high reset- Hard reset+soft reset
   // From/to CSR
   //csr2tx --> csr block to Tx block
   input logic                                csr_axisttx_mrdstart              ,   //MRD Start bit
   input wire                                 csr_axisttx_fifoerr               ,   //FIFO error flag   
   input logic                                csr_axisttx_hpsrdy                ,   //HPS Ready bit
   input logic                                csr_axisttx_rspvalid              ,   //flag to write to MMIO respose fifo
   output logic                               axisttx_csr_dmaerr                ,   //flag to reset mrd start
   output wire                                axisttx_csr_mmiofifooverflow      ,   //FIFO1 overflow flag                                   
   output wire                                axisttx_csr_mmiofifounderflow     ,   //FIFO1 underflow flag                                  
   input logic                                csr_axisttx_length                ,   //CSR Length field               
   input logic    [CSR_ADDR_WIDTH-1:0     ]   csr_axisttx_rspaddr               ,   //CSR Response addr
   input logic    [CSR_DATA_WIDTH-1:0     ]   csr_axisttx_rspdata               ,   //CSR read data[63:0]
   input logic    [CSR_DATA_WIDTH/8 -1:0  ]   csr_axisttx_tkeep                 ,   //CSR read data strobe 
   input logic    [TAG_WIDTH-1:0          ]   csr_axisttx_rsptag                ,   //CSR tag                     
   input logic    [REQ_ID_WIDTH-1:0       ]   csr_axisttx_reqid                 ,   //CSR requester ID            
   input logic    [8:0                    ]   csr_axisttx_rspattr               ,   //CSR attribute               
   input logic    [2:0                    ]   csr_axisttx_tc                    ,   //CSR traffic class               
   input logic    [10:0                   ]   csr_axisttx_datareqlimit          ,   //data req limit                  
   input logic    [3:0                    ]   csr_axisttx_datareqlimit_log2     ,   //data req limit- log2                  
   input logic    [CSR_DATA_WIDTH-1:0     ]   csr_axisttx_hostaddr              ,   //host DDR Start address
   input logic    [CSR_DATA_WIDTH-1:0     ]   csr_axisttx_imgxfrsize            ,   //host Read request size
   input logic    [1:0                    ]   acelitetx_axisttx_bresp           ,   //Ace Lite Write Response
   //from/to rx block
   input logic                                axistrx_axisttx_fc                ,   //Final completion bit in completion header format             
   input logic                                axistrx_csr_ren                   ,   //Immediate Flag for CSR completion service                           
   output wire                                mmiorspfifo_axistrx_almostfull    ,   //FIFO1 full flag
   input  logic                               axistrx_axisttx_cplerr            ,   //cpl error status in completion header format
   input  logic                               acelitetx_axisttx_req_en          ,   //request Enable- ce can issue read req to host
   // AXI-ST Tx interface signals
   //ce2mux --> copy engine to mux
   //mux2ce --> mux to copy engine
   output  logic                             ce2mux_tx_tvalid                   ,   //valid signal         
   input   logic                             mux2ce_tx_tready                   ,   //ready signal          
   output  logic                             ce2mux_tx_tlast                    ,   //last signal 
   output  logic  [CE_BUS_DATA_WIDTH-1:0]    ce2mux_tx_tdata                    ,   //data signal           
   output  logic  [CE_BUS_STRB_WIDTH-1:0]    ce2mux_tx_tkeep                    ,   //keep signal          
   output  logic  [CE_BUS_USER_WIDTH-1:0]    ce2mux_tx_tuser                        //user signal      
);

//------------------------------------------------------------------
//Signal Declarations
//------------------------------------------------------------------

PCIe_ReqHdr_t hostrdreqhdr  ;//host Read request Format
PCIe_PUCplHdr_t hostcsrrdhdr;//CSR Read data Completion Format



//------------------------------------------------------------------
//FSM States
typedef enum logic [3:0] {
   ST_TX_IDLE               = 4'b0000,   //IDLE state    

   ST_TX_CSR_INIT           = 4'b0001,   //CSR initialization state.
                                          //Master signals are asserted here
   ST_TX_RD_REQ_CALC        = 4'b0010,   //Read request Calculation state
                                          //address, size, length are captured here
   ST_TX_RD_REQ_INIT        = 4'b0011,   //host DDR Read request initilization state
                                          //Master signals are asserted here
   ST_TX_CSR_WAIT_RDY       = 4'b0100,   //Wait for ready state-CSR completions
                                          //Master signals hold the value
   ST_TX_RD_REQ_WAIT_RDY    = 4'b0101,   //Wait for ready state - host DDR Read request
   ST_TX_RD_REQ_DONE        = 4'b0110,   //host DDR Read request done state
                                          //next transfer control signals(for total request count>1)
                                          //are incremented here
   ST_TX_CSR_CPLD_DONE      = 4'b0111,   //CSR completion with data done state
                                          //CSR Read data requested sent to host              
   ST_TX_DATA_WAIT          = 4'b1000    //CSR completion with data done state
} tx_states;                         

tx_states   p_state,n_state; //handle for present state & next state respectively


//------------------------------------------------------------------
//-CSR CPLD FIFO Logic----------------------------------------------
//------------------------------------------------------------------
wire                                                         mmio_rsp_fifo_wen  ; //FIFO Write enable
wire                                                         mmio_rsp_fifo_full ; //FIFO full
logic                                                        mmio_rsp_fifo_ren  ; //FIFO Read Enable
wire                                                         mmio_rsp_fifo_noemp; //FIFO empty flag (1= has data, 0=empty)
wire                                                         mmio_rsp_fifo_err  ; //FIFO error flag                            
wire [(CE_BUS_DATA_WIDTH+(CSR_DATA_WIDTH>>3))-1:0      ]     mmio_rsp_fifo_wdata; //FIFO Write data
wire [(CE_BUS_DATA_WIDTH+(CSR_DATA_WIDTH>>3))-1:0      ]     axist_csr_dout     ; //FIFO Write data
//wire [CE_MMIO_RSP_FIFO_DEPTH-1:0 ]     mmiorspfifo_cnt    ;

//CSR read data=64bits and header=256bits, appending zeros to match data bus widht
assign mmio_rsp_fifo_wdata   = {192'h0,csr_axisttx_rspdata,hostcsrrdhdr,csr_axisttx_tkeep}; 
assign mmio_rsp_fifo_wen     = (mmio_rsp_fifo_full ==1'b0) ? csr_axisttx_rspvalid: 1'b0   ; 

//this FIFO contains CSR Read data Packet
//bfifo
//  #(.WIDTH             (CE_BUS_DATA_WIDTH      ),
//    .DEPTH             (CE_MMIO_RSP_FIFO_DEPTH ),
//    .FULL_THRESHOLD    (CE_MMIO_RSP_FIFO_THRHLD),       
//    .REG_OUT           (1                      ), 
//    .GRAM_STYLE        (0                      ), //TBD
//    .BITS_PER_PARITY   (32                     )
//  )
//  mmio_rsp_fifo
//  (
//    .fifo_din          (mmio_rsp_fifo_wdata   ),
//    .fifo_wen          (mmio_rsp_fifo_wen     ),
//    .fifo_ren          (mmio_rsp_fifo_ren     ),
//
//    .clk               (clk                   ),
//    .Resetb            (!ce_corereset            ),
//                   
//    .fifo_out          (                      ), //unused port
//    .fifo_dout         (axist_csr_dout        ),       
//    .fifo_count        (mmiorspfifo_cnt       ),
//    .full              (mmio_rsp_fifo_full    ),
//    .not_empty         (mmio_rsp_fifo_noemp   ),
//    .not_empty_out     (                      ), //unused port 
//    .not_empty_dup     (                      ), //unused port
//    .fifo_err          (                      ), //unused port
//    .fifo_perr         (                      )  //unused port
//  );
quartus_bfifo
#(.WIDTH             (CE_BUS_DATA_WIDTH+(CSR_DATA_WIDTH>>3)),
   .DEPTH             (CE_MMIO_RSP_FIFO_DEPTH               ),
   .FULL_THRESHOLD    (CE_MMIO_RSP_FIFO_THRHLD              ),
   .REG_OUT           (1                                    ), 
   .RAM_STYLE         ("AUTO"                               ), 
   .ECC_EN            (0                                    )
)
   mmio_rsp_fifo
(
   .fifo_din          (mmio_rsp_fifo_wdata           ),
   .fifo_wen          (mmio_rsp_fifo_wen             ),
   .fifo_ren          (mmio_rsp_fifo_ren             ),
   .clk               (clk                           ),
   .Resetb            (!ce_corereset                 ),
   .fifo_dout         (axist_csr_dout                ),       
   .fifo_count        (                              ),
   .full              (mmio_rsp_fifo_full            ),
   .almost_full       (mmiorspfifo_axistrx_almostfull),
   .not_empty         (mmio_rsp_fifo_noemp           ),
   .almost_empty      (                              ),
   .fifo_eccstatus    (                              ),
   .fifo_err          (mmio_rsp_fifo_err             )
);

logic axistrx_axisttx_fc_q;

always_ff@(posedge clk) begin
   if(ce_corereset ==1) begin
         axistrx_axisttx_fc_q<=1'b0;
   end
   else begin
         axistrx_axisttx_fc_q<=axistrx_axisttx_fc;
   end
end
//------------------------------------------------------------------

//------------------------------------------------------------------
//--TX FSM START----------------------------------------------------
//Three Always block FSM coding style- Registered output
//------------------------------------------------------------------
logic  [31:0] total_req_count ; //Total host Read request count required
                                 //Calcuated per descriptor programming by host
logic  [31:0] curr_req_count  ; //Current host Read request count
                                 //Increments after every host read request sent
logic  [63:0] next_addr       ; //HOST DDR Read address
                                 //Increments after every host read request sent
logic  [31:0] curr_size       ; //HOST DDR Read current request size
logic  [23:0] next_size       ; //HOST DDR Read request size
                                 //Increments after every host read request sent
//logic  [9:0]  next_tid        ; //host DDR Read request tag
                                 //Increments after every host read request sent
logic [31:0]  rx_data_pkt_cnt;
logic         csr_cpld_alert  ; //CSR completion has highest precedence
//-------------------------------
//-This flag helps to understand
//if any host csr read request is 
//sent to ce. csr completions
//are given the highest priority
//-------------------------------
always_ff@(posedge clk) begin
   if(ce_corereset ==1) begin
         csr_cpld_alert <=1'b0;
   end

   else if(axistrx_csr_ren == 1'b1) begin
         csr_cpld_alert <= 1'b1;
   end
   else if(p_state == ST_TX_CSR_CPLD_DONE) begin
         csr_cpld_alert <= 1'b0;
   end
end
//-------------------------------



//-------------------------------
//DMA prgoress is checked here
//This logic helps to check if ce
//received final completion bit in the completion
//header for a given
//read request issued to host
//-------------------------------
logic dma_in_progress;

always_ff@(posedge clk) begin

   if(ce_corereset ==1) begin
         dma_in_progress <= 1'b0;
   end
   else if(( ( (rx_data_pkt_cnt      == total_req_count) &&
            (csr_axisttx_mrdstart == 1'b0           ) )   //complete data received as per the csr_img_size. No more read to be issued to host 
                        ||
            ((axistrx_axisttx_fc_q == 1'b1          ) &&  //Intermediate state: final completion received
            (rx_data_pkt_cnt      < total_req_count)))   //for the current request sent. Further read to be issued to host
                        ||
            (axistrx_axisttx_cplerr  ==1'b1) ||       //error at AXIST rx side- ce soft reset expected
            (csr_axisttx_fifoerr     ==1'b1) ||       //FIFO1 & FIFO2 not healthy!- ce soft reset expected
            (acelitetx_axisttx_bresp!=2'b00)) begin   //error at Acelite Tx side- ce soft reset expected
         dma_in_progress <= 1'b0;
   end
   else if(p_state == ST_TX_RD_REQ_DONE/*ST_TX_DATA_WAIT*/) begin //CE issued a read req to host & waiting for the completions from host
                                             //no outstanding read req is issued to host                           
                                             //once the completion for the give read request is received & written 
                                             //to HPS successfully then only ce issues the next read request to host
         dma_in_progress <= 1'b1;
   end
end
//-------------------------------


//-------------------------------
//Clocked Present state logic        
//-------------------------------
always_ff@(posedge clk) begin
   if(ce_corereset ==1) begin
         p_state   <= ST_TX_IDLE;
   end

   else begin
         p_state   <= n_state;
   end
end
//-------------------------------


//-------------------------------
//combo logic for next state
//-------------------------------
always_comb begin
   n_state= p_state;
   case(p_state)
         ST_TX_IDLE:
         begin
            if(mmio_rsp_fifo_noemp ==1) begin //FIFO1 has at least one CSR completion data
               n_state= ST_TX_CSR_INIT;
            end
            else if(( dma_in_progress == 1'b1) && (csr_cpld_alert == 1'b0)) begin  //If ce receives any csr read req from the host
               n_state = ST_TX_DATA_WAIT;                                          //while waiting for the FC bit(data wait state) 
                                                                                    //for the given read request sent to host,
                                                                                    //we service CSR completion first and then go back to this wait state
            end

            else if( (csr_axisttx_mrdstart       == 1'b1  )  && //descriptors are already pgmd by host 
                     (axistrx_axisttx_cplerr     == 1'b0  )  && //no error at AXIST rx side
                     (acelitetx_axisttx_bresp    == 2'b00 )  && //no error at ACELITE Tx side
                     (csr_axisttx_fifoerr        == 1'b0  )  && //FIFO1 and FIFO2 are healthy!
                     (csr_cpld_alert             == 1'b0  )  && //no current csr read req from host to ce
                     (acelitetx_axisttx_req_en   == 1'b1  )  && //CE can issue the rd req to host-
                                                                  //successfully written previous completions to HPS/this is first read req to host
                     (csr_axisttx_hpsrdy         == 1'b1  )   ) //HPS is ready to receive firmware image.
                                                                  //Extra safe guard                             
                                                                  //can exclude in coverage points               
               begin
                  n_state= ST_TX_RD_REQ_CALC;
               end
            else begin
               n_state= ST_TX_IDLE;
            end
         end

         ST_TX_CSR_INIT:
         begin
            if(mux2ce_tx_tready ==1'b1) begin //Ready-Valid handshake 
               n_state=ST_TX_CSR_CPLD_DONE;
            end
            else begin //No ready
               n_state= ST_TX_CSR_WAIT_RDY;
            end
         end

         ST_TX_RD_REQ_CALC:
         begin
            n_state = ST_TX_RD_REQ_INIT;
         end

         ST_TX_RD_REQ_INIT:
         begin
            if(mux2ce_tx_tready==1'b1) begin //Ready-Valid handshake
               n_state= ST_TX_RD_REQ_DONE;
            end
            else begin//No ready
               n_state= ST_TX_RD_REQ_WAIT_RDY;
            end
         end

         ST_TX_CSR_WAIT_RDY:
         begin
            if(mux2ce_tx_tready==1'b1) begin //Ready-Valid handshake
               n_state= ST_TX_CSR_CPLD_DONE;
            end

            else begin//No ready
               n_state= ST_TX_CSR_WAIT_RDY;
            end
         end

         ST_TX_RD_REQ_WAIT_RDY:
         begin
            if(mux2ce_tx_tready==1'b1) begin //Ready-Valid handshake
               n_state= ST_TX_RD_REQ_DONE;
            end

            else begin//No ready
               n_state= ST_TX_RD_REQ_WAIT_RDY;
            end
         end
         ST_TX_CSR_CPLD_DONE:
         begin
            n_state = ST_TX_IDLE;
         end

         ST_TX_RD_REQ_DONE:
         begin
            n_state = ST_TX_DATA_WAIT;
         end

         ST_TX_DATA_WAIT:
         begin
            if(( ((rx_data_pkt_cnt      == total_req_count) &&//complete data received as per the csr_img_size. No more read to be issued to host 
                  (csr_axisttx_mrdstart == 1'b0           ) )
                              ||
                  ((axistrx_axisttx_fc_q || ~dma_in_progress         ) && //Intermediate state: final completion received
                  (rx_data_pkt_cnt      < total_req_count)))  //for the current request sent. Further read to be issued to host
                              ||
                  (axistrx_axisttx_cplerr==1'b1)           //error at AXIST RX side- ce soft reset expected
                              ||
                  (csr_cpld_alert==1'b1)                   //while waiting for the FC bit for the read request sent from ce to host,
                                                            //a csr read request is initiated from host to ce. csr completion has highest priority 
                                                            //will get back to ST_TX_DATA_WAIT state once the csr req is serviced                                
                              ||
                  (csr_axisttx_fifoerr== 1'b1)             //FIFOs are not healthy!- ce soft reset expected
                              ||
                  (acelitetx_axisttx_bresp!=2'b00)) begin          //error at ACELITE TX side- ce soft reset expected 
                     n_state = ST_TX_IDLE;
            end
            else begin//CE is waiting for the FC bit of the given read request from ce to host         
                     n_state = ST_TX_DATA_WAIT;         
            end
         end
   endcase

end
//-------------------------------

//-------------------------------
//-next-output logic and regsiters
//-------------------------------
always_ff@(posedge clk) begin

   if(ce_corereset ==1) begin
         ce2mux_tx_tvalid    <= 1'b0                     ;
         ce2mux_tx_tkeep     <= {CE_BUS_STRB_WIDTH{1'b0}};
         ce2mux_tx_tlast     <= 1'b0                     ;
         ce2mux_tx_tuser     <= {CE_BUS_USER_WIDTH{1'd0}}; 
         ce2mux_tx_tdata     <= {CE_BUS_DATA_WIDTH{1'h0}};
         mmio_rsp_fifo_ren   <= 1'b0                     ; 
         curr_req_count      <= 32'd0                    ;
         next_addr           <= 64'h0                    ;
         next_size           <= 24'h0                    ;
         curr_size           <= 32'h0                    ;
         //next_tid            <= 10'h0                     ;
         total_req_count     <= 32'd0                    ;
         //rx_data_pkt_cnt     <= 32'd0                    ;
         axisttx_csr_dmaerr  <= 1'b0                     ;
   end
   else begin
         case(n_state)
            ST_TX_IDLE: begin
               ce2mux_tx_tvalid    <= 1'b0                      ;
               ce2mux_tx_tkeep     <= {CE_BUS_STRB_WIDTH{1'b0}} ;
               ce2mux_tx_tlast     <= 1'b0                      ;
               ce2mux_tx_tuser     <= {CE_BUS_USER_WIDTH{1'd0}} ;
               ce2mux_tx_tdata     <= {CE_BUS_DATA_WIDTH{1'h0}} ;
               mmio_rsp_fifo_ren   <= 1'b0                      ; 
               next_addr           <= next_addr                 ;
               next_size           <= next_size                 ;
               curr_size           <= curr_size                 ;
               //next_tid            <= next_tid                  ;
               if( (axistrx_axisttx_cplerr  ==1'b1 ) ||    //error case     
                  (csr_axisttx_fifoerr     ==1'b1 ) ||    //error case
                  (acelitetx_axisttx_bresp !=2'b00)) begin//error case
                     axisttx_csr_dmaerr <= 1'b1  ;
                    // rx_data_pkt_cnt    <= 32'd0 ;
                     total_req_count    <= 32'd0 ;
                     curr_req_count     <= 32'd0 ;
               end
               else if (csr_axisttx_mrdstart== 1'b0) begin //ce deasserted mrd start due to error case or
                                                            //write to hps is success for the given csr_img_size
                    // rx_data_pkt_cnt    <= 32'd0 ;
                     total_req_count    <= 32'd0 ;
                     axisttx_csr_dmaerr <= 1'b0  ;
                     curr_req_count     <= 32'd0 ;
               end
            end
            ST_TX_CSR_INIT: begin
               ce2mux_tx_tkeep     <={24'h0,axist_csr_dout[7:0],32'hFFFF_FFFF}; //out of 512bits, 
                                                                     //only header(256bits),
                                                                     //data(64bits) are valid
               ce2mux_tx_tdata     <= axist_csr_dout[519:8]     ;
               ce2mux_tx_tvalid    <= 1'b1                      ;
               ce2mux_tx_tlast     <= 1'b1                      ;
               ce2mux_tx_tuser     <= {CE_BUS_USER_WIDTH{1'd0}} ; 
               mmio_rsp_fifo_ren   <= 1'b0                      ;  
               curr_req_count      <= curr_req_count            ;
               next_addr           <= next_addr                 ;
               //next_tid            <= next_tid                  ;
               next_size           <= next_size                 ;
               curr_size           <= curr_size                 ;
            end
            ST_TX_CSR_WAIT_RDY: begin
               ce2mux_tx_tvalid    <= ce2mux_tx_tvalid;
               ce2mux_tx_tkeep     <= ce2mux_tx_tkeep ;
               ce2mux_tx_tlast     <= ce2mux_tx_tlast ;
               ce2mux_tx_tuser     <= ce2mux_tx_tuser ;
               ce2mux_tx_tdata     <= ce2mux_tx_tdata ;
               mmio_rsp_fifo_ren   <= 1'b0            ;  
               curr_req_count      <= curr_req_count  ;
               next_addr           <= next_addr       ;
               //next_tid            <= next_tid        ;
               next_size           <= next_size       ;
               curr_size           <= curr_size       ;
            end
            ST_TX_RD_REQ_WAIT_RDY: begin
               ce2mux_tx_tvalid    <= ce2mux_tx_tvalid;
               ce2mux_tx_tkeep     <= ce2mux_tx_tkeep ;
               ce2mux_tx_tlast     <= ce2mux_tx_tlast ;
               ce2mux_tx_tuser     <= ce2mux_tx_tuser ;
               ce2mux_tx_tdata     <= ce2mux_tx_tdata ;
               mmio_rsp_fifo_ren   <= 1'b0            ;  
               curr_req_count      <= curr_req_count  ;
               next_addr           <= next_addr       ;
               //next_tid            <= next_tid        ;
               next_size           <= next_size       ;
               curr_size           <= curr_size       ;
            end
            ST_TX_CSR_CPLD_DONE: begin
               ce2mux_tx_tvalid    <= 1'b0                                        ;
               ce2mux_tx_tkeep     <= {CE_BUS_STRB_WIDTH{1'b0}}                   ;
               ce2mux_tx_tlast     <= 1'b0                                        ;
               ce2mux_tx_tuser     <= {CE_BUS_USER_WIDTH{1'd0}}                   ; 
               ce2mux_tx_tdata     <= {CE_BUS_DATA_WIDTH{1'h0}}                   ;
               mmio_rsp_fifo_ren   <= (mmio_rsp_fifo_noemp ==1'b1) ? 1'b1: 1'b0   ;  
               curr_req_count      <= curr_req_count                              ;
               next_addr           <= next_addr                                   ;
               //next_tid            <= next_tid                                    ;
               next_size           <= next_size                                   ;
               curr_size           <= curr_size                                   ;
            end
            ST_TX_RD_REQ_CALC: begin
               if ( (csr_axisttx_mrdstart ==1) && (curr_req_count==32'h0) ) begin//first rd req from ce to host
                     next_addr  <= csr_axisttx_hostaddr ;
                     //next_tid   <= 10'h0                 ;
                  case (csr_axisttx_datareqlimit)
                     512:
                           case(csr_axisttx_imgxfrsize[31:0]%512)
                              0: begin              //csr_axisttx_imgxfrsize >= csr_axisttx_datareqlimit and Image size programed is a multiple of data request limit
                                    total_req_count <= csr_axisttx_imgxfrsize[31:0] >> (csr_axisttx_datareqlimit_log2);
                                    next_size       <= {13'd0,csr_axisttx_datareqlimit}                               ;//next size will be constant for all transfers
                                    curr_size       <= curr_size                                                      ;
                              end
                              csr_axisttx_imgxfrsize[31:0]: begin //csr_axisttx_imgxfrsize < csr_axisttx_datareqlimit
                                    total_req_count <= 32'd1                       ;
                                    next_size       <= csr_axisttx_imgxfrsize[23:0];
                                    curr_size       <= curr_size                   ;
                              end
                              default: begin     //csr_axisttx_imgxfrsize > csr_axisttx_datareqlimit and Image size programed is NOT a multiple of data request limit
                                    total_req_count <= (csr_axisttx_imgxfrsize[31:0] >> (csr_axisttx_datareqlimit_log2) )+ 'd1 ;
                                    next_size       <= {13'd0,csr_axisttx_datareqlimit}                                        ;
                                    curr_size       <= csr_axisttx_imgxfrsize[31:0] - {21'd0,csr_axisttx_datareqlimit}         ;
                              end
                           endcase
                     64:
                           case(csr_axisttx_imgxfrsize[31:0]%64)
                              0: begin              //csr_axisttx_imgxfrsize >= csr_axisttx_datareqlimit and Image size programed is a multiple of data request limit
                                    total_req_count <= csr_axisttx_imgxfrsize[31:0] >> (csr_axisttx_datareqlimit_log2);
                                    next_size       <= {13'd0,csr_axisttx_datareqlimit}                               ;//next size will be constant for all transfers
                                    curr_size       <= curr_size                                                      ;
                              end
                              csr_axisttx_imgxfrsize[31:0]: begin // csr_axisttx_imgxfrsize < csr_axisttx_datareqlimit
                                    total_req_count <= 32'd1                       ;
                                    next_size       <= csr_axisttx_imgxfrsize[23:0];
                                    curr_size       <= curr_size                   ;
                              end
                              default: begin // csr_axisttx_imgxfrsize > csr_axisttx_datareqlimit and Image size programed is NOT a multiple of data request limit
                                    total_req_count <= (csr_axisttx_imgxfrsize[31:0] >> (csr_axisttx_datareqlimit_log2) )+ 'd1 ;
                                    next_size       <= {13'd0,csr_axisttx_datareqlimit}                                        ;
                                    curr_size       <= csr_axisttx_imgxfrsize[31:0] - {21'd0,csr_axisttx_datareqlimit}         ;
                              end
                           endcase
                     128:
                           case(csr_axisttx_imgxfrsize[31:0]%128)
                              0: begin              //csr_axisttx_imgxfrsize >= csr_axisttx_datareqlimit and Image size programed is a multiple of data request limit
                                    total_req_count <= csr_axisttx_imgxfrsize[31:0] >> (csr_axisttx_datareqlimit_log2);
                                    next_size       <= {13'd0,csr_axisttx_datareqlimit}                               ;//next size will be constant for all transfers
                                    curr_size       <= curr_size                                                      ;
                              end
                              csr_axisttx_imgxfrsize[31:0]: begin // csr_axisttx_imgxfrsize < csr_axisttx_datareqlimit
                                    total_req_count <= 32'd1                       ;
                                    next_size       <= csr_axisttx_imgxfrsize[23:0];
                                    curr_size       <= curr_size                   ;
                              end
                              default: begin // csr_axisttx_imgxfrsize > csr_axisttx_datareqlimit and Image size programed is NOT a multiple of data request limit
                                    total_req_count <= (csr_axisttx_imgxfrsize[31:0] >> (csr_axisttx_datareqlimit_log2) )+ 'd1 ;
                                    next_size       <= {13'd0,csr_axisttx_datareqlimit}                                        ;
                                    curr_size       <= csr_axisttx_imgxfrsize[31:0] - {21'd0,csr_axisttx_datareqlimit}         ;
                              end
                           endcase
                     1024:
                           case(csr_axisttx_imgxfrsize[31:0]%1024)
                              0: begin              //csr_axisttx_imgxfrsize >= csr_axisttx_datareqlimit and Image size programed is a multiple of data request limit
                                    total_req_count <= csr_axisttx_imgxfrsize[31:0] >> (csr_axisttx_datareqlimit_log2);
                                    next_size       <= {13'd0,csr_axisttx_datareqlimit}                               ;//next size will be constant for all transfers
                                    curr_size       <= curr_size                                                      ;
                              end
                              csr_axisttx_imgxfrsize[31:0]: begin // csr_axisttx_imgxfrsize < csr_axisttx_datareqlimit
                                    total_req_count <= 32'd1                       ;
                                    next_size       <= csr_axisttx_imgxfrsize[23:0];
                                    curr_size       <= curr_size                   ;
                              end
                              default: begin // csr_axisttx_imgxfrsize > csr_axisttx_datareqlimit and Image size programed is NOT a multiple of data request limit
                                    total_req_count <= (csr_axisttx_imgxfrsize[31:0] >> (csr_axisttx_datareqlimit_log2) )+ 'd1 ;
                                    next_size       <= {13'd0,csr_axisttx_datareqlimit}                                        ;
                                    curr_size       <= csr_axisttx_imgxfrsize[31:0] - {21'd0,csr_axisttx_datareqlimit}         ;
                              end
                           endcase       
                  endcase
               end
            end
            ST_TX_RD_REQ_INIT: begin
               ce2mux_tx_tdata     <={256'h0,hostrdreqhdr}                ;
               ce2mux_tx_tvalid    <= 1'b1                                ;
               ce2mux_tx_tkeep     <={32'h0, 32'hFFFF_FFFF}               ;
               ce2mux_tx_tlast     <= 1'b1                                ;
               ce2mux_tx_tuser     <= { {CE_BUS_USER_WIDTH-1{1'b0}}, 1'b1}; //host DDR read request is in data mover mode only 
               mmio_rsp_fifo_ren   <= 1'b0                                ;  
               curr_req_count      <= curr_req_count                      ;
               next_addr           <= next_addr                           ;
               //next_tid            <= next_tid                            ;
            end
            ST_TX_RD_REQ_DONE: begin
               ce2mux_tx_tvalid    <= 1'b0                      ;
               ce2mux_tx_tkeep     <= {CE_BUS_STRB_WIDTH{1'b0}} ;
               ce2mux_tx_tlast     <= 1'b0                      ;
               ce2mux_tx_tuser     <= {CE_BUS_USER_WIDTH{1'd0}} ; 
               ce2mux_tx_tdata     <= {CE_BUS_DATA_WIDTH{1'h0}} ;
               mmio_rsp_fifo_ren   <= 1'b0                      ;  
               if(curr_req_count== total_req_count-32'h1) begin
                     next_addr       <= 64'h0                 ;
                     next_size       <= 24'h0                 ;
                     curr_size       <= 32'h0                 ;
                     //next_tid        <= 10'h0                  ;
               end
               else begin
               //incrementing counter,addr, tid for next read request
                     case(csr_axisttx_datareqlimit)
                        64:
                           case(csr_axisttx_imgxfrsize[31:0]%64)
                                 0: begin              //perfectly divisible
                                       next_size       <= csr_axisttx_datareqlimit ;
                                       curr_size       <= curr_size                ;
                                 end
                                 default: begin // csr_axisttx_imgxfrsize > csr_axisttx_datareqlimit
                                       curr_size        <= (curr_size > {21'd0,csr_axisttx_datareqlimit})? (curr_size -{21'd0,csr_axisttx_datareqlimit}):curr_size;
                                       next_size       <= (curr_size >= {21'd0,csr_axisttx_datareqlimit})?
                                                            {13'd0,csr_axisttx_datareqlimit}: curr_size[23:0]; //2112-1024= 1088
                                 end
                           endcase
                        128:
                           case(csr_axisttx_imgxfrsize[31:0]%128)
                                 0: begin              //perfectly divisible
                                       next_size       <= csr_axisttx_datareqlimit ;
                                       curr_size       <= curr_size                ;
                                 end
                                 default: begin
                                       curr_size        <= (curr_size > {21'd0,csr_axisttx_datareqlimit})? (curr_size -{21'd0,csr_axisttx_datareqlimit}):curr_size;
                                       next_size       <= (curr_size >= {21'd0,csr_axisttx_datareqlimit})?
                                                            {13'd0,csr_axisttx_datareqlimit}: curr_size[23:0]; //2112-1024= 1088
                                 end
                           endcase
                        512:
                           case(csr_axisttx_imgxfrsize[31:0]%512)
                                 0: begin              //perfectly divisible
                                       next_size       <= csr_axisttx_datareqlimit ;
                                       curr_size       <= curr_size                ;
                                 end
                                 default: begin // csr_axisttx_imgxfrsize > csr_axisttx_datareqlimit
                                       curr_size        <= (curr_size > {21'd0,csr_axisttx_datareqlimit})? (curr_size -{21'd0,csr_axisttx_datareqlimit}):curr_size;
                                       next_size       <= (curr_size >= {21'd0,csr_axisttx_datareqlimit})?
                                                            {13'd0,csr_axisttx_datareqlimit}: curr_size[23:0]; //2112-1024= 1088
                                 end
                           endcase
                        1024:
                           case(csr_axisttx_imgxfrsize[31:0]%1024)
                                 0: begin              //perfectly divisible
                                       next_size       <= csr_axisttx_datareqlimit ;
                                       curr_size       <= curr_size                ;
                                 end
                                 default: begin // csr_axisttx_imgxfrsize > csr_axisttx_datareqlimit
                                       curr_size        <= (curr_size > {21'd0,csr_axisttx_datareqlimit})? (curr_size -{21'd0,csr_axisttx_datareqlimit}):curr_size;
                                       next_size       <= (curr_size >= {21'd0,csr_axisttx_datareqlimit})?
                                                            {13'd0,csr_axisttx_datareqlimit}: curr_size[23:0]; //2112-1024= 1088
                                 end
                           endcase
                     endcase
                     curr_req_count  <= curr_req_count + 32'd1;//this counter keeps track of the count of read req sent from ce to host
                                                               //this counter gets reset during any of the error cases                    
                                                               //this counter doesnt depend on FC received unlike rx_data_pkt_cnt counter
                     next_addr       <= next_addr+next_size   ;//we calculate the address of the next transfer-host DDR address
                     //next_tid        <= next_tid + 10'h1       ;//ID is always incremental. starting from 0
               end
            end
            /*ST_TX_DATA_WAIT: begin
               if (axistrx_axisttx_fc==1'b1) begin//final completion bit received for the read req from ce to host
                     rx_data_pkt_cnt     <= rx_data_pkt_cnt + 32'd1; //this counter checks the total FC received.
                                                                     //if img size is 4KB and read req granularity is 1KB,
                                                                     //CE needs to send a total of 4 read req to host     
                                                                     //hence the total FC expected is also 4(total_req_count will also be 4)              
                                                                     //when this counter value=4, we understand the complete              
                                                                     //data chunk is received as per the csr_img_size programmed          
                                                                     //FSM can go to IDLE state                                          
                                                                     //this counter gets reset during any of the error cases                    
               end
            end*/
      endcase
   end
end
//-------------------------------
always_ff@(posedge clk) begin
  if(ce_corereset ==1)
       rx_data_pkt_cnt    <= 32'd0 ;
  else if( (axistrx_axisttx_cplerr  ==1'b1 ) ||    //error case     
      (csr_axisttx_fifoerr     ==1'b1 ) ||    //error case
      (acelitetx_axisttx_bresp !=2'b00)) begin//error case
      
       rx_data_pkt_cnt    <= 32'd0 ;
      
      
  end
  else if (csr_axisttx_mrdstart== 1'b0) begin //ce deasserted mrd start due to error case or
                                                          //write to hps is success for the given csr_img_size
       rx_data_pkt_cnt    <= 32'd0 ;
  end
  else if (axistrx_axisttx_fc==1'b1) begin//final completion bit received for the read req from ce to host
       rx_data_pkt_cnt     <= rx_data_pkt_cnt + 32'd1; //this counter checks the total FC received.
                                                                     //if img size is 4KB and read req granularity is 1KB,
                                                                     //CE needs to send a total of 4 read req to host     
                                                                     //hence the total FC expected is also 4(total_req_count will also be 4)              
                                                                     //when this counter value=4, we understand the complete              
                                                                     //data chunk is received as per the csr_img_size programmed          
                                                                     //FSM can go to IDLE state                                          
                                                                     //this counter gets reset during any of the error cases  
  end
end
//---TX FSM END-----------------------------------------------------



//------------------------------------------------------------------
//-----Transaction Layer Packet for host Read request & CSR Read data
//------------------------------------------------------------------

logic [2:0]  pf_id;
logic [10:0] vf_id;
always_comb begin
         hostrdreqhdr = 256'h0;
         hostcsrrdhdr = 256'h0 ;
         pf_id        = CE_PF_ID;
         vf_id        = CE_VF_ID;
   if( (p_state!= ST_TX_CSR_CPLD_DONE) ||
      (p_state!= ST_TX_RD_REQ_DONE) ) begin 
      //-----Transaction Layer Packet for host Read request - data Mover Mode                 
      hostrdreqhdr.fmt_type       = DM_RD                                      ;  
      {hostrdreqhdr.tag_h,
      hostrdreqhdr.tag_m,
      hostrdreqhdr.tag_l}        = 10'd0 ;//next_tid                            ;
      {hostrdreqhdr.length_h,
      hostrdreqhdr.length_m,
      hostrdreqhdr.length_l}     = next_size                                  ;  
      hostrdreqhdr.pf_num         = CE_PF_ID                                   ;      
      hostrdreqhdr.vf_num         = CE_VF_ID                                   ;     
      hostrdreqhdr.vf_active      = CE_VF_ACTIVE                               ;  
      {hostrdreqhdr.host_addr_h,
      hostrdreqhdr.host_addr_m,
      hostrdreqhdr.host_addr_l}  = next_addr                                  ;
      //-----Transaction Layer Packet for CSR Read data - Power User Mode                      
      hostcsrrdhdr.fmt_type       = DM_CPL                                     ;      
      hostcsrrdhdr.cpl_status     = 3'd0                                       ; //Completion status
      hostcsrrdhdr.attr           = csr_axisttx_rspattr                        ; // csr attribute                                     
      hostcsrrdhdr.TC             = csr_axisttx_tc                             ; // csr traffic class                                    
      {hostcsrrdhdr.tag_h,          
      hostcsrrdhdr.tag_m,          
      hostcsrrdhdr.tag_l}        = csr_axisttx_rsptag                         ;
      hostcsrrdhdr.length         = (csr_axisttx_length == 0) ? 10'd1 : 10'd2  ; //DWs 
      hostcsrrdhdr.req_id         = csr_axisttx_reqid                          ;
      hostcsrrdhdr.comp_id        = {vf_id, CE_VF_ACTIVE[0], pf_id}            ; 
      hostcsrrdhdr.byte_count     = (csr_axisttx_length == 0) ? 12'd4 : 12'd8  ; 
      hostcsrrdhdr.pf_num         = CE_PF_ID                                   ;  //3'h4     
      hostcsrrdhdr.vf_num         = CE_VF_ID                                   ;  //11'h0   
      hostcsrrdhdr.vf_active      = CE_VF_ACTIVE                               ;  //1'h0
      hostcsrrdhdr.low_addr       = {csr_axisttx_rspaddr[6:0]}; 
   end
end
//------------------------------------------------------------------

//assign mmiorspfifo_axistrx_full = (mmiorspfifo_cnt >= CE_MMIO_RSP_FIFO_DEPTH - 2'd2) ? 1'b1:1'b0;

assign axisttx_csr_mmiofifooverflow   = mmio_rsp_fifo_err & mmio_rsp_fifo_full  ;
assign axisttx_csr_mmiofifounderflow  = mmio_rsp_fifo_err & !mmio_rsp_fifo_noemp;
//-------------------------------
// ---------------------------------------------------------------------------
// Debug Logic
// ---------------------------------------------------------------------------
`ifdef INCLUDE_CE_DEBUG


//logic [10:0] data_wait_state_cnt;
(*preserve*)logic [10:0]  data_wait_state_cnt;/*synthesis noprune*/

always_ff @ (posedge clk)
begin
   if (ce_corereset) 
   begin
      data_wait_state_cnt    <= 11'd0;  
   end
   else if(p_state == ST_TX_DATA_WAIT)
   begin
      data_wait_state_cnt    <= data_wait_state_cnt + 11'd1; 
   end
   else
   begin
      data_wait_state_cnt    <= 11'd0;  
   end
end


`endif



endmodule

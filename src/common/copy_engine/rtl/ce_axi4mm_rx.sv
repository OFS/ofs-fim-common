// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Engineer     : Sindhura Medam                      
// Create Date  : March 2021
// Module Name  : ce_axi4mm_rx.sv
// Project      : IOFS
// -----------------------------------------------------------------------------
//
// Description: 
// This block handles HPS polling/configure of CSR
//
// ***************************************************************************
module ce_axi4mm_rx #(
   parameter CE_AXI4MM_ADDR_WIDTH   = 21   ,                    
   parameter CE_AXI4MM_DATA_WIDTH   = 32   ,                        
   parameter CE_BUS_STRB_WIDTH   = CE_AXI4MM_DATA_WIDTH >>3   ,
   parameter CSR_ADDR_WIDTH   = 16 

)(
   // global signals
   input   logic                                clk                         ,    //Clock Signal
   input   logic                                h2f_reset                ,    //Active High Reset

   // AXI4 Lite Rx interface signals
   // Write Address Channel
   output logic                                 ce2hps_rx_awready           ,    //Write address ready
   input  logic                                 hps2ce_rx_awvalid           ,    //Write address valid
   input  logic                                 hps2ce_rx_awlock            ,    
   input  logic  [CE_AXI4MM_ADDR_WIDTH-1:0]     hps2ce_rx_awaddr            ,    //Write address
   input  logic  [3:0]                          hps2ce_rx_awid              ,    //Write ID 
   input  logic  [2:0]                          hps2ce_rx_awprot            ,    //Protection type
   input  logic  [7:0]                          hps2ce_rx_awlen             ,    //Burst Length //0
   input  logic  [2:0]                          hps2ce_rx_awsize            ,    //Burst size //101
   input  logic  [1:0]                          hps2ce_rx_awburst           ,    //Burst Type
   input  logic  [3:0]                          hps2ce_rx_awcache           ,
   input  logic  [3:0]                          hps2ce_rx_awqos             , 

   // Write Data Channel
   output logic                                 ce2hps_rx_wready            ,    //Write ready
   input  logic                                 hps2ce_rx_wvalid            ,    //Write valid
   input  logic                                 hps2ce_rx_wlast             ,    //Write last //1'b1
   input  logic  [CE_AXI4MM_DATA_WIDTH-1:0]     hps2ce_rx_wdata             ,    //Write data    
   input  logic  [CE_BUS_STRB_WIDTH-1:0]        hps2ce_rx_wstrb             ,    //Write strobes 

   // Write Response Channel
   input  logic                                 hps2ce_rx_bready            ,    //Response ready
   output logic                                 ce2hps_rx_bvalid            ,    //Write response valid
   output logic  [1:0]                          ce2hps_rx_bresp             ,    //Write response
   output logic  [3:0]                          ce2hps_rx_bid               ,    //Write response ID 

   //Read Address Channel
   output logic                                 ce2hps_rx_arready           ,    //Read address ready
   input  logic                                 hps2ce_rx_arlock            ,    
   input  logic                                 hps2ce_rx_arvalid           ,    //Read address valid
   input  logic  [CE_AXI4MM_ADDR_WIDTH-1:0]     hps2ce_rx_araddr            ,    //Read address
   input  logic  [2:0]                          hps2ce_rx_arprot            ,    //Protection type
   input  logic  [3:0]                          hps2ce_rx_arid              ,    //Read ID
   input  logic  [7:0]                          hps2ce_rx_arlen             ,    //Burst Length
   input  logic  [2:0]                          hps2ce_rx_arsize            ,    //Burst size
   input  logic  [1:0]                          hps2ce_rx_arburst           ,    //Burst Type
   input  logic  [3:0]                          hps2ce_rx_arcache           ,
   input  logic  [3:0]                          hps2ce_rx_arqos             , 

   // Read Data Channel
   input  logic                                 hps2ce_rx_rready            ,    //Read Ready
   output logic                                 ce2hps_rx_rvalid            ,    //Read Valid
   output logic                                 ce2hps_rx_rlast             ,    //Read Last
   output logic  [CE_AXI4MM_DATA_WIDTH-1:0]     ce2hps_rx_rdata             ,    //Read data    
   output logic  [1:0]                          ce2hps_rx_rresp             ,    //Read response
   output logic  [3:0]                          ce2hps_rx_rid               ,    //Read response ID 

   //CSR signals
   output logic                                 axi4mmrx_csr_wen            ,    //Write Enable
   output logic                                 axi4mmrx_csr_ren            ,    //Read Enable
   output logic  [CE_AXI4MM_DATA_WIDTH-1:0]     axi4mmrx_csr_wdata          ,    //Write data
   output logic  [CE_BUS_STRB_WIDTH-1:0]        axi4mmrx_csr_wstrb          ,    //Write strobes 
   output logic  [CSR_ADDR_WIDTH-1:0]           axi4mmrx_csr_raddr          ,    //Read Address
   output logic  [CSR_ADDR_WIDTH-1:0]           axi4mmrx_csr_waddr          ,    //Write Address
   input  logic  [CE_AXI4MM_DATA_WIDTH-1:0]     csr_axi4mmrx_rdata          ,    //Read Data

   //Error signals
   input logic                                  axistrx_axi4mmrx_cplerr     ,    //Cpl Error 
   input logic                                  csr_axi4mmrx_fifoerr        ,    //Fifo overflow and underflow error 
   input logic  [1:0]                           acelitetx_axi4mmrx_bresp         //Write Respose 
);

// ---------------------------------------------------------------------------
// Local Signals/Flops
// ---------------------------------------------------------------------------
logic                             hps2ce_rx_wvalid_q ;
logic                             hps2ce_rx_arvalid_q;
logic                             hps2ce_rx_awvalid_q; 
logic [CE_AXI4MM_ADDR_WIDTH-1:0]  hps2ce_rx_awaddr_q ;
logic [3:0                     ]  hps2ce_rx_awid_q   ;
logic [3:0                     ]  hps2ce_rx_arid_q   ;
logic [2:0                     ]  hps2ce_rx_awprot_q ;
logic [CE_AXI4MM_DATA_WIDTH-1:0]  hps2ce_rx_wdata_q  ;
logic [CE_BUS_STRB_WIDTH-1:0   ]  hps2ce_rx_wstrb_q  ;
logic [CE_AXI4MM_ADDR_WIDTH-1:0]  hps2ce_rx_araddr_q ;
logic [2:0                     ]  hps2ce_rx_arprot_q ;

//----------------------------------------------------------------------------
//Sampling AXI-Lite Rx interface Signals
//
always_ff @(posedge clk) 
begin
   if (h2f_reset)
   begin
      hps2ce_rx_awvalid_q   <= 1'd0                         ; 
      hps2ce_rx_awid_q      <=  4'd0                        ;  
      hps2ce_rx_awaddr_q    <= {CE_AXI4MM_ADDR_WIDTH{1'd0}} ;
      hps2ce_rx_awprot_q    <= 3'd0                         ;
      hps2ce_rx_wvalid_q    <= 1'd0                         ;
      hps2ce_rx_wdata_q     <= {CE_AXI4MM_DATA_WIDTH{1'd0}} ;
      hps2ce_rx_wstrb_q     <= {CE_BUS_STRB_WIDTH{1'd0}}    ;
      hps2ce_rx_arvalid_q   <= 1'd0                         ; 
      hps2ce_rx_arid_q      <= 4'd0                         ; 
      hps2ce_rx_araddr_q    <= {CE_AXI4MM_ADDR_WIDTH{1'd0}} ;
      hps2ce_rx_arprot_q    <= 3'd0                         ;
   end
   else
   begin
      hps2ce_rx_awvalid_q   <= hps2ce_rx_awvalid        ; 
      hps2ce_rx_awid_q      <= hps2ce_rx_awid           ;  
      hps2ce_rx_awaddr_q    <= hps2ce_rx_awaddr         ;
      hps2ce_rx_awprot_q    <= hps2ce_rx_awprot         ;  
      hps2ce_rx_wvalid_q    <= hps2ce_rx_wvalid         ;  
      hps2ce_rx_wdata_q     <= hps2ce_rx_wdata          ;  
      hps2ce_rx_wstrb_q     <= hps2ce_rx_wstrb          ;
      hps2ce_rx_arvalid_q   <= hps2ce_rx_arvalid        ; 
      hps2ce_rx_arid_q      <= hps2ce_rx_arid           ; 
      hps2ce_rx_araddr_q    <= hps2ce_rx_araddr         ;
      hps2ce_rx_arprot_q    <= hps2ce_rx_arprot         ;
   end 
end

//-------------------------------------------------------------------------------
// Slave Write Channel State Machine
//-------------------------------------------------------------------------------

typedef enum logic [2:0] {

   AXI4MM_WR_IDLE        = 3'b000,   //IDLE state  
   //Slave address channel output signals assigned with default values

   AXI4MM_WR_ADDR_RDY    = 3'b001,   //AWREADY generate State
   //Slave Write address channel Ready Signal generation
                     
   AXI4MM_WR_DATA_WAIT   = 3'b010,   //Write Data Wait state
   
   AXI4MM_WR_DATA_RDY    = 3'b011,   //WREADY generate state
   //Slave Write data channel Ready Signal generation 
   AXI4MM_WR_BRESP_GEN   = 3'b100    //Write Response generate state

   } wr_states; 

wr_states    pstate,nstate;

//--------------------------------------------------------
// Present State
//--------------------------------------------------------
always_ff@(posedge clk)
begin
   if(h2f_reset)
   begin
      pstate <= AXI4MM_WR_IDLE;
   end
   else 
   begin
      pstate <= nstate;
   end
end

//--------------------------------------------------------
// Next State
//--------------------------------------------------------

always_comb
begin
   if ((acelitetx_axi4mmrx_bresp != 2'b00) || axistrx_axi4mmrx_cplerr || csr_axi4mmrx_fifoerr) // state transition to IDLE if any error condition occurs 
   begin
      nstate = AXI4MM_WR_IDLE;
   end
   else
   begin

      case(pstate)

         AXI4MM_WR_IDLE          :       if(hps2ce_rx_awvalid_q)
                                             begin
                                                nstate = AXI4MM_WR_ADDR_RDY; 
                                             end
                                             else 
                                             begin
                                                nstate = AXI4MM_WR_IDLE;
                                             end

         AXI4MM_WR_ADDR_RDY      :       nstate = AXI4MM_WR_DATA_WAIT;

         AXI4MM_WR_DATA_WAIT     :       if(hps2ce_rx_wvalid_q)
                                             begin
                                                nstate = AXI4MM_WR_DATA_RDY;
                                             end
                                             else 
                                             begin
                                                nstate = AXI4MM_WR_DATA_WAIT;
                                             end

         AXI4MM_WR_DATA_RDY      :       nstate = AXI4MM_WR_BRESP_GEN;

         AXI4MM_WR_BRESP_GEN     :       if(hps2ce_rx_bready) 
                                             begin
                                                nstate = AXI4MM_WR_IDLE; 
                                             end
                                             else 
                                             begin
                                                nstate = AXI4MM_WR_BRESP_GEN;
                                             end

         default                 :       nstate = AXI4MM_WR_IDLE;

      endcase
   end
end                       

//--------------------------------------------------------
// Write Channel Output Logic
//--------------------------------------------------------
logic [15:0] awaddr_q;

always_ff@(posedge clk)
begin
   if(h2f_reset)
   begin
      awaddr_q     <=  16'd0; 
   end
   else if(hps2ce_rx_awvalid_q & ce2hps_rx_awready)
   begin
      awaddr_q     <=  hps2ce_rx_awaddr_q[15:0]; 
   end
end

logic [3:0] awid_q;

always_ff@(posedge clk)
begin
   if(h2f_reset)
   begin
      awid_q     <=  4'd0; 
   end

   else if(hps2ce_rx_awvalid_q & ce2hps_rx_awready) 
   begin
      awid_q     <=  hps2ce_rx_awid_q; 
   end
end

always_ff@(posedge clk)
begin
   if(h2f_reset)
   begin
      ce2hps_rx_awready     <=  1'b0                        ; 
      ce2hps_rx_wready      <=  1'b0                        ;
      ce2hps_rx_bvalid      <=  1'b0                        ; 
      ce2hps_rx_bid         <=  4'd0                        ; 
      ce2hps_rx_bresp       <=  2'b00                       ; 
      axi4mmrx_csr_wen      <=  1'b0                        ; 
      axi4mmrx_csr_wdata    <=  {CE_AXI4MM_DATA_WIDTH{1'd0}}; 
      axi4mmrx_csr_wstrb    <=  {CE_BUS_STRB_WIDTH{1'd0}}   ; 
      axi4mmrx_csr_waddr    <=  {CSR_ADDR_WIDTH{1'd0}}      ;                              
   end
   else
   begin 
      case(nstate)

         AXI4MM_WR_IDLE             :  begin   
                                             ce2hps_rx_awready     <=  1'b0                        ; 
                                             ce2hps_rx_wready      <=  1'b0                        ;
                                             ce2hps_rx_bvalid      <=  1'b0                        ; 
                                             ce2hps_rx_bid         <=  4'd0                        ; 
                                             ce2hps_rx_bresp       <=  2'b00                       ;
                                             axi4mmrx_csr_wen      <=  1'b0                        ; 
                                             axi4mmrx_csr_wdata    <=  {CE_AXI4MM_DATA_WIDTH{1'd0}};                             
                                             axi4mmrx_csr_wstrb    <=  {CE_BUS_STRB_WIDTH{1'd0}}   ; 
                                             axi4mmrx_csr_waddr    <=  {CSR_ADDR_WIDTH{1'd0}}      ;                              
                                       end


         AXI4MM_WR_ADDR_RDY         :  begin
                                             ce2hps_rx_awready     <=  1'b1                        ; 
                                             ce2hps_rx_wready      <=  1'b0                        ;
                                             ce2hps_rx_bvalid      <=  1'b0                        ; 
                                             ce2hps_rx_bid         <=  4'd0                        ; 
                                             ce2hps_rx_bresp       <=  2'b00                       ;  
                                             axi4mmrx_csr_wen      <=  1'b0                        ; 
                                             axi4mmrx_csr_wdata    <=  {CE_AXI4MM_DATA_WIDTH{1'd0}};                             
                                             axi4mmrx_csr_wstrb    <=  {CE_BUS_STRB_WIDTH{1'd0}}   ; 
                                             axi4mmrx_csr_waddr    <=  {CSR_ADDR_WIDTH{1'd0}}      ;                              
                                       end

         AXI4MM_WR_DATA_RDY         :  begin
                                             ce2hps_rx_awready     <=  1'b0                        ; 
                                             ce2hps_rx_wready      <=  1'b1                        ; 
                                             ce2hps_rx_bvalid      <=  1'b0                        ; 
                                             ce2hps_rx_bid         <=  4'd0                        ; 
                                             ce2hps_rx_bresp       <=  2'b00                       ;
                                             axi4mmrx_csr_wen      <=  ((awaddr_q == 16'h0150) || (awaddr_q == 16'h0158)) ? 1'b1 : 1'b0;  
                                             axi4mmrx_csr_wdata    <=  hps2ce_rx_wdata_q           ;                              
                                             axi4mmrx_csr_wstrb    <=  hps2ce_rx_wstrb_q           ; 
                                             axi4mmrx_csr_waddr    <=  awaddr_q                    ;                              
                                       end

         AXI4MM_WR_BRESP_GEN       :   begin
                                             ce2hps_rx_awready     <=  1'b0                        ; 
                                             ce2hps_rx_wready      <=  1'b0                        ;
                                             ce2hps_rx_bvalid      <=  1'b1                        ; 
                                             ce2hps_rx_bid         <=  awid_q                      ; 
                                             ce2hps_rx_bresp       <=  2'b00                       ;    
                                             axi4mmrx_csr_wen      <=  1'b0                        ; 
                                             axi4mmrx_csr_wstrb    <=  {CE_BUS_STRB_WIDTH{1'd0}}   ; 
                                             axi4mmrx_csr_wdata    <=  {CE_AXI4MM_DATA_WIDTH{1'd0}};                          
                                             axi4mmrx_csr_waddr    <=  {CSR_ADDR_WIDTH{1'd0}}      ;                              
                                       end

         default            :          begin   
                                             ce2hps_rx_awready     <=  1'b0                        ; 
                                             ce2hps_rx_wready      <=  1'b0                        ;
                                             ce2hps_rx_bvalid      <=  1'b0                        ; 
                                             ce2hps_rx_bid         <=  4'd0                        ; 
                                             ce2hps_rx_bresp       <=  2'b00                       ;
                                             axi4mmrx_csr_wen      <=  1'b0                        ; 
                                             axi4mmrx_csr_wstrb    <=  {CE_BUS_STRB_WIDTH{1'd0}}   ; 
                                             axi4mmrx_csr_wdata    <=  {CE_AXI4MM_DATA_WIDTH{1'd0}};                             
                                             axi4mmrx_csr_waddr    <=  {CSR_ADDR_WIDTH{1'd0}}      ;                              
                                       end
      endcase
   end
end


//-------------------------------------------------------------------------------
// Slave Read Channel State Machine
//-------------------------------------------------------------------------------

typedef enum logic [2:0] {

   AXI4MM_RD_IDLE        = 3'b000,   //IDLE state  
   //Slave read address channel output signals assigned with default values

   AXI4MM_RD_ADDR_RDY    = 3'b001,   //ARREADY generate State
   //Slave Read address channel Ready Signal generation
                     
   AXI4MM_CSR_RD_EN      = 3'b010,   //CSR Read enable state

   AXI4MM_RD_DATA_WAIT   = 3'b011,   //CSR DATA Wait state   

   AXI4MM_RD_RRDY_WAIT   = 3'b100    //Read data & read response state
   //Slave Read data and response with valid Signal generation 
   
   } rd_states; 

rd_states    rd_pstate,rd_nstate;

logic [3:0] arid_q;

always_ff@(posedge clk)
begin
   if(h2f_reset)
   begin
      arid_q     <=  4'd0            ; 
   end

   else if(hps2ce_rx_arvalid_q & ce2hps_rx_arready)
   begin
      arid_q     <=  hps2ce_rx_arid_q; 
   end
end

//--------------------------------------------------------
// Present State
//--------------------------------------------------------
always_ff@(posedge clk)
begin
   if(h2f_reset)
   begin
         rd_pstate <= AXI4MM_RD_IDLE;
   end
   else 
   begin
         rd_pstate <= rd_nstate;
   end
end

//--------------------------------------------------------
// Next State
//--------------------------------------------------------

always_comb
begin
   if ((acelitetx_axi4mmrx_bresp != 2'b00) || axistrx_axi4mmrx_cplerr || csr_axi4mmrx_fifoerr) // state transition to IDLE if any error condition occurs 
   begin
         rd_nstate = AXI4MM_RD_IDLE;
   end
   else
   begin
         case(rd_pstate)

            AXI4MM_RD_IDLE          :        if(hps2ce_rx_arvalid_q)
                                             begin
                                                rd_nstate = AXI4MM_RD_ADDR_RDY; 
                                             end
                                             else 
                                             begin
                                                rd_nstate = AXI4MM_RD_IDLE;
                                             end

            AXI4MM_RD_ADDR_RDY     :        rd_nstate = AXI4MM_CSR_RD_EN;

            AXI4MM_CSR_RD_EN       :        rd_nstate = AXI4MM_RD_DATA_WAIT;

            AXI4MM_RD_DATA_WAIT    :        rd_nstate = AXI4MM_RD_RRDY_WAIT;

            AXI4MM_RD_RRDY_WAIT    :         if(hps2ce_rx_rready)
                                             begin
                                                rd_nstate = AXI4MM_RD_IDLE; 
                                             end
                                             else 
                                             begin
                                                rd_nstate = AXI4MM_RD_RRDY_WAIT;
                                             end

            default                :        rd_nstate = AXI4MM_RD_IDLE;

         endcase
   end
end                       

//--------------------------------------------------------
// Read Channel Output Logic
//--------------------------------------------------------
logic [15:0] araddr_q;

always_ff@(posedge clk)
begin
   if(h2f_reset)
   begin
      araddr_q     <=  16'd0; 
   end
   else if(hps2ce_rx_arvalid_q & ce2hps_rx_arready)
   begin
      araddr_q     <=  hps2ce_rx_araddr_q[15:0]; 
   end
end

always_ff@(posedge clk)
begin
   if(h2f_reset)
   begin
      ce2hps_rx_arready     <=  1'b0                        ; 
      ce2hps_rx_rdata       <=  {CE_AXI4MM_DATA_WIDTH{1'd0}};
      ce2hps_rx_rvalid      <=  1'b0                        ; 
      ce2hps_rx_rid         <=  4'd0                        ; 
      ce2hps_rx_rlast       <=  1'b0                        ; 
      ce2hps_rx_rresp       <=  2'b00                       ; 
      axi4mmrx_csr_ren      <=  1'b0                        ;                              
      axi4mmrx_csr_raddr    <=  {CSR_ADDR_WIDTH{1'd0}}      ;                              
   end
   else
   begin 
      case(rd_nstate)

         AXI4MM_RD_IDLE         :   begin   
                                          ce2hps_rx_arready     <=  1'b0                        ; 
                                          ce2hps_rx_rdata       <=  {CE_AXI4MM_DATA_WIDTH{1'd0}};
                                          ce2hps_rx_rvalid      <=  1'b0                        ; 
                                          ce2hps_rx_rid         <=  4'd0                        ; 
                                          ce2hps_rx_rlast       <=  1'b0                        ; 
                                          ce2hps_rx_rresp       <=  2'b00                       ;                              
                                          axi4mmrx_csr_ren      <=  1'b0                        ;                              
                                          axi4mmrx_csr_raddr    <=  {CSR_ADDR_WIDTH{1'd0}}      ;                              
                                    end

         AXI4MM_RD_ADDR_RDY     :   begin
                                          ce2hps_rx_arready     <=  1'b1                        ; 
                                          ce2hps_rx_rdata       <=  {CE_AXI4MM_DATA_WIDTH{1'd0}};
                                          ce2hps_rx_rvalid      <=  1'b0                        ; 
                                          ce2hps_rx_rid         <=  4'd0                        ; 
                                          ce2hps_rx_rlast       <=  1'b0                        ; 
                                          ce2hps_rx_rresp       <=  2'b00                       ;                            
                                          axi4mmrx_csr_ren      <=  1'b0                        ;                               
                                          axi4mmrx_csr_raddr    <=  {CSR_ADDR_WIDTH{1'd0}}      ;                               
                                    end

         AXI4MM_CSR_RD_EN       :   begin
                                          ce2hps_rx_arready     <=  1'b0                        ; 
                                          ce2hps_rx_rdata       <=  {CE_AXI4MM_DATA_WIDTH{1'd0}};
                                          ce2hps_rx_rvalid      <=  1'b0                        ; 
                                          ce2hps_rx_rid         <=  4'd0                        ; 
                                          ce2hps_rx_rlast       <=  1'b0                        ; 
                                          ce2hps_rx_rresp       <=  2'b00                       ;                            
                                          axi4mmrx_csr_ren      <=  ((hps2ce_rx_araddr_q[15:0] == 16'h0150) || (hps2ce_rx_araddr_q[15:0] == 16'h0154) || 
                                                                     (hps2ce_rx_araddr_q[15:0] == 16'h0158)) ? 1'b1 : 1'b0;
                                          axi4mmrx_csr_raddr    <=  hps2ce_rx_araddr_q[15:0]    ;                              
                                    end

         AXI4MM_RD_RRDY_WAIT    :   begin
                                          ce2hps_rx_arready     <=  1'b0                        ; 
                                          ce2hps_rx_rdata       <=  (araddr_q > 16'h0158) ? {CE_AXI4MM_DATA_WIDTH{1'b1}} :
                                                                     (((araddr_q == 16'h0150) || (araddr_q == 16'h0154) || (araddr_q == 16'h0158)) ? csr_axi4mmrx_rdata: {CE_AXI4MM_DATA_WIDTH{1'b0}});
                                          ce2hps_rx_rvalid      <=  1'b1                        ; 
                                          ce2hps_rx_rid         <=  arid_q                      ; 
                                          ce2hps_rx_rlast       <=  1'b1                        ; 
                                          ce2hps_rx_rresp       <=  2'b00                       ;                            
                                          axi4mmrx_csr_ren      <=  1'b0                        ;                               
                                          axi4mmrx_csr_raddr    <=  {CSR_ADDR_WIDTH{1'd0}}      ;                              
                                    end

         default         :          begin   
                                          ce2hps_rx_arready     <=  1'b0                        ; 
                                          ce2hps_rx_rdata       <=  {CE_AXI4MM_DATA_WIDTH{1'd0}};
                                          ce2hps_rx_rvalid      <=  1'b0                        ; 
                                          ce2hps_rx_rid         <=  4'd0                        ; 
                                          ce2hps_rx_rlast       <=  1'b0                        ; 
                                          ce2hps_rx_rresp       <=  2'b00                       ;  
                                          axi4mmrx_csr_ren      <=  1'b0                        ;                              
                                          axi4mmrx_csr_raddr    <=  {CSR_ADDR_WIDTH{1'd0}}      ;                              
                                    end
      endcase
   end
end

endmodule


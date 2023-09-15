// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Engineer     : Sindhura Medam                      
// Create Date  : Dec 2020
// Module Name  : ce_acelite_tx.sv
// Project      : IOFS
// -----------------------------------------------------------------------------
//
// Description: 
//	This block reads the FIFO when the HPS is ready to accept the data.
//	Issues write transaction as per the interface requirements.
// ***************************************************************************

module ce_acelite_tx #(
   parameter CE_BUS_ADDR_WIDTH         = 32                  , 
   parameter CE_BUS_DATA_WIDTH         = 512                 ,
   parameter CE_BUS_STRB_WIDTH         = CE_BUS_DATA_WIDTH>>3,
   parameter CE_HST2HPS_FIFO_DEPTH     = 5                   , //2^5=32 depth
   parameter CSR_DATA_WIDTH            = 64 
)(
   // global signals
   input   logic                                clk                            ,    //Clock Signal
   input   logic                                ce_corereset                   ,    //Active High -Soft reset+hard reset

   // ACE Lite tx interface signals
   // Write address Channel
   input   logic                                hps2ce_tx_awready              ,    //Write address ready
   output  logic                                ce2hps_tx_awvalid              ,    //Write address valid
   output  logic  [CE_BUS_ADDR_WIDTH-1:0]       ce2hps_tx_awaddr               ,    //Write address
   output  logic  [2:0]                         ce2hps_tx_awprot               ,    //Protection type
   output  logic  [7:0]                         ce2hps_tx_awlen                ,    //Burst length
   output  logic  [2:0]                         ce2hps_tx_awsize               ,    //Burst size
   output  logic  [1:0]                         ce2hps_tx_awburst              ,    //Burst type
   output  logic  [2:0]                         ce2hps_tx_awsnoop              ,    //transaction type for shareable write transactions
   output  logic  [1:0]                         ce2hps_tx_awdomain             ,    //shareability domain of a write transaction 
   output  logic  [1:0]                         ce2hps_tx_awbar                ,    //write barrier transaction

   // Write data Channel
   input   logic                                hps2ce_tx_wready               ,    //Write ready
   output  logic                                ce2hps_tx_wvalid               ,    //Write valid
   output  logic                                ce2hps_tx_wlast                ,    //Write last
   output  logic  [CE_BUS_DATA_WIDTH-1:0]       ce2hps_tx_wdata                ,    //Write data
   output  logic  [CE_BUS_STRB_WIDTH-1:0]       ce2hps_tx_wstrb                ,    //Write strobes

   // Write Response Channel
   input   logic                                hps2ce_tx_bvalid               ,    //Write response valid
   output  logic                                ce2hps_tx_bready               ,    //Response ready
   input   logic  [1:0]                         hps2ce_tx_bresp                ,    //Write response

   //FIFO2 signals
   output  logic                                acelitetx_cpldfifo_ren         ,    //fifo read enable        
   input   logic                                cpldfifo_acelitetx_empty       ,    //fifo empty information
   input   logic  [576:0]                       cpldfifo_acelitetx_rddata      ,    //fifo read data
   input   logic  [CE_HST2HPS_FIFO_DEPTH-1:0]   cpldfifo_acelitetx_cnt         ,    //fifo count

   //CSR signals
   output  logic                                acelitetx_csr_dmadone          ,    //DMA done bit
   input   logic                                csr_acelitetx_mrdstart         ,    //MRD Start bit
   input   logic                                csr_acelitetx_fifoerr          ,    //Fifo overflow and underflow error      
   input   logic  [CSR_DATA_WIDTH-1:0]          csr_acelitetx_hpsaddr          ,    //HPS DDR destination address 
   input   logic  [CSR_DATA_WIDTH-1:0]          csr_acelitetx_imgxfrsize       ,    //Host Read request size
   input   logic  [10:0]                        csr_acelitetx_datareqlimit     ,    //Host Read request size
   input   logic  [3:0]                         csr_acelitetx_datareqlimit_log2,    //Host Read request size
   
   input   logic                                axistrx_acelitetx_cplerr       ,    //cpl error    
   input   logic                                axistrx_acelitetx_fc           ,    //final completion information
   output  logic  [1:0]                         acelitetx_bresp                ,    //Ace Lite Write Response
   output  logic                                acelitetx_bresperrpulse        ,    //Ace Lite Write Response to axi-ST rx block
   output  logic                                acelitetx_axisttx_req_en            //Ace Lite Write Response flag to axi-ST tx block
);

//----------------------------------------------------------------------------
// Local Parameters
//----------------------------------------------------------------------------
localparam          AWSIZE            = 3'b110;//64bytes 

// ---------------------------------------------------------------------------
// Local Signals/Flops
// ---------------------------------------------------------------------------
logic [7:0]  data_cnt             ;	


typedef enum logic [2:0] {

   ACE_LITE_AW_IDLE        = 3'b000,   //IDLE state  
                                       //address channel output signals assigned with default values

   ACE_LITE_AW_SEND_ADDR   = 3'b001,   //Send address State
                                       //address channel Output Signals changes the values
                     
   ACE_LITE_AW_WAIT_RDY    = 3'b010,   //Wait for awready State
                                       //address channel Output Signals hold the values

   ACE_LITE_AW_BRESP_CHK   = 3'b011,   //Write Response Check state

   ACE_LITE_AW_IN_PROG     = 3'b100    //Wait State

   } addr_states; 

addr_states    pstate,nstate;



//-------------------------------------------------------------------------------
// Write data Channel State Declaration
//-------------------------------------------------------------------------------

typedef enum logic [2:0] {

   ACE_LITE_W_IDLE          = 3'b000,  //IDLE state  
                                       //Write data channel output signals assigned with default values

   ACE_LITE_W_SEND_DATA     = 3'b001,  //Send data State                                
                                       //data channel Output Signals changes the values 

   ACE_LITE_W_WAIT_RDY      = 3'b010,  //Wait for wready State                         
                                       //data channel Output Signals hold the values

   ACE_LITE_W_DATA_DONE     = 3'b011,  //Write data done state

   ACE_LITE_W_BRESP_CHK     = 3'b100   //Write Response Check state
} data_states;

data_states      w_pstate,w_nstate;


//-------------------------------------------------------------------------------
// Captures the fifo occupancy on each final completion(fc)
//-------------------------------------------------------------------------------
logic [CE_HST2HPS_FIFO_DEPTH-1:0] fifo_cnt_q;

always_ff @ (posedge clk)
begin
   if (ce_corereset) 
   begin
      fifo_cnt_q    <= {CE_HST2HPS_FIFO_DEPTH{1'd0}};  
   end
   else if(axistrx_acelitetx_fc)
   begin
      fifo_cnt_q    <= cpldfifo_acelitetx_cnt;  
   end
end

//-------------------------------------------------------------------------------
// Captures the final completion bit and it is useful 
// to start sending data towards HPS
//-------------------------------------------------------------------------------
logic fc_q2;

always_ff @ (posedge clk)
begin
   if (ce_corereset) 
   begin
      fc_q2    <= 1'b0;  
   end
   //else if (pstate == ACE_LITE_AW_SEND_ADDR)
   else if (pstate == ACE_LITE_AW_BRESP_CHK)
   begin
      fc_q2    <= 1'b0;  
   end
   else if(axistrx_acelitetx_fc)
   begin
      fc_q2    <= 1'b1;  
   end
end

//-------------------------------------------------------------------------------
// Counts on each fc when it is read from FIFO2
//-------------------------------------------------------------------------------

logic [31:0] fc_cnt;

always_ff @ (posedge clk)
begin
   if (ce_corereset) 
   begin
      fc_cnt    <= 32'd0;  
   end
   else if(csr_acelitetx_mrdstart == 1'b0)
   begin
      fc_cnt    <= 32'd0; 
   end
   else if((cpldfifo_acelitetx_rddata[576] == 1'b1) && acelitetx_cpldfifo_ren)
   begin
      fc_cnt    <= fc_cnt+32'd1; 
   end

end

//-------------------------------------------------------------------------------
// Calculates number of read requests
//-------------------------------------------------------------------------------
logic [31:0] total_req_count;

always_ff @ (posedge clk)
begin
if (ce_corereset) 
   begin
      total_req_count    <= 32'd0;  
   end
   else if(csr_acelitetx_mrdstart)
   begin

      case(csr_acelitetx_datareqlimit)
         64 : 
               case(csr_acelitetx_imgxfrsize[31:0]% 64)
                     0: begin              //csr_Acelitetx_imgxfrsize >= csr_Acelitetx_datareqlimit and Image size programed is a multiple of data request limit
                           total_req_count <= csr_acelitetx_imgxfrsize[31:0]>>csr_acelitetx_datareqlimit_log2;
                     end
                     csr_acelitetx_imgxfrsize[31:0]: begin // csr_Acelitetx_imgxfrsize < csr_Acelitetx_datareqlimit
                           total_req_count <= 32'd1                      ;
                     end
                     default: begin // csr_Acelitetx_imgxfrsize > csr_Acelitetx_datareqlimit and Image size programed is NOT a multiple of data request limit
                           total_req_count <= ((csr_acelitetx_imgxfrsize[31:0]>>csr_acelitetx_datareqlimit_log2) + 32'd1 );
                     end
               endcase
         128 : 
               case(csr_acelitetx_imgxfrsize[31:0]% 128)
                     0: begin              //csr_Acelitetx_imgxfrsize >= csr_Acelitetx_datareqlimit and Image size programed is a multiple of data request limit
                           total_req_count <= csr_acelitetx_imgxfrsize[31:0]>>csr_acelitetx_datareqlimit_log2;
                     end
                     csr_acelitetx_imgxfrsize[31:0]: begin // csr_Acelitetx_imgxfrsize < csr_Acelitetx_datareqlimit
                           total_req_count <= 32'd1                      ;
                     end
                     default: begin // csr_Acelitetx_imgxfrsize > csr_Acelitetx_datareqlimit and Image size programed is NOT a multiple of data request limit
                           total_req_count <= ((csr_acelitetx_imgxfrsize[31:0] >> csr_acelitetx_datareqlimit_log2) + 32'd1 );
                     end
               endcase

         512 : 
               case(csr_acelitetx_imgxfrsize[31:0]% 512)
                     0: begin              //csr_Acelitetx_imgxfrsize >= csr_Acelitetx_datareqlimit and Image size programed is a multiple of data request limit
                           total_req_count <= csr_acelitetx_imgxfrsize[31:0] >> csr_acelitetx_datareqlimit_log2;
                     end
                     csr_acelitetx_imgxfrsize[31:0]: begin // csr_Acelitetx_imgxfrsize < csr_Acelitetx_datareqlimit
                           total_req_count <= 32'd1                      ;
                     end
                     default: begin // csr_Acelitetx_imgxfrsize > csr_Acelitetx_datareqlimit and Image size programed is NOT a multiple of data request limit
                           total_req_count <= ((csr_acelitetx_imgxfrsize[31:0] >> csr_acelitetx_datareqlimit_log2) + 32'd1 );
                     end
               endcase
         1024 : 
               case(csr_acelitetx_imgxfrsize[31:0]% 1024)
                     0: begin              //csr_Acelitetx_imgxfrsize >= csr_Acelitetx_datareqlimit and Image size programed is a multiple of data request limit
                           total_req_count <= csr_acelitetx_imgxfrsize[31:0] >> csr_acelitetx_datareqlimit_log2;
                     end
                     csr_acelitetx_imgxfrsize[31:0]: begin // csr_Acelitetx_imgxfrsize < csr_Acelitetx_datareqlimit
                           total_req_count <= 32'd1                      ;
                     end
                     default: begin // csr_Acelitetx_imgxfrsize > csr_Acelitetx_datareqlimit and Image size programed is NOT a multiple of data request limit
                           total_req_count <= ((csr_acelitetx_imgxfrsize[31:0] >> csr_acelitetx_datareqlimit_log2) + 32'd1 );
                     end
               endcase


      endcase
   end
   else
   begin
      total_req_count    <= 32'd0;  
   end
end

//-------------------------------------------------------------------------------
// Write address Channel State Machine
//-------------------------------------------------------------------------------

//--------------------------------------------------------
// Present State
//--------------------------------------------------------
always_ff@(posedge clk)
begin
   if(ce_corereset)
   begin
      pstate <= ACE_LITE_AW_IDLE;
   end
   else 
   begin
      pstate <= nstate ;
   end
end

//--------------------------------------------------------
// Next State
//--------------------------------------------------------

always_comb
begin
      case(pstate)

         ACE_LITE_AW_IDLE          :      if(fc_q2 && (!cpldfifo_acelitetx_empty)   && (acelitetx_bresp == 2'b00) && (!axistrx_acelitetx_cplerr) && (!csr_acelitetx_fifoerr)) 
                                          begin
                                             nstate = ACE_LITE_AW_SEND_ADDR; 
                                          end
                                          else
                                          begin
                                             nstate = ACE_LITE_AW_IDLE     ;
                                          end
         ACE_LITE_AW_SEND_ADDR     :      if(hps2ce_tx_awready)
                                          begin
                                             nstate = ACE_LITE_AW_BRESP_CHK;
                                          end
                                          else 
                                          begin
                                             nstate = ACE_LITE_AW_WAIT_RDY ;
                                          end
         ACE_LITE_AW_WAIT_RDY      :      if(hps2ce_tx_awready == 1'b1)
                                          begin
                                             nstate = ACE_LITE_AW_BRESP_CHK;
                                          end
                                          else
                                          begin
                                             nstate = ACE_LITE_AW_WAIT_RDY ;
                                          end
         ACE_LITE_AW_BRESP_CHK      :     if(hps2ce_tx_bvalid && ce2hps_tx_bready && (fc_cnt == total_req_count))   
                                          begin
                                             nstate = ACE_LITE_AW_IDLE     ;
                                          end
                                          else if(hps2ce_tx_bvalid && ce2hps_tx_bready && (fc_cnt < total_req_count)) 
                                          begin
                                             nstate = ACE_LITE_AW_IN_PROG;
                                          end
                                          else 
                                          begin
                                             nstate = ACE_LITE_AW_BRESP_CHK;
                                          end
         ACE_LITE_AW_IN_PROG        :     if((acelitetx_bresp != 2'b00) || axistrx_acelitetx_cplerr || csr_acelitetx_fifoerr)
                                          begin
                                             nstate = ACE_LITE_AW_IDLE     ;
                                          end
                                          else if(fc_q2 && (!cpldfifo_acelitetx_empty)) 
                                          begin
                                             nstate = ACE_LITE_AW_SEND_ADDR;
                                          end
                                          else 
                                          begin
                                             nstate = ACE_LITE_AW_IN_PROG;
                                          end
         default                    :     nstate = ACE_LITE_AW_IDLE         ;

   endcase
end


//--------------------------------------------------------
// Write address Channel Output Logic
//--------------------------------------------------------

logic addr_en;

always_ff@(posedge clk)
begin
   if(ce_corereset)
   begin
      ce2hps_tx_awvalid     <=  1'd0                     ; 
      ce2hps_tx_awaddr      <=  {CE_BUS_ADDR_WIDTH{1'd0}};
      ce2hps_tx_awprot      <=  3'd0                     ; 
      ce2hps_tx_awlen       <=  8'd0                     ; 
      ce2hps_tx_awsize      <=  3'd0                     ; 
      ce2hps_tx_awburst     <=  2'd0                     ; 
      addr_en               <=  1'b0                     ;  
   end
   else
   begin 
      case(nstate)

         ACE_LITE_AW_IDLE            : begin   
                                             ce2hps_tx_awvalid     <=  1'd0                     ; 
                                             ce2hps_tx_awaddr      <=  {CE_BUS_ADDR_WIDTH{1'd0}};
                                             ce2hps_tx_awprot      <=  3'd0                     ; 
                                             ce2hps_tx_awlen       <=  8'd0                     ; 
                                             ce2hps_tx_awsize      <=  3'd0                     ; 
                                             ce2hps_tx_awburst     <=  2'd0                     ;
                                             addr_en               <=  1'b0                     ;
                                       end
         ACE_LITE_AW_SEND_ADDR       : begin
                                             ce2hps_tx_awvalid     <=  1'd1  ;
                                             ce2hps_tx_awprot      <=  3'd0  ; 
                                             ce2hps_tx_awsize      <=  AWSIZE; 
                                             ce2hps_tx_awburst     <=  2'd1  ; 
                                             addr_en               <=  1'b1  ; 
                                             if(addr_en == 1'b1)
                                             begin
                                                //ce2hps_tx_awaddr  <=  ce2hps_tx_awaddr+ ((fifo_cnt_q+1'd1)*(2**AWSIZE));
                                                ce2hps_tx_awaddr  <=  ce2hps_tx_awaddr+ csr_acelitetx_datareqlimit; //Bug Fix
                                             end
                                             else
                                             begin
                                                ce2hps_tx_awaddr  <=  csr_acelitetx_hpsaddr[31:0];
                                             end
                                             ce2hps_tx_awlen       <=  fifo_cnt_q; 
                                       end
         ACE_LITE_AW_WAIT_RDY         :begin
                                             ce2hps_tx_awvalid     <=  ce2hps_tx_awvalid;
                                             ce2hps_tx_awaddr      <=  ce2hps_tx_awaddr ;
                                             ce2hps_tx_awprot      <=  ce2hps_tx_awprot ;
                                             ce2hps_tx_awlen       <=  ce2hps_tx_awlen  ;
                                             ce2hps_tx_awsize      <=  ce2hps_tx_awsize ;
                                             ce2hps_tx_awburst     <=  ce2hps_tx_awburst;
                                             addr_en               <=  addr_en          ;
                                       end
         ACE_LITE_AW_BRESP_CHK       : begin
                                             ce2hps_tx_awvalid     <=  1'b0             ;
                                             ce2hps_tx_awaddr      <=  ce2hps_tx_awaddr ;
                                             ce2hps_tx_awprot      <=  ce2hps_tx_awprot ;
                                             ce2hps_tx_awlen       <=  ce2hps_tx_awlen  ;
                                             ce2hps_tx_awsize      <=  ce2hps_tx_awsize ;
                                             ce2hps_tx_awburst     <=  ce2hps_tx_awburst;
                                             addr_en               <=  addr_en          ;
                                       end
         ACE_LITE_AW_IN_PROG         : begin
                                             ce2hps_tx_awvalid     <=  1'b0;
                                             ce2hps_tx_awaddr      <=  ce2hps_tx_awaddr ;
                                             ce2hps_tx_awprot      <=  ce2hps_tx_awprot ;
                                             ce2hps_tx_awlen       <=  ce2hps_tx_awlen  ;
                                             ce2hps_tx_awsize      <=  ce2hps_tx_awsize ;
                                             ce2hps_tx_awburst     <=  ce2hps_tx_awburst;
                                             addr_en               <=  addr_en;
                                       end
         default                     : begin   
                                             ce2hps_tx_awvalid     <=  1'd0; 
                                             ce2hps_tx_awaddr      <=  {CE_BUS_ADDR_WIDTH{1'd0}};
                                             ce2hps_tx_awprot      <=  3'd0; 
                                             ce2hps_tx_awlen       <=  8'd0; 
                                             ce2hps_tx_awsize      <=  3'd0; 
                                             ce2hps_tx_awburst     <=  2'd0;
                                             addr_en               <=  1'b0;
                                       end
      endcase
   end
end

//-------------------------------------------------------------------------------
// Write data Channel State Machine
//-------------------------------------------------------------------------------

//--------------------------------------------------------
// Present State
//--------------------------------------------------------
always_ff@(posedge clk)
begin
   if(ce_corereset)
   begin
         w_pstate <= ACE_LITE_W_IDLE;
   end
   else 
   begin
         w_pstate <= w_nstate;
   end
end

//--------------------------------------------------------
// Next State
//--------------------------------------------------------

always_comb
begin
      case(w_pstate)
         ACE_LITE_W_IDLE           :      if(fc_q2 && (!cpldfifo_acelitetx_empty) && (acelitetx_bresp == 2'b00) && (!axistrx_acelitetx_cplerr) && (!csr_acelitetx_fifoerr)) 
                                          begin
                                             w_nstate = ACE_LITE_W_SEND_DATA;
                                          end
                                          else
                                          begin
                                             w_nstate = ACE_LITE_W_IDLE;
                                          end
         ACE_LITE_W_SEND_DATA      :      if(hps2ce_tx_wready == 1'b1) 
                                          begin
                                             w_nstate = ACE_LITE_W_DATA_DONE;
                                          end
                                          else
                                          begin
                                             w_nstate = ACE_LITE_W_WAIT_RDY;
                                          end
         ACE_LITE_W_WAIT_RDY        :     if(hps2ce_tx_wready == 1'b1)
                                          begin
                                             w_nstate = ACE_LITE_W_DATA_DONE	;
                                          end
                                          else
                                          begin
                                             w_nstate = ACE_LITE_W_WAIT_RDY;
                                          end
         ACE_LITE_W_DATA_DONE       :     if(data_cnt == {3'd0,fifo_cnt_q} + 8'd1) 
                                          begin
                                             w_nstate = ACE_LITE_W_BRESP_CHK;
                                          end
                                          else if (!cpldfifo_acelitetx_empty) 
                                          begin
                                             w_nstate = ACE_LITE_W_SEND_DATA;
                                          end
                                          else 
                                          begin
                                             w_nstate = ACE_LITE_W_DATA_DONE;
                                          end
         ACE_LITE_W_BRESP_CHK       :     if(hps2ce_tx_bvalid && ce2hps_tx_bready) 
                                          begin
                                             w_nstate = ACE_LITE_W_IDLE;
                                          end
                                          else 
                                          begin
                                             w_nstate = ACE_LITE_W_BRESP_CHK;
                                          end
         default                     :     w_nstate = ACE_LITE_W_IDLE;
   endcase
end

//--------------------------------------------------------
// Write data Channel Output Logic
//--------------------------------------------------------

always_ff@(posedge clk)
begin
   if(ce_corereset)
   begin
      ce2hps_tx_wvalid       <=  1'd0; 
      ce2hps_tx_wlast        <=  1'd0;
      ce2hps_tx_wdata        <=  {CE_BUS_DATA_WIDTH{1'd0}};
      ce2hps_tx_wstrb        <=  {CE_BUS_STRB_WIDTH{1'd0}};
      data_cnt               <=  8'd0;
      acelitetx_cpldfifo_ren <=  1'b0;
   end
   else
   begin 
      case(w_nstate) 
         ACE_LITE_W_IDLE             :       begin   
                                                ce2hps_tx_wvalid        <=  1'd0; 
                                                ce2hps_tx_wlast         <=  1'd0;
                                                ce2hps_tx_wdata         <=  {CE_BUS_DATA_WIDTH{1'd0}};
                                                ce2hps_tx_wstrb         <=  {CE_BUS_STRB_WIDTH{1'd0}};
                                                data_cnt                <=  8'd0;
                                                acelitetx_cpldfifo_ren  <= ((axistrx_acelitetx_cplerr || (acelitetx_bresp != 2'b00)) && (!cpldfifo_acelitetx_empty)) ? 1'b1 : 1'b0;
                                             end
         ACE_LITE_W_SEND_DATA        :       begin         
                                                ce2hps_tx_wvalid        <= 1'd1;
                                                ce2hps_tx_wstrb         <= cpldfifo_acelitetx_rddata[63:0]; 
                                                ce2hps_tx_wdata         <= cpldfifo_acelitetx_rddata[575:64]; 
                                                ce2hps_tx_wlast         <= (data_cnt == {3'd0,fifo_cnt_q} )? 1'b1 : 1'b0;
                                                data_cnt                <= data_cnt+8'd1;
                                                acelitetx_cpldfifo_ren  <= (!cpldfifo_acelitetx_empty) ? 1'b1 : 1'b0; 
                                             end
         ACE_LITE_W_WAIT_RDY         :       begin
                                                ce2hps_tx_wvalid        <= ce2hps_tx_wvalid;   
                                                ce2hps_tx_wstrb         <= ce2hps_tx_wstrb;
                                                ce2hps_tx_wdata         <= ce2hps_tx_wdata;
                                                ce2hps_tx_wlast         <= ce2hps_tx_wlast;
                                                data_cnt                <= data_cnt;
                                                acelitetx_cpldfifo_ren  <= 1'b0;
                                             end
         ACE_LITE_W_DATA_DONE        :       begin
                                                ce2hps_tx_wvalid        <= 1'd0; 
                                                ce2hps_tx_wstrb         <= ce2hps_tx_wstrb;
                                                ce2hps_tx_wdata         <= ce2hps_tx_wdata;
                                                ce2hps_tx_wlast         <= 1'd0;
                                                data_cnt                <= data_cnt;
                                                acelitetx_cpldfifo_ren  <= 1'b0;
                                             end
         ACE_LITE_W_BRESP_CHK        :       begin
                                                ce2hps_tx_wvalid        <= 1'd0; 
                                                ce2hps_tx_wstrb         <= ce2hps_tx_wstrb;
                                                ce2hps_tx_wdata         <= ce2hps_tx_wdata;
                                                ce2hps_tx_wlast         <= 1'd0;
                                                data_cnt                <= data_cnt;
                                                acelitetx_cpldfifo_ren  <= 1'b0;
                                             end
         default                     :       begin   
                                                ce2hps_tx_wvalid        <=  1'd0; 
                                                ce2hps_tx_wlast         <=  1'd0;
                                                ce2hps_tx_wdata         <=  {CE_BUS_DATA_WIDTH{1'd0}};
                                                ce2hps_tx_wstrb         <=  {CE_BUS_STRB_WIDTH{1'd0}};
                                                data_cnt                <=  32'd0;
                                                acelitetx_cpldfifo_ren  <=  1'b0;
                                             end
      endcase
   end
end

//--------------------------------------------------------
// Write Response Extraction
//--------------------------------------------------------

logic [1:0] bresp_q;

assign acelitetx_bresp = ((w_pstate == ACE_LITE_W_BRESP_CHK)  &&  hps2ce_tx_bvalid && ce2hps_tx_bready) ? hps2ce_tx_bresp : bresp_q;


always_ff@(posedge clk)
begin
   if(ce_corereset)
   begin
         bresp_q <= 2'd0;
   end
   else 
   begin
         bresp_q <= acelitetx_bresp;
   end
end

assign acelitetx_bresperrpulse = ((w_pstate == ACE_LITE_W_BRESP_CHK)  &&  hps2ce_tx_bvalid && ce2hps_tx_bready && (hps2ce_tx_bresp != 2'b00)) ? 1'b1 : 1'b0;


//DMA done generation when all the data trasferred to HPS without any error
//
//assign Acelitetx_csr_dmadone = ((w_pstate == ACE_LITE_W_BRESP_CHK) && (tf_cnt == total_transfers) && hps2ce_tx_bvalid && (hps2ce_tx_bresp == 2'b00)) ? 1'b1 : 1'b0;
wire dmadone;
assign dmadone = ((w_pstate == ACE_LITE_W_BRESP_CHK) && (fc_cnt == total_req_count) && hps2ce_tx_bvalid && ce2hps_tx_bready && (hps2ce_tx_bresp == 2'b00)) ? 1'b1 : 1'b0;

always_ff@(posedge clk)
begin
   if(ce_corereset)
   begin
         acelitetx_csr_dmadone <= 1'b0;
   end
   else if(csr_acelitetx_mrdstart == 1'b0)
   begin
         acelitetx_csr_dmadone <= 1'b0;
   end
   else if(dmadone)
   begin
         acelitetx_csr_dmadone <= 1'b1;
   end
end

//-------------------------------------------------------------------------------
// Write Response channel ready Signal
//-------------------------------------------------------------------------------

always_ff @ (posedge clk)
begin
   if (ce_corereset) 
   begin
         ce2hps_tx_bready    <= 1'd0;  
   end
   else 
   begin
         ce2hps_tx_bready    <= ((w_nstate == ACE_LITE_W_BRESP_CHK)  &&  hps2ce_tx_bvalid) ? 1'b1 : 1'b0;  
   end
end

//-------------------------------------------------------------------------------
//request Enable- ce can issue read req to host
//-------------------------------------------------------------------------------
always_ff @ (posedge clk)
begin
   if (ce_corereset) 
   begin
         acelitetx_axisttx_req_en      <= 1'd0;  
   end
   else if(nstate == ACE_LITE_AW_SEND_ADDR) 
   begin
         acelitetx_axisttx_req_en      <= 1'd0;  
   end
   else if((hps2ce_tx_bvalid && ce2hps_tx_bready) || (csr_acelitetx_mrdstart && (pstate == ACE_LITE_AW_IDLE)) ) //assertions
   begin
         acelitetx_axisttx_req_en      <=  1'b1;   
   end
end

// ---------------------------------------------------------------------------
// Registering the ACE-Lite Specific output Signals from Copy Engine
// Temporary tie off 
// ---------------------------------------------------------------------------
always_ff@(posedge clk)
begin
   if(ce_corereset)
   begin
         ce2hps_tx_awsnoop  <=  3'd0;
         ce2hps_tx_awdomain <=  2'd0;
         ce2hps_tx_awbar    <=  2'd0;
   end
   else
   begin
         ce2hps_tx_awsnoop  <=  3'd0;
         ce2hps_tx_awdomain <=  2'd3;
         ce2hps_tx_awbar    <=  2'd0;
   end
end

// ---------------------------------------------------------------------------
// Debug Logic
// ---------------------------------------------------------------------------
`ifdef INCLUDE_CE_DEBUG

(*preserve*)logic [10:0]  send_addr_state_cnt;/* synthesis noprune */

always_ff @ (posedge clk)
begin
   if (ce_corereset) 
   begin
      send_addr_state_cnt    <= 11'd0;  
   end
   else if(pstate == ACE_LITE_AW_SEND_ADDR)
   begin
      send_addr_state_cnt    <= send_addr_state_cnt + 11'd1; 
   end
   else
   begin
      send_addr_state_cnt    <= 11'd0;  
   end
end

(*preserve*)logic [10:0]  bresp_chk_state_cnt;/* synthesis noprune */
//logic [10:0] bresp_chk_state_cnt;

always_ff @ (posedge clk)
begin
   if (ce_corereset) 
   begin
      bresp_chk_state_cnt    <= 11'd0;  
   end
   else if(pstate == ACE_LITE_AW_BRESP_CHK)
   begin
      bresp_chk_state_cnt    <= bresp_chk_state_cnt + 31'd1; 
   end
   else
   begin
      bresp_chk_state_cnt    <= 11'd0;  
   end
end

//logic [10:0] send_data_state_cnt;
(*preserve*)logic [10:0]  send_data_state_cnt;/* synthesis noprune */

always_ff @ (posedge clk)
begin
   if (ce_corereset) 
   begin
      send_data_state_cnt    <= 11'd0;  
   end
   else if(pstate == ACE_LITE_W_SEND_DATA)
   begin
      send_data_state_cnt    <= send_data_state_cnt + 11'd1; 
   end
   else
   begin
      send_data_state_cnt    <= 11'd0;  
   end
end

`endif

endmodule

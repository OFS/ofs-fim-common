// Copyright 2020-2021 Intel Corporation
// SPDX-License-Identifier: MIT

// *****************************************************************************
//
// Create Date : August 2020
// Module Name : axi_avl_st_bridge
// Project     : Arror Creek (Xeon + FPGA)
// Description : AXI Avalon streaming bridge 
//
// *****************************************************************************
//
// ===========================================================================================================================================================
// Notes 
// ===========================================================================================================================================================
//
// Directions RX and TX are specified using AXI as a reference. Each interface enters the bridge through parameterized Hyper Flex pipes. This is done to help 
// with timing closure.
//
// AVST firstSymbolInHighOrderBits is assumed to be false(default value is true according to the spec). So bytes are rearranged while convering avst_data to 
// axi_data and vice-versa if this is set to 1.
// 
// RX Path
// - Converting tkeep to empty requires a 64:6 priority encoder. This is implemented with a latency of 3 clocks. Hence the pipelining from T1 to T3.
//   Refer the note above the priority encoder to understand the logic.
// 
// - sop_valid and sop_init are used to generate the avst_sop signal. sop_init is 1 on reset and is only used to generate the first avst_sop. sop_valid is 
//   used thereafter. Refer the notes above the sop_valid always block.
//
// - Backpressure rx_axi_tready is derived from rx_avst_full but the AXI Hyperflex pipes in between must be taken into account. So the total stages are
//   AXI_RX_NUM_PIPES + 2. In addition since there are flop stages b/w rx_axi_tvalid and rx_avst_wen, that needs to taken into account as well. i.e. 
//   AXI_RX_NUM_PIPES + 5. Total FIFO threshold should be = (AXI_RX_NUM_PIPES * 2) + 7
//
// TX Path
// - Converting avst_empty to axi_tkeep uses a table of all possible tkeep values. Based on the value of tx_avst_empty, the value of tkeep is looked up and 
//   populated. There is helper code at the bottom of this file to help generate the pattern of the tkeep table.  
//
// - Backpressure tx_avst_ready is derived from the FIFO full signal. Due to the hyperflex pipes attached to tx_axi_ready on the input, there must be some
//   allowance within the bridge to store packets already in flight. For this a FIFO is used along the TX Path. 
//   
//   The full signal of the FIFO determines the value of tx_avst_ready and the threshold value of the FIFO must account for AVST_TX_NUM_PIPES + 2 cycles.
//   in addition, tx_avst_valid also has a hyperflex pipe in its path followed by 3 stages. So FIFO threshold is (AVST_TX_NUM_PIPES * 2) + 5 cycles. 
//      
//   The FIFO is read, when tx_axi_tready is 1. tx_axi_tvalid is generated from the FIFO not_empty signal. However, the FIFO is only read when tx_axi_tvalid
//   & tx_axi_tready are high in accordance with the AXI protocol.
//                                                                                                                                                        
//                                                                                                                                                   
//    rx_axi_tvalid        rx_axi_tready            tx_axi_tvalid   tx_axi_tready                              
//         |                   ^                           ^              |                                     
//         |                   |                           |              |                                     
//         |                   |                           |              |                                     
//         |                   |                           |              |                                     
//         |                   |                           |              |                                     
//        \/                   |                           |              |                                     
//   +-------------------------+--------+       +----------|-------------\/-----+                          
//   |                                  |       |          |                    |                         
//   | rx_axi_tkeep                     |       |     +----+---+                |                          
//   |    |                             |       |     |tx_axi_q|                |                          
//   |    |       RX Path               |       |     |        |  TX Path       |                          
//   |  +-+-------------+               |       |     |        |                |                          
//   |  | pri_enc       |               |       |     |        |                |                          
//   |  |  64:6         |               |       |     |        |                |                          
//   |  |               |               |       |     +----+-+-+                |                          
//   |  +--+------------+               |       |          | |     ~full        |                          
//   |     | rx_avst_empty              |       |          | +-----------+      |                          
//   |                                  |       |          |             |      |
//   +-----|--------------------^-------+       +----------^-------------|------+                          
//         |                    |                          |             |                                     
//         |                    |                          |             |                                     
//         |                    |                          |             |                                     
//         |                    |                          |             |                                     
//         |                    |                          |             |                                     
//         |                    |                          |             |                                     
//         \/                   |                          |             \/                                     
//  rx_avst_valid          rx_avst_ready            tx_avst_valid   tx_avst_ready                              
//     
//     
// ===========================================================================================================================================================
// RX Timing 
// ===========================================================================================================================================================
//
//  ----------------------------------------------------------------------------------------------------------------------------------------------------------
// | Interface             |   | T1                    | T2                      | T3                    | T4                    |   |                       |
//  ----------------------------------------------------------------------------------------------------------------------------------------------------------
// |                       |   |                       |                         |                       |                       |   |                       |
// | rx_axi_tvalid         | H | rx_axi_tvalid_T1      | rx_axi_tvalid_T2        | rx_axi_tvalid_T3      | rx_avst_valid_p       | F | rx_avst_valid         |
// |                       | F |                       |                         |                       |                       | I |                       |
// |                       | P | rx_axi_tkeep_T1       |                         |                       | rx_avst_empty_p       | F |                       |
// |                       | I |                       |                         |                       |                       | O |                       |
// |                       | P |                       |                         | sop_valid             | rx_avst_sop_p         |   |                       |
// |                       | E |                       |                         |                       |                       |   |                       |
// |                       |   |                       |                         |                       |                       |   |                       |
//
//
// ===========================================================================================================================================================
// TX Timing 
// ===========================================================================================================================================================
//
//  ----------------------------------------------------------------------------------------------------------------------------------
// | Interface             |   | T1                    | T2                      | T3                    |   | T4                    |
//  ----------------------------------------------------------------------------------------------------------------------------------
// | tx_avst_valid         |   | tx_avst_valid_T1      | tx_axi_tvalid_T2        |                       |   |                       |
// |                       | H |                       |                         |                       |   |                       |
// |                       | F |                       |                         | tx_axi_wen            | F |                       |
// |                       | P |                       |                         | tx_axi_din            | I | tx_axi_dout           |
// |                       | I |                       |                         |                       | F | tx_axi_nemp           |
// |                       | P |                       |                         |                       | O |                       |
// |                       | E |                       |                         |                       |   | tx_axi_tvalid         |
// |                       |   |                       |                         |                       |   |                       |
//
//
// ===========================================================================================================================================================
//
// Done: tkeep table values for 768 b
// Done: 96:7 Pri Encoder for tkeep to tempty
// Done: Talk with Vaibhav about mapping between tuser and error signals. Done
//       they dont map. tuser doesn't need to be sent beyond this bridge. But is 
//       connected to avst_error if needed. Optional to use. 
// Done: Check data format conversion from AXI-AVST. Added a param
//       AVST_FIRST_SYM_HIGH_ORDER to pick the format.
//
// ===========================================================================================================================================================

module axi_avl_st_bridge #(
  parameter  SIM_EMULATE               = 1'b0                  ,  // 1 for simulations
  parameter  DATA_WIDTH                = 512                   ,  // Can only be 512 or 768
  parameter  AXI_TUSER_WIDTH           = 10                    ,  // Decided based on requirement 
  parameter  AVST_ERROR_WIDTH          = 10                    ,  // Decided based on requirement
  localparam AVST_EMPTY_WIDTH          = $clog2(DATA_WIDTH/8)  ,  // 6 for DATA_WIDTH=512, 7 for 768
  parameter  AVST_FIRST_SYM_HIGH_ORDER = 0                     ,  // First symbol in high order bits
  parameter  AXI_RX_NUM_PIPES          = 1                     ,
  parameter  AVST_RX_NUM_PIPES         = 1                     ,
  parameter  AXI_TX_NUM_PIPES          = 1                     ,
  parameter  AVST_TX_NUM_PIPES         = 1
)
(
  input  logic                         clk            , 
  input  logic                         resetb         ,

  //AXI-ST Input 
  input  logic                         rx_axi_tvalid  ,  
  input  logic [DATA_WIDTH-1:0]        rx_axi_tdata   ,
  input  logic [(DATA_WIDTH/8)-1:0]    rx_axi_tkeep   ,
  input  logic                         rx_axi_tlast   ,
  input  logic [AXI_TUSER_WIDTH-1:0]   rx_axi_tuser   ,
  output logic                         rx_axi_tready  ,

  //AXI-ST Output 
  output logic                         tx_axi_tvalid  ,  
  output logic [DATA_WIDTH-1:0]        tx_axi_tdata   ,
  output logic [(DATA_WIDTH/8)-1:0]    tx_axi_tkeep   ,
  output logic                         tx_axi_tlast   ,
  output logic [AXI_TUSER_WIDTH-1:0]   tx_axi_tuser   ,
  input  logic                         tx_axi_tready  ,

  //Avalon-ST Output
  output logic                         rx_avst_valid  ,
  output logic [DATA_WIDTH-1:0]        rx_avst_data   , 
  output logic [AVST_EMPTY_WIDTH-1:0]  rx_avst_empty  , //Number of empty bytes
  output logic                         rx_avst_eop    ,
  output logic                         rx_avst_sop    ,
  output logic [AVST_ERROR_WIDTH-1:0]  rx_avst_error  ,
  input  logic                         rx_avst_ready  ,

  //Avalon-ST Output
  input  logic                         tx_avst_valid  ,
  input  logic [DATA_WIDTH-1:0]        tx_avst_data   , 
  input  logic [AVST_EMPTY_WIDTH-1:0]  tx_avst_empty  , //Number of empty bytes
  input  logic                         tx_avst_eop    ,
  input  logic                         tx_avst_sop    ,
  input  logic [AVST_ERROR_WIDTH-1:0]  tx_avst_error  ,
  output logic                         tx_avst_ready  
);

  // ---------------------------------------------------------------------------
  // LOCAL PARAMETERS
  // ---------------------------------------------------------------------------
  localparam NUM_BYTES               = DATA_WIDTH/8;
  localparam BYTE_INDEX_WIDTH        = $clog2(NUM_BYTES); 
  localparam TX_AVST_READY_ALLOWANCE = (AVST_TX_NUM_PIPES * 2) + 5;
  localparam RX_AVST_READY_ALLOWANCE = (AXI_RX_NUM_PIPES * 2) + 7;

  localparam TX_AXI_Q_WIDTH         = DATA_WIDTH + (DATA_WIDTH/8) + 1 + AXI_TUSER_WIDTH;
  localparam TX_AXI_Q_DEPTH_B2      = 4; 
  localparam TX_AXI_Q_FULL_TH       = (2**TX_AXI_Q_DEPTH_B2) - TX_AVST_READY_ALLOWANCE;

  localparam RX_AVST_Q_WIDTH         = DATA_WIDTH + AVST_EMPTY_WIDTH + 2 + AVST_ERROR_WIDTH;
  localparam RX_AVST_Q_DEPTH_B2      = 4; 
  localparam RX_AVST_Q_FULL_TH       = (2**RX_AVST_Q_DEPTH_B2) - RX_AVST_READY_ALLOWANCE;

  // ---------------------------------------------------------------------------
  // PIPELINE STAGES
  // ---------------------------------------------------------------------------
  logic                         rx_axi_tvalid_T1 ;  
  logic [DATA_WIDTH-1:0]        rx_axi_tdata_T1  ;
  logic [NUM_BYTES-1:0]         rx_axi_tkeep_T1  ;
  logic                         rx_axi_tlast_T1  ;
  logic [AXI_TUSER_WIDTH-1:0]   rx_axi_tuser_T1  ;
  logic                         rx_axi_tready_p  ;

  logic                         rx_axi_tvalid_T2 ;  
  logic [DATA_WIDTH-1:0]        rx_axi_tdata_T2  ;
  logic                         rx_axi_tlast_T2  ;
  logic [AXI_TUSER_WIDTH-1:0]   rx_axi_tuser_T2  ;

  logic                         rx_axi_tvalid_T3 ;  
  logic [DATA_WIDTH-1:0]        rx_axi_tdata_T3  ;
  logic                         rx_axi_tlast_T3  ;
  logic [AXI_TUSER_WIDTH-1:0]   rx_axi_tuser_T3  ;

  logic                         rx_avst_valid_p  ;
  logic [DATA_WIDTH-1:0]        rx_avst_data_p   ; 
  logic [AVST_EMPTY_WIDTH-1:0]  rx_avst_empty_p  ; //Number of empty bytes
  logic                         rx_avst_eop_p    ;
  logic                         rx_avst_sop_p    ;
  logic [AVST_ERROR_WIDTH-1:0]  rx_avst_error_p  ;
  logic                         rx_avst_ready_q  ;

  logic                         tx_avst_valid_T1 ;
  logic [DATA_WIDTH-1:0]        tx_avst_data_T1  ; 
  logic [AVST_EMPTY_WIDTH-1:0]  tx_avst_empty_T1 ; //Number of empty bytes
  logic                         tx_avst_eop_T1   ;
  logic                         tx_avst_sop_T1   ;
  logic [AVST_ERROR_WIDTH-1:0]  tx_avst_error_T1 ;
  logic                         tx_avst_ready_p  ;

  logic                         tx_axi_tvalid_T2 ;  
  logic [DATA_WIDTH-1:0]        tx_axi_tdata_T2  ;
  logic [NUM_BYTES-1:0]         tx_axi_tkeep_T2  ;
  logic                         tx_axi_tlast_T2  ;
  logic [AXI_TUSER_WIDTH-1:0]   tx_axi_tuser_T2  ;
  logic                         tx_axi_tready_T2 ;

  logic                         tx_axi_tvalid_p  ;  
  logic [DATA_WIDTH-1:0]        tx_axi_tdata_p   ;
  logic [NUM_BYTES-1:0]         tx_axi_tkeep_p   ;
  logic                         tx_axi_tlast_p   ;
  logic [AXI_TUSER_WIDTH-1:0]   tx_axi_tuser_p   ;
  logic                         tx_axi_tready_q  ;

  // ---------------------------------------------------------------------------
  // TX AXI QUEUE
  // ---------------------------------------------------------------------------
  logic [TX_AXI_Q_WIDTH-1:0]    tx_axi_din       ;//
  logic                         tx_axi_wen       ;//
  logic                         tx_axi_ren       ;//
  logic [TX_AXI_Q_WIDTH-1:0]    tx_axi_dout      ;//
  logic                         tx_axi_full      ;//
  logic                         tx_axi_nemp      ;//
  logic [1:0]                   tx_axi_ecc       ;//
  logic                         tx_axi_err       ;//

  // ---------------------------------------------------------------------------
  // RX AVST QUEUE
  // ---------------------------------------------------------------------------
  logic [RX_AVST_Q_WIDTH-1:0]   rx_avst_din      ;//
  logic                         rx_avst_wen      ;//
  logic                         rx_avst_ren      ;//
  logic [RX_AVST_Q_WIDTH-1:0]   rx_avst_dout     ;//
  logic                         rx_avst_full     ;//
  logic                         rx_avst_nemp     ;//
  logic [1:0]                   rx_avst_ecc      ;//
  logic                         rx_avst_err      ;//

  // ---------------------------------------------------------------------------
  // Local Signals/Flops
  // ---------------------------------------------------------------------------
  logic                         resetb_q               ;
  logic                         sop_valid              ;
  logic                         sop_init               ;
  logic [6:0]                   num_valid_bytes        ;//512-max value = 64, 768-max value = 96 
  logic [NUM_BYTES-1:0]         tkeep [NUM_BYTES-1:0]  ;//tkeep table

  //Loop indexing variables
  integer i, j;

  //Reset
  hf_pipe # (
    .WIDTH($bits({resetb})),
    .DEPTH(3)
  )
  reset_reg (
    .clk  (clk),
    .Din  (resetb),
    .Qout (resetb_q)
  );

  //===============================================================================================
  // RX Path
  //===============================================================================================

  // Rx AXI Pipelining
  hf_pipe # (
    .WIDTH($bits({rx_axi_tvalid, rx_axi_tdata, rx_axi_tkeep, rx_axi_tlast, rx_axi_tuser})),
    .DEPTH(AXI_RX_NUM_PIPES)
  )
  rx_axi_reg (
    .clk  (clk),
    .Din  ({(rx_axi_tvalid & rx_axi_tready),    rx_axi_tdata,    rx_axi_tkeep,    rx_axi_tlast,    rx_axi_tuser  }),
    .Qout ({rx_axi_tvalid_T1, rx_axi_tdata_T1, rx_axi_tkeep_T1, rx_axi_tlast_T1, rx_axi_tuser_T1})
  );

  hf_pipe # (
    .WIDTH($bits({rx_axi_tready})),
    .DEPTH(AXI_RX_NUM_PIPES)
  )
  rx_axi_rdy_reg (
    .clk  (clk),
    .Din  (rx_axi_tready_p),
    .Qout (rx_axi_tready)
  );

  always @ (posedge clk)
  begin
    rx_axi_tvalid_T2 <= rx_axi_tvalid_T1;
    rx_axi_tdata_T2  <= rx_axi_tdata_T1; 
    rx_axi_tlast_T2  <= rx_axi_tlast_T1; 
    rx_axi_tuser_T2  <= rx_axi_tuser_T1; 

    rx_axi_tvalid_T3 <= rx_axi_tvalid_T2;
    rx_axi_tdata_T3  <= rx_axi_tdata_T2; 
    rx_axi_tlast_T3  <= rx_axi_tlast_T2; 
    rx_axi_tuser_T3  <= rx_axi_tuser_T2; 

    rx_avst_valid_p  <= rx_axi_tvalid_T3;
    rx_avst_eop_p    <= rx_axi_tlast_T3;
    rx_avst_sop_p    <= rx_axi_tvalid_T3 & (sop_valid | sop_init);
    rx_avst_error_p  <= '0; //Unused
 
    //If AVST_FIRST_SYM_HIGH_ORDER == 1
      //avst_data[511:480] <= axi_data[31:0]
      //avst_data[479:448] <= axi_data[63:32]
      //...
      //...
      //avst_data[63:32]   <= axi_data[479:448]
      //avst_data[31:0]    <= axi_data[511:480]
    //else
      //avst_data[511:0] <= axi_data[511:0]

    if(AVST_FIRST_SYM_HIGH_ORDER == 1)
    begin
      for(i=0; i<DATA_WIDTH/8; i++)
      begin
        rx_avst_data_p[(DATA_WIDTH-(8*(i+1)))+:8] <= rx_axi_tdata_T3[(i*8)+:8]; 
      end
    end
    else
    begin
      rx_avst_data_p <= rx_axi_tdata_T3;
    end

    if(!resetb_q)
    begin
      rx_avst_valid_p <= 1'b0;
    end

    rx_axi_tready_p <= rx_avst_ready_q;
  end //always

  // Generate avst_sop - T3
  // sop_init is only used to generate the very first avst_sop. 
  // sop_init = 1 on reset, thereafter is always 0.
  // sop_valid is 0 on reset. Thereafter it is only changed when
  // rx_axi_tvalid is 1 and follows rx_axi_tlast. 
  always @ (posedge clk)
  begin

    //sop_valid
    if(rx_axi_tvalid_T3)
    begin 
      sop_valid <= rx_axi_tlast_T3;
    end
    else
    begin
      sop_valid <= sop_valid;
    end

    //sop_init
    if(sop_init & rx_axi_tvalid_T3)
    begin
      sop_init  = 1'b0;
    end

    if(!resetb_q)
    begin
      sop_valid <= 1'b0;
      sop_init  <= 1'b1;
    end
  end //always

  // Conversion of tkeep to empty
  // Priority Enc - Output: Index of the rightmost 1.
  // Latency - 3 cycles
  // Since in finds the index of rightmost 1, tkeep is inverted. The rightmost 1 
  // then indicates how many bytes are valid in the packet.  
  // NUM_BYTES - dout = No. of empty bytes 
  // Ex. axi_tkeep  = 64'h0000_0000_3ffff_ffff (Implies 30 valid bytes)
  //     !axi_tkeep = 64'hffff_ffff_c000_0000
  //     num_valid_bytes = 30 
  // The exception however, is when, axi_tkeep = 64'hffff_ffff_ffff_ffff
  // This means 64 bytes are valid but the pri_enc us unable to indicate this
  // because the max index is 63. 

  generate

  if(NUM_BYTES > 64)
  begin
  pri_enc_96_7 #(
    .SIM_EMULATE(SIM_EMULATE)
  ) 
  pri_enc
  (
    .clk  (clk),     
    .din  (~rx_axi_tkeep_T1),  
    .dout (num_valid_bytes) //T4 
  );
  
  end

  else
  begin
  pri_enc_64_6 #(
    .SIM_EMULATE(SIM_EMULATE)
  ) 
  pri_enc
  (
    .clk  (clk),     
    .din  (~rx_axi_tkeep_T1),  
    .dout (num_valid_bytes) //T4 
  );
  end

  endgenerate

  // The format of this assignment causes a truncation related warning 
  // The fix is below it but commented because synopsys doesn't like it. Quartus
  // however is fine. 
  assign rx_avst_empty_p = (rx_avst_eop_p) ? (NUM_BYTES - num_valid_bytes) //T4
                                           : {AVST_EMPTY_WIDTH{1'b0}};
  //  assign rx_avst_empty_p = (rx_avst_eop_p) ? {NUM_BYTES - num_valid_bytes}[AVST_EMPTY_WIDTH-1:0] //T4
  //                                           : {AVST_EMPTY_WIDTH{1'b0}};

  always @ (posedge clk)
  begin
    rx_avst_wen     <= rx_avst_valid_p;
    rx_avst_din     <= {rx_avst_data_p, rx_avst_empty_p, rx_avst_error_p, rx_avst_eop_p, rx_avst_sop_p};
    
    rx_avst_ready_q <= !rx_avst_full;

    if(!resetb_q)
    begin
      rx_avst_wen <= 1'b0;
    end
  end

  always_comb
  begin
    rx_avst_valid   = rx_avst_nemp;
    rx_avst_ren     = rx_avst_valid & rx_avst_ready;
   
    {rx_avst_data, 
     rx_avst_empty, 
     rx_avst_error, 
     rx_avst_eop, 
     rx_avst_sop}   = rx_avst_dout;
  end

  //===============================================================================================
  // TX Path
  //===============================================================================================
 
  // Tx Pipelining
  hf_pipe # (
    .WIDTH($bits({tx_avst_valid, tx_avst_data, tx_avst_empty, tx_avst_eop, tx_avst_sop, tx_avst_error})),
    .DEPTH(AVST_TX_NUM_PIPES)
  )
  tx_avst_reg (
    .clk  (clk),
    .Din  ({tx_avst_valid & tx_avst_ready,    tx_avst_data,    tx_avst_empty,    tx_avst_eop,    tx_avst_sop,    tx_avst_error}),
    .Qout ({tx_avst_valid_T1, tx_avst_data_T1, tx_avst_empty_T1, tx_avst_eop_T1, tx_avst_sop_T1, tx_avst_error_T1})
  );

  hf_pipe # (
    .WIDTH($bits({tx_avst_ready})),
    .DEPTH(AVST_TX_NUM_PIPES)
  )
  tx_avst_rdy_reg (
    .clk  (clk),
    .Din  (tx_avst_ready_p),
    .Qout (tx_avst_ready)
  );

  assign tx_avst_ready_p = !tx_axi_full;

  always @ (posedge clk)
  begin
    tx_axi_tvalid_T2  <= tx_avst_valid_T1;
    tx_axi_tuser_T2   <= tx_avst_error_T1;
    tx_axi_tlast_T2   <= tx_avst_eop_T1;

    if(AVST_FIRST_SYM_HIGH_ORDER == 1)
    begin
      for(j=0; j<DATA_WIDTH/8; j++)
      begin
        tx_axi_tdata_T2[(DATA_WIDTH-(8*(j+1)))+:8] <= tx_avst_data_T1[(j*8)+:8]; 
      end
    end
    else
    begin
      tx_axi_tdata_T2 <= tx_avst_data_T1;
    end

    tx_axi_tkeep_T2   <= tx_avst_eop_T1 ? tkeep[tx_avst_empty_T1][NUM_BYTES-1:0] : {NUM_BYTES{1'b1}};
   
    //Write to FIFO
    tx_axi_wen        <= tx_axi_tvalid_T2;
    tx_axi_din        <= {tx_axi_tdata_T2, tx_axi_tkeep_T2, tx_axi_tuser_T2, tx_axi_tlast_T2};

    if(!resetb_q)
    begin
      tx_axi_wen      <= 1'b0;
    end
  end

  always_comb
  begin
    tx_axi_tvalid  = tx_axi_nemp;
    tx_axi_ren     = tx_axi_tvalid & tx_axi_tready;

    {tx_axi_tdata, 
     tx_axi_tkeep, 
     tx_axi_tuser, 
     tx_axi_tlast} = tx_axi_dout; 
  end //always


  //----------------------------------------------------------------------------
  // TX AXI FIFO
  //----------------------------------------------------------------------------
  quartus_bfifo 
  #(.WIDTH             ( TX_AXI_Q_WIDTH    )     ,// 
    .DEPTH             ( TX_AXI_Q_DEPTH_B2 )     ,// 
    .FULL_THRESHOLD    ( TX_AXI_Q_FULL_TH  )     ,//
    .REG_OUT           ( 1                 )     ,// 
    .RAM_STYLE         ( "AUTO"            )     ,//
    .ECC_EN            ( 0                 )      //
  )  
  tx_axi_q 
  (
    .fifo_din          ( tx_axi_din        )     ,// FIFO write data in
    .fifo_wen          ( tx_axi_wen        )     ,// FIFO write enable
    .fifo_ren          ( tx_axi_ren        )     ,// FIFO read enable
    .clk               ( clk               )     ,// clock
    .Resetb            ( resetb_q          )     ,// Reset active low

    .fifo_dout         ( tx_axi_dout       )     ,// FIFO read data out registered
    .almost_full       ( tx_axi_full       )     ,// FIFO count > FULL_THRESHOLD
    .not_empty         ( tx_axi_nemp       )     ,// FIFO is not empty

    .fifo_eccstatus    ( tx_axi_ecc        )     ,// FIFO parity error
    .fifo_err          ( tx_axi_err        )      // FIFO overflow/underflow error
  );

  //----------------------------------------------------------------------------
  // RX AVST FIFO
  //----------------------------------------------------------------------------
  quartus_bfifo 
  #(.WIDTH             ( RX_AVST_Q_WIDTH    )     ,// 
    .DEPTH             ( RX_AVST_Q_DEPTH_B2 )     ,// 
    .FULL_THRESHOLD    ( RX_AVST_Q_FULL_TH  )     ,//
    .REG_OUT           ( 1                  )     ,// 
    .RAM_STYLE         ( "AUTO"             )     ,//
    .ECC_EN            ( 0                  )      //
  )  
  rx_avst_q 
  (
    .fifo_din          ( rx_avst_din        )     ,// FIFO write data in
    .fifo_wen          ( rx_avst_wen        )     ,// FIFO write enable
    .fifo_ren          ( rx_avst_ren        )     ,// FIFO read enable
    .clk               ( clk                )     ,// clock
    .Resetb            ( resetb_q           )     ,// Reset active low

    .fifo_dout         ( rx_avst_dout       )     ,// FIFO read data out registered
    .almost_full       ( rx_avst_full       )     ,// FIFO count > FULL_THRESHOLD
    .not_empty         ( rx_avst_nemp       )     ,// FIFO is not empty

    .fifo_eccstatus    ( rx_avst_ecc        )     ,// FIFO parity error
    .fifo_err          ( rx_avst_err        )      // FIFO overflow/underflow error
  );

  //----------------------------------------------------------------------------
  // tkeep Table 
  // Values pre-computed
  // Index is avst_empty, value is kteep
  //----------------------------------------------------------------------------
  generate //tkeep

  if(NUM_BYTES > 64)
  begin
    always @ (posedge clk)
    begin
      tkeep[95] <= 96'h000000000000000000000001;
      tkeep[94] <= 96'h000000000000000000000003;
      tkeep[93] <= 96'h000000000000000000000007;
      tkeep[92] <= 96'h00000000000000000000000f;
      tkeep[91] <= 96'h00000000000000000000001f;
      tkeep[90] <= 96'h00000000000000000000003f;
      tkeep[89] <= 96'h00000000000000000000007f;
      tkeep[88] <= 96'h0000000000000000000000ff;
      tkeep[87] <= 96'h0000000000000000000001ff;
      tkeep[86] <= 96'h0000000000000000000003ff;
      tkeep[85] <= 96'h0000000000000000000007ff;
      tkeep[84] <= 96'h000000000000000000000fff;
      tkeep[83] <= 96'h000000000000000000001fff;
      tkeep[82] <= 96'h000000000000000000003fff;
      tkeep[81] <= 96'h000000000000000000007fff;
      tkeep[80] <= 96'h00000000000000000000ffff;
      tkeep[79] <= 96'h00000000000000000001ffff;
      tkeep[78] <= 96'h00000000000000000003ffff;
      tkeep[77] <= 96'h00000000000000000007ffff;
      tkeep[76] <= 96'h0000000000000000000fffff;
      tkeep[75] <= 96'h0000000000000000001fffff;
      tkeep[74] <= 96'h0000000000000000003fffff;
      tkeep[73] <= 96'h0000000000000000007fffff;
      tkeep[72] <= 96'h000000000000000000ffffff;
      tkeep[71] <= 96'h000000000000000001ffffff;
      tkeep[70] <= 96'h000000000000000003ffffff;
      tkeep[69] <= 96'h000000000000000007ffffff;
      tkeep[68] <= 96'h00000000000000000fffffff;
      tkeep[67] <= 96'h00000000000000001fffffff;
      tkeep[66] <= 96'h00000000000000003fffffff;
      tkeep[65] <= 96'h00000000000000007fffffff;
      tkeep[64] <= 96'h0000000000000000ffffffff;
      tkeep[63] <= 96'h0000000000000001ffffffff;
      tkeep[62] <= 96'h0000000000000003ffffffff;
      tkeep[61] <= 96'h0000000000000007ffffffff;
      tkeep[60] <= 96'h000000000000000fffffffff;
      tkeep[59] <= 96'h000000000000001fffffffff;
      tkeep[58] <= 96'h000000000000003fffffffff;
      tkeep[57] <= 96'h000000000000007fffffffff;
      tkeep[56] <= 96'h00000000000000ffffffffff;
      tkeep[55] <= 96'h00000000000001ffffffffff;
      tkeep[54] <= 96'h00000000000003ffffffffff;
      tkeep[53] <= 96'h00000000000007ffffffffff;
      tkeep[52] <= 96'h0000000000000fffffffffff;
      tkeep[51] <= 96'h0000000000001fffffffffff;
      tkeep[50] <= 96'h0000000000003fffffffffff;
      tkeep[49] <= 96'h0000000000007fffffffffff;
      tkeep[48] <= 96'h000000000000ffffffffffff;
      tkeep[47] <= 96'h000000000001ffffffffffff;
      tkeep[46] <= 96'h000000000003ffffffffffff;
      tkeep[45] <= 96'h000000000007ffffffffffff;
      tkeep[44] <= 96'h00000000000fffffffffffff;
      tkeep[43] <= 96'h00000000001fffffffffffff;
      tkeep[42] <= 96'h00000000003fffffffffffff;
      tkeep[41] <= 96'h00000000007fffffffffffff;
      tkeep[40] <= 96'h0000000000ffffffffffffff;
      tkeep[39] <= 96'h0000000001ffffffffffffff;
      tkeep[38] <= 96'h0000000003ffffffffffffff;
      tkeep[37] <= 96'h0000000007ffffffffffffff;
      tkeep[36] <= 96'h000000000fffffffffffffff;
      tkeep[35] <= 96'h000000001fffffffffffffff;
      tkeep[34] <= 96'h000000003fffffffffffffff;
      tkeep[33] <= 96'h000000007fffffffffffffff;
      tkeep[32] <= 96'h00000000ffffffffffffffff;
      tkeep[31] <= 96'h00000001ffffffffffffffff;
      tkeep[30] <= 96'h00000003ffffffffffffffff;
      tkeep[29] <= 96'h00000007ffffffffffffffff;
      tkeep[28] <= 96'h0000000fffffffffffffffff;
      tkeep[27] <= 96'h0000001fffffffffffffffff;
      tkeep[26] <= 96'h0000003fffffffffffffffff;
      tkeep[25] <= 96'h0000007fffffffffffffffff;
      tkeep[24] <= 96'h000000ffffffffffffffffff;
      tkeep[23] <= 96'h000001ffffffffffffffffff;
      tkeep[22] <= 96'h000003ffffffffffffffffff;
      tkeep[21] <= 96'h000007ffffffffffffffffff;
      tkeep[20] <= 96'h00000fffffffffffffffffff;
      tkeep[19] <= 96'h00001fffffffffffffffffff;
      tkeep[18] <= 96'h00003fffffffffffffffffff;
      tkeep[17] <= 96'h00007fffffffffffffffffff;
      tkeep[16] <= 96'h0000ffffffffffffffffffff;
      tkeep[15] <= 96'h0001ffffffffffffffffffff;
      tkeep[14] <= 96'h0003ffffffffffffffffffff;
      tkeep[13] <= 96'h0007ffffffffffffffffffff;
      tkeep[12] <= 96'h000fffffffffffffffffffff;
      tkeep[11] <= 96'h001fffffffffffffffffffff;
      tkeep[10] <= 96'h003fffffffffffffffffffff;
      tkeep[9]  <= 96'h007fffffffffffffffffffff;
      tkeep[8]  <= 96'h00ffffffffffffffffffffff;
      tkeep[7]  <= 96'h01ffffffffffffffffffffff;
      tkeep[6]  <= 96'h03ffffffffffffffffffffff;
      tkeep[5]  <= 96'h07ffffffffffffffffffffff;
      tkeep[4]  <= 96'h0fffffffffffffffffffffff;
      tkeep[3]  <= 96'h1fffffffffffffffffffffff;
      tkeep[2]  <= 96'h3fffffffffffffffffffffff;
      tkeep[1]  <= 96'h7fffffffffffffffffffffff;
      tkeep[0]  <= 96'hffffffffffffffffffffffff;
    end //always
  end // if

  else
  begin
    always @ (posedge clk)
    begin
      tkeep[63] = 64'h0000000000000001;
      tkeep[62] = 64'h0000000000000003;
      tkeep[61] = 64'h0000000000000007;
      tkeep[60] = 64'h000000000000000f;
      tkeep[59] = 64'h000000000000001f;
      tkeep[58] = 64'h000000000000003f;
      tkeep[57] = 64'h000000000000007f;
      tkeep[56] = 64'h00000000000000ff;
      tkeep[55] = 64'h00000000000001ff;
      tkeep[54] = 64'h00000000000003ff;
      tkeep[53] = 64'h00000000000007ff;
      tkeep[52] = 64'h0000000000000fff;
      tkeep[51] = 64'h0000000000001fff;
      tkeep[50] = 64'h0000000000003fff;
      tkeep[49] = 64'h0000000000007fff;
      tkeep[48] = 64'h000000000000ffff;
      tkeep[47] = 64'h000000000001ffff;
      tkeep[46] = 64'h000000000003ffff;
      tkeep[45] = 64'h000000000007ffff;
      tkeep[44] = 64'h00000000000fffff;
      tkeep[43] = 64'h00000000001fffff;
      tkeep[42] = 64'h00000000003fffff;
      tkeep[41] = 64'h00000000007fffff;
      tkeep[40] = 64'h0000000000ffffff;
      tkeep[39] = 64'h0000000001ffffff;
      tkeep[38] = 64'h0000000003ffffff;
      tkeep[37] = 64'h0000000007ffffff;
      tkeep[36] = 64'h000000000fffffff;
      tkeep[35] = 64'h000000001fffffff;
      tkeep[34] = 64'h000000003fffffff;
      tkeep[33] = 64'h000000007fffffff;
      tkeep[32] = 64'h00000000ffffffff;
      tkeep[31] = 64'h00000001ffffffff;
      tkeep[30] = 64'h00000003ffffffff;
      tkeep[29] = 64'h00000007ffffffff;
      tkeep[28] = 64'h0000000fffffffff;
      tkeep[27] = 64'h0000001fffffffff;
      tkeep[26] = 64'h0000003fffffffff;
      tkeep[25] = 64'h0000007fffffffff;
      tkeep[24] = 64'h000000ffffffffff;
      tkeep[23] = 64'h000001ffffffffff;
      tkeep[22] = 64'h000003ffffffffff;
      tkeep[21] = 64'h000007ffffffffff;
      tkeep[20] = 64'h00000fffffffffff;
      tkeep[19] = 64'h00001fffffffffff;
      tkeep[18] = 64'h00003fffffffffff;
      tkeep[17] = 64'h00007fffffffffff;
      tkeep[16] = 64'h0000ffffffffffff;
      tkeep[15] = 64'h0001ffffffffffff;
      tkeep[14] = 64'h0003ffffffffffff;
      tkeep[13] = 64'h0007ffffffffffff;
      tkeep[12] = 64'h000fffffffffffff;
      tkeep[11] = 64'h001fffffffffffff;
      tkeep[10] = 64'h003fffffffffffff;
      tkeep[9] = 64'h007fffffffffffff;
      tkeep[8] = 64'h00ffffffffffffff;
      tkeep[7] = 64'h01ffffffffffffff;
      tkeep[6] = 64'h03ffffffffffffff;
      tkeep[5] = 64'h07ffffffffffffff;
      tkeep[4] = 64'h0fffffffffffffff;
      tkeep[3] = 64'h1fffffffffffffff;
      tkeep[2] = 64'h3fffffffffffffff;
      tkeep[1] = 64'h7fffffffffffffff;
      tkeep[0] = 64'hffffffffffffffff;
    end
  end

  endgenerate //tkeep
endmodule


/*
//Helper code to generate tkeep
module print_it();
  logic [63:0] tkeep [511:0];
  logic [63:0] vary;
  
  initial
    begin
    vary = 64'h1;  
      
      for(int i=0; i<64; i++)
        begin
          $display("tkeep[%0d] = 64'h%h;", 63-i, vary);
          vary = vary | (vary<<1);
        end
    end
  
endmodule
*/

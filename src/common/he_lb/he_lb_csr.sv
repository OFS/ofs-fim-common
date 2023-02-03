// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// -----------------------------------------------------------------------------
// Create Date  : Nov 2020
// Module Name  : he_lb_csr.sv
// Project      : OFS Rel1
// Description  : CSR Block for HE-Loopback
//                Implements 64-bits read/write port a CSR file capable of 
//                doing 32 and 64 bit rd/wr the register file.
// -----------------------------------------------------------------------------

module he_lb_csr #(
  parameter FEATURE_ID = 12'h0,
  parameter AW = he_lb_pkg::CSR_AW,
  parameter DW = he_lb_pkg::CSR_DW,
  parameter CSR_TAG_W = he_lb_pkg::CSR_TAG_W,
  parameter CLK_MHZ = 0,
  parameter ATOMICS_SUPPORTED = ofs_plat_host_chan_pcie_tlp_pkg::ATOMICS_SUPPORTED,
  parameter HE_MEM = 0
)
(
  input  logic clk,               
  input  logic rst_n,

  // MMIO
  input  he_lb_pkg::he_csr_req  csr_req,
  output he_lb_pkg::he_csr_dout csr_dout,

  // Connections to exerciser engines
  output he_lb_pkg::he_csr2eng  csr2eng,
  input  he_lb_pkg::he_eng2csr  eng2csr
);

// --------------------------------------------------------------------------
// BBB Attributes
// --------------------------------------------------------------------------
localparam       END_OF_LIST           = 1'h1;  // Set this to 0 if there is another DFH beyond this
localparam       NEXT_DFH_BYTE_OFFSET  = 24'h0; // Next DFH Byte offset

//----------------------------------------------------------------------------
// CSR Attributes
//----------------------------------------------------------------------------
localparam        RO      = 3'h0;
localparam        RW      = 3'h1;
localparam        RsvdP   = 3'h6;
localparam        RsvdZ   = 3'h6;

//---------------------------------------------------------
// CSR Address Map ***** DO NOT MODIFY *****
//---------------------------------------------------------
localparam        CSR_AFH_DFH_BASE     = 16'h000;    // 64b       // RO - Start for the DFH info for this AFU
localparam        CSR_AFH_ID_L         = 16'h008;    // 64b       // RO - Lower 64 bits of the AFU ID
localparam        CSR_AFH_ID_H         = 16'h010;    // 64b       // RO - Upper 64 bits of the AFU ID
localparam        CSR_DFH_RSVD0        = 16'h018;    // 64b       // RO - Offset to next AFU
localparam        CSR_DFH_RSVD1        = 16'h020;    // 64b       // RO - Reserved space for DFH managment(?)

localparam        CSR_SCRATCHPAD0      = 16'h100;    // 32b
localparam        CSR_SCRATCHPAD1      = 16'h104;    // 32b
localparam        CSR_SCRATCHPAD2      = 16'h108;    // 64b

localparam        CSR_AFU_DSM_BASEL    = 16'h110;    // 32b       // RW - Lower 32-bits of AFU DSM base address. The lower 6-bbits are 4x00 since the address is cache aligned.
localparam        CSR_AFU_DSM_BASEH    = 16'h114;    // 32b       // RW - Upper 32-bits of AFU DSM base address.

localparam        CSR_SRC_ADDR         = 16'h120;    // 64b       // RW   Reads are targetted to this region 
localparam        CSR_DST_ADDR         = 16'h128;    // 64b       // RW   Writes are targetted to this region
localparam        CSR_NUM_LINES        = 16'h130;    // 32b       // RW   Numbers of cache lines to be read/write
localparam        CSR_CTL              = 16'h138;    // 32b       // RW   Control CSR to start n stop the test
localparam        CSR_CFG              = 16'h140;    // 32b       // RW   Configures test mode, wrthru, cont and delay mode
localparam        CSR_INACT_THRESH     = 16'h148;    // 32b       // RW   set the threshold limit for inactivity trigger
localparam        CSR_INTERRUPT0       = 16'h150;    // 32b       // RW   set the threshold limit for inactivity trigger

localparam        CSR_SWTEST_MSG       = 16'h158;    // 32b       // RW   Write to this serves as a notification to SW test   
localparam        CSR_STATUS0          = 16'h160;    // 32b       // RO   num_read, num_writes
localparam        CSR_STATUS1          = 16'h168;    // 32b       // RO   num_Rdpend, num_Wrpend 
localparam        CSR_ERROR            = 16'h170;    // 32b       // RO   error
localparam        CSR_STRIDE           = 16'h178;    // 32b       // RW   stride value
localparam        CSR_INFO0            = 16'h180;    // 64b       // RO   Test info (e.g. clock frequency)
//---------------------------------------------------------

localparam        NO_STAGED_CSR        = 16'hXXX;       // used for NON late action CSRs
localparam        CFG_SEG_SIZE         = 16'h188>>3;    // Range specified in number of 8B CSRs
localparam [15:0] CFG_SEG_BEG          = 16'h0000;
localparam        CFG_SEG_END          = CFG_SEG_BEG+(CFG_SEG_SIZE<<3);
localparam        L_CFG_SEG_SIZE       = ($clog2(CFG_SEG_SIZE) == 0) ? 1 : $clog2(CFG_SEG_SIZE);

localparam        FEATURE_0_BEG        = 18'h0000;
//localparam      FEATURE_1_BEG        = 18'h1000;

// WARNING: The next localparam must match what is currently in the
//          requestor.v file.  This should be moved to a global package/file
//          that can be used, rather than in two files.  Future Work.  PKB
// PAR Mode
// Each Test implements a different functionality
// Therefore it should really be treated like a different AFU
// For ease of maintainability they are implemented in a single source tree
// At compile time, user can decide which test mode is synthesized.

localparam NLB_AFU_ID_H = (HE_MEM == 1) ? 64'h8568_ab4e_6ba5_4616 : 64'h56e2_03e9_864f_49a7;
localparam NLB_AFU_ID_L = (HE_MEM == 1) ? 64'hbb65_2a57_8330_a8eb : 64'hb94b_1228_4c31_e02b;

localparam HE_LB_API_VERSION = 1;

//`ifndef SIM_MODE // PAR_MODE
//  `ifdef NLB400_MODE_0
//    localparam NLB_AFU_ID_H    = 64'hD842_4DC4_A4A3_C413;
//    localparam NLB_AFU_ID_L    = 64'hF89E_4336_83F9_040B;
//            
//  `elsif NLB400_MODE_3
//    localparam NLB_AFU_ID_H    = 64'hF7DF_405C_BD7A_CF72;
//    localparam NLB_AFU_ID_L    = 64'h22F1_44B0_B93A_CD18;
//  `elsif NLB400_MODE_7
//    localparam NLB_AFU_ID_H    = 64'h7BAF_4DEA_A57C_E91E;
//    localparam NLB_AFU_ID_L    = 64'h168A_455D_9BDA_88A3;
//  `elsif NLB400_MODE_5
//    localparam NLB_AFU_ID_H    = 64'hA0B8_4916_A8A2_12A1;
//    localparam NLB_AFU_ID_L    = 64'hA2EC_457C_84E7_47BC;
//  `else
//      ** Select a valid NLB Test Mode
//  `endif	
//`else   // SIM_MODE
//  // Temporary Workaround
//  // Simulation tests are always expecting same AFU ID
//  // ** To be Fixed **
//  localparam NLB_AFU_ID_H      = 64'hC000_C966_0D82_4272;
//  localparam NLB_AFU_ID_L      = 64'h9AEF_FE5F_8457_0612;
//`endif

//----------------------------------------------------------------------------------------------------------------------------------------------
logic                 rst_n_q, rst_n_qq;
logic [63:0]          csr_reg [2**L_CFG_SEG_SIZE-1:0];            // register file
logic                 ip_select;
logic [15:0]          afu_csr_addr_4B;
logic [14:0]          afu_csr_addr_8B;
logic                 afu_csr_length;
logic                 afu_csr_length_4B_T1; 
logic                 afu_csr_length_4B_T2;
logic                 afu_csr_length_8B_T1;
logic                 afu_csr_length_8B_T2;
logic                 afu_csr_length_8B_T3;
logic [DW-1:0]        afu_csr_wrdin_T1;
logic [DW-1:0]        afu_csr_dout_T3;
logic [DW-1:0]        afu_csr_dout_T2 [1:0];
logic [1:0]           afu_csr_dw_enable_T1;
logic [1:0]           afu_csr_dw_enable_T2;
logic [1:0]           afu_csr_dw_enable_T3;
logic                 afu_csr_wren_T1; 
logic                 afu_csr_rden_T1;
logic                 afu_csr_out_of_range_T1;
logic                 afu_csr_dout_v_T2; 
logic                 afu_csr_dout_v_T3;
logic [CSR_TAG_W-1:0] afu_csr_tag_T1;
logic [CSR_TAG_W-1:0] afu_csr_tag_T2;
logic [CSR_TAG_W-1:0] afu_csr_tag_T3;
logic [AW-1:0]        afu_csr_addr_T1;
logic [AW-1:0]        afu_csr_addr_T2;
logic [AW-1:0]        afu_csr_addr_T3;
logic                 range_valid;
logic [14:0]          feature_0_addr_offset_8B_T1;
//logic [14:0]         feature_1_addr_offset_8B_T1;
logic [1:0]           feature_id_T2;
logic                 wrlock_n;

(* maxfan=1 *)  logic [14:0] afu_csr_addr_8B_T1;

integer i;

//RME - Commenting Power-up values, helps with timing.
initial 
begin
  for (i=0;i<2**L_CFG_SEG_SIZE;i=i+1)
  begin
    csr_reg[i] = 64'h0;
  end
end

always_ff @ (posedge clk)
begin
  rst_n_q  <= rst_n;
  rst_n_qq <= rst_n_q;
end

//Output CSR Values
always_ff @ (posedge clk)
begin
  csr2eng.ctl             <= func_csr_connect_4B(CSR_CTL,csr_reg[CSR_CTL>>3]);
  csr2eng.stride          <= func_csr_connect_4B(CSR_STRIDE,csr_reg[CSR_STRIDE>>3]);
  csr2eng.dsm_base[31:0]  <= func_csr_connect_4B(CSR_AFU_DSM_BASEL,csr_reg[CSR_AFU_DSM_BASEL>>3]);
  csr2eng.dsm_base[63:32] <= func_csr_connect_4B(CSR_AFU_DSM_BASEH,csr_reg[CSR_AFU_DSM_BASEH>>3]);
  csr2eng.src_address     <= csr_reg[CSR_SRC_ADDR>>3];
  csr2eng.dst_address     <= csr_reg[CSR_DST_ADDR>>3];
  csr2eng.num_lines       <= func_csr_connect_4B(CSR_NUM_LINES, csr_reg[CSR_NUM_LINES>>3]);
  csr2eng.inact_thresh    <= func_csr_connect_4B(CSR_INACT_THRESH,csr_reg[CSR_INACT_THRESH>>3]);
  csr2eng.cfg             <= csr_reg[CSR_CFG>>3];
  csr2eng.interrupt0      <= func_csr_connect_4B(CSR_INTERRUPT0, csr_reg[CSR_INTERRUPT0>>3]);
end

//                                    [14:9]              , [8:0]
assign feature_0_addr_offset_8B_T1 = {FEATURE_0_BEG[17:12], 3'h0, afu_csr_addr_8B_T1[5:0]};
//assign feature_1_addr_offset_8B_T1 = {FEATURE_1_BEG[17:12], afu_csr_addr_8B_T1[8:0]};
assign afu_csr_addr_4B = csr_req.addr;
assign afu_csr_addr_8B = afu_csr_addr_4B[15:1];
assign afu_csr_length  = csr_req.len;
assign ip_select       = (afu_csr_addr_8B[14:L_CFG_SEG_SIZE+2] == CFG_SEG_BEG[15:L_CFG_SEG_SIZE+3]);


always_ff @(posedge clk)
begin
  // -Stage T1-
  afu_csr_tag_T1     <= csr_req.tag;
  afu_csr_addr_T1    <= csr_req.addr;
  afu_csr_addr_8B_T1 <= afu_csr_addr_8B;

  if (csr_req.wen | csr_req.ren)
  begin
    afu_csr_length_4B_T1 <= afu_csr_length==1'b0;
    afu_csr_length_8B_T1 <= afu_csr_length==1'b1;
  end
  
  // DW enable is used when doing a 4B write
  case ({afu_csr_length, afu_csr_addr_4B[0]})
    
    2'b00: 
    begin 
      afu_csr_dw_enable_T1 <= 2'b01;
      afu_csr_wrdin_T1     <= csr_req.din;
    end
    
    2'b01: 
    begin 
      afu_csr_dw_enable_T1 <= 2'b10;
      afu_csr_wrdin_T1     <= {csr_req.din[31:0], csr_req.din[31:0]};
    end
    
    default:
    begin 
      afu_csr_dw_enable_T1 <= 2'b11;
      afu_csr_wrdin_T1     <= csr_req.din;
    end

  endcase

  afu_csr_rden_T1         <= csr_req.ren;

  if(ip_select)
  begin
    afu_csr_wren_T1 <= csr_req.wen;
    afu_csr_out_of_range_T1 <= 1'b0;
  end
  else
  begin
    afu_csr_wren_T1         <= 1'b0;
    afu_csr_out_of_range_T1 <= csr_req.ren;
  end

  // -Stage T2-
  afu_csr_tag_T2       <= afu_csr_tag_T1;
  afu_csr_addr_T2      <= afu_csr_addr_T1;
  afu_csr_length_4B_T2 <= afu_csr_length_4B_T1;
  afu_csr_length_8B_T2 <= afu_csr_length_8B_T1;
  afu_csr_dw_enable_T2 <= afu_csr_dw_enable_T1;
  afu_csr_dout_v_T2    <= afu_csr_rden_T1;

  // Read Feature 0 + addr offset
  afu_csr_dout_T2[0] <= afu_csr_out_of_range_T1 ? '0 : csr_reg[feature_0_addr_offset_8B_T1];
  // Read Feature 1 + addr offset
  //afu_csr_dout_T2[1] <= csr_reg[feature_1_addr_offset_8B_T1];

  feature_id_T2 <= afu_csr_addr_8B_T1[10:9];

  // -Stage T3-
  afu_csr_tag_T3       <= afu_csr_tag_T2;
  afu_csr_addr_T3      <= afu_csr_addr_T2;
  afu_csr_length_8B_T3 <= afu_csr_length_8B_T2;
  afu_csr_dw_enable_T3 <= afu_csr_dw_enable_T2;
  afu_csr_dout_v_T3    <= afu_csr_dout_v_T2;

  case(feature_id_T2)
    2'h0: 
    begin
      afu_csr_dout_T3 <= afu_csr_dout_T2[0];
    end
    //2'h1: 
    //begin
    //  afu_csr_dout_T3 <= afu_csr_dout_T2[1];
    //end
    default: 
    begin
      afu_csr_dout_T3 <= afu_csr_dout_T2[0];
    end
    
  endcase

  // -Stage T4-
  case(afu_csr_dw_enable_T3)
    2'b10:  csr_dout.data <= afu_csr_dout_T3[63:32];
    default:csr_dout.data <= afu_csr_dout_T3;
  endcase

  csr_dout.valid  <= afu_csr_dout_v_T3;
  csr_dout.tag    <= afu_csr_tag_T3;
  csr_dout.addr   <= afu_csr_addr_T3;
  csr_dout.len    <= (afu_csr_length_8B_T3) ? 1'b1 : 1'b0; // 8B or 4B      

  wrlock_n <= csr2eng.ctl[0] & !csr2eng.ctl[1];

  if(!rst_n_qq)
  begin
    csr_dout.valid       <= 1'b0;
  end

  // AFH DFH Declarations:
  // The AFU-DFH must have the following mapping
  //      [63:60] Feature Type - 4'b0011
  //      [59:52] Rsvd
  //      [51:48] 4b User defined AFU mimor version # (else rsvd)
  //      [47:41] Rsvd
  //      [40]    End of DFH List
  //      [39:16] Next DFH Byte Offset (24'h0 because no other DFHs)
  //      [15:12] 4b User defined AFU major version # 
  //      [11:0]  Feature ID
  set_attr(CSR_AFH_DFH_BASE,
           NO_STAGED_CSR,
           1'b1,
           {64{RO}},
           {4'b0001,             // Type=AFU
            8'h0,                // Reserved 
            4'h0,                // AFU minor version #
            7'h0,                // Reserved
            END_OF_LIST,
            NEXT_DFH_BYTE_OFFSET, 
            4'h0,                // AFU major version #
            FEATURE_ID});        // Feature ID

  // The AFU ID
  set_attr(CSR_AFH_ID_L,
           NO_STAGED_CSR,
           1'b1,
           {64{RO}},
           NLB_AFU_ID_L);

  set_attr(CSR_AFH_ID_H,
           NO_STAGED_CSR,
           1'b1,
           {64{RO}},
           NLB_AFU_ID_H);
                          
  
  set_attr(CSR_DFH_RSVD0,
           NO_STAGED_CSR,
           1'b1,
           {64{RsvdP}},
           64'h0);

  // And set the Reserved AFU DFH 0x020 block to Reserved
  set_attr(CSR_DFH_RSVD1,
           NO_STAGED_CSR,
           1'b1,
           {64{RsvdP}},
           64'h0);

  // CSR Declarations
  // These are the parts of the CSR Register that are unique
  // for the NLB AFU.  They are not required for the FIU.
  // The are used by the SW that accesses this AFU.
  set_attr(CSR_SCRATCHPAD0,          // + CSR_SCRATCHPAD1
           NO_STAGED_CSR,
           1'b1,
           {64{RW}},
           64'h0
          );

  set_attr(CSR_SCRATCHPAD2,
           NO_STAGED_CSR,
           1'b1,
           {64{RW}},
           64'h0
          );


  set_attr(CSR_AFU_DSM_BASEL,        // + CSR_AFU_DSM_BASEH
           NO_STAGED_CSR,
           1'b1,
           {64{RW}},
           64'h0
          );


  set_attr(CSR_SRC_ADDR,
           NO_STAGED_CSR,
           wrlock_n,
           {64{RW}},
           64'h0
          );

  set_attr(CSR_DST_ADDR,
           NO_STAGED_CSR,
           wrlock_n,
           {64{RW}},
           64'h0
          );

  set_attr(CSR_NUM_LINES,
           NO_STAGED_CSR,
           1'b1,
           {
            {44{RsvdP}},
            {20{RW}}
           },
           64'h0
          );

  set_attr(CSR_CTL,
           NO_STAGED_CSR,
           1'b1,
           {{32{RW}},
            {16{RsvdP}},
            {16{RW}}
           },
           64'h0
          );
  
  set_attr(CSR_STRIDE,
           NO_STAGED_CSR,
           1'b1,
           {{58{RsvdP}},
            {6{RW}}
           },
           64'h0
          );

  set_attr(CSR_CFG,
           NO_STAGED_CSR,
           wrlock_n,
           {64{RW}},
           64'h0
          );

  set_attr(CSR_INACT_THRESH,
           NO_STAGED_CSR,
           wrlock_n,
           {64{RW}},
           64'h0
          );

  set_attr(CSR_INTERRUPT0,
           NO_STAGED_CSR,
           wrlock_n,
           {{16{RW}},
            {16{RW}}
           },
           64'h0
          );

  set_attr(CSR_SWTEST_MSG,
           NO_STAGED_CSR,
           1'b1,
           {64{RW}},
           64'h0
          );

  set_attr(CSR_STATUS0,
           NO_STAGED_CSR,
           1'b1,
           {64{RO}},
           {eng2csr.num_reads[31:0], eng2csr.num_writes[31:0]}
          );

  set_attr(CSR_STATUS1,
           NO_STAGED_CSR,
           1'b1,
           {64{RO}},
           {eng2csr.num_emif_rdpend, eng2csr.num_emif_wrpend,
            eng2csr.num_host_rdpend, eng2csr.num_host_wrpend}
          );

  set_attr(CSR_ERROR,
           NO_STAGED_CSR,
           1'b1,
           {64{RO}},
           {32'h0, eng2csr.error}
          );
         
  set_attr(CSR_INFO0,
           NO_STAGED_CSR,
           1'b1,
           {64{RO}},
           {39'h0,
            ~1'(ATOMICS_SUPPORTED), // Set when atomic operations are NOT supported
            8'(HE_LB_API_VERSION),
            16'(CLK_MHZ)}
          );

end


//----------------------------------------------------------------------------------------------------------------------------------------------
task automatic set_attr; 
  input  [15:0]       csr_id;                           // byte aligned CSR address
  input  [15:0]       staged_csr_id;                    // byte aligned CSR address for late action staged register
  input               conditional_wr;                   // write condition for RW, RWS, RWDL attributes
  input  [3*64-1:0]   attr;                             // Attribute for each bit in the CSR
  input  [63:0]       default_val;                      // Initial value on Reset
  reg    [12:0]       csr_offset_8B;
  reg    [12:0]       staged_csr_offset_8B;
  reg    [1:0]        this_write;
  integer i,j;
  
  csr_offset_8B = csr_id[3+:L_CFG_SEG_SIZE];
  staged_csr_offset_8B = staged_csr_id[3+:L_CFG_SEG_SIZE];
  this_write[0] = afu_csr_wren_T1 && (csr_offset_8B==afu_csr_addr_8B_T1) && conditional_wr && afu_csr_dw_enable_T1[0];
  this_write[1] = afu_csr_wren_T1 && (csr_offset_8B==afu_csr_addr_8B_T1) && conditional_wr && afu_csr_dw_enable_T1[1];

  for(i=0; i<64; i=i+1)
  begin: atr
    if(i>31)
        j = 1'b1;
    else
        j = 1'b0;

    casex ({attr[i*3+:3]})
      RW: 
      begin                                                   // - Read Write
        if(!rst_n_qq)
          csr_reg[csr_offset_8B][i]   <= default_val[i];
        else if(this_write[j])
        begin
          csr_reg[csr_offset_8B][i]   <= afu_csr_wrdin_T1[i];
        end
      end

      RO: 
      begin                                                   // - Read Only
        csr_reg[csr_offset_8B][i]     <= default_val[i];        // update status
      end

      /*RsvdZ*/ RsvdP: 
      begin                                     // - Software must preserve these bits
        csr_reg[csr_offset_8B][i]     <= default_val[i];    // set default value
      end

    endcase 
  end //for
endtask


// ---------------------------------------------------------------------------
// func_csr_connect_4B
// Provides either lower DW or upper DW
// Used to access 32b CSRs
// ---------------------------------------------------------------------------
function automatic [31:0] func_csr_connect_4B;
  input [15:0]    address;
  input [63:0]    data_8B;
  
  //Address is always DW aligned. so [1:0] = 2'b00 always
  //Address[2] determines which DW (lower or upper) 

  if(address[2])
    func_csr_connect_4B = data_8B[63:32];
  else
    func_csr_connect_4B = data_8B[31:0];
endfunction


endmodule


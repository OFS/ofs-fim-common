// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
// Description
//-----------------------------------------------------------------------------
//
// Ethernet Traffic AFU CSR. The exposed read/write CSR interface is
// independent of the host channel interface -- reduced to read and write
// commands along with an address and data.
//
//-----------------------------------------------------------------------------

module eth_traffic_csr #(
   parameter AFU_CSR_ADDR_WIDTH = 16, // CSR address space width bytes-level
   parameter AVMM_DATA_W        = 32, // Data width
   parameter AVMM_ADDR_W        = 16  // AVMM address width
)(
   input  logic                          clk,
   input  logic                          rst,

   // CSR read/write commands. Only one of read and write will be set.
   input  logic                          i_cmd_csr_rd,
   input  logic                          i_cmd_csr_wr,
   // Byte-level address
   input  logic [AFU_CSR_ADDR_WIDTH-1:0] i_cmd_csr_addr,
   // 32 or 64 bit write
   input  ofs_csr_pkg::csr_access_type_t              i_cmd_csr_wr_type,
   input  logic [63:0]                   i_csr_wr_data,
   // Combinational response expected (same cycle as i_cmd_csr_rd)
   output logic [63:0]                   o_csr_rd_data,

   // Avalon-MM Interface
   output logic [AVMM_ADDR_W-1:0]        o_avmm_addr,        // AVMM address
   output logic                          o_avmm_read,        // AVMM read request
   output logic                          o_avmm_write,       // AVMM write request
   output logic [AVMM_DATA_W-1:0]        o_avmm_writedata,   // AVMM write data
   input  logic [AVMM_DATA_W-1:0]        i_avmm_readdata,    // AVMM read data
   input  logic                          i_avmm_waitrequest, // AVMM wait request
   // Port selection for CSR interface
   output logic [3:0]                    o_csr_port_sel,
   // Enable for crossbar: Tx port swapping between first and second half ports
   output logic                          o_port_swap_en
);

import ofs_csr_pkg::*;
import eth_traffic_csr_pkg::*;
//----------------------------------------------------------------------------
// Local parameters.
//----------------------------------------------------------------------------
localparam   AFU_CSR_DEPTH = 32;       // Number of CSRs
localparam   CSR_NUM_REG = 11 ;

//---------------------------------------------------------------------------------
// Here is a list of the register bit attributes for each of the CSRs.  The effect
// these attributes have on the individual register bits is defined in the 
// function "update_reg" in package "ofs_csr_pkg.sv".
//
// The attributes and their effects are listed here for reference:
//
//     typedef enum logic [3:0] {
//        RO    = 4'h0, // Read-Only
//        RW    = 4'h1, // Read-Write
//        RWS   = 4'h2, // Read-Write Sticky Across Soft Reset
//        RWD   = 4'h3, // Read-Write Sticky Across Hard Reset
//        RW1C  = 4'h4, // Read-Write 1 to Clear
//        RW1CS = 4'h5, // Read-Write 1 to Clear Sticky Across Soft Reset
//        RW1CD = 4'h6, // Read-Write 1 to Clear Sticky Across Hard Reset
//        RW1S  = 4'h7, // Read-Write 1 to Set
//        RW1SS = 4'h8, // Read-Write 1 to Set Sticky Across Soft Reset
//        RW1SD = 4'h9, // Read-Write 1 to Set Sticky Across Hard Reset
//        Rsvd  = 4'hA, // Reserved - Don't Care
//        RsvdP = 4'hB, // Reserved and Protected (SW read-modify-write)
//        RsvdZ = 4'hC   // Reserved and Zero
//     } csr_bit_attr_t;
//
//---------------------------------------------------------------------------------
csr_bit_attr_t [63:0] CSR_AFU_DFH_ATTR           = { {4{RO}},{19{RsvdZ}},{41{RO}} };
csr_bit_attr_t [63:0] CSR_AFU_ID_L_ATTR          = { 64{RO} };
csr_bit_attr_t [63:0] CSR_AFU_ID_H_ATTR          = { 64{RO} };
csr_bit_attr_t [63:0] CSR_AFU_INIT_ATTR          = { {62{RsvdZ}},{1{RO}},{1{RW}} };
csr_bit_attr_t [63:0] CSR_TRAFFIC_CTRL_CMD_ATTR  = { {16{RsvdZ}},{16{RW}},{29{RsvdZ}},{1{RO}},{2{RW}} };
csr_bit_attr_t [63:0] CSR_TRAFFIC_CTRL_DATA_ATTR = { {32{RW}},{32{RO}} };
csr_bit_attr_t [63:0] CSR_TRAFFIC_CTRL_PORT_ATTR = { {60{RsvdZ}},{4{RW}} };
csr_bit_attr_t [63:0] CSR_AFU_SCRATCH_ATTR       = { 64{RW} };
csr_bit_attr_t [63:0] CSR_PORT_SWAP_EN_ATTR      = { {63{RsvdZ}},{1{RW}} };


//------------------------------------------------------------------------------
// Ethernet traffic AFU CSR Structures are used to make register assignments and
// breakouts easier to understand.These definitions may be found in the package:
//     eth_traffic_csr_pkg.sv
//
// These are essentially overlays on the register array to map their
// respective bit fields.
//------------------------------------------------------------------------------
//  Assignment/Update Overlays:
//     These structure overlays help map out the fields for the status register 
//     "update" inputs used by the function "update_reg" to determine the 
//     next values stored in the AFU status CSRs.
//------------------------------------------------------------------------------
afu_csr_dfh_t                        afu_csr_dfh_update;
afu_csr_afu_id_l_t                   afu_csr_afu_id_l_update;
afu_csr_afu_id_h_t                   afu_csr_afu_id_h_update;
afu_csr_afu_init_t                   afu_csr_afu_init_update;
afu_csr_afu_traffic_ctrl_cmd_t       afu_csr_afu_traffic_ctrl_cmd_reset,afu_csr_afu_traffic_ctrl_cmd_update;
afu_csr_afu_traffic_ctrl_data_t      afu_csr_afu_traffic_ctrl_data_reset,afu_csr_afu_traffic_ctrl_data_update;
afu_csr_afu_traffic_ctrl_port_t      afu_csr_afu_traffic_ctrl_port_update;
ofs_csr_reg_generic_t                afu_csr_afu_scratchpad_reset,afu_csr_afu_scratchpad_update;
afu_csr_port_swap_en_t               afu_csr_port_swap_en_update;


// ----------- Parameters -------------
localparam   END_OF_LIST           = 1'h1;  // Set this to 0 if there is another DFH beyond this
localparam   NEXT_DFH_BYTE_OFFSET  = 24'h0; // Next DFH Byte offset
`ifndef ETH_100G
localparam   AFU_ID_H              = 64'h823c334c98bf11ea;
localparam   AFU_ID_L              = 64'hbb370242ac130002;
`else 
localparam   AFU_ID_H              = 64'h43425ee692b24742; 
localparam   AFU_ID_L              = 64'hb03abd8d4a533812;
`endif
localparam   CSR_ADDR_SHIFT        = 3;
localparam [23:0] GBS_ID  = "E2E";
localparam [7:0]  GBS_VER = 8'h11;

// ---- Logic / Struct Declarations ---
logic [CSR_REG_WIDTH-1:0] csr_reg [AFU_CSR_DEPTH-1:0];
logic csr_write[AFU_CSR_DEPTH-1:0]; // Register Write Strobes - Arrayed like the CSR registers.
ofs_csr_hw_state_t hw_state; // Hardware state during CSR updates.   This simplifies the CSR Register Update function call.

logic [31:0]      scratch = {GBS_ID, GBS_VER};

logic [1:0]             s_traffic_ctrl_cmd;
logic [AVMM_ADDR_W-1:0] s_traffic_ctrl_addr;
logic [AVMM_DATA_W-1:0] s_traffic_ctrl_writedata;
logic [AVMM_DATA_W-1:0] s_traffic_ctrl_readdata;
logic                   s_traffic_ctrl_ack;
logic                  range_valid;

assign o_csr_port_sel  = csr_reg[CSR_TRAFFIC_CTRL_PORT >> CSR_ADDR_SHIFT][3:0];
assign o_port_swap_en  = csr_reg[CSR_PORT_SWAP_EN >> CSR_ADDR_SHIFT][0];

// Read response (data)

// CSR address range check 

assign range_valid = (i_cmd_csr_addr[AFU_CSR_ADDR_WIDTH-1:3] < CSR_NUM_REG) ? 1'b1 : 1'b0; 
assign o_csr_rd_data = range_valid ? csr_reg[i_cmd_csr_addr >> CSR_ADDR_SHIFT] : 64'b0 ;

// Write strobe generation for csr update
always_comb begin
   for (int csr_addr=0; csr_addr < AFU_CSR_DEPTH; csr_addr++) begin
      if (i_cmd_csr_wr && ((i_cmd_csr_addr >> CSR_ADDR_SHIFT) == csr_addr)) begin
         csr_write[csr_addr] = 1'b1;
      end else begin
         csr_write[csr_addr] = 1'b0;        
      end
   end
end

//----------------------------------------------------------------------------
// HW State is a data struct used to pass the resets, write data, and write
// type to the CSR "update_reg" function.
//----------------------------------------------------------------------------
assign hw_state.reset_n      = ~rst;
assign hw_state.pwr_good_n   = 1'b0;
assign hw_state.wr_data.data = i_csr_wr_data;
assign hw_state.write_type   = i_cmd_csr_wr_type;


//----------------------------------------------------------------------------
// Register Reset/Update Structure Overlays.
//----------------------------------------------------------------------------
// AFU DFH--------------------------------------------------------------------
assign afu_csr_dfh_update.afu_dfh.feature_type    = 4'h1;
assign afu_csr_dfh_update.afu_dfh.reserved1       = {8{1'b0}};
assign afu_csr_dfh_update.afu_dfh.afu_min_version = 3'h0;
assign afu_csr_dfh_update.afu_dfh.reserved0       = {7{1'b0}};
assign afu_csr_dfh_update.afu_dfh.end_of_list     = END_OF_LIST;
assign afu_csr_dfh_update.afu_dfh.next_dfh_offset = NEXT_DFH_BYTE_OFFSET;
`ifndef OSC_CFGA
assign afu_csr_dfh_update.afu_dfh.afu_maj_version = 4'h1;
`else
assign afu_csr_dfh_update.afu_dfh.afu_maj_version = 4'h2;
`endif 
assign afu_csr_dfh_update.afu_dfh.feature_id      = 12'b0;
// AFU ID--------------------------------------------------------------------
assign afu_csr_afu_id_l_update.data               = AFU_ID_L;
assign afu_csr_afu_id_h_update.data               = AFU_ID_H;
// AFU INIT--------------------------------------------------------------------
assign afu_csr_afu_init_update.data               = 64'h0000_0000_0000_0000;
// AFU Traffic Controller Command Register-------------------------------------
assign afu_csr_afu_traffic_ctrl_cmd_reset.data                             = 64'h0000_0000_0000_0000;
assign afu_csr_afu_traffic_ctrl_cmd_update.afu_traffic_ctrl_cmd.reserved1  = 16'h0000;
assign afu_csr_afu_traffic_ctrl_cmd_update.afu_traffic_ctrl_cmd.addr       = 16'h0000;
assign afu_csr_afu_traffic_ctrl_cmd_update.afu_traffic_ctrl_cmd.reserved0  = 16'h0000;
assign afu_csr_afu_traffic_ctrl_cmd_update.afu_traffic_ctrl_cmd.ack_trans  = s_traffic_ctrl_ack;
assign afu_csr_afu_traffic_ctrl_cmd_update.afu_traffic_ctrl_cmd.wr_cmd     = 1'b0;
assign afu_csr_afu_traffic_ctrl_cmd_update.afu_traffic_ctrl_cmd.rd_cmd     = 1'b0;
// AFU Traffic Controller Data Register-------------------------------------
assign afu_csr_afu_traffic_ctrl_data_reset.data                            = 64'h0000_0000_0000_0000;
assign afu_csr_afu_traffic_ctrl_data_update.afu_traffic_ctrl_data.wr_data  = 32'h0000_0000;
assign afu_csr_afu_traffic_ctrl_data_update.afu_traffic_ctrl_data.rd_data  = s_traffic_ctrl_readdata;
// AFU Traffic Controller Port Select Register-------------------------------------
assign afu_csr_afu_traffic_ctrl_port_update.data  = 64'h0000_0000_0000_0000;
// AFU Scratchpad Register---------------------------------------------------------
assign afu_csr_afu_scratchpad_reset.data         = {32'h0000_0000,scratch};
assign afu_csr_afu_scratchpad_update.data        = 64'h0000_0000_0000_0000;
// AFU Traffic Controller Port Swap Enable Register---------------------------------
assign afu_csr_port_swap_en_update.data  = 64'h0000_0000_0000_0000;


//----------------------------------------------------------------------------
// Register Update Logic using "update_reg" & "update_error_reg" functions in 
// the "ofs_csr_pkg.sv" SystemVerilog package.  Function inputs are "named" 
// for ease of understanding the use.
//    - Register bit attributes are set in array input above.  Attribute
//        functions are defined in SAS.
//    - Reset Value is appied at reset except for RO, *D, and Rsvd{Z}.
//    - Update Value is used as status bit updates for RO, RW1C*, and RW1S*.
//    - Current Value is used to determine next register value.  This must be
//        done due to scoping rules using SystemVerilog package.
//    - "Write" is the decoded write signal for that particular register.
//    - State is a hardware state structure to pass input signals to 
//        "update_reg" function.  See code above.
//----------------------------------------------------------------------------
always_ff @(posedge clk)
begin : update_reg_seq

   csr_reg[CSR_AFU_DFH>>CSR_ADDR_SHIFT]           <= update_reg(  .attr(CSR_AFU_DFH_ATTR),
                                                                  .reg_reset_val(afu_csr_dfh_update.data),
                                                                  .reg_update_val(afu_csr_dfh_update.data),
                                                                  .reg_current_val(csr_reg[CSR_AFU_DFH>>CSR_ADDR_SHIFT]),
                                                                  .write(csr_write[CSR_AFU_DFH>>CSR_ADDR_SHIFT]),
                                                                  .state(hw_state)
                                                               );
                                                               
   csr_reg[CSR_AFU_ID_L>>CSR_ADDR_SHIFT]          <= update_reg(  .attr(CSR_AFU_ID_L_ATTR),
                                                                  .reg_reset_val(afu_csr_afu_id_l_update.data),
                                                                  .reg_update_val(afu_csr_afu_id_l_update.data),
                                                                  .reg_current_val(csr_reg[CSR_AFU_ID_L>>CSR_ADDR_SHIFT]),
                                                                  .write(csr_write[CSR_AFU_ID_L>>CSR_ADDR_SHIFT]),
                                                                  .state(hw_state)
                                                               );

   csr_reg[CSR_AFU_ID_H>>CSR_ADDR_SHIFT]          <= update_reg(  .attr(CSR_AFU_ID_H_ATTR),
                                                                  .reg_reset_val(afu_csr_afu_id_h_update.data),
                                                                  .reg_update_val(afu_csr_afu_id_h_update.data),
                                                                  .reg_current_val(csr_reg[CSR_AFU_ID_H>>CSR_ADDR_SHIFT]),
                                                                  .write(csr_write[CSR_AFU_ID_H>>CSR_ADDR_SHIFT]),
                                                                  .state(hw_state)
                                                               );
   csr_reg['h0018>>CSR_ADDR_SHIFT]       <= 64'h0;

   csr_reg['h0020>>CSR_ADDR_SHIFT]       <= 64'h0;                                                                                                                                                                                                                                                       
   csr_reg['h0028>>CSR_ADDR_SHIFT]       <= 64'h0;      
   
   csr_reg[CSR_AFU_INIT>>CSR_ADDR_SHIFT]          <= update_reg(  .attr(CSR_AFU_INIT_ATTR),
                                                                  .reg_reset_val(afu_csr_afu_init_update.data),
                                                                  .reg_update_val(afu_csr_afu_init_update.data),
                                                                  .reg_current_val(csr_reg[CSR_AFU_INIT>>CSR_ADDR_SHIFT]),
                                                                  .write(csr_write[CSR_AFU_INIT>>CSR_ADDR_SHIFT]),
                                                                  .state(hw_state)
                                                               );

   csr_reg[CSR_TRAFFIC_CTRL_CMD>>CSR_ADDR_SHIFT]  <= update_reg(  .attr(CSR_TRAFFIC_CTRL_CMD_ATTR),
                                                                  .reg_reset_val( afu_csr_afu_traffic_ctrl_cmd_reset.data),
                                                                  .reg_update_val(afu_csr_afu_traffic_ctrl_cmd_update.data),
                                                                  .reg_current_val(csr_reg[CSR_TRAFFIC_CTRL_CMD>>CSR_ADDR_SHIFT]),
                                                                  .write(csr_write[CSR_TRAFFIC_CTRL_CMD>>CSR_ADDR_SHIFT]),
                                                                  .state(hw_state)
                                                               );

   csr_reg[CSR_TRAFFIC_CTRL_DATA>>CSR_ADDR_SHIFT] <= update_reg(  .attr(CSR_TRAFFIC_CTRL_DATA_ATTR),
                                                                  .reg_reset_val(afu_csr_afu_traffic_ctrl_data_reset.data),
                                                                  .reg_update_val(afu_csr_afu_traffic_ctrl_data_update.data),
                                                                  .reg_current_val(csr_reg[CSR_TRAFFIC_CTRL_DATA>>CSR_ADDR_SHIFT]),
                                                                  .write(csr_write[CSR_TRAFFIC_CTRL_DATA>>CSR_ADDR_SHIFT]),
                                                                  .state(hw_state)
                                                               );

   csr_reg[CSR_TRAFFIC_CTRL_PORT>>CSR_ADDR_SHIFT] <= update_reg(  .attr(CSR_TRAFFIC_CTRL_PORT_ATTR),
                                                                  .reg_reset_val(afu_csr_afu_traffic_ctrl_port_update.data),
                                                                  .reg_update_val(afu_csr_afu_traffic_ctrl_port_update.data),
                                                                  .reg_current_val(csr_reg[CSR_TRAFFIC_CTRL_PORT>>CSR_ADDR_SHIFT]),
                                                                  .write(csr_write[CSR_TRAFFIC_CTRL_PORT>>CSR_ADDR_SHIFT]),
                                                                  .state(hw_state)
                                                               );

   csr_reg[CSR_AFU_SCRATCH>>CSR_ADDR_SHIFT]       <= update_reg(  .attr(CSR_AFU_SCRATCH_ATTR),
                                                                  .reg_reset_val(afu_csr_afu_scratchpad_reset.data),
                                                                  .reg_update_val(afu_csr_afu_scratchpad_update.data),
                                                                  .reg_current_val(csr_reg[CSR_AFU_SCRATCH>>CSR_ADDR_SHIFT]),
                                                                  .write(csr_write[CSR_AFU_SCRATCH>>CSR_ADDR_SHIFT]),
                                                                  .state(hw_state)
                                                               );

   csr_reg[CSR_PORT_SWAP_EN>>CSR_ADDR_SHIFT]      <= update_reg(  .attr(CSR_PORT_SWAP_EN_ATTR),
                                                                  .reg_reset_val(afu_csr_port_swap_en_update.data),
                                                                  .reg_update_val(afu_csr_port_swap_en_update.data),
                                                                  .reg_current_val(csr_reg[CSR_PORT_SWAP_EN>>CSR_ADDR_SHIFT]),
                                                                  .write(csr_write[CSR_PORT_SWAP_EN>>CSR_ADDR_SHIFT]),
                                                                  .state(hw_state)
                                                               );
end

always_comb begin
   s_traffic_ctrl_cmd          =  csr_reg[CSR_TRAFFIC_CTRL_CMD>>CSR_ADDR_SHIFT][1:0];
   s_traffic_ctrl_addr         =  csr_reg[CSR_TRAFFIC_CTRL_CMD>>CSR_ADDR_SHIFT][47:32];  
   s_traffic_ctrl_writedata    =  csr_reg[CSR_TRAFFIC_CTRL_DATA>>CSR_ADDR_SHIFT][63:32] ;
end

// AVMM controller for Traffic Controller Registers
mm_ctrl_xcvr #(
   .CMD_W          (2),             // User command width
   .USER_ADDR_W    (AVMM_ADDR_W),   // User address width
   .AVMM_ADDR_W    (AVMM_ADDR_W),   // AVMM address width
   .DATA_W         (AVMM_DATA_W)    // Data width
) inst_mm_ctrl_xcvr (
   // Clocks and Reset
   .i_usr_clk              (clk),   // 250 MHz FME CSRs clock
   .i_avmm_clk             (clk),   // 100 MHz reconfiguration interface clock
   .i_avmm_rst             (rst),   // 100 MHz reset
   // User Interface
   .i_usr_cmd              (s_traffic_ctrl_cmd),
   .i_usr_addr             (s_traffic_ctrl_addr),
   .i_usr_writedata        (s_traffic_ctrl_writedata),
   .o_usr_readdata         (s_traffic_ctrl_readdata),
   .o_usr_ack              (s_traffic_ctrl_ack),
   // AvalonMM Interface
   .o_avmm_addr            (o_avmm_addr),
   .o_avmm_read            (o_avmm_read),
   .o_avmm_write           (o_avmm_write),
   .o_avmm_writedata       (o_avmm_writedata),
   .i_avmm_readdata        (i_avmm_readdata),
   .i_avmm_readdata_valid  (),      //does not exist for traffic controller interfaces
   .i_avmm_waitrequest     (i_avmm_waitrequest)
);

endmodule //eth_traffic_afu 


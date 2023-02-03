// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// Port Gasket CSR
//-----------------------------------------------------------------------------

`include "fpga_defines.vh"

module pg_csr #(
   parameter END_OF_LIST     = 1'b0,
   parameter NEXT_DFH_OFFSET = 24'h01_0000,
   parameter ADDR_WIDTH      = 20, 
   parameter DATA_WIDTH      = 64,
   parameter AGILEX          = 0
)(
   input                                       clk,
   input                                       rst_n,

   ofs_fim_axi_lite_if.slave                   axi_s_if,

   // PR CTRL Interface
   pr_ctrl_if.src                              pr_ctrl_io,
   input  logic                                i_pr_freeze,

   // PORT CTRL Interface
   input  logic     [63:0]                     i_port_ctrl,
   output logic     [63:0]                     o_port_ctrl,

   // User clock interface
   output logic     [63:0]                     user_clk_freq_cmd_0,
   output logic     [63:0]                     user_clk_freq_cmd_1,
   input  logic     [63:0]                     user_clk_freq_sts_0,
   input  logic     [63:0]                     user_clk_freq_sts_1,

   // Remote STP status
   input  logic     [63:0]                     i_remotestp_status,

   // Remote STP IP interface
   ofs_fim_axi_lite_if.master                  m_remotestp_if
);
import ofs_csr_pkg::*;
import pg_csr_pkg::*;
import fme_csr_pkg::*;


//----------------------------------------------------------------------------
// SIGNAL DEFINITIONS
//----------------------------------------------------------------------------
//----------------------------------------------------------------------------
// CSR registers are implemented in a two dimensional array according to the
// features and the number of registers per feature.  This allows the most
// flexibility addressing the registers as well as using the least resources.
//----------------------------------------------------------------------------
//....[63:0 packed width].....reg[10:0 - #Features   ][22:0 - #Regs in Feature]  <<= Unpacked dimensions.

localparam USER_CLK_MINOR_REV = (AGILEX == 1) ? 4'h1 : 4'h0; 
logic [CSR_REG_WIDTH-1:0]   csr_reg     [PG_CSR_FEATURE_NUM-1:0][PG_CSR_FEATURE_REG_NUM-1:0];   // CSR Registers
logic                       csr_write   [PG_CSR_FEATURE_NUM-1:0][PG_CSR_FEATURE_REG_NUM-1:0];   // Arrayed like the CSR registers

ofs_csr_hw_state_t          hw_state;           // Hardware state during CSR updates.  This simplifies the CSR Register Update function call.

logic                       aw_ready_valid, w_ready_valid, b_ready_valid, ar_ready_valid, r_ready_valid;

logic [ADDR_WIDTH-1:0]      waddr_reg;
logic [CSR_REG_WIDTH-1:0]   wdata_reg;

csr_access_type_t           write_type, write_type_reg;

logic [ADDR_WIDTH-1:0]      raddr_reg;

port_csr_port_dfh_t         port_csr_port_dfh_reset, port_csr_port_dfh_update;
port_csr_port_afu_id_l_t    port_csr_port_afu_id_l_reset, port_csr_port_afu_id_l_update;
port_csr_port_afu_id_h_t    port_csr_port_afu_id_h_reset, port_csr_port_afu_id_h_update;
port_csr_first_afu_offset_t port_csr_first_afu_offset_reset, port_csr_first_afu_offset_update;
ofs_csr_reg_generic_t       port_csr_port_mailbox_reset, port_csr_port_mailbox_update;
ofs_csr_reg_generic_t       port_csr_port_scratchpad0_reset, port_csr_port_scratchpad0_update;
port_csr_port_capability_t  port_csr_port_capability_reset, port_csr_port_capability_update;
port_csr_port_control_t     port_csr_port_control_reset, port_csr_port_control_update;
port_csr_port_control_t     port_csr_port_control;
port_csr_port_status_t      port_csr_port_status_reset, port_csr_port_status_update;

ofs_csr_reg_generic_t       pg_csr_pr_scratchpad_reset, pg_csr_pr_scratchpad_update;

fme_csr_dfh_t                      fme_csr_fme_pr_dfh_reset, fme_csr_fme_pr_dfh_update;
fme_csr_fme_pr_ctrl_t              fme_csr_fme_pr_ctrl_reset, fme_csr_fme_pr_ctrl_update;
fme_csr_fme_pr_status_t            fme_csr_fme_pr_status_reset, fme_csr_fme_pr_status_update;
ofs_csr_reg_generic_t              fme_csr_fme_pr_data_reset, fme_csr_fme_pr_data_update;
fme_csr_fme_pr_error_t             fme_csr_fme_pr_error_reset, fme_csr_fme_pr_error_update;
ofs_csr_reg_generic_t              fme_csr_dummy_5028_reset, fme_csr_dummy_5028_update;
ofs_csr_reg_generic_t              fme_csr_dummy_5030_reset, fme_csr_dummy_5030_update;
ofs_csr_reg_generic_t              fme_csr_dummy_5038_reset, fme_csr_dummy_5038_update;
ofs_csr_reg_generic_t              fme_csr_dummy_5040_reset, fme_csr_dummy_5040_update;
ofs_csr_reg_generic_t              fme_csr_dummy_5048_reset, fme_csr_dummy_5048_update;
ofs_csr_reg_generic_t              fme_csr_dummy_5050_reset, fme_csr_dummy_5050_update;
ofs_csr_reg_generic_t              fme_csr_dummy_5058_reset, fme_csr_dummy_5058_update;
ofs_csr_reg_generic_t              fme_csr_dummy_5060_reset, fme_csr_dummy_5060_update;
ofs_csr_reg_generic_t              fme_csr_dummy_5068_reset, fme_csr_dummy_5068_update;
ofs_csr_reg_generic_t              fme_csr_dummy_5070_reset, fme_csr_dummy_5070_update;
ofs_csr_reg_generic_t              fme_csr_dummy_5078_reset, fme_csr_dummy_5078_update;
ofs_csr_reg_generic_t              fme_csr_dummy_5080_reset, fme_csr_dummy_5080_update;
ofs_csr_reg_generic_t              fme_csr_dummy_5088_reset, fme_csr_dummy_5088_update;
ofs_csr_reg_generic_t              fme_csr_dummy_5090_reset, fme_csr_dummy_5090_update;
ofs_csr_reg_generic_t              fme_csr_dummy_5098_reset, fme_csr_dummy_5098_update;
ofs_csr_reg_generic_t              fme_csr_dummy_50A0_reset, fme_csr_dummy_50A0_update;
ofs_csr_reg_generic_t              fme_csr_fme_pr_intfc_id_l_reset, fme_csr_fme_pr_intfc_id_l_update;
ofs_csr_reg_generic_t              fme_csr_fme_pr_intfc_id_h_reset, fme_csr_fme_pr_intfc_id_h_update;

pg_csr_user_clk_dfh_t       pg_csr_user_clk_dfh_reset, pg_csr_user_clk_dfh_update;
pg_csr_user_clk_freq_cmd0_t pg_csr_user_clk_freq_cmd0_reset, pg_csr_user_clk_freq_cmd0_update;
pg_csr_user_clk_freq_cmd1_t pg_csr_user_clk_freq_cmd1_reset, pg_csr_user_clk_freq_cmd1_update;
pg_csr_user_clk_freq_sts0_t pg_csr_user_clk_freq_sts0_reset, pg_csr_user_clk_freq_sts0_update;
pg_csr_user_clk_freq_sts1_t pg_csr_user_clk_freq_sts1_reset, pg_csr_user_clk_freq_sts1_update;

port_csr_dfh_t                     port_csr_port_stp_dfh_reset, port_csr_port_stp_dfh_update;
port_csr_port_stp_status_t         port_csr_port_stp_status_reset, port_csr_port_stp_status_update;

// Port DFH Register Bit Attributes -----------------------------------------------
port_csr_port_dfh_attr_t port_dfh_attr;
assign port_dfh_attr.port_dfh.feature_type    = {4{RO}};
assign port_dfh_attr.port_dfh.reserved        = {19{RsvdZ}};
assign port_dfh_attr.port_dfh.end_of_list     = RO;
assign port_dfh_attr.port_dfh.next_dfh_offset = {24{RO}};
assign port_dfh_attr.port_dfh.afu_maj_version = {4{RO}};
assign port_dfh_attr.port_dfh.corefim_version = {12{RO}};
// Port AFU ID Low Register Bit Attributes ----------------------------------------
port_csr_port_afu_id_l_attr_t port_afu_id_l_attr;
assign port_afu_id_l_attr.port_afu_id_l.afu_id_l = {64{RO}};
// Port AFU ID High Register Bit Attributes ---------------------------------------
port_csr_port_afu_id_h_attr_t port_afu_id_h_attr;
assign port_afu_id_h_attr.port_afu_id_h.afu_id_h = {64{RO}};
// Port First AFU Offset Register Bit Attributes ----------------------------------
port_csr_first_afu_offset_attr_t first_afu_offset_attr;
assign first_afu_offset_attr.first_afu_offset.reserved         = {40{RsvdZ}};
assign first_afu_offset_attr.first_afu_offset.first_afu_offset = {24{RO}};
// Port Main Utility, Control, and Status Register Bit Attributes -----------------
ofs_csr_reg_generic_attr_t port_mailbox_attr;
assign port_mailbox_attr = {64{RW}};
ofs_csr_reg_generic_attr_t port_scratchpad0_attr;
assign port_scratchpad0_attr = {64{RW}};
port_csr_port_capability_attr_t port_capability_attr;
assign port_capability_attr.port_capability.reserved36   = {28{RsvdZ}};
assign port_capability_attr.port_capability.num_supp_int = {4{RO}};
assign port_capability_attr.port_capability.reserved24   = {8{RsvdZ}};
assign port_capability_attr.port_capability.mmio_size    = {16{RO}};
assign port_capability_attr.port_capability.reserved0    = {8{RsvdZ}};
port_csr_port_control_attr_t port_control_attr;
assign port_control_attr.port_control.reserved5           = {59{RsvdZ}};
assign port_control_attr.port_control.port_soft_reset_ack = RO;
assign port_control_attr.port_control.flr_port_reset      = RO;
assign port_control_attr.port_control.latency_tolerance   = RW;
assign port_control_attr.port_control.reserved1           = RsvdZ;
assign port_control_attr.port_control.port_soft_reset     = RW;
port_csr_port_status_attr_t port_status_attr;
assign port_status_attr.port_status.reserved1   = {63{RsvdZ}};
assign port_status_attr.port_status.port_freeze = RO;

// Partial Reconfiguration Registers Bit Attributes -------------------------------
fme_csr_dfh_attr_t fme_pr_dfh_attr;
assign fme_pr_dfh_attr.dfh.feature_type    = {4{RO}};
assign fme_pr_dfh_attr.dfh.reserved        = {19{RsvdZ}};
assign fme_pr_dfh_attr.dfh.end_of_list     = RO;
assign fme_pr_dfh_attr.dfh.next_dfh_offset = {24{RO}};
assign fme_pr_dfh_attr.dfh.feature_rev     = {4{RO}};
assign fme_pr_dfh_attr.dfh.feature_id      = {12{RO}};
fme_csr_fme_pr_ctrl_attr_t fme_pr_ctrl_attr;
assign fme_pr_ctrl_attr.fme_pr_ctrl.config_data           = {32{RW}};
assign fme_pr_ctrl_attr.fme_pr_ctrl.reserved15            = {17{RsvdZ}};
assign fme_pr_ctrl_attr.fme_pr_ctrl.pr_kind               = RW;
assign fme_pr_ctrl_attr.fme_pr_ctrl.pr_data_push_complete = RW1S;
assign fme_pr_ctrl_attr.fme_pr_ctrl.pr_start_request      = RW1S;
assign fme_pr_ctrl_attr.fme_pr_ctrl.reserved10            = {2{RsvdZ}};
assign fme_pr_ctrl_attr.fme_pr_ctrl.pr_region_id          = {2{RW}};
assign fme_pr_ctrl_attr.fme_pr_ctrl.reserved5             = {3{RsvdZ}};
assign fme_pr_ctrl_attr.fme_pr_ctrl.pr_reset_ack          = RO;
assign fme_pr_ctrl_attr.fme_pr_ctrl.reserved1             = {3{RsvdZ}};
assign fme_pr_ctrl_attr.fme_pr_ctrl.pr_reset              = RW;
fme_csr_fme_pr_status_attr_t fme_pr_status_attr;
assign fme_pr_status_attr.fme_pr_status.security_block_status = {32{RO}};
assign fme_pr_status_attr.fme_pr_status.reserved28            = {4{RsvdZ}};
assign fme_pr_status_attr.fme_pr_status.pr_host_status        = {4{RO}};
assign fme_pr_status_attr.fme_pr_status.reserved23            = RsvdZ;
assign fme_pr_status_attr.fme_pr_status.altera_pr_ctrl_status = {3{RO}};
assign fme_pr_status_attr.fme_pr_status.reserved17            = {3{RsvdZ}};
assign fme_pr_status_attr.fme_pr_status.pr_status             = RO;
assign fme_pr_status_attr.fme_pr_status.reserved9             = {7{RsvdZ}};
assign fme_pr_status_attr.fme_pr_status.numb_credits          = {9{RO}};
ofs_csr_reg_generic_attr_t fme_pr_data_attr;
assign fme_pr_data_attr.data = { 64{RW} };
fme_csr_fme_pr_error_attr_t fme_pr_error_attr;
assign fme_pr_error_attr.fme_pr_error.reserved7                      = {57{RsvdZ}};
assign fme_pr_error_attr.fme_pr_error.secure_load_failed             = RW1C;
assign fme_pr_error_attr.fme_pr_error.host_init_timeout              = RW1C;
assign fme_pr_error_attr.fme_pr_error.host_init_fifo_overflow        = RW1C;
assign fme_pr_error_attr.fme_pr_error.ip_init_protocol_error         = RW1C;
assign fme_pr_error_attr.fme_pr_error.ip_init_incompatible_bitstream = RW1C;
assign fme_pr_error_attr.fme_pr_error.ip_init_crc_error              = RW1C;
assign fme_pr_error_attr.fme_pr_error.host_init_operation_error      = RW1C;
ofs_csr_reg_generic_attr_t dummy_5028_attr;
assign dummy_5028_attr.data = {64{RO}};
ofs_csr_reg_generic_attr_t dummy_5030_attr;
assign dummy_5030_attr.data = {64{RO}};
ofs_csr_reg_generic_attr_t dummy_5038_attr;
assign dummy_5038_attr.data = {64{RO}};
ofs_csr_reg_generic_attr_t dummy_5040_attr;
assign dummy_5040_attr.data = {64{RO}};
ofs_csr_reg_generic_attr_t dummy_5048_attr;
assign dummy_5048_attr.data = {64{RO}};
ofs_csr_reg_generic_attr_t dummy_5050_attr;
assign dummy_5050_attr.data = {64{RO}};
ofs_csr_reg_generic_attr_t dummy_5058_attr;
assign dummy_5058_attr.data = {64{RO}};
ofs_csr_reg_generic_attr_t dummy_5060_attr;
assign dummy_5060_attr.data = {64{RO}};
ofs_csr_reg_generic_attr_t dummy_5068_attr;
assign dummy_5068_attr.data = {64{RO}};
ofs_csr_reg_generic_attr_t dummy_5070_attr;
assign dummy_5070_attr.data = {64{RO}};
ofs_csr_reg_generic_attr_t dummy_5078_attr;
assign dummy_5078_attr.data = {64{RO}};
ofs_csr_reg_generic_attr_t dummy_5080_attr;
assign dummy_5080_attr.data = {64{RO}};
ofs_csr_reg_generic_attr_t dummy_5088_attr;
assign dummy_5088_attr.data = {64{RO}};
ofs_csr_reg_generic_attr_t dummy_5090_attr;
assign dummy_5090_attr.data = {64{RO}};
ofs_csr_reg_generic_attr_t dummy_5098_attr;
assign dummy_5098_attr.data = {64{RO}};
ofs_csr_reg_generic_attr_t dummy_50a0_attr;
assign dummy_50a0_attr.data = {64{RO}};
ofs_csr_reg_generic_attr_t fme_pr_intfc_id_l_attr;
assign fme_pr_intfc_id_l_attr.data = {64{RO}};
ofs_csr_reg_generic_attr_t fme_pr_intfc_id_h_attr;
assign fme_pr_intfc_id_h_attr.data = {64{RO}};

// Port SignalTap Register Bit Attributes -----------------------------------------
port_csr_dfh_attr_t port_stp_dfh_attr;
assign port_stp_dfh_attr.dfh.feature_type    = {4{RO}};
assign port_stp_dfh_attr.dfh.reserved        = {19{RsvdZ}};
assign port_stp_dfh_attr.dfh.end_of_list     = RO;
assign port_stp_dfh_attr.dfh.next_dfh_offset = {24{RO}};
assign port_stp_dfh_attr.dfh.feature_rev     = {4{RO}};
assign port_stp_dfh_attr.dfh.feature_id      = {12{RO}};
port_csr_port_stp_status_attr_t port_stp_status_attr;
assign port_stp_status_attr.port_stp_status.num_mmio_resp     = {16{RO}};
assign port_stp_status_attr.port_stp_status.num_mmio_req      = {16{RO}};
assign port_stp_status_attr.port_stp_status.num_mmio_wr       = {16{RO}};
assign port_stp_status_attr.port_stp_status.rx_fifo_underflow = RO;
assign port_stp_status_attr.port_stp_status.rx_fifo_overflow  = RO;
assign port_stp_status_attr.port_stp_status.tx_fifo_underflow = RO;
assign port_stp_status_attr.port_stp_status.tx_fifo_overflow  = RO;
assign port_stp_status_attr.port_stp_status.rx_fifo_count     = {4{RO}};
assign port_stp_status_attr.port_stp_status.tx_fifo_count     = {4{RO}};
assign port_stp_status_attr.port_stp_status.mmio_time_out     = RO;
assign port_stp_status_attr.port_stp_status.unsupported_rd    = RO;
assign port_stp_status_attr.port_stp_status.stp_in_reset      = RO;
assign port_stp_status_attr.port_stp_status.rw_time_out       = RO;

//----------------------------------------------------------------------------
// HW State is a data struct used to pass the resets, write data, and write
// type to the CSR "update_reg" function.
//----------------------------------------------------------------------------
assign hw_state.reset_n      = rst_n;
assign hw_state.pwr_good_n   = 1'b0;
assign hw_state.wr_data.data = wdata_reg;
assign hw_state.write_type   = write_type_reg;

//----------------------------------------------------------------------------
// Combinatorial logic to define what type of write is occurring:
//     1.) UPPER32 = Upper 32 bits of register from lower 32 bits of the write
//         data bus.
//     2.) LOWER32 = Lower 32 bits of register from lower 32 bits of the write
//         data bus.
//     3.) FULL64 = All 64 bits of the register from all 64 bits of the write
//         data bus.
//     4.) NONE = No write will be performed on register.
// Logic must be careful to detect simultaneous awvalid and wvalid OR awvalid
// leading wvalid.  A write address with bit #2 set decides whether 32-bit
// write is to upper or lower word.
//----------------------------------------------------------------------------
always_comb
begin
   write_type = ( !axi_s_if.wvalid )      ?  NONE    :
                  ( &axi_s_if.wstrb )     ?  FULL64  : 
                  ( !axi_s_if.awvalid )   ?
                  ( !waddr_reg[2] )       ?  LOWER32 :
                                             UPPER32 :
                  ( !axi_s_if.awaddr[2] ) ?  LOWER32 :
                                             UPPER32 ;                                                                    
end

//----------------------------------------------------------------------------
// Remote STP IP intercept
//----------------------------------------------------------------------------
logic   remotestp_awaddr_hit;
logic   remotestp_araddr_hit;

logic   remotestp_awaddr_hit_reg;
logic   remotestp_araddr_hit_reg;

`ifndef INCLUDE_REMOTE_STP
assign  remotestp_awaddr_hit        = 1'b0;
assign  remotestp_araddr_hit        = 1'b0;

assign  remotestp_awaddr_hit_reg    = 1'b0;
assign  remotestp_araddr_hit_reg    = 1'b0;
`else
always_ff @ ( posedge clk ) begin
   if ( !rst_n )
      begin
         remotestp_awaddr_hit_reg    <= 1'b0;
         remotestp_araddr_hit_reg    <= 1'b0;
      end else begin
         if ( aw_ready_valid )
            remotestp_awaddr_hit_reg <= remotestp_awaddr_hit;
      
         if ( ar_ready_valid )
            remotestp_araddr_hit_reg <= remotestp_araddr_hit;
      end
end

// Remote STP IP address hit
always_comb
begin
   if ( aw_ready_valid )
      remotestp_awaddr_hit = ( axi_s_if.awaddr[15:4] > PORT_STP_DFH[15:4] );
   else
      remotestp_awaddr_hit = remotestp_awaddr_hit_reg;

   if ( ar_ready_valid )
      remotestp_araddr_hit = ( axi_s_if.araddr[15:4] > PORT_STP_DFH[15:4] );
   else
      remotestp_araddr_hit = remotestp_araddr_hit_reg;
end
`endif

// Tx ports m_remotestp_if
always_comb
begin
   m_remotestp_if.awvalid = remotestp_awaddr_hit  ? axi_s_if.awvalid  : 1'b0;
   m_remotestp_if.awaddr  = axi_s_if.awaddr;
   m_remotestp_if.awprot  = axi_s_if.awprot;

   m_remotestp_if.wvalid  = remotestp_awaddr_hit  ? axi_s_if.wvalid   : 1'b0;
   m_remotestp_if.wdata   = axi_s_if.wdata;
   m_remotestp_if.wstrb   = axi_s_if.wstrb;

   m_remotestp_if.bready  = axi_s_if.bready;

   m_remotestp_if.arvalid = remotestp_araddr_hit  ? axi_s_if.arvalid  : 1'b0;
   m_remotestp_if.araddr  = axi_s_if.araddr;
   m_remotestp_if.arprot  = axi_s_if.arprot;

   m_remotestp_if.rready  = axi_s_if.rready;
end

//----------------------------------------------------------------------------
// AXI-LITE READY + VALID
//----------------------------------------------------------------------------
always_comb
begin
   aw_ready_valid = ( axi_s_if.awready && axi_s_if.awvalid );
   w_ready_valid  = ( axi_s_if.wready && axi_s_if.wvalid );
   b_ready_valid  = ( axi_s_if.bready && axi_s_if.bvalid );
   ar_ready_valid = ( axi_s_if.arready && axi_s_if.arvalid );
   r_ready_valid  = ( axi_s_if.rready && axi_s_if.rvalid );
end

//----------------------------------------------------------------------------
// AXI-LITE WRITE INTERFACE
//----------------------------------------------------------------------------
typedef enum bit [1:0] {
   ST_WADDR,
   ST_WDATA,
   ST_BWAIT,
   ST_BRESP
} WriteState_t;

WriteState_t     WriteState, WriteNextState;

always_ff @ (posedge clk) begin
   if ( !rst_n ) begin
      WriteState <= ST_WADDR;
   end else begin
      WriteState <= WriteNextState;
   end
end    

always_comb begin
   WriteNextState = WriteState;

   case (WriteState)
      ST_WADDR: begin
         if (aw_ready_valid && w_ready_valid) WriteNextState = ST_BWAIT;
         else if (aw_ready_valid) WriteNextState = ST_WDATA; 
      end

      ST_WDATA: begin
            if (w_ready_valid) WriteNextState = ST_BWAIT;
      end

      ST_BWAIT: begin
         WriteNextState = ST_BRESP;
      end

      ST_BRESP: begin
         if (b_ready_valid) WriteNextState = ST_WADDR;
      end
   endcase

end

always_comb
begin
   axi_s_if.awready                = 1'b0;
   axi_s_if.wready                 = 1'b0;
   axi_s_if.bvalid                 = 1'b0;
   axi_s_if.bresp                  = 2'b00;

   csr_write                       = '{default:0};

   case ( WriteState )
      ST_WADDR: begin
         axi_s_if.awready = 1'b1;
         axi_s_if.wready  = 1'b1;                    
      end

      ST_WDATA: begin
         axi_s_if.wready = 1'b1;                         
      end

      ST_BWAIT: begin
         csr_write[waddr_reg[14:12]][waddr_reg[7:3]] = 1'b1;    
            if (remotestp_awaddr_hit) begin
               csr_write = '{default:0};
            end                      
      end

      ST_BRESP: begin
         csr_write[waddr_reg[14:12]][waddr_reg[7:3]]     = 1'b1; 
         axi_s_if.bvalid = 1'b1;

         if (remotestp_awaddr_hit) begin
            csr_write       = '{default:0};
            axi_s_if.bvalid = m_remotestp_if.bvalid;
            axi_s_if.bresp  = m_remotestp_if.bresp;
         end                
      end

   endcase
end

always_ff @ (posedge clk) begin
   if (!rst_n) begin        
      write_type_reg <= NONE;
      waddr_reg      <= {ADDR_WIDTH{1'b0}};
      wdata_reg      <= {CSR_REG_WIDTH{1'b0}};
   end else begin
      write_type_reg <= write_type;

      if (w_ready_valid) begin
         wdata_reg <= axi_s_if.wdata;
      end

      if (aw_ready_valid) begin
         waddr_reg <= axi_s_if.awaddr;
      end

   end
end

//----------------------------------------------------------------------------
// AXI-LITE READ INTERFACE
//----------------------------------------------------------------------------
typedef enum {
   ST_RADDR,
   ST_RDATA
} ReadState_t;

ReadState_t      ReadState, ReadNextState;

always_ff @ (posedge clk) begin
   if (!rst_n) begin
      ReadState           <= ST_RADDR;
   end else begin
      ReadState           <= ReadNextState;
   end
end

always_comb begin
   ReadNextState           = ReadState;

   case ( ReadState )
      ST_RADDR: begin
         if (ar_ready_valid) begin
            ReadNextState = ST_RDATA;
         end
      end

      ST_RDATA: begin
         if (r_ready_valid) begin
            ReadNextState           = ST_RADDR;        
         end
      end
   endcase
end

always_comb begin
   axi_s_if.arready = 1'b0;
   axi_s_if.rvalid  = 1'b0;
   axi_s_if.rresp   = 2'b00;
   axi_s_if.rdata   = csr_reg[raddr_reg[14:12]][raddr_reg[7:3]];

   if (remotestp_araddr_hit) begin
      axi_s_if.rdata = m_remotestp_if.rdata;
   end

   case (ReadState)
      ST_RADDR: begin
         axi_s_if.arready = 1'b1;               
      end

      ST_RDATA: begin
         axi_s_if.rvalid = 1'b1; 

         if (remotestp_araddr_hit) begin
            axi_s_if.rvalid = m_remotestp_if.rvalid;
            axi_s_if.rresp  = m_remotestp_if.rresp;
         end                
      end
   endcase

end

always_ff @ (posedge clk)
begin
   if (!rst_n) begin
      raddr_reg <= {ADDR_WIDTH{1'b0}};
   end else begin
      if (ar_ready_valid) begin
         raddr_reg <= axi_s_if.araddr;
      end
   end
end

//----------------------------------------------------------------------------
// User Clk CMD Assignments
//----------------------------------------------------------------------------
assign user_clk_freq_cmd_0 = csr_reg[PG_USER_CLK_FREQ_CMD0[14:12]][PG_USER_CLK_FREQ_CMD0[7:3]];
assign user_clk_freq_cmd_1 = csr_reg[PG_USER_CLK_FREQ_CMD1[14:12]][PG_USER_CLK_FREQ_CMD1[7:3]];

//----------------------------------------------------------------------------
// FME IDs : FME CSR setup values for the following registers are read from 
//           ROM contents at startup:
//
//           BITSTREAM_ID @ Address 20'h0_0060 in FME
//           BITSTREAM_MD @ Address 20'h0_0068 in FME
//           FME_PR_INTFC_ID_L @ Port Gasket PR DFH
//           FME_PR_INTFC_ID_H @ Port Gasket PR DFH
//           BITSTREAM_INFO @ Address 20'h0_0070 in FME
//           RESERVED_0_IDX @ Reserved Space 0
//           RESERVED_1_IDX @ Reserved Space 1
//           RESERVED_2_IDX @ Reserved Space 2
//----------------------------------------------------------------------------
localparam FME_ID_NUM_REGS = 8;
localparam FME_ID_IDX_WIDTH = $clog2(FME_ID_NUM_REGS);

typedef enum bit [FME_ID_IDX_WIDTH-1:0]  {
   BITSTREAM_ID_IDX,
   BITSTREAM_MD_IDX,
   FME_PR_IF_ID_L_IDX,
   FME_PR_IF_ID_H_IDX,
   BITSTREAM_INFO_IDX,
   RESERVED_0_IDX,
   RESERVED_1_IDX,
   RESERVED_2_IDX
} fme_id_idx_t;
fme_id_idx_t FME_ID_MEM_MAX = RESERVED_2_IDX;
logic [63:0] fme_id_regs[FME_ID_NUM_REGS-1:0];
logic [FME_ID_IDX_WIDTH-1:0] rom_addr;
logic [63:0] rom_data;

//--------------------------------------------------------------------------------
// ROM storing FME IDs:
// Reading a ROM address takes 2 clock cycles (both address and q are registered).
//--------------------------------------------------------------------------------
fme_id_rom fme_id_rom (
   .address(rom_addr),
   .clock(clk),
   .q(rom_data)
);

//----------------------------------------------------------------------------
// Population of FME IDs from ROM to FME ID registers is continually done by 
// the following state machine.
//----------------------------------------------------------------------------
enum {
   ROM_RESET_BIT      = 0,
   ROM_CLK_ADDR_BIT   = 1,
   ROM_FETCH_DATA_BIT = 2,
   ROM_CLK_DATA_BIT   = 3,
   ROM_STORE_REG_BIT  = 4,
   ROM_INC_ADDR_BIT   = 5
} rom_state_bit;


enum logic [5:0] {
   ROM_RESET      = 6'b000001<<ROM_RESET_BIT,
   ROM_CLK_ADDR   = 6'b000001<<ROM_CLK_ADDR_BIT,
   ROM_FETCH_DATA = 6'b000001<<ROM_FETCH_DATA_BIT,
   ROM_CLK_DATA   = 6'b000001<<ROM_CLK_DATA_BIT,
   ROM_STORE_REG  = 6'b000001<<ROM_STORE_REG_BIT,
   ROM_INC_ADDR   = 6'b000001<<ROM_INC_ADDR_BIT
} rom_state, rom_next;

always_ff @(posedge clk) begin : rom_sm_seq
   if (!rst_n) begin
      rom_state <= ROM_RESET;
   end else begin
      rom_state <= rom_next;
   end
end : rom_sm_seq


always_comb begin : rom_sm_comb
   rom_next = rom_state;
   unique case (1'b1) //Reverse Case Statement
      rom_state[ROM_RESET_BIT] :
         if (!rst_n) begin
            rom_next = ROM_RESET;
         end else begin
            rom_next = ROM_CLK_ADDR;
         end
      rom_state[ROM_CLK_ADDR_BIT] :
         rom_next = ROM_FETCH_DATA;
      rom_state[ROM_FETCH_DATA_BIT] :
         rom_next = ROM_CLK_DATA;
      rom_state[ROM_CLK_DATA_BIT] :
         rom_next = ROM_STORE_REG;
      rom_state[ROM_STORE_REG_BIT] :
         rom_next = ROM_INC_ADDR;
      rom_state[ROM_INC_ADDR_BIT] :
         rom_next = ROM_CLK_ADDR;
   endcase
end : rom_sm_comb


always_ff @(posedge clk) 
begin
   if (rom_state[ROM_RESET_BIT]) 
   begin
      fme_id_regs[BITSTREAM_ID_IDX]   <= {64{1'b0}};
      fme_id_regs[BITSTREAM_MD_IDX]   <= {64{1'b0}};
      fme_id_regs[FME_PR_IF_ID_L_IDX] <= {64{1'b0}};
      fme_id_regs[FME_PR_IF_ID_H_IDX] <= {64{1'b0}};
      fme_id_regs[BITSTREAM_INFO_IDX] <= {64{1'b0}};
      fme_id_regs[RESERVED_0_IDX]     <= {64{1'b0}};
      fme_id_regs[RESERVED_1_IDX]     <= {64{1'b0}};
      fme_id_regs[RESERVED_2_IDX]     <= {64{1'b0}};
   end
   else
   begin
      if (rom_state[ROM_STORE_REG_BIT])
      begin
         fme_id_regs[rom_addr] <= rom_data;
      end
   end
end

always_ff @(posedge clk)
begin
   if (rom_state[ROM_RESET_BIT])
      rom_addr <= FME_ID_IDX_WIDTH'('b000);
   else
      if (rom_state[ROM_INC_ADDR_BIT])
         rom_addr <= rom_addr + FME_ID_IDX_WIDTH'('d1);
end


//----------------------------------------------------------------------------
// PR Register Reset/Update Structure Overlays.
//----------------------------------------------------------------------------
// Partial Reconfiguration Registers--------------------------------------------------------------------------------
// PR DFH Register--------------------------------------------------------------------------------------------------
assign fme_csr_fme_pr_dfh_reset.data = fme_csr_fme_pr_dfh_update.data; 
assign fme_csr_fme_pr_dfh_update.dfh.feature_type    = 4'h3; 
assign fme_csr_fme_pr_dfh_update.dfh.reserved        = {19{1'b0}}; 
assign fme_csr_fme_pr_dfh_update.dfh.end_of_list     = 1'b0;
assign fme_csr_fme_pr_dfh_update.dfh.next_dfh_offset = 24'h1000;
assign fme_csr_fme_pr_dfh_update.dfh.feature_rev     = 4'h1; 
assign fme_csr_fme_pr_dfh_update.dfh.feature_id      = 12'h005; 
// PR Control Register----------------------------------------------------------------------------------------------
assign fme_csr_fme_pr_ctrl_reset.data = { {59{1'b0}}, pr_ctrl_io.inp2prc_pg_pr_ctrl[4], {4{1'b0}} };
assign fme_csr_fme_pr_ctrl_update.fme_pr_ctrl.config_data           = pr_ctrl_io.inp2prc_pg_pr_ctrl[63:32];
assign fme_csr_fme_pr_ctrl_update.fme_pr_ctrl.reserved15            = {17{1'b0}};
assign fme_csr_fme_pr_ctrl_update.fme_pr_ctrl.pr_kind               = pr_ctrl_io.inp2prc_pg_pr_ctrl[14];
assign fme_csr_fme_pr_ctrl_update.fme_pr_ctrl.pr_data_push_complete = pr_ctrl_io.inp2prc_pg_pr_ctrl[13];
assign fme_csr_fme_pr_ctrl_update.fme_pr_ctrl.pr_start_request      = pr_ctrl_io.inp2prc_pg_pr_ctrl[12];
assign fme_csr_fme_pr_ctrl_update.fme_pr_ctrl.reserved10            = 2'b00;
assign fme_csr_fme_pr_ctrl_update.fme_pr_ctrl.pr_region_id          = pr_ctrl_io.inp2prc_pg_pr_ctrl[ 9:8];
assign fme_csr_fme_pr_ctrl_update.fme_pr_ctrl.reserved5             = {3{1'b0}};
assign fme_csr_fme_pr_ctrl_update.fme_pr_ctrl.pr_reset_ack          = pr_ctrl_io.inp2prc_pg_pr_ctrl[4];
assign fme_csr_fme_pr_ctrl_update.fme_pr_ctrl.reserved1             = {3{1'b0}};
assign fme_csr_fme_pr_ctrl_update.fme_pr_ctrl.pr_reset              = pr_ctrl_io.inp2prc_pg_pr_ctrl[0];
// PR Status Register-----------------------------------------------------------------------------------------------
assign fme_csr_fme_pr_status_reset.data = fme_csr_fme_pr_status_update.data;
assign fme_csr_fme_pr_status_update.fme_pr_status.security_block_status = pr_ctrl_io.inp2prc_pg_pr_status[63:32];
assign fme_csr_fme_pr_status_update.fme_pr_status.reserved28            = {4{1'b0}};
assign fme_csr_fme_pr_status_update.fme_pr_status.pr_host_status        = pr_ctrl_io.inp2prc_pg_pr_status[27:24];
assign fme_csr_fme_pr_status_update.fme_pr_status.reserved23            = 1'b0;
assign fme_csr_fme_pr_status_update.fme_pr_status.altera_pr_ctrl_status = pr_ctrl_io.inp2prc_pg_pr_status[22:20];
assign fme_csr_fme_pr_status_update.fme_pr_status.reserved17            = {3{1'b0}};
assign fme_csr_fme_pr_status_update.fme_pr_status.pr_status             = |(csr_reg[PG_PR_ERROR[14:12]][PG_PR_ERROR[7:3]]); // WAS |fme_csr_fme_pr_error.data[4:0];
assign fme_csr_fme_pr_status_update.fme_pr_status.reserved9             = {7{1'b0}};
assign fme_csr_fme_pr_status_update.fme_pr_status.numb_credits          = pr_ctrl_io.inp2prc_pg_pr_status[ 8:0];
// PR Data Register-------------------------------------------------------------------------------------------------
assign fme_csr_fme_pr_data_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_fme_pr_data_update.data = 64'h0000_0000_0000_0000;
// PR Error Register-------------------------------------------------------------------------------------------------
assign fme_csr_fme_pr_error_reset.data = 64'h0000_0000_0000_0000;
assign fme_csr_fme_pr_error_update.fme_pr_error.reserved7                      = {57{1'b0}};
assign fme_csr_fme_pr_error_update.fme_pr_error.secure_load_failed             = pr_ctrl_io.inp2prc_pg_pr_error[6];
assign fme_csr_fme_pr_error_update.fme_pr_error.host_init_timeout              = pr_ctrl_io.inp2prc_pg_pr_error[5];
assign fme_csr_fme_pr_error_update.fme_pr_error.host_init_fifo_overflow        = pr_ctrl_io.inp2prc_pg_pr_error[4];
assign fme_csr_fme_pr_error_update.fme_pr_error.ip_init_protocol_error         = pr_ctrl_io.inp2prc_pg_pr_error[3];
assign fme_csr_fme_pr_error_update.fme_pr_error.ip_init_incompatible_bitstream = pr_ctrl_io.inp2prc_pg_pr_error[2];
assign fme_csr_fme_pr_error_update.fme_pr_error.ip_init_crc_error              = pr_ctrl_io.inp2prc_pg_pr_error[1];
assign fme_csr_fme_pr_error_update.fme_pr_error.host_init_operation_error      = pr_ctrl_io.inp2prc_pg_pr_error[0];
// PR Dummy Registers to fill DFH addressing gap---------------------------------------------------------------------
assign fme_csr_dummy_5028_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5028_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5030_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5030_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5038_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5038_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5040_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5040_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5048_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5048_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5050_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5050_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5058_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5058_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5060_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5060_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5068_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5068_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5070_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5070_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5078_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5078_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5080_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5080_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5088_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5088_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5090_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5090_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5098_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_5098_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_50A0_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_50A0_update.data = 64'h0000_0000_0000_0000;
// PR Interface ID Registers-----------------------------------------------------------------------------------------
assign fme_csr_fme_pr_intfc_id_l_reset.data  = fme_csr_fme_pr_intfc_id_l_update.data;
assign fme_csr_fme_pr_intfc_id_l_update.data = fme_id_regs[FME_PR_IF_ID_L_IDX];
assign fme_csr_fme_pr_intfc_id_h_reset.data  = fme_csr_fme_pr_intfc_id_h_update.data;
assign fme_csr_fme_pr_intfc_id_h_update.data = fme_id_regs[FME_PR_IF_ID_H_IDX];

// PR Scratchpad Register--------------------------------------------------------------------------------------------
assign pg_csr_pr_scratchpad_reset.data    = 64'h0000_0000_0000_0000;
assign pg_csr_pr_scratchpad_update.data   = 64'h0000_0000_0000_0000;

// Port DFH Register------------------------------------------------------------------------------------------------
assign port_csr_port_dfh_reset.data = port_csr_port_dfh_update.data; 
assign port_csr_port_dfh_update.port_dfh.feature_type    = 4'h4; 
assign port_csr_port_dfh_update.port_dfh.reserved        = {19{1'b0}}; 
assign port_csr_port_dfh_update.port_dfh.end_of_list     = 1'b0;
assign port_csr_port_dfh_update.port_dfh.next_dfh_offset = 24'h001000;          // Points to User Clock i.e. 0x92000 
assign port_csr_port_dfh_update.port_dfh.afu_maj_version = 4'h1; 
assign port_csr_port_dfh_update.port_dfh.corefim_version = 12'h001;
assign port_csr_port_afu_id_l_reset.data  = 64'h9642_B06C_6B35_5B87;
assign port_csr_port_afu_id_l_update.data = 64'h9642_B06C_6B35_5B87;
assign port_csr_port_afu_id_h_reset.data  = 64'h3AB4_9893_138D_42EB;
assign port_csr_port_afu_id_h_update.data = 64'h3AB4_9893_138D_42EB;
assign port_csr_first_afu_offset_reset.data = port_csr_first_afu_offset_update.data;
assign port_csr_first_afu_offset_update.first_afu_offset.reserved         = {40{1'b0}};
assign port_csr_first_afu_offset_update.first_afu_offset.first_afu_offset = 24'h0;      // WAS 24'h040000;
assign port_csr_port_mailbox_reset.data  = 64'h0000_0000_0000_0000;
assign port_csr_port_mailbox_update.data = 64'h0000_0000_0000_0000;
assign port_csr_port_scratchpad0_reset.data  = 64'h0000_0000_0000_0000;
assign port_csr_port_scratchpad0_update.data = 64'h0000_0000_0000_0000;

// Port Capability -----------------------------------------------------------
assign port_csr_port_capability_reset.data = port_csr_port_capability_update.data;
assign port_csr_port_capability_update.port_capability.reserved36   = {28{1'b0}};
assign port_csr_port_capability_update.port_capability.num_supp_int = 4'd4;
assign port_csr_port_capability_update.port_capability.reserved24   = {8{1'b0}};
assign port_csr_port_capability_update.port_capability.mmio_size    = 16'h0100;
assign port_csr_port_capability_update.port_capability.reserved0    = {8{1'b0}};

// Port Control --------------------------------------------------------------
assign port_csr_port_control_reset.data = port_csr_port_control_update.data;
assign port_csr_port_control_update.port_control.reserved5           = {59{1'b0}};
assign port_csr_port_control_update.port_control.port_soft_reset_ack = i_port_ctrl[4];  // WAS port_io.inp2cr_port_control[4];
assign port_csr_port_control_update.port_control.flr_port_reset      = i_port_ctrl[3];  // WAS port_io.inp2cr_port_control[3];
assign port_csr_port_control_update.port_control.latency_tolerance   = 1'b1;
assign port_csr_port_control_update.port_control.reserved1           = 1'b0;
assign port_csr_port_control_update.port_control.port_soft_reset     = 1'b1;

// Port Status ---------------------------------------------------------------
assign port_csr_port_status_reset.data = port_csr_port_status_update.data;
assign port_csr_port_status_update.port_status.reserved1   = {63{1'b0}};
assign port_csr_port_status_update.port_status.port_freeze = i_pr_freeze;         // WAS port_io.inp2cr_port_status[0];

// User Clock DFH Register-------------------------------------------------------------------------------------------------
assign pg_csr_user_clk_dfh_reset.data                           = pg_csr_user_clk_dfh_update.data;
assign pg_csr_user_clk_dfh_update.user_clk_dfh.FeatureType      = 4'h3;
assign pg_csr_user_clk_dfh_update.user_clk_dfh.Reserved41       = {18{1'b0}};
assign pg_csr_user_clk_dfh_update.user_clk_dfh.EOL              = 1'b0;
assign pg_csr_user_clk_dfh_update.user_clk_dfh.NextDfhOffset    = 24'h00_1000;    // Offset to 0x09_3000 
assign pg_csr_user_clk_dfh_update.user_clk_dfh.CciMinorRev      = USER_CLK_MINOR_REV;
assign pg_csr_user_clk_dfh_update.user_clk_dfh.CciVersion       = 12'h14;

// User Clock Freq CMD0 Register-------------------------------------------------------------------------------------------------
assign pg_csr_user_clk_freq_cmd0_reset.data                                     = 64'h0;
assign pg_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.Reserved4            = 6'h0; 
assign pg_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.UsrClkCmdPllRst      = 1'h0;
assign pg_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.UsrClkCmdPllMgmtRst  = 1'h0;
assign pg_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.Reserved3            = 3'h0;
assign pg_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.UsrClkCmdMmRst       = 1'h0;  
assign pg_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.Reserved2            = 2'h0;
assign pg_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.UsrClkCmdSeq         = 2'h0;
assign pg_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.Reserved1            = 3'h0;
assign pg_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.UsrClkCmdWr          = 1'h0;
assign pg_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.Reserved0            = 2'h0;
assign pg_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.UsrClkCmdAdr         = 10'h0;
assign pg_csr_user_clk_freq_cmd0_update.user_clk_freq_cmd0.UsrClkCmdDat         = 32'h0;

// User Clock Freq CMD1 Register-------------------------------------------------------------------------------------------------
assign pg_csr_user_clk_freq_cmd1_reset.data                                 = 64'h0;
assign pg_csr_user_clk_freq_cmd1_update.user_clk_freq_cmd1.Reserved1        = 31'h0; 
assign pg_csr_user_clk_freq_cmd1_update.user_clk_freq_cmd1.FreqCntrClkSel   = 1'h0; 
assign pg_csr_user_clk_freq_cmd1_update.user_clk_freq_cmd1.Reserved0        = 32'h0; 

// User Clock Freq STS0 Register-------------------------------------------------------------------------------------------------
assign pg_csr_user_clk_freq_sts0_reset.data     = 64'h0;
assign pg_csr_user_clk_freq_sts0_update.data    = user_clk_freq_sts_0;

// User Clock Freq STS1 Register-------------------------------------------------------------------------------------------------
assign pg_csr_user_clk_freq_sts1_reset.data     = 64'h0;
assign pg_csr_user_clk_freq_sts1_update.data    = user_clk_freq_sts_1;

// Port STP DFH --------------------------------------------------------------
assign port_csr_port_stp_dfh_reset.data = port_csr_port_stp_dfh_update.data; 
assign port_csr_port_stp_dfh_update.dfh.feature_type    = 4'h3; 
assign port_csr_port_stp_dfh_update.dfh.reserved        = {19{1'b0}}; 
assign port_csr_port_stp_dfh_update.dfh.end_of_list     = END_OF_LIST;
assign port_csr_port_stp_dfh_update.dfh.next_dfh_offset = NEXT_DFH_OFFSET - PORT_STP_DFH;    // Offset to 0x0A_0000
assign port_csr_port_stp_dfh_update.dfh.feature_rev     = 4'h2; 
assign port_csr_port_stp_dfh_update.dfh.feature_id      = 12'h013; 

// Port STP Status -----------------------------------------------------------
assign port_csr_port_stp_status_reset.data  = port_csr_port_stp_status_update.data;
assign port_csr_port_stp_status_update.data = i_remotestp_status;                           // WAS port_io.inp2cr_port_stp_status;

//----------------------------------------------------------------------------
// Outputs into the CSR Interface for distribution.
//----------------------------------------------------------------------------
assign pr_ctrl_io.prc2out_pg_pr_ctrl   = csr_reg[PG_PR_CTRL[14:12]][PG_PR_CTRL[7:3]];
assign pr_ctrl_io.prc2out_pg_pr_status = csr_reg[PG_PR_STATUS[14:12]][PG_PR_STATUS[7:3]];
assign pr_ctrl_io.prc2out_pg_pr_data   = csr_reg[PG_PR_DATA[14:12]][PG_PR_DATA[7:3]];

// csr_reg updates +1 clk after csr_write
assign pr_ctrl_io.prc2out_pg_pr_data_v = csr_write[PG_PR_DATA[14:12]][PG_PR_DATA[7:3]] && b_ready_valid;  // WAS wr_state[WRITE_COMPLETE_BIT];

// PORT CONTROL
assign o_port_ctrl  = csr_reg[PORT_CONTROL[14:12]][PORT_CONTROL[7:3]];

//-------------------------------------------------------------------------------------------------------------------
// Register Output Breakout Structure Overlays/Maps.
//-------------------------------------------------------------------------------------------------------------------
//assign pg_csr_pr_error.data   = csr_reg[PG_PR_ERROR[14:12]][PG_PR_ERROR[7:3]];

//----------------------------------------------------------------------------
// Register Update Logic using "update_reg" function in "ofs_csr_pkg.sv"
// SystemVerilog package.  Function inputs are "named" for ease of
// understanding the use.
//     - Register bit attributes are set in array input above.  Attribute
//       functions are defined in SAS.
//     - Reset Value is appied at reset except for RO, *D, and Rsvd{Z}.
//     - Update Value is used as status bit updates for RO, RW1C*, and RW1S*.
//     - Current Value is used to determine next register value.  This must be
//       done due to scoping rules using SystemVerilog package.
//     - "Write" is the decoded write signal for that particular register.
//     - State is a hardware state structure to pass input signals to
//       "update_reg" function.  See just above.
//----------------------------------------------------------------------------
always_ff @ ( posedge clk )
begin
   csr_reg[PG_PR_DFH[14:12]][PG_PR_DFH[7:3]]    <= update_reg(
                                                   // [63:60]: Feature Type
                                                   // [59:52]: Reserved
                                                   // [51:48]: If AFU - AFU Minor Revision Number (else, reserved)
                                                   // [47:41]: Reserved
                                                   // [   40]: EOL (End of DFH list)
                                                   // [39:16]: Next DFH Byte Offset
                                                   // [15:12]: If AfU, AFU Major version number (else feature #)
                                                   // [11: 0]: Feature ID
                                                      .attr            (fme_pr_dfh_attr.data),
                                                      .reg_reset_val   (fme_csr_fme_pr_dfh_reset.data),
                                                      .reg_update_val  (fme_csr_fme_pr_dfh_update.data),
                                                      .reg_current_val (csr_reg[PG_PR_DFH[14:12]][PG_PR_DFH[7:3]]),
                                                      .write           (csr_write[PG_PR_DFH[14:12]][PG_PR_DFH[7:3]]),
                                                      .state           (hw_state)
                                                      );

   csr_reg[PG_PR_CTRL[14:12]][PG_PR_CTRL[7:3]] <= update_reg(
                                                   // [63:32]: TBD/Config Data
                                                   // [31:15]: Reserved
                                                   // [   14]: PRKind. 0: Load customer GBS, 1: Load Intel GBS
                                                   // [   13]: PRDataPushComplete
                                                   // [   12]: PRStartRequest 
                                                   // [11:10]: Reserved
                                                   // [ 9: 8]: PRRegionId
                                                   // [ 7: 5]: Reserved
                                                   // [    4]: PRResetAck
                                                   // [ 3: 1]: Reserved
                                                   // [    0]: PRReset
                                                      .attr               (fme_pr_ctrl_attr.data),
                                                      .reg_reset_val      (fme_csr_fme_pr_ctrl_reset.data),
                                                      .reg_update_val     (fme_csr_fme_pr_ctrl_update.data),
                                                      .reg_current_val    (csr_reg[PG_PR_CTRL[14:12]][PG_PR_CTRL[7:3]]),
                                                      .write              (csr_write[PG_PR_CTRL[14:12]][PG_PR_CTRL[7:3]]),
                                                      .state              (hw_state)
                                                   );

   csr_reg[PG_PR_STATUS[14:12]][PG_PR_STATUS[7:3]] <= update_reg(
                                                   // [63:32]: SecurityBlockStatus (TBD)
                                                   // [31:28]: Reserved
                                                   // [27:24]: PRHostStatus
                                                   // [   23]: Reserved
                                                   // [22:20]: AlteraPRCrtlrStatus
                                                   // [   17]: Reserved
                                                   // [   16]: PRStatus
                                                   // [15: 9]: Reserved
                                                   // [ 8: 0]: NumbCredits
                                                      .attr               (fme_pr_status_attr.data),
                                                      .reg_reset_val      (fme_csr_fme_pr_status_reset.data),
                                                      .reg_update_val     (fme_csr_fme_pr_status_update.data),
                                                      .reg_current_val    (csr_reg[PG_PR_STATUS[14:12]][PG_PR_STATUS[7:3]]),
                                                      .write              (csr_write[PG_PR_STATUS[14:12]][PG_PR_STATUS[7:3]]),
                                                      .state              (hw_state)
                                                   );

   csr_reg[PG_PR_DATA[14:12]][PG_PR_DATA[7:3]]     <= update_reg(
                                                      .attr               (fme_pr_data_attr.data),
                                                      .reg_reset_val      (fme_csr_fme_pr_data_reset.data),
                                                      .reg_update_val     (fme_csr_fme_pr_data_update.data),
                                                      .reg_current_val    (csr_reg[PG_PR_DATA[14:12]][PG_PR_DATA[7:3]]),
                                                      .write              (csr_write[PG_PR_DATA[14:12]][PG_PR_DATA[7:3]]),
                                                      .state              (hw_state)
                                                   );

   csr_reg[PG_PR_ERROR[14:12]][PG_PR_ERROR[7:3]]   <= update_reg(
                                                   // [63: 7]: Reserved
                                                   // [    6]: Secure Load Failed
                                                   // [    5]: Host Init TImeout
                                                   // [    4]: Host Init Fifo Overflow
                                                   // [    3]: IP Init Protocol Error
                                                   // [    2]: IP Init Incompatible Bitstream
                                                   // [    1]: IP Init CRC Error
                                                   // [    0]: Host Init Operation Error 
                                                      .attr               (fme_pr_error_attr.data),
                                                      .reg_reset_val      (fme_csr_fme_pr_error_reset.data),
                                                      .reg_update_val     (fme_csr_fme_pr_error_update.data),
                                                      .reg_current_val    (csr_reg[PG_PR_ERROR[14:12]][PG_PR_ERROR[7:3]]),
                                                      .write              (csr_write[PG_PR_ERROR[14:12]][PG_PR_ERROR[7:3]]),
                                                      .state              (hw_state)
                                                   );



   csr_reg[PG_DUMMY_5028[14:12]][PG_DUMMY_5028[7:3]]  <= update_reg(.attr     (dummy_5028_attr.data),
                                                      .reg_reset_val      (fme_csr_dummy_5028_reset.data),
                                                      .reg_update_val     (fme_csr_dummy_5028_update.data),
                                                      .reg_current_val    (csr_reg[PG_DUMMY_5028[14:12]][PG_DUMMY_5028[7:3]]),
                                                      .write              (csr_write[PG_DUMMY_5028[14:12]][PG_DUMMY_5028[7:3]]),
                                                      .state              (hw_state)
                                                   );

   csr_reg[PG_DUMMY_5030[14:12]][PG_DUMMY_5030[7:3]]  <= update_reg(.attr     (dummy_5030_attr.data),
                                                      .reg_reset_val      (fme_csr_dummy_5030_reset.data),
                                                      .reg_update_val     (fme_csr_dummy_5030_update.data),
                                                      .reg_current_val    (csr_reg[PG_DUMMY_5030[14:12]][PG_DUMMY_5030[7:3]]),
                                                      .write              (csr_write[PG_DUMMY_5030[14:12]][PG_DUMMY_5030[7:3]]),
                                                      .state              (hw_state)
                                                   );

   csr_reg[PG_DUMMY_5038[14:12]][PG_DUMMY_5038[7:3]]  <= update_reg(.attr     (dummy_5038_attr.data),
                                                      .reg_reset_val      (fme_csr_dummy_5038_reset.data),
                                                      .reg_update_val     (fme_csr_dummy_5038_update.data),
                                                      .reg_current_val    (csr_reg[PG_DUMMY_5038[14:12]][PG_DUMMY_5038[7:3]]),
                                                      .write              (csr_write[PG_DUMMY_5038[14:12]][PG_DUMMY_5038[7:3]]),
                                                      .state(hw_state)
                                                   );

   csr_reg[PG_DUMMY_5040[14:12]][PG_DUMMY_5040[7:3]]     <= update_reg(.attr     (dummy_5040_attr.data),
                                                      .reg_reset_val      (fme_csr_dummy_5040_reset.data),
                                                      .reg_update_val     (fme_csr_dummy_5040_update.data),
                                                      .reg_current_val    (csr_reg[PG_DUMMY_5040[14:12]][PG_DUMMY_5040[7:3]]),
                                                      .write              (csr_write[PG_DUMMY_5040[14:12]][PG_DUMMY_5040[7:3]]),
                                                      .state              (hw_state)
                                                   );

   csr_reg[PG_DUMMY_5048[14:12]][PG_DUMMY_5048[7:3]]     <= update_reg(.attr     (dummy_5048_attr.data),
                                                      .reg_reset_val      (fme_csr_dummy_5048_reset.data),
                                                      .reg_update_val     (fme_csr_dummy_5048_update.data),
                                                      .reg_current_val    (csr_reg[PG_DUMMY_5048[14:12]][PG_DUMMY_5048[7:3]]),
                                                      .write              (csr_write[PG_DUMMY_5048[14:12]][PG_DUMMY_5048[7:3]]),
                                                      .state(hw_state)
                                                   );

   csr_reg[PG_DUMMY_5050[14:12]][PG_DUMMY_5050[7:3]] <= update_reg(.attr     (dummy_5050_attr.data),
                                                      .reg_reset_val      (fme_csr_dummy_5050_reset.data),
                                                      .reg_update_val     (fme_csr_dummy_5050_update.data),
                                                      .reg_current_val    (csr_reg[PG_DUMMY_5050[14:12]][PG_DUMMY_5050[7:3]]),
                                                      .write              (csr_write[PG_DUMMY_5050[14:12]][PG_DUMMY_5050[7:3]]),
                                                      .state              (hw_state)
                                                   );

   csr_reg[PG_DUMMY_5058[14:12]][PG_DUMMY_5058[7:3]] <= update_reg(.attr     (dummy_5058_attr.data),
                                                      .reg_reset_val      (fme_csr_dummy_5058_reset.data),
                                                      .reg_update_val     (fme_csr_dummy_5058_update.data),
                                                      .reg_current_val    (csr_reg[PG_DUMMY_5058[14:12]][PG_DUMMY_5058[7:3]]),
                                                      .write              (csr_write[PG_DUMMY_5058[14:12]][PG_DUMMY_5058[7:3]]),
                                                      .state              (hw_state)
                                                   );

   csr_reg[PG_DUMMY_5060[14:12]][PG_DUMMY_5060[7:3]] <= update_reg(.attr     (dummy_5060_attr.data),
                                                      .reg_reset_val      (fme_csr_dummy_5060_reset.data),
                                                      .reg_update_val     (fme_csr_dummy_5060_update.data),
                                                      .reg_current_val    (csr_reg[PG_DUMMY_5060[14:12]][PG_DUMMY_5060[7:3]]),
                                                      .write              (csr_write[PG_DUMMY_5060[14:12]][PG_DUMMY_5060[7:3]]),
                                                      .state              (hw_state)
                                                   );

   csr_reg[PG_DUMMY_5068[14:12]][PG_DUMMY_5068[7:3]] <= update_reg(.attr     (dummy_5068_attr.data),
                                                      .reg_reset_val      (fme_csr_dummy_5068_reset.data),
                                                      .reg_update_val     (fme_csr_dummy_5068_update.data),
                                                      .reg_current_val    (csr_reg[PG_DUMMY_5068[14:12]][PG_DUMMY_5068[7:3]]),
                                                      .write              (csr_write[PG_DUMMY_5068[14:12]][PG_DUMMY_5068[7:3]]),
                                                      .state              (hw_state)
                                                   );

   csr_reg[PG_DUMMY_5070[14:12]][PG_DUMMY_5070[7:3]] <= update_reg(.attr     (dummy_5070_attr.data),
                                                      .reg_reset_val      (fme_csr_dummy_5070_reset.data),
                                                      .reg_update_val     (fme_csr_dummy_5070_update.data),
                                                      .reg_current_val    (csr_reg[PG_DUMMY_5070[14:12]][PG_DUMMY_5070[7:3]]),
                                                      .write              (csr_write[PG_DUMMY_5070[14:12]][PG_DUMMY_5070[7:3]]),
                                                      .state              (hw_state)
                                                   );

   csr_reg[PG_DUMMY_5078[14:12]][PG_DUMMY_5078[7:3]]     <= update_reg(.attr     (dummy_5078_attr.data),
                                                      .reg_reset_val      (fme_csr_dummy_5078_reset.data),
                                                      .reg_update_val     (fme_csr_dummy_5078_update.data),
                                                      .reg_current_val    (csr_reg[PG_DUMMY_5078[14:12]][PG_DUMMY_5078[7:3]]),
                                                      .write              (csr_write[PG_DUMMY_5078[14:12]][PG_DUMMY_5078[7:3]]),
                                                      .state              (hw_state)
                                                   );

   csr_reg[PG_DUMMY_5080[14:12]][PG_DUMMY_5080[7:3]] <= update_reg(.attr     (dummy_5080_attr.data),
                                                      .reg_reset_val      (fme_csr_dummy_5080_reset.data),
                                                      .reg_update_val     (fme_csr_dummy_5080_update.data),
                                                      .reg_current_val    (csr_reg[PG_DUMMY_5080[14:12]][PG_DUMMY_5080[7:3]]),
                                                      .write              (csr_write[PG_DUMMY_5080[14:12]][PG_DUMMY_5080[7:3]]),
                                                      .state              (hw_state)
                                                   );

   csr_reg[PG_DUMMY_5088[14:12]][PG_DUMMY_5088[7:3]] <= update_reg(.attr     (dummy_5088_attr.data),
                                                      .reg_reset_val      (fme_csr_dummy_5088_reset.data),
                                                      .reg_update_val     (fme_csr_dummy_5088_update.data),
                                                      .reg_current_val    (csr_reg[PG_DUMMY_5088[14:12]][PG_DUMMY_5088[7:3]]),
                                                      .write              (csr_write[PG_DUMMY_5088[14:12]][PG_DUMMY_5088[7:3]]),
                                                      .state              (hw_state)
                                                   );

   csr_reg[PG_DUMMY_5090[14:12]][PG_DUMMY_5090[7:3]] <= update_reg(.attr     (dummy_5090_attr.data),
                                                      .reg_reset_val      (fme_csr_dummy_5090_reset.data),
                                                      .reg_update_val     (fme_csr_dummy_5090_update.data),
                                                      .reg_current_val    (csr_reg[PG_DUMMY_5090[14:12]][PG_DUMMY_5090[7:3]]),
                                                      .write              (csr_write[PG_DUMMY_5090[14:12]][PG_DUMMY_5090[7:3]]),
                                                      .state              (hw_state)
                                                   );

   csr_reg[PG_DUMMY_5098[14:12]][PG_DUMMY_5098[7:3]] <= update_reg(.attr     (dummy_5098_attr.data),
                                                      .reg_reset_val      (fme_csr_dummy_5098_reset.data),
                                                      .reg_update_val     (fme_csr_dummy_5098_update.data),
                                                      .reg_current_val    (csr_reg[PG_DUMMY_5098[14:12]][PG_DUMMY_5098[7:3]]),
                                                      .write              (csr_write[PG_DUMMY_5098[14:12]][PG_DUMMY_5098[7:3]]),
                                                      .state              (hw_state)
                                                   );

   csr_reg[PG_DUMMY_50A0[14:12]][PG_DUMMY_50A0[7:3]] <= update_reg(.attr     (dummy_50a0_attr.data),
                                                      .reg_reset_val      (fme_csr_dummy_50A0_reset.data),
                                                      .reg_update_val     (fme_csr_dummy_50A0_update.data),
                                                      .reg_current_val    (csr_reg[PG_DUMMY_50A0[14:12]][PG_DUMMY_50A0[7:3]]),
                                                      .write              (csr_write[PG_DUMMY_50A0[14:12]][PG_DUMMY_50A0[7:3]]),
                                                      .state(hw_state)
                                                   );

   csr_reg[PG_PR_INTFC_ID_L[14:12]][PG_PR_INTFC_ID_L[7:3]]  <= update_reg(.attr (fme_pr_intfc_id_l_attr.data),
                                                               .reg_reset_val  (fme_csr_fme_pr_intfc_id_l_reset.data),
                                                               .reg_update_val (fme_csr_fme_pr_intfc_id_l_update.data),
                                                               .reg_current_val(csr_reg[PG_PR_INTFC_ID_L[14:12]][PG_PR_INTFC_ID_L[7:3]]),
                                                               .write          (csr_write[PG_PR_INTFC_ID_L[14:12]][PG_PR_INTFC_ID_L[7:3]]),
                                                               .state          (hw_state)
                                                            );

   csr_reg[PG_PR_INTFC_ID_H[14:12]][PG_PR_INTFC_ID_H[7:3]] <= update_reg(.attr  (fme_pr_intfc_id_h_attr.data),
                                                               .reg_reset_val  (fme_csr_fme_pr_intfc_id_h_reset.data),
                                                               .reg_update_val (fme_csr_fme_pr_intfc_id_h_update.data),
                                                               .reg_current_val(csr_reg[PG_PR_INTFC_ID_H[14:12]][PG_PR_INTFC_ID_H[7:3]]),
                                                               .write          (csr_write[PG_PR_INTFC_ID_H[14:12]][PG_PR_INTFC_ID_H[7:3]]),
                                                               .state          (hw_state)
                                                            );

   csr_reg[PG_SCRATCHPAD[14:12]][PG_SCRATCHPAD[7:3]]   <= update_reg(
                                                            .attr            (PG_SCRATCHPAD_ATTR),
                                                            .reg_reset_val   (pg_csr_pr_scratchpad_reset.data),
                                                            .reg_update_val  (pg_csr_pr_scratchpad_update.data),
                                                            .reg_current_val (csr_reg[PG_SCRATCHPAD[14:12]][PG_SCRATCHPAD[7:3]]),
                                                            .write           (csr_write[PG_SCRATCHPAD[14:12]][PG_SCRATCHPAD[7:3]]),
                                                            .state           (hw_state)
                                                         ); 

   csr_reg[PORT_DFH[14:12]][PORT_DFH[7:3]] <= update_reg(
                                                   // [63:60]: Feature Type
                                                   // [59:52]: Reserved
                                                   // [51:48]: If AFU - AFU Minor Revision Number (else, reserved)
                                                   // [47:41]: Reserved
                                                   // [   40]: EOL (End of DFH list)
                                                   // [39:16]: Next DFH Byte Offset
                                                   // [15:12]: If AfU, AFU Major version number (else feature #)
                                                   // [11: 0]: Feature ID
                                                         .attr            (port_dfh_attr.data),
                                                         .reg_reset_val   (port_csr_port_dfh_reset.data),
                                                         .reg_update_val  (port_csr_port_dfh_update.data),
                                                         .reg_current_val (csr_reg[PORT_DFH[14:12]][PORT_DFH[7:3]]),
                                                         .write           (csr_write[PORT_DFH[14:12]][PORT_DFH[7:3]]),
                                                         .state           (hw_state)
                                                      );

   csr_reg[PORT_AFU_ID_L[14:12]][PORT_AFU_ID_L[7:3]] <=   update_reg (
                                                                        .attr(port_afu_id_l_attr.data),
                                                                        .reg_reset_val   (port_csr_port_afu_id_l_reset.data),
                                                                        .reg_update_val  (port_csr_port_afu_id_l_update.data),
                                                                        .reg_current_val (csr_reg[PORT_AFU_ID_L[14:12]][PORT_AFU_ID_L[7:3]]),
                                                                        .write           (csr_write[PORT_AFU_ID_L[14:12]][PORT_AFU_ID_L[7:3]]),
                                                                        .state           (hw_state)
                                                                  );

   csr_reg[PORT_AFU_ID_H[14:12]][PORT_AFU_ID_H[7:3]] <=   update_reg (
                                                                     .attr            (port_afu_id_h_attr.data),
                                                                     .reg_reset_val   (port_csr_port_afu_id_h_reset.data),
                                                                     .reg_update_val  (port_csr_port_afu_id_h_update.data),
                                                                     .reg_current_val (csr_reg[PORT_AFU_ID_H[14:12]][PORT_AFU_ID_H[7:3]]),
                                                                     .write           (csr_write[PORT_AFU_ID_H[14:12]][PORT_AFU_ID_H[7:3]]),
                                                                     .state           (hw_state)
                                                                  );

   csr_reg[FIRST_AFU_OFFSET[14:12]][FIRST_AFU_OFFSET[7:3]] <=   update_reg (
                                                                           .attr            (first_afu_offset_attr.data),
                                                                           .reg_reset_val   (port_csr_first_afu_offset_reset.data),
                                                                           .reg_update_val  (port_csr_first_afu_offset_update.data),
                                                                           .reg_current_val (csr_reg[FIRST_AFU_OFFSET[14:12]][FIRST_AFU_OFFSET[7:3]]),
                                                                           .write           (csr_write[FIRST_AFU_OFFSET[14:12]][FIRST_AFU_OFFSET[7:3]]),
                                                                           .state           (hw_state)
                                                                        );

   csr_reg[PORT_MAILBOX[14:12]][PORT_MAILBOX[7:3]] <=  update_reg (
                                                                  .attr            (port_mailbox_attr.data),
                                                                  .reg_reset_val   (port_csr_port_mailbox_reset.data),
                                                                  .reg_update_val  (port_csr_port_mailbox_update.data),
                                                                  .reg_current_val (csr_reg[PORT_MAILBOX[14:12]][PORT_MAILBOX[7:3]]),
                                                                  .write           (csr_write[PORT_MAILBOX[14:12]][PORT_MAILBOX[7:3]]),
                                                                  .state           (hw_state)
                                                               );

   csr_reg[PORT_SCRATCHPAD0[14:12]][PORT_SCRATCHPAD0[7:3]] <=   update_reg (
                                                                           .attr            (port_scratchpad0_attr.data),
                                                                           .reg_reset_val   (port_csr_port_scratchpad0_reset.data),
                                                                           .reg_update_val  (port_csr_port_scratchpad0_update.data),
                                                                           .reg_current_val (csr_reg[PORT_SCRATCHPAD0[14:12]][PORT_SCRATCHPAD0[7:3]]),
                                                                           .write           (csr_write[PORT_SCRATCHPAD0[14:12]][PORT_SCRATCHPAD0[7:3]]),
                                                                           .state           (hw_state)
                                                                        );

   csr_reg[PORT_CAPABILITY[14:12]][PORT_CAPABILITY[7:3]] <=  update_reg (
                                                                        .attr            (port_capability_attr.data),
                                                                        .reg_reset_val   (port_csr_port_capability_reset.data),
                                                                        .reg_update_val  (port_csr_port_capability_update.data),
                                                                        .reg_current_val (csr_reg[PORT_CAPABILITY[14:12]][PORT_CAPABILITY[7:3]]),
                                                                        .write           (csr_write[PORT_CAPABILITY[14:12]][PORT_CAPABILITY[7:3]]),
                                                                        .state           (hw_state)
                                                                     );

   csr_reg[PORT_CONTROL[14:12]][PORT_CONTROL[7:3]] <=  update_reg (
                                                                  .attr            (port_control_attr.data),
                                                                  .reg_reset_val   (port_csr_port_control_reset.data),
                                                                  .reg_update_val  (port_csr_port_control_update.data),
                                                                  .reg_current_val (csr_reg[PORT_CONTROL[14:12]][PORT_CONTROL[7:3]]),
                                                                  .write           (csr_write[PORT_CONTROL[14:12]][PORT_CONTROL[7:3]]),
                                                                  .state           (hw_state)
                                                               );

   csr_reg[PORT_STATUS[14:12]][PORT_STATUS[7:3]] <= update_reg(
                                                               .attr            (port_status_attr.data),
                                                               .reg_reset_val   (port_csr_port_status_reset.data),
                                                               .reg_update_val  (port_csr_port_status_update.data),
                                                               .reg_current_val (csr_reg[PORT_STATUS[14:12]][PORT_STATUS[7:3]]),
                                                               .write           (csr_write[PORT_STATUS[14:12]][PORT_STATUS[7:3]]),
                                                               .state           (hw_state)
                                                            );

   csr_reg[PG_USER_CLK_DFH[14:12]][PG_USER_CLK_DFH[7:3]]   <= update_reg (
                                                      // [63:60]: Feature Type = Private
                                                      // [59:41]: Reserved41
                                                      // [   40]: EOL - End of DFH List
                                                      // [39:16]: Next DFH Byte Offset
                                                      // [15:12]: CCI-P Minor Revision
                                                      // [11: 0]: CCI-P Version #
                                                         .attr            (PG_USER_CLK_DFH_ATTR),
                                                         .reg_reset_val   (pg_csr_user_clk_dfh_reset.data),
                                                         .reg_update_val  (pg_csr_user_clk_dfh_update.data),
                                                         .reg_current_val (csr_reg[PG_USER_CLK_DFH[14:12]][PG_USER_CLK_DFH[7:3]]),
                                                         .write           (csr_write[PG_USER_CLK_DFH[14:12]][PG_USER_CLK_DFH[7:3]]),
                                                         .state           (hw_state)
                                                      ); 

   csr_reg[PG_USER_CLK_FREQ_CMD0[14:12]][PG_USER_CLK_FREQ_CMD0[7:3]]   <= update_reg(
                                                      // [63:58]: Reserved
                                                      // [   57]: IOPLL Reset
                                                      // [   56]: IOPLL Management Reset
                                                      // [55:53]: Reserved
                                                      // [   52]: AVMM Bridge State Machine Reset Machine (active low)
                                                      // [51:50]: Reserved
                                                      // [49:48]: IOPLL Reconfig Command Sequence Number
                                                      // [47:45]: Reserved
                                                      // [   44]: IOPLL Reconfig Command Write
                                                      // [43:42]: Reserved
                                                      // [41:32]: IOPLL Reconfig Command Address
                                                      // [31: 0]: IOPLL Reconfig Command Data
                                                         .attr            (PG_USER_CLK_FREQ_CMD0_ATTR),
                                                         .reg_reset_val   (pg_csr_user_clk_freq_cmd0_reset.data),
                                                         .reg_update_val  (pg_csr_user_clk_freq_cmd0_update.data),
                                                         .reg_current_val (csr_reg[PG_USER_CLK_FREQ_CMD0[14:12]][PG_USER_CLK_FREQ_CMD0[7:3]]),
                                                         .write           (csr_write[PG_USER_CLK_FREQ_CMD0[14:12]][PG_USER_CLK_FREQ_CMD0[7:3]]),
                                                         .state           (hw_state)
                                                      ); 

   csr_reg[PG_USER_CLK_FREQ_CMD1[14:12]][PG_USER_CLK_FREQ_CMD1[7:3]]   <= update_reg(
                                                      // [63:33]:    Reserved
                                                      // [   32]:    Clock to measure (0 - uClk_usr_Div2, 1 - uClk_usr)
                                                      // [31: 0]:    Reserved
                                                         .attr            (PG_USER_CLK_FREQ_CMD1_ATTR),
                                                         .reg_reset_val   (pg_csr_user_clk_freq_cmd1_reset.data),
                                                         .reg_update_val  (pg_csr_user_clk_freq_cmd1_update.data),
                                                         .reg_current_val (csr_reg[PG_USER_CLK_FREQ_CMD1[14:12]][PG_USER_CLK_FREQ_CMD1[7:3]]),
                                                         .write           (csr_write[PG_USER_CLK_FREQ_CMD1[14:12]][PG_USER_CLK_FREQ_CMD1[7:3]]),
                                                         .state           (hw_state)
                                                      ); 

   csr_reg[PG_USER_CLK_FREQ_STS0[14:12]][PG_USER_CLK_FREQ_STS0[7:3]]   <= update_reg(
                                                      // [   63]:    Avalon-mm bridge state machine error
                                                      // [62:61]:    Reserved
                                                      // [   60]:    IOPLL Locked
                                                      // [59:58]:    Reserved
                                                      // [   57]:    IOPLL reset
                                                      // [   56]:    IOPLL Management reset
                                                      // [55:53]:    Reserved
                                                      // [   52]:    Avalon-mm bridge state machine reset
                                                      // [51:50]:    Reserved
                                                      // [49:48]:    IOPLL reconfig command sequence number
                                                      // [47:45]:    Reserved
                                                      // [   44]:    IOPLL reconfig command write
                                                      // [43:42]:    Reserved
                                                      // [41:32]:    IOPLL reconfig command address
                                                      // [31: 0]:    IOPLL reconfig command read back data
                                                         .attr               (PG_USER_CLK_FREQ_STS0_ATTR),
                                                         .reg_reset_val      (pg_csr_user_clk_freq_sts0_reset.data),
                                                         .reg_update_val     (pg_csr_user_clk_freq_sts0_update.data),
                                                         .reg_current_val    (csr_reg[PG_USER_CLK_FREQ_STS0[14:12]][PG_USER_CLK_FREQ_STS0[7:3]]),
                                                         .write              (csr_write[PG_USER_CLK_FREQ_STS0[14:12]][PG_USER_CLK_FREQ_STS0[7:3]]),
                                                         .state              (hw_state)
                                                      ); 

   csr_reg[PG_USER_CLK_FREQ_STS1[14:12]][PG_USER_CLK_FREQ_STS1[7:3]]   <= update_reg(
                                                      // [63:60]:    Frequency counter version number
                                                      // [59:51]:    Reserved
                                                      // [50:33]:    PLL Reference Clock Frequency in 10kHz units.  For example, 100MHz = 10000 x 10 kHz >>> 10000 = 0x2710
                                                      // [   32]:    Clock that was measured (0 - uClk_usr_Div2, 1 - uClk_Usr)
                                                      // [31:17]:    Reserved
                                                      // [16: 0]:    Frequency in 10kHz units
                                                         .attr               (PG_USER_CLK_FREQ_STS1_ATTR),
                                                         .reg_reset_val      (pg_csr_user_clk_freq_sts1_reset.data),
                                                         .reg_update_val     (pg_csr_user_clk_freq_sts1_update.data),
                                                         .reg_current_val    (csr_reg[PG_USER_CLK_FREQ_STS1[14:12]][PG_USER_CLK_FREQ_STS1[7:3]]),
                                                         .write              (csr_write[PG_USER_CLK_FREQ_STS1[14:12]][PG_USER_CLK_FREQ_STS1[7:3]]),
                                                         .state              (hw_state)
                                                      ); 

   csr_reg[PORT_STP_DFH[14:12]][PORT_STP_DFH[7:3]] <=  update_reg (
                                                                  .attr            (port_stp_dfh_attr.data),
                                                                  .reg_reset_val   (port_csr_port_stp_dfh_reset.data),
                                                                  .reg_update_val  (port_csr_port_stp_dfh_update.data),
                                                                  .reg_current_val (csr_reg[PORT_STP_DFH[14:12]][PORT_STP_DFH[7:3]]),
                                                                  .write           (csr_write[PORT_STP_DFH[14:12]][PORT_STP_DFH[7:3]]),
                                                                  .state           (hw_state)
                                                               );

   csr_reg[PORT_STP_STATUS[14:12]][PORT_STP_STATUS[7:3]] <=  update_reg (
                                                                        .attr(port_stp_status_attr.data),
                                                                        .reg_reset_val   (port_csr_port_stp_status_reset.data),
                                                                        .reg_update_val  (port_csr_port_stp_status_update.data),
                                                                        .reg_current_val (csr_reg[PORT_STP_STATUS[14:12]][PORT_STP_STATUS[7:3]]),
                                                                        .write           (csr_write[PORT_STP_STATUS[14:12]][PORT_STP_STATUS[7:3]]),
                                                                        .state           (hw_state)
                                                                     );                                                       

end

endmodule 

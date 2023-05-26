// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// AXI-Mem traffic gen CSR 
//
//-----------------------------------------------------------------------------

import ofs_csr_pkg::*;
import tg_csr_pkg::*;

module mem_tg_csr #(
   parameter NUM_TG = 4
)(
   input logic 	           clk,
   input logic 	           rst_n,

   // interface to host
   ofs_avmm_if.sink        csr_if,

   // CSR I/O
   output t_csr_tg_ctrl       tg_ctrl,
   input  t_csr_tg_stat       tg_stat
);


localparam   END_OF_LIST           = 1'h1;  // Set this to 0 if there is another DFH beyond this
localparam   NEXT_DFH_BYTE_OFFSET  = 24'h0; // Next DFH Byte offset
   
// update_reg state
ofs_csr_hw_state_t hw_state;

logic range_valid;
logic csr_read_q;
logic [csr_if.ADDR_W-1:0] csr_address_q;


logic [CSR_REG_WIDTH-1:0] csr_reg   [MEM_TG_NUM_REGS-1:0];
logic                     csr_write [MEM_TG_NUM_REGS-1:0];

csr_tg_ctrl_t mem_tg_ctrl_current;
   
//----------------------------------------------------------------------------
// CSR CTRL output
//----------------------------------------------------------------------------
always_comb
begin
   mem_tg_ctrl_current.data = csr_reg[MEM_TG_CTRL>>CSR_ADDR_SHIFT];
   tg_ctrl = mem_tg_ctrl_current.csr_tg_ctrl.tg_ctrl;
end
   
//----------------------------------------------------------------------------
// CSR write
//----------------------------------------------------------------------------
always_comb
begin
   for (int csr_addr=0; csr_addr < MEM_TG_NUM_REGS; csr_addr++)
      if (csr_if.write && ((csr_if.address >> CSR_ADDR_SHIFT) == csr_addr))
         csr_write[csr_addr] = 1'b1;
      else
         csr_write[csr_addr] = 1'b0;
end

always_ff @(posedge clk) begin
   if(!rst_n) begin
      csr_if.writeresponsevalid <= 1'b0;
   end else begin
      // single cycle latency for non-posted wr
      csr_if.writeresponsevalid <= csr_if.write;
   end
end
   
//----------------------------------------------------------------------------
// CSR read
//----------------------------------------------------------------------------
// Delay reads by 1 cycle to avoid data contention on sequential wr->rd
always_ff @(posedge clk) begin
   csr_read_q    <= csr_if.read;
   csr_address_q <= csr_if.address;
   range_valid   <= ((csr_if.address >> CSR_ADDR_SHIFT) < MEM_TG_NUM_REGS) ? 1'b1 : 1'b0;
end


   
always_ff @(posedge clk) begin
   if(!rst_n) begin
      csr_if.readdata      <= 1'b0;
      csr_if.readdatavalid <= 1'b0;
      csr_if.waitrequest   <= 1'b1;
   end else begin
      // two cycle latency read
      csr_if.readdatavalid <= csr_read_q;
      csr_if.readdata      <= range_valid ? 
                              csr_reg[csr_address_q >> CSR_ADDR_SHIFT] : 64'b0;

      // fixed latency = no backpressure
      csr_if.waitrequest   <= 1'b0;
   end
end

//----------------------------------------------------------------------------
// CSR declarations
//----------------------------------------------------------------------------
csr_bit_attr_t [63:0] AFU_DFH_ATTR     = {{4{RO}},{19{RsvdZ}},{41{RO}} };
csr_bit_attr_t [63:0] AFU_ID_L_ATTR    = {64{RO}};
csr_bit_attr_t [63:0] AFU_ID_H_ATTR    = {64{RO}};
csr_bit_attr_t [63:0] AFU_RSVD_ATTR    = {64{RsvdZ} };
csr_bit_attr_t [63:0] AFU_NEXT_ATTR    = {{40{RsvdZ}}, {24{RO}} };
csr_bit_attr_t [63:0] SCRATCH_ATTR     = {64{RW} };
csr_bit_attr_t [63:0] TG_CTRL_ATTR     = {{(64-NUM_TG){RsvdZ}}, {NUM_TG{RW1C}} };
csr_bit_attr_t [63:0] TG_STAT_ATTR     = {{(64-(NUM_TG*$bits(t_tg_stat))){RsvdZ}}, 
                                          {(NUM_TG*$bits(t_tg_stat)){RO}} };

//----------------------------------------------------------------------------
// Register Reset/Update types
//----------------------------------------------------------------------------

// AFU DFH
afu_csr_dfh_t afu_dfh_update;

assign afu_dfh_update.afu_dfh.feature_type    = 4'h1;
assign afu_dfh_update.afu_dfh.reserved1       = {8{1'b0}};
assign afu_dfh_update.afu_dfh.afu_min_version = 3'h0;
assign afu_dfh_update.afu_dfh.reserved0       = {7{1'b0}};
assign afu_dfh_update.afu_dfh.end_of_list     = END_OF_LIST;
assign afu_dfh_update.afu_dfh.next_dfh_offset = NEXT_DFH_BYTE_OFFSET;
assign afu_dfh_update.afu_dfh.afu_maj_version = 4'h1;
assign afu_dfh_update.afu_dfh.feature_id      = 12'b0;

// AFU ID
afu_csr_afu_id_l_t afu_id_l_update;
afu_csr_afu_id_h_t afu_id_h_update;

assign afu_id_l_update.data = MEM_TG_ID_L;
assign afu_id_h_update.data = MEM_TG_ID_H;

// Reserved
ofs_csr_reg_generic_t afu_reserved_update;

assign afu_reserved_update.data = 64'h0000_0000_0000_0000;

// Next AFU 
ofs_csr_reg_generic_t afu_next_update;

assign afu_next_update.data = 64'h0000_0000_0000_0000;

   
// SCRATCHPAD
ofs_csr_reg_generic_t scratchpad_reset, scratchpad_update;

assign scratchpad_reset.data  = 64'h0000_0000_0000_0000;
assign scratchpad_update.data = csr_if.writedata;

// TG Control
csr_tg_ctrl_t mem_tg_ctrl_update;
assign mem_tg_ctrl_update.csr_tg_ctrl.tg_ctrl = { NUM_TG{1'b1} };
   
// TG Status
csr_tg_stat_t mem_tg_stat_update;
assign mem_tg_stat_update.csr_tg_stat.tg_stat = tg_stat;

always_comb begin
   hw_state.reset_n      = rst_n;
   hw_state.pwr_good_n   = 1'b0;
   hw_state.wr_data.data = csr_if.writedata;
   hw_state.write_type   = (csr_if.byteenable == 'hff) ? FULL64  :
                           (csr_if.byteenable == 'hf0) ? UPPER32 : LOWER32;
end

always_ff @(posedge clk) begin : csr_upd
   csr_reg[AFU_DFH_CSR>>CSR_ADDR_SHIFT]   <= update_reg (
                                             .attr            (AFU_DFH_ATTR),
                                             .reg_reset_val   (afu_dfh_update.data),
                                             .reg_update_val  (afu_dfh_update.data),
                                             .reg_current_val (csr_reg[AFU_DFH_CSR>>CSR_ADDR_SHIFT]),
                                             .write           (csr_write[AFU_DFH_CSR>>CSR_ADDR_SHIFT]),
                                             .state           (hw_state) );

   csr_reg[AFU_ID_L_CSR>>CSR_ADDR_SHIFT]  <= update_reg (
                                             .attr            (AFU_ID_L_ATTR),
                                             .reg_reset_val   (afu_id_l_update.data),
                                             .reg_update_val  (afu_id_l_update.data),
                                             .reg_current_val (csr_reg[AFU_ID_L_CSR>>CSR_ADDR_SHIFT]),
                                             .write           (csr_write[AFU_ID_L_CSR>>CSR_ADDR_SHIFT]),
                                             .state           (hw_state) );


   csr_reg[AFU_ID_H_CSR>>CSR_ADDR_SHIFT]  <= update_reg (
                                             .attr            (AFU_ID_H_ATTR),
                                             .reg_reset_val   (afu_id_h_update.data),
                                             .reg_update_val  (afu_id_h_update.data),
                                             .reg_current_val (csr_reg[AFU_ID_H_CSR>>CSR_ADDR_SHIFT]),
                                             .write           (csr_write[AFU_ID_H_CSR>>CSR_ADDR_SHIFT]),
                                             .state           (hw_state) );

   csr_reg[AFU_NEXT>>CSR_ADDR_SHIFT]      <= update_reg (
                                             .attr            (AFU_NEXT_ATTR),
                                             .reg_reset_val   (afu_next_update.data),
                                             .reg_update_val  (afu_next_update.data),
                                             .reg_current_val (csr_reg[AFU_NEXT>>CSR_ADDR_SHIFT]),
                                             .write           (csr_write[AFU_NEXT>>CSR_ADDR_SHIFT]),
                                             .state           (hw_state) );

   csr_reg[AFU_RSVD>>CSR_ADDR_SHIFT]      <= update_reg (
                                             .attr            (AFU_RSVD_ATTR),
                                             .reg_reset_val   (afu_reserved_update.data),
                                             .reg_update_val  (afu_reserved_update.data),
                                             .reg_current_val (csr_reg[AFU_RSVD>>CSR_ADDR_SHIFT]),
                                             .write           (csr_write[AFU_RSVD>>CSR_ADDR_SHIFT]),
                                             .state           (hw_state) );

   csr_reg[SCRATCHPAD>>CSR_ADDR_SHIFT]    <= update_reg (
                                             .attr            (SCRATCH_ATTR),
                                             .reg_reset_val   (scratchpad_reset.data),
                                             .reg_update_val  (scratchpad_update.data),
                                             .reg_current_val (csr_reg[SCRATCHPAD>>CSR_ADDR_SHIFT]),
                                             .write           (csr_write[SCRATCHPAD>>CSR_ADDR_SHIFT]),
                                             .state           (hw_state) );

   csr_reg[MEM_TG_CTRL>>CSR_ADDR_SHIFT]   <= update_reg (
                                             .attr            (TG_CTRL_ATTR),
                                             .reg_reset_val   (mem_tg_ctrl_update.data),
                                             .reg_update_val  (mem_tg_ctrl_update.data),
                                             .reg_current_val (csr_reg[MEM_TG_CTRL>>CSR_ADDR_SHIFT]),
                                             .write           (csr_write[MEM_TG_CTRL>>CSR_ADDR_SHIFT]),
                                             .state           (hw_state) );
   
   csr_reg[MEM_TG_STAT>>CSR_ADDR_SHIFT]   <= update_reg (
                                             .attr            (TG_STAT_ATTR),
                                             .reg_reset_val   (mem_tg_stat_update.data),
                                             .reg_update_val  (mem_tg_stat_update.data),
                                             .reg_current_val (csr_reg[MEM_TG_STAT>>CSR_ADDR_SHIFT]),
                                             .write           (csr_write[MEM_TG_STAT>>CSR_ADDR_SHIFT]),
                                             .state           (hw_state) );
end
   
endmodule


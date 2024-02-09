// Copyright (C) 2020 Intel Corporation.
// SPDX-License-Identifier: MIT

//
// Description
//-----------------------------------------------------------------------------
//
// This module tracks dynamic PCIe request tag size. 
// This state is valid only for PF0.
//
//-----------------------------------------------------------------------------

module ofs_fim_pcie_ss_tag_mode (

   input  logic                     fim_clk,
   input  logic                     fim_rst_n,
   
   input  logic                     csr_clk,
   input  logic                     csr_rst_n,

   //Ctrl Shadow ports
   input logic                     p0_ss_app_st_ctrlshadow_tvalid,
   input logic [39:0]              p0_ss_app_st_ctrlshadow_tdata,
   
   output pcie_ss_axis_pkg::t_pcie_tag_mode tag_mode
);


pcie_ss_axis_pkg::t_pcie_tag_mode     tag_mode_sync;
pcie_ss_axis_pkg::t_pcie_ctrl_shdw    ctrl_shdw_reg;

always_ff@(posedge csr_clk) begin
   if(~csr_rst_n) begin
      ctrl_shdw_reg.tvalid               <= '0;
   end else begin
      ctrl_shdw_reg.tvalid               <=  p0_ss_app_st_ctrlshadow_tvalid;
   end 

   ctrl_shdw_reg.tdata.pf_num            <=  p0_ss_app_st_ctrlshadow_tdata[2:0];
   ctrl_shdw_reg.tdata.vf_num            <=  p0_ss_app_st_ctrlshadow_tdata[13:3];
   ctrl_shdw_reg.tdata.vf_active         <=  p0_ss_app_st_ctrlshadow_tdata[14];
   ctrl_shdw_reg.tdata.tag_enable_10bit  <=  p0_ss_app_st_ctrlshadow_tdata[30];
   ctrl_shdw_reg.tdata.extended_tag      <=  p0_ss_app_st_ctrlshadow_tdata[29];
end

// Track dynamic PCIe request tag size. This state is valid only for PF0.
always_ff@(posedge csr_clk) begin
   // Always guarantee that the tag mode encoding is 1 hot
   if(~csr_rst_n) begin
      tag_mode_sync.tag_5bit  <= 1'b1;
      tag_mode_sync.tag_8bit  <= 1'b0;
      tag_mode_sync.tag_10bit <= 1'b0;
   end else if(ctrl_shdw_reg.tvalid && ctrl_shdw_reg.tdata.pf_num == 3'b0 &&
               !ctrl_shdw_reg.tdata.vf_active) begin
      if(ctrl_shdw_reg.tdata.extended_tag && ctrl_shdw_reg.tdata.tag_enable_10bit) begin
         // PCIe extended, with 10 bit tags
         tag_mode_sync.tag_5bit  <= 1'b0;
         tag_mode_sync.tag_8bit  <= 1'b0;
         tag_mode_sync.tag_10bit <= 1'b1;
      end else if (ctrl_shdw_reg.tdata.extended_tag) begin
         // PCIe extended, without 10 bit tags
         tag_mode_sync.tag_5bit  <= 1'b0;
         tag_mode_sync.tag_8bit  <= 1'b1;
         tag_mode_sync.tag_10bit <= 1'b0;
      end else begin
         // Not extended -- old 5 bit tag mode
         tag_mode_sync.tag_5bit  <= 1'b1;
         tag_mode_sync.tag_8bit  <= 1'b0;
         tag_mode_sync.tag_10bit <= 1'b0;
      end 
   end
end

localparam CSR_STAT_SYNC_WIDTH = 3;
fim_resync #(
   .SYNC_CHAIN_LENGTH(3),
   .WIDTH(CSR_STAT_SYNC_WIDTH),
   .INIT_VALUE(0),
   .NO_CUT(1)
) csr_resync (
   .clk   (fim_clk),
   .reset (1'b0),
   .d     (tag_mode_sync),
   .q     (tag_mode)
);

endmodule

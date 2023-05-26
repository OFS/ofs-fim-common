// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT
//
// Description
//-----------------------------------------------------------------------------
//
// Control the AFU TX traffic going upstream
// Choose between i_tx_st_r4 and i_mmio_rsp depending on sel_mmio_rsp_rx
//
//-----------------------------------------------------------------------------

module port_traffic_control
import prtcl_chkr_pkg::*;
import pcie_ss_hdr_pkg::*;

(
   input  logic            clk,
   input  logic            rst_n,

   output logic            o_sel_mmio_rsp,
   output logic            o_read_flush_done,

   output logic            o_tx_f_fifo_valid_sop_cmpl,
   output logic [PCIE_TLP_TAG_WIDTH-1:0]  o_tx_f_fifo_rsp_tag,

   input  logic            i_blocking_traffic_fast,
   input  logic            i_tx_hdr_is_pu_mode_r0,
   pcie_ss_axis_if.sink    i_tx_st_r4,
   pcie_ss_axis_if.sink    i_mmio_rsp,

   pcie_ss_axis_if.source  o_tx_st
);

   pcie_ss_axis_if tx_fifo_st(.clk(clk), .rst_n(rst_n));

   //-------------------------
   // TX output arbitration
   //-------------------------
   pcie_ss_axis_if tx_st(.clk(clk), .rst_n(rst_n));
   logic tx_ready;

   PCIe_PUCplHdr_t                cpl_f_fifo_hdr;
   logic tx_f_fifo_valid_sop;
   logic tx_f_fifo_cpld;
   logic tx_f_fifo_cpl;
   logic tx_fifo_st_sop;


   // MMIO timeout response will only be sent
   // after the AFU traffic is blocked and the TX FIFO is flushed.
   // Below will mux between fake completions and real traffic
   always_comb begin
      if(o_sel_mmio_rsp) begin
         tx_st.tvalid        = i_mmio_rsp.tvalid;
         tx_st.tlast         = i_mmio_rsp.tlast;
         tx_st.tuser_vendor  = i_mmio_rsp.tuser_vendor;
         tx_st.tdata         = i_mmio_rsp.tdata;
         tx_st.tkeep         = i_mmio_rsp.tkeep;
         i_mmio_rsp.tready   = tx_st.tready;
         tx_fifo_st.tready   = 1'b0;
      end else begin
         tx_st.tvalid        = tx_fifo_st.tvalid;
         tx_st.tlast         = tx_fifo_st.tlast;
         tx_st.tuser_vendor  = tx_fifo_st.tuser_vendor;
         tx_st.tdata         = tx_fifo_st.tdata;
         tx_st.tkeep         = tx_fifo_st.tkeep;

         i_mmio_rsp.tready   = 1'b0;
         tx_fifo_st.tready   = tx_st.tready;
      end

      if (~rst_n) begin
         tx_st.tvalid = 1'b0;
      end
   end


   always_comb begin
      cpl_f_fifo_hdr       = tx_fifo_st.tdata[255:0];
      tx_f_fifo_valid_sop  = tx_fifo_st.tready & tx_fifo_st.tvalid & tx_fifo_st_sop;
      tx_f_fifo_cpld       = tx_f_fifo_valid_sop & (cpl_f_fifo_hdr.fmt_type == pcie_ss_hdr_pkg::PCIE_FMTTYPE_CPLD);
      tx_f_fifo_cpl        = tx_f_fifo_valid_sop & (cpl_f_fifo_hdr.fmt_type == pcie_ss_hdr_pkg::PCIE_FMTTYPE_CPL);
   end
   always_ff @(posedge clk) begin
      o_tx_f_fifo_valid_sop_cmpl <= tx_f_fifo_valid_sop & (tx_f_fifo_cpld | tx_f_fifo_cpl);
      o_tx_f_fifo_rsp_tag        <= { '0, cpl_f_fifo_hdr.tag_h, cpl_f_fifo_hdr.tag_m, cpl_f_fifo_hdr.tag_l };
   end
   
   axis_register #( .MODE(0), .TDATA_WIDTH(o_tx_st.DATA_W),
                    .ENABLE_TUSER(1), .TUSER_WIDTH(o_tx_st.USER_W)
   )
   axi_tx_stage (
     .clk       ( clk                  ),
     .rst_n     ( rst_n                ),
     .s_tready  ( tx_st.tready         ),
     .s_tvalid  ( tx_st.tvalid         ),
     .s_tdata   ( tx_st.tdata          ),
     .s_tkeep   ( tx_st.tkeep          ),
     .s_tlast   ( tx_st.tlast          ),
     .s_tid     (                      ),
     .s_tdest   (                      ),
     .s_tuser   ( tx_st.tuser_vendor   ),

     .m_tready  ( o_tx_st.tready       ),
     .m_tvalid  ( o_tx_st.tvalid       ),
     .m_tdata   ( o_tx_st.tdata        ),
     .m_tkeep   ( o_tx_st.tkeep        ),
     .m_tlast   ( o_tx_st.tlast        ),
     .m_tid     (                      ),
     .m_tdest   (                      ),
     .m_tuser   ( o_tx_st.tuser_vendor )
  );

   //-------------------------
   // AFU TX FIFO
   //-------------------------
   // Protocol checker guarantees that only legit AFU packets are sent upstream
   port_tx_fifo port_tx_fifo (
      .clk                     (clk),
      .rst_n                   (rst_n),
      .i_blocking_traffic_fast (i_blocking_traffic_fast),
      .i_tx_hdr_is_pu_mode_r0  (i_tx_hdr_is_pu_mode_r0),
      .i_tx_st_r4              (i_tx_st_r4),
      .ob_tx_valid_sop         (tx_fifo_st_sop),
      .o_tx_st                 (tx_fifo_st),
      .o_sel_mmio_rsp          (o_sel_mmio_rsp)
   );

   //-------------------
   // Pending traffic tracking
   //-------------------
   logic no_rd_pend;
   //assign o_read_flush_done = no_rd_pend;
   assign o_read_flush_done = 1'b1;
   
endmodule : port_traffic_control

// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT
//
// Description
//-----------------------------------------------------------------------------
//
// FIFO with store and forward capability to buffer AFU TX packets.
//
// AFU TLP is sent upstream only when the entire packet has been written
// into the FIFO. This will prevent incomplete TLP (due to malfunction AFU or AFU reset event)
// from going upstream.
//
// Write to the FIFO will be stalled when AFU error is detected or when AFU is reset.
//
//-----------------------------------------------------------------------------

module port_tx_fifo (
   input  logic                     clk,
   input  logic                     rst_n,
   input  logic                     i_blocking_traffic_fast,
   input  logic                     i_tx_hdr_is_pu_mode_r0,
   pcie_ss_axis_if.sink             i_tx_st_r4,
   output logic                     ob_tx_valid_sop,
   pcie_ss_axis_if.source           o_tx_st,
   output logic                     o_sel_mmio_rsp
);

   localparam TX_FIFO_DEPTH                = 32;
   localparam TX_FIFO_DEPTH_LOG2           = $clog2(TX_FIFO_DEPTH);
   localparam TX_FIFO_MAX_PIPELINE         = 8;
   localparam TX_FIFO_ALMFULL_THRESHOLD    = (TX_FIFO_DEPTH - TX_FIFO_MAX_PIPELINE);

   //-------------------------
   // Pipeline
   //-------------------------

   logic                          fifo_empty;
   logic                          nafull;
   logic                          wr_fifo;
   logic                          force_ob_valid_0;
   logic                          force_ob_valid_0_fast;
   logic [TX_FIFO_DEPTH_LOG2-1:0] trans_count;

   logic                          rd_fifo;

   logic                          ib_tx_valid;
   logic                          ob_tx_valid;

   logic                          ib_tx_valid_sop;
   logic                          ib_tx_valid_eop;
   logic                          ob_tx_valid_eop;

   logic                          ib_trans_in_progress;
   logic                          ob_trans_in_progress;

   logic                          module_reset_n;

   logic                          ib_trans_in_progress_real;
   logic                          ob_trans_in_progress_real;
   logic                          an_ib_tip;

   logic                          softreset_asserted; // softreset is not used
   logic                          softreset_qual;     // softreset is not used
   logic                          afu_softreset_r1;   // softreset is not used
   logic                          afu_softreset_r2;   // softreset is not used
   logic                          i_afu_softreset;    // softreset is not used

   logic                          valid_out_of_reset;
   logic                          waiting_for_last;
   logic                          module_reset_r1_n;

   // The following are debug waves only.
   logic [7:0]                    debug_count;
   logic [7:0]                    debug_count_out;
   logic                          tx_hdr_is_pu_mode_ff;
   logic                          tx_hdr_is_pu_mode_r1;
   logic                          tx_hdr_is_pu_mode_r2;
   logic                          tx_hdr_is_pu_mode_r3;
   logic                          tx_hdr_is_pu_mode_r4;

   always_ff @(posedge clk) begin
      if (~rst_n) begin
         debug_count <= 8'h0;
      end else begin
         debug_count <= debug_count + 8'h1;
      end
      if (i_tx_st_r4.tready) begin
         tx_hdr_is_pu_mode_r1 <= i_tx_hdr_is_pu_mode_r0;
         tx_hdr_is_pu_mode_r2 <= tx_hdr_is_pu_mode_r1;
         tx_hdr_is_pu_mode_r3 <= tx_hdr_is_pu_mode_r2;
         tx_hdr_is_pu_mode_r4 <= tx_hdr_is_pu_mode_r3;
      end
   end
   // End debug waves.
   
   // #################################################################
   // ### In Arrow Creek, We must never block traffic on softreset. ###
   // ### Setting softreset is part of the PF Flow.                 ###
   // #################################################################
   assign i_afu_softreset = 1'b0;

   always_ff @(posedge clk) begin
      afu_softreset_r1 <= i_afu_softreset;  // softreset is not used
      afu_softreset_r2 <= afu_softreset_r1; // softreset is not used

      if (~rst_n) begin
         softreset_asserted <= 1'b0; // softreset is not used
      end else if (afu_softreset_r1 & ~afu_softreset_r2) begin
         softreset_asserted <= 1'b1; // softreset is not used
      end
      softreset_qual <= softreset_asserted ? i_afu_softreset : 1'b0; // softreset is not used
   end

   always_ff @(posedge clk) begin
      module_reset_n    <= ~(~rst_n | force_ob_valid_0);
      o_sel_mmio_rsp   <= ~ob_trans_in_progress_real & fifo_empty;
      module_reset_r1_n <= module_reset_n;
      waiting_for_last <= valid_out_of_reset & ~(i_tx_st_r4.tlast & i_tx_st_r4.tvalid);
   end

   assign valid_out_of_reset = module_reset_n & ~module_reset_r1_n;

   always_comb begin
      ib_tx_valid     = i_tx_st_r4.tvalid & i_tx_st_r4.tready & ~valid_out_of_reset & ~waiting_for_last;
      ob_tx_valid     = o_tx_st.tvalid & o_tx_st.tready;

      ib_tx_valid_sop = ib_tx_valid & i_tx_st_r4.tvalid & i_tx_st_r4.tready & ~ib_trans_in_progress;
      ib_tx_valid_eop = ib_tx_valid & i_tx_st_r4.tlast  & i_tx_st_r4.tready;
      ob_tx_valid_sop = ob_tx_valid & o_tx_st.tvalid & o_tx_st.tready & ~ob_trans_in_progress;
      ob_tx_valid_eop = ob_tx_valid & o_tx_st.tlast  & o_tx_st.tready;
   end

   // Create transaction in progress signals. The "real" will include the "SOP" time
   always_ff @(posedge clk) begin
      if (~module_reset_n) begin  // Comming out of module_reset_n, we should only consider tx_valid_sop to begin a new transcation.
         ib_trans_in_progress <= 1'b0;
         ob_trans_in_progress <= 1'b0;
      end else begin
         ib_trans_in_progress <= ib_tx_valid_sop & ~ib_tx_valid_eop |
                                 ib_trans_in_progress & ~ib_tx_valid_eop;
         ob_trans_in_progress <= ob_tx_valid_sop & ~ob_tx_valid_eop |
                                 ob_trans_in_progress & ~ob_tx_valid_eop;
      end // else: !if(~module_reset_n)
   end // always @ (posedge clk)

   assign ib_trans_in_progress_real = ib_trans_in_progress | ib_tx_valid_sop;
   assign ob_trans_in_progress_real = ob_trans_in_progress | ob_tx_valid_sop;

   assign an_ib_tip      = ib_trans_in_progress_real;
   //write to the fifo whenever there is a transaction in progress (real) and there is a valid and a ready.
   assign wr_fifo        = an_ib_tip & ib_tx_valid & i_tx_st_r4.tready;

   // Keep the number of full transactions (including EOP) that are in the fifo. Only increment to 1 until EOP
   // so that we begin unloading only after the EOP (i.e. store and forward)
   always_ff @(posedge clk) begin
      i_tx_st_r4.tready <= nafull | ~module_reset_n; // Signal that we are not ready when we are almost full.
      if (~module_reset_n) begin
         trans_count <= {TX_FIFO_DEPTH_LOG2{1'b0}};
      end else begin
         case ({(ib_tx_valid_eop & an_ib_tip), ob_tx_valid_sop})
           2'b00: trans_count <= trans_count;
           2'b01: trans_count <= trans_count - 1;
           2'b10: trans_count <= trans_count + 1;
           2'b11: trans_count <= trans_count;
         endcase // case ({(ib_tx_valid_eop & an_ib_tip), ob_tx_valid_sop})
      end // else: !if(~module_reset_n)
   end // always_ff @ (posedge clk)

   // read the fifo only when there is a full transaction in the fifo. Including it's EOP. The transaction is drained by transaction in progress.
   assign rd_fifo = ~fifo_empty & o_tx_st.tready & ((trans_count > 8'b0) |
                                                    ob_trans_in_progress);

   // read the fifo only when there is a full transaction in the fifo. Including it's EOP. The transaction is drained by transaction in progress.

   //-------------------------
   // AFU TX FIFO
   //-------------------------
   bypass_fifo#(
                .DATA_WIDTH            (587 + 9),
                .ADDR_WIDTH            (TX_FIFO_DEPTH_LOG2),
                .AFULL_COUNT           (TX_FIFO_ALMFULL_THRESHOLD),
                .BYPASS                (1)
                ) tx_fifo (
                           .clk           (clk),
                           .reset_n       (module_reset_n),
                           // inputs
                           .write         (wr_fifo),
                           .write_data    ({tx_hdr_is_pu_mode_r4, debug_count, i_tx_st_r4.tlast, i_tx_st_r4.tuser_vendor, i_tx_st_r4.tdata, i_tx_st_r4.tkeep}),
                           .read          (rd_fifo),
                           //outputs
                           .read_data     ({tx_hdr_is_pu_mode_ff, debug_count_out, o_tx_st.tlast, o_tx_st.tuser_vendor, o_tx_st.tdata, o_tx_st.tkeep}),
                           .fifo_empty    (fifo_empty),
                           .nafull        (nafull),
                           .fifo_count    (),
                           .write_pointer (),
                           .read_pointer  ()
                           );

   // ############################
   // ### Output AXI-S Signals ###
   // ############################
   // This is where we force the valids to zero on a protocol error or a reset
   // This is only done at packet boundries (between EOP and SOP)
   always_comb begin
      if (force_ob_valid_0_fast | ~rd_fifo | ~module_reset_n) begin
         o_tx_st.tvalid         = '0;
      end else if (rd_fifo) begin
         o_tx_st.tvalid         = 1'b1;
      end else begin
         o_tx_st.tvalid         = 1'b0;
      end
   end // always_comb

   // force the valids to zero on a protocol error or a reset
   // This is only done at packet boundries (between EOP and SOP)
   always_ff @(posedge clk) begin
      if (~rst_n) begin // Comming out of module_reset_n, we should only consider tx_valid_sop to begin a new transcation.
         force_ob_valid_0 <=1'b0;
      end else begin
         // Assert force_ob_valid_0 only at a packet boundary
         // de-assertion can be any time. module_reset_n, SOP and trip work so wr_fifo only begin writing at SOP time,
         // never mid transaction, when comming out of module_reset_n.
         force_ob_valid_0 <= (i_blocking_traffic_fast | softreset_qual) & (|ob_tx_valid_eop) |         // softreset is not used
                             (i_blocking_traffic_fast | softreset_qual) & ~ob_trans_in_progress_real | // softreset is not used
                             force_ob_valid_0 & (i_blocking_traffic_fast | softreset_qual);            // softreset is not used
      end
   end
   assign force_ob_valid_0_fast = (i_blocking_traffic_fast & ~ob_trans_in_progress) | force_ob_valid_0;
   
   // synthesis translate_off
   always @(nafull) begin
      if (module_reset_n === 1'b1) begin
         $display("======================================================================================================");
         $display("T:%8d *** INFO: %m port_tx_fifo full changed state to: %b  ***", $time, ~nafull);
         $display("======================================================================================================");
      end
   end

   // these nets just provide debug in waves.
   import pcie_ss_hdr_pkg::*;

   always_ff @(posedge clk) begin
   end
   
   PCIe_PUCplHdr_t         input_pu_hdr_decode; 
   PCIe_CplHdr_t           input_dm_hdr_decode;
   PCIe_PUCplHdr_t         output_pu_hdr_decode; 
   PCIe_CplHdr_t           output_dm_hdr_decode;

   assign input_pu_hdr_decode = ( tx_hdr_is_pu_mode_r4 & i_tx_st_r4.tready) ? i_tx_st_r4.tdata : 'h0;
   assign input_dm_hdr_decode = (~tx_hdr_is_pu_mode_r4 & i_tx_st_r4.tready) ? i_tx_st_r4.tdata : 'h0;
   
   assign output_pu_hdr_decode = ( tx_hdr_is_pu_mode_ff & ob_tx_valid) ? o_tx_st.tdata : 'h0;
   assign output_dm_hdr_decode = (~tx_hdr_is_pu_mode_ff & ob_tx_valid) ? o_tx_st.tdata : 'h0;

   // synthesis translate_on
endmodule : port_tx_fifo

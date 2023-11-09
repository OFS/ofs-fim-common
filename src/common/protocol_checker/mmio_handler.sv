// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT
//
// mmio_timeout_err - AFU is not responding to a MMIO read request within the
//                    pre-defined response timeout period.
//
// unexp_mmio_rsp_err - AFU is sending a MMIO read response with no matching
//                      MMIO read request
//-----------------------------------------------------------------------------

module mmio_handler
import prtcl_chkr_pkg::*;
#(
   parameter NUM_TAGS_ADDR_WIDTH = $clog2(PCIE_RP_MAX_TAGS)
)
(
   input  logic                               clk,
   input  logic                               rst_n,
   input  logic                               i_rx_valid_sop_r1,
   input  logic                               i_rx_mrd_r1,
   input  logic [PCIE_TLP_TAG_WIDTH-1:0]      i_rx_req_tag_r1,
   input  logic [DW_LEN_WIDTH-1:0]            i_rx_req_dw0_len_r1,
   input  logic [PCIE_TLP_REQ_ID_WIDTH-1:0]   i_rx_requester_id_r1,
   input  logic [REQ_HDR_ADDR_WIDTH-1:0]      i_rx_rd_req_addr_r1,
   input  logic                               i_tx_valid_sop_r1, // for unexpected completion. From bus just comming into the protocol checker
   input  logic [PCIE_TLP_TAG_WIDTH-1:0]      i_tx_rsp_tag_r1,   // for unexpected completion
   input  logic                               i_tx_cpl_r1,       // for unexpected completion
   input  logic                               i_tx_cpld_r1,      // for unexpected completion

   // Validated packets coming from the tx_axi_packet_f_fifo
   input  logic                               i_tx_f_fifo_valid_sop_cmpl, // from output of port_tx_fifo
   input  logic [PCIE_TLP_TAG_WIDTH-1:0]      i_tx_f_fifo_rsp_tag,        // from output of port_tx_fifo

   output logic                               o_next_pending_mmio_rdy,
   output logic                               o_flush_mmio_rsp_queue_complete,
   input  logic                               i_blocking_traffic,
   input  logic                               i_mmio_rd_rsp_ack,
   output t_mmio_timeout_hdr_info             o_mmio_timeout_info,
   output logic                               o_mmio_timeout_err,
   output logic                               o_unexp_mmio_rsp_err
);

//import ofs_fim_if_pkg::*;
import ofs_fim_cfg_pkg::*;


   localparam ROLLING_CNTR_WIDTH          = 32;
   localparam ROLLING_CNTR_TRUNCATE_WIDTH = 2;
   localparam TIMESTAMP_WIDTH             = 32;
   localparam SYNC_DEPTH                  = 2;
   localparam SYNC_DEPTH_WIDTH            = SYNC_DEPTH**2;

   // Num Tags:        64
   // Timestamp Width: 64
   // 64 Entries of 64-bit timestamps
   logic [TIMESTAMP_WIDTH + MMIO_TIMEOUT_HDR_INFO_WIDTH - 1:0] timestamp_info_ram [PCIE_RP_MAX_TAGS-1:0];
   logic [TIMESTAMP_WIDTH-1:0]    timestamp_cntr, timestamp_cntr_r1;
   logic [MMIO_TIMEOUT_HDR_INFO_WIDTH-1:0] curr_idx_mmio_timeout_info;
   logic [PCIE_TLP_TAG_WIDTH-1:0] curr_idx_mmio_timeout_tag;
   t_mmio_timeout_hdr_info        curr_idx_mmio_timeout_info_r0, curr_idx_mmio_timeout_info_r1, curr_idx_mmio_timeout_info_r2, curr_idx_mmio_timeout_info_r3;
   t_mmio_timeout_hdr_info        mmio_timeout_info;
   logic [MMIO_TIMEOUT_HDR_INFO_WIDTH-1:0] rd_req_entry;
   logic [ROLLING_CNTR_WIDTH-1:0] rolling_cntr, rolling_cntr_r1, rolling_cntr_r2;
   logic [ROLLING_CNTR_WIDTH-1:0] rolling_cntr_truncate, rolling_cntr_truncate_r1, rolling_cntr_truncate_r2, rolling_cntr_truncate_r3;
   // Make a Pending Req RAM block for BOTH Timeout Errors & Unexpected MMIO Rsp Errors
   logic [PCIE_RP_MAX_TAGS-1:0] pending_rd_req_tags_timeout;
   logic [PCIE_RP_MAX_TAGS-1:0] pending_rd_req_tags_unexp_rsp;
   logic                        curr_idx_hit, curr_idx_hit_r1, curr_idx_hit_r2, curr_idx_hit_r3;
   logic [TIMESTAMP_WIDTH-1:0]  curr_idx_time, curr_idx_time_r1;
   logic [TIMESTAMP_WIDTH-1:0]  time_difference_r2;
   logic                        mmio_timeout_r3;
   logic                        rx_valid_sop_mrd;
   logic                        tx_valid_sop_cmpl;
   logic                        pipeline_complete; // Need a way to determine the read & compare logic is finished
   logic                        pipeline_complete_r3; // Need a way to determine the read & compare logic is finished
   logic                        curr_idx_pending;
   logic                        mmio_timeout_err;
   logic                        sweep_clean;
   logic                        mmio_timeout_err_r3;
   logic                        unexp_mmio_rsp_err_r1;
   logic                        mmio_timeout_err_r1;

   localparam NUM_STATES = 4;
   localparam NUM_STATES_LOG2 = $clog2(NUM_STATES);
   typedef enum logic [NUM_STATES_LOG2-1:0] {NOMINAL, WAIT_FOR_MMIO_RD_RSP, FIND_NEXT_PENDING_RD, FLUSH_PENDING_MMIO_COMPLETE} t_state;
   t_state state, state_next;

   // Grouping valid MemRds and Completions into single bit
   always_comb begin
      rx_valid_sop_mrd         = i_rx_valid_sop_r1 & i_rx_mrd_r1;
      tx_valid_sop_cmpl        = i_tx_valid_sop_r1 & (i_tx_cpl_r1 | i_tx_cpld_r1);

      // This is all the necessary information for a read response
      // We must save it to a RAM block in case we incur an error and
      // flush out all pending reads
      // Possible enhancement: reduce the i_rx_rd_req_add to 1 bit,
      // because only need 1 to determine if it's a read32 or read64.
      rd_req_entry     = { i_rx_req_tag_r1,
                           i_rx_req_dw0_len_r1,
                           i_rx_requester_id_r1,
                           i_rx_rd_req_addr_r1
                         };
   end

   // Start timestamp counter && rolling counter (for addressing timestamp RAM)
   always_ff @(posedge clk) begin
      if (~rst_n) begin
         timestamp_cntr <= '0;
      end else begin
         timestamp_cntr <= timestamp_cntr + 1'b1;
      end
   end

   // Create small FSM to flush pending MMIO read requests
   always_ff @(posedge clk) begin
      if (~rst_n) state <= NOMINAL;
      else        state <= state_next;
   end

   always_comb begin
      state_next = state;
      o_next_pending_mmio_rdy = (state == WAIT_FOR_MMIO_RD_RSP) && !i_mmio_rd_rsp_ack;
      case (state)

         // Nominal mode. The AFU is sending legit traffic.  Behave normally.
         NOMINAL: begin
            if (mmio_timeout_err | i_blocking_traffic) begin
               state_next = FIND_NEXT_PENDING_RD;
            end
         end

         // We have incurred an error and now must flush out all pending reads
         // We are iterating through each of the entries ihe pending_rd_req RAM.
         // If we hit a pending read, forward the information to the
         // tx_axi_packet_f_fifo module.  The tx_axi_packet_f_fifo module will
         // send and ack back to us when it has been serviced
         FIND_NEXT_PENDING_RD: begin
            if (curr_idx_pending)  begin
               state_next = WAIT_FOR_MMIO_RD_RSP;
            end else if (sweep_clean & rolling_cntr_truncate >= (PCIE_RP_MAX_TAGS-1) & ~curr_idx_hit) begin
               state_next = FLUSH_PENDING_MMIO_COMPLETE;
            end
         end

         // The tx_axi_packet_f_fifo has serviced the pending read and sent us
         // an ack.  We now must find the next pending read, if any.
         WAIT_FOR_MMIO_RD_RSP: begin
            if (i_mmio_rd_rsp_ack) begin
               state_next = FIND_NEXT_PENDING_RD;
            end
         end

         // We have iterated through each entry in the pending_rd_req RAM.
         // However, we must keep iterating through in case the host sends
         // another response.
         FLUSH_PENDING_MMIO_COMPLETE: begin
            if (~i_blocking_traffic) begin
               state_next = NOMINAL;
            end else if (rx_valid_sop_mrd | curr_idx_pending) begin
               state_next = FIND_NEXT_PENDING_RD;
            end
         end

         default: begin
            state_next = NOMINAL;
         end
      endcase
   end

   always_ff @(posedge clk) begin
      if (~rst_n) begin
         o_flush_mmio_rsp_queue_complete <= 1'b0;
         rolling_cntr                    <= '0;
         o_mmio_timeout_info             <= '0;
         mmio_timeout_err_r1             <= '0; // comment out to disable error
      end else begin
         o_flush_mmio_rsp_queue_complete <= 1'b0;
         rolling_cntr                    <= rolling_cntr + 1'b1;
         o_mmio_timeout_info             <= mmio_timeout_info;
         mmio_timeout_err_r1             <= mmio_timeout_err; // comment out to disable error
         case (state)
            NOMINAL: begin
               rolling_cntr        <= rolling_cntr + 1'b1;
               o_mmio_timeout_info <= mmio_timeout_info;
            end

            WAIT_FOR_MMIO_RD_RSP: begin
               rolling_cntr            <= rolling_cntr;
               o_mmio_timeout_info     <= o_mmio_timeout_info;
            end

            FLUSH_PENDING_MMIO_COMPLETE: begin
               rolling_cntr                       <= rolling_cntr + 1'b1;
               o_flush_mmio_rsp_queue_complete    <= 1'b1;
               if ((rx_valid_sop_mrd) | curr_idx_pending) begin
                  rolling_cntr                       <= '0;
               end
            end

            default: begin
               rolling_cntr                    <= rolling_cntr + 1'b1;
               o_flush_mmio_rsp_queue_complete <= 1'b0;
               o_mmio_timeout_info             <= mmio_timeout_info;
            end
         endcase
      end
   end

   always_comb begin
      rolling_cntr_truncate = {'0, rolling_cntr[NUM_TAGS_ADDR_WIDTH+ROLLING_CNTR_TRUNCATE_WIDTH-1:ROLLING_CNTR_TRUNCATE_WIDTH]};
      pipeline_complete     = (rolling_cntr_r2[ROLLING_CNTR_TRUNCATE_WIDTH-1:0] >= SYNC_DEPTH) ? 1'b1 : 1'b0;
   end

   // Syncronize the read & compare logic
   always_ff @(posedge clk) begin
      if (~rst_n) begin
         timestamp_cntr_r1 <= '0;
         curr_idx_time_r1  <= '0;
         curr_idx_hit_r1   <= '0;
         curr_idx_hit_r2   <= '0;
         curr_idx_hit_r3   <= '0;
         time_difference_r2<= '0;
         rolling_cntr_r1   <= '0;
         rolling_cntr_r2   <= '0;
         curr_idx_mmio_timeout_info_r1 <= curr_idx_mmio_timeout_info_r0;
         curr_idx_mmio_timeout_info_r2 <= curr_idx_mmio_timeout_info_r1;
         curr_idx_mmio_timeout_info_r3 <= curr_idx_mmio_timeout_info_r2;
         rolling_cntr_truncate_r1      <= '0;
         rolling_cntr_truncate_r2      <= '0;
         rolling_cntr_truncate_r3      <= '0;
      end else begin
         timestamp_cntr_r1  <= timestamp_cntr;
         curr_idx_time_r1   <= curr_idx_time;
         curr_idx_hit_r1    <= curr_idx_hit;
         curr_idx_hit_r2    <= curr_idx_hit_r1;
         curr_idx_hit_r3    <= curr_idx_hit_r2;
         rolling_cntr_r1    <= rolling_cntr;
         rolling_cntr_r2    <= rolling_cntr_r1;
         time_difference_r2 <= timestamp_cntr_r1 - curr_idx_time_r1;
         curr_idx_mmio_timeout_info_r1 <= curr_idx_mmio_timeout_info_r0;
         curr_idx_mmio_timeout_info_r2 <= curr_idx_mmio_timeout_info_r1;
         curr_idx_mmio_timeout_info_r3 <= curr_idx_mmio_timeout_info_r2;
         rolling_cntr_truncate_r1      <= rolling_cntr_truncate;
         rolling_cntr_truncate_r2      <= rolling_cntr_truncate_r1;
         rolling_cntr_truncate_r3      <= rolling_cntr_truncate_r2;
      end
   end

   assign mmio_timeout_err_r3 = pipeline_complete_r3 & curr_idx_hit_r3 & (mmio_timeout_r3 | i_blocking_traffic);


   // Keep Track of Pending MMIO Requests
   always_ff @(posedge clk) begin
      if (~rst_n) begin
         mmio_timeout_info             <= '0;
         mmio_timeout_err              <= '0;
         curr_idx_pending              <= 1'b0;
         pending_rd_req_tags_timeout   <= '0;
         pending_rd_req_tags_unexp_rsp <= '0;
      end else begin
         mmio_timeout_info             <= '0;
         mmio_timeout_err              <= '0;
         curr_idx_pending              <= 1'b0;
         pending_rd_req_tags_timeout   <= pending_rd_req_tags_timeout;
         pending_rd_req_tags_unexp_rsp <= pending_rd_req_tags_unexp_rsp;
         if (rx_valid_sop_mrd) begin
            timestamp_info_ram[i_rx_req_tag_r1]            <= {timestamp_cntr, rd_req_entry};
            pending_rd_req_tags_timeout[i_rx_req_tag_r1]   <= 1'b1;
            pending_rd_req_tags_unexp_rsp[i_rx_req_tag_r1] <= 1'b1;
         end

         // Clear the pending MMIO Req when the response is sent
         if (i_tx_f_fifo_valid_sop_cmpl) begin // Basically from the output of the port fifo
            pending_rd_req_tags_timeout[i_tx_f_fifo_rsp_tag]   <= 1'b0;
            pending_rd_req_tags_unexp_rsp[i_tx_f_fifo_rsp_tag] <= 1'b0;
         end

         // MMIO Rd timeout = 40960 clk_2x cycles (250Mhz), ~163.840us.
         // Check to see which request has timed out & clear the pending read bit
         // Note that we only check the pending bits once every PCIE_RP_MAX_TAGS (64) clock
         // cycles.  This means we have a range of 163.84us-164.092us of time to timeout:
         // Timeout Max = 164.092us = (MMIO_TIMEOUT_CYCLES + (PCIE_RP_MAX_TAGS-1))*(Clock Period)
         // Timeout Min = 163.84us  = (MMIO_TIMEOUT_CYCLES)*(Clock Period)
         mmio_timeout_r3      <= time_difference_r2 > MMIO_TIMEOUT_CYCLES;
         pipeline_complete_r3 <= pipeline_complete;

         if (mmio_timeout_err_r3) begin
            // Set mmio_timeout_err & pass the read request information to tx_axi_packet_f_fifo
            // so that we can generate an automatic read response.
            mmio_timeout_info                                 <= curr_idx_mmio_timeout_info_r3;
            mmio_timeout_err                                  <= 1'b1;
            curr_idx_pending                                  <= 1'b1;
            // Clear all read pending bit
            pending_rd_req_tags_timeout[rolling_cntr_truncate_r3] <= 1'b0;
            pending_rd_req_tags_unexp_rsp[rolling_cntr_truncate_r3] <= 1'b0;
         end
      end
   end // always_ff @ (posedge clk)

   // If the current index is pending a read response (hit), get the current time.
   assign curr_idx_mmio_timeout_info_r0               = t_mmio_timeout_hdr_info'(curr_idx_mmio_timeout_info);
   assign curr_idx_hit                                = pending_rd_req_tags_timeout[rolling_cntr_truncate];
   assign {curr_idx_time, curr_idx_mmio_timeout_info} = timestamp_info_ram[rolling_cntr_truncate];

   always_ff @ (posedge clk) begin
      if (~rst_n) begin
         sweep_clean         <= 1'b0;
      end else if ((rolling_cntr_truncate == 32'h0) & ~curr_idx_hit) begin
         sweep_clean         <= 1'b1;
      end else if (mmio_timeout_err) begin
         sweep_clean         <= 1'b0;
      end
   end

   always_ff @(posedge clk) begin
      o_mmio_timeout_err    <= mmio_timeout_err_r1;
      unexp_mmio_rsp_err_r1 <= tx_valid_sop_cmpl & (pending_rd_req_tags_unexp_rsp[i_tx_rsp_tag_r1] == 0);
      o_unexp_mmio_rsp_err  <= unexp_mmio_rsp_err_r1;
   end

endmodule

// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT
//
// Description
// This module has two objectives:
//     1. Handle MMIO timeout response
//     2. Block AXI TX traffic on an error
//
// When the AFU incurs an error, all pending reads must be flushed and sent
// to the host with the payload of 'hFFFF_FFFF_FFFF_FFFF.
// It is important to note that if a timeout is incurrent, we must make sure
// that the current packet completes before sending our response
//
// Important note: This module only works with 1-cycle CPLDs.  If we extend
// to multi-cycle CPLDs, we can only clear the pending reads after the
// response has completed
//-----------------------------------------------------------------------------
//Note: hdr always comes with with sop assuming single stream 512 bit wide data.


module tx_filter
  import ofs_fim_if_pkg::*;
   import prtcl_chkr_pkg::*;
   import pcie_ss_hdr_pkg::*;
   
   (
    input logic          clk,
    input logic          rst_n,
    input logic          i_afu_softreset,
    input logic          i_clear_errors,
    input logic          i_block_traffic,
    input                t_mmio_timeout_hdr_info i_mmio_timeout_info,
    input logic          i_mmio_timeout_err,
    input logic          i_next_pending_mmio_rdy,
    input logic          i_flush_mmio_rsp_queue_complete,
    
    output logic         o_blocking_traffic,
    output logic         o_blocking_traffic_fast,
    output logic         o_mmio_rd_rsp_ack, //Indicates fake completion has been sent by tx_f_fifo on MMIO timeout detection
                         
                         pcie_ss_axis_if.sink i_tx_st, // this is live from the input of the PC (i.e. r0)
    input logic          i_tx_st_sop, // this is live from the input of the PC (i.e. r0)
                         pcie_ss_axis_if.source o_tx_st_r4,
    output logic         o_tx_st_sop_r4,
                         pcie_ss_axis_if.source o_mmio_rsp_tx_st,
    output logic         o_mmio_rsp_tx_st_sop,
    
    output logic [127:0] o_tx_header_r1,
    output logic [127:0] o_tx_header_r2,
    output logic [127:0] o_tx_header_r3,
    output logic [127:0] o_tx_header_r4,
    output logic [127:0] o_tx_header_r5,
    input                i_tx_hdr_is_pu_mode_r0,
    output logic         o_tx_hdr_is_pu_mode_r1,
    output logic         o_tx_hdr_is_pu_mode_r2,
    output logic         o_tx_hdr_is_pu_mode_r3,
    output logic         o_tx_hdr_is_pu_mode_r4,
    output logic         o_tx_hdr_is_pu_mode_r5
    );
   //Modified AXI ST (added sop signal)
   typedef struct        packed {
      logic              tvalid;
      logic [511:0]      tdata;
      logic [63:0]       tkeep;
      logic [9:0]        tuser;
      logic              tlast;
      logic              tready;
      logic              sop;
   } t_axis_mod;
   
   
   localparam NUM_STATES = 4;
   typedef enum          logic [$clog2(NUM_STATES)-1:0] {IDLE,SEND_MMIO_TIMEOUT_RSP,WAIT_MMIO_RSP_QUEUE,IDLE_BLOCKING_TRAFFIC} t_state;
   t_state state, state_next;
   
   PCIe_PUCplHdr_t                cpl_hdr;
   t_mmio_timeout_hdr_info        timeout_info;
   t_axis_mod                     tx_mmio_st;
   t_axis_mod                     tx_st_r1, tx_st_r2, tx_st_r3, tx_st_r4;
   logic                 access_32b;
   logic                 clear_errors_happened;
   logic                 softreset_happened;
   logic                 afu_softreset_r1;
   logic                 afu_softreset_r2;
   logic                 softreset_deasserted ;

   logic                 tx_ready_r1;
   logic                 tx_ready_r2;
   logic                 tx_ready_r3;
   logic                 tx_ready_r4;
   
   always_comb begin
      o_mmio_rsp_tx_st.tvalid        = tx_mmio_st.tvalid;
      o_mmio_rsp_tx_st.tlast         = tx_mmio_st.tlast;
      o_mmio_rsp_tx_st.tuser_vendor  = tx_mmio_st.tuser;
      o_mmio_rsp_tx_st.tdata         = tx_mmio_st.tdata;
      o_mmio_rsp_tx_st.tkeep         = tx_mmio_st.tkeep;
      o_mmio_rsp_tx_st_sop           = tx_mmio_st.sop;
      
      tx_mmio_st.tready              = o_mmio_rsp_tx_st.tready;
   end
   
   always_comb begin
      access_32b = timeout_info.dw0_len[0];
      
      cpl_hdr               = '0;
      {cpl_hdr.tag_h,
       cpl_hdr.tag_m,
       cpl_hdr.tag_l}       = timeout_info.tag;
      cpl_hdr.fmt_type      = DM_CPL; //0x4a
      cpl_hdr.length        = access_32b ? 'h1 : 'h2;
      cpl_hdr.comp_id       = '0;
      cpl_hdr.cpl_status    = '0;
      cpl_hdr.byte_count    = access_32b ? 12'd4 : 12'd8;
      cpl_hdr.req_id        = timeout_info.requester_id;
      cpl_hdr.low_addr      = timeout_info.addr[6:0];
   end
   
   always_comb begin
      o_tx_st_r4.tvalid        = tx_st_r4.tvalid;
      o_tx_st_r4.tlast         = tx_st_r4.tlast;
      o_tx_st_r4.tuser_vendor  = tx_st_r4.tuser;
      o_tx_st_r4.tdata         = tx_st_r4.tdata;
      o_tx_st_r4.tkeep         = tx_st_r4.tkeep;
      o_tx_st_sop_r4           = tx_st_r4.sop;
      
      i_tx_st.tready = o_tx_st_r4.tready; // This is not registered 4 times. This is almost full from the port_tx_fifo. It goes directly to the output of the PC.
   end
   
   always_ff @(posedge clk) begin
      if (i_tx_st.tready) begin
         tx_st_r1.tvalid   <= i_tx_st.tvalid;
         tx_st_r1.tlast    <= i_tx_st.tlast;
         tx_st_r1.tuser    <= i_tx_st.tuser_vendor;
         tx_st_r1.tdata    <= i_tx_st.tdata;
         tx_st_r1.tkeep    <= i_tx_st.tkeep;
         tx_st_r1.sop      <= i_tx_st_sop;
         tx_st_r2          <= tx_st_r1; // This delay is put here so that the protocol error signals beat
         tx_st_r3          <= tx_st_r2; // the transaction read from the port_tx_fifo.
         tx_st_r4          <= tx_st_r3;
      end
   end // always_ff @ (posedge clk)
   
   // align these with the protocol checkers ready. (no readys)
   always_ff @(posedge clk) begin
      tx_ready_r1 <= i_tx_st.tready;  // This is almost full from the port_tx_fifo. (i_tx_st.tready)
      tx_ready_r2 <= tx_ready_r1;
      tx_ready_r3 <= tx_ready_r2;
      tx_ready_r4 <= tx_ready_r3;
 
      if (i_tx_st_sop  & i_tx_st.tvalid  & i_tx_st.tready) o_tx_header_r1 <= i_tx_st.tdata[127:0];
      if (tx_st_r1.sop & tx_st_r1.tvalid & tx_ready_r1)    o_tx_header_r2 <= tx_st_r1.tdata[127:0];
      if (tx_st_r2.sop & tx_st_r2.tvalid & tx_ready_r2)    o_tx_header_r3 <= tx_st_r2.tdata[127:0];
      if (tx_st_r3.sop & tx_st_r3.tvalid & tx_ready_r3)    o_tx_header_r4 <= tx_st_r3.tdata[127:0];
      if (tx_st_r4.sop & tx_st_r4.tvalid & tx_ready_r4)    o_tx_header_r5 <= tx_st_r4.tdata[127:0];
      
      if (i_tx_st_sop  & i_tx_st.tvalid  & i_tx_st.tready) o_tx_hdr_is_pu_mode_r1 <= i_tx_hdr_is_pu_mode_r0;
      if (tx_st_r1.sop & tx_st_r1.tvalid & tx_ready_r1)    o_tx_hdr_is_pu_mode_r2 <= o_tx_hdr_is_pu_mode_r1;
      if (tx_st_r2.sop & tx_st_r2.tvalid & tx_ready_r2)    o_tx_hdr_is_pu_mode_r3 <= o_tx_hdr_is_pu_mode_r2;
      if (tx_st_r3.sop & tx_st_r3.tvalid & tx_ready_r3)    o_tx_hdr_is_pu_mode_r4 <= o_tx_hdr_is_pu_mode_r3;
      if (tx_st_r4.sop & tx_st_r4.tvalid & tx_ready_r4)    o_tx_hdr_is_pu_mode_r5 <= o_tx_hdr_is_pu_mode_r4;
   end // always_ff @ (posedge clk)
   
      
   always_ff @(posedge clk) begin
      if (~rst_n) state <= IDLE;
      else        state <= state_next;
   end
   
   always_comb begin
      state_next = state;
      case (state)
        IDLE: begin
           if (i_mmio_timeout_err) begin
              state_next = SEND_MMIO_TIMEOUT_RSP;
           end else if (i_block_traffic) begin
              state_next = WAIT_MMIO_RSP_QUEUE;
           end else begin
              state_next = IDLE;
           end
        end
        
        // Send the response of the request that timed out.
        // Block all traffic from the AFU
        // Assert Error to the arbiter in the front end
        SEND_MMIO_TIMEOUT_RSP: begin
           if (o_mmio_rsp_tx_st.tready & tx_mmio_st.tvalid) begin
              state_next = WAIT_MMIO_RSP_QUEUE;
           end else begin
              state_next = SEND_MMIO_TIMEOUT_RSP;
           end
        end
        
        // We are flushing out the pending reads and waiting for the information of
        // the next pendind read
        WAIT_MMIO_RSP_QUEUE: begin
           if (i_next_pending_mmio_rdy) begin
              state_next = SEND_MMIO_TIMEOUT_RSP;
           end else if (i_flush_mmio_rsp_queue_complete) begin
              state_next = IDLE_BLOCKING_TRAFFIC;
           end else begin
              state_next = WAIT_MMIO_RSP_QUEUE;
           end
        end
        
        // This state is mostly cosmetic. It signifies we are done running through all the pending reads
        // but we are still blocking traffic.
        IDLE_BLOCKING_TRAFFIC: begin
           if (clear_errors_happened | softreset_happened) begin
              state_next = IDLE;
           end else if (i_next_pending_mmio_rdy) begin
              state_next = SEND_MMIO_TIMEOUT_RSP;
           end else begin
              state_next = IDLE_BLOCKING_TRAFFIC;
           end
        end
        
        default: begin
           state_next = IDLE;
        end
      endcase
   end
   
   
   always_ff @(posedge clk) begin
      afu_softreset_r1     <= i_afu_softreset;
      afu_softreset_r2     <= afu_softreset_r1;
      softreset_deasserted <= ~afu_softreset_r1 & afu_softreset_r2;
      if (~rst_n) begin
         clear_errors_happened   <= 1'b0;
         softreset_happened      <= 1'b0;
         o_blocking_traffic      <= 1'b0;
      end else begin
         clear_errors_happened   <= i_clear_errors |
                                    clear_errors_happened & ~(state == IDLE);
         softreset_happened      <= softreset_deasserted |
                                    softreset_happened    & ~(state == IDLE);
         o_blocking_traffic      <= i_block_traffic | // block_traffic is just the locical or of all error pulses
                                    o_blocking_traffic    & ~(state == IDLE);
      end
   end
   assign o_blocking_traffic_fast = i_block_traffic | o_blocking_traffic;
   
   //Logic to send out a fake completion on the TX path when an MMIO timeout
   //occurs
   always_ff @(posedge clk) begin
      tx_mmio_st.tkeep <= access_32b ? 64'h0000_000F_FFFF_FFFF : 64'h0000_00FF_FFFF_FFFF;
      timeout_info     <= i_mmio_timeout_info;
      if (~rst_n) begin
         o_mmio_rd_rsp_ack  <= 1'b0;
         tx_mmio_st.tvalid  <= 1'b0;
         tx_mmio_st.sop     <= 1'b0;
         tx_mmio_st.tlast   <= 1'b0;
         tx_mmio_st.tuser   <= tx_mmio_st.tuser;
         tx_mmio_st.tdata   <= tx_mmio_st.tdata;
      end else begin
         o_mmio_rd_rsp_ack  <= 1'b0;
         tx_mmio_st.sop     <= 1'b0;
         tx_mmio_st.tvalid  <= 1'b0;
         tx_mmio_st.tlast   <= tx_mmio_st.tlast;
         tx_mmio_st.tuser   <= tx_mmio_st.tuser;
         tx_mmio_st.tdata   <= tx_mmio_st.tdata;
         
         case (state)
           SEND_MMIO_TIMEOUT_RSP: begin
              o_mmio_rd_rsp_ack          <= 1'b0;
              tx_mmio_st.sop             <= 1'b1;
              tx_mmio_st.tvalid          <= 1'b1;
              tx_mmio_st.tlast           <= 1'b1;
              tx_mmio_st.tdata[255:0]    <= cpl_hdr;
              tx_mmio_st.tdata[511:256]  <= '1;
              if (o_mmio_rsp_tx_st.tready & tx_mmio_st.tvalid) begin
                 tx_mmio_st.sop          <= 1'b0;
                 tx_mmio_st.tvalid       <= 1'b0;
                 tx_mmio_st.tlast        <= 1'b0;
                 o_mmio_rd_rsp_ack       <= 1'b1;
                 tx_mmio_st.tdata[255:0] <= '0;
              end
           end
           
           default: begin
              tx_mmio_st.tvalid       <= '0;
              tx_mmio_st.tlast        <= '0;
              tx_mmio_st.tuser        <= '0;
              tx_mmio_st.tdata        <= '0;
              tx_mmio_st.sop          <= '0;
           end
         endcase
      end
   end
   
endmodule

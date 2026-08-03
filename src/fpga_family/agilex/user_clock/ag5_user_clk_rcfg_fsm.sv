// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// Implements a variant of the OFS read-modify-write IOPLL update protocol for
// Agilex 5. The only component specific to Agilex 5 is the FSM that manages
// the timing of read responses. Otherwise, the code is generic and has no
// knowledge here of IOPLL register addresses or contents.
//
//-----------------------------------------------------------------------------

import qph_user_clk_pkg::*;

module ag5_user_clk_rcfg_fsm (
   // Clock and reset
   input  logic        clk,
   input  logic        rst_n,

   // Management interface (commands from host)
   input  logic        mgmt_reset_i,
   input  logic [1:0]  mgmt_rcfg_cur_seq_i,                // Current sequence number being returned in status register 0
   input  qph_user_clk_pkg::t_rcfg_ctrl mgmt_rcfg_ctrl_i,  // Command 0 register value
   output logic        mgmt_rcfg_ctrl_ack_o,               // Pulsed on command completion
   output logic [31:0] mgmt_rcfg_readdata_o,
   output logic        mgmt_error_o,

   // Agilex 5 IOPLL Avalon interface
   output logic [8:0]  core_avl_address,
   output logic        core_avl_write,
   output logic        core_avl_read,
   output logic [7:0]  core_avl_writedata,
   input  logic [7:0]  core_avl_readdata
);

   logic [31:0] rd_data;

    // Write mask will be applied to future writes. All writes are read-modify-write with a mask.
   logic [31:0] write_mask;
   logic write_mask_valid;
   always_ff @(posedge clk) begin
      if (mgmt_rcfg_ctrl_i.mask) begin
         write_mask <= mgmt_rcfg_ctrl_i.data;
         write_mask_valid <= 1'b1;
      end

      if (~rst_n | mgmt_reset_i) begin
         write_mask_valid <= 1'b0;
      end
   end

   assign mgmt_error_o = 1'b0;

   // 'core_avl' interface FSM states
   typedef enum logic [4:0] {
      IDLE,
      INIT_DELAY_0,
      INIT_DELAY_1,
      INIT_DELAY_2,
      INIT_DELAY_3,
      INIT_DELAY_4,
      RD_START,
      RD_TAR_0,
      RD_TAR_1,
      RD_NULL_0,
      RD_NULL_1,
      RD_NULL_2,
      RD_NULL_3,
      RD_BYTE_0,
      RD_BYTE_1,
      RD_BYTE_2,
      RD_BYTE_3,
      RD_WR_DELAY_0,
      RD_WR_DELAY_1,
      RD_WR_DELAY_2,
      RD_WR_DELAY_3,
      RD_WR_DELAY_4,
      WR_NULL_0,
      WR_NULL_1,
      WR_NULL_2,
      WR_NULL_3,
      WR_NULL_4,
      WR_BYTE_0,
      WR_BYTE_1,
      WR_BYTE_2,
      WR_BYTE_3,
      WR_BYTE_3_repeat
   } e_state;
   e_state core_avl_next_st, core_avl_curr_st;

   // New command when seq changes
   logic uclk_rcfg_start;
   logic [1:0] uclk_rcfg_seq_q;
   always_ff @(posedge clk) begin
      // No register accesses are permitted unless a write mask has been set at some time
      // in the past. This is mainly to prevent software drivers that do not understand
      // the read-modify-write interface from accidentally writing to the wrong register.
      // Early versions of OPAE treated every device not marked S10 as Agilex 7.
      if (~mgmt_rcfg_ctrl_i.mask & write_mask_valid) begin
         uclk_rcfg_start <= |(mgmt_rcfg_ctrl_i.seq ^ uclk_rcfg_seq_q);
         uclk_rcfg_seq_q <= mgmt_rcfg_ctrl_i.seq;
      end

      if (~rst_n | mgmt_reset_i) begin
         uclk_rcfg_start <= 1'b0;
         uclk_rcfg_seq_q <= mgmt_rcfg_cur_seq_i;
      end
   end

   //--------------------------------------------------------------------------------
   // 32 bit read and write operations to core_avl_readdata and core_avl_writedata
   // must be split into four separate 8-bit transfers, each spaced by intervals
   // equal processed sequentially from the least significant to the most significant
   // 8-bit segment.
   //
   // The first 6 cycles while core_avl_read is asserted are discarded. Data arrives
   // for 4 consecutive cycles, starting in the 7th cycle that core_avl_read is
   // asserted.
   //
   // The write sequence begins with 5 cycles with data set to 0 and core_avl_write
   // asserted. The next 5 cycles write the data, with the last byte repeated in the
   // final cycle.
   //
   // Sequences must be separated by at least 5 idle cycles.
   //--------------------------------------------------------------------------------

   // 'core_avl' read|write FSM
   always_comb begin
      unique case (core_avl_curr_st)
         IDLE:
            if (uclk_rcfg_start)
               core_avl_next_st = INIT_DELAY_0;
            else
               core_avl_next_st = IDLE;

         // There must be at least 5 idle cycles after a previous read or
         // write. This preamble separates independent commands.
         INIT_DELAY_0:
            core_avl_next_st  = INIT_DELAY_1;
         INIT_DELAY_1:
            core_avl_next_st  = INIT_DELAY_2;
         INIT_DELAY_2:
            core_avl_next_st  = INIT_DELAY_3;
         INIT_DELAY_3:
            core_avl_next_st  = INIT_DELAY_4;
         INIT_DELAY_4:
            core_avl_next_st = RD_START;

         RD_START:
            core_avl_next_st  = RD_TAR_0;
         RD_TAR_0:
            core_avl_next_st  = RD_TAR_1;
         RD_TAR_1:
            core_avl_next_st  = RD_NULL_0;
         RD_NULL_0:
            core_avl_next_st  = RD_NULL_1;
         RD_NULL_1:
            core_avl_next_st  = RD_NULL_2;
         RD_NULL_2:
            core_avl_next_st  = RD_NULL_3;
         RD_NULL_3:
            core_avl_next_st  = RD_BYTE_0;
         RD_BYTE_0:
            core_avl_next_st  = RD_BYTE_1;
         RD_BYTE_1:
            core_avl_next_st  = RD_BYTE_2;
         RD_BYTE_2:
            core_avl_next_st  = RD_BYTE_3;
         RD_BYTE_3:
            if (mgmt_rcfg_ctrl_i.write)
               core_avl_next_st  = RD_WR_DELAY_0;
            else
               core_avl_next_st  = IDLE;
         // A masked write follows its read with a separate write transaction.
         // The native IOPLL interface requires at least 5 idle cycles between
         // deasserting core_avl_read and asserting core_avl_write.
         RD_WR_DELAY_0:
            core_avl_next_st  = RD_WR_DELAY_1;
         RD_WR_DELAY_1:
            core_avl_next_st  = RD_WR_DELAY_2;
         RD_WR_DELAY_2:
            core_avl_next_st  = RD_WR_DELAY_3;
         RD_WR_DELAY_3:
            core_avl_next_st  = RD_WR_DELAY_4;
         RD_WR_DELAY_4:
            core_avl_next_st  = WR_NULL_0;
         WR_NULL_0:
            core_avl_next_st  = WR_NULL_1;
         WR_NULL_1:
            core_avl_next_st  = WR_NULL_2;
         WR_NULL_2:
            core_avl_next_st  = WR_NULL_3;
         WR_NULL_3:
            core_avl_next_st  = WR_NULL_4;
         WR_NULL_4:
            core_avl_next_st  = WR_BYTE_0;
         WR_BYTE_0:
            core_avl_next_st  = WR_BYTE_1;
         WR_BYTE_1:
            core_avl_next_st  = WR_BYTE_2;
         WR_BYTE_2:
            core_avl_next_st  = WR_BYTE_3;
         WR_BYTE_3:
            core_avl_next_st  = WR_BYTE_3_repeat;
         // The protocol requires byte 3 to be written twice
         WR_BYTE_3_repeat:
            core_avl_next_st  = IDLE;
         default:
            core_avl_next_st  = IDLE;
      endcase
   end

   // 'core_avl' FSM current state
   always_ff @ (posedge clk) begin
      if (~rst_n | mgmt_reset_i)
         core_avl_curr_st <= IDLE;
      else
         core_avl_curr_st <= core_avl_next_st;
   end

   // 'core_avl' FSM outputs
   always_ff @ (posedge clk) begin
      if (~rst_n | mgmt_reset_i) begin
         core_avl_read <= 1'b0;
         core_avl_write <= 1'b0;
         mgmt_rcfg_ctrl_ack_o <= 1'b0;
      end else begin
         unique case (core_avl_curr_st)
            IDLE:
            begin
               core_avl_read <= 1'b0;
               core_avl_write <= 1'b0;
               core_avl_writedata <= '0;
               mgmt_rcfg_ctrl_ack_o <= 1'b0;
            end

            RD_START:
            begin
               core_avl_read <= 1'b1;
               // Software uses the documented byte addresses (for example,
               // M=0x40 and C0=0x5c), while core_avl_address is word-indexed.
`ifdef SIM_MODE
               // The Agilex 5 simulation primitive expects byte addresses.
               core_avl_address <= { 1'b0, mgmt_rcfg_ctrl_i.addr[7:2], 2'b0 };
`else
               core_avl_address <= { 1'b0, mgmt_rcfg_ctrl_i.addr[9:2] };
`endif
            end

            RD_BYTE_0:
            begin
               rd_data[7:0] <= core_avl_readdata;
            end

            RD_BYTE_1:
            begin
               rd_data[15:8] <= core_avl_readdata;
            end

            RD_BYTE_2:
            begin
               rd_data[23:16] <= core_avl_readdata;
            end

            RD_BYTE_3:
            begin
               rd_data[31:24] <= core_avl_readdata;
               core_avl_read <= 1'b0;

               // Read response. Return original data if also doing a write.
               mgmt_rcfg_readdata_o <= { core_avl_readdata, rd_data[23:0] };

               if (core_avl_next_st == IDLE) begin
                  mgmt_rcfg_ctrl_ack_o <= 1'b1;
               end
            end

            WR_NULL_0,
            WR_NULL_1,
            WR_NULL_2,
            WR_NULL_3,
            WR_NULL_4:
            begin
               core_avl_write <= 1'b1;
            end

            WR_BYTE_0:
            begin
               core_avl_writedata <= (rd_data[7:0] & ~write_mask[7:0]) | (mgmt_rcfg_ctrl_i.data[7:0] & write_mask[7:0]);
            end

            WR_BYTE_1:
            begin
               core_avl_writedata <= (rd_data[15:8] & ~write_mask[15:8]) | (mgmt_rcfg_ctrl_i.data[15:8] & write_mask[15:8]);
            end

            WR_BYTE_2:
            begin
               core_avl_writedata <= (rd_data[23:16] & ~write_mask[23:16]) | (mgmt_rcfg_ctrl_i.data[23:16] & write_mask[23:16]);
            end

            WR_BYTE_3:
            begin
               core_avl_writedata <= (rd_data[31:24] & ~write_mask[31:24]) | (mgmt_rcfg_ctrl_i.data[31:24] & write_mask[31:24]);
            end

            WR_BYTE_3_repeat:
            begin
               mgmt_rcfg_ctrl_ack_o <= 1'b1;
            end

            default:
            begin
            end

         endcase
      end
   end

endmodule

// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// AXI-Mem traffic gen CSR 
//
//-----------------------------------------------------------------------------

import ofs_csr_pkg::*;
import tg2_csr_pkg::*;

module mem_tg2_csr #(
   parameter NUM_TG = 4
)(
   output logic [NUM_TG-1:0] mem_tg_active,

   input logic [NUM_TG-1:0]  tg_pass,
   input logic [NUM_TG-1:0]  tg_fail,
   input logic [NUM_TG-1:0]  tg_timeout,
   input logic [63:0]        clock_count[NUM_TG],


   // interface to host
   ofs_avmm_if.sink csr_if,

   // interface to TG2 registers
   ofs_avmm_if.source tg2_cfg_if[NUM_TG]
);


localparam   END_OF_LIST           = 1'h1;  // Set this to 0 if there is another DFH beyond this
localparam   NEXT_DFH_BYTE_OFFSET  = 24'h0; // Next DFH Byte offset
localparam   L2_NUM_TG = $clog2(NUM_TG);
localparam   ADDR_W = csr_if.ADDR_W;

genvar ch;

// update_reg state
ofs_csr_hw_state_t hw_state;

logic range_valid;
logic csr_read_q;
logic csr_write_q;
logic [ADDR_W-1:0] csr_address_q;


logic [CSR_REG_WIDTH-1:0] csr_reg   [MEM_TG2_NUM_REGS-1:0];
logic                     csr_write [MEM_TG2_NUM_REGS-1:0];

t_csr_tg_ctrl tg_ctrl;
csr_tg_ctrl_t mem_tg_ctrl_current;
csr_tg_stat_t tg_stat;


//----------------------------------------------------------------------------
// CSR CTRL output
//----------------------------------------------------------------------------
always_comb
begin
   mem_tg_ctrl_current.data = csr_reg[MEM_TG_CTRL_IDX];
   tg_ctrl = mem_tg_ctrl_current.csr_tg_ctrl.tg_ctrl;
end
   
//----------------------------------------------------------------------------
// CSR write
//----------------------------------------------------------------------------
always_comb
  begin
   for (int csr_addr=0; csr_addr < MEM_TG2_NUM_REGS; csr_addr++)
      if (csr_if.write && ((csr_if.address >> CSR_ADDR_SHIFT) == csr_addr))
         csr_write[csr_addr] = 1'b1;
      else
         csr_write[csr_addr] = 1'b0;
  end

   always_ff @(posedge csr_if.clk) begin
      if(!csr_if.rst_n) begin
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
always_ff @(posedge csr_if.clk) begin
   csr_read_q    <= csr_if.read;
   csr_write_q   <= csr_if.write;
   csr_address_q <= csr_if.address;
   range_valid   <= ((csr_if.address >> CSR_ADDR_SHIFT) < MEM_TG2_NUM_REGS) ? 1'b1 : 1'b0;
end


logic                 csr_select;
logic [L2_NUM_TG-1:0] ch_select;
logic [NUM_TG-1:0]    datavalid;
logic [32*NUM_TG-1:0] readdata;
logic [NUM_TG-1:0]    waitrequest;
logic [31:0]          data;
logic                 msw_access;
   
always_ff @(posedge csr_if.clk) begin
   if(!csr_if.rst_n) begin
      csr_if.readdata      <= 1'b0;
      csr_if.readdatavalid <= 1'b0;
      msw_access           <= 1'b0;
   end else begin
      if (csr_if.read) begin
         // For a read note where the 32-bit value needs to go.
         // AVMM spec doesn't require byteenable to do this.
         msw_access = csr_if.address[2];
      end

      if (csr_select) begin
         // two cycle latency read
         csr_if.readdatavalid <= csr_read_q;
         csr_if.readdata      <= range_valid ? 
                                 csr_reg[csr_address_q >> CSR_ADDR_SHIFT] : 64'b0;
      end else begin
         // return the selected TG2 data
         csr_if.readdatavalid <= |datavalid;
         csr_if.readdata      <= msw_access ? (data << 32) : data;
      end
   end // else: !if(!csr_if.rst_n)
end // always_ff @ (posedge csr_if.clk)

assign csr_if.waitrequest = !csr_if.rst_n ? 1'b1 : 
                            csr_select ? 1'b0 :
                            waitrequest[ch_select];

//----------------------------------------------------------------------------
// TG2 CSR access
//----------------------------------------------------------------------------
logic [NUM_TG-1:0] tg2_write;   
logic [NUM_TG-1:0] tg2_read;   
logic [9:0]        tg2_address;
logic [31:0]       tg2_writedata;
logic [NUM_TG-1:0] tg_ctrl_start;
logic [NUM_TG-1:0] tg2_start_rw;
logic              csr_write_re;
logic              csr_read_re;


// mux down the outputs
always_comb begin
   data = 0;
   for (int ch = 0; ch < NUM_TG; ch++) begin
      if (datavalid[ch]) begin
         data = readdata[32*ch+:32];
      end
   end
end

generate
   for (ch = 0; ch < NUM_TG; ch++) begin : tg2x
      // vectorize for indexing
      assign datavalid[ch]            = tg2_cfg_if[ch].readdatavalid;
      assign readdata[32*ch+:32]      = tg2_cfg_if[ch].readdata;
      assign waitrequest[ch]          = tg2_cfg_if[ch].waitrequest | tg2_start_rw[ch];

      // demux address and write data; set read/write based on selection
      assign tg2_cfg_if[ch].clk       = csr_if.clk;
      assign tg2_cfg_if[ch].rst_n     = csr_if.rst_n;
      assign tg2_cfg_if[ch].address   = tg_ctrl_start[ch] ? TG_START_ADDR : tg2_address;
      assign tg2_cfg_if[ch].writedata = tg2_writedata;
      assign tg2_cfg_if[ch].write     = tg2_write[ch] | tg_ctrl_start[ch];
      assign tg2_cfg_if[ch].read      = tg2_read[ch];
   end // block: tg2x
endgenerate

always_comb begin
   tg2_address = csr_if.address[11:0] >> 2'd2;
   if (csr_if.byteenable == 'hf0) begin
      tg2_address[0] = 1'b1;
      tg2_writedata  = csr_if.writedata[63:32];
   end
   else begin
      tg2_address[0] = 1'b0;
      tg2_writedata  = csr_if.writedata[31:0];
   end
end // always_comb
   
always_comb begin
   tg2_start_rw            = 0;
   tg2_start_rw[ch_select] = csr_write_re | csr_read_re;
end

always_ff @(posedge csr_if.clk) begin
   tg2_write = 0;
   tg2_read  = 0;
   if (!csr_select) begin
      tg2_write[ch_select] = csr_write_re;
      tg2_read[ch_select]  = csr_read_re;
   end
end

assign csr_read_re = csr_if.read & ~csr_read_q;
assign csr_write_re = csr_if.write & ~csr_write_q;

// Choose a TG2 channel or the local CSRs
assign csr_select = csr_if.address[ADDR_W-1:12] == 0;
assign ch_select = csr_if.address[ADDR_W-2:12] - 1'd1;


//----------------------------------------------------------------------------
// Writeable CSR declarations
//----------------------------------------------------------------------------
csr_bit_attr_t [63:0] SCRATCH_ATTR     = {64{RW}};
csr_bit_attr_t [63:0] TG_CTRL_ATTR     = {{(64-NUM_TG){RsvdZ}}, {NUM_TG{RW1C}} };

//----------------------------------------------------------------------------
// Register Reset/Update types
//----------------------------------------------------------------------------

// AFU DFH
afu_csr_dfh_t afu_dfh;

assign afu_dfh.afu_dfh.feature_type    = 4'h1;
assign afu_dfh.afu_dfh.reserved1       = {8{1'b0}};
assign afu_dfh.afu_dfh.afu_min_version = 3'h0;
assign afu_dfh.afu_dfh.reserved0       = {7{1'b0}};
assign afu_dfh.afu_dfh.end_of_list     = END_OF_LIST;
assign afu_dfh.afu_dfh.next_dfh_offset = NEXT_DFH_BYTE_OFFSET;
assign afu_dfh.afu_dfh.afu_maj_version = 4'h1;
assign afu_dfh.afu_dfh.feature_id      = 12'b0;

// AFU_ID
// SCRATCHPAD
ofs_csr_reg_generic_t scratchpad_reset;
ofs_csr_reg_generic_t scratchpad_update;

assign scratchpad_reset.data  = 64'h0000_0000_0000_0000;
assign scratchpad_update.data = csr_if.writedata;

// TG Control
csr_tg_ctrl_t mem_tg_ctrl_update;
assign mem_tg_ctrl_update.csr_tg_ctrl.tg_ctrl = { NUM_TG{1'b1} };

always_comb begin
   hw_state.reset_n      = csr_if.rst_n;
   hw_state.pwr_good_n   = 1'b0;
   hw_state.wr_data.data = csr_if.writedata;
   hw_state.write_type   = (csr_if.byteenable == 'hff) ? FULL64  :
                           (csr_if.byteenable == 'hf0) ? UPPER32 : LOWER32;
end

always @(posedge csr_if.clk) begin : csr_upd
   csr_reg <= '{default : '0};
   
   csr_reg[AFU_DFH_CSR_IDX]  <= afu_dfh.data;
   csr_reg[AFU_ID_L_CSR_IDX] <= MEM_TG2_ID_L;
   csr_reg[AFU_ID_H_CSR_IDX] <= MEM_TG2_ID_H;
   csr_reg[AFU_NEXT_IDX]     <= '0;
   csr_reg[MEM_TG_STAT_IDX]  <= tg_stat.data;

   csr_reg[SCRATCHPAD_IDX] <= update_reg (
                              .attr            (SCRATCH_ATTR),
                              .reg_reset_val   (scratchpad_reset.data),
                              .reg_update_val  (scratchpad_update.data),
                              .reg_current_val (csr_reg[SCRATCHPAD_IDX]),
                              .write           (csr_write[SCRATCHPAD_IDX]),
                              .state           (hw_state) );

   csr_reg[MEM_TG_CTRL_IDX] <= update_reg (
                               .attr            (TG_CTRL_ATTR),
                               .reg_reset_val   (mem_tg_ctrl_update.data),
                               .reg_update_val  (mem_tg_ctrl_update.data),
                               .reg_current_val (csr_reg[MEM_TG_CTRL_IDX]),
                               .write           (csr_write[MEM_TG_CTRL_IDX]),
                               .state           (hw_state) );

   for (int c = 0; c < NUM_TG; c++) begin
      csr_reg[MEM_TG_CLOCKS_IDX+c] <= clock_count[c];
      
      // Generate a write to TG_START for writes to TG_CTRL to support the legacy behavior
      tg_ctrl_start[c]             <= csr_write[MEM_TG_CTRL_IDX] & csr_reg[MEM_TG_CTRL_IDX][c] & hw_state.wr_data.data[c];
   end
   
end // block: csr_upd
   
   
   
// Performance counters
logic [NUM_TG-1:0] tg_start;
logic [NUM_TG-1:0] tg_stop;
logic [NUM_TG-1:0] tg_pass_re;
logic [NUM_TG-1:0] tg_fail_re;
logic [NUM_TG-1:0] tg_timeout_re;
logic [NUM_TG-1:0] tg_pass_1;
logic [NUM_TG-1:0] tg_fail_1;
logic [NUM_TG-1:0] tg_timeout_1;


   always_ff @ (posedge csr_if.clk) begin
      if(!csr_if.rst_n) begin
	 tg_stat.data <= '0;
         tg_pass_1    <= '0;
         tg_fail_1    <= '0;
         tg_timeout_1 <= '0;
      end else begin
	 for (int ch = 0; ch < NUM_TG; ch++) begin
            tg_stat.csr_tg_stat.tg_stat.tg_stat[ch].tg_active  <= (tg_stat.csr_tg_stat.tg_stat.tg_stat[ch].tg_active | tg_start[ch]) & ~tg_stop[ch];
            tg_stat.csr_tg_stat.tg_stat.tg_stat[ch].tg_pass    <= (tg_stat.csr_tg_stat.tg_stat.tg_stat[ch].tg_pass | tg_pass_re[ch]) & ~tg_start[ch];
            tg_stat.csr_tg_stat.tg_stat.tg_stat[ch].tg_fail    <= (tg_stat.csr_tg_stat.tg_stat.tg_stat[ch].tg_fail | tg_fail_re[ch]) & ~tg_start[ch];
            tg_stat.csr_tg_stat.tg_stat.tg_stat[ch].tg_timeout <= (tg_stat.csr_tg_stat.tg_stat.tg_stat[ch].tg_timeout | tg_timeout_re[ch]) & ~tg_start[ch];

            tg_pass_1[ch]                                      <= tg_pass[ch];
            tg_fail_1[ch]                                      <= tg_fail[ch];
            tg_timeout_1[ch]                                   <= tg_timeout[ch];
	 end
      end
   end

   always_comb begin
      for (int ch = 0; ch < NUM_TG; ch++) begin
         mem_tg_active[ch] = tg_stat.csr_tg_stat.tg_stat.tg_stat[ch].tg_active;
         tg_start[ch]      = (tg2_write[ch] && (tg2_address == TG_START_ADDR)) | tg_ctrl_start[ch];
         tg_stop[ch]       = tg_pass_re[ch] | tg_fail_re[ch] | tg_timeout_re[ch];
         tg_pass_re[ch]    = tg_pass[ch] & ~tg_pass_1[ch];
         tg_fail_re[ch]    = tg_fail[ch] & ~tg_fail_1[ch];
         tg_timeout_re[ch] = tg_timeout[ch] & ~tg_timeout_1[ch];
      end
   end

endmodule // mem_tg2_csr


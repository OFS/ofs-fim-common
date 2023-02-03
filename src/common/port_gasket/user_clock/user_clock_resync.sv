// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//  Clock domain crossing between user clock CSR module and qph_user_clk module 
//
//-----------------------------------------------------------------------------

module user_clock_resync (
   // Clocks
   input  logic csr_clk,
   input  logic qph_clk,

   // Resets
   input  logic csr_rst_n,
   input  logic qph_rst_n,

   // CSR signals
   input  logic [63:0]   csr_user_clk_freq_cmd_0,        // Avalon MM command reg
   input  logic [63:0]   csr_user_clk_freq_cmd_1,        // Frequency counter command
   output logic [63:0]   csr_user_clk_freq_sts_0,        // Avalon MM status reg
   output logic [63:0]   csr_user_clk_freq_sts_1,        // Frequency counter status

   // QPH signals
   output logic [63:0]   qph_user_clk_freq_cmd_0,        // Avalon MM command reg
   output logic [63:0]   qph_user_clk_freq_cmd_1,        // Frequency counter command
   input  logic [63:0]   qph_user_clk_freq_sts_0,        // Avalon MM status reg
   input  logic [63:0]   qph_user_clk_freq_sts_1         // Frequency counter status
);

//------------------------------------
// CSR to QPH clock domain crossing
//------------------------------------
typedef struct packed {
   logic [63:0] freq_cmd_1;
   logic [63:0] freq_cmd_0;
} t_csr_to_qph;

localparam CSR_TO_QPH_DW = $bits(t_csr_to_qph);

t_csr_to_qph csr_sync_din;
t_csr_to_qph qph_sync_dout, qph_sync_dout_r;

logic qph_latched_valid;
logic qph_latched_valid_r;
logic qph_latched_ack;

always_comb begin
   csr_sync_din.freq_cmd_1 = csr_user_clk_freq_cmd_1;
   csr_sync_din.freq_cmd_0 = csr_user_clk_freq_cmd_0;

   qph_user_clk_freq_cmd_1 = qph_sync_dout_r.freq_cmd_1;
   qph_user_clk_freq_cmd_0 = qph_sync_dout_r.freq_cmd_0;
end

fim_cross_handshake #(
   .WIDTH (CSR_TO_QPH_DW)
) csr_to_qph_sync (
   .din_clk       (csr_clk),
   .din_srst      (~csr_rst_n), 
   .din           (csr_sync_din),  
   .din_valid     (1'b1),
   .din_ack       (),
   .dout_clk      (qph_clk),
   .dout_srst     (~qph_rst_n),
   .dout_ack      (qph_latched_ack),
   .dout_valid    (qph_latched_valid),
   .dout          (qph_sync_dout)
);

always_ff @ (posedge qph_clk) begin    
   if (qph_latched_valid) begin
      qph_sync_dout_r <= qph_sync_dout;
   end
end 

always_ff @(posedge qph_clk) begin
   qph_latched_valid_r <= qph_latched_valid;
end

always_ff @(posedge qph_clk) begin
   if (~qph_rst_n) begin
      qph_latched_ack <= 1'b0;
   end else begin
      qph_latched_ack <= qph_latched_valid & ~qph_latched_valid_r;
   end
end

//------------------------------------
// QPH to CSR clock domain crossing
//------------------------------------
typedef struct packed {
   logic [63:0] freq_sts_1;
   logic [63:0] freq_sts_0;
} t_qph_to_csr;

localparam QPH_TO_CSR_DW = $bits(t_qph_to_csr);

t_qph_to_csr qph_sync_din;
t_qph_to_csr csr_sync_dout, csr_sync_dout_r;

logic csr_latched_valid;
logic csr_latched_valid_r;
logic csr_latched_ack;

always_comb begin
   qph_sync_din.freq_sts_1 = qph_user_clk_freq_sts_1;
   qph_sync_din.freq_sts_0 = qph_user_clk_freq_sts_0;

   csr_user_clk_freq_sts_1 = csr_sync_dout_r.freq_sts_1;
   csr_user_clk_freq_sts_0 = csr_sync_dout_r.freq_sts_0;
end

fim_cross_handshake #(
   .WIDTH (QPH_TO_CSR_DW)
) qph_to_csr_sync (
   .din_clk       (qph_clk),
   .din_srst      (~qph_rst_n), 
   .din           (qph_sync_din),  
   .din_valid     (1'b1),
   .din_ack       (),
   .dout_clk      (csr_clk),
   .dout_srst     (~csr_rst_n),
   .dout_ack      (csr_latched_ack),
   .dout_valid    (csr_latched_valid),
   .dout          (csr_sync_dout)
);

always_ff @ (posedge csr_clk) begin    
   if (csr_latched_valid) begin
      csr_sync_dout_r <= csr_sync_dout;
   end
end 

always_ff @(posedge csr_clk) begin
   csr_latched_valid_r <= csr_latched_valid;
end

always_ff @(posedge csr_clk) begin
   if (~csr_rst_n) begin
      csr_latched_ack <= 1'b0;
   end else begin
      csr_latched_ack <= csr_latched_valid & ~csr_latched_valid_r;
   end
end

endmodule


// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//   Top level module of AFU user reconfigurable clock feature
//
//-----------------------------------------------------------------------------

module user_clock (
   input  logic                refclk,
   input  logic                clk_csr,
   input  logic                clk_100,

   input  logic                rst_n_csr,
   input  logic                rst_n_clk100,

   input  logic [63:0]          user_clk_freq_cmd_0,
   input  logic [63:0]          user_clk_freq_cmd_1,
   output logic [63:0]          user_clk_freq_sts_0,
   output logic [63:0]          user_clk_freq_sts_1,

   output logic                uclk,
   output logic                uclk_div2
);

logic [63:0] csr_user_clk_freq_cmd_0;
logic [63:0] csr_user_clk_freq_cmd_1;
logic [63:0] csr_user_clk_freq_sts_0;
logic [63:0] csr_user_clk_freq_sts_1;

logic [63:0] qph_user_clk_freq_cmd_0;
logic [63:0] qph_user_clk_freq_cmd_1;
logic [63:0] qph_user_clk_freq_sts_0;
logic [63:0] qph_user_clk_freq_sts_1;

assign csr_user_clk_freq_cmd_0  = user_clk_freq_cmd_0;
assign csr_user_clk_freq_cmd_1  = user_clk_freq_cmd_1;
assign user_clk_freq_sts_0      = csr_user_clk_freq_sts_0;
assign user_clk_freq_sts_1      = csr_user_clk_freq_sts_1;
//----------------------------------------------------------------------------

//---------------------
// Synchronizer
//---------------------
user_clock_resync resync (
   .csr_clk                    (clk_csr),
   .qph_clk                    (clk_100),
   
   .csr_rst_n                  (rst_n_csr),
   .qph_rst_n                  (rst_n_clk100),

   .csr_user_clk_freq_cmd_0    (csr_user_clk_freq_cmd_0),
   .csr_user_clk_freq_cmd_1    (csr_user_clk_freq_cmd_1),
   .csr_user_clk_freq_sts_0    (csr_user_clk_freq_sts_0),
   .csr_user_clk_freq_sts_1    (csr_user_clk_freq_sts_1),

   .qph_user_clk_freq_cmd_0    (qph_user_clk_freq_cmd_0),
   .qph_user_clk_freq_cmd_1    (qph_user_clk_freq_cmd_1),
   .qph_user_clk_freq_sts_0    (qph_user_clk_freq_sts_0),
   .qph_user_clk_freq_sts_1    (qph_user_clk_freq_sts_1)
);

//---------------------
// User clock generator
//---------------------
qph_user_clk #(
   .AGILEX_PLL             (1)
)qph_user_clk (
   .refclk                  (refclk),                    // 100 MHz PLL refclk input
   .clk                     (clk_100),                   // 100 MHz 0deg SSC
   .rst_n                   (rst_n_clk100),              // Reset synchronous to clk_100
   .user_clk_freq_cmd_0     (qph_user_clk_freq_cmd_0),   // Avalon MM command reg                                                         
   .user_clk_freq_cmd_1     (qph_user_clk_freq_cmd_1),   // Frequency counter command                                                     
   .user_clk_freq_sts_0     (qph_user_clk_freq_sts_0),   // Avalon MM status reg                                                         
   .user_clk_freq_sts_1     (qph_user_clk_freq_sts_1),   // Frequency counter status                                                      
   .uclk                    (uclk),                      // User clock                                                                    
   .uclk_div2               (uclk_div2)                  // User clock divided by 2                                                       
);

endmodule

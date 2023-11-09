// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//   AFU user reconfigurable clocks
//
//-----------------------------------------------------------------------------

`include "ofs_ip_cfg_db.vh"

import qph_user_clk_pkg::*;

module qph_user_clk # (
   parameter AGILEX_PLL        = 0
)(
   // PLL refclk
   input  wire           refclk,
   
   // Clocks and Reset
   input  wire           clk,                   // 100 MHz 0deg SSC
   input  wire           rst_n,                 // 100Mhz clock system reset

   // Control and status (synchronous to clk)
   input  wire [63:0]    user_clk_freq_cmd_0,   // Avalon MM command reg
   input  wire [63:0]    user_clk_freq_cmd_1,   // Frequency counter command
   output logic [63:0]   user_clk_freq_sts_0,   // Avalon MM status reg
   output logic [63:0]   user_clk_freq_sts_1,   // Frequency counter status

   // User clocks
   output logic          uclk,                  // User clock
   output logic          uclk_div2              // User clock divided by 2
);

// Feature version (SW uses this information to decide the appropriate handshaking) 
// Version 0-3 are deprecated, and the latest version is version 4
localparam PVL4_USER_CLK_VER = 4'h4;       // Version number
localparam PVL4_USER_CLK_REF = 18'd10000;  // User Clock Reference in 10kHz units: Example: 10000 => 10000 x 10kHz = 10^8 = 100MHz

// Direct command bits
logic        cmd_pll_reset;             // User clock PLL reset
logic        cmd_pll_reset_pre;
logic        reconfig_uclk_reset;       // PLL mgmt interface reset
logic        reconfig_uclk_reset_pre;
logic        rcfg_fsm_reset_n;            // rcfg_fsm machine reset_n (active low)
logic        rcfg_fsm_reset_n_pre;

// Direct status bits
logic        sts_pll_locked;
logic        sts_pll_locked_sync;
logic        rcfg_fsm_error;              // MM Machine error, fatal

// Reconfiguration Bus for IOPLL
logic [10:0] iopll_reconfig_from_pll;
// phase_done missing sync in iopll_reconfig IP - iopll_reconfig_from_pll[9]
// Bus has independant signals, hence multi bit sync not needed
logic        iopll_reconfig_from_pll_sync_bit9;  
logic [29:0] iopll_reconfig_to_pll;

// IOPLL MM Slave Control, to management interface
logic [9:0]  reconfig_uclk_address;     // IOPLL mgmt address
logic [9:0]  reconfig_uclk_address_remap;     // IOPLL mgmt address
logic [31:0] reconfig_uclk_writedata;
logic        reconfig_uclk_read;
logic        reconfig_uclk_write;

// IOPLL MM Slave Control, from management interface
logic        reconfig_uclk_waitrequest;
logic [7:0]  reconfig_uclk_readdata;

// MM Machine and related
t_rcfg_ctrl  uclk_rcfg_ctrl;           // Packed DL csr chunk
t_rcfg_ctrl  uclk_rcfg_ctrl_pre;
logic [1:0]  rcfg_seq;          // Sequence change starts machine
logic        rcfg_write;             // 0:read;  1:write

logic        enable_read_latch;         // Read latch enable
t_rcfg_ctrl  uclk_rcfg_ctrl_latched;   // Latched data from mm cycle
logic [7:0]  reconfig_uclk_readdata_t1; // L1 delayed PLL mgmt interface read data
logic [31:0] amm_readdata_mux_t1;       // Readback mux output

// Reset
logic [4:0]  rst_n_reg;
logic        uclk_reset_n;              // Reset for cmd/sts

//---------------------------------------------------------------------------------------

// Reset
always_ff @(posedge clk) begin
   {uclk_reset_n, rst_n_reg} <= {rst_n_reg[4:0], rst_n};
end

//--------------------------------------------------------------------------------
// Control and Status
//--------------------------------------------------------------------------------
//---------
// Control
//---------
always_ff @ (posedge clk) begin
   if (~uclk_reset_n) begin
      cmd_pll_reset_pre        <= 1'b0;
      reconfig_uclk_reset_pre  <= 1'b0;
      rcfg_fsm_reset_n_pre     <= 1'b0;
      uclk_rcfg_ctrl_pre       <= 'b0;

      cmd_pll_reset            <= 1'b0;
      reconfig_uclk_reset      <= 1'b0;
      rcfg_fsm_reset_n         <= 1'b0;
      uclk_rcfg_ctrl           <= 'b0;
   end else begin
      cmd_pll_reset_pre        <= user_clk_freq_cmd_0[   57]; //  1-bit: PLL powerdown
      reconfig_uclk_reset_pre  <= user_clk_freq_cmd_0[   56]; //  1-bit: PLL mgmt reset
      rcfg_fsm_reset_n_pre     <= user_clk_freq_cmd_0[   52]; //  1-bit: Reconfig FSM reset_n
      uclk_rcfg_ctrl_pre.seq   <= user_clk_freq_cmd_0[49:48]; //  2-bit: Reconfig sequence
      uclk_rcfg_ctrl_pre.write <= user_clk_freq_cmd_0[   44]; //  1-bit: Reconfig write
      uclk_rcfg_ctrl_pre.addr  <= user_clk_freq_cmd_0[41:32]; // 10-bit: Reconfig adress
      uclk_rcfg_ctrl_pre.data  <= user_clk_freq_cmd_0[31:00]; // 32-bit: Reconfig data

      cmd_pll_reset            <= cmd_pll_reset_pre;
      reconfig_uclk_reset      <= reconfig_uclk_reset_pre;
      rcfg_fsm_reset_n         <= rcfg_fsm_reset_n_pre;
      uclk_rcfg_ctrl.seq       <= uclk_rcfg_ctrl_pre.seq;
      uclk_rcfg_ctrl.write     <= uclk_rcfg_ctrl_pre.write;
      uclk_rcfg_ctrl.addr      <= uclk_rcfg_ctrl_pre.addr;
      uclk_rcfg_ctrl.data      <= uclk_rcfg_ctrl_pre.data;
   end
end

generate
// In Agilex PLL, C1 maps to outclk0 and C2 maps to outclk1, C0 register is not being used
// Hence remap the registers to enable same driver to run on Agilex and S10 HW
// If AGILEX_PLL, then remap the address of
// C0 csr to C1 which maps to outclk0
// C1 csr to C2 which maps to outclk1
if (AGILEX_PLL ==1) begin

always_comb begin
   reconfig_uclk_address_remap   = uclk_rcfg_ctrl.addr[9:0];
   case (uclk_rcfg_ctrl.addr[9:0])
      9'h11b: reconfig_uclk_address_remap = 9'h11f; //PLL_C1_HIGH_ADDR
      9'h11c: reconfig_uclk_address_remap = 9'h120; //PLL_C1_BYPASS_EN_ADDR
      9'h11d: reconfig_uclk_address_remap = 9'h121; //PLL_C1_EVEN_DUTY_EN_ADDR
      9'h11e: reconfig_uclk_address_remap = 9'h122; //PLL_C1_LOW_ADDR
      9'h11f: reconfig_uclk_address_remap = 9'h123; //PLL_C2_HIGH_ADDR
      9'h120: reconfig_uclk_address_remap = 9'h124; //PLL_C2_BYPASS_EN_ADDR
      9'h121: reconfig_uclk_address_remap = 9'h125; //PLL_C2_EVEN_DUTY_EN_ADDR
      9'h122: reconfig_uclk_address_remap = 9'h126; //PLL_C2_LOW_ADDR
      default: reconfig_uclk_address_remap = uclk_rcfg_ctrl.addr[9:0];
   endcase
end

end
// No IO PLL CSR remapping needed in S10
else begin
assign reconfig_uclk_address_remap   = uclk_rcfg_ctrl.addr[9:0];
end
endgenerate

// Fan out amm address and write data
assign reconfig_uclk_address   = reconfig_uclk_address_remap;
assign reconfig_uclk_writedata = uclk_rcfg_ctrl.data;

// Assign some slices
assign rcfg_seq   = uclk_rcfg_ctrl.seq;
assign rcfg_write = uclk_rcfg_ctrl.write;

//---------
// Status
//---------
always_ff @(posedge clk) begin
   user_clk_freq_sts_0[   63] <= rcfg_fsm_error;                 //  1-bit: Reconfig FSM error
   user_clk_freq_sts_0[   60] <= sts_pll_locked_sync;            //  1-bit: PLL locked
   user_clk_freq_sts_0[   57] <= cmd_pll_reset;                  //  1-bit: PLL reset
   user_clk_freq_sts_0[   56] <= reconfig_uclk_reset;            //  1-bit: PLL mgmt reset
   user_clk_freq_sts_0[   52] <= rcfg_fsm_reset_n;               //  1-bit: Reconfig FSM reset_n
   user_clk_freq_sts_0[49:48] <= uclk_rcfg_ctrl_latched.seq;     //  2-bit: Reconfig sequence
   user_clk_freq_sts_0[   44] <= uclk_rcfg_ctrl_latched.write;   //  1-bit: Reconfig write
   user_clk_freq_sts_0[41:32] <= uclk_rcfg_ctrl_latched.addr;    // 10-bit: Reconfig address
   user_clk_freq_sts_0[31:00] <= uclk_rcfg_ctrl_latched.data;    // 32-bit: Reconfig data
end

assign user_clk_freq_sts_0[62:61] = 2'b0;
assign user_clk_freq_sts_0[59:58] = 3'b0;
assign user_clk_freq_sts_0[55:53] = 3'b0;
assign user_clk_freq_sts_0[51:50] = 2'b0;
assign user_clk_freq_sts_0[47:45] = 3'b0;
assign user_clk_freq_sts_0[43:42] = 2'b0;

// Return readback data or "ffff_ffff_ffff_ffff."
assign amm_readdata_mux_t1 = {24'h0, (reconfig_uclk_readdata_t1 | {8{uclk_rcfg_ctrl.write}})};

always_ff @ (posedge clk) begin
   reconfig_uclk_readdata_t1 <= reconfig_uclk_readdata;
end

// AMM readback latch
always_ff @ (posedge clk) begin
   if (~uclk_reset_n) begin
      uclk_rcfg_ctrl_latched <= 'b0;
   end else if (enable_read_latch) begin
      uclk_rcfg_ctrl_latched <= {
         // Loopback portion
         uclk_rcfg_ctrl.seq,    //  2-bit: Seq
         uclk_rcfg_ctrl.write,  //  1-bit: Wr
         uclk_rcfg_ctrl.addr,   // 10-bit: Address

         // Read back data
         amm_readdata_mux_t1
      };  // 32-bit: Readback data
   end
end

//--------------------------------------------------------------------------------
// Reconfig FSM
//--------------------------------------------------------------------------------
qph_user_clk_rcfg_fsm qph_user_clk_rcfg_fsm (
   .clk                  (clk),
   .rst_n                (rcfg_fsm_reset_n),

   .rcfg_seq             (rcfg_seq),
   .rcfg_write           (rcfg_write),

   .enable_read_latch    (enable_read_latch),

   .amm_waitrequest      (reconfig_uclk_waitrequest),
   .amm_read             (reconfig_uclk_read),
   .amm_write            (reconfig_uclk_write),

   .error                (rcfg_fsm_error)
);

//--------------------------------------------------------------------------------
// Stratix 10 IOPLL Implementation of the AFU User Clocks
//--------------------------------------------------------------------------------
fim_resync #(
   .SYNC_CHAIN_LENGTH(3),
   .WIDTH(1),
   .INIT_VALUE(0),
   .NO_CUT(0)
) qph_user_clk_locked_resync (
   .clk   (clk),
   .reset (1'b0),
   .d     (sts_pll_locked),
   .q     (sts_pll_locked_sync)
);

fim_resync #(
   .SYNC_CHAIN_LENGTH(3),
   .WIDTH(1),
   .INIT_VALUE(0),
   .NO_CUT(0)
) qph_reconfig_from_pll_resync (
   .clk   (clk),
   .reset (1'b0),
   .d     (iopll_reconfig_from_pll[9]),
   .q     (iopll_reconfig_from_pll_sync_bit9)
);


// IOPLL
qph_user_clk_iopll_RF100M qph_user_clk_iopll (
   .rst               (~uclk_reset_n | cmd_pll_reset),
   .refclk            (refclk),
   .locked            (sts_pll_locked),
   .outclk_0          (uclk),
   .outclk_1          (uclk_div2),
   .reconfig_to_pll   (iopll_reconfig_to_pll),
   .reconfig_from_pll (iopll_reconfig_from_pll)
);

// IOPLL Reconfiguration IP 
qph_user_clk_iopll_reconfig qph_user_clk_iopll_reconfig (
   .mgmt_clk          (clk), // Maximum frequency is 100MHz
   .mgmt_reset        (reconfig_uclk_reset),
   .mgmt_write        (reconfig_uclk_write),
   .mgmt_read         (reconfig_uclk_read),
   .mgmt_waitrequest  (reconfig_uclk_waitrequest),
   .mgmt_address      (reconfig_uclk_address),
   .mgmt_writedata    (reconfig_uclk_writedata[7:0]),
   .mgmt_readdata     (reconfig_uclk_readdata[7:0]),
   .reconfig_from_pll ({iopll_reconfig_from_pll[10], iopll_reconfig_from_pll_sync_bit9, iopll_reconfig_from_pll[8:0]}),
   .reconfig_to_pll   (iopll_reconfig_to_pll)
);

//--------------------------------------------------------------------------------
// Frequency monitoring & version number 
//--------------------------------------------------------------------------------
logic        sel_uclk;
logic        freq_valid;
logic [16:0] freq;

assign sel_uclk = user_clk_freq_cmd_1[32];

qph_user_clk_freq
`ifdef OFS_FIM_IP_CFG_SYS_CLK_100M_MHZ
  // Use the actual clk_100m frequency if available, which may be
  // slightly off 100MHz.
  #(
    .CLK_MHZ(`OFS_FIM_IP_CFG_SYS_CLK_100M_MHZ)
    )
`endif
  qph_user_clk_freq (
   .clk            (clk),
   .rst_n          (uclk_reset_n),

   .uclk           (uclk),
   .uclk_div2      (uclk_div2),

   .i_sel_uclk     (sel_uclk),
   .o_freq_valid   (freq_valid),
   .o_freq         (freq)
);

always_ff @(posedge clk) begin    
   user_clk_freq_sts_1[32] <= sel_uclk;    
end

always_ff @ (posedge clk) begin
   if (~uclk_reset_n) begin
      user_clk_freq_sts_1[16:0] <= {17{1'b0}};
   end else begin
      if (freq_valid) begin
         user_clk_freq_sts_1[16:0] <= freq;
      end
   end
end 

assign user_clk_freq_sts_1[63:60] = PVL4_USER_CLK_VER;
assign user_clk_freq_sts_1[59:51] = 9'b0;
assign user_clk_freq_sts_1[50:33] = PVL4_USER_CLK_REF;
assign user_clk_freq_sts_1[31:17] = 15'b0;

endmodule

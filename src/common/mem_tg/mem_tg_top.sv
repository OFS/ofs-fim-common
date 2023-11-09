// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// AXI traffic generator AFU created to verify AFU attached memory functionality
//
//-----------------------------------------------------------------------------
import tg_csr_pkg::*;

module mem_tg_top #(   
   parameter PF_ID     = 2,
   parameter VF_ID     = 2,
   parameter VF_ACTIVE = 1,
   parameter NUM_TG    = 1
)(
   input logic              clk,
   input logic              rst_n,

   input  logic            flr_rst_n,
   output logic            flr_ack,

   // AXIS Rx
   pcie_ss_axis_if.sink    axis_rx_if,

   // AXIS Tx
   pcie_ss_axis_if.source  axis_tx_if,

   // External Memory I/F
   output [NUM_TG-1:0]  mem_tg_active
`ifdef INCLUDE_DDR4
  ,ofs_fim_emif_axi_mm_if.user ext_mem_if [NUM_TG-1:0]
`endif
);
//----------------------------------------------
// Parameters 
//----------------------------------------------
localparam CSR_ADDR_W = 12;
localparam CSR_DATA_W = 64;
   
//----------------------------------------------
// AXIS Pipeln 
//----------------------------------------------
pcie_ss_axis_if rx_pl_if ();
pcie_ss_axis_if tx_pl_if ();

//----------------------------------------------
// CSR Host channel
//----------------------------------------------
ofs_avmm_if #(
   .ADDR_W(tg_csr_pkg::CSR_ADDR_W),
   .DATA_W(64)
) csr_if ();

//----------------------------------------------
// CSR -> TG
//----------------------------------------------
t_csr_tg_ctrl csr_ctrl;
t_csr_tg_stat csr_stat;
   
//---------------------------------
// FLR reset 
//---------------------------------
logic lcl_rst_n;
logic flr_rst_n_q;

always_ff @(posedge clk) begin
   flr_rst_n_q <= flr_rst_n;
end

always_ff @(posedge clk) begin
   flr_ack <= 1'b0;
   if (flr_rst_n_q && ~flr_rst_n) begin
      flr_ack <= 1'b1;
   end

   if (~rst_n) begin
      flr_ack <= 1'b0;
   end
end

always_ff @(posedge clk) begin
   lcl_rst_n <= (rst_n & flr_rst_n);
end

//----------------------------------------------
// Pipeln instances
//----------------------------------------------
axis_pipeline #( 
   .MODE(0),
   .TDATA_WIDTH(axis_rx_if.DATA_W),
   .TUSER_WIDTH(axis_rx_if.USER_W),
   .PL_DEPTH(2)
) rx_pl_inst (
   .clk    (clk),
   .rst_n  (lcl_rst_n),
   .axis_s (axis_rx_if),
   .axis_m (rx_pl_if)
);

axis_pipeline #( 
   .MODE(0),
   .TDATA_WIDTH(axis_tx_if.DATA_W),
   .TUSER_WIDTH(axis_tx_if.USER_W),
   .PL_DEPTH(2)
) tx_pl_inst (
   .clk    (clk),
   .rst_n  (lcl_rst_n),
   .axis_s (tx_pl_if),
   .axis_m (axis_tx_if)
);

//----------------------------------------------
// CSR
//----------------------------------------------
csr_bridge #(
   .PF_NUM     (PF_ID),
   .VF_NUM     (VF_ID),
   .VF_ACTIVE  (VF_ACTIVE)
) csr_bridge_inst (
   .clk        (clk),
   .rst_n      (lcl_rst_n),

   .axis_rx_if (rx_pl_if),
   .axis_tx_if (tx_pl_if),

   // AVMM CSR if
   .csr_if     (csr_if)
);

mem_tg_csr #(
   .NUM_TG     (NUM_TG)
) tg_csr_inst (
   .clk        (clk),
   .rst_n      (lcl_rst_n),

   .csr_if     (csr_if),

   .tg_ctrl    (csr_ctrl),
   .tg_stat    (csr_stat)
);
   
//----------------------------------------------
// DDR test - uses TG2 from quartus library
//----------------------------------------------
`ifdef INCLUDE_DDR4
genvar ch;
generate
for(ch=0; ch < NUM_TG; ch = ch+1) begin : tg_ch
   tg_axi_mem tg_inst (
      .clk         (clk),
      .rst_n       (lcl_rst_n),
   
      // TG CSR
      .tg_ctrl_csr (csr_ctrl.tg_ctrl[ch]),
      .tg_stat_csr (csr_stat.tg_stat[ch]),

      // External axi mem
      .tg_active   (mem_tg_active[ch]),
      .ext_mem_if  (ext_mem_if[ch])
   );

end // block: tg_ch
endgenerate
`else // !`ifdef INCLUDE_DDR4
   assign csr_stat = '0;
`endif

endmodule


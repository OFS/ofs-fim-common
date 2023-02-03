// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// AXI traffic generator AFU created to verify AFU attached memory functionality
// This module provides direct access to the TG2 registers
//
//-----------------------------------------------------------------------------
import tg2_csr_pkg::*;


module mem_tg2_top #(   
   parameter PF_ID     = 2,
   parameter VF_ID     = 2,
   parameter VF_ACTIVE = 1,
   parameter NUM_TG    = 1,
   parameter PL_EMIF   = 1
)(
   input logic              clk,
   input logic              rst_n,

   // AXIS Rx
   pcie_ss_axis_if.sink    axis_rx_if,

   // AXIS Tx
   pcie_ss_axis_if.source  axis_tx_if,

   // External Memory I/F
   output logic [NUM_TG-1:0] mem_tg_active
`ifdef INCLUDE_DDR4  
  ,ofs_fim_emif_axi_mm_if.user ext_mem_if [NUM_TG-1:0]
`endif
);
//----------------------------------------------
// Parameters 
//----------------------------------------------
localparam CSR_ADDR_W = 14;
localparam CSR_DATA_W = 64;

//----------------------------------------------
// AXIS Pipeln 
//----------------------------------------------
pcie_ss_axis_if rx_pl_if (clk, rst_n);
pcie_ss_axis_if tx_pl_if (clk, rst_n);

//----------------------------------------------
// CSR Host channel
//----------------------------------------------
ofs_avmm_if #(
   .ADDR_W(tg2_csr_pkg::CSR_ADDR_W),
   .DATA_W(CSR_DATA_W)
) csr_if ();

//----------------------------------------------
// CSR TG2 Instances
//----------------------------------------------
ofs_avmm_if #(
   .ADDR_W(10),
   .DATA_W(32)
) tg2_cfg_if[NUM_TG] ();

`ifdef INCLUDE_DDR4  
ofs_fim_emif_axi_mm_if #(
   .AWID_WIDTH   ($bits(ext_mem_if[0].awid)),
   .AWADDR_WIDTH ($bits(ext_mem_if[0].awaddr)),
   .AWUSER_WIDTH ($bits(ext_mem_if[0].awuser)),
   .WDATA_WIDTH  ($bits(ext_mem_if[0].wdata)),
   .BUSER_WIDTH  ($bits(ext_mem_if[0].buser)),
   .ARID_WIDTH   ($bits(ext_mem_if[0].arid)),
   .ARADDR_WIDTH ($bits(ext_mem_if[0].araddr)),
   .ARUSER_WIDTH ($bits(ext_mem_if[0].aruser)),
   .RDATA_WIDTH  ($bits(ext_mem_if[0].rdata)),
   .RUSER_WIDTH  ($bits(ext_mem_if[0].ruser)) 
) tg2_mem_if[NUM_TG] (); 
`endif //  `ifdef INCLUDE_DDR4
   
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
   .rst_n  (rst_n),
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
   .rst_n  (rst_n),
   .axis_s (tx_pl_if),
   .axis_m (axis_tx_if)
);

//----------------------------------------------
// CSR
//----------------------------------------------
csr_bridge #(
   .PF_NUM     (PF_ID),
   .VF_NUM     (VF_ID),
   .VF_ACTIVE  (VF_ACTIVE),
   .MM_ADDR_WIDTH(CSR_ADDR_W),
   .MM_DATA_WIDTH(CSR_DATA_W)
) csr_bridge_inst (
   .clk        (clk),
   .rst_n      (rst_n),

   .axis_rx_if (rx_pl_if),
   .axis_tx_if (tx_pl_if),

   // AVMM CSR if
   .csr_if     (csr_if)
);

logic [NUM_TG-1:0] tg_pass;
logic [NUM_TG-1:0] tg_fail;
logic [NUM_TG-1:0] tg_timeout;

logic [NUM_TG-1:0] tg_pass_csr;
logic [NUM_TG-1:0] tg_fail_csr;
logic [NUM_TG-1:0] tg_timeout_csr;

logic [NUM_TG-1:0] mem_tg_active_csr;
   

// Synchronize TG Status
fim_resync #(
   .SYNC_CHAIN_LENGTH(3),
   .WIDTH($bits(tg_pass)),
   .INIT_VALUE(0),
   .NO_CUT(0)
) tg_pass_sync (
   .clk   (clk),
   .reset (!rst_n),
   .d     (tg_pass),
   .q     (tg_pass_csr)
);
fim_resync #(
   .SYNC_CHAIN_LENGTH(3),
   .WIDTH($bits(tg_fail)),
   .INIT_VALUE(0),
   .NO_CUT(0)
) tg_fail_sync (
   .clk   (clk),
   .reset (!rst_n),
   .d     (tg_fail),
   .q     (tg_fail_csr)
);
fim_resync #(
   .SYNC_CHAIN_LENGTH(3),
   .WIDTH($bits(tg_timeout)),
   .INIT_VALUE(0),
   .NO_CUT(0)
) tg_timeout_sync (
   .clk   (clk),
   .reset (!rst_n),
   .d     (tg_timeout),
   .q     (tg_timeout_csr)
);
   
logic [63:0]       clock_count[NUM_TG];

mem_tg2_csr #(
   .NUM_TG     (NUM_TG)
) tg2_csr_inst (
   .mem_tg_active (mem_tg_active_csr),

   .tg_pass    (tg_pass_csr),
   .tg_fail    (tg_fail_csr),
   .tg_timeout (tg_timeout_csr),
   .clock_count(clock_count),

   .csr_if     (csr_if),
   .tg2_cfg_if (tg2_cfg_if)
);


//----------------------------------------------
// DDR test - uses TG2 from quartus library
//----------------------------------------------
logic [NUM_TG-1:0] tg2_cfg_if_read_q;
genvar ch;
generate
for(ch=0; ch < NUM_TG; ch = ch+1) begin : tg_ch
`ifdef INCLUDE_DDR4
   tg2_axi_mem tg2_inst (
      .clk        (tg2_mem_if[ch].clk),
      .rst_n      (tg2_mem_if[ch].rst_n),
   
      .tg_pass    (tg_pass[ch]),
      .tg_fail    (tg_fail[ch]),
      .tg_timeout (tg_timeout[ch]),
      .clock_count(clock_count[ch]),

      // TG CSR
      .csr_cfg (tg2_cfg_if[ch]),

      // External axi mem
      .ext_mem_if (tg2_mem_if[ch])
   );

   if(PL_EMIF > 0) begin : gen_tg2_mem_br
      axi_mm_emif_bridge #(
         .AW_REG_MODE (0), // skid buffer
         .W_REG_MODE  (0),
         .B_REG_MODE  (0),
         .AR_REG_MODE (0),
         .R_REG_MODE  (0),
         .ID_WIDTH    ($bits(ext_mem_if[ch].awid)),
         .ADDR_WIDTH  ($bits(ext_mem_if[ch].awaddr)),
         .DATA_WIDTH  ($bits(ext_mem_if[ch].wdata))
      ) mem_tg_axi_mm_bridge (
         .m_if      (ext_mem_if[ch]), /* user = master */
         .s_if      (tg2_mem_if[ch]) /* emif = slave  */
      );
   end // block: gen_tg2_mem_br
   
   else begin
   always_comb begin
      tg2_mem_if.clk      = ext_mem_if[ch].clk;
      tg2_mem_if.rst_n    = ext_mem_if[ch].rst_n;
   
      // Master interface
      // Write address channel
      // Inputs
      tg2_mem_if[ch].awready   = ext_mem_if[ch].awready;
      // Outputs
      ext_mem_if[ch].awid      = tg2_mem_if[ch].awid;
      ext_mem_if[ch].awaddr    = tg2_mem_if[ch].awaddr;
      ext_mem_if[ch].awlen     = tg2_mem_if[ch].awlen;
      ext_mem_if[ch].awsize    = tg2_mem_if[ch].awsize;
      ext_mem_if[ch].awburst   = tg2_mem_if[ch].awburst;
      ext_mem_if[ch].awlock    = tg2_mem_if[ch].awlock;
      ext_mem_if[ch].awcache   = tg2_mem_if[ch].awcache;
      ext_mem_if[ch].awprot    = tg2_mem_if[ch].awprot;
      ext_mem_if[ch].awuser    = tg2_mem_if[ch].awuser;
                   
      // Write data channel
      // Inputs
      tg2_mem_if[ch].wready    = ext_mem_if[ch].wready;
      // Outputs
      ext_mem_if[ch].wdata     = tg2_mem_if[ch].wdata;
      ext_mem_if[ch].wstrb     = tg2_mem_if[ch].wstrb;
      ext_mem_if[ch].wlast     = tg2_mem_if[ch].wlast;
                   
      // Write response channel
      // Outputs
      ext_mem_if[ch].bready    = tg2_mem_if[ch].bready;
      // Inputs
      tg2_mem_if[ch].bvalid    = ext_mem_if[ch].bvalid;
      tg2_mem_if[ch].bid       = ext_mem_if[ch].bid;
      tg2_mem_if[ch].bresp     = ext_mem_if[ch].bresp;
      tg2_mem_if[ch].buser     = ext_mem_if[ch].buser;
                                   
      // Read address channel    
      // Inputs
      tg2_mem_if[ch].arready   = ext_mem_if[ch].arready;
      // Outputs
      ext_mem_if[ch].arid      = tg2_mem_if[ch].arid;
      ext_mem_if[ch].araddr    = tg2_mem_if[ch].araddr;
      ext_mem_if[ch].arlen     = tg2_mem_if[ch].arlen;
      ext_mem_if[ch].arsize    = tg2_mem_if[ch].arsize;
      ext_mem_if[ch].arburst   = tg2_mem_if[ch].arburst;
      ext_mem_if[ch].arlock    = tg2_mem_if[ch].arlock;
      ext_mem_if[ch].arcache   = tg2_mem_if[ch].arcache;
      ext_mem_if[ch].arprot    = tg2_mem_if[ch].arprot;
      ext_mem_if[ch].aruser    = tg2_mem_if[ch].aruser;

      // Read response channel
      // Outputs
      ext_mem_if[ch].rready    = tg2_mem_if[ch].rready;
      // Inputs
      tg2_mem_if[ch].rvalid    = ext_mem_if[ch].rvalid;
      tg2_mem_if[ch].rid       = ext_mem_if[ch].rid;
      tg2_mem_if[ch].rdata     = ext_mem_if[ch].rdata;
      tg2_mem_if[ch].rresp     = ext_mem_if[ch].rresp;
      tg2_mem_if[ch].rlast     = ext_mem_if[ch].rlast;
      tg2_mem_if[ch].ruser     = ext_mem_if[ch].ruser;
      ext_mem_if[ch].awvalid   = tg2_mem_if[ch].awvalid;
      ext_mem_if[ch].wvalid    = tg2_mem_if[ch].wvalid;
      ext_mem_if[ch].arvalid   = tg2_mem_if[ch].arvalid;
   end // always_comb
   end // else: !if(PL_EMIF > 0)
   
   fim_resync #(
      .SYNC_CHAIN_LENGTH(3),
      .WIDTH(1),
      .INIT_VALUE(0),
      .NO_CUT(0)
   ) tg_active_sync (
      .clk   (ext_mem_if[ch].clk),
      .reset (!ext_mem_if[ch].rst_n),
      .d     (mem_tg_active_csr[ch]),
      .q     (mem_tg_active[ch])
   );

`else // !`ifdef INCLUDE_DDR4
   assign mem_tg_active[ch] = mem_tg_active_csr[ch];
   
   always_ff @(posedge tg2_cfg_if[ch].clk) begin
      tg2_cfg_if_read_q[ch] <= tg2_cfg_if[ch].read;
   end
   assign tg2_cfg_if[ch].readdatavalid = tg2_cfg_if_read_q[ch];
   assign tg2_cfg_if[ch].readdata      = 0;
   assign tg2_cfg_if[ch].waitrequest   = 0;
`endif
end // block: tg_ch
endgenerate


   
endmodule


// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// AXI MM interface pipeline register
// 
//-----------------------------------------------------------------------------

module axi_mm_bridge 
   import ofs_axi_mm_pkg::*;
#(
   // Number of pipeline stage
   parameter NUM_STAGES = 1,
   // AW channel register type
   // 0 for skid buffer, , 1 for simple buffer, 2 to bypass
   parameter AW_REG_MODE = 0,
   // W channel register type
   // 0 for skid buffer, , 1 for simple buffer, 2 to bypass
   parameter W_REG_MODE = 0,
   // B channel register type
   // 0 for skid buffer, , 1 for simple buffer, 2 to bypass
   parameter B_REG_MODE = 1,
   // AR channel register type
   // 0 for skid buffer, , 1 for simple buffer, 2 to bypass
   parameter AR_REG_MODE = 0,
   // R channel register type
   // 0 for skid buffer, , 1 for simple buffer, 2 to bypass
   parameter R_REG_MODE = 0
)(
   ofs_axi_mm_if.subordinate s_if, 
   ofs_axi_mm_if.manager     m_if  
);
   // Create dummy interface to insert freeze logic on 
   // outbound valid signals
   ofs_axi_mm_if #(
      .AWID_WIDTH   ($bits(m_if.awid)),
      .AWADDR_WIDTH ($bits(m_if.awaddr)),
      .AWUSER_WIDTH ($bits(m_if.awuser)),
      .WDATA_WIDTH  ($bits(m_if.wdata)),
      .BUSER_WIDTH  ($bits(m_if.buser)),
      .ARID_WIDTH   ($bits(m_if.arid)),
      .ARADDR_WIDTH ($bits(m_if.araddr)),
      .ARUSER_WIDTH ($bits(m_if.aruser)),
      .RDATA_WIDTH  ($bits(m_if.rdata)),
      .RUSER_WIDTH  ($bits(m_if.ruser)) 
   ) m_if_wire(); 


   logic [$bits(s_if.rresp)-1:0] s_rresp_wire;
   logic [$bits(s_if.bresp)-1:0] s_bresp_wire;

   logic [$bits(m_if.awburst)-1:0] m_awburst_wire;
   logic [$bits(m_if.arburst)-1:0] m_arburst_wire;

   // Reset flop
   always_ff @ (posedge m_if.clk) begin
      m_if.rst_n <= s_if.rst_n;
   end

   always_comb begin
      s_if.rresp    = axi_resp_t'(s_rresp_wire);
      s_if.bresp    = axi_resp_t'(s_bresp_wire);
      
      m_if.clk      = s_if.clk;
   
      // Master interface
      // Write address channel
      // Inputs
      m_if_wire.awready   = m_if.awready;
      // Outputs
      m_if.awid           = m_if_wire.awid;
      m_if.awaddr         = m_if_wire.awaddr;
      m_if.awlen          = m_if_wire.awlen;
      m_if.awsize         = m_if_wire.awsize;
      m_if.awburst        = axi_burst_t'(m_awburst_wire);
      m_if.awuser         = m_if_wire.awuser;
                   
      // Write data channel
      // Inputs
      m_if_wire.wready   = m_if.wready;
      // Outputs
      m_if.wdata          = m_if_wire.wdata;
      m_if.wstrb          = m_if_wire.wstrb;
      m_if.wlast          = m_if_wire.wlast;
      m_if.wuser          = m_if_wire.wuser;
                   
      // Write response channel
      // Outputs
      m_if.bready =  m_if_wire.bready;
      // Inputs
      m_if_wire.bvalid  = m_if.bvalid;
      m_if_wire.bid     = m_if.bid;
      m_if_wire.bresp   = m_if.bresp;
      m_if_wire.buser   = m_if.buser;
                                   
      // Read address channel    
      // Inputs
      m_if_wire.arready =  m_if.arready;
      // Outputs
      m_if.arid          = m_if_wire.arid;
      m_if.araddr        = m_if_wire.araddr;
      m_if.arlen         = m_if_wire.arlen;
      m_if.arsize        = m_if_wire.arsize;
      m_if.arburst       = axi_burst_t'(m_arburst_wire);
      m_if.aruser        = m_if_wire.aruser;

      // Read response channel
      // Outputs
      m_if.rready = m_if_wire.rready;
      // Inputs
      m_if_wire.rvalid    = m_if.rvalid;
      m_if_wire.rid       = m_if.rid;
      m_if_wire.rdata     = m_if.rdata;
      m_if_wire.rresp     = m_if.rresp;
      m_if_wire.rlast     = m_if.rlast;
      m_if_wire.ruser     = m_if.ruser;
      m_if.awvalid       = m_if_wire.awvalid;
      m_if.wvalid        = m_if_wire.wvalid;
      m_if.arvalid       = m_if_wire.arvalid;
 end

   axi_register #(
      .RDATA_WIDTH   ($bits(s_if.rdata)),
      .WDATA_WIDTH   ($bits(s_if.wdata)),
      .AWADDR_WIDTH  ($bits(s_if.awaddr)),
      .ARADDR_WIDTH  ($bits(s_if.araddr)),
      .AWID_WIDTH    ($bits(s_if.awid)),
      .ARID_WIDTH    ($bits(s_if.arid)),
      .ENABLE_AWUSER (1),
      .AWUSER_WIDTH  ($bits(s_if.awuser)),
      .ENABLE_WUSER  (1),
      .ENABLE_BUSER  (1),
      .BUSER_WIDTH   ($bits(s_if.buser)),
      .ENABLE_ARUSER (1),
      .ARUSER_WIDTH  ($bits(s_if.aruser)),
      .ENABLE_RUSER  (1),
      .RUSER_WIDTH   ($bits(s_if.ruser)),
      .AW_REG_MODE   (AW_REG_MODE),
      .W_REG_MODE    (W_REG_MODE),
      .B_REG_MODE    (B_REG_MODE),
      .AR_REG_MODE   (AR_REG_MODE),
      .R_REG_MODE    (R_REG_MODE) 
    ) axi_axi_register_inst (
       .clk        (s_if.clk),
       .rst_n      (s_if.rst_n),
       // subordinate input interface
       .s_awready  (s_if.awready),
       .s_awvalid  (s_if.awvalid),
       .s_awid     (s_if.awid),
       .s_awaddr   (s_if.awaddr),
       .s_awlen    (s_if.awlen),
       .s_awsize   (s_if.awsize),
       .s_awburst  (s_if.awburst),
       .s_awlock   ('0),
       .s_awcache  ('0),
       .s_awprot   ('0),
       .s_awqos    ('0),
       .s_awregion ('0),
       .s_awuser   (s_if.awuser),
       .s_wready   (s_if.wready),
       .s_wvalid   (s_if.wvalid),
       .s_wdata    (s_if.wdata),
       .s_wstrb    (s_if.wstrb),
       .s_wlast    (s_if.wlast),
       .s_wuser    (s_if.wuser),
       .s_bready   (s_if.bready),
       .s_bvalid   (s_if.bvalid),
       .s_bid      (s_if.bid),
       .s_bresp    (s_bresp_wire),
       .s_buser    (s_if.buser),
       .s_arready  (s_if.arready),
       .s_arvalid  (s_if.arvalid),
       .s_arid     (s_if.arid),
       .s_araddr   (s_if.araddr),
       .s_arlen    (s_if.arlen),
       .s_arsize   (s_if.arsize),
       .s_arburst  (s_if.arburst),
       .s_arlock   ('0),
       .s_arcache  ('0),
       .s_arprot   ('0),
       .s_arqos    ('0),
       .s_arregion ('0),
       .s_aruser   (s_if.aruser),
       .s_rready   (s_if.rready),
       .s_rvalid   (s_if.rvalid),
       .s_rid      (s_if.rid),
       .s_rdata    (s_if.rdata),
       .s_rresp    (s_rresp_wire),
       .s_rlast    (s_if.rlast),
       .s_ruser    (s_if.ruser),

       // manager output interface
       .m_awready  (m_if_wire.awready),
       .m_awvalid  (m_if_wire.awvalid),
       .m_awid     (m_if_wire.awid),
       .m_awaddr   (m_if_wire.awaddr),
       .m_awlen    (m_if_wire.awlen),
       .m_awsize   (m_if_wire.awsize),
       .m_awburst  (m_awburst_wire),
       .m_awlock   (),
       .m_awcache  (),
       .m_awprot   (),
       .m_awqos    (),
       .m_awregion (),
       .m_awuser   (m_if_wire.awuser),
       .m_wready   (m_if_wire.wready),
       .m_wvalid   (m_if_wire.wvalid),
       .m_wdata    (m_if_wire.wdata),
       .m_wstrb    (m_if_wire.wstrb),
       .m_wlast    (m_if_wire.wlast),
       .m_wuser    (m_if_wire.wuser),
       .m_bready   (m_if_wire.bready),
       .m_bvalid   (m_if_wire.bvalid),
       .m_bid      (m_if_wire.bid),
       .m_bresp    (m_if_wire.bresp),
       .m_buser    (m_if_wire.buser),
       .m_arready  (m_if_wire.arready),
       .m_arvalid  (m_if_wire.arvalid),
       .m_arid     (m_if_wire.arid),
       .m_araddr   (m_if_wire.araddr),
       .m_arlen    (m_if_wire.arlen),
       .m_arsize   (m_if_wire.arsize),
       .m_arburst  (m_arburst_wire),
       .m_arlock   (),
       .m_arcache  (),
       .m_arprot   (),
       .m_arqos    (),
       .m_arregion (),
       .m_aruser   (m_if_wire.aruser),
       .m_rready   (m_if_wire.rready),
       .m_rvalid   (m_if_wire.rvalid),
       .m_rid      (m_if_wire.rid),
       .m_rdata    (m_if_wire.rdata),
       .m_rresp    (m_if_wire.rresp),
       .m_rlast    (m_if_wire.rlast),
       .m_ruser    (m_if_wire.ruser)
   );

endmodule

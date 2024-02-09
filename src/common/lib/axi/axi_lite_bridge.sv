// Copyright 2023 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// AXI-Lite pipeline bridge
//
//-----------------------------------------------------------------------------

module axi_lite_bridge #(
    // AW channel register type
    // 0 for skid buffer, , 1 for simple buffer, 2 to bypass
    parameter AW_REG_MODE = 0,
    // W channel register type
    // 0 for skid buffer, , 1 for simple buffer, 2 to bypass
    parameter W_REG_MODE = 0,
    // B channel register type
    // 0 for skid buffer, , 1 for simple buffer, 2 to bypass
    parameter B_REG_MODE = 2,
    // AR channel register type
    // 0 for skid buffer, , 1 for simple buffer, 2 to bypass
    parameter AR_REG_MODE = 0,
    // R channel register type
    // 0 for skid buffer, , 1 for simple buffer, 2 to bypass
    parameter R_REG_MODE = 2
)(
   input clk,
   input rst_n,
   ofs_fim_axi_lite_if.source   m_if, 
   ofs_fim_axi_lite_if.sink     s_if  
);
   // Create dummy interface to insert freeze logic on 
   // outbound valid signals
   ofs_fim_axi_lite_if #(
      .AWADDR_WIDTH ($bits(m_if.awaddr)),
      .WDATA_WIDTH  ($bits(m_if.wdata)),
      .ARADDR_WIDTH ($bits(m_if.araddr)),
      .RDATA_WIDTH  ($bits(m_if.rdata))
   ) m_if_wire(); 

   // Reset flop
   // always_ff @ (posedge s_if.clk) begin
   //    m_if.rst_n <= s_if.rst_n;
   // end

   always_comb begin
      // m_if.clk      = s_if.clk;
   
      // Master interface
      // Write address channel
      // Inputs
      m_if_wire.awready   = m_if.awready;
      // Outputs
      m_if.awaddr         = m_if_wire.awaddr;
      m_if.awprot         = m_if_wire.awprot;
                   
      // Write data channel
      // Inputs
      m_if_wire.wready   = m_if.wready;
      // Outputs
      m_if.wdata          = m_if_wire.wdata;
      m_if.wstrb          = m_if_wire.wstrb;
                   
      // Write response channel
      // Outputs
      m_if.bready =  m_if_wire.bready;
      // Inputs
      m_if_wire.bvalid  = m_if.bvalid;
      m_if_wire.bresp   = m_if.bresp;
                                   
      // Read address channel    
      // Inputs
      m_if_wire.arready =  m_if.arready;
      // Outputs
      m_if.araddr        = m_if_wire.araddr;
      m_if.arprot        = m_if_wire.arprot;

      // Read response channel
      // Outputs
      m_if.rready = m_if_wire.rready;
      // Inputs
      m_if_wire.rvalid    = m_if.rvalid;
      m_if_wire.rdata     = m_if.rdata;
      m_if_wire.rresp     = m_if.rresp;
      m_if.awvalid       = m_if_wire.awvalid;
      m_if.wvalid        = m_if_wire.wvalid;
      m_if.arvalid       = m_if_wire.arvalid;
 end

   axi_register #(
      .RDATA_WIDTH   ($bits(m_if.rdata)),
      .WDATA_WIDTH   ($bits(m_if.wdata)),
      .AWADDR_WIDTH  ($bits(m_if.awaddr)),
      .ARADDR_WIDTH  ($bits(m_if.araddr)),
      .AWID_WIDTH    (0),
      .ARID_WIDTH    (0),
      .ENABLE_AWUSER (0),
      .AWUSER_WIDTH  (0),
      .ENABLE_WUSER  (0),
      .ENABLE_BUSER  (0),
      .BUSER_WIDTH   (0),
      .ENABLE_ARUSER (0),
      .ARUSER_WIDTH  (0),
      .ENABLE_RUSER  (0),
      .RUSER_WIDTH   (0),
      .AW_REG_MODE   (AW_REG_MODE),
      .W_REG_MODE    (W_REG_MODE),
      .B_REG_MODE    (B_REG_MODE),
      .AR_REG_MODE   (AR_REG_MODE),
      .R_REG_MODE    (R_REG_MODE) 
    ) axi_axi_register_inst (
       // .clk        (s_if.clk),
       // .rst_n      (s_if.rst_n),
       .clk        (clk),
       .rst_n      (rst_n),
       // slave input interface
       .s_awready  (s_if.awready),
       .s_awvalid  (s_if.awvalid),
       .s_awid     ('0),
       .s_awaddr   (s_if.awaddr),
       .s_awlen    ('0),
       .s_awsize   ('0),
       .s_awburst  ('0),
       .s_awlock   ('0),
       .s_awcache  ('0),
       .s_awprot   ('0),
       .s_awqos    ('0),
       .s_awregion ('0),
       .s_awuser   ('0),
       .s_wready   (s_if.wready),
       .s_wvalid   (s_if.wvalid),
       .s_wdata    (s_if.wdata),
       .s_wstrb    (s_if.wstrb),
       .s_wlast    ('0),
       .s_wuser    ('0),
       .s_bready   (s_if.bready),
       .s_bvalid   (s_if.bvalid),
       .s_bid      (),
       .s_bresp    (s_if.bresp),
       .s_buser    (),
       .s_arready  (s_if.arready),
       .s_arvalid  (s_if.arvalid),
       .s_arid     ('0),
       .s_araddr   (s_if.araddr),
       .s_arlen    ('0),
       .s_arsize   ('0),
       .s_arburst  ('0),
       .s_arlock   ('0),
       .s_arcache  ('0),
       .s_arprot   (s_if.arprot),
       .s_arqos    (),
       .s_arregion (),
       .s_aruser   (),
       .s_rready   (s_if.rready),
       .s_rvalid   (s_if.rvalid),
       .s_rid      (),
       .s_rdata    (s_if.rdata),
       .s_rresp    (s_if.rresp),
       .s_rlast    (),
       .s_ruser    (),

       // master output interface
       .m_awready  (m_if_wire.awready),
       .m_awvalid  (m_if_wire.awvalid),
       .m_awid     (),
       .m_awaddr   (m_if_wire.awaddr),
       .m_awlen    (),
       .m_awsize   (),
       .m_awburst  (),
       .m_awlock   (),
       .m_awcache  (),
       .m_awprot   (m_if_wire.awprot),
       .m_awqos    (),
       .m_awregion (),
       .m_awuser   (),
       .m_wready   (m_if_wire.wready),
       .m_wvalid   (m_if_wire.wvalid),
       .m_wdata    (m_if_wire.wdata),
       .m_wstrb    (m_if_wire.wstrb),
       .m_wlast    (),
       .m_wuser    (),
       .m_bready   (m_if_wire.bready),
       .m_bvalid   (m_if_wire.bvalid),
       .m_bid      ('0),
       .m_bresp    (m_if_wire.bresp),
       .m_buser    ('0),
       .m_arready  (m_if_wire.arready),
       .m_arvalid  (m_if_wire.arvalid),
       .m_arid     (),
       .m_araddr   (m_if_wire.araddr),
       .m_arlen    (),
       .m_arsize   (),
       .m_arburst  (),
       .m_arlock   (),
       .m_arcache  (),
       .m_arprot   (m_if_wire.arprot),
       .m_arqos    (),
       .m_arregion (),
       .m_aruser   (),
       .m_rready   (m_if_wire.rready),
       .m_rvalid   (m_if_wire.rvalid),
       .m_rid      ('0),
       .m_rdata    (m_if_wire.rdata),
       .m_rresp    (m_if_wire.rresp),
       .m_rlast    ('0),
       .m_ruser    ('0)
   );

endmodule

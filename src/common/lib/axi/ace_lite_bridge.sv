// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT


// Description
//-----------------------------------------------------------------------------
//
// ACE pipeline bridge
// 
//-----------------------------------------------------------------------------

module ace_lite_bridge (
   input                      clk,
   input                      rst_n,
   ofs_fim_ace_lite_if.slave  s_if,
   ofs_fim_ace_lite_if.master m_if
);

   chan_reg #(
      .DATA_W($bits({s_if.awid, s_if.awaddr, s_if.awprot,
                    s_if.awlock, s_if.awcache, s_if.awqos, s_if.awuser,
                    s_if.awlen, s_if.awsize,s_if.awburst, 
                    s_if.awsnoop, s_if.awdomain, s_if.awbar}))
   ) aw_reg (
      .clk,
      .rst_n,
      .tx_ready (s_if.awready),
      .tx_valid (s_if.awvalid),
      .tx_data  ({s_if.awid, s_if.awaddr, s_if.awprot,
                  s_if.awlock, s_if.awcache, s_if.awqos, s_if.awuser,
                  s_if.awlen, s_if.awsize,s_if.awburst, 
                  s_if.awsnoop, s_if.awdomain, s_if.awbar}),

      .rx_ready (m_if.awready),
      .rx_valid (m_if.awvalid),
      .rx_data  ({m_if.awid, m_if.awaddr, m_if.awprot,
                  m_if.awlock, m_if.awcache, m_if.awqos, m_if.awuser,
                  m_if.awlen, m_if.awsize,m_if.awburst, 
                  m_if.awsnoop, m_if.awdomain, m_if.awbar})
   );
	      
   chan_reg #(
      .DATA_W($bits({s_if.arid, s_if.araddr, s_if.arprot,
                     s_if.arlock, s_if.arcache, s_if.arqos, s_if.aruser,
                     s_if.arlen, s_if.arsize, s_if.arburst,
                     s_if.arsnoop, s_if.ardomain, s_if.arbar}))
   ) ar_reg (
      .clk,
      .rst_n,
      .tx_ready (s_if.arready),
      .tx_valid (s_if.arvalid),
      .tx_data  ({s_if.arid, s_if.araddr, s_if.arprot,
		  s_if.arlock, s_if.arcache, s_if.arqos, s_if.aruser,
		  s_if.arlen, s_if.arsize, s_if.arburst,
		  s_if.arsnoop, s_if.ardomain, s_if.arbar}),

      .rx_ready (m_if.arready),
      .rx_valid (m_if.arvalid),
      .rx_data  ({m_if.arid, m_if.araddr, m_if.arprot,
		  m_if.arlock, m_if.arcache, m_if.arqos, m_if.aruser,
		  m_if.arlen, m_if.arsize, m_if.arburst,
		  m_if.arsnoop, m_if.ardomain, m_if.arbar})
   );

   chan_reg #(
      .DATA_W($bits({s_if.wdata, s_if.wstrb, s_if.wlast}))
   ) w_reg (
      .clk,
      .rst_n,
      .tx_ready (s_if.wready),
      .tx_valid (s_if.wvalid),
      .tx_data  ({s_if.wdata, s_if.wstrb, s_if.wlast}),

      .rx_ready (m_if.wready),
      .rx_valid (m_if.wvalid),
      .rx_data  ({m_if.wdata, m_if.wstrb, m_if.wlast})
   );

   chan_reg #(
      .DATA_W($bits({s_if.bresp, s_if.bid}))
   ) b_reg (
      .clk,
      .rst_n,
      .tx_ready (m_if.bready),
      .tx_valid (m_if.bvalid),
      .tx_data  ({m_if.bresp, m_if.bid}),

      .rx_ready (s_if.bready),
      .rx_valid (s_if.bvalid),
      .rx_data  ({s_if.bresp, s_if.bid})
   );

   chan_reg #(
      .DATA_W($bits({s_if.rdata, s_if.rlast, s_if.rresp, s_if.rid}))
   ) r_reg (
      .clk,
      .rst_n,
      .tx_ready (m_if.rready),
      .tx_valid (m_if.rvalid),
      .tx_data  ({m_if.rdata, m_if.rlast, m_if.rresp, m_if.rid}),

      .rx_ready (s_if.rready),
      .rx_valid (s_if.rvalid),
      .rx_data  ({s_if.rdata, s_if.rlast, s_if.rresp, s_if.rid})
   );

endmodule : ace_lite_bridge


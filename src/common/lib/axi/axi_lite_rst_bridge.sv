// Copyright 2023 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// AXI-Lite reset bridge, 
// responds to requests with all 0's if destination is in active reset
// 
//-----------------------------------------------------------------------------


module axi_lite_rst_bridge (
   ofs_fim_axi_lite_if.sink   s_if,
   ofs_fim_axi_lite_if.source m_if
);

   logic clk;
   assign clk = s_if.clk;
   
   ofs_fim_axi_lite_if #(
      .AWADDR_WIDTH(s_if.AWADDR_WIDTH), 
      .ARADDR_WIDTH(s_if.ARADDR_WIDTH)
   ) reg_if ();

   axi_lite_bridge axi_reg (.clk(clk), .rst_n(m_if.rst_n), .s_if(reg_if), .m_if(m_if));

   // Read request handling during reset
   // recieve flag for read channel
   logic       ar_rx;
   always_ff @(posedge clk) begin
      if(!s_if.rst_n) begin
	 ar_rx <= '0;
      end else begin
	 if(s_if.arvalid & s_if.arready) begin
	    ar_rx <= !m_if.rst_n;
	 end else if (s_if.rvalid & s_if.rready) begin
	    ar_rx <= '0;
	 end
      end
   end

   always_comb begin
      // forward read req data
      reg_if.araddr  = s_if.araddr;
      reg_if.arprot  = s_if.arprot;

      reg_if.rready  = s_if.rready;

      // read req control
      if(ar_rx) begin
	 // we are processing a request during reset
	 s_if.rvalid    = '1;
	 s_if.rdata     = '0;
	 s_if.rresp     = '0;
	 s_if.arready   = '0;
	 reg_if.arvalid = '0;
      end else if (!m_if.rst_n) begin
	 // downstream is inactive
	 s_if.rvalid    = '0;
	 s_if.rdata     = '0;
	 s_if.rresp     = '0;
	 s_if.arready   = '1;
	 reg_if.arvalid = '0;
      end else begin
	 // downstream is active, we are not processing rst req
	 s_if.rvalid    = reg_if.rvalid;
	 s_if.rdata     = reg_if.rdata;
	 s_if.rresp     = reg_if.rresp;
	 s_if.arready   = reg_if.arready;
	 reg_if.arvalid = s_if.arvalid;
      end
   end
   
   // Write request handling during reset
   // recieve flags for write channels
   logic       w_rx, aw_rx;
   always_ff @(posedge clk) begin
      if(!s_if.rst_n) begin
	 aw_rx <= '0;
	 w_rx  <= '0;
      end else begin
	 if(s_if.awvalid & s_if.awready) begin
	    aw_rx <= !m_if.rst_n;
	 end else if (s_if.bvalid & s_if.bready) begin
	    aw_rx <= '0;
	 end
	 
	 if(s_if.wvalid & s_if.wready) begin
	    w_rx  <= !m_if.rst_n;
	 end else if (s_if.bvalid & s_if.bready) begin
	    w_rx  <= '0;
	 end
      end // else: !if(!s_if.rst_n)
   end

   always_comb begin
      // forward write req data
      reg_if.awaddr = s_if.awaddr;
      reg_if.awprot = s_if.awprot;
      reg_if.wdata  = s_if.wdata;
      reg_if.wstrb  = s_if.wstrb;

      reg_if.bready = s_if.bready;

      if(aw_rx | w_rx) begin
	 // we are processing a request during reset
	 s_if.bvalid    = (aw_rx & w_rx);
	 s_if.bresp     = '0;
	 s_if.awready   = !aw_rx;
	 s_if.wready    = !w_rx;
	 reg_if.awvalid = '0;
	 reg_if.wvalid  = '0;
      end else if (!m_if.rst_n) begin
	 // downstream is inactive
	 s_if.bvalid    = '0;
	 s_if.bresp     = '0;
	 s_if.awready   = '1;
	 s_if.wready    = '1;
	 reg_if.awvalid = '0;
	 reg_if.wvalid  = '0;
      end else begin
	 // downstream is active, we are not processing rst req
	 s_if.bvalid    = reg_if.bvalid;
	 s_if.bresp     = reg_if.bresp;
	 s_if.awready   = reg_if.awready;
	 s_if.wready    = reg_if.wready;
	 reg_if.awvalid = s_if.awvalid;
	 reg_if.wvalid  = s_if.wvalid;
      end
   end
   
endmodule

// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// AXI-Lite response module, for generating default slaves
//-----------------------------------------------------------------------------

module axi4lite_rsp
#(
   parameter AW =18,
   parameter DW =64,
   parameter RSP_VALUE = 64'hFFFF_FFFF_FFFF_FFFF,
   parameter RSP_STATUS = 2'b0,
   // Derived parameter
   parameter WSTRB_W = (DW/8)
) 
(
// Global signals
input           clk,   
input           rst_n,

// Slave WR ADDR Channel
input [AW-1:0]  s_awaddr,
input [2:0]     s_awprot,
input           s_awvalid,
output          s_awready,
// Slave WR DATA Channel
input [DW-1:0]  s_wdata, 
input [WSTRB_W-1:0] s_wstrb, 
input           s_wvalid,
output          s_wready,
// Slave WR RESP Channel
output  [1:0]   s_bresp, 
output          s_bvalid,
input           s_bready,
// Slave RD ADDR Channel
input [AW-1:0]  s_araddr,
input [2:0]     s_arprot,
input           s_arvalid,
output          s_arready,
// Slave RD DATA Channel
output [DW-1:0] s_rdata, 
output [1:0]    s_rresp, 
output          s_rvalid,
input           s_rready
);
   logic [7:0] aw_cnt, ar_cnt, w_cnt;
   
   always @ (posedge clk) begin
      if(!rst_n) begin
	 aw_cnt <= '0;
	 w_cnt  <= '0;
	 ar_cnt <= '0;
      end else begin
	 aw_cnt <= aw_cnt + (s_awvalid & s_awready) - (s_bvalid & s_bready);
	 w_cnt  <= w_cnt  + (s_wvalid  & s_wready)  - (s_bvalid & s_bready);
	 ar_cnt <= ar_cnt + (s_arvalid & s_arready) - (s_rvalid & s_rready);
      end
   end

   assign s_bresp   = RSP_STATUS;
   assign s_bvalid  = (aw_cnt > 0) && (w_cnt > 0);

   assign s_rresp   = RSP_STATUS;
   assign s_rdata   = RSP_VALUE;
   assign s_rvalid  = (ar_cnt > 0);

   assign s_awready = !(&aw_cnt);
   assign s_wready  = !(&w_cnt);
   assign s_arready = !(&ar_cnt);

endmodule

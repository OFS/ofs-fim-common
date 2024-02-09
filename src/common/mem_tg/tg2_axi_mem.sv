// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
// Description
//-----------------------------------------------------------------------------
//
// AXI-MM Traffic genrator wrapper with full TG2 register access
//
//-----------------------------------------------------------------------------
import tg2_csr_pkg::*;

module tg2_axi_mem (
   input  clk,
   input  rst_n,

   output tg_pass,
   output tg_fail,
   output tg_timeout,
   output logic [63:0] clock_count,
                    
   // TG2 CSRs
   ofs_avmm_if.sink csr_cfg,
                    
   // external mem
   ofs_fim_emif_axi_mm_if.user ext_mem_if
);

localparam USER_WIDTH = ofs_fim_mem_if_pkg::AXI_MEM_USER_WIDTH;
localparam BUSER_WIDTH = ofs_fim_mem_if_pkg::AXI_MEM_BUSER_WIDTH;
localparam UNUSED_BITS = USER_WIDTH - BUSER_WIDTH; 
   
ofs_avmm_if #(
   .ADDR_W($bits(csr_cfg.address)),
   .DATA_W($bits(csr_cfg.writedata))
) tg_cfg ();
assign tg_cfg.clk = ext_mem_if.clk;

logic              local_rst_n;

assign csr_cfg.writeresponsevalid = 1'b0;
assign ext_mem_if.wuser = '0;

mem_ss_tg tg_inst (
   .emif_usr_reset_n (local_rst_n),
   .emif_usr_clk     (clk),

   // TG axi-mm master				      
   // Write address channel
   .axi_awid    (ext_mem_if.awid),
   .axi_awaddr  (ext_mem_if.awaddr),
   .axi_awlen   (ext_mem_if.awlen),
   .axi_awsize  (ext_mem_if.awsize),
   .axi_awburst (ext_mem_if.awburst),
   .axi_awlock  (ext_mem_if.awlock),
   .axi_awcache (ext_mem_if.awcache),
   .axi_awprot  (ext_mem_if.awprot),
   .axi_awuser  (ext_mem_if.awuser),
   .axi_awvalid (ext_mem_if.awvalid),
   .axi_awready (ext_mem_if.awready),
   
   // Write data channel
   .axi_wdata   (ext_mem_if.wdata),
   .axi_wstrb   (ext_mem_if.wstrb),
   .axi_wlast   (ext_mem_if.wlast),
   .axi_wvalid  (ext_mem_if.wvalid),
   .axi_wready  (ext_mem_if.wready),
   
   // Write response channel
   .axi_bready  (ext_mem_if.bready),
   .axi_bvalid  (ext_mem_if.bvalid),
   .axi_bid     (ext_mem_if.bid),
   .axi_bresp   (ext_mem_if.bresp),
   .axi_buser   ({ {{UNUSED_BITS}{1'b0}}, ext_mem_if.buser[BUSER_WIDTH-1:0]}), //buser width is set independently from the other user buses in mem_ss.ip. Need to assign it seperately.
   
   // Read address channel
   .axi_arready (ext_mem_if.arready),
   .axi_arvalid (ext_mem_if.arvalid),
   .axi_arid    (ext_mem_if.arid),
   .axi_araddr  (ext_mem_if.araddr),
   .axi_arlen   (ext_mem_if.arlen),
   .axi_arsize  (ext_mem_if.arsize),
   .axi_arburst (ext_mem_if.arburst),
   .axi_arlock  (ext_mem_if.arlock),
   .axi_arcache (ext_mem_if.arcache),
   .axi_arprot  (ext_mem_if.arprot),
   .axi_aruser  (ext_mem_if.aruser),
   
   // Read response channel
   .axi_rready  (ext_mem_if.rready),
   .axi_rvalid  (ext_mem_if.rvalid),
   .axi_rid     (ext_mem_if.rid),
   .axi_rdata   (ext_mem_if.rdata),
   .axi_rresp   (ext_mem_if.rresp),
   .axi_rlast   (ext_mem_if.rlast),
   .axi_ruser   (ext_mem_if.ruser),

   // Traggic Gen go/status
   .ninit_done          (1'b0),
   .traffic_gen_pass    (tg_pass),
   .traffic_gen_fail    (tg_fail),
   .traffic_gen_timeout (tg_timeout),

   // Avalon-MM Config interface
   .tg_cfg_waitrequest   (tg_cfg.waitrequest),
   .tg_cfg_read          (tg_cfg.read),
   .tg_cfg_write         (tg_cfg.write),
   .tg_cfg_address       (tg_cfg.address),
   .tg_cfg_readdata      (tg_cfg.readdata),
   .tg_cfg_writedata     (tg_cfg.writedata),
   .tg_cfg_readdatavalid (tg_cfg.readdatavalid)
);


   // CDC for Avalon-MM CFG interface
   // Read response side does not have flow control, 
   // this can lead to data loss and cause MMIO to hang.
   // We are fine as long as we do not issue a high volume of requests to the CFG space
   logic 	   cfg_ccb_empty, cfg_ccb_enq, cfg_ccb_deq;
   logic 	   csr_cfg_req;
   logic 	   tg_cfg_valid, tg_cfg_read, tg_cfg_write;

   assign tg_cfg.read  = tg_cfg_valid & tg_cfg_read;
   assign tg_cfg.write = tg_cfg_valid & tg_cfg_write;
   
   assign csr_cfg_req = csr_cfg.read | csr_cfg.write;
   assign cfg_ccb_enq = (!csr_cfg.waitrequest) ? csr_cfg_req : 1'b0;
   assign cfg_ccb_deq = (cfg_ccb_empty) ? 1'b0 : !tg_cfg.waitrequest;
   
   always_ff @(posedge tg_cfg.clk) begin
      if(!rst_n) begin
   	 tg_cfg_valid <= '0;
      end else begin
   	 tg_cfg_valid <= tg_cfg.waitrequest ? tg_cfg_valid : cfg_ccb_deq;
      end
   end

fim_dcfifo
#(
   .DATA_WIDTH      ($bits({csr_cfg.read,
			    csr_cfg.write,
			    csr_cfg.address,
			    csr_cfg.writedata})),
   .DEPTH_RADIX     (4),
   .WRITE_ACLR_SYNC ("ON"),
   .READ_ACLR_SYNC  ("ON")
) cfg_ccb (
   .aclr      (!rst_n),
   // tx side
   .wrclk     (csr_cfg.clk),
   .wrreq     (cfg_ccb_enq),
   .data      ({csr_cfg.read,
		csr_cfg.write,
		csr_cfg.address,
		csr_cfg.writedata}),
   // rx side
   .rdclk     (tg_cfg.clk),
   .rdreq     (cfg_ccb_deq),
   .q         ({tg_cfg_read,
		tg_cfg_write,
		tg_cfg.address,
		tg_cfg.writedata}),

   .rdempty   (cfg_ccb_empty),
   .rdfull    (),
   .rdusedw   (),
   .wrempty   (),
   .wrfull    (),
   .wralmfull (csr_cfg.waitrequest),
   .wrusedw   ()
);

   // dangerous: we don't have flow control for read responses
   // it shouldn't matter for our use case, but if we add
   // cfg csr polling it will be problematic
   logic cfg_rd_ccb_empty;

   always_ff @(posedge csr_cfg.clk) begin
      csr_cfg.readdatavalid <= !cfg_rd_ccb_empty;
   end

fim_dcfifo
#(
   .DATA_WIDTH      ($bits(csr_cfg.readdata)),
   .DEPTH_RADIX     (4),
   .WRITE_ACLR_SYNC ("ON"),
   .READ_ACLR_SYNC  ("ON")
) cfg_rd_ccb (
   .aclr      (!rst_n),
   // tx side
   .wrclk     (tg_cfg.clk),
   .wrreq     (tg_cfg.readdatavalid),
   .data      (tg_cfg.readdata),
   // rx side
   .rdclk     (csr_cfg.clk),
   .rdreq     (!cfg_rd_ccb_empty),
   .q         (csr_cfg.readdata),

   .rdempty   (cfg_rd_ccb_empty),
   .rdfull    (),
   .rdusedw   (),
   .wrempty   (),
   .wrfull    (),
   .wralmfull (),
   .wrusedw   ()
);
   
logic local_rst_n_meta;
logic local_rst_n_sync;
logic tg_start;
logic tg_complete;
logic clock_enable;

   
always @(posedge clk, negedge local_rst_n_sync) begin
   if (!local_rst_n_sync) begin
      tg_start     <= 0;
      clock_enable <= 0;
      clock_count  <= 0;
   end
   else begin
      // Track number of clock during test
      tg_start     <= (tg_cfg.write & !tg_cfg.waitrequest) & (tg_cfg.address == TG_START_ADDR);
      clock_enable <= (clock_enable | tg_start) & ~tg_complete;
      if (tg_start) begin
         clock_count <= 0;
      end
      else begin
         clock_count <= clock_count + clock_enable;
      end
   end
end

assign tg_complete = tg_pass | tg_fail | tg_timeout;

always @(posedge clk, negedge local_rst_n) begin
   if (!local_rst_n) begin
      local_rst_n_meta <= 0;
      local_rst_n_sync <= 0;
   end
   else begin
      local_rst_n_meta <= 1'b1;
      local_rst_n_sync <= local_rst_n_meta;
   end
end

assign local_rst_n = rst_n & csr_cfg.rst_n;

endmodule // tg_axi_mem

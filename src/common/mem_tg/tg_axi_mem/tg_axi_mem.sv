// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
// Description
//-----------------------------------------------------------------------------
//
// AXI-MM Traffic genrator wrapper with CSR control/status interface
//
//-----------------------------------------------------------------------------
import tg_csr_pkg::*;

module tg_axi_mem (
   input  clk,
   input  rst_n,

   // control/status
   input  t_tg_ctrl tg_ctrl_csr,
   output t_tg_stat tg_stat_csr,

   // external mem
   output tg_active,
   ofs_fim_emif_axi_mm_if.user ext_mem_if
);
   localparam TG_RESET_CYCLES = 256;
   localparam RST_CNTR_W = $clog2(TG_RESET_CYCLES);

   // sync signals
   t_tg_ctrl              tg_ctrl_csr_q, tg_ctrl_csr_x2, tg_ctrl;
   t_tg_stat              tg_stat;

   logic  tg_rst_n;
   
   // TG ctrl / status signals
   logic                  tg_ctrl_rst_n;
   logic [RST_CNTR_W-1:0] tg_rst_cntr;
   logic 		  tg_pass, tg_fail, tg_timeout;
   logic 		  tg_pass_csr, tg_fail_csr, tg_timeout_csr;
   logic 		  tg_complete, tg_complete_q, tg_complete_pedge;

   // double tg_init pulse width for sampling w/ slower clk
   always_ff @(posedge clk) begin
      if(!rst_n) begin
	 tg_ctrl_csr_q <= '0;
      end else begin
	 tg_ctrl_csr_q <= tg_ctrl_csr;
      end
   end
   assign tg_ctrl_csr_x2 = !(tg_ctrl_csr ^ tg_ctrl_csr_q); // active low = invert xor
   
   // tg_init is a strobe, begin counting on strobe & lower tg_reset if it isn't already
   // tg_ctrl_rst_n is coupled with emif rst & synchronized afu rst
   always_ff @(posedge ext_mem_if.clk) begin
      if(!tg_rst_n) begin
         tg_ctrl_rst_n    <= 1'b0;
         tg_rst_cntr      <= '0;
      end else begin
         if(!tg_ctrl.tg_init_n) begin
            tg_rst_cntr <= tg_rst_cntr + 1;
         end
         if(&tg_rst_cntr) begin
            tg_rst_cntr <= '0;
            tg_ctrl_rst_n    <= 1'b1;
         end else if (tg_rst_cntr > '0) begin
            tg_rst_cntr <= tg_rst_cntr + 1;
            tg_ctrl_rst_n <= 1'b0;
         end
      end
   end

   assign tg_complete = tg_pass | tg_fail | tg_timeout;
   assign tg_complete_pedge = tg_complete & !tg_complete_q;

   assign tg_active = tg_stat.tg_active;
   
   always_ff @(posedge ext_mem_if.clk) begin
      if(!tg_ctrl_rst_n) tg_complete_q <= 1'b0;
      else       tg_complete_q <= tg_complete;
   end
   // Sticky status bits
   always_ff @(posedge ext_mem_if.clk) begin
      if(!tg_ctrl_rst_n) begin
         tg_stat.tg_pass    <= 1'b0;
         tg_stat.tg_fail    <= 1'b0;
         tg_stat.tg_timeout <= 1'b0;
      end else begin
         tg_stat.tg_pass    <= tg_stat.tg_pass    | tg_pass;
         tg_stat.tg_fail    <= tg_stat.tg_fail    | tg_fail;
         tg_stat.tg_timeout <= tg_stat.tg_timeout | tg_timeout;
      end
   end
   always_ff @(posedge ext_mem_if.clk) begin
      if(!tg_rst_n) begin
         tg_stat.tg_active <= 1'b0;
      end else begin
         if(!tg_ctrl.tg_init_n) begin
            tg_stat.tg_active <= 1'b1;
         end else if (tg_complete_pedge) begin
            tg_stat.tg_active <= 1'b0;
         end
      end
   end

fim_resync #(
   .SYNC_CHAIN_LENGTH(3),
   .WIDTH($bits(t_tg_stat)),
   .INIT_VALUE(0),
   .NO_CUT(0)
) tg_stat_sync (
   .clk   (clk),
   .reset (!rst_n),
   .d     (tg_stat),
   .q     (tg_stat_csr)
);

fim_resync #(
   .SYNC_CHAIN_LENGTH(3),
   .WIDTH($bits(tg_ctrl)),
   .INIT_VALUE(0),
   .NO_CUT(0)
) tg_ctrl_sync (
   .clk   (ext_mem_if.clk),
   .reset (!ext_mem_if.rst_n),
   .d     (tg_ctrl_csr_x2),
   .q     (tg_ctrl)
);

fim_resync #(
   .SYNC_CHAIN_LENGTH(3),
   .WIDTH(1),
   .INIT_VALUE(0),
   .NO_CUT(0)
) tg_rst_sync (
   .clk   (ext_mem_if.clk),
   .reset (!ext_mem_if.rst_n),
   .d     (rst_n),
   .q     (tg_rst_n)
);

mem_ss_tg tg_inst (
   .emif_usr_clk     (ext_mem_if.clk),
   .emif_usr_reset_n (tg_ctrl_rst_n),

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
   .axi_buser   (ext_mem_if.buser),
   
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
   .ninit_done          ('0),
   .traffic_gen_pass    (tg_pass),
   .traffic_gen_fail    (tg_fail),
   .traffic_gen_timeout (tg_timeout)
);
   
endmodule // tg_axi_mem


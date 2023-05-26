// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// * Support the following features
//    * Sends all 0s response with RESP_OKAY status for MMIO read request from host
//      targeting an unsupported/unimplemented FME/Port address (s_csr_if)
//
//    * Sends write response with RESP_OKAY status for MMIO write request from host
//      targeting an unsupported/unimplemented FME/Port address (s_csr_if)
//
// * This module doesn't perform any AXI protocol checking. 
//   It assumes the upstream module to guarantee all incoming requests are legal.
//
//-----------------------------------------------------------------------------

import st2mm_pkg::*;

module fake_responder (
   input  logic clk,
   input  logic rst_n,
   
   ofs_fim_axi_lite_if.slave s_csr_if
);
import ofs_fim_cfg_pkg::*;
import ofs_fim_if_pkg::*;
import ofs_csr_pkg::*;
import fme_csr_pkg::*;
//--------------------
// Read request
//--------------------
logic mmio_read_idle;
logic read_ready;

// Backpressure to master
assign s_csr_if.arready = read_ready;

// Send all 0s back as fake response
assign s_csr_if.rdata = '0;
assign s_csr_if.rresp = RESP_OKAY;

// Track ready status 
always_ff @(posedge clk) begin
   if (~rst_n) begin
      mmio_read_idle <= 1'b1;
      read_ready    <= 1'b0;
   end else begin
      // Read response acknowledged, go back to idle state
      if (s_csr_if.rvalid && s_csr_if.rready) begin
         mmio_read_idle <= 1'b1;
         read_ready     <= 1'b1;
      end

      // Service new read request only in idle state
      if (mmio_read_idle) begin
         read_ready <= 1'b1;
         if (s_csr_if.arvalid) begin // new request, exit idle state
            mmio_read_idle <= 1'b0;
            read_ready    <= 1'b0;
         end
      end
   end
end

// Send read response
always_ff @(posedge clk) begin
   // Read response acknowledged
   if (s_csr_if.rready) begin
      s_csr_if.rvalid <= 1'b0;
   end

   // Ready to send the response
   if (mmio_read_idle && s_csr_if.arvalid) begin
      s_csr_if.rvalid <= 1'b1;
   end 
   
   if (~rst_n) begin         
      s_csr_if.rvalid <= 1'b0;
   end
end

//--------------------
// Write request
//--------------------
logic send_write_response;
logic waddr_idle;
logic write_idle;
logic waddr_ready;
logic write_ready;

// Backpressure to master
assign s_csr_if.awready = waddr_ready;
assign s_csr_if.wready  = write_ready;

assign s_csr_if.bresp = RESP_OKAY;

// Track write address channel ready status
always_ff @(posedge clk) begin
   if (~rst_n) begin
      waddr_idle  <= 1'b1;
      waddr_ready <= 1'b0;
   end else begin
      // Write response acknowledged, go back to idle state
      if (s_csr_if.bvalid && s_csr_if.bready) begin
         waddr_idle  <= 1'b1;
         waddr_ready <= 1'b1;
      end

      // Check new request on write address channel only in idle state
      if (waddr_idle) begin
         waddr_ready <= 1'b1;
         if (s_csr_if.awvalid) begin // new request, exit idle state
            waddr_idle  <= 1'b0;
            waddr_ready <= 1'b0;
         end
      end
   end
end

// Track write channel ready status
always_ff @(posedge clk) begin
   if (~rst_n) begin
      write_idle  <= 1'b1;
      write_ready <= 1'b0;
      send_write_response <= 1'b0;
   end else begin
      send_write_response <= 1'b0;

      // Write response acknowledged, go back to idle state
      if (s_csr_if.bvalid && s_csr_if.bready) begin
         write_idle  <= 1'b1;
         write_ready <= 1'b1;
      end

      // Check new request on write channel only in idle state
      if (write_idle) begin
         write_ready <= 1'b1;
         // Only service a write request after the address is received
         if ((~waddr_idle || s_csr_if.awvalid) && s_csr_if.wvalid) begin
            send_write_response <= 1'b1;
            write_idle  <= 1'b0; // new request, exit idle state
            write_ready <= 1'b0;
         end
      end
   end
end

// Send write response
always_ff @(posedge clk) begin
   // Write response acknowledged
   if (s_csr_if.bready) begin
      s_csr_if.bvalid <= 1'b0;
   end

   // Ready to send the response
   if (send_write_response) begin
      s_csr_if.bvalid <= 1'b1;
   end 
   
   if (~rst_n) begin         
      s_csr_if.bvalid <= 1'b0;
   end
end

endmodule

// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// AXI-4 CSR slave  
//----------------------------
//
//   * Features AXI-4 slave interface and CSR interface
//       * AXI-4 slave interface connects to AXI-4 master interface
//       * CSR interface connects to external CSR module
//   * Support 4B/8B CSR access (No burst)
//   * Convert write/read request from AXI-4 master to CSR write/read 
//   * Send AXI-4 write/read response for CSR write/read request
//
//-----------------------------------------------------------------------------

import ofs_fim_cfg_pkg::*;
import ofs_fim_if_pkg::*;
import ofs_csr_pkg::*;

module ofs_fim_axi_csr_slave #(
   // Derived parameters
   parameter TID_WIDTH   = ofs_fim_cfg_pkg::MMIO_TID_WIDTH,
   parameter ADDR_WIDTH  = ofs_fim_cfg_pkg::MMIO_ADDR_WIDTH,
   parameter DATA_WIDTH  = ofs_fim_cfg_pkg::MMIO_DATA_WIDTH,
   parameter WSTRB_WIDTH = (DATA_WIDTH/8),
   parameter USE_SLV_READY = 0
)(
   ofs_fim_axi_mmio_if.slave      csr_if,

   output logic                   csr_write,
   output logic [ADDR_WIDTH-1:0]  csr_waddr,
   output csr_access_type_t       csr_write_type,
   output logic [DATA_WIDTH-1:0]  csr_wdata,
   output logic [WSTRB_WIDTH-1:0] csr_wstrb,
   input logic                    csr_slv_wready,

   output logic                   csr_read,
   output logic [ADDR_WIDTH-1:0]  csr_raddr,
   output logic                   csr_read_32b,
   input  logic [DATA_WIDTH-1:0]  csr_readdata,
   input  logic                   csr_readdata_valid
 
);

//-------------------------------------
// Signals
//-------------------------------------
logic clk;
logic rst_n;

logic [TID_WIDTH-1:0]  csr_awid;
logic                  csr_wlast;
logic                  csr_awburst_err;
logic                  csr_awlen_err;
logic                  csr_awaddr_err;
logic                  csr_awerr_comb, csr_aw_legal;
logic                  csr_wstrb_err;
logic                  csr_awready_next, csr_awready;
logic                  csr_wready_next, csr_wready;
logic                  csr_write_next;
csr_access_type_t      csr_write_type_comb;

resp_t                 csr_bresp;
logic                  csr_bvalid_next, csr_bvalid;

logic [TID_WIDTH-1:0]  csr_arid;
logic                  csr_arburst_err;
logic                  csr_arlen_err;
logic                  csr_araddr_err;
logic                  csr_rerr_comb, csr_read_legal;
logic                  csr_arready_next, csr_arready;
logic                  csr_read_next;
logic [DATA_WIDTH-1:0] csr_readdata_reg;

resp_t                 csr_rresp;
logic                  csr_rvalid_next, csr_rvalid;

//--------------------------------------------------------------
assign clk = csr_if.clk;
assign rst_n = csr_if.rst_n;

assign csr_if.awready = csr_awready;
assign csr_if.wready  = csr_wready;
assign csr_if.bvalid  = csr_bvalid;
assign csr_if.bresp   = csr_bresp;
assign csr_if.bid     = csr_awid;

assign csr_if.arready = csr_arready;
assign csr_if.rvalid  = csr_rvalid;
assign csr_if.rid     = csr_arid;
assign csr_if.rresp   = csr_rresp;
assign csr_if.rdata   = csr_readdata_reg;
assign csr_if.rlast   = csr_rvalid;

//--------------------------------------------------------------
// AXI Write Interface
//--------------------------------------------------------------
typedef enum {WR_IDLE_BIT, WR_DATA_BIT, WR_CSR_BIT, WR_RESP_BIT, WR_STATE_MAX} t_wr_state_idx;
typedef enum logic [WR_STATE_MAX-1:0] {
   WR_IDLE_STATE = (1 << WR_IDLE_BIT),
   WR_DATA_STATE = (1 << WR_DATA_BIT),
   WR_CSR_STATE  = (1 << WR_CSR_BIT),
   WR_RESP_STATE = (1 << WR_RESP_BIT)
} t_wr_state;

t_wr_state wr_state, wr_state_next;

//------------------------
// Write state transition
//------------------------
always_ff @(posedge clk) begin
   if (~rst_n) begin
      wr_state <= WR_IDLE_STATE;
   end else begin
      wr_state <= wr_state_next;
   end
end

always_ff @(posedge clk) begin
   if (~rst_n) begin
      csr_awready <= 1'b0;
      csr_wready  <= 1'b0;
      csr_write   <= 1'b0;
      csr_bvalid  <= 1'b0;
   end else begin
      csr_awready <= csr_awready_next;
      csr_wready  <= csr_wready_next;
      csr_write   <= csr_write_next;
      csr_bvalid  <= csr_bvalid_next;
   end
end

always_comb begin
   wr_state_next    = wr_state;
   csr_awready_next = 1'b0;
   csr_wready_next  = 1'b0;
   csr_bvalid_next  = 1'b0;
   csr_write_next   = 1'b0;

   unique case (1'b1)
      wr_state[WR_IDLE_BIT] : begin
         if (csr_if.awvalid && csr_if.awready) begin
            csr_wready_next = 1'b1;
            wr_state_next   = WR_DATA_STATE; 
         end else begin
            csr_awready_next = 1'b1;
         end
      end

      wr_state[WR_DATA_BIT] : begin
         if (csr_if.wvalid && csr_if.wready) begin
            wr_state_next = WR_CSR_STATE;
         end else begin
		    csr_wready_next = 1'b1;
         end
      end

      wr_state[WR_CSR_BIT] : begin
	     if (USE_SLV_READY == 1) begin
			csr_write_next  = (csr_aw_legal && ~csr_wstrb_err && csr_wlast);
            csr_bvalid_next = csr_slv_wready;
            wr_state_next   = csr_slv_wready? WR_RESP_STATE:WR_CSR_STATE;
		 end else begin
		 	csr_write_next  = (csr_aw_legal && ~csr_wstrb_err && csr_wlast);
            csr_bvalid_next = 1'b1;
            wr_state_next   = WR_RESP_STATE;
		 end
      end

      wr_state[WR_RESP_BIT] : begin
         if (csr_if.bvalid && csr_if.bready) begin
            csr_awready_next = 1'b1;
            wr_state_next    = WR_IDLE_STATE;
         end else begin
            csr_bvalid_next = 1'b1;
         end
      end

      // synthesis translate_off
      default : begin 
         csr_awready_next = 1'bx;
         csr_wready_next  = 1'bx;
         csr_bvalid_next  = 1'bx;
         csr_write_next   = 1'bx;
      end
      // synthesis translate_on
   endcase
end

//------------------------
// Write address and data
//------------------------
assign load_aw = wr_state[WR_IDLE_BIT];
assign load_w  = wr_state[WR_DATA_BIT];

always_ff @(posedge clk) begin
   if (load_aw) begin
      csr_awid        <= csr_if.awid;
      csr_waddr       <= csr_if.awaddr;
      csr_write_type  <= csr_write_type_comb;
   
      // only fixed burst of 4B/8B is supported
      csr_awburst_err <= |csr_if.awburst || ~(csr_if.awsize == 3'b010 || csr_if.awsize == 3'b011);
      // only burst length 1 is supported
      csr_awlen_err   <= |csr_if.awlen;
      // check address alignment (assuming awsize is valid, use awsize[0] to differentiate between 32b and 64b access)
      csr_awaddr_err  <= |csr_if.awaddr[1:0] || (csr_if.awsize[0] && csr_if.awaddr[2]);
   end
end

always_ff @(posedge clk) begin
   if (load_w) begin
      csr_wdata <= csr_if.wdata;
      csr_wlast <= csr_if.wlast;

      case (csr_write_type) 
         LOWER32 : begin 
            csr_wstrb_err <= |csr_if.wstrb[7:4] || ~&csr_if.wstrb[3:0];
         end
         UPPER32 : begin
            csr_wstrb_err <= |csr_if.wstrb[3:0] || ~&csr_if.wstrb[7:4];
         end
         default : begin
            csr_wstrb_err <= ~&csr_if.wstrb;
         end
      endcase
   end
end

//------------------------
// Write error checking
//------------------------
assign csr_awerr_comb = (csr_awburst_err | csr_awlen_err) || (~csr_awburst_err && csr_awaddr_err);
assign csr_write_type_comb = (csr_if.awsize == 3'b010) ? (csr_if.awaddr[2] ? UPPER32 : LOWER32) : FULL64;

always_ff @(posedge clk) begin
   csr_aw_legal <= ~csr_awerr_comb;
end

//------------------------
// Write response 
//------------------------
always_ff @(posedge clk) begin
   if (~csr_aw_legal) begin
      csr_bresp <= ofs_fim_if_pkg::RESP_SLVERR;
   end else begin
      csr_bresp <= ofs_fim_if_pkg::RESP_OKAY;
   end
end

//--------------------------------------------------------------
// AXI read interface
//--------------------------------------------------------------
typedef enum {RD_IDLE_BIT, RD_CSR_BIT, RD_WAIT_BIT, RD_RESP_BIT, RD_STATE_MAX} t_rd_state_idx;
typedef enum logic [RD_STATE_MAX-1:0] {
   RD_IDLE_STATE = (1 << RD_IDLE_BIT),
   RD_CSR_STATE  = (1 << RD_CSR_BIT),
   RD_WAIT_STATE = (1 << RD_WAIT_BIT),
   RD_RESP_STATE = (1 << RD_RESP_BIT)
} t_rd_state;

t_rd_state rd_state, rd_state_next;

//------------------------
// Read state transition
//------------------------
always_ff @(posedge clk) begin
   if (~rst_n) begin
      rd_state <= RD_IDLE_STATE;
   end else begin
      rd_state <= rd_state_next;
   end
end

always_ff @(posedge clk) begin
   if (~rst_n) begin
      csr_arready <= 1'b0;
      csr_rvalid  <= 1'b0;
      csr_read    <= 1'b0;
   end else begin
      csr_arready <= csr_arready_next;
      csr_rvalid  <= csr_rvalid_next;
      csr_read    <= csr_read_next;
   end
end

always_comb begin
   rd_state_next    = rd_state;
   csr_arready_next = 1'b0;
   csr_rvalid_next  = 1'b0;
   csr_read_next    = 1'b0;

   unique case (1'b1)
      rd_state[RD_IDLE_BIT] : begin
         if (csr_if.arvalid && csr_if.arready) begin
            rd_state_next = RD_CSR_STATE;
         end else begin
            csr_arready_next = 1'b1;
         end
      end

      rd_state[RD_CSR_BIT] : begin
         csr_read_next = ~csr_rerr_comb;
         rd_state_next = RD_WAIT_STATE;
      end

      rd_state[RD_WAIT_BIT] : begin
         if (csr_readdata_valid) begin
            csr_rvalid_next = 1'b1;
            rd_state_next   = RD_RESP_STATE;
         end
      end

      rd_state[RD_RESP_BIT] : begin
         if (csr_if.rvalid && csr_if.rready) begin
            rd_state_next = RD_IDLE_STATE;
            csr_arready_next = 1'b1;
         end else begin
            csr_rvalid_next = 1'b1;
         end
      end

      // synthesis translate_off
      default : begin
         csr_arready_next = 1'bx;
         csr_rvalid_next  = 1'bx;
         csr_read_next    = 1'bx;
      end
      // synthesis translate_on
   endcase
end

//------------------------
// Read address
//------------------------
assign load_ar = rd_state[RD_IDLE_BIT];

always_ff @(posedge clk) begin
   if (load_ar) begin
      csr_arid     <= csr_if.awid;
      csr_raddr    <= csr_if.araddr;
      csr_read_32b <= (csr_if.arsize == 3'b010);

      // only fixed burst of 4B/8B is supported
      csr_arburst_err <= |csr_if.arburst || ~(csr_if.arsize == 3'b010 || csr_if.arsize == 3'b011);
      // only burst length 1 is supported
      csr_arlen_err   <= |csr_if.arlen;
      // check address alignment (assuming awsize is valid, use awsize[0] to differentiate between 32b and 64b access)
      csr_araddr_err  <= |csr_if.araddr[1:0] || (csr_if.arsize[0] && csr_if.araddr[2]);
   end
end

//------------------------
// Read error checking
//------------------------
assign csr_rerr_comb = (csr_arburst_err | csr_arlen_err) || (~csr_arburst_err && csr_araddr_err);

always_ff @(posedge clk) begin
   csr_read_legal <= ~csr_rerr_comb;

   if (~csr_read_legal) begin
      csr_rresp <= ofs_fim_if_pkg::RESP_SLVERR;
   end else begin
      csr_rresp <= ofs_fim_if_pkg::RESP_OKAY;
   end
end

//------------------------
// Read response
//------------------------
always_ff @(posedge clk) begin
   if (csr_readdata_valid) begin
      csr_readdata_reg <= csr_readdata;
   end
end

endmodule

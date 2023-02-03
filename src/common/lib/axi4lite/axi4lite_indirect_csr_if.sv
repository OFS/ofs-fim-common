// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
// Description
//-----------------------------------------------------------------------------
//
//  Indirect access to AXI4-lite CSR interface via CSR
//
//-----------------------------------------------------------------------------

module axi4lite_indirect_csr_if #(
    parameter CMD_W         = 16,   // Indirect CSR command width
    parameter CSR_ADDR_W    = 19,   // Indirect CSR address width
    parameter AXI_ADDR_W    = 19,   // AXI address width
    parameter DATA_W        = 32,   // Data width

    // Derived parameter
    parameter WSTRB_W       = (DATA_W/8)
) (
    // Clocks and Reset
    input  logic                            i_csr_clk,             
    input  logic                            i_csr_rst_n,           

    // Indirect CSR Interface
    input  logic [CMD_W-1:0]                i_csr_cmd,              // Indirect CSR command
    input  logic [CSR_ADDR_W-1:0]           i_csr_addr,             // Indirect CSR address
    input  logic [DATA_W-1:0]               i_csr_writedata,        // Indirect CSR write data
    output logic [DATA_W-1:0]               o_csr_readdata,         // Indirect CSR read data
    output logic                            o_csr_ack,              // Indirect CSR acknowledgment
    output logic [1:0]                      o_csr_rresp,            // Indirect CSR read response
    output logic [1:0]                      o_csr_bresp,            // Indirect CSR write response
   
    // AXI4-lite master Interface
    ofs_fim_axi_lite_if.master              csr_lite_if
);

// Indirect CSR commands
localparam CMD_NOOP     = 2'h0;
localparam CMD_READ     = 2'h1;
localparam CMD_WRITE    = 2'h2;

// Local signals
logic csr_ack;

logic cmd_complete;
logic csr_arvalid, csr_awvalid, csr_wvalid;

logic [AXI_ADDR_W-1:0] csr_addr; 
logic [DATA_W-1:0]     csr_wdata;
logic [DATA_W-1:0]     csr_readdata;
logic [1:0]            csr_rresp, csr_bresp;

//-----------------------
// Assign outputs
//-----------------------
assign o_csr_ack = csr_ack;

// AXI interface
always_comb begin
   csr_lite_if.awvalid = csr_awvalid;
   csr_lite_if.awaddr  = csr_addr;
   csr_lite_if.awprot  = 3'b001;

   csr_lite_if.wvalid  = csr_wvalid;
   csr_lite_if.wdata   = csr_wdata;
   csr_lite_if.wstrb   = {WSTRB_W{1'b1}}; 
   
   csr_lite_if.arvalid = csr_arvalid;
   csr_lite_if.araddr  = csr_addr;
   csr_lite_if.arprot  = 3'b001;

   csr_lite_if.bready  = 1'b1;
   csr_lite_if.rready  = 1'b1;

   o_csr_readdata      = csr_readdata;
   o_csr_rresp         = csr_rresp;
   o_csr_bresp         = csr_bresp;
end

always_ff @(posedge i_csr_clk) begin
   if (~i_csr_rst_n) begin
      csr_readdata <= '0;
      csr_rresp    <= '0;
   end else begin
      if (csr_lite_if.rvalid) begin
         csr_readdata <= csr_lite_if.rdata;
         csr_rresp    <= csr_lite_if.rresp;
      end
   end
end

always_ff @(posedge i_csr_clk) begin
   if (~i_csr_rst_n) begin
      csr_bresp    <= '0;
   end else begin
      if (csr_lite_if.bvalid) begin
         csr_bresp    <= csr_lite_if.bresp;
      end
   end
end

//------------------------------------------
// State definitions for state machine
//------------------------------------------
typedef enum {
   ST_IDLE_BIT,
   ST_WRITE_BIT,
   ST_READ_BIT,
   ST_WAIT_BRESP_BIT,
   ST_WAIT_RRESP_BIT,
   ST_ACK_BIT,
   ST_MAX_BIT
} t_state_idx;

typedef enum logic [ST_MAX_BIT-1:0] {
   ST_IDLE       = (1 << ST_IDLE_BIT),
   ST_WRITE      = (1 << ST_WRITE_BIT),
   ST_READ       = (1 << ST_READ_BIT),
   ST_WAIT_BRESP = (1 << ST_WAIT_BRESP_BIT),
   ST_WAIT_RRESP = (1 << ST_WAIT_RRESP_BIT),
   ST_ACK        = (1 << ST_ACK_BIT)
} t_state;

t_state state;

always_ff @(posedge i_csr_clk) begin
   csr_ack <= 1'b0;
   
   unique case (1'b1) 
      state[ST_IDLE_BIT] : begin
         csr_addr  <= i_csr_addr;
         csr_wdata <= i_csr_writedata;
         
         case (i_csr_cmd[1:0])
             CMD_READ  : state  <= ST_READ;
             CMD_WRITE : state  <= ST_WRITE;
             default   : state  <= ST_IDLE;
         endcase
      end

      state[ST_WRITE_BIT] : begin
         csr_awvalid <= 1'b1;
         csr_wvalid  <= 1'b1; 
         state       <= ST_WAIT_BRESP;
      end

      state[ST_READ_BIT] : begin
         csr_arvalid <= 1'b1;
         state       <= ST_WAIT_RRESP;
      end

      state[ST_WAIT_BRESP_BIT] : begin
         if (csr_lite_if.awready) csr_awvalid <= 1'b0;
         if (csr_lite_if.wready)  csr_wvalid <= 1'b0;
         if (csr_lite_if.bvalid)  state <= ST_ACK;
      end

      state[ST_WAIT_RRESP_BIT] : begin
         if (csr_lite_if.arready) csr_arvalid <= 1'b0;
         if (csr_lite_if.rvalid)  state <= ST_ACK;
      end

      state[ST_ACK_BIT] : begin
         csr_ack <= 1'b1;

         if (i_csr_cmd[1:0] == CMD_NOOP) state <= ST_IDLE;
      end

   // synopsys translate_off
      default : begin
         state <= ST_IDLE;
      end
   // synopsys translate_on

   endcase

   if (~i_csr_rst_n) begin
      state       <= ST_IDLE;
      csr_arvalid <= 1'b0;
      csr_awvalid <= 1'b0;
      csr_wvalid  <= 1'b0;
   end
end


endmodule // axi4lite_indirect_csr_if 

// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// The Peripheral Fabric Adapter (pfa) is a module drives requests and receives 
// responses by translating AXI4-lite interface into Avalon Memory-Mapped (AVMM) 
// interface protocol and vice versa.
// The PFA has two configurations namely pfa_master and pfa_slave. 
// This module describes pfa_master configuration which makes requests.
// Jitendra 
// ***************************************************************************


module pfa_master #(
    // AVMM IF Parameters
    parameter AVMM_ADDR_WIDTH  = 18, 
    parameter AVMM_RDATA_WIDTH = 64, 
    parameter AVMM_WDATA_WIDTH = 64, 

    // AXI4Lite IF Parameters
    parameter AXI4LITE_ADDR_WIDTH  = 18, 
    parameter AXI4LITE_RDATA_WIDTH = 64,
    parameter AXI4LITE_WDATA_WIDTH = 64
)
(
// -----------------------------------------------------------
//  Global signals
// -----------------------------------------------------------
    input   ACLK,           // global clock signal
    input   ARESETn,        // global reset signal, active LOW

// -----------------------------------------------------------
//  Avalon-MM Interface (AVMM)
// -----------------------------------------------------------

    // AVMM Master to Slave Interface
    input                                   avmm_m2s_write,              // valid for write
    input                                   avmm_m2s_read,               // valid for read
    input   [AVMM_ADDR_WIDTH-1:0]           avmm_m2s_address,            // write or read address of a transfer
    input   [AVMM_WDATA_WIDTH-1:0]          avmm_m2s_writedata,          // data for write transfer
    input   [(AVMM_WDATA_WIDTH >> 3)-1:0]   avmm_m2s_byteenable,         // byte-enable signal of write data

    // AVMM Slave to Master Interface
    output                                  avmm_s2m_waitrequest,        // slave requests master to wait 
    output                                  avmm_s2m_writeresponsevalid, // valid write response
    output                                  avmm_s2m_readdatavalid,      // valid read data
    output   [AVMM_RDATA_WIDTH-1:0]         avmm_s2m_readdata,           // data for read transfer

// -----------------------------------------------------------
//  AXI4LITE Interface
// -----------------------------------------------------------

// AXI4Lite Slave to Master Interface: Inputs 
// AXI4Lite Master to Slave Interface: Outputs   

    // Write Address Channel
    input                                       axi4lite_s2m_AWREADY,    // indicates that the slave is ready to accept a write address
    output                                      axi4lite_m2s_AWVALID,    // valid write address and control info
    output  [AXI4LITE_ADDR_WIDTH-1:0]           axi4lite_m2s_AWADDR,     // write address
    output  [2:0]                               axi4lite_m2s_AWPROT,     // protection encoding (access permissions)

    // Write Data Channel
    input                                       axi4lite_s2m_WREADY,     // indicates that the slave can accept the write data
    output                                      axi4lite_m2s_WVALID,     // valid write data and strobes are available
    output  [AXI4LITE_WDATA_WIDTH-1:0]          axi4lite_m2s_WDATA,      // write data
    output  [(AXI4LITE_WDATA_WIDTH >> 3)-1:0]   axi4lite_m2s_WSTRB,      // byte enable i.e. indicates byte lanes that hold valid data

    // Write Response Channel 
    input                                       axi4lite_s2m_BVALID,     // valid write response
    input   [1:0]                               axi4lite_s2m_BRESP,      // status of write transaction 
    output                                      axi4lite_m2s_BREADY,     // indicates that the master can accept a write response

    // Read Address Channel
    input                                       axi4lite_s2m_ARREADY,    // indicates that the slave is ready to accept an read address
    output                                      axi4lite_m2s_ARVALID,    // valid read address and control info
    output  [AXI4LITE_ADDR_WIDTH-1:0]           axi4lite_m2s_ARADDR,     // read address
    output  [2:0]                               axi4lite_m2s_ARPROT,     // protection encoding (access permissions)

    // Read Data Channel
    input                                       axi4lite_s2m_RVALID,     // valid read data
    input   [AXI4LITE_RDATA_WIDTH-1:0]          axi4lite_s2m_RDATA,      // read data
    input   [1:0]                               axi4lite_s2m_RRESP,      // status of read transfer
    output                                      axi4lite_m2s_RREADY      // indicates that the master can accept the read data and response information.

);


// -----------------------------------------------------------------------------
// Local Parameters
// -----------------------------------------------------------------------------
localparam PFAM_FIFO_DEPTH = 3;
localparam PFAM_FIFO_TH = 2**PFAM_FIFO_DEPTH - 3;

// -----------------------------------------------------------------------------
// Packed Struct
// -----------------------------------------------------------------------------
typedef struct packed {
    logic                               wr_valid; 
    logic                               rd_valid; 
    logic   [AVMM_ADDR_WIDTH-1:0]       addr;
    logic   [AVMM_WDATA_WIDTH-1:0]      wrdata;
    logic   [(AVMM_WDATA_WIDTH>>3)-1:0] be;
} pfam_fifo_t;  


// -----------------------------------------------------------------------------
// Internal Signals
// -----------------------------------------------------------------------------
// 0.000
(* dont_merge *) logic aresetn_Q;
(* dont_merge *) logic aresetn_QQ;

// 1.001
logic                                   write_Q, read_Q;
logic   [AVMM_ADDR_WIDTH-1:0]           address_Q;
logic   [AVMM_WDATA_WIDTH-1:0]          writedata_Q;
logic   [(AVMM_WDATA_WIDTH>>3)-1:0]     byteenable_Q;

// 1.0015
pfam_fifo_t                             pfam_fifo_in, pfam_fifo_out;
logic                                   pfam_fifo_ren, pfam_fifo_wen;
logic                                   pfam_fifo_full, pfam_fifo_notempty;
logic                                   pfam_fifo_perr;
logic                                   pfam_fifo_err;
logic                                   axi_wr_ready, axi_rd_ready;
logic                                   pfam_m2s_write, pfam_m2s_read;
logic   [AVMM_ADDR_WIDTH-1:0]           pfam_m2s_addr;
logic   [AVMM_WDATA_WIDTH-1:0]          pfam_m2s_wrdata;
logic   [(AVMM_WDATA_WIDTH>>3)-1:0]     pfam_m2s_be;

// 2.001
logic                                   awready_Q, wready_Q, arready_Q;
logic                                   bvalid_Q, rvalid_Q;
logic   [1:0]                           bresp_Q;
logic   [AXI4LITE_RDATA_WIDTH-1:0]      rdata_Q;
logic   [1:0]                           rresp_Q; 

// 2.002
logic                                   notready;

// 2.003
logic                                   rddataval_pfam, wrrespval_pfam;
logic   [AVMM_RDATA_WIDTH-1:0]          rddata_pfam;
logic                                   waitreq_pfam;

// =============================================================================
// 0.000 Reset pipeline (TIM)
// =============================================================================

always_ff @(posedge ACLK) begin
    aresetn_Q   <= ARESETn;
    aresetn_QQ  <= aresetn_Q;
end

    
// =============================================================================
// 1.000 PFA:   Master to slave path 
//              AVMM ---> AXI4Lite
// =============================================================================

// -----------------------------------------------------------------------------
// 1.001 Stage AVMM Inputs
// -----------------------------------------------------------------------------
always_ff @(posedge ACLK) begin
    read_Q          <= avmm_m2s_read;
    write_Q         <= avmm_m2s_write;
    address_Q       <= avmm_m2s_address;
    writedata_Q     <= avmm_m2s_writedata;
    byteenable_Q    <= avmm_m2s_byteenable;

    // reset valid on RESETn
    if (!aresetn_QQ) begin
        read_Q      <= '0;
        write_Q     <= '0;
    end
end

// -----------------------------------------------------------------------------
// 1.0015 PFA-M Fifo
// -----------------------------------------------------------------------------

// Fifo Inputs
always_comb begin
    //init
    pfam_fifo_in    = '0;

    pfam_fifo_in.rd_valid   = read_Q; 
    pfam_fifo_in.wr_valid   = write_Q; 
    pfam_fifo_in.addr       = address_Q;
    pfam_fifo_in.wrdata     = writedata_Q;
    pfam_fifo_in.be         = byteenable_Q;

    //pfam_fifo_wen           = (read_Q | write_Q) & !pfam_fifo_full; 
    pfam_fifo_wen           = (read_Q | write_Q); 
end

// Fifo Instantiation
bfifo  #(                                       // 0-delay fifo (din in clk0, dout is valid clk1)
    .WIDTH           ($bits(pfam_fifo_t)),      // all outputs are registered
    .DEPTH           (PFAM_FIFO_DEPTH),         //
    .FULL_THRESHOLD  (PFAM_FIFO_TH)             //
)                                                       
pfam_fifo (                                                           
    .fifo_din           (pfam_fifo_in),         // FIFO write data in
    .fifo_wen           (pfam_fifo_wen),        // FIFO write enable
    .fifo_ren           (pfam_fifo_ren),        // FIFO read enable
    .clk                (ACLK),                 // clock
    .Resetb             (aresetn_QQ),           // Reset active low
                                                //--------------------- Output  ------------------
    .fifo_dout          (pfam_fifo_out),        // FIFO read data out registered
    .not_empty          (pfam_fifo_notempty),   // FIFO is not empty
    .full               (pfam_fifo_full),       // FIFO count > FULL_THRESHOLD
    .fifo_err           (pfam_fifo_err),        // FIFO overflow/underflow error
    .fifo_perr          (pfam_fifo_perr)        // FIFO parity error
);


// Fifo Outputs and RdEn Logic
always_comb begin
    // init
    axi_wr_ready    = '0;
    axi_rd_ready    = '0;
    pfam_m2s_write  = '0;
    pfam_m2s_read   = '0;
    pfam_m2s_addr   = '0;
    pfam_m2s_wrdata = '0;
    pfam_m2s_be     = '0;
    pfam_fifo_ren   = '0;

    axi_wr_ready    = (axi4lite_s2m_AWREADY &  axi4lite_s2m_WREADY);
    axi_rd_ready    = axi4lite_s2m_ARREADY;
    // Fifo Rd Enable for Wr Op
    if (axi_wr_ready && pfam_fifo_out.wr_valid) begin
        pfam_m2s_write  = pfam_fifo_out.wr_valid;
        pfam_m2s_addr   = pfam_fifo_out.addr;
        pfam_m2s_wrdata = pfam_fifo_out.wrdata;
        pfam_m2s_be     = pfam_fifo_out.be;

        pfam_fifo_ren   = '1;
    end

    // Fifo Rd Enable for Rd Op
    if (axi_rd_ready && pfam_fifo_out.rd_valid) begin
        pfam_m2s_read   = pfam_fifo_out.rd_valid;
        pfam_m2s_addr   = pfam_fifo_out.addr;

        pfam_fifo_ren   = '1;
    end

end

// -----------------------------------------------------------------------------
// 1.004 Output signals at axi4lite if (Just Renaming)
// -----------------------------------------------------------------------------

// write address channel
assign axi4lite_m2s_AWVALID  = pfam_m2s_write;
assign axi4lite_m2s_AWADDR   = pfam_m2s_addr;
assign axi4lite_m2s_AWPROT   = '0; // always set to 0. i.e. set to unprivileged, secured and data access

// write data channel
assign axi4lite_m2s_WVALID   = pfam_m2s_write;
assign axi4lite_m2s_WDATA    = pfam_m2s_wrdata;
assign axi4lite_m2s_WSTRB    = pfam_m2s_be;

// write response channel
assign axi4lite_m2s_BREADY   = '1;  // Master is always ready receive write response

// read address channel
assign axi4lite_m2s_ARVALID  = pfam_m2s_read;
assign axi4lite_m2s_ARADDR   = pfam_m2s_addr;
assign axi4lite_m2s_ARPROT   = '0; // always set to 0. i.e. set to unprivileged, secured and data access

// read data channel
assign axi4lite_m2s_RREADY   = '1; // Master is always ready to receive read response

// =============================================================================
// 2.000 PFA:   Slave to master path 
//              AXI4Lite ---> AVMM
// =============================================================================
 
// -----------------------------------------------------------------------------
// 2.001 Stage AXI4Lite Inputs
// -----------------------------------------------------------------------------

always_ff @(posedge ACLK) begin
 
    // write address channel
    awready_Q   <= axi4lite_s2m_AWREADY;
    
    // write data channel
    wready_Q    <= axi4lite_s2m_WREADY;

    // write response channel
    bvalid_Q    <= axi4lite_s2m_BVALID;
    bresp_Q     <= axi4lite_s2m_BRESP;  // not driven to avmm if

    // read address channel
    arready_Q   <= axi4lite_s2m_ARREADY;

    // read data channel
    rvalid_Q    <= axi4lite_s2m_RVALID;
    rdata_Q     <= axi4lite_s2m_RDATA;
    rresp_Q     <= axi4lite_s2m_RRESP; // not driven to avmm if

    // reset valid on RESETn
    if (!aresetn_QQ) begin
        awready_Q   <= '0;
        wready_Q    <= '0;
        bvalid_Q    <= '0;
        arready_Q   <= '0;
        rvalid_Q    <= '0;
    end

end

// -----------------------------------------------------------------------------
// 2.002 waitreq logic 
// -----------------------------------------------------------------------------
// Forces the master to wait until the interconnect is ready to proceed 
// with the transfer
//assign notready = ~awready_Q || & arready_Q & pfam_fifo_full);
assign notready = pfam_fifo_full;

// -----------------------------------------------------------------------------
// 2.003 Stage signals before avmm if
// -----------------------------------------------------------------------------

always_ff @(posedge ACLK) begin
    rddataval_pfam  <= rvalid_Q;
    rddata_pfam     <= rdata_Q;
    wrrespval_pfam  <= bvalid_Q;
    waitreq_pfam    <= notready;

    // reset valids on RESETn
    if (!aresetn_QQ) begin
        rddataval_pfam  <= '0;
        wrrespval_pfam  <= '0;
        waitreq_pfam    <= '0;
    end
end

// -----------------------------------------------------------------------------
// 2.004 Output signals at avmm if
// -----------------------------------------------------------------------------
assign  avmm_s2m_readdatavalid       = rddataval_pfam;
assign  avmm_s2m_readdata            = rddata_pfam;
assign  avmm_s2m_writeresponsevalid  = wrrespval_pfam;
assign  avmm_s2m_waitrequest         = waitreq_pfam;


endmodule

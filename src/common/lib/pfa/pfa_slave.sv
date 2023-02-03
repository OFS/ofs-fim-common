// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// The Peripheral Fabric Adapter (pfa) is a module drives requests and receives 
// responses by translating AXI4-lite interface into Avalon Memory-Mapped (AVMM) 
// interface protocol and vice versa.
// The PFA has two configurations namely pfa_master and pfa_slave. 
// This module describes pfa_slave configuration which responds to the requests.
//
// Design implementation is based on following assumptions:
//      1.  Write Address (AW) and Write Data (W) signals of AXI4-Lite may not arrive 
//          on PFA slave at the same time as they are independent channels.
//      2.  Once a Master requests Read, it is always in ‘Ready’ state to receive Read Data.
//      3.  PFA slave does not receive simultaneous Read and Write requests. 
// ***************************************************************************


module pfa_slave #(
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

    // AVMM Slave to Master Interface
    input                                   avmm_s2m_waitrequest,        // slave requests master to wait 
    input                                   avmm_s2m_writeresponsevalid, // valid write response
    input                                   avmm_s2m_readdatavalid,      // valid read data
    input   [AVMM_RDATA_WIDTH-1:0]          avmm_s2m_readdata,           // data for read transfer

    // AVMM Master to Slave Interface
    output                                  avmm_m2s_write,              // valid for write
    output                                  avmm_m2s_read,               // valid for read
    output   [AVMM_ADDR_WIDTH-1:0]          avmm_m2s_address,            // write or read address of a transfer
    output   [AVMM_WDATA_WIDTH-1:0]         avmm_m2s_writedata,          // data for write transfer
    output   [(AVMM_WDATA_WIDTH >> 3)-1:0]  avmm_m2s_byteenable,         // byte-enable signal of write data


// -----------------------------------------------------------
//  AXI4LITE Interface
// -----------------------------------------------------------

// AXI4Lite Master to Slave Interface: Inputs   
// AXI4Lite Slave to Master Interface: Outputs 

    // Write Address Channel
    input                                       axi4lite_m2s_AWVALID,    // valid write address and control info
    input   [AXI4LITE_ADDR_WIDTH-1:0]           axi4lite_m2s_AWADDR,     // write address
    input   [2:0]                               axi4lite_m2s_AWPROT,     // protection encoding (access permissions)
    output                                      axi4lite_s2m_AWREADY,    // indicates that the slave is ready to accept a write address

    // Write Data Channel
    input                                       axi4lite_m2s_WVALID,     // valid write data and strobes are available
    input   [AXI4LITE_WDATA_WIDTH-1:0]          axi4lite_m2s_WDATA,      // write data
    input   [(AXI4LITE_WDATA_WIDTH >> 3)-1:0]   axi4lite_m2s_WSTRB,      // byte enable i.e. indicates byte lanes that hold valid data
    output                                      axi4lite_s2m_WREADY,     // indicates that the slave can accept the write data

    // Write Response Channel 
    input                                       axi4lite_m2s_BREADY,     // indicates that the master can accept a write response
    output                                      axi4lite_s2m_BVALID,     // valid write response
    output  [1:0]                               axi4lite_s2m_BRESP,      // status of write transaction 

    // Read Address Channel
    input                                       axi4lite_m2s_ARVALID,    // valid read address and control info
    input   [AXI4LITE_ADDR_WIDTH-1:0]           axi4lite_m2s_ARADDR,     // read address
    input   [2:0]                               axi4lite_m2s_ARPROT,     // protection encoding (access permissions)
    output                                      axi4lite_s2m_ARREADY,    // indicates that the slave is ready to accept an read address

    // Read Data Channel
    input                                       axi4lite_m2s_RREADY,      // indicates that the master can accept the read data and response information.
    output                                      axi4lite_s2m_RVALID,     // valid read data
    output  [AXI4LITE_RDATA_WIDTH-1:0]          axi4lite_s2m_RDATA,      // read data
    output  [1:0]                               axi4lite_s2m_RRESP      // status of read transfer

);

// -----------------------------------------------------------------------------
// Local Parameters
// -----------------------------------------------------------------------------
//localparam AXI4LITE_WSTRB_WIDTH = AXI4LITE_WDATA_WIDTH >> 3;
localparam PFAS_ADDR_FIFO_DEPTH = 3;
localparam PFAS_ADDR_FIFO_TH = 2**PFAS_ADDR_FIFO_DEPTH - 3;
localparam PFAS_WDATA_FIFO_DEPTH = 3;
localparam PFAS_WDATA_FIFO_TH = 2**PFAS_WDATA_FIFO_DEPTH - 3;


// -----------------------------------------------------------------------------
// Packed Struct
// -----------------------------------------------------------------------------
typedef struct packed {
    logic                               wr_valid; 
    logic                               rd_valid; 
    logic   [AXI4LITE_ADDR_WIDTH-1:0]   addr;
} pfas_addr_fifo_t;  

typedef struct packed {
    logic                                       valid; 
    logic   [AXI4LITE_WDATA_WIDTH-1:0]          wr_data;
    logic   [(AXI4LITE_WDATA_WIDTH >> 3)-1:0]   wr_strb;
} pfas_wrdata_fifo_t;  


// -----------------------------------------------------------------------------
// Internal Signals
// -----------------------------------------------------------------------------
// 0.000
(* dont_merge *) logic aresetn_Q;
(* dont_merge *) logic aresetn_QQ;

// 1.001
logic                                       awvalid_Q, wvalid_Q, arvalid_Q;
logic   [AXI4LITE_ADDR_WIDTH-1:0]           awaddr_Q, araddr_Q; 
logic   [2:0]                               awprot_Q, arprot_Q;                    
logic   [AXI4LITE_WDATA_WIDTH-1:0]          wdata_Q;
logic   [(AXI4LITE_WDATA_WIDTH >> 3)-1:0]   wstrb_Q;
logic                                       bready_Q, rready_Q;

// 1.002
logic   [AXI4LITE_ADDR_WIDTH-1:0]           pfas_addr;

// 1.0031
logic                                       pfas_addr_fifo_wen, pfas_addr_fifo_ren;
pfas_addr_fifo_t                            pfas_addr_fifo_in, pfas_addr_fifo_out;
logic                                       pfas_addr_fifo_full;
logic                                       pfas_addr_fifo_notempty;
logic   [1:0]                               pfas_addr_fifo_ecc;
logic                                       pfas_addr_fifo_err;

// 1.0032
logic                                       pfas_wrdata_fifo_wen, pfas_wrdata_fifo_ren;
pfas_wrdata_fifo_t                          pfas_wrdata_fifo_in, pfas_wrdata_fifo_out; 
logic                                       pfas_wrdata_fifo_full;
logic                                       pfas_wrdata_fifo_notempty;
logic   [1:0]                               pfas_wrdata_fifo_ecc;
logic                                       pfas_wrdata_fifo_err;

// 1.004
logic                                       pfas_m2s_read, pfas_m2s_write;
logic   [AXI4LITE_ADDR_WIDTH-1:0]           pfas_m2s_addr;
logic   [AXI4LITE_WDATA_WIDTH-1:0]          pfas_m2s_wr_data;
logic   [(AXI4LITE_WDATA_WIDTH >> 3)-1:0]   pfas_m2s_be;

// 1.005
logic                                       pfas_m2s_read_Q, pfas_m2s_write_Q;
logic   [AXI4LITE_ADDR_WIDTH-1:0]           pfas_m2s_addr_Q;
logic   [AXI4LITE_WDATA_WIDTH-1:0]          pfas_m2s_wr_data_Q;
logic   [(AXI4LITE_WDATA_WIDTH >> 3)-1:0]   pfas_m2s_be_Q;

// 2.001
logic                                       wait_req_Q;
logic                                       wr_resp_val_Q;
logic                                       rd_data_val_Q;
logic   [AVMM_RDATA_WIDTH-1:0]              rd_data_Q;

// 2.002
logic                                       pfas_addr_rdy;
logic                                       pfas_wrdata_rdy;

// 2.003
logic                                       pfas_awready, pfas_wready;
logic                                       pfas_arready;
logic                                       pfas_bvalid, pfas_rvalid;
logic   [1:0]                               pfas_bresp, pfas_rresp;
logic   [AVMM_RDATA_WIDTH-1:0]              pfas_rdata;

// =============================================================================
// 0.000 Reset pipeline (TIM)
// =============================================================================

always_ff @(posedge ACLK) begin
    aresetn_Q   <= ARESETn;
    aresetn_QQ  <= aresetn_Q;
end

    
// =============================================================================
// 1.000 PFA:   Master to slave path 
//              AXI4Lite ---> AVMM
// =============================================================================

// -----------------------------------------------------------------------------
// 1.001 Stage AXI4Lite Inputs
// -----------------------------------------------------------------------------
always_ff @(posedge ACLK) begin
    
    // Write Address Channel
    awvalid_Q   <= axi4lite_m2s_AWVALID;
    awaddr_Q    <= axi4lite_m2s_AWADDR;
    awprot_Q    <= axi4lite_m2s_AWPROT;

    // Write Data Channel
    wvalid_Q    <= axi4lite_m2s_WVALID;
    wdata_Q     <= axi4lite_m2s_WDATA;
    wstrb_Q     <= axi4lite_m2s_WSTRB;
    
    // Write Response Channel 
    bready_Q    <= axi4lite_m2s_BREADY;

    // Read Address Channel
    arvalid_Q   <= axi4lite_m2s_ARVALID;
    araddr_Q    <= axi4lite_m2s_ARADDR;
    arprot_Q    <= axi4lite_m2s_ARPROT;

    // Read Data Channel
    rready_Q    <= axi4lite_m2s_RREADY;
    
    // Reset valids on ARESETn
    if (!aresetn_QQ) begin
        awvalid_Q   <= '0; 
        wvalid_Q    <= '0;
        bready_Q    <= '0;
        arvalid_Q   <= '0; 
        rready_Q    <= '0;
    end
end

// -----------------------------------------------------------------------------
// 1.002 Address MUX Logic
// -----------------------------------------------------------------------------

// Assumption - Write Address and Read Address signals of AXI4-Lite do not arrive 
// on PFA slave at the same time even though they are independent channels. 

always_comb begin    
    pfas_addr = '0;                             // init (default)    
    if (awvalid_Q)  pfas_addr   = awaddr_Q;     // write address
    if (arvalid_Q)  pfas_addr   = araddr_Q;     // read address
end

// -----------------------------------------------------------------------------
// 1.0031 Address Fifo
// -----------------------------------------------------------------------------

always_comb begin
    pfas_addr_fifo_in   = '0; // init
    pfas_addr_fifo_in.rd_valid  = arvalid_Q;
    pfas_addr_fifo_in.wr_valid  = awvalid_Q;
    pfas_addr_fifo_in.addr      = pfas_addr;

    pfas_addr_fifo_wen = (awvalid_Q | arvalid_Q); 
end

quartus_bfifo #(
    .WIDTH              ($bits(pfas_addr_fifo_t)), 
    .DEPTH              (PFAS_ADDR_FIFO_DEPTH), 
    .FULL_THRESHOLD     (PFAS_ADDR_FIFO_TH), 
    .REG_OUT            (1), 
    .RAM_STYLE          ("AUTO"),
    .ECC_EN             (0)
)  
pfas_addr_fifo (
    .fifo_din           (pfas_addr_fifo_in),        // FIFO write data in
    .fifo_wen           (pfas_addr_fifo_wen),       // FIFO write enable
    .fifo_ren           (pfas_addr_fifo_ren),       // FIFO read enable
    .clk                (ACLK),                     // clock
    .Resetb             (aresetn_QQ),               // Reset active low

    .fifo_dout          (pfas_addr_fifo_out),       // FIFO read data out registered
    .almost_full        (pfas_addr_fifo_full),      // FIFO count > FULL_THRESHOLD
    .not_empty          (pfas_addr_fifo_notempty),  // FIFO is not empty

    .fifo_eccstatus     (pfas_addr_fifo_ecc),       // FIFO parity error
    .fifo_err           (pfas_addr_fifo_err)        // FIFO overflow/underflow error
);



// -----------------------------------------------------------------------------
// 1.0032 Write Data Fifo
// -----------------------------------------------------------------------------

always_comb begin
    pfas_wrdata_fifo_in = '0; // init
    pfas_wrdata_fifo_in.valid       = wvalid_Q;
    pfas_wrdata_fifo_in.wr_data     = wdata_Q;
    pfas_wrdata_fifo_in.wr_strb     = wstrb_Q;

    pfas_wrdata_fifo_wen = wvalid_Q;

end


quartus_bfifo #(
    .WIDTH              ($bits(pfas_wrdata_fifo_t)), 
    .DEPTH              (PFAS_WDATA_FIFO_DEPTH), 
    .FULL_THRESHOLD     (PFAS_WDATA_FIFO_TH), 
    .REG_OUT            (1), 
    .RAM_STYLE          ("AUTO"),
    .ECC_EN             (0)
)  
pfas_wrdata_fifo (
    .fifo_din           (pfas_wrdata_fifo_in),             // FIFO write data in
    .fifo_wen           (pfas_wrdata_fifo_wen),       // FIFO write enable
    .fifo_ren           (pfas_wrdata_fifo_ren),       // FIFO read enable
    .clk                (ACLK),                     // clock
    .Resetb             (aresetn_QQ),               // Reset active low

    .fifo_dout          (pfas_wrdata_fifo_out),            // FIFO read data out registered
    .almost_full        (pfas_wrdata_fifo_full),      // FIFO count > FULL_THRESHOLD
    .not_empty          (pfas_wrdata_fifo_notempty),  // FIFO is not empty

    .fifo_eccstatus     (pfas_wrdata_fifo_ecc),       // FIFO parity error
    .fifo_err           (pfas_wrdata_fifo_err)        // FIFO overflow/underflow error
);


// -----------------------------------------------------------------------------
// 1.004    Logic for Read Enable of Addr-Fifo and WrData-Fifo. 
//          WrRd-DeMux Logic
// -----------------------------------------------------------------------------
always_comb begin
    
    // Init/default 
    pfas_m2s_read       = '0;
    pfas_m2s_write      = '0;
    pfas_m2s_addr       = '0;
    pfas_m2s_wr_data    = '0;
    pfas_m2s_be         = '0;

    pfas_addr_fifo_ren      = '0;
    pfas_wrdata_fifo_ren    = '0;

    // Rd-addr 
    if (pfas_addr_fifo_out.rd_valid && pfas_addr_fifo_notempty) begin
        pfas_m2s_read       = '1;
        pfas_m2s_addr       = pfas_addr_fifo_out.addr;

        pfas_addr_fifo_ren  = '1;
    end

    // Wr-addr and Wr-Data
    if (pfas_addr_fifo_out.wr_valid && pfas_wrdata_fifo_out.valid && pfas_wrdata_fifo_notempty) begin
        pfas_m2s_write      = '1;
        pfas_m2s_addr       = pfas_addr_fifo_out.addr;
        pfas_m2s_wr_data    = pfas_wrdata_fifo_out.wr_data;
        pfas_m2s_be         = pfas_wrdata_fifo_out.wr_strb;

        pfas_addr_fifo_ren      = '1;
        pfas_wrdata_fifo_ren    = '1;
    end


end

// -----------------------------------------------------------------------------
// 1.005 Staged Signals before AVMM Interface
// -----------------------------------------------------------------------------

always_ff @(posedge ACLK) begin
    pfas_m2s_read_Q         <= pfas_m2s_read;
    pfas_m2s_write_Q        <= pfas_m2s_write;
    pfas_m2s_addr_Q         <= pfas_m2s_addr;
    pfas_m2s_wr_data_Q      <= pfas_m2s_wr_data;
    pfas_m2s_be_Q           <= pfas_m2s_be;    

    // Reset valids on ARESETn
    if (!aresetn_QQ) begin
        pfas_m2s_read_Q     <= '0;
        pfas_m2s_write_Q    <= '0;
    end

end

// -----------------------------------------------------------------------------
// 1.006 Output Signals at AVMM Interface
// -----------------------------------------------------------------------------

assign avmm_m2s_address     = pfas_m2s_addr_Q;
assign avmm_m2s_write       = pfas_m2s_write_Q;
assign avmm_m2s_read        = pfas_m2s_read_Q;
assign avmm_m2s_writedata   = pfas_m2s_wr_data_Q;
assign avmm_m2s_byteenable  = pfas_m2s_be_Q;


// =============================================================================
// 2.000 PFA:   Slave to master path 
//              AVMM ---> AXI4Lite
// =============================================================================
 

// -----------------------------------------------------------------------------
// 2.001 Stage AVMM Inputs
// -----------------------------------------------------------------------------
always_ff @(posedge ACLK) begin
    wait_req_Q      <= avmm_s2m_waitrequest;
    wr_resp_val_Q   <= avmm_s2m_writeresponsevalid;
    rd_data_val_Q   <= avmm_s2m_readdatavalid;
    rd_data_Q       <= avmm_s2m_readdata;
    
    // Reset valids on ARESETn
    if (!aresetn_QQ) begin
        wait_req_Q      <= '0;
        wr_resp_val_Q   <= '0;
        rd_data_val_Q   <= '0;
    end
end

// -----------------------------------------------------------------------------
// 2.002 Read/Write Ready & BRESP Logic
// -----------------------------------------------------------------------------
// Set ready signals to 1 only when Corresponding Fifo is not full OR
// there is no waitrequest from slave 
assign pfas_addr_rdy  = ~(wait_req_Q & pfas_addr_fifo_full);  // For both Rd and Wr addr rdy signals
assign pfas_wrdata_rdy  = ~(wait_req_Q & pfas_wrdata_fifo_full);

// set bresp to 0 (i.e. OKAY) when 

// -----------------------------------------------------------------------------
// 2.003 Staged Signals before AXI4Lite Interface
// -----------------------------------------------------------------------------
always_ff @(posedge ACLK) begin
    // write addr channel
    pfas_awready    <= pfas_addr_rdy;

    // write data channel
    pfas_wready     <= pfas_wrdata_rdy;

    // write response channel
    pfas_bvalid     <= wr_resp_val_Q;
    pfas_bresp      <= '0;  // always to set to 2'b00 state (i.e. OKAY - Normal Access Success)

    // read addr channel
    pfas_arready    <= pfas_addr_rdy;

    // read data channel
    pfas_rvalid     <= rd_data_val_Q;
    pfas_rdata      <= rd_data_Q;
    pfas_rresp      <= '0;  // always to set to 2'b00 state (i.e. OKAY - Normal Access Success)

    // Reset valids on ARESETn
    if (!aresetn_QQ) begin
        pfas_awready    <= '0;
        pfas_wready     <= '0;
        pfas_arready    <= '0;
        pfas_bvalid     <= '0;
        pfas_rvalid     <= '0;
    end
end


// -----------------------------------------------------------------------------
// 2.004 Output Signals at AXI4Lite Interface
// -----------------------------------------------------------------------------

// write address channel
assign axi4lite_s2m_AWREADY = pfas_awready;

// write data channel
assign axi4lite_s2m_WREADY  = pfas_wready;

// write response channel
assign axi4lite_s2m_BVALID  = pfas_bvalid;
assign axi4lite_s2m_BRESP   = pfas_bresp;

// read address channel
assign axi4lite_s2m_ARREADY = pfas_arready;

// read data channel
assign axi4lite_s2m_RVALID  = pfas_rvalid;
assign axi4lite_s2m_RDATA   = pfas_rdata;
assign axi4lite_s2m_RRESP   = pfas_rresp;

endmodule

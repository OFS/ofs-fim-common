// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// AXI write channel pipeline register
// 
//-----------------------------------------------------------------------------

`timescale 1 ps / 1 ps
module axi_write_register 
#( 
    // Register mode for write address channel
    parameter AW_REG_MODE          = 1, // 0: skid buffer 1: simple buffer 2: bypass
    // Register mode for write data channel
    parameter W_REG_MODE           = 0, // 0: skid buffer 1: simple buffer 2: bypass
    // Regiter mode for write response channel
    parameter B_REG_MODE           = 1, // 0: skid buffer 1: simple buffer 2: bypass
    
    // Enable awuser signal on register output
    parameter ENABLE_AWUSER        = 0,
    // Enable wuser signal on register output
    parameter ENABLE_WUSER         = 0,
    // Enable buser signal on register output
    parameter ENABLE_BUSER         = 0,
  
    // Width of ID signal on write address channel
    parameter AWID_WIDTH = 10,
    // Width of address signal on write address channel
    parameter AWADDR_WIDTH = 20,
    // Width of awuser signal on write address channel
    parameter AWUSER_WIDTH = 1,
    
    // Width of data signal on write data channel
    parameter WDATA_WIDTH = 256,
    // Width of wstrb signal on write data channel
    parameter WSTRB_WIDTH = (WDATA_WIDTH/8-1),
    // Width of wuser signal on write data channel
    parameter WUSER_WIDTH = 1,
    
    // Width of buser signal on write response channel
    parameter BUSER_WIDTH = 1
)(
    input                         clk,
    input                         rst_n,

    // Slave interface
       /*Write address channel*/
    output logic                       s_awready,
    input  logic                       s_awvalid,
    input  logic [AWID_WIDTH-1:0]      s_awid,
    input  logic [AWADDR_WIDTH-1:0]    s_awaddr,
    input  logic [7:0]                 s_awlen,
    input  logic [2:0]                 s_awsize,
    input  logic [1:0]                 s_awburst,
    input  logic                       s_awlock,
    input  logic [3:0]                 s_awcache,
    input  logic [2:0]                 s_awprot,
    input  logic [3:0]                 s_awqos,
    input  logic [3:0]                 s_awregion,
    input  logic [AWUSER_WIDTH-1:0]    s_awuser,

       /*Write data channel*/
    output logic                       s_wready,
    input  logic                       s_wvalid,
    input  logic [WDATA_WIDTH-1:0]     s_wdata,
    input  logic [(WDATA_WIDTH/8-1):0] s_wstrb,
    input  logic [2:0]                 s_wlast,
    input  logic [WUSER_WIDTH-1:0]     s_wuser,

       /*Write response channel*/
    input  logic                       s_bready,
    output logic                       s_bvalid,
    output logic [AWID_WIDTH-1:0]      s_bid,
    output logic [1:0]                 s_bresp,
    output logic [BUSER_WIDTH-1:0]     s_buser,

    // Master interface
       /*Write address channel*/
    input  logic                       m_awready,
    output logic                       m_awvalid,
    output logic [AWID_WIDTH-1:0]      m_awid,
    output logic [AWADDR_WIDTH-1:0]    m_awaddr,
    output logic [7:0]                 m_awlen,
    output logic [2:0]                 m_awsize,
    output logic [1:0]                 m_awburst,
    output logic                       m_awlock,
    output logic [3:0]                 m_awcache,
    output logic [2:0]                 m_awprot,
    output logic [3:0]                 m_awqos,
    output logic [3:0]                 m_awregion,
    output logic [AWUSER_WIDTH-1:0]    m_awuser,

       /*Write data channel*/
    input  logic                       m_wready,
    output logic                       m_wvalid,
    output logic [WDATA_WIDTH-1:0]     m_wdata,
    output logic [(WDATA_WIDTH/8-1):0] m_wstrb,
    output logic [2:0]                 m_wlast,
    output logic [WUSER_WIDTH-1:0]     m_wuser,

       /*Write response channel*/
    output logic                       m_bready,
    input  logic                       m_bvalid,
    input  logic [AWID_WIDTH-1:0]      m_bid,
    input  logic [1:0]                 m_bresp,
    input  logic [BUSER_WIDTH-1:0]     m_buser
);

generate 
if (AW_REG_MODE == 0) begin 
    // --------------------------------------
    // skid buffer
    // --------------------------------------
    // Registers & signals
    logic                       s_awvalid_reg   /* synthesis preserve noprune */;
    logic [AWID_WIDTH-1:0]      s_awid_reg      /* synthesis preserve noprune */;
    logic [AWADDR_WIDTH-1:0]    s_awaddr_reg    /* synthesis preserve noprune */;
    logic [7:0]                 s_awlen_reg     /* synthesis preserve noprune */;
    logic [2:0]                 s_awsize_reg    /* synthesis preserve noprune */;
    logic [1:0]                 s_awburst_reg   /* synthesis preserve noprune */;
    logic                       s_awlock_reg    /* synthesis preserve noprune */;
    logic [3:0]                 s_awcache_reg   /* synthesis preserve noprune */;
    logic [2:0]                 s_awprot_reg    /* synthesis preserve noprune */;
    logic [3:0]                 s_awqos_reg     /* synthesis preserve noprune */;
    logic [3:0]                 s_awregion_reg  /* synthesis preserve noprune */;
    logic [AWUSER_WIDTH-1:0]    s_awuser_reg    /* synthesis preserve noprune */;

    logic                       s_awready_reg   /* synthesis preserve noprune */;
    logic                       s_awready_reg_dup;
    logic                       aw_use_reg;

    logic                       m_awvalid_pre;
    logic [AWID_WIDTH-1:0]      m_awid_pre;
    logic [AWADDR_WIDTH-1:0]    m_awaddr_pre;
    logic [7:0]                 m_awlen_pre;
    logic [2:0]                 m_awsize_pre;
    logic [1:0]                 m_awburst_pre;
    logic                       m_awlock_pre;
    logic [3:0]                 m_awcache_pre;
    logic [2:0]                 m_awprot_pre;
    logic [3:0]                 m_awqos_pre;
    logic [3:0]                 m_awregion_pre;
    logic [AWUSER_WIDTH-1:0]    m_awuser_pre;

    logic                       m_awvalid_reg;
    logic [AWID_WIDTH-1:0]      m_awid_reg;
    logic [AWADDR_WIDTH-1:0]    m_awaddr_reg;
    logic [7:0]                 m_awlen_reg;
    logic [2:0]                 m_awsize_reg;
    logic [1:0]                 m_awburst_reg;
    logic                       m_awlock_reg;
    logic [3:0]                 m_awcache_reg;
    logic [2:0]                 m_awprot_reg;
    logic [3:0]                 m_awqos_reg;
    logic [3:0]                 m_awregion_reg;
    logic [AWUSER_WIDTH-1:0]    m_awuser_reg;

    // --------------------------------------
    // Pipeline stage
    //
    // s_tready is delayed by one cycle, master will see tready assertions one cycle later.
    // Buffer the data when tready transitions from high->low
    //
    // This implementation buffers idle cycles should tready transition on such cycles. 
    //     i.e. It doesn't take in new data from s_* even though m_tvalid_reg=0 or when m_tready=0
    // This is a potential cause for throughput loss.
    // Not buffering idle cycles costs logic on the tready path.
    // --------------------------------------
    assign s_awready_pre = (m_awready || ~m_awvalid);
 
    always @(posedge clk) begin
      if (~rst_n) begin
        s_awready_reg     <=  1'b0;
        s_awready_reg     <=  1'b0;
      end else begin
        s_awready_reg     <=  s_awready_pre;
        s_awready_reg_dup <=  s_awready_pre;
      end
    end
    
    // --------------------------------------
    // On the first cycle after reset, the pass-through
    // must not be used or downstream logic may sample
    // the same command twice because of the delay in
    // transmitting a falling waitrequest.
    //
    // Using the registered command works on the condition
    // that downstream logic deasserts waitrequest
    // immediately after reset, which is true of the 
    // next stage in this bridge.
    // --------------------------------------			    

    // Check whether to drive the output with buffer registers when output is ready
    always @(posedge clk) begin
       if (~rst_n) begin
          aw_use_reg <= 1'b1;
       end else if (s_awready_pre) begin
          // stop using the buffer when s_aweady_pre is high (m_awready=1 or m_awvalid=0)
          aw_use_reg <= 1'b0;
       end else if (~s_awready_pre && s_awready_reg) begin
          aw_use_reg <= 1'b1;
       end
    end
    
    // Buffer registers    
    always @(posedge clk) begin
       if (~rst_n) begin
          s_awvalid_reg <= 1'b0;
       end else begin
          if (s_awready_reg_dup) 
             s_awvalid_reg <= s_awvalid;
       end
    end
    
    always @(posedge clk) begin
       if (s_awready_reg_dup) begin
          s_awid_reg     <=  s_awid;
          s_awaddr_reg   <=  s_awaddr;
          s_awlen_reg    <=  s_awlen;
          s_awsize_reg   <=  s_awsize;
          s_awburst_reg  <=  s_awburst;
          s_awlock_reg   <=  s_awlock;
          s_awcache_reg  <=  s_awcache;
          s_awprot_reg   <=  s_awprot;
          s_awqos_reg    <=  s_awqos;
          s_awregion_reg <=  s_awregion;
          s_awuser_reg   <=  s_awuser; 
       end
    end
   
   // Output selection (between buffer register and input)
   always_comb begin
      if (aw_use_reg) begin
         m_awvalid_pre  =  s_awvalid_reg;
         m_awid_pre     =  s_awid_reg;
         m_awaddr_pre   =  s_awaddr_reg;
         m_awlen_pre    =  s_awlen_reg;
         m_awsize_pre   =  s_awsize_reg;
         m_awburst_pre  =  s_awburst_reg;
         m_awlock_pre   =  s_awlock_reg;
         m_awcache_pre  =  s_awcache_reg;
         m_awprot_pre   =  s_awprot_reg;
         m_awqos_pre    =  s_awqos_reg;
         m_awregion_pre =  s_awregion_reg;
         m_awuser_pre   =  s_awuser_reg;
      end else begin
         m_awvalid_pre  =  s_awvalid;
         m_awid_pre     =  s_awid;
         m_awaddr_pre   =  s_awaddr;
         m_awlen_pre    =  s_awlen;
         m_awsize_pre   =  s_awsize;
         m_awburst_pre  =  s_awburst;
         m_awlock_pre   =  s_awlock;
         m_awcache_pre  =  s_awcache;
         m_awprot_pre   =  s_awprot;
         m_awqos_pre    =  s_awqos;
         m_awregion_pre =  s_awregion;
         m_awuser_pre   =  s_awuser; 
      end
   end
     
   // Generate ready and valid signals
   always @(posedge clk) begin
      if (~rst_n) begin
         m_awvalid_reg <= 1'b0;
      end else if (s_awready_pre) begin
         m_awvalid_reg <= m_awvalid_pre;
      end
   end
   
   // Register AXI signals
   always @(posedge clk) begin
      if (s_awready_pre) begin
         m_awid_reg      <=  m_awid_pre;
         m_awaddr_reg    <=  m_awaddr_pre;
         m_awlen_reg     <=  m_awlen_pre;
         m_awsize_reg    <=  m_awsize_pre;
         m_awburst_reg   <=  m_awburst_pre;
         m_awlock_reg    <=  m_awlock_pre;
         m_awcache_reg   <=  m_awcache_pre;
         m_awprot_reg    <=  m_awprot_pre;
         m_awqos_reg     <=  m_awqos_pre;
         m_awregion_reg  <=  m_awregion_pre;
         m_awuser_reg    <=  m_awuser_pre;
      end
   end

   // Output assignment
   assign s_awready  =  s_awready_reg;
   assign m_awvalid  =  m_awvalid_reg;
   assign m_awid     =  m_awid_reg;
   assign m_awaddr   =  m_awaddr_reg;
   assign m_awlen    =  m_awlen_reg;
   assign m_awsize   =  m_awsize_reg;
   assign m_awburst  =  m_awburst_reg;
   assign m_awlock   =  m_awlock_reg;
   assign m_awcache  =  m_awcache_reg;
   assign m_awprot   =  m_awprot_reg;
   assign m_awqos    =  m_awqos_reg;
   assign m_awregion =  m_awregion_reg;
   assign m_awuser   =  ENABLE_AWUSER ? m_awuser_reg : '0;

end else if (AW_REG_MODE == 1) begin 
   // --------------------------------------
   // Simple pipeline register with bubble cycle
   // --------------------------------------
   logic                       s_awready_reg;
   logic                       m_awvalid_reg;
   logic [AWID_WIDTH-1:0]      m_awid_reg;
   logic [AWADDR_WIDTH-1:0]    m_awaddr_reg;
   logic [7:0]                 m_awlen_reg;
   logic [2:0]                 m_awsize_reg;
   logic [1:0]                 m_awburst_reg;
   logic                       m_awlock_reg;
   logic [3:0]                 m_awcache_reg;
   logic [2:0]                 m_awprot_reg;
   logic [3:0]                 m_awqos_reg;
   logic [3:0]                 m_awregion_reg;
   logic [AWUSER_WIDTH-1:0]    m_awuser_reg;

   // Generate ready and valid signals
   always @(posedge clk) begin
      if (~rst_n) begin
         s_awready_reg <= 1'b0;
         m_awvalid_reg <= 1'b0;
      end else begin
        if (s_awready_reg && s_awvalid) begin
           s_awready_reg <= 1'b0;
           m_awvalid_reg <= 1'b1;
        end else if (~s_awready_reg && (m_awready || ~m_awvalid)) begin
           s_awready_reg <= 1'b1;
           m_awvalid_reg <= 1'b0;
        end
      end
   end

   // Register AXI signals
   always @(posedge clk) begin
      if (s_awready_reg) begin
         m_awid_reg      <=  s_awid;
         m_awaddr_reg    <=  s_awaddr;
         m_awlen_reg     <=  s_awlen;
         m_awsize_reg    <=  s_awsize;
         m_awburst_reg   <=  s_awburst;
         m_awlock_reg    <=  s_awlock;
         m_awcache_reg   <=  s_awcache;
         m_awprot_reg    <=  s_awprot;
         m_awqos_reg     <=  s_awqos;
         m_awregion_reg  <=  s_awregion;
         m_awuser_reg    <=  s_awuser;
      end
   end

   // Output assignment
   assign s_awready  =  s_awready_reg;
   assign m_awvalid  =  m_awvalid_reg;
   assign m_awid     =  m_awid_reg;
   assign m_awaddr   =  m_awaddr_reg;
   assign m_awlen    =  m_awlen_reg;
   assign m_awsize   =  m_awsize_reg;
   assign m_awburst  =  m_awburst_reg;
   assign m_awlock   =  m_awlock_reg;
   assign m_awcache  =  m_awcache_reg;
   assign m_awprot   =  m_awprot_reg;
   assign m_awqos    =  m_awqos_reg;
   assign m_awregion =  m_awregion_reg;
   assign m_awuser   =  ENABLE_AWUSER ? m_awuser_reg : '0;

end else begin 
   // --------------------------------------
   // bypass mode
   // --------------------------------------
    assign s_awready  =  m_awready;
    assign m_awvalid  =  s_awvalid;
    assign m_awid     =  s_awid;
    assign m_awaddr   =  s_awaddr;
    assign m_awlen    =  s_awlen;
    assign m_awsize   =  s_awsize;
    assign m_awburst  =  s_awburst;
    assign m_awlock   =  s_awlock;
    assign m_awcache  =  s_awcache;
    assign m_awprot   =  s_awprot;
    assign m_awqos    =  s_awqos;
    assign m_awregion =  s_awregion;
    assign m_awuser   =  s_awuser;
end
endgenerate

// Write data channel
generate 
if (W_REG_MODE == 0) begin 
    // --------------------------------------
    // skid buffer
    // --------------------------------------
    // Registers & signals
    logic                        s_wvalid_reg   /* synthesis preserve noprune */;
    logic [WDATA_WIDTH-1:0]      s_wdata_reg    /* synthesis preserve noprune */;
    logic [(WDATA_WIDTH/8-1):0]  s_wstrb_reg    /* synthesis preserve noprune */;
    logic [2:0]                  s_wlast_reg    /* synthesis preserve noprune */;
    logic [WUSER_WIDTH-1:0]      s_wuser_reg    /* synthesis preserve noprune */;

    logic                        s_wready_reg   /* synthesis preserve noprune */;
    logic                        s_wready_reg_dup;
    logic                        w_use_reg;

    logic                       m_wvalid_pre;
    logic [WDATA_WIDTH-1:0]     m_wdata_pre;
    logic [(WDATA_WIDTH/8-1):0] m_wstrb_pre;
    logic [2:0]                 m_wlast_pre;
    logic [WUSER_WIDTH-1:0]     m_wuser_pre;

    logic                       m_wvalid_reg;
    logic [WDATA_WIDTH-1:0]     m_wdata_reg;
    logic [(WDATA_WIDTH/8-1):0] m_wstrb_reg;
    logic [2:0]                 m_wlast_reg;
    logic [WUSER_WIDTH-1:0]     m_wuser_reg;

    // --------------------------------------
    // Pipeline stage
    //
    // s_tready is delayed by one cycle, master will see tready assertions one cycle later.
    // Buffer the data when tready transitions from high->low
    //
    // This implementation buffers idle cycles should tready transition on such cycles. 
    //     i.e. It doesn't take in new data from s_* even though m_tvalid_reg=0 or when m_tready=0
    // This is a potential cause for throughput loss.
    // Not buffering idle cycles costs logic on the tready path.
    // --------------------------------------
    assign s_wready_pre  = (m_wready  || ~m_wvalid);
 
    always @(posedge clk) begin
      if (~rst_n) begin
        s_wready_reg      <=  1'b0;
        s_wready_reg_dup  <=  1'b0;
      end else begin
        s_wready_reg      <=  s_wready_pre;
        s_wready_reg_dup  <=  s_wready_pre;
      end
    end
    
    // --------------------------------------
    // On the first cycle after reset, the pass-through
    // must not be used or downstream logic may sample
    // the same command twice because of the delay in
    // transmitting a falling waitrequest.
    //
    // Using the registered command works on the condition
    // that downstream logic deasserts waitrequest
    // immediately after reset, which is true of the 
    // next stage in this bridge.
    // --------------------------------------			    

    // Check whether to drive the output with buffer registers when output is ready
    always @(posedge clk) begin
       if (~rst_n) begin
          w_use_reg <= 1'b1;
       end else if (s_wready_pre) begin
          // stop using the buffer when s_wready_pre is high (m_wready=1 or m_wvalid=0)
          w_use_reg <= 1'b0;
       end else if (~s_wready_pre && s_wready_reg) begin
          w_use_reg <= 1'b1;
       end
    end
    
    // Buffer registers    
    always @(posedge clk) begin
       if (~rst_n) begin
          s_wvalid_reg  <= 1'b0;
       end else begin
          if (s_wready_reg_dup) 
             s_wvalid_reg <= s_wvalid;
       end
    end
    
    always @(posedge clk) begin
       if (s_wready_reg_dup) begin
          s_wdata_reg    <=  s_wdata;
          s_wstrb_reg    <=  s_wstrb;
          s_wlast_reg    <=  s_wlast;
          s_wuser_reg    <=  s_wuser;
       end
    end
   
   // Output selection (between buffer register and input)
    always_comb begin
      if (w_use_reg) begin
         m_wvalid_pre   =  s_wvalid_reg;
         m_wdata_pre    =  s_wdata_reg;
         m_wstrb_pre    =  s_wstrb_reg;
         m_wlast_pre    =  s_wlast_reg;
         m_wuser_pre    =  s_wuser_reg;
      end else begin
         m_wvalid_pre   =  s_wvalid;
         m_wdata_pre    =  s_wdata;
         m_wstrb_pre    =  s_wstrb;
         m_wlast_pre    =  s_wlast;
         m_wuser_pre    =  s_wuser;
      end
   end 
     
   // Generate ready and valid signals
   always @(posedge clk) begin
      if (~rst_n) begin
         m_wvalid_reg <= 1'b0;
      end else if (s_wready_pre) begin
         m_wvalid_reg <= m_wvalid_pre;
      end
   end
   
   // Register AXI signals
   always @(posedge clk) begin
      if (s_wready_pre) begin
         m_wdata_reg <=  m_wdata_pre;
         m_wstrb_reg <=  m_wstrb_pre;
         m_wlast_reg <=  m_wlast_pre;
         m_wuser_reg <=  m_wuser_pre;
      end
   end

   // Output assignment
   assign s_wready   =  s_wready_reg;
   assign m_wvalid   =  m_wvalid_reg;
   assign m_wdata    =  m_wdata_reg;
   assign m_wstrb    =  m_wstrb_reg;
   assign m_wlast    =  m_wlast_reg;
   assign m_wuser    =  ENABLE_WUSER ? m_wuser_reg : '0;

end else if (W_REG_MODE == 1) begin 
   // --------------------------------------
   // Simple pipeline register with bubble cycle
   // --------------------------------------
   logic                       s_wready_reg;
   logic                       m_wvalid_reg;
   logic [WDATA_WIDTH-1:0]     m_wdata_reg;
   logic [(WDATA_WIDTH/8-1):0] m_wstrb_reg;
   logic [2:0]                 m_wlast_reg;
   logic [WUSER_WIDTH-1:0]     m_wuser_reg;

   // Generate ready and valid signals
   always @(posedge clk) begin
      if (~rst_n) begin
         s_wready_reg <= 1'b0;
         m_wvalid_reg <= 1'b0;
      end else begin
        if (s_wready_reg && s_wvalid) begin
           s_wready_reg <= 1'b0;
           m_wvalid_reg <= 1'b1;
        end else if (~s_wready_reg && (m_wready || ~m_wvalid)) begin
           s_wready_reg <= 1'b1;
           m_wvalid_reg <= 1'b0;
        end
      end
   end

   // Register AXI signals
   always @(posedge clk) begin
      if (s_wready_reg) begin
         m_wdata_reg     <=  s_wdata;
         m_wstrb_reg     <=  s_wstrb;
         m_wlast_reg     <=  s_wlast;
         m_wuser_reg     <=  s_wuser;
      end
   end

   // Output assignment
   assign s_wready   =  s_wready_reg;
   assign m_wvalid   =  m_wvalid_reg;
   assign m_wdata    =  m_wdata_reg;
   assign m_wstrb    =  m_wstrb_reg;
   assign m_wlast    =  m_wlast_reg;
   assign m_wuser    =  ENABLE_WUSER ? m_wuser_reg : '0;

 end else begin 
   // --------------------------------------
   // bypass mode
   // --------------------------------------
    assign s_wready   =  m_wready;
    assign m_wvalid   =  s_wvalid;
    assign m_wdata    =  s_wdata;
    assign m_wstrb    =  s_wstrb;
    assign m_wlast    =  s_wlast;
    assign m_wuser    =  s_wuser;
end
endgenerate

// Write response channel
generate 
if (B_REG_MODE == 0) begin 
    // --------------------------------------
    // skid buffer
    // --------------------------------------
    // Registers & signals
    logic                       m_bvalid_reg    /* synthesis preserve noprune */;
    logic [AWID_WIDTH-1:0]      m_bid_reg       /* synthesis preserve noprune */;
    logic [1:0]                 m_bresp_reg     /* synthesis preserve noprune */;
    logic [BUSER_WIDTH-1:0]     m_buser_reg     /* synthesis preserve noprune */;

    logic                       m_bready_reg    /* synthesis preserve noprune */;
    logic                       m_bready_reg_dup;
    logic                       b_use_reg;

    logic                       s_bvalid_pre;
    logic [AWID_WIDTH-1:0]      s_bid_pre;
    logic [1:0]                 s_bresp_pre;
    logic [BUSER_WIDTH-1:0]     s_buser_pre;

    logic                       s_bvalid_reg;
    logic [AWID_WIDTH-1:0]      s_bid_reg;
    logic [1:0]                 s_bresp_reg;
    logic [BUSER_WIDTH-1:0]     s_buser_reg;

    // --------------------------------------
    // Pipeline stage
    //
    // s_tready is delayed by one cycle, master will see tready assertions one cycle later.
    // Buffer the data when tready transitions from high->low
    //
    // This implementation buffers idle cycles should tready transition on such cycles. 
    //     i.e. It doesn't take in new data from s_* even though m_tvalid_reg=0 or when m_tready=0
    // This is a potential cause for throughput loss.
    // Not buffering idle cycles costs logic on the tready path.
    // --------------------------------------
    assign m_bready_pre  = (s_bready  || ~s_bvalid);
 
    always @(posedge clk) begin
      if (~rst_n) begin
        m_bready_reg_dup  <=  1'b0;
        m_bready_reg_dup  <=  1'b0;
      end else begin
        m_bready_reg      <=  m_bready_pre;
        m_bready_reg_dup  <=  m_bready_pre;
      end
    end
    
    // --------------------------------------
    // On the first cycle after reset, the pass-through
    // must not be used or downstream logic may sample
    // the same command twice because of the delay in
    // transmitting a falling waitrequest.
    //
    // Using the registered command works on the condition
    // that downstream logic deasserts waitrequest
    // immediately after reset, which is true of the 
    // next stage in this bridge.
    // --------------------------------------			    

    // Check whether to drive the output with buffer registers when output is ready
    always @(posedge clk) begin
       if (~rst_n) begin
          b_use_reg <= 1'b1;
       end else if (m_bready_pre) begin
          // stop using the buffer when m_bready_pre is high (s_bready=1 or s_bvalid=0)
          b_use_reg <= 1'b0;
       end else if (~m_bready_pre && m_bready_reg) begin
          b_use_reg <= 1'b1;
       end
    end
    
    // Buffer registers    
    always @(posedge clk) begin
       if (~rst_n) begin
          m_bvalid_reg  <= 1'b0;
        end else begin
          if (m_bready_reg_dup) 
             m_bvalid_reg <= m_bvalid;            
       end
    end

    always @(posedge clk) begin
       if (m_bready_reg_dup) begin
          m_bid_reg      <=  m_bid;
          m_bresp_reg    <=  m_bresp;
          m_buser_reg    <=  m_buser;
       end
    end
   
   // Output selection (between buffer register and input)
    always_comb begin
      if (b_use_reg) begin
         s_bvalid_pre   =  m_bvalid_reg;
         s_bid_pre      =  m_bid_reg;
         s_bresp_pre    =  m_bresp_reg;
         s_buser_pre    =  m_buser_reg;
      end else begin
         s_bvalid_pre   =  m_bvalid;
         s_bid_pre      =  m_bid;
         s_bresp_pre    =  m_bresp;
         s_buser_pre    =  m_buser;       
      end
   end 
     
   // Generate ready and valid signals
   always @(posedge clk) begin
      if (~rst_n) begin
         s_bvalid_reg <= 1'b0;
      end else if (m_bready_pre) begin
         s_bvalid_reg <= s_bvalid_pre;
      end
   end
   
   // Register AXI signals
   always @(posedge clk) begin
      if (m_bready_pre) begin
         s_bid_reg       <=  s_bid_pre;
         s_bresp_reg     <=  s_bresp_pre;
         s_buser_reg     <=  s_buser_pre;
      end
   end

   // Output assignment
   assign m_bready   =  m_bready_reg;
   assign s_bvalid   =  s_bvalid_reg;
   assign s_bid      =  s_bid_reg;
   assign s_bresp    =  s_bresp_reg;
   assign s_buser    =  ENABLE_BUSER ? s_buser_reg : '0;

end else if (B_REG_MODE == 1) begin 
   // --------------------------------------
   // Simple pipeline register with bubble cycle
   // --------------------------------------
   logic                       m_bready_reg;
   logic                       s_bvalid_reg;
   logic [AWID_WIDTH-1:0]      s_bid_reg;
   logic [1:0]                 s_bresp_reg;
   logic [BUSER_WIDTH-1:0]     s_buser_reg;

   // Generate ready and valid signals
   always @(posedge clk) begin
      if (~rst_n) begin
         m_bready_reg <= 1'b0;
         s_bvalid_reg <= 1'b0;
      end else begin
        if (m_bready_reg && m_bvalid) begin
           m_bready_reg <= 1'b0;
           s_bvalid_reg <= 1'b1;
        end else if (~m_bready_reg && (s_bready || ~s_bvalid)) begin
           m_bready_reg <= 1'b1;
           s_bvalid_reg <= 1'b0;
        end
      end
   end

   // Register AXI signals
   always @(posedge clk) begin
      if (m_bready_reg) begin
         s_bid_reg       <=  m_bid;
         s_bresp_reg     <=  m_bresp;
         s_buser_reg     <=  m_buser;
      end
   end

   // Output assignment
   assign m_bready   =  m_bready_reg;
   assign s_bvalid   =  s_bvalid_reg;
   assign s_bid      =  s_bid_reg;
   assign s_bresp    =  s_bresp_reg;
   assign s_buser    =  ENABLE_BUSER ? s_buser_reg : '0;

end else begin 
   // --------------------------------------
   // bypass mode
   // --------------------------------------
    assign m_bready   =  s_bready;
    assign s_bvalid   =  m_bvalid;
    assign s_bid      =  m_bid;
    assign s_bresp    =  m_bresp;
    assign s_buser    =  m_buser;
end
endgenerate



endmodule

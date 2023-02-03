// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// AXI read channel pipeline register
// 
//-----------------------------------------------------------------------------

`timescale 1 ps / 1 ps
module axi_read_register 
#( 
    // Register mode for read address channel
    parameter AR_REG_MODE          = 1, // 0: skid buffer 1: simple buffer 2: bypass
    // Register mode for read data channel
    parameter R_REG_MODE           = 0, // 0: skid buffer 1: simple buffer 2: bypass
    
    // Enable aruser signal on register output
    parameter ENABLE_ARUSER        = 0,
    // Enable ruser signal on register output
    parameter ENABLE_RUSER         = 0,
  
    // Width of ID signal on read address channel
    parameter ARID_WIDTH = 10,
    // Width of address signal on read address channel
    parameter ARADDR_WIDTH = 20,
    // Width of aruser signal on read address channel
    parameter ARUSER_WIDTH = 1,
    
    // Width of data signal on read data channel
    parameter RDATA_WIDTH = 64,
    // Width of ruser signal on read data channel
    parameter RUSER_WIDTH = 1
)(
    input                         clk,
    input                         rst_n,

    // Slave interface
       /*Read address channel*/
    output logic                       s_arready,
    input  logic                       s_arvalid,
    input  logic [ARID_WIDTH-1:0]      s_arid,
    input  logic [ARADDR_WIDTH-1:0]    s_araddr,
    input  logic [7:0]                 s_arlen,
    input  logic [2:0]                 s_arsize,
    input  logic [1:0]                 s_arburst,
    input  logic                       s_arlock,
    input  logic [3:0]                 s_arcache,
    input  logic [2:0]                 s_arprot,
    input  logic [3:0]                 s_arqos,
    input  logic [3:0]                 s_arregion,
    input  logic [ARUSER_WIDTH-1:0]    s_aruser,

       /*Read response channel*/
    input  logic                       s_rready,
    output logic                       s_rvalid,
    output logic [ARID_WIDTH-1:0]      s_rid,
    output logic [RDATA_WIDTH-1:0]     s_rdata,
    output logic [1:0]                 s_rresp,
    output logic                       s_rlast,
    output logic [RUSER_WIDTH-1:0]     s_ruser,

    // Master interface
       /*Read address channel*/
    input  logic                       m_arready,
    output logic                       m_arvalid,
    output logic [ARID_WIDTH-1:0]      m_arid,
    output logic [ARADDR_WIDTH-1:0]    m_araddr,
    output logic [7:0]                 m_arlen,
    output logic [2:0]                 m_arsize,
    output logic [1:0]                 m_arburst,
    output logic                       m_arlock,
    output logic [3:0]                 m_arcache,
    output logic [2:0]                 m_arprot,
    output logic [3:0]                 m_arqos,
    output logic [3:0]                 m_arregion,
    output logic [ARUSER_WIDTH-1:0]    m_aruser,

       /*Read response channel*/
    output logic                       m_rready,
    input  logic                       m_rvalid,
    input  logic [ARID_WIDTH-1:0]      m_rid,
    input  logic [RDATA_WIDTH-1:0]     m_rdata,
    input  logic [1:0]                 m_rresp,
    input  logic                       m_rlast,
    input  logic [RUSER_WIDTH-1:0]     m_ruser
);

// Read address channel
generate
if (AR_REG_MODE == 0) begin 
    // --------------------------------------
    // skid buffer
    // --------------------------------------
    // Registers & signals
    logic                        s_arvalid_reg  /* synthesis preserve noprune */;
    logic [ARID_WIDTH-1:0]       s_arid_reg     /* synthesis preserve noprune */;
    logic [ARADDR_WIDTH-1:0]     s_araddr_reg   /* synthesis preserve noprune */;
    logic [7:0]                  s_arlen_reg    /* synthesis preserve noprune */;
    logic [2:0]                  s_arsize_reg   /* synthesis preserve noprune */;
    logic [1:0]                  s_arburst_reg  /* synthesis preserve noprune */;
    logic                        s_arlock_reg   /* synthesis preserve noprune */;
    logic [3:0]                  s_arcache_reg  /* synthesis preserve noprune */;
    logic [2:0]                  s_arprot_reg   /* synthesis preserve noprune */;
    logic [3:0]                  s_arqos_reg    /* synthesis preserve noprune */;
    logic [3:0]                  s_arregion_reg /* synthesis preserve noprune */;
    logic [ARUSER_WIDTH-1:0]     s_aruser_reg   /* synthesis preserve noprune */;

    logic                        s_arready_reg  /* synthesis preserve noprune */;
    logic                        s_arready_reg_dup;
    logic                        ar_use_reg;

    logic                        m_arvalid_pre;
    logic [ARID_WIDTH-1:0]       m_arid_pre;
    logic [ARADDR_WIDTH-1:0]     m_araddr_pre;
    logic [7:0]                  m_arlen_pre;
    logic [2:0]                  m_arsize_pre;
    logic [1:0]                  m_arburst_pre;
    logic                        m_arlock_pre;
    logic [3:0]                  m_arcache_pre;
    logic [2:0]                  m_arprot_pre;
    logic [3:0]                  m_arqos_pre;
    logic [3:0]                  m_arregion_pre;
    logic [ARUSER_WIDTH-1:0]     m_aruser_pre;

    logic                        m_arvalid_reg;
    logic [ARID_WIDTH-1:0]       m_arid_reg;
    logic [ARADDR_WIDTH-1:0]     m_araddr_reg;
    logic [7:0]                  m_arlen_reg;
    logic [2:0]                  m_arsize_reg;
    logic [1:0]                  m_arburst_reg;
    logic                        m_arlock_reg;
    logic [3:0]                  m_arcache_reg;
    logic [2:0]                  m_arprot_reg;
    logic [3:0]                  m_arqos_reg;
    logic [3:0]                  m_arregion_reg;
    logic [ARUSER_WIDTH-1:0]     m_aruser_reg;

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
    assign s_arready_pre = (m_arready || ~m_arvalid);
 
    always @(posedge clk) begin
      if (~rst_n) begin
        s_arready_reg     <=  1'b0;
        s_arready_reg     <=  1'b0;
      end else begin
        s_arready_reg     <=  s_arready_pre;
        s_arready_reg_dup <=  s_arready_pre;
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
          ar_use_reg <= 1'b1;
       end else if (s_arready_pre) begin
          // stop using the buffer when s_aready_pre is high (m_arready=1 or m_arvalid=0)
          ar_use_reg <= 1'b0;
       end else if (~s_arready_pre && s_arready_reg) begin
          ar_use_reg <= 1'b1;
       end
    end
    
    // Buffer registers    
    always @(posedge clk) begin
       if (~rst_n) begin
          s_arvalid_reg <= 1'b0;
       end else begin
          if (s_arready_reg_dup) 
             s_arvalid_reg <= s_arvalid;
       end
    end
    
    always @(posedge clk) begin
       if (s_arready_reg_dup) begin
          s_arid_reg     <=  s_arid;
          s_araddr_reg   <=  s_araddr;
          s_arlen_reg    <=  s_arlen;
          s_arsize_reg   <=  s_arsize;
          s_arburst_reg  <=  s_arburst;
          s_arlock_reg   <=  s_arlock;
          s_arcache_reg  <=  s_arcache;
          s_arprot_reg   <=  s_arprot;
          s_arqos_reg    <=  s_arqos;
          s_arregion_reg <=  s_arregion;
          s_aruser_reg   <=  s_aruser; 
       end
    end
   
   // Output selection (between buffer register and input)
   always_comb begin
      if (ar_use_reg) begin
         m_arvalid_pre  =  s_arvalid_reg;
         m_arid_pre     =  s_arid_reg;
         m_araddr_pre   =  s_araddr_reg;
         m_arlen_pre    =  s_arlen_reg;
         m_arsize_pre   =  s_arsize_reg;
         m_arburst_pre  =  s_arburst_reg;
         m_arlock_pre   =  s_arlock_reg;
         m_arcache_pre  =  s_arcache_reg;
         m_arprot_pre   =  s_arprot_reg;
         m_arqos_pre    =  s_arqos_reg;
         m_arregion_pre =  s_arregion_reg;
         m_aruser_pre   =  s_aruser_reg;
      end else begin
         m_arvalid_pre  =  s_arvalid;
         m_arid_pre     =  s_arid;
         m_araddr_pre   =  s_araddr;
         m_arlen_pre    =  s_arlen;
         m_arsize_pre   =  s_arsize;
         m_arburst_pre  =  s_arburst;
         m_arlock_pre   =  s_arlock;
         m_arcache_pre  =  s_arcache;
         m_arprot_pre   =  s_arprot;
         m_arqos_pre    =  s_arqos;
         m_arregion_pre =  s_arregion;
         m_aruser_pre   =  s_aruser; 
      end
   end
     
   // Generate ready and valid signals
   always @(posedge clk) begin
      if (~rst_n) begin
         m_arvalid_reg <= 1'b0;
      end else if (s_arready_pre) begin
         m_arvalid_reg <= m_arvalid_pre;
      end
   end
   
   // Register AXI signals
   always @(posedge clk) begin
      if (s_arready_pre) begin
         m_arid_reg      <=  m_arid_pre;
         m_araddr_reg    <=  m_araddr_pre;
         m_arlen_reg     <=  m_arlen_pre;
         m_arsize_reg    <=  m_arsize_pre;
         m_arburst_reg   <=  m_arburst_pre;
         m_arlock_reg    <=  m_arlock_pre;
         m_arcache_reg   <=  m_arcache_pre;
         m_arprot_reg    <=  m_arprot_pre;
         m_arqos_reg     <=  m_arqos_pre;
         m_arregion_reg  <=  m_arregion_pre;
         m_aruser_reg    <=  m_aruser_pre;
      end
   end

   // Output assignment
   assign s_arready  =  s_arready_reg;
   assign m_arvalid  =  m_arvalid_reg;
   assign m_arid     =  m_arid_reg;
   assign m_araddr   =  m_araddr_reg;
   assign m_arlen    =  m_arlen_reg;
   assign m_arsize   =  m_arsize_reg;
   assign m_arburst  =  m_arburst_reg;
   assign m_arlock   =  m_arlock_reg;
   assign m_arcache  =  m_arcache_reg;
   assign m_arprot   =  m_arprot_reg;
   assign m_arqos    =  m_arqos_reg;
   assign m_arregion =  m_arregion_reg;
   assign m_aruser   =  ENABLE_ARUSER ? m_aruser_reg : '0;

end else if (AR_REG_MODE == 1) begin 
   // --------------------------------------
   // Simple pipeline register with bubble cycle
   // --------------------------------------
   logic                       s_arready_reg;
   logic                       m_arvalid_reg;
   logic [ARID_WIDTH-1:0]      m_arid_reg;
   logic [ARADDR_WIDTH-1:0]    m_araddr_reg;
   logic [7:0]                 m_arlen_reg;
   logic [2:0]                 m_arsize_reg;
   logic [1:0]                 m_arburst_reg;
   logic                       m_arlock_reg;
   logic [3:0]                 m_arcache_reg;
   logic [2:0]                 m_arprot_reg;
   logic [3:0]                 m_arqos_reg;
   logic [3:0]                 m_arregion_reg;
   logic [ARUSER_WIDTH-1:0]    m_aruser_reg;

   // Generate ready and valid signals
   always @(posedge clk) begin
      if (~rst_n) begin
         s_arready_reg <= 1'b0;
         m_arvalid_reg <= 1'b0;
      end else begin
        if (s_arready_reg && s_arvalid) begin
           s_arready_reg <= 1'b0;
           m_arvalid_reg <= 1'b1;
        end else if (~s_arready_reg && (m_arready || ~m_arvalid)) begin
           s_arready_reg <= 1'b1;
           m_arvalid_reg <= 1'b0;
        end
      end
   end

   // Register AXI signals
   always @(posedge clk) begin
      if (s_arready_reg) begin
         m_arid_reg      <=  s_arid;
         m_araddr_reg    <=  s_araddr;
         m_arlen_reg     <=  s_arlen;
         m_arsize_reg    <=  s_arsize;
         m_arburst_reg   <=  s_arburst;
         m_arlock_reg    <=  s_arlock;
         m_arcache_reg   <=  s_arcache;
         m_arprot_reg    <=  s_arprot;
         m_arqos_reg     <=  s_arqos;
         m_arregion_reg  <=  s_arregion;
         m_aruser_reg    <=  s_aruser;
      end
   end

   // Output assignment
   assign s_arready  =  s_arready_reg;
   assign m_arvalid  =  m_arvalid_reg;
   assign m_arid     =  m_arid_reg;
   assign m_araddr   =  m_araddr_reg;
   assign m_arlen    =  m_arlen_reg;
   assign m_arsize   =  m_arsize_reg;
   assign m_arburst  =  m_arburst_reg;
   assign m_arlock   =  m_arlock_reg;
   assign m_arcache  =  m_arcache_reg;
   assign m_arprot   =  m_arprot_reg;
   assign m_arqos    =  m_arqos_reg;
   assign m_arregion =  m_arregion_reg;
   assign m_aruser   =  ENABLE_ARUSER ? m_aruser_reg : '0;

end else begin 
   // --------------------------------------
   // bypass mode
   // --------------------------------------
    assign s_arready  =  m_arready;
    assign m_arvalid  =  s_arvalid;
    assign m_arid     =  s_arid;
    assign m_araddr   =  s_araddr;
    assign m_arlen    =  s_arlen;
    assign m_arsize   =  s_arsize;
    assign m_arburst  =  s_arburst;
    assign m_arlock   =  s_arlock;
    assign m_arcache  =  s_arcache;
    assign m_arprot   =  s_arprot;
    assign m_arqos    =  s_arqos;
    assign m_arregion =  s_arregion;
    assign m_aruser   =  s_aruser;
end
endgenerate

// Read response channel
generate
if (R_REG_MODE == 0) begin 
    // --------------------------------------
    // skid buffer
    // --------------------------------------
    // Registers & signals
    logic                        m_rvalid_reg   /* synthesis preserve noprune */;
    logic [ARID_WIDTH-1:0]       m_rid_reg      /* synthesis preserve noprune */;
    logic [RDATA_WIDTH-1:0]      m_rdata_reg    /* synthesis preserve noprune */;
    logic [1:0]                  m_rresp_reg    /* synthesis preserve noprune */;
    logic                        m_rlast_reg    /* synthesis preserve noprune */;
    logic [RUSER_WIDTH-1:0]      m_ruser_reg    /* synthesis preserve noprune */;

    logic                        m_rready_reg   /* synthesis preserve noprune */;
    logic                        m_rready_reg_dup;
    logic                        r_use_reg;

    logic                        s_rvalid_pre;
    logic [ARID_WIDTH-1:0]       s_rid_pre;
    logic [RDATA_WIDTH-1:0]      s_rdata_pre;
    logic [1:0]                  s_rresp_pre;
    logic                        s_rlast_pre;
    logic [RUSER_WIDTH-1:0]      s_ruser_pre;

    logic                        s_rvalid_reg;
    logic [ARID_WIDTH-1:0]       s_rid_reg;
    logic [RDATA_WIDTH-1:0]      s_rdata_reg;
    logic [1:0]                  s_rresp_reg;
    logic                        s_rlast_reg;
    logic [RUSER_WIDTH-1:0]      s_ruser_reg;

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
    assign m_rready_pre  = (s_rready  || ~s_rvalid);
    
    always @(posedge clk) begin
      if (~rst_n) begin
        m_rready_reg_dup  <=  1'b0;
        m_rready_reg_dup  <=  1'b0;
      end else begin
        m_rready_reg      <=  m_rready_pre;
        m_rready_reg_dup  <=  m_rready_pre;
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
       /*Read response channel*/
    always @(posedge clk) begin
       if (~rst_n) begin
          r_use_reg <= 1'b1;
       end else if (m_rready_pre) begin
          // stop using the buffer when m_rready_pre is high (s_rready=1 or s_rvalid=0)
          r_use_reg <= 1'b0;
       end else if (~m_rready_pre && m_rready_reg) begin
          r_use_reg <= 1'b1;
       end
    end
    
    // Buffer registers    
    always @(posedge clk) begin
       if (~rst_n) begin
          m_rvalid_reg  <= 1'b0;
       end else begin
          if (m_rready_reg_dup) 
             m_rvalid_reg <= m_rvalid;            
       end
    end
    
    always @(posedge clk) begin
       if (m_rready_reg_dup) begin
          m_rid_reg      <=  m_rid;
          m_rdata_reg    <=  m_rdata;
          m_rlast_reg    <=  m_rlast;
          m_rresp_reg    <=  m_rresp;
          m_ruser_reg    <=  m_ruser;
       end
    end
   
   // Output selection (between buffer register and input)
    always_comb begin
      if (r_use_reg) begin
         s_rvalid_pre   =  m_rvalid_reg;
         s_rid_pre      =  m_rid_reg;
         s_rdata_pre    =  m_rdata_reg;
         s_rlast_pre    =  m_rlast_reg;
         s_rresp_pre    =  m_rresp_reg;
         s_ruser_pre    =  m_ruser_reg;
      end else begin
         s_rvalid_pre   =  m_rvalid;
         s_rid_pre      =  m_rid;
         s_rdata_pre    =  m_rdata;
         s_rlast_pre    =  m_rlast;
         s_rresp_pre    =  m_rresp;
         s_ruser_pre    =  m_ruser;       
      end
   end 
     
   // Generate ready and valid signals
   always @(posedge clk) begin
      if (~rst_n) begin
         s_rvalid_reg <= 1'b0;
      end else if (m_rready_pre) begin
         s_rvalid_reg <= s_rvalid_pre;
      end
   end
   
   // Register AXI signals
   always @(posedge clk) begin
      if (m_rready_pre) begin
         s_rid_reg       <=  s_rid_pre;
         s_rdata_reg     <=  s_rdata_pre;
         s_rlast_reg     <=  s_rlast_pre;
         s_rresp_reg     <=  s_rresp_pre;
         s_ruser_reg     <=  s_ruser_pre;
      end
   end

   // Output assignment
   assign m_rready   =  m_rready_reg;
   assign s_rvalid   =  s_rvalid_reg;
   assign s_rid      =  s_rid_reg;
   assign s_rdata    =  s_rdata_reg;
   assign s_rlast    =  s_rlast_reg;
   assign s_rresp    =  s_rresp_reg;
   assign s_ruser    =  ENABLE_RUSER ? s_ruser_reg : '0;

end else if (R_REG_MODE == 1) begin 
   // --------------------------------------
   // Simple pipeline register with bubble cycle
   // --------------------------------------
   logic                       m_rready_reg;
   logic                       s_rvalid_reg;
   logic [ARID_WIDTH-1:0]      s_rid_reg;
   logic [RDATA_WIDTH-1:0]     s_rdata_reg;
   logic                       s_rlast_reg;
   logic [1:0]                 s_rresp_reg;
   logic [RUSER_WIDTH-1:0]     s_ruser_reg;

   // Generate ready and valid signals
   always @(posedge clk) begin
      if (~rst_n) begin
         m_rready_reg <= 1'b0;
         s_rvalid_reg <= 1'b0;
      end else begin
        if (m_rready_reg && m_rvalid) begin
           m_rready_reg <= 1'b0;
           s_rvalid_reg <= 1'b1;
        end else if (~m_rready_reg && (s_rready || ~s_rvalid)) begin
           m_rready_reg <= 1'b1;
           s_rvalid_reg <= 1'b0;
        end
      end
   end

   // Register AXI signals
   always @(posedge clk) begin
      if (m_rready_reg) begin
         s_rid_reg       <=  m_rid;
         s_rdata_reg     <=  m_rdata;
         s_rlast_reg     <=  m_rlast;
         s_rresp_reg     <=  m_rresp;
         s_ruser_reg     <=  m_ruser;
      end
   end

   // Output assignment
   assign m_rready   =  m_rready_reg;
   assign s_rvalid   =  s_rvalid_reg;
   assign s_rid      =  s_rid_reg;
   assign s_rdata    =  s_rdata_reg;
   assign s_rlast    =  s_rlast_reg;
   assign s_rresp    =  s_rresp_reg;
   assign s_ruser    =  ENABLE_RUSER ? s_ruser_reg : '0;

end else begin 
   // --------------------------------------
   // bypass mode
   // --------------------------------------
    assign m_rready   =  s_rready;
    assign s_rvalid   =  m_rvalid;
    assign s_rid      =  m_rid;
    assign s_rdata    =  m_rdata;
    assign s_rlast    =  m_rlast;
    assign s_rresp    =  m_rresp;
    assign s_ruser    =  m_ruser;
end
endgenerate



endmodule


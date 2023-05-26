// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// -----------
//  Overview:
// -----------
//    Converts MMIO request PCIe TLPs to AXI-lite read/write transactions.
//    Implements single master multiple slaves topology with shared address and data buses among slaves.
//    Only one outstanding transaction is issued at a time.
//
// -----------
//  Latency:
// -----------
//    2 cycles to read request from FIFO (upstream)
//    3 cycles to fill up the pipelines and send request to CSR slaves 
//    1 cycle  to buffer acknowledgement from CSR slave 
//
// -----------
//  Pipeline stages:
// -----------
//    Stage[0] : Receive MMIO request TLP from upstream
//    Stage[1] : Decode function and bar
//    Stage[2] : Decode address range and activate slave select
//    Stage[3] : Send MMIO request to targeted CSR slave 
//
// -----------
//  Data flow:
// -----------
//    T0   : Receives MMIO request from upstream logic
//           PIPELINE STAGE[0]
//                    Decode feature function and bar from TLP header
//
//    T1   : PIPELINE STAGE [1]
//                    Register bar hit status from STAGE[0]
//                    Decode targeted CSR slave from bar hit status and feature address
//
//    T2   : PIPELINE STAGE [2]
//                    Setup MMIO request to CSR slave
//
//    T3   : PIPELINE STAGE [3]
//                    Send MMIO request on AXI to the targeted CSR slave, assert valid signal on the selected slave 
//                       (awvalid, wvalid) for write request and (aarvalid) for read request
//                    Check if CSR slave is ready (slave is able to accept request in next cycle)
//                       (awready, wready) for write request and (arready) for read request
//
//    T4-n : De-assert valid signal if CSR slave was ready in previous cycle
//                 Otherwise, keep valid signal asserted until CSR slave is ready
//
//    Tn+1 : Service next MMIO request from previous pipeline stage
//
//-----------------------------------------------------------------------------

`include "fpga_defines.vh"

module mmio_req_bridge #(
   parameter MM_ADDR_WIDTH   = 19, 
   parameter MM_DATA_WIDTH   = 64,
   parameter READ_ALLOWANCE  = 1,
   parameter WRITE_ALLOWANCE = 64
)(
   input wire clk,
   input wire rst_n,		
	
   // PCIe interface
   pcie_ss_axis_if.sink   i_mmio_req_st,	

   // CSR slave master interfaces
   ofs_fim_axi_lite_if.req   axi_m_if,

   output logic                                           o_tlp_rd,
   output logic [pcie_ss_hdr_pkg::PCIE_TAG_WIDTH-1:0]     o_tlp_rd_tag,
   output logic [1:0]                                     o_tlp_rd_length,
   output logic [15:0]                                    o_tlp_rd_req_id,
   output logic [pcie_ss_hdr_pkg::LOWER_ADDR_WIDTH-1:0]   o_tlp_rd_lower_addr,
   output logic [2:0]                                     o_tlp_attr,
   output logic [2:0]                                     o_tlp_tc

);

import pcie_ss_hdr_pkg::*;

// MMIO request
typedef struct packed {
   logic [MM_ADDR_WIDTH-1:0]  addr;
   logic                      length;
   logic                      wvalid;
   logic [MM_DATA_WIDTH-1:0]  wdata;
   logic                      arvalid;
} t_mmio_req;
localparam MMIO_REQ_WIDTH = $bits(t_mmio_req);

//------------------------
// Registers and wires
//------------------------
logic                              mmio_valid_t0;
logic                              mmio_valid_t1;
logic                              mmio_valid_t2;

(*maxfan=100*) logic               load_cmd; 

(*maxfan=100*) logic               csr_cmd_active;
logic                              stall_wreq_t2, stall_rreq_t2, stall_req_t2;
logic                              stall_req;
logic [2:0]                        wait_ack;

logic              slave_wvalid;
logic              slave_awvalid;
logic              slave_arvalid;

logic              slave_wready;
logic              slave_awready;
logic              slave_arready;

logic              slave_bvalid;
logic              slave_bready;
logic              slave_wrsp_ack;
logic              slave_wrsp_ack_q;

logic              slave_rvalid;
logic              slave_rready;
logic              slave_rrsp_ack;
logic                              slave_rrsp_ack_q;

logic                              slave_write_ack;
logic                              slave_read_ack;

pcie_ss_hdr_pkg::t_pu_tlp_req_hdr  mmio_hdr_t0;

t_mmio_req                         mmio_req_t0;
t_mmio_req                         mmio_req_t1;
t_mmio_req                         mmio_req_t2;
t_mmio_req                         csr_req;

logic                              mmio_awvalid_t2;
logic                              mmio_wvalid_t2;
logic                              mmio_arvalid_t2;

logic                              unused_region_hit;

//------------------------------------------------------------------------------------

assign i_mmio_req_st.tready = load_cmd;

// Map PCIe MMIO request TLP into MMIO request struct
always_comb begin
   mmio_valid_t0           =  i_mmio_req_st.tvalid;
   mmio_hdr_t0             =  func_get_pu_tlp_hdr(i_mmio_req_st.tdata[HDR_WIDTH-1:0]);	
   mmio_req_t0.wvalid      =  i_mmio_req_st.tvalid && mmio_hdr_t0.dw0.fmttype[6];
   mmio_req_t0.arvalid     =  i_mmio_req_st.tvalid && ~mmio_hdr_t0.dw0.fmttype[6];
   mmio_req_t0.length      =  mmio_hdr_t0.dw0.length[0];
   mmio_req_t0.addr        =  mmio_hdr_t0.dw0.fmttype[5] ? mmio_hdr_t0.lsb_addr[MM_ADDR_WIDTH-1:0] : mmio_hdr_t0.addr[MM_ADDR_WIDTH-1:0];
   mmio_req_t0.wdata       =  i_mmio_req_st.tdata[HDR_WIDTH+:MM_DATA_WIDTH];
end

always_ff @(posedge clk) begin
  if (~rst_n) begin
     mmio_valid_t1 <= 1'b0;
     mmio_valid_t2 <= 1'b0;
  end else if (load_cmd) begin
     mmio_valid_t1 <= mmio_valid_t0;
     mmio_valid_t2 <= mmio_valid_t1;
  end
end

always_ff @(posedge clk) begin
  if (load_cmd) begin
     mmio_req_t1 <= mmio_req_t0;
     mmio_req_t2 <= mmio_req_t1;
     csr_req     <= mmio_req_t2;
  end

  if (~rst_n) begin
     mmio_req_t1.wvalid  <= 1'b0;
     mmio_req_t1.arvalid <= 1'b0;
     
     mmio_req_t2.wvalid  <= 1'b0;
     mmio_req_t2.arvalid <= 1'b0;

     csr_req.wvalid      <= 1'b0;
     csr_req.arvalid     <= 1'b0;
  end
end

//--------------------------------------------------
// Extract info from MMIO read request TLP and store it
// into the RAM inside mmio_rsp_bridge
// This information is needed to generate MMIO response TLP
//--------------------------------------------------
always_ff @(posedge clk) begin
   // fmttyppe[5] : 0[3DW header] 1[4DW header]
   o_tlp_rd_lower_addr <= mmio_hdr_t0.dw0.fmttype[5]? mmio_hdr_t0.lsb_addr[LOWER_ADDR_WIDTH-1:0] : mmio_hdr_t0.addr[LOWER_ADDR_WIDTH-1:0];

   o_tlp_rd_req_id     <= mmio_hdr_t0.requester_id;
   o_tlp_rd_length     <= mmio_hdr_t0.dw0.length[1:0];
   o_tlp_rd_tag        <= func_get_hdr_tag(mmio_hdr_t0);
   o_tlp_rd            <= i_mmio_req_st.tvalid && i_mmio_req_st.tready &&
                          ~func_has_data(ReqHdr_FmtType_e'(mmio_hdr_t0.dw0.fmttype));
   o_tlp_attr          <= {mmio_hdr_t0.dw0.rsvd2[1],mmio_hdr_t0.dw0.attr};
   o_tlp_tc            <= mmio_hdr_t0.dw0.tc;
end

//------------------------
// Decoding Logic
//------------------------
// Decode function and BAR targeting FME 

// Setup slave select vector

//------------------------
// CSR request/acknowledgement
//------------------------
// Connect FME CSR AXI interface
axi_lite_if_conn #(
   .MM_ADDR_WIDTH(MM_ADDR_WIDTH),
   .MM_DATA_WIDTH(MM_DATA_WIDTH)
) axi_csr_conn (
   .clk           (clk),
   .rst_n         (rst_n),
   .i_awvalid     (slave_awvalid   ),
   .i_wvalid      (slave_wvalid    ),
   .i_arvalid     (slave_arvalid   ),
   .i_addr        (csr_req.addr),
   .i_length      (csr_req.length),
   .i_wdata       (csr_req.wdata),

   .o_awready     (slave_awready   ),
   .o_wready      (slave_wready    ),
   .o_arready     (slave_arready   ),
   .o_bvalid      (slave_bvalid    ),
   .o_bready      (slave_bready    ),
   .o_rvalid      (slave_rvalid    ),
   .o_rready      (slave_rready    ),

   .m_csr_if      (axi_m_if)
);

//---------------------------------------------
// Pending write tracking 
//---------------------------------------------
localparam WRITE_CNT_WIDTH = $clog2(WRITE_ALLOWANCE);

logic [WRITE_CNT_WIDTH:0] write_counter;
logic                     write_rsp_pending;
logic                     write_full;
logic                     write_add, write_sub;

assign write_full = write_counter[WRITE_CNT_WIDTH];
assign write_add  = mmio_wvalid_t2 && ~csr_cmd_active;
assign write_sub  = slave_wrsp_ack_q;

always_ff @(posedge clk) begin
   if (~rst_n) begin 
      write_counter <= '0;
   end else begin
      write_counter <= write_counter + write_add - write_sub;
   end
end

// Pending write response 
always_ff @(posedge clk) begin
   if (~rst_n) begin	   
      write_rsp_pending <= 1'b0;
   end else begin      
      if (~|write_counter) begin // read_counter == 0
         write_rsp_pending <= 1'b0;
      end

      if (~csr_cmd_active) begin
         write_rsp_pending <= mmio_wvalid_t2;
      end
   end
end

//---------------------------------------------
// Pending read tracking
//---------------------------------------------
localparam READ_CNT_WIDTH = $clog2(READ_ALLOWANCE);

logic [WRITE_CNT_WIDTH:0] read_counter;
logic                     read_rsp_pending;
logic                     read_full;
logic                     read_add, read_sub;

assign read_full = read_counter[WRITE_CNT_WIDTH];
assign read_add  = mmio_arvalid_t2 && ~csr_cmd_active;
assign read_sub  = slave_rrsp_ack_q;

always_ff @(posedge clk) begin
   if (~rst_n) begin 
      read_counter <= '0;
   end else begin
      read_counter <= read_counter + read_add - read_sub;
   end
end

// Pending read response 
always_ff @(posedge clk) begin
   if (~rst_n) begin	   
      read_rsp_pending <= 1'b0;
   end else begin      
      if (~|read_counter) begin // read_counter == 0
         read_rsp_pending <= 1'b0;
      end

      if (~csr_cmd_active) begin
         read_rsp_pending <= mmio_arvalid_t2;
      end
   end
end

//---------------------------------------------
// Send MMIO request to the decoded CSR slave
//---------------------------------------------
always_comb begin
   stall_wreq_t2   = (read_rsp_pending | write_full);
   stall_rreq_t2   = (write_rsp_pending | read_full);
   stall_req_t2    = (stall_wreq_t2 | stall_rreq_t2);

   mmio_awvalid_t2 = mmio_req_t2.wvalid && ~read_rsp_pending && ~write_full;
   mmio_wvalid_t2  = mmio_awvalid_t2;
   mmio_arvalid_t2 = mmio_req_t2.arvalid && ~write_rsp_pending && ~read_full;
end

always_ff @(posedge clk) begin
   stall_req <= stall_req_t2;
   if (~rst_n) stall_req <= 1'b0;
end

// Write channel
always_ff @(posedge clk) begin
   if (~rst_n) begin
      slave_wvalid <= 1'b0;	   
   end else begin
      if (~csr_cmd_active) 
         begin
            slave_wvalid <= mmio_wvalid_t2;		   
         end else if (slave_wvalid && slave_wready)
	    begin
               slave_wvalid <= 1'b0;			
            end 
   end
end

// Write address channel
always_ff @(posedge clk) begin
   if (~rst_n) begin
      slave_awvalid <= 1'b0;	   
   end else begin
      if (~csr_cmd_active) 
	 begin
            slave_awvalid <= mmio_awvalid_t2;		   
         end else if (slave_awvalid && slave_awready)
	    begin
               slave_awvalid <= 1'b0;			
            end 
   end
end

// Read channel
always_ff @(posedge clk) begin
   if (~rst_n) begin
      slave_arvalid <= 1'b0;	   
   end else begin
      if (~csr_cmd_active) 
	 begin
            slave_arvalid <= mmio_arvalid_t2;	            
         end else if (slave_arvalid && slave_arready)
	    begin
               slave_arvalid <= 1'b0;				      
            end 
   end
end

// Load a new request when there is no pending request
always_ff @(posedge clk) begin
   if (~rst_n) begin
      load_cmd       <= 1'b0;
      csr_cmd_active <= 1'b0;
   end else begin
      if (~csr_cmd_active) begin
          csr_cmd_active <= mmio_valid_t2;
          load_cmd       <= ~mmio_valid_t2;  
      end else if (~|wait_ack && ~stall_req) begin // Wait for ack & stall 
         csr_cmd_active <= 1'b0;
         load_cmd       <= 1'b1;
      end
   end
end

// Check for CSR slave acknowledgement of MMIO write/read request
always_ff @(posedge clk) begin
   if (~rst_n) begin	   
      wait_ack <= '0;
   end else begin
      if (~csr_cmd_active) begin
         wait_ack     <= {mmio_arvalid_t2, mmio_wvalid_t2, mmio_awvalid_t2};
      end else begin 
         wait_ack[0]  <= slave_awvalid;	
         wait_ack[1]  <= slave_wvalid;
         wait_ack[2]  <= slave_arvalid;
      end
   end
end

always_ff @(posedge clk) begin
   slave_wrsp_ack   <= slave_bvalid && slave_bready;
   slave_rrsp_ack   <= slave_rvalid && slave_rready;
   slave_wrsp_ack_q <= slave_wrsp_ack;
   slave_rrsp_ack_q <= slave_rrsp_ack;
end

endmodule : mmio_req_bridge 

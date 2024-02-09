// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
// Description
//-----------------------------------------------------------------------------
//
// PCIe VDM TLP <-> AXI-lite Bridge 
//
//-----------------------------------------------------------------------------

`timescale 1ps / 1ps
`include "fpga_defines.vh"

module mctp_rx_bridge #(
  parameter MAX_BUF_DEPTH     = 32,
  parameter MM_DATA_WIDTH     = 64,
  parameter PMCI_BASEADDR     = 18'h20000,
  parameter VDM_OFFSET        = 16'h2000,
  parameter MM_ADDR_WIDTH     = 19, 
  parameter READ_ALLOWANCE    = 1,
  parameter WRITE_ALLOWANCE   = 6
)(
    input wire                 clk,
    input wire                 rst_n,

    ofs_fim_axi_lite_if.req    axi_m_if,
    pcie_ss_axis_if.sink       i_vdm_req_st
);

  import pcie_ss_hdr_pkg::*;

  localparam TDATA_W  = i_vdm_req_st.DATA_W;
  localparam TKEEP_W  = TDATA_W/8;
  localparam INDX     = TDATA_W/MM_DATA_WIDTH;
   
  // MMIO request
  typedef struct packed {
     logic [MM_ADDR_WIDTH-1:0]  addr;
     logic                      length;
     logic                      wvalid;
     logic [MM_DATA_WIDTH-1:0]  wdata;
     logic                      arvalid;
  } t_mmio_req;
  localparam MMIO_REQ_WIDTH = $bits(t_mmio_req);

  logic                                  slave_wvalid;
  logic                                  slave_awvalid;
  logic                                  slave_arvalid;
  logic                                  slave_wready;
  logic                                  slave_awready;
  logic                                  slave_arready;
  logic                                  slave_bvalid;
  logic                                  slave_bready;
  logic                                  slave_rvalid;
  logic                                  slave_rready;
  t_mmio_req                             csr_req;
  logic                                  vdm_valid;
  logic                                  vdm_valid_d;
  logic                                  vdm_valid_last_d;
  logic                                  vdm_tlast;
  logic                                  vdm_tlast_d;
  logic                                  vdm_tlast_rd;
  logic [(TKEEP_W-1):0]                  vdm_tkeep;
  logic [(TKEEP_W-1):0]                  vdm_tkeep_d;
  logic [(TKEEP_W-1):0]                  vdm_tkeep_rd;
  logic [(TDATA_W-1):0]                  vdm_tdata;
  logic [(TDATA_W-1):0]                  vdm_tdata_d;
  logic [(TDATA_W-1):0]                  vdm_tdata_rd;
  logic                                  vdm_sop;
  logic                                  vdm_sop_d;
  logic                                  vdm_sop_rd;
  logic                                  buf_empty;
  logic                                  buf_full;
  logic [TDATA_W+TKEEP_W+2-1:0]          buf_dout;
  logic                                  buf_ren;
  logic                                  buf_ren_d;
  logic [(TDATA_W-1):0]                  vdm_mmio_data;
  logic [(TKEEP_W-1):0]                  vdm_mmio_tkeep;
  logic [9:0]                            vdm_mmio_length;

// states defined MCTP RX bridge FSM  
  enum {
     VDM_RDBUF_IDLE,     
     VDM_RDEN_HDR,       
     VDM_RDBUF_HDR,      
     VDM_MMIO_TX,         
     SEND_SOP_CSR,       
     SEND_DATA_CSR,
     SEND_EOP_CSR,
     SOP_SLV_RDY_WAIT,       
     EOP_SLV_RDY_WAIT,       
     DATA_SLV_RDY_WAIT      
  } state;               
    
// Map PCIe VDM TLP into MMIO request struct
  always_comb begin
     vdm_valid   =  i_vdm_req_st.tvalid;
     vdm_tlast   =  i_vdm_req_st.tlast;
     vdm_tkeep   =  i_vdm_req_st.tkeep;
     vdm_tdata   = {<<32{ {<<8{i_vdm_req_st.tdata}} }};
  end
  
  always @(posedge clk) begin
    if(~rst_n) begin
      vdm_valid_last_d <= 1'b0;
	  vdm_valid_d      <= 1'b0;
	  vdm_tlast_d      <= 1'b0;
	  vdm_tkeep_d      <= 'b0;
	  vdm_tdata_d      <= 'b0;
	  vdm_sop_d        <= 1'b0;
    end else begin
      if (vdm_tlast) begin
        vdm_valid_last_d <= 1'b0;
	  end else begin
        vdm_valid_last_d <= vdm_valid;
	  end  
      vdm_valid_d <= vdm_valid;
      vdm_tlast_d <= vdm_tlast;
      vdm_tkeep_d <= vdm_tkeep;
      vdm_tdata_d <= vdm_tdata;
      vdm_sop_d   <= vdm_sop;
    end
  end
  
  assign vdm_sop = vdm_valid & (!vdm_valid_last_d);
 
  always @(posedge clk) begin
    if(~rst_n) begin
       buf_ren         <= 1'b0;
       slave_awvalid   <= 1'b0;   
       slave_wvalid    <= 1'b0;   
       slave_arvalid   <= 1'b0;  
	   vdm_sop_rd      <= 1'b0;
	   vdm_mmio_data   <= '0;
	   vdm_mmio_tkeep  <= '0;
	   vdm_mmio_length <= '0;
       vdm_tlast_rd    <= 1'b0;
	   vdm_tkeep_rd    <= '0;
	   vdm_tdata_rd    <= '0;
	   csr_req.addr    <= '0;
	   csr_req.length  <= '0;
	   csr_req.wdata   <= '0;
       state           <= VDM_RDBUF_IDLE;
    end else begin
	  buf_ren_d <= buf_ren;
      case(state)
        VDM_RDBUF_IDLE : begin
		                   buf_ren         <= 1'b0;
                           slave_awvalid   <= 1'b0;   
                           slave_wvalid    <= 1'b0;  
                           slave_arvalid   <= 1'b0;  
                           vdm_sop_rd      <= 1'b0;
	                       vdm_mmio_data   <= '0;
	                       vdm_mmio_tkeep  <= '0;
						   vdm_tlast_rd    <= 1'b0;
	                       vdm_tkeep_rd    <= '0;
	                       vdm_tdata_rd    <= '0;
	                       csr_req.addr    <= '0;
	                       csr_req.length  <= '0;
	                       csr_req.wdata   <= '0;
		                   if(!buf_empty) begin
                              state <= VDM_RDEN_HDR;					  
		                   end
                         end
        VDM_RDEN_HDR   : begin
		                   buf_ren <= 1'b1;
                           state   <= VDM_RDBUF_HDR;					  
 		                 end
		VDM_RDBUF_HDR  : begin
		                   buf_ren <= 1'b0;
						   if (buf_ren_d)
						   begin
						     vdm_sop_rd   <= buf_dout[TDATA_W+TKEEP_W+1];
						     vdm_tlast_rd <= buf_dout[TDATA_W+TKEEP_W];
						     vdm_tkeep_rd <= buf_dout[(TDATA_W+TKEEP_W-1):TDATA_W];
						     vdm_tdata_rd <= buf_dout[(TDATA_W-1):0];
						 	 state        <= VDM_MMIO_TX;
						   end
		                 end
	    VDM_MMIO_TX    : begin
		                   if (vdm_sop_rd) begin 
		                     vdm_mmio_data   <= {128'h0, {<<32{ {<<8{vdm_tdata_rd[256+:256]}} }}, vdm_tdata_rd[0+:128]};
							 vdm_mmio_length <= {vdm_tdata_rd[17:16], vdm_tdata_rd[31:24]};
				    	     state           <= SEND_SOP_CSR;
						   end else begin
						     vdm_mmio_data   <= {<<32{ {<<8{vdm_tdata_rd}} }};
						     vdm_mmio_tkeep  <= ~({64 {1'b1 }} << (vdm_mmio_length * 4));
						     vdm_mmio_length <= vdm_tlast_rd? 10'h0 : (vdm_mmio_length - 10'h10);
						     state           <= SEND_DATA_CSR;
				     	   end
		                 end
		SEND_SOP_CSR   : begin
		                   case (vdm_mmio_length)
						     10'h1: vdm_mmio_tkeep <= {44'h0,vdm_tkeep_rd[32+:4],vdm_tkeep_rd[0+:16]};
						     10'h2: vdm_mmio_tkeep <= {40'h0,vdm_tkeep_rd[32+:8],vdm_tkeep_rd[0+:16]};
						     10'h3: vdm_mmio_tkeep <= {36'h0,vdm_tkeep_rd[32+:12],vdm_tkeep_rd[0+:16]};
						     10'h4: vdm_mmio_tkeep <= {32'h0,vdm_tkeep_rd[32+:16],vdm_tkeep_rd[0+:16]};
						     10'h5: vdm_mmio_tkeep <= {28'h0,vdm_tkeep_rd[32+:20],vdm_tkeep_rd[0+:16]};
						     10'h6: vdm_mmio_tkeep <= {24'h0,vdm_tkeep_rd[32+:24],vdm_tkeep_rd[0+:16]};
						     10'h7: vdm_mmio_tkeep <= {20'h0,vdm_tkeep_rd[32+:28],vdm_tkeep_rd[0+:16]};
							 default: vdm_mmio_tkeep <= {16'h0,vdm_tkeep_rd[32+:32],vdm_tkeep_rd[0+:16]};
						   endcase
                           slave_awvalid  <= 1'b1;   
                           slave_wvalid   <= 1'b1;   
                           csr_req.addr   <= PMCI_BASEADDR + VDM_OFFSET;
                           csr_req.length <= 1'b0; // 64bit transaction
                           csr_req.wdata  <= 64'h00000001;
						   state          <= SOP_SLV_RDY_WAIT;
						   vdm_mmio_length <= vdm_tlast_rd? 10'h0 : vdm_mmio_length - 10'h8;
		                 end
		SEND_DATA_CSR  : begin
						   if (vdm_mmio_tkeep[7:0] == 8'hff)  begin
                             slave_awvalid   <= 1'b1;   
                             slave_wvalid    <= 1'b1;   
                             csr_req.addr    <= PMCI_BASEADDR + VDM_OFFSET + 16'h0008;
		                     csr_req.wdata   <= (vdm_mmio_data[(MM_DATA_WIDTH-1):0]);
							 vdm_mmio_tkeep  <= vdm_mmio_tkeep >> 8;
							 vdm_mmio_data   <= vdm_mmio_data >> MM_DATA_WIDTH;
						     state           <= DATA_SLV_RDY_WAIT;
						   end else if (vdm_mmio_tkeep[7:0] == 8'h0f)  begin
                             slave_awvalid   <= 1'b1;   
                             slave_wvalid    <= 1'b1; 
			                 csr_req.length  <= 1'b1; // 32bit transaction  
                             csr_req.addr    <= PMCI_BASEADDR + VDM_OFFSET + 16'h0008;
		                     csr_req.wdata   <= (vdm_mmio_data[(MM_DATA_WIDTH-1):0]);
							 vdm_mmio_tkeep  <= vdm_mmio_tkeep >> 8;
							 vdm_mmio_data   <= vdm_mmio_data >> MM_DATA_WIDTH;
						     state           <= DATA_SLV_RDY_WAIT;
						   end else begin
						     if (vdm_tlast_rd) begin
						       state    <= SEND_EOP_CSR;
							   vdm_mmio_length <= 10'h0;
						     end else begin
						       state    <= VDM_RDBUF_IDLE;
						     end
		                   end
		                 end
		SEND_EOP_CSR   : begin
                           slave_awvalid  <= 1'b1;   
                           slave_wvalid   <= 1'b1;   
                           csr_req.addr   <= PMCI_BASEADDR + VDM_OFFSET;
                           csr_req.length <= 1'b0;
                           csr_req.wdata  <= 64'h00000002;
						   state          <= EOP_SLV_RDY_WAIT;
		                 end
		DATA_SLV_RDY_WAIT   : begin
		                   if (slave_awvalid && slave_awready) begin
                             slave_awvalid <= 1'b0;   
                             slave_wvalid  <= 1'b0;   
						   end
		                   if (slave_bvalid) begin
						       state <= SEND_DATA_CSR;
						   end
		                 end
		SOP_SLV_RDY_WAIT   : begin
		                   if (slave_awvalid && slave_awready) begin
                             slave_awvalid <= 1'b0;   
                             slave_wvalid  <= 1'b0;   
						   end
		                   if (slave_bvalid) begin
						       state <= SEND_DATA_CSR;
						   end
		                 end
		EOP_SLV_RDY_WAIT   : begin
		                   if (slave_awvalid && slave_awready) begin
                             slave_awvalid <= 1'b0;   
                             slave_wvalid  <= 1'b0;   
						   end
		                   if (slave_bvalid) begin
						       state <= VDM_RDBUF_IDLE;
						   end
		                 end
		default        : begin
		                   state <= VDM_RDBUF_IDLE; 
				         end
      endcase
    end
  end
  
  assign i_vdm_req_st.tready = !buf_full;

  //------------------------------------------
  // RX Buffer
  //------------------------------------------
  scfifo  buf_inst (
    .clock        (clk),
    .data         ({vdm_sop_d,vdm_tlast_d,vdm_tkeep_d,vdm_tdata_d}),
    .rdreq        (buf_ren),
    .wrreq        (vdm_valid_d),
    .almost_empty (),
    .almost_full  (buf_full),
    .empty        (buf_empty),
    .full         (),
    .q            (buf_dout),
    .usedw        (),
    .aclr         (1'b0),
    .eccstatus    (),
    .sclr         (~rst_n));
  defparam
    buf_inst.add_ram_output_register= "ON",
    buf_inst.almost_full_value      = MAX_BUF_DEPTH-2,
    buf_inst.enable_ecc             = "FALSE",
   `ifdef DEVICE_FAMILY
      buf_inst.intended_device_family = `DEVICE_FAMILY,
   `else
      buf_inst.intended_device_family = "Stratix 10",
   `endif
    buf_inst.lpm_hint               = "M20K",
    buf_inst.lpm_numwords           = MAX_BUF_DEPTH,
    buf_inst.lpm_showahead          = "OFF",
    buf_inst.lpm_type               = "scfifo",
    buf_inst.lpm_width              = TDATA_W+TKEEP_W+2,
    buf_inst.lpm_widthu             = $clog2(MAX_BUF_DEPTH),
    buf_inst.overflow_checking      = "ON",
    buf_inst.underflow_checking     = "ON",
    buf_inst.use_eab                = "ON";

  //------------------------
  // CSR request/acknowledgement
  //------------------------
  // Connect FME CSR AXI interface
  axi_lite_if_conn #(
     .MM_ADDR_WIDTH (MM_ADDR_WIDTH),
     .MM_DATA_WIDTH (MM_DATA_WIDTH) 
  )axi_csr_conn (
     .clk           (clk             ),
     .rst_n         (rst_n           ),
     .i_awvalid     (slave_awvalid   ),
     .i_wvalid      (slave_wvalid    ),
     .i_arvalid     (slave_arvalid   ),
     .i_addr        (csr_req.addr    ),
     .i_length      (csr_req.length  ),
     .i_wdata       (csr_req.wdata   ),
  
     .o_awready     (slave_awready   ),
     .o_wready      (slave_wready    ),
     .o_arready     (slave_arready   ),
     .o_bvalid      (slave_bvalid    ),
     .o_bready      (slave_bready    ),
     .o_rvalid      (slave_rvalid    ),
     .o_rready      (slave_rready    ),
  
     .m_csr_if      (axi_m_if        )
  );

endmodule : mctp_rx_bridge

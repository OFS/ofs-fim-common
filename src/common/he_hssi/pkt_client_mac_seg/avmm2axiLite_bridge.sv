// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


module avmm2axiLite_bridge #(
  parameter                        ADDR_WIDTH = 32,
  parameter                        DATA_WIDTH = 32
)(
  input                            aclk,
  input                            aresetn,

  // AVMM slave interface
  input          [ADDR_WIDTH-1:0]  avmm_address_i,
  input          [DATA_WIDTH-1:0]  avmm_writedata_i,
  input        [DATA_WIDTH/8-1:0]  avmm_byteenable_i,
  output         [DATA_WIDTH-1:0]  avmm_readdata_o,
  input                            avmm_read_i,
  input                            avmm_write_i,
  output                           avmm_waitrequest_o,
  output                           avmm_readdata_valid_o,

  // AXI Lite master interface
  output logic                     axi_lite_awvalid_o,
  input                            axi_lite_awready_i,
  output                    [2:0]  axi_lite_awprot_o,
  output logic   [ADDR_WIDTH-1:0]  axi_lite_awaddr_o,
  output logic   [DATA_WIDTH-1:0]  axi_lite_wdata_o,
  output logic [DATA_WIDTH/8-1:0]  axi_lite_wstrb_o,
  output logic                     axi_lite_wvalid_o,
  input                            axi_lite_wready_i,
  input                            axi_lite_bvalid_i,
  output                           axi_lite_bready_o,
  input                     [1:0]  axi_lite_bresp_i,
  
  output logic                     axi_lite_arvalid_o,
  input                            axi_lite_arready_i,
  output                    [2:0]  axi_lite_arprot_o,
  output logic   [ADDR_WIDTH-1:0]  axi_lite_araddr_o,
  input          [DATA_WIDTH-1:0]  axi_lite_rdata_i,
  input                     [1:0]  axi_lite_rresp_i,
  input                            axi_lite_rvalid_i,
  output                           axi_lite_rready_o
);

  //----------------------------------------
  // Signals
  //----------------------------------------

  logic                    write_wait;
  logic                    read_wait;
  logic                    axi_lite_rvalid_i_d1;
  logic                    axi_lite_bvalid_i_d1;
  
  always @(posedge aclk, negedge aresetn) begin
    if(!aresetn) begin
      axi_lite_bvalid_i_d1 <= 1'b0;
      axi_lite_rvalid_i_d1 <= 1'b0;
    end
    else begin
      axi_lite_bvalid_i_d1 <= axi_lite_bvalid_i; 
      axi_lite_rvalid_i_d1 <= axi_lite_rvalid_i; 
    end
  end
  //----------------------------------------
  // Write address channel decode
  //----------------------------------------

  always @(posedge aclk, negedge aresetn) begin
    if(!aresetn) begin
      axi_lite_awaddr_o  <= {ADDR_WIDTH{1'b0}};
      axi_lite_awvalid_o <= 1'b0;
    end else begin
      if(avmm_write_i && ~avmm_waitrequest_o && ~axi_lite_bvalid_i_d1) begin
	    axi_lite_awaddr_o  <= avmm_address_i;
	    axi_lite_awvalid_o <= 1'b1;
      end else begin
        axi_lite_awvalid_o <= axi_lite_awvalid_o & ~axi_lite_awready_i;
      end
    end
  end

  assign axi_lite_awprot_o = 3'b000;

  //----------------------------------------
  // Write data channel 
  //----------------------------------------

  always @(posedge aclk, negedge aresetn) begin
    if(!aresetn) begin
      axi_lite_wdata_o  <= {DATA_WIDTH{1'b0}};
      axi_lite_wstrb_o  <= {(DATA_WIDTH/8){1'b0}};
      axi_lite_wvalid_o <= 1'b0;
    end else begin
      if(avmm_write_i && ~avmm_waitrequest_o && ~axi_lite_bvalid_i_d1) begin
	    axi_lite_wdata_o  <= decode_wdata( avmm_writedata_i, avmm_address_i[1:0]);
	    axi_lite_wstrb_o  <= decode_strb ( avmm_byteenable_i, avmm_address_i[1:0]);
	    axi_lite_wvalid_o <= 1'b1;
      end else begin
        axi_lite_wvalid_o <= axi_lite_wvalid_o & ~axi_lite_wready_i;
      end
    end
  end

  assign axi_lite_bready_o = 1'b1;

  //----------------------------------------
  // Read address channel 
  //----------------------------------------

  always @(posedge aclk, negedge aresetn) begin
    if(!aresetn) begin
      axi_lite_araddr_o  <= {ADDR_WIDTH{1'b0}};
      axi_lite_arvalid_o <= 1'b0;
    end else begin
      if(avmm_read_i && ~avmm_waitrequest_o && ~axi_lite_rvalid_i_d1) begin
	    axi_lite_araddr_o  <= avmm_address_i;
	    axi_lite_arvalid_o <= 1'b1;
      end else begin
        axi_lite_arvalid_o <= axi_lite_arvalid_o & ~axi_lite_arready_i;
      end
    end
  end

  assign axi_lite_arprot_o = 3'b000;

  //----------------------------------------
  // Read data response
  //----------------------------------------

  assign avmm_readdata_valid_o = axi_lite_rvalid_i & axi_lite_rready_o;
  assign avmm_readdata_o       = decode_rdata ( axi_lite_rdata_i, avmm_address_i[1:0]);
  assign axi_lite_rready_o     = 1'b1;

  //----------------------------------------
  // Waitrequest
  //----------------------------------------

  always @(posedge aclk, negedge aresetn) begin
    if(!aresetn) begin
      write_wait <= 1'b0;
    end else begin
      if(avmm_write_i && ~avmm_waitrequest_o && ~axi_lite_bvalid_i_d1) begin
	    write_wait <= 1'b1;
      end else begin
        write_wait <= write_wait & ~axi_lite_bvalid_i;
      end
    end
  end

  always @(posedge aclk, negedge aresetn) begin
    if(!aresetn) begin
      read_wait <= 1'b0;
    end else begin
      if(avmm_read_i && ~avmm_waitrequest_o && ~axi_lite_rvalid_i_d1) begin
	    read_wait <= 1'b1;
      end else begin
        read_wait <= read_wait & ~axi_lite_rvalid_i;
      end
    end
  end

  assign avmm_waitrequest_o = write_wait | read_wait;
  
  
  function [3:0] decode_strb (input [3:0] be, input [1:0] addr);
    case(addr)
	   2'b00: decode_strb =  be;
		2'b01: decode_strb = {be[2:0],1'b0};
		2'b10: decode_strb = {be[1:0],2'b00};
		2'b11: decode_strb = {be[0]  ,3'b000};	 
	 endcase
  endfunction
  
  function [31:0] decode_wdata (input [31:0] data, input [1:0] addr);
    case(addr)
	   2'b00: decode_wdata =  data;
		2'b01: decode_wdata = {data[23:0], 8'b0};
		2'b10: decode_wdata = {data[15:0],16'b0};
		2'b11: decode_wdata = {data[ 7:0],24'b0};	 
	 endcase
  endfunction
  
  function [31:0] decode_rdata (input [31:0] rdata, input [1:0] addr);
    case(addr)
	   2'b00: decode_rdata = rdata;
		2'b01: decode_rdata = {16'b0,rdata[23:8]};
		2'b10: decode_rdata = {16'b0,rdata[31:16]};
		2'b11: decode_rdata = {24'b0,rdata[31:24]};
	 endcase
  endfunction
  
endmodule
//------------------------------------------------------------------------------
//
//
// End avmm2axiLite_bridge.sv
//
//------------------------------------------------------------------------------

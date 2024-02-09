// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Author: Ranajoy Nandi (ranajoy.s.nandi@intel.com)
// Date: WW20, 2022
// Project: Originally designed for OSC. 
// Description: Write Handler
//-----------------------------------------------------------------------------
module whandler
#(
  parameter M_AWADDR_WIDTH = 32,
  parameter S_AWADDR_WIDTH = 32
)
(
  input  logic                      clk,
  input  logic                      rst_n,
  input  logic [M_AWADDR_WIDTH-1:0] m_awaddr,
  input  logic                      m_awvalid,
  output logic                      m_awready,
  input  logic [63:0]               m_wdata,
  input  logic [7:0]                m_wstrb,
  input  logic                      m_wvalid,
  output logic                      m_wready,
  output logic [1:0]                m_bresp,
  output logic                      m_bvalid,
  input  logic                      m_bready,
  output logic [S_AWADDR_WIDTH-1:0] s_awaddr,
  output logic                      s_awvalid,
  input  logic                      s_awready,
  output logic [31:0]               s_wdata,
  output logic [3:0]                s_wstrb,
  output logic                      s_wvalid,
  input  logic                      s_wready,
  input  logic [1:0]                s_bresp,
  input  logic                      s_bvalid,
  output logic                      s_bready

);

//-------------------------------------------------------------------------------
//Internal Wires
//-------------------------------------------------------------------------------
logic [M_AWADDR_WIDTH-1:0] i_m_awaddr;
logic [63:0]               i_m_wdata;
logic [7:0]                i_m_wstrb;
logic                      i_latch_addr;
logic                      i_latch_data;
logic                      i_select_upper;
logic                      i_latch_upper_bresp;
logic                      i_latch_lower_bresp;
//logic                      i_rst_bresp_gen;
//logic                      i_copy_bresp;
logic                      i_start;
logic                      i_done;
logic                      i_upper_strb_set;
logic                      i_lower_strb_set;
logic [1:0]                i_s_bresp;

//--------------------------------------------------------------------------------
//Capture Registers for address, data and strobe
//--------------------------------------------------------------------------------
always_ff @(posedge clk or negedge rst_n) begin
  if (~rst_n)
    i_m_awaddr <= 0;
  else if (i_latch_addr)
    i_m_awaddr <= m_awaddr;
  else
    i_m_awaddr <= i_m_awaddr;
end

always_ff @(posedge clk or negedge rst_n) begin
  if (~rst_n) begin
    i_m_wdata <= 0;
    i_m_wstrb <= 0;
  end  
  else if (i_latch_data) begin
    i_m_wdata <= m_wdata;
    i_m_wstrb <= m_wstrb;
  end  
  else begin
    i_m_wdata <= i_m_wdata;
    i_m_wstrb <= i_m_wstrb;
  end  
end

//-----------------------------------------------------------------------------------
//Data Path
//Muxes for address, data and strobe for slave side
//-----------------------------------------------------------------------------------
assign s_wdata  = i_select_upper ? i_m_wdata[63:32] : i_m_wdata[31:0];
assign s_wstrb  = i_select_upper ? i_m_wstrb[7:4]   : i_m_wstrb[3:0];

always_comb begin
  if (i_select_upper && (!i_m_awaddr[2])) 
      s_awaddr = i_m_awaddr + 4; //When writing to upper dword address, add 4 to outgoing 32-bit aligned s_awaddr
                                 //only if the incoming m_awaddr was 64-bit aligned.
  else
      s_awaddr = i_m_awaddr;
end  

//--------------------------------------------------------------------
//Strobe status per dword
//--------------------------------------------------------------------
assign i_upper_strb_set = |i_m_wstrb[7:4];
assign i_lower_strb_set = |i_m_wstrb[3:0];

//--------------------------------------------
//Master FSM Controller
//--------------------------------------------
whandler_ctrl u0_whandler_ctrl (
                                 .rst_n,
                                 .clk,
                                 .m_awvalid,
                                 .m_awready,
                                 .m_wvalid,
                                 .m_wready,
                                 .m_bready,
                                 .m_bvalid,
                                 .latch_addr        (i_latch_addr),
                                 .latch_data        (i_latch_data),
                                 .select_upper      (i_select_upper),
                                 .latch_upper_bresp (i_latch_upper_bresp),
                                 .latch_lower_bresp (i_latch_lower_bresp),
                                 //.copy_bresp       (i_copy_bresp),
                                 //.rst_bresp_gen    (i_rst_bresp_gen),
                                 .slv_driver_start (i_start),
                                 .slv_driver_done  (i_done),
                                 .upper_strb_set   (i_upper_strb_set),
                                 .lower_strb_set   (i_lower_strb_set),
                                 .addrbit2         (i_m_awaddr[2])
                               );

//--------------------------------------------------------------------
//Slave Driver
//--------------------------------------------------------------------
whandler_slave_driver u0_whandler_slave_driver (
                                                 .rst_n,
                                                 .clk,
                                                 .s_awvalid,
                                                 .s_awready,
                                                 .s_wvalid,
                                                 .s_wready,
                                                 .s_bready,
                                                 .s_bvalid,
                                                 .start (i_start),
                                                 .done  (i_done)

                                               );

//--------------------------------------------------------------------
//BRESP generation data path
//--------------------------------------------------------------------
whandler_bresp_gen u0_whandler_bresp_gen (
                                           .clk,
                                           .rst_n,
                                           .addrbit2 (i_m_awaddr[2]),
                                           .s_bresp,
                                           .latch_upper_bresp (i_latch_upper_bresp),
                                           .latch_lower_bresp (i_latch_lower_bresp),
                                           .m_bresp
                                         );

/*
always_ff @(posedge clk or negedge rst_n) begin
  if (~rst_n) begin
    i_s_bresp      <= 2'b00;
    i_s_bresp_copy <= 2'b00;
  end    
  else if (i_rst_bresp_gen) begin
    i_s_bresp <= 2'b00;
    i_s_bresp_copy <= 2'b00;
  end  
  else begin
    case ({i_latch_bresp, i_copy_bresp})
      2'b10   : begin
                  i_s_bresp      <= s_bresp;
                  i_s_bresp_copy <= i_s_bresp_copy;
                end
      2'b11   : begin
                  i_s_bresp      <= s_bresp;
                  i_s_bresp_copy <= s_bresp;
                end
      default : begin
                  i_s_bresp      <= i_s_bresp;
                  i_s_bresp_copy <= i_s_bresp_copy;
                end
    endcase  
  end  
end

always_comb begin
  if ((|i_s_bresp == 1'b0) && (|i_s_bresp_copy == 1'b0))
    m_bresp = 2'b00; //Assigning OKAY
  else
    m_bresp = 2'b10; //Assigning SLVERR for any non-zero response
end  
*/

endmodule

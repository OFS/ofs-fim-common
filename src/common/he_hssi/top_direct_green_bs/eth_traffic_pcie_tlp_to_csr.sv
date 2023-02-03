// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

//-----------------------------------------------------------------------------
// Description
//-----------------------------------------------------------------------------
//
// Ethernet Traffic AFU connection from PCIe TLP to CSRs.
//
//-----------------------------------------------------------------------------
import ofs_csr_pkg::*;

module eth_traffic_pcie_tlp_to_csr #(
   parameter PF_NUM             = 0,
   parameter VF_NUM             = 0,
   parameter VF_ACTIVE          = 0,
   parameter AVMM_DATA_W        = 32, // Data width
   parameter AVMM_ADDR_W        = 16  // AVMM address width
)(
   input  logic                         clk,
   input  logic                         softreset,
   pcie_ss_axis_if.sink                     axis_rx_if,
   pcie_ss_axis_if.source                   axis_tx_if,
   // Avalon-MM Interface
   output logic [AVMM_ADDR_W-1:0]       o_avmm_addr,        // AVMM address
   output logic                         o_avmm_read,        // AVMM read request
   output logic                         o_avmm_write,       // AVMM write request
   output logic [AVMM_DATA_W-1:0]       o_avmm_writedata,   // AVMM write data
   input  logic [AVMM_DATA_W-1:0]       i_avmm_readdata,    // AVMM read data
   input  logic                         i_avmm_waitrequest, // AVMM wait request
   // Port selection for CSR interface
   output logic [3:0]                   o_csr_port_sel,
   // Enable for crossbar: Tx port swapping between first and second half ports
   output logic                         o_port_swap_en
);

// ----------- Parameters -------------
localparam AFU_CSR_ADDR_WIDTH    = 12;

logic cmd_csr_rd, cmd_csr_rd_q, cmd_csr_rd_q1, cmd_csr_rd_q2;
logic cmd_csr_wr, cmd_csr_wr_q;
logic [AFU_CSR_ADDR_WIDTH-1:0] cmd_csr_addr;
logic [7:0]  axis_rx_fmttype;
csr_access_type_t cmd_csr_wr_type, csr_wr_type;
logic [63:0] csr_wr_data;
logic [63:0] csr_rd_data, csr_rd_data_q, csr_rd_data_q1, csr_rd_data_q2;

logic  [13:0] axis_rx_length, axis_rx_length_q;
logic  [63:0] axis_rx_addr, axis_rx_addr_q;

always_ff @(posedge clk) begin
   if(softreset) begin
      axis_rx_addr_q   <= '0;
      axis_rx_length_q <= '0;
   end else begin
      axis_rx_addr_q <= axis_rx_addr;
      axis_rx_length_q <= axis_rx_length;
   end
end

assign cmd_csr_wr_type = axis_rx_length_q[2] ? (axis_rx_addr_q[2] ? UPPER32 : LOWER32 ) : FULL64;

always_ff @(posedge clk) begin
   if(softreset) begin
      cmd_csr_rd_q  <= '0;
      cmd_csr_rd_q1 <= '0;
      cmd_csr_rd_q2 <= '0;
      cmd_csr_wr_q  <= '0;
   end else begin
      cmd_csr_rd_q <= cmd_csr_rd;
      cmd_csr_rd_q1 <= cmd_csr_rd_q;
      cmd_csr_rd_q2 <= cmd_csr_rd_q1;
      cmd_csr_wr_q <= cmd_csr_wr;
   end
end

always_ff @(posedge clk) begin
   csr_rd_data_q  <= csr_rd_data;
   csr_rd_data_q1 <= csr_rd_data_q;
   csr_rd_data_q2 <= csr_rd_data_q1;
end

//
// Map PCIe TLP to simple CSR read/write commands.
//
pcie_tlp_to_csr_no_dma #(
   .PF_NUM        (PF_NUM),
   .VF_NUM        (VF_NUM),
   .VF_ACTIVE     (VF_ACTIVE),
   .MM_ADDR_WIDTH (AFU_CSR_ADDR_WIDTH)
) pcie_tlp_to_csr_no_dma_inst (
   .clk                         (clk),
   .rst_n                       (~softreset),

   .axis_rx_if                  (axis_rx_if),
   .axis_tx_if                  (axis_tx_if),

   .avmm_m2s_read               (cmd_csr_rd),
   .avmm_m2s_write              (cmd_csr_wr),
   .avmm_m2s_address            (cmd_csr_addr),
   .avmm_m2s_writedata          (csr_wr_data),
   .avmm_m2s_byteenable         (),
   
   .avmm_s2m_readdata           (csr_rd_data_q2),
   .avmm_s2m_readdatavalid      (cmd_csr_rd_q2),
   .avmm_s2m_writeresponsevalid (cmd_csr_wr_q),
   .avmm_s2m_waitrequest        (1'b0),

   .axis_rx_fmttype             (axis_rx_fmttype),
   .axis_rx_length              (axis_rx_length),
   .axis_rx_addr                (axis_rx_addr)

);

//
// Pass CSR commands to the Ethernet traffic generator configuration interface.
//
eth_traffic_csr #(
   .AFU_CSR_ADDR_WIDTH(AFU_CSR_ADDR_WIDTH),
   .AVMM_DATA_W(AVMM_DATA_W),
   .AVMM_ADDR_W(AVMM_ADDR_W)
) inst_eth_traffic_csr (
   .clk(clk),
   .rst(softreset),

   .i_cmd_csr_rd(cmd_csr_rd),
   .i_cmd_csr_wr(cmd_csr_wr),
   .i_cmd_csr_addr(cmd_csr_addr),
   .i_cmd_csr_wr_type(cmd_csr_wr_type),
   .i_csr_wr_data(csr_wr_data),
   .o_csr_rd_data(csr_rd_data),

   // Avalon-MM Interface
   .o_avmm_addr,        // AVMM address
   .o_avmm_read,        // AVMM read request
   .o_avmm_write,       // AVMM write request
   .o_avmm_writedata,   // AVMM write data
   .i_avmm_readdata,    // AVMM read data
   .i_avmm_waitrequest, // AVMM wait request
   // Port selection for CSR interface
   .o_csr_port_sel,
   // Enable for crossbar: Tx port swapping between first and second half ports
   .o_port_swap_en
);

endmodule // eth_traffic_pcie_tlp_to_csr

// Copyright 2020 Intel Corporation.
// SPDX-License-Identifier: MIT
//
//-----------------------------------------------------------------------------
// Description
//-----------------------------------------------------------------------------
//
// Ethernet Traffic AFU connection from PCIe SS AXI-L to CSRs.
//
//-----------------------------------------------------------------------------

module eth_traffic_pcie_axil_csr 
    import ofs_csr_pkg::*;
#(
   parameter AVMM_DATA_W        = 32, // Data width
   parameter AVMM_ADDR_W        = 16  // AVMM address width
)(
   input  logic                         clk,
   input  logic                         rst_n,
   
   ofs_fim_axi_lite_if.sink            csr_lite_if,
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

logic cmd_csr_rd_q, cmd_csr_rd_q1, cmd_csr_rd_q2;
csr_access_type_t csr_avmm_if_wr_type;

logic [63:0] csr_wr_data;
logic [63:0] csr_rd_data;
logic csr_rd;
logic csr_wr;
logic [AFU_CSR_ADDR_WIDTH-1:0] csr_addr;
csr_access_type_t csr_wr_type;

ofs_avmm_if #(
   .ADDR_W($bits(csr_lite_if.awaddr)),
   .DATA_W($bits(csr_lite_if.wdata))
) csr_avmm_if ();

axi_lite_avmm_bridge csr_bridge (
   .clk,
   .rst_n,
   .s_if (csr_lite_if),
   .m_if (csr_avmm_if)
);


// AVMM connections to common csr block
always_ff @(posedge clk) begin
   if(~rst_n) begin
      cmd_csr_rd_q  <= '0;
      cmd_csr_rd_q1 <= '0;
      cmd_csr_rd_q2 <= '0;
   end else begin
      cmd_csr_rd_q <= csr_avmm_if.read;
      cmd_csr_rd_q1 <= cmd_csr_rd_q;
      cmd_csr_rd_q2 <= cmd_csr_rd_q1;
   end
end

assign csr_avmm_if_wr_type = &csr_avmm_if.byteenable ? FULL64 
                            : csr_avmm_if.address[2] ? UPPER32 
                            : LOWER32;

// Read data available after cycles
assign csr_avmm_if.readdatavalid = cmd_csr_rd_q2;
assign csr_avmm_if.waitrequest = 1'b0;

// Latch the address for Rds
always_ff @(posedge clk) begin
   if(~rst_n) begin
      csr_wr        <= '0;
      csr_rd        <= '0;
      csr_wr_type   <=FULL64;
      csr_wr_data   <= '0;
      csr_addr      <= '0;
   end else begin
      csr_wr        <= csr_avmm_if.write;
      csr_rd        <= csr_avmm_if.read;
      csr_wr_type   <= csr_avmm_if_wr_type;
      csr_wr_data   <= csr_avmm_if.writedata;
      csr_addr      <= csr_avmm_if.write | csr_avmm_if.read ? csr_avmm_if.address : csr_addr;
   end
end

assign csr_avmm_if.readdata = csr_rd_data; 

//
// Pass CSR commands to the Ethernet traffic generator configuration interface.
//
eth_traffic_csr #(
   .AFU_CSR_ADDR_WIDTH(AFU_CSR_ADDR_WIDTH),
   .AVMM_DATA_W(AVMM_DATA_W),
   .AVMM_ADDR_W(AVMM_ADDR_W)
) inst_eth_traffic_csr (
   .clk,
   .rst                 (~rst_n),

   .i_cmd_csr_rd        (csr_rd),
   .i_cmd_csr_wr        (csr_wr),
   .i_cmd_csr_addr      (csr_addr),
   .i_cmd_csr_wr_type   (csr_wr_type),
   .i_csr_wr_data       (csr_wr_data),
   .o_csr_rd_data       (csr_rd_data),

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

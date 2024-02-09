// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// VUART Top module
//
//-----------------------------------------------------------------------------
// TODO csr_lite_if mux
// 0x0000-? to DFH
// 0x0200-? to host_uart_ip


module vuart_top_pd 
  import ofs_csr_pkg::*;
   #(
     parameter DATA_WIDTH = ofs_fim_cfg_pkg::MMIO_DATA_WIDTH,
     parameter ADDR_WIDTH = ofs_fim_cfg_pkg::MMIO_ADDR_WIDTH,
     parameter ST2MM_DFH_MSIX_ADDR = 20'h40000 
     ) (
        input clk_csr,
        input rst_n_csr,
        input clk_50m,
        input rst_n_50m,
        input pwr_good_csr_clk_n,
        input host_uart_if_ri_n, 
	input host_uart_if_rx,
	input host_uart_if_cts_n,
	input host_uart_if_dsr_n,
	input host_uart_if_dcd_n,
	output host_uart_if_dtr_n,
	output host_uart_if_rts_n,
	output host_uart_if_out1_n,
	output host_uart_if_out2_n,
	output host_uart_if_tx,

        ofs_fim_axi_lite_if.master csr_lite_m_if,
        ofs_fim_axi_lite_if.slave csr_lite_if
        //ofs_uart_if.source host_uart_if
        );
   
   // ***********************************
   // Begin logic declares...
   // ***********************************
   localparam ST2MM_MSIX_CSR_ADDR = ST2MM_DFH_MSIX_ADDR + 20'h10;

   logic   uart_irq_50m;
   logic   uart_irq;
   logic   avmm_s2m_waitrequest;
   logic   avmm_s2m_write;
   logic   uart_irq_d1, uart_irq_edge;
   
   logic [8:0]            urt_addr;
   logic                  urt_write;
   logic [31:0]           urt_writedata;
   
   logic                  urt_read;
   logic [31:0]           urt_readdata;
   
   logic                  dfh_write;
   logic [11:0]           dfh_waddr;
   csr_access_type_t      dfh_write_type;
   logic [DATA_WIDTH-1:0] dfh_wdata;
   logic                  dfh_wstrb;
   
   logic                  dfh_read;
   logic [ADDR_WIDTH-1:0] dfh_raddr;
   logic [DATA_WIDTH-1:0] dfh_readdata;
   logic                  dfh_readdata_valid;
                            
   vuart_csr_decode vuart_csr_decode
     (
      .clk_csr            (clk_csr),
      .rst_n_csr          (rst_n_csr),
      .clk_50m      (clk_50m),
      .rst_n_50m      (rst_n_50m),
      
      .csr_lite_if        (csr_lite_if),
      
      .urt_addr         (urt_addr),
      .urt_write        (urt_write),
      .urt_writedata    (urt_writedata),
      
      .urt_read         (urt_read),
      .urt_readdata     (urt_readdata),
      
      
      .dfh_write          (dfh_write),      // output logic                   dfh_write
      .dfh_waddr          (dfh_waddr),      // output logic [ADDR_WIDTH-1:0]  dfh_waddr
      .dfh_write_type     (dfh_write_type), // dfh_write_type
      .dfh_wdata          (dfh_wdata),      // output logic [DATA_WIDTH-1:0]  dfh_wdata
      .dfh_wstrb          (dfh_wstrb),      // output logic [WSTRB_WIDTH-1:0] dfh_wstrb
      
      .dfh_read           (dfh_read),       // output logic                   dfh_read
      .dfh_raddr          (dfh_raddr),      // output logic [ADDR_WIDTH-1:0]  dfh_raddr
      .dfh_readdata       (dfh_readdata),   // input logic [DATA_WIDTH-1:0]   dfh_readdata
      .dfh_readdata_valid (dfh_readdata_valid) // input logic                    dfh_readdata_valid
      );
   
   // VUART DFH
   vuart_csr vuart_csr
     (
      .clk_csr             (clk_50m),
      .rst_n_csr           (rst_n_50m),
      
      .csr_write           (dfh_write),
      .csr_waddr           (dfh_waddr),
      .csr_write_type      (dfh_write_type),
      .csr_wdata           (dfh_wdata),
      .csr_wstrb           (dfh_wstrb),
      
      .csr_read            (dfh_read),
      .csr_raddr           (dfh_raddr),
      .csr_readdata        (dfh_readdata),
      .csr_readdata_valid  (dfh_readdata_valid)
      );
   
   
   // HOST UART IP
   uart host_uart
     (
      .clk            (clk_50m),
      .rst_n          (rst_n_50m),
      .addr           (urt_addr),
      .write          (urt_write),
      .writedata      (urt_writedata),
      .read           (urt_read),
      .readdata       (urt_readdata),
      .intr           (uart_irq_50m),
      .sin            (host_uart_if_rx),
      .sout           (host_uart_if_tx),
      .sout_oe        (),
      .cts_n          (host_uart_if_cts_n),
      .rts_n          (host_uart_if_rts_n),
      .dsr_n          (host_uart_if_dsr_n),
      .dcd_n          (host_uart_if_dcd_n),
      .ri_n           (host_uart_if_ri_n),
      .dtr_n          (host_uart_if_dtr_n),
      .out1_n         (host_uart_if_out1_n),
      .out2_n         (host_uart_if_out2_n)
      );
   
//----------------------------
// UART IRQ sideband -> inband
//----------------------------
fim_resync #(
    .SYNC_CHAIN_LENGTH(3),
    .WIDTH(1),
    .INIT_VALUE(0),
    .NO_CUT(0)
 ) uart_irq_sync_inst (
    .clk   (clk_csr),
    .reset (~rst_n_csr),
    .d     (uart_irq_50m),
    .q     (uart_irq)
 );

always@(posedge clk_csr) begin
   if (!rst_n_csr) begin
      uart_irq_d1   <= 0;
      avmm_s2m_write <= 0;
   end else begin
      uart_irq_d1  <= uart_irq;
      avmm_s2m_write <= uart_irq_edge ? 1'b1 
                            : ~avmm_s2m_waitrequest ? 1'b0
                            : avmm_s2m_write;
   end
end 

assign uart_irq_edge = ~uart_irq_d1 & uart_irq;

pfa_master #(
   .AVMM_ADDR_WIDTH        (20),
   .AVMM_RDATA_WIDTH       (64),
   .AVMM_WDATA_WIDTH       (64),
   .AXI4LITE_ADDR_WIDTH    (20),
   .AXI4LITE_RDATA_WIDTH   (64),
   .AXI4LITE_WDATA_WIDTH   (64)
)
pfa_master (
   .ACLK                           (clk_csr),
   .ARESETn                        (rst_n_csr),

   .avmm_m2s_write                 (avmm_s2m_write),
   .avmm_m2s_read                  (1'b0),
   .avmm_m2s_address               (ST2MM_MSIX_CSR_ADDR),
   .avmm_m2s_writedata             (64'd5),
   .avmm_m2s_byteenable            (8'hff),

   .avmm_s2m_waitrequest           (avmm_s2m_waitrequest),
   .avmm_s2m_writeresponsevalid    (),
   .avmm_s2m_readdatavalid         (),
   .avmm_s2m_readdata              (),

   .axi4lite_s2m_AWREADY           (csr_lite_m_if.awready),
   .axi4lite_m2s_AWVALID           (csr_lite_m_if.awvalid),
   .axi4lite_m2s_AWADDR            (csr_lite_m_if.awaddr),
   .axi4lite_m2s_AWPROT            (csr_lite_m_if.awprot),

   .axi4lite_s2m_WREADY            (csr_lite_m_if.wready),
   .axi4lite_m2s_WVALID            (csr_lite_m_if.wvalid),
   .axi4lite_m2s_WDATA             (csr_lite_m_if.wdata),
   .axi4lite_m2s_WSTRB             (csr_lite_m_if.wstrb),

   .axi4lite_s2m_BVALID            (csr_lite_m_if.bvalid),
   .axi4lite_s2m_BRESP             (csr_lite_m_if.bresp),
   .axi4lite_m2s_BREADY            (csr_lite_m_if.bready),

   .axi4lite_s2m_ARREADY           (csr_lite_m_if.arready),
   .axi4lite_m2s_ARVALID           (csr_lite_m_if.arvalid),
   .axi4lite_m2s_ARADDR            (csr_lite_m_if.araddr),
   .axi4lite_m2s_ARPROT            (csr_lite_m_if.arprot),

   .axi4lite_s2m_RVALID            (csr_lite_m_if.rvalid),
   .axi4lite_s2m_RDATA             (csr_lite_m_if.rdata),
   .axi4lite_s2m_RRESP             (csr_lite_m_if.rresp),
   .axi4lite_m2s_RREADY            (csr_lite_m_if.rready)
);


endmodule 


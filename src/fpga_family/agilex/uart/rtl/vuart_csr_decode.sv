// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT

// Module Name: vuart_cfg_decode
//

module  vuart_csr_decode
  import ofs_csr_pkg::*;
   import prtcl_chkr_pkg::*;
   #(
     parameter TID_WIDTH   = ofs_fim_cfg_pkg::MMIO_TID_WIDTH,
     parameter ADDR_WIDTH  = ofs_fim_cfg_pkg::MMIO_ADDR_WIDTH,
     parameter DATA_WIDTH  = ofs_fim_cfg_pkg::MMIO_DATA_WIDTH,
     parameter WSTRB_WIDTH = (DATA_WIDTH/8)
     )(     
            input logic                    clk_csr,
            input logic                    rst_n_csr,
            input logic                    clk_50m,
            input logic                    rst_n_50m,
                                           
            ofs_fim_axi_lite_if.slave      csr_lite_if,
            
            output logic [08:00]           urt_addr,
            output logic                   urt_write,
            output logic [31:00]           urt_writedata,
            
            output logic                   urt_read,
            input logic [31:00]            urt_readdata,
            
            output logic                   dfh_write,
            output logic [11:0]            dfh_waddr,
            csr_access_type_t              dfh_write_type,
            output logic [DATA_WIDTH-1:0]  dfh_wdata,
            output logic [WSTRB_WIDTH-1:0] dfh_wstrb,
            
            output logic                   dfh_read,
            output logic [ADDR_WIDTH-1:0]  dfh_raddr,
            input logic  [DATA_WIDTH-1:0]  dfh_readdata,
            input logic                    dfh_readdata_valid
            );
   
   localparam FIFO_DATA_WRWIDTH = 93;
   localparam FIFO_ADDR_WRWIDTH = 4;
   
   logic                                   fwr_for_urt;
   logic                                   frd_for_urt;
   ofs_fim_axi_mmio_if    csr_if();
   logic                                   fwr_write;
   logic [ADDR_WIDTH-1:0]                  fwr_waddr;
   csr_access_type_t      fwr_write_type;
   logic [DATA_WIDTH-1:0]                  fwr_wdata;
   logic                                   fwr_read;
   logic [ADDR_WIDTH-1:0]                  fwr_raddr;
   logic [DATA_WIDTH-1:0]                  readdata;
   logic                                   readdata_valid;
   
   logic                                   frd_write;
   logic [11:0]                            frd_waddr;
   csr_access_type_t      frd_write_type;
   logic [DATA_WIDTH-1:0]                  frd_wdata;
   logic                                   frd_read;
   logic [11:0]                            frd_raddr;
   
   logic                                   urt_readdata_valid;
   
   logic                                   fifo_read;
   logic                                   fifo_write;
   logic                                   rdempty;
   logic                                   dfh_read_trans_ip;
   logic                                   urt_read_trans_ip;
   
   logic [FIFO_ADDR_WRWIDTH-1:0]           rdusedw;
   logic [FIFO_ADDR_WRWIDTH-1:0]           wrusedw;
   
   logic                                   pre_readdata_valid;
   logic                                   external_ready;
   
   axi_lite2mmio_w_flow_control axi_lite2mmio_w_flow_control
     (
      .clk                    (clk_csr),
      .rst_n                  (rst_n_csr),
      .lite_if                (csr_lite_if),
      .mmio_if                (csr_if),
      .external_ready_awready (external_ready),
      .external_ready_wready  (external_ready),
      .external_ready_arready (external_ready)
      );
   
   //---------------------------------
   // Map AXI write/read request to CSR write/read,
   // and send the write/read response back
   //---------------------------------
   ofs_fim_axi_csr_slave vuart_csr_slave
     (
      .csr_if             (csr_if),            // 
      
      .csr_write          (fwr_write),         // output logic
      .csr_waddr          (fwr_waddr),         // output logic [ADDR_WIDTH-1:0]
      .csr_write_type     (fwr_write_type),    // output csr_access_type_t
      .csr_wdata          (fwr_wdata),         // output logic [DATA_WIDTH-1:0]
      .csr_wstrb          (),                  // output logic [WSTRB_WIDTH-1:0] csr_wstrb
      
      .csr_read           (fwr_read),          // output logic
      .csr_raddr          (fwr_raddr),         // output logic [ADDR_WIDTH-1:0]
      .csr_readdata       (readdata),          // input  logic [DATA_WIDTH-1:0]
      .csr_readdata_valid (readdata_valid)     // input  logic
      );


   always_ff @(posedge clk_csr) begin
      if (~rst_n_csr) begin
         readdata_valid <= 1'b0;
      end else if (pre_readdata_valid & readdata_valid) begin
         readdata_valid <= 0;
      end else if (pre_readdata_valid) begin
         readdata_valid <= 1;
      end
   end
   
   assign urt_read  = ~rdempty &  frd_for_urt & frd_read  & fifo_read;
   assign urt_write = ~rdempty &  frd_for_urt & frd_write & fifo_read;
   assign dfh_read  = ~rdempty & ~frd_for_urt & frd_read  & fifo_read;
   assign dfh_write = ~rdempty & ~frd_for_urt & frd_write & fifo_read;
   
   assign fwr_for_urt = fwr_write & (fwr_waddr[11:0] >= 12'h200) |
                          fwr_read  & (fwr_raddr[11:0] >= 12'h200);
   
   assign urt_addr        = frd_read ? frd_raddr[8:0] : frd_waddr[8:0];
   assign urt_writedata   = (fwr_write_type == ofs_csr_pkg::UPPER32) ? frd_wdata[63:32] : frd_wdata[31:0];
   
   always_ff @(posedge clk_50m) begin
      dfh_waddr       <= frd_waddr;
      dfh_write_type  <= frd_write_type;
      dfh_wdata       <= frd_wdata;
      dfh_wstrb       <= '0;
   
      dfh_raddr       <= frd_raddr;
   end
   
   
   assign pre_readdata_valid = urt_readdata_valid |
                               dfh_readdata_valid;

   assign readdata           = dfh_readdata_valid ? dfh_readdata : {urt_readdata, urt_readdata};
   
   
   always_ff @(posedge clk_50m) begin
      urt_readdata_valid <= urt_read;
      if (~rst_n_50m) begin
         dfh_read_trans_ip <= 1'b0;
         urt_read_trans_ip <= 1'b0;
      end else begin
         dfh_read_trans_ip <= ~rdempty & frd_read & ~frd_for_urt |
                              dfh_read_trans_ip   & ~dfh_readdata_valid;
         urt_read_trans_ip <= ~rdempty & fwr_read &  frd_for_urt |
                              urt_read_trans_ip   & ~urt_readdata_valid;
      end
   end // always_ff @ (posedge clk_50m)

   assign fifo_read  = ~rdempty & ~dfh_read_trans_ip & ~urt_read_trans_ip;
   assign fifo_write = fwr_write | fwr_read;
   
   always_ff @(posedge clk_csr) begin
      external_ready <= (wrusedw > 4'h9);
   end
     
   fim_dcfifo #(
                .DATA_WIDTH               (FIFO_DATA_WRWIDTH),
                .DEPTH_RADIX              (FIFO_ADDR_WRWIDTH),
                
                .ALMOST_FULL_THRESHOLD    (8), // Minimum number of free slots before almost full is asserted
                .WRITE_ACLR_SYNC          ("ON"),
                .READ_ACLR_SYNC           ("ON"),

                .OVERFLOW_CHECKING_PARAM  ("OFF"),
                .UNDERFLOW_CHECKING_PARAM ("OFF"),
                .LPM_SHOWAHEAD_PARAM      ("ON"),

                .ADD_USEDW_MSB_BIT_PARAM  ("OFF"),
                .RDSYNC_DELAYPIPE_PARAM   (4),
                .WRSYNC_DELAYPIPE_PARAM   (4)
                )
   fim_dcfifo
       (
        .wrclk   (clk_csr),
        .rdclk   (clk_50m),
        .aclr    (~rst_n_csr),
        .rdusedw (rdusedw),

        .wrreq   (fifo_write),
        .data    ({fwr_write, fwr_for_urt, fwr_waddr[11:0], fwr_write_type, fwr_wdata, fwr_read, fwr_raddr[11:0]}),
        .wrusedw (wrusedw),

        .rdreq   (fifo_read),
        .q       ({frd_write, frd_for_urt, frd_waddr,       frd_write_type, frd_wdata, frd_read, frd_raddr}),
        .rdempty (rdempty),

        //.eccstatus (),
        .rdfull  (),
        .wrempty (),
        .wrfull  (),
        .wralmfull ()
        );

endmodule // vuart_cfg_decode

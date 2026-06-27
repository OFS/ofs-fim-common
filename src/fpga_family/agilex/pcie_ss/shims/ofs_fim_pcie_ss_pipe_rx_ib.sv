// Copyright (C) 2024 Intel Corporation.
// SPDX-License-Identifier: MIT

//
// Pipeline to map the PCIe SS AXI-S interface to OFS FIM RX and RXREQ interfaces
// when headers are in-band.
//
// Stages include:
//  - Split incoming traffic into completions (RX) and requests/messages (RXREQ)
//  - Buffer incoming traffic to avoid losing messages
//  - Clock crossing to FIM
//

`include "ofs_ip_cfg_db.vh"

module ofs_fim_pcie_ss_pipe_rx_ib
  #(
    parameter TDATA_WIDTH = 512,
    parameter TKEEP_WIDTH = TDATA_WIDTH / 8,
    parameter NUM_OF_SEG = 1,
    parameter CFG_HAS_RXCRDT = 0
    )
   (
    input  logic hip_clk,
    input  logic hip_rst_n,

    // st_rx clocked by hip_clk
    input  logic ss_app_st_rx_tvalid,
    input  logic [TDATA_WIDTH-1:0] ss_app_st_rx_tdata,
    input  logic [TKEEP_WIDTH-1:0] ss_app_st_rx_tkeep,
    input  logic ss_app_st_rx_tlast,
    input  logic [NUM_OF_SEG-1:0] ss_app_st_rx_tuser_vendor,
    input  logic [NUM_OF_SEG-1:0] ss_app_st_rx_tuser_last_segment,
    input  logic [NUM_OF_SEG-1:0] ss_app_st_rx_tuser_hvalid,
    // tready manages the RX flow control between the PCIe SS (HIP) when
    // CFG_HAS_RXCRDT is 0.
    output logic app_ss_st_rx_tready,
    // rxcrdt becomes the RX flow control mechanism between the HIP and here
    // when CFG_HAS_RXCRDT is set.
    output logic ss_app_st_rxcrdt_tvalid,
    output logic [18:0] ss_app_st_rxcrdt_tdata,

    // FIM interfaces share a clock (separate from hip_clk)
    pcie_ss_axis_if.source axi_st_rxreq_if,
    pcie_ss_axis_if.source axi_st_rx_if
    );

    localparam BUFFER_DEPTH = 512;

    wire fim_clk = axi_st_rxreq_if.clk;
    bit fim_rst_n = 1'b0;
    always @(posedge fim_clk) begin
        fim_rst_n <= axi_st_rxreq_if.rst_n;
    end

    // Map the incoming tuser ports to a single data structure and store it
    // in the tuser_vendor field of the standard OFS pcie_ss_axis_if. This
    // is the format expected by the shims instantiated in the RX pipeline.
    ofs_fim_pcie_ss_shims_pkg::t_tuser_seg [NUM_OF_SEG-1:0] rx_in_tuser;
    for (genvar i = 0; i < NUM_OF_SEG; i += 1) begin
        assign rx_in_tuser[i].vendor = ss_app_st_rx_tuser_vendor[i];
        assign rx_in_tuser[i].last_segment = ss_app_st_rx_tuser_last_segment[i];
        assign rx_in_tuser[i].hvalid = ss_app_st_rx_tuser_hvalid[i];
        assign rx_in_tuser[i].hdr = '0;   // Not used with in-band
    end

    pcie_ss_axis_if#(.DATA_W(TDATA_WIDTH), .USER_W($bits(rx_in_tuser))) rx_in(hip_clk, hip_rst_n);

    assign rx_in.tvalid = ss_app_st_rx_tvalid;
    assign rx_in.tlast = ss_app_st_rx_tlast;
    assign rx_in.tuser_vendor = rx_in_tuser;
    assign rx_in.tdata = ss_app_st_rx_tdata;
    assign rx_in.tkeep = ss_app_st_rx_tkeep;
    assign app_ss_st_rx_tready = (CFG_HAS_RXCRDT == 0) ? rx_in.tready : 1'b1;


    // Clock crossing FIFO. In addition to moving to the FIM clock, this is the
    // buffer for which RX credits are managed. Credits are only between the HIP's
    // RX buffers and the FIM so doesn't have to be too large.
    pcie_ss_axis_if#(.DATA_W(TDATA_WIDTH), .USER_W($bits(rx_in_tuser))) rx_buf(fim_clk, fim_rst_n);
    pcie_ss_axis_if#(.DATA_W(TDATA_WIDTH), .USER_W($bits(rx_in_tuser))) rx_buf_skid(fim_clk, fim_rst_n);

    ofs_fim_axis_cdc
      #(
        .DEPTH_LOG2($clog2(BUFFER_DEPTH))
        )
      rx_cdc(.axis_s(rx_in), .axis_m(rx_buf));

    ofs_fim_axis_pipeline
      pipe_rx_buf(.clk(fim_clk), .rst_n(fim_rst_n), .axis_s(rx_buf), .axis_m(rx_buf_skid));


    // Ensure that the bus of the remainder of the pipeline is at least the width of a header.
    localparam PIPE_TDATA_WIDTH = (TDATA_WIDTH >= pcie_ss_hdr_pkg::HDR_WIDTH) ?
                                      TDATA_WIDTH : pcie_ss_hdr_pkg::HDR_WIDTH;
    pcie_ss_axis_if#(.DATA_W(PIPE_TDATA_WIDTH), .USER_W($bits(rx_in_tuser))) rx_wide(fim_clk, fim_rst_n);

    ofs_fim_pcie_bus_width rx_if_width (.i_if(rx_buf_skid), .o_if(rx_wide));


    // Split the RX stream into two: completions (rx) and everything else (rxreq).
    // The streams still have side-band headers.
    pcie_ss_axis_if#(.DATA_W(PIPE_TDATA_WIDTH), .USER_W($bits(rx_in_tuser))) rx_ib_split(fim_clk, fim_rst_n);
    pcie_ss_axis_if#(.DATA_W(PIPE_TDATA_WIDTH), .USER_W($bits(rx_in_tuser))) rxreq_ib_split(fim_clk, fim_rst_n);

    ofs_fim_pcie_ss_rx_dual_stream
      #(
        .NUM_OF_SEG(NUM_OF_SEG),
        .SB_HEADERS(0),
        // SM-tile IB streams do not pack multiple TLPs per beat; tlast is
        // the reliable end-of-packet indicator and last_segment is not set.
        .MULTI_SOP(0)
        )
      rx_dual_stream
       (
        .stream_in(rx_wide),
        .stream_out_cpld(rx_ib_split),
        .stream_out_req(rxreq_ib_split)
        );


    // Reduce each stream so that headers are only at bit 0. USER_W is narrower
    // now since there is only a single header field.
    pcie_ss_axis_if#(.DATA_W(PIPE_TDATA_WIDTH), .USER_W($bits(ofs_fim_pcie_ss_shims_pkg::t_tuser_seg)))
        rx_ib_aligned(fim_clk, fim_rst_n);
    pcie_ss_axis_if#(.DATA_W(PIPE_TDATA_WIDTH), .USER_W($bits(ofs_fim_pcie_ss_shims_pkg::t_tuser_seg)))
        rxreq_ib_aligned(fim_clk, fim_rst_n);

    ofs_fim_pcie_ss_rx_seg_align
      #(
        .NUM_OF_SEG(NUM_OF_SEG),
        .PL_DEPTH_IN(PIPE_TDATA_WIDTH > 512 ? 1 : 0)
        )
      rx_seg_align
       (
        .stream_in(rx_ib_split),
        .stream_out(rx_ib_aligned)
        );

    ofs_fim_pcie_ss_rx_seg_align
      #(
        .NUM_OF_SEG(NUM_OF_SEG)
        )
      rxreq_seg_align
       (
        .stream_in(rxreq_ib_split),
        .stream_out(rxreq_ib_aligned)
        );


    // Map to AXI-S with just a one bit user field (PU/DM tuser_vendor bit)
    pcie_ss_axis_if#(.DATA_W(PIPE_TDATA_WIDTH), .USER_W(1)) rx_ib(fim_clk, fim_rst_n);
    ofs_fim_pcie_ss_shims_pkg::t_tuser_seg rx_ib_aligned_tuser;
    assign rx_ib_aligned_tuser = rx_ib_aligned.tuser_vendor;

    assign rx_ib.tvalid = rx_ib_aligned.tvalid;
    assign rx_ib.tlast = rx_ib_aligned.tlast;
    assign rx_ib.tuser_vendor = rx_ib_aligned_tuser.vendor;
    assign rx_ib.tdata = rx_ib_aligned.tdata;
    assign rx_ib.tkeep = rx_ib_aligned.tkeep;
    assign rx_ib_aligned.tready = rx_ib.tready;

    pcie_ss_axis_if#(.DATA_W(PIPE_TDATA_WIDTH), .USER_W(1)) rxreq_ib(fim_clk, fim_rst_n);
    ofs_fim_pcie_ss_shims_pkg::t_tuser_seg rxreq_ib_aligned_tuser;
    assign rxreq_ib_aligned_tuser = rxreq_ib_aligned.tuser_vendor;

    assign rxreq_ib.tvalid = rxreq_ib_aligned.tvalid;
    assign rxreq_ib.tlast = rxreq_ib_aligned.tlast;
    assign rxreq_ib.tuser_vendor = rxreq_ib_aligned_tuser.vendor;
    assign rxreq_ib.tdata = rxreq_ib_aligned.tdata;
    assign rxreq_ib.tkeep = rxreq_ib_aligned.tkeep;
    assign rxreq_ib_aligned.tready = rxreq_ib.tready;


    // Connect to the FIM
    if (CFG_HAS_RXCRDT == 0) begin : no_rxcrdt
        // No RX credit interface
        assign axi_st_rx_if.tvalid = rx_ib.tvalid;
        assign axi_st_rx_if.tlast = rx_ib.tlast;
        assign axi_st_rx_if.tuser_vendor = { '0, rx_ib.tuser_vendor };
        assign axi_st_rx_if.tdata = rx_ib.tdata;
        assign axi_st_rx_if.tkeep = rx_ib.tkeep;
        assign rx_ib.tready = axi_st_rx_if.tready;

        assign axi_st_rxreq_if.tvalid = rxreq_ib.tvalid;
        assign axi_st_rxreq_if.tlast = rxreq_ib.tlast;
        assign axi_st_rxreq_if.tuser_vendor = { '0, rxreq_ib.tuser_vendor };
        assign axi_st_rxreq_if.tdata = rxreq_ib.tdata;
        assign axi_st_rxreq_if.tkeep = rxreq_ib.tkeep;
        assign rxreq_ib.tready = axi_st_rxreq_if.tready;

        assign ss_app_st_rxcrdt_tvalid = 1'b0;
        assign ss_app_st_rxcrdt_tdata = '0;
    end else begin : rxcrdt
        // Generate RX credits as packets are passed to the FIM
        ofs_fim_pcie_ss_rxcrdt
          #(
            .TDATA_WIDTH(PIPE_TDATA_WIDTH),
            // Depth of the clock crossing buffer above.
            .BUFFER_DEPTH(BUFFER_DEPTH)
            )
          tracker
           (
            .stream_in_cpld(rx_ib),
            .stream_in_req(rxreq_ib),
            .stream_out_cpld(axi_st_rx_if),
            .stream_out_req(axi_st_rxreq_if),

            .rxcrdt_clk(hip_clk),
            .rxcrdt_rst_n(hip_rst_n),
            .rxcrdt_tvalid(ss_app_st_rxcrdt_tvalid),
            .rxcrdt_tdata(ss_app_st_rxcrdt_tdata)
            );
    end

endmodule // ofs_fim_pcie_ss_pipe_rx_ib

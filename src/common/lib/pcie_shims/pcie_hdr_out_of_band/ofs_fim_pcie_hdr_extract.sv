// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT


//
// Transform the source PCIe SS TLP stream to a pair of streams in which
// the inband PCIe SS TLP headers are shunted to a sideband channel and
// the data is re-aligned to the width of the primary data stream.
//
// The sink streams guarantees:
//  1. At most one header per cycle in hdr_stream_sink.
//  2. Data aligned to the bus width in data_stream_sink.
//
// The consumer of the sink stream is responsible for consuming the two
// sink streams in the proper order. Namely, start with a header. If the
// header indicates there is data, consume data_stream_sink until EOP.
//

module ofs_fim_pcie_hdr_extract
  #(
    // Allow control of outbound pipeline depth. In some contexts
    // there is already a skid buffer present.
    parameter PL_DEPTH_HDR_OUT = 2
    )
   (
    pcie_ss_axis_if.sink   stream_source,

    // Stream of only headers, still wrapped in the usual
    // pcie_ss_axis_if. Headers all start at bit 0 of tdata.
    // The high bits if tdata are tied to 0.
    pcie_ss_axis_if.source hdr_stream_sink,
    // Stream of raw TLP data.
    pcie_ss_axis_if.source data_stream_sink
    );

    logic clk;
    assign clk = stream_source.clk;
    logic rst_n;
    assign rst_n = stream_source.rst_n;

    localparam TDATA_WIDTH = $bits(stream_source.tdata);
    localparam TUSER_WIDTH = $bits(stream_source.tuser_vendor);
    localparam TKEEP_WIDTH = TDATA_WIDTH/8;

    // Size of a header. All header types are the same size.
    localparam HDR_WIDTH = $bits(pcie_ss_hdr_pkg::PCIe_PUReqHdr_t);
    localparam HDR_TKEEP_WIDTH = HDR_WIDTH / 8;

    // Size of the data portion when a header that starts at tdata[0] is also present.
    localparam DATA_AFTER_HDR_WIDTH = TDATA_WIDTH - HDR_WIDTH;
    localparam DATA_AFTER_HDR_TKEEP_WIDTH = DATA_AFTER_HDR_WIDTH / 8;


    // ====================================================================
    //
    //  Add a skid buffer on input for timing
    //
    // ====================================================================

    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) source_skid(clk, rst_n);
    ofs_fim_axis_pipeline conn_source_skid (.clk, .rst_n, .axis_s(stream_source), .axis_m(source_skid));

    logic source_skid_sop;
    always_ff @(posedge clk)
    begin
        if (source_skid.tready && source_skid.tvalid)
            source_skid_sop <= source_skid.tlast;

        if (!rst_n)
            source_skid_sop <= 1'b1;
    end


    // ====================================================================
    //
    //  Split the headers and data streams
    //
    // ====================================================================

    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) hdr_stream(clk, rst_n);
    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) data_stream(clk, rst_n);

    logic prev_must_drain;

    // New message available and there is somewhere to put it?
    wire process_msg = source_skid.tvalid && source_skid.tready;
    wire process_drain = prev_must_drain && data_stream.tready;

    assign source_skid.tready = hdr_stream.tready && data_stream.tready;

    //
    // Requirements:
    //  - There is at most one header per beat in the incoming tdata stream.
    //  - All headers begin at tdata[0].
    //

    // Header - only when SOP in the incoming stream
    assign hdr_stream.tvalid = process_msg && source_skid_sop;
    assign hdr_stream.tdata = { '0, source_skid.tdata[$bits(pcie_ss_hdr_pkg::PCIe_CplHdr_t)-1 : 0] };
    assign hdr_stream.tuser_vendor = source_skid.tuser_vendor;
    assign hdr_stream.tkeep = 64'((65'h1 << ($bits(pcie_ss_hdr_pkg::PCIe_CplHdr_t)) / 8) - 1);
    assign hdr_stream.tlast = 1'b1;


    // Data - either directly from the stream for short messages or
    // by combining the current and previous messages.

    // Record the previous data in case it is needed later.
    logic [TDATA_WIDTH-1:0] prev_payload;
    logic [(TDATA_WIDTH/8)-1:0] prev_keep;
    always_ff @(posedge clk)
    begin
        if (process_drain)
        begin
            prev_must_drain <= 1'b0;
        end
        if (process_msg)
        begin
            prev_payload <= source_skid.tdata;
            prev_keep <= source_skid.tkeep;
            // Either there is data that won't fit in this beat or the data+header
            // is a single beat.
            prev_must_drain <= source_skid.tlast &&
                               (source_skid.tkeep[HDR_TKEEP_WIDTH] || source_skid_sop);
        end

        if (!rst_n)
        begin
            prev_must_drain <= 1'b0;
        end
    end

    // Continuation of multi-cycle data?
    logic payload_is_pure_data;
    assign payload_is_pure_data = !source_skid_sop;

    assign data_stream.tvalid = (process_msg && payload_is_pure_data) || process_drain;

    always_comb
    begin
        data_stream.tlast = (source_skid.tlast && !source_skid.tkeep[HDR_TKEEP_WIDTH]) ||
                            prev_must_drain;
        data_stream.tuser_vendor = '0;

        // Realign data - low part from previous flit, high part from current
        data_stream.tdata =
            { source_skid.tdata[0 +: HDR_WIDTH],
              prev_payload[HDR_WIDTH +: DATA_AFTER_HDR_WIDTH] };
        data_stream.tkeep =
            { source_skid.tkeep[0 +: HDR_TKEEP_WIDTH],
              prev_keep[HDR_TKEEP_WIDTH +: DATA_AFTER_HDR_TKEEP_WIDTH] };

        if (prev_must_drain)
        begin
            data_stream.tdata[DATA_AFTER_HDR_WIDTH +: HDR_WIDTH] = '0;
            data_stream.tkeep[DATA_AFTER_HDR_TKEEP_WIDTH +: HDR_TKEEP_WIDTH] = '0;
        end
    end


    // ====================================================================
    //
    //  Outbound buffers
    //
    // ====================================================================

    // Header must be a skid buffer to avoid deadlocks, as headers may arrive
    // before the payload.
    ofs_fim_axis_pipeline #(.PL_DEPTH(PL_DEPTH_HDR_OUT)) conn_hdr_skid (.clk, .rst_n, .axis_s(hdr_stream), .axis_m(hdr_stream_sink));

    // Just a register for data to save space.
    ofs_fim_axis_pipeline #(.MODE(1)) conn_data_skid (.clk, .rst_n, .axis_s(data_stream), .axis_m(data_stream_sink));

endmodule // ofs_fim_pcie_hdr_extract

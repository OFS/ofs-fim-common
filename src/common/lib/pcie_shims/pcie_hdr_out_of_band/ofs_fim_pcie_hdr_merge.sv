// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT


//
// The reverse of ofs_fim_pcie_hdr_extract(). Merge separated header and data
// streams into a single TLP stream with inline headers.
//

module ofs_fim_pcie_hdr_merge
  #(
    // Allow control of inbound pipeline mode to save area. Default to
    // skid buffer.
    parameter PL_MODE_HDR_IN = 0,
    parameter PL_MODE_DATA_IN = 0
    )
   (
    pcie_ss_axis_if.source stream_sink,

    // Stream of PCIe SS headers
    pcie_ss_axis_if.sink   hdr_stream_source,
    // Stream of raw TLP data
    pcie_ss_axis_if.sink   data_stream_source
    );

    logic clk;
    assign clk = stream_sink.clk;
    logic rst_n;
    assign rst_n = stream_sink.rst_n;

    localparam TDATA_WIDTH = $bits(stream_sink.tdata);
    localparam TUSER_WIDTH = $bits(stream_sink.tuser_vendor);
    localparam TKEEP_WIDTH = TDATA_WIDTH/8;

    // Size of a header. All header types are the same size.
    localparam HDR_WIDTH = $bits(pcie_ss_hdr_pkg::PCIe_PUReqHdr_t);
    localparam HDR_TKEEP_WIDTH = HDR_WIDTH / 8;

    // Size of the data portion when a header that starts at tdata[0] is also present.
    localparam DATA_AFTER_HDR_WIDTH = TDATA_WIDTH - HDR_WIDTH;
    localparam DATA_AFTER_HDR_TKEEP_WIDTH = DATA_AFTER_HDR_WIDTH / 8;


    // ====================================================================
    //
    //  Register input for timing
    //
    // ====================================================================

    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) hdr_source(clk, rst_n);
    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) data_source(clk, rst_n);

    axis_pipeline #(.MODE(PL_MODE_HDR_IN)) conn_hdr_skid (.clk, .rst_n, .axis_s(hdr_stream_source), .axis_m(hdr_source));
    axis_pipeline #(.MODE(PL_MODE_DATA_IN)) conn_data_skid (.clk, .rst_n, .axis_s(data_stream_source), .axis_m(data_source));


    // ====================================================================
    //
    //  Merge the headers and data streams
    //
    // ====================================================================

    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) sink_skid(clk, rst_n);

    //
    // Track EOP/SOP of the outgoing stream in order to handle
    // hdr and data messages in order.
    //
    logic source_is_sop;

    always_ff @(posedge clk)
    begin
        if (data_source.tready && data_source.tvalid)
        begin
            source_is_sop <= data_source.tlast;
        end

        if (!rst_n)
        begin
            source_is_sop <= 1'b1;
        end
    end

    //
    // This is a very simple case:
    //  - There is at most one header (SOP) in the incoming tdata stream.
    //  - All headers begin at tdata[0].
    //

    // Track data remaining from the previous cycle
    logic prev_data_valid;
    logic [TDATA_WIDTH-1:0] prev_data;
    logic [(TDATA_WIDTH/8)-1:0] prev_data_keep;

    pcie_ss_hdr_pkg::PCIe_CplHdr_t hdr_source_hdr;
    assign hdr_source_hdr = pcie_ss_hdr_pkg::PCIe_CplHdr_t'(hdr_source.tdata);

    wire source_is_single_beat =
        !pcie_ss_hdr_pkg::func_has_data(hdr_source_hdr.fmt_type) ||
        !data_source.tkeep[DATA_AFTER_HDR_TKEEP_WIDTH];

    always_ff @(posedge clk)
    begin
        if (sink_skid.tvalid && sink_skid.tready)
        begin
            if (data_source.tready)
            begin
                // Does the current cycle's source data fit completely in the
                // sink data vector? If this isn't the SOP beat then the
                // last beat fits if it is shorter than the injected header.
                // If this is an SOP beat then there will be previous data
                // if the message doesn't fit in a single beat.
                prev_data_valid <= ((!source_is_sop && data_source.tkeep[DATA_AFTER_HDR_TKEEP_WIDTH]) ||
                                    (source_is_sop && !source_is_single_beat));
            end
            else
            begin
                // Must have written out prev_data to sink_skid this cycle, since
                // a message was passed to sink_skid but nothing was consumed
                // from data_source.
                prev_data_valid <= 1'b0;
            end
        end

        if (!rst_n)
        begin
            prev_data_valid <= 1'b0;
        end
    end

    // Update the stored data
    always_ff @(posedge clk)
    begin
        // As long as something is written to the outbound stream it is safe
        // to update the stored data. If the input data stream is unconsumed
        // this cycle then the stored data is being flushed out with nothing
        // new to replace it. (prev_data_valid will be 0.)
        if (sink_skid.tvalid && sink_skid.tready)
        begin
            // Stored data is always shifted by the same amount: the size
            // of the TLP header.
            prev_data <= { '0, data_source.tdata[DATA_AFTER_HDR_WIDTH +: HDR_WIDTH] };
            prev_data_keep <= { '0, data_source.tkeep[DATA_AFTER_HDR_TKEEP_WIDTH +: HDR_TKEEP_WIDTH] };
        end
    end


    // Consume incoming header? If the previous partial data is not yet
    // emitted, then no. Otherwise, yes if header and data are valid and the
    // outbound stream is ready.
    assign hdr_source.tready = hdr_source.tvalid &&
                               data_source.tvalid &&
                               sink_skid.tready &&
                               source_is_sop &&
                               !prev_data_valid;

    // Consume incoming data? If SOP, then only if the header is ready and
    // all previous data has been emitted. If not SOP, then yes as long
    // as the outbound stream is ready.
    assign data_source.tready = (!source_is_sop || hdr_source.tvalid) &&
                                data_source.tvalid &&
                                sink_skid.tready &&
                                (!source_is_sop || !prev_data_valid);

    // Write outbound TLP traffic? Yes if consuming incoming data or if
    // the previous packet is complete and data from it remains.
    assign sink_skid.tvalid = data_source.tready ||
                              (source_is_sop && prev_data_valid);

    // Generate the outbound payload
    always_comb
    begin
        if (hdr_source.tready)
        begin
            // SOP: payload is first portion of data + header
            sink_skid.tdata = { data_source.tdata[0 +: DATA_AFTER_HDR_WIDTH],
                                hdr_source.tdata[0 +: HDR_WIDTH] };
            sink_skid.tkeep = { data_source.tkeep[0 +: DATA_AFTER_HDR_TKEEP_WIDTH],
                                {(HDR_TKEEP_WIDTH){1'b1}} };
            sink_skid.tlast = source_is_single_beat;
            sink_skid.tuser_vendor = hdr_source.tuser_vendor;
        end
        else
        begin
            sink_skid.tdata = { data_source.tdata[0 +: DATA_AFTER_HDR_WIDTH],
                                prev_data[0 +: HDR_WIDTH] };
            sink_skid.tkeep = { data_source.tkeep[0 +: DATA_AFTER_HDR_TKEEP_WIDTH],
                                prev_data_keep[0 +: HDR_TKEEP_WIDTH] };
            if (source_is_sop)
            begin
                // New data isn't being being consumed -- only the prev_data is
                // valid.
                sink_skid.tdata[HDR_WIDTH +: DATA_AFTER_HDR_WIDTH] = '0;
                sink_skid.tkeep[HDR_TKEEP_WIDTH +: DATA_AFTER_HDR_TKEEP_WIDTH] = '0;
            end

            sink_skid.tlast = source_is_sop || !data_source.tkeep[DATA_AFTER_HDR_TKEEP_WIDTH];
            sink_skid.tuser_vendor = '0;
        end
    end


    // ====================================================================
    //
    //  Outbound skid buffers
    //
    // ====================================================================

    axis_pipeline conn_sink_skid (.clk, .rst_n, .axis_s(sink_skid), .axis_m(stream_sink));

endmodule // ofs_fim_pcie_hdr_merge

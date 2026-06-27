// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: MIT

//
// Accept stream_in -- a packet stream where there may be multiple headers
// and empty segments in a cycle.
//
// Both in-band and side-band headers are supported.
//
// The input stream_in is separated into two output streams:
//   - All completions with data are routed to stream_out_cpld.
//   - All other packets are routed to stream_out_req.
//
// The tuser_vendor field in stream_in must be a [NUM_OF_SEG-1:0] array
// of ofs_fim_pcie_ss_shims_pkg::t_tuser_seg, holding all tuser
// information. When in-band headers are used, the t_user_seg hdr field
// will be unused.
//
// Input and output streams must all be the same width and must share
// the same clock.
//

module ofs_fim_pcie_ss_rx_dual_stream
  #(
    parameter NUM_OF_SEG = 2,
    parameter SB_HEADERS = 0,
    // When 1, multiple TLPs may be packed into a single beat (a new SOP may
    // start in a later segment of the same beat where a prior TLP ends).
    // Hard-tile PCIe SS supports this; SM-tile IB mode does not.
    // When 0, stream_in.tlast reliably marks end-of-TLP and last_segment is
    // not used for beat-to-beat continuation tracking.
    // Default: enabled for multi-segment streams (NUM_OF_SEG > 1).
    // SM-tile callers must explicitly pass MULTI_SOP=0.
    parameter bit MULTI_SOP = (NUM_OF_SEG > 1)
    )
   (
    // Input stream with NUM_OF_SEG segments
    pcie_ss_axis_if.sink stream_in,

    // Output completion stream
    pcie_ss_axis_if.source stream_out_cpld,
    // Output request stream (everything but completions)
    pcie_ss_axis_if.source stream_out_req
    );

    wire clk = stream_in.clk;
    wire rst_n = stream_in.rst_n;

    localparam TDATA_WIDTH = $bits(stream_in.tdata);
    localparam TKEEP_WIDTH = TDATA_WIDTH/8;
    localparam TUSER_WIDTH = $bits(stream_in.tuser_vendor);

    localparam SEG_TDATA_WIDTH = TDATA_WIDTH / NUM_OF_SEG;
    localparam SEG_TKEEP_WIDTH = TKEEP_WIDTH / NUM_OF_SEG;

    typedef logic [NUM_OF_SEG-1:0][SEG_TDATA_WIDTH-1:0] t_seg_tdata;
    typedef logic [NUM_OF_SEG-1:0][SEG_TKEEP_WIDTH-1:0] t_seg_tkeep;
    typedef ofs_fim_pcie_ss_shims_pkg::t_tuser_seg [NUM_OF_SEG-1:0] t_seg_tuser;

    // synthesis translate_off
    initial
    begin : error_proc
        if (TDATA_WIDTH != $bits(stream_out_cpld.tdata))
            $fatal(2, "** ERROR ** %m: TDATA stream_out_cpld width mismatch (in %0d, out %0d)", $bits(stream_out_cpld.tdata), TDATA_WIDTH);
        if (TDATA_WIDTH != $bits(stream_out_req.tdata))
            $fatal(2, "** ERROR ** %m: TDATA stream_out_req width mismatch (in %0d, out %0d)", $bits(stream_out_req.tdata), TDATA_WIDTH);

        if ($bits(t_seg_tuser) != TUSER_WIDTH)
            $fatal(2, "** ERROR ** %m: stream_in TUSER width mismatch (%0d, expected %0d)",
                   TUSER_WIDTH, $bits(t_seg_tuser));
        if ($bits(t_seg_tuser) != $bits(stream_out_cpld.tuser_vendor))
            $fatal(2, "** ERROR ** %m: stream_out_cpld TUSER width mismatch (%0d, expected %0d)",
                   $bits(stream_out_cpld.tuser_vendor), $bits(t_seg_tuser));
        if ($bits(t_seg_tuser) != $bits(stream_out_req.tuser_vendor))
            $fatal(2, "** ERROR ** %m: stream_out_req TUSER width mismatch (%0d, expected %0d)",
                   $bits(stream_out_req.tuser_vendor), $bits(t_seg_tuser));
    end
    // synthesis translate_on

    // Wait for both cpld and req ports to receive each message
    logic sent_out_cpld;
    logic [NUM_OF_SEG-1:0] cpld_seg_valid;
    logic sent_out_req;
    logic [NUM_OF_SEG-1:0] req_seg_valid;
    assign stream_in.tready = (stream_out_cpld.tready || sent_out_cpld || ~|(cpld_seg_valid)) &&
                              (stream_out_req.tready || sent_out_req || ~|(req_seg_valid));

    t_seg_tdata tdata_in;
    assign tdata_in = stream_in.tdata;
    t_seg_tkeep tkeep_in;
    assign tkeep_in = stream_in.tkeep;
    t_seg_tuser tuser_in;
    assign tuser_in = stream_in.tuser_vendor;

    pcie_ss_hdr_pkg::PCIe_PUReqHdr_t hdr_in[NUM_OF_SEG];
    always_comb begin
        for (int s = 0; s < NUM_OF_SEG; s += 1) begin
            hdr_in[s] = SB_HEADERS ? tuser_in[s].hdr :
                                     $bits(pcie_ss_hdr_pkg::PCIe_PUReqHdr_t)'(tdata_in[s]);
        end
    end


    // ====================================================================
    //
    // Completions
    //
    // ====================================================================

    logic cpld_cont;
    logic [NUM_OF_SEG-1:0] cpld_seg_last;

    // Build a mask of segments that are completions with data
    always_comb begin
        for (int s = 0; s < NUM_OF_SEG; s += 1) begin
            if (tuser_in[s].hvalid) begin
                // Start of a new completion?
                cpld_seg_valid[s] = pcie_ss_hdr_pkg::func_is_completion(hdr_in[s].fmt_type) &&
                                    pcie_ss_hdr_pkg::func_has_data(hdr_in[s].fmt_type);
            end
            else if (s == 0) begin
                // Continuing a multi-cycle packet?
                cpld_seg_valid[s] = cpld_cont;
            end else begin
                // Continuing from the previous segment in the same cycle?
                // Note: tuser_in[s-1].last_segment is unreliable on SM-tile/in-band
                // header streams. Use tkeep[s][0] (the per-segment byte-enable) as
                // the authoritative signal that segment s carries valid bytes.
                cpld_seg_valid[s] = cpld_seg_valid[s-1] && tkeep_in[s][0];
            end

            cpld_seg_last[s] = cpld_seg_valid[s] && tuser_in[s].last_segment;
        end
    end

    // Does the packet continue in the next cycle?
    // MULTI_SOP=0 (SM-tile IB): one TLP at a time per beat; last_segment is
    //   unreliable, but stream_in.tlast reliably marks end-of-TLP.
    // MULTI_SOP=1 (hard tile): multiple TLPs may be packed per beat, so
    //   stream_in.tlast can fire when an earlier TLP ends while a later segment
    //   starts a new TLP that continues beyond this beat. Use last_segment[N-1]
    //   which tracks the last segment's TLP independently.
    always_ff @(posedge clk) begin
        if (stream_in.tvalid && stream_in.tready) begin
            if (!MULTI_SOP)
                cpld_cont <= cpld_seg_valid[NUM_OF_SEG-1] && !stream_in.tlast;
            else
                cpld_cont <= cpld_seg_valid[NUM_OF_SEG-1] && !tuser_in[NUM_OF_SEG-1].last_segment;
        end

        if (!rst_n) begin
            cpld_cont <= 1'b0;
        end
    end

    // Emit only completions iwth data to stream_out_cpld
    t_seg_tdata tdata_out_cpld;
    t_seg_tkeep tkeep_out_cpld;
    t_seg_tuser tuser_out_cpld;

    always_comb begin
        for (int s = 0; s < NUM_OF_SEG; s += 1) begin
            tdata_out_cpld[s] = cpld_seg_valid[s] ? tdata_in[s] : '0;
            tkeep_out_cpld[s] = cpld_seg_valid[s] ? tkeep_in[s] : '0;
            tuser_out_cpld[s] = cpld_seg_valid[s] ? tuser_in[s] : '0;
        end
    end

    assign stream_out_cpld.tvalid = |(cpld_seg_valid) && stream_in.tvalid && !sent_out_cpld;
    assign stream_out_cpld.tlast = (NUM_OF_SEG == 1) ? stream_in.tlast : |(cpld_seg_last);
    assign stream_out_cpld.tdata = tdata_out_cpld;
    assign stream_out_cpld.tkeep = tkeep_out_cpld;
    assign stream_out_cpld.tuser_vendor = tuser_out_cpld;

    always_ff @(posedge clk) begin
        if (stream_out_cpld.tvalid && stream_out_cpld.tready)
            sent_out_cpld <= 1'b1;
        if (stream_in.tready)
            sent_out_cpld <= 1'b0;

        if (!rst_n)
            sent_out_cpld <= 1'b0;
    end


    // ====================================================================
    //
    // All other requests
    //
    // ====================================================================

    logic req_cont;
    logic [NUM_OF_SEG-1:0] req_seg_last;

    // Build a mask of segments that are completions with data
    always_comb begin
        for (int s = 0; s < NUM_OF_SEG; s += 1) begin
            if (tuser_in[s].hvalid) begin
                // Start of a new completion?
                req_seg_valid[s] = !pcie_ss_hdr_pkg::func_is_completion(hdr_in[s].fmt_type) ||
                                   !pcie_ss_hdr_pkg::func_has_data(hdr_in[s].fmt_type);
            end
            else if (s == 0) begin
                // Continuing a multi-cycle packet?
                req_seg_valid[s] = req_cont;
            end else begin
                // Continuing from the previous segment in the same cycle?
                // Same SM-tile workaround as the cpld path above: rely on tkeep[s][0]
                // rather than tuser_in[s-1].last_segment for segment continuation.
                req_seg_valid[s] = req_seg_valid[s-1] && tkeep_in[s][0];
            end

            req_seg_last[s] = req_seg_valid[s] && tuser_in[s].last_segment;
        end
    end

    // Does the packet continue in the next cycle?
    // Same rationale as the cpld path: !MULTI_SOP → tlast, else → last_segment.
    always_ff @(posedge clk) begin
        if (stream_in.tvalid && stream_in.tready) begin
            if (!MULTI_SOP)
                req_cont <= req_seg_valid[NUM_OF_SEG-1] && !stream_in.tlast;
            else
                req_cont <= req_seg_valid[NUM_OF_SEG-1] && !tuser_in[NUM_OF_SEG-1].last_segment;
        end

        if (!rst_n) begin
            req_cont <= 1'b0;
        end
    end

    // Emit only completions iwth data to stream_out_req
    t_seg_tdata tdata_out_req;
    t_seg_tkeep tkeep_out_req;
    t_seg_tuser tuser_out_req;

    always_comb begin
        for (int s = 0; s < NUM_OF_SEG; s += 1) begin
            tdata_out_req[s] = req_seg_valid[s] ? tdata_in[s] : '0;
            tkeep_out_req[s] = req_seg_valid[s] ? tkeep_in[s] : '0;
            tuser_out_req[s] = req_seg_valid[s] ? tuser_in[s] : '0;
        end
    end

    assign stream_out_req.tvalid = |(req_seg_valid) && stream_in.tvalid && !sent_out_req;
    assign stream_out_req.tlast = (NUM_OF_SEG == 1) ? stream_in.tlast : |(req_seg_last);
    assign stream_out_req.tdata = tdata_out_req;
    assign stream_out_req.tkeep = tkeep_out_req;
    assign stream_out_req.tuser_vendor = tuser_out_req;

    always_ff @(posedge clk) begin
        if (stream_out_req.tvalid && stream_out_req.tready)
            sent_out_req <= 1'b1;
        if (stream_in.tready)
            sent_out_req <= 1'b0;

        if (!rst_n)
            sent_out_req <= 1'b0;
    end

endmodule // ofs_fim_pcie_ss_rx_dual_stream

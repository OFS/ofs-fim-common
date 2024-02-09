// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT

//
// Split a DM pipeline into requests no larger than REQ_MAX_BYTES.
// TLP types other than MRd/MWr are allowed in the stream and
// they will be forwarded unmodified. For MWr, only the header
// may be passed through this pipeline. Write data must be split
// and managed outside this module, where it can be reformatted
// for split write packets.
//
// Requests are split as follows:
//  - The first split packet's length is set so that it ends on an
//    address that is a multiple of REQ_MAX_BYTES.
//  - Subsequent packets other than the final packet are all exactly
//    REQ_MAX_BYTES long. Since REQ_MAX_BYTES must be a power of 2 and
//    smaller than a 4KB page, these packets tile neatly in 4KB windows
//    required by PCIe.
//  - The final packet is the remainder of the request, up to REQ_MAX_BYTES.
//
// The same read tag is used for each split request. The logic here assumes
// that the FIM's tag mapper will apply unique tags to each split request
// before they reach the PCIe SS. The FIM tag mapper does not require
// unique AFU-side tags.
//

module ofs_fim_pcie_dm_tx_req_splitter
  #(
    // Maximum size of split requests, defaulting to 8 * the bus width.
    // The default looks strange, just using the bit width of the bus, but
    // dividing by 8 (to get bytes) and then multiplying by 8 is pointless.
    parameter REQ_MAX_BYTES = ofs_pcie_ss_cfg_pkg::TDATA_WIDTH,

    // Are write requests supported in this instance of the pipeline?
    parameter ALLOW_WRITE_REQS = 0,

    // One DM metadata bit is used to mark split read requests. Pick any bit
    // from 0 to 64. This bit will be set only on the final request.
    parameter DM_METADATA_BIT = 63,

    // For writes, the write commit message must be suppressed for all
    // but the final request. A bit in tuser_vendor is used. Setting it
    // to zero turns off the commit message.
    parameter TUSER_STORE_COMMIT_REQ_BIT = ofs_pcie_ss_cfg_pkg::TUSER_STORE_COMMIT_REQ_BIT,

    // Allow control of incoming pipeline depth. In some contexts
    // there is already a skid buffer present.
    parameter PL_DEPTH_IN = 1,

    // Debugging ID
    parameter INSTANCE_ID = 0,
    parameter string PORT_NAME = "A"
    )
   (
    // FIM-side connection
    pcie_ss_axis_if.source o_tx_if,

    // AFU-side connection
    pcie_ss_axis_if.sink   i_tx_if
    );

    // All interfaces are in the same clock domain
    wire clk = o_tx_if.clk;
    wire rst_n = o_tx_if.rst_n;

    localparam TDATA_WIDTH = $bits(i_tx_if.tdata);
    localparam TUSER_WIDTH = $bits(i_tx_if.tuser_vendor);

    localparam DM_METADATA_SAFE_BIT = DM_METADATA_BIT & 31;

    typedef logic [63:0] t_req_addr;
    typedef logic [23:0] t_req_len;

    // synthesis translate_off
    initial
    begin
        if (REQ_MAX_BYTES > 4096)
            $fatal(2, "** ERROR ** %m: REQ_MAX_BYTES must be smaller than 4096!");
        if ((1 << $clog2(REQ_MAX_BYTES)) != REQ_MAX_BYTES)
            $fatal(2, "** ERROR ** %m: REQ_MAX_BYTES must be a power of 2!");
    end
    // synthesis translate_on


    //
    // Inbound TX FIFO
    //
    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) tx_in(clk, rst_n);
    ofs_fim_axis_pipeline #(.PL_DEPTH(PL_DEPTH_IN)) tx_in_pipe (.clk, .rst_n, .axis_s(i_tx_if), .axis_m(tx_in));

    // Decode the incoming header
    pcie_ss_hdr_pkg::PCIe_ReqHdr_t tx_in_hdr;
    assign tx_in_hdr = pcie_ss_hdr_pkg::PCIe_ReqHdr_t'(tx_in.tdata);
    t_req_addr tx_in_hdr_addr;
    assign tx_in_hdr_addr = { tx_in_hdr.host_addr_h, tx_in_hdr.host_addr_m, tx_in_hdr.host_addr_l };
    t_req_len tx_in_hdr_len;
    assign tx_in_hdr_len = { tx_in_hdr.length_h, tx_in_hdr.length_m, tx_in_hdr.length_l };

    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) tx_reg(clk, rst_n);
    logic tx_sop;

    always_ff @(posedge clk) begin
        if (tx_in.tready) begin
            tx_sop <= tx_in.tlast;
        end

        if (!rst_n) begin
            tx_sop <= 1'b1;
        end
    end

    typedef logic [$clog2(4096):0] t_page_bytes;
    typedef logic [$clog2(REQ_MAX_BYTES) : 0] t_split_req_len;

    function automatic logic is_req_needing_split
       (
        input logic [TDATA_WIDTH-1 : 0] tdata,
        input logic [ofs_pcie_ss_plat_cfg_pkg::TUSER_VENDOR_WIDTH-1 : 0] tuser_vendor,
        input logic is_sop
        );

        pcie_ss_hdr_pkg::PCIe_ReqHdr_t hdr = pcie_ss_hdr_pkg::PCIe_ReqHdr_t'(tdata);

        // A DM encoded memory request?
        if (!is_sop || !pcie_ss_hdr_pkg::func_hdr_is_dm_mode(tuser_vendor) ||
            !pcie_ss_hdr_pkg::func_is_mem_req(hdr.fmt_type))
        begin
            // No. Splitting not required.
            return 1'b0;
        end
        else begin
            // Get the start byte offset within a 4KB page
            logic [63:0] start_addr = { hdr.host_addr_h, hdr.host_addr_m, hdr.host_addr_l };
            t_page_bytes start_page_offset = { 1'b0, start_addr[$clog2(4096)-1 : 0] };

            // Request length (bytes)
            logic [23:0] req_len = { hdr.length_h, hdr.length_m, hdr.length_l };

            //
            // Request must be split if it is larger than REQ_MAX_BYTES or if the
            // range crosses a 4KB boundary. Take advantage of REQ_MAX_BYTES being
            // a power of 2.
            //

            t_page_bytes end_page_offset = start_page_offset + req_len[$clog2(REQ_MAX_BYTES) : 0];

            return ((req_len > REQ_MAX_BYTES) || (end_page_offset > 4096));
        end

    endfunction // is_req_needing_split


    t_page_bytes tx_start_page_offset;
    t_req_addr tx_addr_prev;
    t_req_len tx_len_rem, tx_len_rem_next, tx_len, tx_len_prev;
    logic tx_is_last;
    logic tx_needs_split;
    logic tx_req_is_new;
    logic tx_req_is_mrd;
    logic tx_req_is_mwr;
    pcie_ss_hdr_pkg::PCIe_ReqHdr_t tx_out_hdr;
    logic [$bits(i_tx_if.tdata)-1 : 0] tx_out_tdata;
    logic [$bits(i_tx_if.tuser_vendor)-1 : 0] tx_out_tuser_vendor;
    logic illegal_wr_req_error;

    always_comb begin
        tx_is_last = 1'b0;

        //
        // Compute the size of the next split request given the current address
        // and remaining size.
        //
        if (tx_req_is_new) begin
            // First region of a new request. This path will be consumed only when
            // splitting is needed, so we know that it will span at least one
            // aligned REQ_MAX_BYTES boundary. Start by aligning to REQ_MAX_BYTES.
            tx_len = t_split_req_len'(REQ_MAX_BYTES) -
                     tx_start_page_offset[$clog2(REQ_MAX_BYTES)-1 : 0];

            // Calculate the length remaining after tx_len is handled. This is
            // equivalent to "tx_len_rem_next = tx_len_rem - tx_len". Since this
            // calculation is the critical path in the splitter, we go to great
            // lengths here to shorten the path by having at most one carry chain
            // on any of the combinational paths. Extending the offset within
            // REQ_MAX_BYTES by 1s and combining the two arithmetic operations into
            // one cancels out the +1 required in two's complement, leaving us
            // with a single addition.
            tx_len_rem_next = tx_len_rem +
                      // Fill the high bits with 1                            Offset into REQ_MAX_BYTES chunk
                { {($bits(tx_len_rem)-$clog2(REQ_MAX_BYTES)){1'b1}}, tx_start_page_offset[$clog2(REQ_MAX_BYTES)-1 : 0] };
        end
        else begin
            // This path is taken for everything after the first request.
            tx_is_last = (tx_len_rem <= REQ_MAX_BYTES);
            tx_len = tx_is_last ? t_split_req_len'(tx_len_rem) : REQ_MAX_BYTES;

            // Shorten the carry chain by only updating tx_len_rem above
            // REQ_MAX_BYTES chunks. On the path here we know that the
            // base address is aligned to REQ_MAX_BYTES, so only the final
            // tx_is_last request might be shorter than that. Once tx_is_last
            // is set, tx_len_rem_next is irrelevant.
            tx_len_rem_next = tx_len_rem;
            tx_len_rem_next[$bits(tx_len_rem_next)-1 : $clog2(REQ_MAX_BYTES)] =
                tx_len_rem_next[$bits(tx_len_rem_next)-1 : $clog2(REQ_MAX_BYTES)] - 1;
        end

        //
        // Now that the length of the next chunk is known, set up the TLP header.
        //
        tx_out_tdata = tx_reg.tdata;
        tx_out_hdr = pcie_ss_hdr_pkg::PCIe_ReqHdr_t'(tx_out_tdata);
        tx_out_tuser_vendor = tx_reg.tuser_vendor;

        if (tx_needs_split) begin
            { tx_out_hdr.length_h, tx_out_hdr.length_m, tx_out_hdr.length_l } = tx_len;
            { tx_out_hdr.host_addr_h, tx_out_hdr.host_addr_m, tx_out_hdr.host_addr_l } =
                tx_addr_prev + tx_len_prev;
        end
        else begin
            // DM request that wasn't split. Flag it to enable final completion.
            tx_is_last = 1'b1;
        end

        // Mark the packet that holds the final completion for the entire original
        // request. Reads and writes use different marker bits.
        if (tx_req_is_mrd) begin
            // Reads
            if (DM_METADATA_BIT >= 32)
                tx_out_hdr.metadata_h[DM_METADATA_SAFE_BIT] = tx_is_last;
            else
                tx_out_hdr.metadata_l[DM_METADATA_SAFE_BIT] = tx_is_last;
        end

        // Writes
        if (tx_req_is_mwr) begin
            if (tx_is_last) begin
                // Last split write. Even if the AFU doesn't want a completion,
                // the request splitter needs to know the split write is done.
                // Set a metadata bit when the AFU hasn't requested a local
                // completion. The bit doesn't need to be restored since there
                // will be no commit.
                if (!tx_reg.tuser_vendor[TUSER_STORE_COMMIT_REQ_BIT]) begin
                    if (DM_METADATA_BIT >= 32)
                        tx_out_hdr.metadata_h[DM_METADATA_SAFE_BIT] = 1'b1;
                    else
                        tx_out_hdr.metadata_l[DM_METADATA_SAFE_BIT] = 1'b1;
                end
            end
            else begin
                // Disable completions when the packet isn't last.
                tx_out_tuser_vendor[TUSER_STORE_COMMIT_REQ_BIT] = 1'b0;
                if (DM_METADATA_BIT >= 32)
                    tx_out_hdr.metadata_h[DM_METADATA_SAFE_BIT] = 1'b0;
                else
                    tx_out_hdr.metadata_l[DM_METADATA_SAFE_BIT] = 1'b0;
            end
        end

        tx_out_tdata[$bits(tx_out_hdr)-1 : 0] = tx_out_hdr;
    end

    // Consume new requests once the current one has been split completely
    assign tx_in.tready = tx_in.tvalid &&
                          ((tx_reg.tvalid && tx_reg.tready && (tx_is_last || !tx_needs_split)) ||
                           !tx_reg.tvalid);

    // Main splitting stage. Generate one or more requests for every request
    // sitting in tx_reg.
    always_ff @(posedge clk) begin
        if (tx_reg.tvalid && tx_reg.tready) begin
            // Generated an output. Clear tx_reg if the full request is complete.
            tx_reg.tvalid <= (!tx_is_last && tx_needs_split);
            // Update address and length to the portion remaining
            tx_addr_prev <= tx_addr_prev + tx_len_prev;
            tx_len_rem <= tx_len_rem_next;
            tx_len_prev <= tx_len;
            tx_req_is_new <= 1'b0;
        end

        if (tx_in.tready) begin
            // New request accepted from input FIFO. Block traffic if an
            // illegal write request was seen.
            tx_reg.tvalid <= !illegal_wr_req_error;
            tx_reg.tlast <= tx_in.tlast;
            tx_reg.tuser_vendor <= tx_in.tuser_vendor;
            tx_reg.tkeep <= tx_in.tkeep;
            tx_reg.tdata <= tx_in.tdata;

            tx_req_is_mrd <=
                (tx_sop && pcie_ss_hdr_pkg::func_hdr_is_dm_mode(tx_in.tuser_vendor) &&
                 pcie_ss_hdr_pkg::func_is_mrd_req(tx_in_hdr.fmt_type));
            tx_req_is_mwr <=
                (tx_sop && pcie_ss_hdr_pkg::func_hdr_is_dm_mode(tx_in.tuser_vendor) &&
                 pcie_ss_hdr_pkg::func_is_mwr_req(tx_in_hdr.fmt_type));

            tx_needs_split <= is_req_needing_split(tx_in.tdata, tx_in.tuser_vendor, tx_sop);
            tx_req_is_new <= 1'b1;
            tx_addr_prev <= tx_in_hdr_addr;
            tx_start_page_offset <= t_page_bytes'(tx_in_hdr_addr);
            tx_len_rem <= tx_in_hdr_len;
            tx_len_prev <= '0;
        end

        if (!rst_n) begin
            tx_reg.tvalid <= 1'b0;
        end
    end

    // Check for write requests when they aren't supposed to be present
    generate
        if (ALLOW_WRITE_REQS == 0) begin : disable_write_reqs
            always_ff @(posedge clk)
            begin
                if (tx_reg.tvalid && tx_req_is_mwr) begin
                    illegal_wr_req_error <= 1'b1;

                    // synthesis translate_off
                    if (rst_n) $fatal(2, "** ERROR ** %m: Write request seen but ALLOW_WRITE_REQS is 0!");
                    // synthesis translate_on
                end

                if (!rst_n)
                    illegal_wr_req_error <= 1'b0;
            end
        end
        else begin : allow_write_reqs
            assign illegal_wr_req_error = 1'b0;
        end
    endgenerate


    //
    // Outbound TX pipeline
    //
    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) tx_out(clk, rst_n);

    assign tx_reg.tready = tx_out.tready;
    assign tx_out.tvalid = tx_reg.tvalid;
    assign tx_out.tdata = tx_out_tdata;
    assign tx_out.tkeep = tx_reg.tkeep;
    assign tx_out.tlast = tx_reg.tlast;
    assign tx_out.tuser_vendor = tx_out_tuser_vendor;

    // Skid buffer
    ofs_fim_axis_pipeline tx_out_pipe (.clk, .rst_n, .axis_s(tx_out), .axis_m(o_tx_if));


    // ====================================================================
    //
    //  Logging
    //
    // ====================================================================

    // synthesis translate_off
    // Log TLP AXI-S traffic
    int log_fd;

    initial
    begin : log
        log_fd = $fopen($sformatf("log_dm_tx_req_splitter_%s_%0d.tsv", PORT_NAME, INSTANCE_ID), "w");

        // Write module hierarchy to the top of the log
        $fwrite(log_fd, "ofs_fim_pcie_dm_tx_req_splitter.sv: %m\n\n");
    end

`define LOG_PCIE_STREAM_USER(pcie_if, fmt) \
    logic pcie_if``_log_sop; \
    always_ff @(posedge clk) begin \
        if (rst_n && pcie_if.tvalid && pcie_if.tready) begin \
            $fwrite(log_fd, fmt, \
                    pcie_ss_pkg::func_pcie_ss_flit_to_string( \
                        pcie_if``_log_sop, pcie_if.tlast, \
                        pcie_ss_hdr_pkg::func_hdr_is_pu_mode(pcie_if.tuser_vendor), \
                        pcie_if.tdata, pcie_if.tkeep), \
                    pcie_if.tuser_vendor); \
            $fflush(log_fd); \
        end \
        \
        if (pcie_if.tvalid && pcie_if.tready) \
            pcie_if``_log_sop <= pcie_if.tlast; \
        \
        if (!rst_n) \
            pcie_if``_log_sop <= 1'b1; \
    end

    `LOG_PCIE_STREAM_USER(i_tx_if, "i_tx: %s user 0x%x\n")
    `LOG_PCIE_STREAM_USER(o_tx_if, "o_tx: %s user 0x%x\n")
    // synthesis translate_on

endmodule // ofs_fim_pcie_dm_tx_req_splitter

// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT

//
// Split both read and write requests, as necessary. Pass all other traffic
// unmodified. All requests flow through a single pipeline. The request
// splitter uses the same module as the pipeline that handles only reads.
// Once splitting decisions are made, the pipeline rearranges the write
// data stream to align it with split headers.
//

module ofs_fim_pcie_dm_tx_rdwr_req_splitter
  #(
    // Maximum size of split requests, defaulting to 8 * the bus width.
    // The default looks strange, just using the bit width of the bus, but
    // dividing by 8 (to get bytes) and then multiplying by 8 is pointless.
    parameter REQ_MAX_BYTES = ofs_pcie_ss_cfg_pkg::TDATA_WIDTH,

    // One DM metadata bit is used to mark split read requests. Pick any bit
    // from 0 to 64. This bit will be set only on the final request.
    parameter DM_METADATA_BIT = 63,

    // For writes, the write commit message must be suppressed for all
    // but the final request. A bit in tuser_vendor is used. Setting it
    // to one turns off the commit message.
    parameter TUSER_SUPPRESS_COMMIT_MSG = ofs_pcie_ss_cfg_pkg::TUSER_WIDTH - 1,

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
    localparam TKEEP_WIDTH = TDATA_WIDTH/8;

    localparam DM_METADATA_SAFE_BIT = DM_METADATA_BIT & 31;


    // ====================================================================
    //
    //  First, separate the incoming request stream into a header
    //  stream and a data stream. This will allow us to use the same
    //  request splitter for both reads and writes, since the splitter
    //  will see just headers without having to manage payloads.
    //
    // ====================================================================

    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) tx_hdr_if(clk, rst_n);
    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) tx_data_in_if(clk, rst_n);
    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) tx_data_if(clk, rst_n);

    ofs_fim_pcie_hdr_extract
      #(
        .PL_DEPTH_HDR_OUT(1)
        )
      req_hdr_extract
       (
        .stream_source(i_tx_if),
        .hdr_stream_sink(tx_hdr_if),
        .data_stream_sink(tx_data_in_if)
        );


    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) tx_split_hdr_if(clk, rst_n);

    ofs_fim_pcie_dm_tx_req_splitter
      #(
        .REQ_MAX_BYTES(REQ_MAX_BYTES),
        .ALLOW_WRITE_REQS(1),

        .DM_METADATA_BIT(DM_METADATA_BIT),
        .TUSER_SUPPRESS_COMMIT_MSG(TUSER_SUPPRESS_COMMIT_MSG),
        .PL_DEPTH_IN(0),

        .INSTANCE_ID(INSTANCE_ID),
        .PORT_NAME(PORT_NAME)
        )
      req_split
       (
        .i_tx_if(tx_hdr_if),
        .o_tx_if(tx_split_hdr_if)
        );


    //
    // Hold data while the header goes through the request splitter.
    //
    logic data_in_fifo_full;
    assign tx_data_in_if.tready = !data_in_fifo_full;
    logic tx_stg2_do_not_deq_data_in;

    fim_rdack_scfifo
      #(
        .DATA_WIDTH(TDATA_WIDTH + TKEEP_WIDTH + TUSER_WIDTH + 1),
        .DEPTH_LOG2(1)
        )
      data_in_fifo
       (
        .clk,
        .sclr(!rst_n),

        .wdata({ tx_data_in_if.tdata, tx_data_in_if.tkeep, tx_data_in_if.tuser_vendor, tx_data_in_if.tlast }),
        .wreq(tx_data_in_if.tvalid),
        .rdack(tx_data_if.tvalid && tx_data_if.tready && !tx_stg2_do_not_deq_data_in),
        .rdata({ tx_data_if.tdata, tx_data_if.tkeep, tx_data_if.tuser_vendor, tx_data_if.tlast }),
        .wusedw(),
        .rusedw(),
        .wfull(data_in_fifo_full),
        .almfull(),
        .rempty(),
        .rvalid(tx_data_if.tvalid)
        );

    logic tx_data_sop;
    always_ff @(posedge clk)
    begin
        if (tx_data_if.tvalid && tx_data_if.tready)
            tx_data_sop <= tx_data_if.tlast;

        if (!rst_n)
            tx_data_sop <= 1'b1;
    end


    //
    // Stage 1:
    //
    // Data rotation to align data across split packets.
    //
    // The packet splitter has a well defined pattern:
    //   - The first packet is sized so it ends at a naturally
    //     aligned address.
    //   - All intermediate packets (not first, not last) have lengths
    //     that are a multiple of the data bus size. Consequently,
    //     they all require the same rotation. Rotation is dictated
    //     only by the length of the first packet.
    //   - The final packet's length may not be a multiple of the data
    //     bus width, but its start address is. The start address is
    //     all that matters for rotation.
    //

    // Is this the first data flit matching headers from tx_split_hdr_if?
    logic tx_split_data_sop;

    // Rotation amount for stage 1, which works on 64 bit chunks
    logic [$clog2(TDATA_WIDTH / 8)-1 : 0] tx_stg1_rot_cnt;
    logic [TKEEP_WIDTH-1 : 0] tx_stg1_rot_tkeep_mask;

    // Number of data beats matching the current header
    localparam NUM_DATA_BEATS_WIDTH = $clog2(REQ_MAX_BYTES / (TDATA_WIDTH / 8)) + 1;
    logic [NUM_DATA_BEATS_WIDTH-1 : 0] tx_stg1_num_data_beats;
    logic [NUM_DATA_BEATS_WIDTH-1 : 0] tx_stg1_num_data_beats_next;
    logic tx_stg1_data_bubble_required;

    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) tx_stg1_hdr_if(clk, rst_n);
    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) tx_stg2_hdr_if(clk, rst_n);
    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) tx_stg2_data_if(clk, rst_n);

    pcie_ss_hdr_pkg::PCIe_ReqHdr_t tx_split_hdr;
    assign tx_split_hdr = pcie_ss_hdr_pkg::PCIe_ReqHdr_t'(tx_split_hdr_if.tdata);
    wire logic [23:0] tx_split_hdr_len = { tx_split_hdr.length_h, tx_split_hdr.length_m, tx_split_hdr.length_l };
    logic tx_stg1_hdr_is_mrd;

    // Last header for an original request?
    logic tx_split_hdr_is_first, tx_split_hdr_is_last;
    logic tx_stg1_hdr_is_first, tx_stg1_hdr_is_last;
    always_comb
    begin
        if (!pcie_ss_hdr_pkg::func_hdr_is_dm_mode(tx_split_hdr_if.tuser_vendor))
            // PU encoded is never split
            tx_split_hdr_is_last = 1'b1;
        else begin
            // Reads and writes are tagged differently, reads in metadata, writes
            // in tuser_vendor.
            if (pcie_ss_hdr_pkg::func_is_mrd_req(tx_split_hdr.fmt_type)) begin
                if (DM_METADATA_BIT >= 32)
                    tx_split_hdr_is_last = tx_split_hdr.metadata_h[DM_METADATA_SAFE_BIT];
                else
                    tx_split_hdr_is_last = tx_split_hdr.metadata_l[DM_METADATA_SAFE_BIT];
            end
            else if (pcie_ss_hdr_pkg::func_is_mwr_req(tx_split_hdr.fmt_type)) begin
                tx_split_hdr_is_last = !tx_split_hdr_if.tuser_vendor[TUSER_SUPPRESS_COMMIT_MSG];
            end
            else begin
                tx_split_hdr_is_last = 1'b1;
            end
        end
    end

    always_ff @(posedge clk)
    begin
        if (tx_split_hdr_if.tvalid && tx_split_hdr_if.tready)
            tx_split_hdr_is_first <= tx_split_hdr_is_last;

        if (!rst_n)
            tx_split_hdr_is_first <= 1'b1;
    end


    //
    // Header pipeline
    //

    assign tx_split_hdr_if.tready = !tx_stg1_hdr_if.tvalid || tx_stg1_hdr_if.tready;

    // Number of data bus beats, derived from the request length. We know
    // that no packet is larger than REQ_MAX_BYTES, which is guaranteed
    // to be a power of two. If any of the low bits are set,
    // corresponding to fractional sizes of the data bus, round up
    // the by 1.
    assign tx_stg1_num_data_beats_next =
        tx_split_hdr_len[$clog2(TDATA_WIDTH / 8) +: NUM_DATA_BEATS_WIDTH] +
        |(tx_split_hdr_len[$clog2(TDATA_WIDTH / 8)-1 : 0]);

    always_ff @(posedge clk)
    begin
        if (tx_split_hdr_if.tready) begin
            tx_stg1_hdr_if.tvalid <= tx_split_hdr_if.tvalid;
            tx_stg1_hdr_if.tdata <= tx_split_hdr_if.tdata;
            tx_stg1_hdr_if.tkeep <= tx_split_hdr_if.tkeep;
            tx_stg1_hdr_if.tuser_vendor <= tx_split_hdr_if.tuser_vendor;
            tx_stg1_hdr_if.tlast <= tx_split_hdr_if.tlast;

            if (tx_split_hdr_if.tvalid) begin
                tx_stg1_hdr_is_first <= tx_split_hdr_is_first;
                tx_stg1_hdr_is_last <= tx_split_hdr_is_last;

                if (tx_split_hdr_is_first) begin
                    tx_stg1_rot_cnt <= '0;
                    tx_stg1_rot_tkeep_mask <= {TKEEP_WIDTH{1'b1}};

                    if (pcie_ss_hdr_pkg::func_is_mwr_req(tx_split_hdr.fmt_type)) begin
                        // Byte rotation needed for the next split packet is just
                        // the bytes left over above the bus width in the length.
                        // The rotation of the first split packet remains the
                        // confguration for the entire set.
                        tx_stg1_rot_cnt <=
                            $bits(tx_stg1_rot_cnt)'(tx_split_hdr_len);

                        // Mask of tkeep bits to preserve in the last beat of the
                        // first split packet. The mask also is used when merging
                        // data beats while rotating payloads.
                        if ($bits(tx_stg1_rot_cnt)'(tx_split_hdr_len)) begin
                            tx_stg1_rot_tkeep_mask <=
                                ~({TKEEP_WIDTH{1'b1}} << $bits(tx_stg1_rot_cnt)'(tx_split_hdr_len));
                        end
                    end
                end

                if (pcie_ss_hdr_pkg::func_is_mrd_req(tx_split_hdr.fmt_type)) begin
                    tx_stg1_num_data_beats <= 1'b1;
                    tx_stg1_hdr_is_mrd <= 1'b1;
                end
                else begin
                    // Number of beats in this request after splitting
                    tx_stg1_num_data_beats <= tx_stg1_num_data_beats_next;
                    tx_stg1_hdr_is_mrd <= 1'b0;
                end

                // A data pipeline bubble is required before stage 2 in order
                // to set the rotation amount properly when this is the SOP
                // of a new request, more split packets will follow, and the
                // first split packet is only a single data beat. For anything
                // longer, the rotation count will be updated in the normal
                // pipeline without requiring a delay.
                //
                // The bubble is also required for short final split packets
                // in order to set the tkeep mask properly.
                tx_stg1_data_bubble_required <=
                    pcie_ss_hdr_pkg::func_is_mwr_req(tx_split_hdr.fmt_type) &&
                    (tx_split_hdr_is_first || tx_split_hdr_is_last) &&
                    (tx_stg1_num_data_beats_next == NUM_DATA_BEATS_WIDTH'(1));
            end
        end

        if (!rst_n) begin
            tx_stg1_hdr_if.tvalid <= 1'b0;
            tx_stg1_hdr_if.tlast <= 1'b1;
            tx_stg1_rot_cnt <= '0;
            tx_stg1_rot_tkeep_mask <= {TKEEP_WIDTH{1'b1}};
            tx_stg1_hdr_is_mrd <= 1'b0;
        end
    end

    logic tx_stg2_hdr_is_first, tx_stg2_hdr_is_last;
    logic tx_stg2_hdr_is_mrd;
    logic [$clog2(TDATA_WIDTH / 8)-1 : 0] tx_stg2_hdr_rot_cnt;
    logic [TKEEP_WIDTH-1 : 0] tx_stg2_rot_tkeep_mask;
    logic [NUM_DATA_BEATS_WIDTH-1 : 0] tx_stg2_num_data_beats;
    logic tx_stg2_data_split_sop;
    logic tx_stg2_data_bubble_active;
    logic tx_stg2_data_need_drain;
    logic tx_stg2_data_final_pkt_is_drain;

    pcie_ss_hdr_pkg::PCIe_ReqHdr_t tx_stg2_hdr;
    assign tx_stg2_hdr = pcie_ss_hdr_pkg::PCIe_ReqHdr_t'(tx_stg2_hdr_if.tdata);
    wire logic [23:0] tx_stg2_hdr_len = { tx_stg2_hdr.length_h, tx_stg2_hdr.length_m, tx_stg2_hdr.length_l };

    // The stage 1 header must be used in the data pipeline's stage 2 on the
    // first beat of a new packet if the header reached stage 2 in the same
    // cycle. The stage 2 header registers will be available in the next cycle.
    wire tx_stg2_data_use_stg1_hdr = tx_stg2_data_split_sop && !tx_stg2_data_bubble_active;

    // Headers transition to stage 2 only when the SOP data beat is also available.
    assign tx_stg1_hdr_if.tready = (!tx_stg2_hdr_if.tvalid || tx_stg2_hdr_if.tready) &&
                                   !tx_stg2_data_bubble_active &&
                                   !tx_stg2_data_need_drain &&
                                   tx_stg2_data_split_sop &&
                                   (tx_stg2_data_final_pkt_is_drain ||
                                    tx_data_if.tvalid && (!tx_stg2_data_if.tvalid || tx_stg2_data_if.tready));

    // Data pipeline bubble management, driven by stages 1 and 2 of the header.
    // See where tx_stg1_data_bubble_required is set above for an explanation.
    always_ff @(posedge clk)
    begin
        // Clear the request when the next data message is transferred
        if (tx_data_if.tvalid && tx_data_if.tready) begin
            tx_stg2_data_bubble_active <= 1'b0;
        end

        // Header pipeline advanced, perhaps with a new bubble request
        if (tx_stg1_hdr_if.tvalid && tx_stg1_hdr_if.tready) begin
            tx_stg2_data_bubble_active <= tx_stg1_data_bubble_required && !tx_stg2_data_final_pkt_is_drain;
        end

        if (!rst_n) begin
            tx_stg2_data_bubble_active <= 1'b0;
        end
    end

    // Main stage2 transfer
    always_ff @(posedge clk)
    begin
        if (tx_stg2_hdr_if.tready) begin
            tx_stg2_hdr_if.tvalid <= 1'b0;
        end

        if (tx_stg1_hdr_if.tvalid && tx_stg1_hdr_if.tready) begin
            tx_stg2_hdr_if.tvalid <= tx_stg1_hdr_if.tvalid;
            tx_stg2_hdr_if.tdata <= tx_stg1_hdr_if.tdata;
            tx_stg2_hdr_if.tkeep <= tx_stg1_hdr_if.tkeep;
            tx_stg2_hdr_if.tuser_vendor <= tx_stg1_hdr_if.tuser_vendor;
            tx_stg2_hdr_if.tlast <= tx_stg1_hdr_if.tlast;

            tx_stg2_hdr_is_first <= tx_stg1_hdr_is_first;
            tx_stg2_hdr_is_last <= tx_stg1_hdr_is_last;
            tx_stg2_hdr_rot_cnt <= tx_stg1_rot_cnt;
            tx_stg2_rot_tkeep_mask <= tx_stg1_rot_tkeep_mask;
            tx_stg2_num_data_beats <= tx_stg1_num_data_beats;
            tx_stg2_hdr_is_mrd <= tx_stg1_hdr_is_mrd;
        end

        if (!rst_n) begin
            tx_stg2_hdr_if.tvalid <= 1'b0;
            tx_stg2_hdr_is_first <= 1'b1;
            tx_stg2_hdr_is_last <= 1'b0;
            tx_stg2_hdr_rot_cnt <= '0;
            tx_stg2_rot_tkeep_mask <= {TKEEP_WIDTH{1'b1}};
            tx_stg2_num_data_beats <= '0;
            tx_stg2_hdr_is_mrd <= 1'b0;
        end
    end


    //
    // Data pipeline begins in sync with stage 2 of the header pipeline, after
    // rotation and split lengths have been computed.
    //

    logic [NUM_DATA_BEATS_WIDTH-1 : 0] tx_stg2_rem_data_beats;

    // On split SOP, state must come from the header stage 1 registers. After
    // SOP, the header has migrated in sync with the first split data beat.
    wire tx_stg2_data_split_tlast =
        tx_stg2_data_use_stg1_hdr ? (tx_stg1_num_data_beats == NUM_DATA_BEATS_WIDTH'(1)) :
                                    (tx_stg2_rem_data_beats == NUM_DATA_BEATS_WIDTH'(1));
    wire tx_stg2_hdr_is_first_split =
        tx_stg2_data_use_stg1_hdr ? tx_stg1_hdr_is_first : tx_stg2_hdr_is_first;
    wire tx_stg2_hdr_is_last_split =
        tx_stg2_data_use_stg1_hdr ? tx_stg1_hdr_is_last : tx_stg2_hdr_is_last;

    wire tx_stg2_is_mrd =
        tx_stg2_data_use_stg1_hdr ? tx_stg1_hdr_is_mrd : tx_stg2_hdr_is_mrd;

    // When splitting read requests the data input stream would normally be
    // dequeued once for every split. This would pull incoming data that does
    // not exist. When this flag is set, most of the logic here acts as though
    // data was fetched, but the incoming source of data is left in place
    // so it can be reused with the remainder of the split read request.
    assign tx_stg2_do_not_deq_data_in = !tx_stg2_hdr_is_last_split && tx_stg2_is_mrd;


    always_ff @(posedge clk)
    begin
        if (tx_data_if.tvalid && tx_data_if.tready) begin
            tx_stg2_data_split_sop <= tx_stg2_data_split_tlast;

            // The number of data beats remaining comes initially from
            // the header pipeline and then is counted with data.
            if (tx_stg2_data_split_sop) begin
                if (tx_stg2_data_use_stg1_hdr)
                    tx_stg2_rem_data_beats <= tx_stg1_num_data_beats - 1;
                else
                    tx_stg2_rem_data_beats <= tx_stg2_num_data_beats - 1;
            end
            else begin
                tx_stg2_rem_data_beats <= tx_stg2_rem_data_beats - 1;
            end
        end
        else if (tx_stg1_hdr_if.tvalid && tx_stg1_hdr_if.tready) begin
            tx_stg2_rem_data_beats <= tx_stg1_num_data_beats;
        end

        if ((tx_stg2_data_need_drain || tx_stg2_data_final_pkt_is_drain) && tx_stg2_data_if.tready) begin
            tx_stg2_data_split_sop <= 1'b1;
            tx_stg2_rem_data_beats <= 1;
        end

        if (!rst_n) begin
            tx_stg2_data_split_sop <= 1'b1;
        end
    end

    // Data rotation
    logic [TDATA_WIDTH-1 : 0] tx_tdata_rot;

    ofs_fim_rotate_words_comb
      #(
        .DATA_WIDTH(TDATA_WIDTH),
        .WORD_WIDTH(8),
        .ROTATE_LEFT(0)
        )
      tx_rot_d
       (
        .d_in(tx_data_if.tdata),
        .rot_cnt(tx_stg2_hdr_rot_cnt),
        .d_out(tx_tdata_rot)
        );

    // Data can move if it is not SOP or if there is also a header available.
    // When fetching SOP, the data pipeline bubble request must also be honored.
    assign tx_data_if.tready = (!tx_stg2_data_if.tvalid || tx_stg2_data_if.tready) &&
                               !tx_stg2_data_need_drain && !tx_stg2_data_final_pkt_is_drain &&
                               (! tx_stg2_data_split_sop || tx_stg2_data_bubble_active ||
                                (tx_stg1_hdr_if.tvalid && !tx_stg1_data_bubble_required &&
                                 (!tx_stg2_hdr_if.tvalid || tx_stg2_hdr_if.tready)));

    logic [TDATA_WIDTH-1 : 0] tx_stg2_tdata_prev;

    always_ff @(posedge clk)
    begin
        if (tx_stg2_data_if.tready) begin
            tx_stg2_data_if.tvalid <= 1'b0;
        end

        if (tx_stg2_data_final_pkt_is_drain && tx_stg1_hdr_if.tvalid && tx_stg1_hdr_if.tready) begin
            tx_stg2_data_final_pkt_is_drain <= 1'b0;
            tx_stg2_data_need_drain <= 1'b1;
        end

        if (tx_stg2_data_need_drain && tx_stg2_data_if.tready) begin
            tx_stg2_data_need_drain <= 1'b0;

            tx_stg2_data_if.tvalid <= 1'b1;
            tx_stg2_data_if.tlast <= 1'b1;
            tx_stg2_data_if.tdata <= tx_stg2_tdata_prev;

            if ($bits(tx_stg2_hdr_rot_cnt)'(tx_stg2_hdr_len))
                tx_stg2_data_if.tkeep <= ~({TKEEP_WIDTH{1'b1}} << $bits(tx_stg2_hdr_rot_cnt)'(tx_stg2_hdr_len));
            else
                tx_stg2_data_if.tkeep <= {TKEEP_WIDTH{1'b1}};
        end
        else if (tx_data_if.tvalid && tx_data_if.tready) begin
            tx_stg2_data_need_drain <= tx_data_if.tlast && !tx_stg2_data_split_tlast &&
                                       !tx_stg2_is_mrd;
            tx_stg2_data_final_pkt_is_drain <= tx_data_if.tlast && !tx_stg2_hdr_is_last_split &&
                                               !tx_stg2_is_mrd;

            tx_stg2_data_if.tvalid <= tx_data_if.tvalid;
            tx_stg2_data_if.tuser_vendor <= tx_data_if.tuser_vendor;
            tx_stg2_data_if.tlast <= tx_stg2_data_split_tlast;

            if (tx_stg2_hdr_is_first_split || tx_stg2_rot_tkeep_mask[TKEEP_WIDTH-1]) begin
                // The first split packet takes unrotated data
                tx_stg2_data_if.tdata <= tx_data_if.tdata;
            end
            else begin
                // After the first split packet, data comes from two beats
                // that have to be combined.
                for (int i = 0; i < TKEEP_WIDTH; i = i + 1) begin
                    if (!tx_stg2_rot_tkeep_mask[TKEEP_WIDTH-1-i])
                        tx_stg2_data_if.tdata[i*8 +: 8] <= tx_stg2_tdata_prev[i*8 +: 8];
                    else
                        tx_stg2_data_if.tdata[i*8 +: 8] <= tx_tdata_rot[i*8 +: 8];
                end
            end

            tx_stg2_data_if.tkeep <= {TKEEP_WIDTH{1'b1}};
            if (tx_stg2_data_split_tlast) begin
                if (tx_stg2_hdr_is_first_split) begin
                    tx_stg2_data_if.tkeep <= tx_stg2_rot_tkeep_mask;
                end
                if (tx_stg2_hdr_is_last_split) begin
                    if ($bits(tx_stg2_hdr_rot_cnt)'(tx_stg2_hdr_len))
                        tx_stg2_data_if.tkeep <= ~({TKEEP_WIDTH{1'b1}} << $bits(tx_stg2_hdr_rot_cnt)'(tx_stg2_hdr_len));
                    else
                        tx_stg2_data_if.tkeep <= {TKEEP_WIDTH{1'b1}};
                end
                if ((tx_stg2_hdr_is_last_split && tx_stg2_hdr_is_first_split) || tx_stg2_is_mrd) begin
                    tx_stg2_data_if.tkeep <= tx_data_if.tkeep;
                end
            end

            tx_stg2_tdata_prev <= tx_tdata_rot;
        end

        if (!rst_n) begin
            tx_stg2_data_if.tvalid <= 1'b0;
            tx_stg2_data_need_drain <= 1'b0;
            tx_stg2_data_final_pkt_is_drain <= 1'b0;
        end
    end

    //
    // Merge the header and data streams back into a single stream
    // with in-band headers.
    //
    ofs_fim_pcie_hdr_merge
      #(
        // Simple buffers
        .PL_MODE_HDR_IN(1),
        .PL_MODE_DATA_IN(1)
        )
      hdr_merge
       (
        .hdr_stream_source(tx_stg2_hdr_if),
        .data_stream_source(tx_stg2_data_if),
        .stream_sink(o_tx_if)
        );


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
        log_fd = $fopen($sformatf("log_dm_tx_rdwr_req_splitter_%0d.tsv", INSTANCE_ID), "w");

        // Write module hierarchy to the top of the log
        $fwrite(log_fd, "ofs_fim_pcie_dm_tx_rdwr_req_splitter.sv: %m\n\n");
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

`define LOG_PCIE_DATA_STREAM(pcie_if, fmt) \
    always_ff @(posedge clk) begin \
        if (rst_n && pcie_if.tvalid && pcie_if.tready) begin \
            $fwrite(log_fd, fmt, \
                    pcie_ss_pkg::func_pcie_ss_flit_to_string( \
                        1'b0, pcie_if.tlast, \
                        pcie_ss_hdr_pkg::func_hdr_is_pu_mode(pcie_if.tuser_vendor), \
                        pcie_if.tdata, pcie_if.tkeep)); \
            $fflush(log_fd); \
        end \
    end

    `LOG_PCIE_STREAM_USER(i_tx_if,        "i_tx_if:         %s user 0x%x\n")
    `LOG_PCIE_STREAM_USER(o_tx_if,        "o_tx_if:         %s user 0x%x\n")
    `LOG_PCIE_STREAM_USER(tx_stg2_hdr_if, "tx_stg2_hdr_if:  %s user 0x%x\n")
    `LOG_PCIE_DATA_STREAM(tx_stg2_data_if,"tx_stg2_data_if: %s\n")
    // synthesis translate_on

endmodule // ofs_fim_pcie_dm_tx_rdwr_req_splitter

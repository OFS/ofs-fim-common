// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT

//
// Recombine completions that were split by ofs_fim_pcie_dm_req_splitter()
// into a single TLP packet.
//
// The connected ports are the same as those of ofs_fim_pcie_dm_req_splitter().
// Please read the header there for a discussion of read requests on TX-A and
// TX-B and the completion stream.
//
// This module depends on completions arriving in request order, both within
// a single packet and across packets. Completions from one request may not
// be interleaved with completions from a different request. Splitting
// must follow exactly the algorithm as described in ofs_fim_pcie_dm_req_splitter().
//

module ofs_fim_pcie_dm_cpl_merge
  #(
    // Select "H" to record read length in metadata_h, "L" for metadata_l.
    // Metadata is restored before completions are returned, making the choice
    // unimportant for most situations.
    parameter METADATA_GROUP = "H",

    // If non-zero, a detected error in the completion stream will block traffic.
    parameter BLOCK_ON_ERROR = 1,

    // Debugging ID
    parameter INSTANCE_ID = 0
    )
   (
    // FIM-side connections
    pcie_ss_axis_if.source o_tx_a_if,
    pcie_ss_axis_if.source o_tx_b_if,
    pcie_ss_axis_if.sink   i_rx_cpl_if,

    // AFU-side connections
    pcie_ss_axis_if.sink   i_tx_a_if,
    pcie_ss_axis_if.sink   i_tx_b_if,
    pcie_ss_axis_if.source o_rx_cpl_if
    );

    wire clk = i_rx_cpl_if.clk;
    wire rst_n = i_rx_cpl_if.rst_n;

    localparam TDATA_WIDTH = $bits(i_rx_cpl_if.tdata);
    localparam TUSER_WIDTH = $bits(i_rx_cpl_if.tuser_vendor);
    localparam TKEEP_WIDTH = TDATA_WIDTH/8;

    // Tag indexed RAM for tracking metadata of original read request before split
    typedef logic [$clog2(ofs_pcie_ss_cfg_pkg::PCIE_TILE_MAX_TAGS)-1 : 0] t_req_tag;
    typedef logic [23:0] t_req_len_bytes;
    t_req_tag meta_ram_raddr;
    t_req_len_bytes meta_ram_rdata;

    logic error;


    // ====================================================================
    //
    //  RX path -- consume split completions and merge them back into
    //  a single completion packet.
    //
    //  This only works when completions are returned in request order!
    //
    // ====================================================================

    //
    // First, separate the incoming completion stream into a header
    // stream and a data stream. All but the first header in split
    // completions will be discarded.
    //
    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) rx_cpl_hdr_if(clk, rst_n);
    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) rx_cpl_data_if(clk, rst_n);

    ofs_fim_pcie_hdr_extract
      cpl_hdr_extract
       (
        .stream_source(i_rx_cpl_if),
        .hdr_stream_sink(rx_cpl_hdr_if),
        .data_stream_sink(rx_cpl_data_if)
        );

    logic rx_cpl_data_sop;
    always_ff @(posedge clk)
    begin
        if (rx_cpl_data_if.tvalid && rx_cpl_data_if.tready)
            rx_cpl_data_sop <= rx_cpl_data_if.tlast;

        if (!rst_n)
            rx_cpl_data_sop <= 1'b1;
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

    // Is this the first split packet from an original request? These
    // are the only headers that will be preserved.
    logic orig_packet_sop;

    // Rotation amount for stage 1, which works on 64 bit chunks
    logic [$clog2(TDATA_WIDTH / 8)-1 : 0] rx_stg1_rot_cnt;
    logic [$clog2(TDATA_WIDTH / 8)-1 : 0] rx_stg1_rot_cnt_next;

    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) rx_stg1_hdr_if(clk, rst_n);
    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) rx_stg1_data_if(clk, rst_n);
    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) rx_stg2_hdr_if(clk, rst_n);
    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) rx_stg2_data_if(clk, rst_n);

    // Consume headers only on SOP beat of the data stream so that headers stay
    // together with their data.
    assign rx_cpl_hdr_if.tready = (!rx_stg1_hdr_if.tvalid || rx_stg1_hdr_if.tready) &&
                                  !error &&
                                  rx_cpl_data_sop &&
                                  rx_cpl_data_if.tvalid && (!rx_stg1_data_if.tvalid || rx_stg1_data_if.tready);

    pcie_ss_hdr_pkg::PCIe_OrdCplHdr_t rx_cpl_hdr;
    assign rx_cpl_hdr = pcie_ss_hdr_pkg::PCIe_ReqHdr_t'(rx_cpl_hdr_if.tdata);
    assign meta_ram_raddr = t_req_tag'(rx_cpl_hdr.tag);

    // Anything PU encoded is automatically the final completion
    wire rx_cpl_hdr_is_fc =
        (pcie_ss_hdr_pkg::func_hdr_is_dm_mode(rx_cpl_hdr_if.tuser_vendor) &&
         pcie_ss_hdr_pkg::func_is_completion(rx_cpl_hdr.fmt_type)) ? rx_cpl_hdr.FC : 1'b1;

    // Header pipeline
    assign rx_stg1_hdr_if.tready = !rx_stg1_hdr_if.tvalid || rx_stg2_hdr_if.tready;

    always_ff @(posedge clk)
    begin
        if (rx_stg1_hdr_if.tready) begin
            rx_stg1_hdr_if.tvalid <= 1'b0;
        end

        if (rx_cpl_hdr_if.tvalid && rx_cpl_hdr_if.tready) begin
            // Only consume the first header. All others will be dropped here
            // by asserting tready but not writing to rx_stg1_hdr_if.
            if (orig_packet_sop) begin
                rx_stg1_hdr_if.tvalid <= 1'b1;
                rx_stg1_hdr_if.tdata <= rx_cpl_hdr_if.tdata;
                rx_stg1_hdr_if.tkeep <= rx_cpl_hdr_if.tkeep;
                rx_stg1_hdr_if.tuser_vendor <= rx_cpl_hdr_if.tuser_vendor;

                // Byte rotation needed for the next split packet is just
                // the bytes left over above the bus width in the length.
                rx_stg1_rot_cnt_next <=
                    $bits(rx_stg1_rot_cnt_next)'({ rx_cpl_hdr.length_x, rx_cpl_hdr.length_h,
                                                   rx_cpl_hdr.length_m, rx_cpl_hdr.length_l });
            end

            // The packet splitter ensures that the FC bit is set only on the
            // last completion.
            orig_packet_sop <= rx_cpl_hdr_is_fc;
            if (rx_cpl_hdr_is_fc) begin
                // Stop rotating since the packet is done
                rx_stg1_rot_cnt_next <= '0;
            end
        end

        if (!rst_n) begin
            rx_stg1_hdr_if.tvalid <= 1'b0;
            rx_stg1_hdr_if.tlast <= 1'b1;
            orig_packet_sop <= 1'b1;
            rx_stg1_rot_cnt_next <= '0;
        end
    end

    pcie_ss_hdr_pkg::PCIe_OrdCplHdr_t rx_stg1_cpl_hdr;
    assign rx_stg1_cpl_hdr = pcie_ss_hdr_pkg::PCIe_OrdCplHdr_t'(rx_stg1_hdr_if.tdata);


    // The original metadata RAM is read along with rx_cpl_hdr. It becomes available the
    // next cycle, when rx_stg1_hdr_if is written. If the pipeline stalls, the value
    // will be held in meta_ram_rdata_reg. Only one of the two valid flags will be set
    // in a given cycle.
    logic meta_ram_rdata_valid, meta_ram_rdata_reg_valid;
    t_req_len_bytes meta_ram_rdata_reg;
    t_req_len_bytes meta_rdata_merged;
    assign meta_rdata_merged = meta_ram_rdata_reg_valid ? meta_ram_rdata_reg : meta_ram_rdata;

    always_ff @(posedge clk)
    begin
        if (meta_ram_rdata_valid) begin
            meta_ram_rdata_valid <= 1'b0;
            meta_ram_rdata_reg_valid <= 1'b1;
            meta_ram_rdata_reg <= meta_ram_rdata;
        end

        if (rx_cpl_hdr_if.tvalid && rx_cpl_hdr_if.tready && orig_packet_sop) begin
            meta_ram_rdata_valid <= 1'b1;
            meta_ram_rdata_reg_valid <= 1'b0;
        end

        if (!rst_n) begin
            meta_ram_rdata_valid <= 1'b0;
            meta_ram_rdata_reg_valid <= 1'b0;
        end
    end


    // Data rotation
    logic [TDATA_WIDTH-1 : 0] rx_stg1_tdata_rot;
    logic [TKEEP_WIDTH-1 : 0] rx_stg1_tkeep_rot;

    ofs_fim_rotate_words_comb
      #(
        .DATA_WIDTH(TDATA_WIDTH),
        .WORD_WIDTH(8)
        )
      rx_stg1_rot_d
       (
        .d_in(rx_cpl_data_if.tdata),
        .rot_cnt(rx_stg1_rot_cnt),
        .d_out(rx_stg1_tdata_rot)
        );

    ofs_fim_rotate_words_comb
      #(
        .DATA_WIDTH(TKEEP_WIDTH),
        .WORD_WIDTH(1)
        )
      rx_stg1_rot_k
       (
        .d_in(rx_cpl_data_if.tkeep),
        .rot_cnt(rx_stg1_rot_cnt),
        .d_out(rx_stg1_tkeep_rot)
        );

    assign rx_cpl_data_if.tready = (!rx_stg1_data_if.tvalid || rx_stg1_data_if.tready) &&
                                   (!rx_cpl_data_sop ||
                                    (rx_cpl_hdr_if.tvalid && (!rx_stg1_hdr_if.tvalid || rx_stg1_hdr_if.tready)));

    // Data stream tlast for the final completion of the original packet?
    // For the first beat in a completion (rx_cpl_data_sop), look in the matching
    // header. Header arrival is aligned with SOP of the data by tready management
    // of rx_cpl_data_if and rx_cpl_hdr_if. If not SOP, then check orig_packet_sop.
    // Checking SOP seems counterintuitive, but by the time of this check,
    // orig_packet_sop has been set for the arrival of the next packet.
    wire rx_stg1_data_final_tlast = rx_cpl_data_if.tlast &&
                                    (rx_cpl_data_sop ? rx_cpl_hdr_is_fc : orig_packet_sop);
    logic rx_stg1_data_final_tlast_q;

    logic rx_stg1_data_orig_sop_reg;
    wire rx_stg1_data_orig_sop = rx_cpl_data_sop ? orig_packet_sop : rx_stg1_data_orig_sop_reg;

    logic [TKEEP_WIDTH-1 : 0] rx_stg2_rot_mask;
    logic rx_stg2_must_drain;

    assign rx_stg1_data_if.tready = !rx_stg1_data_if.tvalid ||
                                    (rx_stg2_data_if.tready && !rx_stg2_must_drain);

    always_ff @(posedge clk)
    begin
        if (rx_stg1_data_if.tready) begin
            rx_stg1_data_if.tvalid <= 1'b0;
        end

        if (rx_cpl_data_if.tvalid && rx_cpl_data_if.tready) begin
            rx_stg1_data_if.tvalid <= 1'b1;
            rx_stg1_data_if.tdata <= rx_stg1_tdata_rot;
            rx_stg1_data_if.tkeep <= rx_stg1_tkeep_rot;
            rx_stg1_data_if.tlast <= rx_stg1_data_final_tlast;

            rx_stg1_data_if.tuser_vendor <= rx_cpl_data_if.tuser_vendor;

            if (rx_cpl_data_sop)
                rx_stg1_data_orig_sop_reg <= orig_packet_sop;

            rx_stg1_data_final_tlast_q <= rx_stg1_data_final_tlast;
            if (rx_stg1_data_final_tlast_q) begin
                // End of original packet. Reset the rotation mask.
                rx_stg2_rot_mask <= {TKEEP_WIDTH{1'b1}};
            end

            if (rx_cpl_data_if.tlast) begin
                if (rx_cpl_data_sop && orig_packet_sop && !rx_cpl_hdr_is_fc) begin
                    // Special case: the first split packet is very short, fitting
                    // in a single beat, but there are more to come in the merged
                    // packet. The rotation count hasn't been registered yet.
                    rx_stg1_rot_cnt <=
                        $bits(rx_stg1_rot_cnt)'({ rx_cpl_hdr.length_x, rx_cpl_hdr.length_h,
                                                  rx_cpl_hdr.length_m, rx_cpl_hdr.length_l });
                end
                else if (rx_cpl_data_sop && rx_cpl_hdr_is_fc) begin
                    // Another short packet case: the final split packet is a
                    // single beat.
                    rx_stg1_rot_cnt <= '0;
                end
                else begin
                    // First split packet is more than one beat. Pick up the
                    // rotation from the value registered when processing the
                    // first header.
                    rx_stg1_rot_cnt <= rx_stg1_rot_cnt_next;
                end

                if (rx_stg1_data_orig_sop && !rx_stg1_data_final_tlast) begin
                    // tkeep from the first split packet becomes the mask
                    // for merging future rotated packets. Special case for
                    // no rotation needed (high tkeep bit is 1).
                    rx_stg2_rot_mask <=
                        rx_cpl_data_if.tkeep[TKEEP_WIDTH-1] ? {TKEEP_WIDTH{1'b1}} :
                                                              ~rx_cpl_data_if.tkeep;
                end
            end
        end

        if (!rst_n) begin
            rx_stg1_data_if.tvalid <= 1'b0;
            rx_stg1_rot_cnt <= '0;
            rx_stg1_data_orig_sop_reg <= '0;
            rx_stg2_rot_mask <= {TKEEP_WIDTH{1'b1}};
            rx_stg1_data_final_tlast_q <= 1'b0;
        end
    end


    //
    // Stage 2:
    //
    // Merge back-to-back beats of the rotated data stream in order to construct
    // the contiguous data stream, restoring a single completion for split requests.
    //

    // Restore the original length to the merged header. It was preserved in
    // the request metadata field.
    pcie_ss_hdr_pkg::PCIe_OrdCplHdr_t rx_stg2_cpl_hdr_in;
    always_comb
    begin
        rx_stg2_cpl_hdr_in = rx_stg1_cpl_hdr;
        if (pcie_ss_hdr_pkg::func_is_completion(rx_stg1_cpl_hdr.fmt_type) &&
            pcie_ss_hdr_pkg::func_hdr_is_dm_mode(rx_stg1_hdr_if.tuser_vendor))
        begin
            rx_stg2_cpl_hdr_in.FC = 1'b1;

            { rx_stg2_cpl_hdr_in.length_x, rx_stg2_cpl_hdr_in.length_h,
              rx_stg2_cpl_hdr_in.length_m, rx_stg2_cpl_hdr_in.length_l } =
                (METADATA_GROUP == "H") ? t_req_len_bytes'(rx_stg1_cpl_hdr.metadata_h) :
                                          t_req_len_bytes'(rx_stg1_cpl_hdr.metadata_l);

            // Restore the original metadata
            if (METADATA_GROUP == "H")
                rx_stg2_cpl_hdr_in.metadata_h[$bits(t_req_len_bytes)-1 : 0] = meta_rdata_merged;
            else
                rx_stg2_cpl_hdr_in.metadata_l[$bits(t_req_len_bytes)-1 : 0] = meta_rdata_merged;
        end
    end

    always_ff @(posedge clk)
    begin
        if (rx_stg2_hdr_if.tready) begin
            rx_stg2_hdr_if.tvalid <= rx_stg1_hdr_if.tvalid;

            rx_stg2_hdr_if.tdata <= rx_stg1_hdr_if.tdata;
            rx_stg2_hdr_if.tdata[$bits(rx_stg2_cpl_hdr_in)-1 : 0]  <= rx_stg2_cpl_hdr_in;

            rx_stg2_hdr_if.tkeep <= rx_stg1_hdr_if.tkeep;
            rx_stg2_hdr_if.tlast <= rx_stg1_hdr_if.tlast;
            rx_stg2_hdr_if.tuser_vendor <= rx_stg1_hdr_if.tuser_vendor;
        end

        if (!rst_n) begin
            rx_stg2_hdr_if.tvalid <= 1'b0;
        end
    end

    logic [TDATA_WIDTH-1 : 0] rx_stg2_tdata_prev;
    logic [TKEEP_WIDTH-1 : 0] rx_stg2_tkeep_prev;

    // The last beat with rotated data might require an extra cycle to drain from
    // the previous beat.
    wire rx_stg2_must_drain_next = !rx_stg2_rot_mask[0] & rx_stg1_data_if.tkeep[0];

    always_ff @(posedge clk)
    begin
        if (rx_stg2_data_if.tready) begin
            rx_stg2_data_if.tvalid <= 1'b0;
        end

        if (rx_stg2_data_if.tready && rx_stg2_must_drain) begin
            rx_stg2_data_if.tvalid <= 1'b1;
            rx_stg2_data_if.tkeep <= rx_stg2_tkeep_prev;
            rx_stg2_data_if.tlast <= 1'b1;
            rx_stg2_must_drain <= 1'b0;

            rx_stg2_data_if.tdata <= rx_stg2_tdata_prev;
            for (int i = 0; i < TKEEP_WIDTH; i = i + 1) begin
                if (!rx_stg2_tkeep_prev[i]) begin
                    rx_stg2_data_if.tdata[i*8 +: 8] <= '0;
                end
            end

            rx_stg2_tkeep_prev <= {TKEEP_WIDTH{1'b1}};
        end
        else if (rx_stg1_data_if.tvalid && rx_stg1_data_if.tready) begin
            rx_stg2_data_if.tvalid <= rx_stg1_data_if.tkeep[TKEEP_WIDTH-1] || rx_stg1_data_if.tlast;
            rx_stg2_data_if.tlast <= rx_stg1_data_if.tlast && !rx_stg2_must_drain_next;
            rx_stg2_must_drain <= rx_stg1_data_if.tlast && rx_stg2_must_drain_next;
            rx_stg2_data_if.tuser_vendor <= rx_stg1_data_if.tuser_vendor;

            rx_stg2_data_if.tkeep <= (~rx_stg2_rot_mask & rx_stg2_tkeep_prev) |
                                     (rx_stg2_rot_mask & rx_stg1_data_if.tkeep);

            rx_stg2_data_if.tdata <= rx_stg2_tdata_prev;
            for (int i = 0; i < TKEEP_WIDTH; i = i + 1) begin
                if (rx_stg2_rot_mask[i]) begin
                    rx_stg2_data_if.tdata[i*8 +: 8] <= rx_stg1_data_if.tdata[i*8 +: 8];
                end
            end

            rx_stg2_tdata_prev <= rx_stg1_data_if.tdata;
            if (rx_stg1_data_if.tlast && !rx_stg2_must_drain_next)
                rx_stg2_tkeep_prev <= {TKEEP_WIDTH{1'b1}};
            else
                rx_stg2_tkeep_prev <= rx_stg1_data_if.tkeep & ~rx_stg2_rot_mask;
        end

        if (!rst_n) begin
            rx_stg2_data_if.tvalid <= 1'b0;
            rx_stg2_must_drain <= 1'b0;
            rx_stg2_tkeep_prev <= {TKEEP_WIDTH{1'b1}};
        end
    end


    //
    // Finally, merge the remaining header and data streams back into
    // a single completion stream with in-band headers.
    //
    ofs_fim_pcie_hdr_merge
      #(
        // Simple buffers
        .PL_MODE_HDR_IN(1),
        .PL_MODE_DATA_IN(1)
        )
      hdr_merge
       (
        .hdr_stream_source(rx_stg2_hdr_if),
        .data_stream_source(rx_stg2_data_if),
        .stream_sink(o_rx_cpl_if)
        );


    // ====================================================================
    //
    //  TX path -- record original length of each DM read request.
    //  Requests pass through unchanged.
    //
    // ====================================================================

    //
    // Reads are accepted on both TX_A and TX_B. The tracking RAM
    // has only one write port. Arbitration logic here allows only one
    // read on either TX_A or TX_B per cycle. There is little value in
    // allowing both since the two streams will ultimately be merged into
    // a single TX stream inside the FIM or PCIe SS.
    //

    // Headers of incoming requests. TX-A is index 0, TX-B index 1, making
    // it possible to use loops below and pass request vectors to the arbiter.
    pcie_ss_hdr_pkg::PCIe_ReqHdr_t tx_out_hdr[2];
    pcie_ss_hdr_pkg::PCIe_ReqHdr_t tx_in_hdr[2];
    assign tx_in_hdr[0] = pcie_ss_hdr_pkg::PCIe_ReqHdr_t'(i_tx_a_if.tdata);
    assign tx_in_hdr[1] = pcie_ss_hdr_pkg::PCIe_ReqHdr_t'(i_tx_b_if.tdata);

    // Detect DM read requests on each stream
    logic tx_is_read[2];
    t_req_len_bytes tx_in_len_bytes[2];
    logic tx_sop[2];
    assign tx_is_read[0] = tx_sop[0] && i_tx_a_if.tvalid &&
                           pcie_ss_hdr_pkg::func_hdr_is_dm_mode(i_tx_a_if.tuser_vendor) &&
                           pcie_ss_hdr_pkg::func_is_mrd_req(tx_in_hdr[0].fmt_type);
    assign tx_is_read[1] = tx_sop[1] && i_tx_b_if.tvalid &&
                           pcie_ss_hdr_pkg::func_hdr_is_dm_mode(i_tx_b_if.tuser_vendor) &&
                           pcie_ss_hdr_pkg::func_is_mrd_req(tx_in_hdr[1].fmt_type);

    logic i_tx_fifo_full[2];
    logic tx_tready[2];
    assign tx_tready[0] = i_tx_a_if.tready;
    assign tx_tready[1] = i_tx_b_if.tready;

    assign i_tx_a_if.tready = o_tx_a_if.tready && !i_tx_fifo_full[0];
    assign o_tx_a_if.tvalid = i_tx_a_if.tvalid && !i_tx_fifo_full[0];
    assign i_tx_b_if.tready = o_tx_b_if.tready && !i_tx_fifo_full[1];
    assign o_tx_b_if.tvalid = i_tx_b_if.tvalid && !i_tx_fifo_full[1];

    t_req_len_bytes tx_in_orig_meta[2];

    always_comb
    begin
        // Save original read request lengths in metadata. It will be used
        // when merging completions and then restored to the original value.
        for (int c = 0; c < 2; c = c + 1) begin
            tx_in_len_bytes[c] = { tx_in_hdr[c].length_h, tx_in_hdr[c].length_m, tx_in_hdr[c].length_l };
            tx_out_hdr[c] = tx_in_hdr[c];
            if (METADATA_GROUP == "H") begin
                tx_out_hdr[c].metadata_h[$bits(t_req_len_bytes)-1 : 0] = tx_in_len_bytes[c];
                tx_in_orig_meta[c] = t_req_len_bytes'(tx_in_hdr[c].metadata_h);
            end
            else begin
                tx_out_hdr[c].metadata_l[$bits(t_req_len_bytes)-1 : 0] = tx_in_len_bytes[c];
                tx_in_orig_meta[c] = t_req_len_bytes'(tx_in_hdr[c].metadata_l);
            end
        end

        o_tx_a_if.tdata = i_tx_a_if.tdata;
        if (tx_is_read[0])
            o_tx_a_if.tdata[$bits(pcie_ss_hdr_pkg::PCIe_ReqHdr_t)-1 : 0] = tx_out_hdr[0];
        o_tx_a_if.tuser_vendor = i_tx_a_if.tuser_vendor;
        o_tx_a_if.tkeep = i_tx_a_if.tkeep;
        o_tx_a_if.tlast = i_tx_a_if.tlast;

        o_tx_b_if.tdata = i_tx_b_if.tdata;
        if (tx_is_read[1])
            o_tx_b_if.tdata[$bits(pcie_ss_hdr_pkg::PCIe_ReqHdr_t)-1 : 0] = tx_out_hdr[1];
        o_tx_b_if.tuser_vendor = i_tx_b_if.tuser_vendor;
        o_tx_b_if.tkeep = i_tx_b_if.tkeep;
        o_tx_b_if.tlast = i_tx_b_if.tlast;
    end

    // Track SOP
    always_ff @(posedge clk)
    begin
        if (i_tx_a_if.tvalid && i_tx_a_if.tready)
            tx_sop[0] <= i_tx_a_if.tlast;
        if (i_tx_b_if.tvalid && i_tx_b_if.tready)
            tx_sop[1] <= i_tx_b_if.tlast;

        if (!rst_n) begin
            tx_sop[0] <= 1'b1;
            tx_sop[1] <= 1'b1;
        end
    end


    logic [1:0] tx_arb_req;
    logic [1:0] tx_grant_1hot;

    //
    // FIFOs holding the incoming state to preserve, one per channel.
    //
    t_req_tag i_tx_fifo_tag[2];
    t_req_len_bytes i_tx_fifo_orig_meta[2];
    logic i_tx_fifo_valid[2];

    generate
        for (genvar c = 0; c < 2; c = c + 1) begin : in_fifo

            logic i_tx_fifo_empty;
            assign tx_arb_req[c] = !i_tx_fifo_empty;

            fim_scfifo
              #(
                .DATA_WIDTH($bits(t_req_tag) + $bits(t_req_len_bytes)),
                .DEPTH_LOG2(1)
                )
              i_tx_fifo
               (
                .clk,
                .sclr(!rst_n),

                .w_full(i_tx_fifo_full[c]),
                .w_data({ t_req_tag'({ tx_in_hdr[c].tag_h, tx_in_hdr[c].tag_m, tx_in_hdr[c].tag_l }),
                          tx_in_orig_meta[c] }),
                .w_req(tx_is_read[c] && tx_tready[c]),

                .r_empty(i_tx_fifo_empty),
                .r_req(tx_grant_1hot[c]),
                .r_data({ i_tx_fifo_tag[c], i_tx_fifo_orig_meta[c] }),
                .r_valid(i_tx_fifo_valid[c]),

                .w_usedw(),
                .r_usedw(),
                .w_ready()
                );

        end
    endgenerate

    // Pick a FIFO with data
    fair_arbiter
      #(
        .NUM_INPUTS(2)
        )
      tx_arb
       (
        .clk,
        .reset_n(rst_n),
        .in_valid(tx_arb_req),
        .hold_priority('0),
        .out_select(),
        .out_select_1hot(tx_grant_1hot),
        .out_valid()
        );

    //
    // When a DM header is found, store the request length indexed by tag in the
    // tracking RAM.
    //
    logic meta_ram_wr_en;
    t_req_tag meta_ram_waddr;
    t_req_len_bytes meta_ram_wdata;

    always_ff @(posedge clk)
    begin
        meta_ram_wr_en <= 1'b0;

        for (int c = 0; c < 2; c = c + 1) begin
            if (i_tx_fifo_valid[c]) begin
                meta_ram_wr_en <= 1'b1;
                meta_ram_waddr <= i_tx_fifo_tag[c];
                meta_ram_wdata <= i_tx_fifo_orig_meta[c];
            end
        end
    end

    ram_1r1w
      #(
        .GRAM_MODE(1),
        .DEPTH($bits(t_req_tag)),
        .WIDTH($bits(t_req_len_bytes))
        )
      meta_ram
       (
        .clk,

        .we(meta_ram_wr_en),
        
        .waddr(meta_ram_waddr),
        .din(meta_ram_wdata),

        .re(1'b1),
        .raddr(meta_ram_raddr),
        .dout(meta_ram_rdata),
        .perr()
        );


    // ====================================================================
    //
    //  Error checking
    //
    // ====================================================================

    logic [$bits(rx_cpl_hdr.tag)-1 : 0] cpl_tag_orig;
    logic [$bits(rx_cpl_hdr.tag)-1 : 0] cpl_tag_cur;
    logic error_cpl_out_of_order;
    logic error_not_cpl;

    always_ff @(posedge clk)
    begin
        // Block traffic on error
        if (BLOCK_ON_ERROR) begin
            error <= error_cpl_out_of_order || error_not_cpl;
        end

        if (!rst_n) begin
            error <= 1'b0;
        end
    end

    always_ff @(posedge clk)
    begin
        if (rx_cpl_hdr_if.tvalid && rx_cpl_hdr_if.tready) begin
            cpl_tag_cur <= rx_cpl_hdr.tag;

            // Check for a completion tag that doesn't match the one being
            // processed now.
            if (orig_packet_sop) begin
                cpl_tag_orig <= rx_cpl_hdr.tag;
            end
            else begin
                if (cpl_tag_orig != rx_cpl_hdr.tag) begin
                    error_cpl_out_of_order <= 1'b1;
                end
            end

            // Non-completion in the middle of a split completion response?
            if (!orig_packet_sop && !pcie_ss_hdr_pkg::func_is_completion(rx_cpl_hdr.fmt_type)) begin
                error_not_cpl <= 1'b1;
            end
        end

        if (!rst_n) begin
            error_cpl_out_of_order <= 1'b0;
            error_not_cpl <= 1'b0;
        end
    end


    // synthesis translate_off
    always_ff @(posedge clk)
    begin
        if (rst_n && error_not_cpl) begin
            $fatal(2, " ** ERROR ** %m: Non-completion in the middle of a split completion!");
        end

        if (rst_n && error_cpl_out_of_order) begin
            $fatal(2, " ** ERROR ** %m: Completions out of order: tag 0x%x and 0x%x overlap!",
                   cpl_tag_orig, cpl_tag_cur);
        end
    end
    // synthesis translate_on


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
        log_fd = $fopen($sformatf("log_dm_cpl_merge_%0d.tsv", INSTANCE_ID), "w");

        // Write module hierarchy to the top of the log
        $fwrite(log_fd, "ofs_fim_pcie_dm_cpl_merge.sv: %m\n\n");
    end

`define LOG_PCIE_STREAM(pcie_if, fmt) \
    logic pcie_if``_log_sop; \
    always_ff @(posedge clk) begin \
        if (rst_n && pcie_if.tvalid && pcie_if.tready) begin \
            $fwrite(log_fd, fmt, \
                    pcie_ss_pkg::func_pcie_ss_flit_to_string( \
                        pcie_if``_log_sop, pcie_if.tlast, \
                        pcie_ss_hdr_pkg::func_hdr_is_pu_mode(pcie_if.tuser_vendor), \
                        pcie_if.tdata, pcie_if.tkeep)); \
            $fflush(log_fd); \
        end \
        \
        if (pcie_if.tvalid && pcie_if.tready) \
            pcie_if``_log_sop <= pcie_if.tlast; \
        \
        if (!rst_n) \
            pcie_if``_log_sop <= 1'b1; \
    end

    `LOG_PCIE_STREAM(i_tx_a_if,   "i_tx_a:   %s\n")
    `LOG_PCIE_STREAM(i_rx_cpl_if, "i_rx_cpl: %s\n");
    `LOG_PCIE_STREAM(o_rx_cpl_if, "o_rx_cpl: %s\n");
    // synthesis translate_on

endmodule // ofs_fim_pcie_dm_cpl_merge

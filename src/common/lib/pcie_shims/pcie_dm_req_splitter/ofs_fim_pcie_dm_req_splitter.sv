// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT

//
// This is the top level module that should be instantiated to split DM
// encoded read and write requests into chunks no larger than REQ_MAX_BYTES.
//
// Read requests are accepted on both TX-A and TX-B, but it is inadvisable
// for an AFU to generate reads on both. Ordering guarantees for completions
// only hold when requests are sent on a single channel. If requests are
// split on TX-A and TX-B simultaneously, their completions are likely
// to be interleaved. If the AFU is also using ofs_fim_pcie_dm_cpl_merge()
// to recombine completions, the merge will fail and generate an invalid
// TLP stream.
//
// The FIM returns completions on a single stream. That RX stream must
// pass through the request splitter here in order to manage the final
// completion (FC) bit. FC will be set only on the final split completion
// packet. Other traffic on the RX completion stream is passed unmodified
// by the splitter.
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
// The same tag is used for each split request. The logic here assumes
// that the FIM's tag mapper will apply unique tags to each split request
// before they reach the PCIe SS. The FIM tag mapper does not require
// unique AFU-side tags.
//

module ofs_fim_pcie_dm_req_splitter
  #(
    // Maximum size of split requests, defaulting to the larger of 1024 and
    // MAX_RD_REQ_BYTES. MAX_RD_REQ_BYTES is the largest legal PU encoded
    // read. 1024, when DM encoded, will be split by the PCIe SS as needed
    // and is a good balance between size and header overhead on current
    // systems.
    parameter REQ_MAX_BYTES =
       (ofs_pcie_ss_cfg_pkg::MAX_RD_REQ_BYTES > 1024) ?
           ofs_pcie_ss_cfg_pkg::MAX_RD_REQ_BYTES : 1024,

    // For writes, the write commit message must be suppressed for all
    // but the final request. A bit in tuser_vendor is used. Setting it
    // to zero turns off the commit message.
    parameter TUSER_STORE_COMMIT_REQ_BIT = ofs_pcie_ss_cfg_pkg::TUSER_STORE_COMMIT_REQ_BIT,

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

    // All interfaces are in the same clock domain
    wire clk = o_tx_a_if.clk;
    wire rst_n = o_tx_a_if.rst_n;

    localparam TDATA_WIDTH = $bits(i_rx_cpl_if.tdata);
    localparam TUSER_WIDTH = $bits(i_rx_cpl_if.tuser_vendor);
    localparam TKEEP_WIDTH = TDATA_WIDTH/8;

    localparam DM_METADATA_BIT = 63;
    localparam DM_METADATA_SAFE_BIT = DM_METADATA_BIT & 31;

    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) tx_a_if(clk, rst_n);
    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) tx_b_if(clk, rst_n);

    // Tag indexed RAM for tracking original read metadata before split
    typedef logic [$clog2(ofs_pcie_ss_cfg_pkg::PCIE_TILE_MAX_TAGS)-1 : 0] t_req_tag;
    logic i_rx_meta_orig;

    //
    // TX-A supports both writes and reads. While reads may be sent
    // here, it is often a bad idea for AFUs that both read and
    // write simultaneously. Long streams can hold the bus here
    // and prevent PCIe traffic from being bidirectional.
    //
    // In addition, sending reads on both TX-A and TX-B is likely
    // to cause interleaved completions, even when completion
    // reordering is enabled, since the smaller split completions
    // have indeterminate relative order on the two channels.
    // Completion merging is not supported when responses come
    // back interleaved. Ensure that active reads are on only a single
    // channel when using completion merging.
    //
    ofs_fim_pcie_dm_tx_rdwr_req_splitter
      #(
        .REQ_MAX_BYTES(REQ_MAX_BYTES),
        .DM_METADATA_BIT(DM_METADATA_BIT),
        .TUSER_STORE_COMMIT_REQ_BIT(TUSER_STORE_COMMIT_REQ_BIT),

        .INSTANCE_ID(INSTANCE_ID),
        .PORT_NAME("A")
        )
      tx_a
       (
        .o_tx_if(o_tx_a_if),
        .i_tx_if(tx_a_if)
        );

    //
    // TX-B supports reads and interrupts, though sending an interrupt
    // often makes more sense on TX-A in order to synchronize it with
    // writes.
    //
    ofs_fim_pcie_dm_tx_req_splitter
      #(
        .REQ_MAX_BYTES(REQ_MAX_BYTES),
        .DM_METADATA_BIT(DM_METADATA_BIT),

        .INSTANCE_ID(INSTANCE_ID),
        .PORT_NAME("B")
        )
      tx_b
       (
        .o_tx_if(o_tx_b_if),
        .i_tx_if(tx_b_if)
        );

    //
    // Manage the completion response stream by turning off the FC bit
    // on all but the last split completion.
    //
    ofs_fim_pcie_dm_rx_rd_splitter
      #(
        .DM_METADATA_BIT(DM_METADATA_BIT)
        )
      rx
       (
        .i_rx_cpl_if,
        .i_rx_meta_orig,

        .o_rx_cpl_if
        );


    // ====================================================================
    //
    //  TX path -- preserve the metadata bit used to record the final
    //  completion. This is a lot of work to preserve a single bit, but
    //  the shim is supposed to be invisible.
    //
    // ====================================================================

    //
    // Reads are accepted on both TX_A and TX_B. The length tracking RAM
    // has only one write port. Arbitration logic here allows only one
    // read on either TX_A or TX_B per cycle. There is little value in
    // allowing both since the two streams will ultimately be merged into
    // a single TX stream inside the FIM or PCIe SS.
    //

    logic i_tx_fifo_full[2];

    assign i_tx_a_if.tready = tx_a_if.tready && !i_tx_fifo_full[0];
    assign tx_a_if.tvalid = i_tx_a_if.tvalid && !i_tx_fifo_full[0];
    assign i_tx_b_if.tready = tx_b_if.tready && !i_tx_fifo_full[1];
    assign tx_b_if.tvalid = i_tx_b_if.tvalid && !i_tx_fifo_full[1];

    assign tx_a_if.tdata = i_tx_a_if.tdata;
    assign tx_a_if.tuser_vendor = i_tx_a_if.tuser_vendor;
    assign tx_a_if.tkeep = i_tx_a_if.tkeep;
    assign tx_a_if.tlast = i_tx_a_if.tlast;

    assign tx_b_if.tdata = i_tx_b_if.tdata;
    assign tx_b_if.tuser_vendor = i_tx_b_if.tuser_vendor;
    assign tx_b_if.tkeep = i_tx_b_if.tkeep;
    assign tx_b_if.tlast = i_tx_b_if.tlast;

    // Track SOP
    logic [1:0] tx_sop;

    always_ff @(posedge clk)
    begin
        if (i_tx_a_if.tvalid && i_tx_a_if.tready)
            tx_sop[0] <= i_tx_a_if.tlast;
        if (i_tx_b_if.tvalid && i_tx_b_if.tready)
            tx_sop[1] <= i_tx_b_if.tlast;

        if (!rst_n)
            tx_sop <= 2'b11;
    end


    // Headers of incoming requests
    pcie_ss_hdr_pkg::PCIe_ReqHdr_t tx_in_hdr[2];
    assign tx_in_hdr[0] = pcie_ss_hdr_pkg::PCIe_ReqHdr_t'(i_tx_a_if.tdata);
    assign tx_in_hdr[1] = pcie_ss_hdr_pkg::PCIe_ReqHdr_t'(i_tx_b_if.tdata);

    logic [1:0] tx_is_read;
    logic [1:0] tx_arb_req;
    logic [1:0] tx_grant_1hot;

    // Detect DM read requests on each stream
    assign tx_is_read[0] = tx_sop[0] && i_tx_a_if.tvalid && i_tx_a_if.tready &&
                           pcie_ss_hdr_pkg::func_hdr_is_dm_mode(i_tx_a_if.tuser_vendor) &&
                           pcie_ss_hdr_pkg::func_is_mrd_req(tx_in_hdr[0].fmt_type);
    assign tx_is_read[1] = tx_sop[1] && i_tx_b_if.tvalid && i_tx_b_if.tready &&
                           pcie_ss_hdr_pkg::func_hdr_is_dm_mode(i_tx_b_if.tuser_vendor) &&
                           pcie_ss_hdr_pkg::func_is_mrd_req(tx_in_hdr[1].fmt_type);

    //
    // FIFOs holding the incoming state to preserve, one per channel.
    //
    t_req_tag i_tx_fifo_tag[2];
    logic i_tx_fifo_meta_bit[2];
    logic i_tx_fifo_valid[2];

    generate
        for (genvar c = 0; c < 2; c = c + 1) begin : in_fifo

            logic i_tx_fifo_empty;
            assign tx_arb_req[c] = !i_tx_fifo_empty;

            wire dm_meta_bit =
                ((DM_METADATA_BIT >= 32) ? tx_in_hdr[c].metadata_h[DM_METADATA_SAFE_BIT] :
                                           tx_in_hdr[c].metadata_l[DM_METADATA_SAFE_BIT]);

            fim_scfifo
              #(
                .DATA_WIDTH($bits(t_req_tag) + 1),
                .DEPTH_LOG2(1)
                )
              i_tx_fifo
               (
                .clk,
                .sclr(!rst_n),

                .w_full(i_tx_fifo_full[c]),
                .w_data({ t_req_tag'({ tx_in_hdr[c].tag_h, tx_in_hdr[c].tag_m, tx_in_hdr[c].tag_l }),
                          dm_meta_bit }),
                .w_req(tx_is_read[c]),

                .r_empty(i_tx_fifo_empty),
                .r_req(tx_grant_1hot[c]),
                .r_data({ i_tx_fifo_tag[c], i_tx_fifo_meta_bit[c] }),
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
    // When a DM header is found, store the original metadata indexed by tag in the
    // tracking RAM.
    //
    logic meta_ram_wr_en;
    t_req_tag meta_ram_waddr;
    logic meta_ram_wdata;

    always_ff @(posedge clk)
    begin
        meta_ram_wr_en <= 1'b0;

        for (int c = 0; c < 2; c = c + 1) begin : wram_sel
            if (i_tx_fifo_valid[c]) begin
                meta_ram_wr_en <= 1'b1;
                meta_ram_waddr <= i_tx_fifo_tag[c];
                meta_ram_wdata <= i_tx_fifo_meta_bit[c];
            end
        end
    end

    logic meta_ram[ofs_pcie_ss_cfg_pkg::PCIE_TILE_MAX_TAGS] /* synthesis ramstyle = "mlab", no_rw_check */;

    always_ff @(posedge clk)
    begin
        if (meta_ram_wr_en) begin
            meta_ram[meta_ram_waddr] <= meta_ram_wdata;
        end
    end

    // Read back the original metadata bit
    pcie_ss_hdr_pkg::PCIe_CplHdr_t i_rx_hdr;
    assign i_rx_hdr = pcie_ss_hdr_pkg::PCIe_CplHdr_t'(i_rx_cpl_if.tdata);
    wire t_req_tag meta_ram_raddr = t_req_tag'(i_rx_hdr.tag);
    assign i_rx_meta_orig = meta_ram[meta_ram_raddr];

endmodule // ofs_fim_pcie_dm_req_splitter

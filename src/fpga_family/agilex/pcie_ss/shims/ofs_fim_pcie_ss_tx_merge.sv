// Copyright (C) 2024 Intel Corporation.
// SPDX-License-Identifier: MIT

//
// Merge a pair of PCIe TLP streams into a single TX stream for the PCIe SS AXI-S.
//
// tuser fields should be encoded using ofs_fim_pcie_ss_shims_pkg::t_tuser_seg.
//

module ofs_fim_pcie_ss_tx_merge
  #(
    parameter TILE = "P-TILE",
    parameter PORT_ID = 0,
    parameter NUM_OF_SEG = 1,
    parameter NUM_OF_LINKS = 1
    )
   (
    // Data in axi_st_txreq_in is unused. txreq is header only (read requests).
    pcie_ss_axis_if.sink axi_st_txreq_in,
    pcie_ss_axis_if.sink axi_st_tx_in,

    pcie_ss_axis_if.source axi_st_tx_out
    );

    // R-Tile Gen4x16 uses half the Gen5x16 HIP. Just like the Gen5x16 4 segment
    // case, SOP isn't allowed on odd segments.
    localparam IS_R_TILE_GEN4x16 = (TILE == "R-TILE") &&
                                   (NUM_OF_SEG == 2) &&
                                   (NUM_OF_LINKS == 1);

    // Agilex 5 GTS ("SM") tile with NUM_OF_SEG=2 also restricts SOP to segment 0
    // when in-band headers are used. Force the simple arbitration path so that
    // each TLP is launched from segment 0 and the HIP can locate the in-band
    // header reliably (this is the workaround that fixes the MMIO read timeout).
    localparam IS_SM_NSEG2 = (TILE == "SM") && (NUM_OF_SEG == 2);

    // Pick an implementation from the two choices below
    if ((NUM_OF_SEG == 1) || IS_R_TILE_GEN4x16 || IS_SM_NSEG2) begin : arb
        // One segment -- simple arbitration
        ofs_fim_pcie_ss_tx_merge_arb merge
           (
            .axi_st_txreq_in,
            .axi_st_tx_in,
            .axi_st_tx_out
            );
    end else begin : seg
        // Multi-segment -- multiple headers per output cycle
        ofs_fim_pcie_ss_tx_merge_seg
          #(
            .TILE(TILE),
            .PORT_ID(PORT_ID),
            .NUM_OF_SEG(NUM_OF_SEG),
            .REGISTER_OUTPUT(1)
            )
          merge
           (
            .axi_st_txreq_in,
            .axi_st_tx_in,
            .axi_st_tx_out
            );
    end

endmodule // ofs_fim_pcie_ss_tx_merge


//
// Simple arbitration variant, used when NUM_OF_SEG is 1. Selecting either
// TX or TXREQ is sufficient.
//
module ofs_fim_pcie_ss_tx_merge_arb
   (
    // Data in axi_st_txreq_in is unused. txreq is header only (read requests).
    pcie_ss_axis_if.sink axi_st_txreq_in,
    pcie_ss_axis_if.sink axi_st_tx_in,

    pcie_ss_axis_if.source axi_st_tx_out
    );

    localparam TDATA_WIDTH = $bits(axi_st_tx_in.tdata);
    localparam TUSER_WIDTH = $bits(axi_st_tx_in.tuser_vendor);

    wire clk = axi_st_tx_out.clk;
    wire rst_n = axi_st_tx_out.rst_n;

    // Merge tx and txreq streams.
    pcie_ss_axis_if
      #(
        .DATA_W(TDATA_WIDTH),
        .USER_W(TUSER_WIDTH)
        )
      arb_tx_in[2](clk, rst_n);

    assign arb_tx_in[0].tvalid = axi_st_tx_in.tvalid;
    assign axi_st_tx_in.tready = arb_tx_in[0].tready;
    assign arb_tx_in[0].tdata = axi_st_tx_in.tdata;
    assign arb_tx_in[0].tkeep = axi_st_tx_in.tkeep;
    assign arb_tx_in[0].tlast = axi_st_tx_in.tlast;
    assign arb_tx_in[0].tuser_vendor = axi_st_tx_in.tuser_vendor;

    assign arb_tx_in[1].tvalid = axi_st_txreq_in.tvalid;
    assign axi_st_txreq_in.tready = arb_tx_in[1].tready;
    assign arb_tx_in[1].tdata = axi_st_txreq_in.tdata;
    assign arb_tx_in[1].tkeep = axi_st_txreq_in.tkeep;
    assign arb_tx_in[1].tlast = 1'b1;
    assign arb_tx_in[1].tuser_vendor = axi_st_txreq_in.tuser_vendor;

    pcie_ss_axis_mux
      #(
        .NUM_CH(2),
        .TDATA_WIDTH(TDATA_WIDTH),
        .TUSER_WIDTH(TUSER_WIDTH)
        )
      tx_txreq_arb
       (
        .clk(clk),
        .rst_n(rst_n),
        .sink(arb_tx_in),
        .source(axi_st_tx_out)
        );

endmodule // ofs_fim_pcie_ss_tx_merge_arb


//
// Segment-based TX/TXREQ merge for systems that support more than one header
// per cycle.
//
// The algorithm can generate up to 2 headers on the output stream, one in
// segment 0 and the other at NUM_OF_SEG/2.
//
module ofs_fim_pcie_ss_tx_merge_seg
  #(
    parameter TILE = "P-TILE",
    parameter PORT_ID = 0,
    parameter NUM_OF_SEG = 1,

    // Register output?
    parameter REGISTER_OUTPUT = 0
    )
   (
    // Data in axi_st_txreq_in is unused. txreq is header only (read requests).
    pcie_ss_axis_if.sink axi_st_txreq_in,
    pcie_ss_axis_if.sink axi_st_tx_in,

    pcie_ss_axis_if.source axi_st_tx_out
    );

    wire clk = axi_st_tx_out.clk;
    wire rst_n = axi_st_tx_out.rst_n;

    localparam TDATA_WIDTH = $bits(axi_st_tx_in.tdata);
    localparam TKEEP_WIDTH = TDATA_WIDTH / 8;
    localparam TUSER_WIDTH = $bits(axi_st_tx_in.tuser_vendor);

    // tdata, tkeep and tuser_vendor segments
    localparam TDATA_SEG_WIDTH = TDATA_WIDTH / NUM_OF_SEG;
    localparam TKEEP_SEG_WIDTH = TKEEP_WIDTH / NUM_OF_SEG;
    localparam TUSER_SEG_WIDTH = TUSER_WIDTH / NUM_OF_SEG;

    // synthesis translate_off
    initial
    begin : error_proc
        if (TUSER_SEG_WIDTH != $bits(ofs_fim_pcie_ss_shims_pkg::t_tuser_seg))
            $fatal(2, "** ERROR ** %m: TUSER must be of type ofs_fim_pcie_ss_shims_pkg::t_tuser_seg");
    end
    // synthesis translate_on

    pcie_ss_axis_if#(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) tx_out(clk, rst_n);

    typedef logic [NUM_OF_SEG-1:0][TDATA_SEG_WIDTH-1:0] t_seg_tdata;
    typedef logic [NUM_OF_SEG-1:0][TKEEP_SEG_WIDTH-1:0] t_seg_tkeep;
    typedef ofs_fim_pcie_ss_shims_pkg::t_tuser_seg [NUM_OF_SEG-1:0] t_seg_tuser;

    wire t_seg_tdata tx_in_tdata = axi_st_tx_in.tdata;
    wire t_seg_tkeep tx_in_tkeep = axi_st_tx_in.tkeep;
    wire t_seg_tuser tx_in_tuser = axi_st_tx_in.tuser_vendor;
    // Dense encoding of tx tuser last segment
    logic [NUM_OF_SEG-1:0] tx_in_tuser_last_segment;
    for (genvar s = 0; s < NUM_OF_SEG-1; s += 1)
        assign tx_in_tuser_last_segment[s] = tx_in_tuser[s].last_segment;

    wire t_seg_tdata txreq_in_tdata = axi_st_txreq_in.tdata;
    wire t_seg_tkeep txreq_in_tkeep = axi_st_txreq_in.tkeep;
    wire t_seg_tuser txreq_in_tuser = axi_st_txreq_in.tuser_vendor;


    // Registers holding the previous state from TX in case only part
    // of the request was transmitted. Segment 0 must already have been
    // forwarded, so start at 1.
    logic [NUM_OF_SEG/2-1:0][TDATA_SEG_WIDTH-1:0] tx_prev_tdata;
    logic [NUM_OF_SEG/2-1:0][TKEEP_SEG_WIDTH-1:0] tx_prev_tkeep;
    ofs_fim_pcie_ss_shims_pkg::t_tuser_seg [NUM_OF_SEG/2-1:0] tx_prev_tuser;
    logic tx_prev_tlast;
    logic tx_prev_tvalid;

    // Arbitration. Was previous request from txreq?
    logic prev_was_txreq;

    // Incoming segments will be picked from 3 possible locations: txreq,
    // tx and the tx_prev register. Tx_prev holds the remainder of an
    // incompletely forwarded tx from the previous cycle.
    typedef enum logic [1:0] {
        LOC_TXREQ = 0,
        LOC_TX = 1,
        LOC_TX_PREV = 2,
        LOC_NONE = 3
    } e_input_loc;

    // Scheduling choices this cycle
    e_input_loc slot0_input_loc;
    e_input_loc slot1_input_loc;
    logic picked_txreq;
    logic picked_tx;

    always_comb begin
        unique case ({ tx_prev_tvalid, axi_st_tx_in.tvalid, axi_st_txreq_in.tvalid })
            // TXREQ only
            3'b001: begin
                picked_tx = 1'b0;
                picked_txreq = 1'b1;
                slot0_input_loc = LOC_TXREQ;
                slot1_input_loc = LOC_NONE;
            end

            // TX only
            3'b010: begin
                picked_tx = 1'b1;
                picked_txreq = 1'b0;
                slot0_input_loc = LOC_TX;
                slot1_input_loc = LOC_NONE;
            end

            // TX + TXREQ
            3'b011: begin
                // Continuing previous TX or last packet was TXREQ?
                if (!tx_in_tuser[0].hvalid || prev_was_txreq) begin
                    picked_tx = 1'b1;
                    // Also pick txreq if the TX request fits in the first half
                    picked_txreq = |(tx_in_tuser_last_segment[(NUM_OF_SEG/2)-1 : 0]);
                    slot0_input_loc = LOC_TX;
                    slot1_input_loc = picked_txreq ? LOC_TXREQ : LOC_NONE;
                end else begin
                    picked_tx = 1'b1;
                    picked_txreq = 1'b1;
                    slot0_input_loc = LOC_TXREQ;
                    slot1_input_loc = LOC_TX;
                end
            end

            // TX_PREV only
            3'b100: begin
                picked_tx = 1'b0;
                picked_txreq = 1'b0;
                slot0_input_loc = LOC_TX_PREV;
                slot1_input_loc = LOC_NONE;
            end

            // TX_PREV + TXREQ
            3'b101: begin
                // Since packets on TX are guaranteed to be delivered densely,
                // with no empty cycles, we can infer that the TX_PREV ends
                // a packet. There is room in the second slot for TXREQ.
                picked_tx = 1'b0;
                picked_txreq = 1'b1;
                slot0_input_loc = LOC_TX_PREV;
                slot1_input_loc = LOC_TXREQ;
            end

            // TX_PREV + TX
            3'b110: begin
                picked_tx = 1'b1;
                picked_txreq = 1'b0;
                slot0_input_loc = LOC_TX_PREV;
                slot1_input_loc = LOC_TX;
            end

            // TX_PREV + TX + TXREQ
            3'b111: begin
                // Favor TXREQ unless TX continues a packet
                picked_tx = ~tx_prev_tlast;
                picked_txreq = tx_prev_tlast;
                slot0_input_loc = LOC_TX_PREV;
                slot1_input_loc = tx_prev_tlast ? LOC_TXREQ : LOC_TX;
            end

            default: begin
                picked_tx = 1'b0;
                picked_txreq = 1'b0;
                slot0_input_loc = LOC_NONE;
                slot1_input_loc = LOC_NONE;
            end
        endcase
    end

    assign axi_st_txreq_in.tready = tx_out.tready && picked_txreq;
    assign axi_st_tx_in.tready = tx_out.tready && picked_tx;
    assign tx_out.tvalid = tx_prev_tvalid || axi_st_tx_in.tvalid || axi_st_txreq_in.tvalid;
    assign tx_out.tlast =
        picked_txreq ||
        (tx_prev_tvalid && tx_prev_tlast) ||
        ((slot0_input_loc == LOC_TX) && axi_st_tx_in.tlast) ||
        ((slot1_input_loc == LOC_TX) && |(tx_in_tuser_last_segment[(NUM_OF_SEG/2)-1 : 0]));

    //
    // Record the high half of TX in case it is needed next cycle
    //
    always_ff @(posedge clk) begin
        if (tx_out.tready) begin
            tx_prev_tvalid <= 1'b0;
        end

        if (axi_st_tx_in.tvalid && axi_st_tx_in.tready) begin
            tx_prev_tlast <= axi_st_tx_in.tlast;
            tx_prev_tdata <= tx_in_tdata[NUM_OF_SEG-1 : NUM_OF_SEG/2];
            tx_prev_tkeep <= tx_in_tkeep[NUM_OF_SEG-1 : NUM_OF_SEG/2];
            tx_prev_tuser <= tx_in_tuser[NUM_OF_SEG-1 : NUM_OF_SEG/2];
            tx_prev_tvalid <= (slot1_input_loc == LOC_TX) &&
                              ~|(tx_in_tuser_last_segment[(NUM_OF_SEG/2)-1 : 0]);
        end

        if (!rst_n) begin
            tx_prev_tvalid <= 1'b0;
            tx_prev_tlast <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (tx_out.tvalid && tx_out.tready) begin
            prev_was_txreq <= ((slot0_input_loc == LOC_TXREQ) && (slot0_input_loc == LOC_NONE)) ||
                              (slot1_input_loc == LOC_TXREQ);
        end

        if (!rst_n) begin
            prev_was_txreq <= 1'b0;
        end
    end


    //
    // Map inputs to output based on the scheduling choices above
    //
    t_seg_tdata tx_out_tdata;
    t_seg_tkeep tx_out_tkeep;
    t_seg_tuser tx_out_tuser;

    always_comb begin
        unique case (slot0_input_loc)
            LOC_TXREQ: begin
                // There is only one TXREQ input
                tx_out_tdata[0] = txreq_in_tdata[0];
                tx_out_tkeep[0] = txreq_in_tkeep[0];
                tx_out_tuser[0] = txreq_in_tuser[0];
                for (int i = 1; i < NUM_OF_SEG; i += 1) begin
                    tx_out_tdata[i] = '0;
                    tx_out_tkeep[i] = '0;
                    tx_out_tuser[i] = '0;
                end
            end
            LOC_TX_PREV: begin
                for (int i = 0; i < NUM_OF_SEG/2; i += 1) begin
                    tx_out_tdata[i] = tx_prev_tdata[i];
                    tx_out_tkeep[i] = tx_prev_tkeep[i];
                    tx_out_tuser[i] = tx_prev_tuser[i];
                end
                for (int i = NUM_OF_SEG/2; i < NUM_OF_SEG; i += 1) begin
                    tx_out_tdata[i] = '0;
                    tx_out_tkeep[i] = '0;
                    tx_out_tuser[i] = '0;
                end
            end
            default: begin
                // This is LOC_TX, used instead of setting the fields to zero to
                // simplify the MUX. The valid bit will be off if the location
                // is LOC_NONE.
                for (int i = 0; i < NUM_OF_SEG; i += 1) begin
                    tx_out_tdata[i] = tx_in_tdata[i];
                    tx_out_tkeep[i] = tx_in_tkeep[i];
                    tx_out_tuser[i] = tx_in_tuser[i];
                end
            end
        endcase // unique case (slot0_input_loc)

        unique case (slot1_input_loc)
            LOC_TXREQ: begin
                // There is only one TXREQ input
                tx_out_tdata[NUM_OF_SEG/2] = txreq_in_tdata[0];
                tx_out_tkeep[NUM_OF_SEG/2] = txreq_in_tkeep[0];
                tx_out_tuser[NUM_OF_SEG/2] = txreq_in_tuser[0];
                // Any segments beyond NUM_OF_SEG/2 have already been cleared
                // by the slot0_input_loc case.
            end
            LOC_TX: begin
                for (int i = 0; i < NUM_OF_SEG/2; i += 1) begin
                    tx_out_tdata[i + NUM_OF_SEG/2] = tx_in_tdata[i];
                    tx_out_tkeep[i + NUM_OF_SEG/2] = tx_in_tkeep[i];
                    tx_out_tuser[i + NUM_OF_SEG/2] = tx_in_tuser[i];
                end
            end
            default: begin
                // No action. slot1_input_loc will never by LOC_TX_PREV and
                // unused segments in tx_out have already been cleared
                // by the slot0_input_loc case.
            end
        endcase // unique case (slot1_input_loc)
    end

    assign tx_out.tdata = tx_out_tdata;
    assign tx_out.tkeep = tx_out_tkeep;
    assign tx_out.tuser_vendor = tx_out_tuser;

    if (REGISTER_OUTPUT) begin : out
        assign tx_out.tready = axi_st_tx_out.tready || !axi_st_tx_out.tvalid;

        always_ff @(posedge clk) begin
            if (axi_st_tx_out.tready) begin
                axi_st_tx_out.tvalid <= 1'b0;
            end

            if (tx_out.tvalid && tx_out.tready) begin
                axi_st_tx_out.tvalid <= 1'b1;
                axi_st_tx_out.tdata <= tx_out.tdata;
                axi_st_tx_out.tkeep <= tx_out.tkeep;
                axi_st_tx_out.tuser_vendor <= tx_out.tuser_vendor;
                axi_st_tx_out.tlast <= tx_out.tlast;
            end

            if (!rst_n) begin
                axi_st_tx_out.tvalid <= 1'b0;
            end
        end
    end else begin : out
        assign tx_out.tready = axi_st_tx_out.tready;
        assign axi_st_tx_out.tvalid = tx_out.tvalid;
        assign axi_st_tx_out.tdata = tx_out.tdata;
        assign axi_st_tx_out.tkeep = tx_out.tkeep;
        assign axi_st_tx_out.tuser_vendor = tx_out.tuser_vendor;
        assign axi_st_tx_out.tlast = tx_out.tlast;
    end

endmodule // ofs_fim_pcie_ss_tx_merge

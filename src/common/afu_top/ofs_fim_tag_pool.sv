// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT


//
// Manage a space of unique IDs for tagging transactions.
//

`include "vendor_defines.vh"

module ofs_fim_tag_pool
  #(
    parameter N_ENTRIES = 32,
    // Number of low entries to reserve that will never be allocated
    parameter N_RESERVED = 0
    )
   (
    input  logic clk,
    input  logic rst_n,

    // PCIe configuration (available tags)
    input  pcie_ss_axis_pkg::t_pcie_tag_mode tag_mode,

    // Allocate an entry. Ignored when !alloc_ready.
    input  logic alloc,
    // Is an entry available?
    output logic alloc_ready,
    // Assigned UID -- valid as long as notFull is set
    output logic [$clog2(N_ENTRIES)-1 : 0] alloc_uid,

    // Release a UID
    input  logic free,
    input  logic [$clog2(N_ENTRIES)-1 : 0] free_uid
    );

    typedef logic [$clog2(N_ENTRIES)-1 : 0] t_uid;

    logic need_uid;

    //
    // Tracking memory. A bit is 1 when busy and 0 when available. We need
    // only one write port, allowing a UID to either be allocated or freed
    // in a cycle but not both. The case where both happen in the same
    // cycle is handled specially to avoid the conflict: the freed UID
    // is reused for the allocation.
    //

    logic test_ram_rdy;
    t_uid test_uid;
    logic test_uid_busy;

    logic wen;
    t_uid waddr, waddr_init;
    logic wdata;

    ram_1r1w
      #(
        .DEPTH($clog2(N_ENTRIES)),
        .WIDTH(1),
        .GRAM_MODE(0),
        .GRAM_STYLE(`GRAM_DIST)
        )
      tracker
       (
        .clk,

        .we(wen || !test_ram_rdy),
        .waddr(test_ram_rdy ? waddr : waddr_init),
        .din(test_ram_rdy ? wdata : '0),

        .re(1'b1),
        .raddr(test_uid),
        .dout(test_uid_busy),
        .perr()
        );

    // Initialize the RAM
    always_ff @(posedge clk)
    begin
        if (!test_ram_rdy)
        begin
            waddr_init <= waddr_init + t_uid'(1);
            test_ram_rdy <= &(waddr_init);
        end

        if (!rst_n)
        begin
            test_ram_rdy <= 1'b0;
            waddr_init <= 0;
        end
    end


    //
    // Inbound freed UIDs
    //
    logic free_q;
    t_uid free_uid_q;

    always_ff @(posedge clk)
    begin
        free_q <= free;
        free_uid_q <= free_uid;
    end;


    //
    // Loop through the tracker memory looking for a free UID.
    // When a free UID is found the tracker waits for it to be needed
    // and then resumes the search.
    //
    always_ff @(posedge clk)
    begin
        // Move to the next entry if the current entry is busy or was
        // allocated this cycle.
        if (test_uid_busy || (need_uid && !free_q))
        begin
            test_uid <= test_uid + t_uid'(1);

            // Time to wrap back to the beginning? Detect both the need
            // to wrap in the whole static space and dynamically, when
            // PCIe is set to a limited space.
            if ((test_uid == t_uid'(N_ENTRIES-1)) ||
                (tag_mode.tag_5bit && &(5'(test_uid))) ||
                (tag_mode.tag_8bit && &(8'(test_uid))))
            begin
                test_uid <= N_RESERVED;
            end
        end

        if (!rst_n || !test_ram_rdy)
        begin
            test_uid <= N_RESERVED;
        end
    end


    //
    // Update the tracker
    //
    always_comb
    begin
        if (need_uid && free_q)
        begin
            // Allocate and free on the same cycle. The freed UID will be
            // reused instead of updating the tracker.
            wen = 1'b0;
            waddr = 'x;
            wdata = 'x;
        end
        else if (free_q)
        begin
            // Release free_uid_q. No allocation.
            wen = 1'b1;
            waddr = free_uid_q;
            wdata = 1'b0;
        end
        else
        begin
            // Maybe an allocation.
            wen = need_uid && test_ram_rdy;
            waddr = test_uid;
            wdata = 1'b1;
        end
    end


    //
    // Push allocated UIDs to an outbound FIFO. The client will consume
    // UIDs from the FIFO.
    //
    logic fifo_full;
    assign need_uid = !fifo_full;

    fim_rdack_scfifo
      #(
        .DATA_WIDTH($bits(t_uid)),
        .DEPTH_LOG2(2)
        )
      out_fifo
       (
        .clk,
        .sclr(!rst_n),

        // When a new UID is needed, pick either the one being freed this
        // cycle (if available) or a new one (if available).
        .wdata(free_q ? free_uid_q : test_uid),
        .wreq(need_uid && test_ram_rdy && (free_q || !test_uid_busy)),
        .wfull(fifo_full),
        .almfull(),
        .wusedw(),

        .rdata(alloc_uid),
        .rdack(alloc && alloc_ready),
        .rvalid(alloc_ready),
        .rempty(),
        .rusedw()
        );

endmodule // ofs_fim_tag_pool

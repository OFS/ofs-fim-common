// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT


//
// Generate a stream of atomic updates to the source buffer. The
// atomic operation is set by the test CSRs. Read responses from
// the atomic updates are streamed to the destination buffer.
//
// The read pipeline can also be configured to generate read
// requests. Responses from these reads are dropped on the floor.
// The intent is to test the underlying logic that is managing
// both normal read requests and responses from atomic updates
// that return as both write commits and read responses.
//

module mode_atomic
   (
    input  logic clk,
    input  logic rst_n,

    // Start will go high for a single cycle. The pulse is decoded by
    // the parent and will fire only when the test is enabled.
    input  logic start,
    output logic done,

    input  he_lb_pkg::he_csr2eng csr2eng,

    ofs_plat_axi_mem_if.to_sink axi_host_mem
    );

    // Reset is controlled by a CSR
    logic test_rst_n = 1'b0;
    always @(posedge clk)
    begin
        test_rst_n <= rst_n && csr2eng.ctl.rst_n;
    end

    // AXI-MM addresses are byte-based
    localparam ADDR_LINE_IDX_WIDTH = axi_host_mem.ADDR_LINE_IDX_WIDTH;
    localparam ADDR_BYTE_OFFSET_WIDTH = axi_host_mem.ADDR_WIDTH - ADDR_LINE_IDX_WIDTH;
    localparam ID_WIDTH = axi_host_mem.RID_WIDTH;
    localparam DATA_WIDTH = axi_host_mem.DATA_WIDTH;


    // ====================================================================
    //
    //  Memory read requests. These are normal reads, not atomic responses.
    //
    // ====================================================================

    logic rd_not_done, rd_rsp_not_done;
    logic [31:0] num_rd_req_rem;
    // 1-based burst length (not the AXI 0-based count)
    logic [he_lb_pkg::REQ_LEN_W-1 : 0] rd_burst_len;
    logic [ADDR_LINE_IDX_WIDTH-1 : 0] rd_address_base;
    logic [he_lb_pkg::TOTAL_LEN_W-1 : 0] rd_line_offset;
    // Drop two bits from the ID when counting. Bit 0 of the ID will be used
    // as a flag indicating the final read and bit 1 to mark atomics.
    logic [ID_WIDTH-3 : 0] rd_id;

    // Stop if commanded to stop or not in continuous mode and target
    // number of requests has been emitted.
    wire rd_is_last = csr2eng.ctl.stop ||
                      (!csr2eng.cfg.cont_mode && (num_rd_req_rem == 0));

    always_ff @(posedge clk)
    begin
        if (start && csr2eng.cfg.test_mode[0])
        begin
            // Starting a new test that emits read requests. Get all the parameters.
            rd_not_done <= 1'b1;
            rd_rsp_not_done <= 1'b1;
            rd_burst_len <= 1 << csr2eng.cfg.req_len_log2;
            num_rd_req_rem <= csr2eng.num_lines >> csr2eng.cfg.req_len_log2;
            rd_address_base <= csr2eng.src_address;
            rd_line_offset <= '0;
            rd_id <= '0;
        end

        if (rd_not_done && axi_host_mem.arvalid && axi_host_mem.arready)
        begin
            // A read request was generated. Update counters. Wrap at
            // num_lines even in continuous mode.
            if (num_rd_req_rem == 0)
            begin
                rd_line_offset <= '0;
                num_rd_req_rem <= csr2eng.num_lines >> csr2eng.cfg.req_len_log2;
            end
            else
            begin
                rd_line_offset <= rd_line_offset + rd_burst_len;
                num_rd_req_rem <= num_rd_req_rem - 1;
            end
            rd_id <= rd_id + 1;

            if (rd_is_last)
            begin
                rd_not_done <= 1'b0;
            end
        end

        // Bit 0 of the RID is set only on the final request
        if (axi_host_mem.r.id[0] && !axi_host_mem.r.id[1] && axi_host_mem.r.last &&
            axi_host_mem.rvalid && axi_host_mem.rready)
        begin
            rd_rsp_not_done <= 1'b0;
        end

        if (!test_rst_n)
        begin
            rd_not_done <= 1'b0;
            rd_rsp_not_done <= 1'b0;
        end
    end

    // Request a single read burst
    always_comb
    begin
        axi_host_mem.arvalid = rd_not_done;
        axi_host_mem.ar = '0;

        // Read address range contrained to the buffer size. The size of
        // rd_line_offset is expected to match the buffer.
        axi_host_mem.ar.addr = { (rd_address_base + rd_line_offset), ADDR_BYTE_OFFSET_WIDTH'(0) };
        axi_host_mem.ar.len = rd_burst_len - 1;
        axi_host_mem.ar.size = axi_host_mem.ADDR_BYTE_IDX_WIDTH;

        // Indicate final read in bit 0 of the RID. The rest gets a counter,
        // though the RID doesn't really matter. AXI doesn't require that
        // they be unique and the reads will be returned in request order,
        // either by the PIM or the PCIe SS.
        //
        // Bit 1 of ID will be used by the atomic code below to detect
        // atomic responses.
        axi_host_mem.ar.id = { rd_id, 1'b0, rd_is_last };
    end


    // ====================================================================
    //
    //  Atomic requests
    //
    // ====================================================================

    //
    // For the logic here, names with "atomic" in them are managing
    // the atomic update stream to the AW/W pipeline.
    //
    // Names with just "write" are managing normal writes to the AW/W
    // pipeline. These writes are generated as loopbacks from the
    // read responses triggered by the atomic updates.
    //

    logic wr_not_done;
    logic atomic_not_done;
    logic atomic_req_enq;
    logic normal_wr_enq;

    logic [31:0] num_atomic_req_rem;
    logic [ADDR_LINE_IDX_WIDTH-1 : 0] wr_address_base;
    logic [he_lb_pkg::TOTAL_LEN_W-1 : 0] atomic_line_offset;
    logic [he_lb_pkg::TOTAL_LEN_W-1 : 0] wr_line_offset;
    // Drop two bits from the ID when counting. Bit 0 of the ID will be used
    // as a flag indicating the final read and bit 1 to mark atomics.
    logic [ID_WIDTH-3 : 0] atomic_id;

    // Atomic test configuration
    logic [ADDR_LINE_IDX_WIDTH-1 : 0] atomic_address_base;
    logic atomic_64bit_op;
    ofs_plat_axi_mem_pkg::t_axi_atomic atomic_op;
    logic atomic_op_is_cas;

    // Stop if commanded to stop or not in continuous mode and target
    // number of requests has been emitted.
    wire atomic_is_last = csr2eng.ctl.stop ||
                          (!csr2eng.cfg.cont_mode && (num_atomic_req_rem == 0));

    always_ff @(posedge clk)
    begin
        if (start && (csr2eng.cfg.test_mode[1:0] != 2'b1))
        begin
            // Starting a new test. Get all the parameters.
            atomic_not_done <= 1'b1;
            wr_not_done <= 1'b1;
            num_atomic_req_rem <= csr2eng.num_lines >> csr2eng.cfg.req_len_log2;

            atomic_address_base <= csr2eng.src_address;
            atomic_64bit_op <= csr2eng.cfg.atomic_size;
            atomic_op_is_cas <= 1'b0;
            if (csr2eng.cfg.atomic_func[1:0] == 2'h0)
                atomic_op <= ofs_plat_axi_mem_pkg::ATOMIC_ADD;
            else if (csr2eng.cfg.atomic_func[1:0] == 2'h1)
                atomic_op <= ofs_plat_axi_mem_pkg::ATOMIC_SWAP;
            else
            begin
                atomic_op <= ofs_plat_axi_mem_pkg::ATOMIC_CAS;
                atomic_op_is_cas <= 1'b1;
            end

            wr_address_base <= csr2eng.dst_address;
            atomic_line_offset <= '0;
            atomic_id <= '0;
            wr_line_offset <= '0;
        end

        // Atomic request emitted?
        if (atomic_not_done && atomic_req_enq)
        begin
            // Wrap at num_lines even in continuous mode.
            if (num_atomic_req_rem == 0)
            begin
                atomic_line_offset <= '0;
                num_atomic_req_rem <= csr2eng.num_lines >> csr2eng.cfg.req_len_log2;
            end
            else
            begin
                atomic_line_offset <= atomic_line_offset + 1;
                num_atomic_req_rem <= num_atomic_req_rem - 1;
            end
            atomic_id <= atomic_id + 1;

            if (atomic_is_last)
            begin
                atomic_not_done <= 1'b0;
            end
        end

        // Normal write emitted?
        if (normal_wr_enq)
        begin
            wr_line_offset <= wr_line_offset + 1;
        end

        // Writes are done once the response for the last write has been
        // received. Bit 0 of the ID indicates the final response, since
        // it was set only on the final request. Bit 1 indicates a normal
        // write (not an atomic one).
        if (axi_host_mem.bvalid && axi_host_mem.bready &&
            axi_host_mem.b.id[0] && !axi_host_mem.b.id[1])
        begin
            wr_not_done <= 1'b0;
        end

        // Continuous mode doesn't emit normal writes. End on the last
        // response from an atomic update.
        if (csr2eng.cfg.cont_mode &&
            axi_host_mem.rvalid && axi_host_mem.rready &&
            axi_host_mem.r.id[0] && axi_host_mem.b.id[1])
        begin
            wr_not_done <= 1'b0;
        end

        if (!test_rst_n)
        begin
            atomic_not_done <= 1'b0;
            wr_not_done <= 1'b0;
        end
    end

    // Encoding of an atomic ID. Low bit indicates end of test. Bit 1
    // indicates an atomic operation. Non-atomic writes have bit 1 clear.
    wire [ID_WIDTH-1 : 0] atomic_aw_id = { atomic_id, 1'b1, atomic_is_last };


    //
    // Break write requests into two FIFOs, one for the AW stream and the
    // other for the W stream. All requests for this test have bursts that
    // are a single data beat, so managing the FIFOs is relatively easy.
    //

    logic aw_full;
    logic w_full;

    // Differentiate between normal read responses from the read engine
    // at the top (ID bit 1 is 0) and atomic responses (ID bit 1 is 1).
    // Don't write back read responses in continuous mode. Having unlimited
    // atomic requests outstanding along with a feedback path from read
    // response to write can lead to deadlocks. We could solve it with
    // a large buffer on the read response path, but that would take more
    // aread for this test with little gain.
    wire rd_rsp_is_atomic = axi_host_mem.rvalid && axi_host_mem.r.id[1] &&
                            !csr2eng.cfg.cont_mode;


    // Arbitration between atomic requests and normal writes. Both share the
    // write request pipeline. Read responses from atomic updates are forwarded
    // back to the write stream. The source buffer gets the atomic updates
    // and the destination buffers gets the data returned by the atomic updates.
    //
    // Normal writes are given static priority since they are later in the
    // atomic write -> atomic response -> write data to destination buffer
    // pipeline.
    assign atomic_req_enq = !aw_full && !w_full && atomic_not_done && !rd_rsp_is_atomic;
    assign normal_wr_enq = !aw_full && !w_full && rd_rsp_is_atomic;
    assign axi_host_mem.rready = normal_wr_enq || !rd_rsp_is_atomic;

    // Generate the AW and W payloads, either for a new atomic request or a
    // normal write.
    logic [he_lb_pkg::TOTAL_LEN_W + ID_WIDTH - 1 : 0] aw_in;
    logic [1 + 64 - 1 : 0] w_in;
    always_comb
    begin
        if (rd_rsp_is_atomic)
        begin
            // Normal write from atomic response
            aw_in = { wr_line_offset, axi_host_mem.r.id };
            // Clear atomic op flag in ID to indicate normal write
            aw_in[1] = 1'b0;

            w_in = { 1'b0, axi_host_mem.r.data[63:0] };
        end
        else
        begin
            // New atomic request
            aw_in = { atomic_line_offset, atomic_aw_id };
            w_in = { 1'b1, 64'(atomic_line_offset) };
        end
    end

    logic [he_lb_pkg::TOTAL_LEN_W-1 : 0] aw_line_offset;
    logic [ID_WIDTH-1 : 0] aw_id;

    fim_rdack_scfifo
      #(
        .DATA_WIDTH(he_lb_pkg::TOTAL_LEN_W + ID_WIDTH),
        .DEPTH_LOG2(2)
        )
      atomic_aw_fifo
       (
        .clk,
        .sclr(!test_rst_n),

        .wdata(aw_in),
        .wreq(atomic_req_enq || normal_wr_enq),
        .wfull(aw_full),
        .almfull(),
        .wusedw(),

        .rdata({ aw_line_offset, aw_id }),
        .rdack(axi_host_mem.awvalid && axi_host_mem.awready),
        .rvalid(axi_host_mem.awvalid),
        .rempty(),
        .rusedw()
        );

    logic w_data_for_atomic;
    logic [63:0] w_data;

    fim_rdack_scfifo
      #(
        .DATA_WIDTH(1 + 64),
        .DEPTH_LOG2(2)
        )
      atomic_w_fifo
       (
        .clk,
        .sclr(!test_rst_n),

        .wdata(w_in),
        .wreq(atomic_req_enq || normal_wr_enq),
        .wfull(w_full),
        .almfull(),
        .wusedw(),

        .rdata({ w_data_for_atomic, w_data }),
        .rdack(axi_host_mem.wvalid && axi_host_mem.wready),
        .rvalid(axi_host_mem.wvalid),
        .rempty(),
        .rusedw()
        );


    // Byte offset within a single line of data
    typedef logic [$clog2(he_lb_pkg::DW/8)-1 : 0] t_addr_byte_offset;

    //
    // Compare and swap operand order depends on the position on the bus. AXI
    // expects the full payload to be naturally aligned for the size, which is
    // 2x the size of the returned value. The order of the compare operand and
    // the swap operand depends on the address being updated. The compare
    // operand is always at the spot on the bus corresponding to the address.
    // 
    function automatic logic atomicCASCompareIsLast(
        input t_addr_byte_offset addr,
        input logic mode_64bit
        );

        return mode_64bit ? addr[3] : addr[2];
    endfunction // atomicCASCompareIsLast

    //
    // Given a byte-level address, generate a write data mask that enables
    // a single naturally aligned 32, 64 or 128 bit value. Only CAS can use
    // 128 bits: one for the compare and one for the swap.
    //
    localparam BYTE_MASK_WIDTH = axi_host_mem.DATA_N_BYTES;

    function automatic logic [BYTE_MASK_WIDTH-1 : 0] maskFromByteAddr(
        input t_addr_byte_offset addr,
        input logic mode_64bit,
        input logic is_cas
        );

        logic [BYTE_MASK_WIDTH-1 : 0] mask;
        unique case ({ mode_64bit, is_cas })
          { 1'b0, 1'b0 }: mask = BYTE_MASK_WIDTH'('hf)    << (4 * addr[$clog2(BYTE_MASK_WIDTH)-1:2]);
          { 1'b0, 1'b1 }: mask = BYTE_MASK_WIDTH'('hff)   << (8 * addr[$clog2(BYTE_MASK_WIDTH)-1:3]);
          { 1'b1, 1'b0 }: mask = BYTE_MASK_WIDTH'('hff)   << (8 * addr[$clog2(BYTE_MASK_WIDTH)-1:3]);
          default:        mask = BYTE_MASK_WIDTH'('hffff) << (16 * addr[$clog2(BYTE_MASK_WIDTH)-1:4]);
        endcase

        return mask;
    endfunction // maskFromByteAddr


    // Write addresses
    always_comb
    begin
        axi_host_mem.aw = '0;

        // Atomic write or just a normal write? Atomic writes have bit 1 set in the ID.
        if (aw_id[1])
        begin
            axi_host_mem.aw.addr = { (atomic_address_base + aw_line_offset), ADDR_BYTE_OFFSET_WIDTH'(0) };
            axi_host_mem.aw.atop = atomic_op;

            // The size is the full payload. For CAS, both compare and swap.
            if (atomic_op_is_cas)
                axi_host_mem.aw.size = atomic_64bit_op ? 3'b100 : 3'b011;
            else
                axi_host_mem.aw.size = atomic_64bit_op ? 3'b011 : 3'b010;

            // The AXI5 standard says that burst for atomics should generally
            // be INCR (2'b01) except for CAS when the compare value follows the
            // swap value. The PIM ignores this.
            //
            // The function is used here only to show how it might be used in
            // a real design. The test here uses only addresses at the start of
            // a line, so the low bits of the address are always 0 and the burst
            // is always the same.
            axi_host_mem.aw.burst =
                (atomic_op_is_cas && atomicCASCompareIsLast(0, atomic_64bit_op)) ? 2'b10 : 2'b01;
        end
        else
        begin
            axi_host_mem.aw.addr = { (wr_address_base + aw_line_offset), ADDR_BYTE_OFFSET_WIDTH'(0) };
            axi_host_mem.aw.size = atomic_64bit_op ? 3'b011 : 3'b010;
        end

        axi_host_mem.aw.id = aw_id;
    end

    always_comb
    begin
        axi_host_mem.w = '0;
        axi_host_mem.w.last = 1'b1;

        if (w_data_for_atomic)
        begin
            // Atomic update. The payload is the address line offset. For CAS, the
            // swap value is the inverse of the address line offset. We set both
            // values unconditionally but the higher one will be used only for CAS.
            if (atomic_64bit_op)
                axi_host_mem.w.data = { '0, ~w_data, w_data };
            else
                axi_host_mem.w.data = { '0, ~w_data[31:0], w_data[31:0] };

            // Like the use of atomicCASCompareIsLast() above, this function isn't
            // technically necessary within this limited test. The address byte offset
            // used is always 0, making the mask calculation simple. The funciton is
            // included here to show the general mask generation algorithm.
            axi_host_mem.w.strb = maskFromByteAddr(0, atomic_64bit_op, atomic_op_is_cas);
        end
        else
        begin
            // Normal write -- store the read response from an earlier atomic
            // operation to the destination buffer.
            axi_host_mem.w.data = { '0, w_data };
            axi_host_mem.w.strb = atomic_64bit_op ? { '0, 8'hff } : { '0, 4'hf };
        end
    end

    assign axi_host_mem.bready = 1'b1;

    //
    // Engine is done after all traffic has committed.
    //
    logic enable_done_out;
    assign done = enable_done_out && !rd_rsp_not_done && !wr_not_done;

    always_ff @(posedge clk)
    begin
        if (start)
        begin
            enable_done_out <= 1'b1;
        end

        if (!test_rst_n)
        begin
            enable_done_out <= 1'b0;
        end
    end

endmodule

// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT


//
// Implement a loopback from one host memory buffer to another. Since
// the AXI-MM interface has back pressure, read responses flow directly
// to the write stream.
//
// When EMIF is enabled, data travels in two steps: from host to EMIF
// and then EMIF to host.
//

module mode_lpbk
  #(
    parameter EMIF = 0
    )
   (
    input  logic clk,
    input  logic rst_n,

    // Start will go high for a single cycle. The pulse is decoded by
    // the parent and will fire only when the test is enabled.
    input  logic start,
    output logic done,

    input  he_lb_pkg::he_csr2eng csr2eng,

    // AXI-MM interface to host memory
    ofs_plat_axi_mem_if.to_sink axi_host_mem,

    // Interface to local RAM (e.g. DDR on the FPGA card)
    ofs_plat_axi_mem_if.to_sink emif_if
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

    // Maximum burst length of a read or write request
    logic [$clog2(he_lb_pkg::MAX_REQ_LEN)-1 : 0] req_len_log2;
    assign req_len_log2 =
        $bits(req_len_log2)'({ csr2eng.cfg.req_len_log2_high, csr2eng.cfg.req_len_log2 });


    // ====================================================================
    //
    //  Host memory read requests
    //
    // ====================================================================

    logic rd_not_done;
    logic enable_done_out;
    logic [31:0] num_rd_req_rem;
    // 1-based burst length (not the AXI 0-based count)
    logic [he_lb_pkg::REQ_LEN_W-1 : 0] rd_burst_len;
    logic [ADDR_LINE_IDX_WIDTH-1 : 0] rd_address_base;
    logic [he_lb_pkg::TOTAL_LEN_W-1 : 0] rd_line_offset;
    // Drop one bit from the ID when counting. Bit 0 of the ID will be used
    // as a flag indicating the final read.
    logic [ID_WIDTH-2 : 0] rd_id;

    // This test AFU is unusual: read responses are directed
    // directly to the write stream. Since the physical PCIe interface
    // shares the same bus for reads and writes, it is possible to
    // deadlock if the number of read requests in flight exceeds the
    // buffer capacity. We could add a block RAM buffer here between
    // reads and writes to increase throughput, but that would waste
    // area on a test. Instead, we limit the number of outstanding
    // requests. PCIe throughput tests should be run with mode_rdwr
    // anyway, so lpbk test throughput isn't a huge concern. The
    // host_excerciser --testall throughput tests use mode_rdwr.
    localparam RD_MAX_ACTIVE_LINES = 256;
    localparam RD_MAX_ACTIVE_TEST_BIT = $clog2(RD_MAX_ACTIVE_LINES);
    logic [RD_MAX_ACTIVE_TEST_BIT:0] num_rd_active_lines;
    wire rd_too_many_active = num_rd_active_lines[RD_MAX_ACTIVE_TEST_BIT];

    // Stop if commanded to stop or not in continuous mode and target
    // number of requests has been emitted.
    wire rd_is_last = csr2eng.ctl.stop ||
                      (!csr2eng.cfg.cont_mode && (num_rd_req_rem == 0));

    wire axi_host_mem_rd_sent = axi_host_mem.arvalid && axi_host_mem.arready;
    wire axi_host_mem_rd_rcvd = axi_host_mem.rvalid && axi_host_mem.rready;

    always_ff @(posedge clk)
    begin
        if (start)
        begin
            // Starting a new test. Get all the parameters.
            rd_not_done <= 1'b1;
            enable_done_out <= 1'b1;
            rd_burst_len <= 1 << req_len_log2;
            num_rd_req_rem <= csr2eng.num_lines >> req_len_log2;
            rd_address_base <= csr2eng.src_address;
            rd_line_offset <= '0;
            rd_id <= '0;
        end

        if (rd_not_done && axi_host_mem_rd_sent)
        begin
            // A read request was generated. Update counters. Wrap at
            // num_lines even in continuous mode.
            if (num_rd_req_rem == 0)
            begin
                rd_line_offset <= '0;
                num_rd_req_rem <= csr2eng.num_lines >> req_len_log2;
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

        if (!test_rst_n)
        begin
            rd_not_done <= 1'b0;
            enable_done_out <= 1'b0;
        end
    end

    // Request a single read burst
    always_comb
    begin
        axi_host_mem.arvalid = rd_not_done && !rd_too_many_active;
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
        axi_host_mem.ar.id = { rd_id, rd_is_last };
    end

    // Count read lines in flight
    always_ff @(posedge clk)
    begin
        // If idle or a read is sent and received this cycle, the counter stays
        // the same. Otherwise, increment or decrement the count.
        if (axi_host_mem_rd_sent != (axi_host_mem_rd_rcvd && axi_host_mem.r.last))
        begin
            if (axi_host_mem_rd_sent)
                num_rd_active_lines <= num_rd_active_lines + rd_burst_len;
            else
                num_rd_active_lines <= num_rd_active_lines - rd_burst_len;
        end

        if (!rst_n)
        begin
            num_rd_active_lines <= '0;
        end
    end

    //
    // Track read response SOP
    //
    logic rd_rsp_sop;

    always_ff @(posedge clk)
    begin
        if (axi_host_mem_rd_rcvd)
        begin
            rd_rsp_sop <= axi_host_mem.r.last;
        end

        if (!test_rst_n)
        begin
            rd_rsp_sop <= 1'b1;
        end
    end


    // Push read response IDs into a skid buffer. These will become write
    // address requests.
    logic [ID_WIDTH-1: 0] rd_rsp_id;
    logic rd_rsp_id_valid;
    logic rd_rsp_id_deq;
    logic rd_id_fifo_full;

    // Map incoming read data to symbols. No skid buffer is needed since the
    // parent already added one.
    logic rd_data_ready;
    wire [DATA_WIDTH-1: 0] rd_rsp_data = axi_host_mem.r.data;
    wire rd_rsp_data_eop = axi_host_mem.r.last;
    // Bit 0 of the RID is set only on the final request
    wire rd_rsp_data_final = axi_host_mem.r.id[0];
    wire rd_rsp_data_valid = axi_host_mem.rvalid && !rd_id_fifo_full;

    assign axi_host_mem.rready = !rd_id_fifo_full && rd_data_ready;

    // Skid buffer holding only read response IDs. This stream will feed into
    // the write address channel.
    fim_rdack_scfifo
      #(
        .DATA_WIDTH(ID_WIDTH),
        .DEPTH_LOG2(2)
        )
      rd_id_fifo
       (
        .clk,
        .sclr(!test_rst_n),

        .wdata(axi_host_mem.r.id),
        .wreq(axi_host_mem.rvalid && axi_host_mem.rready && rd_rsp_sop),
        .wfull(rd_id_fifo_full),
        .almfull(),
        .wusedw(),

        .rdata(rd_rsp_id),
        .rdack(rd_rsp_id_deq),
        .rvalid(rd_rsp_id_valid),
        .rempty(),
        .rusedw()
        );


    // ====================================================================
    //
    //  Optional FIFO through external memory
    //
    // ====================================================================

    logic [ID_WIDTH-1: 0] wr_in_id;
    logic wr_in_id_valid;
    logic wr_in_id_deq;

    logic [DATA_WIDTH-1: 0] wr_in_data;
    logic wr_in_data_eop;
    logic wr_in_data_final;
    logic wr_in_data_valid;

    generate
        if (EMIF == 0)
        begin : emif_tie
            // No EMIF. Host memory reads feed directly to host memory writes.
            assign wr_in_id = rd_rsp_id;
            assign wr_in_id_valid = rd_rsp_id_valid;
            assign rd_rsp_id_deq = wr_in_id_deq;
            assign rd_data_ready = axi_host_mem.wready;
            assign wr_in_data = rd_rsp_data;
            assign wr_in_data_eop = rd_rsp_data_eop;
            assign wr_in_data_final = rd_rsp_data_final;
            assign wr_in_data_valid = rd_rsp_data_valid;

            // Tie off unused EMIF
            assign emif_if.awvalid   = 1'b0;
            assign emif_if.wvalid    = 1'b0;
            assign emif_if.bready    = 1'b1;
            assign emif_if.arvalid   = 1'b0;
            assign emif_if.rready    = 1'b1;

            assign emif_if.ar        = '0;
            assign emif_if.aw        = '0;
            assign emif_if.w         = '0;
        end
        else
        begin : emif_fifo
            //
            // If you are not using EMIF or not interested in the EMIF FIFO,
            // you can skip reading this block. Since emif_if is the same
            // interface type as host memory, the code here looks very much
            // like the code above for reading from host memory and the code
            // at the bottom for writing to host memory.
            //
            // This block treats EMIF as a FIFO. When data arrives as
            // host memory read responses it is written to EMIF here.
            // When the EMIF store commit is received on the B channel,
            // a read from EMIF is generated. The read response then feeds
            // the host memory writes at the bottom of the file.
            //
            // There is no need to manage end of data here. The bit 0 flag
            // on IDs that is used to indicate the last value passes
            // through the EMIF AW/B and AR/R interfaces unchanged and is
            // eventually consumed by the host memory write logic.
            //

            localparam EMIF_LINE_IDX_WIDTH = emif_if.ADDR_LINE_IDX_WIDTH;

            logic [he_lb_pkg::REQ_LEN_W-1 : 0] emif_burst_len;
            logic [EMIF_LINE_IDX_WIDTH-1 : 0] emif_wr_line_offset;
            logic [EMIF_LINE_IDX_WIDTH-1 : 0] emif_rd_line_offset;
            logic [ID_WIDTH-2 : 0] emif_rd_id;

            always_ff @(posedge clk)
            begin
                if (start)
                begin
                    // Starting a new test. Get all the parameters.
                    emif_burst_len <= 1 << req_len_log2;
                    emif_wr_line_offset <= '0;
                    emif_rd_line_offset <= '0;
                    emif_rd_id <= '0;
                end

                if (emif_if.awvalid && emif_if.awready)
                begin
                    // An EMIF write request was generated. Update counters.
                    emif_wr_line_offset <= emif_wr_line_offset + emif_burst_len;
                end

                if (emif_if.arvalid && emif_if.arready)
                begin
                    // An EMIF read request was generated. Update counters.
                    emif_rd_line_offset <= emif_rd_line_offset + emif_burst_len;
                    emif_rd_id <= emif_rd_id + 1;
                end
            end

            // Trigger EMIF write address requests from SOP of host read responses.
            // Since the write bursts will be the same size as the reads, there is an
            // AW request for every read response SOP.
            always_comb
            begin
                rd_rsp_id_deq = rd_rsp_id_valid && emif_if.awready;
                emif_if.awvalid = rd_rsp_id_valid;
                emif_if.aw = '0;

                // Read address range contrained to the buffer size. The size of
                // wr_line_offset is expected to match the buffer.
                emif_if.aw.addr = { emif_wr_line_offset, ADDR_BYTE_OFFSET_WIDTH'(0) };
                emif_if.aw.len = emif_burst_len - 1;
                emif_if.aw.size = emif_if.ADDR_BYTE_IDX_WIDTH;
                // WID doesn't really matter. Match the AW and AR IDs.
                emif_if.aw.id = rd_rsp_id;
            end

            // EMIF write data comes directly from the host read data stream.
            always_comb
            begin
                rd_data_ready = emif_if.wready;
                emif_if.wvalid = rd_rsp_data_valid;
                emif_if.w = '0;

                emif_if.w.data = rd_rsp_data;
                emif_if.w.last = rd_rsp_data_eop;
                emif_if.w.strb = ~('0);
            end


            //
            // Count write commits. Feeding EMIF write commits directly to EMIF
            // reads can cause deadlocks due to back-pressure on the B channel.
            // The counter here breaks the dependence by always allowing write
            // commits.
            //
            logic [15:0] emif_wr_rsp_counter;
            logic emif_wr_rsp_final_arrived;
            wire emif_wr_rsp_incr = emif_if.bvalid && emif_if.bready;
            wire emif_wr_rsp_decr = emif_if.arvalid && emif_if.arready;
            wire emif_wr_rsp_is_final = emif_wr_rsp_final_arrived && (emif_wr_rsp_counter == 1);
            assign emif_if.bready = 1'b1;

            always_ff @(posedge clk)
            begin
                case ({ emif_wr_rsp_incr, emif_wr_rsp_decr })
                    2'b00: emif_wr_rsp_counter <= emif_wr_rsp_counter;
                    2'b01: emif_wr_rsp_counter <= emif_wr_rsp_counter - 1;
                    2'b10: emif_wr_rsp_counter <= emif_wr_rsp_counter + 1;
                    2'b11: emif_wr_rsp_counter <= emif_wr_rsp_counter;
                endcase

                if (emif_if.bvalid && emif_if.bready)
                begin
                    emif_wr_rsp_final_arrived <= emif_if.b.id[0];
                end

                if (!test_rst_n)
                begin
                    emif_wr_rsp_counter <= '0;
                    emif_wr_rsp_final_arrived <= 1'b0;
                end
            end


            //
            // For every write commit, generate a read to retrieve the value
            // just written to EMIF.
            //
            always_comb
            begin
                emif_if.arvalid = (emif_wr_rsp_counter != 0);
                emif_if.ar = '0;

                // Read address range contrained to the buffer size. The size of
                // rd_line_offset is expected to match the buffer.
                emif_if.ar.addr = { emif_rd_line_offset, ADDR_BYTE_OFFSET_WIDTH'(0) };
                emif_if.ar.len = emif_burst_len - 1;
                emif_if.ar.size = emif_if.ADDR_BYTE_IDX_WIDTH;
                emif_if.ar.id = { emif_rd_id, emif_wr_rsp_is_final };
            end

            // Track read response SOP
            logic emif_rd_rsp_sop;

            always_ff @(posedge clk)
            begin
                if (emif_if.rvalid && emif_if.rready)
                begin
                    emif_rd_rsp_sop <= emif_if.r.last;
                end

                if (!test_rst_n)
                begin
                    emif_rd_rsp_sop <= 1'b1;
                end
            end


            logic emif_rd_id_fifo_full;
            assign wr_in_data = emif_if.r.data;
            assign wr_in_data_eop = emif_if.r.last;
            // Bit 0 of the RID is set only on the final request
            assign wr_in_data_final = emif_if.r.id[0];
            assign wr_in_data_valid = emif_if.rvalid && !emif_rd_id_fifo_full;

            assign emif_if.rready = !emif_rd_id_fifo_full && axi_host_mem.wready;

            // Skid buffer holding only EMIF read response IDs. This stream will feed into
            // the write address channel.
            fim_rdack_scfifo
              #(
                .DATA_WIDTH(ID_WIDTH),
                .DEPTH_LOG2(2)
                )
              emif_rd_id_fifo
               (
                .clk,
                .sclr(!test_rst_n),

                .wdata(emif_if.r.id),
                .wreq(emif_if.rvalid && emif_if.rready && emif_rd_rsp_sop),
                .wfull(emif_rd_id_fifo_full),
                .almfull(),
                .wusedw(),

                .rdata(wr_in_id),
                .rdack(wr_in_id_deq),
                .rvalid(wr_in_id_valid),
                .rempty(),
                .rusedw()
                );
        end
    endgenerate


    // ====================================================================
    //
    //  Host memory write requests
    //
    // ====================================================================

    //
    // Host memory writes are fed either directly from the host memory
    // reads or, when EMIF is enabled, from EMIF read responses.
    // The generate block above picks the data source, setting the
    // wr_in_* wires.
    //

    logic wr_addr_not_done, wr_data_not_done;
    logic wr_not_done;
    logic [31:0] num_wr_req_rem;

    // 1-based burst length (not the AXI 0-based count)
    logic [he_lb_pkg::REQ_LEN_W-1 : 0] wr_burst_len;
    logic [ADDR_LINE_IDX_WIDTH-1 : 0] wr_address_base;
    logic [he_lb_pkg::TOTAL_LEN_W-1 : 0] wr_line_offset;
    logic wr_data_is_last;

    always_ff @(posedge clk)
    begin
        if (start)
        begin
            // Starting a new test. Get all the parameters.
            wr_addr_not_done <= 1'b1;
            wr_data_not_done <= 1'b1;
            wr_not_done <= 1'b1;
            wr_burst_len <= 1 << req_len_log2;
            num_wr_req_rem <= csr2eng.num_lines >> req_len_log2;
            wr_address_base <= csr2eng.dst_address;
            wr_line_offset <= '0;
        end

        if (wr_addr_not_done && axi_host_mem.awvalid && axi_host_mem.awready)
        begin
            // A write request was generated. Update counters. Wrap at
            // num_lines even in continuous mode.
            if (num_wr_req_rem == 0)
            begin
                wr_line_offset <= '0;
                num_wr_req_rem <= csr2eng.num_lines >> req_len_log2;
            end
            else
            begin
                wr_line_offset <= wr_line_offset + wr_burst_len;
                num_wr_req_rem <= num_wr_req_rem - 1;
            end

            // Bit 0 of the ID is set only on the final write request.
            // It carries over from the same bit 0 flag on the read stream.
            if (axi_host_mem.aw.id[0])
            begin
                wr_addr_not_done <= 1'b0;
            end
        end

        if (wr_data_is_last && axi_host_mem.wvalid && axi_host_mem.wready)
        begin
            wr_data_not_done <= 1'b0;
        end

        // Writes are done once the response for the last write has been
        // received. Bit 0 of the ID indicates the final response, since
        // it was set only on the final request.
        if (axi_host_mem.bvalid && axi_host_mem.bready && axi_host_mem.b.id[0])
        begin
            wr_not_done <= 1'b0;
        end

        if (!test_rst_n)
        begin
            wr_addr_not_done <= 1'b0;
            wr_data_not_done <= 1'b0;
            wr_not_done <= 1'b0;
        end
    end

    // Trigger write address requests from SOP of read responses. Since the
    // write bursts will be the same size as the reads, there is an AW request
    // for every read response SOP.
    always_comb
    begin
        wr_in_id_deq = wr_in_id_valid && axi_host_mem.awready;
        axi_host_mem.awvalid = wr_in_id_valid;
        axi_host_mem.aw = '0;

        // Read address range contrained to the buffer size. The size of
        // wr_line_offset is expected to match the buffer.
        axi_host_mem.aw.addr = { (wr_address_base + wr_line_offset), ADDR_BYTE_OFFSET_WIDTH'(0) };
        axi_host_mem.aw.len = wr_burst_len - 1;
        axi_host_mem.aw.size = axi_host_mem.ADDR_BYTE_IDX_WIDTH;
        // WID doesn't really matter. Match the AW and AR IDs.
        axi_host_mem.aw.id = wr_in_id;
    end

    // Write data comes directly from the read data stream.
    always_comb
    begin
        axi_host_mem.wvalid = wr_in_data_valid;
        axi_host_mem.w = '0;

        axi_host_mem.w.data = wr_in_data;
        axi_host_mem.w.last = wr_in_data_eop;
        axi_host_mem.w.strb = ~('0);

        wr_data_is_last = wr_in_data_final && wr_in_data_eop;
    end

    assign axi_host_mem.bready = 1'b1;

    //
    // Engine is done after all traffic has committed.
    //
    assign done = enable_done_out && !rd_not_done && !wr_not_done;

endmodule

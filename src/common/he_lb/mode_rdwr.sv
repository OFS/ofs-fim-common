// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT


//
// Generate just reads, just writes or independent streams
// of reads and writes. This mode is intended mainly for
// benchmarking.
//
// The incoming configuration sets the burst length and base
// addresses of the source and destination buffers.
//
// In continuous mode, requests wrap around the buffers.
//
// After signaling done the parent will handle whatever
// protocol is requiring to tell the host that the test
// is complete.
//

module mode_rdwr
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

    // AXI-MM interface. Note that this variant names the interface
    // just "axi_mem" and not "axi_host_mem". This is because no
    // assumptions are made about the underlying memory. No
    // special requests such as atomics are emitted.
    //
    // This test can be used with host memory and with EMIF.
    ofs_plat_axi_mem_if.to_sink axi_mem
    );

    // Reset is controlled by a CSR
    logic test_rst_n = 1'b0;
    always @(posedge clk)
    begin
        test_rst_n <= rst_n && csr2eng.ctl.rst_n;
    end

    // AXI-MM addresses are byte-based
    localparam ADDR_LINE_IDX_WIDTH = axi_mem.ADDR_LINE_IDX_WIDTH;
    localparam ADDR_BYTE_OFFSET_WIDTH = axi_mem.ADDR_WIDTH - ADDR_LINE_IDX_WIDTH;
    localparam ID_WIDTH = axi_mem.RID_WIDTH;
    localparam DATA_WIDTH = axi_mem.DATA_WIDTH;

    // csr2eng.num_lines is the total number of lines to read and write.
    // In throughput mode, divide it in half.
    wire [31:0] num_lines = &(csr2eng.cfg.test_mode[1:0]) ? (csr2eng.num_lines >> 1) :
                                                            csr2eng.num_lines;

    // ====================================================================
    //
    //  Memory read requests.
    //
    // ====================================================================

    logic rd_not_done, rd_rsp_not_done;
    logic [31:0] num_rd_req_rem;
    // 1-based burst length (not the AXI 0-based count)
    logic [he_lb_pkg::REQ_LEN_W-1 : 0] rd_burst_len;
    logic [ADDR_LINE_IDX_WIDTH-1 : 0] rd_address_base;
    logic [he_lb_pkg::TOTAL_LEN_W-1 : 0] rd_line_offset;
    // Drop one bit from the ID when counting. Bit 0 of the ID will be used
    // as a flag indicating the final read.
    logic [ID_WIDTH-2 : 0] rd_id;

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
            num_rd_req_rem <= num_lines >> csr2eng.cfg.req_len_log2;

            rd_address_base <= csr2eng.src_address;
            if (EMIF)
            begin
                // Use a fixed address for EMIF
                rd_address_base <= '0;
            end

            rd_line_offset <= '0;
            rd_id <= '0;
        end

        if (rd_not_done && axi_mem.arvalid && axi_mem.arready)
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
        if (axi_mem.r.id[0] && axi_mem.r.last &&
            axi_mem.rvalid && axi_mem.rready)
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
        axi_mem.arvalid = rd_not_done;
        axi_mem.ar = '0;

        // Read address range contrained to the buffer size. The size of
        // rd_line_offset is expected to match the buffer.
        axi_mem.ar.addr = { (rd_address_base + rd_line_offset), ADDR_BYTE_OFFSET_WIDTH'(0) };
        axi_mem.ar.len = rd_burst_len - 1;
        axi_mem.ar.size = axi_mem.ADDR_BYTE_IDX_WIDTH;

        // Indicate final read in bit 0 of the RID. The rest gets a counter,
        // though the RID doesn't really matter. AXI doesn't require that
        // they be unique and the reads will be returned in request order,
        // either by the PIM or the PCIe SS.
        axi_mem.ar.id = { rd_id, rd_is_last };
    end

    assign axi_mem.rready = 1'b1;


    // ====================================================================
    //
    //  Memory write requests.
    //
    // ====================================================================

    logic wr_addr_not_done;
    logic wr_not_done;
    logic [31:0] num_wr_req_rem;

    // 1-based burst length (not the AXI 0-based count)
    logic [he_lb_pkg::REQ_LEN_W-1 : 0] wr_burst_len;
    logic [he_lb_pkg::REQ_LEN_W-1 : 0] wr_data_last_beat_num;
    logic [ADDR_LINE_IDX_WIDTH-1 : 0] wr_address_base;
    logic [he_lb_pkg::TOTAL_LEN_W-1 : 0] wr_line_offset;
    // Drop one bit from the ID when counting. Bit 0 of the ID will be used
    // as a flag indicating the final read.
    logic [ID_WIDTH-2 : 0] wr_id;

    // Stop if commanded to stop or not in continuous mode and target
    // number of requests has been emitted.
    wire wr_is_last = csr2eng.ctl.stop ||
                      (!csr2eng.cfg.cont_mode && (num_wr_req_rem == 0));

    always_ff @(posedge clk)
    begin
        if (start && csr2eng.cfg.test_mode[1])
        begin
            // Starting a new test. Get all the parameters.
            wr_addr_not_done <= 1'b1;
            wr_not_done <= 1'b1;
            wr_burst_len <= 1 << csr2eng.cfg.req_len_log2;
            wr_data_last_beat_num <= (1 << csr2eng.cfg.req_len_log2) - 1;
            num_wr_req_rem <= num_lines >> csr2eng.cfg.req_len_log2;

            wr_address_base <= csr2eng.dst_address;
            if (EMIF)
            begin
                // Use a fixed address for EMIF
                wr_address_base <= 0;
                wr_address_base[ADDR_LINE_IDX_WIDTH-1] <= 1'b1;
            end

            wr_line_offset <= '0;
            wr_id <= '0;
        end

        if (wr_addr_not_done && axi_mem.awvalid && axi_mem.awready)
        begin
            // A write request was generated. Update counters. Wrap at
            // num_lines even in continuous mode.
            if (num_wr_req_rem == 0)
            begin
                wr_line_offset <= '0;
                num_wr_req_rem <= num_lines >> csr2eng.cfg.req_len_log2;
            end
            else
            begin
                wr_line_offset <= wr_line_offset + wr_burst_len;
                num_wr_req_rem <= num_wr_req_rem - 1;
            end
            wr_id <= wr_id + 1;

            // Bit 0 of the ID is set only on the final write request.
            // It carries over from the same bit 0 flag on the read stream.
            if (axi_mem.aw.id[0])
            begin
                wr_addr_not_done <= 1'b0;
            end
        end

        // Writes are done once the response for the last write has been
        // received. Bit 0 of the ID indicates the final response, since
        // it was set only on the final request.
        if (axi_mem.bvalid && axi_mem.bready && axi_mem.b.id[0])
        begin
            wr_not_done <= 1'b0;
        end

        if (!test_rst_n)
        begin
            wr_addr_not_done <= 1'b0;
            wr_not_done <= 1'b0;
        end
    end

    // Track the number of write data lines that must be emitted given the
    // number of addresses sent. When the high bit is set, new address requests
    // will block so that the counter doesn't overflow.
    localparam WDATA_CNT_WIDTH = he_lb_pkg::REQ_LEN_W + 2;
    logic [WDATA_CNT_WIDTH-1 : 0] pending_wdata_cnt;
    wire pending_wdata_cnt_full = pending_wdata_cnt[WDATA_CNT_WIDTH-1];

    // Write addresses
    always_comb
    begin
        axi_mem.awvalid = wr_addr_not_done && !pending_wdata_cnt_full;
        axi_mem.aw = '0;

        // Read address range contrained to the buffer size. The size of
        // wr_line_offset is expected to match the buffer.
        axi_mem.aw.addr = { (wr_address_base + wr_line_offset), ADDR_BYTE_OFFSET_WIDTH'(0) };
        axi_mem.aw.len = wr_burst_len - 1;
        axi_mem.aw.size = axi_mem.ADDR_BYTE_IDX_WIDTH;
        axi_mem.aw.id = { wr_id, wr_is_last };
    end

    // Data stream
    logic [he_lb_pkg::REQ_LEN_W-1 : 0] wr_this_pkt_beat_cnt;
    wire wr_data_eop = (wr_this_pkt_beat_cnt == wr_data_last_beat_num);

    always_ff @(posedge clk)
    begin
        // Track pending data beats
        pending_wdata_cnt <=
            pending_wdata_cnt
            // New AW, requiring more data?
            + ((axi_mem.awvalid && axi_mem.awready) ? wr_burst_len : 0)
            // Send a data beat?
            - ((axi_mem.wvalid && axi_mem.wready) ? 1 : 0);

        if (axi_mem.wvalid && axi_mem.wready)
        begin
            // Track EOP of the current packet
            if (wr_data_eop)
                wr_this_pkt_beat_cnt <= 0;
            else
                wr_this_pkt_beat_cnt <= wr_this_pkt_beat_cnt + 1;
        end

        if (!test_rst_n)
        begin
            pending_wdata_cnt <= '0;
            wr_this_pkt_beat_cnt <= '0;
        end
    end

    always_comb
    begin
        axi_mem.wvalid = (pending_wdata_cnt != 0) || (axi_mem.awvalid && axi_mem.awready);
        axi_mem.w = '0;

        axi_mem.w.data = { '0, {4{32'hfeedf00d}}, 32'(wr_this_pkt_beat_cnt) };
        axi_mem.w.last = wr_data_eop;
        axi_mem.w.strb = ~('0);
    end

    assign axi_mem.bready = 1'b1;

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

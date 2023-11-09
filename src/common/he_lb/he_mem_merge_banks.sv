// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT


//
// Combine multiple memory interfaces into a single interface with
// a unified address space.
//
// All banks must have the same properties, except for address width.
// They must also use the same clock. For HE MEM, the parent module
// ensures these are true.
//

`include "ofs_plat_if.vh"

module he_mem_merge_banks
  #(
    parameter NUM_MEM_BANKS = 1
    )
   (
    ofs_plat_axi_mem_if.to_sink mem_sinks[NUM_MEM_BANKS],
    ofs_plat_axi_mem_if.to_source mem_source
    );

    wire clk = mem_source.clk;
    wire rst_n = mem_source.reset_n;

    localparam BANK_ADDR_WIDTH = mem_sinks[0].ADDR_WIDTH;
    localparam SOURCE_ADDR_WIDTH = mem_source.ADDR_WIDTH;

    // synthesis translate_off
    initial
    begin : error_proc
        if (NUM_MEM_BANKS != (2 ** $clog2(NUM_MEM_BANKS)))
            $fatal(2, "** ERROR ** %m: NUM_MEM_BANKS (%0d) must be a power of 2!", NUM_MEM_BANKS);
    end
    // synthesis translate_on

    typedef logic [$clog2(NUM_MEM_BANKS)-1 : 0] t_bank_idx;
    // Address within a bank
    typedef logic [BANK_ADDR_WIDTH-1 : 0] t_bank_addr;
    // Global address
    typedef logic [SOURCE_ADDR_WIDTH-1 : 0] t_source_addr;

    // Map banks to 8KB windows. If windows are too small, throughput suffers.
    function automatic t_bank_idx addr_to_bank_idx(t_source_addr s_addr);
        return s_addr[$clog2(8192) +: $clog2(NUM_MEM_BANKS)];
    endfunction

    // Drop the bank index from the address sent to each bank.
    function automatic t_bank_addr addr_to_bank_addr(t_source_addr s_addr);
        return { s_addr[SOURCE_ADDR_WIDTH-1 : $clog2(8192)+$clog2(NUM_MEM_BANKS)],
                 s_addr[$clog2(8192)-1 : 0] };
    endfunction


    // Track write stream SOP
    logic w_is_sop;
    always_ff @(posedge clk)
    begin
        if (mem_source.wvalid && mem_source.wready) begin
            w_is_sop <= mem_source.w.last;
        end

        if (!rst_n) begin
            w_is_sop <= 1'b1;
        end
    end

    // Hold the selected bank for the write stream. AW and the SOP of W are
    // always processed together, enforced by the ready/enable logic below.
    t_bank_idx w_cur_bank_idx;
    always_ff @(posedge clk)
    begin
        if (mem_source.awvalid && mem_source.awready) begin
            w_cur_bank_idx <= addr_to_bank_idx(mem_source.aw.addr);
        end

        if (!rst_n) begin
            w_cur_bank_idx <= '0;
        end
    end


    //
    // Track the bank from which the next write commit is expected. Responses
    // are returned on mem_source in order.
    //
    logic wr_rsp_bank_fifo_full;
    logic wr_rsp_bank_fifo_valid;
    t_bank_idx wr_rsp_bank_idx;

    fim_rdack_scfifo
      #(
        .DATA_WIDTH($bits(t_bank_idx)),
        .DEPTH_LOG2(9),
        .USE_EAB("ON")
        )
      wr_rsp_bank_fifo
       (
        .clk,
        .sclr(!rst_n),

        .wdata(addr_to_bank_idx(mem_source.aw.addr)),
        .wreq(mem_source.awvalid && mem_source.awready),
        .wfull(wr_rsp_bank_fifo_full),
        .almfull(),
        .wusedw(),

        .rdata(wr_rsp_bank_idx),
        .rdack(mem_source.bvalid && mem_source.bready),
        .rvalid(wr_rsp_bank_fifo_valid),
        .rempty(),
        .rusedw()
        );


    //
    // Track the bank from which the next read response is expected. Responses
    // are returned on mem_source in order.
    //
    logic rd_rsp_bank_fifo_full;
    t_bank_idx rd_rsp_bank_idx;
    logic rd_rsp_bank_fifo_valid;

    fim_rdack_scfifo
      #(
        .DATA_WIDTH($bits(t_bank_idx)),
        .DEPTH_LOG2(9),
        .USE_EAB("ON")
        )
      rd_rsp_bank_fifo
       (
        .clk,
        .sclr(!rst_n),

        .wdata(addr_to_bank_idx(mem_source.ar.addr)),
        .wreq(mem_source.arvalid && mem_source.arready),
        .wfull(rd_rsp_bank_fifo_full),
        .almfull(),
        .wusedw(),

        .rdata(rd_rsp_bank_idx),
        .rdack(mem_source.rvalid && mem_source.rready && mem_source.r.last),
        .rvalid(rd_rsp_bank_fifo_valid),
        .rempty(),
        .rusedw()
        );


    // To simplify the logic, all banks must be ready for any one to be
    // considered ready. The PIM logic that exposes ready bits permits
    // this use of AXI-MM ready.
    logic [NUM_MEM_BANKS-1 : 0] awready_bank;
    wire awready_all = &awready_bank;

    logic [NUM_MEM_BANKS-1 : 0] wready_bank;
    wire wready_all = &wready_bank;

    logic [NUM_MEM_BANKS-1 : 0] arready_bank;
    wire arready_all = &arready_bank;

    // Write address is processed in the same cycle as SOP of write data.
    // This is required in order to send write data to the proper bank.
    wire ready_for_new_write = mem_source.awvalid && mem_source.wvalid &&
                               awready_all && wready_all && !wr_rsp_bank_fifo_full;

    assign mem_source.awready = w_is_sop && ready_for_new_write;
    assign mem_source.wready = w_is_sop ? ready_for_new_write : wready_all;

    assign mem_source.arready = arready_all && !rd_rsp_bank_fifo_full;

    // A bank will claim to have a valid write response only when it is
    // supposed to provide the next value.
    logic [NUM_MEM_BANKS-1 : 0] bvalid_bank;
    wire bvalid_any = |bvalid_bank && wr_rsp_bank_fifo_valid;
    logic [NUM_MEM_BANKS-1 : 0][$bits(mem_source.b)-1 : 0] b_bank;

    // A bank will claim to have a valid read response only when it is
    // supposed to provide the next value.
    logic [NUM_MEM_BANKS-1 : 0] rvalid_bank;
    wire rvalid_any = |rvalid_bank && rd_rsp_bank_fifo_valid;
    logic [NUM_MEM_BANKS-1 : 0][mem_source.T_R_WIDTH-1 : 0] r_bank;

    generate
        for (genvar b = 0; b < NUM_MEM_BANKS; b = b + 1) begin : req

            assign awready_bank[b] = !mem_sinks[b].awvalid || mem_sinks[b].awready;
            assign wready_bank[b] = !mem_sinks[b].wvalid || mem_sinks[b].wready;
            assign arready_bank[b] = !mem_sinks[b].arvalid || mem_sinks[b].arready;

            // Write address
            always_ff @(posedge clk)
            begin
                if (mem_sinks[b].awready) begin
                    mem_sinks[b].awvalid <= 1'b0;
                end

                if (addr_to_bank_idx(mem_source.aw.addr) == t_bank_idx'(b)) begin
                    if (!mem_sinks[b].awvalid || mem_sinks[b].awready) begin
                        mem_sinks[b].awvalid <= mem_source.awvalid && mem_source.awready;
                        `OFS_PLAT_AXI_MEM_IF_COPY_AW(mem_sinks[b].aw, <=, mem_source.aw);
                        mem_sinks[b].aw.addr <= addr_to_bank_addr(mem_source.aw.addr);
                    end
                end

                if (!rst_n) begin
                    mem_sinks[b].awvalid <= 1'b0;
                end
            end

            // Write data
            always_ff @(posedge clk)
            begin
                if (mem_sinks[b].wready) begin
                    mem_sinks[b].wvalid <= 1'b0;
                end

                if ((w_is_sop && addr_to_bank_idx(mem_source.aw.addr) == t_bank_idx'(b)) ||
                    (!w_is_sop && w_cur_bank_idx == t_bank_idx'(b)))
                begin
                    if (!mem_sinks[b].wvalid || mem_sinks[b].wready) begin
                        mem_sinks[b].wvalid <= mem_source.wvalid && mem_source.wready;
                        `OFS_PLAT_AXI_MEM_IF_COPY_W(mem_sinks[b].w, <=, mem_source.w);
                    end
                end

                if (!rst_n) begin
                    mem_sinks[b].wvalid <= 1'b0;
                end
            end

            // Read address
            always_ff @(posedge clk)
            begin
                if (mem_sinks[b].arready) begin
                    mem_sinks[b].arvalid <= 1'b0;
                end

                if (addr_to_bank_idx(mem_source.ar.addr) == t_bank_idx'(b)) begin
                    if (!mem_sinks[b].arvalid || mem_sinks[b].arready) begin
                        mem_sinks[b].arvalid <= mem_source.arvalid && mem_source.arready;
                        `OFS_PLAT_AXI_MEM_IF_COPY_AR(mem_sinks[b].ar, <=, mem_source.ar);
                        mem_sinks[b].ar.addr <= addr_to_bank_addr(mem_source.ar.addr);
                    end
                end

                if (!rst_n) begin
                    mem_sinks[b].arvalid <= 1'b0;
                end
            end

            // Write response. wr_rsp_bank_idx holds the index of the bank expected
            // to provide the next response.
            assign bvalid_bank[b] = (wr_rsp_bank_idx == t_bank_idx'(b)) && mem_sinks[b].bvalid;
            assign mem_sinks[b].bready = mem_source.bready &&
                                         (wr_rsp_bank_idx == t_bank_idx'(b)) && wr_rsp_bank_fifo_valid;
            always_comb
            begin
                b_bank[b] = mem_sinks[b].b;
            end

            // Read response. rd_rsp_bank_idx holds the index of the bank expected
            // to provide the next response.
            assign rvalid_bank[b] = (rd_rsp_bank_idx == t_bank_idx'(b)) && mem_sinks[b].rvalid;
            assign mem_sinks[b].rready = mem_source.rready &&
                                         (rd_rsp_bank_idx == t_bank_idx'(b)) && rd_rsp_bank_fifo_valid;
            always_comb
            begin
                r_bank[b] = mem_sinks[b].r;
            end
        end
    endgenerate

    assign mem_source.bvalid = bvalid_any;
    assign mem_source.b = b_bank[wr_rsp_bank_idx];

    assign mem_source.rvalid = rvalid_any;
    assign mem_source.r = r_bank[rd_rsp_bank_idx];

endmodule: he_mem_merge_banks

// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT


//
// Interfaces entering he_lb_main are platform-independent: an AXI-MM
// interface to host memory, provided by the PIM, and an AXI-MM EMIF
// port provided by one of the parent modules. Clock crossing has
// been instantiated as needed so that all interfaces are in the same
// clk/rst_n domain.
//
// CSRs are managed by the parent, with control and state passed in
// the csr2eng and eng2csr structs.
//

`include "ofs_plat_if.vh"

module he_lb_engines
  #(
    parameter EMIF = 0
    )
   (
    input  logic clk,
    input  logic rst_n,

    input  he_lb_pkg::he_csr2eng csr2eng,
    output he_lb_pkg::he_eng2csr eng2csr,

    // AXI-MM interface to host memory
    ofs_plat_axi_mem_if.to_sink axi_host_mem,

    // Interface to local RAM (e.g. DDR on the FPGA card)
    ofs_plat_axi_mem_if.to_sink emif_if
    );

    // AXI-MM addresses are byte-based
    localparam ADDR_LINE_IDX_WIDTH = axi_host_mem.ADDR_LINE_IDX_WIDTH;
    localparam ADDR_BYTE_OFFSET_WIDTH = axi_host_mem.ADDR_WIDTH - ADDR_LINE_IDX_WIDTH;

    // ====================================================================
    //
    //  Global test start/reset logic
    //
    // ====================================================================

    // Test reset is controlled by a CSR
    logic test_rst_n = 1'b0;
    always @(posedge clk)
    begin
        test_rst_n <= rst_n && csr2eng.ctl.rst_n;
    end

    // Start when csr2eng.ctl.start goes high
    logic start_q;
    wire start_pulse = csr2eng.ctl.start && !start_q;

    always_ff @(posedge clk)
    begin
        start_q <= csr2eng.ctl.start;
        if (!test_rst_n)
        begin
            start_q <= 1'b0;
        end
    end


    // ====================================================================
    //
    //  Instantiate ports for exerciser engines. Each engine gets a
    //  private AXI-MM port.
    //
    // ====================================================================

    localparam ENG_LPBK = 0;
    localparam ENG_ATOMIC = 1;
    localparam ENG_RDWR = 2;
    // Status writer engine must be last
    localparam ENG_STATUS = 3;
    localparam NUM_ENGINES = ENG_STATUS + 1;
    typedef logic [$clog2(NUM_ENGINES)-1 : 0] t_eng_idx;

    logic test_active;
    t_eng_idx cur_eng;
    logic [NUM_ENGINES-1 : 0] eng_done;


    // Per-engine host memory interfaces. A skid buffer is bound to each
    // one for timing in the routing MUX below.
    ofs_plat_axi_mem_if
      #(
        `OFS_PLAT_AXI_MEM_IF_REPLICATE_PARAMS(axi_host_mem)
        )
      host_mem[NUM_ENGINES]();

    generate
        for (genvar p = 0; p < NUM_ENGINES; p = p + 1)
        begin : init
            assign host_mem[p].clk = axi_host_mem.clk;
            assign host_mem[p].reset_n = axi_host_mem.reset_n;
            assign host_mem[p].instance_number = axi_host_mem.instance_number;
        end
    endgenerate

    //
    // Simple MUX for giving each engine a private host memory interface.
    // Only the MUX port chosen by port_select is active. Traffic from all
    // other ports is dropped.
    //
    he_lb_mux_fixed
      #(
        .NUM_PORTS(NUM_ENGINES)
        )
      mux
       (
        .port_select(test_active ? cur_eng : t_eng_idx'(ENG_STATUS)),
        .merged_mem(axi_host_mem),
        .mem_ports(host_mem)
        );


    // ====================================================================
    //
    //  Split the external memory interface into multiple ports, similar
    //  to the host memory MUX above.
    //
    // ====================================================================

    localparam NUM_EMIF_PORTS = 2;

    // Per-engine external memory interface. Only mode_lpbk and mode_rdwr
    // use EMIF, so just two ports are needed.
    ofs_plat_axi_mem_if
      #(
        `OFS_PLAT_AXI_MEM_IF_REPLICATE_PARAMS(emif_if),
        .LOG_CLASS(ofs_plat_log_pkg::LOCAL_MEM)
        )
      ext_mem[NUM_EMIF_PORTS]();

    generate
        for (genvar p = 0; p < NUM_EMIF_PORTS; p = p + 1)
        begin : em_init
            assign ext_mem[p].clk = emif_if.clk;
            assign ext_mem[p].reset_n = emif_if.reset_n;
            assign ext_mem[p].instance_number = emif_if.instance_number;
        end
    endgenerate

    //
    // EMIF uses exactly the same AXI-MM interface definition as host
    // memory, changing only parameters such as address width. The
    // same MUX can be used for both.
    //
    he_lb_mux_fixed
      #(
        .NUM_PORTS(NUM_EMIF_PORTS)
        )
      em_mux
       (
        // Select between ENG_LPBK and ENG_RDWR
        .port_select((cur_eng == ENG_LPBK) ? 1'd0 : 1'd1),
        .merged_mem(emif_if),
        .mem_ports(ext_mem)
        );


    // ====================================================================
    //
    //  Test engines. Only one is active at a time.
    //
    // ====================================================================

    //
    // Loopback test (memory copy). Read responses feed writes.
    //
    mode_lpbk
      #(
        .EMIF(EMIF)
        )
      lpbk
       (
        .clk,
        .rst_n,
        .start(start_pulse && (cur_eng == ENG_LPBK)),
        .done(eng_done[ENG_LPBK]),
        .csr2eng,
        .axi_host_mem(host_mem[ENG_LPBK]),
        .emif_if(ext_mem[0])
        );


    //
    // Atomic tests.
    //
    mode_atomic atomic
       (
        .clk,
        .rst_n,
        .start(start_pulse && (cur_eng == ENG_ATOMIC)),
        .done(eng_done[ENG_ATOMIC]),
        .csr2eng,
        .axi_host_mem(host_mem[ENG_ATOMIC])
        );


    //
    // Independent read and write tests, mostly useful for throughput testing.
    //
    generate
        if (EMIF == 0)
        begin : hm
            // Read/write host memory
            mode_rdwr rdwr
               (
                .clk,
                .rst_n,
                .start(start_pulse && (cur_eng == ENG_RDWR)),
                .done(eng_done[ENG_RDWR]),
                .csr2eng,
                .axi_mem(host_mem[ENG_RDWR])
                );

            // EMIF unused
            assign ext_mem[1].awvalid = 1'b0;
            assign ext_mem[1].wvalid = 1'b0;
            assign ext_mem[1].bready = 1'b1;
            assign ext_mem[1].arvalid = 1'b0;
            assign ext_mem[1].rready = 1'b1;
        end
        else
        begin : em
            // Read/write external memory (e.g. board DDR). The same PIM
            // AXI-MM interface is used for external memory and host memory,
            // so the same module can be used for either. This instance
            // of the test accesses only EMIF.
            //
            // The final host status memory write is handled by the shared
            // code below. The host memory interface is not passed to
            // mode_rdwr here.
            mode_rdwr
              #(
                .EMIF(1)
                )
              rdwr
               (
                .clk,
                .rst_n,
                .start(start_pulse && (cur_eng == ENG_RDWR)),
                .done(eng_done[ENG_RDWR]),
                .csr2eng,
                .axi_mem(ext_mem[1])
                );

            // RDWR host memory port is unused
            assign host_mem[ENG_RDWR].awvalid = 1'b0;
            assign host_mem[ENG_RDWR].wvalid = 1'b0;
            assign host_mem[ENG_RDWR].bready = 1'b1;
            assign host_mem[ENG_RDWR].arvalid = 1'b0;
            assign host_mem[ENG_RDWR].rready = 1'b1;
        end
    endgenerate


    // ====================================================================
    //
    //  Shared status management. Generates the status memory write and
    //  an interrupt, if requested, at the end of one of the tests above.
    //
    // ====================================================================

    //
    // Status buffer and interrupt writes. These fire after one of the engines
    // above finishes.
    //
    logic status_addr_write, status_data_write;
    logic status_interrupt;
    logic [14:0] dsm_uid;
    logic [19:0] num_ticks_h, num_ticks_l; 

    always_comb
    begin
        // Address
        host_mem[ENG_STATUS].awvalid = status_addr_write;
        host_mem[ENG_STATUS].aw = '0;
        host_mem[ENG_STATUS].aw.size = host_mem[ENG_STATUS].ADDR_BYTE_IDX_WIDTH;
        if (! status_interrupt)
        begin
            // Normal status memory write
            host_mem[ENG_STATUS].aw.addr = { csr2eng.dsm_base, ADDR_BYTE_OFFSET_WIDTH'(0) };
        end
        else
        begin
            // Interrupt vector starts at bit 16 of CSR
            host_mem[ENG_STATUS].aw.addr = { '0, csr2eng.interrupt0[31:16] };
            host_mem[ENG_STATUS].aw.user[ofs_plat_host_chan_axi_mem_pkg::HC_AXI_UFLAG_INTERRUPT] = 1'b1;
        end

        // Data. Send the same payload even for interrupts. The value doesn't matter.
        host_mem[ENG_STATUS].wvalid = status_data_write;
        host_mem[ENG_STATUS].w = '0;
        host_mem[ENG_STATUS].w.last = 1'b1;
        host_mem[ENG_STATUS].w.strb = ~('0);

        host_mem[ENG_STATUS].w.data =
            { '0,
              32'h0,                          // [255:224] test end overhead in # clks (no longer used)
              32'h0,                          // [223:192] test start overhead in # clks (no longer used)
              eng2csr.num_writes[31:0],       // [191:160] total number of write lines sent
              eng2csr.num_reads[31:0],        // [159:128] Total number of read lines received
              eng2csr.num_writes[39:32],      // [127:120] extra write count (added later)
              eng2csr.num_reads[39:32],       // [119:112] extra read count (added later)
              8'h0, num_ticks_h, num_ticks_l, // [111:64]  number of clk cycles since start
              32'h0,                          // [63:32]   errors detected
              16'h0, dsm_uid,                 // [15:1]    unique id for each dsm status write
              1'h1                            // [0]       test completion flag
              };

        host_mem[ENG_STATUS].arvalid = 1'b0;
        host_mem[ENG_STATUS].rready = 1'b1;
        host_mem[ENG_STATUS].bready = 1'b1;
    end

    // Cycle counter
    always_ff @(posedge clk)
    begin
        if (test_active)
        begin
            num_ticks_l <= num_ticks_l + 1;
            if (&num_ticks_l)
            begin
                num_ticks_h <= num_ticks_h + 1;
            end
        end

        if (!test_rst_n)
        begin
            num_ticks_h <= '0;
            num_ticks_l <= '0;
        end
    end

    // Update dsm_uid
    always_ff @(posedge clk)
    begin
        if (status_addr_write && host_mem[ENG_STATUS].awready)
        begin
            dsm_uid <= dsm_uid + 1;
        end

        if (!rst_n)
        begin
            dsm_uid <= '0;
        end
    end


    // ====================================================================
    //
    //  State machine that drives tests and picks the active MUX ports
    //
    // ====================================================================

    always_ff @(posedge clk)
    begin
        if (csr2eng.cfg.atomic_req_en)
            cur_eng <= ENG_ATOMIC;
        else if (csr2eng.cfg.test_mode == 0)
            cur_eng <= ENG_LPBK;
        else
            cur_eng <= ENG_RDWR;
    end

    always_ff @(posedge clk)
    begin
        if (status_addr_write)
        begin
            // Ending test. Completed AW for status?
            if (host_mem[ENG_STATUS].awready)
            begin
                // Move on to status data write
                status_addr_write <= 1'b0;
                status_data_write <= 1'b1;
            end
        end
        else if (status_data_write)
        begin
            // Status data write complete?
            if (host_mem[ENG_STATUS].wready)
            begin
                // Status data complete
                status_data_write <= 1'b0;

                if (status_interrupt || !csr2eng.cfg.intr_on_done)
                begin
                    // Finished with status. Either no interrupt expected or
                    // the interrupt has been emitted.
                    status_interrupt <= 1'b0;
                end
                else if (csr2eng.cfg.intr_on_done)
                begin
                    // Host wants an interrupt
                    status_interrupt <= 1'b1;
                    status_addr_write <= 1'b1;
                end
            end
        end
        else if (test_active)
        begin
            // Wait for the active test to finish.
            if (eng_done[cur_eng])
            begin
                // Finished. Move on to status write.
                test_active <= 1'b0;
                status_addr_write <= 1'b1;
            end
        end
        else if (start_pulse)
        begin
            // Start a test
            test_active <= 1'b1;
        end

        if (!test_rst_n)
        begin
            test_active <= 1'b0;
            status_addr_write <= 1'b0;
            status_data_write <= 1'b0;
            status_interrupt <= 1'b0;
        end
    end


    // ====================================================================
    //
    // Statistics. By watching the axi_host_mem interface, statistics can
    // be kept for any active engine since the algorithm is the same.
    //
    // ====================================================================

    wire host_mem_new_rd_pkt = (axi_host_mem.arvalid && axi_host_mem.arready);
    wire host_mem_rd_done = (axi_host_mem.rvalid && axi_host_mem.rready && axi_host_mem.r.last);
    wire host_mem_new_wr_pkt = (axi_host_mem.awvalid && axi_host_mem.awready);
    wire host_mem_wr_done = (axi_host_mem.bvalid && axi_host_mem.bready);

    wire emif_new_rd_pkt = (emif_if.arvalid && emif_if.arready);
    wire emif_rd_done = (emif_if.rvalid && emif_if.rready && emif_if.r.last);
    wire emif_new_wr_pkt = (emif_if.awvalid && emif_if.awready);
    wire emif_wr_done = (emif_if.bvalid && emif_if.bready);

    he_lb_pkg::t_event_counter num_host_mem_reads, num_host_mem_writes;
    he_lb_pkg::t_event_counter num_ext_mem_reads, num_ext_mem_writes;

    always_ff @(posedge clk)
    begin
        // Count reads by tracking read responses since that makes the addition easy.
        // The count is the number of data-bus-width transactions.
        if (axi_host_mem.rvalid && axi_host_mem.rready)
        begin
            num_host_mem_reads <= num_host_mem_reads + 1;
        end
        if (emif_if.rvalid && emif_if.rready)
        begin
            num_ext_mem_reads <= num_ext_mem_reads + 1;
        end

        // Count writes, also one per bus width
        if (axi_host_mem.wvalid && axi_host_mem.wready)
        begin
            num_host_mem_writes <= num_host_mem_writes + 1;
        end
        if (emif_if.wvalid && emif_if.wready)
        begin
            num_ext_mem_writes <= num_ext_mem_writes + 1;
        end

        // Pick EMIF counters for EMIF+RDWR, otherwise host memory
        eng2csr.num_reads  <= ((EMIF != 0) && (cur_eng == ENG_RDWR)) ? num_ext_mem_reads :
                                                                       num_host_mem_reads;
        eng2csr.num_writes <= ((EMIF != 0) && (cur_eng == ENG_RDWR)) ? num_ext_mem_writes :
                                                                       num_host_mem_writes;

        // Count reads in flight
        case ({ host_mem_new_rd_pkt, host_mem_rd_done })
            2'b00: eng2csr.num_host_rdpend <= eng2csr.num_host_rdpend;
            2'b01: eng2csr.num_host_rdpend <= eng2csr.num_host_rdpend - 1;
            2'b10: eng2csr.num_host_rdpend <= eng2csr.num_host_rdpend + 1;
            2'b11: eng2csr.num_host_rdpend <= eng2csr.num_host_rdpend;
        endcase

        case ({ emif_new_rd_pkt, emif_rd_done })
            2'b00: eng2csr.num_emif_rdpend <= eng2csr.num_emif_rdpend;
            2'b01: eng2csr.num_emif_rdpend <= eng2csr.num_emif_rdpend - 1;
            2'b10: eng2csr.num_emif_rdpend <= eng2csr.num_emif_rdpend + 1;
            2'b11: eng2csr.num_emif_rdpend <= eng2csr.num_emif_rdpend;
        endcase

        // Count writes in flight
        case ({ host_mem_new_wr_pkt, host_mem_wr_done })
            2'b00: eng2csr.num_host_wrpend <= eng2csr.num_host_wrpend;
            2'b01: eng2csr.num_host_wrpend <= eng2csr.num_host_wrpend - 1;
            2'b10: eng2csr.num_host_wrpend <= eng2csr.num_host_wrpend + 1;
            2'b11: eng2csr.num_host_wrpend <= eng2csr.num_host_wrpend;
        endcase

        case ({ emif_new_wr_pkt, emif_wr_done })
            2'b00: eng2csr.num_emif_wrpend <= eng2csr.num_emif_wrpend;
            2'b01: eng2csr.num_emif_wrpend <= eng2csr.num_emif_wrpend - 1;
            2'b10: eng2csr.num_emif_wrpend <= eng2csr.num_emif_wrpend + 1;
            2'b11: eng2csr.num_emif_wrpend <= eng2csr.num_emif_wrpend;
        endcase

        // Software requested reset
        if (!csr2eng.ctl.rst_n)
        begin
            eng2csr <= '0;
            num_host_mem_reads <= '0;
            num_host_mem_writes <= '0;
            num_ext_mem_reads <= '0;
            num_ext_mem_writes <= '0;
        end
    end

endmodule // he_lb_engines

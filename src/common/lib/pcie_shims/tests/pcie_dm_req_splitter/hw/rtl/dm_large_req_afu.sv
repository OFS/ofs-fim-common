// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT


`include "ofs_plat_if.vh"
`include "afu_json_info.vh"

module dm_large_req_afu
  #(
    parameter INSTANCE_ID = 0,

    parameter pcie_ss_hdr_pkg::ReqHdr_pf_num_t PF_ID,
    parameter pcie_ss_hdr_pkg::ReqHdr_vf_num_t VF_ID,
    parameter logic VF_ACTIVE
    )  
   (
    input  logic clk,
    input  logic rst_n,

    pcie_ss_axis_if.sink   rx_a_if,
    pcie_ss_axis_if.source o_tx_a_if,

    // Completions
    pcie_ss_axis_if.sink   i_rx_cpl_if,

    // These ports will be tied off and not used
    pcie_ss_axis_if.sink   rx_b_if,
    pcie_ss_axis_if.source o_tx_b_if
    );


    pcie_ss_axis_if tx_a_spl_if(clk, rst_n);
    pcie_ss_axis_if tx_b_spl_if(clk, rst_n);

    pcie_ss_axis_if rx_cpl_spl_if(clk, rst_n);

    ofs_fim_pcie_dm_req_splitter
      #(
        .INSTANCE_ID(INSTANCE_ID)
        )
      req_splitter
       (
        .o_tx_a_if,
        .o_tx_b_if,
        .i_rx_cpl_if,

        .i_tx_a_if(tx_a_spl_if),
        .i_tx_b_if(tx_b_spl_if),
        .o_rx_cpl_if(rx_cpl_spl_if)
        );

    pcie_ss_axis_if tx_a_if(clk, rst_n);
    pcie_ss_axis_if tx_b_if(clk, rst_n);

    pcie_ss_axis_if rx_cpl_if(clk, rst_n);

    ofs_fim_pcie_dm_cpl_merge
      #(
        .INSTANCE_ID(INSTANCE_ID)
        )
      cpl_merge
       (
        .o_tx_a_if(tx_a_spl_if),
        .o_tx_b_if(tx_b_spl_if),
        .i_rx_cpl_if(rx_cpl_spl_if),

        .i_tx_a_if(tx_a_if),
        .i_tx_b_if(tx_b_if),
        .o_rx_cpl_if(rx_cpl_if)
        );


    // ====================================================================
    //
    //  Consume host memory read completions
    //
    // ====================================================================

    pcie_ss_hdr_pkg::PCIe_OrdCplHdr_t rx_cpl_hdr;
    assign rx_cpl_hdr = pcie_ss_hdr_pkg::PCIe_OrdCplHdr_t'(rx_cpl_if.tdata);


    //
    // Hash completions into 32 bit buckets across the data bus.
    //

    logic rx_cpl_sop;
    logic rx_is_cpl_packet_reg;
    wire rx_is_cpl_packet =
        rx_cpl_sop ? 
            (pcie_ss_hdr_pkg::func_hdr_is_dm_mode(rx_cpl_if.tuser_vendor) &&
             pcie_ss_hdr_pkg::func_is_completion(rx_cpl_hdr.fmt_type)) :
            rx_is_cpl_packet_reg;

    logic [15:0] num_cpls_rcvd;

    always_ff @(posedge clk)
    begin
        if (rx_cpl_if.tvalid && rx_cpl_if.tready) begin
            rx_cpl_sop <= rx_cpl_if.tlast;

            if (rx_cpl_sop) begin
                rx_is_cpl_packet_reg <=
                    pcie_ss_hdr_pkg::func_hdr_is_dm_mode(rx_cpl_if.tuser_vendor) &&
                    pcie_ss_hdr_pkg::func_is_completion(rx_cpl_hdr.fmt_type);
            end

            if (rx_cpl_if.tlast && rx_is_cpl_packet) begin
                num_cpls_rcvd <= num_cpls_rcvd + 1;
            end
        end

        if (!rst_n) begin
            rx_cpl_sop <= 1'b1;
            num_cpls_rcvd <= '0;
        end
    end

    //
    // Hash the completion data with a separate bucket for every 32 bits
    // of the bus. The hash is read via CSRs.
    //

    logic [31:0] cpl_hash_value[ofs_pcie_ss_cfg_pkg::TDATA_WIDTH/32];

    // Force bytes not marked keep to 0
    logic [ofs_pcie_ss_cfg_pkg::TDATA_WIDTH-1 : 0] cpl_kept_data;
    always_comb
    begin
        for (int i = 0; i < ofs_pcie_ss_cfg_pkg::TDATA_WIDTH/8; i = i + 1) begin
            cpl_kept_data[8*i +: 8] = rx_cpl_if.tkeep[i] ? rx_cpl_if.tdata[8*i +: 8] : 8'h0;
        end
    end

    generate
        for (genvar b = 0; b < ofs_pcie_ss_cfg_pkg::TDATA_WIDTH/32; b = b + 1) begin : buckets
            wire skip_hdr = rx_cpl_sop && (b < $bits(pcie_ss_hdr_pkg::PCIe_CplHdr_t)/32);

            hash32 hash
               (
                .clk,
                .reset_n(rst_n),
                .en(rx_cpl_if.tkeep[b*4] && !skip_hdr && rx_is_cpl_packet &&
                    rx_cpl_if.tready && rx_cpl_if.tvalid),
                .new_data(cpl_kept_data[32*b +: 32]),
                .value(cpl_hash_value[b])
                );
        end
    endgenerate


    //
    // Simple loopback of read completions, turning them directly into
    // host memory writes.
    //

    logic wr_lpbk_en;
    wire gen_wr_req = wr_lpbk_en && rx_cpl_if.tvalid;
    logic wr_req_arb_en;
    assign rx_cpl_if.tready = !wr_lpbk_en || wr_req_arb_en;

    pcie_ss_hdr_pkg::PCIe_ReqHdr_t tx_wr_hdr;
    logic [ofs_pcie_ss_cfg_pkg::TDATA_WIDTH-1 : 0] wr_req_tdata;
    logic [ofs_pcie_ss_cfg_pkg::TDATA_WIDTH/8-1 : 0] wr_req_tkeep;
    logic [ofs_pcie_ss_cfg_pkg::TUSER_WIDTH-1 : 0] wr_req_tuser_vendor;
    logic wr_req_tlast;

    logic new_wr_host_addr_en;
    logic [63:0] new_wr_host_addr;
    logic [63:0] wr_host_addr;

    always_comb
    begin
        wr_req_tdata = rx_cpl_if.tdata;
        
        tx_wr_hdr = rx_cpl_hdr;
        tx_wr_hdr.fmt_type = pcie_ss_hdr_pkg::DM_WR;
        tx_wr_hdr.PH = '0;
        { tx_wr_hdr.tag_h, tx_wr_hdr.tag_m, tx_wr_hdr.tag_l } = '0;
        { tx_wr_hdr.length_h, tx_wr_hdr.length_m, tx_wr_hdr.length_l } =
            { rx_cpl_hdr.length_x, rx_cpl_hdr.length_h, rx_cpl_hdr.length_m, rx_cpl_hdr.length_l };
        { tx_wr_hdr.host_addr_h, tx_wr_hdr.host_addr_m, tx_wr_hdr.host_addr_l } = wr_host_addr;

        if (rx_cpl_sop) begin
            wr_req_tdata[$bits(tx_wr_hdr)-1 : 0] = tx_wr_hdr;
        end

        wr_req_tkeep = rx_cpl_if.tkeep;
        wr_req_tuser_vendor = rx_cpl_if.tuser_vendor;
        wr_req_tlast = rx_cpl_if.tlast;
    end

    always_ff @(posedge clk)
    begin
        if (wr_req_arb_en && rx_cpl_sop) begin
            wr_host_addr <= wr_host_addr + { rx_cpl_hdr.length_x, rx_cpl_hdr.length_h,
                                             rx_cpl_hdr.length_m, rx_cpl_hdr.length_l };
        end

        if (new_wr_host_addr_en) begin
            wr_host_addr <= new_wr_host_addr;
            wr_lpbk_en <= 1'b1;
        end

        if (!rst_n) begin
            wr_host_addr <= '0;
            wr_lpbk_en <= '0;
        end
    end


    // ====================================================================
    //
    //  Watch for MMIO requests on the RX stream.
    //
    // ====================================================================

    pcie_ss_hdr_pkg::PCIe_PUReqHdr_t rx_a_pu_hdr;
    assign rx_a_pu_hdr = pcie_ss_hdr_pkg::PCIe_PUReqHdr_t'(rx_a_if.tdata);

    logic rx_a_if_sop;
    always_ff @(posedge clk)
    begin
        if (rx_a_if.tvalid && rx_a_if.tready)
        begin
            rx_a_if_sop <= rx_a_if.tlast;
        end

        if (!rst_n)
        begin
            rx_a_if_sop <= 1'b1;
        end
    end

    logic mmio_rd_notFull;
    pcie_ss_hdr_pkg::PCIe_PUReqHdr_t mmio_rd_hdr;
    logic [4:0] mmio_rd_low_addr;
    logic mmio_rd_hdr_valid;
    logic mmio_rd_deq_en;

    //
    // Queue MMIO read requests from the TLP stream
    //
    ofs_plat_prim_fifo2
      #(
        .N_DATA_BITS($bits(pcie_ss_hdr_pkg::PCIe_PUReqHdr_t))
        )
      mmio_rd_fifo
       (
        .clk,
        .reset_n(rst_n),

        .enq_en(rx_a_if.tvalid && rx_a_if_sop &&
                pcie_ss_hdr_pkg::func_hdr_is_pu_mode(rx_a_if.tuser_vendor) &&
                pcie_ss_hdr_pkg::func_is_mrd_req(rx_a_pu_hdr.fmt_type)),
        .enq_data(rx_a_pu_hdr),
        .notFull(mmio_rd_notFull),

        .first(mmio_rd_hdr),
        .deq_en(mmio_rd_deq_en),
        .notEmpty(mmio_rd_hdr_valid)
        );

    assign mmio_rd_low_addr =
        pcie_ss_hdr_pkg::func_is_addr64(mmio_rd_hdr.fmt_type) ?
                             mmio_rd_hdr.host_addr_l[4:0] : mmio_rd_hdr.host_addr_h[6:2];


    logic mmio_wr_notFull;
    logic [4:0] mmio_wr_low_addr;
    logic [63:0] mmio_wr_data;
    logic mmio_wr_deq_en;
    logic mmio_wr_valid;

    // Queue MMIO write requests
    ofs_plat_prim_fifo_bram
      #(
        .N_ENTRIES(512),
        .N_DATA_BITS(5 + 64)
        )
      mmio_wr_fifo
       (
        .clk,
        .reset_n(rst_n),

        .enq_en(rx_a_if.tvalid && rx_a_if_sop &&
                pcie_ss_hdr_pkg::func_hdr_is_pu_mode(rx_a_if.tuser_vendor) &&
                pcie_ss_hdr_pkg::func_is_mwr_req(rx_a_pu_hdr.fmt_type)),
        .enq_data({ (pcie_ss_hdr_pkg::func_is_addr64(rx_a_pu_hdr.fmt_type) ?
                       rx_a_pu_hdr.host_addr_l[4:0] : rx_a_pu_hdr.host_addr_h[6:2]),
                    rx_a_if.tdata[$bits(pcie_ss_hdr_pkg::PCIe_PUReqHdr_t) +: 64] }),
        .notFull(mmio_wr_notFull),
        .almostFull(),

        .first({ mmio_wr_low_addr, mmio_wr_data }),
        .deq_en(mmio_wr_deq_en),
        .notEmpty(mmio_wr_valid)
        );

    assign rx_a_if.tready = mmio_rd_notFull && mmio_wr_notFull;


    // ====================================================================
    //
    //  Respond to MMIO read requests with completions.
    //
    // ====================================================================

    localparam MMIO_CPL_HDR_BYTES = $bits(pcie_ss_hdr_pkg::PCIe_PUCplHdr_t) / 8;
    pcie_ss_hdr_pkg::PCIe_PUCplHdr_t mmio_cpl_hdr;

    always_comb
    begin
        // Build the header -- always the same for any address
        mmio_cpl_hdr = '0;
        mmio_cpl_hdr.fmt_type = pcie_ss_hdr_pkg::ReqHdr_FmtType_e'(pcie_ss_hdr_pkg::PCIE_FMTTYPE_CPLD);
        mmio_cpl_hdr.length = mmio_rd_hdr.length;
        mmio_cpl_hdr.req_id = mmio_rd_hdr.req_id;
        mmio_cpl_hdr.tag_h = mmio_rd_hdr.tag_h;
        mmio_cpl_hdr.tag_m = mmio_rd_hdr.tag_m;
        mmio_cpl_hdr.tag_l = mmio_rd_hdr.tag_l;
        mmio_cpl_hdr.TC = mmio_rd_hdr.TC;
        mmio_cpl_hdr.byte_count = mmio_rd_hdr.length << 2;
        mmio_cpl_hdr.low_addr[6:2] = mmio_rd_low_addr;

        mmio_cpl_hdr.comp_id = { VF_ID, VF_ACTIVE, PF_ID };
        mmio_cpl_hdr.pf_num = PF_ID;
        mmio_cpl_hdr.vf_num = VF_ID;
        mmio_cpl_hdr.vf_active = VF_ACTIVE;
    end

    logic [63:0] mmio_cpl_data;
    logic [127:0] afu_id = `AFU_ACCEL_UUID;
    logic is_cpl_fifo_rd;
    logic is_cpl_tkeep_rd;

    // Completion data. There is minimal address decoding here to keep
    // it simple. Location 0 needs a device feature header and an AFU
    // ID is set.
    always_comb
    begin
        is_cpl_fifo_rd = 1'b0;
        is_cpl_tkeep_rd = 1'b0;

        case (mmio_rd_low_addr[4:1])
            // AFU DFH
            4'h0:
                begin
                    mmio_cpl_data[63:0] = '0;
                    // Feature type is AFU
                    mmio_cpl_data[63:60] = 4'h1;
                    // End of list
                    mmio_cpl_data[40] = 1'b1;
                end

            // AFU_ID_L
            4'h1: mmio_cpl_data[63:0] = afu_id[63:0];

            // AFU_ID_H
            4'h2: mmio_cpl_data[63:0] = afu_id[127:64];

            // Number of completions received
            4'h7: mmio_cpl_data[63:0] = { '0, num_cpls_rcvd };

            // Completion hashes, with indices rotated to account for
            // and skip the inband header.
            4'h8: mmio_cpl_data[63:0] = { cpl_hash_value[9], cpl_hash_value[8] };
            4'h9: mmio_cpl_data[63:0] = { cpl_hash_value[11], cpl_hash_value[10] };
            4'ha: mmio_cpl_data[63:0] = { cpl_hash_value[13], cpl_hash_value[12] };
            4'hb: mmio_cpl_data[63:0] = { cpl_hash_value[15], cpl_hash_value[14] };
            4'hc: mmio_cpl_data[63:0] = { cpl_hash_value[1], cpl_hash_value[0] };
            4'hd: mmio_cpl_data[63:0] = { cpl_hash_value[3], cpl_hash_value[2] };
            4'he: mmio_cpl_data[63:0] = { cpl_hash_value[5], cpl_hash_value[4] };
            4'hf: mmio_cpl_data[63:0] = { cpl_hash_value[7], cpl_hash_value[6] };

            default: mmio_cpl_data[63:0] = '0;
        endcase

        // Was the request short, asking for the high 32 bits of the 64 bit register?
        if (mmio_rd_low_addr[0])
        begin
            mmio_cpl_data[31:0] = mmio_cpl_data[63:32];
        end
    end


    // ====================================================================
    //
    //  Consume MMIO writes, which drive host memory requests
    //
    // ====================================================================

    //
    // MMIO write locations (64 bit registers):
    //   0 - Host memory read request length
    //   1 - Host memory read address
    //   2 - Host memory write (loopback) address
    //   3 - Test config
    //

    logic [23:0] rd_req_bytes_reg;
    logic rd_req_use_tx_a;

    always_ff @(posedge clk)
    begin
        new_wr_host_addr_en <= 1'b0;

        if (mmio_wr_valid)
        begin
            if (mmio_wr_low_addr[2:1] == 2'b00)
                rd_req_bytes_reg <= 24'(mmio_wr_data);
            if (mmio_wr_low_addr[2:1] == 2'b10)
            begin
                new_wr_host_addr_en <= 1'b1;
                new_wr_host_addr <= mmio_wr_data;
            end
            if (mmio_wr_low_addr[2:1] == 2'b11)
            begin
                // Test config. Bit 0 sets use TX A.
                rd_req_use_tx_a <= mmio_wr_data[0];
            end
        end

        if (!rst_n)
        begin
            rd_req_bytes_reg <= 4;
            rd_req_use_tx_a <= 1'b0;
        end
    end

    wire mmio_wr_is_rd_addr = (mmio_wr_low_addr[2:1] == 2'b01);
    assign mmio_wr_deq_en = mmio_wr_valid;

    // ====================================================================
    //
    //  Read requests
    //
    // ====================================================================

    pcie_ss_hdr_pkg::PCIe_ReqHdr_t rd_req_hdr;
    logic rd_req_arb_a_en, rd_req_arb_b_en;
    wire rd_req_arb_en = rd_req_arb_a_en || rd_req_arb_b_en;
    logic [63:0] rd_req_addr;
    logic [23:0] rd_req_bytes;
    logic [$clog2(ofs_pcie_ss_cfg_pkg::PCIE_EP_MAX_TAGS)-1 : 0] rd_req_tag;

    // Store incoming read request commands (from MMIO writes)
    ofs_plat_prim_fifo_bram
      #(
        .N_ENTRIES(32),
        .N_DATA_BITS($bits(rd_req_bytes) + $bits(mmio_wr_data))
        )
      rd_req_fifo
       (
        .clk,
        .reset_n(rst_n),

        .enq_en(mmio_wr_valid && mmio_wr_is_rd_addr),
        .enq_data({ rd_req_bytes_reg, mmio_wr_data }),
        // Software's job to avoid filling this queue
        .notFull(),
        .almostFull(),

        .first({ rd_req_bytes, rd_req_addr }),
        .deq_en(rd_req_arb_en && gen_rd_req),
        .notEmpty(gen_rd_req)
        );

    always_comb
    begin
        rd_req_hdr = '0;
        rd_req_hdr.fmt_type = pcie_ss_hdr_pkg::DM_RD;
        rd_req_hdr.pf_num = PF_ID;
        rd_req_hdr.vf_num = VF_ID;
        rd_req_hdr.vf_active = VF_ACTIVE;
        {rd_req_hdr.length_h, rd_req_hdr.length_m, rd_req_hdr.length_l} = rd_req_bytes;
        { rd_req_hdr.tag_h, rd_req_hdr.tag_m, rd_req_hdr.tag_l } = rd_req_tag;
        {rd_req_hdr.host_addr_h, rd_req_hdr.host_addr_m, rd_req_hdr.host_addr_l} =
            {'0, rd_req_addr};
    end

    always_ff @(posedge clk)
    begin
        if (gen_rd_req && rd_req_arb_en) begin
            rd_req_tag <= rd_req_tag + 1;
        end

        if (!rst_n) begin
            rd_req_tag <= '0;
        end
    end


    // ====================================================================
    //
    //  TX arbitration: completions and host memory requests
    //
    // ====================================================================

    logic tx_a_lock_for_wr;
    always_ff @(posedge clk)
    begin
        if (wr_req_arb_en) begin
            tx_a_lock_for_wr <= !tx_a_if.tlast;
        end

        if (!rst_n) begin
            tx_a_lock_for_wr <= 1'b0;
        end
    end

    // TX-A
    always_comb
    begin
        wr_req_arb_en = 1'b0;
        mmio_rd_deq_en = 1'b0;
        rd_req_arb_a_en = 1'b0;

        if (mmio_rd_hdr_valid && !tx_a_lock_for_wr)
        begin
            //
            // CSR read response
            //

            tx_a_if.tvalid = 1'b1;
            tx_a_if.tdata = { '0, mmio_cpl_data, mmio_cpl_hdr };
            tx_a_if.tlast = 1'b1;
            tx_a_if.tuser_vendor = '0;
            // Keep matches the data: either 8 or 4 bytes of data and the header
            tx_a_if.tkeep = { '0, {4{(mmio_cpl_hdr.length > 1)}}, {4{1'b1}}, {MMIO_CPL_HDR_BYTES{1'b1}} };

            mmio_rd_deq_en = tx_a_if.tvalid && tx_a_if.tready;
        end
        else if (gen_wr_req || tx_a_lock_for_wr)
        begin
            //
            // Loopback DMA write request from read completions
            //

            tx_a_if.tvalid = gen_wr_req;
            tx_a_if.tdata = wr_req_tdata;
            tx_a_if.tlast = wr_req_tlast;
            tx_a_if.tuser_vendor = wr_req_tuser_vendor;
            tx_a_if.tkeep = wr_req_tkeep;

            wr_req_arb_en = gen_wr_req && tx_a_if.tready;
        end
        else
        begin
            //
            // DMA read request
            //

            tx_a_if.tvalid = gen_rd_req && rd_req_use_tx_a;
            tx_a_if.tdata = { '0, rd_req_hdr };
            tx_a_if.tlast = 1'b1;
            tx_a_if.tuser_vendor = 1;	// Data mover encoding
            tx_a_if.tkeep = { '0, {MMIO_CPL_HDR_BYTES{1'b1}} };

            rd_req_arb_a_en = (tx_a_if.tready && rd_req_use_tx_a);
        end
    end

    // TX-B - only DMA read requests
    always_comb
    begin
        tx_b_if.tvalid = gen_rd_req && !rd_req_use_tx_a;
        tx_b_if.tdata = { '0, rd_req_hdr };
        tx_b_if.tlast = 1'b1;
        tx_b_if.tuser_vendor = 1;	// Data mover encoding
        tx_b_if.tkeep = { '0, {MMIO_CPL_HDR_BYTES{1'b1}} };

        rd_req_arb_b_en = (tx_b_if.tready && !rd_req_use_tx_a);
    end

    assign rx_b_if.tready = 1'b1;


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
        log_fd = $fopen($sformatf("log_dm_large_req_afu_port%0d.tsv", INSTANCE_ID), "w");

        // Write module hierarchy to the top of the log
        $fwrite(log_fd, "dm_large_req_afu.sv: %m\n\n");
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

    `LOG_PCIE_STREAM(o_tx_a_if,      "o_tx_a:      %s\n")
    `LOG_PCIE_STREAM(tx_a_if,        "tx_a:        %s\n")
    `LOG_PCIE_STREAM(o_tx_b_if,      "o_tx_b:      %s\n")
    `LOG_PCIE_STREAM(tx_b_if,        "tx_b:        %s\n")

    `LOG_PCIE_STREAM(rx_a_if,        "rx_a:        %s\n")
    `LOG_PCIE_STREAM(rx_b_if,        "rx_b:        %s\n")
    `LOG_PCIE_STREAM(rx_cpl_if,      "rx_cpl:      %s\n")

    // synthesis translate_on

endmodule

// Copyright (C) 2022 Intel Corporation
// SPDX-License-Identifier: MIT

//
// Construct an AFU feature header at MMIO address 0 for either a parent
// or child of a multi-ported AFU. AFU developers may either generate equivalent
// features in AFU-private code or integrate this module.
//
// Version 1 feature headers are created. Parameters allow AFUs to set
// the DFH next field and AFU CSR regions. By default, all MMIO requests
// will be handled in this module unless NEXT_DFH or a CSR region is
// defined.
//

module ofs_fim_pcie_multi_link_afu_dfh
  #(
    // For a child AFU, leave NUM_CHILDREN set to zero. A parent AFU header is
    // constructed when NUM_CHILDREN is non-zero.
    parameter NUM_CHILDREN = 0,
    // When the AFU is a parent (NUM_CHILDREN > 0), set CHILD_GUIDs to an array
    // of child GUIDs on which the parent depends.
    parameter logic [127:0] CHILD_GUIDS[NUM_CHILDREN == 0 ? 1 : NUM_CHILDREN] = {'0},

    // Byte offset to the next feature. If non-zero, the next feature's MMIO
    // traffic must be handled by the AFU.
    parameter logic [23:0] NEXT_DFH = '0,

    // Byte offset to a CSR region. If non-zero, CSR traffic must be handled
    // by the AFU. The CSR region must be outside of the AFU feature managed
    // by this module.
    parameter logic [63:0] CSR_ADDR = '0,
    parameter logic [31:0] CSR_SIZE = '0,

    // When set to one this module will respond to all MMIO reads. When zero,
    // reads outside of the main AFU feature will be forwarded to o_rx_if.
    // All MMIO writes are forwarded to o_rx_if unconditionally.
    // By default, all MMIO reads are handled here if both NEXT_DFH and
    // CSR_ADDR are zero.
    parameter logic HANDLE_ALL_MMIO_READS = !NEXT_DFH && !CSR_ADDR,

    // MMIO byte address size
    parameter MMIO_ADDR_WIDTH = ofs_fim_cfg_pkg::MMIO_ADDR_WIDTH_PG,

    parameter logic [63:0] GUID_H,
    parameter logic [63:0] GUID_L
    )
   (
    // Incoming host->AFU traffic
    pcie_ss_axis_if.sink   i_rx_if,
    // host->AFU traffic not handled by this module
    pcie_ss_axis_if.source o_rx_if,

    // Outbound AFU->host traffic, including MMIO read completions
    pcie_ss_axis_if.source o_tx_if,
    // Incoming AFU->host traffic from the AFU to be merged with completions
    // generated in this module.
    pcie_ss_axis_if.sink i_tx_if
    );

    localparam bit IS_PARENT = (NUM_CHILDREN > 0);

    // Size of the AFU feature. Child AFUs are v1 fixed size.
    // Parents are v1 with child GUIDs as a feature parameter.
    localparam FEATURE_BYTES = (IS_PARENT ? 'h30 + NUM_CHILDREN * 'h10 : 'h28);

    // Extend the AFU feature to a power of 2, defining the MMIO address space that
    // this module will handle. The power of 2 avoids addition in the address range
    // check.
    localparam FEATURE_ADDR_BITS = $clog2(FEATURE_BYTES);

    // synthesis translate_off
    initial
    begin
        if (NEXT_DFH != 0 && NEXT_DFH < (1 << $clog2(FEATURE_ADDR_BITS)))
        begin
            $fatal(2, "** ERROR ** %m: NEXT_DFH 0x%0h is too low! AFU feature ends at 0x%0h",
                   NEXT_DFH, 1 << $clog2(FEATURE_ADDR_BITS));
        end

        if (CSR_ADDR != 0 && CSR_ADDR < (1 << $clog2(FEATURE_ADDR_BITS)))
        begin
            $fatal(2, "** ERROR ** %m: CSR_ADDR 0x%0h is too low! AFU feature ends at 0x%0h",
                   CSR_ADDR, 1 << $clog2(FEATURE_ADDR_BITS));
        end

        if (CSR_SIZE != 0 && CSR_ADDR == 0)
        begin
            $fatal(2, "** ERROR ** %m: CSR_SIZE (0x%0h) is set but CSR_ADDR is zero!",
                   CSR_SIZE);
        end
    end
    // synthesis translate_on

    wire clk = i_rx_if.clk;
    wire rst_n = i_rx_if.rst_n;

    localparam TDATA_WIDTH = $bits(i_rx_if.tdata);
    localparam TUSER_WIDTH = $bits(i_rx_if.tuser_vendor);

    //
    // Consume FIM -> AFU RX stream in a skid buffer for timing
    //
    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) rx_st(clk, rst_n);
    ofs_fim_axis_pipeline i_rx_pipe(.clk, .rst_n, .axis_s(i_rx_if), .axis_m(rx_st));

    //
    // Combine MMIO read responses (AFU -> FIM) with AFU-generated TX
    // traffic in a MUX. tx_st[0] will have locally generated completions
    // and tx_st[1] from the AFU.
    //
    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) tx_st[2](clk, rst_n);


    //
    // Watch for MMIO read requests on the RX stream.
    //

    pcie_ss_hdr_pkg::PCIe_PUReqHdr_t rx_st_hdr_in;
    assign rx_st_hdr_in = pcie_ss_hdr_pkg::PCIe_PUReqHdr_t'(rx_st.tdata);

    // Register requests from incoming RX stream
    pcie_ss_hdr_pkg::PCIe_PUReqHdr_t rx_hdr;
    logic rx_hdr_valid;
    logic rx_sop;

    always_ff @(posedge clk)
    begin
        if (rx_st.tvalid && rx_st.tready)
            rx_sop <= rx_st.tlast;

        if (!rst_n)
            rx_sop <= 1'b1;
    end

    // MMIO request DW address (drop 2 low byte-level bits)
    wire [MMIO_ADDR_WIDTH-3 : 0] rx_in_dw_addr =
        pcie_ss_hdr_pkg::func_is_addr64(rx_st_hdr_in.fmt_type) ?
            (MMIO_ADDR_WIDTH-2)'({ rx_st_hdr_in.host_addr_h, rx_st_hdr_in.host_addr_l }) :
            (MMIO_ADDR_WIDTH-2)'(rx_st_hdr_in.host_addr_h[31:2]);

    // Is the address in the range managed here?
    wire rx_in_addr_is_feature = ~|(rx_in_dw_addr[MMIO_ADDR_WIDTH-3 : FEATURE_ADDR_BITS-2]);
    // Should the request be handled in this module?
    wire handle_rx_req = rx_sop && (HANDLE_ALL_MMIO_READS || rx_in_addr_is_feature) &&
                         pcie_ss_hdr_pkg::func_is_mrd_req(rx_st_hdr_in.fmt_type) &&
                         pcie_ss_hdr_pkg::func_hdr_is_pu_mode(rx_st.tuser_vendor);

    // Locally managed MMIO addresses
    logic [MMIO_ADDR_WIDTH-3 : 0] rx_hdr_dw_addr;
    logic rx_hdr_addr_is_feature;

    assign rx_st.tready = handle_rx_req ? !rx_hdr_valid : o_rx_if.tready;

    // Incoming MMIO read?
    always_ff @(posedge clk)
    begin
        if (rx_st.tvalid && handle_rx_req && !rx_hdr_valid)
        begin
            rx_hdr_valid <= 1'b1;
            rx_hdr <= rx_st_hdr_in;
            rx_hdr_dw_addr <= rx_in_dw_addr;
            rx_hdr_addr_is_feature <= rx_in_addr_is_feature;
        end
        else if (tx_st[0].tready)
        begin
            // If a request was present, it was consumed
            rx_hdr_valid <= 1'b0;
        end

        if (!rst_n)
        begin
            rx_hdr_valid <= 1'b0;
        end
    end

    // Construct MMIO completion in response to RX read request
    pcie_ss_hdr_pkg::PCIe_PUCplHdr_t tx_cpl_hdr;
    localparam TX_CPL_HDR_BYTES = $bits(pcie_ss_hdr_pkg::PCIe_PUCplHdr_t) / 8;

    always_comb
    begin
        // Build the header -- always the same for any address
        tx_cpl_hdr = '0;
        tx_cpl_hdr.fmt_type = pcie_ss_hdr_pkg::ReqHdr_FmtType_e'(pcie_ss_hdr_pkg::PCIE_FMTTYPE_CPLD);
        tx_cpl_hdr.length = rx_hdr.length;
        tx_cpl_hdr.req_id = rx_hdr.req_id;
        tx_cpl_hdr.tag_h = rx_hdr.tag_h;
        tx_cpl_hdr.tag_m = rx_hdr.tag_m;
        tx_cpl_hdr.tag_l = rx_hdr.tag_l;
        tx_cpl_hdr.TC = rx_hdr.TC;
        tx_cpl_hdr.byte_count = rx_hdr.length << 2;
        tx_cpl_hdr.low_addr[6:2] = rx_hdr_dw_addr[4:0];

        tx_cpl_hdr.comp_id = { rx_hdr.vf_num, rx_hdr.vf_active, rx_hdr.pf_num };
        tx_cpl_hdr.pf_num = rx_hdr.pf_num;
        tx_cpl_hdr.vf_num = rx_hdr.vf_num;
        tx_cpl_hdr.vf_active = rx_hdr.vf_active;
    end

    localparam FEATURE_NUM_8B_ENTRIES = (1 << FEATURE_ADDR_BITS) / 8;
    typedef bit [FEATURE_NUM_8B_ENTRIES-1 : 0][63 : 0] t_feature_rom;

    function automatic t_feature_rom init_child_feature_rom();
        t_feature_rom rom = '0;

        // AFU DFH
        // Feature type is AFU
        rom[0][63:60] = 4'h1;
        // DFH v1
        rom[0][59:52] = 8'h1;
        // End of list?
        rom[0][40] = (NEXT_DFH == 0);
        rom[0][39:16] = NEXT_DFH;
        // Child AFU ID
        rom[0][11:0] = 12'h1;

        // AFU_ID_L
        rom[1] = GUID_L;

        // AFU_ID_H
        rom[2] = GUID_H;

        // CSR offset and size
        rom[3] = CSR_ADDR;
        rom[4][63:32] = CSR_SIZE;

        return rom;
    endfunction // init_child_feature_rom

    function automatic t_feature_rom init_parent_feature_rom();
        // t_feature_rom may be too small if the AFU is a child, which will trigger
        // warnings even though this function isn't called. Define a rom that avoids
        // warnings.
        bit [6 + NUM_CHILDREN * 2 : 0][63:0] rom = '0;

        // AFU DFH
        // Feature type is AFU
        rom[0][63:60] = 4'h1;
        // DFH v1
        rom[0][59:52] = 8'h1;
        // End of list?
        rom[0][40] = (NEXT_DFH == 0);
        rom[0][39:16] = NEXT_DFH;

        // AFU_ID_L
        rom[1] = GUID_L;

        // AFU_ID_H
        rom[2] = GUID_H;

        // CSR offset and size
        rom[3] = CSR_ADDR;
        rom[4][63:32] = CSR_SIZE;

        // Feature has parameters
        rom[4][31] = 1'b1;

        // One parameter block -- the list of child GUIDs.
        // Size of parameter block (8 byte words)
        rom[5][63:35] = NUM_CHILDREN * 2 + 1;
        // EOP
        rom[5][32] = 1'b1;
        // Parameter ID (child AFUs).
        // See https://github.com/OFS/dfl-feature-id/blob/main/dfl-param-ids.rst
        rom[5][15:0] = 2;

        // Child GUID array
        for (int c = 0; c < NUM_CHILDREN; c += 1)
        begin
            rom[6 + 2*c] = CHILD_GUIDS[c][63:0];
            rom[7 + 2*c] = CHILD_GUIDS[c][127:64];
        end

        return t_feature_rom'(rom);
    endfunction // init_parent_feature_rom

    localparam t_feature_rom FEATURE_ROM =
        IS_PARENT ? init_parent_feature_rom() : init_child_feature_rom();

    // Completion data, loaded from FEATURE_ROM.
    logic [63:0] cpl_data;
    always_comb
    begin
        if (!rx_hdr_addr_is_feature)
            cpl_data = '0;
        else
        begin
            cpl_data = FEATURE_ROM[rx_hdr_dw_addr[1 +: FEATURE_ADDR_BITS-2]];

            // High 32 bit access?
            if (rx_hdr_dw_addr[0])
              cpl_data[31:0] = cpl_data[63:32];
        end
    end

    // Forward the completion to the AFU->host TX stream
    always_comb
    begin
        tx_st[0].tvalid = rx_hdr_valid &&
                          pcie_ss_hdr_pkg::func_is_mrd_req(rx_hdr.fmt_type);
        tx_st[0].tuser_vendor = '0;
        // TLP payload is the completion data and the header
        tx_st[0].tdata = { '0, cpl_data, tx_cpl_hdr };
        // Keep matches the data: either 8 or 4 bytes of data and the header
        tx_st[0].tkeep = { '0, {4{(rx_hdr.length > 1)}}, {4{1'b1}}, {TX_CPL_HDR_BYTES{1'b1}} };
        tx_st[0].tlast = 1'b1;
    end

    // Forward requests not handled here to AFU
    assign o_rx_if.tvalid = rx_st.tvalid && !handle_rx_req;
    assign o_rx_if.tuser_vendor = rx_st.tuser_vendor;
    assign o_rx_if.tdata = rx_st.tdata;
    assign o_rx_if.tkeep = rx_st.tkeep;
    assign o_rx_if.tlast = rx_st.tlast;

    // Merge AFU and local TX traffic
    assign i_tx_if.tready = tx_st[1].tready;
    assign tx_st[1].tvalid = i_tx_if.tvalid;
    assign tx_st[1].tuser_vendor = i_tx_if.tuser_vendor;
    assign tx_st[1].tdata = i_tx_if.tdata;
    assign tx_st[1].tkeep = i_tx_if.tkeep;
    assign tx_st[1].tlast = i_tx_if.tlast;

    pcie_ss_axis_mux
      #(
        .NUM_CH(2),
        .TDATA_WIDTH(TDATA_WIDTH),
        .TUSER_WIDTH(TUSER_WIDTH)
        )
      tx_mux
       (
        .clk,
        .rst_n,
        .sink(tx_st),
        .source(o_tx_if)
        );

endmodule // ofs_fim_pcie_multi_link_afu_dfh

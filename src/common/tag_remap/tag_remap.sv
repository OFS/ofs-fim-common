// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// tag_remap remaps tx read request tags to a unique tag to avoid duplication
// of the same tag value. When an FPGA function/unit sends out a cycle, it
// assigns a tag for tracking the cycle. However, there is no communication
// between units/functions, therefore two different units/functions may be
// using the same tag value. The PCIe host cannot accept duplicated tag value
// even when PF/VF are different. One easy method to uniquify tag values is to
// attach a unit/function ID to the upper tag field, but this results in the
// tags being evenly divided among units/functions. A unit can easily run out
// of tags and stall -- a performance issue. Instead, tag_remap intercepts the
// tag field and replaces it with a unique tag value for a read request. It
// also restores the original tag value when returning completions to the read
// requester.
//
// 1. A sub-module (ofs_fim_tag_pool) maintains a pool of available tags.
// 2. TX read requests are held up until a tag is available from the pool.
// 3. When a TX read is dispatched, the tag is marked busy in the pool.
// 4. The original tag is stored in tag_reg, so it can be recovered when returning
//    a completion to the unit/function.
// 5. Since completion to a read request can split into multiple smaller transfer
//    sizes, responses are monitored and the final completion is detected using PCIe
//    TLP rules.
// 6. Tags are released in the pool only when all requested data are transferred.
// 7. When the completion returns, the original tag is restored from tag_reg.
//
// The tag_remap_multi_tx() module below supports multiple parallel TX
// pipelines, all of which may pass read requests that need to be mapped.
// A typical FIM will either have 1 or 2 TX pipelines -- either a single
// shared stream or a dual-ported version where one port is used for
// read requests. The code here is general though, allowing for an
// arbitrary number of TX streams. Note, however, that at most one tag
// can be remapped per cycle. Since there is a single RX stream, using
// simple code for TX mapping causes no throughput loss.
//
//
// The AFU tag size may be different from the PCIe SS tag size managed here.
// The tag mapper accepts any tag up to ofs_pcie_ss_cfg_pkg::PCIE_EP_MAX_TAGS,
// independent of the PCIe specification and the dynamic state of the PCIe bus.
// The mapper will convert AFU tags into legal PCIe tags, perhaps in a larger
// space. AFU tags lower than 256 are permitted, even when attempting to generate
// 10 bit tags. The tag mapper will properly avoid 10 bit tags below 256 in
// order to conform to the PCIe specification.
//

`include "vendor_defines.vh"

module tag_remap #(
  // Remap Logic Enable
  parameter REMAP = 1,

  // By default, we set the pipeline depth of the outbound
  // TX port to 0, making the connection combinational.
  // Timing is met and it saves area and a cycle. On platforms
  // where timing is a problem, set this to 1.
  parameter TX_PL_DEPTH = 0,
  parameter RX_PL_DEPTH = 1
) (
  input                  clk,
  input                  rst_n,

  // Connect to host
  pcie_ss_axis_if.sink   ho2mx_rx_port,
  pcie_ss_axis_if.source mx2ho_tx_port,

  // Connect to PF/VF MUX
  pcie_ss_axis_if.source ho2mx_rx_remap,
  pcie_ss_axis_if.sink   mx2ho_tx_remap,

  // PCIe configuration (available tags)
  input  pcie_ss_axis_pkg::t_pcie_tag_mode tag_mode
  );

  // Map TX ports to vectors in order to use the multi-ported tag_remap below.
  pcie_ss_axis_if mx2ho_tx_port_vec[1](clk, rst_n);
  pcie_ss_axis_if mx2ho_tx_remap_vec[1](clk, rst_n);

  assign mx2ho_tx_port_vec[0].tready         = mx2ho_tx_port.tready;
  assign mx2ho_tx_port.tvalid                = mx2ho_tx_port_vec[0].tvalid;
  assign mx2ho_tx_port.tdata                 = mx2ho_tx_port_vec[0].tdata;
  assign mx2ho_tx_port.tlast                 = mx2ho_tx_port_vec[0].tlast;
  assign mx2ho_tx_port.tkeep                 = mx2ho_tx_port_vec[0].tkeep;
  assign mx2ho_tx_port.tuser_vendor          = mx2ho_tx_port_vec[0].tuser_vendor;

  assign mx2ho_tx_remap.tready               = mx2ho_tx_remap_vec[0].tready;
  assign mx2ho_tx_remap_vec[0].tvalid        = mx2ho_tx_remap.tvalid;
  assign mx2ho_tx_remap_vec[0].tdata         = mx2ho_tx_remap.tdata;
  assign mx2ho_tx_remap_vec[0].tlast         = mx2ho_tx_remap.tlast;
  assign mx2ho_tx_remap_vec[0].tkeep         = mx2ho_tx_remap.tkeep;
  assign mx2ho_tx_remap_vec[0].tuser_vendor  = mx2ho_tx_remap.tuser_vendor;

  tag_remap_multi_tx #(
    .REMAP(REMAP),
    .N_TX_PORTS(1),
    .TX_PL_DEPTH(TX_PL_DEPTH),
    .RX_PL_DEPTH(RX_PL_DEPTH))
  map(
    .clk,
    .rst_n,
    .ho2mx_rx_port,
    .mx2ho_tx_port(mx2ho_tx_port_vec),
    .ho2mx_rx_remap,
    .mx2ho_tx_remap(mx2ho_tx_remap_vec),
    .tag_mode);

endmodule

//
// Tag remapping with multiple TX streams, all of which are remapped.
//
module tag_remap_multi_tx #(
  // Remap Logic Enable
  parameter REMAP = 1,
  parameter N_TX_PORTS = 1,

  // By default, we set the pipeline depth of the outbound
  // TX port to 0, making the connection combinational.
  // Timing is met and it saves area and a cycle. On platforms
  // where timing is a problem, set this to 1.
  parameter TX_PL_DEPTH = 0,
  parameter RX_PL_DEPTH = 1
) (
  input                  clk,
  input                  rst_n,

  // Connect to host
  pcie_ss_axis_if.sink   ho2mx_rx_port,
  pcie_ss_axis_if.source mx2ho_tx_port[N_TX_PORTS],

  // Connect to PF/VF MUX
  pcie_ss_axis_if.source ho2mx_rx_remap,
  pcie_ss_axis_if.sink   mx2ho_tx_remap[N_TX_PORTS],

  // PCIe configuration (available tags)
  input  pcie_ss_axis_pkg::t_pcie_tag_mode tag_mode
  );

  import pcie_ss_hdr_pkg::*;

  // Number of tags in the AFU space. We allow AFUs to use any tag lower than
  // PCIE_EP_MAX_TAGS, even if those tag values would be illegal in true PCIe
  // 10 bit extended tag mode. (That mode uses tags between 256 and 1023.)
  // AFUs do not have to be concerned with the dynamic state of the PCIe HIP's
  // tag confinguration. The tag remapper will fix any mismatches.
  localparam             AFU_NUM_TAGS  = ofs_pcie_ss_cfg_pkg::PCIE_EP_MAX_TAGS;
  localparam             AFU_TAG_WIDTH = $clog2(AFU_NUM_TAGS);

  // Number of tags in the remap space. The AFU and SS spaces don't have to be
  // the same size. It doesn't cost much to have the FIM capable of using
  // all available tags supported by the HIP.
  localparam             SS_NUM_TAGS  = ofs_pcie_ss_cfg_pkg::PCIE_TILE_MAX_TAGS;
  localparam             SS_TAG_WIDTH = $clog2(SS_NUM_TAGS);

  // Signals from axis pipeline to be manipulated for tag replacement
  pcie_ss_axis_if        ho2mx_rx_in (clk, rst_n);
  pcie_ss_axis_if        mx2ho_tx_out[N_TX_PORTS](clk, rst_n);

  PCIe_CplHdr_t          rx_cmp_dm_hdr;
  PCIe_PUCplHdr_t        rx_cmp_pu_hdr;

  // SOP detection. 0 indicates stream is transmiting a packet.
  reg                    tx_sop_en[N_TX_PORTS];
  reg                    rx_sop_en;

  // Original tag looked up for rx completions
  reg [AFU_TAG_WIDTH-1:0] rx_prev_tag;
  reg [SS_TAG_WIDTH-1:0] rx_cmp_tag_q;
  reg                    rx_cmp_en_q;

  wire                rx_cmp_is_dm  = func_hdr_is_dm_mode(ho2mx_rx_port.tuser_vendor);
  assign              rx_cmp_dm_hdr = PCIe_CplHdr_t'(ho2mx_rx_port.tdata);
  assign              rx_cmp_pu_hdr = PCIe_PUCplHdr_t'(ho2mx_rx_port.tdata);
  wire                rx_cmp_dm_fc  = rx_cmp_dm_hdr.FC;
  wire                rx_cmp_pu_fc  =(rx_cmp_pu_hdr.length ==
                                    ((rx_cmp_pu_hdr.low_addr   & 3)        // PU final completion -length matches remaining-
                                    + rx_cmp_pu_hdr.byte_count + 3) >> 2); // -data rounded up to DWORDs
  // Final completion, format independent
  wire                   rx_cmp_fc  = rx_cmp_is_dm ? rx_cmp_dm_fc : rx_cmp_pu_fc;

  // Read request headers have identical tag and fmt_type layout in DM and PU
  // encoding, so we can use a single header type.
  PCIe_ReqHdr_t          mx2ho_tx_remap_hdr[N_TX_PORTS];
  PCIe_ReqHdr_t          mx2ho_tx_port_hdr[N_TX_PORTS];
  PCIe_ReqHdr_t          mx2ho_tx_out_hdr[N_TX_PORTS];
  logic [N_TX_PORTS-1:0] tx_sop;
  logic [N_TX_PORTS-1:0] tx_read;
  logic [N_TX_PORTS-1:0] tx_out_tready;
  logic [AFU_TAG_WIDTH-1:0] tx_old_tag[N_TX_PORTS];
  logic [AFU_TAG_WIDTH-1:0] tag_old;

  generate
    // Decode each of the TX ports
    for (genvar txp = 0; txp < N_TX_PORTS; txp = txp + 1) begin : tx_h
      assign mx2ho_tx_remap_hdr[txp] = PCIe_ReqHdr_t'(mx2ho_tx_remap[txp].tdata);
      assign mx2ho_tx_port_hdr[txp]  = PCIe_ReqHdr_t'(mx2ho_tx_port[txp].tdata);

      // TX start of packet
      assign tx_sop[txp]     = tx_sop_en[txp] & mx2ho_tx_remap[txp].tvalid;
      // All TX read requests
      assign tx_read[txp]    = tx_sop[txp] & (func_is_mrd_req(mx2ho_tx_remap_hdr[txp].fmt_type)
                                              | func_is_atomic_req(mx2ho_tx_remap_hdr[txp].fmt_type));

      assign tx_old_tag[txp] = AFU_TAG_WIDTH'({mx2ho_tx_remap_hdr[txp].tag_h, mx2ho_tx_remap_hdr[txp].tag_m, mx2ho_tx_remap_hdr[txp].tag_l});
      assign tx_out_tready[txp] = mx2ho_tx_out[txp].tready;
    end
  endgenerate

  // Get the mapped tag being returned on RX stream
  logic [SS_TAG_WIDTH-1:0]  rx_new_tag;
  always_comb begin
      rx_new_tag = rx_cmp_is_dm ?
                       SS_TAG_WIDTH'(rx_cmp_dm_hdr.tag) :
                       SS_TAG_WIDTH'({rx_cmp_pu_hdr.tag_h, rx_cmp_pu_hdr.tag_m, rx_cmp_pu_hdr.tag_l});

      // In 10 bit mode, PCIe disallows tags in the range 0-255. The TX code later
      // in the file maps 0-255 either to 512-767 (when the PCIe SS accepts only 512
      // total tags) or to 768-1023. For 512-768, we don't have to do anything
      // special to handle this transformation for returning read response tags.
      // With only 512 tags in use, the high bit of the tag can be ignored
      // and the tag mapper logic will see values in the range 0-511.
      //
      // With 768 active tags, 768-1023 must be mapped back to 0-255.
      if ((SS_TAG_WIDTH == 10) && tag_mode.tag_10bit) begin
          if (&rx_new_tag[SS_TAG_WIDTH-2 +: 2]) begin
              rx_new_tag[SS_TAG_WIDTH-2 +: 2] = 2'b0;
          end
      end
  end

  // RX start of packet
  wire         rx_sop =  rx_sop_en  & ho2mx_rx_port.tvalid;
  // RX CplD (format is the same for both DM and PU)
  wire         rx_cmp =  rx_sop     & func_is_completion(rx_cmp_dm_hdr.fmt_type)
                                    & func_has_data(rx_cmp_dm_hdr.fmt_type);

  // Request a new tag from the pool
  logic                  alloc_tx_tag[N_TX_PORTS];
  logic                  alloc_tag;
  // A new tag is available from the pool
  logic                  new_tag_avail;
  // Requested remapped tag value
  logic [SS_TAG_WIDTH-1:0] new_alloc_tag;

  // Only one TX port can have a tag mapped in a given cycle. Reads are
  // ultimately limited to one per cycle anyway by both the single RX
  // pipeline for completions and by the PCIe subsystem, which has a
  // single read request pipeline. This arbiter choses which TX stream
  // to map.
  logic [$clog2(N_TX_PORTS == 1 ? 2 : N_TX_PORTS)-1:0] tx_read_arb_idx;
  logic [N_TX_PORTS-1:0]   tx_read_arb_1hot;
  logic                    tx_read_arb_valid;

  ofs_fim_fair_arbiter #(
    .NUM_INPUTS(N_TX_PORTS))
   tx_arb(
    .clk,
    .reset_n(rst_n),
    .in_valid(tx_read & tx_out_tready & {N_TX_PORTS{new_tag_avail}}),
    .hold_priority('0),
    .out_select(tx_read_arb_idx),
    .out_select_1hot(tx_read_arb_1hot),
    .out_valid(tx_read_arb_valid));

  assign tag_old = tx_old_tag[tx_read_arb_idx];
  assign alloc_tag = alloc_tx_tag[tx_read_arb_idx];

  generate
    for (genvar txp = 0; txp < N_TX_PORTS; txp = txp + 1) begin : tx
      always_comb begin
        // Connect pf_vf_mux to axis pipeline
        mx2ho_tx_remap[txp].tready      = mx2ho_tx_out[txp].tready;
        mx2ho_tx_out[txp].tvalid        = mx2ho_tx_remap[txp].tvalid;
        mx2ho_tx_out[txp].tdata         = mx2ho_tx_remap[txp].tdata;
        mx2ho_tx_out[txp].tlast         = mx2ho_tx_remap[txp].tlast;
        mx2ho_tx_out[txp].tkeep         = mx2ho_tx_remap[txp].tkeep;
        mx2ho_tx_out[txp].tuser_vendor  = mx2ho_tx_remap[txp].tuser_vendor;
        mx2ho_tx_out_hdr[txp]           = PCIe_ReqHdr_t'(mx2ho_tx_remap[txp].tdata);
        alloc_tx_tag[txp]               = 0;

        if (REMAP) begin
          // Map TX read requests
          if (tx_read[txp]) begin
            mx2ho_tx_out[txp].tvalid   = 0;
            mx2ho_tx_remap[txp].tready = 0;

            if (tx_read_arb_valid & tx_read_arb_1hot[txp]) begin
              // New tag consumed from tag pool
              alloc_tx_tag[txp]          = mx2ho_tx_out[txp].tready;
              mx2ho_tx_out[txp].tvalid   = mx2ho_tx_remap[txp].tvalid;
              mx2ho_tx_remap[txp].tready = mx2ho_tx_out[txp].tready;
            end

            // Replace tag. This can be unconditional since tvalid will be
            // true only if new_tag_avail.
            {mx2ho_tx_out_hdr[txp].tag_h, mx2ho_tx_out_hdr[txp].tag_m, mx2ho_tx_out_hdr[txp].tag_l} = {'0, new_alloc_tag};
            // In 10 bit tag mode, the PCIe spec. does not permit tags below
            // 256. In 5 and 8 bit modes, tags begin at 0. The tag allocator
            // (new_alloc_tag) uses a dense numbering space starting with 0,
            // even in 10 bit mode. In 10 bit mode, we must map tags 0-255
            // to higher values.
            if (tag_mode.tag_10bit) begin
                if (SS_TAG_WIDTH < 10) begin
                    // The SS-side tag space is <= 512 tags. We take advantage of
                    // of this and simply set bit 9 (tag_h) when bit 8 (tag_m)
                    // is zero, thus mapping 0-255 to 512-767 and leaving 256-511 alone.
                    mx2ho_tx_out_hdr[txp].tag_h = ~mx2ho_tx_out_hdr[txp].tag_m;
                end
                else begin
                    // The SS tag space is the full 768 possible tags. Map tags
                    // in the range 0-255 to 768-1023.
                    if (!(mx2ho_tx_out_hdr[txp].tag_h | mx2ho_tx_out_hdr[txp].tag_m)) begin
                        mx2ho_tx_out_hdr[txp].tag_h = 1'b1;
                        mx2ho_tx_out_hdr[txp].tag_m = 1'b1;
                    end
                end
            end
          end

          // Updated TX header, possibly with mapped tag
          mx2ho_tx_out[txp].tdata[0 +: $bits(PCIe_ReqHdr_t)] = mx2ho_tx_out_hdr[txp];
        end
      end
    end
  endgenerate

  always_comb begin
    // Connect axis pipeline to host
    ho2mx_rx_port.tready       = ho2mx_rx_in.tready;
    ho2mx_rx_in.tvalid         = ho2mx_rx_port.tvalid;
    ho2mx_rx_in.tdata          = ho2mx_rx_port.tdata;
    ho2mx_rx_in.tlast          = ho2mx_rx_port.tlast;
    ho2mx_rx_in.tkeep          = ho2mx_rx_port.tkeep;
    ho2mx_rx_in.tuser_vendor   = ho2mx_rx_port.tuser_vendor;

    if (REMAP) begin
      // If RX packet is a completion header restore old tag value. Use bit
      // offsets into tdata since dealing with two overlayed header types
      // for DM and PU is messy.
      if (rx_cmp) begin
        if (rx_cmp_is_dm) begin
          // DM encoding (hdr.tag)
          ho2mx_rx_in.tdata[127:118] = {'0, rx_prev_tag};
        end
        else begin
          // PU encoding (hdr.tag_h, hdr.tag_m, hdr.tag_l)
          {ho2mx_rx_in.tdata[23], ho2mx_rx_in.tdata[19], ho2mx_rx_in.tdata[79:72]} = {'0, rx_prev_tag};
        end
      end
    end
  end

  // Free tags when completions arrive
  always_ff @(posedge clk) begin
    rx_cmp_en_q  <= rx_cmp & ho2mx_rx_port.tready & rx_cmp_fc;
    rx_cmp_tag_q <= rx_new_tag;

    if (!rst_n)
    begin
      rx_cmp_en_q <= 1'b0;
    end
  end

  // Track SOP in for both TX and RX streams
  generate
    for (genvar txp = 0; txp < N_TX_PORTS; txp = txp + 1) begin : tx_track_sop
      always_ff @(posedge clk) begin
        if (mx2ho_tx_remap[txp].tvalid & mx2ho_tx_remap[txp].tready) begin
          tx_sop_en[txp] <= mx2ho_tx_remap[txp].tlast;
        end

        if (!rst_n) begin
          tx_sop_en[txp] <= 1;
        end
      end
    end
  endgenerate

  always_ff @(posedge clk) begin
    if (ho2mx_rx_port.tvalid & ho2mx_rx_port.tready) begin
      rx_sop_en <= ho2mx_rx_port.tlast;
    end

    if (!rst_n) begin
      rx_sop_en <= 1;
    end
  end

  //
  // Tag map-back memory
  //
  ram_1r1w #(
               .DEPTH       ( SS_TAG_WIDTH  ),
               .WIDTH       ( AFU_TAG_WIDTH ),
               .GRAM_MODE   ( 0             ),
               .GRAM_STYLE  ( `GRAM_DIST    ))
    tag_reg    (
               .clk         ( clk           ),

               // Record old tag during TX replacement
               .we          ( alloc_tag     ),
               .waddr       ( new_alloc_tag ),
               .din         ( tag_old       ),

               // Read back original tag for RX completion
               .re          ( 1'b1          ),
               .raddr       ( rx_new_tag    ),
               .dout        ( rx_prev_tag   ),
               .perr        (               ));

  //
  // Remapping tag pool
  //
  ofs_fim_tag_pool #(
               .N_ENTRIES   ( SS_NUM_TAGS   ))
    tag_pool   (
               .clk         ( clk           ),
               .rst_n       ( rst_n         ),

               .tag_mode    ( tag_mode      ),  // PCIe SS dynamic tag mode

               .alloc       ( alloc_tag     ),  // Input: allocate a new tag?
               .alloc_ready ( new_tag_avail ),  // Output: new tag available?
               .alloc_uid   ( new_alloc_tag ),  // Output: new remapped tag

               .free        ( rx_cmp_en_q   ),  // Input: release a tag
               .free_uid    ( rx_cmp_tag_q  ));

  //
  // AXIS Pipeline Instantiation
  //
  generate
    // Decode each of the TX ports
    for (genvar txp = 0; txp < N_TX_PORTS; txp = txp + 1) begin : tx_pipe
      ofs_fim_axis_pipeline #(
                   .PL_DEPTH    ( TX_PL_DEPTH        ),
                   .TDATA_WIDTH ( ofs_pcie_ss_cfg_pkg::TDATA_WIDTH ),
                   .TUSER_WIDTH ( ofs_pcie_ss_cfg_pkg::TUSER_WIDTH ))
        tx_axis_pipe  (
                   .clk         ( clk                ),
                   .rst_n       ( rst_n              ),
                   .axis_s      ( mx2ho_tx_out[txp]  ),
                   .axis_m      ( mx2ho_tx_port[txp] ));
    end
  endgenerate

  ofs_fim_axis_pipeline #(
               .PL_DEPTH    ( RX_PL_DEPTH   ),
               .TDATA_WIDTH ( ofs_pcie_ss_cfg_pkg::TDATA_WIDTH ),
               .TUSER_WIDTH ( ofs_pcie_ss_cfg_pkg::TUSER_WIDTH ))
   rx_axis_pipe  (
               .clk         ( clk           ),
               .rst_n       ( rst_n         ),
               .axis_s      ( ho2mx_rx_in   ),
               .axis_m      ( ho2mx_rx_remap));



  //
  // Log all inbound and outbound traffic to a file.
  //

  // synthesis translate_off

  logic mx2ho_tx_port_sop[N_TX_PORTS];
  logic ho2mx_rx_remap_sop;

  generate
    for (genvar txp = 0; txp < N_TX_PORTS; txp = txp + 1) begin : tx_port_sop
      always_ff @(posedge clk) begin
        if (mx2ho_tx_port[txp].tvalid & mx2ho_tx_port[txp].tready) begin
          mx2ho_tx_port_sop[txp] <= mx2ho_tx_port[txp].tlast;
        end

        if (!rst_n) begin
          mx2ho_tx_port_sop[txp] <= 1'b1;
        end
      end
    end
  endgenerate

  always_ff @(posedge clk) begin
    if (ho2mx_rx_remap.tvalid & ho2mx_rx_remap.tready) begin
      ho2mx_rx_remap_sop <= ho2mx_rx_remap.tlast;
    end

    if (!rst_n) begin
      ho2mx_rx_remap_sop <= 1'b1;
    end
  end

  int log_fd;

  initial
  begin : log
    log_fd = $fopen("log_ofs_fim_tag_remap.tsv", "w");

    // Write module hierarchy to the top of the log
    $fwrite(log_fd, "tag_remap.sv: %m\n\n");

    forever @(posedge clk) begin
      if(rst_n && ho2mx_rx_port.tvalid && ho2mx_rx_port.tready)
      begin
        $fwrite(log_fd, "RX_IN:    %s\n",
                pcie_ss_pkg::func_pcie_ss_flit_to_string(
                  rx_sop_en, ho2mx_rx_port.tlast,
                  pcie_ss_hdr_pkg::func_hdr_is_pu_mode(ho2mx_rx_port.tuser_vendor),
                  ho2mx_rx_port.tdata, ho2mx_rx_port.tkeep));
        $fflush(log_fd);
      end

      if(rst_n && ho2mx_rx_remap.tvalid && ho2mx_rx_remap.tready)
      begin
        $fwrite(log_fd, "RX_OUT:   %s\n",
                pcie_ss_pkg::func_pcie_ss_flit_to_string(
                  ho2mx_rx_remap_sop, ho2mx_rx_remap.tlast,
                  pcie_ss_hdr_pkg::func_hdr_is_pu_mode(ho2mx_rx_remap.tuser_vendor),
                  ho2mx_rx_remap.tdata, ho2mx_rx_remap.tkeep));
        $fflush(log_fd);
      end
    end
  end

  generate
    for (genvar txp = 0; txp < N_TX_PORTS; txp = txp + 1) begin : tx_dbg
      initial
      forever @(posedge clk) begin
        if(rst_n && mx2ho_tx_remap[txp].tvalid && mx2ho_tx_remap[txp].tready)
        begin
          $fwrite(log_fd, "TX_IN_%0d:  %s\n", txp,
                  pcie_ss_pkg::func_pcie_ss_flit_to_string(
                    tx_sop_en[txp], mx2ho_tx_remap[txp].tlast,
                    pcie_ss_hdr_pkg::func_hdr_is_pu_mode(mx2ho_tx_remap[txp].tuser_vendor),
                    mx2ho_tx_remap[txp].tdata, mx2ho_tx_remap[txp].tkeep));
          $fflush(log_fd);
        end

        if(rst_n && mx2ho_tx_port[txp].tvalid && mx2ho_tx_port[txp].tready)
        begin
          $fwrite(log_fd, "TX_OUT_%0d: %s\n", txp,
                  pcie_ss_pkg::func_pcie_ss_flit_to_string(
                    mx2ho_tx_port_sop[txp], mx2ho_tx_port[txp].tlast,
                    pcie_ss_hdr_pkg::func_hdr_is_pu_mode(mx2ho_tx_port[txp].tuser_vendor),
                    mx2ho_tx_port[txp].tdata, mx2ho_tx_port[txp].tkeep));
          $fflush(log_fd);
        end
      end
    end
  endgenerate

  // synthesis translate_on

endmodule

// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

//
// Respond to PCIe address translation service invalidation requests. This
// module can be used on functions that have ATS enabled but don't cache
// translations.
//

`include "ofs_ip_cfg_db.vh"

// Old boards (d5005) don't have the PCIe IP database needed to drive
// this module. They also don't need the module.
`ifdef OFS_FIM_IP_CFG_PCIE_SS_NUM_PFS

//
// Wrapper module: generate logic for completions only when ATS is enabled.
//
module ofs_fim_pcie_ats_inval_cpl
  #(
    parameter TDATA_WIDTH = ofs_pcie_ss_cfg_pkg::TDATA_WIDTH,
    parameter TUSER_WIDTH = ofs_pcie_ss_cfg_pkg::TUSER_WIDTH,

    // Parameters describing the functions configured with ATS capability, both
    // physical and virtual. Default values come from the primary PCIe interface.
    parameter logic ATS_ENABLED =
`ifdef OFS_FIM_IP_CFG_PCIE_SS_ATS_CAP
                                  1,
`else
                                  0,
`endif
    parameter NUM_PFS = top_cfg_pkg::MAX_PF_NUM + 1,
    parameter int PF_NUM_VFS_VEC[NUM_PFS] = top_cfg_pkg::PF_NUM_VFS_VEC,
    parameter logic PF_ATS_ENABLED[NUM_PFS] = '{ `OFS_FIM_IP_CFG_PCIE_SS_ATS_CAP_VEC },
    parameter logic VF_ATS_ENABLED[NUM_PFS] = '{ `OFS_FIM_IP_CFG_PCIE_SS_VF_ATS_CAP_VEC }
    )
   (
    input wire clk,
    input wire rst_n,
    // Clocks for pcie_flr_req
    input wire clk_csr,
    input wire rst_n_csr,

    // Function-level reset requests, used to reenable ATS invalidation responses
    // until an ATS request is seen from an AFU. No FLR response is generated
    // here.
    input pcie_ss_axis_pkg::t_axis_pcie_flr pcie_flr_req,

    // FIM to host
    pcie_ss_axis_if.source o_tx_if,
    // Host to FIM commands
    pcie_ss_axis_if.sink   i_rxreq_if,

    // AFU to host. ATS completions will be merged into this.
    pcie_ss_axis_if.sink   i_tx_if,
    // Host to AFU commands. ATS requests will be filtered
    // out of this.
    pcie_ss_axis_if.source o_rxreq_if
    );


    generate
        if (!ATS_ENABLED) begin : no_ats
            //
            // ATS is not enabled on any function. Simply wire the TLP streams
            // together and do nothing else.
            //
            ofs_fim_axis_pipeline
              #(
                .PL_DEPTH(0)
                )
              tx
               (
                .clk,
                .rst_n,
                .axis_s(i_tx_if),
                .axis_m(o_tx_if)
                );

            ofs_fim_axis_pipeline
              #(
                .PL_DEPTH(0)
                )
              rxreq
               (
                .clk,
                .rst_n,
                .axis_s(i_rxreq_if),
                .axis_m(o_rxreq_if)
                );
        end
        else begin : with_ats
            //
            // ATS is enabled on at least one function. Generate completions.
            //
            ofs_fim_pcie_ats_inval_cpl_impl
              #(
                .TDATA_WIDTH(TDATA_WIDTH),
                .TUSER_WIDTH(TUSER_WIDTH),
                .ATS_ENABLED(ATS_ENABLED),
                .NUM_PFS(NUM_PFS),
                .PF_NUM_VFS_VEC(PF_NUM_VFS_VEC),
                .PF_ATS_ENABLED(PF_ATS_ENABLED),
                .VF_ATS_ENABLED(VF_ATS_ENABLED)
                )
              cpl
               (
                .clk,
                .rst_n,
                .clk_csr,
                .rst_n_csr,
                .pcie_flr_req,
                .o_tx_if,
                .i_rxreq_if,
                .i_tx_if,
                .o_rxreq_if
                );
        end
    endgenerate

endmodule // ofs_fim_pcie_ats_inval_cpl


//
// The real ATS completion implementation.
//
module ofs_fim_pcie_ats_inval_cpl_impl
  #(
    // No defaults. Values come from ofs_fim_pcie_ats_inval_cpl() above.
    parameter TDATA_WIDTH,
    parameter TUSER_WIDTH,
    parameter logic ATS_ENABLED,
    parameter NUM_PFS,
    parameter int PF_NUM_VFS_VEC[NUM_PFS],
    parameter logic PF_ATS_ENABLED[NUM_PFS],
    parameter logic VF_ATS_ENABLED[NUM_PFS]
    )
   (
    input wire clk,
    input wire rst_n,
    // Clocks for pcie_flr_req
    input wire clk_csr,
    input wire rst_n_csr,

    // Function-level reset requests, used to reenable ATS invalidation responses
    // until an ATS request is seen from an AFU. No FLR response is generated
    // here.
    input pcie_ss_axis_pkg::t_axis_pcie_flr pcie_flr_req,

    // FIM to host
    pcie_ss_axis_if.source o_tx_if,
    // Host to FIM commands
    pcie_ss_axis_if.sink   i_rxreq_if,

    // AFU to host. ATS completions will be merged into this.
    pcie_ss_axis_if.sink   i_tx_if,
    // Host to AFU commands. ATS requests will be filtered
    // out of this.
    pcie_ss_axis_if.source o_rxreq_if
    );

    // ====================================================================
    // 
    //  Map FLR to bit vectors, one for PFs and one for VFs, using the
    //  standard FIM module.
    //
    // ====================================================================

    // Compute largest number of VFs associated with any PF.
    function automatic int getNumVFs();
        int m = 0;
        for (int p = 0; p < NUM_PFS; ++p) begin
            if (PF_NUM_VFS_VEC[p] > m)
                m = PF_NUM_VFS_VEC[p];
        end
        return m;
    endfunction

    localparam NUM_VFS = getNumVFs();

    typedef logic [$clog2(NUM_PFS)-1 : 0] t_pf_idx;
    typedef logic [$clog2(NUM_VFS)-1 : 0] t_vf_idx;

    // Resets in clk domain, derived from pcie_flr_req
    logic [NUM_PFS-1:0] pf_flr_rst_n;
    logic [NUM_PFS-1:0][NUM_VFS-1:0] vf_flr_rst_n_in;
    logic [NUM_PFS-1:0][NUM_VFS-1:0] vf_flr_rst_n;

    flr_rst_mgr
      #(
        .NUM_PF(NUM_PFS),
        .NUM_VF(NUM_VFS)
        )
      rst_mgr
       (
        .clk_sys(clk),
        .rst_n_sys(rst_n),
        .clk_csr,
        .rst_n_csr,
        .pcie_flr_req,
        .pcie_flr_rsp(),
        .pf_flr_rst_n,
        .vf_flr_rst_n(vf_flr_rst_n_in)
        );

    // Trigger VF reset when parent PF in reset
    always_ff @(posedge clk) begin
        for (int p = 0; p < NUM_PFS; ++p) begin
            for (int v = 0; v < NUM_VFS; ++v) begin
                vf_flr_rst_n[p][v] <= vf_flr_rst_n_in[p][v] && pf_flr_rst_n[p];
            end
        end
    end


    // ====================================================================
    // 
    //  Monitor the AFU TX stream, looking for PCIe ATS requests. If a
    //  request is seen, stop responding for that function to ATS
    //  invalidation. Instead, it is assumed that the AFU has a translation
    //  cache and handled will be sent to the AFU.
    //
    //  ATS invalidation handling is turned back on when a FLR is seen.
    // 
    // ====================================================================

    logic [NUM_PFS-1:0] pf_ats_inval_disable;
    logic [NUM_PFS-1:0][NUM_VFS-1:0] vf_ats_inval_disable;

    pcie_ss_hdr_pkg::PCIe_PUReqHdr_t o_tx_hdr;
    assign o_tx_hdr = pcie_ss_hdr_pkg::PCIe_PUReqHdr_t'(o_tx_if.tdata);
    logic o_tx_sop;

    // Is o_tx_if an address translation request from the AFU?
    wire o_tx_is_ats_req =
         o_tx_if.tvalid && o_tx_if.tready &&
         o_tx_sop &&
         pcie_ss_hdr_pkg::func_hdr_is_pu_mode(o_tx_if.tuser_vendor) &&
         pcie_ss_hdr_pkg::func_is_mrd_req(o_tx_hdr.fmt_type) &&
         o_tx_hdr.attr.AT[0];

    always_ff @(posedge clk) begin
        // On FLR, reenable ATS invalidation
        pf_ats_inval_disable <= pf_ats_inval_disable & pf_flr_rst_n;
        vf_ats_inval_disable <= vf_ats_inval_disable & vf_flr_rst_n;

        if (o_tx_is_ats_req) begin
            // Disable ATS invalidation from this module for any function
            // that makes an ATS request. The function becomes responsible
            // for invalidation responses.
            if (o_tx_hdr.vf_active)
                vf_ats_inval_disable[t_pf_idx'(o_tx_hdr.pf_num)][t_vf_idx'(o_tx_hdr.vf_num)] <= 1'b1;
            else
                pf_ats_inval_disable[t_pf_idx'(o_tx_hdr.pf_num)] <= 1'b1;
        end

        // Force ports that don't have ATS capability to 0. Quartus
        // should drop most of the logic driving them as a result.
        for (int p = 0; p < NUM_PFS; ++p) begin
            if (!PF_ATS_ENABLED[p])
                pf_ats_inval_disable[p] <= 1'b0;

            for (int v = 0; v < NUM_VFS; ++v) begin
                if ((v >= PF_NUM_VFS_VEC[p]) || !PF_ATS_ENABLED[p] || !VF_ATS_ENABLED[p])
                    vf_ats_inval_disable[p][v] <= 1'b0;
            end
        end

        if (!rst_n) begin
            pf_ats_inval_disable <= '0;
            vf_ats_inval_disable <= '0;
        end
    end

    always_ff @(posedge clk) begin
        if (o_tx_if.tvalid && o_tx_if.tready)
            o_tx_sop <= o_tx_if.tlast;

        if (!rst_n)
            o_tx_sop <= 1'b1;
    end


    // Inputs to the TX MUX that merges the main TX stream and ATS invalidation
    // completions.
    pcie_ss_axis_if#(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) tx_mux_in[2](.clk, .rst_n);

    // Storage for a pending ATS invalidation
    logic ats_inval_req_valid;
    pcie_ss_hdr_pkg::PCIe_PUMsgHdr_t ats_inval_req;

    pcie_ss_hdr_pkg::PCIe_PUMsgHdr_t rxreq_msg_hdr;
    assign rxreq_msg_hdr = pcie_ss_hdr_pkg::PCIe_PUMsgHdr_t'(i_rxreq_if.tdata);

    // Detect ATS invalidation request messages
    logic rxreq_is_sop;
    wire rxreq_is_ats_inval =
         rxreq_is_sop &&
         pcie_ss_hdr_pkg::func_hdr_is_pu_mode(i_rxreq_if.tuser_vendor) &&
         pcie_ss_hdr_pkg::func_is_msg(rxreq_msg_hdr.fmt_type) &&
         (rxreq_msg_hdr.msg_code == pcie_ss_hdr_pkg::PCIE_MSGCODE_ATS_INVAL_REQ);

    wire rxreq_ats_inval_disabled =
         (rxreq_msg_hdr.vf_active ? 
             vf_ats_inval_disable[t_pf_idx'(rxreq_msg_hdr.pf_num)][t_vf_idx'(rxreq_msg_hdr.vf_num)] :
             pf_ats_inval_disable[t_pf_idx'(rxreq_msg_hdr.pf_num)]);

    wire rxreq_handle_ats_inval = rxreq_is_ats_inval && !rxreq_ats_inval_disabled;

    always_ff @(posedge clk) begin
        if (i_rxreq_if.tvalid && i_rxreq_if.tready)
            rxreq_is_sop <= i_rxreq_if.tlast;

        if (!rst_n)
            rxreq_is_sop <= 1'b1;
    end

    // Route requests either to the AFU or to ATS invalidation commit
    assign i_rxreq_if.tready =
        rxreq_handle_ats_inval ? !ats_inval_req_valid :
                                 (o_rxreq_if.tready || !o_rxreq_if.tvalid);

    // Normal requests (not ATS)
    always_ff @(posedge clk) begin
        if (o_rxreq_if.tready || !o_rxreq_if.tvalid) begin
            o_rxreq_if.tvalid <= i_rxreq_if.tvalid && !rxreq_handle_ats_inval;

            o_rxreq_if.tlast <= i_rxreq_if.tlast;
            o_rxreq_if.tdata <= i_rxreq_if.tdata;
            o_rxreq_if.tuser_vendor <= i_rxreq_if.tuser_vendor;
            o_rxreq_if.tkeep <= i_rxreq_if.tkeep;
        end

        if (!rst_n)
            o_rxreq_if.tvalid <= 1'b0;
    end

    // Invalidation requests
    always_ff @(posedge clk) begin
        if (tx_mux_in[1].tready) begin
            ats_inval_req_valid <= 1'b0;
        end

        if (i_rxreq_if.tvalid && rxreq_handle_ats_inval && !ats_inval_req_valid) begin
            ats_inval_req_valid <= 1'b1;
            ats_inval_req <= rxreq_msg_hdr;
        end

        if (!rst_n) begin
            ats_inval_req_valid <= 1'b0;
        end
    end

    // AFU TX stream
    assign tx_mux_in[0].tvalid = i_tx_if.tvalid;
    assign i_tx_if.tready = tx_mux_in[0].tready;
    always_comb begin
        tx_mux_in[0].tlast = i_tx_if.tlast;
        tx_mux_in[0].tdata = i_tx_if.tdata;
        tx_mux_in[0].tuser_vendor = i_tx_if.tuser_vendor;
        tx_mux_in[0].tkeep = i_tx_if.tkeep;
    end

    // ATS completions are just a header
    pcie_ss_hdr_pkg::PCIe_PUMsgHdr_t ats_inval_cpl;
    always_comb begin
        ats_inval_cpl = '0;

        // No data
        ats_inval_cpl.fmt_type = ats_inval_req.fmt_type;
        ats_inval_cpl.fmt_type[6] = 1'b0;

        { ats_inval_cpl.attr_h, ats_inval_cpl.attr_l } = { ats_inval_req.attr_h, ats_inval_req.attr_l };
        ats_inval_cpl.EP = ats_inval_req.EP;
        ats_inval_cpl.TD = ats_inval_req.TD;
        ats_inval_cpl.TC = ats_inval_req.TC;

        ats_inval_cpl.msg_code = pcie_ss_hdr_pkg::PCIE_MSGCODE_ATS_INVAL_CPL;
        // Completion req_id from the target of the invalidation request
        ats_inval_cpl.req_id = ats_inval_req.msg1[31:16];
        // Target Device ID -- source of the request
        ats_inval_cpl.msg1[31:16] = ats_inval_req.req_id;
        // Completion count (single message)
        ats_inval_cpl.msg1[2:0] = 3'd1;

        // ITag vector
        ats_inval_cpl.msg2[ats_inval_req.msg0[4:0]] = 1'b1;

        ats_inval_cpl.pf_num = ats_inval_req.pf_num;
        ats_inval_cpl.vf_num = ats_inval_req.vf_num;
        ats_inval_cpl.vf_active = ats_inval_req.vf_active;
    end

    assign tx_mux_in[1].tvalid = ats_inval_req_valid;
    always_comb begin
        tx_mux_in[1].tlast = 1'b1;
        tx_mux_in[1].tdata = { '0, ats_inval_cpl };
        tx_mux_in[1].tuser_vendor = '0;
        tx_mux_in[1].tkeep = { '0, {32{1'b1}} };
    end

    pcie_ss_axis_mux
      #(
        .NUM_CH(2)
        )
      tx_mux
       (
        .clk,
        .rst_n,
        .sink(tx_mux_in),
        .source(o_tx_if)
        );

endmodule // ofs_fim_pcie_ats_inval_cpl_impl

`endif //  `ifdef OFS_FIM_IP_CFG_PCIE_SS_NUM_PFS

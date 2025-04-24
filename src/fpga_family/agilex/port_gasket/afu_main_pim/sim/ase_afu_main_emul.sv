// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT

//
// Platform-specific afu_main() wrapper for emulation with ASE. When the PCIe SS
// is present, ASE provides PCIe SS emulation as an input.
//

// OPAE_PLATFORM_GEN is set when a script is generating the PR build environment
// used with OPAE SDK tools. When set, afu_main acts as a simple template that
// defines the module but doesn't include an actual AFU.
`ifndef OPAE_PLATFORM_GEN

`include "ofs_plat_if.vh"
`include "ofs_ip_cfg_db.vh"

module ase_afu_main_emul
  #(
    parameter PG_NUM_PORTS = 1
    )
   (
    input  logic pClk,
    input  logic pClkDiv2,
    input  logic pClkDiv4,
    input  logic uClk_usr,
    input  logic uClk_usrDiv2,
    input  logic softReset,

    // Emulation of the PCIe SS is provided by ASE core services
    pcie_ss_axis_if.source        afu_axi_tx_a_if,
    pcie_ss_axis_if.sink          afu_axi_rx_a_if,
    pcie_ss_axis_if.source        afu_axi_tx_b_if,
    pcie_ss_axis_if.sink          afu_axi_rx_b_if
    );

    // ====================================================================
    //
    //  PCIe
    //
    // ====================================================================

`ifdef OFS_FIM_IP_CFG_PCIE_SS_NUM_LINKS
    // Actual number of PCIe links on the platform
    localparam NUM_LINKS = `OFS_FIM_IP_CFG_PCIE_SS_NUM_LINKS;
`else
    localparam NUM_LINKS = 1;
`endif

    // Incoming PG_NUM_PORTS is across all links. Convert to ports per link.
    localparam NUM_PORTS = PG_NUM_PORTS / NUM_LINKS;

    // Map the PF/VF association of AFU ports to the parameters that will be
    // passed to the port gasket.
    typedef pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t[NUM_PORTS-1:0] t_afu_pf_vf_info;
    function automatic t_afu_pf_vf_info gen_afu_pf_vf_info();
        t_afu_pf_vf_info info;

        // For simulation, we just pick a collection of VFs associated with a PF.
        for (int p = 0; p < NUM_PORTS; p = p + 1) begin
            info[p].pf_num = 0;
            info[p].vf_num = p;
            info[p].vf_active = 1'b1;
            info[p].link_num = 0;
        end

        return info;
    endfunction // gen_afu_pf_vf_info

    localparam t_afu_pf_vf_info PORT_PF_VF_INFO = gen_afu_pf_vf_info();

    typedef pf_vf_mux_pkg::t_pfvf_rtable_entry[NUM_PORTS-1:0] t_afu_pf_vf_rtable;
    function automatic t_afu_pf_vf_rtable gen_afu_pf_vf_rtable();
        t_afu_pf_vf_rtable rtable;

        // For simulation, we just pick a collection of VFs associated with a PF.
        for (int p = 0; p < NUM_PORTS; p = p + 1) begin
            rtable[p].pfvf_port = p;
            rtable[p].pf = 0;
            rtable[p].vf = p;
            rtable[p].vf_active = 1'b1;
        end

        return rtable;
    endfunction // gen_afu_pf_vf_rtable

    parameter t_afu_pf_vf_rtable PG_PFVF_ROUTING_TABLE = gen_afu_pf_vf_rtable();

    localparam TDATA_WIDTH = pcie_ss_axis_pkg::TDATA_WIDTH;
    localparam TUSER_WIDTH = pcie_ss_axis_pkg::TUSER_WIDTH;

    logic [NUM_PORTS-1:0] port_rst_n[NUM_LINKS-1:0];
    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) link_tx_a_if [NUM_LINKS-1:0](.clk(pClk),.rst_n(~softReset));
    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) link_rx_a_if [NUM_LINKS-1:0](.clk(pClk),.rst_n(~softReset));
    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) link_tx_b_if [NUM_LINKS-1:0](.clk(pClk),.rst_n(~softReset));
    pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) link_rx_b_if [NUM_LINKS-1:0](.clk(pClk),.rst_n(~softReset));

    for (genvar link = 0; link < NUM_LINKS; link = link + 1) begin: rst_link
        for (genvar p = 0; p < NUM_PORTS; p = p + 1) begin: rst_p
            assign port_rst_n[link][p] = ~softReset;
        end
    end

    localparam LINK_EMUL_NUM_RTABLE_ENTRIES = NUM_LINKS * NUM_PORTS;

    typedef pf_vf_mux_pkg::t_pfvf_rtable_entry[LINK_EMUL_NUM_RTABLE_ENTRIES-1:0]
        t_ase_link_emul_rtable;

    function automatic t_ase_link_emul_rtable gen_ase_link_emul_rtable();
        t_ase_link_emul_rtable rtable;

        // Use a unique VF for every port, even across emulated links. ASE
        // only emulates a single link and PF.
        for (int p = 0; p < LINK_EMUL_NUM_RTABLE_ENTRIES; p = p + 1) begin
            rtable[p].pfvf_port = p / NUM_PORTS;
            rtable[p].pf = 0;
            rtable[p].vf = p;
            rtable[p].vf_active = 1'b1;
        end

        return rtable;
    endfunction // gen_ase_link_emul_rtable

    if (NUM_LINKS == 1) begin : l1
        // One link. Connect the ASE PCIe SS emulation ports directly to afu_main().
        ofs_fim_axis_pipeline #(.PL_DEPTH(0)) conn_tx_a (.clk(pClk), .rst_n(~softReset), .axis_s(link_tx_a_if[0]), .axis_m(afu_axi_tx_a_if));
        ofs_fim_axis_pipeline #(.PL_DEPTH(0)) conn_rx_a (.clk(pClk), .rst_n(~softReset), .axis_s(afu_axi_rx_a_if), .axis_m(link_rx_a_if[0]));
        ofs_fim_axis_pipeline #(.PL_DEPTH(0)) conn_tx_b (.clk(pClk), .rst_n(~softReset), .axis_s(link_tx_b_if[0]), .axis_m(afu_axi_tx_b_if));
        ofs_fim_axis_pipeline #(.PL_DEPTH(0)) conn_rx_b (.clk(pClk), .rst_n(~softReset), .axis_s(afu_axi_rx_b_if), .axis_m(link_rx_b_if[0]));
    end
    else begin : l
        // Multiple links. ASE emulation only supports one stream. Add a PF/VF MUX
        // to the simulation path to split the single ASE stream into what looks
        // like multiple links.

        parameter t_ase_link_emul_rtable LINK_EMUL_PFVF_ROUTING_TABLE = gen_ase_link_emul_rtable();

        pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) tx_a_if [NUM_LINKS-1:0](.clk(pClk),.rst_n(~softReset));
        pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) rx_a_if [NUM_LINKS-1:0](.clk(pClk),.rst_n(~softReset));
        pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) tx_b_if [NUM_LINKS-1:0](.clk(pClk),.rst_n(~softReset));
        pcie_ss_axis_if #(.DATA_W(TDATA_WIDTH), .USER_W(TUSER_WIDTH)) rx_b_if [NUM_LINKS-1:0](.clk(pClk),.rst_n(~softReset));

        pf_vf_mux_w_params
          #(
            .MUX_NAME("ASE_LINK_EMUL_A"),
            .NUM_PORT(NUM_LINKS),
            .NUM_RTABLE_ENTRIES(LINK_EMUL_NUM_RTABLE_ENTRIES),
            .PFVF_ROUTING_TABLE(LINK_EMUL_PFVF_ROUTING_TABLE)
            )
          ase_link_emul_mux_a
           (
            .clk(pClk),
            .rst_n(~softReset),
            .ho2mx_rx_port(afu_axi_rx_a_if),
            .mx2ho_tx_port(afu_axi_tx_a_if),
            .mx2fn_rx_port(rx_a_if),
            .fn2mx_tx_port(tx_a_if),
            .out_fifo_err(),
            .out_fifo_perr()
            );

        pf_vf_mux_w_params
          #(
            .MUX_NAME("ASE_LINK_EMUL_B"),
            .NUM_PORT(NUM_LINKS),
            .NUM_RTABLE_ENTRIES(LINK_EMUL_NUM_RTABLE_ENTRIES),
            .PFVF_ROUTING_TABLE(LINK_EMUL_PFVF_ROUTING_TABLE)
            )
          ase_link_emul_mux_b
           (
            .clk(pClk),
            .rst_n(~softReset),
            .ho2mx_rx_port(afu_axi_rx_b_if),
            .mx2ho_tx_port(afu_axi_tx_b_if),
            .mx2fn_rx_port(rx_b_if),
            .fn2mx_tx_port(tx_b_if),
            .out_fifo_err(),
            .out_fifo_perr()
            );


        //
        // ASE emulates multiple links as a single link, using VFs to represent
        // functions across all links. The MUX above breaks the ASE emulated VFs
        // into separate link ports: rx_a_if, tx_a_if, etc.
        //
        // The code below maps the VFs on the ports going to afu_main() so that
        // they match the VF numbering seen on HW. This mapping moves each link's
        // VF numbering into the range 0:NUM_PORTS-1.
        //

        logic rx_a_sop[NUM_LINKS];
        logic tx_a_sop[NUM_LINKS];
        logic rx_b_sop[NUM_LINKS];
        logic tx_b_sop[NUM_LINKS];

        localparam HDR_WIDTH = $bits(pcie_ss_hdr_pkg::PCIe_PUHdr_t);
        pcie_ss_hdr_pkg::PCIe_PUHdr_t rx_a_hdr[NUM_LINKS];
        pcie_ss_hdr_pkg::PCIe_PUHdr_t tx_a_hdr[NUM_LINKS];
        pcie_ss_hdr_pkg::PCIe_PUHdr_t rx_b_hdr[NUM_LINKS];
        pcie_ss_hdr_pkg::PCIe_PUHdr_t tx_b_hdr[NUM_LINKS];

        for (genvar link = 0; link < NUM_LINKS; link = link + 1) begin: mux_link
            // Track SOP for each channel
            always_ff @(posedge pClk)
            begin
                if (rx_a_if[link].tvalid && rx_a_if[link].tready)
                    rx_a_sop[link] <= rx_a_if[link].tlast;
                if (tx_a_if[link].tvalid && tx_a_if[link].tready)
                    tx_a_sop[link] <= tx_a_if[link].tlast;

                if (rx_b_if[link].tvalid && rx_b_if[link].tready)
                    rx_b_sop[link] <= rx_b_if[link].tlast;
                if (tx_b_if[link].tvalid && tx_b_if[link].tready)
                    tx_b_sop[link] <= tx_b_if[link].tlast;

                if (softReset)
                begin
                    rx_a_sop[link] <= 1'b1;
                    tx_a_sop[link] <= 1'b1;
                    rx_b_sop[link] <= 1'b1;
                    tx_b_sop[link] <= 1'b1;
                end
            end

            // Map the vf_num field in each header between the ASE linear space
            // and the per-link afu_main() space.
            always_comb
            begin
                rx_a_hdr[link] = pcie_ss_hdr_pkg::PCIe_PUHdr_t'(rx_a_if[link].tdata);
                rx_a_hdr[link].vf_num = rx_a_hdr[link].vf_num % NUM_PORTS;

                tx_a_hdr[link] = pcie_ss_hdr_pkg::PCIe_PUHdr_t'(link_tx_a_if[link].tdata);
                tx_a_hdr[link].vf_num = tx_a_hdr[link].vf_num + (NUM_PORTS * link);

                rx_b_hdr[link] = pcie_ss_hdr_pkg::PCIe_PUHdr_t'(rx_b_if[link].tdata);
                rx_b_hdr[link].vf_num = rx_b_hdr[link].vf_num % NUM_PORTS;

                tx_b_hdr[link] = pcie_ss_hdr_pkg::PCIe_PUHdr_t'(link_tx_b_if[link].tdata);
                tx_b_hdr[link].vf_num = tx_b_hdr[link].vf_num + (NUM_PORTS * link);
            end

            // Replace headers with updated vf_num in each channel
            always_comb
            begin
                rx_a_if[link].tready = link_rx_a_if[link].tready;
                link_rx_a_if[link].tvalid = rx_a_if[link].tvalid;
                link_rx_a_if[link].tlast = rx_a_if[link].tlast;
                link_rx_a_if[link].tuser_vendor = rx_a_if[link].tuser_vendor;
                link_rx_a_if[link].tdata = rx_a_if[link].tdata;
                link_rx_a_if[link].tkeep = rx_a_if[link].tkeep;
                if (rx_a_sop[link])
                    link_rx_a_if[link].tdata[HDR_WIDTH-1:0] = rx_a_hdr[link];

                link_tx_a_if[link].tready = tx_a_if[link].tready;
                tx_a_if[link].tvalid = link_tx_a_if[link].tvalid;
                tx_a_if[link].tlast = link_tx_a_if[link].tlast;
                tx_a_if[link].tuser_vendor = link_tx_a_if[link].tuser_vendor;
                tx_a_if[link].tdata = link_tx_a_if[link].tdata;
                tx_a_if[link].tkeep = link_tx_a_if[link].tkeep;
                if (tx_a_sop[link])
                    tx_a_if[link].tdata[HDR_WIDTH-1:0] = tx_a_hdr[link];

                rx_b_if[link].tready = link_rx_b_if[link].tready;
                link_rx_b_if[link].tvalid = rx_b_if[link].tvalid;
                link_rx_b_if[link].tlast = rx_b_if[link].tlast;
                link_rx_b_if[link].tuser_vendor = rx_b_if[link].tuser_vendor;
                link_rx_b_if[link].tdata = rx_b_if[link].tdata;
                link_rx_b_if[link].tkeep = rx_b_if[link].tkeep;
                if (rx_b_sop[link])
                    link_rx_b_if[link].tdata[HDR_WIDTH-1:0] = rx_b_hdr[link];

                link_tx_b_if[link].tready = tx_b_if[link].tready;
                tx_b_if[link].tvalid = link_tx_b_if[link].tvalid;
                tx_b_if[link].tlast = link_tx_b_if[link].tlast;
                tx_b_if[link].tuser_vendor = link_tx_b_if[link].tuser_vendor;
                tx_b_if[link].tdata = link_tx_b_if[link].tdata;
                tx_b_if[link].tkeep = link_tx_b_if[link].tkeep;
                if (tx_b_sop[link])
                    tx_b_if[link].tdata[HDR_WIDTH-1:0] = tx_b_hdr[link];
            end
        end
    end


    // ====================================================================
    //
    //  Local memory
    //
    // ====================================================================

    //
    // Local RAM emulation. ASE provides a module to instantiate an AXI
    // memory emulator, though the interface is the PIM's generic AXI-MM.
    // The PIM AXI-MM is transformed to the FIM's interface below.
    //
`ifndef OFS_PLAT_PARAM_LOCAL_MEM_NUM_BANKS
    localparam NUM_LOCAL_MEM_BANKS = 0;
`else
    localparam NUM_LOCAL_MEM_BANKS = `OFS_PLAT_PARAM_LOCAL_MEM_NUM_BANKS;

    // FIM version of each local memory bank
    ofs_fim_emif_axi_mm_if ext_mem_if[NUM_LOCAL_MEM_BANKS-1:0]();
    logic local_mem_clk[NUM_LOCAL_MEM_BANKS];

    // PIM version of each local memory bank
    ofs_plat_axi_mem_if
      #(
        .ADDR_WIDTH(ofs_fim_mem_if_pkg::AXI_MEM_AWADDR_WIDTH),
        .DATA_WIDTH(ofs_fim_mem_if_pkg::AXI_MEM_WDATA_WIDTH),
        .BURST_CNT_WIDTH(ofs_fim_mem_if_pkg::AXI_MEM_BURST_LEN_WIDTH),
        .USER_WIDTH(ofs_fim_mem_if_pkg::AXI_MEM_AWUSER_WIDTH),
        .RID_WIDTH(ofs_fim_mem_if_pkg::AXI_MEM_ARID_WIDTH),
        .WID_WIDTH(ofs_fim_mem_if_pkg::AXI_MEM_AWID_WIDTH)
        )
        local_mem[NUM_LOCAL_MEM_BANKS]();

    // Instantiate emulators for each local memory bank (PIM version)
    ase_sim_local_mem_ofs_axi
      #(
        .NUM_BANKS(NUM_LOCAL_MEM_BANKS),
        // The emulator expects ADDR_WIDTH in Avalon terms (line index, not byte)
        .ADDR_WIDTH(ofs_fim_mem_if_pkg::AXI_MEM_AWADDR_WIDTH - $clog2(ofs_fim_mem_if_pkg::AXI_MEM_WDATA_WIDTH/8)),
        .DATA_WIDTH(ofs_fim_mem_if_pkg::AXI_MEM_WDATA_WIDTH),
        .BURST_CNT_WIDTH(ofs_fim_mem_if_pkg::AXI_MEM_BURST_LEN_WIDTH),
        .USER_WIDTH(ofs_fim_mem_if_pkg::AXI_MEM_AWUSER_WIDTH),
        .RID_WIDTH(ofs_fim_mem_if_pkg::AXI_MEM_ARID_WIDTH),
        .WID_WIDTH(ofs_fim_mem_if_pkg::AXI_MEM_AWID_WIDTH)
        )
      local_mem_model
       (
        .local_mem(local_mem),
        .clks(local_mem_clk)
        );

    // Map PIM memory bank wires to the FIM interface
    generate
        for (genvar b = 0; b < NUM_LOCAL_MEM_BANKS; b = b + 1)
        begin : mb
            map_local_mem_to_fim_emif_axi_mm
              #(
                .INSTANCE_NUMBER(b)
                )
              map_local_mem
               (
                .clk(local_mem_clk[b]),
                .reset_n(~softReset),
                .pim_mem_bank(local_mem[b]),
                .fim_mem_bank(ext_mem_if[b])
                );
        end
    endgenerate
`endif


    // ====================================================================
    //
    //  HSSI
    //
    // ====================================================================

`ifndef INCLUDE_HSSI
    localparam NUM_ETH_CH = 0;
`else
    localparam NUM_ETH_CH = ofs_fim_eth_plat_if_pkg::MAX_NUM_ETH_CHANNELS;

    ofs_fim_hssi_ss_tx_axis_if hssi_ss_st_tx[NUM_ETH_CH-1:0]();
    ofs_fim_hssi_ss_rx_axis_if hssi_ss_st_rx[NUM_ETH_CH-1:0]();
    ofs_fim_hssi_fc_if hssi_fc[NUM_ETH_CH-1:0]();
    logic [NUM_ETH_CH-1:0] i_hssi_clk_pll;
    logic [NUM_ETH_CH-1:0] i_hssi_rst_n = {NUM_ETH_CH{1'b0}};

    // Clocks and tie offs.
    generate
        for (genvar c = 0; c < NUM_ETH_CH; c = c + 1)
        begin : hssi_clk
            assign hssi_ss_st_tx[c].clk = i_hssi_clk_pll[c];
            assign hssi_ss_st_tx[c].rst_n = i_hssi_rst_n[c];
            assign hssi_ss_st_rx[c].clk = i_hssi_clk_pll[c];
            assign hssi_ss_st_rx[c].rst_n = i_hssi_rst_n[c];

          `ifdef ENABLE_HSSI_SIM
            ase_hssi_emulator #(
                .CHANNEL_ID(c)
              ) ase_hssi_emulator (
                .data_rx (hssi_ss_st_rx[c]),
                .data_tx (hssi_ss_st_tx[c]),
                .fc      (hssi_fc[c])
                );
          `else
            //
            // HSSI simulation is not enabled. Compiling for HSSI is slow, so AFUs
            // that need HSSI simulation must declare it in their JSON files with:
            //
            //   "afu-top-interface":
            //      {
            //         "class": "ofs_plat_afu",
            //         "enable-hssi-sim": 1
            //      },
            //
            assign hssi_ss_st_rx[c].rx = '0;
            assign hssi_ss_st_tx[c].tready = 1'b1;

            assign hssi_fc[c].rx_pause = 0;
            assign hssi_fc[c].rx_pfc = 0;

            always_ff @(negedge i_hssi_clk_pll[c])
            begin
                if (hssi_ss_st_tx[c].tx.tvalid)
                begin
                    $fatal(2,
                           { "\nHSSI traffic present on TX channel %0d but HSSI emulation is disabled!\n",
                             "To enable HSSI emulation, update the afu-top-interface section of the AFU's json file:\n",
                             "  \"afu-top-interface\":\n",
                             "      {\n",
                             "        \"class\": \"ofs_plat_afu\",\n",
                             "        \"enable-hssi-sim\": 1\n",
                             "      }\n" }, c);
                end
            end
          `endif

            // Frequency isn't chosen particularly carefully.
            initial
            begin
                i_hssi_clk_pll[c] = 0;
                forever begin
                    #(1200 + c);
                    i_hssi_clk_pll[c] = ~i_hssi_clk_pll[c];
                end
            end

            always @(posedge i_hssi_clk_pll[c])
            begin
                i_hssi_rst_n[c] <= ~softReset;
            end
        end
    endgenerate

`endif //  `ifdef INCLUDE_HSSI


    // ====================================================================
    //
    //  Dummy JTAG
    //
    // ====================================================================

    ofs_jtag_if remote_stp_jtag_if();
    assign remote_stp_jtag_if.tck = 0;
    assign remote_stp_jtag_if.tdi = '0;


    // ====================================================================
    //
    // Instantiate the user's afu_main()
    //
    // ====================================================================

    afu_main #(
        .PG_NUM_LINKS(NUM_LINKS),
        .PG_NUM_PORTS(NUM_PORTS),
        .PORT_PF_VF_INFO(PORT_PF_VF_INFO),
        .NUM_MEM_CH(NUM_LOCAL_MEM_BANKS),
        .MAX_ETH_CH(NUM_ETH_CH),

        .PG_NUM_RTABLE_ENTRIES(NUM_PORTS),
        .PG_PFVF_ROUTING_TABLE(PG_PFVF_ROUTING_TABLE)
      ) afu_main (
        .clk(pClk),
        .clk_div2(pClkDiv2),
        .clk_div4(pClkDiv4),
        .uclk_usr(uClk_usr),
        .uclk_usr_div2(uClk_usrDiv2),

        .rst_n(~softReset),
        .port_rst_n(port_rst_n),

        .afu_axi_tx_a_if(link_tx_a_if),
        .afu_axi_rx_a_if(link_rx_a_if),
        .afu_axi_tx_b_if(link_tx_b_if),
        .afu_axi_rx_b_if(link_rx_b_if),

        `ifdef INCLUDE_LOCAL_MEM
            // Local memory
            .ext_mem_if,
        `endif

        `ifdef INCLUDE_HSSI
            .hssi_ss_st_tx,
            .hssi_ss_st_rx,
            .hssi_fc,
            .i_hssi_clk_pll,
        `endif

        // JTAG interface for PR region debug (dummy, since simulating)
        .remote_stp_jtag_if
        );
endmodule // ase_top_ofs_plat

`endif //  `ifndef OPAE_PLATFORM_GEN

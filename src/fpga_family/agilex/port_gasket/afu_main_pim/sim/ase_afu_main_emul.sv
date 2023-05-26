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

    // Map the PF/VF association of AFU ports to the parameters that will be
    // passed to the port gasket.
    typedef pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t[PG_NUM_PORTS-1:0] t_afu_pf_vf_map;
    function automatic t_afu_pf_vf_map gen_afu_pf_vf_map();
        t_afu_pf_vf_map map;

        // For simulation, we just pick a collection of VFs associated with a PF.
        for (int p = 0; p < PG_NUM_PORTS; p = p + 1) begin
            map[p].pf_num = 0;
            map[p].vf_num = p;
            map[p].vf_active = 1'b1;
        end

        return map;
    endfunction // gen_afu_pf_vf_map

    localparam pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t[PG_NUM_PORTS-1:0] PORT_PF_VF_INFO =
        gen_afu_pf_vf_map();


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
        .ADDR_WIDTH(mem_ss_pkg::AXI_MEM_ADDR_WIDTH),
        .DATA_WIDTH(mem_ss_pkg::AXI_MEM_DATA_WIDTH),
        .BURST_CNT_WIDTH(mem_ss_pkg::AXI_MEM_BURST_LEN_WIDTH),
        .USER_WIDTH(mem_ss_pkg::AXI_MEM_USER_WIDTH),
        .RID_WIDTH(mem_ss_pkg::AXI_MEM_ID_WIDTH),
        .WID_WIDTH(mem_ss_pkg::AXI_MEM_ID_WIDTH)
        )
        local_mem[NUM_LOCAL_MEM_BANKS]();

    // Instantiate emulators for each local memory bank (PIM version)
    ase_sim_local_mem_ofs_axi
      #(
        .NUM_BANKS(NUM_LOCAL_MEM_BANKS),
        // The emulator expects ADDR_WIDTH in Avalon terms (line index, not byte)
        .ADDR_WIDTH(mem_ss_pkg::AXI_MEM_ADDR_WIDTH - $clog2(mem_ss_pkg::AXI_MEM_DATA_WIDTH/8)),
        .DATA_WIDTH(mem_ss_pkg::AXI_MEM_DATA_WIDTH),
        .BURST_CNT_WIDTH(mem_ss_pkg::AXI_MEM_BURST_LEN_WIDTH),
        .USER_WIDTH(mem_ss_pkg::AXI_MEM_USER_WIDTH),
        .RID_WIDTH(mem_ss_pkg::AXI_MEM_ID_WIDTH),
        .WID_WIDTH(mem_ss_pkg::AXI_MEM_ID_WIDTH)
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

localparam NUM_ETH_CH = ofs_fim_eth_plat_if_pkg::MAX_NUM_ETH_CHANNELS;

ofs_fim_hssi_ss_tx_axis_if hssi_ss_st_tx[NUM_ETH_CH-1:0]();
ofs_fim_hssi_ss_rx_axis_if hssi_ss_st_rx[NUM_ETH_CH-1:0]();
ofs_fim_hssi_fc_if         hssi_fc[NUM_ETH_CH-1:0]();
logic [NUM_ETH_CH-1:0]i_hssi_clk_pll;
logic [NUM_ETH_CH-1:0]i_hssi_rst_n = {NUM_ETH_CH{1'b0}};

// Clocks and tie offs.
generate
    for (genvar c = 0; c < NUM_ETH_CH; c = c + 1)
    begin : hssi_clk
        assign hssi_ss_st_tx[c].clk = i_hssi_clk_pll[c];
        assign hssi_ss_st_tx[c].rst_n = i_hssi_rst_n[c];
        assign hssi_ss_st_rx[c].clk = i_hssi_clk_pll[c];
        assign hssi_ss_st_rx[c].rst_n = i_hssi_rst_n[c];

        assign hssi_ss_st_rx[c].rx = '0;
        assign hssi_ss_st_tx[c].tready = 1'b1;

        assign hssi_fc[c].rx_pause = 0;
        assign hssi_fc[c].rx_pfc = 0;

        // Frequency isn't chosen particularly carefully.
        initial
        begin
            i_hssi_clk_pll[c] = 0;
            forever begin
                #(1000 + c * 100);
                i_hssi_clk_pll[c] = ~i_hssi_clk_pll[c];
            end
        end

        always @(posedge i_hssi_clk_pll[c])
        begin
            i_hssi_rst_n[c] <= ~softReset;
        end
    end
endgenerate


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
        .PG_NUM_PORTS(PG_NUM_PORTS),
        .PORT_PF_VF_INFO(PORT_PF_VF_INFO),
        .NUM_MEM_CH(NUM_LOCAL_MEM_BANKS),
        .MAX_ETH_CH(NUM_ETH_CH)
      ) afu_main (
        .clk(pClk),
        .clk_div2(pClkDiv2),
        .clk_div4(pClkDiv4),
        .uclk_usr(uClk_usr),
        .uclk_usr_div2(uClk_usrDiv2),

        .rst_n(~softReset),
        .port_rst_n({PG_NUM_PORTS{~softReset}}),
        //M20k PR protection control for PR region (Tie-off since simulating)
        .pr_m20k_ce_ctl_req(1'b0), 

        .afu_axi_tx_a_if,
        .afu_axi_rx_a_if,
        .afu_axi_tx_b_if,
        .afu_axi_rx_b_if,

        `ifdef INCLUDE_DDR4
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

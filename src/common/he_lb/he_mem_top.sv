// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT


//
// he_mem_top is the entry point to the version of HE LB that manages
// both a PCIe interface and an external memory interface. The
// platform-specific EMIF is converted to a PIM AXI-MM interface and
// the memory's clock domain is mapped to the PCIe clock so that
// all HE LB logic is in the same clock domain.
//
// The EMIF may or may not be used, depending on the value of the
// "EMIF" parameter.
//

`include "ofs_plat_if.vh"

module he_mem_top
  #(
    parameter PF_ID         = 0,
    parameter VF_ID         = 0,
    parameter VF_ACTIVE     = 0,
    parameter PU_MEM_REQ    = 0,
    // Clock frequency exposed in CSR, used to compute throughput.
    parameter CLK_MHZ       = `OFS_PLAT_PARAM_CLOCKS_PCLK_FREQ,

    parameter EMIF          = 1,
    parameter NUM_MEM_BANKS = 1
    )
   (
    input  logic clk,
    // Force 'x to 0
    input  bit   rst_n,

   `ifdef OFS_PLAT_PARAM_LOCAL_MEM_IS_NATIVE_AXI
      ofs_fim_emif_axi_mm_if.user ext_mem_if[NUM_MEM_BANKS],
   `endif
   `ifdef OFS_PLAT_PARAM_LOCAL_MEM_IS_NATIVE_AVALON
      ofs_fim_emif_avmm_if.user   ext_mem_if[NUM_MEM_BANKS],
   `endif

    pcie_ss_axis_if.sink      axi_rx_a_if,
    pcie_ss_axis_if.sink      axi_rx_b_if,
    pcie_ss_axis_if.source    axi_tx_a_if,
    pcie_ss_axis_if.source    axi_tx_b_if
    );

//
// Does the platform have local memory configured?
//
`ifdef OFS_PLAT_PARAM_LOCAL_MEM_NUM_BANKS

    // ====================================================================
    //
    //  Convert the FIM's external memory interface to the PIM's
    //  AXI-MM interface.
    //
    // ====================================================================

    // All memory banks will be mapped to the PIM's AXI-MM interface
    ofs_plat_axi_mem_if
      #(
        `LOCAL_MEM_AXI_MEM_PARAMS
        )
      axi_mem_bank_if[NUM_MEM_BANKS]();


    // Map the FIM external memory interface to the PIM's standard data
    // structure. When the PIM is configured for a platform, its
    // setup scripts provide ofs_plat_local_mem_fiu_if with a type that
    // matches the native FIM interface.
  `ifdef OFS_PLAT_PARAM_LOCAL_MEM_IS_NATIVE_AXI

    // Standard representation of native AXI local memory
    ofs_plat_axi_mem_if
      #(
        `LOCAL_MEM_AXI_MEM_PARAMS_FULL_BUS_DEFAULT,
        .LOG_CLASS(ofs_plat_log_pkg::LOCAL_MEM)
        )
        local_mem[NUM_MEM_BANKS]();

  `elsif OFS_PLAT_PARAM_LOCAL_MEM_IS_NATIVE_AVALON

    // Standard representation of native Avalon local memory
    ofs_plat_avalon_mem_if
      #(
        `LOCAL_MEM_AVALON_MEM_PARAMS_FULL_BUS_DEFAULT,
        .LOG_CLASS(ofs_plat_log_pkg::LOCAL_MEM)
        )
        local_mem[NUM_MEM_BANKS]();

  `else

    *** ERROR: unsupported local memory interface ***

  `endif

    generate
        for (genvar b = 0; b < NUM_MEM_BANKS; b = b + 1) begin : mb

      `ifdef OFS_PLAT_PARAM_LOCAL_MEM_IS_NATIVE_AXI
            // Native AXI-MM interface to PIM's AXI-MM
            map_fim_emif_axi_mm_to_local_mem
              #(
                .INSTANCE_NUMBER(b)
                )
              map_local_mem
               (
                .fim_mem_bank(ext_mem_if[b]),
                .afu_mem_bank(local_mem[b])
                );
      `else
            // Native Avalon-MM interface to PIM's Avalon-MM
            map_fim_emif_avmm_to_local_mem
              #(
                .INSTANCE_NUMBER(b)
                )
              map_local_mem
               (
                .fim_mem_bank(ext_mem_if[b]),
                .afu_mem_bank(local_mem[b])
                );
      `endif

            // Clock crossing, burst count mapping, any required protocol
            // conversion (e.g. Avalon-MM to AXI-MM).
            ofs_plat_local_mem_as_axi_mem
              #(
                // Add a clock crossing
                .ADD_CLOCK_CROSSING(1)
                )
              shim
               (
                .to_fiu(local_mem[b]),
                .to_afu(axi_mem_bank_if[b]),

                .afu_clk(clk),
                .afu_reset_n(rst_n)
                );
        end
    endgenerate


    // ====================================================================
    //
    //  Combine all memory banks into a single address space.
    //
    // ====================================================================

    localparam MEM_ADDR_WIDTH = local_mem_cfg_pkg::LOCAL_MEM_BYTE_ADDR_WIDTH + $clog2(NUM_MEM_BANKS);
    localparam MEM_DATA_WIDTH = local_mem_cfg_pkg::LOCAL_MEM_DATA_WIDTH;

    ofs_plat_axi_mem_if
      #(
        .ADDR_WIDTH(MEM_ADDR_WIDTH),
        .DATA_WIDTH(MEM_DATA_WIDTH)
        )
      axi_mem_if();

    assign axi_mem_if.clk = clk;
    assign axi_mem_if.reset_n = rst_n;
    assign axi_mem_if.instance_number = 0;

    generate
        if (NUM_MEM_BANKS == 1) begin : single
            // There is just one bank. Connect it directly.
            ofs_plat_axi_mem_if_connect conn
               (
                .mem_sink(axi_mem_bank_if[0]),
                .mem_source(axi_mem_if)
                );
        end
        else begin : multi
            ofs_plat_axi_mem_if
              #(
                .ADDR_WIDTH(MEM_ADDR_WIDTH),
                .DATA_WIDTH(MEM_DATA_WIDTH)
                )
              axi_mem_merged_if();

            assign axi_mem_merged_if.clk = clk;
            assign axi_mem_merged_if.reset_n = rst_n;
            assign axi_mem_merged_if.instance_number = 0;

            he_mem_merge_banks
              #(
                .NUM_MEM_BANKS(NUM_MEM_BANKS)
                )
              mem_merge
               (
                .mem_sinks(axi_mem_bank_if),
                .mem_source(axi_mem_merged_if)
                );

            // Add a register stage for timing
            ofs_plat_axi_mem_if_skid mem_skid
               (
                .mem_sink(axi_mem_merged_if),
                .mem_source(axi_mem_if)
                );
        end
    endgenerate


    // ====================================================================
    //
    //  The HE LB main interface is the common entry point for all
    //  variants of the AFU. Pass in the mapped memory interface. The
    //  EMIF parameter still controls whether the interface is used
    //  or just tied off.
    //
    // ====================================================================

    he_lb_main
      #(
        .PF_ID(PF_ID),
        .VF_ID(VF_ID),
        .VF_ACTIVE(VF_ACTIVE),
        .EMIF(EMIF),
        .PU_MEM_REQ(PU_MEM_REQ),
        .CLK_MHZ(CLK_MHZ)
        )
      main
       (
        .clk,
        .rst_n,
        .axi_rx_a_if,
        .axi_rx_b_if,
        .axi_tx_a_if,
        .axi_tx_b_if,
        .ext_mem_if(axi_mem_if)
        );

`endif //  `ifdef OFS_PLAT_PARAM_LOCAL_MEM_NUM_BANKS

endmodule: he_mem_top

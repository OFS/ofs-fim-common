// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT


//
// he_lb_top is the entry point to the version of HE LB that runs
// with only a PCIe interface and no EMIF. It creates a dummy EMIF
// interface and then instantiates he_lb_main(), which is shared with
// variants that do use EMIF.
//

`include "ofs_plat_if.vh"

module he_lb_top
  #(
    parameter PF_ID         = 0,
    parameter VF_ID         = 0,
    parameter VF_ACTIVE     = 0,
    parameter PU_MEM_REQ    = 0,
    // Clock frequency exposed in CSR, used to compute throughput.
    parameter CLK_MHZ       = `OFS_PLAT_PARAM_CLOCKS_PCLK_FREQ
    )
   (
    input  logic clk,
    // Force 'x to 0
    input  bit   rst_n,

    pcie_ss_axis_if.sink      axi_rx_a_if,
    pcie_ss_axis_if.sink      axi_rx_b_if,
    pcie_ss_axis_if.source    axi_tx_a_if,
    pcie_ss_axis_if.source    axi_tx_b_if
    );

    //
    // Instantiate a dummy EMIF instance before entering common code
    //

    // Instance of the PIM's standard AXI memory interface.
    ofs_plat_axi_mem_if
      #(
        // Actual values here don't matter but some value is required
        .ADDR_WIDTH(10),
        .DATA_WIDTH(512)
        )
      ext_mem_if();

    // Tie off the dummy memory
    assign ext_mem_if.clk = clk;
    assign ext_mem_if.reset_n = rst_n;
    assign ext_mem_if.instance_number = 0;
    assign ext_mem_if.awready = 1'b1;
    assign ext_mem_if.wready = 1'b1;
    assign ext_mem_if.bvalid = 1'b0;
    assign ext_mem_if.arready = 1'b1;
    assign ext_mem_if.rvalid = 1'b0;


    he_lb_main
      #(
        .PF_ID(PF_ID),
        .VF_ID(VF_ID),
        .VF_ACTIVE(VF_ACTIVE),
        .EMIF(0),
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
        .ext_mem_if
        );

endmodule: he_lb_top

// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT


//
// A simple MUX that maps NUM_PORTS AXI-MM source ports to a single
// shared sink. There is no arbitration. Only traffic from the
// dynamically selected port passes to the sink. Traffic from
// non-selected ports is dropped.
//
// It is the responsibility of the parent to ensure that port_select
// does not change while a port is active.
//
// Skid buffers are added to each source port for timing.
//

`include "ofs_plat_if.vh"

module he_lb_mux_fixed
  #(
    parameter NUM_PORTS = 1
    )
   (
    // Select which port is connected
    input  logic [$clog2(NUM_PORTS)-1 : 0] port_select,

    // Shared AXI-MM interface to which the individual ports connect
    ofs_plat_axi_mem_if.to_sink merged_mem,

    // Private ports
    ofs_plat_axi_mem_if.to_source mem_ports[NUM_PORTS]
    );

    //
    // Define another instance of the AXI-MM ports vector. This vector
    // will be the one actually connected as the MUX. Skid buffers will
    // be added between these MUX ports and the mem_ports passed to
    // the parent.
    //
    ofs_plat_axi_mem_if
      #(
        `OFS_PLAT_AXI_MEM_IF_REPLICATE_PARAMS(merged_mem)
        )
      mux_ports[NUM_PORTS]();

    //
    // Connect mux_ports to mem_ports through skid buffers and initialize clocks.
    //
    generate
        for (genvar p = 0; p < NUM_PORTS; p = p + 1)
        begin : init
            assign mux_ports[p].clk = merged_mem.clk;
            assign mux_ports[p].reset_n = merged_mem.reset_n;
            assign mux_ports[p].instance_number = merged_mem.instance_number;

            ofs_plat_axi_mem_if_skid skid
               (
                .mem_sink(mux_ports[p]),
                .mem_source(mem_ports[p])
                );
        end
    endgenerate


    // ====================================================================
    //
    //  Routing MUX that binds the proper test's host memory interface to
    //  actual host memory.
    //
    // ====================================================================

    // SystemVerilog does not allow non-constant indexed selection of
    // an array of interfaces. We have to go through wires and then
    // select the wires with an index.
    logic selected_awvalid[NUM_PORTS];
    logic [merged_mem.T_AW_WIDTH-1 : 0] selected_aw[NUM_PORTS];
    logic selected_wvalid[NUM_PORTS];
    logic [merged_mem.T_W_WIDTH-1 : 0] selected_w[NUM_PORTS];
    logic selected_bready[NUM_PORTS];

    logic selected_arvalid[NUM_PORTS];
    logic [merged_mem.T_AR_WIDTH-1 : 0] selected_ar[NUM_PORTS];
    logic selected_rready[NUM_PORTS];

    // MUX to select wires from the active port
    always_comb
    begin
        merged_mem.awvalid = selected_awvalid[port_select];
        merged_mem.aw = selected_aw[port_select];
        merged_mem.wvalid = selected_wvalid[port_select];
        merged_mem.w = selected_w[port_select];
        merged_mem.bready = selected_bready[port_select];

        merged_mem.arvalid = selected_arvalid[port_select];
        merged_mem.ar = selected_ar[port_select];
        merged_mem.rready = selected_rready[port_select];
    end

    generate
        // Interfaces to wires (one to one)
        for (genvar p = 0; p < NUM_PORTS; p = p + 1)
        begin : mux
            assign selected_awvalid[p] = mux_ports[p].awvalid;
            assign selected_aw[p] = mux_ports[p].aw;
            assign selected_wvalid[p] = mux_ports[p].wvalid;
            assign selected_w[p] = mux_ports[p].w;
            assign selected_bready[p] = mux_ports[p].bready;

            assign selected_arvalid[p] = mux_ports[p].arvalid;
            assign selected_ar[p] = mux_ports[p].ar;
            assign selected_rready[p] = mux_ports[p].rready;
        end

        // Forward responses to all engines. The data can simply go everywhere.
        // Only the valid bits are port-specific.
        for (genvar p = 0; p < NUM_PORTS; p = p + 1)
        begin : demux
            always_comb
            begin
                mux_ports[p].awready = merged_mem.awready;
                mux_ports[p].wready = merged_mem.wready;
                mux_ports[p].bvalid = merged_mem.bvalid && (port_select == p);
                mux_ports[p].b = merged_mem.b;

                mux_ports[p].arready = merged_mem.arready;
                mux_ports[p].rvalid = merged_mem.rvalid && (port_select == p);
                mux_ports[p].r = merged_mem.r;
            end
        end
    endgenerate

endmodule // he_lb_mux_fixed

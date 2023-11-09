// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`timescale 1 ps / 1 ps

module eth_f_pkt_gen_rom #(
        parameter INIT_FILE = "rom_init_file.hex",
        parameter data_width = 32,
        parameter addr_width = 8
    ) (
        input  logic           clk,
        input  logic           reset,
        input  logic           clken,

        input  logic [addr_width-1: 0]  address,
        input  logic                    chipselect,
        input  logic                    write,
        input  logic [data_width-1: 0]  writedata,
        output logic [data_width-1: 0]  readdata
);
 
logic  wren;
assign wren = chipselect & write;

altsyncram pkt_altsyncram
    (
        .clock0          (clk),
        .clocken0        (clken),
        .aclr0           (1'b0),
        .address_a       (address),
        .byteena_a       (1'b1),
        .wren_a          (wren),
        .rden_a          (1'b1),
        .data_a          (writedata),
        .q_a             (readdata),
        .addressstall_a  (1'b0),

        //.clock1          (1'b0),
        //.clocken1        (1'b0),
        .aclr1           (1'b0),
        .address_b       (1'b1),
        .byteena_b       (1'b1),
        .wren_b          (1'b0),
        .rden_b          (1'b1),
        .data_b          (1'b1),
        .q_b             (),
        .addressstall_b  (1'b0),

        .eccstatus       (),
        .clocken2        (1'b1)
        //.clocken3        (1'b0)
    );
 
  defparam pkt_altsyncram.init_file       = INIT_FILE,
           pkt_altsyncram.width_a         = data_width,
           pkt_altsyncram.widthad_a       = addr_width,
           pkt_altsyncram.width_byteena_a = 1,
           pkt_altsyncram.numwords_a      = 1 << addr_width,
           pkt_altsyncram.maximum_depth   = 24,
           pkt_altsyncram.lpm_type        = "altsyncram",
           pkt_altsyncram.operation_mode  = "SINGLE_PORT",
           pkt_altsyncram.outdata_reg_a   = "UNREGISTERED",
           pkt_altsyncram.ram_block_type  = "M20K",
           pkt_altsyncram.read_during_write_mode_mixed_ports = "DONT_CARE",
           pkt_altsyncram.read_during_write_mode_port_a = "DONT_CARE",
           pkt_altsyncram.intended_device_family = "Agilex";

endmodule

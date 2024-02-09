// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


// Dual port RAM module designed to
// infer a RAM block
module eth_f_hw_dual_port_sram #(
    parameter WIDTH     = 8,
    parameter DEPTH     = 16,
    parameter ADDR_BITS = $clog2(DEPTH)
) (
    input                   read_clk,
    input  [ADDR_BITS-1:0]  read_addr,
    input                   read,
    output reg [WIDTH-1:0]  read_data,

    input                   write_clk,
    input  [ADDR_BITS-1:0]  write_addr,
    input                   write,
    input  [WIDTH-1:0]      write_data
);

wire rdenA,wrenB,clocken2,clocken3;
wire [WIDTH-1:0] dataB;
assign rdenA = 1'b1;
assign wrenB = 1'b0;
assign clocken2 = 1'b1;
assign clocken3 = 1'b1;
assign dataB = {WIDTH{1'b1}};
altsyncram fifo_altsyncram
    (
// Read 
        .clock0          (write_clk),
        .clocken0        (1'b1),
        .aclr0           (1'b0),
        .address_a       (write_addr),
        .byteena_a       (1'b1),
        .wren_a          (write),
        .rden_a          (rdenA),
        .data_a          (write_data),
        .q_a             (),
        .addressstall_a  (1'b0),
// Write
        .clock1          (read_clk),
        .clocken1        (1'b1),
        .aclr1           (1'b0),
        .address_b       (read_addr),
        .byteena_b       (1'b1),
        .wren_b          (wrenB),
        .rden_b          (read),
        .data_b          (dataB),
        .q_b             (read_data),
        .addressstall_b  (1'b0),
        .eccstatus       (),
        .clocken2        (clocken2),
        .clocken3        (clocken3)
    );
 
  defparam fifo_altsyncram.width_a         = WIDTH,
           fifo_altsyncram.widthad_a       = ADDR_BITS,
           fifo_altsyncram.width_byteena_a = 1,
           fifo_altsyncram.numwords_a      = 1 << ADDR_BITS,
			  fifo_altsyncram.width_b         = WIDTH,
           fifo_altsyncram.widthad_b       = ADDR_BITS,
           fifo_altsyncram.width_byteena_b = 1,
           fifo_altsyncram.numwords_b      = 1 << ADDR_BITS,
           fifo_altsyncram.maximum_depth   = DEPTH,
           fifo_altsyncram.lpm_type        = "altsyncram",
           fifo_altsyncram.operation_mode  = "DUAL_PORT",
           fifo_altsyncram.outdata_reg_b   = "CLOCK1",
           fifo_altsyncram.ram_block_type  = "M20K",
           fifo_altsyncram.intended_device_family = "Agilex";

endmodule

// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


module eth_f_hw_dual_clock_fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 16,
    parameter LO_THRSH = 10, 
    parameter HI_THRSH = DEPTH-10
) (
    input              areset,

    input              read_clk,
    output [WIDTH-1:0] read_data,
    input              read,

    input              write_clk,
    input  [WIDTH-1:0] write_data,
    input              write,

    output             lo_thrsh,
    output             hi_thrsh,

    output             empty,
    output             full
);

    localparam ADDR_BITS = $clog2(DEPTH);
    localparam PTR_BITS  = ADDR_BITS + 1;

    wire [PTR_BITS-1:0]  write_ptr, write_ptr_sync;
    wire [PTR_BITS-1:0] fifo_stat_wr, fifo_stat_rd;
    wire [PTR_BITS-1:0]  read_ptr, read_ptr_sync;
    wire [ADDR_BITS-1:0] write_addr = write_ptr[ADDR_BITS-1:0];
    wire [ADDR_BITS-1:0] read_addr  = read_ptr[ADDR_BITS-1:0];
    wire [PTR_BITS-1:0]  read_ptr_when_empty = write_ptr_sync;
	 wire [PTR_BITS:0]  write_ptr_when_full_tmp = read_ptr_sync + DEPTH;
    wire [PTR_BITS-1:0]  write_ptr_when_full = write_ptr_when_full_tmp[PTR_BITS-1:0];

    assign empty = (read_ptr  == read_ptr_when_empty);
    assign full  = (write_ptr == write_ptr_when_full);

    assign lo_thrsh = fifo_stat_rd[ADDR_BITS-1:0] < LO_THRSH;
    assign hi_thrsh = fifo_stat_wr[ADDR_BITS-1:0] > HI_THRSH;

    assign fifo_stat_rd = (write_ptr_sync[ADDR_BITS-1:0] - read_ptr[ADDR_BITS-1:0]);
    assign fifo_stat_wr = (write_ptr[ADDR_BITS-1:0] - read_ptr_sync[ADDR_BITS-1:0]);

    eth_f_hw_dual_port_sram #(
        .WIDTH      (WIDTH),
        .DEPTH      (DEPTH)
    ) ram (
        .read_clk    (read_clk),
        .read_addr   (read_addr),
        .read        (read),
        .read_data   (read_data),
        .write_clk   (write_clk),
        .write_addr  (write_addr),
        .write       (write),
        .write_data  (write_data)
    );


    wire write_rst_sync;
    eth_f_reset_synchronizer rst_sync_wr (
        .clk            (write_clk),
        .aclr           (areset),
        .aclr_sync      (write_rst_sync)
    );
    eth_f_hw_binary_counter #(
        .WIDTH  (PTR_BITS)
    ) write_addr_counter (
        .clk    (write_clk),
        .reset  (write_rst_sync),
        .incr   (write),
        .count  (write_ptr)
    );
    wire read_rst_sync;
    eth_f_reset_synchronizer rst_sync_rd (
        .clk            (read_clk),
        .aclr           (areset),
        .aclr_sync      (read_rst_sync)
    );
    eth_f_hw_binary_counter #(
        .WIDTH  (PTR_BITS)
    ) read_addr_counter (
        .clk    (read_clk),
        .reset  (read_rst_sync),
        .incr   (read),
        .count  (read_ptr)
    );
    eth_f_hw_pointer_synchronizer #(
        .WIDTH      (PTR_BITS)
    ) wr_ptr_sync (
        .input_clk  (write_clk),
        .input_ptr  (write_ptr),
        .output_clk (read_clk),
        .output_ptr (write_ptr_sync)
    );

    eth_f_hw_pointer_synchronizer #(
        .WIDTH      (PTR_BITS)
    ) rd_ptr_sync (
        .input_clk  (read_clk),
        .input_ptr  (read_ptr),
        .output_clk (write_clk),
        .output_ptr (read_ptr_sync)
    );
endmodule

module eth_f_hw_binary_counter #(
    parameter WIDTH = 8
) (
    input                   clk,
    input                   reset,
    input                   incr,
    output reg [WIDTH-1:0]  count
);
wire [WIDTH:0]  count_tmp= count + 'd1;

    always @(posedge clk) begin
        if (reset) begin
            count <= 'd0;
        end else begin
            if (incr) begin
                count <= count_tmp[WIDTH-1:0];
            end else begin
                count <= count;
            end
        end
    end
endmodule



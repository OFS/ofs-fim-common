// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

module fifo_w_rewind #(parameter ADDR_WIDTH = 4, DATA_WIDTH = 1, BYPASS = 1)
   (
    //inputs
    input wire clk,
    input wire reset_n,
    input wire write,
    input wire [DATA_WIDTH-1:0] write_data,
    input wire read,
    input wire load_write_pointer,
    input wire [ADDR_WIDTH-1:0] write_pointer_value,
    input wire load_read_pointer,  // data is not avaliable until two cycles after loading the read pointer.
    input wire [ADDR_WIDTH-1:0] read_pointer_value,
    
    //Outputs
    output reg [DATA_WIDTH-1:0] read_data,
    output reg fifo_empty,
    output reg nafull,
    output reg [ADDR_WIDTH-1:0] write_pointer,
    output reg [ADDR_WIDTH-1:0] read_pointer
    );
   
   reg [ADDR_WIDTH-1:0]         write_pointer_minus_1;
   reg [ADDR_WIDTH-1:0]         write_pointer_minus_2;
   reg [ADDR_WIDTH-1:0]         write_pointer_minus_3;
   reg [ADDR_WIDTH-1:0]         write_pointer_minus_4;
   
   wire [DATA_WIDTH-1:0]        ram_read_data_stg1;
   reg [DATA_WIDTH-1:0]         ram_read_data_stg2;
   
   reg [ADDR_WIDTH-1:0]         ram_read_pointer;
   wire [ADDR_WIDTH-1:0]        ram_read_pointer_wire;
   reg [ADDR_WIDTH-1:0]         ram_read_pointer_plus_1;
   
   reg                          load_read_pointer_r1;
   reg [ADDR_WIDTH-1:0]         read_pointer_value_r1;
   
   wire                         fifo_4_wire;
   
   reg                          fifo_0;
   reg                          fifo_1;
   reg                          fifo_2;
   reg                          fifo_3;
   wire                         ram_data_invalid;
   reg                          inc_ram_ptr_en;
   wire                         inc_ram_ptr;
   wire                         nxt_stg1_valid;
   wire                         nxt_stg2_valid;
   wire                         nxt_stg3_valid;
   reg                          stg1_valid;
   reg                          stg2_valid;
   reg                          stg3_valid;
   wire                         ram_empty;
   wire                         pipe_full;
   wire                         nxt_pipe_full;
   
   wire                         load_is_minus_0;
   wire                         load_is_minus_1;
   wire                         load_is_minus_2;
   wire                         load_is_minus_3;

   assign fifo_4_wire = (write_pointer_minus_4 == read_pointer);
   assign load_is_minus_0 = (read_pointer_value_r1 == write_pointer);
   assign load_is_minus_1 = (read_pointer_value_r1 == write_pointer_minus_1);
   assign load_is_minus_2 = (read_pointer_value_r1 == write_pointer_minus_2);
   assign load_is_minus_3 = (read_pointer_value_r1 == write_pointer_minus_3);
   
   always @(posedge clk) begin
      if (~reset_n) begin
         fifo_0     <= 1'b1;
         fifo_1     <= 1'b0;
         fifo_2     <= 1'b0;
         fifo_3     <= 1'b0;
      end else begin
         fifo_0          <= fifo_0 & ~write        & ~load_read_pointer_r1 |
                            fifo_1 & ~write & read & ~load_read_pointer_r1 |
                            load_read_pointer_r1 & ~write & load_is_minus_0;
         
         fifo_1          <= fifo_0 &  write & ~read & ~load_read_pointer_r1 |
                            fifo_2 & ~write &  read & ~load_read_pointer_r1 |
                            fifo_1 &  write &  read & ~load_read_pointer_r1 |
                            fifo_1 & ~write & ~read & ~load_read_pointer_r1 |
                            load_read_pointer_r1 & ~write & load_is_minus_1 |
                            load_read_pointer_r1 &  write & load_is_minus_0;
         
         fifo_2          <= fifo_1 &  write & ~read & ~load_read_pointer_r1 |
                            fifo_3 & ~write &  read & ~load_read_pointer_r1 |
                            fifo_2 &  write &  read & ~load_read_pointer_r1 |
                            fifo_2 & ~write & ~read & ~load_read_pointer_r1 |
                            load_read_pointer_r1 & ~write & load_is_minus_2 |
                            load_read_pointer_r1 &  write & load_is_minus_1;
         
         fifo_3          <= fifo_2      &  write & ~read & ~load_read_pointer_r1 |
                            fifo_4_wire & ~write &  read & ~load_read_pointer_r1 |
                            fifo_3      &  write &  read & ~load_read_pointer_r1 |
                            fifo_3      & ~write & ~read & ~load_read_pointer_r1 |
                            load_read_pointer_r1 & ~write & load_is_minus_3 |
                            load_read_pointer_r1 &  write & load_is_minus_2;
      end // else: !if(~reset_n)
   end // always @ (posedge clk)
   
   always @(posedge clk) begin // be carefull using this signal when rewidning the FIFO. (i.e. loading wr/rd pointers)
      nafull <= ~(
                  ((write_pointer + 2'd3) == read_pointer) |
                  ((write_pointer + 2'd2) == read_pointer) |
                  ((write_pointer + 1'd1) == read_pointer)
                  );
   end
   
   always @(posedge clk) begin
      load_read_pointer_r1  <= load_read_pointer;
      read_pointer_value_r1 <= read_pointer_value;
   end // always @ (posedge clk)
   
   
   always @(posedge clk) begin
      if (~reset_n) begin
         write_pointer         <= 0;
         write_pointer_minus_1 <= {{(ADDR_WIDTH-1){1'b1}}, 1'b1};
         write_pointer_minus_2 <= {{(ADDR_WIDTH-1){1'b1}}, 1'b0};
         write_pointer_minus_3 <= {{(ADDR_WIDTH-2){1'b1}}, 2'b01};
         write_pointer_minus_4 <= {{(ADDR_WIDTH-2){1'b1}}, 2'b00};
      end else if (load_write_pointer) begin
         write_pointer         <= write_pointer_value;
         write_pointer_minus_1 <= write_pointer_value - 1'd1;
         write_pointer_minus_2 <= write_pointer_value - 2'd2;
         write_pointer_minus_3 <= write_pointer_value - 2'd3;
         write_pointer_minus_4 <= write_pointer_value - 3'd4;
      end else if (write) begin
         write_pointer         <= write_pointer         + 1'd1;
         write_pointer_minus_1 <= write_pointer_minus_1 + 1'd1;
         write_pointer_minus_2 <= write_pointer_minus_2 + 1'd1;
         write_pointer_minus_3 <= write_pointer_minus_3 + 1'd1;
         write_pointer_minus_4 <= write_pointer_minus_4 + 1'd1;
      end
   end
   
   always @(posedge clk) begin
      if (~reset_n) begin
         read_pointer <= 0;
      end else if (load_read_pointer_r1) begin
         read_pointer <= read_pointer_value_r1;
      end else if (read) begin
         read_pointer <= read_pointer + 1'd1;
      end
      
      if (~reset_n) begin
         ram_read_pointer        <= write_pointer;
         ram_read_pointer_plus_1 <= write_pointer + 1'b1;
      end else begin
         if (load_read_pointer_r1) begin
            ram_read_pointer        <= read_pointer_value_r1;
            ram_read_pointer_plus_1 <= read_pointer_value_r1 + 1'd1;
         end else if (inc_ram_ptr) begin
            ram_read_pointer        <= ram_read_pointer        + 1'b1;
            ram_read_pointer_plus_1 <= ram_read_pointer_plus_1 + 1'b1;
         end
      end
      
   end // always @ (posedge clk)
   assign ram_read_pointer_wire = {ADDR_WIDTH{~(inc_ram_ptr)}} & ram_read_pointer |
                                  {ADDR_WIDTH{ (inc_ram_ptr)}} & ram_read_pointer_plus_1;
   
   assign ram_empty = fifo_3 & stg1_valid & stg2_valid & stg3_valid |
                      fifo_2 & (stg1_valid | stg2_valid) & (stg2_valid | stg3_valid) |
                      fifo_1 & (stg1_valid | stg2_valid | stg3_valid) |
                      fifo_0 |
                      ram_data_invalid |
                      load_read_pointer_r1;
   
   assign pipe_full     = stg1_valid & stg2_valid & (stg3_valid | nxt_stg3_valid);
   assign nxt_pipe_full = nxt_stg1_valid & nxt_stg2_valid & nxt_stg3_valid;
   
   always @(posedge clk) begin
      inc_ram_ptr_en <=~ram_empty & ~nxt_pipe_full;
      fifo_empty     <= ~nxt_stg3_valid
                        | load_read_pointer;
      
      if (~reset_n) begin
         stg1_valid <= 1'b0;
         stg2_valid <= 1'b0;
         stg3_valid <= 1'b0;
      end else begin
         stg1_valid <= nxt_stg1_valid;
         stg2_valid <= nxt_stg2_valid;
         stg3_valid <= nxt_stg3_valid;
      end
   end
   assign inc_ram_ptr = inc_ram_ptr_en |
                        (read & pipe_full);
   
   assign nxt_stg1_valid = ~ram_empty                                   & ~load_read_pointer_r1 |
                           stg1_valid & stg2_valid & stg3_valid & ~read & ~load_read_pointer_r1;
   assign nxt_stg2_valid = stg1_valid                                   & ~load_read_pointer_r1 |
                           stg2_valid & stg3_valid & ~read              & ~load_read_pointer_r1;
   assign nxt_stg3_valid = stg2_valid                                   & ~load_read_pointer_r1 |
                           stg3_valid & ~read                           & ~load_read_pointer_r1;
   
   altera_ram_reg #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ADDR_WIDTH(ADDR_WIDTH))
   altera_ram_reg (
                   .rdclock               (clk),
                   .rdaddress             (ram_read_pointer_wire),
                   .wrclock               (clk),
                   .wren                  (write),
                   .wraddress             (write_pointer),
                   .data                  (write_data),
                   .q                     (ram_read_data_stg1),
                   .ram_data_invalid_stg1 (),
                   .ram_data_invalid      (ram_data_invalid)
                   );
   
   always @(posedge clk) begin
      if (~stg2_valid | ~stg3_valid | read) begin
         ram_read_data_stg2 <= ram_read_data_stg1;
      end
      if (~stg3_valid | read) begin
         read_data <= ram_read_data_stg2;
      end
   end
   
   //synopsys translate_off
   
   wire fifo_empty_check = (read_pointer == write_pointer);
   
   always @(posedge clk) begin
      if (reset_n) begin
         if (read & fifo_empty) begin
            $display("T:%8d ERROR: %m Read an empty FIFO rp:%X, wp:%X", $time, read_pointer, write_pointer);
            //$stop;
         end
         // IMPORTANTE NOTE: Technically the fifo is not overrun in this case BUT this logic will NOT support
         // writing to the last avaliable entry in this fifo.
         if (
             write & ~read & ((write_pointer + 1'd1) == read_pointer)
             ) begin
            $display("T:%8d ERROR: %m Wrote to a full FIFO rp:%X, wp:%X", $time, read_pointer, write_pointer);
            //$stop;
         end
         if (fifo_empty_check != fifo_0) begin
            $display("T:%8d ERROR: %m ########################### FIFO_EMPTY_CHECK FAILURE #############################", $time);
            //$stop;
         end
         if (read & load_read_pointer_r1) begin
            $display("T:%8d ERROR: %m #### Read while loading the read pointer is not supported #####", $time);
            //$stop;
         end
         if ((ram_read_pointer == write_pointer) & inc_ram_ptr) begin
            $display("T:%8d ERROR: %m #### ram_read_pointer should never pass the write pointer #####", $time);
            //$stop;
         end
      end // if (reset_n)
   end // always @ (posedge clk)
   
   
   initial begin
      #1;
      if (ADDR_WIDTH < 3) begin
         $display("T:%8d ERROR: %m The parameter ADDR_WIDTH must be greater than 3.", $time);
      end
      
   end
   
   //synopsys translate_on
   
endmodule

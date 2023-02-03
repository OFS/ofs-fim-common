// (C) 2001-2021 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


// This module uses a fifo to store the read addresses, in order to
// use them to determine when to generate the next read compare data.
// If consecutive addresses are the same, we are doing multiple reads
// to the same address and hence should not update the read compare data.
// The status checker also uses this address to report at which address a
// failure occurred.

module altera_emif_avl_tg_2_compare_addr_gen # (
   parameter AMM_WORD_ADDRESS_WIDTH      = "",
   parameter ADDR_FIFO_DEPTH             = "",
   parameter AMM_BURSTCOUNT_WIDTH        = "",
   parameter READ_RPT_COUNT_WIDTH        = "",
   parameter READ_COUNT_WIDTH            = "",
   parameter READ_LOOP_COUNT_WIDTH       = ""
) (
    // Clock and reset
   input                               clk,
   input                               rst,

   input                               emergency_brake_asserted,

   //signals the traffic gen is starting new run
   input                               tg_restart,

    //read counters needed by status checker to know when all reads received
   input [READ_COUNT_WIDTH-1:0]        num_read_bursts,
   input [READ_LOOP_COUNT_WIDTH-1:0]   num_read_loops,
   input                               not_repeat_test,

   input [READ_RPT_COUNT_WIDTH-1:0]    rw_gen_read_rpt_cnt,
   input                               inf_user_mode,

   // Avalon read data
   input                               rdata_valid,

   output                              fifo_almost_full,
   output logic                        next_read_data_en,

   input [AMM_WORD_ADDRESS_WIDTH-1:0]  read_addr,
   input                               read_addr_valid,

   input [AMM_BURSTCOUNT_WIDTH-1:0]    burst_length,
   input                               single_burst,
   output logic [AMM_WORD_ADDRESS_WIDTH-1:0]       current_written_addr,

   //address outputs from the read address fifo
   output   logic [AMM_WORD_ADDRESS_WIDTH-1:0]     read_addr_fifo_out,

   output logic                        check_in_prog,
   output logic                        incr_timeout
);

   timeunit 1ns;
   timeprecision 1ps;

   import avl_tg_defs::*;

   // FIFO address width
   localparam FIFO_WIDTHU = ceil_log2(ADDR_FIFO_DEPTH);
   // Actual FIFO size
   localparam FIFO_NUMWORDS = 2 ** FIFO_WIDTHU;

   // Read/write data registers
   logic                         rdata_valid_r;
   logic                         rdata_valid_rr;
   
   logic [AMM_BURSTCOUNT_WIDTH-1:0] burst_length_counter;


   // Indicates that burst_length_counter is zero
   logic burst_length_cnt_zero;
   logic burst_length_cnt_zero_r;
   
   // seperated counters for single burst length and multiple burst length 
   logic [READ_COUNT_WIDTH-1:0]      single_burst_num_counter;
   logic [READ_COUNT_WIDTH-1:0]      multi_burst_num_counter;
   logic [READ_LOOP_COUNT_WIDTH-1:0] single_loop_cntr;
   logic [READ_LOOP_COUNT_WIDTH-1:0] multi_loop_cntr;

   logic rw_in_prog;

   logic fifo_read_req;
   logic fifo_write_req;
   logic fifo_empty;
   logic fifo_full;
   logic [FIFO_WIDTHU-1:0] words_in_fifo;

   reg [READ_LOOP_COUNT_WIDTH-1:0] num_read_loops_r;

   reg [31:0]  cmp_read_rpt_cnt;
   // retiming read_rpt_cnt to recude compariosn over 32 bits
   reg rd_rpt_last;
   
   // timeout counter
   always_ff @(posedge clk) begin
      // use rdata_valid_r instead of rdata_valid to get better timing results
      // reset is not needed since fifo_empty is 1 when rst is asserted
      incr_timeout <= !rdata_valid_r && !fifo_empty;
   end

   always @ (posedge clk) begin
      if (tg_restart) begin
         cmp_read_rpt_cnt     <= rw_gen_read_rpt_cnt;
         rd_rpt_last          <= not_repeat_test;
      end else begin
         if (rdata_valid_r) begin
            if (cmp_read_rpt_cnt == 32'h1) cmp_read_rpt_cnt  <= rw_gen_read_rpt_cnt;
            else                             cmp_read_rpt_cnt  <= cmp_read_rpt_cnt - 32'h1;

            rd_rpt_last <= (cmp_read_rpt_cnt == 32'h2 | not_repeat_test);
         end
      end
   end
   
   always @ (posedge clk)
   begin
      if (rst) begin
         burst_length_cnt_zero <= 1'b1;
      end else begin
         if (tg_restart) begin
            burst_length_cnt_zero <= 1'b1;
         end else if (rdata_valid_r) begin
            if (burst_length_counter == burst_length - 1'b1) begin
               burst_length_cnt_zero <= 1'b1;
            end else begin
               burst_length_cnt_zero <= 1'b0;
            end
         end 
      end
   end
   always @ (posedge clk)
   begin
      burst_length_cnt_zero_r <= burst_length_cnt_zero;
   end
   // A separate data generator is used to re-generate the written data/mask for read comparison.
   // This saves us from the need of instantiating a FIFO to record the write data
   always_ff @(posedge clk)
   begin
      if (rdata_valid_rr) begin
         if (burst_length_cnt_zero_r) begin
            current_written_addr <= read_addr_fifo_out;
         end
         else begin
            current_written_addr <= current_written_addr + 1'b1;
         end
      end
   end

   always_ff @(posedge clk)
   begin
      if (rst) begin
         check_in_prog  <= 1'b0;
         rdata_valid_r  <= 1'b0;
         rdata_valid_rr <= 1'b0;
      end else begin
         if (!check_in_prog) begin
            // When tg_restart is set, checking begins
            check_in_prog <= tg_restart;
         end else if (emergency_brake_asserted & (burst_length_cnt_zero)) begin
            check_in_prog <= ~fifo_empty;
         end else if ( rw_in_prog && num_read_bursts > 0) begin
            // Checking continues until the desired number of loops is reached
            check_in_prog <= 1'b1;
         end else begin
            check_in_prog <= |(words_in_fifo);
         end
         rdata_valid_r  <= rdata_valid;
         rdata_valid_rr <= rdata_valid_r;
      end
   end

   // Enable data/be generator to generate the next item
   always_ff @(posedge clk)
   begin
      if (rst)
         next_read_data_en <= 1'b0;
      else
         next_read_data_en <= rdata_valid_r & (!single_burst | (rd_rpt_last) | fifo_empty);
   end

   //In order to report the address of a failure, a fifo is required to store the read addresses
   //due to the ability to read multiple times from the same address
   //This fifo is also used to tell the data generator when to produce the next data for comparison
   //by comparing whether the top 2 addresses of the fifo are the same or not

   //when the fifo is almost full, waitrequest is issued to the traffic generator so that no more
   //operations are issued until the read data comes back from the controller
   assign fifo_write_req = read_addr_valid;

   //once the count of the number of burst equals the number of read bursts issued, the last starting address will
   //already have been dequeued from the fifo. reading from it again will read from an empty fifo
   //we also only need to get the next address once per burst, as it is the start address of the burst
   always@(posedge clk)
   begin
   fifo_read_req  <= rdata_valid_r & (burst_length_cnt_zero); 
   end 
   
   //count the length of the burst, only get next addr once per burst
   always_ff @(posedge clk)
   begin
      if (rst) begin
         burst_length_counter <= '0; 
      end else begin
         if (tg_restart) begin
            burst_length_counter <= '0; 
         end else if (rdata_valid_r) begin
            if (burst_length_counter == burst_length - 1'b1) begin
               burst_length_counter <= '0; 
            end else begin
               burst_length_counter <= burst_length_counter + 1'b1;
            end
         end 
      end
   end

   //also count number of reads completed to know when stage is complete
   //when there are more reads to go, the traffic generator should not be allowed to be configured
   //and start a new run
   //this means need to count length of burst, number of repeats, number of bursts, and number of loops
   //burst mode and read repeats are mutually exclusive
   
   always_ff @(posedge clk)
   begin
      if (rst) begin
         multi_burst_num_counter <= '0;
         multi_loop_cntr <= '0;
      end else begin
         if (tg_restart) begin
            multi_burst_num_counter <= '0;
            multi_loop_cntr <= '0;
         end else begin
            if (rdata_valid_rr) begin
               if (burst_length_cnt_zero) begin //on last cycle of each burst
                  multi_burst_num_counter <= multi_burst_num_counter + 1'b1;
                  if (multi_burst_num_counter == num_read_bursts - 1'b1) begin //done 1 loop
                     multi_loop_cntr <= multi_loop_cntr + 1'b1;
                     multi_burst_num_counter <= '0;
                  end
               end
            end
         end
      end
   end

   always_ff @(posedge clk)
   begin
      if (rst) begin
         single_burst_num_counter <= '0;
         single_loop_cntr <= '0;
      end else begin
         if (tg_restart) begin
            single_burst_num_counter <= '0;
            single_loop_cntr <= '0;
         end else begin
            if (rdata_valid_rr & rd_rpt_last) begin
               single_burst_num_counter <= single_burst_num_counter + 1'b1;
               if (single_burst_num_counter == num_read_bursts - 1'b1) begin //done 1 loop
                  single_loop_cntr <= single_loop_cntr + 1'b1;
                  single_burst_num_counter <= '0;
               end
            end
         end
      end
   end
   
   assign rw_in_prog = inf_user_mode? 1:(single_burst ? (single_loop_cntr != num_read_loops_r) : (multi_loop_cntr != num_read_loops_r)) ;

   always_ff @ (posedge clk)
   begin
      if (rst) begin
         num_read_loops_r   <= '0;
      end
      else if (tg_restart) begin
         num_read_loops_r   <= num_read_loops;
      end
   end

   //read address fifo
   scfifo # (
         .lpm_width                (AMM_WORD_ADDRESS_WIDTH), //width of data (addr)
         .lpm_widthu               (FIFO_WIDTHU), //width of used
         .lpm_numwords             (FIFO_NUMWORDS), //depth
         .lpm_showahead            ("ON"),
         .almost_full_value        (FIFO_NUMWORDS > 2 ? FIFO_NUMWORDS-2 : 1),
         .use_eab                  ("OFF"),
         .overflow_checking        ("OFF"),
         .underflow_checking       ("OFF")
      ) read_addr_fifo (
         .rdreq                    (fifo_read_req & ~fifo_empty),
         .aclr                     (1'b0),
         .clock                    (clk),
         .wrreq                    (fifo_write_req),
         .data                     (read_addr),
         .full                     (fifo_full),
         .q                        (read_addr_fifo_out),
         .sclr                     (rst),
         .usedw                    (words_in_fifo),
         .empty                    (fifo_empty),
         .almost_full              (fifo_almost_full),
         .almost_empty             (),
         .eccstatus                ()
      );

endmodule

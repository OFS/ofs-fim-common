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


//////////////////////////////////////////////////////////////////////////////
// The status checker module uses another copy of the data generators to compare
// written data with the returned read data.  If the write and read data do not
// match, the corresponding bits of pnf_per_bit are deasserted.
//////////////////////////////////////////////////////////////////////////////

module altera_emif_avl_tg_2_status_checker # (
   parameter DATA_WIDTH             = "",
   parameter BE_WIDTH               = "",
   parameter ADDR_WIDTH             = "",
   parameter OP_COUNT_WIDTH         = "",
   parameter TEST_DURATION          = "",
   parameter TG_CLEAR_WIDTH         = "",
   parameter TG_TIMEOUT_WIDTH       = "",
   parameter DISABLE_STATUS_CHECKER = 0
) (
   // Clock and reset
   input                          clk,
   input                          rst,
   // Control signals
   input                          enable,
   // Signals the traffic gen is starting a new run
   input                          tg_restart,

   // Actual data for comparison
   input                          ast_act_data_readdatavalid,
   input [DATA_WIDTH-1:0]         ast_act_data_readdata,

   //Expected data for comparison
   input [BE_WIDTH-1:0]           ast_exp_data_byteenable,
   input [DATA_WIDTH-1:0]         ast_exp_data_writedata,
   input [ADDR_WIDTH-1:0]         ast_exp_data_readaddr,

   // Read compare status
   input  [TG_CLEAR_WIDTH-1:0]          tg_clear,
   output logic [DATA_WIDTH-1:0]        pnf_per_bit_persist,
   output logic                         fail,
   output logic                         pass,
   output logic [ADDR_WIDTH-1:0]        first_fail_addr,
   output logic [OP_COUNT_WIDTH-1:0]    failure_count,
   output logic [DATA_WIDTH-1:0]        first_fail_expected_data,
   output logic [DATA_WIDTH-1:0]        first_fail_read_data,
   output logic [DATA_WIDTH-1:0]        first_fail_pnf,
   output logic                         first_failure_occured,

   output logic [DATA_WIDTH-1:0]        before_ff_expected_data,
   output logic [DATA_WIDTH-1:0]        before_ff_read_data,
   output logic [DATA_WIDTH-1:0]        after_ff_expected_data,
   output logic [DATA_WIDTH-1:0]        after_ff_read_data,
   output logic                         before_ff_rdata_valid,
   output logic                         after_ff_rdata_valid,

   output logic [DATA_WIDTH-1:0]        last_read_data,
   output logic [OP_COUNT_WIDTH-1:0]    total_read_count,

   input                          all_tests_issued,
   input                          inf_user_mode_status_en,
   input                          at_byteenable_stage,
   input                          test_in_prog,
   input                          incr_timeout,
   output                         timeout
);
   timeunit 1ns;
   timeprecision 1ps;

   import avl_tg_defs::*;

   // Byte size derived from dividing data width by byte enable width
   // Round up so that compile fails if DATA_WIDTH is not a multiple of BE_WIDTH
   localparam BYTE_SIZE = (DATA_WIDTH + BE_WIDTH - 1) / BE_WIDTH;

   // Write data for comparison
   logic [DATA_WIDTH-1:0]  written_data_r;
   logic [DATA_WIDTH-1:0]  written_data_rr;
   logic [DATA_WIDTH-1:0]  written_data_rrr;
   
   // Read/write data registers
   logic                         rdata_valid_r;
   logic                         rdata_valid_rr;
   logic                         rdata_valid_rrr;
   logic                         rdata_valid_rrrr;
   logic                         rdata_valid_rrrrr;

   logic [DATA_WIDTH-1:0]        rdata_r;
   logic [DATA_WIDTH-1:0]        rdata_rr;
   logic [DATA_WIDTH-1:0]        rdata_rrr;
   logic [DATA_WIDTH-1:0]        rdata_rrrr;
   logic [DATA_WIDTH-1:0]        rdata_rrrrr;

   logic [ADDR_WIDTH-1:0] current_written_addr_r;
   
   logic [DATA_WIDTH-1:0] pnf_per_bit;
   logic [DATA_WIDTH-1:0] pnf_per_bit_r;
   logic                  pnf_error;

   logic [TG_TIMEOUT_WIDTH-1:0]           timeout_count;

   logic                       rdata_valid;
   logic [DATA_WIDTH-1:0]      rdata;
   logic [BE_WIDTH-1:0]        written_be;
   logic [DATA_WIDTH-1:0]      written_data;
   logic [ADDR_WIDTH-1:0]      current_written_addr;
   assign written_data         = ast_exp_data_writedata;
   assign written_be           = ast_exp_data_byteenable;
   assign current_written_addr = ast_exp_data_readaddr;
   assign rdata_valid          = ast_act_data_readdatavalid;
   assign rdata                = ast_act_data_readdata;

   logic [DATA_WIDTH-1:0]   written_be_full_rrr;
   logic [DATA_WIDTH-1:0]   written_be_full_rr;
   logic [DATA_WIDTH-1:0]   written_be_full_r;
   logic [DATA_WIDTH-1:0]   written_be_full;

   // Per bit comparison
   always_ff @(posedge clk)
   begin
      if (rst) begin
         pnf_per_bit <= {DATA_WIDTH{1'b1}};
      end else begin
         if (tg_restart) begin
            pnf_per_bit <= {DATA_WIDTH{1'b1}};
         end else begin
            for (int byte_num = 0; byte_num < BE_WIDTH; byte_num++) begin
               for (int bit_num = 0; bit_num < BYTE_SIZE; bit_num++) begin
                  if (enable && rdata_valid_rr && !(DISABLE_STATUS_CHECKER)) begin
                     if (written_be[byte_num]) begin
                        pnf_per_bit[bit_num + byte_num * BYTE_SIZE] <= (rdata_rr[bit_num + byte_num * BYTE_SIZE] == written_data[bit_num + byte_num * BYTE_SIZE]);
                     end
                     //if byte-enable not set, only check correctness in byte-enable test stage
                     //check the non enabled bits against the seed data from the be stage test
                     else if (at_byteenable_stage) begin
                        pnf_per_bit[bit_num + byte_num * BYTE_SIZE] <= (rdata_rr[bit_num + byte_num * BYTE_SIZE] == ~written_data[bit_num + byte_num * BYTE_SIZE]);
                     end else
                        pnf_per_bit[bit_num + byte_num * BYTE_SIZE] <= 1'b1;
                  end else
                     pnf_per_bit[bit_num + byte_num * BYTE_SIZE] <= 1'b1;
               end
            end
         end
      end
   end

   always_ff @ (posedge clk)
   begin
      if (rst) begin
         pnf_per_bit_persist <= '1;
         total_read_count <= 32'h0;
         last_read_data <= {DATA_WIDTH{1'b0}};
      end
      else begin
         if (tg_clear[TG_CLEAR__READ_COUNT]) begin
            total_read_count <= 32'h0;
            last_read_data <= {DATA_WIDTH{1'b0}};
         end 
         else if (rdata_valid_rr) begin
            total_read_count <= total_read_count + 32'h1;
            last_read_data <= rdata_rr & written_be_full;
         end else begin
            total_read_count <= total_read_count;
            last_read_data <= last_read_data;
         end
         if (tg_clear[TG_CLEAR__PNF]) begin
            pnf_per_bit_persist <= '1;
         end else begin
            pnf_per_bit_persist <= pnf_per_bit_persist & pnf_per_bit;
         end
      end
   end

   // Generate status signals
   //dont assign pass until all test stages complete or it will end sim
   always_ff @(posedge clk)
   if (rst) begin
      pass <= '0;
      fail <= '0;
      timeout_count <= '0;
   end else
   begin
      if (tg_restart) begin
         pass <= '0;
         fail <= '0;
         timeout_count <= '0;
      end else begin
         pass <=  !first_failure_occured & all_tests_issued & ~(test_in_prog);
         // If TEST_DURATION == "INFINITE" then the fail signal
         // will be asserted immediately upon any bit failure.  Otherwise,
         // the fail signal will only be asserted after all traffic has completed.
         fail <= first_failure_occured & ((TEST_DURATION == "INFINITE") || all_tests_issued || inf_user_mode_status_en);
         if(timeout) begin
            timeout_count <= timeout_count;
         end
         else begin
           if(incr_timeout) timeout_count <= timeout_count + 1;
           else             timeout_count <= '0;
         end
      end
   end

   assign timeout = &timeout_count;

   //it takes 2 cycles to enable and fetch the next written data and do the comparison
   //following stage is needed to hold the data to output it if compare fails
   always_ff @(posedge clk)
   begin
      if (rst) begin
         rdata_valid_r             <= '0;
         rdata_valid_rr            <= '0;
         rdata_valid_rrr           <= '0;
         rdata_valid_rrrr          <= '0;
         rdata_valid_rrrrr         <= '0;
         written_data_r            <= '0;
         written_data_rr           <= '0;
         written_data_rrr          <= '0;
         rdata_r                   <= '0;
         rdata_rr                  <= '0;
         rdata_rrr                 <= '0;
         rdata_rrrr                <= '0;
         rdata_rrrrr               <= '0;
         current_written_addr_r    <= '0;
         pnf_per_bit_r             <= '0;
         pnf_error                 <= '1;
      end else begin
         rdata_valid_r             <= rdata_valid;
         rdata_valid_rr            <= rdata_valid_r;
         rdata_valid_rrr           <= rdata_valid_rr;
         rdata_valid_rrrr          <= rdata_valid_rrr;
         rdata_valid_rrrrr         <= rdata_valid_rrrr;

         written_data_r            <= written_data;
         written_data_rr           <= written_data_r;
         written_data_rrr          <= written_data_rr;

         rdata_r                   <= rdata;
         rdata_rr                  <= rdata_r;
         rdata_rrr                 <= rdata_rr;
         rdata_rrrr                <= rdata_rrr;
         rdata_rrrrr               <= rdata_rrrr;

         current_written_addr_r    <= current_written_addr;

         pnf_per_bit_r             <= pnf_per_bit;
         pnf_error                 <= &pnf_per_bit;
      end
   end

   // Generate bit-wise byte-enable signal which is easier to read
   generate
   genvar byte_num;
      for (byte_num = 0; byte_num < BE_WIDTH; ++byte_num)
      begin : gen_written_be_full
         assign written_be_full [byte_num * BYTE_SIZE +: BYTE_SIZE] = {BYTE_SIZE{written_be[byte_num]}};
      end
   endgenerate

   // Display a message to the user if there is an error
   always_ff @(posedge clk)
   begin
      written_be_full_r  <= written_be_full;
      written_be_full_rr <= written_be_full_r;
      written_be_full_rrr <= written_be_full_rr;
   end

   // synthesis translate_off
   always_ff @(posedge clk)
   begin
      if (~(&pnf_per_bit))
      begin
         $display("[%0t] ERROR: Expected %h/%h but read %h", $time, written_data_r, written_be_full_r, rdata_rrr);
         $display("            wrote bits: %h", written_data_r & written_be_full_r);
         $display("             read bits: %h", rdata_rrr & written_be_full_r);
         $display("     At avalon address: %h", current_written_addr);
      end
   end
   // synthesis translate_on
   logic failure_count_is_zero;
   always_ff @ (posedge clk)
   begin
      if (rst) begin
         first_fail_addr <= '0;
         first_fail_expected_data <= '0;
         before_ff_expected_data <= '0;
         after_ff_expected_data <= '0;
         first_fail_read_data <= '0;
         before_ff_read_data  <= '0;
         after_ff_read_data   <= '0;
         first_fail_pnf <= '1;
         before_ff_rdata_valid <= '0;
         after_ff_rdata_valid <= '0;
      end else begin
         if (failure_count_is_zero) begin
            first_fail_addr <= current_written_addr_r;
            first_fail_expected_data <= written_data_rr & written_be_full_rr;
            before_ff_expected_data <= written_data_rrr & written_be_full_rrr;
            after_ff_expected_data <= written_data_r & written_be_full_r;
            first_fail_read_data <= rdata_rrrr & written_be_full_rr;
            before_ff_read_data  <= rdata_rrrrr & written_be_full_rrr;
            after_ff_read_data   <= rdata_rrr & written_be_full_r;
            first_fail_pnf <= pnf_per_bit_r;
            before_ff_rdata_valid <= rdata_valid_rrrrr;
            after_ff_rdata_valid <= rdata_valid_rrr;
        end
     end
   end
   
   always_ff @ (posedge clk)
   begin
      if (rst) begin
         first_failure_occured <= 1'b0;
         failure_count <= '0;
         failure_count_is_zero <= 1'b1;
      end else begin
         if (tg_clear[TG_CLEAR__FAIL_INFO]) begin
            first_failure_occured <= 1'b0;
            failure_count         <= '0;
            failure_count_is_zero <= 1'b1;
         end
         else if (tg_restart)
            first_failure_occured <= 1'b0;
         else if (!pnf_error) begin
            if (!first_failure_occured) begin
               first_failure_occured <= 1'b1; //assert after first failure occurs
            end
            failure_count_is_zero <= 1'b0;
            failure_count <= failure_count + 1'b1;
         end
      end
   end

endmodule



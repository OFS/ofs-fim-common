// Copyright (C) 2001-2021 Intel Corporation
// SPDX-License-Identifier: MIT



`timescale 1 ps / 1 ps

module altera_emif_avl_tg_2_csr_driver #(
   // Definition of port widths for CSR AXI4-Lite interface
   parameter PORT_AWADDR_WIDTH     = 1,
   parameter PORT_AWPROT_WIDTH     = 1,
   parameter PORT_ARADDR_WIDTH     = 1,
   parameter PORT_ARPROT_WIDTH     = 1,
   parameter PORT_WDATA_WIDTH      = 1,
   parameter PORT_WSTRB_WIDTH      = 1,
   parameter PORT_BRESP_WIDTH      = 1,
   parameter PORT_RDATA_WIDTH      = 1,
   parameter PORT_RRESP_WIDTH      = 1
) (
   input  logic         clk,
   input  logic         rst,

   output logic         pass,
   output logic         fail,
   output logic         timeout,

   // Ports for CSR AXI4-Lite interface
   output logic   [PORT_AWADDR_WIDTH-1:0] awaddr,
   output logic                           awvalid,
   input  logic                           awready,
   output logic   [PORT_AWPROT_WIDTH-1:0] awprot,   
   output logic   [PORT_ARADDR_WIDTH-1:0] araddr,
   output logic                           arvalid,
   input  logic                           arready,
   output logic   [PORT_ARPROT_WIDTH-1:0] arprot,   
   output logic   [PORT_WDATA_WIDTH-1:0]  wdata,
   output logic                           wvalid,
   input  logic                           wready,
   output logic   [PORT_WSTRB_WIDTH-1:0]  wstrb,    
   input  logic   [PORT_BRESP_WIDTH-1:0]  bresp,
   input  logic                           bvalid,
   output logic                           bready,
   input  logic   [PORT_RDATA_WIDTH-1:0]  rdata,
   input  logic   [PORT_RRESP_WIDTH-1:0]  rresp,
   input  logic                           rvalid,
   output logic                           rready
);

   // Number of read tests and write tests
   localparam NUM_READS  = 2;
   localparam NUM_WRITES = 1;

   logic rst_r;
   logic rst_rr;
   logic start;

   logic [3:0] aw_cntr;
   logic [3:0] w_cntr;
   logic [3:0] b_cntr;
   logic       b_pass;
   logic [3:0] ar_cntr;
   logic [3:0] r_cntr;
   logic       r_pass;
   logic [PORT_RDATA_WIDTH-1:0] r_data;
   logic       done_writes;
   logic       done_reads;

   logic [PORT_ARADDR_WIDTH-1:0] read_addr_mem [NUM_READS-1:0];
   logic [PORT_RDATA_WIDTH-1:0]  read_data_mem [NUM_READS-1:0];

   logic [PORT_AWADDR_WIDTH-1:0] write_addr_mem [NUM_WRITES-1:0];
   logic [PORT_WDATA_WIDTH-1:0]  write_data_mem [NUM_WRITES-1:0];

   ////////////////////////////////////////////////////
   //  Read test cases
   ////////////////////////////////////////////////////

   always_comb begin
      read_addr_mem[0] = 32'h00000000;
      read_data_mem[0][7:0]   = 8'h00;
      read_data_mem[0][15:8]  = 8'h00;
      read_data_mem[0][31:16] = 16'h0001;

      read_addr_mem[1] = 32'h0000000C;
      read_data_mem[1] = 32'h0000_0000;
   end

   ////////////////////////////////////////////////////
   //  Write test cases
   ////////////////////////////////////////////////////

   // Addresses must be unique since the read checker runs after
   // *all* the writes are completed, not in lock-step with each
   // write.
   always_comb begin
      write_addr_mem[0] = 32'h00000020;
      write_data_mem[0] = 32'h5A5A_5A5A;
   end

   ////////////////////////////////////////////////////
   //  Tie-off unused signals
   ////////////////////////////////////////////////////
   assign awprot = 3'b000;
   assign arprot = 3'b000;
   assign wstrb  = '1;

   ////////////////////////////////////////////////////
   //  Output pass/fail status
   ////////////////////////////////////////////////////
   assign pass    = (done_reads &  r_pass) & (done_writes &  b_pass);
   assign fail    = (done_reads & ~r_pass) | (done_writes & ~b_pass);
   assign timeout = '0;

   ////////////////////////////////////////////////////
   //  Pulse generator for start signal
   ////////////////////////////////////////////////////

   // Generate start signal pulse when this module comes out of reset
   always_ff @ (posedge clk) begin
      rst_r  <= rst;
      rst_rr <= rst_r;
   end

   assign start = rst_r ^ rst_rr;

   ////////////////////////////////////////////////////
   //  FSM to issue write commands
   ////////////////////////////////////////////////////
   typedef enum {
      AW_IDLE,             // Wait here until this module comes out of reset
      AW_WRITES,           // Issue write commands for write_data_mem
      AW_DONE_WRITES       // Wait here if the last write command gets stalled
   } aw_state_t;

   aw_state_t aw_state /* synthesis ignore_power_up */;

   always_ff @ (posedge clk) begin
      if (rst) begin
         aw_state <= AW_IDLE;
      end else begin
         case (aw_state)
            AW_IDLE:
               aw_state <= (start) ?
                              AW_WRITES : AW_IDLE;
            AW_WRITES:
               aw_state <= (aw_cntr == NUM_WRITES-1 && awready) ?
                              AW_DONE_WRITES : AW_WRITES;
            AW_DONE_WRITES:
               aw_state <= (awready) ?
                              AW_IDLE : AW_DONE_WRITES;
            default:
               aw_state <= AW_IDLE;
         endcase
      end
   end

   always_ff @ (posedge clk) begin
      if (rst) begin
         awaddr  <= '0;
         awvalid <= '0;
         aw_cntr <= '0;
      end else begin
         case (aw_state)
            AW_IDLE: begin
               awvalid <= '0;
               aw_cntr <= '0;
            end
            AW_WRITES: begin
               if (awready) begin
                  awaddr  <= write_addr_mem[aw_cntr];
                  awvalid <= '1;
                  aw_cntr <= aw_cntr + 4'd1;
               end
            end
            AW_DONE_WRITES: begin
               if (awready)
                  awvalid <= '0;
            end
         endcase
      end
   end

   ////////////////////////////////////////////////////
   //  FSM to send write data
   ////////////////////////////////////////////////////
   typedef enum {
      W_IDLE,           // Wait here until this module comes out of reset
      W_WRITES,         // Send out write data
      W_DONE_WRITES     // Wait here if the last write data gets stalled
   } w_state_t;

   w_state_t w_state /* synthesis ignore_power_up */;

   always_ff @ (posedge clk) begin
      if (rst) begin
         w_state <= W_IDLE;
      end else begin
         case (w_state)
            W_IDLE:
               w_state <= (start) ?
                              W_WRITES : W_IDLE;
            W_WRITES:
               w_state <= (w_cntr == NUM_WRITES-1 && wready) ?
                              W_DONE_WRITES : W_WRITES;
            W_DONE_WRITES:
               w_state <= (wready) ?
                              W_IDLE : W_DONE_WRITES;
            default:
               w_state <= W_IDLE;
         endcase
      end
   end

   always_ff @ (posedge clk) begin
      if (rst) begin
         wdata  <= '0;
         wvalid <= '0;
         w_cntr <= '0;
      end else begin
         case (aw_state)
            W_IDLE: begin
               wvalid <= '0;
               w_cntr <= '0;
            end
            W_WRITES: begin
               if (wready) begin
                  wdata  <= write_data_mem[w_cntr];
                  wvalid <= '1;
                  w_cntr <= w_cntr + 4'd1;
               end
            end
            W_DONE_WRITES: begin
               if (wready)
                  wvalid <= '0;
            end
         endcase
      end
   end

   ////////////////////////////////////////////////////
   //  FSM to check write responses
   ////////////////////////////////////////////////////
   typedef enum {
      B_IDLE,           // Wait here until this module comes out of reset
      B_RESPS,          // Grab incoming write responses
      B_DONE_RESPS      // Assert done to indicate write tests are complete
   } b_state_t;

   b_state_t b_state /* synthesis ignore_power_up */;
   
   always_ff @ (posedge clk) begin
      if (rst) begin
         b_state <= B_IDLE;
      end else begin
         case (b_state)
            B_IDLE:
               b_state <= (start) ?
                           B_RESPS : B_IDLE;
            B_RESPS:
               b_state <= (b_cntr == NUM_WRITES - 1 && bvalid) ?
                           B_DONE_RESPS : B_RESPS;
            B_DONE_RESPS:
               b_state <= B_IDLE;
            default:
               b_state <= B_IDLE;
         endcase
      end
   end

   always_ff @ (posedge clk) begin
      if (rst) begin
         bready      <= '0;
         b_pass      <= '1;
         b_cntr      <= '0;
         done_writes <= '0;
      end else begin
         case (b_state)
            B_IDLE: begin
               bready <= '0;
               b_cntr <= '0;
            end
            B_RESPS: begin
               bready <= '1;
               if (bvalid) begin
                  b_pass <= b_pass &
                              (bresp == '0);
                  b_cntr <= b_cntr + 4'd1;
               end
            end
            B_DONE_RESPS: begin
               done_writes <= '1;
            end
         endcase
      end
   end

   ////////////////////////////////////////////////////
   //  FSM to issue read commands
   ////////////////////////////////////////////////////
   typedef enum {
      AR_IDLE,                // Wait here until this module comes out of reset
      AR_READS,               // Issue read commands for read_data_mem
      AR_DONE_READS,          // Wait here if the last read command gets stalled
      AR_WAIT_WRITES,         // Wait for write tests to complete
      AR_READ_WRITES,         // Issue read commands for write_data_mem
      AR_DONE_READ_WRITES     // Wait here if the last read command gets stalled
   } ar_state_t;

   ar_state_t ar_state /* synthesis ignore_power_up */;

   always_ff @ (posedge clk) begin
      if (rst) begin
         ar_state <= AR_IDLE;
      end else begin
         case (ar_state)
            AR_IDLE:
               ar_state <= (start) ?
                              AR_READS : AR_IDLE;
            AR_READS:
               ar_state <= (ar_cntr == NUM_READS-1 && arready) ?
                              AR_DONE_READS : AR_READS;
            AR_DONE_READS:
               ar_state <= (arready) ?
                              AR_WAIT_WRITES : AR_DONE_READS;
            AR_WAIT_WRITES:
               ar_state <= (done_writes) ?
                              AR_READ_WRITES : AR_WAIT_WRITES;
            AR_READ_WRITES:
               ar_state <= (ar_cntr == NUM_WRITES-1 && arready) ?
                              AR_DONE_READ_WRITES : AR_READ_WRITES;
            AR_DONE_READ_WRITES:
               ar_state <= (arready) ?
                              AR_IDLE : AR_DONE_READ_WRITES;
            default:
               ar_state <= AR_IDLE;
         endcase
      end
   end

   always_ff @ (posedge clk) begin
      if (rst) begin
         araddr  <= '0;
         arvalid <= '0;
         ar_cntr <= '0;
      end else begin
         case (ar_state)
            AR_IDLE: begin
               arvalid <= '0;
               ar_cntr <= '0;
            end
            AR_READS: begin
               if (arready) begin
                  araddr  <= read_addr_mem[ar_cntr];
                  arvalid <= '1;
                  ar_cntr <= ar_cntr + 4'd1;
               end
            end
            AR_DONE_READS: begin
               if (arready)
                  arvalid <= '0;
            end
            AR_WAIT_WRITES: begin
               arvalid <= '0;
               ar_cntr <= '0;
            end
            AR_READ_WRITES: begin
               if (arready) begin
                  araddr  <= write_addr_mem[ar_cntr];
                  arvalid <= '1;
                  ar_cntr <= ar_cntr + 4'd1;
               end
            end
            AR_DONE_READ_WRITES: begin
               if (arready)
                  arvalid <= '0;
            end
         endcase
      end
   end

   ////////////////////////////////////////////////////
   //  FSM to check read data
   ////////////////////////////////////////////////////
   typedef enum {
      R_IDLE,           // Wait here until this module comes out of reset
      R_READS,          // Grab incoming read data and compare against golden data
      R_DONE_READS      // Assert done to indicate read tests are complete
   } r_state_t;

   r_state_t r_state /* synthesis ignore_power_up */;
   
   always_ff @ (posedge clk) begin
      if (rst) begin
         r_state <= R_IDLE;
      end else begin
         case (r_state)
            R_IDLE:
               r_state <= (start) ?
                           R_READS : R_IDLE;
            R_READS:
               r_state <= (r_cntr == NUM_READS + NUM_WRITES - 1 && rvalid) ?
                           R_DONE_READS : R_READS;
            R_DONE_READS:
               r_state <= R_IDLE;
            default:
               r_state <= R_IDLE;
         endcase
      end
   end

   assign r_data = (r_cntr < NUM_READS) ? read_data_mem[r_cntr] : write_data_mem[r_cntr - NUM_READS];

   always_ff @ (posedge clk) begin
      if (rst) begin
         rready     <= '0;
         r_pass     <= '1;
         r_cntr     <= '0;
         done_reads <= '0;
      end else begin
         case (r_state)
            R_IDLE: begin
               rready <= '0;
               r_cntr <= '0;
            end
            R_READS: begin
               rready <= '1;
               if (rvalid) begin
                  r_pass <= r_pass &
                              (rdata == r_data) &
                              (rresp == '0);
                  r_cntr <= r_cntr + 4'd1;
               end
            end
            R_DONE_READS: begin
               done_reads <= '1;
            end
         endcase
      end
   end

endmodule


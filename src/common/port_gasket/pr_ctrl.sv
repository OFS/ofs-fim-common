// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// PR controller
//-----------------------------------------------------------------------------

import pr_pkg::*;
import ofs_fim_cfg_pkg::PORTS;

module pr_ctrl (
   // Clks and Reset
   input  logic clk_1x,
   input  logic clk_2x,
   input  logic rst_n_1x,
   input  logic rst_n_2x,
   output logic o_pr_fifo_parity_err,

   // PR CTRL Interface
   pr_ctrl_if.snk           pr_ctrl_io,

   // PR to port signals
   output logic [PORTS-1:0] o_pr_reset,
   output logic [PORTS-1:0] o_pr_freeze
);
   // Parameters
   localparam PR_FIFO_DATA_WIDTH  = 32;
   localparam BITS_PER_PARITY     = 8;
   localparam PARITY_WIDTH        = PR_FIFO_DATA_WIDTH/BITS_PER_PARITY; // 4
   localparam PR_FIFO_TOTAL_WIDTH = PARITY_WIDTH+PR_FIFO_DATA_WIDTH;    // 36

   
   // =============================================================================   
   // Interface Signals -- FME & PR
   // =============================================================================
   // FME to PR config and status  
   logic        i_pr_data_valid;
   logic [63:0] i_pr_data;
   logic [63:0] i_pr_control;
   logic [63:0] i_pr_status;

   // PR to FME config and status 
   logic [63:0] o_pr_control;
   logic [63:0] o_pr_status;
   logic [63:0] o_pr_error;
   //logic        o_pr_fifo_parity_err;

   // =============================================================================   
   // Inputs/ Outputs -- FME & PR         // Who updates this?
   // =============================================================================
   logic [PORTS-1:0]  pr_freeze;      // HW
   logic [PORTS-1:0]  pr_reset;       // HW
   logic [PORTS-1:0]  pr_port_mask;   // SW
   logic              pr_data_valid_q;
   logic [63:0]       pr_data_q;

   // =============================================================================     
   // FME_PR_CONTROL                         // Who updates this?
   // Req (from 1x) require pulse stretching
   // Rsp on slow clk are unmodified
   // =============================================================================
   logic              req_pr_start;          // SW -- FME signal for start of bitstream
   logic              req_pr_start_1x;       //    -- sync to PR HOST clock

   logic              req_pr_push_cmplt;     // SW -- FME signal for end of bitstream
   logic              req_pr_push_cmplt_1x;  //    -- sync to PR HOST clock

   logic              req_clr_err;           // SW -- FME lpbk signal to clear error vector

   logic              req_clr_err_1x;        //    -- sync to PR HOST clock

   logic              rsp_pr_access_cmplt;   // HW -- FME PR done signal 

   // =============================================================================  
   // FME PR STATUS                          // Who updates this?
   // =============================================================================
   logic [3:0]       pr_host_status_sw_remap; // HW
   logic             rsp_err_overflow;        // HW
   logic [8:0]       rsp_pr_fifo_credits;
   
   // =============================================================================  
   // PR Async FIFO
   // =============================================================================
   logic                            pr_fifo_full;
   logic                            pr_fifo_empty;
   logic                            pr_fifo_push;
   logic                            pr_fifo_pop;
   logic [8:0]                      pr_fifo_num_entries;
   logic [PR_FIFO_DATA_WIDTH-1:0]   pr_fifo_dout;

   // FIFO Parity
   logic                           pr_fifo_pop_q;
   logic [PARITY_WIDTH-1:0]        expected_parity;
   logic [PARITY_WIDTH-1:0]        parity_during_wr;
   logic [PARITY_WIDTH-1:0]        parity_during_wr_q;
   logic [PARITY_WIDTH-1:0]        parity_during_rd;
   logic [PR_FIFO_TOTAL_WIDTH-1:0] pr_fifo_din_w_parity;
   logic [PR_FIFO_TOTAL_WIDTH-1:0] pr_fifo_dout_w_parity;

   // =============================================================================     
   // PR IP
   // =============================================================================
   logic       pr_ip_datavalid;
   logic       pr_ip_sink_ready;
   logic [2:0] pr_ip_status;
   logic [2:0] pr_ip_status_sw_remap;
   logic       pr_ip_start;
   logic       pr_ip_error;
   logic       pr_ip_success;
   
   // =============================================================================    
   // FSMs 
   // =============================================================================
   logic       err_clr_prev_state;
   logic       pr_ctl_ip_reset;  // PR Host FSM PR IP reset output
   logic       pr_ctl_fifo_aclr; // PR Host FSM PR fifo reset output
   logic       pr_fifo_aclr;
   
   logic       req_pr_control_reset;  // This is the RW bit from SW
   logic       master_reset;      
   logic       rsp_pr_ack_reset;   // This is the RO bit to SW   

   // FME PR Reset request FSM
   enum {
      PR_RST_IDLE_BIT,
      PR_RST_REQ_BIT,
      PR_RST_ACK_BIT
   } pr_reset_idx;

   enum logic [2:0] {
      PR_RST_IDLE = 3'b1 << PR_RST_IDLE_BIT,
      PR_RST_REQ  = 3'b1 << PR_RST_REQ_BIT,
      PR_RST_ACK  = 3'b1 << PR_RST_ACK_BIT,
      PR_RST_XXX  = 'x     
   } pr_reset_state, pr_reset_next;

   // PR Host Controller FSM
   enum {
      PR_CTL_WAIT_FOR_REQ_BIT,
      PR_CTL_PREV_PR_CLR_BIT,
      PR_CTL_PORT_RESET_BIT,
      PR_CTL_AFU_FREEZE_BIT,
      PR_CTL_INITIATE_PR_BIT,
      PR_CTL_PR_IN_PROGRESS_BIT,
      PR_CTL_REQ_COMPLETE_BIT,
      PR_CTL_PORT_OO_RESET_BIT,
      PR_CTL_REINIT_SERVICE_BIT
   } pr_control_idx;

   enum logic [8:0] {
      PR_CTL_WAIT_FOR_REQ   = 9'b1 << PR_CTL_WAIT_FOR_REQ_BIT,
      PR_CTL_PREV_PR_CLR    = 9'b1 << PR_CTL_PREV_PR_CLR_BIT,
      PR_CTL_PORT_RESET     = 9'b1 << PR_CTL_PORT_RESET_BIT,
      PR_CTL_AFU_FREEZE     = 9'b1 << PR_CTL_AFU_FREEZE_BIT,
      PR_CTL_INITIATE_PR    = 9'b1 << PR_CTL_INITIATE_PR_BIT,
      PR_CTL_PR_IN_PROGRESS = 9'b1 << PR_CTL_PR_IN_PROGRESS_BIT,
      PR_CTL_REQ_COMPLETE   = 9'b1 << PR_CTL_REQ_COMPLETE_BIT,
      PR_CTL_PORT_OO_RESET  = 9'b1 << PR_CTL_PORT_OO_RESET_BIT,
      PR_CTL_REINIT_SERVICE = 9'b1 << PR_CTL_REINIT_SERVICE_BIT,
      PR_CTL_XXX            = 'x     
   } pr_control_state, pr_control_next;


   // =============================================================================   
   // Interface Signals -- FME & PR Mapping
   // =============================================================================
   assign i_pr_data_valid             = pr_ctrl_io.prc2out_pg_pr_data_v;
   assign i_pr_data                   = pr_ctrl_io.prc2out_pg_pr_data;
   assign i_pr_control                = pr_ctrl_io.prc2out_pg_pr_ctrl;
   assign i_pr_status                 = pr_ctrl_io.prc2out_pg_pr_status;

   assign pr_ctrl_io.inp2prc_pg_pr_ctrl   = o_pr_control;
   assign pr_ctrl_io.inp2prc_pg_pr_status = o_pr_status;
   assign pr_ctrl_io.inp2prc_pg_pr_error  = o_pr_error;
   //assign pr_ctrl_io.inp2prc_pg_error[63:1] = {63{1'b0}};
   assign pr_ctrl_io.inp2prc_pg_error[0]  = o_pr_fifo_parity_err;

   always_ff @(posedge clk_2x) begin
      pr_data_valid_q <= i_pr_data_valid;
      pr_data_q       <= i_pr_data;
   end

   // ============================================================================= 
   // Output freeze & reset signals to be consumed by Port / AFU boundary
   //
   // Multiple AFUs are not supported in this implementation. Extending support 
   // involves designing a model to support masking off certain ports for PR
   // ============================================================================= 
   assign pr_port_mask = '1;
   assign o_pr_freeze  = pr_freeze & pr_port_mask;
   assign o_pr_reset   = pr_reset  & pr_port_mask;

   // ============================================================================= 
   // Update clk_2x Signals - From PR to FME
   // no clock crossing required for PR IP signals since they run on slow clk
   // =============================================================================
   always_ff @(posedge clk_2x) begin
      if(!rst_n_2x) begin
         o_pr_control     <= '0;
         o_pr_status      <= '0;
         o_pr_error       <= '0;
      end
      else begin
         // FME PR Control response
         o_pr_control[4]  <= rsp_pr_ack_reset;
         o_pr_control[12] <= rsp_pr_access_cmplt;
         o_pr_control[13] <= rsp_pr_access_cmplt;

         o_pr_status      <= {32'h0, 4'h0, pr_host_status_sw_remap, 1'h0, pr_ip_status_sw_remap,
                              11'h0, rsp_pr_fifo_credits}; 
         o_pr_error       <= {59'h0, rsp_err_overflow, pr_ip_error, 2'b0, err_clr_prev_state};
      end
   end

   always_comb begin
      // Report this error only when we reach the state of actively sending PR data
      rsp_err_overflow     = pr_fifo_full & pr_control_state[PR_CTL_PR_IN_PROGRESS_BIT];
      rsp_pr_fifo_credits  = 9'h1ff - pr_fifo_num_entries;

      // HW remap pr control state vector, needed for DC 2.0.1 compatibility
      // An updated PR feature version could simplify the logic with direct forwarding
      pr_host_status_sw_remap       = 'h0;         
      unique case (1'b1)
         pr_control_state[ PR_CTL_WAIT_FOR_REQ_BIT   ] : pr_host_status_sw_remap <= 'h0;
         pr_control_state[ PR_CTL_PREV_PR_CLR_BIT    ] : pr_host_status_sw_remap <= 'h1;
         pr_control_state[ PR_CTL_PORT_RESET_BIT     ] : pr_host_status_sw_remap <= 'h2;
         pr_control_state[ PR_CTL_AFU_FREEZE_BIT     ] : pr_host_status_sw_remap <= 'h3;
         pr_control_state[ PR_CTL_INITIATE_PR_BIT    ] : pr_host_status_sw_remap <= 'h4;
         pr_control_state[ PR_CTL_PR_IN_PROGRESS_BIT ] : pr_host_status_sw_remap <= 'h5;
         pr_control_state[ PR_CTL_REQ_COMPLETE_BIT   ] : pr_host_status_sw_remap <= 'h7;
         pr_control_state[ PR_CTL_PORT_OO_RESET_BIT  ] : pr_host_status_sw_remap <= 'h8;
         pr_control_state[ PR_CTL_REINIT_SERVICE_BIT ] : pr_host_status_sw_remap <= 'h9;
`ifdef SIM_MODE
         default: pr_host_status_sw_remap <= 'hx;
`endif
      endcase
   end
   
   always_comb begin
      req_pr_control_reset = i_pr_control[0];
      req_pr_start         = i_pr_control[12];
      req_pr_push_cmplt    = i_pr_control[13];
      req_clr_err          = i_pr_status[16];
      req_pr_control_reset = i_pr_control[0];
   end

   always_ff @(posedge clk_1x) begin
      req_pr_start_1x       <= req_pr_start;
      req_pr_push_cmplt_1x  <= (req_pr_start_1x)  ? req_pr_push_cmplt : 0;
      req_clr_err_1x        <= (!req_pr_start_1x) ? req_clr_err : req_clr_err_1x;
   end
   
   // =============================================================================  
   // PR Async data FIFO -- 2x -> 1x (FME to PR IP)
   // PR IP must operate @ < 200 MHz
   //
   // Width: 4 + 32 = 36
   // Depth: 512
   // does not support almfull/rdfull backpressure, overrun is reported as an error
   // =============================================================================  
   assign pr_fifo_aclr         = !rst_n_2x | pr_ctl_fifo_aclr;
   assign pr_fifo_din_w_parity = {parity_during_wr_q, pr_data_q[PR_FIFO_DATA_WIDTH-1:0]};   
   assign parity_during_rd     = pr_fifo_dout_w_parity[PR_FIFO_TOTAL_WIDTH-1:PR_FIFO_DATA_WIDTH];
   assign pr_fifo_dout         = pr_fifo_dout_w_parity[PR_FIFO_DATA_WIDTH-1:0];
   
`ifdef INCLUDE_PARITY       
   calc_parity #(.WIDTH (PR_FIFO_DATA_WIDTH)) inst_calc_parity_fifo_write (
      .clk    (clk_2x),
      .din    (i_pr_data[PR_FIFO_DATA_WIDTH-1:0]),
      .parity (parity_during_wr)
   );
   
   calc_parity #(.WIDTH (PR_FIFO_DATA_WIDTH)) inst_calc_parity_fifo_read (
      .clk    (clk_2x),
      .din    (pr_fifo_dout),
      .parity (expected_parity)
   );
   
   always_ff @(posedge clk_2x) begin
      parity_during_wr_q <= parity_during_wr;
   end

   always_ff @(posedge clk_2x) begin
      pr_fifo_pop_q  <= pr_fifo_pop;
   end

   assign o_pr_fifo_parity_err = (|(expected_parity ^ parity_during_rd)) && pr_fifo_pop_q;
`else
   assign parity_during_wr_q  = 0;
   assign o_pr_fifo_parity_err  = 0;
`endif // !`ifdef INCLUDE_PARITY

   assign pr_fifo_push =  pr_data_valid_q & req_pr_start; // Delay data valid by 1 cycle for parity generation
   fim_dcfifo #(
      .DATA_WIDTH      (PR_FIFO_TOTAL_WIDTH),
      .WRITE_ACLR_SYNC ("ON"),
      .READ_ACLR_SYNC  ("ON")
   ) inst_pr_async_fifo (
      .wrclk    (clk_2x),
      .rdclk    (clk_1x),
      .aclr     (pr_fifo_aclr),
      .wrreq    (pr_fifo_push),
      .rdreq    (pr_fifo_pop),
      .data     (pr_fifo_din_w_parity),
      .q        (pr_fifo_dout_w_parity),
      .wrusedw  (pr_fifo_num_entries),
      .rdempty  (pr_fifo_empty),
      .wrfull   (pr_fifo_full),
      // unused
      .rdfull   (),
      .wralmfull()
   );
   
   // =============================================================================
   // PR HOST FSM
   // =============================================================================
   // Reset FSM logic
   always_ff @ (posedge clk_1x) begin
      if (!rst_n_1x) pr_reset_state <= PR_RST_IDLE;
      else           pr_reset_state <= pr_reset_next;
   end

   always_comb begin
      pr_reset_next = PR_RST_XXX;
      unique case (1'b1)
         pr_reset_state[PR_RST_IDLE_BIT]: begin
            pr_reset_next = (req_pr_control_reset) ? PR_RST_REQ : PR_RST_IDLE;
         end
         pr_reset_state[PR_RST_REQ_BIT]: begin
            pr_reset_next = (pr_control_state[PR_CTL_WAIT_FOR_REQ_BIT] & !master_reset) ?
                              PR_RST_ACK : PR_RST_REQ;
         end
         pr_reset_state[PR_RST_ACK_BIT]: begin
            pr_reset_next = (!req_pr_control_reset) ? PR_RST_IDLE : PR_RST_ACK;
         end
`ifdef SIM_MODE
         default: pr_reset_next = PR_RST_XXX;
`endif
      endcase // case (1'b1)
   end // always_comb begin

   always_ff @ (posedge clk_1x) begin
      if(!rst_n_1x) begin
         master_reset    <= 1'b0;
         rsp_pr_ack_reset <= 1'b0;
      end
      else begin
         master_reset <= (pr_reset_state[PR_RST_IDLE_BIT] & req_pr_control_reset);
         rsp_pr_ack_reset <= pr_reset_state[PR_RST_ACK_BIT];
      end
   end

   localparam PR_DELAY_DEPTH  = 8;
   logic [PR_DELAY_DEPTH-1:0] pr_freeze_cycle_cnt;
   logic                      pr_freeze_wait_cmplt;

   logic [PR_DELAY_DEPTH-1:0] pr_reset_cycle_cnt;
   logic                      pr_reset_wait_cmplt;

   assign pr_freeze_wait_cmplt = pr_freeze_cycle_cnt[PR_DELAY_DEPTH-1];
   assign pr_reset_wait_cmplt  = pr_reset_cycle_cnt[PR_DELAY_DEPTH-1];
   
   // PR Host Control FSM
   always_ff @(posedge clk_1x) begin
      if (!rst_n_1x)         pr_control_state <= PR_CTL_WAIT_FOR_REQ;
      else if (master_reset) pr_control_state <= PR_CTL_REQ_COMPLETE;
      else                   pr_control_state <= pr_control_next;
   end

   always_comb begin
      pr_control_next = PR_CTL_XXX;
      unique case (1'b1)
         pr_control_state[PR_CTL_WAIT_FOR_REQ_BIT]: begin
            pr_control_next = (req_pr_start_1x) ? PR_CTL_PREV_PR_CLR : PR_CTL_WAIT_FOR_REQ;
         end
         pr_control_state[PR_CTL_PREV_PR_CLR_BIT]: begin
            pr_control_next = (req_clr_err_1x) ? PR_CTL_REQ_COMPLETE : PR_CTL_PORT_RESET;
         end
         pr_control_state[PR_CTL_PORT_RESET_BIT]: begin
            pr_control_next = (pr_reset_wait_cmplt) ? PR_CTL_AFU_FREEZE : PR_CTL_PORT_RESET;
         end
         pr_control_state[PR_CTL_AFU_FREEZE_BIT]: begin
            pr_control_next = (pr_freeze_wait_cmplt) ? PR_CTL_INITIATE_PR : PR_CTL_AFU_FREEZE;
         end
         pr_control_state[PR_CTL_INITIATE_PR_BIT]: begin
            pr_control_next = (!pr_fifo_empty) ? PR_CTL_PR_IN_PROGRESS : PR_CTL_INITIATE_PR;
         end
         pr_control_state[PR_CTL_PR_IN_PROGRESS_BIT]: begin
            pr_control_next = (pr_ip_success & req_pr_push_cmplt_1x) ? 
                              PR_CTL_REQ_COMPLETE : PR_CTL_PR_IN_PROGRESS;
         end
         pr_control_state[PR_CTL_REQ_COMPLETE_BIT]: begin
            pr_control_next = (pr_freeze_wait_cmplt) ? PR_CTL_PORT_OO_RESET : PR_CTL_REQ_COMPLETE;
         end
         pr_control_state[PR_CTL_PORT_OO_RESET_BIT]: begin
            pr_control_next = (pr_reset_wait_cmplt) ? PR_CTL_REINIT_SERVICE : PR_CTL_PORT_OO_RESET;
         end
         pr_control_state[PR_CTL_REINIT_SERVICE_BIT]: begin
            pr_control_next = (!req_pr_start_1x && !req_pr_push_cmplt_1x) ? 
                              PR_CTL_WAIT_FOR_REQ : PR_CTL_REINIT_SERVICE;
         end
`ifdef SIM_MODE
         default: pr_control_next = PR_CTL_XXX;
`endif
      endcase // case (1'b1)
   end // always_comb begin
   
   // This logic can be registered if a skid buffer is provided for pr_fifo_dout
   // otherwise IP backpressure must directly drive the fifo flow control
   always_comb begin
      pr_fifo_pop = '0;
      if( pr_control_state[PR_CTL_PR_IN_PROGRESS_BIT] ) begin
         // pop the data queue when there is no in flight backpressure
         pr_fifo_pop = !pr_fifo_empty & !(pr_ip_datavalid & !pr_ip_sink_ready);
      end
   end

   always_ff @(posedge clk_1x) begin
      if(!rst_n_1x) begin
         // PR IP signals
         pr_ip_start         <= 1'b0;
         pr_ip_datavalid     <= 1'b0;
         pr_ctl_ip_reset     <= 1'b0;
         // PR FIFO signals
         pr_ctl_fifo_aclr    <= 1'b0;
         // PORT output signals
         pr_reset            <= 1'b0;
         pr_freeze           <= 1'b0;
         // PORT signal assertion delay counters
         pr_freeze_cycle_cnt <= 'h1;
         pr_reset_cycle_cnt  <= 'h1;
         // PR control status
         err_clr_prev_state  <= 1'b0;
         rsp_pr_access_cmplt <= 1'b0;
      end // if (!rst_n_1x)
      else if (master_reset) begin
         pr_freeze <= 1'b0;
         pr_freeze_cycle_cnt <= 'h1;
      end
      else begin
         // defaults
         pr_ip_start         <= 1'b0;
         pr_ip_datavalid     <= 1'b0;
         pr_ctl_ip_reset     <= 1'b0;
         pr_ctl_fifo_aclr    <= 1'b0;
         pr_reset            <= 1'b0;
         pr_freeze           <= 1'b0;
         err_clr_prev_state  <= 1'b0;
         rsp_pr_access_cmplt <= 1'b0;

         // Port signal assertion delay default count
         pr_freeze_cycle_cnt <= 'h1;
         pr_reset_cycle_cnt  <= 'h1;

         unique case (1'b1)
            pr_control_state[PR_CTL_WAIT_FOR_REQ_BIT]: begin
               pr_ctl_ip_reset  <= 1'b1;    // Hold PR IP in reset
               pr_ctl_fifo_aclr <= !req_pr_start;
            end
            pr_control_state[PR_CTL_PREV_PR_CLR_BIT]: begin
               pr_ctl_ip_reset <= 1'b1;    // Hold PR IP in reset
               err_clr_prev_state <= req_clr_err_1x;
            end
            pr_control_state[PR_CTL_PORT_RESET_BIT]: begin
               pr_ctl_ip_reset <= 1'b1;    // Hold PR IP in reset
               pr_reset        <= 1'b1;    // Hold Port in reset
               // iterate reset delay
               pr_reset_cycle_cnt <= {pr_reset_cycle_cnt[PR_DELAY_DEPTH-2:0],
                                       pr_reset_cycle_cnt[PR_DELAY_DEPTH-1]};
            end
            pr_control_state[PR_CTL_AFU_FREEZE_BIT]: begin
               pr_ctl_ip_reset <= 1'b1;    // Hold PR IP in reset
               pr_reset        <= 1'b1;    // Hold Port in reset
               pr_freeze       <= 1'b1;    // Hold Port freeze
               // iterate freeze delay
               pr_freeze_cycle_cnt <= {pr_freeze_cycle_cnt[PR_DELAY_DEPTH-2:0],
                                       pr_freeze_cycle_cnt[PR_DELAY_DEPTH-1]};
            end
            pr_control_state[PR_CTL_INITIATE_PR_BIT]: begin
               pr_reset    <= 1'b1;           // Hold Port in reset
               pr_freeze   <= 1'b1;           // Hold Port freeze
               pr_ip_start <= !pr_fifo_empty; // start PR when data is available
            end
            pr_control_state[PR_CTL_PR_IN_PROGRESS_BIT]: begin
               pr_reset  <= 1'b1; // Hold Port in reset
               pr_freeze <= 1'b1; // Hold Port freeze
               // stream data from PR FIFO to PR IP
               pr_ip_datavalid <= pr_fifo_pop | (pr_ip_datavalid & !pr_ip_sink_ready);
            end
            pr_control_state[PR_CTL_REQ_COMPLETE_BIT]: begin
               pr_reset  <= 1'b1; // Hold Port in reset
               pr_freeze_cycle_cnt <= {pr_freeze_cycle_cnt[PR_DELAY_DEPTH-2:0],
                                       pr_freeze_cycle_cnt[PR_DELAY_DEPTH-1]};
            end
            pr_control_state[PR_CTL_PORT_OO_RESET_BIT]: begin
               pr_reset_cycle_cnt <= {pr_reset_cycle_cnt[PR_DELAY_DEPTH-2:0],
                                       pr_reset_cycle_cnt[PR_DELAY_DEPTH-1]};
            end
            pr_control_state[PR_CTL_REINIT_SERVICE_BIT]: begin
               pr_ctl_fifo_aclr <= 1'b1;
               pr_ctl_ip_reset  <= 1'b1;
               rsp_pr_access_cmplt <= 1'b1;
            end
         endcase // case (1'b1)
      end // else: !if(master_reset)
   end // always_ff @ (posedge clk_1x)

   // =============================================================================
   // PR IP
   // =============================================================================
   logic pr_ip_reset_n;
   
   assign pr_ip_reset_n = rst_n_1x & !pr_ctl_ip_reset;

   assign pr_ip_success = (pr_ip_status == PR_OPERATION_SUCCESSFUL);
   assign pr_ip_error   = (pr_ip_status == PR_ERROR_IS_TRIGGERED);

   // HW remap pr status, needed for DC 2.0.1 compatibility
   // An updated PR feature version should modify this logic with direct forwarding.
   always_comb begin
      case (pr_ip_status) 
         // 3'b000 --> 3'b000
         POWERUP_NRESET_ASSERTED :      pr_ip_status_sw_remap = SW_POWERUP_NRESET_ASSERTED;
         // 3'b001 --> 3'b110
         CONFIGURATION_SYSTEM_IS_BUSY : pr_ip_status_sw_remap = SW_CONFIGURATION_SYSTEM_IS_BUSY;
         // 3'b010 --> 3'b100
         PR_OPERATION_IN_PROGRESS :     pr_ip_status_sw_remap = SW_PR_OPERATION_IN_PROGRESS;
         // 3'b011 --> 3'b101 
         PR_OPERATION_SUCCESSFUL :      pr_ip_status_sw_remap = SW_PR_OPERATION_SUCCESSFUL;
         // 3'b100 --> 3'b001
         PR_ERROR_IS_TRIGGERED :        pr_ip_status_sw_remap = SW_PR_ERROR_IS_TRIGGERED;
         // default
         default :                      pr_ip_status_sw_remap = 3'b111;
      endcase
   end

`ifdef SIM_MODE
   logic [31:0] pr_ip_dword_cnt;
   logic        pr_ip_sink_ready_raw;
   logic        pr_ip_sink_data_mismatch;
   
   always_comb begin
      if (~pr_ip_reset_n) begin
         pr_ip_sink_ready = 1'b0;
      end else if (pr_ip_sink_ready_raw) begin
         pr_ip_sink_ready = 1'b1;
      end
   end
   
   always_ff @ (posedge clk_1x) begin
      if ( ~pr_ip_reset_n ) begin
         pr_ip_dword_cnt          <= 0;
         pr_ip_sink_data_mismatch <= 1'b0;
      end else if (pr_ip_sink_ready && pr_ip_datavalid) begin
         pr_ip_sink_data_mismatch   <= (pr_fifo_dout != pr_ip_dword_cnt); 

/* synthesis translate_off */ 
         assert ( pr_fifo_dout == pr_ip_dword_cnt ) else
            $display("T=%e PR Data Mismatch!  Expected: %x  Actual: %x",$time, pr_ip_dword_cnt, pr_fifo_dout);
/* synthesis translate_on */            

         if ( pr_fifo_dout != pr_ip_dword_cnt ) begin
            pr_ip_dword_cnt        <= pr_fifo_dout + 1'b1;
         end else begin
            pr_ip_dword_cnt        <= pr_ip_dword_cnt + 1'b1; 
         end
      end
   end 
   
   PR_IP PR_IP (
      .avst_sink_data  (pr_fifo_dout),
      .avst_sink_valid (pr_ip_datavalid),
      .avst_sink_ready (pr_ip_sink_ready_raw),
      .clk             (clk_1x),
      .pr_start        (pr_ip_start),
      .reset           (~pr_ip_reset_n),
      .status          (pr_ip_status)
   );
`else   
   PR_IP PR_IP (
      .avst_sink_data  (pr_fifo_dout),
      .avst_sink_valid (pr_ip_datavalid),
      .avst_sink_ready (pr_ip_sink_ready),
      .clk             (clk_1x),
      .pr_start        (pr_ip_start),
      .reset           (~pr_ip_reset_n),
      .status          (pr_ip_status)
   );
`endif

endmodule

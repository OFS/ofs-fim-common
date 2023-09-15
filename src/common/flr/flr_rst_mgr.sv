// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//   FLR reset manager
//
//     The reset manager is topology agnostic, only requiring the number of
//     PFs and VFs. It maps FLR requests coming from the PCIe SS into
//     reset wires distributed to PFs and VFs. When FLR is requested,
//     the corresponding reset wire is held asserted, then deasserted,
//     and finally the PCIe SS is informed that reset is complete. The
//     time reset is held is configured with RST_CNT_WIDTH.
//
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Module ports
//-----------------------------------------------------------------------------

module flr_rst_mgr #(
   parameter NUM_PF = 1,
   parameter NUM_VF = 1,

   // Maximum number of instantiated VFs across all PFs. Used to set FIFO
   // depths for the maximum number of active FLR requests.
   parameter MAX_NUM_VF = 1,

   // Counters hold reset for multiple cycles (25% of the counter domain, in
   // in clk_csr cycles). The top two bits control reset state, defined in
   // the two functions below: rst_counter_busy() and rst_counter_in_rst().
   // Change the counter size to adjust the time for which reset is held.
   localparam RST_CNT_WIDTH = 7
)(
   input  logic                             clk_sys,        // Global clock
   input  logic                             rst_n_sys,           

   input  logic                             clk_csr,        // Clock for pcie_flr_req/rsp
   input  logic                             rst_n_csr,

   input  pcie_ss_axis_pkg::t_axis_pcie_flr pcie_flr_req,
   output pcie_ss_axis_pkg::t_axis_pcie_flr pcie_flr_rsp,

   output logic [NUM_PF-1:0]                pf_flr_rst_n,
   output logic [NUM_PF-1:0][NUM_VF-1:0]    vf_flr_rst_n
);

//-----------------------------------
// FLR reset request
//-----------------------------------

typedef logic [RST_CNT_WIDTH-1:0] t_rst_cnt;

localparam PF_WIDTH = (NUM_PF > 1) ? $clog2(NUM_PF) : 1;
localparam VF_WIDTH = (NUM_VF > 1) ? $clog2(NUM_VF) : 1;


logic [PF_WIDTH-1:0]                           req_pf_num;
logic [VF_WIDTH-1:0]                           req_vf_num;

logic [NUM_PF-1:0]                             pf_flr_rst_in;
logic [NUM_PF-1:0]                             pf_flr_rst;
logic [NUM_PF-1:0][NUM_VF-1:0]                 vf_flr_rst_in;
logic [NUM_PF-1:0][NUM_VF-1:0]                 vf_flr_rst;

t_rst_cnt                                      pf_flr_cnt[NUM_PF-1:0];
t_rst_cnt                                      vf_flr_cnt[NUM_PF-1:0][NUM_VF-1:0];

// Is the reset counter in the trigger reset phase?
function automatic logic rst_counter_in_rst(t_rst_cnt cnt);
   // As reset begins, counters are decremented from 0. Thus the high bit
   // becomes one. Reset ends when bit RST_CNT_WIDTH-2 goes low. The recovery
   // phase then begins until bit RST_CNT_WIDTH-1 also goes low. During
   // recovery, reset will no longer be asserted but the sequence remains
   // active. The PCIe FLR response will only be sent after recovery,
   // by which time the function must be ready to accept requests.
   return cnt[RST_CNT_WIDTH-1] & cnt[RST_CNT_WIDTH-2];
endfunction

// Is a reset counter busy? A counter is busy for two phases of reset:
// reset and recovery.
function automatic logic rst_counter_busy(t_rst_cnt cnt);
   // A counter is busy only when the high bit is set. Counters are
   // updated by subtracting 1 and all bits are 0 when not in use.
   return cnt[RST_CNT_WIDTH-1];
endfunction

// PF/VF of incoming request.
assign req_pf_num = pcie_flr_req.tdata.pf[PF_WIDTH-1:0];
assign req_vf_num = pcie_flr_req.tdata.vf[VF_WIDTH-1:0];

// PF FLR reset. First decode incoming commands into individual bits in a vector.
// Use the counters below to hold pf_flr_rst for multiple cycles.
always_ff @(posedge clk_csr) begin
   if (~rst_n_csr) begin
      pf_flr_rst_in <= '0;
      pf_flr_rst <= '0;
   end else begin
      for (int p=0; p<NUM_PF; ++p) begin
         pf_flr_rst_in[p] <= (req_pf_num == p) && pcie_flr_req.tvalid && ~pcie_flr_req.tdata.vf_active;

         // Raise reset either from a new request or holding the current one
         pf_flr_rst[p] <= pf_flr_rst_in[p] || rst_counter_in_rst(pf_flr_cnt[p]);
      end
   end
end

// Counter holds PF FLR for multiple cycles. The counter is held
// at zero when not in reset and counts down when reset is triggered
// so that the high bits can be used to manage reset.
always_ff @(posedge clk_csr) begin
   for (int p=0; p<NUM_PF; ++p) begin
      if (~rst_n_csr) begin
         pf_flr_cnt[p] <= '0;
      end else begin
         if (~pf_flr_rst_in[p] && ~rst_counter_busy(pf_flr_cnt[p])) begin
            pf_flr_cnt[p] <= '0;
         end else begin
            pf_flr_cnt[p] <= pf_flr_cnt[p] - 1'b1;
         end
      end
   end
end

// VF FLR reset -- similar trigger and hold to PF reset above
always_ff @(posedge clk_csr) begin
   if (~rst_n_csr) begin
      vf_flr_rst_in <= '0;
      vf_flr_rst <= '0;
   end else begin
      for (int p=0; p<NUM_PF; ++p) begin
         for (int v=0; v<NUM_VF; ++v) begin
            vf_flr_rst_in[p][v] <= (req_pf_num == p) && (req_vf_num == v) && pcie_flr_req.tvalid && pcie_flr_req.tdata.vf_active;

            vf_flr_rst[p][v] <= vf_flr_rst_in[p][v] || rst_counter_in_rst(vf_flr_cnt[p][v]);
         end
      end
   end
end

// Count to hold VF FLR, similar to PF counters above
always_ff @(posedge clk_csr) begin
   for (int p=0; p<NUM_PF; ++p) begin
      for (int v=0; v<NUM_VF; ++v) begin
         if (~rst_n_csr) begin
            vf_flr_cnt[p][v] <= '0;
         end else begin
            if (~vf_flr_rst_in[p][v] && ~rst_counter_busy(vf_flr_cnt[p][v])) begin
               vf_flr_cnt[p][v] <= '0;
            end else begin
               vf_flr_cnt[p][v] <= vf_flr_cnt[p][v] - 1'b1;
            end
         end
      end
   end
end

generate 
   //
   // Reset wires clock crossing to the AFU global clock domain.
   //

   for (genvar p=0; p<NUM_PF; ++p) begin : pf
      fim_resync #(
         .SYNC_CHAIN_LENGTH(3),
         .WIDTH(1),
         .INIT_VALUE(0),
         .NO_CUT(1)
      ) pf_flr_resync (
         .clk   (clk_sys),
         .reset (1'b0),
         .d     (~pf_flr_rst[p]),
         .q     (pf_flr_rst_n[p])
      );
   
      for (genvar v=0; v<NUM_VF; ++v) begin : vf
         fim_resync #(
            .SYNC_CHAIN_LENGTH(3),
            .WIDTH(1),
            .INIT_VALUE(0),
            .NO_CUT(1)
         ) vf_flr_resync (
            .clk   (clk_sys),
            .reset (1'b0),
            .d     (~vf_flr_rst[p][v]),
            .q     (vf_flr_rst_n[p][v])
         );
      end
   end
endgenerate

//-----------------------------------
// FLR reset response
//-----------------------------------

pcie_ss_axis_pkg::t_axis_pcie_flr flr_rsp_dout;
logic                             flr_rsp_rdack;
logic                             flr_rsp_valid;

// Only one FLR can be outstanding per VF and VF
localparam FLR_RSP_FIFO_DEPTH = $clog2(MAX_NUM_VF + NUM_PF + 4);

// Delay the input to the FIFO so reset counter logic above stabilizes
pcie_ss_axis_pkg::t_axis_pcie_flr pcie_flr_req_q0, pcie_flr_req_q1;
always_ff @(posedge clk_csr) begin
   pcie_flr_req_q0 <= pcie_flr_req;
   pcie_flr_req_q1 <= pcie_flr_req_q0;
end

// FLR response FIFO
fim_rdack_scfifo #(
   .DATA_WIDTH   (pcie_ss_axis_pkg::T_AXIS_PCIE_FLR_WIDTH),
   .DEPTH_LOG2   (FLR_RSP_FIFO_DEPTH),  
   .USE_EAB      ("ON")
) flr_rsp_fifo (
   .clk     (clk_csr),
   .sclr    (~rst_n_csr),
   .wdata   (pcie_flr_req_q1),
   .wreq    (pcie_flr_req_q1.tvalid),
   .rdack   (flr_rsp_rdack),
   .rdata   (flr_rsp_dout),
   .rvalid  (flr_rsp_valid)
);

//
// Generate the response after the function is reenabled by the counters above.
//
wire [PF_WIDTH-1:0] rsp_pf_num = flr_rsp_dout.tdata.pf[PF_WIDTH-1:0];
wire [VF_WIDTH-1:0] rsp_vf_num = flr_rsp_dout.tdata.vf[VF_WIDTH-1:0];

wire   pf_rsp_rdy      = ~rst_counter_busy(pf_flr_cnt[rsp_pf_num]) &&
                         ~flr_rsp_dout.tdata.vf_active;
wire   vf_rsp_rdy      = ~rst_counter_busy(vf_flr_cnt[rsp_pf_num][rsp_vf_num]) &&
                         flr_rsp_dout.tdata.vf_active;

assign flr_rsp_rdack   = flr_rsp_valid && (pf_rsp_rdy || vf_rsp_rdy);

// Generate the FLR response to the PCIe SS
always_ff @(posedge clk_csr) begin
   if (~rst_n_csr) begin
      pcie_flr_rsp.tvalid <= 1'b0;
   end else begin
      pcie_flr_rsp.tvalid <= flr_rsp_rdack;
   end

   pcie_flr_rsp.tdata <= flr_rsp_dout.tdata;
end

endmodule : flr_rst_mgr

// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// Definition of AXI4-S streaming interface
//
//-----------------------------------------------------------------------------

`ifndef __OFS_AXIS_IF_SV__
`define __OFS_AXIS_IF_SV__

interface ofs_axis_if #(
    parameter TDATA_WIDTH   = 32,
    parameter TID_WIDTH     = 0,
    parameter TDEST_WIDTH   = 0,
    parameter TUSER_WIDTH   = 0
);
   localparam TKEEP_WIDTH   = TDATA_WIDTH / 8;
   localparam L_TID_WIDTH   = (TID_WIDTH == 0)   ? 1 : TID_WIDTH;
   localparam L_TDEST_WIDTH = (TDEST_WIDTH == 0) ? 1 : TDEST_WIDTH;
   localparam L_TUSER_WIDTH = (TUSER_WIDTH == 0) ? 1 : TUSER_WIDTH;
   
   logic clk;
   logic rst_n;
   logic tready;

   logic                      tvalid;
   logic  [TDATA_WIDTH-1:0]   tdata;
   logic  [TKEEP_WIDTH-1:0]   tkeep;
   logic                      tlast;
   logic  [L_TID_WIDTH-1:0]   tid;
   logic  [L_TDEST_WIDTH-1:0] tdest;
   logic  [L_TUSER_WIDTH-1:0] tuser;

   modport source (
      output clk, rst_n,
      input  tready,

      output tvalid,
      output tdata,
      output tkeep,
      output tlast,
      output tid,
      output tdest,
      output tuser
   );

   modport sink (
      input  clk, rst_n,
      output tready,

      input  tvalid,
      input  tdata,
      input  tkeep,
      input  tlast,
      input  tid,
      input  tdest,
      input  tuser
   );

`ifdef OFS_FIM_ASSERT_OFF
   `define OFS_AXIS_IF_ASSERT_OFF
`endif  // OFS_FIM_ASSERT_OFF
   
`ifndef OFS_AXIS_IF_ASSERT_OFF
// synopsys translate_off
   logic enable_assertion;

   initial begin
      enable_assertion = 1'b0;
      repeat(2) 
         @(posedge clk);

      wait (rst_n === 1'b0);
      wait (rst_n === 1'b1);
      
      enable_assertion = 1'b1;
   end

   assert_tvalid_undef_when_not_in_reset:
      assert property (@(posedge clk) disable iff (~rst_n || ~enable_assertion) (!$isunknown(tvalid)))
      else $fatal(0,$psprintf("%8t: %m ASSERTION_ERROR, rx.tvalid is undefined", $time));   

   assert_tready_undef_when_not_in_reset:
      assert property (@(posedge clk) disable iff (~rst_n || ~enable_assertion) (!$isunknown(tready)))
      else $fatal(0,$psprintf("%8t: %m ASSERTION_ERROR, tready is undefined", $time));        
   
   assert_tdata_undef_when_tvalid_high:
      assert property (@(posedge clk) disable iff (~rst_n || ~enable_assertion) (tvalid |-> !$isunknown(tdata)))
      else $fatal(0,$psprintf("%8t: %m ASSERTION_ERROR, tdata is undefined when tvalid is asserted", $time));   
   
   assert_tlast_undef_when_tvalid_high:
      assert property (@(posedge clk) disable iff (~rst_n || ~enable_assertion) (tvalid |-> !$isunknown(tlast)))
      else $fatal(0,$psprintf("%8t: %m ASSERTION_ERROR, tlast is undefined when tvalid is asserted", $time));     
   
   assert_tkeep_undef_when_tvalid_high:
      assert property (@(posedge clk) disable iff (~rst_n || ~enable_assertion) (tvalid |-> !$isunknown(tkeep)))
      else $fatal(0,$psprintf("%8t: %m ASSERTION_ERROR, tuser is undefined when tvalid is asserted", $time));    
   
   assert_tuser_undef_when_tvalid_high:
      assert property (@(posedge clk) disable iff ( (TUSER_WIDTH==0) || ~rst_n || ~enable_assertion) (tvalid |-> !$isunknown(tuser)))
      else $fatal(0,$psprintf("%8t: %m ASSERTION_ERROR, tuser is undefined when tvalid is asserted", $time));   
   
   assert_tid_undef_when_tvalid_high:
      assert property (@(posedge clk) disable iff ( (TID_WIDTH==0) || ~rst_n || ~enable_assertion) (tvalid |-> !$isunknown(tid)))
      else $fatal(0,$psprintf("%8t: %m ASSERTION_ERROR, tid is undefined when tvalid is asserted", $time));   
   
   assert_tdest_undef_when_tvalid_high:
      assert property (@(posedge clk) disable iff ( (TDEST_WIDTH==0) || ~rst_n || ~enable_assertion) (tvalid |-> !$isunknown(tdest)))
      else $fatal(0,$psprintf("%8t: %m ASSERTION_ERROR, tdest is undefined when tvalid is asserted", $time));   
   
   assert_tvalid_tready_handshake:
      assert property (@(posedge clk) disable iff (~rst_n || ~enable_assertion) ( (tvalid && ~tready) |-> ##1 tvalid))
      else $fatal(0,$psprintf("%8t: %m ASSERTION_ERROR, tvalid is dropped before acknowledged by tready", $time));

// synopsys translate_on
`endif  // OFS_AXIS_IF_ASSERT_OFF 
  
endinterface : ofs_axis_if

`endif // __OFS_AXIS_IF_SV__


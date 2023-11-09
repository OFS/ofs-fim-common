// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// AXI Streaming Interface that complies with IOFS PCIe Sub-system
//
//-----------------------------------------------------------------------------
`ifndef __PCIE_SS_AXI_IF_SV__
`define __PCIE_SS_AXI_IF_SV__

interface pcie_ss_axis_if #(
    parameter USER_W = pcie_ss_pkg::TUSER_WIDTH,
    parameter DATA_W = pcie_ss_pkg::TDATA_WIDTH
)(
   input wire clk,
   input wire rst_n
);

    localparam  KEEP_W = DATA_W/8;

    logic               tvalid;
    logic               tlast;
    logic [USER_W-1:0]  tuser_vendor;
    logic [DATA_W-1:0]  tdata;
    logic [KEEP_W-1:0]  tkeep;
    logic               tready;

    modport source (
        input  clk,
        input  rst_n,

        output tvalid,
        output tlast,
        output tuser_vendor,
        output tdata,
        output tkeep,
        input  tready
    );

    modport sink (
        input  clk,
        input  rst_n,

        input  tvalid,
        input  tlast,
        input  tuser_vendor,
        input  tdata,
        input  tkeep,
        output tready
    );

`ifdef OFS_FIM_ASSERT_OFF
   `define PCIE_SS_AXIS_IF_ASSERT_OFF
`endif  // OFS_FIM_ASSERT_OFF
   
`ifndef PCIE_SS_AXIS_IF_ASSERT_OFF
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
      assert property (@(posedge clk) disable iff ( ~rst_n || ~enable_assertion) (tvalid |-> !$isunknown(tuser_vendor)))
      else $fatal(0,$psprintf("%8t: %m ASSERTION_ERROR, tuser_vendor is undefined when tvalid is asserted", $time));   
   
   assert_tvalid_tready_handshake:
      assert property (@(posedge clk) disable iff (~rst_n || ~enable_assertion) ( (tvalid && ~tready) |-> ##1 tvalid))
      else $fatal(0,$psprintf("%8t: %m ASSERTION_ERROR, tvalid is dropped before acknowledged by tready", $time));

// synopsys translate_on
`endif  // PCIE_SS_AXIS_IF_ASSERT_OFF 

endinterface : pcie_ss_axis_if
`endif

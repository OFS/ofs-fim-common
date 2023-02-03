// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// Definition of Avalon Memory Mapped (AVMM) interface
//
//-----------------------------------------------------------------------------

`ifndef __OFS_AVMM_IF_SV__
`define __OFS_AVMM_IF_SV__

interface ofs_avmm_if #(
   parameter DATA_W  = 64,
   parameter ADDR_W  = 16,
   parameter BURST_W = 1,
   parameter SYMB_W  = 8
);
   logic clk;
   logic rst_n;

   localparam BE_W = DATA_W/SYMB_W;

   logic               write;
   logic               read;
   logic [ADDR_W-1:0]  address;
   logic [DATA_W-1:0]  writedata;
   logic [BURST_W-1:0] burstcount;
   logic [BE_W-1:0]    byteenable;
   logic 	       waitrequest;

   logic 	       writeresponsevalid;

   logic 	       readdatavalid;
   logic [DATA_W-1:0]  readdata;

   modport source (
      output clk, rst_n,
             write, writedata,
             read,
             address,
             burstcount,
             byteenable,
      input readdatavalid, readdata,
            writeresponsevalid,
            waitrequest
   );
   
   modport sink (
      output readdatavalid, readdata,
             writeresponsevalid,
             waitrequest,
      input  clk, rst_n,
             write, writedata,
             read,
             address,
             burstcount,
             byteenable
   );

   modport emif (
      output clk, rst_n,
             readdatavalid, readdata,
             waitrequest, writeresponsevalid,
      input  write, writedata,
             read,
             address,
             burstcount,
             byteenable
   );

   modport user (
      output write, writedata,
             read,
             address,
             burstcount,
             byteenable,
      input  clk, rst_n,
             readdatavalid, readdata,
             waitrequest, writeresponsevalid
   );

   
   
// `ifdef OFS_FIM_ASSERT_OFF
//    `define OFS_AVMM_IF_ASSERT_OFF
// `endif  // OFS_FIM_ASSERT_OFF
// `ifndef OFS_AVMM_IF_ASSERT_OFF
// // synopsys translate_off
//    logic enable_assertion;

//    initial begin
//       enable_assertion = 1'b0;
//       repeat(2) 
//          @(posedge clk);

//       wait (rst_n === 1'b0);
//       wait (rst_n === 1'b1);
      
//       enable_assertion = 1'b1;
//    end

//    assert_readdatavalid_undef_when_not_in_reset:
//       assert property (@(posedge clk) disable iff (~rst_n || ~enable_assertion) (!$isunknown(readdatavalid)))
//       else $fatal(0,$psprintf("%8t: %m ASSERTION_ERROR, readdatavalid is undefined", $time));   
   
//    assert_write_undef_when_not_in_reset:
//       assert property (@(posedge clk) disable iff (~rst_n || ~enable_assertion) (!$isunknown(write)))
//       else $fatal(0,$psprintf("%8t: %m ASSERTION_ERROR, write is undefined", $time));   

//    assert_read_undef_when_not_in_reset:
//       assert property (@(posedge clk) disable iff (~rst_n || ~enable_assertion) (!$isunknown(read)))
//       else $fatal(0,$psprintf("%8t: %m ASSERTION_ERROR, read is undefined", $time));   

//    assert_readdata_undef_when_readdatavalid_high:
//       assert property (@(posedge clk) disable iff (~rst_n || ~enable_assertion) (readdatavalid |-> !$isunknown(readdata)))
//       else $fatal(0,$psprintf("%8t: %m ASSERTION_ERROR, readdata is undefined when readdatavalid is asserted", $time));

//    assert_address_undef_on_write:
//       assert property (@(posedge clk) disable iff (~rst_n || ~enable_assertion) (write |-> !$isunknown(address)))
//       else $fatal(0,$psprintf("%8t: %m ASSERTION_ERROR, address is undefined when write is asserted", $time));

//    assert_address_undef_on_read:
//       assert property (@(posedge clk) disable iff (~rst_n || ~enable_assertion) (read |-> !$isunknown(address)))
//       else $fatal(0,$psprintf("%8t: %m ASSERTION_ERROR, address is undefined when read is asserted", $time));

//    assert_write_and_read:
//       assert property (@(posedge clk) disable iff (~rst_n || ~enable_assertion) (write |-> !read))
//       else $fatal(0,$psprintf("%8t: %m ASSERTION_ERROR, write & read simultaneously asserted", $time));

// // synopsys translate_on
// `endif //  `ifndef OFS_AVMM_IF_ASSERT_OFF

endinterface : ofs_avmm_if 

`endif // __OFS_AVMM_IF_SV__

// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//  Definition of ACE lite interface
//
//-----------------------------------------------------------------------------

//TBD `ifndef __OFS_FIM_ACE_LITE_IF_SV__
//TBD `define __OFS_FIM_ACE_LITE_IF_SV__

interface ofs_fim_ace_lite_if #(
   parameter AWADDR_WIDTH = 32,     //TBD
   parameter WDATA_WIDTH = 512,     //TBD
   parameter ARADDR_WIDTH = 32,     //TBD
   parameter RDATA_WIDTH = 512      //TBD
);
   // Write address channel
   logic                       awready ;
   logic [4:0]                 awid    ;
   logic                       awvalid ;
   logic [AWADDR_WIDTH-1:0]    awaddr  ;
   logic [2:0]                 awprot  ;
   logic [7:0]                 awlen   ;
   logic [2:0]                 awsize  ;
   logic [1:0]                 awburst ;
   logic [3:0]                 awcache ;
   logic [3:0]                 awqos   ;
   logic [22:0]                awuser  ;
   logic                       awlock  ;
   logic [2:0]                 awsnoop ;  
   logic [1:0]                 awdomain; 
   logic [1:0]                 awbar   ; 

   // Write data channel
   logic                       wready  ;
   logic                       wvalid  ;
   logic                       wlast   ;
   logic [WDATA_WIDTH-1:0]     wdata   ;
   logic [(WDATA_WIDTH/8-1):0] wstrb   ;

   // Write response channel
   logic                       bready  ;
   logic                       bvalid  ;
   logic [1:0]                 bresp   ;
   logic [4:0]                 bid     ;

   // Read address channel
   logic                       arready ;
   logic [4:0]                 arid    ;
   logic                       arvalid ;
   logic [ARADDR_WIDTH-1:0]    araddr  ;
   logic [2:0]                 arprot  ;
   logic [7:0]                 arlen   ;
   logic [2:0]                 arsize  ;
   logic [1:0]                 arburst ;
   logic [3:0]                 arcache ;
   logic [3:0]                 arqos   ;
   logic [22:0]                aruser  ;
   logic                       arlock  ;
   logic [3:0]                 arsnoop ;  
   logic [1:0]                 ardomain; 
   logic [1:0]                 arbar   ; 

   // Read response channel
   logic                       rready  ;
   logic                       rvalid  ;
   logic                       rlast   ;
   logic [RDATA_WIDTH-1:0]     rdata   ;
   logic [4:0]                 rid     ;
   logic [1:0]                 rresp   ;
	
   modport master (
        input  awready,
               wready, 
               bvalid, bresp,bid, 
               arready, 
               rvalid, rdata, rlast, rresp, rid,
        output awvalid, awid, awaddr, awprot,
               awlock,awcache, awqos, awuser,
               wvalid, wdata, wstrb,
               bready, wlast,awlen,
               awsize,awburst,
               awsnoop,awdomain,awbar,
               arvalid, arid, araddr, arprot,
               arlock,arcache, arqos, aruser,
               arlen, arsize, arburst,
               arsnoop,ardomain,arbar,
               rready
   );
   
   //TBDmodport req (
   //TBD     input  awready, 
   //TBD            wready, 
   //TBD            arready, 
   //TBD     output awvalid, awaddr, awprot,
   //TBD            wvalid, wdata, wstrb,
   //TBD            arvalid, araddr, arprot
   //TBD);
  
   //TBDmodport rsp (
   //TBD     input  bvalid, bresp, 
   //TBD            rvalid, rdata, rlast,rresp,
   //TBD     output bready, 
   //TBD            rready
   //TBD);

   modport slave (
        output awready,
               wready, 
               bvalid, bresp, bid, 
               arready, 
               rvalid, rdata, rlast, rresp,rid,
        input  awvalid, awid, awaddr, awprot,
               awlock,awcache, awqos, awuser,
               wvalid, wdata, wstrb,
               bready, wlast,awlen,
               awsize,awburst,
               awsnoop,awdomain,awbar,
               arvalid, arid, araddr, arprot,
               arlock,arcache, arqos, aruser,
               arlen, arsize, arburst,
               arsnoop,ardomain,arbar,
               rready
  );

endinterface : ofs_fim_ace_lite_if 
//TBD `endif // __OFS_FIM_ACE_LITE_IF_SV__

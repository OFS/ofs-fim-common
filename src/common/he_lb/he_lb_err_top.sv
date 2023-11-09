// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// -----------------------------------------------------------------------------
// Create Date  : June 2021
// Module Name  : he_lb_err_top.sv
// Project      : OFS 
// -----------------------------------------------------------------------------

import pcie_ss_pkg::*;
import pcie_ss_hdr_pkg::*;
import he_lb_pkg::*;
import prtcl_chkr_pkg::*;

module he_lb_err_top #(
  parameter PF_ID      = 0,
  parameter VF_ID      = 0,
  parameter VF_ACTIVE  = 0,
  parameter PU_MEM_REQ = 0
)
(
  input                     clk,
  input                     rst_n,

  pcie_ss_axis_if.sink      axi_rx_a_if,
  pcie_ss_axis_if.source    axi_tx_a_if,

  he_lb_emif_if.source      ext_mem_if
);

  pcie_ss_axis_if  axi_tx_if_he      ();

he_lb_top #(
         .PF_ID     ( PF_ID ),
         .VF_ID     ( VF_ID ),
         .VF_ACTIVE ( VF_ACTIVE ),
         .PU_MEM_REQ( PU_MEM_REQ)
          )
he_lb_inst(
         .clk       ( clk              ),
         .rst_n     ( rst_n            ),
         .axi_rx_a_if ( axi_rx_a_if    ),   
         .axi_rx_b_if ( axi_rx_b_if    ),   
         .axi_tx_a_if ( axi_tx_if_he   ),   
         .axi_tx_b_if ( axi_tx_b_if    )
         );
//assign axi_tx_if_he.tready    = axi_tx_if.tready      ;

`ifdef ERROR_INJ
pcie_ss_axis_if           axi_tx_if_err();
t_prtcl_chkr_err_vector   err_inj ;

always_comb
begin
err_inj                             = '0;
`ifdef err_inj16
err_inj.tx_req_counter_oflow        = 1'b1;
`endif
`ifdef err_inj14
err_inj.malformed_tlp               = 1'b1;
`endif
`ifdef err_inj13
err_inj.max_payload                 = 1'b1;
`endif
`ifdef err_inj12
err_inj.max_read_req_size           = 1'b1;
`endif
`ifdef err_inj11
err_inj.max_tag                     = 1'b1;
`endif
`ifdef err_inj10
err_inj.unaligned_addr              = 1'b1;
`endif
`ifdef err_inj9
err_inj.tag_occupied                = 1'b1;
`endif
`ifdef err_inj8
err_inj.unexp_mmio_rsp              = 1'b1;
`endif
`ifdef err_inj7
err_inj.mmio_timeout                = 1'b1;
`endif
`ifdef err_inj6
err_inj.mmio_wr_while_rst           = 1'b1;
`endif
`ifdef err_inj5
err_inj.mmio_rd_while_rst           = 1'b1;
`endif
`ifdef err_inj4
err_inj.mmio_data_payload_overrun   = 1'b1;
`endif
`ifdef err_inj3
err_inj.mmio_insufficient_data      = 1'b1;
`endif
`ifdef err_inj2
err_inj.tx_mwr_data_payload_overrun = 1'b1;
`endif
`ifdef err_inj1
err_inj.tx_mwr_insufficient_data    = 1'b1;
`endif
`ifdef err_inj0
err_inj.tx_valid_violation          = 1'b1;
`endif
end


he_lb_err
he_lb_err_inst(
         .clk       ( clk                           ),
        .axi_tx_if   (axi_tx_if_he),
        .axi_tx_if_err(axi_tx_if_err),
        .error_inj (err_inj)     
         );
assign axi_tx_if_err.tready      = axi_tx_a_if.tready ;
assign axi_tx_a_if.tvalid       = axi_tx_if_err.tvalid       ;
assign axi_tx_a_if.tlast        = axi_tx_if_err.tlast        ;
assign axi_tx_a_if.tuser_vendor = axi_tx_if_err.tuser_vendor ;
assign axi_tx_a_if.tdata        = axi_tx_if_err.tdata        ;
assign axi_tx_a_if.tkeep        = axi_tx_if_err.tkeep        ;
`else
assign axi_tx_a_if.tvalid       = axi_tx_if_he.tvalid      ;
assign axi_tx_a_if.tlast        = axi_tx_if_he.tlast       ;
assign axi_tx_a_if.tuser_vendor = axi_tx_if_he.tuser_vendor;
assign axi_tx_a_if.tdata        = axi_tx_if_he.tdata       ;
assign axi_tx_a_if.tkeep        = axi_tx_if_he.tkeep       ;
`endif
endmodule: he_lb_err_top

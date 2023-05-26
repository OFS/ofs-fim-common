// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT

// Module Name: vuart_csr
//
// BEGIN TEMPLATE

module vuart_csr
  import ofs_csr_pkg::*;
   #(parameter TID_WIDTH   = ofs_fim_cfg_pkg::MMIO_TID_WIDTH,
     parameter ADDR_WIDTH  = ofs_fim_cfg_pkg::MMIO_ADDR_WIDTH,
     parameter DATA_WIDTH  = ofs_fim_cfg_pkg::MMIO_DATA_WIDTH,
     parameter WSTRB_WIDTH = (DATA_WIDTH/8),
     parameter HI_ADDR_BIT = this_is_filled_in_by_mk_cfg_module
     )(
       input wire clk_csr
       ,input wire rst_n_csr
       
       ,input logic csr_write
       ,input logic [HI_ADDR_BIT:0] csr_waddr
       ,csr_access_type_t csr_write_type
       ,input logic [DATA_WIDTH-1:0] csr_wdata
       ,input logic [WSTRB_WIDTH-1:0] csr_wstrb
       
       ,input logic csr_read
       ,input logic [HI_ADDR_BIT:0] csr_raddr

       // #######################################################################
       // ### The following wire names are hardcoaded into the                ###
       // ### mk_cfg_module_64.pl and is used to place the final readdata on. ###
       // #######################################################################
       ,output logic [DATA_WIDTH-1:0] csr_readdata
       ,output logic csr_readdata_valid
       
       // BELOW IS A KEY PHRASE THE mk_cfg_module_64.pl
       // KEYS ON. DO NOT DELETE.
       // ***************************************
       // Start Auto generated input port list
       // ***************************************
       
       // BELOW IS A KEY PHRASE THE mk_cfg_module_64.pl
       // KEYS ON. DO NOT DELETE.
       // ***************************************
       // Start Auto generated output port list
       // ***************************************
       );
   
   
   // BELOW IS A KEY PHRASE THE mk_cfg_module_64.pl
   // KEYS ON. DO NOT DELETE.
   // ***************************************
   // Start Auto generated reg and wire decls
   // ***************************************
   
   // ***************************************
   // Start Manual reg and wire decls
   // ***************************************
   
   logic [7:0] byte_en_r3;
   csr_access_type_t       csr_write_type_r1;
   csr_access_type_t       csr_write_type_r2;
   
   logic [HI_ADDR_BIT:02]            csr_addr_r1;
   logic [07:02]            csr_addr_r2;
   logic                    csr_write_r1;
   logic                    csr_write_r2;
   logic                    core_reg_we_r3;
   logic [63:0]             csr_regwr_data_r1;
   logic [63:0]             csr_regwr_data_r2;
   logic [63:0]             csr_regwr_data_r3;
   
   logic                    csr_read_r1;
   logic                    csr_read_r2;
   logic                    csr_read_done_pulse_r2;
   logic                    csr_read_done_pulse_r3;
   logic                    csr_read_done_pulse_r4;
   
   // ######################################################################################
   // ### The wire below (rd_or_wr_r1) is a pulse used by the mk_cfg_module_64.pl script ###
   // ######################################################################################
   logic                    rd_or_wr_r1;
   
   // ***************************************
   // Start Manual RTL Coading
   // ***************************************
   
   always @(posedge clk_csr) begin
      // Note, "csr_addr_r1" is used by mk_cfg_module_64.pl
      csr_addr_r1             <= (csr_read ? csr_raddr[HI_ADDR_BIT:2] : csr_write ? csr_waddr[HI_ADDR_BIT:2] : csr_addr_r1);
      csr_addr_r2             <= csr_addr_r1[07:02]; // csr_addr_r2 used my mk_cfg_module_64.pl 
      csr_write_r1            <= csr_write & rst_n_csr;
      csr_write_r2            <= csr_write_r1;
      core_reg_we_r3          <= csr_write_r2; // high fanout net Keep simple for quartus replication.
      csr_regwr_data_r1       <= csr_wdata;
      csr_regwr_data_r2       <= csr_regwr_data_r1;
      csr_regwr_data_r3       <= csr_regwr_data_r2;
      csr_read_r1             <= csr_read & ~csr_readdata_valid;
      csr_read_r2             <= csr_read_r1;
      csr_read_done_pulse_r2  <= csr_read_r1 & ~csr_read_r2;
      csr_read_done_pulse_r3  <= csr_read_done_pulse_r2;
      csr_read_done_pulse_r4  <= csr_read_done_pulse_r3;
      csr_readdata_valid      <= csr_read_done_pulse_r4;
      
      csr_write_type_r1       <= csr_write_type;
      csr_write_type_r2       <= csr_write_type_r1;
      
      if (csr_write_type_r2 == ofs_csr_pkg::UPPER32) begin
         byte_en_r3 <= 8'hF0;
      end else if (csr_write_type_r2 == ofs_csr_pkg::LOWER32) begin
         byte_en_r3 <= 8'h0F;
      end else if (csr_write_type_r2 == ofs_csr_pkg::FULL64) begin
         byte_en_r3 <= 8'hFF;
      end else begin
         byte_en_r3 <= 8'h00;
      end
   end // always @ (posedge clk_csr)

   // ######################################################################################
   // ### The wire below (rd_or_wr_r1) is a pulse used by the mk_cfg_module_64.pl script ###
   // ######################################################################################
   assign rd_or_wr_r1 = csr_read_r1 & ~csr_read_r2
                      | csr_write_r1 & ~csr_write_r2;
   
   
   // BELOW IS A KEY PHRASE THE mk_cfg_module_64.pl
   // KEYS ON. DO NOT DELETE.
   // ***************************************
   // Start Auto generated rtl code
   // ***************************************
   
   // synopsys translate_off
   //   wire [HI_ADDR_BIT:0] csr_address_real = {1'b1, csr_address, 2'h0};
   //`ifdef loggers_on
   //   
   //   always @(posedge clk_csr) begin
   //      if (csr_read & ~csr_waitrequest) begin
   //       $display("T:%8d INFO: %m RB RD addr:%x data:%x", $time, csr_address_real, csr_readdata);
   
   //      end
   //      if (csr_write & ~csr_waitrequest) begin
   //       $display("T:%8d INFO: %m RB WR addr:%x data:%x", $time, csr_address_real, csr_wdata);
   //      end
   //   end
   //`endif
   // synopsys translate_on
   
endmodule

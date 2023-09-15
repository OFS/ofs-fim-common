// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

//
// Create Date  : Feb 2021
// Module Name  : protocol_checker_csr.sv
// Project      : OFS
// -----------------------------------------------------------------------------
//
// ***************************************************************************


// BEGIN TEMPLATE
module  example_csr
  import ofs_csr_pkg::*;
   import prtcl_chkr_pkg::*;
   #(parameter HI_ADDR_BIT = this_is_filled_in_by_mk_cfg_module
     )(
       input        clk_csr,
       input        rst_n_csr,
       input        pwr_good_csr_clk_n,
       input        clk,
       input        rst_n,
                    ofs_fim_axi_lite_if.slave csr_lite_if,
                    t_prtcl_chkr_err_vector i_error_vector,
       output logic o_clear_errors
       
       
       // BELOW IS A KEY PHRASE THE mk_cfg_module_64.pl
       // KEYS ON. DO NOT DELETE.
       // ***************************************
       // Start Auto generated input port list (string key for mk_cfg_module_64.pl)
       // ***************************************
       
       // BELOW IS A KEY PHRASE THE mk_cfg_module_64.pl
       // KEYS ON. DO NOT DELETE.
       // ***************************************
       // Start Auto generated output port list (string key for mk_cfg_module_64.pl)
       // ***************************************
       );
   
   // BELOW IS A KEY PHRASE THE mk_cfg_module_64.pl
   // KEYS ON. DO NOT DELETE.
   // ***************************************
   // Start Auto generated reg and wire decls
   // ***************************************
   
   // ***************************************
   // Start Manual reg and wire decls (string key for mk_cfg_module_64.pl)
   // ***************************************
   logic [7:0]      byte_en_r3;
   csr_access_type_t       csr_write_type;
   csr_access_type_t       csr_write_type_r1;
   csr_access_type_t       csr_write_type_r2;
   
   logic [HI_ADDR_BIT:02] csr_addr_r1;
   logic [07:02]          csr_addr_r2;
   logic                  csr_write_r1;
   logic                  csr_write_r2;
   logic                  core_reg_we_r3;
   logic [63:0]           csr_regwr_data_r1;
   logic [63:0]           csr_regwr_data_r2;
   logic [63:0]           csr_regwr_data_r3;
   
   logic                  csr_read_r1;
   logic                  csr_read_r2;
   logic                  csr_read_done_pulse_r2;
   logic                  csr_read_done_pulse_r3;
   logic                  csr_read_done_pulse_r4;
   
   // The following wire name (rd_or_wr_r1) is hard-coaded into the mk_cfg_module and is basically a pulse to start a read or a write.
   wire                 rd_or_wr_r1 = (csr_read_r1 & ~csr_read_r2) | (csr_write_r1 & ~csr_write_r2);
   
   //-------------------------------------
   // Signals
   //-------------------------------------
   ofs_fim_axi_mmio_if     csr_if();
   
   logic [HI_ADDR_BIT:0] csr_waddr;
   logic [63:0]          csr_wdata;
   logic                 csr_write;
   
   logic [HI_ADDR_BIT:0] csr_raddr;
   logic                 csr_read;
   logic                 csr_read_32b;

   // #######################################################################
   // ### The following wire names are hardcoaded into the                ###
   // ### mk_cfg_module_64.pl and is used to place the final readdata on. ###
   // #######################################################################
   logic [63:0]          csr_readdata;
   logic                 csr_readdata_valid;
   
   // ##################################################################
   // ### Below here is logic specific to the example_csr CSRs only. ###
   // ##################################################################
   t_prtcl_chkr_err_vector error_vector_r2;
   t_prtcl_chkr_err_vector error_vector_r3;
   t_prtcl_chkr_err_vector error_vector_r4;
   t_prtcl_chkr_err_vector error_vector_r5;
   t_prtcl_chkr_err_vector error_vector_r6;
   t_prtcl_chkr_err_vector error_vector_or;
   t_prtcl_chkr_err_vector error_vector_csr;
   
   logic                 freeze_first_err_regs;

   // ***************************************
   // Start Manual RTL Coading (common to all templates)
   // ***************************************
   
   axi_lite2mmio axi_lite2mmio (
                                .clk    (clk_csr),
                                .rst_n  (rst_n_csr),
                                .lite_if(csr_lite_if),
                                .mmio_if(csr_if)
                                );
   
   //---------------------------------
   // Map AXI write/read request to CSR write/read,
   // and send the write/read response back
   //---------------------------------
   ofs_fim_axi_csr_slave mc_csr_slave (
                                       .csr_if             (csr_if),
                                       
                                       .csr_write          (csr_write),
                                       .csr_waddr          (csr_waddr),
                                       .csr_write_type     (csr_write_type),
                                       .csr_wdata          (csr_wdata),
                                       .csr_wstrb          (),
                                       
                                       .csr_read           (csr_read),
                                       .csr_raddr          (csr_raddr),
                                       .csr_read_32b       (csr_read_32b),
                                       .csr_readdata       (csr_readdata),
                                       .csr_readdata_valid (csr_readdata_valid)
                                       );
   
   always @(posedge clk_csr) begin
      csr_addr_r1             <= (csr_read ? csr_raddr[HI_ADDR_BIT:2] : csr_write ? csr_waddr[HI_ADDR_BIT:2] : csr_addr_r1); // csr_addr_r1 used my mk_cfg_module_64.pl
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
   
   
   // ##############################################
   // ### The code below here is specific to the ###
   // ### example CSRs only.(It is not part      ###
   // ### of the common template)                ###
   // ##############################################
   always_ff @(posedge clk) begin
      error_vector_r2 <= i_error_vector;
      error_vector_r3 <= error_vector_r2 | i_error_vector;
      error_vector_r4 <= error_vector_r3 | error_vector_r2;
      error_vector_r5 <= error_vector_r4 | error_vector_r3;
      error_vector_r6 <= error_vector_r5 | error_vector_r4;
      error_vector_or <= error_vector_r2 | error_vector_r3 |
                         error_vector_r4 | error_vector_r5 |
                         error_vector_r6;
      
   end
   
   // good enough for now
   fim_resync #(
                .SYNC_CHAIN_LENGTH(3),
                .WIDTH($bits(t_prtcl_chkr_err_vector)),
                .INIT_VALUE(0),
                .NO_CUT(0)
                ) rst_hs_resync (
                                 .clk   (clk_csr),
                                 .reset (!rst_n_csr),
                                 .d     (error_vector_or),
                                 .q     (error_vector_csr)
                                 );
   
   //----------------------------------------------------------------------------
   // FIRST ERROR signals
   //----------------------------------------------------------------------------
   assign freeze_first_err_regs = max_read_req_size_err_reg |
                                  max_tag_err_reg |
                                  unexp_mmio_rsp_err_reg |
                                  mmio_timeout_err_reg |
                                  mmio_data_payload_overrun_err_reg |
                                  mmio_insufficient_data_err_reg;
   assign o_clear_errors = 0;
   
   // ##################################
   // ### for 0x78 bits 22:19 exmple ###
   // ##################################
   assign interl_load_term = csr_write_r1;
   assign internal_data_bus = csr_addr_r1[05:02];
   // the above is just a silly example. we load address bits 5:2 to the register on every csr_write
   
   
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

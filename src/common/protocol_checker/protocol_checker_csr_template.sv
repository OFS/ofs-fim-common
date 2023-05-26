// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT
//
// Create Date  : Feb 2021
// Module Name  : protocol_checker_csr.sv
// Project      : OFS
// -----------------------------------------------------------------------------
//
// ***************************************************************************


// BEGIN TEMPLATE
module  protocol_checker_csr
  import ofs_csr_pkg::*;
   import prtcl_chkr_pkg::*;
   #(parameter HI_ADDR_BIT = this_is_filled_in_by_mk_cfg_module
     )(
       input        clk_csr,
       input        rst_n_csr,
       input        pwr_good_csr_clk_n,
       input        pwr_good_clk_n,
       input        clk,
       input        rst_n,
       input        i_blocking_traffic,
       ofs_fim_axi_lite_if.slave csr_lite_if,
       t_prtcl_chkr_err_vector i_error_vector,
       t_mmio_timeout_hdr_info i_mmio_timeout_info,
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
   // Start Auto generated reg and wire decls (string key for mk_cfg_module_64.pl)
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
   
   // ######################################################################################
   // ### The wire below (rd_or_wr_r1) is a pulse used by the mk_cfg_module_64.pl script ###
   // ######################################################################################
   logic                  rd_or_wr_r1;
   
   //-------------------------------------
   // Signals
   //-------------------------------------
   ofs_fim_axi_mmio_if     csr_if();
   
   logic [HI_ADDR_BIT:0]  csr_waddr;
   logic [63:0]           csr_wdata;
   logic                  csr_write;
   
   logic [HI_ADDR_BIT:0]  csr_raddr;
   logic                  csr_read;
   logic                  csr_read_32b;
   
   // #######################################################################
   // ### The following wire names are hardcoaded into the                ###
   // ### mk_cfg_module_64.pl and is used to place the final readdata on. ###
   // #######################################################################
   logic [63:0]           csr_readdata;
   logic                  csr_readdata_valid;
   
   // #################################################################
   // ### Below here is specific to the protocol checker CSRs only. ###
   // ### It is not part of the common template                     ###
   // #################################################################
   t_prtcl_chkr_err_vector error_vector_r2;
   t_prtcl_chkr_err_vector error_vector_r3;
   t_prtcl_chkr_err_vector error_vector_r4;
   t_prtcl_chkr_err_vector error_vector_r5;
   t_prtcl_chkr_err_vector error_vector_r6;
   t_prtcl_chkr_err_vector error_vector_or;
   t_prtcl_chkr_err_vector error_vector_csr;
   
   logic                  freeze_first_err_regs;
   logic                  blockingtraffic; // When a one is returned on blockingtraffic, it signifies that the RTL is
   logic                  timeout_info_regs_locked_down;
   
   
   // blocking traffic as a result of the protocol error logic detecting an
   // error. We never actually set this bit to one in the rtl, It is done by
   // a completion timeout that retuens all F's (signifying that we are
   // blocking traffic). The bit is only here so that is is not mistakenly
   
   // ***************************************
   // Start Manual RTL Coading (common to all templates)
   // ***************************************
   
   axi_lite2mmio axi_lite2mmio
     (
      .clk    (clk_csr),
      .rst_n  (rst_n_csr),
      .lite_if(csr_lite_if),
      .mmio_if(csr_if)
      );
   
   //---------------------------------
   // Map AXI write/read request to CSR write/read,
   // and send the write/read response back
   //---------------------------------
   ofs_fim_axi_csr_slave mc_csr_slave
     (
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
   
   // ######################################################################################
   // ### The wire below (rd_or_wr_r1) is a pulse used by the mk_cfg_module_64.pl script ###
   // ######################################################################################
   assign rd_or_wr_r1 = csr_read_r1 & ~csr_read_r2
                      | csr_write_r1 & ~csr_write_r2;
   
   
   // #################################################################
   // ### Below here is specific to the protocol checker CSRs only. ###
   // ### It is not part of the common template                     ###
   // #################################################################
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
   
   //error_vector_csr.set_tx_req_counter_oflow_err = 1'b0;                                      // 15
   assign   set_malformed_tlp_err               = error_vector_csr.malformed_tlp;               // 14
   assign   set_max_payload_err                 = error_vector_csr.max_payload;                 // 13
   assign   set_max_read_req_size_err           = error_vector_csr.max_read_req_size;           // 12
   assign   set_max_tag_err                     = error_vector_csr.max_tag;                     // 11
   //error_vector_csr.set_unaligned_addr_err    = 1'b0;                                         // 10
   //error_vector_csr.set_tag_occupied_err      = 1'b0;                                         // 09
   assign   set_unexp_mmio_rsp_err              = error_vector_csr.unexp_mmio_rsp;              // 08
   assign   set_mmio_timeout_err                = error_vector_csr.mmio_timeout;                // 07
   //error_vector_csr.set_mmio_wr_while_rst_err = 1'b0;                                         // 06
   //error_vector_csr.set_mmio_rd_while_rst_err = 1'b0;                                         // 05
   assign   set_mmio_data_payload_overrun_err   = error_vector_csr.mmio_data_payload_overrun;   // 04
   assign   set_mmio_insufficient_data_err      = error_vector_csr.mmio_insufficient_data;      // 03
   assign   set_tx_mwr_data_payload_overrun_err = error_vector_csr.tx_mwr_data_payload_overrun; // 02
   assign   set_tx_mwr_insufficient_data_err    = error_vector_csr.tx_mwr_insufficient_data;    // 01
   //error_vector_csr.set_tx_valid_violation_err    = 1'b0;                                     // 00                
   
   assign  blockingtraffic = 0;             // confused for a reserved bit
   
   //----------------------------------------------------------------------------
   // FIRST ERROR signals
   //----------------------------------------------------------------------------
   assign freeze_first_err_regs = malformed_tlp_err_reg |
                                  max_payload_err_reg |
                                  max_read_req_size_err_reg |
                                  max_tag_err_reg |
                                  unexp_mmio_rsp_err_reg |
                                  mmio_timeout_err_reg |
                                  mmio_data_payload_overrun_err_reg |
                                  mmio_insufficient_data_err_reg |
                                  tx_mwr_data_payload_overrun_err_reg |
                                  tx_mwr_insufficient_data_err_reg;
   assign o_clear_errors = 0;
   
   assign vf_num_ferr_load_data = i_vf_num_load_data;
   
   assign timeout_regs_frozen_load_data = i_error_vector.mmio_timeout | timeout_info_regs_locked_down;
   
   always @(posedge clk) begin
      if (~pwr_good_clk_n) begin
         timeout_info_regs_locked_down                <= 1'b0;
      end else if (i_error_vector.mmio_timeout) begin
         timeout_info_regs_locked_down                <= 1'b1;
      end
   end

   always @(posedge clk) begin
      if (~timeout_regs_frozen_load_data) begin
         addr_timeout_csr_reg_load_data             <= i_mmio_timeout_info.addr;
         tag_timeout_csr_reg_load_data              <= i_mmio_timeout_info.tag;
         dw0_len_timeout_csr_reg_load_data          <= i_mmio_timeout_info.dw0_len;
         requester_id_timeout_csr_reg_load_data     <= i_mmio_timeout_info.requester_id;
      end
      
   end
   
   
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

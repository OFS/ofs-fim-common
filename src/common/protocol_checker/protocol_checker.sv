// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT
//
// Considers DM PCie Packet sizes/widths

import pcie_ss_hdr_pkg::*;

module protocol_checker #
  (
   parameter ENABLE_TAG_OCCUPIED_CHECK = 1,
   
   parameter FMTTYPE_W        = 8,
   parameter LEN_W            = 24,
   parameter TAG_W            = 10,
   parameter ADDR_W           = 64,
   parameter DATA_W           = 512,
   parameter PCIE_EP_MAX_TAGS = 96,
   parameter MAX_PLD_SIZE     = 512, //bytes
   parameter MAX_RD_REQ_SIZE  = 512  //bytes
   )
   (
    input logic                  clk,
    input logic                  rst_n,
    input logic                  i_afu_softreset,
    input logic                  i_afu_softreset_dlyd,
    
    input logic                  i_tx_valid_r1,
    input logic                  i_tx_valid_sop_r1,
    input logic                  i_tx_valid_eop_r1,
    input logic [FMTTYPE_W-1:0]  i_tx_fmttype_r1,
    input logic [LEN_W-1:0]      i_tx_length_r1, //Bytes
    input logic [TAG_W-1:0]      i_tx_tag_r1,
    input logic [(DATA_W/8)-1:0] i_tx_keep_r1,
    input logic [ADDR_W-1:0]     i_tx_addr_r1,
    input logic                  i_tx_mwr_r1,
    input logic                  i_tx_mrd_r1,
    input logic                  i_tx_cpld_r1,
    input logic [11:0]           i_tx_cpl_r1d_bytecount_r1,
    input logic                  i_tx_ready_r1, // this is trdy / almost_full from the port_tx_fifo registered one time.
    input logic [10:0]           i_tx_vf_num_r1,
    input logic                  i_tx_vf_active_r1,
    input logic                  i_tx_hdr_is_pu_mode_r1,
    
    input logic                  i_rx_valid_sop_r1,
    input logic                  i_rx_mrd_r1,
    input logic                  i_rx_mwr_r1,
    
    output logic                 o_malformed_tlp_err,
    output logic                 o_max_payload_err,
    output logic                 o_max_read_req_size_err,
    output logic                 o_tx_mwr_insufficient_data_err,
    output logic                 o_tx_mwr_data_payload_overrun_err,
    output logic                 o_mmio_insufficient_data_err,
    output logic                 o_mmio_data_payload_overrun_err,
    output logic                 o_max_tag_err,
    output logic                 o_mmio_rd_while_rst_err,
    output logic                 o_mmio_wr_while_rst_err,
    output logic [10:0]          o_vf_num
    );
   
   logic                         tx_valid_r2, tx_valid_r3, tx_valid_r4;
   logic                         tx_valid_sop_r2, tx_valid_sop_r3, tx_valid_sop_r4;
   logic                         tx_valid_eop_r2, tx_valid_eop_r3, tx_valid_eop_r4;
   logic                         tx_mwr_r2, tx_mwr_r3, tx_mwr_r4;
   logic                         tx_hdr_is_pu_mode_r2;
   
   logic                         tx_mrd_r2;
   logic                         tx_cpld_r2;

   logic                         rx_valid_sop_r2;
   logic                         rx_mrd_r2;
   logic                         rx_mwr_r2;

   logic [11:0]                  tx_cpld_bytecount_r2;
   logic [10:0]                  tx_vf_num_r2   ;
   logic                         tx_vf_active_r2;
   logic                         tx_ready_r2, tx_ready_r3, tx_ready_r4, tx_ready_r5;
   logic [FMTTYPE_W-1:0]         tx_fmttype_r2;
   logic [LEN_W-1:0]             tx_length_r2, tx_length_r3, tx_length_r4; //Bytes
   logic [TAG_W-1:0]             tx_tag_r2;
   logic [(DATA_W/8)-1:0]        tx_keep_r1;
   logic [ADDR_W-1:0]            tx_addr_r2;
   logic [LEN_W-1:0]             mwr_length_r5; //Bytes
   logic [LEN_W-1:0]             acc_len;    //Bytes

   logic                         fmttype_ok_r2;
   logic [6:0]                   num_valid_bytes_r3;
   
   
   assign tx_keep_r1 = i_tx_keep_r1; // We need to make this as fast as possiable to catch the overrun / insuff error in port_tx_fifo
   // i_tx_keep_r1 is registered just before the input of this module so we should be ok on timing.
   // Possibilities - CPL (MMIO), DMRD, DMWR
   always_ff @(posedge clk) begin
      tx_valid_r2     <= i_tx_valid_r1;
      tx_valid_sop_r2 <= i_tx_valid_sop_r1;
      tx_valid_eop_r2 <= i_tx_valid_eop_r1;
      tx_fmttype_r2   <= i_tx_fmttype_r1;
      tx_length_r2    <= i_tx_length_r1;
      tx_tag_r2       <= i_tx_tag_r1;
      tx_mwr_r2       <= i_tx_mwr_r1;
      tx_mrd_r2       <= i_tx_mrd_r1;
      tx_cpld_r2      <= i_tx_cpld_r1;
      tx_cpld_bytecount_r2 <= i_tx_cpl_r1d_bytecount_r1;
      tx_addr_r2      <= i_tx_addr_r1;
      tx_ready_r2     <= i_tx_ready_r1;
      tx_vf_num_r2    <= i_tx_vf_num_r1    ;
      tx_vf_active_r2 <= i_tx_vf_active_r1 ;
      tx_hdr_is_pu_mode_r2 <= i_tx_hdr_is_pu_mode_r1;
      
      tx_valid_r3     <= tx_valid_r2;
      tx_valid_sop_r3 <= tx_valid_sop_r2;
      tx_valid_eop_r3 <= tx_valid_eop_r2;
      tx_mwr_r3       <= tx_mwr_r2;
      tx_length_r3    <= tx_length_r2;
      tx_ready_r3     <= tx_ready_r2;
      
      tx_valid_r4     <= tx_valid_r3;
      tx_valid_sop_r4 <= tx_valid_sop_r3;
      tx_valid_eop_r4 <= tx_valid_eop_r3;
      tx_mwr_r4       <= tx_mwr_r3;
      tx_length_r4    <= tx_length_r3;
      tx_ready_r4     <= tx_ready_r3;
      
      tx_ready_r5     <= tx_ready_r4;
      
      rx_valid_sop_r2 <= i_rx_valid_sop_r1;
      rx_mrd_r2       <= i_rx_mrd_r1;
      rx_mwr_r2       <= i_rx_mwr_r1;
   end // always_ff @ (posedge clk)
   
   //===============================================================================================
   // Malformed_tlp_err - AFU TLP contains unsupported format type
   //===============================================================================================
   //The FmtTypes below are the valid ones. If AFU sends a fmttype outside of the
   //set below during a sop this will be a malformed TLP error.
   assign fmttype_ok_r2 = (tx_fmttype_r2 == pcie_ss_hdr_pkg::PCIE_FMTTYPE_MEM_READ32) |
                          (tx_fmttype_r2 == pcie_ss_hdr_pkg::PCIE_FMTTYPE_MEM_READ64) |
                          (tx_fmttype_r2 == pcie_ss_hdr_pkg::PCIE_FMTTYPE_MEM_WRITE32) |
                          (tx_fmttype_r2 == pcie_ss_hdr_pkg::PCIE_FMTTYPE_MEM_WRITE64) |
                          (tx_fmttype_r2 == pcie_ss_hdr_pkg::PCIE_FMTTYPE_CFG_WRITE) |
                          (tx_fmttype_r2 == pcie_ss_hdr_pkg::PCIE_FMTTYPE_CPL) |
                          (tx_fmttype_r2 == pcie_ss_hdr_pkg::PCIE_FMTTYPE_CPLD) |
                          (tx_fmttype_r2 == pcie_ss_hdr_pkg::PCIE_FMTTYPE_FETCH_ADD32) |
                          (tx_fmttype_r2 == pcie_ss_hdr_pkg::PCIE_FMTTYPE_FETCH_ADD64) |
                          (tx_fmttype_r2 == pcie_ss_hdr_pkg::PCIE_FMTTYPE_SWAP32) |
                          (tx_fmttype_r2 == pcie_ss_hdr_pkg::PCIE_FMTTYPE_SWAP64) |
                          (tx_fmttype_r2 == pcie_ss_hdr_pkg::PCIE_FMTTYPE_CAS32) |
                          (tx_fmttype_r2 == pcie_ss_hdr_pkg::PCIE_FMTTYPE_CAS64) |
                          (tx_fmttype_r2 == pcie_ss_hdr_pkg::DM_INTR) |
                          (tx_fmttype_r2[7:3] == pcie_ss_hdr_pkg::PCIE_FMTTYPE_MSGWD) |
                          (tx_fmttype_r2[7:3] == pcie_ss_hdr_pkg::PCIE_FMTTYPE_MSGWOD);
   always_ff @(posedge clk) begin
      o_malformed_tlp_err <= tx_valid_sop_r2 & ~fmttype_ok_r2 & tx_ready_r2;
   end
   
   //===============================================================================================
   // Max Payload Size
   // Max Read Reqiest Size
   //===============================================================================================
   always_ff @(posedge clk) begin
      if(i_afu_softreset_dlyd) begin
         o_max_payload_err       <= 1'b0;
         o_max_read_req_size_err <= 1'b0;
      end else begin
         o_max_payload_err       <= 1'b0;
         o_max_read_req_size_err <= 1'b0;
         
         if(tx_valid_sop_r2 & tx_mwr_r2 & tx_hdr_is_pu_mode_r2 & tx_ready_r2 & (tx_length_r2 > MAX_PLD_SIZE)) begin
            o_max_payload_err <= 1'b1;
         end
         
         if(tx_valid_sop_r2 & tx_mrd_r2 & tx_hdr_is_pu_mode_r2 & tx_ready_r2 & ((tx_length_r2 > MAX_RD_REQ_SIZE) | (tx_length_r2 == 0))) begin  // afu_tx_hdr_is_pu_mode_r1 is timed to SOP
            o_max_read_req_size_err <= 1'b1;
         end
      end // else: !if(i_afu_softreset_dlyd)
   end // always_ff @ (posedge clk)
   
   //===============================================================================================
   // MWr Overrun
   //===============================================================================================
   logic mwr_r5;
   always_ff @ (posedge clk) begin
      if(i_afu_softreset_dlyd)
        begin
           o_tx_mwr_data_payload_overrun_err <= 1'b0;
           o_tx_mwr_insufficient_data_err    <= 1'b0;
           acc_len                           <= '0;
           mwr_r5                            <= 1'b0;
           mwr_length_r5                     <= '0;
        end else begin
           o_tx_mwr_data_payload_overrun_err <= 1'b0;
           o_tx_mwr_insufficient_data_err    <= 1'b0;
           
           //Buffer length on SOP
           if(tx_valid_sop_r4 && tx_mwr_r4 & tx_ready_r4) begin
              mwr_length_r5 <= tx_length_r4;
           end
           
           if (tx_valid_eop_r4 & tx_ready_r4)
             mwr_r5 <= 1'b0;
           else if (tx_valid_sop_r4 & tx_ready_r4)
             mwr_r5 <= tx_mwr_r4;
           
           if(tx_valid_eop_r4 && (mwr_r5 | tx_mwr_r4) & tx_ready_r4) begin
              if (tx_valid_sop_r4) begin
                 // Write data fits in the SOP beat (according to tlast). Test that the
                 // length matches the EOP claim.
                 o_tx_mwr_insufficient_data_err    <= (tx_length_r4 > (DATA_W/8)/2);
              end else begin
                 // Multi-beat write
                 if (mwr_r5) begin
                    o_tx_mwr_data_payload_overrun_err <= (mwr_length_r5 < (acc_len + num_valid_bytes_r3) & tx_ready_r5);
                    o_tx_mwr_insufficient_data_err    <= (mwr_length_r5 > (acc_len + num_valid_bytes_r3) & tx_ready_r5);
                 end
              end
              
              acc_len <= '0;
           end else begin
              // Accumulative length
              if(tx_valid_sop_r4 && tx_mwr_r4)
                acc_len <= acc_len + ((DATA_W/8)/2);
              else if(tx_valid_r4 && !tx_valid_sop_r4 && !tx_valid_eop_r4 & tx_ready_r4 & mwr_r5)
                acc_len <= acc_len + (DATA_W/8);
           end
        end // else: !if(i_afu_softreset_dlyd)
   end // always_ff @ (posedge clk)
   
   
   pri_enc_64_6 #(
`ifdef SIM_MODE
                  .SIM_EMULATE(1'b1)
`else
                  .SIM_EMULATE(1'b0)
`endif
                  )
   pri_enc
     (
      .clk  (clk),
      .din  (~tx_keep_r1),       //R1
      .dout (num_valid_bytes_r3) //R3
      );
   
   //===============================================================================================
   // MMIO Insufficient Data Error
   //===============================================================================================
   always_ff @ (posedge clk) begin
      if(i_afu_softreset_dlyd) begin
         o_mmio_data_payload_overrun_err <= 1'b0;
         o_mmio_insufficient_data_err    <= 1'b0;
      end else begin
         o_mmio_data_payload_overrun_err <= 1'b0;
         o_mmio_insufficient_data_err    <= 1'b0;
         if(tx_valid_sop_r2 & tx_cpld_r2 & tx_ready_r2) begin
            //MMIO Response should have atleast 4B
            if((tx_length_r2 < 'h4) & tx_ready_r2)
              o_mmio_insufficient_data_err <= 1'b1;
            
            //4B MMIO response should have a non-0 byte count
            if((tx_length_r2 == 'h4) && (tx_cpld_bytecount_r2 == 'h0) & tx_ready_r2)
              o_mmio_insufficient_data_err <= 1'b1;
            
            //8B MMIO response should have 5-8 bytes
            if((tx_length_r2 == 'h8) && (tx_cpld_bytecount_r2 <= 'h4) & tx_ready_r2)
              o_mmio_insufficient_data_err <= 1'b1;
            
            
            // Only one-cycle CPLD allowed. So if we haven't completed the packet on
            // SOP, we have data overrun.
            if ((tx_valid_eop_r2 == 0) & tx_ready_r2)
              o_mmio_data_payload_overrun_err <= 1'b1;
            
            //4B MMIO response should not have byte count greater than 4B
            //Expecting 1-4 bytes
            if((tx_length_r2 == 'h4) && (tx_cpld_bytecount_r2 > 'h4) & tx_ready_r2)
              o_mmio_data_payload_overrun_err <= 1'b1;
            
            //8B MMIO response should not have byte count greater than 8B
            if((tx_length_r2 == 'h8) && (tx_cpld_bytecount_r2 > 'h8) & tx_ready_r2)
              o_mmio_data_payload_overrun_err <= 1'b1;
         end // if (tx_valid_sop_r2 & tx_cpld_r2)
      end // else: !if(i_afu_softreset_dlyd)
   end // always_ff @ (posedge clk)
   
   
   
   //===============================================================================================
   // Max Tag: AFU memory read request tag value exceeds the maximum supported tag count
   //===============================================================================================
   always_ff @ (posedge clk) begin
      if(i_afu_softreset_dlyd) begin
         o_max_tag_err <= 1'b0;
      end else begin
         o_max_tag_err <= 1'b0;
         
         if(tx_valid_sop_r2 && tx_mrd_r2 && (tx_tag_r2 > PCIE_EP_MAX_TAGS) & tx_ready_r2) begin
            o_max_tag_err <= 1'b1;
         end
      end
   end // always_ff @ (posedge clk)
   
   //===============================================================================================
   // MMIO Read while AFU is in reset
   //===============================================================================================
   always_ff @(posedge clk) begin
      if(i_afu_softreset_dlyd) begin
         o_mmio_rd_while_rst_err <= 1'b0;
      end else begin
         o_mmio_rd_while_rst_err <= 1'b0;
         
         if(i_afu_softreset && rx_valid_sop_r2 && rx_mrd_r2) begin
            o_mmio_rd_while_rst_err <= 1'b1; // This goes nowhere
         end
      end
   end // always_ff @ (posedge clk)
   
   //===============================================================================================
   // MMIO Write while AFU is in reset
   //===============================================================================================
   always_ff @(posedge clk) begin
      if(i_afu_softreset_dlyd) begin
         o_mmio_wr_while_rst_err <= 1'b0;
      end else begin
         
         o_mmio_wr_while_rst_err <= 1'b0;
         
         if(i_afu_softreset && rx_valid_sop_r2 && rx_mwr_r2) begin
            o_mmio_wr_while_rst_err <= 1'b1; // This goes nowhere
         end
      end
   end // always_ff @ (posedge clk)
   
   //Capture VF_NUM
   assign o_vf_num =  (tx_vf_active_r2 & tx_ready_r2) ? (tx_vf_num_r2 & {11{tx_ready_r2}}) : 'd0 ;
   
endmodule

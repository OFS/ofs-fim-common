// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT
//
// This is the AC file...

//Assumes TX will be PU_CPL is always CPLD
//Assumes TX will be DM_Rd/DMWr

module afu_intf # (
                   parameter ENABLE           = 1,
                   // Disable tag occupied check by default. When the checker is on the HIP
                   // side of tag_remap(), the remapper guarantees unique tags independent
                   // of AFU-generated duplicate tags. It is an expensive check, especially
                   // for large tag spaces.
                   parameter ENABLE_TAG_OCCUPIED_CHECK = 0,
                   
                   parameter FMTTYPE_W        = 8,
                   parameter LEN_W            = 24,
                   parameter TAG_W            = 10,
                   parameter ADDR_W           = 64,
                   parameter DATA_W           = 512,
                   parameter PCIE_EP_MAX_TAGS = 96,
                   parameter MAX_PLD_SIZE     = 512, //bytes
                   //parameter MAX_RD_REQ_SIZE  = 256  //bytes
                   parameter MAX_RD_REQ_SIZE  = 512  //bytes
                   
                   )
   (
    input logic  clk,
    input logic  rst_n,
    
    input logic  clk_csr,
    input logic  rst_n_csr,
    input logic  pwr_good_csr_clk_n,
    
    input logic  i_afu_softreset,
    
    output logic o_sel_mmio_rsp,
    output logic o_read_flush_done,
    
    // PCIe SS -> AFU_INTF
    // SINK is INPUTS to this module (excpt tready which is an output)
    // This will mostely be completions to the AFU or new read requests somewhere.
    // N2S Transactions raw into this module.
    pcie_ss_axis_if.sink h2a_axis_rx,
    // TO THE HOST !!! SOURCE is OUTPUTS from this module (excpt tready which is an input)
    // S2N Transactions.
    pcie_ss_axis_if.source a2h_axis_tx,
    
    // AFU_INTF <-> PF_VF_MUX
    // SOURCE is OUTPUTS from this module (excpt tready which is an input)
    // N2S transations from this module
    pcie_ss_axis_if.source afu_axis_rx,
    
    // FROM THE AFU !!! SINK is INPUTS to this module (excpt tready which is an output)
    // S2N Transactions.
    pcie_ss_axis_if.sink afu_axis_tx,
    
    ofs_fim_axi_lite_if.slave csr_if
    
    );
   
   //import packages here:
   import pcie_ss_hdr_pkg::*;
   import prtcl_chkr_pkg::*;
   
   
   localparam [8:0] SOFTRESET_DELAY = 9'd20;
   
   pcie_ss_axis_if  tx_st_r4();
   logic         tx_f_fifo_if_sop_r4;
   pcie_ss_axis_if  tx_f_fifo_mmio_if();
   logic         tx_f_fifo_mmio_if_sop;
   pcie_ss_axis_if  tx_port_control_if();
   
   logic         afu_tx_valid_r1;
   logic         afu_tx_valid_sop_r1;
   logic         afu_tx_valid_eop_r1;
   logic [FMTTYPE_W-1:0] afu_tx_fmttype_r1;
   logic [LEN_W-1:0]     afu_tx_length_r1;   //Bytes
   logic [TAG_W-1:0]     afu_tx_tag_r1;
   logic [(DATA_W/8)-1:0] afu_tx_keep_r1;
   logic [ADDR_W-1:0]     afu_tx_addr_r1;
   logic                  afu_tx_vf_active_r1 ;
   logic [10:0]           afu_tx_vf_num_r1    ;
   logic                  afu_tx_mwr_r1;
   logic                  afu_tx_mrd_r1;
   logic                  afu_tx_cpld_r1;
   logic [11:0]           afu_tx_cpld_bytecount_r1;
   logic                  afu_tx_ready_r1;
   
   logic                  afu_rx_valid_sop_r1;
   logic                  afu_rx_valid_eop_r1;
   logic [FMTTYPE_W-1:0]  afu_rx_fmttype_r1;
   logic [LEN_W-1:0]      afu_rx_length_r1;   //Bytes
   logic [TAG_W-1:0]      afu_rx_tag_r1;
   logic [ADDR_W-1:0]     afu_rx_addr_r1;
   logic [15:0]           afu_rx_req_id_r1;
   logic                  afu_rx_mrd_r1;
   logic                  afu_rx_mwr_r1;
   
   logic                  afu_tx_hdr_is_pu_mode;
   logic                  tx_hdr_is_pu_mode_r1;
   logic                  tx_hdr_is_pu_mode_r2;
   logic                  tx_hdr_is_pu_mode_r3;
   logic                  tx_hdr_is_pu_mode_r4;
   logic                  tx_hdr_is_pu_mode_r5;

   logic                  tx_hdr_is_pu_mode_load_data;

   PCIe_PUCplHdr_t         afu_tx_pu_cpl;
   PCIe_CplHdr_t           afu_tx_dm_cpl;
   PCIe_ReqHdr_t           afu_tx_dm_req;
   PCIe_PUReqHdr_t         afu_tx_pu_req;
   
   logic                  afu_rx_hdr_is_pu_mode;
   PCIe_PUCplHdr_t         afu_rx_pu_cpl;
   PCIe_CplHdr_t           afu_rx_dm_cpl;
   PCIe_PUReqHdr_t         afu_rx_pu_req;
   
   logic                  malformed_tlp_err;
   logic                  max_payload_err;
   logic                  max_read_req_size_err;
   logic                  tx_mwr_insufficient_data_err;
   logic                  tx_mwr_data_payload_overrun_err;
   logic                  mmio_insufficient_data_err;
   logic                  mmio_data_payload_overrun_err;
   logic                  max_tag_err;
   logic                  mmio_rd_while_rst_err;
   logic                  mmio_wr_while_rst_err;
   logic                  mmio_timeout_err;
   logic                  unexp_mmio_rsp_err;
   logic [10:0]           vf_num;
   
   logic [TAG_W-1:0]      tx_f_fifo_rsp_tag;
   logic                  tx_f_fifo_cpl;
   logic                  tx_f_fifo_cpld;
   logic                  next_pending_mmio_rdy;
   logic                  flush_mmio_rsp_queue_complete;
   logic                  blocking_traffic;
   logic                  blocking_traffic_fast;
   logic                  mmio_rd_rsp_ack;
   logic                  tag_occupied_err;
   t_mmio_timeout_hdr_info mmio_timeout_info;
   t_prtcl_chkr_err_vector error_vector;
   logic                  block_traffic;
   
   logic                  clear_errors;
   
   logic [8:0]            afu_softreset_count;
   logic                  afu_softreset_dlyd;
   
   logic                  tx_f_fifo_valid_sop_cmpl;
   
   assign afu_tx_hdr_is_pu_mode = pcie_ss_hdr_pkg::func_hdr_is_pu_mode(afu_axis_tx.tuser_vendor);
   assign afu_tx_pu_cpl = afu_axis_tx.tdata[255:0];
   assign afu_tx_dm_cpl = afu_axis_tx.tdata[255:0];
   assign afu_tx_dm_req = afu_axis_tx.tdata[255:0];
   assign afu_tx_pu_req = afu_axis_tx.tdata[255:0];
   
   assign afu_rx_hdr_is_pu_mode = pcie_ss_hdr_pkg::func_hdr_is_pu_mode(afu_axis_rx.tuser_vendor);
   assign afu_rx_pu_cpl = afu_axis_rx.tdata[255:0];
   assign afu_rx_dm_cpl = afu_axis_rx.tdata[255:0];
   assign afu_rx_pu_req = afu_axis_rx.tdata[255:0];
   
   // NEW SOP EOP In Progress stuff.
   logic                  h2a_axis_rx_valid; // N2S input  into this module
   logic                  a2h_axis_tx_valid; // S2N output from this module
   logic                  afu_axis_rx_valid; // N2S output from this module
   logic                  afu_axis_tx_valid; // S2N input  into this module
   
   logic                  h2a_axis_rx_valid_sop;
   logic                  h2a_axis_rx_valid_eop;
   logic                  a2h_axis_tx_valid_sop;
   logic                  a2h_axis_tx_valid_eop;
   logic                  afu_axis_rx_valid_sop;
   logic                  afu_axis_rx_valid_eop;
   logic                  afu_axis_tx_valid_sop;
   logic                  afu_axis_tx_valid_eop;
   
   logic                  h2a_axis_rx_trans_in_progress;
   logic                  a2h_axis_tx_trans_in_progress;
   logic                  afu_axis_rx_trans_in_progress;
   logic                  afu_axis_tx_trans_in_progress;
   
   logic                  h2a_axis_rx_trans_in_progress_real;
   logic                  a2h_axis_tx_trans_in_progress_real;
   logic                  afu_axis_rx_trans_in_progress_real;
   logic                  afu_axis_tx_trans_in_progress_real;
   
   logic [63:0]           errored_header;
   logic [63:0]           errored_address;
   logic [127:0]          tx_header_r1;
   logic [127:0]          tx_header_r2;
   logic [127:0]          tx_header_r3;
   logic [127:0]          tx_header_r4;
   logic [127:0]          tx_header_r5;

   logic [63:0]           tx_header_error_255_192_load_data;
   logic [63:0]           tx_header_error_191_128_load_data;
   logic [63:0]           tx_header_error_127_64_load_data;
   logic [63:0]           tx_header_error_63_00_load_data;

   logic                  malformed_tlp_frozen;
   logic                  max_payload_frozen;
   logic                  max_read_req_size_frozen;
   logic                  max_tag_frozen;
   logic                  unexp_mmio_rsp_frozen;
   logic                  mmio_data_payload_overrun_frozen;
   logic                  mmio_insufficient_data_frozen;
   logic                  tx_mwr_data_payload_overrun_frozen;
   logic                  tx_mwr_insufficient_data_frozen;

   logic                  r3_frozen;
   logic                  r5_frozen;
   logic afu_tx_hdr_is_pu_mode_r1;

   always_comb begin
      h2a_axis_rx_valid     = h2a_axis_rx.tvalid & h2a_axis_rx.tready;
      a2h_axis_tx_valid     = a2h_axis_tx.tvalid & a2h_axis_tx.tready;
      afu_axis_rx_valid     = afu_axis_rx.tvalid & afu_axis_rx.tready;
      afu_axis_tx_valid     = afu_axis_tx.tvalid & afu_axis_tx.tready; // this tready is almost_full from the port_fifo
      
      h2a_axis_rx_valid_sop = h2a_axis_rx_valid & ~h2a_axis_rx_trans_in_progress;
      a2h_axis_tx_valid_sop = a2h_axis_tx_valid & ~a2h_axis_tx_trans_in_progress;
      afu_axis_rx_valid_sop = afu_axis_rx_valid & ~afu_axis_rx_trans_in_progress;
      afu_axis_tx_valid_sop = afu_axis_tx_valid & ~afu_axis_tx_trans_in_progress;
      h2a_axis_rx_valid_eop = h2a_axis_rx_valid & h2a_axis_rx.tlast;
      a2h_axis_tx_valid_eop = a2h_axis_tx_valid & a2h_axis_tx.tlast;
      afu_axis_rx_valid_eop = afu_axis_rx_valid & afu_axis_rx.tlast;
      afu_axis_tx_valid_eop = afu_axis_tx_valid & afu_axis_tx.tlast;
   end
   
   // Create transaction in progress signals. The "real" will include the "SOP" time
   always_ff @(posedge clk) begin
      if (~rst_n) begin  // Comming out of rst_n, we should only consider tx_valid_sop to begin a new transcation.
         h2a_axis_rx_trans_in_progress <= 1'b0;
         a2h_axis_tx_trans_in_progress <= 1'b0;
         afu_axis_rx_trans_in_progress <= 1'b0;
         afu_axis_tx_trans_in_progress <= 1'b0;
      end else begin
         h2a_axis_rx_trans_in_progress <= h2a_axis_rx_valid_sop & ~h2a_axis_rx_valid_eop |
                                          h2a_axis_rx_trans_in_progress & ~h2a_axis_rx_valid_eop;
         a2h_axis_tx_trans_in_progress <= a2h_axis_tx_valid_sop & ~a2h_axis_tx_valid_eop |
                                          a2h_axis_tx_trans_in_progress & ~a2h_axis_tx_valid_eop;
         afu_axis_rx_trans_in_progress <= afu_axis_rx_valid_sop & ~afu_axis_rx_valid_eop |
                                          afu_axis_rx_trans_in_progress & ~afu_axis_rx_valid_eop;
         afu_axis_tx_trans_in_progress <= afu_axis_tx_valid_sop & ~afu_axis_tx_valid_eop |
                                          afu_axis_tx_trans_in_progress & ~afu_axis_tx_valid_eop;
      end // else: !if(~rst_n)
   end // always @ (posedge clk)
   
   // "real" includes sop.
   assign h2a_axis_rx_trans_in_progress_real = h2a_axis_rx_trans_in_progress | h2a_axis_rx_valid_sop;
   assign a2h_axis_tx_trans_in_progress_real = a2h_axis_tx_trans_in_progress | a2h_axis_tx_valid_sop;
   assign afu_axis_rx_trans_in_progress_real = afu_axis_rx_trans_in_progress | afu_axis_rx_valid_sop;
   assign afu_axis_tx_trans_in_progress_real = afu_axis_tx_trans_in_progress | afu_axis_tx_valid_sop;
   
   // DONE Inprogress / sop / eop
   
   always_comb begin
      //RX
      afu_axis_rx.tvalid        = h2a_axis_rx.tvalid;
      afu_axis_rx.tlast         = h2a_axis_rx.tlast;
      afu_axis_rx.tuser_vendor  = h2a_axis_rx.tuser_vendor;
      afu_axis_rx.tdata         = h2a_axis_rx.tdata;
      afu_axis_rx.tkeep         = h2a_axis_rx.tkeep;
      
      h2a_axis_rx.tready        = afu_axis_rx.tready;
      
      //TX NOTE: The a2h_axis_tx goes directly to the host (Well, the PCIe_SS)
      // ######################################################################
      // ############  IF if (ENABLE ##########################################
      // ######################################################################
      if(ENABLE) begin
         a2h_axis_tx.tvalid        = tx_port_control_if.tvalid;
         a2h_axis_tx.tlast         = tx_port_control_if.tlast;
         a2h_axis_tx.tuser_vendor  = tx_port_control_if.tuser_vendor;
         a2h_axis_tx.tdata         = tx_port_control_if.tdata;
         a2h_axis_tx.tkeep         = tx_port_control_if.tkeep;
         
         tx_port_control_if.tready = a2h_axis_tx.tready;
      end else begin // if not ENABLE S2N transactions go directly to the host (Well, the PCIe_SS)
         a2h_axis_tx.tvalid        = afu_axis_tx.tvalid;
         a2h_axis_tx.tlast         = afu_axis_tx.tlast;
         a2h_axis_tx.tuser_vendor  = afu_axis_tx.tuser_vendor;
         a2h_axis_tx.tdata         = afu_axis_tx.tdata;
         a2h_axis_tx.tkeep         = afu_axis_tx.tkeep;
         afu_axis_tx.tready        = a2h_axis_tx.tready;
      end // else: !if(ENABLE)
   end // always_comb
   
           
   // Signals to protocol checker
   always_ff @ (posedge clk) begin
      //if (afu_axis_tx.tready) begin
      afu_tx_hdr_is_pu_mode_r1 <= afu_tx_hdr_is_pu_mode;
      
      //TX
      afu_tx_valid_r1              <= afu_axis_tx.tvalid;
      afu_tx_valid_sop_r1          <= afu_axis_tx_valid_sop;
      afu_tx_valid_eop_r1          <= afu_axis_tx_valid_eop;
      
      afu_tx_fmttype_r1            <= afu_axis_tx.tdata[31:24];
      
      //CPL in TX direction will be PU CPL (length in DWord)
      if(afu_axis_tx.tdata[31:24] == DM_CPL)
        begin
           // Note DW to Bytes (afu_tx_pu_cpl.length width is 10 bits). afu_tx_length_r1 is 24 bits.                
           afu_tx_length_r1           <= (afu_tx_pu_cpl.length == '0) ? 24'd4096 : afu_tx_pu_cpl.length << 2; // DW to Bytes
           
           afu_tx_tag_r1              <= {afu_tx_pu_cpl.tag_h,
                                          afu_tx_pu_cpl.tag_m,
                                          afu_tx_pu_cpl.tag_l};
        end else begin //DM/PU Req
           afu_tx_length_r1           <= afu_tx_hdr_is_pu_mode ?
                                         afu_tx_pu_req.length << 2 :  //DW to Bytes
                                         {afu_tx_dm_req.length_h, //length_h = 12 bits, length_m = 10 bits,  length_l = 2 bits = 24 bits
                                          afu_tx_dm_req.length_m,
                                          afu_tx_dm_req.length_l};
           
           afu_tx_tag_r1              <= afu_tx_hdr_is_pu_mode ?
                                         {afu_tx_pu_req.tag_h,
                                          afu_tx_pu_req.tag_m,
                                          afu_tx_pu_req.tag_l} :
                                         {afu_tx_dm_req.tag_h,
                                          afu_tx_dm_req.tag_m,
                                          afu_tx_dm_req.tag_l};
        end
      
      afu_tx_vf_active_r1          <= afu_tx_hdr_is_pu_mode ? afu_tx_pu_req.vf_active:afu_tx_dm_req.vf_active;
      afu_tx_vf_num_r1             <= afu_tx_hdr_is_pu_mode ? afu_tx_pu_req.vf_num:afu_tx_dm_req.vf_num;
      afu_tx_keep_r1               <= afu_axis_tx.tkeep;
      afu_tx_addr_r1               <= afu_tx_hdr_is_pu_mode ?
                                      {afu_tx_pu_req.host_addr_h,
                                       afu_tx_pu_req.host_addr_l,
                                       2'b0} :
                                      {afu_tx_dm_req.host_addr_h,
                                       afu_tx_dm_req.host_addr_m,
                                       afu_tx_dm_req.host_addr_l};
      
      // Treat atomic operations as both read and write
      afu_tx_mwr_r1                <= (afu_tx_hdr_is_pu_mode ? ((afu_tx_pu_req.fmt_type == DM_WR) |(afu_tx_pu_req.fmt_type == M_WR)):(afu_tx_dm_req.fmt_type == DM_WR)) ||
                                      func_is_atomic_req(afu_tx_dm_req.fmt_type);
      afu_tx_mrd_r1                <= (afu_tx_hdr_is_pu_mode ? ((afu_tx_pu_req.fmt_type == DM_RD) |(afu_tx_pu_req.fmt_type == M_RD)):(afu_tx_dm_req.fmt_type == DM_RD)) ||
                                      func_is_atomic_req(afu_tx_dm_req.fmt_type);
      afu_tx_cpld_r1               <= (afu_tx_pu_cpl.fmt_type == DM_CPL);
      afu_tx_cpld_bytecount_r1     <= afu_tx_pu_cpl.byte_count;
      
      afu_tx_ready_r1              <= afu_axis_tx.tready; // This is tready / almost_full from the port_tx_fifo
      
      //RX
      afu_rx_valid_sop_r1          <= afu_axis_rx_valid_sop;
      afu_rx_valid_eop_r1          <= afu_axis_rx_valid_eop;
      afu_rx_fmttype_r1            <= afu_axis_rx.tdata[31:24];
      
      // CPL in RX direction
      if(afu_axis_rx.tdata[31:24] == DM_CPL) begin // DM/PU CPL
         afu_rx_length_r1           <= afu_rx_hdr_is_pu_mode ?
                                       afu_rx_pu_cpl.length << 2 :  //DW to Bytes
                                       {afu_rx_dm_cpl.length_h,
                                        afu_rx_dm_cpl.length_m,
                                        afu_rx_dm_cpl.length_l};
         
         afu_rx_tag_r1              <= afu_rx_hdr_is_pu_mode ?
                                       {afu_rx_pu_cpl.tag_h,
                                        afu_rx_pu_cpl.tag_m,
                                        afu_rx_pu_cpl.tag_l} :
                                       afu_rx_dm_cpl.tag;
      end else begin //PU Req
         //afu_rx_length_r1           <= {LEN_W{1'b0}};
         afu_rx_length_r1           <= afu_rx_pu_req.length;
         afu_rx_tag_r1              <= {afu_rx_pu_req.tag_h,
                                        afu_rx_pu_req.tag_m,
                                        afu_rx_pu_req.tag_l};
      end
      
      if(afu_axis_rx.tdata[29]) begin
         afu_rx_addr_r1               <= {afu_axis_rx.tdata[95:64], afu_axis_rx.tdata[127:96]};
      end else begin
         afu_rx_addr_r1               <= {32'h0, afu_axis_rx.tdata[95:64]};
      end

      afu_rx_req_id_r1             <= afu_rx_pu_req.req_id;
      
      afu_rx_mrd_r1                <= afu_rx_hdr_is_pu_mode ? ((afu_rx_pu_req.fmt_type == M_RD)|(afu_rx_pu_req.fmt_type == DM_RD)) : (afu_rx_pu_cpl.fmt_type ==M_RD) ;
      afu_rx_mwr_r1                <= 1'b0;
   end // always_ff @ (posedge clk)
   
   always_comb begin
      error_vector                             = '0;
      error_vector.tx_req_counter_oflow        = 1'b0;                               // 15
      error_vector.malformed_tlp               = malformed_tlp_err;                  // 14
      error_vector.max_payload                 = max_payload_err;                    // 13
      error_vector.max_read_req_size           = max_read_req_size_err;              // 12
      error_vector.max_tag                     = max_tag_err;                        // 11
      error_vector.unaligned_addr              = 1'b0;                               // 10
      error_vector.tag_occupied                = 1'b0;                               // 09
      error_vector.unexp_mmio_rsp              = unexp_mmio_rsp_err;                 // 08
      error_vector.mmio_timeout                = mmio_timeout_err;                   // 07
      error_vector.mmio_wr_while_rst           = 1'b0;                               // 06
      error_vector.mmio_rd_while_rst           = 1'b0;                               // 05
      error_vector.mmio_data_payload_overrun   = mmio_data_payload_overrun_err;      // 04
      error_vector.mmio_insufficient_data      = mmio_insufficient_data_err;         // 03
      error_vector.tx_mwr_data_payload_overrun = tx_mwr_data_payload_overrun_err;    // 02
      error_vector.tx_mwr_insufficient_data    = tx_mwr_insufficient_data_err;       // 01
      error_vector.tx_valid_violation          = 1'b0;                               // 00
      
      block_traffic                            = |error_vector  ; // comment out and assign to zero if you do not wish to see any hardware
      // affected by the error. CSR registers will still log the error.
   end
   
   protocol_checker_csr protocol_checker_csr
     (
      .clk_csr              (clk_csr),
      .rst_n_csr            (rst_n_csr),
      .pwr_good_csr_clk_n   (pwr_good_csr_clk_n),
      .pwr_good_clk_n       (pwr_good_csr_clk_n),
      
      .clk                  (clk),
      .rst_n                (rst_n),
      .i_blocking_traffic   (blocking_traffic),
      .csr_lite_if          (csr_if),
      .i_error_vector       (error_vector),
      .i_vf_num_load_data   (vf_num),
      
      .i_mmio_immediate_frozen_load_data  (r3_frozen | r5_frozen),
      .i_tx_header_error_255_192_load_data(tx_header_error_255_192_load_data),
      .i_tx_header_error_191_128_load_data(tx_header_error_191_128_load_data),
      .i_tx_header_error_127_64_load_data (tx_header_error_127_64_load_data),
      .i_tx_header_error_63_00_load_data  (tx_header_error_63_00_load_data),
      .i_tx_hdr_is_pu_mode_load_data      (tx_hdr_is_pu_mode_load_data),
      
      .i_mmio_timeout_info                (mmio_timeout_info),
      .o_clear_errors                     (clear_errors)
      );
   
   
   
   
   if(ENABLE) begin
      
      protocol_checker #(
                         .ENABLE_TAG_OCCUPIED_CHECK(ENABLE_TAG_OCCUPIED_CHECK),
                         .FMTTYPE_W        (FMTTYPE_W       ),
                         .LEN_W            (LEN_W           ),
                         .TAG_W            (TAG_W           ),
                         .ADDR_W           (ADDR_W          ),
                         .DATA_W           (DATA_W          ),
                         .PCIE_EP_MAX_TAGS (PCIE_EP_MAX_TAGS),
                         .MAX_PLD_SIZE     (MAX_PLD_SIZE    ),
                         .MAX_RD_REQ_SIZE  (MAX_RD_REQ_SIZE )
                         )
      protocol_checker_inst
        (
         .clk                                 (clk),
         .rst_n                               (rst_n),
         .i_afu_softreset                     (i_afu_softreset),
         .i_afu_softreset_dlyd                (afu_softreset_dlyd),
         
         .i_tx_valid_r1                       (afu_tx_valid_r1),
         .i_tx_valid_sop_r1                   (afu_tx_valid_sop_r1),
         .i_tx_valid_eop_r1                   (afu_tx_valid_eop_r1),
         .i_tx_fmttype_r1                     (afu_tx_fmttype_r1),
         .i_tx_length_r1                      (afu_tx_length_r1),
         .i_tx_tag_r1                         (afu_tx_tag_r1),
         .i_tx_keep_r1                        (afu_tx_keep_r1),
         .i_tx_addr_r1                        (afu_tx_addr_r1),
         .i_tx_mwr_r1                         (afu_tx_mwr_r1),
         .i_tx_mrd_r1                         (afu_tx_mrd_r1),
         .i_tx_cpld_r1                        (afu_tx_cpld_r1),
         .i_tx_cpl_r1d_bytecount_r1           (afu_tx_cpld_bytecount_r1),
         .i_tx_ready_r1                       (afu_tx_ready_r1), // this is trdy / almost_full from the port_tx_fifo registered one time.
         .i_tx_vf_num_r1                      (afu_tx_vf_num_r1),
         .i_tx_vf_active_r1                   (afu_tx_vf_active_r1),
         .i_tx_hdr_is_pu_mode_r1              (afu_tx_hdr_is_pu_mode_r1),
         
         .i_rx_valid_sop_r1                   (afu_rx_valid_sop_r1),
         .i_rx_mrd_r1                         (afu_rx_mrd_r1),
         .i_rx_mwr_r1                         (afu_rx_mwr_r1),
         
         .o_malformed_tlp_err                 (malformed_tlp_err),
         .o_max_payload_err                   (max_payload_err),
         .o_max_read_req_size_err             (max_read_req_size_err),
         .o_tx_mwr_insufficient_data_err      (tx_mwr_insufficient_data_err),
         .o_tx_mwr_data_payload_overrun_err   (tx_mwr_data_payload_overrun_err),
         .o_mmio_insufficient_data_err        (mmio_insufficient_data_err),
         .o_mmio_data_payload_overrun_err     (mmio_data_payload_overrun_err),
         .o_max_tag_err                       (max_tag_err),
         .o_mmio_rd_while_rst_err             (mmio_rd_while_rst_err),
         .o_mmio_wr_while_rst_err             (mmio_wr_while_rst_err),
         .o_vf_num                            ()
         );
      
      assign vf_num = '0;
      
      tx_filter tx_filter_inst
        (
         .clk                                 (clk),
         .rst_n                               (rst_n),
         
         .i_afu_softreset                     (i_afu_softreset),
         .i_clear_errors                      (clear_errors),
         .i_block_traffic                     (block_traffic),
         .i_mmio_timeout_info                 (mmio_timeout_info),
         .i_mmio_timeout_err                  (mmio_timeout_err),
         .i_next_pending_mmio_rdy             (next_pending_mmio_rdy),
         .i_flush_mmio_rsp_queue_complete     (flush_mmio_rsp_queue_complete),
         
         .o_blocking_traffic                  (blocking_traffic),
         .o_blocking_traffic_fast             (blocking_traffic_fast),
         .o_mmio_rd_rsp_ack                   (mmio_rd_rsp_ack),
         
         .i_tx_st                             (afu_axis_tx),
         .i_tx_st_sop                         (afu_axis_tx_valid_sop),
         .o_tx_st_r4                          (tx_st_r4),
         .o_tx_st_sop_r4                      (tx_f_fifo_if_sop_r4),
         .o_mmio_rsp_tx_st                    (tx_f_fifo_mmio_if),
         .o_mmio_rsp_tx_st_sop                (tx_f_fifo_mmio_if_sop),
         .o_tx_header_r1                      (tx_header_r1),
         .o_tx_header_r2                      (tx_header_r2),
         .o_tx_header_r3                      (tx_header_r3),
         .o_tx_header_r4                      (tx_header_r4),
         .o_tx_header_r5                      (tx_header_r5),
         .i_tx_hdr_is_pu_mode_r0              (afu_tx_hdr_is_pu_mode),
         .o_tx_hdr_is_pu_mode_r1              (tx_hdr_is_pu_mode_r1),
         .o_tx_hdr_is_pu_mode_r2              (tx_hdr_is_pu_mode_r2),
         .o_tx_hdr_is_pu_mode_r3              (tx_hdr_is_pu_mode_r3),
         .o_tx_hdr_is_pu_mode_r4              (tx_hdr_is_pu_mode_r4),
         .o_tx_hdr_is_pu_mode_r5              (tx_hdr_is_pu_mode_r5)
         );
      
      mmio_handler mmio_handler_inst
        (
         .clk                                  (clk),
         .rst_n                                (rst_n),
         
         .i_rx_valid_sop_r1                    (afu_rx_valid_sop_r1),
         .i_rx_mrd_r1                          (afu_rx_mrd_r1),
         .i_rx_req_tag_r1                      (afu_rx_tag_r1),
         .i_rx_req_dw0_len_r1                  (afu_rx_length_r1),
         .i_rx_requester_id_r1                 (afu_rx_req_id_r1),
         .i_rx_rd_req_addr_r1                  (afu_rx_addr_r1[31:0]),
         .i_tx_valid_sop_r1                    (afu_tx_valid_sop_r1),
         .i_tx_rsp_tag_r1                      (afu_tx_tag_r1),
         .i_tx_cpl_r1                          (afu_tx_cpld_r1),
         .i_tx_cpld_r1                         (afu_tx_cpld_r1),
         
         .i_tx_f_fifo_valid_sop_cmpl           (tx_f_fifo_valid_sop_cmpl),
         .i_tx_f_fifo_rsp_tag                  (tx_f_fifo_rsp_tag),
         
         .o_next_pending_mmio_rdy              (next_pending_mmio_rdy),
         .o_flush_mmio_rsp_queue_complete      (flush_mmio_rsp_queue_complete),
         .i_blocking_traffic                   (blocking_traffic),
         .i_mmio_rd_rsp_ack                    (mmio_rd_rsp_ack),
         .o_mmio_timeout_info                  (mmio_timeout_info),
         .o_mmio_timeout_err                   (mmio_timeout_err),
         .o_unexp_mmio_rsp_err                 (unexp_mmio_rsp_err)
         );
   end else begin
      assign blocking_traffic                = 1'b0;
      assign blocking_traffic_fast           = 1'b0;
      assign mmio_rd_rsp_ack                 = 1'b0;
      assign tx_f_fifo_cpld                  = 1'b0;
      assign tx_f_fifo_cpl                   = 1'b0;
      
      assign malformed_tlp_err               = '0;
      assign max_payload_err                 = '0;
      assign max_read_req_size_err           = '0;
      assign tx_mwr_insufficient_data_err    = '0;
      assign tx_mwr_data_payload_overrun_err = '0;
      assign mmio_insufficient_data_err      = '0;
      assign mmio_data_payload_overrun_err   = '0;
      assign max_tag_err                     = '0;
      assign mmio_rd_while_rst_err           = '0;
      assign mmio_wr_while_rst_err           = '0;
      assign tag_occupied_err                = '0;
      assign vf_num                          = '0;
   end
   
   // Traffic Controller
   port_traffic_control port_traffic_control_inst
     (
      .clk                        (clk),
      .rst_n                      (rst_n),
      
      .o_sel_mmio_rsp             (o_sel_mmio_rsp),
      .o_read_flush_done          (o_read_flush_done),
      .o_tx_f_fifo_valid_sop_cmpl (tx_f_fifo_valid_sop_cmpl),
      .o_tx_f_fifo_rsp_tag        (tx_f_fifo_rsp_tag),
      .i_blocking_traffic_fast    (blocking_traffic_fast),
      
      .i_tx_hdr_is_pu_mode_r0     (afu_tx_hdr_is_pu_mode),
      .i_tx_st_r4                 (tx_st_r4),          // input r4. The ready on this bus is port_tx_fifo almost full
      .i_mmio_rsp                 (tx_f_fifo_mmio_if), // input for fake split completions.
      
      .o_tx_st                    (tx_port_control_if) // output to the PCIE_ss
      );
   
   // Create a afu_softreset with a delayed asserting edge
   always_ff @(posedge clk) begin
      if (~rst_n) begin
         afu_softreset_count <= SOFTRESET_DELAY;
      end else if (~i_afu_softreset) begin
         afu_softreset_count <= 0;
      end else if (afu_softreset_count < SOFTRESET_DELAY) begin
         afu_softreset_count <= afu_softreset_count + 1;
      end else begin
         afu_softreset_count <= afu_softreset_count;
      end
      afu_softreset_dlyd <= (afu_softreset_count >= SOFTRESET_DELAY);
   end
   
   always_ff @(posedge clk) begin
      if (afu_axis_tx_valid_sop & ~blocking_traffic) begin
         errored_header  <= afu_axis_tx.tdata[63:0];
         errored_address <= afu_axis_tx.tdata[127:64];
      end
   end
   
   always_ff @(posedge clk) begin
      if (~pwr_good_csr_clk_n) begin
         malformed_tlp_frozen <= 1'b0;
      end else if (error_vector.malformed_tlp)
        malformed_tlp_frozen <= 1'b1;
   end
   
   always_ff @(posedge clk) begin
      if (~pwr_good_csr_clk_n) begin
         max_payload_frozen <= 1'b0;
      end else if (error_vector.max_payload)
        max_payload_frozen <= 1'b1;
   end
   
   always_ff @(posedge clk) begin
      if (~pwr_good_csr_clk_n) begin
         max_read_req_size_frozen <= 1'b0;
      end else if (error_vector.max_read_req_size)
        max_read_req_size_frozen <= 1'b1;
   end
   
   always_ff @(posedge clk) begin
      if (~pwr_good_csr_clk_n) begin
         max_tag_frozen <= 1'b0;
      end else if (error_vector.max_tag)
        max_tag_frozen <= 1'b1;
   end
   
   always_ff @(posedge clk) begin
      if (~pwr_good_csr_clk_n) begin
         unexp_mmio_rsp_frozen <= 1'b0;
      end else if (error_vector.unexp_mmio_rsp)
        unexp_mmio_rsp_frozen <= 1'b1;
   end
   
   // mmio_timeout will not lock down these errors
   
   always_ff @(posedge clk) begin
      if (~pwr_good_csr_clk_n) begin
         mmio_data_payload_overrun_frozen <= 1'b0;
      end else if (error_vector.mmio_data_payload_overrun)
        mmio_data_payload_overrun_frozen <= 1'b1;
   end
   
   
   always_ff @(posedge clk) begin
      if (~pwr_good_csr_clk_n) begin
         mmio_insufficient_data_frozen <= 1'b0;
      end else if (error_vector.mmio_insufficient_data)
        mmio_insufficient_data_frozen <= 1'b1;
   end
   
   always_ff @(posedge clk) begin
      if (~pwr_good_csr_clk_n) begin
         tx_mwr_data_payload_overrun_frozen <= 1'b0;
      end else if (error_vector.tx_mwr_data_payload_overrun)
        tx_mwr_data_payload_overrun_frozen <= 1'b1;
   end
   
   
   always_ff @(posedge clk) begin
      if (~pwr_good_csr_clk_n) begin
         tx_mwr_insufficient_data_frozen <= 1'b0;
      end else if (error_vector.tx_mwr_insufficient_data)
        tx_mwr_insufficient_data_frozen <= 1'b1;
   end
   
   assign r3_frozen = malformed_tlp_frozen |
                      max_payload_frozen |
                      max_read_req_size_frozen |
                      max_tag_frozen |                   // Timing verified.
                      unexp_mmio_rsp_frozen |
                      mmio_data_payload_overrun_frozen |
                      mmio_insufficient_data_frozen;
   
   assign r5_frozen = tx_mwr_data_payload_overrun_frozen |
                      tx_mwr_insufficient_data_frozen;
   
   always_ff @(posedge clk) begin
      if (r3_frozen | r5_frozen) begin
         tx_header_error_255_192_load_data <= 64'h0;
         tx_header_error_191_128_load_data <= 64'h0;
         tx_header_error_127_64_load_data  <= tx_header_error_127_64_load_data;
         tx_header_error_63_00_load_data   <= tx_header_error_63_00_load_data;
         tx_hdr_is_pu_mode_load_data       <= tx_hdr_is_pu_mode_load_data;
      end else if (~r3_frozen) begin
         tx_header_error_255_192_load_data <= 64'h0;
         tx_header_error_191_128_load_data <= 64'h0;
         tx_header_error_127_64_load_data  <= tx_header_r3[127:64];
         tx_header_error_63_00_load_data   <= tx_header_r3[63:0];
         tx_hdr_is_pu_mode_load_data       <= tx_hdr_is_pu_mode_r3;
      end else if (~r5_frozen) begin
         tx_header_error_255_192_load_data <= 64'h0;
         tx_header_error_191_128_load_data <= 64'h0;
         tx_header_error_127_64_load_data  <= tx_header_r5[127:64];
         tx_header_error_63_00_load_data   <= tx_header_r5[63:0];
         tx_hdr_is_pu_mode_load_data       <= tx_hdr_is_pu_mode_r5;
      end 
   end // always_ff @ (posedge clk)
   
   // synthesis translate_off
   static int log_fd;
   
   initial
     begin : log
        log_fd = $fopen("log_ofs_fim_afu_intf.tsv", "w");
        
        // Write module hierarchy to the top of the log
        $fwrite(log_fd, "afu_intf.sv: %m\n\n");
        
        forever @(posedge clk) begin
           // TX from AFU
           if (rst_n && afu_axis_tx.tvalid && afu_axis_tx.tready)
             begin
                $fwrite(log_fd, "afu_axis_tx: %s\n",
                        pcie_ss_pkg::func_pcie_ss_flit_to_string(
                                                                 afu_axis_tx_valid_sop, afu_axis_tx.tlast,
                                                                 pcie_ss_hdr_pkg::func_hdr_is_pu_mode(afu_axis_tx.tuser_vendor),
                                                                 afu_axis_tx.tdata, afu_axis_tx.tkeep));
                $fflush(log_fd);
             end
           
           // TX to host
           if (rst_n && a2h_axis_tx.tvalid && a2h_axis_tx.tready)
             begin
                $fwrite(log_fd, "a2h_axis_tx: %s\n",
                        pcie_ss_pkg::func_pcie_ss_flit_to_string(
                                                                 a2h_axis_tx_valid_sop, a2h_axis_tx.tlast,
                                                                 pcie_ss_hdr_pkg::func_hdr_is_pu_mode(a2h_axis_tx.tuser_vendor),
                                                                 a2h_axis_tx.tdata, a2h_axis_tx.tkeep));
                $fflush(log_fd);
             end
           
           // RX from host
           if (rst_n && h2a_axis_rx.tvalid && h2a_axis_rx.tready)
             begin
                $fwrite(log_fd, "h2a_axis_rx: %s\n",
                        pcie_ss_pkg::func_pcie_ss_flit_to_string(
                                                                 h2a_axis_rx_valid_sop, h2a_axis_rx.tlast,
                                                                 pcie_ss_hdr_pkg::func_hdr_is_pu_mode(h2a_axis_rx.tuser_vendor),
                                                                 h2a_axis_rx.tdata, h2a_axis_rx.tkeep));
                $fflush(log_fd);
             end
           
           // RX to AFU
           if (rst_n && afu_axis_rx.tvalid && afu_axis_rx.tready)
             begin
                $fwrite(log_fd, "afu_axis_rx: %s\n",
                        pcie_ss_pkg::func_pcie_ss_flit_to_string(
                                                                 afu_axis_rx_valid_sop, afu_axis_rx.tlast,
                                                                 pcie_ss_hdr_pkg::func_hdr_is_pu_mode(afu_axis_rx.tuser_vendor),
                                                                 afu_axis_rx.tdata, afu_axis_rx.tkeep));
                $fflush(log_fd);
             end
        end
     end
   
   logic [NUM_ERRORS-1:0] printed_mask;
   //Debug messages when error is detected
   always_ff @ (posedge clk) begin
      if(~rst_n) begin
         printed_mask = 32'h0;
      end else begin
         if (|(error_vector & ~printed_mask))
           begin
              $display("======================================================================================================");
              $display("T:%8d %m *** ERROR: AFU_INTF: ERROR VECTOR : %h  ***", $time, error_vector);
              $display("======================================================================================================");
              printed_mask = printed_mask | error_vector;
           end
      end // else: !if(~rst_n)
   end // always_ff @ (posedge clk)
   
   always @ (blocking_traffic) begin
      if (rst_n === 1'b1) begin
         $display("======================================================================================================");
         $display("T:%8d *** INFO: %m blocking_traffic changed state to: %b  ***", $time, blocking_traffic);
         $display("======================================================================================================");
      end
   end
   
   // synthesis translate_on
   
endmodule: afu_intf

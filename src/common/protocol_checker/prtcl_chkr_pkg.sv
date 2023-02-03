// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//  This package contains the localparams used in the protocol checker
//
//----------------------------------------------------------------------------

package prtcl_chkr_pkg;

   import ofs_fim_if_pkg::*;
   import ofs_fim_pcie_hdr_def::*;

   logic clk;
   logic rst_n; // Active-low reset

   // Protocol Checker localparams
   localparam SYNC_FIFO_DEPTH     = 16;
   localparam ERROR_WIDTH         = 5;
   localparam TLP_HDR_ADDR_WIDTH  = 64;
   localparam PCIE_TLP_TAG_WIDTH  = 8;
   localparam DW_FMTTYPE_WIDTH    = 7;
   localparam DW_LEN_WIDTH        = 10;
   localparam LOWER_ADDR_WIDTH    = 7;
   localparam BYTE_COUNT_WIDTH    = 12;
   localparam PCIE_TLP_REQ_ID_WIDTH = 16;
   localparam REQ_HDR_ADDR_WIDTH = 32;

   `ifdef MMIO_TIMEOUT_IN_CYCLES
      localparam MMIO_TIMEOUT_CYCLES = `MMIO_TIMEOUT_IN_CYCLES;
   `else
      localparam MMIO_TIMEOUT_CYCLES = 40960;
   `endif

   // Error Bit Numbers
   localparam TX_REQ_COUNTER_OFLOW_ERR 	      = 15;
   localparam MALFORMED_TLP_ERR        	      = 14;
   localparam MAX_PAYLOAD_ERR          	      = 13;
   localparam MAX_READ_REQ_SIZE_ERR    	      = 12;
   localparam MAX_TAG_ERR              	      = 11;
   localparam UNALIGNED_ADDR_ERR              = 10;
   localparam TAG_OCCUPIED_ERR                = 9;
   localparam UNEXP_MMIO_RSP_ERR              = 8;
   localparam MMIO_TIMEOUT_ERR                = 7;
   localparam MMIO_WR_WHILE_RST_ERR           = 6;
   localparam MMIO_RD_WHILE_RST_ERR           = 5;
   localparam MMIO_DATA_PAYLOAD_OVERRUN_ERR   = 4;
   localparam MMIO_INSUFFICIENT_DATA_ERR      = 3;
   localparam TX_MWR_DATA_PAYLOAD_OVERRUN_ERR = 2;
   localparam TX_MWR_INSUFFICIENT_DATA_ERR    = 1;
   localparam TX_VALID_VIOLATION_ERR          = 0;

   typedef struct packed {
      logic tx_req_counter_oflow;
      logic malformed_tlp;
      logic max_payload;
      logic max_read_req_size;
      logic max_tag;
      logic unaligned_addr;
      logic tag_occupied;
      logic unexp_mmio_rsp;
      logic mmio_timeout;
      logic mmio_wr_while_rst;
      logic mmio_rd_while_rst;
      logic mmio_data_payload_overrun;
      logic mmio_insufficient_data;
      logic tx_mwr_data_payload_overrun;
      logic tx_mwr_insufficient_data;
      logic tx_valid_violation;
   } t_prtcl_chkr_err_vector;
   localparam NUM_ERRORS = $bits(t_prtcl_chkr_err_vector);

   typedef struct packed {
      logic [PCIE_TLP_TAG_WIDTH-1:0]    tag;
      logic [DW_LEN_WIDTH-1:0]          dw0_len;
      logic [PCIE_TLP_REQ_ID_WIDTH-1:0] requester_id;
      logic [REQ_HDR_ADDR_WIDTH-1:0]    addr;
   } t_mmio_timeout_hdr_info;
   localparam MMIO_TIMEOUT_HDR_INFO_WIDTH = $bits(t_mmio_timeout_hdr_info);

endpackage : prtcl_chkr_pkg

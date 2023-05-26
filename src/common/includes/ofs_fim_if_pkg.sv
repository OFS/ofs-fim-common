// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//  This package defines the following interfaces/channels in CoreFIM
//     1. PCIe AXI4-S channels
//     2. Sideband signals from PCIe Interface (PCIe configurations, FLR and etc.)
//     3. AXI-4 MMIO master and slave interfaces 
//     4. MMIO structs for internal use only
//
//----------------------------------------------------------------------------
`ifndef __OFS_FIM_IF_PKG_SV__
`define __OFS_FIM_IF_PKG_SV__

package ofs_fim_if_pkg;
    
//-----------------------------------------------
// 1. PCIe AXI4-S channels: parameters and interfaces
//-----------------------------------------------

// Number of TLP data stream/channel on AXIS channel
localparam FIM_PCIE_TLP_CH = 2;
typedef enum {CH0, CH1} e_fim_tlp_channel;

// PCIe TLP header width on each TLP data stream
localparam AXIS_PCIE_HW = 128; 
// PCIe TLP payload width on each TLP data stream
localparam AXIS_PCIE_PW = 256; 

`ifdef INCLUDE_PCIE_SS
// TLP routing ID 
typedef struct packed {
   // BAR number
   logic [2:0]  bar;
   // VF number
   logic [12:0] vfn;
   // PF number
   logic [2:0]  pfn;
   // VF active indicates if the TLP is targeting a VF or PF
   logic        vf_active;
   //FC Bit
   logic        fc_bit;
   //Data Mode -PU/DM
   logic        data_mode;
} t_routing_id;
`else
typedef struct packed {
   // BAR number
   logic [2:0]  bar;
   // VF number
   logic [12:0] vfn;
   // PF number
   logic [2:0]  pfn;
   // VF active indicates if the TLP is targeting a VF or PF
   logic        vf_active;
} t_routing_id;
`endif

localparam AXIS_PCIE_DSTW = $bits(t_routing_id);

// TUSER signals in each TLP data stream of AXIS RX channel
typedef struct packed {
   // Current packet is MMIO request
   logic        mmio_req;
   // Unsupported MMIO read request
   logic        ummio_rd;
   // Routing ID
   t_routing_id dest;
} t_axis_pcie_rx_tuser;
localparam AXIS_PCIE_RX_UW = $bits(t_axis_pcie_rx_tuser);

// TUSER signals in each TLP data stream of AXIS TX channel
`ifdef INCLUDE_PCIE_SS
typedef struct packed {
   // Indicates if the TLP packet is sent from a VF/PF
   logic vf_active;
   // Indicates that tdata is an update to the AFU status
   // registers maintained in the FIM's port CSR space. These
   // registers are for low-level state and error signaling
   // from AFUs, typically when TLP generation has failed.
   // When set, the t_axis_pcie_tdata's hdr is replaced with
   // t_axis_afu_status_hdr.
   // *** This flag is honored only on channel 0 and ignored
   // *** on all other channels. When set in channel 0, all
   // *** channels other than 0 are completely ignored and
   // *** may not be used for sending TLP packets.
   logic afu_status_port_csr_wr;
   // Indicates that tdata is an AFU interrupt request.
   // When set, the t_axis_pcie_tdata's hdr is replaced with
   // t_axis_irq_tdata.
   logic afu_irq;
   logic fc_bit;
   logic data_mode;
} t_axis_pcie_tx_tuser;
`else
typedef struct packed {
   // Indicates if the TLP packet is sent from a VF/PF
   logic vf_active;
   // Indicates that tdata is an update to the AFU status
   // registers maintained in the FIM's port CSR space. These
   // registers are for low-level state and error signaling
   // from AFUs, typically when TLP generation has failed.
   // When set, the t_axis_pcie_tdata's hdr is replaced with
   // t_axis_afu_status_hdr.
   // *** This flag is honored only on channel 0 and ignored
   // *** on all other channels. When set in channel 0, all
   // *** channels other than 0 are completely ignored and
   // *** may not be used for sending TLP packets.
   logic afu_status_port_csr_wr;
   // Indicates that tdata is an AFU interrupt request.
   // When set, the t_axis_pcie_tdata's hdr is replaced with
   // t_axis_irq_tdata.
   logic afu_irq;
   } t_axis_pcie_tx_tuser;
`endif

localparam AXIS_PCIE_TX_UW = $bits(t_axis_pcie_tx_tuser);

// TDATA signals in each TLP data stream of AXIS RX/TX channel
typedef struct packed {
   // Data payload
   logic [AXIS_PCIE_PW-1:0] payload;
   // Header
   logic [AXIS_PCIE_HW-1:0] hdr;
   // Reserved - default to 0
   logic [4:0]              rsvd0;
   // End of packet
   logic                    eop;
   // Start of packet
   logic                    sop;
   // Packet is valid
   logic                    valid;
} t_axis_pcie_tdata;
localparam AXIS_PCIE_DW = $bits(t_axis_pcie_tdata);

// AXIS RX channel with 1 TLP data stream channel
typedef struct packed {
   logic                tvalid;
   logic                tlast;
   t_axis_pcie_rx_tuser tuser;
   t_axis_pcie_tdata    tdata;
} t_axis_pcie_rx;
localparam AXIS_PCIE_RX_WIDTH = $bits(t_axis_pcie_rx);

// AXIS RX channel with multiple TLP data stream channels
// Number of TLP data streams is defined by FIM_PCIE_TLP_CH
typedef struct packed {
   logic                                      tvalid;
   logic                                      tlast;
   // Array of sideband signals for TLP data stream channels
   t_axis_pcie_rx_tuser [FIM_PCIE_TLP_CH-1:0] tuser;
   // Array of data for TLP data streams
   t_axis_pcie_tdata    [FIM_PCIE_TLP_CH-1:0] tdata;
} t_axis_pcie_rxs;
localparam AXIS_PCIE_RXS_WIDTH = $bits(t_axis_pcie_rxs);

// AXIS TX channel with 1 TLP data stream channel
typedef struct packed {
   logic                tvalid;
   logic                tlast;
   t_axis_pcie_tx_tuser tuser;
   t_axis_pcie_tdata    tdata;
} t_axis_pcie_tx;
localparam AXIS_PCIE_TX_WIDTH = $bits(t_axis_pcie_tx);

// AXIS TX channel with multiple TLP data stream channels
typedef struct packed {
   logic                                      tvalid;
   logic                                      tlast;
   // Array of sideband signals for TLP data stream channels
   t_axis_pcie_tx_tuser [FIM_PCIE_TLP_CH-1:0] tuser;
   // Array of data for TLP data streams
   t_axis_pcie_tdata    [FIM_PCIE_TLP_CH-1:0] tdata;
} t_axis_pcie_txs;
localparam AXIS_PCIE_TXS_WIDTH = $bits(t_axis_pcie_txs);

// AXIS IRQ request  
typedef struct packed {
   // Interrupt ID
   logic [7:0]  irq_id;
   // Requester ID
   logic [15:0] rid;
} t_axis_irq_tdata;
localparam IRQ_TDATA_WIDTH = $bits(t_axis_irq_tdata);
localparam IRQ_REQ_DW = IRQ_TDATA_WIDTH;
localparam IRQ_RSP_DW = IRQ_TDATA_WIDTH;

// AXIS IRQ response 
typedef struct packed {
   // Indicates if response is valid
   logic             tvalid;
   // IRQ request with which the response is associated
   t_axis_irq_tdata  tdata;
} t_axis_irq_rsp;

// Update AFU status register value in port CSR space. This
// replaces the t_axis_pcie_tdata hdr field when
// afu_status_port_csr_wr is set in tuser. The value to write
// to the selected register(s) is stored in payload.
localparam NUM_PORT_AFU_STATUS_CSRS = 4;
typedef struct packed {
   // Write enable bits, one per CSR. Values to write are stored in
   // a vector of 64 bit values in payload.
   logic [NUM_PORT_AFU_STATUS_CSRS-1:0] csr_wen;
} t_axis_afu_status_hdr;
localparam AFU_STATUS_HDR_WIDTH = $bits(t_axis_afu_status_hdr);

// Vector of AFU status CSRs that may be written (stored in payload).
typedef logic [NUM_PORT_AFU_STATUS_CSRS-1:0][63:0] t_axis_afu_status_payload;

//--------------------------------------------------
// 2. Sideband signals from PCIe Interface 
//--------------------------------------------------
// PCIe configuration settings needed by platform
typedef struct packed {
   logic [2:0]  max_payload_size;
   logic [2:0]  max_read_req_size;
   logic        extended_tag_enable;
   logic        msix_enable;
   logic        msix_pf_mask_en;
   logic        vf0_msix_mask;
} t_pcie_cfg_ctl;
localparam PCIE_CFG_CTL_WIDTH = $bits(t_pcie_cfg_ctl);

// Sideband signals from PCIe module
typedef struct packed {
   // PCIe configurations
   t_pcie_cfg_ctl            cfg_ctl;
   
   // FLR signals
   logic [ofs_fim_pcie_pkg::NUM_PF-1:0]    flr_active_pf;
   logic                     flr_rcvd_vf;
   logic [ofs_fim_pcie_pkg::PF_WIDTH-1:0]  flr_rcvd_pf_num;
   logic [ofs_fim_pcie_pkg::VF_WIDTH-1:0]  flr_rcvd_vf_num;

   logic                     pcie_linkup;
   logic [31:0]              pcie_chk_rx_err_code;
 
} t_sideband_from_pcie;
localparam SIDEBAND_FROM_PCIE_WIDTH = $bits(t_sideband_from_pcie);

// Sideband signals to PCIe module
typedef struct packed {
   // FLR signals
   logic [ofs_fim_pcie_pkg::NUM_PF-1:0]    flr_completed_pf;
   logic                     flr_completed_vf;
   logic [ofs_fim_pcie_pkg::PF_WIDTH-1:0]  flr_completed_pf_num;
   logic [ofs_fim_pcie_pkg::VF_WIDTH-1:0]  flr_completed_vf_num;
} t_sideband_to_pcie;
localparam SIDEBAND_TO_PCIE_WIDTH = $bits(t_sideband_to_pcie);

//-----------------------------------------------------
// 3. AXI MMIO request/response signals
//-----------------------------------------------------
// Write address channel
typedef struct packed {
   logic                           awvalid;
   logic [ofs_fim_cfg_pkg::MMIO_TID_WIDTH-1:0]      awid;
   logic [ofs_fim_cfg_pkg::MMIO_ADDR_WIDTH-1:0]     awaddr;
   logic [7:0]                     awlen;
   logic [2:0]                     awsize;
   logic [1:0]                     awburst;
   logic [3:0]                     awcache;
   logic [2:0]                     awprot;
   logic [3:0]                     awqos;
} t_axi_mmio_aw;

// Write data channel
typedef struct packed {
   logic                           wvalid;
   logic [ofs_fim_cfg_pkg::MMIO_DATA_WIDTH-1:0]     wdata;
   logic [(ofs_fim_cfg_pkg::MMIO_DATA_WIDTH/8-1):0] wstrb;
   logic                           wlast;
} t_axi_mmio_w;

// Read address channel
typedef struct packed {
   logic                           arvalid;
   logic [ofs_fim_cfg_pkg::MMIO_TID_WIDTH-1:0]      arid;
   logic [ofs_fim_cfg_pkg::MMIO_ADDR_WIDTH-1:0]     araddr;
   logic [7:0]                     arlen;
   logic [2:0]                     arsize;
   logic [1:0]                     arburst;
   logic [3:0]                     arcache;
   logic [2:0]                     arprot;
   logic [3:0]                     arqos;
} t_axi_mmio_ar;

// AXI MMIO request channels
typedef struct packed {
  t_axi_mmio_aw aw_ch;
  t_axi_mmio_w  w_ch;
  t_axi_mmio_ar ar_ch;
} t_axi_mmio_req;

// AXI write/read response status 
typedef enum logic [1:0] {
   RESP_OKAY   = 2'b00,
   RESP_EXOKAY = 2'b01,
   RESP_SLVERR = 2'b10,
   RESP_DECERR = 2'b11
} resp_t;

// Write response channel
typedef struct packed {
   logic                           bvalid;
   logic [ofs_fim_cfg_pkg::MMIO_TID_WIDTH-1:0]      bid;
   resp_t                          bresp;
} t_axi_mmio_b;

// Read response channel
typedef struct packed {
   logic                           rvalid;
   logic                           rlast;
   resp_t                          rresp;
   logic [ofs_fim_cfg_pkg::MMIO_DATA_WIDTH-1:0]     rdata;
   logic [ofs_fim_cfg_pkg::MMIO_TID_WIDTH-1:0]      rid;
} t_axi_mmio_r;

// AXI MMIO response channels
typedef struct packed {
  t_axi_mmio_b b_ch;
  t_axi_mmio_r r_ch;
} t_axi_mmio_rsp;

// AXI signals from master to slave
typedef struct packed {
   logic           clk;
   logic           rst_n;
   t_axi_mmio_req  mmio_req;
   logic           bready;
   logic           rready;
} t_axi_mmio_m2s;

// AXI signals from slave to master
typedef struct packed {
   t_axi_mmio_rsp mmio_rsp;
   logic          awready;
   logic          wready;
   logic          arready;
} t_axi_mmio_s2m;

//-----------------------------------------------------
// 4. Internal MMIO request/response signals
//-----------------------------------------------------

// MMIO request header
typedef struct packed {
   logic [ofs_fim_cfg_pkg::MMIO_TID_WIDTH-1:0]  tid;     // Write/Read ID
   logic [ofs_fim_cfg_pkg::MMIO_ADDR_WIDTH-1:0] address; // 4B aligned address
   logic [2:0]                 size;	// 4B: (follow AXI-M AWSIZE encoding)
} t_mmio_req_hdr;
localparam MMIO_REQ_HDR_WIDTH = $bits(t_mmio_req_hdr);

// MMIO response header
typedef struct packed {
   logic [ofs_fim_cfg_pkg::MMIO_TID_WIDTH-1:0] tid;     // Write/Read ID
   logic [1:0]                rsp;     // 2'b00:Success (follow AXI-M bresp and rresp endocing)   
} t_mmio_rsp_hdr;
localparam MMIO_RSP_HDR_WIDTH = $bits(t_mmio_rsp_hdr);

// MMIO request
typedef struct packed {
   logic [ofs_fim_cfg_pkg::MMIO_DATA_WIDTH-1:0]  wdata;
   t_mmio_req_hdr  hdr;
   t_routing_id    rid;
   logic           wvalid;
   logic           rvalid;
} t_mmio_req;
localparam MMIO_REQ_WIDTH = $bits(t_mmio_req);

// MMIO write reponse
typedef struct packed {
   logic                        valid;    
   t_mmio_rsp_hdr               hdr;	 
} t_mmio_wrrsp;

// MMIO read response
typedef struct packed {
   logic                        valid;    
   t_mmio_rsp_hdr               hdr;
   logic [ofs_fim_cfg_pkg::MMIO_DATA_WIDTH-1:0]  rdata;
} t_mmio_rrsp;

// PCIe CPL header info for MMIO response
typedef struct packed {
  logic [6:0]  lower_addr;
  logic [15:0] requester_id;
  logic [1:0]  length;
  logic [12:0] vfn;
  logic [2:0]  pfn;
  logic        vf_active;
} t_mmio_cpl_hdr_info;
localparam MMIO_CPL_HDR_INFO_WIDTH = $bits(t_mmio_cpl_hdr_info);

//-----------------------------------------------------
// 5. AVST structure
//-----------------------------------------------------

typedef struct packed {
    logic [511:0]   data;
    logic           valid;
    logic           error;
    logic           sop;
    logic           eop;
    logic [5:0]     empty;
    logic           ready;
} t_avst;
localparam AVST_W = $bits(t_avst);

//-----------------------------------------------------
// Functions and tasks
//-----------------------------------------------------

// synthesis translate_off

function automatic string func_routing_id_to_string (
   input t_routing_id rid
);
   return $sformatf("bar %x vfn 0x%0x pfn %x%0s",
                    rid.bar, rid.vfn, rid.pfn,
                    (rid.vf_active ? " vf_active" : ""));
endfunction

function automatic string func_rx_user_to_string (
   input t_axis_pcie_rx_tuser user
);
   return $sformatf("user %0s%0s%s",
                    (user.mmio_req ? "mmio_req " : ""),
                    (user.ummio_rd ? "ummio_rd " : ""),
                    func_routing_id_to_string(user.dest));
endfunction

function automatic string func_tx_user_to_string (
   input t_axis_pcie_tx_tuser user
);
   if (user == t_axis_pcie_tx_tuser'(0)) return "user none";

   return $sformatf("user%0s%0s%0s",
                    (user.vf_active ? " vf_active" : ""),
                    (user.afu_status_port_csr_wr ? " afu_status_port_csr_wr" : ""),
                    (user.afu_irq ? " afu_irq" : ""));
endfunction

// synthesis translate_on

endpackage

`endif // __OFS_FIM_IF_PKG_SV__

// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// Minimal PCIe port connector only reponds Host to Card mmio request
// - Option to chose VIRTIO GUID
//-----------------------------------------------------------------------------

import pcie_ss_hdr_pkg::*;

module he_null #(
   parameter CSR_DATA_WIDTH = 64,
   parameter CSR_ADDR_WIDTH = 16,
   parameter CSR_DEPTH      = 4, 
   // PF/VF/VF_ACTIVE are defined here so he_null looks like a normal AFU, but
   // they are not used. Instead, he_null() responds dynamically with any
   // MMIO request received. Since he_null() only responds to commands and
   // does not initiate traffic, it doesn't need to know its address. It
   // would be acceptable to instantiate a single he_null() to respond for
   // multiple functions.
   parameter PF_ID          = 0,
   parameter VF_ID          = 0,
   parameter VF_ACTIVE      = 0,
   parameter USE_VIRTIO_GUID = 0
)(
   input  logic clk,
   input  logic rst_n,

   pcie_ss_axis_if.sink   i_rx_if,
   pcie_ss_axis_if.source o_tx_if
);
   // ----------- Parameters -------------
   localparam END_OF_LIST           = 1'h0;  // Set this to 0 if there is another DFH beyond this
   localparam NEXT_DFH_BYTE_OFFSET  = 24'h0; // Next DFH Byte offset
   localparam CSR_DEPTH_LOG2        = $clog2(CSR_DEPTH);
   localparam PCIE_TDATA_WIDTH      = ofs_fim_cfg_pkg::PCIE_TDATA_WIDTH;
   localparam PCIE_TUSER_WIDTH      = ofs_fim_cfg_pkg::PCIE_TUSER_WIDTH;

   localparam VIRTIO_GUID_L         = 64'hb9abefbd90b970c4;
   localparam VIRTIO_GUID_H         = 64'h1aae155cacc54210;
   localparam NULL_GUID_L           = 64'haa31f54a3e403501;
   localparam NULL_GUID_H           = 64'h3e7b60a0df2d4850;
   localparam HE_GUID_L             = (USE_VIRTIO_GUID == 1) ? VIRTIO_GUID_L : NULL_GUID_L;
   localparam HE_GUID_H             = (USE_VIRTIO_GUID == 1) ? VIRTIO_GUID_H : NULL_GUID_H;

   localparam bit        VIO_END_OF_LIST     = 1'b1; //DFH End of list
   localparam bit [11:0] VIO_FEAT_ID         = 12'h0; //DFH Feature ID
   localparam bit [3:0 ] VIO_FEAT_VER        = 4'h0; //DFH Feature Version
   localparam bit [23:0] VIO_NEXT_DFH_OFFSET = 24'h0000; //DFH Next DFH Offset

   localparam DEF_VIO_FEATURE_DFH = {4'h1,19'h0,VIO_END_OF_LIST,VIO_NEXT_DFH_OFFSET,VIO_FEAT_VER,VIO_FEAT_ID};

   // CSR Addresses
   localparam NULL_DFH         = 17'h0000;
   localparam NULL_GUID_L_ADDR = 17'h0008;
   localparam NULL_GUID_H_ADDR = 17'h0010;
   localparam NULL_SCRATCHPAD  = 17'h0018;

   // ---- Logic / Struct Declarations ---
   logic mmio_wr_en;
   logic mmio_rd_en;
   logic axi_rx_if_sop;
   logic axi_rx_if_cpld;
   logic rx_sop_init;
   logic rx_sop_valid;
   logic axi_rx_if_tvalid_t1;
   logic axi_rx_if_tready_t1;
   logic [CSR_ADDR_WIDTH-5:0]     rx_addr, mmio_csr_addr_4b;
   logic [CSR_ADDR_WIDTH-1:0]     rx_addr_decode;
   logic [CSR_ADDR_WIDTH-2:0]     mmio_csr_addr_8b;
   logic [255:0]                  mmio_wr_data, axi_rx_if_data_t1;
   logic                          mmio_hdr_len;
   PCIe_PUCplHdr_t                cpl_hdr;
   PCIe_PUReqHdr_t                mmio_hdr_t1;
   PCIe_PUReqHdr_t                rx_hdr;
   logic [CSR_DATA_WIDTH-1:0]     scratch_reg;
   logic [CSR_DATA_WIDTH-1:0]     debug_default_reg;
   logic flr_rst_n_d;
   logic access_upper32b;

   pcie_ss_axis_if #(
      .DATA_W (PCIE_TDATA_WIDTH),
      .USER_W (PCIE_TUSER_WIDTH)
   ) axi_rx_if (.clk(clk), .rst_n(rst_n));

   pcie_ss_axis_if #(
      .DATA_W (PCIE_TDATA_WIDTH),
      .USER_W (PCIE_TUSER_WIDTH)
   ) axi_tx_if (.clk(clk), .rst_n(rst_n));

   always_comb begin
      // AXI RX Interface
      i_rx_if.tready           = i_rx_if.rst_n ? 1'b1 : 0;      
      axi_rx_if.tvalid         = i_rx_if.tvalid;
      axi_rx_if.tlast          = i_rx_if.tlast;
      axi_rx_if.tuser_vendor   = i_rx_if.tuser_vendor;
      axi_rx_if.tdata          = i_rx_if.tdata;
      axi_rx_if.tkeep          = i_rx_if.tkeep;
      axi_rx_if.tready         = i_rx_if.tready;

      // AXI TX Interface
      axi_tx_if.tready     = o_tx_if.tready;
      o_tx_if.tvalid       = axi_tx_if.tvalid;
      o_tx_if.tlast        = axi_tx_if.tlast;
      o_tx_if.tuser_vendor = axi_tx_if.tuser_vendor;
      o_tx_if.tdata        = axi_tx_if.tdata;
      o_tx_if.tkeep        = axi_tx_if.tkeep;
   end

   always_comb begin 
      axi_rx_if_sop    = rx_sop_init | rx_sop_valid;
      mmio_hdr_len     = (mmio_hdr_t1.length > 1) ? 1'b1 : 1'b0; //Length is in DW
      rx_addr          = (mmio_hdr_t1.fmt_type == M_RD | mmio_hdr_t1.fmt_type == M_WR) ? mmio_hdr_t1.host_addr_h[13:2] : mmio_hdr_t1.host_addr_l[11:0]; //8B aligned
      rx_addr_decode   = 0;
      rx_addr_decode   = {2'b0, rx_addr[CSR_ADDR_WIDTH-7:1], 3'b0};
      mmio_csr_addr_4b = rx_addr;
      mmio_csr_addr_8b = {'0, mmio_csr_addr_4b[CSR_ADDR_WIDTH-5:1]};

      // CSR Write
      mmio_wr_en   = axi_rx_if_sop & axi_rx_if_tvalid_t1 & axi_rx_if_tready_t1 & (mmio_hdr_t1.fmt_type == M_WR | mmio_hdr_t1.fmt_type == DM_WR);
      mmio_wr_data = axi_rx_if_data_t1;

      // CSR Read
      mmio_rd_en    = axi_rx_if_sop & axi_rx_if_tvalid_t1 & axi_rx_if_tready_t1 & (mmio_hdr_t1.fmt_type == M_RD | mmio_hdr_t1.fmt_type == DM_RD);
      access_upper32b = ~mmio_hdr_len & mmio_csr_addr_4b[0];

      // Set up completion packet
      cpl_hdr               = 'h0;
      cpl_hdr.fmt_type      = DM_CPL;

      cpl_hdr.attr[8]       = mmio_hdr_t1.attr[8];  // Attribite bits 
      cpl_hdr.attr[3:2]     = mmio_hdr_t1.attr[3:2];// Attribite bits 

      cpl_hdr.TC            = mmio_hdr_t1.TC;       // Traffic Class
      cpl_hdr.cpl_status    = 3'h0;                 // Successful Completion
      cpl_hdr.pf_num        = mmio_hdr_t1.pf_num;
      cpl_hdr.vf_num        = mmio_hdr_t1.vf_num;
      cpl_hdr.vf_active     = mmio_hdr_t1.vf_active;

      cpl_hdr.length        = (mmio_hdr_t1.length == 1) ? 10'd1 : 10'd2; //DWs
      
      cpl_hdr.tag_h         = mmio_hdr_t1.tag_h;
      cpl_hdr.tag_m         = mmio_hdr_t1.tag_m;
      cpl_hdr.tag_l         = mmio_hdr_t1.tag_l;

      cpl_hdr.byte_count    = (mmio_hdr_t1.length == 1) ? 10'd4 : 10'd8; //Bytes 
      cpl_hdr.comp_id       = {'0,
                               mmio_hdr_t1.vf_num,
                               mmio_hdr_t1.vf_active,
                               mmio_hdr_t1.pf_num};

      cpl_hdr.low_addr      = ((mmio_hdr_t1.fmt_type == M_RD) | (mmio_hdr_t1.fmt_type == M_WR)) ? 
                                 {mmio_hdr_t1.host_addr_h[15:2], 2'b00} : 
                                 {mmio_hdr_t1.host_addr_l[13:0], 2'b00};
      cpl_hdr.req_id        = mmio_hdr_t1.req_id; //Response with same req_id as request
   end

   //Create SOP & separate data/header signals
   always_ff @(posedge clk) begin
      if(~rst_n) begin
         rx_sop_init         <= 1'b1;
         rx_sop_valid        <= 1'b0;
         axi_rx_if_tvalid_t1 <= '0;
         axi_rx_if_tready_t1 <= '0;
         mmio_hdr_t1         <= '0;
         axi_rx_if_data_t1   <= '0;
      end else begin
         if(rx_sop_init & axi_rx_if.tvalid) begin
            rx_sop_init <= 1'b0;
         end
         if(axi_rx_if.tvalid & axi_rx_if.tready) begin
            rx_sop_valid <= axi_rx_if.tlast;
         end

         axi_rx_if_tvalid_t1 <= axi_rx_if.tvalid;
         axi_rx_if_tready_t1 <= axi_rx_if.tready;
         mmio_hdr_t1         <= axi_rx_if.tdata[255:0];
         axi_rx_if_data_t1   <= axi_rx_if.tdata[256+:CSR_DATA_WIDTH];
      end
   end

   // Receive MMIO Writes 
   always_ff @(posedge clk) begin
      if (~rst_n) begin
         scratch_reg       <= '0;
         debug_default_reg <= 'hdeadbeef;
      end else begin
         if (mmio_wr_en) begin
            case ( {rx_addr_decode} )
               NULL_SCRATCHPAD: begin
                  if (access_upper32b)
                     scratch_reg <= {axi_rx_if_data_t1[31:0], axi_rx_if_data_t1[31:0]};
                  else
                     scratch_reg <= axi_rx_if_data_t1;
               end
               default: begin
                  scratch_reg       <= 'haaaa_aaaa;
                  debug_default_reg <= 'hbbbb_bbbb;
               end
            endcase
         end
      end
   end

   // MMIO Completion 
   always_ff @(posedge clk) begin
      if (~rst_n) begin
         axi_tx_if.tvalid         <= 0;
         axi_tx_if.tlast          <= 0;
         axi_tx_if.tuser_vendor   <= 'h1;
         axi_tx_if.tdata          <= 0;
         axi_tx_if.tkeep          <= 0;
      end else begin
         if (axi_tx_if.tvalid) begin
            axi_tx_if.tvalid         <= (axi_tx_if.tvalid  && axi_tx_if.tready) ? '0  : 1; 
            axi_tx_if.tlast          <= (axi_tx_if.tvalid  && axi_tx_if.tready) ? '0  : axi_tx_if.tlast;
            axi_tx_if.tuser_vendor   <= (axi_tx_if.tvalid  && axi_tx_if.tready) ? 'h1 : 'h0;
            axi_tx_if.tkeep          <= (axi_tx_if.tvalid  && axi_tx_if.tready) ? '1  : axi_tx_if.tkeep;
            axi_tx_if.tdata          <= (axi_tx_if.tvalid  && axi_tx_if.tready) ? '0  : axi_tx_if.tdata;
         end else begin
            axi_tx_if.tvalid         <= axi_tx_if.tvalid;
            axi_tx_if.tlast          <= axi_tx_if.tlast;
            axi_tx_if.tuser_vendor   <= axi_tx_if.tuser_vendor;
            axi_tx_if.tkeep          <= axi_tx_if.tkeep;
            axi_tx_if.tdata          <= axi_tx_if.tdata;
         end
         if (mmio_rd_en) begin
            axi_tx_if.tdata[255:0] <= cpl_hdr;
            if (~axi_tx_if.tvalid | axi_tx_if.tready) begin
               axi_tx_if.tvalid <= 1;
               axi_tx_if.tlast  <= 1;
               axi_tx_if.tuser_vendor   <= 'h0;
               axi_tx_if.tkeep  <= (cpl_hdr.length == 'd1) ? {'0, {(4){1'b1}}, {(PCIE_TDATA_WIDTH/16){1'b1}} } : 
                                                      {'0, {(8){1'b1}}, {(PCIE_TDATA_WIDTH/16){1'b1}} } ; 
               axi_tx_if.tdata[511:256] <= '0;
               case ( {rx_addr_decode} )
                  NULL_DFH: begin
                     axi_tx_if.tdata[511:256] <= access_upper32b ? DEF_VIO_FEATURE_DFH[63:32] : DEF_VIO_FEATURE_DFH; 
                  end
                  NULL_GUID_L_ADDR: begin
                     axi_tx_if.tdata[511:256] <= access_upper32b ?  HE_GUID_L[63:32] : HE_GUID_L; 
                  end
                  NULL_GUID_H_ADDR: begin
                     axi_tx_if.tdata[511:256] <= access_upper32b ? HE_GUID_H[63:32] :  HE_GUID_H; 
                  end
                  NULL_SCRATCHPAD: begin
                     axi_tx_if.tdata[511:256] <= access_upper32b ? scratch_reg[63:32] :  scratch_reg; 
                  end
                  default: begin
                     axi_tx_if.tdata[511:256] <= {debug_default_reg, 1'b0, rx_addr_decode};
                  end
               endcase
            end
         end
      end
   end

endmodule

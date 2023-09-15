// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// This function converts MCTP CSR writes to MCTP AXI-ST Packets
// Assumptions:
//  - MMIO WIDTH is 64. This logic does not work for other MMIO WIdths
//
//-----------------------------------------------------------------------------

import pcie_ss_hdr_pkg::*;
import ofs_csr_pkg::*;

module mctp_tx_bridge #(
   parameter    MAX_BUF_DEPTH = 32,
   parameter    MM_DATA_WIDTH = 64,
   parameter    PF_NUM        = 3'h0,
   parameter    VF_NUM        = 11'h000,
   parameter    VF_ACTIVE     = 1'b0,
   parameter    TDATA_W       = 512,
   parameter    TUSER_W       = 10
)(
   input                        clk,
   input                        rst,

   pcie_ss_axis_if.source       o_tx_st,

   input                        i_csr_sop,  // A Pulse when PMCI writes to FCR.SOP
   input                        i_csr_eop,  // A Pulse when PMCI writes to FCR.EOP
   input                        i_csr_val,  // A Pulse when PMCI writes to DR(PAYLOAD)
   input [MM_DATA_WIDTH-1:0]    i_csr_pld,  // Payload valuae
   input csr_access_type_t      i_csr_type, // Access Type
   output                       o_csr_rdy   // FSM Ready to update FCR.BUSY
);
   //------------------------------------------
   // Signals & Settings
   //------------------------------------------

   localparam TKEEP_W  = TDATA_W/8;
   localparam INDX     = TDATA_W/32; // We need strobe per 4B Word
   localparam STROBE_W = MM_DATA_WIDTH/32;

   localparam VDM_SOP  = 2'b00;
   localparam VDM_HDR0 = 2'b01;
   localparam VDM_HDR1 = 2'b10;
   localparam VDM_PYLD = 2'b11;

   localparam WAIT_FOR_EOP = 1'b0;
   localparam READ_BUF     = 1'b1;

   logic [1:0]         wr_pres_state;
   logic [1:0]         wr_next_state;
   PCIe_PUReqHdr_t     vdm_hdr;
   logic [TDATA_W-1:0] pld_reg;
   logic [INDX-1:0]    pld_stb;
   logic [TDATA_W-1:0] buf_tdata;
   logic [TKEEP_W-1:0] buf_tkeep;
   logic               buf_tlast;
   logic               buf_wen;
   logic               buf_ren;
   logic               buf_empty;
   logic               buf_full;
   logic               buf_eop_ren;
   logic               buf_eop_empty;
   logic               buf_eop_full;
   logic [TDATA_W+TKEEP_W+1-1:0] buf_dout;
   logic [MM_DATA_WIDTH-1:0]     pld;

   logic               rd_pres_state;
   logic               rd_next_state;

   pcie_ss_axis_if#(.DATA_W(TDATA_W)) axi_tx_if_p();

   //------------------------------------------
   // SS PU Format Resrved Bits
   //------------------------------------------
   // PMCI Does not follow SS TLP format, hence it wont write Bytes 16 to 32 of SS TLP
   // Hardcode these reserved bits based on PF/VF number, and insert whil sending Tx data

   assign vdm_hdr.metadata_l = 32'b0;        // meta-data field
   assign vdm_hdr.metadata_h = 32'b0;        // meta-data field
   assign vdm_hdr.bar_number = 7'b0;         // Bar Number
   assign vdm_hdr.mm_mode    = 1'b0;         // Memory Mapped mode
   assign vdm_hdr.slot_num   = 5'b0;         // Slot Number
   assign vdm_hdr.rsvd2      = 4'b0;         // Reserved
   assign vdm_hdr.vf_active  = VF_ACTIVE;
   assign vdm_hdr.vf_num     = VF_NUM;
   assign vdm_hdr.pf_num     = PF_NUM;
   assign vdm_hdr.rsvd3      = 2'b0;         // Reserved
   assign vdm_hdr.pref_present = 1'b0;       // Prefix Present
   assign vdm_hdr.pref_type  = 5'b0;         // Prefix Type
   assign vdm_hdr.pref       = 24'b0;        // Prefix

   //------------------------------------------
   // FSM & State Register
   //------------------------------------------
   // When SOP is asserted, be ready to receive header bytes
   // PMCI will write 16 bytes of PCIe symantics header
   // Our logic inserts 16bytes of reserved bits for PCIe SS PU symantics.
   // Header bytes are followed by payload. When data register is full, write to buffer
   // On EOP, End packet with TLAST, go back to initial state
   // If buffer is full, Logic is not expecting payload or Eop commands from CSR

   always @(posedge clk) begin
      if(rst) begin
         wr_pres_state <= VDM_SOP;
      end else begin
         wr_pres_state <= wr_next_state;
      end
   end

   always @(*) begin
      wr_next_state = wr_pres_state;
      case(wr_pres_state)
         VDM_SOP:  if (i_csr_sop)              wr_next_state = VDM_HDR0;
         VDM_HDR0: if (i_csr_val && o_csr_rdy) wr_next_state = VDM_HDR1;
         VDM_HDR1: if (i_csr_val && o_csr_rdy) wr_next_state = VDM_PYLD;
         VDM_PYLD: if (i_csr_eop && o_csr_rdy) wr_next_state = VDM_SOP;
      endcase
   end
   
   //------------------------------------------
   // Endian swap
   //------------------------------------------
   // Change Data Endianness as per PCIe Symantics
   
  // assign pld = {i_csr_pld[39:32],i_csr_pld[47:40],i_csr_pld[55:48],i_csr_pld[63:56],i_csr_pld[7:0],i_csr_pld[15:8],i_csr_pld[23:16],i_csr_pld[31:24]};
   assign pld = (wr_pres_state == VDM_PYLD) ?  i_csr_pld : {i_csr_pld[39:32],i_csr_pld[47:40],i_csr_pld[55:48],i_csr_pld[63:56],i_csr_pld[7:0],i_csr_pld[15:8],i_csr_pld[23:16],i_csr_pld[31:24]};

   //------------------------------------------
   // Shift in MMIO data
   //------------------------------------------
   // When SOP is asserted, reset all buffers
   // When Payload is written, pack payload to data register one by one from MSB to LSB
   // Insert reserved Header bits from byte 16 to 32 once 16bytes HDR are received from PMCI
   // When Data register is full or EOP occur, write dat to Tx buffer, wait for next SOP

   always @(posedge clk) begin
      if(rst) begin
         pld_reg <= {TDATA_W{1'b0}};
         pld_stb <= {INDX{1'b0}};
      end else begin
         case(wr_pres_state)
            VDM_SOP: begin
               pld_reg <= {TDATA_W{1'b0}};
               pld_stb <= {INDX{1'b0}};
            end
            VDM_HDR0: begin
               if (i_csr_val && o_csr_rdy) begin
                  pld_stb <= {{STROBE_W{1'b1}}, {(INDX-STROBE_W){1'b0}}};
                  pld_reg <= {pld[MM_DATA_WIDTH-1:0],{(TDATA_W-MM_DATA_WIDTH){1'b0}}};
               end
            end
            VDM_HDR1: begin
               if (i_csr_val && o_csr_rdy) begin
                  pld_stb <= {{4{1'b1}},{STROBE_W{1'b1}},pld_stb[INDX-1:(4+STROBE_W)]};
                  pld_reg <= {vdm_hdr[255:128],pld[MM_DATA_WIDTH-1:0],pld_reg[TDATA_W-1:3*MM_DATA_WIDTH]};
               end
            end
            VDM_PYLD: begin
               if(i_csr_val && o_csr_rdy) begin
                  if(pld_stb == {INDX{1'b1}}) begin
                    if(i_csr_type==LOWER32) begin
                       pld_stb <= {1'b1,{(INDX-1){1'b0}}};
                       pld_reg <= {pld[MM_DATA_WIDTH/STROBE_W-1:0],{(TDATA_W-(MM_DATA_WIDTH/STROBE_W)){1'b0}}};
                     end else begin
                       pld_stb <= {{STROBE_W{1'b1}},{(INDX-STROBE_W){1'b0}}};
                       pld_reg <= {pld[MM_DATA_WIDTH-1:0],{(TDATA_W-MM_DATA_WIDTH){1'b0}}};
                     end
                  end else begin
                    if(i_csr_type==LOWER32) begin
                       pld_stb <= {1'b1,pld_stb[INDX-1:1]};
                       pld_reg <= {pld[MM_DATA_WIDTH/STROBE_W-1:0],pld_reg[TDATA_W-1:(MM_DATA_WIDTH/STROBE_W)]};
                     end else begin
                       pld_stb <= {{STROBE_W{1'b1}},pld_stb[INDX-1:STROBE_W]};
                       pld_reg <= {pld[MM_DATA_WIDTH-1:0],pld_reg[TDATA_W-1:MM_DATA_WIDTH]};
                     end
                  end
               end else if (i_csr_eop && o_csr_rdy) begin
                  pld_reg <= {TDATA_W{1'b0}};
                  pld_stb <= {INDX{1'b0}};
               end
            end
         endcase
      end
   end

   //------------------------------------------
   // TX Data remapping
   //------------------------------------------
   // When Data reg is full, write to buffer as it is, without shifting.
   // When EOP is asserted data reg may be full or partly filled.
   // If data reg is party filled, shift out empty bits, and write data with left most bytes filled

   assign buf_tlast = i_csr_eop;
   assign o_csr_rdy = ~buf_full & ~buf_eop_full;
   
   always @(*) begin
      buf_tdata = 0;
      buf_tkeep = 0;
      buf_wen   = 0;
      if(i_csr_eop && o_csr_rdy) begin
         if(&pld_stb) begin
            buf_wen   = 1;
            buf_tdata = pld_reg;
            buf_tkeep = {TKEEP_W{1'b1}};
         end else begin
            buf_wen = |pld_stb;
            for (int j=0;j<INDX;j++) begin
               if(!pld_stb[j]) begin
                  buf_tdata = pld_reg >> ((j+1)*32);
                  buf_tkeep = {TKEEP_W{1'b1}} >> ((j+1)*4);
               end
            end
         end
      end else if (i_csr_val && o_csr_rdy) begin
         if(&pld_stb) begin
            buf_wen   = 1;
            buf_tdata = pld_reg;
            buf_tkeep = {TKEEP_W{1'b1}};
         end
      end
   end

   //------------------------------------------
   // TX Buffer
   //------------------------------------------

   scfifo  buf_inst (
      .clock        (clk),
      .data         ({buf_tlast,buf_tkeep,buf_tdata}),
      .rdreq        (buf_ren),
      .wrreq        (buf_wen),
      .almost_empty (),
      .almost_full  (buf_full),
      .empty        (buf_empty),
      .full         (),
      .q            (buf_dout),
      .usedw        (),
      .aclr         (1'b0),
      .eccstatus    (),
      .sclr         (rst));
   defparam
      buf_inst.add_ram_output_register= "OFF",
      buf_inst.almost_full_value      = MAX_BUF_DEPTH-2,
      buf_inst.enable_ecc             = "FALSE",
      `ifdef DEVICE_FAMILY
      buf_inst.intended_device_family = `DEVICE_FAMILY,
      `else
      buf_inst.intended_device_family = "Stratix 10",
      `endif
      buf_inst.lpm_hint               = "M20K",
      buf_inst.lpm_numwords           = MAX_BUF_DEPTH,
      buf_inst.lpm_showahead          = "ON",
      buf_inst.lpm_type               = "scfifo",
      buf_inst.lpm_width              = TDATA_W+TKEEP_W+1,
      buf_inst.lpm_widthu             = $clog2(MAX_BUF_DEPTH),
      buf_inst.overflow_checking      = "ON",
      buf_inst.underflow_checking     = "ON",
      buf_inst.use_eab                = "ON";

   //------------------------------------------
   // TX EOP Buffer
   //------------------------------------------
   // Write EOP to a FIFO such that we dont need counters to track packets
   // When FIFO has an entry, read logic issues read for full packet, thereby avoiding
   // IDLE cycles in  between beats
   localparam EOP_BUF_DEPTH = 8;

   scfifo  buf_eop_inst (
      .clock        (clk),
      .data         (buf_tlast),
      .rdreq        (buf_eop_ren),
      .wrreq        ( buf_tlast & buf_wen),
      .almost_empty (),
      .almost_full  (buf_eop_full),
      .empty        (buf_eop_empty),
      .full         (),
      .q            (),
      .usedw        (),
      .aclr         (1'b0),
      .eccstatus    (),
      .sclr         (rst));
   defparam
      buf_eop_inst.add_ram_output_register= "OFF",
      buf_eop_inst.almost_full_value      = EOP_BUF_DEPTH-2,
      buf_eop_inst.enable_ecc             = "FALSE",
      `ifdef DEVICE_FAMILY
      buf_eop_inst.intended_device_family = `DEVICE_FAMILY,
      `else
      buf_eop_inst.intended_device_family = "Stratix 10",
      `endif
      buf_eop_inst.lpm_hint               = "MLAB",
      buf_eop_inst.lpm_numwords           = EOP_BUF_DEPTH,
      buf_eop_inst.lpm_showahead          = "ON",
      buf_eop_inst.lpm_type               = "scfifo",
      buf_eop_inst.lpm_width              = 1,
      buf_eop_inst.lpm_widthu             = $clog2(EOP_BUF_DEPTH),
      buf_eop_inst.overflow_checking      = "ON",
      buf_eop_inst.underflow_checking     = "ON",
      buf_eop_inst.use_eab                = "ON";


   //------------------------------------------
   // TX Out Stream
   //------------------------------------------
   // Write to Buffer may not be a continous stream. Due to 64b to 512 b packing, it takes around
   // 8 cycles between eac wrtes. If buffer is read out when it is nonempty, there may be idle
   // cycles between TVALID. This may blcok other paths to PF-VF mux reducing performance.
   // Wait for EOP(full packet) before starting to readout.
   // This logic is written in a combinational way such that buffer read enable canbe stopped
   // immideately when TLAST of current packet is detected

   always @(posedge clk) begin
      if(rst) begin
         rd_pres_state <= WAIT_FOR_EOP;
      end else begin
         rd_pres_state <= rd_next_state;
      end
   end

   always @(*) begin
      rd_next_state = rd_pres_state;
      buf_eop_ren = 0;
      buf_ren     = 0;
      axi_tx_if_p.tvalid = 1'b0;
      axi_tx_if_p.tdata = 0;
      axi_tx_if_p.tkeep = 0;
      axi_tx_if_p.tlast = 0;
      axi_tx_if_p.tuser_vendor = 0;
      case(rd_pres_state)
         WAIT_FOR_EOP: begin
            if(~buf_eop_empty && axi_tx_if_p.tready) begin
               rd_next_state = READ_BUF;
               buf_eop_ren = ~buf_empty;
               buf_ren     = ~buf_empty;
               axi_tx_if_p.tvalid = ~buf_empty;
               axi_tx_if_p.tdata = buf_dout[TDATA_W-1: 0];
               axi_tx_if_p.tkeep = buf_dout[TDATA_W +: TKEEP_W];
               axi_tx_if_p.tlast = buf_dout[TDATA_W+TKEEP_W];
               axi_tx_if_p.tuser_vendor = {TUSER_W{1'b0}};
            end
         end
         READ_BUF: begin
            buf_ren = ~buf_empty & axi_tx_if_p.tready;
            if(buf_dout[TDATA_W+TKEEP_W] && axi_tx_if_p.tready) begin
               buf_eop_ren = 0;
               rd_next_state = WAIT_FOR_EOP;
            end
            axi_tx_if_p.tvalid = ~buf_empty;
            axi_tx_if_p.tdata = buf_dout[TDATA_W-1: 0];
            axi_tx_if_p.tkeep = buf_dout[TDATA_W +: TKEEP_W];
            axi_tx_if_p.tlast = buf_dout[TDATA_W+TKEEP_W];
            axi_tx_if_p.tuser_vendor = {TUSER_W{1'b0}};
         end
      endcase
   end

   //------------------------------------------
   // AXIS Out Register
   //------------------------------------------
   // AXI Register stage is placed here so a snot to create any timing issues with preceeding combo.
   // This module is expected to run at ~100mhz for now, but still making sure it can run at higher margin.
   // Another reason to use this register stage is that preceeding combo logic expects tready sginal
   // to be high before readong from FIFO & asserting tvalid. But at actual block interface, AXIS tvalid
   // should not wait for tready to be high.

   axis_register #( .MODE(0), .TDATA_WIDTH(TDATA_W), .ENABLE_TUSER(1), .TUSER_WIDTH(TUSER_W))
   axi_tx_stage_1 (
      .clk       (clk  ),
      .rst_n     (~rst ),
      .s_tready  (axi_tx_if_p.tready  ),
      .s_tvalid  (axi_tx_if_p.tvalid  ),
      .s_tdata   (axi_tx_if_p.tdata   ),
      .s_tkeep   (axi_tx_if_p.tkeep   ),
      .s_tlast   (axi_tx_if_p.tlast   ),
      .s_tuser   (axi_tx_if_p.tuser_vendor   ),
      .m_tready  (o_tx_st.tready      ),
      .m_tvalid  (o_tx_st.tvalid      ),
      .m_tdata   (o_tx_st.tdata       ),
      .m_tkeep   (o_tx_st.tkeep       ),
      .m_tlast   (o_tx_st.tlast       ),
      .m_tuser   (o_tx_st.tuser_vendor)
   );

endmodule
//----------------------------------------------------------------------------
//
// End
//
//----------------------------------------------------------------------------

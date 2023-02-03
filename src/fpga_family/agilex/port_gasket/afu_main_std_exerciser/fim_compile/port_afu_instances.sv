// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//  Instantiates HE-MEM, HE-HSSI and HE-MEM-TG in FIM base compile
//               HE-LPBK, HE-HSSI and HE-MEM-TG in-tree PR compile
// -----------------------------------------------------------------------------
// Created for use of the PF/VF Configuration tool, where only AFU endpoints are
// connected. The user is instructed to utilize the PORT_PF_VF_INFO parameter
// to access all information regarding a specific endpoint with a PID.
// 
// The default PID mapping is as follows:
//    PID 0 - PF0/VF0 HE-MEM
//    PID 1 - PF0/VF1 HE-HSSI
//    PID 2 - PF0/VF2 HE-MEM-TG
//    PID 3+ - NULL AFUs
//
// Note that when CVL is included, HE-HSSI is moved to the static region 
// (afu_top.fim_afu_instances) and the PID values are reduced by 1


`include "fpga_defines.vh"

module port_afu_instances
   import pcie_ss_axis_pkg::*;
   import ofs_axi_mm_pkg::*;
   import he_lb_pkg::*;
# (
   parameter PG_NUM_PORTS    = 1,
   parameter pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t[PG_NUM_PORTS-1:0] PORT_PF_VF_INFO =
                {PG_NUM_PORTS{pcie_ss_hdr_pkg::ReqHdr_pf_vf_info_t'(0)}},

   parameter NUM_MEM_CH      = 0,
   parameter MAX_ETH_CH      = ofs_fim_eth_plat_if_pkg::MAX_NUM_ETH_CHANNELS,
   parameter NUM_TAGS        = ofs_pcie_ss_cfg_pkg::PCIE_EP_MAX_TAGS,
   parameter AW_REG_MODE = 0,
   parameter W_REG_MODE = 0,
   parameter B_REG_MODE = 0,
   parameter AR_REG_MODE = 0,
   parameter R_REG_MODE = 0
)(
   input  logic clk,
   input  logic clk_div2,
   input  logic clk_div4,
   input  logic uclk_usr,
   input  logic uclk_usr_div2,

   input  logic rst_n,
   input  logic [PG_NUM_PORTS-1:0] port_rst_n,
   
   // PCIe A ports are the standard TLP channels. All host responses
   // arrive on the RX A port.
   pcie_ss_axis_if.source        afu_axi_tx_a_if [PG_NUM_PORTS-1:0],
   pcie_ss_axis_if.sink          afu_axi_rx_a_if [PG_NUM_PORTS-1:0],
   // PCIe B ports are a second channel on which reads and interrupts
   // may be sent from the AFU. To improve throughput, reads on B may flow
   // around writes on A through PF/VF MUX trees until writes are committed
   // to the PCIe subsystem. AFUs may tie off the B port and send all
   // messages to A.
   pcie_ss_axis_if.source        afu_axi_tx_b_if [PG_NUM_PORTS-1:0],
   // Write commits are signaled here on the RX B port, indicating the
   // point at which the A and B channels become ordered within the FIM.
   // Commits are signaled after tlast of a write on TX A, after arbitration
   // with TX B within the FIM. The commit is a Cpl (without data),
   // returning the tag value from the write request. AFUs that do not
   // need local write commits may ignore this port, but must set
   // tready to 1.
   pcie_ss_axis_if.sink          afu_axi_rx_b_if [PG_NUM_PORTS-1:0]

   `ifdef INCLUDE_HSSI_AND_NOT_CVL
      ,ofs_fim_hssi_ss_tx_axis_if.client hssi_ss_st_tx [MAX_ETH_CH-1:0],
       ofs_fim_hssi_ss_rx_axis_if.client hssi_ss_st_rx [MAX_ETH_CH-1:0],
       ofs_fim_hssi_fc_if.client         hssi_fc [MAX_ETH_CH-1:0],
       input logic [MAX_ETH_CH-1:0]      i_hssi_clk_pll
   `endif


`ifdef INCLUDE_DDR4
   ,ofs_fim_emif_axi_mm_if.user     ext_mem_if [NUM_MEM_CH-1:0]
`endif
);


// Index of each feature in the AXIS bus
 `ifdef INCLUDE_CVL
   parameter NUM_DEFAULT_AFUS = 2;
   localparam AXIS_HEM_TG_PID = 1;
   localparam AXIS_HEM_PID    = 0;
  `else
   parameter NUM_DEFAULT_AFUS = 3;
   localparam AXIS_HEM_TG_PID = 2;
   localparam AXIS_HEH_PID    = 1;
   localparam AXIS_HEM_PID    = 0;
 `endif

// Mem TG Channels
`ifdef INCLUDE_MEM_TG
   `ifndef USE_NULL_HE_MEM_TG
      localparam NUM_TG = (NUM_MEM_CH > 1) ? NUM_MEM_CH-1 : 0;
   `else
      localparam NUM_TG = 0;
   `endif
`else
   localparam NUM_TG = 0;
`endif
   
`ifdef PR_COMPILE
   //---------------------------------------------------------------------------------------------------
   // PR_COMPILE is set during in-tree ofs-dev PR compile. This replaces HE-MEM
   // from FIM base compile to HE-LPBK. After loading the in-tree.gbs, the
   // LPBK GUID should reflect a successful PR
   //---------------------------------------------------------------------------------------------------
   generate if (AXIS_HEM_PID < PG_NUM_PORTS)
      he_lb_top #(
         .PF_ID(PORT_PF_VF_INFO[AXIS_HEM_PID].pf_num),
         .VF_ID(PORT_PF_VF_INFO[AXIS_HEM_PID].vf_num),
         .VF_ACTIVE(PORT_PF_VF_INFO[AXIS_HEM_PID].vf_active)
      ) he_lb_pr (
         .clk        (clk),
         .rst_n      (port_rst_n[AXIS_HEM_PID]),
         .axi_rx_a_if(afu_axi_rx_a_if[AXIS_HEM_PID]),
         .axi_rx_b_if(afu_axi_rx_b_if[AXIS_HEM_PID]),
         .axi_tx_a_if(afu_axi_tx_a_if[AXIS_HEM_PID]),
         .axi_tx_b_if(afu_axi_tx_b_if[AXIS_HEM_PID])
      );
   endgenerate
 
`else // PR_COMPILE
   `ifdef USE_NULL_HE_MEM
       // Memory ports are tied off in this mode 
       generate if (AXIS_HEM_PID<PG_NUM_PORTS)
          he_null #(
              .CSR_DATA_WIDTH (64),
              .CSR_ADDR_WIDTH (16),
              .CSR_DEPTH      (4),
              .PF_ID          (PORT_PF_VF_INFO[AXIS_HEM_PID].pf_num),
              .VF_ID          (PORT_PF_VF_INFO[AXIS_HEM_PID].vf_num),
              .VF_ACTIVE      (PORT_PF_VF_INFO[AXIS_HEM_PID].vf_active)
          ) null_he_mem (
              .clk                (clk),
              .rst_n              (port_rst_n[AXIS_HEM_PID]),
              .i_flr_rst_n (1'b1),
              .i_rx_if     (afu_axi_rx_a_if[AXIS_HEM_PID]),
              .o_tx_if     (afu_axi_tx_a_if[AXIS_HEM_PID])
          );

          // we do not use the TX B port
          assign afu_axi_tx_b_if[AXIS_HEM_PID].tvalid = 1'b0;
          assign afu_axi_rx_b_if[AXIS_HEM_PID].tready = 1'b1;

     `ifdef INCLUDE_DDR4
          //Tie-off memory interface
          always_comb begin : he_mem_tie_off
             ext_mem_if[0].awvalid = 1'b0;
             ext_mem_if[0].wvalid = 1'b0;
             ext_mem_if[0].arvalid = 1'b0;
             ext_mem_if[0].rready = 1'b1;
             ext_mem_if[0].bready = 1'b1;
          end
     `endif
       endgenerate
   `else //(not) USE_NULL_HE_MEM

      //----------------------------------------------------------------
      //  HE-MEM instantiation 
      //----------------------------------------------------------------
      generate if (AXIS_HEM_PID<PG_NUM_PORTS)
       `ifdef INCLUDE_DDR4
         he_mem_top #(
            .PF_ID(PORT_PF_VF_INFO[AXIS_HEM_PID].pf_num),
            .VF_ID(PORT_PF_VF_INFO[AXIS_HEM_PID].vf_num),
            .VF_ACTIVE(PORT_PF_VF_INFO[AXIS_HEM_PID].vf_active),
            .EMIF(1)
         ) he_mem_inst (
            .clk        (clk),
            .rst_n      (port_rst_n[AXIS_HEM_PID]),
            .axi_rx_a_if(afu_axi_rx_a_if[AXIS_HEM_PID]),
            .axi_rx_b_if(afu_axi_rx_b_if[AXIS_HEM_PID]),
            .axi_tx_a_if(afu_axi_tx_a_if[AXIS_HEM_PID]),
            .axi_tx_b_if(afu_axi_tx_b_if[AXIS_HEM_PID]),
            .ext_mem_if (ext_mem_if[0:0])
         );
       `else
         // No external memory available
         he_lb_top #(
            .PF_ID(PORT_PF_VF_INFO[AXIS_HEM_PID].pf_num),
            .VF_ID(PORT_PF_VF_INFO[AXIS_HEM_PID].vf_num),
            .VF_ACTIVE(PORT_PF_VF_INFO[AXIS_HEM_PID].vf_active)
         ) he_lb_inst (
            .clk        (clk),
            .rst_n      (port_rst_n[AXIS_HEM_PID]),
            .axi_rx_a_if(afu_axi_rx_a_if[AXIS_HEM_PID]),
            .axi_rx_b_if(afu_axi_rx_b_if[AXIS_HEM_PID]),
            .axi_tx_a_if(afu_axi_tx_a_if[AXIS_HEM_PID]),
            .axi_tx_b_if(afu_axi_tx_b_if[AXIS_HEM_PID])
         );
       `endif
      endgenerate
   `endif //USE_NULL_HE_MEM
`endif //PR_COMPILE

//----------------------------------------------------------------
//  HE-HSSI Instantiation 
//----------------------------------------------------------------

(* noprune *) ofs_fim_hssi_ss_tx_axis_if hssi_ss_st_tx_t1 [MAX_ETH_CH-1:0] ();
(* noprune *) ofs_fim_hssi_ss_rx_axis_if hssi_ss_st_rx_t1 [MAX_ETH_CH-1:0] ();
`ifndef INCLUDE_HSSI
   generate if (AXIS_HEH_PID<PG_NUM_PORTS)
      he_lb_top #(
         .PF_ID     (PORT_PF_VF_INFO[AXIS_HEH_PID].pf_num),
         .VF_ID     (PORT_PF_VF_INFO[AXIS_HEH_PID].vf_num),
         .VF_ACTIVE (PORT_PF_VF_INFO[AXIS_HEH_PID].vf_active)
      ) hssi_he_lb_topr (
         .clk        (clk),
         .rst_n      (port_rst_n[AXIS_HEH_PID]),
         .axi_rx_a_if(afu_axi_rx_a_if[AXIS_HEH_PID]),
         .axi_rx_b_if(afu_axi_rx_b_if[AXIS_HEH_PID]),
         .axi_tx_a_if(afu_axi_tx_a_if[AXIS_HEH_PID]),
         .axi_tx_b_if(afu_axi_tx_b_if[AXIS_HEH_PID])
      );
   endgenerate
`endif // INCLUDE_HSSI
   
`ifdef INCLUDE_HSSI_AND_NOT_CVL
   generate if (AXIS_HEH_PID<PG_NUM_PORTS)
      // we do not use the TX B port
      assign afu_axi_tx_b_if[AXIS_HEH_PID].tvalid = 1'b0;
      assign afu_axi_rx_b_if[AXIS_HEH_PID].tready = 1'b1;

      for (genvar j=0; j<MAX_ETH_CH; j++) begin
         always_ff @(posedge hssi_ss_st_rx[j].clk) begin
            hssi_ss_st_rx_t1[j].rx <= hssi_ss_st_rx[j].rx;
            hssi_ss_st_rx_t1[j].rst_n <= hssi_ss_st_rx[j].rst_n;
          end
         always_comb begin
              hssi_ss_st_rx_t1[j].clk   = hssi_ss_st_rx[j].clk;
         end
         axis_tx_hssi_pipeline #(
            .TDATA_WIDTH ($bits(hssi_ss_st_tx[j].tx.tdata)),
            .TUSER_WIDTH ($bits(hssi_ss_st_tx[j].tx.tuser))
         ) axis_tx_hssi_pipeline_inst (
            .axis_m (hssi_ss_st_tx[j]),   //client
            .axis_s (hssi_ss_st_tx_t1[j]) //mac
         );
      end
   endgenerate
   
   `ifdef USE_NULL_HE_HSSI
      // HSSI ports are tied off in this mode 
      generate if (AXIS_HEH_PID<PG_NUM_PORTS)
         he_null #(
            .CSR_DATA_WIDTH (64),
            .CSR_ADDR_WIDTH (16),
            .CSR_DEPTH      (4),
            .PF_ID          (PORT_PF_VF_INFO[AXIS_HEH_PID].pf_num),
            .VF_ID          (PORT_PF_VF_INFO[AXIS_HEH_PID].vf_num),
            .VF_ACTIVE      (PORT_PF_VF_INFO[AXIS_HEH_PID].vf_active)
         ) null_he_hssi (
            .clk                (clk),
            .rst_n              (port_rst_n[AXIS_HEH_PID]),
            .i_flr_rst_n (1'b1),
            .i_rx_if     (afu_axi_rx_a_if[AXIS_HEH_PID]),
            .o_tx_if     (afu_axi_tx_a_if[AXIS_HEH_PID])
         );

        // Tie off Tx
         for (genvar j=0; j<MAX_ETH_CH; j++) begin : heh_tvalid
            assign hssi_ss_st_tx_t1[j].tx.tvalid = 1'b0;
         end
      endgenerate
   `else // (not) USE_NULL_HE_HSSI
      generate if (AXIS_HEH_PID<PG_NUM_PORTS) begin : heh_gen
          he_hssi_top #(
             .PF_NUM    (PORT_PF_VF_INFO[AXIS_HEH_PID].pf_num),
             .VF_NUM    (PORT_PF_VF_INFO[AXIS_HEH_PID].vf_num),
             .VF_ACTIVE (PORT_PF_VF_INFO[AXIS_HEH_PID].vf_active)
          ) he_hssi_top (
             .clk            (clk),
             .softreset      (~port_rst_n[AXIS_HEH_PID]),
             .axis_rx_if     (afu_axi_rx_a_if[AXIS_HEH_PID]),
             .axis_tx_if     (afu_axi_tx_a_if[AXIS_HEH_PID]),
             .hssi_ss_st_tx  (hssi_ss_st_tx_t1), //client
             .hssi_ss_st_rx  (hssi_ss_st_rx_t1), //client
             .hssi_fc        (hssi_fc),
             .i_hssi_clk_pll (i_hssi_clk_pll)
         );
      end : heh_gen
      endgenerate
   `endif //USE_NULL_HE_HSSI
`endif //INCLUDE_HSSI_AND_NOT_CVL

//----------------------------------------------------------------
//  HE-MEM-TG instantiation 
//----------------------------------------------------------------
ofs_axi_mm_if mem_tg_helb_ext_mem_if();

generate 
   if ((AXIS_HEM_TG_PID<PG_NUM_PORTS) && (NUM_TG==0)) begin
       he_null #(
           .CSR_DATA_WIDTH (64),
           .CSR_ADDR_WIDTH (16),
           .CSR_DEPTH      (4),
           .PF_ID          (PORT_PF_VF_INFO[AXIS_HEM_TG_PID].pf_num),
           .VF_ID          (PORT_PF_VF_INFO[AXIS_HEM_TG_PID].vf_num),
           .VF_ACTIVE      (PORT_PF_VF_INFO[AXIS_HEM_TG_PID].vf_active)
       ) null_he_mem_tg (
           .clk                (clk),
           .rst_n              (port_rst_n[AXIS_HEM_TG_PID]),
           .i_flr_rst_n (1'b1),
           .i_rx_if     (afu_axi_rx_a_if[AXIS_HEM_TG_PID]),
           .o_tx_if     (afu_axi_tx_a_if[AXIS_HEM_TG_PID])
       );

       // we do not use the TX B port
       assign afu_axi_tx_b_if[AXIS_HEM_TG_PID].tvalid = 1'b0;
       assign afu_axi_rx_b_if[AXIS_HEM_TG_PID].tready = 1'b1;

       //Tie-off memory interface
       for (genvar j=0; j<NUM_TG; j++) begin : he_mem_tg_tie_off
           always_comb begin
               ext_mem_if[j+1].awvalid = 1'b0;
               ext_mem_if[j+1].wvalid = 1'b0;
               ext_mem_if[j+1].arvalid = 1'b0;
               ext_mem_if[j+1].rready = 1'b1;
               ext_mem_if[j+1].bready = 1'b1;
           end
       end
   end else if ((AXIS_HEM_TG_PID<PG_NUM_PORTS) && (NUM_TG!=0)) begin  
      mem_tg2_top #(
         .PF_ID(PORT_PF_VF_INFO[AXIS_HEM_TG_PID].pf_num),
         .VF_ID(PORT_PF_VF_INFO[AXIS_HEM_TG_PID].vf_num),
         .VF_ACTIVE(PORT_PF_VF_INFO[AXIS_HEM_TG_PID].vf_active),
         .NUM_TG(NUM_TG)
      ) mem_tg2_inst (
         .clk            (clk),
         .rst_n          (port_rst_n[AXIS_HEM_TG_PID]),
         .axis_rx_if     (afu_axi_rx_a_if[AXIS_HEM_TG_PID]),
         .axis_tx_if     (afu_axi_tx_a_if[AXIS_HEM_TG_PID]),
         .mem_tg_active  (mem_tg_active)
         `ifdef INCLUDE_DDR4
              ,.ext_mem_if (ext_mem_if[NUM_TG:1]) // user
         `endif
      );

       // we do not use the TX B port
       assign afu_axi_tx_b_if[AXIS_HEM_TG_PID].tvalid = 1'b0;
       assign afu_axi_rx_b_if[AXIS_HEM_TG_PID].tready = 1'b1;
   end // else: !if(NUM_TG==0)
   //endgenerate 
endgenerate

genvar i;
generate
    for(i=NUM_DEFAULT_AFUS; i<PG_NUM_PORTS; i=i+1)  begin
      he_null #(
         .PF_ID (PORT_PF_VF_INFO[i].pf_num),
         .VF_ID (PORT_PF_VF_INFO[i].vf_num),
         .VF_ACTIVE (PORT_PF_VF_INFO[i].vf_active)
      ) he_null_prr (
         .clk (clk),
         .rst_n (rst_n),
         .i_rx_if (afu_axi_rx_a_if[i]),
         .o_tx_if (afu_axi_tx_a_if[i]));

       assign afu_axi_tx_b_if[i].tvalid = 1'b0;
       assign afu_axi_rx_b_if[i].tready = 1'b1;
    end
endgenerate

endmodule

// Copyright (C) 2023 Intel Corporation.
// SPDX-License-Identifier: MIT

//
// Description
//-----------------------------------------------------------------------------
//
//   Top level testbench with OFS top level module instantiated as DUT
//
//-----------------------------------------------------------------------------
`include "vendor_defines.vh"
`include "fpga_defines.vh"
`include "ofs_ip_cfg_db.vh"
`include "ofs_fim_mem_defines.vh"

import ofs_fim_cfg_pkg::*;
import ofs_fim_if_pkg::*;
import ofs_fim_pcie_hdr_def::*;
import ofs_fim_pcie_pkg::*;
import ofs_fim_eth_if_pkg::*;

module top_tb ();

logic SYS_REFCLK;
logic PCIE_REFCLK0;
logic PCIE_REFCLK1;
logic PCIE_RESET_N;
logic ETH_REFCLK;
logic flash_reset;
bit outclk_0 = 1'b0; 
bit outclk_1 = 1'b0;
bit outclk_2 = 1'b0;
bit outclk_3 = 1'b0;
bit outclk_4 = 1'b0;
bit outclk_5 = 1'b0;
bit outclk_6 = 1'b0;

initial begin
 `ifdef INCLUDE_PMCI
  force top_tb.DUT.pmci_wrapper.pmci_ss.sdm_mailbox_client.s10_mailbox_client_0.s10_mailbox_client_inst.rsp_fifo.in_valid = 1'b0;
  force top_tb.DUT.pmci_wrapper.pmci_ss.sdm_mailbox_client.s10_mailbox_client_0.s10_mailbox_client_inst.cmd_fifo.out_ready= 1'b0;
 `endif
end

parameter T_OUTCLK_0 = (40'd1_000_000 / `OFS_FIM_IP_CFG_SYS_CLK_CLK0_MHZ);
parameter T_OUTCLK_1 = (40'd1_000_000 / `OFS_FIM_IP_CFG_SYS_CLK_CLK1_MHZ);
parameter T_OUTCLK_2 = (40'd1_000_000 / `OFS_FIM_IP_CFG_SYS_CLK_CLK2_MHZ);
parameter T_OUTCLK_3 = (40'd1_000_000 / `OFS_FIM_IP_CFG_SYS_CLK_CLK3_MHZ);
parameter T_OUTCLK_4 = (40'd1_000_000 / `OFS_FIM_IP_CFG_SYS_CLK_CLK4_MHZ);
parameter T_OUTCLK_5 = (40'd1_000_000 / `OFS_FIM_IP_CFG_SYS_CLK_CLK5_MHZ);
parameter T_OUTCLK_6 = (40'd1_000_000 / `OFS_FIM_IP_CFG_SYS_CLK_CLK6_MHZ);

initial begin
        // #20us;
         #1us;
        force {top_tb.DUT.sys_pll.locked} = 1'b1;
        force top_tb.DUT.sys_pll.outclk_0 = outclk_0; 
        force top_tb.DUT.sys_pll.outclk_1 = outclk_1; 
        force top_tb.DUT.sys_pll.outclk_2 = outclk_2;
        force top_tb.DUT.sys_pll.outclk_3 = outclk_3;
        force top_tb.DUT.sys_pll.outclk_4 = outclk_4;
        force top_tb.DUT.sys_pll.outclk_5 = outclk_5;
        force top_tb.DUT.sys_pll.outclk_6 = outclk_6;

end 
     always #(T_OUTCLK_0/2)  outclk_0 = ~outclk_0; //
     always #(T_OUTCLK_1/2)  outclk_1 = ~outclk_1; //
     always #(T_OUTCLK_2/2)  outclk_2 = ~outclk_2; //
     always #(T_OUTCLK_3/2)  outclk_3 = ~outclk_3; //
     always #(T_OUTCLK_4/2)  outclk_4 = ~outclk_4; //
     always #(T_OUTCLK_5/2)  outclk_5 = ~outclk_5; //
     always #(T_OUTCLK_6/2)  outclk_6 = ~outclk_6; //

initial begin
   SYS_REFCLK   = 0;
   PCIE_REFCLK0 = 0;
   PCIE_REFCLK1 = 0;
   PCIE_RESET_N = 0;
   ETH_REFCLK   = 0;
   flash_reset  = 0;
end

initial 
begin
`ifdef VCD_ON  
   `ifndef VCD_OFF
        $vcdpluson();
        $vcdplusmemon();
   `endif 
`endif
end        

`ifdef INCLUDE_LOCAL_MEM
`ifdef INCLUDE_DDR4

`ifdef OFS_FIM_IP_CFG_LOCAL_MEM_DEFINES_EMIF_DDR4_PARAM_GROUP_0
   ofs_fim_emif_ddr4_if ddr4_mem [ofs_fim_mem_if_pkg::NUM_GROUP_0_DDR4_CHANNELS-1:0] ();
`endif // OFS_FIM_IP_CFG_LOCAL_MEM_DEFINES_EMIF_DDR4_PARAM_GROUP_0
`ifdef OFS_FIM_IP_CFG_LOCAL_MEM_DEFINES_EMIF_DDR4_PARAM_GROUP_1
   ofs_fim_emif_ddr4_group_1_if ddr4_mem_group_1 [ofs_fim_mem_if_pkg::NUM_GROUP_1_DDR4_CHANNELS-1:0] ();
`endif // OFS_FIM_IP_CFG_LOCAL_MEM_DEFINES_EMIF_DDR4_PARAM_GROUP_1


`ifdef INCLUDE_HPS
   ofs_fim_hps_ddr4_if  ddr4_hps (); 
 `endif
`endif
`ifdef INCLUDE_HBM
   bit uib_refclk [ofs_fim_mem_if_pkg::NUM_HBM_DEVICES-1:0];
   bit noc_ctrl_refclk [ofs_fim_mem_if_pkg::NUM_HBM_DEVICES-1:0];
`endif
`endif
      
`ifdef INCLUDE_HSSI
// HSSI serial data for loopback
ofs_fim_hssi_serial_if hssi_if [ofs_fim_eth_plat_if_pkg::NUM_ETH_LANES-1:0] ();
`endif

`ifdef INCLUDE_PMCI                                                                              
  logic          qspi_dclk;                                                 
  logic          qspi_ncs;                                                  
  wire    [3:0]  qspi_data;
  wire           spi_ingress_sclk;  
  wire           spi_ingress_csn;   
  wire           spi_ingress_miso;  
  wire           spi_ingress_mosi;  
  wire           spi_egress_mosi;   
  wire           spi_egress_csn;    
  wire           spi_egress_sclk;   
  wire           spi_egress_miso;   
`endif

initial #2us PCIE_RESET_N = 1; //  IOPLL sim model requires at least 1us of reset
always #5000 SYS_REFCLK   = ~SYS_REFCLK;   // 100MHz
always #5000 PCIE_REFCLK0 = ~PCIE_REFCLK0; // 100MHz
always #5000 PCIE_REFCLK1 = ~PCIE_REFCLK1; // 100MHz
always #3200 ETH_REFCLK   = ~ETH_REFCLK;   // 156.25MHz
always #10000 flash_reset = 1;

top DUT (
   .SYS_REFCLK      (SYS_REFCLK),
   .PCIE_REFCLK0    (PCIE_REFCLK0),
   .PCIE_REFCLK1    (PCIE_REFCLK1),
   .PCIE_RESET_N    (PCIE_RESET_N),

 `ifdef INCLUDE_HSSI
    `ifdef PMCI_QSFP
       //to make QSFP connections without affecting HSSI operations
      .hssi_if          (hssi_if),
    `else
      .qsfp_ref_clk     (ETH_REFCLK),
      .hssi_if          (hssi_if),
    `endif
 `endif

`ifdef INCLUDE_LOCAL_MEM
`ifdef INCLUDE_DDR4

//Fabric DDR4
`ifdef OFS_FIM_IP_CFG_LOCAL_MEM_DEFINES_EMIF_DDR4_PARAM_GROUP_0
      .ddr4_mem  (ddr4_mem),
`endif
`ifdef OFS_FIM_IP_CFG_LOCAL_MEM_DEFINES_EMIF_DDR4_PARAM_GROUP_1
      .ddr4_mem_group_1  (ddr4_mem_group_1),
`endif

`ifdef INCLUDE_HPS
   .ddr4_hps     (ddr4_hps),
`endif
`endif 
`ifdef INCLUDE_HBM
   .uib_refclk      (uib_refclk),
   .noc_ctrl_refclk (noc_ctrl_refclk),
   .hbm_temp        ('{default:'0}),
   .hbm_cattrip     ('{default:'0}),
`endif
`endif
 
`ifdef INCLUDE_PMCI                                                                              
  // AC FPGA - AC card BMC interface 
  .qspi_dclk (qspi_dclk),                                                 
  .qspi_ncs  (qspi_ncs),                                                  
  .qspi_data (qspi_data), 
`ifdef SPI_LB                                                                              
  .spi_ingress_sclk(spi_ingress_sclk),       
  .spi_ingress_csn(spi_ingress_csn),        
  .spi_ingress_miso(spi_ingress_miso),       
  .spi_ingress_mosi(spi_ingress_mosi),       
  .spi_egress_mosi(spi_ingress_mosi),        
  .spi_egress_csn(spi_ingress_csn),         
  .spi_egress_sclk(spi_ingress_sclk),        
  .spi_egress_miso(spi_ingress_miso),         
`endif 
`ifdef BMC_EN
  .spi_ingress_sclk(bmc_m10.ingr_spi_clk),       
  .spi_ingress_csn(bmc_m10.ingr_spi_csn),        
  .spi_ingress_miso(bmc_m10.ingr_spi_miso),       
  .spi_ingress_mosi(bmc_m10.ingr_spi_mosi),       
  .spi_egress_mosi(bmc_m10.egrs_spi_mosi),        
  .spi_egress_csn(bmc_m10.egrs_spi_csn),         
  .spi_egress_sclk(bmc_m10.egrs_spi_clk),        
  .spi_egress_miso(bmc_m10.egrs_spi_miso),         
`endif 
`endif  
 
   .PCIE_RX_P       ('0),
   .PCIE_RX_N       ('0),
   .PCIE_TX_P       (),
   .PCIE_TX_N       ()
);


`ifdef INCLUDE_PMCI                                                                              
// MT25QxxxTop DUT (S, C, HOLD_DQ3, DQ0, DQ1, Vcc, Vpp_W_DQ2, RESET2); 
   
/*   N25Qxxx N25Qxxx (.S (qspi_ncs), 
                    .C_ (qspi_dclk), 
               .HOLD_DQ3(qspi_data[3]),
               //.RESET_DQ3(qspi_data[3]), 
               .DQ0(qspi_data[0]), 
               .DQ1(qspi_data[1]), 
               .Vcc(1), 
               .Vpp_W_DQ2(qspi_data[2]));
*/

`ifdef BMC_EN
   bmc_top  bmc_m10 ();
`endif

`endif



// HSSI serial loopback
`ifdef INCLUDE_HSSI
  `ifdef PMCI_QSFP
  `else
      genvar i;
      generate
          for (i=0;i<ofs_fim_eth_plat_if_pkg::NUM_ETH_LANES;i++) begin
              assign hssi_if[i].rx_p = hssi_if[i].tx_p;
              assign hssi_if[i].rx_n = hssi_if[i].tx_n;
          end
      endgenerate
  `endif
`endif

// EMIF memory model   
`ifdef INCLUDE_LOCAL_MEM
`ifdef INCLUDE_DDR4
`ifdef INCLUDE_HPS
   initial ddr4_hps.ref_clk = '0;
`endif
   genvar ch;

`ifdef OFS_FIM_IP_CFG_LOCAL_MEM_EN_MEM_0
   generate
      for(ch=0; ch < ofs_fim_mem_if_pkg::NUM_GROUP_0_DDR4_CHANNELS; ch = ch+1) begin : mem_model
         initial ddr4_mem[ch].ref_clk = '0;
         always #833 ddr4_mem[ch].ref_clk = ~ddr4_mem[ch].ref_clk; // 1200 MHz

          ed_sim_mem ddr_mem (
         `CONNECT_DDR4_MODEL_TB(mem, mem, ddr4_mem[ch], GROUP_0)
          );

      end
   endgenerate
`endif //OFS_FIM_IP_CFG_LOCAL_MEM_EN_MEM_0

`ifdef OFS_FIM_IP_CFG_LOCAL_MEM_DEFINES_EMIF_DDR4_PARAM_GROUP_1
   generate
      for(ch=0; ch < ofs_fim_mem_if_pkg::NUM_GROUP_1_DDR4_CHANNELS; ch = ch+1) begin : mem_model_grp1
         initial ddr4_mem_group_1[ch].ref_clk = '0;
         always #833 ddr4_mem_group_1[ch].ref_clk = ~ddr4_mem_group_1[ch].ref_clk; // 1200 MHz

         ed_sim_mem_group1 ddr_mem_group_1 (
         `CONNECT_DDR4_MODEL_TB(mem, mem, ddr4_mem_group_1[ch], GROUP_1)
         );

      end
   endgenerate
`endif //OFS_FIM_IP_CFG_LOCAL_MEM_EN_MEM_1


`endif //DDR

`ifdef INCLUDE_HBM
   initial uib_refclk      = '{default:'0};
   initial noc_ctrl_refclk = '{default:'0};
   // 100 MHz refclk
   always #10000 begin : hbm_clocking
      for(int io=0; io < ofs_fim_mem_if_pkg::NUM_HBM_DEVICES; io = io+1) begin
         uib_refclk[io]      = ~uib_refclk[io];
         noc_ctrl_refclk[io] = ~noc_ctrl_refclk[io];
      end
   end
`endif
`endif
   
`ifdef INCLUDE_PMCI
  pmci_if  pmci_if_1();
`endif

 //F-TILE IP Instance
`ifdef FTILE_SIM
ofs_top_auto_tiles ofs_top_auto_tiles();
`endif
  
endmodule

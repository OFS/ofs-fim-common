//=======================================================================
// COPYRIGHT (C) 2013 SYNOPSYS INC.
// This software and the associated documentation are confidential and
// proprietary to Synopsys, Inc. Your use or disclosure of this software
// is subject to the terms and conditions of a written license agreement
// between you, or your company, and Synopsys, Inc. In the event of
// publications, the following notice is applicable:
//
// ALL RIGHTS RESERVED
//
// The entire notice above must be reproduced on all authorized copies.
//-----------------------------------------------------------------------

/**
 * Abstract:
 * Top level PCIe ,AXI and ETH VIP defines for VIP class, interface, tests, sequence, transactions etc. at common place.
 */
 


   `define     PCIE_DRIVER_TRANSACTION_BASE_SEQ_CLASS                  svt_pcie_driver_app_transaction_base_sequence
   `define     PCIE_DRIVER_TRANSACTION_CLASS                           svt_pcie_driver_app_transaction
   `define     PCIE_MEM_TARGET_BASE_SEQ                                svt_pcie_mem_target_service_base_sequence
   `define     PCIE_MEM_SERV                                           svt_pcie_mem_target_service  
   `define     PCIE_DRIVER_MEM_REQ_SEQ                                 svt_pcie_driver_app_mem_request_sequence  
   `define     PCIE_DRIVER_WAIT_FOR_COMPL_SEQ                          svt_pcie_driver_app_service_wait_for_compl_sequence  
   `define     PCIE_DRIVER_WAIT_UNTIL_IDLE_SEQ                         svt_pcie_driver_app_service_wait_until_idle_sequence  
   `define     PCIE_DL_TLP_MON_TRANSACTION                             svt_pcie_dl_tlp_monitor_transaction
   `define     PCIE_TLP_CLASS                                          svt_pcie_tlp
   `define     PCIE_MEM_TARGET_RD_WR_SEQ                               svt_pcie_mem_target_service_rd_wr_sequence
   `define     PCIE_DEV_AGENT                                          svt_pcie_device_agent
   `define     PCIE_DEV_STATUS                                         svt_pcie_device_status
   `define     PCIE_DEV_CFG_CLASS                                      svt_pcie_device_configuration
   `define     PCIE_DEV_AGNT_X16_8G_HDL                                svt_pcie_device_agent_serdes_x16_8g_hdl
   `define     PCIE_DEV_VIR_BASE_SEQ                                   svt_pcie_device_virtual_base_sequence
   `define     PCIE_DEV_VIR_SQR                                        svt_pcie_device_virtual_sequencer
   `define     PCIE_DL_LINK_EN_SEQ                                     svt_pcie_dl_service_set_link_en_sequence
   `define     PCIE_TYPES_CLASS                                        svt_pcie_types
   `define     PCIE_PL_SERV                                            svt_pcie_pl_service
   `define     PCIE_PL_HOT_RST_SEQ                                     svt_pcie_pl_service_set_hot_reset_mode_sequence
   `define      PCIE_PL_SERV_PHY_EN_SEQ                                 svt_pcie_pl_service_set_phy_en_sequence
  `define      PCIE_TL_SERV_SET_TC_MAP_SEQ                             svt_pcie_tl_service_set_tc_map_sequence
   `define     PCIE_DRIVER_DRIVER_APP_MEM_REQUEST_SEQ                  svt_pcie_driver_app_mem_request_sequence


   `define     AXI_MASTER_BASE_SEQUENCE                                svt_axi_master_base_sequence
   `define     AXI_MASTER_TRANSACTION_CLASS                            svt_axi_master_transaction
   `define     AXI_TRANSACTION_CLASS                                   svt_axi_transaction
   `define     AXI_MASTER_READ_XACT_SEQUENCE                           svt_axi_master_read_xact_sequence  
   `define     AXI_IF                                                  svt_axi_if
   `define     AXI_SYS_ENV                                             svt_axi_system_env 
   `define     AXI_SYS_CFG_CLASS                                       svt_axi_system_configuration
   `define     AXI_PORT_CFG_CLASS                                      svt_axi_port_configuration 
   `define     AXI_MASTER_SQR                                          svt_axi_master_sequencer
   `define     AXI_SYS_SQR                                             svt_axi_system_sequencer   
   `define     AXI_SLAVE_CALLBACK                                      svt_axi_slave_callback
   `define     AXI_SLAVE                                               svt_axi_slave

   `define     AXI_SLAVE_BASE_SEQUENCE                                 svt_axi_slave_base_sequence   
   `define     AXI_SLAVE_TRANSACTION_CLASS                             svt_axi_slave_transaction 
   `define     AXI_SLAVE_SQR                                           svt_axi_slave_sequencer 

   `define    ETH_TRANSACTION_CLASS                                   svt_ethernet_transaction
   `define    ETH_AGENT_CLSS                                          svt_ethernet_agent
   `define    ETH_VSQR                                                svt_ethernet_virtual_sequencer
   `define    ETH_TRANSACTION_SQR                                     svt_ethernet_transaction_sequencer
   `define    ETH_AGENT_CFG_CLASS                                     svt_ethernet_agent_configuration
   `define    ETH_TXRX_IF                                             svt_ethernet_txrx_if
   `define    ETH_XXM_BFM_DRV                                         svt_ethernet_xxm_bfm_driver
   `define    ETH_XXM_MON_CHK_DRV                                     svt_ethernet_xxm_mon_chk_driver


    `define    VIP_ERR_CATCHER_CLASS                                   svt_err_catcher
    `define    VIP_CFG                                                 svt_configuration


    `define PCIE_SPEED_2_5G  32'h0000_0002
    `define PCIE_SPEED_5_0G  32'h0000_0004
    `define PCIE_SPEED_8_0G  32'h0000_0008
    `define PCIE_SPEED_16_0G 32'h0000_0010
     //SVT_PCIE_ENABLE_TLP_FIELD_USER_CONTROL_VECTOR_BIT_RESERVED_FIELDS

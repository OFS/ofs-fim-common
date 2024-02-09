// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT


`ifndef COVERAGE_SVH
`define COVERAGE_SVH

class ofs_coverage extends uvm_component;
`uvm_component_utils(ofs_coverage)
virtual coverage_intf cov_intf;

typedef enum int {cache_1=0,cache_2=1,cache_4=2}cache;
typedef enum int {loop=0,read=1,write=2,through=3}tes_mode;
typedef enum int {success=0,unsuprd_req=1,rsvd=2,abort=3}status_compl;
typedef enum int {RdwRRdWr=0,Rd2Wr2=1,Rd4Wr4=2}tput;
 cache REQ_LEN;
 tes_mode TEST_MODE;
 status_compl STAT_COMPL;
 tput TPUT;
//**************************************************RX_COVERGROUP_START*******************************************  
// PCIESS to AFU
 //covergroup RX_CHECK ;
 

 covergroup AXI_ST_RX ;
   `ifndef ENABLE_SOC_HOST_COVERAGE
   `ifdef ENABLE_R1_COVERAGE
      RX_PU_length      : coverpoint cov_intf.rx_length_pu{bins len_pu[]={[1:2]};}
      RX_Bar_num        : coverpoint cov_intf.rx_bar_num{bins bar[]={0};}
   `else
      RX_PU_length   : coverpoint cov_intf.rxreq_length_pu{bins len_pu[]={[1:2]};}
      RX_Bar_num     : coverpoint cov_intf.rxreq_bar_num{bins bar[]={0};}
   `endif
     
 //R1
`ifdef ENABLE_R1_COVERAGE

      RX_R1_PF_num       : coverpoint cov_intf.rx_pf_num{bins R1_pf={0};} 
      RX_R1_VF_num       : coverpoint cov_intf.rx_vf_num {bins R1_vf[]={0,1,2};} 
      RX_R1_Host_Address : coverpoint cov_intf.rx_host_addr_h{bins FME ={[32'hab000000:32'hab00a008]};
                                                              bins PMCI = {[32'hab010000:32'hab01002c]};
                                                              bins HE_HSSI = {[32'hab1c0000:32'hab1c4048]}; 
                                                              bins SS_HSSI = {32'hab030000,32'hab030028,32'hab03002c,32'hab030034,32'hab030038,32'hab03003c};
                                                              bins ST2MM = {32'hab080000,32'hab080008,32'hab08000c};
                                                              bins PRGAS = {32'hab090000,32'hab090008,32'hab09000c};  
                                                              bins HE_LBK = {[32'hab140000:32'hab140140],[32'hab140141:32'hab140f00],[32'hab140f01:32'hab140ff8]}; 
                                                              bins HE_MEM = {[32'hab180000:32'hab180178]};}
     `endif                                                   
      
//AC and F2000x
   `ifndef ENABLE_R1_COVERAGE //For AC and F2000x coverage
      RX_MM_mode        : coverpoint cov_intf.rxreq_MM_mode{bins MM_mode={0};}     
      RX_SLOT_num       : coverpoint cov_intf.rxreq_slot_num{bins slot_num={0};}
      RX_AC_PF_num      : coverpoint cov_intf.rxreq_pf_num {bins AC_pf={0,1,2,3,4};} 
      RX_AC_VF_num      : coverpoint cov_intf.rxreq_vf_num{bins AC_vf[]={0,1,2};}
      RX_AC_VF_active   : coverpoint cov_intf.rxreq_vf_active {bins AC_vf_active[]={1};}
      RX_AC_PF_VF_num   : cross    RX_AC_PF_num,RX_AC_VF_num,RX_AC_VF_active,RX_Bar_num{bins APF       = binsof(RX_AC_PF_num)intersect{0} && binsof(RX_Bar_num)intersect{0};
                                                                                        bins PRGAS     = binsof(RX_AC_PF_num)intersect{1} && binsof(RX_AC_VF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1};
                                                                                        bins HE_LBK    = binsof(RX_AC_PF_num)intersect{2} && binsof(RX_Bar_num)intersect{0};
                                                                                        bins HE_MEM    = binsof(RX_AC_PF_num)intersect{2} && binsof(RX_AC_VF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1};
                                                                                        bins HE_HSSI   = binsof(RX_AC_PF_num)intersect{2} && binsof(RX_AC_VF_num)intersect{1} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1};
                                                                                        bins HE_MEM_TG = binsof(RX_AC_PF_num)intersect{2} && binsof(RX_AC_VF_num)intersect{2} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1};
                                                                                        bins virtio_lbk  = binsof(RX_AC_PF_num)intersect{3} && binsof(RX_Bar_num)intersect{0};
                                                                                        `ifdef INCLUDE_HPS
                                                                                        bins copy_engine = binsof(RX_AC_PF_num)intersect{4} && binsof(RX_Bar_num)intersect{0};
                                                                                    `endif
                                                                                        ignore_bins bar4_igno= binsof(RX_Bar_num)intersect{4};
                                                                                       } 
      RX_AC_Host_Address: coverpoint cov_intf.rxreq_host_addr_h {bins HE_LBK ={[32'hc000_0000:32'hc000_0020],[32'hc000_0100:32'hc000_0178]};
                                                              bins HE_LBK_unused_space={[32'hc000_0028:32'hc000_0098],[32'hc000_0180:32'hc000_ffff]};
                                                              `ifdef INCLUDE_HPS
                                                              bins copy_engine ={[32'he000_0000:32'he000_0020],[32'he000_0100:32'he000_0158]};
                                                              bins copy_engine_unused_space ={[32'he000_0028:32'he000_0098],[32'he000_0160:32'he000_0fff]};
                                                          `endif
                                                              bins qsfp_controller ={[32'h80012000:32'h80012040]};
                                                              bins qsfp_controller_unused_space={[32'h80012048:32'h80012fff]};
                                                              bins ST2MM={[32'h80040000:32'h80040008]};
                                                              bins ST2MM_unused_space={[32'h80040010:32'h8004ffff]}; 
                                                              bins HE_MEM ={[32'h9000_0000:32'h9000_0020],[32'h9000_0100:32'h9000_0178]};
                                                              bins HE_MEM_unused_space={[32'h9000_0028:32'h9000_0098],[32'h9000_0180:32'h9000_ffff]};
                                                              bins HE_HSSI ={[32'h90160000:32'h90160040]};
                                                              bins HE_HSSI_unused_space ={[32'h90160042:32'h9016ffff]};
                                                              bins HSSI_SS ={[32'h8006_0000:32'h8006_00a4],[32'h8006_0800:32'h8006_0828 ]};
                                                              bins HSSI_SS_unused_space ={[32'h8006_00ac:32'h8006_0800],[32'h80060830:32'h8006ffff]};
                                                              bins PMCI ={[32'h8001_0000:32'h8001_0048],[32'h8001_0400:32'h8001_2008]};
                                                              bins PMCI_unused_space ={[32'h8001_0050:32'h8001_0398],[32'h8001_0808:32'h8001_1998]};
                                                              bins PCIE ={[32'h8001_0000:32'h8001_0030]};
                                                              bins PCIE_unused_space ={[32'h8001_0038:32'h8001_0fff]};
                                                              bins FME ={[32'h8000_0000:32'h8000_0068],[32'h8000_1000:32'h8000_4070]}; 
                                                              bins FME_unused_space ={[32'h8000_0070:32'h8000_0998],[32'h80004072:32'h8000ffff]};
                                                              bins PORT_GASKET={[32'h8007_0000:32'h8007_00b8],[32'h8007_1000:32'h8007_3008]};
                                                              bins PORT_GASKET_unused_space={[32'h8007_00c0:32'h8007_0998],[32'h8007_1008:32'h8007_ffff]}; }

     RX_Ac_Host_Address_64 : coverpoint cov_intf.rxreq_host_addr_64{bins HE_LBK_64 ={[64'hc000_0000_0000_0000:64'hc000_0000_0000_0020],[64'hc000_0000_0000_0100:64'hc000_0000_0000_0178]};
                                                                 bins HE_LBK_unused_space_64={[64'hc000_0000_0000_0028:64'hc000_0000_0000_0098],[64'hc000_0000_0000_0180:64'hc000_0000_0000_ffff]};
                                                                 bins HE_MEM_64 ={[64'h9000_0000_0000_0000:64'h9000_0000_0000_0020],[64'h9000_0000_0000_0100:64'h9000_0000_0000_0178]};
                                                                 bins HE_MEM_unused_space_64={[64'h9000_0000_0000_0028:64'h9000_0000_0000_0098],[64'h9000_0000_0000_0180:64'h9000_0000_0000_ffff]};
                                                                 bins qsfp_controller_64 ={[64'h8000_0000_0001_2000:64'h8000_0000_0001_2040]};
                                                                 bins qsfp_controller_unused_space_64={[64'h8000000000012048:64'h8000000000012fff]};
                                                                 `ifdef INCLUDE_HPS
                                                                 bins copy_engine_64 ={[64'he000_0000_0000_0000:64'he000_0000_0000_0020],[64'he000_0000_0000_0100:64'he000_0000_0000_0158]};
                                                                 bins copy_engine_unused_space_64 ={[64'he000_0000_0000_0028:64'he000_0000_0000_0098],[64'he000_0000_0000_0160:64'he000_0000_0000_0fff]};
                                                             `endif
                                                                 bins T2MM_64={[64'h8000000000040000:64'h8000000000040008]};
                                                                 bins ST2MM_unused_space_64={[64'h8000000000040010:64'h800000000004ffff]}; 
                                                                 bins HE_HSSI_64 ={[64'h9000000000160000:64'h9000000000160040]};
                                                                 bins HE_HSSI_unused_space_64 ={[64'h9000000000160042:64'h900000000016ffff]};
                                                                 bins HSSI_SS_64 ={[64'h8000_0000_0006_0000:64'h8000_0000_0006_00a4],[64'h8000_0000_0006_0800:64'h8000_0000_0006_0828]};
                                                                 bins HSSI_SS_unused_space_64 ={[64'h8000_0000_0006_00ac:64'h8000_0000_0006_0800],[64'h8000_0000_0006_0830:64'h8000_0000_0006_ffff]};
                                                                 bins PMCI_64 ={[64'h8000_0000_0001_0000:64'h8000_0000_0001_0048],[64'h8000_0000_0001_0400:64'h8000_0000_0001_2008]};
                                                                 bins PMCI_unused_space_64 ={[64'h8000_0000_0001_0802:64'h8000_0000_0001_1fff]};
                                                                 bins PCIE_64 ={[64'h8000_0000_0001_0000:64'h8000_0000_0001_0030]};
                                                                 bins PCIE_unused_space ={[64'h8000_0000_0001_0038:64'h8000_0000_0001_0fff]};
                                                                 bins FME_64 ={[64'h8000_0000_0000_0000:64'h8000_0000_0000_0068],[64'h8000_0000_0000_1000:64'h8000_0000_0000_4070]};
                                                                 bins FME_unused_space_64 ={[64'h8000_0000_0000_0070:64'h8000_0000_0000_0998],[64'h8000_0000_0000_4072:64'h8000_0000_0000_ffff]};
                                                                 bins PORT_GASKET_64={[64'h8000_0000_0007_0000:64'h8000_0000_0007_00b8],[64'h8000_0000_0007_1000:64'h8000_0000_0007_3008]};
                                                                 bins PORT_GASKET_unused_space={[64'h8000_0000_0007_00c0:64'h8000_0000_0007_0998],[64'h8000_0000_0007_1008:64'h8000_0000_0007_ffff]}; } 
     
     RX_format_type        : coverpoint cov_intf.rxreq_fmt_type{bins format_type[]={0,32,64,96,114,115};
                                                           ignore_bins rx_format_type_igno={[1:31],[33:63],[65:95],[97:112],113,[116:255]};}  

     RX_Address_fmt_type   : cross  RX_AC_PF_num,RX_AC_VF_num,RX_AC_VF_active,RX_Bar_num,RX_format_type{
                                                                  bins b1 =binsof(RX_AC_PF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{0};
                                                                  bins b2 =binsof(RX_AC_PF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{32};
                                                                  bins b3 =binsof(RX_AC_PF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{64};
                                                                  bins b4 =binsof(RX_AC_PF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{96};
                                                                  bins b5 =binsof(RX_AC_PF_num)intersect{1} && binsof(RX_AC_VF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{0};
                                                                  bins b6 =binsof(RX_AC_PF_num)intersect{1} && binsof(RX_AC_VF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{32};
                                                                  bins b7 =binsof(RX_AC_PF_num)intersect{1} && binsof(RX_AC_VF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{64};
                                                                  bins b8 =binsof(RX_AC_PF_num)intersect{1} && binsof(RX_AC_VF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{96};
                                                                  bins b9 =binsof(RX_AC_PF_num)intersect{2} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{0};
                                                                  bins b10=binsof(RX_AC_PF_num)intersect{2} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{32};
                                                                  bins b11=binsof(RX_AC_PF_num)intersect{2} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{64};
                                                                  bins b12=binsof(RX_AC_PF_num)intersect{2} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{96};
                                                                  bins b13=binsof(RX_AC_PF_num)intersect{2} && binsof(RX_AC_VF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{0};
                                                                  bins b14=binsof(RX_AC_PF_num)intersect{2} && binsof(RX_AC_VF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{32};
                                                                  bins b15=binsof(RX_AC_PF_num)intersect{2} && binsof(RX_AC_VF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{64};
                                                                  bins b16=binsof(RX_AC_PF_num)intersect{2} && binsof(RX_AC_VF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{96};
                                                                  bins b17=binsof(RX_AC_PF_num)intersect{2} && binsof(RX_AC_VF_num)intersect{1} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{0};
                                                                  bins b18=binsof(RX_AC_PF_num)intersect{2} && binsof(RX_AC_VF_num)intersect{1} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{32};
                                                                  bins b19=binsof(RX_AC_PF_num)intersect{2} && binsof(RX_AC_VF_num)intersect{1} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{64};
                                                                  bins b20=binsof(RX_AC_PF_num)intersect{2} && binsof(RX_AC_VF_num)intersect{1} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{96};
                                                                  bins b21=binsof(RX_AC_PF_num)intersect{2} && binsof(RX_AC_VF_num)intersect{2} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{0};
                                                                  bins b22=binsof(RX_AC_PF_num)intersect{2} && binsof(RX_AC_VF_num)intersect{2} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{32};
                                                                  bins b23=binsof(RX_AC_PF_num)intersect{2} && binsof(RX_AC_VF_num)intersect{2} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{64};
                                                                  bins b24=binsof(RX_AC_PF_num)intersect{2} && binsof(RX_AC_VF_num)intersect{2} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{96};
                                                                  bins b25=binsof(RX_AC_PF_num)intersect{3} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{0};
                                                                  bins b26=binsof(RX_AC_PF_num)intersect{3} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{32};
                                                                  bins b27=binsof(RX_AC_PF_num)intersect{3} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{64};
                                                                  bins b28=binsof(RX_AC_PF_num)intersect{3} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{96};
                                                                  bins b29=binsof(RX_AC_PF_num)intersect{4} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{0};
                                                                  bins b30=binsof(RX_AC_PF_num)intersect{4} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{32};
                                                                  bins b31=binsof(RX_AC_PF_num)intersect{4} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{64};
                                                                  bins b32=binsof(RX_AC_PF_num)intersect{4} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{96};
                                                                 ignore_bins fmt_type_ignore = binsof(RX_format_type)intersect{114,115};
                                                                 ignore_bins bar4_igno= binsof(RX_Bar_num)intersect{4};
                                                                 }         
         
     //PMCI
      RX_MCTP_length     : coverpoint cov_intf.rx_mctp_len{bins min={1};
                                                           bins max={16};
                                                           bins mid={[2:15]};}
      RX_MCTP_msg_code   : coverpoint cov_intf.rx_mctp_msg_code{bins msg_code={127};}
      RX_MCTP_vdm_code   : coverpoint cov_intf.rx_mctp_vdm_code{bins vdm_id={16'h1ab4};}
      RX_MCTP_multi_pkt_seq: coverpoint cov_intf.rx_mctp_multi_pkt_seq{bins pkt_seq[]={0,1,2,3};}

 `endif
    
   `ifdef ENABLE_R1_COVERAGE
       RX_PU_mode     : coverpoint cov_intf.rx_tuser[0]{bins PU_mode={0};}
   `else
       RX_PU_mode  : coverpoint cov_intf.rxreq_tuser[0]{bins PU_mode={0};}
   `endif
  `ifdef ENABLE_R1_COVERAGE
      RX_format_type : coverpoint cov_intf.rx_fmt_type{bins format_type[]={0,64};
                                          ignore_bins rx_format_type_igno={[1:31],32,[33:63],[65:95],96,[97:114],[116:255]};} 
  `endif
   `endif

endgroup
 covergroup HOST_AXI_ST_RX ;
   `ifdef ENABLE_SOC_HOST_COVERAGE
      HOST_RX_PU_length      : coverpoint cov_intf.HOST_rxreq_length_pu{bins len_pu[]={[1:2]};}
      HOST_RX_Bar_num        : coverpoint cov_intf.HOST_rxreq_bar_num{bins bar[]={0};}

      HOST_RX_MM_mode        : coverpoint cov_intf.HOST_rxreq_MM_mode{bins HOST_MM_mode={0};}     
      HOST_RX_SLOT_num       : coverpoint cov_intf.HOST_rxreq_slot_num{bins HOST_slot_num={0};}
      HOST_RX_AC_PF_num      : coverpoint cov_intf.HOST_rxreq_pf_num {bins HOST_AC_pf={0,1};} 
      HOST_RX_AC_PF_BAR_num  : cross    HOST_RX_AC_PF_num,HOST_RX_Bar_num{bins HE_LBK    = binsof(HOST_RX_AC_PF_num)intersect{1} && binsof(HOST_RX_Bar_num)intersect{0};
                                                                                        ignore_bins HOST_bar4_igno= binsof(HOST_RX_Bar_num)intersect{4};
                                                                                       } 
      HOST_RX_AC_Host_Address: coverpoint cov_intf.HOST_rxreq_host_addr_h {bins HE_LBK ={[32'ha000_0000:32'ha000_0020],[32'ha000_0100:32'ha000_0178]};
                                                              bins HE_LBK_unused_space={[32'ha000_0028:32'ha000_0098],[32'ha000_0180:32'ha000_ffff]};
                                                              bins HOST_PCIE ={[32'h8000_0000:32'h8000_0030]};
                                                              bins HOST_PCIE_unused_space ={[32'h8000_0038:32'h8000_0fff]};
                                                              }

     HOST_RX_Ac_Host_Address_64 : coverpoint cov_intf.HOST_rxreq_host_addr_64{bins HE_LBK_64 ={[64'ha000_0000_0000_0000:64'ha000_0000_0000_0020],[64'ha000_0000_0000_0100:64'ha000_0000_0000_0178]};
                                                                 bins HE_LBK_unused_space_64={[64'ha000_0000_0000_0028:64'ha000_0000_0000_0098],[64'ha000_0000_0000_0180:64'ha000_0000_0000_ffff]};
                                                                 bins HOST_PCIE_64 ={[64'h8000_0000_0000_0000:64'h8000_0000_0000_0030]};
                                                                 bins HOST_PCIE_unused_space ={[64'h8000_0000_0000_0038:64'h8000_0000_0000_0fff]};
                                                                 }
     
     HOST_RX_format_type        : coverpoint cov_intf.HOST_rxreq_fmt_type{bins HOST_format_type[]={0,32,64,96,114,115};
                                                           ignore_bins HOST_rx_format_type_igno={[1:31],[33:63],[65:95],[97:112],113,[116:255]};}  

     HOST_RX_Address_fmt_type   : cross  HOST_RX_AC_PF_num,HOST_RX_Bar_num,HOST_RX_format_type{
                                                                  bins HOST_b1 =binsof(HOST_RX_AC_PF_num)intersect{0} && binsof(HOST_RX_Bar_num)intersect{0} && binsof(HOST_RX_format_type)intersect{0};
                                                                  bins HOST_b2 =binsof(HOST_RX_AC_PF_num)intersect{0} && binsof(HOST_RX_Bar_num)intersect{0} && binsof(HOST_RX_format_type)intersect{32};
                                                                  bins HOST_b3 =binsof(HOST_RX_AC_PF_num)intersect{0} && binsof(HOST_RX_Bar_num)intersect{0} && binsof(HOST_RX_format_type)intersect{64};
                                                                  bins HOST_b4 =binsof(HOST_RX_AC_PF_num)intersect{0} && binsof(HOST_RX_Bar_num)intersect{0} && binsof(HOST_RX_format_type)intersect{96};
                                                                  bins HOST_b5 =binsof(HOST_RX_AC_PF_num)intersect{1} && binsof(HOST_RX_Bar_num)intersect{0} && binsof(HOST_RX_format_type)intersect{0};
                                                                  bins HOST_b6 =binsof(HOST_RX_AC_PF_num)intersect{1} && binsof(HOST_RX_Bar_num)intersect{0} && binsof(HOST_RX_format_type)intersect{32};
                                                                  bins HOST_b7 =binsof(HOST_RX_AC_PF_num)intersect{1} && binsof(HOST_RX_Bar_num)intersect{0} && binsof(HOST_RX_format_type)intersect{64};
                                                                  bins HOST_b8 =binsof(HOST_RX_AC_PF_num)intersect{1} && binsof(HOST_RX_Bar_num)intersect{0} && binsof(HOST_RX_format_type)intersect{96};
                                                                                         ignore_bins HOST_fmt_type_ignore = binsof(HOST_RX_format_type)intersect{114,115};
                                                                 ignore_bins HOST_bar4_igno= binsof(HOST_RX_Bar_num)intersect{4};
                                                                 }
      HOST_RX_MCTP_length     : coverpoint cov_intf.HOST_rx_mctp_len{bins min={1};
                                                           bins max={16};
                                                           bins mid={[2:15]};}
      HOST_RX_MCTP_msg_code   : coverpoint cov_intf.HOST_rx_mctp_msg_code{bins msg_code={127};}
      HOST_RX_MCTP_vdm_code   : coverpoint cov_intf.HOST_rx_mctp_vdm_code{bins vdm_id={16'h1ab4};}
      HOST_RX_MCTP_multi_pkt_seq: coverpoint cov_intf.HOST_rx_mctp_multi_pkt_seq{bins pkt_seq[]={0,1,2,3};}
                                                                 
  `endif
endgroup
 covergroup SOC_AXI_ST_RX ;
   `ifdef ENABLE_SOC_HOST_COVERAGE
      RX_PU_length   : coverpoint cov_intf.rxreq_length_pu{bins len_pu[]={[1:2]};}
      RX_Bar_num     : coverpoint cov_intf.rxreq_bar_num{bins bar[]={0};}
      
//AC and F2000x
      RX_MM_mode        : coverpoint cov_intf.rxreq_MM_mode{bins MM_mode={0};}     
      RX_SLOT_num       : coverpoint cov_intf.rxreq_slot_num{bins slot_num={0};}
      RX_AC_PF_num      : coverpoint cov_intf.rxreq_pf_num {bins AC_pf={0};} 
      RX_AC_VF_num      : coverpoint cov_intf.rxreq_vf_num{bins AC_vf[]={0,1,2};}
      RX_AC_VF_active   : coverpoint cov_intf.rxreq_vf_active {bins AC_vf_active[]={1};}
      RX_AC_PF_VF_num   : cross    RX_AC_PF_num,RX_AC_VF_num,RX_AC_VF_active,RX_Bar_num{bins APF       = binsof(RX_AC_PF_num)intersect{0} && binsof(RX_Bar_num)intersect{0};
                                                                                        bins HE_MEM    = binsof(RX_AC_PF_num)intersect{0} && binsof(RX_AC_VF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1};
                                                                                        bins HE_HSSI   = binsof(RX_AC_PF_num)intersect{0} && binsof(RX_AC_VF_num)intersect{1} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1};
                                                                                        bins HE_MEM_TG = binsof(RX_AC_PF_num)intersect{0} && binsof(RX_AC_VF_num)intersect{2} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1};
                                                                                        ignore_bins bar4_igno= binsof(RX_Bar_num)intersect{4};
                                                                                       } 
      RX_AC_Host_Address: coverpoint cov_intf.rxreq_host_addr_h {bins qsfp_controller ={[32'h80012000:32'h80012040]};
                                                              bins qsfp_controller_unused_space={[32'h80012048:32'h80012fff]};
                                                              bins ST2MM={[32'h80100000:32'h80100008]};
                                                              bins ST2MM_unused_space={[32'h80100010:32'h8010ffff]}; 
                                                              bins HE_MEM ={[32'h9000_0000:32'h9000_0020],[32'h9000_0100:32'h9000_0178]};
                                                              bins HE_MEM_unused_space={[32'h9000_0028:32'h9000_0098],[32'h9000_0180:32'h9000_ffff]};
                                                              bins HE_HSSI ={[32'h90260000:32'h90260040]};
                                                              bins HE_HSSI_unused_space ={[32'h90260042:32'h9026ffff]};
                                                              bins HSSI_SS ={[32'h8001_4000:32'h8001_40a4],[32'h8001_4800:32'h8001_4828 ]};
                                                              bins HSSI_SS_unused_space ={[32'h8001_40ac:32'h8001_4800],[32'h80014830:32'h8014ffff]};
                                                              bins PMCI ={[32'h8008_0000:32'h8008_0048],[32'h8008_0400:32'h8008_2008]};
                                                              bins PMCI_unused_space ={[32'h8008_0050:32'h8008_0398],[32'h8008_0808:32'h8008_1998]};
                                                              bins PCIE ={[32'h8001_0000:32'h8001_0030]};
                                                              bins PCIE_unused_space ={[32'h8001_0038:32'h8001_0fff]};
                                                              bins FME ={[32'h8000_0000:32'h8000_0068],[32'h8000_1000:32'h8000_4070]}; 
                                                              bins FME_unused_space ={[32'h8000_0070:32'h8000_0998],[32'h80004072:32'h8000ffff]};
                                                              bins PORT_GASKET={[32'h8013_0000:32'h8013_00b8],[32'h8013_1000:32'h8013_3008]};
                                                              bins PORT_GASKET_unused_space={[32'h8013_00c0:32'h8013_0998],[32'h8013_1008:32'h8013_ffff]}; }

     RX_Ac_Host_Address_64 : coverpoint cov_intf.rxreq_host_addr_64{
                                                                 bins HE_MEM_64 ={[64'h9000_0000_0000_0000:64'h9000_0000_0000_0020],[64'h9000_0000_0000_0100:64'h9000_0000_0000_0178]};
                                                                 bins HE_MEM_unused_space_64={[64'h9000_0000_0000_0028:64'h9000_0000_0000_0098],[64'h9000_0000_0000_0180:64'h9000_0000_0000_ffff]};
                                                                 bins qsfp_controller_64 ={[64'h8000_0000_0001_2000:64'h8000_0000_0001_2040]};
                                                                 bins qsfp_controller_unused_space_64={[64'h8000000000012048:64'h8000000000012fff]};
                                                                 bins ST2MM_64={[64'h8000000000100000:64'h8000000000100008]};
                                                                 bins ST2MM_unused_space_64={[64'h8000000000100010:64'h800000000010ffff]}; 
                                                                 bins HE_HSSI_64 ={[64'h9000000000260000:64'h9000000000260040]};
                                                                 bins HE_HSSI_unused_space_64 ={[64'h9000000000260042:64'h900000000026ffff]};
                                                                 bins HSSI_SS_64 ={[64'h8000_0000_0001_4000:64'h8000_0000_0001_40a4],[64'h8000_0000_0001_4800:64'h8000_0000_0001_4828]};
                                                                 bins HSSI_SS_unused_space_64 ={[64'h8000_0000_0001_40ac:64'h8000_0000_0001_4800],[64'h8000_0000_0001_4830:64'h8000_0000_0001_4fff]};
                                                                 bins PMCI_64 ={[64'h8000_0000_0008_0000:64'h8000_0000_0008_0048],[64'h8000_0000_0008_0400:64'h8000_0000_0008_2008]};
                                                                 bins PMCI_unused_space_64 ={[64'h8000_0000_0008_0802:64'h8000_0000_0008_1fff]};
                                                                 bins PCIE_64 ={[64'h8000_0000_0001_0000:64'h8000_0000_0001_0030]};
                                                                 bins PCIE_unused_space ={[64'h8000_0000_0001_0038:64'h8000_0000_0001_0fff]};
                                                                 bins FME_64 ={[64'h8000_0000_0000_0000:64'h8000_0000_0000_0068],[64'h8000_0000_0000_1000:64'h8000_0000_0000_4070]};
                                                                 bins FME_unused_space_64 ={[64'h8000_0000_0000_0070:64'h8000_0000_0000_0998],[64'h8000_0000_0000_4072:64'h8000_0000_0000_ffff]};
                                                                 bins PORT_GASKET_64={[64'h8000_0000_0013_0000:64'h8000_0000_0013_00b8],[64'h8000_0000_0013_1000:64'h8000_0000_0013_3008]};
                                                                 bins PORT_GASKET_unused_space={[64'h8000_0000_0013_00c0:64'h8000_0000_0013_0998],[64'h8000_0000_0013_1008:64'h8000_0000_0013_ffff]}; } 
     
     RX_format_type        : coverpoint cov_intf.rxreq_fmt_type{bins format_type[]={0,32,64,96};
                                                           ignore_bins rx_format_type_igno={[1:31],[33:63],[65:95],[97:112],113,[116:255]};}  

     RX_Address_fmt_type   : cross  RX_AC_PF_num,RX_AC_VF_num,RX_AC_VF_active,RX_Bar_num,RX_format_type{
                                                                  bins b1 =binsof(RX_AC_PF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{0};
                                                                  bins b2 =binsof(RX_AC_PF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{32};
                                                                  bins b3 =binsof(RX_AC_PF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{64};
                                                                  bins b4 =binsof(RX_AC_PF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{96};
                                                                  bins b5 =binsof(RX_AC_PF_num)intersect{0} && binsof(RX_AC_VF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{0};
                                                                  bins b6 =binsof(RX_AC_PF_num)intersect{0} && binsof(RX_AC_VF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{32};
                                                                  bins b7 =binsof(RX_AC_PF_num)intersect{0} && binsof(RX_AC_VF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{64};
                                                                  bins b8 =binsof(RX_AC_PF_num)intersect{0} && binsof(RX_AC_VF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{96};
                                                                  bins b9 =binsof(RX_AC_PF_num)intersect{0} && binsof(RX_AC_VF_num)intersect{1} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{0};
                                                                  bins b10=binsof(RX_AC_PF_num)intersect{0} && binsof(RX_AC_VF_num)intersect{1} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{32};
                                                                  bins b11=binsof(RX_AC_PF_num)intersect{0} && binsof(RX_AC_VF_num)intersect{1} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{64};
                                                                  bins b12=binsof(RX_AC_PF_num)intersect{0} && binsof(RX_AC_VF_num)intersect{1} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{96};
                                                                  bins b13=binsof(RX_AC_PF_num)intersect{0} && binsof(RX_AC_VF_num)intersect{2} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{0};
                                                                  bins b14=binsof(RX_AC_PF_num)intersect{0} && binsof(RX_AC_VF_num)intersect{2} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{32};
                                                                  bins b15=binsof(RX_AC_PF_num)intersect{0} && binsof(RX_AC_VF_num)intersect{2} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{64};
                                                                  bins b16=binsof(RX_AC_PF_num)intersect{0} && binsof(RX_AC_VF_num)intersect{2} && binsof(RX_Bar_num)intersect{0} && binsof(RX_AC_VF_active)intersect{1} && binsof(RX_format_type)intersect{96};
                                                                  bins b17=binsof(RX_AC_PF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{0};
                                                                  bins b18=binsof(RX_AC_PF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{32};
                                                                  bins b19=binsof(RX_AC_PF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{64};
                                                                  bins b20=binsof(RX_AC_PF_num)intersect{0} && binsof(RX_Bar_num)intersect{0} && binsof(RX_format_type)intersect{96};

                                                                 ignore_bins fmt_type_ignore = binsof(RX_format_type)intersect{114,115};
                                                                 ignore_bins bar4_igno= binsof(RX_Bar_num)intersect{4};
                                                                 }         
         
    
       RX_PU_mode  : coverpoint cov_intf.rxreq_tuser[0]{bins PU_mode={0};}
  `endif

endgroup

 covergroup AXI_RX_COMPL;
 `ifdef ENABLE_R1_COVERAGE
    RX_PU_cmpl_len  : coverpoint cov_intf.rx_cmpl_len_pu{bins len_pu[]={[1:2]};}
    RX_compl_status : coverpoint cov_intf.rx_cmpl_status{bins cmp_stat[]={[STAT_COMPL.first:STAT_COMPL.last]};
                                                          ignore_bins rx_compl_status_igno = {1,2,3};}      //UR not supported
    RX_compl_type   : coverpoint cov_intf.rx_cmpl_type{bins cmp_typ[]={74}; //4A->74,0A->10,2A->42  
	                    ignore_bins rx_type_igno = {[0:10],[11:41],[43:73],[75:255]};}
 `else
    RX_PU_cmpl_len  : coverpoint cov_intf.rxreq_cmpl_len_pu{bins len_pu[]={[1:2]};}
    RX_compl_status : coverpoint cov_intf.rxreq_cmpl_status{bins cmp_stat[]={[STAT_COMPL.first:STAT_COMPL.last]};
                                                          ignore_bins rx_compl_status_igno = {1,2,3};}      //UR not supported
    RX_compl_type   : coverpoint cov_intf.rx_cmpl_type{bins cmp_typ[]={74}; //4A->74,0A->10,2A->42  
	                    ignore_bins rx_type_igno = {[0:10],[11:41],[43:73],[75:255]};}
   `ifdef ENABLE_SOC_HOST_COVERAGE
      HOST_RX_PU_cmpl_len  : coverpoint cov_intf.HOST_rxreq_cmpl_len_pu{bins len_pu[]={[1:2]};}
      HOST_RX_compl_status : coverpoint cov_intf.HOST_rxreq_cmpl_status{bins cmp_stat[]={[STAT_COMPL.first:STAT_COMPL.last]};
                                                          ignore_bins rx_compl_status_igno = {1,2,3};}      //UR not supported
      HOST_RX_compl_type   : coverpoint cov_intf.rx_cmpl_type{bins cmp_typ[]={74}; //4A->74,0A->10,2A->42  
	                    ignore_bins rx_type_igno = {[0:10],[11:41],[43:73],[75:255]};}
   `endif
 `endif
    RX_DM_cmpl_len  : coverpoint cov_intf.rx_cmpl_len_dm iff(cov_intf.rx_tuser[0]==1){bins sixteenK={[14'h0:14'h3FFF]};}
    RX_DM_cmpl_tag  : coverpoint cov_intf.rx_cmpl_tag_dm iff(cov_intf.rx_tuser[0]==1){bins onek={[10'h0:10'h3FF]};}

endgroup



//**************************************************TX_COVERGROUP_START*******************************************
// AFU -> PCIESS
  covergroup AXI_ST_TX ;
      TX_PU_length   : coverpoint cov_intf.tx_length_pu{bins len_pu[]={[1:2]};} 
      TX_Bar_num     : coverpoint cov_intf.tx_bar_num{bins bar[]={0};}
     

            
//AC AND F2000x
   `ifndef ENABLE_R1_COVERAGE  
      TX_AC_PF_num      : coverpoint cov_intf.tx_pf_num {bins AC_pf={0,1,2,3,4};} 
      TX_AC_VF_num      : coverpoint cov_intf.tx_vf_num{bins AC_vf[]={0,1,2};}
      TX_AC_VF_active   : coverpoint cov_intf.tx_vf_active {bins AC_vf_active[]={1};} 
    
	 
   `else
      TX_R1_PF_num      : coverpoint cov_intf.tx_pf_num{bins R1_pf={0};} 
      TX_R1_VF_num      : coverpoint cov_intf.tx_vf_num {bins R1_vf[]={0,1};}



 `endif

      
     
      TX_DM_length   : coverpoint cov_intf.tx_length_dm iff(cov_intf.tx_tuser[0]==1){bins onetwentyeightB={[24'h40:24'h7F]};
                                                                                     bins twofiftysixB={[24'h80:24'hFF]};}


    
        TX_Host_Address: coverpoint cov_intf.tx_host_addr_h{ bins addr={[32'h0:32'hFFFFFF]};}
        
       `ifndef ENABLE_R1_COVERAGE   //For AC and F2000x
        TX_DM_tag     : coverpoint cov_intf.tx_tag_dm iff(cov_intf.tx_tuser[0]==1){bins eightbittag={[10'h0:10'h0FF]};
                                                                                    bins tenbittag={[10'h100:10'h3FF]}; }
       `ifndef ENABLE_SOC_HOST_COVERAGE
          TX_format_type: coverpoint cov_intf.tx_fmt_type{bins format_type[]={32,48,96,112,114}; 
                                          ignore_bins tx_format_type_igno={[0:31],[33:47],[49:95],[97:111],113,[115:255]};}
       `endif
       `ifdef ENABLE_SOC_HOST_COVERAGE
        TX_format_type: coverpoint cov_intf.tx_fmt_type{bins format_type[]={32,48,96}; 
                                          ignore_bins tx_format_type_igno={[0:31],[33:47],[49:95],[97:111],113,[115:255]};}
        `endif
        TX_vector_num : coverpoint cov_intf.tx_vector_num{bins user_vector_num[]={0,1,2,3};
                                                          bins fme_vector_num[]={6};
                                           ignore_bins tx_vector_num_igno={[4:5],[7:255],[256:65535]};}
        TX_vector_num_fmt_type: cross TX_vector_num,TX_format_type{bins v0= binsof(TX_vector_num)intersect{0} && binsof(TX_format_type)intersect{48};
                                                                   bins v1= binsof(TX_vector_num)intersect{1} && binsof(TX_format_type)intersect{48};
                                                                   bins v2= binsof(TX_vector_num)intersect{2} && binsof(TX_format_type)intersect{48};
                                                                   bins v3= binsof(TX_vector_num)intersect{3} && binsof(TX_format_type)intersect{48};
                                                                   bins v6= binsof(TX_vector_num)intersect{6} && binsof(TX_format_type)intersect{48};
                                                                   ignore_bins fmt_type_ignore = binsof(TX_format_type)intersect{32,96,112,114};}

       `ifndef ENABLE_SOC_HOST_COVERAGE
        //PMCI
        TX_MCTP_length     : coverpoint cov_intf.tx_mctp_len{bins min={1};
                                                           bins mid={[2:15]};
                                                           bins max={16};}
        TX_MCTP_msg_code   : coverpoint cov_intf.tx_mctp_msg_code{bins msg_code={127};}
        TX_MCTP_vdm_code   : coverpoint cov_intf.tx_mctp_vdm_code{bins vdm_id={16'h1ab4};}
        TX_MCTP_multi_pkt_seq: coverpoint cov_intf.tx_mctp_multi_pkt_seq{bins pkt_seq[]={0,1,2,3};}
       `endif

        `else
        TX_DM_tag      : coverpoint cov_intf.tx_tag_dm iff(cov_intf.tx_tuser[0]==1){bins eightbittag={[10'h0:10'h0FF]}; }
        TX_format_type: coverpoint cov_intf.tx_fmt_type{bins format_type[]={32,96}; 
                                          ignore_bins tx_format_type_igno={[0:31],[33:47],48,[49:95],[97:114],[115:255]};}
       `endif
                                      
endgroup

//**************************************************HOST_TX_COVERGROUP_START*******************************************
// AFU -> PCIESS
  covergroup HOST_AXI_ST_TX ;
    `ifdef ENABLE_SOC_HOST_COVERAGE
      HOST_TX_PU_length   : coverpoint cov_intf.HOST_tx_length_pu{bins len_pu[]={[1:2]};} 
      HOST_TX_Bar_num     : coverpoint cov_intf.HOST_tx_bar_num{bins bar[]={0};}
     

            
      HOST_TX_AC_PF_num      : coverpoint cov_intf.HOST_tx_pf_num {bins AC_pf={0,1};} 

      
     
      HOST_TX_DM_length   : coverpoint cov_intf.HOST_tx_length_dm iff(cov_intf.HOST_tx_tuser[0]==1){bins onetwentyeightB={[24'h40:24'h7F]};
                                                                                     bins twofiftysixB={[24'h80:24'hFF]};}


    
        HOST_TX_Host_Address: coverpoint cov_intf.HOST_tx_host_addr_h{ bins addr={[32'h0:32'hFFFFFF]};}
        
        HOST_TX_DM_tag     : coverpoint cov_intf.HOST_tx_tag_dm iff(cov_intf.HOST_tx_tuser[0]==1){bins eightbittag={[10'h0:10'h0FF]};
                                                                                    bins tenbittag={[10'h100:10'h3FF]}; }
        HOST_TX_format_type: coverpoint cov_intf.HOST_tx_fmt_type{bins format_type[]={32,96,112,114}; 
                                          ignore_bins tx_format_type_igno={[0:31],[33:47],[49:95],[97:111],113,[115:255]};}
        //PMCI
        HOST_TX_MCTP_length     : coverpoint cov_intf.HOST_tx_mctp_len{bins min={1};
                                                           
                                                           bins mid={[2:15]};
                                                           bins max={16};}
        HOST_TX_MCTP_msg_code   : coverpoint cov_intf.HOST_tx_mctp_msg_code{bins msg_code={127};}
        HOST_TX_MCTP_vdm_code   : coverpoint cov_intf.HOST_tx_mctp_vdm_code{bins vdm_id={16'h1ab4};}
        HOST_TX_MCTP_multi_pkt_seq: coverpoint cov_intf.HOST_tx_mctp_multi_pkt_seq{bins pkt_seq[]={0,1,2,3};}
       `endif

endgroup


covergroup AXI_TX_COMPL ;
    TX_PU_cmpl_len  : coverpoint cov_intf.tx_cmpl_len_pu{bins len_pu[]={[1:2]};}
    TX_compl_status : coverpoint cov_intf.tx_cmpl_status{bins cmp_stat[]={[STAT_COMPL.first:STAT_COMPL.last]};
                                                         ignore_bins tx_compl_status_igno = {1,2,3};}        // UR not supported
    TX_compl_type   : coverpoint cov_intf.tx_cmpl_type{bins cmp_typ[]={74};
                                                      ignore_bins tx_type_igno={[0:10],[11:42],[43:73],[75:255]};}       //tx compl-only 4A will cover

endgroup

//***************************************************HE_LBK_COVERAGE**********************************************************
covergroup HE_LBK;
`ifdef ENABLE_R1_COVERAGE
         LBK_con_mode:  coverpoint cov_intf.rx_he_lbk_cont_mode{bins conmode[]={[0:1]};}
         LBK_forcdcml:  coverpoint cov_intf.rx_he_lbk_forcdcmpl{bins forcdcmpl[]={[0:1]};}            
         LBK_testmode:  coverpoint cov_intf.rx_he_lbk_test_mode{bins tst_mode[]={[0:3]};}  //000-loop,001=rd,010=wr,011-throughput

         LBK_tput    :  coverpoint cov_intf.rx_he_lbk_tput_intr{bins tput[]={[0:2]};} //0->1rdwr,1-->2rdwr ,2 -->4rdwr
         LBK_reqlen  :  coverpoint cov_intf.rx_he_lbk_req_len{bins req_len[]={[REQ_LEN.first:REQ_LEN.last]}; }

         LBK_con_mode_testmode: cross LBK_con_mode,LBK_testmode{bins b1  = binsof(LBK_con_mode)intersect{0} && binsof(LBK_testmode)intersect{0};
                                                                bins b2  = binsof(LBK_con_mode)intersect{0} && binsof(LBK_testmode)intersect{1};
                                                                bins b3  = binsof(LBK_con_mode)intersect{0} && binsof(LBK_testmode)intersect{2};
                                                                bins b4  = binsof(LBK_con_mode)intersect{0} && binsof(LBK_testmode)intersect{3};
                                                                bins b5  = binsof(LBK_con_mode)intersect{1} && binsof(LBK_testmode)intersect{0};
                                                                bins b6  = binsof(LBK_con_mode)intersect{1} && binsof(LBK_testmode)intersect{1};
                                                                bins b7  = binsof(LBK_con_mode)intersect{1} && binsof(LBK_testmode)intersect{2};
                                                                bins b8  = binsof(LBK_con_mode)intersect{1} && binsof(LBK_testmode)intersect{3};}

         LBK_forcedcml_testmode: cross LBK_forcdcml,LBK_testmode{bins b1  = binsof(LBK_forcdcml)intersect{0} && binsof(LBK_testmode)intersect{0};
                                                                 bins b2  = binsof(LBK_forcdcml)intersect{0} && binsof(LBK_testmode)intersect{1};
                                                                 bins b3  = binsof(LBK_forcdcml)intersect{0} && binsof(LBK_testmode)intersect{2};
                                                                 bins b4  = binsof(LBK_forcdcml)intersect{0} && binsof(LBK_testmode)intersect{3};
                                                                 bins b5  = binsof(LBK_forcdcml)intersect{1} && binsof(LBK_testmode)intersect{0};
                                                                 bins b6  = binsof(LBK_forcdcml)intersect{1} && binsof(LBK_testmode)intersect{1};
                                                                 bins b7  = binsof(LBK_forcdcml)intersect{1} && binsof(LBK_testmode)intersect{2};
                                                                 bins b8  = binsof(LBK_forcdcml)intersect{1} && binsof(LBK_testmode)intersect{3};}
 
         
         LBK_con_mode_forcedcml:  cross LBK_con_mode,LBK_forcdcml{bins fxc = binsof(LBK_con_mode)intersect{1} &&  binsof(LBK_forcdcml)intersect{1}; 
                                                                  ignore_bins lbk_igno_con_mode_forcedcml1 = binsof(LBK_con_mode)intersect{0} &&   binsof(LBK_forcdcml)intersect{0};
                                                                  ignore_bins lbk_igno_con_mode_forcedcml2 = binsof(LBK_con_mode)intersect{0} &&   binsof(LBK_forcdcml)intersect{1};
                                                                  ignore_bins lbk_igno_con_mode_forcedcml3 = binsof(LBK_con_mode)intersect{1} &&   binsof(LBK_forcdcml)intersect{0};}

         LBK_testmod_tput      :  cross LBK_testmode,LBK_tput{bins b1 = binsof(LBK_testmode)intersect{3} &&  binsof(LBK_tput)intersect{0};
                                                              bins b2 = binsof(LBK_testmode)intersect{3} &&  binsof(LBK_tput)intersect{1};
                                                              bins b3 = binsof(LBK_testmode)intersect{3} &&  binsof(LBK_tput)intersect{2};
                                                              ignore_bins lbk_igno_test_mode = binsof(LBK_testmode)intersect{[0:2]};
                                                              ignore_bins lbk_igno_tput= binsof(LBK_tput)intersect{[3:7]};}
  `else
         LBK_con_mode:  coverpoint cov_intf.rxreq_he_lbk_cont_mode{bins conmode[]={[0:1]};}
         LBK_forcdcml:  coverpoint cov_intf.rxreq_he_lbk_forcdcmpl{bins forcdcmpl[]={[0:1]};}            
         LBK_testmode:  coverpoint cov_intf.rxreq_he_lbk_test_mode{bins tst_mode[]={[0:3]};}  //000-loop,001=rd,010=wr,011-throughput

         LBK_tput    :  coverpoint cov_intf.rxreq_he_lbk_tput_intr{bins tput[]={[0:2]};} //0->1rdwr,1-->2rdwr ,2 -->4rdwr
         LBK_reqlen  :  coverpoint cov_intf.rxreq_he_lbk_req_len{bins req_len[]={[REQ_LEN.first:REQ_LEN.last]}; }

         LBK_con_mode_testmode: cross LBK_con_mode,LBK_testmode{bins b1  = binsof(LBK_con_mode)intersect{0} && binsof(LBK_testmode)intersect{0};
                                                                bins b2  = binsof(LBK_con_mode)intersect{0} && binsof(LBK_testmode)intersect{1};
                                                                bins b3  = binsof(LBK_con_mode)intersect{0} && binsof(LBK_testmode)intersect{2};
                                                                bins b4  = binsof(LBK_con_mode)intersect{0} && binsof(LBK_testmode)intersect{3};
                                                                bins b5  = binsof(LBK_con_mode)intersect{1} && binsof(LBK_testmode)intersect{0};
                                                                bins b6  = binsof(LBK_con_mode)intersect{1} && binsof(LBK_testmode)intersect{1};
                                                                bins b7  = binsof(LBK_con_mode)intersect{1} && binsof(LBK_testmode)intersect{2};
                                                                bins b8  = binsof(LBK_con_mode)intersect{1} && binsof(LBK_testmode)intersect{3};}

         LBK_forcedcml_testmode: cross LBK_forcdcml,LBK_testmode{bins b1  = binsof(LBK_forcdcml)intersect{0} && binsof(LBK_testmode)intersect{0};
                                                                 bins b2  = binsof(LBK_forcdcml)intersect{0} && binsof(LBK_testmode)intersect{1};
                                                                 bins b3  = binsof(LBK_forcdcml)intersect{0} && binsof(LBK_testmode)intersect{2};
                                                                 bins b4  = binsof(LBK_forcdcml)intersect{0} && binsof(LBK_testmode)intersect{3};
                                                                 bins b5  = binsof(LBK_forcdcml)intersect{1} && binsof(LBK_testmode)intersect{0};
                                                                 bins b6  = binsof(LBK_forcdcml)intersect{1} && binsof(LBK_testmode)intersect{1};
                                                                 bins b7  = binsof(LBK_forcdcml)intersect{1} && binsof(LBK_testmode)intersect{2};
                                                                 bins b8  = binsof(LBK_forcdcml)intersect{1} && binsof(LBK_testmode)intersect{3};}
 
         
         LBK_con_mode_forcedcml:  cross LBK_con_mode,LBK_forcdcml{bins fxc = binsof(LBK_con_mode)intersect{1} &&  binsof(LBK_forcdcml)intersect{1}; 
                                                                  ignore_bins lbk_igno_con_mode_forcedcml1 = binsof(LBK_con_mode)intersect{0} &&   binsof(LBK_forcdcml)intersect{0};
                                                                  ignore_bins lbk_igno_con_mode_forcedcml2 = binsof(LBK_con_mode)intersect{0} &&   binsof(LBK_forcdcml)intersect{1};
                                                                  ignore_bins lbk_igno_con_mode_forcedcml3 = binsof(LBK_con_mode)intersect{1} &&   binsof(LBK_forcdcml)intersect{0};}

         LBK_testmod_tput      :  cross LBK_testmode,LBK_tput{bins b1 = binsof(LBK_testmode)intersect{3} &&  binsof(LBK_tput)intersect{0};
                                                              bins b2 = binsof(LBK_testmode)intersect{3} &&  binsof(LBK_tput)intersect{1};
                                                              bins b3 = binsof(LBK_testmode)intersect{3} &&  binsof(LBK_tput)intersect{2};
                                                              ignore_bins lbk_igno_test_mode = binsof(LBK_testmode)intersect{[0:2]};
  

                                                            ignore_bins lbk_igno_tput= binsof(LBK_tput)intersect{[3:7]};}

`endif
endgroup

//***************************************************HE_MEM_COVERAGE**********************************************************

covergroup HE_MEM;
`ifdef ENABLE_R1_COVERAGE
         MEM_con_mode:  coverpoint cov_intf.rx_he_mem_cont_mode{bins conmode[]={[0:1]};}
         MEM_forcdcml:  coverpoint cov_intf.rx_he_mem_forcdcmpl{bins forcdcmlmode[]={[0:1]};}
         MEM_testmode:  coverpoint cov_intf.rx_he_mem_test_mode{bins tst_mode[]={[0:3]};}  //000-loop,001=rd,010=wr,011-throughput
         MEM_tput    :  coverpoint cov_intf.rx_he_mem_tput_intr{bins tput[]={[0:2]};} //0->1rdwr,1-->2rdwr ,2 -->4rdwr

         MEM_reqlen  :  coverpoint cov_intf.rx_he_mem_req_len{bins req_len[]={[REQ_LEN.first:REQ_LEN.last]}; }

         MEM_con_mode_testmode: cross MEM_con_mode,MEM_testmode{bins b1  = binsof(MEM_con_mode)intersect{0} && binsof(MEM_testmode)intersect{0};
                                                                bins b2  = binsof(MEM_con_mode)intersect{0} && binsof(MEM_testmode)intersect{1};
                                                                bins b3  = binsof(MEM_con_mode)intersect{0} && binsof(MEM_testmode)intersect{2};
                                                                bins b4  = binsof(MEM_con_mode)intersect{0} && binsof(MEM_testmode)intersect{3};
                                                                bins b5  = binsof(MEM_con_mode)intersect{1} && binsof(MEM_testmode)intersect{0};
                                                                bins b6  = binsof(MEM_con_mode)intersect{1} && binsof(MEM_testmode)intersect{1};
                                                                bins b7  = binsof(MEM_con_mode)intersect{1} && binsof(MEM_testmode)intersect{2};
                                                                bins b8  = binsof(MEM_con_mode)intersect{1} && binsof(MEM_testmode)intersect{3};}

         MEM_forcedcml_testmode: cross MEM_forcdcml,MEM_testmode{bins b1  = binsof(MEM_forcdcml)intersect{0} && binsof(MEM_testmode)intersect{0};
                                                                 bins b2  = binsof(MEM_forcdcml)intersect{0} && binsof(MEM_testmode)intersect{1};
                                                                 bins b3  = binsof(MEM_forcdcml)intersect{0} && binsof(MEM_testmode)intersect{2};
                                                                 bins b4  = binsof(MEM_forcdcml)intersect{0} && binsof(MEM_testmode)intersect{3};
                                                                 bins b5  = binsof(MEM_forcdcml)intersect{1} && binsof(MEM_testmode)intersect{0};
                                                                 bins b6  = binsof(MEM_forcdcml)intersect{1} && binsof(MEM_testmode)intersect{1};
                                                                 bins b7  = binsof(MEM_forcdcml)intersect{1} && binsof(MEM_testmode)intersect{2};
                                                                 bins b8  = binsof(MEM_forcdcml)intersect{1} && binsof(MEM_testmode)intersect{3};}

         
         MEM_con_mode_forcedcml:  cross MEM_con_mode,MEM_forcdcml{bins fxc = binsof(MEM_con_mode)intersect{1} &&   binsof(MEM_forcdcml)intersect{1};
                                                                  ignore_bins mem_igno_con_mode_forcedcm1l = binsof(MEM_con_mode)intersect{0} &&   binsof(MEM_forcdcml)intersect{0};
                                                                  ignore_bins mem_igno_con_mode_forcedcml2 = binsof(MEM_con_mode)intersect{0} &&   binsof(MEM_forcdcml)intersect{1};
                                                                  ignore_bins mem_igno_con_mode_forcedcml3 = binsof(MEM_con_mode)intersect{1} &&   binsof(MEM_forcdcml)intersect{0};} 

         MEM_testmod_tput      :  cross MEM_testmode,MEM_tput{bins b1 = binsof(MEM_testmode)intersect{3} &&  binsof(MEM_tput)intersect{0};
                                                              bins b2 = binsof(MEM_testmode)intersect{3} &&  binsof(MEM_tput)intersect{1};
                                                              bins b3 = binsof(MEM_testmode)intersect{3} &&  binsof(MEM_tput)intersect{2};
                                                              ignore_bins mem_igno_test_mode = binsof(MEM_testmode)intersect{[0:2]};
                                                              ignore_bins mem_igno_tput      = binsof(MEM_tput)intersect{[3:7]};}

  `else
         MEM_con_mode:  coverpoint cov_intf.rxreq_he_mem_cont_mode{bins conmode[]={[0:1]};}
         MEM_forcdcml:  coverpoint cov_intf.rxreq_he_mem_forcdcmpl{bins forcdcmlmode[]={[0:1]};}
         MEM_testmode:  coverpoint cov_intf.rxreq_he_mem_test_mode{bins tst_mode[]={[0:3]};}  //000-loop,001=rd,010=wr,011-throughput
         MEM_tput    :  coverpoint cov_intf.rxreq_he_mem_tput_intr{bins tput[]={[0:2]};} //0->1rdwr,1-->2rdwr ,2 -->4rdwr

         MEM_reqlen  :  coverpoint cov_intf.rxreq_he_mem_req_len{bins req_len[]={[REQ_LEN.first:REQ_LEN.last]}; }

         MEM_con_mode_testmode: cross MEM_con_mode,MEM_testmode{bins b1  = binsof(MEM_con_mode)intersect{0} && binsof(MEM_testmode)intersect{0};
                                                                bins b2  = binsof(MEM_con_mode)intersect{0} && binsof(MEM_testmode)intersect{1};
                                                                bins b3  = binsof(MEM_con_mode)intersect{0} && binsof(MEM_testmode)intersect{2};
                                                                bins b4  = binsof(MEM_con_mode)intersect{0} && binsof(MEM_testmode)intersect{3};
                                                                bins b5  = binsof(MEM_con_mode)intersect{1} && binsof(MEM_testmode)intersect{0};
                                                                bins b6  = binsof(MEM_con_mode)intersect{1} && binsof(MEM_testmode)intersect{1};
                                                                bins b7  = binsof(MEM_con_mode)intersect{1} && binsof(MEM_testmode)intersect{2};
                                                                bins b8  = binsof(MEM_con_mode)intersect{1} && binsof(MEM_testmode)intersect{3};}

         MEM_forcedcml_testmode: cross MEM_forcdcml,MEM_testmode{bins b1  = binsof(MEM_forcdcml)intersect{0} && binsof(MEM_testmode)intersect{0};
                                                                 bins b2  = binsof(MEM_forcdcml)intersect{0} && binsof(MEM_testmode)intersect{1};
                                                                 bins b3  = binsof(MEM_forcdcml)intersect{0} && binsof(MEM_testmode)intersect{2};
                                                                 bins b4  = binsof(MEM_forcdcml)intersect{0} && binsof(MEM_testmode)intersect{3};
                                                                 bins b5  = binsof(MEM_forcdcml)intersect{1} && binsof(MEM_testmode)intersect{0};
                                                                 bins b6  = binsof(MEM_forcdcml)intersect{1} && binsof(MEM_testmode)intersect{1};
                                                                 bins b7  = binsof(MEM_forcdcml)intersect{1} && binsof(MEM_testmode)intersect{2};
                                                                 bins b8  = binsof(MEM_forcdcml)intersect{1} && binsof(MEM_testmode)intersect{3};}

         
         MEM_con_mode_forcedcml:  cross MEM_con_mode,MEM_forcdcml{bins fxc = binsof(MEM_con_mode)intersect{1} &&   binsof(MEM_forcdcml)intersect{1};
                                                                  ignore_bins mem_igno_con_mode_forcedcm1l = binsof(MEM_con_mode)intersect{0} &&   binsof(MEM_forcdcml)intersect{0};
                                                                  ignore_bins mem_igno_con_mode_forcedcml2 = binsof(MEM_con_mode)intersect{0} &&   binsof(MEM_forcdcml)intersect{1};
                                                                  ignore_bins mem_igno_con_mode_forcedcml3 = binsof(MEM_con_mode)intersect{1} &&   binsof(MEM_forcdcml)intersect{0};} 

         MEM_testmod_tput      :  cross MEM_testmode,MEM_tput{bins b1 = binsof(MEM_testmode)intersect{3} &&  binsof(MEM_tput)intersect{0};
                                                              bins b2 = binsof(MEM_testmode)intersect{3} &&  binsof(MEM_tput)intersect{1};
                                                              bins b3 = binsof(MEM_testmode)intersect{3} &&  binsof(MEM_tput)intersect{2};
                                                              ignore_bins mem_igno_test_mode = binsof(MEM_testmode)intersect{[0:2]};
                                                              ignore_bins mem_igno_tput      = binsof(MEM_tput)intersect{[3:7]};}

 `endif
endgroup


//***************************************************HE_HSSI_COVERAGE**********************************************************

covergroup HE_HSSI;
         HSSI_traffic_cntrl_rd    : coverpoint cov_intf.rx_he_hssi_rd_cmd{bins rdcmd[]={[0:1]}; } 
         HSSI_traffic_cntrl_wr    : coverpoint cov_intf.rx_he_hssi_wr_cmd{bins wrcmd[]={[0:1]}; }
         HSSI_traffic_ctrl_ch_sel : coverpoint cov_intf.rx_he_hssi_ch_sel{bins ch_sel={[4'h0:4'hF]};} //16 channels

          HSSI_pkt_lentype  : coverpoint cov_intf.rx_he_hssi_rnd_len{bins rnd_len[]={[0:1]};}  
          HSSI_data_pattern : coverpoint cov_intf.rx_he_hssi_rnd_pld{bins rnd_pld[]={[0:1]};}
          HSSI_tg_numpkt    : coverpoint cov_intf.rx_he_hssi_tg_num_pkt {bins num_pkt={[0:31],[32:63],[64:127],[128:255],[256:511],[512:100000000]}; }  //4gb
          HSSI_rnd_seed0    : coverpoint cov_intf.rx_he_hssi_seed0{bins seed0 ={[0:31]};}
          HSSI_rnd_seed1    : coverpoint cov_intf.rx_he_hssi_seed1{bins seed1 ={[0:31]};}
          HSSI_rnd_seed2    : coverpoint cov_intf.rx_he_hssi_seed2{bins seed2 ={[0:27]};}  
          HSSI_pkt_len      : coverpoint cov_intf.rx_he_hssi_pkt_len {bins pkt_len ={[13'h0:13'h1ff],[13'h200:13'h5dc]};}     //8 kb 
          `ifdef ENABLE_R1_COVERAGE
          HSSI_len_err     : coverpoint cov_intf.rx_he_hssi_len_err{bins len_err[]={[0:1]};}
          HSSI_oversiz_err : coverpoint cov_intf.rx_he_hssi_oversiz_err{bins oversiz_err[]={[0:1]};}
          HSSI_undsiz_err  : coverpoint cov_intf.rx_he_hssi_undsiz_err{bins undsiz_err[]={[0:1]};}
          HSSI_mac_crc_err : coverpoint cov_intf.rx_he_hssi_mac_crc_err{bins mac_crc_err[]={[0:1]};}
          HSSI_phy_err     : coverpoint cov_intf.rx_he_hssi_phy_err{bins phy_err[]={[0:1]};}
          HSSI_err_valid   : coverpoint cov_intf.rx_he_hssi_err_valid{bins err_valid[]={[0:1]};}


          HSSI_lbk_enb:  coverpoint cov_intf.rx_he_hssi_lbk_en {bins lbk_enb= {[0:1]};}
          HSSI_lbk_fifo_status_almost_full : coverpoint cov_intf.rx_he_hssi_lbk_fifo_almost_full{bins lbk_st_full={[0:1]};}
          HSSI_lbk_fifo_status_almost_empty: coverpoint cov_intf.rx_he_hssi_lbk_fifo_almost_empty{bins lbk_st_empty={[0:1]};}

          HSSI_rnd_len_pld   : cross HSSI_pkt_lentype,HSSI_data_pattern{ bins b1= binsof(HSSI_pkt_lentype)intersect{0} && binsof(HSSI_data_pattern)intersect{0};
                                                                         bins b2= binsof(HSSI_pkt_lentype)intersect{0} && binsof(HSSI_data_pattern)intersect{1};
                                                                         bins b3= binsof(HSSI_pkt_lentype)intersect{1} && binsof(HSSI_data_pattern)intersect{0};
                                                                         bins b4= binsof(HSSI_pkt_lentype)intersect{1} && binsof(HSSI_data_pattern)intersect{1}; }
                                                                    
         `else

          HSSI_lbk_enb:  coverpoint cov_intf.rx_he_hssi_lbk_en {bins lbk_enb= {[0:1]};}
          HSSI_lbk_fifo_status_almost_full : coverpoint cov_intf.rx_he_hssi_lbk_fifo_almost_full{bins lbk_st_full={[0:1]};}
          HSSI_lbk_fifo_status_almost_empty: coverpoint cov_intf.rx_he_hssi_lbk_fifo_almost_empty{bins lbk_st_empty={[0:1]};}

        `endif                                                                      

endgroup

//**************************************************EMIF_COVERAGE**********************************************************
`ifndef ENABLE_R1_COVERAGE //For AC and F2000x Coverage
covergroup EMIF_CHANNEL;
    EMIF_capability  : coverpoint cov_intf.rx_emif_cap{bins onechannel={0};
                                                       ignore_bins tx_format_type_igno={1,2,3};}  //not supported       
                                                       
endgroup
`endif
//**************************************************BOTH_TX_RX_COVERGROUP_END*******************************************

  function new(string name ="coverage_r1",uvm_component parent=null);
    super.new(name,parent);
    AXI_ST_TX=new();
    AXI_TX_COMPL=new();
    AXI_ST_RX=new();
    AXI_RX_COMPL=new();
    HE_LBK=new();
    HE_MEM=new();
    HE_HSSI=new();
`ifdef ENABLE_AC_COVERAGE
    EMIF_CHANNEL=new();
  `endif
`ifdef ENABLE_SOC_HOST_COVERAGE
    EMIF_CHANNEL=new();
    HOST_AXI_ST_TX=new();
    SOC_AXI_ST_RX=new();
    HOST_AXI_ST_RX=new();
`endif
 endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!(uvm_config_db#(virtual coverage_intf)::get(this,"*","cov_intf",cov_intf)))begin
       `uvm_fatal("CLSS",("virtual interface must be set for:"))
    end
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
    sample_calling; 
  endtask


task sample_calling;
    `ifdef ENABLE_AC_COVERAGE 

   fork 
//RX_sample:    
     forever @(posedge cov_intf.rxreq_clk)begin
       if((cov_intf.flag_rxreq==1)||(cov_intf.flag_64_rxreq==1))begin
       if(((cov_intf.rxreq_req_fmt==2)&&(cov_intf.rxreq_req_type==0))||((cov_intf.rxreq_req_fmt==3)&&(cov_intf.rxreq_req_type==0))||((cov_intf.rxreq_req_fmt==1)&&(cov_intf.rxreq_req_type==0))||((cov_intf.rxreq_req_fmt==0)&&(cov_intf.rxreq_req_type==0))||((cov_intf.rxreq_req_fmt==3)&&(cov_intf.rxreq_req_type==16))||((cov_intf.rxreq_req_fmt==3)&&(cov_intf.rxreq_req_type==18))||((cov_intf.rxreq_req_fmt==3)&&(cov_intf.rxreq_req_type==19)))begin 
    `ifdef ENABLE_COV_MSG   
     `uvm_info("CLAS_COV",$sformatf("AC_RX_CHECK_sampling"), UVM_LOW)
 `endif
            AXI_ST_RX.sample();

        if((cov_intf.rxreq_host_addr_h==cov_intf.he_lb_addr+32'h138 ) || (cov_intf.rxreq_host_addr_h==cov_intf.he_lb_addr+32'h140 )||(cov_intf.rxreq_host_addr_64==cov_intf.he_lb_addr+64'h138 )||(cov_intf.rxreq_host_addr_64==cov_intf.he_lb_addr+64'h140) )begin   //HE_LBK
            `ifdef ENABLE_COV_MSG
               `uvm_info("CLAS_COV",$sformatf("RX:::AC_HE_LBK_sampling"), UVM_LOW)
           `endif
                HE_LBK.sample();
          
        end else if((cov_intf.rxreq_host_addr_h==cov_intf.he_mem_addr+32'h138 ) || (cov_intf.rxreq_host_addr_h==cov_intf.he_mem_addr+32'h140 )||(cov_intf.rxreq_host_addr_64==cov_intf.he_mem_addr+64'h138 )||(cov_intf.rxreq_host_addr_64==cov_intf.he_mem_addr+64'h140) )begin 
                HE_MEM.sample();
            `ifdef ENABLE_COV_MSG
               `uvm_info("CLAS_COV",$sformatf("RX:::AC_HE_mem_sampling"), UVM_LOW)
           `endif
           end  else if((cov_intf.rxreq_host_addr_h==cov_intf.he_hssi_addr+32'h60030) ||(cov_intf.rxreq_host_addr_h==cov_intf.he_hssi_addr+32'h60034) ||(cov_intf.rxreq_host_addr_h==cov_intf.he_hssi_addr+32'h60038)||(cov_intf.rxreq_host_addr_h==cov_intf.he_hssi_addr+32'h6003c)||(cov_intf.rxreq_host_addr_h==cov_intf.he_hssi_addr+32'h60040)||(cov_intf.rxreq_host_addr_64==cov_intf.he_hssi_addr+64'h60030) ||(cov_intf.rxreq_host_addr_64==cov_intf.he_hssi_addr+64'h60034) ||(cov_intf.rxreq_host_addr_64==cov_intf.he_hssi_addr+64'h60038) ||(cov_intf.rxreq_host_addr_h==cov_intf.he_hssi_addr+64'h6003c) || (cov_intf.rxreq_host_addr_64==cov_intf.he_hssi_addr+64'h60040))begin //he_hssi
                 HE_HSSI.sample();
            `ifdef ENABLE_COV_MSG
               `uvm_info("CLAS_COV",$sformatf("RX:::AC_HE_HSSI_sampling"), UVM_LOW)
           `endif
            end else if((cov_intf.rxreq_host_addr_h==cov_intf.pf0_bar0_addr+32'h15000)||(cov_intf.rxreq_host_addr_h==cov_intf.pf0_bar0_addr+32'h15010)||(cov_intf.rxreq_host_addr_64==cov_intf.pf0_bar0_addr+64'h15010))begin
                EMIF_CHANNEL.sample();
                 `ifdef ENABLE_COV_MSG
               `uvm_info("CLAS_COV",$sformatf("RX:::AC_EMIF_sampling"), UVM_LOW)
           `endif
        end

        end else if((cov_intf.rxreq_req_fmt==2)&&(cov_intf.rxreq_req_type==10))begin  //compl
            AXI_RX_COMPL.sample();
        `ifdef ENABLE_COV_MSG
           `uvm_info("CLAS_COV",$sformatf("AC_RX_CHECK_COMPL_Inside_sample_task"), UVM_LOW)
       `endif
         end
     end
  end


  
  forever @(posedge cov_intf.rx_clk)begin
	  if((cov_intf.flag_rx==1)||(cov_intf.flag_64_rx==1))begin
	    if((cov_intf.rx_req_fmt==2)&&(cov_intf.rx_req_type==10))begin  //compl
            AXI_RX_COMPL.sample();
        `ifdef ENABLE_COV_MSG
           `uvm_info("CLAS_COV",$sformatf("AC_RX_CHECK_COMPL_Inside_sample_task"), UVM_LOW)
       `endif
           end
        end  
     end


       //TX_sample:    
     forever @(posedge cov_intf.tx_clk)begin
       if(cov_intf.flag_tx==1)begin
         if(((cov_intf.tx_req_fmt==1)&&(cov_intf.tx_req_type==16))||((cov_intf.tx_req_fmt==2)&&(cov_intf.tx_req_type==0))||((cov_intf.tx_req_fmt==2)&&(cov_intf.tx_req_type==10)) ||((cov_intf.tx_req_fmt==3)&&(cov_intf.tx_req_type==0))||((cov_intf.tx_req_fmt==1)&&(cov_intf.tx_req_type==0))||((cov_intf.tx_req_fmt==0)&&(cov_intf.tx_req_type==0))|| ((cov_intf.tx_req_fmt==3)&&(cov_intf.tx_req_type==16))||((cov_intf.tx_req_fmt==3)&&(cov_intf.tx_req_type==18)))begin 
          `ifdef ENABLE_COV_MSG
             `uvm_info("CLAS_COV",$sformatf("TX_CHECK_sampling"), UVM_LOW)
         `endif
            AXI_ST_TX.sample();
         end 
         if((cov_intf.tx_req_fmt==2)&&(cov_intf.tx_req_type==10))begin  //compl
            AXI_TX_COMPL.sample();
        `ifdef ENABLE_COV_MSG
           `uvm_info("CLAS_COV",$sformatf("TX_CHECK_COMPL_sampling"), UVM_LOW)
       `endif
          end
       end
     end
   join
   `endif


   `ifdef ENABLE_R1_COVERAGE

//R1
//RX_sample:  
fork
     forever @(posedge cov_intf.rx_clk)begin
       if(cov_intf.flag_rx==1)begin
         if(((cov_intf.rx_req_fmt==2)&&(cov_intf.rx_req_type==0))||((cov_intf.rx_req_fmt==3)&&(cov_intf.rx_req_type==0))||((cov_intf.rx_req_fmt==1)&&(cov_intf.rx_req_type==0))||((cov_intf.rx_req_fmt==0)&&(cov_intf.rx_req_type==0))||((cov_intf.rx_req_fmt==3)&&(cov_intf.rx_req_type==16))||((cov_intf.rx_req_fmt==3)&&(cov_intf.rx_req_type==18))||((cov_intf.rx_req_fmt==3)&&(cov_intf.rx_req_type==19)))begin 
               `ifdef ENABLE_COV_MSG
                  `uvm_info("CLAS_COV",$sformatf("R1_RX_CHECK_sampling"), UVM_LOW)
              `endif
            AXI_ST_RX.sample();
               `ifdef ENABLE_COV_MSG
                  `uvm_info("CLAS_COV",$sformatf("Address=%0h",cov_intf.rx_host_addr_h), UVM_LOW)
              `endif

         if((cov_intf.rx_host_addr_h==cov_intf.he_lb_addr+32'h140) || (cov_intf.rx_host_addr_h==cov_intf.he_lb_addr+32'h138 ))begin   //HE_LBK //if((a==10)||(a==12))

            `ifdef ENABLE_COV_MSG
               `uvm_info("CLAS_COV",$sformatf("RX:::R1_HE_LBK_sampling"), UVM_LOW)
           `endif
                HE_LBK.sample();
          end else if((cov_intf.rx_host_addr_h==cov_intf.he_mem_addr+32'h140) || (cov_intf.rx_host_addr_h==cov_intf.he_mem_addr+32'h138 ))begin   //HE_MEM
                HE_MEM.sample();
            `ifdef ENABLE_COV_MSG
               `uvm_info("CLAS_COV",$sformatf("RX:::R1_HE_mem_sampling"), UVM_LOW)
           `endif
          end else if((cov_intf.rx_host_addr_h==cov_intf.he_hssi_addr+32'h30) ||(cov_intf.rx_host_addr_h==cov_intf.he_hssi_addr+32'h38)||(cov_intf.rx_host_addr_h==cov_intf.he_hssi_addr+32'h40)||(cov_intf.rx_host_addr_h==cov_intf.he_hssi_addr+32'h48)||(cov_intf.rx_host_addr_h==cov_intf.he_hssi_addr+32'h3c))begin   //HE_HSSI
                 HE_HSSI.sample();
            `ifdef ENABLE_COV_MSG
               `uvm_info("CLAS_COV",$sformatf("RX:::R1_HE_HSSI_sampling"), UVM_LOW)
           `endif
            end

          end else if((cov_intf.rx_req_fmt==2)&&(cov_intf.rx_req_type==10))begin  //compl
            AXI_RX_COMPL.sample();
        `ifdef ENABLE_COV_MSG
           `uvm_info("CLAS_COV",$sformatf("R1_RX_CHECK_COMPL_Inside_sample_task"), UVM_LOW)
       `endif
       end
     end
 end
 

//TX_sample:    
     forever @(posedge cov_intf.tx_clk)begin
       if(cov_intf.flag_tx==1)begin
 if(((cov_intf.tx_req_fmt==1)&&(cov_intf.tx_req_type==16))||((cov_intf.tx_req_fmt==2)&&(cov_intf.tx_req_type==0))||((cov_intf.tx_req_fmt==2)&&(cov_intf.tx_req_type==10)) ||((cov_intf.tx_req_fmt==3)&&(cov_intf.tx_req_type==0))||((cov_intf.tx_req_fmt==1)&&(cov_intf.tx_req_type==0))||((cov_intf.tx_req_fmt==0)&&(cov_intf.tx_req_type==0))|| ((cov_intf.tx_req_fmt==3)&&(cov_intf.tx_req_type==16))||((cov_intf.tx_req_fmt==3)&&(cov_intf.tx_req_type==18)))begin 
            `ifdef ENABLE_COV_MSG
             `uvm_info("CLAS_COV",$sformatf("TX_CHECK_sampling"), UVM_LOW)
         `endif
            AXI_ST_TX.sample();
         end 
         if((cov_intf.tx_req_fmt==2)&&(cov_intf.tx_req_type==10))begin  //compl
            AXI_TX_COMPL.sample();
          `ifdef ENABLE_COV_MSG
           `uvm_info("CLAS_COV",$sformatf("TX_CHECK_COMPL_sampling"), UVM_LOW)
       `endif
         end
      end
     end
   join
`endif


//**********************F2000x SAMPLING**********************************************
`ifdef ENABLE_SOC_HOST_COVERAGE        

   fork 
//RX_sample:    
     forever @(posedge cov_intf.rxreq_clk)begin
       if((cov_intf.flag_rxreq==1)||(cov_intf.flag_64_rxreq==1))begin
       if(((cov_intf.rxreq_req_fmt==2)&&(cov_intf.rxreq_req_type==0))||((cov_intf.rxreq_req_fmt==3)&&(cov_intf.rxreq_req_type==0))||((cov_intf.rxreq_req_fmt==1)&&(cov_intf.rxreq_req_type==0))||((cov_intf.rxreq_req_fmt==0)&&(cov_intf.rxreq_req_type==0))||((cov_intf.rxreq_req_fmt==3)&&(cov_intf.rxreq_req_type==16))||((cov_intf.rxreq_req_fmt==3)&&(cov_intf.rxreq_req_type==18))||((cov_intf.rxreq_req_fmt==3)&&(cov_intf.rxreq_req_type==19)))begin 
    `ifdef ENABLE_COV_MSG   
     `uvm_info("CLAS_COV",$sformatf("_RX_CHECK_sampling"), UVM_LOW)
 `endif
            SOC_AXI_ST_RX.sample();
          
         if((cov_intf.rxreq_host_addr_h==cov_intf.he_mem_addr+32'h138 ) || (cov_intf.rxreq_host_addr_h==cov_intf.he_mem_addr+32'h140 )||(cov_intf.rxreq_host_addr_64==cov_intf.he_mem_addr+64'h138 )||(cov_intf.rxreq_host_addr_64==cov_intf.he_mem_addr+64'h140) )begin 
                HE_MEM.sample();
            `ifdef ENABLE_COV_MSG
               `uvm_info("CLAS_COV",$sformatf("RX:::AC_HE_mem_sampling"), UVM_LOW)
           `endif
           end  else if((cov_intf.rxreq_host_addr_h==cov_intf.he_hssi_addr+32'h60030) ||(cov_intf.rxreq_host_addr_h==cov_intf.he_hssi_addr+32'h60034) ||(cov_intf.rxreq_host_addr_h==cov_intf.he_hssi_addr+32'h60038)||(cov_intf.rx_host_addr_h==cov_intf.he_hssi_addr+32'h6003c)||(cov_intf.rxreq_host_addr_h==cov_intf.he_hssi_addr+32'h60040)||(cov_intf.rxreq_host_addr_64==cov_intf.he_hssi_addr+64'h60030) ||(cov_intf.rxreq_host_addr_64==cov_intf.he_hssi_addr+64'h60034) ||(cov_intf.rxreq_host_addr_64==cov_intf.he_hssi_addr+64'h60038) ||(cov_intf.rxreq_host_addr_h==cov_intf.he_hssi_addr+64'h6003c) || (cov_intf.rxreq_host_addr_64==cov_intf.he_hssi_addr+64'h60040))begin //he_hssi
                 HE_HSSI.sample();
            `ifdef ENABLE_COV_MSG
               `uvm_info("CLAS_COV",$sformatf("RX:::AC_HE_HSSI_sampling"), UVM_LOW)
           `endif
            end else if((cov_intf.rxreq_host_addr_h==cov_intf.pf0_bar0_addr+32'h15000)||(cov_intf.rxreq_host_addr_h==cov_intf.pf0_bar0_addr+32'h15010)||(cov_intf.rxreq_host_addr_64==cov_intf.pf0_bar0_addr+64'h15010))begin
                EMIF_CHANNEL.sample();
                 `ifdef ENABLE_COV_MSG
               `uvm_info("CLAS_COV",$sformatf("RX:::AC_EMIF_sampling"), UVM_LOW)
           `endif
        end 

        end else if((cov_intf.rxreq_req_fmt==2)&&(cov_intf.rxreq_req_type==10))begin  //compl
            AXI_RX_COMPL.sample();
        `ifdef ENABLE_COV_MSG
           `uvm_info("CLAS_COV",$sformatf("SOC_RX_CHECK_COMPL_Inside_sample_task"), UVM_LOW)
       `endif
         end
     end
  end
   forever @(posedge cov_intf.rx_clk)begin
	  if((cov_intf.flag_rx==1)||(cov_intf.flag_64_rx==1))begin
	    if((cov_intf.rx_req_fmt==2)&&(cov_intf.rx_req_type==10))begin  //compl
            AXI_RX_COMPL.sample();
        `ifdef ENABLE_COV_MSG
           `uvm_info("CLAS_COV",$sformatf("SOC_RX_CHECK_COMPL_Inside_sample_task"), UVM_LOW)
       `endif
           end
        end  
     end
 
//HOST RX_sample:    
     forever @(posedge cov_intf.HOST_rxreq_clk)begin
       if((cov_intf.HOST_flag_rxreq==1)||(cov_intf.HOST_flag_64_rxreq==1))begin
       if(((cov_intf.HOST_rxreq_req_fmt==2)&&(cov_intf.HOST_rxreq_req_type==0))||((cov_intf.HOST_rxreq_req_fmt==3)&&(cov_intf.HOST_rxreq_req_type==0))||((cov_intf.HOST_rxreq_req_fmt==1)&&(cov_intf.HOST_rxreq_req_type==0))||((cov_intf.HOST_rxreq_req_fmt==0)&&(cov_intf.HOST_rxreq_req_type==0))||((cov_intf.HOST_rxreq_req_fmt==3)&&(cov_intf.HOST_rxreq_req_type==16))||((cov_intf.HOST_rxreq_req_fmt==3)&&(cov_intf.HOST_rxreq_req_type==18))||((cov_intf.HOST_rxreq_req_fmt==3)&&(cov_intf.HOST_rxreq_req_type==19)))begin 
    `ifdef ENABLE_COV_MSG   
     `uvm_info("CLAS_COV",$sformatf("HOST RX_CHECK_sampling"), UVM_LOW)
 `endif
            HOST_AXI_ST_RX.sample();

        if((cov_intf.HOST_rxreq_host_addr_h==cov_intf.he_lb_addr+32'h138 ) || (cov_intf.HOST_rxreq_host_addr_h==cov_intf.he_lb_addr+32'h140 )||(cov_intf.HOST_rxreq_host_addr_64==cov_intf.he_lb_addr+64'h138 )||(cov_intf.HOST_rxreq_host_addr_64==cov_intf.he_lb_addr+64'h140) )begin   //HE_LBK
            `ifdef ENABLE_COV_MSG
               `uvm_info("CLAS_COV",$sformatf("RX:::HOST_HE_LBK_sampling"), UVM_LOW)
           `endif
                HE_LBK.sample();
          
        end
    end else if((cov_intf.HOST_rxreq_req_fmt==2)&&(cov_intf.HOST_rxreq_req_type==10))begin  //compl
            AXI_RX_COMPL.sample();
        `ifdef ENABLE_COV_MSG
           `uvm_info("CLAS_COV",$sformatf("HOST_RX_CHECK_COMPL_Inside_sample_task"), UVM_LOW)
       `endif
       end
     end
  end
  forever @(posedge cov_intf.rx_clk)begin
	  if((cov_intf.flag_rx==1)||(cov_intf.flag_64_rx==1))begin
	    if((cov_intf.rx_req_fmt==2)&&(cov_intf.rx_req_type==10))begin  //compl
            AXI_RX_COMPL.sample();
        `ifdef ENABLE_COV_MSG
           `uvm_info("CLAS_COV",$sformatf("HOST_RX_CHECK_COMPL_Inside_sample_task"), UVM_LOW)
       `endif
           end
        end  
     end

       //TX_sample:    
     forever @(posedge cov_intf.tx_clk)begin
       if(cov_intf.flag_tx==1)begin
         if(((cov_intf.tx_req_fmt==1)&&(cov_intf.tx_req_type==16))||((cov_intf.tx_req_fmt==2)&&(cov_intf.tx_req_type==0))||((cov_intf.tx_req_fmt==2)&&(cov_intf.tx_req_type==10)) ||((cov_intf.tx_req_fmt==3)&&(cov_intf.tx_req_type==0))||((cov_intf.tx_req_fmt==1)&&(cov_intf.tx_req_type==0))||((cov_intf.tx_req_fmt==0)&&(cov_intf.tx_req_type==0))|| ((cov_intf.tx_req_fmt==3)&&(cov_intf.tx_req_type==16))||((cov_intf.tx_req_fmt==3)&&(cov_intf.tx_req_type==18)))begin 
          `ifdef ENABLE_COV_MSG
             `uvm_info("CLAS_COV",$sformatf("TX_CHECK_sampling"), UVM_LOW)
         `endif
            AXI_ST_TX.sample();
         end 
         if((cov_intf.tx_req_fmt==2)&&(cov_intf.tx_req_type==10))begin  //compl
            AXI_TX_COMPL.sample();
        `ifdef ENABLE_COV_MSG
           `uvm_info("CLAS_COV",$sformatf("TX_CHECK_COMPL_sampling"), UVM_LOW)
       `endif
          end
       end
     end
     forever @(posedge cov_intf.HOST_tx_clk)begin
       if(cov_intf.HOST_flag_tx==1)begin
         if(((cov_intf.HOST_tx_req_fmt==1)&&(cov_intf.HOST_tx_req_type==16))||((cov_intf.HOST_tx_req_fmt==2)&&(cov_intf.HOST_tx_req_type==0))||((cov_intf.HOST_tx_req_fmt==2)&&(cov_intf.HOST_tx_req_type==10)) ||((cov_intf.HOST_tx_req_fmt==3)&&(cov_intf.HOST_tx_req_type==0))||((cov_intf.HOST_tx_req_fmt==1)&&(cov_intf.HOST_tx_req_type==0))||((cov_intf.HOST_tx_req_fmt==0)&&(cov_intf.HOST_tx_req_type==0))|| ((cov_intf.HOST_tx_req_fmt==3)&&(cov_intf.HOST_tx_req_type==16))||((cov_intf.HOST_tx_req_fmt==3)&&(cov_intf.HOST_tx_req_type==18)))begin 
          `ifdef ENABLE_COV_MSG
             `uvm_info("CLAS_COV",$sformatf("HOST TX_CHECK_sampling"), UVM_LOW)
         `endif
            HOST_AXI_ST_TX.sample();
         end 
         if((cov_intf.HOST_tx_req_fmt==2)&&(cov_intf.HOST_tx_req_type==10))begin  //compl
            AXI_TX_COMPL.sample();
        `ifdef ENABLE_COV_MSG
           `uvm_info("CLAS_COV",$sformatf("HOST TX_CHECK_COMPL_sampling"), UVM_LOW)
       `endif
          end

       end
     end
     
   join
   `endif

endtask


endclass

`endif




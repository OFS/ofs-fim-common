// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

interface coverage_intf ();
//*****************************************VARIABLE_DECLARATION*****************************
//RX 
   logic         rx_tvalid;
   logic         rx_tlast;
   logic[9:0]    rx_tuser;
   logic[9:0]    rx_tuser_vendor;
   logic[511:0]  rx_tdata;
   logic[63:0]   rx_tkeep;
   logic         rx_tready;
   logic         rx_clk;
//RXREQ 
   logic         rxreq_tvalid;
   logic         rxreq_tlast;
   logic[9:0]    rxreq_tuser;
   logic[9:0]    rxreq_tuser_vendor;
   logic[511:0]  rxreq_tdata;
   logic[63:0]   rxreq_tkeep;
   logic         rxreq_tready;
   logic         rxreq_clk;
   //HOST RXREQ 
   logic         HOST_rxreq_tvalid;
   logic         HOST_rxreq_tlast;
   logic[9:0]    HOST_rxreq_tuser;
   logic[9:0]    HOST_rxreq_tuser_vendor;
   logic[511:0]  HOST_rxreq_tdata;
   logic[63:0]   HOST_rxreq_tkeep;
   logic         HOST_rxreq_tready;
   logic         HOST_rxreq_clk;

//TX
   logic         tx_tvalid;
   logic         tx_tlast;
   logic[9:0]    tx_tuser;
   logic[9:0]    tx_tuser_vendor;
   logic[511:0]  tx_tdata;
   logic[63:0]   tx_tkeep;
   logic         tx_tready;
   logic         tx_clk;

   //TX
   logic         HOST_tx_tvalid;
   logic         HOST_tx_tlast;
   logic[9:0]    HOST_tx_tuser;
   logic[9:0]    HOST_tx_tuser_vendor;
   logic[511:0]  HOST_tx_tdata;
   logic[63:0]   HOST_tx_tkeep;
   logic         HOST_tx_tready;
   logic         HOST_tx_clk;


  logic     traffic_ctrl_ack;
  logic     clk_he_hssi;

  bit       mx2ho_valid;
  bit[2:0]  mx2ho_pfnum;
  bit[10:0] mx2ho_vfnum;
  bit       mx2ho_vfactive;
  bit[7:0]  mx2ho_fmttype;

bit[1:0]  traffic_ctrl_cmd;
bit[31:0] traffic_ctrl_writedata;
bit[31:0] traffic_ctrl_readdata;
bit[16:0] traffic_ctrl_addr;

bit[9:0]   tx_length_1,HOST_tx_length_1,rx_length_1,rxreq_length_1,HOST_rxreq_length_1; 
bit[2:0]   tx_req_fmt,HOST_tx_req_fmt,rx_req_fmt,rxreq_req_fmt,HOST_rxreq_req_fmt;
bit[5:0]   tx_tag,HOST_tx_tag,rx_tag,rxreq_tag,HOST_rxreq_tag;
bit[4:0]   tx_req_type,HOST_tx_req_type,rx_req_type,rxreq_req_type,HOST_rxreq_req_type;
bit[1:0]   tx_length_l,HOST_tx_length_l,rx_length_l,rxreq_length_l,HOST_rxreq_length_l; 
bit[11:0]  tx_length_h,HOST_tx_length_h,rx_length_h,rxreq_length_h,HOST_rxreq_length_h; 
bit[1:0]   tx_host_addr_1,HOST_tx_host_addr_1,rx_host_addr_1,rxreq_host_addr_1,HOST_rxreq_host_addr_1;
bit[31:0]  tx_host_addr_h,HOST_tx_host_addr_h,rx_host_addr_h,rxreq_host_addr_h,HOST_rxreq_host_addr_h; 
bit[31:0]  tx_host_addr_m,HOST_tx_host_addr_m,rx_host_addr_m,rxreq_host_addr_m,HOST_rxreq_host_addr_m;
bit[2:0]   tx_pf_num,HOST_tx_pf_num,rx_pf_num,rxreq_pf_num,HOST_rxreq_pf_num;
bit[10:0]  tx_vf_num,rx_vf_num,rxreq_vf_num,HOST_rxreq_vf_num;
bit        tx_vf_active,rx_vf_active,rxreq_vf_active,HOST_rxreq_vf_active;
bit[4:0]   tx_slot_num,HOST_tx_slot_num,rx_slot_num,rxreq_slot_num,HOST_rxreq_slot_num;
bit        rx_MM_mode, rxreq_MM_mode, HOST_rxreq_MM_mode;
bit[6:0]   tx_bar_num,HOST_tx_bar_num,rx_bar_num,rxreq_bar_num,HOST_rxreq_bar_num;
bit[255:0] tx_data_h,HOST_tx_data_h,rx_data_h,rxreq_data_h,HOST_rxreq_data_h ;
bit[31:0]  tx_data_1,HOST_tx_data_1,rx_data_1,rxreq_data_1,HOST_rxreq_data_1;
bit        tx_cont_mode, rx_cont_mode, rxreq_cont_mode, HOST_rxreq_cont_mode;
bit[3:0]   tx_test_mode,rx_test_mode,rxreq_test_mode,HOST_rxreq_test_mode;
bit[1:0]   tx_req_len,rx_req_len,rxreq_req_len,HOST_rxreq_req_len;
bit[2:0]   tx_tput_intrlev,rx_tput_intrlev,rxreq_tput_intrlev,HOST_rxreq_tput_intrlev;
bit        flag_rx=0,flag_rxreq=0,HOST_flag_rxreq=0,flag_tx=0,HOST_flag_tx=0,flag_64_rx=0,flag_64_rxreq=0,HOST_flag_64_rxreq=0,flag_64_tx=0,HOST_flag_64_tx=0;
int        count_rx=1,count_rxreq=1,HOST_count_rxreq=1,count_tx=1,HOST_count_tx=1;
bit[9:0]   tx_cmpl_len_pu,HOST_tx_cmpl_len_pu,rx_cmpl_len_pu,rxreq_cmpl_len_pu,HOST_rxreq_cmpl_len_pu;
bit[13:0]  rx_cmpl_len_dm,tx_cmpl_len_dm,HOST_tx_cmpl_len_dm;
bit[7:0]   tx_cmpl_type,HOST_tx_cmpl_type,rx_cmpl_type,rxreq_cmpl_type,HOST_rxreq_cmpl_type;  
bit[1:0]   tx_cmpl_status,HOST_tx_cmpl_status,rx_cmpl_status,rxreq_cmpl_status,HOST_rxreq_cmpl_status;
bit[23:0]  rx_length_dm,tx_length_dm,HOST_tx_length_dm;
bit[9:0]   rx_cmpl_tag_dm,tx_cmpl_tag_dm;
bit[9:0]   tx_tag_dm,HOST_tx_tag_dm,rx_tag_dm;
bit[9:0]   tx_cmpl_tag_pu,HOST_tx_cmpl_tag_pu,rx_cmpl_tag_pu,rxreq_cmpl_tag_pu,HOST_rxreq_cmpl_tag_pu;
bit[9:0]   rx_length_pu, rxreq_length_pu, HOST_rxreq_length_pu,tx_length_pu,HOST_tx_length_pu;
bit[9:0]   tx_mctp_len,HOST_tx_mctp_len,rx_mctp_len,HOST_rx_mctp_len;   //PMCI
bit[7:0]   tx_mctp_msg_code,HOST_tx_mctp_msg_code,rx_mctp_msg_code,HOST_rx_mctp_msg_code;
bit[15:0]  tx_mctp_vdm_code,HOST_tx_mctp_vdm_code,rx_mctp_vdm_code,HOST_rx_mctp_vdm_code;
bit[1:0]   tx_mctp_multi_pkt_seq,HOST_tx_mctp_multi_pkt_seq,rx_mctp_multi_pkt_seq,HOST_rx_mctp_multi_pkt_seq;
bit[31:0]  rx_he_lbk_cfg,rxreq_he_lbk_cfg,tx_he_lbk_cfg, rx_he_lbk_ctl,rxreq_he_lbk_ctl,tx_he_lbk_ctl;
bit[63:0]  rx_he_lbk_ctl_64, rxreq_he_lbk_ctl_64, rx_he_mem_ctl_64,rxreq_he_mem_ctl_64;
bit[63:0]  rx_he_lbk_cfg_64 ,rxreq_he_lbk_cfg_64, rx_he_mem_cfg_64,rxreq_he_mem_cfg_64;
bit        rx_he_lbk_cont_mode, rxreq_he_lbk_cont_mode,tx_he_lbk_cont_mode;
bit[2:0]   rx_he_lbk_test_mode, rxreq_he_lbk_test_mode,tx_he_lbk_test_mode;
bit[1:0]   rx_he_lbk_req_len, rxreq_he_lbk_req_len,tx_he_lbk_req_len;
bit[2:0]   rx_he_lbk_tput_intr, rxreq_he_lbk_tput_intr,tx_he_lbk_tput_intr;
bit[31:0]  rx_he_mem_cfg,rxreq_he_mem_cfg,tx_he_mem_cfg,rx_he_mem_ctl,rxreq_he_mem_ctl,tx_he_mem_ctl;
bit        rx_he_mem_cont_mode, rxreq_he_mem_cont_mode,tx_he_mem_cont_mode;
bit[2:0]   rx_he_mem_test_mode, rxreq_he_mem_test_mode,tx_he_mem_test_mode;
bit[1:0]   rx_he_mem_req_len, rxreq_he_mem_req_len,tx_he_mem_req_len;
bit[2:0]   rx_he_mem_tput_intr,rxreq_he_mem_tput_intr,tx_he_mem_tput_intr;
bit[7:0]   rx_fmt_type, rxreq_fmt_type, HOST_rxreq_fmt_type,tx_fmt_type,HOST_tx_fmt_type;
bit[15:0]  tx_vector_num,HOST_tx_vector_num;
bit        rx_he_lbk_forcdcmpl, rxreq_he_lbk_forcdcmpl,tx_he_lbk_forcdcmpl;
bit        rx_he_lbk_Start, rxreq_he_lbk_Start,rx_he_lbk_ResetL,rxreq_he_lbk_ResetL;
bit        rx_he_mem_forcdcmpl, rxreq_he_mem_forcdcmpl,tx_he_mem_forcdcmpl;
bit        rx_he_mem_Start,rx_he_mem_ResetL;
bit        rxreq_he_mem_Start,rxreq_he_mem_ResetL;
bit        rx_he_hssi_tg_ran_len,tx_he_hssi_tg_ran_len;
bit        rx_he_hssi_tg_data_pattern,tx_he_hssi_tg_data_pattern;
bit[31:0]  rx_he_hssi_tg, tx_he_hssi_tg;
bit[31:0]  rx_he_hssi_tg_pktlen_type,tx_he_hssi_tg_pktlen_type;
bit        rx_he_hssi_rnd_len,tx_he_hssi_rnd_len;
bit[31:0]  rx_he_hssi_tg_data_pt,tx_he_hssi_tg_data_pt;
bit        rx_he_hssi_rnd_pld,tx_he_hssi_rnd_pld;
bit[31:0]  rx_he_hssi_tg_num_pkt, tx_he_hssi_tg_num_pkt;
bit[31:0]  rx_he_hssi_seed0, tx_he_hssi_seed0;
bit[31:0]  rx_he_hssi_seed1, tx_he_hssi_seed1;
bit[31:0]  rx_he_hssi_seed2, tx_he_hssi_seed2;
bit[31:0]  rx_he_hssi_rnd_addr0, tx_he_hssi_rnd_addr0;
bit[31:0]  rx_he_hssi_rnd_addr1, tx_he_hssi_rnd_addr1;
bit[31:0]  rx_he_hssi_rnd_addr2, tx_he_hssi_rnd_addr2;
bit[13:0]  rx_he_hssi_pkt_len, tx_he_hssi_pkt_len;
bit        rx_he_hssi_avst_err,tx_he_hssi_avst_err;  
bit[31:0]  rx_he_hssi_err, tx_he_hssi_err;
bit        rx_he_hssi_len_err,tx_he_hssi_len_err;
bit        rx_he_hssi_oversiz_err,tx_he_hssi_oversiz_err;
bit        rx_he_hssi_undsiz_err,tx_he_hssi_undsiz_err;
bit        rx_he_hssi_mac_crc_err,tx_he_hssi_mac_crc_err;
bit        rx_he_hssi_phy_err,tx_he_hssi_phy_err;
bit        rx_he_hssi_err_valid,tx_he_hssi_err_valid;
bit[31:0]  rx_he_hssi_lbk, tx_he_hssi_lbk;
bit        rx_he_hssi_lbk_en, tx_he_hssi_lbk_en;
bit[31:0]  rx_he_hssi_lbk_fifo_st, tx_he_hssi_lbk_fifo_st;
bit        rx_he_hssi_lbk_fifo_almost_empty;
bit        rx_he_hssi_lbk_fifo_almost_full;
bit[31:0]  rx_he_hssi_traffic_ctrl_cmd,tx_he_hssi_traffic_ctrl_cmd;  //traffic cntrl cmd for he hssi
bit        rx_he_hssi_rd_cmd,tx_he_hssi_rd_cmd;
bit        rx_he_hssi_wr_cmd,tx_he_hssi_wr_cmd;
bit[3:0]   rx_he_hssi_traffic_ctrl_ch_sel,tx_he_hssi_traffic_ctrl_ch_sel;
bit[3:0]   rx_he_hssi_ch_sel,tx_he_hssi_ch_sel;
bit        he_lbk_top_reset ;
bit[31:0]  rx_emif_capability;
bit[63:0]  rx_emif_capability_64;
bit[3:0]   rx_emif_cap; 
bit        fme_vector;
bit        user_vector;
event      rx_trig,tx_trig;
bit[63:0] pf0_bar0_addr;
bit[63:0] he_lb_addr;
bit[63:0] he_mem_addr;
bit[63:0] he_hssi_addr;
bit[63:0] rx_host_addr_64,rxreq_host_addr_64,HOST_rxreq_host_addr_64;
bit[63:0] he_lbk_host_addr_64,he_mem_host_addr_64;
bit[63:0] fme_base_addr;
bit[63:0] pf0_bar0;
bit[63:0] HE_MEM_BASE;
bit[63:0] HE_HSSI_BASE; 
assign rx_clk = `PCIE_RX.clk;
`ifndef ENABLE_R1_COVERAGE 
assign rxreq_clk = `PCIE_RXREQ.clk;
`endif
`ifdef ENABLE_SOC_HOST_COVERAGE
  assign HOST_rxreq_clk = `HOST_PCIE_RXREQ.clk;
  assign HOST_tx_clk    = `HOST_PCIE_TX.clk;
`endif
assign tx_clk = `PCIE_TX.clk;
logic HSSI_RX_TVALID;
logic HE_HSSI_RX_TVALID;
logic [63:0] HSSI_RX_TDATA;
logic [63:0] HE_HSSI_RX_TDATA;

`ifdef ENABLE_AC_COVERAGE
assign mx2ho_valid =`AFU_TOP.pf_vf_mux_a.mx2ho_tx_port.tvalid; 
assign mx2ho_pfnum =`AFU_TOP.pf_vf_mux_a.mx2ho_tx_port.tdata[162:160];
assign mx2ho_vfnum =`AFU_TOP.pf_vf_mux_a.mx2ho_tx_port.tdata[173:163]; 
assign mx2ho_vfactive = `AFU_TOP.pf_vf_mux_a.mx2ho_tx_port.tdata[174];
assign mx2ho_fmttype  = `AFU_TOP.pf_vf_mux_a.mx2ho_tx_port.tdata[31:24];
//HE_HSSI -> HSSI PATH chek
assign HSSI_RX_TVALID = `TOP_DUT.hssi_wrapper.hssi_ss_st_rx[0].rx.tvalid;
assign HSSI_RX_TDATA  = `TOP_DUT.hssi_wrapper.hssi_ss_st_rx[0].rx.tdata[63:0];
assign HE_HSSI_RX_TVALID = `AFU_TOP.pg_afu.port_gasket.pr_slot.afu_main.port_afu_instances.hssi_ss_st_rx_t1[0].rx.tvalid;
assign HE_HSSI_RX_TDATA  = `AFU_TOP.pg_afu.port_gasket.pr_slot.afu_main.port_afu_instances.hssi_ss_st_rx_t1[0].rx.tdata[63:0];
assign HSSI_CLK = `TOP_DUT.hssi_wrapper.hssi_ss_st_rx[0].clk;
`endif

typedef struct {
   
     bit[63:0] pf0_bar0;
     bit[63:0] he_lb_base;
     bit[63:0] he_mem_base;
     bit[63:0] he_hssi_base;

               }st_base_addr;

st_base_addr st_addr; 

//*****************************************CODE_START*****************************

//********************************************************************RX_START******************************************************
always@(posedge `PCIE_RX.clk or negedge `PCIE_RX.clk) begin

if((`PCIE_RX.tvalid==1) &&(`PCIE_RX.tready==1) && (count_rx==1))begin
 `ifdef ENABLE_COV_MSG
   `uvm_info("INTF",$sformatf("RX:::first_256_bits_of data = %0h " ,`PCIE_RX.tdata[255:0] ), UVM_LOW)  
   `uvm_info("INTF",$sformatf("RX:::next_last_256_bits_of_data = %0h " ,`PCIE_RX.tdata[511:256] ), UVM_LOW)  
`endif
//*************************new 64 bit address update**********************************



uvm_config_db#(bit[63:0])::get(uvm_root::get(),"*","pf0_bar0", st_addr.pf0_bar0);
uvm_config_db#(bit[63:0])::get(uvm_root::get(),"*","he_lb_base", st_addr.he_lb_base);
uvm_config_db#(bit[63:0])::get(uvm_root::get(),"*","he_mem_base", st_addr.he_mem_base);
uvm_config_db#(bit[63:0])::get(uvm_root::get(),"*","he_hssi_base", st_addr.he_hssi_base);

`ifdef ENABLE_COV_MSG
`uvm_info("", $sformatf("pf0_bar0        %8h", st_addr.pf0_bar0 )    , UVM_LOW)
`uvm_info("", $psprintf("he_lb_base      %8h", st_addr.he_lb_base)   , UVM_LOW)
`uvm_info("", $psprintf("he_mem_base     %8h", st_addr.he_mem_base)  , UVM_LOW)
`uvm_info("", $psprintf("he_hssi_base    %8h", st_addr.he_hssi_base) , UVM_LOW)
 `endif

 pf0_bar0_addr=st_addr.pf0_bar0;
 he_lb_addr   =st_addr.he_lb_base;
 he_mem_addr  =st_addr.he_mem_base;
 he_hssi_addr =st_addr.he_hssi_base;

`ifdef ENABLE_COV_MSG
`uvm_info("INTF",$sformatf("pf0_bar0 = %0h " ,pf0_bar0 ), UVM_LOW)
`uvm_info("", $psprintf("he_lb_addr     %8h", he_lb_addr)    , UVM_LOW)
`uvm_info("", $psprintf("he_mem_addr     %8h", he_mem_addr)    , UVM_LOW)
`uvm_info("", $psprintf("he_hssi_addr     %8h", he_hssi_addr)    , UVM_LOW)
`endif
    //RX 
    rx_tvalid =`PCIE_RX.tvalid; 
    rx_tlast  =`PCIE_RX.tlast; 
    rx_tuser  =`PCIE_RX.tuser_vendor; 
    rx_tdata  =`PCIE_RX.tdata; 
    rx_tkeep  =`PCIE_RX.tkeep;
    rx_tready =`PCIE_RX.tready;
    rx_splitting;
    flag_rx=1; 
    flag_64_rx=1;
    count_rx++;
    end else begin
   flag_rx = 0;
   flag_64_rx=0;

end


if((`PCIE_RX.tvalid==1) &&(`PCIE_RX.tready==1) && (`PCIE_RX.tlast==1))begin
  count_rx=1;
    end
 end
 
//********************************************************************RXREQ_START******************************************************
`ifndef ENABLE_R1_COVERAGE 
always@(posedge `PCIE_RXREQ.clk or negedge `PCIE_RXREQ.clk) begin

if((`PCIE_RXREQ.tvalid==1) &&(`PCIE_RXREQ.tready==1) && (count_rxreq==1))begin
 `ifdef ENABLE_COV_MSG
   `uvm_info("INTF",$sformatf("RXREQ:::first_256_bits_of data = %0h " ,`PCIE_RXREQ.tdata[255:0] ), UVM_LOW)  
   `uvm_info("INTF",$sformatf("RXREQ:::next_last_256_bits_of_data = %0h " ,`PCIE_RXREQ.tdata[511:256] ), UVM_LOW)  
`endif

uvm_config_db#(bit[63:0])::get(uvm_root::get(),"*","pf0_bar0", st_addr.pf0_bar0);
`ifndef ENABLE_SOC_HOST_COVERAGE
uvm_config_db#(bit[63:0])::get(uvm_root::get(),"*","he_lb_base", st_addr.he_lb_base);
 `endif
uvm_config_db#(bit[63:0])::get(uvm_root::get(),"*","he_mem_base", st_addr.he_mem_base);
uvm_config_db#(bit[63:0])::get(uvm_root::get(),"*","he_hssi_base", st_addr.he_hssi_base);

`ifdef ENABLE_COV_MSG
`uvm_info("", $sformatf("pf0_bar0        %8h", st_addr.pf0_bar0 )    , UVM_LOW)
`ifndef ENABLE_SOC_HOST_COVERAGE
`uvm_info("", $psprintf("he_lb_base      %8h", st_addr.he_lb_base)   , UVM_LOW)
 `endif
`uvm_info("", $psprintf("he_mem_base     %8h", st_addr.he_mem_base)  , UVM_LOW)
`uvm_info("", $psprintf("he_hssi_base    %8h", st_addr.he_hssi_base) , UVM_LOW)
 `endif

 pf0_bar0_addr=st_addr.pf0_bar0;
`ifndef ENABLE_SOC_HOST_COVERAGE
 he_lb_addr   =st_addr.he_lb_base;
 `endif
 he_mem_addr  =st_addr.he_mem_base;
 he_hssi_addr =st_addr.he_hssi_base;

`ifdef ENABLE_COV_MSG
`uvm_info("INTF",$sformatf("pf0_bar0 = %0h " ,pf0_bar0 ), UVM_LOW)
`ifndef ENABLE_SOC_HOST_COVERAGE
`uvm_info("", $psprintf("he_lb_addr     %8h", he_lb_addr)    , UVM_LOW)
 `endif
`uvm_info("", $psprintf("he_mem_addr     %8h", he_mem_addr)    , UVM_LOW)
`uvm_info("", $psprintf("he_hssi_addr     %8h", he_hssi_addr)    , UVM_LOW)
`endif

    //RXREQ 
    rxreq_tvalid =`PCIE_RXREQ.tvalid; 
    rxreq_tlast  =`PCIE_RXREQ.tlast; 
    rxreq_tuser  =`PCIE_RXREQ.tuser_vendor; 
    rxreq_tdata  =`PCIE_RXREQ.tdata; 
    rxreq_tkeep  =`PCIE_RXREQ.tkeep;
    rxreq_tready =`PCIE_RXREQ.tready;
    rxreq_splitting;
    flag_rxreq=1; 
    flag_64_rxreq=1;
    count_rxreq++;
    end else begin
   flag_rxreq = 0;
   flag_64_rxreq=0;

end

if((`PCIE_RXREQ.tvalid==1) &&(`PCIE_RXREQ.tready==1) && (`PCIE_RXREQ.tlast==1))begin
  count_rxreq=1;
    end
 end
`endif
//********************************************************************HOST_RXREQ_START******************************************************
`ifdef ENABLE_SOC_HOST_COVERAGE
  always@(posedge `HOST_PCIE_RXREQ.clk or negedge `HOST_PCIE_RXREQ.clk) begin
  
  if((`HOST_PCIE_RXREQ.tvalid==1) &&(`HOST_PCIE_RXREQ.tready==1) && (HOST_count_rxreq==1))begin
   `ifdef ENABLE_COV_MSG
     `uvm_info("INTF",$sformatf("HOST_RXREQ:::first_256_bits_of data = %0h " ,`HOST_PCIE_RXREQ.tdata[255:0] ), UVM_LOW)  
     `uvm_info("INTF",$sformatf("HOST_RXREQ:::next_last_256_bits_of_data = %0h " ,`HOST_PCIE_RXREQ.tdata[511:256] ), UVM_LOW)  
  `endif

   uvm_config_db#(bit[63:0])::get(uvm_root::get(),"*","he_lb_base", st_addr.he_lb_base);
   `ifdef ENABLE_COV_MSG
   `uvm_info("", $psprintf("he_lb_base      %8h", st_addr.he_lb_base)   , UVM_LOW)
    `endif
    he_lb_addr   =st_addr.he_lb_base;
   `ifdef ENABLE_COV_MSG
   `uvm_info("", $psprintf("he_lb_addr     %8h", he_lb_addr)    , UVM_LOW)
    `endif

  
  
      //RXREQ 
      HOST_rxreq_tvalid =`HOST_PCIE_RXREQ.tvalid; 
      HOST_rxreq_tlast  =`HOST_PCIE_RXREQ.tlast; 
      HOST_rxreq_tuser  =`HOST_PCIE_RXREQ.tuser_vendor; 
      HOST_rxreq_tdata  =`HOST_PCIE_RXREQ.tdata; 
      HOST_rxreq_tkeep  =`HOST_PCIE_RXREQ.tkeep;
      HOST_rxreq_tready =`HOST_PCIE_RXREQ.tready;
      HOST_rxreq_splitting;
      HOST_flag_rxreq=1; 
      HOST_flag_64_rxreq=1;
      HOST_count_rxreq++;
      end else begin
     HOST_flag_rxreq = 0;
     HOST_flag_64_rxreq=0;
  
  end
  
  if((`HOST_PCIE_RXREQ.tvalid==1) &&(`HOST_PCIE_RXREQ.tready==1) && (`HOST_PCIE_RXREQ.tlast==1))begin
    HOST_count_rxreq=1;
      end
   end
`endif

//********************************************************************TX_START******************************************************
always@(posedge `PCIE_TX.clk or negedge `PCIE_TX.clk) begin
if((`PCIE_TX.tvalid==1) &&(`PCIE_TX.tready==1) && (count_tx==1))begin

  `ifdef ENABLE_COV_MSG
    `uvm_info("INTF",$sformatf("TX:::first_256_bits_of data = %0h " ,`PCIE_TX.tdata[255:0] ), UVM_LOW)  
    `uvm_info("INTF",$sformatf("TX:::next_last_256_bits_of_data = %0h " ,`PCIE_TX.tdata[511:256] ), UVM_LOW) 
`endif

    //TX 
    tx_tvalid =`PCIE_TX.tvalid; 
    tx_tlast  =`PCIE_TX.tlast; 
    tx_tuser  =`PCIE_TX.tuser_vendor; 
    tx_tdata  =`PCIE_TX.tdata; 
    tx_tkeep  =`PCIE_TX.tkeep;
    tx_tready =`PCIE_TX.tready;
    tx_splitting;
    flag_tx=1; 
    flag_64_tx=1;
    count_tx++;
    end else begin
   flag_tx = 0;
   flag_64_tx=0;
end

if((`PCIE_TX.tvalid==1) &&(`PCIE_TX.tready==1) && (`PCIE_TX.tlast==1))begin
  count_tx=1;
   end
end 
//********************************************************************HOST_TX_START******************************************************
`ifdef ENABLE_SOC_HOST_COVERAGE
always@(posedge `HOST_PCIE_TX.clk or negedge `HOST_PCIE_TX.clk) begin
if((`HOST_PCIE_TX.tvalid==1) &&(`HOST_PCIE_TX.tready==1) && (HOST_count_tx==1))begin

  `ifdef ENABLE_COV_MSG
    `uvm_info("INTF",$sformatf("HOST_TX:::first_256_bits_of data = %0h " ,`HOST_PCIE_TX.tdata[255:0] ), UVM_LOW)  
    `uvm_info("INTF",$sformatf("HOST_TX:::next_last_256_bits_of_data = %0h " ,`HOST_PCIE_TX.tdata[511:256] ), UVM_LOW) 
`endif

    //TX 
    HOST_tx_tvalid =`HOST_PCIE_TX.tvalid; 
    HOST_tx_tlast  =`HOST_PCIE_TX.tlast; 
    HOST_tx_tuser  =`HOST_PCIE_TX.tuser_vendor; 
    HOST_tx_tdata  =`HOST_PCIE_TX.tdata; 
    HOST_tx_tkeep  =`HOST_PCIE_TX.tkeep;
    HOST_tx_tready =`HOST_PCIE_TX.tready;
    HOST_tx_splitting;
    HOST_flag_tx=1; 
    HOST_flag_64_tx=1;
    HOST_count_tx++;
    end else begin
   HOST_flag_tx = 0;
   HOST_flag_64_tx=0;
end

if((`HOST_PCIE_TX.tvalid==1) &&(`HOST_PCIE_TX.tready==1) && (`HOST_PCIE_TX.tlast==1))begin
  HOST_count_tx=1;
   end
end 
`endif

//*****************************************Request_RX_TX_Splitting*****************************
task rx_splitting ; 
//byte 0,1,2,3
 rx_req_fmt   = rx_tdata[31:29];
 rx_req_type  = rx_tdata[28:24];
 rx_fmt_type  ={rx_tdata[31:29],rx_tdata[28:24]};
`ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("RX::Fmt_type= %0h",rx_fmt_type ),UVM_LOW)
  `endif
//*************************************new_update *************************************

if((rx_tdata[31:29]==3)||(rx_tdata[31:29]==1))begin   
 rx_host_addr_64 ={rx_tdata[95:64], rx_tdata[127:96]};   // [95:64] - Host addr [63:32]  [127:96] - Host addr [31:0]
end else if ((rx_tdata[31:29]==2)||(rx_tdata[31:29]==0))begin
 rx_host_addr_h ={rx_tdata[95:64]};   
end

`ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("RX::Host_Addr= %0h",rx_host_addr_h ),UVM_LOW)
 `uvm_info("INTF", $sformatf("RX::Host_Addr_64= %0h",rx_host_addr_64 ),UVM_LOW)
`endif




 if(rx_tuser==0)begin  //POWER_USER_MODE
   rx_length_pu  = rx_tdata[9:0];
 end else begin //DATA_MOVER
   rx_length_dm ={rx_tdata[61:50],rx_tdata[9:0],rx_tdata[49:48]}; 
 end
`ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("RX:::LEN= %0d|| Format=%0d ||TYpe=%0d ", rx_length_1,rx_req_fmt,rx_req_type ),UVM_LOW)
`endif
//byte 4,5,6,7
 rx_length_l    = rx_tdata[49:48];
 rx_length_h    = rx_tdata[61:50];
 rx_host_addr_1 = rx_tdata[63:32];
 rx_tag_dm      = {rx_tdata[23],rx_tdata[19],rx_tdata[47:40]};
//byte 8,9,10,11
`ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("RX::Host_Addr= %0h",rx_host_addr_h ),UVM_LOW)
`endif
//byte 12,13,14,15
 rx_host_addr_m={rx_tdata[127:96]};
  `ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("RX::Host_Addr_2= %0h",rx_host_addr_m ),UVM_LOW)
`endif
//byte 16,17,18,19 -->prefix (No need to check)  
//byte 20,21,22,23
 rx_pf_num	 = rx_tdata[162:160];
 rx_vf_num	 = rx_tdata[173:163];
 rx_vf_active= rx_tdata[174];
 rx_bar_num	 = rx_tdata [178:175]; 
 rx_slot_num = rx_tdata[183:179];
 rx_MM_mode  = rx_tdata[184];
`ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("RX::PF_no=%0d ||VF_no=%0d ||VF_active=%0d||slot_no=%0d ||MM_mode=%0d ||bar_no=%0d",rx_pf_num,rx_vf_num,rx_vf_active,rx_slot_num,rx_MM_mode,rx_bar_num ),UVM_LOW)
`endif
//byte 24,25,26,27,28,29,30,31 -->>Reserved
//Byte 32,33,34,35
 rx_data_h=rx_tdata[511:256];
`ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("RX::DATA_256to511= %0h",rx_data_h ),UVM_LOW)
`endif

//*****************************************completion_RX_Splitting****************************

 rx_cmpl_type   = rx_tdata[31:24];
 rx_cmpl_status = rx_tdata[47:45];
 if(rx_tuser==0)begin
   rx_cmpl_len_pu    = rx_tdata[9:0];
 end else begin
   rx_cmpl_len_dm    = {rx_tdata[115:114],rx_tdata[9:0],rx_tdata[113:112]};
   rx_cmpl_tag_dm    = {rx_tdata[127:118]};
 end
`ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("RX::::::Compl_len_PU=%0d||comp_len_DM=%0d||comp_type=%0d ||compl_status=%0d",rx_cmpl_len_pu,rx_cmpl_len_dm,rx_cmpl_type,rx_cmpl_status),UVM_LOW)
`endif

//CFG_CSR_CHECKING
//For AC and F2000x coverage
 `ifndef ENABLE_R1_COVERAGE 
     if((rx_host_addr_h==pf0_bar0_addr+32'h15010)&&(rx_tdata[31:29]==2))begin     //EMIF_CAPABILITY
      rx_emif_capability =rx_tdata[287:256];
      rx_emif_cap        =rx_emif_capability[3:0];
      `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RX::EMIF_capability= %0h",rx_emif_cap),UVM_LOW)
    `endif
     end else if((rx_host_addr_h==pf0_bar0_addr+64'h15010)&&(rx_tdata[31:29]==3))begin
      rx_emif_capability_64 =rx_tdata[319:256];
      rx_emif_cap        =rx_emif_capability_64[3:0];
      `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RX::EMIF_capability= %0h",rx_emif_cap),UVM_LOW)
    `endif

     end else if((rx_host_addr_h==he_lb_addr+32'h140)&&(rx_tdata[31:29]==2))begin   //HE_LBK
      rx_he_lbk_cfg=rx_tdata[287:256];
      `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RX::HE_bk_config= %0h",rx_he_lbk_cfg ),UVM_LOW)
 `endif
      rx_he_lbk_cont_mode=rx_he_lbk_cfg[1];
      rx_he_lbk_test_mode=rx_he_lbk_cfg[4:2];
      rx_he_lbk_req_len  =rx_he_lbk_cfg[6:5];
      rx_he_lbk_tput_intr=rx_he_lbk_cfg[22:20];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RX::HE_lbk_cont_mode=%0h,HE_lbk_test_mod= %0h,req_len=%0h,tput_intr=%0h",rx_he_lbk_cont_mode,rx_he_lbk_test_mode,rx_he_lbk_req_len,rx_he_lbk_tput_intr ),UVM_LOW)
 `endif
 end else if((rx_host_addr_64==he_lb_addr+32'h140)&&(rx_tdata[31:29]==3))begin   //HE_LBK 
      rx_he_lbk_cfg_64 =rx_tdata[319:256];
      `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RX::HE_bk_config_64= %0h",rx_he_lbk_cfg_64 ),UVM_LOW)//
 `endif
      rx_he_lbk_cont_mode=rx_he_lbk_cfg_64[1];
      rx_he_lbk_test_mode=rx_he_lbk_cfg_64[4:2];
      rx_he_lbk_req_len  =rx_he_lbk_cfg_64[6:5];
      rx_he_lbk_tput_intr=rx_he_lbk_cfg_64[22:20];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RX::HE_lbk_cont_mode=%0h,HE_lbk_test_mod= %0h,req_len=%0h,tput_intr=%0h",rx_he_lbk_cont_mode,rx_he_lbk_test_mode,rx_he_lbk_req_len,rx_he_lbk_tput_intr ),UVM_LOW)
 `endif
    
    end else if((rx_host_addr_h==he_lb_addr+32'h138)&&(rx_tdata[31:29]==2))begin    //CTL for HE_LBK (138)
      rx_he_lbk_ctl=rx_tdata[287:256];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RX::HE_lbk_CTL= %0h",rx_he_lbk_ctl ),UVM_LOW)
 `endif
      rx_he_lbk_forcdcmpl=rx_he_lbk_ctl[2];
      rx_he_lbk_Start    =rx_he_lbk_ctl[1];  
      rx_he_lbk_ResetL   =rx_he_lbk_ctl[0];  
 `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("forcedcmpl= %0h",rx_he_lbk_forcdcmpl ),UVM_LOW)
 `endif

  end else if((rx_host_addr_64==he_lb_addr+ 32'h138)&&(rx_tdata[31:29]==3))begin    //CTL for HE_LBK (138)
      rx_he_lbk_ctl_64 =rx_tdata[319:256];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RX::HE_lbk_CTL_64= %0h",rx_he_lbk_ctl_64 ),UVM_LOW)
 `endif
      rx_he_lbk_forcdcmpl=rx_he_lbk_ctl_64[2];
      rx_he_lbk_Start    =rx_he_lbk_ctl_64[1];  
      rx_he_lbk_ResetL   =rx_he_lbk_ctl_64[0]; 

 `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("forcedcmpl= %0h",rx_he_lbk_forcdcmpl ),UVM_LOW)
 `endif

end else if((rx_host_addr_h==he_mem_addr+32'h140)&&(rx_tdata[31:29]==2))begin   //HE_MEM 
     rx_he_mem_cfg=rx_tdata[287:256];
      `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RX::HE_MEM_config= %0h",rx_he_mem_cfg ),UVM_LOW)
 `endif
      rx_he_mem_cont_mode=rx_he_mem_cfg[1];
      rx_he_mem_test_mode=rx_he_mem_cfg[4:2];
      rx_he_mem_req_len  =rx_he_mem_cfg[6:5];
      rx_he_mem_tput_intr=rx_he_mem_cfg[22:20];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RX::he_mem_cont_mode=%0h,he_mem_test_mod= %0h,req_len=%0h,tput_intr=%0h",rx_he_mem_cont_mode,rx_he_mem_test_mode,rx_he_mem_req_len,rx_he_mem_tput_intr ),UVM_LOW)
 `endif
 end else if((rx_host_addr_64==he_mem_addr+32'h140)&&(rx_tdata[31:29]==3))begin   //HE_MEM
      rx_he_mem_cfg_64 =rx_tdata[319:256];
      `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RX::HE_MEM_config_64= %0h",rx_he_mem_cfg_64 ),UVM_LOW)
 `endif
      rx_he_mem_cont_mode=rx_he_mem_cfg_64[1];
      rx_he_mem_test_mode=rx_he_mem_cfg_64[4:2];
      rx_he_mem_req_len  =rx_he_mem_cfg_64[6:5];
      rx_he_mem_tput_intr=rx_he_mem_cfg_64[22:20];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RX::he_mem_cont_mode=%0h,he_mem_test_mod= %0h,req_len=%0h,tput_intr=%0h",rx_he_mem_cont_mode,rx_he_mem_test_mode,rx_he_mem_req_len,rx_he_mem_tput_intr ),UVM_LOW)
 `endif

     
    end else if((rx_host_addr_h==he_mem_addr+32'h138)&&(rx_tdata[31:29]==2))begin    //CTL for HE_MEM (138)
      rx_he_mem_ctl=rx_tdata[287:256];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RX::he_mem_CTL= %0h",rx_he_mem_ctl ),UVM_LOW)
 `endif
      rx_he_mem_forcdcmpl=rx_he_mem_ctl[2];
      rx_he_mem_Start    =rx_he_mem_ctl[1];  
      rx_he_mem_ResetL   =rx_he_mem_ctl[0]; 
 `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("forcedcmpl= %0h",rx_he_mem_forcdcmpl ),UVM_LOW)
 `endif

  end else if((rx_host_addr_64==he_mem_addr+ 32'h138)&&(rx_tdata[31:29]==3))begin    //CTL for HE_MEM (138)
      rx_he_mem_ctl_64 =rx_tdata[319:256];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RX::he_mem_CTL_64= %0h",rx_he_mem_ctl_64 ),UVM_LOW)
 `endif
      rx_he_mem_forcdcmpl=rx_he_mem_ctl_64[2];
      rx_he_mem_Start    =rx_he_mem_ctl_64[1]; 
      rx_he_mem_ResetL   =rx_he_mem_ctl_64[0];

 `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("forcedcmpl= %0h",rx_he_mem_forcdcmpl ),UVM_LOW)
 `endif

      end else if((rx_host_addr_h==he_hssi_addr+32'h60030)&&(rx_tdata[31:29]==2))begin     //HE_HSSI 
       rx_he_hssi_traffic_ctrl_cmd=rx_tdata[287:256];
       rx_he_hssi_rd_cmd=rx_he_hssi_traffic_ctrl_cmd[0];
       rx_he_hssi_wr_cmd=rx_he_hssi_traffic_ctrl_cmd[1];
    `ifdef ENABLE_COV_MSG
       `uvm_info("INTF", $sformatf("RX::HE_hssi_traffic_rd_cmd= %0h,HE_hssi_traffic_rd_cmd= %0h",rx_he_hssi_rd_cmd,rx_he_hssi_wr_cmd ),UVM_LOW)
   `endif
        end else if((rx_host_addr_h==he_hssi_addr+32'h60040)&&(rx_tdata[31:29]==2))begin  
       rx_he_hssi_traffic_ctrl_ch_sel=rx_tdata[259:256];
       rx_he_hssi_ch_sel=rx_he_hssi_traffic_ctrl_ch_sel[3:0];
     `ifdef ENABLE_COV_MSG
       `uvm_info("INTF", $sformatf("RX::HE_hssi_traffic_channel_sel= %0h",rx_he_hssi_ch_sel ),UVM_LOW)
   `endif
       end else if((rx_host_addr_64==he_hssi_addr+32'h60030)&&(rx_tdata[31:29]==3))begin    
       rx_he_hssi_traffic_ctrl_cmd=rx_tdata[319:256];
       rx_he_hssi_rd_cmd=rx_he_hssi_traffic_ctrl_cmd[0];
       rx_he_hssi_wr_cmd=rx_he_hssi_traffic_ctrl_cmd[1];
    `ifdef ENABLE_COV_MSG
       `uvm_info("INTF", $sformatf("RX::HE_hssi_traffic_rd_cmd_64= %0h,HE_hssi_traffic_wr_cmd_64= %0h",rx_he_hssi_rd_cmd,rx_he_hssi_wr_cmd ),UVM_LOW)
   `endif
      end else if((rx_host_addr_64==he_hssi_addr+32'h60040)&&(rx_tdata[31:29]==3))begin  
       rx_he_hssi_traffic_ctrl_ch_sel=rx_tdata[259:256];
       rx_he_hssi_ch_sel=rx_he_hssi_traffic_ctrl_ch_sel[3:0];
     `ifdef ENABLE_COV_MSG
       `uvm_info("INTF", $sformatf("RX::HE_hssi_traffic_channel_sel= %0h",rx_he_hssi_ch_sel ),UVM_LOW)
   `endif

end
`endif


`ifdef ENABLE_R1_COVERAGE

     if((rx_host_addr_h==he_lb_addr +32'h140)&&(rx_tdata[31:29]==2) )begin    //CFG for HE_LBK ab14 0000 
      rx_he_lbk_cfg=rx_tdata[287:256]; 
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RX::HE_bk_config= %0h",rx_he_lbk_cfg ),UVM_LOW)//48=0 10-req 010-test 00
 `endif
      rx_he_lbk_cont_mode=rx_he_lbk_cfg[1];
      rx_he_lbk_test_mode=rx_he_lbk_cfg[4:2];
      rx_he_lbk_req_len  =rx_he_lbk_cfg[6:5];
      rx_he_lbk_tput_intr=rx_he_lbk_cfg[22:20];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RX::HE_lbk_cont_mode=%0h,HE_lbk_test_mod= %0h,req_len=%0h,tput_intr=%0h",rx_he_lbk_cont_mode,rx_he_lbk_test_mode,rx_he_lbk_req_len,rx_he_lbk_tput_intr ),UVM_LOW)
 `endif
      end else if((rx_host_addr_h==he_mem_addr+32'h140)&&(rx_tdata[31:29]==2) )begin   //CFG for HE_MEM ab18 0000
      rx_he_mem_cfg=rx_tdata[287:256];
     `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RX::HE_mem_config= %0h",rx_he_mem_cfg ),UVM_LOW)
 `endif
      rx_he_mem_cont_mode=rx_he_mem_cfg[1];
      rx_he_mem_test_mode=rx_he_mem_cfg[4:2];
      rx_he_mem_req_len  =rx_he_mem_cfg[6:5];
      rx_he_mem_tput_intr=rx_he_mem_cfg[22:20];
     `ifdef ENABLE_COV_MSG
       `uvm_info("INTF", $sformatf("RX::HE_mem_cont_mode=%0h,HE_mem_test_mod= %0h,req_len=%0h,tput_intr=%0h",rx_he_mem_cont_mode,rx_he_mem_test_mode,rx_he_mem_req_len,rx_he_mem_tput_intr ),UVM_LOW)
   `endif
         end else if((rx_host_addr_h==he_lb_addr+32'h138)&&(rx_tdata[31:29]==2) )begin 
      rx_he_lbk_ctl=rx_tdata[287:256];
     `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RX::HE_lbk_CTL= %0h, forcedcompl= %0h",rx_he_lbk_ctl, rx_he_lbk_forcdcmpl),UVM_LOW)
 `endif
      rx_he_lbk_forcdcmpl=rx_he_lbk_ctl[2];
    end else if ((rx_host_addr_h==he_mem_addr+32'h138)&&(rx_tdata[31:29]==2) )begin
      rx_he_mem_ctl=rx_tdata[287:256];
     `ifdef ENABLE_COV_MSG
      `uvm_info("INTF", $sformatf("RX::HE_mem_CTL= %0h, forcedcompl= %0h",rx_he_mem_ctl,rx_he_mem_forcdcmpl ),UVM_LOW)
  `endif
      rx_he_mem_forcdcmpl=rx_he_mem_ctl[2];

      end else if((rx_host_addr_h==he_hssi_addr+32'h30)&&(rx_tdata[31:29]==2))begin     //HE_HSSI 
       rx_he_hssi_traffic_ctrl_cmd=rx_tdata[287:256];
       rx_he_hssi_rd_cmd=rx_he_hssi_traffic_ctrl_cmd[0];
       rx_he_hssi_wr_cmd=rx_he_hssi_traffic_ctrl_cmd[1];
    `ifdef ENABLE_COV_MSG
       `uvm_info("INTF", $sformatf("RX::HE_hssi_traffic_rd_cmd= %0h,HE_hssi_traffic_wr_cmd= %0h",rx_he_hssi_rd_cmd,rx_he_hssi_wr_cmd ),UVM_LOW)
   `endif
        end else if((rx_host_addr_h==he_hssi_addr+32'h40)&&(rx_tdata[31:29]==2))begin  
       rx_he_hssi_traffic_ctrl_ch_sel=rx_tdata[259:256];
       rx_he_hssi_ch_sel=rx_he_hssi_traffic_ctrl_ch_sel[3:0];
     `ifdef ENABLE_COV_MSG
       `uvm_info("INTF", $sformatf("RX::HE_hssi_traffic_channel_sel= %0h",rx_he_hssi_ch_sel ),UVM_LOW)
   `endif
       end       
     `endif    
 endtask
 
task rxreq_splitting ; 
//byte 0,1,2,3
 rxreq_req_fmt   = rxreq_tdata[31:29];
 rxreq_req_type  = rxreq_tdata[28:24];
 rxreq_fmt_type  ={rxreq_tdata[31:29],rxreq_tdata[28:24]};
`ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("RXREQ::Fmt_type= %0h",rxreq_fmt_type ),UVM_LOW)
  `endif
//*************************************RXREQ_new_update *************************************

if((rxreq_tdata[31:29]==3)||(rxreq_tdata[31:29]==1))begin   
 rxreq_host_addr_64 ={rxreq_tdata[95:64], rxreq_tdata[127:96]};   // [95:64] - Host addr [63:32]  [127:96] - Host addr [31:0]
end else if ((rxreq_tdata[31:29]==2)||(rxreq_tdata[31:29]==0))begin
 rxreq_host_addr_h ={rxreq_tdata[95:64]};   
end

`ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("RXREQ::Host_Addr= %0h",rxreq_host_addr_h ),UVM_LOW)
 `uvm_info("INTF", $sformatf("RXREQ::Host_Addr_64= %0h",rxreq_host_addr_64 ),UVM_LOW)
`endif




 if(rxreq_tuser==0)begin  //POWER_USER_MODE
   rxreq_length_pu  = rxreq_tdata[9:0];
 end else begin //DATA_MOVER
   rx_length_dm ={rx_tdata[61:50],rx_tdata[9:0],rx_tdata[49:48]}; 
 end
`ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("RXREQ:::LEN= %0d|| Format=%0d ||TYpe=%0d ", rxreq_length_1,rxreq_req_fmt,rxreq_req_type ),UVM_LOW)
`endif
//byte 4,5,6,7
 rxreq_length_l    = rxreq_tdata[49:48];
 rxreq_length_h    = rxreq_tdata[61:50];
 rxreq_host_addr_1 = rxreq_tdata[63:32];
 rx_tag_dm      = {rx_tdata[23],rx_tdata[19],rx_tdata[47:40]};
//byte 8,9,10,11
`ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("RXREQ::Host_Addr= %0h",rxreq_host_addr_h ),UVM_LOW)
`endif
//byte 12,13,14,15
 rxreq_host_addr_m={rxreq_tdata[127:96]};
  `ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("RXREQ::Host_Addr_2= %0h",rxreq_host_addr_m ),UVM_LOW)
`endif
//byte 16,17,18,19 -->prefix (No need to check)  
//byte 20,21,22,23
 rxreq_pf_num	 = rxreq_tdata[162:160];
 rxreq_vf_num	 = rxreq_tdata[173:163];
 rxreq_vf_active=  rxreq_tdata[174];
 rxreq_bar_num	 = rxreq_tdata [178:175]; 
 rxreq_slot_num = rxreq_tdata[183:179];
 rxreq_MM_mode  = rxreq_tdata[184];
`ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("RXREQ::PF_no=%0d ||VF_no=%0d ||VF_active=%0d||slot_no=%0d ||MM_mode=%0d ||bar_no=%0d",rxreq_pf_num,rxreq_vf_num,rxreq_vf_active,rxreq_slot_num,rxreq_MM_mode,rxreq_bar_num ),UVM_LOW)
`endif
//byte 24,25,26,27,28,29,30,31 -->>Reserved
//Byte 32,33,34,35
 rxreq_data_h=rxreq_tdata[511:256];
`ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("RXREQ::DATA_256to511= %0h",rxreq_data_h ),UVM_LOW)
`endif
//PMCI
    rx_mctp_len      = rxreq_tdata[9:0];
    rx_mctp_msg_code = rxreq_tdata[39:32];
    rx_mctp_vdm_code = rxreq_tdata[79:64];
    rx_mctp_multi_pkt_seq = rxreq_tdata[103:102];

//*****************************************completion_RXREQ_Splitting****************************

 rxreq_cmpl_type   = rxreq_tdata[31:24];
 rxreq_cmpl_status = rxreq_tdata[47:45];
 if(rxreq_tuser==0)begin
   rxreq_cmpl_len_pu    = rxreq_tdata[9:0];
 end else begin
   rx_cmpl_len_dm    = {rx_tdata[115:114],rx_tdata[9:0],rx_tdata[113:112]};
   rx_cmpl_tag_dm    = {rx_tdata[127:118]};
 end
`ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("RXREQ::::::Compl_len_PU=%0d||comp_len_DM=%0d||comp_type=%0d ||compl_status=%0d",rxreq_cmpl_len_pu,rx_cmpl_len_dm,rxreq_cmpl_type,rxreq_cmpl_status),UVM_LOW)
`endif

//CFG_CSR_CHECKING
//For AC and F2000x coverage
 `ifndef ENABLE_R1_COVERAGE  
     if((rxreq_host_addr_h==pf0_bar0_addr+32'h15010)&&(rxreq_tdata[31:29]==2))begin     //EMIF_CAPABILITY
      rx_emif_capability =rxreq_tdata[287:256];
      rx_emif_cap        =rx_emif_capability[3:0];
      `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RXREQ::EMIF_capability= %0h",rx_emif_cap),UVM_LOW)
    `endif
     end else if((rxreq_host_addr_h==pf0_bar0_addr+64'h15010)&&(rxreq_tdata[31:29]==3))begin
      rx_emif_capability_64 =rxreq_tdata[319:256];
      rx_emif_cap        =rx_emif_capability_64[3:0];
      `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RXREQ::EMIF_capability= %0h",rx_emif_cap),UVM_LOW)
    `endif

     end else if((rxreq_host_addr_h==he_lb_addr+32'h140)&&(rxreq_tdata[31:29]==2))begin   //HE_LBK
     `ifndef ENABLE_SOC_HOST_COVERAGE
        rxreq_he_lbk_cfg=rxreq_tdata[287:256];
        `ifdef ENABLE_COV_MSG
          `uvm_info("INTF", $sformatf("RXREQ::HE_bk_config= %0h",rxreq_he_lbk_cfg ),UVM_LOW)
        `endif
        rxreq_he_lbk_cont_mode=rxreq_he_lbk_cfg[1];
        rxreq_he_lbk_test_mode=rxreq_he_lbk_cfg[4:2];
        rxreq_he_lbk_req_len  =rxreq_he_lbk_cfg[6:5];
        rxreq_he_lbk_tput_intr=rxreq_he_lbk_cfg[22:20];
        `ifdef ENABLE_COV_MSG
          `uvm_info("INTF", $sformatf("RXREQ::HE_lbk_cont_mode=%0h,HE_lbk_test_mod= %0h,req_len=%0h,tput_intr=%0h",rxreq_he_lbk_cont_mode,rxreq_he_lbk_test_mode,rxreq_he_lbk_req_len,rxreq_he_lbk_tput_intr ),UVM_LOW)
        `endif
      `endif
      end else if((rxreq_host_addr_64==he_lb_addr+32'h140)&&(rxreq_tdata[31:29]==3))begin   //HE_LBK 
     `ifndef ENABLE_SOC_HOST_COVERAGE
       rxreq_he_lbk_cfg_64 =rxreq_tdata[319:256];
      `ifdef ENABLE_COV_MSG
        `uvm_info("INTF", $sformatf("RXREQ::HE_bk_config_64= %0h",rx_he_lbk_cfg_64 ),UVM_LOW)//
      `endif
      rxreq_he_lbk_cont_mode=rxreq_he_lbk_cfg_64[1];
      rxreq_he_lbk_test_mode=rxreq_he_lbk_cfg_64[4:2];
      rxreq_he_lbk_req_len  =rxreq_he_lbk_cfg_64[6:5];
      rxreq_he_lbk_tput_intr=rxreq_he_lbk_cfg_64[22:20];
      `ifdef ENABLE_COV_MSG
        `uvm_info("INTF", $sformatf("RXREQ::HE_lbk_cont_mode=%0h,HE_lbk_test_mod= %0h,req_len=%0h,tput_intr=%0h",rxreq_he_lbk_cont_mode,rxreq_he_lbk_test_mode,rxreq_he_lbk_req_len,rxreq_he_lbk_tput_intr ),UVM_LOW)
      `endif
      `endif
    
    end else if((rxreq_host_addr_h==he_lb_addr+32'h138)&&(rxreq_tdata[31:29]==2))begin    //CTL for HE_LBK (138)
     `ifndef ENABLE_SOC_HOST_COVERAGE
      rxreq_he_lbk_ctl=rxreq_tdata[287:256];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RXREQ::HE_lbk_CTL= %0h",rxreq_he_lbk_ctl ),UVM_LOW)
 `endif
      rxreq_he_lbk_forcdcmpl=rxreq_he_lbk_ctl[2];
      rxreq_he_lbk_Start    =rxreq_he_lbk_ctl[1];  
      rxreq_he_lbk_ResetL   =rxreq_he_lbk_ctl[0];  
 `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("forcedcmpl= %0h",rxreq_he_lbk_forcdcmpl ),UVM_LOW)
 `endif
 `endif

  end else if((rxreq_host_addr_64==he_lb_addr+ 32'h138)&&(rxreq_tdata[31:29]==3))begin    //CTL for HE_LBK (138)
     `ifndef ENABLE_SOC_HOST_COVERAGE
      rxreq_he_lbk_ctl_64 =rxreq_tdata[319:256];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RXREQ::HE_lbk_CTL_64= %0h",rxreq_he_lbk_ctl_64 ),UVM_LOW)
 `endif
      rxreq_he_lbk_forcdcmpl=rxreq_he_lbk_ctl_64[2];
      rxreq_he_lbk_Start    =rxreq_he_lbk_ctl_64[1];  
      rxreq_he_lbk_ResetL   =rxreq_he_lbk_ctl_64[0]; 

 `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("forcedcmpl= %0h",rxreq_he_lbk_forcdcmpl ),UVM_LOW)
 `endif
 `endif

end else if((rxreq_host_addr_h==he_mem_addr+32'h140)&&(rxreq_tdata[31:29]==2))begin   //HE_MEM 
     rxreq_he_mem_cfg=rxreq_tdata[287:256];
      `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RXREQ::HE_MEM_config= %0h",rxreq_he_mem_cfg ),UVM_LOW)
 `endif
      rxreq_he_mem_cont_mode=rxreq_he_mem_cfg[1];
      rxreq_he_mem_test_mode=rxreq_he_mem_cfg[4:2];
      rxreq_he_mem_req_len  =rxreq_he_mem_cfg[6:5];
      rxreq_he_mem_tput_intr=rxreq_he_mem_cfg[22:20];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RXREQ::he_mem_cont_mode=%0h,he_mem_test_mod= %0h,req_len=%0h,tput_intr=%0h",rxreq_he_mem_cont_mode,rxreq_he_mem_test_mode,rxreq_he_mem_req_len,rxreq_he_mem_tput_intr ),UVM_LOW)
 `endif
 end else if((rxreq_host_addr_64==he_mem_addr+32'h140)&&(rxreq_tdata[31:29]==3))begin   //HE_MEM
      rxreq_he_mem_cfg_64 =rxreq_tdata[319:256];
      `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RXREQ::HE_MEM_config_64= %0h",rxreq_he_mem_cfg_64 ),UVM_LOW)
 `endif
      rxreq_he_mem_cont_mode=rxreq_he_mem_cfg_64[1];
      rxreq_he_mem_test_mode=rxreq_he_mem_cfg_64[4:2];
      rxreq_he_mem_req_len  =rxreq_he_mem_cfg_64[6:5];
      rxreq_he_mem_tput_intr=rxreq_he_mem_cfg_64[22:20];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RXREQ::he_mem_cont_mode=%0h,he_mem_test_mod= %0h,req_len=%0h,tput_intr=%0h",rxreq_he_mem_cont_mode,rxreq_he_mem_test_mode,rxreq_he_mem_req_len,rxreq_he_mem_tput_intr ),UVM_LOW)
 `endif

     
    end else if((rxreq_host_addr_h==he_mem_addr+32'h138)&&(rxreq_tdata[31:29]==2))begin    //CTL for HE_MEM (138)
      rxreq_he_mem_ctl=rxreq_tdata[287:256];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RXREQ::he_mem_CTL= %0h",rxreq_he_mem_ctl ),UVM_LOW)
 `endif
      rxreq_he_mem_forcdcmpl=rxreq_he_mem_ctl[2];
      rxreq_he_mem_Start    =rxreq_he_mem_ctl[1];  
      rxreq_he_mem_ResetL   =rxreq_he_mem_ctl[0]; 
 `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("forcedcmpl= %0h",rxreq_he_mem_forcdcmpl ),UVM_LOW)
 `endif

  end else if((rxreq_host_addr_64==he_mem_addr+ 32'h138)&&(rxreq_tdata[31:29]==3))begin    //CTL for HE_MEM (138)
      rxreq_he_mem_ctl_64 =rxreq_tdata[319:256];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RXREQ::he_mem_CTL_64= %0h",rxreq_he_mem_ctl_64 ),UVM_LOW)
 `endif
      rxreq_he_mem_forcdcmpl=rxreq_he_mem_ctl_64[2];
      rxreq_he_mem_Start    =rxreq_he_mem_ctl_64[1]; 
      rxreq_he_mem_ResetL   =rxreq_he_mem_ctl_64[0];

 `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("forcedcmpl= %0h",rxreq_he_mem_forcdcmpl ),UVM_LOW)
 `endif

      end else if((rxreq_host_addr_h==he_hssi_addr+32'h60030)&&(rxreq_tdata[31:29]==2))begin     //HE_HSSI 
       rx_he_hssi_traffic_ctrl_cmd=rxreq_tdata[287:256];
       rx_he_hssi_rd_cmd=rx_he_hssi_traffic_ctrl_cmd[0];
       rx_he_hssi_wr_cmd=rx_he_hssi_traffic_ctrl_cmd[1];
    `ifdef ENABLE_COV_MSG
       `uvm_info("INTF", $sformatf("RXREQ::HE_hssi_traffic_rd_cmd= %0h,HE_hssi_traffic_rd_cmd= %0h",rx_he_hssi_rd_cmd,rx_he_hssi_wr_cmd ),UVM_LOW)
   `endif
        end else if((rxreq_host_addr_h==he_hssi_addr+32'h60040)&&(rxreq_tdata[31:29]==2))begin  
       rx_he_hssi_traffic_ctrl_ch_sel=rxreq_tdata[259:256];
       rx_he_hssi_ch_sel=rx_he_hssi_traffic_ctrl_ch_sel[3:0];
     `ifdef ENABLE_COV_MSG
       `uvm_info("INTF", $sformatf("RXREQ::HE_hssi_traffic_channel_sel= %0h",rx_he_hssi_ch_sel ),UVM_LOW)
   `endif
       end else if((rxreq_host_addr_64==he_hssi_addr+32'h60030)&&(rxreq_tdata[31:29]==3))begin    
       rx_he_hssi_traffic_ctrl_cmd=rxreq_tdata[319:256];
       rx_he_hssi_rd_cmd=rx_he_hssi_traffic_ctrl_cmd[0];
       rx_he_hssi_wr_cmd=rx_he_hssi_traffic_ctrl_cmd[1];
    `ifdef ENABLE_COV_MSG
       `uvm_info("INTF", $sformatf("RXREQ::HE_hssi_traffic_rd_cmd_64= %0h,HE_hssi_traffic_wr_cmd_64= %0h",rx_he_hssi_rd_cmd,rx_he_hssi_wr_cmd ),UVM_LOW)
   `endif
      end else if((rxreq_host_addr_64==he_hssi_addr+32'h60040)&&(rxreq_tdata[31:29]==3))begin  
       rx_he_hssi_traffic_ctrl_ch_sel=rxreq_tdata[259:256];
       rx_he_hssi_ch_sel=rx_he_hssi_traffic_ctrl_ch_sel[3:0];
     `ifdef ENABLE_COV_MSG
       `uvm_info("INTF", $sformatf("RX::HE_hssi_traffic_channel_sel= %0h",rx_he_hssi_ch_sel ),UVM_LOW)
   `endif

end
`endif
endtask
task HOST_rxreq_splitting ; 
//byte 0,1,2,3
 HOST_rxreq_req_fmt   = HOST_rxreq_tdata[31:29];
 HOST_rxreq_req_type  = HOST_rxreq_tdata[28:24];
 HOST_rxreq_fmt_type  ={HOST_rxreq_tdata[31:29],HOST_rxreq_tdata[28:24]};
`ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("RXREQ::Fmt_type= %0h",HOST_rxreq_fmt_type ),UVM_LOW)
  `endif
//*************************************new_update *************************************

if((HOST_rxreq_tdata[31:29]==3)||(HOST_rxreq_tdata[31:29]==1))begin   
 HOST_rxreq_host_addr_64 ={HOST_rxreq_tdata[95:64], HOST_rxreq_tdata[127:96]};   // [95:64] - Host addr [63:32]  [127:96] - Host addr [31:0]
end else if ((HOST_rxreq_tdata[31:29]==2)||(HOST_rxreq_tdata[31:29]==0))begin
 HOST_rxreq_host_addr_h ={HOST_rxreq_tdata[95:64]};   
end

`ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("HOST_RXREQ::Host_Addr= %0h",HOST_rxreq_host_addr_h ),UVM_LOW)
 `uvm_info("INTF", $sformatf("HOST_RXREQ::Host_Addr_64= %0h",HOST_rxreq_host_addr_64 ),UVM_LOW)
`endif




 if(HOST_rxreq_tuser==0)begin  //POWER_USER_MODE
   HOST_rxreq_length_pu  = HOST_rxreq_tdata[9:0];
 end else begin //DATA_MOVER
   rx_length_dm ={rx_tdata[61:50],rx_tdata[9:0],rx_tdata[49:48]}; 
 end
`ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("HOST_RXREQ:::LEN= %0d|| Format=%0d ||TYpe=%0d ", HOST_rxreq_length_1,HOST_rxreq_req_fmt,HOST_rxreq_req_type ),UVM_LOW)
`endif
//byte 4,5,6,7
 HOST_rxreq_length_l    = HOST_rxreq_tdata[49:48];
 HOST_rxreq_length_h    = HOST_rxreq_tdata[61:50];
 HOST_rxreq_host_addr_1 = HOST_rxreq_tdata[63:32];
 rx_tag_dm      = {rx_tdata[23],rx_tdata[19],rx_tdata[47:40]};
//byte 8,9,10,11
`ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("HOST_RXREQ::Host_Addr= %0h",HOST_rxreq_host_addr_h ),UVM_LOW)
`endif
//byte 12,13,14,15
 HOST_rxreq_host_addr_m={HOST_rxreq_tdata[127:96]};
  `ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("HOST_RXREQ::Host_Addr_2= %0h",HOST_rxreq_host_addr_m ),UVM_LOW)
`endif
//byte 16,17,18,19 -->prefix (No need to check)  
//byte 20,21,22,23
 HOST_rxreq_pf_num	 = HOST_rxreq_tdata[162:160];
 HOST_rxreq_vf_num	 = HOST_rxreq_tdata[173:163];
 HOST_rxreq_vf_active    = HOST_rxreq_tdata[174];
 HOST_rxreq_bar_num	 = HOST_rxreq_tdata [178:175]; 
 HOST_rxreq_slot_num     = HOST_rxreq_tdata[183:179];
 HOST_rxreq_MM_mode      = HOST_rxreq_tdata[184];
`ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("HOST_RXREQ::PF_no=%0d ||VF_no=%0d ||VF_active=%0d||slot_no=%0d ||MM_mode=%0d ||bar_no=%0d",HOST_rxreq_pf_num,HOST_rxreq_vf_num,HOST_rxreq_vf_active,HOST_rxreq_slot_num,HOST_rxreq_MM_mode,HOST_rxreq_bar_num ),UVM_LOW)
`endif
//byte 24,25,26,27,28,29,30,31 -->>Reserved
//Byte 32,33,34,35
 HOST_rxreq_data_h=HOST_rxreq_tdata[511:256];
`ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("HOST_RXREQ::DATA_256to511= %0h",HOST_rxreq_data_h ),UVM_LOW)
`endif
//PMCI
    HOST_rx_mctp_len      = HOST_rxreq_tdata[9:0];
    HOST_rx_mctp_msg_code = HOST_rxreq_tdata[39:32];
    HOST_rx_mctp_vdm_code = HOST_rxreq_tdata[79:64];
    HOST_rx_mctp_multi_pkt_seq = HOST_rxreq_tdata[103:102];
//*****************************************completion_RX_Splitting****************************

 HOST_rxreq_cmpl_type   = HOST_rxreq_tdata[31:24];
 HOST_rxreq_cmpl_status = HOST_rxreq_tdata[47:45];
 if(rxreq_tuser==0)begin
   HOST_rxreq_cmpl_len_pu    = HOST_rxreq_tdata[9:0];
 end else begin
   rx_cmpl_len_dm    = {rx_tdata[115:114],rx_tdata[9:0],rx_tdata[113:112]};
   rx_cmpl_tag_dm    = {rx_tdata[127:118]};
 end
`ifdef ENABLE_COV_MSG
 `uvm_info("INTF", $sformatf("RXREQ::::::Compl_len_PU=%0d||comp_len_DM=%0d||comp_type=%0d ||compl_status=%0d",HOST_rxreq_cmpl_len_pu,rx_cmpl_len_dm,HOST_rxreq_cmpl_type,HOST_rxreq_cmpl_status),UVM_LOW)
`endif

`ifdef ENABLE_SOC_HOST_COVERAGE

    if((HOST_rxreq_host_addr_h==he_lb_addr+32'h140)&&(HOST_rxreq_tdata[31:29]==2))begin   //HE_LBK
      rxreq_he_lbk_cfg=HOST_rxreq_tdata[287:256];
      `ifdef ENABLE_COV_MSG
       `uvm_info("INTF", $sformatf("RXREQ::HE_bk_config= %0h",rxreq_he_lbk_cfg ),UVM_LOW)
     `endif
      rxreq_he_lbk_cont_mode=rxreq_he_lbk_cfg[1];
      rxreq_he_lbk_test_mode=rxreq_he_lbk_cfg[4:2];
      rxreq_he_lbk_req_len  =rxreq_he_lbk_cfg[6:5];
      rxreq_he_lbk_tput_intr=rxreq_he_lbk_cfg[22:20];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RXREQ::HE_lbk_cont_mode=%0h,HE_lbk_test_mod= %0h,req_len=%0h,tput_intr=%0h",rxreq_he_lbk_cont_mode,rxreq_he_lbk_test_mode,rxreq_he_lbk_req_len,rxreq_he_lbk_tput_intr ),UVM_LOW)
 `endif
 end else if((HOST_rxreq_host_addr_64==he_lb_addr+32'h140)&&(HOST_rxreq_tdata[31:29]==3))begin   //HE_LBK 
      rxreq_he_lbk_cfg_64 =HOST_rxreq_tdata[319:256];
      `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RXREQ::HE_bk_config_64= %0h",rx_he_lbk_cfg_64 ),UVM_LOW)//
 `endif
      rxreq_he_lbk_cont_mode=rxreq_he_lbk_cfg_64[1];
      rxreq_he_lbk_test_mode=rxreq_he_lbk_cfg_64[4:2];
      rxreq_he_lbk_req_len  =rxreq_he_lbk_cfg_64[6:5];
      rxreq_he_lbk_tput_intr=rxreq_he_lbk_cfg_64[22:20];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RXREQ::HE_lbk_cont_mode=%0h,HE_lbk_test_mod= %0h,req_len=%0h,tput_intr=%0h",rxreq_he_lbk_cont_mode,rxreq_he_lbk_test_mode,rxreq_he_lbk_req_len,rxreq_he_lbk_tput_intr ),UVM_LOW)
 `endif
    
    end else if((HOST_rxreq_host_addr_h==he_lb_addr+32'h138)&&(HOST_rxreq_tdata[31:29]==2))begin    //CTL for HE_LBK (138)
      rxreq_he_lbk_ctl=HOST_rxreq_tdata[287:256];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RXREQ::HE_lbk_CTL= %0h",rxreq_he_lbk_ctl ),UVM_LOW)
 `endif
      rxreq_he_lbk_forcdcmpl=rxreq_he_lbk_ctl[2];
      rxreq_he_lbk_Start    =rxreq_he_lbk_ctl[1];  
      rxreq_he_lbk_ResetL   =rxreq_he_lbk_ctl[0];  
 `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("forcedcmpl= %0h",rxreq_he_lbk_forcdcmpl ),UVM_LOW)
 `endif

  end else if((HOST_rxreq_host_addr_64==he_lb_addr+ 32'h138)&&(HOST_rxreq_tdata[31:29]==3))begin    //CTL for HE_LBK (138)
      rxreq_he_lbk_ctl_64 =HOST_rxreq_tdata[319:256];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("RXREQ::HE_lbk_CTL_64= %0h",rxreq_he_lbk_ctl_64 ),UVM_LOW)
 `endif
      rxreq_he_lbk_forcdcmpl=rxreq_he_lbk_ctl_64[2];
      rxreq_he_lbk_Start    =rxreq_he_lbk_ctl_64[1];  
      rxreq_he_lbk_ResetL   =rxreq_he_lbk_ctl_64[0]; 

 `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("forcedcmpl= %0h",rxreq_he_lbk_forcdcmpl ),UVM_LOW)
 `endif


end
`endif
endtask



 //***********************************he_hssi_coverage********************************************************
   always@(posedge `HE_HSSI_TRAFFIC_CTRL.clk) begin
 traffic_ctrl_ack=`HE_HSSI_TRAFFIC_CTRL.s_traffic_ctrl_ack;
 clk_he_hssi=`HE_HSSI_TRAFFIC_CTRL.clk;
 traffic_ctrl_cmd=`HE_HSSI_TRAFFIC_CTRL.s_traffic_ctrl_cmd[1:0];
 traffic_ctrl_writedata=`HE_HSSI_TRAFFIC_CTRL.s_traffic_ctrl_writedata[31:0];
 traffic_ctrl_readdata=`HE_HSSI_TRAFFIC_CTRL.s_traffic_ctrl_readdata[31:0];
 traffic_ctrl_addr=`HE_HSSI_TRAFFIC_CTRL.s_traffic_ctrl_addr[15:0];
 he_hssi_splitting;
 end

 
 task he_hssi_splitting;
     
     if(traffic_ctrl_ack== 1)begin
                  if(traffic_ctrl_cmd== 2)begin
                      if(traffic_ctrl_addr== 16'h3800)begin
                          rx_he_hssi_tg_num_pkt= traffic_ctrl_writedata[31:0];
         `ifdef ENABLE_COV_MSG
          `uvm_info("INTF", $sformatf("RX::HE_hssi_tg_num_pkt= %0h",rx_he_hssi_tg_num_pkt ),UVM_LOW)
        `endif

      end else if(traffic_ctrl_addr== 16'h3801)begin
                rx_he_hssi_rnd_len= traffic_ctrl_writedata[0];
         `ifdef ENABLE_COV_MSG          
        `uvm_info("INTF", $sformatf("RX::HE_hssi_rnd_len= %0h",rx_he_hssi_rnd_len ),UVM_LOW)
   `endif
     end else if(traffic_ctrl_addr== 16'h3802)begin
                rx_he_hssi_rnd_pld= traffic_ctrl_writedata[0];
         `ifdef ENABLE_COV_MSG
          `uvm_info("INTF", $sformatf("RX::HE_hssi_rnd_payload= %0h",rx_he_hssi_rnd_pld ),UVM_LOW)    
      `endif
    end else if(traffic_ctrl_addr== 16'h380a)begin
       rx_he_hssi_seed0=traffic_ctrl_writedata[31:0];
     `ifdef ENABLE_COV_MSG
      `uvm_info("INTF", $sformatf("RX::HE_hssi_seed0= %0h",rx_he_hssi_seed0),UVM_LOW)
  `endif
    end else if(traffic_ctrl_addr== 16'h380b)begin
       rx_he_hssi_seed1=traffic_ctrl_writedata[31:0];
     `ifdef ENABLE_COV_MSG
      `uvm_info("INTF", $sformatf("RX::HE_hssi_seed1= %0h",rx_he_hssi_seed1),UVM_LOW)
  `endif
    end else if(traffic_ctrl_addr== 16'h380c)begin
       rx_he_hssi_seed2=traffic_ctrl_writedata[27:0];
     `ifdef ENABLE_COV_MSG
      `uvm_info("INTF", $sformatf("RX::HE_hssi_seed2= %0h",rx_he_hssi_seed2 ),UVM_LOW)
      `endif
    end else if(traffic_ctrl_addr== 16'h380d)begin
       rx_he_hssi_pkt_len=traffic_ctrl_writedata[31:0];
    `ifdef ENABLE_COV_MSG
      `uvm_info("INTF", $sformatf("RX::HE_hssi_pkt_len= %0h",rx_he_hssi_pkt_len ),UVM_LOW)
      `endif
    end else if(traffic_ctrl_addr== 16'h3a00)begin
     rx_he_hssi_lbk_en=traffic_ctrl_writedata[0];
    `ifdef ENABLE_COV_MSG
      `uvm_info("INTF", $sformatf("RX::HE_hssi_lbk_enable= %0h",rx_he_hssi_lbk_en ),UVM_LOW)
  `endif

    end else if(traffic_ctrl_addr== 16'h3a01)begin                
       rx_he_hssi_lbk_fifo_almost_full=traffic_ctrl_readdata[0];
       rx_he_hssi_lbk_fifo_almost_empty=traffic_ctrl_readdata[1];
        `ifdef ENABLE_COV_MSG
      `uvm_info("INTF", $sformatf("RX::HE_hssi_lbk_fifo_almost_full= %0h, HE_hssi_lbk_fifo_almost_empty= %0h",rx_he_hssi_lbk_fifo_almost_full,rx_he_hssi_lbk_fifo_almost_empty ),UVM_LOW)
  `endif 
  end
   
  end else if(traffic_ctrl_cmd== 1)begin
      if(traffic_ctrl_addr== 16'h3907)begin
       rx_he_hssi_len_err=traffic_ctrl_readdata[8];
       rx_he_hssi_oversiz_err=traffic_ctrl_readdata[7];
       rx_he_hssi_undsiz_err=traffic_ctrl_readdata[6];
       rx_he_hssi_mac_crc_err=traffic_ctrl_readdata[5];
       rx_he_hssi_phy_err=traffic_ctrl_readdata[4];
       rx_he_hssi_err_valid=traffic_ctrl_readdata[3];
     `ifdef ENABLE_COV_MSG
       `uvm_info("INTF", $sformatf("RX::HE_hssi_len_err= %0h,HE_hssi_oversize_err= %0h,HE_hssi_undersize_err= %0h,HE_hssi_mac_crc_err= %0h,HE_hssi_err_valid= %0h ",rx_he_hssi_len_err,rx_he_hssi_oversiz_err,rx_he_hssi_undsiz_err,rx_he_hssi_mac_crc_err,rx_he_hssi_phy_err,rx_he_hssi_err_valid ),UVM_LOW)
   `endif

end
end
end
   
endtask


//*****************************************Request_TX_Splitting****************************

task HOST_tx_splitting;
   `ifdef ENABLE_SOC_HOST_COVERAGE
 
//BYTE_0,1,2,3-1DW
     HOST_tx_req_fmt   = HOST_tx_tdata[31:29];
     HOST_tx_req_type  = HOST_tx_tdata[28:24];
     HOST_tx_fmt_type  ={HOST_tx_tdata[31:29],HOST_tx_tdata[28:24]};
     HOST_tx_vector_num= HOST_tx_tdata[79:64];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("HOST_TX::Fmt_type= %0h",HOST_tx_fmt_type ),UVM_LOW)
 `endif
     if(HOST_tx_tuser==0)begin //POWER_USER_MODE
       HOST_tx_length_pu  = tx_tdata[9:0];
     end else begin //DATA_MOVER
       HOST_tx_length_dm ={HOST_tx_tdata[61:50],HOST_tx_tdata[9:0],HOST_tx_tdata[49:48]}; // 24 bits
       HOST_tx_tag_dm    ={HOST_tx_tdata[23],HOST_tx_tdata[19],HOST_tx_tdata[47:40]};
     end
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("LEN= %0d|| Format=%0d ||TYpe=%0d ", HOST_tx_length_1,HOST_tx_req_fmt,HOST_tx_req_type ),UVM_LOW)
 `endif
//byte 4,5,6,7
     HOST_tx_length_l    = HOST_tx_tdata[49:48];
     HOST_tx_length_h    = HOST_tx_tdata[61:50];
     HOST_tx_host_addr_1  =HOST_tx_tdata[63:62];
//byte 8,9,10,11
     HOST_tx_host_addr_h ={HOST_tx_tdata[95:64]};
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("Host_Addr= %0h",HOST_tx_host_addr_h ),UVM_LOW)
 `endif
//byte 12,13,14,15
     HOST_tx_host_addr_m={HOST_tx_tdata[127:96]};
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("Host_Addr_2= %0h",HOST_tx_host_addr_m ),UVM_LOW)
 `endif
//byte 20,21,22,23
     HOST_tx_pf_num	= HOST_tx_tdata[162:160];
     HOST_tx_slot_num   = HOST_tx_tdata[183:179];
     HOST_tx_bar_num	= HOST_tx_tdata [191:185];
    `ifdef ENABLE_COV_MSG
    `uvm_info("INTF", $sformatf("PF_no=%0d  ||slot_no=%0d ||bar_no=%0d",HOST_tx_pf_num,tx_slot_num,tx_bar_num ),UVM_LOW)
`endif
//byte 24,25,26,27,28,29,30,31 -->>Reserved
//Byte 32 to 63
     HOST_tx_data_h=HOST_tx_tdata[511:256];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("TX::DATA_256to511= %0h",HOST_tx_data_h ),UVM_LOW)
 `endif
//PMCI
    HOST_tx_mctp_len      = HOST_tx_tdata[9:0];
    HOST_tx_mctp_msg_code = HOST_tx_tdata[39:32];
    HOST_tx_mctp_vdm_code = HOST_tx_tdata[79:64];
    HOST_tx_mctp_multi_pkt_seq = HOST_tx_tdata[103:102];
//*****************************************completion_TX_Splitting****************************
     if(HOST_tx_tuser==0)begin
     HOST_tx_cmpl_len_pu    = HOST_tx_tdata[9:0];
     HOST_tx_cmpl_tag_pu    = HOST_tx_tdata[80:72];
     end else begin
     HOST_tx_cmpl_len_dm    = {HOST_tx_tdata[115:114],HOST_tx_tdata[9:0],HOST_tx_tdata[113:112]};
     end
     HOST_tx_cmpl_type   = HOST_tx_tdata[31:24];;
     HOST_tx_cmpl_status = HOST_tx_tdata[47:45];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("HOST TX::::::Compl_len_PU=%0d||comp_len_DM=%0d||comp_type=%0d ||compl_status=%0d",HOST_tx_cmpl_len_pu,HOST_tx_cmpl_len_dm,HOST_tx_cmpl_type,HOST_tx_cmpl_status),UVM_LOW)
 `endif
 `endif
 
endtask

//*****************************************Request_TX_Splitting****************************

task tx_splitting;
 
//BYTE_0,1,2,3-1DW
     tx_req_fmt   = tx_tdata[31:29];
     tx_req_type  = tx_tdata[28:24];
     tx_fmt_type  ={tx_tdata[31:29],tx_tdata[28:24]};
     tx_vector_num= tx_tdata[79:64];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("TX::Fmt_type= %0h",tx_fmt_type ),UVM_LOW)
 `endif
     if(tx_tuser==0)begin //POWER_USER_MODE
       tx_length_pu  = tx_tdata[9:0];
     end else begin //DATA_MOVER
       tx_length_dm ={tx_tdata[61:50],tx_tdata[9:0],tx_tdata[49:48]}; // 24 bits
       tx_tag_dm    ={tx_tdata[23],tx_tdata[19],tx_tdata[47:40]};
     end
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("LEN= %0d|| Format=%0d ||TYpe=%0d ", tx_length_1,tx_req_fmt,tx_req_type ),UVM_LOW)
 `endif
//byte 4,5,6,7
     tx_length_l    = tx_tdata[49:48];
     tx_length_h    = tx_tdata[61:50];
     tx_host_addr_1  =tx_tdata[63:62];
//byte 8,9,10,11
     tx_host_addr_h ={tx_tdata[95:64]};
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("Host_Addr= %0h",tx_host_addr_h ),UVM_LOW)
 `endif
//byte 12,13,14,15
     tx_host_addr_m={tx_tdata[127:96]};
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("Host_Addr_2= %0h",tx_host_addr_m ),UVM_LOW)
 `endif
//byte 20,21,22,23
     tx_pf_num	= tx_tdata[162:160];
     tx_vf_num	= tx_tdata[173:163];
     tx_vf_active	= tx_tdata[174];
     tx_slot_num = tx_tdata[183:179];
     tx_bar_num	= tx_tdata [191:185];
    `ifdef ENABLE_COV_MSG
    `uvm_info("INTF", $sformatf("PF_no=%0d ||VF_no=%0d||VF_active=%0d ||slot_no=%0d ||bar_no=%0d",tx_pf_num,tx_vf_num,tx_vf_active,tx_slot_num,tx_bar_num ),UVM_LOW)
`endif
//byte 24,25,26,27,28,29,30,31 -->>Reserved
//Byte 32 to 63
     tx_data_h=tx_tdata[511:256];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("TX::DATA_256to511= %0h",tx_data_h ),UVM_LOW)
 `endif
//PMCI
    tx_mctp_len      = tx_tdata[9:0];
    tx_mctp_msg_code = tx_tdata[39:32];
    tx_mctp_vdm_code = tx_tdata[79:64];
    tx_mctp_multi_pkt_seq = tx_tdata[103:102];
//*****************************************completion_TX_Splitting****************************
     if(tx_tuser==0)begin
     tx_cmpl_len_pu    = tx_tdata[9:0];
     tx_cmpl_tag_pu    = tx_tdata[80:72];
     end else begin
     tx_cmpl_len_dm    = {tx_tdata[115:114],tx_tdata[9:0],tx_tdata[113:112]};
     end
     tx_cmpl_type   = tx_tdata[31:24];;
     tx_cmpl_status = tx_tdata[47:45];
    `ifdef ENABLE_COV_MSG
     `uvm_info("INTF", $sformatf("TX::::::Compl_len_PU=%0d||comp_len_DM=%0d||comp_type=%0d ||compl_status=%0d",tx_cmpl_len_pu,tx_cmpl_len_dm,tx_cmpl_type,tx_cmpl_status),UVM_LOW)
 `endif
 
endtask

`ifdef ENABLE_AC_COVERAGE

//*********************************HSSI<->HE_HSSI DATA PATH property************************************************
property HSSI_LOOPBACK_DATA_PATH;
logic [63:0] TEMP_HSSI_TDATA;
   @(posedge HSSI_CLK)
   ((HSSI_RX_TVALID==1,TEMP_HSSI_TDATA = HSSI_RX_TDATA) |-> ##2 ((HE_HSSI_RX_TVALID==1)&&(TEMP_HSSI_TDATA===HE_HSSI_RX_TDATA)));
   
endproperty
HSSI_HE_HSSI_DATA_PATH_property : cover property(HSSI_LOOPBACK_DATA_PATH);
//*********************************FLR Reset property************************************************
/*property flr_reset_he_lpbk;
    @(posedge rx_clk) 
    rx_he_lbk_ResetL |-> ##[0:$] rx_he_lbk_Start ##[0:$] he_lbk_top_reset ##[0:$] !(rx_he_lbk_ResetL) ##[0:$] !(rx_he_lbk_Start) ##[0:$] !(he_lbk_top_reset) ##[0:$] rx_he_lbk_ResetL ##[0:$] rx_he_lbk_Start ;
endproperty

property flr_reset_he_mem;
    @(posedge rx_clk) 
    rx_he_mem_ResetL |-> ##[0:$] rx_he_mem_Start ##[0:$] he_mem_top_reset ##[0:$] !(rx_he_mem_ResetL) ##[0:$] !(rx_he_mem_Start) ##[0:$] !(he_mem_top_reset) ##[0:$] rx_he_mem_ResetL ##[0:$] rx_he_mem_Start ;
endproperty

flr_reset_he_lpbk_property : cover property(flr_reset_he_lpbk);
flr_reset_he_mem_property  : cover property(flr_reset_he_mem);
*/
//***************************************Upstream traffic**********************************************
sequence mx2ho_he_mem;
 ((mx2ho_pfnum== 3'h0) && (mx2ho_valid == 1'h1) && ( mx2ho_vfnum == 11'h0) && (mx2ho_vfactive == 'h1) && (mx2ho_fmttype == 8'h0 ||8'h20 || 8'h40 ||8'h60));
 endsequence

sequence mx2ho_helb;
((mx2ho_pfnum == 3'h2) && (mx2ho_valid == 1'h1) && ( mx2ho_vfnum  == 11'h0) && (mx2ho_vfactive == 'h0) && (mx2ho_fmttype == 8'h0 ||8'h20 || 8'h40 ||8'h60));
  endsequence

property mx2ho_upstream_dm_req;
   @(mx2ho_pfnum )((  mx2ho_valid == 1'h1) throughout ( mx2ho_he_mem ##[0:$] mx2ho_helb));
      endproperty  

property mx2ho_upstream_dm_req1;
   @(mx2ho_pfnum )((  mx2ho_valid== 1'h1) throughout ( mx2ho_helb ##[0:$] mx2ho_he_mem));
 endproperty  

mx2ho_upstream_dm_req_property : cover property(mx2ho_upstream_dm_req);
mx2ho_upstream_dm_req1_property : cover property(mx2ho_upstream_dm_req1);

//********************************************down stream traffic *********************************************************
sequence mx2ho_csr_cmp;
( ((mx2ho_pfnum== 3'h0) && ( mx2ho_vfnum == 11'h0) && (mx2ho_vfactive =='h0) ) || (((mx2ho_pfnum== 3'h0) && ( mx2ho_vfnum == 11'h1) &&( mx2ho_vfactive =='h1) ) || ( (mx2ho_pfnum== 3'h0) && ( mx2ho_vfnum == 11'h2) &&( mx2ho_vfactive =='h1) ) || ((mx2ho_pfnum== 3'h3) && ( mx2ho_vfnum == 11'h0) && (mx2ho_vfactive =='h0) )|| ((mx2ho_pfnum == 3'h4) && ( mx2ho_vfnum == 11'h0) && (mx2ho_vfactive =='h0))) && (mx2ho_valid == 1'h1) && (mx2ho_fmttype == 8'h4a));

endsequence

property mx2ho_downstream_csr_cmp;
   @(mx2ho_pfnum)  mx2ho_csr_cmp ##[0:$] mx2ho_csr_cmp;

 endproperty  

mx2ho_downstream_csr_cmp_property : cover property(mx2ho_downstream_csr_cmp);

`endif

endinterface


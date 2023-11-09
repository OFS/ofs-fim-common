// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//  Coverage Interface for PMCI_SS
//
//-----------------------------------------------------------------------------

interface pf_vf_mux_if;

  `define TOP top_tb.pf_vf_mux_a

   logic [7:0] rx_tdata_fmt_type;
   logic [7:0] tx_tdata_fmt_type;
   
   logic [4:0] rx_tdata_tag_val_5B,tx_tdata_tag_val_5B;
   logic [7:0] rx_tdata_tag_val_8B,tx_tdata_tag_val_8B;
   logic [9:0] rx_tdata_tag_val_10B,tx_tdata_tag_val_10B;


 covergroup AXI_ST_RX @(posedge top_tb.clk); 
   RX_PF_NUM_VAL : coverpoint `TOP.ho2mx_rx_port.tdata[162:160] iff (`TOP.ho2mx_rx_port.tvalid ==1 && `TOP.ho2mx_rx_port.tready ==1) {bins b_pf_num[] = {[0:7]};}
   RX_VF_NUM_VAL : coverpoint `TOP.ho2mx_rx_port.tdata[173:163] iff (`TOP.ho2mx_rx_port.tvalid ==1 && `TOP.ho2mx_rx_port.tready ==1) {bins b_vf_num_random = {[1:2046]};
                                                                                                                                      bins b_vf_num[] = {0,2047};
                                                                                                                                     }
   RX_PF_X_VF_NUM_VAL: cross RX_PF_NUM_VAL , RX_VF_NUM_VAL;
   RX_LENGTH_VAL: coverpoint `TOP.ho2mx_rx_port.tdata[9:0] iff (`TOP.ho2mx_rx_port.tvalid ==1 && `TOP.ho2mx_rx_port.tready ==1) {bins b_length_0to7 = {[0:7]};
                                                                                                                                 bins b_length_9to23 = {[9:23]};
                                                                                                                                 bins b_length_25to39 = {[25:39]};
                                                                                                                                 bins b_length_41to55 = {[41:55]};
                                                                                                                                 bins b_length_57to63 = {[57:63]};
                                                                                                                                 bins b_length[] = {8,24,40,56,64};
                                                                                                                                }
   RX_FMT_TYPE_VAL: coverpoint rx_tdata_fmt_type iff (`TOP.ho2mx_rx_port.tvalid ==1 && `TOP.ho2mx_rx_port.tready ==1) {bins b_fmt_type_1[] = {'h0,'h20,'h40,'h60,'h4A};                                                                                                                       
                                                                                                                       ignore_bins b_fmt_type_2[] = {['h70:'h75]};
                                                                                                                      } 
   RX_TAG_VAL_5B: coverpoint  rx_tdata_tag_val_5B iff (`TOP.ho2mx_rx_port.tvalid ==1 && `TOP.ho2mx_rx_port.tready ==1 && `TOP.ho2mx_rx_port.tdata[23]==0 && `TOP.ho2mx_rx_port.tdata[19]==0 && `TOP.ho2mx_rx_port.tdata[47:45] ==0) {bins tag_5B = {[5'h0:5'h1F]};}

   RX_TAG_VAL_8B: coverpoint rx_tdata_tag_val_8B iff (`TOP.ho2mx_rx_port.tvalid ==1 && `TOP.ho2mx_rx_port.tready ==1 && `TOP.ho2mx_rx_port.tdata[23]==0 && `TOP.ho2mx_rx_port.tdata[19]==0) {bins tag_8B = {[8'h0:8'hFF]};}
   RX_TAG_VAL_10B: coverpoint rx_tdata_tag_val_10B iff (`TOP.ho2mx_rx_port.tvalid ==1 && `TOP.ho2mx_rx_port.tready ==1) {bins tag_10B = {[10'h0:10'h3FF]};}
                                                                                                                                   
 endgroup

covergroup AXI_ST_TX @(posedge top_tb.clk); 
   TX_PF_NUM_VAL : coverpoint `TOP.mx2ho_tx_port.tdata[162:160] iff (`TOP.mx2ho_tx_port.tvalid ==1 && `TOP.mx2ho_tx_port.tready ==1) {bins b_pf_num[] = {[0:7]};}
   TX_VF_NUM_VAL : coverpoint `TOP.mx2ho_tx_port.tdata[173:163] iff (`TOP.mx2ho_tx_port.tvalid ==1 && `TOP.mx2ho_tx_port.tready ==1) {bins b_vf_num_random = {[1:2046]};
                                                                                                                                      bins b_vf_num[] = {0,2047};
                                                                                                                                     }
   TX_PF_X_VF_NUM_VAL: cross TX_PF_NUM_VAL , TX_VF_NUM_VAL;
   TX_LENGTH_VAL: coverpoint `TOP.mx2ho_tx_port.tdata[9:0] iff (`TOP.mx2ho_tx_port.tvalid ==1 && `TOP.mx2ho_tx_port.tready ==1) {bins b_length_0to7 = {[0:7]};
                                                                                                                                 bins b_length_9to23 = {[9:23]};
                                                                                                                                 bins b_length_25to39 = {[25:39]};
                                                                                                                                 bins b_length_41to55 = {[41:55]};
                                                                                                                                 bins b_length_57to63 = {[57:63]};
                                                                                                                                 bins b_length[] = {8,24,40,56,64};
                                                                                                                                }
                                                                                                                                      
   TX_FMT_TYPE_VAL: coverpoint tx_tdata_fmt_type iff (`TOP.mx2ho_tx_port.tvalid ==1 && `TOP.mx2ho_tx_port.tready ==1) {bins b_fmt_type_1[] = {'h0,'h20,'h40,'h60,'h4A};
                                                                                                                       ignore_bins b_fmt_type_2[] = {['h70:'h75]};
                                                                                                                      } 

   TX_TAG_VAL_5B: coverpoint tx_tdata_tag_val_5B iff (`TOP.mx2ho_tx_port.tvalid ==1 && `TOP.mx2ho_tx_port.tready ==1 && `TOP.mx2ho_tx_port.tdata[23]==0 && `TOP.mx2ho_tx_port.tdata[19]==0 && `TOP.mx2ho_tx_port.tdata[47:45] ==0) {bins tag_5B = {[5'h0:5'h1F]};}

   TX_TAG_VAL_8B: coverpoint tx_tdata_tag_val_8B iff (`TOP.mx2ho_tx_port.tvalid ==1 && `TOP.mx2ho_tx_port.tready ==1 && `TOP.mx2ho_tx_port.tdata[23]==0 && `TOP.mx2ho_tx_port.tdata[19]==0 ) {bins tag_8B = {[8'h0:8'hFF]};}
   TX_TAG_VAL_10B: coverpoint tx_tdata_tag_val_10B iff (`TOP.mx2ho_tx_port.tvalid ==1 && `TOP.mx2ho_tx_port.tready ==1) {bins tag_10B= {[10'h0:10'h3FF]};}
                                                                                                                               
 endgroup

covergroup ERROR @(posedge top_tb.clk);
  OUT_FIFO_ERR_ASSERT : coverpoint `TOP.out_fifo_err {bins fifo_err[] = {1};}
endgroup 

 
 always@(negedge `TOP.ho2mx_rx_port.tlast)
 begin
       rx_tdata_fmt_type = `TOP.ho2mx_rx_port.tdata[31:24];
 end

 always@(negedge `TOP.mx2ho_tx_port.tlast)
 begin
       tx_tdata_fmt_type = `TOP.mx2ho_tx_port.tdata[31:24];
 end

always@(posedge top_tb.clk)
begin
      rx_tdata_tag_val_5B = `TOP.ho2mx_rx_port.tdata[44:40];
end

always@(posedge top_tb.clk)
begin
      rx_tdata_tag_val_8B = `TOP.ho2mx_rx_port.tdata[47:40];
end

always@(posedge top_tb.clk)
begin
      rx_tdata_tag_val_10B = {`TOP.ho2mx_rx_port.tdata[23],`TOP.ho2mx_rx_port.tdata[19],`TOP.ho2mx_rx_port.tdata[44:40]};
end

always@(posedge top_tb.clk)
begin
      tx_tdata_tag_val_5B = `TOP.mx2ho_tx_port.tdata[44:40];
end

always@(posedge top_tb.clk)
begin
      tx_tdata_tag_val_8B = `TOP.mx2ho_tx_port.tdata[47:40];
end

always@(posedge top_tb.clk)
begin
      tx_tdata_tag_val_10B = {`TOP.mx2ho_tx_port.tdata[23],`TOP.mx2ho_tx_port.tdata[19],`TOP.mx2ho_tx_port.tdata[44:40]};
end

 AXI_ST_RX axi_st_rx_1 = new();
 AXI_ST_TX axi_st_tx_1 = new();
 ERROR fifo_err_1 = new();

endinterface

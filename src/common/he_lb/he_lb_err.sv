// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// -----------------------------------------------------------------------------
// Create Date  : June 2021
// Module Name  : he_lb_err.sv
// Project      : OFS 
// -----------------------------------------------------------------------------

import pcie_ss_hdr_pkg::*;
import prtcl_chkr_pkg::*;
import pcie_ss_pkg::*;

module he_lb_err
(
input                   clk,
input                   SoftReset ,
pcie_ss_axis_if           axi_tx_if,
pcie_ss_axis_if.source    axi_tx_if_err,
t_prtcl_chkr_err_vector   error_inj
);

PCIe_PUCplHdr_t         axi_tx_pu_cpl , axi_tx_pu_cpl_q , axi_tx_err_pu_cpl;
PCIe_ReqHdr_t           axi_tx_dm_req , axi_tx_dm_req_q , axi_tx_err_dm_req;
PCIe_PUReqHdr_t         axi_tx_pu_req , axi_tx_pu_req_q , axi_tx_err_pu_req;
logic axi_tx_hdr_is_pu_mode, axi_tx_hdr_is_pu_mode_q ;
logic [23:0]  axi_tx_length ,axi_tx_length_T1 ,axi_err_tx_length;
pcie_ss_axis_if  axi_tx_q(), axi_tx_if_q();
pcie_ss_axis_if axi_tx_if_err_q();
logic axi_tx_mwr , axi_tx_mwr_q  ;
logic axi_tx_mrd , axi_tx_mrd_q  ;
logic axi_tx_cpld , axi_tx_cpld_q ;
logic axi_tx_cpl , axi_tx_cpl_q  ;
logic  mmio_rsp_q='b0, prev_mmio_rsp ='b0, ready_deassert_valid ='b0;
logic axi_tx_qq_tready ='b0; 
logic [7:0]   axi_tx_err_fmttype;

assign  axi_tx_q.tready = axi_tx_if_err.tready;
    ofs_fim_axis_pipeline #(
         .TDATA_WIDTH(ofs_pcie_ss_cfg_pkg::TDATA_WIDTH),
         .TUSER_WIDTH(ofs_pcie_ss_cfg_pkg::TUSER_WIDTH),
         .PL_DEPTH(1) )
    axi_tx_if_q_port (
        .clk            ( clk          ),
        .rst_n          (   SoftReset  ),
        .axis_s         ( axi_tx_if    ),
        .axis_m         ( axi_tx_q  )
    );

always_ff @ (posedge clk)
begin
 axi_tx_qq_tready         <=  axi_tx_q.tready;
 axi_tx_length_T1        <=  axi_tx_length ;
 ready_deassert_valid          <= (!axi_tx_q.tready & axi_tx_qq_tready)  & axi_tx_q.tvalid;

 if(mmio_rsp_q) 
  begin
  axi_tx_if_err_q.tvalid       <= axi_tx_q.tvalid      ;
  axi_tx_if_err_q.tlast        <= axi_tx_q.tlast       ;
  axi_tx_if_err_q.tuser_vendor <= axi_tx_q.tuser_vendor;
  axi_tx_if_err_q.tdata        <= axi_tx_q.tdata       ;
  axi_tx_if_err_q.tkeep        <= axi_tx_q.tkeep       ;
  prev_mmio_rsp                <= 1'b1 ;
    end
 else 
  begin
    axi_tx_if_err_q.tvalid       <= 'h0;
    axi_tx_if_err_q.tlast        <= 'h0;
    axi_tx_if_err_q.tuser_vendor <= 'h0;
    axi_tx_if_err_q.tdata        <= 'h0;
    axi_tx_if_err_q.tkeep        <= 'h0;
   end 
end

always_comb
begin  
    axi_tx_pu_cpl = axi_tx_if.tdata[255:0];    
    axi_tx_dm_req = axi_tx_if.tdata[255:0];
    axi_tx_pu_req = axi_tx_if.tdata[255:0];

    axi_tx_pu_cpl_q = axi_tx_q.tdata[255:0];    
    axi_tx_dm_req_q = axi_tx_q.tdata[255:0];
    axi_tx_pu_req_q = axi_tx_q.tdata[255:0];

    axi_tx_err_dm_req = axi_tx_q.tdata[255:0];
    axi_tx_err_pu_req = axi_tx_q.tdata[255:0];
    axi_tx_err_pu_cpl = axi_tx_q.tdata[255:0];

    axi_tx_if_err.tvalid        = axi_tx_q.tvalid      ;      
    axi_tx_if_err.tlast         = axi_tx_q.tlast      ;    
    axi_tx_if_err.tuser_vendor  = axi_tx_q.tuser_vendor       ;
    axi_tx_if_err.tdata         = axi_tx_q.tdata;    
    axi_tx_if_err.tkeep         = axi_tx_q.tkeep       ;    
    

    axi_tx_hdr_is_pu_mode  = pcie_ss_hdr_pkg::func_hdr_is_pu_mode(axi_tx_if.tuser_vendor);
    axi_tx_hdr_is_pu_mode_q  = pcie_ss_hdr_pkg::func_hdr_is_pu_mode(axi_tx_q.tuser_vendor);
    axi_tx_mwr_q             =  axi_tx_hdr_is_pu_mode_q ? ((axi_tx_pu_req_q.fmt_type == DM_WR) |(axi_tx_pu_req_q.fmt_type == M_WR)):(axi_tx_dm_req_q.fmt_type == DM_WR);                                
    axi_tx_mrd_q             =  axi_tx_hdr_is_pu_mode_q ? ((axi_tx_pu_req_q.fmt_type == DM_RD) |(axi_tx_pu_req_q.fmt_type == M_RD)):(axi_tx_dm_req_q.fmt_type == DM_RD);    
    axi_tx_cpld_q            = (axi_tx_pu_cpl_q.fmt_type == pcie_ss_hdr_pkg::PCIE_FMTTYPE_CPLD);
    axi_tx_cpl_q             = (axi_tx_pu_cpl_q.fmt_type == pcie_ss_hdr_pkg::PCIE_FMTTYPE_CPL);
    mmio_rsp_q               = axi_tx_q.tvalid && axi_tx_q.tready && (axi_tx_cpl_q | axi_tx_cpld_q) & axi_tx_hdr_is_pu_mode_q; 
    axi_tx_length          = axi_tx_hdr_is_pu_mode ? 
                            axi_tx_pu_req.length << 2 :  //DW to Bytes
                             {axi_tx_dm_req.length_h, 
                              axi_tx_dm_req.length_m, 
                              axi_tx_dm_req.length_l};

                             

//===============================================================================================
// TxValidViolation Inj : AFU drops the valid signal when ready is de-asserted.
//===============================================================================================
  if(error_inj.tx_valid_violation & (axi_tx_mwr_q | axi_tx_mrd_q)) //explicitly doing for rd/wr transactions, else we trigger unintentional mmio_timeout 
   axi_tx_if_err.tvalid = ((!axi_tx_q.tready & axi_tx_q.tvalid) & ready_deassert_valid) ? 'b0 : axi_tx_q.tvalid;

//===============================================================================================
// MWr Insufficient Data Error Inj : The number of data payload sent by AFU for a memory write request is less than the data length specified in the request.
//===============================================================================================
  if(error_inj.tx_mwr_insufficient_data )
   begin
     axi_err_tx_length = axi_tx_length_T1 - 1'b1; 
   
   if(~(axi_tx_cpl_q | axi_tx_cpld_q) & axi_tx_mwr_q)
   begin
     if (axi_tx_hdr_is_pu_mode_q )
     axi_tx_err_pu_req.length = axi_err_tx_length >>2;
     else 
      {axi_tx_err_dm_req.length_h , axi_tx_err_dm_req.length_m , axi_tx_err_dm_req.length_l } = axi_err_tx_length; 
   end
   
     axi_tx_if_err.tdata = axi_tx_hdr_is_pu_mode_q ? axi_tx_err_pu_req : axi_tx_err_dm_req;
end 

//===============================================================================================
// MWr Overrun : The number of data payload sent by AFU for a memory write request is more than the data length specified in the request.
//===============================================================================================
  if(error_inj.tx_mwr_data_payload_overrun )
    begin
      axi_err_tx_length = axi_tx_length_T1 + 1'b1; 
    
  if(~(axi_tx_cpl_q | axi_tx_cpld_q) & axi_tx_mwr_q)
   begin
    if (axi_tx_hdr_is_pu_mode_q )
    axi_tx_err_pu_req.length = axi_err_tx_length >>2;
    else 
   {axi_tx_err_dm_req.length_h , axi_tx_err_dm_req.length_m , axi_tx_err_dm_req.length_l } = axi_err_tx_length; 
  end
      axi_tx_if_err.tdata = axi_tx_hdr_is_pu_mode_q ? axi_tx_err_pu_req : axi_tx_err_dm_req;
    end 

//===============================================================================================
// MMIO Insufficient Data Error Inj : The number of data payload sent by AFU for a MMIO response (cplD) is less than the data length specified in the response.
//===============================================================================================
  if(error_inj.mmio_insufficient_data)
    begin
     if(mmio_rsp_q)
     axi_tx_err_pu_cpl.byte_count = axi_tx_err_pu_cpl.byte_count -3'h4; 
     axi_tx_if_err.tdata = axi_tx_err_pu_cpl;
    end 

//===============================================================================================
//MMIO DataPayloadOverrun Inj : The number of data payload sent by AFU for a MMIO response (cplD) is more than the data length specified in the response.
//===============================================================================================

  if(error_inj.mmio_data_payload_overrun   )
    begin
     if(mmio_rsp_q)
     axi_tx_err_pu_cpl.length = axi_tx_err_pu_cpl.length - 3'h1; 
     axi_tx_if_err.tdata = axi_tx_err_pu_cpl;
    end 

//===============================================================================================
//MMIOTimedOut Inj: AFU is not responding to a MMIO read request within the pre-defined response timeout period
//===============================================================================================
 
  if(error_inj.mmio_timeout      )
   axi_tx_if_err.tvalid = mmio_rsp_q ?  'b0 : axi_tx_q.tvalid ;

//===============================================================================================
//UnexpMMIOResp Inj : AFU is sending a MMIO read response with no matching MMIO read request
//===============================================================================================

  if(error_inj.unexp_mmio_rsp)
    begin
    if (!axi_tx_q.tvalid & axi_tx_if_err.tready & prev_mmio_rsp)
     begin
     axi_tx_if_err.tvalid       = axi_tx_if_err_q.tvalid       ;
     axi_tx_if_err.tlast        = axi_tx_if_err_q.tlast        ;
     axi_tx_if_err.tuser_vendor = axi_tx_if_err_q.tuser_vendor ;
     axi_tx_if_err.tdata        = axi_tx_if_err_q.tdata        ;
     axi_tx_if_err.tkeep        = axi_tx_if_err_q.tkeep        ;
     end
    end


//if(error_inj.unaligned_addr    )

//===============================================================================================
// Tag Occupied Error Inj- AFU sends out memory read request using a tag that is already used for a 
//                      pending memory read request
//===============================================================================================

if(error_inj.tag_occupied  & axi_tx_mrd_q    )
begin
    if (axi_tx_hdr_is_pu_mode_q ) begin
      axi_tx_err_pu_req.tag_l = 8'h2;
      axi_tx_err_pu_req.tag_m = 1'b0;
      axi_tx_err_pu_req.tag_h = 1'b0;
    end 
  else   begin
    axi_tx_err_dm_req.tag_l = 8'h2;
    axi_tx_err_dm_req.tag_m = 1'b0;
    axi_tx_err_dm_req.tag_h = 1'b0;
  end

  axi_tx_if_err.tdata = axi_tx_hdr_is_pu_mode_q ? axi_tx_err_pu_req : axi_tx_err_dm_req;
end

//===============================================================================================
//MaxTagError Inj : AFU memory read request tag value exceeds the maximum supported tag count
//===============================================================================================

  if(error_inj.max_tag  & axi_tx_mrd_q          )
  begin
      if (axi_tx_hdr_is_pu_mode_q ) begin
        axi_tx_err_pu_req.tag_h = 1'b1;
        axi_tx_err_pu_req.tag_m = 1'b0;
        axi_tx_err_pu_req.tag_l = 8'd33;
      end 
    else   begin
      axi_tx_err_dm_req.tag_h = 1'b1;
      axi_tx_err_dm_req.tag_m = 1'b0;
      axi_tx_err_dm_req.tag_l = 8'd33;
    end
  
    axi_tx_if_err.tdata = axi_tx_hdr_is_pu_mode_q ? axi_tx_err_pu_req : axi_tx_err_dm_req;
  end

//===============================================================================================
//MaxReadReqSizeError Inj : AFU memory read payload size exceeds max_read_request_size limit
//===============================================================================================

  if(error_inj.max_read_req_size & axi_tx_mrd_q )
  begin
       axi_err_tx_length = 24'd544 ; 
     
     if (axi_tx_hdr_is_pu_mode_q )
     axi_tx_err_pu_req.length = axi_err_tx_length >>2;
     else 
      {axi_tx_err_dm_req.length_h , axi_tx_err_dm_req.length_m , axi_tx_err_dm_req.length_l } = axi_err_tx_length; 
     
       axi_tx_if_err.tdata = axi_tx_hdr_is_pu_mode_q ? axi_tx_err_pu_req : axi_tx_err_dm_req;
  end 

//===============================================================================================
//MaxPayloadError Inj : AFU memory write payload size exceeds max_payload_length limit
//===============================================================================================
 
  if(error_inj.max_payload & axi_tx_mwr_q    )
   begin
       axi_err_tx_length = 24'd544 ; 
     
     if (axi_tx_hdr_is_pu_mode_q )
     axi_tx_err_pu_req.length = axi_err_tx_length >>2;
     else 
      {axi_tx_err_dm_req.length_h , axi_tx_err_dm_req.length_m , axi_tx_err_dm_req.length_l } = axi_err_tx_length; 
     
       axi_tx_if_err.tdata = axi_tx_hdr_is_pu_mode_q ? axi_tx_err_pu_req : axi_tx_err_dm_req;
   end 

//===============================================================================================
//MalformedTLP Inj : AFU PCIe TLP contains unsupported format type
//===============================================================================================

if (error_inj.malformed_tlp     )
 begin
  axi_tx_err_fmttype = 8'h43 ;
  axi_tx_if_err.tdata[31:24] = axi_tx_err_fmttype;
 end

end 
 endmodule :he_lb_err

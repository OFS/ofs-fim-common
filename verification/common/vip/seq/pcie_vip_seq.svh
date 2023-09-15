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

`ifndef PCIE_RD_MMIO_SEQ_SVH
`define PCIE_RD_MMIO_SEQ_SVH
    //`include "VIP/vip_defines.sv"

class pcie_rd_mmio_seq extends `PCIE_DRIVER_TRANSACTION_BASE_SEQ_CLASS;

    rand bit [63:0] rd_addr;
    rand bit [31:0] wr_payload[];
    rand bit [9:0]  rlen;
    rand bit [3:0]  l_dw_be;
    rand int        wsize;
    rand bit        block;
    string          msgid;
    `PCIE_DRIVER_TRANSACTION_CLASS write_tran, read_tran;

    `uvm_object_utils_begin(pcie_rd_mmio_seq)
          `uvm_field_int(rd_addr, UVM_DEFAULT)
          `uvm_field_array_int(wr_payload, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "pcie_rd_mmio_seq");
        super.new(name);
        wr_payload    =  new[wsize];
        msgid=get_type_name();
    endfunction 

    virtual task body();
        
        `uvm_create(read_tran)

        read_tran.transaction_type = `PCIE_DRIVER_TRANSACTION_CLASS::MEM_RD;
        read_tran.address = rd_addr;
        read_tran.length =  rlen;
        read_tran.traffic_class = 0;
        read_tran.address_translation = 0;
        read_tran.first_dw_be   = 4'b1111;
        read_tran.last_dw_be    = l_dw_be;
        read_tran.ep = 0;
        read_tran.th = 0;
        read_tran.block = block;
        read_tran.payload             = new[read_tran.length]; 

        `uvm_send(read_tran)

        get_response(read_tran);

        foreach(wr_payload[i]) begin
            if(wr_payload[i] === read_tran.payload[i]) begin
                `uvm_info(msgid,$psprintf("Shalini000: Read and write data match. read_data: %0h write_data: %0h len  gth :    %d",read_tran.payload[i], wr_payload[i],rlen) , UVM_HIGH);
            end
            else
                `uvm_error(get_full_name(), $psprintf("Shalini111:Read and write date doesn't match. read_data: %0h   wri t   e_data: %0h", read_tran.payload[i], wr_payload[i]));
        end

    endtask: body
endclass: pcie_rd_mmio_seq

class pcie_wr_mmio_seq extends `PCIE_DRIVER_TRANSACTION_BASE_SEQ_CLASS;

    rand bit [63:0] wr_addr;
    rand bit [31:0] wr_payload[2];
    rand bit [9:0]  wrlen;
    rand bit [3:0]  f_dw_be;
    rand bit [3:0]  l_dw_be;
    rand int        wsize;
    string          msgid;
    `PCIE_DRIVER_TRANSACTION_CLASS write_tran, read_tran;

    `uvm_object_utils_begin(pcie_wr_mmio_seq)
          `uvm_field_int(wr_addr, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "pcie_wr_mmio_seq");
        super.new(name);
        msgid=get_type_name();
    endfunction 

    virtual task body();
        
        `uvm_create(write_tran)

        write_tran.transaction_type = `PCIE_DRIVER_TRANSACTION_CLASS::MEM_WR;
        write_tran.address = wr_addr;
        write_tran.length =  wrlen;
        write_tran.traffic_class = 0;
        write_tran.address_translation = 0;
        write_tran.first_dw_be   = 4'b1111;
        write_tran.last_dw_be    = l_dw_be;
        write_tran.ep = 0;
        write_tran.th = 0;
        write_tran.block = 0;
        write_tran.payload             = new[write_tran.length];
        foreach (write_tran.payload[i]) begin
          write_tran.payload[i]        = wr_payload[i];
        end
        //write_tran.write_payload[0]             = wr_payload[0]; 
        //write_tran.write_payload[1]             = wr_payload[1]; 

        `uvm_send(write_tran)

    endtask: body
endclass: pcie_wr_mmio_seq

 //class host_pcie_mem_write_seq extends `PCIE_MEM_TARGET_BASE_SEQ;
 class host_pcie_mem_write_seq extends `PCIE_MEM_TARGET_RD_WR_SEQ;
   rand bit [63:0] address;
   rand int unsigned dword_length;
   rand bit [31:0]      data_seq[];
    string          msgid;
   `PCIE_MEM_SERV wr_trans;


 //constraint a1_size_c { data_.size() == dword_length; }

    `uvm_object_utils(host_pcie_mem_write_seq)
     function new(string name = "host_pcie_mem_write_seq");
        super.new(name);
        msgid=get_type_name();
    endfunction

     virtual task body();
    
      foreach(data_seq[i]) begin  `uvm_info(get_name(), $psprintf("HOST_PCIE_MEM_WRITE_RAND_DATA_SEQ[%d] :- %h \n",i,data_seq[i]), UVM_LOW)end
         `uvm_info(get_name(), $psprintf("HOST_PCIE_MEM_WRITE_RAND_DATA_SEQ[] :- Inside mem_write_seq \n"), UVM_LOW)
        `uvm_create(wr_trans)

          wr_trans.service_type      = `PCIE_MEM_SERV ::WRITE_BUFFER;
	  wr_trans.address           = address;
          //foreach (data_[i]) begin  wr_trans.data_buf[i]      =  data_[i]; `uvm_info(get_name(), $psprintf("HOST_PCIE_MEM_WRITE_SENT_RAND_DATA_SEQ[%d] :- %h \n",i,wr_trans.data_buf[i]), UVM_LOW)end
          wr_trans.data_buf = new[dword_length] (this.data_seq);
	  wr_trans.dword_length      =  dword_length;
	  wr_trans.first_byte_enable = 4'hf;
	  wr_trans.last_byte_enable  = 4'hf;
	  wr_trans.byte_enables      = 4'hf;
        
      `uvm_send(wr_trans)
    
     endtask: body
     
 endclass


 class host_pcie_mem_read_seq extends `PCIE_MEM_TARGET_BASE_SEQ;
   rand bit [63:0] address;
   rand int unsigned dword_length;
   bit [31:0]      data_buf[];
    string          msgid;
   `PCIE_MEM_SERV rd_trans;

    `uvm_object_utils(host_pcie_mem_read_seq)
     function new(string name = "host_pcie_mem_read_seq");
        super.new(name);
        msgid=get_type_name();
    endfunction

     virtual task body();
        `uvm_create(rd_trans)

          rd_trans.service_type      = `PCIE_MEM_SERV ::READ_BUFFER;
	  rd_trans.address           = address;
	  rd_trans.dword_length      =  dword_length;
	  rd_trans.first_byte_enable = 4'hf;
	  rd_trans.last_byte_enable  = 4'hf;
	  rd_trans.byte_enables      = 4'hf;
        
       `uvm_send(rd_trans)
        //get_response(rd_trans);
    
        data_buf = new[rd_trans.dword_length] (rd_trans.data_buf);

     endtask: body
     
 endclass




class pcie_vdm_msg_seq extends `PCIE_DRIVER_TRANSACTION_BASE_SEQ_CLASS;

    rand bit [63:0] vendor_fields;
    rand bit [9:0]  vdm_len;
    rand bit [31:0] vdm_payload[16];
    rand bit   routing_type;
    rand bit   fix_payload_en;
    string          msgid;
    `PCIE_DRIVER_TRANSACTION_CLASS vdm_msg_tran;

    `uvm_object_utils(pcie_vdm_msg_seq)

    function new(string name = "pcie_vdm_msg_seq");
        super.new(name);
        msgid=get_type_name();
    endfunction 

    virtual task body();
        
        `uvm_create(vdm_msg_tran)

        vdm_msg_tran.transaction_type = `PCIE_DRIVER_TRANSACTION_CLASS::MSG;
        if(routing_type)begin
          vdm_msg_tran.routing_type = `PCIE_DRIVER_TRANSACTION_CLASS::ROUTE_BY_ID;
        end else begin 
          vdm_msg_tran.routing_type = `PCIE_DRIVER_TRANSACTION_CLASS::BROADCAST_FROM_RC;
        end
        vdm_msg_tran.length       =  vdm_len;
        vdm_msg_tran.traffic_class = 0;
        vdm_msg_tran.payload             = new[vdm_msg_tran.length];
        vdm_msg_tran.vendor_fields = vendor_fields;
        vdm_msg_tran.message_code = `PCIE_DRIVER_TRANSACTION_CLASS::VENDOR_DEFINED_1;
        if(fix_payload_en)begin
          foreach (vdm_msg_tran.payload[i]) begin
            vdm_msg_tran.payload[i]        = vdm_payload[i];
          end
        end

        `uvm_send(vdm_msg_tran)

    endtask: body
endclass: pcie_vdm_msg_seq

class cfg_rd_flr_seq extends `PCIE_DRIVER_TRANSACTION_BASE_SEQ_CLASS;

    rand bit  [63:0]        rd_addr;
    rand bit[31:0] wr_payload[];
    bit [31:0] rd_dev_ctl;
    string msgid;

    `uvm_object_utils_begin(cfg_rd_flr_seq)
    `uvm_field_int(rd_addr, UVM_DEFAULT)
    `uvm_field_array_int(wr_payload, UVM_DEFAULT)
    `uvm_object_utils_end


  function new(string name = "cfg_rd_flr_seq");
     super.new(name);
     wr_payload    =  new[4];
     msgid=get_type_name();
  endfunction 

  virtual task body();
    `PCIE_DRIVER_TRANSACTION_CLASS write_tran, read_tran;

     `uvm_create(read_tran)
      read_tran.cfg                 = cfg;
      read_tran.transaction_type    = `PCIE_DRIVER_TRANSACTION_CLASS::CFG_RD;
      read_tran.address             = rd_addr;
      read_tran.register_number     = 'h1E;
      read_tran.length              = 1;
      read_tran.traffic_class       = 0;
      read_tran.address_translation = 0;
      read_tran.first_dw_be         = 4'b1111;
      read_tran.last_dw_be          = 4'b0000;
      read_tran.ep                  = 0;
      read_tran.block               = 1;
      `uvm_send(read_tran)
      get_response(read_tran);
      rd_dev_ctl = read_tran.payload[0];
      rd_dev_ctl[15] =  1'b1;     
      

  endtask: body
endclass: cfg_rd_flr_seq


class cfg_wr_flr_seq extends `PCIE_DRIVER_TRANSACTION_BASE_SEQ_CLASS;

    rand bit  [63:0]        wr_addr;
    rand bit[31:0] wr_payload[];
    rand bit [31:0] wr_dev_ctl;
    string msgid;

    `uvm_object_utils_begin(cfg_wr_flr_seq)
    `uvm_field_int(wr_addr, UVM_DEFAULT)
    `uvm_field_array_int(wr_payload, UVM_DEFAULT)
    `uvm_object_utils_end


  function new(string name = "cfg_wr_flr_seq");
     super.new(name);
     wr_payload    =  new[4];
     msgid=get_type_name();
  endfunction 

  virtual task body();
     `PCIE_DRIVER_TRANSACTION_CLASS write_tran, read_tran;    
      
     `uvm_create(write_tran)
      write_tran.cfg                 = cfg;
      write_tran.transaction_type    = `PCIE_DRIVER_TRANSACTION_CLASS::CFG_WR;
      write_tran.address             = wr_addr;
      write_tran.register_number     = 'h1E;
      write_tran.length              = 1;
      write_tran.traffic_class       = 0;
      write_tran.address_translation = 0;
      write_tran.first_dw_be         = 4'b1111;
      write_tran.last_dw_be          = 4'b0000;
      write_tran.ep                  = 0;
      write_tran.block               = 1;
      write_tran.payload             = new[write_tran.length];
      foreach (write_tran.payload[i]) begin
      write_tran.payload[i]        = wr_dev_ctl;
      end
      `uvm_send(write_tran)
      get_response(write_tran);

     `uvm_info("msgid", $sformatf("MSI: dev_ctl_wr write 0x%h", wr_dev_ctl), UVM_LOW);

  endtask: body
endclass: cfg_wr_flr_seq


`endif // PCIE_RD_MMIO_SEQ_SVH

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


class axi_master_random_sequence extends `AXI_MASTER_BASE_SEQUENCE;

  /** Parameter that controls the number of transactions that will be generated */
  rand int unsigned sequence_length = 10;

  /** Constrain the sequence length to a reasonable value */
  constraint reasonable_sequence_length {
    sequence_length <= 100;
  }

  /** UVM Object Utility macro */
  `uvm_object_utils(axi_master_random_sequence)

  /** Class Constructor */
  function new(string name="axi_master_random_sequence");
    super.new(name);
  endfunction
  
  virtual task body();
    bit status;
    `uvm_info("body", "Entered ...", UVM_LOW)

    super.body();

    status = uvm_config_db #(int unsigned)::get(null, get_full_name(), "sequence_length", sequence_length);
    `uvm_info("body", $sformatf("sequence_length is %0d as a result of %0s.", sequence_length, status ? "config DB" : "randomization"), UVM_LOW);

     fork
    forever begin
      get_response(rsp);
    end
    join_none
    
    repeat (sequence_length) begin
        `uvm_do_with(req, 
        { 
          stream_burst_length > 0;
          stream_burst_length < 15;
          enable_interleave == 0;
          xact_type == `AXI_TRANSACTION_CLASS::DATA_STREAM; 
        })
        #($urandom_range(2000,0));

    end
    `uvm_info("body", "Exiting...", UVM_LOW)
  endtask: body

endclass: axi_master_random_sequence

class qsfp_axi_derived_read_sequence extends `AXI_MASTER_BASE_SEQUENCE;

 `uvm_object_utils(qsfp_axi_derived_read_sequence)

  /** Address to be written */
  rand bit [31 : 0] addr;

  /** Address to be written */
  rand bit [63 : 0] exp_data;
  bit check_enable = 1; 

  `AXI_TRANSACTION_CLASS::atomic_type_enum atomic_type = `AXI_TRANSACTION_CLASS::NORMAL;

  function new(string name="qsfp_axi_derived_read_sequence");
    super.new(name);
  endfunction

  virtual task body();
    super.body();

    `uvm_do_with(req, {
      xact_type == `AXI_TRANSACTION_CLASS::READ;
      addr == local::addr;
      burst_length == 1;
     //exp_data == this.exp_data;
    })
  
    get_response(rsp);

  if (check_enable) begin
      if (rsp.data.size() != 1) begin
        `uvm_error("body", $sformatf("Unexpected number of data for read to addr=%x.  Expected 1, recreived %0d", addr, rsp.data.size()));
      end
      else if (rsp.data[0] != exp_data) begin
        `uvm_error("body", $sformatf("Data mismatch for read to addr=%x.  Expected %x, received %x", addr, exp_data, rsp.data[0]));
      end
    end


  endtask: body

endclass: qsfp_axi_derived_read_sequence
class qsfp_axi_derived_read_rand_sequence extends `AXI_MASTER_BASE_SEQUENCE;

 `uvm_object_utils(qsfp_axi_derived_read_rand_sequence)

  /** Address to be written */
  rand bit [17 : 0] addr;

  /** Address to be written */
  rand bit [63 : 0] exp_data;
  bit check_enable = 0; 

  `AXI_TRANSACTION_CLASS::atomic_type_enum atomic_type = `AXI_TRANSACTION_CLASS::NORMAL;

  function new(string name="qsfp_axi_derived_read_sequence");
    super.new(name);
  endfunction

  virtual task body();
    super.body();

    `uvm_do_with(req, {
      xact_type == `AXI_TRANSACTION_CLASS::READ;
      addr == local::addr;
      burst_length == 1;
     //exp_data == this.exp_data;
    })
  
    get_response(rsp);

  if (check_enable) begin
      if (rsp.data.size() != 1) begin
        `uvm_error("body", $sformatf("Unexpected number of data for read to addr=%x.  Expected 1, recreived %0d", addr, rsp.data.size()));
      end
      else if (rsp.data[0] != exp_data) begin
        `uvm_error("body", $sformatf("Data mismatch for read to addr=%x.  Expected %x, received %x", addr, exp_data, rsp.data[0]));
      end
    end


  endtask: body

endclass: qsfp_axi_derived_read_rand_sequence


class qsfp_axi_derived_write_sequence extends `AXI_MASTER_BASE_SEQUENCE;

  `uvm_object_utils(qsfp_axi_derived_write_sequence)

  /** Address to be written */
  rand bit [63:0] addr;

  /** Address to be written */
  rand bit [63:0] data;

  /**Write strobe */
  rand bit [7:0] wstrb;


  constraint write_strobe {
    soft wstrb == 8'hFF;
  }

  `AXI_TRANSACTION_CLASS::atomic_type_enum atomic_type = `AXI_TRANSACTION_CLASS::NORMAL;

  function new(string name="qsfp_axi_derived_write_sequence");
    super.new(name);
  endfunction

  virtual task body();
    super.body();

    `uvm_do_with(req, {
      xact_type == `AXI_TRANSACTION_CLASS::WRITE;
      addr == local::addr;
`ifndef INCA
      data.size() == 1;
`else
      req.data.size() == 1;
`endif
      data[0] == local::data;
      atomic_type == local::atomic_type;
      burst_length == 1;
      wstrb[0] ==  local::wstrb;
      wvalid_delay[0] ==0; //to make wvalid and awvalid assert at the same time from VIP
    })
  
    get_response(rsp);
  endtask: body

endclass: qsfp_axi_derived_write_sequence
class hps2ce_axi_derived_read_sequence extends `AXI_MASTER_BASE_SEQUENCE;

 `uvm_object_utils(hps2ce_axi_derived_read_sequence)

  /** Address to be written */
  rand bit [20 : 0] addr;

  /** Address to be written */
  rand bit [31 : 0] exp_data;
  bit check_enable = 1; 

  `AXI_TRANSACTION_CLASS::atomic_type_enum atomic_type = `AXI_TRANSACTION_CLASS::NORMAL;

  function new(string name="hps2ce_axi_derived_read_sequence");
    super.new(name);
  endfunction

  virtual task body();
    super.body();

    `uvm_do_with(req, {
      xact_type == `AXI_TRANSACTION_CLASS::READ;
      addr == local::addr;
      burst_length == 1;
     //exp_data == this.exp_data;
    })
  
    get_response(rsp);

  if (check_enable) begin
      if (rsp.data.size() != 1) begin
        `uvm_error("body", $sformatf("Unexpected number of data for read to addr=%x.  Expected 1, recreived %0d", addr, rsp.data.size()));
      end
      else if (rsp.data[0] != exp_data) begin
        `uvm_error("body", $sformatf("Data mismatch for read to addr=%x.  Expected %x, received %x", addr, exp_data, rsp.data[0]));
      end
    end


  endtask: body

endclass: hps2ce_axi_derived_read_sequence


class hps2ce_axi_derived_write_sequence extends `AXI_MASTER_BASE_SEQUENCE;

  `uvm_object_utils(hps2ce_axi_derived_write_sequence)

  /** Address to be written */
  rand bit [63 : 0] addr;

  /** Address to be written */
  rand bit [1023 : 0] data;

  /**Write strobe */
  rand bit [127:0] wstrb;


  constraint write_strobe {
    soft wstrb == 4'hF;
  }

  `AXI_TRANSACTION_CLASS::atomic_type_enum atomic_type = `AXI_TRANSACTION_CLASS::NORMAL;

  function new(string name="hps2ce_axi_derived_write_sequence");
    super.new(name);
  endfunction

  virtual task body();
    super.body();

    `uvm_do_with(req, {
      xact_type == `AXI_TRANSACTION_CLASS::WRITE;
      addr == local::addr;
`ifndef INCA
      data.size() == 1;
`else
      req.data.size() == 1;
`endif
      data[0] == local::data;
      atomic_type == local::atomic_type;
      burst_length == 1;
      wstrb[0] ==  local::wstrb;
      wvalid_delay[0] ==0; //to make wvalid and awvalid assert at the same time from VIP
    })
  
    get_response(rsp);
  endtask: body

endclass: hps2ce_axi_derived_write_sequence




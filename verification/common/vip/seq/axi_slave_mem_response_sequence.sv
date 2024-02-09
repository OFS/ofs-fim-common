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
 * Class axi_slave_mem_response_sequence defines a sequence class that
 * the testbench uses to provide slave response to the Slave agent present in
 * the System agent. The sequence receives a response object of type
 * svt_axi_slave_transaction from slave sequencer. The sequence class then
 * randomizes the response with constraints and provides it to the slave driver
 * within the slave agent. The sequence also instantiates the slave built-in
 * memory, and writes into or reads from the slave memory.
 *
 * Execution phase: main_phase
 * Sequencer: Slave agent sequencer
 */

`ifndef GUARD_AXI_SLAVE_MEM_RESPONSE_SEQUENCE_SV
`define GUARD_AXI_SLAVE_MEM_RESPONSE_SEQUENCE_SV

class axi_slave_mem_response_sequence extends `AXI_SLAVE_BASE_SEQUENCE;

  `AXI_SLAVE_TRANSACTION_CLASS  req_resp;

  /** UVM Object Utility macro */
  `uvm_object_utils(axi_slave_mem_response_sequence)

  /** Class Constructor */
  function new(string name="axi_slave_mem_response_sequence");
    super.new(name);
  endfunction

  virtual task body();
    integer status;
      `VIP_CFG get_cfg;

    `uvm_info("body", "Entered ...", UVM_LOW)

    p_sequencer.get_cfg(get_cfg);
    if (!$cast(cfg, get_cfg)) begin
      `uvm_fatal("body", "Unable to $cast the configuration class");
    end

    // consumes responses sent by driver
    sink_responses();

    forever begin
      /**
       * Get the response request from the slave sequencer. The response request is
       * provided to the slave sequencer by the slave port monitor, through
       * TLM port.
       */
      p_sequencer.response_request_port.peek(req_resp);

      /**
       * Randomize the response and delays
       */
      status=req_resp.randomize with {
        bresp == `AXI_SLAVE_TRANSACTION_CLASS ::OKAY;
        foreach (rresp[index])  {
          rresp[index] == `AXI_SLAVE_TRANSACTION_CLASS ::OKAY;
          }
        foreach (tready_delay[i])
          tready_delay[i] inside {[1:10]};
        //  tready_delay[i]==0;
       };
       if(!status)
        `uvm_fatal("body","Unable to randomize a response")


        req_resp.print();


      /**
       * If write transaction, write data into slave built-in memory, else get
       * data from slave built-in memory
       */
      if(req_resp.get_transmitted_channel() == `AXI_SLAVE_TRANSACTION_CLASS ::WRITE) begin
        put_write_transaction_data_to_mem(req_resp);
      end
      else if (req_resp.get_transmitted_channel() == `AXI_SLAVE_TRANSACTION_CLASS ::READ)begin
        get_read_data_from_mem_to_transaction(req_resp);
      end
  
      /**
       * send to driver
       */

       $cast(req,req_resp);

      `uvm_send(req)

 `uvm_info("body", "Exiting mem_response_shalini9...", UVM_LOW)
      
    end

    `uvm_info("body", "Exiting mem_response_shalini10...", UVM_LOW)
  endtask: body

endclass: axi_slave_mem_response_sequence

`endif // GUARD_AXI_SLAVE_MEM_RESPONSE_SEQUENCE_SV

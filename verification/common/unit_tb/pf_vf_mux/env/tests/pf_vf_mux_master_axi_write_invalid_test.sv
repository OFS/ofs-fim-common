// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: MIT

/**
 * Abstract:
 * PF0 test 
 */

class pf_vf_mux_master_axi_write_invalid_test extends pf_vf_mux_base_test;

	int trans ;

  /** UVM Component Utility macro */
  `uvm_component_utils(pf_vf_mux_master_axi_write_invalid_test)

  /** Class Constructor */
  function new(string name = "pf_vf_mux_master_axi_write_invalid_test", uvm_component parent=null);
    super.new(name,parent);
  endfunction: new

   virtual function void build_phase(uvm_phase phase);
    `uvm_info ("build_phase", "Entered PF0 BASE TEST Build Phase...",UVM_LOW);
    super.build_phase(phase);
		uvm_config_db #(int)::set(null,"*","no_of_trans",50);
    `uvm_info ("build_phase", "Exiting PF0 BASE TEST Build Phase...",UVM_LOW)
  endfunction: build_phase

   task run_phase(uvm_phase phase);
     uvm_objection objection;
     uvm_object    object_list[$];
     pf_vf_mux_master_invalid_traffic_seq m_seq;
     super.run_phase(phase);
	   phase.raise_objection(this);
     uvm_config_db#(int)::get(null, "", "no_of_trans", trans);
	   m_seq = pf_vf_mux_master_invalid_traffic_seq::type_id::create("m_seq");
		 m_seq.randomize() with {m_seq.no_of_transactions==trans;};
     wait(top_tb.rst_n == 1'b1) ;
     wait(top_tb.rst_n == 1'b0) ;
     wait(top_tb.rst_n == 1'b1) ;
     `uvm_info(get_name(), "Out of reset...", UVM_LOW)
     enable_vip_error();
     disable_tready_check();
    `uvm_info("INFO", $sformatf("Running traffic sequence on PF0 from TEST RUN PHASE"),UVM_LOW);
	   m_seq.start(env.sequencer);	   
     wait($isunknown(top_tb.axis_if_H.master_if[0].tready))
     `uvm_info("body", $sformatf("Tready is X as invalid PF-VF combination was provided"), UVM_LOW)

     // Fetching the objection from current phase
     objection = phase.get_objection();
 
     // Collecting all the objects which doesn't drop the objection 
     objection.get_objectors(object_list);
 
     // Dropping the objection forcefully
     foreach(object_list[i]) begin
       while(objection.get_objection_count(object_list[i]) != 0) begin
         objection.drop_objection(object_list[i]);
       end
     end
    // phase.drop_objection(this);
    endtask : run_phase

   function void final_phase(uvm_phase phase);
      `uvm_info("TEST_FINAL", "Final phase from test", UVM_MEDIUM)
  		 final_packet_count_check();
    endfunction

endclass

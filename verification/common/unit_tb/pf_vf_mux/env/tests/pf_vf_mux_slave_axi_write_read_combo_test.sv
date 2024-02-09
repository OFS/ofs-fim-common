// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: MIT

/**
 * Abstract:
 * PF0 test 
 */

class pf_vf_mux_slave_axi_write_read_combo_test extends pf_vf_mux_base_test;
   int trans;

  /** UVM Component Utility macro */
  `uvm_component_utils(pf_vf_mux_slave_axi_write_read_combo_test)

  /** Class Constructor */
  function new(string name = "pf_vf_mux_slave_axi_write_read_combo_test", uvm_component parent=null);
    super.new(name,parent);
  endfunction: new

  virtual function void build_phase(uvm_phase phase);
    `uvm_info ("build_phase", "Entered PF_VF SLAVE WRITE READ COMBO TEST Build Phase...",UVM_LOW);
    super.build_phase(phase);
    uvm_config_db #(int)::set(null,"*","no_of_trans",50);
    `uvm_info ("build_phase", "Exiting PF_VF SLAVE WRITE READ COMBO TEST Build Phase...",UVM_LOW)
  endfunction: build_phase

   task run_phase(uvm_phase phase);
      pf_vf_mux_slave_traffic_wr_rd_combo_sequence m_seq;
      uvm_config_db#(int)::get(null, "", "no_of_trans", trans);
      super.run_phase(phase);
          phase.raise_objection(this);
          m_seq = pf_vf_mux_slave_traffic_wr_rd_combo_sequence::type_id::create("m_seq");
              m_seq.randomize() with {m_seq.no_of_transactions==trans;};
      wait(top_tb.rst_n == 1'b1) ;
      wait(top_tb.rst_n == 1'b0) ;
      wait(top_tb.rst_n == 1'b1) ;
      `uvm_info(get_name(), "Out of reset...", UVM_LOW)
      enable_vip_error();
      `uvm_info("INFO", $sformatf("Running Random format sequence from all DEVICES TO HOST from TEST RUN PHASE"),UVM_LOW);
          m_seq.start(env.sequencer);
      phase.drop_objection(this);
    endtask : run_phase

   function void final_phase(uvm_phase phase);
       super.final_phase(phase);
      `uvm_info("ENV_FINAL", "Final phase from Testcase", UVM_LOW)
       upstream_final_packet_count_check();
    endfunction



endclass

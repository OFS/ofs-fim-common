//=======================================================================
// COPYRIGHT (C) 2010, 2011, 2012, 2013 SYNOPSYS INC.
// This software and the associated documentation are confidential and
// proprietary to Synopsys, Inc. Your use or disclosure of this software
// is subject to the terms and conditions of a written license agreement
// between you, or your company, and Synopsys, Inc. In the event of
// publications, the following notice is applicable:
// 
// ALL RIGHTS RESERVED
//
// The entire notice above must be reproduced on all authorized copies.
//=======================================================================

/**
 * Abstract:
 * class pf_vf_mux_simple_reset_sequence defines a virtual sequence.
 * 
 * The pf_vf_mux_simple_reset_sequence drives the reset pin through one
 * activation cycle.
 *
 * The pf_vf_mux_simple_reset_sequence is configured as the default sequence for the
 * reset_phase of the testbench environment virtual sequencer, in the axi_base_test.
 *
 * The reset sequence obtains the handle to the reset interface through the
 * virtual sequencer. The reset interface is set in the virtual sequencer using
 * configuration database, in file top.sv.
 *
 * Execution phase: reset_phase
 * Sequencer: axi_virtual_sequencer in testbench environment
 */

`ifndef GUARD_pf_vf_mux_simple_reset_sequence_SV
`define GUARD_pf_vf_mux_simple_reset_sequence_SV

class pf_vf_mux_simple_reset_sequence extends uvm_sequence;

  /** UVM Object Utility macro */
  `uvm_object_utils(pf_vf_mux_simple_reset_sequence)

  /** Declare a typed sequencer object that the sequence can access */
  `uvm_declare_p_sequencer(pf_vf_mux_virtual_sequencer)

  /** Class Constructor */
  function new (string name = "pf_vf_mux_simple_reset_sequence");
    super.new(name);
  endfunction : new

  /** Raise an objection if this is the parent sequence */
  virtual task pre_body();
    uvm_phase starting_phase_for_curr_seq;
    super.pre_body();
`ifdef SVT_UVM_12_OR_HIGHER
    starting_phase_for_curr_seq = get_starting_phase();
`else
    starting_phase_for_curr_seq = starting_phase;
`endif
  if (starting_phase_for_curr_seq!=null) begin
    starting_phase_for_curr_seq.raise_objection(this);
  end
  endtask: pre_body

  /** Drop an objection if this is the parent sequence */
  virtual task post_body();
    uvm_phase starting_phase_for_curr_seq;
    super.post_body();
`ifdef SVT_UVM_12_OR_HIGHER
    starting_phase_for_curr_seq = get_starting_phase();
`else
    starting_phase_for_curr_seq = starting_phase;
`endif
  if (starting_phase_for_curr_seq!=null) begin
    starting_phase_for_curr_seq.drop_objection(this);
  end
  endtask: post_body

  virtual task body();
    `uvm_info("body", "Entered...", UVM_LOW)

    p_sequencer.reset_mp.reset <= 1'b1;

    repeat(10) @(posedge p_sequencer.reset_mp.clk);
    #2;
    p_sequencer.reset_mp.reset <= 1'b0;

    repeat(10) @(posedge p_sequencer.reset_mp.clk);
    p_sequencer.reset_mp.reset <= 1'b1;

    `uvm_info("body", "Exiting...", UVM_LOW)
  endtask: body

endclass: pf_vf_mux_simple_reset_sequence

`endif // GUARD_pf_vf_mux_simple_reset_sequence_SV

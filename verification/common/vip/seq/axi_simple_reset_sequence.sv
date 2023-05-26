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
// Description : AXI Simple Reset Sequence

`ifndef AXI_SIMPLE_RESET_SEQUENCE_SV
`define AXI_SIMPLE_RESET_SEQUENCE_SV

class axi_simple_reset_sequence extends uvm_sequence;

  /** UVM Object Utility macro */
  `uvm_object_utils(axi_simple_reset_sequence)

  /** Declare a typed sequencer object that the sequence can access */
  `uvm_declare_p_sequencer(axi_virtual_sequencer)

  /** Class Constructor */
  function new (string name = "axi_simple_reset_sequence");
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
    #1000
    repeat(10) @(posedge p_sequencer.reset_mp.clk);
    p_sequencer.reset_mp.reset <= 1'b1;

    `uvm_info("body", "Exiting...", UVM_LOW)
  endtask: body

endclass: axi_simple_reset_sequence

`endif // AXI_SIMPLE_RESET_SEQUENCE_SV

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
// Description : AXI Virtual Sequencer

`ifndef GUARD_AXI_VIRTUAL_SEQUENCER_SV
`define GUARD_AXI_VIRTUAL_SEQUENCER_SV

class axi_virtual_sequencer extends uvm_sequencer;

  /** Typedef of the reset modport to simplify access */
  typedef virtual axi_reset_if.axi_reset_modport AXI_RESET_MP;

  /** Reset modport provides access to the reset signal */
  AXI_RESET_MP reset_mp;

  `uvm_component_utils(axi_virtual_sequencer)

  function new(string name="axi_virtual_sequencer", uvm_component parent=null);
    super.new(name,parent);
  endfunction // new


  virtual function void build_phase(uvm_phase phase);
    `uvm_info("build_phase", "Entered...", UVM_LOW)

    super.build_phase(phase);

    if (!uvm_config_db#(AXI_RESET_MP)::get(this, "", "reset_mp", reset_mp)) begin
      `uvm_fatal("build_phase", "An axi_reset_modport must be set using the config db.");
    end

    `uvm_info("build_phase", "Exiting...", UVM_LOW)
  endfunction

endclass

`endif // GUARD_AXI_VIRTUAL_SEQUENCER_SV

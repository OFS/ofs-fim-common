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

`ifndef GUARD_PCIE_DEVICE_SEQUENCE_LIBRARY_SV
`define GUARD_PCIE_DEVICE_SEQUENCE_LIBRARY_SV

`include "pcie_device_report_catcher.sv"

/** 
 *  This sequence creates basic service and directed data transactions.
 */

class pcie_device_bring_up_link_sequence extends `PCIE_DEV_VIR_BASE_SEQ; 
   
   /** 
   * Factory Registration. 
   */
   `uvm_object_utils(pcie_device_bring_up_link_sequence)

   /** 
   * Parent Sequencer Declaration.
   */
   `uvm_declare_p_sequencer(`PCIE_DEV_VIR_SQR)
  
 
   /** 
   * Constructs the pcie_device_bring_up_link_sequence sequence
   * @param name string to name the instance.
   */
   function new(string name = "pcie_device_bring_up_link_sequence");
    super.new(name);
   endfunction

   /** 
   * Executes the pcie_device_bring_up_link_sequence sequence. 
   */
   virtual task body();
     uvm_sequence_base p;
     `PCIE_DL_LINK_EN_SEQ link_en_seq;
     `PCIE_DEV_STATUS status; 
     recovery_idle_catcher  idle_catcher;
    
     `uvm_info("body", "Entered...", UVM_LOW)
     status = p_sequencer.get_shared_status(this);

     p = get_parent_sequence();
     `uvm_info("body", $psprintf("Sequence parent is %0s", (p==null)?this.get_type_name():p.get_type_name()), UVM_LOW)
     `uvm_do_on_with(link_en_seq, p_sequencer.pcie_virt_seqr.dl_seqr, {link_en_seq.enable==1'b1;})
     wait(status.pcie_status.pl_status.link_up == 1'b1);

     //========================================================================
     // Demode SERDES error messages during speed change
     // Valid for Gen2 and higher speeds
     // Suppress RP error messages: "Lost valid signal level on receiver"

     if(GEN >= 2) begin
        idle_catcher = new();
        uvm_report_cb::add(null,idle_catcher);

        // Wait for after speed change occurs.
        wait(status.port_status.pl_status.ltssm_state == `PCIE_TYPES_CLASS::RECOVERY_RCVRLOCK) ;
        wait(status.port_status.pl_status.ltssm_state == `PCIE_TYPES_CLASS::L0) ;

        // Resume reporting of Lost of valid; special case is over
        uvm_report_cb::delete(null, idle_catcher);
    end

   endtask : body

endclass : pcie_device_bring_up_link_sequence





class pcie_device_link_hotreset_sequence extends `PCIE_DEV_VIR_BASE_SEQ;
   rand int  t_delay;

  constraint tdelay_task {
      t_delay  inside {[1000:40000]} ;
   }


   `uvm_object_utils(pcie_device_link_hotreset_sequence)
   `uvm_declare_p_sequencer(`PCIE_DEV_VIR_SQR)

   function new(string name = "pcie_device_link_hotreset_sequence");
    super.new(name);
   endfunction

   virtual task body();
     uvm_sequence_base p;
     `PCIE_DEV_STATUS status;
     recovery_idle_catcher  idle_catcher;
     `VIP_ERR_CATCHER_CLASS err_catcher;
     `PCIE_DL_LINK_EN_SEQ link_en_seq;
     `PCIE_PL_HOT_RST_SEQ hot_reset_seq;
     `PCIE_PL_SERV_PHY_EN_SEQ vip_pl_link_en_seq;
     `PCIE_PL_SERV_PHY_EN_SEQ dut_pl_link_en_seq;


     `uvm_info("SEQ", "Entered PL hot reset...", UVM_LOW)
     status = p_sequencer.get_shared_status(this);

    /* Initializing Retrain link Sequence */
    `uvm_info("SEQ", $sformatf("SEQ Before entering hot reset ..."), UVM_LOW);
    `uvm_do_on_with(hot_reset_seq, p_sequencer.pcie_virt_seqr.pl_seqr, {hot_reset_seq.mode == `PCIE_PL_SERV::HOT_RESET_FORCE;});

    /** Wait until LTSSM is in HOT_RESET */
    `uvm_info("SEQ", $sformatf("Wait until LTSSM is in HOT_RESET"), UVM_LOW);
    wait(status.pcie_status.pl_status.ltssm_state == `PCIE_TYPES_CLASS::HOT_RESET) ;

//    `uvm_do_on(vip_reset_seq, p_sequencer.root_virt_seqr)

    //Demote errors only in Polling active.
    wait(status.pcie_status.pl_status.ltssm_state == `PCIE_TYPES_CLASS::POLLING_ACTIVE);
    `uvm_info("SEQ",$sformatf("Endpoint Current state = %s,\n",status.pcie_status.pl_status.ltssm_state.name() ), UVM_LOW)

    //create error catcher
    err_catcher=new();
    //add error message string to error catcher
    err_catcher.add_message_id_to_demote("phy_polling_active_timeout", 1);
    uvm_report_cb::add(null,err_catcher);
    wait(status.pcie_status.pl_status.ltssm_state == `PCIE_TYPES_CLASS::POLLING_CONFIGURATION);
    //delete the error demotion callback once out from polling active.
    uvm_report_cb::delete(null,err_catcher);

    /* Wait until LTSSM is in Recovery_RCVRCFG */
    `uvm_info("SEQ", $sformatf("Wait until LTSSM is in RECOVERY_RCVRCFG"), UVM_LOW);
    wait(status.pcie_status.pl_status.link_up == 1'b0) ;
    wait(status.pcie_status.dl_status.dl_link_up == 1'b0);

    `uvm_info("SEQ",$sformatf("Endpoint pl_status.link_up %d , dl_status.dl_link_up %d\n", status.pcie_status.pl_status.link_up, status.pcie_status.dl_status.dl_link_up ), UVM_LOW)

    //Enable links 
    assert(this.randomize(t_delay));
    #t_delay;
    `uvm_info("SEQ", $psprintf("Before enable the link_en_seq again"), UVM_LOW)
     fork
        `uvm_do_on_with(vip_pl_link_en_seq, p_sequencer.pcie_virt_seqr.pl_seqr, { phy_enable == 1'b1;} )
        `uvm_do_on_with(dut_pl_link_en_seq, p_sequencer.pcie_virt_seqr.pl_seqr, { phy_enable == 1'b1;} )
     join

     #8000;
     `uvm_do_on_with(link_en_seq, p_sequencer.pcie_virt_seqr.dl_seqr, {link_en_seq.enable==1'b1;})
     wait(status.pcie_status.pl_status.link_up == 1'b1);
     wait(status.pcie_status.pl_status.ltssm_state == `PCIE_TYPES_CLASS::L0) ;

     `uvm_info("SEQ", $sformatf("After hot reset part 2"), UVM_LOW);

   endtask : body

endclass : pcie_device_link_hotreset_sequence

`endif // GUARD_PCIE_DEVICE_SEQUENCE_LIBRARY_SV

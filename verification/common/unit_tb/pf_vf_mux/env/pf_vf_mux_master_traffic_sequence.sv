// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: MIT

class pf_vf_mux_master_traffic_seq extends uvm_sequence;
    
  rand bit[7:0] local_fmt_type   ;
  rand bit local_vf_active       ;
  rand bit [2:0] local_pf_num    ;
  rand bit [10:0] local_vf_num   ;
  bit [9:0] local_tlp_length;
  bit [255:0] local_payload , random_value, local_my_payload;
  rand int no_of_transactions ;

  `ifdef TB_CONFIG_4
  bit vf_active_array[1] ;
  bit[10:0] vf_num_array[1];
  `elsif TB_CONFIG_3
  bit vf_active_array[4] ;
  bit[10:0] vf_num_array[4];
  `elsif TB_CONFIG_2
  bit vf_active_array[3] ;
  bit[10:0] vf_num_array[3];
  `else 
  bit vf_active_array[2] ;
  bit[10:0] vf_num_array[2];
  `endif

  int vf_va = 0;
  int num = 0;

  `uvm_object_utils(pf_vf_mux_master_traffic_seq);

  /** Declare a typed sequencer object that the sequence can access */
  `uvm_declare_p_sequencer(pf_vf_mux_virtual_sequencer)

  function new (string name = "pf_vf_mux_master_traffic_seq");
    super.new(name);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
   `uvm_info ("build_phase", "Entered PF0 Traffic Sequence Build Phase...",UVM_LOW);
   `uvm_info ("build_phase", "Exiting PF0 Traffic Sequence Build Phase...",UVM_LOW)
  endfunction: build_phase

  task body();
    pf_vf_mux_request_sequence master_seq;
    super.body(); 
    `uvm_info(get_name(), "Starting master sequence on Host master sequencer", UVM_LOW)
   
    `ifdef TB_CONFIG_4 
    vf_active_array = '{'h1};
    vf_num_array    = '{'h0};
    vf_va = 1;
    `elsif TB_CONFIG_3 
    vf_active_array = '{'h0,'h1,'h1,'h1};
    vf_num_array    = '{'h0,'h0,'h7ff,`RANDOM_VF};
    vf_va = 4;
    `elsif TB_CONFIG_2 
    vf_active_array = '{'h0,'h1,'h1};
    vf_num_array    = '{'h0,'h0,'h7ff};
    vf_va = 3;
    `else 
    vf_active_array = '{'h0,'h1};
    vf_num_array    = '{'h0,'h0};
    vf_va = 2;
    `endif
 
    for(int k = 0; k < vf_va; k++) begin //{
    `ifdef TB_CONFIG_4
     for(int t = 0; t < 2048; t++) begin //{
    `else
     for(int j = 0; j < 8; j++) begin //{
    `endif
    for(int i = 0; i < no_of_transactions; i++) begin
      //===============================================
      // Generating the payload w.r.t TLP length field
      //===============================================
      local_vf_active = vf_active_array[k];
     `ifdef TB_CONFIG_4
      local_pf_num = 0;
      local_vf_num = t;
     `else
      local_pf_num = j;
      local_vf_num = vf_num_array[k];
     `endif
      local_tlp_length = $urandom_range(64,1) ;
      local_payload = 'h0;
      local_my_payload = 'h0;
      if(local_fmt_type == 'h40 || local_fmt_type == 'h60)    //For MWR_32,MWR_64
      assert(std::randomize(random_value));
      else if(local_fmt_type == 'h0 || local_fmt_type == 'h20 || local_fmt_type == 'h4A)  //For WRD_32,MRD_64,CPLD  
      assert(std::randomize(random_value));
      for(int j=0; j < (local_tlp_length*32); j++) local_my_payload[j] = 1'b1;
      local_payload = (random_value) & local_my_payload;
      `uvm_info("body", $sformatf("TLP Length = %h and Payload = %h and Random Value generated = %h",local_tlp_length,local_payload,random_value), UVM_LOW)
      `uvm_info("body", $sformatf("LOCAL_PF_NUM = %d and LOCAL_VF_NUM = %d and LOCAL_VF_ACTIVE = %d",local_pf_num,local_vf_num,local_vf_active), UVM_LOW)
      //=============================================
      // Starting request sequence on Host master
      //=============================================
      `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_H, { tlp_length  == local_tlp_length  ;
                                                                       pf_num      == local_pf_num      ;
                                                                       vf_num      == local_vf_num      ;
                                                                       vf_active   == local_vf_active   ;
                                                                       payload     == local_payload     ;
                                                                       fmt_type    == local_fmt_type    ;             
                                                                       direction   == 1'b0              ;
                                                                    })
       end
      
       end
         
       end
    `uvm_info(get_name(), "Exiting sequence...", UVM_LOW)
  endtask : body

endclass

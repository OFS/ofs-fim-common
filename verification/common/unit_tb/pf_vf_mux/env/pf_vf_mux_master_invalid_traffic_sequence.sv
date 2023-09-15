// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: MIT

class pf_vf_mux_master_invalid_traffic_seq extends uvm_sequence;
    
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

    `uvm_object_utils(pf_vf_mux_master_invalid_traffic_seq);

  /** Declare a typed sequencer object that the sequence can access */
  `uvm_declare_p_sequencer(pf_vf_mux_virtual_sequencer)


    function new (string name = "pf_vf_mux_master_invalid_traffic_seq");
        super.new(name);
    endfunction : new

     virtual function void build_phase(uvm_phase phase);
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
    vf_num_array    = '{'h0,'h3};
    vf_va = 2;
    `endif


       //TB_CONFIG_1 VALID SCENARIO : PF = (0-7), VF = 3, VF_ACTIVE = (0-1)  
       //TB_CONFIG_3 VALID SCENARIO : PF = (0-7), VF = (0-2047), VF_ACTIVE = (0-1)  

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
             local_tlp_length = $urandom_range(1,64) ;
             local_payload = 'h0;
             local_my_payload = 'h0;
             assert(std::randomize(random_value));        
             for(int l=0; l < (local_tlp_length*32); l++) local_my_payload[l] = 1'b1;
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
                                                                              direction   == 1'b0              ;
                                                                           })
           end
         
       end    
       end
      
    `ifdef TB_CONFIG_1 
      `ifdef INVALID_PF_VF
       //TB_CONFIG_1 INVALID_SCENARIO: PF=0, VF= 0, VF_ACTIVE=1 
    
       local_pf_num = 0;               
       local_vf_num = 0;      
       local_vf_active = 1;
       for(int i = 0; i < no_of_transactions; i++) begin
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================
          local_tlp_length = $urandom_range(1,64) ;
          local_payload = 'h0;
          local_my_payload = 'h0;
          assert(std::randomize(random_value));      
          $assertoff (0,top_tb.ho2mx_rx_remap.assert_tready_undef_when_not_in_reset);
          for(int l=0; l < (local_tlp_length*32); l++) local_my_payload[l] = 1'b1;
          local_payload = (random_value) & local_my_payload;
          `uvm_info("body", $sformatf("TLP Length = %h and Payload = %h and Random Value generated = %h",local_tlp_length,local_payload,random_value), UVM_LOW)
          `uvm_info("body", $sformatf("INVALID_LOCAL_PF_NUM = %d and INVALID_LOCAL_VF_NUM = %d and INVALID_LOCAL_VF_ACTIVE = %d",local_pf_num,local_vf_num,local_vf_active), UVM_LOW)
          //=============================================
           // Starting request sequence on Host master
           //=============================================
           `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_H, { tlp_length  == local_tlp_length  ;
                                                                            pf_num      == local_pf_num      ;
                                                                            vf_num      == local_vf_num      ;
                                                                            vf_active   == local_vf_active   ;
                                                                            payload     == local_payload     ;
                                                                            direction   == 1'b0              ;
                                                                        })
        end
      `endif
    `endif

    `ifdef TB_CONFIG_3
      `ifdef INVALID_PF_VF
       //INVALID_SCENARIO: PF=0, VF= other than `RANDOM_VF, VF_ACTIVE=1 

        local_pf_num = 0;
        while(1)
        begin
          local_vf_num = $urandom_range(1,10);
          if(local_vf_num !=`RANDOM_VF)
          break;
        end 
                   
        local_vf_active = 1;
        for(int i = 0; i < no_of_transactions; i++) begin
           //===============================================
           // Generating the payload w.r.t TLP length field
           //===============================================
           local_tlp_length = $urandom_range(1,64) ;
           local_payload = 'h0;
           local_my_payload = 'h0;
           assert(std::randomize(random_value));
           $assertoff (0,top_tb.ho2mx_rx_remap.assert_tready_undef_when_not_in_reset);      
           for(int l=0; l < (local_tlp_length*32); l++) local_my_payload[l] = 1'b1;
           local_payload = (random_value) & local_my_payload;
           `uvm_info("body", $sformatf("TLP Length = %h and Payload = %h and Random Value generated = %h",local_tlp_length,local_payload,random_value), UVM_LOW)
           `uvm_info("body", $sformatf("INVALID_LOCAL_PF_NUM = %d and INVALID_LOCAL_VF_NUM = %d and INVALID_LOCAL_VF_ACTIVE = %d",local_pf_num,local_vf_num,local_vf_active), UVM_LOW)
           //=============================================
           // Starting request sequence on Host master
           //=============================================
           `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_H, { tlp_length  == local_tlp_length  ;
                                                                            pf_num      == local_pf_num      ;
                                                                            vf_num      == local_vf_num      ;
                                                                            vf_active   == local_vf_active   ;
                                                                            payload     == local_payload     ;
                                                                            direction   == 1'b0              ;
                                                                        })
        end
       `endif
      `endif

    `ifdef TB_CONFIG_4 
      `ifdef INVALID_PF_VF
       //TB_CONFIG_4 INVALID_SCENARIO: PF=0, VF= 0, VF_ACTIVE=0 
    
       local_pf_num = 0;               
       local_vf_num = 0;      
       local_vf_active = 0;
       for(int i = 0; i < no_of_transactions; i++) begin
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================
          local_tlp_length = $urandom_range(1,64) ;
          local_payload = 'h0;
          local_my_payload = 'h0;
          assert(std::randomize(random_value)); 
          $assertoff (0,top_tb.ho2mx_rx_remap.assert_tready_undef_when_not_in_reset);      
          for(int l=0; l < (local_tlp_length*32); l++) local_my_payload[l] = 1'b1;
          local_payload = (random_value) & local_my_payload;
          `uvm_info("body", $sformatf("TLP Length = %h and Payload = %h and Random Value generated = %h",local_tlp_length,local_payload,random_value), UVM_LOW)
          `uvm_info("body", $sformatf("INVALID_LOCAL_PF_NUM = %d and INVALID_LOCAL_VF_NUM = %d and INVALID_LOCAL_VF_ACTIVE = %d",local_pf_num,local_vf_num,local_vf_active), UVM_LOW)
          //=============================================
           // Starting request sequence on Host master
           //=============================================
           `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_H, { tlp_length  == local_tlp_length  ;
                                                                            pf_num      == local_pf_num      ;
                                                                            vf_num      == local_vf_num      ;
                                                                            vf_active   == local_vf_active   ;
                                                                            payload     == local_payload     ;
                                                                            direction   == 1'b0              ;
                                                                        })
        end
      `endif
    `endif

      `uvm_info(get_name(), "Exiting sequence...", UVM_LOW)
    endtask : body

endclass

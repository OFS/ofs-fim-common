// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: MIT

`define payload_generate(PF,VF,VA,local_fmt_type) \
          local_vf_active = ``VA``;\
          local_pf_num    = ``PF``;\
          local_vf_num    = ``VF``;\
          local_tlp_length = $urandom_range(1,64) ;\
          local_payload = 'h0;\
          local_my_payload = 'h0;\
          if(``local_fmt_type`` == 'h40 || ``local_fmt_type`` == 'h60) \
          assert(std::randomize(random_value));     //For MWR_32,MWR_64\
          else\
          random_value = 0;     //For WRD_32,MRD_64\
          for(int j=0; j < (local_tlp_length*32); j++) local_my_payload[j] = 1'b1;\
          local_payload = (random_value) & local_my_payload;\
          `uvm_info("body", $sformatf("TLP Length = %h and Payload = %h and Random Value generated = %h No of Trans = %d",local_tlp_length,local_payload,random_value,no_of_transactions),UVM_LOW)
     
    

class pf_vf_mux_slave_simultaneous_traffic_sequence extends uvm_sequence;
    
     rand bit[7:0] local_fmt_type ;
     rand bit local_vf_active       ;
     rand bit [2:0] local_pf_num    ;
     rand bit [10:0] local_vf_num   ;
     bit [9:0] local_tlp_length;
     bit [255:0] local_payload , random_value, local_my_payload;
     rand int no_of_transactions ;
     int num = 0;
    `uvm_object_utils(pf_vf_mux_slave_simultaneous_traffic_sequence);

  /** Declare a typed sequencer object that the sequence can access */
  `uvm_declare_p_sequencer(pf_vf_mux_virtual_sequencer)


    function new (string name = "pf_vf_mux_slave_simultaneous_traffic_sequence");
        super.new(name);
    endfunction : new

     virtual function void build_phase(uvm_phase phase);
        `uvm_info ("build_phase", "Entered PF VF Slave simultaneous Traffic Sequence Build Phase...",UVM_LOW);
        `uvm_info ("build_phase", "Exiting PF VF Slave simultaneous Traffic Sequence Build Phase...",UVM_LOW)
      endfunction: build_phase


    task body();
        pf_vf_mux_request_sequence master_seq;
        super.body(); 
      	`uvm_info(get_name(), "Entering PF VF Slave simultaneous Traffic sequence...", UVM_LOW)
        `uvm_info(get_name(), "Starting Master sequence on Device master sequencer", UVM_LOW)
    for(int i=0; i<no_of_transactions; i++)
     fork//{
`ifndef TB_CONFIG_4
	begin//{ 
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================
         `payload_generate('h0,'h0,'h0,local_fmt_type);
         
          //=============================================
          // Starting request sequence on Device master
          //=============================================
          
         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D0, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ; 
                                                                         direction   == 1'b1              ;            
                                                                                              })
                    
         end//}     
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h1,'h0,'h0,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D1, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h2,'h0,'h0,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================        
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D2, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h3,'h0,'h0,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D3, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h4,'h0,'h0,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D4, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h5,'h0,'h0,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================        
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D5, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h6,'h0,'h0,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D6, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h7,'h0,'h0,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D7, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h0,'h0,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D8, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h1,'h0,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D9, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h2,'h0,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D10, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h3,'h0,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D11, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ; 
                                                                         direction   == 1'b1              ;            
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h4,'h0,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D12, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h5,'h0,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D13, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ; 
                                                                         direction   == 1'b1              ;            
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h6,'h0,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D14, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h7,'h0,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D15, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
	end//}
`endif
`ifdef TB_CONFIG_2//{	 
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================
         `payload_generate('h0,'h2047,'h1,local_fmt_type);
         
          //=============================================
          // Starting request sequence on Device master
          //=============================================        
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN0, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
                      
         end//}     
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h1,'h2047,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN1, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h2,'h2047,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN2, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h3,'h2047,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN3, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h4,'h2047,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN4, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h5,'h2047,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================        
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN5, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h6,'h2047,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================        
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN6, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h7,'h2047,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN7, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           

            end//}  
`endif//}

`ifdef TB_CONFIG_3//{	 
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================
         `payload_generate('h0,'h2047,'h1,local_fmt_type);
         
          //=============================================
          // Starting request sequence on Device master
          //=============================================        
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN0, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
                      
         end//}     
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h1,'h2047,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN1, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h2,'h2047,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN2, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h3,'h2047,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN3, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h4,'h2047,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN4, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h5,'h2047,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================        
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN5, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h6,'h2047,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================        
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN6, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h7,'h2047,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN7, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           

         end//} 
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================
         `payload_generate('h0,`RANDOM_VF,'h1,local_fmt_type);
         
          //=============================================
          // Starting request sequence on Device master
          //=============================================        
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN8, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
                      
         end//}     
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h1,`RANDOM_VF,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN9, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h2,`RANDOM_VF,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN10, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h3,`RANDOM_VF,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN11, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h4,`RANDOM_VF,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN12, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ; 
                                                                         direction   == 1'b1              ;            
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h5,`RANDOM_VF,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================        
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN13, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ; 
                                                                         direction   == 1'b1              ;            
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h6,`RANDOM_VF,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================        
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN14, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate('h7,`RANDOM_VF,'h1,local_fmt_type);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN15, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         fmt_type    == local_fmt_type    ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           

            end//}  
 
`endif//}
`ifdef TB_CONFIG_4
     `include "pf_vf_config4_simultaneous_traffic.sv"
`endif

     join_none     
     wait fork;//} // wait for all the above fork-join_none to complete
   `uvm_info(get_name(), "Exiting sequence...", UVM_LOW)
    endtask : body

endclass

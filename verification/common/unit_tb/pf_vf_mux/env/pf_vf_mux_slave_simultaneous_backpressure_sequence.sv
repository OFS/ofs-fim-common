// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: MIT

`define toggle_tready_upstream\
          foreach(rst_arr[a])\
          if(i==rst_arr[a]) \
            begin\
              force top_tb.pf_vf_mux_a.mx2ho_tx_port.tready = 1'b0;\
              `uvm_info(get_name(), "forced in ready...", UVM_LOW)\
              #1000;\
              force top_tb.pf_vf_mux_a.mx2ho_tx_port.tready = 1'b1;\
              `uvm_info(get_name(), "forced out of ready...", UVM_LOW)\
            end\

`define fifo_full_check_up\
	 if(top_tb.pf_vf_mux_a.switch.M_mux[0].out_q.full==1)\
	 `uvm_info(get_name(), "Fifo full...", UVM_LOW)\
         else if (top_tb.pf_vf_mux_a.switch.M_mux[0].out_q.full==0)\
	 `uvm_info(get_name(), "Fifo not full...", UVM_LOW)\






class pf_vf_mux_slave_simultaneous_backpressure_sequence extends uvm_sequence;    
     
     rand bit local_vf_active       ;
     rand bit [2:0] local_pf_num    ;
     rand bit [10:0] local_vf_num   ;
     bit [9:0] local_tlp_length;
     bit [255:0] local_payload , random_value, local_my_payload;
     rand int no_of_transactions ;
     rand int val1;
     rand int val2;
     int rst_arr[4];


    `uvm_object_utils(pf_vf_mux_slave_simultaneous_backpressure_sequence);

  /** Declare a typed sequencer object that the sequence can access */
  `uvm_declare_p_sequencer(pf_vf_mux_virtual_sequencer)


    function new (string name = "pf_vf_mux_slave_simultaneous_backpressure_sequence");
        super.new(name);
    endfunction : new

     virtual function void build_phase(uvm_phase phase);
        `uvm_info ("build_phase", "Entered PF_VF Slave Simultaneous Backpressure Sequence Build Phase...",UVM_LOW);
        `uvm_info ("build_phase", "Exiting PF_VF Slave Simultaneous Backpressure Sequence Build Phase...",UVM_LOW)
      endfunction: build_phase

    task body();
        pf_vf_mux_request_sequence master_seq;
        super.body(); 
      	`uvm_info(get_name(), "Entering PF_VF Slave Simultaneous backpressure sequence...", UVM_LOW)
        `uvm_info(get_name(), "Starting Master sequence on Device master sequencer", UVM_LOW)

        for(int arr_element = 0; arr_element < 4; arr_element++) 
        begin
            rst_arr[arr_element] = $urandom_range(no_of_transactions,1);
             `uvm_info("body", $sformatf("rst_arr = %h",rst_arr[arr_element]), UVM_LOW)
        end



     for(int i=0; i<no_of_transactions; i++)     
     begin//{

         `toggle_tready_upstream
 
         `fifo_full_check_up
     `ifndef TB_CONFIG_4    
     fork//{         
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================
         `payload_generate_combo('h0,'h0,'h0);
         
          //=============================================
          // Starting request sequence on Device master
          //=============================================                 
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D0, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
                      
         end     
         begin
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h1,'h0,'h0);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================                 
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D1, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h2,'h0,'h0);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================                 
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D2, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h3,'h0,'h0);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================                   
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D3, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h4,'h0,'h0);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================                   
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D4, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h5,'h0,'h0);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================                  
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D5, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h6,'h0,'h0);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================                   
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D6, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h7,'h0,'h0);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================                   
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D7, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h0,'h0,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================                  
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D8, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h1,'h0,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================                  
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D9, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h2,'h0,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================                   
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D10, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h3,'h0,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================                  
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D11, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h4,'h0,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================                  
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D12, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h5,'h0,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================                 
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D13, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h6,'h0,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================                  
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D14, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h7,'h0,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================                   
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D15, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
	end//}
`endif
`ifdef TB_CONFIG_2//{
	  begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================
         `payload_generate_combo('h0,'h2047,'h1);
         
          //=============================================
          // Starting request sequence on Device master
          //=============================================       
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN0, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           
         end//}    
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h1,'h2047,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================        
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN1, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h2,'h2047,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================        
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN2, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h3,'h2047,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================        
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN3, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h4,'h2047,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN4, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h5,'h2047,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN5, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h6,'h2047,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================        
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN6, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h7,'h2047,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN7, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           

          end//}

`endif//}

`ifdef TB_CONFIG_3//{
	  begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================
         `payload_generate_combo('h0,'h2047,'h1);
         
          //=============================================
          // Starting request sequence on Device master
          //=============================================       
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN0, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           
         end//}    
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h1,'h2047,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================        
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN1, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h2,'h2047,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================        
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN2, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h3,'h2047,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================        
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN3, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h4,'h2047,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN4, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h5,'h2047,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN5, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h6,'h2047,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================        
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN6, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h7,'h2047,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN7, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================
         `payload_generate_combo('h0,`RANDOM_VF,'h1);
         
          //=============================================
          // Starting request sequence on Device master
          //=============================================        
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN8, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
                      
         end//}     
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h1,`RANDOM_VF,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN9, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h2,`RANDOM_VF,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN10, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h3,`RANDOM_VF,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN11, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h4,`RANDOM_VF,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN12, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;            
                                                                                              })
           
         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h5,`RANDOM_VF,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================        
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN13, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;            
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h6,`RANDOM_VF,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================        
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN14, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           

         end//}
         begin//{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================

          `payload_generate_combo('h7,`RANDOM_VF,'h1);
 
          //=============================================
          // Starting request sequence on Device master
          //=============================================         
         `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN15, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;             
                                                                                              })
           

            end//}  


`endif//}
`ifdef TB_CONFIG_4
  `include "pf_vf_config4_simultaneous_combo_traffic.sv"
`endif
      
                   
     join_none     
     wait fork;//}
     end//}         // wait for all the above fork-join_none to complete
   `uvm_info(get_name(), "Exiting sequence...", UVM_LOW)
    endtask : body

endclass

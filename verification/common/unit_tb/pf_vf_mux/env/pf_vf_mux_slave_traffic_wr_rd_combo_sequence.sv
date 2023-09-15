// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: MIT

class pf_vf_mux_slave_traffic_wr_rd_combo_sequence extends uvm_sequence;    
     //rand bit[7:0] local_fmt_type ;
     rand bit local_vf_active       ;
     rand bit [2:0] local_pf_num    ;
     rand bit [10:0] local_vf_num   ;
     bit [9:0] local_tlp_length;
     bit [255:0] local_payload , random_value, local_my_payload;
     rand int no_of_transactions ;

     `ifdef TB_CONFIG_3
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
    `uvm_object_utils(pf_vf_mux_slave_traffic_wr_rd_combo_sequence);

  /** Declare a typed sequencer object that the sequence can access */
  `uvm_declare_p_sequencer(pf_vf_mux_virtual_sequencer)


    function new (string name = "pf_vf_mux_slave_traffic_wr_rd_combo_sequence");
        super.new(name);
    endfunction : new

     virtual function void build_phase(uvm_phase phase);
        `uvm_info ("build_phase", "Entered PF_VF Slave Combo Traffic Sequence Build Phase...",UVM_LOW);
        `uvm_info ("build_phase", "Exiting PF_VF Slave Combo Traffic Sequence Build Phase...",UVM_LOW)
      endfunction: build_phase


    task body();
        pf_vf_mux_request_sequence master_seq;
        super.body(); 
      	`uvm_info(get_name(), "Entering PF_VF Slave Combo Traffic sequence...", UVM_LOW)
        `uvm_info(get_name(), "Starting Master sequence on Device master sequencer", UVM_LOW)

       
        `ifdef TB_CONFIG_3
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

        `ifdef TB_CONFIG_4
        for(int vf_num = 0; vf_num < 2048; vf_num++)//{
        `else
        for(int k = 0; k < vf_va; k++) begin //{
        for(int j = 0; j < 8 ; j++) begin //{  
        `endif    
        for(int i = 0; i < no_of_transactions; i++) begin //{
          //===============================================
          // Generating the payload w.r.t TLP length field
          //===============================================
         `ifdef TB_CONFIG_4
             local_vf_active = 'h1;
             local_pf_num    = 'h0;
             local_vf_num    = vf_num;
          `else          
             local_vf_active = vf_active_array[k];
             local_pf_num    = j ;
             local_vf_num    = vf_num_array[k];
          `endif
          local_tlp_length = $urandom_range(1,64) ;
          local_payload = 'h0;
          local_my_payload = 'h0;
          assert(std::randomize(random_value));   //For MWR_32,MWR_64    
          for(int j=0; j < (local_tlp_length*32); j++) local_my_payload[j] = 1'b1;
          local_payload = (random_value) & local_my_payload;
          `uvm_info("body", $sformatf("TLP Length = %h and Payload = %h and Random Value generated = %h",local_tlp_length,local_payload,random_value), UVM_LOW)
          //=============================================
          // Starting request sequence on Device master
          //=============================================
        `ifndef TB_CONFIG_4            
         if(local_pf_num == 'h0 && local_vf_num == 'h0 && local_vf_active == 'h0) begin
          `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D0, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload   ;
                                                                         direction   == 1'b1              ;           
                                                                                              })
	end
         else if(local_pf_num == 'h1 && local_vf_num == 'h0 && local_vf_active == 'h0) begin
          `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D1, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
	end
         else if(local_pf_num == 'h2 && local_vf_num == 'h0 && local_vf_active == 'h0) begin
          `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D2, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
	end
         else if(local_pf_num == 'h3 && local_vf_num == 'h0 && local_vf_active == 'h0) begin
          `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D3, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
	end
         else if(local_pf_num == 'h4 && local_vf_num == 'h0 && local_vf_active == 'h0) begin
          `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D4, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
	end
         else if(local_pf_num == 'h5 && local_vf_num == 'h0 && local_vf_active == 'h0) begin
          `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D5, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
	end
         else if(local_pf_num == 'h6 && local_vf_num == 'h0 && local_vf_active == 'h0) begin
          `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D6, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
	end
         else if(local_pf_num == 'h7 && local_vf_num == 'h0 && local_vf_active == 'h0) begin
          `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D7, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
	end
         else if(local_pf_num == 'h0 && local_vf_num == 'h0 && local_vf_active == 'h1) begin 
          `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D8, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
	end              
         else if(local_pf_num == 'h1 && local_vf_num == 'h0 && local_vf_active == 'h1) begin
          `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D9, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              }) 
	end
         else if(local_pf_num == 'h2 && local_vf_num == 'h0 && local_vf_active == 'h1) begin
          `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D10, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
	end
         else if(local_pf_num == 'h3 && local_vf_num == 'h0 && local_vf_active == 'h1) begin
          `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D11, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
	end
         else if(local_pf_num == 'h4 && local_vf_num == 'h0 && local_vf_active == 'h1) begin
          `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D12, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
	end
         else if(local_pf_num == 'h5 && local_vf_num == 'h0 && local_vf_active == 'h1) begin
          `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D13, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
	end
         else if(local_pf_num == 'h6 && local_vf_num == 'h0 && local_vf_active == 'h1) begin
          `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D14, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
	end 
         else  if(local_pf_num == 'h7 && local_vf_num == 'h0 && local_vf_active == 'h1) begin       
           `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_D15, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                         direction   == 1'b1              ;
                                                                                              })
	end
          else if(local_vf_active == 'h1 && local_pf_num == 'h0 && local_vf_num == 'h7ff) begin
             `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN0, { tlp_length  == local_tlp_length  ;
                                                                           pf_num      == local_pf_num      ;
                                                                           vf_num      == local_vf_num      ;
                                                                           vf_active   == local_vf_active   ;
                                                                           payload     == local_payload     ; 
                                                                         direction   == 1'b1              ;
                                                                        })
        end
          else if(local_vf_active == 'h1 && local_pf_num == 'h1 && local_vf_num == 'h7ff) begin
             `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN1, { tlp_length  == local_tlp_length  ;
                                                                           pf_num      == local_pf_num      ;
                                                                           vf_num      == local_vf_num      ;
                                                                           vf_active   == local_vf_active   ;
                                                                           payload     == local_payload     ;
                                                                         direction   == 1'b1              ; 
                                                                        })
        end
           else if(local_vf_active == 'h1 && local_pf_num == 'h2 && local_vf_num == 'h7ff) begin
             `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN2, { tlp_length  == local_tlp_length  ;
                                                                           pf_num      == local_pf_num      ;
                                                                           vf_num      == local_vf_num      ;
                                                                           vf_active   == local_vf_active   ;
                                                                           payload     == local_payload     ; 
                                                                         direction   == 1'b1              ;
                                                                        })
        end
           else if(local_vf_active == 'h1 && local_pf_num == 'h3 && local_vf_num == 'h7ff) begin
             `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN3, { tlp_length  == local_tlp_length  ;
                                                                           pf_num      == local_pf_num      ;
                                                                           vf_num      == local_vf_num      ;
                                                                           vf_active   == local_vf_active   ;
                                                                           payload     == local_payload     ;
                                                                           direction   == 1'b1              ; 
                                                                        })
        end
           else if(local_vf_active == 'h1 && local_pf_num == 'h4 && local_vf_num == 'h7ff) begin
             `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN4, { tlp_length  == local_tlp_length  ;
                                                                           pf_num      == local_pf_num      ;
                                                                           vf_num      == local_vf_num      ;
                                                                           vf_active   == local_vf_active   ;
                                                                           payload     == local_payload     ;
                                                                           direction   == 1'b1              ; 
                                                                        })
        end
           else if(local_vf_active == 'h1 && local_pf_num == 'h5 && local_vf_num == 'h7ff) begin
             `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN5, { tlp_length  == local_tlp_length  ;
                                                                           pf_num      == local_pf_num      ;
                                                                           vf_num      == local_vf_num      ;
                                                                           vf_active   == local_vf_active   ;
                                                                           payload     == local_payload     ;
                                                                           direction   == 1'b1              ; 
                                                                        })
        end
           else if(local_vf_active == 'h1 && local_pf_num == 'h6 && local_vf_num == 'h7ff) begin
             `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN6, { tlp_length  == local_tlp_length  ;
                                                                           pf_num      == local_pf_num      ;
                                                                           vf_num      == local_vf_num      ;
                                                                           vf_active   == local_vf_active   ;
                                                                           payload     == local_payload     ;
                                                                           direction   == 1'b1              ; 
                                                                        })
        end
           else if(local_vf_active == 'h1 && local_pf_num == 'h7 && local_vf_num == 'h7ff) begin
             `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN7, { tlp_length  == local_tlp_length  ;
                                                                           pf_num      == local_pf_num      ;
                                                                           vf_num      == local_vf_num      ;
                                                                           vf_active   == local_vf_active   ;
                                                                           payload     == local_payload     ;
                                                                           direction   == 1'b1              ; 
                                                                        })
             end
`endif
`ifdef TB_CONFIG_3
	 else if(local_vf_active == 'h1 && local_pf_num == 'h0 && local_vf_num == `RANDOM_VF) begin
             `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN8, { tlp_length  == local_tlp_length  ;
                                                                           pf_num      == local_pf_num      ;
                                                                           vf_num      == local_vf_num      ;
                                                                           vf_active   == local_vf_active   ;
                                                                           payload     == local_payload     ;
                                                                           direction   == 1'b1              ; 
                                                                        })
         end
          else if(local_vf_active == 'h1 && local_pf_num == 'h1 && local_vf_num == `RANDOM_VF) begin
             `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN9, { tlp_length  == local_tlp_length  ;
                                                                           pf_num      == local_pf_num      ;
                                                                           vf_num      == local_vf_num      ;
                                                                           vf_active   == local_vf_active   ;
                                                                           payload     == local_payload     ; 
                                                                           direction   == 1'b1              ;
                                                                        })
        end
           else if(local_vf_active == 'h1 && local_pf_num == 'h2 && local_vf_num == `RANDOM_VF) begin
             `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN10, { tlp_length  == local_tlp_length  ;
                                                                           pf_num      == local_pf_num      ;
                                                                           vf_num      == local_vf_num      ;
                                                                           vf_active   == local_vf_active   ;
                                                                           payload     == local_payload     ;
                                                                           direction   == 1'b1              ; 
                                                                        })
         end
           else if(local_vf_active == 'h1 && local_pf_num == 'h3 && local_vf_num == `RANDOM_VF) begin
               `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN11, { tlp_length  == local_tlp_length  ;
                                                                            pf_num      == local_pf_num      ;
                                                                            vf_num      == local_vf_num      ;
                                                                            vf_active   == local_vf_active   ;
                                                                            payload     == local_payload     ;
                                                                           direction   == 1'b1              ; 
                                                                            })
         end
           else if(local_vf_active == 'h1 && local_pf_num == 'h4 && local_vf_num == `RANDOM_VF) begin
                `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN12, { tlp_length  == local_tlp_length  ;
                                                                          pf_num      == local_pf_num      ;
                                                                          vf_num      == local_vf_num      ;
                                                                          vf_active   == local_vf_active   ;
                                                                          payload     == local_payload     ;
                                                                           direction   == 1'b1              ; 
                                                                       })
         end
           else if(local_vf_active == 'h1 && local_pf_num == 'h5 && local_vf_num == `RANDOM_VF) begin
                `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN13, { tlp_length  == local_tlp_length  ;
                                                                          pf_num      == local_pf_num      ;
                                                                          vf_num      == local_vf_num      ;
                                                                          vf_active   == local_vf_active   ;
                                                                          payload     == local_payload     ;
                                                                           direction   == 1'b1              ; 
                                                                       })
         end
           else if(local_vf_active == 'h1 && local_pf_num == 'h6 && local_vf_num == `RANDOM_VF) begin
                `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN14, { tlp_length  == local_tlp_length  ;
                                                                          pf_num      == local_pf_num      ;
                                                                          vf_num      == local_vf_num      ;
                                                                          vf_active   == local_vf_active   ;
                                                                          payload     == local_payload     ;
                                                                           direction   == 1'b1              ; 
                                                                       })
         end
           else if(local_vf_active == 'h1 && local_pf_num == 'h7 && local_vf_num == `RANDOM_VF) begin
                `uvm_do_on_with(master_seq, p_sequencer.master_sequencer_DN15, { tlp_length  == local_tlp_length  ;
                                                                         pf_num      == local_pf_num      ;
                                                                         vf_num      == local_vf_num      ;
                                                                         vf_active   == local_vf_active   ;
                                                                         payload     == local_payload     ;
                                                                           direction   == 1'b1              ; 
                                                                      })
             end
`endif
`ifdef TB_CONFIG_4
    `include "pf_vf_config4_traffic.sv"
`endif
           end//}

`ifndef TB_CONFIG_4
           end//}
           end//}
`endif
        `uvm_info(get_name(), "Exiting sequence...", UVM_LOW)
    endtask : body

endclass

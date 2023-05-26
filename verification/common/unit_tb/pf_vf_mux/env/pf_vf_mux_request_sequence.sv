// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: MIT

/**
 * Abstract:
 * class pf_vf_mux_request_sequence defines a sequence that generates a
 * random discrete master transaction.  This sequence is used by the
 * axi_master_random_discrete_virtual_sequence which is set up as the default
 * sequence for this environment.
 *
 * Execution phase: main_phase
 * Sequencer: Virtual sequencer in AXI System ENV
 */

`ifndef GUARD_pf_vf_mux_request_sequence_SV
`define GUARD_pf_vf_mux_request_sequence_SV

`include "pf_vf_mux_virtual_sequencer.sv"

//------------------------------------------------------------------------------
//
// CLASS: pf_vf_mux_request_sequence 
//
//------------------------------------------------------------------------------

typedef enum bit[7:0] {MRD_32='h0,MRD_64='h20,MWR_32='h40,MWR_64='h60,CPL='h4a} fmt_type;

class pf_vf_mux_request_sequence extends svt_axi_master_base_sequence;

   /** Parameter that controls the number of transactions that will be generated */
   rand int unsigned sequence_length ;
   rand fmt_type fmt_type ;
   rand bit vf_active;
   rand bit [2:0] pf_num ;
   rand bit [10:0] vf_num ;
   rand bit [9:0] tlp_length ;
   rand bit [255:0] payload ;
   rand bit user_vendor_all_bits;
   bit [511:0] payload_next0 ;
   bit [511:0] payload_next1 ;
   bit [511:0] payload_next2 ;
   bit [511:0] payload_next3 ;
   rand bit direction ;         // 0 - downstream transaction, 1 - upstream transaction
   int packet_size ;

  /** UVM Object Utility macro */
  `uvm_object_utils(pf_vf_mux_request_sequence)

  /** Constrain the sequence length to a reasonable value */
  constraint reasonable_sequence_length {
    sequence_length <= 100;
  }

  constraint fmt_range { fmt_type dist { MRD_32 := 5, MRD_64 := 5, MWR_32 := 12, MWR_64 := 5, CPL := 5}; }

  /** Class Constructor */
  function new (string name = "pf_vf_mux_request_sequence");
     super.new(name);
  endfunction : new

  function bit[9:0] generate_vendor_id(bit[2:0] pf_num, bit[10:0] vf_num, bit vf_active);
     bit[9:0] tuser_vendor;
     if(pf_num=='h0 && vf_num=='h0 && vf_active=='h0)
        tuser_vendor = 'd0;
     else if(pf_num=='h1 && vf_num=='h0 && vf_active=='h0)
        tuser_vendor = 'd1;
     else if(pf_num=='h2 && vf_num=='h0 && vf_active=='h0)
        tuser_vendor = 'd2;
     else if(pf_num=='h3 && vf_num=='h0 && vf_active=='h0)
        tuser_vendor = 'd3;
     else if(pf_num=='h4 && vf_num=='h0 && vf_active=='h0)
        tuser_vendor = 'd4;
     else if(pf_num=='h5 && vf_num=='h0 && vf_active=='h0)
        tuser_vendor = 'd5;
     else if(pf_num=='h6 && vf_num=='h0 && vf_active=='h0)
        tuser_vendor = 'd6;
     else if(pf_num=='h7 && vf_num=='h0 && vf_active=='h0)
        tuser_vendor = 'd7;
     else if(pf_num=='h0 && vf_num=='h0 && vf_active=='h1)
        tuser_vendor = 'd8;
     else if(pf_num=='h1 && vf_num=='h0 && vf_active=='h1)
        tuser_vendor = 'd9;
     else if(pf_num=='h2 && vf_num=='h0 && vf_active=='h1)
        tuser_vendor = 'd10;
     else if(pf_num=='h3 && vf_num=='h0 && vf_active=='h1)
        tuser_vendor = 'd11;
     else if(pf_num=='h4 && vf_num=='h0 && vf_active=='h1)
        tuser_vendor = 'd12;
     else if(pf_num=='h5 && vf_num=='h0 && vf_active=='h1)
        tuser_vendor = 'd13;
     else if(pf_num=='h6 && vf_num=='h0 && vf_active=='h1)
        tuser_vendor = 'd14;
     else if(pf_num=='h7 && vf_num=='h0 && vf_active=='h1)
        tuser_vendor = 'd15;
     else if(pf_num=='h0 && vf_num=='h7ff && vf_active=='h1)
        tuser_vendor = 'd16;
     else if(pf_num=='h1 && vf_num=='h7ff && vf_active=='h1)
        tuser_vendor = 'd17;
     else if(pf_num=='h2 && vf_num=='h7ff && vf_active=='h1)
        tuser_vendor = 'd18;
     else if(pf_num=='h3 && vf_num=='h7ff && vf_active=='h1)
        tuser_vendor = 'd19;
     else if(pf_num=='h4 && vf_num=='h7ff && vf_active=='h1)
        tuser_vendor = 'd20;
     else if(pf_num=='h5 && vf_num=='h7ff && vf_active=='h1)
        tuser_vendor = 'd21;
     else if(pf_num=='h6 && vf_num=='h7ff && vf_active=='h1)
        tuser_vendor = 'd22;
     else if(pf_num=='h7 && vf_num=='h7ff && vf_active=='h1)
        tuser_vendor = 'd23;
     `ifdef TB_CONFIG_3   
     else if(pf_num=='h0 && vf_num==`RANDOM_VF && vf_active=='h1)
        tuser_vendor = 'd24;
     else if(pf_num=='h1 && vf_num==`RANDOM_VF && vf_active=='h1)
        tuser_vendor = 'd25;
     else if(pf_num=='h2 && vf_num==`RANDOM_VF && vf_active=='h1)
        tuser_vendor = 'd26;
     else if(pf_num=='h3 && vf_num==`RANDOM_VF && vf_active=='h1)
        tuser_vendor = 'd27;
     else if(pf_num=='h4 && vf_num==`RANDOM_VF && vf_active=='h1)
        tuser_vendor = 'd28;
     else if(pf_num=='h5 && vf_num==`RANDOM_VF && vf_active=='h1)
        tuser_vendor = 'd29;
     else if(pf_num=='h6 && vf_num==`RANDOM_VF && vf_active=='h1)
        tuser_vendor = 'd30;
     else if(pf_num=='h7 && vf_num==`RANDOM_VF && vf_active=='h1)
        tuser_vendor = 'd31;
     `endif   

     tuser_vendor[7] = direction ; 
     return tuser_vendor;
  endfunction

  function bit[511:0] generate_payload_based_on_length(bit[9:0] length); 
     bit[511:0] payload,local_my_payload,random_value ;
     local_my_payload = 'h0;
     assert(std::randomize(random_value));
     for(int j=0; j < (length*32); j++) local_my_payload[j] = 1'b1;
     payload = (random_value) & local_my_payload;
    `uvm_info("body", $sformatf("Random Value = %0h Local Payload = %0h Payload Actual = %0h",random_value,local_my_payload,payload), UVM_LOW);
     return payload;
  endfunction

  function bit[63:0] generate_tkeep_based_on_length(int num);
    bit [63:0] tkeep_value ;
    if(num == 1) tkeep_value = 'hf;
    else if(num == 2) tkeep_value = 'hff;
    else if(num == 3) tkeep_value = 'hfff;
    else if(num == 4) tkeep_value = 'hffff;
    else if(num == 5) tkeep_value = 'hf_ffff;
    else if(num == 6) tkeep_value = 'hff_ffff;
    else if(num == 7) tkeep_value = 'hfff_ffff;
    else if(num == 8) tkeep_value = 'hffff_ffff;
    else if(num == 9) tkeep_value = 'hf_ffff_ffff;
    else if(num == 10) tkeep_value = 'hff_ffff_ffff;
    else if(num == 11) tkeep_value = 'hfff_ffff_ffff;
    else if(num == 12) tkeep_value = 'hffff_ffff_ffff;
    else if(num == 13) tkeep_value = 'hf_ffff_ffff_ffff;
    else if(num == 14) tkeep_value = 'hff_ffff_ffff_ffff;
    else if(num == 15) tkeep_value = 'hfff_ffff_ffff_ffff;
    else if(num == 16) tkeep_value = 'hffff_ffff_ffff_ffff;
    return tkeep_value;
  endfunction

  virtual task body();
    bit status;
    bit[9:0] tuser_vendor;
    bit[63:0] tkeep_packet;
    bit[63:0] tkeep_packet_next0;
    bit[63:0] tkeep_packet_next1;
    bit[63:0] tkeep_packet_next2;
    bit[63:0] tkeep_packet_next3;

    `uvm_info("body", "Entered ...", UVM_LOW)

    //status = uvm_config_db#(int unsigned)::get(null, get_full_name(), "sequence_length", sequence_length);
    //`uvm_info("body", $sformatf("sequence_length is %0d as a result of %0s.", sequence_length, status ? "config DB" : "randomization"), UVM_LOW);

      `uvm_info("body", $sformatf("Calling `uvm_do inside request sequence with TLP Length as %d",tlp_length), UVM_LOW)
      `ifdef COVER_USER_VENDOR
        if(user_vendor_all_bits==1'b1)
        tuser_vendor = 'h3ff ;  
        else
        tuser_vendor = 'h0 ;  
      `else
        tuser_vendor = generate_vendor_id(pf_num,vf_num,vf_active) ;  
      `endif 
      if(tlp_length < 'd9)
       begin
        packet_size = 1 ;  
        tkeep_packet = generate_tkeep_based_on_length(8+tlp_length);
        `uvm_info("body", $sformatf("TKEEP FROM FUNCTION = %h",tkeep_packet), UVM_LOW)
        `uvm_do_with(req, 
         { 
          xact_type == svt_axi_transaction::DATA_STREAM; 
          tdata.size() == packet_size;
          stream_burst_length == packet_size;
          tdata[0][9:0]     == tlp_length;
          tdata[0][18:10]   == 'h0       ;  // Lightweight Notification-TLP Hint-TLP digest-Error poison-Attribute
          tdata[0][22:20]   == 'h0       ;  // Traffic Class
          tdata[0][31:24]   == fmt_type  ;  // FMT-Type
          tdata[0][159:128] == 'h0       ;  // Prefix Related Fields
	        tdata[0][162:160] == pf_num    ;
	        tdata[0][173:163] == vf_num    ;
	        tdata[0][174:174] == vf_active ;
	        tdata[0][191:184] == 'h0       ;  // Bar Number
          tdata[0][511:256] == payload   ;
          tuser[0][9:0]     == tuser_vendor     ;
          tkeep[0][63:0]    == tkeep_packet       ;
        })
       `svt_note("body", $sformatf("sent xact - %s", `SVT_AXI_STREAM_PRINT_PREFIX(req)));
       `ifdef RESET_PF_VF
          #10;
          `uvm_info("body", "reset_pf_vf", UVM_LOW)
       `else
          #($urandom_range(2000,0));
          `uvm_info("body", "normal_pf_vf", UVM_LOW)
       `endif
       end
      else if(tlp_length > 'd8 && tlp_length < 'd25)
       begin
        packet_size = 2 ;  
        payload_next0 = generate_payload_based_on_length(tlp_length-8);
        tkeep_packet = generate_tkeep_based_on_length(16);
        tkeep_packet_next0 = generate_tkeep_based_on_length(tlp_length-8);
        `uvm_do_with(req, 
         { 
          xact_type == svt_axi_transaction::DATA_STREAM; 
          tdata.size() == packet_size;
          stream_burst_length == packet_size;
          tdata[0][9:0]     == tlp_length;
          tdata[0][18:10]   == 'h0       ;  // Lightweight Notification-TLP Hint-TLP digest-Error poison-Attribute
          tdata[0][22:20]   == 'h0       ;  // Traffic Class
          tdata[0][31:24]   == fmt_type  ;  // FMT-Type
          tdata[0][159:128] == 'h0       ;  // Prefix Related Fields
	        tdata[0][162:160] == pf_num    ;
	        tdata[0][173:163] == vf_num    ;
	        tdata[0][174:174] == vf_active ;
	        tdata[0][191:184] == 'h0       ;  // Bar Number
          tdata[0][511:256] == payload   ;
          tuser[0][9:0]     == tuser_vendor     ;
          tkeep[0][63:0]    == tkeep_packet;
          tdata[1]          == payload_next0   ;
          tuser[1][9:0]     == tuser_vendor     ;
          tkeep[1][63:0]    == tkeep_packet_next0 ;
        })
       `svt_note("body", $sformatf("sent xact - %s", `SVT_AXI_STREAM_PRINT_PREFIX(req)));
       `ifdef RESET_PF_VF
          #10;
          `uvm_info("body", "reset_pf_vf", UVM_LOW)
       `else
          #($urandom_range(2000,0));
          `uvm_info("body", "normal_pf_vf", UVM_LOW)
       `endif
       end
      else if(tlp_length > 'd24 && tlp_length < 'd41)
       begin
        packet_size = 3 ;  
        payload_next0 = generate_payload_based_on_length(16);
        payload_next1 = generate_payload_based_on_length(tlp_length-24);
        tkeep_packet = generate_tkeep_based_on_length(16);
        tkeep_packet_next0 = generate_tkeep_based_on_length(16);
        tkeep_packet_next1 = generate_tkeep_based_on_length(tlp_length-24);
        `uvm_do_with(req, 
         { 
          xact_type == svt_axi_transaction::DATA_STREAM; 
          tdata.size() == packet_size;
          stream_burst_length == packet_size;
          tdata[0][9:0]     == tlp_length;
          tdata[0][18:10]   == 'h0       ;  // Lightweight Notification-TLP Hint-TLP digest-Error poison-Attribute
          tdata[0][22:20]   == 'h0       ;  // Traffic Class
          tdata[0][31:24]   == fmt_type  ;  // FMT-Type
          tdata[0][159:128] == 'h0       ;  // Prefix Related Fields
	        tdata[0][162:160] == pf_num    ;
	        tdata[0][173:163] == vf_num    ;
	        tdata[0][174:174] == vf_active ;
	        tdata[0][191:184] == 'h0       ;  // Bar Number
          tdata[0][511:256] == payload   ;
          tuser[0][9:0]     == tuser_vendor     ;
          tkeep[0][63:0]    == tkeep_packet;
          tdata[1]          == payload_next0   ;
          tuser[1][9:0]     == tuser_vendor     ;
          tkeep[1][63:0]    == tkeep_packet_next0;
          tdata[2]          == payload_next1   ;
          tuser[2][9:0]     == tuser_vendor     ;
          tkeep[2][63:0]    == tkeep_packet_next1;
        })
       `svt_note("body", $sformatf("sent xact - %s", `SVT_AXI_STREAM_PRINT_PREFIX(req)));
       `ifdef RESET_PF_VF
          #10;
          `uvm_info("body", "reset_pf_vf", UVM_LOW)
       `else
          #($urandom_range(2000,0));
          `uvm_info("body", "normal_pf_vf", UVM_LOW)
       `endif
       end
        else if(tlp_length > 'd40 && tlp_length < 'd57)
       begin
        packet_size = 4 ;  
        payload_next0 = generate_payload_based_on_length(16);
        payload_next1 = generate_payload_based_on_length(16);
        payload_next2 = generate_payload_based_on_length(tlp_length-40);
        tkeep_packet = generate_tkeep_based_on_length(16);
        tkeep_packet_next0 = generate_tkeep_based_on_length(16);
        tkeep_packet_next1 = generate_tkeep_based_on_length(16);
        tkeep_packet_next2 = generate_tkeep_based_on_length(tlp_length-40);
        `uvm_do_with(req, 
         { 
          xact_type == svt_axi_transaction::DATA_STREAM; 
          tdata.size() == packet_size;
          stream_burst_length == packet_size;
          tdata[0][9:0]     == tlp_length;
          tdata[0][18:10]   == 'h0       ;  // Lightweight Notification-TLP Hint-TLP digest-Error poison-Attribute
          tdata[0][22:20]   == 'h0       ;  // Traffic Class
          tdata[0][31:24]   == fmt_type  ;  // FMT-Type
          tdata[0][159:128] == 'h0       ;  // Prefix Related Fields
	        tdata[0][162:160] == pf_num    ;
	        tdata[0][173:163] == vf_num    ;
	        tdata[0][174:174] == vf_active ;
	        tdata[0][191:184] == 'h0       ;  // Bar Number
          tdata[0][511:256] == payload   ;
          tuser[0][9:0]     == tuser_vendor     ;
          tkeep[0][63:0]    == tkeep_packet;
          tdata[1]          == payload_next0   ;
          tuser[1][9:0]     == tuser_vendor     ;
          tkeep[1][63:0]    == tkeep_packet_next0;
          tdata[2]          == payload_next1   ;
          tuser[2][9:0]     == tuser_vendor     ;
          tkeep[2][63:0]    == tkeep_packet_next1;
          tdata[3]          == payload_next2   ;
          tuser[3][9:0]     == tuser_vendor     ;
          tkeep[3][63:0]    == tkeep_packet_next2;
        })
       `svt_note("body", $sformatf("sent xact - %s", `SVT_AXI_STREAM_PRINT_PREFIX(req)));
       `ifdef RESET_PF_VF
          #10;
          `uvm_info("body", "reset_pf_vf", UVM_LOW)
       `else
          #($urandom_range(2000,0));
          `uvm_info("body", "normal_pf_vf", UVM_LOW)
       `endif
       end
      else if(tlp_length > 'd56 && tlp_length < 'd73)
       begin
        packet_size = 5 ;  
        payload_next0 = generate_payload_based_on_length(16);
        payload_next1 = generate_payload_based_on_length(16);
        payload_next2 = generate_payload_based_on_length(16);
        payload_next3 = generate_payload_based_on_length(tlp_length-56);
        tkeep_packet = generate_tkeep_based_on_length(16);
        tkeep_packet_next0 = generate_tkeep_based_on_length(16);
        tkeep_packet_next1 = generate_tkeep_based_on_length(16);
        tkeep_packet_next2 = generate_tkeep_based_on_length(16);
        tkeep_packet_next3 = generate_tkeep_based_on_length(tlp_length-56);
        `uvm_do_with(req, 
         { 
          xact_type == svt_axi_transaction::DATA_STREAM; 
          tdata.size() == packet_size;
          stream_burst_length == packet_size;
          tdata[0][9:0]     == tlp_length;
          tdata[0][18:10]   == 'h0       ;  // Lightweight Notification-TLP Hint-TLP digest-Error poison-Attribute
          tdata[0][22:20]   == 'h0       ;  // Traffic Class
          tdata[0][31:24]   == fmt_type  ;  // FMT-Type
          tdata[0][159:128] == 'h0       ;  // Prefix Related Fields
	        tdata[0][162:160] == pf_num    ;
	        tdata[0][173:163] == vf_num    ;
	        tdata[0][174:174] == vf_active ;
	        tdata[0][191:184] == 'h0       ;  // Bar Number
          tdata[0][511:256] == payload   ;
          tuser[0][9:0]     == tuser_vendor     ;
          tkeep[0][63:0]    == tkeep_packet;
          tdata[1]          == payload_next0   ;
          tuser[1][9:0]     == tuser_vendor     ;
          tkeep[1][63:0]    == tkeep_packet_next0;
          tdata[2]          == payload_next1   ;
          tuser[2][9:0]     == tuser_vendor     ;
          tkeep[2][63:0]    == tkeep_packet_next1;
          tdata[3]          == payload_next2   ;
          tuser[3][9:0]     == tuser_vendor     ;
          tkeep[3][63:0]    == tkeep_packet_next2;
          tdata[4]          == payload_next3   ;
          tuser[4][9:0]     == tuser_vendor     ;
          tkeep[4][63:0]    == tkeep_packet_next3;
        })
       `svt_note("body", $sformatf("sent xact - %s", `SVT_AXI_STREAM_PRINT_PREFIX(req)));
       `ifdef RESET_PF_VF
          #10;
          `uvm_info("body", "reset_pf_vf", UVM_LOW)
       `else
          #($urandom_range(2000,0));
          `uvm_info("body", "normal_pf_vf", UVM_LOW)
       `endif


       end

    `uvm_info("body", "Exiting...", UVM_LOW)
  endtask: body
  
endclass: pf_vf_mux_request_sequence

`endif // GUARD_pf_vf_mux_request_sequence_SV

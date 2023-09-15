// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: MIT

`ifndef pf_vf_mux_scoreboard
`define pf_vf_mux_scoreboard

`uvm_analysis_imp_decl(_axi_port_tx)
`uvm_analysis_imp_decl(_axi_port_rx)

class pf_vf_mux_scoreboard extends uvm_scoreboard;

    svt_axi_transaction axi_tx_trans;
    svt_axi_transaction axi_rx_trans;
    
    bit[511:0] axi_payload_tx_q[$];
    bit[511:0] axi_payload_tx_q_actual[$];
    bit[511:0] axi_payload_rx_q[$];
    bit[31:0] awlength;
		int packet_count;

    `uvm_component_utils(pf_vf_mux_scoreboard)

     //Port from axi interface
     uvm_analysis_imp_axi_port_tx#(svt_axi_transaction, pf_vf_mux_scoreboard) axi_port_tx;
     uvm_analysis_imp_axi_port_rx#(svt_axi_transaction, pf_vf_mux_scoreboard) axi_port_rx;


     //TLM FIFO for axi rx and tx
      uvm_tlm_analysis_fifo #(svt_axi_transaction) axi_tx_fifo;
      uvm_tlm_analysis_fifo #(svt_axi_transaction) axi_rx_fifo;

   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction : new


   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      axi_port_tx  = new("axi_port_tx", this);
      axi_port_rx  = new("axi_port_rx", this);
      axi_tx_fifo     = new("axi_tx_fifo", this);
      axi_rx_fifo     = new("axi_rx_fifo", this);
   endfunction : build_phase

 function void write_axi_port_tx(svt_axi_transaction trans);
    $cast(axi_tx_trans , trans.clone());
    `ifdef DEBUG
    `uvm_info(get_type_name(),$sformatf(" SCB:: Pkt received from AXI Lite slave ENV \n %s",axi_tx_trans.sprint()),UVM_LOW)
    `endif
    axi_tx_fifo.write(axi_tx_trans);
 endfunction // write_axi_port_tx

function void write_axi_port_rx(svt_axi_transaction trans);
    $cast(axi_rx_trans , trans.clone());
    `ifdef DEBUG
    `uvm_info(get_type_name(),$sformatf(" SCB:: Pkt received from AXI Lite master ENV \n %s",axi_rx_trans.sprint()),UVM_LOW)
    `endif
    axi_rx_fifo.write(axi_rx_trans);
endfunction // write_axi_port_rx


task run_phase(uvm_phase phase);
    svt_axi_transaction axi_tx_pkt;
    svt_axi_transaction axi_rx_pkt;   
    int i;
    int check_counter=0; 
		packet_count=0;
    super.run_phase(phase);
   //TX = Slave and RX = Master for first case
    forever begin
     axi_tx_fifo.get(axi_tx_pkt);
     if(axi_tx_pkt.tdata[0][9:0] < 'd9) 
       begin
         axi_payload_tx_q.push_back(axi_tx_pkt.tdata[0]);
       end
     else if((axi_tx_pkt.tdata[0][9:0] > 'd8) && (axi_tx_pkt.tdata[0][9:0] < 'd25)) 
       begin
         axi_payload_tx_q.push_back(axi_tx_pkt.tdata[0]);
         axi_payload_tx_q.push_back(axi_tx_pkt.tdata[1]);
       end
     else if((axi_tx_pkt.tdata[0][9:0] > 'd24) && (axi_tx_pkt.tdata[0][9:0] < 'd41))   
       begin
         axi_payload_tx_q.push_back(axi_tx_pkt.tdata[0]);
         axi_payload_tx_q.push_back(axi_tx_pkt.tdata[1]);
         axi_payload_tx_q.push_back(axi_tx_pkt.tdata[2]);
       end
     else if((axi_tx_pkt.tdata[0][9:0] > 'd40) && (axi_tx_pkt.tdata[0][9:0] < 'd57))   
       begin
         axi_payload_tx_q.push_back(axi_tx_pkt.tdata[0]);
         axi_payload_tx_q.push_back(axi_tx_pkt.tdata[1]);
         axi_payload_tx_q.push_back(axi_tx_pkt.tdata[2]);
         axi_payload_tx_q.push_back(axi_tx_pkt.tdata[3]);
       end
     else if((axi_tx_pkt.tdata[0][9:0] > 'd56) && (axi_tx_pkt.tdata[0][9:0] < 'd73))   
       begin
         axi_payload_tx_q.push_back(axi_tx_pkt.tdata[0]);
         axi_payload_tx_q.push_back(axi_tx_pkt.tdata[1]);
         axi_payload_tx_q.push_back(axi_tx_pkt.tdata[2]);
         axi_payload_tx_q.push_back(axi_tx_pkt.tdata[3]);
         axi_payload_tx_q.push_back(axi_tx_pkt.tdata[4]);
       end
     forever begin
         axi_rx_fifo.get(axi_rx_pkt);
         if((axi_rx_pkt.tdata[0][162:160] == axi_tx_pkt.tdata[0][162:160]) && (axi_rx_pkt.tdata[0][173:163] == axi_tx_pkt.tdata[0][173:163]) && (axi_rx_pkt.tdata[0][174:174] == axi_tx_pkt.tdata[0][174:174]) ) 
           begin
            if(axi_rx_pkt.tdata[0][9:0] < 'd9) 
              begin
                axi_payload_rx_q.push_back(axi_rx_pkt.tdata[0]);
              end
            else if((axi_rx_pkt.tdata[0][9:0] > 'd8) && (axi_rx_pkt.tdata[0][9:0] < 'd25)) 
              begin
                axi_payload_rx_q.push_back(axi_rx_pkt.tdata[0]);
                axi_payload_rx_q.push_back(axi_rx_pkt.tdata[1]);
              end
            else if((axi_rx_pkt.tdata[0][9:0] > 'd24) && (axi_rx_pkt.tdata[0][9:0] < 'd41))   
              begin
                axi_payload_rx_q.push_back(axi_rx_pkt.tdata[0]);
                axi_payload_rx_q.push_back(axi_rx_pkt.tdata[1]);
                axi_payload_rx_q.push_back(axi_rx_pkt.tdata[2]);
              end
            else if((axi_rx_pkt.tdata[0][9:0] > 'd40) && (axi_rx_pkt.tdata[0][9:0] < 'd57))   
              begin
                axi_payload_rx_q.push_back(axi_rx_pkt.tdata[0]);
                axi_payload_rx_q.push_back(axi_rx_pkt.tdata[1]);
                axi_payload_rx_q.push_back(axi_rx_pkt.tdata[2]);
                axi_payload_rx_q.push_back(axi_rx_pkt.tdata[3]);
              end
            else if((axi_rx_pkt.tdata[0][9:0] > 'd56) && (axi_rx_pkt.tdata[0][9:0] < 'd73))   
              begin
                axi_payload_rx_q.push_back(axi_rx_pkt.tdata[0]);
                axi_payload_rx_q.push_back(axi_rx_pkt.tdata[1]);
                axi_payload_rx_q.push_back(axi_rx_pkt.tdata[2]);
                axi_payload_rx_q.push_back(axi_rx_pkt.tdata[3]);
                axi_payload_rx_q.push_back(axi_tx_pkt.tdata[4]);
              end
			      packet_count++;
            break;
          end
     end
     check_counter++;
     `ifdef DEBUG
     `uvm_info(get_type_name(),$sformatf("QUEUE TX= %p",axi_payload_tx_q),UVM_LOW);
     `uvm_info(get_type_name(),$sformatf("QUEUE RX= %p",axi_payload_rx_q),UVM_LOW);
     `endif
    
    `ifndef ERR_CASE
       begin
       `uvm_info(get_type_name(),$sformatf(" FOREACH COUNTER = %d \n",check_counter),UVM_LOW)
       compare_data();
       end
    `endif
    end

   endtask:run_phase

function compare_data;
     bit [511:0] exp_data, obs_data;     
     int index;
       
     while (axi_payload_tx_q.size()!==0 && axi_payload_rx_q.size()!==0) begin
          obs_data = axi_payload_tx_q.pop_front();
          exp_data = axi_payload_rx_q.pop_front();
          if (exp_data == obs_data) begin
             `uvm_info(get_type_name(),$sformatf("DATA MATCHED EXP_DATA = 'h%h: OBS_DATA = `h%h", exp_data, obs_data),UVM_LOW);
          end 
          else begin
             `uvm_error(get_type_name(), $sformatf("DATA MISMATCHED EXP_DATA = `h%h, OBS_DATA = `h%h ",exp_data, obs_data));
          end
       end
   endfunction : compare_data

endclass: pf_vf_mux_scoreboard

`endif // pf_vf_mux_scoreboard

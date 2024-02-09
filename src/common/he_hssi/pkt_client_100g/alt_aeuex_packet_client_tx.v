// Copyright (C) 2001-2021 Intel Corporation
// SPDX-License-Identifier: MIT

`timescale 1 ps / 1 ps

module alt_aeuex_packet_client_tx #(
	parameter WORDS = 8,
	parameter WIDTH = 64,
	parameter SOP_ON_LANE0       = 1'b0
)(
	input arst,
	input tx_pkt_gen_en,

	input [1:0] pattern_mode, //00,random, 01, fixed, 10 , incr
	input [13:0] start_addr, //also fixed addr
	input [13:0] end_addr,
	input [31:0] pkt_num, //number of packets to send in one start_pkt_gen pulse
	input end_sel,		//0, controled by stop_pkt_gen, 1 , controlled by pkt_num
	input ipg_sel,    //0, gap is random, 1, no gap between packets
	input [47:0] DEST_ADDR,
	input [47:0] SRC_ADDR,
	
	// TX to Ethernet
	input clk_tx,
	input tx_ack,
	output [WIDTH*WORDS-1:0] tx_data,
	output  tx_start,
	output tx_end_pos,
	output tx_valid,
	output [5:0]		tx_empty
);

///////////////////////////////////////////////////////////////
// stop and restart the ack
///////////////////////////////////////////////////////////////
/*
wire tx_ack_internal;
wire [WIDTH*WORDS-1:0] tx_data_internal;
wire  tx_start_internal ;
wire  tx_end_pos_internal ;
wire [5:0] tx_empty_internal;
wire tx_valid_internal ;

alt_aeuex_ack_skid_tx ask 
(
	.clk(clk_tx),
	
	// from the internal TX sources
	.dat_i({tx_empty_internal,tx_valid_internal,tx_start_internal,tx_end_pos_internal,tx_data_internal}),
	.ack_i(tx_ack_internal),
	
	// to the alt_aeuex_top level pins, feeding the transmitter
	.dat_o({tx_empty,tx_valid,tx_start,tx_end_pos,tx_data}),
	.ack_o(tx_ack)	
);
defparam ask .WIDTH = WORDS * WIDTH + 6 + 3;
*/
wire reset_sync = arst;
/*
alt_aeuex_sync_arst sync_arst (
    .clk(clk_tx),
    .arst(arst),
    .sync_arst(reset_sync)
);
*/
///////////////////////////////////////////////////////////////
// Packet generator
///////////////////////////////////////////////////////////////
wire tx_pkt_gen_en_sync;
wire [WIDTH*WORDS-1:0]	dout_ps;	// regular left to right
wire 	dout_start_ps;  // first of any 8 bytes
wire 	dout_end_pos_ps; // any byte
wire [5:0] dout_empty;
wire dout_valid;
 
//assign tx_empty         = alt_aeuex_wide_encode64to6(tx_end_pos);

alt_aeuex_packet_gen_tx ps (
	.clk(clk_tx),
	.reset(reset_sync),
	.ena(tx_ack),
	.idle(!tx_pkt_gen_en_sync),
	.pattern_mode(pattern_mode),
	.start_addr(start_addr),
	.end_addr(end_addr),
	.pkt_num (pkt_num),
	.end_sel(end_sel),
	.ipg_sel(ipg_sel),
	.SRC_ADDR(SRC_ADDR),
	.DEST_ADDR(DEST_ADDR),
		
	.sop(tx_start),
	.eop(tx_end_pos),
	.dout(tx_data),
	.empty(tx_empty),
	.valid(tx_valid)

);
defparam ps  .WORDS = WORDS;
defparam ps  .WIDTH = WIDTH;
defparam ps  .SOP_ON_LANE0 = SOP_ON_LANE0;
/*
// TX output muxing
always @(posedge clk_tx) begin
	if (tx_ack_internal) begin
		tx_start_internal <= dout_start_ps;
		tx_end_pos_internal <= dout_end_pos_ps;
		tx_data_internal <= dout_ps;
		tx_empty_internal <= dout_empty;
		tx_valid_internal <= dout_valid;
	end
end
*/
reg [3:0] tx_ctrls = 4'b0101;
alt_aeuex_pkt_gen_sync ss0 (
	.clk(clk_tx),
	.din(tx_pkt_gen_en),
	.dout(tx_pkt_gen_en_sync)
);
defparam ss0 .WIDTH = 1;

//------------------------------------------------------
function [5:0] alt_aeuex_wide_encode64to6;
input [63:0] in;

reg    [5:0] out;
integer     j;

begin
    out = 0;
    for (j = 0; j < 64; j = j + 1) begin
        if (in[j])   out = out | j[5:0];
    end
    alt_aeuex_wide_encode64to6 = out;
end
endfunction

//------------------------------------------------------
endmodule

//------------------------------------------------------
//------------------------------------------------------
//------------------------------------------------------
//------------------------------------------------------
//------------------------------------------------------
//------------------------------------------------------
`timescale 1 ps / 1 ps
// baeckler - 06-09-2010
// altera message_off 10199 10230
module alt_aeuex_packet_gen_tx #(
	parameter WORDS = 2,
	parameter WIDTH = 64,
	parameter MORE_SPACING = 1'b1,
	parameter CNTR_PAYLOAD = 1'b0,
	parameter EMPTY_WIDTH = 6,
    parameter SOP_ON_LANE0 = 1'b0
)(
	input clk,
	input reset,
	input ena,//ack
	input idle, //~(pkt gen enable)

	input [1:0] pattern_mode, //00,random, 01, fixed, 10 , incr
	input [13:0] start_addr, //also fixed addr
	input [13:0] end_addr,
	input [31:0] pkt_num, //number of packets to send,
	input end_sel,		//0, controled by stop_pkt_gen, 1 , controlled by pkt_num
	input ipg_sel,    //0, gap is random, 1, no gap between packets
	input [47:0] DEST_ADDR,
	input [47:0] SRC_ADDR,

		
	output reg sop,
	output reg eop,
	output reg [WORDS*WIDTH-1:0] dout,
	output reg [EMPTY_WIDTH-1:0] empty,
	output reg valid	

);

/////////////////////////////////////////////////
// build some semi reasonable random bits

reg [31:0] cntr = 0;
always @(posedge clk) begin
	if (ena) cntr <= cntr + 1'b1;
end

wire [31:0] poly0 = 32'h8000_0241;
reg [31:0] prand0;
always @(posedge clk) begin
    if (reset) begin 
      prand0 <= 32'hffff_ffff;
    end else begin 
	  prand0 <= {prand0[30:0],1'b0} ^ ((prand0[31] ^ cntr[31]) ? poly0 : 32'h0);
    end
end

wire [31:0] poly1 = 32'h8deadfb3;
reg [31:0] prand1;
always @(posedge clk) begin
    if (reset) begin 
      prand1 <= 32'hffff_ffff;
    end else begin
	  prand1 <= {prand1[30:0],1'b0} ^ ((prand1[31] ^ cntr[30]) ? poly1 : 32'h0);
    end
end

reg [15:0] prand2;
always @(posedge clk) begin
    if (reset) begin
      prand2 <= 0;
    end else begin
	  prand2 <= cntr[23:8] ^ prand0[15:0] ^ prand1[15:0];
    end
end

// mostly 1
reg prand3;
always @(posedge clk) begin
    if (reset) begin 
      prand3 <= 1'b0;
    end else begin
	  prand3 <= |(prand0[17:16] ^ prand1[17:16] ^ cntr[25:24]);
    end
end

/////////////////////////////////////////////////

//    localparam DEST_ADDR = 48'h123456780ADD;
//    localparam SRC_ADDR =  48'h876543210ADD;
    // States
    localparam IDLE        = 0,  // Idle state: 
               SOP       = 1,  // SOP stage
               DATA        = 2,  // DATA state
	       EOP	 =3; 	//EOP

reg [1:0] state=0 ;
reg [13:0] packet_length= 0; //total length -4, no CRC in data
reg [13:0] payload_length; //total length -18, no CRC in data
reg byte64;
reg byte128;
reg [15:0] index;


reg nextpacket;
   always @(posedge clk) begin
        if (reset)   nextpacket <= 1'b0;
		  else nextpacket <= ipg_sel ? 1'b1: prand3;
	end

//wire nextpacket= ~prand3;
reg byte64_next;
reg byte128_next;
reg [1:0] state_next;
reg [13:0] packet_length_next =0;
reg [13:0]  payload_length_next=0;
reg [WORDS*WIDTH-1:0] dout_next=0;
reg [EMPTY_WIDTH-1:0] empty_next=0;
reg [15:0] index_next=0;
reg sop_next=0;
reg eop_next=0;
reg valid_next=0;
reg [13:0] packet_length_saved_next;
reg [13:0] packet_length_saved=0;
reg unused_pktlength_flag_next;
reg unused_pktlength_flag=0;

reg [13:0] packet_length_cfg =0;
reg [31:0] pkt_cnt =0;
reg idle_dly =0 ;
wire end_pulse  = idle&(~idle_dly);
wire start_pulse = (~idle)&idle_dly;
reg sleep;
//wire incr_pulse = (state == SOP) &  ena & (~sleep) ;
wire incr_pulse = (byte64 & state == SOP &  ena & ~sleep) | (~byte64 & state == EOP &  ena & ~sleep)  ;

    always @(posedge clk) begin
        if (reset)    begin
		sleep <= 1'b1;
	end
	else if(!end_sel) sleep <= idle;  //pkt_gen control, free running
	else if (start_pulse && ~(pkt_num==0 && (pattern_mode ==2'b01||pattern_mode ==2'b10)) ) sleep <=0;	//start_pkt_gen to trigger start
	else if (pkt_num==1 && pkt_cnt==0 && (pattern_mode ==2'b01|| pattern_mode ==2'b10) && nextpacket && ena && state==SOP) sleep <=1;	//
	else if (start_addr> 14'd68 && pkt_num==2 && pkt_cnt==1  && (pattern_mode ==2'b01|| pattern_mode ==2'b10) && nextpacket && ena && state==SOP) sleep <=1;	//
	else if (start_addr<=14'd68 && pkt_cnt==(pkt_num-2) && state==SOP && nextpacket && ena && (pattern_mode ==2'b01) ) sleep <=1;	//
	else if (end_addr<=14'd68 && pkt_cnt==(pkt_num-2) && state==SOP && nextpacket && ena && (pattern_mode ==2'b10) ) sleep <=1;	//
	//else if (pkt_cnt==pkt_num-1 & pattern_mode ==2'b10) sleep <=1;		//pkt counter to trigger end	
	//else if ((pkt_cnt==(pkt_num-1)) & ((state==IDLE)&nextpacket|state==SOP) & ena & pattern_mode ==2'b01) sleep <=1;	
	else if ((pkt_cnt==(pkt_num-1)) && ((state==IDLE)&&nextpacket||state==SOP) && ena ) sleep <=1;	//pkt counter to trigger end		
   end

    always @(posedge clk) begin
        if (reset)    begin
		idle_dly <= 1'b0;
	end
	else idle_dly <= idle;
   end

    always @(posedge clk) begin
        if (reset)    begin
		packet_length_cfg <= start_addr;	
	end
        else  if(pattern_mode==2'b01)  packet_length_cfg <= start_addr;  //fixed mode, start_addr is the pakcet length
        else  if(pattern_mode==2'b00)  packet_length_cfg <= (prand2[13:0]> 14'd9600 ) ? 14'd9600 : ((prand2[13:0]<14'd64) ? 14'd64  : prand2[13:0] ); //random mode 64-9600
	else  if(pattern_mode==2'b10)  begin //incr mode, from start_addr to end_addr, increase 1 per packet
		if(start_pulse) packet_length_cfg <= start_addr;
		else if(start_addr==end_addr) packet_length_cfg <= start_addr; //always start address
		else if(incr_pulse && (packet_length_cfg==end_addr)) packet_length_cfg <= start_addr; //go back to start address
		else if(packet_length_cfg==start_addr&&start_addr<=14'd68&&state==IDLE&&ena&&nextpacket&&~unused_pktlength_flag) packet_length_cfg <= packet_length_cfg+14'd1;
		else if(incr_pulse) packet_length_cfg <= packet_length_cfg+14'd1;
	
	end
    end

    always @(posedge clk) begin
        if (reset)    begin
		pkt_cnt <= 32'h0;
	end
	else if (start_pulse) pkt_cnt <= 32'h0;
	else if (incr_pulse) pkt_cnt <= pkt_cnt+32'd1;
    end


reg [WIDTH-1:0] rjunk;
always @(posedge clk) begin
    if (reset) begin
      rjunk <= 0;
    end else begin
	  rjunk <= (rjunk << 4'hf) ^ prand2;
    end
end

    always @(posedge clk) begin
        if (reset)    begin
		state <= IDLE;
		packet_length <= 14'h0;
		payload_length <= 14'h0;
		byte64 <= 0;
		dout <= {WORDS*WIDTH{1'b0}};
		empty <={EMPTY_WIDTH{1'b0}};
		index <=32'h0;
		sop <= 1'b0;
		eop <= 1'b0;
		valid <= 1'b0;
		byte128 <= 1'b0;
		unused_pktlength_flag<=1'b0;
		packet_length_saved<=14'h0;
	end
        else       begin
		 state <= state_next; 
		packet_length <= packet_length_next;
		payload_length <= payload_length_next;
		byte64 <= byte64_next;
		dout <= dout_next;
		empty <= empty_next;
		index <= index_next;
		sop <= sop_next;
		eop <= eop_next;
		valid <=valid_next;
		byte128 <=byte128_next;
		unused_pktlength_flag<=unused_pktlength_flag_next;
		packet_length_saved<=packet_length_saved_next;
	end
    end  
 
    //-------------------------------------------------------------------------    
    // Next-state and output logic
    always @(*) begin
        state_next     = IDLE;  // Default next state 

	byte64_next = byte64;
	byte128_next =byte128;
	eop_next = eop;
	sop_next =sop;    
	valid_next =valid;   
	index_next = index; 
	empty_next = empty; 
	packet_length_next= packet_length;
	payload_length_next = payload_length;
	dout_next = dout;
	packet_length_saved_next=packet_length_saved;
	unused_pktlength_flag_next=unused_pktlength_flag;
        case (state)
            IDLE :  begin
                        if (!ena )  state_next = IDLE;
                        else 	begin
				eop_next = 1'b0;
				sop_next =1'b0;
				valid_next =1'b0;
				dout_next <= {WORDS*WIDTH{1'b0}};
				if (sleep) state_next = IDLE;
				else if(nextpacket) begin  
					state_next = SOP;
					//packet_length_next= packet_length_cfg;
					packet_length_next= (unused_pktlength_flag & pattern_mode==2'b10 )? packet_length_saved : packet_length_cfg;
					//payload_length_next = packet_length_cfg -14'd18;
					payload_length_next = (unused_pktlength_flag & pattern_mode==2'b10 )? packet_length_saved-14'd18 : packet_length_cfg -14'd18;
					byte64_next = (packet_length_cfg <=14'd64+14'd4)|(unused_pktlength_flag&(packet_length_saved<=14'd68));
					byte128_next = ((packet_length_cfg<=14'd128+14'd4)& (packet_length_cfg>14'd64+14'd4)) | (unused_pktlength_flag & (packet_length_saved<=14'd128+14'd4)& (packet_length_saved>14'd64+14'd4) );	
					unused_pktlength_flag_next=1'b0;	
			   	end
			end
                    end     
                         
            SOP : begin
				if (!ena) begin
					 state_next = SOP; 
					if(byte64) begin 
						eop_next = 1'b1; 
					end
				end
				else if(byte64)  begin	
					dout_next  = {DEST_ADDR, SRC_ADDR, {2'b00,payload_length},index, {6{rjunk}}};
					sop_next =1'b1;	
					valid_next =1'b1;		  
					eop_next = 1'b1;
					empty_next = 'd64-packet_length[5:0]+6'd4;
					index_next = index + 1'b1;
					if (sleep)  state_next = IDLE;
					//else if(pattern_mode==2'b10) packet_length_next= packet_length_cfg;
					else if ( nextpacket  ) begin
						state_next = SOP; 					
						packet_length_next=packet_length_cfg;
						payload_length_next = packet_length_cfg -14'd18;
						byte64_next = (packet_length_cfg <=14'd64+14'd4)|(unused_pktlength_flag&(packet_length_saved<=14'd68));
						byte128_next = ((packet_length_cfg<=14'd128+14'd4)& (packet_length_cfg>14'd64+14'd4)) | (unused_pktlength_flag & (packet_length_saved<=14'd128+14'd4)& (packet_length_saved>14'd64+14'd4) );	
					end
					else begin
						packet_length_saved_next= packet_length_cfg;//for incr mode only
						unused_pktlength_flag_next = 1'b1;
						state_next = IDLE;
					end
				end
                        	else if(byte128) begin  
					dout_next  = {DEST_ADDR, SRC_ADDR, {2'b00,payload_length},index, {6{rjunk}}};
					sop_next =1'b1;
					valid_next =1'b1;
					eop_next = 1'b0;
					state_next = EOP;
					index_next = index + 1'b1;
					packet_length_next= packet_length - 14'd64;
					empty_next = 'd64-packet_length[5:0]+6'd4;
				end
				else begin   
					dout_next  = {DEST_ADDR, SRC_ADDR, {2'b00,payload_length},index, {6{rjunk}}};
					eop_next = 1'b0;
					sop_next =1'b1;
					valid_next =1'b1;
					state_next = DATA;
					packet_length_next= packet_length - 14'd64;
					empty_next = 'd64-packet_length[5:0]+6'd4;
				end
                  end                      
            DATA: begin         
			if (!ena) state_next = DATA;                        
			else  begin
				sop_next = 1'b0;
				eop_next = 1'b0;
				valid_next =1'b1;
				if (packet_length <= 14'd132) begin
			     		state_next = EOP;   
					index_next = index + 1'b1;
					dout_next = {8{rjunk}};
				end
				else    begin 
					state_next = DATA;      				
					packet_length_next= packet_length - 14'd64;    
					dout_next = {8{rjunk}};
				end
			end	
                  end  
            EOP: begin   
			if (!ena) state_next = EOP;        
                        else begin
				eop_next = 1'b1;
				sop_next = 1'b0;
				valid_next =1'b1;			
				if (sleep)  state_next = IDLE;
                        	else  begin
			
					if (nextpacket)   begin
						state_next = SOP;      
						packet_length_next= packet_length_cfg;
						payload_length_next = packet_length_cfg -14'd18;
						byte64_next = (packet_length_cfg <=14'd64+14'd4)|(unused_pktlength_flag&(packet_length_saved<=14'd68));
						byte128_next = ((packet_length_cfg<=14'd128+14'd4)& (packet_length_cfg>14'd64+14'd4)) | (unused_pktlength_flag & (packet_length_saved<=14'd128+14'd4)& (packet_length_saved>14'd64+14'd4) );		
					end
					else begin
						packet_length_saved_next= packet_length_cfg;//for incr mode only
						unused_pktlength_flag_next = 1'b1;
						state_next = IDLE;
					end         
				end
                    	end  
		end
        endcase
    end

endmodule

//-------------------------------------------------
// baeckler - 9-03-2008
// pipeline for ack 

module alt_aeuex_ack_skid_tx #(
	parameter WIDTH = 16
)
(
	input clk,
	
	input [WIDTH-1:0] dat_i,
	output ack_i,
	
	output reg [WIDTH-1:0] dat_o,
	input ack_o	
) /* synthesis ALTERA_ATTRIBUTE = "ALLOW_SYNCH_CTRL_USAGE=OFF" */;

initial dat_o = 0;

reg ack_i_r = 0 /* synthesis preserve_syn_only */;
reg ack_i_r_dupe = 0 /* synthesis preserve_syn_only */;
assign ack_i = ack_i_r;

reg [WIDTH-1:0] slush = 0;
reg slush_valid = 1'b0;

always @(posedge clk) begin
	ack_i_r <= ack_o;
	ack_i_r_dupe <= ack_o;
		
	if (ack_i_r_dupe) begin
		// taking input
		if (ack_o) begin
			if (slush_valid) begin
				slush <= dat_i;
				dat_o <= slush;
			end
			else begin
				dat_o <= dat_i;
			end
		end
		else begin
			// taking input not outputting
			slush <= dat_i;
			slush_valid <= 1'b1;
		end
	end	
	else begin
		// not taking input
		if (ack_o) begin
			// outputting, no new input
			if (slush_valid) begin
				dat_o <= slush;
				slush_valid <= 1'b0;
			end
			else begin
				// this happens when flushing, no slush available - call it slush
				dat_o <= slush;
				slush_valid <= 1'b0;
			end
		end
		else begin
			// not outputting
			// wait			
		end	
	end
	
end

endmodule
//-------------------------------------------------
//module alt_aeuex_pkt_gen_sync #(
//        parameter WIDTH = 32
//)(
//        input clk,
//        input [WIDTH-1:0] din,
//        output [WIDTH-1:0] dout
//);
//
//reg [WIDTH-1:0] sync_0 = 0 /* synthesis preserve_syn_only */;
//reg [WIDTH-1:0] sync_1 = 0 /* synthesis preserve_syn_only */;
//
//always @(posedge clk) begin
//        sync_0 <= din;
//        sync_1 <= sync_0;
//end
//assign dout = sync_1;
//
//endmodule

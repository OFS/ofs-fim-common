// (C) 2001-2018 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.

module eth_std_traffic_controller_top #(
   parameter DEVICE_FAMILY = "Arria 10",
   parameter CRC_EN        = 1
) (
   input    wire        clk,
   input    wire        reset_n,

   input    wire        avl_mm_read,
   input    wire        avl_mm_write,
   output   wire        avl_mm_waitrequest,
   input    wire[11:0]  avl_mm_baddress,
   output   wire[31:0]  avl_mm_readdata,
   input    wire[31:0]  avl_mm_writedata,

   input    wire[39:0]  mac_rx_status_data,
   input    wire        mac_rx_status_valid,
   input    wire        mac_rx_status_error,
   input    wire        stop_mon,
   output   wire        mon_active,
   output   wire        mon_done,
   output   wire        mon_error,

   output   wire[63:0]  avl_st_tx_data,
   output   wire[2:0]   avl_st_tx_empty,
   output   wire        avl_st_tx_eop,
   output   wire        avl_st_tx_error,
   input    wire        avl_st_tx_ready,
   output   wire        avl_st_tx_sop,
   output   wire        avl_st_tx_val,

   input    wire[63:0]  avl_st_rx_data,
   input    wire[2:0]   avl_st_rx_empty,
   input    wire        avl_st_rx_eop,
   input    wire [5:0]  avl_st_rx_error,
   output   wire        avl_st_rx_ready,
   input    wire        avl_st_rx_sop,
   input    wire        avl_st_rx_val
);

// ________________________________________________
//  traffic generator

wire        avl_st_rx_lpmx_mon_eop;
wire [5:0]  avl_st_rx_lpmx_mon_error;
wire        avl_st_rx_mon_lpmx_ready;
wire        avl_st_rx_lpmx_mon_sop;
wire        avl_st_rx_lpmx_mon_val; 
wire [63:0] avl_st_rx_lpmx_mon_data;
wire [2:0]  avl_st_rx_lpmx_mon_empty;

wire        to_gen_tx_ready;
wire [63:0] from_gen_tx_data;
wire        from_gen_tx_valid;
wire        from_gen_tx_sop;
wire        from_gen_tx_eop;
wire  [2:0] from_gen_tx_empty;
wire        from_gen_tx_error;

wire [63:0] to_mon_rx_data;
wire        to_mon_rx_valid;
wire        to_mon_rx_sop;
wire        to_mon_rx_eop;
wire [2:0]  to_mon_rx_empty;
wire [5:0]  to_mon_rx_error;
wire        from_mon_rx_ready;
wire        time_stamp_counter_reset;

wire[9:0] avl_mm_address = avl_mm_baddress[9:0]; // byte to word address
wire[31:0] avl_mm_readdata_gen, avl_mm_readdata_mon, avl_mm_readdata_loopback;
wire  blk_sel_gen = (avl_mm_baddress[9:8] == 2'd0);
wire  blk_sel_mon = (avl_mm_baddress[9:8] == 2'd1);
wire  blk_sel_loopback = (avl_mm_baddress[9:8] == 2'd2);    //jier added for avalon st loopback

wire waitrequest_gen, waitrequest_mon, waitrequest_loopback;
assign avl_mm_waitrequest = blk_sel_gen?waitrequest_gen:blk_sel_mon? waitrequest_mon: blk_sel_loopback? waitrequest_loopback: 1'b0;
assign avl_mm_readdata = blk_sel_gen? avl_mm_readdata_gen:blk_sel_mon? avl_mm_readdata_mon: blk_sel_loopback? avl_mm_readdata_loopback: 32'd0;

wire gen_lpbk;

wire sync_reset;

traffic_reset_sync reset_sync ( 
.clk      (clk),
.data_in  (1'b0),
.reset    (~reset_n),
.data_out (sync_reset)
);

avalon_st_gen # (
   .DEVICE_FAMILY (DEVICE_FAMILY),
   .CRC_EN (CRC_EN)
) GEN (
   .clk                      (clk),                          // Tx clock
   .reset                    (sync_reset),                   // Reset signal
   .address                  (avl_mm_address[7:0]),          // Avalon-MM Address
   .write                    (avl_mm_write & blk_sel_gen),   // Avalon-MM Write Strobe
   .writedata                (avl_mm_writedata),             // Avalon-MM Write Data
   .read                     (avl_mm_read & blk_sel_gen),    // Avalon-MM Read Strobe
   .readdata                 (avl_mm_readdata_gen),          // Avalon-MM Read Data
   .waitrequest              (waitrequest_gen),
   .tx_data                  (from_gen_tx_data),             // Avalon-ST Data
   .tx_valid                 (from_gen_tx_valid),            // Avalon-ST Valid
   .tx_sop                   (from_gen_tx_sop),              // Avalon-ST StartOfPacket
   .tx_eop                   (from_gen_tx_eop),              // Avalon-ST EndOfPacket
   .tx_empty                 (from_gen_tx_empty),            // Avalon-ST Empty
   .tx_error                 (from_gen_tx_error),            // Avalon-ST Error
   .tx_ready                 (to_gen_tx_ready),              // Avalon-ST Ready Input
   .time_stamp_counter_reset (time_stamp_counter_reset)      // Timestamp counter reset
);

avalon_st_mon  # (
   .CRC_EN (CRC_EN)
) MON (
   .clk                      (clk ),                       // RX clock
   .reset                    (sync_reset ),                // Reset Signal
   .avalon_mm_address        (avl_mm_address[7:0]),        // Avalon-MM Address
   .avalon_mm_write          (avl_mm_write & blk_sel_mon), // Avalon-MM Write Strobe
   .avalon_mm_writedata      (avl_mm_writedata),           // Avalon-MM write Data
   .avalon_mm_read           (avl_mm_read & blk_sel_mon),  // Avalon-MM Read Strobe
   .avalon_mm_waitrequest    (waitrequest_mon),
   .avalon_mm_readdata       (avl_mm_readdata_mon),        // Avalon-MM Read Data
   .mac_rx_status_valid      (mac_rx_status_valid),
   .mac_rx_status_error      (mac_rx_status_error),
   .mac_rx_status_data       (mac_rx_status_data),
   .stop_mon                 (stop_mon),
   .mon_active               (mon_active),
   .mon_done                 (mon_done),
   .mon_error                (mon_error),
   .gen_lpbk                 (gen_lpbk),
   .avalon_st_rx_data        (to_mon_rx_data),             // Avalon-ST RX Data
   .avalon_st_rx_valid       (to_mon_rx_valid),            // Avalon-ST RX Valid
   .avalon_st_rx_sop         (to_mon_rx_sop),              // Avalon-ST RX StartOfPacket
   .avalon_st_rx_eop         (to_mon_rx_eop),              // Avalon-ST RX EndOfPacket
   .avalon_st_rx_empty       (to_mon_rx_empty),            // Avalon-ST RX Data Empty
   .avalon_st_rx_error       (to_mon_rx_error),            // Avalon-ST RX Error
   .avalon_st_rx_ready       (from_mon_rx_ready),          // Avalon-ST RX Ready Output
   .time_stamp_counter_reset (time_stamp_counter_reset)    // Timestamp counter reset
);	

avalon_st_loopback #(8, 32, 64, 3, 6) avalon_st_loopback_u0 (
   .clk                          (clk),
   .reset                        (sync_reset),
   .address                      (avl_mm_address[7:0]),
   .write                        (avl_mm_write & blk_sel_loopback),
   .read                         (avl_mm_read & blk_sel_loopback),
   .waitrequest                  (waitrequest_loopback),
   .writedata                    (avl_mm_writedata),
   .readdata                     (avl_mm_readdata_loopback),
   .from_mac_tx_ready            (avl_st_tx_ready),
   .to_mac_tx_data               (avl_st_tx_data),
   .to_mac_tx_valid              (avl_st_tx_val),
   .to_mac_tx_sop                (avl_st_tx_sop),
   .to_mac_tx_eop                (avl_st_tx_eop),
   .to_mac_tx_empty              (avl_st_tx_empty),
   .to_mac_tx_error              (avl_st_tx_error),
   .from_mac_rx_data             (avl_st_rx_data),
   .from_mac_rx_valid            (avl_st_rx_val),
   .from_mac_rx_sop              (avl_st_rx_sop),
   .from_mac_rx_eop              (avl_st_rx_eop),
   .from_mac_rx_empty            (avl_st_rx_empty),
   .from_mac_rx_error            (avl_st_rx_error),
   .to_mac_rx_ready              (avl_st_rx_ready),
   .to_gen_tx_ready              (to_gen_tx_ready),
   .from_gen_tx_data             (from_gen_tx_data),
   .from_gen_tx_valid            (from_gen_tx_valid),
   .from_gen_tx_sop              (from_gen_tx_sop),
   .from_gen_tx_eop              (from_gen_tx_eop),
   .from_gen_tx_empty            (from_gen_tx_empty),
   .from_gen_tx_error            (from_gen_tx_error), 
   .to_mon_rx_data               (to_mon_rx_data),
   .to_mon_rx_valid              (to_mon_rx_valid),
   .to_mon_rx_sop	               (to_mon_rx_sop),
   .to_mon_rx_eop	               (to_mon_rx_eop),
   .to_mon_rx_empty              (to_mon_rx_empty),
   .to_mon_rx_error              (to_mon_rx_error),
   .from_mon_rx_ready            (from_mon_rx_ready)
);  
endmodule
// ____________________________________________________________________________________________
//	reset synchronizer 
// ____________________________________________________________________________________________

// turn off superfluous verilog processor warnings 
// altera message_level Level1 
// altera message_off 10034 10035 10036 10037 10230 10240 10030 

module traffic_reset_sync ( clk, data_in, reset, data_out) ;
output data_out;
input  clk;
input  data_in;
input  reset;
reg   data_in_d1 /* synthesis ALTERA_ATTRIBUTE = "{-from \"*\"} CUT=ON ; PRESERVE_REGISTER=ON ; SUPPRESS_DA_RULE_INTERNAL=R101"  */;
reg   data_out /* synthesis ALTERA_ATTRIBUTE = "PRESERVE_REGISTER=ON ; SUPPRESS_DA_RULE_INTERNAL=R101"  */;
always @(posedge clk or posedge reset)begin
   if (reset == 1) data_in_d1 <= 1;
   else data_in_d1 <= data_in;
end

always @(posedge clk or posedge reset) begin
   if (reset == 1) data_out <= 1;
   else data_out <= data_in_d1;
end

endmodule

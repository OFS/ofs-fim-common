module avst_pipeline_st_pipeline_stage_0 #(
		parameter SYMBOLS_PER_BEAT = 64,
		parameter BITS_PER_SYMBOL  = 8,
		parameter USE_PACKETS      = 1,
		parameter USE_EMPTY        = 1,
		parameter EMPTY_WIDTH      = 6,
		parameter CHANNEL_WIDTH    = 0,
		parameter PACKET_WIDTH     = 2,
		parameter ERROR_WIDTH      = 1,
		parameter PIPELINE_READY   = 1,
		parameter SYNC_RESET       = 1
	) (
		input  wire         clk,               //       cr0.clk
		input  wire         reset,             // cr0_reset.reset
		output wire         in_ready,          //     sink0.ready
		input  wire         in_valid,          //          .valid
		input  wire         in_startofpacket,  //          .startofpacket
		input  wire         in_endofpacket,    //          .endofpacket
		input  wire [5:0]   in_empty,          //          .empty
		input  wire [0:0]   in_error,          //          .error
		input  wire [511:0] in_data,           //          .data
		input  wire         out_ready,         //   source0.ready
		output wire         out_valid,         //          .valid
		output wire         out_startofpacket, //          .startofpacket
		output wire         out_endofpacket,   //          .endofpacket
		output wire [5:0]   out_empty,         //          .empty
		output wire [0:0]   out_error,         //          .error
		output wire [511:0] out_data           //          .data
	);
endmodule


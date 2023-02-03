	avst_pipeline_st_pipeline_stage_0 #(
		.SYMBOLS_PER_BEAT (INTEGER_VALUE_FOR_SYMBOLS_PER_BEAT),
		.BITS_PER_SYMBOL  (INTEGER_VALUE_FOR_BITS_PER_SYMBOL),
		.USE_PACKETS      (INTEGER_VALUE_FOR_USE_PACKETS),
		.USE_EMPTY        (INTEGER_VALUE_FOR_USE_EMPTY),
		.EMPTY_WIDTH      (INTEGER_VALUE_FOR_EMPTY_WIDTH),
		.CHANNEL_WIDTH    (INTEGER_VALUE_FOR_CHANNEL_WIDTH),
		.PACKET_WIDTH     (INTEGER_VALUE_FOR_PACKET_WIDTH),
		.ERROR_WIDTH      (INTEGER_VALUE_FOR_ERROR_WIDTH),
		.PIPELINE_READY   (INTEGER_VALUE_FOR_PIPELINE_READY),
		.SYNC_RESET       (INTEGER_VALUE_FOR_SYNC_RESET)
	) u0 (
		.clk               (_connected_to_clk_),               //   input,    width = 1,       cr0.clk
		.reset             (_connected_to_reset_),             //   input,    width = 1, cr0_reset.reset
		.in_ready          (_connected_to_in_ready_),          //  output,    width = 1,     sink0.ready
		.in_valid          (_connected_to_in_valid_),          //   input,    width = 1,          .valid
		.in_startofpacket  (_connected_to_in_startofpacket_),  //   input,    width = 1,          .startofpacket
		.in_endofpacket    (_connected_to_in_endofpacket_),    //   input,    width = 1,          .endofpacket
		.in_empty          (_connected_to_in_empty_),          //   input,    width = 6,          .empty
		.in_error          (_connected_to_in_error_),          //   input,    width = 1,          .error
		.in_data           (_connected_to_in_data_),           //   input,  width = 512,          .data
		.out_ready         (_connected_to_out_ready_),         //   input,    width = 1,   source0.ready
		.out_valid         (_connected_to_out_valid_),         //  output,    width = 1,          .valid
		.out_startofpacket (_connected_to_out_startofpacket_), //  output,    width = 1,          .startofpacket
		.out_endofpacket   (_connected_to_out_endofpacket_),   //  output,    width = 1,          .endofpacket
		.out_empty         (_connected_to_out_empty_),         //  output,    width = 6,          .empty
		.out_error         (_connected_to_out_error_),         //  output,    width = 1,          .error
		.out_data          (_connected_to_out_data_)           //  output,  width = 512,          .data
	);


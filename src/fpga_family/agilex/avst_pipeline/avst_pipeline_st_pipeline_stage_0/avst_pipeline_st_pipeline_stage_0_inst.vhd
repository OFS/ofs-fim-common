	component avst_pipeline_st_pipeline_stage_0 is
		generic (
			SYMBOLS_PER_BEAT : integer := 64;
			BITS_PER_SYMBOL  : integer := 8;
			USE_PACKETS      : integer := 1;
			USE_EMPTY        : integer := 1;
			EMPTY_WIDTH      : integer := 6;
			CHANNEL_WIDTH    : integer := 0;
			PACKET_WIDTH     : integer := 2;
			ERROR_WIDTH      : integer := 1;
			PIPELINE_READY   : integer := 1;
			SYNC_RESET       : integer := 1
		);
		port (
			clk               : in  std_logic                      := 'X';             -- clk
			reset             : in  std_logic                      := 'X';             -- reset
			in_ready          : out std_logic;                                         -- ready
			in_valid          : in  std_logic                      := 'X';             -- valid
			in_startofpacket  : in  std_logic                      := 'X';             -- startofpacket
			in_endofpacket    : in  std_logic                      := 'X';             -- endofpacket
			in_empty          : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- empty
			in_error          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- error
			in_data           : in  std_logic_vector(511 downto 0) := (others => 'X'); -- data
			out_ready         : in  std_logic                      := 'X';             -- ready
			out_valid         : out std_logic;                                         -- valid
			out_startofpacket : out std_logic;                                         -- startofpacket
			out_endofpacket   : out std_logic;                                         -- endofpacket
			out_empty         : out std_logic_vector(5 downto 0);                      -- empty
			out_error         : out std_logic_vector(0 downto 0);                      -- error
			out_data          : out std_logic_vector(511 downto 0)                     -- data
		);
	end component avst_pipeline_st_pipeline_stage_0;

	u0 : component avst_pipeline_st_pipeline_stage_0
		generic map (
			SYMBOLS_PER_BEAT => INTEGER_VALUE_FOR_SYMBOLS_PER_BEAT,
			BITS_PER_SYMBOL  => INTEGER_VALUE_FOR_BITS_PER_SYMBOL,
			USE_PACKETS      => INTEGER_VALUE_FOR_USE_PACKETS,
			USE_EMPTY        => INTEGER_VALUE_FOR_USE_EMPTY,
			EMPTY_WIDTH      => INTEGER_VALUE_FOR_EMPTY_WIDTH,
			CHANNEL_WIDTH    => INTEGER_VALUE_FOR_CHANNEL_WIDTH,
			PACKET_WIDTH     => INTEGER_VALUE_FOR_PACKET_WIDTH,
			ERROR_WIDTH      => INTEGER_VALUE_FOR_ERROR_WIDTH,
			PIPELINE_READY   => INTEGER_VALUE_FOR_PIPELINE_READY,
			SYNC_RESET       => INTEGER_VALUE_FOR_SYNC_RESET
		)
		port map (
			clk               => CONNECTED_TO_clk,               --       cr0.clk
			reset             => CONNECTED_TO_reset,             -- cr0_reset.reset
			in_ready          => CONNECTED_TO_in_ready,          --     sink0.ready
			in_valid          => CONNECTED_TO_in_valid,          --          .valid
			in_startofpacket  => CONNECTED_TO_in_startofpacket,  --          .startofpacket
			in_endofpacket    => CONNECTED_TO_in_endofpacket,    --          .endofpacket
			in_empty          => CONNECTED_TO_in_empty,          --          .empty
			in_error          => CONNECTED_TO_in_error,          --          .error
			in_data           => CONNECTED_TO_in_data,           --          .data
			out_ready         => CONNECTED_TO_out_ready,         --   source0.ready
			out_valid         => CONNECTED_TO_out_valid,         --          .valid
			out_startofpacket => CONNECTED_TO_out_startofpacket, --          .startofpacket
			out_endofpacket   => CONNECTED_TO_out_endofpacket,   --          .endofpacket
			out_empty         => CONNECTED_TO_out_empty,         --          .empty
			out_error         => CONNECTED_TO_out_error,         --          .error
			out_data          => CONNECTED_TO_out_data           --          .data
		);


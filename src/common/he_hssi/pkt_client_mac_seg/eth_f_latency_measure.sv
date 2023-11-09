// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT





module eth_f_latency_measure (

        input logic                   i_clk_pll,
        input logic                   i_rst,
    
        //---MAC AVST---
		  input logic                   stat_lat_en,
        input logic                   stat_tx_lat_sop,
        input logic                   stat_rx_lat_sop,
		  input logic                   stat_cnt_clr,

        //---csr interface---
        output logic                   stat_lat_cnt_done,
		  output logic [7:0]             stat_lat_cnt
);



//---------------------------------------------

logic  stat_tx_lat_sop_sync,stat_rx_lat_sop_sync,stat_cnt_clr_sync,i_rst_sync,stat_lat_en_sync;
logic rst;
logic lat_cnt_en;
logic [7:0] lat_cnt;
logic lat_cnt_done;
logic stat_tx_lat_sop_sync_lat;
logic stat_rx_lat_sop_sync_lat,stat_rx_lat_sop_sync_lat1;


   eth_f_xcvr_resync_std #(
        .SYNC_CHAIN_LENGTH  (3),
        .WIDTH              (5),
        .INIT_VALUE         (0)
    ) stat_lat_clkpll_sync (
        .clk                (i_clk_pll),
        .reset              (1'b0),
        .d                  ({stat_tx_lat_sop,stat_cnt_clr,stat_rx_lat_sop,i_rst,stat_lat_en}),
        .q                  ({stat_tx_lat_sop_sync,stat_cnt_clr_sync,stat_rx_lat_sop_sync,i_rst_sync,stat_lat_en_sync})
    );
	 
assign rst = i_rst_sync | stat_cnt_clr_sync;

always @ (posedge i_clk_pll) begin
    if (rst | !stat_lat_en_sync) begin 
	 stat_tx_lat_sop_sync_lat     <= 1'b0; 
    end else if (stat_tx_lat_sop_sync) begin
	 stat_tx_lat_sop_sync_lat     <= 1'b1;
	 end
end

always @ (posedge i_clk_pll) begin
    if (rst | !stat_lat_en_sync) begin
	 stat_rx_lat_sop_sync_lat     <= 1'b0;
    end else if (stat_rx_lat_sop_sync) begin
	 stat_rx_lat_sop_sync_lat     <= 1'b1;
	 end
end

always @ (posedge i_clk_pll) begin
    if (rst ) begin
	 stat_rx_lat_sop_sync_lat1     <= 1'b0;
    end else begin
	 stat_rx_lat_sop_sync_lat1     <= stat_rx_lat_sop_sync_lat;
	 end
end

always @ (posedge i_clk_pll) begin
    if (rst | stat_rx_lat_sop_sync_lat) begin
	 lat_cnt_en     <= 1'b0;
    end else if (stat_tx_lat_sop_sync_lat) begin
	 lat_cnt_en     <= 1'b1;
	 end
end

always @ (posedge i_clk_pll) begin
	if (rst) begin   
	lat_cnt_done     <= 1'b0;
	end 
	else if( stat_rx_lat_sop_sync_lat == 1'b1 & stat_rx_lat_sop_sync_lat1 == 1'b0) begin
	lat_cnt_done <= 1'b1;
	end
end

always @ (posedge i_clk_pll) begin
	if (rst) begin
	lat_cnt   <= 8'b0;
	end else if (lat_cnt_en) begin
	lat_cnt <= lat_cnt + 8'b1;
	end
end

assign stat_lat_cnt = lat_cnt;
assign stat_lat_cnt_done = lat_cnt_done;

//---------------------------------------------


endmodule

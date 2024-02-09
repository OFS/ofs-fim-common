// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`timescale 1 ps / 1 ps

module eth_f_pkt_gen_top #(
        parameter ENABLE_PTP      = 0,             
        parameter CLIENT_IF_TYPE  = 0,        // 0:Segmented; 1:AvST;
        //parameter WORDS           = 1,        // WORD count per cycle;
        parameter WORDS_AVST            = 1,
        parameter WORDS_MAC             = 1, 
        parameter ROM_ADDR_WIDTH        = 16,     
        parameter ROM_LOOPCOUNT_WIDTH   = 16,    
        parameter DATA_BCNT       = 8,
        parameter CTRL_BCNT       = 2,
        parameter PTP_BCNT        = 2,
        parameter PKT_ROM_INIT_FILE       = "eth_f_hw_pkt_gen_rom_init.hex"
    )(
        input  logic        clk,
        input  logic        rst,
        input  logic        clken,

        //---packet data interface---
        input  logic                    tx_pkt_req,
        output logic                    tx_pkt_rdata_vld,
        output logic [DATA_BCNT*8-1:0]  tx_pkt_rdata,
        output logic [CTRL_BCNT*8-1:0]  tx_pkt_rdata_ctrl,
        output logic [PTP_BCNT*8-1:0]   tx_pkt_ptp_ctrl,
		
        //---csr ctrl
        input logic                  cfg_pkt_gen_tx_en,         // 1: start sending pkt; 0: stop sending pkt;
        input logic [ROM_ADDR_WIDTH-1:0]           cfg_rom_start_addr,        // Rom start addr for packet data;
        input logic [ROM_ADDR_WIDTH-1:0]           cfg_rom_end_addr,          // Rom end addr for packet data;
        input logic [ROM_LOOPCOUNT_WIDTH-1:0]      cfg_test_loop_cnt,          // define how many blocks of data to send;
	    input logic            cfg_pkt_gen_cont_mode    // 1: Continuous Mode; 0: One Shot Mode;

);

localparam ROM_DATA_WIDTH = (DATA_BCNT + CTRL_BCNT + PTP_BCNT)*8;

//---------------------------------------------
logic [ROM_DATA_WIDTH-1:0]      rom_wdata, rom_rdata, bf_rdata;
logic [ROM_ADDR_WIDTH-1:0]      rom_raddr, rom_dvld_addr, rom_rd_addr;
logic [16-1:0]                  rom_rd_cnt;
logic                           rom_rd, rom_dvld, rom_rd_done, rom_block_done, rom_wr;
logic                           bf_req, bf_rdata_vld, bf_full, bf_empty;
logic                           bf_wr;
logic [7:0]                     tx_en_dly;
logic                           tx_en, tx_start, rst_local;
logic [ROM_LOOPCOUNT_WIDTH-1:0] rom_block_cnt;

//---------------------------------------------
always @ (posedge clk) begin
    if (rst) begin
        rst_local    <= 1'b1;
        tx_en_dly    <= 1'b0;
        tx_start     <= 1'b0;
        tx_en        <= 1'b0;
    end else begin
        rst_local    <= !cfg_pkt_gen_tx_en;
        tx_en_dly    <= {tx_en_dly[6:0], cfg_pkt_gen_tx_en};
        tx_start     <= !tx_en_dly[7] & tx_en_dly[6];
        tx_en        <= tx_en_dly[7];
    end
end

//---------------------------------------------
always @ (posedge clk) begin
    if (rst_local) begin
            rom_rd_addr     <= {ROM_ADDR_WIDTH{1'b0}};
            rom_rd_cnt      <= 0;
            rom_block_cnt   <= 0;
    end else if (tx_start) begin
            rom_rd_addr     <= cfg_rom_start_addr;
            rom_rd_cnt      <= 0;
    end else if (tx_en) begin
        if (rom_rd) begin
            rom_rd_cnt      <= rom_rd_cnt + 1'b1;
            if (rom_block_done)        rom_block_cnt   <= rom_block_cnt + 1'b1;
            if (rom_block_done)        rom_rd_addr     <= cfg_rom_start_addr;
            else                       rom_rd_addr     <= rom_rd_addr + 1'b1;
		end
    end else begin
            rom_rd_addr     <= 0;
            rom_rd_cnt      <= 0;
            rom_block_cnt   <= 0;
	end 
end

always @ (posedge clk) begin
    if (rst_local) begin
            rom_dvld_addr  <= {ROM_ADDR_WIDTH{1'b0}};
    end else if (tx_start) begin
            rom_dvld_addr  <= cfg_rom_start_addr;
    end else if (rom_rd)   rom_dvld_addr <= rom_rd_addr;
end

assign rom_raddr = bf_wr ? rom_rd_addr : rom_dvld_addr;

//assign rom_rd = tx_en & !bf_full & !rom_rd_done;
assign rom_rd = tx_en & !rom_rd_done & (rom_dvld ? bf_wr : 1'b1);
assign rom_block_done = (rom_rd_addr == cfg_rom_end_addr);
always @ (posedge clk) begin
    if (rst_local)      rom_dvld <= 1'b0;
    else if (rom_rd)    rom_dvld <= 1'b1;
    else if (bf_wr)     rom_dvld <= 1'b0;
end

always @ (posedge clk) begin
    if (rst_local)      rom_rd_done <= 1'b0;
    else if (cfg_test_loop_cnt==0 || cfg_pkt_gen_cont_mode==1)
                        rom_rd_done <= 1'b0;
    else if ((rom_rd & rom_block_done) & ((rom_block_cnt >= cfg_test_loop_cnt-1) && cfg_pkt_gen_cont_mode==0))
                        rom_rd_done <= 1'b1;

end


//---------------------------------------------
assign rom_wr = 1'b0;
assign rom_wdata = 0;

eth_f_pkt_gen_rom pkt_gen_rom (
        .clk           (clk),
        .reset         (rst_local),
        .clken         (clken),
        .chipselect    (1'b1),      //(rom_rd),

        .address       (rom_raddr),
        .readdata      (rom_rdata),
        .write         (rom_wr),
        .writedata     (rom_wdata)
);
defparam pkt_gen_rom.INIT_FILE  = PKT_ROM_INIT_FILE;
defparam pkt_gen_rom.data_width = ROM_DATA_WIDTH;
defparam pkt_gen_rom.addr_width = ROM_ADDR_WIDTH;

assign bf_wr = rom_dvld & !bf_full;

//--------------------------------------------- 
eth_f_pkt_gen_pingpong_bf pkt_gen_pingpong_bf(
        .clk           (clk),
        .rst           (rst_local),

        .wr            (bf_wr),  //(rom_dvld),
        .wdata         (rom_rdata),
        .rd            (bf_rd),
        .rdata         (bf_rdata),
        .full          (bf_full),
        .empty         (bf_empty)
);
defparam pkt_gen_pingpong_bf.WIDTH = ROM_DATA_WIDTH;

assign bf_rd = !bf_empty & tx_pkt_req & tx_en;
assign tx_pkt_rdata_vld  = !bf_empty;
assign tx_pkt_rdata      = bf_rdata[ROM_DATA_WIDTH-1 : (CTRL_BCNT+PTP_BCNT)*8];
assign tx_pkt_rdata_ctrl = bf_rdata[((CTRL_BCNT+PTP_BCNT)*8)-1:(0+(PTP_BCNT*8))];

generate 
if (ENABLE_PTP == 1) begin:PTP_CMD 
    assign tx_pkt_ptp_ctrl = bf_rdata[PTP_BCNT*8-1:0];
end else begin : NO_PTP_CMD
	assign tx_pkt_ptp_ctrl = 0;
end
endgenerate

//------------------------------------------------------
endmodule

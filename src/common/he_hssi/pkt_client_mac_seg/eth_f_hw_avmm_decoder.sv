// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`timescale 1 ps / 1 ps

module eth_f_hw_avmm_decoder #(
        parameter SLAVE_NUM          = 3,
        parameter ADDR_WIDTH         = 32,
        parameter DATA_WIDTH         = 32,
        parameter BYTE_EN_WIDTH      = 4
    )(
        input   logic                       clk,
        input   logic                       rst,

        //---avmm master from Jtag---
        input   logic   [ADDR_WIDTH-1:0]              master_addr,
        input   logic                                 master_read,
        input   logic                                 master_write,
        input   logic   [DATA_WIDTH-1:0]              master_writedata,
        input   logic   [BYTE_EN_WIDTH-1:0]           master_byteenable,
        output  logic   [DATA_WIDTH-1:0]              master_readdata,
        output  logic                                 master_readdatavalid,
        output  logic                                 master_waitrequest,

        //---avmm slave IF---
        output logic   [ADDR_WIDTH-1:0]                slave_addr,
        output logic   [DATA_WIDTH-1:0]                slave_writedata,
        output logic   [BYTE_EN_WIDTH-1:0]             slave_byteenable,
        output logic   [SLAVE_NUM-1:0]                 slave_read,
        output logic   [SLAVE_NUM-1:0]                 slave_write,
        input  logic   [SLAVE_NUM*DATA_WIDTH-1:0]      slave_readdata,
        input  logic   [SLAVE_NUM-1:0]                 slave_readdatavalid,
        input  logic   [SLAVE_NUM-1:0]                 slave_waitrequest,

        //---Ctrl IF---
        input   logic   [SLAVE_NUM*ADDR_WIDTH-1:0]     slave_start_addr,
        input   logic   [SLAVE_NUM*ADDR_WIDTH-1:0]     slave_end_addr

);

//--------------------------------------------
integer i, j;
logic   [SLAVE_NUM:0]     sel, rd_vld, wr_vld, rw_done_all;
logic                     rd_req, wr_req, rd_done, wr_done, rw_done, rdata_vld_t, rdata_vld, rdata_vld_r;

logic   [ADDR_WIDTH-1:0]     master_addr_r;
logic                        master_read_r;
logic                        master_write_r;
logic   [DATA_WIDTH-1:0]     master_writedata_r;
logic   [BYTE_EN_WIDTH-1:0]  master_byteenable_r;

//--------------------------------------------
logic [2:0]     avmm_st, avmm_nst;
localparam      AVMM_IDLE        = 0,
                AVMM_RW          = 1,
                AVMM_RW_DONE     = 2,
                AVMM_RDATA       = 3;

//--------------------------------------------
always @* begin
    avmm_nst = avmm_st;
    case (avmm_st)
        AVMM_IDLE:      if (master_read | master_write)    avmm_nst = AVMM_RW;
        AVMM_RW:        if (rw_done)                       avmm_nst = AVMM_RW_DONE;
        AVMM_RW_DONE:   if (master_read_r & !rdata_vld)    avmm_nst = AVMM_RDATA;
                        else                               avmm_nst = AVMM_IDLE;
        AVMM_RDATA:     if (master_read_r & rdata_vld)     avmm_nst = AVMM_IDLE;
        default:                                           avmm_nst = AVMM_IDLE;
    endcase
end

always @ (posedge clk) begin
  if (rst)        avmm_st <= AVMM_IDLE;
  else            avmm_st <= avmm_nst;
end

always @ (posedge clk)		master_readdatavalid <= rdata_vld_t;

always @ (posedge clk) begin
  if (rst)        master_waitrequest <= 1'b1;
  else            master_waitrequest <= !((avmm_nst==AVMM_RW_DONE) | (avmm_st==AVMM_RW_DONE));
end


assign rd_req = master_read_r  & (avmm_st==AVMM_RW);
assign wr_req = master_write_r & (avmm_st==AVMM_RW);
assign slave_read  = {SLAVE_NUM{rd_req}} & sel[SLAVE_NUM-1:0];
assign slave_write = {SLAVE_NUM{wr_req}} & sel[SLAVE_NUM-1:0];

//--------------------------------------------
logic [(SLAVE_NUM+1)*DATA_WIDTH-1:0]  slave_readdata_all;
assign slave_readdata_all = {32'hdeadc0de, slave_readdata};

logic [DATA_WIDTH-1:0] rd_data[0:SLAVE_NUM];
always @* begin
    for (i=0; i<=SLAVE_NUM; i=i+1) begin
        for (j=0; j<DATA_WIDTH; j=j+1) begin
            rd_data[i][j] = slave_readdata_all[i*DATA_WIDTH+j];
        end
    end
end

always @ (posedge clk) begin
    for (i=0; i<=SLAVE_NUM; i=i+1) begin
        if (sel[i] & rdata_vld_t) begin
            master_readdata <= rd_data[i];
        end
    end
end

//--------------------------------------------
genvar k;
generate
    for (k=0; k<SLAVE_NUM; k=k+1) begin:SLAVE_SEL
        always @ (posedge clk) begin
            if (rst)
                sel[k] <= (k==0) ? 1'b1 : 1'b0; // Reset to select lane 1
            else if ((avmm_st==AVMM_IDLE) & (avmm_nst!=AVMM_IDLE))
                sel[k] <= (master_addr >= slave_start_addr[(k+1)*ADDR_WIDTH-1:k*ADDR_WIDTH])
                        & (master_addr <= slave_end_addr[(k+1)*ADDR_WIDTH-1:k*ADDR_WIDTH]);
        end
    end
endgenerate

assign sel[SLAVE_NUM] = ~|sel[SLAVE_NUM-1:0];
//assign wr_vld = {sel[SLAVE_NUM], ~slave_waitrequest};
assign rw_done_all = {sel[SLAVE_NUM], ~slave_waitrequest};
assign rw_done = |(rw_done_all & sel);

assign rd_vld = {sel[SLAVE_NUM], slave_readdatavalid};
assign rdata_vld_t = |(rd_vld & sel);
assign rdata_vld = rdata_vld_t | rdata_vld_r;
always @(posedge clk) begin
	if (avmm_nst==AVMM_IDLE)	rdata_vld_r <= 1'b0;
	else if (rdata_vld_t)		rdata_vld_r <= 1'b1;
end
//assign rd_done = |(rd_vld & sel);
//assign wr_done = |(wr_vld & sel);

//---------------------------------------------------------------
always @(posedge clk) begin
    if ((avmm_st==AVMM_IDLE) & (avmm_nst!=AVMM_IDLE)) begin
            master_addr_r         <= master_addr;
            master_read_r         <= master_read;
            master_write_r        <= master_write;
            master_writedata_r    <= master_writedata;
            master_byteenable_r   <= master_byteenable;
    end
end

assign slave_addr       = master_addr_r;
assign slave_writedata  = master_writedata_r;
assign slave_byteenable = master_byteenable_r;

//---------------------------------------------------------------
endmodule

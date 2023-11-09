// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


module eth_f_loopback_fifo #(
    parameter DATA_BCNT   = 0,
    parameter CTRL_BCNT   = 0,
    parameter FIFO_ADDR_WIDTH  = 5,
    parameter CLIENT_IF_TYPE = 0,
    parameter SEG_INFRAME_POS  = 8,
    parameter WORDS = 4,
    parameter SIM_EMULATE = 0,
    parameter INIT_FILE_DATA = "init_file_data.hex"
) (
    input   logic                   i_arst,

    input   logic                   i_clk_w,
    input   logic [CTRL_BCNT*8-1:0] i_ctrl,
    input   logic [DATA_BCNT*8-1:0] i_data,
    input   logic                   i_valid,
    input   logic                   i_idle,

    input   logic                   i_clk_r,
    input   logic                   i_read_req,
    output  logic [DATA_BCNT*8-1:0] o_data,
    output  logic [CTRL_BCNT*8-1:0] o_ctrl,
    output  logic                   o_valid,

    input   logic                   stat_cnt_clr,
    output  logic                   o_wr_full_err,
    output  logic                   o_rd_empty_err

);

    logic           w_reset;
    logic           r_reset;
    logic   [0:8]   w_reset_reg;    /* synthesis dont_merge */

    eth_f_reset_synchronizer rsw (
        .clk        (i_clk_w),
        .aclr       (i_arst),
        .aclr_sync  (w_reset)
    );

    eth_f_reset_synchronizer rsr (
        .clk        (i_clk_r),
        .aclr       (i_arst),
        .aclr_sync  (r_reset)
    );

//------------------------------------------------
logic   full, empty;
logic   fifo_rd, fifo_rd_d1;
logic   lo_thrsh, hi_thrsh;
logic   lo_thrsh_reg, hi_thrsh_reg;
logic   [CTRL_BCNT*8-1:0] ctrl_temp;
logic   [DATA_BCNT*8-1:0] data_temp;
logic   fifo_wr, fifo_wr_reg;
logic   valid_r, valid_rr;
logic   [CTRL_BCNT*8-1:0] i_ctrl_reg;
logic   [DATA_BCNT*8-1:0] i_data_reg;
logic   skid_empty;
logic   [WORDS-1:0] ctrl_infrm;

logic eop_det_adv, eop_det_adv_rd, i_idle_reg;
logic rd_stop_disable_timer;
logic read_req_d1, read_req_pedge;

//Write enable logic
//AvST   : based on incoming valid 
//MACSeg : based on incoming valid; write stopped wthen idle is detected and high threshold is detected
//         idle is detected when current cycle has all inframe bits=0 and prev cycle has MSB bit=0
generate
if(CLIENT_IF_TYPE==1)
begin
    assign fifo_wr = i_valid;
    assign eop_det_adv = 1'b0;
end
else
begin
    assign fifo_wr = i_valid & ~(hi_thrsh_reg & i_idle);
    //Any cycle which has the MSB inframe bit set to 0 indicates EOP
    //eop_det_adv indicates this one cycle in advance so that read logic can 
    //detect EOP and stop read if FIFO is crossing low threshold
    assign eop_det_adv = (i_ctrl[SEG_INFRAME_POS+WORDS-1]==1'b0) & fifo_wr;
end
endgenerate

//Registering input data to FIFO to meet timing
always @ (posedge i_clk_w) begin: SYNC_FIFO_INPUTS
  fifo_wr_reg <= fifo_wr & !full;
  i_data_reg  <= i_data;
  i_ctrl_reg  <= i_ctrl;
  hi_thrsh_reg <= hi_thrsh;
end

//Dual clock FIFO with configurable depth
//High/Low Threshold outputs enabled at +/-10 of mid point
eth_f_hw_dual_clock_fifo rx_pkt_fifo (
        .areset        (i_arst),
        .write_clk     (i_clk_w),
        .write         (fifo_wr_reg),
        .write_data    ({i_data_reg, i_ctrl_reg, eop_det_adv}),

        .read_clk      (i_clk_r),
        .read          (fifo_rd),
        .read_data     ({data_temp, ctrl_temp, eop_det_adv_rd}),

        .lo_thrsh      (lo_thrsh),
        .hi_thrsh      (hi_thrsh),

        .full          (full),
        .empty         (empty)
);
defparam rx_pkt_fifo.WIDTH        = ((DATA_BCNT+CTRL_BCNT)*8)+1;
defparam rx_pkt_fifo.DEPTH        = 2**FIFO_ADDR_WIDTH;
defparam rx_pkt_fifo.HI_THRSH     = 2**(FIFO_ADDR_WIDTH-1)+10;
defparam rx_pkt_fifo.LO_THRSH     = 2**(FIFO_ADDR_WIDTH-1)-10;

//Read enable logic
//AvST   - based on incoming tx_ready delayed by READY_LATENCY
//MACSeg - based on incoming tx_ready (w/o delay); stop read when gap btw packets is detected and low threshold is detected
//       - packet gap is detected when MSB inframe bit from read data is set to 0 (indicated by eop_det_adv_rd)
generate
if(CLIENT_IF_TYPE==1)
begin
    assign fifo_rd = i_read_req & !empty;
    assign ctrl_infrm = {WORDS{1'b0}};
    assign rd_stop_disable_timer = 1'b0;
end
else
begin
    assign fifo_rd = ((i_read_req & ~(lo_thrsh_reg & eop_det_adv_rd)) | read_req_pedge) & !empty;
    assign ctrl_infrm = valid_rr? ctrl_temp[SEG_INFRAME_POS+:WORDS] : {WORDS{1'b0}};
	 
	 always_ff @ (posedge i_clk_r)
	 begin
		read_req_d1 <= i_read_req;
	 end
	 assign read_req_pedge = ~read_req_d1 & i_read_req;
    
end
endgenerate

//Output valid logic
//FIFO has enabled register on read data outputs
//Hence latency of FIFO is 2. So o_valid is 2 cycles delayed from read input
always @ (posedge i_clk_r) begin valid_r <= fifo_rd; valid_rr <= valid_r; end 

always @ (posedge i_clk_r) begin
	lo_thrsh_reg <= lo_thrsh;
end

always @ (posedge i_clk_r) begin
    if (r_reset | stat_cnt_clr) begin
        o_wr_full_err  <= 1'b0;
        o_rd_empty_err <= 1'b0;
    end else begin
        if (full)        o_wr_full_err  <= 1'b1;
        if (empty)       o_rd_empty_err <= 1'b1;
    end    
end

//Skid FIFO to make read latency 0 for AvST modes only
logic [4:0] buf_cnt;
logic skid_pop, skid_lo_thrsh, rd_sop, rd_eop, rd_valid;
enum logic {IDLE, INFRAME} state;
generate
if(CLIENT_IF_TYPE==1)
begin    
    fifo_lat_0 #(.DEPTH (16),
	            .SKIP_RDEN(1),
   		        .INIT_FILE_DATA(INIT_FILE_DATA),
                .DW ((DATA_BCNT+CTRL_BCNT)*8)
                  ) skid_fifo
        (// inputs
         .clk (i_clk_r),
         .reset (r_reset),
         .push (valid_rr),
         .dIn ({data_temp, ctrl_temp}),
         .pop (skid_pop),
         // outputs
         .dOut ({o_data, o_ctrl}),
         .cnt (buf_cnt),
         .full (),
         .empty (skid_empty),
         .dOutVld ()
         
         );
    
    assign skid_lo_thrsh = (buf_cnt < 8);
    assign o_valid = skid_pop;

    assign rd_valid   = o_valid;
    assign rd_sop     = o_ctrl[15];
    assign rd_eop     = o_ctrl[14];
   
    //Detection of EOP in order to stop read at packet boundary since AvST requires
    //that there are no forced gaps introduced between SOP and EOP. Ready can go low 
    //between SOP & EOP but user cannot pull valid low or introduce IDLE cycles in the 
    //middle of a packet
    assign skid_pop = i_read_req & ~(skid_lo_thrsh & state==IDLE) & !skid_empty;

    always @ (posedge i_clk_r)
    begin
        if(r_reset)
		state <= IDLE;
        if(rd_valid) begin
            if(rd_eop)
                state <= IDLE;
            else if(rd_sop)
                state <= INFRAME;
        end
    end
end
else
begin
    assign o_data  = data_temp;
    assign o_ctrl  = {ctrl_temp[CTRL_BCNT*8-1:SEG_INFRAME_POS+WORDS], ctrl_infrm[WORDS-1:0],ctrl_temp[SEG_INFRAME_POS-1:0]};
    assign o_valid = valid_rr;
    assign rd_valid = 0;
    assign rd_sop = 0;
    assign rd_eop = 0;
    assign state = IDLE;
end
endgenerate

//------------------------------------------------

endmodule

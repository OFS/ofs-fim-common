// (C) 2001-2021 Intel Corporation. All rights reserved.
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


//////////////////////////////////////////////////////////////////////////////
// This module translates the commands issued by the state machines into
// Avalon-MM or Avalon-ST signals.
//////////////////////////////////////////////////////////////////////////////

module altera_emif_avl_tg_2_axi_if # (
    parameter BYTE_ADDR_WIDTH              = "",
    parameter DATA_WIDTH                   = "",
    parameter BE_WIDTH                     = "",
    parameter AMM_WORD_ADDRESS_WIDTH       = "",
    parameter AMM_BURSTCOUNT_WIDTH         = "",
    parameter ENHANCED_TESTING                   = 0,
    parameter TEST_RREADY                        = 0,
    parameter PORT_CTRL_AXI4_AWID_WIDTH          = 1,
    parameter PORT_CTRL_AXI4_AWADDR_WIDTH        = 31,
    parameter PORT_CTRL_AXI4_AWUSER_WIDTH        = 8,
    parameter PORT_CTRL_AXI4_AWLEN_WIDTH         = 8,
    parameter PORT_CTRL_AXI4_AWSIZE_WIDTH        = 3,
    parameter PORT_CTRL_AXI4_AWBURST_WIDTH       = 2,
    parameter PORT_CTRL_AXI4_AWLOCK_WIDTH        = 1,
    parameter PORT_CTRL_AXI4_AWCACHE_WIDTH       = 4,
    parameter PORT_CTRL_AXI4_AWPROT_WIDTH        = 3,
    parameter PORT_CTRL_AXI4_ARID_WIDTH          = 1,
    parameter PORT_CTRL_AXI4_ARADDR_WIDTH        = 31,
    parameter PORT_CTRL_AXI4_ARUSER_WIDTH        = 8,
    parameter PORT_CTRL_AXI4_ARLEN_WIDTH         = 8,
    parameter PORT_CTRL_AXI4_ARSIZE_WIDTH        = 3,
    parameter PORT_CTRL_AXI4_ARBURST_WIDTH       = 2,
    parameter PORT_CTRL_AXI4_ARLOCK_WIDTH        = 1,
    parameter PORT_CTRL_AXI4_ARCACHE_WIDTH       = 4,
    parameter PORT_CTRL_AXI4_ARPROT_WIDTH        = 3,
    parameter PORT_CTRL_AXI4_WDATA_WIDTH         = 512,
    parameter PORT_CTRL_AXI4_WSTRB_WIDTH         = 64,
    parameter PORT_CTRL_AXI4_BID_WIDTH           = 1,
    parameter PORT_CTRL_AXI4_BRESP_WIDTH         = 2,
    parameter PORT_CTRL_AXI4_BUSER_WIDTH         = 8,
    parameter PORT_CTRL_AXI4_RID_WIDTH           = 1,
    parameter PORT_CTRL_AXI4_RDATA_WIDTH         = 512,
    parameter PORT_CTRL_AXI4_RRESP_WIDTH         = 2,
    parameter PORT_CTRL_AXI4_RUSER_WIDTH         = 8
) (
    input                                                    clk,
    input                                                    rst,

    //from traffic generator
    input                                                    write_req,
    input                                                    read_req,
    input [AMM_WORD_ADDRESS_WIDTH-1:0]                       mem_addr,
    output                                                   controller_wr_ready,
    output                                                   controller_rd_ready,

    input [DATA_WIDTH-1:0]                                   mem_write_data,
    input [BE_WIDTH-1:0]                                     mem_write_be,
    input [AMM_BURSTCOUNT_WIDTH-1:0]                         burstlength,

    output logic   [PORT_CTRL_AXI4_AWID_WIDTH-1:0]           axi_awid,
    output logic   [PORT_CTRL_AXI4_AWADDR_WIDTH-1:0]         axi_awaddr,
    output logic                                             axi_awvalid,
    output logic   [PORT_CTRL_AXI4_AWUSER_WIDTH-1:0]         axi_awuser,
    output logic   [PORT_CTRL_AXI4_AWLEN_WIDTH-1:0]          axi_awlen,
    output logic   [PORT_CTRL_AXI4_AWSIZE_WIDTH-1:0]         axi_awsize,
    output logic   [PORT_CTRL_AXI4_AWBURST_WIDTH-1:0]        axi_awburst,
    input  logic                                             axi_awready,
    output logic   [PORT_CTRL_AXI4_AWPROT_WIDTH-1:0]         axi_awprot,
    output logic   [PORT_CTRL_AXI4_AWCACHE_WIDTH-1:0]        axi_awcache,
    output logic   [PORT_CTRL_AXI4_AWLOCK_WIDTH-1:0]         axi_awlock,

    output logic   [PORT_CTRL_AXI4_ARID_WIDTH-1:0]           axi_arid,
    output logic   [PORT_CTRL_AXI4_ARADDR_WIDTH-1:0]         axi_araddr,
    output logic                                             axi_arvalid,
    output logic   [PORT_CTRL_AXI4_ARUSER_WIDTH-1:0]         axi_aruser,
    output logic   [PORT_CTRL_AXI4_ARLEN_WIDTH-1:0]          axi_arlen,
    output logic   [PORT_CTRL_AXI4_ARSIZE_WIDTH-1:0]         axi_arsize,
    output logic   [PORT_CTRL_AXI4_ARBURST_WIDTH-1:0]        axi_arburst,
    input  logic                                             axi_arready,
    output logic   [PORT_CTRL_AXI4_ARPROT_WIDTH-1:0]         axi_arprot,
    output logic   [PORT_CTRL_AXI4_ARCACHE_WIDTH-1:0]        axi_arcache,
    output logic   [PORT_CTRL_AXI4_ARLOCK_WIDTH-1:0]         axi_arlock,

    output logic   [PORT_CTRL_AXI4_WDATA_WIDTH-1:0]          axi_wdata,
    output logic   [PORT_CTRL_AXI4_WSTRB_WIDTH-1:0]          axi_wstrb,
    output logic                                             axi_wlast,
    output logic                                             axi_wvalid,
    input  logic                                             axi_wready,

    input  logic   [PORT_CTRL_AXI4_BID_WIDTH-1:0]            axi_bid,
    input  logic   [PORT_CTRL_AXI4_BRESP_WIDTH-1:0]          axi_bresp,
    input  logic   [PORT_CTRL_AXI4_BUSER_WIDTH-1:0]          axi_buser,
    input  logic                                             axi_bvalid,
    output logic                                             axi_bready,

    input  logic   [PORT_CTRL_AXI4_RID_WIDTH-1:0]            axi_rid,
    input  logic   [PORT_CTRL_AXI4_RDATA_WIDTH-1:0]          axi_rdata,
    input  logic   [PORT_CTRL_AXI4_RRESP_WIDTH-1:0]          axi_rresp,
    input  logic   [PORT_CTRL_AXI4_RUSER_WIDTH-1:0]          axi_ruser,
    input  logic                                             axi_rlast,
    input  logic                                             axi_rvalid,
    output logic                                             axi_rready,

    input [DATA_WIDTH-1:0]                                   written_data,
    input [BE_WIDTH-1:0]                                     written_be,
    output [BE_WIDTH-1:0]                                    ast_exp_data_byteenable,
    output [DATA_WIDTH-1:0]                                  ast_exp_data_writedata,


    //Actual data for comparison in status checker
    output                                                   ast_act_data_readdatavalid,
    output [DATA_WIDTH-1:0]                                  ast_act_data_readdata,

    input                                                    read_addr_fifo_full,
    input                                                    start
);
    timeunit 1ns;
    timeprecision 1ps;

    import avl_tg_defs::*;

    logic [PORT_CTRL_AXI4_AWID_WIDTH-1:0]    awid;
    logic [PORT_CTRL_AXI4_ARID_WIDTH-1:0]    arid;
    logic [PORT_CTRL_AXI4_AWID_WIDTH-1:0]    expected_bid;
    logic [PORT_CTRL_AXI4_ARID_WIDTH-1:0]    expected_rid;

    always @ ( posedge clk or posedge rst ) begin
        if ( rst ) begin
            awid             <= '0;
            arid             <= '0;
            expected_bid     <= '0;
            expected_rid     <= '0;
        end
        else begin
            if ( axi_awvalid ) begin
                awid <= awid + 1'b1;
            end

            if ( axi_arvalid ) begin
                arid <= arid + 1'b1;
            end

            if ( axi_bvalid ) begin
// synthesis translate_off
                if (expected_bid != axi_bid) begin
                    $display("ERROR: axi_bid mismatch");
                    $finish;
                end
// synthesis translate_on
                expected_bid <= expected_bid + 1'b1;
            end

            if ( axi_rvalid & axi_rready ) begin
                if ( axi_rlast ) begin
                    expected_rid <= expected_rid + 1'b1;
                end

// synthesis translate_off
                if (expected_rid != axi_rid) begin
                    $display("ERROR: axi_rid mismatch");
                    $finish;
                end
                if (axi_rresp != 2'b00) begin
                    $display("ERROR: axi_rresp indicates a read data error");
                    $finish;
                end
// synthesis translate_on
            end
        end
    end

    logic [PORT_CTRL_AXI4_AWLEN_WIDTH-1:0] n_beats_issued;
    logic burst_ongoing;
    assign burst_ongoing = !(n_beats_issued == 0);

    // Altough AXI has separate channels for write request and write data,
    // our traffic generator doesn't fully make use of that. Specifically,
    // we only issue write request and data when both the write request
    // and write data channel are ready.
    logic issue_write;
    assign issue_write = write_req & ~read_addr_fifo_full & (axi_awready | burst_ongoing) & axi_wready;

    // The following signals are used to keep track of whether we're issuing
    // the first and last beat of a write burst.
    logic issue_write_first_beat;
    logic issue_write_last_beat;

    assign issue_write_first_beat = issue_write && (n_beats_issued == 0);
    assign issue_write_last_beat = issue_write && (n_beats_issued == (burstlength - 1'b1));

    always_ff @ ( posedge clk or posedge rst ) begin
        if ( rst ) begin
            n_beats_issued <= '0;
        end else begin
            if (issue_write_last_beat) begin
                n_beats_issued <= '0;
            end else if (issue_write) begin
                n_beats_issued <= n_beats_issued + 1'b1;
            end
        end
    end

    assign axi_awid                   = awid;
    assign axi_awaddr                 = {mem_addr, {(PORT_CTRL_AXI4_AWADDR_WIDTH - AMM_WORD_ADDRESS_WIDTH){1'b0}}};
    assign axi_awvalid                = issue_write_first_beat;
    assign axi_awuser                 = 'd0;
    assign axi_awlen                  = {'0, burstlength-1'b1};
    assign axi_awsize                 = {'0, log2(PORT_CTRL_AXI4_WDATA_WIDTH / 8)};
    assign axi_awburst                = 2'b01;  

    assign axi_wdata                  = mem_write_data;
    assign axi_wstrb                  = mem_write_be;
    assign axi_wlast                  = issue_write_last_beat;
    assign axi_wvalid                 = issue_write;

    assign axi_arid                   = arid;
    assign axi_araddr                 = {mem_addr, {(PORT_CTRL_AXI4_ARADDR_WIDTH - AMM_WORD_ADDRESS_WIDTH){1'b0}}};
    assign axi_arvalid                = read_req & ~read_addr_fifo_full & controller_rd_ready;
    assign axi_aruser                 = 'd0;
    assign axi_arlen                  = {'0, burstlength-1'b1};
    assign axi_arsize                 = {'0, log2(PORT_CTRL_AXI4_RDATA_WIDTH / 8)};
    assign axi_arburst                = 2'b01;  

    localparam READY_COUNTER_WIDTH = 10;
    logic [READY_COUNTER_WIDTH-1:0] ready_counter;
    always_ff @ ( posedge clk or posedge rst ) begin
        if ( rst ) begin
            ready_counter <= '0;
        end else begin
            if (axi_rvalid) begin
                ready_counter <= ready_counter + 1'b1;
            end
        end
    end

    assign axi_rready                 = TEST_RREADY ? ready_counter[READY_COUNTER_WIDTH-1] : 1'b1;
    assign axi_bready                 = 1'b1;

    assign axi_arcache                = '0;
    assign axi_arlock                 = '0;
    assign axi_arprot                 = '0;
    assign axi_awcache                = '0;
    assign axi_awlock                 = '0;
    assign axi_awprot                 = '0;

    assign ast_exp_data_writedata     =  written_data;
    assign ast_exp_data_byteenable    =  written_be;

    //when the address fifo is full, the ready signal to the traffic generator is deasserted
    //this potentially leaves the read or write signals to the memory controller asserted for its duration
    //when we actually do not want to be issuing operations, only holding current state
    assign controller_wr_ready           = (axi_awready | burst_ongoing) & axi_wready & ~read_addr_fifo_full;
    assign controller_rd_ready           = axi_arready==1'b1 && read_addr_fifo_full==1'b0 && expected_bid==awid;

    assign ast_act_data_readdata      = axi_rdata;
    assign ast_act_data_readdatavalid = (axi_rvalid && axi_rresp == 2'b00) & axi_rready;

endmodule


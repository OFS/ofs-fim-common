// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// AVST Rx MMIO Bridge
//-----------------------------------------------------------------------------

import pcie_ss_hdr_pkg::*;

module  avst_rx_mmio_bridge #(
    parameter READ_ISSUING_CAPABILITY   = 512,  // Max # outstanding reads
    
    parameter AVMM_ADDR_WIDTH   = 20, 
    parameter AVMM_DATA_WIDTH   = 64
)(
    input                   clk,
    input                   rst_n,
    
    ofs_avst_if.sink        avst_rx_if,
    
    input   logic                               avmm_s2m_waitrequest,
    input   logic                               avmm_s2m_writeresponsevalid,
    input   logic                               avmm_s2m_readdatavalid,
    
    output  logic                               avmm_m2s_write,
    output  logic                               avmm_m2s_read,
    output  logic   [AVMM_ADDR_WIDTH-1:0]       avmm_m2s_address,
    output  logic   [AVMM_DATA_WIDTH-1:0]       avmm_m2s_writedata,
    output  logic   [(AVMM_DATA_WIDTH>>3)-1:0]  avmm_m2s_byteenable,
    
    output  logic                               tlp_rd_strb,
    output  logic   [9:0]                       tlp_rd_tag,
    output  logic   [13:0]                      tlp_rd_length,
    output  logic   [15:0]                      tlp_rd_req_id,
    output  logic   [23:0]                      tlp_rd_low_addr,

    output  logic   [7:0]                       avst_rx_fmttype,
    output  logic   [13:0]                      avst_rx_length,
    output  logic   [63:0]                      avst_rx_addr
);

logic           avst_rx_sop;
logic           avst_rx_eop;
logic           avst_rx_valid;
logic   [255:0] avst_rx_data;

logic   [255:0] avst_rx_data_0;

pcie_ss_hdr_pkg::PCIe_PUReqHdr_t  avst_rx_mmio_hdr;

localparam [7:0]    MEM_READ_32     = 8'h00,
                    MEM_READ_64     = 8'h20,
                    MEM_WRITE_32    = 8'h40,
                    MEM_WRITE_64    = 8'h60;

logic   [9:0]   avst_rx_tag;
logic   [13:0]  avst_rx_length;
logic   [63:0]  avst_rx_addr;
logic   [15:0]  avst_rx_req_id;

logic           avst_rx_write;
logic           avst_rx_read;

logic   [(AVMM_DATA_WIDTH>>3)-1:0]
                avst_rx_byteenable;

logic   [$bits(READ_ISSUING_CAPABILITY-1)-1:0]
                avst_rx_read_count;

typedef enum bit [2:0] {
    ST_RESET,
    ST_READY,
    ST_WAIT_FOR_READ,
    ST_WAIT_FOR_VALID,
    ST_WAIT_FOR_WRITE,
    ST_WAIT_FOR_RESPONSE
} RxReadyState_t;

RxReadyState_t  RxReadyState;
RxReadyState_t  RxReadyNextState;

//--------------------------------------------------------
// AVST Rx Sink Interface
//--------------------------------------------------------
always_comb
begin   
    avst_rx_if.ready        <= ( RxReadyState == ST_READY );;
end

always_ff @ ( posedge clk )
begin
    if ( !rst_n )
    begin
        avst_rx_valid           <= 1'b0;
    end
    else
    if ( avst_rx_if.ready )
    begin    
        avst_rx_sop             <= avst_rx_if.sop;
        avst_rx_eop             <= avst_rx_if.eop;
        avst_rx_valid           <= avst_rx_if.valid;

        avst_rx_data            <= avst_rx_if.data[511:256];
        avst_rx_mmio_hdr        <= avst_rx_if.data[255:0];
    end
end

always_comb
begin   
    avst_rx_fmttype     = avst_rx_mmio_hdr.fmt_type;
    avst_rx_tag         = { avst_rx_mmio_hdr.tag_h,
                            avst_rx_mmio_hdr.tag_m,
                            avst_rx_mmio_hdr.tag_l };
    avst_rx_length      = { 2'b00,
                            avst_rx_mmio_hdr.length, 
                            2'b00 };
    avst_rx_req_id      = avst_rx_mmio_hdr[63:48];
    
    avst_rx_read        = 1'b0;
    avst_rx_write       = 1'b0;
    
    case ( avst_rx_fmttype )
    
        MEM_READ_32:
        begin
            avst_rx_read        = avst_rx_valid;
            avst_rx_addr        = { 32'd0,
                                    avst_rx_mmio_hdr.host_addr_h };  
        end
                
        MEM_WRITE_32:
        begin
            avst_rx_write       = avst_rx_valid;
            avst_rx_addr        = { 32'd0,
                                    avst_rx_mmio_hdr.host_addr_h };  
        end
        
        MEM_READ_64:
        begin
            avst_rx_read        = avst_rx_valid;
            avst_rx_addr        = { avst_rx_mmio_hdr.host_addr_h,
                                    avst_rx_mmio_hdr.host_addr_l, 
                                    2'b00 };
        end
        
        MEM_WRITE_64:
        begin
            avst_rx_write       = avst_rx_valid;
            avst_rx_addr        = { avst_rx_mmio_hdr.host_addr_h,
                                    avst_rx_mmio_hdr.host_addr_l,
                                    2'b00 };
        end
        
        default:
        begin
            avst_rx_addr        = 64'd0;
        end
        
    endcase
end

//--------------------------------------------------------
// AVST Rx Read Counter
//--------------------------------------------------------
always_ff @ ( posedge clk )
begin
    if ( !rst_n )
    begin
        avst_rx_read_count  <= '0;
    end
    else
    begin
        unique case ( { avmm_m2s_read, avmm_s2m_readdatavalid } )
        
            2'b00:
                avst_rx_read_count  <= avst_rx_read_count;
                
            2'b01:
                avst_rx_read_count  <= avst_rx_read_count - 1'b1;
                
            2'b10:
                avst_rx_read_count  <= avst_rx_read_count + 1'b1;
                
            2'b11:
                avst_rx_read_count  <= avst_rx_read_count;
                
        endcase
    end
end

//--------------------------------------------------------
// AVST Rx Ready FSM
//--------------------------------------------------------
always_ff @ ( posedge clk )
begin
    if ( !rst_n )
    begin
        RxReadyState        <= ST_RESET;
    end
    else
    begin
        RxReadyState        <= RxReadyNextState;
    end
end

always_comb
begin
    RxReadyNextState    = RxReadyState;

    unique  case ( RxReadyState )
    
        ST_RESET:
        begin
            if ( !avmm_s2m_waitrequest )
                RxReadyNextState    = ST_READY;
        end
        
        ST_READY:
        begin
            if ( avst_rx_write )
                RxReadyNextState    = ST_WAIT_FOR_WRITE;
            
            if ( ( avst_rx_read_count + 'd2 ) >= READ_ISSUING_CAPABILITY )
                if ( avst_rx_read )
                    RxReadyNextState    = ST_WAIT_FOR_READ;
        end
        
        ST_WAIT_FOR_READ:
        begin
            if ( avmm_m2s_read )
                RxReadyNextState    = ST_WAIT_FOR_VALID;
        end
        
        ST_WAIT_FOR_VALID:
        begin
            if ( avmm_s2m_readdatavalid )
                RxReadyNextState    = ST_READY;
        end
        
        ST_WAIT_FOR_WRITE:
        begin
            if ( avmm_m2s_write )
                RxReadyNextState    = ST_WAIT_FOR_RESPONSE;
        end
        
        ST_WAIT_FOR_RESPONSE:
        begin
            if ( avmm_s2m_writeresponsevalid )
                RxReadyNextState    = ST_READY;
        end
    
    endcase
end

//--------------------------------------------------------
// AVMM Master to Slave Interface
// TLP Read Request Sideband to Tx Bridge
//--------------------------------------------------------
always_ff @ ( posedge clk )
begin
    if ( !rst_n )
    begin
        avmm_m2s_write      <= 1'b0;
        avmm_m2s_read       <= 1'b0;
    end
    else
    if ( !avmm_s2m_waitrequest )
    begin
        avmm_m2s_write      <= 1'b0;
        avmm_m2s_read       <= 1'b0;

        if ( avst_rx_valid )
        begin
            avmm_m2s_address    <= avst_rx_addr[AVMM_ADDR_WIDTH-1:0];
            avmm_m2s_writedata  <= avst_rx_data_0[AVMM_DATA_WIDTH-1:0];
            avmm_m2s_byteenable <= avst_rx_byteenable;
                
            tlp_rd_tag          <= avst_rx_tag;
            tlp_rd_length       <= avst_rx_length[13:0];
            tlp_rd_req_id       <= avst_rx_req_id;
        
            avmm_m2s_write      <= avst_rx_write
                                    && avst_rx_if.ready;
            avmm_m2s_read       <= avst_rx_read
                                    && avst_rx_if.ready;
        end
    end
end

always_comb
begin
    tlp_rd_strb         = avmm_m2s_read;
    tlp_rd_low_addr     = { { ( $bits(tlp_rd_low_addr) - $bits(avmm_m2s_address) ) { 1'b0 } },
                                                                        avmm_m2s_address };
end

// Left-shift rx_data if unaligned address
always_comb
begin
    avst_rx_data_0      = avst_rx_data << ( 8 * avst_rx_addr[2:0] );
end

// Byte enable positioning dependent upon address alignment
always_comb
begin
    avst_rx_byteenable  = f_rx_byteenable(0,avst_rx_addr[2:0],avst_rx_length);
end

function logic [(AVMM_DATA_WIDTH>>3)-1:0] f_rx_byteenable
(
    integer      ptr,
    logic [2:0]  rx_address,
    logic [23:0] rx_length
);
    integer i;
    
    for ( i = 0 ; i < (AVMM_DATA_WIDTH>>3) ; i++ )
    begin
        if ( i + ptr < rx_address[2:0] )
            f_rx_byteenable[i]      = 1'b0;
        else
        if ( i + ptr * (AVMM_DATA_WIDTH>>3) < rx_length + rx_address[2:0] )
            f_rx_byteenable[i]      = 1'b1;
        else
            f_rx_byteenable[i]      = 1'b0;
    end    

endfunction

endmodule

// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// ST2MM CSR - includes MSI-X vector # strobe generation
//-----------------------------------------------------------------------------

import ofs_csr_pkg::*;

module  axil_bridge_csr #(
    parameter END_OF_LIST     = 1'b0,
    parameter NEXT_DFH_OFFSET = 24'h01_0000,
    parameter ADDR_WIDTH      = 20, 
    parameter DATA_WIDTH      = 64
)(
    input                               clk,
    input                               rst_n,
    
    ofs_fim_axi_lite_if.slave                   axi_s_if,
    
    output  logic                               msix_strb,
    output  logic   [15:0]                      msix_num,
    
    input   logic                               flg_rd_req,
    input   logic                               flg_rd_cpl,
    input   logic                               flg_wr_req,
    input   logic                               flg_wr_cpl
);

//----------------------------------------------------------------------------
// Here we define each registers address...
//----------------------------------------------------------------------------
localparam  ST2MM_DFH                           = 6'h00;
localparam  ST2MM_SCRATCHPAD                    = 6'h08;
localparam  ST2MM_MSIX_CTRL                     = 6'h10;
localparam  ST2MM_READ_CNTR                     = 6'h18;
localparam  ST2MM_WRITE_CNTR                    = 6'h20;

//---------------------------------------------------------------------------------
// Define the register bit attributes for each of the CSRs
//---------------------------------------------------------------------------------
csr_bit_attr_t [63:0] ST2MM_DFH_ATTR            = {64{RO}};
csr_bit_attr_t [63:0] ST2MM_SCRATCHPAD_ATTR     = {64{RW}};
csr_bit_attr_t [63:0] ST2MM_MSIX_CTRL_ATTR      = {64{RW}};
csr_bit_attr_t [63:0] ST2MM_READ_CNTR_ATTR      = {64{RO}};
csr_bit_attr_t [63:0] ST2MM_WRITE_CNTR_ATTR     = {64{RO}};

//----------------------------------------------------------------------------
// SIGNAL DEFINITIONS
//----------------------------------------------------------------------------
logic [CSR_REG_WIDTH-1:0]   csr_reg[0:7];       // 8 registers
logic                       csr_write[7:0];     // Register Write Strobes - Arrayed like the registers.

ofs_csr_hw_state_t          hw_state;           // Hardware state during CSR updates.  This simplifies the CSR Register Update function call.

logic                       awReadyValid, wReadyValid, bReadyValid, arReadyValid, rReadyValid;

logic [ADDR_WIDTH-1:0]      waddr_reg;
logic [CSR_REG_WIDTH-1:0]   wdata_reg;

csr_access_type_t           write_type, write_type_reg;

logic [ADDR_WIDTH-1:0]      raddr_reg;

//----------------------------------------------------------------------------
// HW State is a data struct used to pass the resets, write data, and write
// type to the CSR "update_reg" function.
//----------------------------------------------------------------------------
assign hw_state.reset_n      = rst_n;
assign hw_state.pwr_good_n   = 1'b0;
assign hw_state.wr_data.data = wdata_reg;
assign hw_state.write_type   = write_type_reg;

//----------------------------------------------------------------------------
// Combinatorial logic to define what type of write is occurring:
//     1.) UPPER32 = Upper 32 bits of register from lower 32 bits of the write
//         data bus.
//     2.) LOWER32 = Lower 32 bits of register from lower 32 bits of the write
//         data bus.
//     3.) FULL64 = All 64 bits of the register from all 64 bits of the write
//         data bus.
//     4.) NONE = No write will be performed on register.
// Logic must be careful to detect simultaneous awvalid and wvalid OR awvalid
// leading wvalid.  A write address with bit #2 set decides whether 32-bit
// write is to upper or lower word.
//----------------------------------------------------------------------------
always_comb
begin
    write_type              =   ( !axi_s_if.wvalid )        ?   NONE    :
                                ( &axi_s_if.wstrb )         ?   FULL64  : 
                                ( !axi_s_if.awvalid )       ?
                                    ( !waddr_reg[2] )       ?   LOWER32 :
                                                                UPPER32 :
                                ( !axi_s_if.awaddr[2] )     ?   LOWER32 :
                                                                UPPER32 ;                                                                    
end

//----------------------------------------------------------------------------
// AXI-LITE READY + VALID
//----------------------------------------------------------------------------
always_comb
begin
    awReadyValid     = ( axi_s_if.awready && axi_s_if.awvalid );
    wReadyValid      = ( axi_s_if.wready && axi_s_if.wvalid );
    bReadyValid      = ( axi_s_if.bready && axi_s_if.bvalid );
    arReadyValid     = ( axi_s_if.arready && axi_s_if.arvalid );
    rReadyValid      = ( axi_s_if.rready && axi_s_if.rvalid );
end

//----------------------------------------------------------------------------
// AXI-LITE WRITE INTERFACE
//----------------------------------------------------------------------------
typedef enum bit [1:0] {
    ST_WADDR,
    ST_WDATA,
    ST_BWAIT,
    ST_BRESP
} WriteState_t;

WriteState_t     WriteState, WriteNextState;

always_ff @ ( posedge clk )
begin
    if ( !rst_n )
        WriteState          <= ST_WADDR;
    else
        WriteState          <= WriteNextState;
end    
    
always_comb
begin
    WriteNextState          <= WriteState;

    case ( WriteState )
        
        ST_WADDR:
        begin
            if ( awReadyValid && wReadyValid )
                WriteNextState          <= ST_BWAIT;
            else
            if ( awReadyValid )
                WriteNextState          <= ST_WDATA;
        end
        
        ST_WDATA:
        begin
            if ( wReadyValid )
                WriteNextState          <= ST_BWAIT;
        end
        
        ST_BWAIT:
        begin
            WriteNextState          <= ST_BRESP;
        end
        
        ST_BRESP:
        begin
            if ( bReadyValid )
                WriteNextState          <= ST_WADDR;
        end
    
    endcase
end

always_comb
begin
    axi_s_if.awready                <= 1'b0;
    axi_s_if.wready                 <= 1'b0;
    axi_s_if.bvalid                 <= 1'b0;
    axi_s_if.bresp                  <= 2'b00;
    
    csr_write                       <= '{default:0};
            
    case ( WriteState )
    
        ST_WADDR:
        begin
            axi_s_if.awready                <= 1'b1;
            axi_s_if.wready                 <= 1'b1;          
        end
        
        ST_WDATA:
        begin
            axi_s_if.wready                 <= 1'b1;            
        end
        
        ST_BWAIT:
        begin
            csr_write[waddr_reg[5:3]]       <= 1'b1;          
        end
        
        ST_BRESP:
        begin
            csr_write[waddr_reg[5:3]]       <= 1'b1; 
            axi_s_if.bvalid                 <= 1'b1;
        end
    
    endcase
end

always_ff @ ( posedge clk )
begin
    if ( !rst_n )
    begin        
        write_type_reg          <= NONE;
        waddr_reg               <= {ADDR_WIDTH{1'b0}};
        wdata_reg               <= {CSR_REG_WIDTH{1'b0}};
    end
    else
    begin
        write_type_reg                      <= write_type;
        
        if ( wReadyValid )
            wdata_reg                           <= axi_s_if.wdata;
            
        if ( awReadyValid )
            waddr_reg                           <= axi_s_if.awaddr;
    end
end

//----------------------------------------------------------------------------
// AXI-LITE READ INTERFACE
//----------------------------------------------------------------------------
typedef enum {
    ST_RADDR,
    ST_RDATA
} ReadState_t;

ReadState_t      ReadState, ReadNextState;

always_ff @ ( posedge clk )
begin
    if ( !rst_n )
        ReadState           <= ST_RADDR;
    else
        ReadState           <= ReadNextState;
end      
    
always_comb
begin
    ReadNextState           <= ReadState;

    case ( ReadState )
    
        ST_RADDR:
        begin
            if ( arReadyValid )
                ReadNextState           <= ST_RDATA;
        end
        
        ST_RDATA:
        begin
            if ( rReadyValid )
                ReadNextState           <= ST_RADDR;        
        end
    
    endcase
end

always_comb
begin
    axi_s_if.arready                <= 1'b0;
    axi_s_if.rvalid                 <= 1'b0;
    axi_s_if.rresp                  <= 2'b00;
    axi_s_if.rdata                  <= csr_reg[raddr_reg[5:3]];

    case ( ReadState )
        
        ST_RADDR:
        begin
            axi_s_if.arready                <= 1'b1;
        end
        
        ST_RDATA:
        begin
            axi_s_if.rvalid                 <= 1'b1; 
        end
    
    endcase
end

always_ff @ ( posedge clk )
begin
    if ( !rst_n )
        raddr_reg                       <= {ADDR_WIDTH{1'b0}};
    else
    if ( arReadyValid )
        raddr_reg                       <= axi_s_if.araddr;
end

//----------------------------------------------------------------------------
// MSIX vector number + strobe
//----------------------------------------------------------------------------
always_ff @ ( posedge clk )
begin
    msix_strb                       <= 1'b0;
    msix_num                        <= 0;
    
    if ( csr_write[ST2MM_MSIX_CTRL[5:3]] && bReadyValid )
    begin
        msix_strb                       <= 1'b1;
        msix_num                        <= wdata_reg[15:0];
    end
end

//----------------------------------------------------------------------------
// MMIO Traffic Counters
//----------------------------------------------------------------------------
logic   [31:0]      flg_rd_req_cnt;
logic   [31:0]      flg_rd_cpl_cnt;
logic   [31:0]      flg_wr_req_cnt;
logic   [31:0]      flg_wr_cpl_cnt;

always_ff @ ( posedge clk )
begin
    if ( !rst_n )
    begin
        flg_rd_req_cnt      <= 32'd0;
        flg_rd_cpl_cnt      <= 32'd0;
        flg_wr_req_cnt      <= 32'd0;
        flg_wr_cpl_cnt      <= 32'd0;
    end
    else
    begin
        flg_rd_req_cnt      <= flg_rd_req_cnt + flg_rd_req;
        flg_rd_cpl_cnt      <= flg_rd_cpl_cnt + flg_rd_cpl;
        flg_wr_req_cnt      <= flg_wr_req_cnt + flg_wr_req;
        flg_wr_cpl_cnt      <= flg_wr_cpl_cnt + flg_wr_cpl;
    end
end

//----------------------------------------------------------------------------
// Register Update Logic using "update_reg" function in "ofs_csr_pkg.sv"
// SystemVerilog package.  Function inputs are "named" for ease of
// understanding the use.
//     - Register bit attributes are set in array input above.  Attribute
//       functions are defined in SAS.
//     - Reset Value is appied at reset except for RO, *D, and Rsvd{Z}.
//     - Update Value is used as status bit updates for RO, RW1C*, and RW1S*.
//     - Current Value is used to determine next register value.  This must be
//       done due to scoping rules using SystemVerilog package.
//     - "Write" is the decoded write signal for that particular register.
//     - State is a hardware state structure to pass input signals to
//       "update_reg" function.  See just above.
//----------------------------------------------------------------------------
always_ff @ ( posedge clk )
begin

    // Currently, DFL walk steps over this DFH
    // If DFH included, need valid feature ID
    csr_reg[ ST2MM_DFH[5:3] ]           <= update_reg   (
                                                        .attr            (ST2MM_DFH_ATTR),
                                                    /* 
                                                       [63:60]: Feature Type
                                                       [59:52]: Reserved
                                                       [51:48]: If AFU - AFU Minor Revision Number (else, reserved)
                                                       [47:41]: Reserved
                                                       [40   ]: EOL (End of DFH list)
                                                       [39:16]: Next DFH Byte Offset
                                                       [15:12]: If AfU, AFU Major version number (else feature #)
                                                       [11:0 ]: Feature ID
                                                    */
                                                        .reg_reset_val   ({4'h3,8'h00,4'h0,7'h00,END_OF_LIST,NEXT_DFH_OFFSET,4'h0,12'hfff}),
                                                        .reg_update_val  ({4'h3,8'h00,4'h0,7'h00,END_OF_LIST,NEXT_DFH_OFFSET,4'h0,12'hfff}),
                                                        .reg_current_val (csr_reg[ST2MM_DFH[5:3]]),
                                                        .write           (csr_write[ST2MM_DFH[5:3]]),
                                                        .state           (hw_state)
                                                        );

    csr_reg[ ST2MM_SCRATCHPAD[5:3] ]    <= update_reg   (
                                                        .attr            (ST2MM_SCRATCHPAD_ATTR),
                                                        .reg_reset_val   (64'h0000_0000_0000_0000),
                                                        .reg_update_val  (64'h0000_0000_0000_0000),
                                                        .reg_current_val (csr_reg[ST2MM_SCRATCHPAD[5:3]]),
                                                        .write           (csr_write[ST2MM_SCRATCHPAD[5:3]]),
                                                        .state           (hw_state)
                                                        ); 

    csr_reg[ ST2MM_MSIX_CTRL[5:3] ]     <= update_reg   (
                                                        .attr            (ST2MM_MSIX_CTRL_ATTR),
                                                        .reg_reset_val   (64'h0000_0000_0000_0000),
                                                        .reg_update_val  (64'h0000_0000_0000_0000),
                                                        .reg_current_val (csr_reg[ST2MM_MSIX_CTRL[5:3]] & 64'hFFFF_FFFF_FFFF_0000),  // vector # is self-clearing
                                                        .write           (csr_write[ST2MM_MSIX_CTRL[5:3]]),
                                                        .state           (hw_state)
                                                        ); 

    csr_reg[ ST2MM_READ_CNTR[5:3] ]     <= update_reg   (
                                                        .attr            (ST2MM_READ_CNTR_ATTR),
                                                        .reg_reset_val   (64'h0000_0000_0000_0000),
                                                        .reg_update_val  ({flg_rd_cpl_cnt,flg_rd_req_cnt}),
                                                        .reg_current_val (csr_reg[ST2MM_READ_CNTR[5:3]]),
                                                        .write           (csr_write[ST2MM_READ_CNTR[5:3]]),
                                                        .state           (hw_state)
                                                        ); 

    csr_reg[ ST2MM_WRITE_CNTR[5:3] ]    <= update_reg   (
                                                        .attr            (ST2MM_WRITE_CNTR_ATTR),
                                                        .reg_reset_val   (64'h0000_0000_0000_0000),
                                                        .reg_update_val  ({flg_wr_cpl_cnt,flg_wr_req_cnt}),
                                                        .reg_current_val (csr_reg[ST2MM_WRITE_CNTR[5:3]]),
                                                        .write           (csr_write[ST2MM_WRITE_CNTR[5:3]]),
                                                        .state           (hw_state)
                                                        ); 

    // Unused CSR(s)
    csr_reg[ 3'h5 ]                 <= 64'h0;
    csr_reg[ 3'h6 ]                 <= 64'h0;
    csr_reg[ 3'h7 ]                 <= 64'h0;
end

endmodule

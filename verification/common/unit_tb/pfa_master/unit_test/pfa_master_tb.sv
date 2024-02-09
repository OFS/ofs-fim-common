// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

module pfa_master_tb();
//-------------------------------------------------------------------------------------------
// Parameters
//-------------------------------------------------------------------------------------------
    // AVMM IF Parameters
    parameter   AVMM_ADDR_WIDTH  = 18; 
    parameter AVMM_RDATA_WIDTH = 64; 
    parameter AVMM_WDATA_WIDTH = 64; 

    // AXI4Lite IF Parameters
    parameter AXI4LITE_ADDR_WIDTH  = 18; 
    parameter AXI4LITE_RDATA_WIDTH = 64;
    parameter AXI4LITE_WDATA_WIDTH = 64;


    //TB specific Parameters
    localparam  DEBUG = 1;
    localparam  AVMM_BE_WIDTH = (AVMM_WDATA_WIDTH) >> 3;
    localparam  AVMM_PACKET_WIDTH   = AVMM_ADDR_WIDTH + AVMM_WDATA_WIDTH + AVMM_BE_WIDTH + 1 + 1; 
    localparam  NUM_TESTS = 20;


//-------------------------------------------------------------------------------------------
//  Instantiate Interfaces
//-------------------------------------------------------------------------------------------
    
    logic   ACLK;           // global clock signal
    logic   ARESETn;        // global reset signal; active LOW

    // AVMM Master to Slave Interface
    logic                                       avmm_m2s_write;             // valid for write
    logic                                       avmm_m2s_read;              // valid for read
    logic   [AVMM_ADDR_WIDTH-1:0]               avmm_m2s_address;           // write or read address of a transfer
    logic   [AVMM_WDATA_WIDTH-1:0]              avmm_m2s_writedata;         // data for write transfer
    logic   [(AVMM_WDATA_WIDTH >> 3)-1:0]       avmm_m2s_byteenable;        // byte-enable signal of write data

    // AVMM Slave to Master Interface
    logic                                       avmm_s2m_waitrequest;       // slave requests master to wait 
    logic                                       avmm_s2m_writeresponsevalid;// valid write response
    logic                                       avmm_s2m_readdatavalid;     // valid read data
    logic   [AVMM_RDATA_WIDTH-1:0]              avmm_s2m_readdata;          // data for read transfer

    // Write Address Channel
    logic                                       axi4lite_s2m_AWREADY;       // indicates that the slave is ready to accept a write address
    logic                                       axi4lite_m2s_AWVALID;       // valid write address and control info
    logic  [AXI4LITE_ADDR_WIDTH-1:0]            axi4lite_m2s_AWADDR;        // write address
    logic  [2:0]            axi4lite_m2s_AWPROT;        // protection encoding (access permissions)

    // Write Data Channel
    logic                                       axi4lite_s2m_WREADY;        // indicates that the slave can accept the write data
    logic                                       axi4lite_m2s_WVALID;        // valid write data and strobes are available
    logic  [AXI4LITE_WDATA_WIDTH-1:0]           axi4lite_m2s_WDATA;         // write data
    logic  [(AXI4LITE_WDATA_WIDTH >> 3)-1:0]    axi4lite_m2s_WSTRB;         // byte enable i.e. indicates byte lanes that hold valid data

    // Write Response Channel 
    logic                                       axi4lite_s2m_BVALID;        // valid write response
    logic   [1:0]                               axi4lite_s2m_BRESP;         // status of write transaction 
    logic                                       axi4lite_m2s_BREADY;        // indicates that the master can accept a write response

    // Read Address Channel
    logic                                       axi4lite_s2m_ARREADY;       // indicates that the slave is ready to accept an read address
    logic                                       axi4lite_m2s_ARVALID;       // valid read address and control info
    logic  [AXI4LITE_ADDR_WIDTH-1:0]            axi4lite_m2s_ARADDR;        // read address
    logic  [2:0]            axi4lite_m2s_ARPROT;        // protection encoding (access permissions)

    // Read Data Channel
    logic                                       axi4lite_s2m_RVALID;        // valid read data
    logic   [AXI4LITE_RDATA_WIDTH-1:0]          axi4lite_s2m_RDATA;         // read data
    logic   [1:0]                               axi4lite_s2m_RRESP;         // status of read transfer
    logic                                       axi4lite_m2s_RREADY;        // indicates that the master can accept the read data and response information.

    logic   [AVMM_PACKET_WIDTH-1:0]             m2s_avmm_fifo[$];


    initial begin
        axi_backpressure();
    end

    initial begin
        ACLK    = '1;
        ARESETn = '0;

        avmm_m2s_write  = '0;
        avmm_m2s_read   = '0;

        axi4lite_s2m_AWREADY    = '0;
        axi4lite_s2m_WREADY     = '0;
        axi4lite_s2m_BVALID     = '0;
        axi4lite_s2m_ARREADY    = '0;
        axi4lite_s2m_RVALID     = '0;

        //Release reset
        repeat (5) @ (posedge ACLK);
        $display("releasing reset!!");
        ARESETn = '1;
        
        repeat (5) @ (posedge ACLK);

        // Test to check pfa-master m2s Rd and Wr ops
        $display("starting pfa-master m2s test");
        for (int i = 0; i < NUM_TESTS; i++) begin 
            randsequence (seq)
                seq: Wr | Rd;
                Wr: {test_pfam_m2s_ops(.write(1), .read(0), .address($urandom), .wr_data($urandom), .be($urandom));};
                Rd: {test_pfam_m2s_ops(.write(0), .read(1), .address($urandom), .wr_data($urandom), .be($urandom));};
            endsequence
        end
            
        repeat (10) @ (posedge ACLK);
        
        // Test to check pfa-master s2m resp ops
        $display("starting pfa-master s2m test");
        for (int i = 0; i < NUM_TESTS; i++) begin
            test_pfam_s2m_ops(.wr_addr_rdy($urandom), .wr_data_rdy($urandom), .wr_resp_valid($urandom), .rd_addr_rdy($urandom), .rd_data_valid($urandom), .rd_data($urandom) );
        end

        $display("Done test");


        #200;
        $finish;
    end

    always begin
        #50 ACLK = ~ACLK;
    end




//-------------------------------------------------------------------------------------------
//  Instantiaten DUT
//-------------------------------------------------------------------------------------------
    pfa_master #(
        .AVMM_ADDR_WIDTH        (AVMM_ADDR_WIDTH),
        .AVMM_RDATA_WIDTH       (AVMM_RDATA_WIDTH),
        .AVMM_WDATA_WIDTH       (AVMM_WDATA_WIDTH),

        .AXI4LITE_ADDR_WIDTH    (AXI4LITE_ADDR_WIDTH),
        .AXI4LITE_RDATA_WIDTH   (AXI4LITE_RDATA_WIDTH),
        .AXI4LITE_WDATA_WIDTH   (AXI4LITE_WDATA_WIDTH)
    ) 
    pfa_master_inst (
        .ACLK                       (ACLK),
        .ARESETn                    (ARESETn),

        // avmm if
        .avmm_m2s_write             (avmm_m2s_write),
        .avmm_m2s_read              (avmm_m2s_read),
        .avmm_m2s_address           (avmm_m2s_address),
        .avmm_m2s_writedata         (avmm_m2s_writedata),
        .avmm_m2s_byteenable        (avmm_m2s_byteenable),

        .avmm_s2m_waitrequest       (avmm_s2m_waitrequest),
        .avmm_s2m_writeresponsevalid(avmm_s2m_writeresponsevalid),
        .avmm_s2m_readdatavalid     (avmm_s2m_readdatavalid),
        .avmm_s2m_readdata          (avmm_s2m_readdata),

        // axi4lite if
        .axi4lite_s2m_AWREADY       (axi4lite_s2m_AWREADY),
        .axi4lite_m2s_AWVALID       (axi4lite_m2s_AWVALID),
        .axi4lite_m2s_AWADDR        (axi4lite_m2s_AWADDR),
        .axi4lite_m2s_AWPROT        (axi4lite_m2s_AWPROT),

        .axi4lite_s2m_WREADY        (axi4lite_s2m_WREADY),
        .axi4lite_m2s_WVALID        (axi4lite_m2s_WVALID),
        .axi4lite_m2s_WDATA         (axi4lite_m2s_WDATA),
        .axi4lite_m2s_WSTRB         (axi4lite_m2s_WSTRB),

        .axi4lite_s2m_BVALID        (axi4lite_s2m_BVALID),
        .axi4lite_s2m_BRESP         (axi4lite_s2m_BRESP),
        .axi4lite_m2s_BREADY        (axi4lite_m2s_BREADY),

        .axi4lite_s2m_ARREADY       (axi4lite_s2m_ARREADY),
        .axi4lite_m2s_ARVALID       (axi4lite_m2s_ARVALID),
        .axi4lite_m2s_ARADDR        (axi4lite_m2s_ARADDR),
        .axi4lite_m2s_ARPROT        (axi4lite_m2s_ARPROT),

        .axi4lite_s2m_RVALID        (axi4lite_s2m_RVALID),
        .axi4lite_s2m_RDATA         (axi4lite_s2m_RDATA),
        .axi4lite_s2m_RRESP         (axi4lite_s2m_RRESP),
        .axi4lite_m2s_RREADY        (axi4lite_m2s_RREADY)
    );


    

//    final begin
//        $display("All transactions are complete!!");
//    end


// ---------------------------------------------------------------------------------
// axi_backpressure  test
// ---------------------------------------------------------------------------------
task automatic  axi_backpressure();
    int delay;

    forever begin
        @(posedge ACLK);
        //Pick a random number of cycles 
        if ($urandom_range(0, 10) <= 3) begin
            delay = $urandom_range(0, 10);
            axi4lite_s2m_AWREADY    = 0;
            axi4lite_s2m_WREADY     = 0;
            axi4lite_s2m_ARREADY    = 0;

            repeat(delay) @ (posedge ACLK);
            axi4lite_s2m_AWREADY    = 1;
            axi4lite_s2m_WREADY     = 1;
            axi4lite_s2m_ARREADY    = 1;
        end


    end //forever 
endtask : axi_backpressure
// ---------------------------------------------------------------------------------
// pfa-master m2s (avmm to axi4lite) test
// ---------------------------------------------------------------------------------
task automatic test_pfam_m2s_ops (
    logic                           write,
    logic                           read,
    logic   [AVMM_ADDR_WIDTH-1:0]   address,
    logic   [AVMM_WDATA_WIDTH-1:0]  wr_data,
    logic   [AVMM_BE_WIDTH-1:0]     be
);

    //logic   [AVMM_PACKET_WIDTH-1:0]     avmm_packet;
    //@ (posedge ACLK);
    avmm_m2s_write      = write;
    avmm_m2s_read       = read;
    avmm_m2s_address    = address;
    avmm_m2s_writedata  = wr_data;
    avmm_m2s_byteenable = be;

    @(posedge ACLK);
    if (avmm_s2m_waitrequest == 0) begin
        avmm_m2s_write  = 0;
        avmm_m2s_read   = 0;
    end
    else begin
        wait(avmm_s2m_waitrequest == 0);
        //@ (posedge ACLK);
    end

    avmm_m2s_write      = '0;
    avmm_m2s_read       = '0;

    //@ (posedge ACLK)  // total 2 clock cycles after input assignmments

    // Display port information
    if (DEBUG) 
        print_axi4lite_m2s_if(write, read);

    // Checker    
    /*
    if (write) begin
        assert(axi4lite_m2s_AWVALID == write)   else $error($time, "\t%m checker failed for signal - write address valid, actual = %h and expected = %h", axi4lite_m2s_AWVALID, write);
        assert(axi4lite_m2s_AWADDR == address)  else $error($time, "\t%m checker failed for signal - write address, actual = %h and expected = %h", axi4lite_m2s_AWADDR, address);
        assert(axi4lite_m2s_WVALID == write)    else $error($time, "\t%m checker failed for signal - write data valid, actual = %h and expected = %h", axi4lite_m2s_WVALID, write);
        assert(axi4lite_m2s_WDATA == wr_data)    else $error($time, "\t%m checker failed for signal - write data, actual = %h and expected = %h", axi4lite_m2s_WDATA, wr_data);
        assert(axi4lite_m2s_WSTRB == be)        else $error($time, "\t%m checker failed for signal - write strobe, actual = %h and expected = %h", axi4lite_m2s_WSTRB, be);
    end

    if (read) begin
        assert(axi4lite_m2s_ARVALID == read)    else $error($time, "\t%m checker failed for signal - read address valid, actual = %h and expected = %h", axi4lite_m2s_ARVALID, read);
        assert(axi4lite_m2s_ARADDR == address)  else $error($time, "\t%m checker failed for signal - read address, actual = %h and expected = %h", axi4lite_m2s_ARADDR, address);
    end
    */

endtask: test_pfam_m2s_ops



// ---------------------------------------------------------------------------------
// pfa-master s2m (axi4lite to avmm) test
// ---------------------------------------------------------------------------------
task automatic test_pfam_s2m_ops (
    logic                               wr_addr_rdy = '0,
    logic                               wr_data_rdy = '0,
    logic                               wr_resp_valid = '0,
    logic                               rd_addr_rdy = '0,
    logic                               rd_data_valid = '0,
    logic   [AXI4LITE_RDATA_WIDTH-1:0]  rd_data = '0
);

    logic waitrequest;

    @ (posedge ACLK)
    axi4lite_s2m_AWREADY    <= wr_addr_rdy;
    axi4lite_s2m_WREADY     <= wr_data_rdy;
    axi4lite_s2m_BVALID     <= wr_resp_valid;
    axi4lite_s2m_ARREADY    <= rd_addr_rdy;
    axi4lite_s2m_RVALID     <= rd_data_valid;
    axi4lite_s2m_RDATA      <= rd_data;
    


    repeat (2) @ (posedge ACLK);  // temp HACK
    axi4lite_s2m_AWREADY    = '0;
    axi4lite_s2m_WREADY     = '0;
    axi4lite_s2m_BVALID     = '0;
    axi4lite_s2m_ARREADY    = '0;
    axi4lite_s2m_RVALID     = '0;

    @ (posedge ACLK)  // total 2 clock cycles after input assignmments

    waitrequest             = ~(rd_addr_rdy & wr_addr_rdy);

    // Display port information
    if (DEBUG) 
        print_avmm_s2m_if();
    

    // Checker    
    assert(avmm_s2m_readdatavalid == rd_data_valid)         else $error($time, "\t%m checker failed for signal - read data valid, actual = %h and expected = %h", avmm_s2m_readdatavalid, rd_data_valid);
    assert(avmm_s2m_readdata == rd_data)                    else $error($time, "\t%m checker failed for signal - read data, actual = %h and expected = %h", avmm_s2m_readdata, rd_data);
    assert(avmm_s2m_writeresponsevalid == wr_resp_valid)    else $error($time, "\t%m checker failed for signal - write resp valid, actual = %h and expected = %h", avmm_s2m_writeresponsevalid, wr_resp_valid);
    //assert(avmm_s2m_waitrequest == waitrequest)             else $error($time, "\t%m checker failed for signal - wait request, actual = %h and expected = %h", avmm_s2m_waitrequest, waitrequest);



endtask: test_pfam_s2m_ops


// ---------------------------------------------------------------------------------
// Display axi4lite port siganl information for Read or Write
// ---------------------------------------------------------------------------------
task automatic print_axi4lite_m2s_if(write, read);

    if (write) begin
        $display("------------------------------------------------------------------");
        $display($time, "\taxi4lite m2s interface - Write ");
        $display("------------------------------------------------------------------");

        $display("\tWrite Address Channel");
        $display("\t\tAWVALID = %0h", axi4lite_m2s_AWVALID);
        $display("\t\tAWADDR = %0h", axi4lite_m2s_AWADDR);
        $display("\t\tAWPROT = %0h", axi4lite_m2s_AWPROT);

        $display("\tWrite Data Channel");
        $display("\t\tWVALID = %0h", axi4lite_m2s_WVALID);
        $display("\t\tWDATA = %0h", axi4lite_m2s_WDATA);
        $display("\t\tWSTRB = %0h", axi4lite_m2s_WSTRB);

        $display("\tWrite Response Channel");
        $display("\t\tBREADY = %0h", axi4lite_m2s_BREADY);
    end

    if (read) begin
        $display("------------------------------------------------------------------");
        $display($time, "\taxi4lite m2s interface - Read ");
        $display("------------------------------------------------------------------");

        $display("\tRead Address Channel");
        $display("\t\tARVALID = %0h", axi4lite_m2s_ARVALID);
        $display("\t\tARADDR = %0h", axi4lite_m2s_ARADDR);
        $display("\t\tARPROT = %0h", axi4lite_m2s_ARPROT);

        $display("\tRead Data Channel");
        $display("\t\tRREADY = %0h", axi4lite_m2s_RREADY);
    end
    $display("------------------------------------------------------------------");


endtask : print_axi4lite_m2s_if    



// ---------------------------------------------------------------------------------
// Display axi4lite port siganl information for Read or Write
// ---------------------------------------------------------------------------------
task automatic print_avmm_s2m_if();

    $display("------------------------------------------------------------------");
    $display($time, "\tavmm s2m interface ");
    $display("------------------------------------------------------------------");
    $display("\tWrite Response Valid = %0h", avmm_s2m_writeresponsevalid);
    $display("\tRead Data Valid = %0h", avmm_s2m_readdatavalid);
    $display("\tRead Data = %0h", avmm_s2m_readdata);
    $display("\tWait Request = %0h", avmm_s2m_waitrequest);
    $display("------------------------------------------------------------------");

endtask : print_avmm_s2m_if




endmodule



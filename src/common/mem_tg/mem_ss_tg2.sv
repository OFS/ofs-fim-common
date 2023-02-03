`timescale 1 ps / 1 ps
module mem_ss_tg2
  #(
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
    )
(
 output wire                                    tg_cfg_waitrequest,
 input wire                                     tg_cfg_read,
 input wire                                     tg_cfg_write,
 input wire [9:0]                               tg_cfg_address,
 output wire [31:0]                             tg_cfg_readdata,
 input wire [31:0]                              tg_cfg_writedata,
 output wire                                    tg_cfg_readdatavalid, 
 input wire                                     emif_usr_reset_n, // emif_usr_reset_n.reset_n
 input wire                                     ninit_done, //       ninit_done.ninit_done
 input wire                                     emif_usr_clk, //     emif_usr_clk.clk
 output wire [PORT_CTRL_AXI4_AWID_WIDTH-1:0]    axi_awid, //         ctrl_axi.awid
 output wire [PORT_CTRL_AXI4_AWADDR_WIDTH-1:0]  axi_awaddr, //                 .awaddr
 output wire                                    axi_awvalid, //                 .awvalid
 output wire [PORT_CTRL_AXI4_AWUSER_WIDTH-1:0]  axi_awuser, //                 .awuser
 output wire [PORT_CTRL_AXI4_AWLEN_WIDTH-1:0]   axi_awlen, //                 .awlen
 output wire [PORT_CTRL_AXI4_AWSIZE_WIDTH-1:0]  axi_awsize, //                 .awsize
 output wire [PORT_CTRL_AXI4_AWBURST_WIDTH-1:0] axi_awburst, //                 .awburst
 input wire                                     axi_awready, //                 .awready
 output wire [PORT_CTRL_AXI4_AWLOCK_WIDTH-1:0]  axi_awlock, //                 .awlock
 output wire [PORT_CTRL_AXI4_AWCACHE_WIDTH-1:0] axi_awcache, //                 .awcache
 output wire [PORT_CTRL_AXI4_AWPROT_WIDTH-1:0]  axi_awprot, //                 .awprot
 output wire [PORT_CTRL_AXI4_ARID_WIDTH-1:0]    axi_arid, //                 .arid
 output wire [PORT_CTRL_AXI4_ARADDR_WIDTH-1:0]  axi_araddr, //                 .araddr
 output wire                                    axi_arvalid, //                 .arvalid
 output wire [PORT_CTRL_AXI4_ARUSER_WIDTH-1:0]  axi_aruser, //                 .aruser
 output wire [PORT_CTRL_AXI4_ARLEN_WIDTH-1:0]   axi_arlen, //                 .arlen
 output wire [PORT_CTRL_AXI4_ARSIZE_WIDTH-1:0]  axi_arsize, //                 .arsize
 output wire [PORT_CTRL_AXI4_ARBURST_WIDTH-1:0] axi_arburst, //                 .arburst
 input wire                                     axi_arready, //                 .arready
 output wire [PORT_CTRL_AXI4_ARLOCK_WIDTH-1:0]  axi_arlock, //                 .arlock
 output wire [PORT_CTRL_AXI4_ARCACHE_WIDTH-1:0] axi_arcache, //                 .arcache
 output wire [PORT_CTRL_AXI4_ARPROT_WIDTH-1:0]  axi_arprot, //                 .arprot
 output wire [PORT_CTRL_AXI4_WDATA_WIDTH-1:0]   axi_wdata, //                 .wdata
 output wire [PORT_CTRL_AXI4_WSTRB_WIDTH-1:0]   axi_wstrb, //                 .wstrb
 output wire                                    axi_wlast, //                 .wlast
 output wire                                    axi_wvalid, //                 .wvalid
 input wire                                     axi_wready, //                 .wready
 input wire [PORT_CTRL_AXI4_BID_WIDTH-1:0]      axi_bid, //                 .bid
 input wire [PORT_CTRL_AXI4_BRESP_WIDTH-1:0]    axi_bresp, //                 .bresp
 input wire [PORT_CTRL_AXI4_BUSER_WIDTH-1:0]    axi_buser, //                 .buser
 input wire                                     axi_bvalid, //                 .bvalid
 output wire                                    axi_bready, //                 .bready
 input wire [PORT_CTRL_AXI4_RDATA_WIDTH-1:0]    axi_rdata, //                 .rdata
 input wire [PORT_CTRL_AXI4_RRESP_WIDTH-1:0]    axi_rresp, //                 .rresp
 input wire [PORT_CTRL_AXI4_RUSER_WIDTH-1:0]    axi_ruser, //                 .ruser
 input wire                                     axi_rlast, //                 .rlast
 input wire                                     axi_rvalid, //                 .rvalid
 output wire                                    axi_rready, //                 .rready
 input wire [PORT_CTRL_AXI4_RID_WIDTH-1:0]      axi_rid, //                 .rid
 output wire                                    traffic_gen_pass, //        tg_status.traffic_gen_pass
 output wire                                    traffic_gen_fail, //                 .traffic_gen_fail
 output wire                                    traffic_gen_timeout  //                 .traffic_gen_timeout
 );

	altera_emif_avl_tg_2_top #(
		.PROTOCOL_ENUM                         ("PROTOCOL_DDR4"),
		.MEM_TTL_DATA_WIDTH                    (72),
		.MEM_TTL_NUM_OF_WRITE_GROUPS           (9),
		.DIAG_EXPORT_TG_CFG_AVALON_SLAVE       ("TG_CFG_AMM_EXPORT_MODE_EXPORT"),
		.TEST_CSR                              (0),
		.TG_TIMEOUT_WIDTH                      (32),
		.COMPARE_ADDR_GEN_FIFO_WIDTH           (64),
		.RW_LOOP_COUNT_WIDTH                   (32),
		.AMM_CFG_ADDR_WIDTH                    (10),
		.RW_RPT_COUNT_WIDTH                    (16),
		.RW_OPERATION_COUNT_WIDTH              (12),
		.MEGAFUNC_DEVICE_FAMILY                ("FALCONMESA"),
		.NUM_OF_CTRL_PORTS                     (1),
		.CTRL_AVL_PROTOCOL_ENUM                (""),
		.USE_AVL_BYTEEN                        (0),
		.AMM_WORD_ADDRESS_WIDTH                (27),
		.AMM_WORD_ADDRESS_DIVISIBLE_BY         (1),
		.AMM_BURST_COUNT_DIVISIBLE_BY          (1),
		.TEST_DURATION                         ("SHORT"),
		.BYPASS_DEFAULT_PATTERN                (1),
		.BYPASS_USER_STAGE                     (0),
		.AVL_TO_DQ_WIDTH_RATIO                 (16),
		.CORE_CLK_FREQ_HZ                      (300000000),
		.CTRL_INTERFACE_TYPE                   ("AXI"),
		.PORT_SUBSYSTEM_CSR_AXI4L_AWADDR_WIDTH (23),
		.PORT_SUBSYSTEM_CSR_AXI4L_AWPROT_WIDTH (3),
		.PORT_SUBSYSTEM_CSR_AXI4L_ARADDR_WIDTH (23),
		.PORT_SUBSYSTEM_CSR_AXI4L_ARPROT_WIDTH (3),
		.PORT_SUBSYSTEM_CSR_AXI4L_WDATA_WIDTH  (32),
		.PORT_SUBSYSTEM_CSR_AXI4L_WSTRB_WIDTH  (4),
		.PORT_SUBSYSTEM_CSR_AXI4L_BRESP_WIDTH  (2),
		.PORT_SUBSYSTEM_CSR_AXI4L_RDATA_WIDTH  (32),
		.PORT_SUBSYSTEM_CSR_AXI4L_RRESP_WIDTH  (2),
		.PORT_CTRL_AXI4_AWID_WIDTH             (PORT_CTRL_AXI4_AWID_WIDTH),
		.PORT_CTRL_AXI4_AWADDR_WIDTH           (PORT_CTRL_AXI4_AWADDR_WIDTH),
		.PORT_CTRL_AXI4_AWUSER_WIDTH           (PORT_CTRL_AXI4_AWUSER_WIDTH),
		.PORT_CTRL_AXI4_AWLEN_WIDTH            (PORT_CTRL_AXI4_AWLEN_WIDTH),
		.PORT_CTRL_AXI4_AWSIZE_WIDTH           (PORT_CTRL_AXI4_AWSIZE_WIDTH),
		.PORT_CTRL_AXI4_AWBURST_WIDTH          (PORT_CTRL_AXI4_AWBURST_WIDTH),
		.PORT_CTRL_AXI4_AWLOCK_WIDTH           (PORT_CTRL_AXI4_AWLOCK_WIDTH),
		.PORT_CTRL_AXI4_AWCACHE_WIDTH          (PORT_CTRL_AXI4_AWCACHE_WIDTH),
		.PORT_CTRL_AXI4_AWPROT_WIDTH           (PORT_CTRL_AXI4_AWPROT_WIDTH),
		.PORT_CTRL_AXI4_ARID_WIDTH             (PORT_CTRL_AXI4_ARID_WIDTH),
		.PORT_CTRL_AXI4_ARADDR_WIDTH           (PORT_CTRL_AXI4_ARADDR_WIDTH),
		.PORT_CTRL_AXI4_ARUSER_WIDTH           (PORT_CTRL_AXI4_ARUSER_WIDTH),
		.PORT_CTRL_AXI4_ARLEN_WIDTH            (PORT_CTRL_AXI4_ARLEN_WIDTH),
		.PORT_CTRL_AXI4_ARSIZE_WIDTH           (PORT_CTRL_AXI4_ARSIZE_WIDTH),
		.PORT_CTRL_AXI4_ARBURST_WIDTH          (PORT_CTRL_AXI4_ARBURST_WIDTH),
		.PORT_CTRL_AXI4_ARLOCK_WIDTH           (PORT_CTRL_AXI4_ARLOCK_WIDTH),
		.PORT_CTRL_AXI4_ARCACHE_WIDTH          (PORT_CTRL_AXI4_ARCACHE_WIDTH),
		.PORT_CTRL_AXI4_ARPROT_WIDTH           (PORT_CTRL_AXI4_ARPROT_WIDTH),
		.PORT_CTRL_AXI4_WDATA_WIDTH            (PORT_CTRL_AXI4_WDATA_WIDTH),
		.PORT_CTRL_AXI4_WSTRB_WIDTH            (PORT_CTRL_AXI4_WSTRB_WIDTH),
		.PORT_CTRL_AXI4_BID_WIDTH              (PORT_CTRL_AXI4_BID_WIDTH),
		.PORT_CTRL_AXI4_BRESP_WIDTH            (PORT_CTRL_AXI4_BRESP_WIDTH),
		.PORT_CTRL_AXI4_BUSER_WIDTH            (PORT_CTRL_AXI4_BUSER_WIDTH),
		.PORT_CTRL_AXI4_RID_WIDTH              (PORT_CTRL_AXI4_RID_WIDTH),
		.PORT_CTRL_AXI4_RDATA_WIDTH            (PORT_CTRL_AXI4_RDATA_WIDTH),
		.PORT_CTRL_AXI4_RRESP_WIDTH            (PORT_CTRL_AXI4_RRESP_WIDTH),
		.PORT_CTRL_AXI4_RUSER_WIDTH            (PORT_CTRL_AXI4_RUSER_WIDTH),
		.PORT_CTRL_AMM_ADDRESS_WIDTH           (1),
		.PORT_CTRL_AMM_RDATA_WIDTH             (1),
		.PORT_CTRL_AMM_WDATA_WIDTH             (1),
		.PORT_CTRL_AMM_BCOUNT_WIDTH            (1),
		.PORT_CTRL_AMM_BYTEEN_WIDTH            (1),
		.PORT_CTRL_MMR_MASTER_ADDRESS_WIDTH    (10),
		.PORT_CTRL_MMR_MASTER_RDATA_WIDTH      (32),
		.PORT_CTRL_MMR_MASTER_WDATA_WIDTH      (32),
		.PORT_CTRL_MMR_MASTER_BCOUNT_WIDTH     (2),
		.PORT_TG_CFG_ADDRESS_WIDTH             (10),
		.PORT_TG_CFG_RDATA_WIDTH               (32),
		.PORT_TG_CFG_WDATA_WIDTH               (32)
	) tg_0 (
		.emif_usr_reset_n                (emif_usr_reset_n),                     //   input,    width = 1, emif_usr_reset_n.reset_n
		.ninit_done                      (ninit_done),                           //   input,    width = 1,       ninit_done.ninit_done
		.emif_usr_clk                    (emif_usr_clk),                         //   input,    width = 1,     emif_usr_clk.clk
		.axi_awid                        (axi_awid),                             //  output,    width = 9,         ctrl_axi.awid
		.axi_awaddr                      (axi_awaddr),                           //  output,   width = 32,                 .awaddr
		.axi_awvalid                     (axi_awvalid),                          //  output,    width = 1,                 .awvalid
		.axi_awuser                      (axi_awuser),                           //  output,    width = 1,                 .awuser
		.axi_awlen                       (axi_awlen),                            //  output,    width = 8,                 .awlen
		.axi_awsize                      (axi_awsize),                           //  output,    width = 3,                 .awsize
		.axi_awburst                     (axi_awburst),                          //  output,    width = 2,                 .awburst
		.axi_awready                     (axi_awready),                          //   input,    width = 1,                 .awready
		.axi_awlock                      (axi_awlock),                           //  output,    width = 1,                 .awlock
		.axi_awcache                     (axi_awcache),                          //  output,    width = 4,                 .awcache
		.axi_awprot                      (axi_awprot),                           //  output,    width = 3,                 .awprot
		.axi_arid                        (axi_arid),                             //  output,    width = 9,                 .arid
		.axi_araddr                      (axi_araddr),                           //  output,   width = 32,                 .araddr
		.axi_arvalid                     (axi_arvalid),                          //  output,    width = 1,                 .arvalid
		.axi_aruser                      (axi_aruser),                           //  output,    width = 1,                 .aruser
		.axi_arlen                       (axi_arlen),                            //  output,    width = 8,                 .arlen
		.axi_arsize                      (axi_arsize),                           //  output,    width = 3,                 .arsize
		.axi_arburst                     (axi_arburst),                          //  output,    width = 2,                 .arburst
		.axi_arready                     (axi_arready),                          //   input,    width = 1,                 .arready
		.axi_arlock                      (axi_arlock),                           //  output,    width = 1,                 .arlock
		.axi_arcache                     (axi_arcache),                          //  output,    width = 4,                 .arcache
		.axi_arprot                      (axi_arprot),                           //  output,    width = 3,                 .arprot
		.axi_wdata                       (axi_wdata),                            //  output,  width = 256,                 .wdata
		.axi_wstrb                       (axi_wstrb),                            //  output,   width = 32,                 .wstrb
		.axi_wlast                       (axi_wlast),                            //  output,    width = 1,                 .wlast
		.axi_wvalid                      (axi_wvalid),                           //  output,    width = 1,                 .wvalid
		.axi_wready                      (axi_wready),                           //   input,    width = 1,                 .wready
		.axi_bid                         (axi_bid),                              //   input,    width = 9,                 .bid
		.axi_bresp                       (axi_bresp),                            //   input,    width = 2,                 .bresp
		.axi_buser                       (axi_buser),                            //   input,    width = 1,                 .buser
		.axi_bvalid                      (axi_bvalid),                           //   input,    width = 1,                 .bvalid
		.axi_bready                      (axi_bready),                           //  output,    width = 1,                 .bready
		.axi_rdata                       (axi_rdata),                            //   input,  width = 256,                 .rdata
		.axi_rresp                       (axi_rresp),                            //   input,    width = 2,                 .rresp
		.axi_ruser                       (axi_ruser),                            //   input,    width = 1,                 .ruser
		.axi_rlast                       (axi_rlast),                            //   input,    width = 1,                 .rlast
		.axi_rvalid                      (axi_rvalid),                           //   input,    width = 1,                 .rvalid
		.axi_rready                      (axi_rready),                           //  output,    width = 1,                 .rready
		.axi_rid                         (axi_rid),                              //   input,    width = 9,                 .rid
		.traffic_gen_pass                (traffic_gen_pass),                     //  output,    width = 1,        tg_status.traffic_gen_pass
		.traffic_gen_fail                (traffic_gen_fail),                     //  output,    width = 1,                 .traffic_gen_fail
		.traffic_gen_timeout             (traffic_gen_timeout),                  //  output,    width = 1,                 .traffic_gen_timeout
		.ss_base_csr_axi4l_awaddr        (),                                     // (terminated),                                
		.ss_base_csr_axi4l_awvalid       (),                                     // (terminated),                                
		.ss_base_csr_axi4l_awready       (1'b0),                                 // (terminated),                                
		.ss_base_csr_axi4l_awprot        (),                                     // (terminated),                                
		.ss_base_csr_axi4l_araddr        (),                                     // (terminated),                                
		.ss_base_csr_axi4l_arvalid       (),                                     // (terminated),                                
		.ss_base_csr_axi4l_arready       (1'b0),                                 // (terminated),                                
		.ss_base_csr_axi4l_arprot        (),                                     // (terminated),                                
		.ss_base_csr_axi4l_wdata         (),                                     // (terminated),                                
		.ss_base_csr_axi4l_wstrb         (),                                     // (terminated),                                
		.ss_base_csr_axi4l_wvalid        (),                                     // (terminated),                                
		.ss_base_csr_axi4l_wready        (1'b0),                                 // (terminated),                                
		.ss_base_csr_axi4l_bresp         (2'b00),                                // (terminated),                                
		.ss_base_csr_axi4l_bvalid        (1'b0),                                 // (terminated),                                
		.ss_base_csr_axi4l_bready        (),                                     // (terminated),                                
		.ss_base_csr_axi4l_rdata         (32'b00000000000000000000000000000000), // (terminated),                                
		.ss_base_csr_axi4l_rresp         (2'b00),                                // (terminated),                                
		.ss_base_csr_axi4l_rvalid        (1'b0),                                 // (terminated),                                
		.ss_base_csr_axi4l_rready        (),                                     // (terminated),                                
		.ctrl_user_priority_hi_0         (),                                     // (terminated),                                
		.ctrl_auto_precharge_req_0       (),                                     // (terminated),                                
		.ctrl_ecc_user_interrupt_0       (1'b0),                                 // (terminated),                                
		.ctrl_ecc_readdataerror_0        (1'b0),                                 // (terminated),                                
		.mmr_master_waitrequest_0        (1'b0),                                 // (terminated),                                
		.mmr_master_read_0               (),                                     // (terminated),                                
		.mmr_master_write_0              (),                                     // (terminated),                                
		.mmr_master_address_0            (),                                     // (terminated),                                
		.mmr_master_readdata_0           (32'b00000000000000000000000000000000), // (terminated),                                
		.mmr_master_writedata_0          (),                                     // (terminated),                                
		.mmr_master_burstcount_0         (),                                     // (terminated),                                
		.mmr_master_beginbursttransfer_0 (),                                     // (terminated),                                
		.mmr_master_readdatavalid_0      (1'b0),                                 // (terminated),                                
		.tg_cfg_waitrequest              (tg_cfg_waitrequest),
		.tg_cfg_read                     (tg_cfg_read),
		.tg_cfg_write                    (tg_cfg_write),
		.tg_cfg_address                  (tg_cfg_address),
		.tg_cfg_readdata                 (tg_cfg_readdata),
		.tg_cfg_writedata                (tg_cfg_writedata),
		.tg_cfg_readdatavalid            (tg_cfg_readdatavalid) 
	);

endmodule

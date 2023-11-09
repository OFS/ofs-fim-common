// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT



package gdr_pkt_pkg;
    //localparam INTF_DATA_WD = 1 << (PARAM_RATE_OP + 6);
    
    localparam GEN_MEM_DEPTH = 8192;
    localparam GEN_MEM_ADDR = $clog2(GEN_MEM_DEPTH);
    
    localparam NO_OF_RCHK = 16;
    localparam NO_OF_RCHK_ADDR = $clog2(NO_OF_RCHK);
    
    localparam FCS_LEN       = 4;
    localparam PREAMBLE_LEN  = 11'd8;
    
    localparam PCS_C_IDLE    = 8'h07;
    localparam PCS_C_START   = 8'hfb;
    localparam PCS_C_END     = 8'hfd;
    localparam PCS_C_ERR     = 8'hfe;
    localparam PCS_C_ORD     = 8'h9c;
    localparam PCS_SFD       = 8'hd5;
    localparam PCS_PRE       = 8'h55;

    localparam AM_INS_PERIOD_400G   = 17'd40960;
    localparam AM_INS_PERIOD_200G   = 17'd40960;
    localparam AM_INS_PERIOD_100G   = 17'd81920;
    localparam AM_INS_PERIOD_40_50G = 17'd32768;
    localparam AM_INS_PERIOD_10_25G = 17'd81920;
    localparam AM_INS_CYC_400G   = 4'd2;
    localparam AM_INS_CYC_200G   = 4'd2;
    localparam AM_INS_CYC_100G   = 4'd5;
    localparam AM_INS_CYC_40_50G = 4'd2;
    localparam AM_INS_CYC_10_25G = 4'd4;
    
    // use address [9:2]
    localparam ADDR_CFG_MODE_0            = 8'h0;
    localparam ADDR_CFG_MODE_1            = 8'h1;
    localparam ADDR_CFG_MODE_2            = 8'h2;
    localparam ADDR_CFG_MODE_3            = 8'h3;
    localparam ADDR_CFG_START_PKT_GEN     = 8'h4;
    localparam ADDR_CFG_START_XFER_PKT    = 8'h5;
    localparam ADDR_TX_SOP_CNT            = 8'h6;
    localparam ADDR_TX_SOP_CNT_HI         = 8'h7;
    localparam ADDR_TX_EOP_CNT            = 8'h8;
    localparam ADDR_TX_EOP_CNT_HI         = 8'h9;
    localparam ADDR_TX_PKT_CNT            = 8'hA;
    localparam ADDR_TX_PKT_CNT_HI         = 8'hB;
    localparam ADDR_RX_SOP_CNT            = 8'hC;
    localparam ADDR_RX_SOP_CNT_HI         = 8'hD;
    localparam ADDR_RX_EOP_CNT            = 8'hE;
    localparam ADDR_RX_EOP_CNT_HI         = 8'hF;
    localparam ADDR_RX_PKT_CNT            = 8'h10;
    localparam ADDR_RX_PKT_CNT_HI         = 8'h11;
    localparam ADDR_RX_CRC_OK_CNT         = 8'h12;
    localparam ADDR_RX_CRC_OK_CNT_HI      = 8'h13;
    localparam ADDR_RX_CRC_ERR_CNT        = 8'h14;
    localparam ADDR_RX_CRC_ERR_CNT_HI     = 8'h15;
    localparam ADDR_SW_RST                = 8'h16;
    localparam ADDR_LAT_CNT               = 8'h17;
    localparam LAT_ADJ_CNT               = 8'h18;
    
    localparam ADDR_MEM_DATA_0            = {1'b1, 7'd0};
    localparam ADDR_MEM_DATA_1            = {1'b1, 7'd1};
    localparam ADDR_MEM_DATA_2            = {1'b1, 7'd2};
    localparam ADDR_MEM_DATA_3            = {1'b1, 7'd3};
    localparam ADDR_MEM_DATA_4            = {1'b1, 7'd4};
    localparam ADDR_MEM_DATA_5            = {1'b1, 7'd5};
    localparam ADDR_MEM_DATA_6            = {1'b1, 7'd6};
    localparam ADDR_MEM_DATA_7            = {1'b1, 7'd7};
    localparam ADDR_MEM_DATA_8            = {1'b1, 7'd8};
    localparam ADDR_MEM_DATA_9            = {1'b1, 7'd9};
    localparam ADDR_MEM_DATA_10            = {1'b1, 7'd10};
    localparam ADDR_MEM_DATA_11            = {1'b1, 7'd11};
    localparam ADDR_MEM_DATA_12            = {1'b1, 7'd12};
    localparam ADDR_MEM_DATA_13            = {1'b1, 7'd13};
    localparam ADDR_MEM_DATA_14            = {1'b1, 7'd14};
    localparam ADDR_MEM_DATA_15            = {1'b1, 7'd15};
    localparam ADDR_MEM_DATA_16            = {1'b1, 7'd16};
    localparam ADDR_MEM_DATA_17            = {1'b1, 7'd17};
    localparam ADDR_MEM_DATA_18            = {1'b1, 7'd18};
    localparam ADDR_MEM_DATA_19            = {1'b1, 7'd19};
    localparam ADDR_MEM_DATA_20            = {1'b1, 7'd20};
    localparam ADDR_MEM_DATA_21            = {1'b1, 7'd21};
    localparam ADDR_MEM_DATA_22            = {1'b1, 7'd22};
    localparam ADDR_MEM_DATA_23            = {1'b1, 7'd23};
    localparam ADDR_MEM_DATA_24            = {1'b1, 7'd24};
    localparam ADDR_MEM_DATA_25            = {1'b1, 7'd25};
    localparam ADDR_MEM_DATA_26            = {1'b1, 7'd26};
    localparam ADDR_MEM_DATA_27            = {1'b1, 7'd27};
    localparam ADDR_MEM_DATA_28            = {1'b1, 7'd28};
    localparam ADDR_MEM_DATA_29            = {1'b1, 7'd29};
    localparam ADDR_MEM_DATA_30            = {1'b1, 7'd30};
    localparam ADDR_MEM_DATA_31            = {1'b1, 7'd31};
    localparam ADDR_MEM_DATA_32            = {1'b1, 7'd32};
    localparam ADDR_MEM_DATA_33            = {1'b1, 7'd33};
    localparam ADDR_MEM_DATA_34            = {1'b1, 7'd34};
    localparam ADDR_MEM_DATA_35            = {1'b1, 7'd35};
    localparam ADDR_MEM_DATA_36            = {1'b1, 7'd36};
    localparam ADDR_MEM_DATA_37            = {1'b1, 7'd37};
    localparam ADDR_MEM_DATA_38            = {1'b1, 7'd38};
    localparam ADDR_MEM_DATA_39            = {1'b1, 7'd39};
    localparam ADDR_MEM_DATA_40            = {1'b1, 7'd40};
    localparam ADDR_MEM_DATA_41            = {1'b1, 7'd41};
    localparam ADDR_MEM_DATA_42            = {1'b1, 7'd42};
    localparam ADDR_MEM_DATA_43            = {1'b1, 7'd43};
    localparam ADDR_MEM_DATA_44            = {1'b1, 7'd44};
    localparam ADDR_MEM_DATA_45            = {1'b1, 7'd45};
    localparam ADDR_MEM_DATA_46            = {1'b1, 7'd46};
    localparam ADDR_MEM_DATA_47            = {1'b1, 7'd47};
    localparam ADDR_MEM_DATA_48            = {1'b1, 7'd48};
    localparam ADDR_MEM_DATA_49            = {1'b1, 7'd49};
    localparam ADDR_MEM_DATA_50            = {1'b1, 7'd50};
    localparam ADDR_MEM_DATA_51            = {1'b1, 7'd51};
    localparam ADDR_MEM_DATA_52            = {1'b1, 7'd52};
    localparam ADDR_MEM_DATA_53            = {1'b1, 7'd53};
    localparam ADDR_MEM_DATA_54            = {1'b1, 7'd54};
    localparam ADDR_MEM_DATA_55            = {1'b1, 7'd55};
    localparam ADDR_MEM_DATA_56            = {1'b1, 7'd56};
    localparam ADDR_MEM_DATA_57            = {1'b1, 7'd57};
    localparam ADDR_MEM_DATA_58            = {1'b1, 7'd58};
    localparam ADDR_MEM_DATA_59            = {1'b1, 7'd59};
    localparam ADDR_MEM_DATA_60            = {1'b1, 7'd60};
    localparam ADDR_MEM_DATA_61            = {1'b1, 7'd61};
    localparam ADDR_MEM_DATA_62            = {1'b1, 7'd62};
    localparam ADDR_MEM_DATA_63            = {1'b1, 7'd63};   
    localparam ADDR_MEM_CTL_0              = {1'b1, 7'd64};
    localparam ADDR_MEM_CTL_1              = {1'b1, 7'd65};
    localparam ADDR_MEM_CTL_2              = {1'b1, 7'd66};
    localparam ADDR_MEM_CTL_3              = {1'b1, 7'd67};
    localparam ADDR_MEM_CTL_4              = {1'b1, 7'd68};
    localparam ADDR_MEM_CTL_5              = {1'b1, 7'd69};
    localparam ADDR_MEM_CTL_6              = {1'b1, 7'd70};
    localparam ADDR_MEM_CTL_7              = {1'b1, 7'd71};
    localparam ADDR_MEM_MISC               = {1'b1, 7'd72};
    localparam ADDR_MEM_ACCESS             = {1'b1, 7'd73};
    
    
    localparam PCS_SOP_DATA = {PCS_C_START, PCS_PRE, PCS_PRE, PCS_PRE}; //'hfb_555555;
    
    localparam PCS_PRE_DATA = {PCS_PRE, PCS_PRE, PCS_PRE, PCS_SFD}; //'h555555_d5;

    localparam PCS_TERMINATE_DATA = {PCS_C_END, PCS_C_IDLE, PCS_C_IDLE, PCS_C_IDLE};

    localparam PCS_IDLE_DATA = {PCS_C_IDLE, PCS_C_IDLE, PCS_C_IDLE, PCS_C_IDLE};

    localparam PCS_8_IDLE_DATA = {PCS_C_IDLE, PCS_C_IDLE, PCS_C_IDLE, PCS_C_IDLE,
				  PCS_C_IDLE, PCS_C_IDLE, PCS_C_IDLE, PCS_C_IDLE };

    localparam IPG_DELAY_CNT = 10;
    
    typedef enum logic [7:0] 
       {
	CG_8CTL       = 8'h1e,     // 10_'h1e_C0_C1_C2_C3_C4_C5_C6_C7  $$$$
	CG_4CTL_O     = 8'h2d,     // 10_'h2d_C0_C1_C2_C3_O4_D5_D6_D7
	CG_4CTL_S     = 8'h33,     // 10_'h2d_C0_C1_C2_C3_S4_D5_D6_D7  ****
	CG_O_S        = 8'h66,     // 10_'h66_00_D1_D2_D3_S4_D5_D6_D7
	CG_O_O        = 8'h55,     // 10_'h55_00_D1_D2_D3_O4_D5_D6_D7
	CG_S_D        = 8'h78,     // 10_'H78_S0_D1_D2_D3_D4_D5_D6_D7  ****
	CG_O_C        = 8'h4B,     // 10_'H4B_00_D1_D2_D3_C4_C5_C6_C7
	CG_T_C        = 8'h87,     // 10_'H87_T0_C1_C2_C3_C4_C5_C6_C7  ####
	CG_1D_T_C     = 8'h99,     // 10_'H99_D0_T1_C2_C3_C4_C5_C6_C7  ####
	CG_2D_T_C     = 8'hAA,     // 10_'HAA_D0_D1_T2_C3_C4_C5_C6_C7  ####
	CG_3D_T_C     = 8'hB4,     // 10_'HB4_D0_D1_D2_T3_C4_C5_C6_C7  ####
	CG_4D_T_C     = 8'hCC,     // 10_'HCC_D0_D1_D2_D3_T4_C5_C6_C7  ####
	CG_5D_T_C     = 8'hD2,     // 10_'HCC_D0_D1_D2_D3_D4_T5_C6_C7  ####
	CG_6D_T_C     = 8'hE1,     // 10_'HE1_D0_D1_D2_D3_D4_D5_T6_C7  ####
	CG_7D_T_C     = 8'hFF      // 10_'HFF_D0_D1_D2_D3_D4_D5_D6_T7  ####
	}CODE_GRP_CTL_e;
    
    typedef enum logic [2:0] 
       {
        MODE_10_25G = 3'd0,
	MODE_40_50G = 3'd1,
	MODE_100G   = 3'd2,
	MODE_200G   = 3'd3,
	MODE_400G   = 3'd4
	}MODE_e;

    typedef enum logic [1:0]
       {
	MODE_PCS   = 2'd0,
	MODE_FLEXE = 2'd1,
	MODE_OTN   = 2'd2
	} MODE_OP_e;
       
    typedef enum logic [1:0] 
       {
        FIX_PKT_LEN = 2'd0,
	INC_PKT_LEN = 2'd1,
	RND_PKT_LEN = 2'd2
	}PKT_LEN_MODE_e;

    typedef enum logic [1:0] 
       {
        FIX_DAT_PAT = 2'd0,
	INC_DAT_PAT = 2'd1,
	RND_DAT_PAT = 2'd2
	}DAT_PAT_MODE_e;
    
    typedef struct packed {
	logic [3:0]  ctl;
	logic [31:0] data;	
    } DWORD_s;

    typedef struct packed {
	DWORD_s [1:0] data;
    } DWORD_4_s;

    typedef struct packed {
	DWORD_s [3:0] data;
    } DWORD_8_s;

    typedef struct packed {
	DWORD_s [7:0] data;
    } DWORD_16_s;

    typedef struct  packed {
	DWORD_s [15:0] data;
    } DWORD_32_s;

    // 32 wrd = 32*4 = 128B
    typedef struct  packed {
	DWORD_s [31:0] data;
    } DWORD_64_s;
    localparam DWORD_64_WD = $bits(DWORD_64_s);

    // 64 wrd = 64*4 = 256B
    typedef struct  packed {
	DWORD_s [63:0] data;
    } DWORD_128_s;
    localparam DWORD_128_WD = $bits(DWORD_128_s);

    typedef struct packed {
	logic [7:0] byte_data;
    } BYTE_DATA_s;

    // 4 Bytes
    typedef struct packed {
	logic [31:0] data;	
    } DATA_WRD_s;

    typedef struct packed {
	logic [3:0] ctl;	
    } CTL_WRD_s;

    
    // 8 Bytes
    typedef struct packed {
	BYTE_DATA_s [7:0] data;	
    } PCS_D_WRD_s;
    localparam PCS_D_WRD_WD = $bits(PCS_D_WRD_s);
    
    typedef struct packed {
	PCS_D_WRD_s [1:0] data;	
    } PCS_D_2_WRD_s;

    typedef struct packed {
	PCS_D_WRD_s [3:0] data;	
    } PCS_D_4_WRD_s;
    
    typedef struct packed {
	PCS_D_WRD_s [7:0] data;	
    } PCS_D_8_WRD_s;
    
    typedef struct packed {
	PCS_D_WRD_s [15:0] data;	
    } PCS_D_16_WRD_s;
    localparam PCS_D_16_WRD_WD = $bits(PCS_D_16_WRD_s );

    // 32 * 8 
    typedef struct packed {
	PCS_D_WRD_s [31:0] data;	
    } PCS_D_32_WRD_s;
    localparam PCS_D_32_WRD_WD = $bits(PCS_D_32_WRD_s );
    
    typedef struct packed {
	logic [7:0] ctl;	
    } PCS_C_WRD_s;
    localparam PCS_C_WRD_WD = $bits(PCS_C_WRD_s );
    
    typedef struct  packed {
	PCS_C_WRD_s [1:0] ctl;	
    } PCS_C_2_WRD_s;

    typedef struct  packed {
	PCS_C_WRD_s [3:0] ctl;	
    } PCS_C_4_WRD_s;

    typedef struct  packed {
	PCS_C_WRD_s [7:0] ctl;	
    } PCS_C_8_WRD_s;

    typedef struct  packed {
	PCS_C_WRD_s [15:0] ctl;	
    } PCS_C_16_WRD_s;
    localparam PCS_C_16_WRD_WD = $bits(PCS_C_16_WRD_s);
    
    typedef struct  packed {
	PCS_C_WRD_s [31:0] ctl;	
    } PCS_C_32_WRD_s;
    localparam PCS_C_32_WRD_WD = $bits(PCS_C_32_WRD_s);

    typedef struct packed {
	logic [1:0] sync;
	CODE_GRP_CTL_e cg_tcl;
	logic [55:0] data;
    } ENC_CTL_WRD_s;
    localparam ENC_CTL_WRD_WD = $bits(ENC_CTL_WRD_s);

    
    typedef struct packed {
	logic [1:0] sync;	
    } PCS_SYNC_WRD_s;
    localparam PCS_SYNC_WRD_WD = $bits(PCS_SYNC_WRD_s);
    
    typedef struct packed {
	PCS_SYNC_WRD_s [15:0] sync;	
    } PCS_SYNC_16_WRD_s;
    localparam PCS_SYNC_16_WRD_WD = $bits(PCS_SYNC_16_WRD_s);

    typedef struct packed {
	PCS_SYNC_WRD_s [31:0] sync;	
    } PCS_SYNC_32_WRD_s;
    localparam PCS_SYNC_32_WRD_WD = $bits(PCS_SYNC_32_WRD_s);
    
    typedef struct packed {
	logic [1:0] sync;
	logic [63:0] data;
    } ENC_WRD_s;
    localparam ENC_WRD_WD = $bits(ENC_WRD_s);
    
    typedef struct packed {
	DWORD_s      data;
	logic 	     sop;
	logic 	     terminate;
	logic 	     vld;
	logic [8:0]  cyc_cnt;
	logic [12:0] mem_addr;
	logic 	     mem_wr;
	logic [10:0]  pkt_len;
	logic [12:0] pkt_cnt;
    } GEN_PKT_DATA_s;

    typedef struct   packed {
	DWORD_128_s              mem_data;
        logic 	                 sop;
	logic 	                 terminate;
	logic [GEN_MEM_ADDR-1:0] mem_addr;
	logic 	                 mem_wr;
    }GEN_MEM_WR_s;
    localparam GEN_MEM_WR_WD = $bits(GEN_MEM_WR_s);

    typedef struct   packed {
	DWORD_128_s             mem_data;
        logic 	                 sop;
	logic 	                 terminate;
	logic [GEN_MEM_ADDR-1:0] mem_addr;
	logic 	                 mem_wr;
	logic 	                 mem_rd;
    }CFG_GEN_MEM_REQ_s;
    localparam CFG_GEN_MEM_REQ_WD = $bits(CFG_GEN_MEM_REQ_s);
   
    typedef struct   packed {
	logic 	     sop;
	logic 	     terminate;
	DWORD_128_s  mem_data;
        
    }GEN_MEM_RD_RSP_s;
    localparam GEN_MEM_RD_RSP_WD = $bits(GEN_MEM_RD_RSP_s);
    

    typedef struct packed {
	logic 	      pkt_gen_done_stat; // [31]
	logic [1:0]        rsvd_1;            // [30:29]
	
	logic [12:0]  last_mem_addr;     // [16:28]  // sw generated pkt last mem address
	logic [12:0]  rsvd_0;            // [15:3]
	logic         sw_gen_pkt;        // [2]     // sw generated pkt indicator
	logic         dyn_pkt_gen;       // [1]
	logic         start_pkt_gen;     // [0]      // h/w generated pkts
    }CFG_START_PKT_GEN_s;

    typedef struct packed {
	logic 	      pkt_xfer_done_stat; // [31]
	logic [28:0]  rsvd_0;             // [30:2]
	logic         xfer_pkt_after_pkt_gen; // [1]
	logic         start_xfer_pkt;     // [0]
    }CFG_START_XFER_PKT_s;
    
    typedef struct packed {
	logic [7:0] 	  ipg_dly;        // [31:24]
	logic  	          init_done;      // [23]
	logic 	          rx2tx_lb;       // [22]
	logic 	          disable_am_ins; // [21]
	logic 	          cont_xfer_mode; // [20]	
	logic [3:0] 	  tmii_rdy_fix_dly; // [19:16]
	logic [1:0]       rsvd_3;         // [15:14]	
	DAT_PAT_MODE_e    pat_mode;       // [13:12]
	logic [1:0]       rsvd_2;         // [11:10]
	PKT_LEN_MODE_e    pkt_len_mode;   // [9:8]
	logic 	          rsvd_1;         // [7]
	MODE_e            mode;           // [6:4]
	logic [1:0]       rsvd_0;         // [3:2]
	MODE_OP_e         mode_op;        // [1:0]
    }CFG_MODE_0_s;

    typedef struct 	  packed {
	logic [7:0] 	  no_of_inc_bytes; // [31:24]
	logic [7:0]       fix_pattern;     // [23:16]
	logic [4:0]       rsvd_0;          // [15:11]
	logic [10:0]      fix_pkt_len;     // [10:0]
    }CFG_MODE_1_s;
    
    typedef struct 	  packed {
	logic [15:0]      no_of_xfer_pkt;  // [31:16]
	logic [2:0]       rsvd_0;          // [15:13]
	logic [12:0]      no_of_pkt_gen;   // [12:0]
    }CFG_MODE_2_s;

    typedef struct 	  packed {
	logic [3:0]       rsvd_1;          // [31:28]
	logic [3:0]       am_ins_cyc;      // [27:24]
	logic [6:0]       rsvd_0;          // [23:17]
	logic [16:0]      am_ins_period;   // [16:0]
    }CFG_MODE_3_s;

    typedef struct 	  packed {
	logic [31:2]      rsvd_0;          // [31:2]
        logic             exd_sw_rst;      // [1]
	logic             exd_stscnt_rst;      // [0]
    }CFG_SW_RST_s;
    
	 typedef struct 	  packed {
	logic            lat_cnt_en;     // [31]
	logic [30:8]      rsvd_0;          // [31:1]
	logic [7:0]      lat_cnt;      // [7:0]
    }CFG_LAT_CNT_s;
	 
	 typedef struct 	  packed {
	logic [31:0]      lat_adj_cnt;      // [31:0]
    }CFG_LAT_ADJ_CNT_s;
	 
    // counter peg and writable
    typedef struct packed {
	(* altera_attribute = {"-name SYNCHRONIZER_IDENTIFICATION FORCED;"} *) logic [31:0] cnt;
    }CFG_CNT_STATS_s;

    typedef struct packed {
	logic [31:0] dreg;
    }CFG_DREG_s;

    
    typedef struct packed {
	logic [29:0] rsvd_0;     // [31:2]
	logic 	     terminate;  // [1]
	logic        sop;        // [0]
    }CFG_MEM_MISC_s;
    
    typedef struct packed {
	logic [15:0] addr_req;  // [31:16]
	logic [13:0] rsvd_0;    // [15:2]
	logic 	     rd_req;      // [1]  "sw sets, hw clrs"
	logic 	     wr_req;      // [0]  "sw sets, hw clrs"
    }CFG_MEM_ACCESS_CTL_s;
    
	
    function MODE_e mode_enum;
	input [2:0]  mode;

	begin
	    case (mode)
		3'd0: mode_enum = MODE_10_25G;
		3'd1: mode_enum = MODE_40_50G;
		3'd2: mode_enum = MODE_100G;
		3'd3: mode_enum = MODE_200G;
		3'd4: mode_enum = MODE_400G;
		default: mode_enum = MODE_10_25G;
	    endcase
	end
    endfunction
		    
    function MODE_OP_e mode_op_enum;
	input [1:0] mode_op;

	begin
	    case (mode_op)
		2'd0: mode_op_enum = MODE_PCS;
		2'd1: mode_op_enum = MODE_OTN;
		2'd2: mode_op_enum = MODE_FLEXE;
		2'd3: mode_op_enum = MODE_PCS;
	    endcase
	end
    endfunction // mode_op_enum

    function PKT_LEN_MODE_e pkt_len_mode_enum;
	
	input [1:0] pkt_len_mode;

	begin
	    case (pkt_len_mode)
		2'd0: pkt_len_mode_enum = FIX_PKT_LEN;
		2'd1: pkt_len_mode_enum = INC_PKT_LEN;
		2'd2: pkt_len_mode_enum = RND_PKT_LEN;
		2'd3: pkt_len_mode_enum = FIX_PKT_LEN;
	    endcase
	end
    endfunction

    function DAT_PAT_MODE_e dat_pat_mode_enum;
	
	input [1:0] dat_pat_mode;

	begin
	    case (dat_pat_mode)
		2'd0: dat_pat_mode_enum = FIX_DAT_PAT;
		2'd1: dat_pat_mode_enum = INC_DAT_PAT;
		2'd2: dat_pat_mode_enum = RND_DAT_PAT;
		2'd3: dat_pat_mode_enum = FIX_DAT_PAT;
	    endcase
	end
    endfunction

endpackage // gdr_pkt_pkg
    

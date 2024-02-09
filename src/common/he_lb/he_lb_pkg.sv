// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT


package he_lb_pkg;

    localparam DW        = ofs_pcie_ss_cfg_pkg::TDATA_WIDTH;      // Data Width for streaming path
    localparam TAG_W     = ofs_pcie_ss_cfg_pkg::PCIE_EP_MAX_TAGS; // Tag width based on PCIe TLP 

    localparam CSR_AW    = 12-2;                                  // CSR Addr width
    localparam CSR_DW    = 64;                                    // CSR Data width
    localparam CSR_TAG_W = ofs_pcie_ss_cfg_pkg::PCIE_RP_MAX_TAGS; // Tag width based on PCIe TLP 

    localparam MAX_DATA_SIZE  = 1024;                        // Max number of cache lines transferred per test
    localparam TOTAL_LEN_W    = $clog2(MAX_DATA_SIZE);       // Num of bits required to represent MAX_DATA_SIZE
    localparam MAX_REQ_LEN    = 16;                          // Max number of cache lines transferred per request
    localparam REQ_LEN_W      = $clog2(MAX_REQ_LEN) + 1;     // Num of bits required to represent MAX_REQ_LEN

    // CSR requests from host
    typedef struct packed {
        logic                 wen;          // CSR write enable
        logic                 ren;          // CSR read enable
        logic [CSR_AW-1:0]    addr;         // 4B Aligned address
        logic [CSR_DW-1:0]    din;        
        logic                 len;          // 0 - 32b, 1 - 64b
        logic [CSR_TAG_W-1:0] tag;
    } he_csr_req;

    // CSR responses to host
    typedef struct packed {
        logic                 valid;        // CSR read data valid
        logic [CSR_DW-1:0]    data;         // CSR read data
        logic [CSR_AW-1:0]    addr;
        logic                 len;          // 0 - 32b, 1 - 64b
        logic [CSR_TAG_W-1:0] tag;
    } he_csr_dout;

    // Configuration from CSRs to exerciser engines

    typedef struct packed {
        logic [63:32] unused1;              // [63:32] unused
        logic [1:0] req_len_log2_high;      // [31:30] high bits oflog2 request length (lines)
                                            //         (used when HE_LB_API_VERSION >= 2)
        logic intr_on_done;                 // [   29] generate interrupt at test end
        logic intr_on_error;                // [   28] generate interrupt on error
        logic [27:23] extra_cfg;            // [27:23] extra config - currently ignored
        logic [2:0] tput_interleave;        // [22:20] RD/WR interleaving - currently ignored
        logic [19:12] unused0;              // [19:12] unused
        logic [2:0] atomic_func;            // [11: 9] atomic func (0 fadd, 1 swap, 2 cas)
        logic atomic_size;                  // [    8] atomic size (0: 4 bytes, 1: 8 bytes)
        logic atomic_req_en;                // [    7] generate atomic requests
        logic [1:0] req_len_log2;           // [ 6: 5] log2 request length (lines)
        logic [2:0] test_mode;              // [ 4: 2] test mode (0 lpbk, 1 read, 2 write, 3 trput)
        logic cont_mode;                    // [    1] continuous mode
        logic delay_en;                     // [    0] random delay insertion (not implemented)
    } he_csr2eng_cfg;

    typedef struct packed {
        logic [31: 3] unused;               // [31: 3] unused
        logic stop;                         // [    2] stop the test
        logic start;                        // [    1] start the test
        logic rst_n;                        // [    0] reset the test
    } he_csr2eng_ctl;

    typedef struct packed {
        logic [63:0]         src_address;
        logic [63:0]         dst_address;
        logic [31:0]         num_lines;
        logic [31:0]         inact_thresh;
        logic [31:0]         interrupt0;
        he_csr2eng_cfg       cfg;
        he_csr2eng_ctl       ctl;
        logic [31:0]         stride;
        logic [63:0]         dsm_base;
    } he_csr2eng;

    // State from exerciser engines to CSRs
    typedef logic [39:0] t_event_counter;

    typedef struct packed {
        t_event_counter      num_reads;
        t_event_counter      num_writes;
        logic [15:0]         num_host_rdpend;
        logic [15:0]         num_host_wrpend;
        logic [15:0]         num_emif_rdpend;
        logic [15:0]         num_emif_wrpend;
        logic [31:0]         error;
    } he_eng2csr;

endpackage

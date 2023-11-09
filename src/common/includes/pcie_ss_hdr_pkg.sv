// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
//  This package contains the parameter and struct definition for 
//  PCIe SS TLP header
//
//----------------------------------------------------------------------------

`ifndef __PCIE_SS_HDR_PKG_SV__
`define __PCIE_SS_HDR_PKG_SV__

package pcie_ss_hdr_pkg;

localparam TUSER_WIDTH = ofs_pcie_ss_cfg_pkg::TUSER_WIDTH;

localparam PCIE_TAG_WIDTH   = 10;
localparam PCIE_HDR_WIDTH   = 128;

localparam HDR_WIDTH        = 256;
localparam PF_WIDTH         = 3;
localparam VF_WIDTH         = 11;
localparam LOWER_ADDR_WIDTH = 24;

localparam PCIE_VDM_VENDOR_ID = 16'h1AB4; // message type and route by ID

// PCIe FMTTYPE 
localparam PCIE_TYPE_CPL = 5'b01010;
localparam PCIE_TYPE_MEM_RW = 5'b00000;

localparam PCIE_FMTTYPE_MEM_READ32   = 7'b000_0000;
localparam PCIE_FMTTYPE_MEM_READ64   = 7'b010_0000;
localparam PCIE_FMTTYPE_MEM_WRITE32  = 7'b100_0000;
localparam PCIE_FMTTYPE_MEM_WRITE64  = 7'b110_0000;
localparam PCIE_FMTTYPE_CFG_WRITE    = 7'b100_0100;
localparam PCIE_FMTTYPE_CPL          = 7'b000_1010;
localparam PCIE_FMTTYPE_CPLD         = 7'b100_1010;
localparam PCIE_FMTTYPE_FETCH_ADD32  = 7'b100_1100;
localparam PCIE_FMTTYPE_FETCH_ADD64  = 7'b110_1100;
localparam PCIE_FMTTYPE_SWAP32       = 7'b100_1101;
localparam PCIE_FMTTYPE_SWAP64       = 7'b110_1101;
localparam PCIE_FMTTYPE_CAS32        = 7'b100_1110;
localparam PCIE_FMTTYPE_CAS64        = 7'b110_1110;
localparam PCIE_FMTTYPE_VDM          = 2'b10; // message type

// Messages, without or with data, have consistent FMT (bits [7:5])
// and the top two bits of TYPE. ({FMT, TYPE} combine for 8 bits of
// TLP types.) The low 3 bits are defined in table 2-20 of the PCIe
// spec. and indicate routing, e.g. 010 is routing by ID. These low
// bits are ignored when detecting message packets.
localparam PCIE_FMTTYPE_MSGWOD       = 5'b00110;     // message wo/ data
localparam PCIE_FMTTYPE_MSGWD        = 5'b01110;     // message w/ data

// Message codes used in byte 7 of MSG TLPs
localparam PCIE_MSGCODE_ATS_INVAL_REQ = 8'b0000_0001; // ATS invalidate request
localparam PCIE_MSGCODE_ATS_INVAL_CPL = 8'b0000_0010; // ATS invalidate complation
localparam PCIE_MSGCODE_PAGE_REQ      = 8'b0000_0100; // Page request interface - map a page
localparam PCIE_MSGCODE_PAGE_RSP      = 8'b0000_0101; // Page group response
localparam PCIE_MSGCODE_VDM           = 8'b0111_1111; // Vendor-defined type 1

// ---------------------------------------------------------------------------
//         Standard PCIe header (127-bit) definition for power user mode 
// ---------------------------------------------------------------------------
// 1st DW in TLP header (Big endian)
typedef struct packed {
   logic               rsvd1;
   logic [6:0]         fmttype;
   logic               tag_h;
   logic [2:0]         tc;
   logic               tag_m;
   logic [1:0]         rsvd2;
   logic               th;
   logic               td;
   logic               ep;
   logic [1:0]         attr;
   logic [1:0]         rsvd3;
   logic [9:0]         length;

} t_pu_tlp_hdr_dw0;


// PCIe VDM request TLP header (Big endian)
typedef struct packed {
   // Byte 31 - Byte 16
   logic [127:0]         rsvd2; 

   // Byte 15 - Byte 12
   logic [31:0]          rsvd1; 

   // Byte 11 - Byte 8
   logic [15:0]          target_id;    
   logic [15:0]          vendor_id;    

   // Byte 7 - Byte 4
   logic [15:0]          requester_id;
   logic [7:0]           tag;
   logic [7:0]           msg_code;

   // Byte 3 - Byte 0
   t_pu_tlp_hdr_dw0    dw0;

} t_pu_vdm_tlp_req_hdr;
localparam PCIE_PU_VDM_REQ_HDR_WIDTH = $bits(t_pu_vdm_tlp_req_hdr);

// PCIe memory request TLP header (Big endian)
typedef struct packed {
   // Byte 15 - Byte 12
   logic [31:0]          lsb_addr; // MWr64/MRd64:address[31:0];  MWr32/MRd32:Rsvd

   // Byte 11 - Byte 8
   logic [31:0]          addr;     // MWr64/MRd64:address[63:32]; MWr32/MRd32:address[31:0]

   // Byte 7 - Byte 4
   logic [15:0]          requester_id;
   logic [7:0]           tag;
   logic [3:0]           last_be;
   logic [3:0]           first_be;

   // Byte 3 - Byte 0
   t_pu_tlp_hdr_dw0    dw0;

} t_pu_tlp_req_hdr;
localparam PCIE_PU_REQ_HDR_WIDTH = $bits(t_pu_tlp_req_hdr);

// PCIe completion TLP header (Big endian)
typedef struct packed {
   // Byte 15 - Byte 12
   logic [31:0]          rsvd1;

   // Byte 11 - Byte 8
   logic [15:0]          requester_id;
   logic [7:0]           tag;
   logic                 rsvd2;
   logic [6:0]           lower_addr;
   
   // Byte 7 - Byte 4
   logic [15:0]          completer_id;
   logic [2:0]           status;
   logic                 bcm;
   logic [11:0]          byte_count;
   
   // Byte 3 - Byte 0
   t_pu_tlp_hdr_dw0    dw0;

} t_pu_tlp_cpl_hdr;
localparam PCIE_PU_CPL_HDR_WIDTH = $bits(t_pu_tlp_cpl_hdr);

// PCIe message TLP header (Big endian)
typedef struct packed {
   // Byte 15 - Byte 12  
   logic [31:0]          lower_msg;

   // Byte 11 - Byte 8
   logic [31:0]          upper_msg;

   // Byte 7 - Byte 4
   logic [15:0]          requester_id;
   logic [7:0]           tag;
   logic [7:0]           msg_code;
   
   // Byte 3 - Byte 0
   t_pu_tlp_hdr_dw0    dw0;

} t_pu_tlp_msg_hdr;
localparam PCIE_PU_MSG_HDR_WIDTH = $bits(t_pu_tlp_msg_hdr);

// Header Fmt/Type Field Description
typedef enum logic [7:0] { //             Usage                                         on PCIe maps to
    M_RD     = 8'h00,   //  Power User Read (32-bit address)                        PCIE_FMTTYPE_MEM_READ32
    DM_RD    = 8'h20,   //  Power User Read (64-bit address), Data Mover Read       PCIE_FMTTYPE_MEM_READ64
    M_WR     = 8'h40,   //  Power User Write (32-bit address)                       PCIE_FMTTYPE_MEM_WRITE32
    DM_WR    = 8'h60,   //  Power User Write (64-bit address), Data Mover Write     PCIE_FMTTYPE_MEM_WRITE64
    DM_INTR  = 8'h30,   //  Data Mover Interrupt                                    PCIE_FMTTYPE_MSGWOD
    DM_CPL   = 8'h4a,   //  Data Mover Completion                                   PCIE_FMTTYPE_CPLD
    M_FADD32 = 8'h4c,   //  PU fetch and add (32-bit address)                       PCIE_FMTTYPE_FETCH_ADD32
    M_FADD64 = 8'h6c,   //  PU fetch and add (64-bit address), DM NOT SUPPORTED     PCIE_FMTTYPE_FETCH_ADD64
    M_SWAP32 = 8'h4d,   //  PU swap (32-bit address)                                PCIE_FMTTYPE_SWAP32
    M_SWAP64 = 8'h6d,   //  PU swap (64-bit address), DM NOT SUPPORTED              PCIE_FMTTYPE_SWAP64
    M_CAS32  = 8'h4e,   //  PU compare and swap (32-bit address)                    PCIE_FMTTYPE_CAS32
    M_CAS64  = 8'h6e    //  PU compare and swap (64-bit address), DM NOT SUPPORTED  PCIE_FMTTYPE_CAS64
} ReqHdr_FmtType_e;

// Attributes of DMRd and DMWr 
typedef struct packed {
    logic               rsvd1;      // Reserved
    logic               LN;
    logic               TH;
    logic               TD;
    logic               EP;
    logic   [1:0]       rsvd2;      // Reserved
    logic   [1:0]       AT;         
} ReqHdr_Attr_t;  // 9 bits width

// PF/VF numbering
typedef logic [10:0] ReqHdr_vf_num_t;
typedef logic [2:0]  ReqHdr_pf_num_t;

// Full PF/VF port info, can be passed as a parameter to configure AFUs
typedef struct packed {
    ReqHdr_pf_num_t     pf_num;
    ReqHdr_vf_num_t     vf_num;
    logic               vf_active;
} ReqHdr_pf_vf_info_t;

// ---------------------------------------------------------------------------
//          PCIe Power User Header  
// ---------------------------------------------------------------------------
// Power user mode header
typedef struct packed {
    // Byte 31 - Byte 24
    logic   [63:0]      rsvd1;              // Reserved

    // Byte 23 - Byte 20
    logic   [7:0]       rsvd2;              // Reserved
    logic   [4:0]       slot_num;           // Slot Number
    logic   [6:0]       bar_number;         // Bar Number 
    logic               vf_active;          // VF active     
    logic   [10:0]      vf_num;             // VF number 
    logic   [2:0]       pf_num;             // PF number

    // Byte 19 - Byte 16
    logic   [1:0]       rsvd3;              // Reserved
    logic               pref_present;       // Prefix Present
    logic   [4:0]       pref_type;          // Prefix Type
    logic   [23:0]      pref;               // Prefix

    // Byte 15 - Byte 0
    logic   [PCIE_HDR_WIDTH-1:0]     hdr;   // PCIe standard header
} PCIe_PUHdr_t;

// ---------------------------------------------------------------------------
//          PCIe Message Packet (Power User Mode) - with or without data
// ---------------------------------------------------------------------------
typedef struct packed {
    // Byte 31 - Byte 24
    logic   [63:0]      rsvd1;              // Reserved

    // Byte 23 - Byte 20
    logic   [7:0]       rsvd2;              // Reserved
    logic   [4:0]       slot_num;           // Slot Number
    logic   [3:0]       bar_number;         // Bar Number
    logic               vf_active;
    logic   [10:0]      vf_num;
    logic   [2:0]       pf_num;

    // Byte 19 - Byte 16
    logic   [1:0]       rsvd3;              // Reserved
    logic               pref_present;       // Prefix Present
    logic   [4:0]       pref_type;          // Prefix Type
    logic   [23:0]      pref;               // Prefix

    // Byte 15 - Byte 12
    logic   [31:0]      msg2;               // Message-specific value

    // Byte 11 - Byte 8
    logic   [31:0]      msg1;               // Message-specific value

    // Byte 7 - Byte 4
    logic   [15:0]      req_id;
    logic   [7:0]       msg0;               // Message-specific value (tag_l in messages with tags)
    logic   [7:0]       msg_code;           // Message code (see PCIE_MSGCODE_* above)

    // Byte 3 - Byte 0
    ReqHdr_FmtType_e    fmt_type;           // Specify the type (read/write) - 8 bits wide
    logic               tag_h;              // For messages with tags (reserved in others)
    logic   [2:0]       TC;                 // Traffic Channel
    logic               tag_m;              // For messages with tags (reserved in others)
    logic               attr_h;
    logic   [1:0]       rsvd4;
    logic               TD;
    logic               EP;
    logic   [1:0]       attr_l;
    logic   [1:0]       rsvd5;
    logic   [9:0]       length;             // Length in DW
} PCIe_PUMsgHdr_t;

// ---------------------------------------------------------------------------
//          PCIe Power User Request Packet (Power User Mode) 
// ---------------------------------------------------------------------------
typedef struct packed {
    // Byte 31 - Byte 28
    logic   [31:0]      metadata_l;         // meta-data field 

    // Byte 27 - Byte 24
    logic   [31:0]      metadata_h;         // meta-data field 

    // Byte 23 - Byte 20
    logic   [6:0]       bar_number;         // Bar Number 
    logic               mm_mode;            // Memory Mapped mode
    logic   [4:0]       slot_num;           // Slot Number
    logic   [3:0]       rsvd2;              // Reserved
    logic               vf_active;          
    logic   [10:0]      vf_num;             // 
    logic   [2:0]       pf_num;

    // Byte 19 - Byte 16
    logic   [1:0]       rsvd3;              // Reserved
    logic               pref_present;       // Prefix Present
    logic   [4:0]       pref_type;          // Prefix Type
    logic   [23:0]      pref;               // Prefix

    // Byte 15 - Byte 12
    logic   [29:0]      host_addr_l;        // HostAddress[31:2]
    logic   [1:0]       PH;    
    
    // Byte 11 - Byte 8 
    logic   [31:0]      host_addr_h;        // HostAddress[63:31]

    // Byte 7 - Byte 4
    logic   [15:0]      req_id;             // Requester ID
    logic   [7:0]       tag_l;              // Tag[7:0]
    logic   [3:0]       last_dw_be;         // Last DW BE
    logic   [3:0]       first_dw_be;        // First DW BE

    // Byte 3 - Byte 0
    ReqHdr_FmtType_e    fmt_type;           // Specify the type (read/write) - 8 bits wide
    logic               tag_h;              // Tag[9]
    logic   [2:0]       TC;                 // Traffic Channel 
    logic               tag_m;              // Tag[8]
    ReqHdr_Attr_t       attr;               // Attribute Bits - 9 bits wide
    logic   [9:0]       length;             // Length in DW

} PCIe_PUReqHdr_t;

// ---------------------------------------------------------------------------
//          PCIe Data Mover Request Header Packet (DMRd, DMWr) 
// ---------------------------------------------------------------------------
typedef struct packed {
    // Byte 31 - Byte 28
    logic   [31:0]      metadata_l;         // meta-data field 

    // Byte 27 - Byte 24
    logic   [31:0]      metadata_h;         // meta-data field 

    // Byte 23 - Byte 20
    logic   [6:0]       rsvd3;              // Reserved
    logic               mm_mode;            // Memory Mapped mode
    logic   [4:0]       slot_num;           // Slot Number
    logic   [3:0]       rsvd4;              // Reserved
    logic               vf_active;          
    logic   [10:0]      vf_num;             // 
    logic   [2:0]       pf_num;

    // Byte 19 - Byte 16
    logic   [1:0]       rsvd5;              // Reserved
    logic               pref_present;       // Prefix Present
    logic   [4:0]       pref_type;          // Prefix Type
    logic   [23:0]      pref;               // Prefix

    // Byte 15 - Byte 12
    logic   [29:0]      host_addr_m;        // HostAddress[31:2]
    logic   [1:0]       PH;    
    
    // Byte 11 - Byte 8 
    logic   [31:0]      host_addr_h;        // HostAddress[63:31]

    // Byte 7 - Byte 4
    logic   [1:0]       host_addr_l;        // HostAddress[1:0]
    logic   [11:0]      length_h;           // Length[23:12]
    logic   [1:0]       length_l;           // Length[1:0]
    logic   [7:0]       tag_l;              // Tag[7:0]
    logic   [7:0]       rsvd6;              // Reserved

    // Byte 3 - Byte 0
    ReqHdr_FmtType_e    fmt_type;           // Specify the type (read/write) - 8 bits wide
    logic               tag_h;              // Tag[9]
    logic   [2:0]       TC;                 // 
    logic               tag_m;              // Tag[8]
    ReqHdr_Attr_t       attr;               // Attribute Bits - 9 bits wide
    logic   [9:0]       length_m;           // Length[11:2]

} PCIe_ReqHdr_t;


// ---------------------------------------------------------------------------
//          PCIe Power User Completion Header Packet (Cpl) 
// ---------------------------------------------------------------------------
typedef struct packed {
    // Byte 31 - Byte 28
    logic   [31:0]      metadata_l;         // metadata[31:0]
    
    // Byte 27 - Byte 24
    logic   [31:0]      metadata_h;         // metadata[63:32]

    // Byte 23 - Byte 20
    logic   [6:0]       rsvd1;              // Reserved
    logic               mm_mode;            // Memory Mapped mode
    logic   [4:0]       slot_num;           // Slot Number
    logic   [3:0]       rsvd2;              // Reserved
    logic               vf_active;          // VF Active 
    logic   [10:0]      vf_num;             // VF Number
    logic   [2:0]       pf_num;             // PF Number

    // Byte 19 - Byte 16
    logic   [1:0]       rsvd3;              // Reserved
    logic               pref_present;       // Prefix Present
    logic   [4:0]       pref_type;          // Prefix Type
    logic   [23:0]      pref;               // Prefix 

    // Byte 15 - Byte 12
    logic   [31:0]      rsvd4;              // Reserved

    // Byte 11 - Byte 8 
    logic   [15:0]      req_id;             // Requester ID
    logic   [7:0]       tag_l;              // Tag[7:0]
    logic               rsvd5;              // Reserved
    logic   [6:0]       low_addr;           // LowerAddress

    // Byte 7 - Byte 4
    logic   [15:0]      comp_id;            // Completer ID
    logic   [2:0]       cpl_status;         // Completion Status
    logic               bcm;                // BCM
    logic   [11:0]      byte_count;         // Byte Count

    // Byte 3 - Byte 0
    ReqHdr_FmtType_e    fmt_type;           // Specify the type (read/write) - 8 bits wide
    logic               tag_h;              // Tag[9]
    logic   [2:0]       TC;                 // Traffic Channel 
    logic               tag_m;              // Tag[8]
    ReqHdr_Attr_t       attr;               // Attribute Bits - 9 bits wide
    logic   [9:0]       length;             // Length

} PCIe_PUCplHdr_t;



// ---------------------------------------------------------------------------
//          PCIe Data mover Completion Header Packet (DMCpl) 
// ---------------------------------------------------------------------------
typedef struct packed {
    // Byte 31 - Byte 28
    logic   [31:0]      metadata_l;         // metadata[31:0]
    
    // Byte 27 - Byte 24
    logic   [31:0]      metadata_h;         // metadata[63:32]

    // Byte 23 - Byte 20
    logic   [6:0]       rsvd1;              // Reserved
    logic               mm_mode;            // Memory Mapped mode
    logic   [4:0]       slot_num;           // Slot Number
    logic   [3:0]       rsvd2;              // Reserved
    logic               vf_active;          // VF Active 
    logic   [10:0]      vf_num;             // VF Number
    logic   [2:0]       pf_num;             // PF Number

    // Byte 19 - Byte 16
    logic   [1:0]       rsvd3;              // Reserved
    logic               pref_present;       // Prefix Present
    logic   [4:0]       pref_type;          // Prefix Type
    logic   [23:0]      pref;               // Prefix

    // Byte 15 - Byte 12
    logic   [9:0]       tag;                // TAG
    logic               FC;                 // FC
    logic               rsvd4;              // Reserved
    logic   [1:0]       length_h;           // length[13:12]
    logic   [1:0]       length_l;           // length[1:0]
    logic   [15:0]      low_addr_h;         // LowerAddress[23:8]
    
    // Byte 11 - Byte 8 
    logic   [15:0]      rsvd5;              // Reserved
    logic   [7:0]       rsvd6;              // Reserved
    logic   [7:0]       low_addr_l;         // LowerAddress[7:0]
    
    // Byte 7 - Byte 4
    logic   [15:0]      rsvd7;              // Reserved
    logic   [2:0]       cpl_status;         // Completition Status
    logic   [12:0]      rsvd8;              // Reserved

    // Byte 3 - Byte 0
    ReqHdr_FmtType_e    fmt_type;           // Specify the type (completion=4A)  - 8 bits wide
    logic               rsvd9;              // Reserved
    logic   [2:0]       TC;                 // TC
    logic               rsvd10;             // Reserved
    ReqHdr_Attr_t       attr;               // Attribute Bits - 9 bits wide
    logic   [9:0]       length_m;           // length[11:2]  

} PCIe_CplHdr_t;

//
// There are two variants of completion headers, differing only in the
// low_addr and length fields. When completion reordering is enabled,
// the header must be able to describe a length matching the original
// request. The low_addr_h field is broken in two, with the high
// 10 bits repurposed to hold length[23:14].
//
// There isn't a great way both to maintain backward compatibility and
// represent the change, so PCIe_OrdCplHdr_t is defined.
//
typedef struct packed {
    // Byte 31 - Byte 28
    logic   [31:0]      metadata_l;         // metadata[31:0]
    
    // Byte 27 - Byte 24
    logic   [31:0]      metadata_h;         // metadata[63:32]

    // Byte 23 - Byte 20
    logic   [6:0]       rsvd1;              // Reserved
    logic               mm_mode;            // Memory Mapped mode
    logic   [4:0]       slot_num;           // Slot Number
    logic   [3:0]       rsvd2;              // Reserved
    logic               vf_active;          // VF Active 
    logic   [10:0]      vf_num;             // VF Number
    logic   [2:0]       pf_num;             // PF Number

    // Byte 19 - Byte 16
    logic   [1:0]       rsvd3;              // Reserved
    logic               pref_present;       // Prefix Present
    logic   [4:0]       pref_type;          // Prefix Type
    logic   [23:0]      pref;               // Prefix

    // Byte 15 - Byte 12
    logic   [9:0]       tag;                // TAG
    logic               FC;                 // FC
    logic               rsvd4;              // Reserved
    logic   [1:0]       length_h;           // length[13:12]
    logic   [1:0]       length_l;           // length[1:0]
    logic   [9:0]       length_x;           // length[23:14]
    logic   [5:0]       low_addr_h;         // LowerAddress[13:8]
    
    // Byte 11 - Byte 8 
    logic   [15:0]      rsvd5;              // Reserved
    logic   [7:0]       rsvd6;              // Reserved
    logic   [7:0]       low_addr_l;         // LowerAddress[7:0]
    
    // Byte 7 - Byte 4
    logic   [15:0]      rsvd7;              // Reserved
    logic   [2:0]       cpl_status;         // Completition Status
    logic   [12:0]      rsvd8;              // Reserved

    // Byte 3 - Byte 0
    ReqHdr_FmtType_e    fmt_type;           // Specify the type (completion=4A)  - 8 bits wide
    logic               rsvd9;              // Reserved
    logic   [2:0]       TC;                 // TC
    logic               rsvd10;             // Reserved
    ReqHdr_Attr_t       attr;               // Attribute Bits - 9 bits wide
    logic   [9:0]       length_m;           // length[11:2]  

} PCIe_OrdCplHdr_t;

// ---------------------------------------------------------------------------
//          Interrupt Header Packet (DMIntr) 
// ---------------------------------------------------------------------------
typedef struct packed {
    // Byte 31 - Byte 28
    logic   [31:0]      rsvd1;              // Reserved

    // Byte 27 - Byte 24
    logic   [31:0]      rsvd2;              // Reserved

    // Byte 23 - Byte 20
    logic   [6:0]       rsvd3;              // Reserved
    logic               mm_mode;            // Memory Mapped mode
    logic   [4:0]       slot_num;           // Slot Number
    logic   [3:0]       rsvd4;              // Reserved
    logic               vf_active;          // VF Active 
    logic   [10:0]      vf_num;             // VF Number
    logic   [2:0]       pf_num;             // PF Number

    // Byte 19 - Byte 16
    logic   [1:0]       rsvd5;              // Reserved
    logic               pref_present;       // Prefix Present
    logic   [4:0]       pref_type;          // Prefix Type
    logic   [23:0]      pref;               // Prefix

    // Byte 15 - Byte 12
    logic   [31:0]      rsvd6;              // Reserved

    // Byte 11 - Byte 8 
    logic   [15:0]      rsvd7;              // Reserved
    logic   [15:0]      vector_num;         // Vector Number

    // Byte 7 - Byte 4
    logic   [31:0]      rsvd8;              // Reserved

    // Byte 3 - Byte 0
    ReqHdr_FmtType_e    fmt_type;           // Specify the type (Interrupt=30) - 8 bits wide
    logic   [23:0]      rsvd9;              // Reserved
    
} PCIe_IntrHdr_t;

//--------------------------------
// Functions and tasks
//--------------------------------
function automatic bit func_is_addr32 (
   input ReqHdr_FmtType_e fmttype
);
   return (fmttype[5] == 1'b0);
endfunction

function automatic bit func_is_addr64 (
   input ReqHdr_FmtType_e fmttype
);
   return (fmttype[5] == 1'b1);
endfunction

function automatic bit func_has_data (
   input ReqHdr_FmtType_e fmttype
);
   return (fmttype[6] == 1'b1);
endfunction

function automatic bit func_is_completion (
   input ReqHdr_FmtType_e fmttype
);
   return (fmttype[3:2] == 2'b10);
endfunction

function automatic bit func_is_interrupt_req (
   input ReqHdr_FmtType_e fmttype
);
   return (fmttype == DM_INTR);
endfunction

function automatic bit func_is_atomic_req (
   input ReqHdr_FmtType_e fmttype
);
   return (fmttype[6] & (fmttype[4:2] == 3'b011));
endfunction

function automatic bit func_is_mem_req (
   input ReqHdr_FmtType_e fmttype
);
   return ((fmttype[4:0] == PCIE_TYPE_MEM_RW) || func_is_atomic_req(fmttype));
endfunction

function automatic bit func_is_msg (
   input ReqHdr_FmtType_e fmttype
);
   // Either PCIE_FMTTYPE_MSGWOD or PCIE_FMTTYPE_MSGWD. Use func_has_data()
   // to check for MSGWD.
   return (~fmttype[7] & (fmttype[5:3] == 3'b110));
endfunction

function automatic bit func_is_vdm_req (
   input t_pu_tlp_hdr_dw0 fmttype
);
   return (fmttype[4:3] == PCIE_FMTTYPE_VDM);
endfunction

function automatic bit func_is_vdm_vendor_id (
   input t_pu_vdm_tlp_req_hdr vendor_id
);
   return (vendor_id == PCIE_VDM_VENDOR_ID);
endfunction


function automatic bit func_is_mem_req64 (
   input ReqHdr_FmtType_e fmttype
);
   return (func_is_mem_req(fmttype) && func_is_addr64(fmttype));
endfunction

function automatic bit func_is_mem_req32 (
   input ReqHdr_FmtType_e fmttype
);
   return (func_is_mem_req(fmttype) && func_is_addr32(fmttype));
endfunction

function automatic bit func_is_mwr_req (
   input ReqHdr_FmtType_e fmttype
);
   return (func_is_mem_req(fmttype) && fmttype[6]);
endfunction

function automatic bit func_is_mrd_req (
   input ReqHdr_FmtType_e fmttype
);
   return (func_is_mem_req(fmttype) && ~fmttype[6]);
endfunction

// Remap little endian DW to big endian format
function automatic [31:0] func_switch_endian (
   input logic [31:0] in
);
   // Output Byte 3-0 = Input Byte 0-3
   for (int i=0; i<4; ++i) begin
      func_switch_endian[i*8+:8] = in[(3-i)*8+:8];
   end
endfunction

// Convert power mode header to big endian header format
function automatic logic [PCIE_HDR_WIDTH-1:0] func_to_little_endian_hdr (
   input [PCIE_HDR_WIDTH-1:0] hdr
);
   for (int i=0; i<4; ++i) begin
      func_to_little_endian_hdr[i*32+:32] = func_switch_endian(hdr[i*32+:32]);
   end
endfunction

// Convert power mode header to big endian header format
function automatic logic [PCIE_HDR_WIDTH-1:0] func_get_pu_tlp_hdr (
   input PCIe_PUHdr_t ss_hdr
);
   logic [PCIE_HDR_WIDTH-1:0] hdr;
   hdr = ss_hdr.hdr;

   return hdr;
endfunction

// Get tag from header
function automatic logic [PCIE_TAG_WIDTH-1:0] func_get_hdr_tag (
   input t_pu_tlp_req_hdr hdr
);
   return {hdr.dw0.tag_h, hdr.dw0.tag_m, hdr.tag};
endfunction

// Is header PU encoding?
function automatic logic func_hdr_is_pu_mode (
   input logic [TUSER_WIDTH-1:0] tuser_vendor
);
   return ~tuser_vendor[0];
endfunction

// Is header DM encoding?
function automatic logic func_hdr_is_dm_mode (
   input logic [TUSER_WIDTH-1:0] tuser_vendor
);
   return tuser_vendor[0];
endfunction

// synthesis translate_off

function automatic string func_fmttype_to_string (
   input ReqHdr_FmtType_e fmttype
);
   string t;

   casex (fmttype)
      8'b00x0_0000:  t = "MRd"     ;
      8'b01x0_0000:  t = "MWr"     ;
      8'b00x0_0001:  t = "MRdLk"   ;
      8'b0000_0010:  t = "IORd "   ;
      8'b0100_0010:  t = "IOWr "   ;
      8'b0000_0100:  t = "CfgRd0"  ;
      8'b0100_0100:  t = "CfgWr0"  ;
      8'b0000_0101:  t = "CfgRd1"  ;
      8'b0100_0101:  t = "CfgWr1"  ;
      8'b0011_0xxx:  t = "Msg"     ;
      8'b0111_0xxx:  t = "MsgD"    ;
      8'b0000_1010:  t = "Cpl"     ;
      8'b0100_1010:  t = "CplD"    ;
      8'b0000_1011:  t = "CplLk"   ;
      8'b0100_1011:  t = "CplDLk"  ;
      8'b01x0_1100:  t = "FetAdd"  ;
      8'b01x0_1101:  t = "Swap"    ;
      8'b01x0_1110:  t = "CAS"     ;
      8'b1000_xxxx:  t = "LPrfx"   ;
      8'b1001_xxxx:  t = "EPrfx"   ;
      default:       t = "XXXXX"   ;
   endcase

   if (func_is_mem_req32(fmttype)) t = { t, "32" };
   if (func_is_mem_req64(fmttype)) t = { t, "64" };

   return t;
endfunction

function automatic string func_msgcode_to_string (
   input logic [7:0] msg_code
);
   string t;

   case (msg_code)
      PCIE_MSGCODE_ATS_INVAL_REQ: t = "ATS_INVAL_REQ";
      PCIE_MSGCODE_ATS_INVAL_CPL: t = "ATS_INVAL_CPL";
      PCIE_MSGCODE_PAGE_REQ:      t = "PAGE_REQ";
      PCIE_MSGCODE_PAGE_RSP:      t = "PAGE_RSP";
      PCIE_MSGCODE_VDM:           t = "VDM";
      default:                    t = $sformatf("code %b_%b", msg_code[7:4], msg_code[3:0]);
   endcase

   return t;
endfunction

function automatic string func_hdr_prefix_to_string (
   input logic pref_present,
   input logic [4:0] pref_type,
   input logic [23:0] pref
);
   if (!pref_present)
      return "";

   if (pref_type == 5'b10001)
      return $sformatf(" [pasid 0x%0x]", pref);
   else
      return $sformatf(" [prefix type 0x%x value 0x%0x]", pref_type, pref);
endfunction

function automatic string func_pu_mem_req_base_to_string (
   input PCIe_PUReqHdr_t hdr
);
   return $sformatf("%6s PU len 0x%x%s [pf %0d vf %0d vfa %0d] [tc %0d attr 0x%0x AT %x]",
                    func_fmttype_to_string(hdr.fmt_type),
                    hdr.length,
                    func_hdr_prefix_to_string(hdr.pref_present, hdr.pref_type, hdr.pref),
                    hdr.pf_num, hdr.vf_num, hdr.vf_active,
                    hdr.TC, hdr.attr, hdr.attr.AT);
endfunction

function automatic string func_dm_mem_req_base_to_string (
   input PCIe_ReqHdr_t hdr
);
   return $sformatf("%6s DM len 0x%x%s [pf %0d vf %0d vfa %0d] [tc %0d attr 0x%0x AT %x]",
                    func_fmttype_to_string(hdr.fmt_type),
                    { hdr.length_h, hdr.length_m, hdr.length_l },
                    func_hdr_prefix_to_string(hdr.pref_present, hdr.pref_type, hdr.pref),
                    hdr.pf_num, hdr.vf_num, hdr.vf_active,
                    hdr.TC, hdr.attr, hdr.attr.AT);
endfunction

function automatic string func_pu_mem_req_to_string (
   input PCIe_PUReqHdr_t hdr
);
   if (func_is_addr64(hdr.fmt_type)) begin
      return $sformatf("%s PU req_id 0x%h tag 0x%h lbe 0x%h fbe 0x%h addr 0x%h",
                       func_pu_mem_req_base_to_string(hdr),
                       hdr.req_id, { hdr.tag_h, hdr.tag_m, hdr.tag_l },
                       hdr.last_dw_be, hdr.first_dw_be,
                       { hdr.host_addr_h, hdr.host_addr_l, 2'b0 });
   end
   else begin
      return $sformatf("%s PU req_id 0x%h tag 0x%h lbe 0x%h fbe 0x%h addr 0x%h",
                       func_pu_mem_req_base_to_string(hdr),
                       hdr.req_id, { hdr.tag_h, hdr.tag_m, hdr.tag_l },
                       hdr.last_dw_be, hdr.first_dw_be,
                       { hdr.host_addr_h });
   end
endfunction

function automatic string func_dm_mem_req_to_string (
   input PCIe_ReqHdr_t hdr
);
   if (func_is_addr64(hdr.fmt_type)) begin
      return $sformatf("%s tag 0x%h addr 0x%h",
                       func_dm_mem_req_base_to_string(hdr),
                       { hdr.tag_h, hdr.tag_m, hdr.tag_l },
                       { hdr.host_addr_h, hdr.host_addr_m, hdr.host_addr_l });
   end
   else begin
      return $sformatf("%s tag 0x%h addr 0x%h",
                       func_dm_mem_req_base_to_string(hdr),
                       { hdr.tag_h, hdr.tag_m, hdr.tag_l },
                       { hdr.host_addr_h, hdr.host_addr_m, hdr.host_addr_l });
   end
endfunction

function automatic string func_pu_cpl_to_string (
   input PCIe_PUCplHdr_t hdr
);
   return $sformatf("%6s PU len 0x%x [pf %0d vf %0d vfa %0d] tc %h cpl_id 0x%h st %h bcm %h bytes 0x%h req_id 0x%h tag 0x%h low_addr 0x%h",
                    func_fmttype_to_string(hdr.fmt_type),
                    hdr.length,
                    hdr.pf_num, hdr.vf_num, hdr.vf_active,
                    hdr.TC, hdr.comp_id, hdr.cpl_status, hdr.bcm, hdr.byte_count,
                    hdr.req_id, { hdr.tag_h, hdr.tag_m, hdr.tag_l },
                    hdr.low_addr);
endfunction

function automatic string func_dm_cpl_to_string (
   input PCIe_CplHdr_t hdr
);
`ifdef OFS_PCIE_SS_PLAT_CFG_FLAG_CPL_REORDER
   // Use the proper header when completion reordering is enabled.
   if (ofs_pcie_ss_cfg_pkg::CPL_REORDER_EN) begin
      PCIe_OrdCplHdr_t o_hdr = PCIe_OrdCplHdr_t'(hdr);
      return $sformatf("%6s DM len 0x%x [pf %0d vf %0d vfa %0d] tc %h fc %h st %h tag 0x%h low_addr 0x%h",
                       func_fmttype_to_string(o_hdr.fmt_type),
                       { o_hdr.length_x, o_hdr.length_h, o_hdr.length_m, o_hdr.length_l },
                       o_hdr.pf_num, o_hdr.vf_num, o_hdr.vf_active,
                       o_hdr.TC, o_hdr.FC, o_hdr.cpl_status, o_hdr.tag,
                       { o_hdr.low_addr_h, o_hdr.low_addr_l });
    end
`endif

   return $sformatf("%6s DM len 0x%x [pf %0d vf %0d vfa %0d] tc %h fc %h st %h tag 0x%h low_addr 0x%h",
                    func_fmttype_to_string(hdr.fmt_type),
                    { hdr.length_h, hdr.length_m, hdr.length_l },
                    hdr.pf_num, hdr.vf_num, hdr.vf_active,
                    hdr.TC, hdr.FC, hdr.cpl_status, hdr.tag,
                    { hdr.low_addr_h, hdr.low_addr_l });
endfunction

function automatic string func_dm_intr_to_string (
   input PCIe_IntrHdr_t hdr
);
   return $sformatf("%6s DM [pf %0d vf %0d vfa %0d] vector 0x%h",
                    "Intr",   // Interrupts are encoded as Msg
                    hdr.pf_num, hdr.vf_num, hdr.vf_active,
                    hdr.vector_num);
endfunction

function automatic string func_pu_generic_to_string (
   input PCIe_PUReqHdr_t hdr
);
   return $sformatf("%s tag 0x%h",
                    func_pu_mem_req_base_to_string(hdr),
                    { hdr.tag_h, hdr.tag_m, hdr.tag_l });
endfunction

function automatic string func_dm_generic_to_string (
   input PCIe_ReqHdr_t hdr
);
   return $sformatf("%s tag 0x%h",
                    func_dm_mem_req_base_to_string(hdr),
                    { hdr.tag_h, hdr.tag_m, hdr.tag_l });
endfunction

function automatic string func_pu_msg_to_string (
   input PCIe_PUMsgHdr_t hdr
);
   string s;
   s = $sformatf("%6s PU %s type 0x%h len 0x%h [pf %0d vf %0d vfa %0d] [tc %0d attr 0x%h] req_id 0x%h",
                 func_fmttype_to_string(hdr.fmt_type),
                 func_msgcode_to_string(hdr.msg_code), hdr.fmt_type[4:0],
                 hdr.length,
                 hdr.pf_num, hdr.vf_num, hdr.vf_active,
                 hdr.TC, { hdr.attr_h, hdr.attr_l }, hdr.req_id);

   // Decode message-specific header fields
   if (hdr.msg_code == PCIE_MSGCODE_ATS_INVAL_REQ) begin
      s = $sformatf("%s dev_id 0x%h itag 0x%h", s, hdr.msg1[31:16], hdr.msg0[4:0]);
   end
   else if (hdr.msg_code == PCIE_MSGCODE_ATS_INVAL_CPL) begin
      s = $sformatf("%s dev_id 0x%h cc %0d itag_vec %b",
                    s, hdr.msg1[31:16], hdr.msg1[2:0], hdr.msg2);
   end
   else if (hdr.msg_code == PCIE_MSGCODE_PAGE_REQ) begin
      s = $sformatf("%s tag 0x%h addr 0x%0h000 gidx 0x%0h lwr 0b%b",
                    s, hdr.msg0, { hdr.msg1, hdr.msg2[31:12] },
                    hdr.msg2[11:3], hdr.msg2[2:0]);
   end
   else if (hdr.msg_code == PCIE_MSGCODE_PAGE_RSP) begin
      s = $sformatf("%s tag 0x%h dest_id 0x%h gidx 0x%0h rcode 0x%0h",
                    s, hdr.msg0, hdr.msg1[31:16], hdr.msg2[8:0], hdr.msg2[15:12]);
   end
   else begin
      s = $sformatf("%s msg0 0x%h msg1 0x%h msg2 0x%h", s, hdr.msg0, hdr.msg1, hdr.msg2);
   end

   return s;
endfunction

function automatic string func_pu_hdr_to_string (
   input PCIe_PUReqHdr_t hdr
);
   string s;
   if (func_is_mem_req(hdr.fmt_type)) begin
      s = func_pu_mem_req_to_string(hdr);
   end
   else if (func_is_completion(hdr.fmt_type)) begin
      s = func_pu_cpl_to_string(hdr);
   end
   else if (func_is_msg(hdr.fmt_type)) begin
      s = func_pu_msg_to_string(PCIe_PUMsgHdr_t'(hdr));
   end
   else begin
      s = func_pu_generic_to_string(hdr);
   end

   return s;
endfunction

function automatic string func_dm_hdr_to_string (
   input PCIe_ReqHdr_t hdr
);
   string s;
   if (func_is_mem_req(hdr.fmt_type)) begin
      s = func_dm_mem_req_to_string(hdr);
   end
   else if (func_is_completion(hdr.fmt_type)) begin
      s = func_dm_cpl_to_string(hdr);
   end
   else if (func_is_interrupt_req(hdr.fmt_type)) begin
      s = func_dm_intr_to_string(hdr);
   end
   else begin
      s = func_dm_generic_to_string(hdr);
   end

   return s;
endfunction

function automatic string func_hdr_to_string (
   input logic           is_pu_mode,
   input PCIe_PUReqHdr_t hdr
);
   return is_pu_mode ? func_pu_hdr_to_string(hdr) : func_dm_hdr_to_string(hdr);
endfunction

// Standard formatting of the contents of a channel
function automatic string func_flit_to_string (
   input logic           sop,
   input logic           eop,
   input logic           is_pu_mode,
   input PCIe_PUReqHdr_t hdr
);
   string s;

   if (sop)
   begin
      s = $sformatf("%s%s%s", (sop ? "sop " : ""), (eop ? "eop " : ""),
                    func_hdr_to_string(is_pu_mode, hdr));
   end
   else
   begin
      s = $sformatf("    %s       ", (eop ? "eop " : ""));
   end

   return s;
endfunction

// synthesis translate_on

endpackage : pcie_ss_hdr_pkg 

`endif // __PCIE_SS_HDR_PKG_SV__

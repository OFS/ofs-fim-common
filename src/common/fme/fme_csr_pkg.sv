// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// FME CSR Package.
//
// Definition of FME CSR register block structures/overlays and supporting 
// parameters/types.
//
//-----------------------------------------------------------------------------

`ifndef __FME_CSR_PKG__
`define __FME_CSR_PKG__

package fme_csr_pkg; 

import ofs_csr_pkg::*;
import ofs_fim_cfg_pkg::PORTS;

//---------------------------------------------------------
// CSR ADDRESS MAP 
//---------------------------------------------------------
// CoreFIM FME Register Addresses
//---------------------------------------------------------
localparam FME_DFH                  = 20'h0_0000;
localparam FME_AFU_ID_L             = 20'h0_0008;
localparam FME_AFU_ID_H             = 20'h0_0010;
localparam FME_NEXT_AFU             = 20'h0_0018;
localparam DUMMY_0020               = 20'h0_0020;
localparam FME_SCRATCHPAD0          = 20'h0_0028;
localparam FAB_CAPABILITY           = 20'h0_0030;
localparam PORT0_OFFSET             = 20'h0_0038;
localparam PORT1_OFFSET             = 20'h0_0040;
localparam PORT2_OFFSET             = 20'h0_0048;
localparam PORT3_OFFSET             = 20'h0_0050;
localparam FAB_STATUS               = 20'h0_0058;
localparam BITSTREAM_ID             = 20'h0_0060;
localparam BITSTREAM_MD             = 20'h0_0068;
localparam BITSTREAM_INFO           = 20'h0_0070;
localparam THERM_MNGM_DFH           = 20'h0_1000;
localparam TMP_THRESHOLD            = 20'h0_1008;
localparam TMP_RDSENSOR_FMT1        = 20'h0_1010;
localparam TMP_RDSENSOR_FMT2        = 20'h0_1018;
localparam TMP_THRESHOLD_CAPABILITY = 20'h0_1020;
localparam GLBL_PERF_DFH            = 20'h0_3000;
localparam DUMMY_3008               = 20'h0_3008;
localparam DUMMY_3010               = 20'h0_3010;
localparam DUMMY_3018               = 20'h0_3018;
localparam FPMON_FAB_CTL            = 20'h0_3020;
localparam FPMON_FAB_CTR            = 20'h0_3028;
localparam FPMON_CLK_CTR            = 20'h0_3030;
localparam GLBL_ERROR_DFH           = 20'h0_4000;
localparam FME_ERROR_MASK0          = 20'h0_4008;
localparam FME_ERROR0               = 20'h0_4010;
localparam PCIE0_ERROR_MASK         = 20'h0_4018;
localparam PCIE0_ERROR              = 20'h0_4020;
localparam DUMMY_4028               = 20'h0_4028;
localparam DUMMY_4030               = 20'h0_4030;
localparam FME_FIRST_ERROR          = 20'h0_4038;
localparam FME_NEXT_ERROR           = 20'h0_4040;
localparam RAS_NOFAT_ERROR_MASK     = 20'h0_4048;
localparam RAS_NOFAT_ERROR          = 20'h0_4050;
localparam RAS_CATFAT_ERROR_MASK    = 20'h0_4058;
localparam RAS_CATFAT_ERROR         = 20'h0_4060;
localparam RAS_ERROR_INJ            = 20'h0_4068;
localparam GLBL_ERROR_CAPABILITY    = 20'h0_4070;
//---------------------------------------------------------
// External FME Register Addresses = CoreFIM + 0x40000
//---------------------------------------------------------
localparam PCIE0_DFH              = 20'h4_0000;
localparam EMIF_DFH               = 20'h4_1000;
localparam EMIF_STAT              = 20'h4_1008;
localparam EMIF_CTRL              = 20'h4_1010;
localparam HSSI_ETH_DFH           = 20'h4_2000;
localparam HSSI_CAPABILITY        = 20'h4_2008;
localparam HSSI_RCFG_CMD_QSFP0    = 20'h4_2010;
localparam HSSI_RCFG_DATA_QSFP0   = 20'h4_2018;
localparam HSSI_CTRL_QSFP0        = 20'h4_2020;
localparam HSSI_STAT_QSFP0        = 20'h4_2028;
localparam HSSI_RCFG_CMD_QSFP1    = 20'h4_2030;
localparam HSSI_RCFG_DATA_QSFP1   = 20'h4_2038;
localparam HSSI_CTRL_QSFP1        = 20'h4_2040;
localparam HSSI_STAT_QSFP1        = 20'h4_2048;
localparam BMC_SPI_BRIDGE_DFH     = 20'h4_3000;
localparam BMC_SPI_BRIDGE_CONF    = 20'h4_3008;
localparam BMC_SPI_BRIDGE_ADDR    = 20'h4_3010;
localparam BMC_SPI_BRIDGE_READW   = 20'h4_3018;
localparam BMC_SPI_BRIDGE_WRITEW  = 20'h4_3020;

//---------------------------------------------------------
// DFH Offsets
//---------------------------------------------------------
localparam FME_CSR_NEXT_DFH_OFFSET              = 24'h001000;
localparam FME_CSR_THERM_MNGM_NEXT_DFH_OFFSET   = 24'h002000;
localparam FME_CSR_GLBL_PERF_NEXT_DFH_OFFSET    = 24'h001000;

//---------------------------------------------------------
// FME CSR Overlay Structures.
//    The following packed structures and unions create 
//    useful overlays for the inputs and outputs of the 
//    FME CSR registers.
//---------------------------------------------------------

//---------------------------------------------------------
// FME_DFH Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [3:0]  feature_type; //......[63:60]
   logic [18:0] reserved; //..........[59:41]
   logic        end_of_list; //.......[40]
   logic [23:0] next_dfh_offset; //...[39:16]
   logic [3:0]  afu_maj_version; //...[15:12]
   logic [11:0] corefim_version; //...[11:0]
} fme_csr_fme_dfh_fields_t;

typedef union packed {
   fme_csr_fme_dfh_fields_t fme_dfh;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_fme_dfh_t;

typedef struct packed {
   csr_bit_attr_t [3:0]  feature_type; //......[63:60]
   csr_bit_attr_t [18:0] reserved; //..........[59:41]
   csr_bit_attr_t        end_of_list; //.......[40]
   csr_bit_attr_t [23:0] next_dfh_offset; //...[39:16]
   csr_bit_attr_t [3:0]  afu_maj_version; //...[15:12]
   csr_bit_attr_t [11:0] corefim_version; //...[11:0]
} fme_csr_fme_dfh_fields_attr_t;

typedef union packed {
   fme_csr_fme_dfh_fields_attr_t fme_dfh;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_fme_dfh_attr_t;


//---------------------------------------------------------
// FME_AFU_ID_L Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [63:0]  afu_id_l; //......[63:0]
} fme_csr_fme_afu_id_l_fields_t;

typedef union packed {
   fme_csr_fme_afu_id_l_fields_t fme_afu_id_l;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_fme_afu_id_l_t;

typedef struct packed {
   csr_bit_attr_t [63:0]  afu_id_l; //......[63:0]
} fme_csr_fme_afu_id_l_fields_attr_t;

typedef union packed {
   fme_csr_fme_afu_id_l_fields_attr_t fme_afu_id_l;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_fme_afu_id_l_attr_t;


//---------------------------------------------------------
// FME_AFU_ID_H Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [63:0]  afu_id_h; //......[63:0]
} fme_csr_fme_afu_id_h_fields_t;

typedef union packed {
   fme_csr_fme_afu_id_h_fields_t fme_afu_id_h;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_fme_afu_id_h_t;

typedef struct packed {
   csr_bit_attr_t [63:0]  afu_id_h; //......[63:0]
} fme_csr_fme_afu_id_h_fields_attr_t;

typedef union packed {
   fme_csr_fme_afu_id_h_fields_attr_t fme_afu_id_h;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_fme_afu_id_h_attr_t;


//---------------------------------------------------------
// FME_NEXT_AFU Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [39:0] reserved; //............[63:24]
   logic [23:0] next_afu_dfh_offset; //.[23:0]
} fme_csr_fme_next_afu_fields_t;

typedef union packed {
   fme_csr_fme_next_afu_fields_t fme_next_afu;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_fme_next_afu_t;

typedef struct packed {
   csr_bit_attr_t [39:0] reserved; //............[63:24]
   csr_bit_attr_t [23:0] next_afu_dfh_offset; //.[23:0]
} fme_csr_fme_next_afu_fields_attr_t;

typedef union packed {
   fme_csr_fme_next_afu_fields_attr_t fme_next_afu;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_fme_next_afu_attr_t;


//---------------------------------------------------------
// FAB_CAPABILITY Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [33:0] reserved30; //......[63:30]
   logic [5:0]  addr_width; //......[29:24]
   logic [3:0]  reserved20; //......[23:20]
   logic [2:0]  num_ports; //.......[19:17]
   logic [3:0]  reserved13; //......[16:13]
   logic        pcie0_link; //......[12]
   logic [3:0]  reserved8; //.......[11:8]
   logic [7:0]  fabric_version; //..[ 7:0]
} fme_csr_fab_capability_fields_t;

typedef union packed {
   fme_csr_fab_capability_fields_t fab_capability;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_fab_capability_t;

typedef struct packed {
   csr_bit_attr_t [33:0] reserved30; //......[63:30]
   csr_bit_attr_t [5:0]  addr_width; //......[29:24]
   csr_bit_attr_t [3:0]  reserved20; //......[23:20]
   csr_bit_attr_t [2:0]  num_ports; //.......[19:17]
   csr_bit_attr_t [3:0]  reserved13; //......[16:13]
   csr_bit_attr_t        pcie0_link; //......[12]
   csr_bit_attr_t [3:0]  reserved8; //.......[11:8]
   csr_bit_attr_t [7:0]  fabric_version; //..[ 7:0]
} fme_csr_fab_capability_fields_attr_t;

typedef union packed {
   fme_csr_fab_capability_fields_attr_t fab_capability;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_fab_capability_attr_t;


//---------------------------------------------------------
// PORT_OFFSET Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [2:0]  reserved61; //........[63:61]
   logic        port_implemented; //..[60]
   logic [2:0]  reserved57; //........[59:57]
   logic        decouple_port_csr; //.[56]
   logic        afu_access_ctrl; //...[55]
   logic [19:0] reserved35; //........[54:35]
   logic [2:0]  bar_id; //............[34:32]
   logic [7:0]  reserved24; //........[31:24]
   logic [23:0] port_byte_offset; //..[ 7:0]
} fme_csr_port_offset_fields_t;

typedef struct packed {
   logic [PORTS-1:0] afu_access_ctrl;
   logic [PORTS-1:0] decouple_port_csr;
} fme_port_access_ctrl_t;

typedef union packed {
   fme_csr_port_offset_fields_t port_offset;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_port_offset_t;

typedef struct packed {
   csr_bit_attr_t [2:0]  reserved61; //........[63:61]
   csr_bit_attr_t        port_implemented; //..[60]
   csr_bit_attr_t [2:0]  reserved57; //........[59:57]
   csr_bit_attr_t        decouple_port_csr; //.[56]
   csr_bit_attr_t        afu_access_ctrl; //...[55]
   csr_bit_attr_t [19:0] reserved35; //........[54:35]
   csr_bit_attr_t [2:0]  bar_id; //............[34:32]
   csr_bit_attr_t [7:0]  reserved24; //........[31:24]
   csr_bit_attr_t [23:0] port_byte_offset; //..[ 7:0]
} fme_csr_port_offset_fields_attr_t;

typedef union packed {
   fme_csr_port_offset_fields_attr_t port_offset;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_port_offset_attr_t;


//---------------------------------------------------------
// FAB_STATUS Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [54:0] reserved9; //.........[63:9]
   logic        pcie0_link_status; //.[ 8]
   logic [7:0]  reserved0; //.........[ 7:0]
} fme_csr_fab_status_fields_t;

typedef union packed {
   fme_csr_fab_status_fields_t fab_status;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_fab_status_t;

typedef struct packed {
   csr_bit_attr_t [54:0] reserved9; //.........[63:9]
   csr_bit_attr_t        pcie0_link_status; //.[ 8]
   csr_bit_attr_t [7:0]  reserved0; //.........[ 7:0]
} fme_csr_fab_status_fields_attr_t;

typedef union packed {
   fme_csr_fab_status_fields_attr_t fab_status;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_fab_status_attr_t;


//---------------------------------------------------------
// BITSTREAM_ID Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [3:0]  ver_major; //.........[63:60]
   logic [3:0]  ver_minor; //.........[59:56]
   logic [3:0]  ver_patch; //.........[55:52]
   logic [3:0]  ver_debug; //.........[51:48]
   logic [7:0]  fim_variant; //.......[47:40]
   logic [3:0]  reserved36; //........[39:36]
   logic [3:0]  hssi_id; //...........[35:32]
   logic [31:0] git_hash; //..........[31:0]
} fme_csr_bitstream_id_fields_t;

typedef union packed {
   fme_csr_bitstream_id_fields_t bitstream_id;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_bitstream_id_t;

typedef struct packed {
   csr_bit_attr_t [3:0]  ver_major; //.........[63:60]
   csr_bit_attr_t [3:0]  ver_minor; //.........[59:56]
   csr_bit_attr_t [3:0]  ver_patch; //.........[55:52]
   csr_bit_attr_t [3:0]  ver_debug; //.........[51:48]
   csr_bit_attr_t [7:0]  fim_variant; //.......[47:40]
   csr_bit_attr_t [3:0]  reserved36; //........[39:36]
   csr_bit_attr_t [3:0]  hssi_id; //...........[35:32]
   csr_bit_attr_t [31:0] git_hash; //..........[31:0]
} fme_csr_bitstream_id_fields_attr_t;

typedef union packed {
   fme_csr_bitstream_id_fields_attr_t bitstream_id;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_bitstream_id_attr_t;


//---------------------------------------------------------
// BITSTREAM_MD Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [35:0] reserved28; //........[63:28]
   logic [7:0]  synth_year; //........[27:20]
   logic [7:0]  synth_month; //.......[19:12]
   logic [7:0]  synth_day; //.........[11:4] 
   logic [3:0]  synth_seed; //........[ 3:0]
} fme_csr_bitstream_md_fields_t;

typedef union packed {
   fme_csr_bitstream_md_fields_t bitstream_md;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_bitstream_md_t;

typedef struct packed {
   csr_bit_attr_t [35:0] reserved28; //........[63:28]
   csr_bit_attr_t [7:0]  synth_year; //........[27:20]
   csr_bit_attr_t [7:0]  synth_month; //.......[19:12]
   csr_bit_attr_t [7:0]  synth_day; //.........[11:4] 
   csr_bit_attr_t [3:0]  synth_seed; //........[ 3:0]
} fme_csr_bitstream_md_fields_attr_t;

typedef union packed {
   fme_csr_bitstream_md_fields_attr_t bitstream_md;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_bitstream_md_attr_t;


//---------------------------------------------------------
// BITSTREAM_INFO Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [31:0] reserved32; //..............[63:32]
   logic [31:0] fim_variant_revision; //....[31:0]
} fme_csr_bitstream_info_fields_t;

typedef union packed {
   fme_csr_bitstream_info_fields_t bitstream_info;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_bitstream_info_t;

typedef struct packed {
   csr_bit_attr_t [31:0] reserved32; //..............[63:32]
   csr_bit_attr_t [31:0] fim_variant_revision; //....[27:20]
} fme_csr_bitstream_info_fields_attr_t;

typedef union packed {
   fme_csr_bitstream_info_fields_attr_t bitstream_info;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_bitstream_info_attr_t;


//---------------------------------------------------------
// Standard Feature DFH Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [3:0]  feature_type; //.......[63:60]
   logic [18:0] reserved; //...........[59:41]
   logic        end_of_list; //........[40]
   logic [23:0] next_dfh_offset; //....[39:16]
   logic [3:0]  feature_rev; //........[15:12]
   logic [11:0] feature_id; //.........[11:0] 
} fme_csr_dfh_fields_t;

typedef union packed {
   fme_csr_dfh_fields_t dfh;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_dfh_t;

typedef struct packed {
   csr_bit_attr_t [3:0]  feature_type; //.......[63:60]
   csr_bit_attr_t [18:0] reserved; //...........[59:41]
   csr_bit_attr_t        end_of_list; //........[40]
   csr_bit_attr_t [23:0] next_dfh_offset; //....[39:16]
   csr_bit_attr_t [3:0]  feature_rev; //........[15:12]
   csr_bit_attr_t [11:0] feature_id; //..........[11:0] 
} fme_csr_dfh_fields_attr_t;

typedef union packed {
   fme_csr_dfh_fields_attr_t dfh;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_dfh_attr_t;


//---------------------------------------------------------
// TMP_THRESHOLD Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [18:0] reserved45; //..............[63:45]
   logic        threshold_policy; //........[44]
   logic [1:0]  reserved42; //..............[43:42]
   logic        val_mode_therm; //..........[41]
   logic [4:0]  reserved36; //..............[40:36]
   logic        therm_trip_status; //.......[35]
   logic        reserved34; //..............[34]
   logic        threshold2_status; //.......[33]
   logic        threshold1_status; //.......[32]
   logic        reserved31; //..............[31]
   logic [6:0]  therm_trip_threshold; //....[30:24] 
   logic [7:0]  reserved16; //..............[23:16] 
   logic        temp_threshold2_enable; //..[15]
   logic [6:0]  temp_threshold2; //.........[14:8]
   logic        temp_threshold1_enable; //..[ 7]
   logic [6:0]  temp_threshold1; //.........[ 6:0]
} fme_csr_tmp_threshold_fields_t;

typedef union packed {
   fme_csr_tmp_threshold_fields_t tmp_threshold;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_tmp_threshold_t;

typedef struct packed {
   csr_bit_attr_t [18:0] reserved45; //..............[63:45]
   csr_bit_attr_t        threshold_policy; //........[44]
   csr_bit_attr_t [1:0]  reserved42; //..............[43:42]
   csr_bit_attr_t        val_mode_therm; //..........[41]
   csr_bit_attr_t [4:0]  reserved36; //..............[40:36]
   csr_bit_attr_t        therm_trip_status; //.......[35]
   csr_bit_attr_t        reserved34; //..............[34]
   csr_bit_attr_t        threshold2_status; //.......[33]
   csr_bit_attr_t        threshold1_status; //.......[32]
   csr_bit_attr_t        reserved31; //..............[31]
   csr_bit_attr_t [6:0]  therm_trip_threshold; //....[30:24] 
   csr_bit_attr_t [7:0]  reserved16; //..............[23:16] 
   csr_bit_attr_t        temp_threshold2_enable; //..[15]
   csr_bit_attr_t [6:0]  temp_threshold2; //.........[14:8]
   csr_bit_attr_t        temp_threshold1_enable; //..[ 7]
   csr_bit_attr_t [6:0]  temp_threshold1; //.........[ 6:0]
} fme_csr_tmp_threshold_fields_attr_t;

typedef union packed {
   fme_csr_tmp_threshold_fields_attr_t tmp_threshold;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_tmp_threshold_attr_t;


//---------------------------------------------------------
// TMP_RDSENSOR_FMT1 Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [21:0] reserved42; //...........[63:42]
   logic [9:0]  temp_thermal_sensor; //..[41:32]
   logic [6:0]  reserved25; //...........[31:25]
   logic        temp_valid; //...........[24]
   logic [15:0] numb_temp_reads; //......[23:8]
   logic        reserved7; //............[ 7]
   logic [6:0]  fpga_temp; //............[ 6:0]
} fme_csr_tmp_rdsensor_fmt1_fields_t;

typedef union packed {
   fme_csr_tmp_rdsensor_fmt1_fields_t tmp_rdsensor_fmt1;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_tmp_rdsensor_fmt1_t;

typedef struct packed {
   csr_bit_attr_t [21:0] reserved42; //...........[63:42]
   csr_bit_attr_t [9:0]  temp_thermal_sensor; //..[41:32]
   csr_bit_attr_t [6:0]  reserved25; //...........[31:25]
   csr_bit_attr_t        temp_valid; //...........[24]
   csr_bit_attr_t [15:0] numb_temp_reads; //......[23:8]
   csr_bit_attr_t        reserved7; //............[ 7]
   csr_bit_attr_t [6:0]  fpga_temp; //............[ 6:0]
} fme_csr_tmp_rdsensor_fmt1_fields_attr_t;

typedef union packed {
   fme_csr_tmp_rdsensor_fmt1_fields_attr_t tmp_rdsensor_fmt1;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_tmp_rdsensor_fmt1_attr_t;


//---------------------------------------------------------
// TMP_THRESHOLD_CAPABILITY Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [62:0] reserved; //...................[63:1]
   logic        disable_tmp_thresh_report; //..[ 0]
} fme_csr_tmp_threshold_capability_fields_t;

typedef union packed {
   fme_csr_tmp_threshold_capability_fields_t tmp_threshold_capability;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_tmp_threshold_capability_t;

typedef struct packed {
   csr_bit_attr_t [62:0] reserved; //...................[63:1]
   csr_bit_attr_t        disable_tmp_thresh_report; //..[ 0]
} fme_csr_tmp_threshold_capability_fields_attr_t;

typedef union packed {
   fme_csr_tmp_threshold_capability_fields_attr_t tmp_threshold_capability;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_tmp_threshold_capability_attr_t;


//---------------------------------------------------------
// FPMON_FAB_CTL Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [39:0] reserved24; //...........[63:24]
   logic        port_filter; //..........[23]
   logic        reserved22; //...........[22]
   logic [1:0]  port_id; //..............[21:20]
   logic [3:0]  fabric_event_code; //....[19:16]
   logic [6:0]  reserved9; //............[15:9]
   logic        freeze_counters; //......[ 8]
   logic [7:0]  reserved0; //............[ 7:0]
} fme_csr_fpmon_fab_ctl_fields_t;

typedef union packed {
   fme_csr_fpmon_fab_ctl_fields_t fpmon_fab_ctl;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_fpmon_fab_ctl_t;

typedef struct packed {
   csr_bit_attr_t [39:0] reserved24; //...........[63:24]
   csr_bit_attr_t        port_filter; //..........[23]
   csr_bit_attr_t        reserved22; //...........[22]
   csr_bit_attr_t [1:0]  port_id; //..............[21:20]
   csr_bit_attr_t [3:0]  fabric_event_code; //....[19:16]
   csr_bit_attr_t [6:0]  reserved9; //............[15:9]
   csr_bit_attr_t        freeze_counters; //......[ 8]
   csr_bit_attr_t [7:0]  reserved0; //............[ 7:0]
} fme_csr_fpmon_fab_ctl_fields_attr_t;

typedef union packed {
   fme_csr_fpmon_fab_ctl_fields_attr_t fpmon_fab_ctl;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_fpmon_fab_ctl_attr_t;


//---------------------------------------------------------
// FPMON_FAB_CTR Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [3:0]  fabric_event_code; //......[63:60]
   logic [59:0] fabric_event_counter; //...[59:0]
} fme_csr_fpmon_fab_ctr_fields_t;

typedef union packed {
   fme_csr_fpmon_fab_ctr_fields_t fpmon_fab_ctr;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_fpmon_fab_ctr_t;

typedef struct packed {
   csr_bit_attr_t [3:0]  fabric_event_code; //......[63:60]
   csr_bit_attr_t [59:0] fabric_event_counter; //...[59:0]
} fme_csr_fpmon_fab_ctr_fields_attr_t;

typedef union packed {
   fme_csr_fpmon_fab_ctr_fields_attr_t fpmon_fab_ctr;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_fpmon_fab_ctr_attr_t;


//---------------------------------------------------------
// FPMON_CLK_CTR Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [63:0] clock_counter; //...[63:0]
} fme_csr_fpmon_clk_ctr_fields_t;

typedef union packed {
   fme_csr_fpmon_clk_ctr_fields_t fpmon_clk_ctr;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_fpmon_clk_ctr_t;

typedef struct packed {
   csr_bit_attr_t [63:0] clock_counter; //...[63:0]
} fme_csr_fpmon_clk_ctr_fields_attr_t;

typedef union packed {
   fme_csr_fpmon_clk_ctr_fields_attr_t fpmon_clk_ctr;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_fpmon_clk_ctr_attr_t;


//---------------------------------------------------------
// FME_ERROR_MASK0 Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [62:0] reserved1; //.....[63:1]
   logic        error_mask0; //...[0]
} fme_csr_fme_error_mask0_fields_t;

typedef union packed {
   fme_csr_fme_error_mask0_fields_t fme_error_mask0;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_fme_error_mask0_t;

typedef struct packed {
   csr_bit_attr_t [62:0] reserved1; //.....[63:1]
   csr_bit_attr_t        error_mask0; //...[0]
} fme_csr_fme_error_mask0_fields_attr_t;

typedef union packed {
   fme_csr_fme_error_mask0_fields_attr_t fme_error_mask0;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_fme_error_mask0_attr_t;


//---------------------------------------------------------
// FME_ERROR0 Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [62:0] reserved1; //............................[63:1]
   logic        partial_reconfig_fifo_parity_error; //...[0]
} fme_csr_fme_error0_fields_t;

typedef union packed {
   fme_csr_fme_error0_fields_t fme_error0;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_fme_error0_t;

typedef struct packed {
   csr_bit_attr_t [62:0] reserved1; //............................[63:1]
   csr_bit_attr_t        partial_reconfig_fifo_parity_error; //...[0]
} fme_csr_fme_error0_fields_attr_t;

typedef union packed {
   fme_csr_fme_error0_fields_attr_t fme_error0;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_fme_error0_attr_t;


//---------------------------------------------------------
// PCIE0_ERROR_MASK Register Overlay. 
// NOTE: This register is now implemented in the PCIe CSR
// register bank.  This register is kept inert for backwards
// compatibility.
//---------------------------------------------------------
typedef struct packed {
   logic [63:0] reserved; //.....[63:0]
} fme_csr_pcie0_error_mask_fields_t;

typedef union packed {
   fme_csr_pcie0_error_mask_fields_t pcie0_error_mask;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_pcie0_error_mask_t;

typedef struct packed {
   csr_bit_attr_t [63:0] reserved; //.....[63:0]
} fme_csr_pcie0_error_mask_fields_attr_t;

typedef union packed {
   fme_csr_pcie0_error_mask_fields_attr_t pcie0_error_mask;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_pcie0_error_mask_attr_t;


//---------------------------------------------------------
// PCIE0_ERROR Register Overlay. 
// NOTE: This register is now implemented in the PCIe CSR
// register bank.  This register is kept inert for backwards
// compatibility.
//---------------------------------------------------------
typedef struct packed {
   logic [63:0] reserved; //...............[63:0]
} fme_csr_pcie0_error_fields_t;

typedef union packed {
   fme_csr_pcie0_error_fields_t pcie0_error;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_pcie0_error_t;

typedef struct packed {
   csr_bit_attr_t [63:0] reserved; //...............[63:0]
} fme_csr_pcie0_error_fields_attr_t;

typedef union packed {
   fme_csr_pcie0_error_fields_attr_t pcie0_error;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_pcie0_error_attr_t;


//---------------------------------------------------------
// FME_FIRST_ERROR & FME_NEXT_ERROR Register Overlay.
//---------------------------------------------------------
typedef struct packed {
   logic [1:0]  reserved; //.....////..[63:62]
   logic [1:0]  error_reg_id; //.......[61:60]
   logic [59:0] error_reg_status; //...[59:0]
} fme_csr_fme_first_next_error_fields_t;

typedef union packed {
   fme_csr_fme_first_next_error_fields_t fme_first_next_error;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_fme_first_next_error_t;

typedef struct packed {
   csr_bit_attr_t [1:0]  reserved; //.....////..[63:62]
   csr_bit_attr_t [1:0]  error_reg_id; //.......[61:60]
   csr_bit_attr_t [59:0] error_reg_status; //...[59:0]
} fme_csr_fme_first_next_error_fields_attr_t;

typedef union packed {
   fme_csr_fme_first_next_error_fields_attr_t fme_first_next_error;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_fme_first_next_error_attr_t;


//---------------------------------------------------------
// RAS_NOFAT_ERROR_MASK Register Overlay. 
//---------------------------------------------------------
typedef struct packed {
   logic [56:0] reserved7; //.....[63:7]
   logic [1:0]  error_mask5; //...[ 6:5]
   logic        reserved4; // ....[ 4]
   logic [1:0]  error_mask2; //...[ 3:2]
   logic [1:0]  reserved0; //.....[ 1:0]
} fme_csr_ras_nofat_error_mask_fields_t;

typedef union packed {
   fme_csr_ras_nofat_error_mask_fields_t ras_nofat_error_mask;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_ras_nofat_error_mask_t;

typedef struct packed {
   csr_bit_attr_t [56:0] reserved7; //.....[63:7]
   csr_bit_attr_t [1:0]  error_mask5; //...[ 6:5]
   csr_bit_attr_t        reserved4; // ....[ 4]
   csr_bit_attr_t [1:0]  error_mask2; //...[ 3:2]
   csr_bit_attr_t [1:0]  reserved0; //.....[ 1:0]
} fme_csr_ras_nofat_error_mask_fields_attr_t;

typedef union packed {
   fme_csr_ras_nofat_error_mask_fields_attr_t ras_nofat_error_mask;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_ras_nofat_error_mask_attr_t;


//---------------------------------------------------------
// RAS_NOFAT_ERROR Register Overlay. 
//---------------------------------------------------------
typedef struct packed {
   logic [56:0] reserved7; //..............[63:7]
   logic        injected_warning_error; //.[ 6]
   logic        afu_access_mode_error; //..[ 5]
   logic        reserved4; //..............[ 4]
   logic        port_fatal_error; //.......[ 3]
   logic        pcie_error; //.............[ 2]
   logic [1:0]  reserved0; //..............[ 1:0]
} fme_csr_ras_nofat_error_fields_t;

typedef union packed {
   fme_csr_ras_nofat_error_fields_t ras_nofat_error;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_ras_nofat_error_t;

typedef struct packed {
   csr_bit_attr_t [56:0] reserved7; //..............[63:7]
   csr_bit_attr_t        injected_warning_error; //.[ 6]
   csr_bit_attr_t        afu_access_mode_error; //..[ 5]
   csr_bit_attr_t        reserved4; //..............[ 4]
   csr_bit_attr_t        port_fatal_error; //.......[ 3]
   csr_bit_attr_t        pcie_error; //.............[ 2]
   csr_bit_attr_t [1:0]  reserved0; //..............[ 1:0]
} fme_csr_ras_nofat_error_fields_attr_t;

typedef union packed {
   fme_csr_ras_nofat_error_fields_attr_t ras_nofat_error;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_ras_nofat_error_attr_t;


//---------------------------------------------------------
// RAS_CATFAT_ERROR_MASK Register Overlay. 
//---------------------------------------------------------
typedef struct packed {
   logic [51:0] reserved12; //.....[63:12]
   logic        error_mask11; //...[11]
   logic        reserved10; //.....[10]
   logic [3:0]  error_mask6; //....[ 9:6]
   logic [5:0]  reserved0; //......[ 5:0]
} fme_csr_ras_catfat_error_mask_fields_t;

typedef union packed {
   fme_csr_ras_catfat_error_mask_fields_t ras_catfat_error_mask;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_ras_catfat_error_mask_t;

typedef struct packed {
   csr_bit_attr_t [51:0] reserved12; //.....[63:12]
   csr_bit_attr_t        error_mask11; //...[11]
   csr_bit_attr_t        reserved10; //.....[10]
   csr_bit_attr_t [3:0]  error_mask6; //....[ 9:6]
   csr_bit_attr_t [5:0]  reserved0; //......[ 5:0]
} fme_csr_ras_catfat_error_mask_fields_attr_t;

typedef union packed {
   fme_csr_ras_catfat_error_mask_fields_attr_t ras_catfat_error_mask;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_ras_catfat_error_mask_attr_t;


//---------------------------------------------------------
// RAS_CATFAT_ERROR Register Overlay. 
//---------------------------------------------------------
typedef struct packed {
   logic [51:0] reserved12; //..............[63:12]
   logic        injected_catast_error; //...[11]
   logic        reserved10; //..............[10]
   logic        crc_catast_error; //........[ 9]
   logic        injected_fatal_error; //....[ 8]
   logic        pcie_poison_error; //.......[ 7]
   logic        fabric_fatal_error; //......[ 6]
   logic [5:0]  reserved0; //...............[ 5:0]
} fme_csr_ras_catfat_error_fields_t;

typedef union packed {
   fme_csr_ras_catfat_error_fields_t ras_catfat_error;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_ras_catfat_error_t;

typedef struct packed {
   csr_bit_attr_t [51:0] reserved12; //..............[63:12]
   csr_bit_attr_t        injected_catast_error; //...[11]
   csr_bit_attr_t        reserved10; //..............[10]
   csr_bit_attr_t        crc_catast_error; //........[ 9]
   csr_bit_attr_t        injected_fatal_error; //....[ 8]
   csr_bit_attr_t        pcie_poison_error; //.......[ 7]
   csr_bit_attr_t        fabric_fatal_error; //......[ 6]
   csr_bit_attr_t [5:0]  reserved0; //...............[ 5:0]
} fme_csr_ras_catfat_error_fields_attr_t;

typedef union packed {
   fme_csr_ras_catfat_error_fields_attr_t ras_catfat_error;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_ras_catfat_error_attr_t;


//---------------------------------------------------------
// RAS_ERROR_INJ Register Overlay. 
//---------------------------------------------------------
typedef struct packed {
   logic [60:0] reserved3; //.......[63:3]
   logic        nofatal_error; //...[ 2]
   logic        fatal_error; //.....[ 1]
   logic        catast_error; //....[ 0]
} fme_csr_ras_error_inj_fields_t;

typedef union packed {
   fme_csr_ras_error_inj_fields_t ras_error_inj;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_ras_error_inj_t;

typedef struct packed {
   csr_bit_attr_t [60:0] reserved3; //.......[63:3]
   csr_bit_attr_t        nofatal_error; //...[ 2]
   csr_bit_attr_t        fatal_error; //.....[ 1]
   csr_bit_attr_t        catast_error; //....[ 0]
} fme_csr_ras_error_inj_fields_attr_t;

typedef union packed {
   fme_csr_ras_error_inj_fields_attr_t ras_error_inj;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_ras_error_inj_attr_t;


//---------------------------------------------------------
// GLBL_ERROR_CAPABILITY Register Overlay. 
//---------------------------------------------------------
typedef struct packed {
   logic [50:0] reserved13; //................[63:13]
   logic [11:0] interrupt_vector_number; //...[12:1]
   logic        supports_interrupt; //........[0]
} fme_csr_glbl_error_capability_fields_t;

typedef union packed {
   fme_csr_glbl_error_capability_fields_t glbl_error_capability;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_glbl_error_capability_t;

typedef struct packed {
   csr_bit_attr_t [50:0] reserved13; //................[63:13]
   csr_bit_attr_t [11:0] interrupt_vector_number; //...[12:1]
   csr_bit_attr_t        supports_interrupt; //........[0]
} fme_csr_glbl_error_capability_fields_attr_t;

typedef union packed {
   fme_csr_glbl_error_capability_fields_attr_t glbl_error_capability;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_glbl_error_capability_attr_t;


//---------------------------------------------------------
// FME_PR_CTRL Register Overlay. 
//---------------------------------------------------------
typedef struct packed {
   logic [31:0] config_data; //.............[63:32]
   logic [16:0] reserved15; //..............[31:15]
   logic        pr_kind; //.................[14]
   logic        pr_data_push_complete; //...[13]
   logic        pr_start_request; //........[12]
   logic [1:0]  reserved10; //..............[11:10]
   logic [1:0]  pr_region_id; //............[ 9:8]
   logic [2:0]  reserved5; //...............[ 7:5]
   logic        pr_reset_ack; //............[ 4]
   logic [2:0]  reserved1; //...............[ 3:1]
   logic        pr_reset; //................[ 0]
} fme_csr_fme_pr_ctrl_fields_t;

typedef union packed {
   fme_csr_fme_pr_ctrl_fields_t fme_pr_ctrl;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_fme_pr_ctrl_t;

typedef struct packed {
   csr_bit_attr_t [31:0] config_data; //.............[63:32]
   csr_bit_attr_t [16:0] reserved15; //..............[31:15]
   csr_bit_attr_t        pr_kind; //.................[14]
   csr_bit_attr_t        pr_data_push_complete; //...[13]
   csr_bit_attr_t        pr_start_request; //........[12]
   csr_bit_attr_t [1:0]  reserved10; //..............[11:10]
   csr_bit_attr_t [1:0]  pr_region_id; //............[ 9:8]
   csr_bit_attr_t [2:0]  reserved5; //...............[ 7:5]
   csr_bit_attr_t        pr_reset_ack; //............[ 4]
   csr_bit_attr_t [2:0]  reserved1; //...............[ 3:1]
   csr_bit_attr_t        pr_reset; //................[ 0]
} fme_csr_fme_pr_ctrl_fields_attr_t;

typedef union packed {
   fme_csr_fme_pr_ctrl_fields_attr_t fme_pr_ctrl;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_fme_pr_ctrl_attr_t;


//---------------------------------------------------------
// FME_PR_STATUS Register Overlay. 
//---------------------------------------------------------
typedef struct packed {
   logic [31:0] security_block_status; //...[63:32]
   logic [3:0]  reserved28; //..............[31:28]
   logic [3:0]  pr_host_status; //..........[27:24]
   logic        reserved23; //..............[23]
   logic [2:0]  altera_pr_ctrl_status; //...[22:20]
   logic [2:0]  reserved17; //..............[19:17]
   logic        pr_status; //...............[16]
   logic [6:0]  reserved9; //...............[15:9]
   logic [8:0]  numb_credits; //............[ 8:0]
} fme_csr_fme_pr_status_fields_t;

typedef union packed {
   fme_csr_fme_pr_status_fields_t fme_pr_status;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_fme_pr_status_t;

typedef struct packed {
   csr_bit_attr_t [31:0] security_block_status; //...[63:32]
   csr_bit_attr_t [3:0]  reserved28; //..............[31:28]
   csr_bit_attr_t [3:0]  pr_host_status; //..........[27:24]
   csr_bit_attr_t        reserved23; //..............[23]
   csr_bit_attr_t [2:0]  altera_pr_ctrl_status; //...[22:20]
   csr_bit_attr_t [2:0]  reserved17; //..............[19:17]
   csr_bit_attr_t        pr_status; //...............[16]
   csr_bit_attr_t [6:0]  reserved9; //...............[15:9]
   csr_bit_attr_t [8:0]  numb_credits; //............[ 8:0]
} fme_csr_fme_pr_status_fields_attr_t;

typedef union packed {
   fme_csr_fme_pr_status_fields_attr_t fme_pr_status;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_fme_pr_status_attr_t;


//---------------------------------------------------------
// FME_PR_ERROR Register Overlay. 
//---------------------------------------------------------
typedef struct packed {
   logic [56:0] reserved7; //........................[63:7]
   logic        secure_load_failed; //...............[ 6]
   logic        host_init_timeout; //................[ 5]
   logic        host_init_fifo_overflow; //..........[ 4]
   logic        ip_init_protocol_error; //...........[ 3]
   logic        ip_init_incompatible_bitstream; //...[ 2]
   logic        ip_init_crc_error; //................[ 1]
   logic        host_init_operation_error; //........[ 0]
} fme_csr_fme_pr_error_fields_t;

typedef union packed {
   fme_csr_fme_pr_error_fields_t fme_pr_error;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_fme_pr_error_t;

typedef struct packed {
   csr_bit_attr_t [56:0] reserved7; //........................[63:7]
   csr_bit_attr_t        secure_load_failed; //...............[ 6]
   csr_bit_attr_t        host_init_timeout; //................[ 5]
   csr_bit_attr_t        host_init_fifo_overflow; //..........[ 4]
   csr_bit_attr_t        ip_init_protocol_error; //...........[ 3]
   csr_bit_attr_t        ip_init_incompatible_bitstream; //...[ 2]
   csr_bit_attr_t        ip_init_crc_error; //................[ 1]
   csr_bit_attr_t        host_init_operation_error; //........[ 0]
} fme_csr_fme_pr_error_fields_attr_t;

typedef union packed {
   fme_csr_fme_pr_error_fields_attr_t fme_pr_error;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_fme_pr_error_attr_t;


//---------------------------------------------------------
// MSIX_ADDR Register Overlay. 
//---------------------------------------------------------
typedef struct packed {
   logic [31:0] msg_addr_upp; //...[63:32]
   logic [31:0] msg_addr_low; //...[31:0]
} fme_csr_msix_addr_fields_t;

typedef union packed {
   fme_csr_msix_addr_fields_t msix_addr;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_msix_addr_t;

typedef struct packed {
   csr_bit_attr_t [31:0] msg_addr_upp; //...[63:32]
   csr_bit_attr_t [31:0] msg_addr_low; //...[31:0]
} fme_csr_msix_addr_fields_attr_t;

typedef union packed {
   fme_csr_msix_addr_fields_attr_t msix_addr;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_msix_addr_attr_t;


//---------------------------------------------------------
// MSIX_CTLDAT Register Overlay. 
//---------------------------------------------------------
typedef struct packed {
   logic [31:0] msg_control; //...[63:32]
   logic [31:0] msg_data; //......[31:0]
} fme_csr_msix_ctldat_fields_t;

typedef union packed {
   fme_csr_msix_ctldat_fields_t msix_ctldat;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_msix_ctldat_t;

typedef struct packed {
   csr_bit_attr_t [31:0] msg_control; //...[63:32]
   csr_bit_attr_t [31:0] msg_data; //......[31:0]
} fme_csr_msix_ctldat_fields_attr_t;

typedef union packed {
   fme_csr_msix_ctldat_fields_attr_t msix_ctldat;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_msix_ctldat_attr_t;


//---------------------------------------------------------
// MSIX_PBA Register Overlay. 
//---------------------------------------------------------
typedef struct packed {
   logic [56:0] reserved7; //.....[63:7]
   logic [6:0]  msix_pba; //......[ 6:0]
} fme_csr_msix_pba_fields_t;

typedef union packed {
   fme_csr_msix_pba_fields_t msix_pba;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_msix_pba_t;

typedef struct packed {
   csr_bit_attr_t [56:0] reserved7; //.....[63:7]
   csr_bit_attr_t [6:0]  msix_pba; //......[ 6:0]
} fme_csr_msix_pba_fields_attr_t;

typedef union packed {
   fme_csr_msix_pba_fields_attr_t msix_pba;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_msix_pba_attr_t;


//---------------------------------------------------------
// MSIX_COUNT_CSR Register Overlay. 
//---------------------------------------------------------
typedef struct packed {
   logic [31:0] reserved32; //...................[63:32]
   logic [7:0]  afu_2_sync_fifo_msix_count; //...[31:24]
   logic [7:0]  sync_fifo_2_msix_count; //.......[23:16]
   logic [7:0]  msix_2_cdc_msix_count; //........[15:8]
   logic [7:0]  cdc_2_avl_msix_count; //.........[ 7:0]
} fme_csr_msix_count_csr_fields_t;

typedef union packed {
   fme_csr_msix_count_csr_fields_t msix_count_csr;
   logic [63:0] data;
   ofs_csr_reg_2x32_t word;
} fme_csr_msix_count_csr_t;

typedef struct packed {
   csr_bit_attr_t [31:0] reserved32; //...................[63:32]
   csr_bit_attr_t [7:0]  afu_2_sync_fifo_msix_count; //...[31:24]
   csr_bit_attr_t [7:0]  sync_fifo_2_msix_count; //.......[23:16]
   csr_bit_attr_t [7:0]  msix_2_cdc_msix_count; //........[15:8]
   csr_bit_attr_t [7:0]  cdc_2_avl_msix_count; //.........[15:8]
} fme_csr_msix_count_csr_fields_attr_t;

typedef union packed {
   fme_csr_msix_count_csr_fields_attr_t msix_count_csr;
   csr_bit_attr_t [63:0] data;
   ofs_csr_reg_2x32_attr_t word;
} fme_csr_msix_count_csr_attr_t;


endpackage: fme_csr_pkg

`endif // __FME_CSR_PKG__

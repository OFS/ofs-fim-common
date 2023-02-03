// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// FME CSR
//
// This module contains the FPGA Management Engine (FME) control and status 
// registers and supporting logic.
//
//-----------------------------------------------------------------------------
/*
import ofs_fim_cfg_pkg::*;
import ofs_fim_if_pkg::*;
import ofs_csr_pkg::*;
import fme_csr_pkg::*;*/

module fme_csr #(
   parameter END_OF_LIST        = 1'b0,
   parameter NEXT_DFH_OFFSET    = ( 24'h01_2000 )
)(
   // PowerGoodN Reset Signal -------------------------------------- 
   ofs_fim_pwrgoodn_if.slave pgn, // Implemented as SV Interface for Simulation Simplification.
   // AXI Slave Bus to CSR Registers -------------------------------
   ofs_fim_axi_mmio_if.slave axi,
   // FME I/O Bus status sources and control destinations ----------
   fme_csr_io_if.fme fme_io
);
import ofs_fim_cfg_pkg::*;
import ofs_fim_if_pkg::*;
import ofs_csr_pkg::*;
import fme_csr_pkg::*;

//----------------------------------------------------------------------------
// Local parameters.
//----------------------------------------------------------------------------
localparam   CSR_FEATURE_NUM = 5;      // Up to five features on 256K boundary.
localparam   CSR_FEATURE_REG_NUM = 15;  // Up to fifteen registers allowed per feature.  Current max is 15 used by FME DFH.


//---------------------------------------------------------------------------------
// Here is a list of the register bit attributes for each of the CSRs.  The effect
// these attributes have on the individual register bits is defined in the 
// function "update_reg" in package "ofs_csr_pkg.sv".
//
// The attributes and their effects are listed here for reference:
//
//     typedef enum logic [3:0] {
//        RO    = 4'h0, // Read-Only
//        RW    = 4'h1, // Read-Write
//        RWS   = 4'h2, // Read-Write Sticky Across Soft Reset
//        RWD   = 4'h3, // Read-Write Sticky Across Hard Reset
//        RW1C  = 4'h4, // Read-Write 1 to Clear
//        RW1CS = 4'h5, // Read-Write 1 to Clear Sticky Across Soft Reset
//        RW1CD = 4'h6, // Read-Write 1 to Clear Sticky Across Hard Reset
//        RW1S  = 4'h7, // Read-Write 1 to Set
//        RW1SS = 4'h8, // Read-Write 1 to Set Sticky Across Soft Reset
//        RW1SD = 4'h9, // Read-Write 1 to Set Sticky Across Hard Reset
//        Rsvd  = 4'hA, // Reserved - Don't Care
//        RsvdP = 4'hB, // Reserved and Protected (SW read-modify-write)
//        RsvdZ = 4'hC   // Reserved and Zero
//     } csr_bit_attr_t;
// 
//---------------------------------------------------------------------------------

// FME DFH Register Bit Attributes ------------------------------------------------
fme_csr_fme_dfh_attr_t fme_dfh_attr;
assign fme_dfh_attr.fme_dfh.feature_type    = {4{RO}};
assign fme_dfh_attr.fme_dfh.reserved        = {19{RsvdZ}};
assign fme_dfh_attr.fme_dfh.end_of_list     = RO;
assign fme_dfh_attr.fme_dfh.next_dfh_offset = {24{RO}};
assign fme_dfh_attr.fme_dfh.afu_maj_version = {4{RO}};
assign fme_dfh_attr.fme_dfh.corefim_version = {12{RO}};
// FME AFU ID Register Bit Attributes ---------------------------------------------
fme_csr_fme_afu_id_l_attr_t fme_afu_id_l_attr;
assign fme_afu_id_l_attr.data = {64{RO}};
fme_csr_fme_afu_id_h_attr_t fme_afu_id_h_attr;
assign fme_afu_id_h_attr.data = {64{RO}};
// FME Next AFU Register Bit Attributes -------------------------------------------
fme_csr_fme_next_afu_attr_t fme_next_afu_attr;
assign fme_next_afu_attr.fme_next_afu.reserved            = {40{RsvdZ}};
assign fme_next_afu_attr.fme_next_afu.next_afu_dfh_offset = {24{RO}};
// Dummy Register Bit Attributes --------------------------------------------------
ofs_csr_reg_generic_attr_t dummy_0020_attr;
assign dummy_0020_attr.data = {64{RO}};
// FME Scratchpad Register Bit Attributes -----------------------------------------
ofs_csr_reg_generic_attr_t fme_scratchpad0_attr;
assign fme_scratchpad0_attr.data = {64{RW}};
// Fabric Capability Register Bit Attributes --------------------------------------
fme_csr_fab_capability_attr_t fab_capability_attr;
assign fab_capability_attr.fab_capability.reserved30     = {34{RsvdZ}};
assign fab_capability_attr.fab_capability.addr_width     = {6{RO}};
assign fab_capability_attr.fab_capability.reserved20     = {4{RsvdZ}};
assign fab_capability_attr.fab_capability.num_ports      = {3{RO}};
assign fab_capability_attr.fab_capability.reserved13     = {4{RsvdZ}};
assign fab_capability_attr.fab_capability.pcie0_link     = RO;
assign fab_capability_attr.fab_capability.reserved8      = {4{RsvdZ}};
assign fab_capability_attr.fab_capability.fabric_version = {8{RO}};
// Port Offset Registers Bit Attributes -------------------------------------------
fme_csr_port_offset_attr_t port0_offset_attr;
assign port0_offset_attr.port_offset.reserved61        = {3{RsvdZ}};
assign port0_offset_attr.port_offset.port_implemented  = RO;
assign port0_offset_attr.port_offset.reserved57        = {3{RsvdZ}};
assign port0_offset_attr.port_offset.decouple_port_csr = RW;
assign port0_offset_attr.port_offset.afu_access_ctrl   = RW;
assign port0_offset_attr.port_offset.reserved35        = {20{RsvdZ}};
assign port0_offset_attr.port_offset.bar_id            = {3{RO}};
assign port0_offset_attr.port_offset.reserved24        = {8{RsvdZ}};
assign port0_offset_attr.port_offset.port_byte_offset  = {24{RO}};
fme_csr_port_offset_attr_t port1_offset_attr;
assign port1_offset_attr.port_offset.reserved61        = {3{RsvdZ}};
assign port1_offset_attr.port_offset.port_implemented  = RO;
assign port1_offset_attr.port_offset.reserved57        = {3{RsvdZ}};
assign port1_offset_attr.port_offset.decouple_port_csr = RW;
assign port1_offset_attr.port_offset.afu_access_ctrl   = RW;
assign port1_offset_attr.port_offset.reserved35        = {20{RsvdZ}};
assign port1_offset_attr.port_offset.bar_id            = {3{RO}};
assign port1_offset_attr.port_offset.reserved24        = {8{RsvdZ}};
assign port1_offset_attr.port_offset.port_byte_offset  = {24{RO}};
fme_csr_port_offset_attr_t port2_offset_attr;
assign port2_offset_attr.port_offset.reserved61        = {3{RsvdZ}};
assign port2_offset_attr.port_offset.port_implemented  = RO;
assign port2_offset_attr.port_offset.reserved57        = {3{RsvdZ}};
assign port2_offset_attr.port_offset.decouple_port_csr = RW;
assign port2_offset_attr.port_offset.afu_access_ctrl   = RW;
assign port2_offset_attr.port_offset.reserved35        = {20{RsvdZ}};
assign port2_offset_attr.port_offset.bar_id            = {3{RO}};
assign port2_offset_attr.port_offset.reserved24        = {8{RsvdZ}};
assign port2_offset_attr.port_offset.port_byte_offset  = {24{RO}};
fme_csr_port_offset_attr_t port3_offset_attr;
assign port3_offset_attr.port_offset.reserved61        = {3{RsvdZ}};
assign port3_offset_attr.port_offset.port_implemented  = RO;
assign port3_offset_attr.port_offset.reserved57        = {3{RsvdZ}};
assign port3_offset_attr.port_offset.decouple_port_csr = RW;
assign port3_offset_attr.port_offset.afu_access_ctrl   = RW;
assign port3_offset_attr.port_offset.reserved35        = {20{RsvdZ}};
assign port3_offset_attr.port_offset.bar_id            = {3{RO}};
assign port3_offset_attr.port_offset.reserved24        = {8{RsvdZ}};
assign port3_offset_attr.port_offset.port_byte_offset  = {24{RO}};
// Fabric Status Register Bit Attributes ------------------------------------------
fme_csr_fab_status_attr_t fab_status_attr;
assign fab_status_attr.fab_status.reserved9 = {55{RsvdZ}};
assign fab_status_attr.fab_status.pcie0_link_status = RO;
assign fab_status_attr.fab_status.reserved0 = {8{RsvdZ}};
// Bitstream ID/MD/INFO Registers Bit Attributes ---------------------------------------
fme_csr_bitstream_id_attr_t bitstream_id_attr;
assign bitstream_id_attr.bitstream_id.ver_major   = {4{RO}};
assign bitstream_id_attr.bitstream_id.ver_minor   = {4{RO}};
assign bitstream_id_attr.bitstream_id.ver_patch   = {4{RO}};
assign bitstream_id_attr.bitstream_id.ver_debug   = {4{RO}};
assign bitstream_id_attr.bitstream_id.fim_variant = {8{RO}};
assign bitstream_id_attr.bitstream_id.reserved36  = {4{RsvdZ}};
assign bitstream_id_attr.bitstream_id.hssi_id     = {4{RO}};
assign bitstream_id_attr.bitstream_id.git_hash    = {32{RO}};
fme_csr_bitstream_md_attr_t bitstream_md_attr;
assign bitstream_md_attr.bitstream_md.reserved28  = {36{RsvdZ}};
assign bitstream_md_attr.bitstream_md.synth_year  = {8{RO}};
assign bitstream_md_attr.bitstream_md.synth_month = {8{RO}};
assign bitstream_md_attr.bitstream_md.synth_day   = {8{RO}};
assign bitstream_md_attr.bitstream_md.synth_seed  = {4{RO}};
fme_csr_bitstream_info_attr_t bitstream_info_attr;
assign bitstream_info_attr.bitstream_info.reserved32  = {32{RsvdZ}};
assign bitstream_info_attr.bitstream_info.fim_variant_revision = {32{RO}};
// Thermal/Power Monitor Registers Bit Attributes ---------------------------------
fme_csr_dfh_attr_t therm_mngm_dfh_attr;
assign therm_mngm_dfh_attr.dfh.feature_type    = {4{RO}};
assign therm_mngm_dfh_attr.dfh.reserved        = {19{RsvdZ}};
assign therm_mngm_dfh_attr.dfh.end_of_list     = RO;
assign therm_mngm_dfh_attr.dfh.next_dfh_offset = {24{RO}};
assign therm_mngm_dfh_attr.dfh.feature_rev     = {4{RO}};
assign therm_mngm_dfh_attr.dfh.feature_id      = {12{RO}};
fme_csr_tmp_threshold_attr_t tmp_threshold_attr;
assign tmp_threshold_attr.tmp_threshold.reserved45             = {19{RsvdZ}};
assign tmp_threshold_attr.tmp_threshold.threshold_policy       = RW;
assign tmp_threshold_attr.tmp_threshold.reserved42             = {2{RsvdZ}};
assign tmp_threshold_attr.tmp_threshold.val_mode_therm         = RW;
assign tmp_threshold_attr.tmp_threshold.reserved36             = {5{RsvdZ}};
assign tmp_threshold_attr.tmp_threshold.therm_trip_status      = RO;
assign tmp_threshold_attr.tmp_threshold.reserved34             = RsvdZ;
assign tmp_threshold_attr.tmp_threshold.threshold2_status      = RO;
assign tmp_threshold_attr.tmp_threshold.threshold1_status      = RO;
assign tmp_threshold_attr.tmp_threshold.reserved31             = RsvdZ;
assign tmp_threshold_attr.tmp_threshold.therm_trip_threshold   = {7{RW}};
assign tmp_threshold_attr.tmp_threshold.reserved16             = {8{RsvdZ}};
assign tmp_threshold_attr.tmp_threshold.temp_threshold2_enable = RW;
assign tmp_threshold_attr.tmp_threshold.temp_threshold2        = {7{RW}};
assign tmp_threshold_attr.tmp_threshold.temp_threshold1_enable = RW;
assign tmp_threshold_attr.tmp_threshold.temp_threshold1        = {7{RW}};
fme_csr_tmp_rdsensor_fmt1_attr_t tmp_rdsensor_fmt1_attr;
assign tmp_rdsensor_fmt1_attr.tmp_rdsensor_fmt1.reserved42          = {22{RsvdZ}};
assign tmp_rdsensor_fmt1_attr.tmp_rdsensor_fmt1.temp_thermal_sensor = {10{RO}};
assign tmp_rdsensor_fmt1_attr.tmp_rdsensor_fmt1.reserved25          = {7{RsvdZ}};
assign tmp_rdsensor_fmt1_attr.tmp_rdsensor_fmt1.temp_valid          = RO;
assign tmp_rdsensor_fmt1_attr.tmp_rdsensor_fmt1.numb_temp_reads     = {17{RO}};
assign tmp_rdsensor_fmt1_attr.tmp_rdsensor_fmt1.reserved7           = RsvdZ;
assign tmp_rdsensor_fmt1_attr.tmp_rdsensor_fmt1.fpga_temp           = {7{RO}};
ofs_csr_reg_generic_attr_t tmp_rdsensor_fmt2_attr;
assign tmp_rdsensor_fmt2_attr.data = { 64{RsvdZ} };
fme_csr_tmp_threshold_capability_attr_t tmp_threshold_capability_attr;
assign tmp_threshold_capability_attr.tmp_threshold_capability.reserved = {63{RsvdZ}};
assign tmp_threshold_capability_attr.tmp_threshold_capability.disable_tmp_thresh_report = RO;
// Global Performance Monitor DFH Register Bit Attributes -------------------------
fme_csr_dfh_attr_t glbl_perf_dfh_attr;
assign glbl_perf_dfh_attr.dfh.feature_type    = {4{RO}};
assign glbl_perf_dfh_attr.dfh.reserved        = {19{RsvdZ}};
assign glbl_perf_dfh_attr.dfh.end_of_list     = RO;
assign glbl_perf_dfh_attr.dfh.next_dfh_offset = {24{RO}};
assign glbl_perf_dfh_attr.dfh.feature_rev     = {4{RO}};
assign glbl_perf_dfh_attr.dfh.feature_id      = {12{RO}};
// Dummy Register Bit Attributes --------------------------------------------------
ofs_csr_reg_generic_attr_t dummy_3008_attr;
assign dummy_3008_attr.data = { 64{RO} };
ofs_csr_reg_generic_attr_t dummy_3010_attr;
assign dummy_3010_attr.data = { 64{RO} };
ofs_csr_reg_generic_attr_t dummy_3018_attr;
assign dummy_3018_attr.data = { 64{RO} };
// Performance Monitor Register Bit Attributes ------------------------------------
fme_csr_fpmon_fab_ctl_attr_t fpmon_fab_ctl_attr;
assign fpmon_fab_ctl_attr.fpmon_fab_ctl.reserved24        = {40{RsvdZ}};
assign fpmon_fab_ctl_attr.fpmon_fab_ctl.port_filter       = RW;
assign fpmon_fab_ctl_attr.fpmon_fab_ctl.reserved22        = RsvdZ;
assign fpmon_fab_ctl_attr.fpmon_fab_ctl.port_id           = {2{RW}};
assign fpmon_fab_ctl_attr.fpmon_fab_ctl.fabric_event_code = {4{RW}};
assign fpmon_fab_ctl_attr.fpmon_fab_ctl.reserved9         = {7{RsvdZ}};
assign fpmon_fab_ctl_attr.fpmon_fab_ctl.freeze_counters   = RW;
assign fpmon_fab_ctl_attr.fpmon_fab_ctl.reserved0         = {8{RsvdZ}};
fme_csr_fpmon_fab_ctr_attr_t fpmon_fab_ctr_attr;
assign fpmon_fab_ctr_attr.fpmon_fab_ctr.fabric_event_code    = {4{RO}};
assign fpmon_fab_ctr_attr.fpmon_fab_ctr.fabric_event_counter = {60{RO}};
fme_csr_fpmon_clk_ctr_attr_t fpmon_clk_ctr_attr;
assign fpmon_clk_ctr_attr.fpmon_clk_ctr.clock_counter = { 64{RO} };
// Error, Interrupt, and Mask Register Bit Attributes -----------------------------
fme_csr_dfh_attr_t glbl_error_dfh_attr;
assign glbl_error_dfh_attr.dfh.feature_type    = {4{RO}};
assign glbl_error_dfh_attr.dfh.reserved        = {19{RsvdZ}};
assign glbl_error_dfh_attr.dfh.end_of_list     = RO;
assign glbl_error_dfh_attr.dfh.next_dfh_offset = {24{RO}};
assign glbl_error_dfh_attr.dfh.feature_rev     = {4{RO}};
assign glbl_error_dfh_attr.dfh.feature_id      = {12{RO}};
fme_csr_fme_error_mask0_attr_t fme_error_mask0_attr;
assign fme_error_mask0_attr.fme_error_mask0.reserved1   = {63{Rsvd}};
assign fme_error_mask0_attr.fme_error_mask0.error_mask0 = RW;
fme_csr_pcie0_error_mask_attr_t pcie0_error_mask_attr;
assign pcie0_error_mask_attr.pcie0_error_mask.reserved   = {64{RsvdZ}};
ofs_csr_reg_generic_attr_t dummy_4028_attr;
assign dummy_4028_attr.data = { 64{RO} };
ofs_csr_reg_generic_attr_t dummy_4030_attr;
assign dummy_4030_attr.data = { 64{RO} };
fme_csr_fme_first_next_error_attr_t fme_first_error_attr;
assign fme_first_error_attr.fme_first_next_error.reserved         = {2{RsvdZ}};
assign fme_first_error_attr.fme_first_next_error.error_reg_id     = {2{RO}};
assign fme_first_error_attr.fme_first_next_error.error_reg_status = {60{RO}};
fme_csr_fme_first_next_error_attr_t fme_next_error_attr;
assign fme_next_error_attr.fme_first_next_error.reserved         = {2{RsvdZ}};
assign fme_next_error_attr.fme_first_next_error.error_reg_id     = {2{RO}};
assign fme_next_error_attr.fme_first_next_error.error_reg_status = {60{RO}};
fme_csr_ras_nofat_error_mask_attr_t ras_nofat_error_mask_attr;
assign ras_nofat_error_mask_attr.ras_nofat_error_mask.reserved7   = {57{RsvdZ}};
assign ras_nofat_error_mask_attr.ras_nofat_error_mask.error_mask5 = {2{RW}};
assign ras_nofat_error_mask_attr.ras_nofat_error_mask.reserved4   = RsvdZ;
assign ras_nofat_error_mask_attr.ras_nofat_error_mask.error_mask2 = {2{RW}};
assign ras_nofat_error_mask_attr.ras_nofat_error_mask.reserved0   = {2{RsvdZ}};
fme_csr_ras_nofat_error_attr_t ras_nofat_error_attr;
assign ras_nofat_error_attr.ras_nofat_error.reserved7              = {57{RsvdZ}};
assign ras_nofat_error_attr.ras_nofat_error.injected_warning_error = RW1C;
assign ras_nofat_error_attr.ras_nofat_error.afu_access_mode_error  = RW1C;
assign ras_nofat_error_attr.ras_nofat_error.reserved4              = RsvdZ;
assign ras_nofat_error_attr.ras_nofat_error.port_fatal_error       = RW1C;
assign ras_nofat_error_attr.ras_nofat_error.pcie_error             = RO;
assign ras_nofat_error_attr.ras_nofat_error.reserved0              = {2{RsvdZ}};
fme_csr_ras_catfat_error_mask_attr_t ras_catfat_error_mask_attr;
assign ras_catfat_error_mask_attr.ras_catfat_error_mask.reserved12   = {52{RsvdZ}};
assign ras_catfat_error_mask_attr.ras_catfat_error_mask.error_mask11 = RW;
assign ras_catfat_error_mask_attr.ras_catfat_error_mask.reserved10   = RsvdZ;
assign ras_catfat_error_mask_attr.ras_catfat_error_mask.error_mask6  = {4{RW}};
assign ras_catfat_error_mask_attr.ras_catfat_error_mask.reserved0    = {6{RsvdZ}};
fme_csr_ras_catfat_error_attr_t ras_catfat_error_attr;
assign ras_catfat_error_attr.ras_catfat_error.reserved12            = {52{RsvdZ}};
assign ras_catfat_error_attr.ras_catfat_error.injected_catast_error = RO;
assign ras_catfat_error_attr.ras_catfat_error.reserved10            = RsvdZ;
assign ras_catfat_error_attr.ras_catfat_error.crc_catast_error      = RO;
assign ras_catfat_error_attr.ras_catfat_error.injected_fatal_error  = RO;
assign ras_catfat_error_attr.ras_catfat_error.pcie_poison_error     = RO;
assign ras_catfat_error_attr.ras_catfat_error.fabric_fatal_error    = RO;
assign ras_catfat_error_attr.ras_catfat_error.reserved0             = {6{RsvdZ}};
fme_csr_ras_error_inj_attr_t ras_error_inj_attr;
assign ras_error_inj_attr.ras_error_inj.reserved3     = {61{RsvdZ}};
assign ras_error_inj_attr.ras_error_inj.nofatal_error = RW;
assign ras_error_inj_attr.ras_error_inj.fatal_error   = RW;
assign ras_error_inj_attr.ras_error_inj.catast_error  = RW;
fme_csr_glbl_error_capability_attr_t glbl_error_capability_attr;
assign glbl_error_capability_attr.glbl_error_capability.reserved13              = {51{RsvdZ}};
assign glbl_error_capability_attr.glbl_error_capability.interrupt_vector_number = {12{RO}};
assign glbl_error_capability_attr.glbl_error_capability.supports_interrupt      = RO;


//----------------------------------------------------------------------------
// FME CSR Structures are used to make register assignments and breakouts 
// easier to understand.  These definitions may be found in the package:
//     fme_csr_pkg.sv
//
// These are essentially overlays on the register array to map their
// respective bit fields.
//----------------------------------------------------------------------------
//  Assignment/Update Overlays:
//     These structure overlays help map out the fields for the status register 
//     "update" inputs used by the function "update_reg" to determine the 
//     next values stored in the FME status CSRs.
//----------------------------------------------------------------------------
fme_csr_fme_dfh_t                  fme_csr_fme_dfh_reset, fme_csr_fme_dfh_update;
fme_csr_fme_afu_id_l_t             fme_csr_fme_afu_id_l_reset, fme_csr_fme_afu_id_l_update;
fme_csr_fme_afu_id_h_t             fme_csr_fme_afu_id_h_reset, fme_csr_fme_afu_id_h_update;
fme_csr_fme_next_afu_t             fme_csr_fme_next_afu_reset, fme_csr_fme_next_afu_update;
ofs_csr_reg_generic_t              fme_csr_dummy_0020_reset, fme_csr_dummy_0020_update;
ofs_csr_reg_generic_t              fme_csr_fme_scratchpad0_reset, fme_csr_fme_scratchpad0_update;
fme_csr_fab_capability_t           fme_csr_fab_capability_reset, fme_csr_fab_capability_update;
fme_csr_port_offset_t              fme_csr_port0_offset_reset,  fme_csr_port1_offset_reset,  fme_csr_port2_offset_reset,  fme_csr_port3_offset_reset;
fme_csr_port_offset_t              fme_csr_port0_offset_update, fme_csr_port1_offset_update, fme_csr_port2_offset_update, fme_csr_port3_offset_update;
fme_csr_fab_status_t               fme_csr_fab_status_reset, fme_csr_fab_status_update;
fme_csr_bitstream_id_t             fme_csr_bitstream_id_reset, fme_csr_bitstream_id_update;
fme_csr_bitstream_md_t             fme_csr_bitstream_md_reset, fme_csr_bitstream_md_update;
fme_csr_bitstream_info_t           fme_csr_bitstream_info_reset, fme_csr_bitstream_info_update;
fme_csr_dfh_t                      fme_csr_therm_mngm_dfh_reset, fme_csr_therm_mngm_dfh_update;
fme_csr_tmp_threshold_t            fme_csr_tmp_threshold_reset, fme_csr_tmp_threshold_update;
fme_csr_tmp_rdsensor_fmt1_t        fme_csr_tmp_rdsensor_fmt1_reset, fme_csr_tmp_rdsensor_fmt1_update;
ofs_csr_reg_generic_t              fme_csr_tmp_rdsensor_fmt2_reset, fme_csr_tmp_rdsensor_fmt2_update;
fme_csr_tmp_threshold_capability_t fme_csr_tmp_threshold_capability_reset, fme_csr_tmp_threshold_capability_update; 
fme_csr_dfh_t                      fme_csr_glbl_perf_dfh_reset, fme_csr_glbl_perf_dfh_update;
ofs_csr_reg_generic_t              fme_csr_dummy_3008_reset, fme_csr_dummy_3008_update;
ofs_csr_reg_generic_t              fme_csr_dummy_3010_reset, fme_csr_dummy_3010_update;
ofs_csr_reg_generic_t              fme_csr_dummy_3018_reset, fme_csr_dummy_3018_update;
fme_csr_fpmon_fab_ctl_t            fme_csr_fpmon_fab_ctl_reset, fme_csr_fpmon_fab_ctl_update; 
fme_csr_fpmon_fab_ctr_t            fme_csr_fpmon_fab_ctr_reset, fme_csr_fpmon_fab_ctr_update; 
fme_csr_fpmon_clk_ctr_t            fme_csr_fpmon_clk_ctr_reset, fme_csr_fpmon_clk_ctr_update; 
fme_csr_dfh_t                      fme_csr_glbl_error_dfh_reset, fme_csr_glbl_error_dfh_update;
fme_csr_fme_error_mask0_t          fme_csr_fme_error_mask0_reset, fme_csr_fme_error_mask0_update; 
fme_csr_fme_error0_t               fme_csr_fme_error0_reset, fme_csr_fme_error0_update; 
fme_csr_pcie0_error_mask_t         fme_csr_pcie0_error_mask_reset, fme_csr_pcie0_error_mask_update; 
fme_csr_pcie0_error_t              fme_csr_pcie0_error_reset, fme_csr_pcie0_error_update; 
ofs_csr_reg_generic_t              fme_csr_dummy_4028_reset, fme_csr_dummy_4028_update;
ofs_csr_reg_generic_t              fme_csr_dummy_4030_reset, fme_csr_dummy_4030_update;
fme_csr_fme_first_next_error_t     fme_csr_fme_first_error_reset, fme_csr_fme_first_error_update; 
fme_csr_fme_first_next_error_t     fme_csr_fme_next_error_reset, fme_csr_fme_next_error_update; 
fme_csr_ras_nofat_error_mask_t     fme_csr_ras_nofat_error_mask_reset, fme_csr_ras_nofat_error_mask_update; 
fme_csr_ras_nofat_error_t          fme_csr_ras_nofat_error_reset, fme_csr_ras_nofat_error_update; 
fme_csr_ras_catfat_error_mask_t    fme_csr_ras_catfat_error_mask_reset, fme_csr_ras_catfat_error_mask_update; 
fme_csr_ras_catfat_error_t         fme_csr_ras_catfat_error_reset, fme_csr_ras_catfat_error_update; 
fme_csr_ras_error_inj_t            fme_csr_ras_error_inj_reset, fme_csr_ras_error_inj_update; 
fme_csr_glbl_error_capability_t    fme_csr_glbl_error_capability_reset, fme_csr_glbl_error_capability_update; 


//----------------------------------------------------------------------------
//  Breakout Overlays:
//     These structure overlays Help break out the CSR control register 
//     outputs to their destinations.
//----------------------------------------------------------------------------
fme_csr_fab_capability_t           fme_csr_fab_capability;
fme_csr_port_offset_t              fme_csr_port0_offset, fme_csr_port1_offset, fme_csr_port2_offset, fme_csr_port3_offset;
fme_csr_tmp_threshold_t            fme_csr_tmp_threshold;
fme_csr_fpmon_fab_ctl_t            fme_csr_fpmon_fab_ctl; 
fme_csr_ras_catfat_error_mask_t    fme_csr_ras_catfat_error_mask; 
fme_csr_ras_catfat_error_t         fme_csr_ras_catfat_error;
fme_csr_ras_nofat_error_mask_t     fme_csr_ras_nofat_error_mask; 
fme_csr_ras_nofat_error_t          fme_csr_ras_nofat_error; 
fme_csr_ras_error_inj_t            fme_csr_ras_error_inj;
fme_csr_fme_error_mask0_t          fme_csr_fme_error_mask0; 
fme_csr_fme_error0_t               fme_csr_fme_error0; 
fme_csr_pcie0_error_mask_t         fme_csr_pcie0_error_mask; 
fme_csr_pcie0_error_t              fme_csr_pcie0_error; 


//----------------------------------------------------------------------------
// Here are the state definitions for the read and write state machines.  
// Both state machines are coded one-hot using a reverse case statement.  
// (Quartus recommended coding style.)
//----------------------------------------------------------------------------

//----------------------------------------------------------------------------
// Write State Machine Definitions:
//----------------------------------------------------------------------------
enum {
   WR_RESET_BIT             = 0,
   WR_READY_BIT             = 1,
   WR_GOT_ADDR_BIT          = 2,
   WR_GOT_DATA_BIT          = 3,
   WR_GOT_ADDR_AND_DATA_BIT = 4,
   WRITE_RESP_BIT           = 5,
   WRITE_COMPLETE_BIT       = 6
} wr_state_bit;

enum logic [6:0] {
   WR_RESET             = 7'b0000001<<WR_RESET_BIT,
   WR_READY             = 7'b0000001<<WR_READY_BIT,
   WR_GOT_ADDR          = 7'b0000001<<WR_GOT_ADDR_BIT,
   WR_GOT_DATA          = 7'b0000001<<WR_GOT_DATA_BIT,
   WR_GOT_ADDR_AND_DATA = 7'b0000001<<WR_GOT_ADDR_AND_DATA_BIT,
   WRITE_RESP           = 7'b0000001<<WRITE_RESP_BIT,
   WRITE_COMPLETE       = 7'b0000001<<WRITE_COMPLETE_BIT
} wr_state, wr_next;

//----------------------------------------------------------------------------
// Read State Machine Definitions:
//----------------------------------------------------------------------------
enum {
   RD_RESET_BIT      = 0,
   RD_READY_BIT      = 1,
   RD_GOT_ADDR_BIT   = 2,
   RD_DRIVE_BUS_BIT  = 3,
   READ_COMPLETE_BIT = 4
} rd_state_bit;

enum logic [4:0] {
   RD_RESET      = 5'b00001<<RD_RESET_BIT,
   RD_READY      = 5'b00001<<RD_READY_BIT,
   RD_GOT_ADDR   = 5'b00001<<RD_GOT_ADDR_BIT,
   RD_DRIVE_BUS  = 5'b00001<<RD_DRIVE_BUS_BIT,
   READ_COMPLETE = 5'b00001<<READ_COMPLETE_BIT
} rd_state, rd_next;


//----------------------------------------------------------------------------
// SIGNAL DEFINITIONS
//----------------------------------------------------------------------------
logic clk;  
logic reset_n;
logic pwr_good_n;
assign clk = axi.clk;
assign reset_n = axi.rst_n;
assign pwr_good_n = pgn.pwr_good_n;


//----------------------------------------------------------------------------
// CSR registers are implemented in a two dimensional array according to the
// features and the number of registers per feature.  This allows the most
// flexibility addressing the registers as well as using the least resources.
//----------------------------------------------------------------------------
//....[63:0 packed width]......reg[4:0 - #Features   ][14:0 - #Regs in Feature]  <<= Unpacked dimensions.
logic [CSR_REG_WIDTH-1:0] csr_reg[CSR_FEATURE_NUM-1:0][CSR_FEATURE_REG_NUM-1:0]; // CSR Registers

//----------------------------------------------------------------------------
// AXI CSR WRITE VARIABLES
//----------------------------------------------------------------------------
logic csr_write[CSR_FEATURE_NUM-1:0][CSR_FEATURE_REG_NUM-1:0]; // Register Write Strobes - Arrayed like the CSR registers.
ofs_csr_hw_state_t hw_state; // Hardware state during CSR updates.   This simplifies the CSR Register Update function call.

logic wr_range_valid, wr_range_valid_reg, awsize_valid, awsize_valid_reg, wstrb_valid, wstrb_valid_reg;
logic [CSR_REG_WIDTH-1:0] data_reg;
csr_access_type_t write_type, write_type_reg;

logic [3:0] wr_feature_id;
logic [8:0] wr_reg_offset;
assign wr_feature_id = axi.awaddr[15:12]; // Feature Number Address.
//assign wr_reg_offset = axi.awaddr[7:3];   // Feature Register Address.
assign wr_reg_offset = axi.awaddr[11:3];   // Feature Register Address.

logic [MMIO_TID_WIDTH-1:0] awid_reg;
logic [MMIO_ADDR_WIDTH-1:0] awaddr_reg;
logic [2:0] awsize_reg;
logic [7:0] wstrb_reg;


//----------------------------------------------------------------------------
// AXI CSR READ VARIABLES
//----------------------------------------------------------------------------
logic rd_range_valid, rd_range_valid_reg, arsize_valid, arsize_valid_reg;
logic cfg_rd_hit;
ofs_csr_reg_generic_t read_data_reg;
logic [CSR_REG_WIDTH-1:0] read_data;
csr_access_type_t read_type, read_type_reg;

logic [3:0] rd_feature_id;
logic [8:0] rd_reg_offset;
assign rd_feature_id = axi.araddr[15:12]; // Feature Number Address.
//assign rd_reg_offset = axi.araddr[7:3];   // Feature Register Address.
assign rd_reg_offset = axi.araddr[11:3];   // Feature Register Address.

logic [MMIO_TID_WIDTH-1:0] arid_reg;
logic [MMIO_ADDR_WIDTH-1:0] araddr_reg;
logic [2:0] arsize_reg;


//----------------------------------------------------------------------------
// AXI MMIO CSR WRITE LOGIC
//----------------------------------------------------------------------------

//----------------------------------------------------------------------------
// REGISTER INTERFACE LOGIC
//----------------------------------------------------------------------------
always_comb
begin : wr_range_valid_comb
   if (axi.awaddr[19:16] != '0)  // Restricting FME_CSR region to lower 256KB of BAR (512KB) in CoreFIM.
      wr_range_valid = 1'b0;
   else
   begin
      unique case (wr_feature_id)
         FME_DFH       [15:12]: wr_range_valid = (wr_reg_offset < 15) ? 1'b1 : 1'b0; 
         THERM_MNGM_DFH[15:12]: wr_range_valid = (wr_reg_offset < 5)  ? 1'b1 : 1'b0;
         GLBL_PERF_DFH [15:12]: wr_range_valid = (wr_reg_offset < 7)  ? 1'b1 : 1'b0;
         GLBL_ERROR_DFH[15:12]: wr_range_valid = (wr_reg_offset < 15) ? 1'b1 : 1'b0;
         default:               wr_range_valid = 1'b0;
      endcase
   end
end : wr_range_valid_comb


//----------------------------------------------------------------------------
// Combinatorial logic for valid write access sizes: 
//    2^2 = 4B(32-bit) or 
//    2^3 = 8B(64-bit).
//----------------------------------------------------------------------------
always_comb
begin : wr_size_valid_comb
   if ((axi.awsize == 3'b011) || (axi.awsize == 3'b010)) 
      awsize_valid = 1'b1;
   else
      awsize_valid = 1'b0;
end : wr_size_valid_comb


//----------------------------------------------------------------------------
// Combinatorial logic to ensure correct write access size is paired with 
// correct write strobe: 
//    2^2 = 4B(32-bit) with data in lower word 8'h0F or 
//    2^2 = 4B(32-bit) with data in upper word 8'hF0 or 
//    2^3 = 8B(64-bit) with data in whole word 8'hFF.
// Logic must be careful to detect simultaneous awvalid and wvalid OR awvalid 
// leading wvalid.   Signal awvalid alone will not cause a wstrb evaluation.
//----------------------------------------------------------------------------
always_comb
begin : wstrb_valid_comb
   if (axi.awvalid && axi.wvalid) 
      wstrb_valid = (
                     ((axi.awsize == 3'b010) && (axi.wstrb == 8'h0F)) || 
                     ((axi.awsize == 3'b010) && (axi.wstrb == 8'hF0)) || 
                     ((axi.awsize == 3'b011) && (axi.wstrb == 8'hFF))
                  ) ? 1'b1 : 1'b0;
   else
   if (!axi.awvalid && axi.wvalid)
      wstrb_valid = (
                     ((awsize_reg == 3'b010) && (axi.wstrb == 8'h0F)) || 
                     ((awsize_reg == 3'b010) && (axi.wstrb == 8'hF0)) || 
                     ((awsize_reg == 3'b011) && (axi.wstrb == 8'hFF))
                  ) ? 1'b1 : 1'b0;
   else
      wstrb_valid = 1'b0;
end : wstrb_valid_comb


//----------------------------------------------------------------------------
// Combinatorial logic to define what type of write is occurring:
//    1.) UPPER32 = Upper 32 bits of register from lower 32 bits of the write
//                  data bus.
//    2.) LOWER32 = Lower 32 bits of register from lower 32 bits of the write
//                  data bus.
//    3.) FULL64  = All 64 bits of the register from all 64 bits of the write
//                  data bus.
//    4.) NONE = No write will be performed on register.
// Logic must be careful to detect simultaneous awvalid and wvalid OR awvalid 
// leading wvalid.   A write address with bit #2 set decides whether 32-bit 
// write is to upper or lower word.
//----------------------------------------------------------------------------
always_comb
begin : write_type_comb
   if (axi.awvalid && axi.wvalid && wr_range_valid && awsize_valid) // When address and data are simultaneously presented on AXI Bus.
   begin
      if ((axi.awsize == 3'b010) && (axi.wstrb == 8'hF0) && (axi.awaddr[2] == 1'b1))
         write_type = UPPER32;
      else 
      begin
         if ((axi.awsize == 3'b010) && (axi.wstrb == 8'h0F) && (axi.awaddr[2] == 1'b0))
            write_type = LOWER32;
         else
         begin
            if ((axi.awsize == 3'b011) && (axi.wstrb == 8'hFF))
               write_type = FULL64;
            else
               write_type = NONE;
         end
      end
   end
   else
   begin
      if (!axi.awvalid && axi.wvalid && wr_range_valid_reg && awsize_valid_reg)  // When address sent prior to data on AXI Bus, use stored "awsize" value.
      begin
         if ((awsize_reg == 3'b010) && (axi.wstrb == 8'hF0) && (awaddr_reg[2] == 1'b1))
            write_type = UPPER32;
         else
         begin
            if ((awsize_reg == 3'b010) && (axi.wstrb == 8'h0F) && (awaddr_reg[2] == 1'b0))
               write_type = LOWER32;
            else
            begin
               if ((awsize_reg == 3'b011) && (axi.wstrb == 8'hFF))
                  write_type = FULL64;
               else
                  write_type = NONE;
            end
         end
      end
      else
      begin
         write_type = NONE; // Otherwise, do nothing.
      end
   end
end : write_type_comb


//----------------------------------------------------------------------------
// Write State Machine Logic
//
// Top "always_ff" simply switches the state of the state machine registers.
//
// Following "always_comb" contains all of the next-state decoding logic.
//
// NOTE: The state machine is coded in a one-hot style with a "reverse-case" 
// statement.  This style compiles with the highest performance in Quartus.
//----------------------------------------------------------------------------
always_ff @(posedge clk, negedge reset_n)
begin : wr_sm_seq
   if (!reset_n)
      wr_state <= WR_RESET;
   else
      wr_state <= wr_next;
end : wr_sm_seq

always_comb
begin : wr_sm_comb
   wr_next = wr_state;
   unique case (1'b1) //Reverse Case Statement
      wr_state[WR_RESET_BIT]:
         if (!reset_n)
            wr_next = WR_RESET;
         else
            wr_next = WR_READY;
      wr_state[WR_READY_BIT]:
         if (!axi.awvalid && !axi.wvalid)
            wr_next = WR_READY;
         else
            if (!axi.awvalid && axi.wvalid)
               wr_next = WR_GOT_DATA;
            else
               if (axi.awvalid && !axi.wvalid)
                  wr_next = WR_GOT_ADDR;
               else
                  wr_next = WR_GOT_ADDR_AND_DATA;
      wr_state[WR_GOT_ADDR_BIT]:
         if (!axi.awvalid && !axi.wvalid)
            wr_next = WR_READY;
         else
            if (!axi.awvalid && axi.wvalid)
               wr_next = WR_GOT_DATA;
            else
               if (axi.awvalid && !axi.wvalid)
                  wr_next = WR_GOT_ADDR;
               else
                  wr_next = WR_GOT_ADDR_AND_DATA;
      wr_state[WR_GOT_DATA_BIT]:
         wr_next = WRITE_RESP;
      wr_state[WR_GOT_ADDR_AND_DATA_BIT]:
         wr_next = WRITE_RESP;
      wr_state[WRITE_RESP_BIT]:
         if (!axi.bready)
            wr_next = WRITE_RESP;
         else
            wr_next = WRITE_COMPLETE;
      wr_state[WRITE_COMPLETE_BIT]:
         wr_next = WR_READY;
   endcase
end : wr_sm_comb


//----------------------------------------------------------------------------
// Sequential logic to capture some transaction-qualifying signals during 
// writes on the write-data bus.  Values are sampled on the transition into
// "DATA" states in the write state machine.
//----------------------------------------------------------------------------
always_ff @(posedge clk, negedge reset_n)
begin : wr_data_seq_var
   if (!reset_n)
   begin
      wstrb_reg <= 8'h00;
      wstrb_valid_reg <= 1'b0;
      write_type_reg <= NONE;
      data_reg  <= {64{1'b0}};
      csr_write <= '{default:0};
   end
   else
   begin
      if (wr_next[WR_GOT_DATA_BIT] || wr_next[WR_GOT_ADDR_AND_DATA_BIT])
      begin
         wstrb_reg <= axi.wstrb;
         wstrb_valid_reg <= wstrb_valid;
         write_type_reg <= write_type;
         data_reg  <= axi.wdata;
         if (wr_next[WR_GOT_DATA_BIT])
         begin
            csr_write <= '{default:0};
            csr_write[awaddr_reg[15:12]][awaddr_reg[7:3]] <= 1'b1;
         end
         else
         begin
            csr_write <= '{default:0};
            csr_write[axi.awaddr[15:12]][axi.awaddr[7:3]] <= 1'b1;
         end
      end
      else
      begin
         if (wr_state[WRITE_COMPLETE_BIT])
         begin
            wstrb_reg <= 8'h00;
            wstrb_valid_reg <= 1'b0;
            write_type_reg <= NONE;
            data_reg  <= {64{1'b0}};
            csr_write <= '{default:0};
         end
      end
   end
end : wr_data_seq_var


//----------------------------------------------------------------------------
// Sequential logic to capture some transaction-qualifying signals during 
// writes on the write-address bus.  Values are sampled on the transition into
// "ADDR" states in the write state machine.
//----------------------------------------------------------------------------
always_ff @(posedge clk, negedge reset_n)
begin : wr_addr_seq_var
   if (!reset_n)
   begin
      awid_reg <= {MMIO_TID_WIDTH{1'b0}};
      awaddr_reg <= {MMIO_ADDR_WIDTH{1'b0}};
      awsize_reg <= 3'b000;
      wr_range_valid_reg <= 1'b0;
      awsize_valid_reg  <= 1'b0;
   end
   else
   begin
      if (wr_next[WR_GOT_ADDR_BIT] || wr_next[WR_GOT_ADDR_AND_DATA_BIT])
      begin
         awid_reg <= axi.awid;
         awaddr_reg <= axi.awaddr;
         awsize_reg <= axi.awsize;
         wr_range_valid_reg <= wr_range_valid;
         awsize_valid_reg  <= awsize_valid;
      end
      else
      begin
         if (wr_state[WRITE_COMPLETE_BIT])
         begin
            awid_reg <= {MMIO_TID_WIDTH{1'b0}};
            awaddr_reg <= {MMIO_ADDR_WIDTH{1'b0}};
            awsize_reg <= 3'b000;
            wr_range_valid_reg <= 1'b0;
            awsize_valid_reg  <= 1'b0;
         end
      end
   end
end : wr_addr_seq_var


//----------------------------------------------------------------------------
// FME IDs : FME CSR setup values for the following registers are read from 
//           ROM contents at startup:
//
//           BITSTREAM_ID @ Address 20'h0_0060 in FME
//           BITSTREAM_MD @ Address 20'h0_0068 in FME
//           FME_PR_INTFC_ID_L @ Port Gasket PR DFH
//           FME_PR_INTFC_ID_H @ Port Gasket PR DFH
//           BITSTREAM_INFO @ Address 20'h0_0070 in FME
//           RESERVED_0_IDX @ Reserved Space 0
//           RESERVED_1_IDX @ Reserved Space 1
//           RESERVED_2_IDX @ Reserved Space 2
//----------------------------------------------------------------------------
localparam FME_ID_NUM_REGS = 8;
localparam FME_ID_IDX_WIDTH = $clog2(FME_ID_NUM_REGS);

typedef enum bit [FME_ID_IDX_WIDTH-1:0]  {
   BITSTREAM_ID_IDX,
   BITSTREAM_MD_IDX,
   FME_PR_IF_ID_L_IDX,
   FME_PR_IF_ID_H_IDX,
   BITSTREAM_INFO_IDX,
   RESERVED_0_IDX,
   RESERVED_1_IDX,
   RESERVED_2_IDX
} fme_id_idx_t;
fme_id_idx_t FME_ID_MEM_MAX = RESERVED_2_IDX;
logic [63:0] fme_id_regs[FME_ID_NUM_REGS-1:0];
logic [FME_ID_IDX_WIDTH-1:0] rom_addr;
logic [63:0] rom_data;

//--------------------------------------------------------------------------------
// ROM storing FME IDs:
// Reading a ROM address takes 2 clock cycles (both address and q are registered).
//--------------------------------------------------------------------------------
fme_id_rom fme_id_rom (
   .address(rom_addr),
   .clock(clk),
   .q(rom_data)
);
//----------------------------------------------------------------------------
// Population of FME IDs from ROM to FME ID registers is continually done by 
// the following state machine.
//----------------------------------------------------------------------------
enum {
   ROM_RESET_BIT      = 0,
   ROM_CLK_ADDR_BIT   = 1,
   ROM_FETCH_DATA_BIT = 2,
   ROM_CLK_DATA_BIT   = 3,
   ROM_STORE_REG_BIT  = 4,
   ROM_INC_ADDR_BIT   = 5
} rom_state_bit;


enum logic [5:0] {
   ROM_RESET      = 6'b000001<<ROM_RESET_BIT,
   ROM_CLK_ADDR   = 6'b000001<<ROM_CLK_ADDR_BIT,
   ROM_FETCH_DATA = 6'b000001<<ROM_FETCH_DATA_BIT,
   ROM_CLK_DATA   = 6'b000001<<ROM_CLK_DATA_BIT,
   ROM_STORE_REG  = 6'b000001<<ROM_STORE_REG_BIT,
   ROM_INC_ADDR   = 6'b000001<<ROM_INC_ADDR_BIT
} rom_state, rom_next;


always_ff @(posedge clk, negedge reset_n)
begin : rom_sm_seq
   if (!reset_n)
      rom_state <= ROM_RESET;
   else
      rom_state <= rom_next;
end : rom_sm_seq


always_comb
begin : rom_sm_comb
   rom_next = rom_state;
   unique case (1'b1) //Reverse Case Statement
      rom_state[ROM_RESET_BIT] :
         if (!reset_n)
            rom_next = ROM_RESET;
         else
            rom_next = ROM_CLK_ADDR;
      rom_state[ROM_CLK_ADDR_BIT] :
         rom_next = ROM_FETCH_DATA;
      rom_state[ROM_FETCH_DATA_BIT] :
         rom_next = ROM_CLK_DATA;
      rom_state[ROM_CLK_DATA_BIT] :
         rom_next = ROM_STORE_REG;
      rom_state[ROM_STORE_REG_BIT] :
         rom_next = ROM_INC_ADDR;
      rom_state[ROM_INC_ADDR_BIT] :
         rom_next = ROM_CLK_ADDR;
   endcase
end : rom_sm_comb


always_ff @(posedge clk) 
begin
   if (rom_state[ROM_RESET_BIT]) 
   begin
      fme_id_regs[BITSTREAM_ID_IDX]   <= {64{1'b0}};
      fme_id_regs[BITSTREAM_MD_IDX]   <= {64{1'b0}};
      fme_id_regs[FME_PR_IF_ID_L_IDX] <= {64{1'b0}};
      fme_id_regs[FME_PR_IF_ID_H_IDX] <= {64{1'b0}};
      fme_id_regs[BITSTREAM_INFO_IDX] <= {64{1'b0}};
      fme_id_regs[RESERVED_0_IDX]     <= {64{1'b0}};
      fme_id_regs[RESERVED_1_IDX]     <= {64{1'b0}};
      fme_id_regs[RESERVED_2_IDX]     <= {64{1'b0}};
   end
   else
   begin
      if (rom_state[ROM_STORE_REG_BIT])
      begin
         fme_id_regs[rom_addr] <= rom_data;
      end
   end
end

always_ff @(posedge clk)
begin
   if (rom_state[ROM_RESET_BIT])
      rom_addr <= FME_ID_IDX_WIDTH'('b000);
   else
      if (rom_state[ROM_INC_ADDR_BIT])
         rom_addr <= rom_addr + FME_ID_IDX_WIDTH'('d1);
end

//----------------------------------------------------------------------------
// Sequential logic for interface and handshaking signals controlled mostly
// by the write state machine decoding logic to sequence events.
//----------------------------------------------------------------------------
always_ff @(posedge clk)
begin
   if (!reset_n)
   begin
      axi.awready <= 1'b0;
      axi.wready  <= 1'b0;
      axi.bvalid  <= 1'b0;
      axi.bid     <= {MMIO_TID_WIDTH{1'b0}};
      axi.bresp   <= RESP_OKAY;
   end
   else
   begin
      axi.awready <=  wr_next[WR_READY_BIT] || wr_next[WR_GOT_ADDR_BIT];
      axi.wready  <=  wr_next[WR_READY_BIT] || wr_next[WR_GOT_ADDR_BIT];
      axi.bvalid  <=  wr_next[WRITE_RESP_BIT];
      axi.bid     <= (wr_next[WRITE_RESP_BIT]) ? awid_reg : {MMIO_TID_WIDTH{1'b0}};
      axi.bresp   <=  RESP_OKAY;
   end
end

//----------------------------------------------------------------------------
// HW State is a data struct used to pass the resets, write data, and write
// type to the CSR "update_reg" function.
//----------------------------------------------------------------------------
assign hw_state.reset_n      = reset_n;
assign hw_state.pwr_good_n   = pwr_good_n;
assign hw_state.wr_data.data = data_reg;
assign hw_state.write_type   = write_type_reg;

//----------------------------------------------------------------------------
// Output Registers:
//----------------------------------------------------------------------------
logic fme_fab_err_reg;

always_ff @(posedge clk)
begin : output_error_registers
   fme_fab_err_reg       <= fme_csr_fme_error0.fme_error0.partial_reconfig_fifo_parity_error; 
end : output_error_registers


//----------------------------------------------------------------------------
//  Masked Errors
//----------------------------------------------------------------------------
logic [63:0] ras_grnerr_masked;
logic [63:0] ras_bluerr_masked;
assign ras_grnerr_masked = fme_io.inp2cr_ras_grnerr & ~fme_csr_ras_nofat_error_mask.data;
assign ras_bluerr_masked = fme_io.inp2cr_ras_bluerr & ~fme_csr_ras_catfat_error_mask.data;


//----------------------------------------------------------------------------
// PBA = Pending Bit Array: Clearing Logic
//    Two clocks are needed to clear the bits.  Capture the RW1C writes to the 
//    error registers and forward the bit clears to the PBA/MSIX logic.
//----------------------------------------------------------------------------
logic [19:0] fme_sclr;
logic [19:0] fme0_sclr_sync, fme0_sclr_sync2;
logic [12:0] pcie0_sclr_sync, pcie0_sclr_sync2;
logic fme0_reg_wr, pcie0_reg_wr;
logic nonfat_clr_sync, nonfat_clr_sync2, nonfat_clr_negedge, nonfat_clr_negedge2; 
logic fat_clr_sync, fat_clr_sync2, fat_clr_negedge, fat_clr_negedge2;
always_ff @(posedge clk, negedge reset_n) 
begin 
   if (!reset_n) 
   begin 
      fme_sclr            <= 20'd0;
      fme0_reg_wr         <= 1'b0;
      pcie0_reg_wr        <= 1'b0;
      fme0_sclr_sync      <= '0;
      fme0_sclr_sync2     <= '0;
      pcie0_sclr_sync     <= '0;
      pcie0_sclr_sync2    <= '0;
      nonfat_clr_negedge  <= 1'b0;
      nonfat_clr_negedge2 <= 1'b0;
      nonfat_clr_sync     <= '0;
      nonfat_clr_sync2    <= '0;
      fat_clr_negedge     <= '0;
      fat_clr_negedge2    <= '0;
      fat_clr_sync        <= '0;
      fat_clr_sync2       <= '0;
   end 
   else 
   begin
      fme_sclr      <= data_reg[19:0];
      fme0_reg_wr   <= csr_write[FME_ERROR0[15:12]][FME_ERROR0[7:3]] & (wr_state[WRITE_COMPLETE_BIT]);
      pcie0_reg_wr  <= csr_write[PCIE0_ERROR[15:12]][PCIE0_ERROR[7:3]] & (wr_state[WRITE_COMPLETE_BIT]);

      fme0_sclr_sync   <= fme_sclr & {20{fme0_reg_wr}};
      fme0_sclr_sync2  <= fme0_sclr_sync;

      pcie0_sclr_sync  <= fme_sclr[12:0] & {13{pcie0_reg_wr}};
      pcie0_sclr_sync2 <= pcie0_sclr_sync;

      nonfat_clr_sync  <= |ras_grnerr_masked;
      nonfat_clr_sync2 <= nonfat_clr_sync;

      fat_clr_sync  <= |ras_bluerr_masked;
      fat_clr_sync2 <= fat_clr_sync;

      nonfat_clr_negedge  <= nonfat_clr_sync2  & ~nonfat_clr_sync;
      nonfat_clr_negedge2 <= nonfat_clr_negedge;

      fat_clr_negedge    <= fat_clr_sync2     & ~fat_clr_sync;
      fat_clr_negedge2   <= fat_clr_negedge;
   end
end

assign fme_io.cr2out_nonfat_sclr = nonfat_clr_negedge2 | nonfat_clr_negedge;
assign fme_io.cr2out_fat_sclr    = fat_clr_negedge2    | fat_clr_negedge;
assign fme_io.cr2out_fme_sclr    = fme0_sclr_sync2     | fme0_sclr_sync;
assign fme_io.cr2out_pcie0_sclr  = pcie0_sclr_sync2    | pcie0_sclr_sync;


//----------------------------------------------------------------------------
// Implementing First and Next Error registers (Sticky).
//----------------------------------------------------------------------------

logic [2:0]  err_hit;        // Indicates if one of the Error Registers got an error event.
logic [2:0]  err_hit_mask;   // Indicates what Error register was already captured in FIRST_ERROR register (one-cold).
logic [2:0]  err_hit_masked; // Indicates if one of the Error registers that are not masked got an error event.

logic [63:0] fme_ferr_comb;
logic [63:0] fme_nerr_comb;

logic ferr_lock;
logic nerr_lock;

logic [1:0] ferr_id = 2'b0;
logic [1:0] nerr_id = 2'b0;

assign err_hit_masked = err_hit & err_hit_mask;                             

always_comb
begin
   case (ferr_id) 
      2'h0: fme_ferr_comb = fme_csr_fme_error0.data;
      2'h1: fme_ferr_comb = fme_csr_pcie0_error.data;
      default: fme_ferr_comb = 64'b0;
   endcase

   case (nerr_id)
      2'h0: fme_nerr_comb = fme_csr_fme_error0.data;
      2'h1: fme_nerr_comb = fme_csr_pcie0_error.data;
      default: fme_nerr_comb = 64'b0;
   endcase
end

always_ff @(posedge clk)
begin
   err_hit <= { 1'b0,                                                             // Bit[2] Inactive
                1'b0,                                                             // Bit[1] Inactive
                (fme_io.inp2cr_fme_error[0] & ~fme_csr_fme_error_mask0.data[0])}; // Bit[0] FME Error
end

always @(posedge clk, negedge pwr_good_n)
begin
   if (!pwr_good_n)
   begin
      err_hit_mask<= 3'h7;
      ferr_lock   <= 1'b0;
      nerr_lock   <= 1'b0;
   end
   else
   begin
      if (!ferr_lock)
      begin
         ferr_lock <= 1'b1;
         casez (err_hit_masked)
         3'b??1: begin
            ferr_id <= 2'h0;
            err_hit_mask <= 3'b110;
         end
         3'b?10: begin
            ferr_id <= 2'h1;
            err_hit_mask <= 3'b101;
         end
         3'b100: begin
            ferr_id <= 2'h2;
            err_hit_mask <= 3'b011;
         end
         default: begin
            ferr_lock <= 1'b0;
            err_hit_mask <= 3'b111;
         end
         endcase
      end
      else
      begin
         ferr_lock <= |fme_ferr_comb;
         if (!nerr_lock)
         begin
            nerr_lock <= 1'b1;
            casez (err_hit_masked)
            3'b??1: begin
               nerr_id <= 2'h0;
            end
            3'b?10: begin
               nerr_id <= 2'h1;
            end
            3'b100: begin
               nerr_id <= 2'h2;
            end
            default: nerr_lock <= 1'b0;
            endcase
         end
         else
            nerr_lock <= |fme_nerr_comb;
      end
   end
end


//----------------------------------------------------------------------------
// Register Reset/Update Structure Overlays.
//----------------------------------------------------------------------------
// FME DFH ------------------------------------------------------------------------------------------------
assign fme_csr_fme_dfh_reset.data = fme_csr_fme_dfh_update.data;
assign fme_csr_fme_dfh_update.fme_dfh.feature_type    = 4'h4;
assign fme_csr_fme_dfh_update.fme_dfh.reserved        = {19{1'b0}};
assign fme_csr_fme_dfh_update.fme_dfh.end_of_list     = 1'b0;
assign fme_csr_fme_dfh_update.fme_dfh.next_dfh_offset = 24'h001000;
assign fme_csr_fme_dfh_update.fme_dfh.afu_maj_version = 4'h0;
assign fme_csr_fme_dfh_update.fme_dfh.corefim_version = 12'd0;
// ID & Utility Registers ---------------------------------------------------------------------------------
assign fme_csr_fme_afu_id_l_reset.data     = fme_csr_fme_afu_id_l_update.data;
assign fme_csr_fme_afu_id_l_update.data    = 64'h82FE_38F0_F9E1_7764;
assign fme_csr_fme_afu_id_h_reset.data     = fme_csr_fme_afu_id_h_update.data;
assign fme_csr_fme_afu_id_h_update.data    = 64'hBFAF_2AE9_4A52_46E3;
assign fme_csr_fme_next_afu_reset.data     = 64'h0000_0000_0000_0000;
assign fme_csr_fme_next_afu_update.data    = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_0020_reset.data       = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_0020_update.data      = 64'h0000_0000_0000_0000;
assign fme_csr_fme_scratchpad0_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_fme_scratchpad0_update.data = 64'h0000_0000_0000_0000;
// Fabric Capability---------------------------------------------------------------------------------------
assign fme_csr_fab_capability_reset.data = fme_csr_fab_capability_update.data;
assign fme_csr_fab_capability_update.fab_capability.reserved30     = {34{1'b0}};
assign fme_csr_fab_capability_update.fab_capability.addr_width     = 6'd20;
assign fme_csr_fab_capability_update.fab_capability.reserved20     = {4{1'b0}};
assign fme_csr_fab_capability_update.fab_capability.num_ports      = 3'd1;
assign fme_csr_fab_capability_update.fab_capability.reserved13     = {4{1'b0}};
assign fme_csr_fab_capability_update.fab_capability.pcie0_link     = 1'b1;
assign fme_csr_fab_capability_update.fab_capability.reserved8      = {4{1'b0}};
assign fme_csr_fab_capability_update.fab_capability.fabric_version = 8'd0;
// Port0---------------------------------------------------------------------------------------------------
assign fme_csr_port0_offset_reset.data = fme_csr_port0_offset_update.data;
assign fme_csr_port0_offset_update.port_offset.reserved61        = 3'b000;
assign fme_csr_port0_offset_update.port_offset.port_implemented  = (fme_csr_fab_capability.fab_capability.num_ports > 0) ? 1'b1 : 1'b0;
assign fme_csr_port0_offset_update.port_offset.reserved57        = 3'b000;
assign fme_csr_port0_offset_update.port_offset.decouple_port_csr = 1'b0;
assign fme_csr_port0_offset_update.port_offset.afu_access_ctrl   = 1'b0;
assign fme_csr_port0_offset_update.port_offset.reserved35        = {20{1'b0}};
assign fme_csr_port0_offset_update.port_offset.bar_id            = 3'd7; // PF BAR7 - WAS BAR2
assign fme_csr_port0_offset_update.port_offset.reserved24        = 8'h00;
assign fme_csr_port0_offset_update.port_offset.port_byte_offset  = 24'h000000;
// Port1---------------------------------------------------------------------------------------------------
assign fme_csr_port1_offset_reset.data = fme_csr_port1_offset_update.data;
assign fme_csr_port1_offset_update.port_offset.reserved61        = 3'b000;
assign fme_csr_port1_offset_update.port_offset.port_implemented  = (fme_csr_fab_capability.fab_capability.num_ports > 1) ? 1'b1 : 1'b0;
assign fme_csr_port1_offset_update.port_offset.reserved57        = 3'b000;
assign fme_csr_port1_offset_update.port_offset.decouple_port_csr = 1'b0;
assign fme_csr_port1_offset_update.port_offset.afu_access_ctrl   = 1'b0;
assign fme_csr_port1_offset_update.port_offset.reserved35        = {20{1'b0}};
assign fme_csr_port1_offset_update.port_offset.bar_id            = 3'd0; // PF BAR0 - WAS BAR2
assign fme_csr_port1_offset_update.port_offset.reserved24        = 8'h00;
assign fme_csr_port1_offset_update.port_offset.port_byte_offset  = 24'h080000;
// Port2---------------------------------------------------------------------------------------------------
assign fme_csr_port2_offset_reset.data = fme_csr_port2_offset_update.data;
assign fme_csr_port2_offset_update.port_offset.reserved61        = 3'b000;
assign fme_csr_port2_offset_update.port_offset.port_implemented  = (fme_csr_fab_capability.fab_capability.num_ports > 2) ? 1'b1 : 1'b0;
assign fme_csr_port2_offset_update.port_offset.reserved57        = 3'b000;
assign fme_csr_port2_offset_update.port_offset.decouple_port_csr = 1'b0;
assign fme_csr_port2_offset_update.port_offset.afu_access_ctrl   = 1'b0;
assign fme_csr_port2_offset_update.port_offset.reserved35        = {20{1'b0}};
assign fme_csr_port2_offset_update.port_offset.bar_id            = 3'd0; // PF BAR0 - WAS BAR2
assign fme_csr_port2_offset_update.port_offset.reserved24        = 8'h00;
assign fme_csr_port2_offset_update.port_offset.port_byte_offset  = 24'h100000;
// Port3---------------------------------------------------------------------------------------------------
assign fme_csr_port3_offset_reset.data = fme_csr_port3_offset_update.data;
assign fme_csr_port3_offset_update.port_offset.reserved61        = 3'b000;
assign fme_csr_port3_offset_update.port_offset.port_implemented  = (fme_csr_fab_capability.fab_capability.num_ports > 3) ? 1'b1 : 1'b0;
assign fme_csr_port3_offset_update.port_offset.reserved57        = 3'b000;
assign fme_csr_port3_offset_update.port_offset.decouple_port_csr = 1'b0;
assign fme_csr_port3_offset_update.port_offset.afu_access_ctrl   = 1'b0;
assign fme_csr_port3_offset_update.port_offset.reserved35        = {20{1'b0}};
assign fme_csr_port3_offset_update.port_offset.bar_id            = 3'd0; // PF BAR0 - WAS BAR2
assign fme_csr_port3_offset_update.port_offset.reserved24        = 8'h00;
assign fme_csr_port3_offset_update.port_offset.port_byte_offset  = 24'h180000;
// Fabric Status-------------------------------------------------------------------------------------------
assign fme_csr_fab_status_reset.data = fme_csr_fab_status_update.data;
assign fme_csr_fab_status_update.fab_status.reserved9           = {55{1'b0}};
assign fme_csr_fab_status_update.fab_status.pcie0_link_status   = 1'b0; // Unused.  Please consult the PCIe CSR Block for this information.
assign fme_csr_fab_status_update.fab_status.reserved0           = {8{1'b0}};
// ID Registers--------------------------------------------------------------------------------------------
assign fme_csr_bitstream_id_reset.data    = fme_id_regs[BITSTREAM_ID_IDX];
assign fme_csr_bitstream_id_update.data   = fme_id_regs[BITSTREAM_ID_IDX];
assign fme_csr_bitstream_md_reset.data    = fme_id_regs[BITSTREAM_MD_IDX];
assign fme_csr_bitstream_md_update.data   = fme_id_regs[BITSTREAM_MD_IDX];
assign fme_csr_bitstream_info_reset.data  = fme_id_regs[BITSTREAM_INFO_IDX];
assign fme_csr_bitstream_info_update.data = fme_id_regs[BITSTREAM_INFO_IDX];
// Thermal Management DFH----------------------------------------------------------------------------------
assign fme_csr_therm_mngm_dfh_reset.data = fme_csr_therm_mngm_dfh_update.data; 
assign fme_csr_therm_mngm_dfh_update.dfh.feature_type    = 4'h3; 
assign fme_csr_therm_mngm_dfh_update.dfh.reserved        = {19{1'b0}}; 
assign fme_csr_therm_mngm_dfh_update.dfh.end_of_list     = 1'b0;
assign fme_csr_therm_mngm_dfh_update.dfh.next_dfh_offset = 24'h002000;
assign fme_csr_therm_mngm_dfh_update.dfh.feature_rev     = 4'h0; 
assign fme_csr_therm_mngm_dfh_update.dfh.feature_id      = 12'h001; 
// Temperature Threshold-----------------------------------------------------------------------------------
assign fme_csr_tmp_threshold_reset.data = fme_csr_tmp_threshold_update.data;
assign fme_csr_tmp_threshold_update.tmp_threshold.reserved45             = {19{1'b0}};
assign fme_csr_tmp_threshold_update.tmp_threshold.threshold_policy       = 1'b0;
assign fme_csr_tmp_threshold_update.tmp_threshold.reserved42             = 2'b00;
assign fme_csr_tmp_threshold_update.tmp_threshold.val_mode_therm         = 1'b0;
assign fme_csr_tmp_threshold_update.tmp_threshold.reserved36             = 5'b00000;
assign fme_csr_tmp_threshold_update.tmp_threshold.therm_trip_status      = 1'b0;
assign fme_csr_tmp_threshold_update.tmp_threshold.reserved34             = 1'b0;
assign fme_csr_tmp_threshold_update.tmp_threshold.threshold2_status      = 1'b0;
assign fme_csr_tmp_threshold_update.tmp_threshold.threshold1_status      = 1'b0;
assign fme_csr_tmp_threshold_update.tmp_threshold.reserved31             = 1'b0;
assign fme_csr_tmp_threshold_update.tmp_threshold.therm_trip_threshold   = 7'h5D;
assign fme_csr_tmp_threshold_update.tmp_threshold.reserved16             = 8'h00;
assign fme_csr_tmp_threshold_update.tmp_threshold.temp_threshold2_enable = 1'b0;
assign fme_csr_tmp_threshold_update.tmp_threshold.temp_threshold2        = 7'h5F;
assign fme_csr_tmp_threshold_update.tmp_threshold.temp_threshold1_enable = 1'b0;
assign fme_csr_tmp_threshold_update.tmp_threshold.temp_threshold1        = 7'h5A;
// Thermal Sensor FMT1-------------------------------------------------------------------------------------
assign fme_csr_tmp_rdsensor_fmt1_reset.data = fme_csr_tmp_rdsensor_fmt1_update.data;
assign fme_csr_tmp_rdsensor_fmt1_update.tmp_rdsensor_fmt1.reserved42          = {22{1'b0}};
assign fme_csr_tmp_rdsensor_fmt1_update.tmp_rdsensor_fmt1.temp_thermal_sensor = {10{1'b0}};
assign fme_csr_tmp_rdsensor_fmt1_update.tmp_rdsensor_fmt1.reserved25          = {7{1'b0}};
assign fme_csr_tmp_rdsensor_fmt1_update.tmp_rdsensor_fmt1.temp_valid          = 1'b0;
assign fme_csr_tmp_rdsensor_fmt1_update.tmp_rdsensor_fmt1.numb_temp_reads     = {16{1'b0}};
assign fme_csr_tmp_rdsensor_fmt1_update.tmp_rdsensor_fmt1.reserved7           = 1'b0;
assign fme_csr_tmp_rdsensor_fmt1_update.tmp_rdsensor_fmt1.fpga_temp           = {7{1'b0}};
// Thermal Sensor FMT2-------------------------------------------------------------------------------------
assign fme_csr_tmp_rdsensor_fmt2_reset.data         = 64'h0000_0000_0000_0000;
assign fme_csr_tmp_rdsensor_fmt2_update.data        = 64'h0000_0000_0000_0000;
assign fme_csr_tmp_threshold_capability_reset.data  = 64'h0000_0000_0000_0001;
assign fme_csr_tmp_threshold_capability_update.data = 64'h0000_0000_0000_0001;
// Global Performance DFH----------------------------------------------------------------------------------
assign fme_csr_glbl_perf_dfh_reset.data = fme_csr_glbl_perf_dfh_update.data; 
assign fme_csr_glbl_perf_dfh_update.dfh.feature_type    = 4'h3; 
assign fme_csr_glbl_perf_dfh_update.dfh.reserved        = {19{1'b0}}; 
assign fme_csr_glbl_perf_dfh_update.dfh.end_of_list     = 1'b0;
assign fme_csr_glbl_perf_dfh_update.dfh.next_dfh_offset = 24'h001000;
assign fme_csr_glbl_perf_dfh_update.dfh.feature_rev     = 4'h0; 
assign fme_csr_glbl_perf_dfh_update.dfh.feature_id      = 12'h007; 
// Dummy Registers To Fill Addressing Gap in Register Space, Preventing Bus Exception in Valid Range-------
assign fme_csr_dummy_3008_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_3008_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_3010_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_3010_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_3018_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_3018_update.data = 64'h0000_0000_0000_0000;
// Performance Monitor Registers---------------------------------------------------------------------------
assign fme_csr_fpmon_fab_ctl_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_fpmon_fab_ctl_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_fpmon_fab_ctr_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_fpmon_fab_ctr_update.fpmon_fab_ctr.fabric_event_code    = {4{1'b0}};
assign fme_csr_fpmon_fab_ctr_update.fpmon_fab_ctr.fabric_event_counter = {60{1'b0}};
assign fme_csr_fpmon_clk_ctr_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_fpmon_clk_ctr_update.data = 64'h0000_0000_0000_0000;
// Global Error DFH----------------------------------------------------------------------------------------
assign fme_csr_glbl_error_dfh_reset.data = fme_csr_glbl_error_dfh_update.data; 
assign fme_csr_glbl_error_dfh_update.dfh.feature_type    = 4'h3; 
assign fme_csr_glbl_error_dfh_update.dfh.reserved        = {19{1'b0}}; 
assign fme_csr_glbl_error_dfh_update.dfh.end_of_list     = 1'b0;
assign fme_csr_glbl_error_dfh_update.dfh.next_dfh_offset = NEXT_DFH_OFFSET - GLBL_ERROR_DFH;
assign fme_csr_glbl_error_dfh_update.dfh.feature_rev     = 4'h1; 
assign fme_csr_glbl_error_dfh_update.dfh.feature_id      = 12'h004; 
// Error Registers and Masks-------------------------------------------------------------------------------
// FME Error Register and Mask-----------------------------------------------------------------------------
assign fme_csr_fme_error_mask0_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_fme_error_mask0_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_fme_error0_reset.data       = 64'h0000_0000_0000_0000;
assign fme_csr_fme_error0_update.fme_error0.reserved1                          = {63{1'b0}};
assign fme_csr_fme_error0_update.fme_error0.partial_reconfig_fifo_parity_error = fme_io.inp2cr_fme_error[0];
// PCIe Error Register and Mask---------------------------------------------------------------------------
assign fme_csr_pcie0_error_mask_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_pcie0_error_mask_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_pcie0_error_reset.data       = 64'h0000_0000_0000_0000;
assign fme_csr_pcie0_error_update.data      = 64'h0000_0000_0000_0000;
// Dummy Registers To Fill Addressing Gap in Register Space, Preventing Bus Exception in Valid Range-------
assign fme_csr_dummy_4028_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_4028_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_4030_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_dummy_4030_update.data = 64'h0000_0000_0000_0000;
// FME First and Next Error Registers----------------------------------------------------------------------
assign fme_csr_fme_first_error_reset.data = fme_csr_fme_first_error_update.data;
assign fme_csr_fme_first_error_update.fme_first_next_error.reserved         = 2'b00; 
assign fme_csr_fme_first_error_update.fme_first_next_error.error_reg_id     = ferr_id;
assign fme_csr_fme_first_error_update.fme_first_next_error.error_reg_status = fme_ferr_comb[59:0];
assign fme_csr_fme_next_error_reset.data  = fme_csr_fme_next_error_update.data;
assign fme_csr_fme_next_error_update.fme_first_next_error.reserved          = 2'b00; 
assign fme_csr_fme_next_error_update.fme_first_next_error.error_reg_id      = nerr_id;
assign fme_csr_fme_next_error_update.fme_first_next_error.error_reg_status  = fme_nerr_comb[59:0];
// RAS Error Registers-------------------------------------------------------------------------------------
// Non-Fatal Error Registers-------------------------------------------------------------------------------------
assign fme_csr_ras_nofat_error_mask_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_ras_nofat_error_mask_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_ras_nofat_error_reset.data       = fme_csr_ras_nofat_error_update.data;
assign fme_csr_ras_nofat_error_update.ras_nofat_error.reserved7              = {57{1'b0}};
assign fme_csr_ras_nofat_error_update.ras_nofat_error.injected_warning_error = ras_grnerr_masked[6];
assign fme_csr_ras_nofat_error_update.ras_nofat_error.afu_access_mode_error  = ras_grnerr_masked[5];
assign fme_csr_ras_nofat_error_update.ras_nofat_error.reserved4              = 1'b0;
assign fme_csr_ras_nofat_error_update.ras_nofat_error.port_fatal_error       = ras_grnerr_masked[3];
assign fme_csr_ras_nofat_error_update.ras_nofat_error.pcie_error             = ras_grnerr_masked[2];
assign fme_csr_ras_nofat_error_update.ras_nofat_error.reserved0              = {2{1'b0}};
// Catastrophic Error Registers-------------------------------------------------------------------------------------
assign fme_csr_ras_catfat_error_mask_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_ras_catfat_error_mask_update.data = 64'h0000_0000_0000_0000;
assign fme_csr_ras_catfat_error_reset.data       = fme_csr_ras_catfat_error_update.data;
assign fme_csr_ras_catfat_error_update.ras_catfat_error.reserved12            = {52{1'b0}};
assign fme_csr_ras_catfat_error_update.ras_catfat_error.injected_catast_error = ras_bluerr_masked[11];
assign fme_csr_ras_catfat_error_update.ras_catfat_error.reserved10            = 1'b0;
assign fme_csr_ras_catfat_error_update.ras_catfat_error.crc_catast_error      = ras_bluerr_masked[9];
assign fme_csr_ras_catfat_error_update.ras_catfat_error.injected_fatal_error  = ras_bluerr_masked[8];
assign fme_csr_ras_catfat_error_update.ras_catfat_error.pcie_poison_error     = ras_bluerr_masked[7];
assign fme_csr_ras_catfat_error_update.ras_catfat_error.fabric_fatal_error    = ras_bluerr_masked[6];
assign fme_csr_ras_catfat_error_update.ras_catfat_error.reserved0             = {6{1'b0}};
// RAS Error Injection Register-------------------------------------------------------------------------------------
assign fme_csr_ras_error_inj_reset.data  = 64'h0000_0000_0000_0000;
assign fme_csr_ras_error_inj_update.data = 64'h0000_0000_0000_0000;
// Global Error Capability Register---------------------------------------------------------------------------------
assign fme_csr_glbl_error_capability_reset.data  = 64'h0000_0000_0000_000D;
assign fme_csr_glbl_error_capability_update.data = 64'h0000_0000_0000_000D;


//----------------------------------------------------------------------------
// Register Output Breakout Structure Overlays/Maps.
//----------------------------------------------------------------------------
assign fme_csr_fab_capability.data = csr_reg[FAB_CAPABILITY  [15:12]][FAB_CAPABILITY  [7:3]];
assign fme_csr_port0_offset.data   = csr_reg[PORT0_OFFSET    [15:12]][PORT0_OFFSET    [7:3]];
assign fme_csr_port1_offset.data   = csr_reg[PORT1_OFFSET    [15:12]][PORT1_OFFSET    [7:3]];
assign fme_csr_port2_offset.data   = csr_reg[PORT2_OFFSET    [15:12]][PORT2_OFFSET    [7:3]];
assign fme_csr_port3_offset.data   = csr_reg[PORT3_OFFSET    [15:12]][PORT3_OFFSET    [7:3]];
assign fme_csr_tmp_threshold.data  = csr_reg[TMP_THRESHOLD   [15:12]][TMP_THRESHOLD   [7:3]];
assign fme_csr_fpmon_fab_ctl.data  = csr_reg[FPMON_FAB_CTL   [15:12]][FPMON_FAB_CTL   [7:3]];
assign fme_csr_ras_catfat_error_mask.data = csr_reg[RAS_CATFAT_ERROR_MASK[15:12]][RAS_CATFAT_ERROR_MASK[7:3]];
assign fme_csr_ras_catfat_error.data      = csr_reg[RAS_CATFAT_ERROR     [15:12]][RAS_CATFAT_ERROR     [7:3]];
assign fme_csr_ras_nofat_error_mask.data  = csr_reg[RAS_NOFAT_ERROR_MASK [15:12]][RAS_NOFAT_ERROR_MASK [7:3]];
assign fme_csr_ras_nofat_error.data       = csr_reg[RAS_NOFAT_ERROR      [15:12]][RAS_NOFAT_ERROR      [7:3]];
assign fme_csr_ras_error_inj.data         = csr_reg[RAS_ERROR_INJ        [15:12]][RAS_ERROR_INJ        [7:3]];

assign fme_csr_fme_error_mask0.data  = csr_reg[FME_ERROR_MASK0 [15:12]][FME_ERROR_MASK0 [7:3]]; 
assign fme_csr_fme_error0.data       = csr_reg[FME_ERROR0      [15:12]][FME_ERROR0      [7:3]]; 
assign fme_csr_pcie0_error_mask.data = csr_reg[PCIE0_ERROR_MASK[15:12]][PCIE0_ERROR_MASK[7:3]]; 
assign fme_csr_pcie0_error.data      = csr_reg[PCIE0_ERROR     [15:12]][PCIE0_ERROR     [7:3]]; 

//----------------------------------------------------------------------------
// FME Outputs into the FME Interface for distribution.
//----------------------------------------------------------------------------
assign fme_io.cr2out_port0_offset  = fme_csr_port0_offset.data;
assign fme_io.cr2out_port1_offset  = fme_csr_port1_offset.data;
assign fme_io.cr2out_port2_offset  = fme_csr_port2_offset.data;
assign fme_io.cr2out_port3_offset  = fme_csr_port3_offset.data;
assign fme_io.cr2out_gbsErrMask    = fme_csr_ras_nofat_error_mask.data;
assign fme_io.cr2out_ras_grnerr    = fme_csr_ras_nofat_error.data;
assign fme_io.cr2out_ras_bluerr    = fme_csr_ras_catfat_error.data;
assign fme_io.cr2out_catErrInj     = fme_csr_ras_error_inj.ras_error_inj.catast_error;
assign fme_io.cr2out_fatErrInj     = fme_csr_ras_error_inj.ras_error_inj.fatal_error;
assign fme_io.cr2out_warnErrInj    = fme_csr_ras_error_inj.ras_error_inj.nofatal_error;
assign fme_io.cr2out_CfgRdHit      = cfg_rd_hit;
assign fme_io.cr2out_fme_fab_err   = fme_fab_err_reg;



//----------------------------------------------------------------------------
// Register Update Logic using "update_reg" & "update_error_reg" functions in 
// the "ofs_csr_pkg.sv" SystemVerilog package.  Function inputs are "named" 
// for ease of understanding the use.
//    - Register bit attributes are set in array input above.  Attribute
//        functions are defined in SAS.
//    - Reset Value is appied at reset except for RO, *D, and Rsvd{Z}.
//    - Update Value is used as status bit updates for RO, RW1C*, and RW1S*.
//    - Current Value is used to determine next register value.  This must be
//        done due to scoping rules using SystemVerilog package.
//    - "Write" is the decoded write signal for that particular register.
//    - State is a hardware state structure to pass input signals to 
//        "update_reg" function.  See code above.
//----------------------------------------------------------------------------
always_ff @(posedge clk)
begin : update_reg_seq

   csr_reg[FME_DFH[15:12]][FME_DFH[7:3]]   <= update_reg(.attr(fme_dfh_attr.data),
                                                         .reg_reset_val( fme_csr_fme_dfh_reset.data),
                                                         .reg_update_val(fme_csr_fme_dfh_update.data),
                                                         .reg_current_val(csr_reg[FME_DFH[15:12]][FME_DFH[7:3]]),
                                                         .write(        csr_write[FME_DFH[15:12]][FME_DFH[7:3]]),
                                                         .state(hw_state)
                                                         );

   csr_reg[FME_AFU_ID_L[15:12]][FME_AFU_ID_L[7:3]]  <= update_reg(.attr(fme_afu_id_l_attr.data),
                                                                  .reg_reset_val( fme_csr_fme_afu_id_l_reset.data),
                                                                  .reg_update_val(fme_csr_fme_afu_id_l_update.data),
                                                                  .reg_current_val(csr_reg[FME_AFU_ID_L[15:12]][FME_AFU_ID_L[7:3]]),
                                                                  .write(        csr_write[FME_AFU_ID_L[15:12]][FME_AFU_ID_L[7:3]]),
                                                                  .state(hw_state)
                                                                  );

   csr_reg[FME_AFU_ID_H[15:12]][FME_AFU_ID_H[7:3]]  <= update_reg(.attr(fme_afu_id_h_attr.data),
                                                                  .reg_reset_val( fme_csr_fme_afu_id_h_reset.data),
                                                                  .reg_update_val(fme_csr_fme_afu_id_h_update.data),
                                                                  .reg_current_val(csr_reg[FME_AFU_ID_H[15:12]][FME_AFU_ID_H[7:3]]),
                                                                  .write(        csr_write[FME_AFU_ID_H[15:12]][FME_AFU_ID_H[7:3]]),
                                                                  .state(hw_state)
                                                                  );

   csr_reg[FME_NEXT_AFU[15:12]][FME_NEXT_AFU[7:3]]  <= update_reg(.attr(fme_next_afu_attr.data),
                                                                  .reg_reset_val( fme_csr_fme_next_afu_reset.data),
                                                                  .reg_update_val(fme_csr_fme_next_afu_update.data),
                                                                  .reg_current_val(csr_reg[FME_NEXT_AFU[15:12]][FME_NEXT_AFU[7:3]]),
                                                                  .write(        csr_write[FME_NEXT_AFU[15:12]][FME_NEXT_AFU[7:3]]),
                                                                  .state(hw_state)
                                                                  );

   csr_reg[DUMMY_0020[15:12]][DUMMY_0020[7:3]]   <= update_reg(.attr(dummy_0020_attr.data),
                                                               .reg_reset_val( fme_csr_dummy_0020_reset.data),
                                                               .reg_update_val(fme_csr_dummy_0020_update.data),
                                                               .reg_current_val(csr_reg[DUMMY_0020[15:12]][DUMMY_0020[7:3]]),
                                                               .write(        csr_write[DUMMY_0020[15:12]][DUMMY_0020[7:3]]),
                                                               .state(hw_state)
                                                               );

   csr_reg[FME_SCRATCHPAD0[15:12]][FME_SCRATCHPAD0[7:3]]  <= update_reg(.attr(fme_scratchpad0_attr.data),
                                                                        .reg_reset_val( fme_csr_fme_scratchpad0_reset.data),
                                                                        .reg_update_val(fme_csr_fme_scratchpad0_update.data),
                                                                        .reg_current_val(csr_reg[FME_SCRATCHPAD0[15:12]][FME_SCRATCHPAD0[7:3]]),
                                                                        .write(        csr_write[FME_SCRATCHPAD0[15:12]][FME_SCRATCHPAD0[7:3]]),
                                                                        .state(hw_state)
                                                                        );

   csr_reg[FAB_CAPABILITY[15:12]][FAB_CAPABILITY[7:3]] <= update_reg(.attr(fab_capability_attr.data),
                                                                     .reg_reset_val( fme_csr_fab_capability_reset.data),
                                                                     .reg_update_val(fme_csr_fab_capability_update.data),
                                                                     .reg_current_val(csr_reg[FAB_CAPABILITY[15:12]][FAB_CAPABILITY[7:3]]),
                                                                     .write(        csr_write[FAB_CAPABILITY[15:12]][FAB_CAPABILITY[7:3]]),
                                                                     .state(hw_state)
                                                                     );

   csr_reg[PORT0_OFFSET[15:12]][PORT0_OFFSET[7:3]]  <= update_reg(.attr(port0_offset_attr.data),
                                                                  .reg_reset_val( fme_csr_port0_offset_reset.data),
                                                                  .reg_update_val(fme_csr_port0_offset_update.data),
                                                                  .reg_current_val(csr_reg[PORT0_OFFSET[15:12]][PORT0_OFFSET[7:3]]),
                                                                  .write(        csr_write[PORT0_OFFSET[15:12]][PORT0_OFFSET[7:3]]),
                                                                  .state(hw_state)
                                                                  );

   csr_reg[PORT1_OFFSET[15:12]][PORT1_OFFSET[7:3]]  <= update_reg(.attr(port1_offset_attr.data),
                                                                  .reg_reset_val( fme_csr_port1_offset_reset.data),
                                                                  .reg_update_val(fme_csr_port1_offset_update.data),
                                                                  .reg_current_val(csr_reg[PORT1_OFFSET[15:12]][PORT1_OFFSET[7:3]]),
                                                                  .write(        csr_write[PORT1_OFFSET[15:12]][PORT1_OFFSET[7:3]]),
                                                                  .state(hw_state)
                                                                  );

   csr_reg[PORT2_OFFSET[15:12]][PORT2_OFFSET[7:3]]  <= update_reg(.attr(port2_offset_attr.data),
                                                                  .reg_reset_val( fme_csr_port2_offset_reset.data),
                                                                  .reg_update_val(fme_csr_port2_offset_update.data),
                                                                  .reg_current_val(csr_reg[PORT2_OFFSET[15:12]][PORT2_OFFSET[7:3]]),
                                                                  .write(        csr_write[PORT2_OFFSET[15:12]][PORT2_OFFSET[7:3]]),
                                                                  .state(hw_state)
                                                                  );

   csr_reg[PORT3_OFFSET[15:12]][PORT3_OFFSET[7:3]]  <= update_reg(.attr(port3_offset_attr.data),
                                                                  .reg_reset_val( fme_csr_port3_offset_reset.data),
                                                                  .reg_update_val(fme_csr_port3_offset_update.data),
                                                                  .reg_current_val(csr_reg[PORT3_OFFSET[15:12]][PORT3_OFFSET[7:3]]),
                                                                  .write(        csr_write[PORT3_OFFSET[15:12]][PORT3_OFFSET[7:3]]),
                                                                  .state(hw_state)
                                                                  );

   csr_reg[FAB_STATUS[15:12]][FAB_STATUS[7:3]]   <= update_reg(.attr(fab_status_attr.data),
                                                               .reg_reset_val( fme_csr_fab_status_reset.data),
                                                               .reg_update_val(fme_csr_fab_status_update.data),
                                                               .reg_current_val(csr_reg[FAB_STATUS[15:12]][FAB_STATUS[7:3]]),
                                                               .write(        csr_write[FAB_STATUS[15:12]][FAB_STATUS[7:3]]),
                                                               .state(hw_state)
                                                               );

   csr_reg[BITSTREAM_ID[15:12]][BITSTREAM_ID[7:3]]  <= update_reg(.attr(bitstream_id_attr.data),
                                                                  .reg_reset_val( fme_csr_bitstream_id_reset.data),
                                                                  .reg_update_val(fme_csr_bitstream_id_update.data),
                                                                  .reg_current_val(csr_reg[BITSTREAM_ID[15:12]][BITSTREAM_ID[7:3]]),
                                                                  .write(        csr_write[BITSTREAM_ID[15:12]][BITSTREAM_ID[7:3]]),
                                                                  .state(hw_state)
                                                                  );

   csr_reg[BITSTREAM_MD[15:12]][BITSTREAM_MD[7:3]]  <= update_reg(.attr(bitstream_md_attr.data),
                                                                  .reg_reset_val( fme_csr_bitstream_md_reset.data),
                                                                  .reg_update_val(fme_csr_bitstream_md_update.data),
                                                                  .reg_current_val(csr_reg[BITSTREAM_MD[15:12]][BITSTREAM_MD[7:3]]),
                                                                  .write(        csr_write[BITSTREAM_MD[15:12]][BITSTREAM_MD[7:3]]),
                                                                  .state(hw_state)
                                                                  );

   csr_reg[BITSTREAM_INFO[15:12]][BITSTREAM_INFO[7:3]]  <= update_reg(.attr(bitstream_info_attr.data),
                                                                  .reg_reset_val( fme_csr_bitstream_info_reset.data),
                                                                  .reg_update_val(fme_csr_bitstream_info_update.data),
                                                                  .reg_current_val(csr_reg[BITSTREAM_INFO[15:12]][BITSTREAM_INFO[7:3]]),
                                                                  .write(        csr_write[BITSTREAM_INFO[15:12]][BITSTREAM_INFO[7:3]]),
                                                                  .state(hw_state)
                                                                  );

   csr_reg[THERM_MNGM_DFH[15:12]][THERM_MNGM_DFH[7:3]] <= update_reg(.attr(therm_mngm_dfh_attr.data),
                                                                     .reg_reset_val( fme_csr_therm_mngm_dfh_reset.data),
                                                                     .reg_update_val(fme_csr_therm_mngm_dfh_update.data),
                                                                     .reg_current_val(csr_reg[THERM_MNGM_DFH[15:12]][THERM_MNGM_DFH[7:3]]),
                                                                     .write(        csr_write[THERM_MNGM_DFH[15:12]][THERM_MNGM_DFH[7:3]]),
                                                                     .state(hw_state)
                                                                     );

   csr_reg[TMP_THRESHOLD[15:12]][TMP_THRESHOLD[7:3]]   <= update_reg(.attr(tmp_threshold_attr.data),
                                                                     .reg_reset_val( fme_csr_tmp_threshold_reset.data),
                                                                     .reg_update_val(fme_csr_tmp_threshold_update.data),
                                                                     .reg_current_val(csr_reg[TMP_THRESHOLD[15:12]][TMP_THRESHOLD[7:3]]),
                                                                     .write(        csr_write[TMP_THRESHOLD[15:12]][TMP_THRESHOLD[7:3]]),
                                                                     .state(hw_state)
                                                                     );

   csr_reg[TMP_RDSENSOR_FMT1[15:12]][TMP_RDSENSOR_FMT1[7:3]] <= update_reg(.attr(tmp_rdsensor_fmt1_attr.data),
                                                                           .reg_reset_val( fme_csr_tmp_rdsensor_fmt1_reset.data),
                                                                           .reg_update_val(fme_csr_tmp_rdsensor_fmt1_update.data),
                                                                           .reg_current_val(csr_reg[TMP_RDSENSOR_FMT1[15:12]][TMP_RDSENSOR_FMT1[7:3]]),
                                                                           .write(        csr_write[TMP_RDSENSOR_FMT1[15:12]][TMP_RDSENSOR_FMT1[7:3]]),
                                                                           .state(hw_state)
                                                                           );

   csr_reg[TMP_RDSENSOR_FMT2[15:12]][TMP_RDSENSOR_FMT2[7:3]] <= update_reg(.attr(tmp_rdsensor_fmt2_attr.data),
                                                                           .reg_reset_val( fme_csr_tmp_rdsensor_fmt2_reset.data),
                                                                           .reg_update_val(fme_csr_tmp_rdsensor_fmt2_update.data),
                                                                           .reg_current_val(csr_reg[TMP_RDSENSOR_FMT2[15:12]][TMP_RDSENSOR_FMT2[7:3]]),
                                                                           .write(        csr_write[TMP_RDSENSOR_FMT2[15:12]][TMP_RDSENSOR_FMT2[7:3]]),
                                                                           .state(hw_state)
                                                                           );

   csr_reg[TMP_THRESHOLD_CAPABILITY[15:12]][TMP_THRESHOLD_CAPABILITY[7:3]]  <= update_reg(.attr(tmp_threshold_capability_attr.data),
                                                                                          .reg_reset_val( fme_csr_tmp_threshold_capability_reset.data),
                                                                                          .reg_update_val(fme_csr_tmp_threshold_capability_update.data),
                                                                                          .reg_current_val(csr_reg[TMP_THRESHOLD_CAPABILITY[15:12]][TMP_THRESHOLD_CAPABILITY[7:3]]),
                                                                                          .write(        csr_write[TMP_THRESHOLD_CAPABILITY[15:12]][TMP_THRESHOLD_CAPABILITY[7:3]]),
                                                                                          .state(hw_state)
                                                                                          );

   csr_reg[GLBL_PERF_DFH[15:12]][GLBL_PERF_DFH[7:3]]   <= update_reg(.attr(glbl_perf_dfh_attr.data),
                                                                     .reg_reset_val( fme_csr_glbl_perf_dfh_reset.data),
                                                                     .reg_update_val(fme_csr_glbl_perf_dfh_update.data),
                                                                     .reg_current_val(csr_reg[GLBL_PERF_DFH[15:12]][GLBL_PERF_DFH[7:3]]),
                                                                     .write(        csr_write[GLBL_PERF_DFH[15:12]][GLBL_PERF_DFH[7:3]]),
                                                                     .state(hw_state)
                                                                     );

   csr_reg[DUMMY_3008[15:12]][DUMMY_3008[7:3]]   <= update_reg(.attr(dummy_3008_attr.data),
                                                               .reg_reset_val( fme_csr_dummy_3008_reset.data),
                                                               .reg_update_val(fme_csr_dummy_3008_update.data),
                                                               .reg_current_val(csr_reg[DUMMY_3008[15:12]][DUMMY_3008[7:3]]),
                                                               .write(        csr_write[DUMMY_3008[15:12]][DUMMY_3008[7:3]]),
                                                               .state(hw_state)
                                                               );

   csr_reg[DUMMY_3010[15:12]][DUMMY_3010[7:3]]   <= update_reg(.attr(dummy_3010_attr.data),
                                                               .reg_reset_val( fme_csr_dummy_3010_reset.data),
                                                               .reg_update_val(fme_csr_dummy_3010_update.data),
                                                               .reg_current_val(csr_reg[DUMMY_3010[15:12]][DUMMY_3010[7:3]]),
                                                               .write(        csr_write[DUMMY_3010[15:12]][DUMMY_3010[7:3]]),
                                                               .state(hw_state)
                                                               );

   csr_reg[DUMMY_3018[15:12]][DUMMY_3018[7:3]]   <= update_reg(.attr(dummy_3018_attr.data),
                                                               .reg_reset_val( fme_csr_dummy_3018_reset.data),
                                                               .reg_update_val(fme_csr_dummy_3018_update.data),
                                                               .reg_current_val(csr_reg[DUMMY_3018[15:12]][DUMMY_3018[7:3]]),
                                                               .write(        csr_write[DUMMY_3018[15:12]][DUMMY_3018[7:3]]),
                                                               .state(hw_state)
                                                               );

   csr_reg[FPMON_FAB_CTL[15:12]][FPMON_FAB_CTL[7:3]]   <= update_reg(.attr(fpmon_fab_ctl_attr.data),
                                                                     .reg_reset_val( fme_csr_fpmon_fab_ctl_reset.data),
                                                                     .reg_update_val(fme_csr_fpmon_fab_ctl_update.data),
                                                                     .reg_current_val(csr_reg[FPMON_FAB_CTL[15:12]][FPMON_FAB_CTL[7:3]]),
                                                                     .write(        csr_write[FPMON_FAB_CTL[15:12]][FPMON_FAB_CTL[7:3]]),
                                                                     .state(hw_state)
                                                                     );

   csr_reg[FPMON_FAB_CTR[15:12]][FPMON_FAB_CTR[7:3]]   <= update_reg(.attr(fpmon_fab_ctr_attr.data),
                                                                     .reg_reset_val( fme_csr_fpmon_fab_ctr_reset.data),
                                                                     .reg_update_val(fme_csr_fpmon_fab_ctr_update.data),
                                                                     .reg_current_val(csr_reg[FPMON_FAB_CTR[15:12]][FPMON_FAB_CTR[7:3]]),
                                                                     .write(        csr_write[FPMON_FAB_CTR[15:12]][FPMON_FAB_CTR[7:3]]),
                                                                     .state(hw_state)
                                                                     );

   csr_reg[FPMON_CLK_CTR[15:12]][FPMON_CLK_CTR[7:3]]   <= update_reg(.attr(fpmon_clk_ctr_attr.data),
                                                                     .reg_reset_val( fme_csr_fpmon_clk_ctr_reset.data),
                                                                     .reg_update_val(fme_csr_fpmon_clk_ctr_update.data),
                                                                     .reg_current_val(csr_reg[FPMON_CLK_CTR[15:12]][FPMON_CLK_CTR[7:3]]),
                                                                     .write(        csr_write[FPMON_CLK_CTR[15:12]][FPMON_CLK_CTR[7:3]]),
                                                                     .state(hw_state)
                                                                     );

   csr_reg[GLBL_ERROR_DFH[15:12]][GLBL_ERROR_DFH[7:3]] <= update_reg(.attr(glbl_error_dfh_attr.data),
                                                                     .reg_reset_val( fme_csr_glbl_error_dfh_reset.data),
                                                                     .reg_update_val(fme_csr_glbl_error_dfh_update.data),
                                                                     .reg_current_val(csr_reg[GLBL_ERROR_DFH[15:12]][GLBL_ERROR_DFH[7:3]]),
                                                                     .write(        csr_write[GLBL_ERROR_DFH[15:12]][GLBL_ERROR_DFH[7:3]]),
                                                                     .state(hw_state)
                                                                     );

   csr_reg[FME_ERROR_MASK0[15:12]][FME_ERROR_MASK0[7:3]]  <= update_reg(.attr(fme_error_mask0_attr.data),
                                                                        .reg_reset_val( fme_csr_fme_error_mask0_reset.data),
                                                                        .reg_update_val(fme_csr_fme_error_mask0_update.data),
                                                                        .reg_current_val(csr_reg[FME_ERROR_MASK0[15:12]][FME_ERROR_MASK0[7:3]]),
                                                                        .write(        csr_write[FME_ERROR_MASK0[15:12]][FME_ERROR_MASK0[7:3]]),
                                                                        .state(hw_state)
                                                                        );

   csr_reg[FME_ERROR0[15:12]][FME_ERROR0[7:3]]   <= update_error_reg(.reg_mask_val(fme_csr_fme_error_mask0.data),
                                                                     .reg_reset_val( fme_csr_fme_error0_reset.data),
                                                                     .reg_update_val(fme_csr_fme_error0_update.data),
                                                                     .reg_current_val(csr_reg[FME_ERROR0[15:12]][FME_ERROR0[7:3]]),
                                                                     .write(        csr_write[FME_ERROR0[15:12]][FME_ERROR0[7:3]]),
                                                                     .state(hw_state)
                                                                     );

   csr_reg[PCIE0_ERROR_MASK[15:12]][PCIE0_ERROR_MASK[7:3]]  <= update_reg(.attr(pcie0_error_mask_attr.data),
                                                                  .reg_reset_val( fme_csr_pcie0_error_mask_reset.data),
                                                                  .reg_update_val(fme_csr_pcie0_error_mask_update.data),
                                                                  .reg_current_val(csr_reg[PCIE0_ERROR_MASK[15:12]][PCIE0_ERROR_MASK[7:3]]),
                                                                  .write(        csr_write[PCIE0_ERROR_MASK[15:12]][PCIE0_ERROR_MASK[7:3]]),
                                                                  .state(hw_state)
                                                                  );

   csr_reg[PCIE0_ERROR[15:12]][PCIE0_ERROR[7:3]] <= update_error_reg(.reg_mask_val(fme_csr_pcie0_error_mask.data),
                                                                     .reg_reset_val( fme_csr_pcie0_error_reset.data),
                                                                     .reg_update_val(fme_csr_pcie0_error_update.data),
                                                                     .reg_current_val(csr_reg[PCIE0_ERROR[15:12]][PCIE0_ERROR[7:3]]),
                                                                     .write(        csr_write[PCIE0_ERROR[15:12]][PCIE0_ERROR[7:3]]),
                                                                     .state(hw_state)
                                                                     );

   csr_reg[DUMMY_4028[15:12]][DUMMY_4028[7:3]]   <= update_reg(.attr(dummy_4028_attr.data),
                                                               .reg_reset_val( fme_csr_dummy_4028_reset.data),
                                                               .reg_update_val(fme_csr_dummy_4028_update.data),
                                                               .reg_current_val(csr_reg[DUMMY_4028[15:12]][DUMMY_4028[7:3]]),
                                                               .write(        csr_write[DUMMY_4028[15:12]][DUMMY_4028[7:3]]),
                                                               .state(hw_state)
                                                               );

   csr_reg[DUMMY_4030[15:12]][DUMMY_4030[7:3]]   <= update_reg(.attr(dummy_4030_attr.data),
                                                               .reg_reset_val( fme_csr_dummy_4030_reset.data),
                                                               .reg_update_val(fme_csr_dummy_4030_update.data),
                                                               .reg_current_val(csr_reg[DUMMY_4030[15:12]][DUMMY_4030[7:3]]),
                                                               .write(        csr_write[DUMMY_4030[15:12]][DUMMY_4030[7:3]]),
                                                               .state(hw_state)
                                                               );

   csr_reg[FME_FIRST_ERROR[15:12]][FME_FIRST_ERROR[7:3]]  <= update_reg(.attr(fme_first_error_attr.data),
                                                                        .reg_reset_val( fme_csr_fme_first_error_reset.data),
                                                                        .reg_update_val(fme_csr_fme_first_error_update.data),
                                                                        .reg_current_val(csr_reg[FME_FIRST_ERROR[15:12]][FME_FIRST_ERROR[7:3]]),
                                                                        .write(        csr_write[FME_FIRST_ERROR[15:12]][FME_FIRST_ERROR[7:3]]),
                                                                        .state(hw_state)
                                                                        );

   csr_reg[FME_NEXT_ERROR[15:12]][FME_NEXT_ERROR[7:3]] <= update_reg(.attr(fme_next_error_attr.data),
                                                                     .reg_reset_val( fme_csr_fme_next_error_reset.data),
                                                                     .reg_update_val(fme_csr_fme_next_error_update.data),
                                                                     .reg_current_val(csr_reg[FME_NEXT_ERROR[15:12]][FME_NEXT_ERROR[7:3]]),
                                                                     .write(        csr_write[FME_NEXT_ERROR[15:12]][FME_NEXT_ERROR[7:3]]),
                                                                     .state(hw_state)
                                                                     );

   csr_reg[RAS_NOFAT_ERROR_MASK[15:12]][RAS_NOFAT_ERROR_MASK[7:3]] <= update_reg(.attr(ras_nofat_error_mask_attr.data),
                                                                                 .reg_reset_val( fme_csr_ras_nofat_error_mask_reset.data),
                                                                                 .reg_update_val(fme_csr_ras_nofat_error_mask_update.data),
                                                                                 .reg_current_val(csr_reg[RAS_NOFAT_ERROR_MASK[15:12]][RAS_NOFAT_ERROR_MASK[7:3]]),
                                                                                 .write(        csr_write[RAS_NOFAT_ERROR_MASK[15:12]][RAS_NOFAT_ERROR_MASK[7:3]]),
                                                                                 .state(hw_state)
                                                                                 );

   csr_reg[RAS_NOFAT_ERROR[15:12]][RAS_NOFAT_ERROR[7:3]]  <= update_reg(.attr(ras_nofat_error_attr.data),
                                                                        .reg_reset_val( fme_csr_ras_nofat_error_reset.data),
                                                                        .reg_update_val(fme_csr_ras_nofat_error_update.data),
                                                                        .reg_current_val(csr_reg[RAS_NOFAT_ERROR[15:12]][RAS_NOFAT_ERROR[7:3]]),
                                                                        .write(        csr_write[RAS_NOFAT_ERROR[15:12]][RAS_NOFAT_ERROR[7:3]]),
                                                                        .state(hw_state)
                                                                        );

   csr_reg[RAS_CATFAT_ERROR_MASK[15:12]][RAS_CATFAT_ERROR_MASK[7:3]]  <= update_reg(.attr(ras_catfat_error_mask_attr.data),
                                                                                    .reg_reset_val( fme_csr_ras_catfat_error_mask_reset.data),
                                                                                    .reg_update_val(fme_csr_ras_catfat_error_mask_update.data),
                                                                                    .reg_current_val(csr_reg[RAS_CATFAT_ERROR_MASK[15:12]][RAS_CATFAT_ERROR_MASK[7:3]]),
                                                                                    .write(        csr_write[RAS_CATFAT_ERROR_MASK[15:12]][RAS_CATFAT_ERROR_MASK[7:3]]),
                                                                                    .state(hw_state)
                                                                                    );

   csr_reg[RAS_CATFAT_ERROR[15:12]][RAS_CATFAT_ERROR[7:3]]   <= update_reg(.attr(ras_catfat_error_attr.data),
                                                                           .reg_reset_val( fme_csr_ras_catfat_error_reset.data),
                                                                           .reg_update_val(fme_csr_ras_catfat_error_update.data),
                                                                           .reg_current_val(csr_reg[RAS_CATFAT_ERROR[15:12]][RAS_CATFAT_ERROR[7:3]]),
                                                                           .write(        csr_write[RAS_CATFAT_ERROR[15:12]][RAS_CATFAT_ERROR[7:3]]),
                                                                           .state(hw_state)
                                                                           );

   csr_reg[RAS_ERROR_INJ[15:12]][RAS_ERROR_INJ[7:3]]   <= update_reg(.attr(ras_error_inj_attr.data),
                                                                           .reg_reset_val( fme_csr_ras_error_inj_reset.data),
                                                                           .reg_update_val(fme_csr_ras_error_inj_update.data),
                                                                           .reg_current_val(csr_reg[RAS_ERROR_INJ[15:12]][RAS_ERROR_INJ[7:3]]),
                                                                           .write(        csr_write[RAS_ERROR_INJ[15:12]][RAS_ERROR_INJ[7:3]]),
                                                                           .state(hw_state)
                                                                           );

   csr_reg[GLBL_ERROR_CAPABILITY[15:12]][GLBL_ERROR_CAPABILITY[7:3]]  <= update_reg(.attr(glbl_error_capability_attr.data),
                                                                                    .reg_reset_val( fme_csr_glbl_error_capability_reset.data),
                                                                                    .reg_update_val(fme_csr_glbl_error_capability_update.data),
                                                                                    .reg_current_val(csr_reg[GLBL_ERROR_CAPABILITY[15:12]][GLBL_ERROR_CAPABILITY[7:3]]),
                                                                                    .write(        csr_write[GLBL_ERROR_CAPABILITY[15:12]][GLBL_ERROR_CAPABILITY[7:3]]),
                                                                                    .state(hw_state)
                                                                                    );

end : update_reg_seq


//----------------------------------------------------------------------------
// AXI MMIO CSR READ LOGIC
//----------------------------------------------------------------------------

//----------------------------------------------------------------------------
// REGISTER INTERFACE LOGIC
//----------------------------------------------------------------------------
always_comb
begin : rd_range_valid_comb
   if (axi.araddr[19:16] != '0)  // Restricting FME_CSR region to lower 256KB of BAR (512KB) in CoreFIM.
      rd_range_valid = 1'b0;
   else
   begin
      unique case (rd_feature_id)
         FME_DFH       [15:12]: rd_range_valid = (rd_reg_offset < 15) ? 1'b1 : 1'b0; 
         THERM_MNGM_DFH[15:12]: rd_range_valid = (rd_reg_offset < 5)  ? 1'b1 : 1'b0;
         GLBL_PERF_DFH [15:12]: rd_range_valid = (rd_reg_offset < 7)  ? 1'b1 : 1'b0;
         GLBL_ERROR_DFH[15:12]: rd_range_valid = (rd_reg_offset < 15) ? 1'b1 : 1'b0;
         default:               rd_range_valid = 1'b0;
      endcase
   end
end : rd_range_valid_comb


//----------------------------------------------------------------------------
// Combinatorial logic for valid read access sizes: 
//    2^2 = 4B(32-bit) or 
//    2^3 = 8B(64-bit).
//----------------------------------------------------------------------------
always_comb
begin : rd_size_valid_comb
   if ((axi.arsize == 3'b011) || (axi.arsize == 3'b010)) 
      arsize_valid = 1'b1;
   else
      arsize_valid = 1'b0;
end : rd_size_valid_comb


//----------------------------------------------------------------------------
// Combinatorial logic to define what type of read is occurring:
//    1.) UPPER32 = Upper 32 bits of register to lower 32 bits of the AXI 
//                  data bus. Top 32 bits of bus are zero-filled.
//    2.) LOWER32 = Lower 32 bits of register to lower 32 bits of the AXI
//                  data bus. Top  32 bits of bus are zero-filled.
//    3.) FULL64  = All 64 bits of the register to all 64 bits of the AXI
//                  data bus.
//    4.) NONE = No read will be performed.  AXI data bus will be all ones.
// A read address with bit #2 set decides whether 32-bit read is to upper or 
// lower word.
//----------------------------------------------------------------------------
always_comb
begin : read_type_comb
   if (axi.arvalid && rd_range_valid && arsize_valid) 
   begin
      if ((axi.arsize == 3'b010) && (axi.araddr[2] == 1'b1))
         read_type = UPPER32;
      else 
      begin
         if ((axi.arsize == 3'b010) && (axi.araddr[2] == 1'b0))
            read_type = LOWER32;
         else
         begin
            if (axi.arsize == 3'b011)
               read_type = FULL64;
            else
               read_type = NONE;
         end
      end
   end
   else
   begin
      read_type = NONE;
   end
end : read_type_comb


//----------------------------------------------------------------------------
// Read State Machine Logic
//
// Top "always_ff" simply switches the state of the state machine registers.
//
// Following "always_comb" contains all of the next-state decoding logic.
//
// NOTE: The state machine is coded in a one-hot style with a "reverse-case" 
// statement.  This style compiles with the highest performance in Quartus.
//----------------------------------------------------------------------------
always_ff @(posedge clk, negedge reset_n)
begin : rd_sm_seq
   if (!reset_n)
      rd_state <= RD_RESET;
   else
      rd_state <= rd_next;
end : rd_sm_seq

always_comb
begin : rd_sm_comb
   rd_next = rd_state;
   unique case (1'b1) //Reverse Case Statement
      rd_state[RD_RESET_BIT]:
         if (!reset_n)
            rd_next = RD_RESET;
         else
            rd_next = RD_READY;
      rd_state[RD_READY_BIT]:
         if (axi.arvalid)
            rd_next = RD_GOT_ADDR;
         else
            rd_next = RD_READY;
      rd_state[RD_GOT_ADDR_BIT]:
         rd_next = RD_DRIVE_BUS;
      rd_state[RD_DRIVE_BUS_BIT]:
         if (!axi.rready)
            rd_next = RD_DRIVE_BUS;
         else
            rd_next = READ_COMPLETE;
      rd_state[READ_COMPLETE_BIT]:
         rd_next = RD_READY;
   endcase
end : rd_sm_comb


//----------------------------------------------------------------------------
// Sequential logic to capture some transaction-qualifying signals during 
// reads on the read-address bus.  Values are sampled on the transition into
// the "RD_GOT_ADDR" state in the read state machine.
//----------------------------------------------------------------------------
always_ff @(posedge clk, negedge reset_n)
begin : rd_addr_seq_var
   if (!reset_n)
   begin
      arid_reg <= {MMIO_TID_WIDTH{1'b0}};
      araddr_reg <= {MMIO_ADDR_WIDTH{1'b0}};
      arsize_reg <= 3'b000;
      read_type_reg <= NONE;
      rd_range_valid_reg <= 1'b0;
      arsize_valid_reg  <= 1'b0;
      cfg_rd_hit <= 1'b0;
   end
   else
   begin
      if (rd_next[RD_GOT_ADDR_BIT])
      begin
         arid_reg <= axi.arid;
         araddr_reg <= axi.araddr;
         arsize_reg <= axi.arsize;
         read_type_reg <= read_type;
         rd_range_valid_reg <= rd_range_valid;
         arsize_valid_reg  <= arsize_valid;
         cfg_rd_hit <= 1'b1;
      end
      else
      begin
         if (rd_state[READ_COMPLETE_BIT])
         begin
            arid_reg <= {MMIO_TID_WIDTH{1'b0}};
            araddr_reg <= {MMIO_ADDR_WIDTH{1'b0}};
            arsize_reg <= 3'b000;
            read_type_reg <= NONE;
            rd_range_valid_reg <= 1'b0;
            arsize_valid_reg  <= 1'b0;
            cfg_rd_hit <= 1'b0;
         end
      end
   end
end : rd_addr_seq_var


//----------------------------------------------------------------------------
// Sequential logic to fetch the CSR register contents during an AXI read.
//----------------------------------------------------------------------------
always_ff @(posedge clk, negedge reset_n)
begin : rd_data_reg_seq
   if (!reset_n)
      read_data_reg.data <= {CSR_REG_WIDTH{1'b0}};
   else
   begin
      if (rd_next[RD_GOT_ADDR_BIT])
      begin
         if (read_type == NONE)
            read_data_reg.data <= {64{1'b0}};
         else
            read_data_reg.data <= csr_reg[axi.araddr[15:12]][axi.araddr[7:3]];
      end
   end
end : rd_data_reg_seq


//----------------------------------------------------------------------------
// Combinatorial logic to format the read data according to the read acccess 
// being executed on the AXI bus.
//----------------------------------------------------------------------------
always_comb
begin : rd_data_comb
   if (read_type_reg == FULL64)
      read_data = read_data_reg.data;
   else
      if (read_type_reg == UPPER32)
//       read_data = {read_data_reg.word.upper32, 32'h0};
         read_data = {read_data_reg.word.upper32, read_data_reg.word.upper32};  // replicate read data to lower 32 -- workaround for 32-bit axi4lite_initiator
      else
         if (read_type_reg == LOWER32)
            read_data = {read_data_reg.word.lower32, read_data_reg.word.lower32};
         else
            read_data = {64{1'b0}};
end : rd_data_comb


//----------------------------------------------------------------------------
// Combinatorial logic for interface and handshaking signals controlled mostly
// by the read state machine to sequence events.
//----------------------------------------------------------------------------
always_ff @(posedge clk, negedge reset_n)
begin
   if (!reset_n)
   begin
      axi.arready <= 1'b0;
      axi.rid     <= {MMIO_TID_WIDTH{1'b0}};
      axi.rdata   <= {MMIO_DATA_WIDTH{1'b0}};
      axi.rresp   <= RESP_OKAY;
      axi.rlast   <= 1'b0;
      axi.rvalid  <= 1'b0;
   end
   else
   begin
      axi.arready <=  rd_next[RD_READY_BIT];
      axi.rid     <= (rd_next[RD_DRIVE_BUS_BIT]) ? arid_reg  : {MMIO_TID_WIDTH{1'b0}};
      axi.rdata   <= (rd_next[RD_DRIVE_BUS_BIT]) ? read_data : {MMIO_DATA_WIDTH{1'b0}};
      axi.rresp   <=  RESP_OKAY;
      axi.rlast   <= (rd_next[RD_DRIVE_BUS_BIT]) ? 1'b1 : 1'b0;
      axi.rvalid  <= (rd_next[RD_DRIVE_BUS_BIT]) ? 1'b1 : 1'b0;
   end
end

//============================================================================//
//                           FME Signataps                                    //
//============================================================================//
                                                                              //
//`ifdef debug_FME                                                            //
   logic             debug_wr_range_valid        /* synthesis noprune */ ;//  
   logic             debug_awsize_valid          /* synthesis noprune */ ;//  
   logic     [4:0]   debug_rd_state              /* synthesis noprune */ ;//  
   logic     [6:0]   debug_wr_state              /* synthesis noprune */ ;//  

   always @(posedge clk) begin                                            //
      debug_wr_range_valid <= wr_range_valid                             ;//  
      debug_awsize_valid   <= awsize_valid                               ;//  
      debug_rd_state       <= rd_state                                   ;//  
      debug_wr_state       <= wr_state                                   ;// 
   end                                                                    //
//`endif
endmodule

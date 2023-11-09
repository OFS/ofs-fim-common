#---------------
#PACKAGES
#---------------
+incdir+$OFS_ROOTDIR/src/includes
+incdir+$OFS_ROOTDIR/src/fims/n6000/includes
$OFS_ROOTDIR/src/fims/d5005/includes/ofs_fim_cfg_pkg.sv
$OFS_ROOTDIR/src/fims/n6000/includes/ofs_pcie_ss_plat_cfg_pkg.sv
$OFS_ROOTDIR/src/includes/ofs_fim_if_pkg.sv
$OFS_ROOTDIR/src/includes/ofs_pcie_ss_cfg_pkg.sv
$OFS_ROOTDIR/src/includes/pcie_ss_hdr_pkg.sv
$OFS_ROOTDIR/src/includes/pcie_ss_pkg.sv

#---------------
#MUX FILELIST
#---------------
$OFS_ROOTDIR/src/includes/ofs_axis_if.sv
$OFS_ROOTDIR/src/includes/ofs_avst_if.sv
$OFS_ROOTDIR/src/includes/pcie_ss_axis_if.sv
$OFS_ROOTDIR/src/common/fifo/bfifo.sv
$OFS_ROOTDIR/src/common/ram/ram_1r1w.sv
$OFS_ROOTDIR/src/common/ram/gram_sdp.sv
$OFS_ROOTDIR/src/common/mux/pf_vf_mux_pkg.sv
$OFS_ROOTDIR/src/common/mux/Nmux.sv
$OFS_ROOTDIR/src/common/mux/switch.sv
#$OFS_ROOTDIR/src/fims/n6000/afu/pf_vf_mux_top/mux/top_cfg_pkg.sv
$OFS_ROOTDIR/verification/common/pf_vf_mux/top_cfg_pkg_pf_vf_mux.sv
$OFS_ROOTDIR/src/common/mux/pf_vf_mux_top.sv

# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

#
# HPS SS
#--------------------

set_global_assignment -name SEARCH_PATH "$::env(BUILD_ROOT_REL)/ofs-common/src/fpga_family/agilex/hps"

set_global_assignment -name QSYS_FILE  ../ip_lib/ofs-common/src/fpga_family/agilex/hps/hps_ss.qsys
set_global_assignment -name IP_FILE    ../ip_lib/ofs-common/src/fpga_family/agilex/hps/ip/hps_ss/hps_ss_clock_in_0.ip
set_global_assignment -name IP_FILE    ../ip_lib/ofs-common/src/fpga_family/agilex/hps/ip/hps_ss/hps_ss_intel_agilex_hps_1.ip
set_global_assignment -name IP_FILE    ../ip_lib/ofs-common/src/fpga_family/agilex/hps/ip/hps_ss/hps_ss_reset_in_0.ip

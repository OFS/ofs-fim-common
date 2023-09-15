## Copyright 2020 Intel Corporation
## SPDX-License-Identifier: MIT

#
# Import the standard exerciser sources. Some AFUs, especially default
# test AFUs, may use them.
#

#--------------------
# HE LPBK modules
#--------------------
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE $::env(BUILD_ROOT_REL)/ofs-common/src/common/he_lb/files_quartus.tcl

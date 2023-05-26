## Copyright (C) 2023 Intel Corporation
## SPDX-License-Identifier: MIT

##
## Load the subset of interfaces and modules required for AFUs inside the port
## gasket. This is the minimal set of sources loaded when generating the
## out-of-tree PR build environment.
##

set_global_assignment -name IP_FILE ../ip_lib/ofs-common/src/fpga_family/agilex/remote_stp/AFU_debug/config_reset_release.ip
set_global_assignment -name IP_FILE ../ip_lib/ofs-common/src/fpga_family/agilex/remote_stp/AFU_debug/scjio_agilex.ip

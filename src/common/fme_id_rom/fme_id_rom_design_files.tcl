## Copyright (C) 2023 Intel Corporation
## SPDX-License-Identifier: MIT
#--------------------
#--------------------
# FME ID ROM Filelist
#--------------------
# The MIF file will be generated during the build by update_fme_ifc_id.py
set_global_assignment -name MIF_FILE fme_id.mif
set_global_assignment -name IP_FILE  ../ip_lib/ofs-common/src/common/fme_id_rom/fme_id_rom.ip

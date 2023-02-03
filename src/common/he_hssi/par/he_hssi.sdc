# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

#-----------------------------------------------------------------------------
# Description
#-----------------------------------------------------------------------------
#
#   Eth AFU SDC 
#
#-----------------------------------------------------------------------------

#--------------------
# Common procedures
#--------------------
proc add_reset_sync_sdc { pin_name } {
   set_max_delay -to [get_pins $pin_name] 100.000
   set_min_delay -to [get_pins $pin_name] -100.000
   #set_max_skew  -to [get_pins $pin_name] -get_skew_value_from_clock_period src_clock_period -skew_value_multiplier 0.800 
}

proc add_sync_sdc { name } {
   set_max_delay -to [get_keepers $name] 100.000
   set_min_delay -to [get_keepers $name] -100.000
}

#---------------------------------------------
# CDC constraints for reset synchronizers
#---------------------------------------------
add_reset_sync_sdc {afu_top|port_gasket|pr_slot|afu_main|he_hssi_top_inst|GenRstSync[*].*_reset_synchronizer|resync_chains[0].synchronizer|*|clrn}

#---------------------------------------------
# CDC constraints for synchronizers
#---------------------------------------------
add_sync_sdc {afu_top|port_gasket|pr_slot|afu_main|he_hssi_top|*|altera_std_synchronizer|din_s1}
add_sync_sdc {afu_top|port_gasket|pr_slot|afu_main|he_hssi_top|*|altera_std_synchronizer_nocut|din_s1}
add_sync_sdc {afu_top|port_gasket|pr_slot|afu_main|he_hssi_top_inst|*|*|GenTrafWrap[*].traffic_controller_wrapper|*|resync_chains[*].synchronizer|din_s1}


